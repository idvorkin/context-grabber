//  Larry's changes to the board (stories 814–819, 970–972): the pen and tap events he hears, the outline and headers,
//  a blocked edit, applying his batches, the ink's hashes, dissolving, the selection, lettering and the ledger.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

// MARK: - Larry's changes to the board (stories 814–819)

extension WhiteboardModel {
  /// Unix ms, the time the wire carries.
  private static var nowMs: Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded()) }

  /// The Pencil went down or up: Larry hears it on his next turn, and a change of his waits for the lift.
  func penWent(down: Bool) {
    guard down != penDown else { return }
    penDown = down
    if !down { liftedAt = .now }
    let before = events.list.count
    events.pen(down: down, t: Self.nowMs)
    if events.list.count != before, let event = events.list.last { takeOps(.event(event)) }
    if down {
      heldTask?.cancel()
      heldTask = nil
    } else {
      releaseHeldSoon()
    }
  }

  /// A finger tap on the board, in board points: Larry hears where, and which of his marks it hit (a ghost, or a text
  /// he wrote and Igor kept), if any.
  func tapped(at point: CGPoint, zoom: CGFloat) {
    let tolerance = WhiteboardTurn.tapReach / zoom
    // Story 846: a tap on one of his controls goes to him at once.
    if let overlay = overlays.hit(point, tolerance: 4 / zoom) {
      events.record(.overlayTap(id: overlay.id, event: overlay.tapEvent, t: Self.nowMs))
      log.event("board_events", ["action": "overlay_tap", "board": board.id, "overlay": overlay.id])
      sendEventsNow(why: "overlay_tap")
      return
    }
    // A finger in the margin is the margin's (story 849).
    guard point.x >= BoardMargin.width else { return }
    let hidden = turns.hiddenMarks
    let ghost = WhiteboardMarkChoice.nearest(ghosts) {
      hidden.contains($0.id) ? nil : WhiteboardTurn.reach($0.lines, kind: $0.kind, at: point, tolerance: tolerance)
    }
    let target = ghost.map { $0.text?.id ?? $0.id } ?? keptText(at: point, tolerance: tolerance)
    events.tap(at: point, target: target, t: Self.nowMs)
    if let event = events.list.last { takeOps(.event(event)) }
  }

  /// Story 849: a lone finger lifted after starting in the margin, in board points.
  func fingerLifted(from start: CGPoint, to end: CGPoint, seconds: Double) {
    guard let (gesture, y, dy) = BoardMargin.gesture(from: start, to: end, seconds: seconds) else { return }
    record(.margin(gesture: gesture, y: y, dy: dy, t: Self.nowMs))
    if gesture == .tap { marginTapped(at: y) }
  }

  /// Story 855, as the web board's margin tap: beside a header it folds or unfolds it; beside a line of ink it makes it
  /// a header; beside blank paper nothing.
  func marginTapped(at y: CGFloat) {
    guard editable else { return }
    var what = "nothing"
    let changed =
      canvas?.changeOutline(named: Self.marginStepName(what)) { outline in
        if let header = outline.header(at: y) {
          what = outline.isFolded(header) ? "unfold" : "fold"
          return outline.toggle(header.id)
        }
        what = "header"
        return outline.markHeader(at: y, id: Self.newHeaderID())
      } ?? false
    log.event(
      "board_outline", ["action": "margin_tap", "board": board.id, "y": Double(y), "did": what, "changed": changed])
  }

  /// A margin tap's Undo, named for what it did (bead context-grabber-ssl).
  static func marginStepName(_ what: String) -> String {
    switch what {
    case "header": "Make header"
    case "unfold": "Unfold"
    default: "Fold"
    }
  }

  /// A header's id, as the Cockpit takes a stroke's.
  static func newHeaderID() -> String { "h-" + UUID().uuidString.prefix(8).lowercased() }

  /// The outline over `strokes` (the canvas's, by default the drawing's), with the board's headers.
  func outline(of strokes: [BoardOps.Stroke]? = nil) -> BoardOutline {
    BoardOutline(
      strokes: strokes ?? opStrokes(drawing.strokes).strokes, headers: headers, texts: texts, groups: strokeMeta.groups,
      declined: declined)
  }

  /// The canvas applied an outline change.
  func outlineChanged(_ outline: BoardOutline) {
    if outline.declined != declined {
      declined = outline.declined
      opLedger.setDeclined(declined, board: board.id)
    }
    // Stories 902–904: a header whose ink is gone stays, so the Undo that brings the ink back brings it back folded.
    let kept = BoardOutline.keeping(outline.headers, previous: headers, live: outline.liveNames)
    guard kept != headers else { return }
    headers = kept
    opLedger.setHeaders(headers, board: board.id)
  }

  /// Story 850: the view came to rest showing `rect` (board points) at `scale`.
  func viewRested(_ rect: CGRect, scale: CGFloat) {
    guard !rect.isNull, !rect.isEmpty else { return }
    if let last = lastViewport, abs(last.rect.minY - rect.minY) < 1, abs(last.rect.height - rect.height) < 1,
      abs(last.scale - scale) < 0.001
    {
      return
    }
    lastViewport = (rect, scale)
    record(.viewport(y: rect.minY, h: rect.height, scale: scale, t: Self.nowMs))
  }

  /// Tell Larry once when a named board change is undone (stories 851, 1179).
  func undid(_ label: String) {
    record(.undo(label: label, t: Self.nowMs))
    log.event("board_ops", ["action": "undone", "board": board.id, "label": label])
  }

  private func record(_ event: BoardEvent) {
    events.record(event)
    takeOps(.event(event))
  }

  /// Story 846: the events so far go to the Cockpit now, not with the next turn. Taken, they're gone; not taken (no
  /// route yet, or no answer), they wait for the next turn, and the log says which.
  private func sendEventsNow(why: String) {
    // Story 1112: spoken words waiting go with these events.
    micTimingsGo()
    let taken = events.take()
    let report = BoardTurnReport(rev: ops.rev, opResult: ops.lastResult, taken: taken)
    let request: URLRequest
    do {
      request = try BoardEventsSend.request(board: board.id, report: report, cockpit: cockpit, build: Self.buildLine)
    } catch {
      events.restore(taken)
      log.event("board_events", ["action": "held", "board": board.id, "why": why, "reason": "\(error)"])
      return
    }
    let started = Date()
    Task { [weak self] in
      let answer: BoardEventsSend.Answer
      do {
        let (_, response) = try await URLSession.shared.data(for: request)
        answer = BoardEventsSend.answer(status: (response as? HTTPURLResponse)?.statusCode)
      } catch {
        answer = BoardEventsSend.answer(status: nil, error: error.localizedDescription)
      }
      guard let self else { return }
      var event: [String: Any] = [
        "board": self.board.id, "why": why, "events": taken.events.count,
        "ms": Int(Date().timeIntervalSince(started) * 1000),
      ]
      if taken.dropped > 0 {
        event["events_dropped"] = taken.dropped
        event["dropped_kinds"] = taken.droppedKinds
      }
      switch answer {
      case .taken:
        event["action"] = "sent"
      case .notThere:
        // ponytail: the Cockpit's POST /whiteboard/events is Larry's to build; until it answers, a tap waits for the
        // next turn. Drop this branch's log once every Cockpit has it.
        self.events.restore(taken)
        event["action"] = "held"
        event["reason"] = "no events route"
      case .away(let reason):
        self.events.restore(taken)
        event["action"] = "held"
        event["reason"] = reason
      }
      self.log.event("board_events", event)
    }
  }

  // MARK: Larry's edit blocked (stories 970–972)

  private func showBlocked(_ label: String, _ reason: String) {
    guard blocked.refused(label: label, reason: reason) else { return }
    blockedFrame = nil
    log.event("board_blocked", ["action": "shown", "board": board.id, "label": label, "reason": reason])
  }

  /// Retry: Larry gets the board again, as *Send to Larry* sends it, with what happened to his change in the turn.
  func retryBlocked() {
    let label = blocked.label ?? ""
    guard blocked.showing else { return }
    log.event("board_blocked", ["action": "retry", "board": board.id, "label": label])
    // Retry always hands Larry the board, even when he has this picture (stories 970–972, bead context-grabber-ts8a);
    // the chip stays until a picture goes (bead context-grabber-kxzk).
    if sendToLarry(handOver: true) {
      blocked.retry()
    } else {
      log.event("board_blocked", ["action": "retry_waits", "board": board.id, "label": label])
    }
  }

  /// Where the chip is on screen, window points, once per place it takes: what says whether a tap on it can land.
  func blockedLaid(_ frame: CGRect) {
    guard blocked.showing, frame != blockedFrame else { return }
    blockedFrame = frame
    log.event(
      "board_blocked",
      [
        "action": "laid", "board": board.id,
        "frame": [frame.minX, frame.minY, frame.width, frame.height].map { Double($0) },
      ])
  }

  /// ×: the chip goes and nothing is asked.
  func dismissBlocked() {
    let label = blocked.label ?? ""
    guard blocked.dismissed() else { return }
    log.event("board_blocked", ["action": "dismissed", "board": board.id, "label": label])
  }

  /// The kept text of Larry's under `point`, by its glyphs' box.
  private func keptText(at point: CGPoint, tolerance: CGFloat) -> String? {
    guard !texts.isEmpty else { return nil }
    let byTime = BoardText.byTime(texts)
    var boxes: [String: CGRect] = [:]
    for stroke in drawing.strokes {
      let t = BoardMoment.of(stroke)
      guard let text = BoardText.owning(t, in: byTime) else { continue }
      boxes[text.id] = (boxes[text.id] ?? .null).union(stroke.renderBounds)
    }
    return boxes.first { $0.value.insetBy(dx: -tolerance, dy: -tolerance).contains(point) }?.key
  }

  /// The board's half of Larry's next turn: the events since the last are taken.
  func turnReport() -> BoardTurnReport {
    let taken = events.take()
    var report = BoardTurnReport(rev: ops.rev, opResult: ops.lastResult, taken: taken)
    // Story 1270: the marks this picture takes away once it reaches him, and why.
    let drops = marksToDrop()
    if !drops.isEmpty { report.marksDropped = drops }
    return report
  }

  /// Whatever a source hears goes to every source; each batch they make goes to the one applier.
  func takeOps(_ input: BoardOpInput) {
    for (batch, source) in opBatches(from: input) { receive(batch, from: source) }
  }

  func opBatches(from input: BoardOpInput) -> [(batch: BoardOps.Batch, source: String)] {
    opSources.indices.flatMap { i in
      let source = opSources[i].name
      return opSources[i].batches(from: input).map { ($0, source) }
    }
  }

  private var opsReady: BoardOps.Readiness {
    BoardOps.readiness(penDown: penDown, liftedAt: liftedAt, now: .now)
  }

  func receive(_ batch: BoardOps.Batch, from source: String) {
    var event = BoardOps.logFields(batch)
    event["board"] = board.id
    event["source"] = source
    event["rev"] = ops.rev
    switch ops.receive(batch, board: board.id, editable: editable, ready: opsReady == .now) {
    case .ignored(let why):
      event["action"] = "ignored"
      event["why"] = why
      event["for_board"] = batch.board ?? ""
      log.event("board_ops", event)
    case .refused(let result):
      event["action"] = "refused"
      event["reason"] = result.reason ?? ""
      if let conflicts = result.conflictIDs { event["conflict_ids"] = conflicts }
      log.event("board_ops", event)
      showBlocked(batch.label, result.reason ?? "")
    case .held(let replaced):
      event["action"] = "held"
      event["pen_down"] = penDown
      if let replaced { event["replaced"] = replaced }
      log.event("board_ops", event)
      releaseHeldSoon()
    case .apply(let batch):
      apply(batch, held: false)
    }
  }

  /// A batch held for the Pencil goes once it is up and the board's pause has passed; a touch down in the meantime waits
  /// for the next lift.
  private func releaseHeldSoon() {
    guard ops.held != nil else { return }
    switch opsReady {
    case .onLift:
      return
    case .now:
      guard let waiting = ops.held else { return }
      switch ops.release(ready: true) {
      case .apply(let batch):
        apply(batch, held: true)
      case .refused(let result):
        var event = BoardOps.logFields(waiting)
        event["board"] = board.id
        event["rev"] = ops.rev
        event["held"] = true
        event["action"] = "refused"
        event["reason"] = result.reason ?? ""
        if let conflicts = result.conflictIDs { event["conflict_ids"] = conflicts }
        log.event("board_ops", event)
        showBlocked(waiting.label, result.reason ?? "")
      case .ignored, .held, nil:
        return
      }
    case .after(let wait):
      heldTask?.cancel()
      heldTask = Task { [weak self] in
        try? await Task.sleep(for: wait)
        guard !Task.isCancelled else { return }
        self?.releaseHeldSoon()
      }
    }
  }

  private func apply(_ batch: BoardOps.Batch, held: Bool) {
    let started = ContinuousClock.now
    let batch = batch.lettered(lettering)
    var event = BoardOps.logFields(batch)
    event["board"] = board.id
    event["held"] = held
    // #1040: what the canvas made of it decides what is reported, once: no canvas laid out yet or PaperKit refusing the
    // move is refused as `not_applied`; an answer for a batch no longer being applied changes nothing.
    let outcome = canvas?.apply(batch) ?? .unavailable
    let result: BoardOps.Result
    let plan: BoardOps.Plan
    switch (ops.report(batch, outcome), outcome) {
    case (.applied(let applied), .applied(let planned)):
      (result, plan) = (applied, planned)
    case (.refused(let refused, let canvas), _):
      event["action"] = "refused"
      event["reason"] = refused.reason ?? ""
      event["canvas"] = canvas
      log.event("board_ops", event)
      showBlocked(batch.label, refused.reason ?? "")
      return
    case (.late, _), (.applied, _):
      event["action"] = "late"
      log.event("board_ops", event)
      return
    }
    if blocked.applied() { log.event("board_blocked", ["action": "cleared", "board": board.id, "why": "applied"]) }
    if !plan.overlays.isEmpty {
      overlays.apply(plan.overlays)
      canvas?.showOverlays(overlays.list)
    }
    if !plan.metas.isEmpty || !plan.forgetMetas.isEmpty {
      plan.forgetMetas.forEach { strokeMeta.remove($0) }
      strokeMeta.merge(plan.metas)
      opLedger.setStrokeMeta(strokeMeta, board: board.id)
    }
    // #939: his change reached ghosts of his text by name: the ones it took away go, the ones it moved show anew.
    if !plan.dismissed.isEmpty { turns.larrysTextGone(Set(plan.dismissed.map { "op-text:\($0)" })) }
    if !plan.texts.isEmpty {
      logNewTextMarkActions(batch, texts: plan.texts)
      turns.larrysMarks(
        plan.texts.map {
          Ghost(
            $0.shape, who: .larry, frame: .zero, scale: 1, id: "op-text:\($0.id)", text: $0, hand: penInHand,
            lettering: lettering)
        })
    }
    if let from = batch.rebasedFrom { event["rebased_from"] = from }
    // Story 1195: each make-room as asked and as made, "asked_y+asked_dy>y+dy".
    if !plan.rooms.isEmpty {
      event["room"] = plan.rooms.map { "\(Int($0.askedY))+\(Int($0.askedDy))>\(Int($0.y))+\(Int($0.dy))" }
        .joined(separator: ",")
    }
    var moves = plan.offsets.values.map(\.dy)
    moves.sort()
    let hiding = plan.hidden.values.filter { $0 }.count
    let moving: [String: Any] = [
      "action": "applied", "rev": result.rev, "moved": plan.moved, "strokes_moved": plan.offsets.count,
      "dy_min": Double(moves.first ?? 0), "dy_max": Double(moves.last ?? 0),
      "pages_before": plan.pagesBefore, "pages": plan.pagesAfter,
    ]
    let editing: [String: Any] = [
      "erased": plan.erase.count, "drawn": plan.added.count, "metas": plan.metas.count, "hidden": hiding,
      "shown": plan.hidden.count - hiding, "selected": plan.select.count, "overlays": overlays.list.count,
      "texts": plan.texts.count, "inked": plan.inked.count, "dismissed": plan.dismissed.count,
      "missing_ids": plan.missingIDs.count,
      "changed": plan.changesBoard,
      "ms": Int(started.duration(to: .now) / .milliseconds(1)),
    ]
    event.merge(moving) { $1 }
    event.merge(editing) { $1 }
    log.event("board_ops", event)
  }

  /// Story 843: elements came or changed (`updated`, their hashes now) or went. `report`: Igor did it, so Larry hears
  /// it; else the board only takes it in. `reworded`: the kept texts this change rewords (story 942).
  func inkElements(updated: [String: [String]], removed: [String], report: Bool, reworded: [String]? = nil) {
    let before = strokeIDs
    let change = ink.changed(updated: updated, removed: removed, ids: &strokeIDs)
    if strokeIDs != before {
      opLedger.setStrokeIDs(strokeIDs, board: board.id)
      marksFollow()
    }
    guard report, !change.isEmpty else { return }
    let changed = change.moved + change.erased
    let owners =
      changed.isEmpty
      ? []
      : BoardOps.owners(
        of: changed, live: opStrokes(drawing.strokes).strokes, groups: strokeMeta.groups, texts: texts)
    let dissolved = dissolve(erased: change.erased)
    // Story 961: what a batch from an older look must not name.
    ops.touched(changed + dissolved + owners + (reworded ?? []))
    let event = BoardEvent.strokesChanged(
      added: change.added, erased: change.erased, moved: change.moved, rev: ops.rev, t: Self.nowMs,
      dissolved: dissolved.isEmpty ? nil : dissolved, reworded: reworded)
    events.record(event)
    takeOps(.event(event))
  }

  /// Story 854: a group or kept text Igor erased part of is plain ink from now on. The ids that dissolved.
  private func dissolve(erased: [String]) -> [String] {
    guard !erased.isEmpty, !strokeMeta.isEmpty || !texts.isEmpty else { return [] }
    var metas = strokeMeta
    var kept = texts
    let gone = BoardDissolve.dissolve(
      erased: erased, live: opStrokes(drawing.strokes).strokes, metas: &metas, texts: &kept)
    guard !gone.isEmpty else { return [] }
    if metas != strokeMeta {
      strokeMeta = metas
      opLedger.setStrokeMeta(metas, board: board.id)
    }
    if kept != texts {
      texts = kept
      opLedger.setTexts(kept, board: board.id)
    }
    log.event("board_ops", ["action": "dissolved", "board": board.id, "ids": gone, "erased": erased.count])
    return gone
  }

  /// The strokes as a plan of the board sees them, by the names Larry knows them (one moved before keeps its first
  /// name), with each one's hashes now. Ink with no colour to see is hidden.
  func opStrokes(_ ink: [PKStroke]) -> (strokes: [BoardOps.Stroke], hashes: [[String]]) {
    // #1527: each stroke sampled once, not on every stroke of the board.
    let sent = ink.map { strokeCache.stretches(of: $0) { Self.strokesForLarry(PKDrawing(strokes: [$0])) } }
    strokeCache.trim(to: ink)
    let hashes = sent.map { $0.map(\.id) }
    let strokes = zip(ink, sent).map { stroke, stretches in
      BoardOps.Stroke(
        ids: stretches.map { strokeIDs.stable($0.id) },
        t: BoardMoment.of(stroke), bounds: stroke.renderBounds,
        hidden: stroke.ink.color.cgColor.alpha == 0, points: stretches.flatMap(\.points),
        pen: CGFloat(stretches.first?.width ?? 0))
    }
    return (strokes, hashes)
  }

  /// The ink as it is, Larry told nothing: on opening, and after a change of his own.
  func inkReset(_ hashes: [String: [String]]) { ink.reset(hashes) }

  /// Story 848: the element keys of the strokes Larry names.
  func elementKeys(named names: [String]) -> Set<String> {
    let wanted = Set(names)
    return Set(ink.hashes.filter { $0.value.contains { wanted.contains(strokeIDs.stable($0)) } }.keys)
  }

  /// Story 844: the lasso's selection, by element key; Larry hears it by name when it changes.
  func selectionChanged(_ keys: Set<String>) {
    guard keys != selection else { return }
    selection = keys
    let names = keys.sorted().flatMap { ink.hashes[$0] ?? [] }.map(strokeIDs.stable)
    let event = BoardEvent.selection(ids: names, t: Self.nowMs)
    events.record(event)
    takeOps(.event(event))
  }

  // Stories 920–922 (BoardToTextFlow.swift): what To text needs of the board.
  var cockpitURL: String { cockpit }
  var sessionLog: SessionLog { log }
  func show(problem new: BugProblem?) { problem = new }
  func say(_ note: String) { pasteNote = note }
  /// #939: Larry's text ghosts showing, which his changes reach by name.
  var textGhosts: [BoardOps.Text] { turns.ghosts.compactMap(\.text) }

  func keep(text: BoardText) {
    texts.append(text)
    opLedger.setTexts(texts, board: board.id)
  }

  /// #937 (story 991): the texts a batch of Larry's inks at once (one he put notes on), lettered as Keep letters a text
  /// of his, each a kept text under his id. The canvas adds the strokes in the batch's one undo, then keeps the texts.
  /// Each gets a moment of its own before now, as Keep all gives them, so each is known as one text and no stroke the
  /// batch draws after shares one.
  func letter(_ inked: [BoardOps.Text]) -> (strokes: [PKStroke], texts: [BoardText]) {
    let started = Date()
    var strokes: [PKStroke] = []
    var kept: [BoardText] = []
    for (i, text) in inked.enumerated() {
      let ghost = Ghost(
        text.shape, who: .larry, frame: .zero, scale: 1, id: "op-text:\(text.id)", text: text, hand: penInHand,
        lettering: lettering)
      let made = BoardText.time(started.addingTimeInterval(-Double(inked.count - i) * 0.005))
      let glyphs = Self.strokes(ghost.lines, color: ghost.color, width: ghost.width, spacing: 4, made: made.date)
      kept.append(
        BoardText(
          id: text.id, t: made.t, text: text.text, font: text.font, size: Double(text.size),
          color: Self.lightHex(ghost.color), glyphs: glyphs.count, lettering: ghost.text?.lettering))
      strokes += glyphs
    }
    return (strokes, kept)
  }

  /// The texts `letter` made, once their strokes are on the board.
  func keep(lettered: [BoardText]) {
    guard !lettered.isEmpty else { return }
    rememberTheirs(moments: lettered.map(\.t))
    for text in lettered {
      rememberLabel(Date(timeIntervalSince1970: Double(text.t) / 1000))
      texts.removeAll { $0.id == text.id }
      texts.append(text)
    }
    opLedger.setTexts(texts, board: board.id)
  }

  /// Stories 910–916: what a plan put on the canvas besides its ink, whoever made it: its notes (a connector's route, a
  /// word grouped as one end, a connector turned plain ink) and the names of the strokes it drew.
  func planPut(_ plan: BoardOps.Plan, drawn: [(hash: [String], name: String)]) {
    guard editable else { return }
    if !plan.metas.isEmpty || !plan.forgetMetas.isEmpty {
      plan.forgetMetas.forEach { strokeMeta.remove($0) }
      strokeMeta.merge(plan.metas)
      opLedger.setStrokeMeta(strokeMeta, board: board.id)
    }
    guard !drawn.isEmpty else { return }
    for stroke in drawn { stroke.hash.forEach { strokeIDs.name($0, as: stroke.name) } }
    opLedger.setStrokeIDs(strokeIDs, board: board.id)
  }

  /// The canvas applied a plan (a batch of Larry's, a fold, connectors following their ends): saved and a new revision
  /// like any change, and no stroke for Claude to answer. Its names aren't recorded one by one, so it counts as touching
  /// everything: no batch from an earlier look applies over it (stories 961, 1220).
  /// `renamed`: for each moved stroke, the hashes of its stretches before and after, so it keeps its names.
  /// `drawn`: each stroke Larry drew, its hashes and his name for it.
  func opsApplied(
    _ new: PKDrawing, renamed: [(from: [String], to: [String])], drawn: [(hash: [String], name: String)] = []
  ) {
    guard editable else { return }
    for pair in renamed { strokeIDs.moved(from: pair.from, to: pair.to) }
    for stroke in drawn { stroke.hash.forEach { strokeIDs.name($0, as: stroke.name) } }
    if !renamed.isEmpty || !drawn.isEmpty { opLedger.setStrokeIDs(strokeIDs, board: board.id) }
    drawing = new
    drawingMoved()
    ops.touched([], all: true)
  }
}
