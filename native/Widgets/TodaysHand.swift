//  Today's hand, the large widget (#221; spec 2026-10-08-native-large-widget-design.md): the memdeck card, dealt in
//  place by a tap; the eulogy's role of the day; and three one-tap starts. The card comes from Igor's stack (#219),
//  drawn as the trainer's card screen draws it, one per five minutes by the clock and the tap count in the App Group
//  (Shared/CardStore.swift), without the easy cards when the card screen's Skip easy cards is on.

import AppIntents
import ContextCore
import OSLog
import SwiftUI
import ThinkACardCore
import ThinkACardUI
import WidgetKit

/// The extension's copy of the stack, loaded once; nil when the build had none.
private let stack: Deck? = try? TrainerDeck.load().get()

/// The extension has no session log; these lines are read with `log show` (#230: a tap that did not change the card).
private let widgetLog = Logger(subsystem: "com.idvorkin.grabbernative", category: "todays-hand")

/// A tap on the widget's card: a different card, without opening the app. The widget reloads after it runs.
struct DealCardIntent: AppIntent {
  static let title: LocalizedStringResource = "Deal another card"
  static let description = IntentDescription("Deals a different memdeck card on Today's hand.")

  /// The tap count the tapped entry was dealt with: what was on screen, carried by the drawn button itself, so a
  /// redraw iOS skipped after an earlier tap cannot hide it (#230). nil from Shortcuts.
  @Parameter(title: "Dealt with") var shown: Int?
  /// The five-minute slot that card was dealt for: an entry can stay on screen past its slot until iOS redraws.
  @Parameter(title: "Dealt for") var shownSlot: Int?

  init() {}

  init(shown: Int, slot: Int) {
    self.shown = shown
    shownSlot = slot
  }

  func perform() async throws -> some IntentResult {
    let size = stack.map { TrainerDeck.pool($0).count } ?? CardDeal.cardsPerRun
    let now = Date()
    let old = CardStore.nonce()
    let new = CardDeal.nonceAfterTap(at: now, nonce: old, shown: shown, shownSlot: shownSlot, size: size)
    CardStore.set(new)
    let slot = CardDeal.slot(containing: now)
    widgetLog.notice(
      "deal_tap old=\(old, privacy: .public) shown=\(shown.map(String.init) ?? "none", privacy: .public) shown_slot=\(shownSlot.map(String.init) ?? "none", privacy: .public) new=\(new, privacy: .public) stored=\(CardStore.nonce(), privacy: .public) size=\(size, privacy: .public) slot=\(slot, privacy: .public) from=\(CardDeal.index(forSlot: slot, nonce: old, size: size), privacy: .public) to=\(CardDeal.index(forSlot: slot, nonce: new, size: size), privacy: .public)"
    )
    return .result()
  }
}

struct TodaysHandWidget: Widget {
  struct Entry: TimelineEntry {
    let date: Date
    /// The tap count this entry was dealt with; its button hands it to the tap.
    let nonce: Int
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
      let nonce = CardStore.nonce()
      let timeline = CardDeal.timeline(from: Date(), nonce: nonce, size: max(pool.count, 3))
      widgetLog.notice(
        "timeline nonce=\(nonce, privacy: .public) size=\(pool.count, privacy: .public) first=\(timeline.first?.index ?? -1, privacy: .public) card=\(timeline.first.flatMap { pool.isEmpty ? nil : pool[$0.index].spokenName } ?? "none", privacy: .public)"
      )
      let entries = timeline.map {
        Entry(
          date: $0.date, nonce: nonce, card: pool.isEmpty ? nil : pool[$0.index], role: EulogyRoles.ofDay($0.date))
      }
      completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, nonce: Int) -> Entry {
      let pool = stack.map { TrainerDeck.pool($0) } ?? []
      let index = CardDeal.index(forSlot: CardDeal.slot(containing: date), nonce: nonce, size: max(pool.count, 3))
      return Entry(date: date, nonce: nonce, card: pool.isEmpty ? nil : pool[index], role: EulogyRoles.ofDay(date))
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
  // AppLink writes these from constants; AppLinkTests reads every route's link back.
  // swiftlint:disable:next force_unwrapping
  static let home = URL(string: AppLink.link(for: .home))!
  // swiftlint:disable:next force_unwrapping
  static let think = URL(string: AppLink.link(for: .card(think: true)))!
  // swiftlint:disable:next force_unwrapping
  static let supermix = URL(string: AppLink.link(for: .supermix))!
  // swiftlint:disable:next force_unwrapping
  static let call = URL(string: AppLink.link(for: .call(via: nil)))!
}

struct TodaysHandView: View {
  let entry: TodaysHandWidget.Entry

  var body: some View {
    HStack(spacing: 14) {
      Button(intent: DealCardIntent(shown: entry.nonce, slot: CardDeal.slot(containing: entry.date))) {
        HandCard(card: entry.card)
      }
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
        Text("No stack in this build").font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(
          .center
        )
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
