//  The memdeck card, big (stories 129, 133): one playing card filling the screen, tap for another, *Think of a
//  card* turns it face down for a count of five. The face is drawn here — corner indices, the pips laid out as a
//  real deck lays them, a framed letter for the court cards — so no image assets.

import ContextCore
import SwiftUI

private let table = Color(red: 0.059, green: 0.090, blue: 0.165)
private let accent = Color(red: 0.376, green: 0.647, blue: 0.980)
private let stop = Color(red: 0.973, green: 0.443, blue: 0.443)
private let cardRed = Color(red: 0.78, green: 0.09, blue: 0.13)
private let cardBlack = Color(red: 0.08, green: 0.08, blue: 0.09)
private let paper = Color(red: 0.995, green: 0.99, blue: 0.975)
private let backBlue = Color(red: 0.118, green: 0.227, blue: 0.541)

struct CardLaunch: Equatable {
  var think = false
  /// The `never_mind` hook: press *Never mind* this long into the count.
  var neverMindAfter: Duration?
}

struct CardView: View {
  @StateObject private var model: CardModel
  private let launch: CardLaunch
  private let onExit: () -> Void

  init(app: AppModel, launch: CardLaunch, onExit: @escaping () -> Void) {
    _model = StateObject(wrappedValue: CardModel(log: app.log, database: app.database))
    self.launch = launch
    self.onExit = onExit
  }

