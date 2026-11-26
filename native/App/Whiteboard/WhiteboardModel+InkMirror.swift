//  The ink mirror: what the canvas says changed, settled or stepped, the save debounce it starts, and the picture's
//  frame.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  func changed(_ new: PKDrawing) {
    // #1527: this part of a stroke grows with the board; slow, it names its own steps.
    let laps = StepLaps()
    defer { logPartLaps(laps, part: "model") }
    let same = laps.time("equal") { new == drawing }
    guard editable, !same else { return }
    let added = new.strokes.count > drawing.strokes.count
    laps.time("moved_log") { logStrokesMoved(to: new) }
    drawing = new
    laps.time("landed") {
      if added, let last = new.strokes.last { vad.stroke(last.renderBounds) }
      if added { strokeLanded() }
    }
    drawingMoved(laps: laps)
  }

  /// Kept ink as the canvas reads it back. Nothing to ask about or save that the keep hasn't already started.
  func settled(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    inkMoved()
  }

  /// A kept mark undone or redone on paper: saved like any change, and not a stroke for Claude to answer.
  func stepped(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    drawingMoved()
  }

  /// #624: a board's ink below a line moved on its own, splitting a kept label. Names the next one.
  private func logStrokesMoved(to new: PKDrawing) {
    guard
      let moved = WhiteboardFrame.strokesMoved(
        before: drawing.strokes.map(\.renderBounds), after: new.strokes.map(\.renderBounds))
    else { return }
    log.event(
      "whiteboard",
      [
        "action": "ink_moved", "board": board.id, "strokes": new.strokes.count, "moved": moved.count,
        "dx": Double(moved.dx), "dy": Double(moved.dy), "top_moved_y": Double(moved.topY),
        "zoom": Double(canvas?.zoom ?? 1),
      ])
  }

  func drawingMoved(laps: StepLaps? = nil) {
    ops.changed()
    isEmpty = drawing.strokes.isEmpty
    sent = nil
    sentFrame = nil
    laps?.lap("ops")
    inkMoved(laps: laps)
    pasteNote = nil
    dirty = true
    saveSoon()
    laps?.lap("save")
  }

  /// The ink changed: what's on screen may have too.
  private func inkMoved(laps: StepLaps? = nil) {
    inkBoxes = drawing.strokes.map(\.renderBounds)
    cachedLabelBoxes = nil
    laps?.lap("ink_boxes")
    screenMoved()
    laps?.lap("screen")
  }

  /// On paper, the view moved or the ink changed (story 433): what Send and Larry's turn would show. A Send already made is
  /// of the pages it showed, so another page on screen can be sent too.
  func screenMoved() {
    let frame = pictureFrame()?.rect
    let nothing = !drawing.strokes.isEmpty && frame == nil
    if nothing != nothingOnScreen { nothingOnScreen = nothing }
    larryFrameMovedNow(frame)
    if let sentFrame, sentFrame != frame {
      self.sentFrame = nil
      sent = nil
    }
  }

  /// Bead context-grabber-x3tm: whether the pages on screen are other than those Larry's last picture showed.
  func larryFrameMovedNow(_ frame: CGRect? = nil) {
    let moved = (frame ?? pictureFrame()?.rect).map { larryFrame?.moved(to: $0) ?? true } ?? true
    if moved != larryFrameMoved { larryFrameMoved = moved }
  }

  /// Bead context-grabber-x3tm (story 765): Larry already has the board as it is, so Send is dimmed until the next
  /// stroke, words or other pages on screen. A board only looked at goes by its own `sent` (story 343).
  var larryHasThis: Bool {
    // Story 1281: words heard and not yet sent are new to him.
    editable && speech.pending == nil && turns.unsaid == nil
      && larry.hasThis(version: ops.rev, moved: larryFrameMoved)
  }

  /// Bead context-grabber-x3tm: what dims Send, for the session log.
  func logLarryHas(why: String) {
    let frame = pictureFrame()?.rect
    log.event(
      "whiteboard",
      [
        "action": "larry_has", "board": board.id, "why": why, "has": larry.has ?? -1, "rev": ops.rev,
        "frame_moved": larryFrameMoved, "moved_now": frame.map { larryFrame?.moved(to: $0) ?? true } ?? true,
        "words": larry.wordsWaiting, "dimmed": larryHasThis,
      ])
  }

  /// Larry's picture, for Send and his turn: the pages on screen (story 433). Claude's own turns frame theirs as they
  /// always have.
  func pictureFrame() -> (rect: CGRect, scale: CGFloat)? {
    BoardPages().picture(visible: canvas?.visibleRect ?? .null, ink: inkBoxes + labelBoxes())
  }

  /// The header markers' boxes, kept until the ink or the headers change: the picture's frame is asked for on every
  /// scroll (#1001).
  func labelBoxes() -> [CGRect] {
    if let cachedLabelBoxes { return cachedLabelBoxes }
    let boxes = pictureLabelBoxes()
    cachedLabelBoxes = boxes
    return boxes
  }
}
