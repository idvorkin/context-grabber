# The whiteboard

Drawing on the iPad with the Pencil, Larry seeing the board, and Claude and Larry drawing back. Specs:
[2026-11-01-whiteboard-design.md](../superpowers/specs/2026-11-01-whiteboard-design.md),
[2026-11-01-whiteboard-shapes-design.md](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[2026-11-02-whiteboard-paste-design.md](../superpowers/specs/2026-11-02-whiteboard-paste-design.md).

---

### User Story 340:

- **Summary:** Draw and erase on the iPad with the Pencil
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), the system's Pencil-only setting in [ab9c1e8](https://github.com/idvorkin/context-grabber/commit/ab9c1e8); built for the simulator, where with no Pencil paired a finger draws (the system's own Pencil-only setting); the Pencil, palm and eraser not yet tried on the iPad

#### Use Case:
- **As someone** who thinks better with a pen in hand
- **I want to** open a board and draw on it with the Pencil, and erase with it
- **so that** an idea gets out of my head the way it would on a whiteboard

#### Acceptance Criteria:
- **Scenario:** Pencil, palm and finger
- **Given:** a board of mine is open on the iPad, with my palm resting on the glass
- **When:** I draw with the Pencil, then double-tap it and rub out a stroke, then drag a finger
- **Then:** the Pencil leaves ink, my palm leaves nothing, the eraser removes the stroke, and the finger moves the board without drawing

---

### User Story 341:

- **Summary:** A board that keeps going past the screen
- **Status:** the free-panning board implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); the criterion below is the pages change, not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)

#### Use Case:
- **As someone** who writes down a page and keeps going
- **I want to** scroll down a column of pages, with a blank one always waiting
- **so that** I never run out of room halfway through a thought, and never get lost on a huge square

#### Acceptance Criteria:
- **Scenario:** Past the bottom
- **Given:** I have drawn to the bottom of the last page
- **When:** I drag the board up with a finger and keep drawing
- **Then:** a blank page slides in under the Pencil, and a faint line marks where the last page ended

---

### User Story 342:

- **Summary:** The board is still there next time
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); saving on close, on a link and in the background in [ab9c1e8](https://github.com/idvorkin/context-grabber/commit/ab9c1e8); verified by host tests (`WhiteboardFrameTests`: centred on the drawing) and the simulator build; a relaunch not yet tried on the iPad; that the view opens at the place I left it is the pages change, not implemented (it still opens centred on the drawing); asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)

#### Use Case:
- **As someone** who comes back to a sketch later
- **I want to** find the board as I left it
- **so that** a half-finished idea is never lost

#### Acceptance Criteria:
- **Scenario:** Relaunch
- **Given:** I drew on the board and then quit the app
- **When:** I open the Whiteboard again and tap that board's row
- **Then:** every stroke is there, and the view opens at the place I left it

---

### User Story 343:

- **Summary:** Show Larry the board
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), one send per stroke in [abe5876](https://github.com/idvorkin/context-grabber/commit/abe5876), the thread titled with the board's name in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023), the board's one thread instead of a new one each time in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardFrameTests`: the picture's margin and size) and the simulator build; a thread in Chat not yet seen from the iPad; a picture of the page or pages on screen is the pages change, not implemented (it still shows the whole drawing); asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)

#### Use Case:
- **As someone** who sketches to think and then wants to talk it over
- **I want to** send the board to Larry in one tap
- **so that** he sees what I drew and answers in the board's chat thread

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** I have drawn on the board and the iPad is in dark mode
- **When:** I tap Send to Larry
- **Then:** the bar says the board is on its way, and Chat gets the board's thread, titled with the board's name ("Board, Nov 1", or what I renamed it to), holding a picture of the page or pages on screen, dark ink on white

- **Scenario:** One send, one message
- **Given:** I have just sent the board to Larry
- **When:** I tap Send to Larry again before drawing anything more
- **Then:** nothing is sent, because the button is disabled until my next stroke

---

### User Story 344:

- **Summary:** Claude suggests the next strokes as I draw
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), the Cockpit's `POST /whiteboard/suggest` in [7974077](https://github.com/idvorkin/context-grabber/commit/7974077); verified by host tests (`WhiteboardTurnTests`: the request, the answer, each kind of stroke, a label on its baseline, a 429 skipped, shapes onto the board, a tap's hit, kept ink through PencilKit's own spline; `WhiteboardGhostTurnsTests`: a failing Cockpit noted once, a stale answer shown nowhere) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a pause brings a ghost; the keep verified on the simulator by `WhiteboardTurnUITests`); a real Claude answer and undo not yet tried on the iPad
- **Issues:** [#624](https://github.com/idvorkin/context-grabber/issues/624)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing alone
- **I want to** see faint suggested strokes when I pause
- **so that** it feels like drawing with someone

#### Acceptance Criteria:
- **Scenario:** A ghost, kept
- **Given:** I drew two circles and lifted the Pencil with Ghosts on, and a faint orange shape appeared within about five seconds
- **When:** I tap it
- **Then:** it becomes a real stroke in Claude's orange that my eraser and undo treat like mine

- **Scenario:** Every kind of stroke
- **Given:** Ghosts are on and I paused
- **When:** the Cockpit answers with a line, an arrow, a polyline, a circle, an arc, a label and a kind the app doesn't know
- **Then:** the six I know appear as faint orange ghosts, the label's letters standing on the spot the Cockpit gave as its baseline, and the unknown one isn't shown

- **Scenario:** The model takes too long
- **Given:** Ghosts are on and I paused
- **When:** the Cockpit has not answered after 10 s
- **Then:** no ghost appears and the bar says *Ghosts: the Cockpit isn't answering* until a turn gets through

- **Scenario:** Asked too soon
- **Given:** ghosts are showing
- **When:** a new turn comes within the Cockpit's 2 s and it answers 429
- **Then:** the turn is skipped with no error, the bar doesn't change and the ghosts stay

---

### User Story 345:

- **Summary:** Talk while I draw
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); the words to the turn verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and the new words by `WhiteboardSpeechTests`; real dictation over the Pencil and a real model answer to try on the iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** whose hands are busy with the Pencil
- **I want to** say what the drawing means and what I want
- **so that** Claude's suggestions follow my words, not just my scrawl

#### Acceptance Criteria:
- **Scenario:** Spoken direction
- **Given:** the mic is open on the board, and I drew a curve
- **When:** I say "this is my energy over the week, mark the dip"
- **Then:** within about 5 s of my stopping, faint orange ghosts answer what I said, such as a label "dip" with an arrow at the curve's low point, without my lifting or drawing anything more

---

### User Story 346:

- **Summary:** Larry on a call sees and draws on the board
- **Status:** not implemented (needs a call from the board; his marks on the board already come over chat, story 382)

#### Use Case:
- **As someone** talking an idea through with Larry
- **I want to** call him from the board and keep drawing while we talk
- **so that** he sees the board change and can sketch his answer on it

#### Acceptance Criteria:
- **Scenario:** Call from the board
- **Given:** the board has a drawing
- **When:** I start a Larry call from the board and draw an arrow while talking
- **Then:** Larry speaks to what is on the board, and his own strokes appear in his colour

---

### User Story 347:

- **Summary:** See the iPad's boards on the phone
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and the review fixes in [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5); verified by host tests (`BoardIndexTests`: read-only off the drawing device, the merge, a failed fetch retried) and the simulator (the boards open, iCloud skipped with no account); an iPad board on the phone not yet seen

#### Use Case:
- **As someone** away from the iPad
- **I want to** look at the boards on the phone
- **so that** the sketch is with me wherever I am

#### Acceptance Criteria:
- **Scenario:** View only, through iCloud
- **Given:** I drew a board on the iPad and closed it, and both devices are signed into my iCloud
- **When:** I open the Whiteboard on the phone and tap that board's row
- **Then:** I see the drawing, which I can pan and pinch but not draw on, with a note that it is drawn on the iPad

---

### User Story 348:

- **Summary:** Many boards, as a list
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5), a delete during the first upload in [8625cd8](https://github.com/idvorkin/context-grabber/commit/8625cd8); verified by host tests (`BoardIndexTests`: names, newest first, deletes) and the simulator (`just native-test-sim`: the boards open from the hook); the rows, and Delete offered on another device's board, in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73), verified on the iPhone simulator by `WhiteboardRowDeleteUITests`; the rows on the iPad not yet seen

#### Use Case:
- **As someone** who sketches a different idea each time
- **I want to** keep each board, see them as a list and start a new one
- **so that** a new idea never draws over an old one

#### Acceptance Criteria:
- **Scenario:** The boards
- **Given:** I drew one board this morning, and one before the list existed
- **When:** I open the Whiteboard and tap + New board, draw, and go back
- **Then:** the list shows three rows, newest first, each with its picture, name and when it changed; an empty new board left without a stroke leaves no row

- **Scenario:** Rename and delete
- **Given:** a row for a board this device drew
- **When:** I long-press it and rename it, then long-press it again, tap Delete and confirm
- **Then:** the row takes the new name, then goes, and the board leaves every device and doesn't come back; a row drawn on another device offers Delete (story 396) but not Rename

### User Story 349:

- **Summary:** Larry takes a turn on the board
- **Status:** first implemented as a call that waited for him in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to the chat path, no waiting, in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b) (Igor, 2026-11-02); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: Larry's turn brings his marks with no further tap) against the fake Cockpit; the real Larry's answer on the iPad not yet tried; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** working an idea out on the board
- **I want to** hand Larry the Pencil for a turn
- **so that** he answers in marks on my drawing, not only in words somewhere else

#### Acceptance Criteria:
- **Scenario:** Larry answers on the board
- **Given:** the board has a drawing
- **When:** I tap *Larry's turn* and carry on
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) until he answers (story 662), with no spinner, and the Pencil keeps drawing. When he answers, faint blue shapes and a line from him appear with no tap, nothing on the board changes until I keep one, Chat has a thread named after the board with the picture and his words, and the board's next turn goes to it

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
- **Status:** app side implemented on this branch; `WhiteboardTurnUITests.testAFingerTapOffAGhostDismissesItAndOnOneKeepsIt` verified on the simulator by `WhiteboardTurnUITests` (an old-canvas test, dropped 2026-11-07; on paper `WhiteboardPaperGhostsUITests.testAGhostShowsOnThePaperAndATapKeepsIt` and `testATapOffDismissesLeavesNoDotAndAFingerDrawsAgain` hold it); an iPhone and an iPad with no Pencil not yet tried. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first and Larry's only once his are all that's left (stories 663, 664)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a finger, on an iPad with no Pencil (an iPhone only looks since story 746)
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** tapping a suggestion doesn't draw a dot and lose it

#### Acceptance Criteria:
- **Scenario:** A finger tap while ghosts show
- **Given:** a finger draws on this device and ghosts are showing
- **When:** I tap a ghost
- **Then:** it becomes ink and no dot is drawn; once no ghost is left, or after a tap off them that dismisses them, my finger draws again

---

### User Story 663:

