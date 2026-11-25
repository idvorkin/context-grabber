import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// The shared board-store goldens (stories 1293, 1322, 1323, 1326–1329; cockpit-8kh): each file under
/// `Fixtures/board-store/clash/` is one `bw_store_clash` input and the answer both repos must give. The Cockpit keeps a
/// sha-pinned copy (`SHA256SUMS`, checked by `scripts/native/board-store-goldens.py`) and runs it through the wasm.
/// `GOLDEN_WRITE=1` rewrites each file's `expect` from the rule; read the diff before committing it.
final class StoreClashGoldenTests: XCTestCase {
  static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../ContextCoreTests/Fixtures/board-store/clash").standardized

  func testEveryGoldenGivesItsAnswer() throws {
    let names = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
      .filter { $0.hasSuffix(".json") }.sorted()
    XCTAssertGreaterThanOrEqual(names.count, 17)
    let write = ProcessInfo.processInfo.environment["GOLDEN_WRITE"] == "1"
    for name in names {
      let url = Self.folder.appendingPathComponent(name)
      var golden = try XCTUnwrap(
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any], name)
      let got = WebStoreClash.answer(golden["input"])
      if write {
        golden["expect"] = got
        let data = try JSONSerialization.data(withJSONObject: golden, options: [.prettyPrinted, .sortedKeys])
        try (data + Data("\n".utf8)).write(to: url)
        continue
      }
      let expect = try XCTUnwrap(golden["expect"], "\(name) has no expect: run with GOLDEN_WRITE=1")
      XCTAssertEqual(try canonical(got), try canonical(expect), name)
    }
  }

  /// Sorted-key JSON, so the answer and the golden compare as JSON on every platform.
  private func canonical(_ json: Any) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), as: UTF8.self)
  }
}
