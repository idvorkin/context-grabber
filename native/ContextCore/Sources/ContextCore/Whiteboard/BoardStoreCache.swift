//  A drawing device's copy of a store board and its queue of unsent saves (spec 2026-11-22-boards-in-the-cockpit-design.md,
//  Offline: each device's copy and its unsent changes; plan 2026-11-24-boards-in-the-cockpit-plan.md section 7a;
//  stories 1301, 1330-1334; Larry's store spec, cockpit 2bf00b04, sections 3 and 6). A value the app keeps on disk and
//  drives: no network and no UI here. One batch is in flight at a time and frozen once sent; an answer folds in per id
//  from `refused`; a copy that is behind pulls, then checks its unsent saves with `BoardStoreClash` at its OLD base, so
//  no change goes up over a change it never saw.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public struct BoardStoreCache: Equatable, Sendable, Codable {
  public typealias Author = BoardStoreClash.Author

  /// One thing on the board as this device last saw it. An erased thing keeps its body, so `restore` brings it back.
  public struct Thing: Equatable, Sendable, Codable {
    public var body: BoardStoreJSON?
    public var kind: String?
    public var rev: Int
    public var author: Author
    public var erased: Bool

    public init(body: BoardStoreJSON?, kind: String? = nil, rev: Int, author: Author, erased: Bool = false) {
      self.body = body
      self.kind = kind
      self.rev = rev
      self.author = author
      self.erased = erased
    }
  }

  /// One save: the ops of one gesture or more. Frozen once it has a `batchID`: from then on it is sent as it is.
  public struct Batch: Equatable, Sendable, Codable {
    public var ops: [BoardStoreJSON]
    public var batchID: String?
    public var baseRev: Int?
    public var deviceAt: String?

    public init(ops: [BoardStoreJSON], batchID: String? = nil, baseRev: Int? = nil, deviceAt: String? = nil) {
      self.ops = ops
      self.batchID = batchID
      self.baseRev = baseRev
      self.deviceAt = deviceAt
    }

    /// `POST /boards/<id>/ops`'s body (store spec section 3).
    public func wire(device: String, by: String) -> BoardStoreJSON {
      var out: BoardStoreJSON = ["device": .string(device), "by": .string(by), "ops": .array(ops)]
      if let batchID { out["batch_id"] = .string(batchID) }
      if let baseRev { out["base_rev"] = .int(Int64(baseRev)) }
      if let deviceAt { out["device_at"] = .string(deviceAt) }
      return out
    }
  }

  /// A change that didn't land, for the copyable note: which thing, why, and who changed it when.
  public struct Note: Equatable, Sendable, Codable {
    public var id: String
    public var reason: String
    /// The op that was refused (`set`, `erase`, `rename`, …): what the note says didn't happen.
    public var kind: String
    public var rev: Int?
    public var author: Author?
    /// Refused on this device while catching up, not by the Cockpit.
    public var local: Bool
    /// New ink refused as already there goes up again under this name.
    public var readdedAs: String?
  }

  /// A save the Cockpit wouldn't take as sent: a copyable problem, never retried under a new name.
  public struct Problem: Equatable, Sendable, Codable {
    public var batchID: String
    public var status: Int
    public var error: String
  }

  public enum Outcome: Equatable, Sendable {
    /// The batch was answered and left the queue.
    case done
    /// Not looked at (`ok: false`, a non-200, no answer): it stays queued and frozen, to be sent again as it is.
    case keepQueued
    /// The Cockpit holds a different body under this batch's id: a copyable problem; the batch stays.
    case batchIDReused
  }

  public var boardID: String
  /// The base: the last revision whose ops this copy has all seen.
  public var rev: Int
  public var things: [String: Thing]
  /// Ids in draw order.
  public var order: [String]
  public var deleted: Thing?
  /// Oldest first; only the first may be frozen.
  public var queue: [Batch] = []
  /// The landed part of the device's own answered batch, shown until the pull brings it (not caught up).
  public var awaitingPull: [Batch] = []
  /// Ops refused because the board was deleted, until Igor keeps them as a new board or lets them go.
  public var setAside: [BoardStoreJSON] = []
  public var notes: [Note] = []
  public var problems: [Problem] = []
  public var needsPull = false
  public var needsReload = false

  /// From `GET /boards/<id>`: `{id, rev, deleted?, things: [{id, kind, ord, body, rev, device, by, at}], erased: [id]}`.
  public init(snapshot: BoardStoreJSON) {
    boardID = snapshot["id"]?.string ?? ""
    rev = 0
    things = [:]
    order = []
    load(snapshot)
  }

  // MARK: The queue

  /// A new save, made on top of what the device shows.
  public mutating func enqueue(_ ops: [BoardStoreJSON]) {
    guard !ops.isEmpty else { return }
    queue.append(Batch(ops: ops))
  }

  /// The batch to send now, frozen: the one in flight if there is one (the same id, body and base), else the oldest,
  /// given `batchID` and the current base. Write the cache to disk before sending. Nothing while a pull or a fresh
  /// download is owed.
  public mutating func freeze(batchID: String, deviceAt: String) -> Batch? {
    guard !needsPull, !needsReload, var first = queue.first else { return nil }
    if first.batchID == nil {
      first.batchID = batchID
      first.baseRev = rev
      first.deviceAt = deviceAt
      queue[0] = first
    }
    return first
  }

  /// The Cockpit's answer to the batch in flight.
  public mutating func receive(status: Int, answer: BoardStoreJSON, me: Author, slug: String) -> Outcome {
    guard let batch = queue.first, let batchID = batch.batchID, let base = batch.baseRev else { return .keepQueued }
    if status == 409 {
      let error = answer["error"]?.string ?? "conflict"
      problems.append(Problem(batchID: batchID, status: status, error: error))
      return .batchIDReused
    }
    guard status == 200, answer["ok"]?.bool == true, let answerRev = answer["rev"]?.int else { return .keepQueued }
    let refused = (answer["refused"]?.array ?? []).compactMap(Self.refusal)
    if refused.contains(where: { $0.reason == "ahead" }) {
      queue[0] = Batch(ops: batch.ops)  // landed nothing; it goes again, re-made, once the copy is fresh
      needsReload = true
      return .done
    }
    queue.removeFirst()
    let landed = settle(batch.ops, refused: refused, slug: slug)
    let applied = answer["applied"]?.array ?? []
    let caughtUp = applied.isEmpty ? answerRev == base : answerRev == base + 1
    if rev != base, answerRev <= rev {
      // A pull since the freeze already brought this batch and whatever landed over it (bead context-grabber-2m5r):
      // folding it in again would write this device's older bodies back over newer ones.
    } else if caughtUp, rev == base {
      for op in landed { apply(Self.landings(of: op, things: things), rev: answerRev, author: me) }
      rev = max(rev, answerRev)
    } else {
      if !landed.isEmpty { awaitingPull.append(Batch(ops: landed, batchID: batchID, baseRev: base)) }
      needsPull = true
    }
    return .done
  }

  // MARK: Catching up

  /// `GET /boards/<id>/ops?since=<rev>`'s batches, applied in order, then the unsent queue checked against them at the
  /// old base; after an admin batch the check waits for the fresh download. The batch in flight, if any, is never
  /// rebased.
  public mutating func pull(rev newRev: Int, batches: [BoardStoreJSON], slug: String = "") {
    let oldBase = rev
    let mine = Set((awaitingPull + queue.prefix(1)).compactMap(\.batchID))
    var foreign: [String: BoardStoreClash.Thing] = [:]
    var foreignDelete: BoardStoreClash.Thing?
    for batch in batches {
      if batch["kind"]?.string == "admin" {
        needsReload = true
        continue
      }
      guard let batchRev = batch["rev"]?.int else { continue }
      let author = Author(
        device: batch["device"]?.string ?? "", by: batch["by"]?.string ?? "", at: batch["at"]?.string ?? "")
      let own = batch["batch_id"]?.string.map(mine.contains) ?? false
      for op in batch["ops"]?.array ?? [] {
        let landings = Self.pulledLandings(of: op, things: things)
        apply(landings, rev: batchRev, author: author)
        guard !own else { continue }
        for landing in landings {
          if case .deleteBoard = landing.effect {
            foreignDelete = .init(rev: batchRev, author: author)
          } else {
            foreign[landing.id] = .init(rev: batchRev, author: author)
          }
        }
      }
    }
    awaitingPull = []
    needsPull = false
    rev = max(newRev, rev)
    guard !needsReload else { return }
    rebase(base: oldBase, foreign: foreign, foreignDelete: foreignDelete, slug: slug)
  }

  /// A fresh `GET /boards/<id>` after an `ahead` (or an admin batch): the copy is replaced, the unsent queue kept and
  /// checked against it.
  public mutating func reload(snapshot: BoardStoreJSON, slug: String = "") {
    things = [:]
    order = []
    deleted = nil
    awaitingPull = []
    load(snapshot)
    needsPull = false
    needsReload = false
    rebase(base: rev, foreign: [:], foreignDelete: nil, slug: slug)
  }

  // MARK: Deleted boards

  /// *Keep my ink as a new board*: `POST /boards`'s body and the set-aside ink as its first batch, at base 0.
  public mutating func keptInk(newID: String) -> (create: BoardStoreJSON, ops: [BoardStoreJSON])? {
    let ink = setAside.filter { Self.adding.contains($0["op"]?.string ?? "") }
    guard !ink.isEmpty else { return nil }
    let board = things[BoardStoreClash.boardID]?.body
    var create: BoardStoreJSON = [
      "id": .string(newID), "name": .string((board?["name"]?.string ?? "Board") + " (kept ink)"),
    ]
    if let paper = board?["paper"] { create["paper"] = paper }
    setAside = []
    return (create, ink)
  }

  public mutating func dismissSetAside() { setAside = [] }

  // MARK: What the device shows

  /// The copy with the device's own landed and unsent saves on top: what a board opens to.
  public var view: [String: Thing] {
    var copy = self
    for batch in awaitingPull + queue {
      for op in batch.ops {
        copy.apply(Self.landings(of: op, things: copy.things), rev: rev + 1, author: Author(device: "", by: "", at: ""))
      }
    }
    return copy.things
  }

  // MARK: Per id

  enum Effect: Equatable {
    case put(BoardStoreJSON)
    case erase
    case restore(BoardStoreJSON?)
    /// Its revision moves, its body stays (a group's members).
    case touch
    case deleteBoard
  }

  struct Landing: Equatable {
    var id: String
    var effect: Effect
    var kind: String?
  }

  static let adding: Set<String> = ["add_strokes", "add_text", "add_card", "overlay", "connector", "reply"]
  static let erasing: Set<String> = ["erase", "delete", "remove_overlay"]

  /// What a storage op (store spec section 3) does to each id it names.
  static func landings(of op: BoardStoreJSON, things: [String: Thing]) -> [Landing] {
    let kind = op["op"]?.string ?? ""
    var body = op
    body["op"] = nil
    let id = op["id"]?.string
    let ids = op["ids"]?.strings ?? []
    let named = { (key: String) in
      (op[key]?.array ?? []).compactMap { item in item["id"]?.string.map { Landing(id: $0, effect: .put(item)) } }
    }
    switch kind {
    case "add_strokes": return named("strokes").map { Landing(id: $0.id, effect: $0.effect, kind: "stroke") }
    case "add_text", "add_card", "overlay", "connector":
      return id.map {
        [Landing(id: $0, effect: .put(body), kind: String(kind.dropFirst(kind.hasPrefix("add_") ? 4 : 0)))]
      } ?? []
    case "reply": return (id.map { [Landing(id: $0, effect: .put(body), kind: "reply")] } ?? []) + named("marks")
    case "group", "header":
      return (id.map { [Landing(id: $0, effect: .put(body), kind: kind)] } ?? [])
        + ids.map { Landing(id: $0, effect: .touch) }
    case "set":
      return ids.map { Landing(id: $0, effect: op["bodies"]?[$0].map(Effect.put) ?? .touch) }
    case "replace":
      return ids.map { Landing(id: $0, effect: .erase) }
        + named("strokes").map { Landing(id: $0.id, effect: $0.effect, kind: "stroke") }
    case "restore": return ids.map { Landing(id: $0, effect: .restore(nil)) }
    case "rename", "paper":
      var board = things[BoardStoreClash.boardID]?.body ?? [:]
      for (key, value) in body.object ?? [:] { board[key] = value }
      return [Landing(id: BoardStoreClash.boardID, effect: .put(board), kind: "board")]
    case "delete_board": return [Landing(id: BoardStoreClash.boardID, effect: .deleteBoard)]
    case "select": return []
    default:
      let changed = ids.isEmpty ? (id.map { [$0] } ?? []) : ids
      return changed.map { Landing(id: $0, effect: erasing.contains(kind) ? .erase : .touch) }
    }
  }

  /// A pulled op, `{op, ids, bodies: {id: body after}}`: every landed id with its body, `null` for an erase; an id new
  /// to the copy takes its kind from the op (a reply's first id is the reply, the rest its marks).
  static func pulledLandings(of op: BoardStoreJSON, things: [String: Thing]) -> [Landing] {
    let name = op["op"]?.string ?? ""
    if name == "delete_board" { return [Landing(id: BoardStoreClash.boardID, effect: .deleteBoard)] }
    return (op["ids"]?.strings ?? []).enumerated().map { index, id in
      guard let body = op["bodies"]?[id], !body.isNull else { return Landing(id: id, effect: .erase) }
      let kind = things[id] == nil && (name != "reply" || index == 0) ? addedKind(name) : nil
      return Landing(id: id, effect: name == "restore" ? .restore(body) : .put(body), kind: kind)
    }
  }

  static func addedKind(_ name: String) -> String? {
    switch name {
    case "add_strokes", "replace": return "stroke"
    case "add_text", "add_card", "overlay", "connector", "group", "header", "reply":
      return String(name.dropFirst(name.hasPrefix("add_") ? 4 : 0))
    case "rename", "paper": return "board"
    default: return nil
    }
  }

  mutating func apply(_ landings: [Landing], rev: Int, author: Author) {
    for landing in landings {
      switch landing.effect {
      case .put(let body):
        if things[landing.id] == nil { order.append(landing.id) }
        things[landing.id] = Thing(
          body: body, kind: landing.kind ?? things[landing.id]?.kind, rev: rev, author: author)
      case .erase:
        if things[landing.id] == nil { order.append(landing.id) }
        var thing = things[landing.id] ?? Thing(body: nil, rev: rev, author: author)
        thing.erased = true
        thing.rev = rev
        thing.author = author
        things[landing.id] = thing
      case .restore(let body):
        guard var thing = things[landing.id] ?? body.map({ Thing(body: $0, rev: rev, author: author) }) else {
          continue
        }
        if things[landing.id] == nil { order.append(landing.id) }
        if let body { thing.body = body }
        thing.erased = false
        thing.rev = rev
        thing.author = author
        things[landing.id] = thing
      case .touch:
        guard things[landing.id] != nil else { continue }
        things[landing.id]?.rev = rev
        things[landing.id]?.author = author
      case .deleteBoard:
        deleted = Thing(body: nil, rev: rev, author: author)
      }
    }
  }

  // MARK: Refusals

  struct Refusal {
    var op: Int
    var id: String
    var reason: String
    var rev: Int?
    var author: Author?
  }

  static func refusal(_ json: BoardStoreJSON) -> Refusal? {
    guard let op = json["op"]?.int, let reason = json["reason"]?.string else { return nil }
    let author = json["device"]?.string.map {
      Author(device: $0, by: json["by"]?.string ?? "", at: json["at"]?.string ?? "")
    }
    return Refusal(op: op, id: json["id"]?.string ?? "", reason: reason, rev: json["rev"]?.int, author: author)
  }

  /// What became of one refused-or-not op: notes for its refusals; ink refused as `deleted` set aside; an op refused
  /// for any other reason lands nothing (the rule keeps an op whole). Otherwise it lands minus its adds refused
  /// `exists`, and those go up again under `<id>-<slug>`: as a new op when the op was already sent, renamed in place
  /// when it wasn't.
  mutating func settle(_ op: BoardStoreJSON, refused: [Refusal], local: Bool, slug: String)
    -> (landed: BoardStoreJSON?, readd: BoardStoreJSON?)
  {
    let kind = op["op"]?.string ?? ""
    var renamed: [String: String] = [:]
    for refusal in refused {
      let readd =
        refusal.reason == "exists" && Self.adding.union(["group", "header"]).contains(kind)
        ? Self.readdName(refusal.id, slug: slug) : nil
      if let readd { renamed[refusal.id] = readd }
      notes.append(
        Note(
          id: refusal.id, reason: refusal.reason, kind: kind, rev: refusal.rev, author: refusal.author,
          local: local, readdedAs: readd))
    }
    if refused.contains(where: { $0.reason == "deleted" }) {
      setAside.append(op)
      return (nil, nil)
    }
    if refused.contains(where: { $0.reason != "exists" }) { return (nil, nil) }
    if renamed.isEmpty { return (op, nil) }
    if local { return (Self.renaming(renamed, in: op, only: false), nil) }
    return (Self.without(Set(renamed.keys), in: op), Self.renaming(renamed, in: op, only: true))
  }

  static func readdName(_ id: String, slug: String) -> String { "\(id)-\(slug.isEmpty ? "again" : slug)" }

  /// `settle` over a sent batch's answer: the ops as they landed; re-adds queue next, behind nothing.
  mutating func settle(_ ops: [BoardStoreJSON], refused: [Refusal], slug: String) -> [BoardStoreJSON] {
    var landed: [BoardStoreJSON] = []
    var readds: [BoardStoreJSON] = []
    for (index, op) in ops.enumerated() {
      let result = settle(op, refused: refused.filter { $0.op == index }, local: false, slug: slug)
      if let op = result.landed { landed.append(op) }
      if let readd = result.readd { readds.append(readd) }
    }
    if !readds.isEmpty { queue.insert(Batch(ops: readds), at: 0) }
    return landed
  }

  /// The op as it landed with its adds in `ids` taken out: an `add_strokes`' strokes, a reply's marks, or an op's own id
  /// (a group's or header's members' change and a reply's other marks still land while its body doesn't).
  static func without(_ ids: Set<String>, in op: BoardStoreJSON) -> BoardStoreJSON {
    var out = op
    for key in ["strokes", "marks"] {
      if let items = op[key]?.array { out[key] = .array(items.filter { !ids.contains($0["id"]?.string ?? "") }) }
    }
    if let id = op["id"]?.string, ids.contains(id) { out["id"] = nil }
    return out
  }

  /// The op with its refused adds under new names: all of it (`only: false`), or just those adds (`only: true`, which
  /// never sends an own id that landed again).
  static func renaming(_ names: [String: String], in op: BoardStoreJSON, only: Bool) -> BoardStoreJSON {
    var out = op
    for key in ["strokes", "marks"] {
      guard let items = op[key]?.array else { continue }
      out[key] = .array(
        items.compactMap { item in
          guard let id = item["id"]?.string, let name = names[id] else { return only ? nil : item }
          var renamed = item
          renamed["id"] = .string(name)
          return renamed
        })
    }
    if let id = op["id"]?.string { out["id"] = names[id].map(BoardStoreJSON.string) ?? (only ? nil : op["id"]) }
    return out
  }

  /// The unsent queue through `BoardStoreClash` as one batch at `base`, against the copy's things: a thing a foreign
  /// pulled batch changed carries that batch's rev and author, every other thing at most `base` (the device's own
  /// landed ink doesn't clash with its own queue). A refused op leaves the queue with a note, so the view shows the
  /// pulled body. The batch in flight goes first, so later saves build on it, but is never rebased.
  mutating func rebase(
    base: Int, foreign: [String: BoardStoreClash.Thing], foreignDelete: BoardStoreClash.Thing?, slug: String
  ) {
    let start = queue.first?.batchID == nil ? 0 : 1
    guard start < queue.count else { return }
    var board = BoardStoreClash.Board(rev: max(rev, base))
    for (id, thing) in things {
      var clash = foreign[id] ?? .init(rev: min(thing.rev, base), author: thing.author)
      clash.erased = thing.erased
      board.things[id] = clash
    }
    if let deleted {
      board.deleted = foreignDelete ?? .init(rev: min(deleted.rev, base), author: deleted.author)
    }
    var flat: [(batch: Int, op: BoardStoreJSON)] = []
    for index in queue.indices { flat += queue[index].ops.map { (index, $0) } }
    let answer = BoardStoreClash.apply(
      flat.map { BoardStoreClash.Op(json: $0.op.any) }, to: board, base: base, author: .init(device: "", by: "", at: "")
    )
    let refused = answer.refused.filter { flat[$0.op].batch >= start }.map {
      Refusal(op: $0.op, id: $0.id, reason: $0.reason.rawValue, rev: $0.rev, author: $0.author)
    }
    guard !refused.isEmpty else { return }
    var rebuilt: [Int: [BoardStoreJSON]] = [:]
    for (index, entry) in flat.enumerated() where entry.batch >= start {
      let result = settle(entry.op, refused: refused.filter { $0.op == index }, local: true, slug: slug)
      if let op = result.landed { rebuilt[entry.batch, default: []].append(op) }
    }
    queue =
      Array(queue[..<start])
      + (start..<queue.count).compactMap { index in rebuilt[index].map { Batch(ops: $0) } }
  }

  // MARK: Loading

  mutating func load(_ snapshot: BoardStoreJSON) {
    rev = snapshot["rev"]?.int ?? 0
    for json in snapshot["things"]?.array ?? [] {
      guard let id = json["id"]?.string else { continue }
      order.append(id)
      things[id] = Thing(
        body: json["body"], kind: json["kind"]?.string, rev: json["rev"]?.int ?? 0,
        author: Author(device: json["device"]?.string ?? "", by: json["by"]?.string ?? "", at: json["at"]?.string ?? "")
      )
    }
    for id in snapshot["erased"]?.strings ?? [] where things[id] == nil {
      order.append(id)
      things[id] = Thing(body: nil, rev: 0, author: Author(device: "", by: "", at: ""), erased: true)
    }
    if let gone = snapshot["deleted"], gone != .bool(false), !gone.isNull {
      deleted = Thing(
        body: nil, rev: gone["rev"]?.int ?? rev,
        author: Author(device: gone["device"]?.string ?? "", by: gone["by"]?.string ?? "", at: gone["at"]?.string ?? "")
      )
    }
  }
}

extension BoardStoreClash.Author: Codable {
  enum CodingKeys: String, CodingKey { case device, by, at }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      device: try container.decode(String.self, forKey: .device), by: try container.decode(String.self, forKey: .by),
      at: try container.decode(String.self, forKey: .at))
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(device, forKey: .device)
    try container.encode(by, forKey: .by)
    try container.encode(at, forKey: .at)
  }
}
