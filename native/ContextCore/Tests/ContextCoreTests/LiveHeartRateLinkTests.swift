import XCTest

@testable import ContextCore

/// Stories 1088-1089 (context-grabber-at59): Exercise Analyzer's live heart rate, started when a call goes live and
/// ended when it ends, behind *Live heart rate on calls*.
final class LiveHeartRateLinkTests: XCTestCase {
  func testTheStartLinkAsksForACallSessionAndComesBack() throws {
    let url = try XCTUnwrap(LiveHeartRateLink.url(for: .start))
    let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(parts.scheme, "exerciseanalyzer")
    XCTAssertEqual(parts.host, "live-heart-rate")
    XCTAssertEqual(parts.path, "/start")
    let items = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    XCTAssertEqual(items["kind"], "call")
    XCTAssertEqual(items["x-success"], "grabbernative://live-heart-rate/ok?action=start")
    XCTAssertEqual(items["x-error"], "grabbernative://live-heart-rate/error?action=start")
  }

  func testTheEndLinkHasNoKind() throws {
    let url = try XCTUnwrap(LiveHeartRateLink.url(for: .end))
    let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(parts.path, "/end")
    let names = (parts.queryItems ?? []).map(\.name)
    XCTAssertFalse(names.contains("kind"))
    XCTAssertTrue(names.contains("x-success"))
    XCTAssertTrue(names.contains("x-error"))
  }

  func testCallbacksAreRead() throws {
    let ok = try XCTUnwrap(URL(string: "grabbernative://live-heart-rate/ok?action=start"))
    XCTAssertEqual(LiveHeartRateLink.callback(ok), .ok(.start))
    let bad = try XCTUnwrap(
      URL(
        string: "grabbernative://live-heart-rate/error?action=end&errorMessage=No%20live%20heart%20rate%20is%20running")
    )
    XCTAssertEqual(LiveHeartRateLink.callback(bad), .error(.end, "No live heart rate is running"))
    let other = try XCTUnwrap(URL(string: "grabbernative://call"))
    XCTAssertNil(LiveHeartRateLink.callback(other))
  }

  func testAnErrorWithoutAMessageStillSaysSomething() throws {
    let bad = try XCTUnwrap(URL(string: "grabbernative://live-heart-rate/error?action=start"))
    guard case .error(.start, let reason) = LiveHeartRateLink.callback(bad) else { return XCTFail("not an error") }
    XCTAssertFalse(reason.isEmpty)
  }

  func testSwitchOffAsksNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: false))
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: false))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: false))
  }

  func testALiveCallStartsOnceAndItsEndEndsOnce() {
    var plan = LiveHeartRatePlan()
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true))
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: true), .end)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true))
  }

  func testARedialDoesNotAskAgain() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: true, enabled: true))
    XCTAssertTrue(plan.inCall)
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true))
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: true), .end)
  }

  func testARedialAfterAFailedStartDoesNotAskAgain() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    plan.startFailed()
    XCTAssertNil(plan.next(state: .ended, redialing: true, enabled: true))
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true))
  }

  func testANewCallIsNotInTheLastOne() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: true), .end)
    XCTAssertFalse(plan.inCall)
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertFalse(plan.inCall)
  }

  func testACallThatNeverWentLiveEndsNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true))
  }

  func testTheNextCallStartsAgain() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: true), .end)
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
  }

  func testTurningTheSwitchOffMidCallStillEndsWhatWasStarted() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: false), .end)
  }

  func testAStartThatFailedEndsNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    plan.startFailed()
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true))
  }

  func testAStartThatFailedStillLetsTheNextCallStart() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    plan.startFailed()
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true))
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true))
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: true), .end)
  }

  func testAStartWithNoAnswerYetIsStillEnded() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true), .start)
    XCTAssertEqual(plan.next(state: .ended, redialing: false, enabled: true), .end)
  }
}
