import XCTest

@testable import ContextCore

private let profile = TimerProfile(name: "test", workTime: 30, restTime: 10, rounds: 3, prepTime: 5)

final class DeriveTimerStateTests: XCTestCase {
  private func check(
    _ t: Int, _ phase: TimerPhase, left: Int, round: Int, done: Bool = false, line: UInt = #line
  ) {
    let d = deriveTimerState(profile, elapsedSec: t)
    XCTAssertEqual(d.phase, phase, "phase at \(t)", line: line)
    XCTAssertEqual(d.timeLeft, left, "timeLeft at \(t)", line: line)
    XCTAssertEqual(d.currentRound, round, "round at \(t)", line: line)
    XCTAssertEqual(d.done, done, "done at \(t)", line: line)
  }

  func testEveryBoundaryOfAThreeRoundWorkout() {
    check(0, .prep, left: 5, round: 1)
    check(4, .prep, left: 1, round: 1)
    check(5, .work, left: 30, round: 1)
    check(34, .work, left: 1, round: 1)
    check(35, .rest, left: 10, round: 1)
    check(45, .work, left: 30, round: 2)
    check(85, .work, left: 30, round: 3)
    check(114, .work, left: 1, round: 3)
  }

  func testDoneFallsWithTheLastWorkRoundNoTrailingRestAndStaysDone() {
    check(115, .done, left: 0, round: 3, done: true)
    check(600, .done, left: 0, round: 3, done: true)
  }

  func testACatchUpSkipsAcrossAWholePhaseInOneStep() {
    // Away at t=20 (work round 1), back at t=50: work round 2, 25 s left, nothing replayed.
    check(50, .work, left: 25, round: 2)
  }

  func testNoRestMeansWorkRoundsBackToBack() {
    let p = TimerProfile(name: "x", workTime: 10, restTime: 0, rounds: 2, prepTime: 0)
    XCTAssertEqual(deriveTimerState(p, elapsedSec: 0).phase, .work)
    XCTAssertEqual(deriveTimerState(p, elapsedSec: 10).currentRound, 2)
    XCTAssertTrue(deriveTimerState(p, elapsedSec: 20).done)
  }
}

final class TimerEngineTests: XCTestCase {
  /// Ticks four times a second from `from` up to and including `to`, collecting effects with their second.
  private func run(_ engine: inout TimerEngine, from: Double, to: Double) -> [(Int, TimerEffect)] {
    var out: [(Int, TimerEffect)] = []
    var now = from
    while now <= to + 0.001 {
      for effect in engine.tick(now: now) { out.append((Int(now), effect)) }
      now += 0.25
    }
    return out
  }

  private func cues(_ effects: [(Int, TimerEffect)]) -> [String] {
    effects.compactMap { if case .cue(let c) = $0.1 { return "\($0.0):\(c.rawValue)" } else { return nil } }
  }

  func testStartSaysNothingAndTheReadyCountLeadsToGo() {
    var engine = TimerEngine(profile: profile)
    let started = engine.start(now: 100)
    XCTAssertEqual(started, [.phaseChanged(from: .idle, to: .prep, round: 1)])
    XCTAssertTrue(engine.state.isRunning)
    XCTAssertEqual(engine.state.timeLeft, 5)
    let effects = run(&engine, from: 100.25, to: 105)
    XCTAssertEqual(cues(effects), ["102:three", "103:two", "104:one", "105:go"])
  }

  func testAWholeWorkoutCallsEveryBoundaryOnItsSecondEachOnce() {
    var engine = TimerEngine(profile: TimerProfile(name: "x", workTime: 10, restTime: 10, rounds: 2, prepTime: 5))
    _ = engine.start(now: 0)
    let effects = run(&engine, from: 0.25, to: 40)
    XCTAssertEqual(
      cues(effects),
      [
        "2:three", "3:two", "4:one", "5:go",
        "12:three", "13:two", "14:one", "15:rest",
        "22:three", "23:two", "24:one", "25:go",
        "32:three", "33:two", "34:one", "35:done",
      ])
    XCTAssertEqual(effects.filter { $0.1 == .finished }.map(\.0), [35])
    XCTAssertEqual(engine.state.phase, .done)
    XCTAssertFalse(engine.state.isRunning)
    XCTAssertFalse(engine.state.isPaused)
  }

