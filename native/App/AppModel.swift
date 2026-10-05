//  What the whole app shares: the session log, the bug reporter, and which screen is in front (a report names it).

import ContextCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  let log = SessionLog()
  let database: AppDatabase
  /// The lock-screen card and the Dynamic Island, shared by the Gym Timer and Box breathing.
  let liveActivity: LiveActivityController
  /// The trail: recording runs whatever screen is in front, and iOS may launch the app just to deliver points.
  let tracker: LocationTracker
  let places: PlacesModel
  private let bugReporter: BugReporter

  /// The screen in front, as a report and the log name it. Each ported journey sets it when it appears.
  @Published var screen = "home"
  @Published var showBugReport = false
  @Published var status = ""
  /// Non-nil while the Gym Timer covers the app; says how it was asked for.
  @Published var gymTimer: GymTimerLaunch?
  /// Non-nil while the breathing screen covers the app.
  @Published var breathe: BreatheLaunch?
  @Published var showPlaces = false
  @Published var showPlacesMap = false

  init() {
    database = AppDatabase(log: log)
    liveActivity = LiveActivityController(log: log)
    tracker = LocationTracker(log: log, store: database.locations)
    places = PlacesModel(log: log, database: database)
    bugReporter = BugReporter(log: log)
    CrashReports.shared.onEvent = { [log] type, fields in log.event(type, fields) }
    CrashReports.shared.reportSignalLogs { type, fields in log.event(type, fields) }
    bugReporter.pruneOldLogs()
    places.prune(reason: "launch")
    liveActivity.endLeftovers()
    runLaunchHooks()
  }

  /// The app came to the front (not the launch itself): prune, settle a pending permission, ask for a fix.
  func foreground() {
    places.prune(reason: "foreground")
    tracker.foreground()
    if showPlaces { places.reload(reason: "foreground") }
  }

  func openPlaces(from source: String) {
    log.event("ui", ["action": "open_places", "from": source])
    screen = "places"
    showPlaces = true
    places.reload(reason: "open")
    // Places is where You lives: the first open asks for While Using (the switch asks for Always).
    tracker.requestFix(reason: tracker.authorization == .notDetermined ? "places_open" : "foreground")
  }

  func closePlaces() {
    log.event("ui", ["action": "close_places"])
    screen = "home"
    showPlaces = false
    showPlacesMap = false
  }

  /// A file shared to the app or opened in it from Files: Context Grabber's database export (story 055).
  func open(url: URL) {
    log.event("ui", ["action": "open_url", "scheme": url.scheme ?? "", "file": url.isFileURL ? url.lastPathComponent : ""])
    guard url.isFileURL else { return }
    if !showPlaces { openPlaces(from: "file") }
    places.importDatabase(url, from: "file")
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

  /// A journey still in Context Grabber, opened there by its own link.
  func openInContextGrabber(_ link: String, what: String) {
    guard let url = URL(string: link) else { return }
    UIApplication.shared.open(url) { [log] ok in
      log.event("ui", ["action": "open_context_grabber", "what": what, "ok": ok])
      if !ok { Task { @MainActor in self.status = "Context Grabber is not installed, so the \(what) cannot open." } }
    }
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
    // Places (docs/TESTING.md): import first, so the other hooks see the imported trail.
    if let spec = env["GRABBER_IMPORT_DB"], !spec.isEmpty {
      // "<file>[,recent]": a path, absolute or under Documents; "recent" shifts it by whole weeks into the last seven days.
      let parts = spec.split(separator: ",").map(String.init)
      let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let url = parts[0].hasPrefix("/") ? URL(fileURLWithPath: parts[0]) : docs.appendingPathComponent(parts[0])
      places.importDatabase(url, from: "hook", recent: parts.dropFirst().contains("recent"))
    }
    if let spec = env["GRABBER_RETENTION"], let days = Int(spec) {
      places.setRetention(days, from: "hook")
    }
    if let spec = env["GRABBER_TRACKING"], !spec.isEmpty {
      tracker.setTracking(spec == "on", from: "hook")
    }
    if let spec = env["GRABBER_PLACES"], !spec.isEmpty {
      // "open" opens the screen; "map" also opens the map full screen.
      openPlaces(from: "hook")
      if spec == "map" { showPlacesMap = true }
    }
    if env["GRABBER_EXPORT"] == "1" {
      // Prepares the file as Export database does, without the share sheet a script cannot dismiss.
      places.prepareExport(from: "hook")
      places.exportFile = nil
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
