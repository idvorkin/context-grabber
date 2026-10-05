//  The app's one Live Activity (spec 2026-10-04-native-live-activity-design.md): the Gym Timer (story 106) and Box
//  breathing (story 166) each feed it what their card should say — ContextCore's `LiveActivityContent` — whenever
//  their state changes. It diffs on the content's key and talks to ActivityKit: a request when a session starts, a
//  push at each step, pause and resume, an end at the finish (shown a few minutes more), and an end at once on
//  RESET, Back or leaving the screen. One card at a time: a card for one screen ends the other's. Every request,
//  push and end is a `live_activity` event.
//
//  ActivityKit never runs on the clocks' path: the screens' 0.05-0.1 s clocks share the main actor, and a request on
//  a fresh launch stalled them for seconds (round-1 cues lost). Every call waits its turn on one chain, so the card
//  never moves backwards, and the ones that block (the launch sweep, the enabled check, the request) run off the main
//  actor.

import ActivityKit
import ContextCore
import Foundation

@MainActor
final class LiveActivityController {
  private let log: SessionLog
  /// The screen whose card is up, or asked for. Its next session is the only thing that asks again, so a card
  /// that could not start (Live Activities off, or the request refused) is said once per session and never
  /// requested from the background.
  private var kind: LiveActivityKind?
  /// The card itself, known only once the chain has run its request.
  private var activity: Activity<GrabberActivityAttributes>?
  /// Ended at the finish but still on the lock screen for a few minutes; RESET, Back, leaving or a new start take
  /// it down at once. `finishedKind` is known at once, the card once the chain has run its end.
  private var finishedKind: LiveActivityKind?
  private var finishedActivity: Activity<GrabberActivityAttributes>?
  private var lastKey: String?
  /// ActivityKit's work, one call after another.
  private var chain: Task<Void, Never>?
  /// How long a finished card stays on the lock screen.
  private static let finishedFor: TimeInterval = 4 * 60

  init(log: SessionLog) {
    self.log = log
  }

  /// A card left by a launch that was killed mid-session no longer counts true: the app calls this at launch,
  /// before any request, so every card up afterwards is this launch's.
  func endLeftovers() {
    let log = log
    enqueue {
      await Task.detached {
        let began = Date()
        let leftovers = Activity<GrabberActivityAttributes>.activities
        log.event("live_activity", ["action": "sweep", "count": leftovers.count, "ms": Self.ms(since: began)])
        for leftover in leftovers {
          await leftover.end(nil, dismissalPolicy: .immediate)
          log.event(
            "live_activity", ["action": "end", "reason": "leftover", "kind": leftover.attributes.kind, "ok": true])
        }
      }.value
    }
  }

  /// `kind`'s state changed: push its card if what it says changed. nil content ends `kind`'s card at once (only
  /// that screen's: the other screen's card is not this screen's to end). `stepEndsAt` is the exact end of the
  /// step on the wall clock, nil when paused or finished.
  func sync(_ content: LiveActivityContent?, kind: LiveActivityKind, stepEndsAt: Double?) {
    guard let content else {
      if self.kind == kind || finishedKind == kind { end(kind, reason: "reset") }
      return
    }
    let key = "\(kind.rawValue)|\(content.key)"
    guard key != lastKey else { return }
    lastKey = key
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

    if let current = self.kind, current != kind {
      // The other screen's card: one at a time.
      self.kind = nil
      endCurrent(reason: "replaced", kind: current)
    }
    guard self.kind == kind else {
      if content.finished { return }  // finished before a card was ever shown: nothing to say "done" on
      self.kind = kind
      start(state, kind: kind, staleAt: staleAt, fields: fields)
      return
    }
    if content.finished {
      self.kind = nil
      finishedKind = kind
      enqueue {
        guard let activity = self.activity else { return }
        self.activity = nil
        self.finishedActivity = activity
        await activity.end(
          ActivityContent(state: state, staleDate: nil),
          dismissalPolicy: .after(Date().addingTimeInterval(Self.finishedFor)))
        self.log.event("live_activity", fields.merging(["action": "end", "reason": "finished", "ok": true]) { $1 })
      }
      return
    }
    enqueue {
      guard let activity = self.activity else { return }  // the card never started: nothing to push
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
    if finishedKind == kind { dismissFinished(reason: reason) }
    guard self.kind == kind else { return }
    lastKey = nil
    self.kind = nil
    endCurrent(reason: reason, kind: kind)
  }

  /// The request, after any finished card still on show is taken down (a new start replaces it). Nothing here
  /// waits for it: the clock and the first cue are already going.
  private func start(
    _ state: GrabberActivityAttributes.ContentState, kind: LiveActivityKind, staleAt: Date?, fields: [String: Any]
  ) {
    dismissFinished(reason: "restart")
    let log = log
    enqueue {
      let started = await Task.detached { () -> Activity<GrabberActivityAttributes>? in
        let askedAt = Date()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
          log.event(
            "live_activity",
            [
              "action": "unavailable", "kind": kind.rawValue, "message": "Live Activities are off for this app",
              "ms": Self.ms(since: askedAt),
            ])
          return nil
        }
        let requestedAt = Date()
        do {
          let activity = try Activity.request(
            attributes: GrabberActivityAttributes(kind: kind.rawValue),
            content: ActivityContent(state: state, staleDate: staleAt), pushType: nil)
          log.event(
            "live_activity",
            fields.merging(["action": "start", "ok": true, "id": activity.id, "ms": Self.ms(since: requestedAt)]) {
              $1
            })
          return activity
        } catch {
          log.event(
            "error",
            fields.merging([
              "where": "live_activity", "action": "start", "message": "\(error)", "ms": Self.ms(since: requestedAt),
            ]) { $1 })
          return nil
        }
      }.value
      // Ended or replaced while the request was in flight: that end is next on the chain and takes it down.
      if let started { self.activity = started }
    }
  }

  private nonisolated static func ms(since date: Date) -> Int { Int(Date().timeIntervalSince(date) * 1000) }

  /// The finished card, still on show, goes now.
  private func dismissFinished(reason: String) {
    guard let kind = finishedKind else { return }
    finishedKind = nil
    enqueue {
      guard let activity = self.finishedActivity else { return }
      self.finishedActivity = nil
      await activity.end(nil, dismissalPolicy: .immediate)
      self.log.event("live_activity", ["action": "dismiss", "reason": reason, "kind": kind.rawValue, "ok": true])
    }
  }

  private func endCurrent(reason: String, kind: LiveActivityKind) {
    enqueue {
      guard let activity = self.activity else { return }
      self.activity = nil
      await activity.end(nil, dismissalPolicy: .immediate)
      self.log.event("live_activity", ["action": "end", "reason": reason, "kind": kind.rawValue, "ok": true])
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
