//  Story 137 (#177): Eulogy and Recent leave for the blog; Eulogy song plays in the app, and its sheet's
//  Open on Suno leaves for the song.

import XCTest

final class EulogyUITests: XCTestCase {
  let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

  private func row(_ id: String, in app: XCUIApplication) -> XCUIElement {
    let row = app.buttons["home-\(id)"]
    for _ in 0..<4 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    return row
  }

  func testBlogLaunchersLeaveTheApp() throws {
    for id in ["eulogy", "recent"] {
      let app = XCUIApplication()
      app.launch()
      row(id, in: app).tap()
      XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "\(id) opened the browser")
      safari.terminate()
    }
  }

  func testTheSongPlaysInTheAppAndResumes() throws {
    let app = XCUIApplication()
    app.launch()
    row("eulogy_song", in: app).tap()
    let toggle = app.buttons["eulogy-song-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 10), app.debugDescription)
    let elapsed = app.staticTexts["eulogy-song-elapsed"]
    // Playing: the clock moves off 0:00 and the button offers Pause.
    XCTAssertTrue(waitFor(elapsed, "label != '0:00'", 10), "the song plays: \(elapsed.label)")
    XCTAssertEqual(toggle.label, "Pause")
    XCTAssertFalse(app.staticTexts["eulogy-song-failure"].exists)
    toggle.tap()
    XCTAssertTrue(waitFor(toggle, "label == 'Resume'", 5), toggle.label)
    let pausedAt = elapsed.label
    // Closed and reopened: it resumes from where it was, not the start.
    app.swipeDown(velocity: .fast)
    XCTAssertTrue(waitFor(toggle, "exists == false", 5), "the sheet closed")
    row("eulogy_song", in: app).tap()
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    XCTAssertTrue(waitFor(toggle, "label == 'Pause'", 5), toggle.label)
    XCTAssertGreaterThanOrEqual(seconds(elapsed.label), seconds(pausedAt), "resumed at \(elapsed.label), paused at \(pausedAt)")
    // The song on Suno is still one tap away.
    app.buttons["eulogy-song-suno"].tap()
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "Open on Suno opened the browser")
    safari.terminate()
  }

  /// #195: the scrubber moves the song, restart goes back to the start, and with the sheet closed the small
  /// player carries it: pause in place, ✕ stops it and it goes away.
  func testScrubRestartAndTheSmallPlayer() throws {
    let app = XCUIApplication()
    app.launch()
    row("eulogy_song", in: app).tap()
    let elapsed = app.staticTexts["eulogy-song-elapsed"]
    XCTAssertTrue(app.buttons["eulogy-song-toggle"].waitForExistence(timeout: 10), app.debugDescription)
    app.sliders["eulogy-song-scrubber"].adjust(toNormalizedSliderPosition: 0.9)
    XCTAssertTrue(waitFor(elapsed, "label BEGINSWITH '1:' OR label BEGINSWITH '2:'", 10), "scrubbed to \(elapsed.label)")
    XCTAssertGreaterThanOrEqual(seconds(elapsed.label), 100, elapsed.label)
    app.buttons["eulogy-song-restart"].tap()
    XCTAssertTrue(waitFor(elapsed, "label BEGINSWITH '0:0'", 10), "restarted at \(elapsed.label)")
    XCTAssertEqual(app.buttons["eulogy-song-toggle"].label, "Pause")
    app.swipeDown(velocity: .fast)
    let mini = app.buttons["eulogy-mini-toggle"]
    XCTAssertTrue(mini.waitForExistence(timeout: 10), "the small player shows: \(app.debugDescription)")
    mini.tap()
    XCTAssertTrue(waitFor(mini, "label == 'Resume'", 5), mini.label)
    // A tap on it opens the sheet as the song is, still paused.
    app.buttons["eulogy-mini-open"].tap()
    XCTAssertTrue(waitFor(app.buttons["eulogy-song-toggle"], "label == 'Resume'", 10))
    app.swipeDown(velocity: .fast)
    XCTAssertTrue(mini.waitForExistence(timeout: 10))
    app.buttons["eulogy-mini-stop"].tap()
    XCTAssertTrue(waitFor(mini, "exists == false", 5), "the ✕ took the small player away")
  }

  /// #201: a song that cannot play says so with a Copy error, not a bare red line.
  func testASongThatCannotPlayOffersCopyError() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_SONG"] = "missing"
    app.launch()
    row("eulogy_song", in: app).tap()
    XCTAssertTrue(app.staticTexts["The song is missing from this build."].waitForExistence(timeout: 10), app.debugDescription)
    let copy = app.buttons["Copy error"]
    XCTAssertTrue(copy.exists, app.debugDescription)
    copy.tap()
    XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout: 5))
  }

  private func waitFor(_ element: XCUIElement, _ format: String, _ timeout: TimeInterval) -> Bool {
    XCTWaiter().wait(for: [expectation(for: NSPredicate(format: format), evaluatedWith: element)], timeout: timeout)
      == .completed
  }

  private func seconds(_ clock: String) -> Int {
    let parts = clock.split(separator: ":").compactMap { Int($0) }
    return parts.count == 2 ? parts[0] * 60 + parts[1] : -1
  }
}
