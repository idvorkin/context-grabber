//  Links for Shortcuts (story 135): every link the app answers to, a line saying what it does, and Copy, for the
//  surfaces that want a URL (the Action Button, a bookmark, another app). The actions are in Shortcuts too.

import ContextCore
import SwiftUI
import UIKit

struct LinksView: View {
  let log: SessionLog
  @State private var copied: String?

  var body: some View {
    List {
      Section {
        ForEach(AppLink.catalog, id: \.link) { entry in
          HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
              Text(entry.summary).font(.subheadline)
              Text(entry.link).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer(minLength: 4)
            Button(copied == entry.link ? "Copied" : "Copy") { copy(entry.link) }
              .buttonStyle(.bordered)
              .controlSize(.small)
              .accessibilityIdentifier("copy-\(entry.link)")
          }
        }
      } footer: {
        Text(
          "The same things are actions in the Shortcuts app under Grabber Native: Start Gym Timer, Start Box "
            + "Breathing, Call Larry, Open Today, Open Places, Open Cockpit. Until Grabber Native replaces Context "
            + "Grabber the scheme is grabbernative://; it becomes grabber:// then, and these keep working.")
      }
    }
    .navigationTitle("Links for Shortcuts")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func copy(_ link: String) {
    UIPasteboard.general.string = link
    log.event("ui", ["action": "copy_link", "link": link])
    copied = link
    Task {
      try? await Task.sleep(for: .seconds(1.5))
      if copied == link { copied = nil }
    }
  }
}
