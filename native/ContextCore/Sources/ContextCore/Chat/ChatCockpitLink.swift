//  A link to a Cockpit thread (spec 2026-10-25-native-chat-design.md, Links in a thread: A Cockpit thread link opens
//  here; story 744), an Inbox question being a thread too. Two spellings name one: the Cockpit's own
//  https://<Cockpit host>/#thread/<key>, and the short `larry://inbox/<key>` Larry can write in plain text (a scheme
//  the app registers). Either opens that thread in the app when the list knows it; otherwise the Cockpit page.

import Foundation

public enum ChatCockpitLink {
  /// The app's short scheme for a Cockpit thread.
  public static let scheme = "larry"
  public static let prefix = scheme + "://"

  /// Where a tapped link goes instead of where iOS would send it.
  public enum Jump: Equatable, Sendable {
    /// The thread already on screen: nothing to open.
    case here
    case thread(String)
    /// A thread the list does not know: its page on the Cockpit.
    case web(URL)
  }

  /// The thread key a link names, in either spelling, or nil when it is not one.
  public static func threadKey(_ url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased() else { return nil }
    let raw: String
    if scheme == Self.scheme {
      // larry://inbox/<key>: the host is `inbox`, the path the key.
      guard url.host?.lowercased() == "inbox" else { return nil }
      raw = String(url.path.dropFirst())
    } else {
      guard scheme == "https" || scheme == "http", url.host?.lowercased() == CockpitPage.host,
        url.port == nil || url.port == 443, url.path.isEmpty || url.path == "/",
        let fragment = url.fragment, fragment.hasPrefix("thread/")
      else { return nil }
      raw = String(fragment.dropFirst("thread/".count))
    }
    let key = raw.removingPercentEncoding ?? raw
    guard !key.isEmpty, !key.contains("/"), !key.contains(where: \.isWhitespace) else { return nil }
    return key
  }

  /// The thread's page on the Cockpit.
  public static func webURL(_ key: String) -> URL? {
    let escaped = key.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? key
    return URL(string: "\(CockpitPage.url)/#thread/\(escaped)")
  }

  /// A tap on `url` in thread `current` (nil in a list): that thread opened in the app, nothing for this one, its
  /// Cockpit page when the list does not know it, or nil to open the link as any other.
  public static func jump(_ url: URL, from current: String?, known: Set<String>) -> Jump? {
    guard let key = threadKey(url) else { return nil }
    if key == current { return .here }
    if known.contains(key) { return .thread(key) }
    return webURL(key).map(Jump.web)
  }
}
