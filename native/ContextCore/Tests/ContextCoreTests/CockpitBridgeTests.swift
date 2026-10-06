//  The Cockpit bridge's wire format, ported from __tests__/audioBridge.test.ts and cockpitClient.test.ts. The
//  injected scripts ARE the wire format, so they are run in JavaScriptCore against a stand-in window.

import JavaScriptCore
import XCTest

@testable import ContextCore

private let mic = AudioDevice(id: "BuiltInMicrophoneBottom", name: "iPhone Microphone", type: "MicrophoneBuiltIn")
private let pods = AudioDevice(id: "AC:12:34:56:78:9A-tacl", name: "AirPods Pro", type: "BluetoothHFP")
private let snapshot = AudioRouteSnapshot(
  inputs: [mic, pods],
  outputs: [
    AudioDevice(id: "auto", name: "Automatic", type: "auto"),
    AudioDevice(id: "speaker", name: "Speaker", type: "Speaker"), pods,
  ],
  currentInput: mic, currentOutput: AudioDevice(id: "speaker", name: "Speaker", type: "Speaker"))

private func msg(_ object: Any) -> String {
  String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]), as: UTF8.self)
}

final class BridgeParseTests: XCTestCase {
  func testReadsABareListDevicesAndEchoesARequestId() {
    XCTAssertEqual(AudioBridge.parse(msg(["type": "audio.listDevices"])), .audio(.listDevices(requestId: nil)))
    XCTAssertEqual(
      AudioBridge.parse(msg(["type": "audio.getRoute", "requestId": "r1"])), .audio(.getRoute(requestId: "r1")))
  }

  func testDropsANonStringRequestId() {
    XCTAssertEqual(
      AudioBridge.parse(msg(["type": "audio.listDevices", "requestId": 7])), .audio(.listDevices(requestId: nil)))
  }

  func testEverySpellingOfSystemDefaultOnSetInputIsNil() {
    for raw: [String: Any] in [["type": "audio.setInput"], ["type": "audio.setInput", "id": NSNull()],
      ["type": "audio.setInput", "id": ""]]
    {
      XCTAssertEqual(AudioBridge.parse(msg(raw)), .audio(.setInput(id: nil, requestId: nil)))
    }
    XCTAssertEqual(
      AudioBridge.parse(msg(["type": "audio.setInput", "id": "mic-bt"])), .audio(.setInput(id: "mic-bt", requestId: nil)))
  }

  func testIdIsAnAliasOfPortAndSetOutputNeedsADestination() {
    XCTAssertEqual(
      AudioBridge.parse(msg(["type": "audio.setOutput", "id": "speaker"])),
      .audio(.setOutput(port: "speaker", requestId: nil)))
    XCTAssertEqual(
      AudioBridge.parse(msg(["type": "audio.setOutput", "port": "auto"])), .audio(.setOutput(port: "auto", requestId: nil)))
    XCTAssertNil(AudioBridge.parse(msg(["type": "audio.setOutput"])))
  }

  func testIgnoresTrafficThatIsNotOurs() {
    XCTAssertNil(AudioBridge.parse(msg(["type": "cockpit.decision"])))
    XCTAssertNil(AudioBridge.parse("not json at all"))
    XCTAssertNil(AudioBridge.parse(msg(["audio.listDevices"])))
    XCTAssertNil(AudioBridge.parse("null"))
    XCTAssertNil(AudioBridge.parse(""))
    XCTAssertNil(AudioBridge.parse(nil))
    XCTAssertNil(AudioBridge.parse(42))
  }

  func testCallStateNeedsARealBoolean() {
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.state", "live": true])), .callState(live: true))
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.state", "live": false])), .callState(live: false))
    XCTAssertNil(AudioBridge.parse(msg(["type": "call.state", "live": 1])))
    XCTAssertNil(AudioBridge.parse(msg(["type": "call.state"])))
  }

