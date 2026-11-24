//  Question cards archive and think over (spec 2026-11-16-whiteboard-question-cards-design.md, *Archiving a card* and
//  *Thinking it over*; stories 1314–1317, #1387): a card archived off the board and reopened from the board menu's
//  list, and an open card talked over with Larry on the ask's own chat thread. The rules are `WhiteboardQuestions`'
//  archive, reopen and think in ContextCore; the wire is its thinkRequest and talkRequest.

import ContextCore
import Foundation

extension WhiteboardQuestionsModel {
  /// One ask's conversation as last read, and what its field is doing.
  struct Talk: Equatable {
    var messages: [ChatMessage] = []
    var read = false
    var sending = false
    /// The words last sent without an answer, and the id they went with: sent again unchanged, they reuse it so the
    /// Cockpit takes them once.
    var pendingWords: String?
    var pendingID: String?
    /// A read or a send that failed, with the state that explains it: shown copyably in the popup.
    var problem: String?
  }

  // MARK: Archive

  /// Story 1314: *Archive* in a card's popup. The popup closes and the card leaves the board; nothing is answered.
  func archive(_ card: WhiteboardQuestion) {
    if opened?.id == card.id { opened = nil }
    var next = board
    guard next.archive(card.id, at: Int64(Date().timeIntervalSince1970 * 1000)) else { return }
    change(next)
    log.event(
      "whiteboard_questions",
      ["action": "archived", "board": boardID, "ask": card.ask, "answered": card.answered != nil])
  }

  /// Story 1315: *Reopen* in the archive's list: the card is back where it was, as it was.
  func reopen(_ card: WhiteboardQuestion) {
    var next = board
    guard next.reopen(card.id) else { return }
    change(next)
    if next.archived.isEmpty { archiveOpen = false }
    log.event("whiteboard_questions", ["action": "reopened", "board": boardID, "ask": card.ask])
  }

  // MARK: Thinking

  /// Story 1316: *Thinking* on an open card: it's thought over from now on, and its conversation is read.
  func think(_ card: WhiteboardQuestion) {
    var next = board
    guard next.think(card.id) else { return }
    change(next)
    log.event("whiteboard_questions", ["action": "thinking", "board": boardID, "ask": card.ask])
    Task { await readTalk(card.ask) }
  }

  func talk(_ ask: String) -> Talk { talks[ask] ?? Talk() }

  /// Story 1317: the ask's conversation, read again. A failed read keeps what was read and says why, logged once until
  /// one works.
  func readTalk(_ ask: String) async {
    guard reachable else { return }
    do {
      let (data, response) = try await URLSession.shared.data(
        for: WhiteboardQuestions.talkRequest(ask: ask, cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let messages = ChatWire.messages(data) else {
        return talkFailed(ask, "the conversation didn't load: HTTP \(status)")
      }
      var talk = talk(ask)
      let was = talk.messages.count
      talk.messages = messages.filter { !$0.isSystem }
      talk.read = true
      talk.problem = nil
      talks[ask] = talk
      if talk.messages.count != was {
        log.event(
          "whiteboard_questions",
          [
            "action": "talk_read", "board": boardID, "ask": ask, "messages": talk.messages.count,
            "larry": talk.messages.filter { !$0.fromIgor }.count,
          ])
      }
    } catch {
      talkFailed(ask, "the conversation didn't load: \(error.localizedDescription)")
    }
  }

  /// Story 1316: Igor's words to the ask's conversation. True when they were taken; on false the field keeps them.
  func say(_ words: String, on card: WhiteboardQuestion) async -> Bool {
    guard reachable, ChatDecisions.canSend(words: words) else { return false }
    var talk = talk(card.ask)
    let id = (talk.pendingWords == words ? talk.pendingID : nil) ?? UUID().uuidString.lowercased()
    talk.sending = true
    talk.pendingWords = words
    talk.pendingID = id
    talks[card.ask] = talk
    defer { talks[card.ask]?.sending = false }
    do {
      let (data, response) = try await URLSession.shared.data(
        for: WhiteboardQuestions.thinkRequest(ask: card.ask, words: words, id: id, cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode
      switch ChatSend.outcome(status: status, body: data) {
      case .sent:
        log.event("whiteboard_questions", ["action": "talk_sent", "board": boardID, "ask": card.ask])
        talks[card.ask]?.problem = nil
        talks[card.ask]?.pendingWords = nil
        talks[card.ask]?.pendingID = nil
        await readTalk(card.ask)
        return true
      case .refused(let status, let reason):
        talkFailed(card.ask, "Larry's Cockpit refused the message (HTTP \(status)): \(reason)")
      case .retry(let reason):
        talkFailed(card.ask, "the message didn't go: \(reason); try again")
      }
    } catch {
      talkFailed(card.ask, "the message didn't go: \(error.localizedDescription); try again")
    }
    return false
  }

  private func talkFailed(_ ask: String, _ why: String) {
    var talk = talk(ask)
    let first = talk.problem == nil
    talk.problem = why
    talks[ask] = talk
    guard first else { return }
    log.event("error", ["where": "whiteboard_questions_talk", "board": boardID, "ask": ask, "message": why])
  }
}
