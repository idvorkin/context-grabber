//  What's new (story 148): the last month's changes by day, newest first, as the build found them in git.

import ContextCore
import SwiftUI

struct WhatsNewView: View {
  let feed: WhatsNewFeed?
  let log: SessionLog
  @Environment(\.openURL) private var openURL

  var body: some View {
    List {
      if let days = feed?.days, !days.isEmpty {
        ForEach(days, id: \.day) { day in
          Section(WhatsNew.label(day: day.day, style: .long)) {
            ForEach(day.items, id: \.sha) { item in
              // #232: each change opens its story.
              if let link = item.link.flatMap(URL.init(string:)) {
                Button {
                  log.event("ui", ["action": "open_story", "story": item.story, "url": link.absoluteString])
                  openURL(link)
                } label: {
                  HStack {
                    ChangeLine(item: item)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                  }
                }
                .tint(.primary)
                .accessibilityIdentifier("whats-new-story-\(item.story)")
              } else {
                ChangeLine(item: item)
              }
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

private struct ChangeLine: View {
  let item: WhatsNewItem

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(item.text)
      Text(item.caption).font(.caption).foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
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
