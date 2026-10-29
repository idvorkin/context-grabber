//  #305 phase 2, story 039: an Inbox item to Larry on the Cockpit — since chat (spec 2026-10-25) as a chat message,
//  `ChatSend`. Reaching the tailnet host is the permission; the Cockpit wants its own https Origin from a native app,
//  since no token is set up. Each item goes once: a resend is recognised by its id. This file keeps the image rules
//  and the sender.

import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum InboxSend {
  /// The Cockpit's cap on a decoded image.
  public static let maxImageBytes = 10 * 1024 * 1024

  /// PNG, JPEG, GIF and WebP go as they are; anything else (HEIC) becomes a JPEG, made smaller until it fits the
  /// Cockpit's 10 MB. Nil when the bytes are not an image ImageIO can read.
  public static func sendable(_ image: Data, maxBytes: Int = maxImageBytes) -> Data? {
    guard let source = CGImageSourceCreateWithData(image as CFData, nil) else { return nil }
    let type = CGImageSourceGetType(source).map { $0 as String }
    let kept: Set<String> = [UTType.png, .jpeg, .gif, .webP].map(\.identifier).reduce(into: []) { $0.insert($1) }
    if let type, kept.contains(type), image.count <= maxBytes { return image }
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let long = max(props?[kCGImagePropertyPixelWidth] as? Int ?? 4096, props?[kCGImagePropertyPixelHeight] as? Int ?? 0)
    // The whole picture first (up to 4096 on its long side), then three quarters each time, down to 512.
    let first = min(long, 4096)
    let sides = sequence(first: first) { $0 * 3 / 4 }.prefix { $0 == first || $0 >= 512 }
    for side in sides {
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: side,
        kCGImageSourceCreateThumbnailWithTransform: true,
      ]
      guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
      let out = NSMutableData()
      guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
        return nil
      }
      CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
      guard CGImageDestinationFinalize(dest) else { return nil }
      if out.length <= maxBytes { return out as Data }
    }
    return nil
  }

  /// A small picture for a preview, decoded at most `maxPixels` on its long side: a full-size photo decoded whole
  /// would take hundreds of MB, past the share extension's memory (local review).
  public static func thumbnail(_ image: Data, maxPixels: Int = 600) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(image as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maxPixels,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  static func mime(of image: Data) -> String {
    guard let source = CGImageSourceCreateWithData(image as CFData, nil),
      let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) })
    else { return "application/octet-stream" }
    return type.preferredMIMEType ?? "application/octet-stream"
  }

  static func origin(of url: URL) -> String { CockpitPage.origin(of: url) }

  static func iso(_ ms: Int64) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.string(from: Date(timeIntervalSince1970: Double(ms) / 1000))
  }
}

/// Sends what waits, oldest first, and records each answer. Stops at the first retry: the Cockpit is unreachable, so
/// the rest would fail the same way.
public struct InboxSender: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  let store: InboxStore
  let cockpit: String
  let transport: Transport

  public init(store: InboxStore, cockpit: String, transport: @escaping Transport) {
    self.store = store
    self.cockpit = cockpit
    self.transport = transport
  }

  public struct Report: Equatable, Sendable {
    public var sent: [String] = []
    public var refused: [String] = []
    public var retry: String?
    /// #565: the retry was the Cockpit not answering (a timeout, no connection), not an error it answered with.
    public var unreachable = false
  }

  /// `log` gets one line per item: the event's fields, never the content. Chat (spec 2026-10-25): an item is a
  /// chat message — its image uploaded first, then posted to its thread or as a new one.
  public func sendWaiting(now: @Sendable () -> Date = Date.init, log: (String, [String: Any]) -> Void) async
    -> Report
  {
    var report = Report()
    // A simulator fixture never reaches Larry, whichever launch finds it.
    for queued in store.waiting() where !queued.isFixture {
      // Read again just before sending: one deleted while an earlier request was out never goes (local review).
      guard let item = store.item(queued.id), item.status == .waiting else { continue }
      var fields: [String: Any] = ["item": item.id, "kind": item.kind.rawValue, "new_thread": item.thread == nil]
      if let thread = item.thread { fields["thread"] = thread }
      let outcome = await send(item, fields: &fields)
      record(item, outcome, now: now, fields: &fields, report: &report, log: log)
      if case .retry = outcome { break }
    }
    return report
  }

  private func send(_ item: InboxItem, fields: inout [String: Any]) async -> ChatSend.Outcome {
    var attachment: String?
    if item.kind == .image {
      guard let raw = store.image(of: item), let ready = InboxSend.sendable(raw) else {
        return .refused(status: 0, reason: "The image could not be read or made small enough to send.")
      }
      fields["bytes"] = ready.count
      let upload: ChatSend.Upload
      do {
        let (data, response) = try await transport(try ChatSend.uploadRequest(image: ready, cockpit: cockpit))
        upload = ChatSend.upload(status: (response as? HTTPURLResponse)?.statusCode, body: data)
      } catch {
        if CockpitReach.isAway(error) { fields["unreachable"] = true }
        upload = ChatSend.upload(status: nil, body: nil, error: error.localizedDescription)
      }
      switch upload {
      case .ref(let ref): attachment = ref
      case .refused(let status, let reason): return .refused(status: status, reason: reason)
      case .retry(let reason): return .retry(reason: "image upload: \(reason)")
      }
    }
    do {
      let request = try ChatSend.messageRequest(item, attachment: attachment, cockpit: cockpit)
      let (data, response) = try await transport(request)
      return ChatSend.outcome(status: (response as? HTTPURLResponse)?.statusCode, body: data)
    } catch {
      if CockpitReach.isAway(error) { fields["unreachable"] = true }
      return ChatSend.outcome(status: nil, body: nil, error: error.localizedDescription)
    }
  }

  private func record(
    _ item: InboxItem, _ outcome: ChatSend.Outcome, now: () -> Date, fields: inout [String: Any],
    report: inout Report, log: (String, [String: Any]) -> Void
  ) {
    do {
      switch outcome {
      case .sent(let thread, let duplicate):
        try store.markSent(item.id, at: Int64(now().timeIntervalSince1970 * 1000), thread: thread)
        fields.merge(["action": "sent", "duplicate": duplicate, "thread": thread]) { $1 }
        report.sent.append(item.id)
      case .refused(let status, let reason):
        try store.markRefused(item.id, reason: reason)
        fields.merge(["action": "refused", "status": status, "reason": reason]) { $1 }
        report.refused.append(item.id)
      case .retry(let reason):
        fields.merge(["action": "failed", "reason": reason]) { $1 }
        report.retry = reason
        report.unreachable = fields["unreachable"] as? Bool == true
      }
    } catch {
      fields.merge(["action": "failed", "reason": "could not record the answer: \(error)"]) { $1 }
    }
    log("chat", fields)
  }
}
