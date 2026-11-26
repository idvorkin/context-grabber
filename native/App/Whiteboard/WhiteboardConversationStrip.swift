//  The board's conversation strip, apart from the drawing screen (#1039): the note's one line over the paper (story
//  766), the problem under it with Larry's Retry and Dismiss (stories 761, 762, 775, 776), the conversation it opens
//  above the paper on an iPad (stories 768, 837, 1045, 1047, 1048) and the thread's text that scrolls inside it. What
//  they say is ContextCore's `WhiteboardNote` and `WhiteboardLarryWait` (host-tested); these views lay it out from the
//  values they are handed and give taps back through the actions they are handed.

import BugKit
import ContextCore
import SwiftUI
import UIKit

/// The bar's note, one line (story 766): Larry's state first so it is never what gets cut off (story 667), the newest
/// thing said, how many suggestions show, and a chevron. A finger tap opens the conversation over the board, or on an
/// iPhone the board's thread in Chat (story 769). VoiceOver reads his state in words when it reaches the note, not on
/// every tick. The line's room stays when it has nothing to say, so the paper never moves for it.
struct WhiteboardNoteStrip: View {
  /// What the strip shows at a moment, all read then, as the line ticks: Larry's clock (story 667).
  struct Shown {
    let line: WhiteboardNote.Line?
    /// What a tap on the line does.
    let tap: WhiteboardNote.Tap
    let conversationOpen: Bool
    /// Story 895: every mark of Larry's kept at once; nil when there is none, or the board is only looked at.
    let keepAll: (() -> Void)?
    /// Story 777: Larry has the picture and twenty seconds have passed; nil otherwise.
    let interrupt: (() -> Void)?
  }

  /// What it shows, read by the drawing screen as it draws (context-grabber-c59d): a value, so a change in the model
  /// draws the strip again. A closure alone looks the same to SwiftUI every time, and the line went stale.
  let current: Shown
  /// What it shows at each tick; read once a second while the line ticks.
  let shown: (ContinuousClock.Instant) -> Shown
  /// Whether the line ticks once a second: Larry's clock, or a message holding the middle (story 766).
  let ticks: Bool
  let onPhone: Bool
  let tapNote: () -> Void
  @ScaledMetric(relativeTo: .footnote) private var noteHeight: CGFloat = 28

  var body: some View {
    if ticks {
      TimelineView(.periodic(from: .now, by: 1)) { _ in content(shown(.now)) }
    } else {
      content(current)
    }
  }

  @ViewBuilder private func content(_ shown: Shown) -> some View {
    let (tap, conversationOpen) = (shown.tap, shown.conversationOpen)
    if let line = shown.line {
      HStack(spacing: 6) {
        // Story 929: Larry is holding for more, where his state would be.
        if let listening = line.listening {
          LarryListeningEar(label: listening).layoutPriority(1)
            .accessibilityIdentifier("whiteboard-larry-listening")
          if line.middle != nil { Text("·") }
        }
        if let state = line.state {
          Text(state).lineLimit(1).layoutPriority(1)
            .accessibilityLabel(line.spokenState ?? state)
            .accessibilityIdentifier("whiteboard-note-state")
          if line.middle != nil { Text("·") }
        }
        if let middle = line.middle {
          Text(middle).lineLimit(1).truncationMode(line.keepsEnd ? .head : .tail)
            // Story 1053 (#1003): Larry's words lead.
            .foregroundStyle(line.larrySpeaks ? Color.primary : Color(WhiteboardNoteInk.quiet))
            .accessibilityIdentifier("whiteboard-note-said")
        }
        Spacer(minLength: 0)
        if let keep = line.keep { Text(keep).lineLimit(1).fixedSize() }
        if let keepAll = shown.keepAll {
          Button("Keep all", action: keepAll).buttonStyle(.borderless).fixedSize()
            .accessibilityHint(
              "Keeps every mark of Larry's where it showed, each reply as one group that moves together"
            )
            .accessibilityIdentifier("whiteboard-keep-all")
        }
        if let interrupt = shown.interrupt {
          Button("Interrupt", action: interrupt).buttonStyle(.borderless).fixedSize()
            .accessibilityHint("Stops waiting for Larry's answer, so the next picture is a fresh ask")
            .accessibilityIdentifier("whiteboard-larry-interrupt")
        }
        if tap != .nothing {
          Button(action: tapNote) {
            Image(systemName: onPhone ? "chevron.right" : conversationOpen ? "chevron.up" : "chevron.down")
          }
          .buttonStyle(.borderless)
          .accessibilityLabel(
            onPhone ? "Open in Chat" : conversationOpen ? "Hide the conversation" : "Show the conversation"
          )
          .accessibilityIdentifier("whiteboard-note-chevron")
        }
      }
      .font(.footnote).foregroundStyle(Color(WhiteboardNoteInk.quiet))
      .padding(.vertical, 4).padding(.horizontal)
      .frame(minHeight: noteHeight)
      .contentShape(Rectangle())
      .onTapGesture(perform: tapNote)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("whiteboard-note")
    } else {
      // Nothing to say yet: the line's room stays, so the paper doesn't jump when it first speaks.
      Color.clear.frame(height: noteHeight).accessibilityHidden(true)
    }
  }
}

