//  The memdeck tap count (story 129), in the App Group so a widget deals the card the card screen last dealt.
//  Compiled into both: the app writes, the widget extension reads.

import Foundation
import WidgetKit

enum CardStore {
  /// The large widget, Today's hand (#221).
  static let kind = "TodaysHand"
  private static let key = "memdeck_nonce"

  static func nonce() -> Int {
    UserDefaults(suiteName: UsageTileStore.group)?.integer(forKey: key) ?? 0
  }

  static func set(_ nonce: Int) {
    UserDefaults(suiteName: UsageTileStore.group)?.set(nonce, forKey: key)
  }

  static func reloadWidget() {
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
  }
}
