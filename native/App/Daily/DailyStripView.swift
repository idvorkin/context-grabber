//  The daily strip on the home screen (#236, #238, #257; home-screen spec, "The daily strip"): one tight line. Gym,
//  Meditation and Journal are checks; Balloons and Magic count, a tap for one more and a long press for one fewer.

import ContextCore
import SwiftUI

struct DailyStripView: View {
  @ObservedObject var strip: DailyStripModel

  var body: some View {
    HStack(spacing: 0) {
      check(.gym, label: "Gym", done: strip.gymToday, note: gymNote) { KettlebellIcon(size: 17) }
      check(.meditation, label: "Meditation", done: strip.meditationToday, note: nil) {
        Image(systemName: "figure.mind.and.body").font(.system(size: 15))
      }
      check(.journal, label: "Journal", done: strip.value(.journal) > 0, note: nil) {
        Image(systemName: "book.closed.fill").font(.system(size: 15))
      }
      counter(.balloons, label: "Balloons", icon: "balloon.fill", color: .pink)
      counter(.magic, label: "Magic", icon: "wand.and.sparkles", color: .purple)
    }
    .font(.subheadline.weight(.medium))
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
      strip.refresh()
    }
    .onAppear { strip.refresh() }
  }

  private var gymNote: String? {
    guard !strip.gymToday else { return nil }
    return strip.daysSinceGym.map { "\($0)d" } ?? "–"
  }

  private func check<Icon: View>(
    _ item: DailyItem, label: String, done: Bool, note: String?, @ViewBuilder icon: () -> Icon
  ) -> some View {
    Button {
      strip.change(item)
    } label: {
      HStack(spacing: 5) {
        icon().foregroundStyle(done ? Color.green : Color.secondary)
        if done {
          Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.green)
        } else if let note {
          Text(note).font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(Color.secondary)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 28)
      .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .tint(.primary)  // the colours are the item's own, not the button's blue
    .sensoryFeedback(.selection, trigger: done)
    .accessibilityLabel(label)
    .accessibilityValue(done ? "done today" : note.map { $0 == "–" ? "never" : "\($0) since" } ?? "not yet")
    .accessibilityIdentifier("strip-\(item.rawValue)")
  }

  private func counter(_ item: DailyItem, label: String, icon: String, color: Color) -> some View {
    let count = strip.value(item)
    return HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 15)).foregroundStyle(count > 0 ? color : Color.secondary)
      Text("\(count)").font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(count > 0 ? Color.primary : Color.secondary)
        .contentTransition(.numericText())
    }
    .frame(maxWidth: .infinity, minHeight: 28)
    .contentShape(Rectangle())
    .onTapGesture { withAnimation(.snappy) { strip.change(item, by: 1) } }
    .onLongPressGesture { withAnimation(.snappy) { strip.change(item, by: -1) } }
    .sensoryFeedback(.increase, trigger: count)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue("\(count)")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { strip.change(item, by: 1) }
    .accessibilityAdjustableAction { direction in
      strip.change(item, by: direction == .increment ? 1 : -1)
    }
    .accessibilityIdentifier("strip-\(item.rawValue)")
  }
}

/// No kettlebell in SF Symbols: a bell under a handle, drawn in the current colour.
struct KettlebellIcon: View {
  let size: CGFloat

  var body: some View {
    ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
        .stroke(lineWidth: size * 0.14)
        .frame(width: size * 0.56, height: size * 0.46)
        .offset(y: size * 0.05)
      Circle()
        .frame(width: size * 0.78, height: size * 0.78)
        .offset(y: size * 0.22)
    }
    .frame(width: size, height: size, alignment: .top)
    .accessibilityHidden(true)
  }
}