- **Summary:** A stray tap leaves Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (`WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on a board where Claude and Larry have both drawn back
- **I want to** dismiss only Claude's ghosts when I tap off them
- **so that** one stray tap can't lose Larry's marks, which can't come back

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with both showing
- **Given:** Claude's ghosts and Larry's marks are both showing
- **When:** I tap off them
- **Then:** Claude's are dismissed and Larry's stay

---

### User Story 664:

- **Summary:** A deliberate tap clears Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (`WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has looked at Larry's marks and doesn't want them
- **I want to** dismiss Larry's marks with a tap off them once they're all that's left
- **so that** clearing his always takes a tap of its own

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with only Larry's left
- **Given:** only Larry's marks are showing
- **When:** I tap off them
- **Then:** his marks are dismissed

---

### User Story 665:

- **Summary:** Turning Ghosts off closes the board's mic
- **Status:** implemented in [9a83d67](https://github.com/idvorkin/context-grabber/commit/9a83d67); verified on the host (`WhiteboardGhostTurnsTests`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad
- **Issues:** [#824](https://github.com/idvorkin/context-grabber/issues/824) (the mic heard words with Ghosts off and dropped them silently)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking to the board who switches the ghosts off mid-sentence
- **I want to** have the mic close and say why
- **so that** I don't keep talking to a mic that reaches no one (story 367)

#### Acceptance Criteria:
- **Scenario:** Ghosts go off while I talk
- **Given:** the board's mic is open
- **When:** I turn Ghosts off
- **Then:** the mic closes, the bar says Ghosts are off so the mic would reach no one, and the words aren't asked about, now or when Ghosts come back

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

### User Story 355:

- **Summary:** Keep Larry's mark
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); the keep itself is checked on the simulator through Claude's ghost (`WhiteboardTurnUITests`), the same path; blue ink on the iPad not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** keep the marks of his I agree with
- **so that** his answer joins my drawing only where I want it

#### Acceptance Criteria:
- **Scenario:** A blue ghost, kept
- **Given:** Larry's faint blue shapes are showing
- **When:** I tap one
- **Then:** it becomes blue ink that my eraser and undo treat like mine

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
- **Given:** Larry's faint blue shapes are showing
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
- **Given:** Claude's orange ghosts and Larry's blue ones are showing
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
- **Given:** Claude's orange ghosts and Larry's blue ones are showing
- **When:** 30 s pass with nothing new from Claude
- **Then:** Claude's fade away, and Larry's stay until I keep or dismiss them

---

### User Story 359:

- **Summary:** Strokes made during a ghost turn get their own turn
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3); its rules verified by host tests (`WhiteboardPacerTests`); not on the simulator, whose fake Cockpit answers with no delay, and the Pencil lift still to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on while Claude thinks
- **I want to** have my newest strokes asked about once the turn on its way lands
- **so that** ghosts keep up with the drawing without turns piling up or arriving mid-stroke

#### Acceptance Criteria:
- **Scenario:** Drawing during a turn
- **Given:** a ghost turn is on its way
- **When:** I draw another stroke and lift the Pencil
- **Then:** a second turn is asked a second after the first lands or after the lift, whichever is later

---

### User Story 360:

- **Summary:** Ask for something on an empty board
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone; real dictation to try on the iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** starting from nothing
- **I want to** tell Claude what to draw before I have drawn anything
- **so that** the board answers a blank page too

#### Acceptance Criteria:
- **Scenario:** Spoken on an empty board
- **Given:** the mic is open and the board is empty
- **When:** I say "draw a circle"
- **Then:** faint orange ghosts appear in the part of the board on screen, and nothing becomes ink

---

### User Story 361:

- **Summary:** Words during a turn wait for the next one
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking faster than Claude answers
- **I want to** have what I say while Claude is answering go next
- **so that** no word falls between two turns

#### Acceptance Criteria:
- **Scenario:** Speaking during a turn
- **Given:** a ghost turn is on its way
- **When:** I say something and stop
- **Then:** those words go with a new turn a second after the first lands

---

### User Story 362:

- **Summary:** Words whose turn did not get through go with the next
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with a Cockpit that is sometimes away
- **I want to** have my words survive a turn that fails
- **so that** I don't have to say them again

#### Acceptance Criteria:
- **Scenario:** A turn that did not get through
- **Given:** I said "draw a box" and its turn was skipped, refused or never answered
- **When:** the next turn is asked
- **Then:** it carries "draw a box" ahead of anything I said since

---

### User Story 363:

- **Summary:** A call has the microphone
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation and a call
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** on a call with Larry
- **I want to** be told why the board's mic won't open
- **so that** a dead button doesn't leave me guessing

#### Acceptance Criteria:
- **Scenario:** Tapping the mic during a call
- **Given:** a call with Larry is live
- **When:** I tap the board's mic
- **Then:** the mic stays closed and the bar shows a copyable problem saying the call is using the microphone

---

### User Story 364:

- **Summary:** A call takes the mic
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation and a call
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who gets on a call while drawing
- **I want to** have the board's mic let go
- **so that** Larry can hear me

#### Acceptance Criteria:
- **Scenario:** A call starting
- **Given:** the board's mic is open
- **When:** a call with Larry starts
- **Then:** the board's mic stops, and words not yet sent still go

---

### User Story 365:

- **Summary:** Leaving stops the mic
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** done with the board
- **I want to** have the mic close when I go
- **so that** the app never listens to a board I left

#### Acceptance Criteria:
- **Scenario:** Leaving the board
- **Given:** the board's mic is open
- **When:** I close the board or the app goes to the background
- **Then:** the mic stops, and words not yet sent still go

---

### User Story 366:

- **Summary:** See what the mic heard
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking with my eyes on the drawing
- **I want to** glance at the words heard
- **so that** I know the mic got me right

#### Acceptance Criteria:
- **Scenario:** Words in the bar
- **Given:** the board's mic is open
- **When:** I speak
- **Then:** the bar shows *Listening…* until the first words, then the last words heard; a new session starts at *Listening…* again

---

### User Story 367:

- **Summary:** Ghosts off holds for speech too
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and since bead `context-grabber-y8r` by the host alone (`WhiteboardGhostTurnsTests`); real dictation to try on the iPad. Since [9a83d67](https://github.com/idvorkin/context-grabber/commit/9a83d67) (#824) the mic doesn't open with Ghosts off, so the say hook no longer stands in for it here: verified on the host (`WhiteboardGhostTurnsTests`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605), [#824](https://github.com/idvorkin/context-grabber/issues/824) (the mic heard words with Ghosts off and dropped them silently)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who switched the ghosts off
- **I want to** have talking ask nothing either
- **so that** the switch means what it says (story 351)

#### Acceptance Criteria:
- **Scenario:** Speaking with Ghosts off
- **Given:** Ghosts are off
- **When:** I tap the board's mic
- **Then:** it doesn't open, and the bar says Ghosts are off so the mic would reach no one; nothing is asked, no ghost appears, and nothing is sent when Ghosts come back

---

### User Story 368:

- **Summary:** A mic that cannot start says why
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation, with the permission off
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** whose microphone permission is off
- **I want to** see why the mic did not open
- **so that** I can fix it, or send the reason on

#### Acceptance Criteria:
- **Scenario:** The mic refused
- **Given:** the app has no permission to use the microphone or speech recognition
- **When:** I tap the board's mic
- **Then:** the bar shows a copyable problem naming the permission and the state behind it

---

### User Story 369:

- **Summary:** A report takes the mic
- **Status:** implemented on this branch in the review round after [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation and a shake (the simulator has no dictation to hear)
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who shakes to report a problem while talking to the board
- **I want to** have the board's mic stop when the report opens
- **so that** words meant for the report never go to the Cockpit as a request for ghosts

#### Acceptance Criteria:
- **Scenario:** A shake report opens
- **Given:** the board's mic is open
- **When:** I shake and the report opens
- **Then:** the board's mic stops, what I dictate into the report doesn't reach the Cockpit, and the mic stays closed until I tap it again

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
- **Given:** a ghost is showing, Claude's in orange or Larry's in blue
- **When:** I look at it
- **Then:** it is a solid faint line with round ends, as wide as a kept stroke, and a label shows the outlines of its letters

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

### User Story 373:

- **Summary:** A Cockpit that answers all at once still brings its marks
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by a host test (`WhiteboardStreamTests`: a plain answer) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a Cockpit that doesn't stream still brings its ghost); since bead `context-grabber-5eq` that check is a host test (`WhiteboardGhostTurnsTests`: a plain answer lands no mark while it's read and all of it at the end)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** get his marks from a Cockpit that doesn't stream
- **so that** the board doesn't depend on which Cockpit answers

#### Acceptance Criteria:
- **Scenario:** A Cockpit that answers all at once
- **Given:** the Cockpit does not stream
- **When:** its answer comes
- **Then:** the marks appear together and everything else works as before

---

### User Story 374:

- **Summary:** An answer cut off after a mark is no failure
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: a broken stream after a mark, the Cockpit's error line after a mark); a real broken stream and the 10 s are still to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** keep the marks that made it when an answer stops early
- **so that** a cut-off answer still gives me what he had started

#### Acceptance Criteria:
- **Scenario:** Cut off part way
- **Given:** at least one mark has arrived
- **When:** the answer breaks off or the turn's 10 s run out
- **Then:** the marks already there stay and the bar says nothing about the Cockpit

---

### User Story 375:

- **Summary:** An answer cut off before any mark says so
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: a broken stream before a mark, the Cockpit's error line with no marks); a real broken stream and the 10 s are still to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** be told when no mark came
- **so that** I know the Cockpit isn't answering rather than wondering about Claude

#### Acceptance Criteria:
- **Scenario:** Cut off before anything
- **Given:** no mark has arrived
- **When:** the answer breaks off or the turn's 10 s run out
- **Then:** no ghost appears and the bar says *Ghosts: the Cockpit isn't answering*

---

### User Story 376:

- **Summary:** A turn sent away shows no more marks
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); not covered by a test; to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** have a dismissal stop the marks still on their way
- **so that** what I sent away doesn't come back

#### Acceptance Criteria:
- **Scenario:** Sent away part way
- **Given:** marks are arriving
- **When:** I tap off them or turn Ghosts off
- **Then:** they go and no more of that turn's marks appear

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

### User Story 378:

- **Summary:** Choose the board's colour
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the menu, the colour on the canvas and the colour still there on reopening verified on the simulator by `WhiteboardTurnUITests` (from the screen's pixels and the button tree); the other boards keeping their colours not covered by a test; the Pencil's tool picker after the menu to judge on the iPad
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who looks at a board for a long time
- **I want to** choose its background from a few colours, and have it remember
- **so that** the board is pleasant to draw on, and I can tell one idea from another

#### Acceptance Criteria:
- **Scenario:** A colour for this board
- **Given:** a board of mine is open
- **When:** I open the Board menu in the bar, choose Cream, draw, go back and open the board again
- **Then:** the board is cream both times, and the other boards haven't changed

---

### User Story 379:

- **Summary:** The colour goes with the board
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the merge carrying the colour verified by host tests (`BoardIndexTests`); the colour on the list's row, which replaced the card in [a8b2730](https://github.com/idvorkin/context-grabber/commit/a8b2730), not covered by a test and not yet seen; iCloud and the look-only view on the phone not yet seen, as the simulator has no iCloud account and no board from another device
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who looks at the iPad's boards on the phone
- **I want to** see them in the colour I chose
- **so that** a board looks like the same board everywhere

#### Acceptance Criteria:
- **Scenario:** On the phone
- **Given:** I chose Sage for a board on the iPad and closed it
- **When:** I open the Whiteboard on the phone and tap that board's row
- **Then:** the row in the list and the look-only board are sage, in the phone's own mode, and the phone offers no way to change it

---

### User Story 380:

- **Summary:** Larry's turn doesn't hold up the drawing
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); the turn's message and the bar verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`) against the fake Cockpit; drawing with the Pencil while he has the board to try on the iPad; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a Larry who takes minutes to answer
- **I want to** hand him the board and keep going
- **so that** his turn is a conversation in the background, not a wait

#### Acceptance Criteria:
- **Scenario:** Hand him the board
- **Given:** I have drawn on the board
- **When:** I tap *Larry's turn*
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) as soon as the picture is taken (story 662), with no spinner, and I can keep drawing and, once that picture has gone, tap it again for a newer one

---

### User Story 381:

- **Summary:** A picture for Larry says where it sits on the board
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); the three fields verified by host tests (`WhiteboardMarksTests`), including through the outbox; *Larry's turn* carrying them on the simulator (the fake Cockpit reads the frame to place his marks); *Send to Larry* carrying them to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** whose board is far bigger than any one picture of it
- **I want to** have every picture carry its board, its id and its place
- **so that** Larry's marks go on what he saw, whichever way he got it

#### Acceptance Criteria:
- **Scenario:** Either button
- **Given:** I have drawn away from the middle of the board
- **When:** I tap *Larry's turn* or *Send to Larry*
- **Then:** the picture reaches the board's thread with the board's id, a new picture id, and where the picture sits on the board; his marks answering either kind come back to the board

---

### User Story 382:

- **Summary:** Larry's marks arrive on their own, where the picture was
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); where it lands verified by host tests (`WhiteboardMarksTests`); arriving with no tap and either format by the simulator (`WhiteboardTurnUITests`) against the fake Cockpit, read from the board's note, as the canvas isn't in the accessibility tree; marks landing on what he saw, seen by eye, on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with the board open while Larry thinks
- **I want to** see his marks and his words appear when he has them, even if I didn't ask
- **so that** we are drawing together, in his own time

#### Acceptance Criteria:
- **Scenario:** He answers while I've moved on
- **Given:** I handed Larry the board, then drew elsewhere and panned away
- **When:** he posts a row of marks on the thread
- **Then:** within a few seconds, with no tap, they show as blue ghosts on what the picture showed, not where I am now, and his text shows in the bar as his line

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

### User Story 384:

- **Summary:** The looking stops when I leave
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); stopping on close and in the background not verified by a test; to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who leaves a board with a thread
- **I want to** have the looking stop when I'm not there
- **so that** it costs nothing

#### Acceptance Criteria:
- **Scenario:** Closed or backgrounded
- **Given:** a board with a thread is open
- **When:** I close it or the app goes to the background
- **Then:** the looking stops, and starts again when the app comes back to an open board

---

### User Story 385:

- **Summary:** One board, one thread
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b), and a Send recording the thread as it lands, closed board or not, in the review fixes on this branch; verified by host tests (`WhiteboardMarksTests`: pictures queued with no thread share the one the first starts, a lost thread frees the board); the buttons holding each other back, and a Send's thread on the iPad, not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who sends a board to Larry more than once
- **I want to** have every picture of it go to one thread
- **so that** the conversation about a board is in one place and his marks in answer come back to it

#### Acceptance Criteria:
- **Scenario:** A later send
- **Given:** I sent this board to Larry, went back and read the thread in Chat
- **When:** I open the board, draw more and tap Send to Larry
- **Then:** the new picture goes to that thread, not a new one

---

### User Story 386:

- **Summary:** Larry draws unprompted
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by the simulator (`WhiteboardTurnUITests`) against the fake Cockpit, read from the board's note
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with Larry's marks on the board
- **I want to** see his next marks take their place
- **so that** the board shows where he has got to, not every draft

#### Acceptance Criteria:
- **Scenario:** He draws unprompted
- **Given:** his marks are showing and I asked for nothing
- **When:** he posts another row of marks
- **Then:** the new ones replace his unkept ones; Claude's stay

---

### User Story 387:

- **Summary:** Marks with nowhere to go
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b), the board opening on such a row in the review fixes on this branch; verified by host tests (`WhiteboardMarksTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at Larry's marks
- **I want to** have marks that don't say where they go left off the board
- **so that** nothing lands in the wrong place, and the log says why it's missing

#### Acceptance Criteria:
- **Scenario:** Marks with no place
- **Given:** a row of his, his newest with marks, has marks but no frame
- **When:** the app sees it, on a look at the thread or as the board opens
- **Then:** nothing is drawn and nothing is replaced, no older row stands in for it, and the log names the row

---

### User Story 388:

- **Summary:** A set I've dealt with stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: dismissed, not back on the next look or the next open); keeping one from a row then reopening is host-tested only
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

### User Story 389:

- **Summary:** Looking for his marks fails quietly
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b), a thread the Cockpit no longer has and the shorter wait in the review fixes on this branch; not verified by a test; to try on the iPad, away from the tailnet
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on a board that may be off the tailnet
- **I want to** have the looking stay quiet when it fails
- **so that** it never nags

#### Acceptance Criteria:
- **Scenario:** The Cockpit is away
- **Given:** a board with a thread is open
- **When:** the Cockpit stops answering
- **Then:** the bar says quietly that his marks aren't coming, no error box appears, the log has one error, and the bar clears by itself when the Cockpit answers

---

### User Story 390:

- **Summary:** Paste text onto the board as ink
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); the layout verified by host tests (`WhiteboardPasteTests`); on the simulator (`WhiteboardPasteUITests`), ⌘V from a real clipboard with no prompt, and through a launch hook each line and Claude's pause; the ink's look checked by eye at its pen width in dark mode. Still to try on the iPad: the Paste button itself (XCUITest's taps never fire the system control) and that it shows no prompt, zoomed-out and zoomed-in pastes, sync to the other device
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** thinking on the board with words already on my clipboard
- **I want to** paste them with the bar's Paste button or ⌘V
- **so that** they sit on the board as ink and travel with its picture to Larry and Claude

#### Acceptance Criteria:
- **Scenario:** A paste becomes ink
- **Given:** a board I can draw on is open and the clipboard holds two lines of text
- **When:** I tap Paste or press ⌘V
- **Then:** both lines appear as thin outlined ink in the middle of what's on screen with no *Allow Paste?* prompt, the board saves it, and about a second later Claude's ghosts come

---

### User Story 391:

- **Summary:** One undo takes a whole paste back
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); verified on the simulator (`WhiteboardPasteUITests`: one ⌘Z after a ⌘V)
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** who pasted the wrong thing
- **I want to** undo it in one go
- **so that** I never pick a paste off the board letter by letter

#### Acceptance Criteria:
- **Scenario:** Taking it back
- **Given:** I have just pasted
- **When:** I undo
- **Then:** the whole paste goes at once

---

### User Story 392:

- **Summary:** A paste that is too long is cut, and the bar says so
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); both caps verified by host tests (`WhiteboardPasteTests`); the 500-character cut and its note on the simulator (`WhiteboardPasteUITests`, through a launch hook); since bead `context-grabber-y8r` the note's words are a host test too (`WhiteboardPasteTests`), and the UI case that drew 500 strokes is gone
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** pasting more than the board should carry
- **I want to** have the first part land and be told how much
- **so that** I know what was left off

#### Acceptance Criteria:
- **Scenario:** Too long
- **Given:** the clipboard holds more than 500 characters or wraps past 40 lines
- **When:** I paste
- **Then:** the first part lands and the bar says how much of how much

---

### User Story 393:

- **Summary:** Text that cannot be drawn leaves the board alone
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); no outline means no ink verified by host tests (`WhiteboardPasteTests`); the note and the untouched board on the simulator (`WhiteboardPasteUITests`, through a launch hook); which note, a host test since bead `context-grabber-y8r`
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** pasting only emoji
- **I want to** be told nothing could be drawn
- **so that** an unchanged board doesn't look like a broken paste

#### Acceptance Criteria:
- **Scenario:** Nothing to draw
- **Given:** the clipboard holds only emoji
- **When:** I paste
- **Then:** the board doesn't change and the bar says nothing in it can be drawn

---

### User Story 394:

- **Summary:** Nothing to paste, or a board that is not mine
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); not verified by a test; to try on the iPad: the dimmed Paste, no Paste on a look-only board, ⌘V doing nothing on either
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** looking at a board with nothing to paste, or one another device draws
- **I want to** have Paste and ⌘V stay out of the way
- **so that** nothing lands where it can't or shouldn't

#### Acceptance Criteria:
- **Scenario:** No paste to make
- **Given:** the clipboard holds neither text nor copied strokes, or the board is look-only
- **When:** I look at the bar or press ⌘V
- **Then:** Paste is dimmed (or absent on a look-only board) and ⌘V does nothing

---

### User Story 395:

- **Summary:** Strokes I copied still paste
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented on this branch; not verified by a test (on the simulator, PencilKit's canvas was seen to have its own paste); to try on the iPad with a hardware keyboard
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** moving ink around with the lasso
- **I want to** paste the strokes I copied with ⌘V
- **so that** pasting text doesn't cost me the system's paste of ink

#### Acceptance Criteria:
- **Scenario:** Copied strokes
- **Given:** a board I can draw on is open and the clipboard holds strokes copied with the lasso and no text
- **When:** I press ⌘V
- **Then:** the strokes land the way the system always pastes them, and the bar's Paste stays dimmed

---

### User Story 396:

- **Summary:** Delete a board from any device, with a swipe
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); the list, the swipe, the confirmation and that the row stays gone verified on the iPhone simulator by `WhiteboardRowDeleteUITests`; the merge by host tests (`BoardIndexTests`); on real iCloud, and the rows on the iPad, not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** delete a board with a swipe
- **so that** the list holds only what I still want, and I don't have to go find the iPad to clean it

#### Acceptance Criteria:
- **Scenario:** Swipe on the phone, on a board drawn on the iPad
- **Given:** the phone lists a board drawn on the iPad
- **When:** I swipe its row left, tap Delete and confirm
- **Then:** the row goes and doesn't come back when the list syncs

---

### User Story 397:

- **Summary:** The device that drew a deleted board follows
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); the merge verified by host tests (`BoardIndexTests`); the delete crossing iCloud between the iPhone and the iPad not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** have a delete on the phone reach the iPad, even one that was off
- **so that** a deleted board doesn't linger on the device that drew it

#### Acceptance Criteria:
- **Scenario:** The iPad follows
- **Given:** I deleted an iPad board on the phone, with the iPad off
- **When:** the iPad's list next syncs
- **Then:** the board is gone from the iPad too

---

### User Story 398:

- **Summary:** New ink wins over a delete
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73), the open board's guard held until its last save on this branch; the merge verified by host tests (`BoardIndexTests`); on real iCloud between the iPhone and the iPad not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** keep what I drew when a delete crosses it
- **so that** a delete from another device never costs me ink it hadn't seen

#### Acceptance Criteria:
- **Scenario:** New ink wins
- **Given:** the iPad has the board open, or has drawn on it and not reached iCloud yet, when I delete it on the phone
- **When:** the iPad syncs
- **Then:** nothing it drew is lost: the board goes up again and returns to both devices

---

### User Story 399:

- **Summary:** A picture of a deleted board says so
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); verified on the iPhone simulator by `WhiteboardRowDeleteUITests`
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** be told when a picture or link names a board that has gone
- **so that** a jump that can't land explains itself and I can copy why

#### Acceptance Criteria:
- **Scenario:** A picture of a deleted board
- **Given:** a chat picture or a link names a deleted board
- **When:** I jump to it
- **Then:** I get a copyable problem saying it was deleted or hasn't arrived

---

### User Story 400:

- **Summary:** No delete means no loss
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); the merge verified by host tests (`BoardIndexTests`); a real account switch not yet tried
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** keep this device's boards whatever iCloud's list says
- **so that** only a delete I asked for ever takes a board away

#### Acceptance Criteria:
- **Scenario:** No delete means no loss
- **Given:** this device signs into a different iCloud account, or iCloud's list comes back without its boards
- **When:** the list syncs
- **Then:** the boards this device drew stay, because only an asked-for delete removes them

---

### User Story 401:

- **Summary:** A late delete keeps ink it never saw
- **Issues:** #613
- **Status:** implemented on this branch; the merge verified by host tests (`BoardIndexTests`); on real iCloud between the iPhone and the iPad not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** have a delete cover only what I could see when I made it
- **so that** a delete made offline can't erase what I drew in the days before it arrived

#### Acceptance Criteria:
- **Scenario:** A delete arrives after newer ink
- **Given:** I deleted an iPad board on the phone with no network, and the iPad then drew on it and that reached iCloud
- **When:** the phone gets back online and both devices sync
- **Then:** the board and its new ink return to both devices

---

### User Story 402:

- **Summary:** The Board menu on an iPhone's width
- **Status:** implemented in [6d9f24f](https://github.com/idvorkin/context-grabber/commit/6d9f24f); the top bar with nothing under *More* verified on the simulator by `WhiteboardTurnUITests` (from the button tree); the menu's place at the bottom has not been looked at by eye
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** drawing on a narrow screen
- **I want to** have the Board menu at the bottom of the screen
- **so that** Larry's turn and Send stay where I can reach them

#### Acceptance Criteria:
- **Scenario:** On an iPhone's width
- **Given:** a board of mine is open on a narrow screen
- **When:** I look for the Board menu
- **Then:** it is at the bottom of the screen, and Larry's turn and Send are still in the top bar, not under *More*

---

### User Story 403:

- **Summary:** The colour follows light and dark mode
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the colour on the canvas in both modes verified on the simulator by `WhiteboardTurnUITests` (from the screen's pixels; a screenshot of white ink on the deep Cream comes from the run before the menu moved); ink contrast on every colour by host tests (`BoardPaperTests`). On paper, which stays light, its colour staying with the board is `WhiteboardPaperLinesUITests.testRuledLinesStayWithTheBoardUnderTheInk` since bead `context-grabber-y8r`
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** whose iPad changes mode through the day
- **I want to** have a board's colour change with the mode
- **so that** the ink stays easy to read

#### Acceptance Criteria:
- **Scenario:** Light and dark mode
- **Given:** a board is Cream
- **When:** the iPad changes between light and dark mode
- **Then:** the board goes between a pale shade and a deep one, and the ink stays easy to read on both

---

### User Story 404:

- **Summary:** Ghosts show on every colour
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); ghost contrast on every colour verified by host tests (`BoardPaperTests`); ghosts on each colour by eye to judge on the iPad
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who decides which marks to keep
- **I want to** see a ghost as well on a colour as on Plain
- **so that** choosing a colour doesn't hide what Claude and Larry suggest

#### Acceptance Criteria:
- **Scenario:** Ghosts on a colour
- **Given:** a board is any of the colours
- **When:** Claude's orange ghosts and Larry's blue ones show
- **Then:** I can see them about as well as on Plain

---

### User Story 405:

- **Summary:** A colour alone keeps no empty board
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the empty-board rule verified by host tests (`BoardIndexTests`, and `BoardKeepingTests`: a new board closed without a stroke is dropped)
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who tries a colour on a new board and changes their mind
- **I want to** have the board go if I never drew on it
- **so that** the list holds only boards with something on them

#### Acceptance Criteria:
- **Scenario:** An empty board
- **Given:** I opened a new board and chose a colour
- **When:** I close it without a stroke
- **Then:** it leaves no row

---

### User Story 406:

- **Summary:** Claude and Larry see dark ink on white
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the pictures to Claude and Larry are left as they were, so stay dark on white; not covered by a test
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who colours a board for my own eyes
- **I want to** have Claude and Larry get the same picture on any colour
- **so that** a colour never changes how they read the board

#### Acceptance Criteria:
- **Scenario:** What Claude and Larry see
- **Given:** a board is Sage and the iPad is in dark mode
- **When:** Claude takes a turn or I send the board to Larry
- **Then:** the picture they get is dark ink on white

---

### User Story 407:

- **Summary:** Faint grid lines on the board
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: the lines appear in the screenshot's pixels; by eye in dark mode, faint and even) and the smoke (`grid_on` from the hook); how faint they look beside real ink and how drawing feels at 120 Hz on a big board are not verified, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** turn on faint grid lines that move with the board
- **so that** I can keep things lined up and to scale

#### Acceptance Criteria:
- **Scenario:** Grid on
- **Given:** a board I draw on, its grid off
- **When:** I choose Grid lines in the Board menu
- **Then:** faint lines show, too faint to break up the ink they cross

---

### User Story 408:

- **Summary:** Turning the grid off
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: the screenshot's pixels return to what they were)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** turn the grid back off
- **so that** the board is only my ink again

#### Acceptance Criteria:
- **Scenario:** Grid off
- **Given:** a board with its grid on
- **When:** I choose Grid lines in the Board menu again
- **Then:** the lines are gone and the ink is as it was

---

### User Story 409:

- **Summary:** The grid stays with its board
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: a reopened board draws its lines, or none, from the screenshot's pixels)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have a board remember whether its grid is on
- **so that** I don't set it again each time

#### Acceptance Criteria:
- **Scenario:** Reopened
- **Given:** I left a board with its grid on or off
- **When:** I open it again on this device
- **Then:** it opens the way I left it

---

### User Story 410:

- **Summary:** A new board has no grid
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: the Board menu's label on a new board, with another board's grid on)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** start each new board without a grid
- **so that** a grid is something I ask for on the board I want it on

#### Acceptance Criteria:
- **Scenario:** New board
- **Given:** another board has its grid on
- **When:** I make a new board
- **Then:** its grid is off

---

### User Story 411:

- **Summary:** The eraser leaves the grid alone
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the lines aren't strokes; not verified by a test, and erasing across a line is for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the eraser ignore the grid
- **so that** I can't erase it by accident

#### Acceptance Criteria:
- **Scenario:** Eraser
- **Given:** a board with its grid on
- **When:** I erase across a line
- **Then:** the line stays

---

### User Story 412:

- **Summary:** Larry's picture leaves the grid out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the picture is drawn from the ink alone; not verified by a test, so a picture sent with the grid on is for the iPad's eye
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** leave the grid out of the board I send to Larry
- **so that** what he says answers my drawing and not the squares

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** a board with its grid on
- **When:** I send it to Larry
- **Then:** the picture shows ink only

---

### User Story 413:

- **Summary:** The grid pans with the board
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by host tests (`WhiteboardFrameTests`: the lines cover the view wherever it is, and hold still until it crosses one); a real pan is not verified by a test, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the lines move with the board when I pan
- **so that** they stay put against my drawing

#### Acceptance Criteria:
- **Scenario:** Panning
- **Given:** a board with its grid on
- **When:** I pan the board
- **Then:** the lines keep their place on the drawing and still cover the screen

---

### User Story 414:

- **Summary:** The grid spreads as I pinch in
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by host tests (`WhiteboardFrameTests`: the spacing at 3×); a real pinch is not verified by a test, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the lines zoom with the board when I pinch in
- **so that** they stay put against the detail I'm drawing

#### Acceptance Criteria:
- **Scenario:** Pinching in
- **Given:** a board with its grid on
- **When:** I pinch in
- **Then:** the lines spread apart with the drawing

---

### User Story 415:

- **Summary:** The grid thins as I pinch out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by host tests (`WhiteboardFrameTests`: worked spacings down to 0.1×, a thinned grid's lines on the coarser step, the line count at every zoom); a real pinch is not verified by a test, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have fewer lines the further I pinch out
- **so that** they never crowd together over the whole drawing

#### Acceptance Criteria:
- **Scenario:** Pinching out
- **Given:** a board with its grid on
- **When:** I pinch out until the lines would crowd
- **Then:** every second line goes and the lines left are ones that were already there

---

### User Story 416:

- **Summary:** The lasso leaves the grid alone
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the lines aren't strokes; not verified by a test, and lassoing across a line is for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the lasso ignore the grid
- **so that** I can't move it by accident

#### Acceptance Criteria:
- **Scenario:** Lasso
- **Given:** a board with its grid on
- **When:** I lasso across a line
- **Then:** nothing is selected for the line

---

### User Story 417:

- **Summary:** A turn's picture leaves the grid out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the picture is drawn from the ink alone; not verified by a test, so a turn with the grid on is for the iPad's eye
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** leave the grid out of what a turn sees
- **so that** the marks that come back answer my drawing and aren't fitted to the squares

#### Acceptance Criteria:
- **Scenario:** A turn
- **Given:** a board with its grid on
- **When:** a turn asks for marks on the board
- **Then:** the picture it sends shows ink only

---

### User Story 418:

- **Summary:** The board's card leaves the grid out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the card is drawn from the ink alone; not verified by a test, so a card with the grid on is for the iPad's eye
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** with many boards
- **I want to** see only my ink on a board's card
- **so that** I recognise the board by what I drew

#### Acceptance Criteria:
- **Scenario:** The card
- **Given:** a board with its grid on and ink on it
- **When:** I go back to the list of boards
- **Then:** its card shows ink only

---

### User Story 419:

- **Summary:** The board's strokes go to Larry on his turn
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), tests fixed in [f79d283](https://github.com/idvorkin/context-grabber/commit/f79d283), conversion and tests changed in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by host tests (`WhiteboardStrokesTests`: the stable id, the colour and tool words, thinning, the request's body, the answer, the width following a lasso's resize) and the whiteboard UI tests on the simulator (18 passed, before [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48)); the width's scaling came in the review fix after [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48) and is host-tested only; a real send from the iPad against the Cockpit is owed (the Cockpit's side is idvorkin-ai-tools/cockpit#91)
- **Why:** Igor, 2026-11-03, on a tall board that reached Larry as a 248x2048 px sliver: "This sounds like a bug in your implementation. Can we send strokes instead?"
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** writing pages of notes down one tall board
- **I want to** have Larry get every stroke, not a thumbnail
- **so that** he reads every word however tall the board is, and knows which lines are new

#### Acceptance Criteria:
- **Scenario:** Larry's turn
- **Given:** a board with ink on it
- **When:** I tap *Larry's turn*
- **Then:** before the picture, every stroke on the board reaches the Cockpit in board points with its time, colour, width, tool and a stable id, under the picture's id

---

### User Story 420:

- **Summary:** The picture for Larry frames the drawing at a readable size
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests (`WhiteboardFrameTests`: the pixel budget, the Nov 2 column at 712 x 5892 px instead of 248 x 2048, the long side capped at 8,000) and the simulator compile; how a 5,900-pixel-tall picture looks in Chat is owed on the iPad
- **Why:** Igor, 2026-11-03: "And maybe zoom into the pages".
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose boards are tall and narrow
- **I want to** have the picture spend its pixels on my drawing's own shape
- **so that** the handwriting stays legible in the picture too, not only in the strokes

#### Acceptance Criteria:
- **Scenario:** A tall column of notes
- **Given:** a drawing 1,179 by 9,759 board points
- **When:** a picture of it goes to Larry
- **Then:** it is about 712 by 5,892 pixels (30-point handwriting at 18 px), not 248 by 2,048

---

### User Story 421:

- **Summary:** Larry's turn goes whatever the Cockpit says to the strokes
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests of the answer and its log fields (`WhiteboardStrokesTests`) and the simulator compile; no test runs the turn against a refusal, since the fake Cockpit accepts every strokes post, so a turn from the iPad before cockpit#91 merges, when the route doesn't exist, is owed
- **Why:** Igor, 2026-11-03: the picture is the fallback, including until the Cockpit has the route
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry
- **I want to** have the picture reach him even when the strokes don't
- **so that** a Cockpit without the strokes route never costs me a turn

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses the strokes on Larry's turn
- **Given:** the strokes route answering an error
- **When:** I tap *Larry's turn*
- **Then:** the picture still goes, with only the session log saying what became of the strokes

---

### User Story 422:

- **Summary:** A big square sketch's picture stays as it was
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests (`WhiteboardFrameTests`: a square board unchanged at 2048 px) and the simulator compile
- **Why:** the pixel budget of story 420 is for tall boards; a square one already spent it well
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** sketching on a square part of a big board
- **I want to** have its picture stay as sharp as before
- **so that** framing tall boards costs ordinary sketches nothing

#### Acceptance Criteria:
- **Scenario:** A big square sketch
- **Given:** a drawing about 2,000 points on a side
- **When:** its picture is made
- **Then:** it is 2,048 pixels on a side, as before

---

### User Story 423:

- **Summary:** Rubbed-out ink doesn't go to Larry as strokes
- **Status:** implemented in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); PencilKit's visible ranges checked with a Mac probe of masked strokes (whole range without a mask, the visible part with one, nothing when all of it is masked), and the conversion compiled for the simulator; whether a real rub with the pixel eraser reaches the Cockpit as this is owed on the iPad
- **Why:** the picture shows the ink gone, so the strokes have to agree, or Larry reads sharp words Igor erased
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** correcting a word with the pixel eraser
- **I want to** have the part I rubbed out gone from what Larry reads
- **so that** he never reads what I erased, and knows it was erased

#### Acceptance Criteria:
- **Scenario:** Part of a stroke rubbed out
- **Given:** a stroke on the board with part of it rubbed out by the pixel eraser
- **When:** the board's strokes next go to the Cockpit
- **Then:** they carry only the part still visible, under new ids, so the Cockpit counts the old stroke as erased

---

### User Story 424:

- **Summary:** The board's strokes go with Send to Larry
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), tests fixed in [f79d283](https://github.com/idvorkin/context-grabber/commit/f79d283), changed in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by host tests (`WhiteboardStrokesTests`: the strokes saved beside the picture and posted before the message, under the picture's id); a real send from the iPad against the Cockpit is owed (idvorkin-ai-tools/cockpit#91)
- **Why:** split from story 419: a Send goes through the outbox, a different road from Larry's turn
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** sending a tall board from the iPad
- **I want to** have the strokes go with a Send as they do with a turn
- **so that** Larry reads a board I sent as sharply as one I handed him

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** a board with ink on it and a network
- **When:** I tap *Send to Larry*
- **Then:** every stroke on the board reaches the Cockpit under the picture's id, before the message that names the picture

---

### User Story 425:

- **Summary:** Claude's ghost turn gets the same framing
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); the turn uses the same framing as story 420, whose arithmetic the host tests pin, and the simulator compile; how a turn answers a picture that tall is owed on the iPad
- **Why:** split from story 420: Claude reads the board's handwriting from the picture alone
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing along with Claude on a tall board
- **I want to** have Claude's picture spend its pixels on my drawing's own shape
- **so that** Claude can read the handwriting it answers

#### Acceptance Criteria:
- **Scenario:** A tall column of notes on a ghost turn
- **Given:** a drawing 1,179 by 9,759 board points
- **When:** Claude's ghost turn takes its picture
- **Then:** it is about 712 by 5,892 pixels, not 248 by 2,048

---

### User Story 426:

- **Summary:** Send to Larry goes whatever the Cockpit says to the strokes
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), not taken for an unreadable item since [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by host tests (`WhiteboardStrokesTests`: a 500 to the strokes still sends the picture and logs the reason); a send from the iPad before cockpit#91 merges is owed
- **Why:** split from story 421: the outbox has its own send, and the same promise
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** sending a board to Larry
- **I want to** have the picture reach him even when the strokes don't
- **so that** a Cockpit without the strokes route never costs me a send

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses the strokes on a Send
- **Given:** the strokes route answering an error
- **When:** *Send to Larry* goes
- **Then:** the picture still goes, with only the session log saying what became of the strokes

---

### User Story 427:

- **Summary:** With no network a Send waits with its strokes beside it
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), the strokes file kept out of the inbox's items in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by a host test (`WhiteboardStrokesTests`: no network leaves the item waiting with its strokes, then upload, strokes and message in order), added in the review fix after [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48)
- **Why:** split from story 421: no network is a separate condition from the route's error
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** sending a board with no signal
- **I want to** have the strokes wait with the picture
- **so that** the board that arrives later is as readable as one sent now

#### Acceptance Criteria:
- **Scenario:** No network on a Send
- **Given:** no network
- **When:** I tap *Send to Larry*
- **Then:** the board waits in the outbox with its strokes beside it, and both go when the network is back

---

### User Story 428:

- **Summary:** With no network Larry's turn says so and nothing waits
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); the simulator compile only: no test runs a turn with no network, so this is owed on the iPad
- **Why:** split from story 421, whose old wording promised this case a send or a wait; a turn has no outbox
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry with no signal
- **I want to** be told the turn didn't go
- **so that** I don't wait for marks that aren't coming

#### Acceptance Criteria:
- **Scenario:** No network on Larry's turn
- **Given:** no network
- **When:** I tap *Larry's turn*
- **Then:** a copyable error says Larry couldn't be reached, and nothing is queued

---

### User Story 429:

- **Summary:** A small sketch's picture is never finer than the screen
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests (`WhiteboardFrameTests`: a small sketch drawn at 2x)
- **Why:** split from story 422: the pixel budget would otherwise blow a small sketch up past what the iPad drew
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** sketching on a small part of a board
- **I want to** have its picture stay at the screen's own sharpness
- **so that** a small sketch doesn't cost a huge picture

#### Acceptance Criteria:
- **Scenario:** A small sketch
- **Given:** a drawing 200 by 100 board points
- **When:** its picture is made
- **Then:** it is drawn at the screen's 2x, 560 by 360 pixels with its margin

---

### User Story 430:

- **Summary:** I can see which page I'm on
- **Status:** not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** scrolling a long board
- **I want to** see a page number
- **so that** I know where I am

#### Acceptance Criteria:
- **Scenario:** Scrolling
- **Given:** a board with three pages of ink
- **When:** I scroll until page 2 is mostly on screen
- **Then:** the corner reads *Page 2 of 3*, stays put while the board moves, and isn't in any picture

---

### User Story 431:

- **Summary:** An old board moves onto pages with nothing lost
- **Status:** not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards drawn before pages
- **I want to** open them on pages as they were
- **so that** the change never costs me a drawing

#### Acceptance Criteria:
- **Scenario:** A board that fits a page
- **Given:** a board from before pages, its ink narrower than a page
- **When:** I open it
- **Then:** it opens on pages with every stroke at its old size and in the same place relative to the others, and Larry's marks still sit beside the ink they were drawn beside

---

### User Story 432:

- **Summary:** A mark past the page edge widens the board
- **Status:** not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** Larry draws back to
- **I want to** see all of a mark drawn past the page's edge
- **so that** nothing he drew is cut off

#### Acceptance Criteria:
- **Scenario:** Past the edge
- **Given:** a page-width board
- **When:** Larry's mark lands past the right edge
- **Then:** the board widens to hold it, nothing is clipped, and my ink doesn't move

---

### User Story 433:

- **Summary:** Larry reads the pages I'm looking at
- **Status:** implemented on paper in [a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315), for Send to Larry and *Larry's turn*; verified on the host (`BoardPicturePagesTests`) and on an iPhone 17 simulator (`testThePictureIsThePageOnScreen`: the frame the fake Cockpit got is page 2's alone, and Larry's marks came back to it). Whether Larry reads the writing well, and how it feels on the iPad, haven't been checked; the old canvas still sends the whole board; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** showing Larry part of a long board
- **I want to** send what's on my screen
- **so that** he reads my writing at a readable size, not a sliver of the whole column

#### Acceptance Criteria:
- **Scenario:** The middle page
- **Given:** three pages of ink with page 2 on screen
- **When:** I tap Send to Larry
- **Then:** the picture shows page 2 with my writing legible, and Larry's marks in reply land on page 2

---

### User Story 434:

- **Summary:** Ruled lines, like notebook paper
- **Status:** implemented on paper in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`). 40 points is provisional until Igor has seen it; the old canvas has no ruled lines; asks: [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#678](https://github.com/idvorkin/context-grabber/issues/678)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who writes notes on the board
- **I want to** turn on faint ruled lines
- **so that** my writing has lines to sit on

#### Acceptance Criteria:
- **Scenario:** Choosing them
- **Given:** a board with no lines
- **When:** I choose Ruled lines in the Board menu
- **Then:** faint horizontal lines appear that move with the board, are in no picture, can't be erased, and are still there when I reopen the board on this device

---

### User Story 435:

- **Summary:** Try a board on paper, temporarily, from its long press
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator on iOS 27 (`WhiteboardTrialOnPaperUITests`: opens on this device's board) and by host tests (`BoardKeepingTests`: offered on this device's boards only); played with on the iPad by Igor, 2026-11-03; temporary: goes when the board moves to PaperKit
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding how a board on PaperKit should work
- **I want to** open a board I drew in a trial on paper
- **so that** I can feel it with my own ink before anything is built on it

#### Acceptance Criteria:
- **Scenario:** A board drawn here, on iOS 27
- **Given:** a board drawn on this device
- **When:** I long-press its row
- **Then:** *Try on paper* is offered and opens the trial

---

### User Story 436:

- **Summary:** Nothing in the trial reaches a real board
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`BoardKeepingTests`: the trial's copy reads the board's ink and writes, moves or removes nothing, and an unreadable board stays where it is), and by construction: the trial is handed a drawing, never the store. Earlier, on an iPad simulator, the boards' files hashed the same across trial runs, and a copy with ink added left no file
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** playing with an unfinished canvas
- **I want to** know nothing I do there can touch my boards
- **so that** I can scribble over the real ink without a second thought

