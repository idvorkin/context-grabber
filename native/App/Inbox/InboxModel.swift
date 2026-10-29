//  #305, stories 038 and 039: the Inbox the share extension fills, read from the App Group, and its items sent to
//  Larry's inbox on the Cockpit each time the app opens or comes to the front (plan 2026-10-18-share-inbox-plan.md).

import ContextCore
import CoreGraphics
import Foundation
import Network

@MainActor
final class InboxModel: ObservableObject {
  @Published private(set) var items: [InboxItem] = []
  @Published private(set) var sending = false
  // #406, story 269: unknown at launch; the first path reading releases any waiting send.
  @Published private(set) var sendPolicy = InboxSendPolicy()
  var offline: Bool { sendPolicy.path == .offline }
  private let pathMonitor = NWPathMonitor()
  private var pathRetry: Task<Void, Never>?
  /// #565: the next try on its own after a failed send, while the app is open.
  private var backoff: Task<Void, Never>?
  /// #565: the last send found the Cockpit not answering; a waiting message says so.
  @Published private(set) var cockpitAway = false
  private let started = ContinuousClock.now
  private var now: Double {
    let elapsed = (ContinuousClock.now - started).components
    return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
  }
  /// A refresh came while a send was out: one more pass when it ends, for what was shared meanwhile (local review).
  private var sendAgain = false
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
  private let cockpit: String

  init(log: SessionLog, database: AppDatabase, cockpit: String = CockpitPage.url) {
    self.log = log
    self.database = database
    self.cockpit = cockpit
    store = InboxStore.shared()
    pathMonitor.pathUpdateHandler = { [weak self] path in
      // .requiresConnection (an on-demand VPN such as Tailscale's) comes up when a connection is tried, so it counts.
      let available = path.status != .unsatisfied
      let interfaces = Set(path.availableInterfaces.map { "\($0.type):\($0.name):\($0.index)" })
      let expensive = path.isExpensive
      let constrained = path.isConstrained
      Task { @MainActor [weak self] in
        self?.networkChanged(
          available: available, interfaces: interfaces, expensive: expensive, constrained: constrained)
      }
    }
    pathMonitor.start(queue: .main)
  }

  deinit {
    pathMonitor.cancel()
    pathRetry?.cancel()
    backoff?.cancel()
  }

  private func networkChanged(available: Bool, interfaces: Set<String>, expensive: Bool, constrained: Bool) {
    let wasOffline = offline
    let previousRetry = sendPolicy.retryAfter
    let becameOnline = sendPolicy.updatePath(
      available ? .online : .offline, interfaces: interfaces, expensive: expensive, constrained: constrained,
      waitingCount: store?.waitingCount ?? 0, now: now)
    schedulePathRetry(ifChangedFrom: previousRetry)
    if becameOnline {
      // Read shares made while away before deciding whether there is anything to send.
      refresh(reason: wasOffline ? "network_back" : "network_ready")
    } else if offline && !wasOffline {
      refresh(reason: "network_offline")
    }
  }

  private func schedulePathRetry(ifChangedFrom previousRetry: Double?) {
    guard previousRetry != sendPolicy.retryAfter else { return }
    pathRetry?.cancel()
    guard sendPolicy.retryAfter != nil else { return }
    pathRetry = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
      guard let self else { return }
      let decision = sendPolicy.pathRetryDecision(waitingCount: store?.waitingCount ?? 0, sending: sending, now: now)
      if decision == .send || decision == .sendAgain { refresh(reason: "network_changed") }
    }
  }

  /// Reads the Inbox, logs what the share extension added since the last look, then sends what waits.
  func refresh(reason: String) {
    reload()
    announceNew()
    send(reason: reason)
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
    // Nothing waits, so nothing says the Cockpit is away (local review).
    if waitingCount == 0 { cockpitAway = false }
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
    let seen = Set((database.setting("inbox_seen") ?? "").split(separator: ",").map(String.init))
    let fresh = items.filter { !seen.contains($0.id) }
    for item in fresh.reversed() {
      var fields: [String: Any] = ["action": "added", "item": item.id, "kind": item.kind.rawValue]
      fields["note"] = item.note != nil
      if let text = item.text { fields["text_chars"] = text.count }
      if let bytes = store?.imageBytes(of: item) { fields["bytes"] = bytes }
      if let site = item.site { fields["site"] = site }
      log.event("inbox", fields)
    }
    if fresh.contains(where: { !$0.isFixture }) { didAdd?() }
    // Only ids still in the Inbox, so the setting does not grow forever.
    database.setSetting("inbox_seen", items.map(\.id).joined(separator: ","))
  }

  private func send(reason: String) {
    guard let store else { return }
    let decision = sendPolicy.decision(waitingCount: waitingCount, sending: sending)
    if reason == "network_back" || reason == "network_changed", decision == .send || decision == .sendAgain {
      log.event("inbox", ["action": reason, "waiting": waitingCount, "sending": sending])
    }
    switch decision {
    case .wait: return
    case .offlineSkipped:
      log.event("inbox", ["action": "offline_skipped", "waiting": waitingCount, "why": reason])
      return
    case .sendAgain:
      sendAgain = true
      return
    case .send: break
    }
    sending = true
    sendPolicy.startedSend()
    let sender = InboxSender(store: store, cockpit: cockpit) { try await URLSession.shared.data(for: $0) }
    Task { [log] in
      let report = await sender.sendWaiting { type, fields in
        var fields = fields
        fields["why"] = reason
        log.event(type, fields)
      }
      let previousRetry = sendPolicy.retryAfter
      sendPolicy.finishedSend(retry: report.retry != nil, now: now, scheduled: reason == "backoff")
      schedulePathRetry(ifChangedFrom: previousRetry)
      sending = false
      cockpitAway = report.unreachable
      reload()
      scheduleBackoff()
      if !report.sent.isEmpty { didSend?() }
      if sendAgain {
        sendAgain = false
        send(reason: "again")
      }
    }
  }

  /// #565: a failed send is tried again on its own (30 s, doubling to 5 min) until nothing waits or the phone is
  /// offline; a send from any other trigger replaces the wait. ponytail: a suspended app's timer fires late, on resume.
  private func scheduleBackoff() {
    backoff?.cancel()
    backoff = nil
    guard let delay = sendPolicy.backoffDelay, waitingCount > 0 else { return }
    log.event("inbox", ["action": "backoff", "seconds": delay, "failed_in_a_row": sendPolicy.failedInARow])
    backoff = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      // A send already out reschedules when it ends; joining it would be a second try straight after (local review).
      guard let self, !offline, !sending, waitingCount > 0 else { return }
      refresh(reason: "backoff")
    }
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
