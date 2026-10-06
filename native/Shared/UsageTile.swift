//  The live tile (story 136; spec docs/superpowers/specs/2026-10-06-native-live-tile-design.md): the usage strip on
//  the home screen, and on the medium size three one-tap starts. The app writes each reading it loads into the App
//  Group and asks WidgetKit to redraw; the widget only draws what the app wrote. Compiled into both: the app writes,
//  the widget extension reads and draws.

import ContextCore
import SwiftUI
import WidgetKit

enum UsageTileStore {
  /// Shared by the app and the widget extension (project.yml gives both the entitlement).
  static let group = "group.com.idvorkin.grabbernative"
  static let kind = "UsageTile"
  private static let key = "usage_snapshot"

  /// False when the App Group is not there (a build signed without it).
  @discardableResult
  static func write(_ snapshot: UsageSnapshot) -> Bool {
    guard let defaults = UserDefaults(suiteName: group) else { return false }
    defaults.set(snapshot.encoded(), forKey: key)
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    return true
  }

  static func read() -> UsageSnapshot? {
    UsageSnapshot.decode(UserDefaults(suiteName: group)?.data(forKey: key))
  }
}

/// The links the medium tile's buttons open: the same as the Links screen's (story 135).
enum UsageTileLinks {
  static let home = URL(string: AppLink.link(for: .home))!
  static let timer = URL(string: AppLink.link(for: .timer(TimerLink(start: true))))!
  static let breathe = URL(string: AppLink.link(for: .breathe(BreatheLink(start: true))))!
  static let call = URL(string: AppLink.link(for: .call(via: nil)))!
}

struct UsageTileView: View {
  let snapshot: UsageSnapshot?
  let now: Date
  let family: WidgetFamily

  var body: some View {
    Group {
      if family == .systemMedium {
        HStack(spacing: 12) {
          reading.frame(maxWidth: .infinity, alignment: .leading)
          VStack(spacing: 6) {
            QuickStart(title: "Gym Timer", icon: "timer", url: UsageTileLinks.timer)
            QuickStart(title: "Breathe", icon: "wind", url: UsageTileLinks.breathe)
            QuickStart(title: "Call Larry", icon: "phone.fill", url: UsageTileLinks.call)
          }
          .frame(width: 118)
        }
      } else {
        reading
      }
    }
    .widgetURL(UsageTileLinks.home)
  }

  @ViewBuilder private var reading: some View {
    if let snapshot, let strip = snapshot.strip(now: now) {
      VStack(alignment: .leading, spacing: 7) {
        ForEach(strip.bars, id: \.label) { TileBar(bar: $0) }
        Spacer(minLength: 0)
        VStack(alignment: .leading, spacing: 1) {
          if let spend = strip.spendNote {
            Text(spend).fontWeight(.semibold).foregroundStyle(.green)
          }
          Text(snapshot.age(now: now)).foregroundStyle(snapshot.isOld(now: now) ? .orange : .secondary)
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      }
    } else {
      VStack(alignment: .leading, spacing: 4) {
        Image(systemName: "gauge.with.dots.needle.67percent").font(.title3).foregroundStyle(.secondary)
        Spacer(minLength: 0)
        Text("Usage left").font(.caption.weight(.semibold))
        Text("Open Grabber Native").font(.caption2).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// A bar as the home screen's strip draws it: a label, the number left, a fill of what remains.
private struct TileBar: View {
  let bar: UsageStrip.Bar

  var color: Color {
    switch bar.level {
    case .ok: .accentColor
    case .low: .orange
    case .critical: .red
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline) {
        Text(bar.label).font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
        Spacer(minLength: 2)
        Text(bar.text).font(.caption.weight(.semibold).monospacedDigit())
          .foregroundStyle(bar.level == .ok ? Color.primary : color)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.secondary.opacity(0.2))
          Capsule().fill(color).frame(width: max(4, geo.size.width * bar.left))
        }
      }
      .frame(height: 5)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(bar.label) \(bar.text) left")
  }
}

private struct QuickStart: View {
  let title: String
  let icon: String
  let url: URL

  var body: some View {
    Link(destination: url) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}
