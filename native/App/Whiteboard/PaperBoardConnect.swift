//  Connectors on paper (spec 2026-11-16-whiteboard-board-ops-design.md, *Step 5: connectors*, stories 910–916): Igor's
//  Connect on a lassoed arrow, and every connector following its ends after a change of Igor's own. A plan of anyone
//  else's (Larry's batches, a paste, a room, a fold, the Pencil's word move) follows inside the plan, in its own Undo.

import ContextCore
import PaperKit
import PencilKit
import SwiftUI

extension PaperBoardController {
  /// Igor's own change (PaperKit's lasso move, the eraser): a moment later, out of PaperKit's callback, each connector
  /// follows its ends, quietly and with no Undo of its own. PaperKit's undo of his change is another change, which
  /// follows again, so the arrows always sit on their ends.
  func followSoon() {
    following?.cancel()
    following = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(50))
      guard !Task.isCancelled, let self else { return }
      self.followConnectors()
      self.selectNewestForTests()
      self.offerConnect(Set(self.paper.selection.map(Self.key)))
    }
  }

  private func followConnectors() {
    guard model.editable, model.strokeMeta.hasConnectors, let markup = paper.markup else { return }
    let started = CACurrentMediaTime()
    let (strokes, hashes) = opStrokes(markup)
    var plan = BoardOps.Plan(pagesBefore: pages, pagesAfter: pages)
    BoardConnectors.follow(
      &plan, strokes: strokes, texts: model.texts, metas: model.strokeMeta, folds: model.outline(of: strokes).tags)
    guard !plan.rerouted.isEmpty || !plan.loosened.isEmpty else { return }
    if plan.changesBoard {
      guard let (held, renamed, drawn) = put(plan, on: markup, hashes: hashes, named: "", stepBack: false) else {
        return
      }
      model.opsApplied(held.inkDrawing, renamed: renamed, drawn: drawn)
      model.inkReset(Self.allHashes(held))
    } else {
      model.planPut(plan, drawn: [])
    }
    log.event(
      "board_connectors",
      [
        "action": "followed", "board": model.board.id, "rerouted": plan.rerouted, "loosened": plan.loosened,
        "ms": ms(CACurrentMediaTime() - started),
      ])
  }

  /// The selection's strokes, as the plan sees them, and their names.
  private func selected(_ keys: Set<String>, in markup: PaperMarkup) -> (
    strokes: [BoardOps.Stroke], hashes: [[String]], names: Set<String>
  ) {
    let (strokes, hashes) = opStrokes(markup)
    let elements = markup.subelements.strokes
    let names = elements.indices.filter {
      strokes.indices.contains($0) && keys.contains(Self.key(elements[$0].elementID))
    }
    .flatMap { strokes[$0].ids }
    return (strokes, hashes, Set(names))
  }

  private func connectOps(_ keys: Set<String>, id: String) -> [BoardOps.Op]? {
    // Up to a whole small diagram: PaperKit's lasso can take both boxes with the arrow (#1440, story 1358).
    guard model.editable, !keys.isEmpty, keys.count <= BoardConnectors.maxDiagram, let markup = paper.markup else {
      return nil
    }
    let (strokes, _, names) = selected(keys, in: markup)
    return BoardConnectors.connect(
      selected: names, id: id, strokes: strokes, texts: model.texts, metas: model.strokeMeta,
      folds: model.outline(of: strokes).tags)
  }

  /// Story 910: the lasso holds an arrow whose two ends land on two things: Connect shows beside it.
  func offerConnect(_ keys: Set<String>) {
    let ready = connectOps(keys, id: "connect-probe") != nil
    // #1440: what the lasso took and whether Connect could show, so a selection that offers nothing is visible.
    if !keys.isEmpty {
      log.event(
        "board_connectors", ["action": "connect_offer", "board": model.board.id, "keys": keys.count, "ready": ready])
    }
    connectKeys = ready ? keys : []
    showConnect()
    nameSelection(connectReady: ready)
  }

  /// Where the lassoed arrow is on screen now, for its Connect.
  func showConnect() {
    var frame: CGRect?
    if !connectKeys.isEmpty, let markup = paper.markup {
      let box = markup.subelements.strokes.filter { connectKeys.contains(Self.key($0.elementID)) }
        .compactMap { markup.subelements[$0.elementID] as? PKStroke }.reduce(CGRect.null) { $0.union($1.renderBounds) }
      if !box.isNull {
        let a = lines.convert(lines.spot(of: CGPoint(x: box.minX, y: box.minY)), to: view)
        let b = lines.convert(lines.spot(of: CGPoint(x: box.maxX, y: box.maxY)), to: view)
        frame = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
      }
    }
    if frame != connectFrame { connectFrame = frame }
  }

  /// Story 910: his drawn arrow goes and a clean connector joins its two ends, one Undo named Connect; Larry hears the ink
  /// change as any other.
  func connect() {
    let keys = connectKeys
    log.event(
      "board_connectors",
      [
        "action": "connect_pressed", "board": model.board.id, "keys": keys.count,
        "selected": paper.selection.count,
      ])
    let id = "c-" + UUID().uuidString.prefix(8).lowercased()
    connectKeys = []
    connectFrame = nil
    guard let ops = connectOps(keys, id: id), let markup = paper.markup else {
      log.event("board_connectors", ["action": "connect_refused", "board": model.board.id, "keys": keys.count])
      return
    }
    let started = CACurrentMediaTime()
    let (strokes, hashes) = opStrokes(markup)
    let plan = BoardOps.plan(
      ops, strokes: strokes, texts: model.texts, metas: model.strokeMeta, folds: model.outline(of: strokes).tags,
      pages: pages, board: board)
    let framesBefore = inkFrames
    guard let (held, _, _) = put(plan, on: markup, hashes: hashes, named: "Connect") else { return }
    paper.selection = []
    model.stepped(held.inkDrawing)
    noteInk(held, since: framesBefore, report: true)
    let made = BoardConnector(plan.metas[id])
    log.event(
      "board_connectors",
      [
        "action": "connected", "board": model.board.id, "id": id, "from": made?.from ?? "", "to": made?.to ?? "",
        "elbow": (made?.route.count ?? 0) > 2, "erased": plan.erase.count, "rerouted": plan.rerouted,
        "ms": ms(CACurrentMediaTime() - started),
      ])
  }

  /// `GRABBER_WHITEBOARD_SELECT_NEWEST=<n>`: once the board holds `n` strokes, the newest selected, once.
  private func selectNewestForTests() {
    guard !selectedNewestForTests, let n = LaunchHooks.current.whiteboard.selectNewest, let markup = paper.markup,
      markup.subelements.strokes.count == n, let newest = markup.subelements.strokes.last
    else { return }
    selectedNewestForTests = true
    paper.selection = [newest.elementID]
    log.event("board_connectors", ["action": "select_newest_hook", "board": model.board.id, "strokes": n])
  }
}