/// The board's problem under the note, copyable, with what each of Larry's own problems offers: his silence a Dismiss
/// (stories 761, 762), a picture the Cockpit hasn't taken in twenty seconds Retry and Dismiss (stories 775, 776).
struct WhiteboardProblemRow: View {
  let problem: BugProblem
  let logger: BugLogger
  let dismissSilence: () -> Void
  let retryLarry: () -> Void
  let dismissStuck: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      BugProblemView(problem: problem, logger: logger)
      // Stories 761, 762: his silence stays until he next answers or this.
      if problem.context == WhiteboardLarryClock.DidntAnswer.context {
        Spacer()
        Button("Dismiss", action: dismissSilence).font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-dismiss-problem")
      }
      // Stories 775, 776: a picture the Cockpit hasn't taken in twenty seconds.
      if problem.context == WhiteboardLarryWait.stuckContext {
        Spacer()
        Button("Retry", action: retryLarry).font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-larry-retry")
        Button("Dismiss", action: dismissStuck).font(.footnote).buttonStyle(.borderless)
          .accessibilityIdentifier("whiteboard-larry-dismiss")
      }
    }
    .padding(.horizontal)
  }
}

/// Story 768: the open note, above the board (story 1048): the board's thread, selectable, then the status chip and
/// what the mic hears, and *Open in Chat*. The Pencil never acts on it: the thread's text takes finger touches only,
/// and the rest holds nothing to scroll or draw on. Docked, its text runs to about half the board (story 1045, #1438), and its
/// thread at a fifth of the page, past which it scrolls rather than grows (story 837).
struct WhiteboardConversationPanel: View {
  /// The thread's recent end.
  let rows: [WhiteboardNote.Row]
  /// Whether the live rows tick once a second, with Larry's clock.
  let ticks: Bool
  /// The status chip and what the mic hears, read by the drawing screen as it draws: a value, so a change draws the
  /// panel again (context-grabber-c59d).
  let current: [WhiteboardNote.Row]
  /// The status chip and what the mic hears, at a moment (story 1047); read once a second while the rows tick.
  let live: (ContinuousClock.Instant) -> [WhiteboardNote.Row]
  /// The whole page's height, not the paper's it pushes down, so opening it doesn't change its own limit (story 837).
  let pageHeight: CGFloat
  /// Opens the board's thread in Chat; nil when the board has none yet.
  let openInChat: (() -> Void)?
  /// Story 1127: a link chip in the thread was tapped; it opens on its own, this only tells the log.
  var linkOpened: (ChatLink) -> Void = { _ in }
  /// Story 1277 (#1384): Chat's model and the board's thread, for the bubbles' links and tables; nil shows no switch.
  var chat: ChatModel?
  var threadKey: String?
  /// Stories 1278, 1279 (#1384): the whole panel's height, dragged by its grip or the card's; nil for its own (story 837).
  var height: CGFloat?
  /// Stories 1279 (#1384): *Float* or *Dock* at the foot; nil offers neither.
  var dock: WhiteboardPanelDock?
  /// Story 1277 (#1384): Lines or Bubbles, remembered for the next board.
  @AppStorage(WhiteboardPanelLook.storageKey) private var look: WhiteboardPanelLook = .lines
  /// Story 1045 (#1003): about seventy characters of the conversation's type, the narrowest its docked text runs.
  @ScaledMetric(relativeTo: .footnote) private var readableWidth: CGFloat = 470
  /// Story 837: what the panel's chip, Open in Chat and padding take, and the fewest lines of thread it keeps.
  @ScaledMetric(relativeTo: .footnote) private var panelChrome: CGFloat = 72
  @ScaledMetric(relativeTo: .footnote) private var threadFloor: CGFloat = 64

