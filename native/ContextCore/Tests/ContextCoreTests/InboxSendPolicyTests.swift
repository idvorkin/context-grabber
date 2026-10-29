//  #406, story 269: no offline send, one network-back request, and no overlapping sends.

import XCTest

@testable import ContextCore

final class InboxSendPolicyTests: XCTestCase {
  func testLaunchWaitsForTheFirstPathReading() {
    var policy = InboxSendPolicy()
    XCTAssertEqual(policy.decision(waitingCount: 2, sending: false), .wait)
    XCTAssertTrue(policy.updatePath(.online))
    XCTAssertEqual(policy.decision(waitingCount: 2, sending: false), .send)
  }

  func testOfflineSkipsEvenWhenASendIsAlreadyOut() {
    var policy = InboxSendPolicy()
    XCTAssertFalse(policy.updatePath(.offline))
    for sending in [false, true] {
      XCTAssertEqual(policy.decision(waitingCount: 2, sending: sending), .offlineSkipped)
    }
  }

  func testNetworkReturnRequestsOnlyOneSendUntilItGoesOfflineAgain() {
    var policy = InboxSendPolicy()
    XCTAssertFalse(policy.updatePath(.offline))
    XCTAssertTrue(policy.updatePath(.online))
    XCTAssertEqual(policy.decision(waitingCount: 3, sending: false), .send)
    XCTAssertFalse(policy.updatePath(.online))
    XCTAssertFalse(policy.updatePath(.online))
    XCTAssertFalse(policy.updatePath(.offline))
    XCTAssertTrue(policy.updatePath(.online))
  }

