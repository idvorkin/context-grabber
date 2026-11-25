//  #342, story 254: a counter's last seven days in one sheet, each with − and +, saved together on Confirm.

import XCTest

@testable import ContextCore

final class CounterWeekTests: XCTestCase {
  private let today = "2026-10-18"

  private func strip() throws -> DailyStrip { try DailyStrip(db: SQLiteDatabase(path: ":memory:")) }

  func testTheWeekIsTodayThenTheSixDaysBeforeWithTheirCounts() throws {
    let s = try strip()
    try s.set(.balloons, day: "2026-10-17", value: 2)
    try s.set(.balloons, day: "2026-10-12", value: 1)
    try s.set(.balloons, day: "2026-10-11", value: 5)  // eight days ago: not in the week
    let week = try CounterWeek(.balloons, today: today, strip: s)
    XCTAssertEqual(
      week.days.map(\.day),
      ["2026-10-18", "2026-10-17", "2026-10-16", "2026-10-15", "2026-10-14", "2026-10-13", "2026-10-12"])
    XCTAssertEqual(week.days.map(\.count), [0, 2, 0, 0, 0, 0, 1])
    XCTAssertEqual(week.days.map(\.checked), [false, true, false, false, false, false, true])
    XCTAssertEqual(week.days[0].label, "today \u{00B7} Sun, Oct 18")
    XCTAssertEqual(week.days[1].label, "yesterday \u{00B7} Sat, Oct 17")
  }

  func testStepsStayInTheSheetUntilSavedAndOnlyChangedDaysAreSaved() throws {
    let s = try strip()
    try s.set(.balloons, day: "2026-10-17", value: 2)
    var week = try CounterWeek(.balloons, today: today, strip: s)
    week.step(1, by: 1)
    week.step(2, by: 1)
    week.step(3, by: 1)
    week.step(3, by: -1)  // back where it was: not a change
    XCTAssertEqual(try s.value(.balloons, day: "2026-10-17"), 2, "nothing is written before Confirm")
    XCTAssertEqual(week.days.map(\.checked).prefix(4), [false, true, true, false])
    XCTAssertEqual(
      week.changes,
      [
        CounterWeek.Change(day: "2026-10-17", daysAgo: 1, own: 3, step: 1, count: 3),
        CounterWeek.Change(day: "2026-10-16", daysAgo: 2, own: 1, step: 1, count: 1),
      ])
  }

  func testACountNeverGoesBelowZeroNorBelowWhatOtherDevicesCounted() throws {
    let s = try strip()
    try s.set(.magic, day: today, value: 1)
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: today, item: .magic, value: 2, updatedAt: 5)])
    var week = try CounterWeek(.magic, today: today, strip: s)
    XCTAssertEqual(week.days[0].count, 3, "the phone's 1 and the iPad's 2")
    for _ in 0..<5 { week.step(0, by: -1) }
    XCTAssertEqual(week.days[0].count, 2, "the iPad's two stay; only this device's own one comes off")
    week.step(4, by: -1)
    XCTAssertEqual(week.days[4].count, 0)
    XCTAssertEqual(week.changes, [CounterWeek.Change(day: today, daysAgo: 0, own: 0, step: -1, count: 2)])
  }

  // #1493, story 572: the week as a little graph, oldest on the left, today marked, following unconfirmed steps.
  func testTheGraphRunsOldestToTodayWithEachDaysInitialAndFollowsSteps() throws {
    let s = try strip()
    // Igor's week on 2026-11-25 (a Wednesday): 0, 0, 0, 1, 1, 3, 0 from Thursday.
    try s.set(.balloons, day: "2026-11-22", value: 1)
    try s.set(.balloons, day: "2026-11-23", value: 1)
    try s.set(.balloons, day: "2026-11-24", value: 3)
    var week = try CounterWeek(.balloons, today: "2026-11-25", strip: s)
    XCTAssertEqual(week.graph.map(\.count), [0, 0, 0, 1, 1, 3, 0])
    XCTAssertEqual(week.graph.map(\.initial), ["T", "F", "S", "S", "M", "T", "W"])
    XCTAssertEqual(week.graph.map(\.isToday), [false, false, false, false, false, false, true])
    XCTAssertEqual(week.graph.map(\.day).last, "2026-11-25")
    XCTAssertEqual(week.graphLabel, "Thu 0, Fri 0, Sat 0, Sun 1, Mon 1, Tue 3, Wed 0")
    week.step(0, by: 1)  // today, before Confirm
    week.step(1, by: -1)  // yesterday
    XCTAssertEqual(week.graph.map(\.count), [0, 0, 0, 1, 1, 2, 1], "the bars follow the sheet's counts at once")
  }

  // #1493, story 573: Cancel drops the sheet's steps, so the week opened again draws the saved bars.
  func testTheGraphOpenedAgainAfterCancelShowsTheSavedWeek() throws {
    let s = try strip()
    try s.set(.balloons, day: "2026-11-24", value: 3)
    var cancelled = try CounterWeek(.balloons, today: "2026-11-25", strip: s)
    cancelled.step(0, by: 1)
    XCTAssertEqual(cancelled.graph.last?.count, 1)
    let reopened = try CounterWeek(.balloons, today: "2026-11-25", strip: s)
    XCTAssertEqual(reopened.graph.map(\.count), [0, 0, 0, 0, 0, 3, 0])
  }

  func testTheGraphCountsOtherDevicesToo() throws {
    let s = try strip()
    try s.mergePeer("ipad", month: "2026-10", rows: [StripRow(day: today, item: .magic, value: 2, updatedAt: 5)])
    let week = try CounterWeek(.magic, today: today, strip: s)
    XCTAssertEqual(week.graph.last?.count, 2, "the bar is the row's number, the iPad's included")
  }
}
