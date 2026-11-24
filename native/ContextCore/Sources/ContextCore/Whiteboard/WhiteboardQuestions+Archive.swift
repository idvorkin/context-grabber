//  Question cards archive and think over (spec 2026-11-16-whiteboard-question-cards-design.md, *Archiving a card* and
//  *Thinking it over*; stories 1314–1317, #1387): a card archived off the board, the archive newest first, a card
//  reopened where it was, as it was, and an open card marked as being thought over. Its conversation's requests are in
//  Cockpit/BoardRequests.swift, outside BoardCore.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

extension WhiteboardQuestions {
  /// The archived cards, newest archived first.
  public var archived: [WhiteboardQuestion] {
    cards.filter { $0.archived != nil }.sorted { ($0.archived ?? 0) > ($1.archived ?? 0) }
  }

  /// Story 1314: a card on the board archived at `at` (UTC ms). Nothing is answered. False for none, or one already
  /// archived.
  @discardableResult
  public mutating func archive(_ id: String, at: Int64) -> Bool {
    guard let i = cards.firstIndex(where: { $0.id == id && $0.archived == nil }) else { return false }
    cards[i].archived = at
    return true
  }

  /// Story 1315: an archived card back on the board where it was, as it was. False for none, or one not archived.
  @discardableResult
  public mutating func reopen(_ id: String) -> Bool {
    guard let i = cards.firstIndex(where: { $0.id == id && $0.archived != nil }) else { return false }
    cards[i].archived = nil
    return true
  }

  /// Story 1316: an open card being thought over with Larry. False for an answered card, or none.
  @discardableResult
  public mutating func think(_ id: String) -> Bool {
    guard let i = cards.firstIndex(where: { $0.id == id && $0.answered == nil }) else { return false }
    cards[i].thinking = true
    return true
  }
}
