//  How the breathing circle draws the breath (story 240, #147): four calm styles, remembered in the settings table.

public enum BreathStyle: String, CaseIterable, Sendable {
  case line, glow, beads, tide

  public static let `default` = BreathStyle.line
  public static let settingKey = "breathe_style"
  /// Beads around the circle; an even number, so the two sides light in pairs.
  public static let beadCount = 24

  public static func decode(_ raw: String?) -> BreathStyle {
    raw.flatMap(BreathStyle.init(rawValue:)) ?? .default
  }

  public var label: String {
    switch self {
    case .line: "Line"
    case .glow: "Glow"
    case .beads: "Beads"
    case .tide: "Tide"
    }
  }

  public var blurb: String {
    switch self {
    case .line: "A steady ring around the edge."
    case .glow: "A soft ring led by a small light."
    case .beads: "Beads lighting in pairs, bottom to top."
    case .tide: "The circle fills like rising water."
    }
  }

  /// How many beads are lit at `progress` (0…1): pairs from the bottom, both sides at once, the bottom one first.
  /// Bead 0 is at the bottom, bead `beadCount / 2` at the top.
  public static func litBeads(progress: Double) -> Set<Int> {
    let half = beadCount / 2
    guard progress > 0 else { return [] }
    // Steps from the bottom bead (0) to the top (half); a step is lit once the ring has reached it.
    let reached = Int((min(1, progress) * Double(half)).rounded(.down))
    var lit: Set<Int> = []
    for step in 0...reached {
      lit.insert(step)
      lit.insert((beadCount - step) % beadCount)
    }
    return lit
  }
}
