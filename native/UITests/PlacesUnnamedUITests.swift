//  Story 056 (#162): on the full-screen map, an unnamed place's card names it, and its grey dot becomes a named pin.
//  Story 047 (#160): the name card shows where the place is on a small map.
//  Needs the real fixture in the app's Documents, as `just native-test-sim` puts it there:
//  cp __tests__/fixtures/context-grabber.db "$(xcrun simctl get_app_container <udid> com.idvorkin.grabbernative data)/Documents/import-fixture.db"
//  The place it names is deleted again at the end, so the test can run twice.

import XCTest

final class PlacesUnnamedUITests: XCTestCase {
  func testNameAnUnnamedPlaceFromTheMap() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_IMPORT_DB"] = "import-fixture.db,recent"
    app.launchEnvironment["GRABBER_PLACES"] = "map,unnamed"
    app.launch()
    let dot = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'unnamed-'")).firstMatch
    guard dot.waitForExistence(timeout: 30) else {
      throw XCTSkip("no unnamed place in the last seven days: is import-fixture.db in Documents?")
    }
    let placeId = String(dot.identifier.dropFirst("unnamed-".count))
    let name = app.buttons["name-this-place"]
    XCTAssertTrue(name.waitForExistence(timeout: 10), "the hook opens the longest place's card")
    name.tap()

    // #160: either card shows where the place is. A stay within 500 m of a known place gets the merge card first.
    let map = app.descendants(matching: .any)["naming-map"]
    XCTAssertTrue(map.waitForExistence(timeout: 5), app.debugDescription)
    let createNew = app.buttons["Create new place"]
    if createNew.exists {
      shot("naming-map-merge")
      createNew.tap()
      XCTAssertTrue(map.waitForExistence(timeout: 5), "the name card's map: \(app.debugDescription)")
    }
    let field = app.textFields["Place name"]
    XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
    shot("naming-map-name")
    field.tap()
    field.typeText("UITest Spot")
    app.buttons["Save"].tap()

    XCTAssertTrue(app.descendants(matching: .any)["UITest Spot"].waitForExistence(timeout: 10), "a named pin now")
    // The unnamed list is worked out again off the main thread after the save: wait for the dot to go.
    let dotGone = NSPredicate(format: "exists == false")
    expectation(for: dotGone, evaluatedWith: app.buttons["unnamed-\(placeId)"])
    waitForExpectations(timeout: 10)  // its grey dot is gone

    // Put the fixture back: collapse the map and delete the place from Known places.
    app.buttons["Collapse map"].tap()
    // The Known places row, not the day card's bar: it is the cell that also shows the radius.
    let row = app.cells.containing(NSPredicate(format: "label == 'UITest Spot'"))
      .containing(NSPredicate(format: "label CONTAINS ' · r '")).firstMatch
    for _ in 0..<12 where !row.isHittable { app.swipeUp() }
    row.swipeLeft()
    app.buttons["Delete"].tap()
    XCTAssertTrue(row.waitForNonExistence(timeout: 5), "the place is deleted again")
  }

  private func shot(_ name: String) {
    guard let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] else { return }
    try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
  }
}
