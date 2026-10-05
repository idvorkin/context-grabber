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
        } header: {
          Text("Ported so far")
        } footer: {
          Text("Everything else is still in Context Grabber.")
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
