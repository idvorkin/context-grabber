//  The memdeck card screen's state (story 129, 133): a fresh card on every open, another on a tap, and *Think of a
//  card* — face down for a count of five, then a new card. The deal is ContextCore's `CardDeal`; the tap count lives
//  in the settings table until the widgets step gives the native app the old app's shared one.

import ContextCore
import Foundation

@MainActor
final class CardModel: ObservableObject {
  static let nonceKey = "memdeck_deal_nonce"

  @Published private(set) var card: PlayingCard
  @Published private(set) var thinking = false
  /// The number on the back while thinking.
  @Published private(set) var left = ThinkCount.seconds

  private let log: SessionLog
  private let database: AppDatabase
  private var nonce: Int
  private var count: Task<Void, Never>?
  private var thinkStarted = Date()

  init(log: SessionLog, database: AppDatabase) {
    self.log = log
    self.database = database
    nonce = Int(database.setting(Self.nonceKey) ?? "") ?? 0
    card = CardDeal.card(at: Date(), nonce: nonce)
    // Every open deals (the screen makes a model per open): never the card the last visit was showing.
    deal(how: "open")
  }

  func appear(think: Bool, neverMindAfter: Duration? = nil) {
    guard think else { return }
    startThinking(from: "hook")
    if let neverMindAfter {
      Task {
        try? await Task.sleep(for: neverMindAfter)
        if thinking { toggleThinking() }
      }
    }
  }

  func disappear() {
    if thinking { stopThinking(why: "left") }
  }

  func tapCard() {
    guard !thinking else { return }
    deal(how: "tap")
  }

  /// The one button: *Think of a card*, or *Never mind* while the count runs.
  func toggleThinking() {
    if thinking { stopThinking(why: "never_mind") } else { startThinking(from: "button") }
  }

  // MARK: -

  private func deal(how: String) {
    let dealt = CardDeal.deal(at: Date(), nonce: nonce)
    nonce = dealt.nonce
    card = dealt.card
    database.setSetting(Self.nonceKey, String(nonce))
    log.event("card_deal", ["card": card.label, "how": how, "nonce": nonce])
  }

  private func startThinking(from source: String) {
    let started = Date()
    thinkStarted = started
    thinking = true
    left = ThinkCount.seconds
    log.event("card_think", ["action": "start", "from": source, "showing": card.label])
    // The count is read from the clock, so a trip to the background ends it on time rather than late.
    count = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        guard let self, !Task.isCancelled else { return }
        let n = ThinkCount.left(elapsed: Date().timeIntervalSince(started))
        if n != self.left { self.left = n }
        if n == 0 {
          self.count = nil
          self.thinking = false
          self.deal(how: "think")
          self.log.event("card_think", ["action": "done", "card": self.card.label])
          return
        }
      }
    }
  }

  private func stopThinking(why: String) {
    count?.cancel()
    count = nil
    thinking = false
    let left = ThinkCount.left(elapsed: Date().timeIntervalSince(thinkStarted))  // the clock's, not the last tick's
    log.event("card_think", ["action": "cancel", "why": why, "left": left, "card": card.label])
  }
}
