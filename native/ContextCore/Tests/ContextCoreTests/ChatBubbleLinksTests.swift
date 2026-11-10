import XCTest

@testable import ContextCore

/// Links in a bubble are chips (story 743): a PR reads *PR*, the blog or its tailnet preview *Preview*, any other link
/// its strip chip's words; the words around them split so a chip can sit among them, punctuation kept against it.
final class ChatBubbleLinksTests: XCTestCase {
  private let pr734 = "https://github.com/idvorkin/context-grabber/pull/734"
  private let pr736 = "https://github.com/idvorkin/context-grabber/pull/736"
  private let preview = "http://c-5004.squeaker-teeth.ts.net:8445/ai-journal"

  /// Each paragraph as text: a chip as `[label]` with what touches it, words joined by a space.
  private func read(_ text: String) -> [String] {
    ChatBubbleLinks.paragraphs(in: text).map {
      switch $0 {
      case .plain(let words): return "plain: " + words
      case .flow(let tokens):
        return tokens.map { token -> String in
          switch token {
          case .word(let word): return word
          case .chip(let link, let leading, let trailing):
            return "\(leading)[\(link.label)]\(trailing)"
          }
        }
        .joined(separator: " ")
      }
    }
  }

  func testAPRAndAPreviewAreChipsAmongTheWords() {
    XCTAssertEqual(read("Opened \(pr734), preview at \(preview)."), ["Opened [PR], preview at [Preview]."])
  }

  func testEveryPRReadsPRWhateverItsNumber() {
    XCTAssertEqual(read("Merged \(pr734); \(pr736) is next"), ["Merged [PR]; [PR] is next"])
  }

  func testTheBlogAndItsPreviewsReadPreview() {
    for link in [
      "https://idvork.in/ai-journal", "https://www.idvork.in/eulogy", "https://idvorkin.github.io/ai-journal",
      "http://c-5004.squeaker-teeth.ts.net:8448/religion", "https://idvork.in",
    ] {
      XCTAssertEqual(read("See \(link)"), ["See [Preview]"], link)
    }
  }

  func testOtherLinksAreTheirStripChip() {
    let issue = "https://github.com/idvorkin/context-grabber/issues/736"
    let gist = "https://gist.github.com/idvorkin/3f2a9c1e8b7d"
    XCTAssertEqual(read("A gist \(gist) and \(issue)"), ["A gist [gist] and [github.com/issues/736]"])
  }

  func testWordsWrittenAgainstALinkStayWithItsChip() {
    XCTAssertEqual(read("(see \(pr734)) and **\(preview)**"), ["(see [PR]) and **[Preview]**"])
  }

  func testOnlyTheLinesWithALinkSplitIntoWords() {
    XCTAssertEqual(
      read("Done.\nThe PR: \(pr734)\n\nThanks"), ["plain: Done.", "The PR: [PR]", "plain: ", "plain: Thanks"])
    XCTAssertEqual(read("No links here,\njust words"), ["plain: No links here,\njust words"])
  }

  func testTheChipKeepsTheLinkAndItsPage() {
    guard case .flow(let tokens) = ChatBubbleLinks.paragraphs(in: "Opened \(pr734)/files.")[0],
      case .chip(let link, _, let trailing)? = tokens.last
    else { return XCTFail("no chip") }
    XCTAssertEqual(link.url.absoluteString, pr734 + "/files")
    XCTAssertEqual(link.id, "pr:idvorkin/context-grabber#734", "the strip's id, so its state applies")
    XCTAssertEqual(trailing, ".")
  }
}
