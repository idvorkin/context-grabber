//  #686: a menu's rows exist before they stop moving, and a tap in that moment closes the menu or misses, so a choice
//  only sometimes took. These wait for what the tap needs: the element still, and hittable.

import XCTest

extension XCUIElement {
  /// Polls rather than sleeps, so a settled element costs nothing (story 673).
  func settle(timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    var last = CGRect.null
    while Date() < deadline {
      if exists {
        let now = frame
        if now == last && isHittable { return }
        last = now
      }
      Thread.sleep(forTimeInterval: 0.1)
    }
  }

  func tapWhenSettled(timeout: TimeInterval = 5) {
    settle(timeout: timeout)
    tap()
  }

  /// Bead context-grabber-xnvx: a long press's actions-only menu can take a settled, hittable row's tap and do nothing
  /// (the session log shows the touch on the row and no action after it), leaving the menu up over the bar. Tap the
  /// row, and tap again only while the row is still there and `took` says the action hasn't happened, at most `tries`
  /// times: a slow fade is never tapped twice.
  func tapUntilGone(tries: Int = 3, timeout: TimeInterval = 1.5, took: () -> Bool) {
    for _ in 0..<tries {
      tapWhenSettled()
      let deadline = Date().addingTimeInterval(timeout)
      while Date() < deadline {
        if took() || !exists { return }
        Thread.sleep(forTimeInterval: 0.1)
      }
    }
  }
}
