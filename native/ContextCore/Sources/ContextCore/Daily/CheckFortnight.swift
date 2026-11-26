//  #414, story 255: fourteen days of checks, oldest first. Edits stay here until Done saves the diff.

import Foundation

public struct CheckFortnight: Equatable, Sendable {
  public struct Day: Equatable, Sendable {
    public let day: String
    public let daysAgo: Int
    public let weekday: String
    public let number: String
    public let fullDate: String
    public let automatic: Bool
    let saved: Bool
    public fileprivate(set) var done: Bool
    /// #1503, story 570: what was done that day (Gym only), oldest-first rules in `DailyStrip.gymMarks`.
    public let marks: [GymDayMark]

    public var tag: String { daysAgo == 0 ? "today" : daysAgo == 1 ? "yest." : "" }
    public var changed: Bool { saved != done }
    public var accessibilityLabel: String {
      let base = "\(fullDate), \(done ? "done" : "not done")"
      let names = marks.map(\.name)
      guard let last = names.last else { return base }
      let list = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
      return base + ", " + list
    }
  }

  public let item: DailyItem
  public private(set) var days: [Day]

  public init(
    _ item: DailyItem, today: String, marked: Set<String>, automatic: Set<String> = [],
    marks: [String: [GymDayMark]] = [:], calendar: Calendar = .current
  ) {
    self.item = item
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    days = (0..<14).reversed().compactMap { ago in
      guard let key = DailyStrip.day(ago, before: today, calendar: calendar) else { return nil }
      formatter.dateFormat = "yyyy-MM-dd"
      guard let date = formatter.date(from: key) else { return nil }
      formatter.dateFormat = "EEEEE"
      let weekday = formatter.string(from: date)
      formatter.dateFormat = "d"
      let number = formatter.string(from: date)
      formatter.dateFormat = "EEEE MMMM d"
      let done = marked.contains(key) || automatic.contains(key)
      return Day(
        day: key, daysAgo: ago, weekday: weekday, number: number, fullDate: formatter.string(from: date),
        automatic: automatic.contains(key), saved: done, done: done, marks: marks[key] ?? [])
    }
  }

  public mutating func toggle(_ index: Int) {
    guard days.indices.contains(index), !days[index].automatic else { return }
    days[index].done.toggle()
  }

  public var changes: [Day] { days.filter(\.changed) }
  public var headline: String { "\(days.filter(\.done).count) of the last 14 days" }
  public var subline: String {
    let last: String
    switch days.last(where: \.done)?.daysAgo {
    case 0: last = "today"
    case 1: last = "yesterday"
    case .some(let ago): last = "\(ago) days ago"
    case nil: last = "not in two weeks"
    }
    let count = changes.count
    return "Last done \(last)" + (count == 0 ? "" : " · \(count) \(count == 1 ? "change" : "changes") to save")
  }
}
