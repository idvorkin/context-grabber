//  The card screen (#219; spec 2026-10-04-swift-native-app-design.md, "Think of a card: the trainer's screen, in
//  the app"): Think a Card Trainer's own phone screen, from its shared ThinkACardUI library. Grabber Native hands it
//  the stack the build bundled, the session log, its settings in the App Group (so Today's hand skips the same easy
//  cards), the trainer's voice clips, and silence during a call. Done, and the shake to report, are this app's.

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
  @State private var problem: MirrorProblem?

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.ignoresSafeArea()
      if let session {
        // Grabber Native routes its own links (grabbernative://card?think=1 reopens this screen counting).
        DealScreen(session: session, handlesURLs: false)
      } else if let problem {
        ProblemView(problem: problem).padding().frame(maxHeight: .infinity)
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
      let host = CardScreenHost(
        deck: deck, log: app.log, defaults: TrainerDeck.defaults,
        maySpeak: { [app] in MainActor.assumeIsolated { app.mayTheCardSpeak() } })
      let made = PromptSession(host: host)
      session = made
      if think { made.tap(via: "home") }
    case .failure(let error):
      app.log.event("card_problem", ["error": error.localizedDescription])
      problem = MirrorProblem(
        message: error.localizedDescription, context: "CardView.load",
        extra: ["think": think ? "yes" : "no", "error": String(describing: error)])
    }
  }
}
