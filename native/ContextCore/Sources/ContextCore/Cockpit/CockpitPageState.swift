//  What the Cockpit screen shows over its web view, as one value fed by WebKit's navigation events: a spinner while a
//  page loads, the page once it finished, or the "Can't reach the Cockpit" panel for the page that failed. Any
//  navigation that starts goes back to loading, so the panel never outlives the page it was about (state-machine
//  audit finding 6: Back after a 404 loaded the page under a panel that stayed). Spec:
//  docs/superpowers/specs/2026-10-05-native-cockpit-design.md, "Can't connect".

import Foundation

extension CockpitPage {
  public enum Page: Equatable, Sendable {
    /// A navigation is in flight; `since` times the load for the log.
    case loading(since: Date)
    case shown(url: String)
    /// The panel: why, and the address it names.
    case failed(why: String, url: String)
  }

  /// WebKit's delegate callbacks for the main frame, and the screen's own load.
  public enum Event: Equatable, Sendable {
    /// A navigation started (a load, Back, Cockpit, Try again, a reload, a link); `url` is where it goes, when known.
    case started(url: String?, at: Date)
    /// The main frame's HTTP answer; `text` is the status's words.
    case httpStatus(Int, text: String)
    case finished(url: String?)
    /// The navigation failed; `cancelled` when another navigation replaced it, which is not a failure.
    case failed(why: String, cancelled: Bool)
    /// The back list changed (a page's own pushState moves it without a finish).
    case backList(canGoBack: Bool)
  }

  public struct State: Equatable, Sendable {
    public private(set) var page: Page
    /// Back shows: the web view has a page to go back to.
    public private(set) var canGoBack = false
    /// Cockpit shows: the page in front is not the dashboard's start page.
    public private(set) var awayFromHome = false
    /// The address Igor would type: what the panel names for the start page or a navigation with no URL.
    public let address: String
    /// The start page's address as loaded (with the client tag); its host and path say what the start page is.
    let start: URL?
    private var inFlight: String?
    private var httpError: String?

    public init(address: String, start: URL?, now: Date) {
      self.address = address
      self.start = start
      page = .loading(since: now)
    }

    public var isLoading: Bool {
      if case .loading = page { return true }
      return false
    }

    /// The dashboard's own page: the start address's host and path (the query carries the client tag).
    public func isStartPage(_ url: URL) -> Bool {
      guard let start else { return false }
      return url.host == start.host && url.path == start.path
    }

    public mutating func apply(_ event: Event) {
      switch event {
      case .started(let url, let at):
        page = .loading(since: at)
        inFlight = url
        httpError = nil
      case .httpStatus(let status, let text):
        if status >= 400 { httpError = "HTTP \(status) — \(text)" }
      case .finished(let url):
        awayFromHome = url.flatMap(URL.init(string:)).map { !isStartPage($0) } ?? false
        if let httpError {
          page = .failed(why: httpError, url: shown(url ?? inFlight))
        } else {
          page = .shown(url: url ?? inFlight ?? address)
        }
        httpError = nil
      case .failed(let why, let cancelled):
        guard !cancelled else { return }
        page = .failed(why: why, url: shown(inFlight))
      case .backList(let back):
        canGoBack = back
      }
    }

    /// The panel names the address Igor would type for the start page, the page's own address otherwise.
    private func shown(_ url: String?) -> String {
      guard let url, let parsed = URL(string: url), !isStartPage(parsed) else { return address }
      return url
    }
  }
}
