//  When the Gym Timer and breathing take and let go of the audio, the lit screen and the card (TimerSession,
//  BreathSession), against a fake phone and a clock moved by hand: what the simulator smoke used to wait 73 seconds
//  of real time to see.

import XCTest

@testable import ContextCore

/// The phone's shared switches: one lit-screen flag and one lock-screen card, whichever session sets them.
final class FakePhone {
  var keepAwake = false {
    didSet { awake.append(keepAwake) }
  }
  /// Every change of the switch, in order.
  var awake: [Bool] = []
  /// What reached the lock screen, as LiveActivityController pushes it: `kind:title` when the content's key
  /// changed, `end:kind:reason` when a card was taken down.
  var cards: [String] = []
  private var lastKey: String?
  private var up: LiveActivityKind?

  func sync(_ content: LiveActivityContent?, kind: LiveActivityKind) {
    guard let content else {
      if up == kind { end(kind, reason: "reset") }
      return
    }
    let key = "\(kind.rawValue)|\(content.key)"
    guard key != lastKey else { return }
    lastKey = key
    up = content.finished ? nil : kind
    cards.append("\(kind.rawValue):\(content.title)")
  }

  func end(_ kind: LiveActivityKind, reason: String) {
    cards.append("end:\(kind.rawValue):\(reason)")
    if up == kind {
      up = nil
      lastKey = nil
    }
  }
}

/// A SessionHost whose clock moves only when a test says, in whole milliseconds.
final class FakeSessionHost: SessionHost {
  let phone: FakePhone
  private(set) var nowMs: Int = 1_000_000_000
  var now: Double { Double(nowMs) / 1000 }

  private var lookEveryMs: Int?
  private var nextLookMs = 0
  private var look: (() -> Void)?
  private(set) var clockStarts = 0
  private(set) var clockStops = 0
  var clockRunning: Bool { look != nil }

  private final class Pending {
    let due: Int
    let seq: Int
    let block: () -> Void
    var cancelled = false
    init(due: Int, seq: Int, block: @escaping () -> Void) {
      self.due = due
      self.seq = seq
      self.block = block
    }
  }
  private var pending: [Pending] = []
  private var seq = 0

  private(set) var announced: [String] = []
  private(set) var logs: [(type: String, fields: [String: Any])] = []

  init(phone: FakePhone = FakePhone()) {
    self.phone = phone
  }

  func startClock(every seconds: Double, _ look: @escaping () -> Void) {
    clockStarts += 1
    let every = Int((seconds * 1000).rounded())
    lookEveryMs = every
    nextLookMs = nowMs + every
    self.look = look
  }

  func stopClock() {
    clockStops += 1
    look = nil
    lookEveryMs = nil
  }

  func after(_ ms: Int, _ block: @escaping () -> Void) -> () -> Void {
    seq += 1
    let item = Pending(due: nowMs + ms, seq: seq, block: block)
    pending.append(item)
    return { item.cancelled = true }
  }

  var keepAwake: Bool {
    get { phone.keepAwake }
    set { phone.keepAwake = newValue }
  }

  func syncCard(_ content: LiveActivityContent?, kind: LiveActivityKind, stepEndsAt: Double?) {
    phone.sync(content, kind: kind)
  }

  func endCard(_ kind: LiveActivityKind, reason: String) { phone.end(kind, reason: reason) }

  func announce(_ text: String) { announced.append(text) }

  func log(_ type: String, _ fields: [String: Any]) { logs.append((type, fields)) }

  /// Move the clock on `seconds`, looking on the clock's beat and running whatever falls due, in time order.
  func run(_ seconds: Double) {
    let end = nowMs + Int((seconds * 1000).rounded())
    while true {
      let timer = pending.filter { !$0.cancelled && $0.due <= end }.min { ($0.due, $0.seq) < ($1.due, $1.seq) }
      let lookAt = look != nil && nextLookMs <= end ? nextLookMs : nil
      if let timer, timer.due <= (lookAt ?? Int.max) {
        pending.removeAll { $0 === timer }
        nowMs = max(nowMs, timer.due)
        timer.block()
      } else if let lookAt, let look, let every = lookEveryMs {
        nowMs = lookAt
        nextLookMs = lookAt + every
        look()
      } else {
        break
      }
    }
    nowMs = end
  }

