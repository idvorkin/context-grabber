//  The duck window: other audio turned down (music) or paused (podcasts) around the Gym Timer's cues, and back
//  a moment after the last one (story 105).
//
//  The unit is a window, not a cue: the three, two, one are a second apart, and ducking each would make the
//  music pump. Each count or cue *holds* the window; it closes itself when nothing has held it for a while.
//  Closing means letting go of the session — a paused podcast resumes only when the session that paused it
//  deactivates — which is the session's job; this class only decides when. Platform-free, so the timing is tested.

import Foundation

public protocol DuckSession: AnyObject {
  /// Put the window's options on the session (true) or the base ones (false).
  func setDucking(_ on: Bool)
  /// Let go: deactivate (telling others they may resume), reactivate, restart what was playing.
  func release()
}

public final class DuckWindow {
  /// After a count: long enough to reach the next count or the cue.
  public static let tickHoldMs = 1600
  /// After a phase cue: a beat, then back.
  public static let cueHoldMs = 1500
  /// After the finish ("done" and its fanfare).
  public static let finishHoldMs = 2400
  /// Opened a silent second before the three: reach it with room to spare.
  public static let openEarlyHoldMs = 2600

  /// Run the block after that many milliseconds; the returned closure cancels it.
  public typealias Schedule = (_ afterMs: Int, _ block: @escaping () -> Void) -> () -> Void

  private let session: DuckSession
  private let schedule: Schedule
  private let log: (_ action: String, _ holdMs: Int) -> Void
  private var cancelClose: (() -> Void)?
  public private(set) var isOpen = false

  public init(
    session: DuckSession, schedule: @escaping Schedule,
    log: @escaping (_ action: String, _ holdMs: Int) -> Void = { _, _ in }
  ) {
    self.session = session
    self.schedule = schedule
    self.log = log
  }

  /// Open the window (if it is not), and keep it open `holdMs` from now.
  public func hold(_ holdMs: Int = DuckWindow.tickHoldMs) {
    if !isOpen {
      isOpen = true
      log("open", holdMs)
      session.setDucking(true)
    } else {
      log("held", holdMs)
    }
    cancelClose?()
    cancelClose = schedule(holdMs) { [weak self] in
      self?.cancelClose = nil
      self?.close()
    }
  }

  /// Close now: base options, then let go of the session. Closing a closed window does nothing.
  public func close() {
    cancelClose?()
    cancelClose = nil
    guard isOpen else { return }
    isOpen = false
    log("close", 0)
    session.setDucking(false)
    session.release()
    log("released", 0)
  }
}
