//  Story 203: the usage strip from the Cockpit's GET /usage.

import ContextCore
import XCTest

final class CockpitUsageTests: XCTestCase {
  /// A reading as the Cockpit served it on 2026-10-05.
  let served = """
    {"ok":true,"present":true,"weekly_pct":69,"fable_pct":87,"model_pct":87,"model_name":"Fable",
     "resets":"2026-10-05T21:59:59-07:00","resets_in":"14H","pacing":"On track","age":"2h","stale":false,
     "pending":false,"el_pct":16,"el_used":21249,"el_limit":136714,"el_minutes_left":230.0,"el_hours_left":3.8,
     "el_tier":"creator","el_resets_in":"23D10H","el_age":"56m","el_stale":false}
    """

  func testServedReadingShowsWhatIsLeft() throws {
    let strip = try XCTUnwrap(UsageStrip(CockpitUsage.decode(Data(served.utf8))))
    XCTAssertEqual(strip.bars.map(\.label), ["Week", "Fable", "Voice"])
    XCTAssertEqual(strip.bars.map(\.text), ["31%", "13%", "3.8h"])
    XCTAssertEqual(strip.bars.map(\.level), [.ok, .low, .ok])
    XCTAssertEqual(strip.bars[2].left, 0.84, accuracy: 1e-9)
    XCTAssertEqual(strip.claudeNote, "resets in 14H · On track")
    XCTAssertEqual(strip.voiceNote, "voice resets in 23D10H")
    XCTAssertFalse(strip.claudeStale)
  }

  func testLevels() {
    XCTAssertEqual(UsageStrip.level(left: 0.25), .ok)
    XCTAssertEqual(UsageStrip.level(left: 0.19), .low)
    XCTAssertEqual(UsageStrip.level(left: 0.09), .critical)
  }

  func testNoReadingDrawsNothingNeverZero() throws {
    XCTAssertNil(UsageStrip(try CockpitUsage.decode(Data(#"{"present":false,"reason":"none yet"}"#.utf8))))
    // No Claude reading but a voice one: only Voice, and no Claude note.
    let voiceOnly = try XCTUnwrap(UsageStrip(CockpitUsage(present: false, weeklyPct: 50, elPct: 95, elMinutesLeft: 12)))
    XCTAssertEqual(voiceOnly.bars.map(\.label), ["Voice"])
    XCTAssertEqual(voiceOnly.bars[0].text, "12m")
    XCTAssertEqual(voiceOnly.bars[0].level, .critical)
    XCTAssertNil(voiceOnly.claudeNote)
  }

  func testStaleSaysItsAge() throws {
    let strip = try XCTUnwrap(
      UsageStrip(CockpitUsage(present: true, weeklyPct: 10, age: "2D", stale: true, elPct: 10, elAge: "3h", elStale: true)))
    XCTAssertTrue(strip.claudeStale)
    XCTAssertEqual(strip.claudeNote, "2D old")
    XCTAssertTrue(strip.voiceStale)
    XCTAssertEqual(strip.voiceNote, "voice 3h old")
  }

  func testOlderReadingWithOnlyFable() throws {
    let strip = try XCTUnwrap(UsageStrip(CockpitUsage(present: true, weeklyPct: 40, fablePct: 120, modelName: "")))
    XCTAssertEqual(strip.bars.map(\.label), ["Week", "Fable"])
    XCTAssertEqual(strip.bars[1].text, "0%")
    XCTAssertEqual(strip.bars[1].left, 0)
  }

  func testUnspentQuotaNearTheResetSaysToSpend() throws {
    let reset = "2026-10-05T21:59:59-07:00"
    let at = try XCTUnwrap(ISO8601DateFormatter().date(from: reset))
    let usage = CockpitUsage(present: true, weeklyPct: 69, resetsIn: "13H", resets: reset, pacing: "On track")
    XCTAssertEqual(UsageStrip(usage, now: at.addingTimeInterval(-13 * 3600))?.spendNote, "31% to spend")
    // Two days out: not yet.
    XCTAssertNil(UsageStrip(usage, now: at.addingTimeInterval(-48 * 3600))?.spendNote)
    // Under 20% left: nothing worth nudging.
    var low = usage
    low.weeklyPct = 85
    XCTAssertNil(UsageStrip(low, now: at.addingTimeInterval(-3600))?.spendNote)
    // Past the reset (a stale reading's instant): nothing.
    XCTAssertNil(UsageStrip(usage, now: at.addingTimeInterval(60))?.spendNote)
    // A stale reading does not nudge.
    var old = usage
    old.stale = true
    XCTAssertNil(UsageStrip(old, now: at.addingTimeInterval(-3600))?.spendNote)
  }

  func testServedReadingDecodesTheResetInstant() throws {
    XCTAssertEqual(try CockpitUsage.decode(Data(served.utf8)).resets, "2026-10-05T21:59:59-07:00")
  }
}
