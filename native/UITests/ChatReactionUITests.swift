//  Stories 445-448 (#629) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it). Its
//  Larry repeats what he hears, so his replies show the exact text each reaction sent. One walkthrough in a thread of
//  its own: the fake Cockpit outlives a test, and which message is the newest depends on what came before.

import XCTest

final class ChatReactionUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private let larrysWords = "Shall we ship it?"

  private func element(_ app: XCUIApplication, _ format: String, _ words: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: format, words)).firstMatch
  }

  private func holdLarrys(_ app: XCUIApplication) {
    let bubble = element(app, "label BEGINSWITH %@", larrysWords)
    XCTAssertTrue(bubble.waitForExistence(timeout: 20), app.debugDescription)
    bubble.press(forDuration: 1.2)
  }

  func testHoldingAMessageAnswersAndQuotes() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.629"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()

    // Story 445: Larry's offers all four.
    holdLarrys(app)
    let yes = app.buttons["Yes"].firstMatch
    XCTAssertTrue(yes.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(app.buttons["No"].firstMatch.exists)
    XCTAssertTrue(app.buttons["Quote in reply"].firstMatch.exists)
    XCTAssertTrue(app.buttons["Copy"].firstMatch.exists)

    // Story 446: the newest gets the bare word.
    yes.tap()
    XCTAssertTrue(
      element(app, "label CONTAINS %@", "Larry heard: Yes").waitForExistence(timeout: 15), app.debugDescription)

    // Story 447: now it is older, so the answer carries its quote.
    holdLarrys(app)
    app.buttons["No"].firstMatch.tap()
    XCTAssertTrue(
      element(app, "label CONTAINS %@", "Larry heard: > \(larrysWords)").waitForExistence(timeout: 15),
      app.debugDescription)

    // Story 445: my own offers no answer to myself.
    let mine = element(app, "label BEGINSWITH %@", "Yes")
    XCTAssertTrue(mine.waitForExistence(timeout: 5), app.debugDescription)
    mine.press(forDuration: 1.2)
    let quote = app.buttons["Quote in reply"].firstMatch
    XCTAssertTrue(quote.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Yes"].firstMatch.exists, "no Yes on my own message")

    // Story 448: the quote lands in the bar and goes nowhere.
    quote.tap()
    XCTAssertTrue(element(app, "value BEGINSWITH %@", "> Yes").waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard is up for the reply")
    XCTAssertFalse(
      element(app, "label CONTAINS %@", "Larry heard: > Yes").waitForExistence(timeout: 3), "nothing sent")
  }
}
