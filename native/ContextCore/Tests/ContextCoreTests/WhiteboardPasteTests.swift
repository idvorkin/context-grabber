import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

final class WhiteboardPasteTests: XCTestCase {
  private let view = CGRect(x: 9000, y: 9000, width: 1000, height: 800)

  private func bounds(_ lines: [[CGPoint]]) -> CGRect {
    let points = lines.joined()
    let xs = points.map(\.x)
    let ys = points.map(\.y)
    return CGRect(
      x: xs.min() ?? 0, y: ys.min() ?? 0, width: (xs.max() ?? 0) - (xs.min() ?? 0),
      height: (ys.max() ?? 0) - (ys.min() ?? 0))
  }

  // MARK: Stories 637, 640, 642, 647, 649: on a board on paper

  #if canImport(CoreText)
    func testOnPaperItLandsInTheViewPastTheOldBoardsEdge() {
      let far = CGRect(x: 0, y: 30_000, width: 820, height: 1_000)
      let box = bounds(WhiteboardPaste.layout("HI", visible: far, height: 24, board: BoardPages().pasteReach).lines)
      XCTAssertEqual(box.midY, far.midY, accuracy: 0.5, "page 29, in the middle of the view")
      XCTAssertEqual(box.midX, far.midX, accuracy: 0.5)
      let old = bounds(WhiteboardPaste.layout("HI", visible: far, height: 24).lines)
      XCTAssertLessThanOrEqual(old.maxY, WhiteboardFrame.side, "the fixed square keeps its edge")
    }

    func testOnPaperItStaysOnThePagesWidth() {
      let reach = BoardPages().pasteReach
      let page = CGRect(x: 0, y: 0, width: 820, height: 1_000)
      let long = String(repeating: "wide ", count: 60)
      let box = bounds(WhiteboardPaste.layout(long, visible: page, height: 49, board: reach).lines)
      XCTAssertGreaterThanOrEqual(box.minX, 0)
      XCTAssertLessThanOrEqual(box.maxX, 820)
      // Zoomed in by the right edge: the view's middle is near the side, and short text still fits.
      let edge = CGRect(x: 700, y: 0, width: 120, height: 100)
      let near = bounds(WhiteboardPaste.layout("HI HI", visible: edge, height: 24, board: reach).lines)
      XCTAssertLessThanOrEqual(near.maxX, 820)
      let top = CGRect(x: 0, y: -200, width: 820, height: 100)
      let above = bounds(WhiteboardPaste.layout("HI", visible: top, height: 24, board: reach).lines)
      XCTAssertGreaterThanOrEqual(above.minY, 0, "nothing lands above the first page")
    }

    func testATallPasteRunsDownThePagesAndAsksForThem() {
      let view = CGRect(x: 0, y: 0, width: 820, height: 1_500)
      let text = Array(repeating: "HI", count: 40).joined(separator: "\n")
      let box = bounds(WhiteboardPaste.layout(text, visible: view, height: 49, board: BoardPages().pasteReach).lines)
      XCTAssertEqual(BoardPages().pages(after: 2, inkMaxY: box.maxY, redoWaiting: false), 4)
    }

    /// Story 643: Larry knows a paste by its strokes' names. A paste's strokes share a colour and a moment, so only
    /// the ink tells them apart: every letter's stroke gets its own name.
    func testAPastesLetterStrokesEachHaveTheirOwnName() {
      let t: Int64 = 1_795_540_000_000
      let names = WhiteboardPaste.layout("Hi Larry", visible: view, height: 24).lines.map {
        WhiteboardStrokes.id(points: $0, color: "#000000", t: t)
      }
      XCTAssertGreaterThan(names.count, 1, "the paste is lettered as strokes")
      XCTAssertEqual(Set(names).count, names.count, "every letter's stroke has its own name")
    }

    func testShortTextIsCentredInTheView() {
      let layout = WhiteboardPaste.layout("Hello", visible: view, height: 24)
      XCTAssertFalse(layout.lines.isEmpty)
      XCTAssertFalse(layout.cut)
      let box = bounds(layout.lines)
      XCTAssertEqual(box.midX, view.midX, accuracy: 0.5)
      XCTAssertEqual(box.midY, view.midY, accuracy: 0.5)
    }

    func testEachLineKeepsItsRowEvenAfterABlankOne() {
      let one = WhiteboardPaste.layout("HI", visible: view, height: 24)
      let two = WhiteboardPaste.layout("HI\nHI", visible: view, height: 24)
      let gap = WhiteboardPaste.layout("HI\n\nHI", visible: view, height: 24)
      XCTAssertEqual(two.lines.count, 2 * one.lines.count)
      XCTAssertEqual(bounds(two.lines).width, bounds(one.lines).width, accuracy: 0.5)
      XCTAssertEqual(bounds(two.lines).height, bounds(one.lines).height + 30, accuracy: 0.5)
      XCTAssertEqual(bounds(gap.lines).height, bounds(one.lines).height + 60, accuracy: 0.5)
    }

