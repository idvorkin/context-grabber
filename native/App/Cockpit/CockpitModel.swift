//  The Cockpit (stories 096–098, 200; spec docs/superpowers/specs/2026-10-05-native-cockpit-design.md): Igor's
//  tailnet-only dashboard in a WKWebView, with the audio bridge (docs/cockpit-audio-bridge.md) behind it.
//
//  The model owns the web view and lives as long as the app, so closing the screen hides the page rather than
//  throwing it away: scroll, expanded rows and a recording in progress survive, as they did across the tab switch.

import ContextCore
import SwiftUI
import UIKit
import WebKit

@MainActor
final class CockpitModel: NSObject, ObservableObject {
  struct LoadError: Equatable {
    let message: String
    let url: String
  }

  @Published private(set) var loading = true
  @Published private(set) var error: LoadError?
  /// #234: a page the dashboard opened in place can be backed out of.
  @Published private(set) var canGoBack = false
  /// The page in front is not the dashboard's start page.
  @Published private(set) var awayFromHome = false
  private var backObservation: NSKeyValueObservation?

  private let log: SessionLog
  private let route: AudioRouteController
  /// The address Igor would type (the error panel shows it) and the one loaded, with the client tag.
  let address: String
  private let loadURL: URL?
  private let home: String?
  /// Where the page's call hand-off and its Grabber links go: the app's own screens (story 200), not Context Grabber.
  var onAppRoute: ((AppRoute, String) -> Void)?
  /// The page sends its ☎ twice — the message, then its fallback link — so a second call hand-off this soon is the
  /// same tap.
  private var lastCallHandoff: Date?
  private var loadStarted = Date()
  private var pendingHTTPError: String?
  /// Only the page knows when its call is live; the screen is held for exactly that long (keep-awake spec).
  private var callLive = false

  private(set) lazy var webView: WKWebView = makeWebView()

  /// `override`: a URL, or the name of an HTML page in the app bundle (the simulator's bridge test page).
  init(log: SessionLog, override: String? = nil) {
    self.log = log
    route = AudioRouteController(log: log)
    let raw = override.flatMap { $0.isEmpty ? nil : $0 } ?? CockpitPage.url
    var base: URL?
    if raw.contains("://") {
      base = URL(string: raw)
    } else {
      base = Bundle.main.url(forResource: (raw as NSString).deletingPathExtension, withExtension: "html")
    }
    address = base?.absoluteString ?? raw
    loadURL = base.flatMap { URL(string: CockpitPage.taggedURL($0.absoluteString, build: BuildInfo.sha)) }
    home = base?.host
    super.init()
    route.onRouteChange = { [weak self] snapshot, reason in
      self?.emit(AudioBridge.routeChangedPayload(snapshot, reason: reason))
    }
  }

