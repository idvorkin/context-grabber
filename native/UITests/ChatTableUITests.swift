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

    let bubble = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier == 'chat-larry' AND label BEGINSWITH %@", "Here's how they compare:")
    ).firstMatch
    XCTAssertTrue(bubble.appears(within: 20), app.debugDescription)
    // The grid reads row by row, each cell after its heading, between the words around it.
    XCTAssertTrue(bubble.label.contains("Pro 14, Weight 1.6 kg, Battery 22 h, Price $1,999"), bubble.label)
    XCTAssertTrue(bubble.label.hasSuffix("Want the cheapest?"), bubble.label)
    XCTAssertFalse(bubble.label.contains("|"), "no pipes or dashes as written: \(bubble.label)")
    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    shot.name = "story 747: the laptop table"
    shot.lifetime = .keepAlways
    add(shot)
  }
}
