//  Stories 354, 1152, 1153 (context-grabber-2eml): whether a finger draws while marks show, and the Pencil's rule.

import ContextCore
import XCTest

final class WhiteboardFingerTests: XCTestCase {
  private typealias Verdict = WhiteboardFinger.Verdict

  /// context-grabber-egdh item 2: the board's one fingertip. Every finger tap and hold (a group, Larry's ink, the hold
  /// menu, a reword, a tap's dot) reaches this far, in screen points, divided by the zoom.
  func testTheBoardsFingertipIs22ScreenPoints() {
    XCTAssertEqual(WhiteboardTurn.tapReach, 22)
  }

  func testWithNothingShowingAFingerDoesWhatItUsuallyDoes() {
    XCTAssertEqual(WhiteboardFinger().verdict, Verdict(usual: true, why: .noMarks))
  }

  func testMarksShowingSetAFingerToTapAndPan() {
    var finger = WhiteboardFinger()
    finger.marks(true)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .marks))
  }

  /// Story 1152: Igor's iPad, 2026-11-22: a tap off left his finger panning.
  func testATapOffEmptyBoardGivesTheFingerItsPenBackWithTheMarksStillShowing() {
    var finger = WhiteboardFinger()
    finger.marks(true)
    finger.tapped(onMark: false, onSelection: false)
    XCTAssertEqual(finger.verdict, Verdict(usual: true, why: .tapOff))
    finger.marks(true)
    XCTAssertEqual(finger.verdict, Verdict(usual: true, why: .tapOff), "more marks arriving keep the pen")
  }

  func testATapOnAMarkOrOnHisSelectionKeepsTheFingerTapping() {
    var finger = WhiteboardFinger()
    finger.marks(true)
    finger.tapped(onMark: true, onSelection: false)
    XCTAssertEqual(finger.verdict.why, .marks)
    finger.tapped(onMark: false, onSelection: true)
    XCTAssertEqual(finger.verdict.why, .marks)
  }

  func testATapWithNoMarksShowingGivesNothingAndNoMarksLeftForgetsATapOff() {
    var finger = WhiteboardFinger()
    finger.tapped(onMark: false, onSelection: false)
    finger.marks(true)
    XCTAssertEqual(finger.verdict.why, .marks, "a tap before the marks came isn't a tap off them")
    finger.tapped(onMark: false, onSelection: false)
    finger.marks(false)
    XCTAssertEqual(finger.verdict, Verdict(usual: true, why: .noMarks))
    finger.marks(true)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .marks), "the next marks set it tapping again")
  }

  /// Story 846: his controls alone set a finger tapping, and a tap off his marks doesn't outlast them.
  func testHisControlsAloneSetAFingerTappingEvenAfterATapOff() {
    var finger = WhiteboardFinger()
    finger.marks(false, controls: true)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .marks))
    finger.marks(true, controls: true)
    finger.tapped(onMark: false, onSelection: false)
    XCTAssertEqual(finger.verdict, Verdict(usual: true, why: .tapOff))
    finger.marks(false, controls: true)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .marks), "no mark left, his controls still showing")
  }

  /// Story 846: with his controls alone showing, a finger tap off them leaves the finger tapping.
  func testATapWithOnlyHisControlsShowingKeepsTheFingerTapping() {
    var finger = WhiteboardFinger()
    finger.marks(false, controls: true)
    finger.tapped(onMark: false, onSelection: false)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .marks))
  }

  /// Story 1153: "I should never have finger drawn if I'm using the pencil."
  func testOnceThePencilHasTouchedAFingerNeverDraws() {
    var finger = WhiteboardFinger()
    finger.pencilTouched()
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .pencil), "with no marks")
    finger.marks(true)
    finger.tapped(onMark: false, onSelection: false)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .pencil), "a tap off doesn't give it a pen")
    finger.marks(false)
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .pencil))
    let later = WhiteboardFinger(pencil: true)
    XCTAssertEqual(later.verdict.why, .pencil, "a board opened after the Pencil touched another")
  }

  func testThePencilAfterATapOffTakesTheFingersPen() {
    var finger = WhiteboardFinger()
    finger.marks(true)
    finger.tapped(onMark: false, onSelection: false)
    finger.pencilTouched()
    XCTAssertEqual(finger.verdict, Verdict(usual: false, why: .pencil))
  }

  func testThePencilHookParses() {
    XCTAssertTrue(WhiteboardHooks(["GRABBER_WHITEBOARD_PENCIL": "seen"]).pencilSeen)
    XCTAssertFalse(WhiteboardHooks([:]).pencilSeen)
    XCTAssertTrue(WhiteboardHooks(["GRABBER_WHITEBOARD_FINGER_LABEL": "1"]).fingerLabel)
    XCTAssertFalse(WhiteboardHooks([:]).fingerLabel)
  }
}
