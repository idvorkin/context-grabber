//  Shake to report (stories 142, 145): a shake, or Diagnostics' "Report a problem", opens a note sheet. Sending
//  writes a `bug_report` event into the session log and appends a line to Documents/bugs.jsonl that names the
//  log file, so `just file-bugs` can file it and a developer can jump from the report to the log.

import ContextCore
import CoreMotion
import SwiftUI
import UIKit

/// Calls `onShake` when the device is shaken. Sits invisibly in the view tree and holds first responder.
/// Story 146 (#164): a gentle shake, read from the motion itself (iOS's shake gesture wants a hard one). Runs only
/// while the app is in front. The gesture's state is touched only on the motion queue (one operation at a time).
final class ShakeMotion: @unchecked Sendable {
  private let motion = CMMotionManager()
  private let queue = OperationQueue()
  private var gesture = ShakeGesture()
  private let onShake: @MainActor (Double) -> Void

  init(onShake: @escaping @MainActor (Double) -> Void) {
    self.onShake = onShake
    queue.maxConcurrentOperationCount = 1
  }

  func start() {
    guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
    motion.deviceMotionUpdateInterval = 1.0 / 50
    motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
      guard let self, let data else { return }
      let a = data.userAcceleration
      if let peak = self.gesture.feed(x: a.x, y: a.y, z: a.z, t: data.timestamp) {
        let onShake = self.onShake
        Task { @MainActor in onShake(peak) }
      }
    }
  }

  func stop() { motion.stopDeviceMotionUpdates() }
}

struct ShakeDetector: UIViewControllerRepresentable {
  let onShake: () -> Void

  final class Controller: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
      if motion == .motionShake { onShake?() }
      super.motionEnded(motion, with: event)
    }
  }

  func makeUIViewController(context: Context) -> Controller {
    let controller = Controller()
    controller.onShake = onShake
    controller.view.isUserInteractionEnabled = false
    return controller
  }

  func updateUIViewController(_ controller: Controller, context: Context) {
    controller.onShake = onShake
  }
}

/// Presents the report from the topmost controller, so it opens over any sheet, cover or dialog of the app's.
@MainActor
enum BugReportPresenter {
  private final class Watcher: NSObject, UIAdaptivePresentationControllerDelegate {
    let onGone: () -> Void
    init(onGone: @escaping () -> Void) { self.onGone = onGone }
    func presentationControllerDidDismiss(_ controller: UIPresentationController) { onGone() }
  }

  private static var watcher: Watcher?

  /// The class name of what it was presented over, or nil when there was no window to present from.
  /// `another`: after *Log it and another*, once this sheet is gone, open the next one.
  static func present(
    _ sheet: BugReportSheet, onGone: @escaping () -> Void, another: @escaping () -> Void = {}
  ) -> String? {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    guard var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController else { return nil }
    while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
    // The sheet's buttons close the controller that hosts it, which exists only once the sheet does.
    final class Host { weak var controller: UIViewController? }
    let host = Host()
    var view = sheet
    view.close = {
      host.controller?.dismiss(animated: true)
      onGone()
    }
    // The next report captures the screen underneath, so it waits for this one to be off screen.
    view.closeForAnother = {
      guard let controller = host.controller else { return }
      controller.dismiss(animated: true) {
        onGone()
        another()
      }
    }
    let controller = UIHostingController(rootView: view)
    host.controller = controller
    let watcher = Watcher(onGone: onGone)  // a swipe down closes it without Cancel
    Self.watcher = watcher
    controller.presentationController?.delegate = watcher
    top.present(controller, animated: true)
    return String(describing: type(of: top))
  }
}

struct BugReportSheet: View {
  @ObservedObject var model: AppModel
  /// Set by the presenter: closes the controller it is hosted in.
  var close: () -> Void = {}
  /// Set by the presenter: closes it and opens a fresh report.
  var closeForAnother: () -> Void = {}
  @State private var note = ""
  @FocusState private var noteFocused: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("What went wrong?") {
          TextField("e.g. the timer skipped the rest", text: $note, axis: .vertical)
            .lineLimit(3...8)
            .focused($noteFocused)
          // Right under the note, above the keyboard (a bottom bar sits behind it): the same report as Log it,
          // then an empty one for the next problem, no shake needed.
          Button("Log it and another") {
            model.reportBug(note: note)
            closeForAnother()
          }
          .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("report-log-it-and-another")
        }
        Section("Attached automatically") {
          ForEach(model.bugContext().sorted(by: { $0.key < $1.key }), id: \.key) { item in
            LabeledContent(item.key, value: item.value)
          }
          LabeledContent("screenshot", value: "the screen as it was")
        }
      }
      .navigationTitle("Report a problem")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Log it") {
            model.reportBug(note: note)
            close()
          }
          .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("report-log-it")
        }
      }
      .onAppear { noteFocused = true }
    }
  }
}

