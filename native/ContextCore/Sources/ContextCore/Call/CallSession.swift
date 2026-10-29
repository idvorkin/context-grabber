//  A Larry call: the socket, the microphone, the speaker and the captions, with no platform in it, so the whole
//  thing runs under a fake socket, a fake audio layer and a fake clock on the Mac.
//
//    idle ─start→ connecting ─ready→ live ─(stop | closed | drop)→ ended ─start→ …
//
//  The bridge decides everything about the conversation. This class decides only: when the mic opens (on
//  `ready`, not before), what leaves the phone (nothing while muted), when playback is cut (on `interrupted`), how
//  a dead microphone is healed, and how the call is reported to have ended. Every boundary is a `call_*` event in
//  the session log (docs/DEBUGGING.md).
//
//  Main thread only: the app hops socket messages, mic buffers and audio callbacks onto the main queue before
//  calling in, and the fakes call straight through.
//
//  Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md; the native differences are under step 3
//  of docs/superpowers/specs/2026-10-04-swift-native-app-design.md. Port of lib/callSession.ts.

import Foundation

public enum CallState: String, Sendable { case idle, connecting, live, ended }

public enum CaptionWho: String, Sendable { case igor, larry, tool, note }

public struct CaptionRow: Equatable, Identifiable, Sendable {
  public var id: Int
  public var who: CaptionWho
  public var text: String
  /// Igor's words as the recognizer still hears them — not yet settled.
  public var pending: Bool
  /// #467, story 216: Igor's sentence has gone to Larry and Larry has not answered yet.
  public var sent: Bool

  public init(id: Int, who: CaptionWho, text: String, pending: Bool, sent: Bool = false) {
    self.id = id
    self.who = who
    self.text = text
    self.pending = pending
    self.sent = sent
  }
}

public struct CallSnapshot: Equatable, Sendable {
  public var state: CallState = .idle
  public var backend: CallBackend?
  /// The voice the call was placed in (#98).
  public var voice: CallVoice = .default
  /// The speech-to-text a Direct call was placed with (#556).
  public var stt: CallSTT = .default
  /// The scheduler's clock (ms) when the bridge said `ready`; the timer counts from here.
  public var startedAt: Double?
  /// The bridge's reason (or `connection lost`), raw — the screen shows `CallProtocol.endingText` of it.
  public var endedReason: String?
  /// True when the ending was a failure rather than a hang-up.
  public var endedBadly = false
  public var captions: [CaptionRow] = []
  public var muted = false
  /// A problem that did not end the call — the mic not reaching Larry, a bridge error.
  public var problem: String?

  public init() {}

  public var isActive: Bool { state == .connecting || state == .live }

  /// The home tile's corner badge for a call left running: one short line, so the Call tile keeps its neighbours'
  /// size (Codex on #295). `nowMs` is on the clock `startedAt` is.
  public func tileBadge(nowMs: Double) -> String? {
    switch state {
    case .connecting: return "calling\u{2026}"
    case .live:
      let s = max(0, Int((nowMs - (startedAt ?? nowMs)) / 1000))
      return "\(s / 60):\(String(format: "%02d", s % 60))"
    case .idle, .ended: return nil
    }
  }
}

/// A one-shot timer the scheduler handed out.
public protocol CallTimer: AnyObject {
  func cancel()
}

/// The clock and the timers, so tests can move time by hand.
public protocol CallScheduler: AnyObject {
  /// Milliseconds; the app uses the wall clock.
  var now: Double { get }
  func after(_ ms: Double, _ block: @escaping () -> Void) -> CallTimer
}

/// The socket the session uses. Callbacks arrive on the main thread.
public protocol BridgeSocket: AnyObject {
  var onOpen: (() -> Void)? { get set }
  var onText: ((String) -> Void)? { get set }
  var onBinary: ((Data) -> Void)? { get set }
  /// The socket is gone — closed by the far end, or failed. The argument says why, for the log.
  var onClose: ((String) -> Void)? { get set }
  func send(text: String)
  func send(data: Data)
  func close()
}

