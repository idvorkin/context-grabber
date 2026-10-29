//  The home screen (stories 140, 147): the launchers in Igor's order, and a Settings tile for the rest — which
//  launchers show, the build, this launch's log and the way to report a problem.

import BugKit
import Combine
import ContextCore
import SwiftUI

struct DiagnosticsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationStack {
      Form {
        UsageSection(usage: model.usage)
        // Until its ✕; after that it lives in the Settings sheet (story 148).
        if model.whatsNewOnHome {
          Section {
            // BugKit's row: its ✕ remembers the newest change and hides the row until a newer build.
            WhatsNewRow(feed: model.whatsNew, reports: model.bugReports, logger: model.bugLogger) {
              model.openWhatsNew(from: "home")
            }
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
        // #284: every launcher the same small tile, three to a line, and Settings last (#286), never hidden.
        Section {
          VStack(spacing: 10) {
            ForEach(HomeLayout.lines(arrangement.tiles + [HomeRow.settings.id]), id: \.self) { line in
              HStack(spacing: 10) {
                ForEach(line, id: \.self) { id in
                  if let row = HomeRow.row(id) { HomeTile(row: row, model: model) }
                }
                // A short last line keeps its tiles the size of the rest.
                ForEach(line.count..<HomeLayout.perLine, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
              }
            }
          }
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
          if model.homeLayout.visible.isEmpty {
            Text("Every launcher is hidden. Settings brings them back.").foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        } footer: {
          // What a tap could not do (an app not installed) or what a report did.
          if let problem = model.homeProblem {
            BugProblemView(problem: problem, logger: model.bugLogger)
          } else if !model.status.isEmpty {
            Text(model.status)
          }
        }
      }
      // No bar at all (story 147): the usage card starts under the status bar.
      .toolbar(.hidden, for: .navigationBar)
      .contentMargins(.top, 8, for: .scrollContent)
      .contentMargins(.bottom, 64, for: .scrollContent)  // the last line scrolls clear of the mini player
      .listSectionSpacing(.compact)
      .environment(\.defaultMinListRowHeight, 30)  // lets the daily strip be slimmer than a list row
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
      ) {
        WhatsNewView(feed: model.whatsNew, reports: model.bugReports, logger: model.bugLogger, from: model.whatsNewFrom)
      }
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
      .navigationDestination(
        isPresented: Binding(
          get: { model.showInbox },
          set: {
            model.showInbox = $0
            if !$0 { model.screen = "home" }
          })
      ) { ChatListView(chat: model.chat, voice: model.chatVoice, logger: model.bugLogger) }
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

  /// What VoiceOver reads: the heading the card no longer draws, when the numbers were read, and the numbers.
  private var spoken: String {
    guard let snapshot = mirror.snapshot else { return "Today — tap to look" }
    let numbers = Self.shown.map { key in
      let card = mirror.cards.first { $0.key == key }
      let name = key == .movement ? "Steps" : card?.label ?? key.rawValue
      return "\((card?.value ?? MirrorText.none).replacingOccurrences(of: " asleep", with: "")) \(name)"
    }
    return "Today, as of \(SummaryText.formatLocalTime(snapshot.timestamp, clock: mirror.clock)): "
      + numbers.joined(separator: ", ")
  }

  var body: some View {
    Button(action: open) {
      // #355: just the numbers, no heading ("Today header adds nothing, just the content"); when they were read is
      // in the label VoiceOver reads.
      VStack(alignment: .leading, spacing: 10) {
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
                Text(key == .movement ? "Steps" : card?.label ?? key.rawValue).font(.caption2).foregroundStyle(
                  .secondary
                ).lineLimit(1)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      .padding(.vertical, 4)
    }
    .tint(.primary)
    .accessibilityLabel(spoken)
    .accessibilityIdentifier("home-today-card")
  }
}

/// Story 151: a launcher on the home screen, big enough to hit without looking; one line tall (#225), and the
/// same for the four and the rest (#235).
private struct HomeTile: View {
  let row: HomeRow
  @ObservedObject var model: AppModel

  @State private var showChoices = false
  /// Set by the long press so the lift that ends it is not also a tap.
  @State private var held = false
  /// Opened once the popover has gone: a full-screen cover presented while it is still closing would not show.
  @State private var chosen: HoldChoice?

  var body: some View {
    // #391: press and hold a tile with choices for a popover of drawn icons; every other tile keeps no hold at all.
    let choices = HoldChoices.choices(forTile: row.id)
    if choices.isEmpty {
      tile
    } else {
      tile
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            held = true
            showChoices = true
            model.holdOpened(tile: row.id)
          }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: showChoices) { _, open in open }
        // The popover can cancel the touch, or never show, so the lift may never reach the button.
        .onChange(of: showChoices) { _, open in if !open { held = false } }
        .accessibilityActions {
          ForEach(choices) { choice in Button(choice.title) { model.open(choice: choice) } }
        }
        .popover(isPresented: $showChoices) {
          HoldPopover(choices: choices, color: row.color) { choice in
            chosen = choice
            showChoices = false
          }
          .presentationCompactAdaptation(.popover)
          .onDisappear {
            guard let choice = chosen else { return }
            chosen = nil
            model.open(choice: choice)
          }
        }
    }
  }

  private var tile: some View {
    Button {
      if held {
        held = false
        return
      }
      row.open(model)
    } label: {
      // #304: the tile's drawn art and no name (Igor: "words are dups now"). #354: the art is trimmed to its object
      // and fills the tile ("tiles same size but icons take up more of it"): 88 points with 4 above and below keeps
      // the tile at its old 96. VoiceOver reads the full title below.
      TileArt(row: row, size: 88)
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        // A call left running: a corner badge, not a third line, so this tile stays its neighbours' size.
        .overlay(alignment: .topTrailing) {
          if row.id == "call" { CallTileStatus(call: model.call) }
          if row.id == "inbox" { ChatTileCount(chat: model.chat, inbox: model.inbox) }
        }
    }
    .buttonStyle(.plain)
    .foregroundStyle(.primary)
    .accessibilityLabel(row.title)
    .accessibilityIdentifier("home-\(row.id)")
  }
}

/// #391: a tile's choices, three to a row, each its picture with a short name under it.
private struct HoldPopover: View {
  let choices: [HoldChoice]
  /// The tile's colour, behind a preset's number and a symbol until the art is drawn.
  let color: Color
  let pick: (HoldChoice) -> Void

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 12), count: min(3, choices.count)), spacing: 12) {
      ForEach(choices) { choice in
        Button {
          pick(choice)
        } label: {
          VStack(spacing: 4) {
            picture(choice).frame(width: 64, height: 64)
            Text(choice.title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
          }
          .frame(width: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityIdentifier(choice.id)
      }
    }
    .padding(16)
  }

  @ViewBuilder private func picture(_ choice: HoldChoice) -> some View {
    if let art = choice.art, UIImage(named: art) != nil {
      Image(art).resizable().interpolation(.high).scaledToFit()
    } else {
      RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.gradient)
        .overlay {
          if let symbol = choice.symbol {
            Image(systemName: symbol).font(.system(size: 30, weight: .semibold))
          } else {
            // A preset: its number is the clearest picture of "2 MIN".
            Text(choice.title).font(.system(size: 18, weight: .heavy).monospacedDigit())
              .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, 4)
          }
        }
        .foregroundStyle(.white)
    }
  }
}

