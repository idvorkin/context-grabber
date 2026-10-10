//  #232 (story 148): every change in What's new opens its story, in Safari.

import XCTest

final class WhatsNewStoryLinkUITests: XCTestCase {
  func testAChangeOpensItsStory() throws {
    let app = XCUIApplication()
    app.launch()
    // Through the cog, which always has it: the home row may have been dismissed already.
    let cog = app.buttons["home-settings"]
    XCTAssertTrue(cog.waitForExistence(timeout: 15), app.debugDescription)
    cog.tap()
    let inCog = app.buttons["home-settings-whats-new"]
    for _ in 0..<5 where !inCog.isHittable { app.swipeUp() }
    inCog.tap()
    XCTAssertTrue(app.navigationBars["What's new"].waitForExistence(timeout: 5), app.debugDescription)
    let change = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'whats-new-story-'")).firstMatch
    XCTAssertTrue(change.waitForExistence(timeout: 5), "a change is a link: \(app.debugDescription)")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/whats-new-links.png"))
    }
    change.tap()
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "the story opens in Safari")
    app.activate()
  }
}
