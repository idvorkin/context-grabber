//  A whiteboard (spec 2026-11-01-whiteboard-design.md, stories 340–343, 347, 658): a column of pages on PaperKit with the
//  system tool picker, saved a moment after each stroke, and sent to Larry on the board's chat thread holding its picture
//  (the Inbox's image path, so it waits in the outbox when the network is away). A board another device draws, or one
//  drawn on the old canvas (gone 2026-11-07), opens to look at only. Claude's ghosts after a pause or spoken words and Larry's turn come back
//  as shapes, drawn faint until a tap keeps one (spec 2026-11-01-whiteboard-shapes-design.md, stories 344, 345, 349).

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

@MainActor
final class WhiteboardModel: ObservableObject {
  @Published private(set) var isEmpty: Bool
  /// What the last Send did, shown in the bar until the next stroke.
  @Published private(set) var sent: String?
  @Published private(set) var problem: BugProblem?
  /// The ghosts and the rules of Claude's turn: what shows, whose, for how long, and when Claude is asked (stories 344,
  /// 349, 351, 357, 358, 359, 367, 370). The host tests are `WhiteboardGhostTurnsTests`.
  @Published private(set) var turns: WhiteboardGhostTurns<Ghost> {
    didSet {
      if turns.ghosts.count != oldValue.ghosts.count {
        log.event(
          "whiteboard",
          [
            "action": "ghosts", "board": board.id, "count": turns.ghosts.count,
            "larry": turns.ghosts.filter { $0.who == .larry }.count,
          ])
      }
    }
  }
  /// Shapes Claude or Larry offered, faint on the board until a tap keeps one (stories 344, 349).
  var ghosts: [Ghost] { turns.ghosts }
  /// Story 344's switch, remembered across boards.
  var ghostsOn: Bool { turns.on }
  /// Story 407's switch, remembered per board on this device. Lines on the board, never in the drawing or a picture.
  @Published private(set) var gridOn: Bool
  /// On paper only: a board has a grid, ruled lines or neither.
  @Published private(set) var ruledOn: Bool
  /// The board's colour (story 378).
  @Published private(set) var paper: BoardPaper
  /// Who answers a pause: Haiku, Sonnet or Larry, the board's knob on the Cockpit (story 659).
  @Published private(set) var responder = WhiteboardResponderKnob()
  /// Larry's turn, one at a time, latest wins (story 662): while one is out the bar says he is looking.
  @Published private(set) var larry = WhiteboardLarryTurn()
  /// Bumped on every change of the ink: what a held pause remembers, and what a picture to Larry was of.
  private var boardVersion = 0
  /// The last turn in a line: Larry's words or ghosts not answering.
  var turnNote: String? { turns.note }
  /// The picture is on its way to Larry's thread.
  @Published private(set) var larrySending = false
  /// On paper: ink on the board, none of it on screen, so Send and Larry's turn have nothing to show him (story 522).
  @Published private(set) var nothingOnScreen = false
  /// Looking at Larry's thread has failed for a while (story 383).
  @Published private(set) var larryAway = false
  /// What the last paste left off or couldn't draw, shown until the board next changes (stories 392, 393).
  @Published private(set) var pasteNote: String?
  /// The board's mic (story 345): open, on its way up, finishing its last words, and the last words it heard.
  @Published private(set) var micOn = false
  @Published private(set) var micStarting = false
  @Published private(set) var micFinishing = false
  @Published private(set) var heardNote: String?
  let board: BoardEntry
  /// Drawn on here, or only looked at: a board from another device (story 347) or from the old canvas (story 658).
  let editable: Bool
  /// Drawn on the old canvas: its ink is moved onto pages to be shown, and it can't be sent (story 658).
  let oldCanvas: Bool
  /// Why it's only looked at, for the bar; nil on a board drawn on here.
  let lookOnlyNote: String?
  @Published private(set) var drawing: PKDrawing
  private let store: WhiteboardStore
  private let log: SessionLog
  private let inbox: InboxModel
  private let cockpit: String
  private let threads = WhiteboardThreads()
  /// What's on screen in board points, for a turn on an empty board or a paste, and the zoom; the canvas sets them.
  var visibleRect: (() -> CGRect)?
  var zoom: (() -> CGFloat)?
  /// Where a paste may land, in board points; a board on paper sets its own.
  var pasteReach = WhiteboardPaste.wholeBoard
  /// Puts a kept ghost or a paste on the canvas (undoably), given the whole drawing and what's new in it; the canvas sets
  /// it.
  var draw: ((PKDrawing, [PKStroke]) -> Void)?
  /// Something was chosen in the Board menu, the colour already chosen too; a board on paper sets it.
  var menuChose: (() -> Void)?
  private let callLive: @MainActor () -> Bool
  private lazy var dictation = makeDictation()
  private var dictationWatches: Set<AnyCancellable> = []
  private var speech = WhiteboardSpeech()
  private var silenceTask: Task<Void, Never>?
  private var pauseTask: Task<Void, Never>?
  private var fadeTask: Task<Void, Never>?
  private var saveTask: Task<Void, Never>?
  private var dirty = false
  private var saveFailing = false
  private var marks = WhiteboardMarks()
  /// On paper: each stroke's box, for what's on screen (story 433), and the frame the last Send showed.
  private var inkBoxes: [CGRect] = []
  private var sentFrame: CGRect?
  /// The row his showing marks came from.
  private var shownRow: String?
  private var watchTask: Task<Void, Never>?
  private var lookFailures = 0

  static let ghostsKey = "whiteboard_ghosts"
  /// A pasted letter's height on screen, in points, at 100% and zoomed out.
  static let pasteLetters: CGFloat = 24
  /// How long Claude's ghosts stay when nothing replaces them.
  static let ghostSeconds = LaunchHooks.current.whiteboard.ghostSeconds ?? 30
  /// How often an open board looks at its thread, how long one look waits, and how many failed looks before the bar
  /// says so.
  static let lookEvery: Duration = .seconds(3)
  static let lookTimeout: TimeInterval = 3
  static let awayAfter = 3

