//  The Custom preset's dials, upright (story 184): drums by default, knobs, an arc, or the old sliders behind a
//  launch setting. The values, steps and ranges are CustomPreset's; this is only how a finger moves them — drag
//  distance or turned angle into whole steps, with the remainder carried, and the arc's angle to a value and back.

import Foundation

/// Which control sets Work, Rest and Rounds; the raw value is the launch setting's (`GRABBER_TIMER_DIAL`).
public enum DialStyle: String, CaseIterable, Sendable {
  case drums, knobs, arc, sliders
  /// The gym-first one: three large targets, a straight swipe or a tap, digits that fill the panel.
  public static let shipped = DialStyle.drums
}

/// Turns continuous movement (points dragged, degrees turned) into whole steps, carrying the remainder, so slow
/// movement still steps exactly once per unit and a reversal undoes what it did.
public struct StepAccumulator: Equatable, Sendable {
  public let unitsPerStep: Double
  public private(set) var carry = 0.0

  public init(unitsPerStep: Double) { self.unitsPerStep = unitsPerStep }

  /// Adds movement (positive is "more") and returns the whole steps it completes.
  public mutating func add(_ units: Double) -> Int {
    carry += units
    let steps = (carry / unitsPerStep).rounded(.towardZero)
    carry -= steps * unitsPerStep
    return Int(steps)
  }

  public mutating func reset() { carry = 0 }
}

public enum TimerDials {
  /// A drum: one step per this many points of drag — about a finger's width.
  public static let drumPointsPerStep = 28.0
  /// A knob: a detent every this many degrees, twenty to a turn.
  public static let knobDegreesPerStep = 18.0
  /// The arc runs from lower left, round the top, to lower right: 270°, 0° being straight up, clockwise.
  public static let arcStart = -135.0
  public static let arcSweep = 270.0

  /// `value` moved by whole `steps` of `step`, held in `range`; `hitEnd` when the range stopped it.
  public static func stepped(_ value: Int, by steps: Int, step: Int, range: ClosedRange<Int>) -> (value: Int, hitEnd: Bool) {
    let wanted = value + steps * step
    let held = min(range.upperBound, max(range.lowerBound, wanted))
    return (held, held != wanted)
  }

  /// A flick goes further: 1× under 600 points a second, 2× under 1 500, 4× beyond.
  public static func speedMultiplier(pointsPerSecond: Double) -> Double {
    let v = abs(pointsPerSecond)
    return v < 600 ? 1 : v < 1500 ? 2 : 4
  }

  /// Where `point` is around `center`, in degrees: 0 straight up, clockwise, in (-180, 180]. Screen coordinates
  /// (y grows downward).
  public static func angle(x: Double, y: Double, centerX: Double, centerY: Double) -> Double {
    let degrees = atan2(x - centerX, centerY - y) * 180 / .pi
    return degrees == -180 ? 180 : degrees
  }

  /// The shortest turn from one angle to another, in (-180, 180]: crossing the bottom is not a full turn back.
  public static func turn(from a: Double, to b: Double) -> Double {
    var d = (b - a).truncatingRemainder(dividingBy: 360)
    if d > 180 { d -= 360 }
    if d <= -180 { d += 360 }
    return d
  }

  /// The arc's value under an angle: snapped to the step; the gap at the bottom goes to the nearer end.
  public static func arcValue(angle: Double, range: ClosedRange<Int>, step: Int) -> Int {
    let a = min(arcStart + arcSweep, max(arcStart, angle))
    let fraction = (a - arcStart) / arcSweep
    let raw = Double(range.lowerBound) + fraction * Double(range.upperBound - range.lowerBound)
    return CustomPreset.snap(Int(raw.rounded()), step: step, range: range)
  }

  /// Where a value's handle sits on the arc.
  public static func arcAngle(value: Int, range: ClosedRange<Int>) -> Double {
    let span = Double(max(1, range.upperBound - range.lowerBound))
    let clamped = Double(min(range.upperBound, max(range.lowerBound, value)))
    return arcStart + (clamped - Double(range.lowerBound)) / span * arcSweep
  }
}
