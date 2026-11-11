import XCTest

@testable import ContextCore

/// #796: every launch hook in docs/TESTING.md, what its value reads as, and what an absent or mistyped one does.
final class LaunchHooksTests: XCTestCase {
  private func steps(_ env: [String: String]) -> [LaunchHook] { LaunchHooks(env).steps }

  func testNoHooksDoNothing() {
    let hooks = LaunchHooks([:])
    XCTAssertEqual(hooks.steps, [])
    XCTAssertEqual(hooks, LaunchHooks(["HOME": "/tmp", "GRABBER_NO_SUCH_HOOK": "1"]))
    XCTAssertFalse(hooks.silent)
    XCTAssertFalse(hooks.songMissing)
    XCTAssertNil(hooks.window)
    XCTAssertNil(hooks.windowChoose)
    XCTAssertNil(hooks.cockpitURL)
    XCTAssertNil(hooks.usageURL)
    XCTAssertNil(hooks.chatURL)
    XCTAssertEqual(hooks.chat, ChatViewHooks())
    XCTAssertEqual(hooks.whiteboard, WhiteboardHooks())
  }

  // MARK: Breathe

  private func breathe(_ spec: String, style: String? = nil) -> BreatheHook? {
    var env = ["GRABBER_BREATHE": spec]
    env["GRABBER_BREATHE_STYLE"] = style
    return BreatheHook(env)
  }

  func testBreatheNamesAnExactSession() throws {
    let full = try XCTUnwrap(breathe("5,3,off,12.5"))
    XCTAssertEqual(full.plan, BreathPlan(breathSeconds: 5, cycles: 3))
    XCTAssertEqual(full.cue, BreathCue(rawValue: "off"))
    XCTAssertNotNil(full.cue)
    XCTAssertEqual(full.pauseAt, 12.5)
    XCTAssertNil(full.style)

    let short = try XCTUnwrap(breathe("8,2"))
    XCTAssertEqual(short.plan, BreathPlan(breathSeconds: 8, cycles: 2))
    XCTAssertNil(short.cue)
    XCTAssertNil(short.pauseAt)

    let badExtras = try XCTUnwrap(breathe("8,2,shout,soon"))
    XCTAssertNotNil(badExtras.plan)
    XCTAssertNil(badExtras.cue)
    XCTAssertNil(badExtras.pauseAt)
  }

  func testBreatheAnythingElseOpensTheSliders() throws {
    for spec in ["open", "5", "five,3", "5,three,off", ","] {
      let hook = try XCTUnwrap(breathe(spec), spec)
      XCTAssertNil(hook.plan, spec)
      XCTAssertNil(hook.cue, spec)
      XCTAssertNil(hook.pauseAt, spec)
    }
    XCTAssertNil(breathe(""))
    XCTAssertNil(BreatheHook([:]))
  }

  func testBreatheStyleRidesOnlyWithBreathe() throws {
    let style = try XCTUnwrap(BreathStyle.allCases.first)
    XCTAssertEqual(breathe("open", style: style.rawValue)?.style, style)
    XCTAssertEqual(breathe("5,3", style: style.rawValue)?.style, style)
    XCTAssertNil(try XCTUnwrap(breathe("open", style: "no-such-style")).style)
    XCTAssertEqual(steps(["GRABBER_BREATHE_STYLE": style.rawValue]), [])
  }

  // MARK: Gym Timer

