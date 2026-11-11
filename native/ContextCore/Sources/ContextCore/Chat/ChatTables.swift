//  A table in a message (spec 2026-10-25-native-chat-design.md, A table in a message; story 747, #817). A Markdown
//  table — a row of cells between pipes, a row of dashes under it, then its rows — becomes a grid in the bubble; the
//  words around it stay text.

import Foundation

public enum ChatTables {
  public enum Alignment: Equatable, Sendable { case leading, center, trailing }

  public struct Table: Equatable, Sendable {
    public let heading: [String]
    public let alignments: [Alignment]
    /// Each as many cells as the heading: a short row filled with empty cells, a long one cut.
    public let rows: [[String]]
  }

  /// A message's pieces in order: words as written, or a table.
  public enum Block: Equatable, Sendable {
    case text(String)
    case table(Table)
  }

  public static func blocks(in text: String) -> [Block] {
    let lines = text.components(separatedBy: "\n")
    var blocks: [Block] = []
    var words: [String] = []
    func endWords() {
      if !words.isEmpty { blocks.append(.text(words.joined(separator: "\n"))) }
      words = []
    }
    var index = 0
    while index < lines.count {
      if index + 1 < lines.count, let heading = cells(lines[index]),
        let alignments = dashes(lines[index + 1], count: heading.count)
      {
        var rows: [[String]] = []
        var next = index + 2
        while next < lines.count, let row = cells(lines[next]) {
          rows.append(Array((row + Array(repeating: "", count: heading.count)).prefix(heading.count)))
          next += 1
        }
        endWords()
        blocks.append(.table(Table(heading: heading, alignments: alignments, rows: rows)))
        index = next
      } else {
        words.append(lines[index])
        index += 1
      }
    }
    endWords()
    return blocks
  }

  /// A line's cells when it holds a pipe outside its ends: `| a | b |`, `a | b`. A `\|` is a pipe inside a cell.
  static func cells(_ line: String) -> [String]? {
    var body = line.trimmingCharacters(in: .whitespaces)
    guard body.contains("|") else { return nil }
    if body.hasPrefix("|") { body.removeFirst() }
    if body.hasSuffix("|") && !body.hasSuffix("\\|") { body.removeLast() }
    var cells: [String] = []
    var cell = ""
    var escaped = false
    for character in body {
      if escaped {
        cell.append(character == "|" ? "|" : "\\\(character)")
        escaped = false
      } else if character == "\\" {
        escaped = true
      } else if character == "|" {
        cells.append(cell)
        cell = ""
      } else {
        cell.append(character)
      }
    }
    if escaped { cell.append("\\") }
    cells.append(cell)
    let trimmed = cells.map { $0.trimmingCharacters(in: .whitespaces) }
    // A lone pipe with nothing around it is words, not a table.
    return trimmed.count >= 1 && trimmed.contains { !$0.isEmpty } ? trimmed : nil
  }

  /// The dashes row under a heading of `count` cells: each cell dashes, with a colon at either end for its alignment.
  static func dashes(_ line: String, count: Int) -> [Alignment]? {
    guard let cells = cellsOfDashes(line), cells.count == count else { return nil }
    var alignments: [Alignment] = []
    for cell in cells {
      let left = cell.hasPrefix(":")
      let right = cell.hasSuffix(":")
      let core = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
      guard !core.isEmpty, core.allSatisfy({ $0 == "-" }) else { return nil }
      alignments.append(left && right ? .center : right ? .trailing : .leading)
    }
    return alignments
  }

  private static func cellsOfDashes(_ line: String) -> [String]? {
    var body = line.trimmingCharacters(in: .whitespaces)
    // A dashes row with no pipe is a rule under a line, not a table.
    guard body.contains("-"), body.contains("|") else { return nil }
    if body.hasPrefix("|") { body.removeFirst() }
    if body.hasSuffix("|") { body.removeLast() }
    return body.split(separator: "|", omittingEmptySubsequences: false).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
  }
}
