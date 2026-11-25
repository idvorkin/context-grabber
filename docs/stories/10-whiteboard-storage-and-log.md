# The whiteboard: Storage, sync and the log

Boards that can't be read or haven't synced, unknown ink, and what the board's log keeps about tools and touches. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md),
[reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md).

---

### User Story 1159:

- **Summary:** The session log records which earlier replies stayed on the board
- **Status:** implemented in [10727b6c](https://github.com/idvorkin/context-grabber/commit/10727b6c). The simulator verified that the earlier marks stayed (`WhiteboardTurnUITests`). The `earlier_stayed` and `earlier_replies` fields have not yet been seen in a session log
- **Issues:** bead `context-grabber-n8ab`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** investigating why Larry's marks disappeared
- **I want to** see how many earlier marks and replies stayed when his next marks arrived
- **so that** I can tell what happened from the session log

#### Acceptance Criteria:
- **Scenario:** The log counts what stayed
- **Given:** marks of his are showing
- **When:** another reply's marks show
- **Then:** its `whiteboard_marks` line reports the earlier marks that stayed in `earlier_stayed` and their reply count in `earlier_replies`

---

### User Story 1060:

- **Summary:** A board whose drawing can't be read or moved aside is left as it was, and nothing saves over it
- **Status:** implemented in [2a9b1f0e](https://github.com/idvorkin/context-grabber/commit/2a9b1f0e); verified by host tests (`BoardKeepingTests`: bad bytes and a failed move leave the original and an older set-aside copy untouched through an edit's save, a relaunch and a reopen; a later open that can move it sets it aside beside the older one and the board saves again; a healthy board and a new one are never held), the Mac build, and the iPad simulator (rung 2, 2026-11-21: the 14 other whiteboard classes green on this change; `WhiteboardOnPaperUITests.testAnUnreadableBoardThatCannotBeMovedAsideOpensLookOnly`'s first open showed the copyable problem and *look only*, the session log `editable: false`, `kept_at: null` and the move's permission error; its rerun after taking out a drag a look-only board reads as swipe back waits on the Mac's screen unlocking). Not yet seen on the iPad
- **Issues:** [#1042](https://github.com/idvorkin/context-grabber/issues/1042) (bead context-grabber-75cg): a source review, 2026-11-21, "a subsequent save can overwrite the recoverable original"
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The board is kept*

#### Use Case:
- **As someone** whose board file has gone bad on a device that won't let it be moved
- **I want to** see a problem I can copy, and have the board open look-only
- **so that** nothing I draw that time saves over a drawing that might still be recovered

#### Acceptance Criteria:
- **Scenario:** An unreadable board that can't be moved aside
- **Given:** a board of mine on paper whose saved drawing can't be read, and whose file can't be moved aside
- **When:** I open it, leave, and open it again
- **Then:** each time a copyable problem names the board and says it was left as it was, the board says *Couldn't be read: look only* and takes no ink, and the file and any copy set aside before are exactly as they were

---

### User Story 1061:

- **Summary:** A board whose newer version fails to come down from iCloud keeps showing the last one that did
- **Status:** implemented in [b00acbce](https://github.com/idvorkin/context-grabber/commit/b00acbce); verified by host tests (`BoardKeepingTests`: a failed copy, an unreadable or missing drawing and an interrupted asset each leave the old drawing and picture untouched and nothing removed first; a retry brings the new version; a failed first download leaves no file; a missing or failed picture still takes the drawing and says so) and the Mac build; still in the list while its newer version fails in [d4103e05](https://github.com/idvorkin/context-grabber/commit/d4103e05) (`BoardIndexTests`). The simulator has no iCloud account, so the CloudKit path itself waits for the iPhone and the iPad
- **Issues:** [#1043](https://github.com/idvorkin/context-grabber/issues/1043) (bead context-grabber-nuyw): a source review, 2026-11-21, "a copy failure can leave a reading device without its last viewable replica"
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** looking at the iPad's board on the iPhone
- **I want to** keep seeing the last version that arrived when a newer one fails to come down
- **so that** a bad sync never leaves me with a blank board until the next good one

#### Acceptance Criteria:
- **Scenario:** A refresh that fails over a board already here
- **Given:** the iPhone has a board from the iPad, and the iPad has drawn more on it
- **When:** the iPhone's sync of the newer version fails partway, and I open the board offline, then sync again with the network back
- **Then:** offline it shows the version it had, the list says boards aren't syncing, and the next sync brings the newer version, with its picture drawn on the iPhone if iCloud's came without one

---

### User Story 1062:

- **Summary:** A broken copy of another device's board is repaired by the next good sync
- **Status:** implemented in [584037a4](https://github.com/idvorkin/context-grabber/commit/584037a4); verified by host tests (`BoardKeepingTests`: a held copy of another device's board is replaced by the next good copy and let go; a held board of this device's isn't replaced and still refuses saves). The simulator has no iCloud account, so the CloudKit path itself waits for the iPhone and the iPad
- **Issues:** [#1043](https://github.com/idvorkin/context-grabber/issues/1043) (bead context-grabber-nuyw): a held replica made every sync fail, so the list said boards weren't syncing until that board was opened
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** looking at the iPad's board on the iPhone
- **I want to** have a copy that went bad on the iPhone replaced by iCloud's good one
- **so that** one broken copy never leaves the board unreadable or the whole sync failing

#### Acceptance Criteria:
- **Scenario:** A broken copy of another device's board is repaired
- **Given:** the iPhone's copy of the iPad's board can't be read and couldn't be moved aside
- **When:** the iPhone syncs and iCloud has a good copy of that board
- **Then:** the good copy replaces the broken one, the board opens to look at again, and the list doesn't say boards aren't syncing

---

### User Story 1063:

- **Summary:** A stroke of an ink the app doesn't know never closes the board
- **Status:** implemented in 61540121; verified by host tests (WhiteboardInkTests) and the Mac build; on the iPad and the iPhone since 2026-11-21 (311c4711); which ink it was is still owed, from the iPad's log
- **Issues:** [#1083](https://github.com/idvorkin/context-grabber/issues/1083), with [#1080](https://github.com/idvorkin/context-grabber/issues/1080), [#1081](https://github.com/idvorkin/context-grabber/issues/1081), [#1082](https://github.com/idvorkin/context-grabber/issues/1082), [#1084](https://github.com/idvorkin/context-grabber/issues/1084), [#1085](https://github.com/idvorkin/context-grabber/issues/1085), [#1092](https://github.com/idvorkin/context-grabber/issues/1092)–[#1095](https://github.com/idvorkin/context-grabber/issues/1095): the iPad closed three times in two minutes on 2026-11-21, each just after a stroke landed, when the board asked that stroke's ink for its kind
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Ink the app doesn't know never crashes the board*

#### Use Case:
- **As someone** writing on the iPad's board
- **I want to** keep writing whatever ink a stroke turns out to carry
- **so that** the board never closes under my Pencil and loses the thought I was on

#### Acceptance Criteria:
- **Scenario:** A stroke of an unknown ink lands on the board
- **Given:** a board open on the iPad
- **When:** a stroke arrives whose ink is of a kind the app has no name for
- **Then:** the board stays open, the stroke draws and saves, Larry gets it with its kind as the ink spells it, and the session log names that kind once

---

### User Story 1092:

- **Summary:** A board holding an ink that doesn't read back opens again
- **Status:** implemented in 9489f7c1; verified by host tests (WhiteboardInkTests), the Mac build and the whiteboard UI tests on the iPad simulator
- **Issues:** bead context-grabber-3b02: a drawing holding an ink this PencilKit can't name saves but doesn't read back ("from a future version"), so its board wouldn't open
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Ink the app doesn't know never crashes the board*

#### Use Case:
- **As someone** writing on the iPad's board
- **I want to** open a board again whatever ink its strokes carry
- **so that** a stroke of an ink the app can't read back never locks me out of the board it is on

#### Acceptance Criteria:
- **Scenario:** A board holding an ink that doesn't read back is saved
- **Given:** a board on the iPad with a stroke of an ink the app has no name for, which this build can't read back from a saved board
- **When:** the board is saved and opened again
- **Then:** it opens to draw on, with that stroke where it was as the pen in its own colour and strength, it goes to Larry as *pen*, and the save's log line names the kind, that it didn't read back, and how many strokes were saved as the pen

---

### User Story 1064:

- **Summary:** The log says which tool Igor picked, beside the one the board thinks it holds
- **Status:** implemented in 57255cf5; verified by `just native-test` (lint, host tests, script checks) and the Mac build; the iPad's log with both tools on a touch is still owed
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078): "Switched to eraser still drew normally"; every touch the iPad has logged names a black pen, including 11 that erased ink and the strokes Igor drew in blue
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says which tool Igor picked*

#### Use Case:
- **As someone** who reports that a tool did the wrong thing
- **I want to** have the log say which tool I had picked and which one the board used
- **so that** the fix goes after the real cause, not a guess

#### Acceptance Criteria:
- **Scenario:** Igor picks the eraser and writes
- **Given:** a board open on the iPad with the pen in hand
- **When:** Igor picks the eraser in the tool picker and touches the board with the Pencil
- **Then:** the log has a line for the change naming the eraser the picker shows and the tool the board holds, and the touch's line names both

---

### User Story 1102:

- **Summary:** The log says what comes over an open board and how long it stays
- **Status:** implemented in [eb488471](https://github.com/idvorkin/context-grabber/commit/eb488471); verified by `just native-test` (lint, host tests, script checks), the Mac build, and the iPad simulator (rung 2, 2026-11-22: the 66 whiteboard UI tests and the PaperKit contract tests green; their session logs carry `board_cover` lines naming the board's own full-screen cover, a context menu coming over it and going, and the responder moving to the handwriting view). The iPad's line when the Paste-only state comes back is still owed
- **Issues:** [#1140](https://github.com/idvorkin/context-grabber/issues/1140): "I can't click on menus, whatever I click on I get the pop-up menu Paste"; the iPad's report shows a full-screen popover drawn by another process over the board, a *Paste · Select All* menu under the bar, and no touch heard for the twenty seconds before the shake
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says what covers the board*

#### Use Case:
- **As someone** whose board stops answering and only offers Paste
- **I want to** have the log say what came over the board, when, and what it was
- **so that** the fix goes after the real cause, not a guess

#### Acceptance Criteria:
- **Scenario:** Something comes over the board and goes
- **Given:** a board open on the iPad
- **When:** a popover, a sheet or an edit menu comes up over it, and later goes
- **Then:** the log has a line as it comes, naming what it is, how it was shown, where it sits, what it points at, whether another process draws it, any edit menu and what would answer a Paste, and a line as it goes saying how long it stayed

---

### User Story 1091:

- **Summary:** The board acts on the tool Igor picked, not the one it thinks it holds
- **Status:** implemented in [2b6d48ab](https://github.com/idvorkin/context-grabber/commit/2b6d48ab); verified by `just native-test` (lint, host tests, script checks) and the Mac build. No host or UI test can see the picker disagree with the board, so the fold, card, snap and hold choices wait for the iPad's log
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078); bead context-grabber-ckv5 (whiteboard arch 1): 7,313 iPad touches logged the board's tool as a black pen, including 11 that erased and strokes drawn blue, so every choice made from it (folds, cards, label width, snaps, holds, headers) followed a pen Igor wasn't holding
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The board acts on the tool Igor picked*

#### Use Case:
- **As someone** switching between the pen and the eraser on the iPad's board
- **I want to** have the board treat each touch as the tool I picked for it
- **so that** the eraser takes a fold or an answered card, and a pen's stroke snaps or holds, whatever the board's own idea of the tool

#### Acceptance Criteria:
- **Scenario:** Igor erases across a folded header after picking the eraser
- **Given:** a board on the iPad with a folded header, and the tool picker showing the eraser while the board still reports a black pen
- **When:** Igor draws the eraser across the fold's marker with the Pencil
- **Then:** the fold goes as one *Erase*, and the touch's log line names the eraser as the picker's tool beside the board's own

---

### User Story 1098:

- **Summary:** A board opens drawing with the tool the picker shows, so a kept eraser erases from the first stroke
- **Status:** implemented in [3fe2f43d](https://github.com/idvorkin/context-grabber/commit/3fe2f43d); verified by `just native-test`, the Mac build, and the iPad simulator (`WhiteboardEraserUITests`: the eraser kept from the last launch drew a black line before the fix, and draws no ink after it; the eraser picked after the report sheet draws no ink); the iPad's Pencil is still owed
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078): "Switched to eraser still drew normally"; bead context-grabber-8o93. The picker opened on the eraser kept from before, and the board drew with its own black pen until the next pick
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board opens drawing with the tool the picker shows*

#### Use Case:
- **As someone** who left the eraser picked when the app last closed
- **I want to** have the board erase when the picker shows the eraser, from the first stroke
- **so that** what the picker shows is what the Pencil does, without picking it again

#### Acceptance Criteria:
- **Scenario:** The eraser kept from the last launch
- **Given:** the eraser picked in the tool picker, and the app closed and opened again
- **When:** Igor opens a board, sees the eraser selected, and draws across bare paper
- **Then:** no ink lands, and a pen picked after that draws as before

- **Scenario:** The eraser picked after the report sheet
- **Given:** a board open, and BugKit's report sheet opened and closed over it
- **When:** Igor picks the eraser and draws across bare paper
- **Then:** no ink lands

---

### User Story 1221:

- **Summary:** The log never calls the app's time away a stuck main thread
- **Status:** implemented in [78a1fb1e](https://github.com/idvorkin/context-grabber/commit/78a1fb1e), verified by host tests (`MainStallMeterTests`: the iPad's 921 s away said as away, the 6.5 s real stall still a stall, away mid-stall, the 5 s line; `just native-test`) and the Mac build (`just native-build-mac`); changed in [d3d9fbf4](https://github.com/idvorkin/context-grabber/commit/d3d9fbf4) and its review follow-up (the gap said once whether a look, a reply or a stop comes first, a sleep-inclusive clock, stall timing restarting at the next look), verified by host tests only (`MainStallMeterTests`: reply-first, stop-first, a second sleep after a reply-first resume); the simulator was not run (a suspension and its gap need the device); not yet seen on the iPad
- **Issues:** bead context-grabber-55vm (the iPad, 2026-11-20 and 11-21: `main_stall` waited_ms of 281,422 to 921,354 in grabber-20261120-071137, 1,158,372 in 062630, 297,938 and 361,127 in 20261121-075408, and 2,957,505 in 101810, each the app's time away; the watch hadn't stopped, so a real hang on the board would have been lost among them)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says what held the board up while Igor wrote*

#### Use Case:
- **As someone** who reads the session log to find out why the board froze
- **I want to** have a stuck main thread mean the app was really stuck, never that it was away
- **so that** a real hang stands out instead of hiding among minutes-long "stalls" that were the iPad asleep

#### Acceptance Criteria:
- **Scenario:** The app comes back after being suspended
- **Given:** the app was suspended or the iPad slept for at least five seconds while the watch was still running
- **When:** the app comes back
- **Then:** the first watch look, main-thread reply, or stop records one `main_stall` `away` with the time since the last look, discards any stall in progress, and times the next stall from the watch's next look
- **And:** a normal stop before suspension and the next start appear as `stopped` and `watching`
- **And:** each start and stop of the watch names the app's state and its scenes' states
- **And:** a real stall lasting at least a second while the watch keeps looking still records `main_stall` `began` and `ended`

---

### User Story 1168:

- **Summary:** The log names the parts of a slow change to the ink
- **Status:** implemented (the logging alone) in [c0fc7c3b](https://github.com/idvorkin/context-grabber/commit/c0fc7c3b); verified by host tests (`StepLapsTests`: the iPad's 1,475 ms stroke named by part, a quick change silent, the threshold; `just native-test`) and the Mac build (`just native-build-mac`); the simulator was not run (the line needs a slow change, which only a full board on the iPad has shown), and the iPad's own `paper_ink_slow` is still owed
- **Issues:** bead context-grabber-uktm (#946's "I think I just hung": still not reproduced; the iPad, 2026-11-22, build 565acfe0, board 8f986938 of about 1,000 strokes: `main_stall` began at t=3360294, 4244301 and 4250044, each just after a stroke whose `paper_ink` took 963, 1,475 and 1,348 ms against about 50 for the strokes either side; none followed a `scratch`, `hold_stroke` or `board_word` line; a fourth, at t=4261015, came mid-stroke with that stroke's `paper_ink` at 50 ms)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says what held the board up while Igor wrote*

#### Use Case:
- **As someone** whose board froze for a second now and then while I wrote on a full page
- **I want to** have the log say which part of the board's handling of my stroke took the time
- **so that** the fix goes at the slow part instead of guessing at it

#### Acceptance Criteria:
- **Scenario:** A slow change to the ink
- **Given:** a board whose handling of a change to the ink takes a quarter of a second or more
- **When:** the change has been handled
- **Then:** the log has one line with the whole time and each part's time by name, the stroke count, how many strokes the change added, moved and removed, and the time since the ink last changed
- **And:** nothing I see changes
- **And:** a change handled in less than a quarter of a second writes no such line

---

### User Story 1188:

- **Summary:** The log says what PaperKit's handwriting reflow was doing before it crashed
- **Status:** implemented (the logging alone) in [f99745f9](https://github.com/idvorkin/context-grabber/commit/f99745f9) and [245dd494](https://github.com/idvorkin/context-grabber/commit/245dd494) (a touch on a reflow view names every one); verified by host tests (`PaperProbeReflowTests`; `just native-test`) and the Mac build (`just native-build-mac`); the simulator never shows PaperKit's reflow, so the iPad's own `paper_reflow` lines are owed (rung 3)
- **Issues:** [#1256](https://github.com/idvorkin/context-grabber/issues/1256) and [#1255](https://github.com/idvorkin/context-grabber/issues/1255), one crash (the iPad, 2026-11-22 23:21:23Z, build 8df171a9, session log grabber-20261122-151404, board c4daf842): `CALayerInvalidGeometry`, "CALayer position contains NaN" on a 347×159 word picture, thrown from `-[CALayer setFrame:]` called by PaperKit's `ReflowTextView.stepAnimation()` on a display link (symbolicated against the 27.2.1 (24B156) PaperKit); MetricKit's report is the same abort. The last lines: ten finger taps on Larry's kept group with the system's handwriting popover coming back over it, a finger drag that panned, then a touch beginning on `HandwritingReflowView` about 20 ms before the log ends. Build 8df171a9 predates the popover's put-away (story 945)

#### Use Case:
- **As someone** whose board crashed inside the system's handwriting reflow
- **I want to** have the log say what the reflow showed, where, and what had just touched it
- **so that** the fix goes at what put the reflow in that state instead of guessing at it

#### Acceptance Criteria:
- **Scenario:** The reflow comes, changes and goes
- **Given:** a board on paper on the iPad
- **When:** PaperKit's reflow of handwriting shows, moves, changes or goes
- **Then:** the log has one line saying what it is, where it sits, how many pictures it holds and how many have a place or size that is not a number, endless or empty, with what was selected, whether the system's popover was up and the last touch
- **And:** a touch beginning on a reflow view writes that line at once, before the touch ends, even while the reflow holds no picture yet
- **And:** a board with no reflow showing, or one that hasn't changed, writes no such line
- **And:** nothing I see changes

---

### User Story 1143:

- **Summary:** The log says what a moving touch began on and held, what the board changed under it, and whose ink moved
- **Status:** implemented (the logging alone) in [0fda3903](https://github.com/idvorkin/context-grabber/commit/0fda3903) and [47e93e64](https://github.com/idvorkin/context-grabber/commit/47e93e64); verified by host tests (`PaperProbeMoveAuditTests`; `just native-test`), the Mac build (`just native-build-mac`) and the iPad simulator (rung 2: `WhiteboardGroupTapUITests` and `WhiteboardTheirsTapUITests` pass, and their log shows a group drag beginning on PaperKit's `CanvasElementResizeView` with all 3 moved strokes held, Larry's, and moved alike; the reflow view sits idle at the sheet's size, without the focus); the iPad's own reflow drag is still owed
- **Issues:** bead context-grabber-eg7v (2026-11-22, the iPad log behind #1171: a finger drag moved 54 strokes, Larry's 52-stroke text and two of Igor's, with nothing selected, as a Larry turn landed; the drag began on PaperKit's handwriting reflow view, a popover of its own over exactly those strokes)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says what a moving touch held and what moved*

#### Use Case:
- **As someone** whose drag moved ink I never picked
- **I want to** have the log say what my touch landed on, what was selected then, whose ink moved and what the board or Larry changed while my finger was down
- **so that** the fix settles the cause instead of guessing at it

#### Acceptance Criteria:
- **Scenario:** A drag moves ink
- **Given:** a board with a kept text of Larry's and my writing under it
- **When:** a finger drag moves strokes
- **Then:** the change's line says how many of the moved strokes were selected when the touch began and how many weren't, how many are Larry's or Claude's and how many mine, their box, and the least and most each moved
- **And:** the touch's line says the kind of view it began on, how many strokes were selected then, whether PaperKit's handwriting tools were showing at its start and its end, each change the board put on the ink while it was down, by name, and how many turns came back meanwhile
- **And:** nothing I see changes

---

### User Story 1104:

- **Summary:** The log keeps each pen touch's path, and the stroke each gesture's verdict judged
- **Status:** implemented in [0a44faa3](https://github.com/idvorkin/context-grabber/commit/0a44faa3); verified by `just native-test` (host tests: the path's encoding, and Igor's real scratch-outs judged the same after it), the Mac build, and the iPad simulator (`WhiteboardScratchOutUITests` wrote `board_touch` paths and scratch lines with their zigzag, which `just touch-fixture` read back); the iPad's own Pencil paths are still owed
- **Issues:** bead context-grabber-y544 (whiteboard architecture review 2026-11-21, item 4): the log held only tallies, so a gesture bug on the iPad could not be replayed; bead context-grabber-x1zk waits on it
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A pen touch's path is in the log, and a pulled log replays on the Mac*

#### Use Case:
- **As someone** whose scratch-out, snap or margin hold did the wrong thing on the iPad
- **I want to** have the log keep the stroke I drew, not only how it was judged
- **so that** the fix is checked against my real stroke instead of a guess

#### Acceptance Criteria:
- **Scenario:** Igor draws with the Pencil
- **Given:** a board open on the iPad
- **When:** the Pencil lifts
- **Then:** the session log has a line with the touch's points in board points, their times, whether it ended or was called off, and the tool the picker showed
- **And:** a zigzag's scratch-out line, a margin hold's line and a snap's line each carry the stroke they judged
- **And:** the touch's own line does not go to the Cockpit with the board's log

---

### User Story 1105:

- **Summary:** A pulled iPad log becomes a host fixture of its gesture touches
- **Status:** implemented in [0a44faa3](https://github.com/idvorkin/context-grabber/commit/0a44faa3); verified by `just native-test` (host tests: a log's lines become cases, and every fixture's cases keep their verdicts) and the Mac build; `just touch-fixture` turned the iPad simulator's log into `Fixtures/touches/sim-scratch-out-2026-11-21.json`, the iPad and the Mac agreeing on all 3 scratch-outs
- **Issues:** bead context-grabber-y544
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A pen touch's path is in the log, and a pulled log replays on the Mac*

#### Use Case:
- **As someone** fixing a gesture bug Igor hit on the iPad
- **I want to** turn his pulled log into a fixture the host tests run
- **so that** the bug is settled in seconds on the Mac, and stays settled

#### Acceptance Criteria:
- **Scenario:** an agent replays a pulled log
- **Given:** a session log pulled from the iPad with pen paths in it
- **When:** the agent runs the fixture recipe on it
- **Then:** it writes a fixture of the log's scratch-outs, held lifts and margin tries, each with what the iPad decided and what the Mac decides, and names any case where they differ
- **And:** writing that is none of these stays out of the fixture unless every touch is asked for
- **And:** the host tests hold each case in the fixture to its expected verdict

---

### User Story 1090:

- **Summary:** A board whose first download from iCloud failed stays out of the list until its drawing arrives
- **Status:** implemented in [d4103e05](https://github.com/idvorkin/context-grabber/commit/d4103e05); verified by host tests (`BoardIndexTests`: another device's board, and this device's own board back after a reinstall, are listed only once their drawing is here) and the Mac build. The simulator has no iCloud account, so the CloudKit path waits for the iPhone and the iPad
- **Issues:** bead context-grabber-1jb4 (codex review 2026-11-21, finding 4): the list showed a board from iCloud before its drawing came down, so a failed first download opened it blank; on the iPad that drew it, back after a reinstall, the blank board took ink and would have gone up over iCloud's copy
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** opening the iPad's board on the iPhone, or my own boards on a reinstalled iPad
- **I want to** see a board in the list only once its drawing is on this device
- **so that** I never open a blank board by mistake, or draw over one and lose what iCloud holds

#### Acceptance Criteria:
- **Scenario:** The first download fails
- **Given:** iCloud lists a board this device has never had the drawing of
- **When:** the sync fails to bring its drawing down
- **Then:** the board isn't in the list, the list says boards aren't syncing, a link to it says its drawing hasn't come down, and the next good sync puts it in the list with its ink

---

### User Story 1109:

- **Summary:** A board's folds, cards and Larry's names reach every device with its ink
- **Issues:** bead context-grabber-cc75 step 2 (the architecture review, 2026-11-21: a board's meaning lived only on the iPad that drew it, so the iPhone, the Mac and a reinstalled iPad saw the ink without the folds, the cards, or the names Larry knows the strokes by)
- **Status:** not implemented; asks: bead context-grabber-cc75 step 2 (proposed, waiting on Igor's decision to sync the meaning and on the CloudKit production-schema deploy for TestFlight builds)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board's meaning goes through iCloud with its ink*

#### Use Case:
- **As someone** who draws on the iPad and looks at boards on the iPhone and the Mac
- **I want to** see a board on every device the way the iPad shows it, folds, headers, question cards and Larry's groups included
- **so that** a board means the same thing wherever I open it, and Larry's names for its strokes survive a reinstall

#### Acceptance Criteria:
- **Scenario:** The meaning arrives with the ink
- **Given:** a board drawn on the iPad with a folded header, a question card and a kept text of Larry's
- **When:** the iPhone syncs and I open the board there
- **Then:** the header is folded, the card and the text are there, and Larry's text keeps its name

---

### User Story 1117:

- **Summary:** A TestFlight build syncs every board's ink even before iCloud's production side knows a board's Larry thread
- **Status:** implemented in [2f20cc68](https://github.com/idvorkin/context-grabber/commit/2f20cc68); verified by host tests (`BoardThreadRefusalTests`: a refusal for invalid arguments on a board carrying a thread is retried without it, any other failure throws as before, and a board waiting only on its thread isn't sent again that launch; `just native-test`) and the Mac build (`just native-build-mac`); the simulator (rung 2) is owed (no iCloud account there, and it was wedged on 2026-11-22), and the refusal itself is seen only on a TestFlight build before the production schema is deployed. Whether listing boards with the thread asked for is refused there too is unobserved: a failed list logs its step and iCloud's words
- **Issues:** bead context-grabber-irm0 (after #1161: one board with a thread stopped the whole board sync on a TestFlight device, since iCloud's production side refuses a field it hasn't been given)
- **Spec:** [The conversation with Larry](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *TestFlight builds need one step from Igor first*

#### Use Case:
- **As someone** drawing on a TestFlight build of the iPad before Igor has deployed the board's thread to iCloud's production side
- **I want to** have my boards' ink still reach my other devices, threads or not
- **so that** one board that talked to Larry never stops every board from syncing

#### Acceptance Criteria:
- **Scenario:** iCloud refuses a board for its thread
- **Given:** a TestFlight build whose iCloud doesn't know the board's thread yet, and a board that talked to Larry
- **When:** the board syncs
- **Then:** it goes up once more without its thread, its ink and the boards after it reach the other devices, and the session log says the thread was left off, with what iCloud said

- **Scenario:** The rest of the launch
- **Given:** iCloud refused a thread earlier this launch
- **When:** the next sync runs
- **Then:** boards with new ink go up without their threads, a board with nothing new but its thread isn't sent again, and the next launch offers the threads again, so they go up once production has the field

---

### User Story 1112:

- **Summary:** Each picture the board sends Larry names its build and its own timings, so the Cockpit's board debug page can show them
- **Status:** implemented in [dbecb551](https://github.com/idvorkin/context-grabber/commit/dbecb551); verified by host tests (`BoardDebugTimingTests`: the mic clock's gaps with the mic closed and still open, dropped and hook words untimed, the cap; the message's build, `post` and `mic` events; the events batch's build; a queued picture without a build still reads), the Mac build (rung 1.5), and the same JSON run through the Cockpit's own `chat_store.clean_marks`, `whiteboard_events` and `board_debug.payload` on a scratch data dir (accepted; the turn row keeps `post` and `mic`; the page does not show them yet, the Cockpit's part). Not yet seen on the iPad (rung 3 owed: real mic timings). Numbered 1155 when it landed; renumbered to 1112 because story 1155 (bead `context-grabber-n8ab`) took that ID first, so commit dbecb551 names it 1155
- **Issues:** bead context-grabber-7zmj (Igor, 2026-11-22: "prioritize any missing logging for the debug page on the whiteboard")
- **Spec:** [Board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *What the board says about its own sending, for the debug page*

#### Use Case:
- **As someone** watching the Cockpit's board debug page while I write on the iPad
- **I want to** see which build sent each picture and how long the iPad took to draw, encode and send it
- **so that** a slow turn is pinned on the iPad or the Cockpit from the page, not guessed

#### Acceptance Criteria:
- **Scenario:** A picture handed to Larry
- **Given:** a board whose responder is Larry
- **When:** a picture goes to him, first or by *Retry*
- **Then:** its message names the app's commit and branch, and its events end with one `post` event saying when it left, its draw, encode, strokes and upload times, its size and the build; a *Retry* carries its own, once

---

### User Story 1101:

- **Summary:** Every picture a board sends Larry carries the board's name, so a renamed board renames its chat
- **Status:** implemented in [7741da9d](https://github.com/idvorkin/context-grabber/commit/7741da9d); verified by a host test (`BoardDebugTimingTests`: `board_title` on the chat message on a started thread and a new one, through the outbox's saved copy, and on the strokes; none for an unnamed picture) and the Mac build (rung 1.5). Not yet seen on the iPad with a live Cockpit (rung 3 owed: a rename retitling the chat). Numbered 1158 when it landed; renumbered to 1119 because open PR #1194 claims 1148–1158, so commit 7741da9d names it 1158; renumbered again to 1101 on 2026-11-22 because #1192 (story 1119, the open question's fold) merged first with the same number, and 1118 was taken by #1207 (the speech end)
- **Issues:** bead context-grabber-8rei (Igor via Larry, 2026-11-22: renamed boards should rename their chat and show on the debug page)
- **Spec:** [Board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *What the board says about its own sending, for the debug page*

#### Use Case:
- **As someone** who renames a board after it has started its chat with Larry
- **I want to** have the chat take the board's new name
- **so that** the chat list and the Cockpit's board debug page name the board I am looking at, not the day it began

#### Acceptance Criteria:
- **Scenario:** A board renamed after its first picture
- **Given:** a board whose chat with Larry has started under its old name
- **When:** I rename it and the next picture goes to Larry, by the hand-off, *Send to Larry* or a *Retry*, or from the outbox after waiting
- **Then:** that picture's message carries the board's name as it was when the picture was taken, and a Cockpit that reads it retitles the chat *Board: <name>*; one that doesn't ignores it

---

### User Story 1156:

- **Summary:** Words spoken to the board carry their mic-on-to-sent timing to the Cockpit's board debug page, never the words
- **Status:** implemented in [dbecb551](https://github.com/idvorkin/context-grabber/commit/dbecb551); verified by host tests (`BoardDebugTimingTests`: the mic clock's gaps with the mic closed and still open, dropped and hook words untimed, the cap; the message's build, `post` and `mic` events; the events batch's build; a queued picture without a build still reads), the Mac build (rung 1.5), and the same JSON run through the Cockpit's own `chat_store.clean_marks`, `whiteboard_events` and `board_debug.payload` on a scratch data dir (accepted; the turn row keeps `post` and `mic`; the page does not show them yet, the Cockpit's part). Not yet seen on the iPad (rung 3 owed: real mic timings)
- **Issues:** bead context-grabber-7zmj (Igor, 2026-11-22: "prioritize any missing logging for the debug page on the whiteboard")
- **Spec:** [Board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *What the board says about its own sending, for the debug page*

#### Use Case:
- **As someone** speaking to a board while watching the Cockpit's board debug page
- **I want to** see how long my spoken words took from mic on, to first words, to mic off, to text, to going with a picture
- **so that** a slow spoken turn is pinned on the mic, the recognizer or the send, not guessed

#### Acceptance Criteria:
- **Scenario:** Words spoken to the board
- **Given:** the mic open on a board with *Ask at my pauses* on
- **When:** I speak, close the mic, and the words go with the next picture
- **Then:** that picture's events carry one `mic` event with the mic on, first words, mic off, words ready and sent times and the gaps between them in milliseconds, and the count of characters, never the words

---

### User Story 1157:

- **Summary:** Events the board sends between turns name the build and carry any spoken-word timing waiting
- **Status:** implemented in [dbecb551](https://github.com/idvorkin/context-grabber/commit/dbecb551); verified by host tests (`BoardDebugTimingTests`: the mic clock's gaps with the mic closed and still open, dropped and hook words untimed, the cap; the message's build, `post` and `mic` events; the events batch's build; a queued picture without a build still reads), the Mac build (rung 1.5), and the same JSON run through the Cockpit's own `chat_store.clean_marks`, `whiteboard_events` and `board_debug.payload` on a scratch data dir (accepted; the turn row keeps `post` and `mic`; the page does not show them yet, the Cockpit's part). Not yet seen on the iPad (rung 3 owed: real mic timings)
- **Issues:** bead context-grabber-7zmj (Igor, 2026-11-22: "prioritize any missing logging for the debug page on the whiteboard")
- **Spec:** [Board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *What the board says about its own sending, for the debug page*

#### Use Case:
- **As someone** tapping Larry's controls on the board while watching the Cockpit's board debug page
- **I want to** see which build sent each batch of events, and the mic timing of words spoken before it
- **so that** the page never loses a build or a mic timing because it went between pictures

#### Acceptance Criteria:
- **Scenario:** Events sent between turns
- **Given:** a tap on one of Larry's controls sends the events at once, with a `mic` event waiting
- **When:** they go
- **Then:** the post names the build too, and the waiting `mic` event goes with them

---

### User Story 1237:

- **Summary:** A board idle for five minutes after writing is reviewed
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)): the note after a shortened idle. Not yet seen on the iPad (rung 3 owed): a real session, `board_review` why idle in the pulled log
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *When a review runs*

#### Use Case:
- **As someone** who writes on a board and moves on
- **I want to** have each session looked over without asking
- **so that** an insertion bug that hid or moved my writing doesn't go unnoticed

#### Acceptance Criteria:
- **Scenario:** Idle after writing
- **Given:** I wrote on a board
- **When:** five minutes pass with no step
- **Then:** the session is reviewed in the background, and writing is never held up

---

### User Story 1238:

- **Summary:** Closing a board reviews its session
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537), [813147df](https://github.com/idvorkin/context-grabber/commit/813147df), [29d52bdd](https://github.com/idvorkin/context-grabber/commit/29d52bdd) and [f7fc5a9f](https://github.com/idvorkin/context-grabber/commit/f7fc5a9f); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)): a board left right after writing shows its review on the next open, the review having finished after the board was gone. Not yet seen on the iPad (rung 3 owed)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *When a review runs*

#### Use Case:
- **As someone** who closes a board soon after writing
- **I want to** have that session reviewed too
- **so that** a short session still gets looked at

#### Acceptance Criteria:
- **Scenario:** Closing
- **Given:** a session with at least one step of mine
- **When:** I close the board
- **Then:** the session is reviewed, and a session cut short by the app closing is reviewed the next time the board opens

---

### User Story 1312:

- **Summary:** A session is reviewed once, however the board closes
- **Status:** implemented in [526515bc](https://github.com/idvorkin/context-grabber/commit/526515bc); verified by host tests (`BoardReviewDiskTests`: a save landing after the review leaves nothing pending, a pending session already reviewed isn't reviewed again, a cut-short session is still reviewed on the next open, one session's clear leaves the next one's pending) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)): a review started on close shows on the next open. Not yet seen on the iPad (rung 3 owed)
- **Issues:** context-grabber-04ks (no-mistakes review round 2 on PR #1379: a save of the session in flight could land after the close cleared it)
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *When a review runs*

#### Use Case:
- **As someone** who closes a board right after writing
- **I want to** have that session reviewed exactly once
- **so that** the next open never shows me the same review a second time

#### Acceptance Criteria:
- **Scenario:** A save still on its way at close
- **Given:** a session of mine whose save was on its way as I closed the board
- **When:** the close's review has run and I open the board again
- **Then:** that session is not reviewed again, and nothing about it shows twice

---

### User Story 1297:

- **Summary:** A review finished after the board closed still shows on its next open
- **Status:** implemented in [b755b220](https://github.com/idvorkin/context-grabber/commit/b755b220); verified by host tests (`BoardReviewDiskTests`: a note shown late for an earlier review leaves a later review unseen). Not yet seen on the iPad (rung 3 owed)
- **Issues:** context-grabber-om6m (no-mistakes review round 2 on PR #1379: a note shown late could clear a later review's unseen mark)
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *When a review runs*

#### Use Case:
- **As someone** who closes a board just after an earlier review's note showed
- **I want to** still see the review of the session I just closed
- **so that** no finding is lost because two reviews finished close together

#### Acceptance Criteria:
- **Scenario:** An earlier note shown late
- **Given:** a session reviewed after I closed the board, and an earlier review's note shown just before
- **When:** I open the board again
- **Then:** the later review's note shows

---

### User Story 1239:

- **Summary:** A board only looked at is not reviewed
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537), [813147df](https://github.com/idvorkin/context-grabber/commit/813147df), [29d52bdd](https://github.com/idvorkin/context-grabber/commit/29d52bdd) and [f7fc5a9f](https://github.com/idvorkin/context-grabber/commit/f7fc5a9f); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *When a review runs*

#### Use Case:
- **As someone** who opens a board just to read it
- **I want to** have nothing reviewed
- **so that** the review never speaks about sessions with nothing of mine in them

#### Acceptance Criteria:
- **Scenario:** Looking only
- **Given:** a board opened with no stroke, choice or keep of mine
- **When:** it closes
- **Then:** no review runs and nothing shows

---

### User Story 1240:

- **Summary:** No review row in the Board menu: reviews run on idle and close only
- **Status:** implemented in [0a6d24b4](https://github.com/idvorkin/context-grabber/commit/0a6d24b4); verified by host tests (`BoardReviewRecorderTests`, `BoardReviewTests`) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)): the Board menu has no review row
- **Issues:** Igor, 2026-11-24 (via Larry): "NO 'Review this session' row; reviews run on idle and close only"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *When a review runs*, *Decisions* 7

#### Use Case:
- **As someone** whose Board menu has room for no more
- **I want to** have reviews happen on their own
- **so that** I never have to ask for one, and the menu stays short

#### Acceptance Criteria:
- **Scenario:** The Board menu
- **Given:** a board with a session of writing
- **When:** I open the Board menu
- **Then:** there is no review row, and the session is reviewed after idle or when the board closes

---

### User Story 1241:

- **Summary:** A review never changes the board
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *Goals*

#### Use Case:
- **As someone** writing while a review runs
- **I want to** have the board untouched by it
- **so that** a review can never become a bug of its own

#### Acceptance Criteria:
- **Scenario:** Reviewing
- **Given:** a session reviewed
- **When:** the review finishes
- **Then:** the board, its Undo stack and its folds are as they were before it

---

### User Story 1242:

- **Summary:** A clean review shows nothing
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)): a clean session after idle shows no note; no review on demand since [0a6d24b4](https://github.com/idvorkin/context-grabber/commit/0a6d24b4)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *What Igor sees*; *Decisions*, 6

#### Use Case:
- **As someone** whose sessions are almost always fine
- **I want to** see nothing when nothing went wrong
- **so that** the board stays quiet

#### Acceptance Criteria:
- **Scenario:** Clean
- **Given:** a session where every check is clean or as designed
- **When:** its automatic review finishes
- **Then:** no note shows

---

### User Story 1243:

- **Summary:** A finding puts a quiet note on the board
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)): opened, or his next stroke, puts it away
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *What Igor sees*

#### Use Case:
- **As someone** whose writing a step mishandled
- **I want to** see a small note, never an alert
- **so that** I can look when I'm ready

#### Acceptance Criteria:
- **Scenario:** Something to look at
- **Given:** a review with one bug or unclear finding
- **When:** it finishes
- **Then:** the board's corner says *Reviewed · 1 to look at*, as designed findings don't count, and the note goes once opened or with my next stroke

---

### User Story 1244:

- **Summary:** Each finding is listed and copyable
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df); verified by `BoardReviewTests` (the copy's text) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5)) (*Copy*)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *What Igor sees*

#### Use Case:
- **As someone** who wants to report what the review found
- **I want to** copy a finding with its step and evidence
- **so that** I can file it without reading the log

#### Acceptance Criteria:
- **Scenario:** Copying
- **Given:** the note shows
- **When:** I open it and copy a finding
- **Then:** the text names the check, the verdict, the step's time, what it was and who started it, the evidence, the board, the session and the build

---

### User Story 1245:

- **Summary:** Show me draws the step's outlines, erased ink included
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df): *Show me* draws the record's outlines before and after the step, not playback (Igor, 2026-11-24: outlines are fine); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me) and the iPad simulator (`WhiteboardReviewUITests`, iPad Pro 11-inch (M5))
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *What Igor sees*; *Decisions*, 5

#### Use Case:
- **As someone** looking at a finding
- **I want to** see the board just before and just after its step
- **so that** I can judge it with my own eyes

#### Acceptance Criteria:
- **Scenario:** Show me
- **Given:** a finding about a step that erased ink
- **When:** I tap *Show me*
- **Then:** the step is drawn as outlines behind a Before/After switch: before, with the erased ink as it was; after, with the ink the finding names marked

---

### User Story 1246:

- **Summary:** Answering an unclear finding
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me). The buttons are not yet tapped by a UI test
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *What Igor sees*; *False positives*

#### Use Case:
- **As someone** whom the review asks whether I meant a move
- **I want to** answer *I meant that* or *Not what I meant*
- **so that** Larry and the review learn what I meant

#### Acceptance Criteria:
- **Scenario:** Answering
- **Given:** an unclear finding in the list
- **When:** I answer it
- **Then:** it leaves the note, stays in the list marked with my answer, and my answer goes to Larry with the findings

---

### User Story 1247:

- **Summary:** Larry gets the findings with the board's next picture
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537), [813147df](https://github.com/idvorkin/context-grabber/commit/813147df) and [8aceda0d](https://github.com/idvorkin/context-grabber/commit/8aceda0d): the words go as a `board_review` event with the next picture's events, the whole event kept at or under 6 KB encoded, well inside the Cockpit's 8 KB per event, and saying how many lines it cut (Larry, 2026-11-23: the Cockpit keeps unknown event types); verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *How Larry gets findings*; *Decisions*, 4

#### Use Case:
- **As someone** whose coach watches the board
- **I want to** have Larry see each session's findings
- **so that** he can raise them with me

#### Acceptance Criteria:
- **Scenario:** To Larry
- **Given:** a reviewed session
- **When:** the board's next picture goes to Larry
- **Then:** it carries the counts by check and verdict and each bug or unclear finding as its copyable text, or one line for a clean session

- **Scenario:** A long review
- **Given:** a reviewed session whose words would run past what one event to Larry carries
- **When:** the board's next picture goes to Larry
- **Then:** the event stays under 6 KB as sent, its words end with a line saying they were cut short, and it says how many lines were cut; a review that fits says nothing was cut

---

### User Story 1248:

- **Summary:** A session's record stays on its device for 14 days
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df): Application Support/board-reviews, pruned at 14 days, removed with the board; verified by host tests (`BoardReviewRecorderTests`: a board opening with ink, erase, Undo and Redo, folds, paste, Larry's ops, a drop's room, owners put apart, each from the strokes as the board hands them over; the note, answers, Larry's event under 6 KB encoded with its `cut`, Show me) (a record read back) and the Mac build
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *What a session is*; *Decisions*, 2

#### Use Case:
- **As someone** whose writing is in each record, as geometry
- **I want to** keep the record on the device that made it
- **so that** my writing goes nowhere new

#### Acceptance Criteria:
- **Scenario:** Keeping
- **Given:** a record made on the iPad
- **When:** 14 days pass, or its board is deleted
- **Then:** the record is deleted, and it never synced to another device

---

### User Story 1249:

- **Summary:** A finding never files anything by itself
- **Status:** implemented in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df): nothing files; verified by reading (the review only logs, shows and sends to Larry)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *Decisions*, 3

#### Use Case:
- **As someone** who decides what is worth fixing
- **I want to** have nothing filed for me
- **so that** beads and issues stay the ones I meant

#### Acceptance Criteria:
- **Scenario:** A bug found
- **Given:** a review with a bug
- **When:** it finishes
- **Then:** no bead or GitHub issue is filed; the finding can be copied or sent to Larry

---

### User Story 1250:

- **Summary:** New writing hidden inside a fold is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 1

#### Use Case:
- **As someone** writing near a folded header
- **I want to** be told when new ink went straight into a fold
- **so that** I never lose writing I can't see

#### Acceptance Criteria:
- **Scenario:** Into a fold
- **Given:** a step that only added ink
- **When:** the ink is hidden the moment it lands, or a fold holds it with no fold step
- **Then:** the review calls it a bug with the step, the header, the strokes and the fold's count before and after

---

### User Story 1251:

- **Summary:** Writing the board placed on ink is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 2

#### Use Case:
- **As someone** whose board places pastes, drops and Larry's marks
- **I want to** be told when one landed on ink that showed
- **so that** nothing I wrote is covered

#### Acceptance Criteria:
- **Scenario:** Under ink
- **Given:** a paste, drop, keep or text of Larry's
- **When:** its ink crosses ink that showed before, past the tolerance, and the rules' room didn't open
- **Then:** the review calls it a bug; my own pen writing over ink is never a finding

---

### User Story 1318:

- **Summary:** A drop I dragged myself that only grazes ink is as designed
- **Status:** implemented in [0a798cc5](https://github.com/idvorkin/context-grabber/commit/0a798cc5); verified by host tests (`BoardReviewTests`: check2-drag-slight and check2-drag-tall as designed, check2-larry-slight and check2-drop-no-room still bugs, every golden). The wasm build runs the same fixtures (`test-board-wasm.mjs`), not run on this Mac (no wasm SDK)
- **Issues:** Larry, 2026-11-24: three of five real check-2 findings were overlaps of a few points on drops Igor dragged himself
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 2

#### Use Case:
- **As someone** who drags my own writing into place by hand
- **I want to** have a drop that only grazes nearby ink seen as meant
- **so that** the review only calls a bug when the board covered my writing

#### Acceptance Criteria:
- **Scenario:** A drop by hand that grazes
- **Given:** I drag ink and drop it overlapping other ink by under 4 pt, or under 15% of the shorter box's height
- **When:** the session is reviewed
- **Then:** check 2 calls it as designed, while anything Larry placed overlapping by the same amount is still a bug

---

### User Story 1252:

- **Summary:** My ink moved without my aim is a bug, or asked about
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 3

#### Use Case:
- **As someone** whose strokes should move only when I move them
- **I want to** be told when they moved anyway
- **so that** I trust the board with my writing

#### Acceptance Criteria:
- **Scenario:** Moved
- **Given:** a step not aimed at my strokes
- **When:** they move, or a push moves them other than the rules say
- **Then:** the review calls it a bug, or *unclear* when the system moved them from a handle with no selection of mine

---

### User Story 1253:

- **Summary:** Both owners' ink left moved together is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 4

#### Use Case:
- **As someone** sharing a board with Larry
- **I want to** be told when one step moved his ink and mine together
- **so that** the owners-apart rule is checked every session

#### Acceptance Criteria:
- **Scenario:** Both owners
- **Given:** a step I didn't aim at both
- **When:** ink of both owners stays moved after it settles
- **Then:** the review calls it a bug; owners put apart by the rules read *as designed* (story 1145)

---

### User Story 1254:

- **Summary:** A fold that swallowed newer ink is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 5

#### Use Case:
- **As someone** who writes under a folded header
- **I want to** be told when folding again hid that writing
- **so that** story 1231 is checked every session

#### Acceptance Criteria:
- **Scenario:** Refolding
- **Given:** ink written under a header while it was folded
- **When:** a fold step hides it
- **Then:** the review calls it a bug with the extra ink's ids, times and box
- **And:** ink written into the section while it was open joins it and is no finding

---

### User Story 1255:

- **Summary:** An Undo that didn't put the board back is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 6

#### Use Case:
- **As someone** who undoes a step
- **I want to** be told when the board isn't as it was
- **so that** Undo stays trustworthy

#### Acceptance Criteria:
- **Scenario:** Undo
- **Given:** a step undone
- **When:** the ink or folds that step touched differ from before it past the tolerance, or the Undo took back another step
- **And:** ink that arrived between the step and its Undo is not counted
- **Then:** the review calls it a bug naming what differs

---

### User Story 1256:

- **Summary:** A selection lost with nothing of mine is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 7

#### Use Case:
- **As someone** who selected ink
- **I want to** be told when the selection vanished on its own
- **so that** I'm never left acting on nothing

#### Acceptance Criteria:
- **Scenario:** Lost
- **Given:** a selection of mine
- **When:** it goes with nothing of mine to end it and doesn't come back
- **Then:** the review calls it a bug; one taken and put back at once reads *as designed*

---

### User Story 1257:

- **Summary:** Keeping a mark that changed my pen is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 8

#### Use Case:
- **As someone** who keeps Larry's marks mid-writing
- **I want to** be told when a keep left me a different pen
- **so that** I keep writing with the pen I chose

#### Acceptance Criteria:
- **Scenario:** Pen
- **Given:** the pen before a keep
- **When:** the pen after differs with no pen picked between
- **Then:** the review calls it a bug, or at most *unclear* where the surface knows the pen only approximately

---

### User Story 1258:

- **Summary:** A kept mark drawn cut or in the wrong colour is a bug
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*, 9

#### Use Case:
- **As someone** who keeps Larry's marks
- **I want to** be told when one drew partly or in black
- **so that** his marks show as he made them

#### Acceptance Criteria:
- **Scenario:** Drawn
- **Given:** a kept mark
- **When:** after the board's redraws it is missing part, or in another colour
- **Then:** the review calls it a bug; one a redraw healed reads *as designed*

---

### User Story 1259:

- **Summary:** Moves within half a point, and edges that only touch, are no finding
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*

#### Use Case:
- **As someone** reviewed on the iPad and the web
- **I want to** have arithmetic noise never called a bug
- **so that** both surfaces agree

#### Acceptance Criteria:
- **Scenario:** Tolerance
- **Given:** a stroke moved 0.4 pt, or two boxes that share an edge
- **When:** the session is reviewed
- **Then:** neither is a finding

---

### User Story 1260:

- **Summary:** A check a surface can't see reads not checked or approximate
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The checks*; *Larry's answer*

#### Use Case:
- **As someone** reading a review
- **I want to** know what it couldn't see
- **so that** a check it skipped never reads as clean

#### Acceptance Criteria:
- **Scenario:** Not seen
- **Given:** a record with no observation for a check, or only an approximate one
- **When:** it is reviewed
- **Then:** that check reads *not checked*, or *approximate*, never clean, and an approximate check never calls a bug

---

### User Story 1261:

- **Summary:** The same session gives the same findings on the iPad and the web board
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *The iPad and the web board, through one core*

#### Use Case:
- **As someone** who writes on the iPad and the web board
- **I want to** get the same review wherever a session is replayed
- **so that** a finding is a finding whichever surface found it

#### Acceptance Criteria:
- **Scenario:** Replayed
- **Given:** one session's record
- **When:** it is reviewed on the Mac and through the web board's rules
- **Then:** the findings match verdict for verdict

---

### User Story 1262:

- **Summary:** The 2026-11-23 iPad sessions review to the manual verdict
- **Status:** the review's checks implemented in [8d32af77](https://github.com/idvorkin/context-grabber/commit/8d32af77) (bead context-grabber-8ao5.1); verified by host tests (`BoardReviewTests`: every fixture's findings and golden, the same report twice) and the wasm build (`test-board-wasm.mjs`: `bw_review` gives every golden, swift 6.4.3 wasm SDK in Docker). The iPad runs them off the main actor on values alone in [e5ee2537](https://github.com/idvorkin/context-grabber/commit/e5ee2537) and [813147df](https://github.com/idvorkin/context-grabber/commit/813147df)
- **Issues:** Igor, 2026-11-23: "That design is approved, and it should work on the web board as well"
- **Spec:** [Reviewing each writing session](../superpowers/specs/2026-11-23-board-interaction-review-design.md), *Acceptance criteria*

#### Use Case:
- **As someone** who reviewed those sessions by hand
- **I want to** have the review reach the same answer
- **so that** the review is trusted on real sessions

#### Acceptance Criteria:
- **Scenario:** Real sessions
- **Given:** the two iPad sessions of 2026-11-22 and 2026-11-23, scrubbed
- **When:** they are reviewed
- **Then:** no bug; the 05:15 reflow *as designed* (story 1145); the 05:28 knob stretch *unclear*; the keeps clean; the selections lost to the popover *as designed*

### User Story 1293:

- **Summary:** New ink always lands on a shared board, once
- **Status:** the rule in BoardCore and `bw_store_clash` (interface 22) in [72d3c0cb](https://github.com/idvorkin/context-grabber/commit/72d3c0cb), restore and Larry's other cases in [60014ea8](https://github.com/idvorkin/context-grabber/commit/60014ea8), the review's tombstone, in-batch and ahead fixes in [2178e4bc](https://github.com/idvorkin/context-grabber/commit/2178e4bc); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`, the review fixes included) and the wasm run on Larry's VM (`test-board-wasm.mjs` 324 passed, 0 failed, abi 22, on the merged code at ea45a2e6, review fixes included; wasm sha 58524ac8); not yet used by a device or the Cockpit
- **Issues:** bead context-grabber-t12b; Igor, 2026-11-24: boards live in the Cockpit, any of iPad, web and Mac draws
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Two devices, one board, apart*

#### Use Case:
- **As someone** drawing on a board that another device also draws on
- **I want to** have my new ink land whatever the other device did meanwhile, and never twice
- **so that** nothing I wrote is lost or doubled when the two meet

#### Acceptance Criteria:
- **Scenario:** Ink added on two devices apart
- **Given:** a board the web changed after the iPad last saw it
- **When:** the iPad's new strokes, one of them a name the board already has, reach the Cockpit
- **Then:** the new names land as one new revision, and the name it already has is refused as already there, out loud

### User Story 1322:

- **Summary:** A change to something changed since is refused by name
- **Status:** the rule in BoardCore and `bw_store_clash` (interface 22) in [72d3c0cb](https://github.com/idvorkin/context-grabber/commit/72d3c0cb), restore and Larry's other cases in [60014ea8](https://github.com/idvorkin/context-grabber/commit/60014ea8), the review's tombstone, in-batch and ahead fixes in [2178e4bc](https://github.com/idvorkin/context-grabber/commit/2178e4bc); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`, the review fixes included) and the wasm run on Larry's VM (`test-board-wasm.mjs` 324 passed, 0 failed, abi 22, on the merged code at ea45a2e6, review fixes included; wasm sha 58524ac8); not yet used by a device or the Cockpit
- **Issues:** bead context-grabber-t12b
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Two devices, one board, apart*

#### Use Case:
- **As someone** who moved or erased ink while another device changed it too
- **I want to** be told which thing clashed and who changed it, while the rest of my changes land
- **so that** no change is lost silently and I know what to look at

#### Acceptance Criteria:
- **Scenario:** A move over a stroke the web moved since
- **Given:** a stroke the web moved after the iPad last saw the board, and another the web left alone
- **When:** the iPad's batch moves the first and erases the second
- **Then:** the erase lands, and the move is refused naming the stroke, the web, and when it moved it

### User Story 1323:

- **Summary:** Nothing lands on a deleted board
- **Status:** the rule in BoardCore and `bw_store_clash` (interface 22) in [72d3c0cb](https://github.com/idvorkin/context-grabber/commit/72d3c0cb), restore and Larry's other cases in [60014ea8](https://github.com/idvorkin/context-grabber/commit/60014ea8), the review's tombstone, in-batch and ahead fixes in [2178e4bc](https://github.com/idvorkin/context-grabber/commit/2178e4bc); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`, the review fixes included) and the wasm run on Larry's VM (`test-board-wasm.mjs` 324 passed, 0 failed, abi 22, on the merged code at ea45a2e6, review fixes included; wasm sha 58524ac8); not yet used by a device or the Cockpit
- **Issues:** bead context-grabber-t12b; Igor, 2026-11-24: deleted boards are kept forever, and refused ink can become a new board
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Deleting*

#### Use Case:
- **As someone** whose board was deleted on another device while I was still drawing
- **I want to** have my late ink refused with when and where the board was deleted
- **so that** a delete is never undone behind my back, and I can keep my ink as a new board

#### Acceptance Criteria:
- **Scenario:** Ink sent to a board deleted meanwhile
- **Given:** a board the web deleted after the iPad last saw it
- **When:** the iPad's new strokes and a rename reach the Cockpit
- **Then:** none of them lands, the revision stays, and each is refused as deleted with when and where

### User Story 1326:

- **Summary:** A header on a shared board is a thing of its own
- **Status:** interface 23 in [60ac2271](https://github.com/idvorkin/context-grabber/commit/60ac2271); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`); the wasm run on Larry's VM pending; not yet used by a device or the Cockpit
- **Issues:** cockpit-8kh; review of Larry's board store spec, point Q2
- **Spec:** [Board rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), *Interface 23*

#### Use Case:
- **As someone** who makes a header on a board another device also draws on
- **I want to** have the header land as one new thing over its strokes
- **so that** a header made twice is caught, and a header over strokes changed since is refused by name

#### Acceptance Criteria:
- **Scenario:** A header whose name the board already has
- **Given:** a board that already has a header of that name
- **When:** the iPad's batch makes the header again over its strokes
- **Then:** the header's name is refused as already there, and the answer names exactly which of its names landed

### User Story 1327:

- **Summary:** A board is deleted however the store records it
- **Status:** interface 23 in [60ac2271](https://github.com/idvorkin/context-grabber/commit/60ac2271); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`); the wasm run on Larry's VM pending; not yet used by a device or the Cockpit
- **Issues:** cockpit-8kh; review of Larry's board store spec, points 1 and 7
- **Spec:** [Board rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), *Interface 23*

#### Use Case:
- **As someone** whose board was deleted on another device
- **I want to** have my late ink refused whether the store marked the board deleted or erased its own entry
- **so that** ink never lands on a deleted board because of how the delete was stored

#### Acceptance Criteria:
- **Scenario:** Ink sent to a board whose own entry was erased
- **Given:** a board the store recorded as deleted only by erasing its own entry
- **When:** the iPad's new strokes, and an undo bringing ink back, reach the Cockpit
- **Then:** none of them lands, and each is refused as deleted with when and where

### User Story 1328:

- **Summary:** A change that also adds says which of its names landed
- **Status:** interface 23 in [60ac2271](https://github.com/idvorkin/context-grabber/commit/60ac2271); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`); the wasm run on Larry's VM pending; not yet used by a device or the Cockpit
- **Issues:** cockpit-8kh; review of Larry's board store spec, point 3
- **Spec:** [Board rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), *Interface 23*

#### Use Case:
- **As the** Cockpit's store applying a device's batch
- **I want to** know per change exactly which names landed
- **so that** a group whose own name was refused adds nothing new, while its strokes still change

#### Acceptance Criteria:
- **Scenario:** A group whose name the board already has
- **Given:** a board with a group of that name, and strokes nobody changed since the iPad saw them
- **When:** the iPad's batch groups those strokes under that name
- **Then:** the strokes' change lands, the group's name is refused as already there, and the answer lists only the strokes as landed for that change

### User Story 1329:

- **Summary:** A broken record on a shared board is refused out loud
- **Status:** interface 23 in [60ac2271](https://github.com/idvorkin/context-grabber/commit/60ac2271); verified by host tests (`BoardStoreClashTests`, `WebStoreClashTests`); the wasm run on Larry's VM pending; not yet used by a device or the Cockpit
- **Issues:** cockpit-8kh; review of Larry's board store spec, gap "the wasm silently drops a thing row"
- **Spec:** [Board rules on the web](../superpowers/specs/2026-11-22-board-rules-on-the-web-design.md), *Interface 23*

#### Use Case:
- **As the** Cockpit's store asking the shared rule about a batch
- **I want to** be told when a thing's record lacks its revision or who changed it
- **so that** a broken record is fixed instead of letting the same name be added twice

#### Acceptance Criteria:
- **Scenario:** A thing with no revision
- **Given:** a board whose record for one stroke has no revision
- **When:** a batch is checked against it
- **Then:** the answer is an error naming that stroke, and nothing is decided

### User Story 1330:

- **Summary:** A board drawn on offline opens with my unsent ink
- **Status:** the cache and queue in BoardCore (`BoardStoreCache`) in [ecab77a9](https://github.com/idvorkin/context-grabber/commit/ecab77a9); verified by host tests (`BoardStoreCacheTests`); not yet used by the app, which gets it behind the rollout setting (off by default); the fake Cockpit's store routes it is built against in [a085de7d](https://github.com/idvorkin/context-grabber/commit/a085de7d), checked by `test-fake-cockpit-store.py`
- **Issues:** bead context-grabber-t12b; cockpit-8kh (Larry's store spec 2bf00b04, sections 3 and 6)
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Offline: each device's copy and its unsent changes*

#### Use Case:
- **As someone** drawing on the iPad with no network
- **I want to** see everything I drew on the board at once
- **so that** going offline never hides ink I drew

#### Acceptance Criteria:
- **Scenario:** A board with two unsent saves opens
- **Given:** a board the iPad last saw at one version, and two saves drawn on it offline
- **When:** the board opens
- **Then:** it shows both saves' ink on the last-seen copy

### User Story 1301:

- **Summary:** Unsent saves go up oldest first, one at a time
- **Status:** the cache and queue in BoardCore (`BoardStoreCache`) in [ecab77a9](https://github.com/idvorkin/context-grabber/commit/ecab77a9); verified by host tests (`BoardStoreCacheTests`); not yet used by the app, which gets it behind the rollout setting (off by default)
- **Issues:** bead context-grabber-t12b; cockpit-8kh (Larry's store spec 2bf00b04, sections 3 and 6)
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Offline: each device's copy and its unsent changes*

#### Use Case:
- **As someone** who drew on the iPad with no network
- **I want to** have my saves reach the Cockpit in the order I drew them
- **so that** going offline never scrambles my ink

#### Acceptance Criteria:
- **Scenario:** The network comes back with two saves waiting
- **Given:** two saves drawn offline on a board the iPad last saw at one version
- **When:** the network comes back
- **Then:** the first save goes up alone at that version, and the second goes up only after the first's answer, at the version that answer left

### User Story 1331:

- **Summary:** A save whose answer was lost lands once
- **Status:** the cache and queue in BoardCore (`BoardStoreCache`) in [ecab77a9](https://github.com/idvorkin/context-grabber/commit/ecab77a9); verified by host tests (`BoardStoreCacheTests`); not yet used by the app; the fake Cockpit's store routes it is built against in [a085de7d](https://github.com/idvorkin/context-grabber/commit/a085de7d), checked by `test-fake-cockpit-store.py`
- **Issues:** bead context-grabber-t12b; cockpit-8kh
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Offline: each device's copy and its unsent changes*

#### Use Case:
- **As someone** whose iPad lost the network mid-save
- **I want to** have that save sent again exactly as it was
- **so that** it lands once, never twice and never as a different change

#### Acceptance Criteria:
- **Scenario:** The answer never came back
- **Given:** a save sent once whose answer was lost, and more ink drawn since
- **When:** the iPad tries again
- **Then:** it sends the same save under the same name at the same version, the newer ink stays waiting, and a Cockpit that answers "couldn't look at it" leaves the save queued

### User Story 1332:

- **Summary:** My unsent change to something another hand changed meanwhile is refused on the device, by name
- **Status:** the cache and queue in BoardCore (`BoardStoreCache`) in [ecab77a9](https://github.com/idvorkin/context-grabber/commit/ecab77a9); verified by host tests (`BoardStoreCacheTests`); not yet used by the app; the fake Cockpit's store routes it is built against in [a085de7d](https://github.com/idvorkin/context-grabber/commit/a085de7d), checked by `test-fake-cockpit-store.py`
- **Issues:** bead context-grabber-t12b; cockpit-8kh
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Offline: each device's copy and its unsent changes*, *Two devices, one board, apart*

#### Use Case:
- **As someone** who moved a stroke offline that the web moved meanwhile
- **I want to** be told on the iPad which change was refused and who made the other one, and see the stroke where they left it
- **so that** no clash slips through just because my iPad caught up first

#### Acceptance Criteria:
- **Scenario:** Catching up over a clash
- **Given:** an unsent move of a stroke and an unsent erase of another, and the web moved the first since the iPad's version
- **When:** the iPad catches up before sending
- **Then:** the move is refused on the iPad with a note naming the stroke, the web and when, the stroke shows where the web put it, and only the erase goes up, at the caught-up version

### User Story 1333:

- **Summary:** Ink refused for a deleted board waits for my answer
- **Status:** the cache and queue in BoardCore (`BoardStoreCache`) in [ecab77a9](https://github.com/idvorkin/context-grabber/commit/ecab77a9), and a delete Larry undid in the same catch-up sets nothing aside in [26f64e42](https://github.com/idvorkin/context-grabber/commit/26f64e42); verified by host tests (`BoardStoreCacheTests`); not yet used by the app; the fake Cockpit's store routes it is built against in [a085de7d](https://github.com/idvorkin/context-grabber/commit/a085de7d), checked by `test-fake-cockpit-store.py`
- **Issues:** bead context-grabber-t12b; Igor, 2026-11-24: refused ink can become a new board
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Deleting*, *Offline: each device's copy and its unsent changes*

#### Use Case:
- **As someone** whose board was deleted on the web while I drew on it offline
- **I want to** keep that ink as a new board, or let it go, my choice
- **so that** a delete stands and my ink isn't thrown away behind my back

#### Acceptance Criteria:
- **Scenario:** Keep my ink as a new board
- **Given:** strokes refused because the board was deleted
- **When:** I pick *Keep my ink as a new board*
- **Then:** a new board named like the old one with "(kept ink)" after it, on the old paper, gets exactly those strokes as its first save; and dismissing instead drops them

### User Story 1334:

- **Summary:** The iPad knows when it has seen every change, and fetches when it hasn't
- **Status:** the cache and queue in BoardCore (`BoardStoreCache`) in [ecab77a9](https://github.com/idvorkin/context-grabber/commit/ecab77a9); verified by host tests (`BoardStoreCacheTests`); not yet used by the app; the fake Cockpit's store routes it is built against in [a085de7d](https://github.com/idvorkin/context-grabber/commit/a085de7d), checked by `test-fake-cockpit-store.py`
- **Issues:** bead context-grabber-t12b; cockpit-8kh (Larry's store spec, section 6, from the Mac's review point 5)
- **Spec:** [Boards live in the Cockpit](../superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md), *Offline: each device's copy and its unsent changes*

#### Use Case:
- **As someone** drawing on a board that the web and Larry change too
- **I want to** have my iPad fetch whatever it missed before taking a save's answer as the whole story
- **so that** it never shows a board missing someone else's change

#### Acceptance Criteria:
- **Scenario:** A save that landed nothing on a board that moved on
- **Given:** a save whose every change was refused, answered with a version one past the iPad's
- **When:** the answer comes back
- **Then:** the iPad doesn't call itself caught up: it fetches the change it missed, shows it, and only then sends the next save
