//  The trail and the known places in the shared SQLite file (stories 040, 041, 045, 052, 055). The tables are the
//  React Native app's, unchanged, so the cutover opens its file in place: `locations` (timestamp: UTC ms, stored
//  as REAL by the old app because iOS reports fractions of a millisecond) and `known_places`. The tracking switch
//  and the retention are `settings` rows `tracking_enabled` ("true" / "false") and `retention_days` ("30").

import Foundation

public struct ImportResult: Equatable, Sendable {
  public var pointsAdded: Int
  public var pointsAlreadyHere: Int
  public var placesAdded: Int
  public var placesAlreadyHere: Int
}

public enum ImportError: Error, CustomStringConvertible, Equatable {
  case notADatabase(String)
  case notContextGrabber
  public var description: String {
    switch self {
    case .notADatabase(let m): return "This file is not a database (\(m))."
    case .notContextGrabber: return "This database has no locations table, so it is not a Context Grabber export."
    }
  }
}

public struct LocationStore {
  public static let trackingKey = "tracking_enabled"
  public static let retentionKey = "retention_days"
  public static let defaultRetentionDays = 30

  private let db: SQLiteDatabase

  public init(db: SQLiteDatabase) throws {
    self.db = db
    try db.execute(
      """
      CREATE TABLE IF NOT EXISTS locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        timestamp INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp);
      CREATE TABLE IF NOT EXISTS known_places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius_meters REAL NOT NULL DEFAULT 100
      );
      CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      INSERT OR IGNORE INTO settings (key, value) VALUES ('tracking_enabled', 'false');
      INSERT OR IGNORE INTO settings (key, value) VALUES ('retention_days', '30');
      """)
  }

  // MARK: - the trail

  /// Adds points in one transaction.
  public func insert(_ points: [LocationPoint]) throws {
    guard !points.isEmpty else { return }
    try db.execute("BEGIN")
    do {
      for p in points {
        try db.run(
          "INSERT INTO locations (latitude, longitude, accuracy, timestamp) VALUES (?, ?, ?, ?)",
          [.double(p.latitude), .double(p.longitude), p.accuracy.map { .double($0) } ?? .null, .double(p.timestamp)])
      }
      try db.execute("COMMIT")
    } catch {
      try? db.execute("ROLLBACK")
      throw error
    }
  }

  /// Points in [since, until], oldest first.
  public func points(since: Double = -.infinity, until: Double = .infinity) throws -> [LocationPoint] {
    try db.run(
      "SELECT latitude, longitude, accuracy, timestamp FROM locations WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC, id ASC",
      [.double(since.isFinite ? since : -1e300), .double(until.isFinite ? until : 1e300)]
    ).compactMap { row in
      guard let lat = row["latitude"]?.doubleValue, let lng = row["longitude"]?.doubleValue,
        let t = row["timestamp"]?.doubleValue
      else { return nil }
      return LocationPoint(latitude: lat, longitude: lng, accuracy: row["accuracy"]?.doubleValue, timestamp: t)
    }
  }

  public func count() throws -> Int {
    Int(try db.run("SELECT COUNT(*) AS n FROM locations").first?["n"]?.intValue ?? 0)
  }

  /// Deletes points older than the retention as of `now`; returns how many went.
  @discardableResult
  public func prune(retentionDays: Int, now: Double) throws -> Int {
    let before = try count()
    try db.run("DELETE FROM locations WHERE timestamp < ?", [.double(Geo.pruneThreshold(retentionDays: retentionDays, now: now))])
    return before - (try count())
  }

  // MARK: - settings

  public func trackingEnabled() throws -> Bool {
    try db.run("SELECT value FROM settings WHERE key = ?", [.text(Self.trackingKey)]).first?["value"]?.textValue == "true"
  }

  public func setTrackingEnabled(_ on: Bool) throws {
    try db.run("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [.text(Self.trackingKey), .text(on ? "true" : "false")])
  }

  /// The retention in days; a missing or unreadable value is 30, as in the old app.
  public func retentionDays() throws -> Int {
    let text = try db.run("SELECT value FROM settings WHERE key = ?", [.text(Self.retentionKey)]).first?["value"]?.textValue
    return text.flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil } ?? Self.defaultRetentionDays
  }

