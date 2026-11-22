//  A board on paper: paste (⌘V, the clipboard, landing in clear room, its Delete), a keep that makes room, an outline
//  change, and the margin's header marks. Moved from PaperBoard.swift as it was (context-grabber-fz4x).

import ContextCore
import PaperKit
import PencilKit
import UIKit
import UniformTypeIdentifiers

extension PaperBoardController {
  /// ⌘V, ahead of whatever PaperKit's own views would do with it.
  override var keyCommands: [UIKeyCommand]? {
    let key = UIKeyCommand(input: "v", modifierFlags: .command, action: #selector(pasteKeyPressed))
    key.wantsPriorityOverSystemBehavior = true
    return (super.keyCommands ?? []) + [key]
  }

  @objc private func pasteKeyPressed() { paste(from: "key") }

  /// Text is ink, in the middle of the view. Copied strokes are PaperKit's to place if it will, and landed here if not: nothing
  /// on the simulator takes them, and whether the iPad's PaperKit does is what this line will say. Only a picture is refused: only
  /// strokes are saved, so one on the sheet would go when he left. Strokes first, as a copy may hold a picture of them too. hasStrings
  /// asks without reading, so no prompt shows for nothing. (The spec's "Paste on paper".)
  func paste(from how: String) {
    let clipboard = UIPasteboard.general
    var event: [String: Any] = [
      "action": "paper_paste", "board": model.board.id, "how": how, "has_text": clipboard.hasStrings,
      "has_image": clipboard.hasImages, "types": Array(clipboard.types.prefix(8)),
      "strokes_before": model.drawing.strokes.count,
    ]
    defer { log.event("whiteboard", event) }
    if clipboard.hasStrings, let text = clipboard.string {
      event["went"] = "ink"
      model.paste(text)
      return
    }
    let copied = copiedStrokes(clipboard)
    if copied == nil, clipboard.hasImages {
      event["went"] = "refused_picture"
      return
    }
    let paste = #selector(UIResponderStandardEditActions.paste(_:))
    let copiesReply = copied?.contains { model.reply(at: $0.path.creationDate, seed: $0.randomSeed) != nil } == true
    let took = !copiesReply && UIApplication.shared.sendAction(paste, to: nil, from: self, for: nil)
    if took {
      event["went"] = "paperkit"
    } else if let copied {
      event["went"] = "landed_here"
      event["strokes"] = copied.count
      model.paste(strokes: moved(copied))
    } else {
      event["went"] = "nobody"
    }
  }

  /// Story 852, as the web board's paste: in the clear patch of the view nearest its middle; else room opens at the
  /// clear line nearest the middle, the ink below pushed down whole lines, and the paste lands in it. The push and the
  /// paste are one undo. It lands selected, with Delete beside it.
  func land(paste strokes: [PKStroke]) -> Bool {
    guard let markup = paper.markup, !strokes.isEmpty else { return false }
    let started = CACurrentMediaTime()
    let (ink, hashes) = opStrokes(markup)
    let block = PKDrawing(strokes: strokes).bounds
    let view = paperOnScreen
    let tags = model.outline(of: ink).tags
    let landing = BoardRoom.place(
      block.size, view: view,
      ink: BoardOps.shownBoxes(strokes: ink, texts: model.texts, groups: model.strokeMeta.groups, folds: tags),
      pageWidth: board.width)
    let by = CGAffineTransform(translationX: landing.origin.x - block.minX, y: landing.origin.y - block.minY)
    let placed = strokes.map {
      PKStroke(
        ink: $0.ink, path: $0.path, transform: $0.transform.concatenating(by), mask: $0.mask,
        randomSeed: $0.randomSeed)
    }
    let ops = landing.push.map { [BoardOps.Op.translateBelow(y: $0.cut, dy: $0.dy)] } ?? []
    var plan = BoardOps.plan(
      ops, strokes: ink, texts: model.texts, metas: model.strokeMeta, folds: tags, pages: pages, board: board)
    let landedBox = PKDrawing(strokes: placed).bounds
    plan.pagesAfter = board.pages(after: plan.pagesAfter, inkMaxY: landedBox.maxY, redoWaiting: false)
    let framesBefore = inkFrames
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, adding: placed, named: "Paste") else { return false }
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    let ids = Array(held.subelements.strokes.map(\.elementID).suffix(placed.count))
    pasted = Set(ids.map(Self.key))
    paper.selection = Set(ids)
    showPasted()
    log.event(
      "whiteboard",
      [
        "action": "paper_paste_landed", "board": model.board.id, "strokes": placed.count, "at": rect(landedBox),
        "view": rect(view), "clear": landing.push == nil, "cut": landing.push.map { Double($0.cut) } ?? NSNull(),
        "dy": Double(landing.push?.dy ?? 0), "moved": plan.moved, "pages_before": plan.pagesBefore, "pages": pages,
        "selected": paper.selection.count, "ms": ms(CACurrentMediaTime() - started),
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterKeep)
    lookForInk(landedBox, why: "pasted")
    return true
  }

  /// #938 (story 992): a ghost of Larry's text kept where Igor's ink has come under it; #894 (stories 1004–1006): his
  /// marks kept over ink written after his picture. The room opens and the marks land in one change, one undo named
  /// *Keep* (*Keep group* for a group), as a paste and its room are one. `why` names it in the log: keep_text,
  /// keep_late or keep_group.
  func keep(_ strokes: [PKStroke], making push: BoardRoom.Push, why: String) -> Bool {
    guard let markup = paper.markup, !strokes.isEmpty else { return false }
    let (ink, hashes) = opStrokes(markup)
    var plan = BoardOps.plan(
      [.translateBelow(y: push.cut, dy: push.dy)], strokes: ink, texts: model.texts, metas: model.strokeMeta,
      folds: model.outline(of: ink).tags, pages: pages, board: board)
    plan.pagesAfter = board.pages(
      after: plan.pagesAfter, inkMaxY: PKDrawing(strokes: strokes).bounds.maxY, redoWaiting: false)
    let framesBefore = inkFrames
    let name = why == "keep_group" ? WhiteboardModel.keepGroupUndoName : WhiteboardModel.keepUndoName
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, adding: strokes, named: name) else { return false }
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    log.event(
      "board_room",
      [
        "action": why, "board": model.board.id, "cut": Double(push.cut), "dy": Double(push.dy),
        "moved": plan.moved, "pages_before": plan.pagesBefore, "pages": pages,
      ])
    undoSoonForTests(LaunchHooks.current.whiteboard.afterKeep)
    lookAtKeptInk(strokes, why: why)
    return true
  }

