//  Story 441: a metric's detail fills an iPad's window. Story 442: it stays a sheet on an iPhone, dragged away.
//  Story 142: a shake still opens a report over it.

import XCTest

final class MetricDetailUITests: XCTestCase {
  private func launchOnTheDetail(_ extraEnvironment: [String: String] = [:]) -> XCUIApplication {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_MIRROR"] = "fixture"
    app.launchEnvironment["GRABBER_METRIC"] = "sleep"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment.merge(extraEnvironment) { _, new in new }
    app.launch()
    return app
  }

  func testTheDetailFillsAnIPadsWindowAndDragsAwayOnAnIPhone() throws {
    let app = launchOnTheDetail()
    let close = app.buttons["Close"].firstMatch
    XCTAssertTrue(close.appears(within: 30), app.debugDescription)
    let bar = app.navigationBars.containing(.button, identifier: "Close").firstMatch
    XCTAssertTrue(bar.exists, app.debugDescription)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "the detail"
    shot.lifetime = .keepAlways
    add(shot)
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(bar.frame.width, app.windows.firstMatch.frame.width, accuracy: 1, "the whole window's width")
      XCTAssertEqual(bar.frame.minY, 0, accuracy: 60, "from the top of the window")
      close.tap()
      XCTAssertTrue(close.waitForNonExistence(timeout: 5), "the X closes it")
    } else {
      bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
      XCTAssertTrue(close.waitForNonExistence(timeout: 5), "a drag closes the sheet")
    }
  }

  func testAShakeOpensAReportOverTheDetail() throws {
    let app = launchOnTheDetail(["GRABBER_SHAKE_AFTER": "20"])
    let close = app.buttons["Close"].firstMatch
    XCTAssertTrue(close.appears(within: 30), app.debugDescription)
    let report = app.navigationBars["Report a problem"]
    XCTAssertTrue(report.appears(within: 30), app.debugDescription)
    report.buttons["Cancel"].tap()
    XCTAssertTrue(close.appears(within: 5), "the detail is still there underneath")
  }
}
