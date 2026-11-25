//  Headers that fold their sections, the outline's levels, the lines that look like headers, and the word a held
//  Pencil picks up (spec 2026-11-16-whiteboard-board-ops-design.md, *Headers fold their sections* and *Press and
//  hold*, stories 855–861; the Cockpit's assets/ink/board.mjs: `rowAt`, `markHeader`, `section`, `fold`, `unfold`,
//  `unfoldAll`, `foldAll`, `headerLevels`, `collapseToLevel`, `headerCandidates`, `wordAt`). Pure: the outline works on
//  the strokes' boxes and paths, and `plan` says what the board does to the canvas.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// A row of Igor's ink made a header, by its strokes' names, and what it folds away when folded.
public struct BoardHeader: Codable, Equatable, Sendable {
  public struct Fold: Codable, Equatable, Sendable {
    /// Every stroke tucked under it, a folded inner header's included.
    public var ids: [String]
    /// Those this fold hid: an inner fold's stay its own.
    public var own: [String]
    /// How far what was below slid up.
    public var shift: CGFloat
    /// Lines folded, for the margin mark and for Larry.
    public var lines: Int
    /// How far the section reached below the header: unfolding never draws over it.
    public var bottom: CGFloat
  }

  public var id: String
  public var ids: [String]
  public var fold: Fold?
  /// The strokes of the underline or # that made it (#967): while any of them is off the board it is no header, so the
  /// Undo of the mark takes the header and its Redo brings it back. Nil for a header made by a margin tap or the menu.
  public var mark: [String]?
  /// The strokes of each further # written beside the first (#1034): ## and ###. Nil for a level-1 header.
  public var deeper: [[String]]?
  /// Ink written under it while it was folded (story 1231): the section ends where the first of it begins, as at a
  /// rule, so the next fold leaves it out. Nil when an unfold found nothing new the section would have taken; a name
  /// erased from the board no longer ends it.
  public var ends: [String]?

  public init(
    id: String, ids: [String], fold: Fold? = nil, mark: [String]? = nil, deeper: [[String]]? = nil,
    ends: [String]? = nil
  ) {
    self.id = id
    self.ids = ids
    self.fold = fold
    self.mark = mark
    self.deeper = deeper
    self.ends = ends
  }

  /// The deepest a header's #s take it: ###.
  public static let deepest = 3

  /// Its level by its #s (#1034): 1, and one more for each further # still on the board, in the order they were
  /// written, so an Undo of the last # takes one level and its Redo brings it back.
  public func level(_ live: Set<String>) -> Int {
    min(Self.deepest, 1 + further(live).count)
  }

  /// The further #s still on the board, in the order they were written: those after one that is away don't count.
  func further(_ live: Set<String>) -> ArraySlice<[String]> {
    (deeper ?? []).prefix { !$0.isEmpty && $0.allSatisfy(live.contains) }
  }

  /// Its words: its ink but the underline or #s that made it a header (context-grabber-bov). Only these, or its fold's
  /// marker, take a folded section with the eraser; the mark's strokes are ink like any other.
  public var words: [String] {
    let marks = Set((mark ?? []) + (deeper ?? []).flatMap { $0 })
    return ids.filter { !marks.contains($0) }
  }

  /// Made by ink with a stroke gone, and open: no header while its mark is away (#967). A folded one keeps
  /// its fold, so erasing its underline never loses what it hides.
  public func markGone(_ live: Set<String>) -> Bool {
    guard fold == nil, let mark, !mark.isEmpty else { return false }
    return !mark.allSatisfy(live.contains)
  }
}

public struct BoardOutline: Sendable {
  public static let line = BoardRoom.line
  /// A section ends at a line starting this close to the header's left edge, or further left.
  public static let indentTolerance = line / 2
  /// A margin tap this far above or below a header's row is on it.
  public static let tapReach: CGFloat = 16
  /// A Pencil held still this long on ink picks up the word, and this still.
  public static let holdMs: Double = 400
  public static let holdStill: CGFloat = 5
  /// A gap between strokes on a line wider than this is a word gap.
  public static let wordGap: CGFloat = 16

  public var strokes: [BoardOps.Stroke]
  public internal(set) var headers: [BoardHeader]
  /// Story 1034: the names of lines Igor said were not headers (*Not a header*), never offered a faint H again until he
  /// makes one a header himself.
  public internal(set) var declined: Set<String>
  /// Strokes a fold's erase took (stories 902, 903), by place: still in `strokes`, so `plan` can name them, and in no
  /// unit.
  public internal(set) var erased: Set<Int> = []
  let texts: [BoardText]
  let groups: [String: String]
  /// Story 1280: the groups Igor made of his own ink (the web board lets him group), still his writing. Every other
  /// group is Larry's, as every group on the iPad is.
  public let mine: Set<String>

