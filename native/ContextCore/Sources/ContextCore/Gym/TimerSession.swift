//  A rounds workout's hold on the phone (stories 104-107, 115, 188, 191): when the Gym Timer takes and lets go of
//  the audio session, the duck window, the clock, the lit screen and the lock-screen card. TimerEngine decides what
//  each second says; this carries its effects out against a SessionHost and the timer's audio, so the rules are
//  host-tested with a hand-moved clock. GymTimerModel is the adapter: it publishes the state, remembers the
//  settings, reads the accelerometer and names the preset for the activity log.

import Foundation

/// The Gym Timer's sound: the session, its keepalive loop and the cues. The duck window drives the other half.
public protocol TimerAudio: DuckSession {
  /// START: the session goes active and the keepalive loops. Idempotent.
  func start()
  /// RESET or leaving: stop the loop and let go of the session now.
  func stop()
  /// The finish: the session is no longer wanted, but "done" is still sounding; the window's release lets go.
  func stopWhenReleased()
  func play(_ cue: TimerCue)
}

public final class TimerSession {
  public private(set) var state: TimerState
  /// Called after every change of `state`, once its card has been synced.
  public var onChange: ((TimerState) -> Void)?
  /// The timer screen is up: it holds the lit screen.
  public private(set) var onScreen = false

  private var engine: TimerEngine
  private let host: SessionHost
  private let audio: TimerAudio
  /// The finish, once per workout: the app records it.
  private let finished: (TimerProfile) -> Void
  private var ticking = false
  private lazy var duck = DuckWindow(
    session: audio, schedule: { [host] afterMs, block in host.after(afterMs, block) },
    log: { [host] action, holdMs in host.log("timer_duck", ["action": action, "hold_ms": holdMs]) })

  /// The clock looks ten times a second: a boundary is called within a tenth of its true time, and the engine only
  /// answers when the second changes.
  public static let lookEvery = 0.1

  public init(
    profile: TimerProfile, host: SessionHost, audio: TimerAudio, finished: @escaping (TimerProfile) -> Void = { _ in }
  ) {
    engine = TimerEngine(profile: profile)
    state = engine.state
    self.host = host
    self.audio = audio
    self.finished = finished
  }

  public var profile: TimerProfile { engine.profile }
  /// The chips and the Custom sliders are inert from START until RESET or the finish.
  public var locked: Bool { engine.isEngaged }
  /// The clock is looking (a workout is running).
  public var isTicking: Bool { ticking }

  // MARK: - the workout

  /// A chosen preset onto the face. After a finish that is a RESET: donE goes and the new preset stands ready.
  public func choose(_ profile: TimerProfile) {
    if state.phase == .done {
      reset(to: profile)
    } else {
      engine.setProfile(profile)
      publish()
    }
  }

  /// The saved profile back on the face after a visit's one-off; a finished face stays finished.
  public func restore(_ profile: TimerProfile) {
    guard state.phase != .done else { return }
    engine.setProfile(profile)
    publish()
  }

  /// START, RESUME or STOP. START takes the audio session and starts the clock; a stop only stops the clock (the
  /// session and its keepalive stay until RESET, leaving or the finish).
  public func toggle() {
    if state.isRunning {
      engine.pause(now: host.now)
      stopClock()
      publish()
      host.log(
        "timer_pause", ["phase": state.phase.rawValue, "round": state.currentRound, "time_left": state.timeLeft])
      return
    }
    let p = engine.profile
    host.log(
      "timer_start",
      [
        "preset": p.name, "work": p.workTime, "rest": p.restTime, "rounds": p.rounds, "prep": p.prepTime,
        "resumed": state.isPaused,
      ])
    audio.start()
    perform(engine.start(now: host.now))
    ticking = true
    host.startClock(every: Self.lookEvery) { [weak self] in self?.tick() }
  }

