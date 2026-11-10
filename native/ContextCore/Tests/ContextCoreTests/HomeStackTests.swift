//  #808: one name per screen of the home window, every spelling of it pinned both ways, and the steps a link takes.

import XCTest

@testable import ContextCore

final class HomeStackTests: XCTestCase {
  typealias Screen = HomeStack.Screen
  typealias Step = HomeStack.Step

  // MARK: - The vocabulary

  /// Every spelling that leaves the app: the report's, the link's (and the log's `route`), and the home tile's.
  /// Changing a string here changes what a log, a link or a window title says.
  private let table: [(screen: Screen, report: String, route: String?, tile: String?)] = [
    (.home, "home", "home", nil),
    (.timer, "gym_timer", "timer", "gym_timer"),
    (.breathe, "breathe", "breathe", "breathe"),
    (.card, "card", "card", "think_a_card"),
    (.places, "places", "places", "places"),
    (.cockpit, "cockpit", "cockpit", "cockpit"),
    (.whiteboard, "whiteboard", "whiteboard", "whiteboard"),
    (.call, "call", "call", "call"),
    (.today, "today", "today", "today"),
    (.chat, "chat", "chat", "inbox"),
    (.eulogySong, "eulogy_song", nil, "eulogy_song"),
    (.whatsNew, "whats_new", nil, nil),
    (.homeSettings, "home_settings", nil, "settings"),
    (.drill, "drill", nil, nil),
  ]

  func testTheTableCoversEveryFixedScreen() {
    XCTAssertEqual(table.map(\.screen), Screen.fixed)
  }

  func testEverySpellingOfEveryScreen() {
    for row in table {
      XCTAssertEqual(row.screen.reportName, row.report)
      XCTAssertEqual(row.screen.routeName, row.route, row.report)
      XCTAssertEqual(row.screen.tile, row.tile, row.report)
      if let route = row.route { XCTAssertEqual(Screen(routeName: route), row.screen) }
    }
    XCTAssertEqual(Set(table.map(\.report)).count, table.count, "a report's name is one screen's")
    XCTAssertNil(Screen(routeName: "gym_timer"), "the link's word for the timer is timer")
    XCTAssertNil(Screen(routeName: "eulogy_song"))
  }

  func testAMetricsWeekIsNamedByItsMetric() {
    for key in MetricKey.allCases {
      XCTAssertEqual(Screen.metric(key).reportName, "metric_\(key.rawValue)")
      XCTAssertNil(Screen.metric(key).routeName)
      XCTAssertNil(Screen.metric(key).tile)
    }
    XCTAssertEqual(Screen.metric(.heartRate).reportName, "metric_heartRate")
  }

  func testEveryRouteLandsOnItsScreen() {
    let routes: [(AppRoute, Screen?)] = [
      (.home, .home), (.today, .today), (.timer(TimerLink()), .timer), (.breathe(BreatheLink()), .breathe),
      (.places, .places), (.cockpit, .cockpit), (.call(via: nil), .call), (.card(think: true), .card),
      (.chat(thread: "t"), .chat), (.whiteboard(board: nil), .whiteboard), (.supermix, nil),
    ]
    for (route, screen) in routes {
      XCTAssertEqual(Screen(route: route), screen, route.name)
      if let screen { XCTAssertEqual(screen.routeName, route.name) }
    }
  }

  /// The windows keep their own table (`WindowScreen`): a window's raw value is its screen's route name, and both
  /// name the same tile, so a window's title and the home window's agree.
  func testTheWindowsTableAgrees() {
    for window in WindowScreen.allCases {
      let screen = Screen(routeName: window.rawValue)
      XCTAssertNotNil(screen, window.rawValue)
      XCTAssertEqual(screen?.tile, window.tile, window.rawValue)
    }
  }

  /// Every first word `AppLink.parse` reads, and the screen it lands on.
  func testEveryLinkWordIsReadAsItsScreen() {
    let words: [(String, Screen)] = [
      ("home", .home), ("main", .home), ("today", .today), ("grab", .today), ("timer", .timer),
      ("breathe", .breathe), ("breathing", .breathe), ("places", .places), ("cockpit", .cockpit), ("call", .call),
      ("card", .card), ("think", .card), ("chat", .chat), ("inbox", .chat), ("whiteboard", .whiteboard),
    ]
    for (word, screen) in words {
      let parsed = AppLink.parse("grabbernative://\(word)")
      XCTAssertTrue(parsed.understood, word)
      XCTAssertEqual(Screen(route: parsed.route), screen, word)
    }
    // And the link each route is written as starts with the route's name.
    XCTAssertEqual(AppLink.link(for: .timer(TimerLink())), "grabbernative://timer")
    XCTAssertEqual(AppLink.link(for: .chat(thread: nil)), "grabbernative://chat")
  }

