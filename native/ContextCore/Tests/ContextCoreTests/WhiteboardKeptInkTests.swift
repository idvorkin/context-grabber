//  Story 650: a kept mark's look a second on, from the numbers `paper_kept_ink` logged on the iPad simulator.

import ContextCore
import XCTest

final class WhiteboardKeptInkTests: XCTestCase {
  private let purple = [186, 57, 230]

  /// context-grabber-qko5: Larry's 12-point label kept whole at Igor's 2.68 pen. The view's purple spans 32 x 9; the strokes
  /// drawn alone touch 34 x 13 but their own purple spans 24 x 6. It read as cut on every look, and was redrawn twice.
  func testASmallLabelDrawnWholeIsWhole() {
    let drawn = KeptInkColours(ink: 33, other: 168, inkWidth: 32, inkHeight: 9)
    let expected = KeptInkColours(ink: 9, inkWidth: 24, inkHeight: 6, allWidth: 34, allHeight: 13)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple))
  }

  /// context-grabber-ikya, as logged on the iPad Pro 11-inch (M5) simulator: Larry's 13-glyph text drawn in his purple
  /// only up to a tile's edge, 16 of its 155 pixels.
  func testATextCutAtATileEdgeIsCut() {
    let drawn = KeptInkColours(ink: 22, other: 61, inkWidth: 16, inkHeight: 14)
    let expected = KeptInkColours(ink: 31, inkWidth: 71, inkHeight: 13, allWidth: 157, allHeight: 24)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "cut")
  }

  /// context-grabber-smmj: the same thin 13-glyph text drawn whole, twice, on the iPad Pro 11-inch (M5) simulator. Its
  /// strokes drawn alone kept little true purple, 71 pixels wide one time and 149 the next; every pixel they touch spanned
  /// 157 by 24 both times. Both whole.
  func testAThinTextDrawnWholeIsWholeHoweverLittleColourItKeepsAlone() {
    let first = KeptInkColours(ink: 264, other: 443, inkWidth: 155, inkHeight: 21)
    let firstAlone = KeptInkColours(ink: 31, inkWidth: 71, inkHeight: 13, allWidth: 157, allHeight: 24)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: first, expected: firstAlone, darkBefore: 0, ink: purple))
    let second = KeptInkColours(ink: 152, other: 622, inkWidth: 154, inkHeight: 20)
    let secondAlone = KeptInkColours(ink: 40, inkWidth: 149, inkHeight: 14, allWidth: 157, allHeight: 24)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: second, expected: secondAlone, darkBefore: 0, ink: purple))
  }

  /// context-grabber-smmj: judged against the 71 pixels of purple its strokes kept alone, that text cut at a tile edge
  /// 60 pixels in read as whole (cut fired only under about 53). Against what they touch, less the soft edge, it's cut.
  func testAThinTextCutPartWayIsCutEvenWhenItsColourAloneIsNoisy() {
    let drawn = KeptInkColours(ink: 100, other: 180, inkWidth: 60, inkHeight: 21)
    let expected = KeptInkColours(ink: 31, inkWidth: 71, inkHeight: 13, allWidth: 157, allHeight: 24)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "cut")
    XCTAssertEqual(WhiteboardKeptInk.wholeSpan(expected).width, 153)
  }

  /// A thick mark keeps its colour to its edge drawn alone, so it's judged by that colour, as before: Larry's 3-stroke
  /// box on the iPad simulator, whole (63 of 64) and cut at a tile edge (19 of 64).
  func testAThickMarkIsJudgedByItsOwnColour() {
    let alone = KeptInkColours(ink: 456, inkWidth: 64, inkHeight: 23, allWidth: 66, allHeight: 25)
    XCTAssertEqual(WhiteboardKeptInk.wholeSpan(alone).width, 64)
    let whole = KeptInkColours(ink: 475, other: 314, inkWidth: 63, inkHeight: 23)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: whole, expected: alone, darkBefore: 0, ink: purple))
    let cut = KeptInkColours(ink: 133, dark: 360, other: 315, inkWidth: 19, inkHeight: 23)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: cut, expected: alone, darkBefore: 0, ink: purple), "cut")
  }

  /// Whole kept labels on the real iPad (2026-11-22, 21:24 session): 38, 17 and 1 strokes of Larry's purple.
  func testWholeLabelsOnTheIPadAreWhole() {
    let cases: [(KeptInkColours, KeptInkColours)] = [
      (
        KeptInkColours(ink: 387, inkWidth: 269, inkHeight: 27),
        KeptInkColours(ink: 285, inkWidth: 269, inkHeight: 28, allWidth: 272, allHeight: 28)
      ),
      (
        KeptInkColours(ink: 207, inkWidth: 162, inkHeight: 31),
        KeptInkColours(ink: 147, inkWidth: 160, inkHeight: 31, allWidth: 164, allHeight: 33)
      ),
      (
        KeptInkColours(ink: 71, inkWidth: 11, inkHeight: 11),
        KeptInkColours(ink: 67, inkWidth: 10, inkHeight: 11, allWidth: 12, allHeight: 12)
      ),
    ]
    for (drawn, alone) in cases {
      XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: alone, darkBefore: 0, ink: purple))
    }
  }

  /// The small label with its right half left blank is still found.
  func testASmallLabelHalfDrawnIsCut() {
    let drawn = KeptInkColours(ink: 16, other: 80, inkWidth: 16, inkHeight: 9)
    let expected = KeptInkColours(ink: 9, inkWidth: 24, inkHeight: 6, allWidth: 34, allHeight: 13)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "cut")
  }

  /// A whole text drawn black past a tile's edge: its purple spans as far, but black the keep added is there.
  func testATileDrawnBlackIsDark() {
    let drawn = KeptInkColours(ink: 200, dark: 60, inkWidth: 120, inkHeight: 24)
    let expected = KeptInkColours(ink: 260, inkWidth: 120, inkHeight: 24, allWidth: 124, allHeight: 28)
    XCTAssertEqual(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple), "dark")
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 50, ink: purple))
  }

  /// A pen too thin to draw (#883): its strokes alone show none of their colour, so nothing is judged, and it's said so.
  func testAPenTooThinIsNeitherCutNorWhole() {
    let drawn = KeptInkColours()
    let expected = KeptInkColours(allWidth: 34, allHeight: 12)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: drawn, expected: expected, darkBefore: 0, ink: purple))
    XCTAssertTrue(WhiteboardKeptInk.drewNothing(drawn: drawn, expected: expected))
  }

  /// Unread (none of the spot in view) is never cut.
  func testOutOfViewIsNotJudged() {
    let expected = KeptInkColours(ink: 260, inkWidth: 120, inkHeight: 24, allWidth: 124, allHeight: 28)
    XCTAssertNil(WhiteboardKeptInk.partMissing(drawn: .unread, expected: expected, darkBefore: 0, ink: purple))
  }

  /// The view moves a screen away only after a redraw in place left the mark partly drawn, and nothing after that.
  func testTheMoveAwayComesOnlyAfterARedrawInPlace() {
    XCTAssertEqual(WhiteboardKeptInk.heal(afterLook: 0), "readd")
    XCTAssertEqual(WhiteboardKeptInk.heal(afterLook: 1), "scroll")
    XCTAssertNil(WhiteboardKeptInk.heal(afterLook: 2))
  }

  func testTheLookLabelHook() {
    XCTAssertTrue(WhiteboardHooks(["GRABBER_WHITEBOARD_KEPT_INK_LABEL": "1"]).keptInkLabel)
    XCTAssertFalse(WhiteboardHooks([:]).keptInkLabel)
  }

  /// pbvt: a view drawn alone over a kept mark's spot leaves the rest of the picture transparent. Those pixels are no
  /// colour at all, not black: counted dark, every layer read `dark 442` (the whole spot) and named none of them.
  func testTransparentPixelsAreNotDark() {
    let paper = [255, 255, 255]
    // Four pixels, RGBA premultiplied: transparent, purple, black, paper.
    let bytes: [UInt8] = [0, 0, 0, 0, 186, 57, 230, 255, 0, 0, 0, 255, 255, 255, 255, 255]
    let sorted = WhiteboardKeptInk.sort(rgba: bytes, width: 4, height: 1, paper: paper, ink: purple)
    XCTAssertEqual(sorted.ink, 1)
    XCTAssertEqual(sorted.dark, 1)
    XCTAssertEqual(sorted.other, 0)
    XCTAssertEqual(sorted.allWidth, 2)
    XCTAssertEqual(sorted.inkWidth, 1)
  }

  /// A layer drawn alone has soft, partly transparent edges. Purple (186, 57, 230) at alpha 64 is stored premultiplied
  /// as (47, 14, 58), every channel under 80: read as stored it counted black. It's purple, and so is a half-alpha one.
  func testASoftEdgeOfTheInkIsInkNotDark() {
    let paper = [255, 255, 255]
    let bytes: [UInt8] = [47, 14, 58, 64, 93, 29, 115, 128]
    let sorted = WhiteboardKeptInk.sort(rgba: bytes, width: 2, height: 1, paper: paper, ink: purple)
    XCTAssertEqual(sorted.ink, 2)
    XCTAssertEqual(sorted.dark, 0)
    XCTAssertEqual(sorted.other, 0)
  }

  /// Opaque pixels sort as before: the whole view's picture is opaque, so its numbers don't change.
  func testOpaquePixelsSortAsBefore() {
    let paper = [255, 255, 255]
    let bytes: [UInt8] = [186, 57, 230, 255, 190, 60, 225, 255, 10, 10, 10, 255, 120, 200, 120, 255]
    let sorted = WhiteboardKeptInk.sort(rgba: bytes, width: 2, height: 2, paper: paper, ink: purple)
    XCTAssertEqual(
      sorted, KeptInkColours(ink: 2, dark: 1, other: 1, inkWidth: 2, inkHeight: 1, allWidth: 2, allHeight: 2))
  }
}
