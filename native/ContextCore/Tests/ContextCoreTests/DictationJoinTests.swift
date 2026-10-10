//  #249: a pause in speaking adds to the note; it never replaces what was said or typed.

import XCTest

@testable import ContextCore

final class DictationJoinTests: XCTestCase {
  func testRevisionsOfOneStretchReplaceEachOther() {
    var join = DictationJoin(typed: "")
    join.update(text: "the timer", firstStart: 0.4, lastEnd: 1.0)
    join.update(text: "the timer skipped", firstStart: 0.4, lastEnd: 1.4)
    join.update(text: "the time is skipped the rest", firstStart: 0.4, lastEnd: 2.2)
    XCTAssertEqual(join.note, "the time is skipped the rest")
  }

  func testAFreshTranscriptionAfterAPauseIsAdded() {
    var join = DictationJoin(typed: "Cockpit:")
    join.update(text: "when I stop", firstStart: 0.5, lastEnd: 1.5)
    // After a pause the recogniser starts over: its timestamps carry on past the last result's end.
    XCTAssertTrue(join.update(text: "it gets reset", firstStart: 4.0, lastEnd: 5.0))
    XCTAssertEqual(join.note, "Cockpit: when I stop it gets reset")
    join.update(text: "it gets reset again", firstStart: 4.0, lastEnd: 5.6)
    XCTAssertEqual(join.note, "Cockpit: when I stop it gets reset again")
  }

  func testAFreshTranscriptionWhoseClockStartsOverIsAddedToo() {
    var join = DictationJoin(typed: "")
    join.update(text: "when I stop talking", firstStart: 0.5, lastEnd: 2.0)
    // Timestamps from zero again, shorter, a different first word: new speech.
    XCTAssertTrue(join.update(text: "the input", firstStart: 0.2, lastEnd: 0.8))
    XCTAssertEqual(join.note, "when I stop talking the input")
  }

  func testWhatWasTypedStays() {
    var join = DictationJoin(typed: "  typed first ")
    XCTAssertEqual(join.note, "typed first")
    join.update(text: "", firstStart: 0, lastEnd: 0)
    XCTAssertEqual(join.note, "typed first")
    join.update(text: "then said", firstStart: 0.3, lastEnd: 0.9)
    XCTAssertEqual(join.note, "typed first then said")
  }
}
