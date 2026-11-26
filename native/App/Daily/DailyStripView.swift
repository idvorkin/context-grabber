//  The daily strip on the home screen (#236, #238, #257; home-screen spec, "The daily strip"): one tight line. Gym,
//  Meditation and Journal are checks (a press and hold edits fourteen days, #414); Balloons and Magic count, a tap
//  for one more and a press and hold for the counter's week (#342).

import BugKit
import ContextCore
import SwiftUI

struct DailyStripView: View {
  @ObservedObject var strip: DailyStripModel
  /// #414: the check and its staged fourteen days, while the sheet is up.
  @State private var backdating: Backdate?
  /// A long press opened the sheet: the button's tap on release is not a second change.
  @State private var longPressed = false
  /// #342: the counter whose week is open.
  @State private var editing: WeekEdit?

  var body: some View {
    VStack(spacing: 8) {
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
      if backdating == nil, let problem = strip.problem {
        BugProblemView(problem: problem, logger: strip.bugLogger)
      }
    }
    .font(.subheadline.weight(.medium))
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
      strip.refresh()
    }
    .onAppear { strip.refresh() }
    .sheet(
      item: $backdating,
      onDismiss: {
        longPressed = false
        strip.problem = nil
      },
      content: { b in
        CheckFortnightSheet(label: b.label, fortnight: b.fortnight, strip: strip)
      }
    )
    .sheet(item: $editing) { e in WeekSheet(label: e.label, color: e.color, week: e.week) { strip.save($0) } }
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
        openFortnight(item, label: label)
      }
    )
    .accessibilityAction(named: "Mark an earlier day") { openFortnight(item, label: label) }
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
    .onLongPressGesture { openWeek(item, label: label, color: color) }
    .sensoryFeedback(.increase, trigger: count)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(count > 0 ? "\(count)" : Self.spoken(note(item)))
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { strip.change(item, by: 1) }
    .accessibilityAction(named: "Edit the week") { openWeek(item, label: label, color: color) }
    .accessibilityAdjustableAction { direction in
      strip.change(item, by: direction == .increment ? 1 : -1)
    }
    .accessibilityIdentifier("strip-\(item.rawValue)")
  }

  private func openFortnight(_ item: DailyItem, label: String) {
    guard let fortnight = strip.fortnight(item) else { return }
    backdating = Backdate(label: label, fortnight: fortnight)
  }

  private func openWeek(_ item: DailyItem, label: String, color: Color) {
    guard let week = strip.week(item) else { return }
    editing = WeekEdit(label: label, color: color, week: week)
  }
}

/// #342: the counter week being edited, while its sheet is up.
private struct WeekEdit: Identifiable {
  let label: String
  let color: Color
  let week: CounterWeek
  var id: String { week.item.rawValue }
}

/// Press and hold a counter (#342, story 254): its last seven days, each with − and + and a check above 0. Nothing
/// is saved until Confirm.
private struct WeekSheet: View {
  let label: String
  let color: Color
  @State var week: CounterWeek
  let confirm: (CounterWeek) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        // #1493, story 572: the week at a glance, following − and + before Confirm.
        Section {
          CounterWeekGraph(week: week, label: label, color: color)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
        }
        Section {
          ForEach(Array(week.days.enumerated()), id: \.element.day) { index, day in
            row(index, day)
          }
        }
      }
      .listSectionSpacing(.compact)
      .navigationTitle(label)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.accessibilityIdentifier("strip-week-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Confirm") {
            confirm(week)
            dismiss()
          }
          .accessibilityIdentifier("strip-week-confirm")
        }
      }
    }
    .presentationDetents([.large])  // all seven days at once (spec), never a half sheet that hides the last ones
  }

  private func row(_ index: Int, _ day: CounterWeek.Day) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.green)
        .opacity(day.checked ? 1 : 0)
        .accessibilityHidden(true)
      Text(day.label).monospacedDigit()
      Spacer(minLength: 8)
      Button {
        week.step(index, by: -1)
      } label: {
        Image(systemName: "minus.circle")
      }
      .accessibilityLabel("One fewer")
      .accessibilityIdentifier("strip-week-minus-\(day.daysAgo)")
      Text("\(day.count)").font(.body.weight(.semibold).monospacedDigit()).frame(minWidth: 24)
        .contentTransition(.numericText())
        .accessibilityIdentifier("strip-week-count-\(day.daysAgo)")
      Button {
        week.step(index, by: 1)
      } label: {
        Image(systemName: "plus.circle.fill")
      }
      .accessibilityLabel("One more")
      .accessibilityIdentifier("strip-week-plus-\(day.daysAgo)")
    }
    .font(.title3)
    .buttonStyle(.borderless)  // two buttons in one row, each its own tap
    .sensoryFeedback(.selection, trigger: day.count)
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

