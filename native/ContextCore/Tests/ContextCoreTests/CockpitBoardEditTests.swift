//  Drawing on a Cockpit board (stories 1344-1346): the strokes the trial canvas opens to, and a change of them turned
//  into the store's ops through the one encoder.

import XCTest

@testable import ContextCore

final class CockpitBoardEditTests: XCTestCase {
  private func stroke(_ id: String, x: Int = 0) -> BoardStoreJSON {
    ["id": .string(id), "pts": [[.int(Int64(x)), 0, 1]], "w": 2.5, "c": "#1a1a1a", "seed": 7]
  }

  private func board() -> BoardStoreCache {
    BoardStoreCache(snapshot: [
      "id": "b-1", "rev": 3, "erased": ["gone"],
      "things": [
        ["id": "@board", "kind": "board", "body": ["name": "Trial"], "rev": 1, "device": "web-3f9a", "by": "igor"],
        ["id": "s1", "kind": "stroke", "body": stroke("s1"), "rev": 2, "device": "web-3f9a", "by": "igor"],
        ["id": "t1", "kind": "object", "body": ["id": "t1", "kind": "text", "text": "hi"], "rev": 2, "device": "w"],
        ["id": "s2", "kind": "stroke", "body": stroke("s2", x: 9), "rev": 3, "device": "web-3f9a", "by": "igor"],
      ],
    ])
  }

  // Story 1344: the canvas opens to the live strokes in draw order, with this device's waiting saves on top.
  func testStrokesAreTheLiveOnesInDrawOrderWithWaitingSaves() {
    var cache = board()
    XCTAssertEqual(CockpitBoardEdit.strokes(cache).map(\.id), ["s1", "s2"])
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s3")]]])
    cache.enqueue([["op": "erase", "ids": ["s1"]]])
    XCTAssertEqual(CockpitBoardEdit.strokes(cache).map(\.id), ["s2", "s3"])
  }

  // Story 1344: a new stroke is one add_strokes, carried whole; a stroke taken off is one erase; nothing else moves.
  func testADrawnAndAnErasedStrokeAreTheirOps() throws {
    let cache = board()
    let drawn = try CockpitBoardEdit.ops(cache, after: [stroke("s1"), stroke("s2", x: 9), stroke("s3", x: 4)]).get()
    XCTAssertEqual(drawn, [["op": "add_strokes", "strokes": [stroke("s3", x: 4)]]])
    let erased = try CockpitBoardEdit.ops(cache, after: [stroke("s2", x: 9)]).get()
    XCTAssertEqual(erased, [["op": "erase", "ids": ["s1"]]])
    XCTAssertEqual(try CockpitBoardEdit.ops(cache, after: [stroke("s1"), stroke("s2", x: 9)]).get(), [])
  }

  // A stroke moved is a set of its new record; an undo that brings back an erased stroke is a restore.
  func testAMoveIsASetAndABroughtBackStrokeIsARestore() throws {
    var cache = board()
    let moved = try CockpitBoardEdit.ops(cache, after: [stroke("s1", x: 30), stroke("s2", x: 9)]).get()
    XCTAssertEqual(moved, [["op": "set", "ids": ["s1"], "bodies": ["s1": stroke("s1", x: 30)]]])
    cache.enqueue([["op": "erase", "ids": ["s2"]]])
    let back = try CockpitBoardEdit.ops(cache, after: [stroke("s1"), stroke("s2", x: 9)]).get()
    XCTAssertEqual(back, [["op": "restore", "ids": ["s2"]]])
  }

  func testTwoRecordsOfOneIdAreRefusedNotSent() {
    let cache = board()
    guard case .failure = CockpitBoardEdit.ops(cache, after: [stroke("s1"), stroke("s1", x: 2)]) else {
      return XCTFail("two records of one id went up")
    }
  }

  // Story 1346: Keep my ink starts from an empty board under the new name.
  func testKeptInkStartsFromAnEmptyBoard() {
    let empty = CockpitBoardEdit.emptyBoard(id: "b-9", name: "Trial (kept ink)")
    XCTAssertEqual(empty.boardID, "b-9")
    XCTAssertEqual(empty.rev, 0)
    XCTAssertEqual(CockpitBoardEdit.strokes(empty), [])
  }

  func testJSONFromTheEncodersValues() {
    XCTAssertEqual(BoardStoreJSON(any: true), .bool(true))
    XCTAssertEqual(BoardStoreJSON(any: Int64(3)), .int(3))
    XCTAssertEqual(BoardStoreJSON(any: 3), .int(3))
    XCTAssertEqual(BoardStoreJSON(any: 2.5), .number(2.5))
    XCTAssertEqual(BoardStoreJSON(any: NSNull()), .null)
    XCTAssertEqual(BoardStoreJSON(any: ["a": [1, "x"]] as [String: Any]), ["a": [1, "x"]])
    XCTAssertEqual(BoardStoreJSON(any: stroke("s1").any), stroke("s1"))
  }

  func testCreateRequestIsAPostOfTheBoard() throws {
    let request = try CockpitBoardStore.createRequest(
      body: ["id": "b-9", "name": "Trial (kept ink)"], cockpit: "https://cockpit.test")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.test/boards")
    XCTAssertEqual(CockpitBoardStore.json(request.httpBody ?? Data()), ["id": "b-9", "name": "Trial (kept ink)"])
  }
}
