import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Story 270's heart-rate gaps (context-grabber-kseb): every reading of a workout, the newest year first, big pages
/// in several batches.
final class HealthSeriesTests: XCTestCase {
  // MARK: Every reading of a stored series

  func testAStoredSeriesBecomesOneRecordPerReading() throws {
    let parent: [String: Any] = [
      "guid": "0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22", "type": "HKQuantityTypeIdentifierHeartRate",
      "start": 1_660_570_000_000.0, "end": 1_660_570_300_000.0, "value": 142.0, "unit": "count/min",
      "source": "Igor's Apple Watch", "source_bundle": "com.apple.health.watch", "device": "Apple Watch", "count": 3,
    ]
    let t0 = Date(timeIntervalSince1970: 1_660_570_000)
    let readings = (0..<3).map {
      ArchiveSeries.Reading(start: t0 + Double($0) * 5, end: t0 + Double($0) * 5, value: 130 + Double($0) * 10)
    }
    let records = ArchiveSeries.records(parent: parent, readings: readings)
    XCTAssertEqual(records.count, 3)
    XCTAssertEqual(records.map { $0["value"] as? Double }, [130, 140, 150])
    XCTAssertEqual(records.map { $0["start"] as? Double }, [1_660_570_000_000, 1_660_570_005_000, 1_660_570_010_000])
    XCTAssertEqual(
      records.first?["guid"] as? String, "r:0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22:1660570000000",
      "the sample and the reading's start: the same reading sent twice is one record")
    for record in records {
      XCTAssertEqual(record["series"] as? String, "0f6c1a2e-1111-4a8e-9c1d-aa00bb11cc22")
      XCTAssertEqual(record["type"] as? String, "HKQuantityTypeIdentifierHeartRate")
      XCTAssertEqual(record["unit"] as? String, "count/min")
      XCTAssertEqual(record["source"] as? String, "Igor's Apple Watch")
      XCTAssertNil(record["count"], "a reading is one value")
      let guid = try XCTUnwrap(record["guid"] as? String)
      XCTAssertNotNil(guid.range(of: ArchiveTests.cockpitGUID, options: .regularExpression), guid)
    }
    XCTAssertEqual(Set(records.compactMap { $0["guid"] as? String }).count, 3)
  }

  // MARK: The newest year first

  private let day: Int64 = 86_400_000
  private let now: Int64 = 1_795_600_000_000

  func testTheWalkStartsAtNowAndGoesBackFourHundredDays() {
    let sweep = RecentSweep.start(now: now)
    XCTAssertEqual(sweep.floor, now - 400 * day)
    XCTAssertEqual(sweep.next(now: now), .back(from: now - 400 * day, through: now))
  }

  func testAFullPageBackMovesTheWalkToItsOldestStart() {
    let sweep = RecentSweep.start(now: now)
    let starts = [now - 10, now - 20, now - 30]
    let (next, more) = sweep.after(.back(from: sweep.floor, through: now), starts: starts, limit: 3)
    XCTAssertTrue(more)
    XCTAssertEqual(next.oldest, now - 30)
    XCTAssertEqual(next.newest, now - 10, "the walk forward later starts above the newest it sent")
    XCTAssertFalse(next.done)
    XCTAssertEqual(next.next(now: now), .back(from: sweep.floor, through: now - 30))
  }

  func testAPageAllOnOneInstantStillMovesTheWalk() {
    var sweep = RecentSweep.start(now: now)
    sweep.oldest = now - 50
    let (next, _) = sweep.after(.back(from: sweep.floor, through: now - 50), starts: [now - 50, now - 50], limit: 2)
    XCTAssertEqual(next.oldest, now - 51, "a run of samples on one instant cannot hold the walk")
  }

  func testAShortPageEndsTheWalkAndTheNextRunsGoForward() {
    var sweep = RecentSweep.start(now: now)
    sweep.oldest = now - 300 * day
    sweep.newest = now - 1000
    let (done, more) = sweep.after(
      .back(from: sweep.floor, through: sweep.oldest!), starts: [now - 350 * day], limit: 5)
    XCTAssertTrue(done.done)
    XCTAssertTrue(more, "the same run goes on to what is new")
    XCTAssertEqual(done.next(now: now), .forward(after: now - 1000))
    let (fwd, fwdMore) = done.after(.forward(after: now - 1000), starts: [now - 500, now - 200], limit: 5)
    XCTAssertEqual(fwd.newest, now - 200)
    XCTAssertFalse(fwdMore)
    XCTAssertEqual(fwd.next(now: now), .forward(after: now - 200))
  }

