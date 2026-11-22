# The whiteboard: Ghosts and Larry's marks

What Larry and Claude draw back: ghosts, Keep and Dismiss, how their marks look, keeping a reply as a group, Keep all and Tidy, and the room a kept reply makes. One of the whiteboard journey's files; the
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
- **Status:** first implemented as drawing dismissing the ghosts in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to staying in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) (Igor, 2026-11-02); not verifiable on the simulator, which has no Pencil and no canvas in the accessibility tree; to try on the iPad, including a finger tap on a ghost while the Pencil is down
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing while Claude suggests
- **I want to** keep drawing while the ghosts stay
- **so that** it feels like drawing together, not taking turns

#### Acceptance Criteria:
- **Scenario:** The Pencil touches down
- **Given:** ghosts are showing, or a ghost turn is still on its way
- **When:** I touch the Pencil down and draw on
- **Then:** the ghosts stay, and the answer on its way still shows, drawn in one shape after another

---

### User Story 351:

- **Summary:** Turn the ghosts off
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); seen on the simulator in the recording of `WhiteboardTurnUITests.testGhostsOffAsksNothing` (no note with Ghosts off, the note back on), which passed with the other `WhiteboardTurnUITests` in the build turn of [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3). Since bead `context-grabber-5eq` the rule is a host test (`WhiteboardGhostTurnsTests`: a stroke with Ghosts off starts no pause, Claude's go and Larry's stay, an answer on its way lands stale, on again asks), and that UI test is gone
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who wants to draw undisturbed
- **I want to** switch Claude's ghosts off in the board's bar
- **so that** nothing is asked or offered until I switch them back

#### Acceptance Criteria:
- **Scenario:** Ghosts off
- **Given:** I turned Ghosts off in the board's bar
- **When:** I draw a stroke and lift the Pencil
- **Then:** nothing is asked and no ghost appears

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
- **Given:** Ghosts are on and the Cockpit can't be reached
- **When:** I draw a stroke and lift the Pencil
- **Then:** the stroke stays, and the bar says ghosts aren't answering, unless Larry's line is showing there

---

### User Story 353:

- **Summary:** Larry can't be reached
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), on the chat path in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); not verified by a test
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** see why he didn't get it
- **so that** I don't wait for an answer to a picture he never had

#### Acceptance Criteria:
- **Scenario:** Larry away
- **Given:** the Cockpit can't be reached
- **When:** I tap *Larry's turn*
- **Then:** the bar shows a copyable problem saying so, and the board is unchanged

---

### User Story 354:

- **Summary:** Ghosts on a device where a finger draws
- **Status:** app side implemented on this branch; `WhiteboardTurnUITests.testAFingerTapOffAGhostDismissesItAndOnOneKeepsIt` verified on the simulator by `WhiteboardTurnUITests` (an old-canvas test, dropped 2026-11-07; on paper `WhiteboardPaperGhostsUITests.testAGhostShowsOnThePaperAndKeepMakesItInk` and `testATapOffKeepsTheGhostDismissRemovesItAndAFingerDrawsAgain` hold it since story 825); an iPhone and an iPad with no Pencil not yet tried. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first and Larry's only once his are all that's left (stories 663, 664); on branch `native/batch-decided-1114` (#883, story 825) a tap on a ghost offers Keep and Dismiss and a tap off them does nothing, verified by host tests and the Mac build, simulator and device still to do
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a finger, on an iPad with no Pencil (an iPhone only looks since story 746)
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** tapping a suggestion doesn't draw a dot and lose it

#### Acceptance Criteria:
- **Scenario:** A finger tap while ghosts show
- **Given:** a finger draws on this device and ghosts are showing
- **When:** I tap a ghost
- **Then:** Keep and Dismiss show beside it and no dot is drawn (story 825); once no ghost is left, kept, dismissed or faded, my finger draws again

---

### User Story 663:

- **Summary:** A stray tap leaves Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (`WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad; changed on branch `native/batch-decided-1114` (#883, story 825): a tap off the marks dismisses nothing, and a mark goes only by its own Dismiss; verified by host tests and the Mac build, simulator and device still to do
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good), [#883](https://github.com/idvorkin/context-grabber/issues/883) (Keep and Dismiss beside the mark, story 825)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on a board where Claude and Larry have both drawn back
- **I want to** dismiss only Claude's ghosts when I tap off them
- **so that** one stray tap can't lose Larry's marks, which can't come back

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with both showing
- **Given:** Claude's ghosts and Larry's marks are both showing
- **When:** I tap off them
- **Then:** nothing is dismissed: Claude's and Larry's all stay (story 825)

---

### User Story 664:

- **Summary:** A deliberate choice clears Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (`WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad; changed on branch `native/batch-decided-1114` (#883, story 825): a tap off the marks dismisses nothing, and a mark goes only by its own Dismiss; verified by host tests and the Mac build, simulator and device still to do
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good), [#883](https://github.com/idvorkin/context-grabber/issues/883) (Keep and Dismiss beside the mark, story 825)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has looked at Larry's marks and doesn't want them
- **I want to** dismiss Larry's marks with a tap off them once they're all that's left
- **so that** clearing his always takes a tap of its own

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with only Larry's left
- **Given:** only Larry's marks are showing
- **When:** I tap Dismiss beside each of them (story 825)
- **Then:** each goes as I dismiss it, and a tap off them dismisses nothing

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
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests`: the tap and where the buttons sit) and the Mac build. Fixed in [6754880](https://github.com/idvorkin/context-grabber/commit/6754880): the dot PaperKit draws under a finger's tap is taken back (`PaperProbeTests.testATapsDotIsTheSmallInkAtTheTapJustAfterIt`), and Keep and Dismiss carry their own names; verified on an iPad simulator by `WhiteboardPaperGhostsUITests`, three runs, every test passing first time. The iPad itself still to do
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
- **Then:** nothing on the board has changed, and Keep and Dismiss show beside it, wholly on screen

---

### User Story 808:

- **Summary:** Dismiss beside a mark removes only it
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests.testDismissRemovesOnlyThatMark`, `WhiteboardMarksTests.testSettlingRemembersOnlyThatRowsKeptOrDismissedMarks`) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** dismiss one mark with the Dismiss beside it
- **so that** I turn down that mark and keep thinking about the rest

#### Acceptance Criteria:
- **Scenario:** Dismissing one of his marks
- **Given:** Keep and Dismiss show beside one of Larry's three marks
- **When:** I tap Dismiss
- **Then:** only that mark goes, and when the board opens again it stays gone while his other two show

---

### User Story 809:

- **Summary:** Keep beside a mark makes it ink
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests.testKeepTakesTheChosenMarkOffTheGhosts`) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing); context-grabber-ikya (a kept text of Larry's drew black all but its first glyph, now and then on the iPad simulator, 2026-11-20 and 21: PaperKit held every stroke purple and drew one tile of it blank or black; the board now finds that and draws the mark again, story 650, since [ce66651b](https://github.com/idvorkin/context-grabber/commit/ce66651b))
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** keep one mark with the Keep beside it
- **so that** it joins my drawing only because I said so

#### Acceptance Criteria:
- **Scenario:** Keeping a mark
- **Given:** Keep and Dismiss show beside a mark
- **When:** I tap Keep
- **Then:** it becomes ink in its colour, and one undo takes it back

---

### User Story 810:

- **Summary:** A stray tap or a stroke puts Keep and Dismiss away
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests`: the stray tap and the stroke) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
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
- **When:** I tap one
- **Then:** it becomes purple ink that my eraser and undo treat like mine

---

### User Story 356:

- **Summary:** Larry's marks stay when the ghosts go off
- **Status:** app side implemented in [e2f693e](https://github.com/idvorkin/context-grabber/commit/e2f693e); verified on the simulator by the session log (`whiteboard` ghosts: Ghosts off drops Claude's one ghost, then Larry's turn shows his two); a UI test could not read it, as the Ghosts button's accessibility label does not refresh for XCUITest while Ghosts is off; on the iPad not yet
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn and wants Claude to stop suggesting
- **I want to** switch the ghosts off without losing what Larry drew
- **so that** the switch only quiets Claude, and Larry's answer waits for me to keep it

#### Acceptance Criteria:
- **Scenario:** Ghosts off with Larry's marks showing
- **Given:** Larry's faint purple shapes are showing
- **When:** I turn Ghosts off in the board's bar
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
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11); verified on the simulator by `WhiteboardTurnUITests` (`testClaudesGhostsFadeAndLarrysStay`, with the time shortened); since bead `context-grabber-5eq` by host tests instead (`WhiteboardGhostTurnsTests`: Claude's go at 30 s and Larry's stay, a newer answer starts the 30 s over, Larry's never fade)
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
- **Given:** Ghosts are on, I paused, and the Cockpit streams its answer
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

- **Summary:** A board opens with only his newest marks, and a dismissed set stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: reopened with his newest set)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** coming back to a board Larry has drawn on for days
- **I want to** see only where he has got to, and never what I already turned down
- **so that** the board isn't buried in old marks

#### Acceptance Criteria:
- **Scenario:** Opening a board
- **Given:** the board's thread has several rows of his marks
- **When:** I open the board
- **Then:** only his newest row shows, with its line; older ones stay in Chat

---

### User Story 388:

- **Summary:** A set I've dealt with stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: dismissed, not back on the next look or the next open); keeping one from a row then reopening is host-tested only; on branch `native/batch-decided-1114` (#883, story 808) only the marks kept or dismissed stay gone, and the rest of the row shows again on opening, verified by host tests (`WhiteboardMarksTests`) and the Mac build
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has answered Larry's marks
- **I want to** never see what I already kept or turned down
- **so that** the board isn't nagging me about a settled question

#### Acceptance Criteria:
- **Scenario:** Already settled
- **Given:** I kept or dismissed marks from his newest row
- **When:** a look at the thread comes round, or I open the board again
- **Then:** those marks don't come back, until he posts a new row

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
- **Status:** implemented in [4aee299](https://github.com/idvorkin/context-grabber/commit/4aee299), PR [#891](https://github.com/idvorkin/context-grabber/pull/891), the paper colours held to his purple in [e4efeae](https://github.com/idvorkin/context-grabber/commit/e4efeae); verified on the host (`just native-test`: `WhiteboardTurnTests.testLarrysColourIsNoneOfThePickersOrClaudes`, `BoardPaperTests.testLarrysPurpleInkReadsOnEveryColour` and `testGhostsAreNearlyAsVisibleAsOnPlain` with his purple) and the Mac build (`just native-build-mac`). That a keep leaves the pen as it was lives in the paper view, with no host test: it is logged (`paper_keep` tool_before, tool_after, tool_restored) and put back if it ever changed. Not yet seen on the simulator or a device
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
- **Status:** implemented in [4aee299](https://github.com/idvorkin/context-grabber/commit/4aee299), PR [#891](https://github.com/idvorkin/context-grabber/pull/891); split from story 774. Verified by the Mac build (`just native-build-mac`) only: it lives in the paper view, with no host test, and is logged (`paper_keep` tool_before, tool_after, tool_restored) and put back if it ever changed. Not yet seen on the simulator or a device
- **Issues:** bead context-grabber-a3w
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Larry's own colour*

#### Use Case:
- **As someone** writing back to Larry on a board in the picker's blue
- **I want to** keep one of his marks without my pen changing
- **so that** my next stroke is still mine, in the colour and width I chose

#### Acceptance Criteria:
- **Scenario:** My pen after a keep
- **Given:** I'm writing with the picker's blue pen at its width
- **When:** I tap one of Larry's ghosts to keep it and write again
- **Then:** my next stroke is the same blue pen at the same width as before the keep

---

### User Story 772:

- **Summary:** A kept label of small letters stays on the board
- **Status:** implemented in [b54599d](https://github.com/idvorkin/context-grabber/commit/b54599d), the floor at 2.5 points in [b18aa04](https://github.com/idvorkin/context-grabber/commit/b18aa04); verified on the host (`just native-test`: `WhiteboardTurnTests.testNoMarkIsThinnerThanTheIPadDraws`, a small label's pen, a thin asked-for pen and an unasked line, and the rest of `WhiteboardTurnTests`) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** keeping a label Larry wrote on my board
- **I want to** see it stay as ink where its ghost was
- **so that** a tap that keeps his words never looks like a tap that threw them away

#### Acceptance Criteria:
- **Scenario:** Small letters
- **Given:** a board on paper, and a label of Larry's with 12-point letters and no pen of its own
- **When:** I tap it to keep it
- **Then:** it stays on the board as purple ink, as thick as its ghost was, and the next picture Larry gets shows it

---

### User Story 779:

- **Summary:** A mark that asks for a pen too thin to draw is drawn at the thinnest the iPad shows
- **Status:** implemented in [b54599d](https://github.com/idvorkin/context-grabber/commit/b54599d), the floor at 2.5 points in [b18aa04](https://github.com/idvorkin/context-grabber/commit/b18aa04); split from story 772. Verified on the host (`just native-test`: `WhiteboardTurnTests.testNoMarkIsThinnerThanTheIPadDraws`, a thin asked-for pen) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
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
- **Status:** implemented in [6cd94985](https://github.com/idvorkin/context-grabber/commit/6cd94985), [64dae5ba](https://github.com/idvorkin/context-grabber/commit/64dae5ba); the simulator test reworked in [ebd344b5](https://github.com/idvorkin/context-grabber/commit/ebd344b5); verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`: his marks stay where they showed, both of Igor's lines move 40 points down clear of them, one undo puts them back and takes his marks away); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** writing on while Larry answers a picture of my board
- **I want to** have his reply push down what I wrote after he looked, when I keep it
- **so that** his reply never lands on my newer ink, and his marks still sit beside what they name

#### Acceptance Criteria:
- **Scenario:** Keep group over writing newer than his picture
- **Given:** Larry's reply of several marks showing where I have written two lines since his picture went, under my older plan
- **When:** I tap one of his marks and *Keep group*
- **Then:** his marks become ink where they showed, my two lines and everything under them move down in whole lines until they sit half a line under his lowest mark, my plan above doesn't move, and one Undo puts my lines back and takes his marks away

---

### User Story 1005:

- **Summary:** One kept mark of Larry's makes room for what I wrote since his picture
- **Status:** implemented on branch `native/board-make-room-894`; verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
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
- **Status:** implemented on branch `native/board-make-room-894`; verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
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
- **Status:** implemented on branch `native/board-make-room-894`; verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
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

- **Summary:** Keep all of Larry's marks at once, in the order he drew them
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4) (the web board's `keepAll`, without moving my ink); verified on the host (`WhiteboardTidyTests`; `just native-test`) and on the simulator (`WhiteboardTurnUITests.testKeepingAllOfLarrysMarksMakesThemInkInOneStep`, rung 2)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** whose board Larry answered with several labels
- **I want to** keep them all in one go, each clear of my writing and still in order
- **so that** his answer reads as he wrote it without my tapping every mark

#### Acceptance Criteria:
- **Scenario:** Larry's labels, one landing on my writing
- **Given:** Larry's marks show on my board and the first of his labels sits on a line I wrote
- **When:** I tap Keep all beside the count of marks to keep
- **Then:** every one of his marks becomes ink in his colour, the label on my writing moves just under it and the marks below it move down with it, my own ink doesn't move, and one undo takes all of them back

---

### User Story 896:

- **Summary:** Tidy overlaps moves kept labels off my writing
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4) (the web board's `tidy`, without moving my ink); verified on the host (`WhiteboardTidyTests.testTidyMovesOnlyTheLabelsThatSitOnInk`, `testTidySeparatesTwoLabelsOnEachOther`, `testTidyTwiceChangesNothing`); `just native-test`. Not yet seen on the simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** who kept labels that landed on my own writing
- **I want to** tidy them off it in one step
- **so that** the board stays readable without moving anything by hand

#### Acceptance Criteria:
- **Scenario:** A kept label over my words
- **Given:** a label I kept sits on a line I wrote, and another sits on bare paper
- **When:** I choose Board → Tidy overlaps
- **Then:** the label on my words moves down to the first clear space under them, the other stays, my ink doesn't move, and one undo puts it back

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
- **Then:** a ghost arrow runs from one thing's facing side to the other's, around anything in its way, beside my other marks

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
- **Given:** Larry's connector mark between two things, showing as a ghost
- **When:** I tap Keep, or Keep all
- **Then:** it becomes a connector joining them (with Keep all, in the one Undo), and a push between them redraws it to where they are. If kept with plain Keep, the redrawn connector still selects its reply with a tap (story 1148, bead context-grabber-hm7n)

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
- **Status:** implemented on branch `native/board-ops-937-grouped-label`; verified by host tests (`BoardOpsInkTests`, `BoardReplayTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's Judge batch; not yet seen on the iPad
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
- **Status:** implemented on branch `native/board-ops-938-text-room`; verified by host tests (`BoardRoomTests`, `BoardReplayTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's list batch; keeping a ghost with ink under it is not yet seen on the simulator or the iPad
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

- **Summary:** One tap keeps all of a reply of Larry's, as one group
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942): Igor, 2026-11-17 19:15, via Larry: "accept the group", after keeping his four named boxes one mark at a time; [#966](https://github.com/idvorkin/context-grabber/issues/966): Igor, 2026-11-19, board 302d5345, via Larry: he kept Larry's whole reply group, it sat on top of his own plan, and undo couldn't take it back (story 1007)

#### Use Case:
- **As someone** Larry answered with a little drawing of several marks
- **I want to** keep the whole of his reply with one tap, as one thing
- **so that** his drawing lands whole and moves as one, and one Undo takes it all back

#### Acceptance Criteria:
- **Scenario:** Keep group
- **Given:** Larry's reply of several marks showing, and I tap one of them
- **When:** I tap *Keep group* between Keep and Dismiss
- **Then:** every mark of that reply still showing becomes ink in his colours where it showed, none is left to keep, and one Undo takes them all back

---

### User Story 998:

- **Summary:** A reply of Larry's kept as a group moves as one
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** who kept Larry's drawing as a group
- **I want** it to move as one thing, whoever moves it
- **so that** his drawing never comes apart on my board

#### Acceptance Criteria:
- **Scenario:** It moves as one
- **Given:** a reply I kept as a group
- **When:** Larry moves it by the group's name, or a push opens room through it
- **Then:** all of it moves together, and Larry hears its strokes under that one group

---

### User Story 999:

- **Summary:** Keep group is offered only when more than one mark of the reply shows
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** keeping Larry's marks
- **I want** *Keep group* only when there is a group to keep
- **so that** the buttons beside one mark stay Keep and Dismiss

#### Acceptance Criteria:
- **Scenario:** One mark left
- **Given:** only one mark of his reply still shows
- **When:** I tap it
- **Then:** Keep and Dismiss show, and no *Keep group*

---

### User Story 947:

- **Summary:** A finger tap on any stroke of a group selects the whole group, ready to drag
- **Status:** implemented in [3175c799](https://github.com/idvorkin/context-grabber/commit/3175c799); verified by host tests (`BoardOutlineTests`: `testAFingerTapOnAGroupsStrokeTakesTheWholeGroup`, `testATextInsideAGroupIsTheGroupsAndABareTextIsNot`; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardGroupTapUITests`, rung 2, 2026-11-22: the tap selects all three kept marks and they stay selected past the tap's dot, a finger drag moves them whole, one Undo puts them back, a tap beside them selects nothing); a second tap opening a grouped text's words, and the tap with the Pencil paired (fingers not drawing), not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on a group)
- **Issues:** [#947](https://github.com/idvorkin/context-grabber/issues/947): Igor, 2026-11-18 about 05:42, via Larry: "when I click select-all, I want some notion of fixed object on finger-click to move"

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

- **Scenario:** A text inside a group
- **Given:** a group holding a kept text
- **When:** I tap the text once, and again with the group selected
- **Then:** the first tap selects the group; the second opens the text's words for rewording (story 940)

---

### User Story 1140:

- **Summary:** A finger tap on anything of Larry's I kept picks up that one thing alone, ready to drag
- **Status:** implemented in [38843ea5](https://github.com/idvorkin/context-grabber/commit/38843ea5), [e1409a33](https://github.com/idvorkin/context-grabber/commit/e1409a33); verified by host tests (`BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`: one of two kept marks, his ink nearer and a group's left to the group; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardTheirsTapUITests`, rung 2, 2026-11-22: three circles kept with Keep all, a finger tap selects the first alone, its Delete leaves the other two, one Undo brings it back); the drag not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on anything of Larry's he kept)
- **Issues:** [#1171](https://github.com/idvorkin/context-grabber/issues/1171): Igor, 2026-11-22 17:21, on the iPad, Larry's steps written inside a box of his: "I want to be able to click what Larry wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"

#### Use Case:
- **As someone** with Larry's writing kept on the board, on or beside my own
- **I want to** tap it with a finger and have just that one thing of his selected
- **so that** I can move it on its own, without a lasso that drags my ink along or splits his text

#### Acceptance Criteria:
- **Scenario:** One of his, alone
- **Given:** three marks of Larry's kept with Keep all, on a board I can draw on, no marks showing
- **When:** I tap one of them with a finger and drag it
- **Then:** that mark alone is selected and moves; his other two and my ink stay where they were, and one Undo puts it back

---

### User Story 1141:

- **Summary:** A finger tap on a text of Larry's over my box takes his whole text and none of my box
- **Status:** implemented in [38843ea5](https://github.com/idvorkin/context-grabber/commit/38843ea5), [e1409a33](https://github.com/idvorkin/context-grabber/commit/e1409a33); verified by host tests (`BoardOutlineTests.testAFingerTapOnOneThingOfLarrysTakesItAlone`: his text alone over his box; `just native-test`) and the Mac build (`just native-build-mac`); the selection, its drag and the second tap's reword not yet seen on the iPad simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (a finger tap on anything of Larry's he kept)
- **Issues:** [#1171](https://github.com/idvorkin/context-grabber/issues/1171): Igor, 2026-11-22 17:21, on the iPad, Larry's steps written inside a box of his: "I want to be able to click what Larry wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"

#### Use Case:
- **As someone** with a text of Larry's kept inside a box I drew
- **I want to** tap one of its letters and have all of his text selected, and only it
- **so that** I can move his words out of my box, or reword them with a second tap

#### Acceptance Criteria:
- **Scenario:** His text on my box
- **Given:** a text of Larry's kept over a box I drew
- **When:** I tap one of its letters with a finger
- **Then:** every letter of the text is selected and none of my box, and the label reads *Text · tap to reword*; a second tap on it opens its words

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

### User Story 1148:

- **Summary:** A finger tap on one piece of a reply of Larry's I kept with Keep picks up the whole reply
- **Status:** implemented in [98a3358f](https://github.com/idvorkin/context-grabber/commit/98a3358f) and [ca32e537](https://github.com/idvorkin/context-grabber/commit/ca32e537); verified by host tests (`BoardOutlineTests.testAFingerTapOnOnePieceOfAReplyTakesTheWholeReply`: both pieces of one reply, another reply's mark, a piece with no reply known, his own ink; `BoardMeaningTests`: the reply remembered by moment and pruned with the oldest; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardTheirsTapUITests.testKeepOnOneMarkKeepsTheWholeReplyAndATapPicksItAllUp`, rung 2, 2026-11-22: Keep on one of three circles of one reply keeps all three, a finger tap on the first selects all three, whose Delete takes them and one Undo brings them back; `WhiteboardPaperGhostsUITests` and `WhiteboardGroupTapUITests` still pass). The simulator fixture draws circles. Not yet seen on the iPad, where the drag after the tap is bead context-grabber-4nnh
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (one reply of Larry's, kept piece by piece, is picked up whole)
- **Issues:** bead context-grabber-hm7n: Igor, 2026-11-22 about 12:10, on the iPad, relayed by Larry in the Cockpit: "Should move as group when clicked". The iPad's log for that moment shows the two labels were kept with Keep group, and the tap did select all 93 strokes. What failed there is the drag that followed, which moved nothing (bead context-grabber-4nnh). This story covers a reply kept with plain Keep, which a tap used to pick up one piece at a time.

#### Use Case:
- **As someone** who kept Larry's two-line answer with plain Keep
- **I want** a finger tap on either label to pick up both
- **so that** I can select his whole answer in one tap

#### Acceptance Criteria:
- **Scenario:** Two labels of one reply, kept with Keep
- **Given:** a reply of Larry's with two labels, kept with plain Keep, a mark of his from another reply and my own writing beside them, on a board I can draw on, no marks showing
- **When:** I tap one of the labels with a finger
- **Then:** both labels are selected, leaving out the other reply's mark and my writing

---

### User Story 1144:

- **Summary:** A second tap on a text of a reply picked up whole still opens its words
- **Status:** implemented in [98a3358f](https://github.com/idvorkin/context-grabber/commit/98a3358f); verified by the Mac build (`just native-build-mac`); the second tap not yet seen on the iPad simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (one reply of Larry's, kept piece by piece, is picked up whole)
- **Issues:** bead context-grabber-hm7n

#### Use Case:
- **As someone** who picked up a reply of Larry's whole with a tap on one of its labels
- **I want** a second tap on that label to open its words, as it does for a text alone
- **so that** picking up his reply whole never costs me rewording it (story 940)

#### Acceptance Criteria:
- **Scenario:** A text in the reply still opens its words
- **Given:** a reply of Larry's selected by a finger tap on one of its labels
- **When:** I tap that label again
- **Then:** its words open for rewording. After I save the new wording or undo the change, tapping the label still selects the reply

---

### User Story 1145:

- **Summary:** Keep on one mark of a reply of Larry's keeps the whole reply, so a slip of the finger never loses the rest
- **Status:** implemented in [ca32e537](https://github.com/idvorkin/context-grabber/commit/ca32e537); verified by host tests (`WhiteboardKeepGroupTests.testKeepOnOneMarkOfAReplyTakesTheWholeReply`: the whole reply; `just native-test`), the Mac build (`just native-build-mac`), and on the iPad simulator against the fake Cockpit (`WhiteboardTheirsTapUITests.testKeepOnOneMarkKeepsTheWholeReplyAndATapPicksItAllUp`, rung 2, 2026-11-22: Keep on one of three circles of one reply keeps all three, a finger tap on the first selects all three, whose Delete takes them and one Undo brings them back; `WhiteboardPaperGhostsUITests` and `WhiteboardGroupTapUITests` still pass); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (Keep on any mark of a reply of Larry's keeps the whole reply)
- **Issues:** bead context-grabber-hm7n: Igor, 2026-11-22 12:34, on the iPad (board 8f986938), relayed by Larry: "Keep group is broken when accidentally select one!" Larry's sequence diagram came as one reply of 13 marks (row d310df61e6f5). Igor's tap chose one label and Keep kept only it (`keep`, 25 strokes). The other 12 stayed as ghosts until Larry's next reply (row 40b967e4c623) replaced them 16 s later, so the rest of the diagram was never kept.

#### Use Case:
- **As someone** who meant to keep Larry's whole diagram and touched one label of it
- **I want** Keep on that one mark to keep everything in his reply
- **so that** a slip of the finger never leaves the rest to vanish when his next reply comes

#### Acceptance Criteria:
- **Scenario:** Keep on one mark of a reply
- **Given:** a reply of Larry's of three marks showing as ghosts
- **When:** I tap one and press Keep
- **Then:** all three become ink where they showed, none is left to keep, and one Undo takes all three back

---

### User Story 1146:

- **Summary:** A piece of Larry's kept before the board knew its reply is still picked up alone
- **Status:** implemented in [98a3358f](https://github.com/idvorkin/context-grabber/commit/98a3358f); verified by host tests (`BoardOutlineTests.testAFingerTapOnOnePieceOfAReplyTakesTheWholeReply`: a piece with no reply known; `BoardMeaningTests.testTheReplyOfEachKeptPieceIsRememberedWithItsMoment`: a file from before has no replies; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (one reply of Larry's, kept piece by piece, is picked up whole)
- **Issues:** bead context-grabber-hm7n

#### Use Case:
- **As someone** with marks of Larry's kept before this change
- **I want** a tap on one of them to work as it did
- **so that** an old board neither breaks nor gathers pieces it cannot know belong together (story 1140)

#### Acceptance Criteria:
- **Scenario:** Kept before this change
- **Given:** a reply's pieces kept before the board learned which reply each came from
- **When:** I tap one with a finger
- **Then:** that piece alone is selected, as before

---

### User Story 1147:

- **Summary:** A group Larry made himself is still picked up as the group
- **Status:** implemented in [98a3358f](https://github.com/idvorkin/context-grabber/commit/98a3358f); verified by host tests (`BoardOutlineTests.testAFingerTapOnOnePieceOfAReplyTakesTheWholeReply`: Larry's own group; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss* (one reply of Larry's, kept piece by piece, is picked up whole)
- **Issues:** bead context-grabber-hm7n

#### Use Case:
- **As someone** with strokes Larry put in one group with a change of his
- **I want** a tap on any of them to take his group, not a reply
- **so that** what he grouped moves as he grouped it (story 947)

#### Acceptance Criteria:
- **Scenario:** A group Larry made himself
- **Given:** strokes Larry put in one group with a change of his
- **When:** I tap one of them with a finger
- **Then:** the whole group is selected

---

### User Story 1149:

- **Summary:** A mark outside Larry's replies keeps by itself
- **Status:** implemented in [ca32e537](https://github.com/idvorkin/context-grabber/commit/ca32e537), covered by the host test `WhiteboardKeepGroupTests.testKeepOnOneMarkOfAReplyTakesTheWholeReply`
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** bead context-grabber-hm7n

#### Use Case:
- **As someone** choosing a mark of Claude's or a text Larry offered with a change
- **I want** Keep to take just the piece I chose
- **so that** I can decide what to keep one piece at a time

#### Acceptance Criteria:
- **Scenario:** A single mark outside a reply
- **Given:** several marks showing, including one from Claude or a text Larry offered with a change
- **When:** I press Keep on that mark
- **Then:** only the chosen mark becomes ink

---

### User Story 1150:

- **Summary:** Dismiss takes only the chosen mark of Larry's reply
- **Status:** implemented in [ca32e537](https://github.com/idvorkin/context-grabber/commit/ca32e537), covered by the host test `WhiteboardKeepGroupTests.testKeepOnOneMarkOfAReplyTakesTheWholeReply`
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** bead context-grabber-hm7n

#### Use Case:
- **As someone** looking at several marks in Larry's reply
- **I want** to dismiss one of them
- **so that** I can still keep the rest of the reply

#### Acceptance Criteria:
- **Scenario:** Dismiss one mark in a reply
- **Given:** several marks of one reply showing
- **When:** I press Dismiss on one of them
- **Then:** the chosen mark goes away and the others stay available to keep

---

### User Story 1000:

- **Summary:** The buttons beside a chosen mark sit clear of the board's corner and wholly on screen
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad; the buttons narrowed to the view's width in a view too narrow for them, by host tests (`WhiteboardKeepGroupTests`)
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
- **Given:** I have just tapped *Keep group* (or *Keep*, *Keep all* or *Tidy overlaps*), and the board then takes back a step of PaperKit's of its own, for a tap's dot, a zigzag or a dropped selection, before PaperKit's step is on top
- **When:** I press Undo until the keep is reached
- **Then:** the keep is still a step of its own, named for it, and one Undo takes every mark it kept back off the board
