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
  /// Audit finding 4: who has the microphone, one holder or nobody (`MicFloor`, ContextCore, host-tested).
  private var mic = MicFloor()
  private var callMicWatch: AnyCancellable?

  /// #808, #818: every screen up in the home window, and a link waiting to bring one up. Its reducer (ContextCore,
  /// host-tested) is the only writer: each flag below reads it, and AppModel carries out what it returns.
  @Published private(set) var screens = HomeStack.State()
  /// The screen in front, as a report and the log name it: the top of the stack.
  var screen: String { screens.top.reportName }
  @Published var status = "" { didSet { homeProblem = nil } }
  /// A home tile's failure that has to be copyable (Codex on #386): shown under the tiles in place of `status`,
  /// until a newer `status` replaces it.
  @Published var homeProblem: BugProblem?
  /// Under Reset audio: what the phone's audio was and is now (story 149).
  @Published private(set) var audioResetLine = ""
  /// Non-nil while the Gym Timer covers the app; says how it was asked for.
  var gymTimer: GymTimerLaunch? { screens.isUp(.timer) ? gymLaunch : nil }
  @Published private var gymLaunch = GymTimerLaunch()
  private var gymModel: GymTimerModel?
  /// The Gym Timer's state, made on first open and kept for the app's life: a workout outlives its screen (story
  /// 188, #791).
  var gym: GymTimerModel {
    if let gymModel { return gymModel }
    let made = GymTimerModel(log: log, database: database, liveActivity: liveActivity)
    gymModel = made
    return made
  }
  /// Non-nil while the breathing screen covers the app.
  var breathe: BreatheLaunch? { screens.isUp(.breathe) ? breatheLaunch : nil }
  @Published private var breatheLaunch = BreatheLaunch()
  /// Non-nil while the card screen covers the app (story 129): true when it opened counting.
  var card: Bool? { screens.isUp(.card) ? cardThinks : nil }
  @Published private var cardThinks = false
  /// `GRABBER_DRILL`: the card screen opens the drill in this mode on its next appearance, then forgets it.
  var drillOnOpen: StackDrill.Mode?
  var showPlaces: Bool { screens.isUp(.places) }
  @Published var showPlacesMap = false
  /// True while the Cockpit covers the app. The page itself outlives this: see `cockpit`.
  var showCockpit: Bool { screens.isUp(.cockpit) }
  var showWhiteboard: Bool { screens.isUp(.whiteboard) }
  /// The board a link asked for (#603): the boards open it as they come up.
  @Published var whiteboardLink: String?
  /// #722, story 724: the Mac's New Board asked for a board; the boards open one as they come up, or at once if up.
  @Published var whiteboardNewBoard = false

  /// Made on the first open and kept for the launch, so closing the Cockpit hides the page rather than closing it.
  /// `GRABBER_COCKPIT_URL` points it elsewhere (a URL, or a page in the app bundle) for the simulator's checks and a
  /// Mac test launch (#680). The page's ☎ and its Grabber links come back here (story 200).
  private(set) lazy var cockpit: CockpitModel = {
    let cockpit = CockpitModel(log: log, override: LaunchHooks.current.cockpitURL)
    cockpit.onAppRoute = { [weak self] route, source in self?.open(route: route, from: source) }
    return cockpit
  }()
  /// The eulogy song, played in the app (story 137); it outlives its sheet.
  lazy var eulogySong: EulogySongPlayer = {
    let song = EulogySongPlayer(log: log)
    // A live call holds the audio: the song waits for it (#197).
    song.heldBy = { [weak self] in self?.askAudio(.songPlays)?.rawValue }
    return song
  }()
  /// The usage strip on the home screen (story 203). `GRABBER_USAGE_URL` points it at another Cockpit.
  lazy var usage = UsageModel(log: log, override: LaunchHooks.current.usageURL)
  /// The call screen covers the app. The call itself is `call`'s and outlives the screen.
  var callOpen: Bool { screens.isUp(.call) }
  let call: CallModel
  /// Speaking a message in Chat (#448): BugKit's Apple dictation behind the thread's mic, standing down for a call.
  let chatVoice: ChatVoiceModel
  /// Today (the mirror) is on screen.
  var showToday: Bool { screens.isUp(.today) }
  var showInbox: Bool { screens.isUp(.chat) }
  /// The eulogy song's sheet is up.
  var showEulogySong: Bool { screens.isUp(.eulogySong) }
  /// The metric whose week is open over Today; the sheet's binding sets it back to nil as it goes down.
  var openMetricKey: MetricSheetItem? {
    get { screens.metric.map { MetricSheetItem(key: $0) } }
    set {
      if let newValue {
        screens.open(.metric(newValue.key))
      } else if let key = screens.metric {
        close(.metric(key))
      }
    }
  }
  /// What's new, as the build wrote it with BugKit's script (story 148); nil when the resource is missing or unreadable.
  let whatsNew = WhatsNewSeen.bundledFeed()
  /// This phone's own reports, read once per launch: What's new shows the ones this build fixed (BugKit 0.3.11).
  private(set) lazy var bugReports: [BugReport] = (try? BugStore().readAll().reports) ?? []
  var showWhatsNew: Bool { screens.isUp(.whatsNew) }
  /// Where the list was opened from, for BugKit's `open_whats_new` line.
  private(set) var whatsNewFrom = "home"
  /// The home row shows until its ✕ (BugKit keeps that in UserDefaults; the row hides itself on the tap).
  var whatsNewOnHome: Bool { WhatsNewSeen().showsRow(whatsNew) }
  /// #634: which window holds what (AppModel+Windows.swift).
  var ledger = WindowLedger()
  /// #661: any change here can change what a window should be called.
  private var windowNames: AnyCancellable?
  /// #634, #661: a window goes when its scene does; its views also disappear under a full-screen cover.
  private var windowDisconnects: AnyCancellable?
  var openWindowAction: OpenWindowAction?
  var dismissWindowAction: DismissWindowAction?
  /// `GRABBER_WINDOW` and `GRABBER_WINDOW_CHOOSE` run once, when the home window is up.
  var windowHookRan = false
  /// `GRABBER_WINDOW_CHOOSE`: the screen the new window's chooser picks, until it has.
  var windowHookChoice: WindowScreen?
  /// Whether this launch has looked for a home window after a screen's window came back first.
  var restoreChecked = false
  private var phaseLatch = AppPhaseLatch()
  /// The boards on disk and in iCloud: one store for the app's life, made on first use, shared by every window's list,
  /// chat's *Jump to board* and the fixture hook (#819; #634 needed a lookup to go through the store drawing on screen).
  private(set) lazy var whiteboards = WhiteboardStore(log: log, device: whiteboardDevice)
  /// Which launchers the home screen shows, in Igor's order (story 147).
  @Published private(set) var homeLayout: HomeLayout
  var showHomeSettings: Bool { screens.isUp(.homeSettings) }
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
    // Story 041: with an archive to send to, a prune keeps the points it has not taken yet.
    let archiveSends = ArchiveModel.destination(LaunchHooks.environment) != nil
    places = PlacesModel(log: log, database: database, archiveSends: archiveSends)
    // GRABBER_CHAT_URL: the Cockpit to use, such as the stand-in (scripts/native/fake-cockpit.py). A simulator without
    // one reaches none, so a test run's outbox never reaches Larry (#525); a Mac test launch names one (#680).
    let chatCockpit = ChatCockpit.address(override: LaunchHooks.current.chatURL)
    if chatCockpit == ChatCockpit.nowhere {
      log.event("chat", ["action": "no_address", "reason": ChatCockpit.noAddress])
    }
    inbox = InboxModel(log: log, database: database, cockpit: chatCockpit)
    chat = ChatModel(inbox: inbox, log: log, database: database, cockpit: chatCockpit)
    chat.registerBackgroundTask()  // before the launch finishes, or iOS refuses the handler
    archive = ArchiveModel(log: log, database: database, environment: LaunchHooks.environment)
    archive.registerBackgroundTasks()  // before the launch finishes, or iOS refuses the handlers
    call = CallModel(log: log, database: database, environment: LaunchHooks.environment)
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
    chat.findBoard = { [weak self] board, context in await self?.findBoard(board, context: context) }
    chat.openBoard = { [weak self] board in self?.open(route: .whiteboard(board: board), from: "chat") }
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
      // The song pauses (#197), then the call takes the microphone and whoever had it stops (#448). Before the call
      // configures the session: chat dictation's restore must land first, or the call's mic is dead.
      self?.askAudio(.callStarts)
      _ = self?.requestMic(.call)
      self?.locateForCall()
    }
    // A call going live takes the mic too (it may not have come through willStart); an ended one lets it go. No hop to
    // the next run loop: a late stop would restore the session over the call's.
    callMicWatch = call.$snapshot.map(\.isActive).removeDuplicates().dropFirst().sink { [weak self] live in
      MainActor.assumeIsolated {
        if live { _ = self?.requestMic(.call) } else { self?.mic.release(.call) }
      }
    }
    chatVoice.askMic = { [weak self] in self?.requestMic(.chatVoice) }
    chatVoice.micHeldElsewhere = { [weak self] in self?.micHeld(otherThan: .chatVoice) }
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
    windowNames = objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in self?.nameWindows() }
    windowDisconnects = NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)
      .compactMap { ($0.object as? UIScene)?.session.persistentIdentifier }
      .sink { [weak self] window in self?.windowGone(window) }
    runLaunchHooks()
    inbox.refresh(reason: "launch")  // after the hooks, so a fixture is there to read
  }

  /// What every window reports (#634): one change arrives once per window and means one thing.
  func phaseChanged(_ phase: ScenePhase) {
    let reported: AppPhaseLatch.Phase = phase == .active ? .active : phase == .background ? .background : .inactive
    switch phaseLatch.report(reported) {
    case .launch:
      tracker.foreground(); usage.resume(reason: "launch")
      mirror.refresh(reason: "launch")  // #355: the Today card current, in the background
      archive.launch()  // story 270: the next slots asked for, and a run if one is due
      chat.scheduleBackgroundCheck()  // chat: Larry's replies noticed while the app is away
      Task { await chat.refreshList(reason: "launch") }
    case .foreground: foreground()
    case .background: usage.pause()
    case nil: break
    }
  }

  /// The app came to the front (not the launch itself): prune, settle a pending permission, ask for a fix.
  func foreground() {
    usage.resume(reason: "foreground")
    if gymTimer == nil { gymModel?.catchUp() }  // a workout left running off the timer's screen (story 188)
    dailyStrip.refresh()
    places.prune(reason: "foreground")
    tracker.foreground()
    if showPlaces || ledger.window(holding: .places) != nil { places.reload(reason: "foreground") }
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
    if bringForward(.chat, from: source) {
      chat.linkThread = thread
      return
    }
    inbox.reload()
    chat.linkThread = thread
    screens.open(.chat)
  }

  func openPlaces(from source: String) {
    log.event("ui", ["action": "open_places", "from": source])
    if bringForward(.places, from: source) { return }
    screens.open(.places)
    places.reload(reason: "open")
    // Places is where You lives: the first open asks for While Using (the switch asks for Always).
    tracker.requestFix(reason: tracker.authorization == .notDetermined ? "places_open" : "foreground")
  }

  func closePlaces() { close(.places) }

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

  /// For the card screen, which does not import ContextCore: its drill is up or down (a report names the drill).
  func drillShown(_ shown: Bool) {
    if shown { screens.open(.drill) } else { close(.drill) }
  }

  /// `HomeStack.State.open` decides what a link does to the home window; this carries it out.
  private func go(to route: AppRoute, from source: String) {
    let ownWindow = WindowScreen(route: route).map { windowHolding($0) } ?? false
    apply(screens.open(route, from: source, ownWindow: ownWindow))
  }

  /// The effects of a change to `screens`, and nothing else.
  private func apply(_ effects: [HomeStack.Effect]) {
    for effect in effects {
      switch effect {
      case .showHomeWindow: showHomeWindow()
      case .dismissed(let shown): closed(shown)
      case .present(let route, let source): present(route, from: source)
      case .wait(let milliseconds, let id):
        // #818: a newer link replaces the one waiting here, so a settle for a dropped wait presents nothing.
        Task {
          try? await Task.sleep(for: .milliseconds(milliseconds))
          apply(screens.settle(wait: id))
        }
      }
    }
  }

  /// Takes one screen down: its Done, its cover's binding, another window taking it.
  func close(_ shown: HomeStack.Screen) {
    guard screens.close(shown) else { return }  // a link closed it already; this is the binding catching up
    closed(shown)
  }

  /// What a screen's going down does besides; the stack already has it gone.
  private func closed(_ shown: HomeStack.Screen) {
    switch shown {
    case .timer:
      log.event("ui", ["action": "close_timer"])
      dailyStrip.refresh()  // a finished workout makes today a gym day
    case .breathe:
      log.event("ui", ["action": "close_breathe"])
      dailyStrip.refresh()  // a finished session makes today a meditation day (#257)
    case .card:
      log.event("ui", ["action": "close_card"])
      CardStore.reloadWidget()  // once on leaving, not per deal: iOS rations widget reloads
    case .places:
      log.event("ui", ["action": "close_places"])
      showPlacesMap = false
    case .cockpit: log.event("ui", ["action": "close_cockpit"])
    case .whiteboard: log.event("ui", ["action": "close_whiteboard"])
    case .call: log.event("ui", ["action": "close_call", "state": call.snapshot.state.rawValue])
    case .home, .today, .chat, .eulogySong, .whatsNew, .homeSettings, .drill, .metric: break
    }
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
    case .whiteboard(let board):
      whiteboardLink = board
      openWhiteboard(from: source)
    }
  }

  /// Nothing covers home, not even a sheet or a pushed screen: what is presented from it can show.
  var homeInFront: Bool {
    screens.named == .home && !reporter.flow.isPresented
  }

  func openHomeSettings() {
    log.event("ui", ["action": "home_settings"])
    screens.open(.homeSettings)
  }

  func closeHomeSettings() { close(.homeSettings) }

  func setHomeRow(_ id: String, shown: Bool) {
    homeLayout.setShown(id, shown)
    saveHomeLayout(change: shown ? "show" : "hide")
  }

  func moveHomeRows(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    homeLayout.move(fromOffsets: offsets, toOffset: destination)
    saveHomeLayout(change: "move")
  }

  /// #742: the Mac's pointer drag, one row dropped on another.
  func dropHomeRow(_ moving: String, onto target: String) -> Bool {
    guard homeLayout.drop(moving, onto: target) else { return false }
    saveHomeLayout(change: "move")
    return true
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
        screen: { [unowned self] in self.reportScreen },
        context: { ["branch": .string(BuildInfo.branch)] },
        sessionLog: { ("logs/" + log.url.lastPathComponent, Int(Date().timeIntervalSince(log.startedAt) * 1000)) },
        logger: bugLogger,
        // #239, #559: the microphone's floor; a call or a chat recording has it, so the dialog's mic stands down.
        microphoneBusy: { [unowned self] in self.requestMic(.reportDictation) != nil },
        flushLog: { log.flush() }),
      options: options, delivery: delivery)
    reporterStatus = reporter.$lastStatus.compactMap { $0 }.receive(on: RunLoop.main)
      .sink { [weak self] in self?.status = $0 }
    return reporter
  }

  /// #802: every "who gives way to whom" over the audio session is one row of `AudioFloor.rules` (ContextCore,
  /// host-tested), asked here and carried out in the table's order. Returns the holder that refuses the asker, nil
  /// when it may go ahead.
  @discardableResult
  private func askAudio(_ ask: AudioAsk) -> AudioUser? {
    for decision in AudioFloor.decide(ask, isHolding: { self.holdsAudio($0) }) {
      switch decision {
      case .refuse(let holder): return holder
      case .yield(let holder, let other):
        // Each of these returns at once when it is not sounding.
        switch holder {
        case .timer: gymModel?.yield(to: other)
        case .song: eulogySong.yield(to: other)
        // The recorders give way through the microphone's floor (`requestMic`), not here.
        case .call, .breathe, .card, .chatVoice, .reportDictation, .whiteboardMic, .cockpit: break
        }
      }
    }
    return nil
  }

  /// Whether a holder that refuses others (`AudioFloor.refusers`) has the session now.
  private func holdsAudio(_ user: AudioUser) -> Bool {
    switch user {
    case .call: return call.snapshot.isActive
    case .timer, .breathe, .song, .card, .chatVoice, .reportDictation, .whiteboardMic, .cockpit: return false
    }
  }

  /// Audit finding 4 (spec 2026-11-10-microphone-floor-design.md): `user` wants the microphone. Nil when it may
  /// record; otherwise who has it. A call takes it from anyone, and the one it took from stops here.
  private func requestMic(_ user: AudioUser) -> AudioUser? {
    switch mic.request(user, stillHolding: { self.isRecording($0) }) {
    case .refused(let holder):
      log.event("mic_floor", ["action": "refused", "asker": user.rawValue, "holder": holder.rawValue])
      return holder
    case .granted(let took):
      if let took { log.event("mic_floor", ["action": "taken", "by": user.rawValue, "from": took.rawValue]) }
      if user == .call {
        // Chat's dictation yields to any call, as before the floor: it ignores this when idle, and a listing of the
        // microphones (which holds no floor) gives way too.
        chatVoice.yieldToCall()
        if took == .reportDictation { reporter.dictation.stop(why: "call_started") }
      }
      return nil
    }
  }

  /// Who other than `user` has the microphone now, without asking for it.
  private func micHeld(otherThan user: AudioUser) -> AudioUser? {
    mic.heldByAnother(than: user) { self.isRecording($0) }
  }

  /// Whether a holder on record is still recording: one that stopped without saying so holds nothing.
  private func isRecording(_ user: AudioUser) -> Bool {
    switch user {
    case .call: return call.snapshot.isActive
    case .chatVoice: return chatVoice.recording
    case .reportDictation: return reporter.dictation.busy
    // ponytail: the board's screen neither asks the floor nor says its mic is on (WhiteboardView, rewritten by #821),
    // so the floor never records it as a holder. Wiring it: tapMic asks `requestMic(.whiteboardMic)`, its dictation's
    // hostMicrophoneBusy asks `micHeld(otherThan: .whiteboardMic)`, and this answers its `micOn || micStarting`.
    case .whiteboardMic: return false
    case .timer, .breathe, .song, .card, .cockpit: return false
    }
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
    gymLaunch = launch
    screens.open(.timer)
  }

  func closeGymTimer() { close(.timer) }

  func openBreathe(_ launch: BreatheLaunch = BreatheLaunch(), from source: String) {
    log.event("ui", ["action": "open_breathe", "from": source, "autostart": launch.begins])
    askAudio(.breatheOpens)
    breatheLaunch = launch
    screens.open(.breathe)
  }

  func closeBreathe() { close(.breathe) }

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
    case .randomPost(let topic):
      openBlog(topic.link, action: "open_random", from: from, topic: topic.rawValue)
    case .window(let screen): openInNewWindow(screen, from: from)
    }
  }

  /// The card screen (story 129), face up or with "think of a card" already counting.
  func openCard(think: Bool, from source: String) {
    log.event("ui", ["action": "open_card", "from": source, "think": think])
    if bringForward(.card, from: source) {
      drillOnOpen = nil
      return
    }
    cardThinks = think
    screens.open(.card)
  }

  /// Asked by the card screen at an ask and again at its reveal (#219): a live call keeps the audio, so the card is
  /// shown silently; the eulogy song pauses for it.
  func mayTheCardSpeak() -> Bool {
    askAudio(.cardSpeaks) == nil
  }

  func closeCard() { close(.card) }

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
  func openBlog(_ url: URL, action: String, from source: String, topic: String? = nil) {
    UIApplication.shared.open(url) { [log] ok in
      var fields: [String: Any] = ["action": action, "from": source, "ok": ok]
      if let topic { fields["topic"] = topic }
      log.event("ui", fields)
    }
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
    askAudio(.songOpens)
    screens.open(.eulogySong)
    eulogySong.play(from: source)
  }

  /// #195: the small player's tap brings the sheet back as the song is, playing or paused.
  func showEulogySongSheet(from source: String) {
    log.event("ui", ["action": "open_eulogy_song_sheet", "from": source])
    screens.open(.eulogySong)
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
    guard askAudio(.audioReset) == nil else { return }
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
    askAudio(.cockpitOpens)
    if bringForward(.cockpit, from: source) { return }
    screens.open(.cockpit)
  }

  func closeCockpit() { close(.cockpit) }

  var cockpitOpened = false

  /// The archive's device id (the vendor id): which boards this install draws on.
  var whiteboardDevice: String {
    database.setting(ArchiveModel.deviceKey) ?? UIDevice.current.identifierForVendor?.uuidString.lowercased()
      ?? "this-device"
  }

  /// #603: nil when the board is on this device, once iCloud has been asked; otherwise the problem to show.
  func findBoard(_ id: String, context: String) async -> BugProblem? {
    await whiteboards.find(id, context: context)
  }

  func openWhiteboard(from source: String) {
    log.event("ui", ["action": "open_whiteboard", "from": source])
    if bringForward(.whiteboard, from: source) { return }
    screens.open(.whiteboard)
  }

  /// #722, story 724: the whiteboard, on a new empty board.
  func newBoard(from source: String) {
    log.event("ui", ["action": "new_board", "from": source])
    whiteboardNewBoard = true
    if !showWhiteboard { openWhiteboard(from: source) }
  }

  func closeWhiteboard() { close(.whiteboard) }

  func openCall(from source: String) {
    log.event("ui", ["action": "open_call", "from": source, "state": call.snapshot.state.rawValue])
    askAudio(.callScreenOpens)
    close(.timer)
    screens.open(.call)
  }

  func closeCall() { close(.call) }

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
    screens.open(.whatsNew)
  }

  func openToday(from source: String) {
    log.event("ui", ["action": "open_today", "from": source])
    if bringForward(.today, from: source) { return }
    screens.open(.today)
  }

  func openMetric(_ key: MetricKey, from source: String) {
    log.event("ui", ["action": "open_metric", "metric": key.rawValue, "from": source])
    screens.open(.metric(key))
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
