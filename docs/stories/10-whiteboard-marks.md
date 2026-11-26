# The whiteboard: Ghosts and Larry's marks

What Larry and Claude draw back: ghosts, Keep and Dismiss, how their marks look, Keep all (each reply kept as a group) and Tidy, and the room a kept reply makes. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 350:

- **Summary:** Ghosts stay while I draw
- **Status:** first implemented as drawing dismissing the ghosts in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to staying in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) (Igor, 2026-11-02); not verifiable on the simulator, which has no Pencil and no canvas in the accessibility tree; to try on the iPad, including a finger tap on a ghost while the Pencil is down; a mark my stroke writes over fades and goes on my next post since [6de8abc4](https://github.com/idvorkin/context-grabber/commit/6de8abc4) (stories 1269, 1270), verified on the host (`BoardMarkHoldsTests`) and the Mac build
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing while Claude suggests
- **I want to** keep drawing while the ghosts stay
- **so that** it feels like drawing together, not taking turns

#### Acceptance Criteria:
- **Scenario:** The Pencil touches down
- **Given:** ghosts are showing, or a ghost turn is still on its way
- **When:** I touch the Pencil down and draw on
- **Then:** the ghosts already showing stay (one my stroke writes over fades, and goes on my next post: stories 1269, 1270); Claude's quick answer still on its way is dropped and asked again after my next pause (story 894); a reply of Larry's is never dropped, however much I wrote since he looked: it lands, and the one rule for making room (story 1148) moves my newer writing down rather than his reply giving way (Igor, 2026-11-22)

---

### User Story 351:

- **Summary:** Turn off *Ask at my pauses*
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); seen on the simulator in the recording of the Ghosts-off UI test (no note with Ghosts off, the note back on), which passed with the other `WhiteboardTurnUITests` in the build turn of [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3). Since bead `context-grabber-5eq` the rule is a host test (`WhiteboardGhostTurnsTests.testGhostsOffAsksNothingForAStrokeAndOnAgainDoes`: a stroke with Ghosts off starts no pause, Claude's go and Larry's stay, an answer on its way lands stale, on again asks), and that UI test is gone. Renamed *Ask at my pauses* in [767aabac](https://github.com/idvorkin/context-grabber/commit/767aabac) (story 1171): off asks no one on a Larry board or a Haiku board, verified on the iPad simulator (`WhiteboardTurnUITests.testAskAtMyPausesOffAsksNoOneOnALarryOrAHaikuBoard`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who wants to draw undisturbed
- **I want to** switch *Ask at my pauses* off in the board's bar
- **so that** my pauses don't ask Larry or Claude for suggestions until I switch it back on

#### Acceptance Criteria:
- **Scenario:** Ask at my pauses off
- **Given:** I turned *Ask at my pauses* off in the board's bar
- **When:** I draw a stroke and lift the Pencil
- **Then:** nothing is asked and no ghost appears

---

### User Story 1114:

- **Summary:** Writing with *Ask at my pauses* off says no one is watching
- **Status:** implemented in [ee309dda](https://github.com/idvorkin/context-grabber/commit/ee309dda); verified on the host (`WhiteboardGhostTurnsTests`: the first stroke with Ghosts off sets the line and it stays; `WhiteboardNoteTests`: the line holds the middle) and the Mac build. Not yet seen on the iPad. Worded for *Ask at my pauses* in [767aabac](https://github.com/idvorkin/context-grabber/commit/767aabac) (story 1171), read on the iPad simulator by `WhiteboardTurnUITests.testAskAtMyPausesOffAsksNoOneOnALarryOrAHaikuBoard`
- **Issues:** bead `context-grabber-bozm` (iPad, 2026-11-22: a tap meant for the mic landed on Ghosts at 13:31; 16 minutes of writing went to no one, with nothing on screen saying so)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who turned *Ask at my pauses* off, maybe without meaning to
- **I want to** be told, as I write, that nobody is looking at the board
- **so that** I don't write for minutes waiting for Larry or Claude to answer a board neither of them can see

#### Acceptance Criteria:
- **Scenario:** Writing with *Ask at my pauses* off
- **Given:** *Ask at my pauses* is off on a board
- **When:** I draw a stroke
- **Then:** the bar's note says *Ask at my pauses is off, so no one is watching: turn it on for a look*, and it stays there while I keep writing, past the note's usual few seconds; nothing is asked, as before

---

### User Story 1113:

- **Summary:** Turning *Ask at my pauses* back on takes the no-one-is-watching line away
- **Status:** implemented in [ee309dda](https://github.com/idvorkin/context-grabber/commit/ee309dda); verified on the host (`WhiteboardGhostTurnsTests`: Ghosts on clears the line and the next stroke asks) and the Mac build. Not yet seen on the iPad
- **Issues:** bead `context-grabber-bozm`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who was told no one is watching the board
- **I want to** see the line go once I turn *Ask at my pauses* back on
- **so that** the bar never says no one is watching when someone is

#### Acceptance Criteria:
- **Scenario:** Ask at my pauses back on
- **Given:** the bar says no one is watching
- **When:** I turn *Ask at my pauses* on
- **Then:** the line goes, and my next pause asks as usual

---

### User Story 1116:

- **Summary:** The log marks when writing to no one began, once
- **Status:** implemented in [ee309dda](https://github.com/idvorkin/context-grabber/commit/ee309dda), held to one line however the bar's note changes in the review round; verified on the host (`WhiteboardGhostTurnsTests`: only the first stroke since Ghosts went off begins the spell, a mic tap between strokes doesn't begin another) and the Mac build. Not yet seen on the iPad
- **Issues:** bead `context-grabber-bozm` (the iPad log had no line at all for 16 minutes of unwatched writing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** reading a session log after a board went quiet
- **I want to** find one line where writing with *Ask at my pauses* off began
- **so that** I can tell when the board stopped being watched without wading through a line per stroke

#### Acceptance Criteria:
- **Scenario:** The log says when it began
- **Given:** *Ask at my pauses* is off, and a mic tap or Larry's words may have taken the bar's line since
- **When:** I draw strokes after the switch goes off
- **Then:** the session log has one line, at the first of them, recording that the switch was off, not one per stroke

---

### User Story 352:

- **Summary:** The board still draws when ghosts can't be reached
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); not verified by a test
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing away from the tailnet
- **I want to** keep drawing and be told once why no ghosts come
- **so that** a missing Cockpit neither interrupts me nor looks like nothing to suggest

#### Acceptance Criteria:
- **Scenario:** The Cockpit is away
- **Given:** *Ask at my pauses* is on and the Cockpit can't be reached
- **When:** I draw a stroke and lift the Pencil
- **Then:** the stroke stays, and the bar says ghosts aren't answering, unless Larry's line is showing there

---

### User Story 353:

- **Summary:** Larry can't be reached
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), on the chat path in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); not verified by a test; a tap on *Send to Larry* waits in the outbox instead since [90663552](https://github.com/idvorkin/context-grabber/commit/90663552) (story 1190), so this holds only for a picture a pause hands him
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** see why he didn't get it
- **so that** I don't wait for an answer to a picture he never had

#### Acceptance Criteria:
- **Scenario:** Larry away
- **Given:** the Cockpit can't be reached
- **When:** a pause hands him the picture on a Larry board
- **Then:** the bar shows a copyable problem saying so, and the board is unchanged

---

### User Story 354:

- **Summary:** Ghosts on a device where a finger draws
- **Status:** app side implemented on this branch; WhiteboardTurnUITests.testAFingerTapOffAGhostDismissesItAndOnOneKeepsIt (gone: the old canvas went in a5f33353) verified on the simulator by `WhiteboardTurnUITests` (an old-canvas test, dropped 2026-11-07; on paper `WhiteboardPaperGhostsUITests.testAGhostShowsOnThePaperAndKeepMakesItInk` and `testATapOffLetsAFingerDrawWithTheMarksShowingAndATapOnOneStillChoosesIt` (which since bead context-grabber-3rk holds the tap-off-keeps-the-ghost test, testATapOffKeepsTheGhostDismissRemovesItAndAFingerDrawsAgain) hold it since story 825); an iPhone and an iPad with no Pencil not yet tried. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first and Larry's only once his are all that's left (stories 663, 664); on branch `native/batch-decided-1114` (#883, story 825) a tap on a ghost offers Keep and Dismiss and a tap off them does nothing, verified by host tests and the Mac build, simulator and device still to do
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a finger, on an iPad with no Pencil (an iPhone only looks since story 746)
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** tapping a suggestion doesn't draw a dot and lose it

#### Acceptance Criteria:
- **Scenario:** A finger tap while ghosts show
- **Given:** a finger draws on this device and ghosts are showing
- **When:** I tap a ghost
- **Then:** Keep and Dismiss show beside it and no dot is drawn (story 825); once no ghost is left, kept, dismissed or faded, my finger draws again; a tap off them gives it back sooner, unless the Pencil has been used (stories 1152, 1153)

---

### User Story 1152:

- **Summary:** A tap off Larry's marks lets my finger write again
- **Status:** implemented in 109b21ad, dd0b1862, eae5ad2b and 62794265 (branch `native/finger-draws-2eml`; 62794265 and the review fixes after it, 570dd335 (a tap off ends once no mark is left, even with his controls showing) and 661f510d (with only his controls showing a tap leaves the finger tapping), verified on the host and the Mac build only); verified at eae5ad2b on the host (`WhiteboardFingerTests`), the Mac build, and the iPad simulator (`WhiteboardPaperGhostsUITests.testATapOffLetsAFingerDrawWithTheMarksShowingAndATapOnOneStillChoosesIt`, the board's verdict read through `GRABBER_WHITEBOARD_FINGER_LABEL`, as XCUITest's finger draws on the simulator whatever PaperKit's touch is); a real finger on the iPad not yet tried. The tap-off-keeps-the-ghost test is folded into this one, one launch for both (bead context-grabber-3rk), in cbf0240f: it now also checks that the stray tap dismisses nothing, Dismiss keeps nothing, and a finger draws again (stories 354, 616, 808, 810); verified on the iPad Pro 11-inch (M5) simulator (rung 2, `WhiteboardPaperGhostsUITests` 21 tests, this one passing first try).
- **Issues:** context-grabber-2eml (the iPad "looks like it's stuck": with Larry's marks showing, five finger drags panned and drew nothing, and the tap off that followed left the finger panning)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** writing with a finger and no Pencil
- **I want to** get my pen back with one tap on empty paper while Larry's marks still show
- **so that** the board never feels stuck, and I can keep or dismiss his marks later

#### Acceptance Criteria:
- **Scenario:** A tap off the marks, then writing
- **Given:** no Pencil has touched a board, and Larry's or Claude's marks are showing, so a finger drag pans
- **When:** I tap empty paper, on no mark and outside my selection
- **Then:** Keep and Dismiss go away, nothing is dismissed and no dot is left, and my next finger drag draws ink with the marks still showing
- **And:** a tap on a mark still brings its Keep and Dismiss, with no dot left where I tapped
- **And:** once no mark is left, the next marks set my finger to tapping and panning again, and so do his controls if they still show (story 846)
- **And:** the session log says `finger_draws` with `why: tap_off`

---

### User Story 1153:

- **Summary:** With the Pencil in use, a finger never draws
- **Status:** implemented in 109b21ad, dd0b1862, eae5ad2b and 62794265 (branch `native/finger-draws-2eml`; 62794265 and the review fixes after it, 570dd335 (a tap off ends once no mark is left, even with his controls showing) and 661f510d (with only his controls showing a tap leaves the finger tapping), verified on the host and the Mac build only); verified at eae5ad2b on the host (`WhiteboardFingerTests`), the Mac build, and the iPad simulator (`WhiteboardPaperGhostsUITests.testOnceThePencilHasTouchedAFingerNeverDraws`, `GRABBER_WHITEBOARD_PENCIL=seen` standing in for the Pencil); the real Pencil and finger on the iPad not yet tried
- **Issues:** context-grabber-2eml (Igor, 2026-11-22: "I should never have finger drawn if I'm using the pencil"; the iPad log has Pencil and finger strokes on one board)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** writing with the Pencil
- **I want to** my finger only to pan, select and tap
- **so that** a resting or moving finger never leaves stray ink

#### Acceptance Criteria:
- **Scenario:** The Pencil has touched a board
- **Given:** the Pencil has touched any board since the app launched (or the system's "Only Draw with Apple Pencil" is on)
- **When:** I drag a finger on a board, with marks showing or none, before or after a tap off the marks
- **Then:** it pans or selects, and draws nothing
- **And:** the session log says `finger_draws` with `why: pencil` when the Pencil takes the finger's pen

---

### User Story 663:

- **Summary:** A stray tap leaves Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone (gone: replaced by story 825's Keep and Dismiss in 799018ee)) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad; changed on branch `native/batch-decided-1114` (#883, story 825): a tap off the marks dismisses nothing, and a mark goes only by its own Dismiss; verified by host tests and the Mac build, simulator and device still to do
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good), [#883](https://github.com/idvorkin/context-grabber/issues/883) (Keep and Dismiss beside the mark, story 825)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on a board where Claude and Larry have both drawn back
- **I want to** have a tap off the ghosts dismiss nothing, Claude's or Larry's (first built as dismissing only Claude's; changed by story 825)
- **so that** one stray tap can't lose Larry's marks, which can't come back

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with both showing
- **Given:** Claude's ghosts and Larry's marks are both showing
- **When:** I tap off them
- **Then:** nothing is dismissed: Claude's and Larry's all stay (story 825)

---

### User Story 664:

- **Summary:** A deliberate choice clears Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone (gone: replaced by story 825's Keep and Dismiss in 799018ee)) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad; changed on branch `native/batch-decided-1114` (#883, story 825): a tap off the marks dismisses nothing, and a mark goes only by its own Dismiss; verified by host tests and the Mac build, simulator and device still to do; criteria changed by #1383 (a reply of several marks is chosen and dismissed whole, stories 1285, 1286) in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9), verified there
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good), [#883](https://github.com/idvorkin/context-grabber/issues/883) (Keep and Dismiss beside the mark, story 825)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has looked at Larry's marks and doesn't want them
- **I want to** dismiss Larry's marks only with the *Dismiss* beside each (first built as a tap off them once they were all that was left; changed by story 825)
- **so that** clearing his always takes a tap of its own

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with only Larry's left
- **Given:** only Larry's marks are showing
- **When:** I tap Dismiss beside each of them (story 825)
- **Then:** each goes as I dismiss it (a reply of several marks goes at once, by *Dismiss group*: story 1286), and a tap off them dismisses nothing

---

### User Story 666:

- **Summary:** A palm resting before the Pencil doesn't make the stroke a finger's
- **Status:** implemented in [b0e8221](https://github.com/idvorkin/context-grabber/commit/b0e8221); verified on the host (`PaperProbeTests`) and the Mac build; the Pencil-and-palm line not yet seen in an iPad log
- **Issues:** [#825](https://github.com/idvorkin/context-grabber/issues/825) (a run was typed by its first touch, so a palm made the Pencil's strokes a finger's)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding what a palm and a finger should do on paper
- **I want to** have a touch logged as the Pencil's whenever the Pencil was in it, with what else was touching
- **so that** the next iPad log tells a resting palm from a finger (story 600)

#### Acceptance Criteria:
- **Scenario:** A palm resting before the Pencil
- **Given:** a board on paper
- **When:** my palm lands first and then the Pencil draws, before both lift
- **Then:** the line says the Pencil drew, counts how many touches of each kind it held, and gives the largest finger contact's size

---

### User Story 825:

- **Summary:** Keep and Dismiss beside a tapped mark
- **Status:** implemented on branch `native/batch-decided-1114`, merged in #909 ([09171cae](https://github.com/idvorkin/context-grabber/commit/09171cae)); verified by host tests (`WhiteboardMarkChoiceTests`: the tap and where the buttons sit) and the Mac build. Fixed in [6754880](https://github.com/idvorkin/context-grabber/commit/6754880): the dot PaperKit draws under a finger's tap is taken back (`PaperProbeTests.testATapsDotIsTheSmallInkAtTheTapJustAfterIt`), and Keep and Dismiss carry their own names; verified on an iPad simulator by `WhiteboardPaperGhostsUITests`, three runs, every test passing first time. The iPad itself still to do; criteria changed by #1383 (a reply of several marks is chosen and dismissed whole, stories 1285, 1286) in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9), verified there
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** see Keep and Dismiss beside a mark I tap, wholly on screen
- **so that** a tap never keeps or loses a mark without my saying which

#### Acceptance Criteria:
- **Scenario:** A tap on a mark at the edge
- **Given:** Larry's marks are showing on a board, one of them at the edge of the screen
- **When:** I tap the one at the edge
- **Then:** nothing on the board has changed, only Keep and Dismiss show beside it, wholly on screen; Keep keeps that mark and the rest of its reply (story 1154), Dismiss that mark alone; beside a reply of several marks they read *Keep group* and *Dismiss group* and take the whole reply (stories 1285, 1286)

---

### User Story 1154:

- **Summary:** Keep beside any mark of Larry's reply keeps the whole reply as one group
- **Status:** implemented in 04f92c9f (bead context-grabber-it0e); verified by host tests (`WhiteboardKeepReplyTests.testKeepBesideOneEyeKeepsAllSevenOfTheFace`) and the simulator (`WhiteboardTheirsTapUITests.testKeepBesideOneMarkOfAReplyKeepsTheWholeReply`); criteria changed by #1383 (a reply of several marks is chosen and dismissed whole, stories 1285, 1286) in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9), verified there
- **Issues:** bead context-grabber-it0e (Igor on the iPad, 2026-11-22 21:28: "Keep is not keeping the group properly"; he kept one eye, both labels and the arrow of Larry's 7-mark smiley face one mark at a time, and the face circle, the smile and the other eye stayed behind as marks to keep. Igor chose option A at 21:34)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep beside any mark of a reply keeps the whole reply*

#### Use Case:
- **As someone** keeping a picture Larry drew me out of several marks
- **I want to** tap Keep beside any one of its marks and have the whole picture kept
- **so that** I never leave half of his drawing behind by keeping it piece by piece

#### Acceptance Criteria:
- **Scenario:** Keep beside one mark of a reply
- **Given:** Larry's reply of seven marks shows (a face circle, a smile, two eyes, an arrow and two labels), and *Keep group* and *Dismiss group* show beside it, chosen by a tap on one eye (story 1285)
- **When:** I tap Keep
- **Then:** all seven become ink where they showed, as one group named for his reply, no marks of that reply are left to keep, and one undo named *Keep* takes all seven back

---

### User Story 1210:

- **Summary:** Most of a reply is kept by keeping the group and erasing the piece I don't want
- **Status:** implemented in 04f92c9f (bead context-grabber-it0e), when Dismiss took one mark; since #1383 (story 1286) Dismiss beside a reply of several marks takes the whole reply, and a piece is dropped after *Keep group* by erasing it, in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9); the erase of a kept group's piece is story 1149's and 1193's, verified there
- **Issues:** bead context-grabber-it0e; #1383
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of several marks shows, is chosen and is turned down as one group*

#### Use Case:
- **As someone** keeping most of a picture Larry drew me
- **I want to** keep it as one group and then erase the piece I don't want
- **so that** the piece I turned down is gone and the rest stays one picture

#### Acceptance Criteria:
- **Scenario:** Keep the group, then erase a piece
- **Given:** Larry's reply of seven marks shows, and I kept it with *Keep group* beside one eye
- **When:** I erase its arrow
- **Then:** the arrow is gone, and the other six stay one group that a drag picks up whole

---

### User Story 1285:

- **Summary:** Larry's reply of several marks arrives outlined as one group, and a tap on any of it offers Keep group
- **Status:** implemented in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9); verified by host tests (`WhiteboardKeepReplyTests`, `WhiteboardMarkChoiceTests`; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-24, *iPad Pro 11-inch (M5)*: `WhiteboardTheirsTapUITests`, `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTurnUITests`, 37 tests, 1 skipped, none failing); not yet seen on the iPad (`testKeepBesideOneMarkOfAReplyKeepsTheWholeReply`: *Keep group* beside his reply of three)
- **Issues:** #1383 (Igor on the iPad, 2026-11-24 05:07: Larry's four list lines came as four separate marks; he dismissed three one at a time and kept one, then: "it should've come in as keep group")
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of several marks shows, is chosen and is turned down as one group*

#### Use Case:
- **As someone** reading a reply Larry drew me in several marks
- **I want to** see it as one group and have a tap on any of it offer to keep the group
- **so that** I keep his whole answer in one tap instead of judging it line by line

#### Acceptance Criteria:
- **Scenario:** A tap on one label of a reply of four offers Keep group
- **Given:** Larry's reply of four labels shows as marks to keep, a faint dashed outline in his colour round all four
- **When:** I tap the third label with a finger
- **Then:** *Keep group* and *Dismiss group* sit beside the outline round all four

---

### User Story 1303:

- **Summary:** Another mark of the reply I chose changes nothing
- **Status:** implemented in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9); verified by host tests (`WhiteboardKeepReplyTests.testATapChoosesTheWholeReplyAndAnotherOfItsMarksChangesNothing`; `just test`)
- **Issues:** #1383
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of several marks shows, is chosen and is turned down as one group*

#### Use Case:
- **As someone** who chose a reply Larry drew me in several marks
- **I want to** a tap on another of its marks to leave the choice as it is
- **so that** a second tap on the same answer doesn't move or reset its buttons

#### Acceptance Criteria:
- **Scenario:** A tap on another mark of the chosen reply
- **Given:** Larry's reply of four labels is chosen, *Keep group* and *Dismiss group* beside its outline
- **When:** I tap another of the four
- **Then:** nothing changes: the same reply stays chosen, its buttons where they were

---

### User Story 1304:

- **Summary:** One mark is chosen alone, with no outline
- **Status:** implemented in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9); verified by host tests (`WhiteboardKeepReplyTests.testALoneMarkHisTextAndClaudesAreKeptAlone`, `testTheOutlinedRepliesAreHisRepliesOfTwoOrMore`; `just test`)
- **Issues:** #1383
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of several marks shows, is chosen and is turned down as one group*

#### Use Case:
- **As someone** looking at a single mark Larry or Claude drew
- **I want to** keep or dismiss it as before
- **so that** a one-mark answer isn't dressed up as a group

#### Acceptance Criteria:
- **Scenario:** One mark shows as before
- **Given:** a reply of Larry's with one mark showing, or one of Claude's marks
- **When:** I tap it
- **Then:** there is no outline, and *Keep* and *Dismiss* sit beside that mark

---

### User Story 1286:

- **Summary:** Dismiss group turns down Larry's whole reply
- **Status:** implemented in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9); verified by host tests (`WhiteboardKeepReplyTests`, `WhiteboardMarkChoiceTests`; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-24, *iPad Pro 11-inch (M5)*: `WhiteboardTheirsTapUITests`, `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTurnUITests`, 37 tests, 1 skipped, none failing); not yet seen on the iPad (`testDismissGroupBesideOneMarkTakesTheWholeReply`)
- **Issues:** #1383
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of several marks shows, is chosen and is turned down as one group*

#### Use Case:
- **As someone** turning down a reply Larry drew me in several marks
- **I want to** dismiss it in one tap
- **so that** I don't clear his answer piece by piece

#### Acceptance Criteria:
- **Scenario:** Dismiss group
- **Given:** two replies of Larry's show, one of four labels and one of two, and *Keep group* and *Dismiss group* show beside the four
- **When:** I tap *Dismiss group*
- **Then:** all four go, the other reply's two still show, and none of the four come back when the board opens again

---

### User Story 1211:

- **Summary:** Keep beside a reply's mark leaves another reply's marks showing
- **Status:** implemented in 04f92c9f (bead context-grabber-it0e); verified by host tests (`WhiteboardKeepReplyTests.testKeepBesideOneEyeKeepsAllSevenOfTheFace`); criteria changed by #1383 (a reply of several marks is chosen and dismissed whole, stories 1285, 1286) in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9), verified there
- **Issues:** bead context-grabber-it0e
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep beside any mark of a reply keeps the whole reply*

#### Use Case:
- **As someone** looking at two replies Larry drew
- **I want to** keep one reply without keeping the other
- **so that** I still decide on each of his replies by itself

#### Acceptance Criteria:
- **Scenario:** Another reply's marks stay
- **Given:** two of Larry's replies show, *Keep group* and *Dismiss group* beside the first, chosen by a tap on one of its marks
- **When:** I tap Keep
- **Then:** the whole first reply is kept and the second's marks still show, to keep or dismiss

---

### User Story 1212:

- **Summary:** Keep beside a lone mark, his text or Claude's mark keeps it alone
- **Status:** implemented in 04f92c9f (bead context-grabber-it0e); verified by host tests (`WhiteboardKeepReplyTests.testALoneMarkHisTextAndClaudesAreKeptAlone`)
- **Issues:** bead context-grabber-it0e
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep beside any mark of a reply keeps the whole reply*

#### Use Case:
- **As someone** keeping a mark that belongs to no reply still showing
- **I want to** have Keep keep just that mark
- **so that** Keep never reaches past what I chose when there is no reply to keep

#### Acceptance Criteria:
- **Scenario:** A lone mark, his text, Claude's marks
- **Given:** a reply with only one mark left showing, his text from a change, or one of Claude's marks, with Keep and Dismiss beside it
- **When:** I tap Keep
- **Then:** that mark alone is kept, as before

---

### User Story 808:

- **Summary:** Dismiss beside a mark removes only it
- **Status:** implemented on branch `native/batch-decided-1114`, merged in #909 ([09171cae](https://github.com/idvorkin/context-grabber/commit/09171cae)); verified by host tests (`WhiteboardMarkChoiceTests.testDismissRemovesOnlyThatMark`, `WhiteboardMarksTests.testSettlingRemembersOnlyTheKeptOrDismissedMarksOfRowsStillShowing`) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do; criteria changed by #1383 (a reply of several marks is chosen and dismissed whole, stories 1285, 1286) in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9), verified there
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** dismiss one mark with the Dismiss beside it
- **so that** I turn down that mark and keep thinking about the rest

#### Acceptance Criteria:
- **Scenario:** Dismissing one of his marks
- **Given:** Keep and Dismiss show beside one of Larry's three marks, no two of them from one reply (a reply of several goes whole: story 1286)
- **When:** I tap Dismiss
- **Then:** only that mark goes, and when the board opens again it stays gone while his other two show

---

### User Story 809:

- **Summary:** Keep beside a mark makes it ink
- **Status:** implemented on branch `native/batch-decided-1114`, merged in #909 ([09171cae](https://github.com/idvorkin/context-grabber/commit/09171cae)); verified by host tests (`WhiteboardMarkChoiceTests.testKeepTakesTheChosenMarkOffTheGhosts`) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing); context-grabber-ikya (a kept text of Larry's drew black all but its first glyph, now and then on the iPad simulator, 2026-11-20 and 21: PaperKit held every stroke purple and drew one tile of it blank or black; the board now finds that and draws the mark again, story 650, since [ce66651b](https://github.com/idvorkin/context-grabber/commit/ce66651b))
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** keep a mark with the Keep beside it
- **so that** it joins my drawing only because I said so

#### Acceptance Criteria:
- **Scenario:** Keeping a mark
- **Given:** Keep and Dismiss show beside a mark, the only one of its reply still showing
- **When:** I tap Keep
- **Then:** it becomes ink in its colour, and one undo takes it back (a mark with others of its reply showing keeps them too: story 1154)

---

### User Story 810:

- **Summary:** A stray tap or a stroke puts Keep and Dismiss away
- **Status:** implemented on branch `native/batch-decided-1114`, merged in #909 ([09171cae](https://github.com/idvorkin/context-grabber/commit/09171cae)); verified by host tests (`WhiteboardMarkChoiceTests`: the stray tap and the stroke) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** have a tap off the marks, or a stroke, only put the buttons away
- **so that** a stray touch never keeps or loses a mark

#### Acceptance Criteria:
- **Scenario:** A stray tap or a stroke
- **Given:** Keep and Dismiss are showing beside a mark
- **When:** I tap off the marks, or start drawing with the Pencil
- **Then:** the buttons go, every mark is still showing, nothing is kept, and the Pencil's stroke is drawn

---

### User Story 967:

- **Summary:** A tap on my selection brings up its menu while Larry's marks show
- **Status:** implemented in [57dc58d5](https://github.com/idvorkin/context-grabber/commit/57dc58d5); verified by host tests (`WhiteboardMarkChoiceTests`: the iPad's own selection box and tap keep the selection, a tap on a mark or off the box lets it go; `just native-test`) and the Mac build (`just native-build-mac`); the simulator (rung 2) is owed, as the simulator stack was wedged on 2026-11-22, and the iPad still to do
- **Issues:** [#1170](https://github.com/idvorkin/context-grabber/issues/1170) (the iPad, 2026-11-22: ink selected, Larry's three marks landed, a finger tap on the selection cleared it, `paper_tap` `selected_at_tap` 6, and the menu came up as *Paste* and *Select All*, so there was no Delete)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on his own selection is still his*

#### Use Case:
- **As someone** who selected some of my ink while Larry's marks are on the board
- **I want to** tap my selection and get its menu, Delete among it
- **so that** Larry's marks arriving never stop me deleting what I selected

#### Acceptance Criteria:
- **Scenario:** Deleting a selection with Larry's marks showing
- **Given:** Larry's marks are showing and some of my ink is selected
- **When:** I tap with a finger inside the selection, away from his marks
- **Then:** the selection stays, its menu shows with Delete, and Delete removes that ink

---

### User Story 1196:

- **Summary:** A tap inside my own selection is always the selection's
- **Status:** implemented in 9e1033f5; verified by host tests (`WhiteboardMarkChoiceTests.testATapInsideHisSelectionOnOneThingInItKeepsTheSelection`; `just native-test`) and the Mac build (`just native-build-mac`); the iPad simulator (rung 2) and the iPad are owed
- **Issues:** bead context-grabber-nkh (read from the code on main, 2026-11-22, in the stories coherence pass, bead context-grabber-2qb; not reproduced on a device). The bead named this story 1153, which another story took first.
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on his own selection is still his*, *What the tap lands on inside it doesn't matter*

#### Use Case:
- **As someone** who lassoed several things at once, a group of Larry's and a kept text among them
- **I want to** tap inside my selection and get its menu, whatever my finger lands on
- **so that** the thing under my finger never takes my selection away or opens for rewording

#### Acceptance Criteria:
- **Scenario:** A tap on a group or a text inside a lasso selection
- **Given:** no marks of Larry's showing, and a lasso selection round a kept group and a kept text
- **When:** I tap with a finger inside the selection, on the group's stroke or on the text
- **Then:** the whole selection stays and its menu shows; the group is not selected alone and the text does not open
- **And:** the session log says `selection_kept_tap` with what the tap landed on, and `selection_kept_held` a beat later

---

### User Story 968:

- **Summary:** Delete on the selection's menu works while Larry's marks show
- **Status:** implemented in [9be51be3](https://github.com/idvorkin/context-grabber/commit/9be51be3); verified by host tests (`PaperProbeTests`: a tap that begins on PaperKit's menu is the menu's; `just native-test`) and the Mac build (`just native-build-mac`); the simulator (rung 2) and the iPad still to do
- **Issues:** bead context-grabber-tcy0 (the iPad, 2026-11-22, board 8f986938: a text selected with Larry's three marks showing, four taps on the menu's Delete, each `paper_tap` with `selected_at_tap` 1 at the menu, `paper_selection` 0 a millisecond before it, and no `paper_ink` removed)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on the selection's menu is the menu's*

#### Use Case:
- **As someone** who selected something on the board while Larry's marks are showing
- **I want to** tap Delete on the small menu beside my selection
- **so that** it is gone, as it would be with no marks on the board

#### Acceptance Criteria:
- **Scenario:** Deleting from the selection's menu with Larry's marks showing
- **Given:** Larry's marks are showing and a text (or some of my ink) is selected, with its small menu beside it
- **When:** I tap Delete on that menu with a finger
- **Then:** what was selected is removed, the marks stay, and no mark under the menu is chosen

---

### User Story 355:

- **Summary:** Keep Larry's mark
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); the keep itself is checked on the simulator through Claude's ghost (`WhiteboardTurnUITests`), the same path; blue ink on the iPad not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** keep the marks of his I agree with
- **so that** his answer joins my drawing only where I want it

#### Acceptance Criteria:
- **Scenario:** A purple ghost, kept
- **Given:** Larry's faint purple shapes are showing
- **When:** I tap one, then *Keep* beside it (story 825)
- **Then:** it becomes purple ink that my eraser and undo treat like mine

---

### User Story 356:

- **Summary:** Larry's marks stay when *Ask at my pauses* goes off
- **Status:** app side implemented in [e2f693e](https://github.com/idvorkin/context-grabber/commit/e2f693e); verified on the simulator by the session log (`whiteboard` ghosts: Ghosts off drops Claude's one ghost, then Larry's turn shows his two); a UI test could not read it, as the Ghosts button's accessibility label does not refresh for XCUITest while Ghosts is off; on the iPad not yet. Renamed *Ask at my pauses* in [767aabac](https://github.com/idvorkin/context-grabber/commit/767aabac) (story 1171), Larry's two marks staying with it off read on the iPad simulator by `WhiteboardTurnUITests.testAskAtMyPausesOffAsksNoOneOnALarryOrAHaikuBoard`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn and wants Claude to stop suggesting
- **I want to** turn off *Ask at my pauses* without losing what Larry drew
- **so that** the switch only stops the asking, and Larry's answer already showing waits for me to keep it

#### Acceptance Criteria:
- **Scenario:** Turning off Ask at my pauses with Larry's marks showing
- **Given:** Larry's faint purple shapes are showing
- **When:** I turn *Ask at my pauses* off in the board's bar
- **Then:** his shapes stay and I can still keep them

---

### User Story 357:

- **Summary:** Each new set of ghosts replaces only its author's last one
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3) (Larry's turn no longer drops Claude's); Larry's marks leaving Claude's in place verified on the simulator by `WhiteboardTurnUITests`; Claude's new answer replacing his own, and the draw-in, to try on the iPad (a finger can't draw while ghosts show on the simulator)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing while Claude and Larry suggest
- **I want to** see each one's newest marks replace only their own
- **so that** one voice never wipes out the other's

#### Acceptance Criteria:
- **Scenario:** A new set
- **Given:** Claude's orange ghosts and Larry's purple ones are showing
- **When:** I pause and Claude answers again
- **Then:** Claude's old ghosts fade out as his new ones draw in one after another, and Larry's stay

---

### User Story 358:

- **Summary:** Claude's ghosts fade when they're left alone
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11); verified on the simulator by `WhiteboardTurnUITests` (its Claude's-ghosts-fade test, with the time shortened); since bead `context-grabber-5eq` by host tests instead (`WhiteboardGhostTurnsTests.testClaudesGhostsFadeAfterTheirTimeAndLarrysStay`: Claude's go at 30 s and Larry's stay, a newer answer starts the 30 s over, Larry's never fade)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on past a suggestion
- **I want to** have Claude's ghosts go by themselves after a while
- **so that** a suggestion doesn't sit on a drawing that has moved past it

#### Acceptance Criteria:
- **Scenario:** Left alone
- **Given:** Claude's orange ghosts and Larry's purple ones are showing
- **When:** 30 s pass with nothing new from Claude
- **Then:** Claude's fade away, and Larry's stay until I keep or dismiss them

---

### User Story 370:

- **Summary:** Claude's marks arrive one at a time
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: partial lines, unknown lines skipped, the last line) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: six marks climb the count); since bead `context-grabber-5eq` the climb is a host test (`WhiteboardGhostTurnsTests`: six streamed marks land one at a time, the first replacing Claude's last set), and the simulator keeps one streamed mark reaching the screen (`testAPauseBringsAGhostAndLarryTakesATurn`). The real Cockpit streams (cockpit f208f6c; a live request, 2026-11-02: 200 `application/x-ndjson`, a label, an arrow and the last line); the app reading it and the first-mark time are still to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** see his marks appear one at a time as he makes them
- **so that** it feels like someone sketching, not a picture arriving

#### Acceptance Criteria:
- **Scenario:** Marks as he makes them
- **Given:** *Ask at my pauses* is on, I paused, and the Cockpit streams its answer
- **When:** the marks come
- **Then:** each one draws itself in as it arrives and the count in the bar climbs

---

### User Story 371:

- **Summary:** Ghosts look like ink
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified on the simulator by a screenshot from `WhiteboardTurnUITests`, solid orange lines on an iPhone simulator (since bead `context-grabber-5eq` the screenshot is `testAPauseBringsAGhostAndLarryTakesATurn`'s, Claude's ghost and Larry's two); how they sit beside real Pencil ink is to judge on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** deciding whether to keep a mark
- **I want to** see a ghost drawn as the ink it would become, only fainter
- **so that** I can judge how it looks on the board before I tap it

#### Acceptance Criteria:
- **Scenario:** Solid, not dashed
- **Given:** a ghost is showing, Claude's in orange or Larry's in purple
- **When:** I look at it
- **Then:** it is a solid faint line with round ends, as wide as a kept stroke, and a label shows its letters written in single strokes (since story 1049; before, their outlines)

---

### User Story 372:

- **Summary:** Claude's old marks go when his new ones start
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); not covered by a test; to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** keep his earlier marks until the first new one lands
- **so that** the board is never blank between his answers

#### Acceptance Criteria:
- **Scenario:** The old set goes when the new one starts
- **Given:** Claude's earlier ghosts are showing and a new turn is on its way
- **When:** the first new mark lands
- **Then:** the earlier ones go then, not when the turn was asked, and Larry's stay

---

### User Story 377:

- **Summary:** A ghost is no part of the drawing until it's kept
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); the kept line at full strength is not covered by a test; to judge on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** deciding whether to keep a mark
- **I want to** have a ghost stay out of the drawing until I tap it
- **so that** nothing changes my board unless I choose it

#### Acceptance Criteria:
- **Scenario:** Still only a ghost
- **Given:** a ghost is showing
- **When:** I don't tap it
- **Then:** it is no part of the drawing until I do, and keeping it gives the same line at full strength

---

### User Story 383:

- **Summary:** A board opens with his newest marks and the ones still showing when it closed, and a dismissed set stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: reopened with his newest set). Changed in [10727b6c](https://github.com/idvorkin/context-grabber/commit/10727b6c) (bead `context-grabber-n8ab`, story 1155): an earlier row still showing when the board closed comes back with the newest; verified by host tests (`WhiteboardMarksTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** coming back to a board Larry has drawn on for days
- **I want to** see where he has got to and what of his I left to deal with, and never what I already turned down
- **so that** closing the board loses nothing of his, and it isn't buried in rows I never saw

#### Acceptance Criteria:
- **Scenario:** Opening a board
- **Given:** several replies still had marks showing when I closed the board
- **When:** I open the board
- **Then:** his newest available row shows with its line, alongside up to 20 rows remembered on this device, including
  marks from a thread the Cockpit lost. Marks I kept or dismissed stay gone

---

### User Story 1155:

- **Summary:** His earlier marks stay when he replies again
- **Status:** implemented in [10727b6c](https://github.com/idvorkin/context-grabber/commit/10727b6c). Host tests (`WhiteboardMarksTests`, `WhiteboardGhostTurnsTests`, `BoardMarksReplayTests`), the Mac build, and the simulator (`WhiteboardTurnUITests.testLarrysMarksArriveOnTheirOwnAndAStrayTapLeavesThem`) verified that his second reply's three marks join the first's two and a stray tap leaves all five. The iPad check is pending
- **Issues:** bead `context-grabber-n8ab`: Igor, 2026-11-22 12:35 on board 8f986938 (iPad log): Larry's 12-mark sequence diagram (row 99edfb64758e) was showing; his next reply, a label with a question card (row 4d4bc5dd9efd), took the board from 12 marks to 1, and the reply after it replaced that one too
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A new reply adds his marks, never clears them*; Igor's design-board decision 20 of 2026-11-22: his suggestions stay until kept or dismissed, across later replies and across closing and opening the board, and Claude's quick ghosts still fade (the answer dropped when the board was written past is story 350's)

#### Use Case:
- **As someone** thinking on the board with Larry
- **I want to** keep his diagram on the board while he goes on to add a label or ask me something
- **so that** nothing he drew disappears until I keep it or dismiss it

#### Acceptance Criteria:
- **Scenario:** A label and a question after a diagram
- **Given:** twelve marks of his diagram are showing and I have kept or dismissed none
- **When:** his next reply brings a label, and the one after a question card
- **Then:** the diagram's twelve marks stay, the label shows beside them, and the count to keep is thirteen

---

### User Story 388:

- **Summary:** A set I've dealt with stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b). Host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`) verified that a dismissed mark stays gone on the next look and on reopening. Story 808 covers settling individual marks. Extended to earlier replies in [10727b6c](https://github.com/idvorkin/context-grabber/commit/10727b6c), verified by the host `WhiteboardMarksTests`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has answered Larry's marks
- **I want to** never see what I already kept or turned down
- **so that** the board isn't nagging me about a settled question

#### Acceptance Criteria:
- **Scenario:** Already settled
- **Given:** I kept or dismissed marks from a row of his
- **When:** a look at the thread comes round, or I open the board again
- **Then:** those marks stay gone, including when I settled his newest row before dealing with the earlier ones

---

### User Story 698:

- **Summary:** Claude's and Larry's marks look the way they ask, and labels read as writing
- **Status:** implemented in [bb3f487](https://github.com/idvorkin/context-grabber/commit/bb3f487); verified on the host (`WhiteboardTurnTests`, 22 of 22, five new). Letters written in single strokes, not traced, in [ca0aa8a](https://github.com/idvorkin/context-grabber/commit/ca0aa8a) (#895, story 1049), verified on the host and the Mac build. Not yet seen on a device
- **Issues:** [#698](https://github.com/idvorkin/context-grabber/issues/698)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** drawing with Larry on the board
- **I want to** see his marks at the width, colour and lettering he chose, with labels in a thin pen
- **so that** what he writes reads like writing and his diagram says what he meant, not a bold marker

#### Acceptance Criteria:
- **Scenario:** A mark that asks for its look
- **Given:** a board with a thread, and Larry answers with a box in green at a fine pen and a label in the hand face
- **and Given:** another label of his that names no pen, colour or face
- **When:** his marks arrive and I keep them
- **Then:** the box is a green outline at the fine pen, the first label is in joined handwriting letters, the second is in his purple print at a thin pen, both written in single strokes rather than traced (story 1049), not bold (since story 1003, at the pen in my hand once the board knows it; never thinner than the iPad draws, story 772, so small letters read bolder), and each kept mark is ink exactly as its ghost showed

---

### User Story 1003:

- **Summary:** Larry's kept text is at the width of the pen in my hand
- **Status:** implemented in [1df5eda4](https://github.com/idvorkin/context-grabber/commit/1df5eda4); verified on the host (`WhiteboardTurnTests.testALabelTakesThePenInIgorsHand`; `just test`), the Mac build and the simulator smoke (`just native-test-sim`); the iPad whiteboard UI tests didn't start (the Mac's screen was locked); not yet seen on the iPad
- **Issues:** [#949](https://github.com/idvorkin/context-grabber/issues/949)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** writing on a board beside Larry's labels
- **I want to** have a label of his that names no pen drawn at the width of the pen I'm holding
- **so that** his text and mine read at one weight, not his thinner or bolder than my writing

#### Acceptance Criteria:
- **Scenario:** A label with no pen of its own
- **Given:** a board where I last held a pen of some width, then picked up the eraser
- **When:** Larry's label that names no pen shows, and I keep it
- **Then:** its ghost and its kept ink are at that pen's width (never thinner than the iPad draws, never wider than the widest pen), whatever its letters' size, and the eraser is still in my hand

---

### User Story 774:

- **Summary:** Larry's marks are his own colour, and keeping one leaves my pen alone
- **Status:** implemented in [4aee299](https://github.com/idvorkin/context-grabber/commit/4aee299), PR [#891](https://github.com/idvorkin/context-grabber/pull/891), the paper colours held to his purple in [e4efeae](https://github.com/idvorkin/context-grabber/commit/e4efeae); verified on the host (`just native-test`: `WhiteboardTurnTests.testLarrysColourIsNoneOfThePickersOrClaudes`, `BoardPaperTests.testLarrysPurpleInkReadsOnEveryColour` and `testGhostsAreNearlyAsVisibleAsOnPlain` with his purple) and the Mac build (`just native-build-mac`). That a keep leaves the pen as it was is story 778's, now on the iPad simulator. Not yet seen on a device
- **Issues:** bead context-grabber-a3w
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Larry's own colour*

#### Use Case:
- **As someone** writing back to Larry on a board in the picker's blue
- **I want to** see his marks in a colour I can't pick
- **so that** I can tell his writing from mine, and so can he

#### Acceptance Criteria:
- **Scenario:** His colour
- **Given:** a board, and Larry answers with marks that name no colour
- **When:** they arrive and I keep one
- **Then:** the ghost and the kept ink are purple, a colour none of the picker's swatches has

---

### User Story 778:

- **Summary:** Keeping one of Larry's marks leaves my pen alone
- **Status:** implemented in [4aee299](https://github.com/idvorkin/context-grabber/commit/4aee299), PR [#891](https://github.com/idvorkin/context-grabber/pull/891); split from story 774. Verified by the Mac build (`just native-build-mac`) and, with the test in [605a7202](https://github.com/idvorkin/context-grabber/commit/605a7202), the iPad simulator (rung 2: `WhiteboardPaperGhostsUITests.testKeepingHisMarkLeavesMyPenAsItWas` keeps one of Larry's circles and then draws: the next stroke is black, at the first stroke's width, with none of his purple; four passes; the default black pen, as the simulator can't pick the blue). The keep logs `paper_keep` tool_before, tool_after and tool_restored and puts the pen back if it ever changed. Not yet seen on a device
- **Issues:** bead context-grabber-a3w
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Larry's own colour*

#### Use Case:
- **As someone** writing back to Larry on a board in the picker's blue
- **I want to** keep one of his marks without my pen changing
- **so that** my next stroke is still mine, in the colour and width I chose

#### Acceptance Criteria:
- **Scenario:** My pen after a keep
- **Given:** I'm writing with the picker's blue pen at its width
- **When:** I tap one of Larry's ghosts, then *Keep* beside it (story 825), and write again
- **Then:** my next stroke is the same blue pen at the same width as before the keep

---

### User Story 772:

- **Summary:** A kept label of small letters stays on the board
- **Status:** implemented in [b54599d](https://github.com/idvorkin/context-grabber/commit/b54599d), the floor at 2.5 points in [b18aa04](https://github.com/idvorkin/context-grabber/commit/b18aa04); verified on the host (`just native-test`: `WhiteboardTurnTests.testNoMarkIsThinnerThanTheIPadDraws`, a small label's pen, a thin asked-for pen and an unasked line, and the rest of `WhiteboardTurnTests`) and by the Mac build (`just native-build-mac`); on the iPad simulator (rung 2, bead context-grabber-z8o): `WhiteboardPaperGhostsUITests.testASmallLabelKeptStaysOnTheCanvasAndInThePicture` keeps a label of 12-point letters asking for a 1-point pen by a tap and Keep, and finds it on the canvas as wide as its ghost and in Larry's purple in the next picture he gets; with the floor taken out the same test fails (the ghost showed, the kept ink drew nothing, `paper_kept_ink` `ink_px` 0, now `missing` **none**). Not yet seen on the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883); bead `context-grabber-z8o` (relayed by Larry: the 2026-11-14 board, thread igor2-88g.1461)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** keeping a label Larry wrote on my board
- **I want to** see it stay as ink where its ghost was
- **so that** a tap that keeps his words never looks like a tap that threw them away

#### Acceptance Criteria:
- **Scenario:** Small letters
- **Given:** a board on paper, and a label of Larry's with 12-point letters and no pen of its own
- **When:** I tap it, then *Keep* beside it (story 825)
- **Then:** it stays on the board as purple ink, as thick as its ghost was, and the next picture Larry gets shows it

---

### User Story 779:

- **Summary:** A mark that asks for a pen too thin to draw is drawn at the thinnest the iPad shows
- **Status:** implemented in [b54599d](https://github.com/idvorkin/context-grabber/commit/b54599d), the floor at 2.5 points in [b18aa04](https://github.com/idvorkin/context-grabber/commit/b18aa04); split from story 772. Verified on the host (`just native-test`: `WhiteboardTurnTests.testNoMarkIsThinnerThanTheIPadDraws`, a thin asked-for pen) and by the Mac build (`just native-build-mac`); on the iPad simulator (rung 2, bead context-grabber-z8o): `WhiteboardPaperGhostsUITests.testASmallLabelKeptStaysOnTheCanvasAndInThePicture` keeps a label of 12-point letters asking for a 1-point pen by a tap and Keep, and finds it on the canvas as wide as its ghost and in Larry's purple in the next picture he gets; with the floor taken out the same test fails (the ghost showed, the kept ink drew nothing, `paper_kept_ink` `ink_px` 0, now `missing` **none**). Not yet seen on the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883); bead `context-grabber-z8o` (relayed by Larry: the 2026-11-14 board, thread igor2-88g.1461)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** keeping a fine line Larry drew on my board
- **I want to** see it stay as ink, as its ghost showed it
- **so that** a mark that asked for a hairline never vanishes when I keep it

#### Acceptance Criteria:
- **Scenario:** A pen too thin to draw
- **Given:** a mark that asks for a pen thinner than the iPad draws
- **When:** it arrives and I keep it
- **Then:** its ghost and its ink are both drawn at the thinnest pen the iPad shows, never vanishing once kept

---

### User Story 1046:

- **Summary:** Larry's marks on a picture with a folded section land where he drew them
- **Status:** implemented in [a043ea5c](https://github.com/idvorkin/context-grabber/commit/a043ea5c) (#1013); verified by host tests (`BoardFoldPictureTests`); `just test` and the Mac build (`just native-build-mac`); the iPad simulator (rung 2, `WhiteboardOutlineUITests.testLarrysPictureShowsAFoldedSectionWholeAndShaded`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** [#1013](https://github.com/idvorkin/context-grabber/issues/1013)

#### Use Case:
- **As someone** whose folded board Larry marks up
- **I want** his marks to land on my folded board by the ink he drew them on in his picture
- **so that** a picture showing my folded lines in full never puts his marks in the wrong place

#### Acceptance Criteria:
- **Scenario:** A mark below a folded section
- **Given:** a header folded over four lines, a line of writing below the section, and Larry's picture showing the section whole
- **When:** Larry circles that line of writing on the picture
- **Then:** his circle shows around the same line on my folded board, not four lines below it; a mark he draws on the folded lines shows just under their header

---

### User Story 1049:

- **Summary:** Larry's labels read as plain written letters, not traced outlines
- **Status:** implemented in [ca0aa8a](https://github.com/idvorkin/context-grabber/commit/ca0aa8a); verified on the host (`just test`: `BoardLetteringTests`, the written glyphs, curly punctuation, an outline kept for a character the letters lack, a label's room and baseline, reword's measure; `WhiteboardTurnTests` and `BoardMarksReplayTests`) and by the Mac build (`just native-build-mac`). UI tests and the iPad not yet: the Mac's screen was locked
- **Issues:** [#895](https://github.com/idvorkin/context-grabber/issues/895)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*, *Letters are written, not traced*

#### Use Case:
- **As someone** reading what Larry wrote on my board
- **I want to** see his labels as plain letters, one pen stroke wide, like print
- **so that** his words read at a glance instead of as hollow, traced shapes that fill in when small

#### Acceptance Criteria:
- **Scenario:** A small label, kept
- **Given:** a board on paper, and a label of Larry's in print with 13-point letters, "It’s Tori — hi…"
- **When:** it shows as a ghost and I tap Keep
- **Then:** its letters are single strokes, open and legible at the thinnest pen, the quote, dash and dots written as plain ' - ..., and the kept ink is the same strokes in his purple

---

### User Story 1056:

- **Summary:** I can letter a board's text in a real font, still as ink
- **Status:** implemented in [d4f7faaa](https://github.com/idvorkin/context-grabber/commit/d4f7faaa), [9d963efd](https://github.com/idvorkin/context-grabber/commit/9d963efd), [133e7124](https://github.com/idvorkin/context-grabber/commit/133e7124) and [c8bcc70f](https://github.com/idvorkin/context-grabber/commit/c8bcc70f); verified on the host (`just test`: `BoardRealFontTests`, the per-board choice, a mark's and Larry's lettering, a kept text's lettering through a save, the strokes sent to the Cockpit unchanged, H as one closed outline, baseline and height, paste layout and wrap, reword) and the Mac build (`just native-build-mac`); on the iPad simulator, rung 2, 2026-11-20 (`WhiteboardLetteringUITests`: HI four strokes on a new board, Real font on with no redraw, reopened still on, HI again as two outlines, a new board single strokes). The iPad not yet
- **Issues:** [#950](https://github.com/idvorkin/context-grabber/issues/950): Igor, 2026-11-18, "Why not have the app render a real font?"; 2026-11-20 (W3 on #912's decision page), "a real font as a per-board or per-text option, still drawn as ink"
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A real font, still drawn as ink*; [the paste spec](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** who wants a board's typed words to look typeset rather than written
- **I want to** choose a real font for that board's lettering
- **so that** pastes and labels read as type while staying ink I can move, erase and fold

#### Acceptance Criteria:
- **Scenario:** A paste on a real-font board
- **Given:** a board on paper I can draw on, with *Real font* turned on in its Board menu
- **When:** I copy "HI" and tap Paste
- **Then:** "HI" lands as Helvetica's letter outlines traced in thin ink, one closed outline a letter where single strokes write it in four, and *Real font* is still on when I reopen the board

---

### User Story 1057:

- **Summary:** A board starts, and stays, in single-stroke letters until I choose otherwise
- **Status:** implemented in [d4f7faaa](https://github.com/idvorkin/context-grabber/commit/d4f7faaa), [9d963efd](https://github.com/idvorkin/context-grabber/commit/9d963efd) and [133e7124](https://github.com/idvorkin/context-grabber/commit/133e7124); verified on the host (`just test`: `BoardRealFontTests`, the per-board choice, a mark's and Larry's lettering, a kept text's lettering through a save, the strokes sent to the Cockpit unchanged, H as one closed outline, baseline and height, paste layout and wrap, reword) and the Mac build (`just native-build-mac`); on the iPad simulator, rung 2, 2026-11-20 (`WhiteboardLetteringUITests`: HI four strokes on a new board, Real font on with no redraw, reopened still on, HI again as two outlines, a new board single strokes). The iPad not yet
- **Issues:** [#950](https://github.com/idvorkin/context-grabber/issues/950): Igor, 2026-11-18, "Why not have the app render a real font?"; 2026-11-20 (W3 on #912's decision page), "a real font as a per-board or per-text option, still drawn as ink"
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A real font, still drawn as ink*

#### Use Case:
- **As someone** who liked #895's single-stroke letters
- **I want to** have every board letter in single strokes unless I pick the real font for it
- **so that** the option changes nothing on the boards I already have

#### Acceptance Criteria:
- **Scenario:** A new board and an old one
- **Given:** a new board, and a board made before the option, neither with a lettering chosen
- **When:** I open its Board menu and paste "HI"
- **Then:** *Real font* is off and the paste is four strokes; turning it on changes nothing already on the board, adds no undo step and costs no stroke

---

### User Story 1058:

- **Summary:** Larry can letter one text in the real font, and it stays one text
- **Status:** implemented in [d4f7faaa](https://github.com/idvorkin/context-grabber/commit/d4f7faaa), [9d963efd](https://github.com/idvorkin/context-grabber/commit/9d963efd) and [c8bcc70f](https://github.com/idvorkin/context-grabber/commit/c8bcc70f); verified on the host (`just test`: `BoardRealFontTests`, the per-board choice, a mark's and Larry's lettering, a kept text's lettering through a save, the strokes sent to the Cockpit unchanged, H as one closed outline, baseline and height, paste layout and wrap, reword) and the Mac build (`just native-build-mac`). A text of Larry's in the real font not yet seen on the simulator or the iPad, and the Cockpit drops a chat mark's lettering until context-grabber-qlr3
- **Issues:** [#950](https://github.com/idvorkin/context-grabber/issues/950): Igor, 2026-11-18, "Why not have the app render a real font?"; 2026-11-20 (W3 on #912's decision page), "a real font as a per-board or per-text option, still drawn as ink"
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A real font, still drawn as ink*; [board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md)

#### Use Case:
- **As someone** working on a board with Larry
- **I want to** have a text of his that asks for the real font drawn in it, whatever the board's lettering
- **so that** he can set a heading or a quote apart, and it still moves, folds, rewords and erases as his text

#### Acceptance Criteria:
- **Scenario:** Larry's text in the real font, reworded
- **Given:** a single-stroke board and a text of Larry's that asks for the real font
- **When:** it lands, I keep it, and I reword it
- **Then:** it is the real font's outlines as ink under his id, and after the reword it is still one text in the real font while the board's next paste is single strokes

---

### User Story 1004:

- **Summary:** A kept reply of Larry's pushes what I wrote since his picture out of the way
- **Status:** implemented in [6cd94985](https://github.com/idvorkin/context-grabber/commit/6cd94985), [64dae5ba](https://github.com/idvorkin/context-grabber/commit/64dae5ba); the simulator test reworked in [ebd344b5](https://github.com/idvorkin/context-grabber/commit/ebd344b5); verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testKeepAllPushesWhatIgorWroteSinceThePictureUnderTheReply`: his marks stay where they showed, both of Igor's lines move 40 points down clear of them, one undo puts them back and takes his marks away); not yet seen on the iPad; made by Keep all, each mark against its own reply's picture: Keep group and Keep all made one *Keep all* (bead context-grabber-yqau) in [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e), verified by host tests (`WhiteboardKeepAllTests`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-22, lane 1's *iPad Pro 11-inch (M5)*: `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardTurnUITests`, `WhiteboardConnectUITests`, `WhiteboardHelpFeedbackUITests`, 32 tests passing); not yet seen on the iPad (`testKeepAllPushesWhatIgorWroteSinceThePictureUnderTheReply`); his text from a change kept by Keep all makes room in the same one room on branch `native/keep-all-yqau`, verified by host tests (`WhiteboardKeepAllTests`, `BoardMarksReplayTests`), not yet on the simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** writing on while Larry answers a picture of my board
- **I want to** have his reply push down what I wrote after he looked, when I keep it
- **so that** his reply never lands on my newer ink, and his marks still sit beside what they name

#### Acceptance Criteria:
- **Scenario:** Keep all over writing newer than his picture
- **Given:** Larry's reply of several marks showing where I have written two lines since his picture went, under my older plan
- **When:** I tap *Keep all* beside the count of marks to keep
- **Then:** his marks become ink where they showed, my two lines and everything under them move down in whole lines until they sit half a line under his lowest mark, my plan above doesn't move, and one Undo puts my lines back and takes his marks away

- **Scenario:** Keep all with his text from a change on my writing
- **Given:** a text of Larry's from a change still showing, on a line I wrote after it showed, beside a reply of his
- **When:** I tap *Keep all*
- **Then:** the text stays where it showed and my line goes down under it in the same one room as the reply's, as Keep would have made room for it; a box of mine the text sits wholly inside stays where it is

---

### User Story 1005:

- **Summary:** One kept mark of Larry's makes room for what I wrote since his picture
- **Status:** implemented on branch `native/board-make-room-894`, merged in #987 ([900852be](https://github.com/idvorkin/context-grabber/commit/900852be)); verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepAllPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** keeping Larry's marks one at a time
- **I want to** have one mark of his, kept, push my newer writing out from under it
- **so that** a single Keep never leaves his mark on top of my ink

#### Acceptance Criteria:
- **Scenario:** Keep one mark over newer writing
- **Given:** one of Larry's marks showing on a line I wrote after his picture went
- **When:** I tap it and *Keep*
- **Then:** the mark becomes ink where it showed, my line and everything under it move down clear of it, and one Undo takes back both

---

### User Story 1006:

- **Summary:** Ink Larry saw never makes room for his reply
- **Status:** implemented on branch `native/board-make-room-894`, merged in #987 ([900852be](https://github.com/idvorkin/context-grabber/commit/900852be)); verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepAllPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** who sometimes wants Larry to draw over what I wrote
- **I want to** keep his marks on ink he saw exactly where he put them, with nothing moved
- **so that** a circle round my word or an arrow onto it stays on it

#### Acceptance Criteria:
- **Scenario:** His reply on ink that was in his picture
- **Given:** a mark of Larry's drawn over writing that was in the picture he answered, or over marks of his or Claude's kept since, and nothing newer of mine under it
- **When:** I keep it, alone or as a group
- **Then:** nothing of mine moves

---

### User Story 1037:

- **Summary:** A reply that lands with the board closed still makes room
- **Status:** implemented on branch `native/board-make-room-894`, merged in #987 ([900852be](https://github.com/idvorkin/context-grabber/commit/900852be)); verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepAllPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** who closes the board while Larry thinks
- **I want to** have his reply, shown when I open the board again, still know what I wrote after his picture
- **so that** closing the board never brings back the overlap

#### Acceptance Criteria:
- **Scenario:** Reopened after his reply
- **Given:** a picture sent to Larry from this device, more writing of mine after it, the board closed, and his reply arrived meanwhile
- **When:** I open the board and keep his reply over that writing
- **Then:** my writing made after the picture moves down clear of it, as if the board had stayed open; a reply to a picture this device didn't send keeps with nothing moved

---

### User Story 895:

- **Summary:** Keep all of Larry's marks at once, where he drew them, each reply as one group
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4) (the web board's `keepAll`, without moving my ink); verified on the host (`WhiteboardTidyTests`; `just native-test`) and on the simulator (`WhiteboardTurnUITests.testKeepingAllOfLarrysMarksMakesThemInkInOneStep`, rung 2); his labels no longer move down off my writing, my newer writing makes room instead, as Keep group did: Keep group and Keep all made one *Keep all* (bead context-grabber-yqau) in [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e), verified by host tests (`WhiteboardKeepAllTests`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-22, lane 1's *iPad Pro 11-inch (M5)*: `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardTurnUITests`, `WhiteboardConnectUITests`, `WhiteboardHelpFeedbackUITests`, 32 tests passing); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** whose board Larry answered with several marks
- **I want to** keep them all in one go, where he drew them, each reply in one piece
- **so that** his answer reads as he wrote it, never sits on writing he didn't see, and I never tap every mark

#### Acceptance Criteria:
- **Scenario:** Larry's labels, one landing on what I wrote after his picture
- **Given:** Larry's marks show on my board and the first of his labels sits on a line I wrote after his picture went
- **When:** I tap Keep all beside the count of marks to keep
- **Then:** every one of his marks becomes ink in his colour where it showed, my line and everything under it move down in whole lines until they sit under his lowest mark, ink that was in his picture doesn't move, and one undo takes all of it back

---

### User Story 1149:

- **Summary:** One Keep all keeps each reply of Larry's as one group, with one make-room and one Undo
- **Status:** decided 2026-11-22 (bead context-grabber-nrg); implemented in [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e) (#1224, merge ef074fc8: Keep group and Keep all made one *Keep all*, bead context-grabber-yqau), the change main's stories 895, 995, 999, 1004 and 1009 also record; verified by host tests (`WhiteboardKeepAllTests`, `BoardMarksReplayTests`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-22: `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardTurnUITests`); not yet seen on the iPad; criteria changed by #1383 (a reply of several marks is chosen and dismissed whole, stories 1285, 1286) in [46b140a9](https://github.com/idvorkin/context-grabber/commit/46b140a9), verified there
- **Spec:** [Ink that reflows like text](../superpowers/specs/2026-11-16-whiteboard-object-layer-design.md), *Decided 2026-11-22*
- **Issues:** Igor's pick on the design board, 2026-11-22: "One rule everywhere: his ink never covers writing he didn't see; my newer writing moves down in whole lines; every cut lands between lines; Keep all behaves like Keep group. A fold is erased only by its words or its marker."

#### Use Case:
- **As someone** whose board Larry answered with marks from one reply or several
- **I want to** keep them all with the one Keep all button, each reply as one group
- **so that** each reply stays where he drew it, in one piece, never sits on writing he didn't see, and one Undo takes the keep back

#### Acceptance Criteria:
- **Scenario:** Keep all over newer writing
- **Given:** marks from two of Larry's replies showing, one of their labels on a line I wrote after his picture went
- **When:** I tap *Keep all* beside the count of marks to keep (there is no separate *Keep group* button; a mark I tap offers only Keep and Dismiss, which read *Keep group* and *Dismiss group* beside a reply of several, story 1285)
- **Then:** every mark becomes ink where it showed, each reply's marks become one group a tap picks up whole (story 1205), my newer line and everything under it move down in whole lines in one make-room (story 1148), and one Undo, named *Keep all*, takes all of it back

---

### User Story 896:

- **Summary:** Tidy overlaps moves kept labels off my writing
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4) (the web board's `tidy`, without moving my ink); verified on the host (`WhiteboardTidyTests.testTidyMovesOnlyTheLabelsThatSitOnInk`, `testTidySeparatesTwoLabelsOnEachOther`, `testTidyTwiceChangesNothing`); `just native-test`. Not yet seen on the simulator or the iPad. A grouped label stays with its group: implemented in [4026690a](https://github.com/idvorkin/context-grabber/commit/4026690a) and [3d37ebb0](https://github.com/idvorkin/context-grabber/commit/3d37ebb0) (a group naming any of a label's glyphs holds the whole label); verified on the host (`WhiteboardTidyGroupTests`, rung 1) and the Mac build (rung 1.5); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*
- **Issues:** bead context-grabber-cg3

#### Use Case:
- **As someone** who kept labels that landed on my own writing
- **I want to** tidy them off it in one step
- **so that** the board stays readable without moving anything by hand

#### Acceptance Criteria:
- **Scenario:** A kept label over my words
- **Given:** a label I kept sits on a line I wrote, and another sits on bare paper
- **When:** I choose Board → Tidy overlaps
- **Then:** the label on my words moves down to the first clear space under them, the other stays, my ink doesn't move, and one undo puts it back

- **Scenario:** A label Larry grouped with his box, over my words
- **Given:** Larry drew a box and its label grouped in one change, and the label sits on a line I wrote
- **When:** I choose Board → Tidy overlaps
- **Then:** neither the box nor its label moves: Tidy never pulls a group apart, and other labels still move clear of it

---

### User Story 897:

- **Summary:** Tidy overlaps on a tidy board says so
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4); verified on the host (`WhiteboardTidyTests.testTidyTwiceChangesNothing`) and on the simulator (`WhiteboardPaperGhostsUITests.testTidyOverlapsOnATidyBoardSaysNothingOverlaps`, rung 2)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** who chose Tidy overlaps on a board with nothing to tidy
- **I want to** be told nothing overlaps
- **so that** I know the tidy ran and the board is already clear

#### Acceptance Criteria:
- **Scenario:** Nothing to tidy
- **Given:** no kept label sits on other ink
- **When:** I choose Board → Tidy overlaps
- **Then:** nothing moves and the bar says *Nothing overlaps*

---

### User Story 917:

- **Summary:** Larry's connector mark shows as the arrow it would be
- **Status:** implemented in [4749f2a](https://github.com/idvorkin/context-grabber/commit/4749f2a) and [1ade3f5](https://github.com/idvorkin/context-grabber/commit/1ade3f5); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build (`just native-build-mac`), and on the simulator (`WhiteboardConnectUITests.testLarrysConnectorMarkKeepsAsAConnector`, rung 2); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's connector marks*

#### Use Case:
- **As Larry,** answering Igor on the board
- **I want to** put a connector among my reply's marks, by names or by points on my picture
- **so that** Igor sees the live arrow I mean, routed as it will be, before he keeps it

#### Acceptance Criteria:
- **Scenario:** A connector mark
- **Given:** a reply of mine with a connector mark between two things on Igor's board
- **When:** it lands on the board
- **Then:** a ghost arrow runs from one thing's facing side to the other's, around anything in its way, beside my other
  marks, including when a ready change from an earlier reply added an endpoint during the same look

---

### User Story 918:

- **Summary:** Keeping Larry's connector mark makes a real connector
- **Status:** implemented in [4749f2a](https://github.com/idvorkin/context-grabber/commit/4749f2a) and [1ade3f5](https://github.com/idvorkin/context-grabber/commit/1ade3f5); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build (`just native-build-mac`), and on the simulator (`WhiteboardConnectUITests.testLarrysConnectorMarkKeepsAsAConnector`, rung 2); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's connector marks*

#### Use Case:
- **As someone** keeping Larry's diagram
- **I want to** keep his arrows as connectors
- **so that** they stay joined when I make room or fold, as on the web board

#### Acceptance Criteria:
- **Scenario:** Keep a connector mark
- **Given:** Larry's connector mark between two things, showing as a ghost with other marks from its reply
- **When:** I tap Keep, or Keep all
- **Then:** it becomes a connector joining them, a push between them redraws it to where they are, and Larry receives its route even when Keep all includes it in the reply's group and the one Undo
- **Issues:** bead context-grabber-yqau

---

### User Story 919:

- **Summary:** A connector mark that can't land is plain or nothing
- **Status:** implemented in [4749f2a](https://github.com/idvorkin/context-grabber/commit/4749f2a) and [1ade3f5](https://github.com/idvorkin/context-grabber/commit/1ade3f5); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build (`just native-build-mac`), and on the simulator (`WhiteboardConnectUITests.testLarrysConnectorMarkKeepsAsAConnector`, rung 2); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's connector marks*

#### Use Case:
- **As someone** keeping Larry's marks
- **I want to** see nothing broken when his connector can't join
- **so that** his marks stay readable

#### Acceptance Criteria:
- **Scenario:** A mark with an end nowhere
- **Given:** Larry's connector mark with an end on bare paper, or one naming something the board doesn't have
- **When:** it lands
- **Then:** the one on bare paper shows and keeps as a plain arrow where he drew it; the one naming nothing shows nothing and is set aside as if dismissed

---

### User Story 1349:

- **Summary:** A box Larry drew keeps as one thing Igor can move
- **Status:** in progress on branch `native/diagram-boxes-1528` (#1528)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's diagrams keep as boxes Igor can move*

#### Use Case:
- **As Igor,** keeping a diagram Larry drew on the board
- **I want to** move each of its boxes, with its words, as one thing
- **so that** I can rearrange the diagram and talk about one box at a time

#### Acceptance Criteria:
- **Scenario:** A rectangle with words inside it
- **Given:** a reply of Larry's with a rectangle and a label inside it, beside other marks of the reply
- **When:** I keep the reply and drag the rectangle
- **Then:** the rectangle and its label move together, and the reply's other marks stay where they were

---

### User Story 1350:

- **Summary:** Larry's arrow between two boxes keeps as a connector
- **Status:** in progress on branch `native/diagram-boxes-1528` (#1528)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's diagrams keep as boxes Igor can move*

#### Use Case:
- **As Igor,** keeping a boxes-and-arrows diagram of Larry's
- **I want to** have his arrows join the boxes they point between
- **so that** the diagram stays a diagram, not loose ink

#### Acceptance Criteria:
- **Scenario:** An arrow from one box to another
- **Given:** a reply of Larry's with two boxes and a plain arrow whose tail and head each touch one of them
- **When:** I keep the reply
- **Then:** the arrow is a connector joining the two boxes, drawn from one box's facing side to the other's, and an arrow with an end on bare paper keeps as the plain arrow he drew

---

### User Story 1351:

- **Summary:** Arrows follow a box Igor moves
- **Status:** in progress on branch `native/diagram-boxes-1528` (#1528)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's diagrams keep as boxes Igor can move*

#### Use Case:
- **As Igor,** rearranging a kept diagram of Larry's
- **I want to** see its arrows stay on the boxes when I move one
- **so that** I never have to redraw an arrow after a move

#### Acceptance Criteria:
- **Scenario:** Dragging one box of a kept diagram
- **Given:** a kept diagram with an arrow joining two of its boxes
- **When:** I drag one of the boxes somewhere else
- **Then:** the arrow re-routes from where that box went to the other box, and the other box stays put

---

### User Story 990:

- **Summary:** Larry replays a change on a copy of Igor's board and sees the result before sending it
- **Status:** implemented on branch `native/board-ops-harness`; verified by host tests (`BoardReplayTests`), `just test` and `just board-ops` on the night's three fixtures
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry checks a change before he sends it*
- **Issues:** [#936](https://github.com/idvorkin/context-grabber/issues/936)

#### Use Case:
- **As Larry,** about to change Igor's board
- **I want to** run my change on a copy of his board with the board's own rules and see the board after
- **so that** I never test on his real board, and a mess shows up on my screen instead of his

#### Acceptance Criteria:
- **Scenario:** A change checked on a copy
- **Given:** a copy of a board as it sends me its strokes, and a batch of my changes
- **When:** I run `just board-ops` with the two, on the Mac
- **Then:** within seconds I get the `op_result` the iPad would answer, the names my change moved, erased, drew and left as ghosts, a picture of the board before and after with those marked, and the board after
- **And:** tonight's three failures replay as they happened on the iPad: the Judge label missing (#937), the list landing on ink (#938) and the delete of ghosts missing (#939)

---

### User Story 991:

- **Summary:** A label Larry groups with his box lands with it, as ink
- **Status:** implemented in [4d95846c](https://github.com/idvorkin/context-grabber/commit/4d95846c); verified by host tests (`BoardOpsInkTests`, `BoardReplayTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's Judge batch; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry groups ink*
- **Issues:** [#937](https://github.com/idvorkin/context-grabber/issues/937)

#### Use Case:
- **As Larry,** drawing a labelled block on Igor's board
- **I want to** send a box and its label grouped in one change
- **so that** both land together and move as one, with nothing left for Igor to keep

#### Acceptance Criteria:
- **Scenario:** A grouped box and label
- **Given:** a change of mine that draws a box, adds a text, and groups the two
- **When:** it applies on the board
- **Then:** the box and the label are both ink on the board at once, in my colour, with no ghost to keep
- **And:** my next turn has the label as a kept text under my name, no missing ids, and moving the group moves both
- **And:** one Undo takes both away

---

### User Story 992:

- **Summary:** Larry's text makes room instead of landing on my writing
- **Status:** implemented in [090e7c9f](https://github.com/idvorkin/context-grabber/commit/090e7c9f); verified by host tests (`BoardRoomTests`, `BoardReplayTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's list batch; keeping a ghost with ink under it is not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry writes plain text*
- **Issues:** [#938](https://github.com/idvorkin/context-grabber/issues/938)

#### Use Case:
- **As someone** writing on the board while Larry answers
- **I want to** have his text push my ink down the way a paste does
- **so that** his words and mine never sit on top of each other

#### Acceptance Criteria:
- **Scenario:** His list lands where I wrote
- **Given:** two lines of my writing under my diagram, and a change of Larry's that adds his list of lines there
- **When:** it applies
- **Then:** my two lines and everything under them move down in whole lines until they sit under his last line, my diagram above doesn't move, and none of his lines touch my ink
- **And:** one Undo puts my ink back up

- **Scenario:** His text on clear paper
- **Given:** a text of his that lands on blank paper
- **When:** it applies
- **Then:** nothing moves

- **Scenario:** I keep his ghost after writing under it
- **Given:** a ghost of his text, and my writing that has since reached under it
- **When:** I tap Keep on it
- **Then:** my writing below moves down clear of it, and one Undo takes back both

---

### User Story 993:

- **Summary:** Larry's change reaches his text ghost by the name he gave it
- **Status:** implemented on branch `native/board-ops-939-ghost-ids`; verified by host tests (`BoardReplayTests`, `WhiteboardGhostTurnsTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's delete batch; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry writes plain text*
- **Issues:** [#939](https://github.com/idvorkin/context-grabber/issues/939)

#### Use Case:
- **As Larry,** taking back text I put on Igor's board
- **I want to** delete or move my text by its name whether Igor has kept it yet or not
- **so that** what I take back is gone, and never comes back when he taps Keep later

#### Acceptance Criteria:
- **Scenario:** Delete a text still showing as a ghost
- **Given:** five lines of mine still showing as ghosts
- **When:** my change deletes them by name
- **Then:** the five ghosts go, my change reports no missing ids, and there is nothing left for Igor to keep

- **Scenario:** Move a ghost by name
- **Given:** a text of mine still showing as a ghost
- **When:** my change moves it by its name
- **Then:** the ghost moves, and once kept it is a kept text under the same name

---

### User Story 994:

- **Summary:** A label inside one of Larry's boxes can be tapped on its words
- **Status:** implemented in [75eef936](https://github.com/idvorkin/context-grabber/commit/75eef936) (the reproduction: `just board-ops` replays his marks and tries a tap on each), [491cab14](https://github.com/idvorkin/context-grabber/commit/491cab14), [13e47d0a](https://github.com/idvorkin/context-grabber/commit/13e47d0a) and [80f9873a](https://github.com/idvorkin/context-grabber/commit/80f9873a) (the nearest mark takes the tap); verified by host tests (`BoardMarksReplayTests`, failing on the old rule first), `just test`, the Mac build (`just native-build-mac`), `just board-ops` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests`, rung 2, 2026-11-17); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*; [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry checks a change before he sends it*
- **Issues:** [#941](https://github.com/idvorkin/context-grabber/issues/941): Larry's four named boxes of 18:26, 2026-11-17 (board 13f700bf, build 10b84a5f): all eleven marks showed (`paper_ghosts` count 11, past_side false); Igor's three taps each chose a box or a line and he kept those three; a tap on the upper half of a name went to its box (38–57% of each name's box, by `just board-ops`); and Larry's next reply replaced the eight left, the four names among them

#### Use Case:
- **As someone** keeping Larry's labelled boxes one at a time
- **I want to** tap a name inside a box and get the name, and tap the box's side and get the box
- **so that** no mark of his is out of my reach because another was drawn first

#### Acceptance Criteria:
- **Scenario:** A name inside its box
- **Given:** Larry's box with a name inside it, the box first in his reply
- **When:** I tap on the name's letters, or between them
- **Then:** Keep and Dismiss show beside the name, not the box

---

### User Story 996:

- **Summary:** A tap on the side of Larry's labelled box chooses the box
- **Status:** implemented in [75eef936](https://github.com/idvorkin/context-grabber/commit/75eef936) (the reproduction: `just board-ops` replays his marks and tries a tap on each), [491cab14](https://github.com/idvorkin/context-grabber/commit/491cab14), [13e47d0a](https://github.com/idvorkin/context-grabber/commit/13e47d0a) and [80f9873a](https://github.com/idvorkin/context-grabber/commit/80f9873a) (the nearest mark takes the tap); verified by host tests (`BoardMarksReplayTests`, failing on the old rule first), `just test`, the Mac build (`just native-build-mac`), `just board-ops` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests`, rung 2, 2026-11-17); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#941](https://github.com/idvorkin/context-grabber/issues/941)

#### Use Case:
- **As someone** keeping Larry's labelled boxes one at a time
- **I want to** tap a box's side and get the box, not the name inside it
- **so that** the box stays in reach once its name is nearest the middle

#### Acceptance Criteria:
- **Scenario:** The box's side
- **Given:** Larry's box with a name inside it
- **When:** I tap on the box's side
- **Then:** Keep and Dismiss show beside the box

---

### User Story 997:

- **Summary:** Larry sees which of his marks a tap can't reach before he sends them
- **Status:** implemented in [75eef936](https://github.com/idvorkin/context-grabber/commit/75eef936); verified by host tests (`BoardMarksReplayTests`), `just test` and `just board-ops` on the 18:26 reply, on the Mac; off the Mac (Linux, #943, rung 1L not run) there are no fonts, so his labels are dropped and the step says so
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry checks a change before he sends it*
- **Issues:** [#941](https://github.com/idvorkin/context-grabber/issues/941)

#### Use Case:
- **As Larry,** drawing marks for Igor to keep
- **I want to** replay my reply on a copy of his board and see where every mark lands and what a tap on each chooses
- **so that** I never send him a mark he can't reach

#### Acceptance Criteria:
- **Scenario:** Larry checks his marks first
- **Given:** a reply of his with marks and a copy of the board
- **When:** he runs `just board-ops` with them
- **Then:** the picture shows his marks where the iPad would, and every mark a tap can't reach is named, with the mark that takes the tap instead

---

### User Story 995:

- **Summary:** One tap keeps all of Larry's replies, each as its own group
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepAllTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepAllKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad; the popover's Keep group became the note line's Keep all: Keep group and Keep all made one *Keep all* (bead context-grabber-yqau) in [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e), verified by host tests (`WhiteboardKeepAllTests`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-22, lane 1's *iPad Pro 11-inch (M5)*: `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardTurnUITests`, `WhiteboardConnectUITests`, `WhiteboardHelpFeedbackUITests`, 32 tests passing); not yet seen on the iPad (`testKeepAllKeepsHisWholeReplyAndOneUndoTakesItBack`)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942): Igor, 2026-11-17 19:15, via Larry: "accept the group", after keeping his four named boxes one mark at a time; [#966](https://github.com/idvorkin/context-grabber/issues/966): Igor, 2026-11-19, board 302d5345, via Larry: he kept Larry's whole reply group, it sat on top of his own plan, and undo couldn't take it back (story 1007)

#### Use Case:
- **As someone** whose board holds marks from several of Larry's replies
- **I want to** keep every reply with one tap, each in its own group
- **so that** each drawing moves as one and one Undo takes them all back

#### Acceptance Criteria:
- **Scenario:** Two replies showing
- **Given:** marks from two replies of Larry's show, each of several marks
- **When:** I tap *Keep all* beside the count of marks to keep (there is no separate *Keep group*)
- **Then:** all of the marks become ink where they showed, each reply forms one named group a finger tap picks up whole, any room they need is opened once, and one Undo takes them all back

---

### User Story 998:

- **Summary:** A reply of Larry's kept as a group moves as one
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepAllTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepAllKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad; a drag on part of the group brings the rest along in story 1193
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942); bead context-grabber-1xdh (story 1193)

#### Use Case:
- **As someone** who kept Larry's drawing as a group
- **I want** it to move as one thing, whoever moves it
- **so that** his drawing never comes apart on my board

#### Acceptance Criteria:
- **Scenario:** It moves as one
- **Given:** a reply I kept as a group
- **When:** Larry moves it by the group's name, or a push opens room through it
- **Then:** all of it moves together (under a push all of it moves or all of it stays, by its top, story 842), and Larry hears its strokes under that one group

---

### User Story 1193:

- **Summary:** A drag that picks up part of a kept group brings the rest along
- **Status:** implemented in [7fe61413](https://github.com/idvorkin/context-grabber/commit/7fe61413) (bead context-grabber-1xdh); verified by host tests (`PaperProbeGroupCarryTests`: the iPad's 102-of-120 case), `just native-test`, the Mac build (`just native-build-mac`) and the iPad simulator (`WhiteboardDropRoomUITests`, `WhiteboardGroupTapUITests`: the selected drag and the drop's room unchanged); the unselected drag on the handwriting view exists only on the iPad, not yet seen there
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*; story 998
- **Issues:** bead context-grabber-1xdh (the iPad, 2026-11-22, log grabber-20261122-151404: a finger drag on the handwriting view moved 102 of a kept reply's 120 strokes and left the rest); [#1266](https://github.com/idvorkin/context-grabber/issues/1266) (same session: a tap selected the whole group, the system's convert popover emptied the selection before he could press and drag it, so the drag fell to the handwriting view; the popover is put away and the selection put back by #1210, story 945)

#### Use Case:
- **As someone** who kept Larry's drawing as a group
- **I want** a drag on any part of it to bring the whole group
- **so that** his drawing never comes apart when I move it by hand

#### Acceptance Criteria:
- **Scenario:** A drag on part of it brings the rest
- **Given:** a reply of Larry's I kept as a group, with nothing selected
- **When:** I drag one paragraph of it with a finger and the system's handwriting view picks up only that paragraph
- **Then:** the rest of the group comes along by the same amount, so the whole group lands where I let go, and one Undo
  puts all of it back

---

### User Story 1194:

- **Summary:** A lasso of part of a kept group moves only that part
- **Status:** kept in [7fe61413](https://github.com/idvorkin/context-grabber/commit/7fe61413) (bead context-grabber-1xdh), which carries the rest of a group only for a drag with nothing selected; verified by host tests (`PaperProbeGroupCarryTests`: the iPad's 102-of-120 case), `just native-test`, the Mac build (`just native-build-mac`) and the iPad simulator (`WhiteboardDropRoomUITests`, `WhiteboardGroupTapUITests`: the selected drag and the drop's room unchanged)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*; story 998
- **Issues:** bead context-grabber-1xdh

#### Use Case:
- **As someone** who kept Larry's drawing as a group
- **I want** a lasso to move only what I lassoed
- **so that** I can still pull a piece out of his drawing on purpose

#### Acceptance Criteria:
- **Scenario:** A lasso of part of it moves only that part
- **Given:** a reply kept as a group
- **When:** I lasso part of it and drag that
- **Then:** only what I lassoed moves

---

### User Story 999:

- **Summary:** A reply with one mark left showing is kept alone, not as a group
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepAllTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepAllKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad; no Keep group beside a mark, and a reply with one mark left kept alone by Keep all: Keep group and Keep all made one *Keep all* (bead context-grabber-yqau) in [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e), verified by host tests (`WhiteboardKeepAllTests`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-22, lane 1's *iPad Pro 11-inch (M5)*: `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardTurnUITests`, `WhiteboardConnectUITests`, `WhiteboardHelpFeedbackUITests`, 32 tests passing); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** keeping Larry's marks
- **I want** a group only when there is a group to keep
- **so that** a lone mark of his is one thing on its own, as Keep makes it

#### Acceptance Criteria:
- **Scenario:** One mark left
- **Given:** only one mark of his reply still shows
- **When:** I tap it, or tap *Keep all*
- **Then:** beside it only Keep and Dismiss show, and Keep all keeps it as one thing on its own, in no group

---

### User Story 945:

- **Summary:** The board never offers to convert handwriting to text
- **Status:** implemented in [64c8fcf1](https://github.com/idvorkin/context-grabber/commit/64c8fcf1) and [6570ae84](https://github.com/idvorkin/context-grabber/commit/6570ae84); verified by host tests (`PaperProbeHandwritingOfferTests`: the iPad's remote `_UICampo…` popover at the paper is the offer, the board's own sheets and popovers elsewhere are not; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardGroupTapUITests.testTheHandwritingOfferIsPutAwayAndTheTappedGroupStillDrags`, rung 2, 2026-11-22: a stand-in for the offer, `GRABBER_WHITEBOARD_FAKE_OFFER`, is put away about 40 ms after it shows, `handwriting_offer` in the log); the real system popover being put away, and *To text* beside it, not yet seen on the iPad (rung 3 owed)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *The board never offers to convert handwriting to text*
- **Issues:** bead context-grabber-4nnh: iPad, build 62508388, session log grabber-20261122-120300 (12:09 to 12:11): a finger tap on a kept group of Larry's selected all 93 strokes, the system's handwriting popover (`_UICampoPresentedViewController`, a remote popover from the paper, `HandwritingReflowView` holding the focus) came up over it about a second later, the selection went to 0 with no selection callback, and every finger drag after it moved nothing; Igor, 2026-11-22 14:49: "Also never prompt me to convert"

#### Use Case:
- **As someone** selecting and moving handwriting on a board on the iPad
- **I want** the system never to pop up its offer to convert my selection to text
- **so that** the board stays mine to draw on and move things, and *To text* is there when I want it

#### Acceptance Criteria:
- **Scenario:** The offer is put away
- **Given:** a board on paper on the iPad
- **When:** the system shows its handwriting popover over the paper, on a selection, a tap or anything else
- **Then:** the board puts it away at once, the session log says what it was, what was selected and what was selected after (the board's own *To text* is story 920, unchanged)

---

### User Story 946:

- **Summary:** A tapped group stays selected and draggable when the system takes its selection away
- **Status:** implemented in [64c8fcf1](https://github.com/idvorkin/context-grabber/commit/64c8fcf1) and [6570ae84](https://github.com/idvorkin/context-grabber/commit/6570ae84); verified by host tests (`PaperProbeHandwritingOfferTests`: put back three times then left, a selection of Igor's or one with a touch since never put back; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator (`WhiteboardGroupTapUITests`, rung 2, 2026-11-22: the stand-in offer empties the selection with no callback, the board puts all three strokes back and a finger drag moves them as one; with the put-back switched off the same test fails, the drag moving nothing); the iPad's own offer not yet seen (rung 3 owed: `group_tap_lost`, `group_tap_lost_after` and `handwriting_offer` will say)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *The board never offers to convert handwriting to text* (a tapped group stays selected)
- **Issues:** bead context-grabber-4nnh (as story 945): `group_tap_held` read held false, selected 0, touched_since false, with no `paper_selection` between, three times; the finger drags at t=404311, 408263 and 428048 ended `ink_moved` 0

#### Use Case:
- **As someone** who tapped a kept group of Larry's to move it
- **I want** it to stay selected until I touch the board again
- **so that** the finger drag that follows moves all of it

#### Acceptance Criteria:
- **Scenario:** Put back after the system empties it
- **Given:** a kept group selected by a finger tap
- **When:** within three seconds, with no touch of mine since, the selection goes with no word from the board (the system's popover came over it)
- **Then:** the whole group is selected again, and a finger drag moves it as one

---

### User Story 948:

- **Summary:** A tapped group is never put back over a choice of my own
- **Status:** implemented in [64c8fcf1](https://github.com/idvorkin/context-grabber/commit/64c8fcf1); verified by host tests (`PaperProbeHandwritingOfferTests`: a selection of Igor's or one with a touch since is never put back; `just native-test`); not yet seen on the iPad (rung 3 owed)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *The board never offers to convert handwriting to text* (a tapped group stays selected)
- **Issues:** bead context-grabber-4nnh (as story 946)

#### Use Case:
- **As someone** who tapped a kept group of Larry's and then changed my mind
- **I want** what I touch or select next to stand
- **so that** the board never takes my choice back to the group

#### Acceptance Criteria:
- **Scenario:** My own choice stands
- **Given:** a kept group selected by a finger tap
- **When:** I touch the board, lasso something else or tap elsewhere
- **Then:** what I chose is never put back to the group

---

### User Story 949:

- **Summary:** A tapped group's put-back gives up after three tries
- **Status:** implemented in [64c8fcf1](https://github.com/idvorkin/context-grabber/commit/64c8fcf1); verified by host tests (`PaperProbeHandwritingOfferTests`: put back three times, then left; `just native-test`); not yet seen on the iPad (rung 3 owed: `group_tap_lost` with verdict `given_up` will say)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *The board never offers to convert handwriting to text* (a tapped group stays selected)
- **Issues:** bead context-grabber-4nnh (as story 946)

#### Use Case:
- **As someone** whose tapped group keeps losing its selection
- **I want** the board to stop putting it back after a few tries
- **so that** it never fights the system for the board, and the log says it gave up

#### Acceptance Criteria:
- **Scenario:** Not forever
- **Given:** a tapped group whose selection keeps going
- **When:** the board has put it back three times
- **Then:** it leaves it, and the session log says it gave up

---

### User Story 947:

- **Summary:** A finger tap on any stroke of a group selects the whole group, ready to drag
- **Status:** implemented in [3175c799](https://github.com/idvorkin/context-grabber/commit/3175c799); verified by host tests (`BoardOutlineTests`: `testAFingerTapOnAGroupsStrokeTakesTheWholeGroup`, `testATextInsideAGroupIsTheGroupsAndABareTextIsNot`; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardGroupTapUITests`, rung 2, 2026-11-22: the tap selects all three kept marks and they stay selected past the tap's dot, a finger drag moves them whole, one Undo puts them back, a tap beside them selects nothing); a second tap opening a grouped text's words, and the tap with the Pencil paired (fingers not drawing), not yet seen on the iPad. A busy moment after the tap (bead context-grabber-z93g): [05cf2db3](https://github.com/idvorkin/context-grabber/commit/05cf2db3); verified by a host test (`PaperProbeTests`: a dot 1.17 s late is a group tap's) and on four iPad simulator lanes at once (rung 2, 2026-11-22, 32 runs at a time, no retries: the tap's selection held in every run, 64 of 64, against 4 of 32 lost before; every drag that started inside the group moved it whole; the 4 failures left in each 32 are the kept ink drawn cut, bead context-grabber-dell). His controls showing (bead context-grabber-9d1): [7f7b832d](https://github.com/idvorkin/context-grabber/commit/7f7b832d); verified on the iPad simulator against the fake Cockpit (rung 2, 2026-11-22: `WhiteboardPaperGhostsUITests.testWithHisButtonShowingHisTextSelectsFirstAndRewordsSecond`, with his button showing the first tap on his kept text selects it, *Text · tap to reword*, and opens no words, the second opens them; it fails without the fix; the 846 button tap, 1140 and 940 tests pass beside it), the Mac build (`just native-build-mac`) and `just native-test`; the tap on a control over a kept text, and a group's text with controls showing, not yet seen on the simulator or the iPad. A connected word of Igor's is one thing (bead context-grabber-3iz): pinned in [dc976c5a](https://github.com/idvorkin/context-grabber/commit/dc976c5a), no app change (main already took it whole); verified by a host test (`BoardConnectorsTests.testAFingerTapOnAConnectedWordOfIgorsTakesTheWholeWord`) and `just native-test`; not run on the simulator (no app code changed), not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on a group)
- **Issues:** [#947](https://github.com/idvorkin/context-grabber/issues/947): Igor, 2026-11-18 about 05:42, via Larry: "when I click select-all, I want some notion of fixed object on finger-click to move"; bead context-grabber-z93g: `WhiteboardGroupTapUITests` passed only on its retry; under load the tap's dot landed 0.86 to 1.17 s after the tap, past the 0.6 s window, stayed as a stroke and took the group's selection with it; bead context-grabber-9d1 (read from the code 2026-11-22, not reproduced on a device): with one of Larry's controls showing, the first tap on a kept text of his or in a group opened its words; bead context-grabber-3iz (read from the code 2026-11-22, not reproduced on a device): a finger tap took Igor's own connected word whole, as a group. Igor decided that is right (2026-11-22, decision card igor2-88g.1620.5: "a connected word is one thing; a tap takes it whole")

#### Use Case:
- **As someone** with a reply of Larry's kept as a group on the board
- **I want to** tap any stroke of it with a finger and have all of it selected
- **so that** I can drag his drawing as one thing without drawing a lasso round it, while the Pencil keeps drawing

#### Acceptance Criteria:
- **Scenario:** A tap picks up the group
- **Given:** a reply of Larry's I kept as a group, no marks showing, on a board I can draw on
- **When:** I tap one of its strokes with a finger
- **Then:** every stroke of the group is selected, no dot is left where I tapped, and the Pencil still draws

- **Scenario:** Dragged and put back
- **Given:** the group selected by a tap
- **When:** I drag it with a finger, then press Undo once
- **Then:** all of it moves together, and the one Undo puts it back where it was

- **Scenario:** Off the group
- **Given:** a group on the board
- **When:** I tap blank paper beside it, my own writing, or the margin
- **Then:** nothing of the group is selected, and the tap does what it did before

- **Scenario:** A word of mine an arrow joins
- **Given:** a word I wrote, joined by a connector, and another word of mine no arrow joins
- **When:** I tap one stroke of the joined word with a finger, then one stroke of the other
- **Then:** the first tap selects the whole joined word as one thing, ready to drag; the second does what it did before

- **Scenario:** A text inside a group
- **Given:** a group holding a kept text
- **When:** I tap the text once, and again with the group selected
- **Then:** the first tap selects the group; the second opens the text's words for rewording (story 940)

- **Scenario:** One of Larry's controls showing
- **Given:** a group holding a kept text, and a button, chip, band or hint of Larry's on the board
- **When:** I tap the text once, again with the group selected, and then tap his control
- **Then:** the first tap selects the group, the second opens the text's words, and the tap on his control reaches him and neither selects nor opens anything

---

### User Story 1140:

- **Summary:** A finger tap on anything of Larry's I kept picks up that one thing alone, ready to drag
- **Status:** implemented in [38843ea5](https://github.com/idvorkin/context-grabber/commit/38843ea5), [e1409a33](https://github.com/idvorkin/context-grabber/commit/e1409a33); verified by host tests (`BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`: one of two kept marks, his ink nearer and a group's left to the group; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardTheirsTapUITests`, rung 2, 2026-11-22: three circles kept with Keep all, a finger tap selects the first alone, its Delete leaves the other two, one Undo brings it back); the drag not yet seen on the iPad; the three circles now kept one at a time with Keep, since Keep all keeps them as one group: Keep group and Keep all made one *Keep all* (bead context-grabber-yqau) in [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e), verified by host tests (`WhiteboardKeepAllTests`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-22, lane 1's *iPad Pro 11-inch (M5)*: `WhiteboardPaperGhostsUITests`, `WhiteboardGroupTapUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardTurnUITests`, `WhiteboardConnectUITests`, `WhiteboardHelpFeedbackUITests`, 32 tests passing); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on anything of Larry's he kept)
- **Issues:** [#1171](https://github.com/idvorkin/context-grabber/issues/1171): Igor, 2026-11-22 17:21, on the iPad, Larry's steps written inside a box of his: "I want to be able to click what Larry wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"

#### Use Case:
- **As someone** with Larry's writing kept on the board, on or beside my own
- **I want to** tap it with a finger and have just that one thing of his selected
- **so that** I can move it on its own, without a lasso that drags my ink along or splits his text

#### Acceptance Criteria:
- **Scenario:** One of his, alone
- **Given:** three marks of Larry's, each from a reply of its own, kept one at a time with Keep, on a board I can draw on, no marks showing
- **When:** I tap one of them with a finger and drag it
- **Then:** that mark alone is selected and moves; his other two and my ink stay where they were, and one Undo puts it back

---

### User Story 1141:

- **Summary:** A finger tap on a text of Larry's over my box takes his whole text and none of my box
- **Status:** implemented in [38843ea5](https://github.com/idvorkin/context-grabber/commit/38843ea5), [e1409a33](https://github.com/idvorkin/context-grabber/commit/e1409a33); verified by host tests (`BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`: his text alone over his box; `just native-test`) and the Mac build (`just native-build-mac`); the selection, its drag and the second tap's reword not yet seen on the iPad simulator or the iPad. His controls showing (bead context-grabber-9d1): [7f7b832d](https://github.com/idvorkin/context-grabber/commit/7f7b832d); verified on the iPad simulator against the fake Cockpit (rung 2, 2026-11-22: `WhiteboardPaperGhostsUITests.testWithHisButtonShowingHisTextSelectsFirstAndRewordsSecond`, with his button showing the first tap on his kept text selects it, *Text · tap to reword*, and opens no words, the second opens them; it fails without the fix; the 846 button tap, 1140 and 940 tests pass beside it), the Mac build (`just native-build-mac`) and `just native-test`; the tap on a control over a kept text, and a group's text with controls showing, not yet seen on the simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on anything of Larry's he kept)
- **Issues:** [#1171](https://github.com/idvorkin/context-grabber/issues/1171): Igor, 2026-11-22 17:21, on the iPad, Larry's steps written inside a box of his: "I want to be able to click what Larry wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"; bead context-grabber-9d1 (read from the code 2026-11-22, not reproduced on a device): with one of Larry's controls showing, the first tap on a kept text of his or in a group opened its words

#### Use Case:
- **As someone** with a text of Larry's kept inside a box I drew
- **I want to** tap one of its letters and have all of his text selected, and only it
- **so that** I can move his words out of my box, or reword them with a second tap

#### Acceptance Criteria:
- **Scenario:** His text on my box
- **Given:** a text of Larry's kept over a box I drew
- **When:** I tap one of its letters with a finger
- **Then:** every letter of the text is selected and none of my box, and the label reads *Text · tap to reword*; a second tap on it opens its words

- **Scenario:** His text with one of his controls showing
- **Given:** a text of Larry's kept on the board, and a button of his showing
- **When:** I tap one of its letters, and then tap it again
- **Then:** the first tap selects every letter of it (*Text · tap to reword*) and opens no words; the second opens its words

---

### User Story 1142:

- **Summary:** Where my own ink is nearer, a finger tap stays mine
- **Status:** implemented in [38843ea5](https://github.com/idvorkin/context-grabber/commit/38843ea5), [e1409a33](https://github.com/idvorkin/context-grabber/commit/e1409a33); verified by host tests (`BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`: his ink nearer; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator (`WhiteboardRewordUITests`, rung 2, 2026-11-22: a To text result still opens at the first tap); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on anything of Larry's he kept)
- **Issues:** [#1171](https://github.com/idvorkin/context-grabber/issues/1171): Igor, 2026-11-22 17:21, on the iPad, Larry's steps written inside a box of his: "I want to be able to click what Larry wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"

#### Use Case:
- **As someone** with my own writing beside Larry's
- **I want** a tap nearer my ink than his to do what it always did
- **so that** picking up his things never takes over my own

#### Acceptance Criteria:
- **Scenario:** My ink is nearer
- **Given:** a stroke of mine nearer the tap than any of Larry's
- **When:** I tap there
- **Then:** the tap does what it did before, and a text I typed or made with To text still opens at the first tap

---

### User Story 1144:

- **Summary:** A delayed tap dot leaves the group selected
- **Status:** implemented in [05cf2db3](https://github.com/idvorkin/context-grabber/commit/05cf2db3). The original change held selection in 64 of 64 iPad simulator runs under load (rung 2, 2026-11-22). `PaperProbeTests` covers a dot delivered 1.17 s after the tap.
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** bead context-grabber-z93g

#### Use Case:
- **As someone** moving a group on a busy iPad
- **I want** the whole group to stay selected when the tap is slow to register
- **so that** I can drag it as one and keep the ink I draw afterwards

#### Acceptance Criteria:
- **Scenario:** A busy moment after the tap
- **Given:** a kept group and an iPad slow to draw the tap's dot
- **When:** I tap a stroke of the group
- **Then:** for up to three seconds or until my next touch, that tap's dot is removed and the whole group stays selected. A second tap has its own window, and new or restored ink stays on the board.

---

### User Story 1145:

- **Summary:** PaperKit's handwriting reflow never moves my ink and Larry's together
- **Status:** implemented in [bbd89c38](https://github.com/idvorkin/context-grabber/commit/bbd89c38); verified by host tests (`PaperProbeOwnersApartTests`: the iPad's 52 + 2 case, Igor's line with Larry's strokes caught, a tie, one owner, a selection, nothing known as Larry's; `just native-test`), the Mac build (`just native-build-mac`) and the iPad simulator (rung 2, `just test-ladder`: every whiteboard UI test and the PaperKit contract tests pass, and a group's drag logs `apart: selected`, moved whole); the reflow itself can't be reached on the simulator, so the split, its take-back and its Undo are still owed on the iPad (rung 3: read `paper_ink`'s `apart` and the `paper_apart` line)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (PaperKit's handwriting reflow never carries Igor's ink and Larry's together)
- **Issues:** bead context-grabber-eg7v (the iPad, 2026-11-22, log grabber-20261122-091406: a finger tap on Larry's kept text opened PaperKit's handwriting reflow over it and two of my strokes, and a drag on it moved all 54 strokes together); Igor, 2026-11-22 12:56: keep the reflow, but never group my ink with Larry's or Claude's

#### Use Case:
- **As someone** writing beside a text of Larry's I kept
- **I want** the system's handwriting reflow to move his ink or mine, never both at once
- **so that** reflowing his words never drags my writing along, and mine never drags his

#### Acceptance Criteria:
- **Scenario:** The reflow takes his text and two of my strokes
- **Given:** a kept text of Larry's and two strokes of mine beside it, nothing selected
- **When:** the handwriting reflow moves all of them with one drag
- **Then:** his text stays where the drag took it, my two strokes go back where they were, and one Undo puts his text back too

---

### User Story 1146:

- **Summary:** PaperKit's handwriting reflow on my line leaves Larry's strokes caught in it where they were
- **Status:** implemented in [bbd89c38](https://github.com/idvorkin/context-grabber/commit/bbd89c38); verified by host tests (`PaperProbeOwnersApartTests`: Igor's line with Larry's strokes caught, a tie; `just native-test`) and the Mac build (`just native-build-mac`); the reflow can't be reached on the simulator, so the split is still owed on the iPad (rung 3: read `paper_ink`'s `apart` and the `paper_apart` line)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (PaperKit's handwriting reflow never carries Igor's ink and Larry's together)
- **Issues:** bead context-grabber-eg7v

#### Use Case:
- **As someone** writing a line of my own over a few of Larry's strokes
- **I want** the system's handwriting reflow to move my line without his strokes
- **so that** reflowing my words never drags his marks along

#### Acceptance Criteria:
- **Scenario:** My line with a few of his strokes caught
- **Given:** a line of my handwriting with a few of Larry's strokes in it
- **When:** the reflow moves them all
- **Then:** my line stays moved and his strokes go back where they were

---

### User Story 1147:

- **Summary:** What I select and drag moves whole, my ink and Larry's together
- **Status:** implemented in [bbd89c38](https://github.com/idvorkin/context-grabber/commit/bbd89c38); verified by host tests (`PaperProbeOwnersApartTests`: a selection; `just native-test`), the Mac build (`just native-build-mac`) and the iPad simulator (rung 2, `just test-ladder`: a group's drag logs `apart: selected`, moved whole)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (PaperKit's handwriting reflow never carries Igor's ink and Larry's together)
- **Issues:** bead context-grabber-eg7v

#### Use Case:
- **As someone** who lassoed my ink and Larry's on purpose
- **I want** the drag to move everything I selected
- **so that** keeping owners apart never undoes a move I chose

#### Acceptance Criteria:
- **Scenario:** What I selected moves whole
- **Given:** a lasso round my ink and Larry's
- **When:** I drag it
- **Then:** everything I selected moves together, as before

---

### User Story 1205:

- **Summary:** What I kept together moves together: a tap picks up the piece or the reply, as I kept it
- **Status:** the rule decided 2026-11-22; a piece kept with Keep picked up alone is story 1140 and a reply kept with Keep group picked up whole is stories 947 and 998, each verified there; a reply kept with Keep all is one group since [96fb571e](https://github.com/idvorkin/context-grabber/commit/96fb571e) (story 1149), and a drag on part of a kept group brings the rest along since [7fe61413](https://github.com/idvorkin/context-grabber/commit/7fe61413) (story 1193); a tap on a Keep all reply picking it up whole not yet seen on the iPad
- **Spec:** [Ink that reflows like text](../superpowers/specs/2026-11-16-whiteboard-object-layer-design.md), *Decided 2026-11-22*
- **Issues:** Igor's pick on the design board, 2026-11-22: "What I kept together moves together: Keep = that piece, Keep group or Keep all = the reply. My own selection always wins a tap; a second tap rewords a text."; it settles story 1140 against PR #1187

#### Use Case:
- **As someone** with Larry's kept marks on my board
- **I want to** have a tap pick up exactly what one Keep made
- **so that** I know before I tap whether one piece or the whole reply will move

#### Acceptance Criteria:
- **Scenario:** A piece and a reply
- **Given:** one mark of Larry's kept on its own with Keep, and a reply of his kept with Keep all (or with Keep group before #1224), no marks showing
- **When:** I tap the single mark, and then a piece of the reply, with a finger
- **Then:** the first tap selects that mark alone and the second selects the whole reply and nothing else of his or mine; each drags as one, and one Undo puts it back

---

### User Story 1000:

- **Summary:** The buttons beside a chosen mark sit clear of the board's corner and wholly on screen
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepAllTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepAllKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad; the buttons narrowed to the view's width in a view too narrow for them, by host tests (`WhiteboardKeepAllTests`)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** tapping one of Larry's marks near the edge of the board
- **I want** its buttons where I can tap them, clear of ? and Feedback
- **so that** a tap meant for Keep never opens help or misses the button

#### Acceptance Criteria:
- **Scenario:** Never under the corner
- **Given:** the mark I tapped is near the board's top right, where ? and Feedback (and *Larry's edit blocked*) sit
- **When:** the buttons show
- **Then:** they sit clear of that corner and wholly on screen, each at least 36 points each way, and a tap on them never reaches the paper

---

### User Story 1007:

- **Summary:** A keep stays one Undo, whatever the board does just after it
- **Status:** implemented in [3a4d2979](https://github.com/idvorkin/context-grabber/commit/3a4d2979); verified by host tests (`BoardUndoProbeTests`: PaperKit's step on top taken back, a keep on top left on the stack with nothing said to Larry and one Undo still taking the whole group back, with a fake stack and Foundation's `UndoManager`), `just test` and the Mac build (`just native-build-mac`); the simulator not run (the Mac's screen was locked, so UI tests could not start), and the iPad still to do: the log's `paper_undo` and `paper_undo_left_ours` lines will say whether the take-back ever reached a keep there
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every keep is a step of Undo of its own, and keeps it*
- **Issues:** [#966](https://github.com/idvorkin/context-grabber/issues/966): Igor, 2026-11-19, board 302d5345, via Larry: he kept Larry's whole reply group, it sat on top of his own plan, and undo couldn't take it back

#### Use Case:
- **As someone** who kept one of Larry's replies and then went on working round it
- **I want** Undo to take the keep back, whatever I did with the board straight after
- **so that** a keep I regret never gets stuck on top of my own writing

#### Acceptance Criteria:
- **Scenario:** The board's own take-back comes just after a keep
- **Given:** I have just tapped *Keep all* (or *Keep* or *Tidy overlaps*), and the board then takes back a step of PaperKit's of its own, for a tap's dot, a zigzag or a dropped selection, before PaperKit's step is on top
- **When:** I press Undo until the keep is reached
- **Then:** the keep is still a step of its own, named for it, and one Undo takes every mark it kept back off the board

---

### User Story 1180:

- **Summary:** His marks move with the ink they answer
- **Status:** implemented in [559b7e16](https://github.com/idvorkin/context-grabber/commit/559b7e16), [6de8abc4](https://github.com/idvorkin/context-grabber/commit/6de8abc4) and [09c2d33b](https://github.com/idvorkin/context-grabber/commit/09c2d33b); verified on the host (`BoardMarkHoldsTests`): the anchor, a drag, room above both and between, Undo, and board 5c232430's label against its logged boxes), the Mac build, and the iPad simulator (`WhiteboardPaperGhostsUITests.testHisMarkMovesWithTheInkItAnswersAndBackWithUndo`: his circle on my lower line rode Larry's push by as much as the line, and one undo took both back). A drag of my own ink (a lasso's move) keeps the mark with it since [c198b95c](https://github.com/idvorkin/context-grabber/commit/c198b95c), verified on the host and the Mac build only. The iPad itself not yet tried
- **Issues:** bead `context-grabber-p2an`: Igor, 2026-11-23 16:55, via Larry (ask igor2-88g.1720.1): "Anchor, and fade when written over"; on board 5c232430 his new lines landed on Larry's *got all 33 strokes* label
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *His marks hold to the ink they answer, and fade when written over*

#### Use Case:
- **As someone** reworking the board while Larry's marks still show
- **I want to** see each mark of his stay beside the ink it answers when that ink moves
- **so that** a check stays on its word and a label beside its line, wherever I push them

#### Acceptance Criteria:
- **Scenario:** The ink a mark answers moves
- **Given:** a mark of Larry's, not kept, landed on or just below a line of my writing
- **When:** I drag that line, push it down with the room handle or *Insert space*, a paste's or a drop's room pushes it, or Larry moves it
- **Then:** the mark moves by the same amount and stays beside it; room opened between the line and its mark, or through the mark, leaves the mark beside the line
- **And:** Undo and Redo of that move take the mark back and forth with the line
- **And:** a mark on blank paper with nothing above or beside it stays where it landed
- **And:** the session log says, when the mark lands, what it holds to (or nothing) and how far away

---

### User Story 1181:

- **Summary:** His marks fold and unfold with their section
- **Status:** implemented in [559b7e16](https://github.com/idvorkin/context-grabber/commit/559b7e16) and [6de8abc4](https://github.com/idvorkin/context-grabber/commit/6de8abc4); verified on the host (`BoardMarkHoldsTests`): a real fold of `BoardOutline` hides it and unfold brings it back; a hidden mark takes no tap and no keep) and the Mac build. Not yet seen on the simulator or the iPad
- **Issues:** bead `context-grabber-p2an`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *His marks hold to the ink they answer, and fade when written over*

#### Use Case:
- **As someone** folding sections to see the board's shape
- **I want to** have Larry's marks on a section fold away with it and come back when I open it
- **so that** a folded board shows no stray marks over other sections

#### Acceptance Criteria:
- **Scenario:** Folding the section a mark answers
- **Given:** a mark of Larry's, not kept, answers ink under a header
- **When:** I fold that header
- **Then:** the mark doesn't show and can't be tapped, and *Keep all* leaves it
- **And:** when I unfold the header the mark shows again beside its ink, wherever the ink now is

---

### User Story 1269:

- **Summary:** Writing over one of his marks fades it
- **Status:** implemented in [559b7e16](https://github.com/idvorkin/context-grabber/commit/559b7e16), [6de8abc4](https://github.com/idvorkin/context-grabber/commit/6de8abc4) and [09c2d33b](https://github.com/idvorkin/context-grabber/commit/09c2d33b); verified on the host (`BoardMarkHoldsTests`): a word on a label, a strike-through and a scribble fade it; an underline, a ring and a crossing line don't; Undo unfades) and the Mac build. A scratch-out leaves the mark at full strength since [7178775e](https://github.com/idvorkin/context-grabber/commit/7178775e), verified on the host. Not verifiable on the simulator, where a finger pans while marks show; the iPad's Pencil still to try
- **Issues:** bead `context-grabber-p2an`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *His marks hold to the ink they answer, and fade when written over*

#### Use Case:
- **As someone** writing on, through Larry's marks
- **I want to** have a mark I write over fade under my writing
- **so that** my writing reads on top and I needn't dismiss what I've written past

#### Acceptance Criteria:
- **Scenario:** A stroke on a mark
- **Given:** a mark of Larry's, not kept, shows on the board
- **When:** I draw a stroke, with the Pencil or a drawing finger, with at least a third of its path inside a label's letter box or on a drawn mark's line
- **Then:** the mark fades to a third of its strength and stays where it was, still able to be kept or dismissed
- **And:** an underline below a label, a circle round it, a line crossing an arrow, ink already under the mark when it landed, a scratch-out, a paste, a drop, a keep and the eraser leave it at full strength
- **And:** Undo of that stroke, or erasing it, brings the mark back to full strength
- **And:** the session log says which mark the stroke wrote over and how much of the stroke lay on it

---

### User Story 1270:

- **Summary:** A faded mark goes on my next post, and Larry is told
- **Status:** implemented in [559b7e16](https://github.com/idvorkin/context-grabber/commit/559b7e16) and [6de8abc4](https://github.com/idvorkin/context-grabber/commit/6de8abc4); verified on the host (`BoardMarkHoldsTests`): the post's report names each with its reason beside a full turn of events) and the Mac build. Not yet seen on the iPad
- **Issues:** bead `context-grabber-p2an`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *His marks hold to the ink they answer, and fade when written over*

#### Use Case:
- **As someone** who wrote over Larry's suggestion
- **I want to** have it go when the board next reaches Larry, and him know why
- **so that** the board stays clear and he doesn't wonder where his mark went

#### Acceptance Criteria:
- **Scenario:** The next picture reaches Larry
- **Given:** a mark of Larry's is faded because I wrote over it, or doesn't show because the ink it answered is erased
- **When:** the next picture of the board reaches Larry (a pause's turn, *Send to Larry*, or the outbox sending one)
- **Then:** the mark goes, and that send's report names it by id with *written over* or *ink erased*
- **And:** it doesn't come back on the next look or the next open
- **And:** a send that fails or waits in the outbox leaves it as it was

---

### User Story 1271:

- **Summary:** A mark whose ink I erase goes with it, and Undo brings both back
- **Status:** implemented in [559b7e16](https://github.com/idvorkin/context-grabber/commit/559b7e16) and [6de8abc4](https://github.com/idvorkin/context-grabber/commit/6de8abc4); verified on the host (`BoardMarkHoldsTests`): all erased hides it, part erased hands it on, undo brings it back) and the Mac build. Not yet seen on the iPad
- **Issues:** bead `context-grabber-p2an`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *His marks hold to the ink they answer, and fade when written over*

#### Use Case:
- **As someone** erasing what Larry commented on
- **I want to** have his comment on it go too, and come back if I undo the erase
- **so that** no mark is left pointing at nothing

#### Acceptance Criteria:
- **Scenario:** Erasing what a mark answers
- **Given:** a mark of Larry's, not kept, answers a word of mine
- **When:** I erase all of that word
- **Then:** the mark doesn't show and can't be tapped
- **And:** Undo of the erase shows the mark again beside the word
- **And:** erasing part of the word leaves the mark beside what is left

---

### User Story 1348:

- **Summary:** A long label of Larry's wraps to the board he was looking at
- **Status:** implemented in [00efb292](https://github.com/idvorkin/context-grabber/commit/00efb292); verified on the host (`BoardLabelWrapTests`: breaks between words, a long word breaks where it must, a newline starts a row, rows stay inside the picture's right edge less the margin, each a 1.2 letter-height pitch lower, a label that fits draws as before, no picture means no wrap) and a before/after render of the lines on the Mac. Not yet seen on the iPad
- **Issues:** [#1526](https://github.com/idvorkin/context-grabber/issues/1526) (Igor on the iPad, 2026-11-26: "Larry ink should be wrapped as required")
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A long label wraps to the picture's width*

#### Use Case:
- **As someone** reading Larry's answer on the iPad board
- **I want to** see a long label of his wrapped onto further lines inside the board I was showing him
- **so that** none of his words run off the edge where I can't read them

#### Acceptance Criteria:
- **Scenario:** A label longer than the room to the right edge
- **Given:** Larry answers with a label that, on one line, would reach past the right edge of the picture he was sent
- **When:** it shows on the board
- **Then:** it goes on to further lines, breaking between words, every line inside that edge less a small margin
- **And:** each further line starts at the label's left edge, a fifth more than the letters' height below the one before (the Cockpit's line height)
- **And:** a label that fits shows on one line, as before
- **And:** keeping it keeps the lines as they show