  /// The app away: the clock jumps on with nothing looking and nothing fired.
  func jump(_ seconds: Double) {
    nowMs += Int((seconds * 1000).rounded())
    if lookEveryMs != nil { nextLookMs = nowMs + (lookEveryMs ?? 0) }
    pending.removeAll { $0.due <= nowMs }
  }

  func logged(_ type: String) -> [[String: Any]] { logs.filter { $0.type == type }.map(\.fields) }
}

final class FakeTimerAudio: TimerAudio {
  var calls: [String] = []
  /// Each cue and when it played, in seconds on the host's clock.
  var cues: [(cue: TimerCue, at: Double)] = []
  private let host: FakeSessionHost
  init(host: FakeSessionHost) { self.host = host }

  func start() { calls.append("start") }
  func stop() { calls.append("stop") }
  func stopWhenReleased() { calls.append("stopWhenReleased") }
  func play(_ cue: TimerCue) {
    calls.append("cue:\(cue.rawValue)")
    cues.append((cue, host.now))
  }
  func setDucking(_ on: Bool) { calls.append(on ? "duck" : "base") }
  func release() { calls.append("release") }

  /// The duck window's half of the calls.
  var window: [String] { calls.filter { ["duck", "base", "release"].contains($0) } }
}

final class FakeBreathAudio: BreathAudio {
  var calls: [String] = []
  /// Every phrase and tone, by its file name.
  var said: [String] = []
  var keepAlive: [Bool] = []

  func say(_ phrase: BreathPhrase) {
    calls.append("say")
    said.append(phrase.rawValue)
  }
  func play(_ tone: BreathTone) {
    calls.append("play")
    said.append(tone.rawValue)
  }
  func hush() { calls.append("hush") }
  func keepAlive(_ on: Bool) {
    calls.append("keepAlive:\(on)")
    keepAlive.append(on)
  }
  func stop() { calls.append("stop") }
}

// MARK: - the Gym Timer

final class TimerSessionTests: XCTestCase {
  /// The smoke's workout: 10 s work, 10 s rest, 2 rounds, after the 5 s ready count. 35 s in all.
  private let shape = CustomPreset(work: 10, rest: 10, rounds: 2).profile
  private let host = FakeSessionHost()
  private lazy var audio = FakeTimerAudio(host: host)
  private var recorded: [TimerProfile] = []
  private lazy var session = TimerSession(profile: shape, host: host, audio: audio) { [unowned self] in
    self.recorded.append($0)
  }

  private func startedAt() -> Double {
    session.toggle()
    return host.now
  }

  func testEveryCueFallsWithinATenthOfItsSecond() {
    let t0 = startedAt()
    host.run(40)
    let heard = audio.cues.map { "\(Int(($0.at - t0).rounded(.down))):\($0.cue.rawValue)" }.joined(separator: " ")
    XCTAssertEqual(
      heard,
      "2:three 3:two 4:one 5:go 12:three 13:two 14:one 15:rest 22:three 23:two 24:one 25:go 32:three 33:two 34:one 35:done"
    )
    for cue in audio.cues {
      let past = (cue.at - t0) - (cue.at - t0).rounded(.down)
      XCTAssertLessThanOrEqual(past, TimerSession.lookEvery + 1e-9, "\(cue.cue) is \(past) s past its second")
    }
  }

  func testOneDuckWindowPerBoundaryEachLetGoOnce() {
    _ = startedAt()
    host.run(40)
    XCTAssertEqual(audio.window, Array(repeating: ["duck", "base", "release"], count: 4).flatMap { $0 })
    XCTAssertEqual(host.logged("timer_duck").filter { $0["action"] as? String == "open" }.count, 4)
    XCTAssertEqual(host.logged("timer_duck").filter { $0["action"] as? String == "released" }.count, 4)
  }

  func testTheWindowOpensASilentSecondBeforeTheThreeAndLetsGoABeatAfterGo() {
    let t0 = startedAt()
    host.run(1.05)
    XCTAssertEqual(audio.window, ["duck"], "open at four seconds left, before any word")
    XCTAssertTrue(audio.cues.isEmpty)
    host.run(5 - 1.05 + Double(DuckWindow.cueHoldMs) / 1000 - 0.05)
    XCTAssertEqual(audio.window, ["duck"], "held by three, two, one and go")
    XCTAssertEqual(audio.cues.map(\.cue), [.three, .two, .one, .go])
    host.run(0.1)
    XCTAssertEqual(audio.window, ["duck", "base", "release"], "let go \(DuckWindow.cueHoldMs) ms after go")
    XCTAssertEqual(host.now - t0, 6.55, accuracy: 0.001)
  }