  /// A link, tile or hook that starts a workout (story 188): a running one is left alone (a tap on its card or a
  /// tile must never pause it), a paused one resumes, a finished one goes back to ready and starts again.
  public func autostart(_ profile: TimerProfile) {
    if state.isRunning {
      host.log("timer_autostart", ["action": "already_running", "round": state.currentRound])
      return
    }
    if state.phase == .done { reset(to: profile) }
    toggle()
  }

  /// RESET: the clock, the audio session and any open window go now, and the face shows `profile` ready.
  public func reset(to profile: TimerProfile) {
    stopClock()
    engine.reset()
    engine.setProfile(profile)
    publish()
    audio.stop()
    duck.close()
    host.log("timer_reset", [:])
  }

  /// The app came back to the front: move the state to now. The engine replays nothing that was missed and still
  /// calls what is due this second (story 107).
  public func catchUp() {
    guard state.isRunning else { return }
    tick()
    host.log(
      "timer_catchup", ["phase": state.phase.rawValue, "round": state.currentRound, "time_left": state.timeLeft])
  }

  // MARK: - the screen's lifetime

  /// The timer is open: the screen stays lit (story 115), and a workout left running (story 188) is shown where it
  /// is now. `mode` and `stopwatchRunning` are for the log.
  public func appear(mode: String, stopwatchRunning: Bool) {
    onScreen = true
    host.keepAwake = true
    host.log(
      "keep_awake",
      ["on": true, "reason": "gym_timer", "mode": mode, "running": state.isRunning || stopwatchRunning])
    if state.isRunning { tick() }
  }

  /// The timer is closed: the lit screen goes back to the phone. A running workout carries on, cues, card and all,
  /// as with the phone locked (story 188); with nothing running the clock, the session and the card are let go.
  /// True when it let go, so the app puts back what a visit's one-off settings replaced.
  @discardableResult
  public func disappear(stopwatchRunning: Bool) -> Bool {
    onScreen = false
    host.keepAwake = false
    host.log(
      "keep_awake", ["on": false, "reason": "gym_timer", "running": state.isRunning, "stopwatch": stopwatchRunning])
    if state.isRunning { return false }
    release(reason: "leave")
    return true
  }

  /// Box breathing, a call, the Cockpit or the eulogy song's player is opening (story 191): a running rounds
  /// workout pauses where it is, to resume on coming back. Off the screen, its session and card go too.
  public func yield(to other: String) {
    guard state.isRunning else { return }
    host.log("timer_yield", ["to": other, "on_screen": onScreen])
    toggle()
    if !onScreen { release(reason: "yield") }
  }

  // MARK: - private

  private func tick() {
    perform(engine.tick(now: host.now))
  }

  private func perform(_ effects: [TimerEffect]) {
    for effect in effects {
      switch effect {
      case .duckHold(let ms): duck.hold(ms)
      case .cue(let cue): audio.play(cue)
      case .phaseChanged(let from, let to, let round):
        host.log("timer_phase", ["from": from.rawValue, "to": to.rawValue, "round": round])
      case .finished:
        stopClock()
        host.log("timer_finished", ["rounds": engine.profile.rounds])
        finished(engine.profile)
        // "done" is still sounding: the window's release lets go of the session. With no window open (a finish
        // found on coming back) there is nothing to wait for.
        if duck.isOpen { audio.stopWhenReleased() } else { audio.stop() }
      }
    }
    if state != engine.state { publish() }
  }

  /// Nothing running and nothing on screen to sound for: the clock, the audio session and the card go.
  private func release(reason: String) {
    stopClock()
    audio.stop()
    duck.close()
    host.endCard(.gymTimer, reason: reason)
  }

  private func stopClock() {
    ticking = false
    host.stopClock()
  }

  /// Every change reaches the lock screen from here, and only from here (story 106); the card itself is pushed only
  /// when the phase, round or pause changed.
  private func publish() {
    state = engine.state
    host.syncCard(
      LiveActivityContent(timer: state, profile: engine.profile), kind: .gymTimer, stepEndsAt: engine.phaseEndsAt)
    onChange?(state)
  }
}