  public func setRetentionDays(_ days: Int) throws {
    try db.run("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [.text(Self.retentionKey), .text(String(days))])
  }

  // MARK: - known places

  /// By name, as the old app lists them.
  public func knownPlaces() throws -> [KnownPlace] {
    try db.run("SELECT id, name, latitude, longitude, radius_meters FROM known_places ORDER BY name ASC").compactMap { row in
      guard let id = row["id"]?.intValue, let name = row["name"]?.textValue, let lat = row["latitude"]?.doubleValue,
        let lng = row["longitude"]?.doubleValue, let r = row["radius_meters"]?.doubleValue
      else { return nil }
      return KnownPlace(id: id, name: name, latitude: lat, longitude: lng, radiusMeters: r)
    }
  }

  @discardableResult
  public func addKnownPlace(name: String, latitude: Double, longitude: Double, radiusMeters: Double) throws -> Int64 {
    try db.run(
      "INSERT INTO known_places (name, latitude, longitude, radius_meters) VALUES (?, ?, ?, ?)",
      [.text(name), .double(latitude), .double(longitude), .double(radiusMeters)])
    return try db.run("SELECT last_insert_rowid() AS id").first?["id"]?.intValue ?? 0
  }

  public func updateKnownPlace(id: Int64, circle: PlaceCircle) throws {
    try db.run(
      "UPDATE known_places SET latitude = ?, longitude = ?, radius_meters = ? WHERE id = ?",
      [.double(circle.latitude), .double(circle.longitude), .double(circle.radiusMeters), .int(id)])
  }

  public func deleteKnownPlace(id: Int64) throws {
    try db.run("DELETE FROM known_places WHERE id = ?", [.int(id)])
  }

  // MARK: - import and export

  /// Copies another Context Grabber database's points and known places in. A point already here (same timestamp,
  /// latitude and longitude) is skipped, and so is a place whose name is taken, so importing twice adds nothing.
  /// `shiftMs` moves every imported timestamp (the simulator hook uses it to make an old fixture recent).
  public func importDatabase(at path: String, shiftMs: Double = 0) throws -> ImportResult {
    do {
      try db.run("ATTACH DATABASE ? AS src", [.text(path)])
    } catch let e as SQLiteError {
      throw ImportError.notADatabase(e.message)
    }
    defer { try? db.execute("DETACH DATABASE src") }
    let tables: Set<String>
    do {
      tables = Set(try db.run("SELECT name FROM src.sqlite_master WHERE type = 'table'").compactMap { $0["name"]?.textValue })
    } catch let e as SQLiteError {
      throw ImportError.notADatabase(e.message)
    }
    guard tables.contains("locations") else { throw ImportError.notContextGrabber }

    try db.execute("BEGIN")
    do {
      let offered = Int(try db.run("SELECT COUNT(*) AS n FROM src.locations").first?["n"]?.intValue ?? 0)
      let before = try count()
      try db.run(
        """
        INSERT INTO locations (latitude, longitude, accuracy, timestamp)
        SELECT s.latitude, s.longitude, s.accuracy, s.timestamp + ? FROM src.locations s
         WHERE NOT EXISTS (SELECT 1 FROM main.locations m
                            WHERE m.timestamp = s.timestamp + ? AND m.latitude = s.latitude AND m.longitude = s.longitude)
         ORDER BY s.timestamp
        """, [.double(shiftMs), .double(shiftMs)])
      let added = try count() - before
      var placesAdded = 0
      var placesOffered = 0
      if tables.contains("known_places") {
        placesOffered = Int(try db.run("SELECT COUNT(*) AS n FROM src.known_places").first?["n"]?.intValue ?? 0)
        let placesBefore = Int(try db.run("SELECT COUNT(*) AS n FROM main.known_places").first?["n"]?.intValue ?? 0)
        try db.run(
          """
          INSERT INTO known_places (name, latitude, longitude, radius_meters)
          SELECT s.name, s.latitude, s.longitude, s.radius_meters FROM src.known_places s
           WHERE s.id = (SELECT MIN(d.id) FROM src.known_places d WHERE d.name = s.name)
             AND NOT EXISTS (SELECT 1 FROM main.known_places m WHERE m.name = s.name)
           ORDER BY s.id
          """)
        placesAdded = Int(try db.run("SELECT COUNT(*) AS n FROM main.known_places").first?["n"]?.intValue ?? 0) - placesBefore
      }
      try db.execute("COMMIT")
      return ImportResult(
        pointsAdded: added, pointsAlreadyHere: offered - added, placesAdded: placesAdded,
        placesAlreadyHere: placesOffered - placesAdded)
    } catch {
      try? db.execute("ROLLBACK")
      throw error
    }
  }

  /// A consistent copy of the whole database at `path` (which must not exist), for the share sheet.
  public func exportSnapshot(to path: String) throws {
    try db.run("VACUUM INTO ?", [.text(path)])
  }
}
