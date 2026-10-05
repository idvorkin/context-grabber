//  The Gym Timer's rounds: a wall-clock-anchored state machine (stories 100, 102, 104, 107).
//
//  State derives from `now - startedAt - paused time`, so a missed tick (the app suspended, a slow main thread)
//  is recovered the next time anyone asks. The engine owns no clock and plays no sound: the app calls `tick(now:)`
//  as often as it likes and carries out the effects that come back. Pure, so the timing is tested on the host.

import Foundation

public enum TimerPhase: String, Equatable, Sendable {
  case idle, prep, work, rest, done
}

public struct TimerProfile: Equatable, Sendable {
  public var name: String
  public var workTime: Int
  public var restTime: Int
  public var rounds: Int
  public var prepTime: Int

  public init(name: String, workTime: Int, restTime: Int, rounds: Int, prepTime: Int) {
    self.name = name
    self.workTime = workTime
    self.restTime = restTime
    self.rounds = rounds
    self.prepTime = prepTime
  }

  /// The four chips beside CUSTOM.
  public static let presets: [(id: String, label: String, profile: TimerProfile)] = [
    ("30sec", "30 SEC", TimerProfile(name: "30sec", workTime: 30, restTime: 5, rounds: 6, prepTime: 5)),
    ("1min", "1 MIN", TimerProfile(name: "1min", workTime: 60, restTime: 10, rounds: 5, prepTime: 5)),
    ("2min", "2 MIN", TimerProfile(name: "2min", workTime: 120, restTime: 15, rounds: 4, prepTime: 10)),
    ("5-1", "5-1", TimerProfile(name: "5-1", workTime: 300, restTime: 60, rounds: 3, prepTime: 10)),
  ]
}

public struct DerivedTimerState: Equatable, Sendable {
  public var phase: TimerPhase
  public var timeLeft: Int
  public var currentRound: Int
  public var totalElapsedSec: Int
  public var done: Bool
}

/// Maps whole seconds since the start (paused time already subtracted) onto phase, round and time left.
/// There is no rest after the last round: done falls the moment the final work round elapses.
public func deriveTimerState(_ profile: TimerProfile, elapsedSec: Int) -> DerivedTimerState {
  let full = profile.prepTime + profile.workTime * profile.rounds + profile.restTime * max(0, profile.rounds - 1)
  let done = DerivedTimerState(
    phase: .done, timeLeft: 0, currentRound: profile.rounds, totalElapsedSec: full, done: true)
  if elapsedSec >= full { return done }

  var t = elapsedSec
  if t < profile.prepTime {
    return DerivedTimerState(
      phase: .prep, timeLeft: profile.prepTime - t, currentRound: 1, totalElapsedSec: elapsedSec, done: false)
  }
  t -= profile.prepTime
  for round in 1...max(1, profile.rounds) {
    if t < profile.workTime {
      return DerivedTimerState(
        phase: .work, timeLeft: profile.workTime - t, currentRound: round, totalElapsedSec: elapsedSec, done: false)
    }
    t -= profile.workTime
    if round < profile.rounds {
      if t < profile.restTime {
        return DerivedTimerState(
          phase: .rest, timeLeft: profile.restTime - t, currentRound: round, totalElapsedSec: elapsedSec, done: false)
      }
      t -= profile.restTime
    }
  }
  return done
}

public enum TimerCue: String, Equatable, Sendable, CaseIterable {
  case three, two, one, go, rest, done
}

/// What a tick asks the app to do, in order.
public enum TimerEffect: Equatable, Sendable {
  /// Keep other audio turned down this long from now (DuckWindow.hold).
  case duckHold(ms: Int)
  case cue(TimerCue)
  case phaseChanged(from: TimerPhase, to: TimerPhase, round: Int)
  /// The last round elapsed: stop ticking and let go of the audio session.
  case finished
}

public struct TimerState: Equatable, Sendable {
  public var isRunning = false
  public var isPaused = false
  public var phase: TimerPhase = .idle
  public var timeLeft = 0
  public var currentRound = 1
  public var totalRounds: Int
  public var totalElapsed = 0
}