  init(
    board: BoardEntry, store: WhiteboardStore, log: SessionLog, inbox: InboxModel, cockpit: String,
    callLive: @escaping @MainActor () -> Bool
  ) {
    self.callLive = callLive
    self.board = board
    paper = board.paper
    self.store = store
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
    turns = WhiteboardGhostTurns(
      on: UserDefaults.standard.object(forKey: Self.ghostsKey) as? Bool ?? true, ghostLife: .seconds(Self.ghostSeconds))
    gridOn = UserDefaults.standard.bool(forKey: "whiteboard_grid_\(board.id)")
    ruledOn = UserDefaults.standard.bool(forKey: "whiteboard_ruled_\(board.id)")
    editable = store.drawable(board)
    oldCanvas = BoardIndex.drawnOnTheOldCanvas(board)
    lookOnlyNote = store.lookOnlyNote(board)
    var loaded = PKDrawing()
    do {
      loaded = try store.drawing(board.id)
    } catch {
      log.event("error", ["where": "whiteboard_load", "message": "\(error)", "board": board.id])
      problem = .grabber(
        "This board could not be read: \(error.localizedDescription)", context: "WhiteboardView.load",
        extra: ["board": .string(board.id)])
    }
    drawing = loaded
    isEmpty = loaded.strokes.isEmpty
    inkBoxes = loaded.strokes.map(\.renderBounds)
    log.event(
      "whiteboard",
      [
        "action": "open", "board": board.id, "strokes": loaded.strokes.count, "editable": editable,
        "old_canvas": oldCanvas,
      ])
    if LaunchHooks.current.whiteboard.grid { setGrid(true) }
  }

  func changed(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    let added = new.strokes.count > drawing.strokes.count
    logStrokesMoved(to: new)
    drawing = new
    if added, turns.stroked() { startPause() }
    drawingMoved()
  }

  /// Kept ink as the canvas reads it back. Nothing to ask about or save that the keep hasn't already started.
  func settled(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    inkMoved()
  }

  /// A kept mark undone or redone on paper: saved like any change, and not a stroke for Claude to answer.
  func stepped(_ new: PKDrawing) {
    guard editable, new != drawing else { return }
    drawing = new
    drawingMoved()
  }

  /// #624: a board's ink below a line moved on its own, splitting a kept label. Names the next one.
  private func logStrokesMoved(to new: PKDrawing) {
    guard
      let moved = WhiteboardFrame.strokesMoved(
        before: drawing.strokes.map(\.renderBounds), after: new.strokes.map(\.renderBounds))
    else { return }
    log.event(
      "whiteboard",
      [
        "action": "ink_moved", "board": board.id, "strokes": new.strokes.count, "moved": moved.count,
        "dx": Double(moved.dx), "dy": Double(moved.dy), "top_moved_y": Double(moved.topY), "zoom": Double(zoom?() ?? 1),
      ])
  }