  // MARK: - Which screen is in front

  func testTheFrontIsTheTopmostScreenALinkNames() {
    XCTAssertEqual(HomeStack.front(of: []), .home)
    XCTAssertEqual(HomeStack.front(of: [.chat, .today]), .today)
    XCTAssertEqual(HomeStack.front(of: [.today, .call, .timer]), .timer)
    XCTAssertEqual(HomeStack.front(of: [.call, .cockpit]), .cockpit)
    XCTAssertEqual(HomeStack.front(of: [.eulogySong, .homeSettings, .whatsNew]), .home, "a sheet over home is home")
    XCTAssertEqual(HomeStack.front(of: [.eulogySong, .chat]), .chat)
    XCTAssertEqual(
      HomeStack.order.filter { $0.routeName != nil },
      [.timer, .breathe, .card, .places, .cockpit, .whiteboard, .call, .today, .chat])
  }

  func testTheHomeWindowIsNamedForTheTopmostScreenOfAll() {
    XCTAssertEqual(HomeStack.named(of: []), .home)
    XCTAssertEqual(HomeStack.named(of: [.eulogySong, .today]), .eulogySong)
    XCTAssertEqual(HomeStack.named(of: [.whatsNew, .homeSettings, .chat]), .whatsNew)
    XCTAssertEqual(HomeStack.named(of: [.homeSettings, .today, .chat]), .homeSettings)
    XCTAssertEqual(HomeStack.named(of: [.call, .eulogySong]), .call)
    XCTAssertEqual(
      HomeStack.order,
      [
        .timer, .breathe, .card, .places, .cockpit, .whiteboard, .call, .eulogySong, .whatsNew, .homeSettings, .today,
        .chat,
      ])
    // Every screen that can name the window has a tile, but What's new, which has its own words.
    XCTAssertEqual(HomeStack.order.filter { $0.tile == nil }, [.whatsNew])
  }

  // MARK: - The steps to a screen

  private func go(_ route: AppRoute, up: Set<Screen> = [], ownWindow: Bool = false) -> [Step] {
    HomeStack.go(to: route, up: up, ownWindow: ownWindow)
  }

  func testFromHomeTheScreenComesStraightUp() {
    XCTAssertEqual(go(.places), [.showHomeWindow, .present(.places)])
    XCTAssertEqual(go(.call(via: nil)), [.showHomeWindow, .present(.call(via: nil))])
  }

  func testWhatIsInFrontGoesThenAWaitThenTheScreen() {
    XCTAssertEqual(
      go(.places, up: [.timer]),
      [.showHomeWindow, .close(.timer), .wait(milliseconds: 700), .present(.places)])
    XCTAssertEqual(HomeStack.coverSettles, 700)
  }

  func testEverythingALinkNamesClosesTopFirstAndASheetStays() {
    XCTAssertEqual(
      go(.cockpit, up: [.chat, .today, .call, .eulogySong, .homeSettings, .whatsNew, .timer]),
      [
        .showHomeWindow, .close(.timer), .close(.call), .close(.today), .close(.chat), .wait(milliseconds: 700),
        .present(.cockpit),
      ])
    XCTAssertEqual(go(.places, up: [.eulogySong]), [.showHomeWindow, .present(.places)], "no cover is going down")
  }

  func testTheScreenAlreadyInFrontStaysWhenTheLinkStartsNothing() {
    XCTAssertEqual(go(.timer(TimerLink()), up: [.timer]), [.showHomeWindow])
    XCTAssertEqual(go(.home), [.showHomeWindow])
    XCTAssertEqual(go(.home, up: [.eulogySong]), [.showHomeWindow])
    XCTAssertEqual(go(.chat(thread: nil), up: [.chat]), [.showHomeWindow])
    // Only the front counts: Today under the timer is not in front.
    XCTAssertEqual(
      go(.today, up: [.timer, .today]),
      [.showHomeWindow, .close(.timer), .close(.today), .wait(milliseconds: 700), .present(.today)])
  }

  func testALinkThatStartsSomethingReopensTheScreenInFront() {
    let start = AppRoute.timer(TimerLink(start: true))
    XCTAssertEqual(
      go(start, up: [.timer]), [.showHomeWindow, .close(.timer), .wait(milliseconds: 700), .present(start)])
    let thread = AppRoute.chat(thread: "t")
    XCTAssertEqual(
      go(thread, up: [.chat]), [.showHomeWindow, .close(.chat), .wait(milliseconds: 700), .present(thread)])
  }