  func testTimerStartsAPresetOrACustomShape() throws {
    let turn = DeviceTurn.left
    let voice = try XCTUnwrap(CountVoice.allCases.last)
    let dial = try XCTUnwrap(DialStyle.allCases.last)
    XCTAssertEqual(
      GymTimerHook(["GRABBER_TIMER": "1min"]),
      .start(preset: "1min", custom: nil, turn: nil, voice: nil, dial: nil))
    XCTAssertEqual(
      GymTimerHook([
        "GRABBER_TIMER": "20,10,8", "GRABBER_TURN": turn.rawValue, "GRABBER_COUNT_VOICE": voice.rawValue,
        "GRABBER_TIMER_DIAL": dial.rawValue,
      ]),
      .start(
        preset: nil, custom: CustomPreset(work: 20, rest: 10, rounds: 8), turn: turn, voice: voice, dial: dial))
    // Not three numbers: the whole value is a preset's id, as written.
    for spec in ["20,10", "20,10,8,2", "20,ten,8", ","] {
      XCTAssertEqual(
        GymTimerHook(["GRABBER_TIMER": spec, "GRABBER_TURN": "sideways", "GRABBER_COUNT_VOICE": "nobody"]),
        .start(preset: spec, custom: nil, turn: nil, voice: nil, dial: nil), spec)
    }
    // Four fields of which three are numbers still read as Custom, as they always did.
    XCTAssertEqual(
      GymTimerHook(["GRABBER_TIMER": "20,10,x,8"]),
      .start(preset: nil, custom: CustomPreset(work: 20, rest: 10, rounds: 8), turn: nil, voice: nil, dial: nil))
  }

  func testTimerSettingsAndDialAloneOpenWithoutStarting() throws {
    let voice = try XCTUnwrap(CountVoice.allCases.last)
    let dial = try XCTUnwrap(DialStyle.allCases.last)
    XCTAssertEqual(GymTimerHook(["GRABBER_TIMER_SETTINGS": "1"]), .settings(voice: nil, dial: nil))
    XCTAssertEqual(
      GymTimerHook([
        "GRABBER_TIMER_SETTINGS": "1", "GRABBER_COUNT_VOICE": voice.rawValue, "GRABBER_TIMER_DIAL": dial.rawValue,
      ]),
      .settings(voice: voice, dial: dial))
    XCTAssertEqual(GymTimerHook(["GRABBER_TIMER_DIAL": dial.rawValue]), .dial(dial, voice: nil))
    XCTAssertEqual(
      GymTimerHook(["GRABBER_TIMER_DIAL": dial.rawValue, "GRABBER_COUNT_VOICE": voice.rawValue]),
      .dial(dial, voice: voice))
    // An empty GRABBER_TIMER is as good as none: the next one down is read.
    XCTAssertEqual(
      GymTimerHook(["GRABBER_TIMER": "", "GRABBER_TIMER_SETTINGS": "1"]), .settings(voice: nil, dial: nil))
    XCTAssertEqual(
      GymTimerHook(["GRABBER_TIMER_SETTINGS": "yes", "GRABBER_TIMER_DIAL": dial.rawValue]), .dial(dial, voice: nil))
  }

  func testTimerNothingToOpen() throws {
    let voice = try XCTUnwrap(CountVoice.allCases.last)
    XCTAssertNil(GymTimerHook([:]))
    XCTAssertNil(GymTimerHook(["GRABBER_TIMER": ""]))
    XCTAssertNil(GymTimerHook(["GRABBER_TIMER_SETTINGS": "0"]))
    XCTAssertNil(GymTimerHook(["GRABBER_TIMER_DIAL": "no-such-dial"]))
    XCTAssertNil(GymTimerHook(["GRABBER_COUNT_VOICE": voice.rawValue, "GRABBER_TURN": "left"]))
  }

  // MARK: Places

  func testImportDatabase() {
    let recent = ImportDatabaseHook(["GRABBER_IMPORT_DB": "import-fixture.db,recent"])
    XCTAssertEqual(steps(["GRABBER_IMPORT_DB": "import-fixture.db,recent"]), recent.map { [.importDatabase($0)] })
    XCTAssertEqual(recent?.file, "import-fixture.db")
    XCTAssertEqual(recent?.recent, true)
    let plain = ImportDatabaseHook(["GRABBER_IMPORT_DB": "/tmp/trail.db"])
    XCTAssertEqual(plain?.file, "/tmp/trail.db")
    XCTAssertEqual(plain?.recent, false)
    // "recent" counts only after the file.
    XCTAssertEqual(ImportDatabaseHook(["GRABBER_IMPORT_DB": "recent"])?.recent, false)
    XCTAssertEqual(ImportDatabaseHook(["GRABBER_IMPORT_DB": "a.db,later"])?.recent, false)
    XCTAssertNil(ImportDatabaseHook(["GRABBER_IMPORT_DB": ""]))
    XCTAssertNil(ImportDatabaseHook(["GRABBER_IMPORT_DB": ","]))
    XCTAssertNil(ImportDatabaseHook([:]))
  }

