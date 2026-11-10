//  The Gym Timer's state for the app's lifetime (#791): the rounds engine and its clock, the stopwatch, the set
//  count, the mode, the chosen preset, and which way the phone is turned. The app owns one, so a workout outlives
//  the screen: leaving it lets go of only what the screen needed (the lit screen, the accelerometer), and of the
//  audio and the card too when nothing is running. The logic is ContextCore's: TimerEngine says what each second
//  calls and TimerSession when the audio, the lit screen, the clock and the card are taken and let go; this class
//  publishes the state, remembers, reads the accelerometer and records the finish.

import BugKit
import ContextCore
import CoreMotion
import SwiftUI
import UIKit

/// The database did not open at launch (the log has `error` where database), so nothing can be saved.
struct NoDatabase: Error, CustomStringConvertible {
  var description: String { "the database is not available" }
}

enum GymMode: String, CaseIterable {
  case rounds, stopwatch, sets
}

@MainActor
final class GymTimerModel: ObservableObject {
  /// Remembered across leaving and relaunching (story 188).
  @Published var mode: GymMode = .rounds {
    didSet { if mode != oldValue { database.setSetting(Self.modeKey, mode.rawValue) } }
  }
  @Published private(set) var presetId = "30sec"
  @Published private(set) var custom = CustomPreset.default
  /// TimerSession's state; the session syncs the lock-screen card at every change (story 106).
  @Published private(set) var timer: TimerState
  @Published private(set) var stopwatch = Stopwatch()
  @Published private(set) var sets = 0
  @Published private(set) var turn = DeviceTurn.upright
  @Published private(set) var countVoice = CountVoice.default

  private let session: TimerSession
  private let audio: GymAudio
  private let log: SessionLog
  private let database: AppDatabase
  private let motion = CMMotionManager()

  private static let presetKey = "gym_custom_preset"
  private static let chosenKey = "gym_active_preset"
  private static let setsKey = "gym_sets_count"
  private static let modeKey = "gym_mode"
  init(log: SessionLog, database: AppDatabase, liveActivity: LiveActivityController) {
    self.log = log
    self.database = database
    let audio = GymAudio(log: log)
    self.audio = audio
    var record: (TimerProfile) -> Void = { _ in }
    session = TimerSession(
      profile: TimerProfile.presets[0].profile, host: AppSessionHost(log: log, liveActivity: liveActivity),
      audio: audio, finished: { record($0) })
    timer = session.state
    sets = SetCounter.clamp(Int(database.setting(Self.setsKey) ?? "") ?? 0)
    if let stored = database.setting(Self.modeKey).flatMap(GymMode.init(rawValue:)) { mode = stored }
    record = { [weak self] profile in self?.recordFinish(profile) }
    session.onChange = { [weak self] state in self?.timer = state }
    restoreSaved()
    audio.loadCues()
  }

  static func isPreset(_ id: String) -> Bool {
    id == CustomPreset.id || TimerProfile.presets.contains { $0.id == id }
  }

  /// What the chosen chip runs.
  var profile: TimerProfile {
    presetId == CustomPreset.id
      ? custom.profile : (TimerProfile.presets.first { $0.id == presetId }?.profile ?? TimerProfile.presets[0].profile)
  }

  /// The chips and the Custom sliders are inert from START until RESET or the finish.
  var locked: Bool { session.locked }

  private var now: Double { Date().timeIntervalSince1970 }

  // MARK: - rounds

  func choosePreset(_ id: String) {
    guard !locked, Self.isPreset(id) else { return }
    presetId = id
    database.setSetting(Self.chosenKey, id)
    applyProfile()
  }

  func changeCustom(_ next: CustomPreset) {
    guard !locked else { return }
    custom = next.normalized
    database.setSetting(Self.presetKey, custom.encoded)
    applyProfile()
  }

  /// A Custom dial let go (story 184): one line per gesture, not per step.
  func dialed(_ dial: String, style: String, from source: String) {
    let value = dial == "work" ? custom.work : dial == "rest" ? custom.rest : custom.rounds
    log.event("ui", ["action": "custom_dial", "dial": dial, "value": value, "style": style, "from": source])
  }

  /// For a link or a launch hook: a profile that is not on a chip, chosen as Custom for this visit only.
  func useCustomOnce(_ preset: CustomPreset) {
    guard !locked else { return }
    custom = preset.normalized
    presetId = CustomPreset.id
    applyProfile()
  }

  /// The chosen preset onto the face. After a finish that is a RESET: donE goes and the new preset stands ready.
  private func applyProfile() {
    session.choose(profile)
  }

  func toggleTimer() {
    session.toggle()
  }

  /// A link, tile or hook that starts a workout (story 188), in Rounds: a running one is left alone, a paused one
  /// resumes, a finished one goes back to ready and starts again.
  func autostart() {
    mode = .rounds
    session.autostart(profile)
  }

  func resetTimer() {
    session.reset(to: profile)
  }

  /// The app came back to the front: move the state to now (story 107).
  func catchUp() {
    session.catchUp()
  }

