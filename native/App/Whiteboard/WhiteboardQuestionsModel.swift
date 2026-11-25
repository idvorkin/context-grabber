//  Question cards on a board (spec 2026-11-16-whiteboard-question-cards-design.md, stories 880–886): the board's cards,
//  kept on this device with the board, the Cockpit's open asks read for them, and what a card does when tapped,
//  answered, folded or erased. The rules are `WhiteboardQuestions` in ContextCore; the answering is Chat's
//  `ChatDecisionsModel`, which the popup's decision card runs.

import BugKit
import ContextCore
import Foundation

@MainActor
final class WhiteboardQuestionsModel: ObservableObject {
  @Published private(set) var board: WhiteboardQuestions
  /// The open asks by id, the snoozed ones too, from the last read that worked.
  @Published private(set) var asks: [String: ChatAsk] = [:]
  /// A read of the asks has worked since the board opened.
  @Published private(set) var asksRead = false
  @Published private(set) var reading = false
  /// The card whose popup is up.
  @Published var opened: Opened?

  /// Story 1315: the board menu's *Archived questions* list is up.
  @Published var archiveOpen = false
  /// Stories 1316, 1317: each thought-over ask's conversation with Larry, by ask id.
  @Published var talks: [String: Talk] = [:]

  struct Opened: Identifiable, Equatable {
    let id: String
  }

  let boardID: String
  let log: SessionLog
  private let inbox: InboxModel
  let cockpit: String
  private let threads = WhiteboardThreads()
  /// What's on screen in board points, where a card for an open ask lands; the board's model sets it.
  var visibleRect: () -> CGRect = { .null }
  private var asksFailing = false
  private var answersFailing = false

  /// The board's meaning, where the cards are kept with the rest of it (`BoardMeaning`).
  private let ledger: BoardMeaningLedger

  init(board: String, log: SessionLog, inbox: InboxModel, cockpit: String, ledger: BoardMeaningLedger) {
    boardID = board
    self.log = log
    self.inbox = inbox
    self.cockpit = cockpit
    self.ledger = ledger
    self.board = ledger.questions(board: board)
  }

  var reachable: Bool { !inbox.offline && cockpit != ChatCockpit.nowhere }

  func change(_ new: WhiteboardQuestions) {
    guard new != board else { return }
    board = new
    ledger.setQuestions(new, board: boardID)
  }

  func title(of card: WhiteboardQuestion) -> String? { asks[card.ask]?.title }

  // MARK: Where cards come from

  /// The board opened or came back: open asks naming it land, and cards whose ask has closed fetch their answers.
  func sync(reason: String) async {
    guard await readAsks(reason: reason) else { return }
    var next = board
    let keys = [threads.thread(board: boardID) ?? "", boardID]
    let landed = next.landOpen(Array(asks.values).sorted { $0.id < $1.id }, keys: keys, visible: visibleRect())
    change(next)
    if landed > 0 {
      log.event("whiteboard_questions", ["action": "landed", "board": boardID, "from": "asks", "cards": landed])
    }
    await fillAnswers()
  }

  /// A look at the board's thread: Larry's question marks not landed before land where he put them.
  func looked(_ body: Data) {
    let placements = WhiteboardQuestions.placements(body)
    guard !placements.isEmpty else { return }
    var next = board
    let landed = next.land(placements)
    change(next)
    guard landed > 0 else { return }
    log.event("whiteboard_questions", ["action": "landed", "board": boardID, "from": "larry", "cards": landed])
    Task { await self.readAsks(reason: "landed") }
  }