  func testTheDuckWindowOpensASilentSecondBeforeTheCount() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    let effects = run(&engine, from: 0.25, to: 2)
    XCTAssertEqual(effects.first?.0, 1)
    XCTAssertEqual(effects.first?.1, .duckHold(ms: DuckWindow.openEarlyHoldMs))
  }

  func testAStopHoldsTheClockAndResumeCountsOnInTheSameRound() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 15)  // work round 1, 20 s left
    engine.pause(now: 15.5)
    XCTAssertTrue(engine.state.isPaused)
    XCTAssertFalse(engine.state.isRunning)
    XCTAssertEqual(engine.tick(now: 500), [])
    XCTAssertEqual(engine.state.timeLeft, 20)
    XCTAssertEqual(engine.start(now: 600), [])  // nothing fell: resume says nothing
    XCTAssertTrue(engine.state.isRunning)
    XCTAssertEqual(engine.state.timeLeft, 20)
    _ = engine.tick(now: 601.6)
    XCTAssertEqual(engine.state.timeLeft, 18)
    XCTAssertEqual(engine.state.currentRound, 1)
  }

  func testACatchUpMovesTheStateAndReplaysNothingThenCuesGoOn() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 20)
    XCTAssertEqual(engine.tick(now: 50), [])
    XCTAssertEqual(engine.state.phase, .work)
    XCTAssertEqual(engine.state.currentRound, 2)
    XCTAssertEqual(engine.state.timeLeft, 25)
    XCTAssertEqual(engine.tick(now: 50.5), [])  // the round it landed in is not announced late
  }

  func testACatchUpPastTheEndStillFinishes() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    XCTAssertEqual(engine.tick(now: 1000), [.finished])
    XCTAssertEqual(engine.tick(now: 1001), [])
  }

  private let goEffects: [TimerEffect] = [.duckHold(ms: DuckWindow.cueHoldMs), .cue(.go)]

  func testComingBackInABoundarysSecondStillCallsItOnce() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 4.95)
    // The app comes to the front at 5.02, before the clock's own tick at 5.05.
    XCTAssertEqual(engine.tick(now: 5.02), [.phaseChanged(from: .prep, to: .work, round: 1)] + goEffects)
    XCTAssertEqual(engine.tick(now: 5.05), [])
  }

  func testComingBackAfterALongGapInABoundarysSecondCallsOnlyThatBoundary() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 20)
    // Away across rest and "go"; back as round 2's work ends and its rest begins (t=75).
    XCTAssertEqual(
      engine.tick(now: 75.3),
      [.phaseChanged(from: .work, to: .rest, round: 2), .duckHold(ms: DuckWindow.cueHoldMs), .cue(.rest)])
  }

  func testAStopJustAfterABoundaryNoTickSawCallsItOnResume() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 4.95)
    engine.pause(now: 5.02)
    XCTAssertEqual(engine.start(now: 60), [.phaseChanged(from: .prep, to: .work, round: 1)] + goEffects)
    XCTAssertEqual(engine.tick(now: 60.1), [])
  }

  func testWithNoRestEveryNewRoundSaysGo() {
    var engine = TimerEngine(profile: TimerProfile(name: "x", workTime: 10, restTime: 0, rounds: 3, prepTime: 0))
    XCTAssertEqual(engine.start(now: 0), [.phaseChanged(from: .idle, to: .work, round: 1)] + goEffects)
    let effects = run(&engine, from: 0.25, to: 30)
    XCTAssertEqual(
      cues(effects),
      [
        "7:three", "8:two", "9:one", "10:go",
        "17:three", "18:two", "19:one", "20:go",
        "27:three", "28:two", "29:one", "30:done",
      ])
    XCTAssertEqual(
      effects.filter { $0.0 == 10 }.map(\.1), [.phaseChanged(from: .work, to: .work, round: 2)] + goEffects)
  }

  func testResetReturnsToIdleAndAPresetChangeIsIgnoredMidRun() {
    var engine = TimerEngine(profile: profile)
    let other = TimerProfile(name: "other", workTime: 60, restTime: 10, rounds: 5, prepTime: 5)
    _ = engine.start(now: 0)
    engine.setProfile(other)
    XCTAssertEqual(engine.profile, profile)
    engine.pause(now: 3)
    engine.setProfile(other)
    XCTAssertEqual(engine.profile, profile)
    engine.reset()
    XCTAssertEqual(engine.state, TimerState(totalRounds: 3))
    engine.setProfile(other)
    XCTAssertEqual(engine.state.totalRounds, 5)
  }

  func testStartAfterDoneRunsAgainFromTheTop() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 200)
    XCTAssertEqual(engine.state.phase, .done)
    _ = engine.start(now: 300)
    XCTAssertEqual(engine.state.phase, .prep)
    XCTAssertEqual(engine.state.timeLeft, 5)
  }
}