/// The audio half: microphone in, speaker out. Completions and buffers arrive on the main thread.
public protocol CallAudio: AnyObject {
  /// The audio layer's own verdict — a mic that stopped, audio not playing — or nil when fine. Set by the session.
  var onHealth: ((String?) -> Void)? { get set }
  /// Session, permission, echo cancellation. Called before the socket opens, so the prompt comes first.
  func prepare(_ done: @escaping (Error?) -> Void)
  /// Open the mic; every buffer arrives with the engine's actual rate.
  func startMic(_ onBuffer: @escaping ([Float], Double) -> Void, _ done: @escaping (Error?) -> Void)
  /// Close and reopen the mic — a heal.
  func restartMic(_ done: @escaping (Error?) -> Void)
  /// Playback at the rate the bridge named.
  func openPlayback(outRate: Double)
  /// One binary frame from the bridge, PCM16 LE at the playback rate.
  func play(_ pcm: Data)
  /// Barge-in: drop everything scheduled and not yet heard.
  func flush()
  /// Mic, playback, session — all of it. Idempotent.
  func stop()
  /// The output side, for the periodic log line; nil before playback opens.
  func stats() -> PlaybackStats?
  /// Current route and input format, for the no-first-buffer watch (#423).
  func micStartupDeadline() -> MicStartupDeadline
}

extension CallAudio {
  public func micStartupDeadline() -> MicStartupDeadline { MicStartupDeadline() }
}

public struct CallSessionDeps {
  /// #417, story 085: resolved for every start, including restart and automatic redial.
  public var callSettings: () -> CallSettings = { CallSettings() }

  public var connect: (String) throws -> BridgeSocket
  public var audio: CallAudio
  public var scheduler: CallScheduler
  /// Where the call narrates itself: `call_*` events with their fields.
  public var log: (String, [String: Any]) -> Void
  /// This launch's call log as text, for the dump the bridge gets at a hang-up (#92). nil: no dump.
  public var diagnostics: (() -> String)?
  /// The build, for the bridge's records (#78).
  public var build: String

  public init(
    connect: @escaping (String) throws -> BridgeSocket, audio: CallAudio, scheduler: CallScheduler,
    log: @escaping (String, [String: Any]) -> Void = { _, _ in }, diagnostics: (() -> String)? = nil,
    build: String = ""
  ) {
    self.connect = connect
    self.audio = audio
    self.scheduler = scheduler
    self.log = log
    self.diagnostics = diagnostics
    self.build = build
  }
}

public final class CallSession {
  /// Mic buffers that are exactly zero before the mic is re-armed. A dead capture graph is zero to the sample; a
  /// quiet room never is (#88). Ten buffers ≈ one second.
  public static let zeroBuffersBeforeRearm = 10
  public static let micSilent = "the microphone is delivering silence"
  public static let micNotReaching = "the microphone is not reaching Larry"
  /// Ordinary startup watch (#88); Bluetooth and a zero input rate get longer (#423).
  public static let firstFrameMs = MicStartupDeadline().ms
  /// How long the bridge gets to acknowledge the first mic frame. Mirrors the page.
  public static let micAckMs = 5000.0
  /// Both directions' counters go in the log this often (#106).
  public static let statsEveryMs = 5000.0

  public private(set) var snapshot = CallSnapshot()
  /// Every change to the snapshot.
  public var onChange: ((CallSnapshot) -> Void)?
  /// 0…1 per mic buffer while the mic is open — muted included; 0 once when the call ends. Its own channel: ten
  /// updates a second must not redraw the captions.
  public var onLevel: ((Double) -> Void)?

  private let deps: CallSessionDeps
  private let url: String
  private var socket: BridgeSocket?
  /// Bumped by every start: a completion from an earlier call must not act on this one.
  private var generation = 0

  private var framesSent = 0
  /// Binary frames the socket delivered — not what the speaker rendered; `audio.stats()` says that.
  private var framesReceived = 0
  private var bytesReceived = 0
  private var lastAudioAt = 0.0
  private var lastTextAt = 0.0
  /// #567: Larry's last finished row, and whether an interruption since then may bring it back as text.
  private var lastLarryRow = ""
  private var cutOffPending = false
  /// #440, #439, story 209: the last frame of any kind each way, so a lost socket says how quiet the line was.
  private var lastRxAt = 0.0
  private var lastTxAt = 0.0
  private var statsTimer: CallTimer?
  private var audioProblem: String?
  private var bridgeProblem: String?
  private var zeroRun = 0
  private var zeroRearmed = false
  /// #364: whether any mic buffer this call carried sound, so a zero-run heal says if the mic was ever live.
  private var micHeard = false
  /// A zero-run rearm's restart has finished and waits for its first sound, for `audio_back` whether or not the mic
  /// was live before.
  private var awaitingSoundAfterRearm = false
  private var firstFrameTimer: CallTimer?
  private var micOpenedAt = 0.0
  private var firstFrameDeadline = MicStartupDeadline()
  private var audioReset = false
  /// One automatic redial per dead burst; cleared by a call whose mic delivers.
  private var redialed = false
  /// #441, story 208: the line a mic that failed to open put up, cleared by its first buffer.
  private var micOpenProblem: String?
  private var micBuffers = 0
  private var nextRowId = 1
  private var igorFinal = ""
  private var igorRowId: Int?
  /// #467: a sentence was sent and the recognizer has heard no new speech since. Its finals in this window are its
  /// own late account of the sentence already sent, whatever their words (its spelling is not the vendor's, and a
  /// split final is only part of it). New speech always starts with a partial, which closes the window.
  private var restateWindow = false
  private var larryRowId: Int?
  private var toolRowId: Int?
  private var probeToken = 0
  private var probeSent = false
  private var rearmed = false
  private var probeTimer: CallTimer?
  private var socketOpen = false
  /// The last fix the app gave; rides the start frame, and a `location` frame when it changes (#107).
  private var location: CallLocation?
  /// Story 217: today so far, set just before a call starts.
  private var today: CallToday?

