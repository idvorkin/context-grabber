import XCTest

@testable import ContextCore

/// Stories 1361-1363: sending a board to the Cockpit, the mirror.
final class CockpitBoardMirrorTests: XCTestCase {
  func testStrokeIDsAreStableAndUnique() {
    let strokes: [(ms: Int64, seed: UInt32)] = [(100, 1), (200, 0xab), (200, 0xcd), (200, 0xab), (300, 7)]
    let ids = CockpitBoardMirror.strokeIDs(strokes)
    XCTAssertEqual(ids, ["s-100x1", "s-200xab", "s-200xcd", "s-200xaba", "s-300x7"])
    XCTAssertEqual(CockpitBoardMirror.strokeIDs(strokes), ids, "a second send, same ids")
    XCTAssertFalse(ids.contains { $0.range(of: #"-\d+-\d+$"#, options: .regularExpression) != nil })
    XCTAssertEqual(
      CockpitBoardMirror.strokeIDs([(100, 1), (200, 0xcd), (300, 7)]), ["s-100x1", "s-200xcd", "s-300x7"],
      "erasing a stroke that shares a millisecond moves no other stroke's id")
  }

  private func copy(_ things: [BoardStoreJSON]) -> BoardStoreCache {
    BoardStoreCache(snapshot: ["id": "b1", "rev": 3, "erased": [], "things": .array(things)])
  }

  private func thing(_ id: String, device: String) -> BoardStoreJSON {
    [
      "id": .string(id), "kind": "stroke", "body": stroke(id, points: 2), "rev": 1, "device": .string(device),
      "by": "x",
    ]
  }

  func testASaveNeverErasesAnotherDevicesStrokes() throws {
    let cache = copy([
      ["id": "@board", "kind": "board", "body": ["name": "Main"], "rev": 1, "device": "ipad-1", "by": "igor"],
      thing("s-1x1", device: "ipad-1"), thing("s-2x2", device: "ipad-1"), thing("w-9", device: "web-1"),
    ])
    let records = [stroke("s-1x1", points: 2)]
    let after = CockpitBoardMirror.after(records: records, cache: cache, device: "ipad-1")
    let ops = try CockpitBoardEdit.ops(cache, after: after).get()
    let erased = ops.filter { $0["op"]?.string == "erase" }.flatMap { $0["ids"]?.strings ?? [] }
    XCTAssertEqual(erased, ["s-2x2"], "only the stroke this iPad sent and no longer has: \(ops)")
    XCTAssertFalse(ops.contains { $0["op"]?.string == "set" }, "the web's stroke is left as it is: \(ops)")
  }

  func testASecondSendOfTheSameBoardLandsNothing() throws {
    let cache = copy([thing("s-1x1", device: "ipad-1"), thing("w-9", device: "web-1")])
    let after = CockpitBoardMirror.after(
      records: [stroke("s-1x1", points: 2)], cache: cache, device: "ipad-1")
    XCTAssertEqual(try CockpitBoardEdit.ops(cache, after: after).get(), [])
  }

  func testARenameFollowsTheBoard() {
    let cache = copy([
      ["id": "@board", "kind": "board", "body": ["name": "Untitled"], "rev": 1, "device": "", "by": ""]
    ])
    XCTAssertEqual(CockpitBoardMirror.rename(cache, name: "Plans")?["name"]?.string, "Plans")
    XCTAssertEqual(CockpitBoardMirror.rename(cache, name: "Plans")?["op"]?.string, "rename")
    XCTAssertNil(CockpitBoardMirror.rename(cache, name: ""), "an unnamed board is the copy's Untitled")
  }

  func testTheGateHoldsRealBoardsUntilTheBackupIsLive() {
    XCTAssertFalse(CockpitBoardMirror.allowed(name: "Main board", backupLive: false))
    XCTAssertTrue(CockpitBoardMirror.allowed(name: "Scratch: mirror test", backupLive: false))
    XCTAssertTrue(CockpitBoardMirror.allowed(name: "  scratch two", backupLive: false))
    XCTAssertTrue(CockpitBoardMirror.allowed(name: "Main board", backupLive: true))
  }

  func testCreateBodyKeepsTheBoardsOwnIDAndTheOriginalAsset() {
    let body = CockpitBoardMirror.createBody(
      id: "abc-123", name: "", paper: "cream", ruled: true, device: "ipad-1234abcd", originalAsset: "f00d")
    XCTAssertEqual(body["id"]?.string, "abc-123")
    XCTAssertEqual(body["name"]?.string, "Untitled")
    XCTAssertEqual(body["paper"]?.string, "cream")
    XCTAssertEqual(body["original_asset"]?.string, "f00d")
    XCTAssertEqual(body["device"]?.string, "ipad-1234abcd")
  }

  func testAssetRequestPutsTheBytes() throws {
    let request = try CockpitBoardMirror.assetRequest(
      sha: "abcd", data: Data([1, 2, 3]), cockpit: "http://127.0.0.1:8778")
    XCTAssertEqual(request.httpMethod, "PUT")
    XCTAssertEqual(request.url?.path, "/boards/assets/abcd")
    XCTAssertEqual(request.httpBody, Data([1, 2, 3]))
  }

  private func stroke(_ id: String, points: Int) -> BoardStoreJSON {
    ["id": .string(id), "pts": .array((0..<points).map { _ in [1.5, 2.5, 0.5, 10, 0, 1, 2] })]
  }

  func testABigAddIsCutUnderTheLimitInOrder() {
    let strokes = (0..<40).map { stroke("s-\($0)", points: 50) }
    let ops: [BoardStoreJSON] = [["op": "add_strokes", "strokes": .array(strokes)], ["op": "header", "id": "h1"]]
    let limit = 6_000
    let saves = CockpitBoardMirror.saves(ops, maxBytes: limit)
    XCTAssertGreaterThan(saves.count, 2)
    for save in saves {
      XCTAssertLessThanOrEqual(save.reduce(0) { $0 + CockpitBoardStore.data($1).count }, limit)
    }
    let sent = saves.flatMap { $0 }.flatMap { $0["strokes"]?.array ?? [] }.compactMap { $0["id"]?.string }
    XCTAssertEqual(sent, strokes.compactMap { $0["id"]?.string }, "every stroke once, in order")
    XCTAssertEqual(saves.last?.last?["op"]?.string, "header", "other ops go whole, after")
  }

  func testASmallBoardIsOneSave() {
    let ops: [BoardStoreJSON] = [["op": "add_strokes", "strokes": [stroke("s-1", points: 3)]]]
    XCTAssertEqual(CockpitBoardMirror.saves(ops).count, 1)
    XCTAssertEqual(CockpitBoardMirror.saves([]).count, 0)
  }

  func testTheBookSurvivesARelaunch() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("mirror.json")
    var book = CockpitBoardMirror.Book()
    book.mirrored = ["b1"]
    book.created = ["b1"]
    try book.save(url)
    XCTAssertEqual(CockpitBoardMirror.Book.load(url), book)
    XCTAssertEqual(CockpitBoardMirror.Book.load(url.appendingPathExtension("missing")), CockpitBoardMirror.Book())
  }
}
