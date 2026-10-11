//  The home screen (stories 140, 147): the launchers in Igor's order, and a cog for the rest — which launchers
//  show, the build, this launch's log and the way to report a problem.

import BugKit
import ContextCore
import SwiftUI

struct DiagnosticsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationStack {
      Form {
        UsageSection(usage: model.usage)
        // Until its ✕; after that it lives in the cog's sheet (story 148).
        if model.whatsNewOnHome {
          Section {
            // BugKit's row: its ✕ remembers the newest change and hides the row until a newer build.
            WhatsNewRow(feed: model.whatsNew, logger: model.bugLogger) { model.openWhatsNew(from: "home") }
              // Two buttons in one row: without this a tap anywhere fires both.
              .buttonStyle(.borderless)
          }
        }
        // Story 151 (#189): the mirror first, then the launchers as tiles.
        let arrangement = model.homeLayout.arrangement
        if arrangement.todayCard {
          Section {
            TodayCard(mirror: model.mirror) { model.openToday(from: "home_card") }
          }
        }
        if arrangement.dailyStrip {
          Section {
            DailyStripView(strip: model.dailyStrip)
              .onChange(of: model.mirror.snapshot?.timestamp) { model.dailyStrip.refresh() }  // a grab
              // Tight (Igor): its own slim card, not a 44-point list row.
              .padding(.vertical, 5)
              .padding(.horizontal, 8)
              .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
              .listRowInsets(EdgeInsets())
              .listRowBackground(Color.clear)
          }
        }
        // #235: one look for every launcher. The four two by two, then the rest in order: a pair is two tiles
        // like the four's, a launcher alone one tile the width of two.
        Section {
          let lines = stride(from: 0, to: arrangement.tiles.count, by: 2).map {
            Array(arrangement.tiles[$0..<min($0 + 2, arrangement.tiles.count)])
          } + HomeLayout.lines(arrangement.rows)
          VStack(spacing: 12) {
            ForEach(lines, id: \.self) { line in
              HStack(spacing: 12) {
                ForEach(line, id: \.self) { id in
                  if let row = HomeRow.row(id) {
                    HomeTile(row: row, model: model, half: line.count == 2 && !arrangement.tiles.contains(id))
                  }
                }
                // One of the four left alone (the rest hidden) keeps its half, so it still lines up.
                if line.count == 1, arrangement.tiles.contains(line[0]) { Color.clear.frame(maxWidth: .infinity) }
              }
            }
          }
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
          if model.homeLayout.visible.isEmpty {
            Text("Every launcher is hidden. The cog brings them back.").foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        } footer: {
          // What a tap could not do (an app not installed) or what a report did.
          if !model.status.isEmpty { Text(model.status) }
        }
      }
      // No bar at all (story 147): the usage card starts under the status bar, and the cog sits in the bottom
      // corner, over the list's end, where it costs no row.
      .toolbar(.hidden, for: .navigationBar)
      .contentMargins(.top, 8, for: .scrollContent)
      .contentMargins(.bottom, 64, for: .scrollContent)  // the last row scrolls clear of the cog
      .listSectionSpacing(.compact)
      .environment(\.defaultMinListRowHeight, 30)  // lets the daily strip be slimmer than a list row
      .overlay(alignment: .bottomTrailing) {
        Button {
          model.openHomeSettings()
        } label: {
          Image(systemName: "gearshape").font(.title3).padding(12)
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 8)
        .accessibilityLabel("Home screen settings")
        .accessibilityIdentifier("home-settings")
      }
      .overlay(alignment: .bottomLeading) {
        if !model.showEulogySong {
          EulogyMiniPlayer(song: model.eulogySong) { model.showEulogySongSheet(from: "mini") }
            .padding(.leading, 20)
            .padding(.bottom, 8)
        }
      }
      .sheet(isPresented: Binding(get: { model.showHomeSettings }, set: { if !$0 { model.closeHomeSettings() } })) {
        HomeSettingsView(model: model)
          // A sheet is its own presentation, as the covers are: the report sheet has to come from inside it.
          .bugReporting(model.reporter)
      }
      // Each cover on a view of its own (one view cannot hold two), and none on a row: a hidden row's journey
      // still opens from a link, a Shortcut or a hook.
      .background {
        Color.clear.fullScreenCover(
          isPresented: Binding(get: { model.breathe != nil }, set: { if !$0 { model.closeBreathe() } })
        ) {
          BreatheView(app: model, launch: model.breathe ?? BreatheLaunch(), onExit: model.closeBreathe)
            .bugReporting(model.reporter)
        }
      }
      .background {
        Color.clear.fullScreenCover(
          isPresented: Binding(get: { model.card != nil }, set: { if !$0 { model.closeCard() } })
        ) {
          CardView(app: model, think: model.card ?? false, onDone: model.closeCard)
            .bugReporting(model.reporter)
        }
      }
      .background {
        Color.clear.fullScreenCover(
          isPresented: Binding(get: { model.showPlaces }, set: { if !$0 { model.closePlaces() } })
        ) {
          PlacesView(app: model, places: model.places, tracker: model.tracker, onExit: model.closePlaces)
            .bugReporting(model.reporter)
        }
      }
      // Its own presenter: one view cannot hold two full-screen covers.
      .fullScreenCover(isPresented: Binding(get: { model.showCockpit }, set: { if !$0 { model.closeCockpit() } })) {
        CockpitView(model: model.cockpit, onDone: model.closeCockpit)
          .bugReporting(model.reporter)
      }
      .fullScreenCover(isPresented: Binding(get: { model.callOpen }, set: { if !$0 { model.closeCall() } })) {
        CallView(call: model.call, onDone: model.closeCall)
          .bugReporting(model.reporter)
      }
      .navigationDestination(
        isPresented: Binding(
          get: { model.showWhatsNew },
          set: {
            model.showWhatsNew = $0
            if !$0 { model.screen = "home" }
          })
      ) { WhatsNewView(feed: model.whatsNew, logger: model.bugLogger, from: model.whatsNewFrom) }
      .sheet(
        isPresented: Binding(
          get: { model.showEulogySong },
          set: {
            model.showEulogySong = $0
            if !$0 { model.screen = "home" }
          })
      ) {
        EulogySongView(song: model.eulogySong) { model.openEulogySong(from: "eulogy_song_sheet") }
          .bugReporting(model.reporter)
      }
      .navigationDestination(isPresented: $model.showToday) {
        TodayView(app: model, mirror: model.mirror)
      }
    }
    .fullScreenCover(
      isPresented: Binding(get: { model.gymTimer != nil }, set: { if !$0 { model.closeGymTimer() } })
    ) {
      GymTimerView(app: model, launch: model.gymTimer ?? GymTimerLaunch(), onExit: model.closeGymTimer)
        // A cover is its own presentation: the app's shake detector and report sheet do not reach into it.
        .bugReporting(model.reporter)
    }
  }
}

