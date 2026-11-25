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
    XCTAssertEqual(answer.wire["missing_ids"] as? [String], ["s-9"], "as the Cockpit's batch contract names them")
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

  // Larry's question 1: undo and redo restore erased ink under its own names with `restore`, which lands when nobody
  // changed those names after the erase the device saw; an add of an erased name is still refused.
  func testRestoreBringsBackErasedInkUnderItsNames() throws {
    var board = BoardStoreClash.Board(rev: 6)
    board.things["s-a"] = .init(rev: 5, author: igorIPad, erased: true)
    board.things["s-b"] = .init(rev: 6, author: web, erased: true)
    board.things["s-c"] = .init(rev: 2, author: web)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"restore","ids":["s-a"]},{"op":"restore","ids":["s-b"]},{"op":"restore","ids":["s-c"]}]"#),
      to: board, base: 5, author: igorIPad)
    XCTAssertEqual(answer.applied, [0])
    XCTAssertEqual(answer.refused.map(\.reason), [.changed, .unknown])
    XCTAssertEqual(answer.board.things["s-a"]?.erased, false)
    XCTAssertEqual(answer.board.things["s-a"]?.rev, 7)
  }

  // Larry's question 2: an op that names nothing (a `translate` by `below_y` alone) can't be checked, so it's refused;
  // the device sends the names it moves.
  func testAnOpThatNamesNothingIsRefused() throws {
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"translate","below_y":300,"dy":40}]"#), to: .init(rev: 1), base: 1, author: igorIPad)
    XCTAssertEqual(answer.applied, [])
    XCTAssertEqual(answer.refused, [.init(op: 0, id: "", reason: .unknown, rev: nil, author: nil)])
  }

  // Larry's question 4: select is the device's own and changes nothing; an overlay and a connector are new things (a
  // connector's ends are only referred to); replace changes its ids and adds its new strokes.
  func testLarrysOtherKinds() throws {
    var board = BoardStoreClash.Board(rev: 3)
    board.things["s-a"] = .init(rev: 1, author: web)
    board.things["s-b"] = .init(rev: 1, author: web)
    board.things["o-old"] = .init(rev: 1, author: web)
    let batch = try ops(
      #"[{"op":"select","ids":["s-a"]},{"op":"overlay","id":"o-1"},{"op":"remove_overlay","id":"o-old"},"#
        + #"{"op":"connector","id":"c-1","from":"s-a","to":"s-b"},"#
        + #"{"op":"replace","ids":["s-b"],"strokes":[{"id":"s-b2"}]}]"#)
    let answer = BoardStoreClash.apply(batch, to: board, base: 3, author: igorIPad)
    XCTAssertEqual(answer.applied, [1, 2, 3, 4])
    XCTAssertEqual(answer.refused, [])
    XCTAssertEqual(answer.board.things["s-a"]?.rev, 1, "select and a connector's ends change nothing")
    XCTAssertEqual(answer.board.things["c-1"]?.rev, 4)
    XCTAssertEqual(answer.board.things["s-b"]?.rev, 4)
    XCTAssertEqual(answer.board.things["s-b2"]?.rev, 4)
  }

  // Plan section 3: replace and remove_overlay take their ids off the board as erase does, so undo restores them and
  // nothing else changes them.
  func testReplaceAndRemoveOverlayLeaveATombstone() throws {
    var board = BoardStoreClash.Board(rev: 3)
    board.things["s-b"] = .init(rev: 1, author: web)
    board.things["o-old"] = .init(rev: 1, author: web)
    let first = BoardStoreClash.apply(
      try ops(#"[{"op":"replace","ids":["s-b"],"strokes":[{"id":"s-b2"}]},{"op":"remove_overlay","id":"o-old"}]"#),
      to: board, base: 3, author: igorIPad)
    XCTAssertEqual(first.board.things["s-b"]?.erased, true)
    XCTAssertEqual(first.board.things["o-old"]?.erased, true)
    XCTAssertEqual(first.board.things["s-b2"]?.erased, false)
    let undo = BoardStoreClash.apply(
      try ops(#"[{"op":"restore","ids":["s-b"]},{"op":"move","ids":["o-old"],"dx":1,"dy":0}]"#),
      to: first.board, base: 4, author: igorIPad)
    XCTAssertEqual(undo.applied, [0])
    XCTAssertEqual(undo.refused, [.init(op: 1, id: "o-old", reason: .changed, rev: 4, author: igorIPad)])
    XCTAssertEqual(undo.board.things["s-b"]?.erased, false)
  }

  // Plan section 3: within one batch, an erased name still changes only by restore, and restore only an erased one.
  func testABatchCantChangeWhatItErased() throws {
    var board = BoardStoreClash.Board(rev: 2)
    board.things["s-a"] = .init(rev: 1, author: web)
    board.things["s-c"] = .init(rev: 1, author: web)
    let answer = BoardStoreClash.apply(
      try ops(
        #"[{"op":"erase","ids":["s-a"]},{"op":"move","ids":["s-a"],"dx":4,"dy":0},{"op":"restore","ids":["s-a"]},"#
          + #"{"op":"move","ids":["s-c"],"dx":1,"dy":0},{"op":"restore","ids":["s-c"]}]"#),
      to: board, base: 2, author: igorIPad)
    XCTAssertEqual(answer.applied, [0, 2, 3])
    XCTAssertEqual(
      answer.refused,
      [
        .init(op: 1, id: "s-a", reason: .changed, rev: 3, author: igorIPad),
        .init(op: 4, id: "s-c", reason: .unknown, rev: nil, author: nil),
      ])
    XCTAssertEqual(answer.board.things["s-a"]?.erased, false)
  }

  // Story 1323: once a batch deletes the board, its later ops land nothing.
  func testNothingLandsAfterABatchDeletesTheBoard() throws {
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"delete_board"},{"op":"add_strokes","strokes":[{"id":"s-1"}]}]"#),
      to: .init(rev: 1), base: 1, author: igorIPad)
    XCTAssertEqual(answer.applied, [0])
    XCTAssertEqual(answer.refused, [.init(op: 1, id: "s-1", reason: .deleted, rev: 2, author: igorIPad)])
    XCTAssertNil(answer.board.things["s-1"])
  }

  // Larry's question 5: an op that names nothing is refused as `ahead` too, not dropped.
  func testABaseAheadRefusesAnOpThatNamesNothing() throws {
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"translate","below_y":300,"dy":40}]"#), to: .init(rev: 4), base: 9, author: igorIPad)
    XCTAssertEqual(answer.applied, [])
    XCTAssertEqual(answer.refused, [.init(op: 0, id: "", reason: .ahead, rev: 4, author: nil)])
  }

  // Larry's question 5: a batch based on a revision the board hasn't reached is from another board or a broken cache:
  // nothing lands, each op refused as `ahead`.
  func testABaseAheadOfTheBoardLandsNothing() throws {
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"add_strokes","strokes":[{"id":"s-1"}]}]"#), to: .init(rev: 4), base: 9, author: igorIPad)
    XCTAssertEqual(answer.applied, [])
    XCTAssertEqual(answer.rev, 4)
    XCTAssertEqual(answer.refused, [.init(op: 0, id: "s-1", reason: .ahead, rev: 4, author: nil)])
  }

  // Story 1326: a header is a new thing with its own name over the strokes it heads, like a group.
  func testAHeaderAddsItsIdAndChangesItsStrokes() throws {
    var board = BoardStoreClash.Board(rev: 3)
    board.things["s-1"] = .init(rev: 1, author: web)
    board.things["h-old"] = .init(rev: 2, author: web)
    let batch = try ops(#"[{"op":"header","id":"h-1","ids":["s-1"]},{"op":"header","id":"h-old","ids":["s-1"]}]"#)
    let answer = BoardStoreClash.apply(batch, to: board, base: 3, author: igorIPad)
    XCTAssertEqual(answer.applied, [0, 1])
    XCTAssertEqual(answer.refused, [.init(op: 1, id: "h-old", reason: .exists, rev: 2, author: web)])
    XCTAssertEqual(answer.landed, [.init(op: 0, ids: ["h-1", "s-1"]), .init(op: 1, ids: ["s-1"])])
    XCTAssertEqual(answer.board.things["h-1"]?.rev, 4)
  }

  // Story 1328: a group whose own name exists lands only its strokes' change, and says so per id; a wholly refused op
  // is absent from `landed`; an add of three with one already there lands two.
  func testLandedNamesExactlyWhatLanded() throws {
    var board = BoardStoreClash.Board(rev: 5)
    board.things["s-1"] = .init(rev: 1, author: web)
    board.things["s-2"] = .init(rev: 5, author: web)
    board.things["g-1"] = .init(rev: 2, author: web)
    let batch = try ops(
      #"[{"op":"group","id":"g-1","ids":["s-1"]},{"op":"erase","ids":["s-2"]},"#
        + #"{"op":"add_strokes","strokes":[{"id":"s-3"},{"id":"s-1"},{"id":"s-4"}]}]"#)
    let answer = BoardStoreClash.apply(batch, to: board, base: 3, author: igorIPad)
    XCTAssertEqual(answer.applied, [0, 2])
    XCTAssertEqual(answer.landed, [.init(op: 0, ids: ["s-1"]), .init(op: 2, ids: ["s-3", "s-4"])])
  }

  // Story 1322 (interface 23): `set` over several ids is one op, all or none.
  func testASetOverSeveralIdsLandsWhole() throws {
    var board = BoardStoreClash.Board(rev: 9)
    board.things["s-1"] = .init(rev: 1, author: web)
    board.things["s-2"] = .init(rev: 9, author: web)
    board.things["s-3"] = .init(rev: 1, author: web)
    let batch = try ops(
      #"[{"op":"set","ids":["s-1","s-2"],"bodies":{"s-1":{},"s-2":{}}},{"op":"set","ids":["s-3"],"bodies":{"s-3":{}}}]"#
    )
    let answer = BoardStoreClash.apply(batch, to: board, base: 8, author: igorIPad)
    XCTAssertEqual(answer.applied, [1])
    XCTAssertEqual(answer.refused, [.init(op: 0, id: "s-2", reason: .changed, rev: 9, author: web)])
    XCTAssertEqual(answer.board.things["s-1"]?.rev, 1, "the clash on s-2 keeps s-1 as it was")
    XCTAssertEqual(answer.landed, [.init(op: 1, ids: ["s-3"])])
  }

  // Story 1327: a board whose `@board` is erased is deleted: adds and restores are refused as `deleted`, with
  // `@board`'s change.
  func testAnErasedBoardEntryMeansDeleted() throws {
    var board = BoardStoreClash.Board(rev: 7)
    board.things[BoardStoreClash.boardID] = .init(rev: 7, author: web, erased: true)
    board.things["s-a"] = .init(rev: 3, author: igorIPad, erased: true)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"add_strokes","strokes":[{"id":"s-n"}]},{"op":"restore","ids":["s-a"]}]"#), to: board, base: 7,
      author: igorIPad)
    XCTAssertEqual(answer.applied, [])
    XCTAssertEqual(answer.rev, 7)
    XCTAssertEqual(
      answer.refused,
      [
        .init(op: 0, id: "s-n", reason: .deleted, rev: 7, author: web),
        .init(op: 1, id: "s-a", reason: .deleted, rev: 7, author: web),
      ])
  }

  // Story 1327: `deleted` with a live `@board` is still deleted, and `delete_board` leaves `@board` live (the store
  // keeps `deleted` as the truth).
  func testDeletedWithALiveBoardEntryIsDeleted() throws {
    var board = BoardStoreClash.Board(rev: 4, deleted: .init(rev: 4, author: web))
    board.things[BoardStoreClash.boardID] = .init(rev: 2, author: web)
    let answer = BoardStoreClash.apply(
      try ops(#"[{"op":"restore","ids":["s-a"]}]"#), to: board, base: 4, author: igorIPad)
    XCTAssertEqual(answer.refused.map(\.reason), [.deleted])
    let deleting = BoardStoreClash.apply(
      try ops(#"[{"op":"delete_board"}]"#), to: .init(rev: 1), base: 1, author: igorIPad)
    XCTAssertEqual(deleting.board.things[BoardStoreClash.boardID]?.erased, false)
    XCTAssertNotNil(deleting.board.deleted)
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
      #"{"applied":[1],"landed":[{"ids":["s-b"],"op":1}],"missing_ids":[],"refused":[{"at":"2026-11-24T20:59:00Z","by":"igor","device":"web","#
        + #""id":"s-a","op":0,"reason":"changed","rev":2}],"rev":3}"#)
  }
}
