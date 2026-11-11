//  Story 677 (#683): on a Mac, Enter or Command+Enter sends and Shift+Enter starts a new line. Runs only against the
//  Mac build, signed so the runner can load it (docs/TESTING.md): a simulator has no such keys to press.

#if targetEnvironment(macCatalyst)
  import XCTest

  final class MacKeysUITests: XCTestCase {
    func testEnterAndCommandEnterSendAndShiftEnterDoesNot() throws {
      let app = XCUIApplication.forTests()
      // A Cockpit nobody answers on: the message waits in a test launch's own outbox and nothing reaches Larry (story 588).
      app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
      app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
      app.launch()
      let byPlaceholder = NSPredicate(format: "placeholderValue == %@ OR value == %@", "Message Larry", "Message Larry")
      let field = app.descendants(matching: .any).matching(byPlaceholder).firstMatch
      XCTAssertTrue(field.waitForExistence(timeout: 20), app.debugDescription)
      field.click()
      let send = app.buttons["Send"]
      let run = UUID().uuidString.prefix(6)

      // Nothing to send: no blank message, and the bar stays usable.
      let before = app.staticTexts.count
      field.typeKey(.return, modifierFlags: [])
      sleep(1)
      XCTAssertEqual(app.staticTexts.count, before, "Enter on an empty bar sent something")

      field.typeText("enter \(run)")
      field.typeKey(.return, modifierFlags: [])
      XCTAssertTrue(app.staticTexts["enter \(run)"].waitForExistence(timeout: 5), app.debugDescription)
      XCTAssertFalse(send.isEnabled, "the bar empties after Enter")

      field.typeText("command \(run)")
      field.typeKey(.return, modifierFlags: .command)
      XCTAssertTrue(app.staticTexts["command \(run)"].waitForExistence(timeout: 5), app.debugDescription)
      XCTAssertFalse(send.isEnabled, "the bar empties after Command+Enter")

      field.typeText("one")
      field.typeKey(.return, modifierFlags: .shift)
      field.typeText("two")
      XCTAssertTrue(send.isEnabled, "Shift+Enter left the words in the bar")
      XCTAssertEqual(field.value as? String, "one\ntwo")
    }
  }
#endif