  func testStartTakesTheSessionAndTheFinishLetsGoThroughTheLastWindow() {
    _ = startedAt()
    XCTAssertEqual(audio.calls.first, "start", "the session and its keepalive from START")
    host.run(35.05)
    XCTAssertEqual(host.logged("timer_finished").count, 1)
    XCTAssertEqual(recorded, [shape], "the finish is recorded once")
    XCTAssertFalse(host.clockRunning, "the clock stops at the finish")
    XCTAssertEqual(Array(audio.calls.suffix(2)), ["cue:done", "stopWhenReleased"], "done is still sounding")
    XCTAssertFalse(audio.calls.contains("stop"), "not let go under the done")
    host.run(Double(DuckWindow.finishHoldMs) / 1000 + 0.1)
    XCTAssertEqual(Array(audio.calls.suffix(2)), ["base", "release"], "the window's own release is the letting go")
    XCTAssertEqual(audio.calls.filter { $0 == "release" }.count, 4)
  }

  func testAFinishFoundOnComingBackLetsGoAtOnceAndReplaysNothing() {
    _ = startedAt()
    host.jump(60)
    session.catchUp()
    XCTAssertTrue(audio.cues.isEmpty, "nothing missed is replayed")
    XCTAssertEqual(session.state.phase, .done)
    XCTAssertEqual(audio.calls.last, "stop", "no window open: nothing to wait for")
    XCTAssertFalse(audio.calls.contains("stopWhenReleased"))
    XCTAssertEqual(host.logged("timer_catchup").first?["phase"] as? String, "done")
  }

  func testCatchUpInABoundarysSecondCallsOnlyThatBoundary() {
    _ = startedAt()
    host.jump(15.05)
    session.catchUp()
    XCTAssertEqual(audio.cues.map(\.cue), [.rest])
    XCTAssertEqual(audio.window, ["duck"])
  }

  func testAStopKeepsTheSessionAndStopsTheClockAndResumeCarriesOn() {
    _ = startedAt()
    host.run(7)
    session.toggle()
    XCTAssertTrue(session.state.isPaused)
    XCTAssertFalse(host.clockRunning)
    XCTAssertFalse(audio.calls.contains("stop"), "a stop keeps the session and its keepalive")
    XCTAssertEqual(host.logged("timer_pause").first?["round"] as? Int, 1)
    let heard = audio.cues.count
    host.run(30)
    XCTAssertEqual(audio.cues.count, heard, "nothing sounds while stopped")
    session.toggle()
    XCTAssertEqual(audio.calls.filter { $0 == "start" }.count, 2)
    XCTAssertEqual(host.logged("timer_start").last?["resumed"] as? Bool, true)
    host.run(8.05)
    XCTAssertEqual(audio.cues.last?.cue, .rest, "the round carries on from where it stopped")
  }

  func testResetMidWindowLetsGoOnceAndTheClosePendingNeverFires() {
    _ = startedAt()
    host.run(2.5)
    XCTAssertEqual(audio.window, ["duck"])
    session.reset(to: shape)
    XCTAssertEqual(Array(audio.calls.suffix(3)), ["stop", "base", "release"])
    host.run(5)
    XCTAssertEqual(audio.window, ["duck", "base", "release"], "one release, not two")
    XCTAssertFalse(host.clockRunning)
    XCTAssertEqual(session.state.phase, .idle)
    XCTAssertEqual(host.phone.cards.last, "end:gymTimer:reset")
  }

  func testTheCardIsPushedAtEachPhaseNotEverySecond() {
    _ = startedAt()
    host.run(40)
    XCTAssertEqual(
      host.phone.cards, ["gymTimer:GET READY", "gymTimer:WORK", "gymTimer:REST", "gymTimer:WORK", "gymTimer:DONE!"])
  }

