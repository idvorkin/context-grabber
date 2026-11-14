//  #883: the whiteboard's log lines to the Cockpit's archive, so Larry can read what a board did without the iPad.

import XCTest

@testable import ContextCore

final class WhiteboardLogArchiveTests: XCTestCase {
  func testTheRingTakesOnlyTheBoardsLines() {
    XCTAssertTrue(WhiteboardLogArchive.Ring.takes(type: "whiteboard", fields: ["action": "keep"]))
    XCTAssertTrue(WhiteboardLogArchive.Ring.takes(type: "whiteboard_turn", fields: [:]))
    XCTAssertTrue(WhiteboardLogArchive.Ring.takes(type: "error", fields: ["where": "whiteboard_save"]))
    XCTAssertFalse(WhiteboardLogArchive.Ring.takes(type: "error", fields: ["where": "chat_thread"]))
    XCTAssertFalse(WhiteboardLogArchive.Ring.takes(type: "call_ready", fields: [:]))
    XCTAssertFalse(WhiteboardLogArchive.Ring.takes(type: "ui", fields: ["action": "open_whiteboard"]))
  }

  func testASendTakesWhatTheLastLeftInBatchesOldestFirst() {
    var ring = WhiteboardLogArchive.Ring()
    for t in 0..<(WhiteboardLogArchive.perBatch + 20) { ring.add(t: t, line: "{\"t\":\(t)}") }
    let first = ring.after(0)
    XCTAssertEqual(first.count, WhiteboardLogArchive.perBatch)
    XCTAssertEqual(first.first?.seq, 1)
    let rest = ring.after(first.last?.seq ?? 0)
    XCTAssertEqual(rest.map(\.seq), Array((WhiteboardLogArchive.perBatch + 1)...(WhiteboardLogArchive.perBatch + 20)))
    XCTAssertTrue(ring.after(rest.last?.seq ?? 0).isEmpty)
  }

  func testTheRingKeepsTheNewestWhenFull() {
    var ring = WhiteboardLogArchive.Ring()
    for t in 0..<(WhiteboardLogArchive.keep + 5) { ring.add(t: t, line: "x") }
    XCTAssertEqual(ring.lines.count, WhiteboardLogArchive.keep)
    XCTAssertEqual(ring.lines.first?.seq, 6)
    XCTAssertEqual(ring.lines.last?.seq, WhiteboardLogArchive.keep + 5)
  }

  func testEachLineIsARecordTheArchiveKeepsOnce() throws {
    let launch = WhiteboardLogArchive.launch(logFile: "grabber-20261114-071800.jsonl", device: "ABCDEF12-3456")
    XCTAssertEqual(launch, "ABCDEF12.grabber-20261114-071800")
    let long = String(repeating: "é", count: 9000)
    let records = WhiteboardLogArchive.records(
      [.init(seq: 7, t: 1200, line: #"{"type":"whiteboard"}"#), .init(seq: 8, t: 1300, line: long)], launch: launch)
    XCTAssertEqual(records.first?["guid"] as? String, "ABCDEF12.grabber-20261114-071800:000007")
    XCTAssertEqual(records.first?["line"] as? String, #"{"type":"whiteboard"}"#)
    XCTAssertEqual(records.first?["t"] as? Int, 1200)
    // The archive's rule: 1-128 characters of [A-Za-z0-9_.:+-], and a record within 8 KB.
    let guid = try XCTUnwrap(records.last?["guid"] as? String)
    XCTAssertLessThanOrEqual(guid.count, 128)
    XCTAssertTrue(guid.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "_.:+-".contains($0)) })
    let size = try JSONSerialization.data(withJSONObject: try XCTUnwrap(records.last)).count
    XCTAssertLessThanOrEqual(size, CallLogArchive.maxRecordBytes)
  }
}
