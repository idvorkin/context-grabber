import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Story 270 (context-grabber-3il): every record off the phone, once each, the cursor moved only on a 2xx.
final class ArchiveTests: XCTestCase {
  /// The Cockpit's rule for a guid, copied from its archive.py (GUID_RE): the contract both sides keep.
  static let cockpitGUID = "^[A-Za-z0-9][A-Za-z0-9_.:+-]{0,127}$"

  // MARK: GUIDs

  func testEveryGUIDShapeSatisfiesTheCockpitsRule() throws {
    let uuid = try XCTUnwrap(UUID(uuidString: "0F6C1A2E-1111-4A8E-9C1D-AA00BB11CC22"))
    let point = LocationPoint(latitude: 47.6419, longitude: -122.3045, accuracy: 12, timestamp: 1_760_000_000_123.456)
    let tiny = LocationPoint(latitude: 0.00001, longitude: -0.00001, timestamp: 1e12)
    let guids = [
      ArchiveGUID.sample(uuid), ArchiveGUID.deleted(uuid), ArchiveGUID.point(point), ArchiveGUID.point(tiny),
    ]
    XCTAssertEqual(guids[0], "0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22")
    XCTAssertEqual(guids[1], "del:0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22")
    XCTAssertEqual(guids[2], "p:1760000000123.456:47.6419:-122.3045")
    for guid in guids {
      XCTAssertNotNil(guid.range(of: Self.cockpitGUID, options: .regularExpression), guid)
    }
  }

  func testAPointsGUIDIsTheImportsIdentity() {
    // LocationStore.importDatabase skips a point with the same timestamp, latitude and longitude: so does the archive.
    let a = LocationPoint(latitude: 47.5, longitude: -122.25, accuracy: 10, timestamp: 1_700_000_000_000)
    var b = a
    b.accuracy = 65
    XCTAssertEqual(ArchiveGUID.point(a), ArchiveGUID.point(b))
    b.timestamp += 1
    XCTAssertNotEqual(ArchiveGUID.point(a), ArchiveGUID.point(b))
  }

  // MARK: The request and the answer (Cockpit story 124)

  func testTheRequestCarriesTheContractAndTheCockpitsOrigin() throws {
    let batch = ArchiveBatch(
      stream: ArchiveStream.health("HKQuantityTypeIdentifierStepCount"), deviceId: "dev-1", batchId: "b-1",
      records: [["guid": "a", "value": 12.0], ["guid": "b", "value": 3.0]])
    let request = try ArchiveSend.request(batch, cockpit: "https://cockpit.example:8778")
    XCTAssertEqual(request.url?.absoluteString, "https://cockpit.example:8778/archive")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://cockpit.example:8778")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "no token is set up")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual(body["stream"] as? String, "health.HKQuantityTypeIdentifierStepCount")
    XCTAssertEqual(body["device_id"] as? String, "dev-1")
    XCTAssertEqual(body["batch_id"] as? String, "b-1")
    let records = try XCTUnwrap(body["records"] as? [[String: Any]])
    XCTAssertEqual(records.map { $0["guid"] as? String }, ["a", "b"])
  }

