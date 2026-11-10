import XCTest

@testable import ContextCore

/// #802: the audio floor's rule table, one test per rule, named for the line it was transcribed from (as of
/// 7e64571e). These pin what the app did before the table existed, gaps included: a failing test here is a change in
/// behaviour, which needs a story first.
final class AudioFloorTests: XCTestCase {
  private let everyone = Set(AudioUser.allCases)

  private func decide(_ ask: AudioAsk, _ holding: Set<AudioUser>) -> [AudioDecision] {
    AudioFloor.decide(ask, holding: holding)
  }

  // MARK: the timer gives way (story 191)

  /// AppModel.swift:767 openCall.
  func testCallScreenOpeningPausesTheTimer() {
    XCTAssertEqual(decide(.callScreenOpens, [.timer]), [.yield(.timer, to: "call")])
  }

  /// AppModel.swift:503 openBreathe.
  func testBreatheOpeningPausesTheTimer() {
    XCTAssertEqual(decide(.breatheOpens, [.timer]), [.yield(.timer, to: "breathe")])
  }

  /// AppModel.swift:644 playEulogySong (34902620).
  func testSongTilePausesTheTimer() {
    XCTAssertEqual(decide(.songOpens, [.timer]), [.yield(.timer, to: "eulogy_song")])
  }

  /// AppModel.swift:718 openCockpit (34902620).
  func testCockpitOpeningPausesTheTimer() {
    XCTAssertEqual(decide(.cockpitOpens, [.timer]), [.yield(.timer, to: "cockpit")])
  }

  /// AppModel.swift:644 then EulogySong.swift:47: the tile's yield comes before the play's own check, so during a
  /// call the song's tile pauses a running workout and then the song waits.
  func testSongTileDuringACallStillPausesTheTimerThenTheSongWaits() {
    XCTAssertEqual(decide(.songOpens, [.timer, .call]), [.yield(.timer, to: "eulogy_song")])
    XCTAssertEqual(decide(.songPlays, [.timer, .call]), [.refuse(by: .call)])
  }

  // MARK: a call takes the session

  /// AppModel.swift:184 call.willStart: the song (#197). Chat's dictation stopping next is the microphone's (below).
  func testCallStartingPausesTheSong() {
    XCTAssertEqual(decide(.callStarts, [.song, .chatVoice]), [.yield(.song, to: "call")])
  }

  // MARK: a live call refuses

  /// AppModel.swift:82 song.heldBy, EulogySong.swift:47 (#197); the same answer guards EulogySong.swift:122.
  func testSongWaitsForACall() {
    XCTAssertEqual(decide(.songPlays, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.songPlays, []), [])
  }

  /// AppModel.swift:566 mayTheCardSpeak (#219): silent, and the song is left alone.
  func testCardIsSilentDuringACall() {
    XCTAssertEqual(decide(.cardSpeaks, [.call, .song]), [.refuse(by: .call)])
  }

  /// AppModel.swift:567 mayTheCardSpeak (#219).
  func testCardSpeakingPausesTheSong() {
    XCTAssertEqual(decide(.cardSpeaks, [.song]), [.yield(.song, to: "card")])
  }

  /// AppModel.swift:694 resetAudio, DiagnosticsView.swift:472 (story 149).
  func testResetAudioRefusedDuringACall() {
    XCTAssertEqual(decide(.audioReset, [.call]), [.refuse(by: .call)])
    XCTAssertEqual(decide(.audioReset, everyone.subtracting([.call])), [])
  }

  // MARK: today's gaps

  /// #802 open question for Igor: should the timer/breathing refuse during a call?
  /// Today nothing checks: GymAudio.swift:187 and BreatheAudio.swift:189 set `.playback` on the session a live call
  /// holds as `.playAndRecord` / `.voiceChat`, and the call is not told.
  func testTimerStartAndBreathingDuringACallAreNotArbitrated() {
    XCTAssertEqual(decide(.timerStarts, [.call]), [])
    XCTAssertEqual(decide(.breatheStarts, [.call]), [])
    XCTAssertEqual(decide(.breatheOpens, [.call]), [.yield(.timer, to: "breathe")])
    XCTAssertEqual(decide(.timerStarts, everyone), [])
    XCTAssertEqual(decide(.breatheStarts, everyone), [])
  }

  /// Nothing else gives way either: a call starting leaves a workout started since, or a breathing session, alone;
  /// the song plays over breathing and the Cockpit.
  func testPairsWithNoRuleCoexist() {
    XCTAssertFalse(decide(.callStarts, everyone).contains(.yield(.timer, to: "call")))
    XCTAssertFalse(decide(.callStarts, everyone).contains(.yield(.breathe, to: "call")))
    XCTAssertEqual(decide(.songPlays, everyone.subtracting([.call])), [])
  }

