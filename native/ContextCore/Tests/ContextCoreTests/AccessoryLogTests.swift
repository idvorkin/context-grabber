import XCTest

@testable import ContextCore

final class AccessoryLogTests: XCTestCase {
  /// Seattle, so "local day" is not UTC's.
  private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
  }()

  private func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
  }

  private func makeLog() throws -> AccessoryLog {
    try AccessoryLog(db: SQLiteDatabase(), calendar: calendar)
  }

  func testTheChecklistIsTheFourItemsWithStableIds() {
    XCTAssertEqual(AccessoryLog.items.map(\.id), ["half_lotus", "mcgill_big_3", "pigeon_stretch", "dead_hangs"])
    XCTAssertEqual(AccessoryLog.items.map(\.label), ["Half Lotus", "McGill Big 3", "Pigeon Stretch", "Dead Hangs"])
  }

  func testTheDateKeyIsTheLocalDayZeroPadded() {
    XCTAssertEqual(AccessoryLog.dateKey(local(2026, 9, 8, 23, 30), calendar: calendar), "2026-09-08")
    XCTAssertEqual(AccessoryLog.dateKey(local(2026, 1, 5, 0, 5), calendar: calendar), "2026-01-05")
  }

  func testSavesOnlyTheCheckedItemsWithOneTimestampInChecklistOrder() throws {
    let log = try makeLog()
    let at = local(2026, 9, 8, 15, 12)
    XCTAssertEqual(try log.log(itemIds: ["dead_hangs", "half_lotus"], at: at), 2)
    let entries = try log.entries()
    XCTAssertEqual(entries.map(\.itemName), ["Half Lotus", "Dead Hangs"])
    XCTAssertEqual(Set(entries.map(\.loggedAt)), [Int64(at.timeIntervalSince1970 * 1000)])
    XCTAssertEqual(Set(entries.map(\.dateKey)), ["2026-09-08"])
  }

  func testSkipsUnknownIdsAndAnEmptyChecklistWritesNothing() throws {
    let log = try makeLog()
    XCTAssertEqual(try log.log(itemIds: ["bogus", "pigeon_stretch"]), 1)
    XCTAssertEqual(try log.log(itemIds: []), 0)
    XCTAssertEqual(try log.entries().map(\.itemId), ["pigeon_stretch"])
  }

  func testReadsNewestFirstAndSinceCutsTheOldOnes() throws {
    let log = try makeLog()
    try log.log(itemIds: ["pigeon_stretch"], at: local(2026, 8, 31))
    try log.log(itemIds: ["half_lotus"], at: local(2026, 9, 7))
    try log.log(itemIds: ["dead_hangs"], at: local(2026, 9, 8))
    XCTAssertEqual(try log.entries().map(\.itemId), ["dead_hangs", "half_lotus", "pigeon_stretch"])
    XCTAssertEqual(try log.entries(since: local(2026, 9, 2)).map(\.itemId), ["dead_hangs", "half_lotus"])
  }

  func testDayLabelsTodayYesterdayThenWeekdayAndDate() {
    let now = local(2026, 9, 10, 9)
    XCTAssertEqual(AccessoryLog.dayLabel("2026-09-10", now: now, calendar: calendar), "Today")
    XCTAssertEqual(AccessoryLog.dayLabel("2026-09-09", now: now, calendar: calendar), "Yesterday")
    XCTAssertEqual(AccessoryLog.dayLabel("2026-09-08", now: now, calendar: calendar), "Tue Sep 8")
    XCTAssertEqual(AccessoryLog.dayLabel("2026-08-31", now: local(2026, 9, 1, 9), calendar: calendar), "Yesterday")
  }

  func testClockTimeReadsLikeTheSummary() {
    XCTAssertEqual(AccessoryLog.clockTime(local(2026, 9, 8, 15, 12), calendar: calendar), "3:12pm")
    XCTAssertEqual(AccessoryLog.clockTime(local(2026, 9, 8, 9, 0), calendar: calendar), "9am")
    XCTAssertEqual(AccessoryLog.clockTime(local(2026, 9, 8, 0, 5), calendar: calendar), "12:05am")
    XCTAssertEqual(AccessoryLog.clockTime(local(2026, 9, 8, 12, 0), calendar: calendar), "12pm")
  }

  func testWhatWasSavedIsWhatTheSheetShowsAndTheEightDayOldEntryIsNot() throws {
    let log = try makeLog()
    let now = local(2026, 9, 10, 18)
    try log.log(itemIds: ["pigeon_stretch"], at: local(2026, 9, 2, 10))  // eight days ago
    try log.log(itemIds: ["mcgill_big_3"], at: local(2026, 9, 9, 7, 30))
    try log.log(itemIds: ["half_lotus", "dead_hangs"], at: local(2026, 9, 10, 15, 12))
    try log.log(itemIds: ["pigeon_stretch"], at: local(2026, 9, 10, 17))
    let days = try log.recentDays(now: now)
    XCTAssertEqual(days.map(\.label), ["Today", "Yesterday"])
    XCTAssertEqual(days[0].sessions.map(\.time), ["5pm", "3:12pm"])
    XCTAssertEqual(days[0].sessions[1].items, ["Half Lotus", "Dead Hangs"])
    XCTAssertEqual(days[1].sessions.map(\.items), [["McGill Big 3"]])
  }

  func testNothingInTheWindowIsNoDays() throws {
    XCTAssertEqual(try makeLog().recentDays(), [])
    XCTAssertEqual(AccessoryLog.group([]), [])
  }
}

final class SQLiteStoreTests: XCTestCase {
  func testSettingsRoundTripAndReplace() throws {
    let settings = try SettingsStore(db: SQLiteDatabase())
    XCTAssertNil(try settings.get("gym_sets_count"))
    try settings.set("gym_sets_count", "7")
    try settings.set("gym_sets_count", "8")
    XCTAssertEqual(try settings.get("gym_sets_count"), "8")
  }

  func testABadStatementThrowsWithTheSql() throws {
    let db = try SQLiteDatabase()
    XCTAssertThrowsError(try db.run("SELECT * FROM nowhere")) { error in
      XCTAssertTrue("\(error)".contains("nowhere"))
    }
  }

  func testValuesKeepTheirTypes() throws {
    let db = try SQLiteDatabase()
    try db.execute("CREATE TABLE t (i INTEGER, d REAL, s TEXT, n TEXT);")
    try db.run("INSERT INTO t VALUES (?, ?, ?, ?)", [.int(1_791_160_823_000), .double(1.5), .text("héllo"), .null])
    let row = try XCTUnwrap(db.run("SELECT * FROM t").first)
    XCTAssertEqual(row["i"], .int(1_791_160_823_000))
    XCTAssertEqual(row["d"], .double(1.5))
    XCTAssertEqual(row["s"], .text("héllo"))
    XCTAssertEqual(row["n"], .null)
  }
}
