import XCTest

@testable import ContextCore

final class PCMTests: XCTestCase {
  func testExactSilenceIsOnlyAllZeroNonEmptyBuffers() {
    XCTAssertTrue(PCM.isExactSilence([Float](repeating: 0, count: 480)))
    XCTAssertFalse(PCM.isExactSilence([0, 0, 1e-9]))
    XCTAssertFalse(PCM.isExactSilence([]))
  }

  func testMicLevelIsADecibelScaleFromTheFloorToFullScale() {
    XCTAssertEqual(PCM.micLevel([Float](repeating: 0, count: 100)), 0)
    XCTAssertEqual(PCM.micLevel([0, 1, -0.2]), 1)
    XCTAssertEqual(PCM.micLevel([3]), 1)  // clipping does not exceed 1
    XCTAssertEqual(PCM.micLevel([0.1]), 0.6, accuracy: 0.005)  // -20 dBFS
    XCTAssertEqual(PCM.micLevel([0.00316]), 0, accuracy: 0.05)  // -50 dBFS, the floor
    XCTAssertEqual(PCM.micLevel([0.0001]), 0)
  }

  func testFloatToPcm16MapsFullScaleAndClipsBeyondIt() {
    XCTAssertEqual(PCM.floatToPcm16([0, 1, -1, 2, -2, 0.5]), [0, 32767, -32768, 32767, -32768, 16384])
  }

  private func bytes(_ samples: [Int16]) -> Data {
    var data = Data()
    for s in samples { withUnsafeBytes(of: s.littleEndian) { data.append(contentsOf: $0) } }
    return data
  }

  func testPcm16ToFloatReadsLittleEndianAndIgnoresATrailingOddByte() {
    let out = PCM.pcm16ToFloat(bytes([0, 32767, -32768, 16384]))
    XCTAssertEqual(out[0], 0)
    XCTAssertEqual(out[1], 1, accuracy: 1e-6)
    XCTAssertEqual(out[2], -1)
    XCTAssertEqual(out[3], 0.5, accuracy: 1e-3)
    XCTAssertEqual(PCM.pcm16ToFloat(bytes([1000, 2000]) + Data([7])).count, 2)
    XCTAssertEqual(PCM.pcm16ToFloat(Data([0xE8, 0x03])).first.map { ($0 * 32767).rounded() }, 1000)
  }

  func testRoundTripsWithinOneLsb() {
    let src = (0..<100).map { Float(sin(Double($0) / 7)) }
    let back = PCM.pcm16ToFloat(bytes(PCM.floatToPcm16(src)))
    for (a, b) in zip(src, back) { XCTAssertEqual(a, b, accuracy: 1e-4) }
  }

  func testResampleKeepsOneSampleInThreeFrom48kTo16k() {
    let src = (0..<4800).map(Float.init)
    let out = PCM.resampleLinear(src, from: 48000, to: 16000)
    XCTAssertEqual(out.count, 1600)
    XCTAssertEqual(out[0], 0)
    XCTAssertEqual(out[1], 3)
    XCTAssertEqual(out[1599], 4797)
    XCTAssertEqual(PCM.resampleLinear([1, 2, 3], from: 16000, to: 16000), [1, 2, 3])
  }

  func testResampleInterpolatesAndASineStaysASine() {
    let up = PCM.resampleLinear([0, 1, 2, 3], from: 4, to: 8)
    XCTAssertEqual(up.count, 8)
    XCTAssertEqual(up[1], 0.5, accuracy: 1e-6)
    XCTAssertEqual(up[3], 1.5, accuracy: 1e-6)
    let from = 44100.0
    let src = (0..<44100).map { Float(sin(2 * Double.pi * 440 * Double($0) / from)) }
    let out = PCM.resampleLinear(src, from: from, to: 16000)
    XCTAssertEqual(out.count, 16000)
    for i in stride(from: 0, to: 16000, by: 97) {
      XCTAssertEqual(Double(out[i]), sin(2 * Double.pi * 440 * Double(i) / 16000), accuracy: 0.05)
    }
  }

  func testAMicFrameIsTwoBytesPer16kSample() {
    XCTAssertEqual(PCM.encodeMicFrame([Float](repeating: 0, count: 4800), sampleRate: 48000).count, 3200)
    XCTAssertEqual(PCM.encodeMicFrame([Float](repeating: 0, count: 320), sampleRate: 16000).count, 640)
    XCTAssertEqual(PCM.encodeMicFrame([1, -1], sampleRate: 16000), Data([0xFF, 0x7F, 0x00, 0x80]))
  }
}

final class CallProtocolTests: XCTestCase {
  private func object(_ json: String) -> NSDictionary {
    (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary) ?? [:]
  }

  func testTheBridgeMountsAtSlashBridgeOverHttpsAndIsItsOwnPortOnHttp() {
    XCTAssertEqual(
      CallProtocol.bridgeURL(cockpit: "https://c-5004.squeaker-teeth.ts.net"),
      "wss://c-5004.squeaker-teeth.ts.net/bridge")
    XCTAssertEqual(CallProtocol.bridgeURL(cockpit: "http://c-5004:8778"), "ws://c-5004:8780")
    XCTAssertNil(CallProtocol.bridgeURL(cockpit: "not a url"))
  }

