//  The phone side of ContextCore's SessionHost, for the Gym Timer and breathing: the run loop's clock, the main
//  queue's one-shot timers, the idle timer, the one Live Activity, VoiceOver and the session log. It decides nothing;
//  TimerSession and BreathSession say when.

import ContextCore
import UIKit

@MainActor
final class AppSessionHost: @preconcurrency SessionHost {
  private let log: SessionLog
  private let liveActivity: LiveActivityController
  private var clock: Timer?

  init(log: SessionLog, liveActivity: LiveActivityController) {
    self.log = log
    self.liveActivity = liveActivity
  }

  var now: Double { Date().timeIntervalSince1970 }

  func startClock(every seconds: Double, _ look: @escaping () -> Void) {
    clock?.invalidate()
    // In the common modes: a finger dragging the lap list or the accessory sheet must not stop the clock.
    let timer = Timer(timeInterval: seconds, repeats: true) { _ in
      MainActor.assumeIsolated { look() }
    }
    RunLoop.main.add(timer, forMode: .common)
    clock = timer
  }

  func stopClock() {
    clock?.invalidate()
    clock = nil
  }

  func after(_ ms: Int, _ block: @escaping () -> Void) -> () -> Void {
    let item = DispatchWorkItem(block: block)
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms), execute: item)
    return { item.cancel() }
  }

  var keepAwake: Bool {
    get { UIApplication.shared.isIdleTimerDisabled }
    set { UIApplication.shared.isIdleTimerDisabled = newValue }
  }

  func syncCard(_ content: LiveActivityContent?, kind: LiveActivityKind, stepEndsAt: Double?) {
    liveActivity.sync(content, kind: kind, stepEndsAt: stepEndsAt)
  }

  func endCard(_ kind: LiveActivityKind, reason: String) {
    liveActivity.end(kind, reason: reason)
  }

  func announce(_ text: String) {
    guard UIAccessibility.isVoiceOverRunning else { return }
    UIAccessibility.post(notification: .announcement, argument: text)
  }

  func log(_ type: String, _ fields: [String: Any]) {
    log.event(type, fields)
  }
}