  /// Story 1313 (#1416): what the chip, the mic's words and the foot really take under the thread, once laid out.
  @State private var belowThread: CGFloat = 0
  /// Story 1045 (#1438): the width the panel is given, so docked its text runs to about half the board.
  @State private var givenWidth: CGFloat = 0

  /// Story 1045 (#1438): docked, about half the board and never under seventy characters; floating, the card's width.
  private var textWidth: CGFloat {
    WhiteboardNote.panelTextWidth(
      board: Double(givenWidth), readable: Double(readableWidth), floating: dock?.floating ?? false
    ).map { CGFloat($0) } ?? .infinity
  }

  /// The panel's chrome: measured when it has been laid out (the foot can be taller than a line), else the estimate.
  private var chrome: CGFloat { belowThread > 0 ? belowThread + 18 : panelChrome }

  private var threadCap: CGFloat {
    if let height { return max(height - chrome, threadFloor) }
    let page = pageHeight > 0 ? WhiteboardNote.panelHeight(board: Double(pageHeight)) : WhiteboardNote.panelFloor
    return max(CGFloat(page) - chrome, threadFloor)
  }

  /// The thread: Lines or Bubbles.
  @ViewBuilder private var thread: some View {
    if look == .bubbles, let chat {
      WhiteboardConversationBubbles(
        bubbles: WhiteboardPanelLook.bubbles(rows), maxHeight: threadCap, chat: chat, thread: threadKey ?? ""
      )
      .environment(\.bubbleLinkOpened, linkOpened)
    } else {
      WhiteboardConversationText(rows: rows, maxHeight: threadCap, linkOpened: linkOpened)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      thread
        // A dragged height is the thread's whether its messages fill it or not, as on the web.
        .frame(height: height == nil ? nil : threadCap, alignment: .top)
      VStack(alignment: .leading, spacing: 6) {
        if ticks {
          TimelineView(.periodic(from: .now, by: 1)) { _ in liveRows(live(.now)) }
        } else {
          liveRows(current)
        }
        WhiteboardPanelFoot(openInChat: openInChat, look: $look, showsLook: chat != nil, dock: dock)
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        belowThread = $0
      }
    }
    .frame(maxWidth: textWidth, alignment: .leading)
    .padding(.horizontal).padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      givenWidth = $0
    }
    .background(.regularMaterial)
    .contentShape(Rectangle())
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whiteboard-conversation")
  }

  /// Under the thread: the status chip (story 1047) and what the mic is hearing.
  private func liveRows(_ rows: [WhiteboardNote.Row]) -> some View {
    // One column of its own: a TimelineView lays several children over each other (#882).
    VStack(alignment: .leading, spacing: 4) {
      ForEach(rows) { row in
        Group {
          if row.id == "live-chip" {
            HStack(spacing: 4) {
              // Story 929: the ear while Larry holds for more.
              if row.listening { LarryListeningEar.icon }
              // Bead context-grabber-97s: never more than two lines, so the panel can't grow past its size.
              Text("\(Text(row.who).bold()) · \(row.text)").lineLimit(2)
            }
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Color(WhiteboardNoteInk.quiet).opacity(0.12), in: Capsule())
          } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text("\(row.who):").bold()
              // Story 1184: what the mic hears, at most two lines, ending on the newest words.
              Text(row.text).lineLimit(2).truncationMode(.head)
            }
          }
        }
        .font(.footnote).foregroundStyle(Color(WhiteboardNoteInk.quiet))
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("whiteboard-conversation-\(row.id)")
      }
    }
  }
}

