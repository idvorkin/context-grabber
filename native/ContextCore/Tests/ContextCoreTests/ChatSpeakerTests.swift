import XCTest

@testable import ContextCore

/// Stories 1614, 1615, 1077: the three voices (the Cockpit's cockpit_core.js chatSpeaker and chatIsGroup, ported), a
/// call's thread rows answering nobody, and Larry's own caption lines.
final class ChatSpeakerTests: XCTestCase {
  private func larry(_ id: String, author: String? = nil, error: Bool = false) -> ChatMessage {
    ChatMessage(id: id, ts: "", who: "larry", text: "x", author: author, isError: error)
  }
  private func igor(_ id: String) -> ChatMessage { ChatMessage(id: id, ts: "", who: "igor", text: "x") }

  func testAuthorNamedLarryIsLarryNotASkill() {
    XCTAssertEqual(ChatSpeaker.of(larry("1", author: "larry")).tone, .agent)
    XCTAssertEqual(ChatSpeaker.of(larry("1", author: "Larry")).label, "Larry")
    XCTAssertEqual(ChatSpeaker.of(larry("1")).tone, .agent)
    XCTAssertNil(ChatSpeaker.skillAuthor(larry("1", author: "larry")))
  }

  func testTonyIsTheVoiceAndOthersAreSkills() {
    let tony = ChatSpeaker.of(larry("1", author: "tony"))
    XCTAssertEqual(tony.tone, .voice)
    XCTAssertEqual(tony.label, "Tony")
    XCTAssertEqual(tony.initial, "T")
    let skill = ChatSpeaker.of(larry("1", author: "idvorkin"))
    XCTAssertEqual(skill.tone, .skill)
    XCTAssertEqual(skill.label, "idvorkin")
    XCTAssertEqual(ChatSpeaker.skillAuthor(larry("1", author: "idvorkin")), "idvorkin")
    XCTAssertEqual(ChatSpeaker.of(igor("1")).tone, .principal)
  }

  func testTwoSpeakersBesidesIgorMakeAGroup() {
    XCTAssertTrue(ChatSpeaker.isGroup([igor("0"), larry("1"), larry("2", author: "tony")]))
    XCTAssertTrue(ChatSpeaker.isGroup([larry("1", author: "larry"), larry("2", author: "idvorkin")]))
  }

  func testOneSpeakerOrAnOpenerIsNoGroup() {
    XCTAssertFalse(ChatSpeaker.isGroup([igor("0"), larry("1"), larry("2", author: "larry")]))
    XCTAssertFalse(ChatSpeaker.isGroup([larry("page-opener-1", author: "tony"), larry("2")]))
    XCTAssertFalse(ChatSpeaker.isGroup([larry("call-thread-open-9", author: "tony"), larry("2")]))
    XCTAssertFalse(ChatSpeaker.isGroup([ChatMessage(id: "s", ts: "", who: "system", text: "x"), larry("2")]))
  }

  func testACallsThreadRowsAnswerNobody() {
    XCTAssertTrue(ChatSpeaker.answersNobody(larry("call-thread-77")))
    XCTAssertTrue(ChatSpeaker.answersNobody(larry("page-opener-3")))
    XCTAssertFalse(ChatSpeaker.answersNobody(larry("abc")))
  }

  func testAFailureThenOnlyCallRowsStillFails() {
    let rows = [igor("me"), larry("f", error: true), larry("call-thread-summary-1")]
    XCTAssertEqual(ChatWire.answerFailed(rows), ["me"])
    XCTAssertEqual(ChatWire.answerFailed(rows + [larry("real")]), [])
  }

  func testLarrysOwnCaptionLines() {
    XCTAssertTrue(CaptionWho.tool.isLarrysOwn(on: .eleven))
    XCTAssertTrue(CaptionWho.note.isLarrysOwn(on: .drill))
    XCTAssertTrue(CaptionWho.larry.isLarrysOwn(on: .direct))
    XCTAssertFalse(CaptionWho.larry.isLarrysOwn(on: .eleven))
    XCTAssertFalse(CaptionWho.igor.isLarrysOwn(on: .direct))
  }

  func testTheListNamesLarryNotLowercaseLarry() {
    let row = ChatSummary(key: "k", title: "t", lastTs: "", lastWho: "larry", lastText: "hi", lastAuthor: "larry")
    XCTAssertEqual(row.lastSpeaker, "Larry")
    let tony = ChatSummary(key: "k", title: "t", lastTs: "", lastWho: "larry", lastText: "hi", lastAuthor: "tony")
    XCTAssertEqual(tony.lastSpeaker, "Tony")
  }
}
