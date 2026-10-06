//  The week per metric, the export's shape and the cache (ports of __tests__/weekly.test.ts, share.test.ts and
//  the cache rules of lib/healthCache.ts).

import XCTest

@testable import ContextCore

private func local(_ d: Int, _ h: Int, _ m: Int = 0, month: Int = 3) -> Double {
  la.localTime(year: 2026, month: month, day: d, hour: h, minute: m)
}

final class WeeklyTests: XCTestCase {
  let end = local(15, 12)

  func testDateKeysAreLocalAndOldestFirst() {
    XCTAssertEqual(la.dateKey(la.localTime(year: 2026, month: 1, day: 5)), "2026-01-05")
    XCTAssertEqual(la.dateKey(la.localTime(year: 2025, month: 12, day: 31, hour: 23, minute: 59)), "2025-12-31")
    XCTAssertEqual(
      Weekly.dateKeys(endDate: end, clock: la),
      ["2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12", "2026-03-13", "2026-03-14", "2026-03-15"])
  }

  func testBucketByDay() {
    let samples = [local(15, 9), local(15, 18), local(13, 7), local(1, 7)].map { QuantityReading(start: $0, quantity: 2) }
    let days = Weekly.bucketByDay(samples, start: \.start, endDate: end, days: 7, clock: la) { Double($0.count) }
    XCTAssertEqual(days.map(\.value), [nil, nil, nil, nil, 1, nil, 2])
    XCTAssertEqual(
      Weekly.bucketByDay([QuantityReading](), start: \.start, endDate: end, days: 7, clock: la) { _ in 1 }.compactMap(\.value), [])
  }

  func testAverage() {
    XCTAssertNil(Weekly.average([]))
    XCTAssertNil(Weekly.average([DailyValue(date: "a", value: nil)]))
    XCTAssertEqual(Weekly.average([DailyValue(date: "a", value: 10), DailyValue(date: "b", value: nil), DailyValue(date: "c", value: 20)]), 15)
    XCTAssertEqual(Weekly.average([10, 10, 11].map { DailyValue(date: "a", value: $0) }), 10.3)
  }

  func testHeartRateDays() {
    let samples = [60, 80, 70, 90].enumerated().map { QuantityReading(start: local(15, 8 + $0.offset), quantity: Double($0.element)) }
      + [QuantityReading(start: local(14, 9), quantity: 61.0)]
    let days = Weekly.aggregateHeartRate(samples, endDate: end, clock: la)
    XCTAssertEqual(days.count, 7)
    let today = days[6]
    XCTAssertEqual(today.avg, 75)
    XCTAssertEqual(today.min, 60)
    XCTAssertEqual(today.max, 90)
    XCTAssertEqual(today.q1, 67.5)
    XCTAssertEqual(today.median, 75)
    XCTAssertEqual(today.q3, 82.5)
    XCTAssertEqual(today.count, 4)
    XCTAssertEqual(today.raw.map(\.value), [60, 70, 80, 90])
    XCTAssertEqual(days[5].avg, 61)
    XCTAssertEqual(days[5].q1, 61)
    XCTAssertNil(days[0].avg)
    let thirds = Weekly.aggregateHeartRate([70, 71, 71].map { QuantityReading(start: local(15, 9), quantity: $0) }, endDate: end, clock: la)
    XCTAssertEqual(thirds[6].avg, 70.7)
  }

