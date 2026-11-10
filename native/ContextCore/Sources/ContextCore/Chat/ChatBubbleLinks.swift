//  Links in a bubble as chips (spec 2026-10-25-native-chat-design.md, Links in a thread: Links in a bubble are chips;
//  story 743). A message's words are laid out with each link the strip would collect standing in them as a chip, the
//  same chip as the strip's: a pull request reads *PR*, a link to Igor's blog or its tailnet preview *Preview*, any
//  other its chip's words. Punctuation written against a link stays beside its chip.

import Foundation

public enum ChatBubbleLinks {
  /// The blog's preview servers on the tailnet listen on these ports (Jekyll on the Cockpit's host).
  static let previewPorts = 8400...8499

  /// One piece of a paragraph that holds a chip: a word, or a chip with what is written against it on either side.
  public enum Token: Equatable, Sendable {
    case word(String)
    case chip(ChatLink, leading: String, trailing: String)
  }

  /// One line of the message as written: as plain words when no link in it is a chip, else words and chips.
  public enum Paragraph: Equatable, Sendable {
    case plain(String)
    case flow([Token])
  }

  /// `text` as paragraphs (split at its line breaks), its links as chips.
  public static func paragraphs(in text: String) -> [Paragraph] {
    guard let finder = ChatLinks.Finder() else { return [.plain(text)] }
    let links = ChatLinks.located(in: text, finder)
    guard !links.isEmpty else { return [.plain(text)] }
    // The message as runs of words and links, broken into lines (a link never holds a line break).
    var lines: [[Run]] = [[]]
    var cursor = text.startIndex
    func addWords(_ words: Substring) {
      let parts = words.split(separator: "\n", omittingEmptySubsequences: false)
      for (index, part) in parts.enumerated() {
        if index > 0 { lines.append([]) }
        if !part.isEmpty { lines[lines.count - 1].append(.words(String(part))) }
      }
    }
    for (range, link) in links where range.lowerBound >= cursor {
      addWords(text[cursor..<range.lowerBound])
      lines[lines.count - 1].append(.link(inBubble(link)))
      cursor = range.upperBound
    }
    addWords(text[cursor...])
    return lines.map(paragraph)
  }

  private enum Run {
    case words(String)
    case link(ChatLink)
  }

  /// A line with no chip stays as written; otherwise its words split at spaces, the ones touching a chip kept on it.
  private static func paragraph(_ runs: [Run]) -> Paragraph {
    let plain = runs.compactMap { run -> String? in
      if case .words(let words) = run { return words }
      return nil
    }
    guard plain.count < runs.count else { return .plain(plain.joined()) }
    var tokens: [Token] = []
    var leading = ""
    for (index, run) in runs.enumerated() {
      switch run {
      case .link(let link):
        tokens.append(.chip(link, leading: leading, trailing: ""))
        leading = ""
      case .words(let words):
        var parts = words.split(whereSeparator: \.isWhitespace).map(String.init)
        let afterChip = index > 0 && words.first.map { !$0.isWhitespace } == true
        let beforeChip = index + 1 < runs.count && words.last.map { !$0.isWhitespace } == true
        if afterChip, !parts.isEmpty, case .chip(let link, leading: let before, trailing: _)? = tokens.last {
          tokens[tokens.count - 1] = .chip(link, leading: before, trailing: parts.removeFirst())
        }
        if beforeChip, !parts.isEmpty { leading = parts.removeLast() }
        tokens += parts.map(Token.word)
      }
    }
    return .flow(tokens)
  }

  /// The chip a link is in a bubble: the strip's, but a pull request reads *PR* and the blog *Preview*.
  static func inBubble(_ link: ChatLink) -> ChatLink {
    let label: String
    if case .pullRequest = link.kind {
      label = "PR"
    } else if isPreview(link) {
      label = "Preview"
    } else {
      return link
    }
    return ChatLink(url: link.url, kind: link.kind, label: label, id: link.id, state: link.state)
  }

  /// Igor's blog, on its site or a preview of it on the tailnet.
  static func isPreview(_ link: ChatLink) -> Bool {
    guard link.kind == .web, let raw = link.url.host?.lowercased() else { return false }
    let host = raw.hasPrefix("www.") ? String(raw.dropFirst(4)) : raw
    if host == "idvork.in" || host == "idvorkin.github.io" { return true }
    return host == CockpitPage.host && link.url.port.map { previewPorts.contains($0) } ?? false
  }
}
