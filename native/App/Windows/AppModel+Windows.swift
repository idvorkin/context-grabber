//  #634, stories 460-464, 470-482, 560-564 (spec 2026-11-03-ipad-windows-design.md): more than one window on an iPad. The home
//  window keeps presenting what AppModel says is up; a screen in a window of its own is simply not up there.

import ContextCore
import SwiftUI

extension AppModel {
  static let homeWindowID = "home"

  /// False on a phone, which has one window whatever the app asks for.
  var windowsAvailable: Bool { UIApplication.shared.supportsMultipleScenes }

  private func checkLedger() {
    ledger.keep(alive: Set(UIApplication.shared.connectedScenes.map(\.session.persistentIdentifier)))
  }

  private var sceneCount: Int { UIApplication.shared.connectedScenes.count }

  /// The window in front; with two side by side, either: iOS doesn't say which was touched.
  private var frontWindow: String? {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive && $0.keyWindow != nil }?.session.persistentIdentifier
  }

  /// What a report calls the screen: the window in front, when that window holds one screen.
  var reportScreen: String {
    frontWindow.flatMap { ledger.screen(in: $0) }?.rawValue ?? screen
  }

  /// True when this window is the home window.
  func homeWindowAppeared(_ window: String) -> Bool {
    checkLedger()
    let home = ledger.claimHome(window)
    log.event("window", ["action": home ? "home" : "extra_home", "scenes": sceneCount])
    nameWindows()
    restoreChecked = true  // the home window is here: a screen's window opened later is no restore
    if home { runWindowHook() }
    return home
  }

  func screenWindowAppeared(_ screen: WindowScreen, window: String) {
    checkLedger()
    ledger.claim(screen, window: window)
    log.event("window", ["action": "appear", "screen": screen.rawValue, "scenes": sceneCount])
    nameWindows()
    openHomeAfterRestore()
    // A window iOS kept hidden through a relaunch, shown after the home window opened the same screen (story 461).
    _ = closeInHomeWindow(screen)
    // What opening it in the home window does besides showing it.
    switch screen {
    case .chat: inbox.reload()
    case .places:
      places.reload(reason: "open")
      tracker.requestFix(reason: tracker.authorization == .notDetermined ? "places_open" : "foreground")
    case .cockpit: cockpitOpened = true
    case .today, .whiteboard, .card: break
    }
  }

  /// #661, stories 560-564: what iPadOS calls each window, by the names on the home tiles. `UIScene.title` is the only
  /// way to say it (a SwiftUI `WindowGroup`'s title is fixed per group). Run on every change to this model, from one
  /// place rather than from each window's views: the home window's can be out of the window under a full-screen cover.
  func nameWindows() {
    guard windowsAvailable else { return }  // a phone's one window needs no name
    for scene in UIApplication.shared.connectedScenes {
      let name: String
      switch ledger.role(of: scene.session.persistentIdentifier) {
      case .home: name = homeWindowName
      case .screen(let screen): name = tileName(screen.tile)
      case .noScreen: name = ""
      }
      let was = scene.title ?? ""
      guard was != name else { continue }
      scene.title = name
      log.event("window", ["action": "title", "title": scene.title ?? "", "was": was, "scenes": sceneCount])
    }
  }

  private func tileName(_ tile: String) -> String { HomeRow.row(tile)?.title ?? "" }

  /// What the home window is showing: the covers first, as they sit over everything in its stack.
  private var homeWindowName: String {
    switch screens.named {
    case .home: return "Home"
    case .whatsNew: return "What's new"  // the home row's words; it has no tile
    // Everything else in `HomeStack.order` has a tile; the drill and a metric's week are never in `up`.
    case let shown: return tileName(shown.tile ?? "")
    }
  }

  func windowGone(_ window: String) {
    let screen = ledger.screen(in: window)
    ledger.release(window)
    log.event("window", ["action": "gone", "screen": screen?.rawValue ?? "home", "scenes": sceneCount])
    switch screen {
    case .card: CardStore.reloadWidget()
    case .places: showPlacesMap = false
    case .chat, .today, .cockpit, .whiteboard, nil: break
    }
  }

  func windowHolding(_ screen: WindowScreen) -> Bool {
    checkLedger()
    return ledger.window(holding: screen) != nil
  }

  /// Story 461: one screen, one place. True when its window came forward, and the home window should not show it.
  func bringForward(_ screen: WindowScreen, from source: String) -> Bool {
    guard windowHolding(screen), let openWindowAction else { return false }
    log.event("window", ["action": "bring_forward", "screen": screen.rawValue, "from": source, "scenes": sceneCount])
    openWindowAction(value: screen)  // SwiftUI brings the window holding this value forward rather than open another
    return true
  }

  /// Story 460: a window of its own. If the home window shows the screen it goes first: the Cockpit's page can be in
  /// one window only, and a board drawn in two would overwrite itself.
  func openInNewWindow(_ screen: WindowScreen, from source: String) {
    if bringForward(screen, from: source) { return }
    guard let openWindowAction else {
      log.event("window", ["action": "open", "screen": screen.rawValue, "from": source, "ok": false])
      status = "This window can't open another yet."
      return
    }
    log.event("window", ["action": "open", "screen": screen.rawValue, "from": source, "ok": true])
    guard closeInHomeWindow(screen) else { return openWindowAction(value: screen) }
    Task {
      // As `go` waits: the page must be off the old window before the new one takes it.
      try? await Task.sleep(for: .milliseconds(HomeStack.coverSettles))
      openWindowAction(value: screen)
    }
  }

  /// Story 731 (#782): a new window's choice. The screen opens in a window of its own (or its window comes forward),
  /// and the window that asked closes, so no screen shows twice.
  func chooseForNewWindow(_ screen: WindowScreen, closing window: String?) {
    log.event("window", ["action": "choose", "screen": screen.rawValue, "scenes": sceneCount])
    openInNewWindow(screen, from: "new_window")
    guard let window,
      let session = UIApplication.shared.openSessions.first(where: { $0.persistentIdentifier == window })
    else { return }
    // After the new window has asked to open: closing first would leave the app nothing to open it from.
    Task {
      try? await Task.sleep(for: .milliseconds(900))
      UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { [log] error in
        log.event("window", ["action": "choose_close", "ok": false, "message": error.localizedDescription])
      }
    }
  }

  /// `GRABBER_WINDOW_CHOOSE=<screen>`: once home is up, a new window opens as Command+N would, and its chooser picks
  /// that screen as a tap would. docs/TESTING.md.
  func chooseForHook(closing window: String?) {
    guard let screen = windowHookChoice else { return }
    windowHookChoice = nil
    chooseForNewWindow(screen, closing: window)
  }

  /// A screen's Done, and anything else closing its window.
  func closeWindow(_ screen: WindowScreen) {
    log.event("window", ["action": "close", "screen": screen.rawValue])
    dismissWindowAction?(value: screen)
  }

  /// Story 479: a route that lands in the home window, asked for from another window, shows in sight.
  func showHomeWindow() {
    openHomeWindowIfGone()
    guard windowsAvailable, let home = ledger.home, frontWindow != home,
      let session = UIApplication.shared.openSessions.first(where: { $0.persistentIdentifier == home })
    else { return }
    log.event("window", ["action": "bring_home", "scenes": sceneCount])
    UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: session)) { [log] error in
      log.event("window", ["action": "bring_home", "ok": false, "message": error.localizedDescription])
    }
  }

  /// Story 477: a link, a Shortcut or a notification with the home window closed has somewhere to show.
  func openHomeWindowIfGone() {
    guard windowsAvailable, let openWindowAction else { return }
    checkLedger()
    guard ledger.home == nil else { return }
    log.event("window", ["action": "reopen_home", "scenes": sceneCount])
    openWindowAction(id: Self.homeWindowID)
  }

  /// Story 482: iOS can bring back only a screen's window when the app starts (seen on the simulator: the last window
  /// in front, no home), leaving no home screen. Once per launch, after a moment for a home window on its way too.
  private func openHomeAfterRestore() {
    guard !restoreChecked else { return }
    restoreChecked = true
    Task {
      try? await Task.sleep(for: .seconds(1))
      openHomeWindowIfGone()
    }
  }

  /// True when it was showing there.
  private func closeInHomeWindow(_ screen: WindowScreen) -> Bool {
    // A window's raw value is its screen's route name (HomeStackTests pins it).
    guard let shown = HomeStack.Screen(routeName: screen.rawValue), screens.isUp(shown) else { return false }
    close(shown)
    return true
  }

  /// `GRABBER_WINDOW=<screen>[,again][,close]`: opens that screen's window, then three seconds apart asks for it again
  /// (it comes forward, no second window) and closes it, as a hold and a Done would. docs/TESTING.md.
  private func runWindowHook() {
    guard !windowHookRan else { return }
    if let choice = LaunchHooks.current.windowChoose {
      windowHookRan = true
      windowHookChoice = choice
      Task {
        try? await Task.sleep(for: .seconds(1))
        openWindowAction?(id: Self.homeWindowID)
      }
      return
    }
    guard let hook = LaunchHooks.current.window else { return }
    windowHookRan = true
    guard let screen = hook.screen else { return }
    Task {
      try? await Task.sleep(for: .seconds(1))
      openInNewWindow(screen, from: "hook")
      for step in hook.steps {
        try? await Task.sleep(for: .seconds(3))
        if step == "again" { openInNewWindow(screen, from: "hook") }
        if step == "close" { closeWindow(screen) }
      }
    }
  }
}