  private func makeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    // Audio plays in place and starts without a tap (the call's replies, the page's playback).
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []
    config.allowsAirPlayForMediaPlayback = true
    let controller = WKUserContentController()
    // Before any page script, so the page can feature-detect the bridge on its first line.
    controller.addUserScript(
      WKUserScript(source: AudioBridge.installScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
    // The controller retains its handler; the model lives as long as the app, so the cycle costs nothing.
    controller.add(self, name: AudioBridge.messageHandler)
    config.userContentController = controller

    let web = WKWebView(frame: .zero, configuration: config)
    web.navigationDelegate = self
    // Back-forward list changes (including the page's own pushState) move canGoBack without a didFinish.
    backObservation = web.observe(\.canGoBack, options: [.new]) { [weak self] web, _ in
      Task { @MainActor in self?.canGoBack = web.canGoBack }
    }
    web.uiDelegate = self
    web.allowsBackForwardNavigationGestures = true
    web.isOpaque = false
    web.backgroundColor = UIColor(cockpitBackground)
    web.scrollView.backgroundColor = UIColor(cockpitBackground)
    #if DEBUG
      web.isInspectable = true  // Safari's Web Inspector on a development build
    #endif
    let refresh = UIRefreshControl()
    refresh.addTarget(self, action: #selector(pulled), for: .valueChanged)
    web.scrollView.refreshControl = refresh
    load(into: web)
    return web
  }

  // MARK: - opening and loading

  /// The screen came to the front: ready the audio session for recording if something else reshaped it.
  func appeared() {
    route.activateIfNeeded()
    _ = webView
  }

  private func load(into web: WKWebView) {
    guard let loadURL else {
      fail("Not a URL: \(address)")
      return
    }
    loading = true
    error = nil
    setCallLive(false, why: "load")
    if loadURL.isFileURL {
      web.loadFileURL(loadURL, allowingReadAccessTo: loadURL.deletingLastPathComponent())
    } else {
      web.load(URLRequest(url: loadURL))
    }
  }

  /// Try again: a fresh load rather than reload(), which is unreliable after a failed first load.
  func retry() {
    log.event("ui", ["action": "cockpit_retry"])
    load(into: webView)
  }

  @objc private func pulled() {
    log.event("ui", ["action": "cockpit_pull_refresh"])
    webView.reload()
  }

  private func finished(ok: Bool, message: String? = nil) {
    loading = false
    webView.scrollView.refreshControl?.endRefreshing()
    var fields: [String: Any] = [
      "url": webView.url?.absoluteString ?? loadURL?.absoluteString ?? address, "ok": ok,
      "ms": Int(Date().timeIntervalSince(loadStarted) * 1000),
    ]
    if let message { fields["error"] = message }
    log.event("cockpit_load", fields)
  }

  private func fail(_ message: String) {
    finished(ok: false, message: message)
    setCallLive(false, why: "load_failed")
    error = LoadError(message: message, url: address)
  }

  /// What Copy error puts on the clipboard: enough to debug without the session log.
  func errorReport() -> String {
    guard let error else { return "" }
    return [
      "Error: \(error.message)", "Context: CockpitView.load", "URL: \(error.url)",
      "Build: \(BuildInfo.sha) \(BuildInfo.branch)", "Log: \(log.url.lastPathComponent)",
    ].joined(separator: "\n")
  }

  // MARK: - keep awake

  private func setCallLive(_ live: Bool, why: String) {
    guard live != callLive else { return }
    callLive = live
    // ponytail: the Gym Timer writes the same flag; both are full-screen and a page call hands off to the app, so
    // they do not overlap today. A shared hold with reasons is the upgrade if they ever do.
    UIApplication.shared.isIdleTimerDisabled = live
    log.event("keep_awake", ["on": live, "reason": "cockpit_call", "why": why])
  }

  // MARK: - the bridge

  private func emit(_ payload: [String: Any]) {
    var fields: [String: Any] = ["dir": "out", "kind": payload["type"] as? String ?? "?"]
    if let id = payload["requestId"] { fields["request_id"] = id }
    if let reason = payload["reason"] { fields["reason"] = reason }
    if let message = payload["message"] { fields["message"] = message }
    if let inputs = payload["inputs"] as? [Any] { fields["inputs"] = inputs.count }
    log.event("cockpit_bridge", fields)
    webView.evaluateJavaScript(AudioBridge.emitScript(payload)) { [log] _, error in
      if let error { log.event("cockpit_bridge", ["dir": "out", "ok": false, "message": error.localizedDescription]) }
    }
  }

  private func received(_ message: PageMessage) {
    var fields: [String: Any] = ["dir": "in", "kind": message.kind]
    switch message {
    case .audio(let request):
      if let id = request.requestId { fields["request_id"] = id }
      log.event("cockpit_bridge", fields)
      answer(request)
    case .callState(let live):
      fields["live"] = live
      log.event("cockpit_bridge", fields)
      setCallLive(live, why: "page")
    case .call(let control):
      if case .start(let via) = control {
        fields["via"] = via?.rawValue ?? "none"
        fields["handled"] = handOff(.call(via: via), from: "cockpit")
      } else {
        fields["handled"] = false
      }
      log.event("cockpit_bridge", fields)
    }
  }

  /// Hands a route to the app; false when it is a repeat of the call hand-off just handled, or nobody is listening.
  private func handOff(_ route: AppRoute, from source: String) -> Bool {
    guard let onAppRoute else { return false }
    if case .call = route {
      if let last = lastCallHandoff, Date().timeIntervalSince(last) < 5 { return false }
      lastCallHandoff = Date()
    }
    onAppRoute(route, source)
    return true
  }

  /// Every request gets exactly one answer: a roster (also the receipt for a set) or an error naming the op.
  private func answer(_ request: BridgeRequest) {
    do {
      switch request {
      case .setInput(let id, _): try route.setInput(id)
      case .setOutput(let port, _): try route.setOutput(port)
      case .listDevices, .getRoute: break
      }
      let snapshot = route.snapshot()
      route.logRoute(request.type, snapshot)
      emit(AudioBridge.devicesPayload(snapshot, requestId: request.requestId))
    } catch {
      emit(AudioBridge.errorPayload(op: request.type, message: error.localizedDescription, requestId: request.requestId))
    }
  }
}

extension CockpitModel: WKScriptMessageHandler {
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    let body = message.body as? String
    // Not ours: the page owns postMessage and may use it for something else.
    guard let parsed = AudioBridge.parse(body) else {
      log.event("cockpit_bridge", ["dir": "in", "kind": "unrecognized", "bytes": body?.utf8.count ?? -1])
      return
    }
    received(parsed)
  }
}

extension CockpitModel {
  /// #234: one page back, as Safari's Back.
  func goBack() {
    log.event("cockpit_back", ["from": webView.url?.absoluteString ?? "", "to": webView.backForwardList.backItem?.url.absoluteString ?? ""])
    webView.goBack()
  }

