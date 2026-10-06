//  The audio route's rules, apart from AVAudioSession so the host can check them: which outputs are offered, how the
//  page's output words map to iOS's moves, what "the route already matches" means for re-asserting a choice.
//  Ported from modules/audio-route (the React Native app's AudioRouteModule.swift). Port types are AVAudioSession's
//  raw strings.

import Foundation

public enum AudioRouting {
  /// Synthetic output ids: no override (iOS picks), and force the built-in speaker.
  public static let auto = "auto"
  public static let speaker = "speaker"

  /// AVAudioSession.Port raw values the rules name.
  public enum Port {
    public static let builtInSpeaker = "Speaker"
    public static let builtInReceiver = "Receiver"
    public static let bluetoothHFP = "BluetoothHFP"
    public static let usbAudio = "USBAudio"
    public static let carAudio = "CarAudio"
    public static let headsetMic = "MicrophoneWired"
    public static let lineIn = "LineIn"
  }

  /// A port output can be steered to by naming its input: pointing the preferred input at a headset takes the
  /// output along.
  public static func isSteerableOutput(_ type: String) -> Bool {
    [Port.bluetoothHFP, Port.usbAudio, Port.carAudio, Port.headsetMic, Port.lineIn].contains(type)
  }

  /// Always Automatic and Speaker, plus each destination the phone can reach now: steerable inputs, and whatever is
  /// already playing that is not the phone itself (A2DP headphones never show up as an input). Nothing unreachable
  /// is listed: an option that cannot be honoured is a control that lies.
  public static func outputs(availableInputs: [AudioDevice], routeOutputs: [AudioDevice]) -> [AudioDevice] {
    var seen: Set<String> = [auto, speaker]
    var list = [
      AudioDevice(id: auto, name: "Automatic", type: "auto"),
      AudioDevice(id: speaker, name: "Speaker", type: Port.builtInSpeaker),
    ]
    for port in availableInputs where isSteerableOutput(port.type) && seen.insert(port.id).inserted {
      list.append(port)
    }
    for port in routeOutputs
    where port.type != Port.builtInSpeaker && port.type != Port.builtInReceiver && seen.insert(port.id).inserted {
      list.append(port)
    }
    return list
  }

  /// The live output as the page sees it: the speaker under its synthetic id, so the page can round-trip what it
  /// reads in `outputs[]` straight back into setOutput.
  public static func currentOutput(_ port: AudioDevice?) -> AudioDevice? {
    guard let port else { return nil }
    return port.type == Port.builtInSpeaker ? AudioDevice(id: speaker, name: port.name, type: port.type) : port
  }

  /// `auto`, `default`, `receiver`, `earpiece`, `none` and "" all mean: drop the override and let iOS choose.
  public static func canonicalOutput(_ raw: String) -> String {
    switch raw.lowercased() {
    case "", "auto", "default", "none", "receiver", "earpiece": return auto
    case "speaker", "builtinspeaker": return speaker
    default: return raw
    }
  }

  /// What a requested output asks of the session.
  public enum OutputMove: Equatable, Sendable {
    /// Drop any override.
    case clearOverride
    case forceSpeaker
    /// Clear the override and prefer this input: its output comes along.
    case preferInput(uid: String)
    /// Output-only (A2DP headphones) and already playing: clearing the override is all there is to do.
    case alreadyThere
    case unavailable
  }

  public static func outputMove(for raw: String, availableInputs: [AudioDevice], routeOutputs: [AudioDevice])
    -> OutputMove
  {
    let wanted = canonicalOutput(raw)
    if wanted == auto { return .clearOverride }
    if wanted == speaker { return .forceSpeaker }
    if availableInputs.contains(where: { $0.id == wanted }) { return .preferInput(uid: wanted) }
    if routeOutputs.contains(where: { $0.id == wanted }) { return .alreadyThere }
    return .unavailable
  }

  /// Whether the live route already honours a remembered output choice; re-asserting is skipped when it does, which
  /// is what keeps a re-assert from looping on the route change it causes.
  public static func outputSatisfied(_ desired: String, routeOutputs: [AudioDevice]) -> Bool {
    switch desired {
    case auto: return true  // no override to hold; iOS owns the choice
    case speaker: return routeOutputs.contains { $0.type == Port.builtInSpeaker }
    default: return routeOutputs.contains { $0.id == desired }
    }
  }

  /// A remembered input is satisfied when it is the live one; "system default" (nil) only when nothing is preferred.
  public static func inputSatisfied(_ desired: String?, liveInput: String?, preferredInput: String?) -> Bool {
    guard let desired else { return preferredInput == nil }
    return liveInput == desired
  }

  /// A choice the session refuses this many times running is dropped rather than retried on every route change.
  public static let maxReassertFailures = 2

  /// iOS's own word for why the route moved (AVAudioSession.RouteChangeReason's raw value).
  public static func reasonName(_ raw: UInt) -> String {
    switch raw {
    case 1: return "newDeviceAvailable"
    case 2: return "oldDeviceUnavailable"
    case 3: return "categoryChange"
    case 4: return "override"
    case 6: return "wakeFromSleep"
    case 7: return "noSuitableRouteForCategory"
    case 8: return "routeConfigurationChange"
    default: return "unknown"
    }
  }
}
