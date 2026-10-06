//  Story 240: the ring styles' choice and the beads' order.

import ContextCore
import XCTest

final class BreathStyleTests: XCTestCase {
  func testDecodeDefaultsToLine() {
    XCTAssertEqual(BreathStyle.decode(nil), .line)
    XCTAssertEqual(BreathStyle.decode("nonsense"), .line)
    XCTAssertEqual(BreathStyle.decode("tide"), .tide)
  }

  func testBeadsLightInPairsFromTheBottom() {
    XCTAssertEqual(BreathStyle.litBeads(progress: 0), [])
    // Just begun: the bottom bead.
    XCTAssertEqual(BreathStyle.litBeads(progress: 0.01), [0])
    // A quarter of the way: the bottom and three steps up each side.
    XCTAssertEqual(BreathStyle.litBeads(progress: 0.25), [0, 1, 2, 3, 21, 22, 23])
    // Closed: every bead.
    XCTAssertEqual(BreathStyle.litBeads(progress: 1).count, BreathStyle.beadCount)
    // Symmetric at every point.
    for p in stride(from: 0.0, through: 1.0, by: 0.05) {
      let lit = BreathStyle.litBeads(progress: p)
      for b in lit { XCTAssertTrue(lit.contains((BreathStyle.beadCount - b) % BreathStyle.beadCount), "\(p) \(b)") }
    }
  }
}
