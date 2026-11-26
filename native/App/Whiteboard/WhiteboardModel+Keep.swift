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
  /// What Keep and Dismiss take: the chosen mark, or its whole reply of Larry's when that shows several (story 1285).
  var chosenMarks: [Ghost] { turns.chosenMarks }

  /// Story 1285 (#1383): each reply of Larry's showing two or more marks, with the box its outline goes round, in board
  /// points: all its marks, a pen's half-width and a little more out.
  var groupOutlines: [(reply: String, box: CGRect)] {
    turns.groupedReplies.compactMap { group in
      let box = WhiteboardMarkChoice.bounds(group.marks.flatMap(\.lines))
      guard !box.isNull else { return nil }
      let pad = (group.marks.map(\.width).max() ?? 0) / 2 + 6
      return (group.reply, box.insetBy(dx: -pad, dy: -pad))
    }
  }

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
          "within": within, "marks": turns.chosenMarks.count,
        ])
    case .putAway:
      log.event("whiteboard", ["action": "mark_choice", "board": board.id, "choice": "away", "why": "tap_off"])
    }
  }

  /// Whether a tap at `point` (board points) reaches any mark showing (story 967).
  func reachesMark(at point: CGPoint, zoom: CGFloat) -> Bool {
    let reach = markReach(at: point, zoom: zoom)
    return turns.ghosts.contains { reach($0) != nil }
  }

  /// How far a tap at `point` is from a mark, or nil out of a finger's reach.
  private func markReach(at point: CGPoint, zoom: CGFloat) -> (Ghost) -> CGFloat? {
    let hidden = turns.hiddenMarks
    return { ghost in
      // Story 1181: a mark folded away or with its ink erased takes no tap.
      hidden.contains(ghost.id)
        ? nil
        : WhiteboardTurn.reach(ghost.lines, kind: ghost.kind, at: point, tolerance: WhiteboardTurn.tapReach / zoom)
    }
  }

  // MARK: Keep all and Tidy overlaps (stories 895, 896, 995, 999)

  /// Larry's marks showing, for Keep all in the note's line.
  var larrysMarks: Int { turns.ghosts.filter { $0.who == .larry }.count }

  /// Keep all (stories 895, 995, 999; bead context-grabber-yqau, which made Keep group and Keep all one button): every
  /// mark of Larry's showing becomes ink where it showed, each reply of his one group named for it (#942) that Larry
  /// moves or erases by that one name, a lone mark or his text from a change kept as one thing on its own. What Igor wrote
  /// after a reply's picture, under that reply's marks, makes room in the same step (#894). One keep, so one undo.
  func keepLarrysMarks() {
    guard editable else { return }
    let marks = turns.keepAll(.larry)
    guard !marks.isEmpty else { return }
    keepAsReplies(marks, why: "keep_all", undoName: Self.keepAllUndoName)
  }

  /// `marks` of Larry's kept as Keep all keeps them: each reply one group, one room, one undo named `undoName` (Keep all's,
  /// or story 1154's Keep beside a mark of a reply). `why` names the keep in the log and the room.
  private func keepAsReplies(_ marks: [Ghost], why: String, undoName: String) {
    let groups = WhiteboardMarks.keptGroups(marks.map(\.id))
    // Stories 1349–1351 (#1528): a reply's boxes keep as one thing each, its arrows between boxes as connectors.
    let diagram = diagramPlan(marks)
    var diagramNames: [String: [String]] = [:]
    let started = Date()
    var strokes: [PKStroke] = []
    var repliesByStroke: [String: String] = [:]
    for (i, ghost) in marks.enumerated() {
      // A moment of its own for each, a few milliseconds apart, so each is known as one thing (and story 817's text).
      let made = BoardText.time(started.addingTimeInterval(Double(i) * 0.005))
      let mine =
        connectorInk(ghost)
        ?? diagramArrowInk(ghost, plan: diagram, made: made.date)
        ?? Self.strokes(ghost.lines, color: ghost.color, width: ghost.width, spacing: 4, made: made.date)
      strokes += mine
      if diagram.boxOf[ghost.id] != nil || diagram.connectors[ghost.id] != nil {
        diagramNames[ghost.id] = opStrokes(mine).strokes.flatMap(\.ids)
      } else if let reply = groups[ghost.id] {
        // Named as Larry will hear them, before the canvas has them (`paper_keep` says the names survive it).
        for name in opStrokes(mine).strokes.flatMap(\.ids) where repliesByStroke[name] == nil {
          repliesByStroke[name] = reply
        }
      } else if ghost.kind == .text {
        // Not in a group: a label Tidy overlaps may lay out again. Tidy leaves a group as it is.
        rememberLabel(made.date)
      }
      if let text = ghost.text {
        texts.append(
          BoardText(
            id: text.id, t: made.t, text: text.text, font: text.font, size: Double(text.size),
            color: Self.lightHex(ghost.color), glyphs: mine.count, lettering: text.lettering))
      }
      settleLarrys(ghost)
    }
    // #894 (story 1004): before the groups' notes, so the board it measures is the one he wrote on.
    let late = lateRoom(marks)
    rememberTheirs(strokes)
    let boxed = noteDiagram(diagram, names: diagramNames)
    if !repliesByStroke.isEmpty || !boxed.isEmpty {
      for (name, reply) in repliesByStroke where !boxed.contains(name) {
        if let note = WhiteboardMarks.groupNote(reply: reply, over: strokeMeta[name]) {
          strokeMeta.set(note, for: name)
        }
      }
      opLedger.setStrokeMeta(strokeMeta, board: board.id)
    }
    if marks.contains(where: { $0.text != nil }) { opLedger.setTexts(texts, board: board.id) }
    var event: [String: Any] = [
      "action": why, "board": board.id, "marks": marks.count, "strokes": strokes.count,
      "groups": Set(groups.values).sorted().map(WhiteboardMarks.group(reply:)),
    ]
    event.merge(Self.lateFields(late, marks)) { $1 }
    log.event("whiteboard", event)
    if let push = late?.push, canvas?.keepMakingRoom(strokes, push: push, why: why) == true { return }
    add(strokes, named: undoName)
  }

  /// Story 896: kept labels and pastes that sit on other ink laid out again, top to bottom; his ink stays. One undo.
  func tidyOverlaps() {
    guard editable else { return }
    // Bead context-grabber-cg3: a label in one of Larry's groups stays with its group, as ink.
    let all = drawing.strokes
    let laid = WhiteboardTidy.laid(
      opStrokes(all).strokes, known: opLedger.labels(board: board.id), texts: texts, groups: strokeMeta.groups,
      folded: Set(all.indices.filter { all[$0].isFolded }))
    let members = laid.labels
    let labels = members.mapValues { $0.map { Self.points(all[$0]) } }
    let moves = WhiteboardTidy.tidy(labels, among: laid.ink.map { Self.points(all[$0]) })
    log.event(
      "whiteboard",
      [
        "action": "tidy", "board": board.id, "labels": labels.count, "moved": moves.count, "grouped": laid.grouped,
      ])
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
    opLedger.rememberLabels([BoardMoment.ms(made)], board: board.id)
  }

  /// #894: the moments of ink Larry or Claude made (a mark kept, Larry's ink or text), kept in the board's meaning, so it
  /// never makes room as Igor's (bead context-grabber-p1pl).
  func rememberTheirs(_ strokes: [PKStroke]) { rememberTheirs(moments: strokes.map(BoardMoment.of)) }

  func rememberTheirs(moments: [Int64]) {
    opLedger.rememberTheirs(moments, board: board.id)
  }

  private static func points(_ stroke: PKStroke) -> [CGPoint] {
    stroke.path.interpolatedPoints(by: .distance(4)).map { $0.location.applying(stroke.transform) }
  }

  /// Keep beside the chosen mark, one undo. A mark of Larry's keeps its whole reply still showing as one group, as Keep
  /// all keeps it (story 1154; bead context-grabber-it0e); a lone mark, his text from a change and Claude's keep alone.
  @discardableResult func keepChosen() -> CGFloat? {
    guard let kept = turns.keepChosenReply(), let first = kept.first else { return nil }
    log.event(
      "whiteboard",
      [
        "action": "mark_choice", "board": board.id, "choice": "keep", "who": first.who.rawValue, "marks": kept.count,
      ])
    guard kept.count > 1 else {
      settleLarrys(first)
      return ink(first)
    }
    keepAsReplies(kept, why: "keep_reply", undoName: Self.keepUndoName)
    return kept.flatMap(\.lines).flatMap { $0 }.map(\.y).max()
  }

  /// Story 1000: where the corner's buttons are, in window points.
  func cornerLaid(_ frame: CGRect) {
    if frame != cornerFrame { cornerFrame = frame }
  }

  /// Dismiss beside the chosen mark: it goes, with every other mark of its reply showing (story 1286, #1383), and none
  /// comes back when the board opens again.
  func dismissChosen() {
    guard let gone = turns.dismissChosen(), let first = gone.first else { return }
    log.event(
      "whiteboard",
      [
        "action": "mark_choice", "board": board.id, "choice": "dismiss", "who": first.who.rawValue,
        "kind": first.kind.rawValue, "marks": gone.count, "left": turns.ghosts.count,
      ])
    for ghost in gone { settleLarrys(ghost) }
  }

  /// The ghost as ink in its colour. Its point spacing is what makes PencilKit's spline follow the shape.
  private func ink(_ ghost: Ghost) -> CGFloat? {
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
    let bottom = lines.flatMap { $0 }.map(\.y).max()
    if let push = room.push, canvas?.keepMakingRoom(strokes, push: push, why: "keep_text") == true { return bottom }
    if let push = late?.push, canvas?.keepMakingRoom(strokes, push: push, why: "keep_late") == true { return bottom }
    add(strokes, named: Self.keepUndoName)
    return bottom
  }

  /// #894 (stories 1004–1006): the room Larry's marks need when kept, for what Igor made after the picture they answer;
  /// nil when that picture's time isn't known on this device. His marks stay where they showed.
  /// Keep all's text from a change (#938) makes room in the same one room.
  private func lateRoom(_ marks: [Ghost]) -> BoardRoom.Late? {
    guard marks.contains(where: { $0.seen != nil || $0.text != nil }) else { return nil }
    // Keep all: each mark against its own reply's picture, one room for all of them.
    let replies = marks.filter { $0.text == nil }.map { mark in
      (box: WhiteboardMarkChoice.bounds(mark.lines).insetBy(dx: -mark.width / 2, dy: -mark.width / 2), seen: mark.seen)
    }
    let landing = marks.filter { $0.text != nil }.map { WhiteboardMarkChoice.bounds($0.lines) }
    let strokes = opStrokes(drawing.strokes).strokes
    let theirs = opLedger.theirs(board: board.id)
    return BoardRoom.late(
      replies, landing: landing, strokes: strokes, texts: texts, groups: strokeMeta.groups,
      folds: outline(of: strokes).tags, theirs: theirs)
  }

  /// The keep's log fields for #894: the picture's time (or that it isn't known), each reply's when Keep all kept
  /// replies to more than one, what newer it sat on, the room.
  private static func lateFields(_ late: BoardRoom.Late?, _ marks: [Ghost]) -> [String: Any] {
    let seen = Set(marks.compactMap(\.seen)).sorted()
    var out: [String: Any] = ["picture_t": seen.first.map { $0 as Any } ?? NSNull()]
    if seen.count > 1 { out["picture_ts"] = seen }
    guard let late else { return out }
    out["covered_newer"] = late.covered
    if let push = late.push {
      out["late_cut"] = Double(push.cut)
      out["late_dy"] = Double(push.dy)
    }
    return out
  }

  static func unixMs(_ date: Date = Date()) -> Int64 { BoardMoment.ms(date) }

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
