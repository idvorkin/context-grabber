import XCTest

@testable import ContextCore

/// Story 749: two quick Returns at the end of a chat message send it, the trailing blank lines taken off.
final class ChatDoubleEnterTests: XCTestCase {
  /// Feeds each text in turn at its time, as the bar's field would, and returns what the last change asked for.
  private func type(_ steps: [(String, Int64)], from start: String = "") -> (
    ChatDoubleEnter.Send?, [ChatDoubleEnter.Send]
  ) {
    var rule = ChatDoubleEnter()
    var old = start
    var sends: [ChatDoubleEnter.Send] = []
    var last: ChatDoubleEnter.Send?
    for (text, at) in steps {
      last = rule.change(from: old, to: text, at: at)
      if let last { sends.append(last) }
      old = text
    }
    return (last, sends)
  }

  func testTwoQuickReturnsAtTheEndSendTheWordsTrimmed() {
    let (send, _) = type([("see you at noon", 0), ("see you at noon\n", 1_000), ("see you at noon\n\n", 1_200)])
    XCTAssertEqual(send, .init(text: "see you at noon", gapMs: 200))
  }

  func testTheWindowIsFourHundredMillisecondsInclusive() {
    XCTAssertEqual(ChatDoubleEnter.windowMs, 400)
    let (atEdge, _) = type([("hi", 0), ("hi\n", 1_000), ("hi\n\n", 1_400)])
    XCTAssertEqual(atEdge, .init(text: "hi", gapMs: 400))
    let (past, sends) = type([("hi", 0), ("hi\n", 1_000), ("hi\n\n", 1_401)])
    XCTAssertNil(past, "a slow second Return is a blank line")
    XCTAssertTrue(sends.isEmpty)
  }

  func testASlowPairArmsAgainSoAThirdQuickReturnSends() {
    let (send, sends) = type([("hi", 0), ("hi\n", 1_000), ("hi\n\n", 3_000), ("hi\n\n\n", 3_100)])
    XCTAssertEqual(send, .init(text: "hi", gapMs: 100))
    XCTAssertEqual(sends.count, 1)
  }

  func testDictationsTwoNewLinesInOneChangeSend() {
    let (send, _) = type([("see you at noon\n\n", 500)])
    XCTAssertEqual(send, .init(text: "see you at noon", gapMs: nil))
    let (withWords, _) = type([("see you", 0), ("see you at noon\n\n", 500)])
    XCTAssertEqual(withWords, .init(text: "see you at noon", gapMs: nil), "words and both new lines in one go")
    let (crlf, _) = type([("ok\r\n\r\n", 0)])
    XCTAssertEqual(crlf, .init(text: "ok", gapMs: nil), "carriage-return line ends count as new lines")
  }

  func testAReturnThatCommitsAnAutocorrectionStillCountsAsTheFirst() {
    let (send, _) = type([("teh", 0), ("the\n", 1_000), ("the\n\n", 1_150)])
    XCTAssertEqual(send, .init(text: "the", gapMs: 150))
  }

  func testTrailingSpacesAreTakenOffWithTheNewLines() {
    let (send, _) = type([("ok  ", 0), ("ok  \n", 1_000), ("ok  \n \n", 1_100)])
    XCTAssertEqual(send?.text, "ok")
  }

  func testLeadingAndInnerLinesAreKept() {
    let (send, _) = type([("  first\n\nsecond", 0), ("  first\n\nsecond\n", 1_000), ("  first\n\nsecond\n\n", 1_100)])
    XCTAssertEqual(send?.text, "  first\n\nsecond")
  }

  func testReturnsInTheMiddleAreOrdinaryNewLines() {
    let (send, sends) = type([("ab", 0), ("a\nb", 1_000), ("a\n\nb", 1_100)])
    XCTAssertNil(send)
    XCTAssertTrue(sends.isEmpty)
  }

  func testAnEmptyOrBlankBarNeverSends() {
    XCTAssertTrue(type([("\n", 0), ("\n\n", 100)]).1.isEmpty)
    XCTAssertTrue(type([("\n\n", 0)]).1.isEmpty)
    XCTAssertTrue(type([("   ", 0), ("   \n", 1_000), ("   \n\n", 1_100)]).1.isEmpty)
  }

  func testTypingBetweenTheReturnsDisarms() {
    let (send, sends) = type([("hi", 0), ("hi\n", 1_000), ("hi\nx", 1_050), ("hi\n", 1_100), ("hi\n\n", 1_150)])
    XCTAssertEqual(send, .init(text: "hi", gapMs: 50), "the deleted x re-armed at 1100, from the end's one new line")
    XCTAssertEqual(sends.count, 1)
    let (afterDelete, _) = type([("hi", 0), ("hi\n", 1_000), ("hi", 1_050), ("hi", 1_060)])
    XCTAssertNil(afterDelete)
  }

  func testAWriteTheBarMadeItselfIsNotTyping() {
    var rule = ChatDoubleEnter()
    let quote = "> Larry's words\n\n"
    rule.willWrite(quote)
    XCTAssertNil(rule.change(from: "", to: quote, at: 0), "Quote in reply sends nothing")
    XCTAssertNil(rule.change(from: quote, to: quote + "ok", at: 1_000))
    XCTAssertNil(rule.change(from: quote + "ok", to: quote + "ok\n", at: 2_000))
    XCTAssertEqual(
      rule.change(from: quote + "ok\n", to: quote + "ok\n\n", at: 2_100),
      .init(text: "> Larry's words\n\nok", gapMs: 100))
  }

  func testAWriteThatDidNotChangeTheTextDoesNotSwallowTheNextChange() {
    var rule = ChatDoubleEnter()
    rule.willWrite("hi")
    XCTAssertEqual(rule.change(from: "hi", to: "hi\n\n", at: 0), .init(text: "hi", gapMs: nil))
  }

  func testAClockThatGoesBackDoesNotSend() {
    let (send, _) = type([("hi", 0), ("hi\n", 1_000), ("hi\n\n", 900)])
    XCTAssertNil(send)
  }
}
