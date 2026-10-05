//  The accessory / mobility work log (stories 112, 113): the small pieces done around a workout, so the coaching
//  export can see which mobility work happened. One row per item; one Save writes every checked item with the
//  same timestamp.
//
//  Storage conventions: `logged_at` is UTC unix milliseconds; `date_key` is the LOCAL calendar day (YYYY-MM-DD)
//  of the save. The table is the one the React Native app wrote; the schema is additive-only.

import Foundation

public struct AccessoryItem: Equatable, Sendable {
  /// Stable storage key — append-only. Renaming an id orphans historical rows.
  public let id: String
  /// Shown in the checklist and used in the export.
  public let label: String
}

public struct AccessoryLogEntry: Equatable, Sendable {
  public let id: Int64
  public let itemId: String
  public let itemName: String
  /// UTC unix milliseconds.
  public let loggedAt: Int64
  /// Local calendar day, "YYYY-MM-DD".
  public let dateKey: String
}

/// One Save: the items checked together, stamped once.
public struct AccessoryLogSession: Equatable, Sendable {
  public let loggedAt: Int64
  /// Wall-clock time of the save, "3:12pm".
  public let time: String
  /// Display names, in checklist order.
  public var items: [String]
}

/// One local day of the log, newest save first.
public struct AccessoryLogDay: Equatable, Sendable {
  public let dateKey: String
  /// "Today", "Yesterday", or "Tue Sep 8".
  public let label: String
  public var sessions: [AccessoryLogSession]
}

public struct AccessoryLog {
  /// How far back the export and the in-sheet history look.
  public static let windowDays = 7

  /// The checklist. The `id` is the persisted key and must stay stable; only the label is safe to change.
  public static let items: [AccessoryItem] = [
    AccessoryItem(id: "half_lotus", label: "Half Lotus"),
    AccessoryItem(id: "mcgill_big_3", label: "McGill Big 3"),
    AccessoryItem(id: "pigeon_stretch", label: "Pigeon Stretch"),
    AccessoryItem(id: "dead_hangs", label: "Dead Hangs"),
  ]

  private let db: SQLiteDatabase
  private let calendar: Calendar

  /// Creates the table if it is not there. `calendar` decides what "local day" means (the tests pin a zone).
  public init(db: SQLiteDatabase, calendar: Calendar = .current) throws {
    self.db = db
    self.calendar = calendar
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS accessory_log (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id   TEXT NOT NULL,
        item_name TEXT NOT NULL,
        logged_at INTEGER NOT NULL,
        date_key  TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_accessory_log_time ON accessory_log(logged_at);
      """)
  }

  /// Records the checked items as one session, in checklist order whatever order they were tapped in. Unknown
  /// ids are skipped; nothing checked writes nothing. Returns how many rows were written.
  @discardableResult
  public func log(itemIds: [String], at date: Date = Date()) throws -> Int {
    let loggedAt = Int64((date.timeIntervalSince1970 * 1000).rounded())
    let dateKey = Self.dateKey(date, calendar: calendar)
    let checked = Self.items.filter { itemIds.contains($0.id) }
    for item in checked {
      try db.run(
        "INSERT INTO accessory_log (item_id, item_name, logged_at, date_key) VALUES (?, ?, ?, ?)",
        [.text(item.id), .text(item.label), .int(loggedAt), .text(dateKey)])
    }
    return checked.count
  }

  /// Logged items, newest first; `since` limits to entries at or after that instant.
  public func entries(since: Date? = nil) throws -> [AccessoryLogEntry] {
    let sinceMs = since.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) } ?? Int64.min
    return try db.run(
      """
      SELECT id, item_id, item_name, logged_at, date_key FROM accessory_log
       WHERE logged_at >= ? ORDER BY logged_at DESC, id ASC
      """, [.int(sinceMs)]
    ).compactMap { row in
      guard let id = row["id"]?.intValue, let itemId = row["item_id"]?.textValue,
        let name = row["item_name"]?.textValue, let at = row["logged_at"]?.intValue,
        let key = row["date_key"]?.textValue
      else { return nil }
      return AccessoryLogEntry(id: id, itemId: itemId, itemName: name, loggedAt: at, dateKey: key)
    }
  }

  /// The last `windowDays` as the sheet shows them.
  public func recentDays(now: Date = Date()) throws -> [AccessoryLogDay] {
    let since = now.addingTimeInterval(-Double(Self.windowDays) * 24 * 3600)
    return Self.group(try entries(since: since), now: now, calendar: calendar)
  }

  // MARK: - the log as the user reads it

  /// Local calendar day (YYYY-MM-DD) for an instant.
  public static func dateKey(_ date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  private static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  /// "Today", "Yesterday", or the weekday and date ("Tue Sep 8") for a local date key, as of `now`.
  public static func dayLabel(_ dateKey: String, now: Date = Date(), calendar: Calendar = .current) -> String {
    if dateKey == self.dateKey(now, calendar: calendar) { return "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
      dateKey == self.dateKey(yesterday, calendar: calendar)
    {
      return "Yesterday"
    }
    let parts = dateKey.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
      let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    else { return dateKey }
    return "\(weekdays[calendar.component(.weekday, from: day) - 1]) \(months[parts[1] - 1]) \(parts[2])"
  }

  /// "3:12pm", "9am": the wall clock the way the summary writes it.
  public static func clockTime(_ date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    let hour = c.hour ?? 0
    let minute = c.minute ?? 0
    let period = hour >= 12 ? "pm" : "am"
    let display = hour % 12 == 0 ? 12 : hour % 12
    return minute == 0 ? "\(display)\(period)" : String(format: "%d:%02d%@", display, minute, period)
  }

  /// By local day, newest first; within a day by save (entries sharing a timestamp are one session), newest
  /// first; the items of a session in the order they were written.
  public static func group(
    _ entries: [AccessoryLogEntry], now: Date = Date(), calendar: Calendar = .current
  ) -> [AccessoryLogDay] {
    let sorted = entries.sorted { ($0.loggedAt, $1.id) > ($1.loggedAt, $0.id) }
    var days: [AccessoryLogDay] = []
    for e in sorted {
      if days.last?.dateKey != e.dateKey {
        days.append(
          AccessoryLogDay(dateKey: e.dateKey, label: dayLabel(e.dateKey, now: now, calendar: calendar), sessions: []))
      }
      if days[days.count - 1].sessions.last?.loggedAt != e.loggedAt {
        let at = Date(timeIntervalSince1970: Double(e.loggedAt) / 1000)
        days[days.count - 1].sessions.append(
          AccessoryLogSession(loggedAt: e.loggedAt, time: clockTime(at, calendar: calendar), items: []))
      }
      days[days.count - 1].sessions[days[days.count - 1].sessions.count - 1].items.append(e.itemName)
    }
    return days
  }
}
