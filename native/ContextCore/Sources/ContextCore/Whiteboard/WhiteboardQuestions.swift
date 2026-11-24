//  Question cards on a board (spec 2026-11-16-whiteboard-question-cards-design.md, stories 880–886): Larry's open asks
//  as live cards, placed by him in a reply or by an open ask naming the board, answered through Chat's decision verbs,
//  and kept on the board answered, as *✓ <question>* over the answer. Ported from the Cockpit's assets/ink/board.mjs
//  (`addQuestion`, `answerQuestion`, `needsAnswer`, `collapseQuestion`, `cardLines`, CARD_W and CARD_H) and ink.html's
//  question cards. Here: the cards, where they land, what they say, what the eraser takes, and the Cockpit's wire.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// One card: the ask it is for, its top-left in board points, and once answered the question and the answer.
public struct WhiteboardQuestion: Codable, Equatable, Sendable, Identifiable {
  public struct Answer: Codable, Equatable, Sendable {
    /// The question, as it was asked; nil on a card answered before it was known.
    public var title: String?
    /// The option's label, the words, *Closed* or *Abandoned*.
    public var label: String
    public var note: String?

    public init(title: String?, label: String, note: String? = nil) {
      self.title = title.flatMap { $0.isEmpty ? nil : String($0.prefix(300)) }
      self.label = String(label.prefix(200))
      self.note = note.flatMap { $0.isEmpty ? nil : String($0.prefix(2000)) }
    }

    /// The placeholder for an ask closed elsewhere whose answer the Cockpit doesn't have yet.
    public static let unknown = Answer(title: nil, label: "answered")
  }

  public let id: String
  public let ask: String
  public var x: CGFloat
  public var y: CGFloat
  public var answered: Answer?
  public var collapsed: Bool
  /// Story 1273 (#1387): shrunk to a bare '?' at its top-left; a tap brings it back as it was.
  public var hidden: Bool
  /// Story 1314 (#1387): when it was archived off the board, UTC ms; nil on the board.
  public var archived: Int64?
  /// Story 1316 (#1387): Igor is thinking it over with Larry on the ask's own thread.
  public var thinking: Bool

  public init(
    id: String, ask: String, x: CGFloat, y: CGFloat, answered: Answer? = nil, collapsed: Bool = false,
    hidden: Bool = false, archived: Int64? = nil, thinking: Bool = false
  ) {
    self.id = id
    self.ask = ask
    self.x = x
    self.y = y
    self.answered = answered
    self.collapsed = collapsed
    self.hidden = hidden
    self.archived = archived
    self.thinking = thinking
  }

  private enum CodingKeys: String, CodingKey { case id, ask, x, y, answered, collapsed, hidden, archived, thinking }

  /// A board kept before cards could hide, archive or think has none of those: its cards are shown, on the board.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    ask = try c.decode(String.self, forKey: .ask)
    x = try c.decode(CGFloat.self, forKey: .x)
    y = try c.decode(CGFloat.self, forKey: .y)
    answered = try c.decodeIfPresent(Answer.self, forKey: .answered)
    collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
    hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    archived = try c.decodeIfPresent(Int64.self, forKey: .archived)
    thinking = try c.decodeIfPresent(Bool.self, forKey: .thinking) ?? false
  }

  /// Closed, but the board doesn't hold its question and answer yet: none, no question, or the placeholder.
  public var needsAnswer: Bool {
    guard let answered else { return true }
    return answered.title == nil || answered == .unknown
  }
}

/// A board's cards, kept with the board on this device, and the question marks of Larry's already landed.
public struct WhiteboardQuestions: Codable, Equatable, Sendable {
  public internal(set) var cards: [WhiteboardQuestion]
  /// Larry's question marks that have landed (`WhiteboardMarks.mark`): each lands once, even once erased.
  public private(set) var handled: [String]

  public init(cards: [WhiteboardQuestion] = [], handled: [String] = []) {
    self.cards = cards
    self.handled = handled
  }

  /// The web board's CARD_W and CARD_H, in board points: a page is as wide on both (820).
  public static let width: CGFloat = 600
  public static let height: CGFloat = 40
  /// Where a card for an open ask lands across: the web board's left margin and 16.
  public static let left: CGFloat = 80
  /// Between cards landing one under another.
  static let gap: CGFloat = 8
  /// A chip's letters, in board points (the web's CHIP_PX).
  public static let chipLetters: CGFloat = 14
  /// A hidden card's '?', each way, in board points: a card's height, a finger's size at the board's normal zoom.
  public static let mark: CGFloat = 40

  public func card(_ id: String) -> WhiteboardQuestion? { cards.first { $0.id == id } }

  /// The cards on the board: every card but the archived ones.
  public var shown: [WhiteboardQuestion] { cards.filter { $0.archived == nil } }