final class DuckWindowTests: XCTestCase {
  private final class FakeSession: DuckSession {
    var log: [String] = []
    func setDucking(_ on: Bool) { log.append(on ? "duck" : "base") }
    func release() { log.append("release") }
  }

  /// A clock the test advances by hand.
  private final class FakeTimers {
    private var pending: [(id: Int, at: Int, block: () -> Void)] = []
    private var now = 0
    private var nextId = 0
    func schedule(_ afterMs: Int, _ block: @escaping () -> Void) -> () -> Void {
      nextId += 1
      let id = nextId
      pending.append((id, now + afterMs, block))
      return { [weak self] in self?.pending.removeAll { $0.id == id } }
    }
    func advance(_ ms: Int) {
      now += ms
      let due = pending.filter { $0.at <= now }
      pending.removeAll { $0.at <= now }
      due.forEach { $0.block() }
    }
  }

  func testOpensOnceStaysOpenAcrossTheCountAndTheCueAndLetsGoABeatAfterTheLast() {
    let session = FakeSession()
    let timers = FakeTimers()
    var lines: [String] = []
    let window = DuckWindow(session: session, schedule: timers.schedule) { action, _ in lines.append(action) }
    XCTAssertFalse(window.isOpen)

    window.hold()  // 3
    XCTAssertEqual(session.log, ["duck"])
    timers.advance(1000)
    window.hold()  // 2
    timers.advance(1000)
    window.hold()  // 1
    timers.advance(1000)
    window.hold(DuckWindow.cueHoldMs)  // the cue at 0
    XCTAssertEqual(session.log, ["duck"])  // opened once, never pumped
    XCTAssertTrue(window.isOpen)

    timers.advance(DuckWindow.cueHoldMs - 1)
    XCTAssertTrue(window.isOpen)
    timers.advance(1)
    XCTAssertFalse(window.isOpen)
    XCTAssertEqual(session.log, ["duck", "base", "release"])
    XCTAssertEqual(lines, ["open", "held", "held", "held", "close", "released"])
  }

  func testACountsHoldOutlastsTheSecondToTheNextAndTheFinishHoldsLongest() {
    XCTAssertGreaterThan(DuckWindow.tickHoldMs, 1000)
    XCTAssertGreaterThan(DuckWindow.finishHoldMs, DuckWindow.cueHoldMs)
  }

  func testCloseNowIsOneReleaseAndClosingAClosedWindowDoesNothing() {
    let session = FakeSession()
    let timers = FakeTimers()
    let window = DuckWindow(session: session, schedule: timers.schedule)
    window.close()
    XCTAssertEqual(session.log, [])
    window.hold()
    window.close()
    XCTAssertEqual(session.log, ["duck", "base", "release"])
    timers.advance(DuckWindow.tickHoldMs * 2)  // the pending close was cancelled
    XCTAssertEqual(session.log, ["duck", "base", "release"])
  }
}

final class CustomPresetTests: XCTestCase {
  func testStartsOnSixtySecondsTheOneMinutePresetsShape() {
    XCTAssertEqual(CustomPreset.default, CustomPreset(work: 60, rest: 10, rounds: 5))
    XCTAssertEqual(CustomPreset.decode(nil), .default)
    XCTAssertEqual(CustomPreset.decode("null"), .default)
    XCTAssertEqual(CustomPreset.decode("garbage"), .default)
  }

  func testMovesInTensInsideItsRanges() {
    XCTAssertEqual(CustomPreset.snap(64, step: 10, range: CustomPreset.workRange), 60)
    XCTAssertEqual(CustomPreset.snap(66, step: 10, range: CustomPreset.workRange), 70)
    XCTAssertEqual(CustomPreset.snap(3, step: 10, range: CustomPreset.workRange), 10)
    XCTAssertEqual(CustomPreset.snap(9999, step: 10, range: CustomPreset.workRange), 600)
    XCTAssertEqual(CustomPreset.snap(-5, step: 10, range: CustomPreset.restRange), 0)
    XCTAssertEqual(CustomPreset(work: 95, rest: 301, rounds: 0).normalized, CustomPreset(work: 100, rest: 300, rounds: 1))
    XCTAssertEqual(CustomPreset.decode("{\"rounds\":99}"), CustomPreset(work: 60, rest: 10, rounds: 20))
  }

