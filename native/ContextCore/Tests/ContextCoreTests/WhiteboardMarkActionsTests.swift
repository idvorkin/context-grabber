import XCTest

@testable import ContextCore

/// Stories 1352–1354 (#1525): a reply of Larry's names the choices beside it; the board shows the ones it knows.
final class WhiteboardMarkActionsTests: XCTestCase {
  func testNoChoicesIsKeepAndDismiss() {
    let offered = WhiteboardMarkActions.parse(nil)
    XCTAssertEqual(offered.offers.map(\.action), [.keep, .dismiss])
    XCTAssertTrue(offered.unknown.isEmpty)
  }

  func testTheReplysOrderAndLabels() {
    let offered = WhiteboardMarkActions.parse([
      ["id": "qa", "label": "Fold as Q&A"], ["id": "keep"], ["id": "dismiss", "label": "Not now"],
    ])
    XCTAssertEqual(offered.offers.map(\.action), [.questionAnswer, .keep, .dismiss])
    XCTAssertEqual(offered.offers.map { $0.title(group: false) }, ["Fold as Q&A", "Keep", "Not now"])
    XCTAssertEqual(offered.offers[1].title(group: true), "Keep group", "the board's own name, for a group")
  }

  func testAPlainStringIsAChoice() {
    XCTAssertEqual(WhiteboardMarkActions.parse(["keep", "qa"]).offers.map(\.action), [.keep, .questionAnswer])
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

  func testAChoiceTwiceShowsOnce() {
    XCTAssertEqual(WhiteboardMarkActions.parse(["keep", "keep", "dismiss"]).offers.map(\.action), [.keep, .dismiss])
  }

  func testDefaultTitles() {
    let qa = WhiteboardMarkActions.Offer(action: .questionAnswer)
    XCTAssertEqual(qa.title(group: false), "To question/answer")
    XCTAssertEqual(WhiteboardMarkActions.Offer(action: .dismiss).title(group: true), "Dismiss group")
  }

  func testARowReadsItsChoices() {
    let row = WhiteboardMarks.row(["who": "larry", "id": "r1", "text": "", "actions": ["dismiss", "qa"]])
    XCTAssertEqual(row?.actions.map(\.action), [.dismiss, .questionAnswer])
  }
}
