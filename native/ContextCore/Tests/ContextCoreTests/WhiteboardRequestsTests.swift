import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// The board's HTTP requests to the Cockpit. They live in ContextCore, not BoardCore, so the board's rules build for
/// WebAssembly (spec 2026-11-22-board-rules-on-the-web-design.md); these cases moved here from the board's own test
/// files unchanged.
final class WhiteboardRequestsTests: XCTestCase {
  private let cockpit = "https://cockpit.example"

  // MARK: Stories 845–851: what Larry hears of a control (from BoardOpsControlsTests)

  func testATapOnAControlPostsTheReport() throws {
    let report = BoardTurnReport(
      rev: 9, opResult: BoardOps.Result(label: "fold", ok: true, rev: 9),
      events: [.overlayTap(id: "b", event: nil, t: 1)])
    let request = try BoardEventsSend.request(board: "b1", report: report, cockpit: "https://c.example")
    XCTAssertEqual(request.url?.absoluteString, "https://c.example/whiteboard/events")
    XCTAssertEqual(request.httpMethod, "POST")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["board"] as? String, "b1")
    XCTAssertEqual(body["rev"] as? Int, 9)
    XCTAssertEqual((body["op_result"] as? [String: Any])?["label"] as? String, "fold")
    XCTAssertEqual((body["events"] as? [[String: Any]])?.first?["target_id"] as? String, "b")
  }

  // MARK: Story 920: to text (from BoardToTextTests)

  func testTheRequestIsThePictureAndTheBoardAsTheWebBoardSendsThem() throws {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
    let request = try BoardToText.request(png: png, board: "board-7", cockpit: "https://cockpit.example:5004")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example:5004/ink/to-text")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://cockpit.example:5004")
    XCTAssertGreaterThan(request.timeoutInterval, 90, "past the Cockpit's own 90 s")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
    XCTAssertEqual(body, ["name": "board-7", "png": png.base64EncodedString()])
    XCTAssertThrowsError(try BoardToText.request(png: png, board: "b", cockpit: "not a url"))
  }

  // MARK: Stories 659–661: the responder knob and the ghost request (from WhiteboardResponderTests)

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

  // MARK: Story 857: folds beside the strokes (from BoardOutlineTests)

  func testFoldsGoBesideTheStrokesToTheCockpit() throws {
    let picture = WhiteboardPicture(board: "b1", title: "t", rect: CGRect(x: 0, y: 0, width: 10, height: 10), scale: 1)
    let fold: [String: Any] = ["header": "h-1", "header_strokes": ["a"], "lines": 2, "strokes": ["b"]]
    let request = try WhiteboardStrokes.request(
      picture: picture, strokes: [], folds: [fold], cockpit: "https://c.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual((body["folds"] as? [[String: Any]])?.first?["header"] as? String, "h-1")
    let none = try WhiteboardStrokes.request(picture: picture, strokes: [], cockpit: "https://c.example")
    let plain = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(none.httpBody)) as? [String: Any])
    XCTAssertNil(plain["folds"], "no folds, no field")
  }

  // MARK: The ghost request (from WhiteboardTurnTests)

  func testTheGhostRequestCarriesThePictureAndItsSize() throws {
    let request = try WhiteboardTurn.suggestRequest(
      title: "Plan", picture: Data([1, 2, 3]), width: 800, height: 600, cockpit: "https://cockpit.example")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example/whiteboard/suggest")
    XCTAssertEqual(request.timeoutInterval, 10)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/x-ndjson")
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["image"] as? String, Data([1, 2, 3]).base64EncodedString())
    XCTAssertEqual(body["width"] as? Int, 800)
    XCTAssertEqual(body["height"] as? Int, 600)
    XCTAssertEqual(body["text"] as? String, "Plan")
  }

  // MARK: Question cards on the wire (from WhiteboardQuestionsTests)

  func testTheWireAsksForSnoozedAsksAndEncodesTheIDs() throws {
    let cockpit = "https://cockpit.example.ts.net:8443/"
    XCTAssertEqual(
      try WhiteboardQuestions.asksRequest(cockpit: cockpit).url?.absoluteString,
      "https://cockpit.example.ts.net:8443/asks?snoozed=1")
    XCTAssertEqual(
      try WhiteboardQuestions.answersRequest(["igor2-88g.1", "b 2"], cockpit: cockpit).url?.absoluteString,
      "https://cockpit.example.ts.net:8443/ink/answers?ids=igor2-88g.1,b%202")
    XCTAssertThrowsError(try WhiteboardQuestions.answersRequest([], cockpit: cockpit))
    XCTAssertThrowsError(try WhiteboardQuestions.asksRequest(cockpit: "not a url"))
  }

  func testOwnWordsAreTheInboxsFreeTextAnswer() throws {
    let json: [String: Any] = [
      "id": "b-1", "title": "Renew the gym?", "context": "", "updated_at": "2026-11-16T10:00:00Z", "thread": NSNull(),
      "options": [["key": "yes", "label": "Renew"], ["key": "no", "label": "Let it lapse"]],
    ]
    let a = try XCTUnwrap(
      ChatDecisions.asks(JSONSerialization.data(withJSONObject: ["ok": true, "asks": [json]]))?.first)
    let request = try ChatDecisions.request(
      .ownWords(" every month "), ask: a, cockpit: "https://cockpit.example.ts.net:8443/")
    XCTAssertEqual(request.url?.path, "/act")
    let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? NSDictionary)
    XCTAssertEqual(body["response"] as? String, "DECISION: every month")
    XCTAssertEqual(body["action"] as? String, "respond")
    XCTAssertEqual(body["base_updated_at"] as? String, "2026-11-16T10:00:00Z")
  }

  // MARK: Stories 1316, 1317 (#1387): Thinking talks on the ask's own chat thread

  func testThinkingWordsPostToTheAsksOwnThread() throws {
    let request = try WhiteboardQuestions.thinkRequest(
      ask: "igor2-88g.879", words: "  Month to month?  ", id: "m-1", cockpit: "https://c.example/")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.absoluteString, "https://c.example/chat")
    let body = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["subject_id"] as? String, "igor2-88g.879", "Larry: the ask's id names its thread")
    XCTAssertEqual(body["text"] as? String, "Month to month?")
    XCTAssertEqual(body["id"] as? String, "m-1", "a resend lands once")
    XCTAssertEqual(body["source"] as? String, "app")
    XCTAssertNil(body["attachments"], "no picture")
  }

  func testTheConversationIsReadFromTheAsksThread() throws {
    let request = try WhiteboardQuestions.talkRequest(ask: "igor2-88g.879", cockpit: "https://c.example")
    XCTAssertEqual(request.url?.absoluteString, "https://c.example/chat/igor2-88g.879")
    let data = Data(
      #"""
      {"ok":true,"version":3,"messages":[
        {"id":"a","ts":"2026-11-24T10:00:00Z","who":"igor","text":"Month to month?"},
        {"id":"b","ts":"2026-11-24T10:01:00Z","who":"larry","text":"Cheaper by the year."}]}
      """#.utf8)
    let talk = try XCTUnwrap(ChatWire.messages(data))
    XCTAssertEqual(talk.map(\.who), ["igor", "larry"])
    XCTAssertEqual(talk.last?.text, "Cheaper by the year.")
  }
}
