import XCTest

@testable import ContextCore

/// Stories 1293, 1322 and 1323 (spec 2026-11-22-boards-in-the-cockpit-design.md, plan section 3): the shared-board
/// store's clash rule. Adds always land, once per id; a change lands only on what nobody changed since the batch's
/// base; nothing lands on a deleted board.
final class BoardStoreClashTests: XCTestCase {
  private let igorIPad = BoardStoreClash.Author(device: "ipad-air-11", by: "igor", at: "2026-11-24T21:00:00Z")
  private let web = BoardStoreClash.Author(device: "web", by: "igor", at: "2026-11-24T20:59:00Z")

  private func ops(_ json: String) throws -> [BoardStoreClash.Op] {
    let list = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [Any])
    return list.map(BoardStoreClash.Op.init(json:))
  }

  // Story 1293: an add lands, and an add of an id the board already has is refused as `exists`, out loud.
  func testAddsLandOncePerId() throws {
    var board = BoardStoreClash.Board(rev: 4)
    board.things["s-1"] = .init(rev: 2, author: web)
    let batch = try ops(
      #"[{"op":"add_strokes","strokes":[{"id":"s-1"},{"id":"s-2"}]},{"op":"add_text","id":"t-1","text":"hi"}]"#)
    let answer = BoardStoreClash.apply(batch, to: board, base: 1, author: igorIPad)
    XCTAssertEqual(answer.rev, 5)
    XCTAssertEqual(answer.applied, [0, 1])
    XCTAssertEqual(answer.refused, [.init(op: 0, id: "s-1", reason: .exists, rev: 2, author: web)])
    XCTAssertEqual(answer.board.things["s-2"]?.rev, 5)
    XCTAssertEqual(answer.board.things["t-1"]?.rev, 5)
    XCTAssertEqual(answer.board.things["s-1"]?.rev, 2, "a refused add leaves the thing as it was")
  }

  // Story 1293: a resend of the same batch, all ids already there, lands nothing and keeps the rev.
  func testAResentAddChangesNothing() throws {
    let batch = try ops(#"[{"op":"add_strokes","strokes":[{"id":"s-1"}]}]"#)
    let first = BoardStoreClash.apply(batch, to: .init(rev: 0), base: 0, author: igorIPad)
    let again = BoardStoreClash.apply(batch, to: first.board, base: 0, author: igorIPad)
    XCTAssertEqual(first.rev, 1)
    XCTAssertEqual(again.rev, 1)
    XCTAssertEqual(again.applied, [])
    XCTAssertEqual(again.refused.map(\.reason), [.exists])
  }

  // Story 1322: a change to something changed since the base is refused by name, with who changed it and when; the
  // rest of the batch still lands.
  func testAChangeSinceTheBaseIsRefusedByName() throws {
    var board = BoardStoreClash.Board(rev: 94)
    board.things["s-a"] = .init(rev: 94, author: web)
    board.things["s-b"] = .init(rev: 80, author: web)
    let batch = try ops(#"[{"op":"move","ids":["s-a"],"dx":4,"dy":0},{"op":"erase","ids":["s-b"]}]"#)
    let answer = BoardStoreClash.apply(batch, to: board, base: 92, author: igorIPad)
    XCTAssertEqual(answer.refused, [.init(op: 0, id: "s-a", reason: .changed, rev: 94, author: web)])
    XCTAssertEqual(answer.applied, [1])
    XCTAssertEqual(answer.rev, 95)
    XCTAssertEqual(answer.board.things["s-b"]?.erased, true)
    XCTAssertEqual(answer.board.things["s-a"]?.rev, 94)
  }

  // Story 1322: one op over several ids moves together or not at all.
  func testAnOpOverSeveralIdsIsRefusedWhole() throws {
    var board = BoardStoreClash.Board(rev: 10)
    board.things["s-a"] = .init(rev: 3, author: web)
    board.things["s-b"] = .init(rev: 9, author: web)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"move","ids":["s-a","s-b"],"dx":0,"dy":40}]"#), to: board, base: 5, author: igorIPad)
    XCTAssertEqual(answer.applied, [])
    XCTAssertEqual(answer.refused.map(\.id), ["s-b"])
    XCTAssertEqual(answer.rev, 10)
    XCTAssertEqual(answer.board.things["s-a"]?.rev, 3)
  }

  // Story 1322: a batch's own earlier ops don't clash with its later ones, and an unknown id is refused.
  func testABatchBuildsOnItselfAndAnUnknownIdIsRefused() throws {
    let batch = try ops(
      #"[{"op":"add_strokes","strokes":[{"id":"s-1"}]},{"op":"group","id":"g-1","ids":["s-1"],"owner":"igor"},"#
        + ##"{"op":"move","ids":["g-1"],"dx":1,"dy":1},{"op":"restyle","ids":["s-9"],"color":"#000"}]"##)
    let answer = BoardStoreClash.apply(batch, to: .init(rev: 7), base: 7, author: igorIPad)
    XCTAssertEqual(answer.applied, [0, 1, 2])
    XCTAssertEqual(answer.refused, [.init(op: 3, id: "s-9", reason: .unknown, rev: nil, author: nil)])
    XCTAssertEqual(answer.board.things["g-1"]?.rev, 8)
  }

  // Story 1322: renaming the board is a change like any other.
  func testRenameFollowsTheSameRule() throws {
    var board = BoardStoreClash.Board(rev: 3)
    board.things[BoardStoreClash.boardID] = .init(rev: 3, author: web)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"rename","name":"Plans"}]"#), to: board, base: 2, author: igorIPad)
    XCTAssertEqual(answer.refused.map(\.reason), [.changed])
    XCTAssertEqual(answer.refused.map(\.id), [BoardStoreClash.boardID])
  }

  // Story 1323: once the board is deleted, nothing lands on it, new ink included, and each refusal says when and
  // where it was deleted.
  func testNothingLandsOnADeletedBoard() throws {
    var board = BoardStoreClash.Board(rev: 12)
    board.deleted = .init(rev: 12, author: web)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"add_strokes","strokes":[{"id":"s-new"}]},{"op":"rename","name":"x"}]"#), to: board,
      base: 11, author: igorIPad)
    XCTAssertEqual(answer.applied, [])
    XCTAssertEqual(answer.rev, 12)
    XCTAssertEqual(
      answer.refused,
      [
        .init(op: 0, id: "s-new", reason: .deleted, rev: 12, author: web),
        .init(op: 1, id: BoardStoreClash.boardID, reason: .deleted, rev: 12, author: web),
      ])
  }

  // Story 1323: deleting the board is itself a change; once accepted, it marks the board deleted.
  func testDeleteBoardMarksItDeleted() throws {
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"delete_board"}]"#), to: .init(rev: 5), base: 5, author: igorIPad)
    XCTAssertEqual(answer.applied, [0])
    XCTAssertEqual(answer.board.deleted, .init(rev: 6, author: igorIPad))
  }

  // The answer's wire shape, as the Cockpit's endpoint and the web board read it (plan section 3).
  func testTheAnswerWire() throws {
    var board = BoardStoreClash.Board(rev: 2)
    board.things["s-a"] = .init(rev: 2, author: web)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"erase","ids":["s-a"]},{"op":"add_strokes","strokes":[{"id":"s-b"}]}]"#), to: board, base: 1,
      author: igorIPad)
    let wire = try JSONSerialization.data(withJSONObject: answer.wire, options: [.sortedKeys])
    XCTAssertEqual(
      String(decoding: wire, as: UTF8.self),
      #"{"applied":[1],"refused":[{"at":"2026-11-24T20:59:00Z","by":"igor","device":"web","id":"s-a","op":0,"#
        + #""reason":"changed","rev":2}],"rev":3}"#)
  }
}