  // MARK: Where cards land

  /// A card for `ask` at `x`, `y`, inside the page; none when the board has one for that ask. True when it landed.
  @discardableResult
  public mutating func add(ask: String, x: CGFloat, y: CGFloat, id: String = UUID().uuidString.lowercased()) -> Bool {
    guard !ask.isEmpty, !cards.contains(where: { $0.ask == ask }) else { return false }
    cards.append(WhiteboardQuestion(id: id, ask: ask, x: Self.inPage(x: x, width: Self.width), y: max(0, y)))
    return true
  }

  /// One of Larry's question marks: the ask, where he put it on the board, and the mark that remembers it landed.
  public struct Placement: Equatable, Sendable {
    public let mark: String
    public let ask: String
    public let at: CGPoint

    public init(mark: String, ask: String, at: CGPoint) {
      self.mark = mark
      self.ask = ask
      self.at = at
    }
  }

  /// Larry's question marks not landed before: a card each, once per ask. How many cards landed.
  public mutating func land(_ placements: [Placement]) -> Int {
    var landed = 0
    for p in placements where !handled.contains(p.mark) {
      handled.append(p.mark)
      if add(ask: p.ask, x: p.at.x, y: p.at.y) { landed += 1 }
    }
    return landed
  }

  /// The open asks that name this board (its thread, or the board, in `keys`) and have no card yet: each lands at the
  /// top of `visible`, by the left margin, one under another. How many landed.
  public mutating func landOpen(_ asks: [ChatAsk], keys: [String], visible: CGRect) -> Int {
    var y = (visible.isNull || visible.isInfinite ? 0 : visible.minY) + 16
    var landed = 0
    for ask in asks where Self.namesBoard(ask, keys: keys) {
      if add(ask: ask.id, x: Self.left, y: y) {
        landed += 1
        y += Self.height + Self.gap
      }
    }
    return landed
  }

  /// An ask is about the board when its thread is the board's, or its context names the board's thread or the board.
  public static func namesBoard(_ ask: ChatAsk, keys: [String]) -> Bool {
    let keys = keys.filter { !$0.isEmpty }
    return keys.contains { $0 == ask.thread } || keys.contains { ask.context.contains($0) }
  }

  // MARK: Answers

  /// The asks of cards that need their answer from the Cockpit: none of them open (`open`, a read that worked).
  public func wanted(open: Set<String>) -> [String] {
    var out: [String] = []
    for card in cards where card.needsAnswer && !open.contains(card.ask) && !out.contains(card.ask) {
      out.append(card.ask)
    }
    return out
  }

  /// What the Cockpit had for `asked`: an answer where it had one, the placeholder where it had none and the card had
  /// nothing (asked again next time). How many cards changed.
  public mutating func fill(_ answers: [String: WhiteboardQuestion.Answer], asked: [String]) -> Int {
    var changed = 0
    for i in cards.indices where asked.contains(cards[i].ask) && cards[i].needsAnswer {
      if let answer = answers[cards[i].ask] {
        cards[i].answered = answer
        changed += 1
      } else if cards[i].answered == nil {
        cards[i].answered = .unknown
        changed += 1
      }
    }
    return changed
  }

  public mutating func answer(_ id: String, _ answer: WhiteboardQuestion.Answer) {
    guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
    cards[i].answered = answer
  }

  /// What a decision verb that the Cockpit took leaves on the card; nil for a snooze, which leaves it open.
  public static func answer(for verb: ChatDecisions.Verb, title: String) -> WhiteboardQuestion.Answer? {
    switch verb {
    case .answer(let option): return .init(title: title, label: option.label)
    case .ownWords(let words): return .init(title: title, label: words.trimmingCharacters(in: .whitespacesAndNewlines))
    case .close(let reason): return .init(title: title, label: "Closed", note: reason)
    case .abandon(let reason): return .init(title: title, label: "Abandoned", note: reason)
    case .snooze: return nil
    }
  }

  /// Fold an answered card to its chip, or open it out. False for an open card or none.
  @discardableResult
  public mutating func collapse(_ id: String, _ on: Bool) -> Bool {
    guard let i = cards.firstIndex(where: { $0.id == id && $0.answered != nil }) else { return false }
    cards[i].collapsed = on
    return true
  }

  /// Story 1273: hide a card to its '?', or bring it back as it was, kept inside the page. False for none.
  @discardableResult
  public mutating func hide(_ id: String, _ on: Bool) -> Bool {
    guard let i = cards.firstIndex(where: { $0.id == id }) else { return false }
    cards[i].hidden = on
    if !on { cards[i].x = Self.inPage(x: cards[i].x, width: Self.box(cards[i]).width) }
    return true
  }

