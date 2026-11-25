//  Story 1335 (bead context-grabber-lyr4): naming, by kind, what's on a real board that the board won't keep.

import XCTest

@testable import ContextCore

final class BoardMarkupCensusTests: XCTestCase {
  func testInkAloneIsInkOnly() {
    let census = BoardMarkupCensus(strokes: 42, uniqueStrokes: 42, otherKinds: [])
    XCTAssertTrue(census.isInkOnly)
    XCTAssertEqual(census.text, "")
    XCTAssertEqual(census.added(since: nil), [])
  }

  func testAShapeIsNamedByItsKind() {
    let census = BoardMarkupCensus(strokes: 42, uniqueStrokes: 42, otherKinds: ["shape"])
    XCTAssertFalse(census.isInkOnly)
    XCTAssertEqual(census.kinds, ["shape": 1])
    XCTAssertEqual(census.text, "shape:1")
  }

  /// The tally of strokes counts an id once: 43 elements and 42 tallied strokes can be two strokes sharing one id.
  func testTwoStrokesSharingAnIdAreTheirOwnKind() {
    let census = BoardMarkupCensus(strokes: 43, uniqueStrokes: 42, otherKinds: [])
    XCTAssertEqual(census.kinds, [BoardMarkupCensus.duplicateStroke: 1])
    XCTAssertEqual(census.text, "duplicate_stroke:1")
  }

  func testKindsAreCountedAndSorted() {
    let census = BoardMarkupCensus(strokes: 5, uniqueStrokes: 4, otherKinds: ["shape", "image", "shape"])
    XCTAssertEqual(census.text, "duplicate_stroke:1,image:1,shape:2")
  }

  /// Each kind is logged as it first appears, and again only when there are more of it.
  func testAddedNamesOnlyTheKindsThatGrew() {
    let before = BoardMarkupCensus(strokes: 3, uniqueStrokes: 3, otherKinds: ["shape"])
    let same = BoardMarkupCensus(strokes: 4, uniqueStrokes: 4, otherKinds: ["shape"])
    let more = BoardMarkupCensus(strokes: 4, uniqueStrokes: 4, otherKinds: ["shape", "shape", "image"])
    XCTAssertEqual(before.added(since: nil), ["shape"])
    XCTAssertEqual(same.added(since: before), [])
    XCTAssertEqual(more.added(since: same), ["image", "shape"])
  }
}
