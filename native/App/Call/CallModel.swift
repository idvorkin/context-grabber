//  The app's one call: owned by AppModel so it outlives the call screen, the lock and the background. Wires
//  ContextCore's CallSession to the socket, the audio engine and the clock; narrates every `call_*` event into the
//  session log and this launch's call log; remembers the backend and the voice; after a troubled call, files the
//  call's log as a BugKit automatic report, which the Mac's listener turns into an issue (story 248).

import AVFoundation
import BugKit
import ContextCore
import CoreLocation
import Network
import Security
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class CallModel: ObservableObject {
  @Published private(set) var snapshot = CallSnapshot()
  @Published private(set) var level = 0.0
  @Published private(set) var route = ""
  /// #107: the last fix this call sent, so only a significant move sends another.
  private var sentLocation: CallLocation?
  /// Story 086, #293: the microphones and outputs the devices menu offers, and what was picked this call (nil: iOS).
  @Published private(set) var devices: AudioRouteSnapshot?
  @Published private(set) var chosenInput: String?
  @Published private(set) var chosenOutput: String?
  /// #582, story 829: a held call's notification could not be sent (notifications are off for the app).
  @Published private(set) var holdNoticeRefused = false
  /// The held call's notification is wanted: a removal that lands while the post is in flight wins.
  private var holdNoticeUp = false
  private static let holdNoticeID = "call-held"
  /// Bumped on every call event, so an open Diagnostics fold redraws.
  @Published private(set) var logVersion = 0
  @Published var backend = CallBackend.default {
    didSet { database.setSetting(Self.backendKey, backend.rawValue) }
  }
  @Published var voice = CallVoice.default {
    didSet { database.setSetting(Self.voiceKey, voice.rawValue) }
  }
  /// #556: the speech-to-text a Direct call asks the bridge for; Default sends nothing.
  @Published var stt = CallSTT.default {
    didSet { database.setSetting(Self.sttKey, stt.rawValue) }
  }

  let events = CallEventLog()
  /// Stories 1088-1089: *Live heart rate on calls* asks Exercise Analyzer to start and end the watch's Call session.
  let liveHeartRate: LiveHeartRateOnCalls
  let bridgeURL: String
  /// Story 212: where every call's log goes at its end (the stats archive's destination, same simulator and Mac rule).
  private let archiveURL: String?
  private let log: SessionLog
  private let database: AppDatabase
  // #417, story 085: the call never waits for this refresh.
  private var callSettings = CallSettings()
  private var settingsTask: Task<Void, Never>?
  private static let settingsKey = "call_voice_recommendations"

  // Made at the end of init: its callbacks capture self.
  // swiftlint:disable:next implicitly_unwrapped_optional
  private var session: CallSession!
  /// Steers the session for the devices menu, and puts a pick back when the route moves mid-call. The Cockpit has
  /// its own for the page; only one of them is ever asked to hold a choice at a time (a call and the page's capture
  /// do not share the microphone).
  private lazy var router = AudioRouteController(log: log)
  /// #440, #439, story 209: the network under the call, logged at its start and at every change while it is up.
  private var pathMonitor: NWPathMonitor?
  private var lastPath: CallNetworkPath?
  /// Story 1073: the call's audio, asked whether echo cancellation is on for what the bridge is told.
  private var callAudio: CallAudio?
  /// BugKit's automatic report, set by AppModel once its reporter exists: (reason, context, files).
  var autoReport: ((String, [String: JSONValue], [URL]) -> Void)?
  /// One stable reason, so BugKit's ten-minute window holds across calls and relaunches.
  static let troubleReason = "call_trouble"

  /// The same keys as the React Native app's settings table, so the cutover keeps the picks.
  private static let backendKey = "call_backend"
  private static let voiceKey = "call_voice"
  /// Native only (#556): the React Native app never had a speech-to-text pick, so there is nothing to carry over.
  private static let sttKey = "call_stt"
  /// What the gist (story 094, gone from this app) left behind: the token in the Keychain and the uploads' list.
  private static let gistToken = "gist_token"
  private static let gistUploads = "gist_uploads"
  static let cockpitURL = ChatCockpit.callAddress(chatOverride: LaunchHooks.current.chatURL)

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    liveHeartRate = LiveHeartRateOnCalls(log: log, database: database, environment: environment)
    archiveURL = ArchiveModel.destination(environment)
    bridgeURL = CallProtocol.bridgeURL(environment: environment, cockpit: Self.cockpitURL) ?? ""
    backend = database.setting(Self.backendKey).flatMap(CallBackend.init(rawValue:)) ?? .default
    voice = database.setting(Self.voiceKey).flatMap(CallVoice.init(rawValue:)) ?? .default
    stt = database.setting(Self.sttKey).flatMap(CallSTT.init(rawValue:)) ?? .default
    callSettings = CallSettings(saved: database.setting(Self.settingsKey))
    forgetGist()

    let audio: CallAudio
    if environment["GRABBER_CALL_AUDIO"] == "synthetic" {
      audio = SyntheticCallAudio { [weak self] type, fields in self?.event(type, fields) }
    } else {
      audio = CallAudioEngine { [weak self] type, fields in
        nonisolated(unsafe) let fields = fields
        DispatchQueue.main.async { self?.event(type, fields) }
      }
    }
    var deps = CallSessionDeps(
      connect: { url in
        guard let u = URL(string: url) else { throw CallAudioError("not a bridge address: \(url)") }
        return BridgeWebSocket(url: u) { [weak self] type, fields in
          nonisolated(unsafe) let fields = fields
          DispatchQueue.main.async { self?.event(type, fields) }
        }
      },
      audio: audio, scheduler: MainScheduler(),
      log: { [weak self] type, fields in self?.event(type, fields) },
      diagnostics: { [weak self] in self?.diagnosticsText() ?? "" },
      build: "\(BuildInfo.sha) (\(BuildInfo.branch))")
    deps.callSettings = { [weak self] in
      self?.refreshCallSettings()
      return self?.callSettings ?? CallSettings()
    }
    deps.appState = { Self.appState() }
    deps.holdNotice = { [weak self] notice in self?.holdNotice(notice) }
    callAudio = audio
    // Story 1073: the device, route, audio and network, read as the bridge answers.
    deps.meta = { [weak self] in
      MainActor.assumeIsolated {
        CallMeta(
          device: .current(), route: .current(), audio: .current(voiceProcessing: self?.callAudio?.voiceProcessing()),
          network: self?.lastPath)
      }
    }
    session = CallSession(deps: deps, url: bridgeURL)
    session.onChange = { [weak self] snap in self?.onChange(snap) }
    session.onLevel = { [weak self] level in self?.level = level }
    refreshCallSettings()
    route = CallAudioEngine.describeRoute()
    // #582: a call held for the app starts its mic once the app is in front; a hop, so the audio engine's own
    // observer has its state first.
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      DispatchQueue.main.async { MainActor.assumeIsolated { self?.session.appBecameActive() } }
    }
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] note in
      let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
      MainActor.assumeIsolated {
        self?.route = CallAudioEngine.describeRoute()
        self?.refreshDevices()
        // Story 1073: the bridge hears of a route that changed devices; the session drops the same devices.
        self?.session.routeChanged(
          .current(), audio: .current(voiceProcessing: self?.callAudio?.voiceProcessing()),
          reason: AudioRouting.reasonName(raw))
      }
    }
  }

  /// Non-blocking conditional GET with an eight-second request budget, coalesced across launch and call starts.
  private func refreshCallSettings() {
    guard settingsTask == nil else { return }
    guard callSettings.needsRefresh(at: Date()) else {
      settingsEvent(ok: true, status: 0, schema: callSettings.recommendations?.schema, source: "cache")
      return
    }
    guard let url = URL(string: Self.cockpitURL)?.appendingPathComponent("voices/recommended") else { return }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(callSettings.etag, forHTTPHeaderField: "If-None-Match")
    settingsTask = Task { [weak self] in
      guard let self else { return }
      defer { settingsTask = nil }
      do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let schema = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["schema"] as? Int
        let ok = callSettings.receive(
          status: status, data: data, etag: http?.value(forHTTPHeaderField: "ETag"),
          cacheControl: http?.value(forHTTPHeaderField: "Cache-Control"), at: Date())
        if ok, let saved = callSettings.saved { database.setSetting(Self.settingsKey, saved) }
        settingsEvent(
          ok: ok, status: status, schema: schema ?? (status == 304 ? callSettings.recommendations?.schema : nil),
          source: ok ? "network" : (callSettings.recommendations == nil ? "fallback" : "cache"),
          responseETag: http?.value(forHTTPHeaderField: "ETag"))
      } catch {
        settingsEvent(
          ok: false, status: 0, schema: callSettings.recommendations?.schema,
          source: callSettings.recommendations == nil ? "fallback" : "cache", message: String(describing: error))
      }
    }
  }

  private func settingsEvent(
    ok: Bool, status: Int, schema: Int?, source: String, responseETag: String? = nil, message: String = ""
  ) {
    event(
      "call_settings",
      [
        "ok": ok, "status": status, "schema": schema as Any? ?? NSNull(),
        "etag": responseETag ?? callSettings.etag ?? "", "source": source, "message": message,
      ])
  }

  // MARK: - the call

  /// Runs just before a call takes the audio session: the eulogy song pauses (#197).
  var willStart: (() -> Void)?
  /// Story 217: today so far, from the last grab and the strip, for a Direct call's start frame.
  var today: (() -> CallToday?)?

  func start(from source: String) {
    sentLocation = nil
    session.clearLocation()
    session.setToday(backend == .direct ? today?() : nil)
    willStart?()
    askNotificationsIfUndecided()
    log.event(
      "ui",
      [
        "action": "call", "from": source, "backend": backend.rawValue, "voice": voice.rawValue,
        "stt": stt.frameField(for: backend),
      ])
    session.start(backend, voice: voice, stt: stt)
  }

  func hangUp(from source: String) {
    log.event("ui", ["action": "hang_up", "from": source])
    session.stop()
  }

  func restart() {
    log.event("ui", ["action": "restart_call"])
    session.restart()
  }

  func toggleMute() { session.setMuted(!snapshot.muted) }

  /// The status line: `calling Larry… · ElevenLabs · Igor`, `live · 1:17 · ElevenLabs`, `ended — stopped`.
  func status(now: Date) -> String {
    let b = snapshot.backend ?? backend
    var label = CallVoice.hasPick(b) ? "\(b.label) · \(snapshot.voice.label)" : b.label
    if CallSTT.hasPick(b), snapshot.stt != .default { label += " · \(snapshot.stt.label)" }
    switch snapshot.state {
    case .connecting: return "calling Larry… · \(label)"
    case .live:
      let s = max(0, Int((now.timeIntervalSince1970 * 1000 - (snapshot.startedAt ?? 0)) / 1000))
      return "live · \(s / 60):\(String(format: "%02d", s % 60)) · \(label)"
    case .ended: return "ended — \(CallProtocol.endingText(snapshot.endedReason))"
    case .idle: return ""
    }
  }

  private func onChange(_ snap: CallSnapshot) {
    let was = snapshot.state
    snapshot = snap
    route = CallAudioEngine.describeRoute()
    if snap.isActive { refreshDevices() }
    if snap.state == .connecting, was != .connecting { watchNetwork() }
    if snap.state != was { liveHeartRate.onCall(snap) }
    if snap.state == .ended, was != .ended {
      stopWatchingNetwork()
      // #440: a handoff redial keeps the devices Igor picked and files no trouble report; its log still archives.
      if snap.redialing { return archiveCallLog() }
      releaseDevices()
      onEnded()
    }
  }

  // MARK: - held for the app (#582, story 829)

  private static func appState() -> String {
    switch UIApplication.shared.applicationState {
    case .active: return "active"
    case .background: return "background"
    default: return "inactive"
    }
  }

  /// A held call is always in the background, where iOS cannot ask: so the question comes as a call starts, once.
  private func askNotificationsIfUndecided() {
    Task { [weak self] in
      let center = UNUserNotificationCenter.current()
      guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
      let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
      self?.event("notify_allowed", ["allowed": granted, "status": "asked", "why": "call_start"])
    }
  }

  private func holdNotice(_ notice: CallHoldNotice) {
    switch notice {
    case .post:
      holdNoticeUp = true
      Task { [weak self] in await self?.postHoldNotice() }
    case .remove:
      holdNoticeUp = false
      holdNoticeRefused = false
      Self.removeHoldNotice()
    }
  }

  private static func removeHoldNotice() {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [holdNoticeID])
    center.removeDeliveredNotifications(withIdentifiers: [holdNoticeID])
  }

  private func postHoldNotice() async {
    let center = UNUserNotificationCenter.current()
    let status = await center.notificationSettings().authorizationStatus
    let allowed = [.authorized, .provisional, .ephemeral].contains(status)
    event("notify_allowed", ["allowed": allowed, "status": Self.statusName(status), "why": "call_held"])
    guard holdNoticeUp else { return }
    guard allowed else {
      holdNoticeRefused = true
      return
    }
    let content = UNMutableNotificationContent()
    content.title = CallHold.notificationTitle
    content.body = CallHold.notificationBody
    content.sound = .default
    content.userInfo = ["call": "held"]
    do {
      try await center.add(UNNotificationRequest(identifier: Self.holdNoticeID, content: content, trigger: nil))
      // The hold ended while the post was on its way: take it down again.
      if !holdNoticeUp { Self.removeHoldNotice() }
    } catch {
      holdNoticeRefused = true
      event("error", ["where": "call_hold_notice", "message": describe(error)])
    }
  }

  private static func statusName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "not_determined"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown"
    }
  }

  // MARK: - the network (story 209, #440, #439)

  private func watchNetwork() {
    stopWatchingNetwork()
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self, weak monitor] path in
      let snapshot = Self.networkPath(path)
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          // Fable on #440: a reading the cancelled monitor queued is not the new call's first.
          guard let self, let monitor, self.pathMonitor === monitor else { return }
          self.onPath(snapshot)
        }
      }
    }
    pathMonitor = monitor
    // #1414 (story 1074), a guard, not a proven fix: the post-hang-up crash released a freed object in a block on a
    // global concurrent queue, and this monitor was the only thing the call handed one. A serial queue of its own
    // keeps its deliveries from running at once with each other or with its cancel.
    monitor.start(queue: Self.networkQueue)
  }

  private static let networkQueue = DispatchQueue(label: "call.network", qos: .utility)

  private func stopWatchingNetwork() {
    if let monitor = pathMonitor {
      // #1414 (story 1074): a crash 1.4 s after a hang-up released a freed object on a global queue just as this
      // monitor was cancelled; the stop line places the cancel against the next crash's last lines.
      event("call_network", ["action": "stop"])
      monitor.cancel()
    }
    pathMonitor = nil
    lastPath = nil
  }

  private func onPath(_ path: CallNetworkPath) {
    guard pathMonitor != nil, path != lastPath else { return }
    let first = lastPath == nil
    lastPath = path
    event("call_network", path.fields.merging(["action": first ? "start" : "change"]) { _, new in new })
    // #440: a lost connection soon after redials, but only onto a network that is up: no network is not a handoff.
    if !first, path.status == "satisfied" { session.networkChanged() }
    // Story 1073: the bridge is told each change; the first reading rides the start frame's meta.
    if !first { session.networkPathChanged(path) }
  }

  private nonisolated static func networkPath(_ path: NWPath) -> CallNetworkPath {
    let status: String
    switch path.status {
    case .satisfied: status = "satisfied"
    case .unsatisfied: status = "unsatisfied"
    case .requiresConnection: status = "requiresConnection"
    @unknown default: status = "unknown"
    }
    // #440: the types the path uses (what the call's traffic is on), and separately all that are available.
    let name: (NWInterface.InterfaceType) -> String = { type in
      switch type {
      case .wifi: return "wifi"
      case .cellular: return "cellular"
      case .wiredEthernet: return "wired"
      case .loopback: return "loopback"
      case .other: return "other"
      @unknown default: return "unknown"
      }
    }
    let types: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet, .other, .loopback]
    let interfaces = types.filter { path.usesInterfaceType($0) }.map(name)
    let available = path.availableInterfaces.map { name($0.type) }
    return CallNetworkPath(
      status: status, interfaces: interfaces, available: available, expensive: path.isExpensive,
      constrained: path.isConstrained)
  }

  // MARK: - where Igor is (story 092, #107)

  /// A fix from the location tracker: before the socket opens it rides the start frame, afterwards it goes as its own
  /// frame, and only when it is a significant move from the last one sent (a different known place, or 200 m).
  func offerLocation(_ fix: CLLocation, knownPlaces: [KnownPlace]) {
    let location = CallLocation.fix(
      lat: fix.coordinate.latitude, lon: fix.coordinate.longitude, accuracy: fix.horizontalAccuracy,
      at: fix.timestamp, knownPlaces: knownPlaces)
    guard CallLocation.isSignificantMove(from: sentLocation, to: location) else { return }
    sentLocation = location
    session.setLocation(location)
  }

  // MARK: - the devices menu (story 086, #293)

  func refreshDevices() {
    guard snapshot.isActive else { return }
    devices = router.snapshot()
  }

  /// nil hands the microphone back to iOS (Automatic).
  func chooseInput(_ id: String?) {
    if id == nil { router.forget(output: false) } else { router.observeRouteChanges() }
    do {
      try router.setInput(id, remember: id != nil)
      chosenInput = id
      event("call_devices", ["action": "input", "ok": true, "chosen": id ?? "automatic"])
    } catch {
      event("call_devices", ["action": "input", "ok": false, "chosen": id ?? "automatic", "message": "\(error)"])
    }
    route = CallAudioEngine.describeRoute()
    refreshDevices()
  }

  func chooseOutput(_ id: String) {
    let automatic = id == AudioRouting.auto
    if automatic { router.forget(input: false) } else { router.observeRouteChanges() }
    do {
      try router.setOutput(id, remember: !automatic)
      if automatic, chosenOutput != nil, chosenInput == nil { try router.setInput(nil, remember: false) }
      chosenOutput = automatic ? nil : id
      event("call_devices", ["action": "output", "ok": true, "chosen": id])
    } catch {
      event("call_devices", ["action": "output", "ok": false, "chosen": id, "message": "\(error)"])
    }
    route = CallAudioEngine.describeRoute()
    refreshDevices()
  }

  /// A pick lasts the call: afterwards iOS routes again, as it would have without one.
  private func releaseDevices() {
    router.forget()
    guard chosenInput != nil || chosenOutput != nil else { return }
    try? router.setInput(nil, remember: false)
    if chosenOutput != nil { try? router.setOutput(AudioRouting.auto, remember: false) }
    chosenInput = nil
    chosenOutput = nil
    event("call_devices", ["action": "released", "ok": true])
  }

  /// After a troubled call, on its own: the call's log as a BugKit automatic report (story 248). The trigger is what
  /// the log says; BugKit keeps it to one per ten minutes and the log within 5 MB.
  private func onEnded() {
    archiveCallLog()
    guard CallEventLog.hadTrouble(events.currentCall), let autoReport else { return }
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("call-log.txt")
    do {
      try Data(diagnosticsText().utf8).write(to: file, options: .atomic)
    } catch {
      log.event("error", ["where": "call_report", "message": "\(error)"])
      return
    }
    autoReport(
      Self.troubleReason,
      [
        "ended": .string(snapshot.endedReason ?? ""), "problem": .string(snapshot.problem ?? ""),
        "backend": .string(snapshot.backend?.rawValue ?? ""), "voice": .string(snapshot.voice.rawValue),
        "stt": .string(snapshot.stt.rawValue),
      ],
      [file])
  }

  /// Story 212 (#442): every call's log to the Cockpit's archive at its end, one record per line under the call's
  /// bridge session, so a call that merely sounded wrong can be read on Larry's box without the phone. The socket
  /// dump at the hang-up stays; the bridge has never filed it. One try: the call is over and the app may be about to
  /// suspend. ponytail: a failed send is logged and not retried; the next call's archive does not carry it.
  private func archiveCallLog() {
    let records = CallLogArchive.records(header: header(), events: events.currentCall)
    let call = records.first?["call"] as? String ?? ""
    guard let archiveURL else {
      event("call_archive", ["ok": false, "call": call, "records": records.count, "reason": "no archive URL"])
      return
    }
    let deviceId = database.setting(ArchiveModel.deviceKey) ?? "unknown-device"
    let batch = ArchiveBatch(stream: CallLogArchive.stream, deviceId: deviceId, records: records)
    let request: URLRequest
    do {
      request = try ArchiveSend.request(batch, cockpit: archiveURL)
    } catch {
      event("call_archive", ["ok": false, "call": call, "records": records.count, "reason": describe(error)])
      return
    }
    let count = records.count
    // #1414 (story 1074): the send starts here and is logged again when it returns, so a crash between shows.
    event("call_archive", ["action": "send", "call": call, "records": count])
    Task { [weak self] in
      let outcome: ArchiveSend.Outcome
      do {
        let (data, response) = try await URLSession.shared.data(for: request)
        outcome = ArchiveSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: data)
      } catch {
        outcome = .retry(reason: describe(error))
      }
      self?.archived(call: call, records: count, outcome: outcome)
    }
  }

  private func archived(call: String, records: Int, outcome: ArchiveSend.Outcome) {
    var fields: [String: Any] = ["call": call, "records": records]
    switch outcome {
    case .taken(let inserted, let duplicate):
      fields["ok"] = true
      fields["inserted"] = inserted
      fields["duplicate"] = duplicate
    case .refused(let status, let reason):
      fields["ok"] = false
      fields["status"] = status
      fields["reason"] = reason
    case .retry(let reason):
      fields["ok"] = false
      fields["reason"] = reason
    }
    event("call_archive", fields)
  }

  /// The gist is gone (2026-10-11): its token leaves the Keychain and its list of uploads leaves the settings, once.
  private func forgetGist() {
    let token: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.idvorkin.grabbernative",
      kSecAttrAccount as String: Self.gistToken,
    ]
    if SecItemDelete(token as CFDictionary) == errSecSuccess { log.event("call_gist", ["action": "token_removed"]) }
    if let list = database.setting(Self.gistUploads), !list.isEmpty { database.setSetting(Self.gistUploads, "") }
  }

  // MARK: - the log

  private func event(_ type: String, _ fields: [String: Any]) {
    log.event(type, fields)
    events.add(type, t: Int(Date().timeIntervalSince(log.startedAt) * 1000), fields: fields)
    logVersion += 1
  }

  private func header() -> [(String, String)] {
    [
      ("build", "\(BuildInfo.sha) (\(BuildInfo.branch))"), ("state", snapshot.state.rawValue),
      ("backend", snapshot.backend?.rawValue ?? ""), ("voice", snapshot.voice.rawValue),
      ("stt", snapshot.stt.rawValue), ("ended", snapshot.endedReason ?? ""), ("problem", snapshot.problem ?? ""),
      ("route", route),
      ("bridge", bridgeURL), ("session log", log.url.lastPathComponent),
    ]
  }

  func diagnosticsText() -> String { events.render(header: header()) }

  func copyDiagnostics() {
    UIPasteboard.general.string = diagnosticsText()
    log.event("ui", ["action": "copy_diagnostics", "events": events.events.count])
  }
}