  func testTheLitScreenFollowsTheTimersScreenNotTheWorkout() {
    session.appear(mode: "rounds", stopwatchRunning: false)
    XCTAssertTrue(host.phone.keepAwake)
    session.toggle()
    host.run(3)
    session.disappear(stopwatchRunning: false)
    XCTAssertEqual(host.phone.awake, [true, false], "given back on leaving, though the workout runs")
    let lines = host.logged("keep_awake")
    XCTAssertEqual(lines.map { $0["on"] as? Bool }, [true, false])
    XCTAssertEqual(lines.first?["reason"] as? String, "gym_timer")
    XCTAssertEqual(lines.last?["running"] as? Bool, true)
  }

  func testAWorkoutSurvivesLeavingTheTimer() {
    session.appear(mode: "rounds", stopwatchRunning: false)
    session.toggle()
    host.run(6)
    XCTAssertFalse(session.disappear(stopwatchRunning: true), "nothing let go")
    XCTAssertTrue(host.clockRunning)
    XCTAssertFalse(audio.calls.contains("stop"))
    XCTAssertFalse(host.phone.cards.contains { $0.hasPrefix("end:") }, "the card stays up")
    XCTAssertEqual(host.logged("keep_awake").last?["stopwatch"] as? Bool, true)
    host.run(10)
    XCTAssertEqual(audio.cues.last?.cue, .rest, "the cues kept sounding off the screen")
    XCTAssertEqual(host.phone.cards.last, "gymTimer:REST")
    host.jump(3.5)
    session.appear(mode: "stopwatch", stopwatchRunning: true)
    XCTAssertEqual(session.state.phase, .rest)
    XCTAssertEqual(session.state.timeLeft, 6, "shown where it is now")
    XCTAssertTrue(session.state.isRunning, "not a fresh timer")
    XCTAssertEqual(host.logged("keep_awake").last?["running"] as? Bool, true)
  }

  func testLeavingAStoppedWorkoutLetsGoOfTheSessionTheClockAndTheCard() {
    session.appear(mode: "rounds", stopwatchRunning: false)
    session.toggle()
    host.run(3)
    session.toggle()
    XCTAssertTrue(session.disappear(stopwatchRunning: false), "let go: the app puts back the saved settings")
    XCTAssertEqual(Array(audio.calls.suffix(3)), ["stop", "base", "release"])
    XCTAssertEqual(host.phone.cards.last, "end:gymTimer:leave")
    XCTAssertTrue(session.state.isPaused, "found paused where it was left")
  }

  func testYieldOffTheScreenPausesAndLetsGoOfTheSessionAndTheCard() {
    session.toggle()
    host.run(3)
    session.yield(to: "breathe")
    XCTAssertTrue(session.state.isPaused)
    XCTAssertEqual(host.logged("timer_yield").first?["to"] as? String, "breathe")
    XCTAssertEqual(host.logged("timer_yield").first?["on_screen"] as? Bool, false)
    XCTAssertEqual(Array(audio.calls.suffix(3)), ["stop", "base", "release"])
    XCTAssertEqual(host.phone.cards.last, "end:gymTimer:yield")
    XCTAssertFalse(host.clockRunning)
  }

  func testYieldOnTheScreenOnlyStopsTheClock() {
    session.appear(mode: "rounds", stopwatchRunning: false)
    session.toggle()
    host.run(8)
    session.yield(to: "call")
    XCTAssertTrue(session.state.isPaused)
    XCTAssertFalse(audio.calls.contains("stop"), "the session stays until RESET or leaving")
    XCTAssertFalse(host.phone.cards.contains { $0.hasPrefix("end:") })
    XCTAssertFalse(host.clockRunning)
  }

  func testAWorkoutThatIsNotRunningYieldsNothing() {
    session.yield(to: "cockpit")
    session.toggle()
    host.run(3)
    session.toggle()
    let calls = audio.calls
    session.yield(to: "cockpit")
    XCTAssertTrue(host.logged("timer_yield").isEmpty)
    XCTAssertEqual(audio.calls, calls)
  }

  func testAutostartLeavesARunningWorkoutAlone() {
    session.toggle()
    host.run(2)
    session.autostart(shape)
    XCTAssertTrue(session.state.isRunning)
    XCTAssertEqual(audio.calls.filter { $0 == "start" }.count, 1)
    XCTAssertEqual(host.logged("timer_autostart").first?["action"] as? String, "already_running")
  }

