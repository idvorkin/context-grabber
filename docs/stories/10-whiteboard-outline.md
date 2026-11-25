# The whiteboard: Headers, folds and the outline

Headers from the margin, an underline or a #, folding sections, levels, and what Larry sees of them. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 855:

- **Summary:** A margin tap makes a header, and another folds it
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: a margin tap makes a header once, a fold hides the indented lines and closes up whole lines and unfold puts everything back, a push never splits a fold from its header, unfold makes room for what was written under it, an undo that shows the ink opens the fold); a simulator UI test, `WhiteboardOutlineUITests.testAMarginTapMakesAHeaderAndAnotherFoldsIt`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** [#946](https://github.com/idvorkin/context-grabber/issues/946) (the iPad, 2026-11-18, build 69f912fb: two finger taps in the margin each came back from PaperKit as a selection change, a resize box with no elements showed, and the log went silent for 14 s before "I think I just hung"; not settled, so `main_stall` now says whether the main thread stopped answering); [#945](https://github.com/idvorkin/context-grabber/issues/945) (half a minute later "a bad state now for selection": from those margin taps on, the touch watcher logged no touch, while 223 strokes moved twice by a drag on the box with nothing selected; `paper_selection` and the watch state on `paper_ink` now say what PaperKit selected and what took the touches)

#### Use Case:
- **As someone** writing an outline on the board
- **I want to** turn a line into a header with one tap and fold what is under it
- **so that** a long board reads like an outline

#### Acceptance Criteria:
- **Scenario:** Make a header
- **Given:** a line of writing with indented lines under it
- **When:** I tap the margin beside it
- **Then:** a ▾ shows beside it in the margin

---

### User Story 1179:

- **Summary:** A header made or unmade by a tap is one Undo of its own
- **Status:** implemented in [28d35f89](https://github.com/idvorkin/context-grabber/commit/28d35f89) and [f9034ae2](https://github.com/idvorkin/context-grabber/commit/f9034ae2), with one Larry report per grouped Undo in [616275fb](https://github.com/idvorkin/context-grabber/commit/616275fb). `just test` and `just native-build-mac` passed. On the iPad simulator (rung 2, 2026-11-22), `WhiteboardOutlineUITests` passed, including `testAMarginTapsHeaderIsOneUndoThatLeavesTheInk` (since bead context-grabber-3k6 it also checks *Not a header* on a fold, once a test of its own), as did `WhiteboardScratchOutUITests`.
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** bead `context-grabber-ssl` (a header made or unmade alone was no Undo step: Undo took back the stroke before it and left the ▾)

#### Use Case:
- **As someone** writing an outline on the board
- **I want to** take back a header a stray margin tap made, with one Undo
- **so that** a wrong guess costs one Undo and never the stroke before it

#### Acceptance Criteria:
- **Scenario:** A stray tap costs one Undo
- **Given:** a line I just made a header with a margin tap or *Make header*, or an open header I removed with *Not a header*
- **When:** I tap Undo
- **Then:** Undo, named *Make header* or *Not a header*, restores whether the line was a header and whether I had
  declined it as a header, leaving every stroke in place. Redo reapplies the change.

---

### User Story 872:

- **Summary:** A tap on a header's mark folds its section and another unfolds it
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: a margin tap makes a header once, a fold hides the indented lines and closes up whole lines and unfold puts everything back, a push never splits a fold from its header, unfold makes room for what was written under it, an undo that shows the ink opens the fold); a simulator UI test, `WhiteboardOutlineUITests.testAMarginTapMakesAHeaderAndAnotherFoldsIt`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad. Separate *Fold* and *Unfold* Undo labels added in [28d35f89](https://github.com/idvorkin/context-grabber/commit/28d35f89).
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing an outline on the board
- **I want to** fold the lines under a header and open them again
- **so that** a long board reads like an outline

#### Acceptance Criteria:
- **Scenario:** Fold and unfold
- **Given:** a header with three indented lines and a line at its indent below them
- **When:** I tap its mark
- **Then:** the three lines hide, the line below slides up under the header, and the mark says ▸ 3. Tapping again
  puts everything back where it was. Each action has one Undo, named *Fold* or *Unfold*.

---

### User Story 856:

- **Summary:** Folds nest, and a section ends where the ink returns to the header's indent
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: folds nest and the inner stays folded through the outer's unfold, blank paper never ends a section, a header whose next line isn't indented runs to the next at its indent); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing a deeper outline
- **I want to** fold a section with its sub-sections inside it
- **so that** folding behaves as in an outliner

#### Acceptance Criteria:
- **Scenario:** A folded section inside another
- **Given:** a header with an indented header under it, itself folded
- **When:** I fold the outer one and unfold it again
- **Then:** the inner one is still folded

---

### User Story 873:

- **Summary:** Blank paper never ends a section
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: folds nest and the inner stays folded through the outer's unfold, blank paper never ends a section, a header whose next line isn't indented runs to the next at its indent); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing an outline with gaps in it
- **I want to** have a section run on past blank paper to the next line at its header's indent
- **so that** folding takes the whole section

