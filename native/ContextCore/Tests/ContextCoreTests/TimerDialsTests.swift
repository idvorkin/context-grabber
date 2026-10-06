//  Story 184: the Custom preset's dials — drag and turn into whole steps, the arc's angles — keep exactly the
//  custom preset's steps and ranges.

import XCTest

@testable import ContextCore

final class TimerDialsTests: XCTestCase {
  func testTheShippedDialIsTheDrums() {
    XCTAssertEqual(DialStyle.shipped, .drums)
    XCTAssertEqual(DialStyle(rawValue: "knobs"), .knobs)
    XCTAssertNil(DialStyle(rawValue: "wheel"))
  }

  func testAccumulatorStepsOncePerUnitAndCarriesTheRest() {
    var acc = StepAccumulator(unitsPerStep: 28)
    XCTAssertEqual(acc.add(10), 0)
    XCTAssertEqual(acc.add(10), 0)
    XCTAssertEqual(acc.add(10), 1, "30 points: one step, 2 carried")
    XCTAssertEqual(acc.carry, 2, accuracy: 1e-9)
    XCTAssertEqual(acc.add(56), 2)
    XCTAssertEqual(acc.add(-30), -1, "back the other way")
    XCTAssertEqual(acc.add(-1), 0)
    acc.reset()
    XCTAssertEqual(acc.carry, 0)
    // Many tiny moves add up to exactly as many steps as one big one.
    var slow = StepAccumulator(unitsPerStep: 18)
    var steps = 0
    for _ in 0..<360 { steps += slow.add(1) }
    XCTAssertEqual(steps, 20, "a knob's whole turn is twenty detents")
  }

  func testSteppingKeepsTheCustomPresetsRanges() {
    XCTAssertEqual(
      TimerDials.stepped(60, by: 1, step: CustomPreset.stepSeconds, range: CustomPreset.workRange).value, 70)
    let top = TimerDials.stepped(590, by: 3, step: CustomPreset.stepSeconds, range: CustomPreset.workRange)
    XCTAssertEqual(top.value, 600)
    XCTAssertTrue(top.hitEnd)
    let bottom = TimerDials.stepped(10, by: -1, step: CustomPreset.stepSeconds, range: CustomPreset.restRange)
    XCTAssertEqual(bottom.value, 0)
    XCTAssertFalse(bottom.hitEnd)
    XCTAssertTrue(TimerDials.stepped(0, by: -1, step: CustomPreset.stepSeconds, range: CustomPreset.restRange).hitEnd)
    XCTAssertEqual(TimerDials.stepped(20, by: 5, step: 1, range: CustomPreset.roundsRange).value, 20)
  }

  func testAFlickGoesFurther() {
    XCTAssertEqual(TimerDials.speedMultiplier(pointsPerSecond: 200), 1)
    XCTAssertEqual(TimerDials.speedMultiplier(pointsPerSecond: -900), 2)
    XCTAssertEqual(TimerDials.speedMultiplier(pointsPerSecond: 2500), 4)
    // 1:00 to 10:00 is 54 steps: at four times, about 380 points — one long flick on a phone screen.
    XCTAssertLessThan(54 / 4 * TimerDials.drumPointsPerStep, 400)
  }

  func testAnglesAroundACentre() {
    XCTAssertEqual(TimerDials.angle(x: 0, y: -10, centerX: 0, centerY: 0), 0, accuracy: 1e-9, "up")
    XCTAssertEqual(TimerDials.angle(x: 10, y: 0, centerX: 0, centerY: 0), 90, accuracy: 1e-9, "right")
    XCTAssertEqual(TimerDials.angle(x: 0, y: 10, centerX: 0, centerY: 0), 180, accuracy: 1e-9, "down")
    XCTAssertEqual(TimerDials.angle(x: -10, y: 0, centerX: 0, centerY: 0), -90, accuracy: 1e-9, "left")
    XCTAssertEqual(TimerDials.turn(from: 170, to: -170), 20, accuracy: 1e-9, "across the bottom, clockwise")
    XCTAssertEqual(TimerDials.turn(from: -170, to: 170), -20, accuracy: 1e-9)
    XCTAssertEqual(TimerDials.turn(from: 10, to: 30), 20, accuracy: 1e-9)
  }

  func testTheArcMapsItsSweepOntoTheRange() {
    let work = CustomPreset.workRange
    XCTAssertEqual(TimerDials.arcValue(angle: -135, range: work, step: 10), 10)
    XCTAssertEqual(TimerDials.arcValue(angle: 135, range: work, step: 10), 600)
    XCTAssertEqual(TimerDials.arcValue(angle: 0, range: work, step: 10), 310, "the top is the middle, 5:05, on its step")
    XCTAssertEqual(TimerDials.arcValue(angle: 170, range: work, step: 10), 600, "the gap goes to the nearer end")
    XCTAssertEqual(TimerDials.arcValue(angle: -170, range: work, step: 10), 10)
    for value in stride(from: 0, through: 300, by: 10) {
      let a = TimerDials.arcAngle(value: value, range: CustomPreset.restRange)
      XCTAssertEqual(TimerDials.arcValue(angle: a, range: CustomPreset.restRange, step: 10), value, "round trip \(value)")
      XCTAssertEqual(value % CustomPreset.stepSeconds, 0)
    }
    XCTAssertEqual(TimerDials.arcAngle(value: 60, range: work), -135 + 50.0 / 590 * 270, accuracy: 1e-9)
  }
}