/// Story 910: Connect beside a lassoed arrow that joins two things; under To text when that shows for the same lasso
/// (story 920), which would otherwise sit over it.
struct ConnectButton: View {
  let controller: PaperBoardController
  let arrow: CGRect?
  @ObservedObject var toText: BoardToTextState
  private static let size = CGSize(width: 116, height: 44)
  /// To text's own size (`ToTextButton`).
  private static let toTextSize = CGSize(width: 128, height: 44)

  /// Where Connect goes: beside the arrow, or clear of To text's place when both show.
  static func place(arrow: CGRect, toText: CGRect?, in view: CGRect) -> CGRect {
    let mine = WhiteboardMarkChoice.place(mark: arrow, buttons: size, in: view)
    guard let toText else { return mine }
    let theirs = WhiteboardMarkChoice.place(mark: toText, buttons: toTextSize, in: view)
    guard mine.intersects(theirs.insetBy(dx: -4, dy: -4)) else { return mine }
    let below = CGRect(x: theirs.midX - size.width / 2, y: theirs.maxY + 6, width: size.width, height: size.height)
    let above = below.offsetBy(dx: 0, dy: -(theirs.height + size.height + 12))
    return below.maxY <= view.maxY ? below : above
  }

  var body: some View {
    GeometryReader { geometry in
      if let arrow {
        // Clear of *Reading…* while To text reads (#1386: nothing else of To text shows beside a selection).
        let place = Self.place(
          arrow: arrow, toText: toText.reading ? toText.frame : nil, in: CGRect(origin: .zero, size: geometry.size))
        Button("Connect", systemImage: "arrow.right.circle") { controller.connect() }
          .accessibilityIdentifier("whiteboard-connect")
          .font(.subheadline.weight(.semibold))
          .buttonStyle(.bordered)
          .controlSize(.small)
          .frame(width: Self.size.width, height: Self.size.height)
          .background(.regularMaterial, in: Capsule())
          .position(x: place.midX, y: place.midY)
      }
    }
  }
}
