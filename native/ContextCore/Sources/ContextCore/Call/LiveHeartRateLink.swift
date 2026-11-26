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

/// When a call asks: once when it goes live, and once when it ends, but only if its start went out and wasn't
/// refused. A redial within the call asks nothing; turning the switch off mid-call still ends what was started.
public struct LiveHeartRatePlan: Equatable, Sendable {
  private var started = false
  private var wasLive = false

  public init() {}

  /// The call has been live, redials included: a `.connecting` now is the same call's redial, not a new call.
  public var inCall: Bool { wasLive }

  /// The start never reached Exercise Analyzer, or it answered that it couldn't start: the call's end asks nothing.
  public mutating func startFailed() {
    started = false
  }

  public mutating func next(state: CallState, redialing: Bool, enabled: Bool) -> LiveHeartRateLink.Action? {
    switch state {
    case .live:
      defer { wasLive = true }
      if !wasLive, enabled {
        started = true
        return .start
      }
      return nil
    case .ended:
      if redialing { return nil }
      wasLive = false
      if started {
        started = false
        return .end
      }
      return nil
    case .idle:
      wasLive = false
      return nil
    case .connecting:
      return nil
    }
  }
}
