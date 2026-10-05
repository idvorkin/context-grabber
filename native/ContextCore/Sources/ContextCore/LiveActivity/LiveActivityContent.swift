//  What a Live Activity says (spec 2026-10-04-native-live-activity-design.md): one card for every screen that has
//  one — the Gym Timer (story 106) and Box breathing (story 166). A screen only decides the words, the times and
//  the colour; the card draws them all the same way. The countdown itself runs on the phone from an end date, so
//  `key` changes only when the card must be pushed again (a new step, a pause or resume, the finish), never once
//  a second.

import Foundation

public enum LiveActivityKind: String, Equatable, Sendable {
  case gymTimer, breathe
}

/// Colour tokens; the widget extension turns them into colours.
public enum LiveActivityAccent: String, Equatable, Sendable {
  case red, green, amber, white
}

public struct LiveActivityContent: Equatable, Sendable {
  public var kind: LiveActivityKind
  /// GET READY / WORK / Inhale / PAUSED / DONE! …
  public var title: String
  /// "Round 2/4", "Cycle 3 of 9", "WORK · Round 2/4" when paused, "4 rounds completed" when done.
  public var subtitle: String
  /// The island's compact leading text: "WORK 2/4", "IN 3/9".
  public var compactLabel: String
  public var accent: LiveActivityAccent
  /// Whole seconds left in the step: the still time when paused.
  public var secondsLeft: Int
  /// The whole step's length, for the progress bar. 0 when finished.
  public var stepSeconds: Int
  public var paused: Bool
  public var finished: Bool
  public var key: String

  // MARK: - the Gym Timer

  /// nil while idle: no workout, no card.
  public init?(timer state: TimerState, profile: TimerProfile) {
    let round = "\(state.currentRound)/\(state.totalRounds)"
    kind = .gymTimer
    secondsLeft = state.timeLeft
    paused = state.isPaused
    finished = state.phase == .done
    switch state.phase {
    case .idle: return nil
    case .prep: (title, compactLabel, stepSeconds, accent) = ("GET READY", "READY \(round)", profile.prepTime, .amber)
    case .work: (title, compactLabel, stepSeconds, accent) = ("WORK", "WORK \(round)", profile.workTime, .red)
    case .rest: (title, compactLabel, stepSeconds, accent) = ("REST", "REST \(round)", profile.restTime, .green)
    case .done: (title, compactLabel, stepSeconds, accent) = ("DONE!", "DONE!", 0, .red)
    }
    if finished {
      subtitle = "\(state.totalRounds) \(state.totalRounds == 1 ? "round" : "rounds") completed"
    } else if paused {
      subtitle = "\(title) · Round \(round)"
      title = "PAUSED"
      compactLabel = "PAUSED \(round)"
      accent = .amber
    } else {
      subtitle = "Round \(round)"
    }
    key = "\(state.phase.rawValue)|\(state.currentRound)|\(paused ? "paused" : "running")"
  }

  // MARK: - Box breathing

  /// The session `elapsed` seconds into the breathing (negative in the quiet before the first inhale, which has no
  /// card). `finished` once the run has ended.
  public init?(breath plan: BreathPlan, elapsed: Double, paused: Bool, finished: Bool) {
    kind = .breathe
    accent = .white
    self.paused = paused && !finished
    self.finished = finished
    if finished {
      (title, subtitle, compactLabel, secondsLeft, stepSeconds) = ("Done", plan.doneText, "Done", 0, 0)
      key = "done"
      return
    }
    guard elapsed >= 0 else { return nil }
    let m = plan.moment(at: elapsed)
    guard !m.done else { return nil }  // the run says when it is finished
    let short: String
    switch m.phase {
    case .inhale: short = "IN"
    case .exhale: short = "OUT"
    case .holdFull, .holdEmpty: short = "HOLD"
    }
    let stepEnd = Double((m.phaseIndex + 1) * plan.breathSeconds)
    secondsLeft = Int((stepEnd - elapsed).rounded(.up))
    stepSeconds = plan.breathSeconds
    let cycle = "Cycle \(m.cycle) of \(plan.cycles)"
    if self.paused {
      (title, subtitle, compactLabel) = ("PAUSED", "\(m.phase.word) · \(cycle)", "PAUSED \(m.cycle)/\(plan.cycles)")
    } else {
      (title, subtitle, compactLabel) = (m.phase.word, cycle, "\(short) \(m.cycle)/\(plan.cycles)")
    }
    key = "\(m.phaseIndex)|\(self.paused ? "paused" : "running")"
  }
}

extension BreathRun {
  /// When the current step ends, on the caller's clock, to the fraction of a second. nil unless running.
  public func stepEndsAt(now: Double) -> Double? {
    guard isRunning, !isFinished else { return nil }
    let t = elapsed(now: now)
    let index = max(0, Int((max(0, t) / Double(plan.breathSeconds)).rounded(.down)))
    return now + Double((index + 1) * plan.breathSeconds) - t
  }
}