  func testAutostartResumesAPausedWorkoutAndRestartsAFinishedOne() {
    session.toggle()
    host.run(2)
    session.toggle()
    session.autostart(shape)
    XCTAssertTrue(session.state.isRunning)
    XCTAssertEqual(host.logged("timer_start").last?["resumed"] as? Bool, true)
    host.run(40)
    XCTAssertEqual(session.state.phase, .done)
    session.autostart(shape)
    XCTAssertEqual(host.logged("timer_reset").count, 1)
    XCTAssertEqual(session.state.phase, .prep)
    XCTAssertTrue(host.clockRunning)
  }

  func testAChoiceMidRunIsIgnoredAndAfterTheFinishIsAReset() {
    let other = CustomPreset(work: 20, rest: 0, rounds: 1).profile
    session.toggle()
    host.run(1)
    session.choose(other)
    XCTAssertEqual(session.profile, shape)
    host.run(40)
    session.restore(other)
    XCTAssertEqual(session.state.phase, .done, "a finished face stays finished")
    session.choose(other)
    XCTAssertEqual(session.profile, other)
    XCTAssertEqual(session.state.phase, .idle)
    XCTAssertEqual(host.logged("timer_reset").count, 1)
  }

  func testEveryStateChangeIsPublishedAfterItsCard() {
    var seen: [TimerPhase] = []
    session.onChange = { [unowned self] state in
      seen.append(state.phase)
      XCTAssertEqual(self.session.state, state)
    }
    session.toggle()
    host.run(40)
    XCTAssertEqual(seen.first, .prep)
    XCTAssertEqual(seen.last, .done)
    XCTAssertEqual(seen.count, 36, "once a second, never twice for one state")
  }
}

// MARK: - breathing

final class BreathSessionTests: XCTestCase {
  private let host = FakeSessionHost()
  private let audio = FakeBreathAudio()
  private var saved: [(TimeSpan, String)] = []
  private var recorded: [BreathPlan] = []
  /// The screen's model holds its session; the clock holds it only weakly.
  private var held: [BreathSession] = []

  private func make(_ cue: BreathCue) -> BreathSession {
    let session = BreathSession(
      cue: cue, host: host, audio: audio, saveMindful: { [unowned self] in self.saved.append(($0, $1)) },
      finished: { [unowned self] in self.recorded.append($0) })
    held.append(session)
    return session
  }

  func testEveryStepIsNoticedOnItsSecondAfterTheLeadIn() {
    let session = make(.voice)
    let plan = BreathPlan(breathSeconds: 2, cycles: 2)
    session.begin(plan)
    let t0 = host.now + BreathSession.voiceLeadIn
    host.run(20)
    let steps = host.logs.filter { $0.type == "breath_phase" || $0.type == "breath_finished" }
    XCTAssertEqual(
      steps.map { $0.fields["phase"] as? String ?? "done" },
      ["inhale", "holdFull", "exhale", "holdEmpty", "inhale", "holdFull", "exhale", "holdEmpty", "done"])
    let late = steps.compactMap { $0.fields["late_ms"] as? Int }
    XCTAssertLessThanOrEqual(late.max() ?? 999, 50, "never more than one look late")
    XCTAssertEqual(session.stage, .done)
    XCTAssertEqual(recorded, [plan])
    XCTAssertEqual(host.logged("breath_start").first?["lead_in_ms"] as? Int, 2000)
    XCTAssertGreaterThan(host.now, t0 + 16)
  }

  func testTheVoiceSaysEveryPhraseFromBeginToWellDone() {
    make(.voice).begin(BreathPlan(breathSeconds: 2, cycles: 2))
    host.run(20)
    XCTAssertEqual(
      audio.said,
      [
        "breath-begin", "breath-in", "breath-hold", "breath-out", "breath-hold-low", "breath-in", "breath-hold",
        "breath-out", "breath-hold-low", "breath-done",
      ])
  }

  func testTonesAreATonePerStepAndTheClosingWithNoLeadIn() {
    make(.tone).begin(BreathPlan(breathSeconds: 1, cycles: 1))
    XCTAssertEqual(host.logged("breath_start").first?["lead_in_ms"] as? Int, 0)
    host.run(6)
    XCTAssertEqual(audio.said, ["rising", "tick", "falling", "tick", "closing"])
  }

  func testOffIsSilentButStillKeepsTheSessionAlive() {
    make(.off).begin(BreathPlan(breathSeconds: 1, cycles: 1))
    host.run(6)
    XCTAssertTrue(audio.said.isEmpty)
    XCTAssertEqual(audio.keepAlive, [true, false])
  }

