//  Stories 1088-1089 (context-grabber-at59): *Live heart rate on calls*. The simulator has no Exercise Analyzer, so with
//  the switch on a live call says, in a quiet line under it, that live heart rate couldn't start, and stays live; with
//  it off nothing is asked and no line shows. A synthetic call (GRABBER_CALL_AUDIO=synthetic) never opens the mic.

import XCTest

final class CallLiveHeartRateUITests: XCTestCase {
  func testWithTheSwitchOnAMissingExerciseAnalyzerLeavesTheCallLiveWithANote() throws {
    let app = try launchCall(switchOn: true)
    let note = app.staticTexts["call-live-hr-note"]
    XCTAssertTrue(note.appears(within: 20), app.debugDescription)
    XCTAssertEqual(note.label, "Live heart rate couldn't start: Exercise Analyzer isn't installed.")
    XCTAssertTrue(
      app.staticTexts["call-status"].label.hasPrefix("live"), "the call carries on: \(app.debugDescription)")
    XCTAssertEqual(app.state, .runningForeground)
  }

  func testWithTheSwitchOffACallAsksNothing() throws {
    let app = try launchCall(switchOn: false)
    let status = app.staticTexts["call-status"]
    let live = expectation(for: NSPredicate(format: "label BEGINSWITH 'live'"), evaluatedWith: status)
    wait(for: [live], timeout: 20)
    sleep(2)
    XCTAssertFalse(app.staticTexts["call-live-hr-note"].exists, app.debugDescription)
  }

  private func launchCall(switchOn: Bool) throws -> XCUIApplication {
    guard let bridge = ProcessInfo.processInfo.environment["GRABBER_FAKE_BRIDGE"], !bridge.isEmpty else {
      throw XCTSkip("needs the fake bridge: run scripts/native/test-chat-ui.sh")
    }
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_CALL"] = bridge
    app.launchEnvironment["GRABBER_CALL_AUDIO"] = "synthetic"
    app.launchEnvironment["GRABBER_CALL_SECONDS"] = "120"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launchEnvironment["GRABBER_LIVE_HR_CALLS"] = switchOn ? "1" : "0"
    app.launch()
    XCTAssertTrue(app.staticTexts["call-status"].appears(within: 20), app.debugDescription)
    return app
  }
}