  func testAnEmptyHistoryWalksForwardFromWhereTheWalkStarted() {
    let sweep = RecentSweep.start(now: now)
    let (done, _) = sweep.after(.back(from: sweep.floor, through: now), starts: [], limit: 5)
    XCTAssertTrue(done.done)
    XCTAssertEqual(done.next(now: now + 1000), .forward(after: now))
  }

  func testTheSweepSurvivesAsItsCursor() {
    let sweep = RecentSweep(floor: 1, oldest: 5, newest: 9, done: false)
    XCTAssertEqual(RecentSweep(json: sweep.json), sweep)
    XCTAssertNil(RecentSweep(json: "not json"))
    XCTAssertNil(RecentSweep(json: nil))
  }

  func testTheDenseTypesAreTheOnesThatStoppedOnPages() {
    XCTAssertEqual(
      RecentSweep.denseTypes,
      [
        "HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierActiveEnergyBurned", "HKQuantityTypeIdentifierDistanceWalkingRunning",
      ])
  }

  // MARK: Two passes over one stream, big pages in several batches

  private struct Paged: ArchiveSource {
    let stream = "health.test"
    var cursorKey = "health.test"
    let pages: [Int]
    func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
      let index = cursor.flatMap { Int($0) }.map { $0 + 1 } ?? 0
      guard index < pages.count else { return ArchivePage(records: [], cursor: cursor, more: false) }
      let records = (0..<pages[index]).map { ["guid": "g\(index)-\($0)", "v": 1] as [String: Any] }
      return ArchivePage(records: records, cursor: String(index), more: index + 1 < pages.count)
    }
  }

  private actor Batches {
    var sent: [(stream: String, count: Int)] = []
    func add(_ stream: String, _ count: Int) -> Int {
      sent.append((stream, count))
      return sent.count - 1
    }
  }

  private func uploader(_ cursors: ArchiveCursorStore, failAt: Int? = nil, batches: Batches) -> ArchiveUploader {
    ArchiveUploader(cursors: cursors, cockpit: "https://cockpit.test", deviceId: "dev") { request in
      let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
      let n = await batches.add(body["stream"] as? String ?? "", (body["records"] as? [Any])?.count ?? 0)
      let status = n == failAt ? 503 : 200
      return (
        Data(#"{"ok": true, "inserted": 1, "duplicate": 0}"#.utf8),
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      )
    }
  }

  @MainActor
  func testAPageBiggerThanABatchGoesAsSeveralAndMovesOnOnlyWhenAllAreTaken() async throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    let source = Paged(pages: [2500])
    let batches = Batches()
    var stopped = uploader(cursors, failAt: 1, batches: batches)
    stopped.pageSize = 1000
    let first = await stopped.upload(source) { _, _ in }
    XCTAssertEqual(first.stopped, .cockpitAway)
    XCTAssertNil(try cursors.cursor("health.test"), "the page's second batch failed, so its place stays")

    let again = Batches()
    var whole = uploader(cursors, batches: again)
    whole.pageSize = 1000
    let report = await whole.upload(source) { _, _ in }
    let counts = await again.sent.map(\.count)
    XCTAssertEqual(counts, [1000, 1000, 500], "a batch never holds more than the Cockpit takes")
    XCTAssertEqual(try cursors.cursor("health.test"), "0")
    XCTAssertNil(report.stopped)
    XCTAssertEqual(report.pages, 1, "one page of the source, however many batches it took")
  }

  @MainActor
  func testTwoPassesOverOneStreamKeepTheirOwnPlaces() async throws {
    let cursors = try ArchiveCursorStore(db: SQLiteDatabase())
    let batches = Batches()
    let up = uploader(cursors, batches: batches)
    _ = await up.upload(Paged(pages: [1, 1])) { _, _ in }
    _ = await up.upload(Paged(cursorKey: "health.test#recent", pages: [1])) { _, _ in }
    XCTAssertEqual(try cursors.cursor("health.test"), "1")
    XCTAssertEqual(try cursors.cursor("health.test#recent"), "0")
    let streams = await batches.sent.map(\.stream)
    XCTAssertEqual(Set(streams), ["health.test"], "both passes feed the same stream, so the archive dedupes them")
  }
}
