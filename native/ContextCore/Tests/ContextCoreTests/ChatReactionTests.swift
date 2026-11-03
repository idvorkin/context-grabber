import XCTest

@testable import ContextCore

/// What press and hold writes (#629, stories 501-503).
final class ChatReactionTests: XCTestCase {
  private func larry(_ text: String) -> ChatMessage { ChatMessage(id: "m", ts: "", who: "larry", text: text) }

  func testAReactionToTheNewestIsTheBareWord() {
    XCTAssertEqual(ChatReaction.yes.text(answering: larry("Ship it?"), newest: true), "Yes")
    XCTAssertEqual(ChatReaction.no.text(answering: larry("Ship it?"), newest: true), "No")
  }

  func testAReactionToAnOlderMessageGoesUnderItsQuote() {
    XCTAssertEqual(ChatReaction.no.text(answering: larry("Ship it?"), newest: false), "> Ship it?\n\nNo")
  }

  func testAPictureAloneIsQuotedAsAPicture() {
    let picture = ChatMessage(id: "m", ts: "", who: "larry", text: "  ", attachments: ["a.png"])
    XCTAssertEqual(ChatReaction.yes.text(answering: picture, newest: false), "> A picture\n\nYes")
  }

  func testEveryLineIsMarkedAndABlankLineHoldsTogether() {
    XCTAssertEqual(ChatQuote.quoted(larry("one\n\ntwo\n")), "> one\n>\n> two")
  }

  func testALongMessageIsCutToTheLimit() {
    let exact = String(repeating: "a", count: ChatQuote.maxCharacters)
    XCTAssertEqual(ChatQuote.quoted(larry(exact)), "> " + exact)
    let quote = ChatQuote.quoted(larry(exact + "b"))
    XCTAssertEqual(quote, "> " + String(repeating: "a", count: ChatQuote.maxCharacters - 1) + "…")
  }

  func testAQuoteIntoAnEmptyBarLeavesRoomForTheReply() {
    XCTAssertEqual(ChatQuote.appended(larry("Ship it?"), to: " \n"), "> Ship it?\n\n")
  }

  func testAQuoteFollowsWhatTheBarHeld() {
    XCTAssertEqual(ChatQuote.appended(larry("Ship it?"), to: "half typed"), "half typed\n\n> Ship it?\n\n")
  }

  func testTwoQuotesKeepBoth() {
    let first = ChatQuote.appended(larry("one"), to: "")
    XCTAssertEqual(ChatQuote.appended(larry("two"), to: first), "> one\n\n> two\n\n")
  }
}
