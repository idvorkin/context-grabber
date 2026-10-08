//  Grabber Native's links (story 135; spec docs/superpowers/specs/2026-10-06-native-links-design.md): what a
//  `grabbernative://` URL asks for, and the one link each route is written as — a Shortcuts action is logged as the
//  link it equals, and the Links screen lists them. Pure; the app does the opening.
//
//  Context Grabber owns `grabber://` on the phone until the cutover, so the native app registers its own scheme with
//  the same grammar, and reads a `grabber://` link the same way.

import Foundation

/// Where a link lands.
public enum AppRoute: Equatable, Sendable {
  case home
  case today
  case timer(TimerLink)
  case breathe(BreatheLink)
  case places
  case cockpit
  /// The call screen, calling on that backend (nil: the remembered one), or the live call brought forward.
  case call(via: CallBackend?)
  /// The card screen (story 129): face up, or with "think of a card" already counting.
  case card(think: Bool)
  /// Igor's Play Workout Supermix shortcut, run through Shortcuts (#220); the large widget's button (#221).
  case supermix

  /// The screen's name, as the log writes it.
  public var name: String {
    switch self {
    case .home: return "home"
    case .today: return "today"
    case .timer: return "timer"
    case .breathe: return "breathe"
    case .places: return "places"
    case .cockpit: return "cockpit"
    case .call: return "call"
    case .card: return "card"
    case .supermix: return "supermix"
    }
  }

  /// A route that runs something on arrival, rather than only showing a screen.
  public var starts: Bool {
    switch self {
    case .timer(let t): return t.start
    case .breathe(let b): return b.start
    case .call: return true
    case .card(let think): return think
    default: return false
    }
  }
}

/// The Gym Timer's half of a link: the simulator hook's grammar, a chip's id or "work,rest,rounds".
public struct TimerLink: Equatable, Sendable {
  /// A chip's id (`TimerProfile.presets`, or `custom` for the remembered Custom); nil for the remembered preset.
  public var preset: String?
  /// A one-off Custom workout, on the sliders' grid, not remembered.
  public var custom: CustomPreset?
  public var start: Bool

  public init(preset: String? = nil, custom: CustomPreset? = nil, start: Bool = false) {
    self.preset = preset
    self.custom = custom
    self.start = start
  }

  /// The chips a link can name.
  public static let presetIds = TimerProfile.presets.map(\.id) + [CustomPreset.id]
}

/// Box breathing's half of a link: a breath and a length, each nil for the remembered slider.
public struct BreatheLink: Equatable, Sendable {
  /// Seconds a side, inside the slider's range.
  public var breath: Int?
  /// Session minutes, inside the slider's range.
  public var minutes: Int?
  public var start: Bool

  public init(breath: Int? = nil, minutes: Int? = nil, start: Bool = false) {
    self.breath = breath
    self.minutes = minutes
    self.start = start
  }
}

public enum AppLink {
  /// The scheme the native app registers until the cutover.
  public static let scheme = "grabbernative"
  /// What it reads: its own, and Context Grabber's, which it takes over at the cutover.
  public static let schemes: Set<String> = ["grabbernative", "grabber"]

  public struct Parsed: Equatable, Sendable {
    public var route: AppRoute
    /// False when something in the link was not understood: an unknown route (then `route` is home), preset,
    /// backend, parameter or number. What was understood still routes.
    public var understood: Bool
  }

  public static func parse(_ string: String) -> Parsed {
    guard let url = URL(string: string) else { return Parsed(route: .home, understood: false) }
    return parse(url)
  }

