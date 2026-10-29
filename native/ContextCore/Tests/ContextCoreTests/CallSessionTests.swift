import XCTest

@testable import ContextCore

/// Time moved by hand: `advance` fires every timer that falls due, in order, including ones scheduled meanwhile.
final class FakeScheduler: CallScheduler {
  final class Timer: CallTimer {
    let due: Double
    let seq: Int
    let block: () -> Void
    var cancelled = false
    init(due: Double, seq: Int, block: @escaping () -> Void) {
      self.due = due
      self.seq = seq
      self.block = block
    }
    func cancel() { cancelled = true }
  }

  var now: Double = 1_000_000
  private var timers: [Timer] = []
  private var seq = 0

  func after(_ ms: Double, _ block: @escaping () -> Void) -> CallTimer {
    seq += 1
    let t = Timer(due: now + ms, seq: seq, block: block)
    timers.append(t)
    return t
  }

  func advance(_ ms: Double) {
    let end = now + ms
    while let next = timers.filter({ !$0.cancelled && $0.due <= end }).min(by: { ($0.due, $0.seq) < ($1.due, $1.seq) })
    {
      timers.removeAll { $0 === next }
      now = next.due
      next.block()
    }
    now = end
  }
}

/// Records what was sent and lets the test play the bridge.
final class FakeSocket: BridgeSocket {
  var onOpen: (() -> Void)?
  var onText: ((String) -> Void)?
  var onBinary: ((Data) -> Void)?
  var onClose: ((String) -> Void)?
  var texts: [String] = []
  var binaries: [Data] = []
  /// Text and binary in the order sent: "t" or "b".
  var order: [String] = []
  var closed = false

  func send(text: String) {
    guard !closed else { return }
    texts.append(text)
    order.append("t")
  }
  func send(data: Data) {
    guard !closed else { return }
    binaries.append(data)
    order.append("b")
  }
  func close() { closed = true }

  func open() { onOpen?() }
  func say(_ m: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: m)
    onText?(String(decoding: data, as: UTF8.self))
  }
  func speak(_ bytes: Int = 480) { onBinary?(Data(count: bytes)) }
  func drop() { onClose?("network") }

  var frames: [[String: Any]] {
    texts.map { try! JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
  }
  var types: [String] { frames.map { $0["type"] as? String ?? "" } }
}

struct Boom: Error, CustomStringConvertible {
  let description: String
  init(_ d: String) { description = d }
}

final class FakeAudio: CallAudio {
  var startupDeadline = MicStartupDeadline()
  func micStartupDeadline() -> MicStartupDeadline { startupDeadline }
  var onHealth: ((String?) -> Void)?
  var calls: [String] = []
  var prepareError: Error?
  var startMicError: Error?
  var restartError: Error?
  var onBuffer: (([Float], Double) -> Void)?
  var firstOnBuffer: (([Float], Double) -> Void)?
  var restarts = 0
  var played: [Data] = []
  var flushes = 0
  var stops = 0
  var openedAt: [Double] = []
  var statsValue: PlaybackStats?
  /// Holds `restartMic`'s completion until a test calls it, as the real engine's audio queue does.
  var deferRestart = false
  var pendingRestart: ((Error?) -> Void)?

  func prepare(_ done: @escaping (Error?) -> Void) {
    calls.append("prepare")
    done(prepareError)
  }
  func startMic(_ onBuffer: @escaping ([Float], Double) -> Void, _ done: @escaping (Error?) -> Void) {
    calls.append("startMic")
    self.onBuffer = onBuffer
    if firstOnBuffer == nil { firstOnBuffer = onBuffer }
    done(startMicError)
  }
  func restartMic(_ done: @escaping (Error?) -> Void) {
    restarts += 1
    if deferRestart { pendingRestart = done } else { done(restartError) }
  }
  func openPlayback(outRate: Double) { openedAt.append(outRate) }
  func play(_ pcm: Data) { played.append(pcm) }
  func flush() { flushes += 1 }
  func stop() { stops += 1 }
  func stats() -> PlaybackStats? { statsValue }

  /// The engine delivering one buffer.
  func mic(_ samples: Int = 480, rate: Double = 48000, value: Float = 0) {
    onBuffer?([Float](repeating: value, count: samples), rate)
  }
}

final class CallHarness {
  let socket = FakeSocket()
  let audio = FakeAudio()
  let clock = FakeScheduler()
  var sockets: [FakeSocket] = []
  var connects: [String] = []
  var connectError: Error?
  var events: [(String, [String: Any])] = []
  var states: [CallSnapshot] = []
  var levels: [Double] = []
  var settings = CallSettings()
  var session: CallSession!

  init(build: String = "", diagnostics: Bool = false) {
    sockets = [socket]
    session = make(build: build, diagnostics: diagnostics)
  }

  private func make(build: String, diagnostics: Bool) -> CallSession {
    var deps = CallSessionDeps(
      connect: { [unowned self] url in
        self.connects.append(url)
        if let e = self.connectError { throw e }
        return self.sockets[min(self.connects.count - 1, self.sockets.count - 1)]
      },
      audio: audio, scheduler: clock,
      log: { [unowned self] type, fields in self.events.append((type, fields)) },
      diagnostics: diagnostics ? { [unowned self] in self.events.map { $0.0 }.joined(separator: "\n") } : nil,
      build: build)
    deps.callSettings = { [unowned self] in self.settings }
    let s = CallSession(deps: deps, url: "wss://h/bridge")
    s.onChange = { [unowned self] in self.states.append($0) }
    s.onLevel = { [unowned self] in self.levels.append($0) }
    return s
  }

  /// The socket the next connect returns.
  @discardableResult func nextSocket() -> FakeSocket {
    let s = FakeSocket()
    sockets.append(s)
    return s
  }

  func goLive(_ backend: CallBackend = .gemini, voice: CallVoice = .tony) {
    session.start(backend, voice: voice)
    socket.open()
    socket.say(["type": "ready", "out_rate": 24000, "backend": backend.rawValue, "session": "s1"])
  }

  func eventTypes() -> [String] { events.map { $0.0 } }
  func last(_ type: String) -> [String: Any]? { events.last { $0.0 == type }?.1 }

  var texts: [String] {
    session.snapshot.captions.map { "\($0.who.rawValue)\($0.pending ? "?" : "")\($0.sent ? "!" : ""):\($0.text)" }
  }
}

