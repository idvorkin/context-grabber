import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Story 1348 (#1526): a long label of Larry's wraps to the right edge of the picture he was sent.
final class BoardLabelWrapTests: XCTestCase {
  /// One unit a character, so the rows are easy to read off.
  private let count: (String) -> CGFloat = { CGFloat($0.count) }

  func testATextThatFitsStaysOneLine() {
    XCTAssertEqual(WhiteboardTurn.wrap("hello there", room: 20, measure: count), ["hello there"])
  }

  func testALongTextBreaksBetweenWords() {
    XCTAssertEqual(
      WhiteboardTurn.wrap("the quick brown fox jumps", room: 11, measure: count),
      ["the quick", "brown fox", "jumps"])
  }

  func testAWordLongerThanTheRoomBreaksWhereItMust() {
    XCTAssertEqual(WhiteboardTurn.wrap("abcdefghij", room: 4, measure: count), ["abcd", "efgh", "ij"])
  }

  func testANewlineInTheTextStartsALine() {
    XCTAssertEqual(WhiteboardTurn.wrap("one\ntwo three", room: 40, measure: count), ["one", "two three"])
  }

  func testNoRoomMeansNoWrap() {
    XCTAssertEqual(WhiteboardTurn.wrap("a long line of words", room: 0, measure: count), ["a long line of words"])
  }

  #if canImport(CoreText)
    private let long = "This is a long answer from Larry that should not run off the edge of the board"

    func testALongLabelStaysInsideThePicturesRightEdge() {
      let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
      let shape = WhiteboardTurn.Shape(kind: .text, points: [CGPoint(x: 40, y: 100)], text: long, size: 28)
      let points = WhiteboardTurn.lines(shape, frame: frame, scale: 1).flatMap { $0 }
      XCTAssertLessThanOrEqual(points.map(\.x).max() ?? .infinity, frame.maxX - WhiteboardTurn.labelMargin + 1)
      XCTAssertGreaterThanOrEqual(points.map(\.x).min() ?? 0, 40 - 1)
      // More than one row: the letters reach well below one line's height.
      XCTAssertGreaterThan((points.map(\.y).max() ?? 0) - 100, 28 * 2)
    }

    func testEachFurtherLineIsOnePitchLower() {
      let frame = CGRect(x: 0, y: 0, width: 300, height: 800)
      let shape = WhiteboardTurn.Shape(kind: .text, points: [CGPoint(x: 0, y: 0)], text: "HHH HHH HHH HHH", size: 40)
      let tops = WhiteboardTurn.wrappedRows(shape, frame: frame, scale: 1).map(\.y)
      XCTAssertGreaterThan(tops.count, 1)
      for (a, b) in zip(tops, tops.dropFirst()) {
        XCTAssertEqual(b - a, 40 * WhiteboardTurn.labelLinePitch, accuracy: 0.01)
      }
    }

    func testALabelThatFitsDrawsAsBefore() {
      let frame = CGRect(x: 0, y: 0, width: 800, height: 800)
      let shape = WhiteboardTurn.Shape(kind: .text, points: [CGPoint(x: 100, y: 100)], text: "Hi there", size: 28)
      XCTAssertEqual(
        WhiteboardTurn.lines(shape, frame: frame, scale: 1), WhiteboardTurn.lines(shape, frame: .zero, scale: 1))
    }

    func testATextWithNoPictureDoesNotWrap() {
      let shape = WhiteboardTurn.Shape(kind: .text, points: [CGPoint(x: 0, y: 0)], text: long, size: 28)
      let points = WhiteboardTurn.lines(shape, frame: .zero, scale: 1).flatMap { $0 }
      XCTAssertLessThan((points.map(\.y).max() ?? 0), 28 * 1.5)
    }

    func testALabelAtTheEdgeStillGetsAFewWordsALine() {
      let frame = CGRect(x: 0, y: 0, width: 400, height: 800)
      let shape = WhiteboardTurn.Shape(kind: .text, points: [CGPoint(x: 390, y: 0)], text: "one two three", size: 20)
      let rows = WhiteboardTurn.wrappedRows(shape, frame: frame, scale: 1)
      XCTAssertLessThanOrEqual(rows.count, 2)
    }
  #endif
}
