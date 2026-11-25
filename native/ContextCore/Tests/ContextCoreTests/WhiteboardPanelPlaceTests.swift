import XCTest

@testable import ContextCore

/// Stories 1278, 1279 (#1384): the conversation resizes, and floats as a card or docks.
final class WhiteboardPanelPlaceTests: XCTestCase {
  func testWithNothingStoredThePanelIsAFifthAsBefore() {
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: nil, page: 1000), 200)
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: nil, page: 400), WhiteboardNote.panelFloor)
  }

  func testAStoredHeightIsAShareOfThePageWithinItsBounds() {
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: 0.4, page: 1000), 400)
    XCTAssertEqual(
      WhiteboardPanelPlace.height(stored: 0.95, page: 1000), 1000 * WhiteboardPanelPlace.tallest, "most of the board")
    XCTAssertEqual(WhiteboardPanelPlace.height(stored: 0.01, page: 1000), WhiteboardNote.panelFloor, "about four lines")
  }

  func testDraggingTheGripKeepsAShareOfThePage() {
    let taller = WhiteboardPanelPlace.resized(from: 200, by: 150, page: 1000)
    XCTAssertEqual(taller, 0.35, accuracy: 0.0001)
    XCTAssertEqual(WhiteboardPanelPlace.resized(from: 200, by: 5000, page: 1000), WhiteboardPanelPlace.tallest)
    XCTAssertEqual(WhiteboardPanelPlace.resized(from: 200, by: -5000, page: 1000), 0.12, accuracy: 0.0001)
  }

  func testTheCardStartsTopLeftAndStaysOnTheBoard() {
    let area = (width: 1000.0, height: 800.0)
    let card = WhiteboardPanelPlace.Card.start
    let frame = card.frame(in: area)
    XCTAssertEqual(frame.x, WhiteboardPanelPlace.Card.margin, accuracy: 0.5, "at the left, clear of ? and Feedback")
    XCTAssertEqual(frame.y, WhiteboardPanelPlace.Card.margin, accuracy: 0.5, "at the top")

    let dragged = card.moved(dx: 5000, dy: 5000, in: area).frame(in: area)
    XCTAssertEqual(dragged.x + dragged.width, 1000, accuracy: 0.5, "never off the right edge")
    XCTAssertEqual(dragged.y + dragged.height, 800, accuracy: 0.5, "never off the bottom")
    let back = card.moved(dx: -5000, dy: -5000, in: area).frame(in: area)
    XCTAssertEqual(back.x, 0, accuracy: 0.5)
    XCTAssertEqual(back.y, 0, accuracy: 0.5)
  }

  /// #1491: the grip is at the card's top left; it grows the card up and left, its bottom right staying put.
  func testTheCardResizesByItsTopLeftCornerWithinBounds() {
    let area = (width: 1000.0, height: 800.0)
    let card = WhiteboardPanelPlace.Card(x: 0.4, y: 0.4, width: 0.3, height: 0.25)
    let f = card.frame(in: area)

    let grown = card.resized(dx: -100, dy: -80, in: area).frame(in: area)
    XCTAssertEqual(grown.width, f.width + 100, accuracy: 0.5, "wider to the left")
    XCTAssertEqual(grown.height, f.height + 80, accuracy: 0.5, "taller upwards")
    XCTAssertEqual(grown.x + grown.width, f.x + f.width, accuracy: 0.5, "the right edge stays put")
    XCTAssertEqual(grown.y + grown.height, f.y + f.height, accuracy: 0.5, "the bottom stays put")

    let small = card.resized(dx: 5000, dy: 5000, in: area).frame(in: area)
    XCTAssertEqual(small.width, WhiteboardPanelPlace.Card.narrowest, accuracy: 0.5)
    XCTAssertEqual(small.height, WhiteboardPanelPlace.Card.shortest, accuracy: 0.5)
    XCTAssertEqual(small.x + small.width, f.x + f.width, accuracy: 0.5, "shrinks toward its bottom right")
    XCTAssertEqual(small.y + small.height, f.y + f.height, accuracy: 0.5)

    let big = card.resized(dx: -5000, dy: -5000, in: area).frame(in: area)
    XCTAssertEqual(big.x, 0, accuracy: 0.5, "stops at the board's left edge")
    XCTAssertEqual(big.y, 0, accuracy: 0.5, "stops at the board's top")
    XCTAssertEqual(big.x + big.width, f.x + f.width, accuracy: 0.5)
    XCTAssertEqual(big.y + big.height, f.y + f.height, accuracy: 0.5)
  }

  func testTheCardIsKeptAsTextAndAnythingElseIsTheStart() {
    let card = WhiteboardPanelPlace.Card(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    XCTAssertEqual(WhiteboardPanelPlace.Card(stored: card.stored), card)
    XCTAssertEqual(WhiteboardPanelPlace.Card(stored: ""), .start)
    XCTAssertEqual(WhiteboardPanelPlace.Card(stored: "nonsense"), .start)
  }
}