final class CallSessionConnectingTests: XCTestCase {
  func testPreparesAudioBeforeTheSocketThenSendsExactlyOneStartFrameOnOpen() {
    let t = CallHarness()
    t.session.start(.eleven)
    XCTAssertEqual(t.audio.calls, ["prepare"])
    XCTAssertEqual(t.connects, ["wss://h/bridge"])
    XCTAssertEqual(t.session.snapshot.state, .connecting)
    XCTAssertTrue(t.socket.texts.isEmpty)
    t.socket.open()
    XCTAssertEqual(t.socket.frames.count, 1)
    let start = t.socket.frames[0]
    XCTAssertEqual(start["type"] as? String, "start")
    XCTAssertEqual(start["backend"] as? String, "eleven")
    XCTAssertEqual(start["voice"] as? String, "")
    XCTAssertEqual(start["model"] as? String, "")
    XCTAssertEqual(start["client"] as? String, "context-grabber")
    XCTAssertEqual(t.eventTypes().prefix(4), ["call_start", "call_prepare", "call_socket", "call_sent"])
  }

  func testIntroducesItselfWithTheBuild() {
    let t = CallHarness(build: "abc1234")
    t.session.start(.gemini)
    t.socket.open()
    XCTAssertEqual(t.socket.frames[0]["build"] as? String, "abc1234")
    XCTAssertEqual(t.last("call_start")?["build"] as? String, "abc1234")
  }

  func testDoesNotOpenTheMicBeforeReady() {
    let t = CallHarness()
    t.session.start(.gemini)
    t.socket.open()
    XCTAssertFalse(t.audio.calls.contains("startMic"))
    XCTAssertTrue(t.audio.openedAt.isEmpty)
  }

  func testASecondStartWhileConnectingIsANoOp() {
    let t = CallHarness()
    t.session.start(.gemini)
    t.session.start(.eleven)
    XCTAssertEqual(t.connects.count, 1)
    XCTAssertEqual(t.session.snapshot.backend, .gemini)
    XCTAssertEqual(t.last("call_ignored")?["state"] as? String, "connecting")
  }

  func testAnAudioSessionThatCannotBePreparedEndsTheCallBeforeAnySocket() {
    let t = CallHarness()
    t.audio.prepareError = Boom("mic denied")
    t.session.start(.gemini)
    XCTAssertTrue(t.connects.isEmpty)
    XCTAssertEqual(t.session.snapshot.state, .ended)
    XCTAssertTrue(t.session.snapshot.endedBadly)
    XCTAssertEqual(t.session.snapshot.endedReason, "microphone unavailable: mic denied")
    XCTAssertEqual(t.last("call_prepare")?["ok"] as? Bool, false)
  }

  func testASocketThatCannotBeMadeIsAConnectionLost() {
    let t = CallHarness()
    t.connectError = Boom("no route")
    t.session.start(.gemini)
    XCTAssertEqual(t.session.snapshot.endedReason, "connection lost: no route")
    XCTAssertTrue(t.session.snapshot.endedBadly)
  }

  func testASocketThatDropsWhileConnectingIsAConnectionLost() {
    let t = CallHarness()
    t.session.start(.gemini)
    t.socket.drop()
    XCTAssertEqual(t.session.snapshot.state, .ended)
    XCTAssertEqual(t.session.snapshot.endedReason, CallProtocol.connectionLost)
    XCTAssertTrue(t.session.snapshot.endedBadly)
    XCTAssertEqual(t.audio.stops, 1)
    XCTAssertEqual(t.last("call_socket")?["action"] as? String, "lost")
  }

  // #440, #439, story 209: a lost socket says how long the line had been quiet each way.
  func testALostSocketSaysHowLongSinceTheLastFrameInAndOut() {
    let t = CallHarness()
    t.goLive()
    t.clock.advance(1000)
    t.socket.speak()
    t.clock.advance(500)
    t.audio.mic()
    t.clock.advance(2000)
    t.socket.drop()
    let lost = t.last("call_socket")
    XCTAssertEqual(lost?["action"] as? String, "lost")
    XCTAssertEqual(lost?["since_rx_ms"] as? Double, 2500)
    XCTAssertEqual(lost?["since_tx_ms"] as? Double, 2000)
    XCTAssertEqual(lost?["live_ms"] as? Double, 3500)
  }
}

final class CallSessionMicTests: XCTestCase {
  func testReadyGoesLivePlaybackAtTheNamedRateSttStartThenTheMic() {
    let t = CallHarness()
    t.goLive(.eleven)
    XCTAssertEqual(t.session.snapshot.state, .live)
    XCTAssertEqual(t.session.snapshot.startedAt, 1_000_000)
    XCTAssertEqual(t.audio.openedAt, [24000])
    XCTAssertEqual(t.socket.frames.last?["type"] as? String, "stt_start")
    XCTAssertEqual(t.socket.frames.last?["rate"] as? Int, 16000)
    XCTAssertEqual(t.audio.calls.filter { $0 == "startMic" }.count, 1)
    XCTAssertEqual(t.last("call_ready")?["out_rate"] as? Double, 24000)
  }

