//  Story 137: the eulogy song is whatever the post embeds.

import ContextCore
import XCTest

final class BlogLinksTests: XCTestCase {
  func testTheEmbedInThePostIsTheSong() {
    // As the post served it on 2026-10-07: the embed's iframe comes before the plain link.
    let html = #"<iframe src="https://suno.com/embed/21be0b93-a44b-4a94-b2d6-39a59fff6283" width="100%"></iframe>"#
      + #" <a href="https://suno.com/song/21be0b93-a44b-4a94-b2d6-39a59fff6283">the song</a>"#
    XCTAssertEqual(
      BlogLinks.song(inPost: html)?.absoluteString, "https://suno.com/song/21be0b93-a44b-4a94-b2d6-39a59fff6283")
  }

  func testAChangedSongIsFollowed() {
    let html = #"<a href="https://suno.com/song/AAAAAAAA-1111-2222-3333-444444444444?sh=x">new</a>"#
    XCTAssertEqual(
      BlogLinks.song(inPost: html)?.absoluteString, "https://suno.com/song/aaaaaaaa-1111-2222-3333-444444444444")
  }

  func testAPostWithoutASongHasNone() {
    XCTAssertNil(BlogLinks.song(inPost: "<p>No song here. suno.com/about</p>"))
  }
}
