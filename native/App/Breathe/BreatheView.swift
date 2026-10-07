//  Box breathing (stories 160–165): the sliders, the circle, Done.
//
//  Monochrome on near-black. A light serif (New York) carries the words that hold the moment — the title, the
//  step's word, the slider values, "Done"; small spaced capitals label things; changing numbers keep their width.

import ContextCore
import SwiftUI

private enum Ink {
  static let background = Color(red: 0x0B / 255, green: 0x0B / 255, blue: 0x0B / 255)
  /// The circle is a touch lighter at its centre than its edge, so it sits forward of the background.
  static let circleCentre = Color(red: 0x24 / 255, green: 0x24 / 255, blue: 0x24 / 255)
  static let circleEdge = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255)
  static let text = Color.white
  static let dim = Color.white.opacity(0.58)
  static let faint = Color.white.opacity(0.3)
  static let hairline = Color.white.opacity(0.1)
}

private enum Face {
  static func serif(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
    .system(size: size, weight: weight, design: .serif)
  }
  static let eyebrow = Font.system(size: 11, weight: .semibold)
}

/// A label in small, spaced capitals.
private struct Eyebrow: View {
  let text: String
  init(_ text: String) { self.text = text }
  var body: some View {
    Text(text.uppercased()).font(Face.eyebrow).tracking(1.6).foregroundStyle(Ink.dim)
  }
}

struct BreatheView: View {
  @ObservedObject var app: AppModel
  let launch: BreatheLaunch
  let onExit: () -> Void
  @StateObject private var model: BreatheModel

  init(app: AppModel, launch: BreatheLaunch, onExit: @escaping () -> Void) {
    self.app = app
    self.launch = launch
    self.onExit = onExit
    _model = StateObject(wrappedValue: BreatheModel(log: app.log, database: app.database, liveActivity: app.liveActivity))
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
    .onAppear { if launch.begins { model.begin(launch) } }
    .onDisappear { model.disappear() }
  }
}

// MARK: - setup

private struct BreatheSetup: View {
  @ObservedObject var model: BreatheModel
  let onExit: () -> Void
  @State private var showStyles = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Button(action: onExit) {
          Image(systemName: "xmark").font(.system(size: 17, weight: .regular)).foregroundStyle(Ink.dim)
            .frame(width: 44, height: 44, alignment: .leading)
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("breathe-close")
        Spacer()
        Button { showStyles = true } label: {
          Image(systemName: "gearshape").font(.system(size: 17, weight: .regular)).foregroundStyle(Ink.dim)
            .frame(width: 44, height: 44, alignment: .trailing)
        }
        .accessibilityLabel("Ring style")
        .accessibilityIdentifier("breathe-style")
      }
      .sheet(isPresented: $showStyles) { StylePicker(model: model) }

      // Between the fixed header and Begin, it scrolls: Custom's two sliders make it taller than a phone (story 241).
      ScrollView {
      VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Box breathing").font(Face.serif(36)).foregroundStyle(Ink.text)
        Text(model.preset == nil ? "In and its hold, out and its hold." : "In, hold, out, hold — four even sides.")
          .font(.subheadline).foregroundStyle(Ink.dim)
      }
      .padding(.top, 12)

      VStack(alignment: .leading, spacing: 34) {
        // Story 241: one tap for a pace, or Custom's own in and out.
        VStack(alignment: .leading, spacing: 12) {
          Eyebrow("Breath length")
          PresetPicker(selection: model.preset, choose: model.choosePreset)
        }
        if model.preset == nil {
          BreathSlider(
            title: "In", unit: "s", id: "breathe-in", value: model.customIn, range: BreathPlan.customRange,
            set: model.setCustomIn)
          BreathSlider(
            title: "Out", unit: "s", id: "breathe-out", value: model.customOut, range: BreathPlan.customRange,
            set: model.setCustomOut)
        }
        BreathSlider(
          title: "Session length", unit: "min", id: "breathe-session", value: model.sessionMinutes,
          range: BreathPlan.sessionRange, set: model.setSession)
      }
      .padding(.top, 40)

      VStack(spacing: 0) {
        Ink.hairline.frame(height: 1)
        Text(model.plan.summary)
          .font(.system(size: 15)).monospacedDigit().foregroundStyle(Ink.dim)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 14)
          .contentTransition(.numericText())
          .animation(.easeOut(duration: 0.2), value: model.plan)
          .accessibilityIdentifier("breathe-summary")
        Ink.hairline.frame(height: 1)
      }
      .padding(.top, 28)

      VStack(alignment: .leading, spacing: 12) {
        Eyebrow("Cue")
        CuePicker(selection: model.cue, choose: model.chooseCue)
      }
      .padding(.top, 28)
      .padding(.bottom, 24)
      }
      }
      .scrollBounceBehavior(.basedOnSize)

      Button(action: { model.begin() }) {
        Text("Begin").font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
          .frame(maxWidth: .infinity, minHeight: 56)
          .background(Capsule().fill(.white))
      }
      .buttonStyle(Pressable())
      .accessibilityIdentifier("breathe-begin")
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 16)
  }
}

