import Foundation
import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Story 419 (cockpit-f7c): the board's strokes go to the Cockpit before each picture, in board points, with ids the
/// Cockpit can tell apart across sends.
final class WhiteboardStrokesTests: XCTestCase {
  private let frame = CGRect(x: 9597, y: 9421, width: 694, height: 165)
  private let points = [CGPoint(x: 9640.04, y: 9460), CGPoint(x: 9700, y: 9462.26), CGPoint(x: 9760, y: 9470)]

  func testAnIdIsStableAndTellsStrokesApart() {
    let a = WhiteboardStrokes.id(points: points, color: "#000000", t: 1_762_189_070_000)
    XCTAssertEqual(a.count, 16)
    XCTAssertEqual(a, WhiteboardStrokes.id(points: points, color: "#000000", t: 1_762_189_070_000), "the same again")
    XCTAssertEqual(
      a,
      WhiteboardStrokes.id(
        points: points.map { CGPoint(x: $0.x + 0.001, y: $0.y) }, color: "#000000", t: 1_762_189_070_000),
      "a thousandth of a point is the same ink")
    XCTAssertNotEqual(
      a, WhiteboardStrokes.id(points: Array(points.dropLast()), color: "#000000", t: 1_762_189_070_000))
    XCTAssertNotEqual(a, WhiteboardStrokes.id(points: points, color: "#1e6fd9", t: 1_762_189_070_000))
    XCTAssertNotEqual(a, WhiteboardStrokes.id(points: points, color: "#000000", t: 1_762_189_071_000))
    XCTAssertEqual(
      WhiteboardStrokes.id(points: points, color: "#1E6FD9", t: nil),
      WhiteboardStrokes.id(points: points, color: "#1e6fd9", t: nil), "colour case doesn't count")
  }