  func testSurvivesItsOwnEncoding() {
    let p = CustomPreset(work: 90, rest: 20, rounds: 8)
    XCTAssertEqual(CustomPreset.decode(p.encoded), p)
  }

  func testRunsWhatItSaysWithTheReadyCountTheFixedPresetsUse() {
    XCTAssertEqual(
      CustomPreset(work: 40, rest: 20, rounds: 2).profile,
      TimerProfile(name: "custom", workTime: 40, restTime: 20, rounds: 2, prepTime: 5))
    XCTAssertEqual(CustomPreset(work: 90, rest: 0, rounds: 1).profile.prepTime, 5)
    XCTAssertEqual(CustomPreset(work: 100, rest: 0, rounds: 1).profile.prepTime, 10)
  }

  func testReadsAsMinutesAndSeconds() {
    XCTAssertEqual(formatMinutesSeconds(60), "1:00")
    XCTAssertEqual(formatMinutesSeconds(0), "0:00")
    XCTAssertEqual(formatMinutesSeconds(610), "10:10")
  }
}

final class SevenSegmentTests: XCTestCase {
  func testSpellsEveryDigitWithTheClassicBars() {
    XCTAssertEqual(SevenSegment.segments(for: "8"), Set(Segment.allCases))
    XCTAssertEqual(SevenSegment.segments(for: "1"), [.b, .c])
    XCTAssertEqual(SevenSegment.segments(for: "0"), [.a, .b, .c, .d, .e, .f])
    XCTAssertTrue(SevenSegment.segments(for: "4").contains(.g))
    XCTAssertFalse(SevenSegment.segments(for: "7").contains(.f))
    for digit in "0123456789" { XCTAssertGreaterThanOrEqual(SevenSegment.segments(for: digit).count, 2) }
  }

  func testSpellsThePhaseWordsTheWayAGymClockDoesAndBlanksWhatItCannot() {
    XCTAssertEqual(SevenSegment.phaseWord(.work), "GO")
    XCTAssertEqual(SevenSegment.phaseWord(.rest), "rESt")
    XCTAssertEqual(SevenSegment.phaseWord(.prep), "rEAdY")
    XCTAssertEqual(SevenSegment.phaseWord(.done), "donE")
    XCTAssertEqual(SevenSegment.phaseWord(.idle), "")
    for ch in "GOrEStAdYn" + SevenSegment.pausedWord { XCTAssertFalse(SevenSegment.segments(for: ch).isEmpty, "\(ch)") }
    XCTAssertTrue(SevenSegment.segments(for: "W").isEmpty)
    XCTAssertTrue(SevenSegment.segments(for: " ").isEmpty)
  }

  func testSeparatorsAreDotsNotSegments() {
    XCTAssertTrue(SevenSegment.isSeparator(":"))
    XCTAssertTrue(SevenSegment.isSeparator("."))
    XCTAssertFalse(SevenSegment.isSeparator("1"))
    XCTAssertTrue(SevenSegment.segments(for: ":").isEmpty)
    XCTAssertEqual(LedLayout.separatorDots(":", height: 100).count, 2)
    XCTAssertEqual(LedLayout.separatorDots(".", height: 100).count, 1)
  }

  func testTheDisplayFitsItsWidthAndNeverExceedsItsHeight() {
    let text = "10:00"
    let h = LedLayout.heightToFit(text, width: 300, maxHeight: 150)
    XCTAssertLessThanOrEqual(LedLayout.width(of: text, height: h), 300)
    XCTAssertGreaterThan(LedLayout.width(of: text, height: h + 1), 300)
    XCTAssertEqual(LedLayout.heightToFit("1", width: 10_000, maxHeight: 150), 150)
    XCTAssertEqual(LedLayout.heightToFit("", width: 300, maxHeight: 150), 0)
  }

  func testEveryBarSitsInsideItsDigit() {
    let h = 100.0
    for (segment, r) in LedLayout.segmentRects(height: h) {
      XCTAssertGreaterThanOrEqual(r.x, 0, "\(segment)")
      XCTAssertGreaterThanOrEqual(r.y, 0, "\(segment)")
      XCTAssertLessThanOrEqual(r.x + r.width, LedLayout.digitWidth * h + 0.001, "\(segment)")
      XCTAssertLessThanOrEqual(r.y + r.height, h + 0.001, "\(segment)")
    }
  }
}

