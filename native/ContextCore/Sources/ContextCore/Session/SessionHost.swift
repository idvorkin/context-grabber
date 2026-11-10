//  What a Gym Timer workout or a breathing session needs from the phone, besides its own sound: the clock, a
//  one-shot timer, the lit screen, the lock-screen card, VoiceOver and the session log. TimerSession and
//  BreathSession decide when each is taken and let go; the app's host only carries it out, so a test drives
//  them with a fake and a clock moved by hand, as CallSession's tests do with FakeAudio.

import Foundation

public protocol SessionHost: AnyObject {
  /// Seconds since 1970 on the wall clock.
  var now: Double { get }
  /// Look every `seconds` until `stopClock`. One clock per session: starting it again replaces the old one.
  func startClock(every seconds: Double, _ look: @escaping () -> Void)
  func stopClock()
  /// Run `block` after `ms` milliseconds; the returned closure cancels it (the duck window's `Schedule`).
  func after(_ ms: Int, _ block: @escaping () -> Void) -> () -> Void
  /// The phone's one keep-awake switch. Shared with the call and the Cockpit, so read it rather than assume it.
  var keepAwake: Bool { get set }
  /// The lock-screen card for `kind`: nil content ends it (LiveActivityController.sync).
  func syncCard(_ content: LiveActivityContent?, kind: LiveActivityKind, stepEndsAt: Double?)
  /// `kind`'s card goes now, finished or not.
  func endCard(_ kind: LiveActivityKind, reason: String)
  /// Said by VoiceOver, when it is running.
  func announce(_ text: String)
  func log(_ type: String, _ fields: [String: Any])
}
