//  The Custom preset's controls upright (story 184): three drums by default — a straight swipe or a tap, the value
//  in LED digits filling the panel — and, behind GRABBER_TIMER_DIAL, two rotary knobs or one arc with a handle each
//  for work and rest. Same values, steps and ranges as the sliders (CustomPreset); TimerDials does the arithmetic.

import ContextCore
import SwiftUI
import UIKit

private let panel = Color(red: 0.086, green: 0.129, blue: 0.243)
private let label = Color(white: 0.53)

/// One step's tick, and a firmer bump when the range stops the dial.
@MainActor private enum DialHaptics {
  static let tick = UISelectionFeedbackGenerator()
  static let bump = UIImpactFeedbackGenerator(style: .rigid)
  static func stepped(hitEnd: Bool) {
    if hitEnd { bump.impactOccurred() } else { tick.selectionChanged() }
  }
}

/// What a dial sets: its name, the value, the custom preset's range and step, how it reads, its LED colour.
struct DialValue {
  let name: String
  let value: Int
  let range: ClosedRange<Int>
  let step: Int
  let format: (Int) -> String
  let color: Color
  let onChange: (Int) -> Void

  /// Moves by whole steps; true when something changed. The haptic says which: a tick, or the bump at an end.
  @MainActor func move(by steps: Int) -> Bool {
    guard steps != 0 else { return false }
    let next = TimerDials.stepped(value, by: steps, step: step, range: range)
    // Already at the end: no change, and no bump on every further move.
    guard next.value != value else { return false }
    DialHaptics.stepped(hitEnd: next.hitEnd)
    onChange(next.value)
    return true
  }
}

struct CustomDials: View {
  @ObservedObject var model: GymTimerModel
  let style: DialStyle
  let width: CGFloat

  private var work: DialValue {
    DialValue(
      name: "Work", value: model.custom.work, range: CustomPreset.workRange, step: CustomPreset.stepSeconds,
      format: formatMinutesSeconds, color: LED.red
    ) { model.changeCustom(CustomPreset(work: $0, rest: model.custom.rest, rounds: model.custom.rounds)) }
  }

  private var rest: DialValue {
    DialValue(
      name: "Rest", value: model.custom.rest, range: CustomPreset.restRange, step: CustomPreset.stepSeconds,
      format: formatMinutesSeconds, color: LED.green
    ) { model.changeCustom(CustomPreset(work: model.custom.work, rest: $0, rounds: model.custom.rounds)) }
  }

  private var rounds: DialValue {
    DialValue(
      name: "Rounds", value: model.custom.rounds, range: CustomPreset.roundsRange, step: 1, format: { String($0) },
      color: LED.white
    ) { model.changeCustom(CustomPreset(work: model.custom.work, rest: model.custom.rest, rounds: $0)) }
  }

  private func done(_ dial: DialValue, from source: String) {
    model.dialed(dial.name.lowercased(), style: style.rawValue, from: source)
  }

  var body: some View {
    switch style {
    case .drums:
      HStack(spacing: 10) {
        Drum(dial: work, onEnd: done)
        Drum(dial: rest, onEnd: done)
        Drum(dial: rounds, onEnd: done)
      }
    case .knobs:
      VStack(spacing: 10) {
        HStack(spacing: 18) {
          Knob(dial: work, onEnd: done)
          Knob(dial: rest, onEnd: done)
        }
        BigStepper(dial: rounds, onEnd: done)
      }
    case .arc:
      VStack(spacing: 6) {
        TwoHandleArc(work: work, rest: rest, size: min(width, 230), onEnd: done)
        BigStepper(dial: rounds, onEnd: done)
      }
    case .sliders:
      EmptyView()  // drawn by the timer screen itself, as before story 184
    }
  }
}

// MARK: - (b) drums: the shipped one

/// A tall panel: the label, the value big, its neighbours faint above (one step less) and below (one more). Drag up
/// for more; a flick goes further; a tap on the lower third is one more, on the upper third one less.
private struct Drum: View {
  let dial: DialValue
  let onEnd: (DialValue, String) -> Void

  @State private var acc = StepAccumulator(unitsPerStep: TimerDials.drumPointsPerStep)
  @State private var lastY: CGFloat?
  @State private var moved = false

