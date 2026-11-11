//  Story 303 (#448) on the simulator: the chat mic is the problem report's Apple dictation, and the thread's mic and its
//  microphone picker are there and ready. Speaking itself needs the phone (the recognizer, the microphone). Settings
//  asks for no key because the Deepgram section is gone from the code; nothing on screen needs a launch to say so.

import XCTest

final class ChatVoiceUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  func testTheThreadsMicAndPickerAreReady() throws {
    let app = XCUIApplication.forTests()
    app.launchEnvironment["GRABBER_CHAT_URL"] = "http://127.0.0.1:9"
    app.launchEnvironment["GRABBER_LINK"] = "grabbernative://chat?thread=igor2-88g.900"
    app.launch()
    // The thread's identifier covers its children, so the mic is found by its label.
    let mic = app.buttons["Speak a message"]
    XCTAssertTrue(mic.appears(within: 20), app.debugDescription)
    XCTAssertTrue(mic.isEnabled, "no call is live, so the mic is ready")
    XCTAssertFalse(app.buttons["Stop recording"].exists, "nothing records until a tap")
    // #625: the mic is immediately beside Send, after the field, both a finger's size.
    let send = app.buttons["Send"]
    // The thread's identifier covers the field's too, so it is found by its placeholder.
    let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Message Larry")).firstMatch
    XCTAssertTrue(field.appears(within: 5), app.debugDescription)
    XCTAssertTrue(send.appears(within: 5), app.debugDescription)
    XCTAssertLessThanOrEqual(field.frame.maxX, mic.frame.minX, "the field comes before the mic")
    XCTAssertLessThanOrEqual(mic.frame.maxX, send.frame.minX, "the mic comes before Send")
    XCTAssertLessThanOrEqual(send.frame.minX - mic.frame.maxX, 8, "the mic is right beside Send")
    for button in [mic, send] {
      XCTAssertGreaterThanOrEqual(button.frame.width, 44, button.label)
      XCTAssertGreaterThanOrEqual(button.frame.height, 44, button.label)
    }
    let picker = app.buttons["Microphone: Automatic"]
    XCTAssertTrue(picker.appears(within: 5), "the microphone picker, on Automatic: \(app.debugDescription)")
    picker.tap()
    XCTAssertTrue(app.buttons["Find microphones"].appears(within: 5), app.debugDescription)
  }
}