  func testAMicBufferBecomesA16kPcm16FrameFollowedOnceByAProbe() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic(4800, rate: 48000)
    t.audio.mic(4800, rate: 48000)
    XCTAssertEqual(t.socket.binaries.count, 2)
    XCTAssertEqual(t.socket.binaries[0].count, 1600 * 2)
    let probes = t.socket.frames.filter { $0["type"] as? String == "mic_probe" }
    XCTAssertEqual(probes.count, 1)
    XCTAssertEqual(probes[0]["token"] as? Int, 1)
    // The bridge's own order: binary first, then the probe that names it.
    let firstBinary = t.socket.order.firstIndex(of: "b")!
    let probeIndex = t.socket.order.indices.filter { t.socket.order[$0] == "t" }[
      t.socket.types.firstIndex(of: "mic_probe")!]
    XCTAssertLessThan(firstBinary, probeIndex)
    XCTAssertEqual(t.last("call_mic")?["action"] as? String, "first_frame")
  }

  /// The review on #365: the probe's rearm failing after the hang-up sets no problem on the ended call.
  func testAProbeRearmThatFailsAfterTheHangUpIsIgnored() {
    let t = CallHarness()
    t.goLive()
    t.audio.deferRestart = true
    t.audio.mic()
    t.clock.advance(CallSession.micAckMs)
    XCTAssertEqual(t.audio.restarts, 1)
    t.session.stop()
    let ended = t.session.snapshot
    t.audio.pendingRestart?(NSError(domain: "test", code: 1))
    XCTAssertEqual(t.session.snapshot.problem, ended.problem, "no problem set on the ended call")
  }

  func testAnUnansweredProbeRearmsOnceThenSaysTheMicIsNotReachingLarry() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic()
    t.clock.advance(CallSession.micAckMs)
    XCTAssertEqual(t.audio.restarts, 1)
    XCTAssertNil(t.session.snapshot.problem)
    // The re-armed graph sends again and probes again…
    t.audio.mic()
    XCTAssertEqual(t.socket.types.filter { $0 == "mic_probe" }.count, 2)
    t.clock.advance(CallSession.micAckMs)
    XCTAssertEqual(t.audio.restarts, 1)
    XCTAssertEqual(t.session.snapshot.problem, CallSession.micNotReaching)
    // …and a late ack clears it.
    t.socket.say(["type": "mic_ack", "token": 2])
    XCTAssertNil(t.session.snapshot.problem)
  }

  func testAnAckForAnEarlierProbeDoesNotVouchForTheRearmedMic() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic()
    t.clock.advance(CallSession.micAckMs)
    XCTAssertEqual(t.audio.restarts, 1)
    t.audio.mic()  // probe 2 is waiting
    t.socket.say(["type": "mic_ack", "token": 1])  // stale
    XCTAssertEqual(t.last("call_ack")?["stale"] as? Bool, true)
    t.clock.advance(CallSession.micAckMs)
    XCTAssertEqual(t.session.snapshot.problem, CallSession.micNotReaching)
  }

  func testAnAckInTimeMeansNoRearm() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic()
    t.socket.say(["type": "mic_ack", "token": 1])
    t.clock.advance(CallSession.micAckMs * 2)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertNil(t.session.snapshot.problem)
  }

  func testAMicThatFailsToStartLeavesTheCallLiveAndReportsTheProblem() {
    let t = CallHarness()
    t.audio.startMicError = Boom("no input")
    t.goLive()
    XCTAssertEqual(t.session.snapshot.state, .live)
    XCTAssertEqual(t.session.snapshot.problem, "microphone failed: no input")
  }

  // #441, story 208: the engine refused to start ('what'), the mic never opened, and the call sat silent for 30 s
  // with no heal until the bridge hung up (client_gone). A mic that fails to open is one that never delivers.
  func testAMicThatFailsToOpenGetsTheResetThenTheRedial() {
    let t = CallHarness()
    t.audio.startMicError = Boom("avfaudio error 2003329396")
    t.goLive(.eleven, voice: .igor)
    XCTAssertEqual(t.session.snapshot.problem, "microphone failed: avfaudio error 2003329396")
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.audio.restarts, 1)
    t.nextSocket()
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.connects.count, 2)
    XCTAssertEqual(t.session.snapshot.state, .connecting)
    XCTAssertEqual(
      t.events.filter { $0.0 == "call_heal" }.map { $0.1["action"] as? String ?? "" }, ["reset_audio", "redial"])
  }

  func testAResetThatFailsGoesOnToTheRedial() {
    let t = CallHarness()
    t.audio.startMicError = Boom("no input")
    t.audio.restartError = Boom("still no input")
    t.goLive()
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.audio.restarts, 1)
    t.nextSocket()
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.connects.count, 2)
  }

  func testABufferAfterTheResetClearsMicrophoneFailed() {
    let t = CallHarness()
    t.audio.startMicError = Boom("no input")
    t.goLive()
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.audio.restarts, 1)
    t.audio.mic()
    XCTAssertNil(t.session.snapshot.problem)
    t.clock.advance(CallSession.firstFrameMs * 3)
    XCTAssertEqual(t.connects.count, 1)
  }
}

final class CallSessionNoFirstFrameTests: XCTestCase {
  func testResetsTheAudioAfterOneAndAHalfSecondsThenRedialsOnceSendingTheDumpFirst() {
    let t = CallHarness(build: "abc (x)", diagnostics: true)
    t.session.start(.eleven, voice: .igor)
    t.socket.open()
    t.socket.say(["type": "ready", "out_rate": 16000])
    XCTAssertEqual(t.audio.restarts, 0)
    t.clock.advance(CallSession.firstFrameMs)
    XCTAssertEqual(t.audio.restarts, 1)
    // still nothing after the reset → redial: the dump, stop, a new socket, the same backend and voice
    let second = t.nextSocket()
    t.clock.advance(CallSession.firstFrameMs)
    let diag = t.socket.frames.first { $0["type"] as? String == "diagnostics" }
    XCTAssertEqual(diag?["build"] as? String, "abc (x)")
    XCTAssertTrue((diag?["text"] as? String ?? "").contains("call_heal"))
    XCTAssertEqual(t.socket.types.last, "stop")
    XCTAssertEqual(t.connects.count, 2)
    XCTAssertEqual(t.session.snapshot.state, .connecting)
    XCTAssertEqual(t.session.snapshot.backend, .eleven)
    XCTAssertEqual(t.session.snapshot.voice, .igor)
    second.open()
    XCTAssertEqual(second.frames[0]["voice"] as? String, "Nvd5I2HGnOWHNU0ijNEy")
    XCTAssertEqual(
      t.events.filter { $0.0 == "call_heal" }.map { $0.1["action"] as? String ?? "" }, ["reset_audio", "redial"])
  }

  func testABufferInTimeCancelsTheWatchAndALiveCallNeverRedials() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic()
    t.socket.say(["type": "mic_ack", "token": 1])
    t.clock.advance(CallSession.firstFrameMs * 3)
    XCTAssertEqual(t.audio.restarts, 0)
    XCTAssertEqual(t.connects.count, 1)
  }

  func testRedialsAtMostOncePerDeadBurstThenReportsSilence() {
    let t = CallHarness()
    t.goLive()
    t.clock.advance(CallSession.firstFrameMs)  // reset
    let second = t.nextSocket()
    t.clock.advance(CallSession.firstFrameMs)  // redial
    second.open()
    second.say(["type": "ready", "out_rate": 16000])
    t.clock.advance(CallSession.firstFrameMs)  // reset again on the redialed call
    t.clock.advance(CallSession.firstFrameMs)  // would redial — but no
    XCTAssertEqual(t.connects.count, 2)
    XCTAssertEqual(t.session.snapshot.problem, CallSession.micSilent)
  }
}

final class CallSessionZerosTests: XCTestCase {
  private func zeros(_ t: CallHarness, _ n: Int) {
    for _ in 0..<n { t.audio.mic(480) }
  }

