//  The board's open conversation resized, and floating as a card or docked (#1384, stories 1278, 1279; spec
//  2026-11-12-whiteboard-conversation-design.md, *Resize, and float or dock*). Docked, a grip under the panel drags it
//  taller or shorter and the page moves with it; floating, a card over the board that a finger drags by its top edge and
//  sizes by its top-left corner. Where and how big are `WhiteboardPanelPlace`, kept as shares of the page.

import ContextCore
import SwiftUI

/// The kept choices: the docked panel's share of the page (0 for none yet: a fifth), floating or not, and the card.
enum WhiteboardPanelKeys {
  static let share = "whiteboard_panel_share"
  static let floating = "whiteboard_panel_floating"
  static let card = "whiteboard_panel_card"
  private static var forgotten = false

  /// Story 1313: `GRABBER_WHITEBOARD_PANEL=fresh` forgets the kept place once per launch, as the first board opens.
  @MainActor static func forgetForTests() {
    guard LaunchHooks.current.whiteboard.panelFresh, !forgotten else { return }
    forgotten = true
    for key in [share, floating, card] { UserDefaults.standard.removeObject(forKey: key) }
  }
}

/// What the panel's foot offers to move it: *Float* while docked, *Dock* while floating.
struct WhiteboardPanelDock {
  let floating: Bool
  let toggle: () -> Void
}

/// The panel's Float or Dock button, at its foot.
struct WhiteboardPanelDockButton: View {
  let dock: WhiteboardPanelDock
  /// Story 1313 (#1416): its icon alone, when the foot is too narrow for the word.
  var compact = false

  var body: some View {
    Button {
      dock.toggle()
    } label: {
      let label = Label(
        dock.floating ? "Dock" : "Float",
        systemImage: dock.floating ? "rectangle.topthird.inset.filled" : "macwindow.on.rectangle")
      if compact { label.labelStyle(.iconOnly) } else { label }
    }
    .font(.footnote).buttonStyle(.borderless).lineLimit(1)
    .accessibilityIdentifier(dock.floating ? "whiteboard-conversation-dock" : "whiteboard-conversation-float")
  }
}

/// Story 1278: the docked panel and the grip under it. Dragged, the panel follows the finger and the page moves with it;
/// let go, its share of the page is kept for the next board.
struct WhiteboardConversationDocked<Panel: View>: View {
  let pageHeight: CGFloat
  /// The panel at a height: nil for its own, as before any drag.
  @ViewBuilder let panel: (CGFloat?) -> Panel
  @AppStorage(WhiteboardPanelKeys.share) private var share: Double = 0
  /// The panel's height while the grip is held.
  @State private var dragging: CGFloat?
  @State private var shown: CGFloat = 0

  private var height: CGFloat? {
    if let dragging { return dragging }
    guard share > 0 else { return nil }
    return CGFloat(WhiteboardPanelPlace.height(stored: share, page: Double(pageHeight)))
  }

  var body: some View {
    VStack(spacing: 0) {
      panel(height)
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          shown = $0
        }
      WhiteboardPanelGrip(axis: .vertical)
        // A double tap gives it back its own size: a fifth at most, as before any drag.
        .onTapGesture(count: 2) { share = 0 }
        .gesture(
          DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { drag in
              let from = baseline ?? height ?? shown
              baseline = from
              dragging = CGFloat(
                WhiteboardPanelPlace.height(stored: share(from: from, by: drag.translation.height), page: page))
            }
            .onEnded { drag in
              share = self.share(from: baseline ?? height ?? shown, by: drag.translation.height)
              dragging = nil
              baseline = nil
            }
        )
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  /// The panel's height when the grip was first touched.
  @State private var baseline: CGFloat?

  private var page: Double { Double(pageHeight) }

  private func share(from: CGFloat, by: CGFloat) -> Double {
    WhiteboardPanelPlace.resized(from: Double(from), by: Double(by), page: page)
  }
}

/// Story 1279: the card floating over the board, at its kept place and size, on an area `area` big.
struct WhiteboardConversationCard<Panel: View>: View {
  let area: CGSize
  /// The panel at the card's height (less its top edge).
  @ViewBuilder let panel: (CGFloat) -> Panel
  @AppStorage(WhiteboardPanelKeys.card) private var kept = ""
  /// The card while a finger moves or sizes it; kept once let go.
  @State private var live: WhiteboardPanelPlace.Card?

  private var size: (width: Double, height: Double) { (Double(area.width), Double(area.height)) }
  private var card: WhiteboardPanelPlace.Card { live ?? WhiteboardPanelPlace.Card(stored: kept) }

  var body: some View {
    let frame = card.frame(in: size)
    VStack(spacing: 0) {
      // The top edge: a finger drags the card by it.
      WhiteboardPanelGrip(axis: .horizontal)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { drag in
              live = WhiteboardPanelPlace.Card(stored: kept).moved(
                dx: Double(drag.translation.width), dy: Double(drag.translation.height), in: size)
            }
            .onEnded { _ in keep() }
        )
        .accessibilityIdentifier("whiteboard-conversation-card-move")
      panel(max(CGFloat(frame.height) - WhiteboardPanelGrip.side, 0))
        .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(width: CGFloat(frame.width), height: CGFloat(frame.height))
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(alignment: .topLeading) {
      // The top-left corner (#1491): a finger sizes the card by it, the bottom right staying put.
      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .font(.caption).foregroundStyle(.secondary)
        .frame(width: WhiteboardPanelGrip.side, height: WhiteboardPanelGrip.side)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { drag in
              live = WhiteboardPanelPlace.Card(stored: kept).resized(
                dx: Double(drag.translation.width), dy: Double(drag.translation.height), in: size)
            }
            .onEnded { _ in keep() }
        )
        .accessibilityLabel("Resize the conversation")
        .accessibilityIdentifier("whiteboard-conversation-card-size")
    }
    .shadow(radius: 6)
    // A touch on the card is the card's: the Pencil draws nothing through it.
    .contentShape(RoundedRectangle(cornerRadius: 14))
    .offset(x: CGFloat(frame.x), y: CGFloat(frame.y))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whiteboard-conversation-card")
  }

  private func keep() {
    if let live { kept = live.stored }
    live = nil
  }
}

/// A grip: a short capsule in a strip a finger can hold.
struct WhiteboardPanelGrip: View {
  enum Axis { case vertical, horizontal }
  static let side: CGFloat = 28
  let axis: Axis

  var body: some View {
    Capsule()
      .fill(Color.secondary.opacity(0.5))
      .frame(width: 36, height: 5)
      .frame(maxWidth: .infinity, minHeight: Self.side, maxHeight: Self.side)
      .background(axis == .vertical ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.clear))
      .contentShape(Rectangle())
      .accessibilityLabel(axis == .vertical ? "Resize the conversation" : "Move the conversation")
      .accessibilityIdentifier(axis == .vertical ? "whiteboard-conversation-grip" : "whiteboard-conversation-handle")
  }
}
