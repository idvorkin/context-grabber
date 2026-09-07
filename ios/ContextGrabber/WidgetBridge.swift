import Foundation
import WidgetKit

/// Thin RN bridge for writing today's snapshot to the shared App Group
/// UserDefaults suite that TodayWidget reads. After writing, we kick
/// WidgetCenter so iOS refreshes the widget instead of waiting for its
/// next scheduled timeline refresh.
@objc(WidgetBridge)
class WidgetBridge: NSObject {

  private static let suite = "group.com.idvorkin.contextgrabber"

  @objc
  static func requiresMainQueueSetup() -> Bool { false }

  @objc(writeSnapshot:resolver:rejecter:)
  func writeSnapshot(
    _ payload: NSDictionary,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    guard let defaults = UserDefaults(suiteName: WidgetBridge.suite) else {
      reject("no_suite", "Could not open UserDefaults suite \(WidgetBridge.suite)", nil)
      return
    }
    // NSNull / missing keys leave the prior value alone rather than clobbering with nil.
    if let steps = payload["steps"] as? NSNumber {
      defaults.set(steps.intValue, forKey: "steps")
    }
    if let sleep = payload["sleepHours"] as? NSNumber {
      defaults.set(sleep.doubleValue, forKey: "sleepHours")
    }
    if let ex = payload["exerciseMinutes"] as? NSNumber {
      defaults.set(ex.intValue, forKey: "exerciseMinutes")
    }
    if let ts = payload["grabbedAt"] as? NSNumber {
      defaults.set(ts.doubleValue, forKey: "grabbedAt")
    }
    if let counter = payload["counter"] as? NSNumber {
      defaults.set(counter.intValue, forKey: "counter")
    }
    if let counterDate = payload["counterDate"] as? String {
      defaults.set(counterDate, forKey: "counterDate")
    }
    // Reflect tally — three small ints. Written whenever the journal
    // state on the JS side changes (entry saved, journal modal closed,
    // sync pulled). Read by TodayWidget to render the Reflect strip.
    if let opp = payload["reflectOpportunity"] as? NSNumber {
      defaults.set(opp.intValue, forKey: "reflectOpportunity")
    }
    if let did = payload["reflectDidIt"] as? NSNumber {
      defaults.set(did.intValue, forKey: "reflectDidIt")
    }
    if let grateful = payload["reflectGrateful"] as? NSNumber {
      defaults.set(grateful.intValue, forKey: "reflectGrateful")
    }
    if let reflectDate = payload["reflectDate"] as? String {
      defaults.set(reflectDate, forKey: "reflectDate")
    }

    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    resolve(nil)
  }

  /// Read whichever values the App Group currently holds. Used by the app on
  /// foreground/launch to reconcile widget-side counter increments back into
  /// the SQLite source of truth.
  @objc(readSnapshot:rejecter:)
  func readSnapshot(
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    guard let defaults = UserDefaults(suiteName: WidgetBridge.suite) else {
      reject("no_suite", "Could not open UserDefaults suite \(WidgetBridge.suite)", nil)
      return
    }
    let result: [String: Any] = [
      "counter": defaults.object(forKey: "counter") as? Int as Any,
      "counterDate": defaults.string(forKey: "counterDate") as Any,
    ]
    resolve(result)
  }

  // MARK: - The memdeck card
  // The same deal the widgets make (PlayingCard.swift is compiled into both
  // targets). Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md

  private func payload(_ card: PlayingCard) -> [String: Any] {
    ["label": card.label, "rank": card.rank, "suit": card.suit.rawValue, "isRed": card.isRed]
  }

  /// The card the widgets show right now.
  @objc(currentCard:rejecter:)
  func currentCard(resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    resolve(payload(CardDeal.card(at: Date(), nonce: DealStore.nonce())))
  }

  /// Deal a new card — what a tap on the big widget does — and hand it back.
  /// Does not redraw the widgets: the app's card screen deals every ten
  /// seconds in its drill, and iOS gives an app a few dozen widget refreshes a
  /// day; the screen syncs them once, when it closes.
  @objc(dealCard:rejecter:)
  func dealCard(resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    let now = Date()
    let nonce = CardDeal.nonceAfterTap(at: now, nonce: DealStore.nonce())
    DealStore.set(nonce)
    resolve(payload(CardDeal.card(at: now, nonce: nonce)))
  }

  /// Bring the widgets in line with the last deal.
  @objc(syncCardWidgets:rejecter:)
  func syncCardWidgets(resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
    resolve(nil)
  }
}
