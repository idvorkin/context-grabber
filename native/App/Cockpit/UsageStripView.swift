//  The usage strip at the top of the home screen (story 203): what is left of Claude's week, the current model's
//  allowance and the ElevenLabs voice budget. Tap to ask the Cockpit for a fresh reading.

import ContextCore
import SwiftUI

/// The strip's section, drawn only when there is a reading (off the tailnet the home screen has no strip at all).
struct UsageSection: View {
  @ObservedObject var usage: UsageModel

  var body: some View {
    if let strip = usage.strip {
      Section { UsageStripView(strip: strip, usage: usage) }
    }
  }
}

struct UsageStripView: View {
  let strip: UsageStrip
  @ObservedObject var usage: UsageModel

  var body: some View {
    Button { usage.refresh() } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          ForEach(strip.bars, id: \.label) { bar in BarCell(bar: bar) }
        }
        HStack(spacing: 6) {
          if usage.refreshing {
            ProgressView().controlSize(.mini)
            Text("refreshing…")
          } else {
            if let spend = strip.spendNote {
              Text(spend).fontWeight(.semibold).foregroundStyle(.green)
              Text("·").foregroundStyle(.secondary)
            }
            if let note = strip.claudeNote {
              Text(note).foregroundStyle(strip.claudeStale ? .orange : .secondary)
            }
            if let note = strip.voiceNote {
              if strip.claudeNote != nil { Text("·").foregroundStyle(.secondary) }
              Text(note).foregroundStyle(strip.voiceStale ? .orange : .secondary)
            }
            if usage.lastLoadFailed, let at = usage.loadedAt {
              Text("· as of \(at, style: .relative) ago").foregroundStyle(.orange)
            }
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("usage-strip")
  }

  private struct BarCell: View {
    let bar: UsageStrip.Bar

    var color: Color {
      switch bar.level {
      case .ok: .accentColor
      case .low: .orange
      case .critical: .red
      }
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline) {
          Text(bar.label).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
          Spacer(minLength: 2)
          Text(bar.text).font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(bar.level == .ok ? Color.primary : color)
        }
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.secondary.opacity(0.2))
            Capsule().fill(color).frame(width: max(4, geo.size.width * bar.left))
          }
        }
        .frame(height: 6)
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(bar.label) \(bar.text) left")
    }
  }
}
