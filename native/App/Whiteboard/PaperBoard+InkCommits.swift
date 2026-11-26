//  A board on paper: the board's own changes to the ink: a kept mark, a batch of Larry's, a plan put on the markup, a
//  selection he names, the strokes' names, what changed told to Larry, labels moved, and the redraw. Moved from
//  PaperBoard.swift as it was (context-grabber-fz4x).

import ContextCore
import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// A kept mark into the markup, and any page it needs in the same change: one undo takes them both. PaperKit registers no
  /// undo for a markup that's set: left to itself, the next undo took back the stroke before the kept mark, and the mark
  /// stayed (the simulator, iOS 27, 2026-11-03). Its own steps go on working after this, as the elements keep their ids.
  func keep(_ strokes: [PKStroke], named name: String) {
    let started = CACurrentMediaTime()
    guard var markup = paper.markup else {
      // Not laid out yet: the load takes the model's drawing, with this in it.
      log.event("whiteboard", ["action": "paper_keep", "board": model.board.id, "no_markup": true])
      return
    }
    let undo = paper.undoManager
    let (couldUndo, couldRedo) = (undo?.canUndo ?? false, undo?.canRedo ?? false)
    // context-grabber-a3w: a keep leaves the pen in hand as it was; if setting the markup ever changed it, it goes back,
    // to the tool the picker shows rather than one the board held and Igor may no longer (story 1091).
    let tool = paper.drawingTool
    let toolBefore = toolText(tool)
    let wanted = board.pages(after: pages, inkMaxY: model.drawing.bounds.maxY, redoWaiting: false)
    let made = PKDrawing(strokes: strokes)
    let before = markup
    if wanted > pages { markup.bounds = board.bounds(pages: wanted) }
    Self.appendKept(made.strokes, to: &markup)
    let landed = setMarkup(markup, stepBack: before, named: name)
    let toolAfter = toolText(paper.drawingTool)
    let restore = decidingTool.tool ?? tool
    if toolAfter != toolBefore { paper.drawingTool = restore }
    let pagesBefore = pages
    pages = wanted
    run?.pageAdded = wanted > pagesBefore
    showLines()
    showPageNumber()
    redrawSoon()
    let held = landed.held
    let framesBefore = inkFrames
    inkFrames = held.strokeFrames
    let whole = held.inkDrawing
    model.settled(whole)
    noteInk(held, since: framesBefore, report: true)
    // The names Larry knows them by, from the mark as made and as PaperKit gives it back: the spec's "Larry knows a kept
    // mark as one stroke".
    let back = PKDrawing(strokes: Array(whole.strokes.suffix(strokes.count)))
    let idsMade = WhiteboardModel.strokesForLarry(made).map(\.id)
    let idsBack = WhiteboardModel.strokesForLarry(back).map(\.id)
    // #883: the pen PaperKit holds the kept mark at, beside the keep's own `width`.
    let widthBack: Double =
      back.strokes.first.map {
        Double(WhiteboardStrokes.width(sizes: $0.path.map(\.size.width), transform: $0.transform))
      } ?? 0
    log.event(
      "whiteboard",
      [
        "action": "paper_keep", "board": model.board.id, "name": name, "strokes": strokes.count,
        "total": whole.strokes.count, "undo_name": undo?.undoActionName ?? "",
        "pages_before": pagesBefore, "pages": wanted, "same_ids": idsMade == idsBack, "ids_made": idsMade.count,
        "ids_back": idsBack.count, "ink": rect(made.bounds), "visible": rect(paper.contentVisibleFrame),
        "in_view": paper.contentVisibleFrame.intersects(made.bounds), "screen_scale": Double(screenScale),
        "width_back": widthBack,
        "tool_before": toolBefore, "tool_after": toolAfter, "tool_restored": toolAfter != toolBefore,
        "tool_restored_to": toolText(restore), "picker_tool": pickerText,
        "sheet": rect(lines.bounds), "markup": rect(held.bounds),
        "drift": round(hypot(made.bounds.minX - back.bounds.minX, made.bounds.minY - back.bounds.minY)),
        "could_undo": couldUndo, "could_redo": couldRedo, "can_undo": undo?.canUndo ?? false,
        "can_redo": undo?.canRedo ?? false, "undo_on_window": undo != nil && undo === view.window?.undoManager,
        "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterKeep)
    lookForInk(made.bounds, why: "kept")
    lookAtKeptInk(strokes, why: "keep")
  }

  /// A kept mark's strokes into `markup`, one append each (bead context-grabber-pbvt, story 650): appended all at once,
  /// three circles of Larry's kept by Keep all drew in part black or not at all on the iPad simulator in 17 of 152 keeps,
  /// with PaperKit holding them purple; one append each, in the same one change and one undo, 1 of 145. `keepWay`
  /// `batch` (the simulator's keep loop) puts them in all at once, to count that again.
  static func appendKept(_ strokes: [PKStroke], to markup: inout PaperMarkup) {
    guard keepWay != .batch else {
      markup.append(contentsOf: PKDrawing(strokes: strokes))
      return
    }
    for stroke in strokes { markup.append(contentsOf: PKDrawing(strokes: [stroke])) }
  }

  /// Stories 814–816, 840–842: a batch of Larry's changes on the markup. Every stroke it moves moves whole, by a transform
  /// on its own element (its id kept, so PaperKit's own steps go on working); strokes it erases go, the ink he draws is
  /// added, the column grows to the pages it needs, and the lot is one undo named for the batch, the page count
  /// included. Text and notes alone leave the markup as it is. What came of it is said to the caller (#1040): not there
  /// before the markup is laid out, failed when PaperKit didn't take the moves as moves.
  func applyOps(_ batch: BoardOps.Batch) -> BoardCanvasOutcome {
    guard let markup = paper.markup else { return .unavailable }
    let started = CACurrentMediaTime()
    let (strokes, hashes) = opStrokes(markup)
    let plan = BoardOps.plan(
      batch.ops, strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: model.outline(of: strokes).tags, ghosts: model.textGhosts, pages: pages, board: board)
    guard plan.changesBoard else {
      select(plan.select)
      return .applied(plan)
    }
    // #937: his texts with notes are ink in the same undo.
    let lettered = model.letter(plan.inked)
    guard
      let (held, renamed, drawn) = put(plan, on: markup, hashes: hashes, adding: lettered.strokes, named: batch.label)
    else { return .failed(reason: "paper_ops_failed") }
    model.keep(lettered: lettered.texts)
    model.opsApplied(held.inkDrawing, renamed: renamed, drawn: drawn)
    model.inkReset(Self.allHashes(held))
    log.event(
      "whiteboard",
      [
        "action": "paper_ops", "board": model.board.id, "label": batch.label, "moved": plan.offsets.count,
        "erased": plan.erase.count, "drawn": plan.added.count, "elements": held.subelements.count,
        "pages_before": plan.pagesBefore, "pages": pages, "can_undo": paper.undoManager?.canUndo ?? false,
        "undo_name": paper.undoManager?.undoActionName ?? "", "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterOps)
    select(plan.select)
    return .applied(plan)
  }

  func opStrokes(_ markup: PaperMarkup) -> (strokes: [BoardOps.Stroke], hashes: [[String]]) {
    model.opStrokes(markup.inkDrawing.strokes)
  }

  /// A plan on the markup, with `extra` ink added in the same change, as one undo named `name`: moves, hides, erases,
  /// Larry's ink, the pages. Nil when PaperKit didn't take the moves as moves (the log says so); nothing is set then.
  func put(
    _ plan: BoardOps.Plan, on start: PaperMarkup, hashes: [[String]], adding extra: [PKStroke] = [], named name: String,
    stepBack: Bool = true, undoTo: PaperMarkup? = nil
  ) -> (held: PaperMarkup, renamed: [(from: [String], to: [String])], drawn: [(hash: [String], name: String)])? {
    var markup = start
    let elements = markup.subelements.strokes
    let before = markup
    let countBefore = markup.subelements.count
    var renamed: [(from: [String], to: [String])] = []
    for (index, shift) in plan.offsets where elements.indices.contains(index) {
      var moved = elements[index]
      moved.applyTransform(CGAffineTransform(translationX: shift.dx, y: shift.dy))
      _ = markup.subelements.updateOrAppend(moved)
      renamed.append((hashes[index], Self.hashes(moved)))
    }
    // Story 847: hidden ink stays where it is with no colour to see; its names don't change, as the hash ignores alpha.
    for (index, hidden) in plan.hidden where elements.indices.contains(index) {
      guard var stroke = markup.subelements[elements[index].elementID] as? PKStroke else { continue }
      // ponytail: shown again at full strength, whatever alpha the ink had; the Pencil's inks draw opaque colours.
      stroke.ink = WhiteboardInk.withAlpha(stroke.ink, hidden ? 0 : 1, at: "hide")
      _ = markup.subelements.updateOrAppend(stroke)
    }
    // A moved stroke that came back as a new element would leave its old self behind: nothing is set, and the log says so.
    guard markup.subelements.count == countBefore else {
      log.event(
        "whiteboard",
        [
          "action": "paper_ops_failed", "board": model.board.id, "label": name, "elements_before": countBefore,
          "elements": markup.subelements.count,
        ])
      return nil
    }
    for index in plan.erase where elements.indices.contains(index) {
      _ = markup.subelements.removeElement(for: elements[index].elementID)
    }
    // His ink, in his colour unless he names one, under his names.
    var drawn: [(hash: [String], name: String)] = []
    var theirs: [PKStroke] = []
    for stroke in plan.added {
      let shown = stroke.color.map { UIColor(rgb: $0) } ?? WhiteboardTurn.Who.larry.color
      let color = stroke.hidden ? shown.withAlphaComponent(0) : shown
      let made = WhiteboardModel.strokes([stroke.points], color: color, width: stroke.width, spacing: 4)
      theirs += made
      for one in made {
        markup.append(contentsOf: PKDrawing(strokes: [one]))
        drawn.append((Self.hashes(one), stroke.id))
      }
    }
    model.rememberTheirs(theirs)
    if !extra.isEmpty { Self.appendKept(extra, to: &markup) }
    if plan.pagesAfter != pages { markup.bounds = board.bounds(pages: plan.pagesAfter) }
    let landed = setMarkup(markup, stepBack: stepBack ? undoTo ?? before : nil, named: name)
    putKeys = Set(markup.strokeFrames.keys)
    pages = plan.pagesAfter
    let held = landed.held
    inkFrames = held.strokeFrames
    showLines()
    showPageNumber()
    redrawSoon()
    showMarksSoon()
    model.planPut(plan, drawn: drawn)
    return (held, renamed, drawn)
  }

  /// Story 848: the strokes Larry names, selected as a lasso would leave them; nothing when he names none.
  private func select(_ names: [String]) {
    guard !names.isEmpty, let markup = paper.markup else { return }
    let keys = model.elementKeys(named: names)
    paper.selection = Set(markup.subelements.strokes.map(\.elementID).filter { keys.contains(Self.key($0)) })
  }

  /// A stroke's names as the board sends them, one per visible stretch: remade as `inkDrawing` remakes strokes, since
  /// PencilKit throws on the markup's own.
  static func hashes(_ stroke: PKStroke) -> [String] {
    let remade = PKStroke(
      ink: stroke.ink, path: stroke.path, transform: stroke.transform, mask: stroke.mask, randomSeed: stroke.randomSeed)
    return WhiteboardModel.strokesForLarry(PKDrawing(strokes: [remade])).map(\.id)
  }

  /// Each of `keys`' strokes' names, by element key (story 843): every stroke's with `keys` nil.
  static func hashes(of keys: Set<String>?, in markup: PaperMarkup) -> [String: [String]] {
    if let keys, keys.isEmpty { return [:] }
    var out: [String: [String]] = [:]
    for stroke in markup.subelements.strokes {
      let key = PaperHost.key(stroke.elementID)
      if let keys, !keys.contains(key) { continue }
      out[key] = hashes(stroke)
    }
    return out
  }

  static func allHashes(_ markup: PaperMarkup) -> [String: [String]] { hashes(of: nil, in: markup) }

  /// Story 843: what changed in the ink since `frames`, told to Larry as added, erased and moved (`report`), or only
  /// taken in.
  func noteInk(
    _ markup: PaperMarkup, since frames: [String: CGRect], report: Bool, reworded: [String]? = nil
  ) {
    let change = PaperProbe.inkChange(before: frames, after: markup.strokeFrames)
    guard !change.isEmpty else { return }
    let updated = Self.hashes(of: Set(change.added + change.moved.map(\.id)), in: markup)
    model.inkElements(updated: updated, removed: change.removed, report: report, reworded: reworded)
  }

  /// Story 896: kept labels moved down off ink, by their places in the markup's strokes, with any pages that needs, in
  /// one undo step. Moved in place, so every stroke keeps its id.
  private func move(_ moves: [Int: CGFloat]) {
    guard var markup = paper.markup else { return }
    let strokes = markup.subelements.strokes
    let before = markup
    for (i, dy) in moves where strokes.indices.contains(i) {
      var stroke = strokes[i]
      stroke.transform = stroke.transform.concatenating(CGAffineTransform(translationX: 0, y: dy))
      markup.subelements.updateOrAppend(stroke)
    }
    let wanted = board.pages(after: pages, inkMaxY: markup.inkDrawing.bounds.maxY, redoWaiting: false)
    if wanted > pages { markup.bounds = board.bounds(pages: wanted) }
    setMarkup(markup, stepBack: before, named: WhiteboardModel.tidyUndoName)
    pages = wanted
    let framesBefore = inkFrames
    inkFrames = markup.strokeFrames
    model.stepped(markup.inkDrawing)
    noteInk(markup, since: framesBefore, report: true)
    showLines()
    showPageNumber()
    log.event(
      "whiteboard",
      ["action": "paper_move", "board": model.board.id, "strokes": moves.count, "pages": pages])
    redrawSoon()
  }

  /// PaperKit sometimes never draws a markup that's set: the ink is held and counted, and the tile it falls on stays empty,
  /// whatever is set or scrolled after. A change of zoom draws it. On the simulator, iOS 27: 15 of 180 pastes without this, 0 of
  /// 60 with it, and a zoom brought back each of the 7 in the run that tried one. A set that opens a board is followed by a
  /// zoom anyway, the fit. So the zoom moves too little to see and back, with the touches done and the view at rest.
  /// ponytail: works around a miss inside PaperKit, unseen on a real device so far; drop it if `paper_ink_look` shows the iOS
  /// it's built for no longer misses without it.
  /// `step`: how far a centred page moves and back, in points; a heal after a measured miss moves further (#906).
  func redrawSoon(step: CGFloat = 1) {
    redrawing?.cancel()
    redrawing = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.2))
      var seen: CGRect?
      while !Task.isCancelled, let self, self.touchesDown > 0 || self.paper.contentVisibleFrame != seen {
        seen = self.paper.contentVisibleFrame
        try? await Task.sleep(for: .seconds(0.1))
      }
      guard let self, !Task.isCancelled else { return }
      let config = self.paper.scrollConfiguration
      let (zoom, place) = (config.zoomScale, self.paper.contentVisibleFrame)
      let range = self.paper.zoomRange
      let nudged = zoom * (zoom < range.upperBound ? 1.002 : 0.998)
      // #829: with the page narrower than the screen PaperKit centres it (the view starts left of the page), and a zoom
      // set there recursed inside PaperKit until the stack ran out: zoom 1.017 at the bottom of 1.017...3, asked 1.019, on
      // an iPad simulator. Centred, the zoom is left alone and the view moves instead (#833).
      let centred = place.minX < 0
      self.log.event(
        "whiteboard",
        [
          "action": "paper_redraw_nudge", "board": self.model.board.id, "zoom": zoom, "to": nudged,
          "range_lo": range.lowerBound, "range_hi": range.upperBound, "visible": self.rect(place),
          "how": centred ? "frame" : "zoom", "step": Double(step),
        ])
      if centred {
        // #833: centred, a point down and back instead, which draws the missed tile without setting the zoom.
        self.paper.contentVisibleFrame = place.offsetBy(dx: 0, dy: step)
        try? await Task.sleep(for: .seconds(0.05))
        if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
        return
      }
      config.zoomScale = nudged
      try? await Task.sleep(for: .seconds(0.05))
      config.zoomScale = zoom
      if self.touchesDown == 0 { self.paper.contentVisibleFrame = place }
    }
  }
}
