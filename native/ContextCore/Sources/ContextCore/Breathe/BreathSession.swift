//  A breathing session's hold on the phone (stories 160-169): the clock, the cues, the keepalive, the lit screen
//  and the lock-screen card, from Begin to the finish, Back or leaving. BreathRun decides what is due from the clock;
//  this carries its effects out against a SessionHost and the breathing audio, so the rules are host-tested with a
//  hand-moved clock. BreatheModel is the adapter: it publishes the stage, remembers the choices and saves to Health.

import Foundation

/// The spoken cues, each a sound file of the same name.
public enum BreathPhrase: String, CaseIterable, Sendable {
  case begin = "breath-begin"
  case breatheIn = "breath-in"
  case hold = "breath-hold"
  case breatheOut = "breath-out"
  /// The second hold, lower and slower, so the two are told apart by ear.
  case holdLow = "breath-hold-low"
  case wellDone = "breath-done"

  public var text: String {
    switch self {
    case .begin: return "Let's begin"
    case .breatheIn: return "Breathe in"
    case .hold, .holdLow: return "Hold"
    case .breatheOut: return "Breathe out"
    case .wellDone: return "Well done"
    }
  }

  public static func phrase(for phase: BreathPhase) -> BreathPhrase {
    switch phase {
    case .inhale: return .breatheIn
    case .holdFull: return .hold
    case .exhale: return .breatheOut
    case .holdEmpty: return .holdLow
    }
  }
}

/// The breathing screen's sound: the cues, and the near-silent loop that keeps a locked phone running.
public protocol BreathAudio: AnyObject {
  func say(_ phrase: BreathPhrase)
  func play(_ tone: BreathTone)
  /// Whatever is sounding stops.
  func hush()
  /// The keepalive loop on or off. Idempotent.
  func keepAlive(_ on: Bool)
  /// Leaving: stop everything and let go of the audio session.
  func stop()
}

public final class BreathSession {
  public enum Stage: Equatable, Sendable { case setup, session, done }

  public private(set) var stage = Stage.setup
  public private(set) var paused = false
  /// The session on screen or just finished; Done shows its length.
  public private(set) var sessionPlan: BreathPlan?
  /// The cue the steps are said with; the app sets it from the choice.
  public var cue: BreathCue
  /// Called after the stage, the pause or the plan changed.
  public var onChange: (() -> Void)?

  private let host: SessionHost
  private let audio: BreathAudio
  /// Story 242: a session ending with this much breathing goes to Health, and why it ended.
  private let saveMindful: (TimeSpan, String) -> Void
  /// The finish, for the activity log.
  private let finished: (BreathPlan) -> Void
  private var run: BreathRun?
  private var pauseAt: Double?

  /// Room for "Let's begin" before the first inhale.
  public static let voiceLeadIn = 2.0
  /// Twenty looks a second: no step is noticed more than 50 ms late, and lateness cannot add up, because every look
  /// derives the step from the clock.
  public static let lookEvery = 0.05

  public init(
    cue: BreathCue, host: SessionHost, audio: BreathAudio,
    saveMindful: @escaping (TimeSpan, String) -> Void = { _, _ in }, finished: @escaping (BreathPlan) -> Void = { _ in }
  ) {
    self.cue = cue
    self.host = host
    self.audio = audio
    self.saveMindful = saveMindful
    self.finished = finished
  }

  /// Begin `plan`: the lit screen, the keepalive, the clock and the card. `pauseAt` pauses by itself that many
  /// seconds into the breathing (a launch hook's, to see the paused circle).
  public func begin(_ plan: BreathPlan, pauseAt: Double? = nil) {
    self.pauseAt = pauseAt
    let leadIn = cue == .voice ? Self.voiceLeadIn : 0
    var run = BreathRun(plan: plan, leadIn: leadIn)
    run.start(now: host.now)
    self.run = run
    sessionPlan = plan
    paused = false
    stage = .session
    onChange?()
    host.log(
      "breath_start",
      [
        "breath": plan.inSeconds, "hold_in": plan.holdInSeconds, "out": plan.outSeconds,
        "hold_out": plan.holdOutSeconds, "cycles": plan.cycles, "total": plan.totalSeconds,
        "cue": cue.rawValue,
        "lead_in_ms": Int(leadIn * 1000),
      ])
    keepAwake(true)
    audio.hush()  // a sample still sounding
    if cue == .voice { audio.say(.begin) }
    audio.keepAlive(true)
    startClock()
    tick()
    syncCard()
  }