  /// Stories 855–860: an outline change on the markup, one undo named `label`: what folds hides, what is below slides,
  /// and the headers are kept. A header made or unmade alone changes only the marks.
  /// `base` is the markup the change starts from (the board's own by default) and `undoTo` where its Undo goes back to
  /// (`base`, by default): a scratch-out's fold erase starts without the zigzag's other ink and undoes to before it.
  func changeOutline(
    _ label: String, on base: PaperMarkup? = nil, undoTo: PaperMarkup? = nil, _ change: (inout BoardOutline) -> Bool
  ) -> Bool {
    guard let markup = base ?? paper.markup else { return false }
    let started = CACurrentMediaTime()
    let (strokes, hashes) = opStrokes(markup)
    var outline = model.outline(of: strokes)
    let before = Dictionary(uniqueKeysWithValues: outline.headers.map { ($0.id, outline.level($0)) })
    guard change(&outline) else { return false }
    var plan = outline.plan(from: strokes, pages: pages, board: board)
    // Stories 911, 915: a fold moves ink, and the connectors follow it.
    BoardConnectors.follow(
      &plan, strokes: strokes, texts: model.texts, metas: model.strokeMeta, folds: outline.tags)
    if plan.changesBoard {
      guard let (held, renamed, _) = put(plan, on: markup, hashes: hashes, named: label, undoTo: undoTo) else {
        return false
      }
      model.opsApplied(held.inkDrawing, renamed: renamed)
      model.inkReset(Self.allHashes(held))
    }
    model.outlineChanged(outline)
    showMarks()
    tintNew(outline, before: before)
    log.event(
      "board_outline",
      [
        "action": "changed", "board": model.board.id, "label": label, "moved": plan.offsets.count,
        "hidden": plan.hidden.values.filter { $0 }.count, "shown": plan.hidden.values.filter { !$0 }.count,
        "headers": outline.headers.count, "folded": outline.headers.filter(outline.isFolded).count,
        "pages": pages, "ms": ms(CACurrentMediaTime() - started),
      ])
    return true
  }