  /// #234: straight to the dashboard's start page, from any depth.
  func goHome() {
    guard let loadURL else { return }
    log.event("cockpit_home", ["from": webView.url?.absoluteString ?? ""])
    if let first = webView.backForwardList.backList.first, isStartPage(first.url) {
      webView.go(to: first)
    } else {
      webView.load(URLRequest(url: loadURL))
    }
  }

  /// The dashboard's own page: the start address's host and path (the query carries the client tag).
  func isStartPage(_ url: URL) -> Bool {
    guard let loadURL else { return false }
    return url.host == loadURL.host && url.path == loadURL.path
  }
}

extension CockpitModel: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = action.request.url else { return decisionHandler(.allow) }
    // Frames inside the page load what they load; the rule is for where the page itself goes.
    if let frame = action.targetFrame, !frame.isMainFrame { return decisionHandler(.allow) }
    let where_ = CockpitPage.navigation(to: url, home: home)
    if where_ == .stay { return decisionHandler(.allow) }
    // A Grabber link stays in this app (grabber://call is the page's ☎ fallback); anything else goes to iOS.
    if where_ == .appLink, AppLink.schemes.contains(url.scheme?.lowercased() ?? "") {
      let handled = handOff(AppLink.parse(url).route, from: "cockpit_link")
      log.event("cockpit_link", ["url": url.absoluteString, "kind": "app", "in_app": true, "handled": handled])
      return decisionHandler(.cancel)
    }
    log.event("cockpit_link", ["url": url.absoluteString, "kind": where_ == .appLink ? "app" : "external"])
    UIApplication.shared.open(url)
    decisionHandler(.cancel)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
    decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void
  ) {
    if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
      let text = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
      pendingHTTPError = "HTTP \(http.statusCode) — \(text)"
    }
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    loadStarted = Date()
    pendingHTTPError = nil
    loading = true
    setCallLive(false, why: "load")  // a reload ends whatever call the old page had
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    canGoBack = webView.canGoBack
    awayFromHome = webView.url.map { !isStartPage($0) } ?? false
    log.event("cockpit_page", ["url": webView.url?.absoluteString ?? "", "can_go_back": webView.canGoBack])
    if let http = pendingHTTPError {
      fail(http)
      return
    }
    finished(ok: true)
    emit(AudioBridge.readyPayload(available: true))
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error
  ) {
    failed(error)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
    failed(error)
  }

  private func failed(_ error: any Error) {
    let ns = error as NSError
    // A navigation replaced by another (a second tap, a reload mid-load) is not a failure.
    if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return }
    fail("\(ns.localizedDescription) (\(ns.domain) \(ns.code))")
  }

  /// iOS reclaims the web content process under memory pressure; without a reload the screen comes back empty.
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    log.event("cockpit_load", ["ok": false, "error": "web content process terminated", "action": "reload"])
    setCallLive(false, why: "process_terminated")
    webView.reload()
  }
}

extension CockpitModel: WKUIDelegate {
  /// The microphone is the Cockpit's without a second prompt (iOS's own app-wide alert still comes first); any
  /// other origin gets iOS's prompt.
  func webView(
    _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
    type: WKMediaCaptureType, decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
  ) {
    let host = origin.host
    let grant = CockpitPage.grantsMicrophone(originHost: host, home: home)
    log.event("cockpit_media", ["origin": host, "type": type == .microphone ? "microphone" : "camera", "granted": grant])
    decisionHandler(grant ? .grant : .prompt)
  }

  /// No second windows: a target=_blank link follows the same rule as any other navigation.
  func webView(
    _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    if let url = action.request.url {
      if CockpitPage.navigation(to: url, home: home) == .stay {
        webView.load(action.request)
      } else {
        log.event("cockpit_link", ["url": url.absoluteString, "kind": "new_window"])
        UIApplication.shared.open(url)
      }
    }
    return nil
  }
}

let cockpitBackground = Color(red: 0.102, green: 0.102, blue: 0.180)