  /// Offline or with no address nothing is read and the cards stay as they are; a failed read is logged once until one
  /// works.
  @discardableResult
  private func readAsks(reason: String) async -> Bool {
    guard reachable else { return false }
    reading = true
    defer { reading = false }
    do {
      let (data, response) = try await URLSession.shared.data(for: WhiteboardQuestions.asksRequest(cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let read = ChatDecisions.asks(data) else {
        return asksFailed("HTTP \(status)", reason: reason)
      }
      asks = Dictionary(read.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
      asksRead = true
      asksFailing = false
      return true
    } catch {
      return asksFailed(error.localizedDescription, reason: reason)
    }
  }

  private func asksFailed(_ why: String, reason: String) -> Bool {
    if !asksFailing {
      asksFailing = true
      log.event("error", ["where": "whiteboard_questions_asks", "board": boardID, "why": reason, "message": why])
    }
    return false
  }

  /// Cards whose ask is no longer open ask the Cockpit for its question and answer: the decisions log first.
  private func fillAnswers() async {
    guard asksRead, reachable else { return }
    let wanted = board.wanted(open: Set(asks.keys))
    guard !wanted.isEmpty else { return }
    do {
      let (data, response) = try await URLSession.shared.data(
        for: WhiteboardQuestions.answersRequest(wanted, cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let got = WhiteboardQuestions.answers(data) else {
        return answersFailed("HTTP \(status)")
      }
      answersFailing = false
      var next = board
      let filled = next.fill(got, asked: wanted)
      change(next)
      log.event(
        "whiteboard_questions",
        ["action": "answers", "board": boardID, "asked": wanted.count, "found": got.count, "filled": filled])
    } catch {
      answersFailed(error.localizedDescription)
    }
  }

  private func answersFailed(_ why: String) {
    guard !answersFailing else { return }
    answersFailing = true
    log.event("error", ["where": "whiteboard_questions_answers", "board": boardID, "message": why])
  }

  // MARK: What a card does

  /// A tap: a chip opens out; any other card opens its popup, an open one reading the asks first.
  func tap(_ card: WhiteboardQuestion) {
    if card.answered != nil, card.collapsed {
      var next = board
      next.collapse(card.id, false)
      change(next)
      log.event("whiteboard_questions", ["action": "expand", "board": boardID, "ask": card.ask])
      return
    }
    log.event(
      "whiteboard_questions", ["action": "open", "board": boardID, "ask": card.ask, "answered": card.answered != nil])
    opened = Opened(id: card.id)
    guard card.needsAnswer else { return }
    Task {
      await readAsks(reason: "open")
      if asks[card.ask] == nil { await fillAnswers() }
    }
  }

  /// *Shrink* (called *Collapse* until 2026-11-24) in an answered card's popup: the card is its one-line chip.
  func collapse(_ card: WhiteboardQuestion) {
    guard opened?.id == card.id else { return }
    opened = nil
    var next = board
    guard next.collapse(card.id, true) else { return }
    change(next)
    log.event("whiteboard_questions", ["action": "collapse", "board": boardID, "ask": card.ask])
  }

  /// Story 1119: the fold control on an opened card not yet answered: back to its one line on the paper, nothing
  /// answered.
  func fold(_ card: WhiteboardQuestion) {
    guard opened?.id == card.id else { return }
    opened = nil
    log.event("whiteboard_questions", ["action": "collapse", "board": boardID, "ask": card.ask, "answered": false])
  }

  /// What the popup's decision card came to. Chat's model has logged the verb and holds a refused one's problem.
  func decided(_ card: WhiteboardQuestion, ask: ChatAsk, verb: ChatDecisions.Verb, outcome: ChatDecisions.Outcome) {
    switch outcome {
    case .done:
      if opened?.id == card.id { opened = nil }
      guard let answer = WhiteboardQuestions.answer(for: verb, title: ask.title) else { return }
      var next = board
      next.answer(card.id, answer)
      change(next)
      asks[ask.id] = nil
      log.event("whiteboard_questions", ["action": "answered", "board": boardID, "ask": ask.id, "verb": verb.word])
    case .alreadyAnswered:
      asks[ask.id] = nil
      Task {
        await readAsks(reason: "already_answered")
        await fillAnswers()
      }
    case .changed:
      Task { await readAsks(reason: "changed") }
    case .refused:
      break
    }
  }

  /// A stroke of the eraser, in board points: the answered cards it crosses go.
  func erase(crossing points: [CGPoint]) {
    var next = board
    let gone = next.erase(crossing: points)
    guard !gone.isEmpty else { return }
    change(next)
    log.event("whiteboard_questions", ["action": "erased", "board": boardID, "asks": gone.map(\.ask)])
  }
}
