import Foundation
import XCTest

@testable import ContextCore

#if canImport(PencilKit)
  import CoreGraphics
  import PencilKit
#endif

final class WhiteboardTurnTests: XCTestCase {
  /// Fonts that draw every character: the parse rules without CoreText, so they run on Linux too. Whether a real
  /// label has an outline is the Mac's (`testALabelWithNoOutlinesIsSkippedAndOneWithSomeIsKept`).
  private let everyCharacterDraws: WhiteboardTurn.Lettering = { text, _ in !text.isEmpty }

  func testShapesComeBackAndBadOnesAreSkipped() {
    let body = Data(
      """
      {"ok": true, "shapes": [
        {"kind": "ellipse", "points": [[0, 0], [10, 20]]},
        {"kind": "text", "points": [[5, 5]], "text": "dip", "size": 20},
        {"kind": "star", "points": [[0, 0], [1, 1]]},
        {"kind": "line", "points": [[0, 0]]},
        {"kind": "text", "points": [[5, 5]], "text": "  "},
        {"kind": "arrow", "points": [[0, 0], ["x", 1], [3, 4]]}
      ]}
      """.utf8)
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 200, body: body, lettering: everyCharacterDraws),
      .shapes(
        [
          .init(kind: .ellipse, points: [.zero, CGPoint(x: 10, y: 20)]),
          .init(kind: .text, points: [CGPoint(x: 5, y: 5)], text: "dip", size: 20),
          .init(kind: .arrow, points: [.zero, CGPoint(x: 3, y: 4)]),
        ]))
  }

  #if canImport(CoreText)
    /// An emoji is a bitmap with no outline: a ghost of it would count in the bar with nothing to see or tap.
    func testALabelWithNoOutlinesIsSkippedAndOneWithSomeIsKept() {
      let body = Data(
        """
        {"ok": true, "shapes": [
          {"kind": "text", "points": [[5, 5]], "text": "👍"},
          {"kind": "text", "points": [[5, 5]], "text": "ok 👍"}
        ]}
        """.utf8)
      XCTAssertEqual(
        WhiteboardTurn.answer(status: 200, body: body),
        .shapes([.init(kind: .text, points: [CGPoint(x: 5, y: 5)], text: "ok 👍")]))
    }
  #endif

  func testNothingToAddIsAnAnswer() {
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 200, body: Data(#"{"ok": true}"#.utf8)), .shapes([]))
  }

  func testTheGhostRequestCarriesThePictureAndItsSize() throws {
    let request = try WhiteboardTurn.suggestRequest(
      title: "Plan", picture: Data([1, 2, 3]), width: 800, height: 600, cockpit: "https://cockpit.example")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example/whiteboard/suggest")
    XCTAssertEqual(request.timeoutInterval, 10)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/x-ndjson")
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["image"] as? String, Data([1, 2, 3]).base64EncodedString())
    XCTAssertEqual(body["width"] as? Int, 800)
    XCTAssertEqual(body["height"] as? Int, 600)
    XCTAssertEqual(body["text"] as? String, "Plan")
  }

  func testEveryKindOfStrokeBecomesAShape() throws {
    let body = Data(
      #"""
      {"ok": true, "model": "m", "strokes": [
        {"kind": "line", "x1": 1, "y1": 2, "x2": 3, "y2": 4},
        {"kind": "arrow", "x1": 5, "y1": 6, "x2": 7, "y2": 8, "why": "here"},
        {"kind": "polyline", "points": [[0, 0], [1, 1], [2, 0]]},
        {"kind": "circle", "cx": 50, "cy": 60, "r": 10},
        {"kind": "arc", "cx": 0, "cy": 0, "r": 10, "start": 270, "end": 90},
        {"kind": "label", "text": "hi", "x": 10, "y": 40, "size": 20},
        {"kind": "blob"},
        {"kind": "line", "x1": 1}
      ]}
      """#.utf8)
    guard case .shapes(let shapes) = WhiteboardTurn.answer(status: 200, body: body, lettering: everyCharacterDraws)
    else {
      return XCTFail("no shapes")
    }
    XCTAssertEqual(shapes.map(\.kind), [.line, .arrow, .path, .ellipse, .path, .text])
    XCTAssertEqual(shapes[0].points, [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)])
    XCTAssertEqual(shapes[3].points, [CGPoint(x: 40, y: 50), CGPoint(x: 60, y: 70)])
    // 270 to 90 clockwise passes through 0: straight up, right, straight down, on a picture whose y runs down.
    let arc = shapes[4].points
    XCTAssertEqual(arc.first!.y, -10, accuracy: 0.001)
    XCTAssertEqual(arc[arc.count / 2].x, 10, accuracy: 0.001)
    XCTAssertEqual(arc.last!.y, 10, accuracy: 0.001)
    XCTAssertEqual(shapes[5].text, "hi")
  }

  #if canImport(CoreText)
    /// The Cockpit draws a label as SVG `<text x y>`, so y is the baseline, and an H stands on its baseline. It holds
    /// when the picture is scaled down to the board, and when a tiny label is clamped up to the smallest readable size.
    func testALabelStandsOnTheCockpitsBaseline() throws {
      let cases: [(size: Int, scale: CGFloat)] = [(20, 1), (40, 2), (10, 2)]
      for (size, scale) in cases {
        let label = #"{"kind": "label", "text": "H", "x": 10, "y": 40, "size": \#(size)}"#
        let body = Data(#"{"ok": true, "strokes": [\#(label)]}"#.utf8)
        guard case .shapes(let shapes) = WhiteboardTurn.answer(status: 200, body: body) else {
          return XCTFail("no shapes")
        }
        let frame = CGRect(x: 1000, y: 2000, width: 400, height: 300)
        let lines = WhiteboardTurn.lines(try XCTUnwrap(shapes.first), frame: frame, scale: scale)
        let lowest = try XCTUnwrap(lines.joined().map(\.y).max())
        XCTAssertEqual(lowest, 2000 + 40 / scale, accuracy: 0.01, "size \(size) at scale \(scale)")
      }
    }
  #endif

  func testAskingTooSoonSkipsAGhostTurn() {
    XCTAssertEqual(WhiteboardTurn.answer(status: 429, body: Data(#"{"ok": false}"#.utf8)), .tooSoon)
  }

  func testRefusalsAndAbsences() {
    XCTAssertEqual(
      WhiteboardTurn.answer(status: 400, body: Data(#"{"ok": false, "error": "no picture"}"#.utf8)),
      .refused(status: 400, reason: "no picture"))
    XCTAssertEqual(WhiteboardTurn.answer(status: 404, body: nil), .refused(status: 404, reason: "HTTP 404"))
    XCTAssertEqual(WhiteboardTurn.answer(status: 502, body: nil), .away(reason: "HTTP 502"))
    XCTAssertEqual(WhiteboardTurn.answer(status: 200, body: Data("<html>".utf8)), .away(reason: "HTTP 200"))
    XCTAssertEqual(WhiteboardTurn.answer(status: nil, body: nil, error: "timed out"), .away(reason: "timed out"))
  }

  /// The picture covers `frame` at `scale` pixels a point: pixel (100, 50) at scale 2 is 50 and 25 points in.
  func testPixelsLandOnTheBoardWhereThePictureShowedThem() {
    let frame = CGRect(x: 1000, y: 2000, width: 400, height: 300)
    let line = WhiteboardTurn.lines(
      .init(kind: .line, points: [.zero, CGPoint(x: 100, y: 50)]), frame: frame, scale: 2)
    XCTAssertEqual(line, [[CGPoint(x: 1000, y: 2000), CGPoint(x: 1050, y: 2025)]])
  }

  func testABoxIsClosedAndAnEllipseGoesRoundItsCorners() {
    let box = WhiteboardTurn.lines(
      .init(kind: .rect, points: [CGPoint(x: 10, y: 10), .zero]), frame: .zero, scale: 1)
    XCTAssertEqual(box.count, 1)
    XCTAssertEqual(box[0].first, box[0].last)
    XCTAssertEqual(box[0].count, 5)
    let ellipse = WhiteboardTurn.lines(
      .init(kind: .ellipse, points: [.zero, CGPoint(x: 20, y: 10)]), frame: .zero, scale: 1)[0]
    for p in ellipse {
      XCTAssertEqual(pow((p.x - 10) / 10, 2) + pow((p.y - 5) / 5, 2), 1, accuracy: 1e-9)
    }
  }

  func testAnArrowHasAHeadAtItsEnd() {
    let arrow = WhiteboardTurn.lines(
      .init(kind: .arrow, points: [.zero, CGPoint(x: 90, y: 0)]), frame: .zero, scale: 1)
    XCTAssertEqual(arrow.count, 2)
    XCTAssertEqual(arrow[1][1], CGPoint(x: 90, y: 0))
    XCTAssertTrue(arrow[1][0].x < 90 && arrow[1][0].y < 0)
    XCTAssertTrue(arrow[1][2].x < 90 && arrow[1][2].y > 0)
  }

  #if canImport(CoreText)
    func testALabelIsDrawnAsLettersInsideItsBox() {
      let lines = WhiteboardTurn.lines(
        .init(kind: .text, points: [CGPoint(x: 100, y: 100)], text: "Hi", size: 40), frame: .zero, scale: 1)
      XCTAssertFalse(lines.isEmpty)
      let points = lines.flatMap { $0 }
      XCTAssertGreaterThanOrEqual(points.map(\.y).min() ?? 0, 100 - 1)
      XCTAssertLessThanOrEqual(points.map(\.y).max() ?? 0, 100 + 40 + 1)
      XCTAssertGreaterThanOrEqual(points.map(\.x).min() ?? 0, 100 - 1)
    }
  #endif

  func testATapNearAGhostsLineHitsIt() {
    let lines = [[CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]]
    XCTAssertTrue(WhiteboardTurn.hit(lines, at: CGPoint(x: 50, y: 8), tolerance: 10))
    XCTAssertFalse(WhiteboardTurn.hit(lines, at: CGPoint(x: 50, y: 12), tolerance: 10))
    XCTAssertFalse(WhiteboardTurn.hit(lines, at: CGPoint(x: 115, y: 0), tolerance: 10))
  }

  #if canImport(CoreText)
    /// A character Helvetica lacks draws in CoreText's fallback font: an arrow is wider than tall, while the same glyph
    /// id in Helvetica is an unrelated letter taller than wide.
    func testALabelCharacterFromAFallbackFontKeepsItsShape() {
      let points = WhiteboardTurn.lines(
        .init(kind: .text, points: [.zero], text: "→", size: 40), frame: .zero, scale: 1
      ).flatMap { $0 }
      let width = (points.map(\.x).max() ?? 0) - (points.map(\.x).min() ?? 0)
      let height = (points.map(\.y).max() ?? 0) - (points.map(\.y).min() ?? 0)
      XCTAssertGreaterThan(height, 0)
      XCTAssertGreaterThan(width, height * 1.3)
    }
  #endif

  #if canImport(CoreText)
    /// PencilKit's own spline, through the points a kept ghost gets: it must pass every corner the ghost showed.
    func testKeptInkPassesEveryCornerOfTheShape() {
      let shapes: [WhiteboardTurn.Shape] = [
        .init(kind: .rect, points: [.zero, CGPoint(x: 100, y: 100)]),
        .init(kind: .arrow, points: [.zero, CGPoint(x: 90, y: 0)]),
        .init(kind: .text, points: [.zero], text: "HE", size: 40),
        .init(kind: .path, points: [.zero, CGPoint(x: 60, y: 0), CGPoint(x: 60, y: 60)]),
      ]
      for shape in shapes {
        for line in WhiteboardTurn.lines(shape, frame: .zero, scale: 1) {
          let path = PKStrokePath(
            controlPoints: WhiteboardTurn.inkPoints(line).enumerated().map { i, p in
              PKStrokePoint(
                location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: 3.7, height: 3.7), opacity: 1, force: 1,
                azimuth: 0, altitude: .pi / 2)
            }, creationDate: Date())
          let drawn = path.interpolatedPoints(by: .distance(0.25)).map(\.location)
          for corner in line {
            let miss = drawn.map { hypot($0.x - corner.x, $0.y - corner.y) }.min() ?? .infinity
            XCTAssertLessThan(miss, 1.5, "\(shape.kind) at \(corner)")
          }
        }
      }
    }
  #endif

  func testInkPointsKeepEveryCornerAndStayBoundedOnAnAbsurdEdge() {
    let line = [CGPoint.zero, CGPoint(x: 12, y: 0), CGPoint(x: 12, y: 1)]
    XCTAssertEqual(
      WhiteboardTurn.inkPoints(line),
      [.zero, CGPoint(x: 4, y: 0), CGPoint(x: 8, y: 0), CGPoint(x: 12, y: 0), CGPoint(x: 12, y: 1)])
    let absurd = WhiteboardTurn.inkPoints([.zero, CGPoint(x: 1e300, y: 0)])
    XCTAssertLessThanOrEqual(absurd.count, Int(WhiteboardFrame.side) + 1)
    XCTAssertEqual(absurd.last, CGPoint(x: 1e300, y: 0))
  }

  /// A model's point past anywhere on the board at the finest picture is dropped when read: mapped at a scale under 1
  /// it would be infinite, and keeping that ghost would trap. The sensible part of the shape still draws.
  func testAnAbsurdCoordinateNeverReachesTheInk() throws {
    let body = Data(
      """
      {"ok": true, "shapes": [
        {"kind": "path", "points": [[0, 0], [50, 0], [1e308, 1], [1e308, 2]]},
        {"kind": "line", "points": [[0, 0], [-1e308, 0]]},
        {"kind": "line", "points": [[0, 0], [40000, -40000]]}
      ]}
      """.utf8)
    guard case .shapes(let shapes) = WhiteboardTurn.answer(status: 200, body: body) else {
      return XCTFail("the answer should still be shapes")
    }
    XCTAssertEqual(
      shapes,
      [
        .init(kind: .path, points: [.zero, CGPoint(x: 50, y: 0)]),
        // The board's far corner at the finest scale: 20,000 points at 2 pixels each.
        .init(kind: .line, points: [.zero, CGPoint(x: 40000, y: -40000)]),
      ])
    let ink = WhiteboardTurn.lines(shapes[0], frame: .zero, scale: 0.5).flatMap { WhiteboardTurn.inkPoints($0) }
    XCTAssertEqual(ink.last, CGPoint(x: 100, y: 0))
  }

  // #698: a mark can choose its pen, colour and lettering; one that doesn't looks as before, but labels aren't bold.
  private func strokes(_ json: String) throws -> [WhiteboardTurn.Shape] {
    let body = Data(#"{"ok": true, "strokes": [\#(json)]}"#.utf8)
    guard case .shapes(let shapes) = WhiteboardTurn.answer(status: 200, body: body, lettering: everyCharacterDraws)
    else {
      XCTFail("no shapes")
      return []
    }
    return shapes
  }

  func testAMarkCarriesThePenColourAndLetteringItAsksFor() throws {
    let shapes = try strokes(
      #"""
      {"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9, "pen": 8, "color": "#12AB34"},
      {"kind": "label", "text": "hi", "x": 10, "y": 40, "size": 20, "font": "hand"},
      {"kind": "circle", "cx": 50, "cy": 60, "r": 10, "pen": 5}
      """#)
    XCTAssertEqual(shapes.map(\.kind), [.line, .text, .ellipse])
    XCTAssertEqual(shapes[0].color, 0x12AB34)
    // The pen is in the picture's pixels: a picture at twice the board's size halves it on the board.
    XCTAssertEqual(WhiteboardTurn.width(shapes[0], scale: 2), 4)
    XCTAssertEqual(shapes[1].face, .hand)
    #if canImport(CoreText)
      XCTAssertFalse(WhiteboardTurn.lines(shapes[1], frame: .zero, scale: 1).isEmpty, "the hand face draws letters")
    #endif
    XCTAssertEqual(WhiteboardTurn.width(shapes[2], scale: 1), 5)
  }

  func testAMarkThatAsksForNothingLooksAsBeforeAndLabelsArentBold() throws {
    let shapes = try strokes(
      #"""
      {"kind": "arrow", "x1": 0, "y1": 0, "x2": 9, "y2": 9},
      {"kind": "label", "text": "hi", "x": 10, "y": 40, "size": 40}
      """#)
    XCTAssertNil(shapes[0].color)
    XCTAssertEqual(WhiteboardTurn.width(shapes[0], scale: 2), WhiteboardTurn.defaultPen)
    XCTAssertEqual(shapes[1].face, .print)
    // A 40-pixel label on a picture at board size: 40-point letters, a pen of 4.4, a ninth of them, not a marker.
    XCTAssertEqual(WhiteboardTurn.width(shapes[1], scale: 1), 4.4, accuracy: 0.001)
  }

  /// #883: Larry's labels at 13–14-point letters were kept at a pen of 1.4–1.5 points, and PencilKit drew none of it.
  func testNoMarkIsThinnerThanTheIPadDraws() throws {
    let shapes = try strokes(
      #"""
      {"kind": "label", "text": "hi", "x": 10, "y": 40, "size": 24},
      {"kind": "label", "text": "hi", "x": 10, "y": 40, "size": 28},
      {"kind": "rect", "x": 10, "y": 20, "w": 30, "h": 40, "pen": 2},
      {"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9}
      """#)
    // A 24-pixel label on a picture at twice the board: 12-point letters, whose ninth (1.3) PencilKit wouldn't draw.
    XCTAssertEqual(WhiteboardTurn.letters(shapes[0], scale: 2), 12)
    XCTAssertEqual(WhiteboardTurn.width(shapes[0], scale: 2), WhiteboardTurn.thinnestPen)
    XCTAssertEqual(WhiteboardTurn.width(shapes[1], scale: 2), WhiteboardTurn.thinnestPen)
    // An asked-for pen too thin is held up to it too: a 2-pixel pen at twice the board would be 1 point.
    XCTAssertEqual(WhiteboardTurn.width(shapes[2], scale: 2), WhiteboardTurn.thinnestPen)
    // Nothing that was already wide enough changes.
    XCTAssertEqual(WhiteboardTurn.width(shapes[3], scale: 2), WhiteboardTurn.defaultPen)
    XCTAssertNil(WhiteboardTurn.letters(shapes[3], scale: 2))
    // The floor is the width proven on the iPad, below the default pen, so an unasked line or box is unchanged.
    XCTAssertLessThan(WhiteboardTurn.thinnestPen, WhiteboardTurn.defaultPen)
    XCTAssertGreaterThanOrEqual(WhiteboardTurn.thinnestPen, 2.87)
  }

  func testABoxIsItsCornerWidthAndHeight() throws {
    let shapes = try strokes(#"{"kind": "rect", "x": 10, "y": 20, "w": 30, "h": 40, "pen": 3}"#)
    XCTAssertEqual(shapes.map(\.kind), [.rect])
    XCTAssertEqual(shapes[0].points, [CGPoint(x: 10, y: 20), CGPoint(x: 40, y: 60)])
    XCTAssertEqual(shapes[0].pen, 3)
    XCTAssertEqual(WhiteboardTurn.lines(shapes[0], frame: .zero, scale: 1).first?.count, 5)
  }

  func testWhatAMarkAsksForNeverBreaksTheBoard() throws {
    let shapes = try strokes(
      #"""
      {"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9, "pen": 0, "color": "red", "font": "gothic"},
      {"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9, "pen": -4, "color": "#12AB3"},
      {"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9, "pen": 900},
      {"kind": "label", "text": "hi", "x": 10, "y": 40, "font": "gothic"},
      {"kind": "line", "x1": 0, "y1": 0, "x2": 9, "y2": 9, "color": "#+12345"}
      """#)
    XCTAssertEqual(shapes.count, 5)
    // A sign is not a hex digit, though Swift's number parsing would take it.
    XCTAssertNil(shapes[4].color)
    XCTAssertEqual(shapes[0].pen, nil)
    XCTAssertEqual(shapes[0].color, nil)
    XCTAssertEqual(shapes[1].pen, nil)
    XCTAssertEqual(shapes[1].color, nil)
    XCTAssertEqual(WhiteboardTurn.width(shapes[0], scale: 1), WhiteboardTurn.defaultPen)
    XCTAssertEqual(WhiteboardTurn.width(shapes[2], scale: 1), WhiteboardTurn.widestPen)
    XCTAssertEqual(shapes[3].face, .print)
  }

  func testLarrysChatShapesCarryTheirLooksToo() throws {
    let shape = WhiteboardTurn.anyShape(
      [
        "kind": "label", "text": "ok", "x": 5.0, "y": 30.0, "size": 18.0, "color": "#000000", "pen": 1.5,
        "font": "hand",
      ], lettering: everyCharacterDraws)
    XCTAssertEqual(shape?.color, 0)
    XCTAssertEqual(shape?.pen, 1.5)
    XCTAssertEqual(shape?.face, .hand)
  }
}
