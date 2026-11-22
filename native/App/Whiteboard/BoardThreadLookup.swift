//
//  BoardThreadLookup.swift
//  #1163, stories 1097, 949: the board's chat thread from a device that never sent it, for the boards list's chat
//  bubble and the note's tap on an iPhone. The rules are `BoardThreadFind`'s; this reads the Cockpit and logs.
//

import BugKit
import ContextCore
import Foundation

@MainActor
enum BoardThreadLookup {
  enum Answer {
    case thread(String)
    /// No thread is the board's, or the Cockpit couldn't be read: copyable, filing no report.
    case problem(BugProblem)
    /// A look for this board is already out.
    case busy
  }

  /// Threads found among the chats this launch, board id to thread. Kept apart from the board's own record
  /// (`WhiteboardThreads`), which a board sent from this device watches for Larry's marks.
  private static var found: [String: String] = [:]
  private static var looking: Set<String> = []

  static func find(board: String, title: String, cockpit: String, log: SessionLog, from: String) async -> Answer {
    if let key = WhiteboardThreads().thread(board: board) {
      return answered(
        .thread(key), board: board, from: from, log: log, fields: ["source": BoardThreadFind.Source.device.rawValue])
    }
    if let key = found[board] {
      return answered(
        .thread(key), board: board, from: from, log: log, fields: ["source": BoardThreadFind.Source.remembered.rawValue]
      )
    }
    guard !looking.contains(board) else { return .busy }
    looking.insert(board)
    defer { looking.remove(board) }
    let started = Date()
    let context = from == "list" ? "Boards list · Open in Chat" : "Board note · Open in Chat"
    var extra: [String: JSONValue] = ["board": .string(board), "title": .string(title), "cockpit": .string(cockpit)]
    func ms() -> Int { Int(Date().timeIntervalSince(started) * 1000) }
    guard cockpit != ChatCockpit.nowhere else {
      let problem = BugProblem.grabber(ChatCockpit.noAddress, context: context, extra: extra, autoFile: false)
      return answered(.problem(problem), board: board, from: from, log: log, fields: ["outcome": "no_address"])
    }
    do {
      let (data, response) = try await URLSession.shared.data(for: try ChatWire.listRequest(cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let threads = ChatWire.summaries(data) else {
        extra["status"] = .int(status)
        let problem = BugProblem.grabber(
          "Could not read the chats from the Cockpit: HTTP \(status)", context: context, extra: extra, autoFile: false)
        return answered(
          .problem(problem), board: board, from: from, log: log,
          fields: ["outcome": "list_failed", "status": status, "ms": ms()])
      }
      let candidates = BoardThreadFind.candidates(title: title, threads: threads)
      var checked = 0
      for key in candidates {
        let (data, response) = try await URLSession.shared.data(for: try ChatWire.threadRequest(key, cockpit: cockpit))
        checked += 1
        guard (response as? HTTPURLResponse)?.statusCode == 200, let messages = ChatWire.messages(data) else {
          continue
        }
        if BoardThreadFind.belongs(board: board, messages: messages) {
          found[board] = key
          return answered(
            .thread(key), board: board, from: from, log: log,
            fields: [
              "source": BoardThreadFind.Source.chats.rawValue, "threads": threads.count,
              "candidates": candidates.count, "checked": checked, "ms": ms(),
            ])
        }
      }
      extra["threads"] = .int(threads.count)
      extra["candidates"] = .array(candidates.map(JSONValue.string))
      let problem = BugProblem.grabber(BoardThreadFind.noneMessage, context: context, extra: extra, autoFile: false)
      return answered(
        .problem(problem), board: board, from: from, log: log,
        fields: [
          "outcome": "none", "threads": threads.count, "candidates": candidates.count, "checked": checked, "ms": ms(),
        ])
    } catch {
      extra["reason"] = .string(error.localizedDescription)
      let message = CockpitReach.problem(error, otherwise: "Could not read the chats from the Cockpit")
      let problem = BugProblem.grabber(message, context: context, extra: extra, autoFile: false)
      return answered(
        .problem(problem), board: board, from: from, log: log,
        fields: ["outcome": "failed", "reason": error.localizedDescription, "ms": ms()])
    }

  }

  /// Every answer is logged: which board, from where, and how it was found or why not.
  private static func answered(
    _ answer: Answer, board: String, from: String, log: SessionLog, fields: [String: Any]
  ) -> Answer {
    var line = fields.merging(["action": "chat_lookup", "board": board, "from": from]) { _, new in new }
    if case .thread(let key) = answer { line["thread"] = key }
    log.event("whiteboard", line)
    return answer
  }
}