    func testWindowsLineEndsAndSurroundingSpaceAreNotExtraRows() {
      let plain = WhiteboardPaste.layout("HI\nHI", visible: view, height: 24)
      let messy = WhiteboardPaste.layout("\n  HI\r\nHI \n\n", visible: view, height: 24)
      XCTAssertEqual(bounds(messy.lines).height, bounds(plain.lines).height, accuracy: 0.5)
      XCTAssertEqual(messy.lines.count, plain.lines.count)
      XCTAssertFalse(messy.cut)
    }

    func testALongLineWrapsInsideTheView() {
      let long = String(repeating: "word ", count: 60)
      let layout = WhiteboardPaste.layout(long, visible: view, height: 24)
      let box = bounds(layout.lines)
      XCTAssertLessThanOrEqual(box.width, view.width * 0.8)
      XCTAssertGreaterThan(box.height, 24 * 2)
      XCTAssertGreaterThan(box.minX, view.minX)
      XCTAssertLessThan(box.maxX, view.maxX)
      XCTAssertFalse(layout.cut)
    }

    func testOverTheCharacterCapIsCutAndSaysHowMuch() {
      let layout = WhiteboardPaste.layout(String(repeating: "x", count: 1234), visible: view, height: 24)
      XCTAssertEqual(layout.kept, WhiteboardPaste.maxCharacters)
      XCTAssertEqual(layout.total, 1234)
      XCTAssertTrue(layout.cut)
    }

    func testOverTheLineCapIsCutAndATallBlockStartsAtTheTopOfTheView() {
      let text = (0..<100).map { _ in "a" }.joined(separator: "\n")
      let layout = WhiteboardPaste.layout(text, visible: view, height: 24)
      XCTAssertEqual(layout.total, 199)
      XCTAssertEqual(layout.kept, 2 * WhiteboardPaste.maxLines)
      XCTAssertTrue(layout.cut)
      let box = bounds(layout.lines)
      let letter = bounds(WhiteboardPaste.layout("a", visible: view, height: 24).lines)
      XCTAssertEqual(box.height, 30 * CGFloat(WhiteboardPaste.maxLines - 1) + letter.height, accuracy: 1)
      XCTAssertEqual(box.minY, view.minY + 24, accuracy: 0.5)
    }

    /// The spec's numbers, written out: 500 characters land whole, the 501st is the first one left off.
    func testTheCharacterCapIsExactlyFiveHundred() {
      let atCap = WhiteboardPaste.layout(String(repeating: "x", count: 500), visible: view, height: 24)
      XCTAssertEqual(atCap.kept, 500)
      XCTAssertEqual(atCap.total, 500)
      XCTAssertFalse(atCap.cut)
      let over = WhiteboardPaste.layout(String(repeating: "x", count: 501), visible: view, height: 24)
      XCTAssertEqual(over.kept, 500)
      XCTAssertEqual(over.total, 501)
      XCTAssertTrue(over.cut)
    }

    /// The spec's numbers, written out: 40 lines land whole, the 41st is the first one left off.
    func testTheLineCapIsExactlyForty() {
      let lines = { (count: Int) in (0..<count).map { _ in "a" }.joined(separator: "\n") }
      let one = WhiteboardPaste.layout("a", visible: view, height: 24).lines.count
      let atCap = WhiteboardPaste.layout(lines(40), visible: view, height: 24)
      XCTAssertFalse(atCap.cut)
      XCTAssertEqual(atCap.lines.count, 40 * one)
      let over = WhiteboardPaste.layout(lines(41), visible: view, height: 24)
      XCTAssertTrue(over.cut)
      XCTAssertEqual(over.lines.count, 40 * one)
    }

    /// Whatever the clipboard and the view, ink is finite and on the board (spec: a paste stays on the board).
    func testOddClipboardsAndViewsStayOnTheBoard() {
      let clipboards = [
        "one\r\ntwo\r\n", "a\tb", "a\u{0}b\u{7}c", "שלום עולם", "مرحبا hello", String(repeating: "x", count: 500),
      ]
      let views = [
        view, CGRect(x: 19_900, y: 19_900, width: 100, height: 100), CGRect(x: -50, y: -50, width: 200, height: 200),
        CGRect(x: 500, y: 500, width: 0, height: 0),
      ]
      for text in clipboards {
        for visible in views {
          let lines = WhiteboardPaste.layout(text, visible: visible, height: 24).lines
          XCTAssertFalse(lines.isEmpty, "\(text.prefix(20)) in \(visible)")
          for point in lines.joined() {
            XCTAssertTrue(point.x.isFinite && point.y.isFinite, "\(text.prefix(20)) in \(visible)")
            XCTAssertTrue((0...WhiteboardFrame.side).contains(point.x), "\(text.prefix(20)) in \(visible): \(point)")
            XCTAssertTrue((0...WhiteboardFrame.side).contains(point.y), "\(text.prefix(20)) in \(visible): \(point)")
          }
        }
      }
    }