  public init(
    strokes: [BoardOps.Stroke], headers: [BoardHeader], texts: [BoardText] = [], groups: [String: String] = [:],
    declined: Set<String> = [], mine: Set<String> = []
  ) {
    self.strokes = strokes
    self.declined = declined
    self.texts = texts
    self.groups = groups
    self.mine = mine
    let names = Set(strokes.flatMap(\.ids))
    // A header whose ink is gone is no header, nor one whose underline or # is (#967).
    self.headers = headers.filter { $0.ids.contains(where: names.contains) && !$0.markGone(names) }
  }

  // MARK: - What moves whole

  struct Unit {
    var members: [Int]
    var bounds: CGRect
    var tag: String?
    var header: String? { tag.flatMap { $0.hasPrefix("h:") ? String($0.dropFirst(2)) : nil } }
  }

  var index: [String: Int] {
    var out: [String: Int] = [:]
    for (i, stroke) in strokes.enumerated() { for name in stroke.ids { out[name] = i } }
    return out
  }

  /// Stroke name to its header's tag (`h:<id>`): a header's own row, and what each holding fold tucked under it, the
  /// outer fold winning.
  public var tags: [String: String] {
    var out: [String: String] = [:]
    for header in headers { for name in header.ids { out[name] = "h:" + header.id } }
    let folded = headers.filter(isFolded).sorted { ($0.fold?.ids.count ?? 0) < ($1.fold?.ids.count ?? 0) }
    for header in folded { for name in header.fold?.ids ?? [] { out[name] = "h:" + header.id } }
    return out
  }

  /// What shows, as the things that move whole.
  func units() -> [Unit] {
    BoardOps.items(strokes: strokes, texts: texts, groups: groups, folds: tags).filter { !$0.hidden }.compactMap {
      guard !erased.isEmpty else { return Unit(members: $0.members, bounds: $0.bounds, tag: $0.tag) }
      let live = $0.members.filter { !erased.contains($0) }
      let shown = live.filter { !strokes[$0].hidden }.reduce(CGRect.null) { $0.union(strokes[$1].bounds) }
      return shown.isNull ? nil : Unit(members: live, bounds: shown, tag: $0.tag)
    }
  }

  func names(_ members: [Int]) -> [String] { members.flatMap { strokes[$0].ids } }

  /// His own: a lone stroke or a group he made (story 1280). A kept text, a card, a group of Larry's or a header's row
  /// is not.
  func his(_ unit: Unit) -> Bool { unit.tag.map(mine.contains) ?? true }

  /// The strokes in a group of Larry's or a kept text: never his writing.
  var tagged: Set<Int> { Set(units().filter { !his($0) && $0.header == nil }.flatMap(\.members)) }

  mutating func shift(_ unit: Unit, by dy: CGFloat) {
    for m in unit.members { shift(m, dx: 0, dy: dy) }
  }

  private mutating func shift(_ m: Int, dx: CGFloat, dy: CGFloat) {
    strokes[m].bounds = strokes[m].bounds.offsetBy(dx: dx, dy: dy)
    strokes[m].points = strokes[m].points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
  }

  private func isText(_ tag: String?) -> Bool { tag.map { id in texts.contains { $0.id == id } } ?? false }

  /// Story 1309: these strokes' names are one kept text, whole, even where a header's row or a group holds it.
  func isKeptText(_ chosen: [String]) -> Bool {
    let wanted = Set(chosen)
    let byTime = BoardText.byTime(texts)
    let live = strokes.indices.filter { !erased.contains($0) }
    func text(_ m: Int) -> String? { BoardText.owning(strokes[m].t, in: byTime)?.id }
    guard let first = live.first(where: { !wanted.isDisjoint(with: strokes[$0].ids) }), let id = text(first) else {
      return false
    }
    return Set(names(live.filter { text($0) == id })) == wanted
  }

  // MARK: - Headers

  /// A fold that still holds: what it hid is still hidden. An Undo that shows it again opens the fold.
  public func isFolded(_ header: BoardHeader) -> Bool {
    guard let fold = header.fold else { return false }
    let at = index
    let own = fold.own.compactMap { at[$0] }
    return !own.isEmpty && own.allSatisfy { strokes[$0].hidden }
  }

  public func header(_ id: String) -> BoardHeader? { headers.first { $0.id == id } }

  /// The header's level by its #s: 1 for a single #, an underline or a margin tap; 2 for ##, 3 for ### (#1034).
  public func level(_ header: BoardHeader) -> Int { header.level(liveNames) }

