//  The home screen's launchers (story 147): one entry per row, in the default order. A new row is one more
//  entry; HomeLayout shows it at the end for anyone who already arranged theirs.

import SwiftUI

struct HomeRow: Identifiable {
  /// What the remembered order and the log call it; never change one, or the row loses its place.
  let id: String
  let title: String
  let icon: String
  let open: @MainActor (AppModel) -> Void

  static let all: [HomeRow] = [
    HomeRow(id: "call", title: "Call Larry", icon: "phone.fill") { $0.openCall(from: "home") },
    HomeRow(id: "today", title: "Today", icon: "heart.text.square") { $0.openToday(from: "home") },
    HomeRow(id: "gym_timer", title: "Gym Timer", icon: "timer") { $0.openGymTimer(from: "home") },
    HomeRow(id: "breathe", title: "Box breathing", icon: "wind") { $0.openBreathe(from: "home") },
    HomeRow(id: "places", title: "Places", icon: "map") { $0.openPlaces(from: "home") },
    HomeRow(id: "think_a_card", title: "Think of a card", icon: "suit.spade.fill") { $0.openThinkACard(from: "home") },
    HomeRow(id: "cockpit", title: "Cockpit", icon: "gauge.with.dots.needle.67percent") {
      $0.openCockpit(from: "home")
    },
  ]

  static let ids = all.map(\.id)
  private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
  static func row(_ id: String) -> HomeRow? { byID[id] }
}
