//  A board on paper: a drag that begins inside a small selection moves it (story 1201, bead context-grabber-vhae). On the
//  iPad simulator a drag straight down on a selected one-word text began on PaperKit's resize handle, which on a selection
//  that small covers the whole word, and the text was stretched sideways instead of moved. PaperKit's own pan that moves a
//  selection gives up on a touch that near a handle, so the stretch is taken back on the lift and the finger's travel is
//  put on as one Move.

import ContextCore
import PaperKit
import UIKit

/// The touch that went down on a resize handle inside the selection: where, what was selected, and where the finger is.
@MainActor
final class SelectionDragWatch {
  var box: CGRect?
  var frames: [String: CGRect] = [:]
  var start: CGPoint = .zero
  var end: CGPoint = .zero
  var handle = ""
  /// A stretch of this touch's is being made a move.
  var claimed = false
}

extension PaperBoardController {
  /// A touch went down with something selected: what it began on, against the selection's box and PaperKit's resize
  /// handles, for the log, and remembered when it began on a handle inside the box.
  func selectionTouchDown(_ touch: UITouch) {
    selectionDrag.box = nil
    selectionDrag.claimed = false
    guard drawsHere, !paper.selection.isEmpty else { return }
    let box = selectionBox
    let spot = boardPoint(touch.location(in: view))
    let startView = touch.view.map { String(describing: type(of: $0)) } ?? ""
    let inside = box.insetBy(dx: 0.5, dy: 0.5).contains(spot)
    var handles: [[Double]] = []
    var looks: [UIView] = [paper.view]
    var seen = 0
    while let here = looks.popLast(), seen < 3_000 {
      seen += 1
      looks += here.subviews
      guard !here.isHidden, PaperProbe.isResizeHandle(String(describing: type(of: here))) else { continue }
      handles.append(rect(boardRect(here.convert(here.bounds, to: view))))
    }
    let onHandle = PaperProbe.isResizeHandle(startView)
    // On the handle's own knob, a quarter of which lies inside the box, the touch is a stretch he meant.
    let knob = touch.view.map { boardRect($0.convert($0.bounds, to: view)) } ?? .null
    let onKnob = onHandle && knob.contains(spot)
    if onHandle, inside, !onKnob {
      let keys = paper.selection.map(Self.key)
      selectionDrag.box = box
      selectionDrag.frames = Dictionary(
        uniqueKeysWithValues: keys.compactMap { key in inkFrames[key].map { (key, $0) } })
      selectionDrag.start = spot
      selectionDrag.end = spot
      selectionDrag.handle = "\(rect(knob))"
    }
    log.event(
      "whiteboard",
      [
        "action": "selection_touch", "board": model.board.id, "at": point(spot), "selection_box": rect(box),
        "on_selection": inside, "start_view": startView, "handles": handles, "selected": paper.selection.count,
        "handle_inside": onHandle && inside && !onKnob, "on_knob": onKnob,
      ])
  }

  /// The finger that went down on a handle inside the selection, as it goes.
  func selectionTouchMoved(_ touch: UITouch) {
    guard selectionDrag.box != nil else { return }
    selectionDrag.end = boardPoint(touch.location(in: view))
  }

