import Foundation
import XCTest

@testable import ContextCore

/// Stories 766 to 769: the board's note is one line that opens into the conversation.
final class WhiteboardNoteTests: XCTestCase {
  private let t0 = ContinuousClock.now

  private func at(_ seconds: Double) -> ContinuousClock.Instant { t0 + .milliseconds(Int(seconds * 1000)) }

  private func sent(version: Int = 1) -> WhiteboardLarryTurn {
    var turn = WhiteboardLarryTurn()
    _ = turn.tapped(version: version, now: at(0))
    return turn
  }

  private func line(
    _ larry: WhiteboardLarryTurn = WhiteboardLarryTurn(), now: Double = 42, answering: Bool = true,
    said: WhiteboardSaid = WhiteboardSaid(), micOn: Bool = false, notice: WhiteboardNote.Notice? = nil, ghosts: Int = 0
  ) -> WhiteboardNote.Line? {
    WhiteboardNote.line(
      larry: larry, now: at(now), cockpitAnswering: answering, said: said, micOn: micOn, notice: notice, ghosts: ghosts)
  }

  private func message(
    _ id: String, _ who: String, _ text: String, receipt: ChatMessage.Receipt = .sent, attachments: [String] = []
  ) -> ChatMessage {
    ChatMessage(id: id, ts: "", who: who, text: text, attachments: attachments, receipt: receipt)
  }

  // MARK: Closed: one line

  func testNothingToSayIsNoLine() {
    XCTAssertNil(line())
  }

  func testTheStateComesFirstAndSaysWhatIsWaiting() throws {
    XCTAssertEqual(line(sent())?.state, "Larry · 0:42")
    var turn = sent()
    _ = turn.paused(version: 2, words: nil, now: at(5))
    XCTAssertEqual(line(turn)?.state, "Larry · 0:42 · next: ink")
    turn = sent()
    _ = turn.paused(version: 1, words: "label it", now: at(5))
    XCTAssertEqual(line(turn)?.state, "Larry · 0:42 · next: words")
    _ = turn.paused(version: 3, words: "and the arrow", now: at(6))
    let both = try XCTUnwrap(line(turn, answering: false))
    XCTAssertEqual(both.state, "Larry · 0:42 · Cockpit not answering · next: ink + words")
    XCTAssertEqual(
      both.spokenState, "Larry has been looking for 42 seconds, and the Cockpit isn't answering, next: ink and words")
  }

  func testARepeatTapShowsInTheState() {
    var turn = sent()
    _ = turn.tapped(version: 1, now: at(12))
    XCTAssertEqual(line(turn, now: 12)?.state, "Larry already has this · 0:12")
  }

  func testLarrysLineKeepsItsStart() throws {
    var said = WhiteboardSaid()
    said.larrySaid("a long reply about the middle box", marks: false)
    let note = try XCTUnwrap(line(sent(), said: said))
    XCTAssertEqual(note.middle, "Larry: a long reply about the middle box")
    XCTAssertFalse(note.keepsEnd)
  }

  func testIgorsWordsKeepTheirEnd() throws {
    var said = WhiteboardSaid()
    said.larrySaid("earlier", marks: false)
    said.heard("draw a box and then an arrow to the left")
    let note = try XCTUnwrap(line(said: said, micOn: true))
    XCTAssertEqual(
      note.middle, "You: draw a box and then an arrow to the left", "the newest thing said, whoever said it")
    XCTAssertTrue(note.keepsEnd)
    XCTAssertNil(note.state)
  }

  func testWhoeverSpokeLastHasTheMiddle() {
    var said = WhiteboardSaid()
    said.heard("draw a box")
    said.larrySaid("done", marks: true)
    XCTAssertEqual(line(said: said)?.middle, "Larry: done")
    said.larrySaid(nil, marks: true)
    XCTAssertEqual(line(said: said)?.middle, "You: draw a box", "marks with no words take his line away, as before")
  }

  func testAnOpenMicWithNothingHeardIsListening() {
    var said = WhiteboardSaid()
    said.larrySaid("earlier", marks: false)
    said.micOpened()
    XCTAssertEqual(line(said: said, micOn: true)?.middle, "Listening…")
    XCTAssertEqual(line(said: said, micOn: false)?.middle, "Larry: earlier", "the mic closed with nothing heard")
  }