  var body: some View {
    GeometryReader { geo in
      let width = min(geo.size.width - 56, (geo.size.height - 250) * 5 / 7)
      VStack(spacing: 0) {
        HStack {
          Button("Done", action: onExit).font(.system(size: 16, weight: .semibold)).foregroundStyle(accent)
          Spacer()
        }
        .overlay { Text("Card").font(.system(size: 18, weight: .bold)).foregroundStyle(.white) }
        .padding(.horizontal, 16).padding(.vertical, 12)

        Spacer(minLength: 12)
        ZStack {
          if model.thinking {
            CardBack(left: model.left)
              .transition(flip(from: -90))
          } else {
            Button(action: model.tapCard) { CardFace(card: model.card) }
              .buttonStyle(PressedCard())
              .id(model.card)
              .transition(flip(from: 90))
              .accessibilityLabel("\(model.card.label); tap for another")
              .accessibilityIdentifier("card-face")
          }
        }
        .frame(width: width, height: width * 7 / 5)
        .animation(.easeInOut(duration: 0.28), value: model.thinking)
        .animation(.easeInOut(duration: 0.22), value: model.card)

        Text(model.thinking ? "shuffle…" : "tap the card for another")
          .font(.system(size: 14)).foregroundStyle(Color(white: 0.45))
          .padding(.top, 18)
        Spacer(minLength: 12)

        Button(action: model.toggleThinking) {
          Text(model.thinking ? "Never mind" : "Think of a card")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(model.thinking ? stop : accent)
            .frame(minWidth: 220).padding(.vertical, 15)
            .background((model.thinking ? stop : accent).opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityIdentifier("card-think")
        .padding(.bottom, 28)
      }
      .frame(maxWidth: .infinity)
    }
    .background(table.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .onAppear { model.appear(think: launch.think, neverMindAfter: launch.neverMindAfter) }
    .onDisappear { model.disappear() }
  }

  /// A turn about the card's vertical axis: the leaving side goes edge-on as the arriving side comes round.
  private func flip(from angle: Double) -> AnyTransition {
    .asymmetric(
      insertion: .modifier(active: Turned(angle: angle), identity: Turned(angle: 0)),
      removal: .modifier(active: Turned(angle: -angle), identity: Turned(angle: 0)))
  }
}

private struct Turned: ViewModifier {
  let angle: Double
  func body(content: Content) -> some View {
    content
      .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
      .opacity(abs(angle) >= 90 ? 0 : 1)
  }
}

private struct PressedCard: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.scaleEffect(configuration.isPressed ? 0.975 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

// MARK: - the face

struct CardFace: View {
  let card: PlayingCard

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let ink = card.isRed ? cardRed : cardBlack
      ZStack {
        RoundedRectangle(cornerRadius: w * 0.07)
          .fill(LinearGradient(colors: [paper, Color(white: 0.94)], startPoint: .top, endPoint: .bottom))
          .overlay(RoundedRectangle(cornerRadius: w * 0.07).strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
          .shadow(color: .black.opacity(0.45), radius: 18, y: 10)

        // The middle: inside the corner indices.
        let inner = CGRect(x: w * 0.2, y: h * 0.12, width: w * 0.6, height: h * 0.76)
        if card.isFace {
          CourtPanel(card: card, ink: ink).frame(width: inner.width, height: inner.height)
            .position(x: inner.midX, y: inner.midY)
        } else {
          ForEach(Array(Pips.layout(rank: card.rank).enumerated()), id: \.offset) { _, pip in
            SuitShape(suit: card.suit, ink: ink)
              .frame(width: w * pip.size, height: w * pip.size)
              .rotationEffect(.degrees(pip.y > 0.5 ? 180 : 0))
              .position(x: inner.minX + inner.width * pip.x, y: inner.minY + inner.height * pip.y)
          }
        }

        CornerIndex(card: card, ink: ink, w: w).position(x: w * 0.1, y: h * 0.1)
        CornerIndex(card: card, ink: ink, w: w).rotationEffect(.degrees(180)).position(x: w * 0.9, y: h * 0.9)
      }
    }
  }
}

private struct CornerIndex: View {
  let card: PlayingCard
  let ink: Color
  let w: CGFloat

  var body: some View {
    VStack(spacing: w * 0.004) {
      Text(card.rank)
        .font(.system(size: w * (card.rank == "10" ? 0.105 : 0.12), weight: .bold, design: .serif))
        .tracking(card.rank == "10" ? -w * 0.008 : 0)
        .fixedSize()
      SuitShape(suit: card.suit, ink: ink).frame(width: w * 0.075, height: w * 0.075)
    }
    .foregroundStyle(ink)
  }
}

/// A suit pip: SF Symbols' suits, which are proper shapes rather than a font's glyphs.
struct SuitShape: View {
  let suit: PlayingCard.Suit
  let ink: Color

  var body: some View {
    Image(systemName: Self.symbol(suit)).resizable().scaledToFit().foregroundStyle(ink)
  }

  static func symbol(_ suit: PlayingCard.Suit) -> String {
    switch suit {
    case .spades: "suit.spade.fill"
    case .hearts: "suit.heart.fill"
    case .diamonds: "suit.diamond.fill"
    case .clubs: "suit.club.fill"
    }
  }
}

/// A jack, queen or king: a framed panel with the letter large, a suit above and (turned) below.
private struct CourtPanel: View {
  let card: PlayingCard
  let ink: Color

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      ZStack {
        RoundedRectangle(cornerRadius: w * 0.06)
          .fill(ink.opacity(0.06))
          .overlay(RoundedRectangle(cornerRadius: w * 0.06).strokeBorder(ink.opacity(0.55), lineWidth: 2))
        RoundedRectangle(cornerRadius: w * 0.04)
          .strokeBorder(ink.opacity(0.25), lineWidth: 1)
          .padding(w * 0.045)
        Text(card.rank)
          .font(.system(size: w * 0.72, weight: .bold, design: .serif))
          .foregroundStyle(ink)
        SuitShape(suit: card.suit, ink: ink).frame(width: w * 0.26, height: w * 0.26)
          .position(x: w / 2, y: h * 0.14)
        SuitShape(suit: card.suit, ink: ink).frame(width: w * 0.26, height: w * 0.26)
          .rotationEffect(.degrees(180))
          .position(x: w / 2, y: h * 0.86)
      }
    }
  }
}

/// Where a deck puts the pips, in the middle panel's unit square, and how big (as a share of the card's width).
enum Pips {
  struct Pip {
    let x: Double
    let y: Double
    let size: Double
  }

