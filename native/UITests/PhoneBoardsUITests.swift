//  Story 746 on an iPhone simulator: the boards are for looking. The list has no + New board, and a board this phone
//  drew on paper opens look-only, the bar saying to draw on the iPad,
//  with Send to Larry still there. Every other whiteboard class runs on an iPad
//  simulator (the ladder's whiteboard step), where drawing is.

import XCTest

final class PhoneBoardsUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testAPhoneStartsNoBoardAndOpensItsOwnLookOnly() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "an iPhone simulator only")
    // This phone's own board on paper, on a fresh id so runs on one simulator don't meet each other's boards.
    let id = "phone-\(UUID().uuidString.lowercased())"
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = id
    app.launch()
    XCTAssertTrue(app.buttons["whiteboard-done"].appears(within: 20), app.debugDescription)
    XCTAssertFalse(app.buttons["whiteboard-new"].exists, "an iPhone starts no board")

    app.open(try XCTUnwrap(URL(string: "grabbernative://whiteboard?board=\(id)")))
    let note = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "Look only on iPhone: draw on the iPad"))
    XCTAssertTrue(note.firstMatch.appears(within: 10), app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-send"].exists, "Send to Larry stays: the phone can talk about a board")
    XCTAssertFalse(app.buttons["whiteboard-board"].exists, "no Board menu")
    XCTAssertFalse(app.buttons["whiteboard-ghosts"].exists, "no ghosts")
  }
}
