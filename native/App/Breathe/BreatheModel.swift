//  The breathing screen's state (stories 160–165): the three choices, the session against the clock, the cues.
//
//  ContextCore's BreathRun decides everything from the clock, and BreathSession when the cues, the keepalive, the lit
//  screen and the card are taken and let go; this publishes the stage, remembers the choices and saves to Health.

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
  typealias Stage = BreathSession.Stage

  @Published private(set) var stage = Stage.setup
  /// The preset chosen (story 241), or nil for Custom.
  @Published private(set) var preset: Int?
  /// #289: a four-sided pattern, chosen instead of a preset or Custom.
  @Published private(set) var pattern: BreathPattern?
  @Published private(set) var customIn: Int
  @Published private(set) var customOut: Int
  @Published private(set) var sessionMinutes: Int
  @Published private(set) var cue: BreathCue {
    didSet { session.cue = cue }
  }
  /// How the circle draws the breath (story 240).
  @Published private(set) var style: BreathStyle
  @Published private(set) var paused = false
  /// The session on screen or just finished; Done shows its length.
  @Published private(set) var sessionPlan: BreathPlan?

  private let log: SessionLog
  private let database: AppDatabase
  private let audio: BreatheAudio
  private let session: BreathSession

  private static let sessionKey = "breathe_session_minutes"
  private static let cueKey = "breathe_cue"

  init(
    log: SessionLog, database: AppDatabase, liveActivity: LiveActivityController,
    saveMindful: @escaping (TimeSpan, String) -> Void = { _, _ in }
  ) {
    self.log = log
    self.database = database
    let audio = BreatheAudio(log: log)
    self.audio = audio
    let (setup, seeds) = BreathSetup.restore(database.setting)
    for seed in seeds { database.setSetting(seed.key, seed.value) }
    preset = setup.preset
    pattern = setup.pattern
    customIn = setup.customIn
    customOut = setup.customOut
    sessionMinutes = database.setting(Self.sessionKey).flatMap(Int.init) ?? BreathPlan.defaultSession
    let cue = database.setting(Self.cueKey).flatMap(BreathCue.init(rawValue:)) ?? .voice
    self.cue = cue
    style = BreathStyle.decode(database.setting(BreathStyle.settingKey))
    session = BreathSession(
      cue: cue, host: AppSessionHost(log: log, liveActivity: liveActivity), audio: audio, saveMindful: saveMindful,
      finished: { [database] plan in
        database.logActivity(.breathing, name: ActivityLog.breathName(plan), seconds: plan.totalSeconds)
      })
    session.onChange = { [weak self] in self?.mirror() }
    audio.load()
  }

  var plan: BreathPlan {
    if let pattern { return BreathPlan(pattern: pattern, sessionMinutes: sessionMinutes) }
    if let preset { return BreathPlan(breathSeconds: preset, sessionMinutes: sessionMinutes) }
    return BreathPlan(inSeconds: customIn, outSeconds: customOut, sessionMinutes: sessionMinutes)
  }

  // MARK: - setup

  /// A preset's seconds (nil for Custom) as the remembered choice; also a hold popover's choice (#391), saved before
  /// the screen opens and reads it.
  static func remember(preset seconds: Int?, in database: AppDatabase) {
    for write in BreathSetup.writes(preset: seconds, database.setting) { database.setSetting(write.key, write.value) }
  }

  /// A preset's seconds, or nil for Custom.
  func choosePreset(_ seconds: Int?) {
    guard seconds != preset || pattern != nil else { return }
    pattern = nil
    preset = seconds
    Self.remember(preset: seconds, in: database)
    log.event("ui", ["action": "breath_preset", "preset": seconds.map(String.init) ?? "custom"])
  }

  /// #289: one tap, like a preset; remembered until a preset or Custom is chosen.
  func choosePattern(_ next: BreathPattern) {
    guard next != pattern else { return }
    pattern = next
    preset = nil
    for write in BreathSetup.writes(pattern: next) { database.setSetting(write.key, write.value) }
    log.event("ui", ["action": "breath_preset", "preset": next.key])
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
        pattern.map { BreathPlan(pattern: $0, sessionMinutes: minutes) }
          ?? preset.map { BreathPlan(breathSeconds: $0, sessionMinutes: minutes) }
          ?? BreathPlan(inSeconds: customIn, outSeconds: customOut, sessionMinutes: minutes)
      } ?? self.plan)
    session.begin(plan, pauseAt: launch.pauseAt)
  }

  /// A tap on the circle.
  func togglePause() { session.togglePause() }

  /// The back chevron: out at once, no question.
  func back() { session.back() }

  func backToStart() { session.backToStart() }

  /// Leaving the screen altogether.
  func disappear() { session.disappear() }

  /// Where the ring is at `date`; frozen while paused.
  func moment(at date: Date) -> BreathMoment? { session.moment(now: date.timeIntervalSince1970) }

  /// True in the quiet before the first inhale.
  func inLeadIn(at date: Date) -> Bool { session.inLeadIn(now: date.timeIntervalSince1970) }

  /// The session's stage, pause and plan, published.
  private func mirror() {
    if stage != session.stage { stage = session.stage }
    if paused != session.paused { paused = session.paused }
    if sessionPlan != session.sessionPlan { sessionPlan = session.sessionPlan }
  }
}