  func testANoticeTakesTheMiddleForAFewSecondsAndGivesItBack() {
    var said = WhiteboardSaid()
    said.larrySaid("this is where it goes", marks: true)
    let notice = WhiteboardNote.Notice(text: "Sent to Larry: his reply shows in Chat", since: at(10))
    XCTAssertEqual(line(now: 10, said: said, notice: notice)?.middle, "Sent to Larry: his reply shows in Chat")
    XCTAssertEqual(line(now: 14.9, said: said, notice: notice)?.middle, "Sent to Larry: his reply shows in Chat")
    XCTAssertEqual(line(now: 15, said: said, notice: notice)?.middle, "Larry: this is where it goes")
    XCTAssertEqual(
      line(now: 60, notice: notice)?.middle, "Sent to Larry: his reply shows in Chat", "with nothing said it stays")
    XCTAssertTrue(WhiteboardNote.ticks(larry: WhiteboardLarryTurn(), notice: notice), "the line changes at five seconds")
  }

  // The ghost stories' "until a turn gets through": Larry spoke earlier, then the Cockpit stops answering.
  func testAMessageAboutTheCockpitNotAnsweringKeepsTheMiddle() {
    var said = WhiteboardSaid()
    said.larrySaid("this is where it goes", marks: true)
    let away = "Larry's marks: the Cockpit isn't answering"
    let notice = WhiteboardNote.Notice(text: away, held: away, since: at(10))
    XCTAssertEqual(line(now: 10, said: said, notice: notice)?.middle, away)
    XCTAssertEqual(line(now: 600, said: said, notice: notice)?.middle, away, "still true ten minutes on")
    XCTAssertEqual(line(now: 600, said: said)?.middle, "Larry: this is where it goes", "back once it answers")
    XCTAssertFalse(WhiteboardNote.ticks(larry: WhiteboardLarryTurn(), notice: notice), "nothing to give back")
  }

  func testAPassingMessageBesideAHeldOneLeavesTheHeldOne() {
    var said = WhiteboardSaid()
    said.larrySaid("this is where it goes", marks: true)
    let notice = WhiteboardNote.Notice(
      text: "\(WhiteboardTurn.ghostsAway) · Only the first 200 characters", held: WhiteboardTurn.ghostsAway,
      since: at(10))
    XCTAssertEqual(
      line(now: 12, said: said, notice: notice)?.middle, "\(WhiteboardTurn.ghostsAway) · Only the first 200 characters")
    XCTAssertEqual(line(now: 15, said: said, notice: notice)?.middle, WhiteboardTurn.ghostsAway)
    XCTAssertEqual(line(now: 15, notice: notice)?.middle, WhiteboardTurn.ghostsAway, "with nothing said too")
  }

  func testHowManyToKeep() {
    XCTAssertEqual(line(ghosts: 3)?.keep, "3 to keep")
    XCTAssertEqual(line(ghosts: 1)?.keep, "1 to keep")
    XCTAssertNil(line(sent(), ghosts: 0)?.keep)
  }

  func testWhichMessagesAreNotices() {
    XCTAssertNil(
      WhiteboardNote.notice(
        paste: nil, sent: nil, turnNote: "Larry: hello", marksAway: false, looking: false, lookOnly: nil),
      "his line is said, not a notice")
    let both = WhiteboardNote.notice(
      paste: "Only the first 200 characters", sent: nil, turnNote: WhiteboardTurn.ghostsAway, marksAway: false,
      looking: false, lookOnly: nil)
    XCTAssertEqual(both?.text, "\(WhiteboardTurn.ghostsAway) · Only the first 200 characters")
    XCTAssertEqual(both?.held, WhiteboardTurn.ghostsAway, "the Cockpit not answering stays; the paste passes")
    let marks = WhiteboardNote.notice(
      paste: nil, sent: nil, turnNote: nil, marksAway: true, looking: false, lookOnly: nil)
    XCTAssertEqual(marks?.text, "Larry's marks: the Cockpit isn't answering")
    XCTAssertEqual(marks?.held, "Larry's marks: the Cockpit isn't answering")
    XCTAssertNil(
      WhiteboardNote.notice(paste: nil, sent: nil, turnNote: nil, marksAway: true, looking: true, lookOnly: nil),
      "while he is looking his state says it")
    let sent = WhiteboardNote.notice(
      paste: nil, sent: "Sent to Larry", turnNote: nil, marksAway: false, looking: false, lookOnly: "Look only")
    XCTAssertEqual(sent?.text, "Sent to Larry")
    XCTAssertNil(sent?.held)
    let lookOnly = WhiteboardNote.notice(
      paste: nil, sent: nil, turnNote: nil, marksAway: false, looking: false, lookOnly: "Look only")
    XCTAssertEqual(lookOnly?.text, "Look only")
    XCTAssertNil(lookOnly?.held, "the spec has a look-only reason give the middle back")
    let micOff = WhiteboardNote.notice(
      paste: nil, sent: nil, turnNote: WhiteboardTurn.micGhostsOff, marksAway: false, looking: false, lookOnly: nil)
    XCTAssertEqual(micOff?.text, WhiteboardTurn.micGhostsOff)
    XCTAssertNil(micOff?.held, "the answer to a tap on the mic passes")
  }

