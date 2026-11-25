//  Ink side by side (story 1209, bead context-grabber-vabk; spec docs/superpowers/specs/2026-11-22-ink-side-by-side-design.md):
//  a debug screen, the app's own PencilKit ink on the left and the Cockpit's /ink web board on the right, each with
//  how long a pen-down takes to reach the next frame. An A/B tool only: the board's own drawing is untouched.
//
//  Story 1324: both halves measure the web board's own way (its live ink): per frame while the pen is down, the oldest
//  undrawn touch to the start of the frame that draws it; per stroke, the median and the worst. Native: UITouch
//  timestamps to CADisplayLink.timestamp (seconds of system uptime). Web: the board's own per-stroke numbers, passed
//  along by the probe. Leaving the screen or Clear writes one `board_pen_latency` line per half that drew.

import BugKit
import ContextCore
import PencilKit
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import WebKit

@MainActor
final class InkSideBySideModel: ObservableObject {
  @Published private(set) var native = InkLatency(side: .native)
  @Published private(set) var web = InkLatency(side: .web)
  @Published private(set) var clears = 0
  @Published var webProblem: BugProblem?
  let log: SessionLog
  let webURL: URL?

  init(log: SessionLog) {
    self.log = log
    // Always Igor's real Cockpit: the web board is the thing being compared, never a stand-in page.
    webURL = InkLatency.webBoardURL(cockpit: ChatCockpit.pageAddress(override: nil))
  }

  func record(_ side: InkLatency.Side, stroke: InkStrokeLag.Summary) {
    let fields: [String: Any]
    switch side {
    case .native:
      let outcome = native.add(stroke)
      fields = native.logFields(stroke: stroke, outcome: outcome)
    case .web:
      let outcome = web.add(stroke)
      fields = web.logFields(stroke: stroke, outcome: outcome)
    }
    log.event("ink_side_by_side", fields)
  }

  func clear() {
    clears += 1
    log.event("ink_side_by_side", ["action": "clear", "side": InkLatency.Side.native.rawValue])
    writeLines()
  }

  /// One `board_pen_latency` line per half that drew since the last one (story 1324), then both start afresh.
  func writeLines() {
    for half in [native, web] {
      if let line = half.penLatencyFields() { log.event("ink_side_by_side", line) }
    }
    native = InkLatency(side: .native)
    web = InkLatency(side: .web)
  }

  func webFailed(_ error: Error, url: URL?) {
    let ns = error as NSError
    // A navigation the page itself replaced is not a failure.
    if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
    log.event(
      "ink_side_by_side",
      ["action": "web_failed", "error": ns.localizedDescription, "code": ns.code, "url": url?.absoluteString ?? ""])
    webProblem = BugProblem(
      message: "The web board didn't load: \(ns.localizedDescription)", context: "InkSideBySide.webBoard",
      build: "\(BuildInfo.sha) \(BuildInfo.branch)",
      extra: [
        "url": .string(url?.absoluteString ?? "none"), "domain": .string(ns.domain), "code": .int(ns.code),
      ],
      autoFile: false)
  }
}

struct InkSideBySideView: View {
  @StateObject private var model: InkSideBySideModel

  init(log: SessionLog) {
    _model = StateObject(wrappedValue: InkSideBySideModel(log: log))
  }

  var body: some View {
    HStack(spacing: 0) {
      half(title: "iPad ink (PencilKit)", readout: model.native.readout, side: .native) {
        NativeInkCanvas(model: model)
      }
      Divider()
      half(title: "Web board (/ink)", readout: model.web.readout, side: .web) {
        ZStack(alignment: .top) {
          WebInkBoard(model: model)
          if let problem = model.webProblem {
            BugProblemView(problem: problem, logger: model.log.bugLogger).padding()
              .accessibilityIdentifier("ink-web-problem")
          }
        }
      }
    }
    .navigationTitle("Ink side by side")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Clear") { model.clear() }.accessibilityIdentifier("ink-native-clear")
      }
    }
    .onAppear {
      model.log.event("ink_side_by_side", ["action": "open", "web": model.webURL?.absoluteString ?? "none"])
    }
    .onDisappear { model.writeLines() }
  }

  private func half<Content: View>(
    title: String, readout: String, side: InkLatency.Side, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(title).font(.footnote.weight(.semibold))
        Spacer()
        Text(readout).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
          .accessibilityIdentifier("ink-\(side.rawValue)-readout")
      }
      .padding(.horizontal, 10).padding(.vertical, 6)
      .background(.bar)
      content()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// The left half: a plain PencilKit canvas with a black pen, Pencil or finger, measured from each pen-down.
