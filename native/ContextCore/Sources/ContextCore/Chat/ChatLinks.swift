//  Links in a chat thread (#736; spec 2026-10-25-native-chat-design.md, Links in a thread): every pull request, gist
//  and web link a thread's messages hold, as chips — labelled, one per page, newest first.

import Foundation

public struct ChatLink: Equatable, Sendable, Identifiable {
  public enum Kind: Equatable, Sendable {
    case pullRequest(repo: String, number: Int)
    case gist
    case web
    /// A thread on the Cockpit, an Inbox question being one (story 744): its Cockpit link or `larry://inbox/<key>`.
    case inbox(thread: String)

    /// The session log's name for it; never the link itself.
    public var logName: String {
      switch self {
      case .pullRequest: return "pr"
      case .gist: return "gist"
      case .web: return "web"
      case .inbox: return "inbox"
      }
    }
  }

  /// A pull request's state, as the Cockpit tells it (option C, `ChatPRStates`); the raw value is the chip's word.
  public enum PullRequestState: String, Equatable, Sendable { case open, draft, merged, closed }

  /// The link as written, its trailing punctuation dropped.
  public let url: URL
  public let kind: Kind
  /// What the chip reads.
  public let label: String
  /// Two links to the same page share it.
  public let id: String
  /// A PR chip's state once the Cockpit has reported it (`ChatPRStates.applied`); nil reads as the number alone.
  public var state: PullRequestState?

  public init(url: URL, kind: Kind, label: String, id: String, state: PullRequestState? = nil) {
    self.url = url
    self.kind = kind
    self.label = label
    self.id = id
    self.state = state
  }
}

public enum ChatLinks {
  /// The strip's chips before *All links*.
  public static let stripLimit = 10
  /// A wide list row's chips.
  public static let rowLimit = 3
  /// A web chip's path part, before it is cut short.
  static let pathLimit = 24

  /// Every link written out with `http://` or `https://`, in the order written, repeats kept.
  public static func found(in text: String) -> [ChatLink] {
    guard let finder = Finder() else { return [] }
    return found(in: text, finder)
  }

  private static func found(in text: String, _ finder: Finder) -> [ChatLink] {
    located(in: text, finder).map(\.link)
  }

  /// Each link with where it is written in `text`, its sentence punctuation left outside (`trimmed`).
  static func located(in text: String, _ finder: Finder) -> [(range: Range<String.Index>, link: ChatLink)] {
    finder.ranges(in: text).compactMap { match in
      let written = trimmed(String(text[match]))
      let lower = written.lowercased()
      guard lower.hasPrefix("https://") || lower.hasPrefix("http://") || lower.hasPrefix(ChatCockpitLink.prefix),
        let url = URL(string: written),
        let host = url.host?.lowercased(), !host.isEmpty
      else { return nil }
      let end = text.index(match.lowerBound, offsetBy: written.count)
      return (range: match.lowerBound..<end, link: link(url, host: host))
    }
  }

  /// A thread's links, newest message first, one per page (the newest one written).
  public static func inThread(_ messages: [ChatMessage]) -> [ChatLink] {
    guard let finder = Finder() else { return [] }
    var seen = Set<String>()
    var out: [ChatLink] = []
    for message in messages.reversed() where !message.isError {
      for link in found(in: message.text, finder) where seen.insert(link.id).inserted {
        out.append(link)
      }
    }
    return out
  }

  #if canImport(Darwin)
    /// What NSDataDetector calls a link, as written.
    struct Finder {
      let detector: NSDataDetector

      init?() {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
          return nil
        }
        self.detector = detector
      }

