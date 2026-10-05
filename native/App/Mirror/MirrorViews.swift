//  Small pieces the mirror draws with: a card's box plot (story 004), a night's stage strip (stories 007, 008),
//  the share sheet, a copyable problem, and colours from "#rrggbb".

import ContextCore
import SwiftUI
import UIKit

extension Color {
  init(hex: String) {
    let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
    self.init(
      red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
  }
}

enum StageStyle {
  static func color(_ value: Int?) -> Color {
    switch value {
    case 3: return Color(hex: "#4cc9f0")  // Core
    case 4: return Color(hex: "#3a0ca3")  // Deep
    case 5: return Color(hex: "#7209b7")  // REM
    case 2: return Color(hex: "#8d99ae")  // Awake
    case 0: return Color(hex: "#2a2a40")  // In bed
    default: return Color(hex: "#5e60ce")  // Asleep, no stage
    }
  }

  static let legend: [(String, Int)] = [("Core", 3), ("Deep", 4), ("REM", 5), ("Awake", 2)]
}

/// p5–p95 whiskers, the p25–p75 box, the median, and the week's min and max written in the corners.
struct BoxPlotView: View {
  let stats: BoxPlotStats
  let color: Color
  var showEnds = true

  var body: some View {
    VStack(spacing: 1) {
      GeometryReader { geo in
        let lo = stats.min
        let span = max(stats.max - lo, 1e-9)
        let x = { (v: Double) in CGFloat((v - lo) / span) * geo.size.width }
        let mid = geo.size.height / 2
        ZStack(alignment: .topLeading) {
          Path { p in
            p.move(to: CGPoint(x: x(stats.p5), y: mid))
            p.addLine(to: CGPoint(x: x(stats.p95), y: mid))
          }.stroke(color.opacity(0.6), lineWidth: 1)
          RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: 1))
            .frame(width: max(x(stats.p75) - x(stats.p25), 2), height: geo.size.height)
            .offset(x: x(stats.p25))
          Rectangle().fill(color).frame(width: 2, height: geo.size.height).offset(x: x(stats.p50) - 1)
        }
      }
      .frame(height: 10)
      if showEnds {
        HStack {
          Text(SummaryText.formatNumber(stats.min, maxFractionDigits: 1))
          Spacer()
          Text(SummaryText.formatNumber(stats.max, maxFractionDigits: 1))
        }
        .font(.system(size: 9).monospacedDigit())
        .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Range \(stats.min) to \(stats.max), median \(stats.p50)")
  }
}

/// A night from bedtime to wake, coloured by stage; with `hourLabels`, the hours underneath.
struct StageStrip: View {
  let night: SleepDaily
  var height: CGFloat = 14
  var hourLabels = false
  let clock: LocalClock

  var body: some View {
    if let bed = night.bedtime.flatMap(parseISO), let wake = night.wakeTime.flatMap(parseISO), wake > bed {
      VStack(alignment: .leading, spacing: 2) {
        Canvas { ctx, size in
          let span = wake - bed
          ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4), with: .color(.secondary.opacity(0.12)))
          // In bed first, so the stages draw over it.
          for s in night.samples.sorted(by: { ($0.value == 0 ? 0 : 1) < ($1.value == 0 ? 0 : 1) }) {
            let a = max(s.start, bed), b = min(s.end, wake)
            guard b > a else { continue }
            let rect = CGRect(
              x: CGFloat((a - bed) / span) * size.width, y: 0, width: max(CGFloat((b - a) / span) * size.width, 0.5),
              height: size.height)
            ctx.fill(Path(rect), with: .color(StageStyle.color(s.value)))
          }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        if hourLabels {
          GeometryReader { geo in
            let first = clock.setHours(bed, clock.hour(bed)) + 3_600_000
            ForEach(Array(stride(from: first, to: wake, by: 3_600_000)), id: \.self) { t in
              Text(SummaryText.formatLocalTime(isoString(t), clock: clock))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize()
                .position(x: CGFloat((t - bed) / (wake - bed)) * geo.size.width, y: 6)
            }
          }
          .frame(height: 12)
        }
      }
    }
  }
}

/// The system share sheet with text, as the current app's Share.share({ message }).
struct TextShareSheet: UIViewControllerRepresentable {
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [text], applicationActivities: nil)
  }
  func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// An error on screen with a way to hand it over (AGENTS.md: every user-visible error is copyable).
struct ProblemView: View {
  let problem: MirrorProblem
  @State private var copied = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(problem.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
      Button(copied ? "Copied" : "Copy error") {
        UIPasteboard.general.string = problem.copyText
        copied = true
      }
      .font(.footnote)
    }
  }
}