  private func drawingMoved() {
    boardVersion += 1
    isEmpty = drawing.strokes.isEmpty
    sent = nil
    sentFrame = nil
    inkMoved()
    pasteNote = nil
    dirty = true
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.save()
    }
  }

  /// The ink changed: what's on screen may have too.
  private func inkMoved() {
    inkBoxes = drawing.strokes.map(\.renderBounds)
    screenMoved()
  }

  /// On paper, the view moved or the ink changed (story 433): what Send and Larry's turn would show. A Send already made is
  /// of the pages it showed, so another page on screen can be sent too.
  func screenMoved() {
    let frame = pictureFrame()?.rect
    let nothing = !drawing.strokes.isEmpty && frame == nil
    if nothing != nothingOnScreen { nothingOnScreen = nothing }
    if let sentFrame, sentFrame != frame {
      self.sentFrame = nil
      sent = nil
    }
  }

  /// Larry's picture, for Send and his turn: the pages on screen (story 433). Claude's own turns frame theirs as they
  /// always have.
  private func pictureFrame() -> (rect: CGRect, scale: CGFloat)? {
    BoardPages().picture(visible: visibleRect?() ?? .null, ink: inkBoxes)
  }

  /// The Pencil touching down: the ghosts stay, and a pause under way starts over when it lifts.
  func beganDrawing() {
    turns.toolWentDown()
    pauseTask?.cancel()
    pauseTask = nil
  }

  func endedDrawing() {
    if turns.toolLifted() { startPause() }
  }

  /// A pause still waiting is forgotten; `turns` has made an answer on its way stale.
  private func cancelPause() {
    pauseTask?.cancel()
    pauseTask = nil
  }

  private func startPause() {
    pauseTask?.cancel()
    let started = ContinuousClock.now
    pauseTask = Task { [weak self] in
      try? await Task.sleep(for: WhiteboardPacer.pause)
      guard !Task.isCancelled, let self else { return }
      self.pauseTask = nil
      // Story 661: how long the pause really waited, the timer's own lateness included.
      if self.turns.pauseEnded() { await self.turn(.claude, paused: started.duration(to: .now)) }
    }
  }

  func setGhosts(_ on: Bool) {
    UserDefaults.standard.set(on, forKey: Self.ghostsKey)
    log.event("whiteboard", ["action": on ? "ghosts_on" : "ghosts_off", "board": board.id])
    turns.setOn(on)
    if !on {
      cancelPause()
      larry.dropped()
    }
  }

  func setRuled(_ on: Bool) {
    ruledOn = on
    UserDefaults.standard.set(on, forKey: "whiteboard_ruled_\(board.id)")
    log.event("whiteboard", ["action": on ? "ruled_on" : "ruled_off", "board": board.id])
    if on, gridOn { setGrid(false) }
  }

  func setGrid(_ on: Bool) {
    gridOn = on
    UserDefaults.standard.set(on, forKey: "whiteboard_grid_\(board.id)")
    log.event("whiteboard", ["action": on ? "grid_on" : "grid_off", "board": board.id])
    if on, ruledOn { setRuled(false) }
  }

  func setPaper(_ new: BoardPaper) {
    guard editable, new != paper else { return }
    paper = new
    store.setPaper(new, board: board.id)
    log.event("whiteboard", ["action": "paper", "board": board.id, "paper": new.rawValue])
  }

  /// Story 380: the picture goes to the board's thread and Igor keeps drawing; Larry's marks come when they come. It
  /// goes now, whatever a Larry board was holding for his answer, and takes the words that waited (story 662).
  func larryTurn() {
    guard !larrySending else { return }
    let words = larry.tapped(version: boardVersion, now: .now)
    Task { await handToLarry(said: words) }
  }

  /// The turn `larry` has already counted as out: `said`, words spoken to a Larry board, go as the picture's message
  /// (story 659). `from`: the button, a pause on a Larry board, or the picture that follows his answer or a timeout
  /// (story 662). One that doesn't reach him frees the turn and keeps its words for the next.
  private func handToLarry(said: String? = nil, from: String = "button") async {
    guard editable, let (rect, scale) = pictureFrame() else {
      larry.failed(words: said)
      return
    }
    larrySending = true
    defer { larrySending = false }
    // ponytail: rendered and encoded on the main thread, as the ghost turn is.
    let jpeg = picture(rect: rect, scale: scale).jpegData(compressionQuality: 0.85) ?? Data()
    let strokes = WhiteboardStrokes.wire(strokesForLarry())
    let thread = threads.thread(board: board.id)
    let picture = WhiteboardPicture(
      board: board.id, title: store.index.board(board.id)?.title ?? board.title, rect: rect, scale: scale)
    let started = Date()
    var event: [String: Any] = [
      "who": "larry", "board": board.id, "bytes": jpeg.count, "picture": picture.pictureID, "new_thread": thread == nil,
      "pixels": "\(Int(rect.width * scale))x\(Int(rect.height * scale))", "from": from, "said_chars": said?.count ?? 0,
    ]
    defer {
      event["ms"] = Int(Date().timeIntervalSince(started) * 1000)
      log.event("whiteboard_turn", event)
    }
    // Story 419: the strokes first, under this picture's id; the picture goes whatever they answered.
    event.merge(WhiteboardStrokes.logFields(await sendStrokes(strokes, picture: picture))) { $1 }
    let outcome = await deliver(jpeg, picture: picture, thread: thread, note: said ?? "Your turn on the board")
    switch outcome {
    case .sent(let key, _):
      event["ok"] = true
      event["thread"] = key
      threads.set(key, board: board.id)
      turns.larryReached()
      if problem?.context == "WhiteboardView.larry" { problem = nil }
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
      larry.failed(words: said)
      // A thread the Cockpit no longer has: the next turn starts a new one.
      if status == 404, let thread { threads.forget(thread, board: board.id) }
      failed(
        .larry, "The Cockpit refused the turn (\(status)): \(reason)", status: status,
        first: turns.failed(.larry, stale: false))
    case .retry(let reason):
      event["ok"] = false
      event["reason"] = reason
      larry.failed(words: said)
      failed(.larry, "Larry couldn't be reached: \(reason)", status: nil, first: turns.failed(.larry, stale: false))
    }
  }

  /// Story 419: the board's strokes to the Cockpit under the picture's id. Never a reason not to send the picture.
  private func sendStrokes(_ strokes: [[String: Any]], picture: WhiteboardPicture) async -> WhiteboardStrokes.Answer {
    do {
      let request = try WhiteboardStrokes.request(picture: picture, strokes: strokes, cockpit: cockpit)
      let (body, response) = try await URLSession.shared.data(for: request)
      return WhiteboardStrokes.answer(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      return WhiteboardStrokes.answer(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  /// Story 419: the drawing as the Cockpit's strokes, in board points: each PencilKit spline sampled every few points
  /// (the stroke's transform applied), the ink's colour as it looks in light mode (black, not white), the width as
  /// the mean of the stroke's own point sizes (the transform's scale applied), and an id that is the same for the same
  /// ink on every send. Story 423: only the ink still visible goes, one stroke per visible stretch, so a pixel eraser's rub changes the ids.
  private func strokesForLarry() -> [WhiteboardStrokes.Stroke] { Self.strokesForLarry(drawing) }

  static func strokesForLarry(_ drawing: PKDrawing) -> [WhiteboardStrokes.Stroke] {
    let light = UITraitCollection(userInterfaceStyle: .light)
    return drawing.strokes.flatMap { stroke -> [WhiteboardStrokes.Stroke] in
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      if !stroke.ink.color.resolvedColor(with: light).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        (red, green, blue) = (0, 0, 0)
      }
      let color = WhiteboardStrokes.hex(red: red, green: green, blue: blue)
      let width = WhiteboardStrokes.width(sizes: stroke.path.map(\.size.width), transform: stroke.transform)
      let t = Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
      let tool = WhiteboardStrokes.tool(rawValue: stroke.ink.inkType.rawValue)
      return stroke.maskedPathRanges.map { range in
        var points = stroke.path.interpolatedPoints(in: range, by: .distance(WhiteboardStrokes.spacing)).map {
          $0.location.applying(stroke.transform)
        }
        if points.isEmpty {
          points = [stroke.path.interpolatedPoint(at: range.lowerBound).location.applying(stroke.transform)]
        }
        return WhiteboardStrokes.Stroke(
          id: WhiteboardStrokes.id(points: points, color: color, t: t), t: t, color: color, width: width, tool: tool,
          points: points)
      }
    }
  }

  /// The picture uploaded, then the message that names it.
  private func deliver(
    _ jpeg: Data, picture: WhiteboardPicture, thread: String?, note: String
  ) async -> ChatSend.Outcome {
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try ChatSend.uploadRequest(image: jpeg, cockpit: cockpit))
      switch ChatSend.upload(status: (response as? HTTPURLResponse)?.statusCode, body: body) {
      case .refused(let status, let reason): return .refused(status: status, reason: reason)
      case .retry(let reason): return .retry(reason: "image upload: \(reason)")
      case .ref(let ref):
        let item = InboxItem(
          kind: .image, sharedAt: Int64(Date().timeIntervalSince1970 * 1000), note: note,
          thread: thread, whiteboard: picture)
        let (body, response) = try await URLSession.shared.data(
          for: try ChatSend.messageRequest(item, attachment: ref, cockpit: cockpit))
        return ChatSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: body)
      }
    } catch {
      return .retry(reason: error.localizedDescription)
    }
  }

  /// The board appearing or the app coming back: looks at its thread, once it has one, until `stopWatchingLarry`.
  /// Story 382.
  func startWatchingLarry() {
    guard editable, watchTask == nil else { return }
    watchTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.lookAtThread()
        self?.larryTimedOut()
        try? await Task.sleep(for: Self.lookEvery)
      }
    }
  }

  private func stopWatchingLarry() {
    watchTask?.cancel()
    watchTask = nil
  }

  private func lookAtThread() async {
    guard let thread = threads.thread(board: board.id) else { return }
    let reason: String
    do {
      var request = try ChatWire.threadRequest(thread, cockpit: cockpit)
      request.timeoutInterval = Self.lookTimeout
      let (body, response) = try await URLSession.shared.data(for: request)
      if Task.isCancelled { return }
      let status = (response as? HTTPURLResponse)?.statusCode
      if status == 200, let rows = WhiteboardMarks.rows(body) {
        lookWorked(rows)
        return
      }
      if status == 404 {
        threadGone(thread)
        return
      }
      reason = "HTTP \(status ?? 0)"
    } catch {
      if Task.isCancelled { return }
      reason = error.localizedDescription
    }
    // Once in the log, and quietly in the bar: never a loop of errors.
    if lookFailures == 0 {
      log.event("error", ["where": "whiteboard_marks", "board": board.id, "thread": thread, "message": reason])
    }
    lookFailures += 1
    if lookFailures >= Self.awayAfter { larryAway = true }
  }

  /// The Cockpit answered and no longer has the thread: the next picture starts a new one.
  private func threadGone(_ thread: String) {
    threads.forget(thread, board: board.id)
    lookFailures = 0
    larryAway = false
    log.event("whiteboard_marks", ["action": "thread_gone", "board": board.id, "thread": thread])
  }

  private func lookWorked(_ rows: [WhiteboardMarks.Row]) {
    if lookFailures > 0 { log.event("whiteboard_marks", ["action": "back", "board": board.id, "after": lookFailures]) }
    lookFailures = 0
    larryAway = false
    let update = marks.take(rows, settled: UserDefaults.standard.string(forKey: settledKey))
    for row in update.unplaced {
      log.event("whiteboard_marks", ["action": "unplaced", "board": board.id, "row": row])
    }
    turns.larrySaid(update.say, marks: update.marks != nil)
    // A row landing while a picture is still going up answers an earlier one: the turn on its way stays out.
    if update.replied, !larrySending { larryFollowUp(larry.replied(version: boardVersion, now: .now), why: "reply") }
    guard let row = update.marks, let frame = row.frame else { return }
    // Each author's new marks replace only their own, placed by the row's own frame: where that picture was.
    shownRow = row.id
    turns.larrysMarks(row.shapes.map { Ghost($0, who: .larry, frame: frame, scale: row.scale) })
    log.event(
      "whiteboard_marks",
      [
        "action": "shown", "board": board.id, "row": row.id, "shapes": row.shapes.count,
        "picture": row.pictureID ?? "",
      ])
  }

  /// Story 662: his turn has been out too long; the board stops waiting, as if he had answered.
  private func larryTimedOut() {
    guard let next = larry.tick(version: boardVersion, now: .now) else { return }
    larryFollowUp(next, why: "timeout")
  }

  /// His answer came, or the wait ran out: one fresh picture if the board moved on or words waited, else nothing.
  private func larryFollowUp(_ next: WhiteboardLarryTurn.Next, why: String) {
    var event: [String: Any] = ["action": "larry_turn_over", "board": board.id, "why": why]
    switch next {
    case .send(let words):
      event["next"] = "send"
      event["said_chars"] = words?.count ?? 0
      log.event("whiteboard", event)
      Task { await handToLarry(said: words, from: why) }
    case .held, .done:
      event["next"] = "none"
      log.event("whiteboard", event)
    }
  }

  /// Igor kept or dismissed from his row: it doesn't come back when the board opens again.
  private func settleLarrysRow() {
    if let shownRow { UserDefaults.standard.set(shownRow, forKey: settledKey) }
  }

  private var settledKey: String { "whiteboard_marks_settled_\(board.id)" }

  private func makeDictation() -> NoteDictation {
    let dictation = NoteDictation(
      logger: log.bugLogger, hostMicrophoneBusy: { [weak self] in self?.callLive() ?? false })
    dictation.$listening.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micOn = on }
    }
    .store(in: &dictationWatches)
    dictation.$starting.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micStarting = on }
    }
    .store(in: &dictationWatches)
    dictation.$processing.removeDuplicates().sink { [weak self] on in
      MainActor.assumeIsolated { self?.micFinishing = on }
    }
    .store(in: &dictationWatches)
    dictation.$problem.combineLatest(dictation.$problemState).sink { [weak self] message, state in
      MainActor.assumeIsolated {
        guard let self, let message else { return }
        self.micProblem(message, state)
      }
    }
    .store(in: &dictationWatches)
    return dictation
  }

  private func micProblem(_ message: String, _ state: [String: JSONValue]) {
    let extra = state.merging(["board": .string(board.id), "call_live": .bool(callLive())]) { _, new in new }
    problem = .grabber(message, context: "WhiteboardView.mic", extra: extra)
  }

  /// Opens the board's mic, or closes it and sends what's still unsent.
  func tapMic() {
    if let words = LaunchHooks.current.whiteboard.say {
      speech.heard(words)
      spoke()
      return
    }
    if micOn {
      stopMic(why: "tap")
      return
    }
    guard !dictation.busy else { return }
    guard !callLive() else {
      log.event("whiteboard", ["action": "mic_refused", "board": board.id, "why": "call_live"])
      micProblem("A call with Larry is using the microphone. End it to talk to the board.", [:])
      return
    }
    if problem?.context == "WhiteboardView.mic" { problem = nil }
    speech = WhiteboardSpeech()
    heardNote = nil
    log.event("whiteboard", ["action": "mic_on", "board": board.id])
    dictation.toggle(note: "") { [weak self] text in self?.heard(text) }
  }

  /// A call taking the microphone, the board closing or the app leaving: the mic stops, and its last words still go.
  func stopMic(why: String) {
    guard micOn || micStarting else { return }
    silenceTask?.cancel()
    log.event("whiteboard", ["action": "mic_off", "board": board.id, "why": why])
    Task {
      await dictation.finish(why: why)
      spoke()
    }
  }

  private func heard(_ text: String) {
    speech.heard(text)
    heardNote = String(text.suffix(80))
    silenceTask?.cancel()
    silenceTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.spoke()
    }
  }

  /// He stopped talking: the new words go now, or with the next turn if one is on its way. With Ghosts off nothing is
  /// asked, and they aren't kept for later.
  private func spoke() {
    guard let words = speech.takeNew() else { return }
    let went = turns.spoke(words)
    log.event("whiteboard", ["action": "spoke", "board": board.id, "chars": words.count, "went": went.rawValue])
    guard went == .now else { return }
    // This turn's picture has the strokes a waiting pause would ask about.
    cancelPause()
    Task { await turn(.claude) }
  }

  /// One turn: the board's picture to the Cockpit, shapes back as ghosts, or, on a board whose responder is Larry, the
  /// picture on to his thread (story 659). `paused`: how long the pause that asked it waited; nil for spoken words.
  func turn(_ who: WhiteboardTurn.Who, paused: Duration? = nil) async {
    let said = turns.said(who)
    // An empty board has no drawing to frame: a spoken turn sees the part on screen, and any other isn't asked.
    let framed =
      WhiteboardGhostTurns<Ghost>.framesScreen(said: said, boardEmpty: drawing.strokes.isEmpty)
      ? visibleRect?() ?? .null : drawing.bounds
    guard editable, let (rect, scale) = WhiteboardFrame.export(framed) else { return }
    let asked = turns.asked(who)
    defer { if turns.turnOver(who) { startPause() } }
    // ponytail: rendered and encoded on the main thread; if a big board hitches the next stroke (the turn event's
    // `bytes`), this moves to a background task.
    // Story 661: the iPad's half of the turn, measured around the picture and its send.
    var timings = WhiteboardTimings(pause: paused)
    let rendering = ContinuousClock.now
    let image = picture(rect: rect, scale: scale)
    let encoding = ContinuousClock.now
    timings.render = rendering.duration(to: encoding)
    let png = image.pngData() ?? Data()
    timings.encode = encoding.duration(to: .now)
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
        self.land([shape], who: .claude, rect: rect, scale: scale, first: first)
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
      firstSendWaiting: firstSendWaiting(in: inbox.items))
    // Story 662: one turn of Larry's out at a time. While one is, the pause is held for his answer, with its words.
    var toLarry: String??
    switch handOff {
    case .nothing: break
    case .skipped(let why): event["larry"] = why
    case .hand:
      switch larry.paused(version: boardVersion, words: said, now: .now) {
      case .send(let words):
        event["larry"] = "hand"
        toLarry = .some(words)
      case .held, .done:
        event["larry"] = "held"
      }
    }
    log.event("whiteboard_turn", event)
    // The turn holds the next pause until the picture has gone.
    if case .some(let words) = toLarry { await handToLarry(said: words, from: "responder") }
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
    let deadline = Task {
      try? await Task.sleep(for: .seconds(WhiteboardTurn.suggestTimeout))
      if !Task.isCancelled { reading.cancel() }
    }
    defer { deadline.cancel() }
    return await reading.value
  }

  /// Marks landing on the board: an answer's first replaces its author's earlier ones, and only those.
  private func land(
    _ shapes: [WhiteboardTurn.Shape], who: WhiteboardTurn.Who, rect: CGRect, scale: CGFloat, first: Bool
  ) {
    turns.land(
      shapes.map { Ghost($0, who: who, frame: rect, scale: scale) }, who: who, first: first, now: .now)
    if who == .claude { fadeClaudesGhosts() }
    if first, LaunchHooks.current.whiteboard.keepFirst, let ghost = ghosts.first {
      keep(ghost)
    }
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
  private func failed(_ who: WhiteboardTurn.Who, _ message: String, status: Int?, first: Bool) {
    if first {
      log.event("error", ["where": "whiteboard_turn", "who": who.rawValue, "message": message, "board": board.id])
    }
    guard who == .larry else { return }
    var extra: [String: JSONValue] = ["board": .string(board.id), "cockpit": .string(cockpit)]
    if let status { extra["status"] = .int(status) }
    problem = .grabber(message, context: "WhiteboardView.larry", extra: extra)
  }

  /// A tap at `point` (board points) keeps the ghost under it; a tap anywhere else dismisses the ghosts.
  func tap(at point: CGPoint, zoom: CGFloat) {
    switch turns.tap(hitting: { WhiteboardTurn.hit($0.lines, at: point, tolerance: 22 / zoom) }) {
    case .nothing: return
    case .keep(let ghost): keep(ghost)
    case .dismiss(let count, let larrys):
      log.event("whiteboard", ["action": "ghosts_dismissed", "board": board.id, "count": count])
      turns.dismiss()
      cancelPause()
      if larrys { settleLarrysRow() }
    }
  }

  /// The ghost as ink in its colour. Its point spacing is what makes PencilKit's spline follow the shape.
  private func keep(_ ghost: Ghost) {
    let strokes = Self.strokes(ghost.lines, color: ghost.color, width: ghost.width, spacing: 4)
    if turns.keep(ghost) { settleLarrysRow() }
    log.event("whiteboard", ["action": "keep", "board": board.id, "who": ghost.who.rawValue, "strokes": strokes.count])
    add(strokes)
  }

  private static func strokes(_ lines: [[CGPoint]], color: UIColor, width: CGFloat, spacing: CGFloat) -> [PKStroke] {
    let ink = PKInk(.pen, color: color)
    return lines.map { line in
      PKStroke(
        ink: ink,
        path: PKStrokePath(
          controlPoints: WhiteboardTurn.inkPoints(line, spacing: spacing).enumerated().map { i, p in
            PKStrokePoint(
              location: p, timeOffset: Double(i) * 0.01, size: CGSize(width: width, height: width), opacity: 1,
              force: 1, azimuth: 0, altitude: .pi / 2)
          }, creationDate: Date()))
    }
  }

  private func add(_ strokes: [PKStroke]) {
    var kept = drawing
    kept.strokes += strokes
    drawing = kept
    drawingMoved()
    draw?(kept, strokes)
  }

  /// Stories 390, 391: the text as ink in the middle of the view, one undo, and a change like a drawn stroke. Black ink
  /// shows light in dark mode, as the Pencil's does, and dark in the picture. The pen's width is in proportion to the
  /// letters: a ghost's 3.7 fills a 24-point letter in, and PencilKit draws nothing under about 2 (seen on the
  /// simulator, on the canvas and in the picture alike), which is why zooming in never shrinks them on the board.
  func paste(_ text: String) {
    guard editable, let visible = visibleRect?(), !visible.isNull, let zoom = zoom?() else { return }
    let height = Self.pasteLetters / min(zoom, 1)
    let layout = WhiteboardPaste.layout(text, visible: visible, height: height, board: pasteReach)
    let strokes = Self.strokes(layout.lines, color: .black, width: height * 0.11, spacing: height / 8)
    log.event(
      "whiteboard",
      [
        "action": "paste", "board": board.id, "characters": layout.kept, "of": layout.total, "strokes": strokes.count,
      ])
    guard !strokes.isEmpty else {
      pasteNote = layout.note
      return
    }
    add(strokes)
    if turns.stroked() { startPause() }
    if let note = layout.note { pasteNote = note }
  }

  /// Copied strokes the canvas didn't place itself: one undo, and a change like a drawn stroke, as a paste of text is.
  func paste(strokes: [PKStroke]) {
    guard editable, !strokes.isEmpty else { return }
    log.event("whiteboard", ["action": "paste_strokes", "board": board.id, "strokes": strokes.count])
    add(strokes)
    if turns.stroked() { startPause() }
  }

  /// Dark ink on white whatever the iPad's mode and the board's colour: what Larry and Claude see.
  private func picture(rect: CGRect, scale: CGFloat) -> UIImage {
    var ink = UIImage()
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent { ink = drawing.image(from: rect, scale: scale) }
    let format = UIGraphicsImageRendererFormat()
    format.scale = ink.scale
    format.opaque = true
    return UIGraphicsImageRenderer(size: ink.size, format: format).image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(origin: .zero, size: ink.size))
      ink.draw(at: .zero)
    }
  }

  /// The app going to the background: what is drawn is written now. The board stays open, so an empty new one is
  /// kept.
  func flush() {
    stopWatchingLarry()
    saveTask?.cancel()
    if editable, dirty { save() }
  }

  /// On screen: a delete from another device waits for `close`, which comes after the last save.
  func opened() {
    guard editable else { return }
    store.opened(board.id)
    Task { await readResponder() }
  }

  /// Story 659: which responder the board has, asked as it opens. Until the Cockpit answers, or when it can't, Sonnet
  /// stays ticked: the log says so, the bar doesn't.
  private func readResponder() async {
    let asked = responder.generation
    let reply: WhiteboardResponder.Reply
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try WhiteboardResponder.readRequest(board: board.id, cockpit: cockpit))
      reply = WhiteboardResponder.reply(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      reply = WhiteboardResponder.reply(status: nil, body: nil, error: error.localizedDescription)
    }
    var event: [String: Any] = ["action": "responder_read", "board": board.id]
    switch reply {
    case .responder(let answered):
      responder.heard(answered, asked: asked)
      event["ok"] = true
      event["responder"] = answered.rawValue
    case .failed(let reason, let status):
      event["ok"] = false
      event["reason"] = reason
      if let status { event["status"] = status }
    }
    event["ticked"] = responder.shown.rawValue
    log.event("whiteboard", event)
  }

  /// Story 659: Igor picked who answers the board's pauses. It shows at once and goes to the Cockpit; a write that
  /// fails takes the tick back and says why.
  func setResponder(_ new: WhiteboardResponder) {
    guard editable, let choice = responder.chose(new) else { return }
    log.event("whiteboard", ["action": "responder", "board": board.id, "responder": new.rawValue])
    Task { await writeResponder(new, choice: choice) }
  }

  private func writeResponder(_ new: WhiteboardResponder, choice: Int) async {
    let reply: WhiteboardResponder.Reply
    do {
      let (body, response) = try await URLSession.shared.data(
        for: try WhiteboardResponder.writeRequest(new, board: board.id, cockpit: cockpit))
      reply = WhiteboardResponder.reply(status: (response as? HTTPURLResponse)?.statusCode, body: body)
    } catch {
      reply = WhiteboardResponder.reply(status: nil, body: nil, error: error.localizedDescription)
    }
    switch reply {
    case .responder(let answered):
      responder.wrote(answered, choice: choice)
      if problem?.context == "WhiteboardView.responder" { problem = nil }
    case .failed(let reason, let status):
      responder.wrote(nil, choice: choice)
      log.event(
        "error",
        ["where": "whiteboard_responder", "board": board.id, "responder": new.rawValue, "message": reason])
      var extra: [String: JSONValue] = [
        "board": .string(board.id), "responder": .string(new.rawValue), "ticked": .string(responder.shown.rawValue),
        "cockpit": .string(cockpit),
      ]
      if let status { extra["status"] = .int(status) }
      problem = .grabber(
        "The board couldn't be given to \(new.name): \(reason)", context: "WhiteboardView.responder", extra: extra)
    }
  }

  /// Leaving the board, by Back or by a link that takes it down: what is drawn is written now, not a second later,
  /// and goes up to iCloud. Safe to call twice.
  func close() {
    stopWatchingLarry()
    saveTask?.cancel()
    guard editable else { return }
    if dirty {
      save()
      log.event(
        "whiteboard", ["action": "close", "board": board.id, "strokes": drawing.strokes.count, "saved": !dirty])
      if dirty, let problem { store.closedUnsaved(problem, board: board.id) }
    }
    store.closed(board.id, empty: drawing.strokes.isEmpty)
  }

  // ponytail: serialised on the main thread; a board big enough to stutter here moves it to a background task.
  private func save() {
    guard dirty else { return }
    do {
      try store.save(drawing, board: board.id)
      dirty = false
      saveFailing = false
      if problem?.context == "WhiteboardView.save" { problem = nil }
    } catch {
      if !saveFailing {
        log.event("error", ["where": "whiteboard_save", "message": "\(error)", "strokes": drawing.strokes.count])
      }
      saveFailing = true
      problem = .grabber(
        "The board could not be saved: \(error.localizedDescription)", context: "WhiteboardView.save",
        extra: ["strokes": .int(drawing.strokes.count)])
    }
  }

  /// The board's first Send is still in the outbox: a turn now would start a second thread.
  func firstSendWaiting(in items: [InboxItem]) -> Bool {
    threads.firstSendWaiting(board: board.id, in: items)
  }

  /// Story 343: the whole drawing (on paper, the pages on screen: story 433), dark ink on white whatever the iPad's mode,
  /// on the board's thread with Larry, titled with the board's name; the first one starts it (story 381).
  func send() {
    guard sent == nil, !larrySending, let (rect, scale) = pictureFrame() else { return }
    let ink = picture(rect: rect, scale: scale)
    let jpeg = ink.jpegData(compressionQuality: 0.85) ?? Data()
    var draft = InboxDraft()
    draft.image = jpeg
    let title = store.index.board(board.id)?.title ?? board.title
    // Story 662: a Send is Larry's turn too, out now whatever was held; words that waited go with it.
    let words = larry.tapped(version: boardVersion, now: .now)
    draft.text = words.map { "\(title): \($0)" } ?? title
    draft.whiteboard = WhiteboardPicture(board: board.id, title: title, rect: rect, scale: scale)
    // Story 424: the strokes wait beside the picture and go first when it goes.
    draft.strokes = try? JSONSerialization.data(withJSONObject: WhiteboardStrokes.wire(strokesForLarry()))
    do {
      try inbox.add(&draft, thread: threads.thread(board: board.id))
      if problem?.context == "WhiteboardView.send" { problem = nil }
      sent = "Sent to Larry: his reply shows in Chat"
      sentFrame = rect
      log.event(
        "whiteboard",
        [
          "action": "send", "board": board.id, "strokes": drawing.strokes.count, "bytes": jpeg.count,
          "pixels": "\(Int(ink.size.width * ink.scale))x\(Int(ink.size.height * ink.scale))",
          "frame": [Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)],
        ])
    } catch {
      larry.failed(words: words)
      log.event("error", ["where": "whiteboard_send", "message": "\(error)", "bytes": jpeg.count])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["bytes": .int(jpeg.count)])
    }
  }
}

