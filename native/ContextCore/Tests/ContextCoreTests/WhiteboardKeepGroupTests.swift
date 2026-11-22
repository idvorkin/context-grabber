import Foundation
import XCTest

@testable import ContextCore

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// #942 (stories 995, 998–1000): Keep group keeps the chosen mark's whole reply as one group, and its buttons never sit under the
/// board's top-right corner. The oracle is the shapes spec's "Keep group keeps a whole reply as one thing".
final class WhiteboardKeepGroupTests: XCTestCase {
  private struct G: WhiteboardGhost, Equatable {
    let id: String
    let who: WhiteboardTurn.Who
  }

  private func turns() -> WhiteboardGhostTurns<G> {
    var turns = WhiteboardGhostTurns<G>(on: true, ghostLife: .seconds(30))
    turns.land([G(id: "c0", who: .claude)], who: .claude, first: true, now: .now)
    turns.larrysMarks([G(id: "r1#0", who: .larry), G(id: "r1#1", who: .larry), G(id: "r1#3", who: .larry)])
    turns.larrysText([G(id: "op-text:t", who: .larry)])
    return turns
  }

  func testAMarkBelongsToTheReplyItCameIn() {
    XCTAssertEqual(WhiteboardMarks.reply(of: WhiteboardMarks.mark(4, of: "12c6abcb46e7")), "12c6abcb46e7")
    XCTAssertNil(WhiteboardMarks.reply(of: "op-text:t"))
    XCTAssertNil(WhiteboardMarks.reply(of: "a#b"))
    XCTAssertEqual(WhiteboardMarks.group(reply: "12c6abcb46e7"), "reply-12c6abcb46e7")
  }

  func testKeepGroupTakesTheChosenMarksReplyAndNothingElse() {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "r1#1" })
    XCTAssertEqual(turns.chosenReply().map(\.id), ["r1#0", "r1#1", "r1#3"])
    XCTAssertEqual(turns.keepChosenReply().map(\.id), ["r1#0", "r1#1", "r1#3"], "in the order they came")
    XCTAssertEqual(turns.ghosts.map(\.id), ["c0", "op-text:t"], "Claude's and his text from a change stay")
    XCTAssertNil(turns.chosen, "the buttons went with the marks")
  }

  func testNoGroupForClaudeOrHisTextFromAChange() {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "c0" })
    XCTAssertEqual(turns.chosenReply(), [])
    _ = turns.tap(hitting: { $0.id == "op-text:t" })
    XCTAssertEqual(turns.keepChosenReply(), [])
    XCTAssertEqual(turns.ghosts.count, 5, "nothing kept")
  }

  /// Story 1145 (bead context-grabber-hm7n): Keep on one mark of a reply of Larry's takes every mark of it still
  /// showing; on Claude's mark, his text from a change, or the last of a reply, only that one; Dismiss only the one.
  func testKeepOnOneMarkOfAReplyTakesTheWholeReply() {
    var turns = turns()
    _ = turns.tap(hitting: { $0.id == "r1#1" })
    XCTAssertEqual(turns.keepChosenWithItsReply().map(\.id), ["r1#0", "r1#1", "r1#3"], "the whole reply, in order")
    XCTAssertEqual(turns.ghosts.map(\.id), ["c0", "op-text:t"], "Claude's and his text from a change stay")
    XCTAssertNil(turns.chosen)
    _ = turns.tap(hitting: { $0.id == "c0" })
    XCTAssertEqual(turns.keepChosenWithItsReply().map(\.id), ["c0"], "Claude's mark alone")
    _ = turns.tap(hitting: { $0.id == "op-text:t" })
    XCTAssertEqual(turns.keepChosenWithItsReply().map(\.id), ["op-text:t"], "his text from a change alone")
    XCTAssertEqual(turns.keepChosenWithItsReply(), [], "nothing chosen, nothing kept")

    var other = self.turns()
    _ = other.tap(hitting: { $0.id == "r1#0" })
    XCTAssertEqual(other.dismissChosen()?.id, "r1#0")
    XCTAssertEqual(
      other.ghosts.filter { $0.who == .larry }.map(\.id), ["r1#1", "r1#3", "op-text:t"], "Dismiss takes one")
    _ = other.tap(hitting: { $0.id == "r1#1" })
    _ = other.dismissChosen()
    _ = other.tap(hitting: { $0.id == "r1#3" })
    XCTAssertEqual(other.keepChosenWithItsReply().map(\.id), ["r1#3"], "the last of a reply, alone")
  }

  func testTheGroupsNotesNameTheReply() {
    let notes = WhiteboardMarks.groupNotes(["a", "b"], reply: "r1")
    XCTAssertEqual(notes.keys.sorted(), ["a", "b"])
    XCTAssertEqual(notes["a"]?.group, "reply-r1")
  }

  // MARK: Where the buttons go

  private let view = CGRect(x: 0, y: 0, width: 820, height: 1000)
  private let corner = CGRect(x: 560, y: 40, width: 240, height: 90)
  private let buttons = CGSize(width: 300, height: 44)

  func testButtonsUnderTheCornerMoveBelowIt() {
    let mark = CGRect(x: 600, y: 60, width: 150, height: 40)
    let placed = WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: view, avoid: corner)
    XCTAssertFalse(placed.intersects(corner), "\(placed)")
    XCTAssertGreaterThanOrEqual(placed.minY, corner.maxY)
    XCTAssertTrue(view.contains(placed))
  }

  func testButtonsClearOfTheCornerStayBesideTheirMark() {
    let mark = CGRect(x: 100, y: 500, width: 150, height: 60)
    XCTAssertEqual(
      WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: view, avoid: corner),
      WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: view))
  }

  func testWithNoRoomBelowTheyGoLeftOfTheCorner() {
    let short = CGRect(x: 0, y: 0, width: 820, height: 170)
    let mark = CGRect(x: 600, y: 60, width: 150, height: 40)
    let placed = WhiteboardMarkChoice.place(mark: mark, buttons: buttons, in: short, avoid: corner)
    XCTAssertLessThanOrEqual(placed.maxX, corner.minX)
  }

  func testInAViewNarrowerThanTheButtonsTheyNarrowToStayOnScreen() {
    let narrow = CGRect(x: 0, y: 0, width: 320, height: 600)
    let mark = CGRect(x: 40, y: 200, width: 100, height: 40)
    let placed = WhiteboardMarkChoice.place(mark: mark, buttons: CGSize(width: 400, height: 48), in: narrow)
    XCTAssertTrue(narrow.contains(placed), "\(placed)")
    XCTAssertEqual(placed.height, 48)
  }
}
