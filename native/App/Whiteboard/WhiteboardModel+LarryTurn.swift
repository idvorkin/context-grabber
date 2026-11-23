//  Larry's turn (stories 344, 773, 768 and the rest of the hand-off): handing him the board, shipping the log and the
//  strokes, watching his thread, his marks, the waits and timeouts, Retry, Dismiss and Interrupt.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// Story 773: where the picture Larry is looking at is, from its mark on the thread the board last read (with the
  /// Cockpit not answering, the last it knew) and whether its sending was answered. The one reading the note's state
  /// and the 20-second controls share. A picture the board handed over itself is found by its id; a *Send to Larry*'s
  /// by Igor's newest message since it went.
  func larryMark(now: ContinuousClock.Instant) -> WhiteboardLarryWait.Mark {
    let out = larryOut.flatMap { $0.turn == larry.state ? $0 : nil }
    return WhiteboardLarryWait.mark(
      larry, thread: thread, now: now, wallNow: Date(), picture: out?.picture.pictureID,
      delivered: out?.delivered ?? false, earlier: out?.receipt ?? .sent)
  }

  /// The board's one thread with Larry (story 1158): this device's own on the board it drew, else the one the board
  /// carries through iCloud, as the store has it now (a sync since the board opened may have brought it, #1161).
  var threadKey: String? {
    threads.board(board.id, carried: carriedThread, drawnHere: store.editable(board))
  }

  /// The thread the board's iCloud copy carries (#1161).
  var carriedThread: String? { store.index.board(board.id)?.thread ?? board.thread }

  /// Story 1127 (#1138): a link chip in the open conversation was tapped; the kind and the board, never the link.
  func logLinkOpened(_ link: ChatLink) {
    log.event(
      "chat",
      [
        "action": "link_opened", "from": "board", "board": board.id, "thread": threadKey ?? "",
        "kind": link.kind.logName,
      ])
  }

  /// Story 768: a tap on the note's line opens or closes the panel over the board, remembered for the next board; an
  /// iPhone has no panel, so it opens the board's thread in Chat, found among the chats when another device sent the
  /// board (story 1110, #1163), or says where the conversation is when none is found (story 769, #1161).
  func tapNote(onPhone: Bool, openChat: @escaping (String) -> Void) {
    let icloud = carriedThread
    let tap = WhiteboardNote.tap(onPhone: onPhone, thread: threadKey, icloud: icloud)
    switch tap {
    case .toggle:
      conversationOpen.toggle()
      UserDefaults.standard.set(conversationOpen, forKey: Self.conversationKey)
      log.event(
        "whiteboard",
        ["action": "conversation", "board": board.id, "open": conversationOpen, "messages": thread.count])
    case .openChat(let key, _):
      log.event(
        "whiteboard", ["action": "conversation_chat", "board": board.id, "thread": key, "found": tap.found ?? ""])
      openChat(key)
    case .nothing:
      log.event(
        "whiteboard", ["action": "conversation_chat", "board": board.id, "thread": "", "found": tap.found ?? ""])
      let title = store.index.board(board.id)?.title ?? board.title
      let drawnOn = store.editable(board) ? nil : board.deviceName
      Task { [weak self, board = self.board, cockpit = self.cockpit, log = self.log] in
        let answer = await BoardThreadLookup.find(
          board: board.id, title: title, icloud: icloud, drawnHere: drawnOn == nil, cockpit: cockpit, log: log,
          from: "note")
        switch answer {
        case .thread(let key): openChat(key)
        case .problem(let problem):
          // Cleared first, so a second tap with the same words takes the middle again for its few seconds.
          self?.pasteNote = nil
          // No chat is the board's: say where the conversation is (#1161); a Cockpit out of reach says why.
          self?.say(
            problem.message == BoardThreadFind.noneMessage ? WhiteboardNote.noThread(drawnOn: drawnOn) : problem.message
          )
        case .busy: break
        }
      }
    }
  }

  /// Story 765: a tap that sent nothing, because Larry is looking at this part of the board as it is and no words wait.
  /// The note says *Larry already has this* for two seconds (`WhiteboardLarryClock`).
  func alreadyHas(from: String) {
    var event: [String: Any] = ["action": "larry_already_has", "board": board.id, "from": from]
    if case .awaiting(let since, _) = larry.state {
      event["looking_s"] = Int((ContinuousClock.now - since).components.seconds)
    }
    log.event("whiteboard", event)
  }

  /// The turn `larry` has already counted as out: `said`, words spoken to a Larry board, go as the picture's message
  /// (story 659). `from`: the button, a pause on a Larry board, or the picture that follows his answer or a timeout
  /// (story 662). One that doesn't reach him frees the turn and keeps its words for the next.
  /// `again`: *Retry* (story 775), the very picture that went before, under the same message id.
  func handToLarry(
    _ turn: WhiteboardLarryTurn.State, said: String?, from: String = "button", again: LarryOut? = nil
  ) async {
    // Story 1112: spoken words waiting go among this picture's events (a Retry's already went with it).
    if again == nil { micTimingsGo() }
    guard editable, let out = again ?? larryPicture(said: said) else {
      larry.failed(turn, words: said)
      return
    }
    let attempt = larryHandOffs.begin()
    larryOut = out
    larryOut?.turn = turn
    larryOut?.attempt = attempt
    larrySending = true
    defer { if larryHandOffs.isLatest(attempt) { larrySending = false } }
    let (jpeg, strokes, picture, rect, scale) = (out.jpeg, out.strokes, out.picture, out.rect, out.scale)
    let folds = out.folds
    let thread = threadKey
    let started = Date()
    var event: [String: Any] = [
      "who": "larry", "board": board.id, "bytes": jpeg.count, "picture": picture.pictureID, "new_thread": thread == nil,
      "pixels": "\(Int(rect.width * scale))x\(Int(rect.height * scale))", "from": from, "said_chars": said?.count ?? 0,
      "rev": picture.report?.rev ?? -1, "events": picture.report?.events.count ?? 0,
      "op_result": picture.report?.opResult?.label ?? "",
    ]
    // Bead context-grabber-27sv: what a long stretch between turns let go, and of which kinds.
    if let report = picture.report, report.eventsDropped > 0 {
      event["events_dropped"] = report.eventsDropped
      event["dropped_kinds"] = report.droppedKinds ?? [:]
    }
    defer {
      event["ms"] = Int(Date().timeIntervalSince(started) * 1000)
      log.event("whiteboard_turn", event)
      turnsLogged += 1
    }
    // Story 419: the strokes first, under this picture's id; the picture goes whatever they answered.
    let strokesStarted = ContinuousClock.now
    event.merge(WhiteboardStrokes.logFields(await sendStrokes(strokes, folds: folds, picture: picture))) { $1 }
    // Story 1112: the iPad's half of the send, among the picture's events for the Cockpit's debug page.
    var post = BoardPostTiming(
      t: 0, build: Self.buildLine, from: from, renderMs: out.renderMs, encodeMs: out.encodeMs,
      strokesMs: WhiteboardTimings.ms(strokesStarted.duration(to: .now)), bytes: jpeg.count)
    if !folds.isEmpty { event["folds"] = folds.count }
    let outcome = await deliver(
      jpeg, picture: picture, thread: thread, note: said ?? WhiteboardNote.boardTurnNote, attempt: attempt,
      post: &post, facts: &event)
    for (name, ms) in [
      ("render_ms", post.renderMs), ("encode_ms", post.encodeMs), ("strokes_ms", post.strokesMs),
      ("upload_ms", post.uploadMs),
    ] {
      if let ms { event[name] = ms }
    }
    shipLog(why: "larry_turn")
    switch outcome {
    case .sent(let key, _):
      event["ok"] = true
      event["thread"] = key
      // A reply that lands before the first look at a new thread is still his answer.
      if thread == nil { marks.threadStarted() }
      threads.set(key, board: board.id)
      // #1161: a new thread goes up with the board, so the iPhone can open it, without waiting for the board to close.
      if thread != key { Task { [store] in await store.sync(reason: "thread") } }
      // The Cockpit has the picture (story 775): it isn't stuck. Kept apart from the marks the thread shows, so a
      // Cockpit that marks nothing never reads *Sent* (story 773).
      if larryOut?.picture.pictureID == picture.pictureID { larryOut?.delivered = true }
      turns.larryReached()
      if problem?.context == "WhiteboardView.larry" { problem = nil }
    case .refused(let status, let reason):
      event["ok"] = false
      event["status"] = status
      event["reason"] = reason
      // A thread the Cockpit no longer has: the next turn starts a new one.
      // context-grabber-e3vb: and the board's iCloud copy stops carrying it, now, so the iPhone never opens it.
      if status == 404, let thread, threads.forget(thread, board: board.id) {
        event["thread_forgotten"] = true
        Task { [store] in await store.sync(reason: "thread_gone") }
      }
      // Retry, Dismiss or Interrupt took this one over (stories 775–777): its words went with the retry or back in the
      // queue.
      guard larryHandOffs.speaks(attempt) else {
        event["superseded"] = true
        return
      }
      larry.failed(turn, words: said)
      failed(
        .larry, "The Cockpit refused the turn (\(status)): \(reason)", status: status,
        first: turns.failed(.larry, stale: false))
    case .retry(let reason):
      event["ok"] = false
      event["reason"] = reason
      // Retry, Dismiss or Interrupt took over while this one hung (stories 775–777): its failure is no longer the board's. One a
      // newer picture replaced still keeps its words, and its turn is freed only if it is still the one out.
      guard larryHandOffs.speaks(attempt) else {
        event["superseded"] = true
        return
      }
      larry.failed(turn, words: said)
      failed(.larry, "Larry couldn't be reached: \(reason)", status: nil, first: turns.failed(.larry, stale: false))
    }
  }

  /// #883: the whiteboard's log lines since the last the archive took, to the Cockpit's archive (`whiteboard.log`), each
  /// time a picture goes to Larry, so he reads what the board did without Igor pulling the log. One try; lines not
  /// taken go with the next picture. Nothing goes from a simulator or a Mac without GRABBER_ARCHIVE_URL.
  func shipLog(why: String) {
    let lines = log.whiteboardUnsent()
    guard let last = lines.last else { return }
    var event: [String: Any] = ["why": why, "board": board.id, "records": lines.count, "launch": log.launch]
    guard let archive = ArchiveModel.destination(ProcessInfo.processInfo.environment) else {
      event["ok"] = false
      event["reason"] = "no archive URL"
      log.event("whiteboard_log", event)
      return
    }
    let device = UIDevice.current.identifierForVendor?.uuidString.lowercased() ?? "unknown-device"
    let batch = ArchiveBatch(
      stream: WhiteboardLogArchive.stream, deviceId: device,
      records: WhiteboardLogArchive.records(
        lines, launch: log.launch,
        build: [
          "app": BuildInfo.version, "sha": BuildInfo.sha, "branch": BuildInfo.branch,
          "system": UIDevice.current.systemVersion, "device": UIDevice.current.model,
        ]))
    let log = log
    Task { [event] in
      var event = event
      let outcome: ArchiveSend.Outcome
      do {
        let (body, response) = try await URLSession.shared.data(for: try ArchiveSend.request(batch, cockpit: archive))
        outcome = ArchiveSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: body)
      } catch {
        outcome = .retry(reason: error.localizedDescription)
      }
      switch outcome {
      case .taken(let inserted, let duplicate):
        log.whiteboardSent(through: last.seq)
        event["ok"] = true
        event["inserted"] = inserted
        event["duplicate"] = duplicate
      case .refused(let status, let reason):
        event["ok"] = false
        event["status"] = status
        event["reason"] = reason
      case .retry(let reason):
        event["ok"] = false
        event["reason"] = reason
      }
      log.event("whiteboard_log", event)
    }
  }

  /// Story 419: the board's strokes to the Cockpit under the picture's id. Never a reason not to send the picture.
  private func sendStrokes(_ strokes: [[String: Any]], folds: [[String: Any]] = [], picture: WhiteboardPicture) async
    -> WhiteboardStrokes.Answer
  {
    do {
      let request = try WhiteboardStrokes.request(picture: picture, strokes: strokes, folds: folds, cockpit: cockpit)
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
  /// By the names Larry knows them: a stroke Larry's changes moved keeps the one it had.
  /// Story 857: what is folded goes under its header in `folds`, never as strokes, so it is neither erased nor new.
  func strokesForLarry() -> [WhiteboardStrokes.Stroke] {
    let all = strokeIDs.named(Self.strokesForLarry(drawing))
    guard headers.contains(where: { $0.fold != nil }) else { return all }
    let folded = outline().foldedNames
    return all.filter { !folded.contains($0.id) }
  }

  /// The folds as Larry gets them with the strokes.
  private func foldsForLarry() -> [[String: Any]] {
    headers.contains { $0.fold != nil } ? outline().wire : []
  }

  static func strokesForLarry(_ drawing: PKDrawing) -> [WhiteboardStrokes.Stroke] {
    drawing.strokes.flatMap { stroke -> [WhiteboardStrokes.Stroke] in
      let color = lightHex(stroke.ink.color)
      let width = WhiteboardStrokes.width(sizes: stroke.path.map(\.size.width), transform: stroke.transform)
      let t = Int64(stroke.path.creationDate.timeIntervalSince1970 * 1000)
      // #1083 (story 1063): never `ink.inkType`, which traps on a kind of ink PencilKit's Swift enum doesn't name.
      let tool = WhiteboardStrokes.tool(
        rawValue: WhiteboardInk.name(stroke.ink, at: "strokes", points: stroke.path.count) ?? "pen")
      return stroke.maskedPathRanges.map { range in
        var points = stroke.path.interpolatedPoints(in: range, by: .distance(WhiteboardStrokes.spacing)).map {
          $0.location.applying(stroke.transform)
        }
        if points.isEmpty {
          points = [stroke.path.interpolatedPoint(at: range.lowerBound).location.applying(stroke.transform)]
        }
        // Story 847: Larry's fold leaves the ink on the board with no colour to see.
        return WhiteboardStrokes.Stroke(
          id: WhiteboardStrokes.id(points: points, color: color, t: t), t: t, color: color, width: width, tool: tool,
          points: points, hidden: stroke.ink.color.cgColor.alpha == 0)
      }
    }
  }

  /// The picture uploaded, then the message that names it. #1136 (stories 908, 909): a connection lost under either is sent
  /// once more by itself, once the app is back on screen and if the hand-off still speaks for the board; `facts` gets
  /// what became of it, and the app's state when it was lost and when it went again.
  /// `post`: the send's timing (story 1112), finished here as the message leaves and added to its events.
  private func deliver(
    _ jpeg: Data, picture: WhiteboardPicture, thread: String?, note: String, attempt: Int,
    post: inout BoardPostTiming, facts: inout [String: Any]
  ) async -> ChatSend.Outcome {
    var lost: WhiteboardLostConnection.Record?
    var states: [String: Any] = [:]
    defer {
      if let lost { facts.merge(lost.logFields) { $1 } }
      facts.merge(states) { $1 }
    }
    let again: (WhiteboardLostConnection.Record) async -> Bool = { [weak self] _ in
      states["lost_app"] = Self.appState()
      let back = await Self.appBack()
      states["retry_app"] = Self.appState()
      return back && self?.larryHandOffs.speaks(attempt) == true
    }
    do {
      let uploading = ContinuousClock.now
      let (body, response) = try await WhiteboardLostConnection.run("upload", record: &lost, again: again) {
        try await URLSession.shared.data(for: try ChatSend.uploadRequest(image: jpeg, cockpit: self.cockpit))
      }
      switch ChatSend.upload(status: (response as? HTTPURLResponse)?.statusCode, body: body) {
      case .refused(let status, let reason): return .refused(status: status, reason: reason)
      case .retry(let reason): return .retry(reason: "image upload: \(reason)")
      case .ref(let ref):
        post.uploadMs = WhiteboardTimings.ms(uploading.duration(to: .now))
        post.t = Self.unixMs()
        // A copy: *Retry* sends the kept picture, and stamps its own send, never this one's.
        var sending = picture
        sending.build = Self.buildLine
        sending.report?.events.append(.post(post))
        // The message's id is the picture's, so *Retry* sending it again is the same message to the Cockpit (story 775).
        let item = InboxItem(
          id: picture.pictureID, kind: .image, sharedAt: post.t, note: note, thread: thread, whiteboard: sending)
        let (body, response) = try await WhiteboardLostConnection.run("message", record: &lost, again: again) {
          try await URLSession.shared.data(
            for: try ChatSend.messageRequest(item, attachment: ref, cockpit: self.cockpit))
        }
        return ChatSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: body)
      }
    } catch {
      return .retry(reason: error.localizedDescription)
    }
  }

  /// #1136: the app's state, for the lost connection's log fields.
  private static func appState() -> String {
    switch UIApplication.shared.applicationState {
    case .active: "active"
    case .inactive: "inactive"
    case .background: "background"
    @unknown default: "unknown"
    }
  }

  /// #1136: waits up to five seconds for the app to be back on screen, where the lost connection's second try goes.
  private static func appBack() async -> Bool {
    for _ in 0..<50 {
      if UIApplication.shared.applicationState == .active { return true }
      try? await Task.sleep(for: .milliseconds(100))
    }
    return UIApplication.shared.applicationState == .active
  }

  /// The board appearing or the app coming back: looks at its thread, once it has one, until `stopWatchingLarry`.
  /// Story 382.
  func startWatchingLarry() {
    guard editable, watchTask == nil else { return }
    Task { [questions] in await questions.sync(reason: "open") }
    watchTask = Task { [weak self] in
      while !Task.isCancelled {
        self?.reconcileSend()
        await self?.lookAtThread()
        self?.larryTimedOut()
        self?.checkLarryWait()
        try? await Task.sleep(for: Self.lookEvery)
      }
    }
  }

  func stopWatchingLarry() {
    watchTask?.cancel()
    watchTask = nil
  }

  private func lookAtThread() async {
    guard let thread = threadKey else {
      restoreLarrysMarks()
      return
    }
    let reason: String
    do {
      var request = try ChatWire.threadRequest(thread, cockpit: cockpit)
      request.timeoutInterval = Self.lookTimeout
      let (body, response) = try await URLSession.shared.data(for: request)
      guard !Task.isCancelled, threadKey == thread else { return }
      let status = (response as? HTTPURLResponse)?.statusCode
      if status == 200, let rows = WhiteboardMarks.rows(body) {
        let messages = ChatWire.messages(body) ?? []
        if let out = larryOut, let mark = WhiteboardLarryWait.receipt(of: out.picture.pictureID, in: messages) {
          larryOut?.receipt = out.receipt.atLeast(mark)
        }
        let recent = Array(messages.suffix(WhiteboardNote.panelMessages))
        if recent != self.thread { self.thread = recent }
        lookWorked(rows)
        questions.looked(body)
        larryClosed(messages)
        heardLarryHold(messages)
        return
      }
      if status == 404 {
        threadGone(thread)
        restoreLarrysMarks()
        return
      }
      reason = "HTTP \(status ?? 0)"
    } catch {
      guard !Task.isCancelled, threadKey == thread else { return }
      reason = error.localizedDescription
    }
    restoreLarrysMarks()
    // Once in the log, and quietly in the bar: never a loop of errors.
    if lookFailures == 0 {
      log.event("error", ["where": "whiteboard_marks", "board": board.id, "thread": thread, "message": reason])
    }
    lookFailures += 1
    if lookFailures >= Self.awayAfter { larryAway = true }
  }

  /// The Cockpit answered and no longer has the thread: the next picture starts a new one.
  private func threadGone(_ thread: String) {
    larryListeningChanged(nil, why: "thread_gone")
    if threads.forget(thread, board: board.id) {
      Task { [store] in await store.sync(reason: "thread_gone") }
    }
    self.thread = []
    lookFailures = 0
    larryAway = false
    log.event("whiteboard_marks", ["action": "thread_gone", "board": board.id, "thread": thread])
  }

  private func lookWorked(_ rows: [WhiteboardMarks.Row]) {
    if lookFailures > 0 { log.event("whiteboard_marks", ["action": "back", "board": board.id, "after": lookFailures]) }
    lookFailures = 0
    larryAway = false
    var history = marksHistory
    if let newest = rows.last(where: \.drawable)?.id, newest != history.newest {
      history.newest = newest
      marksHistory = history
    }
    let update = marks.take(rows, settled: Set(history.done), showing: history.showing.map(\.id))
    for row in update.unplaced {
      log.event("whiteboard_marks", ["action": "unplaced", "board": board.id, "row": row])
    }
    turns.larrySaid(update.say, marks: !update.marks.isEmpty)
    lastSaid.larrySaid(update.say, marks: !update.marks.isEmpty)
    // Story 762: his silence is said until he next answers.
    if update.replied, problem?.context == WhiteboardLarryClock.DidntAnswer.context { problem = nil }
    // A row landing while a picture is still going up answers an earlier one: the turn on its way stays out.
    // Story 1176: while the board's Send waits in the outbox, an answer to an earlier picture sends nothing.
    if update.replied, !larrySending, !larry.waitingToSend {
      larryFollowUp(larry.replied(version: ops.rev, now: .now), why: "reply")
    }
    let batches = Dictionary(grouping: opBatches(from: .rows(rows))) { $0.batch.key }
    let toShow = Set(update.marks.map(\.id))
    restoreLarrysMarks(excluding: Set(rows.map(\.id)))
    for row in rows {
      if toShow.contains(row.id), let drawing = row.drawing { showLarrys(drawing) }
      for (batch, source) in batches[row.id] ?? [] { receive(batch, from: source) }
    }
  }

  private func restoreLarrysMarks(excluding onThread: Set<String> = []) {
    let onBoard = Set(
      turns.ghosts.filter { $0.who == .larry && $0.text == nil }.compactMap {
        WhiteboardMarks.reply(of: $0.id)
      })
    for drawing in marksHistory.restore(excluding: onThread.union(onBoard)) {
      showLarrys(drawing)
    }
  }

  /// One row of Larry's marks, placed by the row's own frame (where that picture was), joining his unkept ones from
  /// earlier replies, which stay (story 1155, bead context-grabber-n8ab).
  private func showLarrys(_ row: WhiteboardMarks.Drawing) {
    let earlier = turns.ghosts.filter {
      $0.who == .larry && $0.text == nil && WhiteboardMarks.reply(of: $0.id) != row.id
    }
    var history = marksHistory
    let settled = Set(history.settled)
    let seen = pictureTimes.taken(row.pictureID, board: board.id)
    // Story 1046: a picture drawn with folds open maps back onto the folded board.
    let folds = pictureFolds.map(row.pictureID, board: board.id)
    let (marks, nowhere) = connectorGhosts(
      row.shapes.enumerated().map { index, shape in
        Ghost(
          shape, who: .larry, frame: row.frame, scale: row.scale, id: WhiteboardMarks.mark(index, of: row.id),
          hand: penInHand, seen: seen, folds: folds, lettering: lettering)
      }.filter { !settled.contains($0.id) })
    // Story 919: a connector naming nothing on the board shows nothing, and is set aside as if dismissed.
    turns.larrysMarks(marks)
    history.place(row, shown: marks.map(\.id), nowhere: nowhere.map(\.id))
    marksHistory = history
    log.event(
      "whiteboard_marks",
      [
        "action": "shown", "board": board.id, "row": row.id, "shapes": row.shapes.count,
        "picture": row.pictureID ?? "", "picture_known": seen != nil, "folds_open": folds?.steps.count ?? 0,
        "earlier_stayed": earlier.count,
        "earlier_replies": Set(earlier.compactMap { WhiteboardMarks.reply(of: $0.id) }).count,
      ])
  }

  /// #913 (story 662): Larry marked the picture he is looking at done and wrote nothing after it. The turn ends as an
  /// answer with no shapes would. Runs after the look's rows, so a reply landing in the same look has already ended the
  /// turn and this finds no turn out.
  private func larryClosed(_ messages: [ChatMessage]) {
    guard case .awaiting(let since, _) = larry.state, let out = larryOut, out.turn == larry.state,
      WhiteboardLarryWait.doneWithoutReply(out.picture.pictureID, in: messages)
    else { return }
    let looking = Int((ContinuousClock.now - since).components.seconds)
    larryFollowUp(
      larry.closed(version: ops.rev, now: .now), why: "done_no_reply",
      facts: ["picture": out.picture.pictureID, "looking_s": looking])
    checkLarryWait()
  }

  /// Story 662: his turn has been out too long; the board stops waiting, as if he had answered. Story 669: and says so,
  /// as a copyable problem that stays until he next answers or Igor dismisses it, whatever picture goes next.
  private func larryTimedOut() {
    let now = ContinuousClock.now
    let waiting = larry
    let mark = larryMark(now: now)
    guard let next = larry.tick(version: ops.rev, now: now, timeout: Self.larryTimeout) else { return }
    var facts: [String: Any] = [:]
    if let silence = WhiteboardLarryClock.didntAnswer(
      waiting, now: now, wallNow: Date(), cockpitAnswering: !larryAway, mark: mark)
    {
      let sentAt = silence.sentAt.formatted(.iso8601)
      facts = [
        "problem": silence.context, "sent_at": sentAt, "waited_s": silence.waitedSeconds,
        "ink_waiting": silence.inkWaiting, "words_waiting": silence.wordsWaiting,
        "cockpit_answering": silence.cockpitAnswering, "mark": silence.mark.rawValue,
      ]
      problem = .grabber(
        silence.message, context: silence.context,
        extra: [
          "board": .string(board.id), "cockpit": .string(cockpit), "sent_at": .string(sentAt),
          "waited_s": .int(silence.waitedSeconds), "ink_waiting": .bool(silence.inkWaiting),
          "words_waiting": .bool(silence.wordsWaiting), "cockpit_answering": .bool(silence.cockpitAnswering),
          "mark": .string(silence.mark.rawValue),
        ])
    }
    larryFollowUp(next, why: "timeout", facts: facts)
    dismissSoonForTests()
  }

  /// `GRABBER_WHITEBOARD_LARRY_TIMEOUT=<seconds>,dismiss`: *Larry didn't answer* goes 3 s after it shows, as a tap on
  /// *Dismiss* would take it, for the simulator.
  private func dismissSoonForTests() {
    guard LaunchHooks.current.whiteboard.larryTimeout?.dismiss == true else { return }
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard let self, self.problem?.context == WhiteboardLarryClock.DidntAnswer.context else { return }
      self.dismissProblem()
    }
  }

  /// Igor dismissed *Larry didn't answer* (story 761).
  func dismissProblem() {
    log.event("whiteboard", ["action": "problem_dismissed", "board": board.id, "context": problem?.context ?? ""])
    problem = nil
  }

  /// Stories 775–777: twenty seconds into his turn, what where the picture is says to offer (the same reading as the
  /// note's state, story 773). Logged, and the stuck picture's problem shown or taken away, only when it changes: the
  /// problem slot holds one, the newest wins, and this takes away only its own.
  func checkLarryWait() {
    let now = ContinuousClock.now
    let out = larryOut.flatMap { $0.turn == larry.state ? $0 : nil }
    let mark = larryMark(now: now)
    let wait = out == nil ? .none : WhiteboardLarryWait.of(larry, mark: mark, now: now)
    guard wait != larryWait else { return }
    var event: [String: Any] = [
      "action": "larry_wait", "board": board.id, "wait": wait.rawValue, "was": larryWait.rawValue,
      "mark": mark.rawValue, "picture": out?.picture.pictureID ?? "", "sending": larrySending,
      "cockpit_answering": !larryAway,
    ]
    if case .awaiting(let since, _) = larry.state { event["looking_s"] = Int((now - since).components.seconds) }
    log.event("whiteboard", event)
    larryWait = wait
    if wait == .stuck, case .awaiting(let since, _) = larry.state {
      let waited = Int((now - since).components.seconds)
      problem = .grabber(
        WhiteboardLarryWait.stuckMessage, context: WhiteboardLarryWait.stuckContext,
        extra: [
          "board": .string(board.id), "cockpit": .string(cockpit),
          "picture": .string(out?.picture.pictureID ?? ""),
          "sent_at": .string((Date() - TimeInterval(waited)).formatted(.iso8601)), "waited_s": .int(waited),
          "sending": .bool(larrySending), "cockpit_answering": .bool(!larryAway), "mark": .string(mark.rawValue),
        ])
    } else if problem?.context == WhiteboardLarryWait.stuckContext {
      problem = nil
    }
    pressSoonForTests()
  }

  /// `GRABBER_WHITEBOARD_LARRY_WAIT=retry` / `dismiss` / `interrupt`: that control taps itself, once, 3 s after the board
  /// first offers it, for the simulator.
  private func pressSoonForTests() {
    guard let press = larryWaitHook, larryWait == (press == .interrupt ? .working : .stuck) else { return }
    larryWaitHook = nil
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(3))
      switch press {
      case .retry: self?.retryLarry()
      case .dismiss: self?.dismissStuck()
      case .interrupt: self?.interruptLarry()
      }
    }
  }

  /// *Retry* (story 775): the same picture again, under the same message id, so a first one that did land is kept once;
  /// the clock and the twenty seconds start again. A hand-off still hanging is left to end on its own, and replaced.
  func retryLarry() {
    checkLarryWait()
    guard larryWait == .stuck, let out = larryOut, larry.resent(now: .now) else { return }
    log.event(
      "whiteboard",
      [
        "action": "larry_retry", "board": board.id, "picture": out.picture.pictureID, "sending": larrySending,
        "receipt": out.receipt.rawValue,
      ])
    larryHandOffs.replace(out.attempt)
    let turn = larry.state
    larryOut?.turn = turn
    Task { await handToLarry(turn, said: out.said, from: "retry", again: out) }
    checkLarryWait()
  }

  /// *Dismiss* on a stuck picture (story 776): the board stops waiting. The turn is free, the words that went with it
  /// wait for the next picture, and a hand-off still hanging no longer speaks for the board.
  func dismissStuck() {
    checkLarryWait()
    guard larryWait == .stuck else { return }
    log.event(
      "whiteboard",
      [
        "action": "larry_dismiss", "board": board.id, "picture": larryOut?.picture.pictureID ?? "",
        "sending": larrySending,
      ])
    if let out = larryOut { larryHandOffs.replace(out.attempt) }
    larrySending = false
    larry.failed(larry.state, words: larryOut?.said)
    larryOut = nil
    checkLarryWait()
  }

  /// *Interrupt* (story 777): Larry has the picture and the board stops waiting for his answer, so the next pause or tap
  /// is a fresh ask. What he draws or says later still lands. A picture whose sending hasn't been answered is let go of
  /// as *Dismiss* lets go: its hand-off no longer speaks for the board, and its words wait for the next picture unless
  /// the Cockpit's mark says it has them.
  func interruptLarry() {
    checkLarryWait()
    guard larryWait == .working else { return }
    var event: [String: Any] = [
      "action": "larry_interrupt", "board": board.id, "picture": larryOut?.picture.pictureID ?? "",
      "mark": larryMark(now: .now).rawValue, "sending": larrySending,
    ]
    if case .awaiting(let since, _) = larry.state {
      event["looking_s"] = Int((ContinuousClock.now - since).components.seconds)
    }
    guard larry.interrupted() else { return }
    log.event("whiteboard", event)
    if let out = larryOut {
      larryHandOffs.replace(out.attempt)
      larrySending = false
      if !out.delivered, out.receipt == .sent { larry.failed(larry.state, words: out.said) }
    }
    larryOut = nil
    checkLarryWait()
  }

  /// The picture of the board on screen for Larry, its strokes and its id; nil with nothing on screen to show him.
  func larryPicture(said: String?) -> LarryOut? {
    guard let (rect, scale) = pictureFrame() else { return nil }
    larryFrame = rect
    // ponytail: rendered and encoded on the main thread, as the ghost turn is.
    let rendering = ContinuousClock.now
    let shot = shot(rect: rect, scale: scale)
    let encoding = ContinuousClock.now
    let jpeg = shot.image.jpegData(compressionQuality: 0.85) ?? Data()
    let encoded = ContinuousClock.now
    var picture = WhiteboardPicture(
      board: board.id, title: store.index.board(board.id)?.title ?? board.title, rect: shot.rect, scale: shot.scale,
      report: turnReport())
    picture.folds = shot.folds
    picture.build = Self.buildLine
    pictureTimes.record(picture.pictureID, at: Self.unixMs(), board: board.id)
    pictureFolds.record(picture.pictureID, map: shot.folds, board: board.id)
    return LarryOut(
      jpeg: jpeg, strokes: WhiteboardStrokes.wire(strokesForLarry(), texts: texts, metas: strokeMeta),
      folds: foldsForLarry(), picture: picture, rect: shot.rect,
      scale: shot.scale, said: said, renderMs: WhiteboardTimings.ms(rendering.duration(to: encoding)),
      encodeMs: WhiteboardTimings.ms(encoding.duration(to: encoded)))
  }

  /// A picture handed to Larry, kept while his turn on it is out: *Retry* sends exactly this again (story 775).
  struct LarryOut {
    let jpeg: Data
    let strokes: [[String: Any]]
    /// The folded sections, beside the strokes (story 857).
    var folds: [[String: Any]] = []
    let picture: WhiteboardPicture
    let rect: CGRect
    let scale: CGFloat
    /// The words that went with it, back in the queue if it is dismissed, or interrupted before the Cockpit has it.
    let said: String?
    /// How long it took to draw and to encode (story 1112): a *Retry* sends these again with its own send's times.
    var renderMs: Int?
    var encodeMs: Int?
    /// The furthest the Cockpit's mark on its message has got, on the thread.
    var receipt = ChatMessage.Receipt.sent
    /// Its sending was answered: the Cockpit has it.
    var delivered = false
    /// The hand-off it last went under (`WhiteboardLarryHandOffs`).
    var attempt = 0
    /// The turn it went out under: its mark speaks only for that turn, never for a later one (a *Send to Larry* goes
    /// through the Inbox's outbox, which retries on its own, so that turn is offered nothing).
    var turn = WhiteboardLarryTurn.State.idle
  }

  /// His answer came, or the wait ran out: one fresh picture if the board moved on or words waited, else nothing.
  /// `facts`: the state a timeout's problem carries, in the log too.
  func larryFollowUp(_ next: WhiteboardLarryTurn.Next, why: String, facts: [String: Any] = [:]) {
    var event: [String: Any] = ["action": "larry_turn_over", "board": board.id, "why": why]
    event.merge(facts) { $1 }
    switch next {
    case .send(let words):
      event["next"] = "send"
      event["said_chars"] = words?.count ?? 0
      log.event("whiteboard", event)
      let turn = larry.state
      Task { await handToLarry(turn, said: words, from: why) }
    case .held, .done:
      event["next"] = "none"
      log.event("whiteboard", event)
    }
  }

  /// Igor kept or dismissed one of Larry's marks: it doesn't come back when the board opens again, and once none of his
  /// row is left, nor does the row.
  func settleLarrys(_ ghost: Ghost) {
    guard ghost.who == .larry, ghost.text == nil else { return }
    var history = marksHistory
    history.settle(ghost.id, left: turns.ghosts.filter { $0.who == .larry && $0.text == nil }.map(\.id))
    marksHistory = history
  }

  private var marksHistory: WhiteboardMarks.History {
    get {
      let defaults = UserDefaults.standard
      if let data = defaults.data(forKey: marksHistoryKey),
        let saved = try? PropertyListDecoder().decode(WhiteboardMarks.History.self, from: data)
      {
        return saved
      }
      return WhiteboardMarks.History(
        settled: defaults.stringArray(forKey: "whiteboard_marks_settled_marks_\(board.id)") ?? [],
        done: defaults.string(forKey: "whiteboard_marks_settled_\(board.id)").map { [$0] } ?? [])
    }
    set {
      if let data = try? PropertyListEncoder().encode(newValue) {
        UserDefaults.standard.set(data, forKey: marksHistoryKey)
      }
    }
  }

  private var marksHistoryKey: String { "whiteboard_marks_history_\(board.id)" }
}