/// The report's files: what the screen showed at the shake, the line in bugs.jsonl and the session log, and the
/// pruning of old logs no report names. The model supplies the context, since that is its state.
@MainActor
final class BugReporter {
  private let log: SessionLog
  private let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  private var screenshot: UIImage?

  init(log: SessionLog) { self.log = log }

  /// Snapshots the window before the sheet covers it.
  func capture() {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else { return }
    screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
    }
  }

  private static let folderFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyyMMdd-HHmmss"
    return f
  }()

  /// Writes the captured screenshot under Documents/bugs/<stamp>/ and returns its relative path.
  private func saveScreenshot(stamp: String) -> String? {
    defer { screenshot = nil }
    guard let data = screenshot?.pngData() else { return nil }
    let folder = documents.appendingPathComponent("bugs", isDirectory: true)
      .appendingPathComponent(stamp, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try data.write(to: folder.appendingPathComponent("screen.png"))
      return "bugs/\(stamp)/screen.png"
    } catch {
      log.event("error", ["where": "bug_images", "message": "\(error)"])
      return nil
    }
  }

  /// Writes the report into the session log and to Documents/bugs.jsonl (one line per report, newest last), and
  /// returns what the status line says.
  func report(note: String, context: [String: String]) -> String {
    let now = Date()
    var record: [String: Any] = context
    if let screenshot = saveScreenshot(stamp: Self.folderFormatter.string(from: now)) {
      record["screenshot"] = screenshot
    }
    record["note"] = note
    log.event("bug_report", record)
    record["reported_at"] = ISO8601DateFormatter().string(from: now)
    record["session_t_ms"] = Int(now.timeIntervalSince(log.startedAt) * 1000)
    let url = documents.appendingPathComponent("bugs.jsonl")
    do {
      let line = try JSONSerialization.data(withJSONObject: record) + Data([0x0A])
      if let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(line)
      } else {
        try line.write(to: url)
      }
      return "Problem logged. Thanks."
    } catch {
      // The report is in the session log either way; bugs.jsonl is what `just file-bugs` reads, so say it is missing.
      log.event("error", ["where": "bug_report", "message": "\(error)"])
      return "Problem noted in the log; bugs.jsonl could not be written"
    }
  }

  /// Deletes session logs older than 30 days, except any named by a report in bugs.jsonl. Runs at launch, after
  /// the new session's log is open, and logs one `logs_pruned` event even when zero. A file whose age cannot be
  /// read is never deleted.
  func pruneOldLogs() {
    let dir = documents.appendingPathComponent("logs", isDirectory: true)
    let bugs = documents.appendingPathComponent("bugs.jsonl")
    var referenced = Set<String>()
    if FileManager.default.fileExists(atPath: bugs.path) {
      // A bugs.jsonl that exists but cannot be read means the reported logs are unknown: prune nothing rather
      // than delete evidence.
      guard let text = try? String(contentsOf: bugs, encoding: .utf8) else {
        log.event("error", ["where": "logs_prune", "message": "bugs.jsonl unreadable; nothing pruned"])
        return
      }
      referenced = LogRetention.referencedLogs(bugsJsonl: text)
    }
    let now = Date()
    let files = ((try? FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? [])
      .filter { $0.pathExtension == "jsonl" }
      .compactMap { url -> (name: String, age: Double, size: Int)? in
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
          let modified = values.contentModificationDate
        else { return nil }
        return (url.lastPathComponent, now.timeIntervalSince(modified), values.fileSize ?? 0)
      }
    let victims = Set(LogRetention.prune(files: files.map { (name: $0.name, age: $0.age) }, referenced: referenced))
    var count = 0
    var freed = 0
    for file in files where victims.contains(file.name) {
      do {
        try FileManager.default.removeItem(at: dir.appendingPathComponent(file.name))
        count += 1
        freed += file.size
      } catch {
        log.event("error", ["where": "logs_prune", "file": file.name, "message": "\(error)"])
      }
    }
    let kept = files.filter { $0.age > LogRetention.retentionSeconds && referenced.contains($0.name) }.count
    log.event("logs_pruned", ["count": count, "bytes": freed, "kept_for_reports": kept])
  }
}