  func testEveryAnswerClass() {
    let ok = Data(#"{"ok": true, "received": 3, "inserted": 2, "duplicate": 1}"#.utf8)
    let bad = Data(#"{"ok": false, "reason": "records[0].guid must be ...", "error": "x"}"#.utf8)
    XCTAssertEqual(ArchiveSend.outcome(status: 200, body: ok), .taken(inserted: 2, duplicate: 1))
    XCTAssertEqual(
      ArchiveSend.outcome(status: 201, body: ok), .taken(inserted: 2, duplicate: 1), "any 2xx with ok is taken")
    XCTAssertEqual(
      ArchiveSend.outcome(status: 400, body: bad), .refused(status: 400, reason: "records[0].guid must be ..."))
    XCTAssertEqual(ArchiveSend.outcome(status: 403, body: nil), .refused(status: 403, reason: "HTTP 403"))
    XCTAssertEqual(ArchiveSend.outcome(status: 503, body: Data("down".utf8)), .retry(reason: "HTTP 503"))
    XCTAssertEqual(ArchiveSend.outcome(status: nil, body: nil, error: "offline"), .retry(reason: "offline"))
  }

  // MARK: The cursor moves only on a 2xx

  /// Three pages: [a, b], [c, d], [e].
  private struct Pages: ArchiveSource {
    let stream = "test.stream"
    let pages: [[String]]
    func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
      let index = cursor.flatMap { Int($0) }.map { $0 + 1 } ?? 0
      guard index < pages.count else { return ArchivePage(records: [], cursor: cursor, more: false) }
      return ArchivePage(
        records: pages[index].map { ["guid": $0, "v": 1] }, cursor: String(index), more: index + 1 < pages.count)
    }
  }

  private func makeUploader(_ cursors: ArchiveCursorStore, answers: [Int], seen: Seen) -> ArchiveUploader {
    ArchiveUploader(cursors: cursors, cockpit: "https://cockpit.test", deviceId: "dev") { request in
      let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
      let guids = (body["records"] as? [[String: Any]])?.compactMap { $0["guid"] as? String } ?? []
      let n = await seen.add(guids)
      let status = n < answers.count ? answers[n] : 200
      let json = status == 200 ? #"{"ok": true, "inserted": 2, "duplicate": 0}"# : #"{"ok": false, "reason": "nope"}"#
      return (
        Data(json.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      )
    }
  }

  @MainActor
  func testTheCursorStaysWhereTheLastTakenPageEnded() async throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    let source = Pages(pages: [["a", "b"], ["c", "d"], ["e"]])
    let seen = Seen()
    var lines: [[String: Any]] = []
    let report = await makeUploader(cursors, answers: [200, 503], seen: seen).upload(source) { _, f in lines.append(f) }
    let sent = await seen.batches
    XCTAssertEqual(sent, [["a", "b"], ["c", "d"]], "the third page waits behind the 503")
    XCTAssertEqual(try cursors.cursor("test.stream"), "0", "page 2 was not taken, so its cursor is not kept")
    XCTAssertEqual(report.stopped, .cockpitAway)
    XCTAssertEqual(report.pages, 2)
    XCTAssertEqual(report.records, 4)
    XCTAssertEqual(report.inserted, 2)
    XCTAssertEqual(lines.compactMap { $0["action"] as? String }, ["page", "failed"])
    XCTAssertEqual(lines.first?["backfill"] as? Bool, true)

    // The next run starts after the taken page and finishes the stream.
    let again = Seen()
    let caughtUp = await makeUploader(cursors, answers: [], seen: again).upload(source) { _, _ in }
    let resent = await again.batches
    XCTAssertEqual(resent, [["c", "d"], ["e"]])
    XCTAssertEqual(try cursors.cursor("test.stream"), "2")
    XCTAssertNil(caughtUp.stopped)
    XCTAssertEqual(caughtUp.pages, 2)
  }

  @MainActor
  func testARefusalKeepsTheCursorAndStopsTheStream() async throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    let seen = Seen()
    var lines: [[String: Any]] = []
    let report = await makeUploader(cursors, answers: [415], seen: seen).upload(Pages(pages: [["a"], ["b"]])) { _, f in
      lines.append(f)
    }
    XCTAssertNil(try cursors.cursor("test.stream"))
    XCTAssertEqual(report.stopped, .refused)
    XCTAssertEqual(report.refusedStatus, 415, "for the Settings line")
    XCTAssertEqual(lines.last?["action"] as? String, "refused")
    XCTAssertEqual(lines.last?["status"] as? Int, 415)
    XCTAssertEqual(lines.last?["reason"] as? String, "nope")
  }