/// Story 929: Larry has seen Igor's newest post and is holding for more: an ear, gently pulsing (still with Reduce
/// Motion), and his words for it.
struct LarryListeningEar: View {
  let label: String

  var body: some View {
    HStack(spacing: 4) {
      Self.icon
      Text(label).lineLimit(1)
    }
    .padding(.horizontal, 8).padding(.vertical, 2)
    .background(Color(WhiteboardNoteInk.quiet).opacity(0.12), in: Capsule())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
  }

  static var icon: some View { LarryListeningIcon() }
}

/// The ear itself, pulsing unless Reduce Motion is on.
struct LarryListeningIcon: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Image(systemName: "ear")
      .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
      .accessibilityHidden(true)
  }
}

/// #1003 (story 1053): the note's and the panel's quieter text, at least 4.5:1 on the paper and the panel's material in
/// either appearance; the system's secondary and tertiary greys measured about 3:1 and 2:1. Larry's words take the main
/// text colour.
enum WhiteboardNoteInk {
  static let quiet = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0.72, alpha: 1) : UIColor(white: 0.36, alpha: 1)
  }
}

/// Story 768: the board's thread in the open note, one text that can be selected and copied across rows and scrolls
/// inside the panel, newest at the bottom. A UITextView rather than SwiftUI text: its gestures can be told to take
/// fingers only, so the Pencil neither scrolls nor selects it, and a ticking clock beside it doesn't reset a selection.
/// Its links are chips a finger opens (story 1127, #1138), with the words Chat's bubbles give them.
struct WhiteboardConversationText: UIViewRepresentable {
  let rows: [WhiteboardNote.Row]
  let maxHeight: CGFloat
  var linkOpened: (ChatLink) -> Void = { _ in }

  func makeCoordinator() -> Coordinator { Coordinator() }

  /// Opens a tapped chip as UIKit would, after telling the log which kind it was.
  final class Coordinator: NSObject, UITextViewDelegate {
    var links: [URL: ChatLink] = [:]
    var linkOpened: (ChatLink) -> Void = { _ in }
    var shown: (rows: [WhiteboardNote.Row], size: CGFloat)?

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
      guard case .link(let url) = textItem.content, let link = links[url] else { return defaultAction }
      let opened = linkOpened
      let target = Self.target(link)
      return UIAction { _ in
        opened(link)
        UIApplication.shared.open(target)
      }
    }

