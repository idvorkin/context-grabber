# The whiteboard: The board and the list

Drawing on the iPad with the Pencil on a board bigger than the screen: the board list, rename and delete, the bar and the Board menu, colour, the grid, paste, undo and redo, the cheat sheet and feedback. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

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

### User Story 347:

- **Summary:** See the iPad's boards on the phone
- **Issues:** [#1002](https://github.com/idvorkin/context-grabber/issues/1002) (an upload sometimes fails *Batch Request Failed / Atomic failure*, the first sync of a launch)
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and the review fixes in [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5); verified by host tests (`BoardIndexTests`: read-only off the drawing device, the merge, a failed fetch retried) and the simulator (the boards open, iCloud skipped with no account); an iPad board on the phone not yet seen; a failed sync's log line names its step and each record's own CloudKit error (#1002, instrumentation only) in [6ccd13a](https://github.com/idvorkin/context-grabber/commit/6ccd13a), its fields verified by host tests (`BoardSyncFailureTests`); the iPad's log then named the tombstone delete sent in the board's batch (CKError 22/2024 *Atomic failure*, no error on the save), fixed by story 1093

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

### User Story 1093:

- **Summary:** An upload iCloud turns down goes up by itself
- **Issues:** [#1002](https://github.com/idvorkin/context-grabber/issues/1002) (an upload sometimes fails *Batch Request Failed / Atomic failure*, the first sync of a launch)
- **Status:** implemented in [17a8f56](https://github.com/idvorkin/context-grabber/commit/17a8f56a): the save and the delete go in two calls, and a failed sync tries again by itself after 15 s, doubling to five minutes, eight tries at most before it waits for the next time the list opens or the app comes forward; verified by host tests (`BoardSyncRetryTests`), the Mac build and the simulator (the whiteboard UI tests and the smoke's whiteboard section, iCloud skipped there); a retried upload on the iPad not yet seen

#### Use Case:
- **As someone** who closes the app on the iPad with ink not yet sent
- **I want** the board to reach iCloud without my doing anything when iCloud turns its upload down once
- **so that** the phone shows what I drew

#### Acceptance Criteria:
- **Scenario:** iCloud turns an upload down
- **Given:** I closed the app on the iPad with ink not yet sent, and on the next launch iCloud refuses the board's upload
- **When:** I wait on the list without touching anything
- **Then:** the list says boards aren't syncing, the board is as I drew it, and within a minute or so it goes up by
  itself and the note goes; on the phone the board then shows that ink

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

---

### User Story 836:

- **Summary:** Rename a board from its row's swipe
- **Status:** implemented in [d9fd5cf](https://github.com/idvorkin/context-grabber/commit/d9fd5cf), the rename menu on the board's bar taken out again in [d33c7d0](https://github.com/idvorkin/context-grabber/commit/d33c7d0) (it kept the iPad's Board menu up after a pick; a plain tap on the bar's name renames again since story 1160); verified by host tests (`BoardIndexTests.testARenameIsKeptAndReachesTheOtherDevices`: the name kept through the list's save, not undone by iCloud's older copy, shown on the phone, which offers no Rename; `just test`) and on an iPad simulator (`WhiteboardRowDeleteUITests.testABoardDrawnHereIsRenamedFromItsRowAndShowsItInItsBar`: the swipe's Rename beside Delete, the long press's, the row and the bar taking the name); the real iPad not yet tried
- **Issues:** [#916](https://github.com/idvorkin/context-grabber/issues/916) ("Log bug: Rename boards")
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The boards*

#### Use Case:
- **As someone** with several boards named for the day they were started
- **I want to** rename a board where I'd look for it, a swipe on its row as in Mail or Chat
- **so that** I can tell my boards apart by what's on them

#### Acceptance Criteria:
- **Scenario:** From the list
- **Given:** the list, with a row for a board this device drew, named *Board, Nov 16*
- **When:** I swipe the row left, tap *Rename*, type *Energy week* and confirm
- **Then:** the row says *Energy week*, at the top, and opening the board its bar says *Energy week*

---

### User Story 878:

- **Summary:** A rename with no name changes nothing
- **Status:** implemented in [d9fd5cf](https://github.com/idvorkin/context-grabber/commit/d9fd5cf) (story 836); verified by host tests (`BoardIndexTests.testRenameIsTrimmedAndCountsAsAChange`: a blank name ignored; `just test`); *Cancel* on the simulator not yet tried
- **Issues:** [#916](https://github.com/idvorkin/context-grabber/issues/916)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The boards*

#### Use Case:
- **As someone** renaming a board from its row (story 836)
- **I want to** back out of a rename without losing the name it had
- **so that** a slip of the finger never leaves a board nameless

#### Acceptance Criteria:
- **Scenario:** Nothing changes
- **Given:** the rename box is open for a board named *Board, Nov 16*
- **When:** I clear the name and confirm, or tap *Cancel*
- **Then:** the board keeps the name *Board, Nov 16*

---

### User Story 879:

- **Summary:** Another device's board offers no Rename
- **Status:** implemented in [d9fd5cf](https://github.com/idvorkin/context-grabber/commit/d9fd5cf) (story 836: the swipe's Rename only for a board this device drew, as the long press already was); verified by host tests (`BoardIndexTests.testARenameIsKeptAndReachesTheOtherDevices`: the phone offers no Rename; `just test`)
- **Issues:** [#916](https://github.com/idvorkin/context-grabber/issues/916)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The boards*

#### Use Case:
- **As someone** with boards drawn on the iPad and seen on the phone
- **I want to** rename a board only on the device that drew it
- **so that** two devices never fight over a board's name

#### Acceptance Criteria:
- **Scenario:** Another device's board
- **Given:** a board drawn on another device
- **When:** I swipe or long-press its row
- **Then:** it offers *Delete* and no *Rename*


---

### User Story 1160:

- **Summary:** Rename a board by tapping its name in the board's own bar
- **Status:** implemented in [156f1273](https://github.com/idvorkin/context-grabber/commit/156f1273); verified by host tests (`just native-test`) and the Mac build (`just native-build-mac`); on an iPad simulator (`WhiteboardTitleRenameUITests`: a tap on the name opens the box filled with it, a long name shows cut short with every bar button still there, the next stroke draws, the Board menu takes Grey and closes, the row takes the name, another device's board has no tappable name; `WhiteboardRowDeleteUITests` and `WhiteboardPaperLinesUITests.testTheFirstStrokeAfterChoosingTheSameColourDraws` still pass); the real iPad not yet tried
- **Issues:** bead context-grabber-5chm (Igor, 2026-11-22: he looked for rename inside a board and couldn't find it)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Rename from the board's own bar*

#### Use Case:
- **As someone** with a board open who wants to give it a better name
- **I want to** tap the board's name at the top of the board and rename it there
- **so that** I don't have to go back to the list and find the row's swipe or long press

#### Acceptance Criteria:
- **Scenario:** Renamed from inside the board
- **Given:** a board this iPad draws, open, named *Board, Nov 22*
- **When:** I tap *Board, Nov 22* in the board's top bar, type *Energy week* and tap *Rename*
- **Then:** the bar says *Energy week* at once, the next stroke draws, the Board menu still opens and closes, back in the list the row says *Energy week* at the top, the other devices take the name on their next sync, and the next picture sent to Larry carries *Energy week* as the board's name

- **Scenario:** Cancel, or a blank name
- **Given:** the rename box opened from the board's name
- **When:** I tap *Cancel*, or clear the name and tap *Rename*
- **Then:** the board keeps its name (story 878)

- **Scenario:** A look-only board
- **Given:** a board another device draws, an old-canvas board, or any board on an iPhone, open
- **When:** I tap its name in the bar
- **Then:** nothing happens; the name is only the name (an iPhone renames its own boards from the list)

- **Scenario:** A long name
- **Given:** a board renamed to a name longer than the bar has room for
- **When:** I look at the bar
- **Then:** the name is cut short and every button stays on the bar

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

### User Story 390:

- **Summary:** Paste text onto the board as ink
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597), [#996](https://github.com/idvorkin/context-grabber/issues/996)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); the layout verified by host tests (`WhiteboardPasteTests`); on the simulator (`WhiteboardPasteUITests`), ⌘V from a real clipboard with no prompt, and through a launch hook each line and Claude's pause; the ink's look checked by eye at its pen width in dark mode. Still to try on the iPad: the Paste button itself (XCUITest's taps never fire the system control) and that it shows no prompt, zoomed-out and zoomed-in pastes, sync to the other device; written in single strokes in [c0b61e1](https://github.com/idvorkin/context-grabber/commit/c0b61e1) (#996), verified by host tests (`WhiteboardPasteTests`: a letter's own strokes, curly typography, rows by the written width) and the simulator's whiteboard smoke; the paste UI tests (`WhiteboardPasteUITests`, `WhiteboardPaperPasteUITests`) pass on the iPad simulator (rung 2, 2026-11-20), and the paste counts in the Outline and Paper Lines classes (`WhiteboardOutlineUITests`, `WhiteboardPaperLinesUITests`) followed in [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) and [3d3842fe](https://github.com/idvorkin/context-grabber/commit/3d3842fe)
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** thinking on the board with words already on my clipboard
- **I want to** paste them with the bar's Paste button or ⌘V
- **so that** they sit on the board as ink and travel with its picture to Larry and Claude

#### Acceptance Criteria:
- **Scenario:** A paste becomes ink
- **Given:** a board I can draw on is open and the clipboard holds two lines of text
- **When:** I tap Paste or press ⌘V
- **Then:** both lines appear as thin ink, written in single strokes like Larry's labels (#996), in the middle of what's on screen with no *Allow Paste?* prompt, the board saves it, and about a second later Claude's ghosts come

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
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); no outline means no ink verified by host tests (`WhiteboardPasteTests`); the note and the untouched board on the simulator (`WhiteboardPasteUITests`, through a launch hook); which note, a host test since bead `context-grabber-y8r`. Since story 770 the note's words are `WhiteboardPasteTests` and its place on the bar `WhiteboardNoteTests`, on the host; the simulator no longer pastes emoji
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
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); not verified by a test; changed in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac) (#1005: no Paste without text), verified on the iPad simulator by `WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole`; to try on the iPad: no Paste on a look-only board, ⌘V doing nothing on either
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** looking at a board with nothing to paste, or one another device draws
- **I want to** have Paste and ⌘V stay out of the way
- **so that** nothing lands where it can't or shouldn't

#### Acceptance Criteria:
- **Scenario:** No paste to make
- **Given:** the clipboard holds neither text nor copied strokes, or the board is look-only
- **When:** I look at the bar or press ⌘V
- **Then:** there is no Paste in the bar and ⌘V does nothing

---

### User Story 395:

- **Summary:** Strokes I copied still paste
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented on this branch; changed in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac) (#1005: no Paste without text); not verified by a test (on the simulator, PencilKit's canvas was seen to have its own paste); to try on the iPad with a hardware keyboard
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** moving ink around with the lasso
- **I want to** paste the strokes I copied with ⌘V
- **so that** pasting text doesn't cost me the system's paste of ink

#### Acceptance Criteria:
- **Scenario:** Copied strokes
- **Given:** a board I can draw on is open and the clipboard holds strokes copied with the lasso and no text
- **When:** I press ⌘V
- **Then:** the strokes land the way the system always pastes them, and there is no Paste in the bar

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

### User Story 1054:

- **Summary:** The board's bar has no hole: Paste shows only with text to paste, beside the Board menu
- **Status:** implemented in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac); verified on the iPad simulator (`just test-ladder`: `WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole` with no text on the clipboard, `WhiteboardPasteUITests` and `WhiteboardPaperGhostsUITests` with text on it, and the whiteboard's other UI classes) and the Mac build; changed in [53231df](https://github.com/idvorkin/context-grabber/commit/53231df) (text copied in an app beside the board shows Paste within about a second), not verified by a test. Not yet seen on the iPad; *Larry's turn* and *Send to Larry* made one button (story 1176) in [65ebde40](https://github.com/idvorkin/context-grabber/commit/65ebde40), verified by host tests and the whiteboard UI tests on the iPad simulator
- **Issues:** [#1005](https://github.com/idvorkin/context-grabber/issues/1005) (design critique of the iPad board, 2026-11-20: unlabelled sparkle and hand, a large gap between the palette and the mic)
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *The top bar's groups and labels*

#### Use Case:
- **As someone** reaching for Larry's buttons at the top of a board
- **I want to** see the bar's buttons evenly spaced, the board's own menu in a group of its own
- **so that** a blank space doesn't look like a missing or broken button

#### Acceptance Criteria:
- **Scenario:** Nothing to paste
- **Given:** a board open on an iPad and no text on the clipboard
- **When:** I look at the top bar
- **Then:** the Board menu sits in a group of its own, Talk, Ghosts and Send are evenly spaced in theirs (*Larry's turn* became Send, story 1176), and there is no empty space; once I copy some text, here or in an app beside the board, Paste appears beside the Board menu within about a second and the other three don't move

---

### User Story 1055:

- **Summary:** A long press on a bar button says its name
- **Status:** implemented in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac); verified on the iPad simulator (`WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole`: a long press on Ghosts shows the *Ghosts* menu, its row turns them off, a tap turns them back on) and the Mac build. Not yet seen on the iPad; *Larry's turn* and *Send to Larry* made one button (story 1176) in [65ebde40](https://github.com/idvorkin/context-grabber/commit/65ebde40), verified by host tests and the whiteboard UI tests on the iPad simulator
- **Issues:** [#1005](https://github.com/idvorkin/context-grabber/issues/1005) (design critique of the iPad board, 2026-11-20: unlabelled sparkle and hand, a large gap between the palette and the mic)
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *The top bar's groups and labels*

#### Use Case:
- **As someone** who sees a sparkle and a hand in the board's bar
- **I want to** find out what each one does without trying it
- **so that** I don't send Larry a picture or turn off Claude's suggestions by accident

#### Acceptance Criteria:
- **Scenario:** Long press the sparkle
- **Given:** a board open with Ghosts on
- **When:** I press and hold the sparkle
- **Then:** a small menu headed *Ghosts* shows one row, *Hide Claude's suggestions*, which does it if I tap it; Talk and Send name themselves the same way (Talk's menu also lists the microphones under its row, story 926), and a plain tap on any of them does what it always did

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

### User Story 1107:

- **Summary:** A pick in the open Board menu always takes
- **Status:** implemented in [76e506aa](https://github.com/idvorkin/context-grabber/commit/76e506aa); verified on iPad Pro 11-inch (M5) simulators in three build lanes at once (rung 2): `testTidyOverlapsOnATidyBoardSaysNothingOverlaps` 30 of 30, no row tap cancelled and the on-screen keyboard never put up again behind the open menu (before it 9 of 12, 3 Tidy taps cancelled, 26 re-posts); `WhiteboardPaperGhostsUITests`, `WhiteboardTurnUITests` and `WhiteboardPaperLinesUITests` all passing, the last with no second tap (#880's). The cause, read from the simulator: every look at Larry's thread (each 3 s) and every save set the Board button's menu again, and UIKit swapped the open menu's rows under the finger. Not yet tried on the iPad, where it can only show on a board with a Larry thread
- **Issues:** bead `context-grabber-664d`, [#880](https://github.com/idvorkin/context-grabber/issues/880), [#850](https://github.com/idvorkin/context-grabber/issues/850)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** choosing a colour, lines or *Tidy overlaps* on a board Larry has seen
- **I want to** have my tap on a row in the Board menu take every time
- **so that** I never pick something, see the menu stay open, and have to wonder whether it happened

#### Acceptance Criteria:
- **Scenario:** The board works behind an open menu
- **Given:** a board of mine is open with its Board menu up, and the board is looking at Larry's thread every few seconds or has just saved
- **When:** I tap any row in the menu, at any moment
- **Then:** that row is chosen and the menu closes; the menu is never put up again while it stays open unless what it shows (the colour, the lines, the font or the responder) changed

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
- **When:** Claude's orange ghosts and Larry's purple ones show
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

- **Summary:** A new board opens with the grid on
- **Status:** first implemented as *A new board has no grid* in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); reversed to the grid on (Igor, 2026-11-16, #915) in [c0e22ba](https://github.com/idvorkin/context-grabber/commit/c0e22ba); verified by host tests (`BoardLinesTests`: a new board's grid on, a board with no saved choice off, a saved choice kept, ruled lines taking the grid's place; `just test`); verified on an iPad simulator (`WhiteboardPaperLinesUITests.testANewBoardOpensWithTheGrid`, and the class's other tests with new boards started bare by `GRABBER_WHITEBOARD_GRID=off`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608), [#915](https://github.com/idvorkin/context-grabber/issues/915) ("Log bug: default new boards have grid lines")

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** start each new board with faint grid lines
- **so that** I can line things up from the first stroke without going to the Board menu

#### Acceptance Criteria:
- **Scenario:** New board
- **Given:** another board has its grid off
- **When:** I make a new board
- **Then:** its grid is on, and the Board menu shows *Grid lines* chosen

---

### User Story 888:

- **Summary:** A board made before new boards had the grid keeps no grid
- **Status:** implemented in [c0e22ba](https://github.com/idvorkin/context-grabber/commit/c0e22ba) (story 410, #915); verified by host tests (`BoardLinesTests`: a board with no saved choice off, a saved choice kept; `just test`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#915](https://github.com/idvorkin/context-grabber/issues/915)

#### Use Case:
- **As someone** with boards from before new boards opened with the grid (story 410)
- **I want to** find those boards as I left them
- **so that** a change to the default never redraws a page I already made

#### Acceptance Criteria:
- **Scenario:** A board made before
- **Given:** a board made before new boards had the grid, never given one
- **When:** I open it
- **Then:** it has no grid, as before

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

### User Story 746:

- **Summary:** On an iPhone, boards are for looking, not drawing
- **Status:** implemented in [df438e6](https://github.com/idvorkin/context-grabber/commit/df438e6), [d053c9a](https://github.com/idvorkin/context-grabber/commit/d053c9a); verified by host tests (`BoardIndexTests`), `PhoneBoardsUITests` on the iPhone simulator, and the whiteboard classes on the iPad simulator (`just test-ladder`). Since story 770 the iPhone simulator's check is the smoke's whiteboard section, from the session log: the list's `new_board` false, and its own board on paper opening with `editable` false and `look_only` *Look only on iPhone: draw on the iPad*; *Send to Larry* still being there on a phone is no longer checked by a test; a phone's Send goes to the board's one conversation, the thread the board carries, since story 1158 (bead context-grabber-da1)
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

---

### User Story 852:

- **Summary:** A paste never lands on my ink: it finds clear paper or opens room
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardRoomTests`: the middle of an empty view, the clear patch nearest the middle never touching ink, room at the clear line nearest the middle by whole lines beyond the blank already there, hidden ink no obstacle); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** pasting text onto a full board
- **I want to** have the paste go to clear paper on screen, or have room open for it
- **so that** nothing I wrote is ever covered

#### Acceptance Criteria:
- **Scenario:** Clear paper on screen
- **Given:** a screen with ink at its middle and clear paper above it
- **When:** I paste two lines
- **Then:** they land in the clear paper nearest the middle and nothing moves

---

### User Story 869:

- **Summary:** A paste on a full screen opens room for itself
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardRoomTests`: the middle of an empty view, the clear patch nearest the middle never touching ink, room at the clear line nearest the middle by whole lines beyond the blank already there, hidden ink no obstacle); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** pasting onto a screen written on every line
- **I want to** have room open for the paste in one undo
- **so that** nothing I wrote is covered

#### Acceptance Criteria:
- **Scenario:** A full screen
- **Given:** writing on every line of the screen
- **When:** I paste
- **Then:** the ink from the middle down moves down whole lines, the paste sits in the room against the margin, and one Undo named Paste puts the board back exactly

---

### User Story 853:

- **Summary:** A paste lands selected with Delete beside it
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea), the Delete's test in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f); a simulator UI test, `WhiteboardOutlineUITests.testAPasteLandsSelectedAndDeleteTakesItAway`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** who pasted the wrong thing
- **I want to** take the paste straight back off the board
- **so that** an accidental paste costs one tap

#### Acceptance Criteria:
- **Scenario:** Delete it
- **Given:** a paste that just landed
- **When:** I tap Delete beside it
- **Then:** the paste goes, the room it opened stays, and Undo brings the paste back

---

### User Story 870:

- **Summary:** Delete goes once I move on from a paste
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea), the Delete's test in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f); a simulator UI test, `WhiteboardOutlineUITests.testAPasteLandsSelectedAndDeleteTakesItAway`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** who pasted and carried on working
- **I want to** have the paste's Delete go away when I draw or select something else
- **so that** Delete is only offered for what just landed

#### Acceptance Criteria:
- **Scenario:** Move on
- **Given:** a paste that just landed, selected
- **When:** I draw or select something else
- **Then:** Delete goes away

---

### User Story 950:

- **Summary:** The board's cheat sheet is one tap away
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) the ? opened *How this board works* listing every gesture the test names; its close and the fixed test's full pass not yet seen (the Mac's screen was locked for the rerun); not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*

#### Use Case:
- **As someone** drawing on a board whose gestures I don't all remember
- **I want to** open a list of them with one tap on the board, as on Larry's web board
- **so that** I find the margin, hold and Pencil gestures without asking anyone

#### Acceptance Criteria:
- **Scenario:** Open the cheat sheet
- **Given:** a board drawn on this iPad
- **When:** I tap **?** at the board's top right
- **Then:** *How this board works* opens and lists the margin tap, the margin hold with a finger or the Pencil, the hold
  on the page, the Pencil on a word, scratch-out, the lasso's *To text*, the shape snap, *Keep all*, *Fold all* and the
  levels, and Feedback; *Done* closes it and the board is as it was

---

### User Story 951:

- **Summary:** The cheat sheet's buttons leave the top bar alone
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) the Board menu, Paste, the mic, Ghosts, Larry's turn and Send stayed in the top bar with ? and Feedback on the board; at the lower right the Pencil's tool palette took their taps, so they moved to the top right in 2a01b5c; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*
- **Issues:** [#848](https://github.com/idvorkin/context-grabber/issues/848) (the Board menu must stay in the iPad's bar and close on a pick)

#### Use Case:
- **As someone** who reaches for the Board menu, Larry's turn and Send many times a board
- **I want to** have **?** and Feedback added beside the paper, not to the top bar or the Board menu
- **so that** nothing I already use moves under *More* or makes the menu too tall to close

#### Acceptance Criteria:
- **Scenario:** The bar after the change
- **Given:** a board drawn on this iPad
- **When:** it opens
- **Then:** the Board menu, Paste, the mic, Ghosts, Larry's turn and Send are in the top bar as before, and **?** and
  Feedback float at the board's top right; a look-only board shows Feedback only

---

### User Story 952:

- **Summary:** Feedback from the board is one tap
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) a tap on Feedback opened *Report a problem* over the board; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*

#### Use Case:
- **As someone** who reports the board's bugs to Larry from the board itself
- **I want to** tap Feedback on the board and get the report sheet with the board's picture and the log
- **so that** I don't have to shake the iPad or leave the board to report

#### Acceptance Criteria:
- **Scenario:** Report from the board
- **Given:** a board open
- **When:** I tap Feedback at the board's top right
- **Then:** the *Report a problem* sheet opens over the board with a picture of the board as it was and the session
  log, as a shake would open it

---

### User Story 966:

- **Summary:** The Feedback button is a ladybug with no word beside it
- **Status:** implemented in [7c937884](https://github.com/idvorkin/context-grabber/commit/7c937884); `just native-test` and `just native-build-mac` green, and on the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-22) the ladybug was no wider than the **?** and still read *Feedback*; not yet seen on the phone
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*
- **Issues:** [#1162](https://github.com/idvorkin/context-grabber/issues/1162) (Igor on the iPhone, 2026-11-22: "Just a bug buttons enough I don't need to say feedback"; the word covered the board's ink)

#### Use Case:
- **As someone** drawing on a board, on the iPad or the iPhone
- **I want to** have Feedback be the ladybug alone, the size of the **?** beside it
- **so that** the button doesn't cover the board's ink

#### Acceptance Criteria:
- **Scenario:** The button is only a ladybug
- **Given:** a board open, on the iPad or the iPhone
- **When:** I look at the board's top right
- **Then:** Feedback is a ladybug with no word beside it, no wider than the **?** next to it, and VoiceOver reads it
  as *Feedback*

---

### User Story 953:

- **Summary:** The board says the feedback was logged
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) not yet seen: the run that would log a note and see *Feedback logged ✓* was the rerun the locked screen stopped; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*

#### Use Case:
- **As someone** who just sent feedback from the board
- **I want to** see on the board that it was taken
- **so that** I know it landed without going to look for it

#### Acceptance Criteria:
- **Scenario:** Log it
- **Given:** the report sheet opened from the board, with a note written
- **When:** I tap *Log it*
- **Then:** the sheet closes and *Feedback logged ✓* shows beside the board's buttons for a few seconds; *logged*, not
  *sent*, as the report is saved and queued for iCloud and the app is not told when it arrives

---

### User Story 1008:

- **Summary:** Undo and Redo on the board's own bar
- **Status:** implemented in [11536e97](https://github.com/idvorkin/context-grabber/commit/11536e97), [73d8e538](https://github.com/idvorkin/context-grabber/commit/73d8e538); verified by host tests (`BoardUndoButtonsTests`: dimmed on a new board, *Undo Keep group* for a named step, plain *Undo* for his stroke, PencilKit's *Add Strokes* read as plain *Undo*, no name on a dimmed button), `just test` and the Mac build (`just native-build-mac`); on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testTheBarsUndoAndRedoTakeAStepBackAndNameAKeptGroup`: 44 points wide, the bar's 36 high, plain *Undo* for a stroke, *Undo Keep group* taking the group back); not yet seen on the iPad
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *Undo and Redo on the board's own bar*
- **Issues:** [#965](https://github.com/idvorkin/context-grabber/issues/965): Igor, 2026-11-19, drawn on board 302d5345, via Larry: "an Undo button on the board itself"

#### Use Case:
- **As someone** drawing on a board with a finger or the Pencil
- **I want** Undo and Redo buttons on the board's bar
- **so that** I can take back a step without hunting for the tool picker's

#### Acceptance Criteria:
- **Scenario:** Undo a stroke and bring it back
- **Given:** a board drawn on here, and I have just drawn a stroke
- **When:** I tap *Undo* in the board's bar, then *Redo*
- **Then:** the stroke goes, then comes back; each button is at least 44 points wide and the bar's own height (36 points on the iPad), and each is dimmed when there is nothing for it to do

---

### User Story 1009:

- **Summary:** VoiceOver says what Undo will take back
- **Status:** implemented in [11536e97](https://github.com/idvorkin/context-grabber/commit/11536e97), [73d8e538](https://github.com/idvorkin/context-grabber/commit/73d8e538); verified by host tests (`BoardUndoButtonsTests`: dimmed on a new board, *Undo Keep group* for a named step, plain *Undo* for his stroke, PencilKit's *Add Strokes* read as plain *Undo*, no name on a dimmed button), `just test` and the Mac build (`just native-build-mac`); on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testTheBarsUndoAndRedoTakeAStepBackAndNameAKeptGroup`: 44 points wide, the bar's 36 high, plain *Undo* for a stroke, *Undo Keep group* taking the group back); not yet seen on the iPad
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *Undo and Redo on the board's own bar*
- **Issues:** [#965](https://github.com/idvorkin/context-grabber/issues/965)

#### Use Case:
- **As someone** using the board with VoiceOver
- **I want** the Undo and Redo buttons to name the step they act on
- **so that** I know a press takes back Larry's kept group and not my last stroke

#### Acceptance Criteria:
- **Scenario:** A named step on top
- **Given:** I have just kept a group of Larry's marks
- **When:** VoiceOver reaches the Undo button
- **Then:** it reads *Undo Keep group*; for my own stroke it reads *Undo*, and with nothing to undo it says the button is dimmed

---

### User Story 958:

- **Summary:** I watch a board draw itself again in the order I drew it, and jump to any stroke
- **Issues:** [#1139](https://github.com/idvorkin/context-grabber/issues/1139) (Igor, 2026-11-22: "where is my replay button so I can rewatch it the way you do in Notability?"); [#1169](https://github.com/idvorkin/context-grabber/issues/1169) (Igor, 2026-11-22: "start with a pre-written ghost on the page and … whatever the default background is"); bead context-grabber-zj39 (the UI test's first run)
- **Status:** implemented in [23568982](https://github.com/idvorkin/context-grabber/commit/23568982), [54484b30](https://github.com/idvorkin/context-grabber/commit/54484b30) (bead context-grabber-3tdv; the ink alone, Igor 2026-11-22); verified by host tests (`BoardPlaybackTests`: the order, the hand's pace, a pause over 2 s as 0.5 s, strokes sharing a moment together, the frames, a tap's stroke, the playhead's play, pause, ±10 s, seek, speeds and end), `just test` and the Mac build (`just native-build-mac`, rung 1.5); `WhiteboardPlaybackUITests` on the iPad simulator first ran later, see below; the paper and the ghost (#1169) in [5df4fb2a](https://github.com/idvorkin/context-grabber/commit/5df4fb2a), verified by `just test` and the Mac build (rung 1.5); and on the iPad simulator (rung 2, 2026-11-22, `WhiteboardPlaybackUITests` in [ad66acb5](https://github.com/idvorkin/context-grabber/commit/ad66acb5), bead context-grabber-zj39; green on lane 2's iPad, whose tool picker an earlier class had left on the eraser, and on lane 1's, with the pen already picked): *Play* showed only with ink, the board's bar went while it played, the three strokes drew again to *Stroke 3 of 3, paused*, and `playback_start` logged the ghost; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*

#### Use Case:
- **As someone** who thinks on a board and comes back to it later
- **I want to** watch the board draw itself again, stroke by stroke, at the pace I drew it, and jump to any stroke
- **so that** I can follow how the thinking went, not only where it ended

#### Acceptance Criteria:
- **Scenario:** Play a board
- **Given:** a board with three strokes drawn a minute apart
- **When:** I tap *Play*, beside *?* and *Feedback*
- **Then:** the board shows faint, the whole of it, on its own paper, and the strokes draw again over that ghost in their order, each at the pace I drew it, the minute between them half a second, and the board's own bar and tool picker are gone while it plays

- **Scenario:** The board's paper and its ghost (#1169)
- **Given:** a grid board of three pages, written on all three
- **When:** I tap *Play*
- **Then:** playback shows the same grid and the faint lines where the pages end, and the whole board faint from the first moment; each stroke drawn again shows at full strength over its own ghost, and at the end the board looks as it does outside playback

- **Scenario:** A board with no ink
- **Given:** a new board with nothing on it
- **When:** I look beside *?* and *Feedback*
- **Then:** there is no *Play*

---

### User Story 954:

- **Summary:** In playback, a bar lets me pause, skip 10 s, scrub and change the speed
- **Issues:** [#1139](https://github.com/idvorkin/context-grabber/issues/1139); bead context-grabber-zj39 (the UI test's first run)
- **Status:** implemented in [23568982](https://github.com/idvorkin/context-grabber/commit/23568982), [54484b30](https://github.com/idvorkin/context-grabber/commit/54484b30) (bead context-grabber-3tdv; the ink alone, Igor 2026-11-22); verified by host tests (`BoardPlaybackTests`: the order, the hand's pace, a pause over 2 s as 0.5 s, strokes sharing a moment together, the frames, a tap's stroke, the playhead's play, pause, ±10 s, seek, speeds and end), `just test` and the Mac build (`just native-build-mac`, rung 1.5); and on the iPad simulator (rung 2, 2026-11-22, `WhiteboardPlaybackUITests` in [ad66acb5](https://github.com/idvorkin/context-grabber/commit/ad66acb5), bead context-grabber-zj39; green on lane 2's iPad, whose tool picker an earlier class had left on the eraser, and on lane 1's, with the pen already picked): the speed stepped from *1×* to *1.25×*, play went on to *Stroke 3 of 3, paused* and 10 s back to *Stroke 0 of 3*; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*

#### Use Case:
- **As someone** watching a board play back
- **I want** play and pause, 10 s back and on, a handle to drag, and Notability's speeds
- **so that** I can watch the part I care about at the pace I like

#### Acceptance Criteria:
- **Scenario:** The bar
- **Given:** a board playing back
- **When:** I look at the bar along the bottom
- **Then:** it shows the time played of the whole and which stroke of how many, with play and pause, 10 s back, 10 s on, a handle to drag to any moment, and a speed button at 1×

- **Scenario:** Change the speed
- **Given:** playback at 1×
- **When:** I tap the speed button
- **Then:** it steps to 1.25×, then 1.5×, 2× and 0.7×, and back to 1×

- **Scenario:** The end
- **Given:** playback has drawn the last stroke
- **When:** it reaches the end
- **Then:** it stops with the whole board shown, and play starts again from the beginning

---

### User Story 956:

- **Summary:** In playback, a tap on a stroke jumps to the moment I drew it
- **Issues:** [#1139](https://github.com/idvorkin/context-grabber/issues/1139), [#1169](https://github.com/idvorkin/context-grabber/issues/1169); bead context-grabber-zj39 (the strokes' elements, the UI test's first run)
- **Status:** implemented in [23568982](https://github.com/idvorkin/context-grabber/commit/23568982), [54484b30](https://github.com/idvorkin/context-grabber/commit/54484b30) (bead context-grabber-3tdv; the ink alone, Igor 2026-11-22); verified by host tests (`BoardPlaybackTests`: the order, the hand's pace, a pause over 2 s as 0.5 s, strokes sharing a moment together, the frames, a tap's stroke, the playhead's play, pause, ±10 s, seek, speeds and end), `just test` and the Mac build (`just native-build-mac`, rung 1.5); `WhiteboardPlaybackUITests` on the iPad simulator first ran later, see below; a tap on faint ink (#1169) in [5df4fb2a](https://github.com/idvorkin/context-grabber/commit/5df4fb2a), verified by the Mac build (rung 1.5); each stroke's element kept from one ask to the next in [ad66acb5](https://github.com/idvorkin/context-grabber/commit/ad66acb5) (bead context-grabber-zj39: made afresh at each ask, two of three were empty in the accessibility tree, so VoiceOver and the test found only the last), then on the iPad simulator (rung 2, 2026-11-22, `WhiteboardPlaybackUITests` in [ad66acb5](https://github.com/idvorkin/context-grabber/commit/ad66acb5), bead context-grabber-zj39; green on lane 2's iPad, whose tool picker an earlier class had left on the eraser, and on lane 1's, with the pen already picked): a tap on the second stroke, every stroke drawn, went back to *Stroke 1 of 3, paused* (`playback_seek` how: tap); a tap on faint ink not yet drawn is the host's (`BoardPlaybackTests`) and the iPad's; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*

#### Use Case:
- **As someone** watching a board play back
- **I want to** tap a stroke to jump to when I drew it
- **so that** I can go straight to the part of the thinking I care about

#### Acceptance Criteria:
- **Scenario:** Tap a stroke during playback
- **Given:** a board with three strokes playing back, the second stroke already drawn again
- **When:** I tap the second stroke
- **Then:** playback goes back to the moment the second stroke began: the first stroke showing, the second next, playing or paused as it was

- **Scenario:** Tap faint ink not drawn yet (#1169)
- **Given:** a board with three strokes playing back, only the first drawn again, the third showing faint
- **When:** I tap the third stroke's ghost
- **Then:** playback goes on to the moment the third stroke began: the first two showing, the third next

- **Scenario:** Tap bare paper
- **Given:** a board playing back
- **When:** I tap paper with no stroke near
- **Then:** nothing happens

---

### User Story 957:

- **Summary:** Leaving playback shows the board as it was, with nothing changed
- **Issues:** [#1139](https://github.com/idvorkin/context-grabber/issues/1139); bead context-grabber-zj39 (the UI test's first run)
- **Status:** implemented in [23568982](https://github.com/idvorkin/context-grabber/commit/23568982), [54484b30](https://github.com/idvorkin/context-grabber/commit/54484b30) (bead context-grabber-3tdv; the ink alone, Igor 2026-11-22); verified by host tests (`BoardPlaybackTests`: the order, the hand's pace, a pause over 2 s as 0.5 s, strokes sharing a moment together, the frames, a tap's stroke, the playhead's play, pause, ±10 s, seek, speeds and end), `just test` and the Mac build (`just native-build-mac`, rung 1.5); and on the iPad simulator (rung 2, 2026-11-22, `WhiteboardPlaybackUITests` in [ad66acb5](https://github.com/idvorkin/context-grabber/commit/ad66acb5), bead context-grabber-zj39; green on lane 2's iPad, whose tool picker an earlier class had left on the eraser, and on lane 1's, with the pen already picked): *Done* showed the same three strokes, saved, the same *Undo*, and *Send to Larry* still enabled; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*

#### Use Case:
- **As someone** who watched a board play back
- **I want to** leave playback and find the board exactly as I left it
- **so that** watching never costs me ink, an undo step or a message to Larry

#### Acceptance Criteria:
- **Scenario:** Finish playback
- **Given:** a board playing back
- **When:** I choose *Done*
- **Then:** the board shows as it was, with nothing saved, no undo step and nothing sent to Larry

---

### User Story 1111:

- **Summary:** In playback, a label says when the stroke being drawn is above or below the screen, and on which page
- **Issues:** [#1169](https://github.com/idvorkin/context-grabber/issues/1169) (Igor, 2026-11-22: "maybe some indicator that I'm writing above or below on a separate page"); bead context-grabber-zj39 (the UI test's first run)
- **Status:** implemented in [5df4fb2a](https://github.com/idvorkin/context-grabber/commit/5df4fb2a) (#1169); verified by host tests (`BoardPlaybackOffScreenTests`: the stroke being drawn above, below or on the screen, and its page), `just test` and the Mac build (rung 1.5); on the iPad simulator (rung 2, 2026-11-22, `WhiteboardPlaybackUITests` in [ad66acb5](https://github.com/idvorkin/context-grabber/commit/ad66acb5), bead context-grabber-zj39; green on lane 2's iPad, whose tool picker an earlier class had left on the eraser, and on lane 1's, with the pen already picked): with all three strokes on the screen no label showed; *Writing above* and *Writing below* are the host's and the iPad's; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*

#### Use Case:
- **As someone** watching a board of several pages play back
- **I want to** know when the ink being drawn is off the screen, and where
- **so that** I don't watch a still page while the thinking goes on somewhere else

#### Acceptance Criteria:
- **Scenario:** Writing above
- **Given:** a three-page board playing back with page 2 on the screen
- **When:** playback draws a stroke on page 1
- **Then:** a label at the top of the board says *Writing above, page 1*; tapping it moves the board to that stroke, and the label goes

- **Scenario:** Writing below
- **Given:** the same board with page 1 on the screen
- **When:** playback draws a stroke on page 3
- **Then:** a label at the bottom says *Writing below, page 3*

- **Scenario:** Writing on the screen
- **Given:** a board playing back
- **When:** the stroke being drawn, or between strokes the one drawn last, shows on the screen even in part, or nothing has been drawn yet
- **Then:** there is no label, and playback never moves the board by itself

---

### User Story 959:

- **Summary:** In playback, a tap on a stroke tells me what I was saying as I drew it
- **Issues:** [#1139](https://github.com/idvorkin/context-grabber/issues/1139)
- **Status:** not implemented; asks: bead context-grabber-3tdv (proposed, waiting on Igor's choice between keeping the words and keeping the sound, and where the sound is kept)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*

#### Use Case:
- **As someone** who talks while drawing, as in Notability
- **I want to** see or hear what I was saying when a stroke was drawn
- **so that** the board brings back the words behind the marks

#### Acceptance Criteria:
- **Scenario:** Tap a stroke drawn while I talked
- **Given:** a board I drew on while talking (with the mic open for the words, or recording for the sound)
- **When:** I play it back and tap a stroke I drew as I talked
- **Then:** playback jumps there and shows the line I was saying then, or plays the sound from that moment