#### Acceptance Criteria:
- **Scenario:** Scribbling and closing
- **Given:** a board with one stroke, open in the trial
- **When:** I draw, erase and undo in the trial and close it
- **Then:** the board still has one stroke, and its picture, its place in the list and its *Changed* time are as they were

---

### User Story 437:

- **Summary:** The trial is a column of pages
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests` and screenshots: tool picker, page lines, page number)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** trying the Notability-like board
- **I want to** see my ink on a column of pages with a page number
- **so that** I can judge the shape before it's built for real

#### Acceptance Criteria:
- **Scenario:** Opening
- **Given:** a board with ink
- **When:** the trial opens
- **Then:** the tool picker, faint page lines, *Page 1 of N* at the corner and a blank page below the last ink all show

---

### User Story 438:

- **Summary:** The trial says what to try, and has the switches to try it
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`: the line, and every switch runs); played with on the iPad by Igor, 2026-11-03; since bead `context-grabber-y8r` the every-switch probe runs only when asked (`TEST_RUNNER_GRABBER_PAPER_PROBES=1`), not in each suite run
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with the iPad in hand and no notes
- **I want to** read one line and find the switches in one menu
- **so that** I don't need instructions to settle the questions

#### Acceptance Criteria:
- **Scenario:** The line
- **Given:** the trial just opened
- **When:** I look under the title
- **Then:** one short line says it's a copy and what to try

---

### User Story 439:

- **Summary:** The trial's log settles the five questions
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`PaperProbeTests`) and the simulator (`WhiteboardTrialOnPaperUITests` and `sim-smoke.sh`, whiteboard). Question 1, what a finger does with a Pencil paired, needs the iPad's log: `just pull-logs`
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who plays on the iPad and reads the answers later
- **I want to** have every touch and its outcome in the log
- **so that** the questions are answered without my having to remember what happened

#### Acceptance Criteria:
- **Scenario:** A finger on the ink
- **Given:** the trial is open
- **When:** I drag a finger across some ink
- **Then:** the log has the touch, whether it panned, selected or moved ink, and each moved stroke's id and how far it went

---

### User Story 520:

- **Summary:** Pinching out stops at the page
- **Status:** not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who zooms out to look at a page
- **I want to** have the pinch stop when the page fits the screen
- **so that** the board never moves off sideways into nothing

#### Acceptance Criteria:
- **Scenario:** Pinching out
- **Given:** I am on a page
- **When:** I pinch out as far as it goes
- **Then:** it stops with the page fitting the screen's width, and the board never moves off sideways into nothing

---

### User Story 521:

- **Summary:** An old board wider than a page keeps its width
- **Status:** not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with an old board drawn wider than a page
- **I want to** keep all of it, at its old size
- **so that** moving onto pages never shrinks or crops my drawing

#### Acceptance Criteria:
- **Scenario:** A board wider than a page
- **Given:** a board from before pages with ink wider than a page
- **When:** I open it
- **Then:** it keeps its own wider width, no stroke scaled, and I can pan sideways only as far as that width

---

### User Story 522:

- **Summary:** Nothing on screen, nothing to send
- **Status:** implemented on paper in [a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315), Send to Larry and *Larry's turn* both disabled; verified on the host (`BoardPicturePagesTests`) and on an iPhone 17 simulator (`testThePictureIsThePageOnScreen`). Not yet checked on the iPad; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a blank page of a long board
- **I want to** see that Send to Larry has nothing to send
- **so that** I never send him an empty picture

#### Acceptance Criteria:
- **Scenario:** Nothing on screen
- **Given:** ink on page 1 and a blank page on screen
- **When:** I look at Send to Larry
- **Then:** it's disabled, because there's nothing on screen to send

---

### User Story 523:

- **Summary:** One kind of lines at a time
- **Status:** implemented on paper in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`); asks: [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** choosing what the paper looks like
- **I want to** have ruled lines replace the grid
- **so that** the two never pile up on one board

#### Acceptance Criteria:
- **Scenario:** One kind at a time
- **Given:** a board with its grid on
- **When:** I choose Ruled lines
- **Then:** the grid goes and the ruled lines show

---

### User Story 524:

- **Summary:** The trial isn't offered on another device's board
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`BoardKeepingTests`: another device's board isn't offered it; the list's menu asks `BoardKeeping.offersTrial`)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose boards sync between devices
- **I want to** find the trial only on the boards this device draws
- **so that** a board I can't draw on here doesn't offer me a way to draw on it

#### Acceptance Criteria:
- **Scenario:** Another device's board
- **Given:** a board drawn on another device
- **When:** I long-press its row
- **Then:** *Try on paper* isn't offered

---

### User Story 525:

- **Summary:** The trial isn't offered before iOS 27
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: retired by [bacbc3e](https://github.com/idvorkin/context-grabber/commit/bacbc3e): the whole app now needs iOS 27, so there's no older system left to offer it on (built for the simulator, every bundle's minimum read as 27.0). Implemented earlier in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** on an older system
- **I want to** see the app as it was
- **so that** a trial of a new framework costs me nothing

#### Acceptance Criteria:
- **Scenario:** Before iOS 27
- **Given:** a device below iOS 27
- **When:** I long-press a row
- **Then:** *Try on paper* isn't offered, and the app runs as it did

---

### User Story 526:

- **Summary:** A board that can't be read says so, and stays
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); not yet run on any rung: no test hands it an unreadable file
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose board file has gone bad
- **I want to** a problem I can copy, and the file left alone
- **so that** the trial never makes a bad file worse

#### Acceptance Criteria:
- **Scenario:** A board that can't be read
- **Given:** a board whose drawing can't be read
- **When:** I choose *Try on paper*
- **Then:** a copyable problem says so, and the file stays where it is

---

### User Story 527:

- **Summary:** The trial has nothing to send with
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`: none of the four buttons exists). That nothing goes out is by construction: the trial is handed no store, model or inbox
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** playing with an unfinished canvas
- **I want to** find no way to send from it
- **so that** a scribble in the trial never reaches Larry or iCloud

#### Acceptance Criteria:
- **Scenario:** Nothing to send
- **Given:** the trial is open
- **When:** I look for Send, Larry's turn, ghosts or the mic
- **Then:** there's none of them, and nothing goes to the Cockpit or iCloud

---

### User Story 528:

- **Summary:** The trial's pinch stops at the page
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`BoardPagesTests`: the fit zoom); pinching with real fingers is the iPad's: the simulator's pinch didn't change the zoom
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** trying the Notability-like board
- **I want to** have pinching out stop at the page
- **so that** I can judge the page-width shape before it is built for real

#### Acceptance Criteria:
- **Scenario:** Pinching out
- **Given:** the trial is open
- **When:** I pinch out as far as it goes
- **Then:** it stops when the page fits the screen's width

---

### User Story 529:

- **Summary:** Writing on the last page adds a blank one
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`PaperProbeTests`: when ink needs a page) and an iPad simulator (`WhiteboardTrialOnPaperUITests`: a page added)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing to the end of the trial's column
- **I want to** always have a blank page below
- **so that** I can judge how the column grows

#### Acceptance Criteria:
- **Scenario:** Writing on the last page
- **Given:** a stroke reaching the last page
- **When:** I lift the Pencil
- **Then:** one more blank page is below, and the page number's total goes up

---

### User Story 530:

- **Summary:** A page in the middle of a stroke
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`, the `paper_probe` lines read: a page added mid-stroke with a finger kept the stroke and undo); the Pencil's half is the iPad's
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding how a column of pages should grow
- **I want to** land a page in the middle of a stroke on purpose
- **so that** question 2 gets its answer from the log

#### Acceptance Criteria:
- **Scenario:** A page in the middle of a stroke
- **Given:** the Trial menu
- **When:** I choose *Add a page in 3 s* and write a long stroke across that moment
- **Then:** the page is added, and the log says a touch was down and what became of the stroke

---

### User Story 531:

- **Summary:** Going far down the column
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`: the corner reads *Page 11 of*); the ink's feel there is the iPad's
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** judging the ink's feel far down a board
- **I want to** jump past 9,600 points in one choice
- **so that** I can write there without scrolling all that way

