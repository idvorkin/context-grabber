//  The voice bridge's wire format, as the Call tab speaks it.
//
//  One WebSocket. Up: one `start` frame, then binary PCM16 @ 16 kHz mic frames and a few small JSON notices.
//  Down: binary PCM16 at the rate the `ready` frame names, and JSON events. Everything that makes the call a
//  conversation — turn-taking, barge-in, "hang up" meaning hang up, the idle rule, Larry's persona and tools —
//  is the bridge's. This file only knows how to say things to it and how to read what it says back.
//
//  Source of truth: `handle_browser`'s docstring in the Cockpit repo's `voice_bridge.py`.
//  Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md.

import Foundation

public enum CallBackend: String, CaseIterable, Sendable {
  case eleven, gemini, openai, drill

  public var label: String {
    switch self {
    case .eleven: return "ElevenLabs"
    case .gemini: return "Gemini"
    case .openai: return "OpenAI"
    case .drill: return "Drill"
    }
  }

  /// ElevenLabs — Tony's voice. Igor, 2026-08-29: "Let's default to the 11 labs Tony call."
  public static let `default` = CallBackend.eleven
}

/// The voice a call answers in (#98): Tony, the bridge's stock voice on its default model, or Igor, his own
/// clone, which is only worth hearing on `eleven_v3_conversational` — so picking Igor implies that model. A
/// re-clone changes the id and this constant with it.
public enum CallVoice: String, CaseIterable, Sendable {
  case tony, igor

  public static let `default` = CallVoice.tony

  public var label: String { self == .tony ? "Tony" : "Igor" }

  /// The backends whose voice is an ElevenLabs voice (the drill's clips are ElevenLabs too). On the others
  /// the pick is not sent.
  public static func hasPick(_ backend: CallBackend?) -> Bool { backend == .eleven || backend == .drill }

  /// The `voice` / `model` fields of the start frame for this backend and pick; "" is the bridge's default.
  public func frameFields(for backend: CallBackend) -> (voice: String, model: String) {
    guard Self.hasPick(backend), self == .igor else { return ("", "") }
    return ("Nvd5I2HGnOWHNU0ijNEy", "eleven_v3_conversational")
  }
}

/// Where Igor is, as the call tells the bridge (#107): one fix rides the start frame, one small frame follows
/// each significant move.
public struct CallLocation: Equatable, Sendable {
  public var lat: Double
  public var lon: Double
  /// Horizontal accuracy in metres, rounded; nil when iOS gave none.
  public var accuracyM: Int?
  /// When the fix was taken, ISO 8601 UTC.
  public var at: String
  /// The known place the fix falls inside, or nil.
  public var place: String?

  public init(lat: Double, lon: Double, accuracyM: Int?, at: String, place: String?) {
    self.lat = lat
    self.lon = lon
    self.accuracyM = accuracyM
    self.at = at
    self.place = place
  }

  /// What rides the wire — the bridge's snake_case for the accuracy.
  var fields: [String: Any] {
    ["lat": lat, "lon": lon, "accuracy_m": accuracyM ?? NSNull(), "at": at, "place": place ?? NSNull()]
  }

  /// One log line: `Home (±12 m)` or `47.6062, -122.3321 (±65 m)`.
  public var description: String {
    "\(place ?? "\(lat), \(lon)")" + (accuracyM.map { " (±\($0) m)" } ?? "")
  }
}

public enum BridgeMessage: Equatable, Sendable {
  case ready(outRate: Double, backend: String, session: String)
  case micAck(token: Int)
  case transcript(who: String, text: String, source: String?)
  case sttPartial(text: String)
  case sttFinal(text: String)
  case interrupted
  case turnEnd
  case toolCall(question: String)
  case toolResult(ok: Bool, answer: String)
  case consultProgress(stage: String, text: String)
  case injected(text: String)
  case warning(message: String)
  case error(message: String)
  case vendorClosed(kind: String, message: String)
  case closed(reason: String)
}

public enum CallProtocol {
  /// How the call introduces itself, so the bridge's records can tell app from browser (#78).
  public static let clientName = "context-grabber"

  /// Where the bridge is, given where the Cockpit page is. Over https Tailscale Serve mounts the bridge at
  /// `/bridge`; on plain http it is its own port.
  public static func bridgeURL(cockpit: String) -> String? {
    guard let url = URLComponents(string: cockpit), let host = url.host else { return nil }
    if url.scheme == "https" { return "wss://\(host)\(url.port.map { ":\($0)" } ?? "")/bridge" }
    return "ws://\(host):8780"
  }

