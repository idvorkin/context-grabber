import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Stories 940–942: a kept text reworded in place, as the web board's `rewordText` does it.
final class BoardRewordTests: XCTestCase {
  // MARK: Stories 940, 941: what done with the field's words means

  func testNewWordsAreTrimmedAndCappedEmptyDeletesSameChangesNothing() {
    XCTAssertEqual(BoardReword.outcome(old: "hello", edited: "  hello world \n"), .reword("hello world"))
    XCTAssertEqual(BoardReword.outcome(old: "hello", edited: " \n "), .delete)
    XCTAssertEqual(BoardReword.outcome(old: "hello", edited: ""), .delete)
    XCTAssertEqual(BoardReword.outcome(old: "hello", edited: "hello "), .unchanged)
    XCTAssertEqual(BoardReword.outcome(old: "buy milk\nand eggs", edited: "buy milk\nand eggs"), .unchanged)
    XCTAssertEqual(
      BoardReword.outcome(old: "a", edited: String(repeating: "x", count: 600)),
      .reword(String(repeating: "x", count: 500)), "the paste cap holds")
  }

  func testItWrapsAtTheWiderOfItsOwnWidthAndTheWebBoardsWithinThePage() {
    let page: CGFloat = 820
    XCTAssertEqual(
      BoardReword.width(box: CGRect(x: 100, y: 0, width: 40, height: 20), pageRight: page), 480, "a short text: 480")
    XCTAssertEqual(
      BoardReword.width(box: CGRect(x: 60, y: 0, width: 600, height: 20), pageRight: page), 600,
      "a wide one keeps its own")
    XCTAssertEqual(
      BoardReword.width(box: CGRect(x: 500, y: 0, width: 40, height: 20), pageRight: page), 300, "not past the page")
    XCTAssertEqual(
      BoardReword.width(box: CGRect(x: 700, y: 0, width: 40, height: 20), pageRight: page), 160, "never under 160")
  }

  #if canImport(CoreText)
    func testWordsWrapByWordKeepTheirOwnBreaksAndALongWordBreaks() {
      let one = BoardReword.measure("word", size: 20, face: .print)
      XCTAssertGreaterThan(one, 20)
      let width = one * 2.6  // two words and a space fit, three don't
      XCTAssertEqual(
        BoardReword.rows("word word word word", width: width, size: 20, face: .print), ["word word", "word word"])
      XCTAssertEqual(BoardReword.rows("one\n\ntwo\n\n", width: 400, size: 20, face: .print), ["one", "", "two"])
      let long = String(repeating: "m", count: 40)
      let rows = BoardReword.rows("a " + long, width: width, size: 20, face: .print)
      XCTAssertEqual(rows.first, "a")
      XCTAssertEqual(rows.dropFirst().joined(), long, "broken across rows, none lost")
      XCTAssertTrue(rows.allSatisfy { BoardReword.measure($0, size: 20, face: .print) <= width })
    }

    func testTheNewWordsStartWhereTheOldOnesDid() {
      // The old text as the board drew it from (100, 200): its glyphs' box is inside its line.
      let size: CGFloat = 24
      let drawn = BoardReword.lines(["Hello"], topLeft: CGPoint(x: 100, y: 200), size: size, face: .print)
      let box = BoardReword.bounds(drawn.flatMap { WhiteboardTurn.lines($0, frame: .zero, scale: 1) })
      XCTAssertGreaterThan(box.minY, 200, "letters sit below their line's top")
      let start = BoardReword.topLeft(of: "Hello", size: size, face: .print, box: box)
      XCTAssertEqual(start.x, 100, accuracy: 0.01)
      XCTAssertEqual(start.y, 200, accuracy: 0.01)
      let rows = BoardReword.lines(["Hi", "", "there"], topLeft: start, size: size, face: .print)
      XCTAssertEqual(rows.map(\.text), ["Hi", "there"], "an empty row draws nothing")
      XCTAssertEqual(rows[1].points[0].y, 200 + 2 * size * BoardToText.leading, accuracy: 0.01, "and keeps its room")
    }
  #endif

