//  Story 1203: after an Undo or Redo, the pieces of ink near the change the board looks at, tile by tile.
//  Numbers from context-grabber-9bll's iPad-simulator run: a group of three circles dropped just above my line, undone.

import ContextCore
import XCTest

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

final class BoardUndoRedrawTests: XCTestCase {
  private let line = CGRect(x: 237, y: 659, width: 250, height: 4)
  private let group = "g"

  /// The step moved the group from just above my line back up; the line itself never moved.
  private var before: [String: CGRect] {
    [
      "line": line, group: CGRect(x: 212, y: 633, width: 64, height: 25),
      "first": CGRect(x: 244, y: 472, width: 250, height: 4),
    ]
  }
  private var after: [String: CGRect] {
    [
      "line": line, group: CGRect(x: 212, y: 440, width: 64, height: 24),
      "first": CGRect(x: 244, y: 472, width: 250, height: 4),
    ]
  }

  func testTheChangeIsWhereTheMovedInkWasAndIs() {
    let changed = BoardUndoRedraw.changed(before: before, after: after)
    XCTAssertEqual(changed, CGRect(x: 212, y: 440, width: 64, height: 218))
  }

  func testNothingChangedIsNoChange() {
    XCTAssertNil(BoardUndoRedraw.changed(before: after, after: after))
  }

  func testAddedAndTakenAwayInkCountAsChanged() {
    var more = after
    more["dot"] = CGRect(x: 600, y: 900, width: 4, height: 4)
    XCTAssertEqual(BoardUndoRedraw.changed(before: after, after: more), CGRect(x: 600, y: 900, width: 4, height: 4))
    XCTAssertEqual(BoardUndoRedraw.changed(before: more, after: after), CGRect(x: 600, y: 900, width: 4, height: 4))
  }

  /// The line the Undo never touched is cut at 256, the tile edge the simulator left it drawn up to, so its blank piece
  /// is looked at on its own: the whole line's look would have found its first 19 points drawn and called it shown.
  func testALineNearTheChangeIsLookedAtTileByTile() {
    let points = stride(from: CGFloat(237), through: 487, by: 4).map { CGPoint(x: $0, y: 661) }
    let pieces = BoardUndoRedraw.pieces(
      strokes: [.init(key: "line", points: points, width: 4)],
      near: CGRect(x: 212, y: 440, width: 64, height: 218))
    XCTAssertEqual(pieces.map(\.key), ["line", "line"])
    XCTAssertEqual(pieces.map { $0.box.minX < 256 }, [true, false])
    XCTAssertTrue(pieces.allSatisfy { $0.box.maxX <= 256 || $0.box.minX >= 256 }, "no piece crosses the tile edge")
    XCTAssertEqual(pieces[1].box.minX, 256, accuracy: 4)
    XCTAssertEqual(pieces[1].box.maxX, 489, accuracy: 4)
  }

  /// A diagonal stroke only counts in the tiles its ink passes through, never in a corner of its box it doesn't reach.
  func testAPieceIsWhereTheStrokesInkIsNotItsBox() {
    let points = stride(from: CGFloat(0), through: 500, by: 4).map { CGPoint(x: $0, y: $0) }
    let pieces = BoardUndoRedraw.pieces(
      strokes: [.init(key: "d", points: points, width: 2)], near: CGRect(x: 0, y: 0, width: 10, height: 10))
    XCTAssertEqual(pieces.count, 2, "tiles (0,0) and (1,1), not (1,0) or (0,1)")
    XCTAssertFalse(pieces.contains { $0.box.minX >= 256 && $0.box.maxY <= 256 })
  }

  /// Ink more than a tile away from the change is left alone.
  func testInkFarFromTheChangeIsNotLookedAt() {
    let far = [CGPoint(x: 900, y: 1600), CGPoint(x: 950, y: 1600)]
    let pieces = BoardUndoRedraw.pieces(
      strokes: [.init(key: "far", points: far, width: 2)], near: CGRect(x: 212, y: 440, width: 64, height: 218))
    XCTAssertTrue(pieces.isEmpty)
  }

