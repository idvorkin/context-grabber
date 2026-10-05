//  The Gym Timer's face (stories 103, 108, 109): a seven-segment LED display, drawn — no font. Lit bars glow;
//  unlit bars are faint ghosts, so every digit has an 8 behind it and the display reads as one panel. A green
//  phase word stands over the time, the round line under it — and the same face turns sideways to fill the
//  screen when the phone is on its side.

import ContextCore
import SwiftUI

/// The LED palette: what a gym clock is.
enum LED {
  static let red = Color(red: 1.0, green: 0.231, blue: 0.188)
  static let green = Color(red: 0.204, green: 0.78, blue: 0.349)
  static let amber = Color(red: 1.0, green: 0.8, blue: 0.0)
  static let white = Color(white: 0.9)
  static let ghost = Color(white: 0.14)

  /// Red working, green resting, amber getting ready, red and steady on done; white before the first start.
  static func color(for phase: TimerPhase) -> Color {
    switch phase {
    case .work, .done: return red
    case .rest: return green
    case .prep: return amber
    case .idle: return white
    }
  }
}

struct LedDisplay: View {
  let text: String
  let color: Color
  let height: CGFloat

  var body: some View {
    // The canvas is larger than the display by the glow's reach on every side, or the glow is cut off square.
    let glow = LedLayout.bar * Double(height) * 2
    Canvas { context, _ in
      let h = Double(height)
      let rects = LedLayout.segmentRects(height: h)
      let radius = LedLayout.bar * h / 2
      var ghost = Path()
      var lit = Path()
      var x = 0.0
      context.translateBy(x: glow, y: glow)
      for ch in text {
        if SevenSegment.isSeparator(ch) {
          for dot in LedLayout.separatorDots(ch, height: h) {
            lit.addEllipse(in: CGRect(x: x + dot.x, y: dot.y, width: dot.width, height: dot.height))
          }
        } else {
          let on = SevenSegment.segments(for: ch)
          for segment in Segment.allCases {
            guard let r = rects[segment] else { continue }
            let bar = Path(
              roundedRect: CGRect(x: x + r.x, y: r.y, width: r.width, height: r.height), cornerRadius: radius)
            if on.contains(segment) { lit.addPath(bar) } else { ghost.addPath(bar) }
          }
        }
        x += LedLayout.charWidth(ch, height: h) + LedLayout.gap * h
      }
      context.fill(ghost, with: .color(LED.ghost))
      context.drawLayer { layer in
        layer.addFilter(.shadow(color: color.opacity(0.85), radius: LedLayout.bar * h * 0.7))
        layer.fill(lit, with: .color(color))
      }
    }
    .frame(width: LedLayout.width(of: text, height: Double(height)) + 2 * glow, height: height + 2 * glow)
    .padding(-glow)
    .accessibilityElement()
    .accessibilityLabel(text)
  }
}

/// What a face shows, whichever way it is drawn.
struct FaceContent {
  /// The seven-segment phase word (GO, rESt, …); empty for none.
  var word = ""
  /// Stopped mid-way: PAUSEd in amber, taller than a phase word, in place of `word`.
  var paused = false
  var time: String
  /// Smaller digits after the time — the stopwatch's hundredths.
  var fraction = ""
  var color: Color
  /// Ordinary small type under the time — "Round 2 of 5".
  var sub = ""
}

struct TimerFace: View {
  let content: FaceContent
  /// The width to fill and the height not to exceed.
  let width: CGFloat
  let maxHeight: CGFloat

  var body: some View {
    // The fraction rides at half height; sizing the pair as if full-size keeps it inside the width.
    let mainH = CGFloat(
      LedLayout.heightToFit(content.time + content.fraction, width: Double(width), maxHeight: Double(maxHeight)))
    // The paused word is half again as tall as a phase word: it has to read from across the room.
    let wordH = (mainH * (content.paused ? 0.48 : 0.32)).rounded()
    VStack(spacing: 0) {
      if content.paused {
        LedDisplay(text: SevenSegment.pausedWord, color: LED.amber, height: wordH).padding(.bottom, 6)
      } else if !content.word.isEmpty {
        LedDisplay(text: content.word, color: LED.green, height: wordH).padding(.bottom, 6)
      }
      HStack(alignment: .bottom, spacing: 6) {
        LedDisplay(text: content.time, color: content.color, height: mainH)
        if !content.fraction.isEmpty {
          LedDisplay(text: content.fraction, color: content.color, height: (mainH * 0.5).rounded())
        }
      }
      if !content.sub.isEmpty {
        Text(content.sub).font(.system(size: 16)).foregroundStyle(Color(white: 0.53)).padding(.top, 10)
      }
    }
  }
}

/// The face drawn sideways inside the portrait window, filling the long edge. The box is laid out at the
/// screen's long × short size and rotated; the window itself never turns. A tap anywhere is the one control.
struct TurnedTimer: View {
  let content: FaceContent
  let turn: DeviceTurn
  /// "tap to start" / "tap to stop" / "tap to resume" / "tap to count".
  let hint: String
  /// Shown only while stopped with something to clear (story 181), so a tap across the room cannot reset a run.
  var onReset: (() -> Void)? = nil
  let onTap: () -> Void

  var body: some View {
    GeometryReader { geo in
      let long = max(geo.size.width, geo.size.height)
      let short = min(geo.size.width, geo.size.height)
      VStack(spacing: 18) {
        // The button needs room on the short edge: the face gives some up while it shows, more when the
        // tall PAUSEd word sits above the time.
        TimerFace(
          content: content, width: long * 0.9,
          maxHeight: short * (onReset == nil ? 0.6 : content.paused ? 0.36 : 0.46))
        Text(hint.uppercased()).font(.system(size: 13)).tracking(2).foregroundStyle(Color(white: 0.33))
        if let onReset {
          Button(action: onReset) {
            Text("RESET").font(.system(size: 15, weight: .semibold)).tracking(2)
              .padding(.horizontal, 28).padding(.vertical, 12)
              .overlay(Capsule().stroke(Color(white: 0.4), lineWidth: 1))
          }
          .foregroundStyle(Color(white: 0.75))
          .accessibilityIdentifier("timer-turned-reset")
        }
      }
      .frame(width: long, height: short)
      .rotationEffect(.degrees(turn.rotationDegrees))
      .position(x: geo.size.width / 2, y: geo.size.height / 2)
    }
    .background(Color.black)
    .contentShape(Rectangle())
    .onTapGesture(perform: onTap)
    .ignoresSafeArea()
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(hint)
  }
}
