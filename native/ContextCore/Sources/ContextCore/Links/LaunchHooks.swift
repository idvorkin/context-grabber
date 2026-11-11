//  The simulator cannot be shaken or tapped from a script, so the app reads launch hooks from the environment
//  (`SIMCTL_CHILD_<name>` through simctl); docs/TESTING.md lists them. This is their grammar, read once: `steps` is
//  what the app does at launch, in the order it does it, and the rest is what a screen reads when it appears. Each
//  feature's own grammar is in its directory (`BreatheHook`, `GymTimerHook`, `PlacesHook`, `ChatSendHook`,
//  `WhiteboardHooks`). Pure (#796); the app's `runLaunchHooks` does the work.

import Foundation

/// One thing a launch does, as its hook asked.
public enum LaunchHook: Equatable, Sendable {
  case breathe(BreatheHook)
  case timer(GymTimerHook)
  case importDatabase(ImportDatabaseHook)
  /// `GRABBER_RETENTION=<days>`.
  case retention(days: Int)
  /// `GRABBER_TRACKING=on`; anything else turns it off.
  case tracking(on: Bool)
  case places(PlacesHook)
  /// `GRABBER_EXPORT=1`.
  case export
  /// `GRABBER_DRILL=<mode>`, as written: the trainer's package reads the mode.
  case drill(String)
  /// `GRABBER_COCKPIT=open`, or `browser`.
  case cockpit
  case boardFixture(BoardFixtureHook)
  /// `GRABBER_WHITEBOARD=open`.
  case whiteboard
  /// `GRABBER_WHATS_NEW=open`.
  case whatsNew
  /// `GRABBER_HOME=settings`.
  case homeSettings
  /// `GRABBER_SUPERMIX=<mix>`.
  case supermix(WorkoutSupermix.Mix)
  /// `GRABBER_INBOX_FIXTURE=1`.
  case inboxFixture
  /// `GRABBER_INBOX=open`.
  case inbox
  /// `GRABBER_CHAT_SEND=<thread>|<text>`.
  case chatSend(ChatSendHook)
  /// `GRABBER_CHAT_SEND_FILE=<thread>|<path>`.
  case chatSendFile(ChatSendHook)
  /// `GRABBER_CHAT_SEND_AGAIN=1`.
  case chatSendAgain
  /// `GRABBER_CHAT_NEW=open`, or `voice` for the button beside it.
  case chatNew(voice: Bool)
  /// `GRABBER_ARCHIVE=run`.
  case archive
  /// `GRABBER_CALL=<bridge>`: a call, hung up after `GRABBER_CALL_SECONDS` (8 unless that is a number).
  case call(seconds: Double)
  /// `GRABBER_MIRROR=<mode>`, then `GRABBER_METRIC=<key>`'s sheet.
  case mirror(mode: String, metric: MetricKey?)
  /// `GRABBER_LINK=<url>`.
  case link(URL)
}

/// `GRABBER_WINDOW=<screen>[,again][,close]`. A screen that isn't one leaves `screen` nil: the hook still counts as run.
public struct WindowHook: Equatable, Sendable {
  public var screen: WindowScreen?
  public var steps: [String]
}

public struct LaunchHooks: Equatable, Sendable {
  /// What the launch does, in order: the import before the places hooks that read its trail, the link last.
  public var steps: [LaunchHook]
  /// What the Chat screens do by themselves once they show.
  public var chat: ChatViewHooks
  /// What a board does by itself.
  public var whiteboard: WhiteboardHooks
  /// `GRABBER_WINDOW_CHOOSE=<screen>`.
  public var windowChoose: WindowScreen?
  public var window: WindowHook?
  /// `GRABBER_SILENT=1`: this app's own sound at zero.
  public var silent: Bool
  /// `GRABBER_SONG=missing`: the eulogy song not found.
  public var songMissing: Bool
  /// `GRABBER_NO_ANIMATIONS=1`: UIKit's animations off, for the UI tests (story 754).
  public var noAnimations: Bool
  /// `GRABBER_COCKPIT_URL`, `GRABBER_USAGE_URL` and `GRABBER_CHAT_URL`, as written: `ChatCockpit` and the models
  /// decide what an empty one means.
  public var cockpitURL: String?
  public var usageURL: String?
  public var chatURL: String?
  /// `GRABBER_COCKPIT=browser`: the Cockpit opened, and its first page handed to the browser (story 326).
  public var cockpitOpenInBrowser: Bool