  /// Its own strokes show: it isn't folded away inside another's section.
  public func shows(_ header: BoardHeader) -> Bool {
    let at = index
    let own = header.ids.compactMap { at[$0] }
    return !own.isEmpty && !own.contains { strokes[$0].hidden }
  }

  /// The header's own row.
  public func box(_ header: BoardHeader) -> CGRect? {
    let at = index
    let box = header.ids.compactMap { at[$0] }.reduce(CGRect.null) { $0.union(strokes[$1].bounds) }
    return box.isNull ? nil : box
  }

  public struct Row: Equatable, Sendable {
    public var header: String?
    /// Its strokes' names when it is no header: a group or a kept text is no header's ink.
    public var names: [String]
    public var top: CGFloat
    public var bottom: CGFloat
  }

  /// The row of ink at `y`, within half a line.
  public func row(at y: CGFloat) -> Row? {
    let us = units()
    guard
      let r = BoardRoom.rows(us.map(\.bounds)).first(where: {
        y >= $0.lowerBound - Self.line / 2 && y <= $0.upperBound + Self.line / 2
      })
    else { return nil }
    let inside = us.filter { $0.bounds.minY >= r.lowerBound && $0.bounds.maxY <= r.upperBound }
    if let header = inside.compactMap(\.header).first {
      return Row(header: header, names: [], top: r.lowerBound, bottom: r.upperBound)
    }
    // cockpit-gvv: one line of his writing, the one at y. A descender grazing the line below chains the two into one
    // room row (BoardRoom.rows), but a header is the line he tapped beside, not the paragraph.
    let mine = inside.filter(his)
    guard let line = Self.line(of: mine, at: y) else {
      return Row(header: nil, names: [], top: r.lowerBound, bottom: r.upperBound)
    }
    // its underline stays part of it, as the row's always was
    let unders = mine.filter { u in
      !line.contains { $0.members == u.members } && u.members.count == 1 && Self.isUnderline(strokes[u.members[0]])
        && Self.underlineOf(u.bounds, line.reduce(CGRect.null) { $0.union($1.bounds) })
    }
    let chosen = line + unders
    let box = chosen.reduce(CGRect.null) { $0.union($1.bounds) }
    return Row(header: nil, names: names(chosen.flatMap(\.members)), top: box.minY, bottom: box.maxY)
  }

  /// Units on one line of writing: one line while a unit overlaps it by a good part of the smaller height (the
  /// writingLines rule), so a descender grazing the next line doesn't chain the two.
  static func lines(_ us: [Unit]) -> [[Unit]] {
    var out: [(box: CGRect, us: [Unit])] = []
    for u in us.sorted(by: { $0.bounds.minY < $1.bounds.minY }) {
      let overlap = { (b: CGRect) in min(b.maxY, u.bounds.maxY) - max(b.minY, u.bounds.minY) }
      var best: Int?
      for (i, l) in out.enumerated() where overlap(l.box) >= 0.4 * min(u.bounds.height, l.box.height) {
        if best.map({ overlap(l.box) > overlap(out[$0].box) }) ?? true { best = i }
      }
      if let best {
        out[best].box = out[best].box.union(u.bounds)
        out[best].us.append(u)
      } else {
        out.append((u.bounds, [u]))
      }
    }
    // A flat mark (an i's dot, a bar, an underline that wanders) is no line of its own: it joins the nearest line it
    // touches or nearly touches, the one above on a tie.
    let flat = { (l: (box: CGRect, us: [Unit])) in l.box.height < Self.line / 2 }
    var lines = out.filter { !flat($0) }
    for f in out.filter(flat) {
      let gap = { (b: CGRect) in max(0, max(b.minY - f.box.maxY, f.box.minY - b.maxY)) }
      if let i = lines.indices.min(by: { gap(lines[$0].box) < gap(lines[$1].box) }), gap(lines[i].box) <= Self.line / 4 {
        lines[i].box = lines[i].box.union(f.box)
        lines[i].us += f.us
      } else {
        lines.append(f)
      }
    }
    return lines.map(\.us)
  }

  /// The line of `us` at y: the one whose box holds y (the nearest middle when two do), else the nearest.
  static func line(of us: [Unit], at y: CGFloat) -> [Unit]? {
    let ls = lines(us).map { l in (us: l, box: l.reduce(CGRect.null) { $0.union($1.bounds) }) }
    let dist = { (b: CGRect) in y < b.minY ? b.minY - y : y > b.maxY ? y - b.maxY : 0 }
    return ls.min { a, b in
      let (da, db) = (dist(a.box), dist(b.box))
      return da != db ? da < db : abs(a.box.midY - y) < abs(b.box.midY - y)
    }?.us
  }

