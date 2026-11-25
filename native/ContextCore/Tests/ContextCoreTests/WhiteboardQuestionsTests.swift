import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Question cards on a board (spec 2026-11-16-whiteboard-question-cards-design.md, stories 880–886): where a card lands,
/// once per ask; which open asks name a board; what an answer leaves on the card; the answers fetched for asks closed
/// elsewhere; folding; the eraser; and the Cockpit's wire.
final class WhiteboardQuestionsTests: XCTestCase {

  private func ask(_ id: String, title: String = "Renew the gym?", thread: String? = nil, context: String = "")
    throws -> ChatAsk
  {
    var json: [String: Any] = [
      "id": id, "title": title, "context": context, "updated_at": "2026-11-16T10:00:00Z",
      "options": [["key": "yes", "label": "Renew"], ["key": "no", "label": "Let it lapse"]],
    ]
    json["thread"] = thread ?? NSNull()
    let data = try JSONSerialization.data(withJSONObject: ["ok": true, "asks": [json]])
    return try XCTUnwrap(ChatDecisions.asks(data)?.first)
  }

  // MARK: Story 880: Larry's question lands once, where he put it

  func testLarrysQuestionMarkLandsAtHisPlaceByTheRowsFrame() throws {
    let thread = Data(
      #"""
      {"ok": true, "messages": [
        {"id": "m1", "who": "igor", "text": "", "shapes": [{"kind": "question", "ask": "b-9", "x": 1, "y": 1}]},
        {"id": "m2", "who": "larry", "text": "one for you", "frame": {"x": 100, "y": 2000, "w": 400, "h": 300, "scale": 2},
         "shapes": [{"kind": "arrow", "points": [[0, 0], [10, 10]]}, {"kind": "question", "ask": "b-1", "x": 200, "y": 80},
                    {"kind": "question", "x": 5, "y": 5}]},
        {"id": "m3", "who": "larry", "text": "no frame", "shapes": [{"kind": "question", "ask": "b-2", "x": 0, "y": 0}]}
      ]}
      """#.utf8)
    let placements = WhiteboardQuestions.placements(thread)
    XCTAssertEqual(
      placements, [.init(mark: "m2#1", ask: "b-1", at: CGPoint(x: 200, y: 2040))],
      "Larry's alone, with an ask, by the row's frame and scale; a row with no frame has nowhere to go")
    var board = WhiteboardQuestions()
    XCTAssertEqual(board.land(placements), 1)
    XCTAssertEqual(board.cards.first?.ask, "b-1")
    XCTAssertEqual(board.cards.first?.y, 2040)
    XCTAssertEqual(board.land(placements), 0, "a mark lands once")
    XCTAssertEqual(board.cards.count, 1)
  }

  func testACardIsOncePerAskAndInsideThePage() {
    var board = WhiteboardQuestions()
    XCTAssertTrue(board.add(ask: "b-1", x: 700, y: 50))
    XCTAssertEqual(board.cards[0].x, BoardPages.pageWidth - WhiteboardQuestions.width - 8, "kept inside the page")
    XCTAssertFalse(board.add(ask: "b-1", x: 100, y: 500), "once per ask on a board")
    XCTAssertTrue(board.add(ask: "b-2", x: -40, y: 10))
    XCTAssertEqual(board.cards[1].x, BoardPages.margin + 8)
    XCTAssertFalse(board.add(ask: "", x: 100, y: 100), "no ask, no card")
  }

  func testAnErasedCardsMarkNeverLandsAgain() {
    var board = WhiteboardQuestions()
    let mark = WhiteboardQuestions.Placement(mark: "m#0", ask: "b-1", at: CGPoint(x: 100, y: 100))
    board.land([mark])
    board.answer(board.cards[0].id, .init(title: "Q", label: "A"))
    XCTAssertEqual(board.erase(crossing: [CGPoint(x: 120, y: 110)]).count, 1)
    XCTAssertEqual(board.land([mark]), 0, "a mark is remembered once landed, even erased")
    XCTAssertTrue(board.cards.isEmpty)
  }

  // MARK: Story 881: open asks naming the board

  func testAnOpenAskNamesTheBoardByItsThreadOrInItsContext() throws {
    let keys = ["igor2-88g.900", "board-1"]
    XCTAssertTrue(WhiteboardQuestions.namesBoard(try ask("a", thread: "igor2-88g.900"), keys: keys))
    XCTAssertTrue(WhiteboardQuestions.namesBoard(try ask("b", context: "About the drawing on board-1."), keys: keys))
    XCTAssertFalse(WhiteboardQuestions.namesBoard(try ask("c", thread: "igor2-88g.901"), keys: keys))
    XCTAssertFalse(WhiteboardQuestions.namesBoard(try ask("d"), keys: ["", "board-2"]), "an empty key names nothing")
  }

  func testOpenAsksLandAtTheTopOfTheScreenOneUnderAnother() throws {
    var board = WhiteboardQuestions()
    let asks = [try ask("a", thread: "t"), try ask("b"), try ask("c", context: "for t")]
    let landed = board.landOpen(asks, keys: ["t"], visible: CGRect(x: 0, y: 1000, width: 820, height: 900))
    XCTAssertEqual(landed, 2)
    XCTAssertEqual(board.cards.map(\.ask), ["a", "c"])
    XCTAssertEqual(board.cards.map(\.x), [WhiteboardQuestions.left, WhiteboardQuestions.left])
    XCTAssertEqual(board.cards.map(\.y), [1016, 1016 + WhiteboardQuestions.height + 8])
    XCTAssertEqual(board.landOpen(asks, keys: ["t"], visible: .null), 0, "each ask has its card")
  }

  // MARK: Stories 882, 883: answering

  func testAnAnswerLeavesTheQuestionOverTheAnswer() throws {
    let option = ChatAsk.Option(key: "yes", label: "Renew")
    XCTAssertEqual(
      WhiteboardQuestions.answer(for: .answer(option), title: "Renew the gym?"),
      .init(title: "Renew the gym?", label: "Renew"))
    XCTAssertEqual(
      WhiteboardQuestions.answer(for: .ownWords("  only monthly \n"), title: "Q"),
      .init(title: "Q", label: "only monthly"))
    XCTAssertEqual(
      WhiteboardQuestions.answer(for: .close(reason: "Booked it"), title: "Q"),
      .init(title: "Q", label: "Closed", note: "Booked it"))
    XCTAssertEqual(
      WhiteboardQuestions.answer(for: .abandon(reason: nil), title: "Q"), .init(title: "Q", label: "Abandoned"))
    XCTAssertNil(WhiteboardQuestions.answer(for: .snooze(.later), title: "Q"), "a snooze leaves the card open")
  }

  func testWhatACardSays() {
    var card = WhiteboardQuestion(id: "c", ask: "b-1", x: 80, y: 0)
    XCTAssertEqual(WhiteboardQuestions.lines(card, title: nil), ["? Question ···"], "until the asks are read")
    XCTAssertEqual(WhiteboardQuestions.lines(card, title: "Renew?"), ["? Renew? ···"])
    card.answered = .init(title: "Renew?", label: "Renew", note: "monthly")
    XCTAssertEqual(WhiteboardQuestions.lines(card, title: nil), ["✓ Renew?", "Renew — monthly"])
    card.collapsed = true
    XCTAssertEqual(WhiteboardQuestions.lines(card, title: nil), ["✓ Renew?"], "a chip is the question alone")
    card.answered = .unknown
    XCTAssertEqual(WhiteboardQuestions.lines(card, title: nil), ["✓ answered"])
    card.answered = .init(title: nil, label: "", note: "just a note")
    XCTAssertEqual(WhiteboardQuestions.answerText(card.answered!), "just a note")
  }

  // Its request: WhiteboardRequestsTests (ContextCore holds the HTTP requests).
  func testOwnWordsAreTheInboxsFreeTextAnswer() {
    XCTAssertEqual(
      ChatDecisions.Verb.ownWords("abc").logFields as NSDictionary, ["option": "own", "answer_chars": 3],
      "the log has the words' length, never the words")
    XCTAssertFalse(ChatDecisions.canSend(words: " \n "))
    XCTAssertTrue(ChatDecisions.canSend(words: "ok"))
  }

  // MARK: Story 884: answered elsewhere

  func testClosedAsksFetchTheirAnswerAndAMissingOneIsAskedAgain() {
    var board = WhiteboardQuestions()
    board.add(ask: "open", x: 80, y: 0)
    board.add(ask: "closed", x: 80, y: 50)
    board.add(ask: "gone", x: 80, y: 100)
    board.add(ask: "done", x: 80, y: 150)
    board.answer(board.cards[3].id, .init(title: "Q", label: "A"))
    let wanted = board.wanted(open: ["open"])
    XCTAssertEqual(wanted, ["closed", "gone"], "an open ask is answered here; a card holding its Q&A needs nothing")
    let got = WhiteboardQuestions.answers(
      Data(
        #"{"ok": true, "answers": {"closed": {"title": "Lunch?", "label": "Tacos", "note": "", "action": "respond"}}, "unknown": ["gone"]}"#
          .utf8))
    XCTAssertEqual(board.fill(try XCTUnwrap(got), asked: wanted), 2)
    XCTAssertEqual(board.cards[1].answered, .init(title: "Lunch?", label: "Tacos"))
    XCTAssertEqual(board.cards[2].answered, .unknown, "the placeholder for now")
    XCTAssertEqual(board.wanted(open: ["open"]), ["gone"], "and asked again next time")
    XCTAssertEqual(board.fill([:], asked: ["gone"]), 0, "the placeholder stays a placeholder")
    XCTAssertNil(WhiteboardQuestions.answers(Data(#"{"ok": false}"#.utf8)))
  }

  // MARK: Stories 885, 886: folding and the eraser

  func testOnlyAnAnsweredCardFoldsToAChipAsWideAsItsWords() {
    var board = WhiteboardQuestions()
    board.add(ask: "b-1", x: 80, y: 0)
    let id = board.cards[0].id
    XCTAssertFalse(board.collapse(id, true), "an open card doesn't fold")
    XCTAssertEqual(WhiteboardQuestions.box(board.cards[0]).width, WhiteboardQuestions.width)
    board.answer(id, .init(title: "Renew?", label: "Renew"))
    XCTAssertTrue(board.collapse(id, true))
    let chip = WhiteboardQuestions.box(board.cards[0])
    XCTAssertLessThan(chip.width, 120, "as wide as ✓ Renew?")
    XCTAssertEqual(chip.height, WhiteboardQuestions.height)
    XCTAssertTrue(board.collapse(id, false))
    XCTAssertFalse(board.cards[0].collapsed)
  }

  func testTheEraserTakesAnAnsweredCardAndLeavesAnOpenOne() {
    var board = WhiteboardQuestions()
    board.add(ask: "open", x: 80, y: 0)
    board.add(ask: "answered", x: 80, y: 100)
    board.answer(board.cards[1].id, .init(title: "Q", label: "A"))
    let stroke = [CGPoint(x: 300, y: 20), CGPoint(x: 300, y: 120)]
    XCTAssertEqual(board.erase(crossing: stroke).map(\.ask), ["answered"])
    XCTAssertEqual(board.cards.map(\.ask), ["open"])
    XCTAssertTrue(board.erase(crossing: [CGPoint(x: 300, y: 500)]).isEmpty, "a stroke elsewhere takes nothing")
  }

  func testTheCardsKeepWithTheBoard() throws {
    var board = WhiteboardQuestions()
    board.land([.init(mark: "m#0", ask: "b-1", at: CGPoint(x: 100, y: 100))])
    board.answer(board.cards[0].id, .init(title: "Q", label: "A", note: "n"))
    board.collapse(board.cards[0].id, true)
    let back = try JSONDecoder().decode(WhiteboardQuestions.self, from: try JSONEncoder().encode(board))
    XCTAssertEqual(back, board)
  }

  // MARK: Story 1273: a card hides to a bare '?' and comes back

  func testAnyCardHidesToAQuestionMarkAtItsLeftEndAndComesBackAsItWas() {
    var board = WhiteboardQuestions()
    board.add(ask: "open", x: 100, y: 200)
    board.add(ask: "chip", x: 100, y: 400)
    let open = board.cards[0].id
    let chip = board.cards[1].id
    board.answer(chip, .init(title: "Renew?", label: "Renew"))
    board.collapse(chip, true)

    XCTAssertTrue(board.hide(open, true))
    XCTAssertTrue(board.hide(chip, true))
    for card in board.cards {
      let box = WhiteboardQuestions.box(card)
      XCTAssertEqual(box.origin, CGPoint(x: card.x, y: card.y), "the '?' sits where the card's left end was")
      XCTAssertEqual(box.width, WhiteboardQuestions.mark)
      XCTAssertEqual(box.height, WhiteboardQuestions.mark)
      // #1387 part 3: an open round is a '?', an answered one a '✓', as on the web board.
      XCTAssertEqual(WhiteboardQuestions.lines(card, title: "Renew?"), [card.answered == nil ? "?" : "✓"])
    }
    XCTAssertNil(board.card(open)?.answered, "hiding answers nothing")

    XCTAssertTrue(board.hide(chip, false))
    XCTAssertEqual(board.card(chip)?.collapsed, true, "back as it was: still a chip")
    XCTAssertEqual(WhiteboardQuestions.lines(board.card(chip)!, title: nil), ["✓ Renew?"])
    XCTAssertFalse(board.hide("nobody", true))
  }

  func testTheEraserTakesAnAnsweredQuestionMarkAndLeavesAnOpenOne() {
    var board = WhiteboardQuestions()
    board.add(ask: "open", x: 100, y: 0)
    board.add(ask: "answered", x: 100, y: 100)
    board.answer(board.cards[1].id, .init(title: "Q", label: "A"))
    board.hide(board.cards[0].id, true)
    board.hide(board.cards[1].id, true)
    XCTAssertEqual(board.erase(crossing: [CGPoint(x: 400, y: 0), CGPoint(x: 400, y: 140)]).count, 0, "past the '?'")
    XCTAssertEqual(board.erase(crossing: [CGPoint(x: 110, y: 0), CGPoint(x: 110, y: 140)]).map(\.ask), ["answered"])
    XCTAssertEqual(board.cards.map(\.ask), ["open"])
  }

  func testABoardKeptBeforeHidingReadsAsShown() throws {
    let old = #"{"cards":[{"id":"c","ask":"b-1","x":80,"y":10,"collapsed":false}],"handled":[]}"#
    let board = try JSONDecoder().decode(WhiteboardQuestions.self, from: Data(old.utf8))
    XCTAssertEqual(board.cards.first?.hidden, false)
    var hidden = board
    hidden.hide("c", true)
    let back = try JSONDecoder().decode(WhiteboardQuestions.self, from: try JSONEncoder().encode(hidden))
    XCTAssertEqual(back, hidden)
    XCTAssertEqual(back.cards.first?.hidden, true)
  }

  // MARK: Story 1274: a card drags anywhere on the page

  func testACardMovesWhereItIsLetGoInsideThePage() {
    var board = WhiteboardQuestions()
    board.add(ask: "b-1", x: 100, y: 100)
    let id = board.cards[0].id
    XCTAssertEqual(board.move(id, to: CGPoint(x: 150, y: 900)), CGPoint(x: 150, y: 900))
    XCTAssertEqual(board.card(id).map { CGPoint(x: $0.x, y: $0.y) }, CGPoint(x: 150, y: 900))

    let right = board.move(id, to: CGPoint(x: 5000, y: -50))
    XCTAssertEqual(right?.y, 0, "never above the board")
    XCTAssertEqual(right?.x, BoardPages.pageWidth - WhiteboardQuestions.width - 8, "a card stops at the page's edge")
    let left = board.move(id, to: CGPoint(x: -300, y: 10))
    XCTAssertEqual(left?.x, BoardPages.margin + 8)

    board.hide(id, true)
    let mark = board.move(id, to: CGPoint(x: 5000, y: 10))
    XCTAssertEqual(
      mark?.x, BoardPages.pageWidth - WhiteboardQuestions.mark - 8, "a '?' goes as far as its own width allows")
    XCTAssertNil(board.move("nobody", to: .zero))
  }

  func testAQuestionMarkDraggedToTheEdgeComesBackAsACardInsideThePage() {
    var board = WhiteboardQuestions()
    board.add(ask: "b-1", x: 100, y: 100)
    let id = board.cards[0].id
    board.hide(id, true)
    board.move(id, to: CGPoint(x: 5000, y: 10))
    XCTAssertTrue(board.hide(id, false))
    let card = board.card(id)!
    XCTAssertFalse(card.hidden)
    XCTAssertEqual(card.x, BoardPages.pageWidth - WhiteboardQuestions.width - 8, "shown again, the card fits the page")
    XCTAssertLessThanOrEqual(WhiteboardQuestions.box(card).maxX, BoardPages.pageWidth - 8)
  }
}
