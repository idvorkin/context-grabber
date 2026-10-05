//  The app's one Live Activity (spec 2026-10-04-native-live-activity-design.md): the Gym Timer (story 106) and Box
//  breathing (story 166) each feed it what their card should say — ContextCore's `LiveActivityContent` — whenever
//  their state changes. It diffs on the content's key and talks to ActivityKit: a request when a session starts, a
//  push at each step, pause and resume, an end at the finish (shown a few minutes more), and an end at once on
//  RESET, Back or leaving the screen. One card at a time: a card for one screen ends the other's. Every request,
//  push and end is a `live_activity` event.

import ActivityKit
import ContextCore
import Foundation

@MainActor
final class LiveActivityController {
  private let log: SessionLog
  private var activity: Activity<GrabberActivityAttributes>?
  private var kind: LiveActivityKind?
  /// Ended at the finish but still on the lock screen for a few minutes; RESET, Back, leaving or a new start take
  /// it down at once.
  private var finishedCard: (activity: Activity<GrabberActivityAttributes>, kind: LiveActivityKind)?
  private var lastKey: String?
  /// ActivityKit's update and end are async: each waits for the one before, so the card never moves backwards.
  private var chain: Task<Void, Never>?
  /// Kinds whose card could not start (Live Activities off, or the request refused): said once, and not asked
  /// again until that screen's next session, which begins in front of Igor rather than from the background.
  private var declined: Set<LiveActivityKind> = []
  /// How long a finished card stays on the lock screen.
  private static let finishedFor: TimeInterval = 4 * 60

  init(log: SessionLog) {
    self.log = log
  }

  /// A card left by a launch that was killed mid-session no longer counts true: the app calls this at launch.
  static func endLeftovers(log: SessionLog, except: String? = nil) {
    for leftover in Activity<GrabberActivityAttributes>.activities where leftover.id != except {
      Task {
        await leftover.end(nil, dismissalPolicy: .immediate)
        log.event(
          "live_activity", ["action": "end", "reason": "leftover", "kind": leftover.attributes.kind, "ok": true])
      }
    }
  }

  /// `kind`'s state changed: push its card if what it says changed. nil content ends `kind`'s card at once (only
  /// that screen's: the other screen's card is not this screen's to end). `stepEndsAt` is the exact end of the
  /// step on the wall clock, nil when paused or finished.
  func sync(_ content: LiveActivityContent?, kind: LiveActivityKind, stepEndsAt: Double?) {
    guard let content else {
      if self.kind == kind || finishedCard?.kind == kind { end(kind, reason: "reset") }
      return
    }
    let key = "\(kind.rawValue)|\(content.key)"
    guard key != lastKey else { return }
    lastKey = key
    guard !declined.contains(kind) else {
      if content.finished { declined.remove(kind) }
      return
    }
    let endsAt =
      stepEndsAt.map { Date(timeIntervalSince1970: $0) } ?? Date().addingTimeInterval(TimeInterval(content.secondsLeft))
    let state = GrabberActivityAttributes.ContentState(
      title: content.title, subtitle: content.subtitle, compactLabel: content.compactLabel,
      accent: content.accent.rawValue, endsAt: endsAt, stepSeconds: content.stepSeconds,
      secondsLeft: content.secondsLeft, paused: content.paused, finished: content.finished)
    // A running card goes stale a minute after its step should have ended: the app has stopped moving it.
    let staleAt = content.paused || content.finished ? nil : endsAt.addingTimeInterval(60)
    let fields: [String: Any] = [
      "kind": kind.rawValue, "title": content.title, "subtitle": content.subtitle, "seconds": content.secondsLeft,
    ]

    if let activity, self.kind != kind {
      // The other screen's card: one at a time.
      self.activity = nil
      enqueueEnd(activity, reason: "replaced", kind: self.kind)
    }
    guard let activity else {
      if content.finished { return }  // finished before a card was ever shown: nothing to say "done" on
      let finishedId = finishedCard?.activity.id
      dismissFinished(reason: "restart")
      start(state, kind: kind, staleAt: staleAt, fields: fields, finishedId: finishedId)
      return
    }
    if content.finished {
      self.activity = nil
      finishedCard = (activity, kind)
      enqueue {
        await activity.end(
          ActivityContent(state: state, staleDate: nil),
          dismissalPolicy: .after(Date().addingTimeInterval(Self.finishedFor)))
        self.log.event("live_activity", fields.merging(["action": "end", "reason": "finished", "ok": true]) { $1 })
      }
      return
    }
    enqueue {
      await activity.update(ActivityContent(state: state, staleDate: staleAt))
      // Swiped off the lock screen, or ended by iOS: the push went nowhere.
      let live = activity.activityState == .active
      var event = fields.merging(["action": "update", "ok": live]) { $1 }
      if !live { event["message"] = "activity is \(activity.activityState)" }
      self.log.event("live_activity", event)
    }
  }

  /// RESET, Back, or leaving the screen: `kind`'s card goes now, finished or not.
  func end(_ kind: LiveActivityKind, reason: String) {
    if finishedCard?.kind == kind { dismissFinished(reason: reason) }
    declined.remove(kind)
    guard self.kind == kind else { return }
    lastKey = nil
    self.kind = nil
    guard let activity else { return }
    self.activity = nil
    enqueueEnd(activity, reason: reason, kind: kind)
  }

  private func start(
    _ state: GrabberActivityAttributes.ContentState, kind: LiveActivityKind, staleAt: Date?, fields: [String: Any],
    finishedId: String?
  ) {
    self.kind = kind
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      declined.insert(kind)
      log.event(
        "live_activity",
        ["action": "unavailable", "kind": kind.rawValue, "message": "Live Activities are off for this app"])
      return
    }
    // Never two cards: anything still up is from an earlier launch.
    Self.endLeftovers(log: log, except: finishedId)
    do {
      activity = try Activity.request(
        attributes: GrabberActivityAttributes(kind: kind.rawValue),
        content: ActivityContent(state: state, staleDate: staleAt), pushType: nil)
      log.event("live_activity", fields.merging(["action": "start", "ok": true, "id": activity?.id ?? ""]) { $1 })
    } catch {
      declined.insert(kind)
      log.event(
        "error", fields.merging(["where": "live_activity", "action": "start", "message": "\(error)"]) { $1 })
    }
  }

  /// The finished card, still on show, goes now.
  private func dismissFinished(reason: String) {
    guard let card = finishedCard else { return }
    finishedCard = nil
    enqueue {
      await card.activity.end(nil, dismissalPolicy: .immediate)
      self.log.event(
        "live_activity", ["action": "dismiss", "reason": reason, "kind": card.kind.rawValue, "ok": true])
    }
  }

  private func enqueueEnd(_ activity: Activity<GrabberActivityAttributes>, reason: String, kind: LiveActivityKind?) {
    enqueue {
      await activity.end(nil, dismissalPolicy: .immediate)
      self.log.event("live_activity", ["action": "end", "reason": reason, "kind": kind?.rawValue ?? "", "ok": true])
    }
  }

  private func enqueue(_ work: @escaping @MainActor () async -> Void) {
    let previous = chain
    chain = Task { @MainActor in
      await previous?.value
      await work()
    }
  }
}
