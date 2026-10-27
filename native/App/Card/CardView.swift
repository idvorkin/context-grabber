//  The card screen (#219; spec 2026-10-04-swift-native-app-design.md, "Think of a card: the trainer's screen, in
//  the app"): Think a Card Trainer's own phone screen, from its shared ThinkACardUI library. Grabber Native hands it
//  the stack the build bundled, the session log, its settings in the App Group (so Today's hand skips the same easy
//  cards), the trainer's voice clips, and silence during a call. Done, and the shake to report, are this app's.
//  *Drill the stack* (story 220) covers it with the trainer's drill, graded into this app's own ledger.

import BugKit
import SwiftUI
import ThinkACardCore
import ThinkACardUI

extension SessionLog: CardScreenLog {}

struct CardView: View {
  let app: AppModel
  /// True: open with the ask already started, as the home row does.
  let think: Bool
  let onDone: () -> Void

  @State private var session: PromptSession?
  @State private var deck: Deck?
  @State private var drills = false
  @State private var drillMode = StackDrill.Mode.cardToPosition
  @State private var problem: BugProblem?

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.ignoresSafeArea()
      if let session {
        // Grabber Native routes its own links (grabbernative://card?think=1 reopens this screen counting).
        DealScreen(session: session, handlesURLs: false)
          .safeAreaInset(edge: .bottom) {
            Button("Drill the stack") {
              session.stopCount(why: "drill")  // a count left running would deal and speak behind the drill
              drills = true
            }
            .font(.footnote)
            .foregroundStyle(.gray)
            .padding(.bottom, 4)
            .accessibilityIdentifier("card-drill")
          }
          // ponytail: the drill's Stats sheet shows a failed load as plain text, not BugProblemView; it is logged
          // (`ledger_stats` how: failed) for a shake report. The library lets the host present it since v0.3.1
          // (`StackDrillScreen(session:showLedgerFailure:)`); passing that closure is #563.
          // A report from inside the drill names it, not the card under it (Codex on #381).
          .onChange(of: drills, initial: true) { _, open in app.screen = open ? "drill" : "card" }
          .fullScreenCover(isPresented: $drills) {
            if let deck {
              StackDrillScreen(
                session: DrillSession(
                  deck: deck, log: app.log, ledger: GrabberLedger.shared(log: app.log), mode: drillMode,
                  skippingEasy: session.skipsEasyCards)
              )
              // A cover is its own presentation: the app's shake and report sheet do not reach into it (Codex on #381).
              .bugReporting(app.reporter)
            }
          }
      } else if let problem {
        BugProblemView(problem: problem, logger: app.bugLogger).padding().frame(maxHeight: .infinity)
      }
      Button("Done", action: onDone)
        .font(.body.weight(.semibold))
        .foregroundStyle(.white.opacity(0.85))
        .padding()
        .accessibilityIdentifier("card-done")
    }
    .preferredColorScheme(.dark)
    .onAppear(perform: start)
  }

  private func start() {
    guard session == nil, problem == nil else { return }
    switch TrainerDeck.load() {
    case .success(let deck):
      self.deck = deck
      let host = CardScreenHost(
        deck: deck, log: app.log, defaults: TrainerDeck.defaults,
        maySpeak: { [app] in MainActor.assumeIsolated { app.mayTheCardSpeak() } })
      let made = PromptSession(host: host)
      session = made
      if think { made.tap(via: "home") }
      if let mode = app.drillOnOpen {
        app.drillOnOpen = nil
        drillMode = mode
        drills = true
      }
    case .failure(let error):
      app.log.event("card_problem", ["error": error.localizedDescription])
      problem = .grabber(
        error.localizedDescription, context: "CardView.load",
        extra: ["think": .bool(think), "error": .string(String(describing: error))])
    }
  }
}