  /// Below the header's line: under it, or reaching up into it by less than a good part of the smaller height (a line
  /// the header's descender touches is the next line, cockpit-gvv).
  static func below(_ u: CGRect, _ hb: CGRect) -> Bool {
    if u.minY >= hb.maxY { return true }
    let overlap = min(u.maxY, hb.maxY) - max(u.minY, hb.minY)
    return u.midY > hb.maxY && overlap < 0.4 * min(u.height, hb.height)
  }

  /// The header showing whose row a margin tap at `y` is on, or whose ▾ it is within reach of (#1004).
  public func header(at y: CGFloat) -> BoardHeader? {
    headers.first { header in
      guard shows(header), let box = box(header) else { return false }
      return (y >= box.minY - Self.tapReach && y <= box.maxY + Self.tapReach) || onMark(header, y: y)
    }
  }

  /// The row at `y` made a header named `id`; false when it is blank paper, already one, or not Igor's ink.
  @discardableResult
  public mutating func markHeader(at y: CGFloat, id: String) -> Bool {
    guard let row = row(at: y), row.header == nil, !row.names.isEmpty else { return false }
    add(BoardHeader(id: id, ids: row.names))
    return true
  }

  /// A header made, by a margin tap, the menu or a mark in ink: its line is no longer declined (story 1034).
  mutating func add(_ header: BoardHeader) {
    headers.append(header)
    declined.subtract(header.ids)
  }

  /// Story 1034, *Not a header*: no longer a header, and its line never offered as one again.
  public mutating func decline(_ id: String) {
    guard let header = header(id) else { return }
    declined.formUnion(header.ids)
    unmark(id)
  }

  /// No longer a header; folded, it opens first.
  public mutating func unmark(_ id: String) {
    unfold(id)
    headers.removeAll { $0.id == id }
  }

  struct Section {
    var header: CGRect
    var body: [Unit]
    var after: [Unit]
  }

  /// A section, by indent: the header's row down to the first line whose ink starts at or left of the header's own
  /// left edge (within half a line), or to the next header at the same indent or shallower, whichever comes first.
  /// Blank paper never ends one. A header whose next line isn't indented runs to the next header at its indent.
  /// A rule drawn across the page ends it too, whatever its indent (#967), and so does ink written under the header
  /// while it was folded (story 1231).
  func section(_ id: String) -> Section? {
    guard let header = header(id), let hb = box(header) else { return nil }
    let us = units()
    let all = us.filter { $0.header != id && Self.below($0.bounds, hb) }
    // The indent is the header's writing, not an underline that overshoots it.
    let at = index
    let words = header.ids.compactMap { at[$0] }.filter { !Self.isUnderline(strokes[$0]) }
    let left = words.isEmpty ? hb.minX : words.reduce(CGRect.null) { $0.union(strokes[$1].bounds) }.minX
    let edge = left + Self.indentTolerance
    // the rows of what is below alone: the header's descender no longer chains the first line into its own row
    let lines = BoardRoom.rows(all.map(\.bounds)).map { r in
      (top: r.lowerBound, us: all.filter { $0.bounds.minY >= r.lowerBound && $0.bounds.maxY <= r.upperBound })
    }.filter { !$0.us.isEmpty }
    let leftOf = { (us: [Unit]) in us.map(\.bounds.minX).min() ?? 0 }
    let indented = lines.first.map { leftOf($0.us) > edge } ?? false
    var nextTop = CGFloat.infinity
    let rules = rules()
    let isRule = { (u: Unit) in self.his(u) && u.members.contains(where: rules.contains) }
    // Levels by #s (#1034): a header of this level at or left of the indent ends the section, as one of a shallower
    // level does wherever it is; a deeper one never does, and once one has begun, the indent no longer ends it.
    let live = liveNames
    let levels = Dictionary(uniqueKeysWithValues: headers.map { ($0.id, $0.level(live)) })
    let mine = header.level(live)
    let levelOf = { (u: Unit) in u.header.flatMap { levels[$0] } ?? 1 }
    var deeper = false
    let ends = Set(header.ends ?? [])
    let isEnd = { (u: Unit) in u.members.contains { self.strokes[$0].ids.contains(where: ends.contains) } }
    for line in lines {
      if !ends.isEmpty, line.us.contains(where: isEnd) {
        nextTop = line.top
        break
      }
      let writing = line.us.filter { !isRule($0) }
      let heads = writing.filter { $0.header != nil }
      let shallowHeader = heads.contains {
        levelOf($0) < mine || (levelOf($0) == mine && $0.bounds.minX <= edge)
      }
      let sub = heads.contains { levelOf($0) > mine }
      if shallowHeader || (!deeper && !sub && indented && !writing.isEmpty && leftOf(writing) <= edge) {
        nextTop = line.top
        break
      }
      if let rule = line.us.filter(isRule).map(\.bounds.minY).min() {
        nextTop = rule
        break
      }
      if sub { deeper = true }
    }
    return Section(
      header: hb, body: all.filter { $0.bounds.minY < nextTop }, after: all.filter { $0.bounds.minY >= nextTop })
  }