  func testRetentionTrackingAndExport() {
    XCTAssertEqual(steps(["GRABBER_RETENTION": "7"]), [.retention(days: 7)])
    XCTAssertEqual(steps(["GRABBER_RETENTION": "-1"]), [.retention(days: -1)])
    XCTAssertEqual(steps(["GRABBER_RETENTION": "a week"]), [])
    XCTAssertEqual(steps(["GRABBER_RETENTION": ""]), [])
    XCTAssertEqual(steps(["GRABBER_TRACKING": "on"]), [.tracking(on: true)])
    XCTAssertEqual(steps(["GRABBER_TRACKING": "off"]), [.tracking(on: false)])
    XCTAssertEqual(steps(["GRABBER_TRACKING": "ON"]), [.tracking(on: false)])
    XCTAssertEqual(steps(["GRABBER_TRACKING": ""]), [])
    XCTAssertEqual(steps(["GRABBER_EXPORT": "1"]), [.export])
    XCTAssertEqual(steps(["GRABBER_EXPORT": "yes"]), [])
  }

  func testPlaces() throws {
    func places(_ spec: String) throws -> PlacesHook { try XCTUnwrap(PlacesHook(["GRABBER_PLACES": spec]), spec) }
    func fields(_ hook: PlacesHook) -> [String] {
      [hook.map ? "map" : "", hook.unnamed ? "unnamed" : "", hook.name ? "name" : "", hook.edit ?? "-"]
    }
    XCTAssertEqual(fields(try places("open")), ["", "", "", "-"])
    XCTAssertEqual(fields(try places("anything")), ["", "", "", "-"])
    XCTAssertEqual(fields(try places("map")), ["map", "", "", "-"])
    XCTAssertEqual(fields(try places("map,unnamed")), ["map", "unnamed", "", "-"])
    XCTAssertEqual(fields(try places("map,unnamed,name")), ["map", "unnamed", "name", "-"])
    XCTAssertEqual(fields(try places("open,edit:Home Sweet Home")), ["", "", "", "Home Sweet Home"])
    XCTAssertEqual(fields(try places("edit:Gym")), ["", "", "", "Gym"])
    XCTAssertEqual(fields(try places("open,edit:")), ["", "", "", ""])
    // "map" and "unnamed" count only in their places; "name" anywhere.
    XCTAssertEqual(fields(try places("open,map")), ["", "", "", "-"])
    XCTAssertEqual(fields(try places("unnamed")), ["", "", "", "-"])
    XCTAssertEqual(fields(try places("name")), ["", "", "name", "-"])
    XCTAssertEqual(fields(try places(",")), ["", "", "", "-"])
    XCTAssertNil(PlacesHook(["GRABBER_PLACES": ""]))
    XCTAssertNil(PlacesHook([:]))
    XCTAssertEqual(steps(["GRABBER_PLACES": "map"]), [.places(try places("map"))])
  }

  // MARK: The screens that just open

  func testHooksWithOneWord() {
    XCTAssertEqual(steps(["GRABBER_COCKPIT": "open"]), [.cockpit])
    XCTAssertEqual(steps(["GRABBER_WHITEBOARD": "open"]), [.whiteboard])
    XCTAssertEqual(steps(["GRABBER_WHATS_NEW": "open"]), [.whatsNew])
    XCTAssertEqual(steps(["GRABBER_HOME": "settings"]), [.homeSettings])
    XCTAssertEqual(steps(["GRABBER_INBOX_FIXTURE": "1"]), [.inboxFixture])
    XCTAssertEqual(steps(["GRABBER_INBOX": "open"]), [.inbox])
    XCTAssertEqual(steps(["GRABBER_CHAT_SEND_AGAIN": "1"]), [.chatSendAgain])
    XCTAssertEqual(steps(["GRABBER_CHAT_NEW": "open"]), [.chatNew(voice: false)])
    XCTAssertEqual(steps(["GRABBER_CHAT_NEW": "voice"]), [.chatNew(voice: true)])
    XCTAssertEqual(steps(["GRABBER_ARCHIVE": "run"]), [.archive])
    let others = [
      "GRABBER_COCKPIT": "1", "GRABBER_WHITEBOARD": "1", "GRABBER_WHATS_NEW": "1", "GRABBER_HOME": "open",
      "GRABBER_INBOX_FIXTURE": "open", "GRABBER_INBOX": "1", "GRABBER_CHAT_SEND_AGAIN": "open",
      "GRABBER_CHAT_NEW": "1", "GRABBER_ARCHIVE": "1",
    ]
    XCTAssertEqual(steps(others), [])
    XCTAssertEqual(steps(others.mapValues { _ in "" }), [])
  }

