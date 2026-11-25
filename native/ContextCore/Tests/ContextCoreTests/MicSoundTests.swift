import XCTest

@testable import ContextCore

/// Stories 1082 and 1083 (context-grabber-ka1i): how the call's mic sounded, per five seconds and for the call.
final class MicSoundTests: XCTestCase {
  let rate = 16_000.0

  /// A tenth of a second of a sine at `amplitude` (peak), or of steady noise-like alternation.
  func tone(_ amplitude: Float, seconds: Double = 0.1) -> [Float] {
    let n = Int(rate * seconds)
    return (0..<n).map { amplitude * Float(sin(Double($0) * 2 * .pi * 440 / rate)) }
  }

  func dB(_ amplitude: Float) -> Double { 20 * log10(Double(amplitude) / 2.0.squareRoot()) }

  func testQuietRoomWithSpeechScoresHigh() {
    var meter = MicSound()
    // 3 s of a quiet room (-66 dBFS RMS) and 2 s of speech (-20 dBFS RMS).
    for _ in 0..<30 { meter.add(tone(0.0007), sampleRate: rate) }
    for _ in 0..<20 { meter.add(tone(0.14), sampleRate: rate) }
    let window = meter.closeWindow()
    XCTAssertEqual(window.floorDB!, dB(0.0007), accuracy: 1)
    XCTAssertEqual(window.speechDB!, dB(0.14), accuracy: 1)
    XCTAssertEqual(window.snrDB!, dB(0.14) - dB(0.0007), accuracy: 1.5)
    XCTAssertEqual(window.clips, 0)
    XCTAssertEqual(window.dropouts, 0)
    XCTAssertEqual(window.score, 100)
  }

  func testWindyAirPodsScoreLow() {
    var meter = MicSound()
    // Wind: a floor at about -30 dBFS, speech only 6-7 dB over it.
    for _ in 0..<30 { meter.add(tone(0.045), sampleRate: rate) }
    for _ in 0..<20 { meter.add(tone(0.1), sampleRate: rate) }
    let window = meter.closeWindow()
    XCTAssertEqual(window.floorDB!, -30, accuracy: 1)
    XCTAssertNotNil(window.snrDB)
    // No floor points and few SNR points; clips and dropouts still earn their 30.
    XCTAssertLessThan(window.score, 50)
  }

  func testNoSpeechHasNoSNRAndScalesTheOtherParts() {
    var meter = MicSound()
    for _ in 0..<50 { meter.add(tone(0.0007), sampleRate: rate) }
    let window = meter.closeWindow()
    XCTAssertNil(window.snrDB)
    XCTAssertNil(window.speechDB)
    XCTAssertFalse(window.speech)
    // Quiet floor, no clips, no dropouts: the other three parts scaled up to 100.
    XCTAssertEqual(window.score, 100)
  }

  func testClipsAndDropoutsCostPoints() {
    var meter = MicSound()
    for _ in 0..<30 { meter.add(tone(0.0007), sampleRate: rate) }
    for _ in 0..<15 { meter.add(tone(0.14), sampleRate: rate) }
    for _ in 0..<5 { meter.add([Float](repeating: 1, count: 1600), sampleRate: rate) }  // full scale
    for _ in 0..<10 { meter.add([Float](repeating: 0, count: 1600), sampleRate: rate) }  // digital silence
    let window = meter.closeWindow()
    XCTAssertEqual(window.clips, 5)
    XCTAssertEqual(window.dropouts, 10)
    XCTAssertEqual(window.peakDB, 0, accuracy: 0.1)
    // SNR and floor full (70); 5 of 60 pieces clipped (8%) and 10 of 60 silent (17%) each leave 2.5 of 15.
    XCTAssertEqual(window.score, 75)
  }

  func testBuffersThatDoNotLineUpWithPiecesStillMeasure() {
    var meter = MicSound()
    // 1024-sample buffers at 24 kHz, as AirPods HFP delivers: pieces of 2400 samples span buffers.
    let hfp = 24_000.0
    for _ in 0..<120 {
      meter.add((0..<1024).map { _ in Float(0.0007) }, sampleRate: hfp)
    }
    let window = meter.closeWindow()
    XCTAssertEqual(window.pieces, 51)  // 122,880 samples / 2400
    XCTAssertEqual(window.floorDB!, 20 * log10(0.0007), accuracy: 0.5)
  }

