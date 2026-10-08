// The large widget's role of the day (#221).
import ContextCore
import XCTest

final class EulogyRolesTests: XCTestCase {
  private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
  }()

  func testOneRolePerLocalDay() {
    let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 0, minute: 1))!
    let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 23, minute: 59))!
    let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 0, minute: 1))!
    XCTAssertEqual(EulogyRoles.ofDay(morning, calendar: calendar), EulogyRoles.ofDay(night, calendar: calendar))
    XCTAssertNotEqual(EulogyRoles.ofDay(night, calendar: calendar), EulogyRoles.ofDay(tomorrow, calendar: calendar))
    XCTAssertEqual(EulogyRoles.nextChange(after: night, calendar: calendar),
                   calendar.date(from: DateComponents(year: 2026, month: 10, day: 9))!)
  }

  func testEachRoleOnceInAnyElevenDays() {
    let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!  // across a DST change
    for offset in 0..<30 {
      let days = (0..<11).map { calendar.date(byAdding: .day, value: offset + $0, to: start)! }
      XCTAssertEqual(Set(days.map { EulogyRoles.ofDay($0, calendar: calendar) }).count, 11, "from day \(offset)")
    }
  }

  func testInEulogyOrder() {
    let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12))!
    let today = EulogyRoles.names.firstIndex(of: EulogyRoles.ofDay(day, calendar: calendar))!
    let next = EulogyRoles.ofDay(calendar.date(byAdding: .day, value: 1, to: day)!, calendar: calendar)
    XCTAssertEqual(next, EulogyRoles.names[(today + 1) % 11])
  }
}
