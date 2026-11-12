//  The board's note: one line that opens into the conversation (spec 2026-11-12-whiteboard-conversation-design.md, *One
//  line that opens*, story 766; #879: "some kind of collapse expand conversation"). Closed, the line is Larry's state
//  first, then the newest thing said, then how many suggestions show; open, a panel over the top of the board holds the
//  recent end of the board's thread and what is live. The board's model hands in the turn, the clock, what was said, the
//  thread it already reads every few seconds and the note's other messages; the view draws what comes back.

import Foundation

/// What was said last on a board, and by whom: Larry's newest line, or what the mic last heard.
public struct WhiteboardSaid: Equatable, Sendable {
  public private(set) var larry: String?
  public private(set) var you: String?
  /// Igor spoke, or opened the mic, after Larry's last line.
  public private(set) var youLast = false

  public init() {}

  /// Larry's newest row: its words, or marks with none, which take his line away (as the note always did).
  public mutating func larrySaid(_ words: String?, marks: Bool) {
    if let words {
      larry = words
      youLast = false
    } else if marks {
      larry = nil
    }
  }

  /// The mic opened: nothing heard yet.
  public mutating func micOpened() {
    you = nil
    youLast = true
  }

  /// What the mic has heard so far, in full.
  public mutating func heard(_ words: String) {
    you = words
    youLast = true
  }
}

public enum WhiteboardNote {
  /// How long one of the note's other messages takes the middle before giving it back to what was said.
  public static let noticeFor: Duration = .seconds(5)

  /// One of the note's other messages (a paste cut short, *Sent to Larry*, a look-only reason, a Cockpit not
  /// answering), and when it appeared.
  public struct Notice: Equatable, Sendable {
    public let text: String
    public let since: ContinuousClock.Instant

    public init(text: String, since: ContinuousClock.Instant) {
      self.text = text
      self.since = since
    }
  }

  /// The closed note: one line.
  public struct Line: Equatable, Sendable {
    /// Larry's state while a turn is out: his clock and what waits to go next.
    public var state: String?
    /// The state in words, for VoiceOver.
    public var spokenState: String?
    /// The newest thing said, or one of the note's other messages.
    public var middle: String?
    /// A middle too long for the line keeps its end (Igor's words: the newest are the ones he is checking), else its
    /// start (Larry's line).
    public var keepsEnd = false
    /// How many suggestions show: *3 to keep*.
    public var keep: String?
  }

  /// The line, or nil with nothing to say.
  public static func line(
    larry: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool, said: WhiteboardSaid,
    micOn: Bool, notice: Notice?, ghosts: Int
  ) -> Line? {
    var line = Line()
    if let clock = WhiteboardLarryClock.state(larry, now: now, cockpitAnswering: cockpitAnswering),
      let spoken = WhiteboardLarryClock.spoken(larry, now: now, cockpitAnswering: cockpitAnswering)
    {
      let next = waiting(larry)
      line.state = next.map { "\(clock) · next: \($0)" } ?? clock
      line.spokenState =
        next.map { "\(spoken), next: \($0.replacingOccurrences(of: " + ", with: " and "))" } ?? spoken
    }
    let words = middle(said, micOn: micOn)
    if let notice, now - notice.since < noticeFor || words == nil {
      line.middle = notice.text
    } else if let words {
      line.middle = words.text
      line.keepsEnd = words.keepsEnd
    }
    line.keep = ghosts == 0 ? nil : "\(ghosts) to keep"
    return line == Line() ? nil : line
  }

