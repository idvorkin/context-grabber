import XCTest

@testable import ContextCore

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// #305, #406, #525, #565, stories 039, 269, 488, 507–510: when the Inbox sends, on an injected clock, timers and
/// transport over a temp-directory store. A relaunch is a new outbox over the same directory.
final class InboxOutboxTests: XCTestCase {
  private var dir: URL!
  private var store: InboxStore { InboxStore(directory: dir) }
  private let cockpit = "https://cockpit.test"

  override func setUp() {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString)")
  }

  override func tearDown() { try? FileManager.default.removeItem(at: dir) }

  // MARK: Fakes

  private final class Timer: InboxTimer, @unchecked Sendable {
    let seconds: Double
    let fire: @MainActor () -> Void
    var cancelled = false
    init(_ seconds: Double, _ fire: @escaping @MainActor () -> Void) {
      self.seconds = seconds
      self.fire = fire
    }
    func cancel() { cancelled = true }
  }

  /// The waits the outbox asked for, fired by hand.
  @MainActor private final class Timers {
    var all: [Timer] = []
    var live: [Timer] { all.filter { !$0.cancelled } }
    func schedule(_ seconds: Double, _ fire: @escaping @MainActor () -> Void) -> InboxTimer {
      let timer = Timer(seconds, fire)
      all.append(timer)
      return timer
    }
    /// Fires the newest live wait of that length.
    func fire(_ seconds: Double) {
      guard let timer = live.last(where: { $0.seconds == seconds }) else { return XCTFail("no \(seconds) s wait") }
      timer.cancelled = true
      timer.fire()
    }
  }

  private final class Clock: @unchecked Sendable { var now = 0.0 }

  private final class Lines: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [(String, [String: Any])] = []
    func add(_ type: String, _ fields: [String: Any]) { lock.withLock { lines.append((type, fields)) } }
    var all: [(String, [String: Any])] { lock.withLock { lines } }
    func actions(_ type: String? = nil) -> [String] {
      all.filter { type == nil || $0.0 == type }.compactMap { $0.1["action"] as? String }
    }
    func first(_ action: String) -> [String: Any]? { all.first { $0.1["action"] as? String == action }?.1 }
  }

  /// Every request, and the answer each gets: `answer` decides, `gate` holds each request until opened.
  private actor Wire {
    var requests: [URLRequest] = []
    var paths: [String] { requests.map { $0.url?.path ?? "" } }
    var ids: [String] {
      requests.compactMap {
        (try? JSONSerialization.jsonObject(with: $0.httpBody ?? Data()) as? [String: Any])?["id"] as? String
      }
    }
    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func record(_ request: URLRequest) async {
      requests.append(request)
      if held { await withCheckedContinuation { waiters.append($0) } }
    }
    func hold() { held = true }
    /// Returns once `count` requests have come in.
    func arrived(_ count: Int) async {
      for _ in 0..<10_000 where requests.count < count { await Task.yield() }
      XCTAssertGreaterThanOrEqual(requests.count, count)
    }
    func release() {
      held = false
      waiters.forEach { $0.resume() }
      waiters = []
    }
  }

  private enum Answer { case ok, timeout, refuseFiles }

  @MainActor
  private final class Rig {
    let outbox: InboxOutbox
    let timers = Timers()
    let clock = Clock()
    let lines = Lines()
    let wire = Wire()
    var refreshes: [String] = []
    var finished: [InboxSender.Report] = []

    init(store: InboxStore?, cockpit: String) {
      let timers = self.timers
      let clock = self.clock
      let lines = self.lines
      let wire = self.wire
      let box = AnswerBox()
      outbox = InboxOutbox(
        store: store, cockpit: cockpit, now: { clock.now }, schedule: { timers.schedule($0, $1) },
        log: { lines.add($0, $1) },
        transport: { request in
          await wire.record(request)
          switch box.answer {
          case .timeout: throw URLError(.timedOut)
          case .refuseFiles where request.url?.path == "/attachments":
            return ChatTests.answer(request, 400, InboxOutboxTests.picturesOnlyBody)
          case .ok where request.url?.path == "/attachments":
            return ChatTests.answer(request, 200, #"{"ok": true, "ref": "2026-11-07/0123456789abcdef.pdf"}"#)
          default:
            return ChatTests.answer(request, 200, #"{"ok": true, "thread": "igor2-88g.900"}"#)
          }
        })
      answerBox = box
      outbox.refresh = { [unowned self] reason in
        refreshes.append(reason)
        outbox.send(reason: reason)
      }
      outbox.finished = { [unowned self] report in finished.append(report) }
    }

    private let answerBox: AnswerBox
    func answer(_ new: Answer) { answerBox.answer = new }

    func online(_ interfaces: Set<String> = ["wifi:en0:1"]) {
      outbox.networkChanged(available: true, interfaces: interfaces, expensive: false, constrained: false)
    }

    func offline() { outbox.networkChanged(available: false, interfaces: [], expensive: false, constrained: false) }

    func send(_ reason: String) async {
      outbox.send(reason: reason)
      await outbox.settled()
    }
  }

  private final class AnswerBox: @unchecked Sendable { var answer: Answer = .ok }
  static let picturesOnlyBody = #"{"ok": false, "error": "not an image Cockpit accepts (png, jpeg, gif or webp)"}"#

  private func text(_ id: String, at: Int64 = 1, thread: String? = "igor2-88g.900") throws {
    try store.add(InboxItem(id: id, kind: .text, sharedAt: at, text: "message \(id)", thread: thread))
  }

  // MARK: What the phone keeps (#809, chat spec)

  private let day: Int64 = 24 * 3_600_000

  /// The audit's finding: a sent message left the phone only when its thread was opened and listed it.
  func testAnUnopenedThreadsSentMessagesLeaveThePhoneSevenDaysAfterTheirSend() throws {
    try text("old")
    try text("young")
    try text("waiting")
    try text("refused")
    try text("earlier-share", thread: nil)
    try store.add(InboxItem(id: "photo", kind: .image, sharedAt: 1, thread: "igor2-88g.900"), image: Data([7]))
    let now = 100 * day
    try store.markSent("old", at: now - 7 * day, thread: "igor2-88g.900")
    try store.markSent("photo", at: now - 30 * day, thread: "igor2-88g.900")
    try store.markSent("young", at: now - 7 * day + 1, thread: "igor2-88g.900")
    try store.markRefused("refused", reason: "too big")
    try store.markSent("earlier-share", at: now - 90 * day)

    XCTAssertEqual(try store.dropOldSent(now: now), 2, "no thread was ever read")
    XCTAssertEqual(store.items().items.map(\.id).sorted(), ["earlier-share", "refused", "waiting", "young"])
    XCTAssertFalse(
      try FileManager.default.contentsOfDirectory(atPath: dir.path).contains { $0.hasPrefix("photo") },
      "its picture goes with it")
    XCTAssertEqual(try store.dropOldSent(now: now), 0, "nothing more is due")
    XCTAssertEqual(try store.dropOldSent(now: now + 1), 1, "the young one, a millisecond later")
  }

  func testAClockSetBackDropsNothing() throws {
    try text("a")
    try store.markSent("a", at: 100 * day, thread: "igor2-88g.900")
    XCTAssertEqual(try store.dropOldSent(now: 0), 0)
    XCTAssertEqual(store.items().items.map(\.id), ["a"])
  }

  // MARK: The path (#406, story 269)

  @MainActor func testALaunchWaitsForThePathAndTheFirstReadingSends() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    await rig.send("launch")
    let before = await rig.wire.requests.count
    XCTAssertEqual(before, 0, "the path is unknown until its first reading")
    rig.online()
    await rig.outbox.settled()
    XCTAssertEqual(rig.refreshes, ["network_ready"])
    let ids = await rig.wire.ids
    XCTAssertEqual(ids, ["a"])
    XCTAssertEqual(store.item("a")?.status, .sent)
    XCTAssertEqual(rig.finished.map(\.sent), [["a"]])
  }

  @MainActor func testOfflineHoldsItAndSaysWhyAndTheNetworksReturnSendsIt() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.offline()
    XCTAssertTrue(rig.outbox.offline)
    XCTAssertEqual(rig.refreshes, ["network_offline"])
    await rig.send("foreground")
    let none = await rig.wire.requests.count
    XCTAssertEqual(none, 0)
    let skipped = rig.lines.all.filter { $0.1["action"] as? String == "offline_skipped" }.map(\.1)
    XCTAssertEqual(skipped.compactMap { $0["why"] as? String }, ["network_offline", "foreground"])
    XCTAssertEqual(skipped.last?["waiting"] as? Int, 1)

    rig.online()
    await rig.outbox.settled()
    XCTAssertEqual(rig.refreshes.last, "network_back")
    XCTAssertEqual(rig.lines.first("network_back")?["waiting"] as? Int, 1)
    let ids = await rig.wire.ids
    XCTAssertEqual(ids, ["a"])
    XCTAssertEqual(rig.lines.first("sent")?["why"] as? String, "network_back")
  }

  @MainActor func testNothingWaitingSendsNothing() async {
    let rig = Rig(store: store, cockpit: cockpit)
    rig.online()
    await rig.send("compose")
    let count = await rig.wire.requests.count
    XCTAssertEqual(count, 0)
    XCTAssertTrue(rig.finished.isEmpty)
    XCTAssertTrue(rig.timers.all.isEmpty)
  }

  @MainActor func testWithoutAnAppGroupNothingIsSent() async {
    let rig = Rig(store: nil, cockpit: cockpit)
    rig.online()
    await rig.send("compose")
    XCTAssertFalse(rig.outbox.sending)
    XCTAssertTrue(rig.finished.isEmpty)
  }

  // MARK: One send at a time (local review)

  @MainActor func testOneSendIsOutAtATimeAndRefreshesMeanwhileRunOneMorePass() async throws {
    try text("a", at: 1)
    let rig = Rig(store: store, cockpit: cockpit)
    rig.online()
    await rig.outbox.settled()
    try text("b", at: 2)
    await rig.wire.hold()
    rig.outbox.send(reason: "compose")
    XCTAssertTrue(rig.outbox.sending)
    await rig.wire.arrived(2)
    try text("c", at: 3)  // shared while b is out
    rig.outbox.send(reason: "foreground")
    rig.outbox.send(reason: "compose")
    await rig.wire.release()
    await rig.outbox.settled()
    let ids = await rig.wire.ids
    XCTAssertEqual(ids, ["a", "b", "c"], "each once, in order")
    XCTAssertEqual(
      rig.lines.all.filter { $0.0 == "chat" }.compactMap { $0.1["why"] as? String },
      [
        "network_ready", "compose", "again",
      ])
    XCTAssertFalse(rig.outbox.sending)
    XCTAssertEqual(rig.finished.count, 3, "two refreshes during the send asked for one more pass, not two")
  }

  // MARK: The backoff (#565)

  @MainActor func testAFailedSendTriesAgainAfter30sThen60sAndStopsOnceItGoes() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.timeout)
    rig.online()
    await rig.outbox.settled()
    XCTAssertTrue(rig.outbox.cockpitAway, "the Cockpit not answering is said on the message")
    XCTAssertEqual(store.item("a")?.status, .waiting)
    XCTAssertEqual(rig.timers.live.map(\.seconds), [30])
    XCTAssertEqual(rig.lines.first("backoff")?["seconds"] as? Double, 30)

    rig.timers.fire(30)
    await rig.outbox.settled()
    XCTAssertEqual(rig.refreshes.last, "backoff")
    XCTAssertEqual(rig.timers.live.map(\.seconds), [60], "the backoff's own try steps the wait")

    rig.answer(.ok)
    rig.timers.fire(60)
    await rig.outbox.settled()
    XCTAssertEqual(store.item("a")?.status, .sent)
    XCTAssertFalse(rig.outbox.cockpitAway)
    XCTAssertTrue(rig.timers.live.isEmpty)
    let tries = await rig.wire.ids
    XCTAssertEqual(tries, ["a", "a", "a"])
  }

  @MainActor func testASendIgorStartsReplacesTheWaitWithoutStretchingIt() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.timeout)
    rig.online()
    await rig.outbox.settled()
    let first = try XCTUnwrap(rig.timers.live.first)
    await rig.send("foreground")
    XCTAssertTrue(first.cancelled)
    XCTAssertEqual(rig.timers.live.map(\.seconds), [30])
  }

  @MainActor func testTheBackoffDoesNothingOfflineDuringASendOrWithNothingWaiting() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.timeout)
    rig.online()
    await rig.outbox.settled()
    let wait = try XCTUnwrap(rig.timers.live.first)
    rig.offline()
    await rig.outbox.settled()
    wait.fire()
    XCTAssertFalse(rig.refreshes.contains("backoff"), "offline: the network's return sends instead")

    rig.online()
    await rig.outbox.settled()
    let next = try XCTUnwrap(rig.timers.live.first)
    await rig.wire.hold()
    rig.outbox.send(reason: "compose")
    next.fire()
    XCTAssertFalse(rig.refreshes.contains("backoff"), "a send already out reschedules when it ends")
    await rig.wire.release()
    await rig.outbox.settled()

    let last = try XCTUnwrap(rig.timers.live.first)
    try store.delete(try XCTUnwrap(store.item("a")))
    last.fire()
    XCTAssertFalse(rig.refreshes.contains("backoff"), "nothing waits")
  }

  @MainActor func testARefusalIsNoFailureSoNothingRetries() async throws {
    var draft = InboxDraft()
    draft.file = ChatFile(name: "report.pdf", data: Data("%PDF".utf8))
    _ = try draft.save(to: store, at: 1, thread: "igor2-88g.900")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.refuseFiles)
    rig.online()
    await rig.outbox.settled()
    XCTAssertTrue(rig.timers.all.isEmpty)
    XCTAssertFalse(rig.outbox.cockpitAway)
  }

  @MainActor func testReadingAnInboxWithNothingWaitingClearsTheAwayNote() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.timeout)
    rig.online()
    await rig.outbox.settled()
    rig.outbox.read(waiting: 1)
    XCTAssertTrue(rig.outbox.cockpitAway)
    rig.outbox.read(waiting: 0)
    XCTAssertFalse(rig.outbox.cockpitAway)
  }

  // MARK: A new route after a failure (#406)

  @MainActor func testANewRouteAfterAFailureTriesOnceHalfASecondLater() async throws {
    try text("a")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.timeout)
    rig.online()
    await rig.outbox.settled()
    rig.answer(.ok)
    rig.clock.now = 10
    rig.online(["wifi:en0:1", "other:utun4:9"])  // the tunnel comes up
    XCTAssertEqual(rig.timers.live.map(\.seconds).sorted(), [0.5, 30])
    rig.timers.fire(0.5)
    XCTAssertFalse(rig.refreshes.contains("network_changed"), "the clock has not reached the debounce yet")

    rig.clock.now = 10.2
    rig.online(["wifi:en0:1"])  // and settles back: the wait starts over
    rig.clock.now = 10.8
    rig.timers.fire(0.5)
    await rig.outbox.settled()
    XCTAssertEqual(rig.refreshes.last, "network_changed")
    XCTAssertEqual(rig.lines.first("network_changed")?["waiting"] as? Int, 1)
    XCTAssertEqual(store.item("a")?.status, .sent)
  }

  // MARK: No address, then a launch that names one (#525, stories 507–510)

  @MainActor func testWithNoAddressItWaitsWithoutRetryingAndALaterLaunchDeliversItOnce() async throws {
    try text("a")
    let nowhere = Rig(store: store, cockpit: ChatCockpit.nowhere)
    nowhere.online()
    await nowhere.outbox.settled()
    let none = await nowhere.wire.requests.count
    XCTAssertEqual(none, 0)
    XCTAssertEqual(nowhere.lines.first("no_address")?["waiting"] as? Int, 1)
    XCTAssertEqual(nowhere.lines.first("no_address")?["why"] as? String, "network_ready")
    XCTAssertTrue(nowhere.timers.all.isEmpty, "no address is nothing to retry")
    XCTAssertEqual(store.item("a")?.status, .waiting)

    let relaunch = Rig(store: InboxStore(directory: dir), cockpit: "http://localhost:8797")
    relaunch.online()
    await relaunch.outbox.settled()
    await relaunch.send("foreground")
    let urls = await relaunch.wire.requests.map { $0.url?.absoluteString }
    XCTAssertEqual(urls, ["http://localhost:8797/chat/igor2-88g.900"], "once, to the address the later launch named")
    XCTAssertEqual(store.item("a")?.status, .sent)
  }

  // MARK: A refused file and Send again (#633, stories 487–489)

  @MainActor func testARefusedFileIsKeptAndSendAgainUploadsItAgainWithNoMessageUntilTheCockpitTakesIt() async throws {
    var draft = InboxDraft()
    draft.file = ChatFile(name: "report.pdf", data: Data("%PDF-1.7 smoke".utf8))
    let item = try draft.save(to: store, at: 1, thread: "igor2-88g.900")
    let rig = Rig(store: store, cockpit: cockpit)
    rig.answer(.refuseFiles)
    rig.online()
    await rig.outbox.settled()
    let refused = try XCTUnwrap(store.item(item.id))
    XCTAssertEqual(refused.status, .refused)
    XCTAssertTrue(refused.canSendAgain)
    XCTAssertEqual(store.file(of: refused), Data("%PDF-1.7 smoke".utf8), "the phone keeps the file")
    XCTAssertEqual(rig.lines.first("refused")?["status"] as? Int, 400)
    XCTAssertNotNil(rig.lines.first("refused")?["file_type"])

    rig.outbox.sendAgain(refused)
    await rig.outbox.settled()
    XCTAssertEqual(rig.lines.first("send_again")?["item"] as? String, item.id)
    XCTAssertEqual(rig.refreshes.last, "send_again")
    XCTAssertEqual(rig.lines.actions("chat").filter { $0 == "refused" }.count, 2, "too soon: refused again")
    let paths = await rig.wire.paths
    XCTAssertEqual(paths, ["/attachments", "/attachments"], "no message goes without its file")
    XCTAssertTrue(try XCTUnwrap(store.item(item.id)).canSendAgain)

    rig.answer(.ok)
    rig.outbox.sendAgain(try XCTUnwrap(store.item(item.id)))
    await rig.outbox.settled()
    let all = await rig.wire.paths
    XCTAssertEqual(all.suffix(2), ["/attachments", "/chat/igor2-88g.900"])
    XCTAssertEqual(store.item(item.id)?.status, .sent)
  }

  // MARK: What the app has seen (#305)

  func testTheFirstLookAnnouncesOldestFirstAndTheSettingKeepsOnlyWhatIsThere() {
    let a = InboxItem(id: "a", kind: .text, sharedAt: 1, text: "x")
    let b = InboxItem(id: "b", kind: .link, sharedAt: 2, url: "https://example.com/y", note: "n")
    let c = InboxItem(id: "c", kind: .text, sharedAt: 3, text: "z")
    let look = InboxSeen.look([c, b, a], seen: "a,gone")
    XCTAssertEqual(look.fresh.map(\.id), ["b", "c"])
    XCTAssertTrue(look.anyReal)
    XCTAssertEqual(look.setting, "c,b,a")
    XCTAssertEqual(InboxSeen.look([c, b, a], seen: look.setting).fresh, [])
    XCTAssertEqual(InboxSeen.look([a], seen: nil).fresh.map(\.id), ["a"])
  }

  func testFixturesAloneAreNothingRealOnItsWayToLarry() {
    let fixture = InboxItem(id: InboxItem.fixtureID(), kind: .text, sharedAt: 1, text: "test")
    let look = InboxSeen.look([fixture], seen: "")
    XCTAssertEqual(look.fresh.count, 1)
    XCTAssertFalse(look.anyReal)
  }

  func testTheAddedLineSaysTheKindAndSizeNeverTheContent() {
    var link = InboxItem(id: "b", kind: .link, sharedAt: 2, url: "https://example.com/private", note: "secret note")
    link.offered = "3"
    let fields = link.addedLogFields(bytes: nil)
    XCTAssertEqual(fields["action"] as? String, "added")
    XCTAssertEqual(fields["kind"] as? String, "link")
    XCTAssertEqual(fields["note"] as? Bool, true)
    XCTAssertEqual(fields["new_thread"] as? Bool, true)
    XCTAssertEqual(fields["site"] as? String, "example.com")
    XCTAssertEqual(fields["offered"] as? String, "3")
    XCTAssertFalse("\(fields)".contains("secret"))
    XCTAssertFalse("\(fields)".contains("private"))
    let text = InboxItem(id: "t", kind: .text, sharedAt: 1, text: "héllo", thread: "igor2-88g.1")
    let line = text.addedLogFields(bytes: 12)
    XCTAssertEqual(line["text_chars"] as? Int, 5)
    XCTAssertEqual(line["thread"] as? String, "igor2-88g.1")
    XCTAssertEqual(line["bytes"] as? Int, 12)
    XCTAssertNil(line["site"])
  }
}
