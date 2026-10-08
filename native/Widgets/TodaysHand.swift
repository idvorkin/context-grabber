//  Today's hand, the large widget (#221; spec 2026-10-08-native-large-widget-design.md): the memdeck card, dealt in
//  place by a tap; the eulogy's role of the day; and three one-tap starts. The card is the card screen's deal, read
//  from the tap count the app keeps in the App Group (Shared/CardStore.swift).

import AppIntents
import ContextCore
import SwiftUI
import WidgetKit

/// A tap on the widget's card: a different card, without opening the app. The widget reloads after it runs.
struct DealCardIntent: AppIntent {
  static let title: LocalizedStringResource = "Deal another card"
  static let description = IntentDescription("Deals a different memdeck card on Today's hand.")

  func perform() async throws -> some IntentResult {
    CardStore.set(CardDeal.nonceAfterTap(at: Date(), nonce: CardStore.nonce()))
    return .result()
  }
}

struct TodaysHandWidget: Widget {
  struct Entry: TimelineEntry {
    let date: Date
    let card: PlayingCard
    let role: String
  }

  struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { entry(at: Date(), nonce: 0) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
      completion(entry(at: Date(), nonce: CardStore.nonce()))
    }

    /// Twelve hours of five-minute cards, with the role for each moment's day; then ask again.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
      let entries = CardDeal.timeline(from: Date(), nonce: CardStore.nonce()).map {
        Entry(date: $0.date, card: $0.card, role: EulogyRoles.ofDay($0.date))
      }
      completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, nonce: Int) -> Entry {
      Entry(date: date, card: CardDeal.card(at: date, nonce: nonce), role: EulogyRoles.ofDay(date))
    }
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: CardStore.kind, provider: Provider()) { entry in
      TodaysHandView(entry: entry).containerBackground(Color(red: 0.06, green: 0.09, blue: 0.16), for: .widget)
    }
    .configurationDisplayName("Today's hand")
    .description("A memdeck card that a tap deals again, a role from the eulogy for the day, and three quick starts.")
    .supportedFamilies([.systemLarge])
  }
}

private enum HandLinks {
  static let home = URL(string: AppLink.link(for: .home))!
  static let think = URL(string: AppLink.link(for: .card(think: true)))!
  static let supermix = URL(string: AppLink.link(for: .supermix))!
  static let call = URL(string: AppLink.link(for: .call(via: nil)))!
}

struct TodaysHandView: View {
  let entry: TodaysHandWidget.Entry

  var body: some View {
    HStack(spacing: 14) {
      Button(intent: DealCardIntent()) { CardFace(card: entry.card) }
        .buttonStyle(.plain)
      VStack(alignment: .leading, spacing: 8) {
        Text("Today, be")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color(white: 0.6))
        Text(entry.role)
          .font(.title3.weight(.bold))
          .foregroundStyle(.white)
          .minimumScaleFactor(0.7)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 4)
        HandButton(title: "Think of a card", icon: "suit.spade.fill", url: HandLinks.think)
        HandButton(title: "Supermix", icon: "music.note.list", url: HandLinks.supermix)
        HandButton(title: "Call Larry", icon: "phone.fill", url: HandLinks.call)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .widgetURL(HandLinks.home)
  }
}

/// The card screen's face, drawn to fit the widget.
private struct CardFace: View {
  let card: PlayingCard

  private var ink: Color { card.isRed ? Color(red: 0.8, green: 0.09, blue: 0.13) : Color(white: 0.08) }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14).fill(.white)
      Text(card.suit.rawValue).font(.system(size: 72, weight: .bold))
      corner.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(10)
      corner.rotationEffect(.degrees(180))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(10)
    }
    .foregroundStyle(ink)
    .aspectRatio(5 / 7, contentMode: .fit)
    .accessibilityLabel("Memdeck card \(card.label); tap for another")
  }

  private var corner: some View {
    VStack(spacing: 0) {
      Text(card.rank)
      Text(card.suit.rawValue)
    }
    .font(.system(size: 20, weight: .heavy))
  }
}

private struct HandButton: View {
  let title: String
  let icon: String
  let url: URL

  var body: some View {
    Link(destination: url) {
      Label(title, systemImage: icon)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}
