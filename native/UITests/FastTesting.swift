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
}

extension XCTestCase {
  /// Waits for `predicate` to hold for `object`, looking every 0.1 s, and fails the test at `timeout` as
  /// `waitForExpectations` would. XCTest's predicate expectation looks about once a second, so each of its waits costs
  /// up to a second more than the app takes (story 673).
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
