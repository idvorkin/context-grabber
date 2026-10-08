//  The app's one call: owned by AppModel so it outlives the call screen, the lock and the background. Wires
//  ContextCore's CallSession to the socket, the audio engine and the clock; narrates every `call_*` event into the
//  session log and this launch's call log; remembers the backend and the voice; uploads the log as a private gist
//  on a tap or after a troubled call (docs/superpowers/specs/2026-09-05-diagnostics-gist-upload-design.md).

import AVFoundation
import ContextCore
import SwiftUI
import UIKit

enum UploadState: Equatable { case idle, uploading, uploaded, failed }

@MainActor
final class CallModel: ObservableObject {
  @Published private(set) var snapshot = CallSnapshot()
  @Published private(set) var level = 0.0
  @Published private(set) var route = ""
  /// Bumped on every call event, so an open Diagnostics fold redraws.
  @Published private(set) var logVersion = 0
  @Published private(set) var upload = UploadState.idle
  @Published private(set) var uploadError: String?
  @Published private(set) var uploads: [Gist.Upload] = []
  @Published private(set) var hasToken = false
  @Published var autoUpload = true {
    didSet { database.setSetting(Self.autoKey, autoUpload ? "true" : "false") }
  }
  @Published var backend = CallBackend.default {
    didSet { database.setSetting(Self.backendKey, backend.rawValue) }
  }
  @Published var voice = CallVoice.default {
    didSet { database.setSetting(Self.voiceKey, voice.rawValue) }
  }

  let events = CallEventLog()
  let bridgeURL: String
  private let log: SessionLog
  private let database: AppDatabase
  private var session: CallSession!
  private var uploadReset: Task<Void, Never>?

  /// The same keys as the React Native app's settings table, so the cutover keeps the picks.
  private static let backendKey = "call_backend"
  private static let voiceKey = "call_voice"
  private static let autoKey = "gist_auto_upload"
  private static let uploadsKey = "gist_uploads"
  private static let tokenAccount = "gist_token"
  static let cockpitURL = "https://c-5004.squeaker-teeth.ts.net"

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    bridgeURL = environment["GRABBER_CALL"].flatMap { $0.isEmpty ? nil : $0 }
      ?? CallProtocol.bridgeURL(cockpit: Self.cockpitURL) ?? ""
    backend = database.setting(Self.backendKey).flatMap(CallBackend.init(rawValue:)) ?? .default
    voice = database.setting(Self.voiceKey).flatMap(CallVoice.init(rawValue:)) ?? .default
    autoUpload = database.setting(Self.autoKey) != "false"
    uploads = Gist.decodeUploads(database.setting(Self.uploadsKey))
    hasToken = Keychain.get(Self.tokenAccount) != nil

