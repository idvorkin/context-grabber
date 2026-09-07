import Foundation

#if canImport(AppIntents)
import AppIntents
import WidgetKit

/// The tap on the big widget's memdeck card: deal a different card, on every
/// surface, without launching the app. Bumps the shared tap count until the
/// card in hand changes (`CardDeal.nonceAfterTap`), then asks WidgetKit to
/// redraw the lock-screen widget — the tapped Today widget WidgetKit reloads
/// itself once this returns, and asking for it too put a second timeline fetch
/// on the tap's critical path.
/// Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
///
/// iOS 17+ only — before that the card is not tappable in place and the
/// widget's own link (open the app) is what a tap does.
@available(iOS 17.0, *)
struct DealCardIntent: AppIntent {
  static var title: LocalizedStringResource = "Deal a new card"
  static var description = IntentDescription("Show a different random card on the memdeck widgets.")
  static var openAppWhenRun: Bool = false
  // Discoverable, like the +1: it shows in Shortcuts as "Deal a new card".

  func perform() async throws -> some IntentResult {
    DealStore.set(CardDeal.nonceAfterTap(at: Date(), nonce: DealStore.nonce()))
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.memdeckCard)
    return .result()
  }
}
#endif
