//  What Igor finished (story 037, #139): every Gym Timer workout run to done and every breathing session that
//  reached Done, so the summary can tell Larry what was actually done. One row per finished activity.
//
//  Storage conventions as the accessory log's: `finished_at` UTC unix milliseconds, `date_key` the LOCAL day.

import Foundation

public struct ActivityEntry: Equatable, Sendable {
  public enum Kind: String, Sendable { case gymTimer = "gym_timer", breathing }

  public let id: Int64
  public let kind: Kind
  /// As Larry reads it: "30 SEC · 6 rounds", "Box breathing · 8 s · 9 cycles".
  public let name: String
  public let seconds: Int
  /// UTC unix milliseconds.
  public let finishedAt: Int64
  /// Local calendar day, "YYYY-MM-DD".
  public let dateKey: String

  public var exportJSON: JSValue {
    .object([
      ("kind", .string(kind.rawValue)), ("name", .string(name)), ("minutes", .number(round1(Double(seconds) / 60))),
      ("timestamp", .string(isoString(Double(finishedAt)))), ("date", .string(dateKey)),
    ])
  }
}

public struct ActivityLog {
  /// How far back the export looks, as the accessory log's.
  public static let windowDays = 7

  private let db: SQLiteDatabase
  private let calendar: Calendar

  public init(db: SQLiteDatabase, calendar: Calendar = .current) throws {
    self.db = db
    self.calendar = calendar
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS activity_log (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        kind        TEXT NOT NULL,
        name        TEXT NOT NULL,
        seconds     INTEGER NOT NULL,
        finished_at INTEGER NOT NULL,
        date_key    TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_activity_log_time ON activity_log(finished_at);
      """)
  }

  @discardableResult
  public func log(_ kind: ActivityEntry.Kind, name: String, seconds: Int, at date: Date = Date()) throws -> ActivityEntry {
    let finishedAt = Int64((date.timeIntervalSince1970 * 1000).rounded())
    let dateKey = AccessoryLog.dateKey(date, calendar: calendar)
    let rows = try db.run(
      "INSERT INTO activity_log (kind, name, seconds, finished_at, date_key) VALUES (?, ?, ?, ?, ?) RETURNING id",
      [.text(kind.rawValue), .text(name), .int(Int64(seconds)), .int(finishedAt), .text(dateKey)])
    return ActivityEntry(
      id: rows.first?["id"]?.intValue ?? 0, kind: kind, name: name, seconds: seconds, finishedAt: finishedAt,
      dateKey: dateKey)
  }

  /// Newest first.
  public func entries(since date: Date) throws -> [ActivityEntry] {
    let since = Int64((date.timeIntervalSince1970 * 1000).rounded())
    return try db.run(
      """
      SELECT id, kind, name, seconds, finished_at, date_key FROM activity_log
       WHERE finished_at >= ? ORDER BY finished_at DESC, id DESC
      """, [.int(since)]
    ).compactMap { row in
      guard let id = row["id"]?.intValue, let kind = row["kind"]?.textValue.flatMap(ActivityEntry.Kind.init(rawValue:)),
        let name = row["name"]?.textValue, let seconds = row["seconds"]?.intValue,
        let at = row["finished_at"]?.intValue, let key = row["date_key"]?.textValue
      else { return nil }
      return ActivityEntry(id: id, kind: kind, name: name, seconds: Int(seconds), finishedAt: at, dateKey: key)
    }
  }

  /// "30 SEC · 6 rounds"; a custom shape names its work and rest: "CUSTOM 0:45 / 0:15 · 8 rounds".
  public static func gymName(label: String, profile: TimerProfile, custom: Bool) -> String {
    func mmss(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    let head = custom ? "CUSTOM \(mmss(profile.workTime)) / \(mmss(profile.restTime))" : label
    return "\(head) · \(profile.rounds) round\(profile.rounds == 1 ? "" : "s")"
  }

  /// The workout's own length: the count-in, every round's work, and the rests between rounds.
  public static func gymSeconds(_ p: TimerProfile) -> Int {
    p.prepTime + p.rounds * p.workTime + max(0, p.rounds - 1) * p.restTime
  }

  public static func breathName(_ plan: BreathPlan) -> String {
    "Box breathing · \(plan.breathSeconds) s · \(plan.cycles) cycle\(plan.cycles == 1 ? "" : "s")"
  }
}
