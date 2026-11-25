//  The simulator cannot be shaken or tapped from a script, so the app reads launch hooks from the environment
//  (`SIMCTL_CHILD_<name>` through simctl); docs/TESTING.md lists them. ContextCore's `LaunchHooks` reads them (its
//  host tests cover every grammar); this runs them, each feature's in its own directory (#796), so a change to one
//  feature's hook is that feature's change.

import BugKit
import ContextCore
import Foundation

extension LaunchHooks {
  /// The one place the app reads its environment.
  static let environment = ProcessInfo.processInfo.environment
  /// This launch's hooks.
  static let current = LaunchHooks(environment)
}

extension AppModel {
  func runLaunchHooks() {
    for step in LaunchHooks.current.steps {
      switch step {
      case .breathe(let hook): runBreatheHook(hook)
      case .timer(let hook): runTimerHook(hook)
      case .importDatabase(let hook): runImportDatabaseHook(hook)
      case .retention(let days): places.setRetention(days, from: "hook")
      case .tracking(let on): tracker.setTracking(on, from: "hook")
      case .places(let hook): runPlacesHook(hook)
      case .export: runExportHook()
      case .drill(let mode): runDrillHook(mode)
      case .cockpit: openCockpit(from: "hook")
      case .boardFixture(let hook): runBoardFixtureHook(hook)
      case .whiteboard: openWhiteboard(from: "hook")
      // Story 1020: a bare PaperKit paper over the app, for the touch contracts' UI tests.
      case .paperStage(let hook): PaperTouchStage.show(hook)
      case .whatsNew: openWhatsNew(from: "hook")
      case .homeSettings: openHomeSettings()
      case .inkSideBySide: openInkSideBySide()
      case .supermix(let mix): openWorkoutSupermix(from: "hook", mix: mix)
      // #305: three Inbox items as the share extension writes them (never sent), and the Inbox opened.
      case .inboxFixture: inbox.addFixture()
      case .inbox: openInbox(from: "hook")
      case .chatSend(let hook): runChatSendHook(hook)
      case .chatSendFile(let hook): runChatSendFileHook(hook)
      case .chatSendAgain: runChatSendAgainHook()
      case .chatNew(let voice): runChatNewHook(voice: voice)
      // Story 270: an archive run now, to GRABBER_ARCHIVE_URL (a simulator or a Mac build sends nowhere else).
      case .archive: archive.run(reason: "hook")
      case .call(let seconds): runCallHook(seconds: seconds)
      case .callThread: runCallThreadHook()
      case .mirror(let mode, let metric): runMirrorHook(mode, metric: metric)
      // As if iOS had opened the link: simctl openurl stops at a confirmation a script cannot tap.
      case .link(let url): open(url: url)
      }
    }
    // GRABBER_SHAKE_AFTER (a shake after that many seconds, over whatever is up: #182) and GRABBER_BUG ("a|b",
    // reports saved with no dialog) are BugKit's hooks under this app's prefix.
    reporter.runLaunchHooks(LaunchHooks.environment)
  }
}
