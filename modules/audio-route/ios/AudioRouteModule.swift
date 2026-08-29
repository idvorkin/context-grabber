import AVFoundation
import ExpoModulesCore

/**
 Reads and steers the iOS audio route on behalf of the Cockpit web view.

 WebKit — which is every browser engine on iOS, the app's `WKWebView`
 included — enumerates one nameless audio input and zero audio outputs, and
 implements no `setSinkId`. So the Cockpit's device pickers have nothing to
 build a control out of and correctly hide themselves. The roster and the
 routing controls do exist, one layer down, in `AVAudioSession`. This module
 is the pipe to that layer; the protocol on top of it is documented in
 `docs/cockpit-audio-bridge.md`.

 It does no capture. The page's own `getUserMedia` still records; this only
 decides which microphone it records from and where playback lands.
 */
public class AudioRouteModule: Module {
  /// Synthetic output id: force the built-in speaker.
  private static let outputSpeaker = "speaker"
  /// Synthetic output id: no override, let iOS pick. Aliases are resolved in
  /// `canonicalOutputId` so a page written against an early sketch of the
  /// protocol still works.
  private static let outputAuto = "auto"

  private var routeObserver: NSObjectProtocol?

  /// What the page last asked for, re-asserted when the route changes under
  /// us. `nil` means it never asked, which is different from asking for the
  /// system default — we only fight for a route somebody actually chose.
  private var desiredInputUID: String?
  private var hasInputPreference = false
  private var desiredOutputID: String?

  /// A request the session refuses twice running is dropped rather than
  /// re-attempted forever on every route change.
  private var inputReassertFailures = 0
  private var outputReassertFailures = 0
  private static let maxReassertFailures = 2

  public func definition() -> ModuleDefinition {
    Name("AudioRoute")

    Events("onRouteChange")

    /// Present at all on this build. Guards the JS side against a stale
    /// binary where the pod was never installed.
    Function("isAvailable") { () -> Bool in
      true
    }

    /// Put the session in a shape where `availableInputs` is populated and
    /// an output override is legal — i.e. `.playAndRecord` with Bluetooth
    /// allowed. Called when the Cockpit tab first becomes visible.
    AsyncFunction("activate") { () -> [String: Any] in
      try self.configureSession()
      return self.snapshot()
    }

    Function("getDevices") { () -> [String: Any] in
      self.snapshot()
    }

    /// `nil` or `""` clears the preference and hands the choice back to iOS.
    AsyncFunction("setInput") { (uid: String?) -> [String: Any] in
      try self.applyInput(uid, remember: true)
      return self.snapshot()
    }

    AsyncFunction("setOutput") { (port: String) -> [String: Any] in
      try self.applyOutput(port, remember: true)
      return self.snapshot()
    }

    OnStartObserving {
      self.startObservingRoute()
    }

    OnStopObserving {
      self.stopObservingRoute()
    }

    OnDestroy {
      self.stopObservingRoute()
    }
  }

  // MARK: - session

  private var session: AVAudioSession { AVAudioSession.sharedInstance() }

