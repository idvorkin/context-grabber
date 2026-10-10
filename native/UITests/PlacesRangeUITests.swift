//  #252 (story 049): the map's Today · 7 days switch picks today's path or the week's, and is remembered after a
//  relaunch. Needs the real fixture in Documents, as PlacesUnnamedUITests does. Screenshots stay local: they show
//  places.

import XCTest

final class PlacesRangeUITests: XCTestCase {
  func testTheSwitchIsRememberedAndGoesBack() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_IMPORT_DB"] = "import-fixture.db,recent"
    app.launchEnvironment["GRABBER_PLACES"] = "open"
    app.launch()
    let week = app.buttons["places-range-7"], today = app.buttons["places-range-1"]
    XCTAssertTrue(week.waitForExistence(timeout: 30), app.debugDescription)
    today.tap()  // whatever an earlier run left
    XCTAssertTrue(today.isSelected)
    week.tap()
    XCTAssertTrue(week.isSelected, "7 days is on")
    XCTAssertFalse(today.isSelected)
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/places-week.png"))
    }

    app.terminate()
    app.launchEnvironment["GRABBER_IMPORT_DB"] = nil
    app.launch()
    XCTAssertTrue(week.waitForExistence(timeout: 30), app.debugDescription)
    XCTAssertTrue(week.isSelected, "remembered after a relaunch")
    today.tap()
    XCTAssertTrue(today.isSelected, "and back to today")
  }
}