/// Story 151: the last grab on the home screen. Never grabs itself (so opening the app asks Health nothing); a tap
/// opens Today, which does.
private struct TodayCard: View {
  @ObservedObject var mirror: MirrorModel
  let open: () -> Void

  private static let shown: [MetricKey] = [.sleep, .movement, .hrv, .exerciseMinutes]

  var body: some View {
    Button(action: open) {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          HStack(spacing: 10) {
            if let row = HomeRow.row("today") { LauncherIcon(row: row) }
            Text("Today").font(.headline)
          }
          Spacer()
          if let stamp = mirror.snapshot?.timestamp {
            Text("as of \(SummaryText.formatLocalTime(stamp, clock: mirror.clock))")
              .font(.caption).foregroundStyle(.secondary)
          }
          Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        if mirror.snapshot == nil {
          Text("Today — tap to look").foregroundStyle(.secondary)
        } else {
          let cards = mirror.cards.filter { Self.shown.contains($0.key) }
          HStack(alignment: .top, spacing: 8) {
            ForEach(Self.shown, id: \.self) { key in
              let card = cards.first { $0.key == key }
              VStack(alignment: .leading, spacing: 2) {
                // Short forms for a glance: "6.8h", not "6.8h asleep"; steps under their own name.
                Text((card?.value ?? MirrorText.none).replacingOccurrences(of: " asleep", with: ""))
                  .font(.title3.weight(.semibold).monospacedDigit())
                  .lineLimit(1).minimumScaleFactor(0.6)
                Text(key == .movement ? "Steps" : card?.label ?? key.rawValue).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      .padding(.vertical, 4)
    }
    .tint(.primary)
    .accessibilityIdentifier("home-today-card")
  }
}

/// Story 151: a launcher on the home screen, big enough to hit without looking; one line tall (#225), and the
/// same for the four and the rest (#235).
private struct HomeTile: View {
  let row: HomeRow
  @ObservedObject var model: AppModel
  /// Half of a shared line (#225): the short name.
  var half = false

  var body: some View {
    Button { row.open(model) } label: {
      HStack(spacing: 10) {
        LauncherIcon(row: row, size: 32)
        VStack(alignment: .leading, spacing: 1) {
          Text(half ? row.short : row.title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
          if row.id == "call" { CallTileStatus(call: model.call) }
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .foregroundStyle(.primary)
    .accessibilityLabel(row.title)
    .accessibilityIdentifier("home-\(row.id)")
  }
}

private struct CallTileStatus: View {
  @ObservedObject var call: CallModel

  var body: some View {
    if call.snapshot.isActive {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        Text(call.status(now: context.date)).font(.caption.monospacedDigit()).foregroundStyle(.green)
      }
    }
  }
}

/// Behind the home screen's cog (story 147): the launchers to show and their order, then what used to sit under them.
private struct HomeSettingsView: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var showUploads = false
  @State private var showLinks = false
  @State private var showWhatsNew = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(model.homeLayout.order, id: \.self) { id in
            if let row = HomeRow.row(id) {
              Toggle(isOn: Binding(get: { model.homeLayout.isShown(id) }, set: { model.setHomeRow(id, shown: $0) })) {
                HStack(spacing: 12) {
                  LauncherIcon(row: row)
                  Text(row.title)
                }
              }
              .accessibilityIdentifier("home-row-\(id)")
            }
          }
          .onMove { model.moveHomeRows(fromOffsets: $0, toOffset: $1) }
          Button("Reset to default") { model.resetHomeRows() }
            .accessibilityIdentifier("home-rows-reset")
        } header: {
          Text("Launchers")
        } footer: {
          Text("Drag to reorder. A hidden launcher still opens from its link or Shortcut.")
        }
        Section {
          // A button, not a NavigationLink: edit mode (for the drag handles) disables links.
          Button {
            showUploads = true
          } label: {
            HStack {
              Text("Diagnostics uploads").foregroundStyle(.primary)
              Spacer()
              Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
          }
          .tint(.primary)
          .accessibilityIdentifier("home-diagnostics-uploads")
          Button {
            showWhatsNew = true
          } label: {
            HStack {
              Text("What's new").foregroundStyle(.primary)
              Spacer()
              Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
          }
          .tint(.primary)
          .accessibilityIdentifier("home-settings-whats-new")
          Button {
            showLinks = true
          } label: {
            HStack {
              Text("Links for Shortcuts").foregroundStyle(.primary)
              Spacer()
              Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
          }
          .tint(.primary)
          .accessibilityIdentifier("home-links")
          // Story 149: when the phone's sound is stuck after a call, a workout or breathing.
          Button("Reset audio") { model.resetAudio() }
            .disabled(model.call.snapshot.isActive)
            .accessibilityIdentifier("home-reset-audio")
          if model.call.snapshot.isActive {
            Text("A call is live: ending it resets the audio.").font(.footnote).foregroundStyle(.secondary)
          } else if !model.audioResetLine.isEmpty {
            Text(model.audioResetLine).font(.footnote).foregroundStyle(.secondary)
              .accessibilityIdentifier("home-reset-audio-result")
          }
        } header: {
          Text("About and diagnostics")
        } footer: {
          Text(model.call.hasToken ? "A troubled call's log goes up as a private gist." : "No GitHub token saved.")
        }
        Section("Build") {
          LabeledContent("Commit", value: BuildInfo.sha)
          LabeledContent("Branch", value: BuildInfo.branch)
          LabeledContent("Version", value: BuildInfo.version)
        }
        Section {
          LabeledContent("Log", value: model.log.url.lastPathComponent)
          LabeledContent("Started", value: model.log.startedAt.formatted(date: .abbreviated, time: .standard))
        } header: {
          Text("This launch")
        } footer: {
          Text("Logs are in Files → On My iPhone → Grabber Native → logs.")
        }
        Section {
          Button("Report a problem") { model.startBugReport(from: "button") }
            .accessibilityIdentifier("home-settings-report")  // BugKit's hidden ⌘I button has the same name
          if !model.status.isEmpty { Text(model.status).foregroundStyle(.secondary) }
        } footer: {
          Text("Or shake the phone on any screen.")
        }
      }
      // The reorder handles always showing: dragging is what this sheet is for.
      .environment(\.editMode, .constant(.active))
      .navigationDestination(isPresented: $showUploads) { GistSettingsView(call: model.call) }
      .navigationDestination(isPresented: $showLinks) { LinksView(log: model.log) }
      .navigationDestination(isPresented: $showWhatsNew) {
        WhatsNewView(feed: model.whatsNew, logger: model.bugLogger, from: "home_settings")
      }
      .navigationTitle("Home screen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }.accessibilityIdentifier("home-settings-done")
        }
      }
    }
  }
}