  public init(deps: CallSessionDeps, url: String) {
    self.deps = deps
    self.url = url
    deps.audio.onHealth = { [weak self] problem in self?.onAudioHealth(problem) }
  }

  // MARK: - controls

  /// No-op while a call is connecting or live: whatever asked for a call joins the one that is up. The voice only
  /// reaches the frame on a backend whose voice is an ElevenLabs one; the speech-to-text only on Direct (#556).
  public func start(_ backend: CallBackend, voice: CallVoice = .default, stt: CallSTT = .default) {
    if snapshot.isActive {
      log("call_ignored", ["action": "start", "backend": backend.rawValue, "state": snapshot.state.rawValue])
      return
    }
    resetForCall(backend: backend, voice: voice, stt: stt)
    let fields = deps.callSettings().fields(for: backend, voice: voice)
    let sttField = stt.frameField(for: backend)
    log(
      "call_start",
      [
        "backend": backend.rawValue, "voice": voice.rawValue, "voice_id": fields.voice, "model": fields.model,
        "build": deps.build, "bridge": url, "model_source": fields.source, "stt": sttField,
      ])
    emit()
    let call = generation
    deps.audio.prepare { [weak self] error in
      guard let self, call == self.generation else { return }
      if let error {
        self.log("call_prepare", ["ok": false, "message": describe(error)])
        self.finish("microphone unavailable: \(describe(error))", badly: true)
        return
      }
      self.log("call_prepare", ["ok": true])
      // A stop() during prepare lands here.
      guard self.snapshot.state == .connecting else { return }
      self.connect(backend: backend, frame: (fields.voice, fields.model, sttField))
    }
  }

  private func connect(backend: CallBackend, frame fields: (voice: String, model: String, stt: String)) {
    let socket: BridgeSocket
    do {
      socket = try deps.connect(url)
    } catch {
      log("call_socket", ["action": "connect", "ok": false, "message": describe(error)])
      finish("\(CallProtocol.connectionLost): \(describe(error))", badly: true)
      return
    }
    self.socket = socket
    socket.onOpen = { [weak self] in
      guard let self else { return }
      self.socketOpen = true
      self.log("call_socket", ["action": "open", "ok": true])
      // Story 217: today so far rides a Direct call's start, never a voice model's.
      let today = backend == .direct ? self.today : nil
      var logged: [String: Any] = [:]
      if let location = self.location { logged["location"] = location.description }
      if let today { logged["today"] = today.description }
      self.send(
        CallProtocol.startFrame(
          backend: backend, build: self.deps.build, voice: fields.voice, model: fields.model, location: self.location,
          today: today, stt: fields.stt),
        frame: "start", logged)
    }
    socket.onText = { [weak self] text in self?.onText(text) }
    socket.onBinary = { [weak self] data in self?.onBinary(data) }
    socket.onClose = { [weak self] why in self?.onSocketGone(why) }
  }

  /// Hang up. The bridge is told first — the dump, `stt_stop` (flushes Deepgram's tail), then `stop`.
  public func stop() {
    guard snapshot.isActive else { return }
    log("call_hangup", [:])
    if socket != nil {
      sendDiagnostics(why: "hang up")
      send(CallProtocol.sttStopFrame(), frame: "stt_stop")
      send(CallProtocol.stopFrame(), frame: "stop")
    }
    finish(CallProtocol.stopped, badly: false)
  }

  /// Restart (#93): hang up and dial again on the same backend in the same voice, one tap. The ended call's
  /// dump goes to the bridge and stays in the log.
  public func restart() {
    guard snapshot.isActive, let backend = snapshot.backend else { return }
    let voice = snapshot.voice
    let stt = snapshot.stt
    log("call_restart", [:])
    stop()
    start(backend, voice: voice, stt: stt)
  }

