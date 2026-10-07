//  The home screen (stories 140, 147): the launchers in Igor's order, and a cog for the rest — which launchers
//  show, the build, this launch's log and the way to report a problem.

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
            HStack(spacing: 8) {
              Button {
                model.openWhatsNew(from: "home")
              } label: {
                WhatsNewRow(feed: model.whatsNew).frame(maxWidth: .infinity, alignment: .leading)
              }
              .tint(.primary)  // a quiet line above the launchers, not another launcher
              .accessibilityIdentifier("home-whats-new")
              Button {
                withAnimation { model.dismissWhatsNew() }
              } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
              }
              .accessibilityLabel("Dismiss What's new")
              .accessibilityIdentifier("home-whats-new-dismiss")
            }
            // Two buttons in one row: without this a tap anywhere fires both.
            .buttonStyle(.borderless)
          }
        }
        Section {
          ForEach(model.homeLayout.visible, id: \.self) { id in
            if let row = HomeRow.row(id) {
              Button {
                row.open(model)
              } label: {
                if id == "call" {
                  CallRow(call: model.call)
                } else {
                  Label(row.title, systemImage: row.icon).font(.title3.weight(.semibold)).padding(.vertical, 6)
                }
              }
              .accessibilityIdentifier("home-\(id)")
            }
          }
          if model.homeLayout.visible.isEmpty {
            Text("Every launcher is hidden. The cog brings them back.").foregroundStyle(.secondary)
          }
        } footer: {
          // What a tap could not do (an app not installed) or what a report did.
          if !model.status.isEmpty { Text(model.status) }
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.openHomeSettings()
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel("Home screen settings")
          .accessibilityIdentifier("home-settings")
        }
      }
      .sheet(isPresented: Binding(get: { model.showHomeSettings }, set: { if !$0 { model.closeHomeSettings() } })) {
        HomeSettingsView(model: model)
          // A sheet is its own presentation, as the covers are: the report sheet has to come from inside it.
          .background(ShakeDetector { model.startBugReport(from: "shake") })
      }
      // Each cover on a view of its own (one view cannot hold two), and none on a row: a hidden row's journey
      // still opens from a link, a Shortcut or a hook.
      .background {
        Color.clear.fullScreenCover(
          isPresented: Binding(get: { model.breathe != nil }, set: { if !$0 { model.closeBreathe() } })
        ) {
          BreatheView(app: model, launch: model.breathe ?? BreatheLaunch(), onExit: model.closeBreathe)
            .background(ShakeDetector { model.startBugReport(from: "shake") })
        }
      }
      .background {
        Color.clear.fullScreenCover(
          isPresented: Binding(get: { model.showPlaces }, set: { if !$0 { model.closePlaces() } })
        ) {
          PlacesView(app: model, places: model.places, tracker: model.tracker, onExit: model.closePlaces)
            .background(ShakeDetector { model.startBugReport(from: "shake") })
        }
      }
      // No title (story 147): the space goes to the rows. Inline keeps the bar to the cog's height.
      .navigationBarTitleDisplayMode(.inline)
      // Its own presenter: one view cannot hold two full-screen covers.
      .fullScreenCover(isPresented: Binding(get: { model.showCockpit }, set: { if !$0 { model.closeCockpit() } })) {
        CockpitView(model: model.cockpit, onDone: model.closeCockpit)
          .background(ShakeDetector { model.startBugReport(from: "shake") })
      }
      .fullScreenCover(isPresented: Binding(get: { model.callOpen }, set: { if !$0 { model.closeCall() } })) {
        CallView(call: model.call, onDone: model.closeCall)
          .background(ShakeDetector { model.startBugReport(from: "shake") })
      }
      .navigationDestination(
        isPresented: Binding(
          get: { model.showWhatsNew },
          set: {
            model.showWhatsNew = $0
            if !$0 { model.screen = "home" }
          })
      ) { WhatsNewView(feed: model.whatsNew) }
      .navigationDestination(isPresented: $model.showToday) {
        TodayView(app: model, mirror: model.mirror)
      }
    }
    .fullScreenCover(
      isPresented: Binding(get: { model.gymTimer != nil }, set: { if !$0 { model.closeGymTimer() } })
    ) {
      GymTimerView(app: model, launch: model.gymTimer ?? GymTimerLaunch(), onExit: model.closeGymTimer)
        // A cover is its own presentation: the app's shake detector and report sheet do not reach into it.
        .background(ShakeDetector { model.startBugReport(from: "shake") })
    }
  }
}

/// The home screen's Call row: *Call Larry* idle, the live line while a call is up.
private struct CallRow: View {
  @ObservedObject var call: CallModel

  var body: some View {
    HStack {
      Label("Call Larry", systemImage: "phone.fill").font(.title3.weight(.semibold))
      Spacer()
      if call.snapshot.isActive {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Text(call.status(now: context.date)).font(.footnote.monospacedDigit()).foregroundStyle(.green)
        }
      }
    }
    .padding(.vertical, 6)
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
                Label(row.title, systemImage: row.icon)
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
            model.logWhatsNewOpened(from: "home_settings")
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
          if !model.status.isEmpty { Text(model.status).foregroundStyle(.secondary) }
        } footer: {
          Text("Or shake the phone on any screen.")
        }
      }
      // The reorder handles always showing: dragging is what this sheet is for.
      .environment(\.editMode, .constant(.active))
      .navigationDestination(isPresented: $showUploads) { GistSettingsView(call: model.call) }
      .navigationDestination(isPresented: $showLinks) { LinksView(log: model.log) }
      .navigationDestination(isPresented: $showWhatsNew) { WhatsNewView(feed: model.whatsNew) }
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
