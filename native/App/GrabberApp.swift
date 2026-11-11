//  Grabber Native: the Swift-native Context Grabber, built beside the React Native app until it can replace it
//  (docs/superpowers/specs/2026-10-04-swift-native-app-design.md).

import ContextCore
import SwiftUI

@main
struct GrabberApp: App {
  @StateObject private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  init() {
    // Story 270: StateObject defers its wrapped-value expression until the view is installed. Make the model
    // now so its background-task handlers are registered before launch finishes (and crash capture starts here).
    let model = AppModel()
    _model = StateObject(wrappedValue: model)
    // Story 754: the UI tests' launches only.
    if LaunchHooks.current.noAnimations { UIView.setAnimationsEnabled(false) }
  }

  var body: some Scene {
    // The home window (#634: one at a time; another from this group offers a choice of screens instead, story 731. It alone takes links.
    WindowGroup(id: AppModel.homeWindowID) {
      HomeWindow(model: model)
        .onChange(of: scenePhase) { _, phase in model.phaseChanged(phase) }
    }
    .handlesExternalEvents(matching: ["*"])
    .commands { MacMenuCommands(model: model, reporter: model.reporter) }
    // Stories 460, 461: one screen in a window of its own.
    WindowGroup(for: WindowScreen.self) { $screen in
      Group {
        if let screen {
          ScreenWindow(model: model, screen: screen)
        } else {
          HomeWindow(model: model)
        }
      }
      .onChange(of: scenePhase) { _, phase in model.phaseChanged(phase) }
    }
    .handlesExternalEvents(matching: [])
  }
}
