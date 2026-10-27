import XCTest

@testable import ContextCore

/// #556, story 218: a Direct call names its speech-to-text in the start frame; Default and every other backend send
/// nothing, so the bridge keeps its own default.
final class CallSTTTests: XCTestCase {
  private func object(_ text: String) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] ?? [:]
  }

  func testTheValuesAreTheOnesTheBridgeAccepts() {
    // voice_bridge.py DIRECT_STT_CHOICES: "nova-3", "flux"; "" is the bridge default.
    XCTAssertEqual(CallSTT.allCases.map(\.rawValue), ["", "nova-3", "flux"])
    XCTAssertEqual(CallSTT.allCases.map(\.label), ["Default", "Nova-3", "Flux"])
    XCTAssertEqual(CallSTT.default, .bridgeDefault)
  }

  func testOnlyDirectHasAPick() {
    XCTAssertEqual(CallBackend.allCases.filter { CallSTT.hasPick($0) }, [.direct])
    XCTAssertFalse(CallSTT.hasPick(nil))
  }

  func testTheFrameFieldIsThePickOnDirectAndEmptyElsewhere() {
    XCTAssertEqual(CallSTT.flux.frameField(for: .direct), "flux")
    XCTAssertEqual(CallSTT.nova3.frameField(for: .direct), "nova-3")
    XCTAssertEqual(CallSTT.bridgeDefault.frameField(for: .direct), "")
    for backend in CallBackend.allCases where backend != .direct {
      XCTAssertEqual(CallSTT.flux.frameField(for: backend), "", backend.rawValue)
    }
  }

  func testTheStartFrameCarriesSttOnlyWhenNamed() {
    XCTAssertEqual(object(CallProtocol.startFrame(backend: .direct, stt: "flux"))["stt"] as? String, "flux")
    XCTAssertNil(object(CallProtocol.startFrame(backend: .direct))["stt"])
    XCTAssertNil(object(CallProtocol.startFrame(backend: .direct, stt: ""))["stt"])
  }

  func testADirectCallSendsItsPickAndLogsIt() {
    let t = CallHarness()
    t.session.start(.direct, stt: .flux)
    t.socket.open()
    XCTAssertEqual(t.socket.frames[0]["stt"] as? String, "flux")
    XCTAssertEqual(t.last("call_start")?["stt"] as? String, "flux")
    XCTAssertEqual(t.session.snapshot.stt, .flux)
  }

  func testADefaultDirectCallLeavesSttOut() {
    let t = CallHarness()
    t.session.start(.direct)
    t.socket.open()
    XCTAssertNil(t.socket.frames[0]["stt"])
    XCTAssertEqual(t.last("call_start")?["stt"] as? String, "")
  }

  func testAVoiceModelCallNeverSendsStt() {
    let t = CallHarness()
    t.session.start(.eleven, stt: .flux)
    t.socket.open()
    XCTAssertNil(t.socket.frames[0]["stt"])
    XCTAssertEqual(t.last("call_start")?["stt"] as? String, "")
  }

  func testRestartKeepsThePick() {
    let t = CallHarness()
    t.session.start(.direct, stt: .nova3)
    t.socket.open()
    t.socket.say(["type": "ready", "out_rate": 16000])
    let second = t.nextSocket()
    t.session.restart()
    second.open()
    XCTAssertEqual(second.frames[0]["stt"] as? String, "nova-3")
  }
}
