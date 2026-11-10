//  Story 304: the archive's lines in Settings.

import XCTest

@testable import ContextCore

final class ArchiveStatusTests: XCTestCase {
  private let now: Int64 = 1_780_000_000_000
  private let hour: Int64 = 3_600_000

  private func texts(_ lines: [ArchiveStatus.Line]) -> [String] { lines.map(\.text) }

  func testCaughtUpSaysWhen() {
    let lines = ArchiveStatus.lines(
      sends: true, outcome: ArchiveOutcome(at: now - 2 * hour), lastCaughtUp: now - 2 * hour, now: now)
    XCTAssertEqual(texts(lines), ["Caught up \u{00B7} 2 h ago"])
    XCTAssertFalse(lines[0].trouble)
    let old = ArchiveStatus.lines(
      sends: true, outcome: ArchiveOutcome(at: now - 30 * hour), lastCaughtUp: now - 30 * hour, now: now)
    XCTAssertTrue(old[0].trouble, "no run for over a day")
  }

  func testTheCockpitOutOfReachNamesTheLastTimeItCaughtUp() {
    let outcome = ArchiveOutcome(at: now - 10 * 60_000, stopped: [ArchiveStream.points: .cockpitAway])
    let lines = ArchiveStatus.lines(sends: true, outcome: outcome, lastCaughtUp: now - 50 * hour, now: now)
    XCTAssertEqual(
      texts(lines),
      [
        "Cockpit out of reach \u{00B7} tried 10 min ago \u{00B7} last caught up 2 days ago",
        "Trail: waiting for the Cockpit",
      ])
    XCTAssertTrue(lines[0].trouble, "behind for over a day")
    XCTAssertFalse(
      ArchiveStatus.lines(sends: true, outcome: outcome, lastCaughtUp: now - hour, now: now)[0].trouble,
      "a short spell away is not trouble yet")
  }

  func testARefusedStreamIsRedWithItsStatus() {
    let outcome = ArchiveOutcome(
      at: now - hour,
      stopped: ["strip.balloons": .refused, "health.HKQuantityTypeIdentifierHeartRate": .pages],
      refused: ["strip.balloons": 404])
    let lines = ArchiveStatus.lines(
      sends: true, outcome: outcome, lastCaughtUp: nil, firstRun: now - 30 * hour, now: now)
    XCTAssertEqual(
      texts(lines),
      [
        "Behind \u{00B7} last run 1 h ago \u{00B7} never caught up",
        "Heart Rate: still sending its history",
        "Strip: balloons: refused (404); the rest waits on the phone",
      ])
    XCTAssertEqual(lines.map(\.trouble), [true, false, true])
  }

  /// A first backfill (runs that stop at their page limit, a restarted stream's re-read, a run iOS cut short) is
  /// progress: never red, however long it takes, and never red at first launch.
  func testABackfillIsNeverRed() {
    let backfill = ArchiveOutcome(
      at: now - hour,
      stopped: ["health.HKQuantityTypeIdentifierHeartRate": .pages, ArchiveStream.points: .cancelled])
    XCTAssertTrue(backfill.madeProgress)
    let first = ArchiveStatus.lines(
      sends: true, outcome: backfill, lastCaughtUp: nil, lastProgress: nil, firstRun: now - 3 * 24 * hour, now: now)
    XCTAssertEqual(first.map(\.trouble), [false, false, false], "this run moved the archive")
    XCTAssertEqual(
      ArchiveStatus.lines(sends: true, outcome: backfill, lastCaughtUp: nil, now: now).map(\.trouble),
      [false, false, false], "a fresh install's first run")
  }