  /// Fold: the body hides and stays with the header, and what is below slides up to sit a line or two under the
  /// header, in whole lines. False when there is nothing to fold.
  @discardableResult
  public mutating func fold(_ id: String) -> Bool {
    guard let at = headers.firstIndex(where: { $0.id == id }), !isFolded(headers[at]), shows(headers[at]),
      let section = section(id), !section.body.isEmpty
    else { return false }
    let top = section.header.maxY
    let nextTop = section.after.map(\.bounds.minY).min()
    let shift = nextTop.map { max(0, (($0 - top) / Self.line).rounded(.down) * Self.line - Self.line) } ?? 0
    for unit in section.after where shift > 0 { self.shift(unit, by: -shift) }
    let members = section.body.flatMap(\.members)
    let own = members.filter { !strokes[$0].hidden }
    for m in own { strokes[m].hidden = true }
    let bodyBottom = section.body.map(\.bounds.maxY).max() ?? top
    headers[at].fold = BoardHeader.Fold(
      ids: names(members), own: names(own), shift: shift,
      lines: max(1, Int(((bodyBottom - top) / Self.line).rounded())), bottom: bodyBottom - top)
    return true
  }

  /// Unfold: what is below slides back down and the body shows again. Anything written under the folded header lands
  /// after the body: the slide grows by whole lines so nothing is drawn over.
  @discardableResult
  public mutating func unfold(_ id: String) -> Bool { opening(id) != nil }

  /// Unfold, saying where: the header row's bottom, and how far everything from there down slid (#1013).
  package mutating func opening(_ id: String) -> (top: CGFloat, slide: CGFloat)? {
    guard let at = headers.firstIndex(where: { $0.id == id }), isFolded(headers[at]), let fold = headers[at].fold,
      let hb = box(headers[at])
    else { return nil }
    let top = hb.maxY
    let below = units().filter { $0.header != id && $0.bounds.minY >= top }
    let extra =
      below.map(\.bounds.minY).min().map {
        max(0, ((top + fold.bottom - ($0 + fold.shift)) / Self.line).rounded(.up)) * Self.line
      } ?? 0
    for unit in below where fold.shift + extra != 0 { shift(unit, by: fold.shift + extra) }
    let positions = index
    for name in fold.own { if let m = positions[name] { strokes[m].hidden = false } }
    headers[at].fold = nil
    // Story 1231: what was written under the folded header, landed after its lines, ends the section from now on;
    // only what the section would otherwise take, so an unfold with nothing new written changes no section.
    let tucked = Set(fold.ids)
    let new = (section(id)?.body ?? []).flatMap(\.members).filter { m in
      !strokes[m].ids.contains(where: tucked.contains)
    }
    if !new.isEmpty { headers[at].ends = (headers[at].ends ?? []) + names(new) }
    return (top, fold.shift + extra)
  }

  /// Folded, unfolded.
  @discardableResult
  public mutating func toggle(_ id: String) -> Bool {
    guard let header = header(id) else { return false }
    return isFolded(header) ? unfold(id) : fold(id)
  }

  func bottomUp() -> [String] {
    headers.compactMap { header in box(header).map { (header.id, $0.minY) } }.sorted { $0.1 > $1.1 }.map(\.0)
  }

  /// Every fold open: the lowest showing one each time, so a fold inside another opens once the outer one has.
  public mutating func unfoldAll() {
    while let id = bottomUp().first(where: { id in header(id).map { isFolded($0) && shows($0) } ?? false }) {
      guard unfold(id) else { break }
    }
  }

  /// Every header folded, the lowest first.
  public mutating func foldAll() {
    for id in bottomUp() { fold(id) }
  }

  /// Each header's level with everything open: 1 inside no other's section, 2 inside a level-1 one, and so on.
  public func levels() -> [String: Int] {
    var open = self
    open.unfoldAll()
    var parent: [String: String] = [:]
    // Top down: the innermost section holding a header is its parent.
    for id in open.bottomUp().reversed() {
      for unit in open.section(id)?.body ?? [] { if let inner = unit.header { parent[inner] = id } }
    }
    func level(_ id: String, _ seen: Set<String> = []) -> Int {
      guard let up = parent[id], !seen.contains(id) else { return 1 }
      return 1 + level(up, seen.union([id]))
    }
    return Dictionary(uniqueKeysWithValues: open.headers.map { ($0.id, level($0.id)) })
  }