  func testOffersTheFourBackendsElevenLabsFirstAndByDefault() {
    XCTAssertEqual(CallBackend.allCases.map(\.rawValue), ["eleven", "gemini", "openai", "drill"])
    XCTAssertEqual(CallBackend.default, .eleven)
    XCTAssertNil(CallBackend(rawValue: "siri"))
  }

  func testStartNamesTheBackendLeavesModelAndVoiceToTheVendorAndSaysWhoIsCalling() {
    XCTAssertEqual(
      object(CallProtocol.startFrame(backend: .eleven, build: "abc1234")),
      ["type": "start", "backend": "eleven", "model": "", "voice": "", "client": "context-grabber", "build": "abc1234"])
    XCTAssertEqual(object(CallProtocol.startFrame(backend: .gemini))["build"] as? String, "")
  }

  func testStartCarriesAVoiceAndAModelWhenTheCallHasAPick() {
    let frame = object(
      CallProtocol.startFrame(
        backend: .eleven, build: "abc", voice: "Nvd5I2HGnOWHNU0ijNEy", model: "eleven_v3_conversational"))
    XCTAssertEqual(frame["voice"] as? String, "Nvd5I2HGnOWHNU0ijNEy")
    XCTAssertEqual(frame["model"] as? String, "eleven_v3_conversational")
  }

  func testLocationRidesTheStartFrameAndItsOwnFrameMidCall() {
    let here = CallLocation(lat: 47.6, lon: -122.3, accuracyM: 12, at: "2026-09-02T14:52:00.000Z", place: "Home")
    let fields: NSDictionary = [
      "lat": 47.6, "lon": -122.3, "accuracy_m": 12, "at": "2026-09-02T14:52:00.000Z", "place": "Home",
    ]
    XCTAssertEqual(object(CallProtocol.startFrame(backend: .eleven, location: here))["location"] as? NSDictionary, fields)
    XCTAssertNil(object(CallProtocol.startFrame(backend: .eleven))["location"])
    let frame = NSMutableDictionary(dictionary: fields)
    frame["type"] = "location"
    XCTAssertEqual(object(CallProtocol.locationFrame(here)), frame)
    let nowhere = CallLocation(lat: 1, lon: 2, accuracyM: nil, at: "t", place: nil)
    XCTAssertTrue(object(CallProtocol.locationFrame(nowhere))["place"] is NSNull)
    XCTAssertTrue(object(CallProtocol.locationFrame(nowhere))["accuracy_m"] is NSNull)
    XCTAssertEqual(here.description, "Home (±12 m)")
    XCTAssertEqual(nowhere.description, "1.0, 2.0")
  }

  func testTheOtherFramesMatchTheBridgeDocstring() {
    XCTAssertEqual(object(CallProtocol.sttStartFrame()), ["type": "stt_start", "rate": 16000])
    XCTAssertEqual(object(CallProtocol.sttStopFrame()), ["type": "stt_stop"])
    XCTAssertEqual(object(CallProtocol.stopFrame()), ["type": "stop"])
    XCTAssertEqual(object(CallProtocol.micFrame(muted: true)), ["type": "mic", "muted": true])
    XCTAssertEqual(object(CallProtocol.micProbeFrame(token: 3)), ["type": "mic_probe", "token": 3])
    XCTAssertEqual(
      object(CallProtocol.diagnosticsFrame(build: "abc (main)", text: "+0.0s start")),
      ["type": "diagnostics", "build": "abc (main)", "text": "+0.0s start"])
  }

  func testJunkAndEventsTheScreenDoesNotRenderAreNil() {
    for junk in [nil, "", "{nope", "[1]", "{\"text\":\"hi\"}"] { XCTAssertNil(CallProtocol.parse(junk)) }
    for ignored in ["{\"type\":\"turn_metrics\",\"user_ms\":12}", "{\"type\":\"stt_ready\"}", "{\"type\":\"sessions\"}"] {
      XCTAssertNil(CallProtocol.parse(ignored))
    }
  }

  func testReadyCarriesTheOutputRateDefaultingTo24kForAnOldBridge() {
    XCTAssertEqual(
      CallProtocol.parse("{\"type\":\"ready\",\"out_rate\":16000,\"backend\":\"eleven\",\"session\":\"abc\",\"tools\":[]}"),
      .ready(outRate: 16000, backend: "eleven", session: "abc"))
    XCTAssertEqual(CallProtocol.parse("{\"type\":\"ready\"}"), .ready(outRate: 24000, backend: "", session: ""))
  }

