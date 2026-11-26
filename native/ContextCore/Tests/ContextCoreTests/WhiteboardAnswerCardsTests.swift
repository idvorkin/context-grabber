import XCTest

@testable import ContextCore

/// Answer cards (#1439, stories 1355–1357): Larry's `answer` shape lands as a card, or answers the question card it
/// names, and then behaves like an answered card.
final class WhiteboardAnswerCardsTests: XCTestCase {

  private let thread = Data(
    #"""
    {"ok": true, "messages": [
      {"id": "m1", "who": "igor", "text": "", "frame": {"x": 0, "y": 0, "w": 400, "h": 300, "scale": 1},
       "shapes": [{"kind": "answer", "text": "not mine", "x": 1, "y": 1}]},
      {"id": "m2", "who": "larry", "text": "here", "frame": {"x": 100, "y": 2000, "w": 400, "h": 300, "scale": 2},
       "shapes": [{"kind": "question", "ask": "b-1", "x": 0, "y": 0},
                  {"kind": "answer", "title": "Gym", "text": "Renew it: you went 3x a week.", "x": 200, "y": 80},
                  {"kind": "answer", "text": "Yes.\nBecause it fits.", "x": 0, "y": 200, "re": "b-7"},
                  {"kind": "answer", "title": "empty", "text": "  ", "x": 5, "y": 5}]},
      {"id": "m3", "who": "larry", "text": "no frame", "shapes": [{"kind": "answer", "text": "x", "x": 0, "y": 0}]}
    ]}
    """#.utf8)

  // MARK: Story 1355: Larry's answer lands as a card

  func testLarrysAnswerShapeIsReadByTheRowsFrame() {
    XCTAssertEqual(
      WhiteboardQuestions.answerPlacements(thread),
      [
        .init(mark: "m2#1", title: "Gym", text: "Renew it: you went 3x a week.", re: nil, at: CGPoint(x: 200, y: 2040)),
        .init(mark: "m2#2", title: nil, text: "Yes.\nBecause it fits.", re: "b-7", at: CGPoint(x: 100, y: 2100)),
      ], "Larry's alone, with words, by the row's frame and scale; a row with no frame has nowhere to go")
  }

  func testAnAnswerLandsOnceAsLarrysCard() throws {
    var board = WhiteboardQuestions()
    let placements = WhiteboardQuestions.answerPlacements(thread)
    XCTAssertEqual(board.landAnswers(placements), 2)
    XCTAssertEqual(board.landAnswers(placements), 0, "a mark lands once")
    let gym = try XCTUnwrap(board.cards.first { $0.answered?.title == "Gym" })
    XCTAssertTrue(gym.fromLarry)
    XCTAssertFalse(gym.needsAnswer, "nothing to fetch from the Cockpit")
    XCTAssertEqual(gym.y, 2040)
    XCTAssertEqual(
      WhiteboardQuestions.lines(gym, title: nil), ["Larry · Gym", "Renew it: you went 3x a week."])
    let untitled = try XCTUnwrap(board.cards.first { $0.answered?.label.hasPrefix("Yes") == true })
    XCTAssertEqual(
      WhiteboardQuestions.lines(untitled, title: nil), ["Larry · Yes.", "Yes.\nBecause it fits."],
      "no title: his first line is the title")
    XCTAssertTrue(board.wanted(open: []).isEmpty, "answer cards ask the Cockpit for nothing")
  }

  // MARK: Story 1356: an answer to a question card answers it, as on the web board

  func testAnAnswerNamingAQuestionCardAnswersItAndLandsUnderIt() throws {
    var board = WhiteboardQuestions()
    board.add(ask: "b-7", x: 80, y: 40)
    XCTAssertEqual(board.landAnswers(WhiteboardQuestions.answerPlacements(thread)), 2)
    let card = try XCTUnwrap(board.cards.first { $0.ask == "b-7" })
    XCTAssertFalse(card.fromLarry)
    XCTAssertTrue(card.collapsed)
    XCTAssertEqual(card.y, 40, "it stays where it was")
    XCTAssertEqual(
      WhiteboardQuestions.lines(card, title: nil), ["✓ Yes."], "collapsed to the answer's title, as the web does")
    let answer = try XCTUnwrap(board.cards.first { $0.ask == "answer:m2#2" })
    XCTAssertTrue(answer.fromLarry)
    XCTAssertEqual(answer.x, card.x)
    XCTAssertEqual(answer.y, 40 + WhiteboardQuestions.height + 8, "under the question card")
    XCTAssertEqual(WhiteboardQuestions.lines(answer, title: nil), ["Larry · Yes.", "Yes.\nBecause it fits."])
  }

  func testAnAnswerNamingAQuestionNotOnTheBoardLandsAsItsOwnCard() {
    var board = WhiteboardQuestions()
    XCTAssertEqual(board.landAnswers(WhiteboardQuestions.answerPlacements(thread)), 2)
    XCTAssertEqual(board.cards.filter(\.fromLarry).count, 2)
  }

  // MARK: Story 1357: it folds, moves, archives and erases like an answered card

  func testAnAnswerCardFoldsAndTheEraserTakesIt() throws {
    var board = WhiteboardQuestions()
    board.landAnswers(WhiteboardQuestions.answerPlacements(thread))
    let gym = try XCTUnwrap(board.cards.first { $0.answered?.title == "Gym" })
    XCTAssertTrue(board.collapse(gym.id, true))
    XCTAssertEqual(WhiteboardQuestions.lines(try XCTUnwrap(board.card(gym.id)), title: nil), ["Larry · Gym"])
    XCTAssertNotNil(board.move(gym.id, to: CGPoint(x: 300, y: 500)))
    let box = WhiteboardQuestions.box(try XCTUnwrap(board.card(gym.id)))
    let gone = board.erase(crossing: [CGPoint(x: box.midX, y: box.midY)])
    XCTAssertEqual(gone.map(\.id), [gym.id])
  }

  func testABoardKeptBeforeAnswerCardsReadsAsQuestions() throws {
    let old = Data(#"{"id": "c", "ask": "b-1", "x": 80, "y": 40}"#.utf8)
    XCTAssertFalse(try JSONDecoder().decode(WhiteboardQuestion.self, from: old).fromLarry)
    var board = WhiteboardQuestions()
    board.landAnswers(WhiteboardQuestions.answerPlacements(thread))
    let kept = try JSONDecoder().decode(WhiteboardQuestions.self, from: JSONEncoder().encode(board))
    XCTAssertEqual(kept, board, "answer cards keep with the board")
  }
}
