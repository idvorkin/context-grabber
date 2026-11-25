//  #342, story 254 (home-screen spec, "A counter's week"): press and hold Balloons or Magic for its last seven days,
//  each with − and +. The steps stay here until Confirm saves the days that changed.

import Foundation

public struct CounterWeek: Equatable, Sendable {
  public struct Day: Equatable, Sendable {
    public let day: String
    public let daysAgo: Int
    /// "today · Sun, Oct 18", "yesterday · Sat, Oct 17", "3 days ago · Thu, Oct 15".
    public let label: String
    /// The weekday, short ("Wed"), for the week's graph (#1493).
    public let weekday: String
    /// What the other devices counted (#376): the count never goes below it, since only this device's share moves.
    let others: Int
    let savedOwn: Int
    public internal(set) var own: Int

    public var count: Int { others + own }
    public var checked: Bool { count > 0 }
  }

  /// A day to save: this device's new count for it, the step from what was saved, and the day's new total.
  public struct Change: Equatable, Sendable {
    public let day: String
    public let daysAgo: Int
    public let own: Int
    public let step: Int
    public let count: Int
  }

  public static let length = 7

  public let item: DailyItem
  /// Today first, then the six days before.
  public private(set) var days: [Day]

  public init(_ item: DailyItem, today: String, strip: DailyStrip, calendar: Calendar = .current) throws {
    self.item = item
    days = try (0..<Self.length).compactMap { ago in
      guard let day = DailyStrip.day(ago, before: today, calendar: calendar) else { return nil }
      let own = try strip.ownValue(item, day: day)
      return Day(
        day: day, daysAgo: ago, label: DailyStrip.backdateLabel(ago, today: today, calendar: calendar),
        weekday: DailyStrip.weekday(day, calendar: calendar),
        others: max(0, try strip.value(item, day: day) - own), savedOwn: own, own: own)
    }
  }

  /// One more or one fewer on the day at `index`; never below 0 of this device's own.
  public mutating func step(_ index: Int, by step: Int) {
    guard days.indices.contains(index) else { return }
    days[index].own = max(0, days[index].own + step)
  }

  public var changes: [Change] {
    days.filter { $0.own != $0.savedOwn }.map {
      Change(day: $0.day, daysAgo: $0.daysAgo, own: $0.own, step: $0.own - $0.savedOwn, count: $0.count)
    }
  }

  /// One bar of the week's graph (#1493, story 572).
  public struct Bar: Equatable, Sendable {
    public let day: String
    /// The weekday's initial under the bar: "W".
    public let initial: String
    public let count: Int
    public let isToday: Bool
  }

  /// The seven days oldest first, today last, with the sheet's counts as they are now (unconfirmed steps included).
  public var graph: [Bar] {
    days.reversed().map {
      Bar(day: $0.day, initial: String($0.weekday.prefix(1)), count: $0.count, isToday: $0.daysAgo == 0)
    }
  }

  /// What VoiceOver reads for the graph: "Thu 0, Fri 0, … Wed 0".
  public var graphLabel: String {
    days.reversed().map { "\($0.weekday) \($0.count)" }.joined(separator: ", ")
  }
}