  func testSleepByStartDayMeditationAndLatestWeight() {
    let sleep = Weekly.aggregateSleep(
      [
        SleepSample(start: local(14, 23), end: local(15, 7), value: 3),
        SleepSample(start: local(14, 23, 30), end: local(15, 6, 30), value: 3),
      ], endDate: end, clock: la)
    XCTAssertEqual(sleep[5].value, 8)
    XCTAssertNil(sleep[6].value)

    let med = Weekly.aggregateMeditation(
      [
        TimeSpan(start: local(15, 7), end: local(15, 7, 10)), TimeSpan(start: local(15, 20), end: local(15, 20, 15)),
        TimeSpan(start: local(14, 7, 10), end: local(14, 7)),
      ], endDate: end, clock: la)
    XCTAssertEqual(med[6].value, 25)
    XCTAssertEqual(med[5].value, 0)
    XCTAssertNil(med[4].value)

    let weight = Weekly.pickLatestPerDay(
      [
        QuantityReading(start: local(15, 7), quantity: 82.456), QuantityReading(start: local(15, 21), quantity: 82.1),
        QuantityReading(start: local(1, 7), quantity: 90),
      ], endDate: end, clock: la)
    XCTAssertEqual(weight[6].value, 82.1)
    XCTAssertEqual(weight.compactMap(\.value).count, 1)
  }

  func testMovementOverlay() {
    let keys = ["a", "b", "c"]
    let o = Weekly.movementOverlay(
      steps: zip(keys, [1000, nil, 4000]).map { DailyValue(date: $0, value: $1) },
      distance: zip(keys.reversed(), [2, 1, nil]).map { DailyValue(date: $0, value: $1) },
      energy: keys.map { DailyValue(date: $0, value: nil) })
    XCTAssertEqual(o.stepsMax, 4000)
    XCTAssertEqual(o.stepsNormalized, [0.25, nil, 1])
    XCTAssertEqual(o.days.map(\.distanceKm), [nil, 1, 2])
    XCTAssertEqual(o.energyMax, 0)
    XCTAssertEqual(o.energyNormalized, [nil, nil, nil])
  }

  func testDaysSinceLast() {
    let now = local(15, 12)
    func week(_ v: [Double?]) -> [DailyValue] { zip(Weekly.dateKeys(endDate: now, clock: la), v).map { DailyValue(date: $0, value: $1) } }
    XCTAssertEqual(Weekly.daysSinceLast(week([nil, nil, nil, nil, nil, nil, 5]), now: now, clock: la), 0)
    XCTAssertEqual(Weekly.daysSinceLast(week([nil, nil, nil, nil, nil, 5, nil]), now: now, clock: la), 1)
    XCTAssertEqual(Weekly.daysSinceLast(week([5, nil, nil, nil, nil, 0, nil]), now: now, clock: la), 6)
    XCTAssertNil(Weekly.daysSinceLast(week([0, nil, 0, nil, nil, nil, nil]), now: now, clock: la))
    XCTAssertNil(Weekly.daysSinceLast([], now: now, clock: la))
  }
}

final class ContextExportTests: XCTestCase {
  let keys = Weekly.dateKeys(endDate: la.localTime(year: 2026, month: 3, day: 15, hour: 12), clock: la)

  func week(steps: [Double?] = Array(repeating: nil, count: 7)) -> WeeklyDataMap {
    var series: [MetricKey: WeeklySeries] = [:]
    for m in MetricKey.series {
      series[m] = m.isRanged ? .ranged(keys.map { HeartRateDaily(date: $0) }) : .daily(keys.map { DailyValue(date: $0, value: nil) })
    }
    series[.steps] = .daily(zip(keys, steps).map { DailyValue(date: $0, value: $1) })
    var hr = keys.map { HeartRateDaily(date: $0) }
    hr[6].avg = 72.5
    hr[6].min = 55
    hr[6].max = 140
    series[.heartRate] = .ranged(hr)
    var hrv = keys.map { HeartRateDaily(date: $0) }
    hrv[6].avg = 45.2
    series[.hrv] = .ranged(hrv)
    return WeeklyDataMap(series: series)
  }

  func testDayOfWeek() {
    XCTAssertEqual(ContextExport.dayOfWeek("2026-03-15", clock: la), "Sunday")
    XCTAssertEqual(ContextExport.dayOfWeek("2026-03-16", clock: la), "Monday")
    XCTAssertEqual(ContextExport.dayOfWeek("2026-03-21", clock: la), "Saturday")
  }

