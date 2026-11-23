//  Opening, flushing, closing and saving the board, and Send to Inbox.
//  Moved out of WhiteboardView.swift (context-grabber-jp6z); the model's state, init and load are in WhiteboardModel.swift.

import BugKit
import Combine
import ContextCore
import PencilKit
import SwiftUI

extension WhiteboardModel {
  /// The app going to the background: what is drawn is written now. The board stays open, so an empty new one is
  /// kept.
  func flush() {
    stopWatchingLarry()
    saveTask?.cancel()
    if editable, dirty || opLedger.unsaved { save(.background) }
  }

  /// On screen: a delete from another device waits for `close`, which comes after the last save.
  func opened() {
    guard editable else { return }
    store.opened(board.id)
    watchSend()
    Task { await readResponder() }
  }

  /// Leaving the board, by Back or by a link that takes it down: what is drawn is written now, not a second later,
  /// and goes up to iCloud. Safe to call twice.
  func close() {
    stopWatchingLarry()
    sendWatch?.cancel()
    sendWatch = nil
    saveTask?.cancel()
    heldTask?.cancel()
    ops.closed()
    if let dropped = ops.dropHeld(reason: "board_closed") {
      log.event(
        "board_ops", ["action": "refused", "board": board.id, "label": dropped.label, "reason": "board_closed"])
    }
    guard editable else { return }
    if dirty || opLedger.unsaved {
      save(.close)
      log.event(
        "whiteboard", ["action": "close", "board": board.id, "strokes": drawing.strokes.count, "saved": !dirty])
      if dirty, let problem { store.closedUnsaved(problem, board: board.id) }
    }
    store.closed(board.id, empty: drawing.strokes.isEmpty)
  }

  // ponytail: serialised on the main thread; a board big enough to stutter here moves it to a background task.
  /// `trigger`: what set the save off, for its timing in the session log (#1044).
  func save(_ trigger: BoardSaveTiming.Trigger) {
    guard dirty || opLedger.unsaved else { return }
    guard dirty else {
      writeMeaning()
      return
    }
    do {
      if let written = try store.save(drawing, meaning: opLedger.meaning, board: board.id, trigger: trigger) {
        opLedger.wrote(written)
      }
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

  /// A board only looked at (story 746); a board drawn here sends through `sendToLarry` (story 1176).
  /// Story 343: the whole drawing (on paper, the pages on screen: story 433), dark ink on white whatever the iPad's mode,
  /// on the board's thread with Larry, titled with the board's name; the first one starts it (story 381).
  func send() {
    guard sent == nil, !larrySending, let (rect, scale) = pictureFrame() else { return }
    // Story 662: a Send is Larry's turn too, out now whatever was held; words that waited go with it. Story 765: not
    // while he is looking at the board as it is.
    guard case .send(let words) = larry.tapped(version: ops.rev, moved: rect != larryFrame, now: .now) else {
      return alreadyHas(from: "send")
    }
    larryFrame = rect
    let turn = larry.state
    checkLarryWait()
    let shot = shot(rect: rect, scale: scale)
    let ink = shot.image
    let jpeg = ink.jpegData(compressionQuality: 0.85) ?? Data()
    var draft = InboxDraft()
    draft.image = jpeg
    let title = store.index.board(board.id)?.title ?? board.title
    draft.text = words.map { "\(title): \($0)" } ?? title
    // Story 1112: spoken words waiting go among this picture's events.
    micTimingsGo()
    var sending = WhiteboardPicture(
      board: board.id, title: title, rect: shot.rect, scale: shot.scale, report: turnReport())
    sending.folds = shot.folds
    sending.build = Self.buildLine
    draft.whiteboard = sending
    pictureTimes.record(sending.pictureID, at: Self.unixMs(), board: board.id)
    pictureFolds.record(sending.pictureID, map: shot.folds, board: board.id)
    // Story 424: the strokes wait beside the picture and go first when it goes.
    draft.strokes = try? JSONSerialization.data(
      withJSONObject: WhiteboardStrokes.wire(strokesForLarry(), texts: texts, metas: strokeMeta))
    do {
      // Story 1115: the message is the picture's id, as on Larry's turn, so what names one finds the other's strokes.
      // Story 1158: the board's one conversation, the one it carries when another device drew it.
      try inbox.add(&draft, id: sending.pictureID, thread: threadKey)
      if problem?.context == "WhiteboardView.send" { problem = nil }
      sent = "Sent to Larry: his reply shows in Chat"
      sentFrame = rect
      shipLog(why: "send")
      log.event(
        "whiteboard",
        [
          "action": "send", "board": board.id, "strokes": drawing.strokes.count, "bytes": jpeg.count,
          "pixels": "\(Int(ink.size.width * ink.scale))x\(Int(ink.size.height * ink.scale))",
          "frame": [Double(shot.rect.minX), Double(shot.rect.minY), Double(shot.rect.width), Double(shot.rect.height)],
          "folds_open": shot.folds?.steps.count ?? 0,
        ])
    } catch {
      larry.failed(turn, words: words)
      log.event("error", ["where": "whiteboard_send", "message": "\(error)", "bytes": jpeg.count])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["bytes": .int(jpeg.count)])
    }
  }
}
