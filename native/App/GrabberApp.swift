//  Grabber Native: the Swift-native Context Grabber, built beside the React Native app until it can replace it
//  (docs/superpowers/specs/2026-10-04-swift-native-app-design.md).

import SwiftUI

@main
struct GrabberApp: App {
  @StateObject private var model: AppModel

  init() {
    CrashReports.shared.install()  // before the model: its init announces last launch's crash files
    _model = StateObject(wrappedValue: AppModel())
  }

  var body: some Scene {
    WindowGroup {
      DiagnosticsView(model: model)
        .background(ShakeDetector { model.startBugReport(from: "shake") })
        .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
    }
  }
}
