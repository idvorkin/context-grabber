//  The daily strip's state (#236, #238): today's values from the database, and the gym days from a tap, the Gym
//  Timer's finished workouts and the last grab's strength workouts. Refreshed whenever the day or a source may
//  have changed: the home screen appearing, the app coming to the front, midnight, a grab, the timer closing.

import BugKit
import ContextCore
import Foundation

@MainActor
final class DailyStripModel: ObservableObject {
  @Published private(set) var today = AccessoryLog.dateKey(Date())
  @Published private(set) var values: [DailyItem: Int] = [:]
  /// Days since each item's last day (2026-10-17, Igor: every item, as gym has): 0 when today counts, absent when
  /// there has never been one.
  @Published private(set) var daysSince: [DailyItem: Int] = [:]
  var daysSinceGym: Int? { daysSince[.gym] }
  /// Today counts as a gym day from the timer or Health, so a tap cannot take it back.
  @Published private(set) var gymFromElsewhere = false
  /// #257: where today's meditation came from without a tap ("breathing", "health"), or nil.
  @Published private(set) var meditationFrom: String?
  /// "item/day" already announced as turning green by itself, so `daily_strip_auto` is one line per item per day.
  private var announced: Set<String> = []

  @Published var problem: BugProblem?
  var bugLogger: BugLogger { log.bugLogger }

  private let log: SessionLog
  private let store: DailyStrip?
  private let activity: ActivityLog?
  private let health: () -> MirrorSnapshot?
  /// #376: the same strip on every device signed into Igor's iCloud.
  private let sync: StripCloudSync?

  /// `health`: the last grab, for its strength workouts and today's mindful minutes.
  init(log: SessionLog, database: AppDatabase, health: @escaping () -> MirrorSnapshot?) {
    self.log = log
    store = database.dailyStrip
    activity = database.activityLog
    self.health = health
    sync = StripCloudSync(database: database, log: log)
    sync?.onArrived = { [weak self] in self?.refresh() }
    refresh()
    sync?.start()
  }

  func value(_ item: DailyItem) -> Int { values[item] ?? 0 }
  var gymToday: Bool { daysSinceGym == 0 }
  var meditationToday: Bool { meditationFrom != nil || value(.meditation) > 0 }

  func refresh() {
    today = AccessoryLog.dateKey(Date())
    do {
      for item in DailyItem.allCases { values[item] = try store?.value(item, day: today) ?? 0 }
      let tapped = try store?.days(.gym) ?? []
      // A year back is plenty to say how long it has been.
      let timer = try activity?.entries(since: Date().addingTimeInterval(-366 * 24 * 3600)) ?? []
      let snapshot = health()
      let elsewhere = DailyStrip.gymDays(tapped: [], timer: timer, workoutsByDay: snapshot?.workoutsByDay ?? [:])
      gymFromElsewhere = elsewhere.contains(today)
      var since: [DailyItem: Int] = [:]
      since[.gym] = DailyStrip.daysSince(tapped.union(elsewhere), today: today)
      since[.meditation] = DailyStrip.daysSince(
        // All of breathing's history, not the year above: a session from long ago is still a last day (Codex).
        DailyStrip.meditationDays(
          tapped: try store?.days(.meditation) ?? [],
          activity: try activity?.entries(since: Date(timeIntervalSince1970: 0)) ?? []), today: today)
      for item in [DailyItem.journal, .balloons, .magic] {
        since[item] = DailyStrip.daysSince(try store?.days(item) ?? [], today: today)
      }
      let grabDay = snapshot.flatMap {
        ISO8601DateFormatter.withFraction.date(from: $0.timestamp) ?? ISO8601DateFormatter().date(from: $0.timestamp)
      }
      .map { AccessoryLog.dateKey($0) }
      meditationFrom = DailyStrip.meditationSource(
        today: today, activity: timer, healthMinutes: snapshot?.health.meditationMinutes, healthDay: grabDay)
      if gymFromElsewhere {
        let from = timer.contains { $0.kind == .gymTimer && $0.dateKey == today } ? "gym_timer" : "health"
        announce(.gym, from: from)
      }
      if let from = meditationFrom {
        since[.meditation] = 0
        announce(.meditation, from: from)
      }
      daysSince = since
      // #404, story 226: every edit and peer arrival comes through here, with the same automatic checks as the app.
      let glance = TodayGlance(day: today, values: values, meditationDone: meditationToday)
      if store != nil, UsageTileStore.writeToday(glance, strip: true) {
        log.event(
          "ui",
          [
            "action": "daily_strip_tile", "day": today, "meditation": meditationToday,
            "journal": value(.journal) > 0, "balloons": value(.balloons), "magic": value(.magic),
          ])
      }
    } catch {
      log.event("error", ["where": "daily_strip", "message": "\(error)"])
    }
  }