  /// Outline-style: headers down to level `n` show and nothing deeper. Every header at level `n` folds, and so does
  /// a shallower one with no headers under it; a shallower one with headers under it stays open.
  public mutating func collapse(to n: Int) {
    let levels = levels()
    unfoldAll()
    let parents = Set(headers.filter { section($0.id)?.body.contains { $0.header != nil } ?? false }.map(\.id))
    for id in bottomUp() {
      guard let level = levels[id] else { continue }
      if level == n || (level < n && !parents.contains(id)) { fold(id) }
    }
  }

  // MARK: - What the board does, and what Larry is told

  /// The changes from `start` (the strokes this outline began from) as a plan for the canvas: each stroke's move and
  /// whether it hides or shows, and the pages the ink needs after.
  public func plan(from start: [BoardOps.Stroke], pages: Int, board: BoardPages = BoardPages()) -> BoardOps.Plan {
    var plan = BoardOps.Plan(pagesBefore: pages, pagesAfter: pages)
    plan.erase = erased
    for (i, (was, now)) in zip(start, strokes).enumerated() where !erased.contains(i) {
      let dx = now.bounds.minX - was.bounds.minX
      let dy = now.bounds.minY - was.bounds.minY
      if dx != 0 || dy != 0 { plan.offsets[i] = CGVector(dx: dx, dy: dy) }
      if was.hidden != now.hidden { plan.hidden[i] = now.hidden }
    }
    plan.moved = plan.offsets.count
    let kept = strokes.indices.filter { !erased.contains($0) }.map { strokes[$0].bounds.maxY }
    plan.pagesAfter = board.pages(after: pages, inkMaxY: kept.max(), redoWaiting: false)
    return plan
  }

  /// The strokes folds hide, by name: never sent as strokes, as the Cockpit has them under `folds`.
  public var foldedNames: Set<String> { Set(headers.filter(isFolded).flatMap { $0.fold?.own ?? [] }) }

  /// The folds as the Cockpit's strokes snapshot takes them: `[{header, header_strokes, lines, strokes}]`.
  public var wire: [[String: Any]] {
    let live = Set(strokes.flatMap(\.ids))
    return headers.filter(isFolded).map { header in
      [
        "header": header.id, "header_strokes": header.ids.filter(live.contains), "lines": header.fold?.lines ?? 0,
        "strokes": (header.fold?.own ?? []).filter(live.contains),
      ]
    }
  }

  // MARK: - Lines that look like headers

  public static let bigLine: CGFloat = 1.5
  public static let bigLetter: CGFloat = 1.6
  public static let fewestStrokes = 3
  public static let fewestLines = 4

  public struct Candidate: Equatable, Sendable {
    public enum Why: String, Sendable { case big, underline }
    public var y: CGFloat
    public var box: CGRect
    public var why: Why
  }

  struct WritingLine {
    var box: CGRect
    var members: [Int]
    var heights: [CGFloat]
    var header = false
    var letter: CGFloat = 0
  }

  /// A long, flat, straight stroke: an underline.
  static func isUnderline(_ s: BoardOps.Stroke) -> Bool {
    let b = s.bounds
    let pen = s.pen > 0 ? s.pen : 4
    guard b.width >= 60, b.height - pen <= b.width * 0.12, let a = s.points.first, let z = s.points.last else {
      return false
    }
    let path = zip(s.points, s.points.dropFirst()).reduce(CGFloat(0)) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    return path <= 1.1 * hypot(z.x - a.x, z.y - a.y)
  }

  /// An underline's box `u` under the line `l`, across most of it.
  static func underlines(_ u: CGRect, _ l: CGRect) -> Bool {
    let mid = u.midY
    let span = min(u.maxX, l.maxX) - max(u.minX, l.minX)
    return mid >= l.maxY - l.height * 0.35 && mid <= l.maxY + line * 0.6 && span >= l.width * 0.7
  }

  private static func median(_ xs: [CGFloat]) -> CGFloat? {
    guard !xs.isEmpty else { return nil }
    let a = xs.sorted()
    let m = a.count / 2
    return a.count % 2 == 1 ? a[m] : (a[m - 1] + a[m]) / 2
  }