  var body: some View {
    let above = TimerDials.stepped(dial.value, by: -1, step: dial.step, range: dial.range)
    let below = TimerDials.stepped(dial.value, by: 1, step: dial.step, range: dial.range)
    GeometryReader { geo in
      let w = geo.size.width - 16
      let big = CGFloat(LedLayout.heightToFit(dial.format(dial.value), width: Double(w), maxHeight: 44))
      let small = (big * 0.5).rounded()
      VStack(spacing: 0) {
        Text(dial.name.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.5).foregroundStyle(label)
          .padding(.top, 10)
        Spacer(minLength: 4)
        // At an end the neighbour is not there; its space is kept so the value does not jump.
        // Faint as a whole, ghost bars too, so the neighbour reads as a number and not as 8:88.
        LedDisplay(text: dial.format(above.value), color: dial.color, height: small)
          .opacity(above.value == dial.value ? 0 : 0.4)
        LedDisplay(text: dial.format(dial.value), color: dial.color, height: big).padding(.vertical, 10)
        LedDisplay(text: dial.format(below.value), color: dial.color, height: small)
          .opacity(below.value == dial.value ? 0 : 0.4)
        Spacer(minLength: 4)
        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(label.opacity(0.6))
          .padding(.bottom, 8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(panel, lineWidth: 2))
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { g in
            let y = g.location.y
            defer { lastY = y }
            guard let lastY else { return }
            if abs(g.translation.height) > 6 { moved = true }
            guard moved else { return }
            let up = Double(lastY - y) * TimerDials.speedMultiplier(pointsPerSecond: Double(g.velocity.height))
            _ = dial.move(by: acc.add(up))
          }
          .onEnded { g in
            if !moved {
              // A tap: the upper third brings the smaller neighbour in, the lower third the larger.
              let third = geo.size.height / 3
              if g.location.y < third { _ = dial.move(by: -1) } else if g.location.y > 2 * third { _ = dial.move(by: 1) }
            }
            onEnd(dial, moved ? "drag" : "tap")
            lastY = nil
            moved = false
            acc.reset()
          })
    }
    .frame(height: 176)
    .accessibilityElement()
    .accessibilityLabel(dial.name)
    .accessibilityValue(dial.format(dial.value))
    .accessibilityIdentifier("dial-\(dial.name.lowercased())")
    .accessibilityAdjustableAction { direction in
      _ = dial.move(by: direction == .increment ? 1 : -1)
      onEnd(dial, "accessibility")
    }
  }
}

// MARK: - (a) knobs

/// A rotary knob: twenty detents to a turn, a notch that turns with the value, the value in LED digits inside.
private struct Knob: View {
  let dial: DialValue
  let onEnd: (DialValue, String) -> Void

  @State private var acc = StepAccumulator(unitsPerStep: TimerDials.knobDegreesPerStep)
  @State private var lastAngle: Double?
  private let size: CGFloat = 150

  var body: some View {
    let index = (dial.value - dial.range.lowerBound) / dial.step
    let notch = Double(index) * TimerDials.knobDegreesPerStep
    VStack(spacing: 6) {
      ZStack {
        Circle().fill(Color.black).overlay(Circle().stroke(panel, lineWidth: 10))
        ForEach(0..<20, id: \.self) { i in
          Capsule().fill(label.opacity(i % 5 == 0 ? 0.7 : 0.3)).frame(width: 2, height: i % 5 == 0 ? 10 : 6)
            .offset(y: -size / 2 + 12).rotationEffect(.degrees(Double(i) * 18))
        }
        // The notch rides just inside the ring, outside the digits.
        Capsule().fill(dial.color).frame(width: 6, height: 16).shadow(color: dial.color, radius: 4)
          .offset(y: -size / 2 + 13).rotationEffect(.degrees(notch))
        LedDisplay(text: dial.format(dial.value), color: dial.color, height: 26)
      }
      .frame(width: size, height: size)
      .contentShape(Circle())
      .gesture(
        DragGesture(minimumDistance: 2)
          .onChanged { g in
            let a = TimerDials.angle(
              x: Double(g.location.x), y: Double(g.location.y), centerX: Double(size / 2), centerY: Double(size / 2))
            defer { lastAngle = a }
            guard let lastAngle else { return }
            _ = dial.move(by: acc.add(TimerDials.turn(from: lastAngle, to: a)))
          }
          .onEnded { _ in
            onEnd(dial, "turn")
            lastAngle = nil
            acc.reset()
          })
      Text(dial.name.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.5).foregroundStyle(label)
    }
    .accessibilityElement()
    .accessibilityLabel(dial.name)
    .accessibilityValue(dial.format(dial.value))
    .accessibilityIdentifier("dial-\(dial.name.lowercased())")
    .accessibilityAdjustableAction { direction in
      _ = dial.move(by: direction == .increment ? 1 : -1)
      onEnd(dial, "accessibility")
    }
  }
}