  /// A check flips; a counter goes up or down by one, never below 0.
  func change(_ item: DailyItem, by step: Int = 1) {
    refresh()  // the day may have turned since the strip was drawn
    if (item == .gym && gymFromElsewhere) || (item == .meditation && meditationFrom != nil) {
      log.event("ui", ["action": "daily_strip", "item": item.rawValue, "value": 1, "from": "timer_or_health"])
      return
    }
    // #376: a count steps this device's own share; a check flips what every device shows.
    let next: Int
    do {
      if item.isCounter {
        next = try stepCounter(item, day: today, by: step)
      } else {
        next = value(item) > 0 ? 0 : 1
        try store?.set(item, day: today, value: next)
      }
    } catch {
      log.event("error", ["where": "daily_strip", "item": item.rawValue, "message": "\(error)"])
      return
    }
    log.event("ui", ["action": "daily_strip", "item": item.rawValue, "value": next, "day": today])
    problem = nil
    sync?.changed(day: today)
    refresh()
  }

  /// #414, story 255: a frozen two-week snapshot, including the automatic checks the strip already knows.
  func fortnight(_ item: DailyItem) -> CheckFortnight? {
    refresh()
    do {
      guard let store else { throw CocoaError(.fileReadUnknown) }
      let entries = try activity?.entries(since: Date(timeIntervalSince1970: 0)) ?? []
      var automatic: Set<String> = []
      var marks: [String: [GymDayMark]] = [:]
      if item == .gym {
        let workoutsByDay = health()?.workoutsByDay ?? [:]
        automatic = DailyStrip.gymDays(tapped: [], timer: entries, workoutsByDay: workoutsByDay)
        marks = DailyStrip.gymMarks(timer: entries, workoutsByDay: workoutsByDay)  // #1503, story 570
      } else if item == .meditation {
        automatic = DailyStrip.meditationDays(tapped: [], activity: entries)
        if meditationFrom != nil { automatic.insert(today) }
      }
      problem = nil
      return CheckFortnight(item, today: today, marked: try store.days(item), automatic: automatic, marks: marks)
    } catch {
      log.event("error", ["where": "daily_strip", "item": item.rawValue, "message": "\(error)"])
      problem = .grabber(
        "Could not load the last fourteen days: \(error.localizedDescription)", context: "daily strip: load grid",
        extra: ["item": .string(item.rawValue), "today": .string(today)])
      return nil
    }
  }

  /// #414: use today's same dated write and sync path, including a zero that takes a peer's check back.
  func save(_ fortnight: CheckFortnight) -> Bool {
    do {
      guard let store else { throw CocoaError(.fileWriteUnknown) }
      try store.save(fortnight)
    } catch {
      log.event("error", ["where": "daily_strip", "item": fortnight.item.rawValue, "message": "\(error)"])
      problem = .grabber(
        "Could not save the days: \(error.localizedDescription)", context: "daily strip: save grid",
        extra: [
          "item": .string(fortnight.item.rawValue),
          "days": .string(fortnight.changes.map(\.day).joined(separator: ", ")),
        ])
      return false
    }
    for change in fortnight.changes {
      log.event(
        "ui",
        [
          "action": "daily_strip", "item": fortnight.item.rawValue, "day": change.day,
          "value": change.done ? 1 : 0, "backdated": change.daysAgo, "done": change.done,
        ])
      sync?.changed(day: change.day)
    }
    problem = nil
    refresh()
    return true
  }

  /// #342: a counter's last seven days, for the sheet its press and hold opens.
  func week(_ item: DailyItem) -> CounterWeek? {
    refresh()  // the day may have turned since the strip was drawn
    guard let store else { return nil }
    do {
      return try CounterWeek(item, today: today, strip: store)
    } catch {
      log.event("error", ["where": "daily_strip", "item": item.rawValue, "message": "\(error)"])
      return nil
    }
  }

  /// #342: Confirm in a counter's week saves every day changed there, each as a tap's step would be.
  func save(_ week: CounterWeek) {
    for change in week.changes {
      // The step, onto the count as it is now: iCloud may have restored this device's days while the sheet was up.
      let next: Int
      do {
        next = try stepCounter(week.item, day: change.day, by: change.step)
      } catch {
        log.event("error", ["where": "daily_strip", "item": week.item.rawValue, "message": "\(error)"])
        continue
      }
      var fields: [String: Any] = [
        "action": "daily_strip", "item": week.item.rawValue, "value": next, "day": change.day,
      ]
      if change.daysAgo > 0 { fields["backdated"] = change.daysAgo }
      log.event("ui", fields)
      sync?.changed(day: change.day)
    }
    refresh()
  }

  /// A counter's own count steps, never below 0. With the sync, the step as applied (a − at 0 changes nothing) is
  /// held with the write while the first sync is awaited, in one transaction (#380, #384).
  private func stepCounter(_ item: DailyItem, day: String, by step: Int) throws -> Int {
    if let sync { return try sync.step(item, day: day, by: step) }
    let next = max(0, (try store?.ownValue(item, day: day) ?? 0) + step)
    try store?.set(item, day: day, value: next)
    return next
  }

  /// One `daily_strip_auto` line per item per day, the first time it is seen green with no tap.
  private func announce(_ item: DailyItem, from: String) {
    guard announced.insert("\(item.rawValue)/\(today)").inserted else { return }
    log.event("daily_strip_auto", ["item": item.rawValue, "from": from, "day": today])
  }
}

extension ISO8601DateFormatter {
  /// The grab's timestamp carries milliseconds.
  static let withFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()
}
