//  The card screen (story 129; spec 2026-10-04-swift-native-app-design.md, "Think of a card: in the app"): one big
//  playing card, a fresh one on every open and every tap. *Think of a card* turns it face down for a count from five,
//  then a new card is face up; *Never mind* stops the count on the card that was showing.

import ContextCore
import SwiftUI

struct CardView: View {
  let log: SessionLog
  /// True: open with the count already running, as the home row does.
  let think: Bool
  let onDone: () -> Void

  static let thinkSeconds = 5

  @State private var nonce = CardStore.nonce()
  @State private var thinking = false
  @State private var left = CardView.thinkSeconds

  private var card: PlayingCard { CardDeal.card(at: Date(), nonce: nonce) }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("Done", action: onDone).accessibilityIdentifier("card-done")
        Spacer()
      }
      .padding()
      Spacer()
      if thinking { back } else { face }
      Text(thinking ? "shuffle…" : "tap the card for another")
        .font(.subheadline)
        .foregroundStyle(Color(white: 0.5))
        .padding(.top, 18)
      Button {
        thinking.toggle()
        log.event("ui", ["action": thinking ? "card_think" : "card_never_mind"])
      } label: {
        Text(thinking ? "Never mind" : "Think of a card")
          .font(.headline)
          .frame(minWidth: 200)
          .padding(.vertical, 14)
      }
      .buttonStyle(.bordered)
      .tint(thinking ? .red : .blue)
      .padding(.top, 28)
      .accessibilityIdentifier("card-think")
      Spacer()
    }
    .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea())
    .preferredColorScheme(.dark)
    .onAppear {
      if think { thinking = true } else { deal() }
    }
    .task(id: thinking) {
      guard thinking else { return }
      left = Self.thinkSeconds
      while left > 0 {
        try? await Task.sleep(for: .seconds(1))
        if Task.isCancelled { return }  // Never mind
        left -= 1
      }
      thinking = false
      deal()
    }
  }

  private func deal() {
    nonce = CardDeal.nonceAfterTap(at: Date(), nonce: nonce)
    CardStore.set(nonce)
    log.event("ui", ["action": "card_deal", "card": card.label])
  }

  private var ink: Color { card.isRed ? Color(red: 0.8, green: 0.09, blue: 0.13) : Color(white: 0.08) }

  private var face: some View {
    Button(action: deal) {
      ZStack {
        RoundedRectangle(cornerRadius: 18).fill(.white)
        Text(card.suit.rawValue).font(.system(size: 128, weight: .bold))
        corner.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(14)
        corner.rotationEffect(.degrees(180))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(14)
      }
      .foregroundStyle(ink)
      .frame(width: 240, height: 336)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("card-face")
    .accessibilityLabel("Memdeck card \(card.label); tap for another")
  }

  private var corner: some View {
    VStack(spacing: 0) {
      Text(card.rank)
      Text(card.suit.rawValue)
    }
    .font(.system(size: 28, weight: .heavy))
  }

  private var back: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18).fill(.white)
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(red: 0.12, green: 0.23, blue: 0.54))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.58, green: 0.77, blue: 0.99), lineWidth: 2))
        .padding(12)
      VStack(spacing: 8) {
        Text("\(left)").font(.system(size: 96, weight: .heavy)).foregroundStyle(.white)
          .accessibilityIdentifier("card-count")
        Text("think of a card…").foregroundStyle(Color(red: 0.75, green: 0.86, blue: 1.0))
      }
    }
    .frame(width: 240, height: 336)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("card-back")
  }
}
