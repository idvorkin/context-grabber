//  The breathing screen's sound (stories 164, 165): a tone or a spoken phrase at the start of each step.
//
//  The session is `playback` mixed with others, so music keeps playing under the cues. While a session runs a
//  near-silent loop plays (the Gym Timer's keepalive.wav, real samples iOS counts as live output), so the app keeps
//  running, and speaking, with the phone locked (story 166); pausing or ending the session stops it. The phrases are sound files rendered ahead of time
//  (scripts/make-breath-words.sh); a missing file falls back to the phone's own Australian voice. The tones are
//  synthesised once (ContextCore's BreathTone) and played like files.
//
//  Everything runs in order on one queue: a session call can block for a moment and must not stall the ring.

import AVFoundation
import ContextCore

enum BreathPhrase: String, CaseIterable {
  case begin = "breath-begin"
  case breatheIn = "breath-in"
  case hold = "breath-hold"
  case breatheOut = "breath-out"
  /// The second hold, lower and slower, so the two are told apart by ear.
  case holdLow = "breath-hold-low"
  case wellDone = "breath-done"

  var text: String {
    switch self {
    case .begin: return "Let's begin"
    case .breatheIn: return "Breathe in"
    case .hold, .holdLow: return "Hold"
    case .breatheOut: return "Breathe out"
    case .wellDone: return "Well done"
    }
  }

  static func phrase(for phase: BreathPhase) -> BreathPhrase {
    switch phase {
    case .inhale: return .breatheIn
    case .holdFull: return .hold
    case .exhale: return .breatheOut
    case .holdEmpty: return .holdLow
    }
  }
}

final class BreatheAudio: @unchecked Sendable {
  private let log: SessionLog
  private let queue = DispatchQueue(label: "grabber.breathe.audio")
  private let session = AVAudioSession.sharedInstance()

  // Touched only on `queue`.
  /// A session is running and wants the keepalive.
  private var wanted = false
  private var active = false
  private var phrases: [BreathPhrase: AVAudioPlayer] = [:]
  private var missing: Set<BreathPhrase> = []
  private var tones: [BreathTone: AVAudioPlayer] = [:]
  private var loop: AVAudioPlayer?
  private let speech = AVSpeechSynthesizer()
  private var interruptionObserver: NSObjectProtocol?

  init(log: SessionLog) {
    self.log = log
    // A phone call or Siri takes the session; when it gives it back the keepalive has to be started again or the
    // app is suspended with the phone locked.
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification, object: session, queue: nil
    ) { [weak self] note in
      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
      let ended = AVAudioSession.InterruptionType(rawValue: raw) == .ended
      self?.queue.async {
        guard let self else { return }
        self.log.event("breath_interruption", ["kind": ended ? "ended" : "began", "wanted": self.wanted])
        self.active = false
        if ended, self.wanted { self.startLoop() }
      }
    }
  }

  deinit {
    if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
  }

  /// Make the players ahead of time, so the first cue is not the first load.
  func load() {
    queue.async { [self] in
      for phrase in BreathPhrase.allCases { _ = player(phrase) }
      for tone in BreathTone.allCases { _ = player(tone) }
    }
  }

  func say(_ phrase: BreathPhrase) {
    queue.async { [self] in
      activate()
      if let player = player(phrase) {
        player.currentTime = 0
        log.event("breath_cue", ["kind": "voice", "name": phrase.rawValue, "ok": player.play()])
        return
      }
      // No file: the phone's own Australian voice says it.
      let utterance = AVSpeechUtterance(string: phrase.text)
      utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
      speech.usesApplicationAudioSession = true
      speech.speak(utterance)
      log.event("breath_cue", ["kind": "voice", "name": phrase.rawValue, "ok": true, "fallback": true])
    }
  }

  func play(_ tone: BreathTone) {
    queue.async { [self] in
      activate()
      guard let player = player(tone) else {
        log.event("breath_cue", ["kind": "tone", "name": tone.rawValue, "ok": false])
        return
      }
      player.currentTime = 0
      log.event("breath_cue", ["kind": "tone", "name": tone.rawValue, "ok": player.play()])
    }
  }

  /// A session running: the keepalive loops, so the app is not suspended with the phone locked. Off when paused,
  /// finished or left. Idempotent.
  func keepAlive(_ on: Bool) {
    queue.async { [self] in
      wanted = on
      if on {
        startLoop()
      } else if let loop, loop.isPlaying {
        loop.pause()
        log.event("breath_keepalive", ["action": "stop", "ok": true])
      }
    }
  }

  /// A pause: whatever is sounding stops with the ring.
  func hush() {
    queue.async { [self] in silence() }
  }

  /// Leaving the screen: stop whatever is sounding and let go of the session.
  func stop() {
    queue.async { [self] in
      wanted = false
      silence()
      if let loop, loop.isPlaying {
        loop.pause()
        log.event("breath_keepalive", ["action": "stop", "ok": true])
      }
      guard active else { return }
      active = false
      do {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        log.event("breath_session", ["action": "inactive", "ok": true])
      } catch {
        log.event("breath_session", ["action": "inactive", "ok": false, "message": "\(error)"])
      }
    }
  }

  // MARK: - on the queue

  private func startLoop() {
    activate()
    if loop == nil {
      do {
        guard let url = Bundle.main.url(forResource: "keepalive", withExtension: "wav") else {
          throw CocoaError(.fileNoSuchFile)
        }
        loop = try AVAudioPlayer(contentsOf: url)
        loop?.numberOfLoops = -1
      } catch {
        log.event("breath_keepalive", ["action": "start", "ok": false, "message": "keepalive.wav: \(error)"])
        return
      }
    }
    guard let loop, !loop.isPlaying else { return }
    log.event("breath_keepalive", ["action": "start", "ok": loop.play()])
  }

  private func silence() {
    for player in phrases.values where player.isPlaying { player.stop() }
    for player in tones.values where player.isPlaying { player.stop() }
    if speech.isSpeaking { speech.stopSpeaking(at: .immediate) }
  }

  private func activate() {
    guard !active else { return }
    do {
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      active = true
      log.event("breath_session", ["action": "active", "ok": true, "other_audio": session.isOtherAudioPlaying])
    } catch {
      log.event("breath_session", ["action": "active", "ok": false, "message": "\(error)"])
    }
  }

  private func player(_ phrase: BreathPhrase) -> AVAudioPlayer? {
    if let player = phrases[phrase] { return player }
    guard !missing.contains(phrase) else { return nil }
    do {
      guard let url = Bundle.main.url(forResource: phrase.rawValue, withExtension: "wav") else {
        throw CocoaError(.fileNoSuchFile)
      }
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      phrases[phrase] = player
      return player
    } catch {
      // Said once: every later use of this phrase goes to the phone's voice without another line.
      missing.insert(phrase)
      log.event(
        "error", ["where": "breath_audio", "message": "\(phrase.rawValue).wav: \(error.localizedDescription)"])
      return nil
    }
  }

  private func player(_ tone: BreathTone) -> AVAudioPlayer? {
    if let player = tones[tone] { return player }
    do {
      let player = try AVAudioPlayer(data: tone.wav())
      player.prepareToPlay()
      tones[tone] = player
      return player
    } catch {
      log.event("error", ["where": "breath_audio", "message": "tone \(tone.rawValue): \(error.localizedDescription)"])
      return nil
    }
  }
}