  func testEmptyWindowSaysNothing() {
    var meter = MicSound()
    let window = meter.closeWindow()
    XCTAssertEqual(window.pieces, 0)
    XCTAssertNil(window.floorDB)
    XCTAssertTrue(window.fields.isEmpty)
  }

  func testCallSummaryIsTheMedianSoOneGustDoesNotSinkIt() {
    var meter = MicSound()
    func quiet() {
      for _ in 0..<30 { meter.add(tone(0.0007), sampleRate: rate) }
      for _ in 0..<20 { meter.add(tone(0.14), sampleRate: rate) }
      _ = meter.closeWindow()
    }
    quiet()
    quiet()
    for _ in 0..<30 { meter.add(tone(0.045), sampleRate: rate) }
    for _ in 0..<20 { meter.add(tone(0.1), sampleRate: rate) }
    let gust = meter.closeWindow()
    quiet()
    quiet()
    let summary = meter.callSummary()
    XCTAssertEqual(summary.windows, 5)
    XCTAssertEqual(summary.score, 100)
    XCTAssertEqual(summary.worst, gust.score)
    XCTAssertTrue(summary.speech)
    XCTAssertNotNil(summary.snrDB)
    XCTAssertEqual(summary.fields["score"] as? Int, 100)
  }

  func testCallWithNoSpeechSaysSo() {
    var meter = MicSound()
    for _ in 0..<50 { meter.add(tone(0.0007), sampleRate: rate) }
    _ = meter.closeWindow()
    let summary = meter.callSummary()
    XCTAssertFalse(summary.speech)
    XCTAssertNil(summary.snrDB)
    XCTAssertEqual(summary.fields["speech"] as? Bool, false)
  }

  func testDeadMicScoresZero() {
    var meter = MicSound()
    for _ in 0..<50 { meter.add([Float](repeating: 0, count: 1600), sampleRate: rate) }
    let window = meter.closeWindow()
    XCTAssertEqual(window.dropouts, 50)
    XCTAssertNil(window.floorDB)
    XCTAssertEqual(window.score, 0)
    XCTAssertEqual(meter.callSummary().score, 0)
  }

  func testShortClosingStretchDoesNotCountTowardTheCall() {
    var meter = MicSound()
    for _ in 0..<30 { meter.add(tone(0.0007), sampleRate: rate) }
    for _ in 0..<20 { meter.add(tone(0.14), sampleRate: rate) }
    _ = meter.closeWindow()
    // "Bye" in the last 0.3 s: all speech, so its floor is speech level and it scores low.
    for _ in 0..<3 { meter.add(tone(0.14), sampleRate: rate) }
    XCTAssertLessThan(meter.closeWindow().score, 100)
    let summary = meter.callSummary()
    XCTAssertEqual(summary.windows, 1)
    XCTAssertEqual(summary.score, 100)
    XCTAssertEqual(summary.worst, 100)
  }

  func testShortCallStillGetsAScore() {
    var meter = MicSound()
    for _ in 0..<3 { meter.add(tone(0.0007), sampleRate: rate) }
    _ = meter.closeWindow()
    let summary = meter.callSummary()
    XCTAssertEqual(summary.windows, 1)
    XCTAssertNotNil(summary.score)
  }

  func testScoreParts() {
    // The spec's table, each part linear between its ends.
    XCTAssertEqual(MicSound.score(snrDB: 30, floorDB: -60, clipFraction: 0, dropoutFraction: 0), 100)
    XCTAssertEqual(MicSound.score(snrDB: 0, floorDB: -30, clipFraction: 0.1, dropoutFraction: 0.2), 0)
    XCTAssertEqual(MicSound.score(snrDB: 15, floorDB: -60, clipFraction: 0, dropoutFraction: 0), 75)
    XCTAssertEqual(MicSound.score(snrDB: 30, floorDB: -45, clipFraction: 0, dropoutFraction: 0), 90)
    // No speech: the other three parts (50 points) scaled up to 100.
    XCTAssertEqual(MicSound.score(snrDB: nil, floorDB: -45, clipFraction: 0, dropoutFraction: 0), 80)
    // No floor at all, nothing but digital silence: 0.
    XCTAssertEqual(MicSound.score(snrDB: nil, floorDB: nil, clipFraction: 0, dropoutFraction: 1), 0)
  }
}