  /// Where Igor is (#107). Before the socket opens it waits for the start frame; once open, while connecting or
  /// live, it goes as its own frame. Idle or ended, it waits for the next call's start frame, unless
  /// `clearLocation` forgets it first.
  public func setLocation(_ location: CallLocation) {
    self.location = location
    guard snapshot.isActive, socketOpen else { return }
    send(CallProtocol.locationFrame(location), frame: "location", ["location": location.description])
  }

  /// Forgets the last fix, so a new call carries only a fix given for it.
  public func clearLocation() { location = nil }

  /// Story 217: what the day has held, for the next start frame (a Direct call's only); nil sends none.
  public func setToday(_ today: CallToday?) { self.today = today }

  public func setMuted(_ muted: Bool) {
    guard snapshot.muted != muted else { return }
    log("call_mic", ["action": muted ? "muted" : "unmuted"])
    update { $0.muted = muted }
    if snapshot.state == .live { send(CallProtocol.micFrame(muted: muted), frame: "mic", ["muted": muted]) }
  }

  // MARK: - socket

  private func onText(_ text: String) {
    lastRxAt = deps.scheduler.now
    guard snapshot.isActive, let message = CallProtocol.parse(text) else { return }
    onMessage(message)
  }

  private func onBinary(_ data: Data) {
    lastRxAt = deps.scheduler.now
    guard snapshot.state == .live else { return }
    deps.audio.play(data)
    framesReceived += 1
    bytesReceived += data.count
    lastAudioAt = deps.scheduler.now
    if framesReceived == 1 { log("call_rx", ["action": "first_audio", "bytes": data.count]) }
    if snapshot.problem == CallWatchdog.audioNotArriving { setProblem(nil) }
  }

  private func onSocketGone(_ why: String) {
    guard snapshot.isActive else { return }
    let now = deps.scheduler.now
    func since(_ at: Double) -> Double { at > 0 ? (now - at).rounded() : -1 }
    log(
      "call_socket",
      [
        "action": "lost", "message": why, "since_rx_ms": since(lastRxAt), "since_tx_ms": since(lastTxAt),
        "live_ms": since(snapshot.startedAt ?? 0),
      ])
    finish(CallProtocol.connectionLost, badly: true)
  }

  private func send(_ text: String, frame: String, _ fields: [String: Any] = [:]) {
    guard let socket else { return }
    socket.send(text: text)
    lastTxAt = deps.scheduler.now
    log("call_sent", fields.merging(["frame": frame]) { _, new in new })
  }

  /// The dump to the bridge, over the call's own socket, before anything closes (#92).
  private func sendDiagnostics(why: String) {
    guard let text = deps.diagnostics?(), let socket else { return }
    socket.send(text: CallProtocol.diagnosticsFrame(build: deps.build, text: text))
    log("call_sent", ["frame": "diagnostics", "why": why, "bytes": text.utf8.count])
  }

  // MARK: - messages

