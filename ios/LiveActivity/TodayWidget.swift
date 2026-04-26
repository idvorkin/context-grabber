import SwiftUI
import WidgetKit

// MARK: - Entry

struct TodayEntry: TimelineEntry {
  let date: Date
  let steps: Int?
  let sleepHours: Double?
  let exerciseMinutes: Int?
  let grabbedAt: Date?
  /// Today's tap counter. Auto-resets on the JS side (and inside the
  /// CounterIncrementIntent) when `counterDate` doesn't match today's local
  /// date — surfaced here as the value the widget should display.
  let counter: Int

  static var empty: TodayEntry {
    TodayEntry(date: Date(), steps: nil, sleepHours: nil, exerciseMinutes: nil, grabbedAt: nil, counter: 0)
  }

  /// Attempt to load a snapshot the app wrote to shared UserDefaults.
  /// Returns an empty entry if the App Group hasn't been set up yet.
  static func load() -> TodayEntry {
    let suite = UserDefaults(suiteName: "group.com.idvorkin.contextgrabber")
    guard let suite = suite else { return .empty }
    let steps = suite.object(forKey: "steps") as? Int
    let sleep = suite.object(forKey: "sleepHours") as? Double
    let ex = suite.object(forKey: "exerciseMinutes") as? Int
    let grabbedMs = suite.object(forKey: "grabbedAt") as? Double
    let grabbedAt = grabbedMs.map { Date(timeIntervalSince1970: $0 / 1000.0) }

    // Counter: read the raw value, but treat it as 0 if its date is stale —
    // the JS side does the same on app foreground; this prevents a yesterday
    // value from appearing on the widget after midnight before the app runs.
    let storedDate = suite.string(forKey: "counterDate")
    let storedCounter = suite.object(forKey: "counter") as? Int ?? 0
    let today = TodayEntry.todayLocalDateKey()
    let counter = (storedDate == today) ? storedCounter : 0

    return TodayEntry(date: Date(), steps: steps, sleepHours: sleep, exerciseMinutes: ex, grabbedAt: grabbedAt, counter: counter)
  }

  static func todayLocalDateKey() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone.current
    return f.string(from: Date())
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

      // Counter row: tally marks + value (handwritten font) on the left,
      // +1 button on the right. iOS 17+ uses Button(intent:) so the +1
      // happens in-widget; older iOS falls back to a deep link.
      HStack(spacing: 8) {
        Link(destination: URL(string: "grabber://main")!) {
          HStack(spacing: 8) {
            TallyMarksView(value: entry.counter, color: .cyan)
            Text("\(entry.counter)")
              .font(.custom("Marker Felt", size: 22))
              .foregroundColor(.cyan)
              .frame(minWidth: 28, alignment: .trailing)
          }
        }

        Spacer()

        if #available(iOS 17.0, *) {
          Button(intent: CounterIncrementIntent()) {
            Text("+1")
              .font(.system(size: 13, weight: .bold))
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(Color.cyan.opacity(0.15))
              .foregroundColor(.cyan)
              .cornerRadius(8)
          }
          .buttonStyle(.plain)
        } else {
          Link(destination: URL(string: "grabber://counter/inc")!) {
            Text("+1")
              .font(.system(size: 13, weight: .bold))
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(Color.cyan.opacity(0.15))
              .foregroundColor(.cyan)
              .cornerRadius(8)
          }
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
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }

        Link(destination: URL(string: "grabber://timer?preset=2min&autostart=1")!) {
          Text("2 MIN")
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.purple.opacity(0.15))
            .foregroundColor(.purple)
            .cornerRadius(8)
        }

        Link(destination: URL(string: "grabber://timer?preset=5-1&autostart=1")!) {
          Text("5-1")
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.orange.opacity(0.15))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
      }
    }
    .padding(12)
    .widgetURL(URL(string: "grabber://main")!)
    .widgetBackgroundCompat()
  }

  private func formatInt(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
  }
}

// MARK: - Tally marks subview

/// 5-stroke tally rendering: groups of 4 vertical marks + a diagonal slash
/// for the 5th, matching the dashboard `<TallyCounter>` JS component. Caps
/// at 50 (10 groups) to keep the widget layout from overflowing — beyond
/// that the numeric value carries the load.
struct TallyMarksView: View {
  let value: Int
  let color: Color

  private let strokeWidth: CGFloat = 2
  private let strokeHeight: CGFloat = 18
  private let groupSpacing: CGFloat = 6
  private let markSpacing: CGFloat = 2
  private let maxGroups = 10

  var body: some View {
    let safe = max(0, value)
    let fullGroups = min(safe / 5, maxGroups)
    let remainder = safe / 5 < maxGroups ? safe % 5 : 0

    HStack(spacing: groupSpacing) {
      ForEach(0..<fullGroups, id: \.self) { _ in
        ZStack {
          HStack(spacing: markSpacing) {
            ForEach(0..<4, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: strokeWidth, height: strokeHeight)
            }
          }
          // Diagonal slash through the group of 4
          Rectangle()
            .fill(color)
            .frame(width: strokeWidth * 8, height: 1.5)
            .rotationEffect(.degrees(-30))
        }
      }
      if remainder > 0 {
        HStack(spacing: markSpacing) {
          ForEach(0..<remainder, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 1)
              .fill(color)
              .frame(width: strokeWidth, height: strokeHeight)
          }
        }
      }
    }
  }
}

// MARK: - Background compat

/// `containerBackground(for: .widget)` is iOS 17+; the deployment target supports older OSes,
/// so fall back to a plain `background(...)` on older systems where the new API is absent.
extension View {
  @ViewBuilder
  func widgetBackgroundCompat() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) {
        Color(UIColor.systemBackground)
      }
    } else {
      self.background(Color(UIColor.systemBackground))
    }
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
