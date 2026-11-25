import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Question cards archive and think over (spec 2026-11-16-whiteboard-question-cards-design.md, *Archiving a card* and
/// *Thinking it over*; stories 1314–1317, #1387): an archived card leaves the board and never lands again by itself,
/// reopens where it was, as it was; Thinking marks an open card and its words go to the ask's own chat thread.
final class WhiteboardQuestionsArchiveTests: XCTestCase {

  private func board() -> (WhiteboardQuestions, open: String, answered: String) {
    var board = WhiteboardQuestions()
    board.add(ask: "open", x: 100, y: 200)
    board.add(ask: "answered", x: 120, y: 400)
    let open = board.cards[0].id
    let answered = board.cards[1].id
    board.answer(answered, .init(title: "Renew?", label: "Renew"))
    board.collapse(answered, true)
    board.hide(answered, true)
    return (board, open, answered)
  }

  // MARK: Story 1314: a card archives off the board

  func testAnArchivedCardLeavesTheBoardAndAnsweresNothing() {
    var (board, open, answered) = board()
    XCTAssertTrue(board.archive(open, at: 1_000))
    XCTAssertEqual(board.shown.map(\.id), [answered], "only the other card is on the board")
    XCTAssertNil(board.card(open)?.answered, "archiving answers nothing")
    XCTAssertFalse(board.archive(open, at: 2_000), "already archived")
    XCTAssertFalse(board.archive("nobody", at: 2_000))
  }

  func testAnArchivedCardNeverLandsAgainByItself() throws {
    var (board, open, _) = board()
    board.archive(open, at: 1_000)
    XCTAssertEqual(board.land([.init(mark: "m#9", ask: "open", at: CGPoint(x: 300, y: 300))]), 0)
    let ask = try XCTUnwrap(
      ChatDecisions.asks(
        try JSONSerialization.data(withJSONObject: [
          "ok": true,
          "asks": [
            ["id": "open", "title": "Q", "context": "board-1", "updated_at": "2026-11-24T10:00:00Z", "options": []]
          ],
        ]))?.first)
    XCTAssertEqual(board.landOpen([ask], keys: ["board-1"], visible: .null), 0)
    XCTAssertEqual(board.shown.count, 1)
  }

  func testTheEraserCantReachAnArchivedCard() {
    var (board, _, answered) = board()
    board.archive(answered, at: 1_000)
    XCTAssertTrue(board.erase(crossing: [CGPoint(x: 130, y: 390), CGPoint(x: 130, y: 450)]).isEmpty)
    XCTAssertNotNil(board.card(answered), "still kept, archived")
  }

  func testAnArchivedOpenCardStillGetsItsAnswer() {
    var (board, open, _) = board()
    board.archive(open, at: 1_000)
    XCTAssertEqual(board.wanted(open: []), ["open"], "answered elsewhere, its answer is still fetched")
  }

  // MARK: Story 1315: an archived card reopens where it was, as it was

  func testArchivedNewestFirstAndReopenedAsItWas() {
    var (board, open, answered) = board()
    board.archive(open, at: 1_000)
    board.archive(answered, at: 2_000)
    XCTAssertEqual(board.archived.map(\.id), [answered, open], "newest archived first")
    XCTAssertTrue(board.shown.isEmpty)

    XCTAssertTrue(board.reopen(answered))
    let back = board.card(answered)
    XCTAssertEqual(back?.x, 120)
    XCTAssertEqual(back?.y, 400)
    XCTAssertEqual(back?.collapsed, true, "still a chip")
    XCTAssertEqual(back?.hidden, true, "still its '?'")
    XCTAssertEqual(back?.answered?.label, "Renew")
    XCTAssertEqual(board.archived.map(\.id), [open])
    XCTAssertFalse(board.reopen(answered), "not archived any more")
  }

  func testABoardKeptBeforeArchivingReadsAsOnTheBoard() throws {
    let old = #"{"cards":[{"id":"c","ask":"b-1","x":80,"y":10,"collapsed":false,"hidden":true}],"handled":[]}"#
    var board = try JSONDecoder().decode(WhiteboardQuestions.self, from: Data(old.utf8))
    XCTAssertEqual(board.shown.map(\.id), ["c"])
    XCTAssertEqual(board.card("c")?.thinking, false)
    board.archive("c", at: 5)
    board.think("c")
    let back = try JSONDecoder().decode(WhiteboardQuestions.self, from: try JSONEncoder().encode(board))
    XCTAssertEqual(back, board)
  }

  // MARK: Story 1316: Thinking marks an open card, and its words go to the ask's own thread

  func testOnlyAnOpenCardIsThoughtOverAndItsLineSaysSo() {
    var (board, open, answered) = board()
    XCTAssertFalse(board.think(answered), "an answered card has nothing to think over")
    XCTAssertTrue(board.think(open))
    let card = board.card(open)!
    XCTAssertEqual(WhiteboardQuestions.lines(card, title: "Renew the gym?"), ["… Renew the gym? ···"])
    board.answer(open, .init(title: "Renew the gym?", label: "Renew"))
    XCTAssertEqual(
      WhiteboardQuestions.lines(board.card(open)!, title: nil), ["✓ Renew the gym?", "Renew"],
      "answered, it reads as any answered card")
  }

  // The ask's conversation is read and posted by `WhiteboardRequestsTests` (requests live outside BoardCore).
}
