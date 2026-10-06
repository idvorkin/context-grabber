//  Story 135 (#167): links open the app where they say, cold and warm, and the Links screen copies them.
//  The links go through iOS (`XCUIApplication.open`), as a Shortcut's *Open URL* would.

import XCTest

final class LinksUITests: XCTestCase {
  private func shot(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  /// Through SpringBoard, as Shortcuts' *Open URL* does, into the app that is already running: iOS asks "Open in
  /// Grabber Native?" first. (`XCUIApplication.open` relaunches the app, which is the cold case.)
  private func openWarm(_ link: String) {
    XCUIDevice.shared.system.open(URL(string: link)!)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let open = springboard.buttons["Open"]
    if open.waitForExistence(timeout: 5) { open.tap() }
  }

  func testTimerAndBreatheLinksStartColdAndWarm() throws {
    let app = XCUIApplication()
    // Cold: the link launches the app.
    app.open(URL(string: "grabbernative://timer?preset=10,10,2")!)
    XCTAssertTrue(app.buttons["STOP"].waitForExistence(timeout: 20), "the link starts the workout")
    shot(app, "timer-from-link")

    // Warm, over the running timer: the timer goes and the breathing begins.
    openWarm("grabbernative://breathe?breath=5&minutes=2")
    XCTAssertTrue(app.descendants(matching: .any)["breathe-pause"].waitForExistence(timeout: 10), "the session begins")
    XCTAssertFalse(app.buttons["STOP"].exists, "the timer is gone")
    shot(app, "breathe-from-link")

    // Not a route: home, no error.
    openWarm("grabbernative://nowhere")
    XCTAssertTrue(app.buttons["home-call"].waitForExistence(timeout: 10), "an unknown link lands on home")

    // A preset it does not know: the timer, ready.
    openWarm("grabbernative://timer?preset=9min")
    XCTAssertTrue(app.buttons["START"].waitForExistence(timeout: 10), "the timer opens ready")
    XCTAssertFalse(app.buttons["STOP"].exists)
  }

  func testTheLinksScreenCopiesALink() throws {
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-links"]
    for _ in 0..<5 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
    row.tap()
    let copy = app.buttons["copy-grabbernative://timer?preset=1min"]
    XCTAssertTrue(copy.waitForExistence(timeout: 5), app.debugDescription)
    shot(app, "links-screen")
    copy.tap()
    XCTAssertEqual(copy.label, "Copied")
  }
}