  func testDrillAndSupermix() throws {
    // The mode is the trainer's to read: every value goes through, as written.
    XCTAssertEqual(steps(["GRABBER_DRILL": "position"]), [.drill("position")])
    XCTAssertEqual(steps(["GRABBER_DRILL": ""]), [.drill("")])
    let mix = try XCTUnwrap(WorkoutSupermix.Mix.allCases.last)
    XCTAssertEqual(steps(["GRABBER_SUPERMIX": mix.rawValue]), [.supermix(mix)])
    XCTAssertEqual(steps(["GRABBER_SUPERMIX": "no-such-mix"]), [])
  }

  // MARK: Whiteboard

  func testBoardFixture() {
    let alone = BoardFixtureHook(["GRABBER_BOARD_FIXTURE": "board-1"])
    XCTAssertEqual(alone?.board, "board-1")
    XCTAssertNil(alone?.from)
    XCTAssertNil(alone?.oldInk)
    let full = BoardFixtureHook([
      "GRABBER_BOARD_FIXTURE": "board-2", "GRABBER_BOARD_FIXTURE_FROM": "Igor's iPad",
      "GRABBER_BOARD_FIXTURE_OLD_INK": "3",
    ])
    XCTAssertEqual(full?.from, "Igor's iPad")
    XCTAssertEqual(full?.oldInk, 3)
    let odd = BoardFixtureHook([
      "GRABBER_BOARD_FIXTURE": "b", "GRABBER_BOARD_FIXTURE_FROM": "", "GRABBER_BOARD_FIXTURE_OLD_INK": "some",
    ])
    XCTAssertEqual(odd?.from, "")
    XCTAssertNil(odd?.oldInk)
    XCTAssertNil(BoardFixtureHook(["GRABBER_BOARD_FIXTURE": "", "GRABBER_BOARD_FIXTURE_FROM": "iPad"]))
    XCTAssertNil(BoardFixtureHook(["GRABBER_BOARD_FIXTURE_FROM": "iPad", "GRABBER_BOARD_FIXTURE_OLD_INK": "3"]))
    XCTAssertEqual(steps(["GRABBER_BOARD_FIXTURE": "board-1"]), alone.map { [.boardFixture($0)] })
  }

  func testWhatABoardDoesByItself() {
    let board = WhiteboardHooks([
      "GRABBER_WHITEBOARD_SAVE_FAILS": "1", "GRABBER_WHITEBOARD_GHOST_SECONDS": "2.5", "GRABBER_WHITEBOARD_GRID": "on",
      "GRABBER_WHITEBOARD_SAY": "draw a cat", "GRABBER_WHITEBOARD_KEEP": "first", "GRABBER_WHITEBOARD_PASTE": "hello",
      "GRABBER_WHITEBOARD_AFTER_INK": "copy,paste", "GRABBER_WHITEBOARD_PAGE_AFTER_INK": "2",
      "GRABBER_WHITEBOARD_AFTER_KEEP": "1.5,undo,redo",
    ])
    XCTAssertTrue(board.saveFails)
    XCTAssertEqual(board.ghostSeconds, 2.5)
    XCTAssertTrue(board.grid)
    XCTAssertEqual(board.say, "draw a cat")
    XCTAssertTrue(board.keepFirst)
    XCTAssertEqual(board.paste, "hello")
    XCTAssertEqual(board.afterInk, ["copy", "paste"])
    XCTAssertEqual(board.pageAfterInk, 2)
    XCTAssertEqual(board.afterKeep, WhiteboardHooks.AfterKeep(delay: 1.5, presses: ["undo", "redo"]))
    XCTAssertEqual(LaunchHooks(["GRABBER_WHITEBOARD_GRID": "on"]).whiteboard.grid, true)
  }