  /// A tap on the circle: pause, or resume where it stopped.
  public func togglePause() {
    guard var run, stage == .session else { return }
    if paused {
      run.start(now: host.now)
      host.log("breath_resume", ["time_left": run.moment(now: host.now).secondsLeft])
      self.run = run
      paused = false
      onChange?()
      audio.keepAlive(true)
      startClock()
      syncCard()
    } else {
      pause(reason: "circle")
    }
  }

  /// The back chevron: out at once, no question; the card goes now.
  public func back() {
    guard stage == .session, let run else { return }
    let now = host.now
    host.log("breath_exit", ["elapsed_ms": Int(max(0, run.elapsed(now: now)) * 1000), "paused": paused])
    if let span = run.mindfulSpan(now: now) {
      saveMindful(span, "back")
    } else {
      host.log("mindful_skipped", ["why": "under a minute", "breathed_ms": Int(max(0, run.elapsed(now: now)) * 1000)])
    }
    endSession()
    stage = .setup
    onChange?()
    host.endCard(.breathe, reason: "back")
  }

  /// Done's *Back to start*.
  public func backToStart() {
    audio.hush()
    stage = .setup
    onChange?()
    host.endCard(.breathe, reason: "back")
  }

  /// Leaving the screen altogether: Back if a session is on, then the audio session and the card go.
  public func disappear() {
    if stage == .session { back() }
    audio.stop()
    host.endCard(.breathe, reason: "leave")
  }

  /// Where the ring is at `now`; frozen while paused.
  public func moment(now: Double) -> BreathMoment? { run?.moment(now: now) }

  /// True in the quiet before the first inhale.
  public func inLeadIn(now: Double) -> Bool { (run?.elapsed(now: now) ?? 0) < 0 }

  // MARK: - private

  private func pause(reason: String) {
    guard var run else { return }
    let now = host.now
    run.pause(now: now)
    self.run = run
    paused = true
    onChange?()
    stopClock()
    audio.hush()
    audio.keepAlive(false)
    let m = run.moment(now: now)
    host.log("breath_pause", ["reason": reason, "phase": "\(m.phase)", "cycle": m.cycle, "time_left": m.secondsLeft])
    syncCard()
  }

  /// What the lock screen and the island show (story 166): the controller pushes only when the step, the pause or
  /// the finish changed, which it works out from the content's key.
  private func syncCard() {
    guard let run else { return }
    let t = host.now
    host.syncCard(
      LiveActivityContent(
        breath: run.plan, elapsed: run.elapsed(now: t), leadIn: run.leadIn, paused: paused, finished: run.isFinished),
      kind: .breathe, stepEndsAt: run.stepEndsAt(now: t))
  }

  private func startClock() {
    host.startClock(every: Self.lookEvery) { [weak self] in self?.tick() }
  }

  private func stopClock() { host.stopClock() }

  private func tick() {
    guard var run else { return }
    let effects = run.tick(now: host.now)
    self.run = run
    for effect in effects {
      switch effect {
      case .phase(let phase, let cycle, let lateMs):
        host.log("breath_phase", ["phase": "\(phase)", "cycle": cycle, "late_ms": lateMs])
        switch cue {
        case .voice: audio.say(BreathPhrase.phrase(for: phase))
        case .tone: audio.play(BreathTone.tone(for: phase))
        case .off: break
        }
        host.announce(phase.word)
      case .finished(let lateMs):
        host.log("breath_finished", ["cycles": run.plan.cycles, "total": run.plan.totalSeconds, "late_ms": lateMs])
        finished(run.plan)
        if let span = run.mindfulSpan(now: host.now) { saveMindful(span, "finished") }
        endSession()
        stage = .done
        onChange?()
        switch cue {
        case .voice: audio.say(.wellDone)
        case .tone: audio.play(.closing)
        case .off: break
        }
        host.announce("Done")
      }
    }
    if !effects.isEmpty { syncCard() }
    if let at = pauseAt, stage == .session, run.elapsed(now: host.now) >= at {
      pauseAt = nil
      pause(reason: "hook")
    }
  }

  /// The session is over (finished or left): the clock, the cues and the keepalive stop and the lit screen goes back.
  private func endSession() {
    pauseAt = nil
    stopClock()
    audio.hush()
    audio.keepAlive(false)
    paused = false
    onChange?()
    keepAwake(false)
  }

  /// Turned on only if off and off only if on: the switch is shared, and the log says each change once.
  private func keepAwake(_ on: Bool) {
    guard host.keepAwake != on else { return }
    host.keepAwake = on
    host.log("keep_awake", ["on": on, "reason": "breathe"])
  }
}