#### Acceptance Criteria:
- **Scenario:** Going far down
- **Given:** the Trial menu
- **When:** I choose *Go to page 11*
- **Then:** the view goes past 9,600 points down, adding pages if it must, so I can write there

---

### User Story 532:

- **Summary:** The log says what adding a page did
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`, the `paper_probe` lines read): question 2 is answered there
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who plays on the iPad and reads the answers later
- **I want to** have each page added in the log
- **so that** question 2 is answered without my remembering it

#### Acceptance Criteria:
- **Scenario:** A page added
- **Given:** the trial is open
- **When:** a page is added
- **Then:** the log has where the view was and is, the zoom, whether undo survived, and whether a touch was down

---

### User Story 533:

- **Summary:** The log says how far the ring slipped
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`PaperProbeTests`) and the simulator that the lines are written; question 3 needs the iPad's log: `just pull-logs`
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who plays on the iPad and reads the answers later
- **I want to** have each scroll and pinch in the log
- **so that** question 3 is answered without my having to judge it by eye

#### Acceptance Criteria:
- **Scenario:** Scrolling
- **Given:** the trial is open
- **When:** I scroll or pinch
- **Then:** the log has how often the visible area was reported, and how far the ring slipped from its cross

---

### User Story 534:

- **Summary:** The log says whether a far corner works
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on the simulator (`WhiteboardTrialOnPaperUITests`: `stroke_landing`, and `sim-smoke.sh`: `origin`): question 4 is answered there
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with old boards whose ink sits far from the corner
- **I want to** have the log say whether the column can start there
- **so that** I know if the ink has to move

#### Acceptance Criteria:
- **Scenario:** A board far from the corner
- **Given:** a board with ink about 10,000 points from the corner
- **When:** I choose *Ink where it is* in the Trial menu
- **Then:** the log says whether that start was kept and whether the ink is on screen, and the first stroke says whether it landed under the Pencil

---

### User Story 535:

- **Summary:** Always one blank page below the last ink
- **Status:** the page count implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); on a real board since [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (story 603)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing down a board on paper
- **I want to** always have one blank page below my last ink
- **so that** I never run out of room and never have to add a page

#### Acceptance Criteria:
- **Scenario:** Ink reaching a new page
- **Given:** a new board, which is one blank page
- **When:** my ink goes past the end of page 1
- **Then:** the board has three pages, the last of them blank

- **Scenario:** Ink stopping exactly at a page's end
- **Given:** a new board, which is one blank page
- **When:** my ink reaches the end of page 1 and goes no further
- **Then:** the board has two pages, and page 2 still counts as the blank one

---

### User Story 536:

- **Summary:** A mark is on the page that holds it
- **Status:** the page of a point implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); the corner's page number on a real board since [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (story 603); nothing shows Larry a page yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who thinks of a board page by page
- **I want to** have every place on the board belong to one page
- **so that** the page number and what Larry is shown agree with what I see

#### Acceptance Criteria:
- **Scenario:** A mark on the line between pages
- **Given:** a board on paper with two pages or more
- **When:** a mark sits exactly on the line where page 1 ends
- **Then:** that mark counts as on page 2

---

### User Story 537:

- **Summary:** Pages stack edge to edge, and a line marks where each ends
- **Status:** page edges and end lines implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); the page lines on a real board since [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (story 592); a board wider than a page isn't on any screen yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** used to writing on paper
- **I want to** see where each page ends, on pages all the same height
- **so that** a board reads as sheets of paper

#### Acceptance Criteria:
- **Scenario:** A board wider than a page
- **Given:** a board whose ink makes it 2,000 points wide
- **When:** I look at its pages
- **Then:** every page is that wide and still 1,060 tall, touching the next, with a line at each page's end

---

### User Story 538:

- **Summary:** Every page is ruled the same
- **Status:** the line positions implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); the 40-point spacing is provisional until Igor has seen it. Drawn on paper in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`), which shows one page at a time; two pages ruled alike is from `BoardPagesTests`.
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who writes on notebook paper
- **I want to** have the same lines at the same places on every page, thinning when I pinch out
- **so that** the lines guide my writing without crowding the page

#### Acceptance Criteria:
- **Scenario:** Pinching out over ruled pages
- **Given:** a board on paper with ruled lines on
- **When:** I pinch out
- **Then:** only lines that were already there stay, every page's lines stay the same as each other's, and none lands on a page's end

---

### User Story 539:

- **Summary:** Moving onto pages never scales a stroke
- **Status:** the move implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); no real board has moved yet: that's a later slice
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards from before pages
- **I want to** have my strokes keep their size and their places relative to each other when a board moves onto pages
- **so that** my old drawings are the drawings I made

#### Acceptance Criteria:
- **Scenario:** Ink wider than a page moving onto pages
- **Given:** an old board with ink 2,000 points wide, far from the board's corner
- **When:** it moves onto pages
- **Then:** the ink sits inside the first page's corner at the same size, and the board is wide enough to hold it

---

### User Story 590:

- **Summary:** A switch for new boards on paper
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f), and on by default since [6a96779](https://github.com/idvorkin/context-grabber/commit/6a96779); verified on an iPhone simulator (`WhiteboardOnPaperUITests`: on until turned off)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), [#671](https://github.com/idvorkin/context-grabber/issues/671)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who wants paper
- **I want to** have new boards on paper unless I turn that off from the boards list
- **so that** I get paper without asking, and can go back to the old canvas while paper lacks something

#### Acceptance Criteria:
- **Scenario:** A device that never touched the switch
- **Given:** the boards list
- **When:** I open its menu beside +
- **Then:** *New boards on paper* is on

---

### User Story 591:

- **Summary:** A new board on paper is a column of pages
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: *Page 1 of 1*) and by host tests (`BoardPagesTests`). How it feels under the Pencil is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing down a new board
- **I want to** get a page-wide column with a blank page below my ink and a page number at the corner
- **so that** I never run out of room and always know where I am

#### Acceptance Criteria:
- **Scenario:** A new board
- **Given:** the switch on
- **When:** I tap +
- **Then:** the board fits one page across the screen and reads *Page 1 of 1*

---

### User Story 592:

- **Summary:** Page lines under the ink, and nothing to test with
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified by reading screenshots from an iPhone and an iPad simulator: page lines under the ink, no cross, no ring. Ruled lines are story 434
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at my own notes
- **I want to** see faint page lines under the ink and no test marks
- **so that** the board reads as paper and not as a trial

#### Acceptance Criteria:
- **Scenario:** A board on paper
- **Given:** a board on paper with ink
- **When:** I look at it
- **Then:** a faint line marks each page's end, under the ink, with no small cross and no orange ring

---

### User Story 593:

- **Summary:** A board on paper is kept like any other
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: killed and reopened with the same ink)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing on a board on paper
- **I want to** have it saved, listed and synced as any board is
- **so that** paper costs me nothing I rely on

#### Acceptance Criteria:
- **Scenario:** Killed after a stroke
- **Given:** a board on paper with a stroke drawn a moment ago
- **When:** the app is killed and opened again
- **Then:** the row says *On paper* and the board opens with that ink

---

### User Story 594:

- **Summary:** Another device looks at a board on paper
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified by host tests only (`BoardIndexTests`: the mark survives the list and the merge, and opens on paper only on its own device). iCloud isn't signed in on the simulator, so the other device's view is for the iPad and iPhone; shown on paper since [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e) (host tests: `BoardIndexTests`)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a board my iPad draws, on my iPhone
- **I want to** see its ink in the look-only view
- **so that** paper doesn't cut a board off from my other device

#### Acceptance Criteria:
- **Scenario:** On the other device
- **Given:** a board on paper drawn on the iPad
- **When:** I open it on the iPhone
- **Then:** the ink shows look-only on paper, on its pages, with no tool picker (the old canvas went 2026-11-07, story 658)

---

### User Story 595:

- **Summary:** The switch never moves a board
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator earlier (`WhiteboardOnPaperUITests`: an old board with the switch on), and now by host tests (`BoardKeepingTests`: a board keeps what it was made as through a relaunch)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with old boards and new ones side by side
- **I want to** have each board stay on the canvas it started on
- **so that** the switch can't cost me a board

#### Acceptance Criteria:
- **Scenario:** An old board, switch on
- **Given:** a board from before, and the switch on
- **When:** I open it
- **Then:** it opens on the old canvas with its ghosts and mic

---

### User Story 596:

- **Summary:** A board on paper opens where I left it
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the place's rule verified by host tests (`BoardPagesTests`); not driven on the simulator, where one finger draws, so coming back to a scrolled place is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** coming back to a long board
- **I want to** land on the page I was on
- **so that** I don't scroll to find my place

#### Acceptance Criteria:
- **Scenario:** Coming back
- **Given:** a board on paper I scrolled down and left
- **When:** I open it on this device
- **Then:** it opens at that place

---

### User Story 597:

- **Summary:** A board on paper keeps its colour
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: Sage chosen, and read off a screenshot)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who gave a board a colour
- **I want to** choose its colour on paper as on the old canvas
- **so that** the page looks the way I chose

#### Acceptance Criteria:
- **Scenario:** Choosing a colour
- **Given:** a board on paper
- **When:** I choose Sage in the Board menu
- **Then:** the paper under the ink turns sage

---

### User Story 598:

- **Summary:** A board on paper says what it can't do yet
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: the bar and the Board menu). The paste button back in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); that it's there is checked on an iPhone simulator (`WhiteboardPaperGhostsUITests`: `testAGhostShowsOnThePaperAndATapKeepsIt`). The Board menu's grid in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** used to the old canvas
- **I want to** not be offered what paper can't do yet
- **so that** nothing looks like it works and then doesn't

#### Acceptance Criteria:
- **Scenario:** The top bar
- **Given:** a board on paper
- **When:** I look at its bar
- **Then:** the Ghosts switch, the mic, *Larry's turn*, *Send to Larry* and the paste button are there

---

### User Story 599:

- **Summary:** A failed save on paper says so, and doesn't vanish
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`, `GRABBER_WHITEBOARD_SAVE_FAILS`: *Copy error* on the board) and by host tests (`BoardKeepingTests`: a full disk fails the save and keeps the last good drawing). A real full disk wasn't tried
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who can't afford to lose notes silently
- **I want to** see a problem I can copy when a save fails
- **so that** I know right then that something isn't kept

#### Acceptance Criteria:
- **Scenario:** While drawing
- **Given:** a board on paper whose save fails
- **When:** a stroke's save runs
- **Then:** the board shows the problem with a *Copy error* button, and I can keep drawing

---

### User Story 600:

- **Summary:** The log tells the Pencil from a finger
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the line verified on the simulator's log for a finger (`whiteboard` action: paper_touch); the Pencil's is for the iPad. This story says only that the log tells them apart, not what a finger does. Since [b0e8221](https://github.com/idvorkin/context-grabber/commit/b0e8221) (#825) a touch is the Pencil's when any touch in it was: verified on the host (`PaperProbeTests`) and the Mac build; the Pencil's line still for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), [#825](https://github.com/idvorkin/context-grabber/issues/825) (a run was typed by its first touch, so a palm made the Pencil's strokes a finger's)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding what a finger should do on paper
- **I want to** have each touch on a board on paper logged with which it was and what came of it
- **so that** the next try on the iPad settles it without another build

#### Acceptance Criteria:
- **Scenario:** A touch
- **Given:** a board on paper
- **When:** I touch it with the Pencil or a finger
- **Then:** a line says which it was, how far it went, and whether it drew, panned, selected, moved ink or did nothing

---

### User Story 601:

- **Summary:** *Try on paper* stays
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified earlier on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`; `WhiteboardTrialOnPaperUITests` on the iPhone), and now by host tests (`BoardKeepingTests`: a board on paper is offered it, and its copy reads the ink and writes nothing)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** still testing what PaperKit does
- **I want to** open any board this device draws in the trial
- **so that** the switch doesn't take away the place to test with

#### Acceptance Criteria:
- **Scenario:** A board on paper in the trial
- **Given:** a board on paper
- **When:** I long-press its row and choose *Try on paper*
- **Then:** the trial opens a copy with its test marks, and the real board is untouched

---

### User Story 602:

- **Summary:** Turning new boards on paper on
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: turned on, then a new board is on paper). That the switch is still on after a relaunch isn't asserted there
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who turned the switch off on this device
- **I want to** turn the switch back on once
- **so that** every new board here is on paper until I turn it off

#### Acceptance Criteria:
- **Scenario:** Turning it on
- **Given:** the switch off
- **When:** I turn on *New boards on paper* and tap +
- **Then:** the new board is on paper, and the switch stays on when the app opens again

---

### User Story 603:

- **Summary:** The first ink brings the next page
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: *Page 1 of 2*) and by host tests (`BoardPagesTests`)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing down a new board
- **I want to** have a blank page ready below my ink
- **so that** I never stop to make room

#### Acceptance Criteria:
- **Scenario:** The first ink
- **Given:** a new board on paper
- **When:** I draw on it
- **Then:** it reads *Page 1 of 2*, and a blank page is there to scroll to

---

### User Story 604:

- **Summary:** A board on paper closed empty leaves nothing
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator earlier (`WhiteboardOnPaperUITests`: no row left), and now by host tests (`BoardKeepingTests`: a new board of this device's closed without a stroke is dropped, on paper too; one drawn on, renamed or another device's stays)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** opening a new board and changing my mind
- **I want to** leave nothing behind when I go back
- **so that** the list holds only what I drew

#### Acceptance Criteria:
- **Scenario:** Closed without a stroke
- **Given:** a new board on paper with nothing on it
- **When:** I go back
- **Then:** no row is left behind

---

### User Story 605:

- **Summary:** A board on paper is saved in today's format
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the same format by construction, as what's saved is a `PKDrawing`; not run against an older build
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with devices on different builds
- **I want to** have a board on paper saved as every board is
- **so that** an older build can still read it

#### Acceptance Criteria:
- **Scenario:** In today's format
- **Given:** a board on paper with ink
- **When:** an older build reads its file
- **Then:** it opens the same strokes on the old canvas, as the file is what every board's file is

---

### User Story 606:

- **Summary:** A board on paper comes back on paper
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified by host tests only (`BoardIndexTests`: the mark survives the list and the merge). iCloud isn't signed in on the simulator, so the record's new field is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose device lost its list of boards
- **I want to** have a board on paper come back as it was
- **so that** iCloud's copy doesn't land me on the old canvas

#### Acceptance Criteria:
- **Scenario:** Back on the same device
- **Given:** a board on paper whose list this device lost
- **When:** iCloud brings it back
- **Then:** it opens on paper again

---

### User Story 607:

- **Summary:** Turning the switch off leaves paper boards on paper
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator earlier (`WhiteboardOnPaperUITests`: a paper board with the switch off), and now by host tests (`BoardKeepingTests`: a board keeps what it was made as through a relaunch)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who turned the switch off
- **I want to** have the boards already on paper stay there
- **so that** turning it off can't cost me a board

#### Acceptance Criteria:
- **Scenario:** A paper board, switch off
- **Given:** a board on paper, and the switch off
- **When:** I open it
- **Then:** it opens on paper

---

### User Story 608:

- **Summary:** A remembered place past the end of the board
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the rule verified by host tests (`BoardPagesTests`); not driven on the simulator
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who erased ink from a long board
- **I want to** open at the last page if my place is gone
- **so that** I don't land past the end of the board

#### Acceptance Criteria:
- **Scenario:** Ink erased since
- **Given:** a place further down than the board now reaches
- **When:** I open it
- **Then:** it opens at the last page's top

---

### User Story 609:

