//  Stories 1077, 1614: the speakers' colours. Larry's purple is the Cockpit's (#7a4cc3 light, #b18ae0 dark, its story
//  322), so he reads the same on the web, the call screen and chat.

import ContextCore
import SwiftUI
import UIKit

extension Color {
  /// Larry's purple.
  static let larry = Color(
    UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0xB1 / 255, green: 0x8A / 255, blue: 0xE0 / 255, alpha: 1)
        : UIColor(red: 0x7A / 255, green: 0x4C / 255, blue: 0xC3 / 255, alpha: 1)
    })

  /// A speaker's avatar: Larry purple, Tony teal, a skill indigo (as since #632).
  static func speaker(_ tone: ChatSpeaker.Tone) -> Color {
    switch tone {
    case .agent: return .larry
    case .voice: return .teal
    case .skill, .principal: return .indigo
    }
  }
}
