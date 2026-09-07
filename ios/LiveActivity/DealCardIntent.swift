import Foundation

#if canImport(AppIntents)
import AppIntents
import WidgetKit

/// In-widget tap on the memdeck card: deal a different card, on every surface,
/// without launching the app. Bumps the shared tap count until the card in
/// hand changes (`CardDeal.nonceAfterTap`), then asks WidgetKit to redraw the
/// *other* card-carrying widget — the tapped one WidgetKit reloads itself once
/// this returns, and asking twice put a second timeline fetch on the tap's
/// critical path.
/// Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
///
/// iOS 17+ only — before that the card is not tappable in place and the
/// widget's own link (open the app) is what a tap does.
@available(iOS 17.0, *)
struct DealCardIntent: AppIntent {
  static var title: LocalizedStringResource = "Deal a new card"
  static var description = IntentDescription("Show a different random card on the memdeck widgets.")
  static var openAppWhenRun: Bool = false
  /// Widget-only; not a Shortcuts action.
  static var isDiscoverable: Bool = false

  /// The widget the tap came from (its `kind`).
  @Parameter(title: "Widget") var kind: String

  init() { kind = "" }
  init(from kind: String) { self.kind = kind }

  func perform() async throws -> some IntentResult {
    DealStore.set(CardDeal.nonceAfterTap(at: Date(), nonce: DealStore.nonce()))
    for other in [TodayWidget.kind, MemdeckCardWidget.kind] where other != kind {
      WidgetCenter.shared.reloadTimelines(ofKind: other)
    }
    return .result()
  }
}
#endif