  func testTheLitScreenIsHeldForTheSessionAndGivenBackAtTheFinish() {
    make(.voice).begin(BreathPlan(breathSeconds: 2, cycles: 1))
    XCTAssertTrue(host.phone.keepAwake)
    host.run(12)
    XCTAssertEqual(host.phone.awake, [true, false])
    XCTAssertEqual(host.logged("keep_awake").map { $0["on"] as? Bool }, [true, false])
    XCTAssertEqual(host.logged("keep_awake").first?["reason"] as? String, "breathe")
  }

  func testTheKeepaliveRunsForTheSessionAndStopsAtTheEnd() {
    make(.voice).begin(BreathPlan(breathSeconds: 2, cycles: 1))
    XCTAssertEqual(audio.keepAlive, [true])
    host.run(12)
    XCTAssertEqual(audio.keepAlive, [true, false])
    XCTAssertFalse(host.clockRunning)
  }

  func testAPauseStopsTheKeepaliveAndTheCuesButKeepsTheLitScreen() {
    let session = make(.voice)
    session.begin(BreathPlan(breathSeconds: 2, cycles: 2))
    host.run(3)  // into the inhale
    session.togglePause()
    XCTAssertTrue(session.paused)
    XCTAssertEqual(audio.keepAlive, [true, false])
    XCTAssertEqual(audio.calls.last, "keepAlive:false")
    XCTAssertTrue(audio.calls.suffix(2).contains("hush"))
    XCTAssertTrue(host.phone.keepAwake, "the lit screen stays through a pause")
    XCTAssertEqual(host.logged("breath_pause").first?["reason"] as? String, "circle")
    let said = audio.said
    host.run(60)
    XCTAssertEqual(audio.said, said, "nothing moves on while paused")
    session.togglePause()
    XCTAssertEqual(audio.keepAlive, [true, false, true])
    XCTAssertEqual(audio.said, said, "the step is not announced again")
    host.run(1.1)
    XCTAssertEqual(audio.said.last, "breath-hold", "and the next step comes on time")
  }

  func testTheCardSaysReadyThenEachStepThenDone() {
    make(.voice).begin(BreathPlan(breathSeconds: 2, cycles: 2))
    host.run(20)
    XCTAssertEqual(
      host.phone.cards,
      ["breathe:Ready"]
        + Array(repeating: ["breathe:Inhale", "breathe:Hold", "breathe:Exhale", "breathe:Hold"], count: 2)
        .flatMap { $0 } + ["breathe:Done"])
  }

  func testAPauseAndResumeArePushedToTheCard() {
    let session = make(.tone)
    session.begin(BreathPlan(breathSeconds: 2, cycles: 1))
    host.run(1)
    session.togglePause()
    session.togglePause()
    XCTAssertEqual(host.phone.cards, ["breathe:Inhale", "breathe:PAUSED", "breathe:Inhale"])
  }

  func testBackLeavesAtOnceAndLetsGoOfEverythingButTheSession() {
    let session = make(.voice)
    session.begin(BreathPlan(breathSeconds: 2, cycles: 2))
    host.run(3)
    session.back()
    XCTAssertEqual(session.stage, .setup)
    XCTAssertFalse(host.clockRunning)
    XCTAssertEqual(audio.keepAlive.last, false)
    XCTAssertFalse(host.phone.keepAwake)
    XCTAssertEqual(host.phone.cards.last, "end:breathe:back")
    XCTAssertEqual(host.logged("mindful_skipped").count, 1, "under a minute is not saved")
    XCTAssertFalse(audio.calls.contains("stop"))
  }

  func testLeavingMidSessionIsBackThenTheAudioSessionAndTheCardGo() {
    let session = make(.voice)
    session.begin(BreathPlan(breathSeconds: 2, cycles: 2))
    host.run(3)
    session.disappear()
    XCTAssertEqual(host.logged("breath_exit").count, 1)
    XCTAssertEqual(audio.calls.last, "stop")
    XCTAssertEqual(Array(host.phone.cards.suffix(2)), ["end:breathe:back", "end:breathe:leave"])
    XCTAssertEqual(host.phone.awake, [true, false])
  }

