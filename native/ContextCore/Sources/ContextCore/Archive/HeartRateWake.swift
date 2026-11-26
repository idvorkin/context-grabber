//  context-grabber-jimz: Health wakes the app when new heart rate, resting heart rate or HRV is saved, and the app
//  sends it to the Cockpit's archive then instead of waiting for the four-hourly run. Health can't be read while the
//  phone is locked, which is when most samples land (the Watch syncs to a phone in a pocket), so a locked wake waits,
//  kept across a suspension, for the next time the app runs with the phone unlocked. Wakes close together share one run. Spec: the stats archive design, "Heart rate as it comes".

import Foundation

public struct HeartRateWake: Equatable, Sendable {
  public enum Decision: String, Equatable, Sendable {
    /// Send now.
    case run
    /// Locked: send the next time the app runs unlocked.
    case waitForUnlock = "wait_for_unlock"
    /// A run just went, or one is going: this wake rides on it.
    case tooSoon = "too_soon"
  }

  /// The least time between two heart-rate runs: a Watch that syncs a burst wakes the app once per type.
  public static let minimumGapMs: Int64 = 60_000

  public private(set) var lastRunAtMs: Int64?
  public private(set) var waitingForUnlock = false

  /// `waitingForUnlock` as kept from before a suspension or relaunch.
  public init(waitingForUnlock: Bool = false) {
    self.waitingForUnlock = waitingForUnlock
  }

  /// A wake from Health at `nowMs`.
  public mutating func wake(nowMs: Int64, unlocked: Bool) -> Decision {
    guard unlocked else {
      waitingForUnlock = true
      return .waitForUnlock
    }
    if let last = lastRunAtMs, nowMs - last < Self.minimumGapMs { return .tooSoon }
    lastRunAtMs = nowMs
    waitingForUnlock = false
    return .run
  }

  /// The app is running (an unlock, a launch, the foreground): a run when it is unlocked and a locked wake waited.
  public mutating func flush(nowMs: Int64, unlocked: Bool) -> Bool {
    guard unlocked, waitingForUnlock else { return false }
    waitingForUnlock = false
    lastRunAtMs = nowMs
    return true
  }
}
