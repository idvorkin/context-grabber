//  "Call Larry" as a Shortcuts action of the native app: it opens Grabber Native on the call screen and starts the
//  call on the remembered backend (or the one picked), or brings a live call forward. Same shape as the React
//  Native app's ios/ContextGrabber/CallLarryIntent.swift; docs/superpowers/specs/2026-08-29-call-larry-shortcut-design.md.
//  It goes through the same route as `grabbernative://call` (App/Links/LinkIntents.swift).

import AppIntents
import ContextCore

enum CallBackendOption: String, AppEnum {
  case eleven, gemini, openai, drill

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Backend")
  static let caseDisplayRepresentations: [CallBackendOption: DisplayRepresentation] = [
    .eleven: "ElevenLabs", .gemini: "Gemini", .openai: "OpenAI", .drill: "Drill",
  ]
}

struct CallLarryIntent: AppIntent {
  static let title: LocalizedStringResource = "Call Larry"
  static let description = IntentDescription("Start a voice call with Larry in Grabber Native. Keeps going when the phone locks.")
  static let openAppWhenRun = true

  @Parameter(title: "Backend", description: "Leave blank for the remembered backend.")
  var via: CallBackendOption?

  static var parameterSummary: some ParameterSummary {
    When(\.$via, .hasAnyValue) {
      Summary("Call Larry on \(\.$via)")
    } otherwise: {
      Summary("Call Larry")
    }
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    LinkLauncher.request(.call(via: via.flatMap { CallBackend(rawValue: $0.rawValue) }))
    return .result()
  }
}
