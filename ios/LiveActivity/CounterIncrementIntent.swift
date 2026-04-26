import Foundation

#if canImport(AppIntents)
import AppIntents
import WidgetKit

/// In-widget +1: increment the shared App Group counter without launching the
/// app. Reads `(counter, counterDate)` from UserDefaults, applies a daily
/// reset if the date is stale, increments, writes back, and asks WidgetCenter
/// to reload all timelines so the new value renders within ~1 second.
///
/// iOS 17+ only — older systems fall back to a deep link in TodayWidget.
@available(iOS 17.0, *)
struct CounterIncrementIntent: AppIntent {
  static var title: LocalizedStringResource = "Increment Counter"
  static var description = IntentDescription("Add one to today's tap counter.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult {
    let suite = "group.com.idvorkin.contextgrabber"
    guard let defaults = UserDefaults(suiteName: suite) else {
      return .result()
    }

    let today = CounterIncrementIntent.todayLocalDateKey()
    let storedDate = defaults.string(forKey: "counterDate")
    let storedValue = defaults.object(forKey: "counter") as? Int ?? 0
    let base = (storedDate == today) ? storedValue : 0
    let next = base + 1

    defaults.set(next, forKey: "counter")
    defaults.set(today, forKey: "counterDate")

    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }

  /// "YYYY-MM-DD" in the device's local time zone, matching the JS-side
  /// `todayLocalDateKey()` in lib/counter.ts.
  private static func todayLocalDateKey() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: Date())
  }
}
#endif
