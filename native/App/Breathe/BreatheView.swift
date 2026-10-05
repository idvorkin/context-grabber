//  Box breathing (stories 160–165): the sliders, the circle, Done.

import ContextCore
import SwiftUI

private enum Ink {
  static let background = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0B / 255)
  static let circle = Color(red: 0x26 / 255, green: 0x26 / 255, blue: 0x26 / 255)
  static let dim = Color.white.opacity(0.6)
}

struct BreatheView: View {
  @ObservedObject var app: AppModel
  let launch: BreatheLaunch
  let onExit: () -> Void
  @StateObject private var model: BreatheModel
  @Environment(\.scenePhase) private var scenePhase

  init(app: AppModel, launch: BreatheLaunch, onExit: @escaping () -> Void) {
    self.app = app
    self.launch = launch
    self.onExit = onExit
    _model = StateObject(wrappedValue: BreatheModel(log: app.log, database: app.database))
  }

  var body: some View {
    ZStack {
      Ink.background.ignoresSafeArea()
      switch model.stage {
      case .setup: BreatheSetup(model: model, onExit: onExit)
      case .session: BreatheSession(model: model)
      case .done: BreatheDone(model: model)
      }
    }
    .preferredColorScheme(.dark)
    .onAppear { if launch.plan != nil { model.begin(launch) } }
    .onDisappear { model.disappear() }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { model.leftForeground() }
    }
  }
}

// MARK: - setup

private struct BreatheSetup: View {
  @ObservedObject var model: BreatheModel
  let onExit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      Button(action: onExit) {
        Image(systemName: "xmark").font(.title3).frame(width: 44, height: 44, alignment: .leading)
      }
      .accessibilityLabel("Close")
      .accessibilityIdentifier("breathe-close")
      Text("Box breathing").font(.largeTitle.weight(.semibold))

      slider(
        "Breath length", value: "\(model.breathSeconds) s", id: "breathe-breath",
        Binding(get: { Double(model.breathSeconds) }, set: { model.setBreath(Int($0.rounded())) }),
        in: BreathPlan.breathRange)
      slider(
        "Session length", value: "\(model.sessionMinutes) min", id: "breathe-session",
        Binding(get: { Double(model.sessionMinutes) }, set: { model.setSession(Int($0.rounded())) }),
        in: BreathPlan.sessionRange)
      Text(model.plan.summary).foregroundStyle(Ink.dim).accessibilityIdentifier("breathe-summary")

      VStack(alignment: .leading, spacing: 8) {
        Text("Cue").font(.headline)
        Picker("Cue", selection: Binding(get: { model.cue }, set: { model.chooseCue($0) })) {
          ForEach(BreathCue.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("breathe-cue")
      }

      Spacer()
      Button {
        model.begin()
      } label: {
        Text("Begin").font(.title3.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .tint(.white)
      .foregroundStyle(.black)
      .accessibilityIdentifier("breathe-begin")
    }
    .padding(24)
    .foregroundStyle(.white)
  }

  private func slider(
    _ title: String, value: String, id: String, _ binding: Binding<Double>, in range: ClosedRange<Int>
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title).font(.headline)
        Spacer()
        Text(value).monospacedDigit().foregroundStyle(Ink.dim)
      }
      Slider(value: binding, in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        .tint(.white)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier(id)
    }
  }
}

// MARK: - session

private struct BreatheSession: View {
  @ObservedObject var model: BreatheModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button(action: model.back) {
          Image(systemName: "chevron.left").font(.title3).frame(width: 44, height: 44)
        }
        .accessibilityLabel("Back")
        .accessibilityIdentifier("breathe-back")
        Spacer()
        Button(action: model.togglePause) {
          Image(systemName: model.paused ? "play.fill" : "pause.fill").font(.title3).frame(width: 44, height: 44)
        }
        .accessibilityLabel(model.paused ? "Resume" : "Pause")
        .accessibilityIdentifier("breathe-pause")
      }
      .foregroundStyle(Ink.dim)
      .padding(.horizontal, 12)

      // While paused the clock is not read at all: nothing can move.
      TimelineView(.animation(paused: model.paused)) { timeline in
        if let moment = model.moment(at: timeline.date) {
          VStack(spacing: 28) {
            Spacer()
            BreathCircle(
              moment: moment, word: model.inLeadIn(at: timeline.date) ? "Ready" : moment.phase.word,
              reduceMotion: reduceMotion)
            Text(moment.timeLeftText)
              .font(.system(size: 11)).monospacedDigit().foregroundStyle(Ink.dim)
              .accessibilityIdentifier("breathe-left")
            Spacer()
          }
        }
      }
    }
  }
}

private struct BreathCircle: View {
  let moment: BreathMoment
  let word: String
  let reduceMotion: Bool

  var body: some View {
    ZStack {
      Circle().fill(Ink.circle)
      BreathRing(progress: moment.ring)
        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }
    // Reduce Motion keeps the ring, which reads as time, and drops the growing and shrinking.
    .scaleEffect(reduceMotion ? 1 : moment.scale)
    .overlay {
      VStack(spacing: 14) {
        Text(word).font(.system(size: 28, weight: .medium)).foregroundStyle(.white)
        // The holds have no ring movement to watch; the bar is their clock.
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.15))
          Capsule().fill(.white).frame(width: 96 * moment.phaseProgress)
        }
        .frame(width: 96, height: 3)
        .opacity(moment.phase.isHold && word != "Ready" ? 1 : 0)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(word)
    }
    .padding(.horizontal, 44)
    .aspectRatio(1, contentMode: .fit)
  }
}

/// The ring: from the bottom, up both sides at once, closing at the top.
private struct BreathRing: Shape {
  var progress: Double

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard progress > 0 else { return path }
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    let sweep = 180 * min(1, progress)
    // 90° is the bottom of the circle on screen, 270° the top.
    let bottom = CGPoint(x: center.x, y: center.y + radius)
    path.move(to: bottom)
    path.addArc(
      center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(90 + sweep), clockwise: false)
    path.move(to: bottom)  // a second stroke, not a chord back across the circle
    path.addArc(
      center: center, radius: radius, startAngle: .degrees(90), endAngle: .degrees(90 - sweep), clockwise: true)
    return path
  }
}

// MARK: - done

private struct BreatheDone: View {
  @ObservedObject var model: BreatheModel

  var body: some View {
    VStack(spacing: 14) {
      Spacer()
      Text("Done").font(.system(size: 44, weight: .semibold)).accessibilityIdentifier("breathe-done")
      Text(model.sessionPlan?.doneText ?? "").foregroundStyle(Ink.dim)
      Spacer()
      Button("Back to start", action: model.backToStart)
        .buttonStyle(.bordered)
        .tint(.white)
        .accessibilityIdentifier("breathe-restart")
        .padding(.bottom, 32)
    }
    .foregroundStyle(.white)
  }
}
