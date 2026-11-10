//  #305, stories 038 and 039: the Inbox, things shared to Grabber Native waiting for Larry (spec
//  2026-10-17-native-share-inbox-design.md; plan 2026-10-18-share-inbox-plan.md). One file per item in a directory
//  of the App Group, because the share extension and the app are two processes: the extension only adds, and the
//  app records sends and deletes.

import Foundation

public struct InboxItem: Codable, Equatable, Sendable, Identifiable {
  public enum Kind: String, Codable, Sendable { case link, text, image, file }

  /// A lowercase UUID: the Cockpit's idempotency key (`[A-Za-z0-9_-]{1,64}`).
  public let id: String
  public let kind: Kind
  /// Unix ms.
  public let sharedAt: Int64
  public var url: String?
  public var text: String?
  public var note: String?
  /// The image's file name beside the item, as shared (HEIC stays HEIC until it is sent).
  public var imageFile: String?
  /// A document (#633): its name as picked, and its bytes beside the item.
  public var fileName: String?
  public var attachedFile: String?
  /// #809: waiting, sent or refused, one at a time (`InboxDelivery.swift`).
  public var delivery: Delivery = .waiting
  /// Unix ms when the Cockpit took it.
  public var sentAt: Int64? { if case .sent(let at, _) = delivery { at } else { nil } }
  /// The Cockpit's reason when it said the item itself is wrong; such an item is never sent again on its own
  /// (a document can go again on a tap: `canSendAgain`).
  public var refused: String? { if case .refused(let reason) = delivery { reason } else { nil } }
  /// Chat (spec 2026-10-25): the Cockpit thread this message goes to; nil starts a new thread (a share with *New chat* ticked, every +).
  public var thread: String?
  /// The thread it landed on, once sent. A sent item without one went to Larry's inbox before chat: an
  /// *Earlier share*.
  public var chatThread: String? { if case .sent(_, let thread) = delivery { thread } else { nil } }
  /// A whiteboard's picture: which board, which picture and where on the board it is (story 381).
  public var whiteboard: WhiteboardPicture?
  /// The board's strokes beside the item, `WhiteboardStrokes.wire` JSON, sent before the picture (story 424).
  public var strokesFile: String?
  /// What the share card's list of chats held when this was shared (#587), for the log: a count, or why not.
  public var offered: String?
  /// The types the other app offered on a share (#673), for the log: never content.
  public var shareTypes: String?

  /// Why a document whose bytes the phone can't read was refused: no request went (story 492).
  public static let fileUnreadable = "the file could not be read from the phone"

  /// Story 488: a refused document is kept to go again; anything else refused, or its bytes gone, is wrong for good.
  public var canSendAgain: Bool { kind == .file && status == .refused && refused != Self.fileUnreadable }

  public var isEarlierShare: Bool { sentAt != nil && chatThread == nil }

  public enum Status: Equatable, Sendable { case waiting, sent, refused }

  public var status: Status {
    switch delivery {
    case .waiting: .waiting
    case .sent: .sent
    case .refused: .refused
    }
  }

  /// A simulator fixture's id (the `GRABBER_INBOX_FIXTURE` hook): such an item is never sent to Larry.
  public static func fixtureID() -> String { "fixture-" + UUID().uuidString.lowercased() }
  public var isFixture: Bool { id.hasPrefix("fixture-") }

  /// A link's site, the only "where it came from" iOS gives a share extension.
  public var site: String? { url.flatMap { URL(string: $0)?.host } }

  public init(
    id: String = UUID().uuidString.lowercased(), kind: Kind, sharedAt: Int64, url: String? = nil,
    text: String? = nil, note: String? = nil, imageFile: String? = nil, thread: String? = nil,
    whiteboard: WhiteboardPicture? = nil, fileName: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.sharedAt = sharedAt
    self.url = url
    self.text = text
    self.note = note?.isEmpty == true ? nil : note
    self.imageFile = imageFile
    self.thread = thread
    self.whiteboard = whiteboard
    self.fileName = fileName
  }

