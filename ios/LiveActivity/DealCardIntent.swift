import Foundation

#if canImport(AppIntents)
import AppIntents
import WidgetKit

/// In-widget tap on the memdeck card: deal a different card, on every surface,
/// without launching the app. Bumps the shared tap count until the card in
/// hand changes (`CardDeal.nonceAfterTap`), then asks WidgetKit to redraw the
/// two card-carrying widgets.
/// Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
///
/// iOS 17+ only — before that the card is not tappable in place and the
/// widget's own link (open the app) is what a tap does.
@available(iOS 17.0, *)
struct DealCardIntent: AppIntent {
  static var title: LocalizedStringResource = "Deal a new card"
  static var description = IntentDescription("Show a different random card on the memdeck widgets.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult {
    DealStore.set(CardDeal.nonceAfterTap(at: Date(), nonce: DealStore.nonce()))
    WidgetCenter.shared.reloadTimelines(ofKind: "TodayWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "MemdeckCardWidget")
    return .result()
  }
}
#endif
