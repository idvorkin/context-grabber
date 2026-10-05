//  The app's one SQLite file, where the React Native app keeps its own: Documents/SQLite/context-grabber.db,
//  with the same tables, so the cutover opens that file in place. Used from the main actor only.

import ContextCore
import Foundation

@MainActor
final class AppDatabase {
  let settings: SettingsStore?
  let accessoryLog: AccessoryLog?
  /// The trail, the known places, the tracking switch and the retention (Places).
  let locations: LocationStore?
  /// The file itself, for the database export.
  let url: URL
  private let log: SessionLog

  init(log: SessionLog) {
    self.log = log
    var settings: SettingsStore?
    var accessoryLog: AccessoryLog?
    var locations: LocationStore?
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("SQLite", isDirectory: true)
    url = dir.appendingPathComponent("context-grabber.db")
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let db = try SQLiteDatabase(path: url.path)
      settings = try SettingsStore(db: db)
      accessoryLog = try AccessoryLog(db: db)
      locations = try LocationStore(db: db)
    } catch {
      // Without it nothing is remembered; the screens still work and every write says so again.
      log.event("error", ["where": "database", "message": "\(error)"])
    }
    self.settings = settings
    self.accessoryLog = accessoryLog
    self.locations = locations
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
