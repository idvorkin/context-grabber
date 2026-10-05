//  What the Cockpit screen decides about the page, apart from WebKit: the address it loads (with the client tag,
//  #78 — the Swift port of lib/cockpitClient.ts), which navigations stay, and who gets the microphone without asking.
//  Spec: docs/superpowers/specs/2026-10-05-native-cockpit-design.md.

import Foundation

public enum CockpitPage {
  /// Igor's decision Cockpit, served only on the tailnet: reaching the host at all is the authentication.
  public static let url = "https://c-5004.squeaker-teeth.ts.net"
  public static let host = "c-5004.squeaker-teeth.ts.net"

  /// The app's own URL schemes, as the page opens them (its ☎ hands the call to the app as `grabber://call`).
  public static let appSchemes: Set<String> = ["grabber", "com.idvorkin.contextgrabber"]

  /// The URL with `client=context-grabber&v=<build>` on its query, before any `#route`. The native app says
  /// context-grabber too: it becomes Context Grabber at the cutover, and the build tells the two apart.
  public static func taggedURL(_ url: String, build: String) -> String {
    let hashAt = url.firstIndex(of: "#")
    let base = hashAt.map { String(url[..<$0]) } ?? url
    let hash = hashAt.map { String(url[$0...]) } ?? ""
    let separator = base.contains("?") ? "&" : "?"
    var tag = "client=\(CallProtocol.clientName)"
    if !build.isEmpty { tag += "&v=\(encodeComponent(build))" }
    return "\(base)\(separator)\(tag)\(hash)"
  }

  /// encodeURIComponent's unreserved set: letters, digits and - _ . ! ~ * ' ( ).
  static func encodeComponent(_ text: String) -> String {
    var allowed = CharacterSet.alphanumerics.intersection(.init(charactersIn: Unicode.Scalar(0)..<Unicode.Scalar(128)))
    allowed.insert(charactersIn: "-_.!~*'()")
    return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
  }

  public enum Navigation: Equatable, Sendable {
    /// Load it here.
    case stay
    /// One of the app's own links: the page handing something to the app.
    case appLink
    /// Somewhere else: the phone's browser, and the Cockpit stays where it was.
    case external
  }

  /// Keeps the screen pinned to the Cockpit — and with it the microphone grant scoped to one origin. `home` is the
  /// host the screen was opened on (the Cockpit, or a test page's); a local file stays.
  public static func navigation(to url: URL, home: String?) -> Navigation {
    guard let scheme = url.scheme?.lowercased() else { return .stay }
    if scheme == "about" || scheme == "file" || scheme == "blob" || scheme == "data" { return .stay }
    if appSchemes.contains(scheme) { return .appLink }
    if let home, url.host?.lowercased() == home.lowercased() { return .stay }
    return .external
  }

  /// The microphone is granted without a prompt to the page's own origin only; anything else gets iOS's prompt.
  public static func grantsMicrophone(originHost: String, home: String?) -> Bool {
    guard let home, !originHost.isEmpty else { return false }
    return originHost.lowercased() == home.lowercased()
  }
}
