//  JSON as JavaScript writes it, JavaScript's rounding and dates, the box-plot statistics and the summary text
//  (ports of __tests__/stats.test.ts and summary.test.ts, plus the JSON writer the byte-for-byte export rests on).

import XCTest

@testable import ContextCore

let la = LocalClock(timeZone: TimeZone(identifier: "America/Los_Angeles")!)

final class JSValueTests: XCTestCase {
  func testNumbersAreWrittenAsJavaScriptWritesThem() {
    XCTAssertEqual(JSValue.formatNumber(181), "181")
    XCTAssertEqual(JSValue.formatNumber(-0.0), "0")
    XCTAssertEqual(JSValue.formatNumber(7.1), "7.1")
    XCTAssertEqual(JSValue.formatNumber(0.1 + 0.2), "0.30000000000000004")
    XCTAssertEqual(JSValue.formatNumber(3.943000000000002), "3.943000000000002")
    XCTAssertEqual(JSValue.formatNumber(1380.52), "1380.52")
    XCTAssertEqual(JSValue.formatNumber(0.00001), "0.00001")
    XCTAssertEqual(JSValue.formatNumber(0.000001), "0.000001")
    XCTAssertEqual(JSValue.formatNumber(1e-7), "1e-7")
    XCTAssertEqual(JSValue.formatNumber(1.5e-7), "1.5e-7")
    XCTAssertEqual(JSValue.formatNumber(1e21), "1e+21")
    XCTAssertEqual(JSValue.formatNumber(123456789012), "123456789012")
    XCTAssertEqual(JSValue.formatNumber(.nan), "null")
  }

  func testStringsEscapeOnlyWhatJavaScriptEscapes() {
    let v = JSValue.string("igor\u{2019}s \u{A0}Watch / \"ultra\"\n\t\u{01}\\")
    XCTAssertEqual(v.stringify(), "\"igor\u{2019}s \u{A0}Watch / \\\"ultra\\\"\\n\\t\\u0001\\\\\"")
  }

