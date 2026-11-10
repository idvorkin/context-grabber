import XCTest

@testable import ContextCore

/// A link to a Cockpit thread (story 744): either spelling names the thread, a tap opens it in the app when the list
/// knows it and its Cockpit page when not, and the tailnet host never shows.
final class ChatCockpitLinkTests: XCTestCase {
  private func url(_ s: String) -> URL { URL(string: s)! }
  private let ask = "https://c-5004.squeaker-teeth.ts.net/#thread/igor2-88g.1411.2"

  func testBothSpellingsNameTheThread() {
    XCTAssertEqual(ChatCockpitLink.threadKey(url(ask)), "igor2-88g.1411.2")
    XCTAssertEqual(
      ChatCockpitLink.threadKey(url("https://c-5004.squeaker-teeth.ts.net#thread/igor2-88g.1413")), "igor2-88g.1413")
    XCTAssertEqual(ChatCockpitLink.threadKey(url("HTTPS://C-5004.squeaker-teeth.ts.net/#thread/a%2Db")), "a-b")
    XCTAssertEqual(ChatCockpitLink.threadKey(url("larry://inbox/igor2-88g.1411.2")), "igor2-88g.1411.2")
    XCTAssertEqual(ChatCockpitLink.threadKey(url("LARRY://Inbox/igor2-88g.1413")), "igor2-88g.1413")
  }

  func testOtherLinksNameNoThread() {
    for s in [
      "https://c-5004.squeaker-teeth.ts.net/#inbox",
      "https://c-5004.squeaker-teeth.ts.net/#thread/",
      "https://c-5004.squeaker-teeth.ts.net/#thread/a/b",
      "https://c-5004.squeaker-teeth.ts.net/decisions#thread/igor2-88g.1413",
      "http://c-5004.squeaker-teeth.ts.net:8445/#thread/igor2-88g.1413",
      "https://example.com/#thread/igor2-88g.1413",
      "https://github.com/idvorkin/context-grabber/pull/734",
      "larry://inbox/",
      "larry://inbox/a/b",
      "larry://chat/igor2-88g.1413",
    ] {
      XCTAssertNil(ChatCockpitLink.threadKey(url(s)), s)
    }
  }

  func testATapOpensAKnownThreadAndAnUnknownOneOnTheCockpit() {
    let known: Set = ["igor2-88g.1411.2", "igor2-88g.1413"]
    for link in [url(ask), url("larry://inbox/igor2-88g.1411.2")] {
      XCTAssertEqual(ChatCockpitLink.jump(link, from: "igor2-88g.1413", known: known), .thread("igor2-88g.1411.2"))
      XCTAssertEqual(ChatCockpitLink.jump(link, from: "igor2-88g.1411.2", known: known), .here)
      XCTAssertEqual(
        ChatCockpitLink.jump(link, from: "igor2-88g.1413", known: ["igor2-88g.1413"]), .web(url(ask)),
        "unknown: the Cockpit page, as the long link did before")
    }
    XCTAssertNil(ChatCockpitLink.jump(url("https://idvork.in/ai-journal"), from: nil, known: known))
  }

  func testAThreadLinkIsAnInboxChipOncePerThread() {
    let text = "It's in the Inbox: \(ask). Same as larry://inbox/igor2-88g.1411.2, and https://idvork.in/ai-journal"
    let links = ChatLinks.found(in: text)
    XCTAssertEqual(links.map(\.label), ["Inbox", "Inbox", "idvork.in/ai-journal"])
    XCTAssertEqual(links.first?.kind, .inbox(thread: "igor2-88g.1411.2"))
    let thread = ChatLinks.inThread([ChatMessage(id: "1", ts: "", who: "larry", text: text, isError: false)])
    XCTAssertEqual(thread.map(\.label), ["Inbox", "idvork.in/ai-journal"], "both spellings are one chip")
  }

  func testTheTailnetHostNeverShows() {
    let links = ChatLinks.found(
      in: "\(ask) https://c-5004.squeaker-teeth.ts.net/#inbox http://c-5004.squeaker-teeth.ts.net:8445/ai-journal")
    XCTAssertEqual(links.map(\.label), ["Inbox", "Larry", "Larry: ai-journal"])
    XCTAssertEqual(
      links.map(ChatLinks.address),
      ["larry://inbox/igor2-88g.1411.2", "Larry/#inbox", "Larry:8445/ai-journal"])
    XCTAssertEqual(
      ChatLinks.address(ChatLinks.found(in: "https://idvork.in/ai-journal")[0]), "https://idvork.in/ai-journal")
  }

  func testInABubbleAThreadLinkIsAnInboxChip() {
    guard case .flow(let tokens) = ChatBubbleLinks.paragraphs(in: "See larry://inbox/igor2-88g.1411.2.")[0],
      case .chip(let link, _, let trailing)? = tokens.last
    else { return XCTFail("no chip") }
    XCTAssertEqual(link.label, "Inbox")
    XCTAssertEqual(trailing, ".")
  }
}
