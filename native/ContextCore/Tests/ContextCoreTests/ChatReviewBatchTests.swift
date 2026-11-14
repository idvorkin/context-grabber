//  Story 748: a pasted blog-review batch reads as one card; anything else stays as written. The cases mirror the
//  Cockpit web chat's `reviewBatch` tests (cockpit-3uc) so both read a batch the same way.

import XCTest

@testable import ContextCore

final class ChatReviewBatchTests: XCTestCase {
  private typealias B = ChatReviewBatch

  /// The Cockpit's golden batch (fixtures/blog_review_batch_golden.json): the shape of a real batch from 2026-11-14,
  /// its text made neutral, pasted as the tool's Copy puts it (two-space JSON).
  private let golden = #"""
    {
      "permalink": "/time-allocation",
      "origin": "https://idvork.in",
      "title": "Where the time goes",
      "url": "https://idvork.in/time-allocation",
      "created": "2026-11-14T13:05:25.761Z",
      "version": {
        "url": "https://idvork.in/time-allocation",
        "capturedAt": "2026-11-14T13:05:25.761Z",
        "lastModified": "11/12/2026 05:23:19",
        "contentLength": 9123,
        "contentDigest": "926cae01"
      },
      "annotations": [
        {
          "permalink": "/time-allocation",
          "origin": "https://idvork.in",
          "title": "Where the time goes",
          "quote": "passion or addiction:",
          "prefix": ". I can’t tell, some days, the ",
          "suffix": "\n    \n      Energy flows where ",
          "comment": "Link this to the energy-flow section. ",
          "intent": "note",
          "ts": "2026-11-14T13:04:53.626Z",
          "version": {
            "url": "https://idvork.in/time-allocation",
            "capturedAt": "2026-11-14T13:04:53.627Z",
            "lastModified": "11/12/2026 05:23:19",
            "contentLength": 9123,
            "contentDigest": "926cae01"
          }
        },
        {
          "permalink": "/time-allocation",
          "origin": "https://idvork.in",
          "title": "Where the time goes",
          "quote": "Energy: I’m tracking where my hours actually go, week by week. I can’t tell, some days, the passion or addiction:\n    \n      ",
          "prefix": "n of it in my current week.\n  ",
          "suffix": "Energy flows where attention go",
          "comment": "Add something like, \"I'm measuring energy, not hours,\" and say that very concisely",
          "intent": "rewrite",
          "ts": "2026-11-14T13:05:10.001Z",
          "version": {
            "url": "https://idvork.in/time-allocation",
            "capturedAt": "2026-11-14T13:05:10.002Z",
            "lastModified": "11/12/2026 05:23:19",
            "contentLength": 9123,
            "contentDigest": "926cae01"
          }
        }
      ]
    }
    """#

  private func pasted(_ edit: (inout [String: Any]) -> Void) throws -> String {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(golden.utf8)) as? [String: Any])
    edit(&object)
    return String(
      decoding: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]), as: UTF8.self)
  }

  /// The golden with one note: its first, `change` applied.
  private func oneNote(_ change: [String: Any?] = [:]) throws -> String {
    try pasted { object in
      var note = ((object["annotations"] as? [[String: Any]]) ?? [])[0]
      for (key, value) in change { note[key] = value }
      object["annotations"] = [note]
    }
  }

  func testTheGoldenBatchIsACard() throws {
    let card = try XCTUnwrap(B.parse(golden))
    XCTAssertEqual(card.title, "Where the time goes")
    XCTAssertEqual(card.page, URL(string: "https://idvork.in/time-allocation"))
    XCTAssertEqual(card.count, "2 notes")
    XCTAssertEqual(
      card.notes,
      [
        B.Note(
          intent: "note", text: "Link this to the energy-flow section.", before: "… I can’t tell, some days, the ",
          quote: "passion or addiction:", after: " Energy flows where …",
          comment: "Link this to the energy-flow section."),
        B.Note(
          intent: "rewrite", text: "Add something like, \"I'm measuring energy, not hours,\" and…",
          before: "…n of it in my current week. ",
          quote:
            "Energy: I’m tracking where my hours actually go, week by week. I can’t tell, some days, the passion or addiction:",
          after: "Energy flows where attention g…",
          comment: "Add something like, \"I'm measuring energy, not hours,\" and say that very concisely"),
      ])
    XCTAssertEqual(
      card.notes.map(\.label),
      [
        "note · Link this to the energy-flow section.",
        "rewrite · Add something like, \"I'm measuring energy, not hours,\" and…",
      ])
    // 59 characters, then "…", less the space that would have hung before it.
    XCTAssertEqual(card.notes[1].text.count, B.labelLimit - 1)
    XCTAssertNotNil(B.parse("\n  " + golden + "\n"))
  }

  func testOneNoteReadsOneNote() throws {
    XCTAssertEqual(try XCTUnwrap(B.parse(try oneNote())).count, "1 note")
  }

  func testAnythingButAWholeBatchStaysAsWritten() throws {
    let bad = [
      "", "hello", #"{"permalink": "/x", "annotations": ["#, String(golden.dropLast()), #"{"a": 1}"#,
      "[" + golden + "]", "null",
      try pasted { $0["annotations"] = [Any]() },
      try pasted { $0["annotations"] = [String: Any]() },
      try pasted {
        $0["permalink"] = ""; $0["url"] = ""
      },
      try pasted {
        $0["permalink"] = 7; $0["url"] = NSNull()
      },
      try pasted { $0["annotations"] = [((($0["annotations"] as? [Any]) ?? [])[0]), ["quote": "q"]] as [Any] },
      try pasted { $0["annotations"] = [((($0["annotations"] as? [Any]) ?? [])[0]), "note"] as [Any] },
      try oneNote(["quote": 3]),
      "note: " + golden, golden + "\nthanks", "```json\n" + golden + "\n```",
    ]
    for message in bad { XCTAssertNil(B.parse(message), String(message.prefix(60))) }
  }

  func testEitherPermalinkOrURLIsEnoughAndTheLinkIsOnlyHTTP() throws {
    let noURL = try XCTUnwrap(B.parse(try pasted { $0["url"] = nil }))
    XCTAssertEqual(noURL.page, URL(string: "https://idvork.in/time-allocation"))
    let onlyURL = try XCTUnwrap(
      B.parse(#"{"url": "https://idvork.in/a", "annotations": [{"quote": "q", "comment": "c"}]}"#))
    XCTAssertEqual(onlyURL.title, "https://idvork.in/a")
    XCTAssertEqual(onlyURL.page, URL(string: "https://idvork.in/a"))
    let script = try XCTUnwrap(
      B.parse(
        #"{"permalink": "/x", "url": "javascript:alert(1)", "origin": "javascript:x", "title": "T", "annotations": [{"quote": "q", "comment": "c"}]}"#
      ))
    XCTAssertNil(script.page)
    let relative = try XCTUnwrap(
      B.parse(#"{"permalink": "x", "origin": "https://idvork.in", "annotations": [{"quote": "q", "comment": "c"}]}"#))
    XCTAssertEqual(relative.title, "x")
    XCTAssertNil(relative.page)
  }

  func testTheIntentIsOneOfTheSevenAnyCaseElseNote() throws {
    let values: [Any?] = ["FIX", " cut ", "nitpick", "", 4, nil]
    let intents = try values.map { try XCTUnwrap(B.parse(try oneNote(["intent": $0]))).notes[0].intent }
    XCTAssertEqual(intents, ["fix", "cut", "note", "note", "note", "note"])
  }

  func testAnEmptyCommentReadsItsQuote() throws {
    let note = try XCTUnwrap(B.parse(try oneNote(["comment": "  \n", "prefix": " \n ", "suffix": nil]))).notes[0]
    XCTAssertEqual(
      [note.label, note.before, note.after, note.comment], ["note · “passion or addiction:”", "", "", ""])
    let long = try XCTUnwrap(B.parse(try oneNote(["comment": "", "quote": String(repeating: "x", count: 80)])))
    XCTAssertEqual(long.notes[0].text, "“" + String(repeating: "x", count: 57) + "…”")
    XCTAssertEqual(long.notes[0].text.count, B.labelLimit)
  }

  func testTheFullCommentKeepsItsLineBreaks() throws {
    let note = try XCTUnwrap(B.parse(try oneNote(["comment": "line one\n\nline two  "]))).notes[0]
    XCTAssertEqual([note.comment, note.text], ["line one\n\nline two", "line one line two"])
    let emoji = try XCTUnwrap(B.parse(try oneNote(["comment": String(repeating: "🦝", count: 61)]))).notes[0]
    XCTAssertEqual(emoji.text, String(repeating: "🦝", count: 59) + "…")
  }
}
