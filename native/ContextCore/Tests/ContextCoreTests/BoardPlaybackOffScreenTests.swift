import Foundation
import XCTest

@testable import ContextCore

/// The oracle is story 948 (#1169): while a board plays back, a label says when the stroke being drawn (or drawn last) is
/// wholly above or below the screen, and on which page; ink any of which shows needs no label.
final class BoardPlaybackOffScreenTests: XCTestCase {
  private let pages = BoardPages()
  /// Page 2 on the screen: pages are 1060 points tall.
  private let page2 = CGRect(x: 0, y: 1100, width: 820, height: 900)

  private func stroke(_ t: TimeInterval) -> BoardPlayback.Stroke {
    BoardPlayback.Stroke(began: 1_800_000_000 + t, offsets: [0, 0.5, 1])
  }

  func testInkOnPageOneWithPageTwoShowingIsAbove() {
    let ink = CGRect(x: 100, y: 200, width: 300, height: 40)
    XCTAssertEqual(BoardPlayback.offScreen(ink: ink, visible: page2, pages: pages), .above(page: 1))
    XCTAssertEqual(BoardPlayback.OffScreen.above(page: 1).text, "Writing above, page 1")
  }

  func testInkOnPageThreeWithPageTwoShowingIsBelow() {
    let ink = CGRect(x: 100, y: 2300, width: 300, height: 40)
    XCTAssertEqual(BoardPlayback.offScreen(ink: ink, visible: page2, pages: pages), .below(page: 3))
    XCTAssertEqual(BoardPlayback.OffScreen.below(page: 3).text, "Writing below, page 3")
  }

  func testInkBelowTheScreenOnTheSamePageSaysThatPage() {
    let ink = CGRect(x: 100, y: 2050, width: 300, height: 4)
    XCTAssertEqual(BoardPlayback.offScreen(ink: ink, visible: page2, pages: pages), .below(page: 2))
  }

  func testInkOnTheScreenOrPartlyOnItNeedsNoLabel() {
    XCTAssertNil(
      BoardPlayback.offScreen(ink: CGRect(x: 100, y: 1500, width: 300, height: 40), visible: page2, pages: pages))
    XCTAssertNil(
      BoardPlayback.offScreen(ink: CGRect(x: 100, y: 1080, width: 300, height: 40), visible: page2, pages: pages),
      "a stroke crossing the top edge shows in part")
    XCTAssertNil(BoardPlayback.offScreen(ink: .null, visible: page2, pages: pages))
  }

  func testLatestIsTheStrokeBeingDrawnOrTheOneDrawnLast() {
    let playback = BoardPlayback([stroke(0), stroke(60), stroke(120)])
    XCTAssertNil(playback.latest(at: 0), "nothing begun yet")
    XCTAssertEqual(playback.latest(at: 0.5), 0, "the first, being drawn")
    XCTAssertEqual(playback.latest(at: 1.2), 0, "between strokes, the one drawn last")
    XCTAssertEqual(playback.latest(at: 1.6), 1)
    XCTAssertEqual(playback.latest(at: playback.length), 2, "at the end, the last")
  }
}
