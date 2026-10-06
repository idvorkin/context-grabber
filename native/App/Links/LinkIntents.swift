//  Grabber Native's Shortcuts actions and Siri phrases (story 135; spec 2026-10-06-native-links-design.md). Each opens
//  the app and does what its link does: the intent hands the route to the app, which logs it as that link.

import AppIntents
import ContextCore

/// Where an intent hands its route to the app. Set by AppModel; a request that comes before it is kept.
@MainActor
enum LinkLauncher {
  static var handler: ((AppRoute) -> Void)? {
    didSet {
      guard let handler, let pending else { return }
      self.pending = nil
      handler(pending)
    }
  }
  private static var pending: AppRoute?

  static func request(_ route: AppRoute) {
    if let handler { handler(route) } else { pending = route }
  }
}

enum TimerPresetOption: String, AppEnum {
  case thirtySeconds = "30sec", oneMinute = "1min", twoMinutes = "2min", fiveOne = "5-1", custom

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Preset")
  static let caseDisplayRepresentations: [TimerPresetOption: DisplayRepresentation] = [
    .thirtySeconds: "30 SEC", .oneMinute: "1 MIN", .twoMinutes: "2 MIN", .fiveOne: "5-1", .custom: "Custom",
  ]
}

struct StartGymTimerIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Gym Timer"
  static let description = IntentDescription("Open Grabber Native's Gym Timer and start a workout.")
  static let openAppWhenRun = true

  @Parameter(title: "Preset", description: "Leave blank for the last preset used.")
  var preset: TimerPresetOption?

  static var parameterSummary: some ParameterSummary {
    When(\.$preset, .hasAnyValue) {
      Summary("Start \(\.$preset) on the Gym Timer")
    } otherwise: {
      Summary("Start the Gym Timer")
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    LinkLauncher.request(.timer(TimerLink(preset: preset?.rawValue, start: true)))
    return .result()
  }
}

struct StartBoxBreathingIntent: AppIntent {
  static let title: LocalizedStringResource = "Start Box Breathing"
  static let description = IntentDescription("Open Grabber Native's Box breathing and begin a session.")
  static let openAppWhenRun = true

  @Parameter(title: "Minutes", description: "2 to 15. Leave blank for the length on the sliders.")
  var minutes: Int?

  static var parameterSummary: some ParameterSummary {
    When(\.$minutes, .hasAnyValue) {
      Summary("Breathe for \(\.$minutes) minutes")
    } otherwise: {
      Summary("Start Box Breathing")
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    let range = BreathPlan.sessionRange
    let length = minutes.map { min(range.upperBound, max(range.lowerBound, $0)) }
    LinkLauncher.request(.breathe(BreatheLink(minutes: length, start: true)))
    return .result()
  }
}

struct OpenTodayIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Today"
  static let description = IntentDescription("Open Grabber Native on Today, which grabs as it opens.")
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    LinkLauncher.request(.today)
    return .result()
  }
}

struct OpenPlacesIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Places"
  static let description = IntentDescription("Open Grabber Native on Places.")
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    LinkLauncher.request(.places)
    return .result()
  }
}

struct OpenCockpitIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Cockpit"
  static let description = IntentDescription("Open Grabber Native on the Cockpit.")
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    LinkLauncher.request(.cockpit)
    return .result()
  }
}

struct GrabberNativeShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartGymTimerIntent(),
      phrases: [
        "Start Gym Timer in \(.applicationName)", "Start \(\.$preset) in \(.applicationName)",
        "Start a workout in \(.applicationName)",
      ],
      shortTitle: "Start Gym Timer",
      systemImageName: "timer")
    AppShortcut(
      intent: StartBoxBreathingIntent(),
      phrases: ["Start Box Breathing in \(.applicationName)", "Breathe with \(.applicationName)"],
      shortTitle: "Box Breathing",
      systemImageName: "wind")
    AppShortcut(
      intent: CallLarryIntent(),
      phrases: ["Call Larry in \(.applicationName)", "Call Larry with \(.applicationName)"],
      shortTitle: "Call Larry",
      systemImageName: "phone.fill")
    AppShortcut(
      intent: OpenTodayIntent(),
      phrases: ["Open Today in \(.applicationName)"],
      shortTitle: "Today",
      systemImageName: "heart.text.square")
    AppShortcut(
      intent: OpenPlacesIntent(),
      phrases: ["Open Places in \(.applicationName)"],
      shortTitle: "Places",
      systemImageName: "map")
    AppShortcut(
      intent: OpenCockpitIntent(),
      phrases: ["Open Cockpit in \(.applicationName)"],
      shortTitle: "Cockpit",
      systemImageName: "gauge.with.dots.needle.67percent")
  }
}