  // MARK: Story 942: the same text to Larry

  func testAnUndoneWordingsVersionDoesntDissolveTheText() {
    var metas = BoardStrokeMeta()
    let old = BoardText(id: "text-1", t: 100, text: "hello", font: .plain, size: 20, color: "#000000", glyphs: 5)
    let new = BoardText(id: "text-1", t: 500, text: "hi", font: .plain, size: 20, color: "#000000", glyphs: 2)
    let glyph = { (id: String, t: Int64) in
      BoardOps.Stroke(ids: [id], t: t, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
    }
    // Reworded: the old glyphs erased, the new ones live.
    var texts = [old, new]
    XCTAssertEqual(
      BoardDissolve.dissolve(
        erased: ["o1", "o2", "o3", "o4", "o5"], live: [glyph("n1", 500), glyph("n2", 500)], metas: &metas,
        texts: &texts), [])
    XCTAssertEqual(texts, [old, new])
    // Undone: the old ones back, the new ones gone.
    let back = (1...5).map { glyph("o\($0)", 100) }
    XCTAssertEqual(BoardDissolve.dissolve(erased: ["n1", "n2"], live: back, metas: &metas, texts: &texts), [])
    // Larry reads it under its one id, in the words whose glyphs are on the board.
    let placed = WhiteboardStrokes.placedTexts(
      back.map { WhiteboardStrokes.Stroke(id: $0.ids[0], t: $0.t, points: [.zero, CGPoint(x: 5, y: 5)]) },
      texts: texts)
    XCTAssertEqual(placed.map(\.text.text), ["hello"])
    // Part of the live wording erased still dissolves it, once.
    XCTAssertEqual(
      BoardDissolve.dissolve(erased: ["o5"], live: Array(back.prefix(4)), metas: &metas, texts: &texts), ["text-1"])
    XCTAssertTrue(texts.isEmpty, "every wording of it is plain ink now")
  }

  func testLarryHearsWhichTextWasReworded() {
    let event = BoardEvent.strokesChanged(
      added: ["n1"], erased: ["o1"], moved: [], rev: 3, t: 9, reworded: ["text-1"]
    ).wire
    XCTAssertEqual(event["type"] as? String, "strokes_changed")
    XCTAssertEqual(event["reworded"] as? [String], ["text-1"])
    XCTAssertNil(BoardEvent.strokesChanged(added: [], erased: [], moved: [], rev: 3, t: 9).wire["reworded"])
  }

  // MARK: Story 940 (bead context-grabber-4ief): Return is done, however the field's words change

  func testAReturnTypedOnItsOwnIsDoneAndTheLineIsNotKept() {
    XCTAssertEqual(BoardReword.typedReturn(before: "hello world", after: "hello world\n"), "hello world")
    XCTAssertEqual(BoardReword.typedReturn(before: "hello world", after: "hello\n world"), "hello world")
  }

  func testAReturnArrivingWithOtherLettersAtOnceIsDoneToo() {
    // The field read "hello" and the next change brought " world" and the Return together (fast typing, a paste or
    // dictation ending in a line, or a busy device): still done, with the letters kept and the line not.
    XCTAssertEqual(BoardReword.typedReturn(before: "hello", after: "hello world\n"), "hello world")
    XCTAssertEqual(BoardReword.typedReturn(before: "hello", after: "say hello\n"), "say hello")
  }

  func testTheTextsOwnLineBreaksStayAndNoNewLineIsNotDone() {
    XCTAssertNil(BoardReword.typedReturn(before: "one\ntwo", after: "one\ntwos"), "no new line: still editing")
    XCTAssertEqual(BoardReword.typedReturn(before: "one\ntwo", after: "one\ntwo three\n"), "one\ntwo three")
    XCTAssertNil(BoardReword.typedReturn(before: "hello", after: "hell"), "a letter taken away")
    XCTAssertNil(BoardReword.typedReturn(before: "hello", after: "hello"))
  }
}
