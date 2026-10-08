// The role of the day on the large widget (#221): the eulogy's eleven roles, in its order, one per local day, so
// each comes up once in any eleven days. Names only: they are Igor's words; the old app's passages are partly
// placeholders. Spec: docs/superpowers/specs/2026-10-08-native-large-widget-design.md

import Foundation

public enum EulogyRoles {
  /// Eulogy order, as the old app's Roles tab has them.
  public static let names = [
    "Dealer of smiles & wonder",
    "Mostly car-free spirit",
    "Disciple of 7 habits",
    "Fit fellow",
    "Emotionally healthy human",
    "Technologist",
    "Professional",
    "Family man",
    "Husband to Tori",
    "Father to Amelia",
    "Father to Zach",
  ]

  /// The role for the local day `date` is in.
  public static func ofDay(_ date: Date, calendar: Calendar = .current) -> String {
    let day = calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: calendar.startOfDay(for: date)).day ?? 0
    let n = names.count
    return names[((day % n) + n) % n]
  }

  /// The next local midnight after `date`: when the role changes.
  public static func nextChange(after date: Date, calendar: Calendar = .current) -> Date {
    calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
  }
}
