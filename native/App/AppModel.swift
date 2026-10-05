//  What the whole app shares: the session log, the bug reporter, and which screen is in front (a report names it).

import ContextCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  let log = SessionLog()
  let database: AppDatabase
  private let bugReporter: BugReporter

  /// The screen in front, as a report and the log name it. Each ported journey sets it when it appears.
  @Published var screen = "home"
  @Published var showBugReport = false
  @Published var status = ""
  /// Non-nil while the Gym Timer covers the app; says how it was asked for.
  @Published var gymTimer: GymTimerLaunch?
  /// Non-nil while the breathing screen covers the app.
  @Published var breathe: BreatheLaunch?

  init() {
    database = AppDatabase(log: log)
    bugReporter = BugReporter(log: log)
    CrashReports.shared.onEvent = { [log] type, fields in log.event(type, fields) }
    CrashReports.shared.reportSignalLogs { type, fields in log.event(type, fields) }
    bugReporter.pruneOldLogs()
    runLaunchHooks()
  }

  /// A shake or the button: the picture is taken before the sheet covers the screen.
  func startBugReport(from source: String) {
    guard !showBugReport else { return }
    log.event("ui", ["action": "report_problem", "from": source, "screen": screen])
    bugReporter.capture()
    showBugReport = true
  }

  func bugContext() -> [String: String] {
    ["screen": screen, "build": "\(BuildInfo.sha) \(BuildInfo.branch)", "log": log.url.lastPathComponent]
  }

  func reportBug(note: String) {
    status = bugReporter.report(note: note, context: bugContext())
  }

  func openGymTimer(_ launch: GymTimerLaunch = GymTimerLaunch(), from source: String) {
    log.event("ui", ["action": "open_timer", "from": source, "autostart": launch.autostart])
    screen = "gym_timer"
    gymTimer = launch
  }

  func closeGymTimer() {
    log.event("ui", ["action": "close_timer"])
    screen = "home"
    gymTimer = nil
  }

  func openBreathe(_ launch: BreatheLaunch = BreatheLaunch(), from source: String) {
    log.event("ui", ["action": "open_breathe", "from": source, "autostart": launch.plan != nil])
    screen = "breathe"
    breathe = launch
  }

  func closeBreathe() {
    log.event("ui", ["action": "close_breathe"])
    screen = "home"
    breathe = nil
  }

  /// The simulator cannot be shaken or tapped from a script, so the app reads launch hooks from the environment
  /// (`SIMCTL_CHILD_<name>` through simctl); docs/TESTING.md lists them.
  private func runLaunchHooks() {
    let env = ProcessInfo.processInfo.environment
    if let spec = env["GRABBER_BREATHE"], !spec.isEmpty {
      // "breath,cycles[,cue[,pause_at_seconds]]" begins that exact session; anything else just opens the sliders.
      let parts = spec.split(separator: ",").map(String.init)
      var launch = BreatheLaunch()
      if parts.count >= 2, let breath = Int(parts[0]), let cycles = Int(parts[1]) {
        launch.plan = BreathPlan(breathSeconds: breath, cycles: cycles)
        launch.cue = parts.count > 2 ? BreathCue(rawValue: parts[2]) : nil
        launch.pauseAt = parts.count > 3 ? Double(parts[3]) : nil
      }
      openBreathe(launch, from: "hook")
    }
    if let spec = env["GRABBER_TIMER"], !spec.isEmpty {
      // A chip's id starts it as a tap on a widget tile would; "work,rest,rounds" runs that shape as Custom.
      var launch = GymTimerLaunch(autostart: true, turn: env["GRABBER_TURN"].flatMap(DeviceTurn.init(rawValue:)))
      let numbers = spec.split(separator: ",").compactMap { Int($0) }
      if numbers.count == 3 {
        launch.custom = CustomPreset(work: numbers[0], rest: numbers[1], rounds: numbers[2])
      } else {
        launch.preset = spec
      }
      openGymTimer(launch, from: "hook")
    }
    if let note = env["GRABBER_BUG"], !note.isEmpty {
      Task {
        try? await Task.sleep(for: .seconds(2))  // the first frame must be on screen for the picture
        bugReporter.capture()
        reportBug(note: note)
      }
    }
  }
}