/// A shape Claude or Larry offered, in board points, not yet kept.
struct Ghost: Identifiable, WhiteboardGhost {
  let id: String
  let who: WhiteboardTurn.Who
  let lines: [[CGPoint]]
  /// The colour and pen it asked for, or its author's colour and the default pen (#698).
  let color: UIColor
  let width: CGFloat

  init(_ shape: WhiteboardTurn.Shape, who: WhiteboardTurn.Who, frame: CGRect, scale: CGFloat) {
    id = UUID().uuidString
    self.who = who
    lines = WhiteboardTurn.lines(shape, frame: frame, scale: scale)
    color = shape.color.map { UIColor(rgb: $0) } ?? who.color
    width = WhiteboardTurn.width(shape, scale: scale)
  }
}

/// How long a ghost turn's request took to go up (story 661): from the send to its body's last byte, the connection's
/// setup included. URLSession tells a task's own delegate as the body goes; the last word is the last byte.
final class UploadClock: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var started: ContinuousClock.Instant?
  private var sent: ContinuousClock.Instant?

  func start() {
    lock.withLock {
      started = .now
      sent = nil
    }
  }

  /// Nil until the body has gone, or when URLSession never said.
  var span: Duration? {
    lock.withLock {
      guard let started, let sent else { return nil }
      return started.duration(to: sent)
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    lock.withLock { sent = .now }
  }
}

