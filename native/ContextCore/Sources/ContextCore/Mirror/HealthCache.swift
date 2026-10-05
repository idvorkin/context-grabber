//  The health cache (story 013): past days are kept, today is always asked again. The same three tables the React
//  Native app keeps in the same file (health_raw_cache, health_computed_cache, health_cache_meta with
//  cache_version 2), rows written in the same JSON, so the cutover reads them in place. Port of lib/healthCache.ts.

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

  public func putRaw(_ metric: MetricKey, _ dateKey: String, _ data: JSValue, at now: Double = jsMillis(Date())) throws {
    lock.lock()
    defer { lock.unlock() }
    try db.run(
      "INSERT OR REPLACE INTO health_raw_cache (metric, date_key, data, cached_at) VALUES (?, ?, ?, ?)",
      [.text(metric.rawValue), .text(dateKey), .text(data.stringify()), .int(Int64(now))])
  }

  public func computed(_ metric: MetricKey, _ dateKeys: [String]) throws -> [String: JSValue] {
    try batch("health_computed_cache", metric, dateKeys)
  }

  public func raw(_ metric: MetricKey, _ dateKeys: [String]) throws -> [String: JSValue] {
    try batch("health_raw_cache", metric, dateKeys)
  }

  private func batch(_ table: String, _ metric: MetricKey, _ dateKeys: [String]) throws -> [String: JSValue] {
    guard !dateKeys.isEmpty else { return [:] }
    lock.lock()
    defer { lock.unlock() }
    let marks = dateKeys.map { _ in "?" }.joined(separator: ",")
    let rows = try db.run(
      "SELECT date_key, data FROM \(table) WHERE metric = ? AND date_key IN (\(marks))",
      [.text(metric.rawValue)] + dateKeys.map { .text($0) })
    var out: [String: JSValue] = [:]
    for row in rows {
      if let key = row["date_key"]?.textValue, let text = row["data"]?.textValue, let v = JSValue.parse(text) {
        out[key] = v
      }
    }
    return out
  }

  /// Which days to ask Health for: today always, a past day only when the cache does not have it.
  public static func partition(todayKey: String, dateKeys: [String], cached: [String: JSValue]) -> (
    cached: [String: JSValue], fetch: [String]
  ) {
    var hit: [String: JSValue] = [:]
    var fetch: [String] = []
    for key in dateKeys {
      if key == todayKey {
        fetch.append(key)
      } else if let v = cached[key] {
        hit[key] = v
      } else {
        fetch.append(key)
      }
    }
    return (hit, fetch)
  }
}