  func testTheCallScreenInFrontStaysAndIsPresentedAgain() {
    XCTAssertEqual(go(.call(via: .eleven), up: [.call]), [.showHomeWindow, .present(.call(via: .eleven))])
    // Under another cover it is not in front: it closes and comes back.
    XCTAssertEqual(
      go(.call(via: nil), up: [.cockpit, .call]),
      [.showHomeWindow, .close(.cockpit), .close(.call), .wait(milliseconds: 700), .present(.call(via: nil))])
  }

  /// #818: home has nothing to bring up, so nothing waits.
  func testHomeClosesWhatIsUpAndWaitsForNothing() {
    XCTAssertEqual(go(.home, up: [.breathe]), [.showHomeWindow, .close(.breathe)])
    XCTAssertEqual(go(.home, up: [.chat, .eulogySong]), [.showHomeWindow, .close(.chat)], "a sheet over home stays")
  }

  func testTheSupermixMovesNothing() {
    XCTAssertEqual(go(.supermix, up: [.timer, .chat]), [.present(.supermix)])
    XCTAssertEqual(go(.supermix, up: [], ownWindow: true), [.present(.supermix)])
  }

  func testAScreenInAWindowOfItsOwnLeavesTheHomeWindowAlone() {
    XCTAssertEqual(go(.cockpit, up: [.timer], ownWindow: true), [.present(.cockpit)])
    XCTAssertEqual(go(.chat(thread: "t"), up: [], ownWindow: true), [.present(.chat(thread: "t"))])
  }

  // MARK: - The stack: one value, and who wins (#818)

  typealias State = HomeStack.State
  typealias Effect = HomeStack.Effect

  /// The home window as AppModel runs it: effects carried out, each present bringing its screen up as its opener
  /// does, and the waits left running until `settle` is called by hand.
  private struct Window {
    var state: State
    var presented: [AppRoute] = []
    var dismissed: [Screen] = []
    var waits: [Int] = []

    init(_ up: [Screen] = []) { state = State(up) }

    mutating func link(_ route: AppRoute, ownWindow: Bool = false) {
      apply(state.open(route, from: "link", ownWindow: ownWindow), ownWindow: ownWindow)
    }

    /// Every wait asked for so far runs out, oldest first.
    mutating func settle() {
      let running = waits
      waits = []
      for id in running { apply(state.settle(wait: id)) }
    }

    /// `ownWindow`: the screen's window comes forward (AppModel's `bringForward`), so the home stack is left alone.
    private mutating func apply(_ effects: [Effect], ownWindow: Bool = false) {
      for effect in effects {
        switch effect {
        case .showHomeWindow: break
        case .dismissed(let screen): dismissed.append(screen)
        case .wait(_, let id): waits.append(id)
        case .present(let route, _):
          presented.append(route)
          if !ownWindow, let screen = Screen(route: route) { state.open(screen) }
        }
      }
    }
  }

  func testTheStackKeepsTheHomeWindowsOrderWhateverCameFirst() {
    var state = State()
    XCTAssertEqual(state.top, .home)
    state.open(.chat)
    state.open(.timer)
    state.open(.today)
    XCTAssertEqual(state.stack, [.chat, .today, .timer], "a cover sits over a pushed screen")
    XCTAssertEqual(state.top, .timer)
    XCTAssertFalse(state.open(.timer), "already up")
    XCTAssertFalse(state.open(.home), "home is under everything")
    XCTAssertEqual(state.stack, [.chat, .today, .timer])
  }

  func testTheDrillAndAMetricsWeekRideOnTheirScreen() {
    var state = State([.today, .card])
    state.open(.metric(.steps))
    state.open(.drill)
    XCTAssertEqual(state.stack, [.today, .metric(.steps), .card, .drill])
    XCTAssertEqual(state.top.reportName, "drill")
    state.open(.metric(.heartRate))
    XCTAssertEqual(state.metric, .heartRate, "one metric's week at a time")
    XCTAssertEqual(state.stack, [.today, .metric(.heartRate), .card, .drill])
    XCTAssertTrue(state.close(.card))
    XCTAssertEqual(state.stack, [.today, .metric(.heartRate)], "the drill goes with the card")
    XCTAssertEqual(state.top.reportName, "metric_heartRate")
    state.close(.today)
    XCTAssertEqual(state.stack, [])
    XCTAssertNil(state.metric)
  }

  func testClosingWhatIsNotUpChangesNothing() {
    var state = State([.places])
    XCTAssertFalse(state.close(.timer))
    XCTAssertTrue(state.close(.places))
    XCTAssertFalse(state.close(.places), "the cover's binding catching up after a link closed it")
  }