  /// A piece is missing only when it's in view and none of it shows; one that shows anything, or is off screen, isn't.
  func testOnlyAPieceInViewWithNothingShownIsMissing() {
    XCTAssertTrue(BoardUndoRedraw.missing(inView: true, shownPixels: 0))
    XCTAssertFalse(BoardUndoRedraw.missing(inView: true, shownPixels: 3))
    XCTAssertFalse(BoardUndoRedraw.missing(inView: false, shownPixels: 0))
    XCTAssertFalse(BoardUndoRedraw.missing(inView: true, shownPixels: -1))
  }

  func testTheLaunchHookShowsTheLooksAndCanForceAMiss() {
    XCTAssertFalse(WhiteboardHooks([:]).undoLookLabel)
    XCTAssertTrue(WhiteboardHooks(["GRABBER_WHITEBOARD_UNDO_LOOK": "label"]).undoLookLabel)
    XCTAssertFalse(WhiteboardHooks(["GRABBER_WHITEBOARD_UNDO_LOOK": "label"]).undoLookMiss)
    let miss = WhiteboardHooks(["GRABBER_WHITEBOARD_UNDO_LOOK": "miss"])
    XCTAssertTrue(miss.undoLookLabel && miss.undoLookMiss)
  }

  /// The line's blank piece, right of the tile edge, is in tile column 1 of row 2.
  func testAPiecesTileIsItsColumnAndRow() {
    let pieces = [
      BoardUndoRedraw.Piece(key: "line", box: CGRect(x: 256, y: 659, width: 231, height: 4)),
      BoardUndoRedraw.Piece(key: "line", box: CGRect(x: 300, y: 700, width: 10, height: 4)),
      BoardUndoRedraw.Piece(key: "g", box: CGRect(x: 212, y: 440, width: 40, height: 24)),
    ]
    XCTAssertEqual(BoardUndoRedraw.tiles(pieces), [[0, 1], [1, 2]], "each tile once, top row first")
  }

  /// Every heal is one session-log line: the tiles it was for, how many strokes, which step, and whether the look after it
  /// found them drawn.
  func testAHealIsLoggedWithItsTilesStrokesStepAndOutcome() {
    let heal = BoardUndoRedraw.Heal(
      why: "undo", attempt: 1, how: "scroll", tiles: [[1, 2]], strokes: 1, missingAfter: 0)
    XCTAssertTrue(heal.worked)
    let fields = heal.fields
    XCTAssertEqual(fields["action"] as? String, "paper_ink_heal")
    XCTAssertEqual(fields["why"] as? String, "undo")
    XCTAssertEqual(fields["attempt"] as? Int, 1)
    XCTAssertEqual(fields["how"] as? String, "scroll")
    XCTAssertEqual(fields["tiles"] as? [[Int]], [[1, 2]])
    XCTAssertEqual(fields["tile_size"] as? Int, 256)
    XCTAssertEqual(fields["strokes"] as? Int, 1)
    XCTAssertEqual(fields["worked"] as? Bool, true)
    XCTAssertEqual(fields["missing_after"] as? Int, 0)
    let failed = BoardUndoRedraw.Heal(
      why: "redo", attempt: 2, how: "scroll", tiles: [[1, 2]], strokes: 2, missingAfter: 3)
    XCTAssertFalse(failed.worked)
    XCTAssertEqual(failed.fields["worked"] as? Bool, false)
    XCTAssertEqual(failed.fields["how"] as? String, "scroll")
  }

  /// Story 1343 (bead context-grabber-pmv6): the one heal after a step moves the view a screen away and back, and there is
  /// no second. A heal never takes the strokes out and puts them back: that left PaperKit's own Undo of a stroke taking
  /// nothing back.
  func testTheHealAfterAStepIsOneScrollAndNeverAReadd() {
    XCTAssertEqual(BoardUndoRedraw.healStep(afterLook: 0), "scroll")
    XCTAssertNil(BoardUndoRedraw.healStep(afterLook: 1))
    XCTAssertNil(BoardUndoRedraw.healStep(afterLook: 2))
  }
}