  private func onMessage(_ m: BridgeMessage) {
    switch m {
    case .ready(let outRate, let backend, let session):
      onReady(outRate: outRate, backend: backend, session: session)
    case .micAck(let token):
      // Only the probe that is waiting: a late ack for an earlier probe must not vouch for a re-armed mic.
      log("call_ack", ["token": token, "stale": token != probeToken])
      if token == probeToken { clearProbe() }
    case .transcript(let who, let text, let source):
      if who == "igor" {
        // The bridge took his words and sent them to Larry (#467): the vendor's transcript replaces the
        // recognizer's, and the sentence leaves the live line now, marked sent, rather than when Larry answers.
        if source != "typed", !text.isEmpty {
          setIgor(final: text, partial: "")
          promoteIgor(sent: true)
        }
      } else if who == "larry" {
        // Larry answering means the vendor decided Igor's turn was over.
        if cutOffPending && CallWatchdog.repeatsCutOff(text, cutOff: lastLarryRow) {
          log("call_bridge", ["kind": "cut_off_resend", "chars": text.count])
        } else {
          lastTextAt = deps.scheduler.now
        }
        cutOffPending = false
        promoteIgor()
        clearSent()
        appendLarry(text)
      }
    case .sttPartial(let text):
      restateWindow = false
      setIgor(final: igorFinal, partial: text)
    case .sttFinal(let text):
      if restateWindow {
        // The recognizer's own final for a sentence the bridge already sent: never show it twice.
        log("call_caption_restated", ["text": text])
      } else {
        setIgor(final: joinWords(igorFinal, text), partial: "")
      }
    case .interrupted:
      log("call_bridge", ["kind": "interrupted"])
      cutOffPending = true
      deps.audio.flush()
      closeLarryRow()
    case .turnEnd:
      closeLarryRow()
      promoteIgor()
      clearSent()
    case .toolCall(let question):
      promoteIgor()
      closeLarryRow()
      log("call_bridge", ["kind": "tool_call", "question": question])
      toolRowId = addRow(.tool, question.isEmpty ? "asking Larry …" : "asking Larry: \(question) …")
    case .consultProgress(_, let text):
      if !text.isEmpty { setTool(text) }
    case .toolResult(let ok, let answer):
      log("call_bridge", ["kind": "tool_result", "ok": ok, "answer": answer])
      setTool(ok ? (answer.isEmpty ? "answered" : answer) : "no answer")
      toolRowId = nil
    case .injected(let text):
      closeLarryRow()
      log("call_bridge", ["kind": "injected", "text": text])
      _ = addRow(.note, "added context: \(text)")
    case .warning(let message):
      log("call_bridge", ["kind": "warning", "message": message])
      closeLarryRow()
      _ = addRow(.note, "warning: \(message)")
    case .error(let message):
      log("call_bridge", ["kind": "error", "message": message])
      bridgeProblem = message
      setProblem(message)
    case .vendorClosed(let kind, let message):
      log("call_bridge", ["kind": "vendor_closed", "vendor_kind": kind, "message": message])
      finish(message.isEmpty ? (kind == "quota" ? "vendor quota exhausted" : "vendor hung up") : message, badly: true)
    case .closed(let reason):
      log("call_bridge", ["kind": "closed", "reason": reason])
      finish(reason, badly: false)
    }
  }

  private func onReady(outRate: Double, backend: String, session: String) {
    guard snapshot.state == .connecting else { return }
    log("call_ready", ["out_rate": outRate, "backend": backend, "session": session])
    update {
      $0.state = .live
      $0.startedAt = deps.scheduler.now
    }
    deps.audio.openPlayback(outRate: outRate)
    scheduleStats()
    send(CallProtocol.sttStartFrame(), frame: "stt_start")
    let call = generation
    // the samples handler and the failure handler, kept apart.
    // swift-format-ignore: OnlyOneTrailingClosureArgument
    deps.audio.startMic({ [weak self] samples, rate in
      guard let self, call == self.generation else { return }
      self.onMicBuffer(samples, rate)
    }) { [weak self] error in
      guard let self, call == self.generation else { return }
      if let error {
        // The call goes on — Larry may still be heard — but say so. #441, story 208: a mic that failed to open is
        // one that never delivers, so the same reset-then-redial watch runs from here.
        self.log("call_mic", ["action": "open", "ok": false, "message": describe(error)])
        let problem = "microphone failed: \(describe(error))"
        self.micOpenProblem = problem
        self.setProblem(problem)
        self.armFirstFrameWatch()
        return
      }
      self.log("call_mic", ["action": "open", "ok": true])
      self.armFirstFrameWatch()
    }
  }

  /// Every five seconds while live (#106): what came down the socket against what the speaker rendered, and what
  /// went up. And Tony's words arriving as text with no audio behind them is the bridge, not the phone.
  private func scheduleStats() {
    statsTimer?.cancel()
    statsTimer = deps.scheduler.after(Self.statsEveryMs) { [weak self] in
      guard let self, self.snapshot.state == .live else { return }
      let stats = self.deps.audio.stats()
      self.log(
        "call_stats",
        [
          "rx_kb": (Double(self.bytesReceived) / 1024).rounded(), "rx_frames": self.framesReceived,
          "mic_frames": self.framesSent, "played_s": stats?.playedS ?? 0, "scheduled_s": stats?.scheduledS ?? 0,
          "pending_s": stats?.pendingS ?? 0, "clock_running": stats?.clockRunning ?? false,
          "playback": PlaybackStats.describe(stats), "odd_frames": stats?.oddFrames ?? 0,
          "underruns": stats?.underruns ?? 0,
        ])
      let absent = CallWatchdog.audioAbsent(
        now: self.deps.scheduler.now, lastTextAt: self.lastTextAt, lastAudioAt: self.lastAudioAt)
      if absent, self.snapshot.problem == nil {
        self.setProblem(CallWatchdog.audioNotArriving)
      } else if !absent, self.snapshot.problem == CallWatchdog.audioNotArriving {
        self.setProblem(nil)
      }
      self.scheduleStats()
    }
  }