  /// The name a report, the log and the home window use is read off the stack: nothing sets it by hand.
  func testTheNameIsTheTopOfTheStack() {
    var state = State([.chat, .eulogySong])
    XCTAssertEqual(state.top.reportName, "eulogy_song")
    XCTAssertEqual(state.front, .chat, "a sheet over chat: chat is what a link sees")
    XCTAssertEqual(state.named, .eulogySong)
    state.close(.eulogySong)
    XCTAssertEqual(state.top.reportName, "chat")
    state.close(.chat)
    XCTAssertEqual(state.top.reportName, "home")
    XCTAssertEqual(state.named, .home)
  }

  /// Audit 3a: a link home from Chat closed Chat and left the report naming chat. Now home is in front and named,
  /// at once: there is nothing to wait for.
  func testALinkHomeFromChatLeavesHomeInFrontAndNamed() {
    var window = Window([.chat])
    window.link(.home)
    XCTAssertEqual(window.dismissed, [.chat])
    XCTAssertEqual(window.state.top, .home)
    XCTAssertEqual(window.state.top.reportName, "home")
    XCTAssertEqual(window.state.named, .home)
    XCTAssertEqual(window.waits, [], "nothing waits")
    XCTAssertNil(window.state.pending)
    XCTAssertEqual(window.presented, [])
  }

  func testALinkHomeLeavesASheetOverHomeUp() {
    var window = Window([.chat, .homeSettings])
    window.link(.home)
    XCTAssertEqual(window.state.stack, [.homeSettings])
    XCTAssertEqual(window.state.top.reportName, "home_settings")
  }

  /// Audit 3b, #818: two links inside the wait each presented. Now the second replaces the first, on the wait the
  /// first started, and the first's screen never comes up.
  func testASecondLinkInsideTheWaitReplacesTheFirst() {
    var window = Window([.chat])
    window.link(.places)
    XCTAssertEqual(window.dismissed, [.chat])
    XCTAssertEqual(window.state.pending?.route, .places)
    window.link(.cockpit)  // 100 ms later
    XCTAssertEqual(window.presented, [], "the covers are still going down: the second waits too")
    XCTAssertEqual(window.state.pending?.route, .cockpit)
    XCTAssertEqual(window.waits.count, 1, "on the wait already running")
    window.settle()
    XCTAssertEqual(window.presented, [.cockpit])
    XCTAssertEqual(window.state.stack, [.cockpit])
  }

  func testALinkHomeInsideTheWaitDropsTheWaitingScreen() {
    var window = Window([.timer])
    window.link(.breathe(BreatheLink(start: true)))
    window.link(.home)
    window.settle()
    XCTAssertEqual(window.presented, [])
    XCTAssertEqual(window.state.top, .home)
  }

  func testAWindowOfItsOwnOrTheSupermixInsideTheWaitShowsAtOnceAndDropsTheWaitingScreen() {
    var window = Window([.timer])
    window.link(.places)
    window.link(.cockpit, ownWindow: true)
    XCTAssertEqual(window.presented, [.cockpit], "its window comes forward now")
    window.settle()
    XCTAssertEqual(window.presented, [.cockpit])
    XCTAssertEqual(window.state.stack, [], "the home window shows nothing new")

    var again = Window([.timer])
    again.link(.places)
    again.link(.supermix)
    again.settle()
    XCTAssertEqual(again.presented, [.supermix])
  }

  func testATileChosenInsideTheWaitIsTheLatestAsk() {
    var window = Window([.timer])
    window.link(.places)
    window.state.open(.eulogySong)  // the song's tile
    window.settle()
    XCTAssertEqual(window.presented, [])
    XCTAssertEqual(window.state.stack, [.eulogySong])
  }

  func testAWaitALaterLinkStartedOverPresentsNothingEarly() {
    var state = State([.timer])
    guard case .wait(_, let first) = state.open(.places, from: "link", ownWindow: false).last else {
      return XCTFail("the first link waits")
    }
    XCTAssertEqual(state.settle(wait: first), [.present(.places, from: "link")])
    state.open(.places)
    guard case .wait(_, let second) = state.open(.today, from: "shortcut", ownWindow: false).last else {
      return XCTFail("the second closes Places and waits")
    }
    XCTAssertNotEqual(first, second)
    XCTAssertEqual(state.settle(wait: first), [], "a stale wait")
    XCTAssertEqual(state.settle(wait: second), [.present(.today, from: "shortcut")])
    XCTAssertEqual(state.settle(wait: second), [], "once")
  }

