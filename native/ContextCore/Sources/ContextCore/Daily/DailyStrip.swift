//  The daily strip (#236, #238; home-screen spec, "The daily strip"): gym and journal checks and the balloon and
//  magic counts, one value per item per LOCAL day, kept so the week can be read later. Gym also counts a day the
//  Gym Timer finished a workout or Health has a strength workout, and says how many days since the last.

import Foundation

public enum DailyItem: String, CaseIterable, Sendable {
  case gym, meditation, journal, balloons, magic

  public var isCounter: Bool { self == .balloons || self == .magic }
}

public struct DailyStrip {
  private let db: SQLiteDatabase

  public init(db: SQLiteDatabase) throws {
    self.db = db
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS daily_strip (
        date_key TEXT NOT NULL,
        item     TEXT NOT NULL,
        value    INTEGER NOT NULL,
        PRIMARY KEY (date_key, item)
      );
      """)
  }

  /// 0 for a day with nothing recorded.
  public func value(_ item: DailyItem, day: String) throws -> Int {
    let rows = try db.run(
      "SELECT value FROM daily_strip WHERE date_key = ? AND item = ?", [.text(day), .text(item.rawValue)])
    return Int(rows.first?["value"]?.intValue ?? 0)
  }

  public func set(_ item: DailyItem, day: String, value: Int) throws {
    _ = try db.run(
      """
      INSERT INTO daily_strip (date_key, item, value) VALUES (?, ?, ?)
      ON CONFLICT(date_key, item) DO UPDATE SET value = excluded.value
      """, [.text(day), .text(item.rawValue), .int(Int64(max(0, value)))])
  }

  /// The days the item was set above 0, any age.
  public func days(_ item: DailyItem) throws -> Set<String> {
    let rows = try db.run(
      "SELECT date_key FROM daily_strip WHERE item = ? AND value > 0", [.text(item.rawValue)])
    return Set(rows.compactMap { $0["date_key"]?.textValue })
  }

  // MARK: Gym days

  /// Health's names for a gym session (`Health.workoutActivityName`).
  public static let strengthWorkouts: Set<String> = ["Strength Training", "Functional Strength"]

  /// Every day that counts as a gym day: tapped, a finished Gym Timer workout, or a strength workout in Health.
  public static func gymDays(
    tapped: Set<String>, timer: [ActivityEntry], workoutsByDay: [String: [WorkoutEntry]]
  ) -> Set<String> {
    var days = tapped
    days.formUnion(timer.filter { $0.kind == .gymTimer }.map(\.dateKey))
    for (day, workouts) in workoutsByDay where workouts.contains(where: { strengthWorkouts.contains($0.activityType) }) {
      days.insert(day)
    }
    return days
  }

  // MARK: Meditation (#257)

  /// Where today's meditation came from without a tap: "breathing" (a Box breathing session reached Done today),
  /// "health" (the last grab, made today, had mindful minutes), or nil.
  public static func meditationSource(
    today: String, activity: [ActivityEntry], healthMinutes: Double?, healthDay: String?
  ) -> String? {
    if activity.contains(where: { $0.kind == .breathing && $0.dateKey == today }) { return "breathing" }
    if healthDay == today, let minutes = healthMinutes, minutes > 0 { return "health" }
    return nil
  }

  /// Days from the newest gym day on or before `today` to today: 0 when today counts, nil with none ever.
  public static func daysSince(_ days: Set<String>, today: String, calendar: Calendar = .current) -> Int? {
    guard let last = days.filter({ $0 <= today }).max(), let from = date(last, calendar), let to = date(today, calendar)
    else { return nil }
    return calendar.dateComponents([.day], from: from, to: to).day
  }

  private static func date(_ key: String, _ calendar: Calendar) -> Date? {
    let p = key.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))
  }
}
