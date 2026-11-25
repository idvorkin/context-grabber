//  Claude's ghost turn: asking, streaming, landing and fading Claude's ghosts.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// One turn: the board's picture to the Cockpit, shapes back as ghosts, or, on a board whose responder is Larry, the
  /// picture on to his thread (story 659). `paused`: how long the pause that asked it waited; nil for spoken words.
  func turn(_ who: WhiteboardTurn.Who, paused: Duration? = nil) async {
    // Story 1281: every word the open mic heard so far goes with this picture.
    if who == .claude { gatherSpoken(why: paused == nil ? "turn" : "pause") }
    let said = turns.said(who)
    // An empty board has no drawing to frame: a spoken turn sees the part on screen, and any other isn't asked.
    let framed =
      WhiteboardGhostTurns<Ghost>.framesScreen(said: said, boardEmpty: drawing.strokes.isEmpty)
      ? canvas?.visibleRect ?? .null : labelBoxes().reduce(drawing.bounds) { $0.union($1) }
    guard editable, let (rect, scale) = WhiteboardFrame.export(framed) else { return }
    let asked = turns.asked(who)
    defer { if turns.turnOver(who) { startPause() } }
    // ponytail: rendered and encoded on the main thread; if a big board hitches the next stroke (the turn event's
    // `bytes`), this moves to a background task.
    // Story 661: the iPad's half of the turn, measured around the picture and its send.
    var timings = WhiteboardTimings(pause: paused)
    let rendering = ContinuousClock.now
    let shot = shot(rect: rect, scale: scale)
    let image = shot.image
    let encoding = ContinuousClock.now
    timings.render = rendering.duration(to: encoding)
    let png = image.pngData() ?? Data()
    timings.encode = encoding.duration(to: .now)
    // Story 1112: spoken words this picture carries are sent now; their timing waits among the events for Larry.
    if said != nil { micTimingsGo() }
    let started = Date()
    let answer: WhiteboardTurn.Answer
    var read = WhiteboardStream.Read()
    let knobAsked = responder.generation
    let upload = UploadClock()
    do {
      let title = store.index.board(board.id)?.title ?? board.title
      let request = try WhiteboardTurn.suggestRequest(
        title: WhiteboardSpeech.context(title: title, said: said), picture: png, width: image.cgImage?.width ?? 0,
        height: image.cgImage?.height ?? 0,
        cockpit: cockpit, board: board.id, timings: timings.wire)
      read = await readClaude(request, started: started, upload: upload) { [weak self] shape, first in
        guard let self, self.turns.current(asked) else { return }
        self.land([shape], who: .claude, rect: shot.rect, scale: shot.scale, folds: shot.folds, first: first)
      }
      answer = read.answer
    } catch {
      answer = WhiteboardTurn.answer(status: nil, body: nil, error: error.localizedDescription)
    }
    timings.upload = upload.span
    let landing = turns.answered(answer, who: who, asked: asked, streamed: read.streamed, said: said)
    let ms = Int(Date().timeIntervalSince(started) * 1000)
    var event: [String: Any] = [
      "who": who.rawValue, "board": board.id, "ms": ms, "stale": landing.stale, "bytes": png.count,
      "streamed": read.streamed, "said_chars": said?.count ?? 0,
    ]
    event.merge(timings.logFields) { $1 }
    if let answered = read.responder {
      event["responder"] = answered.rawValue
      responder.heard(answered, asked: knobAsked)
    }
    if let broken = read.broken { event["broken"] = broken }
    if landing.cancelled { event["cancelled"] = "pen_down" }
    switch answer {
    case .shapes(let shapes):
      event["ok"] = true
      event["shapes"] = shapes.count
      if !shapes.isEmpty { event["first_shape_ms"] = read.firstShapeMs ?? ms }
    case .tooSoon:
      event["ok"] = false
      event["reason"] = "too_soon"
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
    case .away(let reason):
      event["ok"] = false
      event["reason"] = reason
    }
    // Streamed marks are on the board already; a stream with none clears Claude's, as an empty answer does.
    if let shapes = landing.land { land(shapes, who: who, rect: rect, scale: scale, first: true) }
    if let failure = landing.failure {
      failed(who, failure, status: landing.status, first: landing.firstFailure)
    }
    let handOff = WhiteboardResponder.handOff(
      answered: read.responder, answer: answer, stale: landing.stale,
      firstSendWaiting: firstSendWaiting(in: inbox.items), turnHolds: larry.waitingToSend)
    // Story 662: one turn of Larry's out at a time. While one is, the pause is held for his answer, with its words.
    var toLarry: String??
    switch handOff {
    case .nothing: break
    case .skipped(let why): event["larry"] = why
    case .hand:
      switch larry.paused(version: ops.rev, words: said, now: .now) {
      case .send(let words):
        event["larry"] = "hand"
        toLarry = .some(words)
      case .held, .done:
        event["larry"] = "held"
      }
    }
    log.event("whiteboard_turn", event)
    turnsLogged += 1
    // The turn holds the next pause until the picture has gone.
    if case .some(let words) = toLarry { await handToLarry(larry.state, said: words, from: "responder") }
  }

  /// Reads Claude's answer as it comes, telling `landed` each mark and whether it is the answer's first. The 10 s are
  /// for the whole answer: URLRequest's own timeout starts over with every byte.
  private func readClaude(
    _ request: URLRequest, started: Date, upload: UploadClock, landed: @escaping (WhiteboardTurn.Shape, Bool) -> Void
  ) async -> WhiteboardStream.Read {
    let reading = Task { () -> WhiteboardStream.Read in
      var reading = WhiteboardStream.Reading()
      let elapsedMs = { Int(Date().timeIntervalSince(started) * 1000) }
      var failure: String?
      do {
        upload.start()
        let (bytes, response) = try await URLSession.shared.bytes(for: request, delegate: upload)
        reading.opened(status: (response as? HTTPURLResponse)?.statusCode, contentType: response.mimeType)
        for try await byte in bytes {
          if let mark = reading.take(byte, elapsedMs: elapsedMs) { landed(mark.shape, mark.first) }
          if reading.done { break }
        }
        if let mark = reading.finish(elapsedMs: elapsedMs) { landed(mark.shape, mark.first) }
      } catch {
        failure = WhiteboardStream.Reading.failure(error, cancelled: Task.isCancelled)
      }
      return reading.read(failure: failure)
    }
    claudeReading = reading
    let deadline = Task {
      try? await Task.sleep(for: .seconds(WhiteboardTurn.suggestTimeout))
      if !Task.isCancelled { reading.cancel() }
    }
    defer { deadline.cancel() }
    return await reading.value
  }

  /// Marks landing on the board: an answer's first replaces its author's earlier ones, and only those.
  private func land(
    _ shapes: [WhiteboardTurn.Shape], who: WhiteboardTurn.Who, rect: CGRect, scale: CGFloat,
    folds: BoardFoldMap? = nil, first: Bool
  ) {
    turns.land(
      shapes.map {
        Ghost($0, who: who, frame: rect, scale: scale, hand: penInHand, folds: folds, lettering: lettering)
      }, who: who, first: first, now: .now)
    if who == .claude { fadeClaudesGhosts() }
  }

  private func fadeClaudesGhosts() {
    guard let at = turns.fadeAt else { return }
    fadeTask?.cancel()
    fadeTask = Task { [weak self] in
      try? await Task.sleep(until: at, clock: .continuous)
      guard !Task.isCancelled, let self else { return }
      self.turns.fade(now: .now)
    }
  }

  /// `turns` has already said so in the note; logged once a run, and Larry's as a copyable problem.
  /// `autoFile` false keeps a blink's problem from filing (story 1136); `extra` goes on the report.
  func failed(
    _ who: WhiteboardTurn.Who, _ message: String, status: Int?, first: Bool, autoFile: Bool = true,
    extra more: [String: JSONValue] = [:]
  ) {
    if first {
      log.event("error", ["where": "whiteboard_turn", "who": who.rawValue, "message": message, "board": board.id])
    }
    guard who == .larry else { return }
    var extra: [String: JSONValue] = ["board": .string(board.id), "cockpit": .string(cockpit)]
    if let status { extra["status"] = .int(status) }
    extra.merge(more) { $1 }
    problem = .grabber(message, context: "WhiteboardView.larry", extra: extra, autoFile: autoFile)
  }
}
