//  Story 1209 (bead context-grabber-vabk): Ink side by side's readout and the web board's address. Story 1324's
//  per-stroke lags, log fields and web probe are InkStrokeLagTests'.

import XCTest

@testable import ContextCore

final class InkLatencyTests: XCTestCase {
  private func stroke(_ lag: Double) -> InkStrokeLag.Summary { InkStrokeLag.Summary(lag: lag, lagMax: lag, frames: 1) }

  func testBeforeAnyStrokeTheCornerSaysDrawToMeasure() {
    let latency = InkLatency(side: .native)
    XCTAssertEqual(latency.readout, "Draw to measure")
    XCTAssertNil(latency.last)
    XCTAssertNil(latency.median)
    XCTAssertEqual(latency.count, 0)
  }

  func testTheMedianOfAnEvenCountIsTheMeanOfTheMiddleTwo() {
    var latency = InkLatency(side: .native)
    for ms in [40.0, 10, 30, 20] { latency.add(stroke(ms)) }
    XCTAssertEqual(latency.median, 25)
  }

  func testATimeBelowZeroOrOverASecondIsDroppedNotCounted() {
    var latency = InkLatency(side: .native)
    XCTAssertEqual(latency.add(stroke(-3)), .dropped)
    XCTAssertEqual(latency.add(stroke(1500)), .dropped)
    XCTAssertEqual(latency.add(stroke(.nan)), .dropped)
    XCTAssertEqual(latency.add(stroke(1000)), .kept)
    XCTAssertEqual(latency.count, 1)
    XCTAssertEqual(latency.dropped, 3)
    XCTAssertEqual(latency.readout, "last 1000 ms · median 1000 ms · 1 stroke")
  }

  func testADroppedStrokeIsStillLoggedAsDropped() {
    var latency = InkLatency(side: .native)
    let bad = stroke(-1)
    let outcome = latency.add(bad)
    let fields = latency.logFields(stroke: bad, outcome: outcome)
    XCTAssertEqual(fields["kept"] as? Bool, false)
    XCTAssertEqual(fields["dropped"] as? Int, 1)
    XCTAssertNil(fields["median"])
  }

  func testTheWebBoardOpensOnItsScratchBoard() {
    XCTAssertEqual(
      InkLatency.webBoardURL(cockpit: "https://cockpit.example.net")?.absoluteString,
      "https://cockpit.example.net/ink?b=scratch")
    XCTAssertEqual(
      InkLatency.webBoardURL(cockpit: "https://cockpit.example.net/")?.absoluteString,
      "https://cockpit.example.net/ink?b=scratch")
  }
}
