import BoardCore
import Foundation
import XCTest

@testable import BoardWasm

/// Stories 1293, 1322 and 1323 (spec 2026-11-22-board-rules-on-the-web-design.md, The interface, versions 22 and 23):
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

  // Story 1329: a thing without its revision or device, or with an `erased` that isn't a boolean, is an error naming
  // it, never dropped; a `deleted` of null is no delete.
  func testAMalformedThingIsAnError() throws {
    let head =
      #"{"base_rev":1,"device":"ipad","by":"igor","at":"t","ops":[{"op":"add_strokes","strokes":[{"id":"s-1"}]}],"#
    XCTAssertEqual(
      try answer(head + #""board":{"rev":1,"things":{"s-1":{"rev":1}}}}"#)["error"] as? String, "malformed thing s-1")
    XCTAssertEqual(
      try answer(head + #""board":{"rev":1,"things":{"s-1":{"device":"web"}}}}"#)["error"] as? String,
      "malformed thing s-1")
    XCTAssertEqual(
      try answer(head + #""board":{"rev":1,"things":{"s-1":{"rev":1,"device":"web","erased":"yes"}}}}"#)["error"]
        as? String, "malformed thing s-1")
    XCTAssertEqual(
      try answer(head + #""board":{"rev":1,"deleted":{"rev":1}}}"#)["error"] as? String, "malformed thing deleted")
    let fine = try answer(
      head + #""board":{"rev":1,"deleted":null,"things":{"s-2":{"rev":1,"device":"web","erased":1}}}}"#)
    XCTAssertNil(fine["error"])
    XCTAssertEqual(fine["applied"] as? [Int], [0])
    let things = try XCTUnwrap((fine["board"] as? [String: Any])?["things"] as? [String: [String: Any]])
    XCTAssertEqual(things["s-2"]?["erased"] as? Bool, true, "an erased of 1 reads as erased")
  }

  // Stories 1327 and 1328 over the wire: an erased `@board` refuses as deleted, and `landed` names ids per op.
  func testInterface23OverTheWire() throws {
    let deleted = try answer(
      #"{"board":{"rev":3,"things":{"@board":{"rev":3,"device":"web","by":"igor","at":"t","erased":true}}},"#
        + #""base_rev":3,"device":"ipad","by":"igor","at":"t2","ops":[{"op":"add_strokes","strokes":[{"id":"n"}]}]}"#)
    XCTAssertEqual((deleted["refused"] as? [[String: Any]])?.first?["reason"] as? String, "deleted")
    XCTAssertEqual((deleted["landed"] as? [Any])?.count, 0)
    let grouped = try answer(
      #"{"board":{"rev":2,"things":{"s-1":{"rev":1,"device":"web"},"g-1":{"rev":1,"device":"web"}}},"#
        + #""base_rev":2,"device":"ipad","by":"igor","at":"t2","ops":[{"op":"group","id":"g-1","ids":["s-1"]}]}"#)
    let landed = try XCTUnwrap(grouped["landed"] as? [[String: Any]])
    XCTAssertEqual(landed.first?["op"] as? Int, 0)
    XCTAssertEqual(landed.first?["ids"] as? [String], ["s-1"])
  }
}
