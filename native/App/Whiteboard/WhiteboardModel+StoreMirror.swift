//  Sending a board to the Cockpit, the mirror (stories 1361-1363): the board's side of `WhiteboardStoreMirror`. After a
//  save, a mirrored board's ink also goes to the Cockpit's copy; the board menu's row sends it the first time.

import ContextCore
import SwiftUI

extension WhiteboardModel {
  var storeMirror: WhiteboardStoreMirror { .of(board: board.id, cockpit: cockpit, log: log) }

  /// The name the board shows (its title in the index).
  var mirrorName: String { store.index.board(board.id)?.title ?? board.title }

  /// What the mirror sends for the board as it is now: the ink, and (story 1368) the meaning with each stroke's names.
  /// The names come from the per-stroke cache (#1527), so this is cheap on the main thread.
  var mirrorJob: WhiteboardStoreMirror.Job {
    WhiteboardStoreMirror.Job(
      drawing: drawing, name: mirrorName, paper: paper.rawValue, ruled: ruledOn, meaning: opLedger.meaning,
      names: opStrokes(drawing.strokes).strokes.map(\.ids))
  }

  /// Called after each save that wrote the drawing or only its meaning (a fold, a header, a card).
  func mirrorSaved() {
    guard WhiteboardStoreMirror.betaOn, storeMirror.mirrored else { return }
    storeMirror.saved(mirrorJob)
  }

  /// Story 1361: the menu's *Send this board to the Cockpit*.
  func sendToCockpit() {
    if dirty { save(.background) }
    storeMirror.send(mirrorJob)
  }
}

/// Stories 1361 and 1363: the Board menu's row. Shown only with the beta switch on; dimmed, saying why, until the
/// Cockpit's backup is live (a *Scratch…* board can be sent before that).
struct WhiteboardMirrorRow: View {
  let model: WhiteboardModel
  @ObservedObject var mirror: WhiteboardStoreMirror
  /// Watched so a rename is seen here: the Board menu itself is kept from rebuilding (story 1107).
  @ObservedObject var store: WhiteboardStore
  @AppStorage(WhiteboardCockpitBoards.key) private var betaOn = false

  init(model: WhiteboardModel) {
    self.model = model
    mirror = model.storeMirror
    store = model.store
  }

  var body: some View {
    if betaOn {
      if mirror.mirrored {
        Text(mirror.line ?? "In the Cockpit").accessibilityIdentifier("whiteboard-mirror-status")
      } else if CockpitBoardMirror.allowed(name: store.index.board(model.board.id)?.title ?? model.mirrorName) {
        if mirror.problem != nil, let line = mirror.line {
          Text(line).accessibilityIdentifier("whiteboard-mirror-status")
        }
        Button("Send this board to the Cockpit") { model.sendToCockpit() }
          .accessibilityIdentifier("whiteboard-mirror-send")
      } else {
        Button("Send this board to the Cockpit\nWaiting for the Cockpit's backup") {}
          .disabled(true)
          .accessibilityIdentifier("whiteboard-mirror-waiting")
      }
    }
  }
}
