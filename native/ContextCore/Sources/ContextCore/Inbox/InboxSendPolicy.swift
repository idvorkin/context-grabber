//  #406, story 269: wait for a network, and coalesce requests made while a send is out.

public struct InboxSendPolicy: Sendable {
  public enum Path: Equatable, Sendable {
    case unknown, offline, online
  }

  public enum Decision: Equatable, Sendable {
    case wait, offlineSkipped, send, sendAgain
  }

  public private(set) var path: Path = .unknown
  public private(set) var retryAfter: Double?
  private var interfaces: Set<String> = []
  private var expensive = false
  private var constrained = false
  private var failed = false
  /// #565: steps up the backoff ladder since the last send that got through.
  public private(set) var failedInARow = 0
  private var sendOut = false
  private var changedDuringSend = false

  public init() {}

  /// A changed route after failure may restore the tailnet even when the phone stayed online.
  public mutating func updatePath(
    _ path: Path, interfaces: Set<String> = [], expensive: Bool = false, constrained: Bool = false,
    waitingCount: Int = 0, now: Double = 0
  ) -> Bool {
    let becameOnline = self.path != .online && path == .online
    let changed = self.interfaces != interfaces || self.expensive != expensive || self.constrained != constrained
    self.path = path
    self.interfaces = interfaces
    self.expensive = expensive
    self.constrained = constrained
    if path != .online || becameOnline || waitingCount == 0 {
      retryAfter = nil
      changedDuringSend = false
    } else if changed && failed {
      retryAfter = now + 0.5
    } else if changed && sendOut {
      changedDuringSend = true
    }
    return becameOnline
  }

  public mutating func startedSend() {
    sendOut = true
    changedDuringSend = false
  }

  /// A meaningful change seen while the failed send was out arms the same retry a later change would.
  /// `scheduled`: the send was the backoff's own try. Only those (and the first failure) step the wait, so sends Igor
  /// starts meanwhile do not stretch it (#565 review).
  public mutating func finishedSend(retry: Bool, now: Double = 0, scheduled: Bool = false) {
    failed = retry
    failedInARow = !retry ? 0 : (failedInARow == 0 || scheduled ? failedInARow + 1 : failedInARow)
    if !retry {
      retryAfter = nil
    } else if changedDuringSend && path == .online {
      retryAfter = now + 0.5
    }
    sendOut = false
    changedDuringSend = false
  }

  /// Consume one retry only after meaningful updates have settled; identical updates do not extend the wait.
  public mutating func pathRetryDecision(waitingCount: Int, sending: Bool, now: Double) -> Decision {
    guard let retryAfter, now >= retryAfter else { return .wait }
    self.retryAfter = nil
    guard failed, path == .online else { return .wait }
    return decision(waitingCount: waitingCount, sending: sending)
  }

  /// #565: how long after a failed send to try again on its own: 30 s, doubling to 5 min; nil when the last send got
  /// through or the phone is not online (the network's return sends instead).
  public var backoffDelay: Double? {
    guard failed, failedInARow > 0, path == .online else { return nil }
    return min(30 * Double(1 << min(failedInARow - 1, 4)), 300)
  }

  public func decision(waitingCount: Int, sending: Bool) -> Decision {
    guard waitingCount > 0 else { return .wait }
    switch path {
    case .unknown: return .wait
    case .offline: return .offlineSkipped
    case .online: return sending ? .sendAgain : .send
    }
  }
}
