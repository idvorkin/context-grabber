//  The call's audio on AVAudioEngine: the session, echo cancellation, the microphone and Larry's voice.
//
//  The session is `.playAndRecord` / `.voiceChat`, out of the speaker unless a headset is on. Echo cancellation is
//  iOS's voice-processing unit, switched on with `setVoiceProcessingEnabled(true)` on a stopped engine at prepare —
//  before anything starts, every call, so the first call after launch is built exactly like the tenth (#80, #88).
//  The mic is a tap on the input node at the hardware rate; CallSession resamples to 16 kHz. Larry's PCM16 is
//  scheduled on a player node at the rate `ready` named; the mixer converts it to the hardware's.
//
//  The watchdog (ContextCore's CallWatchdog) looks at both directions twice a second: a tap that goes quiet is
//  re-armed up to three times, a clock that stops with audio due is reopened, and a clock that never starts is
//  reopened once. Interruptions (a phone call, Siri) pause and resume; a route or configuration change rebuilds the
//  graph. Every boundary is a `call_audio` or `call_heal` event (docs/DEBUGGING.md).
//
//  Everything that touches AVAudio* runs in order on one queue; completions, buffers and health go to main.

import AVFoundation
import ContextCore
import UIKit

final class CallAudioEngine: CallAudio, @unchecked Sendable {
  var onHealth: ((String?) -> Void)?

  private let log: @Sendable (String, [String: Any]) -> Void
  private let queue = DispatchQueue(label: "grabber.call.audio")
  private let session = AVAudioSession.sharedInstance()

  // Touched only on `queue`.
  private var engine: AVAudioEngine?
  private var player: AVAudioPlayerNode?
  private var playerFormat: AVAudioFormat?
  private var outRate = 24000.0
  private var micListener: (([Float], Double) -> Void)?
  private var tapInstalled = false
  private var paused = false
  private var armedAt = 0.0
  private var lastBufferAt = 0.0
  private var micDeadline = MicStartupDeadline()
  private var micStalls = 0
  private var micStallRearm = false
  private var watchdog: DispatchSourceTimer?
  private var observers: [NSObjectProtocol] = []
  /// Which heal a queued retry belongs to (#198).
  private var healGate = HealGate()
  private var health: String?
  private var openedAt = 0.0
  private var clockLive = false
  private var clockReopened = false
  private var clockPrev = 0.0
  private var clockAdvancedAt = 0.0
  private var lastScheduledAt = 0.0
  private var lastReopenAt = 0.0
  private var firstBufferLogged = false
  /// #146 (a call that "played" Tony with nothing heard): per five seconds, the loudest sample the bridge sent and
  /// the loudest the mixer rendered, so the log says whether silence came in or sound got lost on the way out.
  private var rxPeak: Float = 0
  /// When this window's first audible frame from Larry arrived (#186).
  private var firstLoudRxAt: Double?
  private var mixPeak: Float = 0
  private var mixBuffers = 0
  private var mixTapInstalled = false
  /// #442: Larry's bytes as one stream across frames (an odd frame's last byte waits for the next), and five seconds
  /// of how his frames arrived and were queued, logged as `call_playback`.
  private var rxStream = PCM16Stream()
  private var window = PlaybackWindow()
  /// #578: a copy of what is scheduled, so a heal's rebuild can play what the old player had not reached.
  private var tail = PlaybackTail(rate: 16000)
  /// The player's last running time: a stopped engine reads 0, and a rebuild after an OS stop must not replay what
  /// was heard (Fable on #578).
  private var heardPlayerS = 0.0
  /// A failed rebuild is waiting to be tried again: Larry's frames go to the tail, not the floor (Fable on #578).
  private var rebuildRetryPending = false

  /// The output, read from main for the stats line: guarded by `lock`.
  private let lock = NSLock()
  private var scheduledS = 0.0
  private var playhead = 0.0
  private var playerTimeS = 0.0
  private var playbackOpen = false
  private var oddFrames = 0
  private var underruns = 0
  private var publishedMicDeadline = MicStartupDeadline()

  /// #441: whether the app was in front when a start failed, read on the audio queue without waiting on main.
  private var appState = "unknown"
  private var appObservers: [NSObjectProtocol] = []

