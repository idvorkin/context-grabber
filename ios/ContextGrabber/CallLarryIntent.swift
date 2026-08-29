import Foundation
import UIKit

#if canImport(AppIntents)
import AppIntents

/// The backends the voice bridge offers. Mirrors `CallBackend` in
/// `lib/deepLink.ts`; the raw value is what goes into `grabber://call?via=`.
@available(iOS 16.0, *)
enum CallBackendOption: String, AppEnum {
  case gemini
  case eleven
  case openai
  case drill

  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Backend")
  static var caseDisplayRepresentations: [CallBackendOption: DisplayRepresentation] = [
    .gemini: "Gemini",
    .eleven: "ElevenLabs",
    .openai: "OpenAI",
    .drill: "Drill",
  ]
}

/// "Call Larry" as a Shortcuts action: the app comes to the front on the
/// Call tab and the call starts — the same route a `grabber://call` link
/// takes, so the link, the widget pill and this intent are one code path.
///
/// Lives in the app target (not the widget extension) because it must open
/// the app and then hand it the URL; `perform()` runs in-process once the
/// app is in front, so the JavaScript side's `Linking` listener is attached.
/// Spec: docs/superpowers/specs/2026-08-29-call-larry-shortcut-design.md.
@available(iOS 16.0, *)
struct CallLarryIntent: AppIntent {
  static var title: LocalizedStringResource = "Call Larry"
  static var description = IntentDescription(
    "Start a voice call with Larry on the Call tab. Keeps going when the phone locks.")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Backend", description: "Leave blank for the remembered backend.")
  var via: CallBackendOption?

  static var parameterSummary: some ParameterSummary {
    Summary("Call Larry on \(\.$via)")
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    var components = URLComponents()
    components.scheme = "grabber"
    components.host = "call"
    if let via {
      components.queryItems = [URLQueryItem(name: "via", value: via.rawValue)]
    }
    guard let url = components.url else { return .result() }
    await UIApplication.shared.open(url)
    return .result()
  }
}

/// The pre-built shortcut, so "Call Larry" exists in the Shortcuts app
/// without building one, and answers to Siri.
@available(iOS 16.0, *)
struct ContextGrabberShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CallLarryIntent(),
      phrases: [
        "Call Larry in \(.applicationName)",
        "Call Larry with \(.applicationName)",
        "Start a Larry call in \(.applicationName)",
      ],
      shortTitle: "Call Larry",
      systemImageName: "phone.fill"
    )
  }
}
#endif