  func testCompactAndIndentedMatchJSONStringify() {
    let v = JSValue.object([("a", .number(1)), ("b", .array([])), ("c", .object([])), ("d", .array([.null, .bool(true)]))])
    XCTAssertEqual(v.stringify(), #"{"a":1,"b":[],"c":{},"d":[null,true]}"#)
    XCTAssertEqual(v.stringify(indent: 2), "{\n  \"a\": 1,\n  \"b\": [],\n  \"c\": {},\n  \"d\": [\n    null,\n    true\n  ]\n}")
  }

  func testParseKeepsKeyOrderAndRoundTrips() {
    let text = #"{"z":1,"a":[1.5,"xé\n",null,false],"m":{"k":-2e-7}}"#
    let v = JSValue.parse(text)
    XCTAssertEqual(v?.stringify(), #"{"z":1,"a":[1.5,"xé\n",null,false],"m":{"k":-2e-7}}"#)
    XCTAssertNil(JSValue.parse("{\"a\":}"))
  }
}

final class JSTimeTests: XCTestCase {
  func testMathRoundTakesHalvesUp() {
    XCTAssertEqual(jsRound(2.5), 3)
    XCTAssertEqual(jsRound(-2.5), -2)
    XCTAssertEqual(jsRound(0.49999999999999994), 0)
    XCTAssertEqual(round1(0.25), 0.3)
    XCTAssertEqual(round2(82.125), 82.13)
  }

  func testISOStringsMatchToISOString() {
    XCTAssertEqual(isoString(0), "1970-01-01T00:00:00.000Z")
    XCTAssertEqual(isoString(1_777_814_858_089), "2026-05-03T13:27:38.089Z")
    XCTAssertEqual(parseISO("2026-05-03T13:27:38.089Z"), 1_777_814_858_089)
    XCTAssertEqual(parseISO("2026-04-24T05:30:00Z"), 1_777_008_600_000)
  }

  func testLocalCalendar() {
    let noon = la.localTime(year: 2026, month: 3, day: 15, hour: 12)
    XCTAssertEqual(la.dateKey(noon), "2026-03-15")
    XCTAssertEqual(la.dateKey(la.addDays(noon, -15)), "2026-02-28")
    // Across the spring-forward night the wall clock is kept.
    XCTAssertEqual(la.hour(la.addDays(la.localTime(year: 2026, month: 3, day: 7, hour: 9), 1)), 9)
    XCTAssertEqual(la.dateKey(la.endOfDay("2025-12-31")), "2025-12-31")
    XCTAssertEqual(la.weekday(la.midnight("2026-05-03")), 0)
  }
}

final class StatsTests: XCTestCase {
  func testPercentile() {
    XCTAssertEqual(Stats.percentile([42], 0.5), 42)
    XCTAssertEqual(Stats.percentile([1, 2, 3, 4, 5], 0), 1)
    XCTAssertEqual(Stats.percentile([1, 2, 3, 4, 5], 1), 5)
    XCTAssertEqual(Stats.percentile([1, 2, 3, 4], 0.5), 2.5)
    XCTAssertEqual(Stats.percentile([1, 2, 3, 4, 5], 0.5), 3)
    XCTAssertEqual(Stats.percentile([1, 2, 3, 4, 5], 0.25), 2)
    XCTAssertEqual(Stats.percentile([10, 20], 0.3), 13)
    XCTAssertNil(Stats.percentile([], 0.5))
  }

  func testBoxPlot() {
    XCTAssertNil(Stats.boxPlot([]))
    XCTAssertNil(Stats.boxPlot([.nan, .infinity]))
    let one = Stats.boxPlot([7])!
    XCTAssertEqual([one.min, one.p5, one.p50, one.p95, one.max], [7, 7, 7, 7, 7])
    let s = Stats.boxPlot([5000, 8000, 3000, 10000, 6000, 7000, 9000])!
    XCTAssertEqual(s.min, 3000)
    XCTAssertEqual(s.p5, 3600)
    XCTAssertEqual(s.p25, 5500)
    XCTAssertEqual(s.p50, 7000)
    XCTAssertEqual(s.p75, 8500)
    XCTAssertEqual(s.p95, 9700)
    XCTAssertEqual(s.max, 10000)
    XCTAssertEqual(s.values, [3000, 5000, 6000, 7000, 8000, 9000, 10000])
    XCTAssertEqual(Stats.boxPlot([1, .nan, 3])!.values, [1, 3])
    XCTAssertEqual(Stats.boxPlot([1.234, 5.678])!.min, 1.2)
  }

  func testValuesSkipsNulls() {
    XCTAssertEqual(Stats.values([DailyValue(date: "a", value: 1), DailyValue(date: "b", value: nil)]), [1])
    XCTAssertEqual(Stats.values([]), [])
  }
}

final class SummaryTextTests: XCTestCase {
  var full: HealthData {
    var h = HealthData()
    h.steps = 8241
    h.heartRate = 72
    h.sleepHours = 7.5
    h.activeEnergy = 450
    h.walkingDistance = 5.2
    h.weight = 80
    h.meditationMinutes = 15
    return h
  }

  func testFormatTimeIsUTC() {
    XCTAssertEqual(SummaryText.formatTime("2026-03-15T23:00:00Z"), "11pm")
    XCTAssertEqual(SummaryText.formatTime("2026-03-15T06:15:00Z"), "6:15am")
    XCTAssertEqual(SummaryText.formatTime("2026-03-15T12:00:00Z"), "12pm")
    XCTAssertEqual(SummaryText.formatTime("2026-03-15T00:00:00Z"), "12am")
    XCTAssertEqual(SummaryText.formatTime("2026-03-15T13:30:00Z"), "1:30pm")
  }

  func testFormatLocalTime() {
    XCTAssertEqual(SummaryText.formatLocalTime("2026-04-24T05:30:00Z", clock: la), "10:30pm")
    XCTAssertEqual(SummaryText.formatLocalTime("2026-04-24T12:19:00Z", clock: la), "5:19am")
    XCTAssertEqual(SummaryText.formatLocalTime("2026-04-24T14:00:00Z", clock: la), "7am")
  }

  func testFormatNumber() {
    XCTAssertEqual(SummaryText.formatNumber(8241), "8,241")
    XCTAssertEqual(SummaryText.formatNumber(100), "100")
    XCTAssertEqual(SummaryText.formatNumber(1_000_000), "1,000,000")
    XCTAssertEqual(SummaryText.formatNumber(0), "0")
    XCTAssertEqual(SummaryText.formatNumber(1380.52, maxFractionDigits: 2), "1,380.52")
  }

  func testBuildSummary() {
    XCTAssertEqual(
      SummaryText.buildSummary(full, locationCount: 1234),
      "8,241 steps | Slept 7.5hrs | 72 bpm | 450 kcal | 5.2 km | 176 lbs | 15 min meditation | 1,234 locations")
    var h = full
    h.bedtime = "2026-03-15T23:00:00Z"
    h.wakeTime = "2026-03-16T06:15:00Z"
    XCTAssertTrue(SummaryText.buildSummary(h, locationCount: 0).contains("Slept 7.5hrs (11pm\u{2013}6:15am)"))
    h.steps = nil
    XCTAssertFalse(SummaryText.buildSummary(h, locationCount: 0).contains("steps"))
    XCTAssertEqual(SummaryText.buildSummary(HealthData(), locationCount: 0), "")
    XCTAssertEqual(SummaryText.buildSummary(HealthData(), locationCount: 5), "5 locations")
    var w = HealthData()
    w.exerciseMinutes = 35
    XCTAssertEqual(SummaryText.buildSummary(w, locationCount: 0), "35 min exercise")
    w.workouts = [
      WorkoutEntry(activityType: "Running", durationMinutes: 30, energyBurned: 300, distanceKm: 5.2),
      WorkoutEntry(activityType: "Yoga", durationMinutes: 20, energyBurned: nil, distanceKm: nil),
    ]
    XCTAssertEqual(SummaryText.buildSummary(w, locationCount: 0), "Running 30min 300kcal 5.2km, Yoga 20min")
    XCTAssertFalse(SummaryText.buildSummary(full, locationCount: 0).hasSuffix("|"))
  }
}
