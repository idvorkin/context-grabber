//  Today (stories 002, 004, 005, 013, 019, 020, 029): when the last grab finished, the summary line, the body
//  cards with their week as a box plot, and the two shares. A grab runs on open, on coming back to the front,
//  every thirty minutes while open, and on a pull.

import ContextCore
import SwiftUI

struct TodayView: View {
  @ObservedObject var app: AppModel
  @ObservedObject var mirror: MirrorModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var shareText: ShareItem?
  @State private var showSettings = false

  private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
  private let every30 = Timer.publish(every: 30 * 60, on: .main, in: .common).autoconnect()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        header
        if let problem = mirror.problem { ProblemView(problem: problem) }
        if let h = mirror.snapshot?.health {
          let line = SummaryText.buildSummary(h, locationCount: 0)
          if !line.isEmpty {
            Text(line).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("today-summary")
          }
        }
        if mirror.snapshot == nil && !mirror.grabbing {
          Text("No data yet — pull to grab.").foregroundStyle(.secondary).padding(.top, 40).frame(maxWidth: .infinity)
        } else {
          LazyVGrid(columns: columns, spacing: 10) {
            ForEach(mirror.cards, id: \.key) { card in
              Button {
                app.openMetric(card.key, from: "card")
              } label: {
                CardView(card: card)
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("card-\(card.key.rawValue)")
            }
          }
        }
        shareButtons
        if let status = mirror.hookStatus {
          Text("Fixture hook: \(status)").font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("hook-\(status)")
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 24)
    }
    .refreshable { await mirror.grabNow(reason: "pull") }
    .navigationTitle("Today")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
      }
    }
    .onAppear {
      app.screen = "today"
      mirror.grab(reason: "open")
    }
    .onDisappear { if app.screen == "today" { app.screen = "home" } }
    .onChange(of: scenePhase) { _, phase in if phase == .active { mirror.grab(reason: "foreground") } }
    .onReceive(every30) { _ in mirror.grab(reason: "timer") }
    .sheet(item: $app.openMetricKey) { item in
      MetricDetailView(app: app, mirror: mirror, metric: item.key)
    }
    .sheet(item: $shareText) { item in ShareSheet(text: item.text) }
    .sheet(isPresented: $showSettings) { MirrorSettingsView(mirror: mirror) }
  }

  private var header: some View {
    HStack(spacing: 8) {
      if let phase = mirror.phase {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
          let secs = Int(ctx.date.timeIntervalSince(mirror.grabStartedAt ?? ctx.date))
          Label("\(phase) · \(secs)s", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        }
      }
      if let stamp = mirror.snapshot?.timestamp, let ms = parseISO(stamp) {
        Text("Grabbed \(jsDate(ms).formatted(date: .omitted, time: .shortened))")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("grab-time")
      }
      Spacer()
    }
  }

  private var shareButtons: some View {
    HStack {
      Button {
        share(.summary)
      } label: {
        Label("Share summary", systemImage: "square.and.arrow.up")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("share-summary")
      Button {
        share(.raw)
      } label: {
        Label("Share raw", systemImage: "curlybraces")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("share-raw")
    }
    .disabled(mirror.snapshot == nil)
    .padding(.top, 6)
  }

  private func share(_ kind: ExportKind) {
    app.log.event("ui", ["action": "share", "kind": kind.rawValue])
    if let text = mirror.export(kind) { shareText = ShareItem(text: text) }
  }
}

struct ShareItem: Identifiable {
  let id = UUID()
  let text: String
}

struct CardView: View {
  let card: MetricCard

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(card.label).font(.footnote.weight(.semibold)).foregroundStyle(Color(hex: card.color))
      Text(card.value)
        .font(.title3.weight(.bold).monospacedDigit())
        .foregroundStyle(card.isEmpty ? .secondary : .primary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(card.sublabel).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
      Spacer(minLength: 0)
      ForEach(Array(card.boxPlots.enumerated()), id: \.offset) { i, plot in
        BoxPlotView(stats: plot.0, color: Color(hex: plot.1), showEnds: card.boxPlots.count == 1 || i == 0)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
  }
}

/// Settings that belong to the mirror: the sleep target the debt line counts against (story 019).
struct MirrorSettingsView: View {
  @ObservedObject var mirror: MirrorModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Stepper(value: Binding(get: { mirror.sleepTarget }, set: { mirror.setSleepTarget($0) }), in: 4...12, step: 0.5) {
            LabeledContent("Sleep target", value: "\(SummaryText.js(mirror.sleepTarget)) h")
          }
        } footer: {
          Text("The Sleep sheet's debt line counts the week's nights against it.")
        }
        Section("About") {
          LabeledContent("Commit", value: BuildInfo.sha)
          LabeledContent("Branch", value: BuildInfo.branch)
          LabeledContent("Version", value: BuildInfo.version)
        }
      }
      .navigationTitle("Settings")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}
