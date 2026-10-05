//  The phone's real microphones and outputs, for the Cockpit page (story 097): reads and steers AVAudioSession on
//  the page's behalf. The Swift port of modules/audio-route; the rules (which outputs are offered, what each output
//  word asks of the session, when a remembered choice is already honoured) are AudioRouting in ContextCore.
//
//  It does no capture: the page's own getUserMedia still records. It only decides which microphone that is and
//  where playback lands, and puts a choice back when the route moves under it (the page's capture starting is the
//  usual cause — AGENTS.md, "WebKit enumerates one nameless microphone").

import AVFoundation
import ContextCore
import Foundation

struct AudioRouteError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

@MainActor
final class AudioRouteController {
  private let log: SessionLog
  private var session: AVAudioSession { AVAudioSession.sharedInstance() }
  private var observer: NSObjectProtocol?

  /// What the page last asked for, put back when the route moves. `hasInputPreference` false means it never asked,
  /// which differs from asking for the system default: only a route somebody chose is fought for.
  private var desiredInput: String?
  private var hasInputPreference = false
  private var desiredOutput: String?
  private var inputFailures = 0
  private var outputFailures = 0

  /// Called after every route change, with iOS's reason, once any remembered choice has been put back.
  var onRouteChange: ((AudioRouteSnapshot, String) -> Void)?

  init(log: SessionLog) {
    self.log = log
  }

  /// `.playAndRecord` is what makes `availableInputs` list more than the built-in microphone and an output override
  /// legal; `.defaultToSpeaker` is why Automatic on a bare phone is the speaker, not the earpiece. Done when the
  /// Cockpit opens and the session is in some other shape (first open, or after the Gym Timer set `.playback`), so
  /// opening it again does not touch music that is playing. A live `.voiceChat` is kept.
  func activateIfNeeded() {
    startObserving()
    guard session.category != .playAndRecord else { return }
    let options: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetoothHFP]
    let mode: AVAudioSession.Mode = session.mode == .voiceChat ? .voiceChat : .default
    do {
      try session.setCategory(.playAndRecord, mode: mode, options: options)
      try session.setActive(true)
      logRoute("activate")
    } catch {
      // Nothing to show: the page has asked for nothing yet, and its next request reports the failure itself.
      log.event("audio_route", ["action": "activate", "ok": false, "message": error.localizedDescription])
    }
  }

  // MARK: - reading

  private func describe(_ port: AVAudioSessionPortDescription) -> AudioDevice {
    AudioDevice(id: port.uid, name: port.portName, type: port.portType.rawValue)
  }

  func snapshot() -> AudioRouteSnapshot {
    let inputs = (session.availableInputs ?? []).map(describe)
    let route = session.currentRoute
    let routeOutputs = route.outputs.map(describe)
    return AudioRouteSnapshot(
      inputs: inputs,
      outputs: AudioRouting.outputs(availableInputs: inputs, routeOutputs: routeOutputs),
      currentInput: route.inputs.first.map(describe),
      currentOutput: AudioRouting.currentOutput(routeOutputs.first))
  }

  /// `audio_route`: the roster and what is live, with what the page chose, each time the page is told.
  func logRoute(_ action: String, _ snapshot: AudioRouteSnapshot? = nil, reason: String? = nil) {
    let snap = snapshot ?? self.snapshot()
    var fields: [String: Any] = [
      "action": action, "ok": true,
      "inputs": snap.inputs.map { "\($0.name) [\($0.type)]" },
      "outputs": snap.outputs.map(\.id),
      "input": snap.currentInput?.name ?? "none", "output": snap.currentOutput?.name ?? "none",
      "chosen_input": hasInputPreference ? (desiredInput ?? "default") : "unset",
      "chosen_output": desiredOutput ?? "unset",
      "category": session.category.rawValue.replacingOccurrences(of: "AVAudioSessionCategory", with: ""),
    ]
    if let reason { fields["reason"] = reason }
    log.event("audio_route", fields)
  }

  // MARK: - steering

  /// `nil` hands the choice back to iOS.
  func setInput(_ uid: String?, remember: Bool = true) throws {
    if remember {
      desiredInput = uid
      hasInputPreference = true
      inputFailures = 0
    }
    guard let uid else {
      try session.setPreferredInput(nil)
      return
    }
    guard let port = session.availableInputs?.first(where: { $0.uid == uid }) else {
      throw AudioRouteError(message: "Input not available: \(uid)")
    }
    try session.setPreferredInput(port)
  }

  func setOutput(_ raw: String, remember: Bool = true) throws {
    let wanted = AudioRouting.canonicalOutput(raw)
    if remember {
      desiredOutput = wanted
      outputFailures = 0
    }
    let snap = snapshot()
    switch AudioRouting.outputMove(
      for: wanted, availableInputs: snap.inputs, routeOutputs: session.currentRoute.outputs.map(describe))
    {
    case .clearOverride, .alreadyThere:
      try session.overrideOutputAudioPort(.none)
    case .forceSpeaker:
      try session.overrideOutputAudioPort(.speaker)
    case .preferInput(let uid):
      try session.overrideOutputAudioPort(.none)
      try setInput(uid, remember: false)
    case .unavailable:
      throw AudioRouteError(message: "Output not available: \(wanted)")
    }
  }

  // MARK: - route changes

  private func startObserving() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
      MainActor.assumeIsolated { self?.routeChanged(reason: AudioRouting.reasonName(raw)) }
    }
  }

  private func routeChanged(reason: String) {
    reassert()
    let snap = snapshot()
    logRoute("changed", snap, reason: reason)
    onRouteChange?(snap, reason)
  }

  /// Cannot loop: a re-assert raises another route change, whose re-assert finds the route matching and does nothing.
  private func reassert() {
    let route = session.currentRoute
    if hasInputPreference, inputFailures < AudioRouting.maxReassertFailures,
      !AudioRouting.inputSatisfied(
        desiredInput, liveInput: route.inputs.first?.uid, preferredInput: session.preferredInput?.uid)
    {
      do {
        try setInput(desiredInput, remember: false)
        inputFailures = 0
        log.event("audio_route", ["action": "reassert_input", "ok": true, "chosen_input": desiredInput ?? "default"])
      } catch {
        inputFailures += 1
        log.event(
          "audio_route",
          ["action": "reassert_input", "ok": false, "failures": inputFailures, "message": error.localizedDescription])
      }
    }
    if let desiredOutput, outputFailures < AudioRouting.maxReassertFailures,
      !AudioRouting.outputSatisfied(desiredOutput, routeOutputs: route.outputs.map(describe))
    {
      do {
        try setOutput(desiredOutput, remember: false)
        outputFailures = 0
        log.event("audio_route", ["action": "reassert_output", "ok": true, "chosen_output": desiredOutput])
      } catch {
        outputFailures += 1
        log.event(
          "audio_route",
          ["action": "reassert_output", "ok": false, "failures": outputFailures, "message": error.localizedDescription])
      }
    }
  }
}