  func testColourAndToolAreWhatTheCockpitTakes() {
    XCTAssertEqual(WhiteboardStrokes.hex(red: 0, green: 0, blue: 0), "#000000")
    XCTAssertEqual(WhiteboardStrokes.hex(red: 0.118, green: 0.435, blue: 0.851), "#1e6fd9")
    XCTAssertEqual(WhiteboardStrokes.hex(red: 2, green: -1, blue: 1), "#ff00ff", "clamped")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.pen"), "pen")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.fountainPen"), "fountainpen")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "com.apple.ink.marker"), "marker")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: ""), "pen")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "x.9lives"), "pen", "must start with a letter")
    XCTAssertEqual(WhiteboardStrokes.tool(rawValue: "x.averyveryverylongtoolname"), "averyveryverylon")
  }

  func testAWidthFollowsTheStrokesScale() {
    let sizes: [CGFloat] = [2, 4]
    XCTAssertEqual(WhiteboardStrokes.width(sizes: sizes, transform: .identity), 3, accuracy: 0.0001)
    XCTAssertEqual(
      WhiteboardStrokes.width(sizes: sizes, transform: CGAffineTransform(scaleX: 3, y: 3)), 9, accuracy: 0.0001,
      "a lasso's 3x resize makes the ink three times as heavy")
    XCTAssertEqual(
      WhiteboardStrokes.width(sizes: sizes, transform: CGAffineTransform(a: 0, b: 2, c: -2, d: 0, tx: 50, ty: 70)), 6,
      accuracy: 0.0001, "a quarter turn at 2x: turning and moving add no weight")
  }

  func testThinningKeepsTheEndsAndTheCap() {
    let many = (0..<10_000).map { CGPoint(x: CGFloat($0), y: 0.123) }
    let thinned = WhiteboardStrokes.thin(many)
    XCTAssertLessThanOrEqual(thinned.count, WhiteboardStrokes.maxPoints)
    XCTAssertEqual(thinned.first, CGPoint(x: 0, y: 0.1))
    XCTAssertEqual(thinned.last, CGPoint(x: 9999, y: 0.1))
    XCTAssertEqual(WhiteboardStrokes.thin([CGPoint(x: 1.26, y: 2)]), [CGPoint(x: 1.3, y: 2)], "a dot stays a dot")
    XCTAssertEqual(WhiteboardStrokes.thin(points, max: 2), [CGPoint(x: 9640, y: 9460), CGPoint(x: 9760, y: 9470)])
  }

  func testTheRequestCarriesThePictureAndTheStrokes() throws {
    let picture = WhiteboardPicture(board: "b1", title: "Plan", rect: frame, scale: 2, pictureID: "p1")
    let strokes = [
      WhiteboardStrokes.Stroke(id: "s1", t: 7, points: points),
      WhiteboardStrokes.Stroke(id: "s2", color: "#1e6fd9", width: 3.7, tool: "marker", points: [points[0]]),
    ]
    let request = try WhiteboardStrokes.request(
      picture: picture, strokes: WhiteboardStrokes.wire(strokes), cockpit: "https://c.example")
    XCTAssertEqual(request.url?.absoluteString, "https://c.example/whiteboard/strokes")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://c.example")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["board"] as? String, "b1")
    XCTAssertEqual(body["picture_id"] as? String, "p1")
    XCTAssertEqual(body["frame"] as? [String: Double], ["x": 9597, "y": 9421, "w": 694, "h": 165, "scale": 2])
    XCTAssertNil(body["title"], "the title is the chat message's, not the strokes'")
    let sent = try XCTUnwrap(body["strokes"] as? [[String: Any]])
    XCTAssertEqual(sent.count, 2)
    XCTAssertEqual(sent[0]["id"] as? String, "s1")
    XCTAssertEqual(sent[0]["t"] as? Int, 7)
    XCTAssertEqual(sent[0]["color"] as? String, "#000000")
    XCTAssertEqual(sent[0]["tool"] as? String, "pen")
    XCTAssertEqual(sent[0]["width"] as? Double, 3)
    XCTAssertEqual(sent[0]["points"] as? [[Double]], [[9640, 9460], [9700, 9462.3], [9760, 9470]])
    XCTAssertNil(sent[1]["t"])
    XCTAssertEqual(sent[1]["width"] as? Double, 3.7)
    XCTAssertEqual(sent[1]["points"] as? [[Double]], [[9640, 9460]])
  }

  func testWireStopsAtTheCockpitsCap() {
    let strokes = (0..<(WhiteboardStrokes.maxStrokes + 5)).map {
      WhiteboardStrokes.Stroke(id: "s\($0)", points: [.zero])
    }
    XCTAssertEqual(WhiteboardStrokes.wire(strokes).count, WhiteboardStrokes.maxStrokes)
  }

  func testTheAnswerIsStoredRefusedOrAway() {
    XCTAssertEqual(
      WhiteboardStrokes.answer(
        status: 200, body: Data(#"{"ok": true, "count": 73, "new": 2, "erased": 1}"#.utf8)),
      .stored(count: 73, new: 2, erased: 1))
    XCTAssertEqual(
      WhiteboardStrokes.answer(
        status: 400, body: Data(#"{"ok": false, "error": "stroke 3: a point is off the board"}"#.utf8)),
      .refused(status: 400, reason: "stroke 3: a point is off the board"))
    XCTAssertEqual(WhiteboardStrokes.answer(status: 413, body: nil), .refused(status: 413, reason: "HTTP 413"))
    XCTAssertEqual(WhiteboardStrokes.answer(status: 503, body: Data("<html>".utf8)), .away(reason: "HTTP 503"))
    XCTAssertEqual(WhiteboardStrokes.answer(status: nil, body: nil, error: "offline"), .away(reason: "offline"))
    XCTAssertEqual(
      WhiteboardStrokes.answer(status: 200, body: Data(#"{"ok": false}"#.utf8)), .away(reason: "HTTP 200"),
      "a 200 that says no is no answer")
    let fields = WhiteboardStrokes.logFields(.stored(count: 73, new: 2, erased: 1))
    XCTAssertEqual(fields["strokes"] as? Int, 73)
    XCTAssertEqual(fields["strokes_ok"] as? Bool, true)
    XCTAssertEqual(WhiteboardStrokes.logFields(.away(reason: "x"))["strokes_ok"] as? Bool, false)
  }

  // MARK: Through the outbox (Send to Larry)

  func testStrokesWaitBesideThePictureAndGoBeforeItWhateverTheCockpitSays() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = InboxStore(directory: dir)
    var draft = InboxDraft()
    draft.image = TestImages.png
    draft.text = "Board, Nov 3"
    draft.whiteboard = WhiteboardPicture(board: "b1", title: "Board, Nov 3", rect: frame, scale: 2, pictureID: "p1")
    draft.strokes = try JSONSerialization.data(
      withJSONObject: WhiteboardStrokes.wire([WhiteboardStrokes.Stroke(id: "s1", points: points)]))
    let item = try draft.save(to: store, at: 1, id: "m1")
    XCTAssertEqual(item.strokesFile, "m1.strokes")
    XCTAssertEqual(store.item("m1")?.strokesFile, "m1.strokes", "the file's name survives the outbox")
    XCTAssertNotNil(store.strokes(of: item))
    XCTAssertEqual(store.items().items.map(\.id), ["m1"])
    XCTAssertEqual(store.items().unreadable, [], "the strokes beside an item are not an unreadable item")

    let calls = Calls()
    let sender = InboxSender(
      store: store, cockpit: "https://c.example", threads: freshThreads(), readyImage: TestImages.asTheyAre
    ) { request in
      let url = try XCTUnwrap(request.url)
      await calls.add(url.path, body: request.httpBody)
      let (status, body): (Int, String) =
        switch url.path {
        case "/attachments": (200, #"{"ok": true, "ref": "r1"}"#)
        case "/whiteboard/strokes": (500, "boom")
        default: (200, #"{"ok": true, "thread": "t1"}"#)
        }
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
      )
    }
    var lines: [[String: Any]] = []
    let report = await sender.sendWaiting { _, fields in lines.append(fields) }
    XCTAssertEqual(report.sent, ["m1"], "a 500 to the strokes never stops the picture")
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/whiteboard/strokes", "/chat"], "strokes before the message")
    let bodies = await calls.bodies
    let sent = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(bodies["/whiteboard/strokes"])) as? [String: Any])
    XCTAssertEqual(sent["board"] as? String, "b1")
    XCTAssertEqual(sent["picture_id"] as? String, "p1")
    XCTAssertEqual((sent["strokes"] as? [[String: Any]])?.first?["id"] as? String, "s1")
    XCTAssertEqual(lines.first?["action"] as? String, "sent")
    XCTAssertEqual(lines.first?["strokes_ok"] as? Bool, false)
    XCTAssertEqual(lines.first?["strokes_reason"] as? String, "HTTP 500")
    XCTAssertEqual(store.items().unreadable, [], "nor once the item is sent")

    try store.delete(try XCTUnwrap(store.item("m1")))
    XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("m1.strokes").path))
  }

  // Story 427.
  func testWithNoNetworkTheBoardWaitsWithItsStrokesAndBothGoLater() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = InboxStore(directory: dir)
    var draft = InboxDraft()
    draft.image = TestImages.png
    draft.whiteboard = WhiteboardPicture(board: "b1", title: "T", rect: frame, scale: 2, pictureID: "p1")
    draft.strokes = try JSONSerialization.data(
      withJSONObject: WhiteboardStrokes.wire([WhiteboardStrokes.Stroke(id: "s1", points: points)]))
    _ = try draft.save(to: store, at: 1, id: "m3")

    let offline = InboxSender(
      store: store, cockpit: "https://c.example", threads: freshThreads(), readyImage: TestImages.asTheyAre
    ) { _ in
      throw URLError(.notConnectedToInternet)
    }
    let away = await offline.sendWaiting { _, _ in }
    XCTAssertEqual(away.sent, [])
    let waiting = try XCTUnwrap(store.item("m3"))
    XCTAssertEqual(waiting.status, .waiting)
    XCTAssertNotNil(store.strokes(of: waiting), "the strokes are still beside the picture")

    let calls = Calls()
    let back = InboxSender(
      store: store, cockpit: "https://c.example", threads: freshThreads(), readyImage: TestImages.asTheyAre
    ) { request in
      let url = try XCTUnwrap(request.url)
      await calls.add(url.path, body: nil)
      let body = url.path == "/attachments" ? #"{"ok": true, "ref": "r1"}"# : #"{"ok": true, "thread": "t1"}"#
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      )
    }
    let report = await back.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, ["m3"])
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/whiteboard/strokes", "/chat"])
  }

  // Story 1176: a board's Send with no network waits; the network back, it goes once, its folds beside its strokes, and
  // a second try finds nothing waiting.
  func testABoardsSendWaitsOfflineAndGoesOnceWithItsFolds() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = InboxStore(directory: dir)
    var draft = InboxDraft()
    draft.image = TestImages.png
    draft.text = WhiteboardNote.boardTurnNote
    draft.whiteboard = WhiteboardPicture(board: "b1", title: "T", rect: frame, scale: 2, pictureID: "p9")
    draft.strokes = try WhiteboardStrokes.file(
      strokes: WhiteboardStrokes.wire([WhiteboardStrokes.Stroke(id: "s1", points: points)]),
      folds: [["header": "h1", "strokes": ["s2"]]])
    _ = try draft.save(to: store, at: 1, id: "p9")

    let offline = InboxSender(
      store: store, cockpit: "https://c.example", threads: freshThreads(), readyImage: TestImages.asTheyAre
    ) { _ in
      throw URLError(.notConnectedToInternet)
    }
    for _ in 0..<2 {
      let away = await offline.sendWaiting { _, _ in }
      XCTAssertEqual(away.sent, [])
    }
    XCTAssertEqual(store.item("p9")?.status, .waiting)

    let calls = Calls()
    let back = InboxSender(
      store: store, cockpit: "https://c.example", threads: freshThreads(), readyImage: TestImages.asTheyAre
    ) { request in
      let url = try XCTUnwrap(request.url)
      await calls.add(url.path, body: request.httpBody)
      let body = url.path == "/attachments" ? #"{"ok": true, "ref": "r1"}"# : #"{"ok": true, "thread": "t1"}"#
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      )
    }
    let report = await back.sendWaiting { _, _ in }
    XCTAssertEqual(report.sent, ["p9"])
    let again = await back.sendWaiting { _, _ in }
    XCTAssertEqual(again.sent, [], "it goes once")
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/whiteboard/strokes", "/chat"])
    XCTAssertEqual(store.item("p9")?.status, .sent)
    let bodies = await calls.bodies
    let sent = try XCTUnwrap(
      JSONSerialization.jsonObject(with: try XCTUnwrap(bodies["/whiteboard/strokes"])) as? [String: Any])
    XCTAssertEqual((sent["strokes"] as? [[String: Any]])?.first?["id"] as? String, "s1")
    XCTAssertEqual((sent["folds"] as? [[String: Any]])?.first?["header"] as? String, "h1")
    let message = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(bodies["/chat"])) as? [String: Any])
    XCTAssertEqual(message["id"] as? String, "p9", "the message is the picture's id")
  }

  func testAPictureWithoutStrokesSendsAsBefore() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = InboxStore(directory: dir)
    var draft = InboxDraft()
    draft.image = TestImages.png
    draft.whiteboard = WhiteboardPicture(board: "b1", title: "T", rect: frame, scale: 2, pictureID: "p1")
    let item = try draft.save(to: store, at: 1, id: "m2")
    XCTAssertNil(item.strokesFile)
    let calls = Calls()
    let sender = InboxSender(
      store: store, cockpit: "https://c.example", threads: freshThreads(), readyImage: TestImages.asTheyAre
    ) { request in
      let url = try XCTUnwrap(request.url)
      await calls.add(url.path, body: nil)
      let body = url.path == "/attachments" ? #"{"ok": true, "ref": "r1"}"# : #"{"ok": true, "thread": "t1"}"#
      return (
        Data(body.utf8),
        try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
      )
    }
    var lines: [[String: Any]] = []
    _ = await sender.sendWaiting { _, fields in lines.append(fields) }
    let paths = await calls.paths
    XCTAssertEqual(paths, ["/attachments", "/chat"])
    XCTAssertNil(lines.first?["strokes_ok"])
  }
}

/// The board-to-thread memory on its own defaults, so one test's board never lands on another's thread.
private func freshThreads() -> WhiteboardThreads {
  let suite = "whiteboard-strokes-\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defaults.removePersistentDomain(forName: suite)
  return WhiteboardThreads(defaults: defaults)
}

private actor Calls {
  var paths: [String] = []
  var bodies: [String: Data] = [:]

  func add(_ path: String, body: Data?) {
    paths.append(path)
    if let body { bodies[path] = body }
  }
}
