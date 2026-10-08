//  #220: the Workout Supermix row hands Igor's "Play Workout Supermix" shortcut to Shortcuts. The simulator has no
//  such shortcut, so this checks only that Shortcuts comes to the front; YouTube Music playing is the phone's.

import XCTest

final class WorkoutSupermixUITests: XCTestCase {
  func testTheRowRunsTheShortcut() throws {
    let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-workout_supermix"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    if !row.isHittable { app.swipeUp() }
    row.tap()
    XCTAssertTrue(shortcuts.wait(for: .runningForeground, timeout: 15), "Shortcuts came to the front")
  }
}