  public init(_ env: [String: String] = [:]) {
    steps = Self.steps(env)
    chat = ChatViewHooks(env)
    whiteboard = WhiteboardHooks(env)
    windowChoose = env["GRABBER_WINDOW_CHOOSE"].flatMap(WindowScreen.init(rawValue:))
    if let spec = env["GRABBER_WINDOW"] {
      let parts = spec.split(separator: ",").map(String.init)
      window = WindowHook(screen: parts.first.flatMap(WindowScreen.init(rawValue:)), steps: Array(parts.dropFirst()))
    }
    silent = env["GRABBER_SILENT"] == "1"
    songMissing = env["GRABBER_SONG"] == "missing"
    noAnimations = env["GRABBER_NO_ANIMATIONS"] == "1"
    cockpitURL = env["GRABBER_COCKPIT_URL"]
    usageURL = env["GRABBER_USAGE_URL"]
    chatURL = env["GRABBER_CHAT_URL"]
    cockpitOpenInBrowser = env["GRABBER_COCKPIT"] == "browser"
  }

  private static func steps(_ env: [String: String]) -> [LaunchHook] {
    var steps: [LaunchHook] = []
    func add(_ hook: LaunchHook?) { if let hook { steps.append(hook) } }
    add(BreatheHook(env).map(LaunchHook.breathe))
    add(GymTimerHook(env).map(LaunchHook.timer))
    // Places: import first, so the other hooks see the imported trail.
    add(ImportDatabaseHook(env).map(LaunchHook.importDatabase))
    add(env["GRABBER_RETENTION"].flatMap { Int($0) }.map { .retention(days: $0) })
    if let spec = env["GRABBER_TRACKING"], !spec.isEmpty { add(.tracking(on: spec == "on")) }
    add(PlacesHook(env).map(LaunchHook.places))
    if env["GRABBER_EXPORT"] == "1" { add(.export) }
    add(env["GRABBER_DRILL"].map(LaunchHook.drill))
    if env["GRABBER_COCKPIT"] == "open" || env["GRABBER_COCKPIT"] == "browser" { add(.cockpit) }
    add(BoardFixtureHook(env).map(LaunchHook.boardFixture))
    if env["GRABBER_WHITEBOARD"] == "open" { add(.whiteboard) }
    if env["GRABBER_WHATS_NEW"] == "open" { add(.whatsNew) }
    if env["GRABBER_HOME"] == "settings" { add(.homeSettings) }
    add(env["GRABBER_SUPERMIX"].flatMap(WorkoutSupermix.Mix.init(rawValue:)).map(LaunchHook.supermix))
    if env["GRABBER_INBOX_FIXTURE"] == "1" { add(.inboxFixture) }
    if env["GRABBER_INBOX"] == "open" { add(.inbox) }
    add(ChatSendHook(text: env["GRABBER_CHAT_SEND"]).map(LaunchHook.chatSend))
    add(ChatSendHook(file: env["GRABBER_CHAT_SEND_FILE"]).map(LaunchHook.chatSendFile))
    if env["GRABBER_CHAT_SEND_AGAIN"] == "1" { add(.chatSendAgain) }
    if env["GRABBER_CHAT_NEW"] == "open" || env["GRABBER_CHAT_NEW"] == "voice" {
      add(.chatNew(voice: env["GRABBER_CHAT_NEW"] == "voice"))
    }
    if env["GRABBER_ARCHIVE"] == "run" { add(.archive) }
    if let bridge = env["GRABBER_CALL"], !bridge.isEmpty {
      add(.call(seconds: Double(env["GRABBER_CALL_SECONDS"] ?? "") ?? 8))
    }
    if let mode = env["GRABBER_MIRROR"], !mode.isEmpty {
      add(.mirror(mode: mode, metric: env["GRABBER_METRIC"].flatMap(MetricKey.init(rawValue:))))
    }
    add(env["GRABBER_LINK"].flatMap { URL(string: $0) }.map(LaunchHook.link))
    return steps
  }
}
