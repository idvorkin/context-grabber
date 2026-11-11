//  Story 306 (#592) on the simulator: a white picture opened full size, against the fake Cockpit
//  (scripts/native/test-chat-ui.sh starts it), shows Done on a dark badge and closes with Done or a swipe down.
//  Stories 317–319, 228 (#603): a picture from a board also jumps to that board; a missing board says so and the
//  picture stays; a link to a missing board stays on the boards and says so.

import XCTest

final class ChatImageUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func openPicture(thread: String = "igor2-88g.592", board: String? = nil) throws -> XCUIApplication {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    app.launchEnvironment["GRABBER_CHAT_IMAGE"] = "open"
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=\(thread)"
    if let board { app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = board }
    app.launch()
    XCTAssertTrue(app.buttons["chat-image-done"].appears(within: 20), app.debugDescription)
    return app
  }

  /// How bright the screen is at a point, 0 to 255; white and the black badge are greys, so one channel will do.
  private func brightness(at point: CGPoint, in shot: XCUIScreenshot) throws -> UInt8 {
    let image = shot.image
    let cg = try XCTUnwrap(image.cgImage)
    var pixel: [UInt8] = [0, 0, 0, 255]
    let context = try XCTUnwrap(
      CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let x = point.x * image.scale
    let y = point.y * image.scale
    context.draw(
      cg, in: CGRect(x: -x, y: y + 1 - CGFloat(cg.height), width: CGFloat(cg.width), height: CGFloat(cg.height)))
    return pixel[0]
  }

  func testDoneShowsOverAWhitePictureAndCloses() throws {
    let app = try openPicture()
    let done = app.buttons["chat-image-done"]
    XCTAssertTrue(done.isHittable, app.debugDescription)

    // Beside the badge is the white picture (once it has loaded), and inside the badge, left of the word, it is dark.
    let frame = done.frame
    let beside = CGPoint(x: frame.minX - 4, y: frame.midY)
    let inside = CGPoint(x: frame.minX + 8, y: frame.midY)
    let deadline = Date().addingTimeInterval(10)
    var shot = XCUIScreen.main.screenshot()
    while try brightness(at: beside, in: shot) < 240, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.5)
      shot = XCUIScreen.main.screenshot()
    }
    add(XCTAttachment(screenshot: shot))
    XCTAssertGreaterThan(try brightness(at: beside, in: shot), 240, "the picture is white beside Done")
    XCTAssertLessThan(try brightness(at: inside, in: shot), 140, "Done has a dark badge over the white")

    done.tap()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), app.debugDescription)
  }

  /// Which drags close it (only down, past 80 points) is ChatImageCloseTests'; this is the real swipe.
  func testASwipeDownCloses() throws {
    let app = try openPicture()
    let done = app.buttons["chat-image-done"]
    app.swipeDown()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), app.debugDescription)
  }

  func testAPictureFromABoardJumpsToIt() throws {
    let app = try openPicture(thread: "igor2-88g.603", board: "board-603")
    let jump = app.buttons["chat-image-jump"]
    XCTAssertTrue(jump.appears(within: 5), app.debugDescription)
    jump.tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard"].appears(within: 15), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-image-done"].exists, "no zoom left stuck over the board")

    // Out of the board and the list: home, not a stuck cover.
    let back = app.navigationBars.buttons.firstMatch
    XCTAssertTrue(back.appears(within: 5), app.debugDescription)
    back.tap()
    let done = app.buttons["whiteboard-done"]
    XCTAssertTrue(done.appears(within: 10), app.debugDescription)
    done.tap()
    XCTAssertTrue(app.buttons["home-call"].appears(within: 10), app.debugDescription)
  }

  func testAMissingBoardSaysSoAndThePictureStays() throws {
    let app = try openPicture(thread: "igor2-88g.604")
    let jump = app.buttons["chat-image-jump"]
    XCTAssertTrue(jump.appears(within: 5), app.debugDescription)
    jump.tap()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 20), app.debugDescription)
    XCTAssertTrue(app.buttons["chat-image-done"].exists, "the picture stays")
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
    app.buttons["chat-image-done"].tap()
    XCTAssertTrue(app.buttons["chat-image-done"].waitForNonExistence(timeout: 5), app.debugDescription)
  }

  func testALinkToAMissingBoardOpensTheBoardsAndSaysSo() throws {
    guard ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"]?.isEmpty == false else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://whiteboard?board=board-gone-603"
    app.launch()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 20), app.debugDescription)
    XCTAssertTrue(app.buttons["whiteboard-done"].exists, app.debugDescription)
  }
}
