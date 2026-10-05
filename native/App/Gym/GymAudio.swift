//  The Gym Timer's audio: the session, the background keepalive and the cues (stories 104, 105, 107).
//
//  The session is `playback` mixed with others, so a workout never pauses the music. Around each cue the duck
//  window (ContextCore's DuckWindow) adds `duckOthers` + `interruptSpokenAudioAndMixWithOthers` to the live
//  session, then lets go with a deactivate-and-reactivate: a paused podcast resumes only on deactivation, and
//  only when told (`notifyOthersOnDeactivation`). The keepalive is a looping second of -66 dB noise — real
//  samples, which iOS counts as live output — so the app keeps running, and speaking, with the screen locked.
//  The cues are sound files, never synthesis, in the chosen count voice (story 182): Adam, Igor's own clone
//  (scripts/make-timer-words.sh) or an Australian woman (scripts/make-timer-voice.sh).
//
//  Everything runs in order on one queue: a session call can block for a moment and must not stall the face.

import AVFoundation
import ContextCore

final class GymAudio: DuckSession, @unchecked Sendable {
  private let log: SessionLog
  private let queue = DispatchQueue(label: "grabber.gym.audio")
  private let session = AVAudioSession.sharedInstance()

  // Touched only on `queue`.
  private var wanted = false
  private var active = false
  private var loop: AVAudioPlayer?
  private var cues: [TimerCue: AVAudioPlayer] = [:]
  private var voice = CountVoice.default
  private var sampler: AVAudioPlayer?
  private var interruptionObserver: NSObjectProtocol?

