import SwiftUI
import WidgetKit

// The memdeck card as it is drawn — on the big Today widget (a small white
// card) and as a lock-screen widget of its own (the same card, in the lock
// screen's one tint). Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
// The deal itself is PlayingCard.swift; nothing here chooses a card.

// MARK: - A tap deals

/// On iOS 17+ a tap on the card deals a new one in place (the intent); before
/// iOS 17 the widget's own link — open the app — is what a tap does. No
/// `invalidatableContent()` on the label: with it, the tap opened the app
/// instead of running the intent.
///
/// Home-screen widgets only. iPhone lock-screen widgets run no in-place
/// actions: a button there dims the card as "changing" and nothing ever
/// changes it, which on the lock screen's one-tint rendering is a blank widget.
struct TapToDeal<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    #if canImport(AppIntents)
    if #available(iOS 17.0, *) {
      Button(intent: DealCardIntent()) { content() }
        .buttonStyle(.plain)
    } else {
      content()
    }
    #else
    content()
    #endif
  }
}

// MARK: - The card on the big widget

/// A small white playing card: rank and suit in the corner, the suit large in
/// the middle, hearts and diamonds in red. Two lines of metrics tall.
struct PlayingCardView: View {
  let card: PlayingCard

  private var ink: Color {
    card.isRed ? Color(red: 0.80, green: 0.09, blue: 0.13) : Color(white: 0.08)
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: -3) {
        Text(card.rank)
          .font(.system(size: 13, weight: .heavy, design: .rounded))
        Text(card.suit.rawValue)
          .font(.system(size: 11, weight: .bold))
      }
      .padding(.leading, 4)
      .padding(.top, 2)
      Text(card.suit.rawValue)
        .font(.system(size: 26, weight: .bold))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 6)
        .padding(.leading, 6)
    }
    .foregroundColor(ink)
    .frame(width: 44, height: 60)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .stroke(Color.black.opacity(0.22), lineWidth: 1)
    )
    .accessibilityLabel("Memdeck card: \(card.label)")
  }
}

// MARK: - The lock-screen widget

struct MemdeckCardEntry: TimelineEntry {
  let date: Date
  let card: PlayingCard
}

struct MemdeckCardProvider: TimelineProvider {
  func placeholder(in context: Context) -> MemdeckCardEntry {
    MemdeckCardEntry(date: Date(), card: PlayingCard(rank: "7", suit: .clubs))
  }

  func getSnapshot(in context: Context, completion: @escaping (MemdeckCardEntry) -> Void) {
    let now = Date()
    completion(MemdeckCardEntry(date: now, card: CardDeal.card(at: now, nonce: DealStore.nonce())))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MemdeckCardEntry>) -> Void) {
    // The whole horizon of cards, in case iOS never honours the reload policy;
    // a tap on the big widget reloads this. Ask again within the hour regardless.
    let entries = CardDeal.timeline(from: Date(), nonce: DealStore.nonce()).map { MemdeckCardEntry(date: $0.date, card: $0.card) }
    completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(60 * 60))))
  }
}

/// The lock screen draws in one tint, so the suit is a shape, not a colour.
/// No button here (see `TapToDeal`): a tap opens the app on its card screen,
/// which deals; the big widget's deal reaches this one through the intent's
/// reload, the app's through its sync when the card screen closes.
struct MemdeckCardView: View {
  let entry: MemdeckCardEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    Group {
      switch family {
      case .accessoryInline:
        // One line above the clock: "7♣ memdeck".
        Text("\(entry.card.label) memdeck")
      case .accessoryCircular:
        ZStack {
          AccessoryWidgetBackground()
          Text(entry.card.label)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .widgetAccentable()
        }
      default:
        // Rectangular: the card as big as the row allows, "memdeck" beside it.
        HStack(alignment: .center, spacing: 10) {
          Text(entry.card.label)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .widgetAccentable()
          VStack(alignment: .leading, spacing: 0) {
            Text("memdeck")
              .font(.system(size: 13, weight: .semibold))
            Text("find it")
              .font(.system(size: 11))
              .opacity(0.7)
          }
          Spacer(minLength: 0)
        }
      }
    }
    .accessibilityLabel("Memdeck card: \(entry.card.label)")
    .widgetURL(URL(string: "grabber://card")!)  // the app, on a fresh card (D5)
    .widgetBackgroundCompat(.clear)
  }
}

struct MemdeckCardWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: WidgetKind.memdeckCard, provider: MemdeckCardProvider()) { entry in
      MemdeckCardView(entry: entry)
    }
    .configurationDisplayName("Memdeck card")
    .description("A random card every five minutes — find it in the stack. Tap the card on the Today widget for a new one.")
    .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}
