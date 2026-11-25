//  Story 1203 (context-grabber-9bll): after an Undo or Redo that changes ink, what the board looks at to know it's all on
//  screen. PaperKit draws in tiles, and on the iPad simulator an Undo left one tile of a line it never touched blank: a
//  look at the whole stroke saw its first points drawn and called it shown, so each stroke near the change is looked at
//  one tile at a time.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

public enum BoardUndoRedraw {
  /// PaperKit's tile, in board points: the edge the simulator left a line drawn up to.
  public static let tile: CGFloat = 256

  /// A stroke as the look needs it: its points on the board and its width.
  public struct Stroke: Equatable, Sendable {
    public var key: String
    public var points: [CGPoint]
    public var width: CGFloat
    public init(key: String, points: [CGPoint], width: CGFloat) {
      self.key = key
      self.points = points
      self.width = width
    }
  }

  /// The part of one stroke in one tile, in board points.
  public struct Piece: Equatable, Sendable {
    public var key: String
    public var box: CGRect
    public init(key: String, box: CGRect) {
      self.key = key
      self.box = box
    }
  }

  /// Where the step changed the ink: every stroke added, taken away or moved, where it was and where it is. Nil when
  /// nothing changed.
  public static func changed(before: [String: CGRect], after: [String: CGRect]) -> CGRect? {
    var out: CGRect?
    for key in Set(before.keys).union(after.keys) where before[key] != after[key] {
      for frame in [before[key], after[key]].compactMap({ $0 }) {
        out = out.map { $0.union(frame) } ?? frame
      }
    }
    return out
  }

  /// Each stroke's ink within a tile of `changed`, cut at the tile edges: one piece per stroke per tile its ink passes
  /// through, its box the stroke's points there grown by half its width and kept inside the tile. In stroke order, then
  /// tile by tile, top row first.
  public static func pieces(strokes: [Stroke], near changed: CGRect, tile: CGFloat = tile) -> [Piece] {
    let near = changed.insetBy(dx: -tile, dy: -tile)
    var out: [Piece] = []
    for stroke in strokes {
      var cells: [Cell: CGRect] = [:]
      for point in stroke.points where near.contains(point) {
        let cell = Cell(row: Int((point.y / tile).rounded(.down)), column: Int((point.x / tile).rounded(.down)))
        let spot = CGRect(x: point.x, y: point.y, width: 0, height: 0)
        cells[cell] = cells[cell].map { $0.union(spot) } ?? spot
      }
      let pad = max(stroke.width / 2, 1)
      for (cell, box) in cells.sorted(by: { $0.key < $1.key }) {
        let bounds = CGRect(x: CGFloat(cell.column) * tile, y: CGFloat(cell.row) * tile, width: tile, height: tile)
        let piece = box.insetBy(dx: -pad, dy: -pad).intersection(bounds)
        if !piece.isNull, !piece.isEmpty { out.append(Piece(key: stroke.key, box: piece)) }
      }
    }
    return out
  }

  /// A piece is missing when it's in view and the view shows none of it (-1: the picture couldn't be read).
  public static func missing(inView: Bool, shownPixels: Int) -> Bool {
    inView && shownPixels == 0
  }

  /// The tiles `pieces` lie in, each once, as [column, row], top row first.
  public static func tiles(_ pieces: [Piece], tile: CGFloat = tile) -> [[Int]] {
    let cells = Set(
      pieces.map {
        Cell(row: Int(($0.box.midY / tile).rounded(.down)), column: Int(($0.box.midX / tile).rounded(.down)))
      })
    return cells.sorted().map { [$0.column, $0.row] }
  }

  /// The heal after the look numbered `afterLook` found a piece missing: the view a screen away and back once, then nothing
  /// more. Never the strokes taken out and put back (story 1343, bead context-grabber-pmv6): after an Undo or Redo that
  /// left PaperKit's own Undo of a stroke Igor drew taking nothing back.
  public static func healStep(afterLook attempt: Int) -> String? {
    attempt == 0 ? "scroll" : nil
  }

  /// One heal as the session log says it, once the look after it has run: the tiles it was for, how many strokes, which
  /// step, and whether that look found every piece drawn.
  public struct Heal: Equatable, Sendable {
    public var why: String
    public var attempt: Int
    public var how: String
    public var tiles: [[Int]]
    public var strokes: Int
    public var missingAfter: Int
    public init(why: String, attempt: Int, how: String, tiles: [[Int]], strokes: Int, missingAfter: Int) {
      (self.why, self.attempt, self.how, self.tiles) = (why, attempt, how, tiles)
      (self.strokes, self.missingAfter) = (strokes, missingAfter)
    }
    public var worked: Bool { missingAfter == 0 }
    /// The `paper_ink_heal` event's fields, the board's id added by the caller.
    public var fields: [String: Any] {
      [
        "action": "paper_ink_heal", "why": why, "attempt": attempt, "how": how, "tiles": tiles,
        "tile_size": Int(BoardUndoRedraw.tile), "strokes": strokes, "worked": worked, "missing_after": missingAfter,
      ]
    }
  }

  private struct Cell: Hashable, Comparable {
    var row: Int
    var column: Int
    static func < (a: Cell, b: Cell) -> Bool { (a.row, a.column) < (b.row, b.column) }
  }
}
