//  The daily strip's state (#236, #238): today's values from the database, and the gym days from a tap, the Gym
//  Timer's finished workouts and the last grab's strength workouts. Refreshed whenever the day or a source may
//  have changed: the home screen appearing, the app coming to the front, midnight, a grab, the timer closing.

import ContextCore
import Foundation

@MainActor
final class DailyStripModel: ObservableObject {
  @Published private(set) var today = AccessoryLog.dateKey(Date())
  @Published private(set) var values: [DailyItem: Int] = [:]
  /// Days since the last gym day: 0 when today counts, nil when there has never been one.
  @Published private(set) var daysSinceGym: Int?
  /// Today counts as a gym day from the timer or Health, so a tap cannot take it back.
  @Published private(set) var gymFromElsewhere = false

  private let log: SessionLog
  private let store: DailyStrip?
  private let activity: ActivityLog?
  private let workoutsByDay: () -> [String: [WorkoutEntry]]

  init(log: SessionLog, database: AppDatabase, workoutsByDay: @escaping () -> [String: [WorkoutEntry]]) {
    self.log = log
    store = database.dailyStrip
    activity = database.activityLog
    self.workoutsByDay = workoutsByDay
    refresh()
  }

  func value(_ item: DailyItem) -> Int { values[item] ?? 0 }
  var gymToday: Bool { daysSinceGym == 0 }

  func refresh() {
    today = AccessoryLog.dateKey(Date())
    do {
      for item in DailyItem.allCases { values[item] = try store?.value(item, day: today) ?? 0 }
      let tapped = try store?.days(.gym) ?? []
      // A year back is plenty to say how long it has been.
      let timer = try activity?.entries(since: Date().addingTimeInterval(-366 * 24 * 3600)) ?? []
      let elsewhere = DailyStrip.gymDays(tapped: [], timer: timer, workoutsByDay: workoutsByDay())
      gymFromElsewhere = elsewhere.contains(today)
      daysSinceGym = DailyStrip.daysSince(tapped.union(elsewhere), today: today)
    } catch {
      log.event("error", ["where": "daily_strip", "message": "\(error)"])
    }
  }

  /// A check flips; a counter goes up or down by one, never below 0.
  func change(_ item: DailyItem, by step: Int = 1) {
    refresh()  // the day may have turned since the strip was drawn
    if item == .gym, gymFromElsewhere {
      log.event("ui", ["action": "daily_strip", "item": item.rawValue, "value": 1, "from": "timer_or_health"])
      return
    }
    let now = value(item)
    let next = item.isCounter ? max(0, now + step) : (now > 0 ? 0 : 1)
    do {
      try store?.set(item, day: today, value: next)
    } catch {
      log.event("error", ["where": "daily_strip", "item": item.rawValue, "message": "\(error)"])
      return
    }
    log.event("ui", ["action": "daily_strip", "item": item.rawValue, "value": next, "day": today])
    refresh()
  }
}
