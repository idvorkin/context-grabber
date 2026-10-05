import XCTest

@testable import ContextCore

private let profile = TimerProfile(name: "2min", workTime: 120, restTime: 15, rounds: 4, prepTime: 10)

final class GymTimerActivityContentTests: XCTestCase {
  private func content(at now: Double, _ engine: inout TimerEngine) -> LiveActivityContent? {
    _ = engine.tick(now: now)
    return LiveActivityContent(timer: engine.state, profile: profile)
  }

  func testIdleHasNoCard() {
    XCTAssertNil(LiveActivityContent(timer: TimerEngine(profile: profile).state, profile: profile))
  }

  func testEachPhaseSaysItsWordRoundLengthAndColour() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    let ready = LiveActivityContent(timer: engine.state, profile: profile)!
    XCTAssertEqual(ready.kind, .gymTimer)
    XCTAssertEqual([ready.title, ready.subtitle, ready.compactLabel], ["GET READY", "Round 1/4", "READY 1/4"])
    XCTAssertEqual([ready.secondsLeft, ready.stepSeconds], [10, 10])
    XCTAssertEqual(ready.accent, .amber)

    // Second round of work: 10 prep + 120 work + 15 rest = 145, then 30 s in.
    let work = content(at: 175, &engine)!
    XCTAssertEqual([work.title, work.subtitle, work.compactLabel], ["WORK", "Round 2/4", "WORK 2/4"])
    XCTAssertEqual([work.secondsLeft, work.stepSeconds], [90, 120])
    XCTAssertEqual(work.accent, .red)
    XCTAssertFalse(work.paused || work.finished)

    let rest = content(at: 270, &engine)!
    XCTAssertEqual([rest.title, rest.subtitle, rest.compactLabel], ["REST", "Round 2/4", "REST 2/4"])
    XCTAssertEqual([rest.secondsLeft, rest.stepSeconds], [10, 15])
    XCTAssertEqual(rest.accent, .green)
  }

  func testTheKeyMovesOnBoundariesAndPausesNotEverySecond() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    var keys: [String] = []
    var now = 0.0
    while now <= 140 {
      let c = content(at: now, &engine)!
      if keys.last != c.key { keys.append(c.key) }
      now += 0.5
    }
    XCTAssertEqual(keys, ["prep|1|running", "work|1|running", "rest|1|running"])

    _ = engine.tick(now: 141)
    engine.pause(now: 141)
    let paused = LiveActivityContent(timer: engine.state, profile: profile)!
    XCTAssertEqual(paused.key, "rest|1|paused")
    XCTAssertTrue(paused.paused)
    XCTAssertEqual([paused.title, paused.subtitle, paused.compactLabel], ["PAUSED", "REST · Round 1/4", "PAUSED 1/4"])
    XCTAssertEqual(paused.accent, .amber)
    XCTAssertEqual(paused.secondsLeft, 4)
    XCTAssertEqual(content(at: 200, &engine)!.key, "rest|1|paused", "still paused a minute later: nothing to push")

    _ = engine.start(now: 210)
    XCTAssertEqual(LiveActivityContent(timer: engine.state, profile: profile)!.key, "rest|1|running")
  }

  func testTheFinishSaysDoneAndTheRoundsCompleted() {
    var engine = TimerEngine(profile: profile)
    _ = engine.start(now: 0)
    let done = content(at: 10_000, &engine)!
    XCTAssertTrue(done.finished)
    XCTAssertFalse(done.paused)
    XCTAssertEqual([done.title, done.subtitle, done.compactLabel], ["DONE!", "4 rounds completed", "DONE!"])

    var one = TimerEngine(profile: TimerProfile(name: "x", workTime: 5, restTime: 0, rounds: 1, prepTime: 0))
    _ = one.start(now: 0)
    _ = one.tick(now: 6)
    XCTAssertEqual(LiveActivityContent(timer: one.state, profile: one.profile)!.subtitle, "1 round completed")
  }
}

