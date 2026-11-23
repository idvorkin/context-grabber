# The whiteboard: Boards on paper

The board as a column of pages: the trial, the switch for new boards, pages and lines, and ghosts, keeping and paste on paper. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 430:

- **Summary:** I can see which page I'm on
- **Status:** implemented on paper in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (stories 591, 603); the page mostly on screen is the one at the screen's middle, verified by host tests (`BoardPagesTests`) and on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: *Page 1 of 2*) and on an iPhone 17 simulator (`WhiteboardPaperGhostsUITests.testThePictureIsThePageOnScreen`: *Page 2 of 2*, then *Page 2 of 3*, reaching page 2 through a launch hook). The corner is in no picture by construction: since [a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315) (story 433) Larry's picture is drawn from the strokes, not the screen. Reaching page 2 by scrolling with a finger is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
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
- **Status:** implemented on paper in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e) as a look-only board (story 658; Igor, 2026-11-07: "Old canvas can be erased"): its ink moved onto the first page's corner, never scaled, by the rule in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34) (story 539); verified by host tests (`BoardPagesTests`, `BoardKeepingTests`) and the simulator smoke's `paper_open` (40 strokes at the first page's corner). A look-only board takes no turns, so Larry's marks don't arise on it. Igor's own old boards on the iPad not yet seen
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
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
- **Status:** implemented on paper in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f): the pinch's floor is the zoom that fits the column's width, and it scrolls only up and down; the fit zoom verified by host tests (`BoardPagesTests`). XCUITest's pinch barely moves on an iPad simulator, so a real pinch is the iPad's. Zooming out past the page to a whole page held sideways was weighed for #636 and not wanted
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
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
- **Status:** implemented on paper in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e) (story 658): ink wider than a page widens the board by the rule in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34), never scaled, and pages get no taller; verified by host tests (`BoardPagesTests`: `testInkWiderThanAPageWidensTheBoardInsteadOfShrinking`, `testAWideBoardsPagesAreWideAndNoTaller`). Panning sideways only as far as that width hasn't been driven on a simulator, as no fixture board is wider than a page; Igor's own wide boards on the iPad not yet seen
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
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
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: killed and reopened with the same ink); #1044: every save logs `save_timing`, the time of each stage (encode, write, picture, index) with its trigger, strokes and revision and nothing of the drawing, verified by host tests (`BoardSaveTimingTests`) and the Mac build; the measurement at 100, 1,000 and 5,000 strokes on the iPad is Igor's
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636); [#1044](https://github.com/idvorkin/context-grabber/issues/1044) (bead context-grabber-a99q: what each stage of a save costs on the iPad)
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
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: the bar and the Board menu). The paste button back in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); that it's there is checked on an iPhone simulator (`WhiteboardPaperGhostsUITests`: `testAGhostShowsOnThePaperAndKeepMakesItInk`, named `testAGhostShowsOnThePaperAndATapKeepsIt` before story 825). The Board menu's grid in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653)
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
- **Then:** the Ghosts switch, the mic, *Send to Larry* and the paste button are there

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
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); verified on an iPhone simulator and an iPad simulator, where a finger draws (`WhiteboardPaperGhostsUITests`, `WhiteboardTurnOnPaperUITests`: no dot, and the next stroke draws). What a finger drag does while ghosts show, with a Pencil paired or not, isn't settled: `paper_touch`'s `touch_mode` is `selection` then. Since bead `context-grabber-y8r`, `WhiteboardPaperGhostsUITests` alone. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first (stories 663, 664). Since [6754880](https://github.com/idvorkin/context-grabber/commit/6754880) the dot PaperKit still draws under such a tap is taken back by its own undo (story 825; `PaperProbeTests`), verified on an iPad simulator by `WhiteboardPaperGhostsUITests`
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
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the fake's `/far`, *Page 1 of 6*, kept by a hook). A ghost that far down can't be seen until it's kept: the Cockpit has never been seen to answer that far from the ink. Since story 770 the pages a far mark brings are `BoardPagesTests` on the host (`testPagesAddedAsInkReachesThemAndNeverTakenBack`), and the one undo that takes them back is `WhiteboardPaperPasteUITests.testATallPasteBringsItsPagesInOneUndo`, through the same keep
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
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the same two ids at the fake Cockpit before and after closing and opening the board). `paper_keep`'s `same_ids` was true on every keep in both simulators' logs, with `drift` 0: the mark's id is the same before and after PaperKit. A real Cockpit wasn't used. Since story 770, `WhiteboardPaperGhostsUITests.testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`: the same two ids before and after the app is killed and relaunched; the names' rule is `WhiteboardStrokesTests`
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
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: killed with a ghost showing, and one stroke after the relaunch). The strokes sent to Larry hold only ink, as story 619's two ids show. Since story 770, one test with story 619's (`testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`): killed with Larry's marks showing, and two strokes after the relaunch
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
- **When:** I tap *Send to Larry*
- **Then:** his marks arrive by themselves in purple, kept by a tap like Claude's, and his words show in the bar

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
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the fake's `/far`, *Page 1 of 6* then *Page 1 of 2*, by a hook). Since story 770: `BoardPagesTests` for the pages, `WhiteboardPaperPasteUITests.testATallPasteBringsItsPagesInOneUndo` for the one undo, through the same keep (story 618)
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
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`). Extended to earlier replies in [95c5ca4](https://github.com/idvorkin/context-grabber/commit/95c5ca4), verified by host tests (`WhiteboardMarksTests`). `WhiteboardTurnUITests` covers a dismissed set staying gone
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
- **Then:** his newest set is there, with any earlier set still showing when I closed it (story 1155), and a set I
  dismissed stays gone

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
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`testAPastesStrokesKeepTheirNamesForLarry`: the same two ids at the fake Cockpit before and after a relaunch; `paper_keep`'s `same_ids` true and `drift` 0). That the letters are in the picture is the old canvas's code, on the same drawing, and wasn't looked at. A real Cockpit wasn't used. Since story 770 the names through a relaunch are `WhiteboardPaperGhostsUITests.testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`, through the keep and the save a paste shares, and the names' rule `WhiteboardStrokesTests`
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
- **Status:** implemented in [869cb8d](https://github.com/idvorkin/context-grabber/commit/869cb8d); the simulator only, iPhone 17, iOS 27: pasted ink missing from the screen in 15 of 180 runs before the fix, 0 of 60 after it (`testAPasteLandsInTheMiddleOfThePaperOnScreen`, read from `paper_ink_look`). The wait for the view to come to rest came after those counts, in [a86ac93](https://github.com/idvorkin/context-grabber/commit/a86ac93). A centred page skipped the redraw in [97bbdbe](https://github.com/idvorkin/context-grabber/commit/97bbdbe), verified on an iPad Pro 11-inch simulator (`testAGhostLeftShowingIsNotSaved`: crashed before, passes after; since story 770 part of `testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`). Since [62c7672](https://github.com/idvorkin/context-grabber/commit/62c7672) a centred page redraws by moving a point down and back, never setting the zoom (`paper_redraw_nudge` says `how: frame`), verified on an iPad Pro 11-inch simulator: `testAPasteLandsInTheMiddleOfThePaperOnScreen` missed 1 of 8 before, drew 24 of 24 after, no crash. Since [c4b3dc1](https://github.com/idvorkin/context-grabber/commit/c4b3dc1) a look that finds the ink missing redraws and looks again (#906), verified on an iPad Pro 11-inch (M5) simulator: `testAPasteLandsInTheMiddleOfThePaperOnScreen` alone 20 of 20, every paste drawn on the first look, so the heal itself is not yet seen working (40 of 40 on main before it: the 1 in 6 of 2026-11-14 no longer shows alone). Whether it happens on a real iPad, and whether the small redraw can be felt there, is still to be seen. Since [ce66651b](https://github.com/idvorkin/context-grabber/commit/ce66651b) a kept mark drawn only in part is found and drawn again (context-grabber-ikya), verified on iPad Pro 11-inch (M5) simulators in three or four build lanes at once: on c572c2a8 with the change, `testLarrysTextArrivesAsAGhostAndKeepsAsOneText` drew his text only in part in 8 of about 250 runs, always split at the same tile edge (3 with the rest blank, 4 with it black, once the part before the edge black); the view's nudge, setting the same markup again and a redisplay each left it so, and taking the mark out and putting it back drew it whole at the next look in both runs that tried it, the test passing. No partial draw was found in about 170 whole keeps (`WhiteboardPaperGhostsUITests` and `WhiteboardTurnUITests` on the branch, 22 of 22 before the rebase on 9d118325; after it 21 of 22, `testTidyOverlapsOnATidyBoardSaysNothingOverlaps` failing 2 of 4 with no keep in it, its own bead). Not yet seen on the iPad. Since [9fa67407](https://github.com/idvorkin/context-grabber/commit/9fa67407) a look heals only ink the board still holds (context-grabber-2jw), verified on an iPad Pro 11-inch (M5) simulator: `testAPasteLandsSelectedAndDeleteTakesItAway` 5 of 5, its looks at the deleted paste `held` false with no `paper_ink_heal` (before, each such look healed twice); `testAPasteLandsInTheMiddleOfThePaperOnScreen` 5 of 5 alone and once in its class with `WhiteboardPasteUITests` and `testOneUndoTakesAKeptMarkBack`, every look `held` and drawn. Not on the iPhone (none while the whiteboard work runs). Since [aebe46ea](https://github.com/idvorkin/context-grabber/commit/aebe46ea) a kept mark's colour is measured against the same strokes' own colour drawn alone (context-grabber-qko5), verified on the host (`WhiteboardKeptInkTests`: the small label's logged numbers whole, the cut text and a half-drawn label still cut, the move away only after a redraw in place), by the Mac build, and on an iPad Pro 11-inch (M5) simulator: `testASmallLabelAtANormalPenKeptWholeIsNotRedrawn` read `cut,cut,cut` with a redraw in place and a move a screen away before (2 of 2), and one `whole` look with no redraw after; all of `WhiteboardPaperGhostsUITests` passed (20, 1 skipped), every `paper_kept_ink` whole on its first look and no `paper_ink_heal`. Not on the iPhone (none while the whiteboard work runs).
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636); [#829](https://github.com/idvorkin/context-grabber/issues/829): on an iPad, where the page is narrower than the screen and PaperKit centres it, the redraw's zoom recursed inside PaperKit until the app crashed; a centred page skipped it; [#833](https://github.com/idvorkin/context-grabber/issues/833): with the redraw skipped, a centred iPad page missed kept or pasted ink again (1 of 8 pastes, and 2 kept marks in a ladder run); a centred page now moves a point down and back instead, which never sets the zoom: 24 of 24 pastes drawn on an iPad Pro 11-inch simulator (`testAPasteLandsInTheMiddleOfThePaperOnScreen`, `paper_ink_look`), no crash; [#906](https://github.com/idvorkin/context-grabber/issues/906): the same test still found no letters on screen about 1 run in 6 on that simulator (2026-11-14), and a missed tile the one redraw left empty stayed empty, since the look that measured it only wrote it down. Now a look that finds the ink missing in view redraws and looks again, twice at most, each time moving the view a little further (`paper_ink_heal`, then the next `paper_ink_look` with its attempt); context-grabber-ikya: a kept text of Larry's showed its first letter or two in his purple and the rest blank (or, once, black) up to one vertical edge on the iPad simulator, now and then since 2026-11-20 (`testLarrysTextArrivesAsAGhostAndKeepsAsOneText`; 1 of 39 runs on c572c2a8, its `paper_kept_ink` held all 13 glyphs purple and the view drew 22 px of his purple where a whole text draws about 260). A look that drew some ink found nothing missing, so nothing redrew it, and the view's nudge, setting the same markup again or marking every view to draw again each left that tile as it was. Now a kept mark whose own colour spans under three quarters of what the same strokes span drawn alone, or that turned dark where nothing dark was, is taken out of the markup and put back a tenth of a second later (its ids kept), and the view scrolls a screen away and back if that wasn't enough (`paper_kept_ink`'s `missing`, `paper_ink_heal` with `how`).; context-grabber-2jw: every look that found ink missing in the iPad simulators' session logs from 2026-11-19 to 11-22 (61 looks, with their `paper_ink_heal`s) was at ink already gone: a paste undone or deleted, or kept marks undone, inside the look's second (`strokes` 0 or 1 at the look). The look judged a spot the board no longer held and nudged the view 8 then 32 points for nothing. Now a look checks that the board still holds ink there (`held`), and heals only then. #906's own miss is still unseen since 2026-11-14 (92 of 92 runs of the test passed in every lane's record); context-grabber-qko5: a small label of Larry's kept whole at Igor's own pen (12-point letters, a 2.68-point pen) read as cut on every look on the iPad simulator (`paper_kept_ink` `ink_span` [32,9] against `expected_span` [34,13]: the view's ink in its true colour measured against every pixel the strokes drawn alone touch, their soft edges among them, and a thin letter's true colour is only its middle), so it was redrawn in place and then the view moved a screen away and back, a jump Igor would see after each such keep. Now the view's colour is measured against the same strokes' own colour drawn alone (`expected_ink_span`), like with like
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

- **Scenario:** A kept mark only partly drawn
- **Given:** a board on paper, and a mark of Larry's I keep
- **When:** the screen shows only part of it in his colour a second later (the rest blank, or in another colour)
- **Then:** the board draws it again on its own within a few seconds, every stroke in his colour; the mark may blink once, and if that is not enough the view moves a screen away and back once, ending where it was

- **Scenario:** A small mark kept whole
- **Given:** a board on paper, and a small label of Larry's in thin letters at a normal pen
- **When:** I keep it and it shows whole in his colour
- **Then:** the board leaves it as it is: it doesn't blink, and the view doesn't move

- **Scenario:** Ink taken away before the board looks
- **Given:** a board on paper, and ink I just pasted or kept
- **When:** I undo it, delete it or clear the board within a second
- **Then:** the board doesn't count the empty spot as ink missing: it neither redraws nor moves the view for it

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

---

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

---

### User Story 653:

- **Summary:** Lines stay with their board on paper
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesStayWithTheBoardUnderTheInk`, `testTheGridShowsWhenAskedAndStaysWithItsBoard`, the latter an old-canvas test dropped 2026-11-07); a new board starting with the grid, not none, in [c0e22ba](https://github.com/idvorkin/context-grabber/commit/c0e22ba) (story 410, #915), verified by host tests (`BoardLinesTests`)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608), [#915](https://github.com/idvorkin/context-grabber/issues/915)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** going back to a board
- **I want to** find its lines as I left them
- **so that** each board keeps its own look

#### Acceptance Criteria:
- **Scenario:** Reopening
- **Given:** a board on paper with ruled lines on
- **When:** I leave it and open it again
- **Then:** the lines are on. A new board starts with the grid, not ruled lines (story 410)

---

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

---

### User Story 655:

- **Summary:** Lines and ghosts show on every colour
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testEveryColourShowsItsLinesAndKeepsTheInk` for the grid on all five, `testAGhostShowsOnTheDarkestColours` for a ghost on Grey; `testABoardsColourShowsInBothModesAndStaysWithIt` for the colour, an old-canvas test dropped 2026-11-07; on paper `testRuledLinesStayWithTheBoardUnderTheInk` keeps a board's colour); since bead `context-grabber-y8r` the grid on Lilac, the darkest, and Plain stand for all five (the lines are one grey on every colour); since story 770 Lilac alone, the grid on Plain being `testRuledLinesAndTheGridAreOneChoiceAndNeverInk`
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

---

### User Story 656:

- **Summary:** Changing colour or lines leaves the ink
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testEveryColourShowsItsLinesAndKeepsTheInk`; `paper_ink_look` after each change); since bead `context-grabber-y8r` on Lilac and Plain; since story 770 on Lilac alone
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

