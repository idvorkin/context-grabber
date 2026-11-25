import XCTest

@testable import ContextCore

/// Story 1292 (cockpit-gvv): a margin-tap header is the one line tapped beside, even when a descender on it touches
/// the line below, and that touched line still belongs to the header's section.
final class BoardOutlineHeaderLineTests: XCTestCase {
  private func letter(_ id: String, x: CGFloat, y: CGFloat, w: CGFloat = 20, h: CGFloat = 24) -> BoardOps.Stroke {
    let points = [CGPoint(x: x, y: y + h), CGPoint(x: x + w / 2, y: y), CGPoint(x: x + w, y: y + h)]
    return BoardOps.Stroke(
      ids: [id], t: nil, bounds: CGRect(x: x, y: y, width: w, height: h), points: points, pen: 3)
  }

  private func word(_ id: String, x: CGFloat, y: CGFloat, h: CGFloat = 24) -> [BoardOps.Stroke] {
    (0..<3).map { letter("\(id)\($0)", x: x + CGFloat($0) * 24, y: y, h: h) }
  }

  /// "Big" at the margin with a g whose tail reaches 4 pt into the indented line under it, then a line back at the
  /// margin.
  private var board: [BoardOps.Stroke] {
    word("h", x: 100, y: 100) + [letter("hg", x: 172, y: 100, h: 40)] + word("a", x: 140, y: 136)
      + word("c", x: 100, y: 200)
  }

  func testAMarginTapTakesOnlyTheLineBesideItWhenADescenderTouchesTheNext() {
    var o = BoardOutline(strokes: board, headers: [])
    XCTAssertTrue(o.markHeader(at: 112, id: "h"))
    XCTAssertEqual(o.headers.first?.ids.sorted(), ["h0", "h1", "h2", "hg"], "the tapped line, its tail included")
  }

  func testTheLineTheDescenderTouchesFoldsWithTheHeader() {
    var o = BoardOutline(strokes: board, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2", "hg"])])
    XCTAssertTrue(o.fold("h"))
    let hidden = Set(o.strokes.filter(\.hidden).flatMap(\.ids))
    XCTAssertEqual(hidden, ["a0", "a1", "a2"], "the indented line under it folds; the line at the margin doesn't")
  }

  func testATapBesideTheTouchedLineIsThatLinesNotTheHeaderAbove() {
    var o = BoardOutline(strokes: board, headers: [BoardHeader(id: "h", ids: ["h0", "h1", "h2", "hg"])])
    XCTAssertNil(o.header(at: 148), "the tap is beside the indented line, not the header whose tail touches it")
    XCTAssertEqual(o.row(at: 148)?.names.sorted(), ["a0", "a1", "a2"])
    XCTAssertTrue(o.markHeader(at: 148, id: "a"))
    XCTAssertEqual(o.header(at: 148)?.id, "a")
    XCTAssertEqual(o.header(at: 112)?.id, "h", "beside the first line is still its header")
  }

  func testTheLineAboveATouchedHeaderStaysItsOwn() {
    var o = BoardOutline(strokes: board, headers: [BoardHeader(id: "a", ids: ["a0", "a1", "a2"])])
    XCTAssertEqual(o.row(at: 125)?.header, nil, "beside the line with the tail, not the header it touches")
    XCTAssertTrue(o.markHeader(at: 112, id: "h"))
    XCTAssertEqual(o.headers.first { $0.id == "h" }?.ids.sorted(), ["h0", "h1", "h2", "hg"])
    XCTAssertEqual(o.header(at: 125)?.id, "h")
  }
}
