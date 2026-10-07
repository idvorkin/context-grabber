//  Story 137 (#177): the home screen's Eulogy song, Eulogy and Recent leave for the song and the blog.

import XCTest

final class EulogyUITests: XCTestCase {
  let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

  func testEachLauncherLeavesTheApp() throws {
    for id in ["eulogy_song", "eulogy", "recent"] {
      let app = XCUIApplication()
      app.launch()
      let row = app.buttons["home-\(id)"]
      for _ in 0..<4 where !row.isHittable { app.swipeUp() }
      XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
      row.tap()
      // The browser (or Suno's app) comes forward; the simulator has no Suno app, so it is Safari.
      XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "\(id) opened the browser")
      safari.terminate()
    }
  }
}