  /// Story 1274: a card, chip or '?' let go with its top-left at `to`, kept inside the page. Where it landed; nil for
  /// none.
  @discardableResult
  public mutating func move(_ id: String, to: CGPoint) -> CGPoint? {
    guard let i = cards.firstIndex(where: { $0.id == id }) else { return nil }
    cards[i].x = Self.inPage(x: to.x, width: Self.box(cards[i]).width)
    cards[i].y = max(0, to.y)
    return CGPoint(x: cards[i].x, y: cards[i].y)
  }

  private static func inPage(x: CGFloat, width: CGFloat) -> CGFloat {
    max(BoardPages.margin + 8, min(x, BoardPages.pageWidth - width - 8))
  }

  // MARK: On the board

  /// The card's box in board points: a chip is only as wide as its words, a hidden card its '?'.
  public static func box(_ card: WhiteboardQuestion) -> CGRect {
    if card.hidden { return CGRect(x: card.x, y: card.y, width: mark, height: mark) }
    var w = width
    if card.answered != nil, card.collapsed, let line = lines(card, title: nil).first {
      // ponytail: letters measured as a share of their height, not by the font; a font measure if chips look wrong.
      w = min(width, (CGFloat(line.count) * chipLetters * 0.55).rounded(.up) + 32)
    }
    return CGRect(x: card.x, y: card.y, width: w, height: height)
  }

  /// The answered cards a stroke of the eraser crosses, taken off the board; an open card is live and stays.
  public mutating func erase(crossing points: [CGPoint], reach: CGFloat = 8) -> [WhiteboardQuestion] {
    let gone = cards.filter { card in
      card.archived == nil && card.answered != nil
        && points.contains { Self.box(card).insetBy(dx: -reach, dy: -reach).contains($0) }
    }
    cards.removeAll { card in gone.contains { $0.id == card.id } }
    return gone
  }

  /// An open card's line: *? <question> ···*, *Question* until the asks are read. Cut to the card by its view.
  public static func openLine(title: String?, thinking: Bool = false) -> String {
    "\(thinking ? "…" : "?") \(title ?? "Question") ···"
  }

  /// What a card says, line by line: open, its one line; answered, *✓ <question>* over the answer (the label, then the
  /// note); folded, the question alone; one answered with no question known, its answer.
  public static func lines(_ card: WhiteboardQuestion, title: String?) -> [String] {
    if card.hidden { return ["?"] }
    guard let a = card.answered else { return [openLine(title: title, thinking: card.thinking)] }
    guard let question = a.title else { return ["✓ \(a.label.isEmpty ? "answered" : a.label)"] }
    if card.collapsed { return ["✓ \(question)"] }
    return ["✓ \(question)", answerText(a)]
  }

  public static func answerText(_ a: WhiteboardQuestion.Answer) -> String {
    guard let note = a.note else { return a.label }
    return a.label.isEmpty ? note : "\(a.label) — \(note)"
  }

  // MARK: The Cockpit's wire

  /// Larry's question marks in `GET /chat/<key>`: `{kind: question, ask, x, y}` in the picture's pixels, placed by the
  /// row's own frame as his other marks are. A row with no frame, or a mark with no ask, has nowhere to go.
  public static func placements(_ data: Data) -> [Placement] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["ok"] as? Bool == true,
      let messages = json["messages"] as? [[String: Any]]
    else { return [] }
    var out: [Placement] = []
    for message in messages where message["who"] as? String == "larry" {
      guard let id = message["id"] as? String, let shapes = message["shapes"] as? [Any],
        let place = (message["frame"] as? [String: Any]).flatMap(WhiteboardMarks.frame)
      else { continue }
      for (i, any) in shapes.enumerated() {
        guard let shape = any as? [String: Any], shape["kind"] as? String == "question",
          let ask = shape["ask"] as? String, !ask.isEmpty,
          let x = shape["x"].flatMap(WhiteboardTurn.number), let y = shape["y"].flatMap(WhiteboardTurn.number)
        else { continue }
        let at = CGPoint(x: place.rect.minX + x / place.scale, y: place.rect.minY + y / place.scale)
        out.append(Placement(mark: WhiteboardMarks.mark(i, of: id), ask: ask, at: at))
      }
    }
    return out
  }

  /// `{ok, answers: {id: {title, label, note}}}`, or nil for an answer that isn't that.
  public static func answers(_ data: Data) -> [String: WhiteboardQuestion.Answer]? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["ok"] as? Bool == true
    else { return nil }
    let raw = json["answers"] as? [String: Any] ?? [:]
    var out: [String: WhiteboardQuestion.Answer] = [:]
    for (id, any) in raw {
      guard let a = any as? [String: Any] else { continue }
      out[id] = .init(title: a["title"] as? String, label: a["label"] as? String ?? "", note: a["note"] as? String)
    }
    return out
  }
}