  func testTranscriptsCaptionsControlAndEndings() {
    let cases: [(String, BridgeMessage)] = [
      ("{\"type\":\"transcript\",\"who\":\"larry\",\"text\":\"Hello.\"}", .transcript(who: "larry", text: "Hello.", source: nil)),
      (
        "{\"type\":\"transcript\",\"who\":\"igor\",\"text\":\"hi\",\"source\":\"typed\"}",
        .transcript(who: "igor", text: "hi", source: "typed")
      ),
      ("{\"type\":\"stt_partial\",\"text\":\"hel\"}", .sttPartial(text: "hel")),
      ("{\"type\":\"stt_final\",\"text\":\"hello\",\"speech_final\":true}", .sttFinal(text: "hello")),
      ("{\"type\":\"mic_ack\",\"token\":\"4\",\"frames\":1}", .micAck(token: 4)),
      ("{\"type\":\"mic_ack\",\"token\":5}", .micAck(token: 5)),
      ("{\"type\":\"interrupted\"}", .interrupted),
      ("{\"type\":\"turn_end\"}", .turnEnd),
      ("{\"type\":\"tool_call\",\"id\":\"t1\",\"question\":\"why?\"}", .toolCall(question: "why?")),
      ("{\"type\":\"tool_result\",\"ok\":true,\"answer\":\"because\"}", .toolResult(ok: true, answer: "because")),
      ("{\"type\":\"tool_result\",\"ok\":false,\"answer\":\"no\"}", .toolResult(ok: false, answer: "no")),
      ("{\"type\":\"tool_result\",\"answer\":\"old bridge\"}", .toolResult(ok: true, answer: "old bridge")),
      (
        "{\"type\":\"consult_progress\",\"stage\":\"note\",\"text\":\"reading…\"}",
        .consultProgress(stage: "note", text: "reading…")
      ),
      ("{\"type\":\"injected\",\"text\":\"fact\"}", .injected(text: "fact")),
      ("{\"type\":\"warning\",\"message\":\"goAway\"}", .warning(message: "goAway")),
      ("{\"type\":\"error\",\"message\":\"boom\"}", .error(message: "boom")),
      (
        "{\"type\":\"vendor_closed\",\"kind\":\"quota\",\"message\":\"out\",\"help\":\"…\"}",
        .vendorClosed(kind: "quota", message: "out")
      ),
      ("{\"type\":\"closed\",\"reason\":\"hangup intent\"}", .closed(reason: "hangup intent")),
    ]
    for (raw, expected) in cases { XCTAssertEqual(CallProtocol.parse(raw), expected, raw) }
  }

  func testEndingsMirrorThePagesWordingAndAnUnknownReasonIsPrintedVerbatim() {
    XCTAssertEqual(CallProtocol.endingText("idle timeout"), "idle 2 min")
    XCTAssertEqual(CallProtocol.endingText("hangup intent"), "hang-up intent")
    XCTAssertEqual(CallProtocol.endingText(CallProtocol.stopped), "stopped")
    XCTAssertEqual(CallProtocol.endingText(CallProtocol.connectionLost), "connection lost")
    XCTAssertEqual(CallProtocol.endingText(""), "session ended")
    XCTAssertEqual(CallProtocol.endingText(nil), "session ended")
    XCTAssertEqual(CallProtocol.endingText("Gemini Live ended the session: 1011"), "Gemini Live ended the session: 1011")
  }
}

final class CallVoiceTests: XCTestCase {
  func testOffersTonyAndIgorTonyFirstAndByDefault() {
    XCTAssertEqual(CallVoice.allCases.map(\.rawValue), ["tony", "igor"])
    XCTAssertEqual(CallVoice.default, .tony)
    XCTAssertEqual(CallVoice.allCases.map(\.label), ["Tony", "Igor"])
    XCTAssertNil(CallVoice(rawValue: "IKne3meq5aSn9XLyUdCD"))
  }

  func testOnlyElevenLabsAndTheDrillHaveAVoiceToPick() {
    XCTAssertTrue(CallVoice.hasPick(.eleven))
    XCTAssertTrue(CallVoice.hasPick(.drill))
    XCTAssertFalse(CallVoice.hasPick(.gemini))
    XCTAssertFalse(CallVoice.hasPick(.openai))
    XCTAssertFalse(CallVoice.hasPick(nil))
  }

  func testTonyIsTheBridgesDefaultIgorIsTheCloneOnV3AndOtherBackendsSendNothing() {
    XCTAssertEqual(CallVoice.tony.frameFields(for: .eleven).voice, "")
    XCTAssertEqual(CallVoice.tony.frameFields(for: .eleven).model, "")
    XCTAssertEqual(CallVoice.igor.frameFields(for: .eleven).voice, "Nvd5I2HGnOWHNU0ijNEy")
    XCTAssertEqual(CallVoice.igor.frameFields(for: .eleven).model, "eleven_v3_conversational")
    XCTAssertEqual(CallVoice.igor.frameFields(for: .drill).voice, "Nvd5I2HGnOWHNU0ijNEy")
    XCTAssertEqual(CallVoice.igor.frameFields(for: .gemini).voice, "")
    XCTAssertEqual(CallVoice.igor.frameFields(for: .openai).model, "")
    // The shape the bridge checks: 16–40 of [A-Za-z0-9_-].
    XCTAssertNotNil(CallVoice.igor.frameFields(for: .eleven).voice.range(of: "^[A-Za-z0-9_-]{16,40}$", options: .regularExpression))
  }
}
