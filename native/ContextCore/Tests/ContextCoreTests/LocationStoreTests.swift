//  The trail's SQL on real SQLite, in memory (or a temp file where ATTACH / VACUUM INTO need one).

import XCTest

@testable import ContextCore

final class LocationStoreTests: XCTestCase {
  let day = 86_400_000.0
  let now = 1_780_000_000_000.0

  func testInsertRangeCountAndPrune() throws {
    let store = try LocationStore(db: SQLiteDatabase())
    try store.insert((0..<40).map { LocationPoint(latitude: 47.6, longitude: -122.3, accuracy: 5, timestamp: now - Double($0) * day - 1.5) })
    XCTAssertEqual(try store.count(), 40)
    let lastWeek = try store.points(since: now - 7 * day)
    XCTAssertEqual(lastWeek.count, 7)
    XCTAssertEqual(lastWeek.map(\.timestamp), lastWeek.map(\.timestamp).sorted(), "oldest first")
    XCTAssertEqual(lastWeek.last?.timestamp, now - 1.5, "fractional milliseconds survive, as the old app stored them")
    // Story 041: retention 30 keeps 30 days; lowering to 7 removes the rest at once.
    XCTAssertEqual(try store.prune(retentionDays: 30, now: now), 10)
    XCTAssertEqual(try store.prune(retentionDays: 7, now: now), 23)
    XCTAssertEqual(try store.count(), 7)
  }

  func testSettingsAreTheOldAppsKeys() throws {
    let db = try SQLiteDatabase()
    let store = try LocationStore(db: db)
    XCTAssertFalse(try store.trackingEnabled(), "off on a fresh install")
    XCTAssertEqual(try store.retentionDays(), 30)
    try store.setTrackingEnabled(true)
    try store.setRetentionDays(7)
    let settings = try SettingsStore(db: db)
    XCTAssertEqual(try settings.get("tracking_enabled"), "true")
    XCTAssertEqual(try settings.get("retention_days"), "7")
    try settings.set("retention_days", "garbage")
    XCTAssertEqual(try store.retentionDays(), 30)
    // A value the old app wrote is kept, not reset by opening the store again.
    try settings.set("tracking_enabled", "true")
    XCTAssertTrue(try LocationStore(db: db).trackingEnabled())
  }

  func testKnownPlacesCRUD() throws {
    let store = try LocationStore(db: SQLiteDatabase())
    let gym = try store.addKnownPlace(name: "Gym", latitude: 47.6, longitude: -122.3, radiusMeters: 100)
    try store.addKnownPlace(name: "Cafe", latitude: 47.7, longitude: -122.4, radiusMeters: 50)
    XCTAssertEqual(try store.knownPlaces().map(\.name), ["Cafe", "Gym"])
    try store.updateKnownPlace(id: gym, circle: PlaceCircle(latitude: 47.61, longitude: -122.31, radiusMeters: 159))
    XCTAssertEqual(try store.knownPlaces().first { $0.id == gym }?.radiusMeters, 159)
    try store.deleteKnownPlace(id: gym)
    XCTAssertEqual(try store.knownPlaces().map(\.name), ["Cafe"])
  }

  func testImportKeepsANativePlaceWithTheSameName() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = try LocationStore(db: SQLiteDatabase(path: dir.appendingPathComponent("old.db").path))
    try source.insert([LocationPoint(latitude: 1, longitude: 2, accuracy: nil, timestamp: 1000)])
    try source.addKnownPlace(name: "Home", latitude: 1, longitude: 2, radiusMeters: 100)
    try source.addKnownPlace(name: "Gym", latitude: 3, longitude: 4, radiusMeters: 100)

    let store = try LocationStore(db: SQLiteDatabase(path: dir.appendingPathComponent("new.db").path))
    try store.addKnownPlace(name: "Home", latitude: 9, longitude: 9, radiusMeters: 300)
    let result = try store.importDatabase(at: dir.appendingPathComponent("old.db").path, shiftMs: day)
    XCTAssertEqual(result, ImportResult(pointsAdded: 1, pointsAlreadyHere: 0, placesAdded: 1, placesAlreadyHere: 1))
    XCTAssertEqual(try store.knownPlaces().first { $0.name == "Home" }?.radiusMeters, 300, "the native one wins")
    XCTAssertEqual(try store.points().first?.timestamp, 1000 + day, "the hook's shift")
    XCTAssertNil(try store.points().first?.accuracy)
  }

  func testImportRefusesOtherFiles() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = try LocationStore(db: SQLiteDatabase(path: dir.appendingPathComponent("new.db").path))
    let text = dir.appendingPathComponent("notes.db")
    try Data("hello, this is not sqlite at all, not even close to a header".utf8).write(to: text)
    XCTAssertThrowsError(try store.importDatabase(at: text.path)) { error in
      guard case ImportError.notADatabase = error else { return XCTFail("\(error)") }
    }
    let other = dir.appendingPathComponent("other.db")
    try SQLiteDatabase(path: other.path).execute("CREATE TABLE things (x INTEGER);")
    XCTAssertThrowsError(try store.importDatabase(at: other.path)) { XCTAssertEqual($0 as? ImportError, .notContextGrabber) }
    XCTAssertEqual(try store.count(), 0, "nothing changed")
    // The store is still usable: the failed attach was let go.
    try store.insert([LocationPoint(latitude: 1, longitude: 1, timestamp: 1)])
    XCTAssertEqual(try store.count(), 1)
  }

  func testExportSnapshotIsTheWholeDatabase() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = try LocationStore(db: SQLiteDatabase(path: dir.appendingPathComponent("app.db").path))
    try store.insert([LocationPoint(latitude: 1, longitude: 2, accuracy: 3, timestamp: 4)])
    try store.addKnownPlace(name: "Home", latitude: 1, longitude: 2, radiusMeters: 100)
    let out = dir.appendingPathComponent("context-grabber.db")
    try store.exportSnapshot(to: out.path)
    let copy = try LocationStore(db: SQLiteDatabase(path: out.path))
    XCTAssertEqual(try copy.count(), 1)
    XCTAssertEqual(try copy.knownPlaces().map(\.name), ["Home"])
    XCTAssertEqual(try copy.retentionDays(), 30)
  }
}
