//  Keep, Tidy overlaps and choosing: ghosts becoming ink, and the room they make (stories 895, 896).
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// The mark whose Keep and Dismiss show (story 825).
  var chosen: Ghost? { turns.chosen }

  /// A tap at `point` (board points) on a mark shows its Keep and Dismiss; anywhere else only puts them away (stories
  /// 825, 810, #883): a stray tap never keeps or dismisses a mark.
  func tap(at point: CGPoint, zoom: CGFloat) {
    // #941: the nearest mark takes the tap, a label anywhere on its words, so a box drawn first never steals its name's.
    let reach = markReach(at: point, zoom: zoom)
    let within = turns.ghosts.filter { reach($0) != nil }.count
    switch turns.tapNearest(reach: reach) {
    case .nothing: return
    case .chose(let ghost):
      log.event(
        "whiteboard",
        [
          "action": "mark_chosen", "board": board.id, "who": ghost.who.rawValue, "kind": ghost.kind.rawValue,
          "within": within,
        ])
    case .putAway:
      log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "away", "why": "tap_off"])
    }
  }

  /// Whether a tap at `point` (board points) reaches any mark showing (story 966).
  func reachesMark(at point: CGPoint, zoom: CGFloat) -> Bool {
    let reach = markReach(at: point, zoom: zoom)
    return turns.ghosts.contains { reach($0) != nil }
  }

  /// How far a tap at `point` is from a mark, or nil out of a finger's reach.
  private func markReach(at point: CGPoint, zoom: CGFloat) -> (Ghost) -> CGFloat? {
    { ghost in
      WhiteboardTurn.reach(ghost.lines, kind: ghost.kind, at: point, tolerance: WhiteboardTurn.tapReach / zoom)
    }
  }

  // MARK: Keep all and Tidy overlaps (stories 895, 896)

  /// Larry's marks showing, for Keep all in the note's line.
  var larrysMarks: Int { turns.ghosts.filter { $0.who == .larry }.count }

  /// Story 895: every mark of Larry's kept at once, top to bottom, a label on ink moved under it and the marks after it
  /// with it. One keep, so one undo.
  func keepLarrysMarks() {
    let marks = turns.keepAll(.larry)
    guard editable, !marks.isEmpty else { return }
    let moves = WhiteboardTidy.keepAll(
      marks.map { .init(id: $0.id, lines: $0.lines, label: $0.kind == .text) }, over: Self.inkPoints(drawing))
    let started = Date()
    var strokes: [PKStroke] = []
    for (i, ghost) in marks.enumerated() {
      let dy = moves[ghost.id] ?? 0
      // A moment of its own for each, a few milliseconds apart, so each label is known as one (and story 817's text).
      let made = BoardText.time(started.addingTimeInterval(Double(i) * 0.005))
      let lines = ghost.lines.map { line in line.map { CGPoint(x: $0.x, y: $0.y + dy) } }
      let mine =
        connectorInk(ghost) ?? Self.strokes(lines, color: ghost.color, width: ghost.width, spacing: 4, made: made.date)
      strokes += mine
      if ghost.kind == .text { rememberLabel(made.date) }
      if let text = ghost.text {
        texts.append(
          BoardText(
            id: text.id, t: made.t, text: text.text, font: text.font, size: Double(text.size),
            color: Self.lightHex(ghost.color), glyphs: mine.count, lettering: text.lettering))
      }
      settleLarrys(ghost)
    }
    rememberTheirs(strokes)
    if marks.contains(where: { $0.text != nil }) { opLedger.setTexts(texts, board: board.id) }
    log.event(
      "whiteboard",
      [
        "action": "keep_all", "board": board.id, "marks": marks.count, "strokes": strokes.count,
        "moved": moves.values.filter { $0 > 0 }.count,
      ])
    add(strokes, named: Self.keepAllUndoName)
  }

  /// Story 896: kept labels and pastes that sit on other ink laid out again, top to bottom; his ink stays. One undo.
  func tidyOverlaps() {
    guard editable else { return }
    let known = opLedger.labels(board: board.id)
    var labels: [String: [[CGPoint]]] = [:]
    var members: [String: [Int]] = [:]
    var ink: [[CGPoint]] = []
    for (i, stroke) in drawing.strokes.enumerated() where !stroke.isFolded {
      let points = Self.points(stroke)
      let made = Self.moment(stroke)
      if known.contains(made) {
        labels["\(made)", default: []].append(points)
        members["\(made)", default: []].append(i)
      } else {
        ink.append(points)
      }
    }
    let moves = WhiteboardTidy.tidy(labels, among: ink)
    log.event("whiteboard", ["action": "tidy", "board": board.id, "labels": labels.count, "moved": moves.count])
    guard !moves.isEmpty else {
      pasteNote = "Nothing overlaps"
      return
    }
    var strokes: [Int: CGFloat] = [:]
    for (label, dy) in moves { for i in members[label] ?? [] { strokes[i] = dy } }
    _ = canvas?.moveStrokes(strokes)
  }

  /// A label's moment, kept in the board's meaning and saved with its ink (bead context-grabber-p1pl).
  func rememberLabel(_ made: Date) {
    opLedger.rememberLabels([Int64(made.timeIntervalSince1970 * 1000)], board: board.id)
  }

  /// #894: the moments of ink Larry or Claude made (a mark kept, Larry's ink or text), kept in the board's meaning, so it
  /// never makes room as Igor's (bead context-grabber-p1pl).
  func rememberTheirs(_ strokes: [PKStroke]) { rememberTheirs(moments: strokes.map(Self.moment)) }

  func rememberTheirs(moments: [Int64]) {
    opLedger.rememberTheirs(moments, board: board.id)
  }

  private static func moment(_ stroke: PKStroke) -> Int64 {
    Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
  }

  private static func points(_ stroke: PKStroke) -> [CGPoint] {
    stroke.path.interpolatedPoints(by: .distance(4)).map { $0.location.applying(stroke.transform) }
  }

  private static func inkPoints(_ drawing: PKDrawing) -> [[CGPoint]] {
    drawing.strokes.filter { !$0.isFolded }.map(points)
  }

  /// Keep beside the chosen mark: the old tap's keep, one undo.
  func keepChosen() {
    guard let kept = turns.keepChosen() else { return }
    log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "keep", "who": kept.who.rawValue])
    settleLarrys(kept)
    ink(kept)
  }

  /// Story 999: how many of the chosen mark's reply still show; Keep group is offered from two.
  var chosenReplyCount: Int { turns.chosenReply().count }

  /// Keep group (#942, story 995): every mark of the chosen one's reply still showing, ink where it showed, in one keep
  /// (one undo), its strokes one group named for the reply, which Larry moves or erases by that one name.
  func keepChosenReply() {
    guard editable, let reply = turns.chosen.flatMap({ WhiteboardMarks.reply(of: $0.id) }) else { return }
    let marks = turns.keepChosenReply()
    guard !marks.isEmpty else { return }
    let started = Date()
    var strokes: [PKStroke] = []
    for (i, ghost) in marks.enumerated() {
      // A moment of its own for each, a few milliseconds apart, as Keep all gives them. Not remembered as a label: Tidy
      // overlaps leaves a group as it is.
      let made = started.addingTimeInterval(Double(i) * 0.005)
      strokes +=
        connectorInk(ghost) ?? Self.strokes(ghost.lines, color: ghost.color, width: ghost.width, spacing: 4, made: made)
      settleLarrys(ghost)
    }
    // Named as Larry will hear them, before the canvas has them (`paper_keep` says the names survive it).
    let names = opStrokes(strokes).strokes.flatMap(\.ids)
    // #894 (story 1004): before the group's notes, so the board it measures is the one he wrote on.
    let late = lateRoom(marks)
    rememberTheirs(strokes)
    strokeMeta.merge(WhiteboardMarks.groupNotes(names, reply: reply))
    opLedger.setStrokeMeta(strokeMeta, board: board.id)
    var event: [String: Any] = [
      "action": "keep_group", "board": board.id, "marks": marks.count, "strokes": strokes.count,
      "group": WhiteboardMarks.group(reply: reply),
    ]
    event.merge(Self.lateFields(late, marks)) { $1 }
    log.event("whiteboard", event)
    if let push = late?.push, canvas?.keepMakingRoom(strokes, push: push, why: "keep_group") == true { return }
    add(strokes, named: Self.keepGroupUndoName)
  }

  /// Story 1000: where the corner's buttons are, in window points.
  func cornerLaid(_ frame: CGRect) {
    if frame != cornerFrame { cornerFrame = frame }
  }

  /// Dismiss beside the chosen mark: that mark goes, and doesn't come back when the board opens again.
  func dismissChosen() {
    guard let gone = turns.dismissChosen() else { return }
    log.event(
      "whiteboard",
      [
        "action": "mark_choice", "board": board.id, "choice": "dismiss", "who": gone.who.rawValue,
        "kind": gone.kind.rawValue, "left": turns.ghosts.count,
      ])
    settleLarrys(gone)
  }

  /// The ghost as ink in its colour. Its point spacing is what makes PencilKit's spline follow the shape.
  private func ink(_ ghost: Ghost) {
    // Story 817: a text of Larry's is one thing on the board, known by its glyphs' one creation time.
    let made = BoardText.time(Date())
    // #938: a text of his that Igor's ink has come under makes room as it lands. #894: a mark of his on ink written
    // after his picture makes room for itself.
    let room = textRoom(ghost)
    let late = ghost.text == nil ? lateRoom([ghost]) : nil
    let lines = ghost.lines.map { line in line.map { CGPoint(x: $0.x, y: $0.y + room.dy) } }
    let strokes =
      connectorInk(ghost)
      ?? Self.strokes(lines, color: ghost.color, width: ghost.width, spacing: 4, made: made.date)
    if ghost.kind == .text { rememberLabel(made.date) }
    rememberTheirs(strokes)
    if let text = ghost.text {
      texts.append(
        BoardText(
          id: text.id, t: made.t, text: text.text, font: text.font, size: Double(text.size),
          color: Self.lightHex(ghost.color), glyphs: strokes.count, lettering: text.lettering))
      opLedger.setTexts(texts, board: board.id)
    }
    // #883: what a kept mark that doesn't show needs said: its pen, letters and colour, the zoom, and whether the ink
    // landed on screen. `paper_keep` and `paper_ink_look` follow with where it went and whether the view drew it.
    let ink = PKDrawing(strokes: strokes).bounds
    var event: [String: Any] = [
      "action": "keep", "board": board.id, "who": ghost.who.rawValue, "strokes": strokes.count,
      "kind": ghost.kind.rawValue, "width": Double(ghost.width),
      "color": Self.lightHex(ghost.color), "zoom": Double(canvas?.zoom ?? 1),
    ]
    if let hand = penInHand { event["pen_in_hand"] = Double(hand) }
    if let letters = ghost.letters { event["letters"] = Double(letters) }
    if let text = ghost.text { event["text_id"] = text.id }
    if let visible = canvas?.visibleRect, !visible.isNull, !ink.isNull { event["in_view"] = visible.intersects(ink) }
    if let push = room.push {
      event["room_cut"] = Double(push.cut)
      event["room_dy"] = Double(push.dy)
    }
    if room.dy != 0 { event["landed_dy"] = Double(room.dy) }
    if ghost.text == nil { event.merge(Self.lateFields(late, [ghost])) { $1 } }
    log.event("whiteboard", event)
    if let push = room.push, canvas?.keepMakingRoom(strokes, push: push, why: "keep_text") == true { return }
    if let push = late?.push, canvas?.keepMakingRoom(strokes, push: push, why: "keep_late") == true { return }
    add(strokes, named: Self.keepUndoName)
  }

  /// #894 (stories 1004–1006): the room Larry's marks need when kept, for what Igor made after the picture they answer;
  /// nil when that picture's time isn't known on this device. His marks stay where they showed.
  private func lateRoom(_ marks: [Ghost]) -> BoardRoom.Late? {
    guard let seen = marks.compactMap(\.seen).min() else { return nil }
    let boxes = marks.map { WhiteboardMarkChoice.bounds($0.lines).insetBy(dx: -$0.width / 2, dy: -$0.width / 2) }
    let strokes = opStrokes(drawing.strokes).strokes
    let theirs = opLedger.theirs(board: board.id)
    return BoardRoom.late(
      boxes, seen: seen, strokes: strokes, texts: texts, groups: strokeMeta.groups, folds: outline(of: strokes).tags,
      theirs: theirs)
  }

  /// The keep's log fields for #894: the picture's time (or that it isn't known), what newer it sat on, the room.
  private static func lateFields(_ late: BoardRoom.Late?, _ marks: [Ghost]) -> [String: Any] {
    guard let late, let seen = marks.compactMap(\.seen).min() else { return ["picture_t": NSNull()] }
    var out: [String: Any] = ["picture_t": seen, "covered_newer": late.covered]
    if let push = late.push {
      out["late_cut"] = Double(push.cut)
      out["late_dy"] = Double(push.dy)
    }
    return out
  }

  static func unixMs(_ date: Date = Date()) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

  /// #938 (story 992): where a ghost of Larry's text lands when kept, as his text lands from a batch: clear of the ink,
  /// with the room it opens. `dy` is how far the text itself goes down to sit under a line its top fell in.
  private func textRoom(_ ghost: Ghost) -> (dy: CGFloat, push: BoardRoom.Push?) {
    guard ghost.text != nil else { return (0, nil) }
    let box = WhiteboardMarkChoice.bounds(ghost.lines)
    guard !box.isNull else { return (0, nil) }
    let strokes = opStrokes(drawing.strokes).strokes
    let boxes = BoardOps.shownBoxes(
      strokes: strokes, texts: texts, groups: strokeMeta.groups, folds: outline(of: strokes).tags)
    let room = BoardRoom.text(box, among: boxes.filter { !$0.contains(box) })
    return (room.y - box.minY, room.push)
  }
}