  func testRearmsTheMicOnceAfterASecondOfZeros() {
    let t = CallHarness()
    t.goLive()
    zeros(t, CallSession.zeroBuffersBeforeRearm - 1)
    XCTAssertEqual(t.audio.restarts, 0)
    zeros(t, 1)
    XCTAssertEqual(t.audio.restarts, 1)
    XCTAssertNil(t.session.snapshot.problem)
    t.audio.mic(480, value: 0.2)
    XCTAssertNil(t.session.snapshot.problem)
  }

  func testReportsSilenceIfZerosContinueAfterTheRearmAndClearsWhenAudioReturns() {
    let t = CallHarness()
    t.goLive()
    zeros(t, CallSession.zeroBuffersBeforeRearm)
    zeros(t, CallSession.zeroBuffersBeforeRearm)
    XCTAssertEqual(t.audio.restarts, 1)
    XCTAssertEqual(t.session.snapshot.problem, CallSession.micSilent)
    t.audio.mic(480, value: 0.2)
    XCTAssertNil(t.session.snapshot.problem)
  }

  /// #364: the heal says whether the mic was ever live and what playback held, before the restart and after it.
  func testTheRearmSaysWhatTheMicAndThePlaybackHeld() throws {
    let t = CallHarness()
    t.goLive()
    t.audio.statsValue = PlaybackStats(scheduledS: 0.47, playedS: 0.3, clockRunning: true, pendingS: 0.1)
    zeros(t, CallSession.zeroBuffersBeforeRearm)
    let heals = t.events.filter { $0.0 == "call_heal" && $0.1["action"] as? String == "rearm_mic" }.map(\.1)
    XCTAssertEqual(heals.count, 2, "the heal, then the queue once the engine is back")
    let before = try XCTUnwrap(heals.first)
    XCTAssertEqual(before["buffers"] as? Int, CallSession.zeroBuffersBeforeRearm)
    XCTAssertEqual(before["heard_before"] as? Bool, false)
    XCTAssertEqual(before["scheduled_s"] as? Double, 0.47)
    XCTAssertEqual(before["pending_s"] as? Double, 0.1)
    XCTAssertNotNil(before["rx_frames"] as? Int)
    let after = try XCTUnwrap(heals.last)
    XCTAssertEqual(after["ok"] as? Bool, true)
    XCTAssertEqual(after["played_s"] as? Double, 0.3)

    t.audio.mic(480, value: 0.2)
    let back = t.events.filter { $0.0 == "call_mic" && $0.1["action"] as? String == "audio_back" }.map(\.1)
    XCTAssertEqual(back.first?["buffers"] as? Int, CallSession.zeroBuffersBeforeRearm + 1, "the first sound, by buffer")
  }

  /// Codex on #365: a sound buffer the old tap queued before the restart finished is not the rearm's recovery.
  func testOnlySoundAfterTheRestartFinishesCountsAsBack() {
    let t = CallHarness()
    t.goLive()
    t.audio.deferRestart = true
    zeros(t, CallSession.zeroBuffersBeforeRearm)
    t.audio.mic(480, value: 0.2)  // from the old tap, while the graph rebuilds
    func backs() -> [[String: Any]] {
      t.events.filter { $0.0 == "call_mic" && $0.1["action"] as? String == "audio_back" }.map(\.1)
    }
    XCTAssertEqual(backs().count, 0)
    t.audio.pendingRestart?(nil)
    t.audio.mic(480, value: 0.2)
    XCTAssertEqual(backs().count, 1)
    XCTAssertEqual(backs().first?["buffers"] as? Int, CallSession.zeroBuffersBeforeRearm + 2)
  }

  /// Codex on #365: a rebuild that finishes after the hang-up logs nothing for the ended call.
  func testARestartThatFinishesAfterTheHangUpIsIgnored() {
    let t = CallHarness()
    t.goLive()
    t.audio.deferRestart = true
    zeros(t, CallSession.zeroBuffersBeforeRearm)
    t.session.stop()
    let before = t.events.count
    t.audio.pendingRestart?(nil)
    XCTAssertEqual(t.events.count, before, "nothing logged after call_ended")
  }

  func testAMicThatWasLiveBeforeTheZerosSaysSo() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic(480, value: 0.2)
    zeros(t, CallSession.zeroBuffersBeforeRearm)
    let heal = t.events.first { $0.0 == "call_heal" && $0.1["action"] as? String == "rearm_mic" }?.1
    XCTAssertEqual(heal?["heard_before"] as? Bool, true)
    XCTAssertEqual(heal?["buffers"] as? Int, CallSession.zeroBuffersBeforeRearm + 1)

    // Codex on #365: sound → zeros → rearm → sound still says the mic came back.
    t.audio.mic(480, value: 0.2)
    let back = t.events.filter { $0.0 == "call_mic" && $0.1["action"] as? String == "audio_back" }.map(\.1)
    XCTAssertEqual(back.count, 1)
    XCTAssertEqual(back.first?["buffers"] as? Int, CallSession.zeroBuffersBeforeRearm + 2)
  }

  func testAQuietRoomIsNotZeros() {
    let t = CallHarness()
    t.goLive()
    for _ in 0..<(CallSession.zeroBuffersBeforeRearm * 2) { t.audio.mic(480, value: 1e-6) }
    XCTAssertEqual(t.audio.restarts, 0)
  }

  func testStillSendsTheZeroFramesMeanwhile() {
    let t = CallHarness()
    t.goLive()
    zeros(t, 3)
    XCTAssertEqual(t.socket.binaries.count, 3)
  }
}