    func testNothingWithAnOutlineMeansNoInk() {
      XCTAssertTrue(WhiteboardPaste.layout("   \n ", visible: view, height: 24).lines.isEmpty)
      XCTAssertTrue(WhiteboardPaste.layout("🎉🎉", visible: view, height: 24).lines.isEmpty)
      XCTAssertFalse(WhiteboardPaste.layout("🎉 yes", visible: view, height: 24).lines.isEmpty)
    }

    /// Stories 390, 391: each letter's outline is one stroke, a line at a time.
    /// #996: letters are written as a pen writes them, H in three strokes (two stems and its bar) and I in one, not
    /// each traced as one closed outline.
    func testEachLetterIsWrittenInItsOwnStrokes() throws {
      XCTAssertEqual(WhiteboardPaste.layout("HI", visible: view, height: 24).lines.count, 3 + 1)
      XCTAssertEqual(WhiteboardPaste.layout("HI\nHI", visible: view, height: 24).lines.count, 2 * (3 + 1))
      let l = try XCTUnwrap(WhiteboardPaste.layout("l", visible: view, height: 24).lines.first)
      XCTAssertNotEqual(l.first, l.last, "a written stem is an open line, where an outline closes on itself")
    }

    /// #996: a model's or a page's typography is written in its keyboard form, and a character the written letters
    /// lack keeps its outline, so nothing pasted goes missing.
    func testCurlyTypographyIsWrittenAndAnAccentIsStillDrawn() {
      let curly = WhiteboardPaste.layout("it\u{2019}s \u{2014} so\u{2026}", visible: view, height: 24)
      let plain = WhiteboardPaste.layout("it's - so...", visible: view, height: 24)
      XCTAssertEqual(curly.lines.count, plain.lines.count)
      XCTAssertGreaterThan(
        WhiteboardPaste.layout("cafe\u{301}", visible: view, height: 24).lines.count,
        WhiteboardPaste.layout("caf", visible: view, height: 24).lines.count + 1, "the e and its accent")
    }

    /// #996: rows are measured in the written letters: each fits the width, they break after spaces, and together
    /// they are the whole line, so the count of what landed holds.
    func testRowsFitTheWrittenWidthAndAreTheWholeLine() {
      let line = "the quick brown fox jumps over the lazy dog and keeps running"
      let rows = WhiteboardPaste.wrapped(line, width: 200, height: 24)
      XCTAssertGreaterThan(rows.count, 1)
      XCTAssertEqual(rows.joined(), line)
      for row in rows {
        let drawn = WhiteboardMarkChoice.bounds(WhiteboardTurn.glyphLines(row, topLeft: .zero, height: 24))
        XCTAssertLessThanOrEqual(drawn.maxX, 200, row)
      }
      XCTAssertTrue(rows.dropLast().allSatisfy { $0.hasSuffix(" ") }, "each break is after a space: \(rows)")
    }

    func testAWordWiderThanARowBreaksBetweenItsLetters() {
      let word = String(repeating: "m", count: 40)
      let rows = WhiteboardPaste.wrapped(word, width: 200, height: 24)
      XCTAssertGreaterThan(rows.count, 1)
      XCTAssertEqual(rows.joined(), word)
      for row in rows {
        XCTAssertLessThanOrEqual(
          WhiteboardMarkChoice.bounds(WhiteboardTurn.glyphLines(row, topLeft: .zero, height: 24)).maxX, 200)
      }
    }

    /// Stories 392, 393: what the board's bar says after a paste.
    func testTheNoteSaysHowMuchWasLeftOffOrThatNothingCanBeDrawn() {
      let long = WhiteboardPaste.layout(String(repeating: "I", count: 1234), visible: view, height: 24)
      XCTAssertEqual(long.lines.count, WhiteboardPaste.maxCharacters, "an I is one stroke, and the first 500 land")
      XCTAssertEqual(long.note, "Pasted the first 500 of \(1234.formatted()) characters")
      for nothing in ["🎉🎉", "   \n "] {
        XCTAssertEqual(
          WhiteboardPaste.layout(nothing, visible: view, height: 24).note, "Nothing in that text can be drawn", nothing)
      }
      XCTAssertNil(WhiteboardPaste.layout("HI", visible: view, height: 24).note, "a whole paste says nothing")
    }

    func testStaysOnTheBoardAtItsCorner() {
      let corner = CGRect(x: 19_900, y: 19_900, width: 100, height: 100)
      let box = bounds(WhiteboardPaste.layout("Hello there", visible: corner, height: 24).lines)
      XCTAssertLessThanOrEqual(box.maxX, WhiteboardFrame.side)
      XCTAssertLessThanOrEqual(box.maxY, WhiteboardFrame.side)
    }
  #endif
}
