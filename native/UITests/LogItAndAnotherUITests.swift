//  Story 142: "Log it and another" stores the report and opens an empty one, no second shake.

import XCTest

final class LogItAndAnotherUITests: XCTestCase {
  func testTwoReportsInARow() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_SHAKE_AFTER"] = "4"
    app.launch()
    let report = app.navigationBars["Report a problem"]
    XCTAssertTrue(report.waitForExistence(timeout: 15), app.debugDescription)
    let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    field.typeText("first of two")
    app.buttons["report-log-it-and-another"].tap()

    // The second report: open again, with its field empty.
    let again = app.buttons["report-log-it-and-another"]
    XCTAssertTrue(again.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertFalse(again.isEnabled, "the fresh report starts empty")
    let second = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    XCTAssertTrue(second.waitForExistence(timeout: 5))
    second.typeText("second of two")
    app.buttons["report-log-it"].tap()
    // Done: no third report. That two were stored, each with its note and picture, is read from bugs.jsonl in the
    // simulator's container (story 142's Status).
    let gone = NSPredicate(format: "exists == false")
    expectation(for: gone, evaluatedWith: report)
    waitForExpectations(timeout: 10)
  }
}
