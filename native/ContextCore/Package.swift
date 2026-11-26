// swift-tools-version: 6.0
import PackageDescription

// ChatWireKit's files, which stay where they are in ContextCore's tree (plan 2026-11-22-contextcore-targets-plan.md).
let chatWireSources = [
  "Chat/ChatWire.swift", "Chat/ChatDecisions.swift", "Chat/ChatMove.swift", "Chat/ChatLinks.swift",
  "Chat/ChatSiteNames.swift", "Chat/ChatBubbleLinks.swift", "Chat/ChatCockpitLink.swift",
  "Cockpit/CockpitAddress.swift", "Archive/ArchiveRecord.swift", "Chat/AppBuild.swift", "Platform/FoundationLite.swift",
  "Platform/FoundationLiteShims.swift", "Chat/ChatSpeaker.swift",
]

// BoardCore's: the whole Whiteboard directory, new files included, and the CoreGraphics stand-ins it needs on Linux.
let boardSources = ["Whiteboard", "Platform/LinuxGeometry.swift", "Platform/LiteGeometry.swift"]

// The board's tests, built against BoardCore alone (`just board-test`). Every Board*, Whiteboard* and Paper* test file
// is in this list or the next; scripts/native/test-board-tests-listed.sh says which a new one is missing from. Their
// `@testable import ContextCore` reaches BoardCore through a module alias, so they are written as before.
let boardTests = [
  "BoardBlockedEditTests.swift", "BoardCanvasOutcomeTests.swift", "BoardConnectorsTests.swift",
  "BoardDissolveTests.swift", "BoardEventsCapTests.swift", "BoardFindTests.swift", "BoardFoldEraseTests.swift",
  "BoardFoldMarkerTests.swift", "BoardFoldPictureTests.swift", "BoardFoldWrittenUnderTests.swift",
  "BoardHeaderMarksTests.swift",
  "BoardHoldMenuTests.swift",
  "BoardIndexTests.swift",
  "BoardInkHeadersTests.swift", "BoardKeepingTests.swift", "BoardLabelOneLineTests.swift",
  "BoardLabelWrapTests.swift", "BoardLetteringTests.swift", "BoardLinesTests.swift", "BoardMarginHoldTests.swift",
  "BoardMarkHoldsTests.swift",
  "BoardMarksReplayTests.swift", "BoardMomentTests.swift",
  "BoardMeaningTests.swift", "BoardMicMenuTests.swift", "BoardOpsControlsTests.swift", "BoardOpsInkTests.swift",
  "BoardOutlineHeaderLineTests.swift", "BoardOutlineIgorGroupsTests.swift", "BoardOutlineTests.swift",
  "BoardQuestionFoldTests.swift", "WhiteboardMarkActionsTests.swift",
  "BoardPagesTests.swift", "BoardPaperTests.swift",
  "BoardPicturePagesTests.swift",
  "BoardPlaybackOffScreenTests.swift", "BoardPlaybackTests.swift", "BoardRealFontTests.swift",
  "BoardRectOverlapTests.swift",
  "BoardReplayTests.swift", "BoardReviewRecorderTests.swift", "BoardReviewTests.swift", "BoardRewordTests.swift",
  "BoardRoomBandTests.swift",
  "BoardRoomDropTests.swift",
  "BoardMarkupCensusTests.swift",
  "BoardRoomLateTests.swift", "BoardRoomTests.swift", "BoardSaveTimingTests.swift", "BoardSelectionLabelTests.swift",
  "BoardSessionReplayTests.swift", "BoardShapeSnapTests.swift", "BoardStoreCacheTests.swift",
  "BoardStoreClashTests.swift",
  "BoardSyncFailureTests.swift",
  "BoardSyncRetryTests.swift", "BoardThreadFindTests.swift", "BoardThreadRefusalTests.swift",
  "BoardToTextTests.swift", "BoardUndoButtonsTests.swift", "BoardUndoProbeTests.swift", "BoardUndoRedrawTests.swift",
  "PaperProbeGroupCarryTests.swift", "PaperProbeHandwritingOfferTests.swift", "PaperProbeMoveAuditTests.swift",
  "PaperProbeOwnersApartTests.swift",
  "PaperProbePickupTests.swift", "PaperProbeReflowTests.swift", "PaperProbeTests.swift", "WhiteboardDiagramTests.swift",
  "WhiteboardFingerTests.swift",
  "WhiteboardFrameTests.swift",
  "WhiteboardGhostTurnsTests.swift", "WhiteboardInkTests.swift", "WhiteboardKeepAllTests.swift",
  "WhiteboardKeepReplyTests.swift",
  "WhiteboardKeptInkTests.swift",
  "WhiteboardLarryClockTests.swift", "WhiteboardLarryListeningTests.swift", "WhiteboardLarryTurnTests.swift",
  "WhiteboardLarryWaitTests.swift", "WhiteboardLostConnectionTests.swift", "WhiteboardMarkChoiceTests.swift",
  "WhiteboardNoteTests.swift", "WhiteboardOneSendTests.swift", "WhiteboardPacerTests.swift",
  "WhiteboardPanelLookTests.swift", "WhiteboardPanelPlaceTests.swift",
  "WhiteboardPasteTests.swift",
  "WhiteboardAnswerCardsTests.swift", "WhiteboardQuestionsArchiveTests.swift", "WhiteboardQuestionsLooksTests.swift",
  "WhiteboardQuestionsTests.swift",
  "WhiteboardResponderTests.swift",
  "WhiteboardScratchOutTests.swift",
  "WhiteboardSpeechTests.swift", "WhiteboardStreamTests.swift", "WhiteboardStrokesFileTests.swift",
  "WhiteboardTidyGroupTests.swift", "WhiteboardTidyTests.swift", "WhiteboardTurnTests.swift",
  "WhiteboardWordsOnlyTests.swift",
  "WhiteboardWritingVadTests.swift",
]

