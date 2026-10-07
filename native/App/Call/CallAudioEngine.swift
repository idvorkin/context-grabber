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
  private var micStalls = 0
  private var watchdog: DispatchSourceTimer?
  private var observers: [NSObjectProtocol] = []
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

  /// The output, read from main for the stats line: guarded by `lock`.
  private let lock = NSLock()
  private var scheduledS = 0.0
  private var playhead = 0.0
  private var playerTimeS = 0.0
  private var playbackOpen = false

  init(log: @escaping @Sendable (String, [String: Any]) -> Void) {
    self.log = log
  }

  private var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

  // MARK: - CallAudio

  func prepare(_ done: @escaping (Error?) -> Void) {
    AVAudioApplication.requestRecordPermission { [self] granted in
      queue.async { [self] in
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
      do {
        try connectPlayer()
        try startEngine(why: "playback")
        player?.play()
        lock.withLock {
          playbackOpen = true
          scheduledS = 0
          playhead = 0
          playerTimeS = 0
        }
        openedAt = nowMs
        clockLive = false
        clockReopened = false
        log("call_audio", ["action": "playback_open", "out_rate": outRate, "ok": true])
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
  /// session re-asserted. Larry's queued audio is lost (a short gap); the next frames play.
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
      guard let player, let format = playerFormat, let engine, engine.isRunning else { return }
      let samples = PCM.pcm16ToFloat(pcm)
      for x in samples { rxPeak = max(rxPeak, abs(x)) }
      if rxPeak > 0.01, firstLoudRxAt == nil { firstLoudRxAt = nowMs }
      guard !samples.isEmpty,
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
      else { return }
      buffer.frameLength = AVAudioFrameCount(samples.count)
      samples.withUnsafeBufferPointer { src in
        buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
      }
      player.scheduleBuffer(buffer, completionHandler: nil)
      let duration = Double(samples.count) / outRate
      let now = currentPlayerTime()
      lock.withLock {
        scheduledS += duration
        playhead = max(playhead, now) + duration
      }
      lastScheduledAt = nowMs
      if !player.isPlaying { player.play() }
    }
  }

  /// Barge-in: everything of Larry's not yet heard goes. The player's clock restarts from zero.
  func flush() {
    queue.async { [self] in
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
      if engine?.isRunning == true { player.play() }
    }
  }

  func stop() {
    queue.async { [self] in
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
        scheduledS: scheduledS, playedS: max(0, scheduledS - queued), clockRunning: playerTimeS > 0, pendingS: 0)
    }
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
      log("call_audio", ["action": "voice_processing", "ok": true, "enabled": engine.inputNode.isVoiceProcessingEnabled])
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
      log("call_audio", ["action": "engine_start", "why": why, "ok": false, "message": describe(error)])
      throw error
    }
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
    let rate = format.sampleRate
    log(
      "call_audio",
      [
        "action": "mic_arm", "rate": rate, "channels": Int(format.channelCount), "other_audio": session.isOtherAudioPlaying,
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
      log("call_audio", ["action": "reconnect_player", "why": "engine stopped before the mic started it", "was_running": wasRunning])
      try connectPlayer()
    }
    try startEngine(why: "mic")
    if playerFormat != nil, let player, !player.isPlaying { player.play() }
  }

  private func onTapBuffer(_ samples: [Float], rate: Double) {
    guard let listener = micListener else { return }
    lastBufferAt = nowMs
    if !firstBufferLogged {
      firstBufferLogged = true
      log("call_audio", ["action": "mic_first_buffer", "samples": samples.count, "rate": rate, "after_ms": (nowMs - armedAt).rounded()])
    }
    if health == CallWatchdog.micStopped { setHealth(nil) }
    main { listener(samples, rate) }
  }

  /// Everything down and up again on the same session and the same engine settings.
  /// `playing` / `listening`: what to bring back, for a retry after a failed rebuild already lost the player.
  private func rebuild(why: String, playing: Bool? = nil, listening: Bool? = nil) throws {
    let wasListening = listening ?? (micListener != nil)
    let wasPlaying = playing ?? (playerFormat != nil)
    teardownEngineOnly()
    try configureSession()
    try buildEngine()
    if wasPlaying {
      try connectPlayer()
      try startEngine(why: why)
      player?.play()
      lock.withLock {
        scheduledS -= max(0, playhead - playerTimeS)
        playhead = 0
        playerTimeS = 0
      }
      clockPrev = 0
      clockAdvancedAt = nowMs
    }
    if wasListening { try armTap() }
  }

  /// A heal's rebuild, tried again when it fails (#186: a failure used to leave the engine stopped, so the rest of
  /// the call was dead air in both directions). After the last try the call says its audio is gone.
  private func healingRebuild(why: String, attempt: Int = 0, playing: Bool? = nil, listening: Bool? = nil) {
    let playing = playing ?? (playerFormat != nil)
    let listening = listening ?? (micListener != nil)
    do {
      try rebuild(why: why, playing: playing, listening: listening)
      if attempt > 0 { log("call_heal", ["action": "rebuild", "why": why, "ok": true, "attempt": attempt + 1]) }
    } catch {
      let retries = CallWatchdog.rebuildRetryMs
      log("call_heal", [
        "action": "rebuild", "why": why, "ok": false, "attempt": attempt + 1, "message": describe(error),
        "retry_in_ms": attempt < retries.count ? retries[attempt] : -1,
      ])
      guard attempt < retries.count else { return setHealth(CallWatchdog.audioGone) }
      queue.asyncAfter(deadline: .now() + retries[attempt] / 1000) { [weak self] in
        guard let self, !self.observers.isEmpty else { return }  // the call ended meanwhile
        self.healingRebuild(why: why, attempt: attempt + 1, playing: playing, listening: listening)
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
    let mic = CallWatchdog.mic(
      now: now, armed: tapInstalled && micListener != nil, paused: paused, armedAt: armedAt, lastBufferAt: lastBufferAt)
    if mic == .stalled {
      if micStalls < CallWatchdog.micStallsBeforeGivingUp {
        micStalls += 1
        log(
          "call_heal",
          [
            "action": "rearm_tap", "why": "mic stalled", "no_buffer_ms": (now - max(lastBufferAt, armedAt)).rounded(),
            "attempt": micStalls, "of": CallWatchdog.micStallsBeforeGivingUp,
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
        "session_volume": session.outputVolume, "out_rate": outFormat.sampleRate, "out_channels": Int(outFormat.channelCount),
        "out_vp": out.isVoiceProcessingEnabled, "in_vp": engine.inputNode.isVoiceProcessingEnabled,
        "category": session.category.rawValue, "mode": session.mode.rawValue, "outputs": outputs,
      ])
    rxPeak = 0
    firstLoudRxAt = nil
    mixPeak = 0
    mixBuffers = 0
    if silentMixer, nowMs - lastReopenAt >= CallWatchdog.reopenMinGapMs {
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
