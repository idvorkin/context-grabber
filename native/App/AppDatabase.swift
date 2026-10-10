//  The app's one SQLite file, where the React Native app keeps its own: Documents/SQLite/context-grabber.db,
//  with the same tables, so the cutover opens that file in place. Used from the main actor only.

import ContextCore
import Foundation

@MainActor
final class AppDatabase {
  let settings: SettingsStore?
  let accessoryLog: AccessoryLog?
  /// What Igor finished, for Larry (story 037).
  let activityLog: ActivityLog?
  /// The daily strip's checks and counts (#236).
  let dailyStrip: DailyStrip?
  /// The trail, the known places, the tracking switch and the retention (Places).
  let locations: LocationStore?
  /// The file itself, for the database export.
  let url: URL
  /// The health cache, on its own connection to the same file: a grab reads and writes it off the main actor.
  let healthCache: HealthCache?
  private let log: SessionLog

  init(log: SessionLog) {
    self.log = log
    var settings: SettingsStore?
    var accessoryLog: AccessoryLog?
    var activityLog: ActivityLog?
    var locations: LocationStore?
    var dailyStrip: DailyStrip?
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("SQLite", isDirectory: true)
    url = dir.appendingPathComponent("context-grabber.db")
    var healthCache: HealthCache?
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let db = try SQLiteDatabase(path: url.path)
      settings = try SettingsStore(db: db)
      accessoryLog = try AccessoryLog(db: db)
      activityLog = try ActivityLog(db: db)
      locations = try LocationStore(db: db)
      dailyStrip = try DailyStrip(db: db)
      healthCache = try HealthCache(db: SQLiteDatabase(path: dir.appendingPathComponent("context-grabber.db").path))
    } catch {
      // Without it nothing is remembered; the screens still work and every write says so again.
      log.event("error", ["where": "database", "message": "\(error)"])
    }
    self.settings = settings
    self.accessoryLog = accessoryLog
    self.activityLog = activityLog
    self.locations = locations
    self.dailyStrip = dailyStrip
    self.healthCache = healthCache
  }

  /// Story 037: a finished workout or breathing session, recorded for the summary.
  func logActivity(_ kind: ActivityEntry.Kind, name: String, seconds: Int) {
    guard let activityLog else { return }
    do {
      let e = try activityLog.log(kind, name: name, seconds: seconds)
      log.event("activity_logged", ["kind": kind.rawValue, "name": name, "seconds": seconds, "date": e.dateKey])
    } catch {
      log.event("error", ["where": "activity_log", "message": "\(error)"])
    }
  }

  func setting(_ key: String) -> String? {
    do {
      return try settings?.get(key)
    } catch {
      log.event("error", ["where": "settings", "key": key, "message": "\(error)"])
      return nil
    }
  }

  func setSetting(_ key: String, _ value: String) {
    do {
      try settings?.set(key, value)
    } catch {
      log.event("error", ["where": "settings", "key": key, "message": "\(error)"])
    }
  }
}
