//  Larry's unkept marks hold to the ink they answer and fade when written over (spec
//  2026-11-01-whiteboard-shapes-design.md, *His marks hold to the ink they answer, and fade when written over*; stories
//  1180, 1181, 1269–1271; bead context-grabber-p2an). The rule is `BoardMarkHolds` in ContextCore; here the board
//  chooses each mark's anchor as it lands, moves and hides the marks as the ink changes, fades the ones Igor writes over,
//  and takes the faded ones away when a picture reaches Larry.

import ContextCore
import PencilKit
import SwiftUI

/// Each mark's anchor, where it landed, and where it shows now.
struct MarkHoldsState: Equatable {
  var anchors: [String: BoardMarkAnchor] = [:]
  /// Each mark's lines where it landed, board points: its place is worked out from these.
  var landed: [String: [[CGPoint]]] = [:]
  var places: [String: BoardMarkHolds.Place] = [:]

  func faded(_ id: String) -> Bool { places[id]?.faded ?? false }
  func hidden(_ id: String) -> Bool { places[id]?.hidden != nil }
}

extension Ghost {
  /// Moved by `dx`, `dy`: its lines, and a connector's ends that are points.
  mutating func move(dx: CGFloat, dy: CGFloat) {
    lines = lines.map { $0.map { CGPoint(x: $0.x + dx, y: $0.y + dy) } }
    guard var mark = connector else { return }
    let shift = { (end: BoardOps.NewConnector.End) -> BoardOps.NewConnector.End in
      if case .point(let p) = end { return .point(CGPoint(x: p.x + dx, y: p.y + dy)) }
      return end
    }
    mark.from = shift(mark.from)
    mark.to = shift(mark.to)
    connector = mark
  }
}

extension WhiteboardModel {
  /// The board's ink as the rule reads it, by the names Larry knows.
  private func marksInk() -> BoardMarkHolds.Ink {
    let strokes = opStrokes(drawing.strokes).strokes
    return BoardMarkHolds.Ink(
      strokes: strokes, texts: texts, groups: strokeMeta.groups, folds: outline(of: strokes).tags)
  }

  private func boardMark(_ ghost: Ghost, lines: [[CGPoint]]) -> BoardMark {
    BoardMark(id: ghost.id, lines: lines, pen: ghost.width, label: ghost.kind == .text || ghost.text != nil)
  }

  /// The ink or the marks changed: a new mark takes its anchor, and every mark goes where its anchor is now.
  /// `laps` names this one's steps inside its caller's (#1527).
  func marksFollow(laps: StepLaps? = nil) {
    guard editable, !turns.ghosts.isEmpty || !markHolds.places.isEmpty else { return }
    var state = markHolds
    let live = Set(turns.ghosts.map(\.id))
    // A mark gone (kept, dismissed, dropped) forgets its anchor; one not shown yet this session keeps its saved one.
    for id in state.landed.keys where !live.contains(id) {
      state.anchors[id] = nil
      state.landed[id] = nil
      state.places[id] = nil
    }
    laps?.lap("follow")
    let ink = marksInk()
    laps?.lap("follow_ink")
    for ghost in turns.ghosts where state.landed[ghost.id] == nil {
      state.landed[ghost.id] = ghost.lines
      guard state.anchors[ghost.id] == nil else { continue }
      // A connector mark follows what its ends join (story 917), and holds to nothing more.
      let anchor =
        ghost.connector == nil
        ? BoardMarkHolds.anchor(boardMark(ghost, lines: ghost.lines), on: ink) : BoardMarkAnchor(strokes: [])
      state.anchors[ghost.id] = anchor
      log.event(
        "whiteboard_marks",
        [
          "action": "anchored", "board": board.id, "mark": ghost.id, "who": ghost.who.rawValue,
          "to": anchor.strokes.first?.name ?? "", "strokes": anchor.strokes.count, "gap": anchor.gap,
        ])
    }
    var hidden: Set<String> = []
    for ghost in turns.ghosts {
      let place = BoardMarkHolds.place(state.anchors[ghost.id] ?? BoardMarkAnchor(strokes: []), on: ink.strokes)
      let was = state.places[ghost.id] ?? BoardMarkHolds.Place()
      if place.dx != was.dx || place.dy != was.dy {
        turns.change(ghost.id) { $0.move(dx: place.dx - was.dx, dy: place.dy - was.dy) }
      }
      if place.hidden != was.hidden || place.faded != was.faded {
        log.event(
          "whiteboard_marks",
          [
            "action": "mark_look", "board": board.id, "mark": ghost.id, "hidden": place.hidden?.rawValue ?? "",
            "faded": place.faded, "dx": Double(place.dx), "dy": Double(place.dy),
          ])
      }
      state.places[ghost.id] = place
      if place.hidden != nil { hidden.insert(ghost.id) }
    }
    laps?.lap("follow_place")
    if turns.hiddenMarks != hidden { turns.hiddenMarks = hidden }
    if state != markHolds { markHolds = state }
    saveMarkAnchors()
    laps?.lap("follow")
  }

