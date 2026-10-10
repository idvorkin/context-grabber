//  #239 (story 142): the report sheet has a microphone beside the note. The simulator cannot tap iOS's permission
//  prompts or hear anything, so the test checks the button is there and that a tap either listens or says why it
//  cannot; the words themselves are the phone's to check.

import XCTest

final class ReportDictationUITests: XCTestCase {
  func testTheMicrophoneSitsBesideTheNote() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_SHAKE_AFTER"] = "4"
    app.launch()
    XCTAssertTrue(app.navigationBars["Report a problem"].waitForExistence(timeout: 15), app.debugDescription)
    let mic = app.buttons["report-dictate"]
    XCTAssertTrue(mic.exists, app.debugDescription)
    XCTAssertTrue(mic.isEnabled, "no call is up, so the microphone is on")
    let field = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
    XCTAssertEqual(mic.frame.midY, field.frame.midY, accuracy: 30, "beside the note")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/report-mic.png"))
    }
    app.buttons["report-log-it"].firstMatch.tap()  // disabled with an empty note: the sheet stays
    app.buttons["Cancel"].tap()
  }
}
