//  A board on paper: the press-and-hold menu and what it offers, room by hand, the margin's Pencil hold, the Pencil's
//  pick up, and ink swapped in place (replaceInk). Moved from PaperBoard.swift as it was (context-grabber-fz4x).

import ContextCore
import PaperKit
import PencilKit
import UIKit

extension PaperBoardController {
  /// Story 858, as the web board: a finger held in the margin is the room handle, and the drag opens or closes room
  /// when it lifts; held still there, or anywhere on the page, it brings up the menu.
  @objc func held(_ hold: UILongPressGestureRecognizer) {
    let spot = hold.location(in: view)
    let at = lines.columnPoint(of: view.convert(spot, to: lines))
    switch hold.state {
    case .began:
      holdMenu = nil
      holdBegan = Date(timeIntervalSinceNow: -hold.minimumPressDuration - 0.2)
      if marginTry?.tool == .finger { marginTry?.held = true }
      if at.x < BoardMargin.width,
        model.outline(of: paper.markup.map { opStrokes($0).strokes } ?? []).header(at: at.y) == nil
      {
        grip = (at.y, spot)
        scrolls(false)
        roomBandBegan(at: at.y, tool: "finger")
      } else {
        showHoldMenu(at: at, spot: spot)
      }
    case .changed:
      guard let grip else { return }
      roomBandMoved(dy: (spot.y - grip.spot.y) / max(screenScale, 0.01))
    case .ended, .cancelled, .failed:
      guard let grip else {
        holdLifted(at: at)
        return
      }
      self.grip = nil
      scrolls(true)
      let dy = (spot.y - grip.spot.y) / max(screenScale, 0.01)
      roomBandEnded(why: hold.state == .ended ? "lifted" : "cancelled")
      if hold.state == .ended, abs(dy) >= BoardRoom.line / 2 {
        room(at: grip.y, dy: dy, why: "margin_drag")
      } else if hold.state == .ended {
        showHoldMenu(at: CGPoint(x: 0, y: grip.y), spot: grip.spot)
      }
    default:
      break
    }
  }