  static func layout(rank: String) -> [Pip] {
    let l = 0.0, m = 0.5, r = 1.0
    let pips: [(Double, Double)]
    switch rank {
    case "A": return [Pip(x: m, y: m, size: 0.42)]
    case "2": pips = [(m, 0), (m, 1)]
    case "3": pips = [(m, 0), (m, 0.5), (m, 1)]
    case "4": pips = [(l, 0), (r, 0), (l, 1), (r, 1)]
    case "5": pips = [(l, 0), (r, 0), (m, 0.5), (l, 1), (r, 1)]
    case "6": pips = [(l, 0), (r, 0), (l, 0.5), (r, 0.5), (l, 1), (r, 1)]
    case "7": pips = [(l, 0), (r, 0), (m, 0.25), (l, 0.5), (r, 0.5), (l, 1), (r, 1)]
    case "8": pips = [(l, 0), (r, 0), (m, 0.25), (l, 0.5), (r, 0.5), (m, 0.75), (l, 1), (r, 1)]
    case "9":
      pips = [(l, 0), (r, 0), (l, 1 / 3.0), (r, 1 / 3.0), (m, 0.5), (l, 2 / 3.0), (r, 2 / 3.0), (l, 1), (r, 1)]
    default:  // 10
      pips = [
        (l, 0), (r, 0), (m, 1 / 6.0), (l, 1 / 3.0), (r, 1 / 3.0), (l, 2 / 3.0), (r, 2 / 3.0), (m, 5 / 6.0), (l, 1), (r, 1),
      ]
    }
    // Pips sit on the panel's edges; pull them in by half a pip so none touches the corner indices.
    return pips.map { Pip(x: 0.1 + $0.0 * 0.8, y: 0.06 + $0.1 * 0.88, size: 0.15) }
  }
}

// MARK: - the back

private struct CardBack: View {
  let left: Int

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      ZStack {
        RoundedRectangle(cornerRadius: w * 0.07).fill(paper)
          .overlay(RoundedRectangle(cornerRadius: w * 0.07).strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
          .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
        ZStack {
          backBlue
          Lattice().stroke(Color.white.opacity(0.16), lineWidth: 1.2)
          RoundedRectangle(cornerRadius: w * 0.035).strokeBorder(Color.white.opacity(0.55), lineWidth: 2)
            .padding(w * 0.03)
          VStack(spacing: w * 0.02) {
            Text("\(left)")
              .font(.system(size: w * 0.36, weight: .heavy, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.white)
              .contentTransition(.numericText(countsDown: true))
              .animation(.snappy, value: left)
            Text("think of a card…")
              .font(.system(size: w * 0.06, weight: .medium))
              .foregroundStyle(Color(red: 0.75, green: 0.86, blue: 1))
          }
          .padding(.vertical, w * 0.06).padding(.horizontal, w * 0.1)
          .background(backBlue.opacity(0.92), in: RoundedRectangle(cornerRadius: w * 0.06))
          .overlay(RoundedRectangle(cornerRadius: w * 0.06).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        }
        .clipShape(RoundedRectangle(cornerRadius: w * 0.045))
        .padding(w * 0.045)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Think of a card; \(left) seconds")
      .accessibilityIdentifier("card-back")
    }
  }
}

/// The back's diamond lattice.
private struct Lattice: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    let step = rect.width / 9
    var x = -rect.height
    while x < rect.width + rect.height {
      p.move(to: CGPoint(x: x, y: rect.minY))
      p.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
      p.move(to: CGPoint(x: x + rect.height, y: rect.minY))
      p.addLine(to: CGPoint(x: x, y: rect.maxY))
      x += step
    }
    return p
  }
}