  @MainActor
  func testARunReadsAtMostItsPagesAndSaysSo() async throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    var uploader = makeUploader(cursors, answers: [], seen: Seen())
    uploader.maxPages = 1
    let report = await uploader.upload(Pages(pages: [["a"], ["b"], ["c"]])) { _, _ in }
    XCTAssertEqual(report.pages, 1)
    XCTAssertEqual(report.stopped, .pages)
    XCTAssertEqual(try cursors.cursor("test.stream"), "0")
  }

  @MainActor
  func testAnEmptyPageStillMovesTheCursorWithoutASend() async throws {
    // Health answers a new anchor even when nothing was added: keep it, so the next run asks from there.
    struct Moved: ArchiveSource {
      let stream = "health.empty"
      func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
        ArchivePage(records: [], cursor: "anchor-2", more: false)
      }
    }
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    try cursors.set("health.empty", cursor: "anchor-1", at: 1)
    let uploader = ArchiveUploader(cursors: cursors, cockpit: "https://cockpit.test", deviceId: "dev") { _ in
      XCTFail("nothing to send")
      throw URLError(.badURL)
    }
    let report = await uploader.upload(Moved()) { _, _ in }
    XCTAssertEqual(report, ArchiveUploader.Report())
    XCTAssertEqual(try cursors.cursor("health.empty"), "anchor-2")
  }

  @MainActor
  func testARestartedStreamSaysSoOnceAndSendsAsABackfill() async throws {
    // A Health anchor the build cannot read: the source starts over, and the log says why the history comes again.
    struct Restarted: ArchiveSource {
      let stream = "health.restarted"
      func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
        cursor == "unreadable"
          ? ArchivePage(records: [["guid": "a"]], cursor: "anchor-1", more: true, restarted: true)
          : ArchivePage(records: [["guid": "b"]], cursor: "anchor-2", more: false)
      }
    }
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    try cursors.set("health.restarted", cursor: "unreadable", at: 1)
    var lines: [[String: Any]] = []
    let report = await makeUploader(cursors, answers: [], seen: Seen()).upload(Restarted()) { _, f in lines.append(f) }
    XCTAssertNil(report.stopped)
    XCTAssertEqual(lines.compactMap { $0["action"] as? String }, ["restarted", "page", "page"])
    XCTAssertEqual(lines.first?["stream"] as? String, "health.restarted")
    XCTAssertEqual(lines.dropFirst().compactMap { $0["backfill"] as? Bool }, [true, true])
    XCTAssertEqual(try cursors.cursor("health.restarted"), "anchor-2")
  }

  @MainActor
  func testNoRecordContentReachesTheLog() async throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    var lines: [[String: Any]] = []
    _ = await makeUploader(cursors, answers: [], seen: Seen()).upload(Pages(pages: [["secret-guid"]])) { _, f in
      lines.append(f)
    }
    XCTAssertFalse(lines.contains { "\($0)".contains("secret") })
  }

  // MARK: The trail as a stream

  @MainActor
  func testTheTrailPagesByRowIdWithContentGUIDs() async throws {
    let store = try LocationStore(db: SQLiteDatabase())
    try store.insert(
      (1...5).map {
        LocationPoint(latitude: 47.0 + Double($0), longitude: -122.0, accuracy: 5, timestamp: 1_000 + Double($0))
      })
    let source = LocationArchiveSource(store: store)
    XCTAssertEqual(source.stream, "location.points")
    let first = try await source.page(after: nil, limit: 2)
    XCTAssertEqual(first.records.map { $0["guid"] as? String }, ["p:1001.0:48.0:-122.0", "p:1002.0:49.0:-122.0"])
    XCTAssertEqual(first.records.first?["acc"] as? Double, 5)
    XCTAssertEqual(first.cursor, "2")
    XCTAssertTrue(first.more)
    let last = try await source.page(after: "4", limit: 2)
    XCTAssertEqual(last.records.count, 1)
    XCTAssertEqual(last.cursor, "5")
    XCTAssertFalse(last.more)
    let none = try await source.page(after: "5", limit: 2)
    XCTAssertTrue(none.records.isEmpty)
    XCTAssertNil(none.cursor)
  }

  @MainActor
  func testTheWholeTrailGoesOnceAndTheCursorEndsAtItsLastRow() async throws {
    let store = try LocationStore(db: SQLiteDatabase())
    try store.insert((1...5).map { LocationPoint(latitude: 47, longitude: -122, timestamp: Double($0)) })
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    let seen = Seen()
    var uploader = makeUploader(cursors, answers: [], seen: seen)
    uploader.pageSize = 2
    let report = await uploader.upload(LocationArchiveSource(store: store)) { _, _ in }
    let sent = await seen.batches
    XCTAssertEqual(sent.map(\.count), [2, 2, 1])
    XCTAssertEqual(try cursors.cursor("location.points"), "5")
    XCTAssertNil(report.stopped)
  }

  // MARK: The daily strip as streams (story 271)

  /// A fixed clock at `ms` Unix milliseconds.
  private func clock(_ ms: Int64) -> @Sendable () -> Date {
    { Date(timeIntervalSince1970: Double(ms) / 1000) }
  }

  func testAStripObservationsGUIDAndStreamSatisfyTheCockpitsRules() {
    let guid = ArchiveGUID.stripDay("2026-10-18", seenAt: 1_760_900_000_000)
    XCTAssertEqual(guid, "2026-10-18:1760900000000")
    XCTAssertNotNil(guid.range(of: Self.cockpitGUID, options: .regularExpression), guid)
    XCTAssertEqual(ArchiveStream.strip(.balloons), "strip.balloons")
    for item in DailyItem.allCases {
      // The Cockpit's rule for a stream (archive.py STREAM_RE).
      let stream = ArchiveStream.strip(item)
      XCTAssertNotNil(stream.range(of: "^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$", options: .regularExpression), stream)
    }
  }

  @MainActor
  func testTheStripsFirstRunIsEveryDayAsTheStripShowsIt() async throws {
    let strip = try DailyStrip(db: SQLiteDatabase())
    try strip.set(.balloons, day: "2026-10-16", value: 2)
    try strip.set(.balloons, day: "2026-10-17", value: 0)  // stepped back down before any run: nothing to say
    try strip.set(.balloons, day: "2026-10-18", value: 1)
    // The iPad's taps, arrived over iCloud: a count adds up across devices, and a day only the iPad has counts.
    try strip.mergePeer(
      "ipad", month: "2026-10",
      rows: [
        StripRow(day: "2026-10-18", item: .balloons, value: 3, updatedAt: 5),
        StripRow(day: "2026-10-15", item: .balloons, value: 4, updatedAt: 5),
        StripRow(day: "2026-10-15", item: .magic, value: 9, updatedAt: 5),
      ])
    let source = StripArchiveSource(strip: strip, item: .balloons, now: clock(1_000))
    XCTAssertEqual(source.stream, "strip.balloons")
    let page = try await source.page(after: nil, limit: 100)
    XCTAssertEqual(page.records.map { $0["day"] as? String }, ["2026-10-15", "2026-10-16", "2026-10-18"])
    XCTAssertEqual(page.records.map { $0["value"] as? Int }, [4, 2, 4])
    XCTAssertEqual(page.records.first?["guid"] as? String, "2026-10-15:1000")
    XCTAssertEqual(page.records.first?["seen_at"] as? Int64, 1_000)
    XCTAssertEqual(page.records.first?["item"] as? String, "balloons")
    XCTAssertFalse(page.more)
    XCTAssertFalse(page.restarted)

    // Nothing changed since: nothing to send, and the cursor stays where it was.
    let again = try await StripArchiveSource(strip: strip, item: .balloons, now: clock(2_000))
      .page(after: page.cursor, limit: 100)
    XCTAssertTrue(again.records.isEmpty)
    XCTAssertEqual(again.cursor, page.cursor)
  }

  @MainActor
  func testAChangedDayGoesAgainAsANewerObservationWhateverItsAge() async throws {
    let strip = try DailyStrip(db: SQLiteDatabase())
    try strip.set(.balloons, day: "2026-10-01", value: 3)
    try strip.set(.balloons, day: "2026-10-18", value: 1)
    let first = try await StripArchiveSource(strip: strip, item: .balloons, now: clock(1_000))
      .page(after: nil, limit: 100)

    // A counter's week edited weeks later, and the iPad's taps for a day already sent arriving late, stamped
    // earlier than that send: the archive's first copy of each day is stale, so each goes again under a new guid.
    try strip.set(.balloons, day: "2026-10-01", value: 2)
    try strip.mergePeer(
      "ipad", month: "2026-10", rows: [StripRow(day: "2026-10-18", item: .balloons, value: 2, updatedAt: 1)])
    let second = try await StripArchiveSource(strip: strip, item: .balloons, now: clock(2_000))
      .page(after: first.cursor, limit: 100)
    XCTAssertEqual(second.records.map { $0["guid"] as? String }, ["2026-10-01:2000", "2026-10-18:2000"])
    XCTAssertEqual(second.records.map { $0["value"] as? Int }, [2, 3])

    // Back to 3, the first observation's value: still a new observation, so the newest says 3.
    try strip.set(.balloons, day: "2026-10-01", value: 3)
    let third = try await StripArchiveSource(strip: strip, item: .balloons, now: clock(3_000))
      .page(after: second.cursor, limit: 100)
    XCTAssertEqual(third.records.map { $0["guid"] as? String }, ["2026-10-01:3000"])
    XCTAssertEqual(third.records.map { $0["value"] as? Int }, [3])
  }

  @MainActor
  func testADayTakenBackToNothingIsSentAsZero() async throws {
    let strip = try DailyStrip(db: SQLiteDatabase())
    try strip.set(.journal, day: "2026-10-17", value: 1, at: Date(timeIntervalSince1970: 1))
    try strip.set(.journal, day: "2026-10-18", value: 1, at: Date(timeIntervalSince1970: 1))
    let first = try await StripArchiveSource(strip: strip, item: .journal, now: clock(1_000))
      .page(after: nil, limit: 100)
    XCTAssertEqual(first.records.count, 2)

    // Un-ticked on this phone, and the other day's row taken back by the first sync's replay (#380).
    try strip.set(.journal, day: "2026-10-17", value: 0, at: Date(timeIntervalSince1970: 2))
    try strip.restoreOwn(.journal, day: "2026-10-18", to: nil)
    let second = try await StripArchiveSource(strip: strip, item: .journal, now: clock(2_000))
      .page(after: first.cursor, limit: 100)
    XCTAssertEqual(second.records.map { $0["day"] as? String }, ["2026-10-17", "2026-10-18"])
    XCTAssertEqual(second.records.map { $0["value"] as? Int }, [0, 0])
    XCTAssertEqual(second.cursor, "{}", "0 is what the archive assumes for a day it never heard of")
    let third = try await StripArchiveSource(strip: strip, item: .journal, now: clock(3_000))
      .page(after: second.cursor, limit: 100)
    XCTAssertTrue(third.records.isEmpty)
  }

  @MainActor
  func testTheStripsHistoryPagesOnceAndAQuietRunSendsNothing() async throws {
    let strip = try DailyStrip(db: SQLiteDatabase())
    for day in 1...5 { try strip.set(.magic, day: String(format: "2026-10-%02d", day), value: day) }
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    let source = StripArchiveSource(strip: strip, item: .magic)

    // The Cockpit away on the first page: nothing is taken, so nothing is remembered as taken.
    let failed = await makeUploader(cursors, answers: [503], seen: Seen()).upload(source) { _, _ in }
    XCTAssertEqual(failed.stopped, .cockpitAway)
    XCTAssertNil(try cursors.cursor("strip.magic"))

    let seen = Seen()
    var uploader = makeUploader(cursors, answers: [], seen: seen)
    uploader.pageSize = 2
    let report = await uploader.upload(source) { _, _ in }
    let sent = await seen.batches
    XCTAssertEqual(sent.map(\.count), [2, 2, 1])
    XCTAssertNil(report.stopped)
    let cursor = try XCTUnwrap(try cursors.cursor("strip.magic"))
    XCTAssertEqual(
      StripArchiveSource.decode(cursor),
      ["2026-10-01": 1, "2026-10-02": 2, "2026-10-03": 3, "2026-10-04": 4, "2026-10-05": 5])

    let quiet = Seen()
    let none = await makeUploader(cursors, answers: [], seen: quiet).upload(source) { _, _ in }
    let resent = await quiet.batches
    XCTAssertEqual(none, ArchiveUploader.Report())
    XCTAssertTrue(resent.isEmpty)
  }

  @MainActor
  func testAnUnreadableStripCursorStartsTheStreamOver() async throws {
    XCTAssertNil(StripArchiveSource.decode("not json"))
    XCTAssertNil(StripArchiveSource.decode("[1]"))
    XCTAssertNil(StripArchiveSource.decode(#"{"2026-10-18": "one"}"#))
    let strip = try DailyStrip(db: SQLiteDatabase())
    try strip.set(.gym, day: "2026-10-18", value: 1)
    let page = try await StripArchiveSource(strip: strip, item: .gym, now: clock(1_000))
      .page(after: "not json", limit: 100)
    XCTAssertTrue(page.restarted)
    XCTAssertEqual(page.records.map { $0["day"] as? String }, ["2026-10-18"])
    XCTAssertEqual(page.cursor.flatMap(StripArchiveSource.decode), ["2026-10-18": 1])
  }

  // MARK: The cursor store

  func testAddingTheArchiveToAnExistingDatabaseKeepsItsDataAndCursors() throws {
    let db = try SQLiteDatabase()
    let settings = try SettingsStore(db: db)
    try settings.set("location_tracking", "1")
    let locations = try LocationStore(db: db)
    let point = LocationPoint(latitude: 47, longitude: -122, timestamp: 1_000)
    try locations.insert([point])

    let cursors = try ArchiveCursorStore(db: db)
    XCTAssertNil(try cursors.cursor(ArchiveStream.points))
    try cursors.set(ArchiveStream.points, cursor: "1", at: 10)
    let reopened = try ArchiveCursorStore(db: db)
    XCTAssertEqual(try reopened.cursor(ArchiveStream.points), "1")
    XCTAssertEqual(try settings.get("location_tracking"), "1")
    XCTAssertEqual(try locations.points(afterId: 0, limit: 10).map(\.point), [point])
  }

  func testTheCursorStoreRoundTripsPerStream() throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    XCTAssertNil(try cursors.cursor("a"))
    try cursors.set("a", cursor: "1", at: 10)
    try cursors.set("b", cursor: "x", at: 11)
    try cursors.set("a", cursor: "2", at: 12)
    XCTAssertEqual(try cursors.cursor("a"), "2")
    XCTAssertEqual(try cursors.cursor("b"), "x")
  }

  // MARK: When

  func testARunIsDueFourHoursAfterOneThatGotSomewhere() {
    let now = Date(timeIntervalSince1970: 1_760_000_000)
    let ms = { (ago: TimeInterval) in Int64(now.addingTimeInterval(-ago).timeIntervalSince1970 * 1000) }
    XCTAssertTrue(ArchiveSchedule.isDue(.never, now: now))
    for state in [
      ArchiveState.caughtUp(at: ms(3 * 3600)), .backfilling(at: ms(3 * 3600)),
      .blocked(.refused(stream: "a", status: 400), since: ms(3 * 3600)), .blocked(.unreadable, since: ms(3 * 3600)),
    ] {
      XCTAssertFalse(ArchiveSchedule.isDue(state, now: now), "\(state)")
    }
    XCTAssertTrue(ArchiveSchedule.isDue(.caughtUp(at: ms(4 * 3600)), now: now))
    XCTAssertTrue(ArchiveSchedule.isDue(.backfilling(at: ms(4 * 3600)), now: now))
  }

  /// State-machine audit finding 5: "last run" meant "last attempt", so a run that never reached the Cockpit held the
  /// next foreground off for four hours.
  func testAfterACockpitAwayRunAForegroundIsDue() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let fiveMinAgo = Int64(now.addingTimeInterval(-300).timeIntervalSince1970 * 1000)
    let outcome = ArchiveOutcome(at: fiveMinAgo, stopped: [ArchiveStream.points: .cockpitAway])
    XCTAssertEqual(ArchiveState(outcome), .blocked(.cockpitAway, since: fiveMinAgo))
    XCTAssertTrue(ArchiveSchedule.isDue(ArchiveState(outcome), now: now), "back on the tailnet, opening the app runs")
    let lines = ArchiveStatus.lines(
      sends: true, outcome: outcome, lastCaughtUp: nil, now: Int64(now.timeIntervalSince1970 * 1000))
    XCTAssertTrue(lines[0].text.hasPrefix("Cockpit out of reach"), "Settings reads the same state")
  }

  func testTheStateAnOutcomeLeaves() {
    XCTAssertEqual(ArchiveState(nil), .never)
    XCTAssertEqual(ArchiveState(ArchiveOutcome(at: 1)), .caughtUp(at: 1))
    XCTAssertEqual(ArchiveState(ArchiveOutcome(at: 1, stopped: ["a": .pages, "b": .cancelled])), .backfilling(at: 1))
    XCTAssertEqual(
      ArchiveState(
        ArchiveOutcome(at: 1, stopped: ["b": .refused, "a": .unreadable, "c": .refused], refused: ["b": 413])),
      .blocked(.refused(stream: "b", status: 413), since: 1), "a refusal beats an unreadable stream")
    XCTAssertEqual(
      ArchiveState(ArchiveOutcome(at: 1, stopped: ["a": .refused, "z": .cockpitAway])),
      .blocked(.cockpitAway, since: 1), "the Cockpit out of reach beats everything")
    XCTAssertEqual(ArchiveState(ArchiveOutcome(at: 1, stopped: ["a": .unreadable])), .blocked(.unreadable, since: 1))
  }

  // MARK: A run (ArchiveRun)

  private struct Rig {
    let db: SQLiteDatabase
    let cursors: ArchiveCursorStore
    let ledger: ArchiveLedger
    var lines: [(String, [String: Any])] = []

    init() throws {
      db = try SQLiteDatabase()
      cursors = try ArchiveCursorStore(db: db)
      ledger = ArchiveLedger(settings: try SettingsStore(db: db))
    }

    func actions(_ type: String = "archive") -> [String] {
      lines.filter { $0.0 == type }.compactMap { $0.1["action"] as? String }
    }
  }

  private static let runStart = Date(timeIntervalSince1970: 1_800_000_000)

  @MainActor
  private func run(
    _ rig: inout Rig, sources: [ArchiveSource], health: [ArchiveSource] = [], answers: [Int] = [],
    unlocked: @escaping () -> Bool = { true }, cancelled: @escaping () -> Bool = { false }
  ) async -> ArchiveRun.Result {
    let run = ArchiveRun(
      reason: "test", sources: sources, healthSources: { health }, isUnlocked: unlocked, isCancelled: cancelled,
      now: { Self.runStart }, ledger: rig.ledger, uploader: makeUploader(rig.cursors, answers: answers, seen: Seen()))
    var lines: [(String, [String: Any])] = []
    let result = await run.perform { lines.append(($0, $1)) }
    rig.lines += lines
    return result
  }

  private struct Named: ArchiveSource {
    let stream: String
    let pages: [[String]]
    func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
      try await Pages(pages: pages).page(after: cursor, limit: limit)
    }
  }

  @MainActor
  func testACaughtUpRunHoldsTheNextForegroundOff() async throws {
    var rig = try Rig()
    let result = await run(
      &rig, sources: [Named(stream: "a", pages: [["x"]])], health: [Named(stream: "h", pages: [["y"]])])
    XCTAssertEqual(result.stopped, [:])
    XCTAssertEqual(result.streams, 2, "Health goes while the phone is unlocked")
    XCTAssertEqual(try rig.ledger.state(), .caughtUp(at: Int64(Self.runStart.timeIntervalSince1970 * 1000)))
    XCTAssertFalse(ArchiveSchedule.isDue(try rig.ledger.state(), now: Self.runStart.addingTimeInterval(300)))
    XCTAssertTrue(ArchiveSchedule.isDue(try rig.ledger.state(), now: Self.runStart.addingTimeInterval(4 * 3600)))
    XCTAssertNotNil(try rig.ledger.lastCaughtUp())
    XCTAssertNotNil(try rig.ledger.firstRun())
  }

  @MainActor
  func testAnUnreachedRunIsDueAgain() async throws {
    var rig = try Rig()
    let result = await run(
      &rig, sources: [Named(stream: "a", pages: [["x"]]), Named(stream: "b", pages: [["y"]])], answers: [503])
    XCTAssertEqual(result.stopped, ["a": .cockpitAway], "b is not tried: it would fail the same way")
    XCTAssertEqual(
      try rig.ledger.state(), .blocked(.cockpitAway, since: Int64(Self.runStart.timeIntervalSince1970 * 1000)))
    XCTAssertTrue(ArchiveSchedule.isDue(try rig.ledger.state(), now: Self.runStart.addingTimeInterval(300)))
    XCTAssertEqual(try rig.ledger.statusLines(sends: true, now: 0).first?.text.hasPrefix("Cockpit out of reach"), true)
  }

  @MainActor
  func testARefusedRunHoldsTheNextForegroundOff() async throws {
    var rig = try Rig()
    _ = await run(&rig, sources: [Named(stream: "a", pages: [["x"]])], answers: [400])
    XCTAssertEqual(
      try rig.ledger.state(),
      .blocked(.refused(stream: "a", status: 400), since: Int64(Self.runStart.timeIntervalSince1970 * 1000)))
    XCTAssertFalse(ArchiveSchedule.isDue(try rig.ledger.state(), now: Self.runStart.addingTimeInterval(300)))
  }

  @MainActor
  func testALockedRunRecordsNothing() async throws {
    var rig = try Rig()
    var askedHealth = false
    let run = ArchiveRun(
      reason: "refresh", sources: [Named(stream: "a", pages: [["x"]])],
      healthSources: {
        askedHealth = true
        return []
      }, isUnlocked: { false }, now: { Self.runStart }, ledger: rig.ledger,
      uploader: makeUploader(rig.cursors, answers: [503], seen: Seen()))
    var lines: [(String, [String: Any])] = []
    let result = await run.perform { lines.append(($0, $1)) }
    rig.lines = lines
    XCTAssertFalse(askedHealth, "Health is not read while locked")
    XCTAssertTrue(result.locked)
    XCTAssertNil(result.recorded)
    XCTAssertEqual(result.stopped, ["a": .cockpitAway], "the trail and the strip still go")
    XCTAssertEqual(try rig.ledger.state(), .never, "not even a Cockpit out of reach is recorded")
    XCTAssertNil(try rig.ledger.firstRun())
    XCTAssertEqual(rig.actions().first, "health_skipped")
    XCTAssertEqual(lines.first?.1["reason"] as? String, "phone locked")
  }

  @MainActor
  func testAPhoneLockedMidRunRecordsNothing() async throws {
    struct Unreadable: ArchiveSource {
      let stream = "health.x"
      func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
        throw URLError(.noPermissionsToReadFile)
      }
    }
    var rig = try Rig()
    _ = try rig.ledger.record(ArchiveOutcome(at: 7))
    var unlocked = true
    let result = await run(
      &rig, sources: [Named(stream: "a", pages: [["x"]])], health: [Unreadable(), Named(stream: "h", pages: [["y"]])],
      unlocked: {
        defer { unlocked = false }
        return unlocked
      })
    XCTAssertTrue(result.locked)
    XCTAssertEqual(result.stopped, ["health.x": .unreadable], "the stream after it is not tried")
    XCTAssertEqual(try rig.ledger.state(), .caughtUp(at: 7), "the run before it still decides")
  }

  @MainActor
  func testACancelKeepsCursors() async throws {
    var rig = try Rig()
    var taken = 0
    let counting = ArchiveUploader(cursors: rig.cursors, cockpit: "https://cockpit.test", deviceId: "dev") { request in
      (
        Data(#"{"ok": true, "inserted": 1, "duplicate": 0}"#.utf8),
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      )
    }
    let source = Named(stream: "a", pages: [["x"], ["y"], ["z"]])
    let run = ArchiveRun(
      reason: "refresh", sources: [source, Named(stream: "b", pages: [["w"]])], isUnlocked: { true },
      isCancelled: {
        taken += 1
        return taken > 2  // the run's check before "a", the uploader's before page 1, then iOS takes the time back
      }, now: { Self.runStart }, ledger: rig.ledger, uploader: counting)
    let result = await run.perform { _, _ in }
    XCTAssertEqual(result.pages, 1)
    XCTAssertEqual(result.stopped, ["a": .cancelled, "b": .cancelled], "nothing after the stream in flight starts")
    XCTAssertEqual(try rig.cursors.cursor("a"), "0", "the taken page's cursor stays")
    XCTAssertNil(try rig.cursors.cursor("b"))
    XCTAssertEqual(try rig.ledger.state(), .backfilling(at: Int64(Self.runStart.timeIntervalSince1970 * 1000)))
  }

  /// Was sim-smoke.sh's archive check: against an unreachable Cockpit the trail's first page goes, fails with the
  /// reason, and the run stops there; the run's line says `retry` for the trail.
  @MainActor
  func testAnUnreachableCockpitFailsTheTrailsFirstPageAndStopsTheRun() async throws {
    var rig = try Rig()
    let locations = try LocationStore(db: rig.db)
    try locations.insert((0..<3).map { LocationPoint(latitude: 47, longitude: -122, timestamp: Double(1_000 + $0)) })
    let away = ArchiveUploader(cursors: rig.cursors, cockpit: "https://127.0.0.1:65530/", deviceId: "dev") { _ in
      throw URLError(.cannotConnectToHost)
    }
    let run = ArchiveRun(
      reason: "hook", sources: [LocationArchiveSource(store: locations), Named(stream: "strip.magic", pages: [["m"]])],
      isUnlocked: { true }, now: { Self.runStart }, ledger: rig.ledger, uploader: away)
    var lines: [(String, [String: Any])] = []
    let result = await run.perform { lines.append(($0, $1)) }
    let failed = lines.first { $0.0 == "archive" && $0.1["action"] as? String == "failed" }?.1
    XCTAssertEqual(failed?["stream"] as? String, ArchiveStream.points)
    XCTAssertEqual(failed?["records"] as? Int, 3)
    XCTAssertEqual(failed?["why"] as? String, "hook")
    XCTAssertEqual(result.stopped, [ArchiveStream.points: .cockpitAway])
    let summary = lines.last { $0.0 == "archive_run" }?.1
    XCTAssertEqual(
      (summary?["stopped"] as? [String: String])?[ArchiveStream.points], "retry", "the log keeps its words")
    XCTAssertEqual(try rig.cursors.cursor(ArchiveStream.points), nil)
  }

  func testTheStateReadsWhatOlderBuildsStored() throws {
    let settings = try SettingsStore(db: SQLiteDatabase())
    let ledger = ArchiveLedger(settings: settings)
    XCTAssertEqual(try ledger.state(), .never)
    try settings.set(ArchiveLedger.legacyLastRunKey, "42")
    XCTAssertEqual(
      try ledger.state(), .caughtUp(at: 42), "a build before the outcome: its last run holds off as before")
    try settings.set(ArchiveLedger.outcomeKey, #"{"at": 50, "stopped": {"location.points": "retry"}, "refused": {}}"#)
    XCTAssertEqual(try ledger.state(), .blocked(.cockpitAway, since: 50), "the outcome wins once there is one")
  }

  func testTheDailySlotIsTheNext2330Local() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 9)))
    let slot = ArchiveSchedule.nextDaily(after: morning, calendar: calendar)
    let parts = calendar.dateComponents([.day, .hour, .minute], from: slot)
    XCTAssertEqual([parts.day, parts.hour, parts.minute], [19, 23, 30])
    let late = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 23, minute: 45)))
    XCTAssertEqual(calendar.component(.day, from: ArchiveSchedule.nextDaily(after: late, calendar: calendar)), 20)
  }

  private actor Seen {
    var batches: [[String]] = []
    /// Records the batch and returns its index.
    func add(_ guids: [String]) -> Int {
      batches.append(guids)
      return batches.count - 1
    }
  }
}
