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
  /// Today (the mirror) is on screen.
  @Published var showToday = false
  /// The metric whose week is open over Today.
  @Published var openMetricKey: MetricSheetItem?
  /// The mirror: the last grab and the exports. Set at the end of init (it reads the database and the log).
  private(set) var mirror: MirrorModel!

  init() {
    database = AppDatabase(log: log)
    bugReporter = BugReporter(log: log)
    CrashReports.shared.onEvent = { [log] type, fields in log.event(type, fields) }
    CrashReports.shared.reportSignalLogs { type, fields in log.event(type, fields) }
    bugReporter.pruneOldLogs()
    mirror = MirrorModel(app: self)
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

  func openToday(from source: String) {
    log.event("ui", ["action": "open_today", "from": source])
    showToday = true
  }

  func openMetric(_ key: MetricKey, from source: String) {
    log.event("ui", ["action": "open_metric", "metric": key.rawValue, "from": source])
    openMetricKey = MetricSheetItem(key: key)
  }

  /// The simulator cannot be shaken or tapped from a script, so the app reads launch hooks from the environment
  /// (`SIMCTL_CHILD_<name>` through simctl); docs/TESTING.md lists them.
  private func runLaunchHooks() {
    let env = ProcessInfo.processInfo.environment
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
    if let mode = env["GRABBER_MIRROR"], !mode.isEmpty {
      // Today on screen, a grab of the fixture week (moved to this week), both exports written to
      // Documents/exports/; GRABBER_METRIC=<key> then opens that metric's sheet, for a screenshot.
      mirror.hookStatus = "running"  // before Today appears, so its own grab waits for the hook's
      openToday(from: "hook")
      let metric = env["GRABBER_METRIC"].flatMap(MetricKey.init(rawValue:))
      Task {
        await mirror.runFixtureHook(mode)
        if let metric { openMetric(metric, from: "hook") }
      }
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

struct MetricSheetItem: Identifiable, Equatable {
  let key: MetricKey
  var id: String { key.rawValue }
}
