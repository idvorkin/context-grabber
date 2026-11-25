//  The beta switch's talk with the Cockpit board store (spec 2026-11-22-boards-in-the-cockpit-design.md, Trying it
//  before the rollout; stories 1339-1341): the requests, the list rows, the copy on disk, and one sync pass that
//  pulls before it sends and sends one save at a time.

import XCTest

@testable import ContextCore

/// A Cockpit that answers like the fake's store routes, and records what it was asked.
private actor FakeStore {
  var rev = 5
  var batches: [BoardStoreJSON] = []
  var asked: [String] = []
  var posted: [BoardStoreJSON] = []
  var answers: [String: BoardStoreJSON] = [:]
  /// The next POST goes unanswered, as a kill or a lost network would leave it.
  var dropNextAnswer = false
  var refuseNext: [BoardStoreJSON] = []

  func setDrop(_ drop: Bool) { dropNextAnswer = drop }
  func setRefuse(_ refused: [BoardStoreJSON]) { refuseNext = refused }
  func addRemote(_ batch: BoardStoreJSON) {
    rev += 1
    var batch = batch
    batch["rev"] = .int(Int64(rev))
    batches.append(batch)
  }

  func handle(_ request: URLRequest) throws -> (Int, Data) {
    let url = request.url!
    let path = url.path
    asked.append((request.httpMethod ?? "GET") + " " + path + (url.query.map { "?" + $0 } ?? ""))
    if request.httpMethod == "POST" {
      let body = CockpitBoardStore.json(request.httpBody ?? Data())!
      posted.append(body)
      let id = body["batch_id"]!.string!
      if let seen = answers[id] { return (200, CockpitBoardStore.data(seen)) }
      if dropNextAnswer {
        dropNextAnswer = false
        record(body, id: id)
        throw URLError(.networkConnectionLost)
      }
      return (200, CockpitBoardStore.data(record(body, id: id)))
    }
    if path.hasSuffix("/ops") {
      let since = Int(url.query?.replacingOccurrences(of: "since=", with: "") ?? "0") ?? 0
      let after = batches.filter { ($0["rev"]?.int ?? 0) > since }
      return (200, CockpitBoardStore.data(["rev": .int(Int64(rev)), "batches": .array(after)]))
    }
    if path == "/boards" {
      return (
        200,
        CockpitBoardStore.data([
          "contract": 2,
          "boards": [
            ["id": "b-1", "name": "Store trial", "rev": .int(Int64(rev)), "last_drawn_on": "web"],
            ["id": "b-2", "name": "Gone", "rev": 2, "deleted": true],
          ],
        ])
      )
    }
    return (404, CockpitBoardStore.data(["ok": false, "error": "unknown board"]))
  }

  /// The landed form `ops?since` gives: the op with the ids it landed and their bodies after.
  private static func landed(_ op: BoardStoreJSON) -> BoardStoreJSON {
    let strokes = op["strokes"]?.array ?? []
    if !strokes.isEmpty {
      let ids = strokes.compactMap { $0["id"]?.string }
      var bodies: [String: BoardStoreJSON] = [:]
      for stroke in strokes { if let id = stroke["id"]?.string { bodies[id] = stroke } }
      return ["op": op["op"] ?? "", "ids": .array(ids.map { .string($0) }), "bodies": .object(bodies)]
    }
    return ["op": op["op"] ?? "", "ids": op["ids"] ?? [], "bodies": [:]]
  }

  @discardableResult
  private func record(_ body: BoardStoreJSON, id: String) -> BoardStoreJSON {
    let ops = body["ops"]?.array ?? []
    let refused = refuseNext
    refuseNext = []
    let refusedIndexes = Set(refused.compactMap { $0["op"]?.int })
    let applied = ops.indices.filter { !refusedIndexes.contains($0) }
    if !applied.isEmpty {
      rev += 1
      batches.append([
        "rev": .int(Int64(rev)), "batch_id": .string(id), "kind": "ops", "device": body["device"] ?? "",
        "by": "igor", "at": "t", "ops": .array(applied.map { Self.landed(ops[$0]) }),
      ])
    }
    let answer: BoardStoreJSON = [
      "ok": true, "rev": .int(Int64(rev)), "applied": .array(applied.map { .int(Int64($0)) }),
      "refused": .array(refused), "batch_id": .string(id),
    ]
    answers[id] = answer
    return answer
  }
}

