//  The board's note: one line that opens into the conversation (spec 2026-11-12-whiteboard-conversation-design.md, *One
//  line that opens*, stories 766–769; #879: "some kind of collapse expand conversation"). Closed, the line is Larry's
//  state first, then the newest thing said, then how many suggestions show; open, a panel over the top of the board
//  holds the recent end of the board's thread and what is live. The board's model hands in the turn, the clock, what
//  was said, the thread it already reads every few seconds and the note's other messages; the view draws what comes
//  back.

#if FOUNDATION_ESSENTIALS_ONLY
  import FoundationEssentials
#else
  import Foundation
#endif

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

  /// Story 837 (#917): the least room the open panel has, about four lines of the thread and its foot.
  public static let panelFloor: Double = 120

  /// Story 837 (#917): how tall the open panel may be over a board `board` points tall: a fifth of it, never less than
  /// `panelFloor` nor more than the board. Past this its messages scroll; it doesn't grow.
  public static func panelHeight(board: Double) -> Double {
    min(max(board, 0), max(board / 5, panelFloor))
  }

  /// Bead context-grabber-97s (stories 837, 887): whether the panel's thread, scrolled to `offset` of the `end` its newest
  /// line sits at, follows the newest: a new line keeps it at the bottom only while Igor is there, within a few points.
  /// Scrolled up to read, a new line leaves him where he is.
  public static func followsNewest(offset: Double, end: Double) -> Bool {
    end - offset <= followSlack
  }

  /// How near the bottom still counts as at it: a fling that settles a few points short is at the newest.
  public static let followSlack = 8.0

  /// What VoiceOver (and a UI test) hears of the panel's thread: where it is scrolled.
  public static func panelPlace(following: Bool) -> String {
    following ? "Conversation, newest showing" : "Conversation, older messages showing"
  }

  /// The note's other messages (a paste cut short, *Sent to Larry*, a look-only reason, a Cockpit not answering), and
  /// when they appeared.
  public struct Notice: Equatable, Sendable {
    public let text: String
    /// The part of `text` about something still wrong (a Cockpit not answering): it keeps the middle until it's over.
    public let held: String?
    public let since: ContinuousClock.Instant

    public init(text: String, held: String? = nil, since: ContinuousClock.Instant) {
      self.text = text
      self.held = held
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
    /// The middle is Larry's own line, which takes the emphasis (#1003, story 1053).
    public var larrySpeaks = false
    /// Story 929: Larry is holding for more, in his words; the line starts with an ear and these.
    public var listening: String?
  }

  /// The line, or nil with nothing to say.
  public static func line(
    larry: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool,
    mark: WhiteboardLarryWait.Mark = .unknown, said: WhiteboardSaid, micOn: Bool, notice: Notice?, ghosts: Int,
    listening: String? = nil
  ) -> Line? {
    var line = Line()
    line.listening = WhiteboardLarryListening.shown(listening, turn: larry)
    if let clock = WhiteboardLarryClock.state(
      larry, now: now, cockpitAnswering: cockpitAnswering, mark: mark),
      let spoken = WhiteboardLarryClock.spoken(
        larry, now: now, cockpitAnswering: cockpitAnswering, mark: mark)
    {
      let next = waiting(larry)
      line.state = next.map { "\(clock) · next: \($0)" } ?? clock
      line.spokenState =
        next.map { "\(spoken), next: \($0.replacingOccurrences(of: " + ", with: " and "))" } ?? spoken
    }
    let words = middle(said, micOn: micOn)
    if let notice, now - notice.since < noticeFor || (words == nil && notice.held == nil) {
      line.middle = notice.text
    } else if let held = notice?.held {
      line.middle = held
    } else if let words {
      line.middle = words.text
      line.keepsEnd = words.keepsEnd
      line.larrySpeaks = words.larry
    }
    line.keep = ghosts == 0 ? nil : "\(ghosts) to keep"
    return line == Line() ? nil : line
  }

  /// The note's other messages, in one: nil when there are none. `turnNote` counts only when it isn't Larry's line,
  /// which is said, not a notice; `marksAway` only with no turn out, as his state says it while he is looking. `held`
  /// is the part that stays while it is true: the Cockpit not answering, for ghosts or for Larry's marks, or writing with
  /// the pause switch off (story 1114).
  public static func notice(
    paste: String?, sent: String?, turnNote: String?, marksAway: Bool, looking: Bool, lookOnly: String?
  ) -> (text: String, held: String?)? {
    let held = [
      turnNote == WhiteboardTurn.ghostsAway || turnNote == WhiteboardTurn.writingGhostsOff ? turnNote : nil,
      // While he is looking his state says it (story 760).
      marksAway && !looking ? "Larry's marks: the Cockpit isn't answering" : nil,
    ].compactMap { $0 }
    let passing = [turnNote == WhiteboardTurn.micGhostsOff ? turnNote : nil, paste, sent ?? lookOnly].compactMap { $0 }
    guard !held.isEmpty || !passing.isEmpty else { return nil }
    let separator = " · "
    return ((held + passing).joined(separator: separator), held.isEmpty ? nil : held.joined(separator: separator))
  }

  /// Whether the line changes with the clock alone: a turn out ticks, and a passing notice gives the middle back.
  public static func ticks(larry: WhiteboardLarryTurn, notice: Notice?) -> Bool {
    larry.looking || notice.map { $0.text != $0.held } ?? false
  }

  /// What a tap on the line does.
  public enum Tap: Equatable, Sendable {
    /// Opens or closes the panel.
    case toggle
    /// On an iPhone, which has no panel: the board's thread in Chat, this device's own or the one the board carries
    /// through iCloud (#1161).
    case openChat(String, fromICloud: Bool = false)
    /// On an iPhone, a board with no thread on this device: the note says where its conversation is (#1161).
    case nothing

    /// How the thread was found, for `conversation_chat`: `this_device` (the thread this device keeps for the
    /// board), `icloud` (the one the board's iCloud copy carries, #1161) or `none`; nil for the panel's toggle, which
    /// looks for none.
    public var found: String? {
      switch self {
      case .toggle: nil
      case .openChat(_, let fromICloud): fromICloud ? "icloud" : "this_device"
      case .nothing: "none"
      }
    }
  }

  /// `thread`: the board's one thread as this device picks it (story 1158: the carried one wins on a board another
  /// device drew); `icloud`: the one the board carries through iCloud, which names where a thread came from.
  public static func tap(onPhone: Bool, thread: String?, icloud: String? = nil) -> Tap {
    guard onPhone else { return .toggle }
    guard let thread else { return .nothing }
    return .openChat(thread, fromICloud: thread == icloud)
  }

  /// #1161 (story 769): what the note says when a tap on an iPhone finds no thread. A board's thread is known only to
  /// the device that sent its pictures, so another device's board says where its conversation is; one drawn here
  /// never went to Larry. `drawnOn`: the name of the device that drew the board, nil when this one did.
  public static func noThread(drawnOn: String?) -> String {
    drawnOn.map { "Larry's conversation is on the \($0)" } ?? "No conversation with Larry yet"
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
    /// Story 929: the chip says Larry is holding for more, and carries the ear.
    public let listening: Bool

    public init(id: String, kind: Kind, who: String, text: String, listening: Bool = false) {
      self.id = id
      self.kind = kind
      self.who = who
      self.text = text
      self.listening = listening
    }
  }

  /// The most messages of the thread the panel holds; *Open in Chat* has the rest.
  public static let panelMessages = 10

  /// What the board sends with a picture when Igor said nothing with it. Not a row of the panel (#1003): it was most of
  /// it, between Larry's sentences; the status chip says where that picture is.
  public static let boardTurnNote = "Your turn on the board"

  /// A reply of Larry's with marks and no words, in the panel.
  public static let drewOnTheBoard = "drew on the board"

  /// The panel's thread: the recent end of the board's thread (`thread`, oldest first, as the Cockpit sends it), newest
  /// at the bottom. The Cockpit's own lines (*Moved to a new chat*) are neither Igor's nor Larry's, and are left out, and
  /// so are Igor's pictures that carried no words of his (#1003, story 1047): the chip under the thread stands for them.
  public static func recent(_ thread: [ChatMessage]) -> [Row] {
    thread.suffix(panelMessages).compactMap { message in
      if message.isSystem { return nil }
      guard message.fromIgor else {
        return Row(
          id: message.id, kind: .larry, who: ChatSpeaker.of(message).label,
          text: message.text.isEmpty ? drewOnTheBoard : message.text)
      }
      let words = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
      if !message.attachments.isEmpty, words.isEmpty || words == boardTurnNote { return nil }
      return Row(id: message.id, kind: .you, who: "You", text: words.isEmpty ? "…" : message.text)
    }
  }

  /// Where a picture of Igor's got to, in the chip's words, with no turn out (#1003, story 1047). `answered`: a row of
  /// Larry's follows it, which is his answer whatever the mark says; `marks`: the Cockpit marks Igor's messages, so a
  /// missing mark means something. On one that marks nothing the picture on the thread is with Larry, never *Sent*
  /// (stories 1161, 1162, bead context-grabber-l9u).
  static func chipWord(_ receipt: ChatMessage.Receipt, answered: Bool = false, marks: Bool = true) -> String {
    if answered { return "Answered" }
    switch receipt {
    case .sent: return marks ? "Sent" : "Larry has it"
    case .received: return "Sent"
    case .seen: return "Larry has it"
    case .done: return "Answered"
    }
  }

  /// The panel's status chip (#1003, story 1047): where Igor's newest board picture is, in one vocabulary. While a turn
  /// is out, the closed line's own state with what waits to go next (the waiting words in full); else the newest
  /// picture's mark in words; nil with neither.
  public static func chip(
    thread: [ChatMessage], larry: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool,
    mark: WhiteboardLarryWait.Mark = .unknown, listening: String? = nil
  ) -> String? {
    if larry.looking,
      let clock = WhiteboardLarryClock.state(larry, now: now, cockpitAnswering: cockpitAnswering, mark: mark)
    {
      guard let next = waiting(larry) else { return clock }
      return "\(clock) · next: " + (larry.queued.map { "\(next): \($0)" } ?? next)
    }
    // Story 929: his hold, in his words, in place of *Larry has it*: one chip, one vocabulary.
    if let listening { return listening }
    guard let at = thread.lastIndex(where: { $0.fromIgor && !$0.attachments.isEmpty }) else { return nil }
    let answered = thread[(at + 1)...].contains { !$0.fromIgor && !$0.isSystem }
    let marks = thread.contains { $0.fromIgor && $0.receipt != .sent }
    return chipWord(thread[at].receipt, answered: answered, marks: marks)
  }

  /// The panel's live rows, under its thread: the status chip, and what the mic is hearing.
  public static func live(
    thread: [ChatMessage] = [], larry: WhiteboardLarryTurn, now: ContinuousClock.Instant, cockpitAnswering: Bool,
    mark: WhiteboardLarryWait.Mark = .unknown, said: WhiteboardSaid, micOn: Bool, listening: String? = nil
  ) -> [Row] {
    var rows: [Row] = []
    let ear = WhiteboardLarryListening.shown(listening, turn: larry)
    if let chip = chip(
      thread: thread, larry: larry, now: now, cockpitAnswering: cockpitAnswering, mark: mark, listening: ear)
    {
      rows.append(Row(id: "live-chip", kind: .live, who: "Your board", text: chip, listening: ear != nil))
    }
    if micOn {
      rows.append(Row(id: "live-mic", kind: .live, who: "Hearing", text: said.you ?? "Listening…"))
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

  /// The newest thing said, by whoever said it last, and whether it is Larry's.
  private static func middle(_ said: WhiteboardSaid, micOn: Bool) -> (text: String, keepsEnd: Bool, larry: Bool)? {
    // Story 1127: a link reads as its chip's words, never the long address.
    let larry = said.larry.map { (text: "Larry: \(ChatBubbleLinks.shortened($0))", keepsEnd: false, larry: true) }
    guard said.youLast else { return larry ?? said.you.map { ("You: \($0)", true, false) } }
    if let you = said.you { return ("You: \(you)", true, false) }
    return micOn ? ("Listening…", false, false) : larry
  }
}