  /// The margin's marks: ▾ beside a header, ▸ and its lines beside a folded one, a faint H beside a line that looks
  /// like one (stories 855, 861). Soon after a change, not on every stroke's every point.
  func showMarksSoon() {
    marking?.cancel()
    marking = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(0.4))
      guard !Task.isCancelled else { return }
      self?.showMarks()
    }
  }

  func showMarks() {
    guard let markup = paper.markup else { return }
    // ponytail: the whole board's outline on each change, ~ms per hundred strokes; incremental by changed line if
    // a long board feels it.
    let outline = model.outline(of: opStrokes(markup).strokes)
    // Stories 1040, 1041: the headers' ▾ go over the ink, in one spot on their baselines.
    showHeaderMarks(outline)
    var marks: [PaperLines.Mark] = []
    // Story 901: "▸ N lines folded" beside a folded header, where the eraser takes the fold.
    for marker in outline.markers {
      marks.append(
        PaperLines.Mark(
          id: "fold-\(marker.header)", y: marker.box.midY, text: marker.text, faint: false, x: marker.origin.x))
    }
    for (n, candidate) in outline.candidates().enumerated() {
      marks.append(PaperLines.Mark(id: "candidate-\(n)", y: candidate.y, text: "H", faint: true))
    }
    lines.showMarks(marks)
    noteMarksGone(outline)
  }

  /// Where the landed paste is on screen now, for its Delete.
  func showPasted() {
    var frame: CGRect?
    if !pasted.isEmpty, let markup = paper.markup {
      let box = markup.subelements.strokes.filter { pasted.contains(Self.key($0.elementID)) }
        .compactMap { markup.subelements[$0.elementID] as? PKStroke }.reduce(CGRect.null) { $0.union($1.renderBounds) }
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    if frame != pastedFrame { pastedFrame = frame }
    showSelectionLabel()
  }

  func forgetPaste() {
    guard !pasted.isEmpty else { return }
    pasted = []
    pastedFrame = nil
  }

  /// Story 852: the landed paste's Delete: its strokes go, one undo; the room it opened stays, as on the web board.
  func deletePasted() {
    guard var markup = paper.markup, !pasted.isEmpty else { return }
    let before = markup
    let gone = markup.subelements.strokes.map(\.elementID).filter { pasted.contains(Self.key($0)) }
    for id in gone { _ = markup.subelements.removeElement(for: id) }
    forgetPaste()
    let landed = setMarkup(markup, stepBack: before, named: "Delete")
    let framesBefore = inkFrames
    let held = landed.held
    inkFrames = held.strokeFrames
    model.changed(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    log.event("whiteboard", ["action": "paper_paste_deleted", "board": model.board.id, "strokes": gone.count])
  }

  private func copiedStrokes(_ clipboard: UIPasteboard) -> [PKStroke]? {
    if let data = clipboard.data(forPasteboardType: UTType.paperkit.identifier),
      let markup = try? PaperMarkup(dataRepresentation: data), !markup.subelements.strokes.isEmpty
    {
      return markup.inkDrawing.strokes
    }
    if let data = clipboard.data(forPasteboardType: PKAppleDrawingTypeIdentifier as String),
      let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty
    {
      return drawing.strokes
    }
    return nil
  }

  private func moved(_ strokes: [PKStroke]) -> [PKStroke] {
    let shift = board.pasteShift(ink: PKDrawing(strokes: strokes).bounds, visible: paperOnScreen)
    let by = CGAffineTransform(translationX: shift.dx, y: shift.dy)
    return strokes.map { stroke in
      let path =
        model.reply(at: stroke.path.creationDate, seed: stroke.randomSeed) == nil
        ? stroke.path : PKStrokePath(controlPoints: Array(stroke.path), creationDate: Date())
      return PKStroke(
        ink: stroke.ink, path: path, transform: stroke.transform.concatenating(by), mask: stroke.mask,
        randomSeed: stroke.randomSeed)
    }
  }
}