#### Acceptance Criteria:
- **Scenario:** Blank paper
- **Given:** a header whose indented lines run on after a gap of blank paper
- **When:** I fold it
- **Then:** the lines after the gap fold too, up to the first line back at the header's indent

---

### User Story 1231:

- **Summary:** Ink written under a folded header stays outside its fold
- **Status:** implemented in [5c6650ae](https://github.com/idvorkin/context-grabber/commit/5c6650ae); verified by host tests (`BoardFoldWrittenUnderTests`, from the Cockpit's .ink repro: 21 hidden, 31 before the fix; the header's JSON round trip), `just native-test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests` on the iPad simulator (rung 2, 2026-11-23, 9/9); not yet seen with the Pencil on the iPad. The web board needs its unfold to record the header's `ends` (spec, board rules on the web)
- **Issues:** context-grabber-eysh (Igor's board, 2026-11-23; Cockpit bead cockpit-9ik: 10 new strokes went into a 145-stroke fold)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** who folds a section and keeps writing just under its header
- **I want to** have what I wrote stay out when I fold the section again
- **so that** a fold never hides a new thought I didn't ask it to hide

#### Acceptance Criteria:
- **Scenario:** Written under the fold, then folded again
- **Given:** a header whose lines aren't indented, folded, and a new line I wrote just under it while it was folded
- **When:** I unfold it and fold it again
- **Then:** the new line shows below the header, and only the section's own lines fold, as they did the first time

---

### User Story 1232:

- **Summary:** Unfolding with nothing written leaves the section as it was
- **Status:** implemented in [5c6650ae](https://github.com/idvorkin/context-grabber/commit/5c6650ae); verified by host tests (`BoardFoldWrittenUnderTests`: an unfold with nothing written), `just native-test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests` on the iPad simulator (rung 2, 2026-11-23, 9/9); not yet seen with the Pencil on the iPad
- **Issues:** context-grabber-eysh
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** who folds and unfolds a section without writing under it
- **I want to** have the fold hide the same lines each time
- **so that** keeping new ink out of a fold never shrinks a section I didn't touch

#### Acceptance Criteria:
- **Scenario:** Nothing written under the fold
- **Given:** a folded header with nothing written under it
- **When:** I unfold it and fold it again
- **Then:** the fold hides the same lines as before, and the section ends where it always did

---

### User Story 1233:

- **Summary:** Erasing the ink written under a fold lets the section run on again
- **Status:** implemented in [5c6650ae](https://github.com/idvorkin/context-grabber/commit/5c6650ae); verified by host tests (`BoardFoldWrittenUnderTests`: the new ink erased), `just native-test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests` on the iPad simulator (rung 2, 2026-11-23, 9/9); not yet seen with the Pencil on the iPad
- **Issues:** context-grabber-eysh
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** who wrote under a folded header and then changed my mind
- **I want to** have the section run on as before once I erase that ink
- **so that** an erased line leaves no hidden end behind in my outline

#### Acceptance Criteria:
- **Scenario:** The new ink erased
- **Given:** a section ended by ink written under it while it was folded
- **When:** I erase that ink
- **Then:** the section runs on again as it did before

---

### User Story 857:

- **Summary:** Larry knows folded ink is folded, not erased
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: the fold's wire and folded names, `testFoldsGoBesideTheStrokesToTheCockpit`) and the fake Cockpit's check (`test-fake-cockpit-ops.py`: folds taken, a fold without lines refused); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Cockpit
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** talking with Larry about a folded board
- **I want to** have Larry told which strokes are folded under which header
- **so that** he doesn't think I erased them, or wrote them again when I unfold

#### Acceptance Criteria:
- **Scenario:** A folded section
- **Given:** a header folded over three lines
- **When:** Larry's turn comes
- **Then:** the strokes he gets leave the folded ones out and list them under the header's strokes, with the number of lines folded

---

### User Story 860:

- **Summary:** Fold all, Unfold all, and collapse to a level
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b) (levels, collapse) and [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the menu on a header's mark); verified by host tests (`BoardOutlineTests.testLevelsAndCollapsingToOne`, `testUnfoldAllOpensFoldsInsideFolds`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** reading a long outline
- **I want to** fold everything, open everything, or show the outline to a depth
- **so that** I see the shape of the board at a glance

#### Acceptance Criteria:
- **Scenario:** Collapse to level 1
- **Given:** an outline two levels deep
- **When:** I hold a header's mark and choose 1
- **Then:** only the top headers show, each folded

---

### User Story 876:

- **Summary:** Collapse to level 2 shows the sub-headers folded
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b) (levels, collapse) and [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the menu on a header's mark); verified by host tests (`BoardOutlineTests.testLevelsAndCollapsingToOne`, `testUnfoldAllOpensFoldsInsideFolds`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** reading a long outline
- **I want to** show it to two levels
- **so that** I see its shape a level deeper

#### Acceptance Criteria:
- **Scenario:** Collapse to level 2
- **Given:** the same outline
- **When:** I choose 2
- **Then:** the top headers stay open, their sub-headers show folded, and a top header with no sub-headers folds

---

### User Story 861:

- **Summary:** A line that looks like a header is offered as one
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests.testABigOrUnderlinedLineIsOffered`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing titles bigger or underlining them
- **I want to** see such a line offered as a header
- **so that** making headers is one tap where I already marked them

#### Acceptance Criteria:
- **Scenario:** A big line
- **Given:** a board with four ordinary lines and one written much bigger
- **When:** it is drawn
- **Then:** a faint H shows in the margin beside the big line; nothing folds until I tap the margin there, which makes it a header

---

### User Story 877:

- **Summary:** An underlined line is offered as a header
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b), [11f70d23](https://github.com/idvorkin/context-grabber/commit/11f70d23) (a stroke running far past the line is a rule, not offered); verified by host tests (`BoardOutlineTests.testABigOrUnderlinedLineIsOffered`, `BoardInkHeadersTests.testARuleTouchingTheLastLineLeavesThatLineInTheSection`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** underlining my titles
- **I want to** see an underlined line offered as a header
- **so that** making headers is one tap where I already marked them

#### Acceptance Criteria:
- **Scenario:** An underlined line
- **Given:** a line with a straight stroke under most of it that doesn't run far past it (no more than half as wide again as the line, plus a line's height)
- **When:** it is drawn
- **Then:** the faint H shows beside it (for an underline drawn before story 1030's build; one drawn since makes the line a header at once)

---

### User Story 898:

- **Summary:** Folded ink is never scratched out, kept around or tidied
- **Status:** implemented in the review round after [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4); verified by the lint rung and the Mac build (`just native-build-mac`) only. Folding and the Pencil's zigzag are the iPad's to show
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*; [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** who folds sections of a board away under their headers
- **I want to** have what is folded left alone by a scratch-out, a Keep all or a tidy
- **so that** unfolding brings back exactly what I folded, where I left it

#### Acceptance Criteria:
- **Scenario:** A zigzag over a word just under a folded header
- **Given:** a folded section whose hidden ink sits under the lines below its header, and a word on one of those lines
- **When:** I scratch the word out
- **Then:** only the word goes; unfolding the header shows all of its ink where it was (a zigzag that reaches the fold's marker or its header line takes the whole section instead, story 905)

---

### User Story 900:

- **Summary:** Larry's picture shows a folded section whole, flagged folded
- **Status:** implemented in [568bd4a](https://github.com/idvorkin/context-grabber/commit/568bd4a) (header and "▸ N lines folded"); changed to the whole section in [a043ea5c](https://github.com/idvorkin/context-grabber/commit/a043ea5c) (#1013); verified by host tests (`BoardFoldMarkerTests`, `BoardFoldPictureTests`); `just test` and the Mac build (`just native-build-mac`); the iPad simulator (rung 2, `WhiteboardOutlineUITests.testLarrysPictureShowsAFoldedSectionWholeAndShaded`); the picture not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** [#1013](https://github.com/idvorkin/context-grabber/issues/1013) (Igor, 2026-11-20, W4 on PR #912: "the picture shows the whole section, flagged as folded")

#### Use Case:
- **As someone** folding sections of a board I talk over with Larry
- **I want to** have the picture Larry gets show a folded section in full, marked as folded
- **so that** he never loses what I set aside, and still knows I set it aside

#### Acceptance Criteria:
- **Scenario:** A folded section in Larry's picture
- **Given:** a header folded over two lines, with more writing below the section
- **When:** Larry's turn takes a picture of the board (or I Send it, or Claude takes its turn)
- **Then:** the picture shows the two folded lines under the header, shaded light grey across the page, with a grey "folded" in the margin at their top and a grey ▸ beside the header; the writing below comes after them, and a fold folded inside the section is drawn whole inside the shading
- **And:** the picture has no "▸ 2 lines folded", and the board on the iPad stays folded

---

### User Story 901:

- **Summary:** A folded header says on the board how many lines it holds
- **Status:** implemented in [568bd4a](https://github.com/idvorkin/context-grabber/commit/568bd4a); verified by host tests (`BoardFoldMarkerTests`); `just test` and the Mac build (`just native-build-mac`); the simulator (`WhiteboardOutlineUITests`, 197 s), `testAMarginTapMakesAHeaderAndAnotherFoldsIt` (its own test until bead context-grabber-3k6 folded it into the margin tap's); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** folding sections on the board
- **I want to** see "▸ N lines folded" beside a folded header
- **so that** I know what the fold holds and have something to erase to take it

#### Acceptance Criteria:
- **Scenario:** Folding a header
- **Given:** a header with two indented lines under it
- **When:** I tap the margin beside it to fold it
- **Then:** "▸ 2 lines folded" shows in small grey letters just right of the header's row, moves with it, and goes when I unfold

---

### User Story 902:

- **Summary:** The eraser across a fold's marker erases the whole section
- **Status:** implemented in [040dbd8](https://github.com/idvorkin/context-grabber/commit/040dbd8), its file's import in [bbb34db](https://github.com/idvorkin/context-grabber/commit/bbb34db); verified by host tests (`BoardFoldEraseTests.testTheEraserAcrossTheMarkerErasesTheWholeFoldAndClosesUp`, `testErasingAFoldTakesTheFoldsFoldedInsideIt`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad. A called-off eraser stroke erased the fold anyway (context-grabber-0m2d): stories 906 and 907, fixed in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** done with a folded section
- **I want to** rub the eraser across its "▸ N lines folded" and have the header and everything folded under it go
- **so that** a section I folded away is erased in one stroke, without unfolding it first

#### Acceptance Criteria:
- **Scenario:** Erasing a fold by its marker
- **Given:** a folded header with a line of ink below the fold
- **When:** I draw the eraser across "▸ N lines folded"
- **Then:** the header, its folded lines and any folds folded inside it are erased, and the ink below closes up to where the header was, in whole lines

---

### User Story 1170:

- **Summary:** Erasing a folded header's underline or # leaves the fold
- **Status:** implemented in [5934a3d1](https://github.com/idvorkin/context-grabber/commit/5934a3d1); verified by host tests (`BoardInkHeadersTests.testTheEraserAcrossAFoldedHeadersUnderlineLeavesTheFold`, `testTheEraserAcrossAFoldedHeadersHashLeavesTheFold`), `just native-test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad (its `erase_fold_check` line will say)
- **Issues:** context-grabber-bov
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*; [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Undoing a wrong guess*

#### Use Case:
- **As someone** tidying a folded header's underline or #
- **I want to** erase just that mark and keep the section folded under the header's words
- **so that** a fold is erased only by its words or its marker, never by the mark that made the header

#### Acceptance Criteria:
- **Scenario:** Erasing a folded header's underline or #
- **Given:** a header I made by underlining a line or writing a # before it, folded, with a line of ink below the fold
- **When:** I draw the eraser along its underline, or across one bar of its #, without touching its words
- **Then:** only that stroke goes: the header's words, "▸ N lines folded" and the folded lines stay, the ink below stays where it was, and the line stays a header until I unfold it (its words or its marker still take the section, as in stories 902 and 903)

---

### User Story 955:

- **Summary:** The pixel eraser takes a folded section by its words only once it has rubbed them through
- **Status:** implemented in [5934a3d1](https://github.com/idvorkin/context-grabber/commit/5934a3d1); verified by the host test `BoardInkHeadersTests.testThePixelEraserTakesAFoldOnlyWhenItRubsThroughTheWords`, `just native-test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad (its `erase_fold_check` line, via `eraser_rub`, will say)
- **Issues:** context-grabber-bov
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** rubbing out a stray mark with the pixel eraser near a folded header
- **I want to** have the section go only when I have rubbed out the header's words
- **so that** a rub on the corner of a letter never takes a whole folded section with it

#### Acceptance Criteria:
- **Scenario:** A rub on a corner of a letter
- **Given:** a folded header and the pixel eraser
- **When:** I rub out the corner of one letter of the header
- **Then:** that corner goes and the section stays folded under what is left of the header, until I rub through every stroke of its words or across its "▸ N lines folded", which erases the header and everything folded under it

---

### User Story 904:

- **Summary:** One Undo brings a fold erased by its marker back, still folded
- **Status:** implemented in [040dbd8](https://github.com/idvorkin/context-grabber/commit/040dbd8); verified by host tests (`BoardFoldEraseTests.testAnUndoBringsTheFoldBackStillFolded`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** who erased a folded section by mistake
- **I want to** have one Undo bring it all back as it was
- **so that** erasing a whole section in one stroke is never a loss

#### Acceptance Criteria:
- **Scenario:** Undo brings it back folded
- **Given:** a fold I just erased by its marker
- **When:** I tap Undo once
- **Then:** the header comes back still folded, with "▸ N lines folded" beside it, and the ink below is back where it was

---

### User Story 903:

- **Summary:** The eraser across a folded header erases the whole section
- **Status:** implemented in [040dbd8](https://github.com/idvorkin/context-grabber/commit/040dbd8), its file's import in [bbb34db](https://github.com/idvorkin/context-grabber/commit/bbb34db); verified by host tests (`BoardFoldEraseTests.testTheHeadersInkTakesTheFoldOnlyWhenAsked`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad. A called-off eraser stroke erased the fold anyway (context-grabber-0m2d): stories 906 and 907, fixed in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f). Its header's ink narrowed to its words, and taken only where the eraser took some of them, in [5934a3d1](https://github.com/idvorkin/context-grabber/commit/5934a3d1) (stories 1170, 955)
- **Issues:** context-grabber-0m2d, context-grabber-bov
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** erasing a folded header
- **I want to** have its folded lines go with it
- **so that** no folded ink is left hidden on the board with no header to unfold it

#### Acceptance Criteria:
- **Scenario:** Erasing a folded header's ink
- **Given:** a folded header
- **When:** I draw the eraser across the header's own ink
- **Then:** the header and everything folded under it are erased and the ink below closes up; Undo twice brings the header back still folded (the eraser's own step, then the fold's). The header's own ink is its words: the eraser across its underline or # alone leaves the fold (story 1170), and the pixel eraser takes it only once it has rubbed through the words (story 955)

---

### User Story 905:

- **Summary:** A scratch-out over a fold's marker or its header line erases the whole section
- **Status:** implemented in [1cee727](https://github.com/idvorkin/context-grabber/commit/1cee727), its file's import in [bbb34db](https://github.com/idvorkin/context-grabber/commit/bbb34db); verified by host tests (`BoardFoldEraseTests.testAScratchOutOverTheMarkerTakesTheFold`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad. Staying gone on the sheet and to Larry (#1015: PaperKit refused the board's markup and kept the section) fixed in [cb1ab206](https://github.com/idvorkin/context-grabber/commit/cb1ab206); verified on the iPad simulator (`WhiteboardScratchOutUITests.testAScratchedOutFoldStaysGoneWhenHeWritesOn`, failing before the fix: wanted 1 stroke, PaperKit held 3)
- **Issues:** [#1015](https://github.com/idvorkin/context-grabber/issues/1015)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*; [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** who scratches out what I'm done with
- **I want to** scratch out a folded section by its marker or its header line and have it all go
- **so that** scratch-out takes a fold the way the eraser does, with no folded ink left hidden

#### Acceptance Criteria:
- **Scenario:** Scratching out a fold
- **Given:** a folded header with a line of ink below the fold
- **When:** I scratch out its "▸ N lines folded" or its header line with a fast zigzag
- **Then:** the header, everything folded under it and the zigzag go, on the sheet and in what Larry gets, and stay gone when I write on; the ink below closes up to where the header was, and one Undo brings the section back still folded with the ink below where it was

---

### User Story 906:

- **Summary:** An eraser stroke the iPad calls off takes no fold by its marker
- **Status:** implemented in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f); verified by the host test `BoardFoldEraseTests.testACalledOffEraserTakesAFoldOnlyWhereTheHeadersInkWent`, `just native-test` and `just native-build-mac`; the called-off touch not yet seen on the iPad (its `erase_fold_cancelled` line will say)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** whose palm lands while I'm erasing near a folded section
- **I want to** have an eraser stroke the iPad calls off leave the fold alone
- **so that** a whole section is erased only by a stroke I finished

#### Acceptance Criteria:
- **Scenario:** A called-off eraser stroke across the marker
- **Given:** a folded header with a line of ink below the fold
- **When:** I draw the eraser across "▸ N lines folded" and the iPad calls the touch off before it lifts (a palm landing, a system gesture taking it)
- **Then:** the header stays folded with its "▸ N lines folded", and the ink below stays where it was

---

### User Story 907:

- **Summary:** A called-off eraser stroke that took a folded header's ink takes its section too
- **Status:** implemented in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f); verified by the host test `BoardFoldEraseTests.testACalledOffEraserTakesAFoldOnlyWhereTheHeadersInkWent`, `just native-test` and `just native-build-mac`; whether the iPad keeps the eraser's own erase when it calls the touch off is not yet seen (the `erase_fold_cancelled` line will say)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** whose eraser stroke across a folded header was called off
- **I want to** have the section go only if the header's ink went
- **so that** no folded lines are left hidden under no header, and none are lost under a header that stayed

#### Acceptance Criteria:
- **Scenario:** A called-off eraser stroke across the header's ink
- **Given:** a folded header
- **When:** I draw the eraser across the header's own ink, the iPad calls the touch off before it lifts, and the eraser took all of the header's ink anyway
- **Then:** the header and everything folded under it are erased and the ink below closes up, as for a finished stroke; had any of the header's ink stayed, the section would stay folded as it was

---

### User Story 1030:

- **Summary:** An underline drawn under a line of my writing makes it a header
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); `WhiteboardOutlineUITests.testAnUnderlineDrawnUnderALineMakesItAHeader` written for the iPad simulator but not yet run (the Mac's screen was locked); not yet seen with the Pencil on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *An underline makes the line above it a header*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who underlines my headings as I would in a notebook
- **I want to** draw a line under a line of my writing and have it become a header
- **so that** I never reach for the margin to make one

#### Acceptance Criteria:
- **Scenario:** Underlining a line
- **Given:** a line of my writing with indented lines under it
- **When:** I draw a straight line under it across most of its width and lift the Pencil
- **Then:** a ▾ shows beside the line, and a tap on the ▾ folds the indented lines, the underline staying with the header

---

### User Story 1031:

- **Summary:** A # written at the start of a line makes it a header
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); a # can't be drawn by a UI test (straight drags only), so host only; not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *A # at the start of a line makes it a header*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967), [#1004](https://github.com/idvorkin/context-grabber/issues/1004) (it was recognised; its ▾ hid under the # written in the margin: story 1041)

#### Use Case:
- **As someone** who thinks in Markdown
- **I want to** write a # at the start of a line and have the line become a header
- **so that** a heading on the board reads as one in my notes

#### Acceptance Criteria:
- **Scenario:** Writing a #
- **Given:** a blank line
- **When:** I write a # (two level strokes crossing two upright ones) with no ink left of it
- **Then:** a ▾ shows beside it as soon as the # is finished, before I write the words

---

### User Story 1032:

- **Summary:** What I write on a header's line joins the header
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Writing more on a header's line*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who writing a header's words after its #
- **I want** the words I write on a header's line to be part of the header
- **so that** the fold's marker never lands on my words and the line stays one header

#### Acceptance Criteria:
- **Scenario:** Words after a #
- **Given:** a line made a header by a #
- **When:** I write words after the # on the same line, then fold it
- **Then:** the words fold and move with the header, "▸ N lines folded" sits past the last word, and there is one ▾

---

### User Story 1033:

- **Summary:** One Undo takes an underline or a #'s last bar and the header it made; Redo brings both back
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab), [11f70d23](https://github.com/idvorkin/context-grabber/commit/11f70d23); verified by host tests (`BoardInkHeadersTests`, the # by `testOneUndoOfAHashsLastBarTakesTheHeader`), `just test` and the Mac build (rung 1.5, 2026-11-19); a # can't be drawn by a UI test, so host only; the Undo itself not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Undoing a wrong guess*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** whose underline or # was only emphasis
- **I want** one Undo to take back a header the board guessed from my mark
- **so that** a wrong guess costs one tap

#### Acceptance Criteria:
- **Scenario:** Undoing the mark
- **Given:** a line made a header by the underline or the # I just drew
- **When:** I tap Undo, then Redo
- **Then:** Undo takes the underline or the #'s last bar and the ▾ goes; Redo brings both back

---

### User Story 1034:

- **Summary:** Not a header keeps my underline as ink and the board never makes it a header again
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab), [4240ec99](https://github.com/idvorkin/context-grabber/commit/4240ec99) (no faint H after *Not a header*, remembered across a reopen); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19 and 2026-11-22); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Undoing a wrong guess*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967); bead `context-grabber-2ul` (the faint H came straight back)

#### Use Case:
- **As someone** who underlined for emphasis and wants to keep the line
- **I want** to keep my underline but not the header
- **so that** the board stops treating that line as a header for good

#### Acceptance Criteria:
- **Scenario:** Not a header
- **Given:** a line made a header by an underline
- **When:** I choose *Not a header* from the hold menu and go on drawing elsewhere
- **Then:** the underline stays as ink, there is no ▾, and the line never becomes a header again on its own: no faint H comes back beside it, words I add to it later included, and the board still remembers after I close and reopen it

---

### User Story 1167:

- **Summary:** A line I said was not a header can still be made one by hand
- **Status:** implemented in [4240ec99](https://github.com/idvorkin/context-grabber/commit/4240ec99); verified by host tests (`BoardInkHeadersTests.testNotAHeaderIsNeverOfferedAgainEvenAfterReopening`: a margin tap after *Not a header* makes the line a header), `just test` and the Mac build (rung 1.5, 2026-11-22); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Undoing a wrong guess*
- **Issues:** bead `context-grabber-2ul`

#### Use Case:
- **As someone** who said a line was not a header and then changed my mind
- **I want** a margin tap, *Make header* or a new underline or # to still make it a header
- **so that** saying no once never locks the line out of the outline

#### Acceptance Criteria:
- **Scenario:** Making it a header after all
- **Given:** a line I said was not a header
- **When:** I tap the margin beside it
- **Then:** it becomes a header, as any line does, and the board no longer remembers it as not a header

---

### User Story 1035:

- **Summary:** A rule drawn across the page ends the sections above it
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab), [11f70d23](https://github.com/idvorkin/context-grabber/commit/11f70d23); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); a rule can't be told from the simulator's straight "writing" by a UI test, so host only; not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *A rule across the page ends the sections above it*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who whose next lines belong to no header
- **I want** to end a header's section where I draw a line across the page
- **so that** folding a header never takes what comes after the rule

#### Acceptance Criteria:
- **Scenario:** Ending a section
- **Given:** a header with indented lines, then a long line drawn across the page, then more indented lines
- **When:** I fold the header
- **Then:** only the lines above the rule fold (the last one too, even when the rule touches it), and the rule and what is below it slide up under the header

---

### User Story 1036:

- **Summary:** Larry's picture shows which lines are headers
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19) (the ▾ marks a picture would draw, `openHeaderMarks`); the drawn picture not yet seen on the simulator or the iPad. #1001: labelled "▾ header" past the line and kept in the picture's frame in [475f9070](https://github.com/idvorkin/context-grabber/commit/475f9070); verified by host tests (`BoardInkHeadersTests`: the label is clear of the ink and inside the picture), the Mac build (rung 1.5) and the iPad simulator's whiteboard UI classes (rung 2, 2026-11-20); Larry reading the label needs the iPad. An open sub-header inside a folded section, labelled in the opened picture, kept in its frame in [d2e5300b](https://github.com/idvorkin/context-grabber/commit/d2e5300b); verified by host tests (`BoardFoldPictureTests.testTheFrameTakesInAnOpenSubheadersLabelInsideAFold`, failing before the fix: the label cut off), `just test` and the Mac build (rung 1.5, 2026-11-21)
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Larry sees the headers*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967), [#1001](https://github.com/idvorkin/context-grabber/issues/1001), context-grabber-e91y

#### Use Case:
- **As someone** who talking the board over with Larry
- **I want** Larry to see which lines the board takes for headers
- **so that** he reads my board's outline as I see it

#### Acceptance Criteria:
- **Scenario:** A header in Larry's picture
- **Given:** an open header on the board
- **When:** Larry gets a picture of the board (his turn, Send or Claude's turn)
- **Then:** the header is labelled "▾ header" in grey just past the end of its line, clear of its ink and inside the picture however far in the line starts

---

### User Story 1280:

- **Summary:** Ink I grouped myself is still my writing; only Larry's groups are not
- **Status:** implemented in [6e977be8](https://github.com/idvorkin/context-grabber/commit/6e977be8); verified by host tests (`BoardOutlineIgorGroupsTests`, `WebMineGroupsTests`; `just test`, rung 1, 2026-11-24); the iPad is unchanged (every group there is Larry's); the web board passing `mine` (BoardWasm interface 18) is the Cockpit's; `just wasm-test`'s new check is owed on a Mac with the wasm SDK
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *An underline makes the line above it a header*; [Board rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), *The interface, version 18*
- **Issues:** bead context-grabber-xzmc (found porting the web board's ink headers, #1330); Igor's pick on the whiteboard-now board, 2026-11-24 ~05:00: "only Larry's groups count as 'not your writing'; Igor's own grouped strokes stay his writing"

#### Use Case:
- **As someone** who groups a few of my own words on the web board so they move together
- **I want** that group to still count as my writing
- **so that** I can still underline it, start it with a #, or tap the margin to make it a header, on the web as on the iPad

#### Acceptance Criteria:
- **Scenario:** A group I made is a line of my writing
- **Given:** a line of my words that I grouped on the web board, with writing under it
- **When:** I make it a header (an underline, a # at its start, or a margin tap)
- **Then:** it becomes a header, as an ungrouped line would, and it still moves whole as one group

---

### User Story 1040:

- **Summary:** A line tints for a moment when it becomes a header
- **Status:** implemented in [8e0a8e6e](https://github.com/idvorkin/context-grabber/commit/8e0a8e6e), [cb503b46](https://github.com/idvorkin/context-grabber/commit/cb503b46), [ddea0bc3](https://github.com/idvorkin/context-grabber/commit/ddea0bc3); verified by `WhiteboardOutlineUITests.testHeaderMarksShareOneSpotStandOnTheLineAndTintWhenMade` on the iPad simulator (rung 2, 2026-11-20: the tint appears on a margin tap's header and fades, the `header_tint` event in the session log) and `just test`; not yet seen with the Pencil on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Seeing the headers*
- **Issues:** [#1004](https://github.com/idvorkin/context-grabber/issues/1004)

#### Use Case:
- **As someone** who makes headers with the Pencil as I write
- **I want** the board to show me the moment it takes a line for a header
- **so that** I never wonder whether my # or underline was recognised

#### Acceptance Criteria:
- **Scenario:** A header made
- **Given:** a line of my writing
- **When:** it becomes a header (an underline, a #, a margin tap or *Make header*)
- **Then:** its row is tinted for about a second, then the tint fades; writing more on the line doesn't tint it again

---

### User Story 1041:

- **Summary:** Every header's ▾ sits in one spot in the margin, on the line's baseline, over the ink, easy to tap
- **Status:** implemented in [8e0a8e6e](https://github.com/idvorkin/context-grabber/commit/8e0a8e6e), [cb503b46](https://github.com/idvorkin/context-grabber/commit/cb503b46), [ddea0bc3](https://github.com/idvorkin/context-grabber/commit/ddea0bc3); verified by host tests (`BoardHeaderMarksTests`, the # row from the iPad's 2026-11-20 log), `just test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests.testHeaderMarksShareOneSpotStandOnTheLineAndTintWhenMade` on the iPad simulator (rung 2, 2026-11-20: two headers' marks at one x, each foot on its line's ink read from the screen's pixels, a tap on the mark folds); a # in the margin can't be drawn by a UI test, so over-the-ink is host and screenshot only; not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Seeing the headers*
- **Issues:** [#1004](https://github.com/idvorkin/context-grabber/issues/1004) (a # written in the margin hid its own ▾, so "#Affirmations" looked unrecognised)

#### Use Case:
- **As someone** who folds my board's sections with a finger
- **I want** each header's ▾ in the same place, standing on its line, never under my ink and big enough to hit
- **so that** I can see at a glance which lines are headers and fold one without aiming

#### Acceptance Criteria:
- **Scenario:** Headers at different indents, one started with a # in the margin
- **Given:** two headers, one indented and one whose # I wrote in the margin's left corner
- **When:** I look at the margin and tap a ▾, or up to 22 points above or below its middle
- **Then:** both ▾ sit at the same place across, each on its line's baseline and over the ink, and the tap folds that header

---

### User Story 1065:

- **Summary:** A line started with ## or ### is a header of that level, and its margin mark says so
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests`: ##, ###, a fourth # as ink, a # by an underline or after the words as ink), `just test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests.testHashHashMakesASubheaderThatFoldsWithTheHashAbove` on the iPad simulator (rung 2, 2026-11-20: # and ## drawn with drags, marks ▾ and ▾ ##); a # under a tall # header kept as its own line's in [f346d8cc](https://github.com/idvorkin/context-grabber/commit/f346d8cc) and a tight ## whose bars overlap accepted in [f7293684](https://github.com/idvorkin/context-grabber/commit/f7293684), host tests; not yet written with the Pencil on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who outlines my board in Markdown's way as I write
- **I want** ## and ### written at a line's start to make a level-2 and a level-3 header
- **so that** my notes get sub-headings without reaching for the margin

#### Acceptance Criteria:
- **Scenario:** Writing ## then ###
- **Given:** a line I start with a #, which makes it a header (▾)
- **When:** I write a second # right beside the first, then a third
- **Then:** the margin's mark reads ▾ ## after the second and ▾ ### after the third, in the same spot; a fourth # is plain ink on the line

---

### User Story 1066:

- **Summary:** A ## section ends at the next ## or #, and folding the # above folds it too
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests`: a ## ending at the next ## or #, an indented body then an unindented ##, a shallower # ending a ## wherever its indent, the # folding its ##s and their folds kept, the outline's levels), `just test`, and `WhiteboardOutlineUITests.testHashHashMakesASubheaderThatFoldsWithTheHashAbove` on the iPad simulator (rung 2, 2026-11-20: folding the # hides the ## and its line); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who folds my board's sections
- **I want** a ## section to sit inside the # section above it, as in Markdown
- **so that** folding a top-level header tucks away everything under it, sub-headings included

#### Acceptance Criteria:
- **Scenario:** A # with two ## under it
- **Given:** a # header, then a ## header with lines under it, then another ## with lines, all at one indent
- **When:** I fold the first ##, then the #
- **Then:** the first ##'s fold hides only its own lines (the second ## ends it); folding the # hides both ## and all their lines, and unfolding it brings them back as they were

---

### User Story 1067:

- **Summary:** One Undo of the last # takes a header back a level
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests.testOneUndoOfTheLastHashTakesOneLevel`) and `just test`; redrawing an undone # takes the level back in [f346d8cc](https://github.com/idvorkin/context-grabber/commit/f346d8cc) (`testRedrawingAnUndoneHashsLastBarTakesTheHeaderDeeperAgain`); the bar's Undo of a real # is for the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who sometimes writes one # too many
- **I want** Undo of the # that deepened a header to take back only that level
- **so that** a slip costs one Undo and never the header itself

#### Acceptance Criteria:
- **Scenario:** A ### undone
- **Given:** a line I made a ### header
- **When:** I Undo once, then Redo
- **Then:** the mark reads ▾ ## after the Undo and ▾ ### again after the Redo; the line stays a header throughout

---

### User Story 1068:

- **Summary:** Larry's picture labels a deeper header with its level
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests.testLarrysPictureLabelsADeeperHeaderWithItsLevel`) and `just test`; the picture Larry gets is not yet seen from the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who talks my board over with Larry
- **I want** Larry to see which headers are sub-headings
- **so that** he reads my outline's shape, not only which lines are headers

#### Acceptance Criteria:
- **Scenario:** A picture with a # and a ## header
- **Given:** an open # header and an open ## header under it
- **When:** a turn sends Larry a picture of the board
- **Then:** the # is labelled "▾ header" and the ## "▾ ## header" past their lines, clear of the ink

---

### User Story 1069:

- **Summary:** Redrawing an erased bar of a ### header's middle # brings back ###
- **Status:** implemented in [e801768f](https://github.com/idvorkin/context-grabber/commit/e801768f); verified by host tests (`BoardInkHeadersTests.testRedrawingAnErasedBarOfTheMiddleHashBringsBackEveryHash`, failing before the fix: ▾ ##) and `just test`; the eraser and the Pencil's bar are for the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** context-grabber-2zud (from [#1034](https://github.com/idvorkin/context-grabber/issues/1034)'s review)

#### Use Case:
- **As someone** who fixes a wobbly # with the eraser
- **I want** a bar I erase and redraw to give back the level the #s on the board say
- **so that** a ### stays a ### after a touch-up, never quietly a ##

#### Acceptance Criteria:
- **Scenario:** The middle # of a ### touched up
- **Given:** a line I made a ### header
- **When:** I erase one bar of the second # with the eraser, then draw that bar again
- **Then:** the mark reads ▾ after the erase and ▾ ### again after the redraw; the line stays a header throughout

---

### User Story 1292:

- **Summary:** A margin-tap header is the one line tapped beside, even when a descender touches the next
- **Status:** in progress (the fix proposed by Larry on the web side, cockpit-gvv)
- **Spec:** [Board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Acceptance criteria*
- **Issues:** Igor on the board, 2026-11-24 19:04, "why did it copy 2 lines to collapse"; 3 of his 5 margin taps that evening made two-line headers, and 9 of the 24 stored headers spanned more than one line (Larry, cockpit-gvv)

#### Use Case:
- **As someone** who makes headers with a margin tap
- **I want** the header to be the line I tapped beside, and the line under it to stay in its section
- **so that** a g or y's tail never turns two lines into one header or leaves the first line out of its fold

#### Acceptance Criteria:
- **Scenario:** A header whose descender touches the indented line below
- **Given:** a line at the margin whose g's tail reaches a few points into an indented line under it, and a line back at the margin after that
- **When:** I tap the margin beside the first line, then tap again to fold it
- **Then:** only the first line is the header, and the fold hides the indented line and leaves the line at the margin showing
