//  The step-4 acceptance bar: over the same fixture the native grab's exports equal, byte for byte, what the
//  React Native app's own code produces (scripts/native/make-mirror-expected.mjs wrote the expected files).

import XCTest

@testable import ContextCore

final class MirrorFixtureTests: XCTestCase {
  static let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")

  static func text(_ name: String) throws -> String {
    try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
  }

  func grab(_ fx: HealthFixture, cache: HealthCache?) async -> MirrorSnapshot {
    let clock = LocalClock(timeZone: TimeZone(identifier: fx.timeZone)!)
    let grab = MirrorGrab(source: FixtureHealthSource(fx), cache: cache, clock: clock)
    let snap = await grab.grab(now: fx.now, finished: { fx.now })
    XCTAssertEqual(grab.takeFailures(), [])
    return snap
  }

  func accessory(_ fx: HealthFixture) throws -> [AccessoryLogEntry] {
    let db = try SQLiteDatabase()
    let log = try AccessoryLog(db: db)
    for a in fx.accessory {
      try db.run(
        "INSERT INTO accessory_log (item_id, item_name, logged_at, date_key) VALUES (?, ?, ?, ?)",
        [.text(a.itemId), .text(a.itemName), .int(a.loggedAt), .text(a.dateKey)])
    }
    return try log.entries(since: jsDate(fx.now - Double(AccessoryLog.windowDays) * 24 * 3600 * 1000))
  }

  func testSummaryAndRawExportsMatchTheReactNativeAppByteForByte() async throws {
    let fx = try XCTUnwrap(HealthFixture(json: Self.text("mirror-fixture.json")))
    let clock = LocalClock(timeZone: TimeZone(identifier: fx.timeZone)!)
    let cache = try HealthCache(db: SQLiteDatabase())
    let entries = try accessory(fx)

    let cold = await grab(fx, cache: cache)
    let summary = MirrorGrab.summaryJSON(cold, accessory: entries, clock: clock)
    let raw = MirrorGrab.rawJSON(cold)
    XCTAssertEqual(summary, try Self.text("mirror-summary-expected.json"))
    XCTAssertEqual(raw, try Self.text("mirror-raw-expected.json"))

    // Past days now come from the cache: the same bytes.
    let warm = await grab(fx, cache: cache)
    XCTAssertEqual(MirrorGrab.summaryJSON(warm, accessory: entries, clock: clock), summary)
    XCTAssertEqual(MirrorGrab.rawJSON(warm), raw)
  }

  func testFixtureCoversWhatTheStoriesAsk() async throws {
    let fx = try XCTUnwrap(HealthFixture(json: Self.text("mirror-fixture.json")))
    let snap = await grab(fx, cache: nil)
    // Story 028: the workout that began last night is in today's.
    XCTAssertTrue(snap.health.workouts.contains { $0.activityType == "Yoga" })
    // Story 006: two sources, and the sheet opens on the one with stages.
    let bundle = try XCTUnwrap(snap.sleepBundle)
    XCTAssertEqual(bundle.bySource.keys.sorted().count, 2)
    XCTAssertNotEqual(Sleep.pickDefaultSource(bundle), "AutoSleep")
    // Story 027: weight in whole pounds, a day with none is null.
    let weight = snap.weeklyData.weight
    XCTAssertTrue(weight.contains { $0.value == nil })
    XCTAssertTrue(weight.compactMap(\.value).allSatisfy { $0 == $0.rounded() })
  }
}

final class HealthFixtureTests: XCTestCase {
  func testFixtureWritesBackWhatItRead() throws {
    let text = try MirrorFixtureTests.text("mirror-fixture.json")
    let fx = try XCTUnwrap(HealthFixture(json: text))
    let again = try XCTUnwrap(HealthFixture(json: fx.json.stringify()))
    XCTAssertEqual(again.json, fx.json)
    XCTAssertEqual(fx.json.stringify() + "\n", text)
  }

  func testShiftedAndSavedBy() throws {
    let fx = try XCTUnwrap(HealthFixture(json: MirrorFixtureTests.text("mirror-fixture.json")))
    let week = 7 * 86_400_000.0
    let moved = fx.shifted(by: week, clock: la).asSavedBy(source: "Grabber Native", dropping: [.exerciseTime])
    XCTAssertEqual(moved.now, fx.now + week)
    XCTAssertEqual(moved.quantities[.exerciseTime], [])
    XCTAssertEqual(Set(moved.sleep.compactMap(\.source)), ["Grabber Native"])
    XCTAssertEqual(moved.accessory.first?.dateKey, la.dateKey(Double(fx.accessory[0].loggedAt) + week))
  }
}
