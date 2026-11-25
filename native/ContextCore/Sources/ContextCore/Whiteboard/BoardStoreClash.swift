//  The shared-board store's clash rule (spec 2026-11-22-boards-in-the-cockpit-design.md, plan
//  2026-11-24-boards-in-the-cockpit-plan.md section 3; stories 1293, 1322, 1323, bead context-grabber-t12b). A device
//  sends a batch of ops against the last revision it saw; this decides, per op, what lands. The Cockpit's store is the
//  authority and runs the same rule (`bw_store_clash` for the web board); a device runs it first so a refusal is rare
//  and explained. It needs only who last changed each thing, not what the ops do to the ink.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardStoreClash {
  /// The name a board-level op (rename, paper, delete_board) changes.
  public static let boardID = "@board"

  /// The ops that take what they change off the board, leaving its id taken.
  static let erasing: Set<String> = ["erase", "delete", "replace", "remove_overlay"]

  /// Where and by whom a change was made.
  public struct Author: Equatable, Sendable {
    public var device: String
    public var by: String
    public var at: String

    public init(device: String, by: String, at: String) {
      self.device = device
      self.by = by
      self.at = at
    }
  }

  /// The revision that last changed a thing, and who changed it.
  public struct Thing: Equatable, Sendable {
    public var rev: Int
    public var author: Author
    /// Erased: its id stays taken, so a later add of the same id is refused, not landed twice.
    public var erased: Bool

    public init(rev: Int, author: Author, erased: Bool = false) {
      self.rev = rev
      self.author = author
      self.erased = erased
    }
  }

  /// What the rule needs of a board: its revision, each thing's last change, and whether it was deleted.
  public struct Board: Equatable, Sendable {
    public var rev: Int
    public var things: [String: Thing]
    public var deleted: Thing?

    public init(rev: Int, things: [String: Thing] = [:], deleted: Thing? = nil) {
      self.rev = rev
      self.things = things
      self.deleted = deleted
    }

    /// Who deleted the board, however the store recorded it: `deleted`, or `@board` erased (interface 23).
    public var deletedBy: Thing? {
      deleted ?? things[BoardStoreClash.boardID].flatMap { $0.erased ? $0 : nil }
    }
  }

  public enum Reason: String, Sendable {
    /// Someone else changed it after the batch's base.
    case changed
    /// The board was deleted.
    case deleted
    /// An add of an id the board already has (a resend, or the same ink twice). Re-added ink takes a new id.
    case exists
    /// A change to something the board doesn't have, or an op that names nothing to check.
    case unknown
    /// The batch is based on a revision the board hasn't reached: another board's, or a broken cache.
    case ahead
  }

  public struct Refusal: Equatable, Sendable {
    public var op: Int
    public var id: String
    public var reason: Reason
    /// When the change that blocks it was made, and by whom; nil for `unknown`.
    public var rev: Int?
    public var author: Author?

    public init(op: Int, id: String, reason: Reason, rev: Int?, author: Author?) {
      self.op = op
      self.id = id
      self.reason = reason
      self.rev = rev
      self.author = author
    }
  }

  /// One op as the rule sees it: the ids it creates and the ids it changes.
  public struct Op: Equatable, Sendable {
    public var kind: String
    public var adds: [String]
    public var changes: [String]
    /// The device's own (a selection): changes nothing on the board, so it neither lands nor is refused.
    public var local: Bool

    public init(kind: String, adds: [String], changes: [String], local: Bool = false) {
      self.kind = kind
      self.adds = adds
      self.changes = changes
      self.local = local
    }

    /// Reads an op of the plan's op set (section 4) or of Larry's existing batches. Adds name their new ids
    /// (`add_strokes`' strokes, `add_text`/`add_card`/`overlay`/`connector`'s id, a group's or reply's own id and a
    /// reply's marks; a connector's ends are only referred to); `replace` changes its ids and adds its strokes;
    /// `restore` brings erased names back; board-level ops change the board; `select` is the device's own; every
    /// other op changes its `ids` (or its `id`).
    public init(json: Any) {
      let op = json as? [String: Any] ?? [:]
      let kind = op["op"] as? String ?? ""
      let id = op["id"] as? String
      let ids = (op["ids"] as? [Any])?.compactMap { $0 as? String } ?? []
      let named = { (key: String) in
        ((op[key] as? [Any]) ?? []).compactMap { ($0 as? [String: Any])?["id"] as? String }
      }
      switch kind {
      case "add_strokes": self.init(kind: kind, adds: named("strokes"), changes: [])
      case "add_text", "add_card", "overlay", "connector":
        self.init(kind: kind, adds: id.map { [$0] } ?? [], changes: [])
      case "replace": self.init(kind: kind, adds: named("strokes"), changes: ids)
      case "select": self.init(kind: kind, adds: [], changes: [], local: true)
      case "group", "header": self.init(kind: kind, adds: id.map { [$0] } ?? [], changes: ids)
      case "reply": self.init(kind: kind, adds: (id.map { [$0] } ?? []) + named("marks"), changes: [])
      case "rename", "paper", "delete_board": self.init(kind: kind, adds: [], changes: [BoardStoreClash.boardID])
      default: self.init(kind: kind, adds: [], changes: ids.isEmpty ? (id.map { [$0] } ?? []) : ids)
      }
    }
  }

  /// The ids one op landed, its adds first and then its changes (interface 23): the store applies from these, never
  /// from `applied` alone, since a group whose own id `exists` still lands its strokes' change.
  public struct Landed: Equatable, Sendable {
    public var op: Int
    public var ids: [String]

    public init(op: Int, ids: [String]) {
      self.op = op
      self.ids = ids
    }
  }

  /// What a batch did: the board's new revision, the ops that landed, and why the rest didn't.
  public struct Answer: Equatable, Sendable {
    public var rev: Int
    public var applied: [Int]
    public var refused: [Refusal]
    public var landed: [Landed] = []
    public var board: Board

    /// `{rev, applied, landed: [{op, ids}], refused: [{op, id, reason, rev?, device?, by?, at?}], missing_ids}` (plan
    /// section 3); `missing_ids` names the `unknown` ones the way the Cockpit's batch contract does.
    public var wire: [String: Any] {
      [
        "rev": rev, "applied": applied, "landed": landed.map { ["op": $0.op, "ids": $0.ids] as [String: Any] },
        "missing_ids": refused.filter { $0.reason == .unknown && !$0.id.isEmpty }.map(\.id),
        "refused": refused.map { refusal -> [String: Any] in
          var out: [String: Any] = ["op": refusal.op, "id": refusal.id, "reason": refusal.reason.rawValue]
          if let rev = refusal.rev { out["rev"] = rev }
          if let author = refusal.author {
            out["device"] = author.device
            out["by"] = author.by
            out["at"] = author.at
          }
          return out
        },
      ]
    }
  }

  /// Applies `ops`, a batch made against revision `base`, by `author`. Adds land once per id; a change lands when
  /// every id it names was last changed at or before `base` (or by this same batch); one op's ids land together; and
  /// nothing lands on a deleted board. An accepted batch is one new revision.
  public static func apply(_ ops: [Op], to board: Board, base: Int, author: Author) -> Answer {
    var next = board
    let rev = board.rev + 1
    var applied: [Int] = []
    var refused: [Refusal] = []
    var landedIDs: [Landed] = []
    var mine: Set<String> = []  // ids this batch added or changed: its own later ops build on them

    for (index, op) in ops.enumerated() where !op.local {
      if base > board.rev {
        let ids = op.adds + op.changes
        for id in ids.isEmpty ? [""] : ids {
          refused.append(Refusal(op: index, id: id, reason: .ahead, rev: board.rev, author: nil))
        }
        continue
      }
      if op.adds.isEmpty && op.changes.isEmpty {
        refused.append(Refusal(op: index, id: "", reason: .unknown, rev: nil, author: nil))
        continue
      }
      if let deleted = next.deletedBy {
        for id in op.adds + op.changes {
          refused.append(Refusal(op: index, id: id, reason: .deleted, rev: deleted.rev, author: deleted.author))
        }
        continue
      }
      var blocked: Refusal?
      for id in op.changes {
        guard let thing = next.things[id] ?? (id == boardID ? Thing(rev: 0, author: author) : nil) else {
          blocked = Refusal(op: index, id: id, reason: .unknown, rev: nil, author: nil)
          break
        }
        // An erased name changes only by `restore`, and `restore` only an erased one.
        let stale = thing.rev > base && !mine.contains(id)
        if stale || thing.erased != (op.kind == "restore") {
          if !thing.erased, !stale {
            blocked = Refusal(op: index, id: id, reason: .unknown, rev: nil, author: nil)
            break
          }
          blocked = Refusal(op: index, id: id, reason: .changed, rev: thing.rev, author: thing.author)
          break
        }
      }
      if let blocked {
        refused.append(blocked)
        continue
      }
      var ids: [String] = []
      for id in op.adds {
        if let thing = next.things[id] {
          refused.append(Refusal(op: index, id: id, reason: .exists, rev: thing.rev, author: thing.author))
          continue
        }
        next.things[id] = Thing(rev: rev, author: author)
        mine.insert(id)
        ids.append(id)
      }
      for id in op.changes {
        next.things[id] = Thing(rev: rev, author: author, erased: erasing.contains(op.kind))
        mine.insert(id)
        ids.append(id)
      }
      if op.kind == "delete_board" { next.deleted = Thing(rev: rev, author: author) }
      if !ids.isEmpty {
        applied.append(index)
        landedIDs.append(Landed(op: index, ids: ids))
      }
    }
    if applied.isEmpty { return Answer(rev: board.rev, applied: [], refused: refused, board: board) }
    next.rev = rev
    return Answer(rev: rev, applied: applied, refused: refused, landed: landedIDs, board: next)
  }
}
