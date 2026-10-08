//  The breathing screen's state (stories 160–165): the three choices, the session against the clock, the cues.
//
//  ContextCore's BreathRun decides everything from the clock; this owns the clock, the sound and the log.

import ContextCore
import SwiftUI

/// How the screen was asked for. A launch hook can name an exact session, shorter than the sliders allow.
struct BreatheLaunch: Equatable {
  var plan: BreathPlan?
  var cue: BreathCue?
  /// Pause by itself this many seconds into the breathing, so a script can see the paused circle.
  var pauseAt: Double?
  /// `GRABBER_BREATHE_STYLE`: this visit's ring style, not remembered (the simulator's screenshots).
  var style: BreathStyle?
  /// A link's breath and length (story 135), each nil for the remembered slider; this session only.
  var breath: Int?
  var minutes: Int?
  /// Begin on arrival, from the sliders unless the fields above say otherwise.
  var start = false

  /// Whether the screen begins a session as it appears rather than showing the sliders.
  var begins: Bool { plan != nil || start }
}

@MainActor
final class BreatheModel: ObservableObject {
  enum Stage { case setup, session, done }

  @Published private(set) var stage = Stage.setup
  /// The preset chosen (story 241), or nil for Custom.
  @Published private(set) var preset: Int?
  @Published private(set) var customIn: Int
  @Published private(set) var customOut: Int
  @Published private(set) var sessionMinutes: Int
  @Published private(set) var cue: BreathCue
  /// How the circle draws the breath (story 240).
  @Published private(set) var style: BreathStyle
  @Published private(set) var paused = false
  /// The session on screen or just finished; Done shows its length.
  @Published private(set) var sessionPlan: BreathPlan?

  private let log: SessionLog
  private let database: AppDatabase
  private let audio: BreatheAudio
  private let liveActivity: LiveActivityController
  private var run: BreathRun?
  private var clock: Timer?
  private var pauseAt: Double?

  private static let sessionKey = "breathe_session_minutes"
  private static let cueKey = "breathe_cue"
  /// Room for "Let's begin" before the first inhale.
  private static let voiceLeadIn = 2.0

  /// Story 242: where a session goes in Health; the app saves it as a Mindful Session.
  private let saveMindful: (TimeSpan, String) -> Void

  init(
    log: SessionLog, database: AppDatabase, liveActivity: LiveActivityController,
    saveMindful: @escaping (TimeSpan, String) -> Void = { _, _ in }
  ) {
    self.saveMindful = saveMindful
    self.log = log
    self.database = database
    self.liveActivity = liveActivity
    audio = BreatheAudio(log: log)
    let (setup, seeds) = BreathSetup.restore(database.setting)
    for seed in seeds { database.setSetting(seed.key, seed.value) }
    preset = setup.preset
    customIn = setup.customIn
    customOut = setup.customOut
    sessionMinutes = database.setting(Self.sessionKey).flatMap(Int.init) ?? BreathPlan.defaultSession
    cue = database.setting(Self.cueKey).flatMap(BreathCue.init(rawValue:)) ?? .voice
    style = BreathStyle.decode(database.setting(BreathStyle.settingKey))
    audio.load()
  }

  var plan: BreathPlan {
    if let preset { return BreathPlan(breathSeconds: preset, sessionMinutes: sessionMinutes) }
    return BreathPlan(inSeconds: customIn, outSeconds: customOut, sessionMinutes: sessionMinutes)
  }
  private var now: Double { Date().timeIntervalSince1970 }

  // MARK: - setup

  /// A preset's seconds, or nil for Custom.
  func choosePreset(_ seconds: Int?) {
    guard seconds != preset else { return }
    preset = seconds
    if let seconds { database.setSetting(BreathSetup.breathKey, String(seconds)) }
    database.setSetting(BreathSetup.customKey, seconds == nil ? "1" : "0")
    log.event("ui", ["action": "breath_preset", "preset": seconds.map(String.init) ?? "custom"])
  }

  func setCustomIn(_ seconds: Int) {
    guard seconds != customIn else { return }
    customIn = seconds
    database.setSetting(BreathSetup.customInKey, String(seconds))
  }

  func setCustomOut(_ seconds: Int) {
    guard seconds != customOut else { return }
    customOut = seconds
    database.setSetting(BreathSetup.customOutKey, String(seconds))
  }

  func setSession(_ minutes: Int) {
    guard minutes != sessionMinutes else { return }
    sessionMinutes = minutes
    database.setSetting(Self.sessionKey, String(minutes))
  }

  /// Choosing a cue plays a sample of it.
  func chooseStyle(_ next: BreathStyle) {
    guard next != style else { return }
    style = next
    database.setSetting(BreathStyle.settingKey, next.rawValue)
    log.event("breathe_style", ["style": next.rawValue])
  }

  func chooseCue(_ next: BreathCue) {
    guard next != cue else { return }
    cue = next
    database.setSetting(Self.cueKey, next.rawValue)
    log.event("ui", ["action": "breath_cue_choice", "cue": next.rawValue])
    switch next {
    case .voice: audio.say(.breatheIn)
    case .tone: audio.play(.rising)
    case .off: audio.hush()
    }
  }

  // MARK: - the session