private struct NativeInkCanvas: UIViewRepresentable {
  @ObservedObject var model: InkSideBySideModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> PKCanvasView {
    let canvas = PKCanvasView()
    canvas.drawingPolicy = .anyInput
    canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
    canvas.backgroundColor = .white
    canvas.isOpaque = true
    canvas.accessibilityIdentifier = "ink-native-canvas"
    let watcher = StrokeWatcher(target: nil, action: nil)
    watcher.onDown = { [weak coordinator = context.coordinator] stamp in coordinator?.down(at: stamp) }
    watcher.onMove = { [weak coordinator = context.coordinator] stamp in coordinator?.moved(at: stamp) }
    watcher.onUp = { [weak coordinator = context.coordinator] in coordinator?.up() }
    watcher.delegate = context.coordinator
    canvas.addGestureRecognizer(watcher)
    context.coordinator.clears = model.clears
    return canvas
  }

  func updateUIView(_ canvas: PKCanvasView, context: Context) {
    guard context.coordinator.clears != model.clears else { return }
    context.coordinator.clears = model.clears
    canvas.drawing = PKDrawing()
  }

  @MainActor
  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    let model: InkSideBySideModel
    var clears = 0
    private var stroke: InkStrokeLag?
    private var link: CADisplayLink?

    init(model: InkSideBySideModel) { self.model = model }

    // Seconds of system uptime to the stroke's milliseconds.
    func down(at stamp: TimeInterval) {
      stroke = InkStrokeLag(down: stamp * 1000)
      if link == nil {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
      }
    }

    func moved(at stamp: TimeInterval) { stroke?.touched(at: stamp * 1000) }

    /// The frame that starts now draws whatever touch is waiting, as the web board's live ink counts it.
    @objc private func tick(_ link: CADisplayLink) { stroke?.frame(at: link.timestamp * 1000) }

    func up() {
      link?.invalidate()
      link = nil
      if let summary = stroke?.summary { model.record(.native, stroke: summary) }
      stroke = nil
    }

    // PencilKit's own drawing recognizer must never make the watcher fail mid-stroke.
    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
  }
}

/// Sees a stroke's touches go by and never takes them: it stays undecided from pen-down to lift, so PencilKit's own
/// drawing never waits on it, and steps aside at the end.
private final class StrokeWatcher: UIGestureRecognizer {
  var onDown: ((TimeInterval) -> Void)?
  var onMove: ((TimeInterval) -> Void)?
  var onUp: (() -> Void)?

  override init(target: Any?, action: Selector?) {
    super.init(target: target, action: action)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    if let first = touches.min(by: { $0.timestamp < $1.timestamp }) { onDown?(first.timestamp) }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    // The earliest touch since the last call, coalesced ones included, is the oldest one not yet drawn.
    let all = touches.flatMap { event.coalescedTouches(for: $0) ?? [$0] }
    if let first = all.min(by: { $0.timestamp < $1.timestamp }) { onMove?(first.timestamp) }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { finish() }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { finish() }

  private func finish() {
    onUp?()
    state = .failed
  }
}

/// The right half: the Cockpit's /ink page on its scratch board, with a probe that times each pointer-down.
private struct WebInkBoard: UIViewRepresentable {
  @ObservedObject var model: InkSideBySideModel

  func makeCoordinator() -> Coordinator { Coordinator(model: model) }

  func makeUIView(context: Context) -> WKWebView {
    let controller = WKUserContentController()
    controller.addUserScript(
      WKUserScript(source: InkLatency.webProbeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    controller.add(WeakMessages(context.coordinator), name: InkLatency.messageHandler)
    let config = WKWebViewConfiguration()
    config.userContentController = controller
    let web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = context.coordinator
    web.accessibilityIdentifier = "ink-web-board"
    #if DEBUG
      web.isInspectable = true
    #endif
    if let url = model.webURL {
      web.load(URLRequest(url: url))
    } else {
      model.webFailed(URLError(.badURL), url: nil)
    }
    return web
  }

  func updateUIView(_ web: WKWebView, context: Context) {}

  static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
    web.configuration.userContentController.removeScriptMessageHandler(forName: InkLatency.messageHandler)
  }

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate {
    let model: InkSideBySideModel
    init(model: InkSideBySideModel) { self.model = model }

    func received(_ body: Any) {
      guard let stroke = InkLatency.webStroke(from: body) else { return }
      model.record(.web, stroke: stroke)
    }

    // WebKit's own signature.
    // swiftlint:disable:next implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      model.webProblem = nil
    }

    // WebKit's own signature.
    // swiftlint:disable:next implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      model.webFailed(error, url: webView.url ?? model.webURL)
    }

    // WebKit's own signature.
    // swiftlint:disable:next implicitly_unwrapped_optional
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      model.webFailed(error, url: webView.url ?? model.webURL)
    }
  }
}

/// The content controller keeps its handler alive; this keeps only a weak hold on the coordinator.
private final class WeakMessages: NSObject, WKScriptMessageHandler {
  private weak var coordinator: WebInkBoard.Coordinator?
  init(_ coordinator: WebInkBoard.Coordinator) { self.coordinator = coordinator }

  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    let body = message.body
    MainActor.assumeIsolated { coordinator?.received(body) }
  }
}
