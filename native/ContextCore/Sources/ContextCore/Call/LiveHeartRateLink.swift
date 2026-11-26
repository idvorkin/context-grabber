import Foundation

/// Stories 1088-1089 (context-grabber-at59): Exercise Analyzer's live heart rate on calls. Grabber can't start
/// another app's watch session itself, so it opens Exercise Analyzer's link (exercise-analyzer PR #412), which asks
/// the watch and comes back through `x-success` or `x-error`.
public enum LiveHeartRateLink {
  public enum Action: String, Equatable, Sendable { case start, end }

  public enum Callback: Equatable, Sendable {
    case ok(Action)
    case error(Action, String)
  }

  /// The scheme Exercise Analyzer answers; Grabber lists it under `LSApplicationQueriesSchemes` for `canOpenURL`.
  public static let scheme = "exerciseanalyzer"
  static let host = "live-heart-rate"

  /// `exerciseanalyzer://live-heart-rate/start?kind=call&x-success=…&x-error=…`, or `/end` with the same callbacks.
  public static func url(for action: Action) -> URL? {
    var parts = URLComponents()
    parts.scheme = scheme
    parts.host = host
    parts.path = "/" + action.rawValue
    var items: [URLQueryItem] = []
    if action == .start { items.append(URLQueryItem(name: "kind", value: "call")) }
    items.append(URLQueryItem(name: "x-success", value: callbackString("ok", action)))
    items.append(URLQueryItem(name: "x-error", value: callbackString("error", action)))
    parts.queryItems = items
    return parts.url
  }

  /// Exercise Analyzer's answer, from the `grabbernative://live-heart-rate/…` link it opens; nil for any other link.
  public static func callback(_ url: URL) -> Callback? {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.host == host else { return nil }
    let items = parts.queryItems ?? []
    let action = items.first { $0.name == "action" }.flatMap { Action(rawValue: $0.value ?? "") } ?? .start
    switch parts.path {
    case "/ok": return .ok(action)
    case "/error":
      let message = items.first { $0.name == "errorMessage" }?.value ?? ""
      return .error(action, message.isEmpty ? "Exercise Analyzer gave no reason" : message)
    default: return nil
    }
  }

  private static func callbackString(_ outcome: String, _ action: Action) -> String {
    "\(AppLink.scheme)://\(host)/\(outcome)?action=\(action.rawValue)"
  }
}

/// When a call asks: once when it goes live, and once it has stayed ended for `endWait`, but only if its start went
/// out and wasn't refused. A redial within the call asks nothing, nor does a call that connects again within
/// `endWait` of ending (the mic heal hangs up and dials again); turning the switch off mid-call still ends what was
/// started.
public struct LiveHeartRatePlan: Equatable, Sendable {
  /// How long an ended call waits before its end is asked, in case it connects again as the same call.
  public static let endWait: TimeInterval = 5

  private var started = false
  private var startPending = false
  private var wasLive = false
  private var endedAt: Date?

  public init() {}

  /// The call has been live, redials included: a `.connecting` now is the same call's redial, not a new call.
  public var inCall: Bool { wasLive }

  /// The start's answer: from Exercise Analyzer, or the open failing. False when no start is waiting for one (a late
  /// answer for a call already over), which then changes nothing.
  public mutating func startAnswered(failed: Bool) -> Bool {
    guard startPending else { return false }
    startPending = false
    if failed { started = false }
    return true
  }

  public mutating func next(state: CallState, redialing: Bool, enabled: Bool, now: Date) -> LiveHeartRateLink.Action? {
    switch state {
    case .live:
      defer { wasLive = true }
      if !wasLive, enabled {
        started = true
        startPending = true
        return .start
      }
      return nil
    case .ended:
      if redialing || !wasLive { return nil }
      endedAt = now
      return nil
    case .connecting:
      guard let endedAt else { return nil }
      if now.timeIntervalSince(endedAt) < Self.endWait {
        self.endedAt = nil
        return nil
      }
      return finish()
    case .idle:
      return finish()
    }
  }

  /// Called once `endWait` has passed since the call ended: the end, if the call is still ended and asked to start.
  public mutating func endDue(now: Date) -> LiveHeartRateLink.Action? {
    guard let endedAt, now.timeIntervalSince(endedAt) >= Self.endWait else { return nil }
    return finish()
  }

  /// The app is leaving the foreground, where a link can't be opened: a held end goes now rather than be lost.
  public mutating func endNow() -> LiveHeartRateLink.Action? {
    guard endedAt != nil else { return nil }
    return finish()
  }

  private mutating func finish() -> LiveHeartRateLink.Action? {
    let end = started
    started = false
    startPending = false
    wasLive = false
    endedAt = nil
    return end ? .end : nil
  }
}