  /// Begin, or a launch hook's exact session (whose cue is used but not remembered).
  func begin(_ launch: BreatheLaunch = BreatheLaunch()) {
    if let hooked = launch.cue { cue = hooked }
    if let hooked = launch.style { style = hooked }
    let plan =
      launch.plan
      ?? launch.breath.map { BreathPlan(breathSeconds: $0, sessionMinutes: launch.minutes ?? sessionMinutes) }
      ?? (launch.minutes.map { minutes in
        preset.map { BreathPlan(breathSeconds: $0, sessionMinutes: minutes) }
          ?? BreathPlan(inSeconds: customIn, outSeconds: customOut, sessionMinutes: minutes)
      } ?? self.plan)
    pauseAt = launch.pauseAt
    let leadIn = cue == .voice ? Self.voiceLeadIn : 0
    var run = BreathRun(plan: plan, leadIn: leadIn)
    run.start(now: now)
    self.run = run
    sessionPlan = plan
    paused = false
    stage = .session
    log.event(
      "breath_start",
      [
        "breath": plan.inSeconds, "out": plan.outSeconds, "cycles": plan.cycles, "total": plan.totalSeconds, "cue": cue.rawValue,
        "lead_in_ms": Int(leadIn * 1000),
      ])
    keepAwake(true)
    audio.hush()  // a sample still sounding
    if cue == .voice { audio.say(.begin) }
    audio.keepAlive(true)
    startClock()
    tick()
    syncLiveActivity()
  }

  func togglePause() {
    guard var run, stage == .session else { return }
    if paused {
      run.start(now: now)
      log.event("breath_resume", ["time_left": run.moment(now: now).secondsLeft])
      self.run = run
      paused = false
      audio.keepAlive(true)
      startClock()
      syncLiveActivity()
    } else {
      pause(reason: "circle")
    }
  }

  /// The back chevron: out at once, no question.
  func back() {
    guard stage == .session, let run else { return }
    log.event("breath_exit", ["elapsed_ms": Int(max(0, run.elapsed(now: now)) * 1000), "paused": paused])
    if let span = run.mindfulSpan(now: now) {
      saveMindful(span, "back")
    } else {
      log.event("mindful_skipped", ["why": "under a minute", "breathed_ms": Int(max(0, run.elapsed(now: now)) * 1000)])
    }
    endSession()
    stage = .setup
    liveActivity.end(.breathe, reason: "back")
  }

  func backToStart() {
    audio.hush()
    stage = .setup
    liveActivity.end(.breathe, reason: "back")
  }

  /// Leaving the screen altogether.
  func disappear() {
    if stage == .session { back() }
    audio.stop()
    liveActivity.end(.breathe, reason: "leave")
  }

  /// Where the ring is at `date`; frozen while paused.
  func moment(at date: Date) -> BreathMoment? {
    run?.moment(now: date.timeIntervalSince1970)
  }

  /// True in the quiet before the first inhale.
  func inLeadIn(at date: Date) -> Bool {
    (run?.elapsed(now: date.timeIntervalSince1970) ?? 0) < 0
  }

  // MARK: - private

  private func pause(reason: String) {
    guard var run else { return }
    run.pause(now: now)
    self.run = run
    paused = true
    stopClock()
    audio.hush()
    audio.keepAlive(false)
    let m = run.moment(now: now)
    log.event(
      "breath_pause",
      ["reason": reason, "phase": "\(m.phase)", "cycle": m.cycle, "time_left": m.secondsLeft])
    syncLiveActivity()
  }

  /// What the lock screen and the island show (story 166): pushed only when the step, the pause or the finish
  /// changed, which the controller works out from the content's key.
  private func syncLiveActivity() {
    guard let run else { return }
    let t = now
    liveActivity.sync(
      LiveActivityContent(
        breath: run.plan, elapsed: run.elapsed(now: t), leadIn: run.leadIn, paused: paused, finished: run.isFinished),
      kind: .breathe, stepEndsAt: run.stepEndsAt(now: t))
  }

  private func startClock() {
    stopClock()
    // Twenty looks a second: no step is noticed more than 50 ms late, and lateness cannot add up, because
    // every look derives the step from the clock.
    let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    RunLoop.main.add(timer, forMode: .common)
    clock = timer
  }

  private func stopClock() {
    clock?.invalidate()
    clock = nil
  }

  private func tick() {
    guard var run else { return }
    let effects = run.tick(now: now)
    self.run = run
    for effect in effects {
      switch effect {
      case .phase(let phase, let cycle, let lateMs):
        log.event("breath_phase", ["phase": "\(phase)", "cycle": cycle, "late_ms": lateMs])
        switch cue {
        case .voice: audio.say(BreathPhrase.phrase(for: phase))
        case .tone: audio.play(BreathTone.tone(for: phase))
        case .off: break
        }
        if UIAccessibility.isVoiceOverRunning {
          UIAccessibility.post(notification: .announcement, argument: phase.word)
        }
      case .finished(let lateMs):
        log.event(
          "breath_finished", ["cycles": run.plan.cycles, "total": run.plan.totalSeconds, "late_ms": lateMs])
        database.logActivity(.breathing, name: ActivityLog.breathName(run.plan), seconds: run.plan.totalSeconds)
        if let span = run.mindfulSpan(now: now) { saveMindful(span, "finished") }
        endSession()
        stage = .done
        switch cue {
        case .voice: audio.say(.wellDone)
        case .tone: audio.play(.closing)
        case .off: break
        }
        if UIAccessibility.isVoiceOverRunning {
          UIAccessibility.post(notification: .announcement, argument: "Done")
        }
      }
    }
    if !effects.isEmpty { syncLiveActivity() }
    if let at = pauseAt, stage == .session, run.elapsed(now: now) >= at {
      pauseAt = nil
      pause(reason: "hook")
    }
  }

  private func endSession() {
    pauseAt = nil
    stopClock()
    audio.hush()
    audio.keepAlive(false)
    paused = false
    keepAwake(false)
  }

  private func keepAwake(_ on: Bool) {
    guard UIApplication.shared.isIdleTimerDisabled != on else { return }
    UIApplication.shared.isIdleTimerDisabled = on
    log.event("keep_awake", ["on": on, "reason": "breathe"])
  }
}
