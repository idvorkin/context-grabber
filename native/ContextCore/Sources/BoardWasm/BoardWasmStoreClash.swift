//  The shared-board store's clash rule, for the Cockpit (spec 2026-11-22-board-rules-on-the-web-design.md, The
//  interface, versions 22 and 23; plan 2026-11-24-boards-in-the-cockpit-plan.md section 3; stories 1293, 1322, 1323).
//  `bw_store_clash` is `BoardStoreClash.apply` over one batch and the board's per-thing revisions: what lands, what is
//  refused and why, and the board after it. Only the export is WASI's; the answer builds everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

enum WebStoreClash {
  static func author(_ json: Any?) -> BoardStoreClash.Author? {
    guard let json = json as? [String: Any], let device = json["device"] as? String else { return nil }
    return .init(device: device, by: json["by"] as? String ?? "", at: json["at"] as? String ?? "")
  }

  /// A thing row, or nil when it is malformed: no `rev`, no `device`, or an `erased` that is neither a boolean nor 0/1
  /// (a SQLite store sends 1). Interface 23 makes that an error rather than a dropped row, which would let its id be
  /// added twice.
  static func thing(_ json: Any?) -> BoardStoreClash.Thing? {
    guard let json = json as? [String: Any], let rev = JSONNumber(json["rev"])?.intValue,
      let author = author(json)
    else { return nil }
    var erased = false
    if let flag = json["erased"], !(flag is NSNull) {
      guard let number = JSONNumber(flag), number.doubleValue == 0 || number.doubleValue == 1 else { return nil }
      erased = number.doubleValue == 1
    }
    return .init(rev: rev, author: author, erased: erased)
  }

  static func wire(_ thing: BoardStoreClash.Thing) -> [String: Any] {
    var out: [String: Any] = [
      "rev": thing.rev, "device": thing.author.device, "by": thing.author.by, "at": thing.author.at,
    ]
    if thing.erased { out["erased"] = true }
    return out
  }

  /// `{"board": {"rev", "things": {id: thing}, "deleted"?: thing}, "base_rev", "device", "by", "at", "ops": [op]}`,
  /// a thing being `{"rev", "device", "by", "at", "erased"?}`: the answer `{rev, applied, landed, refused, board}`,
  /// or `{"error"}` naming a malformed thing.
  static func answer(_ json: Any?) -> [String: Any] {
    guard let json = json as? [String: Any], let boardJSON = json["board"] as? [String: Any],
      let rev = JSONNumber(boardJSON["rev"])?.intValue
    else { return ["error": "no board"] }
    guard let base = JSONNumber(json["base_rev"])?.intValue else { return ["error": "no base_rev"] }
    guard let author = author(json) else { return ["error": "no device"] }
    guard let ops = json["ops"] as? [Any] else { return ["error": "no ops"] }
    var board = BoardStoreClash.Board(rev: rev)
    if let deleted = boardJSON["deleted"], !(deleted is NSNull) {
      guard let thing = thing(deleted) else { return ["error": "malformed thing deleted"] }
      board.deleted = thing
    }
    for (id, value) in boardJSON["things"] as? [String: Any] ?? [:] {
      guard let thing = thing(value) else { return ["error": "malformed thing \(id)"] }
      board.things[id] = thing
    }
    let answer = BoardStoreClash.apply(ops.map(BoardStoreClash.Op.init(json:)), to: board, base: base, author: author)
    var out = answer.wire
    var after: [String: Any] = ["rev": answer.board.rev, "things": answer.board.things.mapValues(wire)]
    if let deleted = answer.board.deleted { after["deleted"] = wire(deleted) }
    out["board"] = after
    return out
  }
}

#if os(WASI)
  /// One batch against the board's revisions, as a reply `{rev, applied, refused, board}` or `{"error"}`.
  @_expose(wasm, "bw_store_clash")
  @_cdecl("bw_store_clash")
  public func bwStoreClash(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    let data = input(pointer, length)
    return reply(json: WebStoreClash.answer(try? JSONSerialization.jsonObject(with: data)))
  }
#endif