      /// The detector's links, and each `larry://` link, which it does not know (story 744).
      func ranges(in text: String) -> [Range<String.Index>] {
        let all = NSRange(location: 0, length: (text as NSString).length)
        let larry = ChatLinks.schemeRanges(in: text, [ChatCockpitLink.prefix])
        let found = detector.matches(in: text, range: all).compactMap { Range($0.range, in: text) }
          .filter { match in !larry.contains { $0.overlaps(match) } }
        return (found + larry).sorted { $0.lowerBound < $1.lowerBound }
      }
    }
  #else
    /// Linux (just test-linux): NSDataDetector is Darwin Foundation only, so a stand-in finds each `http://` or
    /// `https://` that starts a word and runs to the next space or angle bracket; `trimmed` then drops what ends the
    /// sentence, as it does for the detector. The same tests run on both, but only the Mac's say the app is right.
    /// ponytail: a link the detector finds without a scheme never counts anyway; a link with a space in it would need
    /// the detector's own rules.
    struct Finder {
      init?() {}

      func ranges(in text: String) -> [Range<String.Index>] {
        ChatLinks.schemeRanges(in: text, ["https://", "http://", ChatCockpitLink.prefix])
      }
    }
  #endif

  /// Each link starting with one of `prefixes` (in any case) at the start of a word, running to the next space, angle
  /// bracket or double quote: the Linux stand-in for the detector, and on both how `larry://` links are found.
  static func schemeRanges(in text: String, _ prefixes: [String]) -> [Range<String.Index>] {
    var out: [Range<String.Index>] = []
    let chars = Array(text)
    var i = 0
    while i < chars.count {
      let startsWord = i == 0 || !(chars[i - 1].isLetter || chars[i - 1].isNumber)
      let scheme = prefixes.first { prefix in
        i + prefix.count <= chars.count && String(chars[i..<(i + prefix.count)]).lowercased() == prefix
      }
      if startsWord, let scheme {
        var end = i + scheme.count
        while end < chars.count, !chars[end].isWhitespace, !"<>\"".contains(chars[end]) { end += 1 }
        if end > i + scheme.count {
          let lower = text.index(text.startIndex, offsetBy: i)
          out.append(lower..<text.index(lower, offsetBy: end - i))
        }
        i = end
      } else {
        i += 1
      }
    }
    return out
  }

  /// The strip's chips, and what *All links* adds past them.
  public static func strip(_ links: [ChatLink]) -> (shown: [ChatLink], more: Int) {
    (Array(links.prefix(stripLimit)), max(0, links.count - stripLimit))
  }

  /// Ends a sentence or wraps the link, so it is not part of it: a full stop, quotes, backticks, a bold mark's stars,
  /// a closing bracket with no opening one.
  public static func trimmed(_ written: String) -> String {
    var s = Substring(written)
    while let last = s.last {
      if ".,;:!?'\"`*~>".contains(last) {
        s = s.dropLast()
      } else if last == ")" && s.filter({ $0 == "(" }).count < s.filter({ $0 == ")" }).count {
        s = s.dropLast()
      } else if last == "]" && s.filter({ $0 == "[" }).count < s.filter({ $0 == "]" }).count {
        s = s.dropLast()
      } else {
        break
      }
    }
    return String(s)
  }

  private static func link(_ url: URL, host rawHost: String) -> ChatLink {
    if let key = ChatCockpitLink.threadKey(url) {
      return ChatLink(url: url, kind: .inbox(thread: key), label: "Inbox", id: "inbox:\(key)")
    }
    let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
    let parts = url.path.split(separator: "/").map(String.init)
    if host == "github.com", parts.count >= 4, parts[2] == "pull", let number = Int(parts[3]) {
      let repo = "\(parts[0])/\(parts[1])".lowercased()
      return ChatLink(
        url: url, kind: .pullRequest(repo: repo, number: number), label: "PR #\(number)", id: "pr:\(repo)#\(number)")
    }
    let page = host + (parts.isEmpty ? "" : "/" + parts.joined(separator: "/")) + (url.query.map { "?" + $0 } ?? "")
    if host == "gist.github.com" { return ChatLink(url: url, kind: .gist, label: "gist", id: page) }
    return ChatLink(url: url, kind: .web, label: webLabel(host: host, parts: parts), id: page)
  }

  /// The site and the last part of the path, with the part before it when the last is only a number.
  /// The Cockpit's long tailnet host reads *Larry* (story 744): *Larry*, *Larry: ai-journal*.
  private static func webLabel(host: String, parts: [String]) -> String {
    let cockpit = host == CockpitPage.host
    guard let last = parts.last else { return cockpit ? "Larry" : host }
    var path = last
    if parts.count > 1, last.allSatisfy(\.isNumber) { path = parts[parts.count - 2] + "/" + last }
    path = path.removingPercentEncoding ?? path
    if path.count > pathLimit { path = String(path.prefix(pathLimit - 1)) + "…" }
    return cockpit ? "Larry: " + path : host + "/" + path
  }

  /// A link's address where the app spells it out (*All links*): as written, but a Cockpit thread as its short form and
  /// any other Cockpit link with *Larry* for the tailnet host, which never shows (story 744).
  public static func address(_ link: ChatLink) -> String {
    if case .inbox(let key) = link.kind { return ChatCockpitLink.prefix + "inbox/" + key }
    guard link.url.host?.lowercased() == CockpitPage.host else { return link.url.absoluteString }
    let port = link.url.port.map { ":\($0)" } ?? ""
    let rest = link.url.path + (link.url.query.map { "?" + $0 } ?? "") + (link.url.fragment.map { "#" + $0 } ?? "")
    return "Larry" + port + rest
  }
}
