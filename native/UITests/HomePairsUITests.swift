//  #225: thinner tiles, and Exercise Analyzer + Workout Supermix, Eulogy + Eulogy song each share a line.
//  #235: the pairs are tiles the size of the four's, and a launcher alone is one tile the width of two.

import XCTest

final class HomePairsUITests: XCTestCase {
  func testTilesAreOneLineAndPairsShareALine() throws {
    let app = XCUIApplication()
    app.launch()
    let call = app.buttons["home-call"]
    XCTAssertTrue(call.waitForExistence(timeout: 15), app.debugDescription)
    let places = app.buttons["home-places"].frame
    XCTAssertLessThan(places.height, 80, "a tile is one line tall")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/home-pairs.png"))
    }
    // Before any scrolling: a row scrolled off the screen leaves the hierarchy.
    let cockpit = app.buttons["home-cockpit"]
    if !cockpit.isHittable { app.swipeUp() }
    XCTAssertEqual(cockpit.frame.width, places.maxX - call.frame.minX, accuracy: 2, "a launcher alone is the width of two")
    for (a, b) in [("exercise_analyzer", "workout_supermix"), ("eulogy", "eulogy_song")] {
      let left = app.buttons["home-\(a)"], right = app.buttons["home-\(b)"]
      if !right.isHittable { app.swipeUp() }
      XCTAssertTrue(left.exists && right.exists, app.debugDescription)
      XCTAssertEqual(left.frame.midY, right.frame.midY, accuracy: 4, "\(a) and \(b) share a line")
      XCTAssertLessThan(left.frame.maxX, right.frame.minX)
      XCTAssertEqual(left.frame.width, places.width, accuracy: 2, "\(a) is a tile like the four's")
      XCTAssertEqual(left.frame.height, places.height, accuracy: 2, "\(a) is as tall as the four's")
      XCTAssertEqual(left.frame.minX, call.frame.minX, accuracy: 2, "\(a) lines up under the four")
    }

    // Each half opens its own launcher: the song's sheet, not the post.
    app.buttons["home-eulogy_song"].tap()
    XCTAssertTrue(app.buttons["eulogy-song-toggle"].waitForExistence(timeout: 10), app.debugDescription)
  }
}
