//  The Cockpit screen's loading / page / panel state (spec 2026-10-05-native-cockpit-design.md, "Can't connect";
//  stories 096, 200), fed WebKit's events as CockpitModel's delegate passes them.

import XCTest

@testable import ContextCore

final class CockpitPageStateTests: XCTestCase {
  private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  private let home = "https://cockpit.test/?client=context-grabber&v=abc"
  private let away = "https://cockpit.test/lavish/page"

  private func fresh() -> CockpitPage.State {
    CockpitPage.State(address: "https://cockpit.test", start: URL(string: home), now: t0)
  }

  /// The start page, loaded: the screen as it opens.
  private func onHome() -> CockpitPage.State {
    var s = fresh()
    s.apply(.started(url: home, at: t0))
    s.apply(.finished(url: home))
    return s
  }

  func testItOpensLoadingAndAGoodFinishShowsThePage() {
    var s = fresh()
    XCTAssertEqual(s.page, .loading(since: t0))
    XCTAssertTrue(s.isLoading)
    s.apply(.started(url: home, at: t0))
    s.apply(.httpStatus(200, text: "no error"))
    s.apply(.finished(url: home))
    XCTAssertEqual(s.page, .shown(url: home))
    XCTAssertFalse(s.awayFromHome)
    XCTAssertFalse(s.canGoBack)
  }

  /// Audit finding 6: a 404, then Back. Today the panel stayed over the page Back loaded.
  func testA404ThenBackLoadsAndShowsThePageWithNoPanel() {
    var s = onHome()
    s.apply(.started(url: away, at: t0))
    s.apply(.httpStatus(404, text: "not found"))
    s.apply(.backList(canGoBack: true))
    s.apply(.finished(url: away))
    XCTAssertEqual(s.page, .failed(why: "HTTP 404 — not found", url: away))
    XCTAssertTrue(s.canGoBack, "Back stays under the panel, so the failed page can be left")
    XCTAssertTrue(s.awayFromHome)

    let back = t0.addingTimeInterval(5)
    s.apply(.started(url: home, at: back))
    XCTAssertEqual(s.page, .loading(since: back), "the tap takes the panel down at once")
    s.apply(.backList(canGoBack: false))
    s.apply(.finished(url: home))
    XCTAssertEqual(s.page, .shown(url: home))
    XCTAssertFalse(s.canGoBack)
    XCTAssertFalse(s.awayFromHome)
  }

  /// Was sim-smoke.sh's unreachable-panel wait: an unreachable Cockpit is the panel with its reason and the address
  /// Igor would type, never a blank page; Try again goes back to loading, and a good load shows the page.
  func testAnUnreachableCockpitIsThePanelAndTryAgainRecovers() {
    var s = fresh()
    s.apply(.started(url: home, at: t0))
    s.apply(.failed(why: "Could not connect to the server. (NSURLErrorDomain -1004)", cancelled: false))
    XCTAssertEqual(
      s.page, .failed(why: "Could not connect to the server. (NSURLErrorDomain -1004)", url: "https://cockpit.test"))
    XCTAssertFalse(s.isLoading)
    s.apply(.started(url: nil, at: t0))
    XCTAssertTrue(s.isLoading)
    s.apply(.finished(url: home))
    XCTAssertEqual(s.page, .shown(url: home))
  }

  func testACancelledNavigationIsNotAFailure() {
    var s = onHome()
    s.apply(.started(url: away, at: t0))
    s.apply(.failed(why: "cancelled", cancelled: true))
    XCTAssertTrue(s.isLoading, "the navigation that replaced it decides")
    s.apply(.started(url: home, at: t0))
    s.apply(.finished(url: home))
    XCTAssertEqual(s.page, .shown(url: home))
  }

  func testAnHTTPErrorBelongsToItsOwnNavigation() {
    var s = onHome()
    s.apply(.started(url: away, at: t0))
    s.apply(.httpStatus(500, text: "internal server error"))
    // A second tap replaces the failing load before it finishes.
    s.apply(.started(url: home, at: t0))
    s.apply(.finished(url: home))
    XCTAssertEqual(s.page, .shown(url: home), "the 500 was the other page's")
    s.apply(.httpStatus(399, text: "?"))
    s.apply(.finished(url: home))
    XCTAssertEqual(s.page, .shown(url: home), "below 400 is not an error")
  }

  func testAFailureAfterAShownPageBringsThePanelForThatPage() {
    var s = onHome()
    s.apply(.started(url: away, at: t0))
    s.apply(.failed(why: "The network connection was lost.", cancelled: false))
    XCTAssertEqual(s.page, .failed(why: "The network connection was lost.", url: away))
    // A pull to refresh or the page's own reload also starts a navigation.
    s.apply(.started(url: away, at: t0))
    s.apply(.finished(url: away))
    XCTAssertEqual(s.page, .shown(url: away))
  }

  /// Was CockpitBackUITests' "which buttons show": no Back on the start page, Back and Cockpit on a page the
  /// dashboard opened, Back gone once back on the dashboard, Cockpit from two pages deep.
  func testBackAndCockpitFollowTheBackListAndThePageInFront() {
    var s = onHome()
    XCTAssertFalse(s.canGoBack, "no Back on the start page")
    XCTAssertFalse(s.awayFromHome, "no Cockpit on the start page")
    s.apply(.started(url: away, at: t0))
    s.apply(.backList(canGoBack: true))
    s.apply(.finished(url: away))
    XCTAssertTrue(s.canGoBack)
    XCTAssertTrue(s.awayFromHome)
    s.apply(.started(url: away + "?deeper=1", at: t0))
    s.apply(.finished(url: away + "?deeper=1"))
    XCTAssertTrue(s.awayFromHome, "two pages deep")
    s.apply(.started(url: home, at: t0))
    s.apply(.backList(canGoBack: false))
    s.apply(.finished(url: home))
    XCTAssertFalse(s.canGoBack, "Back goes on the dashboard")
    XCTAssertFalse(s.awayFromHome)
    // The page's own pushState moves the back list with no finish.
    s.apply(.backList(canGoBack: true))
    XCTAssertTrue(s.canGoBack)
    XCTAssertEqual(s.page, .shown(url: home))
  }

  func testTheStartPageIsItsHostAndPathWhateverTheQuery() throws {
    let s = fresh()
    XCTAssertTrue(s.isStartPage(try XCTUnwrap(URL(string: "https://cockpit.test/?client=x"))))
    XCTAssertFalse(s.isStartPage(try XCTUnwrap(URL(string: "https://cockpit.test/other"))))
    XCTAssertFalse(s.isStartPage(try XCTUnwrap(URL(string: "https://elsewhere.test/"))))
    let none = CockpitPage.State(address: "nowhere", start: nil, now: t0)
    XCTAssertFalse(none.isStartPage(try XCTUnwrap(URL(string: "https://cockpit.test/"))))
  }
}