  /// The reducer over every link pair, from each kind of start: the second link wins. Whatever the first asked
  /// for, nothing of it is presented after the second arrives, the second is presented at most once, and when the
  /// second's screen lives in the home window it ends in front.
  func testEveryPairOfLinksTheSecondWins() {
    let routes: [AppRoute] = [
      .home, .today, .timer(TimerLink()), .timer(TimerLink(start: true)), .breathe(BreatheLink(start: true)),
      .places, .cockpit, .call(via: nil), .card(think: true), .chat(thread: nil), .chat(thread: "t"),
      .whiteboard(board: nil), .supermix,
    ]
    let starts: [[Screen]] = [[], [.timer], [.chat], [.today, .call], [.eulogySong], [.card, .drill]]
    for start in starts {
      for first in routes {
        for second in routes {
          let label = "\(start.map(\.reportName)): \(AppLink.link(for: first)) then \(AppLink.link(for: second))"
          var window = Window(start)
          window.link(first)
          let before = window.presented.count
          window.link(second)  // inside the first's wait, if it has one
          window.settle()
          let after = Array(window.presented[before...])
          XCTAssertLessThanOrEqual(after.filter { $0 == second }.count, 1, label)
          XCTAssertTrue(after.allSatisfy { $0 == second }, "only the second is presented: \(label) \(after)")
          XCTAssertNil(window.state.pending, label)
          if let screen = Screen(route: second) {
            XCTAssertEqual(window.state.front, screen, label)
          }
        }
      }
    }
  }

  // MARK: - Moved from LinksUITests' warm case and HoldPopoverUITests (test-ladder card 2)

  /// LinksUITests, warm: over the running timer, a breathing link closes the timer and begins breathing, and the
  /// workout gives way to it (story 188); an unknown link lands on home; a preset the timer does not know opens the
  /// timer, starting nothing, so the paused workout is found as it was.
  func testWarmLinksOverTheTimer() {
    var window = Window([.timer])
    let breathe = AppLink.parse("grabbernative://breathe?breath=5&minutes=2")
    XCTAssertTrue(breathe.understood)
    window.link(breathe.route)
    XCTAssertEqual(window.dismissed, [.timer])
    window.settle()
    XCTAssertEqual(window.presented, [.breathe(BreatheLink(breath: 5, minutes: 2, start: true))])
    XCTAssertEqual(window.state.stack, [.breathe], "the timer is gone, the session begun")
    XCTAssertEqual(
      AudioFloor.decide(.breatheOpens, holding: [.timer]), [.yield(.timer, to: "breathe")], "the workout pauses")

    let nowhere = AppLink.parse("grabbernative://nowhere")
    XCTAssertFalse(nowhere.understood)
    window.link(nowhere.route)
    XCTAssertEqual(window.state.top, .home, "an unknown link lands on home")

    let unknown = AppLink.parse("grabbernative://timer?preset=9min")
    XCTAssertFalse(unknown.understood)
    XCTAssertEqual(unknown.route, .timer(TimerLink()), "nothing started: the paused workout stays paused")
    window.link(unknown.route)
    XCTAssertEqual(window.presented.last, .timer(TimerLink()))
    XCTAssertEqual(window.state.top, .timer)
  }

  /// HoldPopoverUITests' "opens the right thing": from home, each popover choice that is a route brings up its
  /// screen at once with what it names started; the timer's presets start, the card's drill opens the card.
  func testEveryHeldChoiceOpensItsScreenFromHome() {
    for tile in ["gym_timer", "breathe", "think_a_card"] {
      for choice in HoldChoices.choices(forTile: tile) {
        guard case .route(let route) = choice.action else { continue }
        var window = Window()
        window.link(route)
        XCTAssertEqual(window.presented, [route], choice.id)
        XCTAssertEqual(window.state.top, Screen(route: route), choice.id)
      }
    }
    let oneMinute = HoldChoices.choices(forTile: "gym_timer").first { $0.id == "timer-1min" }
    XCTAssertEqual(oneMinute?.action, .route(.timer(TimerLink(preset: "1min", start: true))), "it starts")
    let drill = HoldChoices.choices(forTile: "think_a_card").first { $0.id == "card-drill" }
    XCTAssertEqual(drill?.action, .drill)
    var card = State()
    card.open(.card)
    card.open(.drill)
    XCTAssertEqual(card.top.reportName, "drill", "the drill over the card, as the popover opens it")
    let ai = HoldChoices.choices(forTile: "random").first { $0.id == "random-ai" }
    XCTAssertEqual(ai?.action, .randomPost(.ai), "AI leaves for the browser (BlogLinksTests has its link)")
  }
}
