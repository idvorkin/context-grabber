//  Story 184 (#163): upright, the Custom preset's Work drum turns with a tap on either end and a swipe up.

import XCTest

final class GymTimerDialsUITests: XCTestCase {
  private func seconds(_ mss: String) -> Int {
    let parts = mss.split(separator: ":").compactMap { Int($0) }
    return parts.count == 2 ? parts[0] * 60 + parts[1] : -1
  }

  func testSwipeAndTapTheWorkDrum() throws {
    let app = XCUIApplication()
    app.launchEnvironment["GRABBER_TIMER_DIAL"] = "drums"
    app.launch()
    let work = app.descendants(matching: .any)["dial-work"]
    XCTAssertTrue(work.waitForExistence(timeout: 15), app.debugDescription)
    // Start from a known place whatever an earlier run left: tap the upper third down to the floor.
    for _ in 0..<70 where work.value as? String != "0:10" {
      work.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
    }
    XCTAssertEqual(work.value as? String, "0:10", "a tap on the upper third is one step less, down to 0:10")

    work.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88)).tap()
    XCTAssertEqual(work.value as? String, "0:20", "a tap on the lower third is one step more")

    let before = seconds(work.value as? String ?? "")
    work.swipeUp()
    let after = seconds(work.value as? String ?? "")
    XCTAssertGreaterThan(after, before, "a swipe up turns Work up")
    XCTAssertEqual(after % 10, 0, "on the ten-second grid")
    XCTAssertLessThanOrEqual(after, 600)
  }
}
