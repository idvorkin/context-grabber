//  The health cache (story 013): a past day is kept once it has settled, today is always asked again. The same
//  three tables the React Native app keeps in the same file (health_raw_cache, health_computed_cache,
//  health_cache_meta with cache_version 2), rows written in the same JSON, so the cutover reads them in place.
//  Port of lib/healthCache.ts, plus the settle rule (a day cached too soon after it ended is asked again).

import Foundation

/// Safe from any task: a grab reads and writes the week's series concurrently, one statement at a time here.
public final class HealthCache: @unchecked Sendable {
  /// Changing it empties both caches at the next open.
  public static let version = "2"
  private let db: SQLiteDatabase
  private let lock = NSLock()

  public init(db: SQLiteDatabase) throws {
    self.db = db
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS health_raw_cache (
        metric TEXT NOT NULL,
        date_key TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        PRIMARY KEY (metric, date_key)
      );
      CREATE TABLE IF NOT EXISTS health_computed_cache (
        metric TEXT NOT NULL,
        date_key TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        PRIMARY KEY (metric, date_key)
      );
      CREATE TABLE IF NOT EXISTS health_cache_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      INSERT OR IGNORE INTO health_cache_meta (key, value) VALUES ('cache_version', '\(Self.version)');
      """)
    let row = try db.run("SELECT value FROM health_cache_meta WHERE key = 'cache_version'").first
    if row?["value"]?.textValue != Self.version {
      try db.execute(
        """
        DELETE FROM health_raw_cache;
        DELETE FROM health_computed_cache;
        UPDATE health_cache_meta SET value = '\(Self.version)' WHERE key = 'cache_version';
        """)
    }
  }

  public func putComputed(_ metric: MetricKey, _ dateKey: String, _ data: JSValue, at now: Double = jsMillis(Date()))
    throws
  {
    lock.lock()
    defer { lock.unlock() }
    try db.run(
      "INSERT OR REPLACE INTO health_computed_cache (metric, date_key, data, cached_at) VALUES (?, ?, ?, ?)",
      [.text(metric.rawValue), .text(dateKey), .text(data.stringify()), .int(Int64(now))])
  }

  public func putRaw(_ metric: MetricKey, _ dateKey: String, _ data: JSValue, at now: Double = jsMillis(Date())) throws
  {
    lock.lock()
    defer { lock.unlock() }
    try db.run(
      "INSERT OR REPLACE INTO health_raw_cache (metric, date_key, data, cached_at) VALUES (?, ?, ?, ?)",
      [.text(metric.rawValue), .text(dateKey), .text(data.stringify()), .int(Int64(now))])
  }

  public func computed(_ metric: MetricKey, _ dateKeys: [String]) throws -> [String: JSValue] {
    try entries("health_computed_cache", metric, dateKeys).mapValues(\.value)
  }

  /// The computed days with when each was written, for `partition`.
  public func computedEntries(_ metric: MetricKey, _ dateKeys: [String]) throws -> [String: CachedDay] {
    try entries("health_computed_cache", metric, dateKeys)
  }

  public func raw(_ metric: MetricKey, _ dateKeys: [String]) throws -> [String: JSValue] {
    try entries("health_raw_cache", metric, dateKeys).mapValues(\.value)
  }

  private func entries(_ table: String, _ metric: MetricKey, _ dateKeys: [String]) throws -> [String: CachedDay] {
    guard !dateKeys.isEmpty else { return [:] }
    lock.lock()
    defer { lock.unlock() }
    let marks = dateKeys.map { _ in "?" }.joined(separator: ",")
    let rows = try db.run(
      "SELECT date_key, data, cached_at FROM \(table) WHERE metric = ? AND date_key IN (\(marks))",
      [.text(metric.rawValue)] + dateKeys.map { .text($0) })
    var out: [String: CachedDay] = [:]
    for row in rows {
      if let key = row["date_key"]?.textValue, let text = row["data"]?.textValue, let v = JSValue.parse(text) {
        out[key] = CachedDay(value: v, cachedAt: row["cached_at"]?.doubleValue ?? 0)
      }
    }
    return out
  }

  /// How long after a day ends Health may still be filling it in: the Watch syncs its last hours late, so a day
  /// cached sooner than this after its end is asked again until a grab caches it later than that.
  public static let settleMs = 36.0 * 60 * 60 * 1000

  /// Whether a past day's cached row was written late enough to be final.
  public static func isSettled(_ dateKey: String, cachedAt: Double, clock: LocalClock) -> Bool {
    let end = clock.endOfDay(dateKey)
    return end.isFinite && cachedAt >= end + settleMs
  }

  /// Which days to ask Health for: today always, a past day when the cache does not have it or cached it before
  /// the day had settled. `cached` holds only the settled hits.
  public static func partition(todayKey: String, dateKeys: [String], cached: [String: CachedDay], clock: LocalClock)
    -> (cached: [String: JSValue], fetch: [String])
  {
    var hit: [String: JSValue] = [:]
    var fetch: [String] = []
    for key in dateKeys {
      if key != todayKey, let day = cached[key], isSettled(key, cachedAt: day.cachedAt, clock: clock) {
        hit[key] = day.value
      } else {
        fetch.append(key)
      }
    }
    return (hit, fetch)
  }
}

/// A cached day and when it was written (JavaScript milliseconds).
public struct CachedDay: Equatable, Sendable {
  public var value: JSValue
  public var cachedAt: Double

  public init(value: JSValue, cachedAt: Double) {
    self.value = value
    self.cachedAt = cachedAt
  }
}