  /// No progress: red a day after the last run that made any, or a day after the first run when none ever has.
  func testNoProgressForADayIsRed() {
    let away = ArchiveOutcome(at: now - 10 * 60_000, stopped: [ArchiveStream.points: .cockpitAway])
    XCTAssertFalse(away.madeProgress)
    func red(progress: Int64?, firstRun: Int64?) -> Bool {
      ArchiveStatus.lines(
        sends: true, outcome: away, lastCaughtUp: nil, lastProgress: progress, firstRun: firstRun, now: now)[0].trouble
    }
    XCTAssertFalse(red(progress: now - 20 * hour, firstRun: now - 90 * hour), "a backfill run 20 h ago")
    XCTAssertTrue(red(progress: now - 30 * hour, firstRun: now - 90 * hour))
    XCTAssertFalse(red(progress: nil, firstRun: now - 2 * hour), "the first day of a Cockpit never reached")
    XCTAssertTrue(red(progress: nil, firstRun: now - 30 * hour))
    XCTAssertFalse(red(progress: nil, firstRun: nil), "the first run")
    XCTAssertFalse(ArchiveOutcome(at: 0, stopped: ["a": .refused, "b": .pages]).madeProgress)
    XCTAssertFalse(ArchiveOutcome(at: 0, stopped: ["a": .unreadable]).madeProgress)
  }

  func testNotRunYetAndNoArchive() {
    XCTAssertEqual(texts(ArchiveStatus.lines(sends: true, outcome: nil, lastCaughtUp: nil, now: now)), ["Not run yet"])
    XCTAssertEqual(
      texts(ArchiveStatus.lines(sends: false, outcome: nil, lastCaughtUp: nil, now: now)),
      ["Not sent: this build has no archive address"])
  }

  func testNamesAndAges() {
    XCTAssertEqual(ArchiveStatus.name("location.points"), "Trail")
    XCTAssertEqual(ArchiveStatus.name("health.HKCategoryTypeIdentifierSleepAnalysis"), "Sleep Analysis")
    XCTAssertEqual(ArchiveStatus.name("health.HKWorkoutTypeIdentifier"), "Workouts")
    XCTAssertEqual(
      ArchiveStatus.name("health.HKQuantityTypeIdentifierHeartRateVariabilitySDNN"), "Heart Rate Variability SDNN")
    XCTAssertEqual(ArchiveStatus.ago(now - 20_000, now: now), "just now")
    XCTAssertEqual(ArchiveStatus.ago(now - 47 * hour, now: now), "47 h ago")
    XCTAssertEqual(ArchiveStatus.ago(now - 72 * hour, now: now), "3 days ago")
  }

  func testTheOutcomeRoundTripsThroughItsSetting() {
    let outcome = ArchiveOutcome(at: 5, stopped: ["a": .refused], refused: ["a": 413])
    XCTAssertEqual(ArchiveOutcome(json: outcome.json), outcome)
    XCTAssertNil(ArchiveOutcome(json: nil))
    XCTAssertNil(ArchiveOutcome(json: "not json"))
  }

  /// The phone has outcomes stored with the stop reasons as words; they read back, and are written back the same.
  func testAStoredOutcomeReadsBackWithItsWords() throws {
    let stored =
      #"{"at": 5, "stopped": {"a": "retry", "b": "read", "c": "pages", "d": "cancelled", "e": "refused", "f": "new"}, "refused": {"e": 404}}"#
    let outcome = try XCTUnwrap(ArchiveOutcome(json: stored))
    XCTAssertEqual(
      outcome.stopped, ["a": .cockpitAway, "b": .unreadable, "c": .pages, "d": .cancelled, "e": .refused],
      "a reason this build does not know is dropped, not the outcome")
    XCTAssertEqual(outcome.refused, ["e": 404])
    let written = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(outcome.json.utf8)) as? [String: Any])
    XCTAssertEqual((written["stopped"] as? [String: String])?["a"], "retry")
    XCTAssertEqual((written["stopped"] as? [String: String])?["b"], "read")
    XCTAssertEqual(ArchiveOutcome(json: #"{"at": 9}"#), ArchiveOutcome(at: 9))
  }
}
