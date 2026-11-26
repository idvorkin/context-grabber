//  #1503, story 570: what was done on a gym day (the Gym Timer, each kind of Health workout), shown as icons under
//  the two-week sheet's tiles.

import Foundation

/// One thing done on a gym day.
public enum GymDayMark: Equatable, Hashable, Sendable {
  /// A finished Gym Timer workout.
  case timer
  /// A Health workout, by Health's activity name ("Functional Strength", "Running").
  case workout(String)

  /// The SF Symbol drawn for it; a kind without its own figure gets a generic one.
  public var symbol: String {
    switch self {
    case .timer: return "stopwatch"
    case .workout(let kind): return Self.symbols[kind] ?? "figure.mixed.cardio"
    }
  }

  /// What VoiceOver reads.
  public var name: String {
    switch self {
    case .timer: return "Gym Timer"
    case .workout(let kind): return kind
    }
  }

  private static let symbols: [String: String] = [
    "Strength Training": "figure.strengthtraining.traditional",
    "Functional Strength": "figure.strengthtraining.functional",
    "Running": "figure.run",
    "Walking": "figure.walk",
    "Cycling": "figure.outdoor.cycle",
    "Hiking": "figure.hiking",
    "Swimming": "figure.pool.swim",
    "Stretching": "figure.flexibility",
    "Rowing": "figure.rower",
    "Dance": "figure.dance",
    "Cross Training": "figure.cross.training",
    "Mixed Cardio": "figure.mixed.cardio",
  ]
}

/// The icons a tile has room for: up to three, else the first two and how many more.
public struct GymDayIcons: Equatable, Sendable {
  public let shown: [GymDayMark]
  public let more: Int

  public init(shown: [GymDayMark], more: Int) {
    self.shown = shown
    self.more = more
  }
}

extension DailyStrip {
  /// Each day's marks: the strength workouts that make it a gym day first, then the Gym Timer, then the other
  /// workouts in the order Health gave them; each kind once. A day with nothing recorded has no entry.
  public static func gymMarks(
    timer: [ActivityEntry], workoutsByDay: [String: [WorkoutEntry]]
  ) -> [String: [GymDayMark]] {
    let timerDays = Set(timer.filter { $0.kind == .gymTimer }.map(\.dateKey))
    var marks: [String: [GymDayMark]] = [:]
    for day in timerDays.union(workoutsByDay.keys) {
      let kinds = (workoutsByDay[day] ?? []).map(\.activityType)
      var ordered = kinds.filter { strengthWorkouts.contains($0) }.map(GymDayMark.workout)
      if timerDays.contains(day) { ordered.append(.timer) }
      ordered += kinds.filter { !strengthWorkouts.contains($0) }.map(GymDayMark.workout)
      var seen = Set<GymDayMark>()
      let unique = ordered.filter { seen.insert($0).inserted }
      if !unique.isEmpty { marks[day] = unique }
    }
    return marks
  }

  /// What fits on a tile: three icons, or the first two and "+N".
  public static func gymIcons(_ marks: [GymDayMark], fit: Int = 3) -> GymDayIcons {
    marks.count <= fit
      ? GymDayIcons(shown: marks, more: 0)
      : GymDayIcons(shown: Array(marks.prefix(fit - 1)), more: marks.count - fit + 1)
  }
}
