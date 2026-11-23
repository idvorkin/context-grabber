//  Story 1127 (#1138) on the simulator, against the fake Cockpit (scripts/native/test-whiteboard-ui.sh starts it): a
//  link in Larry's reply reads as a chip in the board's open conversation, never its tailnet address, and a finger tap
//  on it opens it. How a link reads is `ChatBubbleLinksTests`, on the host.

import XCTest

final class WhiteboardLinkChipUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testALinkInLarrysReplyIsAChipAFingerOpens() throws {
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
    try post(cockpit + "/fake/larry-ops", #"{"kind": "link_reply"}"#)
    app.buttons["whiteboard-send"].tap()
    let chevron = app.buttons["whiteboard-note-chevron"]
    XCTAssertTrue(chevron.appears(within: 15), app.debugDescription)
    let panel = app.textViews["whiteboard-conversation-text"]
    if !panel.exists { chevron.tap() }
    // Open or closed outlives the launch: the next test starts with it closed.
    addTeardownBlock {
      if panel.exists { chevron.tap() }
    }
    XCTAssertTrue(panel.appears(within: 5), app.debugDescription)
    waitUntil(NSPredicate(format: "value CONTAINS %@", "Larry: Lavish"), panel, timeout: 15)
    let text = panel.value as? String ?? ""
    XCTAssertFalse(text.contains("squeaker"), "the tailnet address never shows: \(text)")
    let chip = panel.links.matching(NSPredicate(format: "label CONTAINS %@", "Larry: Lavish")).firstMatch
    XCTAssertTrue(chip.appears(within: 5), app.debugDescription)
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "the Lavish chip in the board's conversation"
    picture.lifetime = .keepAlways
    add(picture)
    chip.tap()
    // The link opens outside the app (Safari), which sends the app to the background.
    XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "a tap on the chip opens its page")
    app.activate()
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
