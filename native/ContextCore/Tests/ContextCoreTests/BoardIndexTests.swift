import XCTest

@testable import ContextCore

final class BoardIndexTests: XCTestCase {
  let utc = TimeZone(identifier: "UTC") ?? .current
  let nov1 = Date(timeIntervalSince1970: 1_793_534_400)

  func testNewBoardsAreNamedForTheDayAndNumberedAfterTheFirst() {
    var index = BoardIndex()
    XCTAssertEqual(
      index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad", timeZone: utc).title, "Board, Nov 1")
    XCTAssertEqual(
      index.add(id: "b", at: nov1, device: "ipad", deviceName: "iPad", timeZone: utc).title, "Board, Nov 1 (2)")
    XCTAssertEqual(
      index.add(id: "c", at: nov1, device: "ipad", deviceName: "iPad", timeZone: utc).title, "Board, Nov 1 (3)")
  }

  func testAColourOnANewBoardLeavesItNewAndGoesUpWithItsFirstStroke() {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.setPaper("a", to: .cream, at: 2_000_000_000_000)
    let board = index.board("a")
    XCTAssertEqual(board?.paper, .cream)
    XCTAssertEqual(board?.updated, board?.created, "closing it without a stroke still takes it away")
    index.drew("a", strokes: 1, at: 2_000_000_000_001)
    XCTAssertEqual(index.pendingUploads(device: "ipad").first?.paperID, "cream")
  }

  func testAColourOnADrawnBoardIsAChangeForICloud() {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.drew("a", strokes: 1, at: 2_000_000_000_000)
    index.uploaded("a", at: 2_000_000_000_000)
    index.setPaper("a", to: .plain, at: 2_000_000_000_500)
    XCTAssertEqual(index.pendingUploads(device: "ipad"), [], "the colour it already has changes nothing")
    index.setPaper("a", to: .sage, at: 2_000_000_001_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad").map(\.id), ["a"])
    XCTAssertEqual(index.board("a")?.current, true, "the drawing here is still the board's")
  }

  func testAnotherDevicesColourComesDownWithItsBoard() {
    var index = BoardIndex()
    let remote = BoardEntry(
      id: "a", title: "T", created: 1, updated: 2, strokes: 1, device: "ipad", deviceName: "iPad", paperID: "sage")
    index.merge(cloud: [remote], device: "phone")
    XCTAssertEqual(index.board("a")?.paper, .sage)
    var recoloured = remote
    recoloured.paperID = "lilac"
    recoloured.updated = 3
    index.merge(cloud: [recoloured], device: "phone")
    XCTAssertEqual(index.board("a")?.paper, .lilac)
  }

  func testAListWithNoColoursOrAColourFromANewerBuildStillReads() throws {
    let old =
      #"{"boards":[{"id":"a","title":"T","created":1,"updated":1,"strokes":0,"device":"d","deviceName":"n"}],"deleted":[]}"#
    XCTAssertEqual(try JSONDecoder().decode(BoardIndex.self, from: Data(old.utf8)).board("a")?.paper, .plain)
    let new = old.replacingOccurrences(of: #""strokes":0"#, with: #""strokes":0,"paperID":"neon""#)
    let board = try JSONDecoder().decode(BoardIndex.self, from: Data(new.utf8)).board("a")
    XCTAssertEqual(board?.paper, .plain)
    XCTAssertEqual(board?.paperID, "neon")
  }

  func testTheListIsNewestChangeFirst() {
    var index = BoardIndex()
    index.add(id: "old", at: nov1, device: "ipad", deviceName: "iPad")
    index.add(id: "new", at: nov1.addingTimeInterval(60), device: "ipad", deviceName: "iPad")
    index.drew("old", strokes: 3, at: Int64(nov1.timeIntervalSince1970 * 1000) + 120_000)
    XCTAssertEqual(index.sorted.map(\.id), ["old", "new"], "drawing on a board brings it to the top")
  }

  func testOnlyTheDrawingDeviceEdits() {
    var index = BoardIndex()
    let board = index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    XCTAssertTrue(BoardIndex.editable(board, on: "ipad"))
    XCTAssertFalse(BoardIndex.editable(board, on: "phone"))
  }

  func testOwnBoardsWaitForUploadUntilICloudTakesThatVersion() {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.drew("a", strokes: 2, at: 2_000_000_000_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad").map(\.id), ["a"])
    index.uploaded("a", at: 2_000_000_000_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad"), [])
    index.drew("a", strokes: 3, at: 2_000_000_001_000)
    XCTAssertEqual(index.pendingUploads(device: "ipad").map(\.id), ["a"], "a later stroke goes up again")
    XCTAssertEqual(index.pendingUploads(device: "phone"), [], "never another device's board")
  }

  func testThePhoneTakesTheIPadsBoardsAndTheirChanges() {
    var phone = BoardIndex()
    let ipadBoard = BoardEntry(
      id: "a", title: "Board, Nov 1", created: 1, updated: 10, strokes: 4, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(phone.merge(cloud: [ipadBoard], device: "phone").fetch, ["a"])
    phone.fetched("a", at: 10)
    XCTAssertEqual(phone.merge(cloud: [ipadBoard], device: "phone").fetch, [], "nothing new, nothing fetched")
    var drawnOn = ipadBoard
    drawnOn.updated = 20
    drawnOn.strokes = 6
    XCTAssertEqual(phone.merge(cloud: [drawnOn], device: "phone").fetch, ["a"])
    XCTAssertEqual(phone.board("a")?.strokes, 6)
  }

  func testABoardItsDeviceDeletedLeavesTheOtherDevices() {
    var phone = BoardIndex()
    let ipadBoard = BoardEntry(
      id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = phone.merge(cloud: [ipadBoard], device: "phone")
    XCTAssertEqual(phone.merge(cloud: [], device: "phone").dropped, ["a"])
    XCTAssertNil(phone.board("a"))
  }

  func testThisDevicesOwnBoardsAreNeverTakenFromICloud() {
    var ipad = BoardIndex()
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.drew("a", strokes: 5, at: 3_000_000_000_000)
    let stale = BoardEntry(
      id: "a", title: "A", created: 1, updated: 4_000_000_000_000, strokes: 1, device: "ipad", deviceName: "iPad")
    let result = ipad.merge(cloud: [stale], device: "ipad")
    XCTAssertEqual(result.fetch, [])
    XCTAssertEqual(ipad.board("a")?.strokes, 5)
    XCTAssertEqual(ipad.merge(cloud: [], device: "ipad").dropped, [], "an own board not yet uploaded stays")
  }

  func testADeleteWaitsForICloudAndIsNotUndoneByIt() {
    var ipad = BoardIndex()
    ipad.add(id: "never-up", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.remove("never-up", device: "ipad")
    XCTAssertEqual(ipad.deleted, [], "a board iCloud never had needs no delete there")
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.uploaded("a", at: 1)
    ipad.remove("a", device: "ipad")
    XCTAssertEqual(ipad.deleted, ["a"])
    let cloudCopy = BoardEntry(
      id: "a", title: "A", created: 1, updated: 1, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = ipad.merge(cloud: [cloudCopy], device: "ipad")
    XCTAssertNil(ipad.board("a"))
    ipad.deletedInCloud("a")
    XCTAssertEqual(ipad.deleted, [])
  }

  // Story 396, #613: any device deletes any board.
  private func ipadBoard(updated: Int64 = 10) -> BoardEntry {
    BoardEntry(id: "a", title: "A", created: 1, updated: updated, strokes: 1, device: "ipad", deviceName: "iPad")
  }

  /// The iPad's list holding board "a", which iCloud took at `updated` 10.
  private func ipadList() -> BoardIndex {
    BoardIndex(boards: [
      BoardEntry(
        id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad", uploaded: 10,
        fetched: 10)
    ])
  }

  func testThePhoneDeletesTheIPadsBoardInICloudEvenOneNeverChanged() {
    var phone = BoardIndex()
    _ = phone.merge(cloud: [ipadBoard(updated: 1)], device: "phone")
    phone.remove("a", device: "phone")
    XCTAssertEqual(phone.deleted, ["a"])
    XCTAssertEqual(phone.merge(cloud: [ipadBoard(updated: 1)], device: "phone").fetch, [])
    XCTAssertNil(phone.board("a"), "not brought back while iCloud still holds it")
  }

  func testATombstoneTakesTheBoardFromTheDeviceThatDrewIt() {
    var ipad = ipadList()
    XCTAssertEqual(ipad.merge(cloud: [], device: "ipad", tombstones: ["a": 10]).dropped, ["a"])
    XCTAssertNil(ipad.board("a"))
  }

  func testAnEmptyICloudListNeverTakesAnOwnBoard() {
    // An iCloud account switch, or another CloudKit environment: nothing asked for a delete.
    var ipad = ipadList()
    XCTAssertEqual(ipad.merge(cloud: [], device: "ipad").dropped, [])
    XCTAssertNotNil(ipad.board("a"))
  }

  func testATombstoneDoesNotTakeInkICloudLacksOrAnOpenBoard() {
    var drawn = ipadList()
    drawn.drew("a", strokes: 9, at: 20)
    XCTAssertEqual(drawn.merge(cloud: [], device: "ipad", tombstones: ["a": 10]).dropped, [], "unsent ink stays")
    var open = ipadList()
    XCTAssertEqual(open.merge(cloud: [], device: "ipad", tombstones: ["a": 10], open: ["a"]).dropped, [])
    XCTAssertEqual(open.merge(cloud: [], device: "ipad", tombstones: ["a": 10]).dropped, ["a"], "gone once it closes")
  }

  func testATombstoneOutranksARecordThatLandedLate() {
    var phone = BoardIndex()
    XCTAssertEqual(phone.merge(cloud: [ipadBoard()], device: "phone", tombstones: ["a": 10]).fetch, [])
    XCTAssertNil(phone.board("a"), "not added")
    _ = phone.merge(cloud: [ipadBoard()], device: "phone")
    XCTAssertEqual(phone.merge(cloud: [ipadBoard()], device: "phone", tombstones: ["a": 10]).dropped, ["a"])
  }

  func testTheBoardComesBackOnceItsDeviceSentNewInk() {
    // The iPad's upload clears the tombstone, so the phone that deleted it sees a board and no tombstone.
    var phone = BoardIndex()
    _ = phone.merge(cloud: [ipadBoard()], device: "phone", tombstones: ["a": 10])
    XCTAssertEqual(phone.merge(cloud: [ipadBoard(updated: 20)], device: "phone").fetch, ["a"])
    XCTAssertEqual(phone.board("a")?.updated, 20)
  }

  func testATombstoneNamesItsBoardAndABoardsOwnRecordNamesNone() {
    // The name is a contract with the tombstones already in iCloud, which are never cleared.
    XCTAssertEqual(BoardIndex.tombstone(of: "abc"), "deleted-abc")
    XCTAssertEqual(BoardIndex.tombstoned(by: "deleted-abc"), "abc")
    XCTAssertNil(BoardIndex.tombstoned(by: "1b7e2c4a-0000-4000-8000-000000000000"))
  }

  // Story 401: a delete covers only what the deleting device had seen.
  func testADeleteRemembersTheVersionItSawUntilICloudHasIt() {
    var phone = BoardIndex()
    _ = phone.merge(cloud: [ipadBoard(updated: 10)], device: "phone")
    phone.remove("a", device: "phone")
    XCTAssertEqual(phone.deletedVersions, ["a": 10])
    phone.deletedInCloud("a")
    XCTAssertEqual(phone.deletedVersions, [:])
  }

  func testInkSentAfterTheDeleteSawTheBoardOutlivesTheTombstoneAndGoesUpAgain() {
    var ipad = ipadList()
    ipad.drew("a", strokes: 9, at: 20)
    ipad.uploaded("a", at: 20)
    let first = ipad.merge(cloud: [], device: "ipad", tombstones: ["a": 10])
    XCTAssertEqual(first.dropped, [])
    XCTAssertTrue(first.resend, "the delete took its record, so iCloud needs it again")
    XCTAssertEqual(ipad.pendingUploads(device: "ipad").map(\.id), ["a"])
    let second = ipad.merge(cloud: [], device: "ipad", tombstones: ["a": 10])
    XCTAssertFalse(second.resend, "asked once: a board with no file can't loop")
    XCTAssertEqual(ipad.board("a")?.strokes, 9)
  }

  func testATombstoneCoversTheVersionItSawExactly() {
    var ipad = ipadList()
    let result = ipad.merge(cloud: [], device: "ipad", tombstones: ["a": 10])
    XCTAssertEqual(result.dropped, ["a"])
    XCTAssertFalse(result.resend)
  }

  func testATombstoneNamingNoVersionCoversEverythingSent() {
    var ipad = ipadList()
    ipad.drew("a", strokes: 9, at: 20)
    ipad.uploaded("a", at: 20)
    XCTAssertEqual(ipad.merge(cloud: [], device: "ipad", tombstones: ["a": .max]).dropped, ["a"])
  }

  func testAnotherDevicesNewerBoardBeatsAnOlderTombstone() {
    var phone = BoardIndex()
    let result = phone.merge(cloud: [ipadBoard(updated: 20)], device: "phone", tombstones: ["a": 10])
    XCTAssertEqual(result.fetch, ["a"])
    XCTAssertEqual(result.dropped, [])
    XCTAssertFalse(result.resend, "never another device's board")
  }

  func testAListSavedBeforeDeleteVersionsStillReads() throws {
    let saved = Data(#"{"boards":[],"deleted":["a"]}"#.utf8)
    let index = try JSONDecoder().decode(BoardIndex.self, from: saved)
    XCTAssertEqual(index.deleted, ["a"])
    XCTAssertEqual(index.deletedVersions, [:])
  }

  func testABoardDeletedWhileItsFirstUploadRunsStaysDeleted() {
    var ipad = BoardIndex()
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.drew("a", strokes: 3, at: 3_000_000_000_000)
    ipad.remove("a", device: "ipad")
    XCTAssertEqual(ipad.deleted, ["a"], "the upload in flight may land, so iCloud is told to delete it")
    ipad.uploaded("a", at: 3_000_000_000_000)
    let landed = BoardEntry(
      id: "a", title: "A", created: 1, updated: 3_000_000_000_000, strokes: 3, device: "ipad", deviceName: "iPad")
    _ = ipad.merge(cloud: [landed], device: "ipad")
    XCTAssertNil(ipad.board("a"))
  }

  func testRenameIsTrimmedAndCountsAsAChange() {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.rename("a", to: "  Energy week  ", at: 5_000_000_000_000)
    XCTAssertEqual(index.board("a")?.title, "Energy week")
    XCTAssertEqual(index.board("a")?.updated, 5_000_000_000_000)
    index.rename("a", to: "   ", at: 6_000_000_000_000)
    XCTAssertEqual(index.board("a")?.title, "Energy week", "a blank name is ignored")
  }

  func testTheIndexRoundTripsThroughJSON() throws {
    var index = BoardIndex()
    index.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    index.add(id: "b", at: nov1, device: "ipad", deviceName: "iPad")
    index.uploaded("b", at: 1)
    index.remove("b", device: "ipad")
    let back = try JSONDecoder().decode(BoardIndex.self, from: JSONEncoder().encode(index))
    XCTAssertEqual(back, index)
  }

  func testAFailedFetchIsAskedForAgainUntilItLands() {
    var phone = BoardIndex()
    let board = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(phone.merge(cloud: [board], device: "phone").fetch, ["a"])
    XCTAssertEqual(phone.merge(cloud: [board], device: "phone").fetch, ["a"], "the download failed: asked again")
    phone.fetched("a", at: 10)
    XCTAssertEqual(phone.merge(cloud: [board], device: "phone").fetch, [])
  }

  func testOwnBoardsTheListLostComeBackFromICloud() {
    var ipad = BoardIndex()
    let lost = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 3, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(ipad.merge(cloud: [lost], device: "ipad").fetch, ["a"])
    XCTAssertEqual(ipad.board("a")?.uploaded, 10, "iCloud already has it, so nothing goes back up")
    XCTAssertEqual(ipad.pendingUploads(device: "ipad"), [])
    ipad.fetched("a", at: 10)
    XCTAssertEqual(ipad.merge(cloud: [lost], device: "ipad").fetch, [])
    XCTAssertTrue(BoardIndex.editable(ipad.board("a") ?? lost, on: "ipad"), "drawn here again")
  }

  func testABoardICloudHoldsButCannotReadIsNotDropped() {
    var phone = BoardIndex()
    let board = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = phone.merge(cloud: [board], device: "phone")
    let result = phone.merge(cloud: [], device: "phone", unread: ["a"])
    XCTAssertEqual(result.dropped, [])
    XCTAssertEqual(result.fetch, [])
    XCTAssertNotNil(phone.board("a"))
  }

  func testABoardIsCurrentOnlyOnceItsLatestDrawingArrived() {
    var phone = BoardIndex()
    let board = BoardEntry(id: "a", title: "A", created: 1, updated: 10, strokes: 1, device: "ipad", deviceName: "iPad")
    _ = phone.merge(cloud: [board], device: "phone")
    XCTAssertEqual(phone.board("a")?.current, false, "listed, but its download hasn't landed")
    phone.fetched("a", at: 10)
    XCTAssertEqual(phone.board("a")?.current, true)
    var drawnOn = board
    drawnOn.updated = 20
    _ = phone.merge(cloud: [drawnOn], device: "phone")
    XCTAssertEqual(phone.board("a")?.current, false, "iCloud has newer ink than the copy here")
    var ipad = BoardIndex()
    ipad.add(id: "b", at: nov1, device: "ipad", deviceName: "iPad")
    XCTAssertEqual(ipad.board("b")?.current, true, "a board drawn here is always current")
    ipad.drew("b", strokes: 2, at: 2_000_000_000_000)
    XCTAssertEqual(ipad.board("b")?.current, true)
  }

  func testOwnBoardsDrawnHereNeverNeedAFetch() {
    var ipad = BoardIndex()
    ipad.add(id: "a", at: nov1, device: "ipad", deviceName: "iPad")
    ipad.drew("a", strokes: 2, at: 2_000_000_000_000)
    ipad.rename("a", to: "B", at: 2_000_000_001_000)
    ipad.uploaded("a", at: 2_000_000_001_000)
    let cloudCopy = ipad.board("a")!
    XCTAssertEqual(ipad.merge(cloud: [cloudCopy], device: "ipad").fetch, [])
  }

  // MARK: Stories 590, 593–595, 606, 658: which boards can be drawn on

  private let aDate = Date(timeIntervalSince1970: 1_800_000_000)

  func testOnlyABoardMadeOnPaperCanBeDrawnOn() {
    var index = BoardIndex()
    index.add(id: "old", at: aDate, device: "ipad", deviceName: "iPad")
    index.add(id: "new", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    XCTAssertEqual(index.board("old").map { BoardIndex.drawable($0, on: "ipad") }, false, "story 658: look-only")
    XCTAssertEqual(index.board("new").map { BoardIndex.drawable($0, on: "ipad") }, true)
    XCTAssertEqual(index.board("old").map(BoardIndex.drawnOnTheOldCanvas), true)
    XCTAssertEqual(index.board("new").map(BoardIndex.drawnOnTheOldCanvas), false)
  }

  func testABoardOnPaperIsDrawnOnOnlyWhereItsMade() {
    var index = BoardIndex()
    let board = index.add(id: "a", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    XCTAssertFalse(BoardIndex.drawable(board, on: "iphone"), "the look-only view elsewhere")
  }

  /// Story 658: the bar names why a board is look-only. Another device's board says whose it is, whichever canvas it was
  /// drawn on; this device's own old board says it's from the old canvas.
  func testTheBarSaysWhyABoardIsLookOnly() {
    var index = BoardIndex()
    let mine = index.add(id: "mine", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    let old = index.add(id: "old", at: aDate, device: "ipad", deviceName: "iPad")
    let theirs = index.add(id: "theirs", at: aDate, device: "iphone", deviceName: "iPhone", onPages: true)
    let theirsOld = index.add(id: "theirs-old", at: aDate, device: "iphone", deviceName: "iPhone")
    XCTAssertNil(BoardIndex.lookOnlyNote(mine, on: "ipad"))
    XCTAssertEqual(BoardIndex.lookOnlyNote(old, on: "ipad"), "Drawn on the old canvas: look only")
    XCTAssertEqual(BoardIndex.lookOnlyNote(theirs, on: "ipad"), "Drawn on iPhone: look only")
    XCTAssertEqual(BoardIndex.lookOnlyNote(theirsOld, on: "ipad"), "Drawn on iPhone: look only")
  }

  /// Story 746: on a phone every board is look-only, its own on paper too, and the bar says to draw on the iPad.
  func testNothingIsDrawnOnAPhone() {
    var index = BoardIndex()
    let mine = index.add(id: "mine", at: aDate, device: "iphone", deviceName: "iPhone", onPages: true)
    let ipads = index.add(id: "ipads", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    XCTAssertTrue(BoardIndex.drawable(mine, on: "iphone"), "the same board, off a phone")
    XCTAssertFalse(BoardIndex.drawable(mine, on: "iphone", onPhone: true))
    XCTAssertFalse(BoardIndex.drawable(ipads, on: "iphone", onPhone: true))
    XCTAssertEqual(BoardIndex.lookOnlyNote(mine, on: "iphone", onPhone: true), "Look only on iPhone: draw on the iPad")
    XCTAssertEqual(BoardIndex.lookOnlyNote(ipads, on: "iphone", onPhone: true), "Look only on iPhone: draw on the iPad")
  }

  func testAListFromBeforePaperStillReadsAndNoBoardInItIsOnPaper() throws {
    let board = #"{"id":"a","title":"T","created":1,"updated":2,"strokes":1,"device":"ipad","deviceName":"iPad"}"#
    let old = #"{"boards":["# + board + #"],"deleted":[]}"#
    let index = try JSONDecoder().decode(BoardIndex.self, from: Data(old.utf8))
    XCTAssertEqual(index.board("a").map { BoardIndex.drawable($0, on: "ipad") }, false)
  }

  func testOnPaperSurvivesTheListBeingSavedAndReadBack() throws {
    var index = BoardIndex()
    index.add(id: "a", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    let back = try JSONDecoder().decode(BoardIndex.self, from: JSONEncoder().encode(index))
    XCTAssertEqual(back.board("a")?.onPages, true)
  }

  func testOnPaperSurvivesEveryChangeToTheBoard() {
    var index = BoardIndex()
    index.add(id: "a", at: aDate, device: "ipad", deviceName: "iPad", onPages: true)
    index.drew("a", strokes: 3, at: 2_000_000_000_000)
    index.rename("a", to: "Notes", at: 2_000_000_000_100)
    index.setPaper("a", to: .cream, at: 2_000_000_000_200)
    index.uploaded("a", at: 2_000_000_000_200)
    XCTAssertEqual(index.board("a")?.onPages, true)
  }

  func testABoardOnPaperComesBackFromICloudOnPaper() {
    // A reinstall or an unreadable list: iCloud gives this device's board back, and it has to reopen on paper, as its
    // ink sits at the column's corner and not in the old canvas's middle.
    var index = BoardIndex()
    let cloud = BoardEntry(
      id: "a", title: "T", created: 1, updated: 2, strokes: 1, device: "ipad", deviceName: "iPad", onPages: true)
    _ = index.merge(cloud: [cloud], device: "ipad")
    XCTAssertEqual(index.board("a").map { BoardIndex.drawable($0, on: "ipad") }, true)
  }

  func testAnotherDevicesBoardOnPaperKeepsSayingSoAsItUpdates() {
    var index = BoardIndex()
    let first = BoardEntry(
      id: "a", title: "T", created: 1, updated: 2, strokes: 1, device: "ipad", deviceName: "iPad", onPages: true)
    _ = index.merge(cloud: [first], device: "iphone")
    var newer = first
    newer.updated = 3
    _ = index.merge(cloud: [newer], device: "iphone")
    XCTAssertEqual(index.board("a")?.onPages, true)
    XCTAssertEqual(index.board("a").map { BoardIndex.drawable($0, on: "iphone") }, false)
  }
}