  private func armFirstFrameWatch() {
    guard snapshot.state == .live else { return }
    firstFrameTimer?.cancel()
    micOpenedAt = deps.scheduler.now
    firstFrameDeadline = deps.audio.micStartupDeadline()
    scheduleFirstFrameWatch()
  }

  // #423, story 204: recheck before each reset/redial; the route may have begun settling meanwhile.
  private func scheduleFirstFrameWatch() {
    log(
      "call_mic",
      ["action": "first_frame_watch", "deadline_s": firstFrameDeadline.ms / 1000, "why": firstFrameDeadline.why])
    let remaining = max(0, micOpenedAt + firstFrameDeadline.ms - deps.scheduler.now)
    firstFrameTimer = deps.scheduler.after(remaining) { [weak self] in self?.onNoFirstFrame() }
  }

  private func onNoFirstFrame() {
    firstFrameTimer = nil
    guard snapshot.state == .live, micBuffers == 0 else { return }
    let current = firstFrameDeadline.extended(by: deps.audio.micStartupDeadline())
    if current.ms > firstFrameDeadline.ms {
      firstFrameDeadline = current
      if deps.scheduler.now < micOpenedAt + current.ms {
        scheduleFirstFrameWatch()
        return
      }
    }
    if !audioReset {
      audioReset = true
      log(
        "call_heal",
        [
          "action": "reset_audio", "why": "no mic buffer within \(firstFrameDeadline.ms / 1000) s of the mic opening",
          "deadline_s": firstFrameDeadline.ms / 1000, "deadline_why": firstFrameDeadline.why,
        ])
      let call = generation
      deps.audio.restartMic { [weak self] error in
        guard let self, call == self.generation else { return }
        if let error {
          // #441: a failed reset goes on to the redial; it used to end the ladder here.
          self.log("call_heal", ["action": "reset_audio", "ok": false, "message": describe(error)])
        }
        self.armFirstFrameWatch()
      }
      return
    }
    if !redialed, let backend = snapshot.backend {
      redialed = true
      let voice = snapshot.voice
      let stt = snapshot.stt
      log(
        "call_heal",
        [
          "action": "redial", "why": "still no mic buffer after the reset", "deadline_s": firstFrameDeadline.ms / 1000,
          "deadline_why": firstFrameDeadline.why,
        ])
      sendDiagnostics(why: "redial")
      stop()
      start(backend, voice: voice, stt: stt)
      return
    }
    log("call_heal", ["action": "give_up", "why": "still no mic buffer after the redial"])
    setProblem(Self.micSilent)
  }

  private func onMicBuffer(_ samples: [Float], _ sampleRate: Double) {
    guard snapshot.state == .live else { return }
    micBuffers += 1
    if micBuffers == 1 {
      firstFrameTimer?.cancel()
      firstFrameTimer = nil
      redialed = false  // this burst delivered; the next dead call may redial again
      if let p = micOpenProblem {
        micOpenProblem = nil
        if snapshot.problem == p { setProblem(nil) }
      }
    }
    // Heard even while muted: "is my mic working" and "am I muted" are different questions.
    onLevel?(PCM.micLevel(samples))
    watchForZeros(samples)
    if snapshot.muted { return }
    socket?.send(data: PCM.encodeMicFrame(samples, sampleRate: sampleRate))
    lastTxAt = deps.scheduler.now
    framesSent += 1
    if framesSent == 1 {
      log("call_mic", ["action": "first_frame", "samples": samples.count, "rate": sampleRate])
    }
    if !probeSent {
      probeSent = true
      probeToken += 1
      send(CallProtocol.micProbeFrame(token: probeToken), frame: "mic_probe", ["token": probeToken])
      probeTimer = deps.scheduler.after(Self.micAckMs) { [weak self] in self?.onProbeMissed() }
    }
  }

  /// What came down and what the speaker has of it, for a heal line: rx frames, then scheduled, played and pending.
  private func playbackFields() -> [String: Any] {
    let stats = deps.audio.stats()
    return [
      "rx_frames": framesReceived, "scheduled_s": stats?.scheduledS ?? 0, "played_s": stats?.playedS ?? 0,
      "pending_s": stats?.pendingS ?? 0,
    ]
  }

