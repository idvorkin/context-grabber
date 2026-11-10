//  #808: the home window's screens under one name each, and the steps that put one in front. Pure; the state they
//  change is `HomeStack.State` (HomeStackState.swift), which AppModel holds and nothing else writes.
//
//  A screen is spelled several ways, and each spelling is seen outside the app: a link and the log's `open_url` say
//  `timer`, a report and `report_problem` say `gym_timer`, its home tile (and so its window's title) is `gym_timer`,
//  an iPad window of its own is a `WindowScreen` (its raw value is the route's name). This table is the only place that
//  knows they are one screen.

import Foundation

public enum HomeStack {
  public enum Screen: Hashable, Sendable {
    case home
    case timer, breathe, card, places, cockpit, whiteboard, call, today, chat
    /// Sheets and pushed screens over home, which no link names.
    case eulogySong, whatsNew, homeSettings
    /// The card screen's drill, and one metric's week over Today: a report names them, nothing else does.
    case drill
    case metric(MetricKey)

    /// Every screen but the metrics' weeks.
    public static let fixed: [Screen] = [
      .home, .timer, .breathe, .card, .places, .cockpit, .whiteboard, .call, .today, .chat, .eulogySong, .whatsNew,
      .homeSettings, .drill,
    ]

    /// What a report and the log's `screen` field call it.
    public var reportName: String {
      switch self {
      case .home: return "home"
      case .timer: return "gym_timer"
      case .breathe: return "breathe"
      case .card: return "card"
      case .places: return "places"
      case .cockpit: return "cockpit"
      case .whiteboard: return "whiteboard"
      case .call: return "call"
      case .today: return "today"
      case .chat: return "chat"
      case .eulogySong: return "eulogy_song"
      case .whatsNew: return "whats_new"
      case .homeSettings: return "home_settings"
      case .drill: return "drill"
      case .metric(let key): return "metric_\(key.rawValue)"
      }
    }

    /// `AppRoute.name` for the route that lands here: the link's first word and the log's `route`. Nil for a screen
    /// no link names.
    public var routeName: String? {
      switch self {
      case .home: return "home"
      case .timer: return "timer"
      case .breathe: return "breathe"
      case .card: return "card"
      case .places: return "places"
      case .cockpit: return "cockpit"
      case .whiteboard: return "whiteboard"
      case .call: return "call"
      case .today: return "today"
      case .chat: return "chat"
      case .eulogySong, .whatsNew, .homeSettings, .drill, .metric: return nil
      }
    }

    public init?(routeName: String) {
      guard let screen = Self.fixed.first(where: { $0.routeName == routeName }) else { return nil }
      self = screen
    }

    /// The screen a route lands on; nil for the supermix, which opens another app.
    public init?(route: AppRoute) { self.init(routeName: route.name) }

    /// Its home tile's id, which gives the home window its title. Nil where there is no tile.
    public var tile: String? {
      switch self {
      case .timer: return "gym_timer"
      case .breathe: return "breathe"
      case .card: return "think_a_card"
      case .places: return "places"
      case .cockpit: return "cockpit"
      case .whiteboard: return "whiteboard"
      case .call: return "call"
      case .today: return "today"
      case .chat: return "inbox"
      case .eulogySong: return "eulogy_song"
      case .homeSettings: return "settings"
      case .home, .whatsNew, .drill, .metric: return nil
      }
    }
  }

  /// Top first: the covers, as they sit over everything in the home window's stack, then what sits on home itself.
  /// The order `front`, `named` and a link's closing all go in.
  public static let order: [Screen] = [
    .timer, .breathe, .card, .places, .cockpit, .whiteboard, .call, .eulogySong, .whatsNew, .homeSettings, .today,
    .chat,
  ]

  /// The screen in front as a link sees it: the topmost one a route names. A sheet over home is still home here.
  public static func front(of up: Set<Screen>) -> Screen {
    order.first { up.contains($0) && $0.routeName != nil } ?? .home
  }

  /// What the home window is showing, which names it: the topmost screen of all.
  public static func named(of up: Set<Screen>) -> Screen {
    order.first(where: up.contains) ?? .home
  }

  /// SwiftUI drops a cover asked for while another is still going down, so what comes next waits this long.
  public static let coverSettles = 700

  public enum Step: Equatable, Sendable {
    /// The home window is there and in sight: what follows shows in it.
    case showHomeWindow
    case close(Screen)
    case wait(milliseconds: Int)
    case present(AppRoute)
  }

  /// What a link, a Shortcut or a tile's choice does to show `route`, in order. `up`: every screen showing in the
  /// home window. `ownWindow`: the route's screen is in a window of its own.
  ///
  /// Whatever is in front goes, then the route's screen comes up. The screen already in front stays when the link
  /// starts nothing; the call screen stays either way (a live call is brought forward, not restarted). Home has
  /// nothing to bring up, so a link home closes what is in front and waits for nothing (#818).
  public static func go(to route: AppRoute, up: Set<Screen>, ownWindow: Bool) -> [Step] {
    // The supermix is another app: nothing here needs to move.
    guard let screen = Screen(route: route) else { return [.present(route)] }
    // #634: its own window comes forward, and whatever the home window shows stays.
    if ownWindow { return [.present(route)] }
    if front(of: up) == screen {
      if screen == .call { return [.showHomeWindow, .present(route)] }
      if !route.starts { return [.showHomeWindow] }
    }
    // What a link closes: the screens a route names. A sheet over home stays up.
    let closing = order.filter { up.contains($0) && $0.routeName != nil }
    guard !closing.isEmpty else { return [.showHomeWindow, .present(route)] }
    if screen == .home { return [.showHomeWindow] + closing.map(Step.close) }
    return [.showHomeWindow] + closing.map(Step.close) + [.wait(milliseconds: coverSettles), .present(route)]
  }
}