  /// Music and podcasts play on, untouched, while the timer runs.
  private static let baseOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]
  /// Around a cue: music turned down, spoken audio paused (and resumed when the window lets go).
  private static let duckOptions: AVAudioSession.CategoryOptions = [
    .mixWithOthers, .duckOthers, .interruptSpokenAudioAndMixWithOthers,
  ]

  init(log: SessionLog) {
    self.log = log
    // A phone call takes the session; when it gives it back the keepalive has to be started again or the app
    // is suspended at the next lock.
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification, object: session, queue: nil
    ) { [weak self] note in
      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
      let ended = AVAudioSession.InterruptionType(rawValue: raw) == .ended
      self?.queue.async {
        guard let self else { return }
        self.log.event("timer_interruption", ["kind": ended ? "ended" : "began", "wanted": self.wanted])
        if ended, self.wanted {
          self.active = false
          self.activateAndLoop()
        } else if !ended {
          self.active = false
        }
      }
    }
  }

  deinit {
    if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
  }

  /// Make every cue's player ahead of time, so the first count is not the first load.
  func loadCues() {
    queue.async { [self] in
      for cue in TimerCue.allCases where cues[cue] == nil { cues[cue] = player(voice.fileName(for: cue)) }
    }
  }

  /// The next cue is in this voice. A word still sounding in the old one stops, so the two never overlap.
  func setVoice(_ next: CountVoice) {
    queue.async { [self] in
      guard next != voice else { return }
      for player in cues.values where player.isPlaying { player.stop() }
      voice = next
      cues = [:]
      for cue in TimerCue.allCases { cues[cue] = player(voice.fileName(for: cue)) }
    }
  }

  /// The voice's "go", once, as a sample for the settings sheet. Mixed with the music like a cue; when the timer
  /// is not holding the session it is taken for the sample and let go after it.
  func sample(_ sampleVoice: CountVoice) {
    queue.async { [self] in
      guard let player = player(sampleVoice.fileName(for: .go)) else {
        log.event("timer_voice_sample", ["voice": sampleVoice.rawValue, "ok": false, "message": "no player"])
        return
      }
      sampler?.stop()
      sampler = player
      let borrowed = !active
      if borrowed {
        applyOptions(ducking: false)
        do {
          try session.setActive(true)
        } catch {
          log.event("timer_session", ["action": "active", "for": "sample", "ok": false, "message": "\(error)"])
        }
      }
      let ok = player.play()
      log.event("timer_voice_sample", ["voice": sampleVoice.rawValue, "ok": ok])
      guard borrowed else { return }
      queue.asyncAfter(deadline: .now() + player.duration + 0.3) { [self] in
        // The timer may have started meanwhile, or another sample be playing: then the session stays.
        guard !active, !(sampler?.isPlaying ?? false) else { return }
        do {
          try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
          log.event("timer_session", ["action": "inactive", "for": "sample", "ok": false, "message": "\(error)"])
        }
      }
    }
  }

  /// START: the session goes active and the keepalive loops. Idempotent.
  func start() {
    queue.async { [self] in
      wanted = true
      guard !active else { return }
      applyOptions(ducking: false)
      activateAndLoop()
    }
  }

  /// RESET or leaving: stop the loop and let go of the session now, telling others they may resume.
  func stop() {
    queue.async { [self] in
      wanted = false
      deactivate()
    }
  }

  /// The finish: the timer no longer needs the session, but "done" is still playing. The duck window's own
  /// release, a moment after the cue, is the letting go.
  func stopWhenReleased() {
    queue.async { [self] in wanted = false }
  }

  func play(_ cue: TimerCue) {
    queue.async { [self] in
      guard let player = cues[cue] ?? player(voice.fileName(for: cue)) else {
        log.event("timer_cue", ["cue": cue.rawValue, "voice": voice.rawValue, "ok": false, "message": "no player"])
        return
      }
      cues[cue] = player
      player.currentTime = 0
      let ok = player.play()
      log.event("timer_cue", ["cue": cue.rawValue, "voice": voice.rawValue, "ok": ok])
    }
  }

  // MARK: - DuckSession

  func setDucking(_ on: Bool) {
    queue.async { [self] in applyOptions(ducking: on) }
  }

  func release() {
    queue.async { [self] in
      deactivate()
      if wanted { activateAndLoop() }
    }
  }

  // MARK: - on the queue

  private func player(_ name: String) -> AVAudioPlayer? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
      log.event("error", ["where": "timer_audio", "message": "\(name).wav is not in the bundle"])
      return nil
    }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.prepareToPlay()
      return player
    } catch {
      log.event("error", ["where": "timer_audio", "message": "\(name).wav: \(error.localizedDescription)"])
      return nil
    }
  }

  private func applyOptions(ducking: Bool) {
    let options = ducking ? Self.duckOptions : Self.baseOptions
    let names = ducking ? "mixWithOthers,duckOthers,interruptSpokenAudioAndMixWithOthers" : "mixWithOthers"
    do {
      try session.setCategory(.playback, mode: .default, options: options)
      log.event("timer_session", ["action": "options", "options": names, "ok": true])
    } catch {
      log.event("timer_session", ["action": "options", "options": names, "ok": false, "message": "\(error)"])
    }
  }

  private func activateAndLoop() {
    do {
      try session.setActive(true)
      active = true
      log.event("timer_session", ["action": "active", "ok": true, "other_audio": session.isOtherAudioPlaying])
    } catch {
      log.event("timer_session", ["action": "active", "ok": false, "message": "\(error)"])
    }
    if loop == nil {
      loop = player("keepalive")
      loop?.numberOfLoops = -1
    }
    loop?.currentTime = 0
    let ok = loop?.play() ?? false
    log.event("timer_keepalive", ["action": "start", "ok": ok])
  }

  private func deactivate() {
    guard active else { return }
    active = false
    loop?.pause()
    // A cue still sounding would make the deactivation fail as busy; the window's holds are longer than any cue.
    for player in cues.values where player.isPlaying { player.stop() }
    sampler?.stop()
    log.event("timer_keepalive", ["action": "stop", "ok": true])
    do {
      try session.setActive(false, options: .notifyOthersOnDeactivation)
      log.event("timer_session", ["action": "inactive", "ok": true])
    } catch {
      log.event("timer_session", ["action": "inactive", "ok": false, "message": "\(error)"])
    }
  }
}
