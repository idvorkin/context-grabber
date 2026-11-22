//  Stroke building and paste (stories 390, 391): text and copied strokes as ink.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// A colour as `#rrggbb`, as it looks in light mode: the colour the Cockpit's strokes carry.
  static func lightHex(_ color: UIColor) -> String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    if !color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(
      &red, green: &green, blue: &blue, alpha: &alpha)
    {
      (red, green, blue) = (0, 0, 0)
    }
    return WhiteboardStrokes.hex(red: red, green: green, blue: blue)
  }

  /// `made`: one moment for every stroke of one mark or paste, which is how a kept label is known again (story 896).
  static func strokes(
    _ lines: [[CGPoint]], color: UIColor, width: CGFloat, spacing: CGFloat, made: Date = Date(), seed: UInt32? = nil
  ) -> [PKStroke] {
    let ink = PKInk(.pen, color: color)
    return lines.map { line in
      let path = PKStrokePath(
        controlPoints: WhiteboardTurn.inkPoints(line, spacing: spacing).enumerated().map { i, p in
          PKStrokePoint(
            location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: width, height: width), opacity: 1,
            force: 1, azimuth: 0, altitude: .pi / 2)
        }, creationDate: made)
      if let seed { return PKStroke(ink: ink, path: path, transform: .identity, mask: nil, randomSeed: seed) }
      return PKStroke(ink: ink, path: path)
    }
  }

  func add(_ strokes: [PKStroke], named name: String) {
    var kept = drawing
    kept.strokes += strokes
    drawing = kept
    drawingMoved()
    _ = canvas?.draw(strokes, named: name)
  }

  /// #966: what Undo and Redo call each keep, and Tidy overlaps.
  static let keepUndoName = "Keep"
  static let keepGroupUndoName = "Keep group"
  static let keepAllUndoName = "Keep all"
  static let pasteUndoName = "Paste"
  static let tidyUndoName = "Tidy overlaps"

  /// Stories 390, 391: the text as ink in the middle of the view, one undo, and a change like a drawn stroke. Black ink
  /// shows light in dark mode, as the Pencil's does, and dark in the picture. The pen's width is in proportion to the
  /// letters: a ghost's 3.7 fills a 24-point letter in, and PencilKit draws nothing under about 2 (seen on the
  /// simulator, on the canvas and in the picture alike), which is why zooming in never shrinks them on the board.
  func paste(_ text: String) {
    guard editable, let canvas, case let visible = canvas.visibleRect, !visible.isNull else { return }
    let zoom = canvas.zoom
    let height = Self.pasteLetters / min(zoom, 1)
    let layout = WhiteboardPaste.layout(
      text, visible: visible, height: height, board: pasteReach, lettering: lettering)
    let made = Date()
    let strokes = Self.strokes(layout.lines, color: .black, width: height * 0.11, spacing: height / 8, made: made)
    if !strokes.isEmpty { rememberLabel(made) }
    log.event(
      "whiteboard",
      [
        "action": "paste", "board": board.id, "characters": layout.kept, "of": layout.total, "strokes": strokes.count,
        "lettering": lettering.rawValue,
      ])
    guard !strokes.isEmpty else {
      pasteNote = layout.note
      return
    }
    land(strokes)
    if turns.stroked() { startPause() }
    if let note = layout.note { pasteNote = note }
  }

  private func land(_ strokes: [PKStroke]) {
    if canvas?.landPaste(strokes) != true { add(strokes, named: Self.pasteUndoName) }
  }

  /// Copied strokes the canvas didn't place itself: one undo, and a change like a drawn stroke, as a paste of text is.
  func paste(strokes: [PKStroke]) {
    guard editable, !strokes.isEmpty else { return }
    log.event("whiteboard", ["action": "paste_strokes", "board": board.id, "strokes": strokes.count])
    land(strokes)
    if turns.stroked() { startPause() }
  }
}