- **Summary:** A board on paper in dark mode
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [9af014a](https://github.com/idvorkin/context-grabber/commit/9af014a); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: the screenshot's pixels hold dark ink on pale paper, and the list is dark again). Dark mode on the iPad itself is still to be seen
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with my device in dark mode
- **I want to** see my ink on a board on paper
- **so that** what I draw never vanishes black on black

#### Acceptance Criteria:
- **Scenario:** In dark mode
- **Given:** a board on paper, and the device in dark mode
- **When:** I draw
- **Then:** the ink shows dark on the colour's pale shade, as dark mode's deep shades aren't on paper yet

---

### User Story 610:

- **Summary:** Send to Larry from a board on paper
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); *Send to Larry* is the old canvas's code, its button enabled on paper, and wasn't tapped on paper
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with a board on paper to show Larry
- **I want to** send it as I would any board
- **so that** paper doesn't cut Larry off, even before his marks come back

#### Acceptance Criteria:
- **Scenario:** Larry
- **Given:** a board on paper with ink
- **When:** I tap *Send to Larry*
- **Then:** the whole drawing goes, his reply shows in Chat, and marks he draws in answer come to the board (story 621)

---

### User Story 611:

- **Summary:** Paste wasn't on paper at first
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); ⌘V wasn't run. Ended by [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6): stories 637, 638
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** used to pasting text as ink on the old canvas
- **I want to** have had ⌘V do nothing on paper until paste was built
- **so that** no text lands where it can't be kept as it should

#### Acceptance Criteria:
- **Scenario:** Keys
- **Given:** a board on paper
- **When:** I press ⌘V
- **Then:** this held until stories 637 and 638, which replace it: the text lands

---

### User Story 612:

- **Summary:** A save that fails on leaving shows on the list
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`, `GRABBER_WHITEBOARD_SAVE_FAILS`: *Copy error* on the list after leaving). The problem staying through another failed save or another board's save, and going once that board saves, is verified by host tests (`BoardKeepingTests`). Boards on the old canvas take the same path
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who can't afford to lose notes silently
- **I want to** be told when the ink I just left couldn't be kept
- **so that** the failure doesn't go with the board's screen

#### Acceptance Criteria:
- **Scenario:** On leaving
- **Given:** a board with ink that can't be saved
- **When:** I go back
- **Then:** the boards list shows the problem until that board next saves

---

### User Story 613:

- **Summary:** Ghosts come to a board on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator by every old-canvas turn test run on paper (`WhiteboardTurnOnPaperUITests`, bar the colour's dark mode and the grid), and on an iPad simulator by two of them; and `WhiteboardPaperGhostsUITests` on an iPhone and an iPad simulator, read from the screen's pixels. A real Claude answer is for the iPad. Since bead `context-grabber-y8r` the bar and the turns, the same on either canvas, run once on the old canvas (`WhiteboardTurnUITests`), and what paper shows is `WhiteboardPaperGhostsUITests`'
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing on a board on paper
- **I want to** see the same faint suggestions as on any board when I pause
- **so that** paper doesn't cost me drawing with someone

#### Acceptance Criteria:
- **Scenario:** A pause
- **Given:** a board on paper with Ghosts on
- **When:** I draw a stroke and pause
- **Then:** a faint orange shape appears, and the bar says *1 suggestion: tap one to keep it*

---

### User Story 614:

- **Summary:** A ghost stays on the ink as the board moves
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardPaperGhostsUITests`: pinched in, the ghost's place against the ink read from the pixels; `ghost_slip` was 0 in the log of a run of that pinch at 0.49 to 0.67 zoom). XCUITest's pinch barely moves on an iPad simulator, so that test skips there. How it looks through a fast scroll at 120 Hz is for the iPad: `paper_touch`'s `ghost_slip` and `ghost_checks`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking around a board with suggestions on it
- **I want to** have a ghost stay where it was drawn when I scroll or pinch
- **so that** it never drifts off what it's about

#### Acceptance Criteria:
- **Scenario:** Scroll and pinch
- **Given:** a ghost beside my ink on a board on paper
- **When:** I scroll or pinch
- **Then:** the ghost moves and zooms exactly as the ink does, and doesn't trail behind

---

### User Story 615:

- **Summary:** A tap keeps a ghost on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: orange ink where the ghost was, from the pixels)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a suggestion I like
- **I want to** tap it with a finger and have it become ink
- **so that** keeping it is as easy as on any board

#### Acceptance Criteria:
- **Scenario:** On a ghost
- **Given:** a ghost on a board on paper
- **When:** I tap it
- **Then:** it becomes ink in its author's colour, in the same place, and the stroke count goes up by its strokes

---

### User Story 616:

- **Summary:** A finger doesn't draw while ghosts show on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); verified on an iPhone simulator and an iPad simulator, where a finger draws (`WhiteboardPaperGhostsUITests`, `WhiteboardTurnOnPaperUITests`: no dot, and the next stroke draws). What a finger drag does while ghosts show, with a Pencil paired or not, isn't settled: `paper_touch`'s `touch_mode` is `selection` then. Since bead `context-grabber-y8r`, `WhiteboardPaperGhostsUITests` alone. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first (stories 663, 664)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing with a finger, on a phone or an iPad with no Pencil
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** a tap doesn't leave a dot or select my ink

#### Acceptance Criteria:
- **Scenario:** A tap off them
- **Given:** a finger draws here, and ghosts show
- **When:** I tap away from them
- **Then:** they're dismissed (Larry's only once Claude's are gone, stories 663, 664), no dot is drawn and nothing is selected, and my finger draws again

---

### User Story 617:

- **Summary:** One undo takes a kept mark back
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`, by a hook, `GRABBER_WHITEBOARD_AFTER_KEEP`). The tool picker's own Undo and ⌘Z weren't pressed: a phone's picker has none, and keys reach only a run's first test. PaperKit registers no undo for a markup that's set, so this step is the app's own
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who kept a suggestion and thought again
- **I want to** undo it with one press
- **so that** my eraser and undo treat it as my own ink

#### Acceptance Criteria:
- **Scenario:** Undo
- **Given:** a kept ghost
- **When:** I undo once
- **Then:** it's gone, and my strokes before it stay

---

### User Story 618:

- **Summary:** A kept mark past the last page brings its pages
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the fake's `/far`, *Page 1 of 6*, kept by a hook). A ghost that far down can't be seen until it's kept: the Cockpit has never been seen to answer that far from the ink
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose suggestion lands below the last page
- **I want to** have the board make room for it
- **so that** kept ink is never out of reach below

#### Acceptance Criteria:
- **Scenario:** Far down
- **Given:** a mark below the last page
- **When:** it's kept
- **Then:** the pages down to it come with it, and a blank one below

---

### User Story 619:

- **Summary:** A kept mark has one name for Larry
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the same two ids at the fake Cockpit before and after closing and opening the board). `paper_keep`'s `same_ids` was true on every keep in both simulators' logs, with `drift` 0: the mark's id is the same before and after PaperKit. A real Cockpit wasn't used
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** working with Larry on a board that changes
- **I want to** have each stroke keep its name every time it's sent
- **so that** Larry knows what's new and doesn't see the board as redrawn

#### Acceptance Criteria:
- **Scenario:** Kept and sent again
- **Given:** a kept mark on a board on paper, sent to Larry
- **When:** I close and open the board and send it again
- **Then:** every stroke goes under the same name

---

### User Story 620:

- **Summary:** A ghost is never saved on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: killed with a ghost showing, and one stroke after the relaunch). The strokes sent to Larry hold only ink, as story 619's two ids show
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** leaving a board with a suggestion on it
- **I want to** have only what I drew or kept stay
- **so that** an unkept suggestion never turns into my ink

#### Acceptance Criteria:
- **Scenario:** Left showing
- **Given:** a ghost on a board on paper
- **When:** the app is killed after the save
- **Then:** the board opens with my strokes and no ghost of Claude's

---

### User Story 621:

- **Summary:** Larry's turn from a board on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`: his two marks beside Claude's one, unprompted ones replacing them) and an iPad simulator (the first of those). Where his marks land on real ink is for the iPad, with a real Larry. Since bead `context-grabber-y8r`, Larry's marks on paper are `WhiteboardPaperGhostsUITests`' (`testThePictureIsThePageOnScreen`) and unprompted ones `WhiteboardTurnUITests`', as the bar is the same on either canvas
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** wanting Larry's hand on a board on paper
- **I want to** tap *Larry's turn* and have his marks come back on the board
- **so that** paper doesn't send his answers off to Chat only

#### Acceptance Criteria:
- **Scenario:** His turn
- **Given:** a board on paper with ink
- **When:** I tap *Larry's turn*
- **Then:** his marks arrive by themselves in blue, kept by a tap like Claude's, and his words show in the bar

---

### User Story 622:

- **Summary:** Talk to a board on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the turn verified on an iPhone simulator with the spoken-words hook (`WhiteboardTurnOnPaperUITests`: words on an empty board bring a ghost, and nothing with Ghosts off). The microphone itself, and a call taking it, are for the iPad. Since bead `context-grabber-y8r`, words on an empty board are `WhiteboardTurnUITests`' (the same model on either canvas) and Ghosts off for words is `WhiteboardGhostTurnsTests`, on the host
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** talking while I draw on paper
- **I want to** ask Claude out loud as on any board
- **so that** my voice works whichever canvas a board is on

#### Acceptance Criteria:
- **Scenario:** Words
- **Given:** a board on paper, empty or not
- **When:** I tap the mic and say *draw a circle*
- **Then:** a ghost comes about as soon as on the old canvas, in the part on screen when the board is empty

---

### User Story 623:

- **Summary:** The Pencil holds Claude's pause on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the rule's own tests are the host's (`WhiteboardPacerTests`); a finger stroke's pause verified on the simulators (every ghost test above). The Pencil is only on the iPad: PaperKit tells when drawing begins and not when it ends, so the lift is read from the touch, and `paper_touch`'s `began_drawing` with `whiteboard_turn`'s timing will show it
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** still drawing with the Pencil
- **I want to** not be interrupted by a turn between strokes
- **so that** Claude answers when I stop, as on any board

#### Acceptance Criteria:
- **Scenario:** Touching down
- **Given:** a pause under way
- **When:** the Pencil touches down
- **Then:** the pause stops, and starts over when it lifts

---

### User Story 624:

- **Summary:** A mark past the page's side, for now
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the telling verified by host tests (`BoardPagesTests`); the case not driven on the simulator. The log's `paper_ghosts` says `past_side`. A later step widens the board for these
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose suggestion lands past the page's edge
- **I want to** know nothing is lost
- **so that** the board's later widening has all of it

#### Acceptance Criteria:
- **Scenario:** Past the side
- **Given:** a mark past the column's side or above its top
- **When:** it shows
- **Then:** it shows only as far as the column does

---

### User Story 625:

- **Summary:** A ghost lies under the ink on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); seen on simulator screenshots of an iPhone (a ghost beside ink, and zoomed). A ghost crossing ink wasn't shown in a test, and how it looks is for Igor's eye on the iPad. This differs from the old canvas, and it's his to overrule
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a suggestion across my own writing
- **I want to** see my ink on top of it
- **so that** it can't lag behind the board

#### Acceptance Criteria:
- **Scenario:** Crossing
- **Given:** a ghost crossing my ink on a board on paper
- **When:** I look at it
- **Then:** the ink is on top, and the ghost shows either side of it

---

### User Story 626:

- **Summary:** The log says what ghosts did on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the lines read from the simulators' logs (`paper_ghosts`, `paper_tap`, `paper_keep`, `paper_step`, and `paper_touch`'s `ghost_slip` and `ghost_checks`). What they say on the iPad is to come
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** working out on the iPad what the simulator can't show
- **I want to** have the log say where a ghost sat and what each tap and keep did
- **so that** the next try settles it without another build

#### Acceptance Criteria:
- **Scenario:** A try on the iPad
- **Given:** a board on paper with ghosts
- **When:** I scroll, tap and keep
- **Then:** the log says how far a ghost slipped, what the tap came to, and what the keep did to undo and to the strokes' names

---

### User Story 627:

- **Summary:** Ghosts off asks nothing on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`: `testGhostsOffAsksNothing`); since bead `context-grabber-5eq` the rule is a host test (`WhiteboardGhostTurnsTests`), the same model on paper as on the old canvas; since bead `context-grabber-y8r` no UI case on either canvas
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing alone on a board on paper
- **I want to** turn the suggestions off
- **so that** nothing interrupts me

#### Acceptance Criteria:
- **Scenario:** Ghosts off
- **Given:** a board on paper with Ghosts off
- **When:** I draw and pause
- **Then:** nothing is asked and nothing appears

---

### User Story 628:

- **Summary:** A tap keeps a ghost during a Pencil stroke
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); not verified: a Pencil is only on the iPad, and `paper_tap` will show it
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing with the Pencil in one hand
- **I want to** keep a suggestion with a finger of the other
- **so that** I don't have to stop drawing to keep it

#### Acceptance Criteria:
- **Scenario:** During a stroke
- **Given:** a ghost, and the Pencil drawing
- **When:** I tap the ghost with a finger
- **Then:** it's kept, and the stroke under way goes on

---

### User Story 629:

- **Summary:** A palm doesn't dismiss ghosts on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); not driven on a simulator: a touch the system calls off is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** resting my hand on the glass
- **I want to** have that touch not count as a tap
- **so that** my palm doesn't throw away the suggestions

#### Acceptance Criteria:
- **Scenario:** A palm
- **Given:** ghosts show
- **When:** the system calls off a touch, as it does a palm
- **Then:** the ghosts stay

---

### User Story 630:

- **Summary:** Redo brings a kept mark back
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: by the same hook as story 617, orange ink back from the pixels)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who undid a kept suggestion and thought again
- **I want to** redo it with one press
- **so that** it comes back as any ink does

#### Acceptance Criteria:
- **Scenario:** Redo
- **Given:** a kept ghost I undid
- **When:** I redo
- **Then:** it's back where it was

---

### User Story 631:

- **Summary:** The undo after a kept mark takes the stroke before it
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: by the same hook as story 617, none of his ink left, from the pixels)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** stepping back through what's on the board
- **I want to** have undo go on past a kept mark to my own strokes
- **so that** the kept mark doesn't stop the steps behind it

#### Acceptance Criteria:
- **Scenario:** Before it
- **Given:** a kept ghost I undid
- **When:** I undo again
- **Then:** the stroke before it goes

---

### User Story 632:

- **Summary:** One undo takes a kept mark and the pages it brought
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the fake's `/far`, *Page 1 of 6* then *Page 1 of 2*, by a hook)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who kept a suggestion far down the board
- **I want to** undo it and its pages together
- **so that** no empty pages are left behind

#### Acceptance Criteria:
- **Scenario:** With its page
- **Given:** a kept mark that brought pages
- **When:** I undo once
- **Then:** the mark and those pages both go

---

### User Story 633:

- **Summary:** Larry's marks come back when a board on paper opens
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`: the newest set on reopening, a dismissed set staying gone). Since bead `context-grabber-y8r`, `WhiteboardTurnUITests` on the old canvas (the same marks on either) and `WhiteboardMarksTests` on the host
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** coming back to a board Larry drew on
- **I want to** find his newest marks where they were
- **so that** closing a board doesn't cost me his answer, and what I dismissed stays dismissed

#### Acceptance Criteria:
- **Scenario:** Reopened
- **Given:** his marks showing
- **When:** I close and open the board
- **Then:** his newest set is there, and a set I dismissed stays gone

---

### User Story 634:

- **Summary:** Drawing during a turn on paper brings another after the next pause
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the rule's own tests are the host's (`WhiteboardPacerTests`). With the Pencil on paper it's for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** still drawing while Claude answers
- **I want to** be answered about what I added too
- **so that** a turn under way doesn't swallow my new strokes

#### Acceptance Criteria:
- **Scenario:** During a turn
- **Given:** a turn on its way
- **When:** I draw and lift
- **Then:** a new turn comes after the next pause

---

### User Story 635:

- **Summary:** A kept mark past the page's side is saved and sent
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the case not driven on the simulator. A later step widens the board for these
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** keeping a suggestion that runs past the page's edge
- **I want to** have all of it kept, not just what shows
- **so that** the board's later widening has all of it

