import Foundation
import XCTest

@testable import ContextCore

/// The oracle is the shapes spec (2026-11-01-whiteboard-shapes-design.md) and its stories: 351 and 367 (Ghosts off asks
/// nothing, for strokes or for words), 357 (each new set replaces only its author's), 358 (Claude's fade, Larry's stay),
/// 345 and 360 (spoken turns), 354 (a tap keeps or dismisses), 370 (marks arrive one at a time), 373 (a Cockpit that
/// doesn't stream still brings its marks). These were `WhiteboardTurnUITests` cases on the simulator; the screen keeps
/// one stream-to-ghost path and the real gestures, pixels and undo.
final class WhiteboardGhostTurnsTests: XCTestCase {
  private struct G: WhiteboardGhost, Equatable {
    let id: String
    let who: WhiteboardTurn.Who
  }

  private let t0 = ContinuousClock.now
  private let circle = #"{"kind": "circle", "cx": 50, "cy": 50, "r": 10}"#
  private let last = #"{"done": true, "ms": 2100}"#

  private func turns(on: Bool = true) -> WhiteboardGhostTurns<G> {
    WhiteboardGhostTurns(on: on, ghostLife: .seconds(30))
  }

  private func ghosts(_ who: WhiteboardTurn.Who, _ count: Int) -> [G] {
    (0..<count).map { _ in G(id: "\(who.rawValue)-\(UUID().uuidString)", who: who) }
  }

  private func count(_ turns: WhiteboardGhostTurns<G>, _ who: WhiteboardTurn.Who) -> Int {
    turns.ghosts.filter { $0.who == who }.count
  }

  private func shapes(_ count: Int) -> [WhiteboardTurn.Shape] {
    var reader = WhiteboardStream(status: 200, contentType: "application/x-ndjson")
    let body = Array(repeating: circle + "\n", count: count).joined()
    return body.utf8.compactMap { reader.take($0) }
  }

  /// Claude's turn under way, asked from a stroke's pause.
  private func asking(_ turns: inout WhiteboardGhostTurns<G>) -> Int {
    XCTAssertTrue(turns.stroked())
    XCTAssertTrue(turns.pauseEnded())
    return turns.asked(.claude)
  }

  /// The test is the transport: the body's bytes in order, then its clean end, or `cut` in its place.
  private func feed(
    _ text: String, status: Int? = 200, type: String? = "application/x-ndjson", cut: String? = nil,
    elapsedMs: Int = 0, landed: (WhiteboardTurn.Shape, Bool) -> Void
  ) -> WhiteboardStream.Read {
    var reading = WhiteboardStream.Reading()
    reading.opened(status: status, contentType: type)
    for byte in text.utf8 {
      if let mark = reading.take(byte, elapsedMs: { elapsedMs }) { landed(mark.shape, mark.first) }
      if reading.done { break }
    }
    if cut == nil, let mark = reading.finish(elapsedMs: { elapsedMs }) { landed(mark.shape, mark.first) }
    return reading.read(failure: cut)
  }

  // MARK: Story 358: Claude's fade, Larry's stay

  func testClaudesGhostsFadeAfterTheirTimeAndLarrysStay() {
    var turns = turns()
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    turns.larrysMarks(ghosts(.larry, 2))
    XCTAssertEqual(turns.fadeAt, t0 + .seconds(30))
    turns.fade(now: t0 + .seconds(29))
    XCTAssertEqual(turns.ghosts.count, 3, "not yet")
    turns.fade(now: t0 + .seconds(30))
    XCTAssertEqual(count(turns, .claude), 0)
    XCTAssertEqual(count(turns, .larry), 2, "Larry's stay")
    XCTAssertNil(turns.fadeAt)
  }

