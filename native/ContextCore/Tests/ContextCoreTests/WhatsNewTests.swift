import Foundation
import XCTest

@testable import ContextCore

/// Story 148: what's new, made from the commit subjects and the stories' summaries.
final class WhatsNewTests: XCTestCase {
  let la = TimeZone(identifier: "America/Los_Angeles")!

  private func at(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

  func testSubjectsThatStartWithTheirStory() {
    XCTAssertEqual(
      WhatsNew.parse(subject: "Story 203: the Cockpit's usage left, as a strip on the native home screen"),
      .init(story: 203, text: "The Cockpit's usage left, as a strip on the native home screen", issue: nil, leading: true))
    XCTAssertEqual(
      WhatsNew.parse(subject: "Story 146 (#164): a gentle shake opens the report, read from the motion itself"),
      .init(story: 146, text: "A gentle shake opens the report, read from the motion itself", issue: 164, leading: true))
    XCTAssertEqual(
      WhatsNew.parse(subject: "Story 147: the home screen holds only the launchers (#166)"),
      .init(story: 147, text: "The home screen holds only the launchers", issue: 166, leading: true))
    XCTAssertEqual(WhatsNew.parse(subject: "Story 037 (#139): every finished workout rides to Larry")?.story, 37)
  }

  func testSubjectsThatNameTheirStoriesInBrackets() {
    XCTAssertEqual(
      WhatsNew.parse(subject: "Think of a card opens Igor's Think a Card Trainer instead of a native card port (story 133)"),
      .init(
        story: 133, text: "Think of a card opens Igor's Think a Card Trainer instead of a native card port", issue: nil,
        leading: false))
    XCTAssertEqual(
      WhatsNew.parse(subject: "Gym Timer: RESET on the turned face when paused or finished (story 181, #132)"),
      .init(story: 181, text: "Gym Timer: RESET on the turned face when paused or finished", issue: 132, leading: false))
    XCTAssertEqual(WhatsNew.parse(subject: "Native app: Box breathing (stories 160-165)")?.story, 160)
    XCTAssertEqual(WhatsNew.parse(subject: "Native app: Box breathing (stories 160-165)")?.text, "Native app: Box breathing")
    XCTAssertEqual(WhatsNew.parse(subject: "Home: an Exercise Analyzer row (#142, story 134)"), nil)  // story not first
  }

  func testBookkeepingAndStorylessSubjectsAreDropped() {
    for subject in [
      "Story 147 Status names 80b7186", "Story 133: Status names 0152b68", "Story 203 Status names its commit 3da9e54",
      "Story 080 Status: d9c1fd1 verified on the phone (#146)", "Merge native/mirror into native/ports",
      "Merge pull request #134 from idvorkin/native/05-live-activity (story 106)", "WIP story 12",
      "no-mistakes(review): Story 120 Status names its commit 7ba6357", "Native Call: send the Cockpit's origin (#136)", "",
    ] {
      XCTAssertNil(WhatsNew.parse(subject: subject), subject)
    }
  }

  func testStorySummariesAndIssuesFromTheMarkdown() {
    let markdown = """
      ### User Story 141:

      - **Summary:** Every launch keeps a log (technical)
      - **Status:** implemented

      ### User Story 147:

      - **Summary:** The home screen holds only what I open, and a cog holds the rest
      - **Issues:** [#166](https://github.com/idvorkin/context-grabber/issues/166), [#170](x)

      ### User Story 199:
      - **Status:** a story with no summary is not used
      """
    let stories = WhatsNew.stories(fromMarkdown: markdown)
    XCTAssertEqual(stories[141], .init(summary: "Every launch keeps a log"))
    XCTAssertEqual(stories[147], .init(summary: "The home screen holds only what I open, and a cog holds the rest", issue: 166))
    XCTAssertNil(stories[199])
  }

  func testTheFeedIsByLocalDayNewestFirstOneLinePerStoryPerDay() {
    let stories: [Int: WhatsNew.Story] = [147: .init(summary: "A cog for the rest", issue: 166)]
    let commits = [
      WhatsNew.Commit(sha: "e", date: at("2026-10-06T16:00:00Z"), subject: "Story 147 Status names d"),
      WhatsNew.Commit(sha: "d", date: at("2026-10-06T15:00:00Z"), subject: "Story 147: the home screen, launchers only"),
      WhatsNew.Commit(sha: "c", date: at("2026-10-06T14:00:00Z"), subject: "Story 147: a follow-up the same day"),
      // 01:00 UTC on the 6th is still the 5th in Los Angeles.
      WhatsNew.Commit(sha: "b", date: at("2026-10-06T01:00:00Z"), subject: "Story 147: the first cut"),
      WhatsNew.Commit(sha: "a", date: at("2026-10-05T18:00:00Z"), subject: "Card opens the trainer (story 133)"),
      WhatsNew.Commit(sha: "old", date: at("2026-08-01T18:00:00Z"), subject: "Story 100: long ago"),
    ]
    let days = WhatsNew.build(commits: commits, stories: stories, now: at("2026-10-06T20:00:00Z"), timeZone: la)
    XCTAssertEqual(days.map(\.day), ["2026-10-06", "2026-10-05"])
    XCTAssertEqual(days[0].items, [WhatsNewItem(story: 147, text: "A cog for the rest", issue: 166, sha: "d")])
    XCTAssertEqual(days[1].items.map(\.sha), ["b", "a"])
    XCTAssertEqual(days[1].items[1].text, "Card opens the trainer")
    XCTAssertEqual(days[1].items[1].caption, "Story 133")
    XCTAssertEqual(days[0].items[0].caption, "Story 147 · #166")
  }

  func testAStoryWithoutAMarkdownSummaryShowsTheSubjectsWords() {
    let days = WhatsNew.build(
      commits: [.init(sha: "a", date: at("2026-10-06T15:00:00Z"), subject: "Story 240 (#147): a thicker ring")],
      stories: [:], now: at("2026-10-06T20:00:00Z"), timeZone: la)
    XCTAssertEqual(days.first?.items.first?.text, "A thicker ring")
    XCTAssertEqual(days.first?.items.first?.issue, 147)
  }

  func testTheHomeLineAndLabels() {
    XCTAssertEqual(WhatsNew.homeLine(nil), "nothing new")
    XCTAssertEqual(WhatsNew.homeLine(WhatsNewFeed(generated: "", days: [])), "nothing new")
    let feed = WhatsNewFeed(
      generated: "", days: [.init(day: "2026-10-05", items: [.init(story: 240, text: "Box breathing ring styles", sha: "a")])])
    XCTAssertEqual(WhatsNew.homeLine(feed), "Oct 5 — Box breathing ring styles")
    XCTAssertEqual(WhatsNew.label(day: "2026-10-05", style: .long), "Monday, Oct 5")
    XCTAssertEqual(WhatsNew.label(day: "garbage", style: .long), "garbage")
  }

  func testTheResourceRoundTripsAndABadOneIsNil() throws {
    let feed = WhatsNewFeed(
      generated: "2026-10-06T20:00:00Z",
      days: [.init(day: "2026-10-05", items: [.init(story: 133, text: "Card", issue: 142, sha: "a")])])
    XCTAssertEqual(WhatsNewFeed.decode(try JSONEncoder().encode(feed)), feed)
    XCTAssertNil(WhatsNewFeed.decode(nil))
    XCTAssertNil(WhatsNewFeed.decode(Data("not json".utf8)))
  }

  /// The real stories: every journey file parses, and a known summary is found.
  func testTheRepositorysStoriesParse() throws {
    let dir = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/stories")
    var all: [Int: WhatsNew.Story] = [:]
    for file in try FileManager.default.contentsOfDirectory(atPath: dir.path) where file.hasSuffix(".md") {
      all.merge(WhatsNew.stories(fromMarkdown: try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8))) { a, _ in a }
    }
    XCTAssertGreaterThan(all.count, 50)
    XCTAssertEqual(all[140]?.summary, "The native app lives beside the current one")
    XCTAssertEqual(all[148]?.issue, 165)
  }

  func testHomeRowGoesOnceSeenAndComesBackForSomethingNewer() {
    let feed = WhatsNewFeed(
      generated: "2026-10-06",
      days: [WhatsNewDay(day: "2026-10-06", items: [WhatsNewItem(story: 148, text: "New", sha: "bbb")])])
    XCTAssertTrue(WhatsNewFeed.showsOnHome(feed, seen: nil))
    XCTAssertFalse(WhatsNewFeed.showsOnHome(feed, seen: "bbb"))
    XCTAssertTrue(WhatsNewFeed.showsOnHome(feed, seen: "aaa"))
    // Nothing to show: no row at all.
    XCTAssertFalse(WhatsNewFeed.showsOnHome(nil, seen: nil))
    XCTAssertFalse(WhatsNewFeed.showsOnHome(WhatsNewFeed(generated: "", days: []), seen: nil))
  }
}
