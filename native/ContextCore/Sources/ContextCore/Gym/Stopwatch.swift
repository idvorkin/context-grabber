//  The Gym Timer's stopwatch (story 110) and set counter (story 111): anchored to the caller's clock like the
//  rounds, so the display can redraw as often as it likes without owning the time.

import Foundation

public struct Stopwatch: Equatable, Sendable {
  /// The clock reading at which a zero stopwatch would have started; nil while stopped.
  private var anchor: Double?
  private var banked: Double = 0
  /// Lap times in milliseconds, newest first.
  public private(set) var laps: [Int] = []

  public init() {}

  public var isRunning: Bool { anchor != nil }

  public func elapsedMs(now: Double) -> Int {
    Int(((anchor.map { now - $0 } ?? 0) + banked) * 1000)
  }

  /// Stopped with time on it: the face says PAUSEd.
  public var isPaused: Bool { anchor == nil && banked > 0 }

  public mutating func toggle(now: Double) {
    if let anchor {
      banked += now - anchor
      self.anchor = nil
    } else {
      anchor = now
    }
  }

  public mutating func lap(now: Double) {
    guard isRunning else { return }
    laps.insert(elapsedMs(now: now), at: 0)
  }

  public mutating func reset() { self = Stopwatch() }

  /// "02:05" and ".37": minutes and seconds, then the hundredths the face draws smaller.
  public static func format(ms: Int) -> (main: String, fraction: String) {
    let total = ms / 1000
    return (String(format: "%02d:%02d", total / 60, total % 60), String(format: ".%02d", (ms % 1000) / 10))
  }
}

public enum SetCounter {
  public static let max = 15

  public static func clamp(_ count: Int) -> Int { Swift.min(max, Swift.max(0, count)) }

  /// Struck groups of five and the marks left over.
  public static func tally(_ count: Int) -> (groups: Int, remainder: Int) {
    let c = Swift.max(0, count)
    return (c / 5, c % 5)
  }
}
