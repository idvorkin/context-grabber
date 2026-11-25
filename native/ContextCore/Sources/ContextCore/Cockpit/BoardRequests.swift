//  The board's HTTP requests to the Cockpit, kept out of BoardCore so the board's rules build for WebAssembly, whose
//  Foundation has no URLRequest (spec 2026-11-22-board-rules-on-the-web-design.md). Same types, same calls: these are
//  extensions, and ContextCore re-exports BoardCore, so callers are unchanged.

import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension BoardEventsSend {
  /// `build`: the app's `<sha> <branch>`, for the Cockpit's board debug page (story 1112).
  /// `appBuild`: the build number and short commit every post carries (story 1134).
  public static func request(
    board: String, report: BoardTurnReport, cockpit: String, build: String? = nil, appBuild: AppBuild = .current
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("events"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    var body = report.wire
    body["board"] = board
    if let build, !build.isEmpty { body["build"] = build }
    body = appBuild.stamp(body)
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
  }
}

extension BoardToText {
  /// `POST <cockpit>/ink/to-text` with `{name, png}`: the board's id and the picture, base64.
  public static func request(png: Data, board: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit), base.host != nil else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("ink").appendingPathComponent("to-text"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["name": board, "png": png.base64EncodedString()])
    return request
  }
}

extension WhiteboardQuestions {
  /// The open asks, the snoozed ones too: a snoozed ask's card is still open, as on the web board.
  public static func asksRequest(cockpit: String) throws -> URLRequest {
    guard URL(string: cockpit)?.host != nil else { throw URLError(.badURL) }
    return try ChatWire.get(cockpit, "/asks?snoozed=1")
  }

  /// The question and answer of closed asks, `GET /ink/answers?ids=a,b`.
  public static func answersRequest(_ ids: [String], cockpit: String) throws -> URLRequest {
    guard URL(string: cockpit)?.host != nil, !ids.isEmpty else { throw URLError(.badURL) }
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&=+,#")
    let list = ids.map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0 }.joined(separator: ",")
    return try ChatWire.get(cockpit, "/ink/answers?ids=" + list)
  }

  /// Story 1316 (#1387): Igor's words on the ask's own chat thread, `POST /chat` with `subject_id` the ask's id, as a
  /// board's chat post without a picture. `id` is the message's, so a resend lands once.
  public static func thinkRequest(ask: String, words: String, id: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit), base.host != nil, !ask.isEmpty else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("chat"))
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(InboxSend.origin(of: base), forHTTPHeaderField: "Origin")
    let body: [String: Any] = [
      "id": id, "text": words.trimmingCharacters(in: .whitespacesAndNewlines), "source": ChatSend.source,
      "subject_id": ask,
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    return request
  }

  /// Story 1317: the ask's own conversation, `GET /chat/<ask id>`.
  public static func talkRequest(ask: String, cockpit: String) throws -> URLRequest {
    guard URL(string: cockpit)?.host != nil, !ask.isEmpty else { throw URLError(.badURL) }
    return try ChatWire.threadRequest(ask, cockpit: cockpit)
  }
}

extension WhiteboardStrokes {
  /// `POST /whiteboard/strokes`: the board's strokes under this picture's id and frame.
  /// `folds`: the folded sections (`BoardOutline.wire`), whose strokes are not in `strokes` (story 857).
  public static func request(
    picture: WhiteboardPicture, strokes: [[String: Any]], folds: [[String: Any]] = [], cockpit: String
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("strokes"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    var body = picture.wire
    body["strokes"] = strokes
    if !folds.isEmpty { body["folds"] = folds }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }
}

extension WhiteboardResponder {
  public static func readRequest(board: String, cockpit: String) throws -> URLRequest {
    guard let base = URL(string: cockpit),
      var parts = URLComponents(
        url: base.appendingPathComponent("whiteboard").appendingPathComponent("responder"),
        resolvingAgainstBaseURL: false)
    else { throw URLError(.badURL) }
    parts.queryItems = [URLQueryItem(name: "board", value: board)]
    guard let url = parts.url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    return request
  }

  public static func writeRequest(
    _ responder: WhiteboardResponder, board: String, cockpit: String
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("responder"))
    request.httpMethod = "POST"
    request.timeoutInterval = timeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["board": board, "responder": responder.rawValue])
    return request
  }
}

extension WhiteboardTurn {
  /// Claude's ghosts: the picture and its size in pixels, which every stroke comes back in. `board` picks the board's
  /// responder on the Cockpit (story 659); `timings` are the iPad's half of the turn so far (story 661).
  public static func suggestRequest(
    title: String, picture: Data, width: Int, height: Int, cockpit: String, board: String? = nil,
    timings: [String: Int] = [:]
  ) throws -> URLRequest {
    guard let base = URL(string: cockpit) else { throw URLError(.badURL) }
    var request = URLRequest(url: base.appendingPathComponent("whiteboard").appendingPathComponent("suggest"))
    request.httpMethod = "POST"
    request.timeoutInterval = suggestTimeout
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // One stroke a line as the model makes it; a Cockpit that doesn't stream answers with one JSON (`WhiteboardStream`).
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
    request.setValue(CockpitPage.origin(of: base), forHTTPHeaderField: "Origin")
    var body: [String: Any] = [
      "image": picture.base64EncodedString(), "width": width, "height": height, "text": title,
      "client": "grabber-native",
    ]
    if let board { body["board"] = board }
    if !timings.isEmpty { body["timings"] = timings }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }
}
