//
//  BoardThreadFind.swift
//  #1163, stories 1097, 949: the chat thread of a board this device never sent. Only the device that sent a board's
//  picture records its thread, so an iPhone looks among Larry's chats: those titled with the board's name, and opens
//  one only when a message on it came from this very board.
//

import Foundation

public enum BoardThreadFind {
  /// The most threads read to confirm one: each is a request to the Cockpit.
  public static let mostChecked = 5

  /// What the list and the note say when no thread is the board's.
  public static let noneMessage = "No chat with Larry for this board yet"

  /// Where the thread came from, for the log.
  public enum Source: String, Sendable {
    /// This device sent the board and recorded its thread.
    case device
    /// Found among the chats earlier this launch.
    case remembered
    /// Found among the chats now.
    case chats
  }

  /// Threads that may be the board's, to read in order: titled with its name first, then those whose title holds it
  /// (a thread renamed around it), newest first in each, at most `mostChecked`.
  public static func candidates(title: String, threads: [ChatSummary]) -> [String] {
    let name = folded(title)
    guard !name.isEmpty else { return [] }
    let newestFirst = threads.sorted { ($0.lastAt ?? .distantPast) > ($1.lastAt ?? .distantPast) }
    let same = newestFirst.filter { folded($0.title) == name }
    let holding = newestFirst.filter { folded($0.title) != name && folded($0.title).contains(name) }
    return Array((same + holding).prefix(mostChecked).map(\.key))
  }

  /// The thread is the board's: one of its messages was sent from it. A name alone never is.
  public static func belongs(board: String, messages: [ChatMessage]) -> Bool {
    !board.isEmpty && messages.contains { $0.board == board }
  }

  private static func folded(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
