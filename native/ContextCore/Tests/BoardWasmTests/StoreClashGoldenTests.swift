import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// The shared board-store goldens (stories 1293, 1322, 1323, 1326–1329, 1299, 1300; cockpit-8kh): each file under
/// `Fixtures/board-store/clash/` is one `bw_store_clash` input and the answer both repos must give, and each under
/// `encode/` one `bw_store_encode` input and its ops. The Cockpit keeps a
/// sha-pinned copy (`SHA256SUMS`, checked by `scripts/native/board-store-goldens.py`) and runs it through the wasm.
/// `GOLDEN_WRITE=1` rewrites each file's `expect` from the rule; read the diff before committing it.
final class StoreClashGoldenTests: XCTestCase {
  static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../ContextCoreTests/Fixtures/board-store").standardized

  func testEveryClashGoldenGivesItsAnswer() throws {
    XCTAssertGreaterThanOrEqual(try check("clash", WebStoreClash.answer).count, 18)
  }

  // Story 1299: every encode golden gives its ops, and those ops land whole as one batch on the board before.
  func testEveryEncodeGoldenGivesItsOpsAndTheyLand() throws {
    let goldens = try check("encode", WebStoreEncode.answer)
    XCTAssertGreaterThanOrEqual(goldens.count, 7)
    let author = BoardStoreClash.Author(device: "ipad-7c2e", by: "igor", at: "t")
    for (name, input) in goldens {
      guard let before = input["before"] as? [String: Any], let after = input["after"] as? [String: Any] else {
        continue
      }
      var board = BoardStoreClash.Board(rev: 1)
      board.things[BoardStoreClash.boardID] = .init(rev: 1, author: author)
      for id in BoardStoreEncode.thingIDs(before) { board.things[id] = .init(rev: 1, author: author) }
      for id in (input["erased"] as? [String: Any] ?? [:]).keys {
        board.things[id] = .init(rev: 1, author: author, erased: true)
      }
      let ops =
        BoardStoreEncode.encode(
          before: before, after: after, erased: input["erased"] as? [String: Any] ?? [:])["ops"] as? [Any] ?? []
      let answer = BoardStoreClash.apply(
        ops.map(BoardStoreClash.Op.init(json:)), to: board, base: 1, author: author)
      XCTAssertEqual(answer.refused, [], name)
      XCTAssertEqual(answer.applied, Array(ops.indices), name)
    }
  }

  // Story 1300: a move of the shared stroke records sends each one whole, every field it had kept.
  func testTheStrokeRecordSurvivesAMove() throws {
    let record = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: Data(contentsOf: Self.root.appendingPathComponent("stroke-record.json")))
        as? [String: Any])
    let strokes = try XCTUnwrap(record["strokes"] as? [[String: Any]])
    let moved = strokes.map { stroke -> [String: Any] in
      var out = stroke
      out["pts"] = (stroke["pts"] as? [[Double]] ?? []).map { [$0[0] + 12, $0[1] - 8] + $0.dropFirst(2) }
      return out
    }
    let ops = try XCTUnwrap(
      BoardStoreEncode.encode(before: ["strokes": strokes], after: ["strokes": moved])["ops"] as? [[String: Any]])
    XCTAssertEqual(ops.count, 1)
    XCTAssertEqual(ops.first?["op"] as? String, "set")
    let bodies = try XCTUnwrap(ops.first?["bodies"] as? [String: Any])
    for stroke in moved {
      let id = try XCTUnwrap(stroke["id"] as? String)
      XCTAssertEqual(try canonical(XCTUnwrap(bodies[id])), try canonical(stroke), id)
    }
    XCTAssertNotNil((bodies["s-1795600002000-1"] as? [String: Any])?["zz_future"], "an unknown field is kept")
  }

  /// Runs every golden in `folder` through `answer`, or rewrites its `expect` under `GOLDEN_WRITE=1`: each golden's
  /// name and input.
  @discardableResult
  private func check(_ folder: String, _ answer: (Any?) -> [String: Any]) throws -> [(String, [String: Any])] {
    let dir = Self.root.appendingPathComponent(folder)
    let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".json") }.sorted()
    let write = ProcessInfo.processInfo.environment["GOLDEN_WRITE"] == "1"
    var out: [(String, [String: Any])] = []
    for name in names {
      let url = dir.appendingPathComponent(name)
      var golden = try XCTUnwrap(
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any], name)
      let input = golden["input"] as? [String: Any] ?? [:]
      out.append((name, input))
      let got = answer(golden["input"])
      if write {
        golden["expect"] = got
        let data = try JSONSerialization.data(withJSONObject: golden, options: [.prettyPrinted, .sortedKeys])
        try (data + Data("\n".utf8)).write(to: url)
        continue
      }
      let expect = try XCTUnwrap(golden["expect"], "\(name) has no expect: run with GOLDEN_WRITE=1")
      XCTAssertEqual(try canonical(got), try canonical(expect), name)
    }
    return out
  }

  /// Sorted-key JSON, so the answer and the golden compare as JSON on every platform.
  private func canonical(_ json: Any) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), as: UTF8.self)
  }
}
