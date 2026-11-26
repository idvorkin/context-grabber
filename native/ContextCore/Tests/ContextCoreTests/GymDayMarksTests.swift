//  #1503, story 570: what was done on each gym day, as icons under the two-week sheet's tiles.

import XCTest

@testable import ContextCore

final class GymDayMarksTests: XCTestCase {
  private func workout(_ kind: String) -> WorkoutEntry {
    WorkoutEntry(activityType: kind, durationMinutes: 30, energyBurned: nil, distanceKm: nil)
  }

  private func timer(_ day: String, id: Int64 = 1) -> ActivityEntry {
    ActivityEntry(id: id, kind: .gymTimer, name: "30 SEC", seconds: 600, finishedAt: 0, dateKey: day)
  }

  func testStrengthFirstThenTheTimerThenTheRestEachKindOnce() {
    let marks = DailyStrip.gymMarks(
      timer: [
        timer("2026-11-20"), timer("2026-11-20", id: 2),
        ActivityEntry(id: 3, kind: .breathing, name: "Box", seconds: 60, finishedAt: 0, dateKey: "2026-11-20"),
      ],
      workoutsByDay: [
        "2026-11-20": [workout("Walking"), workout("Functional Strength"), workout("Walking")],
        "2026-11-21": [workout("Strength Training"), workout("Strength Training")],
      ])
    XCTAssertEqual(
      marks["2026-11-20"], [.workout("Functional Strength"), .timer, .workout("Walking")],
      "strength first, then the timer once, then the walk once; breathing is not gym")
    XCTAssertEqual(marks["2026-11-21"], [.workout("Strength Training")], "a kind done twice shows once")
    XCTAssertNil(marks["2026-11-22"], "a day with nothing recorded has no marks")
  }

  func testThreeFitAndMoreShowTwoAndACount() {
    let three: [GymDayMark] = [.workout("Running"), .timer, .workout("Cycling")]
    XCTAssertEqual(DailyStrip.gymIcons(three), GymDayIcons(shown: three, more: 0))
    let five: [GymDayMark] = three + [.workout("Hiking"), .workout("Rowing")]
    XCTAssertEqual(
      DailyStrip.gymIcons(five), GymDayIcons(shown: [.workout("Running"), .timer], more: 3),
      "more than three: the first two and +3")
    XCTAssertEqual(DailyStrip.gymIcons([]), GymDayIcons(shown: [], more: 0))
  }

  func testEachKindHasASymbolAndAName() {
    XCTAssertEqual(GymDayMark.timer.symbol, "stopwatch")
    XCTAssertEqual(GymDayMark.timer.name, "Gym Timer")
    XCTAssertEqual(GymDayMark.workout("Strength Training").symbol, "figure.strengthtraining.traditional")
    XCTAssertEqual(GymDayMark.workout("Functional Strength").symbol, "figure.strengthtraining.functional")
    XCTAssertEqual(GymDayMark.workout("Running").symbol, "figure.run")
    XCTAssertEqual(GymDayMark.workout("Walking").symbol, "figure.walk")
    XCTAssertEqual(GymDayMark.workout("Curling").symbol, "figure.mixed.cardio", "any other kind: a generic figure")
    XCTAssertEqual(GymDayMark.workout("Curling").name, "Curling")
  }

  func testTheFortnightCarriesEachDaysMarksIntoItsLabel() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let grid = CheckFortnight(
      .gym, today: "2026-11-21", marked: ["2026-11-19"], automatic: ["2026-11-20"],
      marks: ["2026-11-20": [.timer, .workout("Functional Strength")]], calendar: calendar)
    let day = grid.days[12]
    XCTAssertEqual(day.day, "2026-11-20")
    XCTAssertEqual(day.marks, [.timer, .workout("Functional Strength")])
    XCTAssertEqual(day.accessibilityLabel, "Friday November 20, done, Gym Timer and Functional Strength")
    XCTAssertEqual(grid.days[11].marks, [], "a day marked only by a tap shows no icons")
    XCTAssertEqual(grid.days[11].accessibilityLabel, "Thursday November 19, done")
  }
}
