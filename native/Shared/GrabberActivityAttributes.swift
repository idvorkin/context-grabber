//  The Live Activity as both sides see it (spec 2026-10-04-native-live-activity-design.md): compiled into the app
//  (which starts and moves it) and the widget extension (which draws it). One shape for every screen that has a
//  card; plain values only, so the extension needs nothing else from the app.

import ActivityKit
import Foundation

struct GrabberActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String
    var subtitle: String
    var compactLabel: String
    /// A colour token: red / green / amber / white.
    var accent: String
    /// When the step ends; the countdown runs to it on the phone's clock. Unused when paused or finished.
    var endsAt: Date
    var stepSeconds: Int
    /// The still time shown when paused.
    var secondsLeft: Int
    var paused: Bool
    var finished: Bool
  }

  /// gymTimer / breathe: which screen the card belongs to.
  var kind: String
}