    let audio: CallAudio
    if environment["GRABBER_CALL_AUDIO"] == "synthetic" {
      audio = SyntheticCallAudio { [weak self] type, fields in self?.event(type, fields) }
    } else {
      audio = CallAudioEngine { [weak self] type, fields in
        nonisolated(unsafe) let fields = fields
        DispatchQueue.main.async { self?.event(type, fields) }
      }
    }
    let deps = CallSessionDeps(
      connect: { url in
        guard let u = URL(string: url) else { throw CallAudioError("not a bridge address: \(url)") }
        return BridgeWebSocket(url: u)
      },
      audio: audio, scheduler: MainScheduler(),
      log: { [weak self] type, fields in self?.event(type, fields) },
      diagnostics: { [weak self] in self?.diagnosticsText() ?? "" },
      build: "\(BuildInfo.sha) (\(BuildInfo.branch))")
    session = CallSession(deps: deps, url: bridgeURL)
    session.onChange = { [weak self] snap in self?.onChange(snap) }
    session.onLevel = { [weak self] level in self?.level = level }
    route = CallAudioEngine.describeRoute()
    NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.route = CallAudioEngine.describeRoute() }
    }
  }

  // MARK: - the call

  /// Runs just before a call takes the audio session: the eulogy song pauses (#197).
  var willStart: (() -> Void)?

  func start(from source: String) {
    willStart?()
    log.event("ui", ["action": "call", "from": source, "backend": backend.rawValue, "voice": voice.rawValue])
    session.start(backend, voice: voice)
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
    let label = CallVoice.hasPick(b) ? "\(b.label) · \(snapshot.voice.label)" : b.label
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
    if snap.state == .ended, was != .ended { onEnded() }
  }

  /// After a troubled call, on its own, when there is a token and the switch is on. The trigger is what the log says.
  private func onEnded() {
    guard hasToken, autoUpload, CallEventLog.hadTrouble(events.currentCall) else { return }
    Task { try? await uploadDiagnostics(why: "troubled call") }
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
      ("ended", snapshot.endedReason ?? ""), ("problem", snapshot.problem ?? ""), ("route", route),
      ("bridge", bridgeURL), ("session log", log.url.lastPathComponent),
    ]
  }

  func diagnosticsText() -> String { events.render(header: header()) }

  func copyDiagnostics() {
    UIPasteboard.general.string = diagnosticsText()
    log.event("ui", ["action": "copy_diagnostics", "events": events.events.count])
  }

  // MARK: - gists

  var lastUploadURL: String? { uploads.first?.url }

  func setToken(_ token: String) throws {
    try Keychain.set(Self.tokenAccount, token)
    hasToken = Keychain.get(Self.tokenAccount) != nil
    // Never the token itself: only whether there is one.
    log.event("ui", ["action": "gist_token", "saved": hasToken])
  }

  func uploadTapped() {
    upload = .uploading
    uploadError = nil
    Task {
      do {
        _ = try await uploadDiagnostics(why: "upload requested")
        upload = .uploaded
      } catch {
        uploadError = describe(error)
        upload = .failed
      }
      uploadReset?.cancel()
      uploadReset = Task {
        try? await Task.sleep(for: .seconds(2.5))
        if !Task.isCancelled, upload != .uploading { upload = .idle }
      }
    }
  }

  /// The whole log as a secret gist; the URL on the clipboard and in the log. Throws with the reason.
  @discardableResult
  func uploadDiagnostics(why: String) async throws -> String {
    guard let token = Keychain.get(Self.tokenAccount) else {
      throw GistError("no GitHub token — home screen → Diagnostics uploads")
    }
    let body = Gist.body(at: Date(), why: why, text: diagnosticsText())
    event("call_gist", ["action": "upload", "why": why, "bytes": body.count])
    do {
      let (data, response) = try await URLSession.shared.data(for: Gist.createRequest(token: token, body: body))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      let up = try Gist.parseCreate(status: status, body: data, at: Date()).get()
      event("call_gist", ["action": "uploaded", "ok": true, "why": why, "url": up.url])
      UIPasteboard.general.string = up.url
      let all = [up] + uploads
      remember(all)
      // The link shows at once; the oldest are retired behind it unless Delete cleared the list meanwhile.
      let kept = await Gist.retire(all) { id in try await Self.deleteGist(token: token, id: id) }
      if uploads.contains(up) { remember(kept) }
      return up.url
    } catch {
      event("call_gist", ["action": "upload", "ok": false, "why": why, "message": describe(error)])
      throw error
    }
  }

  /// *Delete uploaded diagnostics (N)*: every gist this app made, one request each.
  func deleteUploads() async -> String {
    guard let token = Keychain.get(Self.tokenAccount) else { return "no GitHub token" }
    let list = uploads
    var deleted = 0
    var gone = 0
    var stuck: [Gist.Upload] = []
    for u in list {
      do {
        if try await Self.deleteGist(token: token, id: u.id) { deleted += 1 } else { gone += 1 }
      } catch {
        stuck.append(u)
      }
    }
    remember(stuck)
    let result =
      "deleted \(deleted) of \(list.count)" + (gone > 0 ? " — \(gone) already gone" : "")
      + (stuck.isEmpty ? "" : " — \(stuck.count) failed, kept")
    event("call_gist", ["action": "delete", "deleted": deleted, "gone": gone, "failed": stuck.count, "ok": stuck.isEmpty])
    return result
  }

  private static func deleteGist(token: String, id: String) async throws -> Bool {
    let (_, response) = try await URLSession.shared.data(for: Gist.deleteRequest(token: token, id: id))
    return try Gist.parseDelete(status: (response as? HTTPURLResponse)?.statusCode ?? 0).get()
  }

  private func remember(_ list: [Gist.Upload]) {
    uploads = list
    database.setSetting(Self.uploadsKey, Gist.encodeUploads(list))
  }
}