  /// His lines of writing, top down: his own strokes showing (not Larry's groups or texts), underlines left out.
  func writingLines() -> [WritingLine] {
    let inHeader = Set(headers.flatMap(\.ids))
    let tagged = tagged
    let boxes = strokes.indices.filter {
      !strokes[$0].hidden && !strokes[$0].points.isEmpty && !tagged.contains($0) && !Self.isUnderline(strokes[$0])
    }.map { ($0, strokes[$0].bounds, strokes[$0].bounds.height - (strokes[$0].pen > 0 ? strokes[$0].pen : 4)) }
      .sorted { $0.1.minY < $1.1.minY }
    var out: [WritingLine] = []
    for (m, box, h) in boxes {
      // One line while the stroke overlaps it by a good part of its own height: a descender grazing the next line
      // doesn't chain the two.
      let overlap = { (l: WritingLine) in min(l.box.maxY, box.maxY) - max(l.box.minY, box.minY) }
      var best: Int?
      for (i, l) in out.enumerated() where overlap(l) >= 0.4 * min(h, l.box.height) {
        if best.map({ overlap(l) > overlap(out[$0]) }) ?? true { best = i }
      }
      if let best {
        out[best].box = out[best].box.union(box)
        out[best].members.append(m)
        out[best].heights.append(h)
      } else {
        out.append(WritingLine(box: box, members: [m], heights: [h]))
      }
    }
    for i in out.indices {
      out[i].header = out[i].members.contains { strokes[$0].ids.contains(where: inHeader.contains) }
      out[i].letter = Self.median(out[i].heights.filter { $0 >= 6 }) ?? 0
    }
    return out
  }

  /// Lines that look like headers and aren't yet: written well bigger than his usual lines (once there are four to
  /// judge by), or underlined across most of their width. Derived, never kept.
  public func candidates() -> [Candidate] {
    let lines = writingLines()
    let mine = lines.filter { !$0.header && $0.letter > 0 }
    let usual = mine.count >= Self.fewestLines ? Self.median(mine.map(\.letter)) : nil
    let usualLine = mine.count >= Self.fewestLines ? Self.median(mine.map(\.box.height)) : nil
    let unders = strokes.filter { !$0.hidden && Self.isUnderline($0) }.map(\.bounds)
    var out: [Candidate] = []
    for l in lines where !l.header {
      let h = l.box.height
      let why: Candidate.Why?
      if let usual, let usualLine, h >= Self.bigLine * usualLine, l.letter >= Self.bigLetter * usual,
        l.members.count >= Self.fewestStrokes, l.box.width >= 2 * h
      {
        why = .big
      } else if unders.contains(where: { Self.underlineOf($0, l.box) }) {
        why = .underline
      } else {
        why = nil
      }
      guard let why, let row = row(at: l.box.midY), row.header == nil, !row.names.isEmpty,
        declined.isDisjoint(with: row.names)
      else { continue }
      out.append(Candidate(y: l.box.midY, box: l.box, why: why))
    }
    return out
  }

  // MARK: - The word under a held Pencil