final class CallSessionVoiceTests: XCTestCase {
  func testServerSettingsAndTheirSourceReachStartAndRestart() {
    let t = CallHarness()
    let body = Data(
      #"{"ok":true,"schema":1,"voices":[{"pick":"igor","id":"recommended-clone","model":"eleven_v4_turbo"}]}"#.utf8)
    t.settings.receive(status: 200, data: body, etag: "v1", cacheControl: nil, at: Date())
    t.session.start(.eleven, voice: .igor)
    t.socket.open()
    XCTAssertEqual(t.socket.frames[0]["voice"] as? String, "recommended-clone")
    XCTAssertEqual(t.socket.frames[0]["model"] as? String, "eleven_v4_turbo")
    XCTAssertEqual(t.events.first { $0.0 == "call_start" }?.1["model_source"] as? String, "server")
    t.settings = CallSettings(saved: t.settings.saved)
    let second = t.nextSocket()
    t.session.restart()
    second.open()
    XCTAssertEqual(second.frames[0]["model"] as? String, "eleven_v4_turbo")
    XCTAssertEqual(t.events.last { $0.0 == "call_start" }?.1["model_source"] as? String, "cache")
  }

  func testIgorRidesTheStartFrameAsTheCloneWithBridgeModelTonySendsTheDefaults() {
    let t = CallHarness()
    t.session.start(.eleven, voice: .igor)
    t.socket.open()
    XCTAssertEqual(t.socket.frames[0]["voice"] as? String, "Nvd5I2HGnOWHNU0ijNEy")
    XCTAssertEqual(t.socket.frames[0]["model"] as? String, "")
    XCTAssertEqual(t.session.snapshot.voice, .igor)
    t.session.stop()
    let second = t.nextSocket()
    t.session.start(.eleven, voice: .tony)
    second.open()
    XCTAssertEqual(second.frames[0]["voice"] as? String, "")
    XCTAssertEqual(second.frames[0]["model"] as? String, "")
    XCTAssertEqual(t.session.snapshot.voice, .tony)
  }

  func testOnGeminiThePickIsInTheSnapshotButNothingRidesTheFrame() {
    let t = CallHarness()
    t.session.start(.gemini, voice: .igor)
    t.socket.open()
    XCTAssertEqual(t.socket.frames[0]["voice"] as? String, "")
    XCTAssertEqual(t.session.snapshot.voice, .igor)
  }

  func testStartWithoutAVoiceIsTony() {
    let t = CallHarness()
    t.session.start(.eleven)
    XCTAssertEqual(t.session.snapshot.voice, .tony)
  }
}

final class CallSessionCountersTests: XCTestCase {
  func testLogsReceivedBytesAgainstPlayedSecondsEveryFiveSecondsAndTheFinalPairOnEnding() {
    let t = CallHarness()
    t.audio.statsValue = PlaybackStats(
      scheduledS: 1.5, playedS: 1.2, clockRunning: true, pendingS: 0, oddFrames: 3, underruns: 2)
    t.goLive(.eleven)
    t.audio.mic()
    t.socket.say(["type": "mic_ack", "token": 1])
    t.socket.speak(3200)
    t.socket.speak(3200)
    t.clock.advance(5000)
    let stats = t.last("call_stats")!
    XCTAssertEqual(stats["rx_kb"] as? Double, 6)
    XCTAssertEqual(stats["rx_frames"] as? Int, 2)
    XCTAssertEqual(stats["mic_frames"] as? Int, 1)
    XCTAssertEqual(stats["playback"] as? String, "played 1.2s of 1.5s")
    XCTAssertEqual(stats["odd_frames"] as? Int, 3)  // #442: the audio layer's totals ride the line
    XCTAssertEqual(stats["underruns"] as? Int, 2)
    t.clock.advance(5000)
    XCTAssertEqual(t.events.filter { $0.0 == "call_stats" }.count, 2)
    t.session.stop()
    let ended = t.last("call_ended")!
    XCTAssertEqual(ended["reason"] as? String, "stopped")
    XCTAssertEqual(ended["rx_frames"] as? Int, 2)
    XCTAssertEqual(ended["played_s"] as? Double, 1.2)
    XCTAssertEqual(ended["badly"] as? Bool, false)
    XCTAssertEqual(ended["odd_frames"] as? Int, 3)
    XCTAssertEqual(ended["underruns"] as? Int, 2)
    t.clock.advance(20000)
    XCTAssertEqual(t.events.filter { $0.0 == "call_stats" }.count, 2)  // nothing after the end
  }

  func testTonysTextWithNoAudioForFiveSecondsIsNamedAndClearsWhenAudioComes() {
    let t = CallHarness()
    t.goLive(.eleven)
    t.audio.mic()
    t.socket.say(["type": "mic_ack", "token": 1])
    t.socket.say(["type": "transcript", "who": "larry", "text": "Hello there."])
    t.clock.advance(5000)
    XCTAssertEqual(t.session.snapshot.problem, CallWatchdog.audioNotArriving)
    t.socket.speak()
    XCTAssertNil(t.session.snapshot.problem)
    t.socket.say(["type": "transcript", "who": "larry", "text": "Still here."])
    t.clock.advance(5000)
    XCTAssertNil(t.session.snapshot.problem)
  }

  // #567: Igor cut in during a tool call; the cut-off reply's words came as text with no audio and flashed the banner.
  func testTheCutOffReplysTextAfterAnInterruptionRaisesNoBannerButLaterTextStillDoes() {
    let t = CallHarness()
    t.goLive(.direct)
    t.audio.mic()
    t.socket.say(["type": "mic_ack", "token": 1])
    t.socket.say(["type": "transcript", "who": "larry", "text": "Let me look. Yes, it's wired in."])
    t.socket.say(["type": "turn_end"])
    t.socket.speak()
    t.clock.advance(10000)
    t.socket.say(["type": "interrupted"])
    t.socket.say(["type": "transcript", "who": "larry", "text": "Let me look. Yes, it's wired in…"])
    t.clock.advance(5000)
    XCTAssertNil(t.session.snapshot.problem)
    XCTAssertTrue(t.events.contains { $0.0 == "call_bridge" && $0.1["kind"] as? String == "cut_off_resend" })
    XCTAssertFalse(
      t.events.contains { $0.0 == "call_problem" && ($0.1["problem"] as? String ?? "") != "" },
      "a barge-in is not call trouble")
    t.socket.say(["type": "transcript", "who": "larry", "text": "Not from here, this call is read-only."])
    t.clock.advance(5000)
    XCTAssertEqual(t.session.snapshot.problem, CallWatchdog.audioNotArriving)
  }

  func testTheAudioLayersVerdictStandsAndLiftsWithoutTouchingABridgeError() {
    let t = CallHarness()
    t.goLive(.eleven)
    t.audio.onHealth?(CallWatchdog.micStopped)
    XCTAssertEqual(t.session.snapshot.problem, CallWatchdog.micStopped)
    t.audio.onHealth?(nil)
    XCTAssertNil(t.session.snapshot.problem)
    t.socket.say(["type": "error", "message": "bridge boom"])
    t.audio.onHealth?(CallWatchdog.micStopped)
    t.audio.onHealth?(nil)
    XCTAssertEqual(t.session.snapshot.problem, "bridge boom")
  }
}

final class CallSessionLocationTests: XCTestCase {
  let home = CallLocation(lat: 47.6, lon: -122.3, accuracyM: 12, at: "2026-09-02T14:52:00.000Z", place: "Home")
  let school = CallLocation(lat: 47.61, lon: -122.31, accuracyM: 20, at: "2026-09-02T14:58:00.000Z", place: nil)

