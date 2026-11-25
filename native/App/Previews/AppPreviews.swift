//  SwiftUI previews of the screens agents change most (Igor 2026-11-24 "Add previews too"), on PreviewFixtures'
//  offline data. Render one from the command line with `just render-preview`. Debug builds only.

#if DEBUG
  import SwiftUI

  #Preview("Chat list") {
    NavigationStack {
      ChatListView(chat: PreviewFixtures.chat, voice: PreviewFixtures.voice, logger: PreviewFixtures.logger)
    }
  }

  #Preview("Decision card") {
    @Previewable @State var draft = ChatDecisionCard.Draft()
    ChatDecisionCard(
      decisions: PreviewFixtures.chat.decisions, ask: PreviewFixtures.ask, place: "thread", voice: nil,
      logger: PreviewFixtures.logger, draft: $draft, fold: {}
    )
    .padding()
  }

  #Preview("Decisions row and line") {
    List {
      ChatDecisionsRow(count: 3)
      ChatDecisionLine(text: "You decided: Any device, clashes refused out loud")
    }
  }

  #Preview("Home tiles") {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 12) {
        ForEach(HomeRow.all + [HomeRow.settings]) { row in
          TileArt(row: row, size: 88)
            .padding(4)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel(row.title)
        }
      }
      .padding()
    }
  }

  /// On purpose: the list with no Cockpit address, so a reviewer can tell "looks broken" (this) from "is broken".
  #Preview("Chat list, no Cockpit (error on purpose)") {
    NavigationStack {
      ChatListView(chat: PreviewFixtures.brokenChat, voice: PreviewFixtures.voice, logger: PreviewFixtures.logger)
    }
  }
#endif
