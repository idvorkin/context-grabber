//  The call's launch hook (docs/TESTING.md).

import Foundation

extension AppModel {
  /// A call to GRABBER_CALL's bridge (the smoke run's fake one), hung up after GRABBER_CALL_SECONDS (default 8).
  func runCallHook(seconds: Double) {
    openCall(from: "hook")
    Task {
      try? await Task.sleep(for: .seconds(1))
      call.start(from: "hook")
      try? await Task.sleep(for: .seconds(seconds))
      if call.snapshot.isActive { call.hangUp(from: "hook") }
    }
  }

  /// Story 1078: the *This call's chat* link's tap, once the bridge has named the call's thread (it waits up to 6 s).
  func runCallThreadHook() {
    Task {
      for _ in 0..<30 where call.snapshot.thread == nil { try? await Task.sleep(for: .milliseconds(200)) }
      guard let key = call.snapshot.thread else {
        log.event("ui", ["action": "open_call_thread", "from": "hook", "ok": false, "reason": "no thread"])
        return
      }
      openCallThread(key)
    }
  }
}
