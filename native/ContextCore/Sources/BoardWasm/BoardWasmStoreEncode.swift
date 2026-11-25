//  The shared-board store's one encoder, for the web board and the Cockpit (spec
//  2026-11-22-board-rules-on-the-web-design.md, Interface 23; stories 1299, 1300). `bw_store_encode` is
//  `BoardStoreEncode.encode` over a board before and after a commit. Only the export is WASI's; the answer builds
//  everywhere.

import BoardCore

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

enum WebStoreEncode {
  /// `{"before": board, "after": board, "erased"?: {id: record}}`: the answer `{ops, ignored}` or `{"error"}`.
  static func answer(_ json: Any?) -> [String: Any] {
    let json = json as? [String: Any] ?? [:]
    guard let before = json["before"] as? [String: Any] else { return ["error": "no before"] }
    guard let after = json["after"] as? [String: Any] else { return ["error": "no after"] }
    return BoardStoreEncode.encode(before: before, after: after, erased: json["erased"] as? [String: Any] ?? [:])
  }
}

#if os(WASI)
  /// A board before and after one commit, as a reply `{ops, ignored}` or `{"error"}`.
  @_expose(wasm, "bw_store_encode")
  @_cdecl("bw_store_encode")
  public func bwStoreEncode(_ pointer: UnsafeRawPointer?, _ length: Int32) -> UnsafeMutableRawPointer {
    let data = input(pointer, length)
    return reply(json: WebStoreEncode.answer(try? JSONSerialization.jsonObject(with: data)))
  }
#endif
