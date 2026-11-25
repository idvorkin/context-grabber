//  Story 1607 (#1365) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): the + opens a
//  new chat again after the last one landed and was left by Back, by Home and back, by another thread, and by two quick
//  Backs to Home. Animated, as Igor sees it. What the + logs when it opens nothing is the Mac's to show.

import XCTest

final class ChatNewChatAgainUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func field(_ app: XCUIApplication) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Message Larry")).firstMatch
  }

  private func back(_ app: XCUIApplication) {
    app.navigationBars.buttons.element(boundBy: 0).tap()
  }

  private func startOne(_ app: XCUIApplication, _ text: String) {
    let plus = app.buttons["inbox-add"]
    XCTAssertTrue(plus.appears(within: 20), "the + for \(text): \(app.debugDescription)")
    plus.tap()
    XCTAssertTrue(app.navigationBars["New chat"].appears(within: 5), "New chat for \(text): \(app.debugDescription)")
    let field = field(app)
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    field.tap()
    field.typeText(text)
    app.buttons["Send"].tap()
    XCTAssertTrue(app.navigationBars[text].appears(within: 5), app.debugDescription)
    let waiting = app.staticTexts["The next message goes once your first one reaches Larry."]
    let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: waiting)
    wait(for: [gone], timeout: 20)
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.appears(within: 2) { allow.tap() }
  }

  func testThePlusOpensANewChatAgain() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let stamp = Int(Date().timeIntervalSince1970)
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_INBOX"] = "open"
    app.launch()

    // A: land, Back to the list, + again.
    startOne(app, "Again A \(stamp)")
    back(app)
    startOne(app, "Again B \(stamp)")
    // B: land, Back, Back to Home, Chat, +.
    back(app)
    back(app)
    let tile = app.buttons["home-inbox"]
    XCTAssertTrue(tile.appears(within: 10), app.debugDescription)
    tile.tap()
    startOne(app, "Again C \(stamp)")
    // C: land, open another thread from the list, Back, +.
    back(app)
    // Any other thread will do, and the one nearest the top is the one on screen: a fixed thread id was pushed out of
    // view as the fake Cockpit's list grew (bead context-grabber-6d1b, .629 never appeared under eight newer rows).
    let other = NSPredicate(
      format: "identifier BEGINSWITH %@ AND NOT (label CONTAINS %@)", "chat-thread-igor2-88g.", "Again")
    let row = app.buttons.matching(other).firstMatch
    XCTAssertTrue(row.appears(within: 10), app.debugDescription)
    row.tap()
    Thread.sleep(forTimeInterval: 2)
    back(app)
    startOne(app, "Again D \(stamp)")
    // D: straight from a landed new chat to Home in one go: Back twice fast.
    back(app)
    back(app)
    XCTAssertTrue(tile.appears(within: 10), app.debugDescription)
    tile.tap()
    startOne(app, "Again E \(stamp)")
  }
}
