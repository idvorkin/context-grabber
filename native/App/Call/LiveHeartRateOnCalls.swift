//  Stories 1088-1089 (context-grabber-at59): *Live heart rate on calls*. A live call asks Exercise Analyzer to start
//  its light Call session on the watch (exercise-analyzer PR #412), and the call's end asks it to end it. Grabber
//  can't start another app's watch session, so it opens Exercise Analyzer's link, which comes back through
//  x-success or x-error. Asked once the call is live, never before: iOS doesn't let a call start its audio from the
//  background, and a live call's audio keeps running there as it does with the phone locked.

import ContextCore
import SwiftUI
import UIKit

@MainActor
final class LiveHeartRateOnCalls: ObservableObject {
  /// The switch, off by default. Only the iPhone offers it: the watch pairs with the phone.
  @Published var enabled: Bool {
    didSet { database.setSetting(Self.key, enabled ? "1" : "0") }
  }
  /// Why live heart rate didn't start or end, for the quiet line under the call; nil when it went, or wasn't asked.
  @Published private(set) var note: String?

  static let key = "live_hr_on_calls"
  /// Only the iPhone, not the iPad and not the Mac app.
  static var offered: Bool {
    #if targetEnvironment(macCatalyst)
      return false
    #else
      return UIDevice.current.userInterfaceIdiom == .phone
    #endif
  }

  private let log: SessionLog
  private let database: AppDatabase
  private var plan = LiveHeartRatePlan()
  /// The opener, swapped in tests. Answers whether the link went out.
  private let canOpen: (URL) -> Bool
  private let open: (URL, @escaping (Bool) -> Void) -> Void

  init(log: SessionLog, database: AppDatabase, environment: [String: String]) {
    self.log = log
    self.database = database
    // GRABBER_LIVE_HR_CALLS=1: a UI test turns the switch on without opening Settings.
    let hook = environment["GRABBER_LIVE_HR_CALLS"]
    if let hook { database.setSetting(Self.key, hook == "1" ? "1" : "0") }
    enabled = database.setting(Self.key) == "1"
    // GRABBER_LIVE_HR_EA=absent: a UI test acts as if Exercise Analyzer weren't installed, whatever this simulator has.
    if environment["GRABBER_LIVE_HR_EA"] == "absent" {
      canOpen = { _ in false }
    } else {
      canOpen = { UIApplication.shared.canOpenURL($0) }
    }
    open = { url, done in UIApplication.shared.open(url, options: [:], completionHandler: done) }
  }

  /// Every change of the call's state: asks to start once it's live, and to end once it ends.
  func onCall(_ snap: CallSnapshot) {
    if snap.state == .connecting, !snap.redialing { note = nil }
    guard let action = plan.next(state: snap.state, redialing: snap.redialing, enabled: enabled && Self.offered)
    else { return }
    ask(action)
  }

  /// Exercise Analyzer's answer, from the `grabbernative://live-heart-rate/…` link it opened.
  func handle(_ callback: LiveHeartRateLink.Callback) {
    switch callback {
    case .ok(let action):
      log.event("live_hr_link", ["action": action.rawValue, "stage": "callback", "ok": true])
      if action == .start { note = nil }
    case .error(let action, let reason):
      log.event("live_hr_link", ["action": action.rawValue, "stage": "callback", "ok": false, "reason": reason])
      if action == .start { plan.startFailed() }
      note = Self.noteText(action, reason)
    }
  }

  private func ask(_ action: LiveHeartRateLink.Action) {
    guard let url = LiveHeartRateLink.url(for: action) else { return }
    guard canOpen(url) else {
      let reason = "Exercise Analyzer isn't installed"
      log.event("live_hr_link", ["action": action.rawValue, "stage": "open", "ok": false, "reason": reason])
      if action == .start { plan.startFailed() }
      note = Self.noteText(action, reason)
      return
    }
    log.event("live_hr_link", ["action": action.rawValue, "stage": "open", "url": url.absoluteString])
    open(url) { [weak self] went in
      Task { @MainActor in
        guard let self else { return }
        self.log.event("live_hr_link", ["action": action.rawValue, "stage": "opened", "ok": went])
        guard !went else { return }
        if action == .start { self.plan.startFailed() }
        self.note = Self.noteText(action, "iOS didn't open Exercise Analyzer")
      }
    }
  }

  static func noteText(_ action: LiveHeartRateLink.Action, _ reason: String) -> String {
    let what = action == .start ? "couldn't start" : "couldn't end"
    let end = reason.hasSuffix(".") ? "" : "."
    return "Live heart rate \(what): \(reason)\(end)"
  }
}

/// The quiet line under the call, copyable (AGENTS.md: every user-visible error is copyable).
struct LiveHeartRateNote: View {
  @ObservedObject var live: LiveHeartRateOnCalls

  var body: some View {
    if let note = live.note {
      Text(note)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .contextMenu { Button("Copy") { UIPasteboard.general.string = note } }
        .accessibilityIdentifier("call-live-hr-note")
    }
  }
}

/// Settings: *Live heart rate on calls*, iPhone only.
struct LiveHeartRateSettingsSection: View {
  @ObservedObject var live: LiveHeartRateOnCalls

  var body: some View {
    if LiveHeartRateOnCalls.offered {
      Section {
        Toggle("Live heart rate on calls", isOn: $live.enabled)
          .accessibilityIdentifier("live-hr-calls-switch")
      } header: {
        Text("Heart rate on calls")
      } footer: {
        Text(
          "A call asks Exercise Analyzer to start its Call session on the watch, so your heart rate goes to the "
            + "Cockpit while you talk. Exercise Analyzer opens for a second, then the call comes back.")
      }
    }
  }
}