  enum CodingKeys: String, CodingKey {
    case id, kind, url, text, note, thread, whiteboard, offered, delivery
    case sharedAt = "shared_at"
    case imageFile = "image_file"
    case strokesFile = "strokes_file"
    case fileName = "file_name"
    case attachedFile = "attached_file"
    case shareTypes = "share_types"
  }

  /// The fields an item file held before #809, read when it has no `delivery`.
  private enum LegacyKeys: String, CodingKey {
    case refused
    case sentAt = "sent_at"
    case chatThread = "chat_thread"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    kind = try c.decode(Kind.self, forKey: .kind)
    sharedAt = try c.decode(Int64.self, forKey: .sharedAt)
    url = try c.decodeIfPresent(String.self, forKey: .url)
    text = try c.decodeIfPresent(String.self, forKey: .text)
    note = try c.decodeIfPresent(String.self, forKey: .note)
    imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
    fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
    attachedFile = try c.decodeIfPresent(String.self, forKey: .attachedFile)
    thread = try c.decodeIfPresent(String.self, forKey: .thread)
    whiteboard = try c.decodeIfPresent(WhiteboardPicture.self, forKey: .whiteboard)
    strokesFile = try c.decodeIfPresent(String.self, forKey: .strokesFile)
    offered = try c.decodeIfPresent(String.self, forKey: .offered)
    shareTypes = try c.decodeIfPresent(String.self, forKey: .shareTypes)
    if let delivery = try c.decodeIfPresent(Delivery.self, forKey: .delivery) {
      self.delivery = delivery
    } else {
      let old = try decoder.container(keyedBy: LegacyKeys.self)
      delivery = .legacy(
        sentAt: try old.decodeIfPresent(Int64.self, forKey: .sentAt),
        chatThread: try old.decodeIfPresent(String.self, forKey: .chatThread),
        refused: try old.decodeIfPresent(String.self, forKey: .refused))
    }
  }
}

public struct InboxStore: Sendable {
  public let directory: URL

  public init(directory: URL) {
    self.directory = directory
  }

  /// The App Group the app, the widgets and the share extension share (project.yml gives each the entitlement).
  public static let appGroup = "group.com.idvorkin.grabbernative"

