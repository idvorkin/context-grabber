//  Grabber Native's widget extension. For now only the Live Activity — the lock-screen card and the Dynamic
//  Island — shared by the Gym Timer and Box breathing (stories 106, 166; spec
//  2026-10-04-native-live-activity-design.md). The views are generic: a screen decides the words, the times and the
//  colour. No widgetURL: a tap opens the app, and a card only lives while its screen covers the app (story 125).

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct GrabberWidgets: WidgetBundle {
  var body: some Widget {
    GrabberLiveActivity()
  }
}

/// The accent tokens. Red, green and amber are the timer face's LED palette (App/Gym/TimerFace.swift).
private enum Palette {
  static let dim = Color(white: 0.6)

  static func of(_ s: GrabberActivityAttributes.ContentState) -> Color {
    switch s.accent {
    case "red": return Color(red: 1.0, green: 0.231, blue: 0.188)
    case "green": return Color(red: 0.204, green: 0.78, blue: 0.349)
    case "amber": return Color(red: 1.0, green: 0.8, blue: 0.0)
    default: return Color(white: 0.92)
    }
  }
}

struct GrabberLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: GrabberActivityAttributes.self) { context in
      LockScreenCard(state: context.state)
        .padding(16)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let s = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(s.title).font(.title3.weight(.bold)).foregroundStyle(Palette.of(s))
            Text(s.subtitle).font(.subheadline).foregroundStyle(Palette.dim).lineLimit(1)
          }
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(state: s).font(.system(size: 34, weight: .bold, design: .monospaced))
            .foregroundStyle(.white).padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if !s.finished { StepBar(state: s).padding(.horizontal, 4) }
        }
      } compactLeading: {
        Text(s.compactLabel).font(.system(size: 13, weight: .bold, design: .rounded))
          .foregroundStyle(Palette.of(s)).lineLimit(1).minimumScaleFactor(0.6)
      } compactTrailing: {
        Countdown(state: s).font(.system(size: 15, weight: .semibold, design: .monospaced))
          .foregroundStyle(Palette.of(s)).frame(maxWidth: 52)
      } minimal: {
        Countdown(state: s).font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(Palette.of(s)).minimumScaleFactor(0.6)
      }
      .keylineTint(Palette.of(s))
    }
  }
}

private struct LockScreenCard: View {
  let state: GrabberActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(state.title).font(.system(size: 22, weight: .heavy)).foregroundStyle(Palette.of(state))
          Text(state.subtitle).font(.system(size: 15)).foregroundStyle(Palette.dim)
        }
        Spacer()
        if !state.finished {
          Countdown(state: state).font(.system(size: 44, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
        }
      }
      if !state.finished { StepBar(state: state) }
    }
  }
}

/// A countdown that runs by itself to the step's end; a still number when paused or finished.
private struct Countdown: View {
  let state: GrabberActivityAttributes.ContentState

  var body: some View {
    if state.finished {
      Image(systemName: "checkmark")
    } else if state.paused || state.endsAt <= Date() {
      Text(String(format: "%d:%02d", state.secondsLeft / 60, state.secondsLeft % 60))
        .multilineTextAlignment(.trailing)
    } else {
      Text(timerInterval: Date()...state.endsAt, countsDown: true).multilineTextAlignment(.trailing)
        .monospacedDigit()
    }
  }
}

/// What is left of the step, shrinking with it; still when paused.
private struct StepBar: View {
  let state: GrabberActivityAttributes.ContentState

  var body: some View {
    let total = Double(max(1, state.stepSeconds))
    Group {
      if state.paused || state.endsAt <= Date() {
        ProgressView(value: min(total, Double(state.secondsLeft)), total: total)
      } else {
        ProgressView(
          timerInterval: state.endsAt.addingTimeInterval(-total)...state.endsAt, countsDown: true,
          label: { EmptyView() }, currentValueLabel: { EmptyView() })
      }
    }
    .tint(Palette.of(state))
  }
}
