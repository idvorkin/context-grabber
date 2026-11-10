//  #305, stories 038 and 039: the Inbox the share extension fills, read from the App Group, and its items sent to
//  Larry's inbox on the Cockpit each time the app opens or comes to the front (plan 2026-10-18-share-inbox-plan.md).

import ContextCore
import CoreGraphics
import Foundation
import Network

@MainActor
final class InboxModel: ObservableObject {
  @Published private(set) var items: [InboxItem] = []
  /// When and whether to send (ContextCore's `InboxOutbox`, host-tested): this model hands it the network path, the
  /// clock and URLSession, and shows what it says.
  private let outbox: InboxOutbox
  // #406, story 269: unknown at launch; the first path reading releases any waiting send.
  var offline: Bool { outbox.offline }
  /// #565: the last send found the Cockpit not answering; a waiting message says so.
  var cockpitAway: Bool { outbox.cockpitAway }
  private let pathMonitor = NWPathMonitor()
  /// Each image item's small preview, decoded once per item.
  private(set) var thumbnails: [String: CGImage] = [:]
  var waitingCount: Int { items.filter { $0.status == .waiting }.count }

  let store: InboxStore?
  /// After a send that delivered something: chat reads the threads again, so a new one appears under its key.
  var didSend: (() -> Void)?
  /// Something new is on its way to Larry (a compose or a share found): chat asks for notifications once.
  var didAdd: (() -> Void)?
  private let log: SessionLog
  private let database: AppDatabase

  init(log: SessionLog, database: AppDatabase, cockpit: String) {
    self.log = log
    self.database = database
    let store = InboxStore.shared(cockpit: cockpit)
    self.store = store
    let started = ContinuousClock.now
    outbox = InboxOutbox(
      store: store, cockpit: cockpit,
      now: {
        let elapsed = (ContinuousClock.now - started).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
      },
      schedule: InboxTaskTimer.schedule, log: { [log] type, fields in log.event(type, fields) },
      transport: { try await URLSession.shared.data(for: $0) })
    outbox.waitingCount = { [weak self] in self?.waitingCount ?? 0 }
    outbox.refresh = { [weak self] reason in self?.refresh(reason: reason) }
    outbox.finished = { [weak self] report in
      guard let self else { return }
      objectWillChange.send()
      reload()
      if !report.sent.isEmpty { didSend?() }
    }
    pathMonitor.pathUpdateHandler = { [weak self] path in
      // .requiresConnection (an on-demand VPN such as Tailscale's) comes up when a connection is tried, so it counts.
      let available = path.status != .unsatisfied
      let interfaces = Set(path.availableInterfaces.map { "\($0.type):\($0.name):\($0.index)" })
      let expensive = path.isExpensive
      let constrained = path.isConstrained
      Task { @MainActor [weak self] in
        guard let self else { return }
        objectWillChange.send()
        outbox.networkChanged(
          available: available, interfaces: interfaces, expensive: expensive, constrained: constrained)
      }
    }
    pathMonitor.start(queue: .main)
  }

  deinit {
    pathMonitor.cancel()
  }

  /// Reads the Inbox, logs what the share extension added since the last look, then sends what waits.
  func refresh(reason: String) {
    // #794: which chat a shared link started is kept eight hours and no longer.
    do {
      try store?.forgetOldLinkStarts()
    } catch {
      log.event("error", ["where": "inbox_link_starts", "message": "\(error)"])
    }
    // #809: a sent chat message leaves the phone seven days after its send, its thread opened or not.
    do {
      let dropped = try store?.dropOldSent(now: Int64(Date().timeIntervalSince1970 * 1000)) ?? 0
      if dropped > 0 { log.event("inbox", ["action": "sent_dropped", "count": dropped]) }
    } catch {
      log.event("error", ["where": "inbox_sent_dropped", "message": "\(error)"])
    }
    reload()
    // #809: what the outbox still holds, each time the app starts or comes to the front.
    if reason == "launch" || reason == "foreground" {
      log.event(
        "chat", ChatOutboxLook.whole(items, now: Int64(Date().timeIntervalSince1970 * 1000)).logFields(why: reason))
    }
    announceNew()
    objectWillChange.send()
    outbox.send(reason: reason)
  }

