import XCTest

@testable import ContextCore

/// Story 135: every link, its parameters, and what a bad link does.
final class AppLinkTests: XCTestCase {
  private func route(_ link: String) -> AppRoute { AppLink.parse(link).route }
  private func understood(_ link: String) -> Bool { AppLink.parse(link).understood }

  func testEveryScreenHasALink() {
    XCTAssertEqual(route("grabbernative://"), .home)
    XCTAssertEqual(route("grabbernative://home"), .home)
    XCTAssertEqual(route("grabbernative://today"), .today)
    XCTAssertEqual(route("grabbernative://grab"), .today)
    XCTAssertEqual(route("grabbernative://timer"), .timer(TimerLink()))
    XCTAssertEqual(route("grabbernative://breathe"), .breathe(BreatheLink()))
    XCTAssertEqual(route("grabbernative://places"), .places)
    XCTAssertEqual(route("grabbernative://cockpit"), .cockpit)
    XCTAssertEqual(route("grabbernative://call"), .call(via: nil))
    XCTAssertEqual(route("grabbernative://card"), .card(think: false))
    XCTAssertEqual(route("grabbernative://card?think=1"), .card(think: true))
    XCTAssertEqual(route("grabbernative://think"), .card(think: true))
    XCTAssertEqual(route("grabbernative://supermix"), .supermix)
    for link in ["grabbernative://", "grabbernative://today", "grabbernative://timer", "grabbernative://card"] {
      XCTAssertTrue(understood(link), link)
    }
  }

  func testContextGrabbersSchemeAndOtherSpellingsReadTheSame() {
    XCTAssertEqual(route("grabber://timer?preset=1min&autostart=1"), .timer(TimerLink(preset: "1min", start: true)))
    XCTAssertEqual(route("GrabberNative://Places"), .places)
    XCTAssertEqual(route("grabbernative:///cockpit"), .cockpit)
    XCTAssertEqual(route("grabbernative:today"), .today)
  }

  func testATimerPresetStartsIt() {
    XCTAssertEqual(route("grabbernative://timer?preset=1min"), .timer(TimerLink(preset: "1min", start: true)))
    XCTAssertEqual(route("grabbernative://timer?preset=5-1"), .timer(TimerLink(preset: "5-1", start: true)))
    XCTAssertEqual(route("grabbernative://timer?preset=custom"), .timer(TimerLink(preset: "custom", start: true)))
    XCTAssertEqual(route("grabbernative://timer?preset=2MIN"), .timer(TimerLink(preset: "2min", start: true)))
    XCTAssertEqual(route("grabbernative://timer?preset=30sec&autostart=0"), .timer(TimerLink(preset: "30sec")))
    XCTAssertEqual(route("grabbernative://timer?autostart=1"), .timer(TimerLink(start: true)))
  }

  func testWorkRestRoundsIsACustomWorkoutOnTheSlidersGrid() {
    XCTAssertEqual(
      route("grabbernative://timer?preset=10,10,2"),
      .timer(TimerLink(custom: CustomPreset(work: 10, rest: 10, rounds: 2), start: true)))
    XCTAssertTrue(understood("grabbernative://timer?preset=10,10,2"))
    // Snapped and clamped: 10 s to 10 min of work, 0 to 5 min of rest, 1 to 20 rounds.
    XCTAssertEqual(
      route("grabbernative://timer?preset=64,1000,40"),
      .timer(TimerLink(custom: CustomPreset(work: 60, rest: 300, rounds: 20), start: true)))
    XCTAssertEqual(
      route("grabbernative://timer?preset=0,0,0"),
      .timer(TimerLink(custom: CustomPreset(work: 10, rest: 0, rounds: 1), start: true)))
  }

  func testAnUnknownPresetOpensTheTimerReady() {
    for link in ["grabbernative://timer?preset=9min", "grabbernative://timer?preset=1,2", "grabbernative://timer?preset=a,b,c"] {
      XCTAssertEqual(route(link), .timer(TimerLink()), link)
      XCTAssertFalse(understood(link), link)
    }
    XCTAssertFalse(understood("grabbernative://timer?autostart=maybe"))
  }

