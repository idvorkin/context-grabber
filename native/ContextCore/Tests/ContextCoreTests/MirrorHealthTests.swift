//  Health and sleep math (ports of __tests__/health.test.ts and sleep.test.ts).

import XCTest

@testable import ContextCore

private let minute = 60_000.0
private let hour = 3_600_000.0
private func utc(_ iso: String) -> Double { parseISO(iso)! }
private func local(_ d: Int, _ h: Int, _ m: Int = 0, month: Int = 3) -> Double {
  la.localTime(year: 2026, month: month, day: d, hour: h, minute: m)
}

final class HealthMathTests: XCTestCase {
  func testSleepHoursMergesAndRounds() {
    XCTAssertNil(Health.sleepHours(nil))
    XCTAssertNil(Health.sleepHours([]))
    XCTAssertEqual(Health.sleepHours([SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T07:00:00Z"))]), 8)
    XCTAssertEqual(
      Health.sleepHours([
        SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T02:00:00Z")),
        SleepSample(start: utc("2026-03-15T03:00:00Z"), end: utc("2026-03-15T07:00:00Z")),
      ]), 7)
    XCTAssertEqual(Health.sleepHours([SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T06:30:00Z"))]), 7.5)
    // Watch 23:00–07:00 and phone 23:30–06:30: one night, not two.
    XCTAssertEqual(
      Health.sleepHours([
        SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T07:00:00Z")),
        SleepSample(start: utc("2026-03-14T23:30:00Z"), end: utc("2026-03-15T06:30:00Z")),
      ]), 8)
    // In bed and awake do not count; only in bed at all is null.
    XCTAssertEqual(
      Health.sleepHours([
        SleepSample(start: utc("2026-03-14T22:00:00Z"), end: utc("2026-03-15T07:00:00Z"), value: 0),
        SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T06:00:00Z"), value: 3),
        SleepSample(start: utc("2026-03-15T02:00:00Z"), end: utc("2026-03-15T02:30:00Z"), value: 2),
      ]), 7)
    XCTAssertNil(Health.sleepHours([SleepSample(start: 0, end: hour, value: 0)]))
    XCTAssertEqual(Health.sleepHours([SleepSample(start: hour, end: hour, value: 3)]), 0)
  }

  func testFilterActualSleepKeepsUntypedData() {
    let untyped = [SleepSample(start: 0, end: hour)]
    XCTAssertEqual(Health.filterActualSleep(untyped), untyped)
    XCTAssertEqual(
      Health.filterActualSleep([0, 1, 2, 3, 4, 5].map { SleepSample(start: 0, end: hour, value: $0) }).map(\.value),
      [1, 3, 4, 5])
    XCTAssertEqual(Health.sleepCategoryName(nil), "Asleep")
    XCTAssertEqual(Health.sleepCategoryName(4), "Deep")
    XCTAssertEqual(Health.sleepCategoryName(9), "Unknown")
  }

  func testSleepBySourceKeepsFirstSeenOrderAndStageHours() {
    let r = Health.sleepBySource([
      SleepSample(start: utc("2026-03-15T03:00:00Z"), end: utc("2026-03-15T05:00:00Z"), value: 4, source: "Watch"),
      SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T07:00:00Z"), value: 1, source: "AutoSleep"),
      SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T03:00:00Z"), value: 3, source: "Watch"),
      SleepSample(start: utc("2026-03-15T05:00:00Z"), end: utc("2026-03-15T05:20:00Z"), value: 2, source: "Watch"),
    ])!
    XCTAssertEqual(r.map(\.0), ["Watch", "AutoSleep"])
    let watch = r[0].1
    XCTAssertEqual(watch.bedtime, "2026-03-14T23:00:00.000Z")
    XCTAssertEqual(watch.wakeTime, "2026-03-15T05:20:00.000Z")
    XCTAssertEqual([watch.coreHours, watch.deepHours, watch.remHours, watch.awakeHours], [4, 2, 0, 0.3])
    XCTAssertEqual(r[1].1.coreHours, 0)
    XCTAssertNil(Health.sleepBySource([]))
  }

  func testMeditationWeightAndWeighInDays() {
    XCTAssertNil(Health.meditationMinutes(nil))
    XCTAssertEqual(Health.meditationMinutes([TimeSpan(start: 0, end: 10 * minute), TimeSpan(start: 0, end: 5.5 * minute)]), 15.5)
    XCTAssertEqual(Health.meditationMinutes([TimeSpan(start: 10 * minute, end: 0)]), 0)
    XCTAssertEqual(Health.extractWeight(82.456), 82.46)
    XCTAssertNil(Health.extractWeight(nil))
    XCTAssertNil(Health.countWeightDays([], clock: la))
    XCTAssertEqual(
      Health.countWeightDays(
        [local(14, 7), local(14, 21), local(15, 7)].map { QuantityReading(start: $0, quantity: 80) }, clock: la), 2)
  }

  func testBuildHealthDataTurnsEachFailureIntoANull() {
    let bad: Result<Double?, HealthQueryError> = .failure(HealthQueryError("denied"))
    let r = HealthQueryResults(
      stepsSum: .success(8241.6), latestHeartRate: bad, activeEnergySum: .success(nil), distanceSum: .success(5.2345),
      sleep: .failure(HealthQueryError("x")), latestWeight: .success(82.456), mindful: .success([]),
      weightSamples: .success([QuantityReading(start: local(14, 7), quantity: 82)]), latestHRV: .success(45.67),
      latestRestingHeartRate: .success(58.4), exerciseSum: .success(34.5))
    let h = Health.buildHealthData(r, clock: la)
    XCTAssertEqual(h.steps, 8242)
    XCTAssertNil(h.heartRate)
    XCTAssertNil(h.activeEnergy)
    XCTAssertEqual(h.walkingDistance, 5.23)
    XCTAssertNil(h.sleepHours)
    XCTAssertNil(h.bedtime)
    XCTAssertNil(h.sleepBySource)
    XCTAssertEqual(h.weight, 82.46)
    XCTAssertEqual(h.weightDaysLast7, 1)
    XCTAssertNil(h.meditationMinutes)
    XCTAssertEqual(h.hrv, 45.7)
    XCTAssertEqual(h.restingHeartRate, 58)
    XCTAssertEqual(h.exerciseMinutes, 35)
    XCTAssertEqual(h.workouts, [])
  }

  func testWorkoutsAsTheReactNativeAppNamesAndRoundsThem() {
    let w = WorkoutRecord(
      activityType: 52, start: utc("2026-05-01T02:00:12.000Z"), end: 0, durationSeconds: 2410, energyKcal: 210.4,
      distanceMeters: 3215
    ).entry
    XCTAssertEqual(w.activityType, "Walking")
    XCTAssertEqual(w.durationMinutes, 40)
    XCTAssertEqual(w.energyBurned, 210)
    XCTAssertEqual(w.distanceKm, 3.22)
    XCTAssertEqual(w.endTime, "2026-05-01T02:40:22.000Z")
    let zero = WorkoutRecord(activityType: 9999, start: 0, end: 0, durationSeconds: 0, energyKcal: 0, distanceMeters: 0).entry
    XCTAssertEqual(zero.activityType, "Workout 9999")
    XCTAssertNil(zero.energyBurned)
    XCTAssertNil(zero.distanceKm)
  }

  func testHealthDataSurvivesTheLastGrabRoundTrip() {
    var h = HealthData()
    h.steps = 10
    h.bedtime = "2026-03-15T06:00:00.000Z"
    h.sleepBySource = [("Watch", SourceSleepSummary(bedtime: "a", wakeTime: "b", coreHours: 1, deepHours: 2, remHours: 3, awakeHours: 0.5))]
    h.workouts = [WorkoutEntry(activityType: "Yoga", durationMinutes: 20, energyBurned: nil, distanceKm: nil, startTime: "s")]
    let back = HealthData(json: JSValue.parse(h.json.stringify())!)
    XCTAssertEqual(back, h)
  }
}

final class SleepTests: XCTestCase {
  let end = local(15, 12)

  func testExtractSleepDetails() {
    XCTAssertEqual(Sleep.extractSleepDetails(nil), SleepDetails())
    let d = Sleep.extractSleepDetails([
      SleepSample(start: utc("2026-03-15T03:00:00Z"), end: utc("2026-03-15T07:00:00Z")),
      SleepSample(start: utc("2026-03-14T23:00:00Z"), end: utc("2026-03-15T02:00:00Z")),
    ])
    XCTAssertEqual(d.bedtime, "2026-03-14T23:00:00.000Z")
    XCTAssertEqual(d.wakeTime, "2026-03-15T07:00:00.000Z")
  }

  func testNightsRunNoonToNoon() {
    let empty = Sleep.aggregateDetailed(nil, endDate: end, clock: la)
    XCTAssertEqual(empty.count, 7)
    XCTAssertEqual(empty.last?.date, "2026-03-15")
    XCTAssertTrue(empty.allSatisfy { $0.totalHours == nil && $0.samples.isEmpty })

    let nights = Sleep.aggregateDetailed(
      [
        SleepSample(start: local(14, 23), end: local(15, 0), value: 3),
        SleepSample(start: local(15, 0), end: local(15, 1, 30), value: 4),
        SleepSample(start: local(15, 1, 30), end: local(15, 3), value: 5),
        SleepSample(start: local(15, 3), end: local(15, 3, 15), value: 2),
        SleepSample(start: local(15, 3, 15), end: local(15, 6), value: 3),
        // A late-morning nap belongs to the night before.
        SleepSample(start: local(15, 10), end: local(15, 10, 30), value: 1),
      ], endDate: end, clock: la)
    let n = nights.first { $0.date == "2026-03-14" }!
    XCTAssertEqual(n.samples.count, 6)
    XCTAssertEqual(n.coreHours, 3.8)
    XCTAssertEqual(n.deepHours, 1.5)
    XCTAssertEqual(n.remHours, 1.5)
    XCTAssertEqual(n.awakeHours, 0.3)
    XCTAssertEqual(n.totalHours, 6.8)
    XCTAssertEqual(la.hour(parseISO(n.bedtime!)!), 23)
    XCTAssertEqual(la.hour(parseISO(n.wakeTime!)!), 6)
    XCTAssertNil(nights.first { $0.date == "2026-03-15" }!.totalHours)
  }

  func testOverlappingSourcesAreMergedPerStage() {
    let n = Sleep.aggregateDetailed(
      [
        SleepSample(start: local(14, 23), end: local(15, 3, 30), value: 3, source: "Watch"),
        SleepSample(start: local(15, 3), end: local(15, 7), value: 3, source: "iPhone"),
      ], endDate: end, clock: la
    ).first { $0.date == "2026-03-14" }!
    XCTAssertEqual(n.coreHours, 8)
  }

  func testSleepDebt() {
    func nights(_ v: [Double?]) -> [SleepDaily] {
      v.map { var n = SleepDaily(date: "2026-03-15"); n.totalHours = $0; return n }
    }
    XCTAssertEqual(Sleep.sleepDebt(nights([8, 8, 8, 8, 8, 8, 8]), targetHours: 8), 0)
    XCTAssertEqual(Sleep.sleepDebt(nights([7, 7, 7, 7, 7, 7, 7]), targetHours: 8), 7)
    XCTAssertEqual(Sleep.sleepDebt(nights([6, 10, 6, 10, 6, 10, 6]), targetHours: 8), 8)
    XCTAssertEqual(Sleep.sleepDebt(nights([nil, 8]), targetHours: 8), 8)
    XCTAssertEqual(Sleep.sleepDebt(nights([5]), targetHours: 0), 0)
  }

  func testConsistencyWrapsAroundMidnight() {
    func night(_ bed: Double?, _ wake: Double?) -> SleepDaily {
      var n = SleepDaily(date: "2026-03-15")
      n.bedtime = bed.map(isoString)
      n.wakeTime = wake.map(isoString)
      return n
    }
    let same = Sleep.consistency(Array(repeating: night(local(14, 23), local(15, 7)), count: 3), clock: la)
    XCTAssertEqual(same, SleepConsistencyStats(bedtimeStdevMinutes: 0, wakeStdevMinutes: 0))
    XCTAssertEqual(Sleep.consistency([night(local(14, 23), nil), night(local(15, 1), nil)], clock: la).bedtimeStdevMinutes, 60)
    XCTAssertEqual(Sleep.consistency([night(nil, nil), night(local(15, 7), local(15, 7))], clock: la).bedtimeStdevMinutes, 0)
  }

  func testBundleAndDefaultSource() {
    XCTAssertEqual(Sleep.detailedBundle(nil, endDate: end, clock: la).bySource.count, 0)
    let b = Sleep.detailedBundle(
      [
        SleepSample(start: local(14, 23), end: local(15, 6), value: 1, source: "AutoSleep"),
        SleepSample(start: local(14, 23), end: local(15, 2), value: 3, source: "Watch"),
        SleepSample(start: local(15, 2), end: local(15, 4), value: 4, source: "Watch"),
        SleepSample(start: local(2, 23), end: local(3, 4), value: 3, source: "Old"),  // outside the week
      ], endDate: end, clock: la)
    XCTAssertEqual(b.bySource.keys.sorted(), ["AutoSleep", "Old", "Watch"])
    XCTAssertEqual(b.bySource["Watch"]!.first { $0.date == "2026-03-14" }!.totalHours, 5)
    XCTAssertEqual(b.merged.first { $0.date == "2026-03-14" }!.totalHours, 7)
    XCTAssertEqual(Sleep.pickDefaultSource(b), "Watch")
    let untyped = Sleep.detailedBundle(
      [SleepSample(start: local(14, 23), end: local(15, 6), value: 1, source: "AutoSleep")], endDate: end, clock: la)
    XCTAssertEqual(Sleep.pickDefaultSource(untyped), Sleep.allSources)
    XCTAssertEqual(Sleep.pickDefaultSource(SleepDetailedBundle(bySource: [:], merged: [])), "All")
  }

  func testTrackingGap() {
    func night(total: Double?, bed: String? = "2026-04-24T05:30:00Z", wake: String? = "2026-04-24T12:30:00Z") -> SleepDaily {
      var n = SleepDaily(date: "2026-04-23")
      n.totalHours = total
      n.bedtime = bed
      n.wakeTime = wake
      return n
    }
    XCTAssertNil(Sleep.trackingGap(night(total: 7)))
    XCTAssertNil(Sleep.trackingGap(night(total: 5, bed: nil)))
    XCTAssertNil(Sleep.trackingGap(night(total: nil)))
    XCTAssertNil(Sleep.trackingGap(night(total: 0)))
    XCTAssertNil(Sleep.trackingGap(night(total: 6.7)))
    XCTAssertEqual(Sleep.trackingGap(night(total: 6.25)), 45)
    let long = night(total: 9, bed: "2026-04-24T05:00:00Z", wake: "2026-04-24T15:00:00Z")
    XCTAssertNil(Sleep.trackingGap(long))
    var shorter = long
    shorter.totalHours = 8.5
    XCTAssertEqual(Sleep.trackingGap(shorter), 90)
    XCTAssertNil(Sleep.trackingGap(night(total: 1, bed: "2026-04-24T12:30:00Z", wake: "2026-04-24T12:30:00Z")))
    // Awake inside the night is covered time, not a gap.
    let bed = utc("2026-04-24T05:00:00Z")
    var awakeNight = night(total: 6.5, bed: isoString(bed), wake: isoString(bed + 8 * hour))
    awakeNight.samples = [SleepSample(start: bed + 2 * hour, end: bed + 3.5 * hour, value: 2)]
    XCTAssertNil(Sleep.trackingGap(awakeNight))
  }

  func testOnset() {
    let first = utc("2026-04-24T05:00:00Z")
    func awake(_ a: Double, _ b: Double) -> SleepSample { SleepSample(start: first + a, end: first + b, value: 2) }
    let sleep = SleepSample(start: first, end: first + 8 * hour, value: 3)
    XCTAssertNil(Sleep.onsetMinutes([sleep], firstSleep: first))
    XCTAssertEqual(Sleep.onsetMinutes([awake(-30 * minute, 0), sleep], firstSleep: first), 30)
    XCTAssertEqual(Sleep.onsetMinutes([awake(-50 * minute, -40 * minute), awake(-20 * minute, 0), sleep], firstSleep: first), 30)
    XCTAssertEqual(Sleep.onsetMinutes([awake(-4 * hour, -3.5 * hour), awake(-15 * minute, 0), sleep], firstSleep: first), 15)
    XCTAssertEqual(
      Sleep.onsetMinutes(
        [
          awake(-6 * hour, -5.5 * hour), awake(-90 * minute, -80 * minute), awake(-45 * minute, -30 * minute),
          awake(-20 * minute, 0), sleep,
        ], firstSleep: first), 45)
    XCTAssertNil(Sleep.onsetMinutes([sleep, awake(2 * hour, 2.25 * hour)], firstSleep: first))
    XCTAssertEqual(Sleep.onsetMinutes([awake(-30 * minute, -10 * minute), awake(-20 * minute, 0), sleep], firstSleep: first), 30)
  }

  func testMainSessionIgnoresNoise() {
    let t = utc("2026-04-23T00:00:00Z")
    func s(_ a: Double, _ b: Double, _ v: Int = 3) -> SleepSample { SleepSample(start: t + a * hour, end: t + b * hour, value: v) }
    XCTAssertNil(Sleep.pickMainSleepSession([]))
    var m = Sleep.pickMainSleepSession([s(0, 2), s(2, 4), s(4.5, 7)])!
    XCTAssertEqual([m.start, m.end], [t, t + 7 * hour])
    m = Sleep.pickMainSleepSession([s(0, 0.25), s(6, 13)])!
    XCTAssertEqual(m.start, t + 6 * hour)
    m = Sleep.pickMainSleepSession([s(0, 3), s(6, 9)])!
    XCTAssertEqual(m.start, t + 6 * hour)
    m = Sleep.pickMainSleepSession([s(0, 10, 1), s(12, 14)])!
    XCTAssertEqual(m.start, t + 12 * hour)
    m = Sleep.pickMainSleepSession([s(0, 1, 1), s(3, 10, 1)])!
    XCTAssertEqual(m.start, t + 3 * hour)
  }
}