/// #414: the check and its initial days, captured when the editor opens.
private struct Backdate: Identifiable {
  let label: String
  let fortnight: CheckFortnight
  var id: String { fortnight.item.rawValue }
}

/// #414, story 255: mark or take back days together; Cancel discards the local snapshot.
private struct CheckFortnightSheet: View {
  let label: String
  @State var fortnight: CheckFortnight
  @ObservedObject var strip: DailyStripModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text(fortnight.headline).font(.title2.weight(.semibold))
          Text(fortnight.subline).font(.subheadline).foregroundStyle(.secondary)
            .accessibilityIdentifier("strip-grid-summary")
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
            ForEach(Array(fortnight.days.enumerated()), id: \.element.day) { index, day in
              tile(day, index: index)
            }
          }
          HStack(spacing: 12) {
            Label {
              Text("done")
            } icon: {
              Circle().fill(Color.accentColor).frame(width: 10, height: 10)
            }
            Label {
              Text("changed")
            } icon: {
              Circle().stroke(Color.orange, lineWidth: 2).frame(width: 10, height: 10)
            }
          }
          .font(.caption).foregroundStyle(.secondary)
          Text("Tap a day to mark or unmark it").font(.footnote).foregroundStyle(.secondary)
          if let problem = strip.problem {
            BugProblemView(problem: problem, logger: strip.bugLogger)
          }
        }
        .padding()
      }
      .navigationTitle(label)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.accessibilityIdentifier("strip-backdate-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            if strip.save(fortnight) { dismiss() }
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("strip-grid-done")
        }
      }
    }
    .preferredColorScheme(.dark)
    // #1503, story 570: Gym's sheet opens full height (more room for the icons); the others keep the half sheet.
    .presentationDetents(fortnight.item == .gym ? [.large] : [.medium, .large])
  }

  /// #1503, story 570: Gym's sheet is taller, and its tiles show what was done.
  private var isGym: Bool { fortnight.item == .gym }

  /// Up to three icons for the day's workouts and the timer, else the first two and "+N" (story 570).
  private func marksRow(_ day: CheckFortnight.Day) -> some View {
    let icons = DailyStrip.gymIcons(day.marks)
    return HStack(spacing: 2) {
      ForEach(icons.shown, id: \.self) { mark in
        Image(systemName: mark.symbol).font(.system(size: 11))
      }
      if icons.more > 0 { Text("+\(icons.more)").font(.system(size: 10).weight(.semibold)) }
    }
    .frame(height: 14)
    .accessibilityHidden(true)  // the tile's label names them
    .accessibilityIdentifier("strip-day-marks-\(day.daysAgo)")
  }

  private func tile(_ day: CheckFortnight.Day, index: Int) -> some View {
    Button {
      fortnight.toggle(index)
    } label: {
      VStack(spacing: 3) {
        Text(day.weekday).font(.caption2)
        Text(day.number).font(.body.weight(.semibold).monospacedDigit())
        Text(day.tag).font(.system(size: 9)).lineLimit(1)
        if isGym { marksRow(day) }
      }
      .frame(maxWidth: .infinity, minHeight: isGym ? 88 : 64)
      .foregroundStyle(day.done ? Color.white : Color.primary)
      .background(
        day.done ? Color.accentColor : Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 10)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(day.daysAgo == 0 ? Color.primary.opacity(0.35) : Color.clear, lineWidth: 1)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12).stroke(day.changed ? Color.orange : Color.clear, lineWidth: 2)
          .padding(-2)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(day.accessibilityLabel)
    .accessibilityHint(day.automatic ? "Recorded automatically" : "Tap to mark or unmark")
    .accessibilityAddTraits(day.done ? .isSelected : [])
    .accessibilityIdentifier("strip-day-\(day.daysAgo)")
  }
}