/// A whole-number slider: the value large beside its label, a faint dot for every stop, the range's ends under it.
private struct BreathSlider: View {
  let title: String
  let unit: String
  let id: String
  let value: Int
  let range: ClosedRange<Int>
  let set: (Int) -> Void

  private let thumb: CGFloat = 22

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .lastTextBaseline) {
        Eyebrow(title)
        Spacer()
        HStack(alignment: .lastTextBaseline, spacing: 4) {
          Text("\(value)").font(Face.serif(30)).monospacedDigit().foregroundStyle(Ink.text)
            .contentTransition(.numericText(value: Double(value)))
            .animation(.easeOut(duration: 0.15), value: value)
          Text(unit).font(.system(size: 13)).foregroundStyle(Ink.dim)
        }
      }
      track
      HStack {
        Text("\(range.lowerBound) \(unit)")
        Spacer()
        Text("\(range.upperBound) \(unit)")
      }
      .font(.system(size: 11)).monospacedDigit().foregroundStyle(Ink.faint)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue("\(value) \(unit == "s" ? "seconds" : "minutes")")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: if value < range.upperBound { set(value + 1) }
      case .decrement: if value > range.lowerBound { set(value - 1) }
      @unknown default: break
      }
    }
    .accessibilityIdentifier(id)
  }

  private var fraction: CGFloat {
    CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
  }

  private var track: some View {
    GeometryReader { geo in
      let usable = geo.size.width - thumb
      let x = thumb / 2 + usable * fraction
      let stops = range.upperBound - range.lowerBound
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.12)).frame(height: 2)
        ForEach(0...stops, id: \.self) { i in
          Circle().fill(Color.white.opacity(i <= value - range.lowerBound ? 0 : 0.3))
            .frame(width: 3, height: 3)
            .position(x: thumb / 2 + usable * CGFloat(i) / CGFloat(stops), y: geo.size.height / 2)
        }
        Capsule().fill(Color.white.opacity(0.9)).frame(width: x, height: 2)
        Circle().fill(.white)
          .frame(width: thumb, height: thumb)
          .shadow(color: .white.opacity(0.25), radius: 8)
          .position(x: x, y: geo.size.height / 2)
      }
      .frame(height: geo.size.height)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { drag in
          let f = min(1, max(0, (drag.location.x - thumb / 2) / max(1, usable)))
          set(range.lowerBound + Int((f * CGFloat(stops)).rounded()))
        })
    }
    .frame(height: 32)
  }
}

/// Voice, Tone or Off: three quiet tiles, the chosen one lit.
/// Story 241: 8, 10, 12, 15 seconds a side, or Custom (nil).
private struct PresetPicker: View {
  let selection: Int?
  let choose: (Int?) -> Void

  var body: some View {
    HStack(spacing: 8) {
      ForEach(BreathPlan.presets.map(Optional.some) + [nil], id: \.self) { preset in
        let on = preset == selection
        Button(action: { choose(preset) }) {
          Text(preset.map { "\($0) s" } ?? "Custom")
            .font(.system(size: 15, weight: on ? .semibold : .regular)).monospacedDigit()
            .foregroundStyle(on ? Ink.text : Ink.dim)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(Color.white.opacity(on ? 0.09 : 0.0)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(on ? 0.4 : 0.1), lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: on)
        }
        .buttonStyle(Pressable())
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("breathe-preset-\(preset.map(String.init) ?? "custom")")
      }
    }
  }
}

private struct CuePicker: View {
  let selection: BreathCue
  let choose: (BreathCue) -> Void

