# The whiteboard: Gestures: holds, scratch-out, shapes, connectors and moving ink

What the Pencil's gestures do: press and hold, the scratch-out, snapped shapes, To text, connectors, rewording, dragging a selection and the room handle. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md),
[what's selected](../superpowers/specs/2026-11-22-whiteboard-selection-label-design.md).

---

### User Story 1044:

- **Summary:** Holding the room handle shows a band and a "Making room" chip until I lift
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700); verified by host tests (`BoardRoomBandTests`; `just test`), the Mac build, and on the iPad simulator by `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (a finger in the margin, the band and chip photographed with `GRABBER_WHITEBOARD_FEEDBACK_SECONDS`); the Pencil's hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** making room in the middle of my writing on the iPad
- **I want to** see a see-through band with up and down arrows and a *Making room* chip while I hold and drag in the margin
- **so that** it's clear I'm in that mode, and where the room will open, before I lift

#### Acceptance Criteria:
- **Scenario:** Dragging down in the margin
- **Given:** a board on paper with writing above and below
- **When:** I hold a finger or the Pencil in the margin until the handle fires, and drag down two lines without lifting
- **Then:** a see-through band two lines tall lies across the page at the clear line, with up and down arrows and a *Making room* chip beside it; nothing below has moved yet; and when I lift, the band goes and the ink below moves down those two lines

---

### User Story 1038:

- **Summary:** Dragging the room handle up shows the blank paper that will close
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700); verified by host tests (`BoardRoomBandTests`; `just test`), the Mac build, and on the iPad simulator by `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (a finger in the margin, the band and chip photographed with `GRABBER_WHITEBOARD_FEEDBACK_SECONDS`); the Pencil's hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** closing up a gap I no longer need
- **I want to** see the band cover the blank paper that will close
- **so that** I know what the lift will do before I lift

#### Acceptance Criteria:
- **Scenario:** Dragging up over blank paper
- **Given:** a board with three blank lines between two lines of writing
- **When:** I hold in the margin in the gap and drag up four lines
- **Then:** the band covers the three blank lines, never the writing, and the chip says *Closing room*

---

### User Story 1039:

- **Summary:** Dragging the room handle up with no blank paper says there is none to close
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700); verified by host tests (`BoardRoomBandTests`; `just test`), the Mac build, and on the iPad simulator by `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (a finger in the margin, the band and chip photographed with `GRABBER_WHITEBOARD_FEEDBACK_SECONDS`); the Pencil's hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** closing up a gap I no longer need
- **I want to** be told when there is no blank paper to close
- **so that** I know the lift will change nothing before I lift

#### Acceptance Criteria:
- **Scenario:** Dragging up with no blank paper
- **Given:** a board with two lines of writing with no blank line between them
- **When:** I hold in the margin between the two lines and drag up
- **Then:** the band is a thin line and the chip says *No blank paper to close*

---

### User Story 1042:

- **Summary:** The room band follows Reduce Motion
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700): the band's easing is off under Reduce Motion; built and its UI tests pass on the iPad simulator with Reduce Motion off; with it on, not yet seen anywhere
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** with Reduce Motion on
- **I want to** have the room band move without easing
- **so that** the board never moves more than it has to

#### Acceptance Criteria:
- **Scenario:** Dragging the room handle with Reduce Motion on
- **Given:** Reduce Motion is on in Settings
- **When:** I drag the room handle down
- **Then:** the band jumps a line at a time with no easing

---

### User Story 1043:

- **Summary:** The scratch-out's flash follows Reduce Motion
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4): the flash is off under Reduce Motion; built and its UI tests pass on the iPad simulator with Reduce Motion off; with it on, not yet seen anywhere
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** with Reduce Motion on
- **I want to** have the struck ink fade without flashing
- **so that** the board never moves more than it has to

#### Acceptance Criteria:
- **Scenario:** Scratching out with Reduce Motion on
- **Given:** Reduce Motion is on in Settings
- **When:** I scratch out a word
- **Then:** the struck ink shows plainly and fades without a flash

---

### User Story 1050:

- **Summary:** A scratch-out flashes and fades the ink it took
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13), [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4); verified by `just test`, the Mac build, and on the iPad simulator by the scratch-out flash UI test (the hook's zigzag, the flash held for its picture). The flash check now runs in `WhiteboardScratchOutUITests.testWordScratchOutAndEraserSweep`. The Pencil's zigzag is the iPad's.
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** scribbling out a word with the Pencil
- **I want to** see the ink I struck flash and fade where it was
- **so that** I know the scratch-out fired and what it took

#### Acceptance Criteria:
- **Scenario:** Scratching out a word
- **Given:** a board on paper with a word written on it
- **When:** I draw a quick zigzag over it
- **Then:** the word and the zigzag show in a bright tint where they were and fade out over about half a second, and the board is without them, one Undo bringing the word back

---

### User Story 1051:

- **Summary:** A zigzag that finds nothing to erase says so and goes
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13), [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4); verified on the host (`WhiteboardScratchOutTests.testOnlyAZigzagOverNothingFindsNothing`), the Mac build, and on the iPad simulator by `WhiteboardScratchOutUITests.testAZigzagOverNothingSaysSoAndGoes` (the message, zero strokes after the board's first zigzag goes, and one after Redo). The Pencil's zigzag is the iPad's.
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** who scribbled where there was nothing
- **I want to** be told nothing was erased, and not be left with the scribble
- **so that** I don't wonder whether the scratch-out failed, and can try again over the ink

#### Acceptance Criteria:
- **Scenario:** A zigzag over bare paper
- **Given:** a board on paper with bare paper where I draw
- **When:** I draw a quick zigzag there
- **Then:** the zigzag is taken away, *Nothing under the scribble to erase* shows beside where it was for a few seconds, and Redo brings the zigzag back as ink

---

### User Story 1052:

- **Summary:** A zigzag that only clips the end of a word says so and goes, leaving the word
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13), [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4); verified on the host (`WhiteboardScratchOutTests.testOnlyAZigzagOverNothingFindsNothing`), and the Mac build; the simulator's UI test draws over bare paper only (story 1051), so a zigzag beside a word is the iPad's
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** who scribbled beside a word rather than over it
- **I want to** be told nothing was erased, and not be left with the scribble
- **so that** I don't wonder whether the scratch-out failed, and can try again over the ink

#### Acceptance Criteria:
- **Scenario:** A zigzag beside a word
- **Given:** a board on paper with a long word written on it
- **When:** I draw a quick zigzag that only clips the end of the word
- **Then:** the word stays, the zigzag is taken away, *Nothing under the scribble to erase* shows beside where it was for a few seconds, and Redo brings the zigzag back as ink

---

### User Story 854:

- **Summary:** Erasing part of a group leaves plain ink
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardDissolveTests`: part of a group leaves plain ink with his other notes, a whole group is an ordinary erase, a kept text missing a letter is forgotten and `dissolved` goes on the wire); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Erasing part of a group dissolves it*

#### Use Case:
- **As someone** rubbing out part of something Larry drew as one
- **I want to** have what's left be plain ink
- **so that** it no longer moves or answers as a thing that is gone

#### Acceptance Criteria:
- **Scenario:** Part of his group
- **Given:** a group of Larry's three strokes
- **When:** I erase one of them
- **Then:** the other two stay where they are as plain ink, a push moves them one by one, and Larry's next turn names the group as dissolved

---

### User Story 871:

- **Summary:** Erasing a letter of Larry's kept text leaves plain ink
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardDissolveTests`: part of a group leaves plain ink with his other notes, a whole group is an ordinary erase, a kept text missing a letter is forgotten and `dissolved` goes on the wire); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Erasing part of a group dissolves it*

#### Use Case:
- **As someone** rubbing out part of a text of Larry's I kept
- **I want to** have what's left be plain ink
- **so that** Larry no longer reads it as his text

#### Acceptance Criteria:
- **Scenario:** Part of a kept text
- **Given:** a text of Larry's I kept
- **When:** I erase one letter
- **Then:** the other letters stay as plain ink, and Larry no longer gets it as his text

---

### User Story 858:

- **Summary:** Press and hold: room in the margin, a menu on the page
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f), the Pencil in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardRoomTests.testRoomByHandOpensWholeLinesAndClosesOnlyBlankPaper`); a simulator UI test, `WhiteboardOutlineUITests.testAHoldBringsTheMenuAndAMarginDragMakesRoom`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** needing room in the middle of my writing
- **I want to** hold and drag in the margin, or hold for a menu
- **so that** I make room, paste or mark a header without leaving the board

#### Acceptance Criteria:
- **Scenario:** Drag in the margin
- **Given:** writing above and below
- **When:** I hold a finger or the Pencil in the margin, drag down two lines and lift
- **Then:** the ink below that clear line moves down two lines, one Undo

---

### User Story 930:

- **Summary:** The Pencil held in the margin opens room
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing with the Pencil and needing room
- **I want to** hold the Pencil still in the margin and drag it down
- **so that** I make room without putting the Pencil down

#### Acceptance Criteria:
- **Scenario:** Hold and drag
- **Given:** writing above and below a clear line
- **When:** I hold the Pencil still in the margin beside it for half a second, drifting a little as a hand does, drag down two lines and lift
- **Then:** the ink below moves down two lines, one Undo, and no stroke of the Pencil's is left in the margin

