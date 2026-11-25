# The whiteboard: Larry changes the board

Larry editing the board itself: drawing, erasing, moving and folding ink by name, controls he lays on it, what he hears, stale and refused changes. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 961:

- **Summary:** Larry's change applies though I wrote on since he looked
- **Issues:** Larry, 2026-11-17: his make-room ops came back stale (rev 257 on 11/16, rev 111 today) because Igor wrote a stroke or two before they arrived
- **Status:** implemented in [905337c](https://github.com/idvorkin/context-grabber/commit/905337c); verified on the host (`BoardOpsTests`: new strokes since don't stop a push and it says `rebased_from`, only changes after the look count, a rebased push moves the strokes below now) and the Mac build; on the iPad simulator, merged with main at 2510b8c6 (`WhiteboardPaperGhostsUITests` rung 2: `testAPushFromAnOlderLookStillApplies` passes)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** writing on while Larry thinks
- **I want to** have his make-room still happen when my new strokes don't get in its way
- **so that** I don't have to stop writing for his changes to land

#### Acceptance Criteria:
- **Scenario:** I wrote a stroke after he looked
- **Given:** Larry looked at the board, and I drew two new strokes since
- **When:** his make room arrives
- **Then:** everything below its line now moves down, my new strokes included, one Undo, and his next turn says it applied on a newer board than the one he saw

---

### User Story 964:

- **Summary:** Larry's change from an older look is refused when it names what I moved or erased
- **Issues:** Larry, 2026-11-17: his make-room ops came back stale (rev 257 on 11/16, rev 111 today) because Igor wrote a stroke or two before they arrived
- **Status:** implemented in [905337c](https://github.com/idvorkin/context-grabber/commit/905337c); verified on the host (`BoardOpsTests`: a named stroke Igor moved is stale with `conflict_ids`, a named group or kept text whose stroke Igor moved is stale too, every name an op uses is checked) and the Mac build; on the iPad simulator, merged with main at 2510b8c6 (`WhiteboardPaperGhostsUITests` rung 2: `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` (which since bead context-grabber-3rk holds the stale-push test, testAStalePushMovesNothingAndLarryIsTold) passes); since [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891) a fold, an unfold or connectors following their ends count as moving everything, so any look from before one is stale (story 1229; compiled in the Mac build, not host-tested)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** writing on while Larry thinks
- **I want to** have his make-room still happen when my new strokes don't get in its way
- **so that** I don't have to stop writing for his changes to land

#### Acceptance Criteria:
- **Scenario:** I moved what he names
- **Given:** Larry looked, and I since moved one of the strokes his change names, or a stroke of a group or kept text it names
- **When:** it arrives
- **Then:** nothing moves, and his next turn says it was stale and which of his names I had moved or erased

---

### User Story 1220:

- **Summary:** Larry's change from before the app restarted still applies when I only wrote new strokes since
- **Issues:** bead context-grabber-fuw0 (found checking drop rule C, 2026-11-22: the board's memory of its changes lived only for one run, so after a relaunch a batch based on an earlier revision was refused as stale even when Igor had only added strokes)
- **Status:** implemented in [06655b6a](https://github.com/idvorkin/context-grabber/commit/06655b6a) and [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891), the drawing's fingerprint in [15779696](https://github.com/idvorkin/context-grabber/commit/15779696); verified on the host (`BoardMeaningTests`: a push from before a relaunch applies over new strokes and says `rebased_from`, and one naming only strokes that never moved applies too) and the Mac build (`just native-build-mac`). The review round also re-checks a batch held for the Pencil on the lift (host: `BoardMeaningTests` refuses one whose stroke was erased while it waited; `BoardOpsTests` and `BoardCanvasOutcomeTests` still let one through when nothing it names moved); that the app shows a refusal on the lift is compiled (Mac build) but not host-tested. Not run on a simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** who closes and reopens the app while Larry thinks
- **I want to** have his make-room still land when all I did since he looked was write new strokes
- **so that** a relaunch doesn't silently cost me his change

#### Acceptance Criteria:
- **Scenario:** The app restarted after he looked
- **Given:** Larry looked at the board, I wrote two new strokes, and the app was closed and opened again
- **When:** his make room, from the look before the restart, arrives
- **Then:** it applies to the board as it is now, my new strokes included, and his next turn says it applied on a newer board than the one he saw

---

### User Story 1229:

- **Summary:** Larry's change from before the app restarted is still refused when I moved what it names
- **Issues:** bead context-grabber-fuw0 (split from story 1220 in its review)
- **Status:** implemented in [06655b6a](https://github.com/idvorkin/context-grabber/commit/06655b6a) and [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891); verified on the host (`BoardMeaningTests`: one naming a stroke moved before the relaunch is still stale with `conflict_ids`, Larry's own change before a relaunch still makes an older look stale, a file from before this remembers nothing older than its saved revision). That a fold or connectors following count as moving everything is compiled (Mac build) but not host-tested. Not run on a simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** who moves my strokes around while Larry thinks
- **I want to** have his change refused when it names a stroke I moved, even across a restart
- **so that** his change never lands on ink that is no longer where he saw it

#### Acceptance Criteria:
- **Scenario:** I moved what it names before the restart
- **Given:** Larry looked at the board, I moved a stroke his change names, or folded a section, and the app was closed and opened again
- **When:** his change, from the look before the restart, arrives
- **Then:** it is refused as stale and nothing moves

---

### User Story 1230:

- **Summary:** A save the app didn't finish leaves the board remembering none of my earlier changes
- **Issues:** bead context-grabber-fuw0 (split from story 1220 in its review: a cut-off save after a move that kept the drawing's size went unnoticed)
- **Status:** implemented in [15779696](https://github.com/idvorkin/context-grabber/commit/15779696) (the drawing's fingerprint saved with the board's memory); verified on the host (`BoardMeaningTests`: a save cut off after a move that kept the drawing's size forgets the memory and refuses an older look naming the moved stroke, a clean relaunch keeps it, a file without the fingerprint forgets it) and the Mac build (`just native-build-mac`). Not run on a simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** whose app can stop at any moment
- **I want to** have the board forget what it remembered of my changes when its last save was cut off
- **so that** a change of Larry's never lands on a stroke I moved that the board lost track of

#### Acceptance Criteria:
- **Scenario:** The app stopped while saving
- **Given:** I moved a stroke, the board's drawing was saved, and the app stopped before what it remembers of my changes was
- **When:** a change of Larry's from an earlier look arrives after the app opens again
- **Then:** it is refused as stale, even though the move left the drawing's size the same

---

### User Story 965:

- **Summary:** Larry's change from too far back is refused as stale
- **Issues:** Larry, 2026-11-17: his make-room ops came back stale (rev 257 on 11/16, rev 111 today) because Igor wrote a stroke or two before they arrived
- **Status:** implemented in [905337c](https://github.com/idvorkin/context-grabber/commit/905337c); verified on the host (`BoardOpsTests`: too old or after Larry's own change is stale, the memory's limit) and the Mac build
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** writing on while Larry thinks
- **I want to** have his make-room still happen when my new strokes don't get in its way
- **so that** I don't have to stop writing for his changes to land

#### Acceptance Criteria:
- **Scenario:** He is too far behind
- **Given:** Larry's change was made on a board older than the board remembers (a board last saved by a build from before story 1220 remembers nothing older than the revision it was saved at)
- **When:** it arrives
- **Then:** it is refused as stale, as before

---

### User Story 814:

- **Summary:** Larry makes room between my lines
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1), [06c48a49](https://github.com/idvorkin/context-grabber/commit/06c48a49) (the snap, story 1195); verified by host tests (`BoardOpsTests`: `testAPushMovesOnlyWhatStartsAtOrBelowTheLine`, `testAPushThatNeedsAPageAddsOne`, `testAPushBelowTheLastInkMovesNothingAndAddsPaper`, `testATranslateBelowALine`; `just test`) and the Mac build (`just native-build-mac`). The one undo named for the change, page count included, is PaperKit's, in the board's view, with no host test; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysPushMovesTheInkBelowAndOneUndoPutsItBack`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** who asked Larry on the board to open space between two parts of my notes
- **I want to** see everything below the line slide down by the amount he chose, in one step I can undo
- **so that** I get room to write without redrawing or squeezing anything

#### Acceptance Criteria:
- **Scenario:** A push in the middle of the board
- **Given:** a board with ink above and below a line, and Larry answers my turn with "make room below that line"
- **When:** his answer lands with the Pencil up
- **Then:** every stroke, kept mark and pasted line whose top is at or below the line moves straight down that far, the ink above doesn't move, a page is added at the bottom if the push needs one, and one tap on Undo puts the board back as it was, page count included; Redo pushes it down again. The line he names snaps to a clear line and the distance to whole lines first (story 1195)

---

### User Story 1195:

- **Summary:** Larry's make-room lands between lines and moves whole lines
- **Issues:** bead context-grabber-2gu (Igor, 2026-11-22, design board: "every cut lands between lines")
- **Status:** implemented in [06c48a49](https://github.com/idvorkin/context-grabber/commit/06c48a49); verified by host tests (`BoardOpsTests`: `testLarrysRoomInsideALineCutsAtItsTopAndMovesWholeLines`, `testLarrysRoomNearALinesBottomCutsUnderIt`, `testLarrysRoomOnClearPaperStaysWhereHeAsked`, `testLarrysRoomNeverSplitsAGroupAcrossTheLine`, `testLarrysClosingRoomClosesBlankPaperOnlyInWholeLines`, `testHisNextTurnHearsTheRoomUsed`, `testTheBoardsOwnRoomStaysExact`, and `testOnTheRealBoardsEveryCutLandsBetweenLines` on the four real-board fixtures; `just test`), the Mac build (`just native-build-mac`), and on the iPad simulator (`WhiteboardPaperGhostsUITests`, all 21, Larry's push and its Undo among them). Not yet seen on the iPad, nor against the real Larry. Open, not decided: a push from an older look, after Igor opened room by hand since Larry looked, still snaps at the height Larry saw on the board as it is now, as before (the spec's *Larry makes room*)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** whose board Larry opens room in
- **I want to** have his cut land between my lines and open whole lines, as every other push does
- **so that** a line of my handwriting is never split and the room he opens is room I can write in

#### Acceptance Criteria:
- **Scenario:** He names a height inside a line of writing
- **Given:** a line of my handwriting, and Larry asks for 50 points of room at a height a little way into it
- **When:** his push lands
- **Then:** the cut is at the clear line at the top of that line of writing (its bottom when that is nearer, or the top is more than two lines away), the whole line moves down 80 points (whole lines, rounded up), nothing of it stays behind, and a group of his across the height moves whole or stays whole

---

### User Story 1198:

- **Summary:** Larry hears the room his make-room used
- **Issues:** bead context-grabber-2gu
- **Status:** implemented in [06c48a49](https://github.com/idvorkin/context-grabber/commit/06c48a49); verified by host tests (`BoardOpsTests`: `testHisNextTurnHearsTheRoomUsed`; `just test`) and the Mac build (`just native-build-mac`). Not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** whose board Larry opens room in
- **I want to** have Larry told where his cut landed and how far it moved
- **so that** what he says next matches the board, not the height he guessed

#### Acceptance Criteria:
- **Scenario:** He hears what was used
- **Given:** his push was snapped (story 1195)
- **When:** his next turn goes to him
- **Then:** it says, for each make-room, the height and distance he asked for and the clear line and distance the board used

---

### User Story 1199:

- **Summary:** Larry's closing room closes blank paper only, in whole lines
- **Issues:** bead context-grabber-2gu
- **Status:** implemented in [06c48a49](https://github.com/idvorkin/context-grabber/commit/06c48a49); verified by host tests (`BoardOpsTests`: `testLarrysClosingRoomClosesBlankPaperOnlyInWholeLines`; `just test`) and the Mac build (`just native-build-mac`). Not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** whose board Larry tidies
- **I want to** have his closing of room take only blank paper, in whole lines
- **so that** nothing of mine is ever closed over

#### Acceptance Criteria:
- **Scenario:** He asks to close room
- **Given:** blank paper between two lines of writing, and Larry asks to close more than there is
- **When:** his change lands
- **Then:** only the blank paper closes, in whole lines, and nothing closes onto ink

---

### User Story 862:

- **Summary:** A push below the last ink adds paper
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testAPushMovesOnlyWhatStartsAtOrBelowTheLine`, `testAPushThatNeedsAPageAddsOne`, `testAPushBelowTheLastInkMovesNothingAndAddsPaper`, `testATranslateBelowALine`; `just test`) and the Mac build (`just native-build-mac`). The one undo named for the change, page count included, is PaperKit's, in the board's view, with no host test; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysPushMovesTheInkBelowAndOneUndoPutsItBack`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** whose ink all sits above the line Larry names
- **I want to** have his push grow blank paper rather than move anything
- **so that** the room he asked for is there to write in

#### Acceptance Criteria:
- **Scenario:** A push below the last ink
- **Given:** a board whose ink all sits above the line Larry names
- **When:** his push lands
- **Then:** nothing moves, and the board grows blank paper to reach the room he asked for

---

### User Story 815:

- **Summary:** Larry moves the strokes he names
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testNamedStrokesMoveAndOnlyThose`, `testOpsApplyInOrderOnTheBoardTheEarlierOnesLeft`, `testAStrokeWithSeveralStretchesAnswersToEachId`, `testATranslateOfNamedStrokes`, `testAMovedStrokeGoesBackUnderTheIdItHad`, `testAStrokeWhoseInkChangedIsNotRenamed`, testTheNamesAreKeptPerBoard (gone: BoardOpLedger's setters went in ab4c3ccd); `just test`) and the Mac build (`just native-build-mac`). An id the board doesn't have is skipped and named back to Larry (`missing_ids`); the rest applies; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose board Larry is tidying
- **I want to** see the strokes he names, and only those, move where he says, together with anything else he changes in the same answer
- **so that** a change of his is never half applied

#### Acceptance Criteria:
- **Scenario:** Named strokes and a push in one answer
- **Given:** Larry answers with a push and a move of some strokes he names by the ids the board sent him
- **When:** the answer lands with the Pencil up
- **Then:** both happen, and one Undo takes both back

---

### User Story 863:

- **Summary:** A stroke Larry moved keeps its name
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testNamedStrokesMoveAndOnlyThose`, `testOpsApplyInOrderOnTheBoardTheEarlierOnesLeft`, `testAStrokeWithSeveralStretchesAnswersToEachId`, `testATranslateOfNamedStrokes`, `testAMovedStrokeGoesBackUnderTheIdItHad`, `testAStrokeWhoseInkChangedIsNotRenamed`, testTheNamesAreKeptPerBoard (gone: BoardOpLedger's setters went in ab4c3ccd); `just test`) and the Mac build (`just native-build-mac`). An id the board doesn't have is skipped and named back to Larry (`missing_ids`); the rest applies; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose strokes Larry moves and talks about later
- **I want to** have a moved stroke keep the id he knew it by
- **so that** his connectors and diffs still find it

#### Acceptance Criteria:
- **Scenario:** A moved stroke keeps its name
- **Given:** a stroke Larry has moved
- **When:** the board next sends him its strokes
- **Then:** the stroke has the id he knew it by; only ink I draw, erase or rub part of gets a new one

---

### User Story 816:

- **Summary:** A push never moves ink under my Pencil or on a board that changed
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, and a change held for the Pencil is checked again when the Pencil lifts, so one naming what Igor moved or erased while it waited is refused (story 1220, [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891)); the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` (which since bead context-grabber-3rk holds the stale-push test, testAStalePushMovesNothingAndLarryIsTold), passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** still drawing when Larry answers
- **I want to** have his push wait until I lift the Pencil, and be refused only if I moved or erased what it names after he looked (stories 961, 964)
- **so that** ink never jumps under my pen and never lands in the wrong place

#### Acceptance Criteria:
- **Scenario:** The Pencil is down
- **Given:** I am drawing, or lifted the Pencil less than a moment ago
- **When:** Larry's push arrives
- **Then:** it waits, and applies within a second of the Pencil lifting

---

### User Story 864:

- **Summary:** A push on a board that changed since he looked is refused
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, and a change held for the Pencil is checked again when the Pencil lifts, so one naming what Igor moved or erased while it waited is refused (story 1220, [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891)); the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` (which since bead context-grabber-3rk holds the stale-push test, testAStalePushMovesNothingAndLarryIsTold), passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** who drew after Larry looked at the board
- **I want to** have his push refused rather than land on ink that moved
- **so that** his change never lands in the wrong place

#### Acceptance Criteria:
- **Scenario:** I drew after he looked
- **Given:** after the picture Larry answered I moved or erased something his push names, or his look is older than the board remembers (stories 964, 965); strokes I only added never refuse it (story 961)
- **When:** his push arrives
- **Then:** nothing moves, his next turn tells him it was stale, and a fresh push from him applies

---

### User Story 865:

- **Summary:** A change the board can't take applies none of it
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, and a change held for the Pencil is checked again when the Pencil lifts, so one naming what Igor moved or erased while it waited is refused (story 1220, [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891)); the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` (which since bead context-grabber-3rk holds the stale-push test, testAStalePushMovesNothingAndLarryIsTold), passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry; context-grabber-4nes, a revision no board can have refused whole instead of stopping the app, in [d2e8a11](https://github.com/idvorkin/context-grabber/commit/d2e8a11): `BoardOpsTests.testARevisionNoBoardCanHaveRefusesTheBatchAndNeverTraps` (host, Larry's reply read end to end; it trapped before the fix)
- **Issues:** context-grabber-4nes (a revision too large for a whole number stopped the app while it read Larry's reply)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose board gets an answer it can't carry out
- **I want to** have none of that answer's changes apply, and Larry told why
- **so that** a board is never half changed

#### Acceptance Criteria:
- **Scenario:** A change the board can't take
- **Given:** an answer with more than 50 changes, a push of more than 4000 points, a kind of change this build doesn't know, or a board revision no board can have (a fraction, or a number too large to be one)
- **When:** it arrives
- **Then:** none of it applies, Larry is told why, the rest of his answer shows as it does today, and the session log has one line saying what was refused and why

---

### User Story 866:

- **Summary:** An answer of Larry's applies once
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, and a change held for the Pencil is checked again when the Pencil lifts, so one naming what Igor moved or erased while it waited is refused (story 1220, [f2f70891](https://github.com/idvorkin/context-grabber/commit/f2f70891)); the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` (which since bead context-grabber-3rk holds the stale-push test, testAStalePushMovesNothingAndLarryIsTold), passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose board reads Larry's thread again or opens again
- **I want to** have a push that already applied not apply again
- **so that** nothing moves twice

#### Acceptance Criteria:
- **Scenario:** The same answer seen twice
- **Given:** a push that already applied
- **When:** the board reads the thread again or opens again
- **Then:** it is not applied a second time

---

### User Story 817:

- **Summary:** Larry writes plain, readable text on my board
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testAddTextWithItsLooks`, `testPlainTextIsAPrintGhostAtItsTopLeft`, `testAKeptTextGoesBackAsOneStrokeOfKindText`, `testAKeptTextMovesWholeByItsIdOrAPush`, `testAKeptTextsTimeMatchesItsGlyphsReadBack`; `WhiteboardGhostTurnsTests.testLarrysTextJoinsHisMarksAndReplacesOnlyItsOwnId`; `just test`) and the Mac build (`just native-build-mac`). The text's place is its top-left. A text ghost doesn't come back when the board opens again; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysTextArrivesAsAGhostAndKeepsAsOneText`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry writes plain text*

#### Use Case:
- **As someone** reading Larry's small labels on the board
- **I want to** see his text in a plain typeface, offered as a ghost I keep or dismiss like his other marks
- **so that** it reads cleanly and stays mine to accept

#### Acceptance Criteria:
- **Scenario:** Keep his text
- **Given:** Larry's answer puts a line of text on the board
- **When:** it lands, and I tap it and Keep
- **Then:** it shows as a ghost in a plain typeface at his size and colour, Keep makes it ink on the board (one Undo takes it back, Dismiss throws it away instead), the next picture and strokes Larry gets have it as one text with his id, and a later push from him moves it with the ink around it

---

### User Story 818:

- **Summary:** Larry hears the Pencil and my taps
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testPenAndTapEventsAccumulateUntilTaken`, `testEventsKeepTheirNewestUnderTheCap`, `testEventsOnTheWire`, `testTheTurnMessageCarriesRevResultAndEventsButTheStrokesDont`; `just test`) and the Mac build (`just native-build-mac`); simulator UI tests against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysTextArrivesAsAGhostAndKeepsAsOneText` (the op_result) and `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` (which since bead context-grabber-3rk holds the stale-push test, testAStalePushMovesNothingAndLarryIsTold), pass on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry; a turn with too many events keeping what Larry needs (bead context-grabber-27sv) in [71827734](https://github.com/idvorkin/context-grabber/commit/71827734), verified by host tests (`BoardEventsCapTests`; `just native-test`) and the Mac build (rung 1.5); not yet seen on the iPad
- **Issues:** bead context-grabber-27sv (the debug page showed *5 events dropped* on a turn after two minutes of drawing and a kept reply)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the pen and taps*

#### Use Case:
- **As someone** drawing while Larry watches the board
- **I want to** have Larry told when the Pencil went down and came up and where I tapped
- **so that** he can wait for me to finish and offer things I tap on

#### Acceptance Criteria:
- **Scenario:** A turn after some drawing and a tap
- **Given:** I drew two strokes and tapped one of his marks since his last turn
- **When:** the next picture goes to Larry
- **Then:** it carries the board's revision, what came of his last change, and the Pencil's downs and ups and my tap (where it was, and which of his marks it hit, if any), each with its time; a later turn carries only what happened after

- **Scenario:** A long stretch of drawing between turns
- **Given:** since his last turn I kept his reply, selected it, and drew for a couple of minutes, more events than a turn holds
- **When:** the next picture goes to Larry
- **Then:** it carries as many events as the Cockpit takes, with room for the picture's own sending event; a view I scrolled past and the Pencil's oldest downs and ups go first, so my tap on his reply, my ink changes and my selection all reach him; the count of those let go is on the turn, and the session log says how many of each kind

---

### User Story 819:

- **Summary:** The board takes changes from one place, whoever sends them
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testTheWebSourceOffersTheNewestBatchFirstThenEachNewOne`, `testTheSameBatchNeverAppliesTwice`, testTheLedgerKeepsRevHandledAndTexts (gone: BoardOpLedger's setters went in ab4c3ccd), `testAnotherBoardsBatchIsIgnored`; `just test`) and the Mac build (`just native-build-mac`). Only the web source exists; a source inside the app is the next step; not yet seen on the simulator or the iPad, nor against the real Larry; #1040 (bead context-grabber-img6): what the canvas made of a batch (taken, not there, or refused by PaperKit) is now reported to the one applier, which records it once, only for the batch it let through, so a twice-delivered batch, a closed canvas, a refused edit or an answer after the board closed changes nothing else and Larry still hears `not_applied`. Verified by host tests (`BoardCanvasOutcomeTests`, a recording canvas) and the Mac build; the iPad simulator's one-Undo push (`WhiteboardPaperGhostsUITests`) waits on the Mac's screen unlocking
- **Issues:** [#1040](https://github.com/idvorkin/context-grabber/issues/1040) (bead context-grabber-img6): a review, 2026-11-21, "give remote whiteboard edits a testable canvas application outcome"
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Driven from the web or from the app*

#### Use Case:
- **As someone** whose board Larry will one day drive partly from inside the app
- **I want to** see the same push, the same text and the same single undo whichever side sends them
- **so that** moving a feature from the web into the app changes nothing I see

#### Acceptance Criteria:
- **Scenario:** Today's source
- **Given:** Larry's changes arrive over the network on his board replies
- **When:** they reach the board
- **Then:** they go through the one place that checks, holds and applies changes, which would take a source inside the app the same way, and never applies one change twice

---

### User Story 1106:

- **Summary:** A change of Larry's that landed just before the app quit is not lost
- **Issues:** bead context-grabber-cc75 (the architecture review, 2026-11-21: a batch was remembered as handled about a second before its drawing saved, so a kill in that second lost it while Larry was told it applied)
- **Status:** implemented in [42b31bf](https://github.com/idvorkin/context-grabber/commit/42b31bf), [b4175d5](https://github.com/idvorkin/context-grabber/commit/b4175d5); verified by host tests (`BoardMeaningTests`: the drawing is written before its meaning, a batch held for the Pencil or on its way to the canvas isn't saved as handled, a drawing that fails to save writes no meaning, the move from UserDefaults, a delete takes the meaning) the Mac build (`just native-build-mac`) and the iPad simulator (`just test-ladder --rung 2`: the whiteboard's 15 UI classes; the 6 that fail fail the same on main, beads context-grabber-zem0 and context-grabber-c59d); not yet seen on the iPad, where a kill in that second can't be staged; the `meaning_behind` log line says if a save is ever cut off between the two files
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Edge cases*

#### Use Case:
- **As someone** whose board Larry changes while I work
- **I want to** have each change of his either on the board after a relaunch or offered again
- **so that** Larry is never told a change applied that I will never see

#### Acceptance Criteria:
- **Scenario:** The app is killed right after Larry's change lands
- **Given:** Larry's change has just appeared on my board and the board has not saved yet
- **When:** the app is killed and I open the board again
- **Then:** his change is offered again, and either lands or Larry is told it couldn't, instead of being remembered as done with its ink gone

---

### User Story 1099:

- **Summary:** The board, not the device, remembers which ink is Larry's and which strokes are kept labels
- **Issues:** bead context-grabber-p1pl (follow-up to context-grabber-cc75: the two lists were still kept on the device, apart from the board's file; this step moves them into it, and the file reaching other devices is a later step)
- **Status:** implemented in [e085eeb](https://github.com/idvorkin/context-grabber/commit/e085eeb9); verified by host tests (`BoardMeaningTests`: a file from before reads, the keys join a file already there and go, with no file they make one, what the file holds is only added to, a failed move leaves the file and the keys, a move that doesn't read back puts the file back as it was, a board whose six old keys haven't moved waits, the keys fill the board as it opens; `just native-test`) and the Mac build (`just native-build-mac`); the iPad simulator's whiteboard UI tests couldn't start (the Mac's screen was locked); not yet seen on the iPad, where the `meaning_migrated` line's labels and theirs counts show the move
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Edge cases*

#### Use Case:
- **As someone** who keeps Larry's marks and labels on a board and opens it again later
- **I want to** have the board itself remember which of its ink is Larry's and which strokes are labels
- **so that** his kept marks never make room as if they were mine, and *Tidy overlaps* still finds every label, after the app updates

#### Acceptance Criteria:
- **Scenario:** A board from before this build
- **Given:** a board whose labels and Larry's kept marks were remembered on this device
- **When:** the app updates and I open the board
- **Then:** *Tidy overlaps* lays out the same labels as before, and Larry's kept marks still never make room as mine; nothing the board already knew is lost

---

### User Story 1100:

- **Summary:** A label or a mark of Larry's kept now is remembered with the board's ink
- **Issues:** bead context-grabber-p1pl
- **Status:** implemented in [e085eeb](https://github.com/idvorkin/context-grabber/commit/e085eeb9); verified by host tests (`BoardMeaningTests`: the ledger remembers labels and theirs, capped, and tells each change; `just native-test`) and the Mac build (`just native-build-mac`); the iPad simulator's whiteboard UI tests couldn't start (the Mac's screen was locked); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Edge cases*

#### Use Case:
- **As someone** who keeps Larry's labels on a board
- **I want to** have the board remember a label the moment I keep it
- **so that** a later *Tidy overlaps* finds it, with nothing kept only on the device

#### Acceptance Criteria:
- **Scenario:** A label kept just now
- **Given:** I keep one of Larry's labels
- **When:** the board saves its ink
- **Then:** the label is remembered in the same save, and a later *Tidy overlaps* finds it

---

### User Story 840:

- **Summary:** Larry draws ink straight onto my board
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testAddStrokesWithTheirLooksAndNotes`, `testAPenTooThinOrTooWideDrawsWithinReach`, `testLarrysInkJoinsTheBoardWhereLaterOpsLeaveIt`, `testLarrysStrokesGoBackUnderHisNamesWithHisNotes`, `testInkTheCockpitWouldRefuseIsRefusedHere`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry draws, erases and replaces ink*

#### Use Case:
- **As someone** whose board Larry is helping lay out
- **I want to** have Larry draw real strokes on the board, at his width and colour
- **so that** his drawing is part of the page, not a ghost I have to keep

#### Acceptance Criteria:
- **Scenario:** He draws
- **Given:** Larry's answer adds two strokes with names of his own
- **When:** it lands with the Pencil up
- **Then:** both strokes are ink on the page at once, the board's next strokes give them back under his names, and one Undo takes them away

---

### User Story 841:

- **Summary:** Larry erases and replaces ink by name
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testDeleteSetMetaAndReplace`, `testDeleteByNameAndReplace`, `testAStrokeDrawnAgainUnderItsNameReplacesIt`, `testLarrysOwnInkCanBeErasedInTheSameBatch`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry draws, erases and replaces ink*

#### Use Case:
- **As someone** whose scrawl Larry is tidying
- **I want to** have Larry erase strokes, or swap some for clean ones, in one step
- **so that** a tidy never leaves the old and the new ink both on the page

#### Acceptance Criteria:
- **Scenario:** A replace and an erase in one answer
- **Given:** Larry's answer erases one stroke and replaces two others with one clean line
- **When:** it lands
- **Then:** the three strokes go, the clean line is there, one Undo brings back exactly what was, and a name the board doesn't have is told back to him and nothing else of the answer is lost

---

### User Story 842:

- **Summary:** Larry's groups move as one
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testAGroupMovesWholeAndAnswersToItsName`, `testNotesAreKeptAsWritten`, `testNotesSetByNameAndForgottenWithTheirStrokes`, testTheNotesAreKeptPerBoard (gone: BoardOpLedger's setters went in ab4c3ccd), `testLarrysStrokesGoBackUnderHisNamesWithHisNotes`; `just test`) and the Mac build (`just native-build-mac`). The Cockpit's strokes endpoint ignores `meta` today, so the notes reach Larry only once it keeps them; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry groups ink*

#### Use Case:
- **As someone** with a label Larry underlined
- **I want to** have the strokes Larry groups move together
- **so that** a push never splits a label from its underline

#### Acceptance Criteria:
- **Scenario:** A group across the line
- **Given:** a group of Larry's whose top is above the line he pushes below, and another stroke of it below
- **When:** the push lands
- **Then:** the whole group moves together or stays together by its top, and his notes on the strokes come back to him exactly as he wrote them

---

### User Story 843:

- **Summary:** Larry hears my ink change
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testIgorsInkChangeIsToldByName`, `testInkEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`). A rub with the pixel eraser that leaves a stroke's box as it was isn't seen as a change; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears my ink change and my selection*

#### Use Case:
- **As someone** drawing, erasing and moving ink while Larry follows
- **I want to** have Larry told what I added, erased and moved, by name
- **so that** he can say "new since my last reply" without guessing

#### Acceptance Criteria:
- **Scenario:** A few changes
- **Given:** since his last turn I drew a stroke, erased one and moved one with the lasso
- **When:** his next turn goes
- **Then:** it names the added, erased and moved strokes and the board's revision after each change, and the moved stroke keeps the name it had

---

### User Story 844:

- **Summary:** Larry hears my lasso selection
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests.testInkEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears my ink change and my selection*

#### Use Case:
- **As someone** circling ink to talk about it
- **I want to** have Larry told which strokes I selected
- **so that** "this" means what I circled

#### Acceptance Criteria:
- **Scenario:** I circle some ink
- **Given:** I lasso three strokes
- **When:** his next turn goes
- **Then:** it names those three strokes as my selection

---

### User Story 845:

- **Summary:** Larry lays bands, chips, buttons and hints on the board
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testAnOverlayWithItsLooksAndItsEvent`, `testAnOverlayThatCantShowIsRefused`, `testControlsAreLaidReplacedTakenAwayAndHit`, `testSelectingAndControlsLeaveTheInkAsItIs`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** talking with Larry on the board
- **I want to** see Larry's few controls at their places, scrolling with the board
- **so that** I can answer him with a tap instead of words

#### Acceptance Criteria:
- **Scenario:** A band and a button
- **Given:** Larry lays a band across the page and a button beside it
- **When:** they land
- **Then:** they show at their places with their labels, scroll and zoom with the board, are in no picture and no strokes, are never undone, and go when he takes them away

---

### User Story 846:

- **Summary:** A tap on Larry's control reaches him at once
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6), the wake and the caps in [782b1ad](https://github.com/idvorkin/context-grabber/commit/782b1ad) (`BoardOpsControlsTests.testAReportKeepsToTheCockpitsCaps`; the fake Cockpit mirrors the live endpoint); verified by host tests (`BoardOpsControlsTests`: `testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** tapping one of Larry's buttons
- **I want to** have the tap reach him straight away
- **so that** he answers what I chose without waiting for my next turn

#### Acceptance Criteria:
- **Scenario:** I tap his button
- **Given:** a button of Larry's on the board
- **When:** I tap it with a finger
- **Then:** its event goes to the Cockpit at once with the board's revision; if the Cockpit can't take it, it goes with my next turn, and the session log says which

---

### User Story 867:

- **Summary:** A tap on Larry's button wakes him with what he asked to hear
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6), the wake and the caps in [782b1ad](https://github.com/idvorkin/context-grabber/commit/782b1ad) (`BoardOpsControlsTests.testAReportKeepsToTheCockpitsCaps`; the fake Cockpit mirrors the live endpoint); verified by host tests (`BoardOpsControlsTests`: `testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** tapping one of Larry's buttons
- **I want to** have the Cockpit wake him with what the button was for
- **so that** he answers the choice he offered

#### Acceptance Criteria:
- **Scenario:** The tap wakes him
- **Given:** a button of Larry's that asks to hear "make room"
- **When:** I tap it
- **Then:** the Cockpit gets a tap on his control naming the button, with his "make room" as he wrote it, and wakes him; a plain tap elsewhere on the board is never sent as one

---

### User Story 868:

- **Summary:** Events since the last turn keep to the Cockpit's caps
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6), the wake and the caps in [782b1ad](https://github.com/idvorkin/context-grabber/commit/782b1ad) (`BoardOpsControlsTests.testAReportKeepsToTheCockpitsCaps`; the fake Cockpit mirrors the live endpoint); verified by host tests (`BoardOpsControlsTests`: `testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** who did a lot on the board since Larry's last turn
- **I want to** have the newest events reach him within the Cockpit's limits
- **so that** he is never refused for too much, and knows what he missed

#### Acceptance Criteria:
- **Scenario:** A lot happened since the last turn
- **Given:** more events than the Cockpit takes at once, or one too big
- **When:** they are sent
- **Then:** at most 200 go, none over 8 KB, the whole under 256 KB, the newest kept, and Larry is told how many he missed

---

### User Story 847:

- **Summary:** Larry folds ink away and back
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testHiddenInkMovesWithAPushAndHidingIsAChange`, `testInkHeDrawsHiddenIsDrawnHidden`, `testAHiddenStrokeIsSaidToBe`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry folds and selects*

#### Use Case:
- **As someone** whose long board Larry is folding into sections
- **I want to** have Larry hide strokes and show them again
- **so that** a section can be out of the way without being gone

#### Acceptance Criteria:
- **Scenario:** He hides a section
- **Given:** Larry's answer hides five strokes
- **When:** it lands, and a push of his later moves them, and then he shows them
- **Then:** they vanish at once, keep their place and move with the push while hidden, come back where the push left them, and one Undo undoes the hiding as part of his answer

---

### User Story 848:

- **Summary:** Larry selects ink for me
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testHideAndSelect`, `testSelectingAndControlsLeaveTheInkAsItIs`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry folds and selects*

#### Use Case:
- **As someone** Larry is pointing at ink for
- **I want to** have Larry select strokes as if I had circled them
- **so that** I can move or delete what he means in one gesture

#### Acceptance Criteria:
- **Scenario:** He selects
- **Given:** Larry's answer selects two strokes
- **When:** it lands
- **Then:** those two are selected on the board, and nothing else changes

---

### User Story 849:

- **Summary:** Larry hears the margin
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testTheMarginsGestures`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`). A finger that draws on paper still draws in the margin too; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the margin, the view and Undo*

#### Use Case:
- **As someone** asking for room by hand
- **I want to** have a finger tap, hold or drag in the board's left margin reach Larry
- **so that** he can open room where I asked

#### Acceptance Criteria:
- **Scenario:** A drag in the margin
- **Given:** the board open
- **When:** I drag a finger down the left margin
- **Then:** Larry's next turn has a margin drag with where it started on the board and how far it went; a tap and a hold there are told the same way

---

### User Story 850:

- **Summary:** Larry hears where I'm looking
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests.testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the margin, the view and Undo*

#### Use Case:
- **As someone** scrolling a long board
- **I want to** have Larry told what part of the board is on screen when I stop
- **so that** he can answer about what I see

#### Acceptance Criteria:
- **Scenario:** I scroll and stop
- **Given:** the board open
- **When:** I scroll down and let it rest
- **Then:** Larry's next turn has the part of the board on screen and the zoom, once per rest, not on every frame

---

### User Story 851:

- **Summary:** Larry hears me undo his change
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests.testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the margin, the view and Undo*

#### Use Case:
- **As someone** undoing a change of Larry's
- **I want to** have Larry told which of his changes I undid
- **so that** he doesn't build on a change I took back

#### Acceptance Criteria:
- **Scenario:** I undo his push
- **Given:** a push of Larry's on the board
- **When:** I tap Undo
- **Then:** his next turn has an undo naming that change

---

### User Story 970:

- **Summary:** A refused change of Larry's says so on the board
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry: "show a chip so I'm not guessing" when Larry's push is refused
- **Issues:** `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` on main 2510b8c6, 2026-11-17: the chip moved under ? and Feedback (#929), and a tap on its bare × glyph went through to the paper and drew a dot (`ui_touch_begin` on `PKTiledGestureView` at 797, 202.5; no `board_blocked dismissed`)
- **Issues:** beads context-grabber-ts8a and context-grabber-kxzk (2026-11-23): since #1325 dimmed Send once Larry has the picture, Retry went through that refusal, sent nothing and used up its chip, and `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` failed on main; Igor via Larry: Retry always hands over the board. Fixed in [7d060c6b](https://github.com/idvorkin/context-grabber/commit/7d060c6b).
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`); and on the simulator (`WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`, rung 2). Retry and × take a finger's width in [753c9ec](https://github.com/idvorkin/context-grabber/commit/753c9ec); verified by `just test`, the Mac build, and on the simulator (`WhiteboardPaperGhostsUITests`, the chip test included, and `WhiteboardHelpFeedbackUITests`, rung 2) Retry hands over the board when Larry already has the picture, and the chip stays until a picture goes (beads context-grabber-ts8a, kxzk): [7d060c6b](https://github.com/idvorkin/context-grabber/commit/7d060c6b); verified by host tests (`WhiteboardLarryTurnTests.testABlockedEditsRetryHandsOverTheBoardLarryAlreadyHas`) and the iPad simulator (2026-11-23, `WhiteboardPaperGhostsUITests` 22 passed, 1 skipped, `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` among them). The stale-push UI test is folded into the chip test, one launch for both (bead context-grabber-3rk), in [c6b8a690](https://github.com/idvorkin/context-grabber/commit/c6b8a690), verified on the iPad Pro 11-inch (M5) simulator (rung 2, `WhiteboardPaperGhostsUITests` 21 tests, the chip test passing first try): `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` now also checks that a stale push moves nothing, shows none of his text, and that Retry's turn says `stale` (story 816's rule stays `BoardOpsTests.testAStaleBatchAppliesNothingAndSaysSo` on the host).
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** writing while Larry edits the board
- **I want to** see when one of his changes couldn't be applied
- **so that** I'm not left wondering why nothing moved

#### Acceptance Criteria:
- **Scenario:** Refused
- **Given:** after Larry looked I moved or erased something his change names (story 964; writing on alone no longer refuses it, story 961)
- **When:** his change comes back refused
- **Then:** a chip in his purple says *Larry's edit blocked · Retry*, with × beside it, and nothing on the board moved

---

### User Story 971:

- **Summary:** Retry hands Larry the board again
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Issues:** beads context-grabber-ts8a and context-grabber-kxzk (2026-11-23): since #1325 dimmed Send once Larry has the picture, Retry went through that refusal, sent nothing and used up its chip, and `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` failed on main; Igor via Larry: Retry always hands over the board. Retry always hands Larry the board, even when he has this picture; only the Send button keeps that dimming. Fixed in [7d060c6b](https://github.com/idvorkin/context-grabber/commit/7d060c6b).
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`); and on the simulator (`WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`, rung 2) Retry hands over the board when Larry already has the picture, and the chip stays until a picture goes (beads context-grabber-ts8a, kxzk): [7d060c6b](https://github.com/idvorkin/context-grabber/commit/7d060c6b); verified by host tests (`WhiteboardLarryTurnTests.testABlockedEditsRetryHandsOverTheBoardLarryAlreadyHas`) and the iPad simulator (2026-11-23, `WhiteboardPaperGhostsUITests` 22 passed, 1 skipped, `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` among them).
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** whose board moved on before Larry's change arrived
- **I want to** tap Retry
- **so that** Larry looks at the board as it is and sends a fresh change

#### Acceptance Criteria:
- **Scenario:** Retry
- **Given:** the chip shows
- **When:** I tap Retry
- **Then:** the chip goes and it is Larry's turn, with the board as it is now and what happened to his last change; his refused change is never replayed

- **Scenario:** Retry while a picture is on its way
- **Given:** the chip shows and a picture of this board is still on its way to Larry
- **When:** I tap Retry
- **Then:** nothing more is sent and the chip stays, so I can tap Retry again once that picture has gone

---

### User Story 972:

- **Summary:** × puts the chip away
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Issues:** beads context-grabber-ts8a and context-grabber-kxzk (2026-11-23): since #1325 dimmed Send once Larry has the picture, Retry went through that refusal, sent nothing and used up its chip, and `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` failed on main; Igor via Larry: Retry always hands over the board. Fixed in [7d060c6b](https://github.com/idvorkin/context-grabber/commit/7d060c6b).
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`); and on the simulator (`WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`, rung 2) Retry hands over the board when Larry already has the picture, and the chip stays until a picture goes (beads context-grabber-ts8a, kxzk): [7d060c6b](https://github.com/idvorkin/context-grabber/commit/7d060c6b); verified by host tests (`WhiteboardLarryTurnTests.testABlockedEditsRetryHandsOverTheBoardLarryAlreadyHas`) and the iPad simulator (2026-11-23, `WhiteboardPaperGhostsUITests` 22 passed, 1 skipped, `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` among them).
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** who doesn't need Larry to try again
- **I want to** put the chip away
- **so that** it doesn't sit on the board once I've seen it

#### Acceptance Criteria:
- **Scenario:** Dismiss
- **Given:** the chip shows
- **When:** I tap ×
- **Then:** the chip goes and nothing is sent to Larry

---

### User Story 976:

- **Summary:** A newer refusal replaces the chip
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** writing while Larry edits the board
- **I want to** see only his latest blocked change
- **so that** the board never fills with chips

#### Acceptance Criteria:
- **Scenario:** One chip
- **Given:** the chip shows
- **When:** another change of his is refused
- **Then:** the one chip stays, for the newer change

---

### User Story 977:

- **Summary:** Leaving the board forgets the chip
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** who leaves a board mid-change
- **I want to** find no chip for a board I've left
- **so that** nothing speaks for a board nobody is looking at

#### Acceptance Criteria:
- **Scenario:** Leaving the board
- **Given:** a change of his waiting for my Pencil
- **When:** I leave the board
- **Then:** no chip shows anywhere

---

### User Story 978:

- **Summary:** A change that applies clears the chip
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** whose board Larry has caught up with
- **I want to** have the chip go once his next change lands
- **so that** it never lingers after it stops being true

#### Acceptance Criteria:
- **Scenario:** Applied
- **Given:** the chip shows
- **When:** a later change of his applies
- **Then:** the chip goes
