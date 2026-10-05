//  The Gym Timer's state for one visit to the screen: the rounds engine and its clock, the stopwatch, the set
//  count, the chosen preset, and which way the phone is turned. The logic is ContextCore's; this class owns the
//  clock, carries out the engine's effects, remembers, and writes the session log.

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
  @Published var mode: GymMode = .rounds
  @Published private(set) var presetId = "30sec"
  @Published private(set) var custom = CustomPreset.default
  @Published private(set) var timer: TimerState
  @Published private(set) var stopwatch = Stopwatch()
  @Published private(set) var sets = 0
  @Published private(set) var turn = DeviceTurn.upright

  private var engine: TimerEngine
  private var clock: Timer?
  private let audio: GymAudio
  private let log: SessionLog
  private let database: AppDatabase
  private let motion = CMMotionManager()
  private lazy var duck = DuckWindow(
    session: audio,
    schedule: { afterMs, block in
      let item = DispatchWorkItem(block: block)
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(afterMs), execute: item)
      return { item.cancel() }
    },
    log: { [log] action, holdMs in log.event("timer_duck", ["action": action, "hold_ms": holdMs]) })

  private static let presetKey = "gym_custom_preset"
  private static let chosenKey = "gym_active_preset"
  private static let setsKey = "gym_sets_count"

  init(log: SessionLog, database: AppDatabase) {
    self.log = log
    self.database = database
    audio = GymAudio(log: log)
    let first = TimerProfile.presets[0].profile
    engine = TimerEngine(profile: first)
    timer = engine.state
    custom = CustomPreset.decode(database.setting(Self.presetKey))
    sets = SetCounter.clamp(Int(database.setting(Self.setsKey) ?? "") ?? 0)
    if let chosen = database.setting(Self.chosenKey), Self.isPreset(chosen) { presetId = chosen }
    engine.setProfile(profile)
    timer = engine.state
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
  var locked: Bool { engine.isEngaged }

  private var now: Double { Date().timeIntervalSince1970 }

  // MARK: - rounds

  func choosePreset(_ id: String) {
    guard !locked, Self.isPreset(id) else { return }
    presetId = id
    database.setSetting(Self.chosenKey, id)
    engine.setProfile(profile)
    timer = engine.state
  }

  func changeCustom(_ next: CustomPreset) {
    guard !locked else { return }
    custom = next.normalized
    database.setSetting(Self.presetKey, custom.encoded)
    engine.setProfile(profile)
    timer = engine.state
  }

  /// For a link or a launch hook: a profile that is not on a chip, chosen as Custom without being remembered.
  func useCustomOnce(_ preset: CustomPreset) {
    guard !locked else { return }
    custom = preset.normalized
    presetId = CustomPreset.id
    engine.setProfile(profile)
    timer = engine.state
  }

  func toggleTimer() {
    if timer.isRunning {
      engine.pause(now: now)
      clock?.invalidate()
      clock = nil
      timer = engine.state
      log.event("timer_pause", ["phase": timer.phase.rawValue, "round": timer.currentRound, "time_left": timer.timeLeft])
      return
    }
    let p = engine.profile
    log.event(
      "timer_start",
      [
        "preset": p.name, "work": p.workTime, "rest": p.restTime, "rounds": p.rounds, "prep": p.prepTime,
        "resumed": timer.isPaused,
      ])
    audio.start()
    perform(engine.start(now: now))
    clock?.invalidate()
    // Ten looks a second: a boundary is called within a tenth of its true time, and the engine only answers
    // when the second changes.
    clock = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.tick() }
    }
  }

  func resetTimer() {
    clock?.invalidate()
    clock = nil
    engine.reset()
    engine.setProfile(profile)
    timer = engine.state
    duck.close()
    audio.stop()
    log.event("timer_reset")
  }

  private func tick(silent: Bool = false) {
    perform(engine.tick(now: now, silent: silent))
  }

  /// The app came back to the front: move the state to now without replaying what was missed (story 107).
  func catchUp() {
    guard timer.isRunning else { return }
    tick(silent: true)
    log.event(
      "timer_catchup", ["phase": timer.phase.rawValue, "round": timer.currentRound, "time_left": timer.timeLeft])
  }

  private func perform(_ effects: [TimerEffect]) {
    for effect in effects {
      switch effect {
      case .duckHold(let ms): duck.hold(ms)
      case .cue(let cue): audio.play(cue)
      case .phaseChanged(let from, let to, let round):
        log.event("timer_phase", ["from": from.rawValue, "to": to.rawValue, "round": round])
      case .finished:
        clock?.invalidate()
        clock = nil
        log.event("timer_finished", ["rounds": engine.profile.rounds])
        // "done" is still sounding: the window's release lets go of the session. With no window open (a
        // finish found on coming back) there is nothing to wait for.
        if duck.isOpen { audio.stopWhenReleased() } else { audio.stop() }
      }
    }
    if timer != engine.state { timer = engine.state }
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
  func appear(forcedTurn: DeviceTurn? = nil) {
    UIApplication.shared.isIdleTimerDisabled = true
    log.event("keep_awake", ["on": true, "reason": "gym_timer"])
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

  /// Done: the lock goes back to the phone's own setting and the session is let go.
  func disappear() {
    motion.stopAccelerometerUpdates()
    UIApplication.shared.isIdleTimerDisabled = false
    log.event("keep_awake", ["on": false, "reason": "gym_timer"])
    clock?.invalidate()
    clock = nil
    duck.close()
    audio.stop()
  }

  // MARK: - accessory work

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
