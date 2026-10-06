//  What's new (story 148): the last month's changes by day, newest first, as the build found them in git.

import ContextCore
import SwiftUI

struct WhatsNewView: View {
  let feed: WhatsNewFeed?

  var body: some View {
    List {
      if let days = feed?.days, !days.isEmpty {
        ForEach(days, id: \.day) { day in
          Section(WhatsNew.label(day: day.day, style: .long)) {
            ForEach(day.items, id: \.sha) { item in
              VStack(alignment: .leading, spacing: 3) {
                Text(item.text)
                Text(item.caption).font(.caption).foregroundStyle(.secondary)
              }
              .padding(.vertical, 2)
            }
          }
        }
      } else {
        Text("Nothing new in the last thirty days.").foregroundStyle(.secondary)
      }
    }
    .navigationTitle("What's new")
    .accessibilityIdentifier("whats-new")
  }
}

/// The home screen's one-line pointer at it.
struct WhatsNewRow: View {
  let feed: WhatsNewFeed?

  var body: some View {
    (Text(Image(systemName: "sparkles")) + Text("  What's new").fontWeight(.semibold)
      + Text(" · \(WhatsNew.homeLine(feed))").foregroundStyle(.secondary))
      .font(.subheadline)
      .lineLimit(2)
  }
}