  var body: some View {
    HStack(spacing: 10) {
      ForEach(BreathCue.allCases, id: \.self) { cue in
        let on = cue == selection
        Button(action: { choose(cue) }) {
          VStack(spacing: 8) {
            Image(systemName: symbol(cue)).font(.system(size: 17, weight: .regular))
            Text(cue.label).font(.system(size: 13, weight: on ? .semibold : .regular))
          }
          .foregroundStyle(on ? Ink.text : Ink.dim)
          .frame(maxWidth: .infinity, minHeight: 68)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(Color.white.opacity(on ? 0.09 : 0.0))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .strokeBorder(Color.white.opacity(on ? 0.4 : 0.1), lineWidth: 1)
          )
          .animation(.easeOut(duration: 0.2), value: on)
        }
        .buttonStyle(Pressable())
        .accessibilityLabel(cue.label)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("breathe-cue-\(cue.rawValue)")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Cue")
    .accessibilityIdentifier("breathe-cue")
  }

  private func symbol(_ cue: BreathCue) -> String {
    switch cue {
    case .voice: return "waveform"
    case .tone: return "music.note"
    case .off: return "speaker.slash"
    }
  }
}

/// Gives a little under the finger.
private struct Pressable: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.8 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
          Image(systemName: "chevron.left").font(.system(size: 18, weight: .regular))
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Back")
        .accessibilityIdentifier("breathe-back")
        Spacer()
      }
      .foregroundStyle(Ink.dim)
      .padding(.horizontal, 12)

      // While paused the clock is not read at all: nothing can move.
      TimelineView(.animation(paused: model.paused)) { timeline in
        if let moment = model.moment(at: timeline.date) {
          let word = model.inLeadIn(at: timeline.date) ? "Ready" : moment.phase.word
          VStack(spacing: 30) {
            Spacer()
            // The circle is the pause button: tap to pause, tap again to resume.
            Button(action: model.togglePause) {
              BreathCircle(
                moment: moment, word: word, paused: model.paused, reduceMotion: reduceMotion, style: model.style)
            }
            .buttonStyle(CircleTap())
            .accessibilityLabel(model.paused ? "Resume" : "Pause")
            .accessibilityValue(model.paused ? "Paused" : word)
            .accessibilityIdentifier("breathe-pause")
            Text(moment.timeLeftText)
              .font(.system(size: 12)).monospacedDigit().tracking(0.6).foregroundStyle(Ink.faint)
              .accessibilityIdentifier("breathe-left")
            Spacer()
            Spacer().frame(height: 44)  // balances the back row, so the circle sits at the true centre
          }
        }
      }
    }
  }
}

/// The circle answers a press by settling back a little, no more.
private struct CircleTap: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

private struct BreathCircle: View {
  let moment: BreathMoment
  let word: String
  let paused: Bool
  let reduceMotion: Bool
  var style: BreathStyle = .default

  var body: some View {
    ZStack {
      // A soft halo that gathers as the ring closes.
      Circle()
        .stroke(Color.white.opacity(paused ? 0 : 0.07 * moment.ring), lineWidth: 26)
        .blur(radius: 22)
      Circle().fill(
        EllipticalGradient(
          colors: [Ink.circleCentre, Ink.circleEdge], center: .center, startRadiusFraction: 0,
          endRadiusFraction: 0.5))
      StyledRing(style: style, progress: moment.ring)
        .opacity(paused ? 0.4 : 1)
      // While running, a faint mark says the circle can be tapped.
      VStack {
        Spacer()
        Image(systemName: "pause.fill")
          .font(.system(size: 12))
          .foregroundStyle(Color.white.opacity(0.26))
          .padding(.bottom, 44)
      }
      .opacity(paused ? 0 : 1)
      .accessibilityHidden(true)
    }
    // Reduce Motion keeps the ring, which reads as time, and drops the growing and shrinking.
    .scaleEffect(reduceMotion ? 1 : moment.scale)
    .overlay {
      if paused {
        VStack(spacing: 10) {
          Image(systemName: "play.fill").font(.system(size: 16)).foregroundStyle(Ink.dim)
          Text("Paused").font(Face.serif(28)).foregroundStyle(Ink.text)
          Text("tap to resume").font(.system(size: 13)).foregroundStyle(Ink.dim)
        }
        .accessibilityIdentifier("breathe-paused")
      } else {
        VStack(spacing: 16) {
          Text(word).font(Face.serif(30)).foregroundStyle(Ink.text)
          // The holds have no ring movement to watch; the bar is their clock.
          ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.14))
            Capsule().fill(.white).frame(width: 96 * moment.phaseProgress)
          }
          .frame(width: 96, height: 2)
          .opacity(moment.phase.isHold && word != "Ready" ? 1 : 0)
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .contentShape(Circle())
    .padding(.horizontal, 40)
  }
}

/// The breath drawn in the chosen style (story 240). Every style is a fill of `progress` (0…1) and nothing else.
struct StyledRing: View {
  let style: BreathStyle
  let progress: Double
  /// The ring's thickness at the circle's full size; the Done screen's small ring passes less.
  var lineWidth: CGFloat = 6

