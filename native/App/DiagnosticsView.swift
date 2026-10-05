//  The Diagnostics screen (story 140): which build this is, this launch's log, and the way to report a problem.
//  Until a journey is ported it is the whole app.

import SwiftUI

struct DiagnosticsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    NavigationStack {
      Form {
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
        Section("Ported so far") {
          Text("Nothing yet. Context Grabber is still the app to use.")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Grabber Native")
    }
    .onAppear { model.screen = "diagnostics" }
  }
}