final class CockpitBoardStoreTests: XCTestCase {
  private let cockpit = "https://cockpit.test"

  private func stroke(_ id: String) -> BoardStoreJSON { ["id": .string(id), "pts": [[0, 0, 1]]] }

  private func board() -> BoardStoreCache {
    BoardStoreCache(snapshot: [
      "id": "b-1", "rev": 5, "erased": [],
      "things": [
        [
          "id": "@board", "kind": "board", "body": ["name": "Store trial"], "rev": 1, "device": "web-3f9a",
          "by": "igor", "at": "t1",
        ]
      ],
    ])
  }

  private func sync(_ store: FakeStore, ids: [String] = ["batch-1", "batch-2", "batch-3"]) -> CockpitBoardSync {
    let next = IDs(ids)
    return CockpitBoardSync(
      cockpit: cockpit, device: "ipad-7c2e", by: "igor",
      send: { request in try await store.handle(request) },
      newBatchID: { next.take() }, now: { "2026-11-25T10:00:00Z" })
  }

  // The requests: the store's read and write routes, under the Cockpit's address.
  func testRequestsNameTheStoreRoutes() throws {
    XCTAssertEqual(try CockpitBoardStore.listRequest(cockpit: cockpit).url?.absoluteString, cockpit + "/boards")
    XCTAssertEqual(
      try CockpitBoardStore.snapshotRequest(board: "b 1", cockpit: cockpit).url?.absoluteString,
      cockpit + "/boards/b%201")
    XCTAssertEqual(
      try CockpitBoardStore.opsRequest(board: "b-1", since: 7, cockpit: cockpit).url?.absoluteString,
      cockpit + "/boards/b-1/ops?since=7")
    let post = try CockpitBoardStore.postRequest(board: "b-1", body: ["batch_id": "x"], cockpit: cockpit)
    XCTAssertEqual(post.httpMethod, "POST")
    XCTAssertEqual(post.url?.absoluteString, cockpit + "/boards/b-1/ops")
    XCTAssertEqual(CockpitBoardStore.json(post.httpBody ?? Data()), ["batch_id": "x"])
    XCTAssertThrowsError(try CockpitBoardStore.listRequest(cockpit: ""))
  }

  // Story 1340: the list shows the Cockpit's live boards, newest version first; a deleted board isn't listed.
  func testRowsListLiveBoards() async throws {
    let store = FakeStore()
    let (status, data) = try await store.handle(try CockpitBoardStore.listRequest(cockpit: cockpit))
    XCTAssertEqual(status, 200)
    let rows = try XCTUnwrap(CockpitBoardStore.rows(data))
    XCTAssertEqual(rows, [.init(id: "b-1", name: "Store trial", rev: 5, lastDrawnOn: "web")])
    XCTAssertEqual(CockpitBoardStore.rows(Data("{\"boards\": []}".utf8)), [])
    XCTAssertNil(CockpitBoardStore.rows(Data("<html>".utf8)))
  }

