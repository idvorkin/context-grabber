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
}
