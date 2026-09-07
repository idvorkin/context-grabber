import SwiftUI
import WidgetKit

// The memdeck card as it is drawn — on the big Today widget (a small white
// card) and as a lock-screen widget of its own (the same card, in the lock
// screen's one tint). Spec: docs/superpowers/specs/2026-09-07-widget-random-card-design.md
// The deal itself is PlayingCard.swift; nothing here chooses a card.

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

  static func at(_ moment: Date) -> MemdeckCardEntry {
    MemdeckCardEntry(date: moment, card: CardDeal.card(at: moment))
  }
}

struct MemdeckCardProvider: TimelineProvider {
  func placeholder(in context: Context) -> MemdeckCardEntry {
    MemdeckCardEntry(date: Date(), card: PlayingCard(rank: "7", suit: .clubs))
  }

  func getSnapshot(in context: Context, completion: @escaping (MemdeckCardEntry) -> Void) {
    completion(.at(Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MemdeckCardEntry>) -> Void) {
    // A card per quarter hour for the next twelve hours; then ask again.
    let entries = CardDeal.moments(from: Date(), count: 48).map(MemdeckCardEntry.at)
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

/// The lock screen draws in one tint, so the suit is a shape, not a colour.
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
    .widgetURL(URL(string: "grabber://main")!)
    .accessoryBackgroundCompat()
  }
}

private extension View {
  /// iOS 17 wants every widget to name its container background; the lock
  /// screen's is the system's own, so it is clear here.
  @ViewBuilder
  func accessoryBackgroundCompat() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) { Color.clear }
    } else {
      self
    }
  }
}

struct MemdeckCardWidget: Widget {
  let kind = "MemdeckCardWidget"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MemdeckCardProvider()) { entry in
      MemdeckCardView(entry: entry)
    }
    .configurationDisplayName("Memdeck card")
    .description("A random card every quarter hour — find it in the stack.")
    .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}