/// The ghosts on screen, in board points: one shape layer a ghost, the ink it would become, faint, in its colour. Whoever
/// holds `holder` scales it to sit on the drawing. Never part of the drawing, and in no picture.
@MainActor
final class GhostLayers {
  let holder = CALayer()
  private var shown: [String: CAShapeLayer] = [:]

  init() {
    holder.anchorPoint = .zero
    holder.frame = .zero
  }

  /// True when the ghosts on show changed.
  @discardableResult
  func show(_ ghosts: [Ghost]) -> Bool {
    guard Set(ghosts.map(\.id)) != Set(shown.keys) else { return false }
    let live = Set(ghosts.map(\.id))
    for (id, gone) in shown where !live.contains(id) {
      shown[id] = nil
      CATransaction.begin()
      CATransaction.setCompletionBlock { gone.removeFromSuperlayer() }
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = gone.presentation()?.opacity ?? 1
      fade.toValue = 0
      fade.duration = 0.3
      gone.opacity = 0
      gone.add(fade, forKey: "fade")
      CATransaction.commit()
    }
    let arriving = ghosts.filter { shown[$0.id] == nil }
    for (i, ghost) in arriving.enumerated() {
      let path = CGMutablePath()
      for line in ghost.lines { path.addLines(between: line) }
      let shape = CAShapeLayer()
      shape.path = path
      shape.fillColor = nil
      shape.strokeColor = ghost.color.withAlphaComponent(0.5).cgColor
      shape.lineWidth = ghost.width
      shape.lineCap = .round
      shape.lineJoin = .round
      // Drawn in one after another, like someone sketching beside him.
      let drawIn = CABasicAnimation(keyPath: "strokeEnd")
      drawIn.fromValue = 0
      drawIn.toValue = 1
      drawIn.duration = 0.25
      drawIn.beginTime = CACurrentMediaTime() + 0.25 * Double(i)
      drawIn.fillMode = .backwards
      shape.add(drawIn, forKey: "drawIn")
      holder.addSublayer(shape)
      shown[ghost.id] = shape
    }
    return true
  }
}