  // MARK: The tap

  func testATapOpensThePanelOrOnAPhoneTheThread() {
    XCTAssertEqual(WhiteboardNote.tap(onPhone: false, thread: nil), .toggle)
    XCTAssertEqual(WhiteboardNote.tap(onPhone: false, thread: "t1"), .toggle)
    XCTAssertEqual(WhiteboardNote.tap(onPhone: true, thread: "t1"), .openChat("t1"))
    XCTAssertEqual(WhiteboardNote.tap(onPhone: true, thread: nil), .nothing)
  }

  // MARK: Open: the conversation

  func testThePanelShowsTheThreadWithItsMarksAndWhatIsLive() {
    var turn = sent()
    _ = turn.paused(version: 2, words: "and label the arrow", now: at(5))
    var said = WhiteboardSaid()
    said.heard("make it bigger")
    let rows = WhiteboardNote.recent([
      message("a", "igor", "Your turn on the board", receipt: .done, attachments: ["img"]),
      message("b", "larry", "This is where it goes, beside the box."),
      message("c", "igor", "", receipt: .seen, attachments: ["img"]),
      message("d", "larry", ""),
    ])
    XCTAssertEqual(
      rows,
      [
        .init(id: "a", kind: .you, who: "You", text: "Your turn on the board", mark: "done"),
        .init(id: "b", kind: .larry, who: "Larry", text: "This is where it goes, beside the box.", mark: nil),
        .init(id: "c", kind: .you, who: "You", text: "a picture", mark: "seen"),
        .init(id: "d", kind: .larry, who: "Larry", text: "drew on the board", mark: nil),
      ])
    XCTAssertEqual(
      WhiteboardNote.live(larry: turn, now: at(42), cockpitAnswering: true, said: said, micOn: true),
      [
        .init(id: "live-turn", kind: .live, who: "Now", text: "Larry · 0:42", mark: nil),
        .init(id: "live-next", kind: .live, who: "Next", text: "ink + words: and label the arrow", mark: nil),
        .init(id: "live-mic", kind: .live, who: "Hearing", text: "make it bigger", mark: nil),
      ])
  }

  func testThePanelHoldsTheLastTenMessages() {
    let thread = (1...14).map { message("m\($0)", $0.isMultiple(of: 2) ? "larry" : "igor", "line \($0)") }
    let rows = WhiteboardNote.recent(thread)
    XCTAssertEqual(rows.map(\.id), (5...14).map { "m\($0)" }, "newest at the bottom")
  }

  func testABoardWithNoThreadShowsOnlyWhatIsLive() {
    var said = WhiteboardSaid()
    said.micOpened()
    XCTAssertEqual(WhiteboardNote.recent([]), [])
    XCTAssertEqual(
      WhiteboardNote.live(larry: sent(), now: at(3), cockpitAnswering: false, said: said, micOn: true),
      [
        .init(id: "live-turn", kind: .live, who: "Now", text: "Larry · 0:03 · Cockpit not answering", mark: nil),
        .init(id: "live-mic", kind: .live, who: "Hearing", text: "Listening…", mark: nil),
      ])
  }

  func testASkillsRowIsNamedForIt() {
    let rows = WhiteboardNote.recent([ChatMessage(id: "s", ts: "", who: "larry", text: "hi", author: "idvorkin")])
    XCTAssertEqual(rows.first?.who, "idvorkin")
  }
}
