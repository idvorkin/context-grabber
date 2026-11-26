import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Stories 1349–1351 (#1528): a kept diagram of Larry's is boxes (a rectangle and the labels inside it) and the arrows
/// between them, which keep as connectors joining those boxes.
final class WhiteboardDiagramTests: XCTestCase {
  private typealias Mark = WhiteboardDiagram.Mark

  private func rect(_ id: String, _ r: CGRect) -> Mark {
    Mark(
      id: id, kind: .rect,
      lines: [
        [
          CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
          CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.minY),
        ]
      ])
  }

  private func label(_ id: String, at p: CGPoint) -> Mark {
    Mark(id: id, kind: .text, lines: [[p, CGPoint(x: p.x + 20, y: p.y + 8)]])
  }

  private func arrow(_ id: String, _ tail: CGPoint, _ head: CGPoint) -> Mark {
    Mark(id: id, kind: .arrow, lines: [[tail, head], [CGPoint(x: head.x - 8, y: head.y - 5), head]])
  }

  private let left = CGRect(x: 0, y: 0, width: 100, height: 60)
  private let right = CGRect(x: 300, y: 0, width: 100, height: 60)

  func testARectangleWithALabelInsideIsOneBox() {
    let plan = WhiteboardDiagram.plan([rect("r#0", left), label("r#1", at: CGPoint(x: 30, y: 25))])
    let name = WhiteboardDiagram.boxName(rect: "r#0")
    XCTAssertEqual(plan.boxOf["r#0"], name)
    XCTAssertEqual(plan.boxOf["r#1"], name)
    XCTAssertEqual(plan.boxes[name], left)
  }

  func testARectangleWithNoLabelIsNoBox() {
    let plan = WhiteboardDiagram.plan([rect("r#0", left), label("r#1", at: CGPoint(x: 200, y: 25))])
    XCTAssertTrue(plan.boxOf.isEmpty)
    XCTAssertTrue(plan.connectors.isEmpty)
  }

  func testALabelInsideTwoRectanglesGoesWithTheSmaller() {
    let outer = CGRect(x: 0, y: 0, width: 300, height: 200)
    let inner = CGRect(x: 20, y: 20, width: 100, height: 60)
    let plan = WhiteboardDiagram.plan([
      rect("r#0", outer), rect("r#1", inner), label("r#2", at: CGPoint(x: 50, y: 45)),
      label("r#3", at: CGPoint(x: 200, y: 150)),
    ])
    XCTAssertEqual(plan.boxOf["r#2"], WhiteboardDiagram.boxName(rect: "r#1"))
    XCTAssertEqual(plan.boxOf["r#3"], WhiteboardDiagram.boxName(rect: "r#0"))
  }

  func testAnArrowBetweenTwoBoxesKeepsAsAConnectorJoiningThem() {
    let plan = WhiteboardDiagram.plan([
      rect("r#0", left), label("r#1", at: CGPoint(x: 30, y: 25)),
      rect("r#2", right), label("r#3", at: CGPoint(x: 330, y: 25)),
      arrow("r#4", CGPoint(x: 104, y: 30), CGPoint(x: 296, y: 30)),
    ])
    let connector = try? XCTUnwrap(plan.connectors["r#4"])
    XCTAssertEqual(connector?.from, WhiteboardDiagram.boxName(rect: "r#0"))
    XCTAssertEqual(connector?.to, WhiteboardDiagram.boxName(rect: "r#2"))
    XCTAssertEqual(connector?.fromSide, .right)
    XCTAssertEqual(connector?.toSide, .left)
    XCTAssertEqual(connector?.route, [CGPoint(x: 100, y: 30), CGPoint(x: 300, y: 30)])
    XCTAssertNil(plan.boxOf["r#4"], "a joined arrow is part of no box")
  }

  func testAnArrowWithAnEndOnBarePaperStaysAPlainArrow() {
    let plan = WhiteboardDiagram.plan([
      rect("r#0", left), label("r#1", at: CGPoint(x: 30, y: 25)),
      arrow("r#2", CGPoint(x: 104, y: 30), CGPoint(x: 220, y: 30)),
    ])
    XCTAssertNil(plan.connectors["r#2"])
  }

  func testAnArrowFromABoxBackToItselfStaysAPlainArrow() {
    let plan = WhiteboardDiagram.plan([
      rect("r#0", left), label("r#1", at: CGPoint(x: 30, y: 25)),
      arrow("r#2", CGPoint(x: 104, y: 10), CGPoint(x: 104, y: 50)),
    ])
    XCTAssertNil(plan.connectors["r#2"])
  }

  func testAnEndReachesABoxWithinSixteenPoints() {
    let plan = WhiteboardDiagram.plan([
      rect("r#0", left), label("r#1", at: CGPoint(x: 30, y: 25)),
      rect("r#2", right), label("r#3", at: CGPoint(x: 330, y: 25)),
      arrow("r#4", CGPoint(x: 115, y: 30), CGPoint(x: 284, y: 30)),
      arrow("r#5", CGPoint(x: 118, y: 40), CGPoint(x: 284, y: 40)),
    ])
    XCTAssertNotNil(plan.connectors["r#4"])
    XCTAssertNil(plan.connectors["r#5"], "18 points off the box is bare paper")
  }

  func testBoxNamesAreNamesTheCockpitTakes() {
    let name = WhiteboardDiagram.boxName(rect: "a reply/with odd#7")
    XCTAssertTrue(BoardOps.isName(name), name)
    XCTAssertTrue(name.hasPrefix("box-"))
    XCTAssertTrue(BoardOps.isName(WhiteboardDiagram.boxName(rect: String(repeating: "x", count: 200) + "#1")))
  }
}