  func testCallControlKnownBackendOrNone() {
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.focus"])), .call(.focus))
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.start", "via": "eleven"])), .call(.start(via: .eleven)))
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.start", "backend": "gemini"])), .call(.start(via: .gemini)))
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.start", "via": "siri"])), .call(.start(via: nil)))
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.start"])), .call(.start(via: nil)))
    XCTAssertEqual(AudioBridge.parse(msg(["type": "call.start"]))?.kind, "call.start")
  }
}

final class BridgePayloadTests: XCTestCase {
  private func roundTrip(_ payload: [String: Any]) -> [String: Any] {
    let data = Data(AudioBridge.json(payload).utf8)
    return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
  }

  func testDevicesPayloadIsTheSnapshotWithATypeAndTheRequestId() {
    let payload = roundTrip(AudioBridge.devicesPayload(snapshot, requestId: "r9"))
    XCTAssertEqual(payload["type"] as? String, "audio.devices")
    XCTAssertEqual(payload["requestId"] as? String, "r9")
    let inputs = payload["inputs"] as! [[String: String]]
    XCTAssertEqual(inputs, [
      ["id": "BuiltInMicrophoneBottom", "name": "iPhone Microphone", "type": "MicrophoneBuiltIn"],
      ["id": "AC:12:34:56:78:9A-tacl", "name": "AirPods Pro", "type": "BluetoothHFP"],
    ])
    let current = payload["current"] as! [String: [String: String]]
    XCTAssertEqual(current["output"]?["id"], "speaker")
    XCTAssertEqual(
      payload["capabilities"] as? [String: Bool], ["selectInput": true, "selectOutput": true, "forceSpeaker": true])
  }

  func testFireAndForgetHasNoRequestIdAndANoneSideIsNull() {
    var empty = snapshot
    empty.currentInput = nil
    let payload = roundTrip(AudioBridge.devicesPayload(empty))
    XCTAssertNil(payload["requestId"])
    XCTAssertTrue((payload["current"] as! [String: Any])["input"] is NSNull)
  }

  func testRouteChangedCarriesTheReason() {
    let payload = roundTrip(AudioBridge.routeChangedPayload(snapshot, reason: "oldDeviceUnavailable"))
    XCTAssertEqual(payload["type"] as? String, "audio.routeChanged")
    XCTAssertEqual(payload["reason"] as? String, "oldDeviceUnavailable")
  }