  func testDailyExportMapsEveryMetric() {
    let days = ContextExport.dailyExport(week(steps: [nil, nil, nil, nil, nil, 8000, 9500]), clock: la).array!
    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(days[0]["date"]?.string, "2026-03-09")
    XCTAssertEqual(days[0]["dayOfWeek"]?.string, "Monday")
    XCTAssertEqual(days[0]["heartRate"], .null)
    XCTAssertEqual(days[6]["steps"]?.double, 9500)
    XCTAssertEqual(days[6]["heartRate"]?.stringify(), #"{"avg":72.5,"min":55,"max":140}"#)
    XCTAssertEqual(days[6]["hrvMs"]?.double, 45.2)
    XCTAssertEqual(days[6]["restingHeartRate"], .null)
    XCTAssertEqual(
      days[0].stringify(),
      #"{"date":"2026-03-09","dayOfWeek":"Monday","steps":null,"heartRate":null,"sleepHours":null,"activeEnergy":null,"walkingDistanceKm":null,"weightLbs":null,"meditationMinutes":null,"hrvMs":null,"restingHeartRate":null,"exerciseMinutes":null}"#
    )
  }

  func testSummaryHasNoCoordinatesAndLeadsWithRoles() {
    var h = HealthData()
    h.weight = 82.1
    h.bedtime = "2026-03-15T06:00:00.000Z"
    h.wakeTime = "2026-03-15T13:15:00.000Z"
    let json = ContextExport.summary(week(), health: h, places: nil, accessory: nil, clock: la).stringify()
    XCTAssertTrue(json.hasPrefix(#"{"roles":null,"today":{"date":"2026-03-15","dayOfWeek":"Sunday""#))
    XCTAssertTrue(json.contains(#""weightLbs":181"#))
    XCTAssertTrue(json.contains(#""bedtime":"6am","wakeTime":"1:15pm""#))
    XCTAssertTrue(json.hasSuffix(#""places":null,"accessory":null}"#))
    for key in ["latitude", "longitude", "center", "radiusMeters", "pointCount", "firstVisit", "lastVisit", "weeklyStats"] {
      XCTAssertFalse(json.contains("\"\(key)\""), key)
    }
    let withPlaces = ContextExport.summary(
      week(), health: h, places: PlacesSummary(weekly: "This week: Home 92h", recent: "r"), accessory: [], clock: la
    ).stringify()
    XCTAssertTrue(withPlaces.hasSuffix(#""places":{"weekly":"This week: Home 92h","recent":"r"},"accessory":[]}"#))
  }

  func testAccessoryExportOrdersNewestFirstAndLaterRowFirstWithinASave() {
    let e = ContextExport.accessoryExport([
      AccessoryLogEntry(id: 1, itemId: "half_lotus", itemName: "Half Lotus", loggedAt: 1_777_000_000_000, dateKey: "2026-04-23"),
      AccessoryLogEntry(id: 2, itemId: "dead_hangs", itemName: "Dead Hangs", loggedAt: 1_777_000_000_000, dateKey: "2026-04-23"),
      AccessoryLogEntry(id: 3, itemId: "pigeon_stretch", itemName: "Pigeon Stretch", loggedAt: 1_777_100_000_000, dateKey: "2026-04-25"),
    ])
    XCTAssertEqual(e.map(\.name), ["Pigeon Stretch", "Dead Hangs", "Half Lotus"])
    XCTAssertEqual(e[1].timestamp, "2026-04-24T03:06:40.000Z")
    XCTAssertEqual(e[1].date, "2026-04-23")
    XCTAssertEqual(ContextExport.accessoryExport([]), [])
  }

  func testRawShareIsIndentedWithNullLocationUntilPlacesMoves() {
    let raw = ContextExport.raw(timestamp: "2026-03-15T19:00:00.000Z", health: HealthData()).stringify(indent: 2)
    XCTAssertTrue(raw.hasPrefix("{\n  \"timestamp\": \"2026-03-15T19:00:00.000Z\",\n  \"health\": {\n    \"steps\": null,"))
    XCTAssertTrue(raw.hasSuffix("    \"workouts\": []\n  },\n  \"location\": null,\n  \"locationClusters\": null\n}"))
    XCTAssertFalse(raw.contains("locationHistory"))
  }

  func testWeeklyStats() {
    let stats = ContextExport.weeklyStats(week(steps: [1000, 2000, 3000, nil, nil, nil, nil]))
    XCTAssertEqual(stats.map(\.0).first, "steps")
    XCTAssertEqual(stats[0].1?.p50, 2000)
    XCTAssertEqual(stats[1].1?.max, 72.5)
    XCTAssertNil(stats[2].1)
  }
}

final class HealthCacheTests: XCTestCase {
  func testRoundTripAndVersionBust() throws {
    let db = try SQLiteDatabase()
    let cache = try HealthCache(db: db)
    try cache.putComputed(.steps, "2026-03-14", DailyValue(date: "2026-03-14", value: 8241.37).json)
    try cache.putRaw(.steps, "2026-03-14", .array([]))
    XCTAssertEqual(try cache.computed(.steps, ["2026-03-14", "2026-03-13"])["2026-03-14"]?.stringify(), #"{"date":"2026-03-14","value":8241.37}"#)
    XCTAssertEqual(try cache.computed(.hrv, ["2026-03-14"]).count, 0)
    // The React Native app's text reads back.
    try db.run(
      "INSERT OR REPLACE INTO health_computed_cache (metric, date_key, data, cached_at) VALUES ('heartRate', '2026-03-13', ?, 0)",
      [.text(#"{"date":"2026-03-13","avg":61,"min":61,"max":61,"q1":61,"median":61,"q3":61,"count":1,"raw":[{"value":61,"time":"2026-03-13T16:00:00.000Z"}]}"#)])
    let hr = try XCTUnwrap(cache.computed(.heartRate, ["2026-03-13"])["2026-03-13"].flatMap(HeartRateDaily.init(json:)))
    XCTAssertEqual(hr.avg, 61)
    XCTAssertEqual(hr.raw.first?.time, "2026-03-13T16:00:00.000Z")

    try db.run("UPDATE health_cache_meta SET value = '1' WHERE key = 'cache_version'")
    let reopened = try HealthCache(db: db)
    XCTAssertEqual(try reopened.computed(.steps, ["2026-03-14"]).count, 0)
    XCTAssertEqual(try db.run("SELECT value FROM health_cache_meta").first?["value"]?.textValue, "2")
  }

  func testTodayIsAlwaysAskedAgain() {
    let keys = ["2026-03-13", "2026-03-14", "2026-03-15"]
    let p = HealthCache.partition(
      todayKey: "2026-03-15", dateKeys: keys, cached: ["2026-03-13": .null, "2026-03-15": .null])
    XCTAssertEqual(p.fetch, ["2026-03-14", "2026-03-15"])
    XCTAssertEqual(Array(p.cached.keys), ["2026-03-13"])
  }
}

final class MirrorTextTests: XCTestCase {
  let now = la.localTime(year: 2026, month: 3, day: 15, hour: 12)

  func testCardsReadAsTheBodyTabDoes() {
    var h = HealthData()
    h.steps = 8241
    h.walkingDistance = 5.23
    h.activeEnergy = 1450
    h.heartRate = 72
    h.sleepHours = 6.8
    h.bedtime = "2026-03-15T06:00:00.000Z"  // 11pm PDT
    h.wakeTime = "2026-03-15T13:15:00.000Z"  // 7h15m later
    h.weight = 82.1
    h.weightDaysLast7 = 3
    h.workouts = [WorkoutEntry(activityType: "HIIT", durationMinutes: 25, energyBurned: nil, distanceKm: nil)]
    let keys = Weekly.dateKeys(endDate: now, clock: la)
    let cards = MirrorText.cards(
      h, weekly: [.steps: .daily(keys.map { DailyValue(date: $0, value: 1000) })], now: now, clock: la)
    XCTAssertEqual(cards.map(\.label), ["Movement", "Exercise", "Heart Rate", "HRV", "Sleep", "Meditation", "Weight"])
    XCTAssertEqual(cards[0].value, "8,241")
    XCTAssertEqual(cards[0].sublabel, "5.23 km \u{00B7} 1,450 kcal")
    XCTAssertEqual(cards[0].boxPlots.count, 1)
    XCTAssertEqual(cards[1].value, MirrorText.none)
    XCTAssertEqual(cards[1].sublabel, "HIIT 25m")
    XCTAssertEqual(cards[2].value, "72 bpm")
    XCTAssertTrue(cards[3].isEmpty)
    XCTAssertEqual(cards[4].value, "6.8h asleep")
    XCTAssertEqual(cards[4].sublabel, "7.3h bed \u{00B7} 94% eff")
    XCTAssertEqual(cards[6].value, "181 lbs")
    XCTAssertEqual(cards[6].sublabel, "3/7 days weighed")

    let empty = MirrorText.cards(nil, weekly: [:], now: now, clock: la)
    XCTAssertTrue(empty.allSatisfy { $0.isEmpty })
    XCTAssertEqual(empty[1].sublabel, "7+ days ago")
    XCTAssertEqual(empty[4].sublabel, "last night")
    XCTAssertEqual(empty[0].sublabel, "\u{2014} km \u{00B7} \u{2014} kcal")
  }

  func testSheetText() {
    XCTAssertEqual(MirrorText.dayRow("2026-03-15"), "Sun, Mar 15")
    var d = HeartRateDaily(date: "x")
    XCTAssertEqual(MirrorText.heartRateRow(d), "\u{2014}")
    d.avg = 72.5
    d.min = 55
    d.max = 140.4
    XCTAssertEqual(MirrorText.heartRateRow(d), "73 avg (55\u{2013}140)")
    XCTAssertEqual(MirrorText.dailyValue(DailyValue(date: "x", value: 8241), unit: "steps"), "8,241 steps")
    XCTAssertEqual(MirrorText.dailyValue(DailyValue(date: "x", value: 1380.517), unit: "kcal"), "1,380.52 kcal")
    XCTAssertEqual(
      MirrorText.average(.steps, series: .daily([DailyValue(date: "a", value: 1000), DailyValue(date: "b", value: 2001)]), sleepNights: nil),
      "Avg: 1,500.5 steps/day")
    var n1 = SleepDaily(date: "a")
    n1.totalHours = 7
    var n2 = SleepDaily(date: "b")
    n2.totalHours = 6.5
    XCTAssertEqual(MirrorText.average(.sleep, series: nil, sleepNights: [n1, n2, SleepDaily(date: "c")]), "Avg: 6.8 hrs/day")
    XCTAssertEqual(MirrorText.sleepDebt(0, target: 8), "Sleep debt: 0m (caught up!)")
    XCTAssertEqual(MirrorText.sleepDebt(3.2, target: 8), "Sleep debt: \u{2212}3h 12m over 7 days (target 8h)")
    XCTAssertEqual(MirrorText.sleepDebt(0.5, target: 7.5), "Sleep debt: \u{2212}30m over 7 days (target 7.5h)")
    XCTAssertNil(MirrorText.onsetTag(9))
    XCTAssertEqual(MirrorText.onsetTag(25), "onset 25m")
    XCTAssertEqual(MirrorText.gapTag(95), "gap 1h 35m")
    XCTAssertEqual(MirrorText.gapTag(60), "gap 1h")
  }
}
