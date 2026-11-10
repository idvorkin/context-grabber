import Foundation
import XCTest

@testable import ContextCore

/// Stories 659–661: the board's responder knob, the half-second pause, and the iPad's timings for each ghost turn.
final class WhiteboardResponderTests: XCTestCase {
  private let cockpit = "https://cockpit.example"

  // MARK: The knob on the wire

  func testTheReadAsksForTheBoard() throws {
    let request = try WhiteboardResponder.readRequest(board: "b 1", cockpit: cockpit)
    XCTAssertEqual(request.httpMethod ?? "GET", "GET")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example/whiteboard/responder?board=b%201")
    XCTAssertEqual(request.timeoutInterval, WhiteboardResponder.timeout)
  }

  func testTheWriteNamesTheBoardAndTheResponder() throws {
    let request = try WhiteboardResponder.writeRequest(.haiku, board: "b1", cockpit: cockpit)
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example/whiteboard/responder")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String])
    XCTAssertEqual(body, ["board": "b1", "responder": "haiku"])
  }

  func testTheCockpitsAnswerIsTheBoardsResponder() {
    let body = Data(
      #"""
      {"ok": true, "board": "b1", "responder": "larry", "set": true, "at": "2026-11-10T09:00:00Z",
       "default": "sonnet", "choices": ["haiku", "sonnet", "larry"]}
      """#.utf8)
    XCTAssertEqual(WhiteboardResponder.reply(status: 200, body: body), .responder(.larry))
  }

  func testAnAnswerThatCantBeReadIsAFailure() {
    XCTAssertEqual(
      WhiteboardResponder.reply(status: 400, body: Data(#"{"ok": false, "error": "responder must be one of"}"#.utf8)),
      .failed(reason: "responder must be one of", status: 400))
    XCTAssertEqual(
      WhiteboardResponder.reply(status: 404, body: Data("not found".utf8)), .failed(reason: "HTTP 404", status: 404))
    XCTAssertEqual(
      WhiteboardResponder.reply(status: 200, body: Data(#"{"ok": true, "responder": "opus"}"#.utf8)),
      .failed(reason: "no responder in the answer", status: 200), "a responder this build doesn't know")
    XCTAssertEqual(
      WhiteboardResponder.reply(status: nil, body: nil, error: "offline"), .failed(reason: "offline", status: nil))
  }

  func testTheMenuNamesThreeInOrder() {
    XCTAssertEqual(WhiteboardResponder.allCases.map(\.name), ["Haiku", "Sonnet", "Larry"])
    XCTAssertEqual(WhiteboardResponder.fallback, .sonnet)
  }

  // MARK: The knob as the menu shows it

  func testSonnetIsTickedUntilTheCockpitSays() {
    var knob = WhiteboardResponderKnob()
    XCTAssertEqual(knob.shown, .sonnet)
    XCTAssertFalse(knob.known)
    knob.heard(.haiku, asked: knob.generation)
    XCTAssertEqual(knob.shown, .haiku)
    XCTAssertTrue(knob.known)
  }

  func testAChoiceMadeBeforeTheReadAnswersWins() {
    var knob = WhiteboardResponderKnob()
    let asked = knob.generation
    let choice = knob.chose(.larry)
    XCTAssertNotNil(choice)
    knob.heard(.haiku, asked: asked)
    XCTAssertEqual(knob.shown, .larry, "the read went out before the choice")
    knob.wrote(.larry, choice: choice!)
    XCTAssertEqual(knob.shown, .larry)
    knob.heard(.haiku, asked: asked)
    XCTAssertEqual(knob.shown, .larry, "still older than the choice, even once it has landed")
  }

  func testAReadWhileAChoiceIsOnItsWayIsIgnored() {
    var knob = WhiteboardResponderKnob()
    knob.heard(.sonnet, asked: knob.generation)
    _ = knob.chose(.haiku)
    knob.heard(.sonnet, asked: knob.generation)
    XCTAssertEqual(knob.shown, .haiku)
  }

  func testChoosingWhatTheBoardHasWritesNothing() {
    var knob = WhiteboardResponderKnob()
    knob.heard(.sonnet, asked: knob.generation)
    XCTAssertNil(knob.chose(.sonnet))
  }

  func testWithTheCockpitUnheardEvenTheTickedOneIsWritten() {
    var knob = WhiteboardResponderKnob()
    XCTAssertNotNil(knob.chose(.sonnet), "the board may be Larry's: the read never came")
  }

  func testAFailedWriteTakesTheTickBack() {
    var knob = WhiteboardResponderKnob()
    knob.heard(.haiku, asked: knob.generation)
    let choice = knob.chose(.larry)!
    XCTAssertEqual(knob.shown, .larry)
    XCTAssertTrue(knob.wrote(nil, choice: choice))
    XCTAssertEqual(knob.shown, .haiku)
  }

  func testOnlyTheNewestChoiceMovesTheTick() {
    var knob = WhiteboardResponderKnob()
    knob.heard(.sonnet, asked: knob.generation)
    let first = knob.chose(.haiku)!
    let second = knob.chose(.larry)!
    XCTAssertFalse(knob.wrote(.haiku, choice: first))
    XCTAssertEqual(knob.shown, .larry, "the newer choice is still on its way")
    XCTAssertTrue(knob.wrote(nil, choice: second))
    XCTAssertEqual(knob.shown, .haiku, "back to what the Cockpit last took, the first choice")
  }

  func testATurnsAnswerUpdatesTheTickOnceNothingIsPending() {
    var knob = WhiteboardResponderKnob()
    knob.heard(.sonnet, asked: knob.generation)
    // Another device set the board to Larry; this one hears it from the next ghost turn.
    knob.heard(.larry, asked: knob.generation)
    XCTAssertEqual(knob.shown, .larry)
  }

  // MARK: Who answered a ghost turn

  func testTheStreamsLastLineSaysWhoAnswered() {
    var reader = WhiteboardStream(status: 200, contentType: "application/x-ndjson")
    let body = #"{"done": true, "ms": 0, "strokes": 0, "model": null, "responder": "larry", "note": "send it"}"# + "\n"
    for byte in body.utf8 { _ = reader.take(byte) }
    XCTAssertTrue(reader.done)
    XCTAssertEqual(reader.responder, .larry)
    XCTAssertEqual(reader.answer(), .shapes([]))
  }

  func testAWholeAnswerSaysWhoAnswered() {
    var reading = WhiteboardStream.Reading()
    reading.opened(status: 200, contentType: "application/json")
    for byte in #"{"ok": true, "strokes": [], "model": "m", "responder": "haiku"}"#.utf8 {
      _ = reading.take(byte, elapsedMs: { 0 })
    }
    XCTAssertEqual(reading.read().responder, .haiku)
  }

  func testACockpitThatDoesntSayLeavesItUnknown() {
    var reader = WhiteboardStream(status: 200, contentType: "application/x-ndjson")
    for byte in (#"{"done": true, "ms": 900}"# + "\n").utf8 { _ = reader.take(byte) }
    XCTAssertNil(reader.responder)
  }

  // MARK: Handing a Larry board to Larry

  private func handOff(
    _ answered: WhiteboardResponder?, _ answer: WhiteboardTurn.Answer = .shapes([]), stale: Bool = false,
    waiting: Bool = false
  ) -> WhiteboardResponder.HandOff {
    WhiteboardResponder.handOff(answered: answered, answer: answer, stale: stale, firstSendWaiting: waiting)
  }

  func testALarryBoardsPauseGoesToHisThread() {
    XCTAssertEqual(handOff(.larry), .hand)
  }

  func testClaudesAnswerHandsNothing() {
    XCTAssertEqual(handOff(.sonnet), .nothing)
    XCTAssertEqual(handOff(.haiku), .nothing)
    XCTAssertEqual(handOff(nil), .nothing, "a Cockpit that doesn't say")
    XCTAssertEqual(handOff(.larry, .away(reason: "down")), .nothing)
    XCTAssertEqual(handOff(.larry, .tooSoon), .nothing)
    let mark = WhiteboardTurn.Shape(kind: .line, points: [.zero, CGPoint(x: 1, y: 1)])
    XCTAssertEqual(handOff(.larry, .shapes([mark])), .nothing, "marks came: they show as ghosts")
  }

  func testALarryBoardIsntHandedOnAStaleTurnOrBeforeItsThreadExists() {
    XCTAssertEqual(handOff(.larry, stale: true), .skipped("stale"))
    XCTAssertEqual(handOff(.larry, waiting: true), .skipped("first_send_waiting"))
  }

  // MARK: The pause and the timings

  func testThePauseIsHalfASecond() {
    XCTAssertEqual(WhiteboardPacer.pause, .milliseconds(500))
  }

  func testTimingsRoundToWholeMilliseconds() {
    XCTAssertEqual(WhiteboardTimings.ms(.milliseconds(500)), 500)
    XCTAssertEqual(WhiteboardTimings.ms(.microseconds(12_600)), 13)
    XCTAssertEqual(WhiteboardTimings.ms(.microseconds(12_400)), 12)
    XCTAssertEqual(WhiteboardTimings.ms(.seconds(2) + .milliseconds(3)), 2003)
    XCTAssertEqual(WhiteboardTimings.ms(.zero), 0)
    XCTAssertNil(WhiteboardTimings.ms(.milliseconds(-4)))
  }

  func testTheCockpitGetsWhatIsKnownBeforeTheRequestGoes() {
    let timings = WhiteboardTimings(
      pause: .milliseconds(503), render: .milliseconds(41), encode: .milliseconds(18), upload: .milliseconds(120))
    XCTAssertEqual(timings.wire, ["pause_ms": 503, "render_ms": 41, "encode_ms": 18])
    XCTAssertEqual(timings.logFields, ["pause_ms": 503, "render_ms": 41, "encode_ms": 18, "upload_ms": 120])
  }

  func testASpokenTurnHasNoPause() {
    let timings = WhiteboardTimings(render: .milliseconds(30), encode: .milliseconds(9))
    XCTAssertEqual(timings.wire, ["render_ms": 30, "encode_ms": 9])
    XCTAssertEqual(timings.logFields, ["render_ms": 30, "encode_ms": 9])
  }

  func testTheGhostRequestCarriesTheBoardAndTimings() throws {
    let request = try WhiteboardTurn.suggestRequest(
      title: "Plan", picture: Data([1]), width: 8, height: 6, cockpit: cockpit, board: "b1",
      timings: ["pause_ms": 500, "render_ms": 40])
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["board"] as? String, "b1")
    XCTAssertEqual(body["timings"] as? [String: Int], ["pause_ms": 500, "render_ms": 40])
    XCTAssertNil(body["responder"], "the board's knob decides; no per-turn override in this piece")
  }

  func testAGhostRequestWithNeitherLeavesThemOut() throws {
    let request = try WhiteboardTurn.suggestRequest(
      title: "Plan", picture: Data([1]), width: 8, height: 6, cockpit: cockpit)
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertNil(body["board"])
    XCTAssertNil(body["timings"])
  }
}
