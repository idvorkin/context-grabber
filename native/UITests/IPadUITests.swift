//  Story 150: on an iPad the home screen fills the screen either way up and each in-app launcher opens. Run it on
//  an iPad simulator; on a phone it skips. GRABBER_SHOTS=<dir> on the test's environment saves a picture of each.

import XCTest

final class IPadUITests: XCTestCase {
  func testHomeFillsTheIPadAndEachLauncherOpensInLandscape() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "an iPad simulator only")
    let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"]
    for id in ["home", "call", "today", "gym_timer", "breathe", "places", "cockpit"] {
      let app = XCUIApplication()
      app.launch()
      XCUIDevice.shared.orientation = .landscapeLeft
      let row = app.buttons["home-call"]
      XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
      if id == "home" {
        // An iPad app, not a phone-sized window: the row spans most of the screen's width.
        XCTAssertGreaterThan(row.frame.width, app.windows.firstMatch.frame.width * 0.8, app.debugDescription)
      } else {
        let launcher = app.buttons["home-\(id)"]
        for _ in 0..<4 where !launcher.isHittable { app.swipeUp() }
        launcher.tap()
        sleep(3)
        XCTAssertEqual(app.state, .runningForeground, "\(id) opened without leaving or crashing the app")
      }
      if let shots {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(id).png"))
      }
      XCUIDevice.shared.orientation = .portrait
      app.terminate()
    }
  }
}