  init(log: @escaping @Sendable (String, [String: Any]) -> Void) {
    self.log = log
    let center = NotificationCenter.default
    let states: [(Notification.Name, String)] = [
      (UIApplication.didBecomeActiveNotification, "active"), (UIApplication.willResignActiveNotification, "inactive"),
      (UIApplication.didEnterBackgroundNotification, "background"),
    ]
    for (name, state) in states {
      appObservers.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          self?.lock.withLock { self?.appState = state }
        })
    }
    DispatchQueue.main.async { [weak self] in
      let state = MainActor.assumeIsolated { UIApplication.shared.applicationState }
      let name = state == .active ? "active" : state == .background ? "background" : "inactive"
      self?.lock.withLock { self?.appState = name }
    }
  }

  private var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

  // MARK: - CallAudio

  func prepare(_ done: @escaping (Error?) -> Void) {
    AVAudioApplication.requestRecordPermission { [self] granted in
      queue.async { [self] in
        healGate.invalidate()
        guard granted else {
          log("call_audio", ["action": "permission", "ok": false])
          return main { done(CallAudioError("microphone permission denied — Settings → Grabber Native")) }
        }
        do {
          try configureSession()
          try buildEngine()
          observe()
          main { done(nil) }
        } catch {
          log("call_audio", ["action": "prepare", "ok": false, "message": describe(error)])
          teardown()
          main { done(error) }
        }
      }
    }
  }

  func openPlayback(outRate: Double) {
    queue.async { [self] in
      self.outRate = outRate
      rxStream = PCM16Stream()
      window = PlaybackWindow()
      tail = PlaybackTail(rate: outRate)
      heardPlayerS = 0
      do {
        try connectPlayer()
        try startEngine(why: "playback")
        player?.play()
        lock.withLock {
          playbackOpen = true
          scheduledS = 0
          playhead = 0
          playerTimeS = 0
          oddFrames = 0
          underruns = 0
        }
        openedAt = nowMs
        clockLive = false
        clockReopened = false
        lastScheduledAt = 0
        log(
          "call_audio",
          [
            "action": "playback_open", "out_rate": outRate, "ok": true,
            "hw_rate": engine?.outputNode.outputFormat(forBus: 0).sampleRate ?? 0,
            "io_buffer_ms": (session.ioBufferDuration * 1000).rounded(),
          ])
        startWatchdog()
      } catch {
        log("call_audio", ["action": "playback_open", "out_rate": outRate, "ok": false, "message": describe(error)])
      }
    }
  }

  func startMic(_ onBuffer: @escaping ([Float], Double) -> Void, _ done: @escaping (Error?) -> Void) {
    queue.async { [self] in
      micListener = onBuffer
      micStalls = 0
      micStallRearm = false
      do {
        try armTap()
        main { done(nil) }
      } catch {
        log("call_audio", ["action": "mic_arm", "ok": false, "message": describe(error)])
        main { done(error) }
      }
    }
  }

  /// A heal: the whole graph down and up again — the second call is the one that always worked (#88) — with the
  /// session re-asserted. Larry's unheard audio plays on the new graph after a short gap (#578).
  func restartMic(_ done: @escaping (Error?) -> Void) {
    queue.async { [self] in
      log("call_audio", ["action": "restart", "why": "heal"])
      do {
        try rebuild(why: "restart")
        main { done(nil) }
      } catch {
        log("call_audio", ["action": "restart", "ok": false, "message": describe(error)])
        main { done(error) }
      }
    }
  }

  func play(_ pcm: Data) {
    queue.async { [self] in
      guard let player, let format = playerFormat, let engine, engine.isRunning else {
        if rebuildRetryPending {
          // #578: the retry's new player plays it after what the old one had not reached.
          let samples = rxStream.decode(pcm)
          let duration = Double(samples.count) / outRate
          tail.append(samples, at: tail.durationS)
          lock.withLock {
            scheduledS += duration
            playhead += duration
          }
          return
        }
        // Nowhere to put it: the frame is lost, but its bytes still say where the next sample starts (#442).
        rxStream.skip(pcm)
        window.dropped()
        return
      }
      let samples = rxStream.decode(pcm)
      let now = currentPlayerTime()
      let head = lock.withLock { playhead }
      let queued = head - now
      let underrunsBefore = window.underruns
      window.scheduled(bytes: pcm.count, at: nowMs, queuedS: queued, previousAt: lastScheduledAt)
      lock.withLock {
        oddFrames = rxStream.oddFrames
        if window.underruns > underrunsBefore { underruns += 1 }
      }
      for x in samples { rxPeak = max(rxPeak, abs(x)) }
      if rxPeak > 0.01, firstLoudRxAt == nil { firstLoudRxAt = nowMs }
      guard schedule(samples, on: player, format: format) else { return }
      tail.prune(before: now)
      tail.append(samples, at: max(head, now))
      let duration = Double(samples.count) / outRate
      lock.withLock {
        scheduledS += duration
        playhead = max(playhead, now) + duration
      }
      lastScheduledAt = nowMs
      if !player.isPlaying { player.play() }
    }
  }

  /// One buffer of Larry's samples onto the player; false when there is nothing to schedule.
  private func schedule(_ samples: [Float], on player: AVAudioPlayerNode, format: AVAudioFormat) -> Bool {
    guard !samples.isEmpty,
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
    else { return false }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { src in
      // An empty chunk has no base address; a float buffer always has channel data.
      guard let channels = buffer.floatChannelData, let base = src.baseAddress else { return }
      channels[0].update(from: base, count: samples.count)
    }
    player.scheduleBuffer(buffer, completionHandler: nil)
    return true
  }

  /// Barge-in: everything of Larry's not yet heard goes. The player's clock restarts from zero.
  func flush() {
    queue.async { [self] in
      // #442: what follows is a new stream, even when a failed rebuild left no player to stop.
      rxStream.reset()
      tail.reset()
      heardPlayerS = 0
      guard let player else { return }
      let now = currentPlayerTime()
      player.stop()
      lock.withLock {
        scheduledS -= max(0, playhead - now)
        playhead = 0
        playerTimeS = 0
      }
      clockPrev = 0
      clockAdvancedAt = nowMs
      // Its first frame finds an empty queue by design.
      lastScheduledAt = 0
      if engine?.isRunning == true { player.play() }
    }
  }

  func stop() {
    queue.async { [self] in
      healGate.invalidate()
      micListener = nil
      teardown()
      do {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        log("call_audio", ["action": "inactive", "ok": true])
      } catch {
        log("call_audio", ["action": "inactive", "ok": false, "message": describe(error)])
      }
      setHealth(nil)
    }
  }

  func stats() -> PlaybackStats? {
    lock.withLock {
      guard playbackOpen else { return nil }
      let queued = max(0, playhead - playerTimeS)
      return PlaybackStats(
        scheduledS: scheduledS, playedS: max(0, scheduledS - queued), clockRunning: playerTimeS > 0, pendingS: 0,
        oddFrames: oddFrames, underruns: underruns)
    }
  }

  // #423, story 204: the deadline the queue last published (armTap and the watchdog tick), read without waiting
  // on the queue.
  func micStartupDeadline() -> MicStartupDeadline {
    lock.withLock { publishedMicDeadline }
  }

  private func currentMicDeadline() -> MicStartupDeadline {
    let route = session.currentRoute
    let bluetooth = (route.inputs + route.outputs).contains {
      $0.portType == .bluetoothHFP || $0.portType.rawValue.lowercased().contains("bluetooth")
    }
    return MicStartupDeadline(bluetooth: bluetooth, sampleRate: engine?.inputNode.outputFormat(forBus: 0).sampleRate)
  }

  /// The route as the devices line names it: `iPhone Microphone · Speaker`.
  static func describeRoute() -> String {
    let route = AVAudioSession.sharedInstance().currentRoute
    let input = route.inputs.map(\.portName).joined(separator: ", ")
    let output = route.outputs.map(\.portName).joined(separator: ", ")
    return "\(input.isEmpty ? "no microphone" : input) · \(output.isEmpty ? "no output" : output)"
  }

  // MARK: - on the queue

  private func configureSession() throws {
    var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothA2DP]
    if #available(iOS 26.0, *) { options.insert(.allowBluetoothHFP) } else { options.insert(.allowBluetooth) }
    try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
    try session.setActive(true)
    log(
      "call_audio",
      [
        "action": "session", "ok": true, "category": "playAndRecord", "mode": session.mode.rawValue,
        "other_audio": session.isOtherAudioPlaying, "input_available": session.isInputAvailable,
        "rate": session.sampleRate, "io_buffer_ms": (session.ioBufferDuration * 1000).rounded(),
        "route": Self.describeRoute(),
      ])
  }

  private func buildEngine() throws {
    let engine = AVAudioEngine()
    // On a stopped engine, before anything starts: the input and output both run through voice processing.
    do {
      try engine.inputNode.setVoiceProcessingEnabled(true)
      log(
        "call_audio", ["action": "voice_processing", "ok": true, "enabled": engine.inputNode.isVoiceProcessingEnabled])
    } catch {
      // The call still works, with echo; say so where a bad call's log will show it.
      log("call_audio", ["action": "voice_processing", "ok": false, "message": describe(error)])
    }
    let player = AVAudioPlayerNode()
    engine.attach(player)
    self.engine = engine
    self.player = player
    playerFormat = nil
    builtAt = nowMs
    watchConfiguration(of: engine)
  }

  private func connectPlayer() throws {
    guard let engine, let player else { throw CallAudioError("no audio engine") }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: outRate, channels: 1) else {
      throw CallAudioError("no playback format at \(outRate) Hz")
    }
    engine.connect(player, to: engine.mainMixerNode, format: format)
    playerFormat = format
    let mixer = engine.mainMixerNode
    if mixTapInstalled { mixer.removeTap(onBus: 0) }
    mixer.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
      guard let self, let data = buffer.floatChannelData else { return }
      var peak: Float = 0
      for c in 0..<Int(buffer.format.channelCount) {
        for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(data[c][i])) }
      }
      self.queue.async {
        self.mixPeak = max(self.mixPeak, peak)
        self.mixBuffers += 1
      }
    }
    mixTapInstalled = true
  }

  private func startEngine(why: String) throws {
    guard let engine else { throw CallAudioError("no audio engine") }
    guard !engine.isRunning else { return }
    engine.prepare()
    do {
      try engine.start()
      log("call_audio", ["action": "engine_start", "why": why, "ok": true])
    } catch {
      var fields: [String: Any] = ["action": "engine_start", "why": why, "ok": false, "message": describe(error)]
      fields.merge(ErrorDetail.fields(error)) { a, _ in a }
      fields.merge(failureState(engine)) { a, _ in a }
      log("call_audio", fields)
      throw error
    }
  }

  /// #441, story 208: what the phone's audio looked like when a start failed — the 'what' (unspecified) error on
  /// 2026-10-20 came with nothing to say what refused.
  private func failureState(_ engine: AVAudioEngine) -> [String: Any] {
    func describe(_ f: AVAudioFormat) -> String { "\(Int(f.sampleRate)) Hz × \(f.channelCount)" }
    return [
      "category": session.category.rawValue, "mode": session.mode.rawValue, "rate": session.sampleRate,
      "route": Self.describeRoute(), "other_audio": session.isOtherAudioPlaying,
      "secondary_silenced": session.secondaryAudioShouldBeSilencedHint, "input_available": session.isInputAvailable,
      "input_channels": session.inputNumberOfChannels, "output_channels": session.outputNumberOfChannels,
      "app_state": lock.withLock { appState }, "since_build_ms": (nowMs - builtAt).rounded(),
      "in_vp": engine.inputNode.isVoiceProcessingEnabled,
      "mic_hw_format": describe(engine.inputNode.inputFormat(forBus: 0)),
      "mic_format": describe(engine.inputNode.outputFormat(forBus: 0)),
      "out_format": describe(engine.outputNode.inputFormat(forBus: 0)),
      "out_hw_format": describe(engine.outputNode.outputFormat(forBus: 0)),
    ]
  }

  private func armTap() throws {
    guard let engine else { throw CallAudioError("no audio engine") }
    let input = engine.inputNode
    if tapInstalled { input.removeTap(onBus: 0) }
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      tapInstalled = false
      throw CallAudioError("no microphone input (format \(format))")
    }
    micDeadline = currentMicDeadline()
    lock.withLock { publishedMicDeadline = micDeadline }
    let rate = format.sampleRate
    log(
      "call_audio",
      [
        "action": "mic_arm", "rate": rate, "channels": Int(format.channelCount),
        "deadline_s": (micStallRearm ? CallWatchdog.micStallMs : micDeadline.ms) / 1000,
        "why": micStallRearm ? "mid_call_stall" : micDeadline.why,
        "other_audio": session.isOtherAudioPlaying,
        "input_available": session.isInputAvailable, "route": Self.describeRoute(),
      ])
    firstBufferLogged = false
    let wasRunning = engine.isRunning
    input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(rate / 10), format: format) { [weak self] buffer, _ in
      guard let self, let data = buffer.floatChannelData else { return }
      let samples = Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength)))
      self.queue.async { self.onTapBuffer(samples, rate: rate) }
    }
    tapInstalled = true
    armedAt = nowMs
    lastBufferAt = 0
    // #146: with voice processing on, the engine started for playback is stopped again by the time the mic arms
    // (before the tap or by it); started again as it was, the player kept its clock but fed the mixer silence
    // (rx_peak 0.87, mix_peak 0 on the phone). Whatever stopped it, connect the player afresh before the start.
    if !engine.isRunning, playerFormat != nil {
      log(
        "call_audio",
        ["action": "reconnect_player", "why": "engine stopped before the mic started it", "was_running": wasRunning])
      try connectPlayer()
    }
    try startEngine(why: "mic")
    if playerFormat != nil, let player, !player.isPlaying { player.play() }
  }

  private func onTapBuffer(_ samples: [Float], rate: Double) {
    guard let listener = micListener else { return }
    lastBufferAt = nowMs
    micStallRearm = false
    if !firstBufferLogged {
      firstBufferLogged = true
      log(
        "call_audio",
        ["action": "mic_first_buffer", "samples": samples.count, "rate": rate, "after_ms": (nowMs - armedAt).rounded()])
    }
    if health == CallWatchdog.micStopped { setHealth(nil) }
    main { listener(samples, rate) }
  }

  /// Everything down and up again on the same session and the same engine settings.
  /// `playing` / `listening`: what to bring back, for a retry after a failed rebuild already lost the player.
  private func rebuild(why: String, playing: Bool? = nil, listening: Bool? = nil) throws {
    let wasListening = listening ?? (micListener != nil)
    let wasPlaying = playing ?? (playerFormat != nil)
    firstLoudRxAt = nil  // what was scheduled goes with the engine; the next window judges fresh audio (#199)
    // The stream's alignment stays (#442): a rebuild is local, and the bridge's bytes carry on where they were.
    lastScheduledAt = 0
    micStallRearm = false
    if wasPlaying {
      // #578: how far the old player got, read before it goes (the watchdog's last reading when its clock is gone),
      // and the tail cut there: what plays again on the new graph starts at its zero.
      let heardTo = max(currentPlayerTime(), heardPlayerS)
      tail.rebase(at: heardTo)
      heardPlayerS = 0
      let keepS = tail.durationS
      lock.withLock {
        // What the old player held beyond what plays again is what the rebuild lost.
        scheduledS -= max(0, playhead - heardTo - keepS)
        playhead = keepS
        playerTimeS = 0
      }
    }
    teardownEngineOnly()
    try configureSession()
    try buildEngine()
    if wasPlaying {
      try connectPlayer()
      try startEngine(why: why)
      player?.play()
      let keep = tail.unplayed(at: 0)
      if let player, let format = playerFormat, schedule(keep, on: player, format: format) {
        lastScheduledAt = nowMs
        log("call_audio", ["action": "requeue", "why": why, "kept_s": (tail.durationS * 100).rounded() / 100])
      }
      clockPrev = 0
      clockAdvancedAt = nowMs
    }
    if wasListening { try armTap() }
  }

  /// A heal's rebuild, tried again when it fails (#186: a failure used to leave the engine stopped, so the rest of
  /// the call was dead air in both directions). After the last try the call says its audio is gone.
  private func healingRebuild(
    why: String, attempt: Int = 0, ticket: Int? = nil, playing: Bool? = nil, listening: Bool? = nil
  ) {
    let ticket = ticket ?? healGate.begin()
    let playing = playing ?? (playerFormat != nil)
    let listening = listening ?? (micListener != nil)
    do {
      try rebuild(why: why, playing: playing, listening: listening)
      rebuildRetryPending = false
      if attempt > 0 { log("call_heal", ["action": "rebuild", "why": why, "ok": true, "attempt": attempt + 1]) }
    } catch {
      let retries = CallWatchdog.rebuildRetryMs
      log(
        "call_heal",
        [
          "action": "rebuild", "why": why, "ok": false, "attempt": attempt + 1, "message": describe(error),
          "retry_in_ms": attempt < retries.count ? retries[attempt] : -1,
        ])
      guard attempt < retries.count else {
        rebuildRetryPending = false
        return setHealth(CallWatchdog.audioGone)
      }
      rebuildRetryPending = true
      queue.asyncAfter(deadline: .now() + retries[attempt] / 1000) { [weak self] in
        guard let self else { return }
        // The call ended or restarted, or a newer heal took over: this retry is not this call's any more.
        guard self.healGate.isCurrent(ticket), !self.observers.isEmpty else {
          return self.log("call_heal", ["action": "retry_dropped", "why": why, "attempt": attempt + 2])
        }
        self.healingRebuild(why: why, attempt: attempt + 1, ticket: ticket, playing: playing, listening: listening)
      }
    }
  }

  private func currentPlayerTime() -> Double {
    guard let player, let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid,
      let t = player.playerTime(forNodeTime: nodeTime), t.sampleRate > 0
    else { return 0 }
    return Double(t.sampleTime) / t.sampleRate
  }

  // MARK: - the watchdog

  private func startWatchdog() {
    guard watchdog == nil else { return }
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(50))
    timer.setEventHandler { [weak self] in self?.tick() }
    watchdog = timer
    timer.resume()
  }

  private var ticks = 0

  private func tick() {
    let now = nowMs
    let t = currentPlayerTime()
    lock.withLock { playerTimeS = t }
    if t > 0 {
      heardPlayerS = t
      tail.prune(before: t)  // an idle tail empties as the player drains
    }
    // The clock: polled every 50 ms until it runs; the greeting waits on it (#95).
    if playerFormat != nil, !clockLive {
      if t > 0 {
        clockLive = true
        clockPrev = t
        clockAdvancedAt = now
        log("call_audio", ["action": "clock_running", "after_ms": (now - openedAt).rounded()])
      } else if now - openedAt >= CallWatchdog.clockStartMs, !clockReopened {
        clockReopened = true
        log("call_heal", ["action": "reopen_playback", "why": "output clock has not started after 2 s"])
        healingRebuild(why: "clock")
        openedAt = nowMs
      }
    }
    ticks += 1
    guard ticks % 10 == 0 else { return }  // the rest twice a second

    if ticks % 100 == 0, playerFormat != nil { logOutputLevel() }

    // The mic: a tap that went quiet gets re-armed; three times and it is a fact.
    // #423: a tap re-armed after a mid-call stall keeps the ordinary grace; only startup gets the longer window.
    let starting = lastBufferAt == 0 && !micStallRearm
    if starting {
      micDeadline = micDeadline.extended(by: currentMicDeadline())
      lock.withLock { publishedMicDeadline = micDeadline }
    }
    let mic = CallWatchdog.mic(
      now: now, armed: tapInstalled && micListener != nil, paused: paused, armedAt: armedAt, lastBufferAt: lastBufferAt,
      startupDeadlineMs: starting ? micDeadline.ms : CallWatchdog.micStallMs)
    if mic == .stalled {
      if micStalls < CallWatchdog.micStallsBeforeGivingUp {
        micStalls += 1
        if lastBufferAt != 0 { micStallRearm = true }
        log(
          "call_heal",
          [
            "action": "rearm_tap", "why": "mic stalled", "no_buffer_ms": (now - max(lastBufferAt, armedAt)).rounded(),
            "attempt": micStalls, "of": CallWatchdog.micStallsBeforeGivingUp,
            "deadline_s": (starting ? micDeadline.ms : CallWatchdog.micStallMs) / 1000,
            "deadline_why": starting ? micDeadline.why : "mid_call_stall",
          ])
        do { try armTap() } catch {
          log("call_heal", ["action": "rearm_tap", "ok": false, "message": describe(error)])
        }
      } else if health != CallWatchdog.micStopped {
        log("call_heal", ["action": "give_up_tap", "why": "mic still stalled after re-arms"])
        setHealth(CallWatchdog.micStopped)
      }
    }

    // The output: audio due, a frame scheduled lately, and a clock that is not moving.
    guard clockLive else { return }
    let head = lock.withLock { playhead }
    let verdict = CallWatchdog.output(
      now: now, currentTime: t, previousTime: clockPrev, previousCheckAt: clockAdvancedAt, playhead: head,
      lastScheduledAt: lastScheduledAt)
    if t > clockPrev {
      clockPrev = t
      clockAdvancedAt = now
      if health == CallWatchdog.audioNotPlaying { setHealth(nil) }
    }
    if verdict == .stalled, now - lastReopenAt >= CallWatchdog.reopenMinGapMs {
      lastReopenAt = now
      log("call_heal", ["action": "reopen_playback", "why": "output clock stalled", "at_s": t, "due_s": head - t])
      setHealth(CallWatchdog.audioNotPlaying)
      healingRebuild(why: "output stall")
    }
  }

  /// #146: what came in, what the mixer rendered, and everything between the mixer and the speaker.
  private func logOutputLevel() {
    guard let engine else { return }
    // #146's net: Larry's audio arrived and was scheduled, yet the mixer rendered nothing for five seconds.
    let silentMixer = CallWatchdog.silentMixer(
      now: nowMs, firstLoudRxAt: firstLoudRxAt, mixBuffers: mixBuffers, mixPeak: mixPeak)
    let out = engine.outputNode
    let outFormat = out.outputFormat(forBus: 0)
    let outputs = session.currentRoute.outputs.map { "\($0.portName) [\($0.portType.rawValue)]" }
    log(
      "call_out_level",
      [
        "rx_peak": (Double(rxPeak) * 1000).rounded() / 1000, "mix_peak": (Double(mixPeak) * 1000).rounded() / 1000,
        "mix_buffers": mixBuffers, "engine_running": engine.isRunning, "player_playing": player?.isPlaying ?? false,
        "player_volume": player?.volume ?? -1, "mixer_volume": engine.mainMixerNode.outputVolume,
        "session_volume": session.outputVolume, "out_rate": outFormat.sampleRate,
        "out_channels": Int(outFormat.channelCount),
        "out_vp": out.isVoiceProcessingEnabled, "in_vp": engine.inputNode.isVoiceProcessingEnabled,
        "category": session.category.rawValue, "mode": session.mode.rawValue, "outputs": outputs,
        "player_rate": playerFormat?.sampleRate ?? 0, "session_rate": session.sampleRate,
        "io_buffer_ms": (session.ioBufferDuration * 1000).rounded(),
      ])
    // #442: how Larry's frames arrived and were queued this window; nothing when none came.
    if !window.isEmpty {
      log(
        "call_playback",
        window.fields.merging(["carrying": rxStream.carrying, "odd_total": rxStream.oddFrames]) { _, new in new })
      window = PlaybackWindow()
    }
    let heals = silentMixer && nowMs - lastReopenAt >= CallWatchdog.reopenMinGapMs
    firstLoudRxAt = CallWatchdog.carriedLoudRx(firstLoudRxAt: firstLoudRxAt, mixPeak: mixPeak, healed: heals)
    rxPeak = 0
    mixPeak = 0
    mixBuffers = 0
    if heals {
      lastReopenAt = nowMs
      log("call_heal", ["action": "reopen_playback", "why": "mixer silent while Larry's audio arrives"])
      setHealth(CallWatchdog.audioNotPlaying)
      healingRebuild(why: "silent mixer")
    }
  }

  // MARK: - interruptions and route changes

  private func observe() {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: nil) {
        [weak self] note in
        let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
        let ended = AVAudioSession.InterruptionType(rawValue: raw) == .ended
        self?.queue.async { self?.onInterruption(ended: ended) }
      })
    observers.append(
      center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: nil) {
        [weak self] note in
        let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
        let reason = AVAudioSession.RouteChangeReason(rawValue: raw).map(Self.name) ?? "\(raw)"
        self?.queue.async {
          self?.log("call_audio", ["action": "route_change", "reason": reason, "route": Self.describeRoute()])
        }
      })
    observers.append(
      center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: nil) {
        [weak self] _ in
        self?.queue.async { self?.onReset(why: "media services reset") }
      })
  }

  /// A configuration change (a new hardware rate, a new route) stops the engine; rebuild while a call wants it.
  private var configObserver: NSObjectProtocol?

  private func watchConfiguration(of engine: AVAudioEngine) {
    if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
    configObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
    ) { [weak self] _ in
      self?.queue.async { self?.onReset(why: "engine configuration change") }
    }
  }

  private var builtAt = 0.0

  private func onReset(why: String) {
    guard let engine else { return }
    // Our own build (voice processing, a new connection) posts the same notification; only a stopped engine that
    // we did not just make needs rebuilding.
    if why == "engine configuration change", engine.isRunning || nowMs - builtAt < 1000 {
      log("call_audio", ["action": "configuration_change", "running": engine.isRunning, "rebuilt": false])
      return
    }
    log("call_audio", ["action": "rebuild", "why": why, "route": Self.describeRoute()])
    do { try rebuild(why: why) } catch {
      log("call_audio", ["action": "rebuild", "ok": false, "message": describe(error)])
    }
  }

  private func onInterruption(ended: Bool) {
    log("call_audio", ["action": "interruption", "kind": ended ? "ended" : "began"])
    guard engine != nil else { return }
    if !ended {
      paused = true
      return
    }
    paused = false
    // Fable on #578: a pause, not a heal; what was queued before a phone call is stale after it.
    tail.reset()
    heardPlayerS = 0
    do {
      try rebuild(why: "interruption ended")
      log("call_audio", ["action": "resumed", "ok": true])
    } catch {
      log("call_audio", ["action": "resumed", "ok": false, "message": describe(error)])
    }
  }

  private static func name(_ reason: AVAudioSession.RouteChangeReason) -> String {
    switch reason {
    case .newDeviceAvailable: return "new_device"
    case .oldDeviceUnavailable: return "device_gone"
    case .categoryChange: return "category"
    case .override: return "override"
    case .wakeFromSleep: return "wake"
    case .noSuitableRouteForCategory: return "no_route"
    case .routeConfigurationChange: return "configuration"
    default: return "unknown"
    }
  }

  // MARK: - teardown

  private func teardownEngineOnly() {
    if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
    configObserver = nil
    if let engine {
      if tapInstalled { engine.inputNode.removeTap(onBus: 0) }
      if mixTapInstalled { engine.mainMixerNode.removeTap(onBus: 0) }
      player?.stop()
      engine.stop()
    }
    tapInstalled = false
    mixTapInstalled = false
    engine = nil
    player = nil
    playerFormat = nil
  }

  private func teardown() {
    watchdog?.cancel()
    watchdog = nil
    teardownEngineOnly()
    for o in observers { NotificationCenter.default.removeObserver(o) }
    observers = []
    paused = false
    clockLive = false
    tail.reset()
    heardPlayerS = 0
    rebuildRetryPending = false
    lock.withLock {
      playbackOpen = false
      scheduledS = 0
      playhead = 0
      playerTimeS = 0
    }
  }

  private func setHealth(_ problem: String?) {
    guard health != problem else { return }
    health = problem
    main { [weak self] in self?.onHealth?(problem) }
  }

  private func main(_ block: @escaping () -> Void) { DispatchQueue.main.async(execute: block) }
}

struct CallAudioError: Error, LocalizedError {
  let message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}