  var body: some View {
    switch style {
    case .line:
      BreathRing(progress: progress)
        .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .shadow(color: .white.opacity(0.45 * progress), radius: 6)
    case .glow:
      ZStack {
        Circle().stroke(Color.white.opacity(0.06), lineWidth: lineWidth * 1.6)
        BreathRing(progress: progress)
          .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: lineWidth * 1.6, lineCap: .round))
          .blur(radius: lineWidth * 0.6)
        BreathRing(progress: progress)
          .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
        GeometryReader { geo in
          let r = min(geo.size.width, geo.size.height) / 2
          let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
          // The two leading tips, where the ring is being drawn.
          let sweep = Double.pi * min(1, progress)
          ForEach([1.0, -1.0], id: \.self) { side in
            let a = Double.pi / 2 + side * sweep
            Circle().fill(.white).frame(width: lineWidth * 1.4, height: lineWidth * 1.4)
              .shadow(color: .white, radius: lineWidth * 1.2)
              .position(x: c.x + r * cos(a), y: c.y + r * sin(a))
              .opacity(progress > 0 ? 1 : 0)
          }
        }
      }
    case .beads:
      GeometryReader { geo in
        let r = min(geo.size.width, geo.size.height) / 2
        let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        let lit = BreathStyle.litBeads(progress: progress)
        ForEach(0..<BreathStyle.beadCount, id: \.self) { i in
          // Bead 0 at the bottom, counting clockwise on screen.
          let a = Double.pi / 2 + Double(i) * 2 * Double.pi / Double(BreathStyle.beadCount)
          let on = lit.contains(i)
          Circle().fill(Color.white.opacity(on ? 1 : 0.14))
            .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
            .shadow(color: .white.opacity(on ? 0.6 : 0), radius: lineWidth)
            .position(x: c.x + r * cos(a), y: c.y + r * sin(a))
            .animation(.easeOut(duration: 0.35), value: on)
        }
      }
    case .tide:
      GeometryReader { geo in
        let h = geo.size.height
        ZStack(alignment: .bottom) {
          Color.clear
          LinearGradient(
            colors: [Color.white.opacity(0.32), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom
          )
          .frame(height: h * min(1, progress))
          .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.55)).frame(height: 1.5) }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
      }
    }
  }
}

/// Ring style: four choices with a still preview each (story 240).
private struct StylePicker: View {
  @ObservedObject var model: BreatheModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Ring style").font(Face.serif(28)).foregroundStyle(Ink.text)
        Spacer()
        Button("Done") { dismiss() }.foregroundStyle(Ink.text).accessibilityIdentifier("breathe-style-done")
      }
      .padding(.bottom, 20)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
        ForEach(BreathStyle.allCases, id: \.self) { style in
          let on = style == model.style
          Button { model.chooseStyle(style) } label: {
            VStack(spacing: 12) {
              ZStack {
                Circle().fill(
                  EllipticalGradient(
                    colors: [Ink.circleCentre, Ink.circleEdge], center: .center, startRadiusFraction: 0,
                    endRadiusFraction: 0.5))
                StyledRing(style: style, progress: 0.62, lineWidth: 4)
              }
              .frame(width: 92, height: 92)
              Text(style.label).font(Face.serif(20)).foregroundStyle(Ink.text)
              Text(style.blurb).font(.system(size: 12)).foregroundStyle(Ink.dim).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(on ? 0.08 : 0.02)))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(on ? 0.5 : 0.1), lineWidth: 1))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("breathe-style-\(style.rawValue)")
          .accessibilityAddTraits(on ? .isSelected : [])
        }
      }
      Spacer()
    }
    .padding(24)
    .background(Ink.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .presentationDetents([.large])
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
    VStack(spacing: 0) {
      Spacer()
      // The closed ring, small and still: the box is complete.
      ZStack {
        Circle().stroke(Color.white.opacity(0.06), lineWidth: 18).blur(radius: 14)
        Circle().fill(
          EllipticalGradient(
            colors: [Ink.circleCentre, Ink.circleEdge], center: .center, startRadiusFraction: 0,
            endRadiusFraction: 0.5))
        StyledRing(style: model.style, progress: 1, lineWidth: 2.5)
      }
      .frame(width: 84, height: 84)
      .accessibilityHidden(true)
      Text("Done").font(Face.serif(48)).foregroundStyle(Ink.text)
        .padding(.top, 36)
        .accessibilityIdentifier("breathe-done")
      Text(model.sessionPlan?.doneText ?? "")
        .font(.system(size: 15)).monospacedDigit().foregroundStyle(Ink.dim)
        .padding(.top, 10)
      Spacer()
      Button(action: model.backToStart) {
        Text("Back to start").font(.system(size: 17, weight: .regular)).foregroundStyle(Ink.text)
          .frame(maxWidth: .infinity, minHeight: 56)
          .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
      }
      .buttonStyle(Pressable())
      .accessibilityIdentifier("breathe-restart")
      .padding(.horizontal, 24)
      .padding(.bottom, 16)
    }
  }
}