  /// The App Group's Inbox, or nil without the group (a test host, a build without the entitlement). On a Mac, the
  /// app's own folder, by which Cockpit this launch talks to.
  public static func shared(cockpit: String, group: String = appGroup) -> InboxStore? {
    #if targetEnvironment(macCatalyst)
      // #638: no share extension to share with on a Mac, and a build with no signing identity can't write the group's
      // folder even though it is handed one. The app's own folder holds the outbox.
      return
        (try? FileManager.default.url(
          for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        .map { mac(base: $0, cockpit: cockpit) }
    #elseif canImport(Darwin)
      return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        .map { InboxStore(directory: $0.appendingPathComponent("Inbox", isDirectory: true)) }
    #else
      // Linux (just test-linux) has no App Groups: an un-entitled host, as a Mac test host is.
      return nil
    #endif
  }

  /// #680, story 588: a Mac has one app folder for real launches and test launches, and a sender sends all that waits
  /// to its own address, so a launch named away from the real Cockpit keeps its own outbox.
  public static func mac(base: URL, cockpit: String) -> InboxStore {
    let folder = cockpit == CockpitPage.url ? "Inbox" : "Inbox-test"
    return InboxStore(directory: base.appendingPathComponent(folder, isDirectory: true))
  }

  /// The image (and a board's strokes), or a document, first, the item last, so an item on disk always has its files.
  @discardableResult
  public func add(
    _ item: InboxItem, image: Data? = nil, imageExtension: String = "jpg", strokes: Data? = nil, file: Data? = nil
  ) throws -> InboxItem {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var item = item
    if let image {
      let name = "\(item.id).\(imageExtension)"
      try image.write(to: directory.appendingPathComponent(name), options: .atomic)
      item.imageFile = name
    }
    if let strokes {
      let name = "\(item.id).strokes"
      try strokes.write(to: directory.appendingPathComponent(name), options: .atomic)
      item.strokesFile = name
    }
    if let file {
      // Never under the file's own extension: a picked .json would read as an Inbox item.
      let name = "\(item.id).file"
      try file.write(to: directory.appendingPathComponent(name), options: .atomic)
      item.attachedFile = name
    }
    try write(item)
    return item
  }

  /// Newest first. An item that does not decode is skipped and named in `unreadable`.
  public func items() -> (items: [InboxItem], unreadable: [String]) {
    let files =
      (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    var items: [InboxItem] = []
    var unreadable: [String] = []
    for file in files where file.pathExtension == "json" {
      if let data = try? Data(contentsOf: file), let item = try? JSONDecoder().decode(InboxItem.self, from: data) {
        items.append(item)
      } else {
        unreadable.append(file.lastPathComponent)
      }
    }
    return (items.sorted { ($0.sharedAt, $0.id) > ($1.sharedAt, $1.id) }, unreadable.sorted())
  }

  /// What still goes to Larry, oldest first.
  public func waiting() -> [InboxItem] { items().items.filter { $0.status == .waiting }.reversed() }

  public var waitingCount: Int { items().items.filter { $0.status == .waiting }.count }

  /// One item as it is on disk now, nil once deleted.
  public func item(_ id: String) -> InboxItem? {
    (try? Data(contentsOf: file(id))).flatMap { try? JSONDecoder().decode(InboxItem.self, from: $0) }
  }

  public func image(of item: InboxItem) -> Data? {
    item.imageFile.flatMap { try? Data(contentsOf: directory.appendingPathComponent($0)) }
  }

  /// A document's bytes beside the item (#633), nil without them.
  public func file(of item: InboxItem) -> Data? {
    item.attachedFile.flatMap { try? Data(contentsOf: directory.appendingPathComponent($0)) }
  }

  /// A board's strokes beside the item (story 424), nil without them.
  public func strokes(of item: InboxItem) -> Data? {
    item.strokesFile.flatMap { try? Data(contentsOf: directory.appendingPathComponent($0)) }
  }

  /// The image's or document's size on disk, without reading it.
  public func imageBytes(of item: InboxItem) -> Int? {
    (item.imageFile ?? item.attachedFile).flatMap {
      (try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent($0).path))?[.size] as? Int
    }
  }

  public func markSent(_ id: String, at: Int64, thread: String? = nil) throws {
    try update(id) { $0.delivery = .sent(at: at, thread: thread) }
  }

  public func markRefused(_ id: String, reason: String) throws {
    try update(id) { $0.delivery = .refused(reason) }
  }

  /// Story 488: a refused item is waiting again, the same message under the same id.
  public func sendAgain(_ id: String) throws {
    try update(id) { if case .refused = $0.delivery { $0.delivery = .waiting } }
  }

  /// #809: sent chat messages seven days old leave the phone, their thread opened or not. Returns how many went.
  @discardableResult
  public func dropOldSent(now: Int64) throws -> Int {
    let due = items().items.filter { $0.isDueToDrop(now: now) }
    for item in due { try delete(item) }
    return due.count
  }

  public func delete(_ item: InboxItem) throws {
    for beside in [item.imageFile, item.strokesFile, item.attachedFile].compactMap({ $0 }) {
      try? FileManager.default.removeItem(at: directory.appendingPathComponent(beside))
    }
    try FileManager.default.removeItem(at: file(item.id))
  }

  private func update(_ id: String, _ change: (inout InboxItem) -> Void) throws {
    var item = try JSONDecoder().decode(InboxItem.self, from: Data(contentsOf: file(id)))
    change(&item)
    try write(item)
  }

  private func write(_ item: InboxItem) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(item).write(to: file(item.id), options: .atomic)
  }

  private func file(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }
}
