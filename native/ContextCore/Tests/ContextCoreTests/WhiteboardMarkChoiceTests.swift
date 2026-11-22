import Foundation
import XCTest

@testable import ContextCore

/// Stories 825, 808, 809, 810 (#883): a tap on a mark shows Keep and Dismiss beside it, a stray tap or a stroke puts them away and
/// changes nothing, Keep is the old keep and Dismiss removes that one mark. The oracle is the shapes spec's "A tap on a
/// mark offers Keep and Dismiss".
final class WhiteboardMarkChoiceTests: XCTestCase {
  private struct G: WhiteboardGhost, Equatable {
    let id: String
    let who: WhiteboardTurn.Who
  }

  private let t0 = ContinuousClock.now

  private func board(claude: Int = 1, larry: Int = 2) -> (WhiteboardGhostTurns<G>, [G], [G]) {
    var turns = WhiteboardGhostTurns<G>(on: true, ghostLife: .seconds(30))
    let claudes = (0..<claude).map { G(id: "c\($0)", who: .claude) }
    let larrys = (0..<larry).map { G(id: "l\($0)", who: .larry) }
    turns.land(claudes, who: .claude, first: true, now: t0)
    turns.larrysMarks(larrys)
    return (turns, claudes, larrys)
  }

  // MARK: A tap on his selection (story 966, #1170)

  func testATapInsideHisSelectionOffTheMarksKeepsIt() {
    // The iPad's #1170: "OK, ah 2" selected at [66, 1717, 139, 92], tapped at (124.5, 1729.5), no mark chosen.
    let box = CGRect(x: 66, y: 1717, width: 139, height: 92)
    XCTAssertTrue(WhiteboardMarkChoice.onSelection(box, at: CGPoint(x: 124.5, y: 1729.5), reach: 22, onMark: false))
    XCTAssertTrue(
      WhiteboardMarkChoice.onSelection(box, at: CGPoint(x: 60, y: 1700), reach: 22, onMark: false),
      "a fingertip's reach round the box counts")
  }

  func testATapOnAMarkOrOffTheSelectionLetsItGo() {
    let box = CGRect(x: 66, y: 1717, width: 139, height: 92)
    XCTAssertFalse(
      WhiteboardMarkChoice.onSelection(box, at: CGPoint(x: 124.5, y: 1729.5), reach: 22, onMark: true),
      "a mark in reach takes the tap")
    XCTAssertFalse(WhiteboardMarkChoice.onSelection(box, at: CGPoint(x: 400, y: 1729.5), reach: 22, onMark: false))
    XCTAssertFalse(
      WhiteboardMarkChoice.onSelection(.null, at: CGPoint(x: 124.5, y: 1729.5), reach: 22, onMark: false),
      "nothing selected")
  }

  // MARK: Which mark a tap chooses

  func testATapOnAMarkChoosesItAndChangesNothing() {
    var (turns, claudes, larrys) = board()
    guard case .chose(let mark) = turns.tap(hitting: { $0 == larrys[1] }) else { return XCTFail() }
    XCTAssertEqual(mark, larrys[1])
    XCTAssertEqual(turns.chosen, larrys[1])
    XCTAssertEqual(turns.ghosts, claudes + larrys, "nothing kept or dismissed yet")
  }

  func testATapOnAnotherMarkMovesTheButtons() {
    var (turns, claudes, larrys) = board()
    _ = turns.tap(hitting: { $0 == larrys[0] })
    guard case .chose(let mark) = turns.tap(hitting: { $0 == claudes[0] }) else { return XCTFail() }
    XCTAssertEqual(mark, claudes[0])
    XCTAssertEqual(turns.chosen, claudes[0])
  }

  func testATapOnTheChosenMarkAgainLeavesTheButtons() {
    var (turns, _, larrys) = board()
    _ = turns.tap(hitting: { $0 == larrys[0] })
    guard case .nothing = turns.tap(hitting: { $0 == larrys[0] }) else { return XCTFail() }
    XCTAssertEqual(turns.chosen, larrys[0])
  }

  func testAStrayTapPutsTheButtonsAwayAndDismissesNothing() {
    var (turns, claudes, larrys) = board()
    guard case .nothing = turns.tap(hitting: { _ in false }) else {
      return XCTFail("no buttons: a stray tap does nothing")
    }
    XCTAssertEqual(turns.ghosts, claudes + larrys)
    _ = turns.tap(hitting: { $0 == larrys[0] })
    guard case .putAway = turns.tap(hitting: { _ in false }) else { return XCTFail() }
    XCTAssertNil(turns.chosen)
    XCTAssertEqual(turns.ghosts, claudes + larrys, "Claude's and Larry's all stay")
  }

  func testATapWithNoMarksDoesNothing() {
    var turns = WhiteboardGhostTurns<G>(on: true, ghostLife: .seconds(30))
    guard case .nothing = turns.tap(hitting: { _ in true }) else { return XCTFail() }
  }

  func testStartingToDrawPutsTheButtonsAway() {
    var (turns, claudes, larrys) = board()
    XCTAssertFalse(turns.toolWentDown(), "nothing showing to put away")
    _ = turns.tap(hitting: { $0 == claudes[0] })
    XCTAssertTrue(turns.toolWentDown())
    XCTAssertNil(turns.chosen)
    XCTAssertEqual(turns.ghosts, claudes + larrys)
  }