// Board test files that need more of ContextCore than the board (the Inbox, the call log, the session log): they stay
// in ContextCoreTests and see only BoardCore's public API.
let boardTestsInContextCore = [
  "BoardReviewDiskTests.swift",
  "BoardChatJumpTests.swift", "BoardDebugTimingTests.swift", "BoardOpsTests.swift", "BoardTouchReplayTests.swift",
  "WhiteboardLogArchiveTests.swift", "WhiteboardMarksTests.swift", "WhiteboardRequestsTests.swift",
  "WhiteboardStrokesTests.swift",
]

// The board wasm links ChatWireKit, BoardCore and BoardWasm on FoundationEssentials alone, so it carries no ICU data
// (bead context-grabber-pt1e). Everywhere else they import Foundation, as the rest of the package does.
let essentialsOnly: [SwiftSetting] = [.define("FOUNDATION_ESSENTIALS_ONLY", .when(platforms: [.wasi]))]

// The platform-free half of the native app: everything here runs under `swift test` on the Mac (docs/TESTING.md).
let package = Package(
  name: "ContextCore",
  platforms: [.iOS(.v18), .macOS(.v14)],
  products: [
    .library(name: "ContextCore", targets: ["ContextCore"]),
    // Larry's board changes replayed on a copy of a board and drawn to a PNG, on the Mac (#936; `just board-ops`).
    .executable(name: "board-ops-harness", targets: ["BoardOpsHarness"]),
    // A pulled log's pen touches judged again on the Mac and written as a host fixture (story 1105; `just touch-fixture`).
    .executable(name: "touch-replay", targets: ["TouchReplay"]),
  ],
  targets: [
    // Linux only (just test-linux, and the board-ops harness on Larry's box, #943): the system's SQLite, found through
    // pkg-config's sqlite3 (its headers wherever the system put them); SwiftPM names the package to install when it is
    // missing. The Apple SDKs carry SQLite as the SQLite3 module, so the Mac and iOS never build this.
    .systemLibrary(
      name: "CSQLite", pkgConfig: "sqlite3",
      providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite"]), .yum(["sqlite-devel"])]),
    // The Cockpit chat wire the chat screen and the board share, in place under ContextCore (plan
    // 2026-11-22-contextcore-targets-plan.md); ContextCore excludes the same files and re-exports the module.
    .target(name: "ChatWireKit", path: "Sources/ContextCore", sources: chatWireSources, swiftSettings: essentialsOnly),
    .target(
      name: "BoardCore", dependencies: ["ChatWireKit"], path: "Sources/ContextCore", sources: boardSources,
      swiftSettings: essentialsOnly),
    .target(
      name: "ContextCore",
      dependencies: ["ChatWireKit", "BoardCore", .target(name: "CSQLite", condition: .when(platforms: [.linux]))],
      exclude: chatWireSources + boardSources),
    .executableTarget(name: "BoardOpsHarness", dependencies: ["ContextCore"]),
    .executableTarget(name: "TouchReplay", dependencies: ["ContextCore"]),
    // The board's rules for the Cockpit's web board: a WASI reactor exporting a small C interface (spec
    // 2026-11-22-board-rules-on-the-web-design.md; `just wasm`). Elsewhere it is a stub that says so.
    .executableTarget(
      name: "BoardWasm", dependencies: ["BoardCore"], swiftSettings: essentialsOnly,
      linkerSettings: [.unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"], .when(platforms: [.wasi]))]),
    .testTarget(name: "ContextCoreTests", dependencies: ["ContextCore"], exclude: ["Fixtures"] + boardTests),
    .testTarget(
      name: "BoardCoreTests", dependencies: ["BoardCore"], path: "Tests/ContextCoreTests", sources: boardTests,
      swiftSettings: [.unsafeFlags(["-module-alias", "ContextCore=BoardCore"])]),
    // The web board's exports asked on the host, against the app's own rules (spec
    // 2026-11-22-board-rules-on-the-web-design.md): the answers build everywhere, only the exports are WASI's.
    .testTarget(name: "BoardWasmTests", dependencies: ["BoardWasm", "BoardCore"]),
  ],
  swiftLanguageModes: [.v5]
)