  func testAFixBeforeTheSocketOpensRidesTheStartFrame() {
    let t = CallHarness()
    t.session.start(.eleven)
    t.session.setLocation(home)
    XCTAssertTrue(t.socket.texts.isEmpty)
    t.socket.open()
    let location = t.socket.frames[0]["location"] as? [String: Any]
    XCTAssertEqual(location?["place"] as? String, "Home")
    XCTAssertEqual(location?["accuracy_m"] as? Int, 12)
    XCTAssertFalse(t.socket.types.contains("location"))
  }

  func testAFixAfterTheSocketOpensIsItsOwnFrameIdleItIsOnlyRemembered() {
    let t = CallHarness()
    t.session.setLocation(home)
    t.goLive(.eleven)
    XCTAssertEqual((t.socket.frames[0]["location"] as? [String: Any])?["place"] as? String, "Home")
    t.session.setLocation(school)
    XCTAssertEqual(t.socket.types.last, "location")
    XCTAssertEqual(t.socket.frames.last?["lat"] as? Double, 47.61)
    t.session.stop()
    let before = t.socket.texts.count
    t.session.setLocation(home)
    XCTAssertEqual(t.socket.texts.count, before)
  }

  func testACallsFixDoesNotRideTheNextCallUnlessGivenAgain() {
    let t = CallHarness()
    t.goLive(.eleven)
    t.session.setLocation(home)
    t.session.stop()
    var next = t.nextSocket()
    t.session.clearLocation()
    t.session.start(.eleven)
    next.open()
    XCTAssertNil(next.frames[0]["location"])
    t.session.stop()
    next = t.nextSocket()
    t.session.clearLocation()
    t.session.setLocation(school)
    t.session.start(.eleven)
    next.open()
    XCTAssertEqual((next.frames[0]["location"] as? [String: Any])?["lat"] as? Double, 47.61)
  }
}

final class CallSessionControlsTests: XCTestCase {
  func testRestartHangsUpAndDialsAgainOnTheSameBackendInTheSameVoice() {
    let t = CallHarness()
    t.goLive(.eleven, voice: .igor)
    let second = t.nextSocket()
    t.session.restart()
    XCTAssertEqual(Array(t.socket.types.suffix(2)), ["stt_stop", "stop"])
    XCTAssertTrue(t.socket.closed)
    XCTAssertEqual(t.session.snapshot.state, .connecting)
    XCTAssertEqual(t.session.snapshot.voice, .igor)
    second.open()
    XCTAssertEqual(second.frames[0]["backend"] as? String, "eleven")
    XCTAssertEqual(second.frames[0]["model"] as? String, "")
  }

  func testRestartDoesNothingWhenIdle() {
    let t = CallHarness()
    t.session.restart()
    XCTAssertTrue(t.connects.isEmpty)
  }

  func testMutedNothingLeavesThePhoneAndTheBridgeIsTold() {
    let t = CallHarness()
    t.goLive()
    t.session.setMuted(true)
    t.audio.mic()
    t.audio.mic()
    XCTAssertTrue(t.socket.binaries.isEmpty)
    XCTAssertEqual(t.socket.frames.last?["type"] as? String, "mic")
    XCTAssertEqual(t.socket.frames.last?["muted"] as? Bool, true)
    t.session.setMuted(false)
    t.audio.mic()
    XCTAssertEqual(t.socket.binaries.count, 1)
    XCTAssertEqual(
      t.socket.frames.filter { $0["type"] as? String == "mic" }.map { $0["muted"] as? Bool ?? false }, [true, false])
  }

  func testMuteIsRememberedAcrossCallsButNotAnnouncedWhileIdle() {
    let t = CallHarness()
    t.session.setMuted(true)
    XCTAssertTrue(t.session.snapshot.muted)
    t.goLive()
    XCTAssertFalse(t.socket.types.contains("mic"))
    XCTAssertTrue(t.session.snapshot.muted)
  }

  func testReportsALevelPerBufferMutedIncludedAndZeroAtTheEnd() {
    let t = CallHarness()
    t.goLive()
    t.audio.mic()  // silence
    t.session.setMuted(true)
    t.audio.mic(480, value: 0.5)
    t.socket.say(["type": "closed", "reason": "stopped"])
    XCTAssertEqual(t.levels.first, 0)
    XCTAssertGreaterThan(t.levels[1], 0.8)
    XCTAssertEqual(t.levels.last, 0)
    XCTAssertEqual(t.socket.binaries.count, 1)
  }
}

final class CallSessionPlaybackAndCaptionTests: XCTestCase {
  func testBinaryFramesPlayWhileLiveAndAreDroppedBeforeReady() {
    let t = CallHarness()
    t.session.start(.gemini)
    t.socket.open()
    t.socket.speak()
    XCTAssertTrue(t.audio.played.isEmpty)
    t.socket.say(["type": "ready", "out_rate": 24000])
    t.socket.speak(960)
    XCTAssertEqual(t.audio.played.map { $0.count }, [960])
    XCTAssertEqual(t.last("call_rx")?["bytes"] as? Int, 960)
  }

