//  Story 137 (#177): Eulogy and Recent leave for the blog, and so does Random (story 247, #259); Eulogy song plays
//  in the app, and its sheet's Open on Suno leaves for the song. The player's rules are host tests (SongPlaybackTests).

import XCTest

final class EulogyUITests: XCTestCase {
  let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")

  private func row(_ id: String, in app: XCUIApplication) -> XCUIElement {
    let row = app.buttons["home-\(id)"]
    for _ in 0..<4 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.appears(within: 15), app.debugDescription)
    return row
  }

  /// One launch for the three: Safari is sent away and the app brought back between them (it was a launch each).
  func testBlogLaunchersLeaveTheApp() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    for id in ["eulogy", "recent", "random"] {
      row(id, in: app).tap()
      XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "\(id) opened the browser")
      safari.terminate()
      app.activate()
      XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "back from \(id)")
    }
  }

  /// The one play on the simulator: the tile starts the song, restart plays it from the start, and with the sheet
  /// closed the small player (#195) carries it: pause in place, ✕ stops it and it goes away. What play, pause,
  /// resume, a scrub, a call and a song that cannot play do is SongPlaybackTests, on the host.
  func testThePlayRestartAndTheSmallPlayer() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    row("eulogy_song", in: app).tap()
    let elapsed = app.staticTexts["eulogy-song-elapsed"]
    XCTAssertTrue(app.buttons["eulogy-song-toggle"].appears(within: 10), app.debugDescription)
    XCTAssertTrue(waitFor(app.buttons["eulogy-song-toggle"], "label == 'Pause'", 10), whyNotPlaying(app))
    app.buttons["eulogy-song-restart"].tap()
    XCTAssertTrue(waitFor(elapsed, "label BEGINSWITH '0:0'", 10), "restarted at \(elapsed.label)")
    XCTAssertEqual(app.buttons["eulogy-song-toggle"].label, "Pause")
    app.swipeDown(velocity: .fast)
    let mini = app.buttons["eulogy-mini-toggle"]
    XCTAssertTrue(mini.appears(within: 10), "the small player shows: \(app.debugDescription)")
    mini.tap()
    XCTAssertTrue(waitFor(mini, "label == 'Resume'", 5), mini.label)
    // A tap on it opens the sheet as the song is, still paused.
    app.buttons["eulogy-mini-open"].tap()
    XCTAssertTrue(waitFor(app.buttons["eulogy-song-toggle"], "label == 'Resume'", 10))
    app.swipeDown(velocity: .fast)
    XCTAssertTrue(mini.appears(within: 10))
    app.buttons["eulogy-mini-stop"].tap()
    XCTAssertTrue(waitFor(mini, "exists == false", 5), "the ✕ took the small player away")
  }

  /// #205: Open on Suno opens the song the post embeds, on suno.com, not the post it falls back to.
  func testOpenOnSunoOpensTheSongNotThePost() throws {
    let app = XCUIApplication.forTests()
    app.launch()
    row("eulogy_song", in: app).tap()
    let suno = app.buttons["eulogy-song-suno"]
    XCTAssertTrue(suno.appears(within: 10), app.debugDescription)
    suno.tap()
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "Open on Suno opened the browser")
    // Safari's address bar, not the page: the post itself embeds a Suno player, so only the address can tell.
    let address = safariAddress()
    XCTAssertTrue(address.appears(within: 20), safari.debugDescription)
    XCTAssertTrue(waitFor(address, "value CONTAINS[c] 'suno.com'", 20), "Safari is on \(address.value ?? "?")")
    safari.terminate()
  }

  /// The active tab's address field. An iPhone's Safari names it `TabBarItemTitle`; an iPad's shows a tab bar where
  /// every tab has a `TabBarItemTitleContainer` field, so it's the one inside the active search field (bead
  /// context-grabber-3hj9.2: the store walk ran on the iPad and found no `TabBarItemTitle` at all). An old tab on
  /// suno.com from an earlier run can't pass the check.
  private func safariAddress() -> XCUIElement {
    guard UIDevice.current.userInterfaceIdiom == .pad else { return safari.textFields["TabBarItemTitle"] }
    let active = NSPredicate(format: "identifier BEGINSWITH 'SearchFieldItemView?isActive=true'")
    return safari.buttons.matching(active).firstMatch.textFields.firstMatch
  }

  /// #692: when the system's player refuses, the app says so on the sheet (a copyable problem) and logs
  /// `play_refused`; the simulator's audio has done that on code that plays on the phone (docs/TESTING.md). The
  /// failure names which it was, so a red run reads as the app's or the simulator's without opening the log.
  private func whyNotPlaying(_ app: XCUIApplication) -> String {
    let problem = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'The song '")).firstMatch
    guard problem.exists else { return "the song did not play and the sheet shows no problem: \(app.debugDescription)" }
    return "the song did not play, and the sheet says \"\(problem.label)\": the song would not load, or the "
      + "system's player refused it. On code that plays on the phone that has been the simulator's audio "
      + "(docs/TESTING.md, #692): unlock the Mac, rerun, and read the session log's eulogy_song events"
  }

  private func waitFor(_ element: XCUIElement, _ format: String, _ timeout: TimeInterval) -> Bool {
    XCTWaiter().wait(for: [expectation(for: NSPredicate(format: format), evaluatedWith: element)], timeout: timeout)
      == .completed
  }
}
