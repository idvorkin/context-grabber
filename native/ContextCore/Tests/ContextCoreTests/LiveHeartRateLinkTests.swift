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

  private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

  func testSwitchOffAsksNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: false, now: at(0)))
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: false, now: at(1)))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: false, now: at(2)))
    XCTAssertNil(plan.endDue(now: at(7)))
  }

  func testALiveCallStartsOnceAndItsEndEndsOnceFiveSecondsLater() {
    var plan = LiveHeartRatePlan()
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(0)))
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(1)), .start)
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true, now: at(2)))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(10)))
    XCTAssertNil(plan.endDue(now: at(14)))
    XCTAssertEqual(plan.endDue(now: at(15)), .end)
    XCTAssertNil(plan.endDue(now: at(20)))
  }

  func testAHandoffRedialDoesNotAskAgain() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: true, enabled: true, now: at(10)))
    XCTAssertTrue(plan.inCall)
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(30)))
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true, now: at(31)))
    XCTAssertNil(plan.endDue(now: at(40)))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(50)))
    XCTAssertEqual(plan.endDue(now: at(55)), .end)
  }

  func testAHangUpAndDialAgainWithinFiveSecondsIsTheSameCall() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(10)))
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(10)))
    XCTAssertTrue(plan.inCall)
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true, now: at(12)))
    XCTAssertNil(plan.endDue(now: at(15)))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(60)))
    XCTAssertEqual(plan.endDue(now: at(65)), .end)
  }

  func testARedialAfterAFailedStartDoesNotAskAgain() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertTrue(plan.startAnswered(failed: true))
    XCTAssertNil(plan.next(state: .ended, redialing: true, enabled: true, now: at(10)))
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(10)))
    XCTAssertNil(plan.next(state: .live, redialing: false, enabled: true, now: at(11)))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(20)))
    XCTAssertNil(plan.endDue(now: at(25)))
  }

  func testACallThatNeverWentLiveEndsNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(0)))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(1)))
    XCTAssertNil(plan.endDue(now: at(6)))
    XCTAssertFalse(plan.inCall)
  }

  func testTheNextCallStartsAgain() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(10)))
    XCTAssertEqual(plan.endDue(now: at(15)), .end)
    XCTAssertFalse(plan.inCall)
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(60)))
    XCTAssertFalse(plan.inCall)
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(61)), .start)
  }

  func testANewCallAfterTheWaitEndsTheLastOneEvenBeforeItsTimer() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(10)))
    XCTAssertEqual(plan.next(state: .connecting, redialing: false, enabled: true, now: at(30)), .end)
    XCTAssertFalse(plan.inCall)
    XCTAssertNil(plan.endDue(now: at(31)))
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(31)), .start)
  }

  func testTurningTheSwitchOffMidCallStillEndsWhatWasStarted() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: false, now: at(10)))
    XCTAssertEqual(plan.endDue(now: at(15)), .end)
  }

  func testAStartThatFailedEndsNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertTrue(plan.startAnswered(failed: true))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(10)))
    XCTAssertNil(plan.endDue(now: at(15)))
  }

  func testAStartWithNoAnswerYetIsStillEnded() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(10)))
    XCTAssertEqual(plan.endDue(now: at(15)), .end)
  }

  func testALateStartAnswerFromTheLastCallChangesNothing() {
    var plan = LiveHeartRatePlan()
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(0)), .start)
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(1)))
    XCTAssertEqual(plan.endDue(now: at(6)), .end)
    XCTAssertFalse(plan.startAnswered(failed: true))
    XCTAssertNil(plan.next(state: .connecting, redialing: false, enabled: true, now: at(7)))
    XCTAssertEqual(plan.next(state: .live, redialing: false, enabled: true, now: at(8)), .start)
    XCTAssertTrue(plan.startAnswered(failed: false))
    XCTAssertFalse(plan.startAnswered(failed: true))
    XCTAssertNil(plan.next(state: .ended, redialing: false, enabled: true, now: at(20)))
    XCTAssertEqual(plan.endDue(now: at(25)), .end)
  }
}