public struct TimerEngine {
  public private(set) var profile: TimerProfile
  public private(set) var state: TimerState

  /// Seconds on the caller's clock. nil: not started since the last reset.
  private var startedAt: Double?
  private var pausedAccum: Double = 0
  private var pausedAt: Double?
  private var lastPhase: TimerPhase = .idle
  private var lastTimeLeft = 0

  public init(profile: TimerProfile) {
    self.profile = profile
    state = TimerState(totalRounds: profile.rounds)
  }

  /// True from START until RESET or the finish: a run is in progress or stopped mid-way.
  public var isEngaged: Bool { state.isRunning || state.isPaused }

  /// A new preset. Ignored while a run is in progress: the chips and sliders are inert then.
  public mutating func setProfile(_ next: TimerProfile) {
    guard !isEngaged else { return }
    profile = next
    if state.phase == .idle { state.totalRounds = next.rounds }
  }

  /// START, or RESUME after a stop. START itself says nothing: the ready count's three, two, one leads to the
  /// first go!, and a profile with no ready count goes straight to work, whose phase change says it.
  public mutating func start(now: Double) -> [TimerEffect] {
    guard !state.isRunning else { return [] }
    if let paused = pausedAt {
      pausedAccum += now - paused
      pausedAt = nil
      return tick(now: now, silent: true)
    }
    startedAt = now
    pausedAccum = 0
    lastPhase = .idle
    lastTimeLeft = profile.prepTime
    return tick(now: now)
  }

  public mutating func pause(now: Double) {
    guard startedAt != nil, pausedAt == nil, state.isRunning else { return }
    pausedAt = now
    state.isRunning = false
    state.isPaused = true
  }

  public mutating func reset() {
    startedAt = nil
    pausedAccum = 0
    pausedAt = nil
    lastPhase = .idle
    lastTimeLeft = 0
    state = TimerState(totalRounds: profile.rounds)
  }

  /// Bring the state to `now` and say what to do about it. `silent` is the catch-up after the app was away:
  /// the state moves, nothing is replayed.
  public mutating func tick(now: Double, silent: Bool = false) -> [TimerEffect] {
    guard let startedAt else { return [] }
    let elapsed = (pausedAt ?? now) - startedAt - pausedAccum
    let d = deriveTimerState(profile, elapsedSec: max(0, Int(elapsed.rounded(.down))))
    var effects: [TimerEffect] = []

    if !silent {
      let counting = d.phase != .idle && d.phase != .done
      // The window opens a silent second before the count, so the session's change is done before a word plays.
      if counting, d.timeLeft == 4, d.timeLeft != lastTimeLeft {
        effects.append(.duckHold(ms: DuckWindow.openEarlyHoldMs))
      }
      if counting, (1...3).contains(d.timeLeft), d.timeLeft != lastTimeLeft {
        effects.append(.duckHold(ms: DuckWindow.tickHoldMs))
        effects.append(.cue([.one, .two, .three][d.timeLeft - 1]))
      }
      if d.phase != lastPhase {
        effects.append(.phaseChanged(from: lastPhase, to: d.phase, round: d.currentRound))
        switch d.phase {
        case .work:
          effects.append(.duckHold(ms: DuckWindow.cueHoldMs))
          effects.append(.cue(.go))
        case .rest:
          effects.append(.duckHold(ms: DuckWindow.cueHoldMs))
          effects.append(.cue(.rest))
        case .done:
          effects.append(.duckHold(ms: DuckWindow.finishHoldMs))
          effects.append(.cue(.done))
        default: break
        }
      }
    }
    if d.done, lastPhase != .done { effects.append(.finished) }

    lastPhase = d.phase
    lastTimeLeft = d.timeLeft
    state = TimerState(
      isRunning: !d.done && pausedAt == nil, isPaused: pausedAt != nil && !d.done, phase: d.phase,
      timeLeft: d.timeLeft, currentRound: d.currentRound, totalRounds: profile.rounds,
      totalElapsed: d.totalElapsedSec)
    return effects
  }
}