  /// The finish, in the activity log under the chip's name.
  private func recordFinish(_ finished: TimerProfile) {
    let custom = presetId == CustomPreset.id
    let label = TimerProfile.presets.first { $0.id == presetId }?.label ?? "CUSTOM"
    database.logActivity(
      .gymTimer, name: ActivityLog.gymName(label: label, profile: finished, custom: custom),
      seconds: ActivityLog.gymSeconds(finished))
  }

  // MARK: - the count voice (stories 182, 187)

  /// Chosen in Timer settings: remembered, used from the next cue, and its "go" played as a sample.
  func chooseCountVoice(_ voice: CountVoice) {
    countVoice = voice
    database.setSetting(CountVoice.settingKey, voice.rawValue)
    log.event("ui", ["action": "count_voice", "voice": voice.rawValue, "from": "settings"])
    audio.setVoice(voice)
    audio.sample(voice)
  }

  func openedSettings(from source: String) {
    log.event("ui", ["action": "timer_settings", "from": source, "voice": countVoice.rawValue])
  }

  /// For a launch hook: this visit only, not remembered and no sample.
  func useCountVoiceOnce(_ voice: CountVoice) {
    countVoice = voice
    log.event("ui", ["action": "count_voice", "voice": voice.rawValue, "from": "hook"])
    audio.setVoice(voice)
  }

  // MARK: - stopwatch and sets

  func toggleStopwatch() {
    stopwatch.toggle(now: now)
    log.event("stopwatch", ["running": stopwatch.isRunning, "elapsed_ms": stopwatch.elapsedMs(now: now)])
  }

  func lap() { stopwatch.lap(now: now) }
  func resetStopwatch() { stopwatch.reset() }
  func stopwatchMs(at date: Date) -> Int { stopwatch.elapsedMs(now: date.timeIntervalSince1970) }

  func setSets(_ count: Int) {
    sets = SetCounter.clamp(count)
    database.setSetting(Self.setsKey, String(sets))
  }

  // MARK: - the screen's lifetime

  /// The timer is open: the screen stays lit (story 115) and the display follows the phone's turn (story 109).
  /// A workout left running (story 188) is shown where it is now.
  func appear(forcedTurn: DeviceTurn? = nil) {
    session.appear(mode: mode.rawValue, stopwatchRunning: stopwatch.isRunning)
    if let forcedTurn {
      turn = forcedTurn
      return
    }
    guard motion.isAccelerometerAvailable else { return }
    motion.accelerometerUpdateInterval = 0.2
    motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
      guard let a = data?.acceleration else { return }
      MainActor.assumeIsolated {
        guard let self else { return }
        let next = DeviceTurn.classify(x: a.x, y: a.y, previous: self.turn)
        if next != self.turn {
          self.turn = next
          self.log.event("timer_turn", ["turn": next.rawValue])
        }
      }
    }
  }

  /// Done: the lock goes back to the phone's own setting. A running workout carries on, cues, card and all, as
  /// with the phone locked (story 188); with nothing running the session and the card are let go.
  func disappear() {
    motion.stopAccelerometerUpdates()
    if session.disappear(stopwatchRunning: stopwatch.isRunning) { restoreSaved() }
  }

  /// The saved Custom, chip and count voice; on leaving, a visit's one-off profile and voice give way to them. A
  /// paused workout keeps the profile it is running.
  private func restoreSaved() {
    countVoice = CountVoice.decode(database.setting(CountVoice.settingKey))
    audio.setVoice(countVoice)
    guard !locked else { return }
    custom = CustomPreset.decode(database.setting(Self.presetKey))
    presetId = database.setting(Self.chosenKey).flatMap { Self.isPreset($0) ? $0 : nil } ?? TimerProfile.presets[0].id
    session.restore(profile)
  }

  /// Box breathing, a call, the Cockpit or the eulogy song's player is opening (story 191): a running rounds workout
  /// pauses, and off the screen lets go of its session and card (TimerSession.yield).
  func yield(to other: String) {
    session.yield(to: other)
  }

  // MARK: - accessory work

  var bugLogger: BugLogger { log.bugLogger }

  func saveAccessory(_ ids: [String]) throws -> Int {
    guard let accessoryLog = database.accessoryLog else {
      log.event("error", ["where": "accessory_save", "message": "no database"])
      throw NoDatabase()
    }
    do {
      let count = try accessoryLog.log(itemIds: ids)
      log.event("accessory_saved", ["count": count, "items": ids.joined(separator: ",")])
      return count
    } catch {
      log.event("error", ["where": "accessory_save", "items": ids.joined(separator: ","), "message": "\(error)"])
      throw error
    }
  }

  func accessoryHistory() throws -> [AccessoryLogDay] {
    do {
      return try database.accessoryLog?.recentDays() ?? []
    } catch {
      log.event("error", ["where": "accessory_history", "message": "\(error)"])
      throw error
    }
  }

  /// Story 116: this launch's timer events behind a build line, for pasting at the gym.
  func timerLogText() -> String {
    let lines = log.snapshot().split(separator: "\n").filter {
      $0.contains("\"type\":\"timer_") || $0.contains("\"type\":\"error\"") || $0.contains("\"type\":\"session_start\"")
    }
    return (["build: \(BuildInfo.sha) \(BuildInfo.branch)  mode: \(mode.rawValue)  preset: \(presetId)"] + lines)
      .joined(separator: "\n")
  }
}