  func testWhatABoardDoesNotDo() {
    let none = WhiteboardHooks()
    XCTAssertFalse(none.saveFails)
    XCTAssertNil(none.ghostSeconds)
    XCTAssertFalse(none.grid)
    XCTAssertNil(none.say)
    XCTAssertFalse(none.keepFirst)
    XCTAssertNil(none.paste)
    XCTAssertNil(none.afterInk)
    XCTAssertNil(none.pageAfterInk)
    XCTAssertNil(none.afterKeep)

    let odd = WhiteboardHooks([
      "GRABBER_WHITEBOARD_SAVE_FAILS": "", "GRABBER_WHITEBOARD_GHOST_SECONDS": "long", "GRABBER_WHITEBOARD_GRID": "1",
      "GRABBER_WHITEBOARD_SAY": "", "GRABBER_WHITEBOARD_KEEP": "all", "GRABBER_WHITEBOARD_PASTE": "",
      "GRABBER_WHITEBOARD_AFTER_INK": "", "GRABBER_WHITEBOARD_PAGE_AFTER_INK": "two",
      "GRABBER_WHITEBOARD_AFTER_KEEP": "undo,redo",
    ])
    XCTAssertTrue(odd.saveFails, "set to anything, even nothing")
    XCTAssertNil(odd.ghostSeconds)
    XCTAssertFalse(odd.grid)
    XCTAssertEqual(odd.say, "", "the mic hears nothing, but it is the hook that answers")
    XCTAssertFalse(odd.keepFirst)
    XCTAssertEqual(odd.paste, "")
    XCTAssertEqual(odd.afterInk, [], "set but empty: the hook has run, with nothing to press")
    XCTAssertNil(odd.pageAfterInk)
    // The first field is always the wait: a press written there is not pressed.
    XCTAssertEqual(odd.afterKeep, WhiteboardHooks.AfterKeep(delay: 3, presses: ["redo"]))
    XCTAssertEqual(
      WhiteboardHooks(["GRABBER_WHITEBOARD_AFTER_KEEP": ""]).afterKeep,
      WhiteboardHooks.AfterKeep(delay: 3, presses: []))
  }

  // MARK: Chat

  func testChatSend() {
    func send(_ spec: String?) -> [String?]? { ChatSendHook(text: spec).map { [$0.thread, $0.body] } }
    XCTAssertEqual(send("igor2-88g.629|hello there"), ["igor2-88g.629", "hello there"])
    XCTAssertEqual(send("new|a fresh thread"), [nil, "a fresh thread"])
    XCTAssertEqual(send("t|a|b"), ["t", "a|b"], "only the first bar divides")
    XCTAssertEqual(send("t"), ["t", ""])
    XCTAssertEqual(send("t|"), ["t", ""])
    XCTAssertEqual(send("|words"), ["words", ""], "an empty thread is skipped, so the words are read as the thread")
    XCTAssertNil(send(""))
    XCTAssertNil(send("|"))
    XCTAssertNil(send(nil))
    XCTAssertEqual(steps(["GRABBER_CHAT_SEND": "new|hi"]), ChatSendHook(text: "new|hi").map { [.chatSend($0)] })
  }

  func testChatSendFile() {
    func send(_ spec: String?) -> [String?]? { ChatSendHook(file: spec).map { [$0.thread, $0.body] } }
    XCTAssertEqual(send("t1|/tmp/a.pdf"), ["t1", "/tmp/a.pdf"])
    XCTAssertEqual(send("new|/tmp/a.pdf"), [nil, "/tmp/a.pdf"])
    XCTAssertEqual(send("/tmp/a.pdf"), ["/tmp/a.pdf", "/tmp/a.pdf"], "one word is both")
    XCTAssertEqual(send("new"), [nil, "new"])
    XCTAssertEqual(send("|"), [nil, ""], "no path: the send refuses it and says so")
    XCTAssertNil(send(""))
    XCTAssertNil(send(nil))
    XCTAssertEqual(
      steps(["GRABBER_CHAT_SEND_FILE": "t1|/tmp/a.pdf"]),
      ChatSendHook(file: "t1|/tmp/a.pdf").map { [.chatSendFile($0)] })
  }