  /// The first call after launch used to send exact silence for its whole length (#88). A first second that is
  /// zero to the sample re-arms the mic once; zeros after that are said.
  private func watchForZeros(_ samples: [Float]) {
    guard PCM.isExactSilence(samples) else {
      if zeroRun >= Self.zeroBuffersBeforeRearm || awaitingSoundAfterRearm {
        log("call_mic", ["action": "audio_back", "buffers": micBuffers])
      }
      awaitingSoundAfterRearm = false
      micHeard = true
      zeroRun = 0
      if snapshot.problem == Self.micSilent { setProblem(nil) }
      return
    }
    zeroRun += 1
    guard zeroRun == Self.zeroBuffersBeforeRearm else { return }
    if !zeroRearmed {
      zeroRearmed = true
      zeroRun = 0
      log(
        "call_heal",
        [
          "action": "rearm_mic", "why": "\(Self.zeroBuffersBeforeRearm) buffers of exact zeros", "buffers": micBuffers,
          "heard_before": micHeard,
        ].merging(playbackFields()) { mine, _ in mine })
      let call = generation
      deps.audio.restartMic { [weak self] error in
        // Codex on #365: a hang-up keeps the generation, so a rebuild that finishes after it is not this call's.
        guard let self, call == self.generation, self.snapshot.state == .live else { return }
        // #364: the queue again once the engine is back, so what the restart dropped is the difference.
        guard let error else {
          // Codex on #365: armed once the rebuilt graph is up, so a buffer the old tap had queued cannot claim it.
          self.awaitingSoundAfterRearm = true
          self.log(
            "call_heal", ["action": "rearm_mic", "ok": true].merging(self.playbackFields()) { mine, _ in mine })
          return
        }
        self.log("call_heal", ["action": "rearm_mic", "ok": false, "message": describe(error)])
        self.setProblem("microphone failed: \(describe(error))")
      }
      return
    }
    log("call_mic", ["action": "zeros", "why": "still exact zeros after the re-arm"])
    setProblem(Self.micSilent)
  }

  private func onProbeMissed() {
    probeTimer = nil
    guard snapshot.state == .live else { return }
    log(
      "call_heal",
      [
        "action": rearmed ? "mic_not_reaching" : "rearm_mic", "why": "mic_ack missed", "mic_frames": framesSent,
        "buffers": micBuffers,
      ])
    if !rearmed {
      // Once. Two silent capture graphs in a row is a fact, not a hiccup.
      rearmed = true
      probeSent = false
      let call = generation
      deps.audio.restartMic { [weak self] error in
        // As the zero-run rearm (Codex on #365): a failure after the hang-up is not this call's problem.
        guard let self, call == self.generation, self.snapshot.state == .live, let error else { return }
        self.setProblem("microphone failed: \(describe(error))")
      }
      return
    }
    sendDiagnostics(why: "mic_ack timeout")
    setProblem(Self.micNotReaching)
  }

  private func clearProbe() {
    probeTimer?.cancel()
    probeTimer = nil
    if snapshot.problem == Self.micNotReaching { setProblem(nil) }
  }

  // MARK: - the audio layer's verdict

  /// Shown while it stands; when it lifts, the bridge's own error (if any) comes back.
  private func onAudioHealth(_ problem: String?) {
    let previous = audioProblem
    audioProblem = problem
    if let problem {
      setProblem(problem)
    } else if let previous, snapshot.problem == previous {
      setProblem(bridgeProblem)
    }
  }

  private func setProblem(_ problem: String?) {
    guard snapshot.problem != problem else { return }
    log("call_problem", ["problem": problem ?? ""])
    update { $0.problem = problem }
  }

  // MARK: - captions

  private func addRow(_ who: CaptionWho, _ text: String, pending: Bool = false) -> Int {
    let id = nextRowId
    nextRowId += 1
    update { $0.captions.append(CaptionRow(id: id, who: who, text: text, pending: pending)) }
    return id
  }

  private func setRow(_ id: Int, _ change: (inout CaptionRow) -> Void) {
    update { s in
      if let i = s.captions.firstIndex(where: { $0.id == id }) { change(&s.captions[i]) }
    }
  }

  private func row(_ id: Int?) -> CaptionRow? {
    guard let id else { return nil }
    return snapshot.captions.first { $0.id == id }
  }

  private func setIgor(final: String, partial: String) {
    igorFinal = final
    let text = joinWords(final, partial)
    if text.isEmpty {
      if let id = igorRowId { setRow(id) { $0.text = "" } }
      return
    }
    if let id = igorRowId {
      setRow(id) {
        $0.text = text
        $0.pending = true
      }
    } else {
      igorRowId = addRow(.igor, text, pending: true)
    }
  }

  /// Igor's pending row becomes a settled one, marked sent when the bridge sent it to Larry; an empty pending row
  /// is dropped.
  private func promoteIgor(sent: Bool = false) {
    let id = igorRowId
    igorRowId = nil
    igorFinal = ""
    guard let row = row(id) else { return }
    if row.text.isEmpty {
      update { $0.captions.removeAll { $0.id == row.id } }
      return
    }
    setRow(row.id) {
      $0.pending = false
      $0.sent = sent
    }
    if sent { restateWindow = true }
    log("call_caption", ["who": "igor", "text": row.text, "sent": sent])
  }