---

### User Story 657:

- **Summary:** The Board menu never costs a stroke
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testTheFirstStrokeAfterTheMenuDraws`, 5 of 5 after the fix, and before it the stroke was lost 5 of 5). Choosing the colour already chosen takes the same path; its test, `testTheFirstStrokeAfterChoosingTheSameColourDraws`, hasn't been run on a simulator yet; since bead `context-grabber-y8r` the first two cases share one launch, and since [e234dc6](https://github.com/idvorkin/context-grabber/commit/e234dc6) the same-colour case has its own again, on a fresh board choosing Plain (chained after the others, the menu tap missed the colour row); verified on the simulator (the whole whiteboard suite, 0 failures). Since [efab29b9](https://github.com/idvorkin/context-grabber/commit/efab29b9) (#880) a Board-menu row whose tap the on-screen keyboard's rise cancelled is tapped again; verified on the iPad Pro 11-inch (M5) simulator, `WhiteboardPaperLinesUITests` four times with no retry, 28 of 28 (the second tap was needed 3 times, each a miss before), against 13 of 14 before it
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608), [#880](https://github.com/idvorkin/context-grabber/issues/880) (the menu's UI tests flaky on the iPad simulator: opening the Board menu raises the on-screen keyboard there, and a row tapped as it rises is cancelled, so `WhiteboardPaperLinesUITests` taps the row again while the menu is still up)
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

---

### User Story 658:

- **Summary:** A board drawn on the old canvas opens to look at, on paper
- **Status:** implemented in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e); verified by host tests (`BoardIndexTests`: only a board made on paper, on its own device, is drawn on; the bar's words for each look-only board; `BoardKeepingTests`: through a relaunch; `BoardPagesTests`: the ink moved, never scaled) and on the simulator (`WhiteboardOnPaperUITests.testAnOldCanvasBoardOpensLookOnlyOnPaper`, on an iPad Pro 11-inch simulator too since [#845](https://github.com/idvorkin/context-grabber/issues/845): it searches for the old ink from under the navigation bar and drags right to left, as a swipe right is Back; `paper_ink_look` why `open` counted the ink drawn in 6 of 6 opens; the smoke's `paper_open`). Igor's own old boards on the iPad not yet seen. Since story 770 the simulator's check is the smoke's `paper_open` (look-only, 40 strokes at the first page's corner); the UI test was a duplicate of it and of `BoardIndexTests`
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