  // MARK: - outbound

  private static func json(_ object: [String: Any]) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
    return String(decoding: data, as: UTF8.self)
  }

  /// Empty model / voice = the vendor's default. `client` / `build` / `location` are extra keys; a bridge that
  /// does not know them ignores them.
  public static func startFrame(
    backend: CallBackend, build: String = "", voice: String = "", model: String = "", location: CallLocation? = nil
  ) -> String {
    var frame: [String: Any] = [
      "type": "start", "backend": backend.rawValue, "model": model, "voice": voice, "client": clientName,
      "build": build,
    ]
    if let location { frame["location"] = location.fields }
    return json(frame)
  }

  /// Where Igor is now, mid-call — after a significant move, or a fix that landed after the start.
  public static func locationFrame(_ location: CallLocation) -> String {
    json(location.fields.merging(["type": "location"]) { _, new in new })
  }

  public static func sttStartFrame() -> String { json(["type": "stt_start", "rate": 16000]) }
  public static func sttStopFrame() -> String { json(["type": "stt_stop"]) }
  public static func stopFrame() -> String { json(["type": "stop"]) }

  /// A notice, not a control: the client already stopped sending audio.
  public static func micFrame(muted: Bool) -> String { json(["type": "mic", "muted": muted]) }
  public static func micProbeFrame(token: Int) -> String { json(["type": "mic_probe", "token": token]) }

  /// The app's diagnostics, for the bridge to file beside the call (#92).
  public static func diagnosticsFrame(build: String, text: String) -> String {
    json(["type": "diagnostics", "build": build, "text": text])
  }

  // MARK: - inbound

  /// The rate the page assumes when a bridge is too old to say.
  private static let defaultOutRate = 24000.0

  /// nil for junk and for every event the screen does not render (`turn_metrics`, `stt_ready`, the control-path
  /// replies…). Ignoring is the contract: the bridge adds event types faster than any client renders them.
  public static func parse(_ raw: String?) -> BridgeMessage? {
    guard let raw, !raw.isEmpty,
      let m = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
    else { return nil }
    func str(_ key: String) -> String { m[key] as? String ?? "" }
    switch m["type"] as? String {
    case "ready":
      let rate = (m["out_rate"] as? NSNumber)?.doubleValue ?? 0
      return .ready(outRate: rate > 0 ? rate : defaultOutRate, backend: str("backend"), session: str("session"))
    case "mic_ack":
      // The bridge has sent the token as a number and as a string; -1 is "no token I can read".
      let token = (m["token"] as? NSNumber)?.intValue ?? Int(str("token")) ?? -1
      return .micAck(token: token)
    case "transcript": return .transcript(who: str("who"), text: str("text"), source: m["source"] as? String)
    case "stt_partial": return .sttPartial(text: str("text"))
    case "stt_final": return .sttFinal(text: str("text"))
    case "interrupted": return .interrupted
    case "turn_end": return .turnEnd
    case "tool_call": return .toolCall(question: str("question"))
    case "tool_result": return .toolResult(ok: (m["ok"] as? Bool) != false, answer: str("answer"))
    case "consult_progress": return .consultProgress(stage: str("stage"), text: str("text"))
    case "injected": return .injected(text: str("text"))
    case "warning": return .warning(message: str("message"))
    case "error": return .error(message: str("message"))
    case "vendor_closed": return .vendorClosed(kind: str("kind"), message: str("message"))
    case "closed": return .closed(reason: str("reason"))
    default: return nil
    }
  }

  // MARK: - endings

  /// The client's own reason for a socket that dropped without a `closed`.
  public static let connectionLost = "connection lost"
  /// The bridge's reason for a tap on Hang up.
  public static let stopped = "stopped"

  /// The bridge's reason → what the screen says. An unrecognised reason is printed verbatim, because giving a
  /// failure a cause it did not state is worse than an unfamiliar sentence.
  public static func endingText(_ reason: String?) -> String {
    switch reason {
    case "idle timeout": return "idle 2 min"
    case "hangup intent": return "hang-up intent"
    case nil, "": return "session ended"
    case .some(let other): return other
    }
  }
}