  func testWhatChatTapsByItself() {
    let chat = LaunchHooks([
      "GRABBER_CHAT_SELECT": "archive", "GRABBER_CHAT_LINKS": "fold", "GRABBER_CHAT_HOLD": "quote",
      "GRABBER_CHAT_IMAGE": "open",
    ]).chat
    XCTAssertTrue(chat.selectArchive)
    XCTAssertEqual(chat.links, "fold")
    XCTAssertEqual(chat.hold, "quote")
    XCTAssertTrue(chat.imageOpen)

    // The words are the screens' to read: anything goes through.
    let odd = ChatViewHooks([
      "GRABBER_CHAT_SELECT": "all", "GRABBER_CHAT_LINKS": "", "GRABBER_CHAT_HOLD": "shrug", "GRABBER_CHAT_IMAGE": "1",
    ])
    XCTAssertFalse(odd.selectArchive)
    XCTAssertEqual(odd.links, "")
    XCTAssertEqual(odd.hold, "shrug")
    XCTAssertFalse(odd.imageOpen)

    let none = ChatViewHooks()
    XCTAssertFalse(none.selectArchive)
    XCTAssertNil(none.links)
    XCTAssertNil(none.hold)
    XCTAssertFalse(none.imageOpen)
  }

  // MARK: Call, mirror, link

  func testCall() {
    XCTAssertEqual(steps(["GRABBER_CALL": "ws://127.0.0.1:8797"]), [.call(seconds: 8)])
    XCTAssertEqual(steps(["GRABBER_CALL": "ws://x", "GRABBER_CALL_SECONDS": "2.5"]), [.call(seconds: 2.5)])
    XCTAssertEqual(steps(["GRABBER_CALL": "ws://x", "GRABBER_CALL_SECONDS": "soon"]), [.call(seconds: 8)])
    XCTAssertEqual(steps(["GRABBER_CALL": "ws://x", "GRABBER_CALL_SECONDS": ""]), [.call(seconds: 8)])
    XCTAssertEqual(steps(["GRABBER_CALL": "", "GRABBER_CALL_SECONDS": "3"]), [])
    XCTAssertEqual(steps(["GRABBER_CALL_SECONDS": "3"]), [])
  }

  func testMirror() throws {
    let metric = try XCTUnwrap(MetricKey.allCases.first)
    XCTAssertEqual(steps(["GRABBER_MIRROR": "fixture"]), [.mirror(mode: "fixture", metric: nil)])
    XCTAssertEqual(
      steps(["GRABBER_MIRROR": "healthkit", "GRABBER_METRIC": metric.rawValue]),
      [.mirror(mode: "healthkit", metric: metric)])
    XCTAssertEqual(
      steps(["GRABBER_MIRROR": "anything", "GRABBER_METRIC": "no-such-metric"]),
      [.mirror(mode: "anything", metric: nil)], "the mode is the mirror's to read")
    XCTAssertEqual(steps(["GRABBER_MIRROR": "", "GRABBER_METRIC": metric.rawValue]), [])
    XCTAssertEqual(steps(["GRABBER_METRIC": metric.rawValue]), [])
  }

  func testLink() throws {
    let link = "grabbernative://chat?thread=igor2-88g.629"
    XCTAssertEqual(steps(["GRABBER_LINK": link]), [.link(try XCTUnwrap(URL(string: link)))])
    XCTAssertEqual(steps(["GRABBER_LINK": ""]), [])
  }

  // MARK: Windows, sound, addresses