  // MARK: the whole table

  /// Every ask with everyone holding: a rule added, dropped or reordered shows here.
  func testEveryAskWithEveryoneHolding() {
    let expected: [AudioAsk: [AudioDecision]] = [
      .callScreenOpens: [.yield(.timer, to: "call")],
      .callStarts: [.yield(.song, to: "call")],
      .timerStarts: [],
      .breatheOpens: [.yield(.timer, to: "breathe")],
      .breatheStarts: [],
      .songOpens: [.yield(.timer, to: "eulogy_song")],
      .songPlays: [.refuse(by: .call)],
      .cardSpeaks: [.refuse(by: .call)],
      .cockpitOpens: [.yield(.timer, to: "cockpit")],
      .audioReset: [.refuse(by: .call)],
    ]
    XCTAssertEqual(Set(expected.keys), Set(AudioAsk.allCases))
    for ask in AudioAsk.allCases {
      XCTAssertEqual(decide(ask, everyone), expected[ask], ask.rawValue)
    }
    XCTAssertEqual(AudioFloor.rules.count, 9, "the seven microphone rows are MicFloor's")
    XCTAssertTrue(AudioFloor.rules.allSatisfy { !$0.source.isEmpty })
  }

  /// A yield is asked of the holder whoever has the session: GymTimerModel.yield, EulogySongPlayer.yield and
  /// ChatVoiceModel.yieldToCall each return at once when they are not sounding, as the pairwise lines relied on.
  func testYieldsAreAskedWhetherOrNotTheHolderIsKnownToHold() {
    XCTAssertEqual(decide(.breatheOpens, []), [.yield(.timer, to: "breathe")])
    XCTAssertEqual(decide(.callStarts, []), [.yield(.song, to: "call")])
  }

  /// Only a call refuses anything now, so a call is all `isHolding` is ever asked about, and only for an ask with a
  /// refusal row.
  func testOnlyRefusingHoldersAreAskedAbout() {
    for ask in AudioAsk.allCases {
      var asked: [AudioUser] = []
      _ = AudioFloor.decide(ask) {
        asked.append($0)
        return false
      }
      XCTAssertEqual(asked, [.songPlays, .cardSpeaks, .audioReset].contains(ask) ? [.call] : [], ask.rawValue)
    }
  }

  /// AppModel's `holdsAudio` answers for the call and says false for every other user. A new refuser needs a case
  /// in `holdsAudio` (native/App/AppModel.swift) before this set changes.
  func testTheOnlyRefuserIsTheCall() {
    XCTAssertEqual(AudioFloor.refusers, [.call])
  }

  /// The one raw value that reaches the session log: AppModel's `song.heldBy` hands a refusing holder's raw value to
  /// EulogySong.swift:49, which logs it as `play_held`'s `by`. Only a call refuses the song. The names in
  /// `timer_yield`'s `to` and the song's `pause` `from` are the rules' own strings, pinned in the tests above.
  func testRawValuesThatReachTheLog() {
    XCTAssertEqual(AudioUser.call.rawValue, "call")
    XCTAssertEqual(decide(.songPlays, everyone), [.refuse(by: .call)])
  }

  // MARK: - the microphone: one holder or nobody (audit finding 4, spec 2026-11-10-microphone-floor-design.md)

  private let recorders = MicFloor.recorders
  private let nobodyElse: (AudioUser) -> Bool = { _ in true }

  /// Audit test 4: three dictations and a call, and the floor arbitrated one pair. Every ordered pair has a row now,
  /// a recorder asking again included.
  func testEveryMicPairHasARow() {
    XCTAssertEqual(recorders, [.call, .chatVoice, .reportDictation, .whiteboardMic])
    XCTAssertEqual(MicFloor.rules.count, 16)
    for asker in recorders {
      for holder in recorders {
        let rows = MicFloor.rules.filter { $0.asker == asker && $0.holder == holder }
        XCTAssertEqual(rows.count, 1, "\(asker) asking while \(holder) holds")
      }
    }
    // The pairs nothing arbitrated before: the board against either dictation, and the two dictations' other way.
    for (asker, holder) in [
      (AudioUser.whiteboardMic, AudioUser.chatVoice), (.whiteboardMic, .reportDictation), (.chatVoice, .whiteboardMic),
      (.chatVoice, .reportDictation), (.reportDictation, .whiteboardMic),
    ] {
      XCTAssertEqual(MicFloor.rule(asker, holder).outcome, .refused, "\(asker) asking while \(holder) holds")
    }
  }

