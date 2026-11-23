//  One Send (story 1176, bead context-grabber-rtl; Igor, 2026-11-22: "one Send button that waits when offline"). On a
//  board drawn here *Send to Larry* is Larry's turn: the picture and its strokes go through the Inbox's outbox, which
//  sends at once with the network there and waits without it, and the turn is out on it as on any turn of his. While it
//  waits the note says *Waiting to send* and nothing else goes; when the outbox sends it his clock starts. A board only
//  looked at keeps `send()`.

import Combine
import ContextCore
import SwiftUI

extension WhiteboardModel {
  /// This board's *Send* waits in the outbox: the button is dimmed and no second picture goes.
  func sendWaiting(in items: [InboxItem]) -> Bool {
    items.contains { $0.whiteboard?.board == board.id && $0.status == .waiting }
  }

  /// The bar's *Send to Larry*.
  func sendToLarry() {
    guard editable else { return send() }
    guard !larrySending, !sendWaiting(in: inbox.items) else { return }
    let moved = pictureFrame().map { $0.rect != larryFrame } ?? false
    guard case .send(let words) = larry.tapped(version: ops.rev, moved: moved, now: .now) else {
      return alreadyHas(from: "send")
    }
    let turn = larry.state
    // Story 1112: spoken words waiting go among this picture's events.
    micTimingsGo()
    guard var out = larryPicture(said: words) else {
      larry.failed(turn, words: words)
      return
    }
    let thread = threadKey
    var draft = InboxDraft()
    draft.image = out.jpeg
    // As a turn says it: the conversation panel shows no row for a picture without words (story 1047).
    draft.text = words ?? WhiteboardNote.boardTurnNote
    draft.whiteboard = out.picture
    // Story 424: the strokes wait beside the picture, the folded sections with them (story 857).
    draft.strokes = try? WhiteboardStrokes.file(strokes: out.strokes, folds: out.folds)
    do {
      // Story 1115: the message is the picture's id, so what names one finds the other's strokes.
      try inbox.add(&draft, id: out.picture.pictureID, thread: thread)
    } catch {
      larry.failed(turn, words: words)
      log.event("error", ["where": "whiteboard_send", "message": "\(error)", "bytes": out.jpeg.count])
      problem = .grabber(
        "The board could not go to Larry: \(error.localizedDescription)", context: "WhiteboardView.send",
        extra: ["board": .string(board.id), "bytes": .int(out.jpeg.count)])
      return
    }
    // A reply that lands before the first look at a new thread is still his answer (story 662).
    if thread == nil { marks.threadStarted() }
    larry.waitsInOutbox()
    out.turn = larry.state
    out.attempt = larryHandOffs.begin()
    larryOut = out
    sendOut = out.picture.pictureID
    sendListed = false
    if problem?.context == "WhiteboardView.send" { problem = nil }
    shipLog(why: "send")
    log.event(
      "whiteboard",
      [
        "action": "send", "board": board.id, "picture": out.picture.pictureID, "strokes": drawing.strokes.count,
        "bytes": out.jpeg.count, "new_thread": thread == nil, "said_chars": words?.count ?? 0, "folds": out.folds.count,
        "pixels": "\(Int(out.rect.width * out.scale))x\(Int(out.rect.height * out.scale))", "turn": true,
      ])
    followSend(inbox.items)
    checkLarryWait()
  }

  /// The board on screen: a *Send* of this board still in the outbox is waiting again, and the Inbox is watched for when
  /// it goes.
  func watchSend() {
    guard editable, sendWatch == nil else { return }
    if sendOut == nil,
      let waiting = inbox.items.first(where: { $0.whiteboard?.board == board.id && $0.status == .waiting })
    {
      sendOut = waiting.id
      sendListed = true
      larry.reopenedWaiting(version: ops.rev, now: .now)
      log.event("whiteboard", ["action": "send_waiting", "board": board.id, "picture": waiting.id])
    }
    sendWatch = inbox.$items.sink { [weak self] items in
      MainActor.assumeIsolated { self?.followSend(items) }
    }
  }

  /// What became of the waiting *Send*: sent starts his clock; refused, or deleted from the Inbox, frees the turn.
  func followSend(_ items: [InboxItem]) {
    guard let id = sendOut else { return }
    guard let item = items.first(where: { $0.id == id }) else {
      // Not listed yet: the Inbox reads it back after the add.
      if sendListed { sendEnded(id, why: "deleted", refusal: nil) }
      return
    }
    sendListed = true
    switch item.status {
    case .waiting: return
    case .sent:
      sendOut = nil
      sendListed = false
      let started = larry.outboxSent(now: .now)
      if larryOut?.picture.pictureID == id {
        larryOut?.turn = larry.state
        larryOut?.delivered = true
      }
      log.event("whiteboard", ["action": "send_went", "board": board.id, "picture": id, "clock": started])
      checkLarryWait()
    case .refused:
      sendEnded(id, why: "refused", refusal: item.refused ?? "")
    }
  }

  private func sendEnded(_ id: String, why: String, refusal: String?) {
    sendOut = nil
    sendListed = false
    let mine = larryOut?.picture.pictureID == id
    if larry.waitingToSend { larry.failed(larry.state, words: mine ? larryOut?.said : nil) }
    if mine { larryOut = nil }
    log.event("whiteboard", ["action": "send_ended", "board": board.id, "picture": id, "why": why])
    if let refusal {
      problem = .grabber(
        "The Cockpit refused the board: \(refusal)", context: "WhiteboardView.send",
        extra: ["board": .string(board.id), "picture": .string(id)])
    }
    checkLarryWait()
  }
}
