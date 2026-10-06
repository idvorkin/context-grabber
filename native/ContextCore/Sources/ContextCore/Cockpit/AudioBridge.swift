//  The Cockpit audio bridge's wire format — the Swift port of lib/audioBridge.ts, byte-compatible with it so the
//  Cockpit page needs no change. Protocol: docs/cockpit-audio-bridge.md.
//
//  Why it exists: WebKit (every browser engine on iOS) enumerates one nameless microphone and zero outputs and has
//  no setSinkId, so the page's pickers hide inside the app. The roster is in AVAudioSession; this is the pipe.

import Foundation

/// A microphone or an output destination, as iOS names it. `id` is an AVAudioSession port UID, except the two
/// synthetic output ids `auto` and `speaker`, which name a routing decision rather than hardware.
public struct AudioDevice: Equatable, Sendable {
  public let id: String
  public let name: String
  public let type: String

  public init(id: String, name: String, type: String) {
    self.id = id
    self.name = name
    self.type = type
  }

  var fields: [String: Any] { ["id": id, "name": name, "type": type] }
}

/// What the page is told: the roster, what is actually carrying audio (never what was requested), and what this
/// build can do at all.
public struct AudioRouteSnapshot: Equatable, Sendable {
  public var inputs: [AudioDevice]
  public var outputs: [AudioDevice]
  public var currentInput: AudioDevice?
  public var currentOutput: AudioDevice?

  public init(inputs: [AudioDevice], outputs: [AudioDevice], currentInput: AudioDevice?, currentOutput: AudioDevice?) {
    self.inputs = inputs
    self.outputs = outputs
    self.currentInput = currentInput
    self.currentOutput = currentOutput
  }

  var fields: [String: Any] {
    [
      "inputs": inputs.map(\.fields),
      "outputs": outputs.map(\.fields),
      "current": [
        "input": currentInput?.fields ?? NSNull(),
        "output": currentOutput?.fields ?? NSNull(),
      ] as [String: Any],
      "capabilities": ["selectInput": true, "selectOutput": true, "forceSpeaker": true],
    ]
  }
}

/// Page → app: the four audio requests.
public enum BridgeRequest: Equatable, Sendable {
  case listDevices(requestId: String?)
  case getRoute(requestId: String?)
  /// `nil` id: hand the choice back to iOS.
  case setInput(id: String?, requestId: String?)
  case setOutput(port: String, requestId: String?)

  public var type: String {
    switch self {
    case .listDevices: return "audio.listDevices"
    case .getRoute: return "audio.getRoute"
    case .setInput: return "audio.setInput"
    case .setOutput: return "audio.setOutput"
    }
  }

  public var requestId: String? {
    switch self {
    case .listDevices(let r), .getRoute(let r), .setInput(_, let r), .setOutput(_, let r): return r
    }
  }
}

/// Page → app: the page's call asks for the app's call (#99).
public enum CallControl: Equatable, Sendable {
  case focus
  /// `nil`: the backend was missing or not one the app knows.
  case start(via: CallBackend?)
}

/// Everything the page can say on the channel.
public enum PageMessage: Equatable, Sendable {
  case audio(BridgeRequest)
  /// Only the page knows when its call is connecting, live or over; the screen is held for exactly that long.
  case callState(live: Bool)
  case call(CallControl)

  public var kind: String {
    switch self {
    case .audio(let request): return request.type
    case .callState: return "call.state"
    case .call(.focus): return "call.focus"
    case .call(.start): return "call.start"
    }
  }
}

public enum AudioBridge {
  /// Bumped only for a breaking change. New message types do not bump it.
  public static let version = 1
  /// The CustomEvent type the app dispatches on `window`.
  public static let event = "cockpit-audio"
  /// The global the page feature-detects on.
  public static let global = "CockpitAudioBridge"

  // MARK: - page → app

  private static func object(_ raw: Any?) -> [String: Any]? {
    guard let text = raw as? String, !text.isEmpty, let data = text.data(using: .utf8),
      let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    else { return nil }
    return parsed as? [String: Any]
  }

  /// A string field, and only a string: JSON numbers and nulls are not ids.
  private static func string(_ value: Any?) -> String? {
    value as? String
  }

