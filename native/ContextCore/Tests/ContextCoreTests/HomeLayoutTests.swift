import Foundation
import XCTest

@testable import ContextCore

/// Story 147: the home screen's order and hidden rows, remembered across builds.
final class HomeLayoutTests: XCTestCase {
  let known = ["call", "today", "gym_timer", "breathe", "places", "think_a_card", "cockpit"]

  func testNothingRememberedIsTheDefaultOrderAllShown() {
    let layout = HomeLayout(known: known, storedOrder: nil, storedHidden: nil)
    XCTAssertEqual(layout.order, known)
    XCTAssertEqual(layout.visible, known)
    XCTAssertEqual(HomeLayout(known: known, storedOrder: "", storedHidden: "").visible, known)
  }

  func testTheRememberedOrderAndHiddenRowsHold() {
    let layout = HomeLayout(
      known: known, storedOrder: "gym_timer,call,today,breathe,places,think_a_card,cockpit", storedHidden: "cockpit,places")
    XCTAssertEqual(layout.visible, ["gym_timer", "call", "today", "breathe", "think_a_card"])
    XCTAssertEqual(layout.encodedHidden, "places,cockpit")
  }

  func testARowTheOrderDoesNotKnowShowsAtTheEnd() {
    // Remembered by a build without Exercise Analyzer, read by one with it.
    let layout = HomeLayout(
      known: known + ["exercise_analyzer"], storedOrder: "cockpit,call,today,gym_timer,breathe,places,think_a_card",
      storedHidden: "today")
    XCTAssertEqual(layout.order.last, "exercise_analyzer")
    XCTAssertTrue(layout.isShown("exercise_analyzer"))
    XCTAssertEqual(layout.visible.first, "cockpit")
  }

  func testRowsTheBuildNoLongerHasAreDroppedAndDuplicatesIgnored() {
    let layout = HomeLayout(known: ["call", "today"], storedOrder: "card, today ,today,call", storedHidden: "card")
    XCTAssertEqual(layout.order, ["today", "call"])
    XCTAssertEqual(layout.hidden, [])
    XCTAssertEqual(layout.encodedOrder, "today,call")
  }

  func testHidingAndShowingKeepsTheRowInPlace() {
    var layout = HomeLayout(known: known, storedOrder: nil, storedHidden: nil)
    layout.setShown("today", false)
    XCTAssertEqual(layout.visible, ["call", "gym_timer", "breathe", "places", "think_a_card", "cockpit"])
    layout.setShown("today", true)
    XCTAssertEqual(layout.visible, known)
    layout.setShown("nonsense", false)
    XCTAssertEqual(layout.hidden, [])
  }

  func testMovesFollowTheListConvention() {
    var layout = HomeLayout(known: known, storedOrder: nil, storedHidden: nil)
    layout.move(fromOffsets: [2], toOffset: 0)  // Gym Timer dragged to the top
    XCTAssertEqual(layout.order, ["gym_timer", "call", "today", "breathe", "places", "think_a_card", "cockpit"])
    layout.move(fromOffsets: [0], toOffset: 7)  // and back down to the end
    XCTAssertEqual(layout.order, ["call", "today", "breathe", "places", "think_a_card", "cockpit", "gym_timer"])
    layout.move(fromOffsets: [1], toOffset: 3)  // Today below Box breathing
    XCTAssertEqual(layout.order, ["call", "breathe", "today", "places", "think_a_card", "cockpit", "gym_timer"])
  }

  func testWhatIsStoredReadsBackTheSame() {
    var layout = HomeLayout(known: known, storedOrder: nil, storedHidden: nil)
    layout.move(fromOffsets: [6], toOffset: 1)
    layout.setShown("places", false)
    let again = HomeLayout(known: known, storedOrder: layout.encodedOrder, storedHidden: layout.encodedHidden)
    XCTAssertEqual(again, layout)
  }

  /// Story 151: Today is the card, the next four the tiles, the rest rows.
  func testTodayIsTheCardTheNextFourTilesTheRestRows() {
    let a = HomeLayout(known: known, storedOrder: nil, storedHidden: nil).arrangement
    XCTAssertTrue(a.todayCard)
    XCTAssertEqual(a.tiles, ["call", "gym_timer", "breathe", "places"])
    XCTAssertEqual(a.rows, ["think_a_card", "cockpit"])
  }

  func testHidingTodayDropsTheCardAndMovingARowUpMakesItATile() {
    let layout = HomeLayout(
      known: known, storedOrder: (["cockpit"] + known.filter { $0 != "cockpit" }).joined(separator: ","),
      storedHidden: "today")
    XCTAssertFalse(layout.arrangement.todayCard)
    XCTAssertEqual(layout.arrangement.tiles.first, "cockpit")
    XCTAssertEqual(layout.arrangement.rows, ["places", "think_a_card"])
  }
}
