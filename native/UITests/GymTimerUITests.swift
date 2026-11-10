//  Story 183 (#148): upright, a tap on the time pauses and resumes the workout, as it does on its side.
//  Story 188 (#791), a workout surviving leaving the timer, is a host test now (TimerSessionTests).

import XCTest

final class GymTimerUITests: XCTestCase {
  func testTapTheTimeUprightPausesAndResumes() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_TIMER"] = "30,10,3"
    app.launchEnvironment["GRABBER_TURN"] = "upright"
    app.launch()
    let face = app.descendants(matching: .any).matching(identifier: "timer-face").firstMatch
    XCTAssertTrue(face.appears(within: 15), app.debugDescription)
    XCTAssertTrue(app.buttons["STOP"].appears(within: 10), "the hook starts the workout")
    face.tap()
    XCTAssertTrue(app.buttons["RESUME"].appears(within: 5), "a tap on the time pauses")
    face.tap()
    XCTAssertTrue(app.buttons["STOP"].appears(within: 5), "a second tap resumes")
  }
}
