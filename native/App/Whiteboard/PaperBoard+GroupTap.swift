//  A board on paper: a finger tap on any stroke of a group selects the whole group, ready to drag (story 947, #947).

import ContextCore
import PaperKit
import UIKit

extension PaperBoardController {
  /// A group a finger tapped: its name, its strokes' names, and whether it was already the whole selection. `kind` is
  /// "group", "theirs" for one thing of Larry's outside a group (story 1140, PaperBoard+TheirsTap.swift), or "text" for a kept text
  /// (story 1197, PaperBoard+TextTap.swift).
  struct TappedGroup {
    var name: String
    var names: Set<String>
    var selected: Bool
    var kind = "group"
  }

  /// Story 947: the group whose stroke is within a fingertip (22 screen points) of `at`, in board points, on a board he
  /// can draw on. Nil off every group, and at once on a board with none.
  func tappedGroup(at: CGPoint) -> TappedGroup? {
    guard model.editable, !model.strokeMeta.groups.isEmpty, let markup = paper.markup else { return nil }
    let strokes = opStrokes(markup).strokes
    guard let hit = model.outline(of: strokes).group(at: at, slop: WhiteboardTurn.tapReach / max(screenScale, 0.01))
    else { return nil }
    let names = Set(hit.names)
    let ids = groupElements(names, in: markup)
    guard !ids.isEmpty else { return nil }
    return TappedGroup(name: hit.group, names: names, selected: ids == paper.selection)
  }

  /// The markup's elements for these strokes' names, found again each time: PaperKit's ids change as the ink does.
  func groupElements(_ names: Set<String>, in markup: PaperMarkup) -> Set<MarkupOrderedSet.ElementID> {
    let strokes = opStrokes(markup).strokes
    let elements = markup.subelements.strokes
    return Set(
      strokes.indices.filter { strokes[$0].ids.contains(where: names.contains) }
        .compactMap { elements.indices.contains($0) ? elements[$0].elementID : nil })
  }

  /// The group selected, as a lasso round it would select it. PaperKit makes its own selection for the same tap after
  /// the lift, which goes back to the group (`reselectGroupTap`); a finger that draws leaves a dot, taken back as a
  /// ghost tap's is. A beat later the log says whether it held.
  func select(_ group: TappedGroup, tappedAt at: CGPoint, beganAt: Date) {
    guard let markup = paper.markup else { return }
    let now = CACurrentMediaTime()
    let isGroup = group.kind == "group"
    let hold = isGroup ? PaperProbe.groupTapSeconds : 1.0
    let until = now + hold
    groupTap = (group.names, until)
    if fingersDraw {
      ghostTap = TapDot(
        at: at, beganAt: beganAt, time: now, within: isGroup ? hold : PaperProbe.tapDotSeconds,
        selection: (until, isGroup))
    }
    let ids = groupElements(group.names, in: markup)
    paper.selection = ids
    // As PaperKit's own selection callback would: Larry hears what is selected, and To text shows beside it.
    model.selectionChanged(Set(ids.map(Self.key)))
    showToText()
    let event: [String: Any] = [
      "action": "group_tap", "board": model.board.id, "at": point(at), "group": group.name, "kind": group.kind,
      "strokes": ids.count, "controls": model.overlays.list.count,
      "touch_mode": name(paper.directTouchMode), "fingers_draw": fingersDraw, "selected": paper.selection.count,
    ]
    log.event("whiteboard", event)
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(hold + 0.2))
      guard let self else { return }
      let wanted = self.paper.markup.map { self.groupElements(group.names, in: $0) } ?? []
      let held = !wanted.isEmpty && self.paper.selection == wanted
      let ours = self.groupTap?.until == until
      self.log.event(
        "whiteboard",
        [
          "action": "group_tap_held", "board": self.model.board.id, "group": group.name, "kind": group.kind,
          "held": held,
          "selected": self.paper.selection.count, "strokes": wanted.count, "touched_since": !ours,
        ])
      if ours { self.groupTap = nil }
    }
  }

  /// Story 947: the group a tap selected, selected again with no touch since. Taking back the tap's dot left nothing
  /// selected on the simulator, with no selection callback (2026-11-22: `group_tap_held` held false, selected 0).
  func reselectGroupTap(until: Double, why: String) {
    guard let tap = groupTap, tap.until == until, CACurrentMediaTime() < until, let markup = paper.markup,
      paper.undoManager?.isUndoing != true, paper.undoManager?.isRedoing != true
    else { return }
    let wanted = groupElements(tap.names, in: markup)
    guard !wanted.isEmpty, paper.selection != wanted else { return }
    log.event(
      "whiteboard",
      [
        "action": "group_tap_put_back", "board": model.board.id, "why": why, "had": paper.selection.count,
        "to": wanted.count,
      ])
    paper.selection = wanted
    model.selectionChanged(Set(wanted.map(Self.key)))
    showToText()
  }
}