#### Acceptance Criteria:
- **Scenario:** Kept past the side
- **Given:** a mark past the column's side or above its top, that I can reach
- **When:** I keep it
- **Then:** it's saved and sent like any ink, and what's past the column is out of reach on paper

---

### User Story 636:

- **Summary:** An undo doesn't outlive its board
- **Status:** implemented with the review fixes of #636, on paper and on the old canvas; built only, not driven on a simulator. Which undo stack a board has is for the iPad: `paper_keep`'s `undo_on_window` and `paper_undo_closed`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** going from one board to the next
- **I want to** have Undo on the new board never reach back
- **so that** a board I closed can't lose a kept mark without my seeing

#### Acceptance Criteria:
- **Scenario:** The next board
- **Given:** a mark kept on a board, which I then closed
- **When:** I open another board and press Undo
- **Then:** the closed board keeps that mark

---

### User Story 637:

- **Summary:** Paste text onto a board on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator through `GRABBER_WHITEBOARD_PASTE` (`WhiteboardPaperPasteUITests`: the letters read from the screen's pixels, across the middle; `WhiteboardPasteOnPaperUITests`: each line, the cap, the emoji note, Claude's pause). The bar's button itself is for the iPad, as XCUITest's taps never reach it. The iPad simulator wasn't run. Since bead `context-grabber-y8r`, each line, the cap and the note are `WhiteboardPasteTests`, on the host, and the pause and the emoji note `WhiteboardPasteUITests`, on the old canvas
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing on a board on paper
- **I want to** paste text as ink, as on any board
- **so that** paper doesn't cost me what I could already do

#### Acceptance Criteria:
- **Scenario:** The bar
- **Given:** a board on paper and text on the clipboard
- **When:** I tap Paste
- **Then:** the letters land as ink in the middle of the paper on screen, and the stroke count goes up

---

### User Story 638:

- **Summary:** ⌘V on a board on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`test1CommandVOnPaperAndCommandZ`: text after a stroke, read from the log as `paper_paste` how: key, went: ink; since bead `context-grabber-y8r`, `WhiteboardPasteUITests.testCommandVPastesAndCommandZTakesItBackOnBothCanvases`, after the old canvas's in the same launch; since 2026-11-07 `testCommandVPastesAndCommandZTakesItBack`, on paper only). A real keyboard on the iPad is to try, with text and a picture copied from another app, to see whether *Allow Paste?* shows: story 390 says it doesn't, this key reads the clipboard itself, and `paper_paste` can't show a prompt
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with a keyboard on a board on paper
- **I want to** press ⌘V and have the text land
- **so that** my hands don't leave the keys

#### Acceptance Criteria:
- **Scenario:** Keys
- **Given:** a board on paper and text on the clipboard
- **When:** I press ⌘V
- **Then:** the text lands as it does from the button

---

### User Story 639:

- **Summary:** One undo takes a paste back on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator: one ⌘Z (`test1CommandVOnPaperAndCommandZ`, since bead `context-grabber-y8r` `testCommandVPastesAndCommandZTakesItBackOnBothCanvases`, since 2026-11-07 `testCommandVPastesAndCommandZTakesItBack`), and an undo by a hook on a tall paste (`testATallPasteBringsItsPagesInOneUndo`). The tool picker's own Undo is for the iPad, as a phone's has none
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who pasted the wrong thing
- **I want to** undo it in one press
- **so that** a paste of many strokes is one thing to take back

#### Acceptance Criteria:
- **Scenario:** Undo
- **Given:** a paste on a board with my strokes on it
- **When:** I undo once
- **Then:** the whole paste goes, and my strokes stay

---

### User Story 640:

- **Summary:** A paste brings the pages it needs
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); the pages and their one undo verified on an iPhone simulator (`testATallPasteBringsItsPagesInOneUndo`: 40 lines, *Page 1 of 4*, and *Page 1 of 1* after the undo)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** pasting something long
- **I want to** have the board make room
- **so that** a long paste doesn't run off the last page

#### Acceptance Criteria:
- **Scenario:** Tall
- **Given:** a paste taller than the pages left
- **When:** it lands
- **Then:** the pages it needs come with it, with a blank one below

---

### User Story 641:

- **Summary:** Copied strokes paste on a board on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator with hooks (`testCopiedStrokesPaste`: PaperKit's own clipboard format, *landed_here*), and the middle of the view by host tests (`BoardPagesTests`). A real lasso Copy can't be worked on the simulator, and nothing took the system's Copy there, so what a real copy puts on the clipboard, and whether PaperKit pastes it itself, is for the iPad: `paper_paste`'s `types` and `went`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** moving ink around with the lasso
- **I want to** paste the strokes I copied with ⌘V
- **so that** pasting text doesn't cost me pasting ink

#### Acceptance Criteria:
- **Scenario:** Copied strokes
- **Given:** strokes on the clipboard and no text
- **When:** I press ⌘V
- **Then:** they land as ink at their own size, in the middle of the paper on screen unless PaperKit places them itself

---

### User Story 642:

- **Summary:** A paste stays on the page
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified by host tests (`WhiteboardPasteTests`: a view by the right edge, above the first page); on an iPhone simulator only as far as a short paste across the middle
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** pasting while zoomed in by a page's edge
- **I want to** have nothing land past the side
- **so that** I never paste where paper can't show it

#### Acceptance Criteria:
- **Scenario:** By the edge
- **Given:** a view near a page's side
- **When:** I paste
- **Then:** the text is wholly on the page

---

### User Story 643:

- **Summary:** Larry knows a paste by the same names
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`testAPastesStrokesKeepTheirNamesForLarry`: the same two ids at the fake Cockpit before and after a relaunch; `paper_keep`'s `same_ids` true and `drift` 0). That the letters are in the picture is the old canvas's code, on the same drawing, and wasn't looked at. A real Cockpit wasn't used
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** working with Larry on a board with pasted text
- **I want to** have him see the letters as ink, the same every time
- **so that** he knows what's new

#### Acceptance Criteria:
- **Scenario:** Sent again
- **Given:** a paste on a board on paper, sent to Larry
- **When:** I close and open the board and send it again
- **Then:** every letter's stroke goes under the same name, and the letters are in the picture, dark on white

---

### User Story 644:

- **Summary:** A picture on the clipboard isn't pasted on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator through a hook (`testAPictureIsNotPasted`: `went`: refused_picture, no red on the screen's pixels, the count unchanged). Pasting images remains a non-goal on every board
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with a picture on the clipboard from somewhere else
- **I want to** have ⌘V leave the board alone
- **so that** nothing lands that would vanish when I leave, as only strokes are saved

#### Acceptance Criteria:
- **Scenario:** A picture
- **Given:** a picture on the clipboard and no text or strokes
- **When:** I press ⌘V
- **Then:** the board doesn't change

---

### User Story 645:

- **Summary:** A phone's one page takes a paste
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`testAPasteLandsInTheMiddleOfThePaperOnScreen`: the letters read from the screen's pixels, across the middle). The test doesn't measure up and down, so `paper_keep`'s `ink`, `visible` and `sheet` are what say where they landed
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** on a phone
- **I want to** paste on a new board and see the text
- **so that** a page shorter than the screen doesn't lose it in the margin

#### Acceptance Criteria:
- **Scenario:** A phone's one page
- **Given:** a new board on paper on a phone, its page shorter than the screen
- **When:** I paste
- **Then:** the text is on the paper, not in the margin around it

---

### User Story 646:

- **Summary:** Redo brings a paste back on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator by a hook's press on a tall paste (`testATallPasteBringsItsPagesInOneUndo`: the strokes and the pages back). The tool picker's own Redo is for the iPad, as a phone's has none
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who undid a paste too soon
- **I want to** redo it in one press
- **so that** I get the whole paste back, not a part of it

#### Acceptance Criteria:
- **Scenario:** Redo
- **Given:** a paste I undid
- **When:** I redo
- **Then:** the whole paste is back

---

### User Story 647:

- **Summary:** A paste lands far down the board
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified by host tests only (`WhiteboardPasteTests`: page 29), as the simulator's test wasn't taken that far down
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** many pages down a board on paper
- **I want to** paste where I'm looking
- **so that** the old canvas's edge doesn't send it somewhere else

#### Acceptance Criteria:
- **Scenario:** Far down
- **Given:** a view past where the old canvas ended
- **When:** I paste
- **Then:** the text is in the middle of that view

---

### User Story 648:

- **Summary:** Text wins over copied strokes on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); built only, not driven on a simulator: no test puts text and strokes on the clipboard together. Whether a real copy ever holds both is for the iPad: `paper_paste`'s `types` and `went`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with text and strokes both on the clipboard
- **I want to** have ⌘V do one thing I can predict
- **so that** a paste never lands twice

#### Acceptance Criteria:
- **Scenario:** Text wins
- **Given:** strokes and text on the clipboard
- **When:** I press ⌘V
- **Then:** the text lands

---

### User Story 649:

- **Summary:** A wide line wraps on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified by host tests (`WhiteboardPasteTests`: long text stays on the page's width on paper, and a long line wraps inside the view by the same layout). Not on a simulator
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** pasting a long line while zoomed in
- **I want to** have it wrap
- **so that** I can read all of it without scrolling sideways

#### Acceptance Criteria:
- **Scenario:** Wide
- **Given:** a line wider than the part of the page on screen
- **When:** I paste
- **Then:** it wraps

---

### User Story 650:

- **Summary:** Ink the app adds always shows
- **Status:** implemented in [869cb8d](https://github.com/idvorkin/context-grabber/commit/869cb8d); the simulator only, iPhone 17, iOS 27: pasted ink missing from the screen in 15 of 180 runs before the fix, 0 of 60 after it (`testAPasteLandsInTheMiddleOfThePaperOnScreen`, read from `paper_ink_look`). The wait for the view to come to rest came after those counts, in [a86ac93](https://github.com/idvorkin/context-grabber/commit/a86ac93). A centred page skipped the redraw in [97bbdbe](https://github.com/idvorkin/context-grabber/commit/97bbdbe), verified on an iPad Pro 11-inch simulator (`testAGhostLeftShowingIsNotSaved`: crashed before, passes after). Since [62c7672](https://github.com/idvorkin/context-grabber/commit/62c7672) a centred page redraws by moving a point down and back, never setting the zoom (`paper_redraw_nudge` says `how: frame`), verified on an iPad Pro 11-inch simulator: `testAPasteLandsInTheMiddleOfThePaperOnScreen` missed 1 of 8 before, drew 24 of 24 after, no crash. Whether it happens on a real iPad, and whether the small redraw can be felt there, is still to be seen.
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636); [#829](https://github.com/idvorkin/context-grabber/issues/829): on an iPad, where the page is narrower than the screen and PaperKit centres it, the redraw's zoom recursed inside PaperKit until the app crashed; a centred page skipped it; [#833](https://github.com/idvorkin/context-grabber/issues/833): with the redraw skipped, a centred iPad page missed kept or pasted ink again (1 of 8 pastes, and 2 kept marks in a ladder run); a centred page now moves a point down and back instead, which never sets the zoom: 24 of 24 pastes drawn on an iPad Pro 11-inch simulator (`testAPasteLandsInTheMiddleOfThePaperOnScreen`, `paper_ink_look`), no crash.
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** keeping a ghost or pasting text on a board on paper
- **I want to** see the ink as soon as it's there
- **so that** nothing the board counts and saves is invisible to me

#### Acceptance Criteria:
- **Scenario:** Added ink shows
- **Given:** a board on paper
- **When:** I keep a ghost, paste text, or undo or redo one of those
- **Then:** the ink is on the screen within half a second, and the view stays where it is

---

### User Story 651:

- **Summary:** Turning new boards on paper off
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [6a96779](https://github.com/idvorkin/context-grabber/commit/6a96779); verified on an iPhone simulator (`WhiteboardOnPaperUITests`: turned off and back on from the menu) and by host tests (`BoardKeepingTests`: on until it's turned off, the launch hook, and a board made with it off stays on the old canvas through a relaunch). That the store's `UserDefaults` keeps it across a relaunch is no longer driven on the simulator; every launch hook relies on the same write and read
- **Issues:** [#671](https://github.com/idvorkin/context-grabber/issues/671)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who needs the old canvas while paper lacks something
- **I want to** turn the switch off once
- **so that** every new board here is on the old canvas until I turn it back on

#### Acceptance Criteria:
- **Scenario:** Turning it off
- **Given:** I turned *New boards on paper* off
- **When:** I open the app again and tap +
- **Then:** the new board is on the old canvas

### User Story 652:

- **Summary:** A grid on a board on paper
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`, `testTheGridShowsWhenAskedAndStaysWithItsBoard`, an old-canvas test dropped 2026-11-07; host `BoardPagesTests`; feel on a big board is the iPad's)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608), [#678](https://github.com/idvorkin/context-grabber/issues/678)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** thinking on paper
- **I want to** turn on faint grid lines under my ink
- **so that** I can line things up without the lines competing with the ink

#### Acceptance Criteria:
- **Scenario:** The grid
- **Given:** a board on paper
- **When:** I choose *Grid lines* in the Board menu
- **Then:** faint squares lie under the ink, run on unbroken from page to page, and thin when pinched out

### User Story 653:

- **Summary:** Lines stay with their board on paper
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesStayWithTheBoardUnderTheInk`, `testTheGridShowsWhenAskedAndStaysWithItsBoard`, the latter an old-canvas test dropped 2026-11-07)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** going back to a board
- **I want to** find its lines as I left them
- **so that** each board keeps its own look

#### Acceptance Criteria:
- **Scenario:** Reopening
- **Given:** a board on paper with ruled lines on
- **When:** I leave it and open it again
- **Then:** the lines are on. A new board starts with none

### User Story 654:

- **Summary:** Lines are never ink
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`, the stroke count; that they can't be erased or lassoed follows from their not being in the drawing, and hasn't been driven with those tools)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing over lines
- **I want to** have them left out of everything that is the drawing
- **so that** what I save and send is only what I drew

#### Acceptance Criteria:
- **Scenario:** Lines on
- **Given:** a board on paper with a stroke
- **When:** I turn lines on or off
- **Then:** the stroke count stays the same, nothing is added to undo, and they're not in the saved drawing, the card or any picture

### User Story 655:

- **Summary:** Lines and ghosts show on every colour
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testEveryColourShowsItsLinesAndKeepsTheInk` for the grid on all five, `testAGhostShowsOnTheDarkestColours` for a ghost on Grey; `testABoardsColourShowsInBothModesAndStaysWithIt` for the colour, an old-canvas test dropped 2026-11-07; on paper `testRuledLinesStayWithTheBoardUnderTheInk` keeps a board's colour); since bead `context-grabber-y8r` the grid on Lilac, the darkest, and Plain stand for all five (the lines are one grey on every colour)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** choosing a colour on paper
- **I want to** still see the page lines, the grid and ghosts
- **so that** a colour never hides what I need

#### Acceptance Criteria:
- **Scenario:** Each colour
- **Given:** a board on paper
- **When:** I choose any of the five colours
- **Then:** its pale shade shows, even with the device in dark mode, and the lines and ghosts show on it

### User Story 656:

- **Summary:** Changing colour or lines leaves the ink
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testEveryColourShowsItsLinesAndKeepsTheInk`; `paper_ink_look` after each change); since bead `context-grabber-y8r` on Lilac and Plain
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** changing how the paper looks
- **I want to** have the ink stay on screen
- **so that** nothing I drew seems to vanish

#### Acceptance Criteria:
- **Scenario:** A change under ink
- **Given:** ink on screen on a board on paper
- **When:** I change the colour or the lines
- **Then:** the ink stays where it was and the view doesn't move

### User Story 657:

- **Summary:** The Board menu never costs a stroke
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testTheFirstStrokeAfterTheMenuDraws`, 5 of 5 after the fix, and before it the stroke was lost 5 of 5). Choosing the colour already chosen takes the same path; its test, `testTheFirstStrokeAfterChoosingTheSameColourDraws`, hasn't been run on a simulator yet; since bead `context-grabber-y8r` the first two cases share one launch, and since [e234dc6](https://github.com/idvorkin/context-grabber/commit/e234dc6) the same-colour case has its own again, on a fresh board choosing Plain (chained after the others, the menu tap missed the colour row); verified on the simulator (the whole whiteboard suite, 0 failures)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing right after the menu
- **I want to** have my first stroke draw
- **so that** I don't lose a mark to a menu

#### Acceptance Criteria:
- **Scenario:** After the menu
- **Given:** a board on paper
- **When:** I close the Board menu, with a choice or without one, and draw
- **Then:** the stroke draws

### User Story 698:

- **Summary:** Claude's and Larry's marks look the way they ask, and labels read as writing
- **Status:** implemented in [bb3f487](https://github.com/idvorkin/context-grabber/commit/bb3f487); verified on the host (`WhiteboardTurnTests`, 22 of 22, five new). Not yet seen on a device
- **Issues:** [#698](https://github.com/idvorkin/context-grabber/issues/698)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** drawing with Larry on the board
- **I want to** see his marks at the width, colour and lettering he chose, with labels in a thin pen
- **so that** what he writes reads like writing and his diagram says what he meant, not a bold blue marker

#### Acceptance Criteria:
- **Scenario:** A mark that asks for its look
- **Given:** a board with a thread, and Larry answers with a box in green at a fine pen and a label in the hand face
- **and Given:** another label of his that names no pen, colour or face
- **When:** his marks arrive and I keep them
- **Then:** the box is a green outline at the fine pen, the first label is in handwriting letters, the second is in his blue print at a thin pen, not bold, and each kept mark is ink exactly as its ghost showed

---

### User Story 658:

- **Summary:** A board drawn on the old canvas opens to look at, on paper
- **Status:** implemented in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e); verified by host tests (`BoardIndexTests`: only a board made on paper, on its own device, is drawn on; the bar's words for each look-only board; `BoardKeepingTests`: through a relaunch; `BoardPagesTests`: the ink moved, never scaled) and on the simulator (`WhiteboardOnPaperUITests.testAnOldCanvasBoardOpensLookOnlyOnPaper`, on an iPad Pro 11-inch simulator too since [#845](https://github.com/idvorkin/context-grabber/issues/845): it searches for the old ink from under the navigation bar and drags right to left, as a swipe right is Back; `paper_ink_look` why `open` counted the ink drawn in 6 of 6 opens; the smoke's `paper_open`). Igor's own old boards on the iPad not yet seen
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Paper is the only canvas*

#### Use Case:
- **As someone** whose early boards were drawn before paper
- **I want to** open one and see its ink on paper, where every board now lives
- **so that** the old canvas can go without taking my old sketches with it

#### Acceptance Criteria:
- **Scenario:** An old board, after the old canvas is gone
- **Given:** a board I drew on the old canvas, on this device
- **and Given:** the app has only paper
- **When:** I open it
- **Then:** its ink shows on the first page, every stroke where it was relative to the others and none scaled, the bar says *Drawn on the old canvas: look only*, and there are no tools, no Board menu and no Send, so nothing draws on it or changes its file

---

### User Story 659:

- **Summary:** I pick who answers a board's pause: Haiku, Sonnet or the real Larry
- **Status:** implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (`WhiteboardResponderTests`: the read and the write on the wire, the tick while they are on their way, a failed write taking it back, who answered from a stream or a whole answer, when a Larry board's pause goes to his thread) and the Linux cross-builds of ContextCore. [0a91f6e](https://github.com/idvorkin/context-grabber/commit/0a91f6e) moved the choice into a *Responder: Sonnet*-style submenu of the Board menu (#848); verified on the iPad simulator (`WhiteboardPaperLinesUITests` 6/6: the Board menu closes on a pick of colour or lines). The Cockpit's live knob and a Larry board's hand-off not yet seen on the Mac or the iPad; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Issues:** [#848](https://github.com/idvorkin/context-grabber/issues/848) (the section made the iPad's Board menu too tall to close on a pick; now a submenu)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing with a model beside me
- **I want to** choose per board whether Haiku, Sonnet or the real Larry answers when I pause
- **so that** I can feel the difference between a fast ghost, a sharper one and Larry himself, and keep the one that suits the board

#### Acceptance Criteria:
- **Scenario:** The board's own choice
- **Given:** a board I draw on, which nobody has set
- **When:** I open its Board menu
- **Then:** its Responder row says Sonnet and opens on Haiku, Sonnet and Larry with Sonnet ticked, and when I pick Haiku the tick moves at once and the board has Haiku when I reopen it, here and on my other devices

- **Scenario:** A Larry board
- **Given:** a board whose responder is Larry, with Ghosts on
- **When:** I draw and pause
- **Then:** no orange ghosts come; the bar's note begins with Larry's clock (*Larry · 0:00*, story 667), the picture is in the board's chat thread, and his blue marks show when he answers

- **Scenario:** The Cockpit can't take the choice
- **Given:** the Cockpit can't be reached
- **When:** I pick another responder
- **Then:** the tick goes back to the one the Cockpit last said and a copyable problem says why

---

### User Story 660:

- **Summary:** Claude is asked half a second after I lift the Pencil, not a second
- **Status:** implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (`WhiteboardResponderTests.testThePauseIsHalfASecond`; the pause's own rules unchanged in `WhiteboardPacerTests`). The feel on the iPad not yet tried
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Ghosts from Claude*

#### Use Case:
- **As someone** drawing with Claude
- **I want to** see ghosts sooner after I stop
- **so that** it feels like drawing together, not waiting for a turn

#### Acceptance Criteria:
- **Scenario:** A shorter pause
- **Given:** Ghosts are on
- **When:** I draw a circle and lift the Pencil
- **Then:** the turn is asked half a second later (the session log's `pause_ms` is about 500), and the Pencil going back down before then still holds it

---

### User Story 661:

- **Summary:** Every ghost turn says how long the iPad's half took
- **Status:** implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (`WhiteboardResponderTests`: the milliseconds, what goes to the Cockpit and what only the log has, the request carrying the board and the timings). The upload time comes from URLSession's own report, seen only on a device
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** deciding which model draws the ghosts
- **I want to** see where the wait goes: the pause, the picture, the upload, the model
- **so that** the choice rests on measurements, not guesses

#### Acceptance Criteria:
- **Scenario:** A measured turn
- **Given:** Ghosts are on
- **When:** I draw, pause, and a ghost turn goes
- **Then:** its session-log line has `pause_ms`, `render_ms`, `encode_ms` and `upload_ms` beside who answered, and the Cockpit's log of that turn has the pause, render and encode times

---

### User Story 662:

- **Summary:** A Larry board sends him one picture at a time, the newest
- **Status:** implemented in [41b83fb](https://github.com/idvorkin/context-grabber/commit/41b83fb); verified on the host (`WhiteboardLarryTurnTests`: a pause while idle sends, a pause while he is looking doesn't, his answer with the board moved on sends once and with nothing new sends nothing, the 3-minute timeout, a tap taking over, words carried, a failed picture freeing the turn). Not yet seen on the iPad or against the real Larry; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** keep drawing and talking while he looks, without each pause sending him another picture
- **so that** his thread holds one picture per answer, always the newest board, and nothing I said is lost

#### Acceptance Criteria:
- **Scenario:** Pauses while he is looking
- **Given:** a Larry board, a picture sent and no answer from him yet
- **When:** I draw and pause several times, and say "and label it"
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) and no new picture goes; when he answers, exactly one picture of the board as it is then goes, with "and label it" as its message

- **Scenario:** Nothing new since
- **Given:** a Larry board, a picture sent, and no pause since
- **When:** he answers
- **Then:** nothing more goes and the bar stops saying he is looking

- **Scenario:** He doesn't answer
- **Given:** a Larry board, a picture sent, and pauses since
- **When:** 3 minutes pass with no answer from him
- **Then:** one fresh picture goes, and the session log says the turn ended by timeout

- **Scenario:** I don't wait
- **Given:** he is looking and the board has moved on
- **When:** I tap *Larry's turn*
- **Then:** a picture of the board goes at once with any words that waited, and his answer to the earlier one sends nothing more

- **Scenario:** Nothing new to show him (story 765)
- **Given:** he is looking at a picture and I have drawn and said nothing since it went
- **When:** I tap *Larry's turn* or *Send to Larry*
- **Then:** no picture goes and the note says *Larry already has this*

---

### User Story 746:

- **Summary:** On an iPhone, boards are for looking, not drawing
- **Status:** implemented in [df438e6](https://github.com/idvorkin/context-grabber/commit/df438e6), [d053c9a](https://github.com/idvorkin/context-grabber/commit/d053c9a); verified by host tests (`BoardIndexTests`), `PhoneBoardsUITests` on the iPhone simulator, and the whiteboard classes on the iPad simulator (`just test-ladder`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *On an iPhone every board is look-only*

#### Use Case:
- **As Igor,** on my iPhone, where a finger on a small screen is too hard to draw with ("we can't do hand drawing")
- **I want to** open any board to look at what was drawn, with nothing offering to draw
- **so that** the phone shows the boards without pretending to be a drawing surface, and the drawing happens on the iPad

#### Acceptance Criteria:
- **Scenario:** Opening the boards on an iPhone
- **Given:** an iPhone whose list holds a board it drew earlier and a board drawn on the iPad
- **and Given:** the list has no *+ New board*
- **When:** I open either board
- **Then:** it opens to pan and pinch with no tool picker, no Board menu and no ghosts, *Send to Larry* still there to talk about it, and the bar says *Look only on iPhone: draw on the iPad*

### User Story 667:

- **Summary:** See how long Larry has been looking
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: the clock counts from the picture, shows the true time after the app was away, stops at his answer, and VoiceOver's words) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see that he is working and for how long
- **so that** I can tell a slow answer from a broken one without stopping to wonder

#### Acceptance Criteria:
- **Scenario:** The clock counts while he looks
- **Given:** a Larry board and a picture just sent
- **When:** I keep drawing for forty-two seconds
- **Then:** the bar's note begins *Larry · 0:42*, and it goes when his answer arrives

---

### User Story 668:

- **Summary:** Larry's clock times the picture he is looking at now
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: a newer picture restarts the clock) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** have the clock start again when a newer picture goes
- **so that** it never counts a picture he is no longer answering

#### Acceptance Criteria:
- **Scenario:** A newer picture
- **Given:** Larry has been looking for twenty seconds
- **When:** I tap *Larry's turn* with new ink
- **Then:** the clock goes back to 0:00

---

### User Story 669:

- **Summary:** A wait that ended without an answer says so
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: his silence carries when the picture went, the wait, what was waiting and whether the Cockpit was answering; `WhiteboardLarryTurnTests`: the 3-minute timeout) and the Mac build (`just native-build-mac`); the problem on the bar not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** be told when the board has stopped waiting for him, with the state that explains it
- **so that** I can hand the evidence over instead of guessing whether he was slow or gone

#### Acceptance Criteria:
- **Scenario:** He doesn't answer
- **Given:** a picture sent and no answer
- **When:** three minutes pass
- **Then:** the bar shows *Larry didn't answer* as a problem I can copy, naming when the picture went, how long the board waited, what was waiting and whether the Cockpit was answering

---

### User Story 760:

- **Summary:** Slow and unreachable never look the same
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: the Cockpit not answering is said and the clock keeps counting) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see when the board can't reach the Cockpit while he is looking
- **so that** I know the wait is the connection's and not his

#### Acceptance Criteria:
- **Scenario:** The Cockpit can't be reached
- **Given:** Larry is looking
- **When:** the board's looks at his thread keep failing
- **Then:** the state adds *Cockpit not answering* and keeps counting, the bar's separate *Larry's marks: the Cockpit isn't answering* note stays away while the clock says it, and the state clears itself when the Cockpit answers

---

### User Story 761:

- **Summary:** Dismiss *Larry didn't answer*
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by the Mac build (`just native-build-mac`) and, for the launch hook that shortens the wait and dismisses it (`GRABBER_WHITEBOARD_LARRY_TIMEOUT`), host tests (`LaunchHooksTests`, `WhiteboardLarryTurnTests`: a shorter timeout); the button not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** put his silence away once I have read it
- **so that** the bar goes back to the board

#### Acceptance Criteria:
- **Scenario:** I dismiss it
- **Given:** the bar shows *Larry didn't answer*
- **When:** I tap *Dismiss* beside it
- **Then:** the problem goes, and the session log says it was dismissed

---

### User Story 762:

- **Summary:** *Larry didn't answer* stays until he next answers
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** keep seeing that he went quiet, even once the board has moved on to the next picture
- **so that** a silence I didn't notice at the time is still there when I look up

#### Acceptance Criteria:
- **Scenario:** The waiting ink goes and the problem stays
- **Given:** the bar shows *Larry didn't answer*
- **and Given:** ink was waiting, so a fresh picture went and a new clock started
- **When:** his answer to that picture arrives
- **Then:** the problem was there for the whole of that wait, and goes only now, with his clock

---

### User Story 763:

- **Summary:** The board shows one problem at a time
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see only the newest thing that went wrong
- **so that** the bar never stacks problems over the drawing

#### Acceptance Criteria:
- **Scenario:** A later failure
- **Given:** the bar shows *Larry didn't answer*
- **When:** a later picture can't be handed to him
- **Then:** that failure's problem takes the place of *Larry didn't answer*, with no *Dismiss* beside it

---

### User Story 764:

- **Summary:** Larry's clock shows on any board his turn is out
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: the clock runs from a tapped turn, whoever answers the board's pauses) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board Haiku or Sonnet answers
- **I want to** see Larry's clock after I hand him a turn myself
- **so that** his slow answer is timed there too, while the fast responders' pauses start no clock

#### Acceptance Criteria:
- **Scenario:** A manual turn on a Haiku or Sonnet board
- **Given:** a board whose pauses Haiku or Sonnet answers, and a pause that started no clock
- **When:** I tap *Larry's turn*
- **Then:** the bar's note begins *Larry · 0:00* and counts until he answers

---

### User Story 765:

- **Summary:** A repeat tap doesn't send Larry the same picture again
- **Status:** not yet implemented
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) (seven identical pictures in twelve seconds)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *A repeat tap sends nothing*

#### Use Case:
- **As someone** waiting on Larry and not sure my tap took
- **I want to** be told he already has the picture
- **so that** his thread isn't filled with copies and I know the tap was heard

#### Acceptance Criteria:
- **Scenario:** Nothing new since the picture
- **Given:** Larry is looking at a picture and I have drawn and said nothing since
- **When:** I tap *Larry's turn* or *Send to Larry*
- **Then:** no picture goes, and the note says *Larry already has this* with the clock for two seconds

- **Scenario:** Something new
- **Given:** Larry is looking and I have drawn a stroke since
- **When:** I tap *Larry's turn*
- **Then:** a fresh picture goes at once and the clock restarts

---

### User Story 766:

- **Summary:** The board's note is one line that opens into the conversation
- **Status:** not yet implemented
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** drawing and talking with Larry on a board
- **I want to** glance at one line for where things stand and open it to read what was said
- **so that** his reply and my own words aren't cut off, and reading them doesn't take me off the board

#### Acceptance Criteria:
- **Scenario:** One line
- **Given:** Larry's long reply and a long line from the mic
- **When:** I look at the note
- **Then:** it is one line: his state first, the newest words after it, and the paper hasn't moved

- **Scenario:** What is waiting
- **Given:** Larry is looking
- **When:** I draw and speak
- **Then:** the state says *next: ink + words*

- **Scenario:** Open it
- **Given:** a board with a thread
- **When:** I tap the line with a finger
- **Then:** a panel over the top of the board shows the last messages of the thread in full and what is live, the ink below hasn't moved, and the Pencil still draws below it

- **Scenario:** On a phone
- **Given:** a board with a thread, on an iPhone
- **When:** I tap the line
- **Then:** Chat opens on the board's thread

