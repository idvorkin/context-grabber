import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Stories 1293, 1322 and 1323 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, version 22):
/// `bw_store_clash` answers what `BoardStoreClash.apply` decides, and carries the board after the batch.
final class WebStoreClashTests: XCTestCase {
  private func answer(_ json: String) throws -> [String: Any] {
    WebStoreClash.answer(try JSONSerialization.jsonObject(with: Data(json.utf8)))
  }

  func testABatchLandsAndRefusesByName() throws {
    let got = try answer(
      #"{"board":{"rev":94,"things":{"s-a":{"rev":94,"device":"web","by":"igor","at":"t1"},"#
        + #""s-b":{"rev":80,"device":"web","by":"igor","at":"t0"}}},"base_rev":92,"device":"ipad","by":"igor","#
        + #""at":"t2","ops":[{"op":"move","ids":["s-a"],"dx":4},{"op":"erase","ids":["s-b"]},"#
        + #"{"op":"add_strokes","strokes":[{"id":"s-c"}]}]}"#)
    XCTAssertEqual(got["rev"] as? Int, 95)
    XCTAssertEqual(got["applied"] as? [Int], [1, 2])
    let refused = try XCTUnwrap(got["refused"] as? [[String: Any]])
    XCTAssertEqual(refused.count, 1)
    XCTAssertEqual(refused[0]["id"] as? String, "s-a")
    XCTAssertEqual(refused[0]["reason"] as? String, "changed")
    XCTAssertEqual(refused[0]["device"] as? String, "web")
    let things = try XCTUnwrap((got["board"] as? [String: Any])?["things"] as? [String: [String: Any]])
    XCTAssertEqual(things["s-b"]?["erased"] as? Bool, true)
    XCTAssertEqual(things["s-c"]?["rev"] as? Int, 95)
    XCTAssertEqual(things["s-a"]?["rev"] as? Int, 94)
  }

  func testADeletedBoardRefusesEverything() throws {
    let got = try answer(
      #"{"board":{"rev":12,"deleted":{"rev":12,"device":"web","by":"igor","at":"t"}},"base_rev":11,"#
        + #""device":"ipad","by":"igor","at":"t2","ops":[{"op":"add_strokes","strokes":[{"id":"n"}]}]}"#)
    XCTAssertEqual(got["applied"] as? [Int], [])
    XCTAssertEqual((got["refused"] as? [[String: Any]])?.first?["reason"] as? String, "deleted")
    XCTAssertNotNil((got["board"] as? [String: Any])?["deleted"])
  }

  func testMissingFieldsSaySo() {
    XCTAssertEqual(WebStoreClash.answer(nil)["error"] as? String, "no board")
    XCTAssertEqual(WebStoreClash.answer(["board": ["rev": 1]])["error"] as? String, "no base_rev")
    XCTAssertEqual(
      WebStoreClash.answer(["board": ["rev": 1], "base_rev": 1])["error"] as? String, "no device")
    XCTAssertEqual(
      WebStoreClash.answer(["board": ["rev": 1], "base_rev": 1, "device": "d"])["error"] as? String, "no ops")
  }
}