final class DeviceTurnTests: XCTestCase {
  func testUprightUntilAClearSidewaysPullLeftAndRightByTheSignOfX() {
    XCTAssertEqual(DeviceTurn.classify(x: 0, y: -1, previous: .upright), .upright)
    XCTAssertEqual(DeviceTurn.classify(x: -1, y: 0, previous: .upright), .left)
    XCTAssertEqual(DeviceTurn.classify(x: 1, y: 0, previous: .upright), .right)
    XCTAssertEqual(DeviceTurn.classify(x: -0.5, y: -0.85, previous: .upright), .upright)  // 30° is not a turn
  }

  func testTheMarginKeepsFortyFiveDegreesFromFlickering() {
    XCTAssertGreaterThan(DeviceTurn.engage, DeviceTurn.release)
    var t = DeviceTurn.upright
    t = DeviceTurn.classify(x: -0.7, y: -0.7, previous: t)
    XCTAssertEqual(t, .upright)  // x is not greater than y
    t = DeviceTurn.classify(x: -0.75, y: -0.65, previous: t)
    XCTAssertEqual(t, .left)
    t = DeviceTurn.classify(x: -0.55, y: -0.83, previous: t)  // back toward upright, but not clearly
    XCTAssertEqual(t, .left)
    t = DeviceTurn.classify(x: -0.2, y: -0.98, previous: t)
    XCTAssertEqual(t, .upright)
  }

  func testAPhoneLaidFlatKeepsTheTurnItWasLastHeldAt() {
    for turn in [DeviceTurn.left, .right, .upright] {
      XCTAssertEqual(DeviceTurn.classify(x: 0.05, y: 0.05, previous: turn), turn)
    }
  }

  func testASwingStraightToTheOtherSideFollows() {
    XCTAssertEqual(DeviceTurn.classify(x: 1, y: 0, previous: .left), .right)
    XCTAssertEqual(DeviceTurn.classify(x: -1, y: 0, previous: .right), .left)
  }

  func testTopLeftNeedsTheDisplayTurnedClockwise() {
    XCTAssertEqual(DeviceTurn.left.rotationDegrees, 90)
    XCTAssertEqual(DeviceTurn.right.rotationDegrees, -90)
    XCTAssertEqual(DeviceTurn.upright.rotationDegrees, 0)
  }
}

final class StopwatchTests: XCTestCase {
  func testRunsStopsHoldsAndRunsOn() {
    var watch = Stopwatch()
    XCTAssertEqual(watch.elapsedMs(now: 50), 0)
    XCTAssertFalse(watch.isPaused)
    watch.toggle(now: 10)
    XCTAssertTrue(watch.isRunning)
    XCTAssertEqual(watch.elapsedMs(now: 12.5), 2500)
    watch.toggle(now: 13)
    XCTAssertTrue(watch.isPaused)
    XCTAssertEqual(watch.elapsedMs(now: 99), 3000)
    watch.toggle(now: 100)
    XCTAssertEqual(watch.elapsedMs(now: 101), 4000)
  }

  func testLapsAreNewestFirstOnlyWhileRunningAndResetClearsBoth() {
    var watch = Stopwatch()
    watch.lap(now: 1)
    XCTAssertEqual(watch.laps, [])
    watch.toggle(now: 0)
    watch.lap(now: 1)
    watch.lap(now: 3)
    XCTAssertEqual(watch.laps, [3000, 1000])
    watch.reset()
    XCTAssertEqual(watch, Stopwatch())
  }

  func testFormatsMinutesSecondsAndHundredths() {
    XCTAssertEqual(Stopwatch.format(ms: 0).main, "00:00")
    XCTAssertEqual(Stopwatch.format(ms: 0).fraction, ".00")
    XCTAssertEqual(Stopwatch.format(ms: 125_370).main, "02:05")
    XCTAssertEqual(Stopwatch.format(ms: 125_370).fraction, ".37")
  }

  func testTheSetCountStaysInRangeAndTalliesInFives() {
    XCTAssertEqual(SetCounter.clamp(-1), 0)
    XCTAssertEqual(SetCounter.clamp(99), 15)
    XCTAssertEqual(SetCounter.tally(7).groups, 1)
    XCTAssertEqual(SetCounter.tally(7).remainder, 2)
  }
}
