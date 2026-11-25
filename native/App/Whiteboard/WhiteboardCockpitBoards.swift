//  Boards from the Cockpit (beta) (spec 2026-11-22-boards-in-the-cockpit-design.md, Trying it before the rollout;
//  stories 1339-1341; cockpit-8kh): a switch in Settings, off by default, and with it on, a *From the Cockpit* section
//  above the iPad's own boards listing the Cockpit store's boards. Off, nothing here asks the Cockpit for anything.
//  Drawing on a Cockpit board (the encoder and `CockpitBoardSync` wired to the canvas) is the next step.

import BugKit
import ContextCore
import SwiftUI

enum WhiteboardCockpitBoards {
  /// The switch, in UserDefaults (a UI test turns it on with `-whiteboard_boards_from_cockpit YES`).
  static let key = "whiteboard_boards_from_cockpit"

  /// Where saves go: reads always come from the chat's Cockpit, but the real store takes no writes until Larry's
  /// slice 1 (`POST /boards/<id>/ops`) lands, so until then saves go only to a fake Cockpit a launch names. Moving
  /// writes to the real Cockpit is this one line: `{ reads in reads }`.
  static let writeAddress: (_ reads: String) -> String? = { _ in LaunchHooks.current.chatURL }
}

@MainActor
final class CockpitBoardsModel: ObservableObject {
  @Published private(set) var rows: [CockpitBoardStore.Row] = []
  @Published private(set) var loaded = false
  @Published private(set) var problem: BugProblem?
  private let cockpit: String
  private let log: SessionLog

  init(cockpit: String, log: SessionLog) {
    self.cockpit = cockpit
    self.log = log
  }

  func refresh(reason: String) async {
    do {
      let (data, response) = try await URLSession.shared.data(for: try CockpitBoardStore.listRequest(cockpit: cockpit))
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard status == 200, let rows = CockpitBoardStore.rows(data) else {
        fail("HTTP \(status)", reason: reason, body: String(data: data.prefix(200), encoding: .utf8) ?? "")
        return
      }
      self.rows = rows
      problem = nil
      loaded = true
      log.event("board_store", ["action": "listed", "reason": reason, "boards": rows.count])
    } catch {
      fail(error.localizedDescription, reason: reason, body: "")
    }
  }

  private func fail(_ error: String, reason: String, body: String) {
    loaded = true
    log.event("board_store", ["action": "list_failed", "reason": reason, "error": error, "cockpit": cockpit])
    problem = BugProblem(
      message: "Cockpit not answering: the boards list didn't load (\(error))",
      context: "WhiteboardListView.cockpitBoards",
      build: "\(BuildInfo.sha) \(BuildInfo.branch)",
      extra: [
        "address": .string(cockpit + "/boards"), "error": .string(error), "reason": .string(reason),
        "body": .string(body),
      ],
      autoFile: false)
  }
}

/// Story 1340: the list's *From the Cockpit* section.
struct CockpitBoardsSection: View {
  @ObservedObject var model: CockpitBoardsModel
  let logger: BugLogger

  var body: some View {
    Section {
      if let problem = model.problem {
        BugProblemView(problem: problem, logger: logger)
      } else if model.loaded, model.rows.isEmpty {
        Text("No boards in the Cockpit yet").foregroundStyle(.secondary)
          .accessibilityIdentifier("cockpit-boards-empty")
      } else if !model.loaded {
        ProgressView()
      }
      ForEach(model.rows) { row in
        HStack {
          Text(row.name.isEmpty ? "Untitled" : row.name)
          Spacer()
          Text(row.rev == 1 ? "1 version" : "\(row.rev) versions").font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cockpit-board-\(row.id)")
      }
    } header: {
      // Not on the Section: an identifier there would replace each row's own.
      Text("From the Cockpit").accessibilityIdentifier("cockpit-boards")
    }
  }
}

/// Story 1339: the switch, in Settings, off by default; an iPhone only views boards, so it isn't offered there.
struct WhiteboardCockpitSettingsSection: View {
  @AppStorage(WhiteboardCockpitBoards.key) private var on = false

  var body: some View {
    if UIDevice.current.userInterfaceIdiom != .phone {
      Section {
        Toggle("Boards from the Cockpit (beta)", isOn: $on)
          .accessibilityIdentifier("cockpit-boards-switch")
      } header: {
        Text("Whiteboard")
      } footer: {
        Text("Lists the Cockpit's boards above your own. For trying the new board store; your boards stay in iCloud.")
      }
    }
  }
}
