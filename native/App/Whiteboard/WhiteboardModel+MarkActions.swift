//  The buttons beside a chosen mark come from Larry's reply (spec 2026-11-01-whiteboard-shapes-design.md, *Larry
//  chooses the buttons beside his reply*; stories 1352, 1353, #1525).

import ContextCore
import SwiftUI

extension WhiteboardModel {
  /// The buttons beside the chosen marks, in the reply's order: Keep and Dismiss for a reply that names none, for one
  /// this board no longer remembers, or for Claude's ghosts.
  var chosenOffers: [WhiteboardMarkActions.Offer] {
    guard let first = chosenMarks.first, first.who == .larry, let reply = WhiteboardMarks.reply(of: first.id) else {
      return WhiteboardMarkActions.standard
    }
    return replyOffers[reply] ?? WhiteboardMarkActions.standard
  }
}