  func testInterruptedFlushesPlayback() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "interrupted"])
    XCTAssertEqual(t.audio.flushes, 1)
  }

  func testIgorsWordsArePendingUntilLarryAnswersAndLarrysFragmentsJoinOneRow() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_partial", "text": "hello"])
    XCTAssertEqual(t.texts, ["igor?:hello"])
    t.socket.say(["type": "stt_partial", "text": "hello lar"])
    t.socket.say(["type": "stt_final", "text": "hello Larry"])
    XCTAssertEqual(t.texts, ["igor?:hello Larry"])
    t.socket.say(["type": "stt_final", "text": "how are you"])
    XCTAssertEqual(t.texts, ["igor?:hello Larry how are you"])
    t.socket.say(["type": "transcript", "who": "larry", "text": "Hi Igor."])
    t.socket.say(["type": "transcript", "who": "larry", "text": "I'm well."])
    XCTAssertEqual(t.texts, ["igor:hello Larry how are you", "larry:Hi Igor. I'm well."])
    t.socket.say(["type": "turn_end"])
    t.socket.say(["type": "transcript", "who": "larry", "text": "And you?"])
    XCTAssertEqual(t.texts, ["igor:hello Larry how are you", "larry:Hi Igor. I'm well.", "larry:And you?"])
    let logged = t.events.filter { $0.0 == "call_caption" }.map { "\($0.1["who"]!):\($0.1["text"]!)" }
    XCTAssertEqual(logged, ["igor:hello Larry how are you", "larry:Hi Igor. I'm well."])
  }

  func testTheVendorsTranscriptOfIgorReplacesTheRecognizersAndATypedOneIsIgnored() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_final", "text": "helo lary"])
    t.socket.say(["type": "transcript", "who": "igor", "text": "Hello Larry."])
    XCTAssertEqual(t.texts, ["igor!:Hello Larry."])
    t.socket.say(["type": "transcript", "who": "igor", "text": "typed", "source": "typed"])
    XCTAssertEqual(t.texts, ["igor!:Hello Larry."])
  }

  // #467, story 216: sent to Larry is out of the live line now, marked sent, not when Larry answers.
  func testASentSentenceLeavesTheLiveLineMarkedSentAndTheMarkGoesWhenLarryAnswers() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_partial", "text": "what should"])
    t.socket.say(["type": "stt_final", "text": "What should I eat?"])
    XCTAssertEqual(t.texts, ["igor?:What should I eat?"])
    t.socket.say(["type": "transcript", "who": "igor", "text": "What should I eat?"])
    XCTAssertEqual(t.texts, ["igor!:What should I eat?"])
    XCTAssertNil(t.session.snapshot.captions.first { $0.pending }, "the live line is empty again")
    let logged = t.events.filter { $0.0 == "call_caption" }
    XCTAssertEqual(logged.count, 1)
    XCTAssertEqual(logged.first?.1["sent"] as? Bool, true)
    t.socket.say(["type": "transcript", "who": "larry", "text": "Eggs."])
    XCTAssertEqual(t.texts, ["igor:What should I eat?", "larry:Eggs."])
    XCTAssertEqual(t.events.filter { $0.0 == "call_caption" && $0.1["who"] as? String == "igor" }.count, 1)
  }

  func testTwoSentencesSentBeforeLarryAnswersAreTwoRowsNotOne() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_final", "text": "Can you outsource yourself?"])
    t.socket.say(["type": "transcript", "who": "igor", "text": "Can you outsource yourself?"])
    t.socket.say(["type": "stt_partial", "text": "hold"])
    XCTAssertEqual(t.texts, ["igor!:Can you outsource yourself?", "igor?:hold"])
    t.socket.say(["type": "stt_final", "text": "Hold on."])
    t.socket.say(["type": "transcript", "who": "igor", "text": "Hold on."])
    XCTAssertEqual(t.texts, ["igor!:Can you outsource yourself?", "igor!:Hold on."])
    t.socket.say(["type": "turn_end"])
    XCTAssertEqual(t.texts, ["igor:Can you outsource yourself?", "igor:Hold on."])
  }

  // The recognizer's finals after a send, before any partial, are its late account of the sentence already sent —
  // whatever their words.
  func testALateFinalSpelledDifferentlyFromTheSentSentenceIsNotShownTwice() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_partial", "text": "helo"])
    t.socket.say(["type": "transcript", "who": "igor", "text": "Hello Larry."])
    t.socket.say(["type": "stt_final", "text": "helo lary"])
    XCTAssertEqual(t.texts, ["igor!:Hello Larry."])
    XCTAssertEqual(t.last("call_caption_restated")?["text"] as? String, "helo lary")
  }

  func testALateFinalThatIsOnlyTheStartOfTheSentSentenceIsNotShown() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "transcript", "who": "igor", "text": "What should I eat tonight?"])
    t.socket.say(["type": "stt_final", "text": "what should I"])
    XCTAssertEqual(t.texts, ["igor!:What should I eat tonight?"])
  }

  func testEveryFinalBeforeTheNextPartialIsDroppedThenNewSpeechShows() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "transcript", "who": "igor", "text": "What should I eat tonight?"])
    t.socket.say(["type": "stt_final", "text": "what should I"])
    t.socket.say(["type": "stt_final", "text": "eat tonight"])
    XCTAssertEqual(t.texts, ["igor!:What should I eat tonight?"])
    XCTAssertEqual(t.events.filter { $0.0 == "call_caption_restated" }.count, 2)
    t.socket.say(["type": "stt_partial", "text": "and"])
    t.socket.say(["type": "stt_final", "text": "and tomorrow"])
    XCTAssertEqual(t.texts, ["igor!:What should I eat tonight?", "igor?:and tomorrow"])
  }

  func testARealRepeatStartsWithAPartialAndIsShown() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "transcript", "who": "igor", "text": "Hello Larry."])
    t.socket.say(["type": "stt_partial", "text": "hello"])
    t.socket.say(["type": "stt_final", "text": "hello Larry"])
    XCTAssertEqual(t.texts, ["igor!:Hello Larry.", "igor?:hello Larry"])
    t.socket.say(["type": "transcript", "who": "igor", "text": "Hello Larry."])
    XCTAssertEqual(t.texts, ["igor!:Hello Larry.", "igor!:Hello Larry."])
    XCTAssertNil(t.last("call_caption_restated"))
  }

  func testTheSentMarkSurvivesAnInterruptionAndAConsult() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "transcript", "who": "igor", "text": "Look this up."])
    t.socket.say(["type": "interrupted"])
    XCTAssertEqual(t.texts, ["igor!:Look this up."])
    t.socket.say(["type": "tool_call", "question": "what is up"])
    XCTAssertEqual(t.texts.first, "igor!:Look this up.")
    t.socket.say(["type": "transcript", "who": "larry", "text": "Found it."])
    XCTAssertEqual(t.texts.first, "igor:Look this up.")
  }

  func testHangingUpClearsTheSentMark() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "transcript", "who": "igor", "text": "Bye."])
    t.session.stop()
    XCTAssertEqual(t.texts, ["igor:Bye."])
  }

  func testATurnEndWithNothingSaidLeavesNoEmptyRow() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_partial", "text": "um"])
    t.socket.say(["type": "stt_partial", "text": ""])
    t.socket.say(["type": "turn_end"])
    XCTAssertEqual(t.texts, [])
  }

  func testAConsultIsOneRowThatUpdatesInPlace() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "tool_call", "id": "t1", "name": "talk_to_larry", "question": "what's next?"])
    XCTAssertEqual(t.texts, ["tool:asking Larry: what's next? …"])
    t.socket.say(["type": "consult_progress", "stage": "note", "text": "reading the plan"])
    XCTAssertEqual(t.texts, ["tool:reading the plan"])
    t.socket.say(["type": "tool_result", "ok": true, "answer": "Ship it.", "duration_s": 12])
    XCTAssertEqual(t.texts, ["tool:Ship it."])
    t.socket.say(["type": "transcript", "who": "larry", "text": "Larry says ship it."])
    XCTAssertEqual(t.texts, ["tool:Ship it.", "larry:Larry says ship it."])
  }

  func testInjectedContextAndWarningsAreNotesABridgeErrorIsAProblemNotAnEnding() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "injected", "text": "the PR merged"])
    t.socket.say(["type": "warning", "message": "Gemini goAway in 60s"])
    t.socket.say(["type": "error", "message": "vendor 500"])
    XCTAssertEqual(t.texts, ["note:added context: the PR merged", "note:warning: Gemini goAway in 60s"])
    XCTAssertEqual(t.session.snapshot.state, .live)
    XCTAssertEqual(t.session.snapshot.problem, "vendor 500")
  }
}

