import SwiftUI
import WidgetKit

// MARK: - Entry

struct TodayEntry: TimelineEntry {
  let date: Date
  let steps: Int?
  let sleepHours: Double?
  let exerciseMinutes: Int?
  let grabbedAt: Date?

  static var empty: TodayEntry {
    TodayEntry(date: Date(), steps: nil, sleepHours: nil, exerciseMinutes: nil, grabbedAt: nil)
  }

  /// Attempt to load a snapshot the app wrote to shared UserDefaults.
  /// Returns an empty entry if the App Group hasn't been set up yet (v1 ships without the write
  /// path; see context-grabber-don). The widget still renders tap-zones correctly in that case.
  static func load() -> TodayEntry {
    let suite = UserDefaults(suiteName: "group.com.idvorkin.contextgrabber")
    guard let suite = suite else { return .empty }
    let steps = suite.object(forKey: "steps") as? Int
    let sleep = suite.object(forKey: "sleepHours") as? Double
    let ex = suite.object(forKey: "exerciseMinutes") as? Int
    let grabbedMs = suite.object(forKey: "grabbedAt") as? Double
    let grabbedAt = grabbedMs.map { Date(timeIntervalSince1970: $0 / 1000.0) }
    return TodayEntry(date: Date(), steps: steps, sleepHours: sleep, exerciseMinutes: ex, grabbedAt: grabbedAt)
  }
}

// MARK: - Provider

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry { .empty }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(TodayEntry.load())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let entry = TodayEntry.load()
    // Safety net: refresh every 30 min even without an explicit reload from the app.
    let next = Date().addingTimeInterval(30 * 60)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

// MARK: - View

struct TodayWidgetView: View {
  let entry: TodayEntry

  private static let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE"
    return f
  }()

  var body: some View {
    // The widgetURL modifier on the outer VStack sets a default tap → main. The timer-tile
    // Links below override within their own bounds.
    VStack(alignment: .leading, spacing: 8) {
      // Top row: date label + arrow affordance
      HStack {
        Text("Today · \(Self.dayFormatter.string(from: entry.grabbedAt ?? entry.date))")
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.secondary)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.secondary)
      }

      // Metrics block
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 8) {
          Text(entry.steps.map { formatInt($0) } ?? "—")
            .font(.system(size: 18, weight: .bold))
          Text("steps").font(.system(size: 13)).foregroundColor(.secondary)
          Text("·").foregroundColor(.secondary)
          Text(entry.sleepHours.map { String(format: "%.1fh", $0) } ?? "—")
            .font(.system(size: 18, weight: .bold))
          Text("sleep").font(.system(size: 13)).foregroundColor(.secondary)
        }
        HStack(spacing: 4) {
          Text(entry.exerciseMinutes.map { "\($0) min" } ?? "—")
            .font(.system(size: 14, weight: .medium))
          Text("exercise").font(.system(size: 13)).foregroundColor(.secondary)
        }
      }

      Divider().padding(.vertical, 2)

      // Bottom row: timer label + 2 preset tiles
      HStack(spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: "timer")
          Text("Timer").font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.secondary)

        Spacer()

        Link(destination: URL(string: "grabber://timer?preset=1min&autostart=1")!) {
          Text("1 MIN")
            .font(.system(size: 13, weight: .bold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }

        Link(destination: URL(string: "grabber://timer?preset=5-1&autostart=1")!) {
          Text("5-1")
            .font(.system(size: 13, weight: .bold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
      }
    }
    .padding(12)
    .widgetURL(URL(string: "grabber://main")!)
  }

  private func formatInt(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
  }
}

// MARK: - Widget

struct TodayWidget: Widget {
  let kind = "TodayWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      TodayWidgetView(entry: entry)
    }
    .configurationDisplayName("Today")
    .description("Today's snapshot + one-tap timers")
    .supportedFamilies([.systemMedium])
  }
}