  func testAHookPausesBySelfAtItsSecond() {
    let session = make(.tone)
    session.begin(BreathPlan(breathSeconds: 2, cycles: 2), pauseAt: 3)
    host.run(5)
    XCTAssertTrue(session.paused)
    XCTAssertEqual(host.logged("breath_pause").first?["reason"] as? String, "hook")
    XCTAssertEqual(host.logged("breath_pause").first?["phase"] as? String, "holdFull")
  }

  func testAFinishAndABackPastAMinuteGoToHealth() {
    make(.off).begin(BreathPlan(breathSeconds: 5, cycles: 4))  // 80 s
    host.run(81)
    XCTAssertEqual(saved.map(\.1), ["finished"])
    let session = make(.off)
    session.begin(BreathPlan(breathSeconds: 5, cycles: 4))
    host.run(70)
    session.back()
    XCTAssertEqual(saved.map(\.1), ["finished", "back"])
    XCTAssertEqual(saved.last.map { ($0.0.end - $0.0.start) / 1000 } ?? 0, 70, accuracy: 0.1)
  }

  func testVoiceOverHearsEachStepAndDone() {
    make(.off).begin(BreathPlan(breathSeconds: 1, cycles: 1))
    host.run(6)
    XCTAssertEqual(host.announced, ["Inhale", "Hold", "Exhale", "Hold", "Done"])
  }

  func testTheLitScreenIsOneSwitchAndBreathingWritesItOnlyWhenItChanges() {
    host.phone.keepAwake = true  // another screen turned it on
    make(.off).begin(BreathPlan(breathSeconds: 1, cycles: 1))
    XCTAssertTrue(host.logged("keep_awake").isEmpty, "already on: not written, not logged")
    host.run(6)
    XCTAssertEqual(host.phone.awake, [true, false], "off at the finish, whoever turned it on")
  }
}

// MARK: - the two meeting

final class TimerAndBreathingTests: XCTestCase {
  private let phone = FakePhone()

  func testOpeningBreathingPausesAWorkoutLeftRunningAndTakesTheCard() {
    let timerHost = FakeSessionHost(phone: phone)
    let timerAudio = FakeTimerAudio(host: timerHost)
    let timer = TimerSession(profile: TimerProfile.presets[0].profile, host: timerHost, audio: timerAudio)
    timer.appear(mode: "rounds", stopwatchRunning: false)
    timer.toggle()
    timerHost.run(8)
    timer.disappear(stopwatchRunning: false)  // Done, the workout running
    // Breathing opens: the floor asks the timer to yield first, then the screen begins.
    timer.yield(to: "breathe")
    let breathHost = FakeSessionHost(phone: phone)
    let breath = BreathSession(cue: .tone, host: breathHost, audio: FakeBreathAudio())
    breath.begin(BreathPlan(breathSeconds: 2, cycles: 1))
    XCTAssertTrue(timer.state.isPaused)
    XCTAssertEqual(timerAudio.calls.last, "stop", "the workout let go of the audio session before breathing began")
    XCTAssertEqual(Array(phone.cards.suffix(2)), ["end:gymTimer:yield", "breathe:Inhale"])
    XCTAssertEqual(phone.awake, [true, false, true])
    breathHost.run(10)
    XCTAssertTrue(timer.state.isPaused, "found paused there, ready to RESUME")
    timer.toggle()
    XCTAssertEqual(phone.cards.last, "gymTimer:WORK", "RESUME takes the card back")
  }

  /// The rule as it stands (the spec's "the last screen to set it wins"): the timer's screen going after breathing
  /// began turns the shared switch off under the breathing.
  func testTheLastScreenToSetTheLitScreenWins() {
    let timerHost = FakeSessionHost(phone: phone)
    let timer = TimerSession(
      profile: TimerProfile.presets[0].profile, host: timerHost, audio: FakeTimerAudio(host: timerHost))
    timer.appear(mode: "rounds", stopwatchRunning: false)
    let breathHost = FakeSessionHost(phone: phone)
    BreathSession(cue: .off, host: breathHost, audio: FakeBreathAudio()).begin(BreathPlan(breathSeconds: 2, cycles: 1))
    XCTAssertTrue(breathHost.logged("keep_awake").isEmpty, "already lit by the timer")
    timer.disappear(stopwatchRunning: false)
    XCTAssertFalse(phone.keepAwake)
  }
}