final class CallSessionEndingTests: XCTestCase {
  func testStopSendsTheDumpFirstThenSttStopAndStop() {
    let t = CallHarness(build: "b (m)", diagnostics: true)
    t.goLive()
    t.session.stop()
    XCTAssertEqual(Array(t.socket.types.suffix(3)), ["diagnostics", "stt_stop", "stop"])
    let diag = t.socket.frames[t.socket.frames.count - 3]
    XCTAssertEqual(diag["build"] as? String, "b (m)")
    XCTAssertTrue((diag["text"] as? String ?? "").contains("call_hangup"))
  }

  func testStopClosesAndEndsAsStoppedAndTheBridgesOwnClosedChangesNothing() {
    let t = CallHarness()
    t.goLive()
    t.session.stop()
    XCTAssertEqual(Array(t.socket.types.suffix(2)), ["stt_stop", "stop"])
    XCTAssertTrue(t.socket.closed)
    XCTAssertEqual(t.session.snapshot.state, .ended)
    XCTAssertEqual(t.session.snapshot.endedReason, CallProtocol.stopped)
    XCTAssertFalse(t.session.snapshot.endedBadly)
    XCTAssertEqual(t.audio.stops, 1)
    t.socket.say(["type": "closed", "reason": "stopped"])
    t.socket.drop()
    XCTAssertEqual(t.session.snapshot.endedReason, CallProtocol.stopped)
    XCTAssertEqual(t.events.filter { $0.0 == "call_ended" }.count, 1)
  }

  func testTheBridgesClosedCarriesItsReason() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "closed", "reason": "hangup intent"])
    XCTAssertEqual(t.session.snapshot.endedReason, "hangup intent")
    XCTAssertFalse(t.session.snapshot.endedBadly)
    XCTAssertEqual(t.audio.stops, 1)
    XCTAssertEqual(t.last("call_ended")?["text"] as? String, "hang-up intent")
  }

  func testAVendorCloseIsABadEndingInTheVendorsWords() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "vendor_closed", "kind": "quota", "message": "ElevenLabs quota exceeded"])
    XCTAssertEqual(t.session.snapshot.endedReason, "ElevenLabs quota exceeded")
    XCTAssertTrue(t.session.snapshot.endedBadly)
  }

  func testADroppedSocketMidCallIsAConnectionLost() {
    let t = CallHarness()
    t.goLive()
    t.socket.drop()
    XCTAssertEqual(t.session.snapshot.endedReason, CallProtocol.connectionLost)
    XCTAssertTrue(t.session.snapshot.endedBadly)
    XCTAssertTrue(CallEventLog.hadTrouble(t.events.map { CallEvent(t: 0, type: $0.0, fields: $0.1) }))
  }

  func testEndingPromotesIgorsPendingWordsAndKeepsTheCaptions() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "stt_final", "text": "bye Larry"])
    t.socket.say(["type": "closed", "reason": "hangup intent"])
    XCTAssertEqual(t.session.snapshot.captions, [CaptionRow(id: 1, who: .igor, text: "bye Larry", pending: false)])
  }

  func testANewCallAfterAnEndingStartsCleanOnAFreshSocket() {
    let t = CallHarness()
    t.goLive()
    t.socket.say(["type": "transcript", "who": "larry", "text": "old"])
    t.socket.say(["type": "closed", "reason": "stopped"])
    let second = t.nextSocket()
    t.session.start(.drill)
    XCTAssertEqual(t.session.snapshot.state, .connecting)
    XCTAssertEqual(t.session.snapshot.backend, .drill)
    XCTAssertTrue(t.session.snapshot.captions.isEmpty)
    XCTAssertNil(t.session.snapshot.endedReason)
    second.open()
    XCTAssertEqual(second.frames[0]["backend"] as? String, "drill")
  }

  // #436: a Direct call says `direct` and leaves Larry's model and voice to the bridge, whatever voice was picked.
  func testADirectCallNamesTheBackendAndSendsNoVoiceOrModel() {
    let t = CallHarness()
    t.session.start(.direct, voice: .igor)
    t.socket.open()
    XCTAssertEqual(t.session.snapshot.backend, .direct)
    XCTAssertEqual(t.socket.frames[0]["backend"] as? String, "direct")
    XCTAssertEqual(t.socket.frames[0]["voice"] as? String, "")
    XCTAssertEqual(t.socket.frames[0]["model"] as? String, "")
  }

  func testMicBuffersAfterTheEndGoNowhere() {
    let t = CallHarness()
    t.goLive()
    t.session.stop()
    let before = t.socket.texts.count + t.socket.binaries.count
    t.audio.mic()
    XCTAssertEqual(t.socket.texts.count + t.socket.binaries.count, before)
  }

  func testACompletionFromAnEarlierCallDoesNotActOnTheNextOne() {
    // A mic buffer callback captured by the first call must not feed the second.
    let t = CallHarness()
    t.goLive()
    let stale = t.audio.firstOnBuffer!
    t.socket.say(["type": "closed", "reason": "stopped"])
    let second = t.nextSocket()
    t.session.start(.gemini)
    second.open()
    second.say(["type": "ready", "out_rate": 16000])
    stale([Float](repeating: 0.3, count: 480), 48000)
    XCTAssertTrue(second.binaries.isEmpty)
  }
}
