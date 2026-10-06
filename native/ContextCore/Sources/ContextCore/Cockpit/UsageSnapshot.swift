//  The live tile's reading (story 136; spec docs/superpowers/specs/2026-10-06-native-live-tile-design.md): the last
//  `GET /usage` the app loaded and when, as the app hands it to the widget through the App Group. The widget draws
//  the strip from it as of the moment it draws, so the countdown to the reset, the *to spend* nudge and the age move
//  on their own between loads.

import Foundation

public struct UsageSnapshot: Codable, Equatable, Sendable {
  public var usage: CockpitUsage
  public var fetchedAt: Date

  /// Older than this, the tile's age turns orange.
  public static let oldAfter: TimeInterval = 3600

  public init(usage: CockpitUsage, fetchedAt: Date) {
    self.usage = usage
    self.fetchedAt = fetchedAt
  }

  public func encoded() -> Data {
    (try? JSONEncoder().encode(self)) ?? Data()
  }

  /// Nil for nothing written yet, or for what this build cannot read (the tile then shows its placeholder).
  public static func decode(_ data: Data?) -> UsageSnapshot? {
    guard let data, !data.isEmpty else { return nil }
    return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
  }

  /// The strip as of `now`: the weekly countdown worked out again from the reset's instant, when the reading has one.
  public func strip(now: Date) -> UsageStrip? {
    var u = usage
    if let at = u.resets.flatMap(UsageStrip.instant) {
      let seconds = at.timeIntervalSince(now)
      u.resetsIn = seconds > 0 ? Self.countdown(seconds: seconds) : nil
    }
    return UsageStrip(u, now: now)
  }

  public func isOld(now: Date) -> Bool { now.timeIntervalSince(fetchedAt) >= Self.oldAfter }

  /// "just now", "12m ago", "2h ago", "3d ago".
  public func age(now: Date) -> String {
    let s = max(0, now.timeIntervalSince(fetchedAt))
    if s < 60 { return "just now" }
    if s < 3600 { return "\(Int(s / 60))m ago" }
    if s < 86400 { return "\(Int(s / 3600))h ago" }
    return "\(Int(s / 86400))d ago"
  }

  /// The Cockpit's countdown style: "23D10H", "14H", "45M".
  public static func countdown(seconds: Double) -> String {
    let minutes = Int(seconds / 60)
    let days = minutes / 1440, hours = minutes % 1440 / 60
    if days > 0 { return hours > 0 ? "\(days)D\(hours)H" : "\(days)D" }
    if hours > 0 { return "\(hours)H" }
    return "\(max(1, minutes))M"
  }
}