  /// PaperKit's own scrolling, off while a finger holds the margin's handle so the drag is the handle's.
  /// ponytail: found by walking PaperKit's views for its scroll view; a PaperKit setting is the upgrade if one comes.
  private func scrolls(_ on: Bool) {
    func scrollViews(_ view: UIView) -> [UIScrollView] {
      ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrollViews)
    }
    for scroll in scrollViews(paper.view) { scroll.panGestureRecognizer.isEnabled = on }
  }

  /// Stories 874, 1186, 1187: the rows are ContextCore's, by what the finger is on.
  private func showHoldMenu(at point: CGPoint, spot: CGPoint) {
    let strokes = paper.markup.map { opStrokes($0).strokes } ?? []
    let outline = model.outline(of: strokes)
    // Story 1310: held on his selection, the menu is about all of it (a lasso, then To text from the hold).
    let elements = paper.markup?.subelements.strokes ?? []
    let selected = zip(elements, strokes).filter { paper.selection.contains($0.0.elementID) }.flatMap { $0.1.ids }
    let menu = outline.holdMenu(
      at: point, inMargin: point.x < BoardMargin.width, slop: WhiteboardTurn.tapReach / max(screenScale, 0.01),
      selected: selected)
    let items = toText.reading ? menu.choices.filter { $0 != .toText } : menu.choices
    holdMenu = HoldMenu(spot: spot, y: point.y, items: items, names: menu.names, on: menu.on)
    log.event(
      "board_outline",
      [
        "action": "hold_menu", "board": model.board.id, "y": Double(point.y), "x": Double(point.x),
        "items": items.map(\.id), "on": menu.on, "strokes": menu.names.count,
      ])
  }

  /// A choice from the hold menu.
  func chose(_ item: HoldMenu.Item) {
    guard let menu = holdMenu else { return }
    holdMenu = nil
    log.event(
      "board_outline",
      ["action": "hold_chose", "board": model.board.id, "item": item.id, "on": menu.on, "strokes": menu.names.count])
    switch item {
    case .select: holdSelect(menu.names)
    case .toText: holdToText(menu.names)
    case .delete: holdDelete(menu.names)
    case .makeRoom: room(at: menu.y, dy: 3 * BoardRoom.line, why: "menu")
    case .paste: paste(from: "hold")
    case .makeHeader:
      _ = changeOutline("Make header") { $0.markHeader(at: menu.y, id: WhiteboardModel.newHeaderID()) }
    case .notHeader(let id):
      _ = changeOutline("Not a header") { outline in
        outline.decline(id)
        return true
      }
    case .foldAll:
      _ = changeOutline("Fold all") { outline in
        outline.foldAll()
        return true
      }
    case .unfoldAll:
      _ = changeOutline("Unfold all") { outline in
        outline.unfoldAll()
        return true
      }
    case .level(let n):
      _ = changeOutline("Collapse to \(n)") { outline in
        outline.collapse(to: n)
        return true
      }
    }
  }

  /// Room by Igor's hand (stories 858): the push at the clear line nearest `y`, `dy` in whole lines, one undo named
  /// *Make room*. Larry hears the ink that moved.
  private func room(at y: CGFloat, dy: CGFloat, why: String) {
    guard let markup = paper.markup else { return }
    let (strokes, hashes) = opStrokes(markup)
    let tags = model.outline(of: strokes).tags
    let boxes = BoardOps.shownBoxes(strokes: strokes, texts: model.texts, groups: model.strokeMeta.groups, folds: tags)
    guard let push = BoardRoom.byHand(boxes, at: y, dy: dy) else {
      log.event("board_room", ["action": "nothing", "board": model.board.id, "why": why, "y": Double(y)])
      return
    }
    let plan = BoardOps.plan(
      [.translateBelow(y: push.cut, dy: push.dy)], strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: tags, pages: pages, board: board)
    guard !plan.offsets.isEmpty else {
      log.event("board_room", ["action": "nothing_below", "board": model.board.id, "why": why, "y": Double(y)])
      return
    }
    let framesBefore = inkFrames
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, named: push.dy > 0 ? "Make room" : "Close room")
    else { return }
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    log.event(
      "board_room",
      [
        "action": "room", "board": model.board.id, "why": why, "y": Double(y), "cut": Double(push.cut),
        "dy": Double(push.dy), "moved": plan.moved, "pages": pages,
      ])
  }

  /// Stories 930–932: a Pencil stroke that went down in the margin and held still for half a second is the hold, not
  /// ink: dragged, it opens or closes room when it lifts; lifted in place, the menu. Its own stroke goes. A Pencil that
  /// moved or lifted sooner draws. Each verdict is in the log (story 933). True when it was a hold.
  func marginHeld(_ change: PaperProbe.InkChange, markup: PaperMarkup) -> Bool {
    guard model.editable, lastDown == .pencil, change.added.count == 1, change.removed.isEmpty,
      change.moved.isEmpty, touchTool.ink != nil,
      let element = markup.subelements.strokes.first(where: { Self.key($0.elementID) == change.added[0] }),
      let drawn = markup.subelements[element.elementID] as? PKStroke
    else { return false }
    let path = drawn.path.map { (point: $0.location.applying(drawn.transform), time: $0.timeOffset) }
    let verdict = BoardMarginHold.pencil(path)
    guard verdict != .notInMargin, let start = path.first?.point else { return false }
    var event: [String: Any] = [
      "action": "hold_stroke", "board": model.board.id, "tool": "pencil", "verdict": verdict.reason,
      "y": Double(start.y), "ms": Int(((path.last?.time ?? 0) - (path.first?.time ?? 0)) * 1000),
      "points": path.count, "path": BoardTouchPath.encode(path.map { .init($0.point, ms: $0.time * 1000) }),
    ]
    switch verdict {
    case .moved(let after, let by):
      event["moved_after_ms"] = Int(after * 1000)
      event["moved_by"] = Double(by.rounded())
    case .hold(let dy): event["dy"] = Double(dy.rounded())
    case .tooShort, .notInMargin: break
    }
    log.event("board_margin", event)
    guard case .hold(let dy) = verdict else { return false }
    // ponytail: PaperKit's own undo step for the stroke stays beneath, with nothing to take back, as the pick-up's does.
    var without = markup
    _ = without.subelements.removeElement(for: element.elementID)
    setMarkup(without)
    inkFrames = without.strokeFrames
    if verdict.opensRoom, model.outline(of: opStrokes(without).strokes).header(at: start.y) == nil {
      room(at: start.y, dy: dy, why: "pencil_margin_drag")
    } else {
      showHoldMenu(at: CGPoint(x: 0, y: start.y), spot: lines.convert(lines.spot(of: start), to: view))
    }
    return true
  }

  /// Story 859, as the web board: the Pencil held still on ink for 400 ms picks up the word, and the same stroke drags
  /// it. On paper the word lands when the Pencil lifts, and the Pencil's own stroke goes. True when it did.
  func pickedUp(_ change: PaperProbe.InkChange, markup: PaperMarkup, before: [String: CGRect]) -> Bool {
    guard change.added.count == 1, change.removed.isEmpty, change.moved.isEmpty, touchTool.ink != nil,
      let element = markup.subelements.strokes.first(where: { Self.key($0.elementID) == change.added[0] }),
      let drawn = markup.subelements[element.elementID] as? PKStroke
    else { return false }
    let path = drawn.path.map { (point: $0.location.applying(drawn.transform), time: $0.timeOffset) }
    guard BoardOutline.isHold(path), BoardMarginHold.pencil(path) == .notInMargin else { return false }
    var without = markup
    _ = without.subelements.removeElement(for: element.elementID)
    let (strokes, hashes) = opStrokes(without)
    let outline = model.outline(of: strokes)
    guard let picked = outline.pickUp(path) else { return false }
    let names = Set(picked.names)
    let still = hypot(picked.by.dx, picked.by.dy) <= BoardOutline.holdStill
    let elements = without.subelements.strokes
    let framesBefore = before
    if still {
      // Held and lifted: the word is left selected; the Pencil's dot goes.
      setMarkup(without)
      inkFrames = without.strokeFrames
      let chosen = strokes.indices.filter { strokes[$0].ids.contains(where: names.contains) }
      paper.selection = Set(chosen.compactMap { elements.indices.contains($0) ? elements[$0].elementID : nil })
    } else {
      let plan = BoardOps.plan(
        [.translateIDs(picked.names, dx: picked.by.dx, dy: picked.by.dy)], strokes: strokes, texts: model.texts,
        metas: model.strokeMeta, folds: outline.tags, pages: pages, board: board)
      // ponytail: the step goes back to the board without the Pencil's stroke; PaperKit's own step for that stroke
      // stays beneath it and finds nothing to take back.
      guard let (held, _, _) = put(plan, on: without, hashes: hashes, named: "Move") else { return false }
      model.stepped(held.inkDrawing)
      noteInk(held, since: framesBefore, report: true)
    }
    log.event(
      "board_word",
      [
        "action": still ? "picked_up" : "moved", "board": model.board.id, "strokes": picked.names.count,
        "dx": Double(picked.by.dx), "dy": Double(picked.by.dy), "path_points": path.count,
        "held_ms": Int(((path.last?.time ?? 0) - (path.first?.time ?? 0)) * 1000),
      ])
    return true
  }

  /// The strokes with these element keys swapped for `strokes`, as one undo named `name` (stories 920, 923, 940): saved,
  /// and told to Larry as ink added and erased (naming the texts it `reworded`), never a stroke for Claude to answer. Nil
  /// before the markup is laid out.
  @discardableResult
  func replaceInk(
    removing keys: Set<String>, adding strokes: [PKStroke], named name: String, reworded: [String]? = nil
  ) -> PaperMarkup? {
    guard var markup = paper.markup else { return nil }
    let before = markup
    for id in markup.subelements.strokes.map(\.elementID) where keys.contains(Self.key(id)) {
      _ = markup.subelements.removeElement(for: id)
    }
    if !strokes.isEmpty { markup.append(contentsOf: PKDrawing(strokes: strokes)) }
    forgetPaste()
    let landed = setMarkup(markup, stepBack: before, named: name)
    let framesBefore = inkFrames
    let held = landed.held
    inkFrames = held.strokeFrames
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true, reworded: reworded)
    showLines()
    redrawSoon()
    showMarksSoon()
    return held
  }
}
