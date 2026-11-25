//  What keeps the UI tests quick (story 673).

import XCTest

extension XCUIElement {
  /// Like `waitForExistence`, whose first look comes about a second in even when the element is already there.
  func appears(within timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if exists { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return exists
  }

  /// The other way round: true once the element is gone, looking every 0.1 s (bead context-grabber-u76). `waitUntil`
  /// reads a missing element as "not yet", so it can't wait for a disappearance, and XCTest's predicate expectation
  /// looks about once a second.
  func disappears(within timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if !exists { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while Date() < deadline
    return !exists
  }
}

extension XCTestCase {
  /// Waits for `predicate` to hold for `object`, looking every 0.1 s, and fails the test at `timeout` as
  /// `waitForExpectations` would. XCTest's predicate expectation looks about once a second, so each of its waits costs
  /// up to a second more than the app takes (story 673). A missing element reads as "not yet": to wait for one to
  /// go away, use `disappears(within:)`.
  func waitUntil(
    _ predicate: NSPredicate, _ object: Any?, timeout: TimeInterval, file: StaticString = #filePath, line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(timeout)
    // An element that is gone for a moment (mid-navigation) reads as not yet, rather than failing on the read.
    let element = object as? XCUIElement
    while !(element.map { $0.exists } ?? true) || !predicate.evaluate(with: object) {
      guard Date() < deadline else {
        // What it was, so a miss says where it went (7 Nov: two misses showed only what was wanted).
        let seen = element.map { $0.exists ? "label is \"\($0.label)\"" : "element not found" } ?? "no element"
        // #850: and the screen and its tree as they were, kept in the result, so a flaky miss shows what covered it.
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "waitUntil miss"
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: XCUIApplication().debugDescription)
        tree.name = "waitUntil miss: the app's tree"
        tree.lifetime = .keepAlways
        add(tree)
        XCTFail("not within \(timeout) s: \(predicate.predicateFormat); \(seen)", file: file, line: line)
        return
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
  }
}

extension XCUIApplication {
  /// The app as every UI test launches it: UIKit's animations off, so a screen, sheet or menu is there at once rather
  /// than after its slide (story 754; the chat suite went from about 243 s to 193 s). `animated` keeps them.
  /// ponytail: the whiteboard's classes keep their animations. Without the Board menu's closing animation a stroke
  /// after it counted 2 where 1 was drawn (PaperLines, iPad simulator, 2026-11-10), so the menu's closing tap may reach
  /// the canvas. Turn them off there once #850's responder fight is settled, and measure again.
  /// A new board starts bare, as before #915, so a board's pixels are read against plain paper; the grid a new board
  /// really opens with is `WhiteboardPaperLinesUITests.testANewBoardOpensWithTheGrid`, which drops this (story 410).
  /// A call a test places dials TEST-NET-1 (RFC 5737), never Igor's bridge (context-grabber-0mn): routed nowhere, the
  /// socket waits out its ten seconds rather than failing at once and filing an automatic report. A test that wants a
  /// bridge names its fake one with `GRABBER_CALL`, which wins.
  static func forTests(animated: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    if !animated { app.launchEnvironment["GRABBER_NO_ANIMATIONS"] = "1" }
    app.launchEnvironment["GRABBER_WHITEBOARD_GRID"] = "off"
    app.launchEnvironment["GRABBER_CALL_BRIDGE"] = "ws://192.0.2.1:8780"
    // Story 1630 (bead context-grabber-8dnk): no Health refresh at launch, so HealthKit's own simulator crash
    // (bead context-grabber-2xyj) fails only the tests about Health. `GRABBER_MIRROR` still grabs its fixture week.
    app.launchEnvironment["GRABBER_HEALTH"] = "off"
    return app
  }
}

extension XCTestCase {
  /// Story 673: until a board on paper has saved its ink, as its page number's value says, in place of a fixed second
  /// past the save. Asked after the stroke is counted, so the ink is already marked unsaved.
  func waitForTheSave(
    _ app: XCUIApplication, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line
  ) {
    waitUntil(
      NSPredicate(format: "value == 'saved'"),
      app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Page '")).firstMatch, timeout: timeout,
      file: file,
      line: line)
  }
}

/// Story 672: one running app for a class's tests, so each test after the first skips its launch (5-9 s each in the
/// timing study). A test gets the running app back through `back`, the class's own way to the screen its launch hook
/// lands on (a Back tap, say). Not a link home: XCTest then waited 33 s for the app to idle, more than a launch. A fresh
/// launch instead when there is no app yet, the class or the environment differs, or the last test on it failed (its
/// state is then unknown). Tests about what survives a restart launch for themselves.
enum SharedApp {
  private static var app: XCUIApplication?
  private static var owner = ""
  private static var environment: [String: String] = [:]
  private static var spoiled = false

  /// `environment` goes on top of `XCUIApplication.forTests()`'s.
  static func open(
    _ environment: [String: String], for test: XCTestCase, back: (XCUIApplication) -> Void
  ) -> XCUIApplication {
    let owner = String(describing: type(of: test))
    test.addTeardownBlock {
      if (test.testRun?.totalFailureCount ?? 1) > 0 { spoiled = true }
    }
    if let app, !spoiled, owner == self.owner, environment == self.environment, app.state == .runningForeground {
      back(app)
      return app
    }
    let fresh = XCUIApplication.forTests()
    fresh.launchEnvironment.merge(environment) { $1 }
    fresh.launch()
    (self.app, self.owner, self.environment, spoiled) = (fresh, owner, environment, false)
    return fresh
  }
}
