//  The home screen's launchers (story 147): one entry per row, in the default order. A new row is one more
//  entry; HomeLayout shows it at the end for anyone who already arranged theirs.

import ContextCore
import SwiftUI

struct HomeRow: Identifiable {
  /// What the remembered order and the log call it; never change one, or the row loses its place.
  let id: String
  let title: String
  let icon: String
  /// The icon's square, the one colour a launcher carries; the name stays in the text colour.
  let color: Color
  /// The name in half a line (#225), where the full one would be cut off.
  var short: String { Self.shortNames[id] ?? title }
  private static let shortNames = ["exercise_analyzer": "Analyzer", "workout_supermix": "Supermix"]
  let open: @MainActor (AppModel) -> Void

  static let all: [HomeRow] = [
    HomeRow(id: "call", title: "Call Larry", icon: "phone.fill", color: .green) { $0.openCall(from: "home") },
    HomeRow(id: "today", title: "Today", icon: "heart.text.square", color: .pink) { $0.openToday(from: "home") },
    // #236: not a launcher but the strip under the Today card; a row here so the cog can hide it.
    HomeRow(id: HomeLayout.dailyStrip, title: "Daily strip", icon: "checklist", color: .green) { _ in },
    HomeRow(id: "gym_timer", title: "Gym Timer", icon: "timer", color: Color(red: 1.0, green: 0.23, blue: 0.19)) { $0.openGymTimer(from: "home") },
    HomeRow(id: "breathe", title: "Box breathing", icon: "wind", color: .teal) { $0.openBreathe(from: "home") },
    HomeRow(id: "places", title: "Places", icon: "map", color: .indigo) { $0.openPlaces(from: "home") },
    HomeRow(id: "think_a_card", title: "Think of a card", icon: "suit.spade.fill", color: .purple) { $0.openCard(think: true, from: "home") },
    HomeRow(id: "exercise_analyzer", title: "Exercise Analyzer", icon: "figure.strengthtraining.traditional", color: .orange) {
      $0.openExerciseAnalyzer(from: "home")
    },
    // #220: runs Igor's own shortcut, so YouTube Music plays the mix.
    HomeRow(id: "workout_supermix", title: "Workout Supermix", icon: "music.note.list", color: Color(red: 1.0, green: 0.0, blue: 0.2)) {
      $0.openWorkoutSupermix(from: "home")
    },
    HomeRow(id: "cockpit", title: "Cockpit", icon: "gauge.with.dots.needle.67percent", color: .blue) {
      $0.openCockpit(from: "home")
    },
    // Story 137: the blog's daily three.
    HomeRow(id: "eulogy_song", title: "Eulogy song", icon: "music.note", color: .brown) { $0.playEulogySong(from: "home") },
    HomeRow(id: "eulogy", title: "Eulogy", icon: "book", color: .brown) { $0.openBlog(BlogLinks.eulogy, action: "open_eulogy", from: "home") },
    HomeRow(id: "recent", title: "Recent", icon: "clock.arrow.circlepath", color: .gray) {
      $0.openBlog(BlogLinks.recent, action: "open_recent", from: "home")
    },
  ]

  static let ids = all.map(\.id)
  private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
  static func row(_ id: String) -> HomeRow? { byID[id] }
}

/// A launcher's icon: its glyph in white on a small rounded square of its colour, as Settings draws them.
struct LauncherIcon: View {
  let row: HomeRow
  var size: CGFloat = 28

  var body: some View {
    Image(systemName: row.icon)
      .font(.system(size: size * 0.52, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(row.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
      .accessibilityHidden(true)
  }
}
