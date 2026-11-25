//  context-grabber-jimz: Health wakes the app when new heart rate, resting heart rate or HRV is saved, and the app
//  sends it to the Cockpit's archive then instead of waiting for the four-hourly run. Health can't be read while the
//  phone is locked, which is when most samples land (the Watch syncs to a phone in a pocket), so a locked wake waits
//  for the next unlock. Wakes close together share one run. Spec: the stats archive design, "Heart rate as it comes".

import Foundation

public struct HeartRateWake: Equatable, Sendable {
  public enum Decision: String, Equatable, Sendable {
    /// Send now.
    case run
    /// Locked: send at the next unlock.
    case waitForUnlock = "wait_for_unlock"
    /// A run just went, or one is going: this wake rides on it.
    case tooSoon = "too_soon"
  }

  /// The least time between two heart-rate runs: a Watch that syncs a burst wakes the app once per type.
  public static let minimumGapMs: Int64 = 60_000

  public private(set) var lastRunAtMs: Int64?
  public private(set) var waitingForUnlock = false

  public init() {}

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

  /// The phone unlocked: a run when a locked wake was waiting for it.
  public mutating func unlocked(nowMs: Int64) -> Bool {
    guard waitingForUnlock else { return false }
    waitingForUnlock = false
    lastRunAtMs = nowMs
    return true
  }
}
