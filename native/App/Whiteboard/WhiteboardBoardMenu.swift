//  The board's Board menu: its colour, lines, Tidy overlaps, a real font and who answers a pause. Moved from
//  WhiteboardView.swift into a view of its own so the board's other changes leave it alone while it is open (story 1107,
//  context-grabber-664d).

import ContextCore
import SwiftUI

/// Story 1107: equal while what it shows is, so the board's other changes (Larry's thread looked at every 3 s, a save)
/// don't rebuild it. A rebuilt menu is set on the bar button again, which swaps the open menu's rows for new ones; a tap
/// on a row at that moment was cancelled (and on the iPad simulator the on-screen keyboard rose again, #880).
struct WhiteboardBoardMenu: View, Equatable {
  let model: WhiteboardModel
  let paper: BoardPaper
  let gridOn: Bool
  let ruledOn: Bool
  let lettering: WhiteboardTurn.LetterStyle
  let responder: WhiteboardResponder

  init(model: WhiteboardModel) {
    self.model = model
    paper = model.paper
    gridOn = model.gridOn
    ruledOn = model.ruledOn
    lettering = model.lettering
    responder = model.responder.shown
  }

  static func == (a: Self, b: Self) -> Bool {
    a.model === b.model && a.paper == b.paper && a.gridOn == b.gridOn && a.ruledOn == b.ruledOn
      && a.lettering == b.lettering && a.responder == b.responder
  }

  var body: some View {
    Menu {
      Section("Colour") {
        ForEach(BoardPaper.allCases, id: \.self) { paper in
          Toggle(
            paper.name,
            isOn: Binding(
              get: { model.paper == paper },
              set: { _ in
                model.setPaper(paper)
                model.canvas?.menuChose()
              }))
        }
      }
      Section("Lines") {
        Toggle(
          "Grid lines",
          isOn: Binding(
            get: { model.gridOn },
            set: {
              model.setGrid($0)
              model.canvas?.menuChose()
            }))
        Toggle(
          "Ruled lines",
          isOn: Binding(
            get: { model.ruledOn },
            set: {
              model.setRuled($0)
              model.canvas?.menuChose()
            }))
      }
      // Story 896: kept labels moved off ink. One row, as the Board menu has room for no more (#848); Keep all is in
      // the note's line, beside the count of marks to keep (story 895).
      // Story 1240: no review row; reviews run on idle and close only (Igor, 2026-11-24).
      Button("Tidy overlaps") {
        model.tidyOverlaps()
        model.canvas?.menuChose()
      }
      .accessibilityIdentifier("whiteboard-tidy")
      // Stories 1361-1363: send the board to the Cockpit (beta switch only).
      WhiteboardMirrorRow(model: model)
      // Story 1315 (#1387): the questions archived off the board, to read or reopen; only while there are some.
      WhiteboardArchivedQuestionsRow(questions: model.questions)
      // #950 (stories 1056, 1057): how the board letters its text. One row, a switch, as the menu has room for no
      // more (#848), and a submenu's rows close before a tap reaches them while the board's bar redraws.
      Toggle(
        "Real font",
        isOn: Binding(
          get: { model.lettering == .font },
          set: {
            model.setLettering($0 ? .font : .single)
            model.canvas?.menuChose()
          })
      )
      .accessibilityIdentifier("whiteboard-lettering")
      // Story 659: who answers a pause, the board's own on the Cockpit. A submenu, not a section: three more rows
      // make the iPad show the menu as a full-height list that stays up after a pick (#848).
      Menu {
        ForEach(WhiteboardResponder.allCases, id: \.self) { responder in
          Toggle(
            responder.name,
            isOn: Binding(
              get: { model.responder.shown == responder },
              set: { _ in
                model.setResponder(responder)
                model.canvas?.menuChose()
              }))
        }
      } label: {
        Label("Responder: \(model.responder.shown.name)", systemImage: "person.wave.2")
      }
      // Story 1171: a UI test gives the board to Haiku here.
      .accessibilityIdentifier("whiteboard-responder")
    } label: {
      Label("Board", systemImage: "paintpalette")
    }
    // Its colour, lines and a real font (#950), for VoiceOver and the UI test, in the label: a toolbar button's
    // accessibility value never reaches either.
    .accessibilityLabel(
      "Board, \(model.paper.name)\(model.gridOn ? ", grid on" : model.ruledOn ? ", ruled lines on" : "")"
        + (model.lettering == .font ? ", real font" : "")
    )
    .accessibilityIdentifier("whiteboard-board")
  }
}
