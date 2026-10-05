//  The home screen while journeys move over (story 140): what is ported so far, which build this is, this
//  launch's log, and the way to report a problem.

import SwiftUI

struct DiagnosticsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Button {
            model.openCall(from: "home")
          } label: {
            CallRow(call: model.call)
          }
          .accessibilityIdentifier("home-call")
          Button {
            model.openToday(from: "home")
          } label: {
            Label("Today", systemImage: "heart.text.square").font(.title3.weight(.semibold)).padding(.vertical, 6)
          }
          .accessibilityIdentifier("open-today")
          Button {
            model.openGymTimer(from: "home")
          } label: {
            Label("Gym Timer", systemImage: "timer").font(.title3.weight(.semibold)).padding(.vertical, 6)
          }
          Button {
            model.openBreathe(from: "home")
          } label: {
            Label("Box breathing", systemImage: "wind").font(.title3.weight(.semibold)).padding(.vertical, 6)
          }
          .fullScreenCover(
            isPresented: Binding(get: { model.breathe != nil }, set: { if !$0 { model.closeBreathe() } })
          ) {
            BreatheView(app: model, launch: model.breathe ?? BreatheLaunch(), onExit: model.closeBreathe)
              .background(ShakeDetector { model.startBugReport(from: "shake") })
              .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
          }
          Button {
            model.openPlaces(from: "home")
          } label: {
            Label("Places", systemImage: "map").font(.title3.weight(.semibold)).padding(.vertical, 6)
          }
          .fullScreenCover(isPresented: Binding(get: { model.showPlaces }, set: { if !$0 { model.closePlaces() } })) {
            PlacesView(app: model, places: model.places, tracker: model.tracker, onExit: model.closePlaces)
              .background(ShakeDetector { model.startBugReport(from: "shake") })
              .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
          }
          Button {
            model.openThinkACard(from: "home")
          } label: {
            Label("Think of a card", systemImage: "suit.spade.fill").font(.title3.weight(.semibold))
              .padding(.vertical, 6)
          }
          Button {
            model.openCockpit(from: "home")
          } label: {
            Label("Cockpit", systemImage: "gauge.with.dots.needle.67percent").font(.title3.weight(.semibold))
              .padding(.vertical, 6)
          }
          .accessibilityIdentifier("home-cockpit")
        } header: {
          Text("Ported so far")
        } footer: {
          Text("Everything else is still in Context Grabber.")
        }
        Section {
          NavigationLink("Diagnostics uploads") { GistSettingsView(call: model.call) }
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
      .navigationTitle("Grabber Native")
      // Its own presenter: one view cannot hold two full-screen covers.
      .fullScreenCover(isPresented: Binding(get: { model.showCockpit }, set: { if !$0 { model.closeCockpit() } })) {
        CockpitView(model: model.cockpit, onDone: model.closeCockpit)
          .background(ShakeDetector { model.startBugReport(from: "shake") })
          .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
      }
      .fullScreenCover(isPresented: Binding(get: { model.callOpen }, set: { if !$0 { model.closeCall() } })) {
        CallView(call: model.call, onDone: model.closeCall)
          .background(ShakeDetector { model.startBugReport(from: "shake") })
          .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
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
        .background(ShakeDetector { model.startBugReport(from: "shake") })
        .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
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
