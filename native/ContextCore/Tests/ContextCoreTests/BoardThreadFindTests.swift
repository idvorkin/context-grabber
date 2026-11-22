import XCTest

@testable import ContextCore

/// #1163, stories 1097, 949: which chats may be a board's, and which one is.
final class BoardThreadFindTests: XCTestCase {
  private func thread(_ key: String, _ title: String, at ts: String) -> ChatSummary {
    ChatSummary(key: key, title: title, lastTs: ts, lastWho: "larry", lastText: "")
  }

  func testThreadsTitledWithTheBoardsNameComeFirstNewestFirst() {
    let threads = [
      thread("old", "Board, Nov 20 (2)", at: "2026-11-20T10:00:00+00:00"),
      thread("other", "Board, Nov 20", at: "2026-11-22T10:00:00+00:00"),
      thread("renamed", "Larry on Board, Nov 20 (2)", at: "2026-11-22T09:00:00+00:00"),
      thread("new", "board, nov 20 (2) ", at: "2026-11-21T10:00:00+00:00"),
      thread("pinned", "Larry", at: "2026-11-22T11:00:00+00:00"),
    ]
    XCTAssertEqual(BoardThreadFind.candidates(title: "Board, Nov 20 (2)", threads: threads), ["new", "old", "renamed"])
  }

  func testNoNameNoCandidatesAndAtMostFive() {
    let many = (0..<9).map { thread("t\($0)", "Board, Nov 1", at: "2026-11-0\($0 + 1)T00:00:00+00:00") }
    XCTAssertEqual(BoardThreadFind.candidates(title: "  ", threads: many), [])
    XCTAssertEqual(BoardThreadFind.candidates(title: "Board, Nov 1", threads: many).count, BoardThreadFind.mostChecked)
  }

  func testOnlyAMessageFromTheBoardMakesTheThreadItsOwn() {
    let words = ChatMessage(id: "1", ts: "", who: "igor", text: "Board, Nov 20")
    let fromBoard = ChatMessage(id: "2", ts: "", who: "igor", text: "Board, Nov 20", board: "5ebf7612")
    let otherBoard = ChatMessage(id: "3", ts: "", who: "igor", text: "Board, Nov 20", board: "ab54b1d6")
    XCTAssertTrue(BoardThreadFind.belongs(board: "5ebf7612", messages: [words, fromBoard]))
    XCTAssertFalse(
      BoardThreadFind.belongs(board: "5ebf7612", messages: [words, otherBoard]), "a shared name is not enough")
    XCTAssertFalse(BoardThreadFind.belongs(board: "", messages: [words]))
  }
}
