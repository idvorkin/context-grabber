//  This launch's call events, as the Diagnostics fold shows them, *Copy diagnostics* copies them, the bridge's
//  hang-up dump carries them and a gist uploads them. The session log on disk has the same events; this is the
//  in-memory copy the screen reads, so nothing re-parses the file.
//
//  Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md ("Diagnostics") and step 3 of
//  docs/superpowers/specs/2026-10-04-swift-native-app-design.md.

import Foundation

public struct CallEvent: @unchecked Sendable {
  /// Milliseconds since the launch, the session log's `t`.
  public let t: Int
  public let type: String
  public let fields: [String: Any]

  public init(t: Int, type: String, fields: [String: Any]) {
    self.t = t
    self.type = type
    self.fields = fields
  }

  /// `+12.3s call_ready backend=eleven out_rate=16000` — keys sorted, so two runs diff cleanly.
  public var line: String {
    let stamp = String(format: "+%.1fs", Double(t) / 1000)
    let pairs = fields.keys.sorted().map { "\($0)=\(Self.render(fields[$0]!))" }
    return ([stamp, type] + pairs).joined(separator: " ")
  }

  private static func render(_ value: Any) -> String {
    switch value {
    case let b as Bool: return b ? "true" : "false"
    case let d as Double: return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(format: "%.2f", d)
    case let s as String: return s.contains(" ") || s.isEmpty ? "\"\(s)\"" : s
    default: return "\(value)"
    }
  }
}

public final class CallEventLog {
  /// Room for many calls; a launch that outlives it keeps the newest.
  public static let maxEvents = 4000
  /// Between calls: a retry must never hide the call it retried (#92).
  public static let separator = "──────── call ────────"

  public private(set) var events: [CallEvent] = []
  private let limit: Int

  public init(limit: Int = CallEventLog.maxEvents) {
    self.limit = limit
  }

  public func add(_ type: String, t: Int, fields: [String: Any]) {
    events.append(CallEvent(t: t, type: type, fields: fields))
    if events.count > limit { events.removeFirst(events.count - limit) }
  }

  /// The events since the latest `call_start` (all of them before the first call).
  public var currentCall: ArraySlice<CallEvent> {
    guard let i = events.lastIndex(where: { $0.type == "call_start" }) else { return events[...] }
    return events[i...]
  }

  /// One line per event, oldest first, a rule before every call but a first one at the top.
  public var lines: [String] {
    var out: [String] = []
    for event in events {
      if event.type == "call_start", !out.isEmpty { out.append(Self.separator) }
      out.append(event.line)
    }
    return out
  }

  /// Everything on the clipboard: header lines first, then the log.
  public func render(header: [(String, String)]) -> String {
    let head = header.filter { !$0.1.isEmpty }.map { "\($0.0): \($0.1)" }
    return (head + ["---"] + lines).joined(separator: "\n")
  }

  /// A call whose log says something went wrong: the audio healed itself, a problem reached the screen, a step
  /// failed, or it ended badly. The trigger is what the log says, so anything it learns to say is covered.
  public static func hadTrouble<S: Sequence>(_ events: S) -> Bool where S.Element == CallEvent {
    events.contains { e in
      if e.type == "call_heal" { return true }
      if e.type == "call_problem", let p = e.fields["problem"] as? String, !p.isEmpty { return true }
      if e.type == "call_ended", e.fields["badly"] as? Bool == true { return true }
      return e.type.hasPrefix("call_") && e.fields["ok"] as? Bool == false
    }
  }
}
