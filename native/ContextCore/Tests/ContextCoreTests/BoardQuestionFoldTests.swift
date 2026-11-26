import XCTest

@testable import ContextCore

/// Story 1354 (#1525): *To question/answer* makes the first line of Igor's question a header and folds Larry's kept
/// answer, and the rest of the question, under it; what Igor wrote after the answer stays out.
final class BoardQuestionFoldTests: XCTestCase {
  private func letter(_ id: String, x: CGFloat, y: CGFloat) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + 24), CGPoint(x: x + 10, y: y), CGPoint(x: x + 20, y: y + 24)]
    return BoardOps.Stroke(ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: 20, height: 24), points: points, pen: 3)
  }

  private func word(_ id: String, x: CGFloat, y: CGFloat) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y) }
  }

  private func hidden(_ o: BoardOutline, _ id: String) -> Bool {
    o.strokes.first { $0.ids.contains(id) }?.hidden ?? false
  }

  /// His question on two lines at y 100 and 140; Larry's kept answer (a group) at y 180 and 220; his next note at 300.
  private func board() -> BoardOutline {
    let question = word("q", x: 100, y: 100) + word("r", x: 100, y: 140)
    let answer = word("a", x: 100, y: 180) + word("b", x: 100, y: 220)
    let after = word("n", x: 100, y: 300)
    var groups: [String: String] = [:]
    for s in answer { for id in s.ids { groups[id] = "reply-1" } }
    return BoardOutline(strokes: question + answer + after, headers: [], groups: groups)
  }

  func testTheQuestionsFirstLineHeadsAFoldOfTheAnswer() {
    var o = board()
    let id = o.foldQuestion(in: CGRect(x: 80, y: 90, width: 300, height: 90), answerBottom: 244, id: "qa")
    XCTAssertEqual(id, "qa")
    XCTAssertEqual(o.header("qa")?.ids.sorted(), ["q0", "q1", "q2"], "the question's first line is the header")
    XCTAssertTrue(o.isFolded(o.header("qa")!))
    XCTAssertTrue(hidden(o, "r0"), "the rest of the question folds")
    XCTAssertTrue(hidden(o, "a0") && hidden(o, "b2"), "the answer folds")
    XCTAssertFalse(hidden(o, "n0"), "what he wrote after the answer stays out")
  }

  /// Larry (8abe63373b12): the question is the ink made since the turn before, not every older line in the picture.
  func testTheQuestionIsTheInkMadeSinceTheTurnBefore() {
    let older = word("o", x: 100, y: 60).map { stamped($0, 1_000) }
    let question = (word("q", x: 100, y: 100) + word("r", x: 100, y: 140)).map { stamped($0, 5_000) }
    let answer = word("a", x: 100, y: 180)
    var groups: [String: String] = [:]
    for s in answer { for id in s.ids { groups[id] = "reply-1" } }
    var o = BoardOutline(strokes: older + question + answer, headers: [], groups: groups)
    XCTAssertEqual(
      o.foldQuestion(
        in: CGRect(x: 80, y: 40, width: 300, height: 140), made: 2_000...6_000, answerBottom: 204, id: "qa"),
      "qa")
    XCTAssertEqual(o.header("qa")?.ids.sorted(), ["q0", "q1", "q2"], "the new ink's first line, not the older line")
    XCTAssertFalse(hidden(o, "o0"))
    XCTAssertTrue(hidden(o, "a0"))
  }

  func testNoInkMadeSinceTheTurnBeforeFoldsNothing() {
    var o = board()
    XCTAssertNil(
      o.foldQuestion(in: CGRect(x: 80, y: 90, width: 300, height: 90), made: 9_000...9_500, answerBottom: 244, id: "qa")
    )
    XCTAssertTrue(o.headers.isEmpty)
  }

  private func stamped(_ stroke: BoardOps.Stroke, _ t: Int64) -> BoardOps.Stroke {
    var stroke = stroke
    stroke.t = t
    return stroke
  }

  func testNoWritingOfHisInThePictureFoldsNothing() {
    var o = board()
    XCTAssertNil(o.foldQuestion(in: CGRect(x: 80, y: 400, width: 300, height: 90), answerBottom: 500, id: "qa"))
    XCTAssertTrue(o.headers.isEmpty)
  }

  func testAnAnswerWithNothingAfterItFoldsToTheEnd() {
    let question = word("q", x: 100, y: 100)
    let answer = word("a", x: 100, y: 140)
    var groups: [String: String] = [:]
    for s in answer { for id in s.ids { groups[id] = "reply-1" } }
    var o = BoardOutline(strokes: question + answer, headers: [], groups: groups)
    XCTAssertEqual(o.foldQuestion(in: CGRect(x: 80, y: 90, width: 300, height: 40), answerBottom: 164, id: "qa"), "qa")
    XCTAssertTrue(hidden(o, "a0"))
  }
}
