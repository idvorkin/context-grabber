//  Story 1222 (beads context-grabber-wvpv, context-grabber-yfsz): Settings → PaperKit board shows its tool picker and
//  the picker's + at once, the + offers the shapes, and a finger stroke lands on the page. On build 5569178f none of
//  that showed on the iPad ("Nothing there?"), and nothing caught it: this is the check that would have.
//  Run it on an iPad simulator; on a phone it skips (the row is not there).
//  Run: xcodebuild … -only-testing:GrabberNativeUITests/IPadPaperKitBoardUITests

import XCTest

final class IPadPaperKitBoardUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testThePickersPlusOffersTheShapesAndAFingerDraws() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "an iPad simulator only")
    let app = XCUIApplication.forTests()
    app.launch()
    app.openHomeSettings()
    let row = app.buttons["home-paperkit-board"]
    for _ in 0..<6 where !(row.exists && row.isHittable) { app.swipeUp() }
    XCTAssertTrue(row.appears(within: 5), "the PaperKit board row: \(app.debugDescription)")
    row.tap()

    // The picker and its + show with nothing tapped on the page first, the page full screen, not in Settings' sheet.
    let insert = app.buttons["paperkit-board-insert"]
    XCTAssertTrue(insert.appears(within: 5), "the tool picker's +: \(app.debugDescription)")

    // A finger stroke lands on the page.
    let page = app.otherElements["paperkit-board"]
    XCTAssertTrue(page.appears(within: 5), app.debugDescription)
    XCTAssertEqual(page.value as? String, "0 elements", "the empty page before the stroke")
    let start = page.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35))
    start.press(forDuration: 0.05, thenDragTo: page.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.45)))
    let drew = NSPredicate(format: "value MATCHES '[1-9][0-9]* elements'")
    let landed = XCTNSPredicateExpectation(predicate: drew, object: page)
    XCTAssertEqual(XCTWaiter().wait(for: [landed], timeout: 5), .completed, "page: \(page.value ?? "nil")")

    // The + offers the shapes and a text box (PaperKit's own insert menu).
    insert.tap()
    XCTAssertTrue(app.staticTexts["Add Shape"].appears(within: 5), "the insert menu: \(app.debugDescription)")
    XCTAssertTrue(app.staticTexts["Add Text"].exists, "the insert menu: \(app.debugDescription)")
  }

  /// Story 1335 (bead context-grabber-lyr4): a real board keeps only its ink, so its tool picker offers no **+**, no
  /// shapes and no text box. Only the scratch page above, which keeps nothing, has them.
  func testARealBoardsPickerOffersNoShapesOrText() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "an iPad simulator only")
    let app = XCUIApplication.forTests(animated: true)
    app.launchEnvironment["GRABBER_WHITEBOARD"] = "open"
    app.launchEnvironment["GRABBER_SILENT"] = "1"
    app.launch()
    let new = app.buttons["whiteboard-new"]
    XCTAssertTrue(new.appears(within: 20), app.debugDescription)
    new.tap()
    XCTAssertTrue(app.buttons["Pen"].appears(within: 10), "the tool picker: \(app.debugDescription)")
    sleep(1)
    let labels = app.buttons.allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)" }
    let picture = XCTAttachment(screenshot: app.screenshot())
    picture.name = "a real board's tool picker"
    picture.lifetime = .keepAlways
    add(picture)
    let note = XCTAttachment(string: labels.joined(separator: "\n"))
    note.name = "the buttons on a real board"
    note.lifetime = .keepAlways
    add(note)
    XCTAssertFalse(app.buttons["paperkit-board-insert"].exists, "a real board has no +: \(labels)")
    for name in ["Add", "Insert", "Add Shape", "Add Text", "Shapes"] {
      XCTAssertFalse(app.buttons[name].exists, "a real board's picker offers \(name): \(labels)")
    }
    // PencilKit's own … (More) menu is on every picker: it may hold settings, never an insert.
    let more = app.buttons["More-Button"]
    if more.exists {
      more.tap()
      sleep(1)
      let menu = XCTAttachment(screenshot: app.screenshot())
      menu.name = "the picker's More menu on a real board"
      menu.lifetime = .keepAlways
      add(menu)
    }
    let offered = (app.buttons.allElementsBoundByIndex + app.staticTexts.allElementsBoundByIndex).map(\.label)
    for insert in ["Add Shape", "Add Text", "Add Sticker", "Add Image", "Add Signature", "Shapes", "Text"] {
      XCTAssertFalse(offered.contains(insert), "a real board offers \(insert): \(offered)")
    }
  }
}
