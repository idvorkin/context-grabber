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
  /// True while the Cockpit covers the app. The page itself outlives this: see `cockpit`.
  @Published var showCockpit = false

  /// Made on the first open and kept for the launch, so closing the Cockpit hides the page rather than closing it.
  /// `GRABBER_COCKPIT_URL` points it elsewhere (a URL, or a page in the app bundle) for the simulator's checks.
  private(set) lazy var cockpit = CockpitModel(
    log: log, override: ProcessInfo.processInfo.environment["GRABBER_COCKPIT_URL"])
  /// The call screen covers the app. The call itself is `call`'s and outlives the screen.
  @Published var callOpen = false
  let call: CallModel
  /// Today (the mirror) is on screen.
  @Published var showToday = false
  /// The metric whose week is open over Today.
  @Published var openMetricKey: MetricSheetItem?
  /// The mirror: the last grab and the exports. Set at the end of init (it reads the database and the log).
  private(set) var mirror: MirrorModel!

  init() {
    database = AppDatabase(log: log)
    liveActivity = LiveActivityController(log: log)
    tracker = LocationTracker(log: log, store: database.locations)
    places = PlacesModel(log: log, database: database)
    bugReporter = BugReporter(log: log)
    call = CallModel(log: log, database: database, environment: ProcessInfo.processInfo.environment)
    CrashReports.shared.onEvent = { [log] type, fields in log.event(type, fields) }
    CrashReports.shared.reportSignalLogs { type, fields in log.event(type, fields) }
    bugReporter.pruneOldLogs()
    places.prune(reason: "launch")
    liveActivity.endLeftovers()
    CallLauncher.handler = { [weak self] backend in self?.callFromShortcut(backend) }
    mirror = MirrorModel(app: self)
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

  /// Think a Card Trainer, Igor's own app, opened straight into "think of a card" (its story 063).
  func openThinkACard(from source: String) {
    guard let url = URL(string: "thinkacard://think") else { return }
    UIApplication.shared.open(url) { [log] ok in
      log.event("ui", ["action": "open_think_a_card", "from": source, "ok": ok])
      if !ok { Task { @MainActor in self.status = "Think a Card is not installed, so the card cannot open." } }
    }
  }

  func openCockpit(from source: String) {
    log.event("ui", ["action": "open_cockpit", "from": source, "first": !cockpitOpened])
    cockpitOpened = true
    screen = "cockpit"
    showCockpit = true
  }

  func closeCockpit() {
    log.event("ui", ["action": "close_cockpit"])
    screen = "home"
    showCockpit = false
  }

  private var cockpitOpened = false

  func openCall(from source: String) {
    log.event("ui", ["action": "open_call", "from": source, "state": call.snapshot.state.rawValue])
    if gymTimer != nil { closeGymTimer() }
    screen = "call"
    callOpen = true
  }

  func closeCall() {
    log.event("ui", ["action": "close_call", "state": call.snapshot.state.rawValue])
    screen = "home"
    callOpen = false
  }

  /// The "Call Larry" Shortcut: the call screen, and a call unless one is already up (it is brought forward).
  private func callFromShortcut(_ backend: CallBackend?) {
    openCall(from: "shortcut")
    guard !call.snapshot.isActive else { return }
    if let backend { call.backend = backend }
    call.start(from: "shortcut")
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
    if let spec = env["GRABBER_BREATHE"], !spec.isEmpty {
      // "breath,cycles[,cue[,pause_at_seconds]]" begins that exact session; anything else just opens the sliders.
      let parts = spec.split(separator: ",").map(String.init)
      var launch = BreatheLaunch()
      launch.style = env["GRABBER_BREATHE_STYLE"].flatMap(BreathStyle.init(rawValue:))
      if parts.count >= 2, let breath = Int(parts[0]), let cycles = Int(parts[1]) {
        launch.plan = BreathPlan(breathSeconds: breath, cycles: cycles)
        launch.cue = parts.count > 2 ? BreathCue(rawValue: parts[2]) : nil
        launch.pauseAt = parts.count > 3 ? Double(parts[3]) : nil
      }
      openBreathe(launch, from: "hook")
    }
    let voice = env["GRABBER_COUNT_VOICE"].flatMap(CountVoice.init(rawValue:))
    if let spec = env["GRABBER_TIMER"], !spec.isEmpty {
      // A chip's id starts it as a tap on a widget tile would; "work,rest,rounds" runs that shape as Custom.
      var launch = GymTimerLaunch(
        autostart: true, turn: env["GRABBER_TURN"].flatMap(DeviceTurn.init(rawValue:)), voice: voice)
      let numbers = spec.split(separator: ",").compactMap { Int($0) }
      if numbers.count == 3 {
        launch.custom = CustomPreset(work: numbers[0], rest: numbers[1], rounds: numbers[2])
      } else {
        launch.preset = spec
      }
      openGymTimer(launch, from: "hook")
    } else if env["GRABBER_TIMER_SETTINGS"] == "1" {
      openGymTimer(GymTimerLaunch(voice: voice, settings: true), from: "hook")
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
    if env["GRABBER_COCKPIT"] == "open" { openCockpit(from: "hook") }
    if let bridge = env["GRABBER_CALL"], !bridge.isEmpty {
      // A call to that bridge (the smoke run's fake one), hung up after GRABBER_CALL_SECONDS (default 8).
      openCall(from: "hook")
      let seconds = Double(env["GRABBER_CALL_SECONDS"] ?? "") ?? 8
      Task {
        try? await Task.sleep(for: .seconds(1))
        call.start(from: "hook")
        try? await Task.sleep(for: .seconds(seconds))
        if call.snapshot.isActive { call.hangUp(from: "hook") }
      }
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