  func testReturnDuringASendRequestsAnotherPassWhichChecksThePathAgain() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.offline)
    XCTAssertTrue(policy.updatePath(.online))
    XCTAssertEqual(policy.decision(waitingCount: 2, sending: true), .sendAgain)
    XCTAssertEqual(policy.decision(waitingCount: 3, sending: true), .sendAgain)
    XCTAssertEqual(policy.decision(waitingCount: 1, sending: false), .send)
    _ = policy.updatePath(.offline)
    XCTAssertEqual(policy.decision(waitingCount: 1, sending: false), .offlineSkipped)
  }

  func testNothingWaitingNeverRequestsASend() {
    var policy = InboxSendPolicy()
    for path: InboxSendPolicy.Path in [.unknown, .offline, .online] {
      _ = policy.updatePath(path)
      for sending in [false, true] {
        XCTAssertEqual(policy.decision(waitingCount: 0, sending: sending), .wait)
      }
    }
  }

  func testSatisfiedPathWithANewTunnelRetriesAfterFailure() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online, interfaces: ["en0"])
    policy.finishedSend(retry: true)
    XCTAssertFalse(policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 2, now: 10))
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 2, sending: false, now: 10.4), .wait)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 2, sending: false, now: 10.5), .send)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 2, sending: false, now: 11), .wait)
  }

  func testIdenticalUpdatesNeitherRetryNorExtendTheDebounce() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online, interfaces: ["en0"])
    policy.finishedSend(retry: true)
    _ = policy.updatePath(.online, interfaces: ["en0"], waitingCount: 1, now: 1)
    XCTAssertNil(policy.retryAfter)
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 1, now: 2)
    _ = policy.updatePath(.online, interfaces: ["utun4", "en0"], waitingCount: 1, now: 2.4)
    XCTAssertEqual(policy.retryAfter, 2.5)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 2.5), .send)
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 1, now: 3)
    XCTAssertNil(policy.retryAfter)
  }

  func testMeaningfulBurstSettlesIntoOneGuardedRetry() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online, interfaces: ["en0"])
    policy.finishedSend(retry: true)
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 1, now: 2)
    _ = policy.updatePath(.online, interfaces: ["en0", "utun5"], expensive: true, waitingCount: 1, now: 2.2)
    _ = policy.updatePath(
      .online, interfaces: ["en0", "utun5"], expensive: true, constrained: true, waitingCount: 1, now: 2.4)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: true, now: 2.8), .wait)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: true, now: 3), .sendAgain)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 4), .wait)
  }

  func testPathChangesDoNotRetryWithoutWaitingItemsOrAFailure() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online)
    _ = policy.updatePath(.online, interfaces: ["en0"], waitingCount: 1, now: 1)
    XCTAssertNil(policy.retryAfter)
    policy.finishedSend(retry: true)
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 0, now: 2)
    XCTAssertNil(policy.retryAfter)
    _ = policy.updatePath(.online, interfaces: ["en0"], waitingCount: 1, now: 3)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 0, sending: false, now: 4), .wait)
  }

  func testOfflineOrSuccessfulSendCancelsAPendingPathRetry() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online)
    policy.finishedSend(retry: true)
    _ = policy.updatePath(.online, expensive: true, waitingCount: 1, now: 1)
    _ = policy.updatePath(.offline, waitingCount: 1, now: 1.1)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 2), .wait)
    _ = policy.updatePath(.online)
    _ = policy.updatePath(.online, constrained: true, waitingCount: 1, now: 3)
    XCTAssertNotNil(policy.retryAfter)
    policy.finishedSend(retry: false)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 4), .wait)
  }

  func testTunnelReturningDuringASendThatFailsRetriesOnce() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online, interfaces: ["en0"])
    policy.startedSend()
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 1, now: 5)
    XCTAssertNil(policy.retryAfter)
    policy.finishedSend(retry: true, now: 20)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 20.4), .wait)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 20.5), .send)
    XCTAssertEqual(policy.pathRetryDecision(waitingCount: 1, sending: false, now: 21), .wait)
  }

  func testAFailedSendWithoutAChangeWhileOutDoesNotRetry() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online, interfaces: ["en0"])
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 1, now: 1)
    policy.startedSend()
    _ = policy.updatePath(.online, interfaces: ["en0", "utun4"], waitingCount: 1, now: 2)
    policy.finishedSend(retry: true, now: 3)
    XCTAssertNil(policy.retryAfter)
    policy.startedSend()
    _ = policy.updatePath(.online, interfaces: ["en0"], waitingCount: 1, now: 4)
    _ = policy.updatePath(.offline, waitingCount: 1, now: 4.1)
    _ = policy.updatePath(.online, interfaces: ["en0"], waitingCount: 1, now: 4.2)
    policy.finishedSend(retry: true, now: 5)
    XCTAssertNil(policy.retryAfter)
  }

  // MARK: #565, a failed send tried again on its own

  func testAFailedSendBacksOffFrom30SecondsDoublingToFiveMinutes() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online)
    XCTAssertNil(policy.backoffDelay, "nothing failed yet")
    var delays: [Double] = []
    for _ in 0..<7 {
      policy.startedSend()
      policy.finishedSend(retry: true, scheduled: true)
      delays.append(policy.backoffDelay ?? -1)
    }
    XCTAssertEqual(delays, [30, 60, 120, 240, 300, 300, 300])
  }

  func testASendThatGetsThroughStartsTheWaitOver() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online)
    for _ in 0..<3 { policy.finishedSend(retry: true, scheduled: true) }
    policy.finishedSend(retry: false)
    XCTAssertNil(policy.backoffDelay)
    policy.finishedSend(retry: true)
    XCTAssertEqual(policy.backoffDelay, 30)
  }

  func testSendsIgorStartsDoNotStretchTheWaitAndAnUnknownPathHasNone() {
    var policy = InboxSendPolicy()
    policy.finishedSend(retry: true)
    XCTAssertNil(policy.backoffDelay, "no path reading yet")
    _ = policy.updatePath(.online)
    for _ in 0..<3 { policy.finishedSend(retry: true) }
    XCTAssertEqual(policy.backoffDelay, 30, "composes and foregrounds while away keep the first step")
    policy.finishedSend(retry: true, scheduled: true)
    XCTAssertEqual(policy.backoffDelay, 60)
  }

  func testOfflineHasNoBackoffTheNetworksReturnSendsInstead() {
    var policy = InboxSendPolicy()
    _ = policy.updatePath(.online)
    policy.finishedSend(retry: true)
    _ = policy.updatePath(.offline)
    XCTAssertNil(policy.backoffDelay)
  }
}