  // Story 1341: the copy on disk comes back whole, the frozen save in flight included.
  func testDiskKeepsTheCopyAndItsFrozenSave() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let disk = CockpitBoardDisk(folder: folder)
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s1")]]])
    _ = cache.freeze(batchID: "batch-1", deviceAt: "t")
    try disk.save(cache)
    XCTAssertEqual(disk.load(board: "b-1"), cache)
    XCTAssertNil(disk.load(board: "b-9"))
  }

  // Story 1341: a pass pulls before it sends, then sends one save at a time, each after the last one's answer.
  func testAPassPullsFirstThenSendsOneAtATime() async throws {
    let store = FakeStore()
    await store.addRemote([
      "batch_id": "w1", "kind": "ops", "device": "web-3f9a", "by": "igor", "at": "t",
      "ops": [["op": "add_strokes", "ids": ["w"], "bodies": ["w": stroke("w")]]],
    ])
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s1")]]])
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s2")]]])
    var saved = 0
    let report = await sync(store).run(&cache) { _ in saved += 1 }
    let asked = await store.asked
    XCTAssertEqual(asked, ["GET /boards/b-1/ops?since=5", "POST /boards/b-1/ops", "POST /boards/b-1/ops"])
    let posted = await store.posted
    XCTAssertEqual(posted.map { $0["base_rev"]?.int }, [6, 7])
    XCTAssertEqual(posted.map { $0["batch_id"]?.string }, ["batch-1", "batch-2"])
    XCTAssertEqual(cache.queue, [])
    XCTAssertEqual(cache.rev, 8)
    XCTAssertNotNil(cache.view["w"])
    XCTAssertNotNil(cache.view["s2"])
    XCTAssertEqual(report.sent, 2)
    XCTAssertNil(report.problem)
    XCTAssertGreaterThanOrEqual(saved, 3, "the copy is written before each save leaves and after each answer")
  }

  // Story 1341: a save whose answer was lost goes again as it was, and the Cockpit takes it once.
  func testALostAnswerSendsTheSameSaveAgain() async throws {
    let store = FakeStore()
    await store.setDrop(true)
    var cache = board()
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s1")]]])
    cache.enqueue([["op": "add_strokes", "strokes": [stroke("s2")]]])
    let first = await sync(store).run(&cache) { _ in }
    XCTAssertNotNil(first.problem)
    XCTAssertEqual(cache.queue.count, 2, "nothing leaves the queue without an answer")
    XCTAssertEqual(cache.queue.first?.batchID, "batch-1")
    // Relaunch: a new sync, the same copy from disk.
    let second = await sync(store, ids: ["batch-9", "batch-10"]).run(&cache) { _ in }
    XCTAssertNil(second.problem)
    let posted = await store.posted
    XCTAssertEqual(posted.map { $0["batch_id"]?.string }, ["batch-1", "batch-1", "batch-9"])
    XCTAssertEqual(posted[0], posted[1], "the same body goes again")
    let rev = await store.rev
    XCTAssertEqual(rev, 7, "the first save landed once, the second once")
    XCTAssertEqual(cache.queue, [])
  }

  // A refused change becomes a note, and the next save still goes.
  func testARefusalBecomesANote() async throws {
    let store = FakeStore()
    await store.setRefuse([["op": 0, "id": "s1", "reason": "changed", "rev": 4, "device": "web-3f9a", "by": "igor"]])
    var cache = board()
    cache.enqueue([["op": "erase", "ids": ["s1"]]])
    _ = await sync(store).run(&cache) { _ in }
    XCTAssertEqual(cache.notes.map(\.id), ["s1"])
    XCTAssertEqual(cache.queue, [])
  }

  // Not answering: a pass stops with a copyable problem naming the address and what failed.
  func testUnreachableIsACopyableProblem() async {
    var cache = board()
    let sync = CockpitBoardSync(
      cockpit: cockpit, device: "ipad-7c2e", by: "igor", send: { _ in throw URLError(.cannotFindHost) },
      newBatchID: { "x" }, now: { "t" })
    let report = await sync.run(&cache) { _ in }
    let problem = try? XCTUnwrap(report.problem)
    XCTAssertTrue(problem?.contains(cockpit) == true)
    XCTAssertTrue(problem?.contains("ops?since=5") == true)
  }
}

private final class IDs: @unchecked Sendable {
  private var ids: [String]
  private let lock = NSLock()
  init(_ ids: [String]) { self.ids = ids }
  func take() -> String {
    lock.lock()
    defer { lock.unlock() }
    return ids.isEmpty ? UUID().uuidString : ids.removeFirst()
  }
}
