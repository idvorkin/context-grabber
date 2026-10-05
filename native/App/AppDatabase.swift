//  The app's one SQLite file, where the React Native app keeps its own: Documents/SQLite/context-grabber.db,
//  with the same tables, so the cutover opens that file in place. Used from the main actor only.

import ContextCore
import Foundation

@MainActor
final class AppDatabase {
  let settings: SettingsStore?
  let accessoryLog: AccessoryLog?
  /// The health cache, on its own connection to the same file: a grab reads and writes it off the main actor.
  let healthCache: HealthCache?
  private let log: SessionLog

  init(log: SessionLog) {
    self.log = log
    var settings: SettingsStore?
    var accessoryLog: AccessoryLog?
    var healthCache: HealthCache?
    do {
      let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SQLite", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let db = try SQLiteDatabase(path: dir.appendingPathComponent("context-grabber.db").path)
      settings = try SettingsStore(db: db)
      accessoryLog = try AccessoryLog(db: db)
      healthCache = try HealthCache(db: SQLiteDatabase(path: dir.appendingPathComponent("context-grabber.db").path))
    } catch {
      // Without it nothing is remembered; the screens still work and every write says so again.
      log.event("error", ["where": "database", "message": "\(error)"])
    }
    self.settings = settings
    self.accessoryLog = accessoryLog
    self.healthCache = healthCache
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
