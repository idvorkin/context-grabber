import XCTest

@testable import ContextCore

final class BreathPlanTests: XCTestCase {
  func testTheSessionIsTheWholeCyclesClosestToTheTimeChosen() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.cycles, 9)
    XCTAssertEqual(plan.totalSeconds, 288)
    XCTAssertEqual(plan.summary, "9 cycles · ends at 4 min 48 s")
    XCTAssertEqual(plan.doneText, "4 min 48 s · 9 cycles")
  }

  func testChangingBreathLengthChangesTheSummary() {
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 5).summary, "5 cycles · ends at 5 min 0 s")
  }

  func testNeverLessThanOneCycleAtAnySetting() {
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 2).cycles, 2)
    for breath in BreathPlan.breathRange {
      for session in BreathPlan.sessionRange {
        XCTAssertGreaterThanOrEqual(BreathPlan(breathSeconds: breath, sessionMinutes: session).cycles, 1)
      }
    }
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 10).cycles, 30)
    XCTAssertEqual(BreathPlan.sessionRange, 2...15)
  }

  func testTheLongestSessionIsFifteenMinutes() {
    XCTAssertEqual(BreathPlan(breathSeconds: 8, sessionMinutes: 15).summary, "28 cycles · ends at 14 min 56 s")
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 15).cycles, 45)
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 15).totalSeconds, 900)
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 15).cycles, 15)
    XCTAssertEqual(BreathPlan(breathSeconds: 5, sessionMinutes: 15).moment(at: 0).timeLeftText, "15:00 left")
  }

  func testTheSlidersStopAtTheirEnds() {
    XCTAssertEqual(BreathPlan(breathSeconds: 1, sessionMinutes: 5).breathSeconds, 5)
    XCTAssertEqual(BreathPlan(breathSeconds: 99, sessionMinutes: 5).breathSeconds, 15)
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 99).cycles, 15)
    XCTAssertEqual(BreathPlan(breathSeconds: 15, sessionMinutes: 0).cycles, 2)
    XCTAssertEqual(BreathPlan(breathSeconds: 8, cycles: 1).summary, "1 cycle · ends at 0 min 32 s")
  }

  func testEachSideOfTheBoxLastsTheBreathLength() {
    let plan = BreathPlan(breathSeconds: 10, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 0).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 9.99).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 10).phase, .holdFull)
    XCTAssertEqual(plan.moment(at: 20).phase, .exhale)
    XCTAssertEqual(plan.moment(at: 30).phase, .holdEmpty)
    XCTAssertEqual(plan.moment(at: 40).phase, .inhale)
    XCTAssertEqual(plan.moment(at: 40).cycle, 2)
  }

  func testTheRingDrawsOnTheInhaleStaysOnTheHoldAndUndrawsOnTheExhale() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 0).ring, 0)
    XCTAssertEqual(plan.moment(at: 4).ring, 0.5, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 12).ring, 1)
    XCTAssertEqual(plan.moment(at: 20).ring, 0.5, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 28).ring, 0)
    XCTAssertEqual(plan.moment(at: 12).phaseProgress, 0.5, accuracy: 1e-9)  // the hold bar, halfway
  }

  func testTheCircleGrowsFromNinetyToAHundredPercentAndBackEased() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 0).scale, 0.9, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 4).scale, 0.95, accuracy: 1e-9)
    XCTAssertLessThan(plan.moment(at: 1).scale, 0.9 + 0.1 / 8)  // slow at the start: eased, not linear
    XCTAssertEqual(plan.moment(at: 10).scale, 1)
    XCTAssertEqual(plan.moment(at: 20).scale, 0.95, accuracy: 1e-9)
    XCTAssertEqual(plan.moment(at: 30).scale, 0.9, accuracy: 1e-9)
  }

  func testTimeLeftCountsDown() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertEqual(plan.moment(at: 17).timeLeftText, "4:31 left")
    XCTAssertEqual(plan.moment(at: 0).timeLeftText, "4:48 left")
    XCTAssertEqual(plan.moment(at: 287.5).timeLeftText, "0:01 left")
  }

  func testTheSessionEndsAfterTheLastHold() {
    let plan = BreathPlan(breathSeconds: 8, sessionMinutes: 5)
    XCTAssertFalse(plan.moment(at: 287.99).done)
    XCTAssertEqual(plan.moment(at: 287.99).phase, .holdEmpty)
    XCTAssertEqual(plan.moment(at: 287.99).cycle, 9)
    XCTAssertTrue(plan.moment(at: 288).done)
    XCTAssertEqual(plan.moment(at: 500).secondsLeft, 0)
  }

  func testTheWordsOnScreenAndTheCueLabels() {
    XCTAssertEqual(BreathPhase.allCases.map(\.word), ["Inhale", "Hold", "Exhale", "Hold"])
    XCTAssertEqual(BreathCue.allCases.map(\.label), ["Voice", "Tone", "Off"])
  }
}

final class BreathRunTests: XCTestCase {
  /// Looks every 50 ms from `from` to `to`, collecting effects with the second they fell in.
  private func look(_ run: inout BreathRun, from: Double, to: Double) -> [String] {
    var out: [String] = []
    var now = from
    while now <= to + 0.001 {
      for effect in run.tick(now: now) {
        switch effect {
        case .phase(let phase, let cycle, _): out.append("\(Int(now - from + 0.001)):\(phase.word)#\(cycle)")
        case .finished: out.append("\(Int(now - from + 0.001)):done")
        }
      }
      now += 0.05
    }
    return out
  }