  /// The whole table: a call beats all three, anyone else waits for whoever has it, a holder asking again keeps it.
  func testTheMicTable() {
    for asker in recorders {
      for holder in recorders {
        let expected: MicRule.Outcome = asker == holder ? .keeps : asker == .call ? .takes : .refused
        XCTAssertEqual(MicFloor.rule(asker, holder).outcome, expected, "\(asker) asking while \(holder) holds")
      }
    }
  }

  func testNobodyHoldingGrantsTheAsker() {
    for user in recorders {
      var floor = MicFloor()
      XCTAssertEqual(floor.request(user, stillHolding: nobodyElse), .granted(took: nil))
      XCTAssertEqual(floor.holder, user)
    }
  }

  /// A call starting takes the mic from whoever has it: AppModel stops that one, as #448 and #546 did for chat.
  func testACallTakesTheMicFromAnyone() {
    for holder in [AudioUser.chatVoice, .reportDictation, .whiteboardMic] {
      var floor = MicFloor()
      _ = floor.request(holder, stillHolding: nobodyElse)
      XCTAssertEqual(floor.request(.call, stillHolding: nobodyElse), .granted(took: holder))
      XCTAssertEqual(floor.holder, .call)
    }
  }

  /// #239, #559 and the audit's gaps: the first one keeps it, and a refusal changes nothing.
  func testAnyoneElseWaitsForWhoeverHasIt() {
    for holder in recorders {
      for asker in recorders where asker != holder && asker != .call {
        var floor = MicFloor()
        _ = floor.request(holder, stillHolding: nobodyElse)
        XCTAssertEqual(floor.request(asker, stillHolding: nobodyElse), .refused(by: holder), "\(asker) vs \(holder)")
        XCTAssertEqual(floor.holder, holder)
      }
    }
  }

  func testAskingAgainKeepsIt() {
    var floor = MicFloor()
    _ = floor.request(.chatVoice, stillHolding: nobodyElse)
    XCTAssertEqual(floor.request(.chatVoice, stillHolding: nobodyElse), .granted(took: nil))
    XCTAssertEqual(floor.holder, .chatVoice)
  }

  /// Only the holder's letting go frees it; after that the next to ask gets it.
  func testTheHolderLetsGo() {
    var floor = MicFloor()
    _ = floor.request(.call, stillHolding: nobodyElse)
    floor.release(.chatVoice)
    XCTAssertEqual(floor.holder, .call)
    floor.release(.call)
    XCTAssertNil(floor.holder)
    XCTAssertEqual(floor.request(.reportDictation, stillHolding: nobodyElse), .granted(took: nil))
  }

  /// A recorder that stopped without saying so (a dictation that never started, the report dialog closed) holds
  /// nothing: the next ask finds it gone.
  func testAHolderNoLongerRecordingIsLetGo() {
    var floor = MicFloor()
    _ = floor.request(.chatVoice, stillHolding: nobodyElse)
    XCTAssertEqual(floor.request(.reportDictation) { $0 != .chatVoice }, .granted(took: nil))
    XCTAssertEqual(floor.holder, .reportDictation)
    XCTAssertNil(floor.heldByAnother(than: .chatVoice) { _ in false }, "stale: nobody really has it")
    XCTAssertEqual(floor.heldByAnother(than: .chatVoice, stillHolding: nobodyElse), .reportDictation)
    XCTAssertNil(floor.heldByAnother(than: .reportDictation, stillHolding: nobodyElse), "its own hold")
  }

  /// Who enforces each row: the floor for the call and the two dictations; the board still checks the call for itself;
  /// and nobody yet for the board against either dictation, because the board's screen doesn't ask (#821 rewrites it).
  func testWhoEnforcesEachMicRow() {
    let nobodyYet = MicFloor.rules.filter { $0.enforcedBy == .nobodyYet }.map { "\($0.asker)/\($0.holder)" }
    XCTAssertEqual(
      Set(nobodyYet),
      [
        "chatVoice/whiteboardMic", "reportDictation/whiteboardMic", "whiteboardMic/chatVoice",
        "whiteboardMic/reportDictation",
      ])
    let board = MicFloor.rules.filter { $0.enforcedBy == .theBoard }.map { "\($0.asker)/\($0.holder)" }
    XCTAssertEqual(Set(board), ["whiteboardMic/call", "call/whiteboardMic", "whiteboardMic/whiteboardMic"])
    XCTAssertEqual(MicFloor.rules.filter { $0.enforcedBy == .floor }.count, 9)
  }
}
