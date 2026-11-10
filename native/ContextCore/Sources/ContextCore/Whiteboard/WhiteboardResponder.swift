//  Who answers a board's pause (spec 2026-11-01-whiteboard-shapes-design.md, *Who answers the pause*, stories 659,
//  661): the board's knob on the Cockpit (`GET`/`POST /whiteboard/responder`, whiteboard.py), what the menu ticks
//  while it is read and written, when a ghost turn's answer hands the board to Larry instead, and the iPad's timings
//  for each turn.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum WhiteboardResponder: String, CaseIterable, Sendable {
  case haiku, sonnet, larry

  /// The Cockpit's default: who answers a board nobody has set, and what the menu ticks until the Cockpit says.
  public static let fallback: WhiteboardResponder = .sonnet

  /// The menu's word for it.
  public var name: String {
    switch self {
    case .haiku: "Haiku"
    case .sonnet: "Sonnet"
    case .larry: "Larry"
    }
  }

  /// A read or a write of the knob waits this long: it is a file on the Cockpit, no model.
  public static let timeout: TimeInterval = 5

  public static func readRequest(board: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit),
      var parts = URLComponents(
        url: base.appendingPathComponent("whiteboard").appendingPathComponent("responder"),
        resolvingAgainstBaseURL: false)
    else { throw URLError(.badURL) }
    parts.queryItems = [URLQueryItem(name: "board", value: board)]
    guard let url = parts.url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    return request
  }

  public static func writeRequest(
    _ responder: WhiteboardResponder, board: String, cockpit: String
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("responder"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["board": board, "responder": responder.rawValue])
    return request
  }

  public enum Reply: Equatable, Sendable {
    case responder(WhiteboardResponder)
    /// What went wrong, for the log and the copyable problem; `status` nil when no answer came.
    case failed(reason: String, status: Int?)
  }

  /// A read's or a write's answer: both are the board's `{ok, responder, …}`.
  public static func reply(status: Int?, body: Data?, error: String? = nil) -> Reply {
    guard let status else { return .failed(reason: error ?? "no answer", status: nil) }
    let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    if status == 200, json?["ok"] as? Bool == true, let responder = of(json?["responder"]) {
      return .responder(responder)
    }
    let reason = (json?["error"] as? String) ?? (status == 200 ? "no responder in the answer" : "HTTP \(status)")
    return .failed(reason: reason, status: status)
  }

  /// A `responder` field; nil for none or one this build doesn't know.
  static func of(_ any: Any?) -> WhiteboardResponder? {
    (any as? String).flatMap(WhiteboardResponder.init(rawValue:))
  }

  /// Who answered a ghost turn, from its whole JSON answer or its stream's last line.
  static func of(body: Data) -> WhiteboardResponder? {
    of((try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["responder"])
  }

  public enum HandOff: Equatable, Sendable {
    /// Claude answered (or no one did): nothing for Larry.
    case nothing
    /// The board is Larry's: `WhiteboardLarryTurn.paused` says whether its picture goes now.
    case hand
    /// A Larry board, but not this time: the reason, for the log.
    case skipped(String)
  }

  /// What a ghost turn's answer means for Larry: on a Larry board the Cockpit answers with no marks and says so, and
  /// the board is his instead (`WhiteboardLarryTurn` says whether a picture goes now or waits for his answer), unless
  /// the turn was sent away or the board's first Send still waits (a second picture now would start a second thread).
  public static func handOff(
    answered: WhiteboardResponder?, answer: WhiteboardTurn.Answer, stale: Bool, firstSendWaiting: Bool
  ) -> HandOff {
    guard answered == .larry, case .shapes(let shapes) = answer, shapes.isEmpty else { return .nothing }
    if stale { return .skipped("stale") }
    if firstSendWaiting { return .skipped("first_send_waiting") }
    return .hand
  }
}

/// The board's knob as the menu shows it: what is ticked, while the Cockpit is read and each choice is written.
public struct WhiteboardResponderKnob: Equatable, Sendable {
  /// What the menu ticks.
  public private(set) var shown: WhiteboardResponder = .fallback
  /// The Cockpit has said which one the board has.
  public private(set) var known = false
  /// What the Cockpit last said: where a failed choice goes back to.
  private var confirmed: WhiteboardResponder = .fallback
  /// A choice on its way to the Cockpit.
  private var pending: WhiteboardResponder?
  private var choices = 0

  public init() {}

  /// Pass this with a look at the Cockpit (the read on open, a ghost turn): its answer counts only if Igor has chosen
  /// nothing since.
  public var generation: Int { choices }

  /// The Cockpit said the board's responder, in an answer asked under `asked`. A choice of Igor's made since, or one
  /// still on its way, wins over it.
  public mutating func heard(_ responder: WhiteboardResponder, asked: Int) {
    guard asked == choices, pending == nil else { return }
    confirmed = responder
    shown = responder
    known = true
  }

  /// Igor picked one. Returns the choice's number to hand back to `wrote`, or nil when there is nothing to write: it is
  /// already the board's.
  public mutating func chose(_ responder: WhiteboardResponder) -> Int? {
    guard responder != shown || (!known && pending == nil) else { return nil }
    choices += 1
    pending = responder
    shown = responder
    return choices
  }

  /// The Cockpit answered choice `choice`: the responder it now has, or nil when the write failed. True when the tick
  /// went back. An older choice's answer only updates what the Cockpit has; the newest choice still shows.
  @discardableResult
  public mutating func wrote(_ responder: WhiteboardResponder?, choice: Int) -> Bool {
    if let responder {
      confirmed = responder
      known = true
    }
    guard choice == choices else { return false }
    pending = nil
    let before = shown
    shown = responder ?? confirmed
    return responder == nil && shown != before
  }
}

/// How long the iPad's half of a ghost turn took (story 661): the pause, drawing the picture, encoding it and uploading
/// the request.
public struct WhiteboardTimings: Equatable, Sendable {
  public var pause: Duration?
  public var render: Duration?
  public var encode: Duration?
  public var upload: Duration?

  public init(pause: Duration? = nil, render: Duration? = nil, encode: Duration? = nil, upload: Duration? = nil) {
    self.pause = pause
    self.render = render
    self.encode = encode
    self.upload = upload
  }

  /// Whole milliseconds, rounded; nil for a negative span, which no real one is.
  public static func ms(_ span: Duration) -> Int? {
    let (seconds, atto) = span.components
    let ms = (Double(seconds) * 1000 + Double(atto) / 1e15).rounded()
    return ms >= 0 ? Int(ms) : nil
  }

  /// What `POST /whiteboard/suggest` carries as `timings`: only what is known before the request goes. The upload isn't
  /// until it has gone, so it is in the session log alone.
  public var wire: [String: Int] {
    fields([("pause_ms", pause), ("render_ms", render), ("encode_ms", encode)])
  }

  /// The turn's `whiteboard_turn` line: all four.
  public var logFields: [String: Int] {
    fields([("pause_ms", pause), ("render_ms", render), ("encode_ms", encode), ("upload_ms", upload)])
  }

  private func fields(_ spans: [(String, Duration?)]) -> [String: Int] {
    var out: [String: Int] = [:]
    for (name, span) in spans {
      if let span, let ms = Self.ms(span) { out[name] = ms }
    }
    return out
  }
}