  /// Stories 262–264: saved locally before sending; never logs the draft's content. `thread`: the chat thread this
  /// message goes to; nil starts a new one (spec 2026-10-25).
  func add(_ draft: inout InboxDraft, id: String = UUID().uuidString.lowercased(), thread: String? = nil) throws {
    guard let store else {
      throw NSError(
        domain: "InboxModel.add", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "This build has no App Group, so the Inbox is unreachable."])
    }
    let bytes = draft.byteCount
    let item = try draft.save(to: store, at: Int64(Date().timeIntervalSince1970 * 1000), id: id, thread: thread)
    log.event(
      "ui",
      [
        "action": "inbox_compose_add", "kind": item.kind.rawValue, "bytes": bytes, "new_thread": thread == nil,
      ])
    didAdd?()
    refresh(reason: "compose")
  }

  func reload() {
    guard let store else { return }
    let read = store.items()
    var kept: [String: CGImage] = [:]
    for item in read.items where item.kind == .image {
      kept[item.id] =
        thumbnails[item.id] ?? store.image(of: item).flatMap { InboxSend.thumbnail($0, maxPixels: 168) }
    }
    thumbnails = kept
    items = read.items
    outbox.read(waiting: waitingCount)
    for name in read.unreadable { log.event("error", ["where": "inbox_read", "file": name]) }
  }

  func delete(_ item: InboxItem) {
    do {
      try store?.delete(item)
      log.event(
        "inbox", ["action": "deleted", "item": item.id, "kind": item.kind.rawValue, "status": "\(item.status)"])
    } catch {
      log.event("error", ["where": "inbox_delete", "item": item.id, "message": "\(error)"])
    }
    reload()
  }

  /// Story 488: a refused file tries again, the same message.
  func sendAgain(_ item: InboxItem) { outbox.sendAgain(item) }

  /// Chat messages the Cockpit's thread now lists: the phone's copy, image and all, is no longer needed.
  func forget(_ delivered: [InboxItem]) {
    for item in delivered {
      do {
        try store?.delete(item)
      } catch {
        log.event("error", ["where": "inbox_delete", "item": item.id, "message": "\(error)"])
      }
    }
    log.event("inbox", ["action": "delivered_removed", "count": delivered.count])
    reload()
  }

  /// One `inbox` added line per item, the first time the app sees it: the kind and the size, never the content.
  private func announceNew() {
    let look = InboxSeen.look(items, seen: database.setting("inbox_seen"))
    for item in look.fresh { log.event("inbox", item.addedLogFields(bytes: store?.imageBytes(of: item))) }
    if look.anyReal { didAdd?() }
    database.setSetting("inbox_seen", look.setting)
  }

  // MARK: Launch hooks (docs/TESTING.md)

  /// `GRABBER_INBOX_FIXTURE=1`: three items as the share extension would write them, for the simulator. Their ids
  /// mark them as fixtures, which are never sent: the simulator reaches the tailnet too.
  func addFixture() {
    guard let store else { return log.event("error", ["where": "inbox_fixture", "message": "no App Group"]) }
    let now = Int64(Date().timeIntervalSince1970 * 1000)
    do {
      try store.add(
        InboxItem(
          id: InboxItem.fixtureID(), kind: .link, sharedAt: now - 2_000, url: "https://idvork.in/eulogy",
          note: "for Larry"))
      try store.add(
        InboxItem(id: InboxItem.fixtureID(), kind: .text, sharedAt: now - 1_000, text: "A thought worth talking about.")
      )
      try store.add(InboxItem(id: InboxItem.fixtureID(), kind: .text, sharedAt: now, text: "Another one."))
    } catch {
      log.event("error", ["where": "inbox_fixture", "message": "\(error)"])
    }
  }
}
