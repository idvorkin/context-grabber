import XCTest

@testable import ContextCore

/// A question card's looks (spec 2026-11-16-whiteboard-question-cards-design.md, *The card's looks*; stories 1319–1321,
/// #1387 part 3, words agreed with Larry for the app and the web board): full, short (answered only) and round (open '?',
/// answered '✓'). Collapse steps one look smaller, Open out goes back to full, and a double tap is Collapse that wraps
/// from round to full.
final class WhiteboardQuestionsLooksTests: XCTestCase {

  private func board() -> (WhiteboardQuestions, open: String, answered: String) {
    var board = WhiteboardQuestions()
    board.add(ask: "open", x: 100, y: 200)
    board.add(ask: "answered", x: 100, y: 400)
    board.answer(board.cards[1].id, .init(title: "Renew?", label: "Renew"))
    return (board, board.cards[0].id, board.cards[1].id)
  }

  private func look(_ board: WhiteboardQuestions, _ id: String) -> WhiteboardQuestion.Look? { board.card(id)?.look }

  // MARK: Story 1319: Collapse steps one look smaller; a double tap cycles

  func testCollapseStepsAnAnsweredCardFullThenShortThenRound() {
    var (board, _, answered) = board()
    XCTAssertEqual(look(board, answered), .full)
    XCTAssertEqual(board.collapseStep(answered), .short)
    XCTAssertEqual(board.collapseStep(answered), .round)
    XCTAssertNil(board.collapseStep(answered), "a round is as small as it gets")
    XCTAssertEqual(look(board, answered), .round)
  }

  func testCollapseTakesAnOpenCardStraightToRound() {
    var (board, open, _) = board()
    XCTAssertEqual(board.collapseStep(open), .round, "an open card is already one line: no short")
  }

  func testOpenOutGoesBackToFullFromAnyLook() {
    var (board, _, answered) = board()
    board.collapseStep(answered)
    XCTAssertEqual(board.openOut(answered), .full)
    board.collapseStep(answered)
    board.collapseStep(answered)
    XCTAssertEqual(board.openOut(answered), .full)
    XCTAssertNil(board.openOut(answered), "already full")
  }

  func testADoubleTapCyclesAndWrapsFromRoundToFull() {
    var (board, open, answered) = board()
    XCTAssertEqual([board.cycle(answered), board.cycle(answered), board.cycle(answered)], [.short, .round, .full])
    XCTAssertEqual([board.cycle(open), board.cycle(open)], [.round, .full])
    XCTAssertNil(board.cycle("nobody"))
  }

  // MARK: Story 1320: an answered round is a ✓; an answered card reads as text

  func testAnAnsweredRoundIsATickAndAnOpenOneAQuestionMark() {
    var (board, open, answered) = board()
    board.cycle(open)
    board.cycle(answered)
    board.cycle(answered)
    XCTAssertEqual(WhiteboardQuestions.lines(board.card(open)!, title: "Q"), ["?"])
    XCTAssertEqual(WhiteboardQuestions.lines(board.card(answered)!, title: nil), ["✓"])
  }

  // MARK: Story 1321: the controls a look allows, in one fixed order

  func testEachLookOffersItsControlsInOneOrder() {
    var (board, open, answered) = board()
    XCTAssertEqual(WhiteboardQuestions.controls(board.card(open)!), [.collapse, .archive, .thinking])
    board.think(open)
    XCTAssertEqual(WhiteboardQuestions.controls(board.card(open)!), [.collapse, .archive, .thinking])
    XCTAssertEqual(WhiteboardQuestions.controls(board.card(answered)!), [.collapse, .archive])
    board.collapseStep(answered)
    XCTAssertEqual(WhiteboardQuestions.controls(board.card(answered)!), [.collapse, .openOut, .archive])
    board.collapseStep(answered)
    XCTAssertEqual(WhiteboardQuestions.controls(board.card(answered)!), [], "a round carries no strip")
    XCTAssertEqual(
      WhiteboardQuestion.Control.allCases, [.collapse, .openOut, .archive, .thinking], "the strip's one order")
  }

  func testTheStripSitsAtTheSamePlaceInEveryLook() {
    var (board, _, answered) = board()
    let full = WhiteboardQuestions.strip(board.card(answered)!)
    board.collapseStep(answered)
    XCTAssertEqual(WhiteboardQuestions.strip(board.card(answered)!), full, "short: the strip doesn't move")
    XCTAssertLessThanOrEqual(
      full.x + WhiteboardQuestions.stripWidth, 100 + WhiteboardQuestions.width, "inside a full card's right end")
    XCTAssertGreaterThan(full.x, 100 + WhiteboardQuestions.width / 2, "at its right end")
    XCTAssertEqual(full.y + WhiteboardQuestions.control / 2, 400 + WhiteboardQuestions.height / 2, "on its line")
    var far = WhiteboardQuestions()
    far.add(ask: "edge", x: 5_000, y: 0)
    let edge = WhiteboardQuestions.strip(far.cards[0])
    XCTAssertLessThanOrEqual(
      edge.x + WhiteboardQuestions.stripWidth, BoardPages.pageWidth, "a card at the page's edge keeps its strip on it")
    board.move(answered, to: CGPoint(x: 5_000, y: 400))
    let short = WhiteboardQuestions.strip(board.card(answered)!)
    XCTAssertLessThanOrEqual(
      short.x + WhiteboardQuestions.stripWidth, BoardPages.pageWidth,
      "a short card dragged to the edge keeps its strip on it")
  }
}
