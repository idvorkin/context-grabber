//  Reset audio (story 149): let go of everything this app holds on the phone's audio and tell other apps they may
//  resume. It cannot reach another app's session or the phone's audio service; it clears what this app left behind.

import AVFoundation

enum AudioReset {
  struct State: Equatable {
    var route: String
    var category: String
    var otherAudio: Bool

    var line: String { "\(route)\(otherAudio ? " · other audio playing" : "")" }
  }

  static func state() -> State {
    let s = AVAudioSession.sharedInstance()
    let route = s.currentRoute
    let input = route.inputs.map(\.portName).joined(separator: ", ")
    let output = route.outputs.map(\.portName).joined(separator: ", ")
    return State(
      route: "\(input.isEmpty ? "no microphone" : input) · \(output.isEmpty ? "no output" : output)",
      category: s.category.rawValue.replacingOccurrences(of: "AVAudioSessionCategory", with: ""),
      otherAudio: s.isOtherAudioPlaying)
  }

  /// Every step is tried; the failures come back by name so the log says which one iOS refused.
  static func reset() -> [String: String] {
    let s = AVAudioSession.sharedInstance()
    var failed: [String: String] = [:]
    func step(_ name: String, _ body: () throws -> Void) {
      do { try body() } catch { failed[name] = "\(error)" }
    }
    step("speaker_override") { try s.overrideOutputAudioPort(.none) }
    step("preferred_input") { try s.setPreferredInput(nil) }
    // Deactivating is what lifts the ducking and lets a paused podcast resume.
    step("deactivate") { try s.setActive(false, options: .notifyOthersOnDeactivation) }
    // Left as the quietest category, so nothing this app does next interrupts other audio by surprise.
    step("category") { try s.setCategory(.ambient, mode: .default, options: [.mixWithOthers]) }
    return failed
  }
}