---

### User Story 931:

- **Summary:** The Pencil held still in the margin brings the menu
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing with the Pencil
- **I want to** hold it still in the margin and lift
- **so that** I get Make room here, Paste and the header choices without a finger

#### Acceptance Criteria:
- **Scenario:** Hold and lift
- **Given:** a line of writing
- **When:** I hold the Pencil still in the margin beside it for half a second, within about 12 points, and lift
- **Then:** the menu shows there, and the Pencil left no dot

---

### User Story 932:

- **Summary:** The Pencil that moves at once still draws in the margin
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing or marking in the margin
- **I want to** have a quick Pencil stroke there stay ink
- **so that** margin notes and quick marks still work

#### Acceptance Criteria:
- **Scenario:** A quick stroke
- **Given:** the margin
- **When:** I draw a quick bullet or dash in it, moving further than about 12 points within the first half second
- **Then:** the stroke stays as ink and nothing moves

---

### User Story 933:

- **Summary:** Every margin hold says in the log what became of it
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** debugging a hold that didn't fire on the iPad
- **I want to** read each margin hold in the session log
- **so that** the next report settles whether it was the finger, the Pencil, the timing or PaperKit

#### Acceptance Criteria:
- **Scenario:** A hold that fails
- **Given:** the board open
- **When:** I hold in the margin with a finger or the Pencil
- **Then:** the log has its start (which, where) and whether it became a hold or why not: moved first, lifted too soon, or never seen held

---

### User Story 874:

