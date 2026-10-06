//  Story 037 (#139): finished activities are recorded and ride along in the summary to Larry.

import ContextCore
import XCTest

final class ActivityLogTests: XCTestCase {
  var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
  }()

  func makeLog() throws -> ActivityLog {
    try ActivityLog(db: SQLiteDatabase(path: ":memory:"), calendar: calendar)
  }

  func testRecordsNewestFirstWithTheLocalDay() throws {
    let log = try makeLog()
    // 2026-10-05 07:30 and 23:30 Pacific; the second is already the 6th in UTC.
    let morning = Date(timeIntervalSince1970: 1_791_210_600)
    let night = morning.addingTimeInterval(16 * 3600)
    try log.log(.gymTimer, name: "30 SEC · 6 rounds", seconds: 210, at: morning)
    try log.log(.breathing, name: "Box breathing · 8 s · 9 cycles", seconds: 288, at: night)
    let entries = try log.entries(since: morning.addingTimeInterval(-1))
    XCTAssertEqual(entries.map(\.kind), [.breathing, .gymTimer])
    XCTAssertEqual(entries.map(\.dateKey), ["2026-10-05", "2026-10-05"])
    XCTAssertEqual(try log.entries(since: night).count, 1)
  }

  func testExportShape() throws {
    let log = try makeLog()
    let at = Date(timeIntervalSince1970: 1_791_210_600)
    let e = try log.log(.breathing, name: "Box breathing · 8 s · 9 cycles", seconds: 288, at: at)
    XCTAssertEqual(
      e.exportJSON.stringify(),
      #"{"kind":"breathing","name":"Box breathing · 8 s · 9 cycles","minutes":4.8,"timestamp":"2026-10-05T14:30:00.000Z","date":"2026-10-05"}"#)
  }

  func testNames() {
    let thirty = TimerProfile.presets[0].profile
    XCTAssertEqual(ActivityLog.gymName(label: "30 SEC", profile: thirty, custom: false), "30 SEC · 6 rounds")
    // 5 s count-in, six 30 s rounds, five 5 s rests.
    XCTAssertEqual(ActivityLog.gymSeconds(thirty), 5 + 180 + 25)
    let custom = TimerProfile(name: "custom", workTime: 45, restTime: 15, rounds: 1, prepTime: 5)
    XCTAssertEqual(ActivityLog.gymName(label: "CUSTOM", profile: custom, custom: true), "CUSTOM 0:45 / 0:15 · 1 round")
    XCTAssertEqual(ActivityLog.breathName(BreathPlan(breathSeconds: 8, sessionMinutes: 5)), "Box breathing · 8 s · 9 cycles")
  }
}
