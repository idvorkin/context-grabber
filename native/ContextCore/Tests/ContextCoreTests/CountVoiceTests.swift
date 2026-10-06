import Foundation
import XCTest

@testable import ContextCore

final class CountVoiceTests: XCTestCase {
  func testAdamCountsUntilSomethingElseIsChosen() {
    XCTAssertEqual(CountVoice.decode(nil), .adam)
    XCTAssertEqual(CountVoice.decode(""), .adam)
    XCTAssertEqual(CountVoice.decode("tony"), .adam)
    XCTAssertEqual(CountVoice.decode("aussie"), .aussie)
    XCTAssertEqual(CountVoice.decode("igor"), .igor)
  }

  func testTheSheetListsAdamIgorThenTheAustralianWoman() {
    XCTAssertEqual(CountVoice.allCases.map(\.label), ["Adam", "Igor", "Australian woman"])
  }

  func testIgorPlaysTheSharedFilesAndTheOthersTheirOwn() {
    XCTAssertEqual(CountVoice.igor.fileName(for: .three), "three")
    XCTAssertEqual(CountVoice.adam.fileName(for: .go), "adam-go")
    XCTAssertEqual(CountVoice.aussie.fileName(for: .done), "aussie-done")
  }

  /// Every voice has all six cues in the bundle's sources, so no cue can fall silent for want of a file.
  func testEveryVoiceHasEveryCueOnDisk() {
    let repo = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    for voice in CountVoice.allCases {
      let dir = repo.appendingPathComponent(voice == .igor ? "assets/audio/timer" : "assets/audio/timer-voices")
      for cue in TimerCue.allCases {
        let file = dir.appendingPathComponent("\(voice.fileName(for: cue)).wav")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), file.path)
      }
    }
  }
}