  func testANewAnswerOfClaudesStartsTheFadeOver() {
    var turns = turns()
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0 + .seconds(20))
    turns.fade(now: t0 + .seconds(30))
    XCTAssertEqual(count(turns, .claude), 1, "the newer set has its own 30 s")
    turns.fade(now: t0 + .seconds(50))
    XCTAssertEqual(count(turns, .claude), 0)
  }

  func testLarrysMarksNeverStartAFade() {
    var turns = turns()
    turns.land(ghosts(.larry, 2), who: .larry, first: true, now: t0)
    XCTAssertNil(turns.fadeAt)
    turns.fade(now: t0 + .seconds(3600))
    XCTAssertEqual(count(turns, .larry), 2)
  }

  // MARK: Story 357: each new set replaces only its author's

  func testAnAnswersFirstMarkReplacesOnlyItsAuthorsOwn() {
    var turns = turns()
    let claudes = ghosts(.claude, 1)
    turns.land(claudes, who: .claude, first: true, now: t0)
    turns.larrysMarks(ghosts(.larry, 2))
    XCTAssertEqual(turns.ghosts.count, 3, "Larry's beside Claude's")

    let newer = ghosts(.claude, 1)
    turns.land(newer, who: .claude, first: true, now: t0)
    XCTAssertEqual(turns.ghosts.filter { $0.who == .claude }, newer)
    XCTAssertEqual(count(turns, .larry), 2)

    turns.larrysMarks(ghosts(.larry, 3))
    XCTAssertEqual(count(turns, .larry), 3, "unprompted marks replace his unkept ones")
    XCTAssertEqual(turns.ghosts.filter { $0.who == .claude }, newer)
  }

  func testLarrysWordsShowAndHisMarksAloneClearTheNote() {
    var turns = turns()
    turns.note = "Larry has the board"
    turns.larrySaid("this is where it goes", marks: true)
    XCTAssertEqual(turns.note, "Larry: this is where it goes")
    turns.larrySaid(nil, marks: false)
    XCTAssertEqual(turns.note, "Larry: this is where it goes", "a row with nothing new leaves it")
    turns.larrySaid(nil, marks: true)
    XCTAssertNil(turns.note)
  }

  // MARK: Story 370: the count climbs; story 373: a plain answer still lands

  func testStreamedMarksLandOneAtATimeAndTheCountClimbs() {
    var turns = turns()
    turns.larrysMarks(ghosts(.larry, 2))
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    let asked = asking(&turns)
    var counts: [Int] = []
    var firsts: [Bool] = []
    let lines = Array(repeating: circle, count: 6) + [last]
    let read = feed(lines.joined(separator: "\n") + "\n", elapsedMs: 120) { _, first in
      guard turns.current(asked) else { return }
      firsts.append(first)
      turns.land([G(id: UUID().uuidString, who: .claude)], who: .claude, first: first, now: t0)
      counts.append(count(turns, .claude))
    }
    XCTAssertEqual(counts, [1, 2, 3, 4, 5, 6], "the old one replaced by the first, then one at a time")
    XCTAssertEqual(firsts, [true, false, false, false, false, false])
    XCTAssertEqual(count(turns, .larry), 2)
    XCTAssertTrue(read.streamed)
    XCTAssertEqual(read.firstShapeMs, 120)
    XCTAssertNil(read.broken)
    let landing = turns.answered(read.answer, who: .claude, asked: asked, streamed: read.streamed, said: nil)
    XCTAssertNil(landing.land, "streamed marks are on the board already")
    XCTAssertEqual(count(turns, .claude), 6)
    XCTAssertFalse(turns.turnOver(.claude))
  }

  func testAStreamWithNoMarksClearsClaudes() {
    var turns = turns()
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    let asked = asking(&turns)
    let read = feed(last + "\n") { _, _ in XCTFail("no marks") }
    XCTAssertEqual(read.answer, .shapes([]))
    let landing = turns.answered(read.answer, who: .claude, asked: asked, streamed: read.streamed, said: nil)
    XCTAssertEqual(landing.land, [])
    turns.land([], who: .claude, first: true, now: t0)
    XCTAssertEqual(count(turns, .claude), 0)
  }

  func testACockpitThatDoesNotStreamLandsItsMarksWhole() {
    var turns = turns()
    let asked = asking(&turns)
    let read = feed(#"{"ok": true, "strokes": [\#(circle)]}"#, type: "application/json") { _, _ in
      XCTFail("a plain answer lands at its end, not mark by mark")
    }
    XCTAssertFalse(read.streamed)
    XCTAssertNil(read.firstShapeMs)
    let landing = turns.answered(read.answer, who: .claude, asked: asked, streamed: read.streamed, said: nil)
    XCTAssertEqual(landing.land?.count, 1)
    XCTAssertFalse(landing.stale)
    XCTAssertNil(landing.failure)
  }

  func testAStreamBrokenPartWayKeepsTheMarksThatArrived() {
    var landed = 0
    let read = feed(circle + "\n" + circle, cut: "The network connection was lost.") { _, _ in landed += 1 }
    XCTAssertEqual(landed, 1)
    XCTAssertEqual(read.answer, .shapes(shapes(1)))
    XCTAssertNotNil(read.broken)
  }

  func testNoAnswerAtAllIsAFailureTheNoteShowsOnce() {
    struct Down: LocalizedError {
      var errorDescription: String? { "Could not connect to the server." }
    }
    var turns = turns()
    var asked = asking(&turns)
    let failure = WhiteboardStream.Reading.failure(Down(), cancelled: false)
    XCTAssertEqual(failure, "Could not connect to the server.")
    let read = WhiteboardStream.Reading().read(failure: failure)
    XCTAssertEqual(read.answer, .away(reason: failure))
    var landing = turns.answered(read.answer, who: .claude, asked: asked, streamed: read.streamed, said: nil)
    XCTAssertTrue(landing.firstFailure)
    XCTAssertEqual(landing.failure?.hasPrefix("Larry couldn't be reached"), true)
    XCTAssertEqual(turns.note, WhiteboardTurn.ghostsAway)
    _ = turns.turnOver(.claude)

    asked = asking(&turns)
    landing = turns.answered(
      .refused(status: 500, reason: "boom"), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertFalse(landing.firstFailure, "logged once a run, never a loop of errors")
    XCTAssertEqual(landing.status, 500)
    _ = turns.turnOver(.claude)

    asked = asking(&turns)
    landing = turns.answered(.shapes(shapes(1)), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertNil(turns.note, "an answer clears it")
    _ = turns.turnOver(.claude)
    asked = asking(&turns)
    XCTAssertTrue(
      turns.answered(.away(reason: "x"), who: .claude, asked: asked, streamed: false, said: nil).firstFailure)
  }

  func testADeadlinePassingIsSaidAsNoAnswerInTime() {
    struct Cancelled: Error {}
    XCTAssertEqual(
      WhiteboardStream.Reading.failure(Cancelled(), cancelled: true),
      "no answer in \(Int(WhiteboardTurn.suggestTimeout)) s")
  }

  func testAFailureLeavesLarrysWordsAndLarrysOwnClearsTheNote() {
    var turns = turns()
    turns.larrySaid("hi", marks: true)
    let asked = asking(&turns)
    _ = turns.answered(.away(reason: "x"), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertEqual(turns.note, "Larry: hi", "the note keeps what's there")
    XCTAssertFalse(turns.failed(.larry, stale: false), "the same run of failures")
    XCTAssertNil(turns.note, "Larry's failure is a copyable problem instead")
    turns.larryReached()
    XCTAssertTrue(turns.failed(.larry, stale: false))
  }

  func testAGhostLandingClearsTheNoteThatGhostsWerentAnswering() {
    var turns = turns()
    _ = turns.failed(.claude, stale: false)
    XCTAssertEqual(turns.note, WhiteboardTurn.ghostsAway)
    turns.land([], who: .claude, first: true, now: t0)
    XCTAssertEqual(turns.note, WhiteboardTurn.ghostsAway, "an empty set says nothing")
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    XCTAssertNil(turns.note)
  }

  // MARK: Stale answers

  func testAnAnswerAskedBeforeADismissalShowsNothing() {
    var turns = turns()
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    let asked = asking(&turns)
    guard case .dismiss(let count, let larrys) = turns.tap(hitting: { _ in false }) else { return XCTFail() }
    XCTAssertEqual(count, 1)
    XCTAssertFalse(larrys)
    turns.dismiss(larrys: larrys)
    XCTAssertFalse(turns.current(asked), "a streamed mark of it is dropped")
    let landing = turns.answered(.shapes(shapes(1)), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertTrue(landing.stale)
    XCTAssertNil(landing.land)
    XCTAssertTrue(turns.ghosts.isEmpty)
  }

  func testAStaleFailureSaysNothingInTheNote() {
    var turns = turns()
    let asked = asking(&turns)
    turns.setOn(false)
    turns.setOn(true)
    let landing = turns.answered(.away(reason: "x"), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertTrue(landing.stale)
    XCTAssertNotNil(landing.failure, "still logged")
    XCTAssertNil(turns.note)
  }

  // MARK: Stories 351, 367: Ghosts off asks nothing

  func testGhostsOffAsksNothingForAStrokeAndOnAgainDoes() {
    var turns = turns()
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    turns.larrysMarks(ghosts(.larry, 2))
    _ = turns.failed(.claude, stale: false)
    turns.setOn(false)
    XCTAssertEqual(count(turns, .claude), 0, "Claude's go")
    XCTAssertEqual(count(turns, .larry), 2, "Larry's are his turn's, not the switch's")
    XCTAssertNil(turns.note)
    XCTAssertFalse(turns.stroked(), "no pause, no ask")

    turns.setOn(true)
    XCTAssertTrue(turns.stroked())
    XCTAssertTrue(turns.pauseEnded())
  }

  func testGhostsOffMidTurnMakesItsAnswerStaleAndForgetsTheOwedAsk() {
    var turns = turns()
    let asked = asking(&turns)
    XCTAssertTrue(turns.stroked())
    XCTAssertFalse(turns.pauseEnded(), "owed after the turn")
    turns.setOn(false)
    let landing = turns.answered(.shapes(shapes(1)), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertTrue(landing.stale)
    XCTAssertNil(landing.land)
    XCTAssertFalse(turns.turnOver(.claude), "the owed ask is forgotten")
  }

  func testWordsSpokenWithGhostsOffAreNeitherAskedNorKept() {
    var turns = turns(on: false)
    XCTAssertEqual(turns.spoke("draw a square"), .ghostsOff)
    XCTAssertNil(turns.unsaid)
    turns.setOn(true)
    XCTAssertEqual(turns.spoke("draw a circle"), .now)
    XCTAssertEqual(turns.said(.claude), "draw a circle")
  }

  func testGhostsOffDropsWordsWaitingForTheNextTurn() {
    var turns = turns()
    _ = asking(&turns)
    XCTAssertEqual(turns.spoke("and a box"), .held)
    turns.setOn(false)
    XCTAssertNil(turns.unsaid)
  }

  // MARK: Stories 345, 360: spoken turns

  func testWordsDuringATurnGoWithTheNextAfterItLands() {
    var turns = turns()
    let asked = asking(&turns)
    XCTAssertEqual(turns.spoke("draw a circle"), .held)
    XCTAssertEqual(turns.spoke("and a box"), .held)
    XCTAssertEqual(turns.unsaid, "draw a circle and a box")
    _ = turns.answered(.shapes(shapes(1)), who: .claude, asked: asked, streamed: false, said: nil)
    XCTAssertTrue(turns.turnOver(.claude), "the words are owed their pause")
    XCTAssertTrue(turns.pauseEnded())
    XCTAssertEqual(turns.said(.claude), "draw a circle and a box")
    _ = turns.asked(.claude)
    XCTAssertNil(turns.unsaid, "taken by the turn")
  }

  func testWordsThatDidntGetThroughGoFirstInTheNextTurn() {
    var turns = turns()
    XCTAssertEqual(turns.spoke("draw a circle"), .now)
    let said = turns.said(.claude)
    let asked = turns.asked(.claude)
    XCTAssertEqual(turns.spoke("in red"), .held)
    _ = turns.answered(.away(reason: "x"), who: .claude, asked: asked, streamed: false, said: said)
    XCTAssertEqual(turns.unsaid, "draw a circle in red")
  }

  func testATurnTooSoonKeepsItsWordsAndSaysNothing() {
    var turns = turns()
    XCTAssertEqual(turns.spoke("draw a circle"), .now)
    let said = turns.said(.claude)
    let asked = turns.asked(.claude)
    let landing = turns.answered(.tooSoon, who: .claude, asked: asked, streamed: false, said: said)
    XCTAssertNil(landing.failure)
    XCTAssertNil(landing.land)
    XCTAssertNil(turns.note)
    XCTAssertEqual(turns.unsaid, "draw a circle")
  }

  func testWordsThatDidntGetThroughAreDroppedIfGhostsWentOff() {
    var turns = turns()
    XCTAssertEqual(turns.spoke("draw a circle"), .now)
    let said = turns.said(.claude)
    let asked = turns.asked(.claude)
    turns.setOn(false)
    _ = turns.answered(.away(reason: "x"), who: .claude, asked: asked, streamed: false, said: said)
    XCTAssertNil(turns.unsaid)
  }

  func testOnlyClaudesTurnCarriesTheWords() {
    var turns = turns()
    XCTAssertEqual(turns.spoke("draw a circle"), .now)
    XCTAssertNil(turns.said(.larry))
    _ = turns.asked(.larry)
    XCTAssertEqual(turns.unsaid, "draw a circle", "Larry's turn leaves them for Claude's")
  }

  func testASpokenTurnOnAnEmptyBoardFramesTheScreen() {
    typealias T = WhiteboardGhostTurns<G>
    XCTAssertTrue(T.framesScreen(said: "draw a circle", boardEmpty: true))
    XCTAssertFalse(T.framesScreen(said: nil, boardEmpty: true), "a pause on an empty board isn't asked")
    XCTAssertFalse(T.framesScreen(said: "draw a circle", boardEmpty: false))
  }

  // MARK: Story 354: a tap keeps one or dismisses them all

  func testATapKeepsTheGhostUnderItAndOffThemDismissesAll() {
    var turns = turns()
    if case .nothing = turns.tap(hitting: { _ in true }) {} else { XCTFail("no ghosts: nothing to keep or dismiss") }
    let claudes = ghosts(.claude, 1)
    let larrys = ghosts(.larry, 2)
    turns.land(claudes, who: .claude, first: true, now: t0)
    turns.larrysMarks(larrys)

    guard case .keep(let kept) = turns.tap(hitting: { $0 == larrys[1] }) else { return XCTFail() }
    XCTAssertEqual(kept, larrys[1])
    XCTAssertTrue(turns.keep(kept), "Larry's: his row is settled")
    XCTAssertEqual(turns.ghosts, claudes + [larrys[0]])
    XCTAssertFalse(turns.keep(claudes[0]))

    guard case .dismiss(let count, let hadLarrys) = turns.tap(hitting: { _ in false }) else { return XCTFail() }
    XCTAssertEqual(count, 1)
    XCTAssertTrue(hadLarrys)
    XCTAssertEqual(turns.ghosts.count, 1, "the tap only decides")
    turns.dismiss(larrys: hadLarrys)
    XCTAssertTrue(turns.ghosts.isEmpty)
  }

  /// #823: one stray tap never loses Larry's marks; with only his left, a tap off them is his to dismiss.
  func testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone() {
    var turns = turns()
    let claudes = ghosts(.claude, 1)
    let larrys = ghosts(.larry, 2)
    turns.land(claudes, who: .claude, first: true, now: t0)
    turns.larrysMarks(larrys)

    guard case .dismiss(let count, let hisToo) = turns.tap(hitting: { _ in false }) else { return XCTFail() }
    XCTAssertEqual(count, 1, "Claude's")
    XCTAssertFalse(hisToo)
    turns.dismiss(larrys: hisToo)
    XCTAssertEqual(turns.ghosts, larrys, "Larry's stay")

    guard case .dismiss(let again, let his) = turns.tap(hitting: { _ in false }) else { return XCTFail() }
    XCTAssertEqual(again, 2)
    XCTAssertTrue(his)
    turns.dismiss(larrys: his)
    XCTAssertTrue(turns.ghosts.isEmpty)
  }

  func testADismissalForgetsAPauseUnderWay() {
    var turns = turns()
    turns.land(ghosts(.claude, 1), who: .claude, first: true, now: t0)
    XCTAssertTrue(turns.stroked())
    turns.toolWentDown()
    turns.dismiss(larrys: false)
    XCTAssertFalse(turns.toolLifted(), "the dismissed turn's pause doesn't restart")
  }
}