    /// Story 1127: an Inbox chip opens its thread in the app, in either spelling; any other link where it points.
    static func target(_ link: ChatLink) -> URL {
      guard case .inbox = link.kind, let short = URL(string: ChatLinks.address(link)) else { return link.url }
      return short
    }
  }

  func makeUIView(context: Context) -> NewestInView {
    let view = NewestInView()
    view.isEditable = false
    view.isSelectable = true
    view.backgroundColor = .clear
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.adjustsFontForContentSizeCategory = true
    view.accessibilityIdentifier = "whiteboard-conversation-text"
    view.delegate = context.coordinator
    // Story 1127: a chip keeps the look the text gives it, no underline.
    view.linkTextAttributes = [.foregroundColor: UIColor.tintColor]
    return view
  }

  func updateUIView(_ view: NewestInView, context: Context) {
    context.coordinator.linkOpened = linkOpened
    fingersOnly(view)
    let size = UIFont.preferredFont(forTextStyle: .footnote).pointSize
    if let shown = context.coordinator.shown, shown.rows == rows, shown.size == size { return }
    let (text, links) = Self.text(rows)
    context.coordinator.links = links
    context.coordinator.shown = (rows, size)
    view.show(text)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: NewestInView, context: Context) -> CGSize? {
    let width = proposal.width ?? 320
    let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: min(fit.height, maxHeight, proposal.height ?? .infinity))
  }

  /// ponytail: every gesture the text view has now, set again on each update since UIKit adds some lazily; a Pencil
  /// touch on it then does nothing at all. If one ever slips through, subclass UITextView and filter in its
  /// `gestureRecognizerShouldBegin`.
  private func fingersOnly(_ view: UITextView) {
    let fingers = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
    for gesture in view.gestureRecognizers ?? [] where gesture.allowedTouchTypes != fingers {
      gesture.allowedTouchTypes = fingers
    }
  }

  private static func text(_ rows: [WhiteboardNote.Row]) -> (NSAttributedString, [URL: ChatLink]) {
    let body = UIFont.preferredFont(forTextStyle: .footnote)
    let bold = UIFont(
      descriptor: body.fontDescriptor.withSymbolicTraits(.traitBold) ?? body.fontDescriptor, size: body.pointSize)
    let text = NSMutableAttributedString()
    var links: [URL: ChatLink] = [:]
    for (index, row) in rows.enumerated() {
      if index > 0 { text.append(NSAttributedString(string: "\n")) }
      // Story 1053 (#1003): Larry's words lead; Igor's are quieter, still 4.5:1.
      let color: UIColor = row.kind == .larry ? .label : WhiteboardNoteInk.quiet
      text.append(NSAttributedString(string: "\(row.who): ", attributes: [.font: bold, .foregroundColor: color]))
      for piece in ChatBubbleLinks.pieces(in: row.text) {
        switch piece {
        case .words(let words):
          text.append(NSAttributedString(string: words, attributes: [.font: body, .foregroundColor: color]))
        case .chip(let link):
          links[link.url] = link
          text.append(chip(link, font: bold))
        }
      }
    }
    return (text, links)
  }

  /// A link as a chip in the text (story 1127): its icon and words on a tinted ground, the whole of it the link.
  /// Copying it gives the full address (`NewestInView.copy`).
  private static func chip(_ link: ChatLink, font: UIFont) -> NSAttributedString {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font, .link: link.url, .backgroundColor: UIColor.tertiarySystemFill,
    ]
    let chip = NSMutableAttributedString(string: "\u{2009}", attributes: attributes)
    if let icon = UIImage(systemName: chipIcon(link.kind), withConfiguration: UIImage.SymbolConfiguration(font: font)) {
      let attachment = NSMutableAttributedString(attachment: NSTextAttachment(image: icon))
      attachment.addAttributes(attributes, range: NSRange(location: 0, length: attachment.length))
      chip.append(attachment)
      chip.append(NSAttributedString(string: "\u{2009}", attributes: attributes))
    }
    chip.append(NSAttributedString(string: link.label + "\u{2009}", attributes: attributes))
    return chip
  }

  /// Chat's chip icons (`LinkChip`).
  private static func chipIcon(_ kind: ChatLink.Kind) -> String {
    switch kind {
    case .pullRequest: return "arrow.triangle.pull"
    case .gist: return "doc.text"
    case .web: return "link"
    case .inbox: return "tray"
    case .install: return "arrow.down.app"
    }
  }
}

/// Story 1313 (#1416): the panel's foot, on one line at any width. Too narrow for the words, *Open in Chat* and
/// **Dock** show as their icons, keeping their names for VoiceOver and their identifiers.
struct WhiteboardPanelFoot: View {
  let openInChat: (() -> Void)?
  @Binding var look: WhiteboardPanelLook
  let showsLook: Bool
  let dock: WhiteboardPanelDock?

  var body: some View {
    ViewThatFits(in: .horizontal) {
      row(compact: false)
      row(compact: true)
    }
  }

  private func row(compact: Bool) -> some View {
    HStack(spacing: compact ? 8 : 12) {
      if let openInChat {
        Button(action: openInChat) {
          if compact {
            Label("Open in Chat", systemImage: "bubble.left.and.bubble.right").labelStyle(.iconOnly)
          } else {
            Text("Open in Chat")
          }
        }
        .font(.footnote).buttonStyle(.borderless).lineLimit(1)
        .accessibilityIdentifier("whiteboard-conversation-chat")
      }
      if showsLook { WhiteboardPanelLookSwitch(look: $look) }
      if let dock { WhiteboardPanelDockButton(dock: dock, compact: compact) }
    }
    .fixedSize()
  }
}