  public static func parse(_ url: URL) -> Parsed {
    guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme),
      let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return Parsed(route: .home, understood: false) }
    // `grabbernative://timer` has the route as its host; `grabbernative:///timer` and `grabbernative:timer` as its path.
    let segments = ([parts.host ?? ""] + parts.path.split(separator: "/").map(String.init))
      .map { $0.lowercased() }.filter { !$0.isEmpty }
    var query: [String: String] = [:]
    for item in parts.queryItems ?? [] { query[item.name.lowercased()] = item.value ?? "" }
    var understood = segments.count <= 1
    /// Reads one parameter, and marks the link not understood for any parameter left unread at the end.
    var unread = Set(query.keys)
    func take(_ key: String) -> String? {
      unread.remove(key)
      return query[key]
    }
    func autostart(key: String = "autostart") -> Bool? {
      guard let value = take(key) else { return nil }
      if value == "1" || value == "true" { return true }
      if value == "0" || value == "false" { return false }
      understood = false
      return nil
    }
    func number(_ key: String, in range: ClosedRange<Int>) -> Int? {
      guard let value = take(key) else { return nil }
      guard let n = Int(value) else {
        understood = false
        return nil
      }
      return min(range.upperBound, max(range.lowerBound, n))
    }

    let route: AppRoute
    switch segments.first ?? "home" {
    case "home", "main":
      route = .home
    case "today", "grab":
      route = .today
    case "timer":
      var link = TimerLink()
      let start = autostart()
      if let preset = take("preset") {
        let numbers = preset.split(separator: ",", omittingEmptySubsequences: false).map { Int($0) }
        if TimerLink.presetIds.contains(preset.lowercased()) {
          link.preset = preset.lowercased()
          link.start = start ?? true
        } else if numbers.count == 3, let work = numbers[0], let rest = numbers[1], let rounds = numbers[2] {
          link.custom = CustomPreset(work: work, rest: rest, rounds: rounds).normalized
          link.start = start ?? true
        } else {
          understood = false  // the timer opens ready on the remembered preset
        }
      } else {
        link.start = start ?? false
      }
      route = .timer(link)
    case "breathe", "breathing":
      var link = BreatheLink()
      link.breath = number("breath", in: BreathPlan.breathRange)
      link.minutes = number("minutes", in: BreathPlan.sessionRange)
      link.start = autostart() ?? (link.breath != nil || link.minutes != nil)
      route = .breathe(link)
    case "places":
      route = .places
    case "cockpit":
      route = .cockpit
    case "call":
      var via: CallBackend?
      if let name = take("via"), !name.isEmpty {
        via = CallBackend(rawValue: name.lowercased())
        if via == nil { understood = false }
      }
      route = .call(via: via)
    case "card":
      route = .card(think: autostart(key: "think") ?? false)
    case "think":
      route = .card(think: true)
    case "supermix":
      route = .supermix
    default:
      return Parsed(route: .home, understood: false)
    }
    if !unread.isEmpty { understood = false }
    return Parsed(route: route, understood: understood)
  }

  /// The link that opens `route`: what a Shortcuts action is logged as, and what the Links screen copies.
  public static func link(for route: AppRoute) -> String {
    var items: [(String, String)] = []
    switch route {
    case .timer(let t):
      if let custom = t.custom {
        items.append(("preset", "\(custom.work),\(custom.rest),\(custom.rounds)"))
      } else if let preset = t.preset {
        items.append(("preset", preset))
      }
      let named = !items.isEmpty
      if t.start != named { items.append(("autostart", t.start ? "1" : "0")) }
    case .breathe(let b):
      if let breath = b.breath { items.append(("breath", String(breath))) }
      if let minutes = b.minutes { items.append(("minutes", String(minutes))) }
      let named = !items.isEmpty
      if b.start != named { items.append(("autostart", b.start ? "1" : "0")) }
    case .call(let via):
      if let via { items.append(("via", via.rawValue)) }
    case .card(let think):
      if think { items.append(("think", "1")) }
    default:
      break
    }
    let query = items.isEmpty ? "" : "?" + items.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    return "\(scheme)://\(route.name)\(query)"
  }

  public struct Entry: Equatable, Sendable {
    public var link: String
    /// One line saying what it does.
    public var summary: String
  }

  /// Every link the Links screen lists, in its order.
  public static let catalog: [Entry] = {
    let presets = TimerProfile.presets.map { p in
      (AppRoute.timer(TimerLink(preset: p.id, start: true)), "Gym Timer: \(p.label), started")
    }
    let rows: [(AppRoute, String)] =
      [
        (.home, "The home screen"),
        (.today, "Today, grabbing as it opens"),
        (.timer(TimerLink()), "Gym Timer, ready on the last preset"),
        (.timer(TimerLink(start: true)), "Gym Timer: the last preset, started"),
      ] + presets + [
        (.timer(TimerLink(preset: CustomPreset.id, start: true)), "Gym Timer: your Custom, started"),
        (
          .timer(TimerLink(custom: CustomPreset(work: 60, rest: 10, rounds: 5), start: true)),
          "Gym Timer: work, rest seconds and rounds, started (not remembered)"
        ),
        (.breathe(BreatheLink()), "Box breathing's sliders"),
        (.breathe(BreatheLink(start: true)), "Box breathing: the sliders' session, begun"),
        (.breathe(BreatheLink(minutes: 5, start: true)), "Box breathing: 5 minutes on your breath, begun"),
        (.breathe(BreatheLink(breath: 8, minutes: 5, start: true)), "Box breathing: 8-second breaths for 5 minutes"),
        (.places, "Places"),
        (.cockpit, "The Cockpit"),
        (.call(via: nil), "Call Larry on the remembered backend"),
        (.call(via: .eleven), "Call Larry on ElevenLabs (also gemini, openai, drill)"),
        (.card(think: false), "A playing card, face up; tap for another"),
        (.card(think: true), "Think of a card: face down, five seconds, then the reveal"),
        (.supermix, "Workout Supermix: runs your Play Workout Supermix shortcut"),
      ]
    return rows.map { Entry(link: link(for: $0.0), summary: $0.1) }
  }()
}