  /// One message from the page. `nil` for anything that is not a well-formed bridge message — malformed JSON, a bare
  /// string, some other feature's traffic. The page owns postMessage and may use it for something else.
  public static func parse(_ raw: Any?) -> PageMessage? {
    guard let msg = object(raw), let type = string(msg["type"]) else { return nil }
    let requestId = string(msg["requestId"])
    switch type {
    case "audio.listDevices": return .audio(.listDevices(requestId: requestId))
    case "audio.getRoute": return .audio(.getRoute(requestId: requestId))
    case "audio.setInput":
      // Absent, null and "" all mean the same thing: the system default.
      let id = string(msg["id"])
      return .audio(.setInput(id: (id?.isEmpty ?? true) ? nil : id, requestId: requestId))
    case "audio.setOutput":
      // `id` is accepted as an alias of `port` for a page written against an early sketch of the protocol.
      guard let port = string(msg["port"]) ?? string(msg["id"]) else { return nil }
      return .audio(.setOutput(port: port, requestId: requestId))
    case "call.state":
      guard let live = msg["live"] as? Bool, isBool(msg["live"]) else { return nil }
      return .callState(live: live)
    case "call.focus":
      return .call(.focus)
    case "call.start":
      let via = string(msg["via"]) ?? string(msg["backend"])
      return .call(.start(via: via.flatMap(CallBackend.init(rawValue:))))
    default:
      return nil
    }
  }

  /// JSONSerialization hands back NSNumber for both 1 and true; only a JSON boolean is a boolean.
  private static func isBool(_ value: Any?) -> Bool {
    guard let number = value as? NSNumber else { return false }
    return CFGetTypeID(number) == CFBooleanGetTypeID()
  }

  // MARK: - app → page

  public static func readyPayload(available: Bool, platform: String = "ios") -> [String: Any] {
    ["type": "audio.ready", "version": version, "platform": platform, "available": available]
  }

  public static func devicesPayload(_ snapshot: AudioRouteSnapshot, requestId: String? = nil) -> [String: Any] {
    var payload = snapshot.fields
    payload["type"] = "audio.devices"
    if let requestId { payload["requestId"] = requestId }
    return payload
  }

  public static func routeChangedPayload(_ snapshot: AudioRouteSnapshot, reason: String) -> [String: Any] {
    var payload = snapshot.fields
    payload["type"] = "audio.routeChanged"
    payload["reason"] = reason
    return payload
  }

  public static func errorPayload(op: String, message: String, requestId: String? = nil) -> [String: Any] {
    var payload: [String: Any] = ["type": "audio.error", "op": op, "message": message.isEmpty ? "Unknown audio error" : message]
    if let requestId { payload["requestId"] = requestId }
    return payload
  }

  // MARK: - scripts

  /// The name of the WKScriptMessageHandler the page's messages arrive on.
  public static let messageHandler = "grabber"

  /// Installed at document start, so the page can feature-detect the bridge on its first line of script.
  ///
  /// The bridge itself is the React Native app's, character for character. In front of it, a
  /// `window.ReactNativeWebView` that forwards to WebKit's message handler: the bridge posts through it, and the page
  /// already takes it as the tell that it is inside the app. Trailing `true;`: an injected script whose last
  /// expression is not a primitive draws a warning on iOS.
  public static func installScript(platform: String = "ios") -> String {
    """
    (function () {
      if (window.ReactNativeWebView) return;
      var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(messageHandler);
      if (!h) return;
      window.ReactNativeWebView = { postMessage: function (m) { h.postMessage(String(m)); } };
    })();
    (function () {
      if (window.\(global) && window.\(global).version >= \(version)) return;
      function post(msg) {
        try { window.ReactNativeWebView.postMessage(JSON.stringify(msg)); } catch (e) {}
      }
      window.\(global) = {
        version: \(version),
        platform: \(jsString(platform)),
        last: null,
        post: post,
        listDevices: function (requestId) { post({ type: "audio.listDevices", requestId: requestId }); },
        getRoute: function (requestId) { post({ type: "audio.getRoute", requestId: requestId }); },
        setInput: function (id, requestId) { post({ type: "audio.setInput", id: id, requestId: requestId }); },
        setOutput: function (port, requestId) { post({ type: "audio.setOutput", port: port, requestId: requestId }); }
      };
    })();
    true;
    """
  }

  /// Deliver one payload: a CustomEvent on its own type (the page has its own `message` consumers), with `last`
  /// written first so a listener that attaches late can read it synchronously.
  public static func emitScript(_ payload: [String: Any]) -> String {
    """
    (function () {
      var detail = JSON.parse(\(jsString(json(payload))));
      if (window.\(global)) { window.\(global).last = detail; }
      try {
        window.dispatchEvent(new CustomEvent(\(jsString(event)), { detail: detail }));
      } catch (e) {}
    })();
    true;
    """
  }

  /// The payload as JSON text, keys sorted.
  public static func json(_ payload: [String: Any]) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data("{}".utf8)
    return String(decoding: data, as: UTF8.self)
  }

  /// A JS string literal for any text. A device name is whoever paired the headset's text, and it lands inside a
  /// script the app evaluates: JSON-encode it (slashes escaped, so `</script>` cannot close anything) and escape
  /// U+2028 / U+2029, which are line terminators inside a string literal on older engines.
  static func jsString(_ text: String) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: [text], options: [])) ?? Data("[\"\"]".utf8)
    let array = String(decoding: data, as: UTF8.self)
    return String(array.dropFirst().dropLast())
      .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
      .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
  }
}