  func testTheButtonsGoWithTheirMark() {
    var (turns, claudes, _) = board()
    _ = turns.tap(hitting: { $0 == claudes[0] })
    turns.fade(now: t0 + .seconds(31))
    XCTAssertNil(turns.chosen, "Claude's faded, and the buttons with it")
    let fresh = [G(id: "c-new", who: .claude)]
    turns.land(fresh, who: .claude, first: true, now: t0 + .seconds(40))
    XCTAssertNil(turns.chosen, "a new mark is never chosen by an old tap")
  }

  // MARK: Keep and Dismiss

  func testKeepTakesTheChosenMarkOffTheGhosts() {
    var (turns, claudes, larrys) = board()
    _ = turns.tap(hitting: { $0 == larrys[1] })
    XCTAssertEqual(turns.keepChosen(), larrys[1])
    XCTAssertNil(turns.chosen)
    XCTAssertEqual(turns.ghosts, claudes + [larrys[0]])

    _ = turns.tap(hitting: { $0 == claudes[0] })
    XCTAssertEqual(turns.keepChosen(), claudes[0])
    XCTAssertNil(turns.keepChosen(), "nothing chosen, nothing kept")
  }

  func testDismissRemovesOnlyThatMark() {
    var (turns, claudes, larrys) = board()
    _ = turns.tap(hitting: { $0 == larrys[0] })
    XCTAssertEqual(turns.dismissChosen(), larrys[0])
    XCTAssertNil(turns.chosen)
    XCTAssertEqual(turns.ghosts, claudes + [larrys[1]])
    XCTAssertNil(turns.dismissChosen())
  }

  func testDismissingOneOfClaudesLetsTheRestOfHisAnswerLand() {
    var (turns, claudes, _) = board(claude: 2, larry: 0)
    XCTAssertTrue(turns.stroked())
    XCTAssertTrue(turns.pauseEnded())
    let asked = turns.asked(.claude)
    _ = turns.tap(hitting: { $0 == claudes[0] })
    XCTAssertEqual(turns.dismissChosen(), claudes[0])
    XCTAssertTrue(turns.current(asked), "one mark dismissed doesn't send the turn away")
    XCTAssertEqual(turns.ghosts, [claudes[1]])
  }

  // MARK: Where the buttons sit

  private let view = CGRect(x: 0, y: 0, width: 800, height: 1000)
  private let size = CGSize(width: 160, height: 44)

  private func onScreen(_ place: CGRect, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(view.insetBy(dx: 8, dy: 8).contains(place), "\(place) is on screen", file: file, line: line)
  }

  func testBesideTheMarkToItsRight() {
    let mark = CGRect(x: 100, y: 400, width: 120, height: 60)
    let place = WhiteboardMarkChoice.place(mark: mark, buttons: size, in: view)
    XCTAssertEqual(place.minX, mark.maxX + WhiteboardMarkChoice.gap)
    XCTAssertEqual(place.midY, mark.midY)
    XCTAssertFalse(place.intersects(mark))
    onScreen(place)
  }

  func testAtTheRightEdgeOnItsLeft() {
    let mark = CGRect(x: 700, y: 400, width: 95, height: 60)
    let place = WhiteboardMarkChoice.place(mark: mark, buttons: size, in: view)
    XCTAssertEqual(place.maxX, mark.minX - WhiteboardMarkChoice.gap)
    XCTAssertFalse(place.intersects(mark))
    onScreen(place)
  }

  func testAMarkAsWideAsTheViewGetsThemBelowOrAbove() {
    let wide = CGRect(x: 0, y: 300, width: 800, height: 80)
    let below = WhiteboardMarkChoice.place(mark: wide, buttons: size, in: view)
    XCTAssertEqual(below.minY, wide.maxY + WhiteboardMarkChoice.gap)
    onScreen(below)
    let low = CGRect(x: 0, y: 900, width: 800, height: 95)
    let above = WhiteboardMarkChoice.place(mark: low, buttons: size, in: view)
    XCTAssertEqual(above.maxY, low.minY - WhiteboardMarkChoice.gap)
    onScreen(above)
  }

  func testAtTheTopOrBottomEdgeTheyStayOnScreen() {
    for mark in [
      CGRect(x: 100, y: -40, width: 80, height: 50), CGRect(x: 100, y: 980, width: 80, height: 60),
      CGRect(x: -50, y: 500, width: 60, height: 40), CGRect(x: 790, y: 990, width: 50, height: 50),
    ] {
      onScreen(WhiteboardMarkChoice.place(mark: mark, buttons: size, in: view))
    }
  }

  func testAMarkCoveringTheViewStillGetsThemOnScreen() {
    onScreen(WhiteboardMarkChoice.place(mark: view.insetBy(dx: -100, dy: -100), buttons: size, in: view))
  }

  func testAMarksBoxIsItsLinesBox() {
    let box = WhiteboardMarkChoice.bounds([[CGPoint(x: 10, y: 20), CGPoint(x: 50, y: 5)], [CGPoint(x: 30, y: 60)]])
    XCTAssertEqual(box, CGRect(x: 10, y: 5, width: 40, height: 55))
    XCTAssertTrue(WhiteboardMarkChoice.bounds([]).isNull)
  }
}