  /// Story 1201: a stretch PaperKit made of a drag begun on a handle inside the selection is the finger's move instead:
  /// after the lift its step is taken back and the selection goes by the finger's travel, room made below as for any
  /// drop, one Undo named *Move*. True when the change was this one's to handle.
  func resizeAsMove(_ change: PaperProbe.InkChange, undo: UndoManager?, split: Bool) -> Bool {
    // PaperKit says more while the same touch stretches: those are this move's too.
    if selectionDrag.claimed, selectionDrag.box != nil, run != nil { return true }
    // A move the owners-apart rule puts right (story 1145) is that rule's to take back.
    guard let box = selectionDrag.box, !selectionDrag.claimed, !split, run != nil, change.added.isEmpty,
      change.removed.isEmpty,
      undo?.isUndoing != true, undo?.isRedoing != true,
      PaperProbe.resizeIsMove(change.moved, selected: Set(selectionDrag.frames.keys), onHandleInside: true)
    else { return false }
    let watch = selectionDrag
    let frames = watch.frames
    let handle = watch.handle
    watch.claimed = true
    Task { @MainActor [weak self] in
      guard let self else { return }
      // The finger is still down while PaperKit stretches: the move waits for the lift, up to 3 s.
      var waited = 0
      while self.run != nil, waited < 60 {
        try? await Task.sleep(for: .milliseconds(50))
        waited += 1
      }
      let travel = CGVector(dx: watch.end.x - watch.start.x, dy: watch.end.y - watch.start.y)
      watch.box = nil
      let stretched = frames.keys.compactMap { self.paper.markup?.strokeFrames[$0] }.reduce(CGRect.null) {
        $0.union($1)
      }
      var event: [String: Any] = [
        "action": "paper_resize_as_move", "board": self.model.board.id, "before": self.rect(box),
        "stretched": self.rect(stretched), "travel": [self.round(travel.dx), self.round(travel.dy)], "handle": handle,
        "strokes": frames.count, "waited_ms": waited * 50,
      ]
      let tookBack = self.quietly { self.takeBackPaperKitsStep(why: "resize_as_move") }
      let now = self.paper.markup?.strokeFrames ?? [:]
      let undid = frames.allSatisfy { key, was in
        now[key].map { abs($0.minX - was.minX) + abs($0.minY - was.minY) + abs($0.width - was.width) < 1 } ?? false
      }
      event["took_back"] = tookBack
      event["undid_stretch"] = undid
      // Not sure what came back: PaperKit's stretch stays, and its step goes back on.
      guard undid, let live = self.paper.markup else {
        if tookBack { self.quietly { self.paper.undoManager?.redo() } }
        self.log.event("whiteboard", event)
        return
      }
      let elements = live.subelements.strokes
      let dragged = Set(elements.indices.filter { frames[Self.key(elements[$0].elementID)] != nil })
      let (strokes, hashes) = self.opStrokes(live)
      let tags = self.model.outline(of: strokes).tags
      let others = strokes.indices.filter { !dragged.contains($0) }.map { strokes[$0] }
      let ink = BoardOps.shownBoxes(
        strokes: others, texts: self.model.texts, groups: self.model.strokeMeta.groups, folds: tags)
      let push = BoardRoom.drop(box.offsetBy(dx: travel.dx, dy: travel.dy), from: box, among: ink)
      var plan =
        push.map {
          BoardOps.plan(
            [.translateBelow(y: $0.cut, dy: $0.dy)], strokes: strokes, texts: self.model.texts,
            metas: self.model.strokeMeta, folds: tags, pages: self.pages, board: self.board)
        } ?? BoardOps.Plan(pagesBefore: self.pages, pagesAfter: self.pages)
      for index in dragged { plan.offsets[index] = travel }
      // Story 1351 (#1528): the connectors joined to what moved follow it to where it lands, not to PaperKit's stretch
      // that was just taken back.
      BoardConnectors.follow(
        &plan, strokes: strokes, texts: self.model.texts, metas: self.model.strokeMeta, folds: tags)
      let framesBefore = self.inkFrames
      self.registerStepBack(to: live, named: "Move")
      guard let (held, _, _) = self.put(plan, on: live, hashes: hashes, named: "Move", stepBack: false) else {
        event["failed"] = true
        self.log.event("whiteboard", event)
        return
      }
      self.model.stepped(held.inkDrawing)
      self.noteInk(held, since: framesBefore, report: true)
      let after = frames.keys.compactMap { held.strokeFrames[$0] }.reduce(CGRect.null) { $0.union($1) }
      event.merge(["after": self.rect(after), "room": push != nil, "moved": plan.moved]) { $1 }
      if let push { event.merge(["cut": Double(push.cut), "dy": Double(push.dy)]) { $1 } }
      self.log.event("whiteboard", event)
    }
    return true
  }

  /// A point in this view, in board points.
  func boardPoint(_ at: CGPoint) -> CGPoint {
    let visible = paper.contentVisibleFrame
    let scale = visible.width / max(view.bounds.width, 1)
    return CGPoint(x: visible.minX + at.x * scale, y: visible.minY + at.y * scale)
  }

  /// A rect in this view, in board points.
  func boardRect(_ box: CGRect) -> CGRect {
    let visible = paper.contentVisibleFrame
    let scale = visible.width / max(view.bounds.width, 1)
    return CGRect(
      x: visible.minX + box.minX * scale, y: visible.minY + box.minY * scale, width: box.width * scale,
      height: box.height * scale)
  }
}