  func testEveryPhaseIsCalledOnItsSecondAndTheSessionFinishesOnce() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, cycles: 2))
    run.start(now: 100)
    XCTAssertEqual(
      look(&run, from: 100, to: 45 + 100),
      [
        "0:Inhale#1", "5:Hold#1", "10:Exhale#1", "15:Hold#1", "20:Inhale#2", "25:Hold#2", "30:Exhale#2",
        "35:Hold#2", "40:done",
      ])
    XCTAssertTrue(run.isFinished)
    XCTAssertFalse(run.isRunning)
    XCTAssertEqual(run.tick(now: 999), [])
    XCTAssertTrue(run.moment(now: 999).done)
  }

  func testAThirtyCycleSessionDoesNotDrift() {
    // The brief's bar: 10 minutes at 5 s, under 0.5 s of total drift. Looks land every 50 ms, so no cue is
    // more than 50 ms late and lateness never accumulates.
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, sessionMinutes: 10))
    run.start(now: 0)
    var worst = 0
    var finishedAt = -1.0
    var now = 0.0
    while now < 601 {
      for effect in run.tick(now: now) {
        switch effect {
        case .phase(_, _, let lateMs): worst = max(worst, lateMs)
        case .finished(let lateMs):
          worst = max(worst, lateMs)
          finishedAt = now
        }
      }
      now += 0.05
    }
    XCTAssertLessThanOrEqual(worst, 51)
    XCTAssertEqual(finishedAt, 600, accuracy: 0.051)
  }

  func testPauseFreezesEverythingAndResumeContinuesMidPhaseWithNoJump() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 8, sessionMinutes: 5))
    run.start(now: 0)
    _ = run.tick(now: 0)
    run.pause(now: 4)  // halfway through the inhale
    XCTAssertTrue(run.isPaused)
    let frozen = run.moment(now: 4)
    XCTAssertEqual(run.moment(now: 500), frozen)
    XCTAssertEqual(run.tick(now: 500), [])
    XCTAssertEqual(frozen.ring, 0.5, accuracy: 1e-9)
    run.start(now: 1000)
    XCTAssertEqual(run.moment(now: 1000), frozen)
    XCTAssertEqual(run.tick(now: 1000.05), [])  // the inhale is not announced again
    XCTAssertEqual(run.tick(now: 1004), [.phase(.holdFull, cycle: 1, lateMs: 0)])
    // Still ends on time: 288 s of breathing in all.
    XCTAssertEqual(run.tick(now: 1000 + 284), [.finished(lateMs: 0)])
  }

  func testTheLeadInIsQuietAndTheFirstInhaleFollowsIt() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, cycles: 1), leadIn: 2)
    run.start(now: 0)
    XCTAssertEqual(run.tick(now: 1.9), [])
    XCTAssertEqual(run.moment(now: 1).ring, 0)
    XCTAssertEqual(run.moment(now: 1).timeLeftText, "0:20 left")
    XCTAssertEqual(run.tick(now: 2), [.phase(.inhale, cycle: 1, lateMs: 0)])
    XCTAssertEqual(run.tick(now: 22), [.finished(lateMs: 0)])
  }

  func testALookAfterALongGapReportsOnlyWhereTheSessionIsNow() {
    var run = BreathRun(plan: BreathPlan(breathSeconds: 5, cycles: 3))
    run.start(now: 0)
    _ = run.tick(now: 0)
    XCTAssertEqual(run.tick(now: 27), [.phase(.holdFull, cycle: 2, lateMs: 2000)])
  }
}

final class BreathToneTests: XCTestCase {
  func testEachPhaseHasItsTone() {
    XCTAssertEqual(BreathPhase.allCases.map(BreathTone.tone(for:)), [.rising, .tick, .falling, .tick])
  }

  func testEveryToneIsShortQuietAtItsEdgesAndNeverClips() {
    for tone in BreathTone.allCases {
      let samples = tone.samples()
      XCTAssertEqual(Double(samples.count) / BreathTone.sampleRate, tone.seconds, accuracy: 0.001, tone.rawValue)
      XCTAssertLessThanOrEqual(tone.seconds, 1.6)
      XCTAssertLessThan(abs(samples.first ?? 1), 0.01, tone.rawValue)
      XCTAssertLessThan(abs(samples.last ?? 1), 0.02, tone.rawValue)
      XCTAssertLessThan(samples.map(abs).max() ?? 1, 0.5, tone.rawValue)
      XCTAssertGreaterThan(samples.map(abs).max() ?? 0, 0.1, tone.rawValue)
    }
  }

  func testTheWavIsAMonoSixteenBitFileOfTheRightLength() {
    let wav = BreathTone.tick.wav()
    XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
    XCTAssertEqual(String(decoding: wav[8..<16], as: UTF8.self), "WAVEfmt ")
    XCTAssertEqual(wav.count, 44 + BreathTone.tick.samples().count * 2)
    XCTAssertEqual(wav[22], 1)  // one channel
    XCTAssertEqual(wav[34], 16)  // bits per sample
  }
}
