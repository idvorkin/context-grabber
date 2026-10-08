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
      // Today is the card across the top (story 151); the launchers below it are half-width tiles and rows.
      let today = app.buttons["home-today-card"]
      XCTAssertTrue(today.waitForExistence(timeout: 15), app.debugDescription)
      if id == "home" {
        // An iPad app, not a phone-sized window: the Today card spans most of the screen's width (the screen, not the
        // app's window, which shrinks with a phone-only app), once the turn to landscape has settled.
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard").windows.firstMatch.frame
        let wide = max(screen.width, screen.height) * 0.8
        for _ in 0..<10 where today.frame.width <= wide { usleep(300_000) }
        XCTAssertGreaterThan(today.frame.width, wide, "Today \(today.frame) on a \(screen) screen")
      } else {
        let launcher = app.buttons[id == "today" ? "home-today-card" : "home-\(id)"]
        for _ in 0..<4 where !launcher.isHittable { app.swipeUp() }
        launcher.tap()
        // The journey's own screen, not just an app still in front: a launcher that did nothing would pass that.
        let screen = destination(id, in: app)
        XCTAssertTrue(screen.waitForExistence(timeout: 15), "\(id) opened its screen: \(app.debugDescription)")
        // On top, once its push or cover has finished arriving. Today's first visit on a fresh simulator puts the
        // system's Health Access sheet over it; that sheet is the screen working, and only a person can answer it.
        let onTop = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: screen)
        let arrived = XCTWaiter().wait(for: [onTop], timeout: 5) == .completed
        XCTAssertTrue(
          arrived || (id == "today" && app.navigationBars["Health Access"].exists),
          "\(id)'s screen is on top in landscape")
        XCTAssertEqual(app.state, .runningForeground, "\(id) opened without leaving or crashing the app")
      }
      if let shots {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(id).png"))
      }
      XCUIDevice.shared.orientation = .portrait
      app.terminate()
    }
  }

  /// What each journey shows once it has opened (#203).
  private func destination(_ id: String, in app: XCUIApplication) -> XCUIElement {
    switch id {
    case "call": return app.buttons["call-larry"]
    case "today": return app.buttons["card-sleep"]  // a card is there with or without Health data
    case "gym_timer": return app.buttons["timer-settings"]
    case "breathe": return app.buttons["breathe-begin"]
    case "places": return app.navigationBars["Places"]
    case "cockpit": return app.buttons["cockpit-done"]
    default: return app.descendants(matching: .any)["no-destination-for-\(id)"]
    }
  }
}
