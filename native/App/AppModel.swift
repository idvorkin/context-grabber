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
  /// A gentle shake opens the report too (story 146).
  private(set) lazy var shakeMotion = ShakeMotion { [weak self] peak in
    self?.log.event("shake", ["source": "motion", "peak_g": (peak * 100).rounded() / 100])
    self?.startBugReport(from: "shake")
  }

  /// The screen in front, as a report and the log name it. Each ported journey sets it when it appears.
  @Published var screen = "home"
  @Published var showBugReport = false
  @Published var status = ""
  /// Under Reset audio: what the phone's audio was and is now (story 149).
  @Published private(set) var audioResetLine = ""
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
  /// The page's ☎ and its Grabber links come back here (story 200).
  private(set) lazy var cockpit: CockpitModel = {
    let cockpit = CockpitModel(log: log, override: ProcessInfo.processInfo.environment["GRABBER_COCKPIT_URL"])
    cockpit.onAppRoute = { [weak self] route, source in self?.open(route: route, from: source) }
    return cockpit
  }()
  /// The eulogy song, played in the app (story 137); it outlives its sheet.
  lazy var eulogySong: EulogySongPlayer = {
    let song = EulogySongPlayer(log: log)
    // A live call holds the audio: the song waits for it (#197).
    song.heldBy = { [weak self] in self?.call.snapshot.isActive == true ? "call" : nil }
    return song
  }()
  /// The usage strip on the home screen (story 203). `GRABBER_USAGE_URL` points it at another Cockpit.
  lazy var usage = UsageModel(log: log, override: ProcessInfo.processInfo.environment["GRABBER_USAGE_URL"])
  /// The call screen covers the app. The call itself is `call`'s and outlives the screen.
  @Published var callOpen = false
  let call: CallModel
  /// Today (the mirror) is on screen.
  @Published var showToday = false
  /// The eulogy song's sheet is up.
  @Published var showEulogySong = false
  /// The metric whose week is open over Today.
  @Published var openMetricKey: MetricSheetItem?
  /// What's new, as the build wrote it (story 148); nil when the resource is missing or unreadable.
  let whatsNew = WhatsNewFeed.decode(
    Bundle.main.url(forResource: "whats-new", withExtension: "json").flatMap { try? Data(contentsOf: $0) })
  @Published var showWhatsNew = false
  /// The newest change Igor dismissed What's new at (its ✕); the home row stays away until a newer one arrives.
  @Published private(set) var whatsNewSeen: String?
  static let whatsNewSeenKey = "whats_new_seen"
  var whatsNewOnHome: Bool { WhatsNewFeed.showsOnHome(whatsNew, seen: whatsNewSeen) }
  /// Which launchers the home screen shows, in Igor's order (story 147).
  @Published private(set) var homeLayout: HomeLayout
  @Published var showHomeSettings = false
  /// The mirror: the last grab and the exports. Set at the end of init (it reads the database and the log).
  private(set) var mirror: MirrorModel!

  init() {
    database = AppDatabase(log: log)
    liveActivity = LiveActivityController(log: log)
    tracker = LocationTracker(log: log, store: database.locations)
    places = PlacesModel(log: log, database: database)
    bugReporter = BugReporter(log: log)
    call = CallModel(log: log, database: database, environment: ProcessInfo.processInfo.environment)
    whatsNewSeen = database.setting(Self.whatsNewSeenKey)
    homeLayout = HomeLayout(
      known: HomeRow.ids, storedOrder: database.setting(HomeLayout.orderKey),
      storedHidden: database.setting(HomeLayout.hiddenKey))
    CrashReports.shared.onEvent = { [log] type, fields in log.event(type, fields) }
    CrashReports.shared.reportSignalLogs { type, fields in log.event(type, fields) }
    bugReporter.pruneOldLogs()
    places.prune(reason: "launch")
    liveActivity.endLeftovers()
    LinkLauncher.handler = { [weak self] route in self?.open(route: route, from: "shortcut") }
    mirror = MirrorModel(app: self)
    call.willStart = { [weak self] in self?.eulogySong.yield(to: "call") }
    runLaunchHooks()
  }

  /// The app came to the front (not the launch itself): prune, settle a pending permission, ask for a fix.
  func foreground() {
    usage.resume(reason: "foreground")
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
    guard showPlaces else { return }
    log.event("ui", ["action": "close_places"])
    screen = "home"
    showPlaces = false
    showPlacesMap = false
  }

  /// A `grabbernative://` link (story 135), or a file shared to the app or opened in it from Files: Context
  /// Grabber's database export (story 055).
  func open(url: URL) {
    if url.isFileURL {
      log.event("open_url", ["url": "file:" + url.lastPathComponent, "route": "import", "ok": true, "from": "file"])
      if !showPlaces { openPlaces(from: "file") }
      places.importDatabase(url, from: "file")
      return
    }
    let parsed = AppLink.parse(url)
    log.event(
      "open_url", ["url": url.absoluteString, "route": parsed.route.name, "ok": parsed.understood, "from": "link"])
    go(to: parsed.route, from: "link")
  }

  /// A Shortcuts action, logged as the link it equals.
  func open(route: AppRoute, from source: String) {
    log.event("open_url", ["url": AppLink.link(for: route), "route": route.name, "ok": true, "from": source])
    go(to: route, from: source)
  }

  /// The screen in front, by the route that names it.
  private var front: String {
    if gymTimer != nil { return "timer" }
    if breathe != nil { return "breathe" }
    if showPlaces { return "places" }
    if showCockpit { return "cockpit" }
    if callOpen { return "call" }
    if showToday { return "today" }
    return "home"
  }

  /// Whatever is in front goes, then the route's screen comes up. The screen already in front stays when the link
  /// starts nothing; the call screen stays either way (a live call is brought forward, not restarted).
  private func go(to route: AppRoute, from source: String) {
    if front == route.name {
      if case .call = route { return present(route, from: source) }
      if !route.starts { return }
    }
    if case .card = route { return present(route, from: source) }  // another app: nothing here needs to move
    guard closeAll() else { return present(route, from: source) }
    Task {
      // SwiftUI drops a cover asked for while another is still going down.
      try? await Task.sleep(for: .milliseconds(700))
      present(route, from: source)
    }
  }

  /// Takes down every screen over home; true when one was up.
  private func closeAll() -> Bool {
    var covered = false
    if gymTimer != nil { closeGymTimer(); covered = true }
    if breathe != nil { closeBreathe(); covered = true }
    if showPlaces { closePlaces(); covered = true }
    if showCockpit { closeCockpit(); covered = true }
    if callOpen { closeCall(); covered = true }
    if showToday {
      openMetricKey = nil
      showToday = false
      covered = true
    }
    return covered
  }

  private func present(_ route: AppRoute, from source: String) {
    switch route {
    case .home: break
    case .today: openToday(from: source)
    case .timer(let t):
      openGymTimer(GymTimerLaunch(preset: t.preset, custom: t.custom, autostart: t.start), from: source)
    case .breathe(let b):
      openBreathe(BreatheLaunch(breath: b.breath, minutes: b.minutes, start: b.start), from: source)
    case .places: openPlaces(from: source)
    case .cockpit: openCockpit(from: source)
    case .call(let via): callFromLink(via, from: source)
    case .card: openThinkACard(from: source)
    }
  }

  func openHomeSettings() {
    log.event("ui", ["action": "home_settings"])
    screen = "home_settings"
    showHomeSettings = true
  }

  func closeHomeSettings() {
    screen = "home"
    showHomeSettings = false
  }

  func setHomeRow(_ id: String, shown: Bool) {
    homeLayout.setShown(id, shown)
    saveHomeLayout(change: shown ? "show" : "hide")
  }

  func moveHomeRows(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    homeLayout.move(fromOffsets: offsets, toOffset: destination)
    saveHomeLayout(change: "move")
  }

  func resetHomeRows() {
    homeLayout = HomeLayout(known: HomeRow.ids, storedOrder: nil, storedHidden: nil)
    saveHomeLayout(change: "reset")
  }

  /// The whole layout after every change, so a log says what the home screen looked like.
  private func saveHomeLayout(change: String) {
    database.setSetting(HomeLayout.orderKey, homeLayout.encodedOrder)
    database.setSetting(HomeLayout.hiddenKey, homeLayout.encodedHidden)
    log.event(
      "ui",
      ["action": "home_rows", "change": change, "order": homeLayout.encodedOrder, "hidden": homeLayout.encodedHidden])
  }

  /// A shake or the button: the picture is taken before the sheet covers the screen.
  /// Opens the report over whatever is in front (#182): a sheet attached to the screen underneath could not open
  /// while that screen already had one up, and stayed "up" so every later shake was swallowed too.
  func startBugReport(from source: String) {
    guard !showBugReport else { return }
    bugReporter.capture()
    let over = BugReportPresenter.present(
      BugReportSheet(model: self), onGone: { [weak self] in self?.showBugReport = false },
      another: { [weak self] in self?.startBugReport(from: "another") })
    log.event("ui", ["action": "report_problem", "from": source, "screen": screen, "over": over ?? "nothing"])
    showBugReport = over != nil
  }

  func bugContext() -> [String: String] {
    ["screen": screen, "build": "\(BuildInfo.sha) \(BuildInfo.branch)", "log": log.url.lastPathComponent]
  }

  func reportBug(note: String) {
    status = bugReporter.report(note: note, context: bugContext())
  }

  func openGymTimer(_ launch: GymTimerLaunch = GymTimerLaunch(), from source: String) {
    log.event(
      "ui", ["action": "open_timer", "from": source, "autostart": launch.autostart, "dial": (launch.dial ?? .shipped).rawValue])
    screen = "gym_timer"
    gymTimer = launch
  }

  func closeGymTimer() {
    guard gymTimer != nil else { return }  // a link closed it already; this is the cover's binding catching up
    log.event("ui", ["action": "close_timer"])
    screen = "home"
    gymTimer = nil
  }

  func openBreathe(_ launch: BreatheLaunch = BreatheLaunch(), from source: String) {
    log.event("ui", ["action": "open_breathe", "from": source, "autostart": launch.begins])
    screen = "breathe"
    breathe = launch
  }

  func closeBreathe() {
    guard breathe != nil else { return }
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

  /// Exercise Analyzer, Igor's own app (its story 069): the link only brings it forward.
  func openExerciseAnalyzer(from source: String) {
    guard let url = URL(string: "exerciseanalyzer://") else { return }
    UIApplication.shared.open(url) { [log] ok in
      log.event("ui", ["action": "open_exercise_analyzer", "from": source, "ok": ok])
      if !ok { Task { @MainActor in self.status = "Exercise Analyzer is not installed, so it cannot open." } }
    }
  }

  /// Story 137: a page of Igor's blog, in the browser.
  func openBlog(_ url: URL, action: String, from source: String) {
    UIApplication.shared.open(url) { [log] ok in log.event("ui", ["action": action, "from": source, "ok": ok]) }
  }

  /// Story 137: the eulogy song, played in the app; the sheet shows where it is. Resumes rather than restarts.
  func playEulogySong(from source: String) {
    log.event("ui", ["action": "open_eulogy_song_player", "from": source])
    screen = "eulogy_song"
    showEulogySong = true
    eulogySong.play(from: source)
  }

  /// #195: the small player's tap brings the sheet back as the song is, playing or paused.
  func showEulogySongSheet(from source: String) {
    log.event("ui", ["action": "open_eulogy_song_sheet", "from": source])
    screen = "eulogy_song"
    showEulogySong = true
  }

  static let eulogySongKey = "eulogy_song_url"

  /// Story 137: the song the eulogy post embeds today, on Suno; the last one found when the blog cannot be reached,
  /// and the post itself when no song was ever found.
  func openEulogySong(from source: String) {
    Task {
      var song: URL?
      var found = "post"
      var failure = ""
      do {
        var request = URLRequest(url: BlogLinks.eulogy, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        song = BlogLinks.song(inPost: String(decoding: data, as: UTF8.self))
        if song == nil { failure = "no Suno song in the post" }
      } catch {
        failure = String(describing: error)
      }
      if let song {
        database.setSetting(Self.eulogySongKey, song.absoluteString)
      } else if let last = database.setting(Self.eulogySongKey).flatMap(URL.init(string:)) {
        song = last
        found = "last_time"
      } else {
        found = "none"
      }
      let target = song ?? BlogLinks.eulogy
      log.event(
        "ui", ["action": "open_eulogy_song", "from": source, "song": target.absoluteString, "found": found, "error": failure])
      if song == nil { status = "Couldn't find the eulogy song, so here is the post." }
      await UIApplication.shared.open(target)
    }
  }

  /// Story 149: lets go of the audio this app holds. Not while a call is live; ending the call is the reset then.
  func resetAudio() {
    guard !call.snapshot.isActive else { return }
    audioResetLine = "Resetting…"
    DispatchQueue.global(qos: .userInitiated).async { [log] in
      let before = AudioReset.state()
      let failed = AudioReset.reset()
      let after = AudioReset.state()
      log.event(
        "audio_reset",
        [
          "before": before.line, "before_category": before.category, "after": after.line,
          "after_category": after.category, "ok": failed.isEmpty, "failed": failed,
        ])
      Task { @MainActor in
        self.audioResetLine =
          failed.isEmpty
          ? "Was \(before.line). Now \(after.line). Still wrong? Restart the phone."
          : "iOS refused \(failed.keys.sorted().joined(separator: ", ")). Now \(after.line). Restarting the phone resets it fully."
      }
    }
  }

  func openCockpit(from source: String) {
    log.event("ui", ["action": "open_cockpit", "from": source, "first": !cockpitOpened])
    cockpitOpened = true
    screen = "cockpit"
    showCockpit = true
  }

  func closeCockpit() {
    guard showCockpit else { return }
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
    guard callOpen else { return }
    log.event("ui", ["action": "close_call", "state": call.snapshot.state.rawValue])
    screen = "home"
    callOpen = false
  }

  /// A call link or the "Call Larry" Shortcut: the call screen, and a call unless one is already up (it is brought
  /// forward).
  private func callFromLink(_ backend: CallBackend?, from source: String) {
    if !callOpen { openCall(from: source) }
    guard !call.snapshot.isActive else { return }
    if let backend { call.backend = backend }
    call.start(from: source)
  }

  func openWhatsNew(from source: String) {
    logWhatsNewOpened(from: source)
    screen = "whats_new"
    showWhatsNew = true
  }

  func logWhatsNewOpened(from source: String) {
    let days = whatsNew?.days ?? []
    log.event(
      "ui",
      [
        "action": "open_whats_new", "from": source, "days": days.count,
        "changes": days.reduce(0) { $0 + $1.items.count }, "newest": days.first?.day ?? "",
      ])
  }

  /// The home row's ✕: the newest change is dismissed and the row goes until a newer build brings another.
  func dismissWhatsNew() {
    guard let newest = whatsNew?.newest else { return }
    log.event("ui", ["action": "dismiss_whats_new", "newest": newest])
    whatsNewSeen = newest
    database.setSetting(Self.whatsNewSeenKey, newest)
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
    // Story 184: which Custom control the timer draws upright; alone, it opens the timer on CUSTOM, not started.
    let dial = env["GRABBER_TIMER_DIAL"].flatMap(DialStyle.init(rawValue:))
    if let spec = env["GRABBER_TIMER"], !spec.isEmpty {
      // A chip's id starts it as a tap on a widget tile would; "work,rest,rounds" runs that shape as Custom.
      var launch = GymTimerLaunch(
        autostart: true, turn: env["GRABBER_TURN"].flatMap(DeviceTurn.init(rawValue:)), voice: voice, dial: dial)
      let numbers = spec.split(separator: ",").compactMap { Int($0) }
      if numbers.count == 3 {
        launch.custom = CustomPreset(work: numbers[0], rest: numbers[1], rounds: numbers[2])
      } else {
        launch.preset = spec
      }
      openGymTimer(launch, from: "hook")
    } else if env["GRABBER_TIMER_SETTINGS"] == "1" {
      openGymTimer(GymTimerLaunch(voice: voice, settings: true, dial: dial), from: "hook")
    } else if let dial {
      openGymTimer(GymTimerLaunch(preset: CustomPreset.id, voice: voice, dial: dial), from: "hook")
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
      // "open" opens the screen; "map" also opens the map full screen; "map,unnamed" then opens the card of the
      // longest unnamed place once the trail is read, and "map,unnamed,name" its naming card (story 056).
      let parts = spec.split(separator: ",").map(String.init)
      openPlaces(from: "hook")
      if parts.first == "map" { showPlacesMap = true }
      // "open,edit:<name>" opens that known place's screen, for a screenshot of its icon picker (story 057).
      if let edit = parts.first(where: { $0.hasPrefix("edit:") }) {
        let name = String(edit.dropFirst(5))
        if let place = places.knownPlaces.first(where: { $0.name == name }) { places.edit(place, from: "hook") }
      }
      if parts.dropFirst().contains("unnamed") {
        Task {
          for _ in 0..<100 where places.loading || places.unnamed.isEmpty {
            try? await Task.sleep(for: .milliseconds(200))
          }
          guard let place = places.unnamed.first else { return }
          places.selectUnnamed(place.placeId, from: "hook")
          if parts.contains("name") { places.startNaming(place) }
        }
      }
    }
    if env["GRABBER_EXPORT"] == "1" {
      // Prepares the file as Export database does, without the share sheet a script cannot dismiss.
      places.prepareExport(from: "hook")
      places.exportFile = nil
    }
    if env["GRABBER_COCKPIT"] == "open" { openCockpit(from: "hook") }
    if env["GRABBER_WHATS_NEW"] == "open" { openWhatsNew(from: "hook") }
    if env["GRABBER_HOME"] == "settings" { openHomeSettings() }
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
    if let link = env["GRABBER_LINK"], let url = URL(string: link) {
      // As if iOS had opened the link: simctl openurl stops at a confirmation a script cannot tap.
      open(url: url)
    }
    // A shake after this many seconds, over whatever is up by then (#182: the cog's sheet, with GRABBER_HOME).
    if let seconds = Double(env["GRABBER_SHAKE_AFTER"] ?? "") {
      Task {
        try? await Task.sleep(for: .seconds(seconds))
        startBugReport(from: "hook")
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
