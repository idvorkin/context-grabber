//  The daily strip on the home screen (#236, #238, #257; home-screen spec, "The daily strip"): one tight line. Gym,
//  Meditation and Journal are checks (a press and hold marks an earlier day, #290); Balloons and Magic count, a tap
//  for one more and a long press for one fewer.

import ContextCore
import SwiftUI

struct DailyStripView: View {
  @ObservedObject var strip: DailyStripModel
  /// #290: the check being marked for an earlier day, while its sheet is up.
  @State private var backdating: Backdate?
  /// A long press opened the sheet: the button's tap on release is not a second change.
  @State private var longPressed = false

  var body: some View {
    HStack(spacing: 0) {
      check(.gym, label: "Gym", done: strip.gymToday, note: gymNote) { KettlebellIcon(size: 17) }
      check(.meditation, label: "Meditation", done: strip.meditationToday, note: note(.meditation)) {
        Image(systemName: "figure.mind.and.body").font(.system(size: 15))
      }
      check(.journal, label: "Journal", done: strip.value(.journal) > 0, note: note(.journal)) {
        // #287, #299: a drawn quill, tinted like the other icons.
        StripGlyph(name: "strip-quill")
      }
      // #287, #299: a drawn balloon poodle.
      counter(.balloons, label: "Balloons", color: .pink) { StripGlyph(name: "strip-poodle") }
      counter(.magic, label: "Magic", color: .purple) {
        Image(systemName: "wand.and.sparkles").font(.system(size: 15))
      }
    }
    .font(.subheadline.weight(.medium))
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
      strip.refresh()
    }
    .onAppear { strip.refresh() }
    .sheet(
      item: $backdating, onDismiss: { longPressed = false },
      content: { b in
        BackdateSheet(label: b.label, today: strip.today) { strip.mark(b.item, day: $0, daysAgo: $1) }
      })
  }

  private var gymNote: String? {
    guard !strip.gymToday else { return nil }
    return note(.gym)
  }

  /// What VoiceOver says for a note (spec: "3 days since", "never"): the short "3d" spelled out.
  static func spoken(_ note: String) -> String {
    guard note != "–", let n = Int(note.dropLast()) else { return "never" }
    return n == 1 ? "1 day since" : "\(n) days since"
  }

  /// Days since the item's last day, as gym says it: "3d", or "–" when there has never been one.
  private func note(_ item: DailyItem) -> String { strip.daysSince[item].map { "\($0)d" } ?? "–" }

  private func check<Icon: View>(
    _ item: DailyItem, label: String, done: Bool, note: String?, @ViewBuilder icon: () -> Icon
  ) -> some View {
    Button {
      if longPressed {
        longPressed = false
        return
      }
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
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 0.5).onEnded { _ in
        longPressed = true
        backdating = Backdate(item: item, label: label)
      }
    )
    .accessibilityAction(named: "Mark an earlier day") { backdating = Backdate(item: item, label: label) }
    .accessibilityLabel(label)
    .accessibilityValue(done ? "done today" : note.map(Self.spoken) ?? "not yet")
    .accessibilityIdentifier("strip-\(item.rawValue)")
  }

  private func counter<Icon: View>(
    _ item: DailyItem, label: String, color: Color, @ViewBuilder icon: () -> Icon
  ) -> some View {
    let count = strip.value(item)
    return HStack(spacing: 5) {
      icon().foregroundStyle(count > 0 ? color : Color.secondary)
      // At 0, the days since the last day with any, in place of the 0 (2026-10-17).
      if count > 0 {
        Text("\(count)").font(.subheadline.weight(.semibold).monospacedDigit())
          .foregroundStyle(Color.primary)
          .contentTransition(.numericText())
      } else {
        Text(note(item)).font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(Color.secondary)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 28)
    .contentShape(Rectangle())
    .onTapGesture { withAnimation(.snappy) { strip.change(item, by: 1) } }
    .onLongPressGesture { withAnimation(.snappy) { strip.change(item, by: -1) } }
    .sensoryFeedback(.increase, trigger: count)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(count > 0 ? "\(count)" : Self.spoken(note(item)))
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { strip.change(item, by: 1) }
    .accessibilityAdjustableAction { direction in
      strip.change(item, by: direction == .increment ? 1 : -1)
    }
    .accessibilityIdentifier("strip-\(item.rawValue)")
  }
}

/// A drawn strip icon from the asset catalog, a template image, so it takes the item's colour as the symbols do.
private struct StripGlyph: View {
  let name: String

  var body: some View {
    Image(name).renderingMode(.template).resizable().scaledToFit().frame(width: 19, height: 19)
      .accessibilityHidden(true)
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

/// #290: which check the earlier-day sheet is for.
private struct Backdate: Identifiable {
  let item: DailyItem
  let label: String
  var id: String { item.rawValue }
}

/// Press and hold a check (#290): slide back to the day it was done, Confirm, and the sheet closes. One and done.
private struct BackdateSheet: View {
  let label: String
  let today: String
  let confirm: (String, Int) -> Void
  @Environment(\.dismiss) private var dismiss
  /// Today at the right end, two weeks back at the left; starts on yesterday.
  @State private var position = -1.0

  private var daysAgo: Int { Int(-position) }

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Text(DailyStrip.backdateLabel(daysAgo, today: today))
          .font(.title3.weight(.semibold).monospacedDigit())
          .accessibilityIdentifier("strip-backdate-day")
        Slider(value: $position, in: -Double(DailyStrip.backdateRange.upperBound)...0, step: 1) {
          Text("Day")
        } minimumValueLabel: {
          Text("2 wk").font(.caption)
        } maximumValueLabel: {
          Text("today").font(.caption)
        }
        .accessibilityValue(DailyStrip.backdateLabel(daysAgo, today: today))
        .accessibilityIdentifier("strip-backdate-slider")
      }
      .padding()
      .navigationTitle(label)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.accessibilityIdentifier("strip-backdate-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Confirm") {
            if let day = DailyStrip.day(daysAgo, before: today) { confirm(day, daysAgo) }
            dismiss()
          }
          .accessibilityIdentifier("strip-backdate-confirm")
        }
      }
    }
    .presentationDetents([.height(200)])
  }
}
