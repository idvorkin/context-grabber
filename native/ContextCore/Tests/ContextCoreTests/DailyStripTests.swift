//  #236, #238: the daily strip's values by local day, and gym days from a tap, the timer or Health.

import XCTest

@testable import ContextCore

final class DailyStripTests: XCTestCase {
  func testValuesAreKeptPerDayAndNeverBelowZero() throws {
    let strip = try DailyStrip(db: SQLiteDatabase(path: ":memory:"))
    XCTAssertEqual(try strip.value(.balloons, day: "2026-10-10"), 0)
    try strip.set(.balloons, day: "2026-10-10", value: 3)
    try strip.set(.balloons, day: "2026-10-09", value: 1)
    try strip.set(.magic, day: "2026-10-10", value: -2)
    XCTAssertEqual(try strip.value(.balloons, day: "2026-10-10"), 3)
    XCTAssertEqual(try strip.value(.balloons, day: "2026-10-09"), 1, "yesterday is kept")
    XCTAssertEqual(try strip.value(.magic, day: "2026-10-10"), 0)
    try strip.set(.gym, day: "2026-10-01", value: 1)
    try strip.set(.gym, day: "2026-10-02", value: 0)
    XCTAssertEqual(try strip.days(.gym), ["2026-10-01"])
  }

  func testGymDaysComeFromATapTheTimerOrAStrengthWorkout() {
    let timer = [
      ActivityEntry(id: 1, kind: .gymTimer, name: "30 SEC", seconds: 600, finishedAt: 0, dateKey: "2026-10-05"),
      ActivityEntry(id: 2, kind: .breathing, name: "Box", seconds: 60, finishedAt: 0, dateKey: "2026-10-06"),
    ]
    let workouts: [String: [WorkoutEntry]] = [
      "2026-10-07": [WorkoutEntry(activityType: "Functional Strength", durationMinutes: 40, energyBurned: nil, distanceKm: nil)],
      "2026-10-08": [WorkoutEntry(activityType: "Walking", durationMinutes: 40, energyBurned: nil, distanceKm: nil)],
    ]
    XCTAssertEqual(
      DailyStrip.gymDays(tapped: ["2026-10-01"], timer: timer, workoutsByDay: workouts),
      ["2026-10-01", "2026-10-05", "2026-10-07"], "a breathing session and a walk are not gym")
  }

  func testDaysSinceGym() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let days: Set<String> = ["2026-10-07", "2026-09-30"]
    XCTAssertEqual(DailyStrip.daysSince(days, today: "2026-10-10", calendar: calendar), 3)
    XCTAssertEqual(DailyStrip.daysSince(days, today: "2026-10-07", calendar: calendar), 0)
    XCTAssertEqual(DailyStrip.daysSince(days, today: "2026-10-01", calendar: calendar), 1, "a later day does not count")
    XCTAssertNil(DailyStrip.daysSince([], today: "2026-10-10", calendar: calendar), "never")
    // Across the clocks going back (Nov 1 2026 in Los Angeles) a day is still a day.
    XCTAssertEqual(DailyStrip.daysSince(["2026-10-31"], today: "2026-11-02", calendar: calendar), 2)
  }

  // #257: meditation counts from a breathing session today, or the last grab's mindful minutes if it was today.
  func testMeditationComesFromBreathingOrHealthToday() {
    let breath = ActivityEntry(id: 1, kind: .breathing, name: "Box", seconds: 240, finishedAt: 0, dateKey: "2026-10-10")
    let gym = ActivityEntry(id: 2, kind: .gymTimer, name: "30 SEC", seconds: 600, finishedAt: 0, dateKey: "2026-10-10")
    XCTAssertEqual(
      DailyStrip.meditationSource(today: "2026-10-10", activity: [gym, breath], healthMinutes: nil, healthDay: nil),
      "breathing")
    XCTAssertEqual(
      DailyStrip.meditationSource(today: "2026-10-10", activity: [gym], healthMinutes: 12, healthDay: "2026-10-10"),
      "health")
    XCTAssertNil(
      DailyStrip.meditationSource(today: "2026-10-11", activity: [breath], healthMinutes: 12, healthDay: "2026-10-10"),
      "yesterday's breathing and yesterday's grab do not count today")
    XCTAssertNil(
      DailyStrip.meditationSource(today: "2026-10-10", activity: [gym], healthMinutes: 0, healthDay: "2026-10-10"),
      "zero minutes is not a meditation")
  }
}