  static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let l = dx * dx + dy * dy
    let t = l > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l)) : 0
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
  }

  /// What a Pencil held still at `point` picks up, by its strokes' names: a kept text, a group or a header row whole;
  /// a stroke with its neighbours on its line, chained while the gap between them is under a word gap. Nil off ink.
  public func word(at point: CGPoint, slop: CGFloat = 10) -> [String]? {
    let us = units()
    let near = { (u: Unit) -> Bool in
      if self.isText(u.tag) { return u.bounds.insetBy(dx: -slop, dy: -slop).contains(point) }
      return u.members.contains { m in
        let s = self.strokes[m]
        guard !s.hidden, let first = s.points.first else { return false }
        if s.points.count == 1 { return hypot(point.x - first.x, point.y - first.y) <= slop }
        return zip(s.points, s.points.dropFirst()).contains { Self.distance(point, $0.0, $0.1) <= slop }
      }
    }
    // Ink drawn over a text is what the Pencil is on: strokes first.
    guard let hit = us.first(where: { !isText($0.tag) && near($0) }) ?? us.first(where: { isText($0.tag) && near($0) })
    else { return nil }
    if isText(hit.tag) || hit.header != nil { return names(hit.members) }
    let mid = hit.bounds.midY
    let line = us.filter { $0.header == nil && !isText($0.tag) }
      .filter { $0.bounds.minY <= mid + Self.line / 4 && $0.bounds.maxY >= mid - Self.line / 4 }
      .sorted { $0.bounds.minX < $1.bounds.minX }
    var (left, right) = (hit.bounds.minX, hit.bounds.maxX)
    var grew = true
    while grew {
      grew = false
      for u in line where !(u.bounds.minX >= left && u.bounds.maxX <= right) {
        if u.bounds.minX - right < Self.wordGap, left - u.bounds.maxX < Self.wordGap {
          left = min(left, u.bounds.minX)
          right = max(right, u.bounds.maxX)
          grew = true
        }
      }
    }
    return names(line.filter { $0.bounds.minX >= left && $0.bounds.maxX <= right }.flatMap(\.members))
  }

  /// Story 947 (#947): the group a finger tapped at `point`, by its name and its strokes' names: the tap within `slop`
  /// of one of a group's strokes (a kept reply's, or one of Larry's own groups), and no other ink nearer. A text inside
  /// the group is the group's; a folded or header row, a bare text and his own writing are no group's. Nil off groups.
  public func group(at point: CGPoint, slop: CGFloat) -> (group: String, names: [String])? {
    guard let hit = nearest(at: point, slop: slop), let tag = hit.tag, Set(groups.values).contains(tag), !isText(tag)
    else { return nil }
    return (tag, names(hit.members))
  }

  /// #1171 (stories 1140–1142): the one thing of Larry's (or Claude's) a finger tapped at `point`, outside any group:
  /// every stroke made at the moment of the one tapped, when `theirs` lists that moment (a mark kept with Keep or Keep
  /// all, a text of his, a stroke he drew). Nil when his own ink is nearer, on a group's (story 947) or a header's, and
  /// off ink.
  public func theirs(at point: CGPoint, slop: CGFloat, moments theirs: Set<Int64>) -> (moment: Int64, names: [String])?
  {
    guard !theirs.isEmpty, let hit = nearest(at: point, slop: slop), hit.header == nil else { return nil }
    if let tag = hit.tag, Set(groups.values).contains(tag) { return nil }
    let nearestStroke = hit.members.min { inkDistance(point, strokes[$0]) < inkDistance(point, strokes[$1]) }
    guard let tapped = nearestStroke, let moment = strokes[tapped].t, theirs.contains(moment) else { return nil }
    // The whole of it: every loose stroke, or text, of that moment; none in a group, under a header or hidden.
    let members = units().filter { u in
      u.header == nil && !(u.tag.map(Set(groups.values).contains) ?? false)
    }.flatMap(\.members).filter { strokes[$0].t == moment && !strokes[$0].hidden }
    return members.isEmpty ? nil : (moment, names(members))
  }

  /// The thing that moves whole nearest `point`, within `slop` of a stroke's line (a text's box): the later in the
  /// outline's order between two as near (by each one's first stroke). Nil off ink.
  private func nearest(at point: CGPoint, slop: CGFloat) -> Unit? {
    var best: (unit: Unit, distance: CGFloat)?
    for u in units() {
      let d: CGFloat
      if isText(u.tag) {
        let box = u.bounds
        d = hypot(max(box.minX - point.x, 0, point.x - box.maxX), max(box.minY - point.y, 0, point.y - box.maxY))
      } else {
        d = u.members.map { inkDistance(point, strokes[$0]) }.min() ?? .infinity
      }
      if d <= slop, d <= (best?.distance ?? .infinity) { best = (u, d) }
    }
    return best?.unit
  }

  /// How far `point` is from a stroke's line; infinite for a hidden one.
  private func inkDistance(_ point: CGPoint, _ s: BoardOps.Stroke) -> CGFloat {
    guard !s.hidden, let first = s.points.first else { return .infinity }
    if s.points.count == 1 { return hypot(point.x - first.x, point.y - first.y) }
    return zip(s.points, s.points.dropFirst()).map { Self.distance(point, $0.0, $0.1) }.min() ?? .infinity
  }

  /// A Pencil stroke that is a hold and drag: still within `holdStill` of where it went down for `holdMs`, on a word.
  /// Its points in board points with their time since the stroke began, seconds. The word and how far it is dragged.
  public func pickUp(_ path: [(point: CGPoint, time: Double)]) -> (names: [String], by: CGVector)? {
    guard Self.isHold(path), let start = path.first, let end = path.last, let word = word(at: start.point) else {
      return nil
    }
    return (word, CGVector(dx: end.point.x - start.point.x, dy: end.point.y - start.point.y))
  }

  /// The stroke began still within `holdStill` of where it went down for `holdMs`, wherever it lies on the board.
  public static func isHold(_ path: [(point: CGPoint, time: Double)]) -> Bool {
    guard let start = path.first else { return false }
    let held = path.prefix { hypot($0.point.x - start.point.x, $0.point.y - start.point.y) <= holdStill }
    guard let last = held.last else { return false }
    return (last.time - start.time) * 1000 >= holdMs
  }
}
