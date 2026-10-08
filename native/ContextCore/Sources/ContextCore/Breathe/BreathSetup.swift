//  Story 241: the breath length chosen on the setup screen, as the settings remember it. A preset is its seconds;
//  Custom is its own In and Out, which never follow a preset chosen later (#200).

import Foundation

public struct BreathSetup: Equatable, Sendable {
  public static let breathKey = "breathe_breath_seconds"
  public static let customKey = "breathe_custom"
  public static let customInKey = "breathe_custom_in"
  public static let customOutKey = "breathe_custom_out"

  /// The preset's seconds, or nil for Custom.
  public var preset: Int?
  public var customIn: Int
  public var customOut: Int

  /// What the settings hold. A breath from the old slider becomes its preset if one matches, else Custom at that
  /// length both ways. `seeds` are the Custom sides the settings do not hold yet: saving them now pins them, so a
  /// preset chosen later cannot change an In or Out never touched.
  public static func restore(_ setting: (String) -> String?) -> (setup: BreathSetup, seeds: [(key: String, value: String)]) {
    let stored = setting(breathKey).flatMap(Int.init) ?? BreathPlan.defaultBreath
    let custom = setting(customKey) == "1" || !BreathPlan.presets.contains(stored)
    let storedIn = setting(customInKey).flatMap(Int.init)
    let storedOut = setting(customOutKey).flatMap(Int.init)
    var seeds: [(key: String, value: String)] = []
    if storedIn == nil { seeds.append((customInKey, String(stored))) }
    if storedOut == nil { seeds.append((customOutKey, String(stored))) }
    return (BreathSetup(preset: custom ? nil : stored, customIn: storedIn ?? stored, customOut: storedOut ?? stored), seeds)
  }
}