/// Chat (spec 2026-10-25): live threads with an unread reply from Larry plus messages not yet sent, in the tile's
/// corner as the call's badge is.
private struct ChatTileCount: View {
  @ObservedObject var chat: ChatModel
  @ObservedObject var inbox: InboxModel

  var body: some View {
    let count = chat.badgeCount
    if count > 0 {
      Text("\(count)").font(.caption2.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Color.blue, in: Capsule())
        .padding(6)
        .accessibilityLabel("\(count) unread or not yet sent")
        .accessibilityIdentifier("home-inbox-count")
    }
  }
}

private struct CallTileStatus: View {
  @ObservedObject var call: CallModel

  var body: some View {
    if call.snapshot.isActive {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        if let badge = call.snapshot.tileBadge(nowMs: context.date.timeIntervalSince1970 * 1000) {
          Text(badge).font(.caption2.weight(.semibold).monospacedDigit()).lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.green, in: Capsule())
            .padding(6)
            .accessibilityIdentifier("home-call-badge")
        }
      }
    }
  }
}

/// Behind the home screen's Settings tile (story 147): the Launchers page, then what used to sit under the launchers.
private struct HomeSettingsView: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var showLinks = false
  @State private var showWhatsNew = false
  /// Story 304: the Archive section, re-read on open and whenever an archive run ends while it is up.
  @State private var archiveLines: [ArchiveStatus.Line] = []
  @State private var loggedArchiveStatus = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          // #302: the launchers have their own page, so the rest of the sheet is one short list.
          NavigationLink {
            HomeLaunchersView(model: model)
          } label: {
            Label("Launchers", systemImage: "square.grid.3x3")
          }
          .accessibilityIdentifier("home-settings-launchers")
        }
        Section {
          // #303 (bug-kit#45): the same About page as Igor's other apps, from the built app's Info.plist.
          BugKitAboutLink()
            .accessibilityIdentifier("home-settings-about")
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
          Text("A troubled call files its log as a report on its own; the Mac files the issue.")
        }
        // Story 304: whether everything reached the Cockpit's archive, and which stream did not.
        Section {
          ForEach(Array(archiveLines.enumerated()), id: \.offset) { _, line in
            Text(line.text).font(.footnote).foregroundStyle(line.trouble ? Color.red : Color.secondary)
          }
          .accessibilityIdentifier("home-settings-archive")
        } header: {
          Text("Archive")
        } footer: {
          Text("Every few hours the trail, Health and the strip go to the Cockpit on their own.")
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
      .task {
        archiveLines = model.archive.statusLines()
        // Story 304: what the Archive section said, for a report or the simulator smoke: once per open, not again
        // when a pushed page pops back.
        guard !loggedArchiveStatus else { return }
        loggedArchiveStatus = true
        model.log.event(
          "archive_status", ["lines": archiveLines.map(\.text), "trouble": archiveLines.contains(where: \.trouble)])
      }
      .onReceive(model.archive.$lastRunEnded.dropFirst()) { _ in archiveLines = model.archive.statusLines() }
      .navigationDestination(isPresented: $showLinks) { LinksView(log: model.log) }
      .navigationDestination(isPresented: $showWhatsNew) {
        WhatsNewView(feed: model.whatsNew, reports: model.bugReports, logger: model.bugLogger, from: "home_settings")
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

/// Settings → Launchers (story 147, #302): which launchers the home screen shows and their order.
private struct HomeLaunchersView: View {
  @ObservedObject var model: AppModel

  var body: some View {
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
      } footer: {
        Text("Drag to reorder. A hidden launcher still opens from its link or Shortcut.")
      }
    }
    // The reorder handles always showing: dragging is what this page is for.
    .environment(\.editMode, .constant(.active))
    .navigationTitle("Launchers")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        // Closes the whole sheet, as the sheet's own Done does; a pushed page's dismiss would only pop back.
        Button("Done") { model.showHomeSettings = false }.accessibilityIdentifier("home-settings-done")
      }
    }
  }
}
