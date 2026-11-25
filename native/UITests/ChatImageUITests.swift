//  Story 306 (#592) on the simulator: a white picture opened full size, against the fake Cockpit
//  (scripts/native/test-chat-ui.sh starts it), shows Done on a dark badge and closes with Done or a swipe down.
//  Stories 821, 822 (#907): Share, and a double tap zooming so a swipe pans.
//  Stories 317–319, 228 (#603): a picture from a board also jumps to that board; a missing board says so and the
//  picture stays. Stories 1122–1124 (#1091): the board's thread itself has *Board* in its bar, to the same ends. A link to a missing board staying on the boards and saying so is whiteboard code, not chat's:
//  `WhiteboardRowDeleteUITests` ends on it, and why a board can't open is `BoardIndexTests` (story 770).
//  Stories 1206–1208 (bead context-grabber-dbku): each jump between a board and its thread slides the other in over
//  where he is, never through home or a list, and *Back* (or a jump back) returns to where he jumped from.

import XCTest

final class ChatImageUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  private func openPicture(thread: String = "igor2-88g.592", board: String? = nil) throws -> XCUIApplication {
    let app = try launchThread(thread, board: board, picture: true)
    XCTAssertTrue(app.buttons["chat-image-done"].appears(within: 20), app.debugDescription)
    return app
  }

  /// The thread, with its picture opened full size by itself when `picture`.
  private func launchThread(
    _ thread: String, board: String? = nil, picture: Bool, link: String? = nil, boardThread: String? = nil,
    conversationOpen: Bool = false
  ) throws -> XCUIApplication {
    guard let cockpit = ProcessInfo.processInfo.environment["GRABBER_FAKE_COCKPIT"], !cockpit.isEmpty else {
      throw XCTSkip("needs the fake Cockpit: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = cockpit
    if picture { app.launchEnvironment["GRABBER_CHAT_IMAGE"] = "open" }
    app.launchEnvironment["GRABBER_LINK"] = link ?? "grabbernative://chat?thread=\(thread)"
    if let board { app.launchEnvironment["GRABBER_BOARD_FIXTURE"] = board }
    if let boardThread { app.launchEnvironment["GRABBER_BOARD_FIXTURE_THREAD"] = boardThread }
    // On an iPad, Open in Chat is in the board's conversation panel, and a board with nothing to say shows no note to
    // open it with: start with the panel open (the setting the note's chevron keeps).
    if conversationOpen { app.launchArguments += ["-whiteboard_conversation_open", "YES"] }
    app.launch()
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

  /// One launch for both ways out: a real swipe down closes it, a tap on the picture in the thread opens it again, and
  /// Done closes it. Which drags close it (only down, past 80 points) is `ChatImageCloseTests`'.
  func testDoneShowsOverAWhitePictureAndASwipeOrDoneCloses() throws {
    let app = try openPicture()
    let done = app.buttons["chat-image-done"]
    XCTAssertTrue(done.isHittable, app.debugDescription)

    // Share is live once the picture has loaded, so a dark reading below is never the spinner.
    let loaded = expectation(
      for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.buttons["chat-image-share"])
    wait(for: [loaded], timeout: 15)

    // Beside the badge is the white picture, and inside the badge, left of the word, it is dark.
    let frame = done.frame
    let beside = CGPoint(x: frame.minX - 4, y: frame.midY)
    let inside = CGPoint(x: frame.minX + 8, y: frame.midY)
    func whiteBeside(within seconds: TimeInterval) throws -> XCUIScreenshot {
      let deadline = Date().addingTimeInterval(seconds)
      var shot = XCUIScreen.main.screenshot()
      while try brightness(at: beside, in: shot) < 240, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.5)
        shot = XCUIScreen.main.screenshot()
      }
      return shot
    }
    var shot = try whiteBeside(within: 3)
    // The picture is half as wide as tall: fitted on the iPad's wider screen it leaves Done over the black margin
    // (context-grabber-ootp), so there a double tap zooms it until the white lies under the badge.
    let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let zoomed = try brightness(at: beside, in: shot) < 240
    if zoomed {
      middle.doubleTap()
      shot = try whiteBeside(within: 5)
    }
    let attachment = XCTAttachment(screenshot: shot)
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTAssertGreaterThan(try brightness(at: beside, in: shot), 240, "the picture is white beside Done")
    XCTAssertLessThan(try brightness(at: inside, in: shot), 140, "Done has a dark badge over the white")
    if zoomed {
      // Back to fitted, so the swipe closes rather than pans.
      middle.doubleTap()
      Thread.sleep(forTimeInterval: 0.5)
    }

    app.swipeDown()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), "a swipe down closes it: \(app.debugDescription)")
    // The thread's one message is Larry's picture alone, at his bubble's leading edge: the bubble's element can be the
    // whole row (the picture is half as wide as tall), so the tap goes near its left, not its middle.
    let bubble = app.descendants(matching: .any).matching(identifier: "chat-larry").firstMatch
    XCTAssertTrue(bubble.appears(within: 5), app.debugDescription)
    bubble.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
    XCTAssertTrue(done.appears(within: 5), "a tap opens it again: \(app.debugDescription)")
    done.tap()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done closes it: \(app.debugDescription)")
  }

  /// Stories 821, 822 (#907): Share is there on its dark badge, and a double tap zooms, so a swipe down pans instead of closing;
  /// a second double tap goes back to fitted and the swipe closes again. The scale and pan rules are `ChatImageZoomTests`'.
  func testShareShowsAndADoubleTapZoomsSoASwipePans() throws {
    let app = try openPicture()
    let share = app.buttons["chat-image-share"]
    XCTAssertTrue(share.appears(within: 10), app.debugDescription)
    // Share is live only while there is a picture to share, so the double tap lands on the picture.
    let loaded = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: share)
    wait(for: [loaded], timeout: 15)
    let done = app.buttons["chat-image-done"]
    let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    middle.doubleTap()
    app.swipeDown()
    XCTAssertTrue(done.exists, "zoomed, a swipe down pans: \(app.debugDescription)")
    middle.doubleTap()
    app.swipeDown()
    XCTAssertTrue(done.waitForNonExistence(timeout: 5), "fitted again, a swipe down closes: \(app.debugDescription)")
  }

  func testAPictureFromABoardJumpsToIt() throws {
    let app = try openPicture(thread: "igor2-88g.603", board: "board-603")
    let jump = app.buttons["chat-image-jump"]
    XCTAssertTrue(jump.appears(within: 5), app.debugDescription)
    jump.tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard"].appears(within: 15), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-image-done"].exists, "no zoom left stuck over the board")
    XCTAssertFalse(app.buttons["whiteboard-done"].exists, "slid in over the thread, not through the boards")

    // Story 317 (bead context-grabber-dbku): Back comes back to the thread, not the boards or home.
    let back = app.navigationBars.buttons.firstMatch
    XCTAssertTrue(back.appears(within: 5), app.debugDescription)
    back.tap()
    XCTAssertTrue(app.buttons["chat-thread-board"].appears(within: 10), "back on the thread: \(app.debugDescription)")
    XCTAssertFalse(app.buttons["whiteboard-done"].exists, app.debugDescription)
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

  /// Story 1122 (#1091): a board's thread has *Board* in its bar; it slides the board in, whose Back comes back to the
  /// thread (bead context-grabber-dbku).
  func testABoardsThreadHasBoardInItsBarBackToTheBoard() throws {
    let app = try launchThread("igor2-88g.603", board: "board-603", picture: false)
    let board = app.buttons["chat-thread-board"]
    XCTAssertTrue(board.appears(within: 20), app.debugDescription)
    board.tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard"].appears(within: 15), app.debugDescription)
    let back = app.navigationBars.buttons.firstMatch
    XCTAssertTrue(back.appears(within: 5), app.debugDescription)
    back.tap()
    XCTAssertTrue(app.buttons["chat-thread-board"].appears(within: 10), "back on the thread: \(app.debugDescription)")
    XCTAssertFalse(app.buttons["whiteboard-done"].exists, "no boards on the way: \(app.debugDescription)")
  }

  /// Story 569 (#1454): a web ink board's thread has *Board* in its bar, and it opens the board's page in Safari, not a
  /// problem saying the board isn't on this device.
  func testAWebBoardsThreadOpensItsPageInSafari() throws {
    let app = try launchThread("igor2-88g.1454", picture: false)
    let board = app.buttons["chat-thread-board"]
    XCTAssertTrue(board.appears(within: 20), app.debugDescription)
    board.tap()
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "the web board opens in Safari")
    app.activate()
    XCTAssertFalse(app.buttons["copy-error"].appears(within: 3), "no board-missing problem: \(app.debugDescription)")
  }

  /// Story 569 (#1454): a picture from a web ink board jumps to the board's page in Safari.
  func testAPictureFromAWebBoardJumpsToItsPage() throws {
    let app = try openPicture(thread: "igor2-88g.1454")
    let jump = app.buttons["chat-image-jump"]
    XCTAssertTrue(jump.appears(within: 5), app.debugDescription)
    jump.tap()
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "the web board opens in Safari")
    app.activate()
    XCTAssertFalse(app.buttons["copy-error"].appears(within: 3), "no board-missing problem: \(app.debugDescription)")
  }

  /// The board's *Open in Chat*: the panel's on an iPad (opened by a tap on the note when it's closed), the note itself
  /// on an iPhone.
  private func openInChat(_ app: XCUIApplication) {
    let chat = app.buttons["whiteboard-conversation-chat"]
    if chat.exists {
      chat.tap()
      return
    }
    let note = app.descendants(matching: .any)["whiteboard-note"]
    XCTAssertTrue(note.appears(within: 10), app.debugDescription)
    note.tap()
    if chat.appears(within: 3) { chat.tap() }
  }

  /// Stories 1206, 1207 (bead context-grabber-dbku): a board opened by a link slides its thread in with *Open in Chat*;
  /// the thread's *Board* goes back to that same board, whose Back then shows the boards it was opened over.
  func testOpenInChatSlidesTheThreadInAndBoardGoesBack() throws {
    let app = try launchThread(
      "igor2-88g.603", board: "board-603", picture: false, link: "grabbernative://whiteboard?board=board-603",
      boardThread: "igor2-88g.603", conversationOpen: true)
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard"].appears(within: 20), app.debugDescription)
    openInChat(app)
    let board = app.buttons["chat-thread-board"]
    XCTAssertTrue(board.appears(within: 15), "the thread slid in over the board: \(app.debugDescription)")
    XCTAssertFalse(app.buttons["whiteboard-done"].exists, "no boards list on the way: \(app.debugDescription)")
    board.tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard"].appears(within: 15), app.debugDescription)
    XCTAssertTrue(board.disappears(within: 10), "went back, not a second copy over the thread: \(app.debugDescription)")
    let back = app.navigationBars.buttons.firstMatch
    XCTAssertTrue(back.appears(within: 5), app.debugDescription)
    back.tap()
    XCTAssertTrue(app.buttons["whiteboard-done"].appears(within: 10), "one Back to the boards: \(app.debugDescription)")
  }

  /// Story 1225: a board slid in over its thread goes back to that thread with *Open in Chat*.
  func testOpenInChatOnABoardFromItsThreadGoesBack() throws {
    let app = try launchThread(
      "igor2-88g.603", board: "board-603", picture: false, boardThread: "igor2-88g.603", conversationOpen: true)
    let board = app.buttons["chat-thread-board"]
    XCTAssertTrue(board.appears(within: 20), app.debugDescription)
    board.tap()
    XCTAssertTrue(app.descendants(matching: .any)["whiteboard"].appears(within: 15), app.debugDescription)
    openInChat(app)
    XCTAssertTrue(board.appears(within: 10), "back on the thread: \(app.debugDescription)")
    XCTAssertTrue(
      app.descendants(matching: .any)["whiteboard"].disappears(within: 10), "the board went, not under a new thread")
  }

  /// Story 1124: a thread with no board has no *Board*.
  func testAThreadWithNoBoardHasNoBoardInItsBar() throws {
    let app = try launchThread("igor2-88g.592", picture: false)
    let bubble = app.descendants(matching: .any).matching(identifier: "chat-larry").firstMatch
    XCTAssertTrue(bubble.appears(within: 20), app.debugDescription)
    XCTAssertFalse(app.buttons["chat-thread-board"].exists, app.debugDescription)
  }

  /// Story 1123: *Board* on a thread whose board no device has says so, and the thread stays.
  func testBoardOnAThreadWhoseBoardIsMissingSaysSoAndTheThreadStays() throws {
    let app = try launchThread("igor2-88g.604", picture: false)
    let board = app.buttons["chat-thread-board"]
    XCTAssertTrue(board.appears(within: 20), app.debugDescription)
    board.tap()
    XCTAssertTrue(app.buttons["copy-error"].appears(within: 20), app.debugDescription)
    XCTAssertTrue(board.exists, "the thread stays: \(app.debugDescription)")
    XCTAssertFalse(app.descendants(matching: .any)["whiteboard"].exists, app.debugDescription)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.lifetime = .keepAlways
    add(shot)
  }
}
