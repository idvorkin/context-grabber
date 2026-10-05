//  The Gym Timer's Custom preset: a work time in ten-second steps, a rest time, a round count — remembered
//  across launches, untouched by RESET (story 101). Pure; GymStore does the remembering.

import Foundation

public struct CustomPreset: Equatable, Codable, Sendable {
  /// Seconds of work per round.
  public var work: Int
  /// Seconds of rest between rounds; 0 for none.
  public var rest: Int
  public var rounds: Int

  public init(work: Int, rest: Int, rounds: Int) {
    self.work = work
    self.rest = rest
    self.rounds = rounds
  }

  public static let id = "custom"
  public static let stepSeconds = 10
  public static let workRange = 10...600
  public static let restRange = 0...300
  public static let roundsRange = 1...20

  /// A fresh Custom is the 1 MIN preset's shape.
  public static let `default` = CustomPreset(work: 60, rest: 10, rounds: 5)

  /// The nearest step inside the range.
  public static func snap(_ value: Int, step: Int, range: ClosedRange<Int>) -> Int {
    let clamped = min(range.upperBound, max(range.lowerBound, value))
    return Int((Double(clamped) / Double(step)).rounded()) * step
  }

  /// Every value on its grid and in its range.
  public var normalized: CustomPreset {
    CustomPreset(
      work: Self.snap(work, step: Self.stepSeconds, range: Self.workRange),
      rest: Self.snap(rest, step: Self.stepSeconds, range: Self.restRange),
      rounds: Self.snap(rounds, step: 1, range: Self.roundsRange))
  }

  /// From the stored JSON; missing fields take the default's, garbage is the default.
  public static func decode(_ json: String?) -> CustomPreset {
    guard let json, let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    else { return .default }
    func int(_ key: String, _ fallback: Int) -> Int { (object[key] as? NSNumber)?.intValue ?? fallback }
    return CustomPreset(
      work: int("work", Self.default.work), rest: int("rest", Self.default.rest),
      rounds: int("rounds", Self.default.rounds)
    ).normalized
  }

  public var encoded: String {
    let n = normalized
    return "{\"work\":\(n.work),\"rest\":\(n.rest),\"rounds\":\(n.rounds)}"
  }

  /// What the timer runs. The ready count is 5 s up to a minute and a half, 10 s beyond, as the fixed presets do.
  public var profile: TimerProfile {
    TimerProfile(name: Self.id, workTime: work, restTime: rest, rounds: rounds, prepTime: work > 90 ? 10 : 5)
  }
}

/// `m:ss`, for the face and the sliders.
public func formatMinutesSeconds(_ seconds: Int) -> String {
  String(format: "%d:%02d", seconds / 60, seconds % 60)
}