  func testBreathingBeginsWithALengthOrABreath() {
    XCTAssertEqual(route("grabbernative://breathe?minutes=5"), .breathe(BreatheLink(minutes: 5, start: true)))
    XCTAssertEqual(
      route("grabbernative://breathe?breath=5&minutes=2"), .breathe(BreatheLink(breath: 5, minutes: 2, start: true)))
    XCTAssertEqual(route("grabbernative://breathe?breath=6"), .breathe(BreatheLink(breath: 6, start: true)))
    XCTAssertEqual(route("grabbernative://breathe?autostart=1"), .breathe(BreatheLink(start: true)))
    XCTAssertEqual(route("grabbernative://breathe?minutes=5&autostart=0"), .breathe(BreatheLink(minutes: 5)))
    // Into the sliders' ranges: 5–15 seconds a side, 2–15 minutes.
    XCTAssertEqual(
      route("grabbernative://breathe?breath=2&minutes=60"), .breathe(BreatheLink(breath: 5, minutes: 15, start: true)))
  }

  func testABreathOrLengthThatIsNotANumberIsIgnored() {
    XCTAssertEqual(route("grabbernative://breathe?minutes=lots"), .breathe(BreatheLink()))
    XCTAssertFalse(understood("grabbernative://breathe?minutes=lots"))
    XCTAssertEqual(route("grabbernative://breathe?breath=x&minutes=4"), .breathe(BreatheLink(minutes: 4, start: true)))
  }

  func testACallOnABackend() {
    XCTAssertEqual(route("grabbernative://call?via=eleven"), .call(via: .eleven))
    XCTAssertEqual(route("grabbernative://call?via=Gemini"), .call(via: .gemini))
    XCTAssertEqual(route("grabbernative://call?via=skype"), .call(via: nil))
    XCTAssertFalse(understood("grabbernative://call?via=skype"))
  }

  func testWhatIsNotALinkLandsOnHome() {
    for link in ["grabbernative://nowhere", "https://example.com/timer", "mailto:igor@example.com", "", "::::"] {
      XCTAssertEqual(route(link), .home, link)
      XCTAssertFalse(understood(link), link)
    }
  }

  func testATypoInAParameterOrAnExtraPathStillRoutesButIsFlagged() {
    XCTAssertEqual(route("grabbernative://timer?presets=1min"), .timer(TimerLink()))
    XCTAssertFalse(understood("grabbernative://timer?presets=1min"))
    XCTAssertEqual(route("grabbernative://cockpit/usage"), .cockpit)
    XCTAssertFalse(understood("grabbernative://cockpit/usage"))
    XCTAssertFalse(understood("grabbernative://places?x=1"))
  }

  func testEachRouteIsWrittenAsOneLinkThatReadsBackToIt() {
    let routes: [AppRoute] = [
      .home, .today, .places, .cockpit, .card(think: false), .card(think: true), .supermix, .call(via: nil), .call(via: .drill),
      .timer(TimerLink()), .timer(TimerLink(start: true)), .timer(TimerLink(preset: "1min", start: true)),
      .timer(TimerLink(preset: "2min")), .timer(TimerLink(custom: CustomPreset(work: 30, rest: 0, rounds: 4), start: true)),
      .breathe(BreatheLink()), .breathe(BreatheLink(start: true)), .breathe(BreatheLink(minutes: 3, start: true)),
      .breathe(BreatheLink(breath: 7, minutes: 10, start: true)), .breathe(BreatheLink(minutes: 3)),
    ]
    for r in routes {
      let link = AppLink.link(for: r)
      XCTAssertTrue(link.hasPrefix("grabbernative://"), link)
      XCTAssertEqual(AppLink.parse(link), AppLink.Parsed(route: r, understood: true), link)
    }
    XCTAssertEqual(AppLink.link(for: .timer(TimerLink(preset: "1min", start: true))), "grabbernative://timer?preset=1min")
    XCTAssertEqual(
      AppLink.link(for: .breathe(BreatheLink(breath: 8, minutes: 5, start: true))),
      "grabbernative://breathe?breath=8&minutes=5")
    XCTAssertEqual(AppLink.link(for: .timer(TimerLink(start: true))), "grabbernative://timer?autostart=1")
  }

  func testTheLinksScreenListsEveryScreenOnceEachUnderstood() {
    let links = AppLink.catalog.map(\.link)
    XCTAssertEqual(Set(links).count, links.count, "no link twice")
    let screens = Set(AppLink.catalog.map { AppLink.parse($0.link).route.name })
    XCTAssertEqual(screens, ["home", "today", "timer", "breathe", "places", "cockpit", "call", "card", "supermix"])
    for entry in AppLink.catalog {
      XCTAssertTrue(AppLink.parse(entry.link).understood, entry.link)
      XCTAssertFalse(entry.summary.isEmpty)
    }
    XCTAssertTrue(links.contains("grabbernative://timer?preset=60,10,5"))
    XCTAssertTrue(links.contains("grabbernative://breathe?minutes=5"))
  }
}