final class BreatheActivityContentTests: XCTestCase {
  /// 8 s a side, 5 minutes: 9 cycles, 4 min 48 s.
  private let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)

  private func at(_ t: Double, paused: Bool = false) -> LiveActivityContent? {
    LiveActivityContent(breath: plan, elapsed: t, paused: paused, finished: false)
  }

  func testTheQuietBeforeTheFirstInhaleSaysReadyAndTheTimeToIt() {
    let ready = LiveActivityContent(breath: plan, elapsed: -1.5, leadIn: 2, paused: false, finished: false)!
    XCTAssertEqual([ready.title, ready.subtitle, ready.compactLabel], ["Ready", "Cycle 1 of 9", "READY 1/9"])
    XCTAssertEqual([ready.secondsLeft, ready.stepSeconds], [2, 2])
    XCTAssertEqual(ready.key, "ready|running")
    let paused = LiveActivityContent(breath: plan, elapsed: -0.4, leadIn: 2, paused: true, finished: false)!
    XCTAssertEqual([paused.title, paused.subtitle, paused.compactLabel], ["PAUSED", "Ready · Cycle 1 of 9", "PAUSED 1/9"])
    XCTAssertEqual([paused.secondsLeft, paused.stepSeconds], [1, 2])
    XCTAssertEqual(paused.key, "ready|paused")
    XCTAssertEqual(at(0)!.key, "0|running")
  }

  func testEachStepSaysItsWordCycleAndTimeLeft() {
    // Cycle 3 starts at 64 s: inhale 64–72, hold 72–80, exhale 80–88, hold 88–96.
    let inhale = at(66.5)!
    XCTAssertEqual(inhale.kind, .breathe)
    XCTAssertEqual([inhale.title, inhale.subtitle, inhale.compactLabel], ["Inhale", "Cycle 3 of 9", "IN 3/9"])
    XCTAssertEqual([inhale.secondsLeft, inhale.stepSeconds], [6, 8])
    XCTAssertEqual(inhale.accent, .white)
    XCTAssertEqual(at(73)!.compactLabel, "HOLD 3/9")
    XCTAssertEqual([at(81)!.title, at(81)!.compactLabel], ["Exhale", "OUT 3/9"])
    XCTAssertEqual([at(95)!.title, at(95)!.compactLabel], ["Hold", "HOLD 3/9"])
  }

  func testTheKeyMovesOnStepsAndPausesNotEverySecond() {
    var keys: [String] = []
    var t = 0.0
    while t < 32 {
      let c = at(t)!
      if keys.last != c.key { keys.append(c.key) }
      t += 0.25
    }
    XCTAssertEqual(keys, ["0|running", "1|running", "2|running", "3|running"])
    let paused = at(66.5, paused: true)!
    XCTAssertEqual(paused.key, "8|paused")
    XCTAssertEqual([paused.title, paused.subtitle, paused.compactLabel], ["PAUSED", "Inhale · Cycle 3 of 9", "PAUSED 3/9"])
    XCTAssertEqual(paused.secondsLeft, 6)
  }

  func testTheFinishSaysDoneAndTheSession() {
    let done = LiveActivityContent(breath: plan, elapsed: 400, paused: false, finished: true)!
    XCTAssertTrue(done.finished)
    XCTAssertEqual([done.title, done.subtitle], ["Done", "4 min 48 s · 9 cycles"])
    XCTAssertEqual(done.key, "done")
  }

  func testTheStepEndIsExactThroughTheLeadInAndAPause() {
    var run = BreathRun(plan: plan, leadIn: 2)
    run.start(now: 100)
    XCTAssertEqual(run.stepEndsAt(now: 101)!, 102, accuracy: 1e-9, "the lead-in ends at the first inhale")
    XCTAssertEqual(run.stepEndsAt(now: 102.5)!, 110, accuracy: 1e-9)
    XCTAssertEqual(run.stepEndsAt(now: 111.3)!, 118, accuracy: 1e-9)
    run.pause(now: 112)
    XCTAssertNil(run.stepEndsAt(now: 112))
    run.start(now: 130.5)
    XCTAssertEqual(run.stepEndsAt(now: 130.5)!, 136.5, accuracy: 1e-9)
  }
}

final class PhaseEndsAtTests: XCTestCase {
  func testThePhaseEndIsTheBoundaryToTheFractionEvenAfterAPause() {
    var engine = TimerEngine(profile: TimerProfile(name: "x", workTime: 10, restTime: 5, rounds: 2, prepTime: 5))
    _ = engine.start(now: 1000.3)
    XCTAssertEqual(engine.phaseEndsAt!, 1005.3, accuracy: 1e-9)
    _ = engine.tick(now: 1007.5)  // work, round 1
    XCTAssertEqual(engine.phaseEndsAt!, 1015.3, accuracy: 1e-9)

    engine.pause(now: 1008.0)
    XCTAssertNil(engine.phaseEndsAt, "a paused phase has no end yet")
    _ = engine.start(now: 1020.7)  // 12.7 s paused
    XCTAssertEqual(engine.phaseEndsAt!, 1028.0, accuracy: 1e-9)

    _ = engine.tick(now: 1028.05)  // rest, round 1
    XCTAssertEqual(engine.state.phase, .rest)
    XCTAssertEqual(engine.phaseEndsAt!, 1033.0, accuracy: 1e-9)
  }

  func testNoEndWhenIdleOrDone() {
    var engine = TimerEngine(profile: TimerProfile(name: "x", workTime: 2, restTime: 0, rounds: 1, prepTime: 0))
    XCTAssertNil(engine.phaseEndsAt)
    _ = engine.start(now: 0)
    _ = engine.tick(now: 3)
    XCTAssertEqual(engine.state.phase, .done)
    XCTAssertNil(engine.phaseEndsAt)
  }
}
