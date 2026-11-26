import XCTest

@testable import ContextCore

/// Stories 1361-1363: sending a board to the Cockpit, the mirror.
final class CockpitBoardMirrorTests: XCTestCase {
  func testStrokeIDsAreStableAndUnique() {
    let ids = CockpitBoardMirror.strokeIDs(createdMs: [100, 200, 200, 200, 300])
    XCTAssertEqual(ids, ["s-100", "s-200", "s-200a", "s-200b", "s-300"])
    XCTAssertEqual(CockpitBoardMirror.strokeIDs(createdMs: [100, 200, 200, 200, 300]), ids, "a second send, same ids")
    XCTAssertFalse(ids.contains { $0.range(of: #"-\d+-\d+$"#, options: .regularExpression) != nil })
  }

  func testTheGateHoldsRealBoardsUntilTheBackupIsLive() {
    XCTAssertFalse(CockpitBoardMirror.allowed(name: "Main board", backupLive: false))
    XCTAssertTrue(CockpitBoardMirror.allowed(name: "Scratch: mirror test", backupLive: false))
    XCTAssertTrue(CockpitBoardMirror.allowed(name: "  scratch two", backupLive: false))
    XCTAssertTrue(CockpitBoardMirror.allowed(name: "Main board", backupLive: true))
    XCTAssertTrue(CockpitBoardMirror.backupLive, "Larry posted the backup is live (cockpit cfbb196)")
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
