//  The usage strip's data (story 203): the Cockpit's GET /usage, loaded on launch, on foreground and every five
//  minutes while the app is in front; a tap asks for a new reading (POST /usage/refresh) and polls until it lands.
//
//  Off the tailnet the strip simply is not drawn; a strip that had loaded keeps its last reading and its time.

import ContextCore
import Foundation

@MainActor
final class UsageModel: ObservableObject {
  @Published private(set) var strip: UsageStrip?
  @Published private(set) var refreshing = false
  /// When the strip's reading was fetched; shown when a later load failed.
  @Published private(set) var loadedAt: Date?
  @Published private(set) var lastLoadFailed = false

  private let log: SessionLog
  private let base: URL?
  private var timer: Timer?
  private var pollTask: Task<Void, Never>?

  /// `override`: another Cockpit (the simulator's checks point it at a local server).
  init(log: SessionLog, override: String? = nil) {
    self.log = log
    base = URL(string: override.flatMap { $0.isEmpty ? nil : $0 } ?? CockpitPage.url)
  }

  /// Loads now and every five minutes until `pause()`.
  func resume(reason: String) {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.load(reason: "timer") }
    }
    Task { await load(reason: reason) }
  }

  func pause() {
    timer?.invalidate()
    timer = nil
  }

  @discardableResult
  func load(reason: String) async -> CockpitUsage? {
    guard let url = base?.appendingPathComponent("usage") else { return nil }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let started = Date()
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200 else { throw URLError(.badServerResponse, userInfo: ["status": status]) }
      let usage = try CockpitUsage.decode(data)
      strip = UsageStrip(usage)
      loadedAt = Date()
      lastLoadFailed = false
      log.event("usage", [
        "action": "load", "reason": reason, "ok": true, "ms": Int(Date().timeIntervalSince(started) * 1000),
        "present": usage.present ?? false, "drawn": strip != nil,
        "bars": strip?.bars.map { "\($0.label) \($0.text)" }.joined(separator: ", ") ?? "",
        "stale": usage.stale ?? false, "pending": usage.pending ?? false,
      ])
      return usage
    } catch {
      lastLoadFailed = true
      log.event("usage", [
        "action": "load", "reason": reason, "ok": false, "ms": Int(Date().timeIntervalSince(started) * 1000),
        "error": String(describing: error), "kept": strip != nil,
      ])
      return nil
    }
  }

  /// Asks the Cockpit for a fresh reading (Larry takes it, about a minute), then polls every ten seconds until it
  /// says the ask is answered, giving up after five minutes.
  func refresh() {
    guard !refreshing, let base else { return }
    refreshing = true
    pollTask?.cancel()
    pollTask = Task {
      defer { refreshing = false }
      var request = URLRequest(url: base.appendingPathComponent("usage/refresh"), timeoutInterval: 8)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      // The Cockpit's write boundary takes a POST from its own origin (the Call screen's fix for #136, too).
      if var origin = URLComponents(url: base, resolvingAgainstBaseURL: false) {
        origin.path = ""; origin.query = nil; origin.fragment = nil
        request.setValue(origin.string, forHTTPHeaderField: "Origin")
      }
      request.httpBody = Data(#"{"source":"grabber-native"}"#.utf8)
      do {
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        log.event("usage", ["action": "refresh_ask", "status": status])
        guard (200..<300).contains(status) else { return }
      } catch {
        log.event("usage", ["action": "refresh_ask", "error": String(describing: error)])
        return
      }
      let deadline = Date().addingTimeInterval(300)
      while Date() < deadline, !Task.isCancelled {
        try? await Task.sleep(for: .seconds(10))
        if let usage = await load(reason: "refresh"), usage.pending != true {
          log.event("usage", ["action": "refresh_landed"])
          return
        }
      }
      log.event("usage", ["action": "refresh_gave_up"])
    }
  }
}
