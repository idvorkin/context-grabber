//  Story 929 (context-grabber-4fww) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh
//  starts it): Larry holds on the board's picture with *waiting for more*, so the turn's clock stops, an ear and his
//  words start the note's line and the panel's chip, and his next row takes them away. What counts as a hold is
//  `WhiteboardLarryListeningTests`, on the host.

import XCTest

final class WhiteboardListeningUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testAnEarShowsWhileLarryWaitsForMoreAndGoesWhenHeAnswers() throws {
    let cockpit = try XCTUnwrap(
      ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], "run through scripts/native/test-whiteboard-ui.sh")
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    sleep(1)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)))
    try post(cockpit + "/fake/larry-ops", #"{"kind": "hold", "label": "Larry: hmm, go on"}"#)
    app.buttons["whiteboard-send"].tap()
    let ear = app.descendants(matching: .any)["whiteboard-larry-listening"]
    XCTAssertTrue(ear.appears(within: 20), app.debugDescription)
    XCTAssertEqual(ear.label, "Larry: hmm, go on")
    // A hold is his answer: the turn's clock is gone, and nothing offers to interrupt him.
    XCTAssertFalse(app.descendants(matching: .any)["whiteboard-note-state"].exists, "the clock stopped")
    XCTAssertFalse(app.buttons["whiteboard-larry-interrupt"].exists)
    let chevron = app.buttons["whiteboard-note-chevron"]
    XCTAssertTrue(chevron.appears(within: 5), app.debugDescription)
    let panel = app.textViews["whiteboard-conversation-text"]
    let chip = app.staticTexts["whiteboard-conversation-live-chip"]
    if !chip.exists { chevron.tap() }
    // Open or closed outlives the launch: the next test starts with it closed.
    addTeardownBlock {
      if panel.exists || chip.exists { chevron.tap() }
    }
    XCTAssertTrue(chip.appears(within: 5), app.debugDescription)
    XCTAssertEqual(chip.label, "Your board · Larry: hmm, go on")
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "Larry is listening: the ear on the note and the chip"
    picture.lifetime = .keepAlways
    add(picture)
    // His next row clears the hold.
    try post(cockpit + "/fake/larry-draws", #"{"count": 1}"#)
    expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: ear)
    waitForExpectations(timeout: 15)
    waitUntil(NSPredicate(format: "NOT (label CONTAINS 'go on')"), chip, timeout: 5)
  }

  private func post(_ url: String, _ body: String) throws {
    var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
    request.httpMethod = "POST"
    request.httpBody = Data(body.utf8)
    let done = expectation(description: "the fake Cockpit took it")
    URLSession.shared.dataTask(with: request) { _, response, _ in
      XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
      done.fulfill()
    }.resume()
    wait(for: [done], timeout: 5)
  }
}
