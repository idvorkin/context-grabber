import XCTest

@testable import ContextCore

/// Stories 1352, 1353 (#1525): a reply of Larry's names the choices beside it; the board shows the ones it knows.
final class WhiteboardMarkActionsTests: XCTestCase {
  func testNoChoicesIsKeepAndDismiss() {
    let offered = WhiteboardMarkActions.parse(nil)
    XCTAssertEqual(offered.offers.map(\.action), [.keep, .dismiss])
    XCTAssertTrue(offered.unknown.isEmpty)
  }

  func testTheReplysOrderAndLabels() {
    let offered = WhiteboardMarkActions.parse([["id": "dismiss", "label": "Not now"], ["id": "keep"]])
    XCTAssertEqual(offered.offers.map(\.action), [.dismiss, .keep])
    XCTAssertEqual(offered.offers.map { $0.title(group: false) }, ["Not now", "Keep"])
    XCTAssertEqual(offered.offers[1].title(group: true), "Keep group", "the board's own name, for a group")
  }

  func testAPlainStringIsAChoice() {
    XCTAssertEqual(WhiteboardMarkActions.parse(["dismiss", "keep"]).offers.map(\.action), [.dismiss, .keep])
  }

  func testAnUnknownChoiceIsLeftOutAndNamed() {
    let offered = WhiteboardMarkActions.parse([["id": "keep"], ["id": "pin"]])
    XCTAssertEqual(offered.offers.map(\.action), [.keep])
    XCTAssertEqual(offered.unknown, ["pin"])
  }

  func testAllUnknownStillOffersKeepAndDismiss() {
    let offered = WhiteboardMarkActions.parse([["id": "pin"], "star"])
    XCTAssertEqual(offered.offers.map(\.action), [.keep, .dismiss])
    XCTAssertEqual(offered.unknown, ["pin", "star"])
  }

  func testTheLogCarriesAFewShortUnknownIDs() {
    let long = String(repeating: "x", count: 40)
    XCTAssertEqual(
      WhiteboardMarkActions.logged([long, "a", "b", "c", "d"]), [String(repeating: "x", count: 24), "a", "b", "c"])
  }

  func testAChoiceTwiceShowsOnce() {
    XCTAssertEqual(WhiteboardMarkActions.parse(["keep", "keep", "dismiss"]).offers.map(\.action), [.keep, .dismiss])
  }

  func testToQuestionAnswerIsNotKnownYet() {
    let offered = WhiteboardMarkActions.parse(["qa", "keep"])
    XCTAssertEqual(offered.offers.map(\.action), [.keep])
    XCTAssertEqual(offered.unknown, ["qa"])
  }

  func testDefaultTitles() {
    XCTAssertEqual(WhiteboardMarkActions.Offer(action: .keep).title(group: false), "Keep")
    XCTAssertEqual(WhiteboardMarkActions.Offer(action: .dismiss).title(group: true), "Dismiss group")
  }

  func testARowReadsItsChoices() {
    let row = WhiteboardMarks.row(["who": "larry", "id": "r1", "text": "", "actions": ["dismiss", "qa"]])
    XCTAssertEqual(row?.actions.map(\.action), [.dismiss])
    XCTAssertEqual(row?.unknownActions, ["qa"])
  }

  func testBlankLabelsUseStandardTitlesFromTheWireAndHistory() throws {
    let offered = WhiteboardMarkActions.parse([["id": "dismiss", "label": " \n\t "]])
    XCTAssertEqual(offered.offers.map { $0.title(group: false) }, ["Dismiss"])

    let saved = Data(#"{"action":"keep","label":" \n\t "}"#.utf8)
    let restored = try JSONDecoder().decode(WhiteboardMarkActions.Offer.self, from: saved)
    XCTAssertEqual(restored.title(group: true), "Keep group")
  }

  func testTextKeepsItsReplyOfferedActionsWhenANewerBatchMovesIt() throws {
    let row = try XCTUnwrap(
      WhiteboardMarks.row([
        "id": "r1", "who": "larry", "actions": ["qa", ["id": "dismiss", "label": "Not now"]],
        "ops": [
          "board": "b1", "base_rev": 0,
          "list": [
            ["op": "add_text", "id": "t1", "x": 80, "y": 100, "text": "A label"]
          ],
        ],
      ]))
    var source = WebBoardOpSource()
    let batch = try XCTUnwrap(source.batches(from: .rows([row])).first)
    let landed = BoardOps.plan(batch.lettered(.single).ops, strokes: [], pages: 1)
    let first = try XCTUnwrap(landed.texts.first)
    XCTAssertEqual(first.markOffers?.map(\.action), [.dismiss])
    XCTAssertEqual(first.markOffers?.map { $0.title(group: false) }, ["Not now"])

    let moved = BoardOps.plan(
      [.translateIDs(["t1"], dx: 20, dy: 10)], strokes: [], ghosts: landed.texts, pages: 1)
    let later = try XCTUnwrap(moved.texts.first)
    XCTAssertEqual(later.x, 100)
    XCTAssertEqual(later.y, first.y + 10)
    XCTAssertEqual(later.markOffers?.map(\.action), [.dismiss])
    XCTAssertEqual(later.markOffers?.map { $0.title(group: false) }, ["Not now"])
  }
}