  /// Igor's new strokes (the Pencil, or a finger that draws): each mark one writes over fades (story 1269).
  func marksWritten(_ new: [PKStroke]) {
    guard editable, !new.isEmpty, !turns.ghosts.isEmpty else { return }
    // #1527: this part of a stroke grows with the board; slow, it names its own steps.
    let laps = StepLaps()
    defer { logPartLaps(laps, part: "marks") }
    marksFollow(laps: laps)
    var state = markHolds
    let strokes = opStrokes(drawing.strokes).strokes
    laps.lap("op_all")
    let marks = turns.ghosts.compactMap { ghost in
      state.landed[ghost.id].map { boardMark(ghost, lines: $0) }
    }
    let written = opStrokes(new).strokes
    laps.lap("op_new")
    for stroke in written {
      for over in BoardMarkHolds.wrote(stroke, marks: marks, anchors: &state.anchors, strokes: strokes) {
        log.event(
          "whiteboard_marks",
          [
            "action": "written_over", "board": board.id, "mark": over.id, "stroke": stroke.ids.first ?? "",
            "share": (over.share * 100).rounded() / 100,
          ])
      }
    }
    laps.lap("wrote")
    guard state != markHolds else { return }
    markHolds = state
    marksFollow(laps: laps)
  }

  /// What a post now would take away (story 1270).
  func marksToDrop() -> [BoardMarkHolds.Drop] {
    turns.ghosts.compactMap { ghost in
      markHolds.places[ghost.id]?.drops.map { BoardMarkHolds.Drop(id: ghost.id, why: $0) }
    }
  }

  /// A picture that reached Larry took `drops` away (story 1270): they go, settled as a dismissed mark is.
  func marksDropped(_ drops: [BoardMarkHolds.Drop]) {
    let gone = turns.drop(Set(drops.map(\.id)))
    guard !gone.isEmpty else { return }
    for ghost in gone { settleLarrys(ghost) }
    log.event(
      "whiteboard_marks",
      [
        "action": "dropped", "board": board.id, "marks": drops.map(\.id),
        "why": drops.map(\.why.rawValue), "left": turns.ghosts.count,
      ])
    marksFollow()
  }

  // MARK: Kept on this device

  private var markAnchorsKey: String { "whiteboard_mark_anchors_\(board.id)" }

  /// The anchors of Larry's marks (his text's too), so a mark shown again when the board opens holds to the same ink.
  /// Claude's marks fade in seconds and are never kept.
  private func saveMarkAnchors() {
    let larrys = markHolds.anchors.filter { id, _ in turns.ghosts.first { $0.id == id }?.who != .claude }
    guard larrys != savedMarkAnchors else { return }
    savedMarkAnchors = larrys
    if larrys.isEmpty {
      UserDefaults.standard.removeObject(forKey: markAnchorsKey)
    } else if let data = try? JSONEncoder().encode(larrys) {
      UserDefaults.standard.set(data, forKey: markAnchorsKey)
    }
  }

  /// On opening: the anchors kept for this board.
  func loadMarkAnchors() {
    guard let data = UserDefaults.standard.data(forKey: markAnchorsKey),
      let saved = try? JSONDecoder().decode([String: BoardMarkAnchor].self, from: data)
    else { return }
    savedMarkAnchors = saved
    markHolds.anchors = saved
  }
}
