//  Story 136: the live tile's reading, as the app writes it and the widget reads it back.

import ContextCore
import XCTest

final class UsageSnapshotTests: XCTestCase {
  let served = """
    {"ok":true,"present":true,"weekly_pct":69,"fable_pct":87,"model_pct":87,"model_name":"Fable",
     "resets":"2026-10-05T21:59:59-07:00","resets_in":"14H","pacing":"On track","age":"2h","stale":false,
     "pending":false,"el_pct":16,"el_minutes_left":230.0,"el_resets_in":"23D10H","el_age":"56m","el_stale":false}
    """
  /// The reset above, as an instant.
  let reset = ISO8601DateFormatter().date(from: "2026-10-06T04:59:59Z")!

  func testWhatTheAppWritesTheWidgetReadsBack() throws {
    let usage = try CockpitUsage.decode(Data(served.utf8))
    let snapshot = UsageSnapshot(usage: usage, fetchedAt: Date(timeIntervalSince1970: 1_790_000_000))
    let back = try XCTUnwrap(UsageSnapshot.decode(snapshot.encoded()))
    XCTAssertEqual(back, snapshot)
    let now = reset.addingTimeInterval(-14 * 3600)
    XCTAssertEqual(back.strip(now: now), snapshot.strip(now: now))
    XCTAssertEqual(back.strip(now: now)?.bars.map(\.text), ["31%", "13%", "3.8h"])
  }

  func testNothingWrittenOrUnreadableIsThePlaceholder() {
    XCTAssertNil(UsageSnapshot.decode(nil))
    XCTAssertNil(UsageSnapshot.decode(Data()))
    XCTAssertNil(UsageSnapshot.decode(Data("{\"usage\":3}".utf8)))
  }

  func testAReadingWithNothingToDrawHasNoStrip() {
    let snapshot = UsageSnapshot(usage: CockpitUsage(present: false), fetchedAt: Date())
    XCTAssertNil(snapshot.strip(now: Date()))
  }

  func testTheCountdownAndTheNudgeMoveWithTheClockNotTheReading() throws {
    // Read two days before the reset: nothing to spend yet.
    let usage = try CockpitUsage.decode(Data(served.utf8))
    let snapshot = UsageSnapshot(usage: usage, fetchedAt: reset.addingTimeInterval(-48 * 3600))
    let early = try XCTUnwrap(snapshot.strip(now: snapshot.fetchedAt))
    XCTAssertNil(early.spendNote)
    XCTAssertEqual(early.claudeNote, "resets in 2D · On track")
    // Thirteen hours before it, with the same reading: 31% to spend, and the countdown says 13H.
    let late = try XCTUnwrap(snapshot.strip(now: reset.addingTimeInterval(-13 * 3600 - 60)))
    XCTAssertEqual(late.spendNote, "31% to spend")
    XCTAssertEqual(late.claudeNote, "resets in 13H · On track")
    // After the reset the stale countdown is dropped rather than shown as past.
    let after = try XCTUnwrap(snapshot.strip(now: reset.addingTimeInterval(60)))
    XCTAssertEqual(after.claudeNote, "On track")
    XCTAssertNil(after.spendNote)
  }

  func testAgeAndWhenItIsOld() {
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    let s = UsageSnapshot(usage: CockpitUsage(), fetchedAt: at)
    XCTAssertEqual(s.age(now: at.addingTimeInterval(20)), "just now")
    XCTAssertEqual(s.age(now: at.addingTimeInterval(12 * 60)), "12m ago")
    XCTAssertEqual(s.age(now: at.addingTimeInterval(2 * 3600 + 5)), "2h ago")
    XCTAssertEqual(s.age(now: at.addingTimeInterval(3 * 86400)), "3d ago")
    XCTAssertFalse(s.isOld(now: at.addingTimeInterval(59 * 60)))
    XCTAssertTrue(s.isOld(now: at.addingTimeInterval(3600)))
  }

  func testCountdownInTheCockpitsStyle() {
    XCTAssertEqual(UsageSnapshot.countdown(seconds: 14 * 3600 + 120), "14H")
    XCTAssertEqual(UsageSnapshot.countdown(seconds: 23 * 86400 + 10 * 3600 + 30), "23D10H")
    XCTAssertEqual(UsageSnapshot.countdown(seconds: 2 * 86400 + 59), "2D")
    XCTAssertEqual(UsageSnapshot.countdown(seconds: 45 * 60), "45M")
    XCTAssertEqual(UsageSnapshot.countdown(seconds: 10), "1M")
  }
}