  /// The note's other messages, in one: nil when there are none. `turnNote` counts only when it isn't Larry's line,
  /// which is said, not a notice; `marksAway` only with no turn out, as his state says it while he is looking.
  public static func notice(
    paste: String?, sent: String?, turnNote: String?, marksAway: Bool, looking: Bool, lookOnly: String?
  ) -> String? {
    let ours = [WhiteboardTurn.ghostsAway, WhiteboardTurn.micGhostsOff]
    let parts = [
      turnNote.flatMap { ours.contains($0) ? $0 : nil },
      paste,
      // While he is looking his state says it (story 760).
      marksAway && !looking ? "Larry's marks: the Cockpit isn't answering" : nil,
      sent ?? lookOnly,
    ].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// Whether the line changes with the clock alone: a turn out ticks, and a notice gives the middle back.
  public static func ticks(larry: WhiteboardLarryTurn, notice: Notice?) -> Bool { larry.looking || notice != nil }

  /// What a tap on the line does.
  public enum Tap: Equatable, Sendable {
    /// Opens or closes the panel.
    case toggle
    /// On an iPhone, which has no panel: the board's thread in Chat.
    case openChat(String)
    /// On an iPhone, a board with no thread yet.
    case nothing
  }

  public static func tap(onPhone: Bool, thread: String?) -> Tap {
    guard onPhone else { return .toggle }
    return thread.map { .openChat($0) } ?? .nothing
  }

  // MARK: Open: the conversation

  /// One row of the open panel.
  public struct Row: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
      case larry, you
      /// What is live now: the turn that's out, what waits to go next, what the mic is hearing.
      case live
    }

    public let id: String
    public let kind: Kind
    public let who: String
    public let text: String
    /// The Cockpit's mark on a picture of Igor's: received, seen or done.
    public let mark: String?

    public init(id: String, kind: Kind, who: String, text: String, mark: String?) {
      self.id = id
      self.kind = kind
      self.who = who
      self.text = text
      self.mark = mark
    }
  }

  /// The most messages of the thread the panel holds; *Open in Chat* has the rest.
  public static let panelMessages = 10

  /// The panel: the recent end of the board's thread (`thread`, oldest first, as the Cockpit sends it), newest at the
  /// bottom, then what is live.
  public static func panel(
    thread: [ChatMessage], larry: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool,
    said: WhiteboardSaid, micOn: Bool
  ) -> [Row] {
    var rows = thread.suffix(panelMessages).map { message in
      message.fromIgor
        ? Row(
          id: message.id, kind: .you, who: "You",
          text: message.text.isEmpty ? (message.attachments.isEmpty ? "…" : "a picture") : message.text,
          mark: message.receipt == .sent ? nil : message.receipt.rawValue)
        : Row(
          id: message.id, kind: .larry, who: message.author ?? "Larry",
          text: message.text.isEmpty ? "drew on the board" : message.text, mark: nil)
    }
    if let clock = WhiteboardLarryClock.state(larry, now: now, cockpitAnswering: cockpitAnswering) {
      rows.append(Row(id: "live-turn", kind: .live, who: "Now", text: clock, mark: nil))
    }
    if let next = waiting(larry) {
      let text = larry.queued.map { "\(next): \($0)" } ?? next
      rows.append(Row(id: "live-next", kind: .live, who: "Next", text: text, mark: nil))
    }
    if micOn {
      rows.append(Row(id: "live-mic", kind: .live, who: "Hearing", text: said.you ?? "Listening…", mark: nil))
    }
    return rows
  }

  // MARK: Pieces

  /// What goes when he answers: *ink*, *words* or *ink + words*; nil with nothing waiting or no turn out.
  static func waiting(_ larry: WhiteboardLarryTurn) -> String? {
    switch (larry.inkWaiting, larry.wordsWaiting) {
    case (true, true): return "ink + words"
    case (true, false): return "ink"
    case (false, true): return "words"
    case (false, false): return nil
    }
  }

  /// The newest thing said, by whoever said it last.
  private static func middle(_ said: WhiteboardSaid, micOn: Bool) -> (text: String, keepsEnd: Bool)? {
    let larry = said.larry.map { (text: "Larry: \($0)", keepsEnd: false) }
    guard said.youLast else { return larry ?? said.you.map { ("You: \($0)", true) } }
    if let you = said.you { return ("You: \(you)", true) }
    return micOn ? ("Listening…", false) : larry
  }
}