  /// Larry answered, or the turn or the call ended: nothing is waiting on him any more.
  private func clearSent() {
    guard snapshot.captions.contains(where: { $0.sent }) else { return }
    update { s in
      for i in s.captions.indices where s.captions[i].sent { s.captions[i].sent = false }
    }
  }

  private func appendLarry(_ text: String) {
    guard !text.isEmpty else { return }
    if let row = row(larryRowId) {
      setRow(row.id) { $0.text = joinWords(row.text, text) }
    } else {
      larryRowId = addRow(.larry, text)
    }
  }

  /// Larry's row is finished: the next fragment starts a new one. The finished row goes in the log once.
  private func closeLarryRow() {
    if let row = row(larryRowId) {
      log("call_caption", ["who": "larry", "text": row.text])
      lastLarryRow = row.text
    }
    larryRowId = nil
  }

  private func setTool(_ text: String) {
    if let id = toolRowId, row(id) != nil {
      setRow(id) { $0.text = text }
    } else {
      toolRowId = addRow(.tool, text)
    }
  }

  // MARK: - lifecycle

  private func resetForCall(backend: CallBackend, voice: CallVoice, stt: CallSTT) {
    generation += 1
    var next = CallSnapshot()
    next.state = .connecting
    next.backend = backend
    next.voice = voice
    // A voice-model call does not record a leftover Direct pick (#556).
    next.stt = CallSTT.hasPick(backend) ? stt : .default
    next.muted = snapshot.muted
    snapshot = next
    igorFinal = ""
    igorRowId = nil
    restateWindow = false
    larryRowId = nil
    toolRowId = nil
    probeSent = false
    rearmed = false
    probeTimer?.cancel()
    probeTimer = nil
    socketOpen = false
    framesSent = 0
    framesReceived = 0
    bytesReceived = 0
    lastAudioAt = 0
    lastTextAt = 0
    lastLarryRow = ""
    cutOffPending = false
    lastRxAt = 0
    lastTxAt = 0
    audioProblem = nil
    bridgeProblem = nil
    statsTimer?.cancel()
    statsTimer = nil
    zeroRun = 0
    zeroRearmed = false
    micHeard = false
    awaitingSoundAfterRearm = false
    micBuffers = 0
    audioReset = false
    micOpenProblem = nil
    firstFrameTimer?.cancel()
    firstFrameTimer = nil
  }

  private func finish(_ reason: String, badly: Bool) {
    guard snapshot.isActive else { return }
    closeLarryRow()
    promoteIgor()
    clearSent()
    let stats = deps.audio.stats()
    log(
      "call_ended",
      [
        "reason": reason, "text": CallProtocol.endingText(reason), "badly": badly, "mic_frames": framesSent,
        "rx_frames": framesReceived, "rx_kb": (Double(bytesReceived) / 1024).rounded(),
        "played_s": stats?.playedS ?? 0, "scheduled_s": stats?.scheduledS ?? 0,
        "playback": PlaybackStats.describe(stats), "odd_frames": stats?.oddFrames ?? 0,
        "underruns": stats?.underruns ?? 0,
      ])
    statsTimer?.cancel()
    statsTimer = nil
    clearProbe()
    firstFrameTimer?.cancel()
    firstFrameTimer = nil
    socketOpen = false
    if let socket {
      self.socket = nil
      socket.onOpen = nil
      socket.onText = nil
      socket.onBinary = nil
      socket.onClose = nil
      socket.close()
    }
    update {
      $0.state = .ended
      $0.endedReason = reason
      $0.endedBadly = badly
    }
    deps.audio.stop()
    onLevel?(0)
  }

  private func update(_ change: (inout CallSnapshot) -> Void) {
    change(&snapshot)
    emit()
  }

  private func emit() { onChange?(snapshot) }

  private func log(_ type: String, _ fields: [String: Any]) { deps.log(type, fields) }
}

func joinWords(_ a: String, _ b: String) -> String {
  if a.isEmpty { return b }
  if b.isEmpty { return a }
  return "\(a) \(b)"
}

/// An error in words: a system error's own sentence, a Swift error's description.
public func describe(_ error: Error) -> String {
  if let e = error as? LocalizedError, let d = e.errorDescription { return d }
  if type(of: error) is NSError.Type { return (error as NSError).localizedDescription }
  return String(describing: error)
}
