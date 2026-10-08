//  Today's hand, the large widget (#221; spec 2026-10-08-native-large-widget-design.md): the memdeck card, dealt in
//  place by a tap; the eulogy's role of the day; and three one-tap starts. The card comes from Igor's stack (#219),
//  drawn as the trainer's card screen draws it, one per five minutes by the clock and the tap count in the App Group
//  (Shared/CardStore.swift), without the easy cards when the card screen's Skip easy cards is on.

import AppIntents
import ContextCore
import SwiftUI
import ThinkACardCore
import ThinkACardUI
import WidgetKit

/// The extension's copy of the stack, loaded once; nil when the build had none.
private let stack: Deck? = try? TrainerDeck.load().get()

/// A tap on the widget's card: a different card, without opening the app. The widget reloads after it runs.
struct DealCardIntent: AppIntent {
  static let title: LocalizedStringResource = "Deal another card"
  static let description = IntentDescription("Deals a different memdeck card on Today's hand.")

  func perform() async throws -> some IntentResult {
    let size = stack.map { TrainerDeck.pool($0).count } ?? CardDeal.cardsPerRun
    CardStore.set(CardDeal.nonceAfterTap(at: Date(), nonce: CardStore.nonce(), size: size))
    return .result()
  }
}

struct TodaysHandWidget: Widget {
  struct Entry: TimelineEntry {
    let date: Date
    /// nil when the build had no stack.
    let card: Card?
    let role: String
  }

  struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { entry(at: Date(), nonce: 0) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
      completion(entry(at: Date(), nonce: CardStore.nonce()))
    }

    /// Twelve hours of five-minute cards, with the role for each moment's day; then ask again.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
      let pool = stack.map { TrainerDeck.pool($0) } ?? []
      let entries = CardDeal.timeline(from: Date(), nonce: CardStore.nonce(), size: max(pool.count, 3)).map {
        Entry(date: $0.date, card: pool.isEmpty ? nil : pool[$0.index], role: EulogyRoles.ofDay($0.date))
      }
      completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, nonce: Int) -> Entry {
      let pool = stack.map { TrainerDeck.pool($0) } ?? []
      let index = CardDeal.index(forSlot: CardDeal.slot(containing: date), nonce: nonce, size: max(pool.count, 3))
      return Entry(date: date, card: pool.isEmpty ? nil : pool[index], role: EulogyRoles.ofDay(date))
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
      Button(intent: DealCardIntent()) { HandCard(card: entry.card) }
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

/// The trainer's card face (its story 005: the rank large, the suit under it, red or white) on black, as the card
/// screen shows it; without a stack, a word saying so.
private struct HandCard: View {
  let card: Card?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black)
      if let card {
        CardFace(card: card).padding(.vertical, 18).padding(.horizontal, 10)
      } else {
        Text("No stack in this build").font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
          .padding()
      }
    }
    .aspectRatio(5 / 7, contentMode: .fit)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(card.map { "Memdeck card \($0.spokenName); tap for another" } ?? "No stack in this build")
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
