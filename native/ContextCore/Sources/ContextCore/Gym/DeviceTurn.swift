//  Which way the phone is turned, from its accelerometer — so the Gym Timer's display can turn with it while
//  the app's window stays portrait (story 109).
//
//  Device axes (Apple's): +x out of the right edge, +y out of the top edge, +z out of the screen. Readings are
//  in g. Held upright, gravity reads y ≈ -1; turned so the top points left, x ≈ -1; top to the right, x ≈ +1.
//
//  Pure: the same reading and the same previous answer give the same answer, so the margins are tested rather
//  than tuned on the phone.

public enum DeviceTurn: String, Equatable, Sendable {
  case upright, left, right

  /// Past this (in g) an axis is "down". Below `release` it is no longer; the gap is the margin against
  /// flicker near 45°.
  public static let engage = 0.6
  public static let release = 0.4

  /// Degrees, clockwise positive, to rotate a portrait-laid-out display so it reads upright. The phone turned
  /// counter-clockwise (top to the left) needs the display turned clockwise to undo it.
  public var rotationDegrees: Double {
    switch self {
    case .left: return 90
    case .right: return -90
    case .upright: return 0
    }
  }

  /// Classify one reading given the previous answer. Near-flat (neither axis pulling) keeps the previous
  /// answer: a phone laid on a table stays as it was last held.
  public static func classify(x: Double, y: Double, previous: DeviceTurn) -> DeviceTurn {
    let ax = abs(x)
    let ay = abs(y)
    switch previous {
    case .upright:
      // Only a clear sideways pull turns the display.
      if ax >= engage, ax > ay { return x < 0 ? .left : .right }
      return .upright
    case .left, .right:
      // Stay turned — following the side — until gravity clearly leaves the x axis…
      if ax >= release { return x < 0 ? .left : .right }
      // …then upright only once y clearly pulls (a flat phone keeps its turn).
      if ay >= engage { return .upright }
      return previous
    }
  }
}
