//  #225: thinner tiles, and Exercise Analyzer + Workout Supermix, Eulogy + Eulogy song each share a line.

import XCTest

final class HomePairsUITests: XCTestCase {
  func testTilesAreOneLineAndPairsShareALine() throws {
    let app = XCUIApplication()
    app.launch()
    let call = app.buttons["home-call"]
    XCTAssertTrue(call.waitForExistence(timeout: 15), app.debugDescription)
    XCTAssertLessThan(app.buttons["home-places"].frame.height, 80, "a tile is one line tall")
    if let shots = ProcessInfo.processInfo.environment["GRABBER_SHOTS"] {
      try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/home-pairs.png"))
    }
    for (a, b) in [("exercise_analyzer", "workout_supermix"), ("eulogy", "eulogy_song")] {
      let left = app.buttons["home-\(a)"], right = app.buttons["home-\(b)"]
      if !right.isHittable { app.swipeUp() }
      XCTAssertTrue(left.exists && right.exists, app.debugDescription)
      XCTAssertEqual(left.frame.midY, right.frame.midY, accuracy: 4, "\(a) and \(b) share a line")
      XCTAssertLessThan(left.frame.maxX, right.frame.minX)
    }
    // Each half opens its own launcher: the song's sheet, not the post.
    app.buttons["home-eulogy_song"].tap()
    XCTAssertTrue(app.buttons["eulogy-song-toggle"].waitForExistence(timeout: 10), app.debugDescription)
  }
}
