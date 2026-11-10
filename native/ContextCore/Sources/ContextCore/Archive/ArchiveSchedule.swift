//  Story 270: when the archive runs. Every four hours or so (a background refresh, and a foreground once that long
//  has passed), and an end-of-day batch (a background processing task, which iOS gives minutes rather than
//  seconds, so the day's last pages and a backfill's long tail go then).

import Foundation

public enum ArchiveSchedule {
  /// iOS owns the exact moment; this is the earliest the next refresh is asked for.
  public static let interval: TimeInterval = 4 * 3600
  /// The end-of-day batch, local time.
  public static let dailyHour = 23
  public static let dailyMinute = 30
  /// The background task identifiers (Info.plist names the same two).
  public static let refreshTask = "com.idvorkin.grabbernative.archive.refresh"
  public static let dailyTask = "com.idvorkin.grabbernative.archive.daily"

  /// Whether a foreground or launch should run the archive now (spec: "When a run is due"). Only a run that got
  /// somewhere holds the next one off for the interval; one that never reached the Cockpit is due at once.
  public static func isDue(_ state: ArchiveState, now: Date) -> Bool {
    let since: Int64
    switch state {
    case .never, .blocked(.cockpitAway, _): return true
    case .caughtUp(let at), .backfilling(let at), .blocked(_, let at): since = at
    }
    return now.timeIntervalSince(Date(timeIntervalSince1970: Double(since) / 1000)) >= interval
  }

  /// The next end-of-day slot after `now`: today's if it is still ahead, else tomorrow's.
  public static func nextDaily(after now: Date, calendar: Calendar) -> Date {
    var at = DateComponents()
    at.hour = dailyHour
    at.minute = dailyMinute
    return calendar.nextDate(after: now, matching: at, matchingPolicy: .nextTime) ?? now.addingTimeInterval(interval)
  }
}