// MARK: - (c) one arc, two handles

/// Work on the outer ring, rest on the inner, each a 270° sweep from lower left round the top to lower right with a
/// handle on its value; a drag that starts nearer a ring moves that ring's handle to the finger.
private struct TwoHandleArc: View {
  let work: DialValue
  let rest: DialValue
  let size: CGFloat
  let onEnd: (DialValue, String) -> Void

  @State private var grabbed: String?

  private var outer: CGFloat { size / 2 - 14 }
  private var inner: CGFloat { size / 2 - 46 }

  var body: some View {
    ZStack {
      ring(work, radius: outer)
      ring(rest, radius: inner)
      VStack(spacing: 4) {
        LedDisplay(text: work.format(work.value), color: work.color, height: 28)
        LedDisplay(text: rest.format(rest.value), color: rest.color, height: 20)
      }
    }
    .frame(width: size, height: size)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { g in
          let dx = Double(g.location.x - size / 2)
          let dy = Double(g.location.y - size / 2)
          if grabbed == nil {
            let r = (dx * dx + dy * dy).squareRoot()
            grabbed = abs(r - Double(outer)) <= abs(r - Double(inner)) ? "work" : "rest"
          }
          let dial = grabbed == "work" ? work : rest
          let a = TimerDials.angle(x: dx, y: dy, centerX: 0, centerY: 0)
          let next = TimerDials.arcValue(angle: a, range: dial.range, step: dial.step)
          if next != dial.value {
            DialHaptics.stepped(hitEnd: next == dial.range.lowerBound || next == dial.range.upperBound)
            dial.onChange(next)
          }
        }
        .onEnded { _ in
          onEnd(grabbed == "work" ? work : rest, "arc")
          grabbed = nil
        })
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Work \(work.format(work.value)), rest \(rest.format(rest.value))")
    .accessibilityIdentifier("dial-arc")
  }

  private func ring(_ dial: DialValue, radius: CGFloat) -> some View {
    let fraction = (TimerDials.arcAngle(value: dial.value, range: dial.range) - TimerDials.arcStart) / TimerDials.arcSweep
    let handle = TimerDials.arcAngle(value: dial.value, range: dial.range) * .pi / 180
    // SwiftUI's trim starts at 3 o'clock; turned so the sweep starts at lower left (0° = up, clockwise).
    return ZStack {
      Circle().trim(from: 0, to: 0.75).stroke(panel, style: StrokeStyle(lineWidth: 14, lineCap: .round))
      Circle().trim(from: 0, to: 0.75 * fraction).stroke(dial.color.opacity(0.85), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        .shadow(color: dial.color.opacity(0.6), radius: 4)
    }
    .rotationEffect(.degrees(135))
    .frame(width: radius * 2, height: radius * 2)
    .overlay {
      Circle().fill(.white).frame(width: 22, height: 22).overlay(Circle().stroke(dial.color, lineWidth: 4))
        .offset(x: radius * sin(handle), y: -radius * cos(handle))
    }
  }
}

// MARK: - rounds, beside the knobs and the arc

/// Rounds as big − and + around LED digits: there is no time to turn, only a count.
private struct BigStepper: View {
  let dial: DialValue
  let onEnd: (DialValue, String) -> Void

  var body: some View {
    HStack(spacing: 18) {
      Text(dial.name.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.5).foregroundStyle(label)
      button("−", by: -1)
      LedDisplay(text: dial.format(dial.value), color: dial.color, height: 30).frame(minWidth: 44)
      button("+", by: 1)
    }
  }

  private func button(_ title: String, by steps: Int) -> some View {
    Button {
      _ = dial.move(by: steps)
      onEnd(dial, "tap")
    } label: {
      Text(title).font(.system(size: 26, weight: .bold)).foregroundStyle(LED.white)
        .frame(width: 52, height: 52).background(panel, in: Circle())
    }
    .accessibilityLabel("\(dial.name) \(steps > 0 ? "more" : "less")")
  }
}
