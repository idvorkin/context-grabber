//  Story 146 (#164): a gentle back-and-forth is a shake; one push, a slow sway or a weak jiggle is not.

import ContextCore
import XCTest

final class ShakeGestureTests: XCTestCase {
  /// A sine on one axis at `hz`, `g` strong, sampled at 50 Hz for `seconds`; returns the first shake's peak.
  func run(_ g: Double, hz: Double, seconds: Double, start: Double = 0, on gesture: inout ShakeGesture) -> Double? {
    var t = start
    while t < start + seconds {
      if let p = gesture.feed(x: 0.05, y: g * sin(2 * .pi * hz * t), z: 0.1, t: t) { return p }
      t += 0.02
    }
    return nil
  }

  func testAQuickLightShakeIsAShake() throws {
    var g = ShakeGesture()
    // Four flicks a second at 1.8 g: lighter than a hard shake.
    let peak = try XCTUnwrap(run(1.8, hz: 4, seconds: 1.5, on: &g))
    XCTAssertGreaterThanOrEqual(peak, 1.5)
  }

  func testOnePushIsNotAShake() {
    var g = ShakeGesture()
    var hit = false
    // Setting the phone down: one hard push the same way, then nothing.
    for i in 0..<50 { if g.feed(x: 0, y: i < 5 ? -2.5 : 0, z: 0, t: Double(i) * 0.02) != nil { hit = true } }
    XCTAssertFalse(hit)
  }

  func testASlowSwayIsNotAShake() {
    var g = ShakeGesture()
    // Walking's swing: strong enough, but one change of direction per second at most.
    XCTAssertNil(run(1.7, hz: 0.5, seconds: 4, on: &g))
  }

  func testAWeakJiggleIsNotAShake() {
    var g = ShakeGesture()
    XCTAssertNil(run(1.0, hz: 5, seconds: 3, on: &g))
  }

  func testOneShakeOpensOneSheet() {
    var g = ShakeGesture()
    XCTAssertNotNil(run(2, hz: 4, seconds: 1.2, on: &g))
    // Still shaking inside the cooldown: nothing more.
    XCTAssertNil(run(2, hz: 4, seconds: 1.0, start: 1.2, on: &g))
  }
}
