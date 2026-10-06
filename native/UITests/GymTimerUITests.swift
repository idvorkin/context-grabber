//  Story 183 (#148): upright, a tap on the time pauses and resumes the workout, as it does on its side.

import XCTest

final class GymTimerUITests: XCTestCase {
  func testTapTheTimeUprightPausesAndResumes() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_TIMER"] = "30,10,3"
    app.launchEnvironment["GRABBER_TURN"] = "upright"
    app.launch()
    let face = app.descendants(matching: .any).matching(identifier: "timer-face").firstMatch
    XCTAssertTrue(face.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertTrue(app.buttons["STOP"].waitForExistence(timeout: 10), "the hook starts the workout")
    face.tap()
    XCTAssertTrue(app.buttons["RESUME"].waitForExistence(timeout: 5), "a tap on the time pauses")
    face.tap()
    XCTAssertTrue(app.buttons["STOP"].waitForExistence(timeout: 5), "a second tap resumes")
  }
}
