//  Sending a board to the Cockpit, the mirror (stories 1361-1363): the board's side of `WhiteboardStoreMirror`. After a
//  save, a mirrored board's ink also goes to the Cockpit's copy; the board menu's row sends it the first time.

import ContextCore
import SwiftUI

extension WhiteboardModel {
  var storeMirror: WhiteboardStoreMirror { .of(board: board.id, cockpit: cockpit, log: log) }

  /// The name the board shows (its title in the index).
  var mirrorName: String { store.index.board(board.id)?.title ?? board.title }

  /// Called after each save that wrote the drawing.
  func mirrorSaved() {
    guard WhiteboardStoreMirror.betaOn else { return }
    storeMirror.saved(drawing: drawing, name: mirrorName, paper: paper.rawValue, ruled: ruledOn)
  }

  /// Story 1361: the menu's *Send this board to the Cockpit*.
  func sendToCockpit() {
    if dirty { save(.background) }
    storeMirror.send(drawing: drawing, name: mirrorName, paper: paper.rawValue, ruled: ruledOn)
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