extension WhiteboardTurn.Who {
  /// Claude orange, Larry blue (spec 2026-11-01-whiteboard-shapes-design.md).
  var color: UIColor { self == .claude ? .systemOrange : .systemBlue }
}

extension UIColor {
  convenience init(rgb: UInt32) {
    self.init(
      red: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255,
      alpha: 1)
  }
}

extension BoardPaper {
  /// Follows the view's mode, as the ink does. Plain is the system's own, as every board was before colours.
  var color: UIColor {
    guard self != .plain else { return .systemBackground }
    let light = UIColor(rgb: light)
    let dark = UIColor(rgb: dark)
    return UIColor { $0.userInterfaceStyle == .dark ? dark : light }
  }
}

/// One board, pushed from the list: drawn on here, or looked at when another device draws it.
struct WhiteboardView: View {
  @StateObject private var model: WhiteboardModel
  @ObservedObject private var inbox: InboxModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let logger: BugLogger
  private let log: SessionLog
  private let callLive: AnyPublisher<Bool, Never>
  private let reportOpen: AnyPublisher<Bool, Never>

  init(board: BoardEntry, store: WhiteboardStore, app: AppModel) {
    _model = StateObject(
      wrappedValue: WhiteboardModel(
        board: board, store: store, log: app.log, inbox: app.inbox, cockpit: app.chat.cockpit,
        callLive: { [weak app] in app?.call.snapshot.isActive ?? false }))
    inbox = app.inbox
    callLive = app.call.$snapshot.map(\.isActive).removeDuplicates().eraseToAnyPublisher()
    reportOpen = app.reporter.$flow.map(\.isPresented).removeDuplicates().eraseToAnyPublisher()
    logger = app.bugLogger
    log = app.log
  }

