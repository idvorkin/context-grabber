//  A board on paper: after an Undo or Redo that changes ink, the board redraws around the change and a second later looks,
//  tile by tile, for ink near it that the view doesn't show (story 1203, bead context-grabber-9bll). Seen only on the iPad
//  simulator: an Undo of a group dropped just above Igor's line left the line drawn up to one 256-point tile edge and
//  blank past it, the model holding it whole.

import ContextCore
import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// The step's change, from the strokes' frames before it to the markup's now; nothing when no ink changed.
  func redrawAfterStep(redo: Bool, before: [String: CGRect]) {
    guard let markup = paper.markup, let changed = BoardUndoRedraw.changed(before: before, after: markup.strokeFrames)
    else { return }
    redrawSoon()
    lookAfterStep(changed, why: redo ? "redo" : "undo")
  }

  /// A second on, each stroke near `changed`, a tile at a time: a piece in view with nothing shown is missing.
  /// `paper_ink_look` says what was found. A miss asks for a heal (`BoardUndoRedraw.healStep`): the view a screen away and
  /// back, once. Never the strokes taken out and put back as a kept mark's are: after a step that left PaperKit's own Undo
  /// of a stroke taking nothing back (story 1343, bead context-grabber-pmv6). The look after it logs the heal,
  /// `paper_ink_heal`, with its tiles, strokes, step and whether it worked. `healed`: the heal that look follows.
  func lookAfterStep(_ changed: CGRect, why: String, attempt: Int = 0, healed: BoardUndoRedraw.Heal? = nil) {
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, let markup = self.paper.markup else { return }
      let strokes = markup.subelements.strokes.map { stroke in
        BoardUndoRedraw.Stroke(
          key: Self.key(stroke.elementID),
          points: stroke.path.interpolatedPoints(by: .distance(4)).map { $0.location.applying(stroke.transform) },
          width: stroke.path.map(\.size.width).max() ?? 2)
      }
      let pieces = BoardUndoRedraw.pieces(strokes: strokes, near: changed)
      let forced = LaunchHooks.current.whiteboard.undoLookMiss && attempt == 0
      var missing: [BoardUndoRedraw.Piece] = []
      var outOfView = 0
      for piece in pieces {
        let spot = self.stepSpot(piece.box)
        let inView = self.view.bounds.contains(spot)
        if !inView { outOfView += 1 }
        if forced || BoardUndoRedraw.missing(inView: inView, shownPixels: inView ? self.shownPixels(in: spot) : -1) {
          missing.append(piece)
        }
      }
      self.log.event(
        "whiteboard",
        [
          "action": "paper_ink_look", "why": why, "board": self.model.board.id, "changed": self.rect(changed),
          "pieces": pieces.count, "out_of_view": outOfView, "missing": missing.count,
          "missing_at": missing.prefix(8).map { self.rect($0.box) }, "strokes": markup.subelements.strokes.count,
          "visible": self.rect(self.paper.contentVisibleFrame), "attempt": attempt, "forced": forced,
        ])
      if var healed {
        healed.missingAfter = missing.count
        var fields = healed.fields
        fields["board"] = self.model.board.id
        self.log.event("whiteboard", fields)
      }
      let how = missing.isEmpty || self.touchesDown > 0 ? nil : BoardUndoRedraw.healStep(afterLook: attempt)
      self.showUndoLookForTests(missing.isEmpty ? "whole" : "missing", healed: how != nil)
      guard let how else { return }
      let keys = Set(missing.map(\.key))
      let heal = BoardUndoRedraw.Heal(
        why: why, attempt: attempt + 1, how: how, tiles: BoardUndoRedraw.tiles(missing), strokes: keys.count,
        missingAfter: missing.count)
      let place = self.paper.contentVisibleFrame
      self.paper.contentVisibleFrame = place.offsetBy(dx: 0, dy: place.height)
      try? await Task.sleep(for: .seconds(0.1))
      self.paper.contentVisibleFrame = place
      self.lookAfterStep(changed, why: why, attempt: attempt + 1, healed: heal)
    }
  }

  /// Where `box` (board points) is in this view's own points.
  private func stepSpot(_ box: CGRect) -> CGRect {
    let corner = lines.convert(lines.spot(of: box.origin), to: view)
    let scale = screenScale
    return CGRect(x: corner.x, y: corner.y, width: box.width * scale, height: box.height * scale)
  }

  /// `GRABBER_WHITEBOARD_UNDO_LOOK=label` (or `miss`): every look after an Undo or Redo this launch as an element a UI
  /// test reads (`whiteboard-undo-look`): its label each look's verdict in turn (`whole`, `missing`), its value how many
  /// heals they asked for.
  private func showUndoLookForTests(_ verdict: String, healed: Bool) {
    guard LaunchHooks.current.whiteboard.undoLookLabel, isViewLoaded else { return }
    let id = "whiteboard-undo-look"
    let label =
      view.subviews.first { $0.accessibilityIdentifier == id } as? UILabel
      ?? {
        let made = UILabel(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        made.accessibilityIdentifier = id
        made.isAccessibilityElement = true
        made.alpha = 0.02
        made.accessibilityValue = "0"
        view.addSubview(made)
        return made
      }()
    let looks = label.accessibilityLabel.map { $0.split(separator: ",").map(String.init) } ?? []
    label.accessibilityLabel = (looks + [verdict]).joined(separator: ",")
    label.accessibilityValue = String((Int(label.accessibilityValue ?? "0") ?? 0) + (healed ? 1 : 0))
  }
}