- **Summary:** A hold on the page brings a menu
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f); verified by host tests (`BoardRoomTests.testRoomByHandOpensWholeLinesAndClosesOnlyBlankPaper`); a simulator UI test, `WhiteboardOutlineUITests.testAHoldBringsTheMenuAndAMarginDragMakesRoom`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad; the menu by what the finger is on, in a column with icons (stories 1186, 1187, bead context-grabber-y4y) in [06eddd08](https://github.com/idvorkin/context-grabber/commit/06eddd08) and [b0debd9c](https://github.com/idvorkin/context-grabber/commit/b0debd9c), the class again on the iPad simulator (rung 2, 2026-11-22)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** needing room, a paste or a header in the middle of my writing
- **I want to** hold a finger still for a menu
- **so that** I do them without leaving the board

#### Acceptance Criteria:
- **Scenario:** Hold for the menu
- **Given:** a finger held still on the page, or in the margin without dragging
- **When:** the hold is long enough
- **Then:** a menu offers Make room here, Paste, and Make header (or Not a header) beside a line, in a column with an icon on each row; held on ink, Select and Delete for what is under the finger come first (stories 1186, 1187)

---

### User Story 1186:

- **Summary:** A finger held on ink offers to select what is under it
- **Issues:** bead context-grabber-y4y (Larry, 2026-11-22: "press-and-hold on the board should open a useful menu"; the iPad's logs, 11-16 to 11-22: the menu came up 26 times and a row was chosen 3 times)
- **Status:** implemented in [06eddd08](https://github.com/idvorkin/context-grabber/commit/06eddd08) and [b0debd9c](https://github.com/idvorkin/context-grabber/commit/b0debd9c); verified by host tests (`BoardHoldMenuTests`), `just native-test` and the Mac build (`just native-build-mac`); `WhiteboardOutlineUITests.testAHoldBringsTheMenuAndAMarginDragMakesRoom` (with the hold on ink since bead context-grabber-3k6) passes on the iPad simulator with the rest of the class (rung 2, 2026-11-22); not yet seen on the iPad; To text reached through the hold menu since [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920) (#1386)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing with my finger
- **I want to** hold a finger on a word and choose Select
- **so that** I can drag it, turn it to text or use the selection's menu without drawing a lasso

#### Acceptance Criteria:
- **Scenario:** Select from the hold menu
- **Given:** two words on a line
- **When:** I hold a finger still on the first and choose Select
- **Then:** that word alone is selected, as a lasso round it would leave it, with its label above it and nothing beside it; on a group of Larry's the whole group is, and on a header's row the row is

---

### User Story 1187:

- **Summary:** A finger held on ink offers to delete what is under it
- **Issues:** bead context-grabber-y4y (Larry, 2026-11-22: "press-and-hold on the board should open a useful menu")
- **Status:** implemented in [06eddd08](https://github.com/idvorkin/context-grabber/commit/06eddd08) and [b0debd9c](https://github.com/idvorkin/context-grabber/commit/b0debd9c); verified by host tests (`BoardHoldMenuTests`), `just native-test` and the Mac build (`just native-build-mac`); `WhiteboardOutlineUITests.testAHoldBringsTheMenuAndAMarginDragMakesRoom` (with the hold on ink since bead context-grabber-3k6) passes on the iPad simulator with the rest of the class (rung 2, 2026-11-22); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** fixing a word I wrote
- **I want to** hold a finger on it and choose Delete
- **so that** it goes without picking up the eraser

#### Acceptance Criteria:
- **Scenario:** Delete from the hold menu
- **Given:** two lines of writing
- **When:** I hold a finger still on the first line's word and choose Delete
- **Then:** that word goes and the other line stays, one Undo named Delete brings it back, and Larry hears it erased; the hold itself left no dot, even with a finger that draws; held on a header's row there is no Delete, and held off ink there is none either

---

### User Story 859:

- **Summary:** The Pencil held on a word picks it up
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the word lands when the Pencil lifts, not live; in the margin a held Pencil is the hold, not the pick-up, since [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192)); verified by host tests (`BoardOutlineTests.testAHeldPencilPicksUpTheWordUnderIt`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad: the simulator can't hold a Pencil, so the iPad is where it is seen
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** rearranging what I wrote
- **I want to** hold the Pencil still on a word and drag it somewhere else
- **so that** I move a word without the lasso

#### Acceptance Criteria:
- **Scenario:** Move a word
- **Given:** a line of words
- **When:** I hold the Pencil still on one word for under half a second, drag and lift
- **Then:** that word, and only it, lands where I lifted, my Pencil's stroke isn't kept, and one Undo puts it back

---

### User Story 875:

- **Summary:** The Pencil held on a word and lifted selects it
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the word lands when the Pencil lifts, not live); verified by host tests (`BoardOutlineTests.testAHeldPencilPicksUpTheWordUnderIt`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad: the simulator can't hold a Pencil, so the iPad is where it is seen
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** choosing a word I wrote
- **I want to** hold the Pencil on it and lift
- **so that** it is selected without the lasso

#### Acceptance Criteria:
- **Scenario:** Hold and lift
- **Given:** a word
- **When:** I hold the Pencil on it and lift without moving
- **Then:** the word is selected

---

### User Story 890:

- **Summary:** A fast zigzag over ink scratches it out
- **Status:** implemented in [767fdd4](https://github.com/idvorkin/context-grabber/commit/767fdd4) (the Cockpit's web board's `scratchOut`, ported); verified on the host (`WhiteboardScratchOutTests`, the web board's own zigzags, humps and loops; `just native-test`). The Pencil's feel and the one undo are the iPad's to show. Staying gone when he writes on (#999) fixed in [19fa533e](https://github.com/idvorkin/context-grabber/commit/19fa533e); verified on the simulator (`WhiteboardScratchOutUITests`, failing before the fix: the word stayed on the sheet), the Pencil's zigzag on the iPad still to see. A scribble that drifts along the word (context-grabber-4kj) in [eb73c30](https://github.com/idvorkin/context-grabber/commit/eb73c30); verified on the Linux rung (`WhiteboardScratchOutTests`, Igor's real scribbles of 2026-11-21 replayed, failing before the fix on *short sweeps*), the iPad still to see. A scribble that drifts further than its sweeps are long is story 1185
- **Issues:** [#999](https://github.com/idvorkin/context-grabber/issues/999), context-grabber-4kj (a scribble that drifts along the word stayed ink, *short sweeps*, Igor 2026-11-21)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** writing on a board with the Pencil
- **I want to** scribble over a word to delete it, without picking up the eraser
- **so that** fixing a mistake doesn't break my flow, as on Larry's web board

#### Acceptance Criteria:
- **Scenario:** Scratching out a word
- **Given:** a board on paper with a word written on it and another word beside it
- **When:** I draw a quick zigzag, turning back at least three times, over the first word
- **Then:** the strokes the zigzag touched and the zigzag itself are gone, and stay gone, on the sheet and in what Larry gets, when I write on; the word beside it stays, and one undo brings the scratched-out word back without the zigzag

- **Scenario:** Scribbling over a word the way a hand does
- **Given:** a board on paper with a word written on it
- **When:** I scribble fast over the word, turning back five times or more, drifting along it so no sweep spans the whole scribble
- **Then:** the word and the scribble are gone, as for a straight zigzag

---

### User Story 1185:

- **Summary:** A long scribble that drifts further than its sweeps are long scratches out
- **Status:** implemented in [770b0c36](https://github.com/idvorkin/context-grabber/commit/770b0c36); verified on the host (`just native-test`: `WhiteboardScratchOutTests`, every scratch line and every fast pen path from Igor's iPad logs of 2026-11-21 and 22 replayed, the drifting one failing before the fix on *short sweeps*) and the Mac build (`just native-build-mac`), the iPad still to see
- **Issues:** context-grabber-4kj (a fast scribble drifting 458 points along a line stayed ink, *short sweeps*, Igor 2026-11-21, on a build with story 890's drifting-scribble fix)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** scratching out a long word or a phrase with the Pencil
- **I want to** scribble along it the way a hand does, drifting as I go
- **so that** it goes as a short word does, without a straighter zigzag

#### Acceptance Criteria:
- **Scenario:** A long scribble that drifts further than its sweeps are long
- **Given:** a board on paper with a long word or a phrase written on it
- **When:** I scribble fast along it, turning back five times or more, each sweep 40 points or longer but the whole scribble drifting well past any one sweep
- **Then:** the ink under it and the scribble are gone; the same scribble over bare paper, or beside ink, stays ink unsaid

---

### User Story 1282:

- **Summary:** A small mark inside a scratched-out word goes with it
- **Status:** implemented in [485bd9c0](https://github.com/idvorkin/context-grabber/commit/485bd9c0); verified on the host (`WhiteboardScratchOutTests`: Igor's board-nov-23 scratch-out replayed, failing before the fix with the mark left; the web board's *t* crossbar now goes too), the Mac build and the iPad simulator (`WhiteboardScratchOutUITests`), the Pencil on the iPad still to see
- **Issues:** cockpit-9g1 (a scratch-out over ten fresh strokes left one, a mark its sweeps passed either side of, Igor 2026-11-23, board-nov-23)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** scratching out a word with the Pencil
- **I want to** have the whole word go, its dots and small marks included
- **so that** I don't have to scratch out a speck the zigzag happened to miss

#### Acceptance Criteria:
- **Scenario:** A mark between two sweeps
- **Given:** a board on paper with a word written on it, a small mark among its letters
- **When:** I scratch the word out and no sweep of the zigzag touches the small mark
- **Then:** the word, the small mark and the zigzag are gone, and one undo brings the word and the mark back

---

### User Story 1266:

- **Summary:** A scratch-out never takes the line below, even when it touches a long stroke
- **Status:** implemented in the commit that adds this story; verified on the host (`WhiteboardScratchOutTests`: the line below a struck word stays, and so do small letters below it when the zigzag also touches an arrow running down past them)
- **Issues:** cockpit-9g1 (review of story 1282: a long touched stroke stretched the outline over the line below)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** scratching out a word with the Pencil
- **I want to** keep the writing around it, even where a stroke of the word runs down past it
- **so that** a scratch-out takes only what I struck

#### Acceptance Criteria:
- **Scenario:** Ink beside the word stays
- **Given:** a board on paper with a word written on it, an arrow running down from it, and small writing on the line below beside the arrow
- **When:** I scratch out the word and the zigzag touches the start of the arrow
- **Then:** the writing on the line below stays, even where it is close

---

### User Story 1283:

- **Summary:** A small zigzag scratches out at a small zigzag's speed
- **Status:** implemented in [485bd9c0](https://github.com/idvorkin/context-grabber/commit/485bd9c0); verified on the host (`WhiteboardScratchOutTests`: the 37-point retry, refused as slow before the fix, and every pen path from Igor's iPad logs of 2026-11-21 and 22 keeping its verdict), the Mac build and the iPad simulator, the Pencil on the iPad still to see
- **Issues:** cockpit-9g1 (the retry over the left-behind mark, a 37-point zigzag at 0.35 points per millisecond, was refused as slow, Igor 2026-11-23)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** scratching out a single letter or a small mark
- **I want to** have a small quick zigzag count
- **so that** I don't have to scribble as fast as over a long word

#### Acceptance Criteria:
- **Scenario:** A small quick zigzag
- **Given:** a board on paper with a small mark on it
- **When:** I draw a quick zigzag about 40 points long over it, at a third of a point per millisecond
- **Then:** the mark and the zigzag are gone

---

### User Story 1268:

- **Summary:** Slow small writing that looks like a zigzag stays ink
- **Status:** implemented in [485bd9c0](https://github.com/idvorkin/context-grabber/commit/485bd9c0); verified on the host (`WhiteboardScratchOutTests`: every pen path from Igor's iPad logs of 2026-11-21 and 22 keeping its verdict, his slow writing of 37 points at 0.23 and 45 at 0.30 among them)
- **Issues:** cockpit-9g1
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** writing small letters with the Pencil
- **I want to** have a small back-and-forth I write slowly stay ink
- **so that** a lower speed floor for small zigzags never eats my handwriting

#### Acceptance Criteria:
- **Scenario:** Slow writing still stays ink
- **Given:** a board on paper with writing on it
- **When:** I write a small back-and-forth slowly, under a quarter of a point per millisecond
- **Then:** it stays ink

---

### User Story 891:

- **Summary:** Writing that only looks like a zigzag stays ink
- **Status:** implemented in [767fdd4](https://github.com/idvorkin/context-grabber/commit/767fdd4); verified on the host (`WhiteboardScratchOutTests.testHandwritingNeverQualifies`, `testAZigzagThatIsNotAScratchOutStaysInk`, `testAZigzagBesideAWordRatherThanOverItStaysInk`). The session log's `scratch` line says why each near miss stayed ink, for the iPad; narrowed to writing in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13) (#1000): a fast zigzag over bare paper or beside a word is stories 1051 and 1052; hatching that wanders along stays ink unsaid in [eb73c30](https://github.com/idvorkin/context-grabber/commit/eb73c30) (context-grabber-4kj; Igor's hatching from his boards in the test's fixture)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** writing words like *mmm*, *www* or *minimum*
- **I want to** never lose ink to a scratch-out I didn't mean
- **so that** I can trust the board with my handwriting

#### Acceptance Criteria:
- **Scenario:** Near misses
- **Given:** a board with writing on it
- **When:** I write *mmm* over a word, or draw a slow zigzag over it
- **Then:** what I drew stays as ink, nothing else is removed, and the session log says why it wasn't a scratch-out (*marches along*, *slow*). A fast zigzag on bare paper, or one that only clips the end of a long word, is stories 1051 and 1052 (#1000)

- **Scenario:** Shading
- **Given:** a board with a drawn box on it
- **When:** I hatch fast beside the box or inside it, back and forth along a line
- **Then:** the hatching stays as ink, without a word, and the box stays (*short sweeps*, or *wanders, beside ink*)

---

### User Story 899:

- **Summary:** A zigzag over a gap the pixel eraser left leaves the stroke alone
- **Status:** implemented in [e91e8bb5](https://github.com/idvorkin/context-grabber/commit/e91e8bb5); verified on the host (`WhiteboardScratchOutTests.testAZigzagOverTheGapTheEraserLeftStaysInk`, `testAZigzagOverWhatIsLeftTakesTheStroke`, `testWhatTheEraserLeftIsReadFromTheVisibleRanges`; `just native-test`) and the Mac build (`just native-build-mac`); a real pixel eraser's rub then a zigzag over the gap is the iPad's to see
- **Issues:** context-grabber-p5hy (a zigzag over a gap the pixel eraser left took the whole stroke around it; codex review 2026-11-21)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** who rubs part of a stroke away with the pixel eraser
- **I want to** have a scratch-out touch only the ink still on the board
- **so that** a zigzag over bare paper never takes the ink around it

#### Acceptance Criteria:
- **Scenario:** A zigzag over a gap the pixel eraser left
- **Given:** a board on paper with a stroke whose middle I rubbed out with the pixel eraser
- **When:** I draw a quick zigzag over the gap, touching neither part that is left
- **Then:** nothing of that stroke goes, as the gap is bare paper

---

### User Story 920:

- **Summary:** Selected handwriting becomes typed text
- **Status:** implemented in [6a1894d](https://github.com/idvorkin/context-grabber/commit/6a1894d); verified by host tests (`BoardToTextTests`: `testTheRequestIsThePictureAndTheBoardAsTheWebBoardSendsThem`, `testTheCropIsTheInkWithAirRoundItNeverOffTheBoard`, `testTheWordsAreTheAnswer`, `testOneTypedLinePerLineReadAtTheInksTopLeftSizedToIt`; `just test`) and the Mac build (`just native-build-mac`), and on the simulator against the fake Cockpit (`WhiteboardToTextUITests.testToTextPutsTheWordsInTheInksPlace`, rung 2); not yet seen on the iPad, nor against the real Cockpit; To text reached through the hold menu since [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920) (#1386)
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*

#### Use Case:
- **As someone** writing on the board with the Pencil
- **I want to** lasso some of my handwriting, hold a finger on it and choose To text
- **so that** the words are typed where I wrote them, for me and for Larry

#### Acceptance Criteria:
- **Scenario:** Two written lines
- **Given:** I lasso two lines of my handwriting on a board drawn on here
- **When:** I hold a finger still on the selection, choose To text from the hold menu, and the Cockpit reads it
- **Then:** the ink goes and its words show in its place as two typed lines in the print lettering and the ink's colour, one kept text that Larry gets back as text; one undo brings the ink back

---

### User Story 921:

- **Summary:** A To text that fails leaves the ink and says why
- **Status:** implemented in [6a1894d](https://github.com/idvorkin/context-grabber/commit/6a1894d); verified by host tests (`BoardToTextTests.testAFailureSaysTheCockpitsReason`; `just test`) and the Mac build (`just native-build-mac`), and on the simulator against the fake Cockpit (`WhiteboardToTextUITests.testAFailureLeavesTheInkWithACopyableProblem`, rung 2); not yet seen on the iPad; To text reached through the hold menu since [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920) (#1386)
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*

#### Use Case:
- **As someone** turning handwriting into text
- **I want to** be told why when the Cockpit can't read it
- **so that** I know whether to try again, and my ink is never lost

#### Acceptance Criteria:
- **Scenario:** The Cockpit fails
- **Given:** some ink lassoed, and a Cockpit that is away or answers with an error
- **When:** I choose To text from the hold menu on it
- **Then:** the ink stays exactly as it was and a copyable problem says "To text failed:" with the Cockpit's reason, naming the board, the Cockpit and its status

---

### User Story 922:

- **Summary:** No writing, or too much, leaves the ink and says so
- **Status:** implemented in [6a1894d](https://github.com/idvorkin/context-grabber/commit/6a1894d); verified by host tests (`BoardToTextTests.testNoWritingOrTooMuchLeavesTheInk`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad; To text reached through the hold menu since [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920) (#1386)
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*

#### Use Case:
- **As someone** lassoing a drawing or a whole page
- **I want to** hear that there was no writing, or too much for one text
- **so that** I can select something else instead of losing what I drew

#### Acceptance Criteria:
- **Scenario:** A drawing with no words
- **Given:** I lasso a doodle with no writing in it, or more than 500 characters of writing
- **When:** I choose To text from the hold menu on it
- **Then:** the ink stays and the board's note says "No writing found there", or "Too much writing for one text (500 characters): select less"

---

### User Story 923:

- **Summary:** A line held at its end snaps straight
- **Status:** implemented in [f2d3e1d](https://github.com/idvorkin/context-grabber/commit/f2d3e1d); verified by host tests (`BoardShapeSnapTests`: `testANearlyStraightStrokeSnapsToTheLineFromItsStartToItsEnd`, `testAWobblyOrShortStrokeStaysInk`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator (no Pencil to hold) or the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *Shapes that snap*

#### Use Case:
- **As someone** drawing a line with the Pencil
- **I want to** hold the Pencil still at its end to make it straight
- **so that** my diagrams look clean without a ruler or a shape tool

#### Acceptance Criteria:
- **Scenario:** A nearly straight line
- **Given:** I draw a slightly wobbly line on a board drawn on here
- **When:** I hold the Pencil still at its end for about half a second, then lift
- **Then:** the line is replaced by a straight one from where I started to where I stopped, in my pen's ink, colour and width; one undo gives my raw line back

---

### User Story 924:

- **Summary:** A box or a loop held at its end snaps to a rectangle or an ellipse
- **Status:** implemented in [f2d3e1d](https://github.com/idvorkin/context-grabber/commit/f2d3e1d); verified by host tests (`BoardShapeSnapTests`: `testANearlySquareBoxSnapsToItsBox`, `testATiltedBoxStaysInk`, `testANearlyRoundLoopSnapsToTheEllipseInItsBoxFromWhereItStarted`, `testAnOpenLoopStaysInk`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *Shapes that snap*

#### Use Case:
- **As someone** boxing or circling things on the board
- **I want to** hold the Pencil at the end of a box or a loop to clean it up
- **so that** the board reads as tidy as the web board's

#### Acceptance Criteria:
- **Scenario:** A box and a loop
- **Given:** I draw a nearly square box, and a closed loop, each ending where it started
- **When:** I hold the Pencil still at the end of each for about half a second, then lift
- **Then:** the box becomes a rectangle square to the page and the loop an ellipse in its box; a tilted box or an open loop stays as I drew it; one undo gives each raw stroke back

---

### User Story 925:

- **Summary:** Nothing snaps without the hold
- **Status:** implemented in [f2d3e1d](https://github.com/idvorkin/context-grabber/commit/f2d3e1d); verified by host tests (`BoardShapeSnapTests`: `testOnlyAPencilHeldStillHalfASecondAtTheEndAsks`, `testWritingNeverSnaps`; `just test`) and the Mac build (`just native-build-mac`); a held lift whose stroke a margin hold, a pick-up or a scratch-out took no longer arms the next stroke, in [acb476c](https://github.com/idvorkin/context-grabber/commit/acb476c); not yet seen on the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *Shapes that snap*

#### Use Case:
- **As someone** writing and drawing freely
- **I want to** have my strokes left exactly as drawn unless I hold the Pencil at their end
- **so that** my handwriting and sketches never change under me

#### Acceptance Criteria:
- **Scenario:** A line lifted at once
- **Given:** I draw a nearly straight line, and a word of writing
- **When:** I lift the Pencil at the end of each without holding it still
- **Then:** both stay exactly as I drew them

---

### User Story 910:

- **Summary:** I join two things with an arrow I drew
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb), and [7097c4e](https://github.com/idvorkin/context-grabber/commit/7097c4e) (Connect sits clear of To text, which covered it); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; on the simulator, `WhiteboardConnectUITests` (`testALassoedArrowBetweenTwoWordsConnectsThem`, passing after 7097c4e); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** sketching how ideas connect
- **I want to** lasso an arrow I drew between two things and tap Connect
- **so that** the arrow stays joined to them, as on the web board

#### Acceptance Criteria:
- **Scenario:** Connect a drawn arrow
- **Given:** two words of mine on the board and an arrow I drew from one to the other, circled with the lasso
- **When:** I tap Connect beside the selection
- **Then:** my arrow's ink is replaced by a clean arrow from the first word's facing side to the second's, and one Undo named Connect gives my arrow back

---

### User Story 1358:

- **Summary:** Connect works when the lasso takes the whole diagram
- **Status:** implemented in [c3318179](https://github.com/idvorkin/context-grabber/commit/c3318179) and [584f9276](https://github.com/idvorkin/context-grabber/commit/584f9276); verified by host tests (`BoardConnectorsTests.testConnectFindsTheArrowInsideALassoThatTookTheWholeDiagram`, failing before the change), `just test`, and on the iPad Pro 11-inch (M5) simulator `WhiteboardConnectUITests` (both passing); not yet seen on the iPad
- **Issues:** [#1440](https://github.com/idvorkin/context-grabber/issues/1440)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** sketching two boxes joined by an arrow on the iPad
- **I want to** get Connect even when the lasso grabs the boxes along with my arrow
- **so that** I don't have to fight the lasso to circle the arrow alone

#### Acceptance Criteria:
- **Scenario:** The lasso takes both boxes and the arrow
- **Given:** two boxes of mine with an arrow I drew from one to the other, and a lasso that selects all of them
- **When:** I tap Connect beside the selection
- **Then:** only my arrow is replaced by a clean connector from the first box to the second, the boxes stay as drawn, and one Undo named Connect gives my arrow back

---

### User Story 911:

- **Summary:** A connector follows what it joins
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** rearranging a diagram
- **I want to** move one end of a connector
- **so that** the arrow goes with it without my redrawing it

#### Acceptance Criteria:
- **Scenario:** Move an end
- **Given:** a connector between two things
- **When:** I lasso-move one of them, or a push, a paste or a fold moves it
- **Then:** the arrow is drawn again from where they are now, and the Undo of that move puts the arrow back too

---

### User Story 912:

- **Summary:** A connector bends once around something in its way
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** reading a diagram
- **I want to** see an arrow go around a box rather than through it
- **so that** the arrows stay readable

#### Acceptance Criteria:
- **Scenario:** A group in the way
- **Given:** a connector between two things, and a kept text or one of Larry's groups put on the straight line between them
- **When:** the board redraws the connector
- **Then:** it bends once, an L with a level leg and an upright one, that crosses nothing; when the thing in the way moves off, it is straight again

---

### User Story 913:

- **Summary:** Larry joins two things by name
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As Larry,** Igor's coach, drawing on the board
- **I want to** draw a connector between two things by their names
- **so that** my diagram on Igor's board stays joined when he rearranges it

#### Acceptance Criteria:
- **Scenario:** Connector by names
- **Given:** a group of mine and a kept text on the board
- **When:** my answer asks for a connector from the group's name to the text's
- **Then:** an arrow joins them, part of my answer's one Undo; a name the board lacks draws nothing and my next turn lists it missing

---

### User Story 914:

- **Summary:** Larry joins two things by pointing at them
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As Larry,** drawing on the board from its picture
- **I want to** give a connector's ends as points
- **so that** I can join what I see without knowing its names

#### Acceptance Criteria:
- **Scenario:** Connector by points
- **Given:** two things on the board
- **When:** my connector's ends are points on each
- **Then:** it joins the smallest thing under each point (a word of Igor's becomes one thing); with an end on bare paper it is a plain arrow

---

### User Story 915:

- **Summary:** A connector whose end is gone stays as plain ink
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** erasing part of a diagram
- **I want to** rub out one thing an arrow points at
- **so that** I don't lose the arrow I still see

#### Acceptance Criteria:
- **Scenario:** Erase an end
- **Given:** a connector between two things
- **When:** I erase one of them
- **Then:** the arrow stays where it was, as plain ink that no longer follows anything

---

### User Story 916:

- **Summary:** Larry gets connectors back with the board's strokes
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As Larry,** reading Igor's board
- **I want to** know which strokes are connectors and what they join
- **so that** I can reason about the diagram, not only its picture

#### Acceptance Criteria:
- **Scenario:** The strokes snapshot
- **Given:** a connector on the board
- **When:** the board sends Larry its strokes
- **Then:** the connector is a stroke under its name, drawn in every picture I render, whose notes say it is a connector, what it joins, its sides and its route

---

### User Story 973:

- **Summary:** A selection dropped onto writing pushes the writing down
- **Issues:** Igor on the iPad, 2026-11-17, via Larry: "same as reflowing stuff below, as opposed to drop on top"; [#945](https://github.com/idvorkin/context-grabber/issues/945) (2026-11-18: a box PaperKit showed after a margin tap dragged 223 strokes onto writing, twice, and nothing was pushed: the move came with no selection, so it was never taken for a drop); bead context-grabber-9uj2 ([story 1172](#user-story-1172))
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a) and fixed in [c5c3bf24](https://github.com/idvorkin/context-grabber/commit/c5c3bf24) after a selected drop left the writing unmoved. The original change was verified by `BoardRoomDropTests`, `just test` and `just native-build-mac`. The fix was verified on the iPad simulator with a tap-selected group ([story 1172](#user-story-1172)). The lasso drag still needs a device check.
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** rearranging my notes
- **I want to** lasso a few lines and drag them down between others
- **so that** they slot in and the lines below make room, instead of landing on top of them

#### Acceptance Criteria:
- **Scenario:** Dropped on writing
- **Given:** lines of writing down the page
- **When:** I lasso one, drag it and let go over a line further down
- **Then:** what I dragged stays where I let go, and from the clear line nearest its top everything below slides down by whole lines, half a line of air under what I dropped; ink above that line doesn't move

---

### User Story 974:

- **Summary:** The drag and the push are one Undo
- **Issues:** Igor on the iPad, 2026-11-17, via Larry; bead context-grabber-9uj2 (a drop picked up with nothing selected is one Undo too, story 1172)
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by `BoardRoomDropTests`, `just test` and `just native-build-mac`. One Undo restored both positions after the fix in [c5c3bf24](https://github.com/idvorkin/context-grabber/commit/c5c3bf24) on the iPad simulator ([story 1172](#user-story-1172)).
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** who dropped a selection in the wrong place
- **I want to** tap Undo once
- **so that** both the selection and the ink it pushed go back where they were

#### Acceptance Criteria:
- **Scenario:** One Undo
- **Given:** a drop that pushed the ink below
- **When:** I tap Undo once
- **Then:** the dragged ink is back where it started and the ink below is back up; the Undo is named *Move*

---

### User Story 975:

- **Summary:** A drop on clear paper moves only what I dragged
- **Issues:** Igor on the iPad, 2026-11-17, via Larry
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by host tests (`BoardRoomDropTests`), `just test` and the Mac build (`just native-build-mac`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** moving a note into blank space
- **I want to** drop it there
- **so that** nothing else on the board shifts

#### Acceptance Criteria:
- **Scenario:** Clear paper
- **Given:** blank paper between two lines
- **When:** I drop a selection there, or so it only touches a line at its edge
- **Then:** only what I dragged moves

---

### User Story 979:

- **Summary:** Undo and Redo of a move never push
- **Issues:** Igor on the iPad, 2026-11-17, via Larry
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by host tests (`BoardRoomDropTests`), `just test` and the Mac build (`just native-build-mac`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** stepping back and forth through a move
- **I want to** have Undo and Redo put ink only where it was
- **so that** stepping through history never opens room again

#### Acceptance Criteria:
- **Scenario:** Undo never pushes
- **Given:** a move undone
- **When:** I tap Redo, or Undo again
- **Then:** nothing else opens room

---

### User Story 1172:

- **Summary:** Text or ink dropped on writing makes room, however I picked it up
- **Issues:** bead context-grabber-d455 (its UI test left Ask at my pauses on behind a stale "Ghosts on" check, so a loaded Mac took a pause turn first); bead context-grabber-9uj2: Igor on the iPad, 2026-11-22 14:49, board ead78e80, via Larry: "OK when I drop text onto existing text, I want it to move just like if I was to select text". The log: he kept Larry's 20-letter reply (29 strokes), then dragged it twice onto his own first line (it landed at y 70, then 67, on the line at 54 to 95); each drag began on PaperKit's handwriting view with nothing selected (`selected: 0`, `held_at_start: 0`), every stroke moved the same way, and no `paper_drop` was logged: the board took a move nothing selected held for the system's, not a drop; [#1265](https://github.com/idvorkin/context-grabber/issues/1265) (iPad report, 2026-11-22 23:19, build 8df171a9: "when I put text over other text didn't move the other text"; its log shows the same drag, 102 of Larry's strokes moved alike with nothing held, and no `paper_drop` line)
- **Status:** implemented in [d340873a](https://github.com/idvorkin/context-grabber/commit/d340873a) and [c5c3bf24](https://github.com/idvorkin/context-grabber/commit/c5c3bf24), with settling checks in [dac8955f](https://github.com/idvorkin/context-grabber/commit/dac8955f) and [f731bef7](https://github.com/idvorkin/context-grabber/commit/f731bef7). Host coverage uses the iPad's drag in `PaperProbePickupTests` and its landing boxes in `BoardRoomDropTests`. `just native-test` and `just native-build-mac` passed on the earlier implementation. The 2026-11-22 iPad simulator runs of `WhiteboardDropRoomUITests` (rung 2) verified the push and Undo for a tap-selected group on the implementation in c5c3bf24, before the settling checks. The session log also confirmed the push via `pushed_now`. Dragging directly from PaperKit's handwriting view with nothing selected still needs a physical iPad check (rung 3).
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** rearranging my notes, my writing and the replies of Larry's I kept
- **I want to** drop a piece of text or ink on writing however I picked it up, lassoed, tapped or grabbed straight off the page
- **so that** the writing under it moves down in whole lines as if I had inserted text there, instead of the two landing on top of each other

#### Acceptance Criteria:
- **Scenario:** A kept text of Larry's dropped on my writing
- **Given:** a reply of Larry's I kept, and a line of my writing elsewhere
- **When:** I drag the reply, by a tap on it or straight off the page with nothing selected, and let go over my line
- **Then:** it stays where I let go, my line and everything below it move down by whole lines from the clear line above it until they are half a line clear of it, and one Undo puts the reply back and my writing back up

---

### User Story 1177:

- **Summary:** The system rearranging my handwriting opens no room
- **Issues:** bead context-grabber-9uj2 (split from story 1172)
- **Status:** implemented in [d340873a](https://github.com/idvorkin/context-grabber/commit/d340873a) and [c5c3bf24](https://github.com/idvorkin/context-grabber/commit/c5c3bf24); verified by host tests (`PaperProbePickupTests`), `just native-test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** writing on a board the system reflows on its own
- **I want to** have only my own drops push writing down
- **so that** a reflow never shoves my lines around

#### Acceptance Criteria:
- **Scenario:** The system rearranging my handwriting
- **Given:** writing the system moves on its own, words going different ways or with nothing being dragged
- **When:** it moves
- **Then:** nothing else moves to make room

---

### User Story 1178:

- **Summary:** The log says how a drop was picked up and why it opened no room
- **Issues:** bead context-grabber-9uj2 (split from story 1172: the iPad's drag left no `paper_drop` line at all)
- **Status:** implemented in [d340873a](https://github.com/idvorkin/context-grabber/commit/d340873a) and [c5c3bf24](https://github.com/idvorkin/context-grabber/commit/c5c3bf24), with stale push logging in [dac8955f](https://github.com/idvorkin/context-grabber/commit/dac8955f). `PaperProbePickupTests` covers pickup classification on the host. The log confirmed the push on the earlier iPad simulator build ([story 1172](#user-story-1172)). The unselected drag's log still needs a physical iPad check.
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** whose drop didn't make room
- **I want to** have the session log say what happened
- **so that** the next fix starts from evidence, not a guess

#### Acceptance Criteria:
- **Scenario:** The log
- **Given:** any drag of mine that moves ink
- **When:** I let go
- **Then:** the session log records where the ink started and landed, how the drag was picked up, whether room opened and why a move was rejected or a planned push skipped

---

### User Story 1148:

- **Summary:** One rule for making room: Larry's ink never covers writing he didn't see, and mine moves down in whole lines from a cut between lines
- **Status:** the rule decided 2026-11-22; already what a paste (stories 852, 869), a dropped selection (973), the margin handle (858, 930), Keep and Keep all (1004–1006, 1149; Keep group became Keep all in #1224) and Larry's text from a change (992) do, each verified on its own story; and since 2026-11-22 Larry's own make-room too (stories 1195, 1198 and 1199, bead context-grabber-2gu)
- **Spec:** [Ink that reflows like text](../superpowers/specs/2026-11-16-whiteboard-object-layer-design.md), *Decided 2026-11-22*
- **Issues:** Igor's pick on the design board, 2026-11-22: "One rule everywhere: his ink never covers writing he didn't see; my newer writing moves down in whole lines; every cut lands between lines; Keep all behaves like Keep group. A fold is erased only by its words or its marker."

#### Use Case:
- **As someone** whose ink is moved by Larry, by a paste and by my own hand
- **I want to** have one rule for whatever moves my writing
- **so that** I can tell what will move, and how far, before it does

#### Acceptance Criteria:
- **Scenario:** Something lands on writing Larry didn't see
- **Given:** writing of mine that wasn't in the picture Larry answered, and something about to land on it: a mark of his I keep, however I keep it, a text of his, or a paste
- **When:** it lands
- **Then:** it sits where it was meant to, my writing from the nearest clear line between rows moves down by whole lines until it is clear of it, no row of mine is split or covered, writing he saw doesn't move, and one Undo puts it all back

---

### User Story 969:

- **Summary:** A word slid along its own line moves nothing else
- **Issues:** review of stories 973–975, 2026-11-17: a word slid sideways onto its neighbour pushed its own line down
- **Status:** implemented in the review fix that follows [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a) on this branch; verified by host tests (`BoardRoomDropTests`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Dropping ink onto writing makes room](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md#dropping-ink-onto-writing-makes-room)

#### Use Case:
- **As someone** rearranging words within a line
- **I want to** slide one along its line, even over its neighbour
- **so that** the line stays put and only the word moves

#### Acceptance Criteria:
- **Scenario:** Along its own line
- **Given:** a line of words
- **When:** I lasso one and drop it further along the same line, over the word beside it
- **Then:** only what I dragged moves

---

### User Story 940:

- **Summary:** A finger tap on a kept text rewords it in place
- **Issues:** bead context-grabber-yfrl (the UI test read the old words before the new ones were drawn: a flake, not the app); bead context-grabber-4ief (a Return that came in the same change as other letters, as " world\n" did under load on the iPad simulator, stayed in the field as a new line and the field stayed open: the app, not the test)
- **Status:** the first tap selects and the second opens since story 1197 (context-grabber-awz) in [d7ddf7d7](https://github.com/idvorkin/context-grabber/commit/d7ddf7d7); implemented in [ea93cbb](https://github.com/idvorkin/context-grabber/commit/ea93cbb); verified by host tests (`BoardRewordTests`: `testItWrapsAtTheWiderOfItsOwnWidthAndTheWebBoardsWithinThePage`, `testWordsWrapByWordKeepTheirOwnBreaksAndALongWordBreaks`, `testTheNewWordsStartWhereTheOldOnesDid`; `just test`) and the Mac build (`just native-build-mac`); on the simulator against the fake Cockpit (`WhiteboardRewordUITests.testATapOnAKeptTextRewordsItInPlace`, rung 2); the test waits for the new words before reading them in [cafe6cc1](https://github.com/idvorkin/context-grabber/commit/cafe6cc1) (context-grabber-yfrl), passing 3 runs of 3 on the iPad simulator (rung 2); a Return that comes in one change with other letters is done too in [2a4b481a](https://github.com/idvorkin/context-grabber/commit/2a4b481a) (context-grabber-4ief), host tests (`BoardRewordTests`: `testAReturnArrivingWithOtherLettersAtOnceIsDoneToo` and two more) and `WhiteboardRewordUITests` 3 runs of 3, 5 of 5 each, on the iPad simulator (rung 2); a text of Larry's opens at the second tap in [38843ea5](https://github.com/idvorkin/context-grabber/commit/38843ea5) (#1171, story 1141), host tests and the Mac build; not yet seen on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As someone** with one of Larry's texts, a To text result or my own typed text on the board
- **I want to** tap it twice and change its words where it is
- **so that** fixing a word doesn't mean erasing the whole text and starting again

#### Acceptance Criteria:
- **Scenario:** A word changed
- **Given:** a kept text (my own typed or To text text, one of Larry's, or one inside a group) reading "hello" on a board drawn on here, and no marks of Larry's showing
- **When:** I tap it with a finger once to select it (story 1197), tap it again, change the words to "hello world" and press Return
- **Then:** the text shows "hello world" from the same top-left in its own lettering, size and colour, wrapped by word to its width; one undo brings "hello" back

---

### User Story 1347:

- **Summary:** A paste with a line break inside it keeps the break, and the reword field stays open
- **Issues:** bead context-grabber-4ief (a Return was done wherever a new line came in the change, so a pasted "buy milk", new line, "call mom" closed the field as "buy milkcall mom")
- **Status:** implemented in [47c1ce17](https://github.com/idvorkin/context-grabber/commit/47c1ce17); verified by host tests (`BoardRewordTests.testAPasteWithALineInsideKeepsItAndOnlyAnEndingLineIsDone`, rung 1); not yet seen on the simulator or the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As someone** rewording a kept text on the board
- **I want to** paste words with a line break inside them
- **so that** the text keeps its lines and I finish it with Return when I'm ready

#### Acceptance Criteria:
- **Scenario:** A paste with a line break inside it
- **Given:** the reword field open on a kept text reading "note: "
- **When:** I paste "buy milk", a new line and "call mom"
- **Then:** the field stays open, reading "note: buy milk" over "call mom"

---

### User Story 1197:

- **Summary:** The first tap on any kept text selects it; the second rewords it
- **Status:** implemented in [d7ddf7d7](https://github.com/idvorkin/context-grabber/commit/d7ddf7d7); verified by host tests and lint (`just native-test`), the Mac build (`just native-build-mac`) and the iPad simulator (rung 2: `WhiteboardRewordUITests`, all three, among them `testAFirstTapPicksUpATextToDrag`: the first tap selects with *Text · tap to reword* and opens no field, the second opens it, a drag after the first tap moves it; `WhiteboardGroupTapUITests` and `WhiteboardTheirsTapUITests` pass too); the drag moved the text sideways rather than down on the simulator until story 1201 (bead context-grabber-vhae), which now asserts the move is down by the finger's travel; not yet seen on the iPad
- **Issues:** bead context-grabber-awz (Igor, design board, 2026-11-22: "a second tap rewords a text"). The bead named this story 1154; 1197 was reserved for it.
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *The first finger tap on any kept text selects it; the second opens it*

#### Use Case:
- **As someone** with my own typed or To text text on the board
- **I want to** a first tap to pick it up and a second to open its words, as Larry's and grouped texts already do
- **so that** I can move a text with a tap and a drag without the keyboard coming up, and every text behaves the same

#### Acceptance Criteria:
- **Scenario:** The first tap picks it up
- **Given:** a kept text of my own on a board drawn on here, nothing selected and no marks of Larry's showing
- **When:** I tap it with a finger
- **Then:** the text alone is selected, its label says *Text · tap to reword* and no field opens, so a drag now moves it (a second tap opens the field, story 940)

---

### User Story 1201:

- **Summary:** A drag that begins inside a small selection moves it, even where its stretch handles cover it
- **Status:** implemented in [22e3929a](https://github.com/idvorkin/context-grabber/commit/22e3929a) and [bbfcf1ed](https://github.com/idvorkin/context-grabber/commit/bbfcf1ed); verified by host tests and lint (`just native-test`, `PaperProbePickupTests`), the Mac build (`just native-build-mac`) and the iPad simulator (rung 2, build fd53b985, the pre-rebase build of the same patches: `WhiteboardRewordUITests.testAFirstTapPicksUpATextToDrag` asserts the text lands 0.1 of the window lower with its left edge where it was and one Undo puts it back; `WhiteboardGroupTapUITests`, `WhiteboardDropRoomUITests`, `WhiteboardTheirsTapUITests`, `WhiteboardToTextUITests` and `WhiteboardPaperGhostsUITests` pass too); not yet seen on the iPad. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-vhae (found on the simulator verifying story 1197: a drag 120 points down on a selected *hello* stretched it 34 points left, `paper_ink` resized 6, started on `CanvasElementResizeHandle`; maybe part of Igor's "when I select and want to move something, it's borked", 2026-11-22). Following the finger without the stretch: bead context-grabber-ppha
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A drag that starts inside a selection moves it, however small it is*

#### Use Case:
- **As someone** who has just selected a word or a small mark on the board
- **I want to** drag it with a finger from its middle and have it land where my finger went
- **so that** moving a small thing doesn't stretch it sideways and need undoing

#### Acceptance Criteria:
- **Scenario:** A small selected text dragged straight down
- **Given:** a kept text of one short word, selected, on a board drawn on here
- **When:** I put a finger on the word and drag it straight down, then lift
- **Then:** the word stretches under my finger while it is down (the system draws that), and on the lift it lands as far down as my finger went, not moved across and at its own size; one Undo, named *Move*, puts it back

---

### User Story 1150:

- **Summary:** A drag from a corner handle's own knob, or from outside the box, still stretches the selection
- **Status:** implemented in [bbfcf1ed](https://github.com/idvorkin/context-grabber/commit/bbfcf1ed); verified by host tests (`PaperProbePickupTests`; `just native-test`) and the iPad simulator (rung 2, build fd53b985, the pre-rebase build of the same patch: `WhiteboardRewordUITests.testAStretchFromACornerKnobStillStretches`); not yet seen on the iPad. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-vhae (the move of story 1201 must not take a stretch that was meant)
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A drag that starts inside a selection moves it, however small it is*

#### Use Case:
- **As someone** who has selected something on the board
- **I want to** stretch it by dragging a corner handle's knob
- **so that** making a small selection move when dragged from inside (story 1201) doesn't take away resizing it

#### Acceptance Criteria:
- **Scenario:** A stretch I meant
- **Given:** a selection
- **When:** I drag one of its corner handles from the handle's knob, even the part of it inside the selected thing's box, or from outside the box
- **Then:** it stretches, as before

---

### User Story 1151:

- **Summary:** A small selection dragged from inside onto ink still makes room
- **Status:** implemented in [22e3929a](https://github.com/idvorkin/context-grabber/commit/22e3929a); verified by the iPad simulator (rung 2, build fd53b985, the pre-rebase build of the same patch: `WhiteboardRewordUITests.testASmallTextDroppedOnALinePushesItDown`, the line goes down clear of it, `paper_resize_as_move` logged); not yet seen on the iPad. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-vhae (the move of story 1201 lands as a drop, so it must make room as story 973's drops do)
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A drag that starts inside a selection moves it, however small it is*

#### Use Case:
- **As someone** moving a small selected text onto a line of ink
- **I want to** the ink to move clear of it, as any drop onto ink does
- **so that** a move from inside a small selection (story 1201) never leaves the text on top of my writing

#### Acceptance Criteria:
- **Scenario:** Dropped onto ink
- **Given:** a small selected text and a line of ink below it
- **When:** I drag the text from inside it down onto the line and lift
- **Then:** the line moves down clear of it, as any drop onto ink does (story 973)

---

### User Story 941:

- **Summary:** Emptied words delete the text; unchanged words change nothing
- **Status:** implemented in [ea93cbb](https://github.com/idvorkin/context-grabber/commit/ea93cbb); verified by host tests (`BoardRewordTests.testNewWordsAreTrimmedAndCappedEmptyDeletesSameChangesNothing`; `just test`) and the Mac build (`just native-build-mac`); the opening tap's dot taken back in [9191a96](https://github.com/idvorkin/context-grabber/commit/9191a96); on the simulator against the fake Cockpit (`WhiteboardRewordUITests.testEmptyWordsDeleteTheText`, rung 2); not yet seen on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As someone** editing a kept text
- **I want to** empty it to delete it, and leave it untouched to change nothing
- **so that** the editor is also the quickest way to remove a text, and opening it by mistake costs nothing

#### Acceptance Criteria:
- **Scenario:** Emptied, and left alone
- **Given:** a kept text open for editing
- **When:** I delete all its words and press Return, or open another and tap off it without typing
- **Then:** the first text goes, one undo bringing it back; the second stays exactly as it was, with no undo step for it

---

### User Story 942:

- **Summary:** Larry knows a reworded text as the same text
- **Status:** implemented in [ea93cbb](https://github.com/idvorkin/context-grabber/commit/ea93cbb); verified by host tests (`BoardRewordTests`: `testAnUndoneWordingsVersionDoesntDissolveTheText`, `testLarryHearsWhichTextWasReworded`; `just test`) and the Mac build (`just native-build-mac`); not yet seen against the real Cockpit or on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As** Larry, reading Igor's board
- **I want to** see a reworded text under the id I knew it by, with its new words
- **so that** a later move or answer can still name it

#### Acceptance Criteria:
- **Scenario:** Reworded
- **Given:** a kept text Larry knows as `text-1`
- **When:** Igor rewords it
- **Then:** Larry hears a strokes change that names `text-1` as reworded, and the board he reads has `text-1` with the new words; an undo gives him the old words under `text-1` again

---

### User Story 943:

- **Summary:** A held shape shows clean before the Pencil lifts
- **Status:** implemented in [2640a36](https://github.com/idvorkin/context-grabber/commit/2640a36); verified by host tests (`BoardShapeSnapTests`: `testHeldStillTheCleanShapeShowsBeforeTheLift`, `testWritingHeldStillShowsNothing`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad (the simulator has no Pencil to hold)
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A snap you see before you lift*

#### Use Case:
- **As someone** drawing a box or a line with the Pencil
- **I want to** see the clean shape as soon as I hold still, before I lift
- **so that** I know it will snap, and to what, while I can still change my mind

#### Acceptance Criteria:
- **Scenario:** Held, then lifted
- **Given:** I draw a nearly square box on a board drawn on here
- **When:** I hold the Pencil still at its end for about half a second, with it still down
- **Then:** the box shows as a clean rectangle in my pen's colour and width at once; lifting keeps it, one undo giving my raw box back

---

### User Story 944:

- **Summary:** Moving on after the clean shape shows brings the raw stroke back
- **Status:** implemented in [2640a36](https://github.com/idvorkin/context-grabber/commit/2640a36); verified by host tests (`BoardShapeSnapTests.testMovingOnTakesTheShapeAwayUntilHeldAgain`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A snap you see before you lift*

#### Use Case:
- **As someone** who held still by accident in the middle of a drawing
- **I want to** keep drawing and have my stroke stay mine
- **so that** a pause never turns a sketch into a shape I didn't ask for

#### Acceptance Criteria:
- **Scenario:** Held, then moved on
- **Given:** a line I drew whose clean shape is showing, the Pencil still down
- **When:** I move the Pencil on to draw a curl, and lift without holding still again
- **Then:** the clean line goes as I move, the raw stroke shows again, and it lands exactly as I drew it

---

### User Story 1059:

- **Summary:** A scratch-out never puts back ink I had just moved
- **Status:** implemented in [820ec0ae](https://github.com/idvorkin/context-grabber/commit/820ec0ae); verified by host tests (`WhiteboardScratchOutTests.testATakeBackIsRedoneWhenTheStepItUndidWasNotTheZigzags`, failing before the fix for a step that moved ink), `just test`, the Mac build (rung 1.5) and the iPad simulator's whiteboard UI classes (rung 2, 2026-11-21, `WhiteboardScratchOutUITests` among them); PaperKit taking back the wrong step happens only on the iPad (the log's `base: redone`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*
- **Issues:** context-grabber-geaz (from [#999](https://github.com/idvorkin/context-grabber/issues/999)'s review)

#### Use Case:
- **As someone** who tidies my board with the lasso and scratches out words as I go
- **I want** a scratch-out to take only what it covers
- **so that** ink I just moved never jumps back to where it was

#### Acceptance Criteria:
- **Scenario:** A move, then a scratch-out
- **Given:** a board on paper where I have just moved a word with the lasso
- **When:** I scratch out another word with a quick zigzag
- **Then:** the scratched-out word and the zigzag are gone, and the word I moved stays where I put it

---

### User Story 1108:

- **Summary:** The eraser scrubbed back and forth over ink erases, and is never a scratch-out
- **Status:** implemented in [11de5bf2](https://github.com/idvorkin/context-grabber/commit/11de5bf2) and verified by `just native-test`, the Mac build and the iPad simulator. The eraser UI test, then a test of its own, reproduced the scratch-out before the fix and passed afterward, along with all 66 tests in the whiteboard UI suite. The author reported all three `WhiteboardScratchOutUITests` passing on the iPad simulator at [a371c3af](https://github.com/idvorkin/context-grabber/commit/a371c3af). The eraser check now runs in `WhiteboardScratchOutUITests.testWordScratchOutAndEraserSweep`. The Pencil's eraser scrub on the iPad, which crashed, is still to see.
- **Issues:** [#1121](https://github.com/idvorkin/context-grabber/issues/1121), [#1120](https://github.com/idvorkin/context-grabber/issues/1120): the iPad crashed (signal 5, PaperKit trapping inside Undo) when the board took back the "zigzag" of an eraser sweep it had read as a scratch-out
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** rubbing out ink with the eraser on the iPad
- **I want to** scrub back and forth as fast as I like
- **so that** the eraser just erases, and the board never mistakes it for a pen's scratch-out and falls over

#### Acceptance Criteria:
- **Scenario:** A fast scrub with the eraser over a word
- **Given:** a board on paper with a word written on it, and the eraser picked
- **When:** I scrub the eraser back and forth fast over the word with the Pencil
- **Then:** the eraser rubs out what it crosses, no scratch-out flash or *Nothing under the scribble to erase* shows, and the app stays up

---

### User Story 1095:

- **Summary:** A small label on a selection says what I picked and what applies to it
- **Issues:** [#1045](https://github.com/idvorkin/context-grabber/issues/1045)
- **Status:** implemented in [a5a8bf80](https://github.com/idvorkin/context-grabber/commit/a5a8bf80); verified by host tests (`BoardSelectionLabelTests`; `just native-test`), the Mac build (rung 1.5) and on the iPad simulator (rung 2, 2026-11-22: `WhiteboardToTextUITests.testToTextPutsTheWordsInTheInksPlace` reads *Selected: Ink, To text* and `WhiteboardConnectUITests.testALassoedArrowBetweenTwoWordsConnectsThem` *Selected: Arrow, Connect*, all 66 whiteboard UI tests passing); not yet seen on the iPad: a real lasso and the comparison #1045 asks for; the plain-ink label says *Ink · hold for To text* since [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920) (#1386; `BoardSelectionLabelTests`)
- **Spec:** [What's selected](../superpowers/specs/2026-11-22-whiteboard-selection-label-design.md)

#### Use Case:
- **As someone** whose board holds handwriting, Larry's kept texts and groups, and connectors that all look alike
- **I want** a small label beside what I selected saying what it is (*Ink*, *Text*, *Group*, *Connector*) and what applies (*To text*, *tap to reword*, *moves as one*, *follows its two ends*)
- **so that** my first action on it is the one I meant, not a try to find out what it is

#### Acceptance Criteria:
- **Scenario:** My handwriting
- **Given:** a board on paper with my handwriting
- **When:** I lasso my handwriting
- **Then:** the label says *Ink · hold for To text*; it sits just above the selection, never takes a touch (my next stroke draws), and is in no picture Larry gets

---

### User Story 1166:

- **Summary:** The label on a group of Larry's that holds a kept text says *Group*
- **Issues:** bead context-grabber-owy (a group holding a kept text read *2 things · move together*)
- **Status:** implemented in [445eb85a](https://github.com/idvorkin/context-grabber/commit/445eb85a); verified by host tests (`BoardSelectionLabelTests`; `just native-test`) and the Mac build (rung 1.5); not yet seen on the iPad: a grouped text
- **Spec:** [What's selected](../superpowers/specs/2026-11-22-whiteboard-selection-label-design.md)

#### Use Case:
- **As someone** whose board holds groups Larry made of a box and its label, or of two labels
- **I want** the label on all of such a group to say *Group · moves as one*
- **so that** I know it moves as one before I drag it, as with any other group

#### Acceptance Criteria:
- **Scenario:** A group of Larry's that holds a text
- **Given:** a board with a group of Larry's made of a box and its label, and another of two labels
- **When:** I select all of either group
- **Then:** the label says *Group · moves as one*, not *2 things · move together*; a kept text in no group still says *Text · tap to reword*

---

### User Story 1096:

- **Summary:** The label on a kept text says it can be reworded, and an erase turns it to ink
- **Issues:** [#1045](https://github.com/idvorkin/context-grabber/issues/1045)
- **Status:** implemented in [a5a8bf80](https://github.com/idvorkin/context-grabber/commit/a5a8bf80); verified by host tests (`BoardSelectionLabelTests`; `just native-test`) and the Mac build (rung 1.5); not yet seen on the iPad: a kept text, reworded or erased; the plain-ink label says *Ink · hold for To text* since [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920) (#1386; `BoardSelectionLabelTests`)
- **Spec:** [What's selected](../superpowers/specs/2026-11-22-whiteboard-selection-label-design.md)

#### Use Case:
- **As someone** whose board holds Larry's kept texts beside my handwriting
- **I want** the label on a selected text to say *Text · tap to reword*, and to say *Ink · hold for To text* once an erase has broken it
- **so that** I know a tap rewords it before I try, and know when it has become ink

#### Acceptance Criteria:
- **Scenario:** A kept text, then one an erase broke
- **Given:** a board on paper with a kept text of Larry's, and another kept text with one letter erased
- **When:** I select each one in turn
- **Then:** the label says *Text · tap to reword* on the whole text, and *Ink · hold for To text* on the one with the erased letter

---

### User Story 1094:

- **Summary:** The label on a connected word says a connector follows it
- **Issues:** [#1045](https://github.com/idvorkin/context-grabber/issues/1045)
- **Status:** implemented in [a5a8bf80](https://github.com/idvorkin/context-grabber/commit/a5a8bf80); verified by host tests (`BoardSelectionLabelTests`; `just native-test`) and the Mac build (rung 1.5); not yet seen on the iPad: a connected word and a connector
- **Spec:** [What's selected](../superpowers/specs/2026-11-22-whiteboard-selection-label-design.md)

#### Use Case:
- **As someone** who joins words on my board with connectors
- **I want** the label on a connected word to say a connector follows it, and on a connector that it follows its two ends
- **so that** I move a connected word knowing its connector comes along

#### Acceptance Criteria:
- **Scenario:** A connected word
- **Given:** a word of mine a connector ends on
- **When:** I hold the Pencil on it and lift without moving
- **Then:** the label says *Group · moves as one · a connector follows it*, and a selected connector says *Connector · follows its two ends*

---

### User Story 1276:

- **Summary:** A tap on the board brings up no Paste or Select All menu
- **Issues:** [#1385](https://github.com/idvorkin/context-grabber/issues/1385) (Igor, 2026-11-24: "Every time I tap I get paste and select all"; then "better would be using my long hold paste")
- **Status:** implemented in [45bc8880](https://github.com/idvorkin/context-grabber/commit/45bc8880); verified by `just native-test`, the Mac build (rung 1.5) and the whiteboard classes on the iPad simulator (rung 2, `WhiteboardQuietTapUITests`: finger taps with the Pencil seen bring up no *Paste* or *Select All*). The simulator never brought the menu up, even before the fix (it comes with Only Draw with Apple Pencil, which a simulator can't set), so the iPad is still to show it: its log's `tap_menu_quiet` and an empty `board_cover` `edit_menu` after a tap
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *A tap brings up no system menu*

#### Use Case:
- **As someone** tapping around my board with a finger or the Pencil
- **I want** a tap to bring up no system menu
- **so that** nothing covers my writing, and paste is where I reach for it, in the hold menu

#### Acceptance Criteria:
- **Scenario:** A tap on the board
- **Given:** ink on the board and text on the clipboard
- **When:** I tap blank paper or my ink with a finger
- **Then:** no *Paste* or *Select All* menu comes up

---

### User Story 1306:

- **Summary:** A tap on my selection brings up its menu without Paste or Select All
- **Issues:** [#1385](https://github.com/idvorkin/context-grabber/issues/1385)
- **Status:** implemented in [45bc8880](https://github.com/idvorkin/context-grabber/commit/45bc8880); verified by `just native-test` and the Mac build (rung 1.5). The iPad simulator could not bring the selection's menu up either, so the iPad is still to show it: its log's `tap_menu_quiet` with `selected` above 0 after a tap on a selection
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *A tap brings up no system menu*

#### Use Case:
- **As someone** who selects ink on my board and taps it to act on it
- **I want** the selection's menu to offer only what acts on it
- **so that** paste stays in the hold menu, where I reach for it

#### Acceptance Criteria:
- **Scenario:** A tap on my selection
- **Given:** some of my ink selected
- **When:** I tap the selection
- **Then:** its menu offers what acts on it (Copy, Delete) and never *Paste* or *Select All*

---

### User Story 1309:

- **Summary:** To text is in the hold menu, and nowhere else
- **Issues:** [#1386](https://github.com/idvorkin/context-grabber/issues/1386) (Igor, 2026-11-24 05:19: "To text only in the long-press menu")
- **Status:** implemented in [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920); verified by host tests (`BoardHoldMenuTests`, `WebHoldMenuTests`: the row after Select on a word, a group and a header's row, none on a kept text; `just native-test`), the Mac build (rung 1.5) and every whiteboard class on the iPad simulator (rung 2: `WhiteboardToTextUITests` reaches To text only through the hold menu, with nothing beside the selection). The wasm smoke (`test-board-wasm.mjs`, abi 21) is updated but did not run here: this Mac has no wasm Swift SDK
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*; [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold*

#### Use Case:
- **As someone** writing on the board
- **I want** To text offered when I hold a finger on my writing, and never popping up on its own beside a selection
- **so that** nothing appears over the board unless I ask for it

#### Acceptance Criteria:
- **Scenario:** Held on my writing
- **Given:** a word of my handwriting on a board drawn on here, on the iPad or the web board
- **When:** I hold a finger still on it
- **Then:** the menu offers *Select*, then *To text*, then *Delete*, and nothing shows beside a selection made any other way

---

### User Story 1310:

- **Summary:** A hold on my selection acts on all of it
- **Issues:** [#1386](https://github.com/idvorkin/context-grabber/issues/1386) (the vision's "a tap inside his selection acts on the selection")
- **Status:** implemented in [d50a3920](https://github.com/idvorkin/context-grabber/commit/d50a3920); verified by host tests (`BoardHoldMenuTests.testHeldOnTheSelectionTheMenuTakesAllOfIt`, `WebHoldMenuTests`; `just native-test`) and on the iPad simulator (rung 2: `WhiteboardToTextUITests` and `WhiteboardRewordUITests` select the ink, hold on it and choose To text). The wasm smoke's `bw_hold_menu_on` checks did not run here: no wasm Swift SDK
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold*; [Board rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), *Interface 21*

#### Use Case:
- **As someone** who lassoed two lines of my handwriting
- **I want** a finger held on them to offer To text for the whole selection
- **so that** I can turn more than one word into text at once, now that To text lives only in the hold menu

#### Acceptance Criteria:
- **Scenario:** Two lines lassoed
- **Given:** two lines of my handwriting selected with the lasso
- **When:** I hold a finger still on one of their words and choose To text
- **Then:** both lines are read and typed in their place, one undo, as To text does
