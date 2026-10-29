//  What the whole app shares: the session log, the bug reporter, and which screen is in front (a report names it).

import BugKit
import Combine
import ContextCore
import CoreLocation
import SwiftUI
import ThinkACardCore
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
  let log = SessionLog()
  let database: AppDatabase
  /// The lock-screen card and the Dynamic Island, shared by the Gym Timer and Box breathing.
  let liveActivity: LiveActivityController
  /// The trail: recording runs whatever screen is in front, and iOS may launch the app just to deliver points.
  let tracker: LocationTracker
  let places: PlacesModel
  /// What was shared to the app, on its way to Larry (#305, stories 038 and 039).
  let inbox: InboxModel
  /// Chat with Larry on the Cockpit's threads (spec 2026-10-25); what Igor writes goes out through `inbox`.
  let chat: ChatModel
  private let chatNotifications = ChatNotificationDelegate()
  /// Everything the app collects, to the Cockpit's archive every few hours (story 270).
  let archive: ArchiveModel
  /// Shake (hard or gentle), ⌘I or the Settings button opens BugKit's report dialog (stories 142, 146). Set at the
  /// end of init: its hooks read this model.
  // swiftlint:disable:next implicitly_unwrapped_optional
  private(set) var reporter: BugReporter!
  private var reporterStatus: AnyCancellable?
  /// #107: the tracker's fixes, passed to a live call.
  private var callLocationWatch: AnyCancellable?

  /// The screen in front, as a report and the log name it. Each ported journey sets it when it appears.
  @Published var screen = "home"
  @Published var status = "" { didSet { homeProblem = nil } }
  /// A home tile's failure that has to be copyable (Codex on #386): shown under the tiles in place of `status`,
  /// until a newer `status` replaces it.
  @Published var homeProblem: BugProblem?
  /// Under Reset audio: what the phone's audio was and is now (story 149).
  @Published private(set) var audioResetLine = ""
  /// Non-nil while the Gym Timer covers the app; says how it was asked for.
  @Published var gymTimer: GymTimerLaunch?
  /// Non-nil while the breathing screen covers the app.
  @Published var breathe: BreatheLaunch?
  /// Non-nil while the card screen covers the app (story 129): true when it opened counting.
  @Published var card: Bool?
  /// `GRABBER_DRILL`: the card screen opens the drill in this mode on its next appearance, then forgets it.
  var drillOnOpen: StackDrill.Mode?
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
  /// Speaking a message in Chat (#448): BugKit's Apple dictation behind the thread's mic, standing down for a call.
  let chatVoice: ChatVoiceModel
  /// Today (the mirror) is on screen.
  @Published var showToday = false
  @Published var showInbox = false
  /// The eulogy song's sheet is up.
  @Published var showEulogySong = false
  /// The metric whose week is open over Today.
  @Published var openMetricKey: MetricSheetItem?
  /// What's new, as the build wrote it with BugKit's script (story 148); nil when the resource is missing or unreadable.
  let whatsNew = WhatsNewSeen.bundledFeed()
  /// This phone's own reports, read once per launch: What's new shows the ones this build fixed (BugKit 0.3.11).
  private(set) lazy var bugReports: [BugReport] = (try? BugStore().readAll().reports) ?? []
  @Published var showWhatsNew = false
  /// Where the list was opened from, for BugKit's `open_whats_new` line.
  private(set) var whatsNewFrom = "home"
  /// The home row shows until its ✕ (BugKit keeps that in UserDefaults; the row hides itself on the tap).
  var whatsNewOnHome: Bool { WhatsNewSeen().showsRow(whatsNew) }
  /// Which launchers the home screen shows, in Igor's order (story 147).
  @Published private(set) var homeLayout: HomeLayout
  @Published var showHomeSettings = false
  /// The mirror: the last grab and the exports. Set at the end of init (it reads the database and the log).
  // swiftlint:disable:next implicitly_unwrapped_optional
  private(set) var mirror: MirrorModel!
  /// The daily strip (#236): made with the mirror, whose last grab says which days had a strength workout.
  // swiftlint:disable:next implicitly_unwrapped_optional
  private(set) var dailyStrip: DailyStripModel!

  init() {
    // BugKit's crash capture first (story 144), so a crash anywhere in the launch comes back: MetricKit, signal and
    // exception files under Documents/crashes, each announced once in this log.
    CrashReports.shared.install(logger: log.bugLogger)
    database = AppDatabase(log: log)
    liveActivity = LiveActivityController(log: log)
    tracker = LocationTracker(log: log, store: database.locations)
    places = PlacesModel(log: log, database: database)
    // GRABBER_CHAT_URL: the simulator's stand-in Cockpit (scripts/native/fake-cockpit.py), so nothing reaches Larry.
    let chatCockpit = ProcessInfo.processInfo.environment["GRABBER_CHAT_URL"].flatMap { $0.isEmpty ? nil : $0 }
    inbox = InboxModel(log: log, database: database, cockpit: chatCockpit ?? CockpitPage.url)
    chat = ChatModel(inbox: inbox, log: log, database: database, cockpit: chatCockpit ?? CockpitPage.url)
    chat.registerBackgroundTask()  // before the launch finishes, or iOS refuses the handler
    archive = ArchiveModel(log: log, database: database, environment: ProcessInfo.processInfo.environment)
    archive.registerBackgroundTasks()  // before the launch finishes, or iOS refuses the handlers
    call = CallModel(log: log, database: database, environment: ProcessInfo.processInfo.environment)
    chatVoice = ChatVoiceModel(log: log, callLive: call.$snapshot.map(\.isActive).eraseToAnyPublisher())
    // Before BugKit the ✕ was kept in the database: carry it over once, so a dismissed row stays dismissed.
    if let seen = database.setting("whats_new_seen"),
      UserDefaults.standard.string(forKey: WhatsNewSeen.defaultKey) == nil
    {
      UserDefaults.standard.set(seen, forKey: WhatsNewSeen.defaultKey)
    }
    homeLayout = HomeLayout(
      known: HomeRow.ids, storedOrder: database.setting(HomeLayout.orderKey),
      storedHidden: database.setting(HomeLayout.hiddenKey))
    // BugKit's: logs older than 30 days go, except any a report names (story 145).
    BugStore().pruneLogs(logger: bugLogger)
    places.prune(reason: "launch")
    liveActivity.endLeftovers()
    LinkLauncher.handler = { [weak self] route in self?.open(route: route, from: "shortcut") }
    // Chat: a reply's notification opens its thread (set before the launch finishes, for a tap that launches us).
    chatNotifications.open = { [weak self] thread in self?.open(route: .chat(thread: thread), from: "notification") }
    chatNotifications.onScreen = { [weak self] in self?.chat.openThread }
    UNUserNotificationCenter.current().delegate = chatNotifications
    inbox.didSend = { [weak self] in Task { await self?.chat.refreshList(reason: "sent") } }
    mirror = MirrorModel(app: self)
    reporter = makeReporter()
    startDelivery()
    dailyStrip = DailyStripModel(log: log, database: database) { [weak self] in self?.mirror.snapshot }
    call.willStart = { [weak self] in
      self?.eulogySong.yield(to: "call")
      // Before the call configures the session: chat dictation's restore must land first, or the call's mic is dead.
      self?.chatVoice.yieldToCall()
      self?.locateForCall()
    }
    // Story 217: a Direct call starts knowing the day so far: the last grab and the strip as the home screen shows it.
    call.today = { [weak self] in
      guard let self else { return nil }
      self.dailyStrip.refresh()
      var strip: [DailyItem: Int] = [:]
      for item in DailyItem.allCases { strip[item] = self.dailyStrip.value(item) }
      if self.dailyStrip.gymToday { strip[.gym] = max(strip[.gym] ?? 0, 1) }
      if self.dailyStrip.meditationToday { strip[.meditation] = max(strip[.meditation] ?? 0, 1) }
      return CallToday.build(
        snapshot: self.mirror.snapshot, strip: strip, now: jsMillis(Date()), clock: LocalClock())
    }
    // #107: a move during a call goes up too; CallModel sends only the significant ones.
    callLocationWatch = tracker.$you.compactMap { $0 }.sink { [weak self] fix in
      guard let self, self.call.snapshot.isActive else { return }
      self.call.offerLocation(fix, knownPlaces: self.knownPlacesForCall())
    }
    // Story 248: a troubled call's log as an automatic report, for the Mac's listener to file.
    call.autoReport = { [weak self] reason, context, files in
      self?.reporter.autoReport(reason: reason, context: context, files: files)
    }
    runLaunchHooks()
    inbox.refresh(reason: "launch")  // after the hooks, so a fixture is there to read
  }

  /// The app came to the front (not the launch itself): prune, settle a pending permission, ask for a fix.
  func foreground() {
    usage.resume(reason: "foreground")
    dailyStrip.refresh()
    places.prune(reason: "foreground")
    tracker.foreground()
    if showPlaces { places.reload(reason: "foreground") }
    mirror.refresh(reason: "foreground")  // #355: the Today card current, in the background
    startDelivery()  // story 152: what waited for a connection goes up now
    inbox.refresh(reason: "foreground")  // #305: what was shared while the app was away, then on to Larry
    Task { await chat.refreshList(reason: "foreground") }  // the tile's unread count, and nothing notified twice
    chat.scheduleBackgroundCheck()
    archive.runIfDue(reason: "foreground")  // story 270: the delta, once four hours have passed
  }

  /// Chat's list, or with `thread` that thread on top of it (a notification's tap).
  func openInbox(from source: String, thread: String? = nil) {
    log.event("ui", ["action": "open_chat", "from": source, "waiting": inbox.waitingCount, "thread": thread ?? ""])
    screen = "chat"
    inbox.reload()
    chat.linkThread = thread
    showInbox = true
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
    if card != nil { return "card" }
    if showPlaces { return "places" }
    if showCockpit { return "cockpit" }
    if callOpen { return "call" }
    if showToday { return "today" }
    if showInbox { return "chat" }
    return "home"
  }

  /// Whatever is in front goes, then the route's screen comes up. The screen already in front stays when the link
  /// starts nothing; the call screen stays either way (a live call is brought forward, not restarted).
  private func go(to route: AppRoute, from source: String) {
    if front == route.name {
      if case .call = route { return present(route, from: source) }
      if !route.starts { return }
    }
    if case .supermix = route { return present(route, from: source) }  // another app: nothing here needs to move
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
    if card != nil { closeCard(); covered = true }
    if showPlaces { closePlaces(); covered = true }
    if showCockpit { closeCockpit(); covered = true }
    if callOpen { closeCall(); covered = true }
    if showToday {
      openMetricKey = nil
      showToday = false
      covered = true
    }
    if showInbox {
      showInbox = false
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
    case .card(let think): openCard(think: think, from: source)
    case .supermix: openWorkoutSupermix(from: source)
    case .chat(let thread): openInbox(from: source, thread: thread)
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

  /// BugKit's events into this launch's log.
  var bugLogger: BugLogger { log.bugLogger }

  /// Story 152: every report saved from this build on also goes up to Igor's private iCloud, where the Mac's listener
  /// takes it. On, with no switch; one for the app's lifetime, started at launch and again on each foreground.
  private lazy var delivery = CloudKitReportDelivery(
    containerIdentifier: "iCloud.com.idvorkin.BugKitReports", logger: bugLogger)

  /// Reports waiting for iCloud go up (story 152).
  private func startDelivery() {
    Task { [delivery] in await delivery.start() }
  }

  /// The report dialog, BugKit's (bug-kit migration, step 1). "Log it and another" takes a fresh picture of the
  /// screen underneath (story 142); dictation is off while a call holds the microphone (#239); the simulator hooks
  /// keep their names (`GRABBER_BUG`, `GRABBER_SHAKE_AFTER`).
  private func makeReporter() -> BugReporter {
    var options = BugReporterOptions()
    options.another = .recapture
    options.dictation = true
    options.gentleShake = true
    options.launchHookPrefix = "GRABBER"
    options.placeholder = "e.g. the timer skipped the rest"
    let log = log
    let reporter = BugReporter(
      hooks: BugReporterHooks(
        screen: { [unowned self] in self.screen },
        context: { ["branch": .string(BuildInfo.branch)] },
        sessionLog: { ("logs/" + log.url.lastPathComponent, Int(Date().timeIntervalSince(log.startedAt) * 1000)) },
        logger: bugLogger,
        microphoneBusy: { [unowned self] in self.call.snapshot.isActive },
        flushLog: { log.flush() }),
      options: options, delivery: delivery)
    reporterStatus = reporter.$lastStatus.compactMap { $0 }.receive(on: RunLoop.main)
      .sink { [weak self] in self?.status = $0 }
    return reporter
  }

  /// #107: the call starts with where Igor is. Only with permission already given: a call never prompts for it.
  private func locateForCall() {
    guard [.authorizedWhenInUse, .authorizedAlways].contains(tracker.authorization) else { return }
    if let you = tracker.you, -you.timestamp.timeIntervalSinceNow < 60 {
      call.offerLocation(you, knownPlaces: knownPlacesForCall())
    }
    tracker.requestFix(reason: "call") { [weak self] fix in
      guard let self, let fix, self.call.snapshot.isActive else { return }
      self.call.offerLocation(fix, knownPlaces: self.knownPlacesForCall())
    }
  }

  private func knownPlacesForCall() -> [KnownPlace] { (try? database.locations?.knownPlaces()) ?? [] }

  /// *Report a problem*, from Settings or its home tile (story 252).
  func startBugReport(from source: String) {
    log.event("ui", ["action": "report_problem", "from": source, "screen": screen])
    reporter.open(from: .button)
  }

  func openGymTimer(_ launch: GymTimerLaunch = GymTimerLaunch(), from source: String) {
    log.event(
      "ui",
      [
        "action": "open_timer", "from": source, "autostart": launch.autostart,
        "dial": (launch.dial ?? .shipped).rawValue,
      ])
    screen = "gym_timer"
    gymTimer = launch
  }

  func closeGymTimer() {
    guard gymTimer != nil else { return }  // a link closed it already; this is the cover's binding catching up
    log.event("ui", ["action": "close_timer"])
    dailyStrip.refresh()  // a finished workout makes today a gym day
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
    dailyStrip.refresh()  // a finished session makes today a meditation day (#257)
  }

  /// A journey still in Context Grabber, opened there by its own link.
  func openInContextGrabber(_ link: String, what: String) {
    guard let url = URL(string: link) else { return }
    UIApplication.shared.open(url) { [log] ok in
      log.event("ui", ["action": "open_context_grabber", "what": what, "ok": ok])
      if !ok { Task { @MainActor in self.status = "Context Grabber is not installed, so the \(what) cannot open." } }
    }
  }

  /// #391, stories 222-225: a home tile's press-and-hold popover opened; logged so a hold that chose nothing shows.
  func holdOpened(tile: String) {
    log.event("ui", ["action": "home_popover", "tile": tile])
  }

  /// A choice from a tile's popover, opened exactly as its own link or tile would.
  func open(choice: HoldChoice) {
    let from = "home_popover"
    switch choice.action {
    case .route(let route):
      // The spec's Remembering: a preset chosen here is breathing's choice afterwards, as on its own screen; a link's
      // length stays this session's only. (The timer's open already makes its preset the chosen one.)
      if case .breathe(let link) = route, let seconds = link.breath {
        BreatheModel.remember(preset: seconds, in: database)
        log.event("ui", ["action": "breath_preset", "preset": String(seconds), "from": from])
      }
      open(route: route, from: from)
    case .supermix(let mix): openWorkoutSupermix(from: from, mix: mix)
    case .drill:
      drillOnOpen = .cardToPosition
      openCard(think: false, from: from)
    }
  }

  /// The card screen (story 129), face up or with "think of a card" already counting.
  func openCard(think: Bool, from source: String) {
    log.event("ui", ["action": "open_card", "from": source, "think": think])
    screen = "card"
    card = think
  }

  /// Asked by the card screen at an ask and again at its reveal (#219): a live call keeps the audio, so the card is
  /// shown silently; the eulogy song pauses for it.
  func mayTheCardSpeak() -> Bool {
    if call.snapshot.isActive { return false }
    eulogySong.yield(to: "card")
    return true
  }

  func closeCard() {
    guard card != nil else { return }
    log.event("ui", ["action": "close_card"])
    CardStore.reloadWidget()  // once on leaving, not per deal: iOS rations widget reloads
    screen = "home"
    card = nil
  }

  /// Igor's Workout Supermix (#220, #372): the mix's link, straight in YouTube Music.
  /// `mix`: the tile's tap opens the workout one; its press-and-hold menu any of them (#383).
  func openWorkoutSupermix(from source: String, mix: WorkoutSupermix.Mix = .workout) {
    // #372: straight in YouTube Music, no Shortcuts hop; the browser when the app is missing.
    let link = mix.link
    homeProblem = nil  // a new try clears the last one's failure
    UIApplication.shared.open(link, options: [.universalLinksOnly: true]) { [log] inApp in
      guard !inApp else {
        log.event(
          "ui", ["action": "open_workout_supermix", "from": source, "mix": mix.rawValue, "ok": true, "how": "app"])
        return
      }
      UIApplication.shared.open(link) { ok in
        log.event(
          "ui", ["action": "open_workout_supermix", "from": source, "mix": mix.rawValue, "ok": ok, "how": "browser"])
        guard !ok else { return }
        Task { @MainActor in
          self.homeProblem = .grabber(
            "The \(mix.title) would not open.", context: "Home.open_workout_supermix",
            extra: ["mix": .string(mix.rawValue), "link": .string(link.absoluteString), "from": .string(source)])
        }
      }
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

  /// Story 242: a breathing session saved to Health as a Mindful Session. A refusal is logged, never shown: breathing
  /// works the same without it.
  func saveMindful(_ span: TimeSpan, why: String) {
    guard HealthKitSource.isAvailable else {
      return log.event("mindful_saved", ["ok": false, "why": why, "message": "Health is not available on this device"])
    }
    Task {
      let fields: [String: Any] = ["why": why, "seconds": Int((span.end - span.start) / 1000)]
      do {
        try await healthWriter.saveMindful(span)
        log.event("mindful_saved", fields.merging(["ok": true]) { $1 })
      } catch {
        log.event("mindful_saved", fields.merging(["ok": false, "message": error.localizedDescription]) { $1 })
      }
    }
  }

  private lazy var healthWriter = HealthKitSource()

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
        "ui",
        ["action": "open_eulogy_song", "from": source, "song": target.absoluteString, "found": found, "error": failure])
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

  /// Opens the list; BugKit's view logs `open_whats_new` as it appears.
  func openWhatsNew(from source: String) {
    whatsNewFrom = source
    screen = "whats_new"
    showWhatsNew = true
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
      // "<file>[,recent]": a path, absolute or under Documents; "recent" shifts it by whole days into the last 24 hours.
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
    if let mode = env["GRABBER_DRILL"].flatMap(StackDrill.Mode.init) {
      // Story 220: the card screen with *Drill the stack* already tapped, in that direction.
      drillOnOpen = mode
      openCard(think: false, from: "hook")
    }
    if env["GRABBER_COCKPIT"] == "open" { openCockpit(from: "hook") }
    if env["GRABBER_WHATS_NEW"] == "open" { openWhatsNew(from: "hook") }
    if env["GRABBER_HOME"] == "settings" { openHomeSettings() }
    if let mix = env["GRABBER_SUPERMIX"].flatMap(WorkoutSupermix.Mix.init(rawValue:)) {
      openWorkoutSupermix(from: "hook", mix: mix)
    }
    // #305: three Inbox items as the share extension writes them (never sent), and the Inbox opened.
    if env["GRABBER_INBOX_FIXTURE"] == "1" { inbox.addFixture() }
    if env["GRABBER_INBOX"] == "open" { openInbox(from: "hook") }
    if let send = env["GRABBER_CHAT_SEND"], !send.isEmpty {
      // Chat: "<thread>|<text>" written in that thread as the compose bar would ("new|<text>" starts one).
      let parts = send.split(separator: "|", maxSplits: 1).map(String.init)
      var draft = InboxDraft()
      draft.text = parts.count > 1 ? parts[1] : ""
      do {
        try chat.send(&draft, thread: parts[0] == "new" ? nil : parts[0])
      } catch {
        log.event("error", ["where": "chat_hook", "message": "\(error)"])
      }
    }
    if env["GRABBER_CHAT_NEW"] == "open" {
      // #536: Chat with its + already tapped, a new thread on screen.
      openInbox(from: "hook")
      chat.openNewChat(from: "hook")
    }
    // Story 270: an archive run now, to GRABBER_ARCHIVE_URL (the simulator sends nowhere else).
    if env["GRABBER_ARCHIVE"] == "run" { archive.run(reason: "hook") }
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
    // GRABBER_SHAKE_AFTER (a shake after that many seconds, over whatever is up: #182) and GRABBER_BUG ("a|b",
    // reports saved with no dialog) are BugKit's hooks under this app's prefix.
    reporter.runLaunchHooks(env)
  }
}

struct MetricSheetItem: Identifiable, Equatable {
  let key: MetricKey
  var id: String { key.rawValue }
}

extension SessionLog {
  /// BugKit's events into this log: BugKit hands JSON values, the log takes Foundation values.
  var bugLogger: BugLogger { { [self] type, fields in self.event(type, fields.mapValues(\.foundation)) } }
}