  func testWindows() throws {
    let screen = try XCTUnwrap(WindowScreen.allCases.first)
    XCTAssertEqual(LaunchHooks(["GRABBER_WINDOW_CHOOSE": screen.rawValue]).windowChoose, screen)
    XCTAssertNil(LaunchHooks(["GRABBER_WINDOW_CHOOSE": "no-such-screen"]).windowChoose)
    XCTAssertEqual(
      LaunchHooks(["GRABBER_WINDOW": "\(screen.rawValue),again,close"]).window,
      WindowHook(screen: screen, steps: ["again", "close"]))
    XCTAssertEqual(LaunchHooks(["GRABBER_WINDOW": screen.rawValue]).window, WindowHook(screen: screen, steps: []))
    // A hook that names no screen has still run: it is not read again.
    XCTAssertEqual(
      LaunchHooks(["GRABBER_WINDOW": "no-such-screen,again"]).window, WindowHook(screen: nil, steps: ["again"]))
    XCTAssertEqual(LaunchHooks(["GRABBER_WINDOW": ""]).window, WindowHook(screen: nil, steps: []))
    XCTAssertEqual(LaunchHooks(["GRABBER_WINDOW": screen.rawValue]).steps, [], "a window opens once home is up")
  }

  func testSoundAndAddresses() {
    let hooks = LaunchHooks([
      "GRABBER_SILENT": "1", "GRABBER_SONG": "missing", "GRABBER_COCKPIT_URL": "cockpit-bridge-test",
      "GRABBER_USAGE_URL": "http://127.0.0.1:1", "GRABBER_CHAT_URL": "", "GRABBER_NO_ANIMATIONS": "1",
    ])
    XCTAssertTrue(hooks.silent)
    XCTAssertTrue(hooks.noAnimations)
    XCTAssertTrue(hooks.songMissing)
    XCTAssertEqual(hooks.cockpitURL, "cockpit-bridge-test")
    XCTAssertEqual(hooks.usageURL, "http://127.0.0.1:1")
    XCTAssertEqual(hooks.chatURL, "", "empty goes through: ChatCockpit decides it means unset")
    XCTAssertEqual(hooks.steps, [], "none of these does anything at launch")
    let odd = LaunchHooks(["GRABBER_SILENT": "yes", "GRABBER_SONG": "1", "GRABBER_NO_ANIMATIONS": "true"])
    XCTAssertFalse(odd.silent)
    XCTAssertFalse(odd.noAnimations)
    XCTAssertFalse(odd.songMissing)
  }

  // MARK: Order

  /// The import before the places hooks that read its trail, the fixtures before the screens that show them, the
  /// link last: the order `AppModel.runLaunchHooks` always ran them in.
  func testEveryHookAtOnceRunsInTheOldOrder() {
    let env = [
      "GRABBER_BREATHE": "5,3", "GRABBER_TIMER": "1min", "GRABBER_IMPORT_DB": "a.db", "GRABBER_RETENTION": "7",
      "GRABBER_TRACKING": "on", "GRABBER_PLACES": "map", "GRABBER_EXPORT": "1", "GRABBER_DRILL": "position",
      "GRABBER_COCKPIT": "open", "GRABBER_BOARD_FIXTURE": "b", "GRABBER_WHITEBOARD": "open",
      "GRABBER_WHATS_NEW": "open", "GRABBER_HOME": "settings", "GRABBER_SUPERMIX": WorkoutSupermix.Mix.workout.rawValue,
      "GRABBER_INBOX_FIXTURE": "1", "GRABBER_INBOX": "open", "GRABBER_CHAT_SEND": "new|hi",
      "GRABBER_CHAT_SEND_FILE": "new|/tmp/a", "GRABBER_CHAT_SEND_AGAIN": "1", "GRABBER_CHAT_NEW": "open",
      "GRABBER_ARCHIVE": "run", "GRABBER_CALL": "ws://x", "GRABBER_MIRROR": "fixture", "GRABBER_LINK": "grabber://card",
    ]
    let names = steps(env).map { String(describing: $0).prefix { $0 != "(" } }.map(String.init)
    XCTAssertEqual(
      names,
      [
        "breathe", "timer", "importDatabase", "retention", "tracking", "places", "export", "drill", "cockpit",
        "boardFixture", "whiteboard", "whatsNew", "homeSettings", "supermix", "inboxFixture", "inbox", "chatSend",
        "chatSendFile", "chatSendAgain", "chatNew", "archive", "call", "mirror", "link",
      ])
  }
}
