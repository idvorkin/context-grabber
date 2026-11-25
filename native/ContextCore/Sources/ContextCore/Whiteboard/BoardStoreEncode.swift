//  The shared-board store's one encoder (spec 2026-11-22-board-rules-on-the-web-design.md, Interface 23; stories 1299,
//  1300; cockpit-8kh). A device commits a whole new board; this turns the board before and after into the store's
//  storage ops, in an order `BoardStoreClash` accepts within one batch. Records go up whole, as the device holds them:
//  a field this build doesn't know is carried through, never dropped, so the web's pen data and the iPad's pencil seed
//  both survive the other side's edits. The web board calls it through the wasm, the iPad and the Mac natively.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

public enum BoardStoreEncode {
  /// The board fields the store keeps on `@board`: `rename` changes the name, `paper` the rest.
  static let paperFields = ["paper", "lines", "ruled"]
  /// The board's own fields that are not things and not kept on `@board`.
  static let thingLists = ["strokes", "objects", "headers", "connectors"]
  static let kept: Set<String> = Set(["v", "name"] + paperFields + thingLists)

  /// One thing of the web board's shape: which list it came from, and its record.
  struct Thing {
    var list: String
    var body: [String: Any]
  }

  /// `before` and `after` boards in the web board's shape, stored and unfolded, the erased records the device still
  /// holds for undo, and the gesture's `why` for its change: `{"ops": [op], "ignored": [field]}`, `ignored` naming the
  /// after's board fields the store doesn't keep, or `{"error"}` for a record without an id or an id used twice.
  public static func encode(
    before: [String: Any], after: [String: Any], erased: [String: Any] = [:], why: Any? = nil
  ) -> [String: Any] {
    let old: Board
    let new: Board
    do {
      old = try things(before)
      new = try things(after)
    } catch let error as Malformed {
      return ["error": "malformed record \(error.list)[\(error.index)]"]
    } catch {
      return ["error": "\(error)"]
    }
    var ops: [[String: Any]] = []

    // Brought back: restore every erased name the after has again (and wasn't on the before), then set those whose
    // record differs from what was erased.
    let back = new.order.filter { old.byID[$0] == nil && erased[$0] != nil }
    if !back.isEmpty {
      ops.append(["op": "restore", "ids": back])
      let differ = back.filter { !same(erased[$0], new.byID[$0]?.body) }
      if !differ.isEmpty { ops.append(set(differ, new)) }
    }
    var added = new.order.filter { old.byID[$0] == nil && erased[$0] == nil }
    var gone = old.order.filter { new.byID[$0] == nil }
    // Split: a stroke taken off whose pieces are new strokes named `<id>-<n>` is one replace, so a clash on the stroke
    // refuses its pieces too instead of doubling the ink.
    for id in gone where old.byID[id]?.list == "strokes" {
      let pieces = added.filter { piece in
        new.byID[piece]?.list == "strokes" && piece.hasPrefix(id + "-")
          && !piece.dropFirst(id.count + 1).isEmpty && piece.dropFirst(id.count + 1).allSatisfy(\.isNumber)
      }
      guard !pieces.isEmpty else { continue }
      ops.append(["op": "replace", "ids": [id], "strokes": pieces.compactMap { new.byID[$0]?.body }])
      gone.removeAll { $0 == id }
      added.removeAll { pieces.contains($0) }
    }
    // Taken off: one erase of every other name the after lacks.
    if !gone.isEmpty { ops.append(["op": "erase", "ids": gone]) }
    // Changed: one set of every name whose record differs, all or none, with the gesture's why.
    let changed = new.order.filter { id in old.byID[id].map { !same($0.body, new.byID[id]?.body) } ?? false }
    if !changed.isEmpty {
      var change = set(changed, new)
      if let why, !(why is NSNull) { change["why"] = why }
      ops.append(change)
    }
    // New: the strokes in draw order, then objects, groups, headers and connectors (they refer to what came before).
    let strokes = added.compactMap { id in new.byID[id].flatMap { $0.list == "strokes" ? $0.body : nil } }
    if !strokes.isEmpty { ops.append(["op": "add_strokes", "strokes": strokes]) }
    for pass in ["object", "group", "headers", "connectors"] {
      for id in added {
        guard let thing = new.byID[id], let op = addOp(thing), op.pass == pass else { continue }
        var out = thing.body
        out["op"] = op.name
        ops.append(out)
      }
    }
    // The board itself.
    if let name = after["name"], !same(before["name"], name) { ops.append(["op": "rename", "name": name]) }
    if paperFields.contains(where: { !same(before[$0], after[$0]) }) {
      var paper: [String: Any] = ["op": "paper"]
      for field in paperFields { paper[field] = after[field] }
      ops.append(paper)
    }
    return ["ops": ops, "ignored": after.keys.filter { !kept.contains($0) }.sorted()]
  }

  /// The op that adds `thing`, and which pass of the new ones it goes in.
  static func addOp(_ thing: Thing) -> (name: String, pass: String)? {
    switch thing.list {
    case "headers": return ("header", "headers")
    case "connectors": return ("connector", "connectors")
    case "objects":
      switch thing.body["kind"] as? String {
      case "group": return ("group", "group")
      case "text": return ("add_text", "object")
      case "question", "card": return ("add_card", "object")
      default: return ("overlay", "object")
      }
    default: return nil
    }
  }

  typealias Board = (order: [String], byID: [String: Thing])

  /// A record without a string id, or with an id another record already has.
  struct Malformed: Error {
    var list: String
    var index: Int
  }

  static func set(_ ids: [String], _ board: Board) -> [String: Any] {
    var bodies: [String: Any] = [:]
    for id in ids { bodies[id] = board.byID[id]?.body }
    return ["op": "set", "ids": ids, "bodies": bodies]
  }

  /// The names of a board's things, in draw order: what the store holds a row for (none for a malformed board).
  public static func thingIDs(_ board: [String: Any]) -> [String] { (try? things(board))?.order ?? [] }

  /// A board's things by id, in draw order (each list in turn, then its array order). A record without a string `id`
  /// can't be named in an op, and two records of one id can't both be stored: either is an error, never a skip.
  static func things(_ board: [String: Any]) throws -> Board {
    var order: [String] = []
    var byID: [String: Thing] = [:]
    for list in thingLists {
      for (index, item) in (board[list] as? [Any] ?? []).enumerated() {
        guard let body = item as? [String: Any], let id = body["id"] as? String, byID[id] == nil else {
          throw Malformed(list: list, index: index)
        }
        order.append(id)
        byID[id] = Thing(list: list, body: body)
      }
    }
    return (order, byID)
  }

  /// Two JSON values are the same when they serialize alike with sorted keys (numbers as their JSON reads).
  static func same(_ a: Any?, _ b: Any?) -> Bool {
    canonical(a) == canonical(b)
  }

  static func canonical(_ value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "null" }
    // A value JSON can't hold never compares equal to anything, so it always goes up rather than being skipped.
    guard let data = try? JSONSerialization.data(withJSONObject: ["v": value], options: [.sortedKeys]) else {
      return "unserializable \(UUID().uuidString)"
    }
    return String(decoding: data, as: UTF8.self)
  }
}