  var body: some View {
    VStack(spacing: 0) {
      if let note {
        Text(note).font(.footnote).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.8)
          .padding(.vertical, 4).padding(.horizontal)
      }
      if let problem = model.problem {
        BugProblemView(problem: problem, logger: logger).padding(.horizontal)
      }
      Group {
        PaperBoardCanvas(model: model, log: log)
      }
      .ignoresSafeArea(edges: .bottom)
    }
    .navigationTitle(model.board.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if model.editable {
        // The board's own settings, in one menu. Six items in an iPhone's top bar push Larry's turn and Send under *More*,
        // so at that width this one goes to the bottom (story 402).
        ToolbarItem(placement: horizontalSizeClass == .compact ? .bottomBar : .topBarTrailing) {
          Menu {
            Section("Colour") {
              ForEach(BoardPaper.allCases, id: \.self) { paper in
                Toggle(
                  paper.name,
                  isOn: Binding(
                    get: { model.paper == paper },
                    set: { _ in
                      model.setPaper(paper)
                      model.menuChose?()
                    }))
              }
            }
            Section("Lines") {
              Toggle(
                "Grid lines",
                isOn: Binding(
                  get: { model.gridOn },
                  set: {
                    model.setGrid($0)
                    model.menuChose?()
                  }))
              Toggle(
                "Ruled lines",
                isOn: Binding(
                  get: { model.ruledOn },
                  set: {
                    model.setRuled($0)
                    model.menuChose?()
                  }))
            }
            // Story 659: who answers a pause, the board's own on the Cockpit.
            Section("Responder") {
              ForEach(WhiteboardResponder.allCases, id: \.self) { responder in
                Toggle(
                  responder.name,
                  isOn: Binding(
                    get: { model.responder.shown == responder },
                    set: { _ in
                      model.setResponder(responder)
                      model.menuChose?()
                    }))
              }
            }
          } label: {
            Label("Board", systemImage: "paintpalette")
          }
          // Its colour and lines, for VoiceOver and the UI test, in the label for the reason below.
          .accessibilityLabel(
            "Board, \(model.paper.name)\(model.gridOn ? ", grid on" : model.ruledOn ? ", ruled lines on" : "")"
          )
          .accessibilityIdentifier("whiteboard-board")
        }
      }
      if model.editable {
        ToolbarItem(placement: .topBarTrailing) {
          // The system's button: no *Allow Paste?* prompt, and iOS dims it when the clipboard holds no text.
          PasteButton(payloadType: String.self) { texts in
            Task { @MainActor in model.paste(texts.joined(separator: "\n")) }
          }
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("whiteboard-paste")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.tapMic()
          } label: {
            Label(model.micOn ? "Stop listening" : "Talk to Claude", systemImage: model.micOn ? "mic.fill" : "mic")
          }
          .disabled(model.micStarting || model.micFinishing)
          .tint(model.micOn ? .red : nil)
          .accessibilityIdentifier("whiteboard-mic")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.setGhosts(!model.ghostsOn)
          } label: {
            Label(model.ghostsOn ? "Ghosts on" : "Ghosts off", systemImage: model.ghostsOn ? "sparkles" : "eye.slash")
          }
          // How many show, for VoiceOver and the UI test (the board's own content is not in the accessibility tree,
          // and a toolbar button's accessibility value never reaches it).
          .accessibilityLabel(
            (model.ghostsOn ? "Ghosts on" : "Ghosts off")
              + (model.ghosts.isEmpty ? "" : ", \(model.ghosts.count) showing")
          )
          .accessibilityIdentifier("whiteboard-ghosts")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.larryTurn()
          } label: {
            Label("Larry's turn", systemImage: "hand.draw")
          }
          .disabled(
            model.isEmpty || model.nothingOnScreen || model.larrySending || model.firstSendWaiting(in: inbox.items)
          )
          .accessibilityIdentifier("whiteboard-larry")
        }
      }
      // An old-canvas board's ink sits where the column put it, not where it's saved: nothing to frame for Larry (story 658).
      if !model.oldCanvas {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            model.send()
          } label: {
            Label("Send to Larry", systemImage: "paperplane")
          }
          // How much is drawn, for VoiceOver and the UI test, in the label for the reason above.
          .accessibilityLabel("Send to Larry, \(model.drawing.strokes.count) strokes")
          .disabled(model.isEmpty || model.nothingOnScreen || model.sent != nil || model.larrySending)
          .accessibilityIdentifier("whiteboard-send")
        }
      }
    }
    .accessibilityIdentifier("whiteboard")
    .task {
      // XCUITest's taps never reach the system's paste button: the UI test pastes through this.
      guard let text = LaunchHooks.current.whiteboard.paste else { return }
      try? await Task.sleep(for: .seconds(1))
      model.paste(text)
    }
    .onAppear {
      model.opened()
      model.startWatchingLarry()
    }
    .onDisappear {
      model.stopMic(why: "closed")
      model.close()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        model.flush()
        model.stopMic(why: "background")
      }
      if phase == .active { model.startWatchingLarry() }
    }
    .onReceive(callLive) { live in if live { model.stopMic(why: "call") } }
    .onReceive(reportOpen) { open in if open { model.stopMic(why: "report") } }
  }

  private var note: String? {
    let count = model.ghosts.count
    let parts = [
      model.turnNote,
      model.larry.looking ? WhiteboardLarryTurn.lookingNote : nil,
      model.pasteNote,
      model.larryAway ? "Larry's marks: the Cockpit isn't answering" : nil,
      model.micOn ? model.heardNote.map { "Heard: \($0)" } ?? "Listening…" : nil,
      count == 0 ? nil : "\(count) suggestion\(count == 1 ? "" : "s"): tap one to keep it",
      model.sent ?? model.lookOnlyNote,
    ].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}
