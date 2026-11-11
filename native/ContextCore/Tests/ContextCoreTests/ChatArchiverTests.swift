import Foundation
import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Archiving a chat (#589, #599; stories 307–309, 311–314) with the Cockpit's answers and the five seconds in the test's
/// hands: the row moves at once, a refusal puts it back, an Undo waits for the archive's answer, out-of-order answers
/// settle their own rows, the offer lasts five seconds, and a list read across a change is stale.
@MainActor
final class ChatArchiverTests: XCTestCase {
  // MARK: Fakes

  @MainActor final class List: ChatArchiveList {
    var threads: [ChatSummary]
    var undoArchive: [ChatSummary] = []
    var archiveProblem: String?
    var events: [ChatArchiver.Event] = []
    var refreshes = 0

    init(_ threads: [ChatSummary]) { self.threads = threads }

    func archiveLogged(_ event: ChatArchiver.Event) { events.append(event) }
    func archiveUnarchived() async { refreshes += 1 }

    func row(_ key: String) -> ChatSummary? { threads.first { $0.key == key } }
  }

  /// Each request waits until the test answers it, in any order.
  @MainActor final class Cockpit {
    private(set) var requests: [URLRequest] = []
    private var waiting: [CheckedContinuation<(Data, Int?), Error>] = []
    private var answered: Set<Int> = []

    var paths: [String] { requests.map { $0.url?.path ?? "" } }

    func send(_ request: URLRequest) async throws -> (Data, Int?) {
      requests.append(request)
      return try await withCheckedThrowingContinuation { waiting.append($0) }
    }

    func answer(_ index: Int, status: Int = 200, _ body: String = #"{"ok": true}"#) {
      guard index < waiting.count else { return XCTFail("no request \(index): \(paths)") }
      guard answered.insert(index).inserted else { return XCTFail("request \(index) answered twice") }
      waiting[index].resume(returning: (Data(body.utf8), status))
    }

    func fail(_ index: Int, _ why: String = "The network connection was lost.") {
      guard index < waiting.count else { return XCTFail("no request \(index): \(paths)") }
      guard answered.insert(index).inserted else { return XCTFail("request \(index) answered twice") }
      waiting[index].resume(throwing: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: why]))
    }
  }

  /// Each sleep waits until the test lets it end.
  @MainActor final class Clock {
    private(set) var asked: [Duration] = []
    private var waiting: [CheckedContinuation<Void, Never>?] = []

    func sleep(_ duration: Duration) async {
      asked.append(duration)
      await withCheckedContinuation { waiting.append($0) }
    }

    func end(_ index: Int) {
      guard index < waiting.count else { return XCTFail("no sleep \(index)") }
      waiting[index]?.resume()
      waiting[index] = nil
    }
  }

  private func row(
    _ key: String, done: Bool = false, archived: Bool = false, looksDone: Bool = false, pinned: Bool = false
  ) -> ChatSummary {
    ChatSummary(
      key: key, title: "T\(key)", lastTs: "", lastWho: "larry", lastText: "", done: done || archived,
      archived: archived, looksDone: looksDone, pinned: pinned)
  }

  private func make(_ rows: [ChatSummary]) -> (List, Cockpit, Clock, ChatArchiver) {
    let list = List(rows)
    let cockpit = Cockpit()
    let clock = Clock()
    let archiver = ChatArchiver(
      list: list, cockpit: "http://cockpit.test", transport: { try await cockpit.send($0) },
      sleep: { await clock.sleep($0) })
    return (list, cockpit, clock, archiver)
  }

  /// Lets every task on the main actor run up to its next wait.
  private func settle() async {
    for _ in 0..<50 { await Task.yield() }
  }

  /// A change under way; a test waits for it with `finish`, which fails rather than hangs on one that never ends.
  @MainActor final class Running {
    var finished = false
  }

  private func start(_ body: @escaping @MainActor () async -> Void) -> Running {
    let running = Running()
    Task {
      await body()
      running.finished = true
    }
    return running
  }

  private func finish(_ running: Running, file: StaticString = #filePath, line: UInt = #line) async {
    await until(running.finished)
    XCTAssertTrue(running.finished, "the change never finished", file: file, line: line)
  }

  /// Waits for a state the archiver's tasks reach, up to five real seconds: a loaded machine can take more than
  /// `settle`'s yields to schedule them (#844).
  private func until(_ condition: @autoclosure () -> Bool) async {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition(), ContinuousClock.now < deadline {
      await Task.yield()
      try? await Task.sleep(for: .milliseconds(1))
    }
  }

  // MARK: One change

  func testASwipeArchivesAtOnceThenOnTheCockpit() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b")])
    let done = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    XCTAssertEqual(list.row("a")?.archived, true, "under Done before the Cockpit answers")
    XCTAssertEqual(list.row("a")?.done, true)
    XCTAssertEqual(list.undoArchive.map(\.key), ["a"])
    XCTAssertEqual(list.undoArchive.first?.archived, false, "the offer is the row as it was")
    XCTAssertEqual(cockpit.paths, ["/chat/a/archive"])
    XCTAssertEqual(cockpit.requests.first?.httpMethod, "POST")
    cockpit.answer(0)
    await finish(done)
    XCTAssertEqual(list.row("a")?.archived, true)
    XCTAssertNil(list.archiveProblem)
    XCTAssertEqual(list.events, [.init(archive: true, thread: "a", from: "swipe", failure: nil)])
    XCTAssertEqual(list.refreshes, 0, "an archive the Cockpit took needs no list read")
    XCTAssertEqual(
      list.events.first?.fields["action"] as? String, "archive", "the log's action, thread, from, ok and reason")
    XCTAssertEqual(list.events.first?.fields["ok"] as? Bool, true)
  }

  func testARefusalPutsTheRowBackAndSaysWhy() async {
    let (list, cockpit, _, archiver) = make([row("a")])
    let done = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    cockpit.answer(0, status: 409, #"{"ok": false, "error": "pinned threads stay"}"#)
    await finish(done)
    XCTAssertEqual(list.row("a"), row("a"), "back in the live list as it was")
    XCTAssertEqual(list.undoArchive, [], "nothing to undo")
    XCTAssertEqual(list.archiveProblem, #"Could not archive "Ta": pinned threads stay (HTTP 409)"#)
    XCTAssertEqual(list.events.first?.failure, "pinned threads stay (HTTP 409)")
    XCTAssertEqual(list.events.first?.fields["ok"] as? Bool, false)
  }

  func testNoAnswerIsARefusalWithTheReason() async {
    let (list, cockpit, _, archiver) = make([row("a")])
    let done = start { await archiver.setArchived("a", true, from: "menu") }
    await settle()
    cockpit.fail(0)
    await finish(done)
    XCTAssertEqual(list.row("a")?.archived, false)
    XCTAssertEqual(list.archiveProblem, #"Could not archive "Ta": The network connection was lost."#)
  }

  func testAnUnarchiveTakenReadsTheListAgain() async {
    let (list, cockpit, _, archiver) = make([row("a", archived: true)])
    let done = start { await archiver.setArchived("a", false, from: "menu") }
    await settle()
    XCTAssertEqual(list.row("a")?.done, false, "live at once")
    XCTAssertEqual(cockpit.paths, ["/chat/a/unarchive"])
    cockpit.answer(0)
    await finish(done)
    XCTAssertEqual(list.refreshes, 1, "the Cockpit may still call it done: its list settles where it belongs")
    XCTAssertEqual(list.undoArchive, [], "an unarchive is never offered back")
  }

  func testTheMenuOffersNoUndo() async {
    let (list, cockpit, clock, archiver) = make([row("a")])
    let done = start { await archiver.setArchived("a", true, from: "menu") }
    await settle()
    XCTAssertEqual(list.undoArchive, [])
    XCTAssertEqual(clock.asked, [], "no five seconds")
    cockpit.answer(0)
    await finish(done)
  }

  func testARowAlreadySoOrGoneAsksNothing() async {
    let (list, cockpit, _, archiver) = make([row("a", archived: true)])
    await archiver.setArchived("a", true, from: "swipe")
    await archiver.setArchived("gone", false, from: "undo")
    XCTAssertEqual(cockpit.requests.count, 0)
    XCTAssertEqual(list.events, [])
    XCTAssertEqual(archiver.epoch, 0)
  }

  func testTheNextChangeClearsTheLastProblem() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b")])
    list.archiveProblem = "Could not archive \"Ta\": HTTP 502"
    let done = start { await archiver.setArchived("b", true, from: "swipe") }
    await settle()
    XCTAssertNil(list.archiveProblem)
    cockpit.answer(0)
    await finish(done)
  }

  // MARK: One at a time per thread

  func testAnUndoWhileTheArchiveIsUnansweredWaitsForItsAnswer() async {
    let (list, cockpit, _, archiver) = make([row("a")])
    let archive = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    let undo = start { await archiver.setArchived(list.undoArchive.map(\.key), false, from: "undo") }
    await settle()
    XCTAssertEqual(list.undoArchive, [], "the Undo line goes at once")
    XCTAssertEqual(cockpit.paths, ["/chat/a/archive"], "the unarchive waits for the archive's answer")
    XCTAssertEqual(list.row("a")?.archived, true)
    cockpit.answer(0)
    await finish(archive)
    await settle()
    XCTAssertEqual(cockpit.paths, ["/chat/a/archive", "/chat/a/unarchive"])
    XCTAssertEqual(list.row("a")?.archived, false, "live again at once")
    cockpit.answer(1)
    await finish(undo)
    XCTAssertEqual(list.events.map(\.from), ["swipe", "undo"])
    XCTAssertEqual(list.refreshes, 1)
  }

  func testAnUndoAfterARefusedArchiveAsksNothing() async {
    let (list, cockpit, _, archiver) = make([row("a")])
    let archive = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    let undo = start { await archiver.setArchived("a", false, from: "undo") }
    await settle()
    cockpit.answer(0, status: 502, "")
    await finish(archive)
    await finish(undo)
    XCTAssertEqual(cockpit.requests.count, 1, "the row was put back, so there is nothing to bring back")
    XCTAssertEqual(list.row("a")?.archived, false)
    XCTAssertEqual(list.archiveProblem, #"Could not archive "Ta": HTTP 502"#)
  }

  func testTwoThreadsGoTogetherAndAnswerInEitherOrder() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b"), row("c")])
    let done = start { await archiver.archiveSelected(["a", "b"]) }
    await settle()
    XCTAssertEqual(cockpit.paths, ["/chat/a/archive", "/chat/b/archive"], "different threads don't wait on each other")
    XCTAssertEqual(list.undoArchive.map(\.key), ["a", "b"], "one offer for the batch")
    cockpit.answer(1)
    await settle()
    XCTAssertEqual(list.row("b")?.archived, true)
    XCTAssertNil(list.archiveProblem, "nothing failed yet")
    cockpit.answer(0, status: 404, #"{"error": "no such thread"}"#)
    await finish(done)
    XCTAssertEqual(list.row("a")?.archived, false, "the refused one is back")
    XCTAssertEqual(list.row("b")?.archived, true, "the taken one stays")
    XCTAssertEqual(list.row("c")?.archived, false)
    XCTAssertEqual(list.undoArchive.map(\.key), ["b"], "the offer keeps only what went")
    XCTAssertEqual(list.archiveProblem, #"Could not archive "Ta": no such thread (HTTP 404)"#)
  }

  func testEveryThreadThatDidNotTakeIsNamedInOneProblem() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b")])
    let done = start { await archiver.archiveSelected(["a", "b"]) }
    await settle()
    cockpit.answer(0, status: 502, "")
    cockpit.fail(1, "timed out")
    await finish(done)
    XCTAssertEqual(list.archiveProblem, #"Could not archive 2 chats: "Ta": HTTP 502; "Tb": timed out"#)
    XCTAssertEqual(list.undoArchive, [])
  }

  func testUndoOfABatchBringsEveryThreadBack() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b")])
    let archive = start { await archiver.archiveSelected(["a", "b"]) }
    await settle()
    cockpit.answer(0)
    cockpit.answer(1)
    await finish(archive)
    XCTAssertEqual(ChatArchiver.undoLine(list.undoArchive), "Archived 2 chats")
    let undo = start { await archiver.setArchived(list.undoArchive.map(\.key), false, from: "undo") }
    await settle()
    XCTAssertEqual(cockpit.paths.suffix(2), ["/chat/a/unarchive", "/chat/b/unarchive"])
    XCTAssertEqual(list.threads.map(\.done), [false, false], "back in the live list at once")
    cockpit.answer(2)
    cockpit.answer(3)
    await finish(undo)
    XCTAssertEqual(list.refreshes, 2)
  }

  // MARK: The five seconds

  func testTheOfferLastsFiveSeconds() async {
    let (list, cockpit, clock, archiver) = make([row("a")])
    let done = start { await archiver.setArchived("a", true, from: "swipe") }
    await until(cockpit.requests.count == 1)
    cockpit.answer(0)
    await finish(done)
    await until(clock.asked.count == 1)
    XCTAssertEqual(clock.asked, [.seconds(5)])
    XCTAssertEqual(ChatArchiver.undoLine(list.undoArchive), #"Archived "Ta""#)
    clock.end(0)
    await until(list.undoArchive.isEmpty)
    XCTAssertEqual(list.undoArchive, [], "gone after five seconds")
    XCTAssertEqual(list.row("a")?.archived, true, "and the archive stands")
  }

  func testANewSwipeStartsTheFiveSecondsAgainWithOnlyItself() async {
    let (list, cockpit, clock, archiver) = make([row("a"), row("b")])
    let first = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    let second = start { await archiver.setArchived("b", true, from: "swipe") }
    await settle()
    XCTAssertEqual(list.undoArchive.map(\.key), ["b"], "a swipe's offer replaces the last")
    clock.end(0)
    await settle()
    XCTAssertEqual(list.undoArchive.map(\.key), ["b"], "the first swipe's five seconds don't end the second's")
    clock.end(1)
    await settle()
    XCTAssertEqual(list.undoArchive, [])
    cockpit.answer(0)
    cockpit.answer(1)
    await finish(first)
    await finish(second)
  }

  func testSelectStartsAFreshOfferAndABatchGrowsIt() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b"), row("c")])
    let swipe = start { await archiver.setArchived("c", true, from: "swipe") }
    await settle()
    let batch = start { await archiver.archiveSelected(["a", "b"]) }
    await settle()
    XCTAssertEqual(list.undoArchive.map(\.key), ["a", "b"], "the swipe's offer is not part of the batch")
    for i in 0..<3 { cockpit.answer(i) }
    await finish(swipe)
    await finish(batch)
  }

  func testNoUndoLineWithNothingOffered() {
    XCTAssertNil(ChatArchiver.undoLine([]))
  }

  // MARK: A list read across a change

  func testAListReadThatStartedBeforeAChangeOrItsAnswerIsStale() async {
    let (list, cockpit, _, archiver) = make([row("a")])
    defer { withExtendedLifetime(list) {} }
    let before = archiver.epoch
    XCTAssertTrue(archiver.isCurrent(before))
    let done = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    XCTAssertFalse(archiver.isCurrent(before), "it would put the thread back where it was")
    let during = archiver.epoch
    cockpit.answer(0)
    await finish(done)
    XCTAssertFalse(archiver.isCurrent(during), "the answer changes the list too")
    XCTAssertTrue(archiver.isCurrent(archiver.epoch))
  }

  func testAListThatComesBackMeanwhileShowsTheChangeOverIt() async {
    let (list, cockpit, _, archiver) = make([row("a"), row("b")])
    defer { withExtendedLifetime(list) {} }
    let fromCockpit = [row("a"), row("b")]
    let done = start { await archiver.setArchived("a", true, from: "swipe") }
    await settle()
    XCTAssertEqual(archiver.overlaid(fromCockpit).map(\.archived), [true, false], "the change shows over it")
    cockpit.answer(0)
    await finish(done)
    XCTAssertEqual(archiver.overlaid(fromCockpit), fromCockpit, "once answered, the Cockpit's list is the truth")
  }

  // MARK: What a row offers

  func testASwipeArchivesALiveThreadAndBringsBackAnArchivedOne() {
    XCTAssertEqual(ChatArchiveAction.swipe(row("a")), .archive)
    XCTAssertEqual(ChatArchiveAction.swipe(row("a", archived: true)), .unarchive)
    XCTAssertNil(ChatArchiveAction.swipe(row("a", done: true)), "a thread the Cockpit calls done has no swipe")
    XCTAssertNil(ChatArchiveAction.swipe(row("p", pinned: true)), "the pinned thread can't be archived")
  }

  func testTheMenuArchivesOrUnarchivesAndThePinnedThreadHasNone() {
    XCTAssertEqual(ChatArchiveAction.menu(row("a")), .archive)
    XCTAssertEqual(ChatArchiveAction.menu(row("a", done: true)), .archive)
    XCTAssertEqual(ChatArchiveAction.menu(row("a", archived: true)), .unarchive)
    XCTAssertNil(ChatArchiveAction.menu(row("p", pinned: true)))
  }

  // MARK: Select and Review

  func testReviewTicksWhatLooksDoneAndArchivesItInOneTap() {
    let threads = [
      row("p", pinned: true), row("a"), row("b", looksDone: true), row("old", done: true, looksDone: true),
    ]
    var selection = ChatListSelection()
    XCTAssertEqual(selection.reviewLine(threads), "1 chat looks done")
    XCTAssertEqual(selection.review(threads), 1)
    XCTAssertTrue(selection.selecting)
    XCTAssertTrue(selection.ticked("b"))
    XCTAssertFalse(selection.ticked("old"), "a Done thread isn't in the live list")
    XCTAssertNil(selection.reviewLine(threads), "no Review line while selecting")
    XCTAssertEqual(selection.archiveTitle(threads), "Archive (1)")
    XCTAssertEqual(selection.archivePicked(threads), ["b"])
    XCTAssertFalse(selection.selecting)
    XCTAssertEqual(selection.picked, [])
    XCTAssertTrue(row("b", looksDone: true).showsLooksDone, "the row's mark")
    XCTAssertFalse(row("old", done: true, looksDone: true).showsLooksDone, "not on a Done row")
    XCTAssertTrue(row("b", looksDone: true).archiving(true).archiving(false).showsLooksDone, "back after an Undo")
    let two = threads + [row("c", looksDone: true)]
    XCTAssertEqual(ChatListSelection().reviewLine(two), "2 chats look done")
    XCTAssertNil(ChatListSelection().reviewLine([row("a")]))
  }

  func testSelectTicksSeveralAndCancelArchivesNone() {
    let threads = [row("p", pinned: true), row("a"), row("b"), row("d", archived: true)]
    var selection = ChatListSelection()
    XCTAssertEqual(selection.toggleTitle, "Select")
    XCTAssertTrue(selection.showsDone(threads))
    XCTAssertTrue(selection.toggle())
    XCTAssertEqual(selection.toggleTitle, "Cancel")
    XCTAssertFalse(selection.showsDone(threads), "the Done fold hides while selecting")
    XCTAssertEqual(selection.archiveTitle(threads), "Archive (0)")
    XCTAssertFalse(selection.canArchive(threads))
    selection.tick("a")
    selection.tick("b")
    XCTAssertEqual(selection.archiveTitle(threads), "Archive (2)")
    XCTAssertTrue(selection.canArchive(threads))
    selection.tick("b")
    XCTAssertFalse(selection.ticked("b"), "a second tap unticks")
    selection.tick("b")
    XCTAssertFalse(selection.toggle(), "Cancel")
    XCTAssertEqual(selection.picked, [], "Cancel archives none")
    XCTAssertTrue(selection.toggle())
    XCTAssertEqual(selection.archiveTitle(threads), "Archive (0)", "a fresh Select starts with nothing ticked")
  }

  func testAThreadThatLeavesTheListWhileTickedIsNotArchived() {
    var selection = ChatListSelection()
    selection.toggle()
    selection.tick("a")
    selection.tick("b")
    let refreshed = [row("a"), row("b", done: true)]
    XCTAssertEqual(selection.archiveTitle(refreshed), "Archive (1)")
    XCTAssertEqual(selection.archivePicked(refreshed), ["a"])
  }

  func testThePinnedThreadHasNoTickAndSelectNeedsAnotherThread() {
    let pinned = row("p", pinned: true)
    var selection = ChatListSelection()
    XCTAssertTrue(selection.shows(pinned), "listed while not selecting")
    XCTAssertFalse(selection.canToggle([pinned, row("d", archived: true)]), "nothing Select could tick")
    XCTAssertTrue(selection.canToggle([pinned, row("a")]))
    selection.toggle()
    XCTAssertFalse(selection.shows(pinned), "no tick for the pinned thread")
    XCTAssertTrue(selection.shows(row("a")))
    XCTAssertTrue(selection.canToggle([pinned]), "Cancel always works")
  }
}
