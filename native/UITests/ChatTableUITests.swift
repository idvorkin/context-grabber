//  Story 747 (#817) on the simulator, against the fake Cockpit (scripts/native/test-chat-ui.sh starts it): Larry's
//  laptop comparison reads as a grid, with the words around it, and no pipes or dashes.

import XCTest

final class ChatTableUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testATableInLarrysMessageIsAGrid() throws {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.817"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()

    let table = app.descendants(matching: .any)["chat-table"].firstMatch
    XCTAssertTrue(table.appears(within: 20), app.debugDescription)
    for cell in ["Battery", "Pro 14", "$1,299"] {
      XCTAssertTrue(table.staticTexts[cell].exists, "\(cell) in the grid: \(table.debugDescription)")
    }
    let words = { (text: String) in app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
    XCTAssertTrue(words("Here's how they compare:").exists, app.debugDescription)
    XCTAssertTrue(words("Want the cheapest?").exists, app.debugDescription)
    XCTAssertFalse(words("|---").exists, "no dashes row as written")
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = "story 747: the laptop table"
    shot.lifetime = .keepAlways
    add(shot)
  }
}