  /// `.playAndRecord` is what makes `availableInputs` list anything beyond
  /// the built-in microphone and what makes `overrideOutputAudioPort` legal.
  /// `.defaultToSpeaker` is why "Automatic" on a bare phone means the
  /// speaker rather than the earpiece — nobody holds a dashboard to their ear.
  ///
  /// expo-audio configures the same session for voice notes. Both converge on
  /// `.playAndRecord`; last writer wins on the option set, and every option
  /// here is additive, so the overlap is benign.
  private func configureSession() throws {
    var options: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .defaultToSpeaker]
    #if compiler(>=6.2) // Xcode 26 renamed .allowBluetooth
    options.insert(.allowBluetoothHFP)
    #else
    options.insert(.allowBluetooth)
    #endif
    // A live call runs the session in `.voiceChat` (echo cancellation via
    // VoiceProcessingIO). Re-activating for the roster — the Call tab does
    // it on every mount — must not downgrade that to `.default` mid-call.
    let mode: AVAudioSession.Mode = session.mode == .voiceChat ? .voiceChat : .default
    try session.setCategory(.playAndRecord, mode: mode, options: options)
    try session.setActive(true)
  }

  // MARK: - reading the route

  private func describe(_ port: AVAudioSessionPortDescription) -> [String: Any] {
    ["id": port.uid, "name": port.portName, "type": port.portType.rawValue]
  }

  private func inputList() -> [[String: Any]] {
    (session.availableInputs ?? []).map(describe)
  }

  /// A port we can steer output to by naming it. Bluetooth headsets and wired
  /// or USB headsets appear in `availableInputs`, and pointing the session's
  /// preferred *input* at them takes the output along.
  private func isSteerableOutput(_ type: AVAudioSession.Port) -> Bool {
    switch type {
    case .bluetoothHFP, .usbAudio, .carAudio, .headsetMic, .lineIn:
      return true
    default:
      return false
    }
  }

  /// Always `auto` and `speaker`, plus one entry per destination the phone
  /// can currently reach. Nothing that is not plugged in or paired is listed:
  /// an option that cannot be honored is a control that lies.
  private func outputList() -> [[String: Any]] {
    var seen = Set<String>([Self.outputAuto, Self.outputSpeaker])
    var outputs: [[String: Any]] = [
      ["id": Self.outputAuto, "name": "Automatic", "type": "auto"],
      [
        "id": Self.outputSpeaker,
        "name": "Speaker",
        "type": AVAudioSession.Port.builtInSpeaker.rawValue,
      ],
    ]

    for port in session.availableInputs ?? [] where isSteerableOutput(port.portType) {
      if seen.insert(port.uid).inserted {
        outputs.append(describe(port))
      }
    }

    // A2DP headphones never show up as an input, so they would otherwise be
    // invisible here even while they are the thing playing the audio.
    for port in session.currentRoute.outputs
    where port.portType != .builtInSpeaker && port.portType != .builtInReceiver {
      if seen.insert(port.uid).inserted {
        outputs.append(describe(port))
      }
    }

    return outputs
  }

  /// What is *actually* carrying audio, read off `currentRoute` — never what
  /// was requested. The dashboard's confirmer line is only worth anything if
  /// this is the honest answer.
  private func currentRoute() -> [String: Any] {
    let route = session.currentRoute
    var current: [String: Any] = ["input": NSNull(), "output": NSNull()]

    if let input = route.inputs.first {
      current["input"] = describe(input)
    }
    if let output = route.outputs.first {
      var described = describe(output)
      // The speaker's synthetic id, so a page can round-trip what it sees in
      // `outputs[]` straight back into `setOutput`.
      if output.portType == .builtInSpeaker {
        described["id"] = Self.outputSpeaker
      }
      current["output"] = described
    }

    return current
  }

  private func snapshot(reason: String? = nil) -> [String: Any] {
    var payload: [String: Any] = [
      "inputs": inputList(),
      "outputs": outputList(),
      "current": currentRoute(),
      "capabilities": [
        "selectInput": true,
        "selectOutput": true,
        "forceSpeaker": true,
      ],
    ]
    if let reason {
      payload["reason"] = reason
    }
    return payload
  }

  // MARK: - steering the route

  private func port(withUID uid: String) -> AVAudioSessionPortDescription? {
    (session.availableInputs ?? []).first { $0.uid == uid }
  }

  private func applyInput(_ uid: String?, remember: Bool) throws {
    let wanted = (uid?.isEmpty ?? true) ? nil : uid

    if remember {
      desiredInputUID = wanted
      hasInputPreference = true
      inputReassertFailures = 0
    }

    guard let wanted else {
      try session.setPreferredInput(nil)
      return
    }
    guard let target = port(withUID: wanted) else {
      throw InputNotAvailableException(wanted)
    }
    try session.setPreferredInput(target)
  }

  /// `auto`, `default`, `receiver`, `none`, and the empty string all mean the
  /// same thing: drop the override and let iOS choose.
  private func canonicalOutputId(_ raw: String) -> String {
    switch raw.lowercased() {
    case "", "auto", "default", "none", "receiver", "earpiece":
      return Self.outputAuto
    case "speaker", "builtinspeaker":
      return Self.outputSpeaker
    default:
      return raw
    }
  }

  private func applyOutput(_ raw: String, remember: Bool) throws {
    let wanted = canonicalOutputId(raw)

    if remember {
      desiredOutputID = wanted
      outputReassertFailures = 0
    }

    switch wanted {
    case Self.outputAuto:
      try session.overrideOutputAudioPort(.none)
    case Self.outputSpeaker:
      try session.overrideOutputAudioPort(.speaker)
    default:
      if let target = port(withUID: wanted) {
        // Naming a headset's input port takes its output along with it.
        try session.overrideOutputAudioPort(.none)
        try session.setPreferredInput(target)
      } else if session.currentRoute.outputs.contains(where: { $0.uid == wanted }) {
        // Output-only (A2DP headphones): iOS is already routing there, and
        // clearing the override is the whole of what we can do about it.
        try session.overrideOutputAudioPort(.none)
      } else {
        throw OutputNotAvailableException(wanted)
      }
    }
  }

  // MARK: - route changes

  private func startObservingRoute() {
    guard routeObserver == nil else { return }
    routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleRouteChange(notification)
    }
  }

  private func stopObservingRoute() {
    if let routeObserver {
      NotificationCenter.default.removeObserver(routeObserver)
    }
    routeObserver = nil
  }

  private func handleRouteChange(_ notification: Notification) {
    let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
    let reason = AVAudioSession.RouteChangeReason(rawValue: raw ?? 0) ?? .unknown

    reassertDesiredRoute()
    // mapValues to spell the optional-valued dictionary sendEvent wants,
    // rather than leaning on an implicit collection conversion.
    let payload = snapshot(reason: name(for: reason))
    sendEvent("onRouteChange", payload.mapValues { $0 as Any? })
  }

  /// The web view's own `getUserMedia` reconfigures the session when capture
  /// starts, which can undo a route chosen before the call began. Re-asserting
  /// here is what makes "pick the headset, then start the call" work.
  ///
  /// Cannot loop: an override raises another route change whose re-assert
  /// finds the route already matching and does nothing.
  private func reassertDesiredRoute() {
    if hasInputPreference, inputReassertFailures < Self.maxReassertFailures {
      let live = session.currentRoute.inputs.first?.uid
      if live != desiredInputUID {
        do {
          try applyInput(desiredInputUID, remember: false)
          inputReassertFailures = 0
        } catch {
          inputReassertFailures += 1
        }
      } else {
        inputReassertFailures = 0
      }
    }

    if let desiredOutputID, outputReassertFailures < Self.maxReassertFailures {
      let outputs = session.currentRoute.outputs
      let satisfied: Bool
      switch desiredOutputID {
      case Self.outputAuto:
        satisfied = true // no override to hold; iOS owns the choice
      case Self.outputSpeaker:
        satisfied = outputs.contains { $0.portType == .builtInSpeaker }
      default:
        satisfied = outputs.contains { $0.uid == desiredOutputID }
      }
      if satisfied {
        outputReassertFailures = 0
      } else {
        do {
          try applyOutput(desiredOutputID, remember: false)
          outputReassertFailures = 0
        } catch {
          outputReassertFailures += 1
        }
      }
    }
  }

  private func name(for reason: AVAudioSession.RouteChangeReason) -> String {
    switch reason {
    case .newDeviceAvailable: return "newDeviceAvailable"
    case .oldDeviceUnavailable: return "oldDeviceUnavailable"
    case .categoryChange: return "categoryChange"
    case .override: return "override"
    case .wakeFromSleep: return "wakeFromSleep"
    case .noSuitableRouteForCategory: return "noSuitableRouteForCategory"
    case .routeConfigurationChange: return "routeConfigurationChange"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }
}

internal final class InputNotAvailableException: GenericException<String> {
  override var reason: String {
    "Input not available: \(param)"
  }
}

internal final class OutputNotAvailableException: GenericException<String> {
  override var reason: String {
    "Output not available: \(param)"
  }
}