  func testReadyAndErrorPayloads() {
    XCTAssertEqual(
      AudioBridge.json(AudioBridge.readyPayload(available: true)),
      #"{"available":true,"platform":"ios","type":"audio.ready","version":1}"#)
    XCTAssertEqual(
      AudioBridge.json(AudioBridge.errorPayload(op: "audio.setInput", message: "Input not available: x", requestId: "r3")),
      #"{"message":"Input not available: x","op":"audio.setInput","requestId":"r3","type":"audio.error"}"#)
    XCTAssertEqual(roundTrip(AudioBridge.errorPayload(op: "x", message: ""))["message"] as? String, "Unknown audio error")
  }
}

/// A stand-in page: `win` is the window, CustomEvent records type and detail, and the WebKit message handler (or a
/// React Native one) collects what the page posts.
private final class FakePage {
  let context = JSContext()!

  init(webkit: Bool = true, reactNative: Bool = false) {
    context.evaluateScript(
      """
      var sent = []; var events = [];
      function CustomEvent(type, init) { this.type = type; this.detail = init && init.detail; }
      var win = { dispatchEvent: function (e) { events.push(e); } };
      """)
    if webkit {
      context.evaluateScript(
        "win.webkit = { messageHandlers: { grabber: { postMessage: function (m) { sent.push('wk:' + m); } } } };")
    }
    if reactNative {
      context.evaluateScript("win.ReactNativeWebView = { postMessage: function (m) { sent.push('rn:' + m); } };")
    }
  }

  @discardableResult
  func run(_ script: String) -> JavaScriptCore.JSValue? {
    let fn = context.evaluateScript("(function (window, CustomEvent) {\n\(script)\n})")
    return fn?.call(withArguments: [context.objectForKeyedSubscript("win")!, context.objectForKeyedSubscript("CustomEvent")!])
  }

  func eval(_ js: String) -> JavaScriptCore.JSValue { context.evaluateScript(js) }
  var exception: JavaScriptCore.JSValue? { context.exception }
  var sent: [String] { eval("sent").toArray() as? [String] ?? [] }
}

final class BridgeScriptTests: XCTestCase {
  func testInstallsAFeatureDetectableGlobal() {
    let page = FakePage()
    page.run(AudioBridge.installScript())
    XCTAssertNil(page.exception)
    XCTAssertEqual(page.eval("win.CockpitAudioBridge.version").toInt32(), 1)
    XCTAssertEqual(page.eval("win.CockpitAudioBridge.platform").toString(), "ios")
    XCTAssertTrue(page.eval("win.CockpitAudioBridge.last === null").toBool())
    // The page's own "inside the app" tell (cockpit index.html insideGrabber) holds.
    XCTAssertTrue(page.eval("!!win.ReactNativeWebView").toBool())
  }

  func testPostsWellFormedRequestsTheParserAcceptsThroughWebKit() {
    let page = FakePage()
    page.run(AudioBridge.installScript())
    page.eval(
      """
      var b = win.CockpitAudioBridge;
      b.listDevices("a"); b.setInput("mic-bt", "b"); b.setOutput("speaker", "c"); b.getRoute();
      b.post({ type: "call.state", live: true });
      """)
    XCTAssertTrue(page.sent.allSatisfy { $0.hasPrefix("wk:") })
    // Round trip: what the injected helper emits is exactly what the app parses. Drift is the whole risk.
    XCTAssertEqual(page.sent.map { AudioBridge.parse(String($0.dropFirst(3))) }, [
      .audio(.listDevices(requestId: "a")), .audio(.setInput(id: "mic-bt", requestId: "b")),
      .audio(.setOutput(port: "speaker", requestId: "c")), .audio(.getRoute(requestId: nil)), .callState(live: true),
    ])
  }

  func testAnExistingReactNativeWebViewIsLeftAlone() {
    let page = FakePage(webkit: true, reactNative: true)
    page.run(AudioBridge.installScript())
    page.eval("win.CockpitAudioBridge.listDevices('x')")
    XCTAssertEqual(page.sent.count, 1)
    XCTAssertTrue(page.sent[0].hasPrefix("rn:"))
  }

  func testDoesNotThrowWithNoMessageHandlerAtAll() {
    let page = FakePage(webkit: false)
    page.run(AudioBridge.installScript())
    page.eval("win.CockpitAudioBridge.listDevices()")
    XCTAssertNil(page.exception)
    XCTAssertEqual(page.sent, [])
  }

  func testReinjectionKeepsTheExistingBridge() {
    let page = FakePage()
    page.run(AudioBridge.installScript())
    page.eval("var first = win.CockpitAudioBridge; first.last = { marker: true };")
    page.run(AudioBridge.installScript())
    XCTAssertTrue(page.eval("win.CockpitAudioBridge === first && win.CockpitAudioBridge.last.marker").toBool())
  }

  func testScriptsEndInAPrimitive() {
    XCTAssertTrue(AudioBridge.installScript().trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("true;"))
    XCTAssertTrue(
      AudioBridge.emitScript(AudioBridge.readyPayload(available: true)).trimmingCharacters(in: .whitespacesAndNewlines)
        .hasSuffix("true;"))
  }

  func testEmitDispatchesOnItsOwnEventTypeAndRecordsLast() {
    let page = FakePage()
    page.run(AudioBridge.installScript())
    page.run(AudioBridge.emitScript(AudioBridge.devicesPayload(snapshot, requestId: "r1")))
    XCTAssertNil(page.exception)
    XCTAssertEqual(page.eval("events.length").toInt32(), 1)
    XCTAssertEqual(page.eval("events[0].type").toString(), "cockpit-audio")
    XCTAssertEqual(page.eval("events[0].detail.requestId").toString(), "r1")
    XCTAssertEqual(page.eval("events[0].detail.inputs[1].name").toString(), "AirPods Pro")
    XCTAssertTrue(page.eval("events[0].detail.current.input.id === 'BuiltInMicrophoneBottom'").toBool())
    XCTAssertEqual(page.eval("win.CockpitAudioBridge.last.type").toString(), "audio.devices")
  }

  func testSurvivesADeviceNameFullOfQuotesNewlinesAndScriptTags() {
    // A Bluetooth device is named by whoever paired it, and the name lands inside a script the app evaluates.
    let nasty = "He said \"hi\"\n</script>\\ '  \u{2028}\u{2029} `${x}`"
    var named = snapshot
    named.inputs = [AudioDevice(id: "x", name: nasty, type: "BluetoothHFP")]
    let page = FakePage()
    page.run(AudioBridge.installScript())
    page.run(AudioBridge.emitScript(AudioBridge.devicesPayload(named)))
    XCTAssertNil(page.exception)
    XCTAssertEqual(page.eval("events[0].detail.inputs[0].name").toString(), nasty)
    XCTAssertFalse(AudioBridge.emitScript(AudioBridge.devicesPayload(named)).contains("</script>"))
  }

  func testEmitWithoutABridgeOrDispatchEventDoesNotThrowIntoIOS() {
    let page = FakePage()
    page.run(AudioBridge.emitScript(AudioBridge.readyPayload(available: true)))
    XCTAssertNil(page.exception)
    XCTAssertEqual(page.eval("events[0].detail.type").toString(), "audio.ready")
    page.eval("delete win.dispatchEvent")
    page.run(AudioBridge.emitScript(AudioBridge.readyPayload(available: true)))
    XCTAssertNil(page.exception)
  }
}

final class AudioRoutingTests: XCTestCase {
  private let speakerPort = AudioDevice(id: "Speaker-uid", name: "Speaker", type: "Speaker")
  private let a2dp = AudioDevice(id: "BB-a2dp", name: "Headphones", type: "BluetoothA2DPOutput")

  func testOutputsAreAutoSpeakerThenReachableDestinationsOnce() {
    let outputs = AudioRouting.outputs(availableInputs: [mic, pods], routeOutputs: [pods, a2dp, speakerPort])
    XCTAssertEqual(outputs.map(\.id), ["auto", "speaker", pods.id, a2dp.id])
    XCTAssertEqual(outputs[0].name, "Automatic")
    XCTAssertEqual(AudioRouting.outputs(availableInputs: [mic], routeOutputs: [speakerPort]).map(\.id), ["auto", "speaker"])
  }

  func testTheLiveSpeakerIsReportedUnderItsSyntheticId() {
    XCTAssertEqual(AudioRouting.currentOutput(speakerPort)?.id, "speaker")
    XCTAssertEqual(AudioRouting.currentOutput(pods), pods)
    XCTAssertNil(AudioRouting.currentOutput(nil))
  }

  func testOutputAliases() {
    for raw in ["", "auto", "default", "none", "receiver", "Earpiece"] { XCTAssertEqual(AudioRouting.canonicalOutput(raw), "auto") }
    XCTAssertEqual(AudioRouting.canonicalOutput("BuiltInSpeaker"), "speaker")
    XCTAssertEqual(AudioRouting.canonicalOutput(pods.id), pods.id)
  }

  func testOutputMoves() {
    let move = { (raw: String) in AudioRouting.outputMove(for: raw, availableInputs: [mic, pods], routeOutputs: [self.a2dp]) }
    XCTAssertEqual(move("default"), .clearOverride)
    XCTAssertEqual(move("speaker"), .forceSpeaker)
    XCTAssertEqual(move(pods.id), .preferInput(uid: pods.id))
    XCTAssertEqual(move(a2dp.id), .alreadyThere)
    XCTAssertEqual(move("gone"), .unavailable)
  }

  func testReassertIsSkippedWhenTheRouteAlreadyMatches() {
    XCTAssertTrue(AudioRouting.outputSatisfied("auto", routeOutputs: []))
    XCTAssertTrue(AudioRouting.outputSatisfied("speaker", routeOutputs: [speakerPort]))
    XCTAssertFalse(AudioRouting.outputSatisfied("speaker", routeOutputs: [pods]))
    XCTAssertTrue(AudioRouting.outputSatisfied(pods.id, routeOutputs: [pods]))
    XCTAssertTrue(AudioRouting.inputSatisfied(pods.id, liveInput: pods.id, preferredInput: pods.id))
    XCTAssertFalse(AudioRouting.inputSatisfied(pods.id, liveInput: mic.id, preferredInput: pods.id))
    XCTAssertTrue(AudioRouting.inputSatisfied(nil, liveInput: mic.id, preferredInput: nil))
    XCTAssertFalse(AudioRouting.inputSatisfied(nil, liveInput: mic.id, preferredInput: pods.id))
  }

  func testReasonNames() {
    XCTAssertEqual(AudioRouting.reasonName(1), "newDeviceAvailable")
    XCTAssertEqual(AudioRouting.reasonName(3), "categoryChange")
    XCTAssertEqual(AudioRouting.reasonName(99), "unknown")
  }
}

final class CockpitPageTests: XCTestCase {
  func testAddsTheClientAndTheBuildToABareURL() {
    XCTAssertEqual(
      CockpitPage.taggedURL("https://c-5004.squeaker-teeth.ts.net", build: "abc1234"),
      "https://c-5004.squeaker-teeth.ts.net?client=context-grabber&v=abc1234")
  }

  func testJoinsAnExistingQueryAndKeepsTheRouteAfterIt() {
    XCTAssertEqual(CockpitPage.taggedURL("https://h/?x=1#call/abc", build: "s"), "https://h/?x=1&client=context-grabber&v=s#call/abc")
    XCTAssertEqual(CockpitPage.taggedURL("https://h/#calls", build: "s"), "https://h/?client=context-grabber&v=s#calls")
  }

  func testNamesTheClientWithNoBuildAndEscapesTheBuild() {
    XCTAssertEqual(CockpitPage.taggedURL("https://h", build: ""), "https://h?client=context-grabber")
    XCTAssertEqual(CockpitPage.taggedURL("https://h", build: "a b"), "https://h?client=context-grabber&v=a%20b")
    XCTAssertEqual(CockpitPage.taggedURL("https://h", build: "a/é"), "https://h?client=context-grabber&v=a%2F%C3%A9")
  }

  func testNavigationStaysOnTheCockpitAndHandsTheRestOn() {
    let home = CockpitPage.host
    let nav = { (s: String) in CockpitPage.navigation(to: URL(string: s)!, home: home) }
    XCTAssertEqual(nav("https://c-5004.squeaker-teeth.ts.net/#calls"), .stay)
    XCTAssertEqual(nav("about:blank"), .stay)
    XCTAssertEqual(nav("file:///tmp/test.html"), .stay)
    XCTAssertEqual(nav("grabber://call?via=eleven"), .appLink)
    XCTAssertEqual(nav("com.idvorkin.contextgrabber://cockpit"), .appLink)
    XCTAssertEqual(nav("https://github.com/idvorkin/context-grabber/pull/1"), .external)
    XCTAssertEqual(nav("mailto:x@y"), .external)
  }

  func testTheMicrophoneIsGrantedToTheCockpitOnly() {
    XCTAssertTrue(CockpitPage.grantsMicrophone(originHost: "C-5004.squeaker-teeth.ts.net", home: CockpitPage.host))
    XCTAssertFalse(CockpitPage.grantsMicrophone(originHost: "evil.example", home: CockpitPage.host))
    XCTAssertFalse(CockpitPage.grantsMicrophone(originHost: "", home: CockpitPage.host))
    XCTAssertFalse(CockpitPage.grantsMicrophone(originHost: "x", home: nil))
  }
}
