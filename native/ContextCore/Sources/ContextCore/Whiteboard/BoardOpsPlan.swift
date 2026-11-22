//  What a batch of Larry's changes does to the board (spec 2026-11-16-whiteboard-board-ops-design.md, stories 814–817,
//  840–842, 847, 848): which strokes move, which go, which he draws, what notes they carry, what hides, and how many
//  pages the board needs after. The ops run in order, each on the board the ones before it left, so a later op can move
//  or erase what an earlier one drew. Pure: the app applies the plan to PaperKit.

import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension BoardOps {
  /// One stroke on the canvas as the plan sees it: the names Larry knows it by (one per visible stretch) and when it was
  /// made, unix ms.
  public struct Stroke: Equatable, Sendable {
    public var ids: [String]
    public var t: Int64?
    public var seed: Int
    public var bounds: CGRect
    /// Folded away or hidden by Larry: still on the board, but nothing lands around it or reads it as a line.
    public var hidden: Bool
    /// Its path in board points (its stretches end to end) and its pen's width: what tells an underline, and what a
    /// held Pencil is on. Empty where only boxes matter.
    public var points: [CGPoint]
    public var pen: CGFloat

    public init(
      ids: [String], t: Int64?, bounds: CGRect, hidden: Bool = false, points: [CGPoint] = [], pen: CGFloat = 0,
      seed: Int = 0
    ) {
      self.ids = ids
      self.t = t
      self.seed = seed
      self.bounds = bounds
      self.hidden = hidden
      self.points = points
      self.pen = pen
    }
  }

  /// What moves as a whole: a stroke, every glyph of a kept text, a group of Larry's, or a header with what is folded
  /// under it.
  public struct Item: Equatable, Sendable {
    /// Every name it answers to: its strokes', and its text's or group's.
    public var ids: Set<String>
    /// The strokes' places on the canvas.
    public var members: [Int]
    /// What shows of it: a folded header's is its own row. All of it when none shows.
    public var bounds: CGRect
    /// Every stroke of it is hidden.
    public var hidden: Bool
    /// The text, group or header (`h:<id>`) that makes it one; nil for a lone stroke.
    public var tag: String?
  }

  /// The boxes of what shows and moves whole: what a paste lands clear of and a cut never splits.
  public static func shownBoxes(
    strokes: [Stroke], texts: [BoardText] = [], groups: [String: String] = [:], folds: [String: String] = [:]
  ) -> [CGRect] {
    items(strokes: strokes, texts: texts, groups: groups, folds: folds).filter { !$0.hidden }.map(\.bounds)
  }

  /// The canvas's strokes as items: a header's row with what is folded under it is one item (`folds`, stroke name to
  /// `h:<id>`, from `BoardOutline`), a kept text's glyphs (made at its time) are one item answering to its id, and
  /// strokes whose notes name one group are one item answering to the group. A kept text Larry grouped (notes under
  /// its id, #937) is in its group's item, and still answers to its own id.
  public static func items(
    strokes: [Stroke], texts: [BoardText] = [], groups: [String: String] = [:], folds: [String: String] = [:]
  ) -> [Item] {
    let byTime = BoardText.byTime(texts)
    var out: [Item] = []
    var byTag: [String: Int] = [:]
    var all: [CGRect] = []
    for (index, stroke) in strokes.enumerated() {
      let text = BoardText.owning(stroke.t, in: byTime)?.id
      let tag =
        stroke.ids.lazy.compactMap { folds[$0] }.first ?? text.flatMap { groups[$0] }
        ?? stroke.ids.lazy.compactMap { groups[$0] }.first ?? text
      let ids = stroke.ids + (text.map { [$0] } ?? [])
      if let tag, let at = byTag[tag] {
        out[at].ids.formUnion(ids)
        out[at].members.append(index)
        all[at] = all[at].union(stroke.bounds)
        if !stroke.hidden { out[at].bounds = out[at].hidden ? stroke.bounds : out[at].bounds.union(stroke.bounds) }
        out[at].hidden = out[at].hidden && stroke.hidden
        continue
      }
      if let tag { byTag[tag] = out.count }
      all.append(stroke.bounds)
      out.append(
        Item(
          ids: Set(ids + (tag.map { [$0] } ?? [])), members: [index], bounds: stroke.bounds,
          hidden: stroke.hidden, tag: tag))
    }
    for at in out.indices where out[at].hidden { out[at].bounds = all[at] }
    return out
  }

  public struct Plan: Equatable, Sendable {
    /// How far each canvas stroke moves, by its place on the canvas; strokes that stay or go are absent.
    public var offsets: [Int: CGVector] = [:]
    /// Canvas strokes erased, by place.
    public var erase: Set<Int> = []
    /// Strokes Larry draws, where the batch leaves them.
    public var added: [NewStroke] = []
    /// Notes set, by stroke name (his drawn strokes' included).
    public var metas: [String: BoardMeta] = [:]
    /// Names erased and not drawn again: their notes go.
    public var forgetMetas: Set<String> = []
    /// Canvas strokes hidden (true) or shown (false), by place. A stroke he draws carries its own.
    public var hidden: [Int: Bool] = [:]
    /// Names to select once the batch is on the board (story 848).
    public var select: [String] = []
    /// Larry's controls laid and taken away, in order (story 845): never ink, never undone.
    public var overlays: [BoardOverlays.Change] = []
    /// Ghosts of Larry's text to show: new ones, and ones showing that the batch moved (they replace theirs by id).
    public var texts: [Text] = []
    /// Ghosts of his text showing before the batch that it took away: deleted, replaced, or inked (#939, story 993).
    public var dismissed: [String] = []
    /// Larry's texts that go onto the board as kept text at once, where the batch leaves them: a text he put notes on
    /// is ink, never a ghost (#937, story 991). The app letters them; their notes are in `metas` under their ids.
    public var inked: [Text] = []
    public var pagesBefore: Int
    public var pagesAfter: Int
    /// Items that moved.
    public var moved = 0
    public var missingIDs: [String] = []
    /// Connectors drawn by the batch, drawn again on a new route, and turned plain ink as an end went (stories 910–916).
    public var connected: [String] = []
    public var rerouted: [String] = []
    public var loosened: [String] = []

    public init(pagesBefore: Int, pagesAfter: Int) {
      self.pagesBefore = pagesBefore
      self.pagesAfter = pagesAfter
    }

    /// The board's ink changes: something moves, goes, is drawn, hides or shows, or a page is added. Text and notes
    /// alone leave the ink as it is.
    public var changesBoard: Bool {
      !offsets.isEmpty || !erase.isEmpty || !added.isEmpty || !inked.isEmpty || !hidden.isEmpty
        || pagesAfter != pagesBefore
    }
  }

  /// The batch's changes on the canvas's `strokes`, in order. `ghosts`: his text ghosts showing, which his ops reach by
  /// name as they reach a kept text (#939). `pages` is the column's page count now; it grows to hold
  /// the ink after, and the room a push opens below the last ink.
  public static func plan(
    _ ops: [Op], strokes: [Stroke], texts: [BoardText] = [], metas: BoardStrokeMeta = BoardStrokeMeta(),
    folds: [String: String] = [:], ghosts showing: [Text] = [], pages: Int, board: BoardPages = BoardPages()
  ) -> Plan {
    var work = Working(
      strokes: strokes, texts: texts, items: items(strokes: strokes, texts: texts, groups: metas.groups, folds: folds))
    // His texts this batch shows as ghosts, in order; one he puts notes on leaves them for the board (#937).
    var ghosts: [Text] = showing
    /// A ghost of his named `id` takes it away; false when none is showing (#939).
    func dismiss(_ id: String) -> Bool {
      guard let at = ghosts.firstIndex(where: { $0.id == id }) else { return false }
      ghosts.remove(at: at)
      return true
    }
    var plan = Plan(pagesBefore: pages, pagesAfter: pages)
    var reach: CGFloat?
    var connectors: [NewConnector] = []
    // Everything at or below `y` down `dy`, of `items` (all the ink by default), and his ghosts showing there.
    func push(_ y: CGFloat, _ dy: CGFloat, items: [Int]? = nil) {
      for item in items ?? Array(work.items.indices) where work.top(item).map({ $0 >= y }) == true {
        work.move(item, 0, dy)
      }
      for at in ghosts.indices where ghosts[at].y >= y { ghosts[at].y += dy }
      if dy > 0 { reach = max(reach ?? y + dy, y + dy) }
    }
    for op in ops {
      switch op {
      case .translateBelow(let y, let dy):
        push(y, dy)
      case .translateIDs(let ids, let dx, let dy):
        var hit = Set<Int>()
        for id in ids {
          let found = work.items(named: id)
          // A ghost of his moves by its name (#939).
          if let at = ghosts.firstIndex(where: { $0.id == id }) {
            ghosts[at].x += dx
            ghosts[at].y += dy
            continue
          }
          if found.isEmpty { plan.missingIDs.append(id) }
          hit.formUnion(found)
        }
        for item in hit.sorted() { work.move(item, dx, dy) }
      case .addText(var text):
        ghosts.removeAll { $0.id == text.id }
        // His text never lands on ink: it makes room, as a paste does (#938, story 992).
        // What it lands clear of and moves: the board's ink, not what this change draws (his box for it), nor a frame
        // it sits in.
        let box = text.box
        let ink = work.canvasInk.filter { $0.box.map { !$0.contains(box) } ?? true }
        let room = BoardRoom.text(box, among: ink.compactMap(\.box))
        text.y = room.y
        if let room = room.push { push(room.cut, room.dy, items: ink.filter(\.moves).map(\.item)) }
        ghosts.append(text)
      case .addStrokes(let new):
        work.add(new, plan: &plan)
      case .delete(let ids):
        for id in ids where !(work.erase(named: id) || dismiss(id)) { plan.missingIDs.append(id) }
      case .setMeta(let ids, let meta):
        for id in ids {
          // A text with notes is ink, never a ghost (#937, story 991).
          if let at = ghosts.firstIndex(where: { $0.id == id }) {
            work.ink(ghosts.remove(at: at))
          }
          let names = work.names(of: id)
          if names.isEmpty { plan.missingIDs.append(id) }
          for name in names { plan.metas[name] = meta }
          if let group = meta.group { work.join(work.entries(named: id), group: group) }
        }
      case .replace(let ids, let new):
        for id in ids where !(work.erase(named: id) || dismiss(id)) { plan.missingIDs.append(id) }
        work.add(new, plan: &plan)
      case .setHidden(let ids, let hidden):
        for id in ids {
          let found = work.entries(named: id)
          if found.isEmpty { plan.missingIDs.append(id) }
          for e in found { work.entries[e].hidden = hidden }
        }
      case .select(let ids):
        for id in ids {
          let names = work.names(of: id)
          if names.isEmpty { plan.missingIDs.append(id) }
          plan.select += names.filter { !plan.select.contains($0) }
        }
      case .overlay(let overlay):
        plan.overlays.append(.set(overlay))
      case .removeOverlay(let id):
        plan.overlays.append(.remove(id))
      case .connector(let new):
        connectors.append(new)
      }
    }
    plan.texts = ghosts.filter { !showing.contains($0) }
    plan.dismissed = showing.map(\.id).filter { id in !ghosts.contains { $0.id == id } }
    work.finish(into: &plan)
    // Connectors last, on the board the batch leaves; then every connector follows its ends (stories 910–916).
    BoardConnectors.draw(connectors, into: &plan, strokes: strokes, texts: texts, metas: metas, folds: folds)
    BoardConnectors.follow(&plan, strokes: strokes, texts: texts, metas: metas, folds: folds)
    let inkMaxY = (work.liveBounds.map(\.maxY) + (reach.map { [$0] } ?? [])).max()
    plan.pagesAfter = board.pages(after: pages, inkMaxY: inkMaxY, redoWaiting: false)
    return plan
  }

  /// The board as the batch changes it: entries are the canvas's strokes then the ones the batch draws.
  struct Working {
    struct Entry {
      var names: [String]
      /// Its place on the canvas, or in the plan's drawn strokes.
      var canvas: Int?
      var drawn: Int?
      /// Its place in `inked`: a text of his the batch inks.
      var text: Int?
      var bounds: CGRect
      var shift = CGVector.zero
      var gone = false
      /// Set by the batch: hidden or shown.
      var hidden: Bool?
      /// Hidden on the canvas before the batch (folded away).
      var folded = false
    }

    var entries: [Entry]
    /// Each item's entries, and the names it answers to as a whole (its text or group).
    var items: [(entries: [Int], tags: Set<String>)]
    var drawn: [NewStroke] = []
    /// His texts the batch inks (#937), by `Entry.text`.
    var inked: [Text] = []

    /// A kept text's glyphs answer to its id one by one, as a stroke does to its name: in a group, its id names the text
    /// alone, not the group.
    init(strokes: [Stroke], texts: [BoardText] = [], items: [Item]) {
      let byTime = BoardText.byTime(texts)
      let names = strokes.map { $0.ids + (BoardText.owning($0.t, in: byTime).map { [$0.id] } ?? []) }
      entries = strokes.enumerated().map {
        Entry(names: names[$0], canvas: $0, bounds: $1.bounds, folded: $1.hidden)
      }
      self.items = items.map { item in
        let own = Set(item.members.flatMap { names[$0] })
        return (item.members, item.ids.subtracting(own))
      }
    }

    /// A text of his goes onto the board as ink, its own item until notes group it.
    mutating func ink(_ text: Text) {
      _ = erase(named: text.id)
      entries.append(Entry(names: [text.id], text: inked.count, bounds: text.box))
      inked.append(text)
      items.append(([entries.count - 1], []))
    }

    /// These entries move as one with the group `group` from now on in the batch.
    mutating func join(_ members: [Int], group: String) {
      guard !members.isEmpty else { return }
      for item in items.indices { items[item].entries.removeAll { members.contains($0) } }
      if let item = items.firstIndex(where: { $0.tags.contains(group) }) {
        items[item].entries += members
      } else {
        items.append((members, [group]))
      }
    }

    func live(_ item: Int) -> [Int] { items[item].entries.filter { !entries[$0].gone } }

    func top(_ item: Int) -> CGFloat? { live(item).map { entries[$0].bounds.minY }.min() }

    var liveBounds: [CGRect] { entries.filter { !$0.gone }.map(\.bounds) }

    /// The board's ink from before the batch, by what moves whole, as the batch has left it: each item's box of what
    /// shows of it (nil when none does), and whether it is all canvas ink, nothing the batch drew or inked. What his text
    /// lands clear of, and what of it the room his text opens moves.
    var canvasInk: [(item: Int, box: CGRect?, moves: Bool)] {
      items.indices.compactMap { item in
        let all = live(item)
        let canvas = all.filter { entries[$0].canvas != nil }
        guard !canvas.isEmpty else { return nil }
        let shown = canvas.filter { !(entries[$0].hidden ?? entries[$0].folded) }
        let box = shown.isEmpty ? nil : shown.map { entries[$0].bounds }.reduce(CGRect.null) { $0.union($1) }
        return (item, box, canvas.count == all.count)
      }
    }

    /// Items answering to `id`: by its text or group, or by one of its strokes' names. Moving a stroke of a group moves
    /// the group.
    func items(named id: String) -> [Int] {
      items.indices.filter { item in
        !live(item).isEmpty && (items[item].tags.contains(id) || live(item).contains { entries[$0].names.contains(id) })
      }
    }

    /// Live entries `id` names: a text's or group's, all of them; a stroke's name, that stroke alone.
    func entries(named id: String) -> [Int] {
      let tagged = items.indices.filter { items[$0].tags.contains(id) }.flatMap { live($0) }
      if !tagged.isEmpty { return tagged }
      return entries.indices.filter { !entries[$0].gone && entries[$0].names.contains(id) }
    }

    /// The stroke names `id` covers.
    func names(of id: String) -> [String] { entries(named: id).flatMap { entries[$0].names } }

    mutating func move(_ item: Int, _ dx: CGFloat, _ dy: CGFloat) {
      for e in live(item) {
        entries[e].bounds = entries[e].bounds.offsetBy(dx: dx, dy: dy)
        entries[e].shift.dx += dx
        entries[e].shift.dy += dy
      }
    }

    /// False when nothing answers to `id`.
    mutating func erase(named id: String) -> Bool {
      let found = entries(named: id)
      for e in found { entries[e].gone = true }
      return !found.isEmpty
    }

    /// Larry's strokes join the board: a name already there is redrawn (the Cockpit takes a name once), and one whose
    /// notes name a group joins that group.
    mutating func add(_ new: [NewStroke], plan: inout Plan) {
      for stroke in new {
        _ = erase(named: stroke.id)
        let entry = entries.count
        entries.append(Entry(names: [stroke.id], drawn: drawn.count, bounds: stroke.bounds))
        drawn.append(stroke)
        if let meta = stroke.meta { plan.metas[stroke.id] = meta }
        if let group = stroke.meta?.group, let item = items.indices.first(where: { items[$0].tags.contains(group) }) {
          items[item].entries.append(entry)
        } else {
          items.append(([entry], stroke.meta?.group.map { [$0] } ?? []))
        }
      }
    }

    func finish(into plan: inout Plan) {
      for entry in entries {
        if let canvas = entry.canvas {
          if entry.gone {
            plan.erase.insert(canvas)
          } else {
            if entry.shift.dx != 0 || entry.shift.dy != 0 { plan.offsets[canvas] = entry.shift }
            if let hidden = entry.hidden { plan.hidden[canvas] = hidden }
          }
        } else if let index = entry.text, !entry.gone {
          var text = inked[index]
          text.x += entry.shift.dx
          text.y += entry.shift.dy
          plan.inked.append(text)
        } else if let index = entry.drawn, !entry.gone {
          var stroke = drawn[index]
          stroke.points = stroke.points.map { CGPoint(x: $0.x + entry.shift.dx, y: $0.y + entry.shift.dy) }
          if let hidden = entry.hidden { stroke.hidden = hidden }
          plan.added.append(stroke)
        }
      }
      plan.moved =
        items.indices.filter { item in
          live(item).contains { entries[$0].canvas != nil && (entries[$0].shift.dx != 0 || entries[$0].shift.dy != 0) }
        }.count
      for stroke in plan.added {
        if plan.metas[stroke.id] == nil, let meta = stroke.meta { plan.metas[stroke.id] = meta }
      }
      // Notes on strokes that went are forgotten with them.
      let gone = Set(entries.filter(\.gone).flatMap(\.names))
      let live = Set(entries.filter { !$0.gone }.flatMap(\.names))
      plan.forgetMetas = gone.subtracting(live)
      for name in plan.forgetMetas { plan.metas[name] = nil }
    }
  }
}
