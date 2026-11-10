//  #808, #818 (spec 2026-10-06-native-links-design.md, "Who wins when links come close together"): the home window's
//  screens as one value, and the only code that changes them. AppModel holds a `HomeStack.State`, reads every "is it
//  up" and the screen a report names from it, and carries out the effects it returns; nothing else writes it.

import Foundation

extension HomeStack {
  /// What AppModel does after a change to the stack. The stack already says what is up.
  public enum Effect: Equatable, Sendable {
    /// The home window is there and in sight: what follows shows in it.
    case showHomeWindow
    /// The screen is down; AppModel does what its closing does besides (a log line, a refresh).
    case dismissed(Screen)
    /// Call `settle(wait:)` with this id after this long: the covers going down have to settle first.
    case wait(milliseconds: Int, id: Int)
    /// Bring the route's screen up (its opener calls `open(_:)`), or open it in its own window or another app.
    case present(AppRoute, from: String)
  }

  /// A link that closed what was in front, waiting for it to go down before its screen comes up.
  public struct Pending: Equatable, Sendable {
    public let route: AppRoute
    public let from: String
    /// The wait it comes up after: a newer link that replaces it keeps the wait already running.
    public let wait: Int
  }

  public struct State: Equatable, Sendable {
    /// Every screen up in the home window, bottom first. Home is under everything and never listed. The order is
    /// the home window's own (`HomeStack.order`): a cover always sits over a pushed screen, whatever came first. The
    /// card's drill sits on the card, a metric's week on Today.
    public private(set) var stack: [Screen] = []
    /// At most one link waiting to bring its screen up.
    public private(set) var pending: Pending?
    private var waits = 0

    public init() {}

    /// For tests: these screens up, as if each had been opened.
    public init(_ up: [Screen]) {
      for screen in up { open(screen) }
    }

    /// The screen on top of all, which a report and the log name: home when nothing is up.
    public var top: Screen { stack.last ?? .home }

    /// The screen in front as a link sees it (`HomeStack.front`).
    public var front: Screen { HomeStack.front(of: Set(stack)) }

    /// What the home window is showing, which names it (`HomeStack.named`).
    public var named: Screen { HomeStack.named(of: Set(stack)) }

    public func isUp(_ screen: Screen) -> Bool { stack.contains(screen) }

    /// The metric whose week is open, if one is.
    public var metric: MetricKey? {
      for case .metric(let key) in stack { return key }
      return nil
    }

    /// A screen comes up over what is there: a tile, a hook, a sheet, or the present a link asked for. It is the
    /// latest ask, so a link still waiting is dropped. A metric's week replaces another's. True when it was not up.
    @discardableResult
    public mutating func open(_ screen: Screen) -> Bool {
      pending = nil
      guard screen != .home, !stack.contains(screen) else { return false }
      if case .metric = screen { stack.removeAll { if case .metric = $0 { return true } else { return false } } }
      let rank = Self.rank(screen)
      let at = stack.firstIndex { Self.rank($0) > rank } ?? stack.endIndex
      stack.insert(screen, at: at)
      return true
    }

    /// A screen goes down, and what sits on it with it (the drill on the card, a metric's week on Today). False when
    /// it was not up: a link closed it already, and this is its cover's binding catching up.
    @discardableResult
    public mutating func close(_ screen: Screen) -> Bool {
      guard stack.contains(screen) else { return false }
      stack.removeAll { $0 == screen || Self.sitsOn($0) == screen }
      return true
    }

    /// A link, a Shortcut or a tile's choice to `route` (`HomeStack.go` says the steps). `ownWindow`: the route's
    /// screen is in a window of its own.
    ///
    /// Who wins: the newest link. One that arrives while an earlier one waits replaces it, so the earlier screen
    /// never comes up. It keeps the wait already running when it has nothing new to close; a link home, to a
    /// window of its own or to the supermix shows at once and the waiting screen is dropped.
    public mutating func open(_ route: AppRoute, from source: String, ownWindow: Bool) -> [Effect] {
      let waiting = pending
      pending = nil
      var effects: [Effect] = []
      for step in HomeStack.go(to: route, up: Set(stack), ownWindow: ownWindow) {
        switch step {
        case .showHomeWindow: effects.append(.showHomeWindow)
        case .close(let screen):
          if close(screen) { effects.append(.dismissed(screen)) }
        case .wait(let milliseconds):
          waits += 1
          pending = Pending(route: route, from: source, wait: waits)
          effects.append(.wait(milliseconds: milliseconds, id: waits))
          return effects
        case .present(let presented):
          if let waiting, !ownWindow, Screen(route: presented) != nil {
            // The covers the earlier link closed are still going down.
            pending = Pending(route: presented, from: source, wait: waiting.wait)
            return effects
          }
          effects.append(.present(presented, from: source))
        }
      }
      return effects
    }

    /// The wait `id` is over: the link still waiting on it, if any, brings its screen up. A wait a newer link
    /// started over, or whose link was dropped, does nothing.
    public mutating func settle(wait id: Int) -> [Effect] {
      guard let waiting = pending, waiting.wait == id else { return [] }
      pending = nil
      return [.present(waiting.route, from: waiting.from)]
    }

    /// The screen `screen` rides on and goes down with: nil for one that stands on its own.
    static func sitsOn(_ screen: Screen) -> Screen? {
      switch screen {
      case .drill: return .card
      case .metric: return .today
      default: return nil
      }
    }

    /// Bottom first: `HomeStack.order` read upwards, a rider just over what it sits on.
    static func rank(_ screen: Screen) -> Int {
      if let under = sitsOn(screen) { return rank(under) + 1 }
      guard let index = HomeStack.order.firstIndex(of: screen) else { return -1 }
      return (HomeStack.order.count - index) * 2
    }
  }
}
