//  A question card's looks (spec 2026-11-16-whiteboard-question-cards-design.md, *The card's looks*; stories 1319–1321,
//  #1387 part 3; the words agreed with Larry for this board and the web's): full, short (an answered card's one-line
//  chip) and round (an open '?', an answered '✓'). *Collapse* steps one look smaller, *Open out* goes back to full, a
//  double tap is Collapse that wraps from round to full, and the controls a look allows sit in one strip in one order.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif
#if canImport(CoreGraphics)
  import CoreGraphics
#endif

extension WhiteboardQuestion {
  public enum Look: String, Equatable, Sendable {
    case full, short, round
  }

  /// The strip's controls, in the strip's one order.
  public enum Control: String, CaseIterable, Equatable, Sendable {
    case collapse, openOut, archive, thinking
  }

  public var look: Look { hidden ? .round : (collapsed && answered != nil ? .short : .full) }
}

extension WhiteboardQuestions {
  /// The strip's icons, each way, in board points, and the gap between them.
  public static let control: CGFloat = 32
  public static let controlGap: CGFloat = 6

  /// The looks a card steps through, smallest last: an open card is one line already, so it has no short.
  private static func looks(_ card: WhiteboardQuestion) -> [WhiteboardQuestion.Look] {
    card.answered == nil ? [.full, .round] : [.full, .short, .round]
  }

  private mutating func set(_ id: String, _ look: WhiteboardQuestion.Look) -> WhiteboardQuestion.Look? {
    guard let i = cards.firstIndex(where: { $0.id == id }) else { return nil }
    cards[i].hidden = look == .round
    cards[i].collapsed = look == .short
    // A card coming back from round is kept inside the page by its own width (`hide`).
    if look != .round { hide(id, false) }
    return look
  }

  /// *Collapse*: one look smaller. The new look; nil for none, or a round.
  @discardableResult
  public mutating func collapseStep(_ id: String) -> WhiteboardQuestion.Look? {
    guard let card = card(id) else { return nil }
    let order = Self.looks(card)
    guard let i = order.firstIndex(of: card.look), i + 1 < order.count else { return nil }
    return set(id, order[i + 1])
  }

  /// *Open out*: back to full. Nil for none, or one already full.
  @discardableResult
  public mutating func openOut(_ id: String) -> WhiteboardQuestion.Look? {
    guard let card = card(id), card.look != .full else { return nil }
    return set(id, .full)
  }

  /// A double tap: Collapse, and from a round back to full.
  @discardableResult
  public mutating func cycle(_ id: String) -> WhiteboardQuestion.Look? {
    guard let card = card(id) else { return nil }
    return card.look == .round ? openOut(id) : collapseStep(id)
  }

  /// The controls a card's look allows, in the strip's order: Collapse while it can get smaller, Open out once it's
  /// not full (a round has no strip: a tap opens it out), Archive, and Thinking on an open card.
  public static func controls(_ card: WhiteboardQuestion) -> [WhiteboardQuestion.Control] {
    guard card.look != .round else { return [] }
    var out: [WhiteboardQuestion.Control] = [.collapse]
    if card.look != .full { out.append(.openOut) }
    out.append(.archive)
    if card.answered == nil { out.append(.thinking) }
    return out
  }

  /// Where the strip's first icon's top-left is, in board points: just past a full card's right end, top-aligned, the
  /// same in every look so the icons never move.
  public static func strip(_ card: WhiteboardQuestion) -> CGPoint {
    CGPoint(x: card.x + width + 8, y: card.y)
  }
}
