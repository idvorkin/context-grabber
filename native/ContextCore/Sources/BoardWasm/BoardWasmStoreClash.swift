//  The shared-board store's clash rule, for the Cockpit (spec 2026-11-22-board-rules-on-the-web-design.md, The
//  interface, version 22; plan 2026-11-24-boards-in-the-cockpit-plan.md section 3; stories 1293, 1322, 1323).
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

  static func thing(_ json: Any?) -> BoardStoreClash.Thing? {
    guard let json = json as? [String: Any], let rev = (json["rev"] as? NSNumber)?.intValue,
      let author = author(json)
    else { return nil }
    return .init(rev: rev, author: author, erased: json["erased"] as? Bool ?? false)
  }

  static func wire(_ thing: BoardStoreClash.Thing) -> [String: Any] {
    var out: [String: Any] = [
      "rev": thing.rev, "device": thing.author.device, "by": thing.author.by, "at": thing.author.at,
    ]
    if thing.erased { out["erased"] = true }
    return out
  }

  /// `{"board": {"rev", "things": {id: thing}, "deleted"?: thing}, "base_rev", "device", "by", "at", "ops": [op]}`,
  /// a thing being `{"rev", "device", "by", "at", "erased"?}`: the answer `{rev, applied, refused, board}`.
  static func answer(_ json: Any?) -> [String: Any] {
    guard let json = json as? [String: Any], let boardJSON = json["board"] as? [String: Any],
      let rev = (boardJSON["rev"] as? NSNumber)?.intValue
    else { return ["error": "no board"] }
    guard let base = (json["base_rev"] as? NSNumber)?.intValue else { return ["error": "no base_rev"] }
    guard let author = author(json) else { return ["error": "no device"] }
    guard let ops = json["ops"] as? [Any] else { return ["error": "no ops"] }
    var board = BoardStoreClash.Board(rev: rev, deleted: thing(boardJSON["deleted"]))
    for (id, value) in boardJSON["things"] as? [String: Any] ?? [:] {
      if let thing = thing(value) { board.things[id] = thing }
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
