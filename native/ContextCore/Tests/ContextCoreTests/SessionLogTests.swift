import XCTest

@testable import ContextCore

final class SessionLogLineTests: XCTestCase {
  private func decode(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func testALineCarriesItsTypeItsTimeAndItsFields() throws {
    let line = try decode(SessionLogLine.encode(type: "session_start", t: 12, fields: ["sha": "abc1234", "n": 3]))
    XCTAssertEqual(line["type"] as? String, "session_start")
    XCTAssertEqual(line["t"] as? Int, 12)
    XCTAssertEqual(line["sha"] as? String, "abc1234")
    XCTAssertEqual(line["n"] as? Int, 3)
  }

  func testALineIsOneLine() {
    let data = SessionLogLine.encode(type: "bug_report", t: 0, fields: ["note": "first\nsecond"])
    XCTAssertFalse(data.contains(0x0A))
  }

  func testAFieldCannotReplaceTheLinesOwnTypeOrTime() throws {
    let line = try decode(SessionLogLine.encode(type: "ui", t: 5, fields: ["type": "other", "t": 99]))
    XCTAssertEqual(line["type"] as? String, "ui")
    XCTAssertEqual(line["t"] as? Int, 5)
  }

  func testNumbersStayNumbersRoundedAndNonFiniteOnesAreMinusOne() throws {
    let line = try decode(
      SessionLogLine.encode(
        type: "x", t: 0,
        fields: ["ms": 12.3456, "nan": Double.nan, "f": Float(0.5), "nested": ["inf": Double.infinity], "list": [1.006]]))
    XCTAssertEqual(line["ms"] as? Double, 12.35)
    XCTAssertEqual(line["nan"] as? Double, -1)
    XCTAssertEqual(line["f"] as? Double, 0.5)
    XCTAssertEqual((line["nested"] as? [String: Any])?["inf"] as? Double, -1)
    XCTAssertEqual((line["list"] as? [Double])?.first, 1.01)
  }

  func testAValueJSONCannotCarryBecomesAnErrorLineNamingTheEvent() throws {
    let line = try decode(SessionLogLine.encode(type: "route", t: 7, fields: ["when": Date()]))
    XCTAssertEqual(line["type"] as? String, "error")
    XCTAssertEqual(line["where"] as? String, "log")
    XCTAssertEqual(line["event"] as? String, "route")
    XCTAssertEqual(line["t"] as? Int, 7)
  }
}
