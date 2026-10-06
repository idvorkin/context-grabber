//  Grabber Native: the Swift-native Context Grabber, built beside the React Native app until it can replace it
//  (docs/superpowers/specs/2026-10-04-swift-native-app-design.md).

import SwiftUI

@main
struct GrabberApp: App {
  @StateObject private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var wasActive = false

  init() {
    CrashReports.shared.install()  // before the model: its init announces last launch's crash files
    _model = StateObject(wrappedValue: AppModel())
  }

  var body: some Scene {
    WindowGroup {
      DiagnosticsView(model: model)
        .background(ShakeDetector { model.startBugReport(from: "shake") })
        .sheet(isPresented: $model.showBugReport) { BugReportSheet(model: model) }
        .onOpenURL { model.open(url: $0) }
        .onChange(of: scenePhase) { _, phase in
          // The first activation is the launch, which pruned already; every later one is a foreground.
          if phase == .active { model.shakeMotion.start() } else { model.shakeMotion.stop() }
          if phase == .active {
            if wasActive { model.foreground() } else { model.tracker.foreground(); model.usage.resume(reason: "launch") }
            wasActive = true
          } else if phase == .background {
            model.usage.pause()
          }
        }
    }
  }
}
