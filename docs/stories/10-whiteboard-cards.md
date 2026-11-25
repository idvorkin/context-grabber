# The whiteboard: Question cards

Larry's questions about a board, landing on it as cards to answer. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 880:

- **Summary:** Larry's question about a board lands on it as a card
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests`: `testLarrysQuestionMarkLandsAtHisPlaceByTheRowsFrame`, `testACardIsOncePerAskAndInsideThePage`, `testAnErasedCardsMarkNeverLandsAgain`; `just test`); and on the simulator (`WhiteboardQuestionUITests` 1/1, `scripts/native/test-whiteboard-ui.sh`); not yet seen on the iPad or against the real Larry
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Where a card comes from*

#### Use Case:
- **As someone** drawing with Larry who has a question about the drawing
- **I want to** see his question on the board, where he put it
- **so that** I answer it looking at what it is about, not in another screen

#### Acceptance Criteria:
- **Scenario:** Larry asks on the board
- **Given:** a board I draw on, with its thread to Larry
- **When:** his reply on the thread holds a question for one of his asks
- **Then:** a card *? \<question> ···* lands where he put it, inside the page, once for that ask, and the session log says a card landed from Larry

---

### User Story 881:

- **Summary:** An open ask about a board shows on it when it opens
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests`: `testAnOpenAskNamesTheBoardByItsThreadOrInItsContext`, `testOpenAsksLandAtTheTopOfTheScreenOneUnderAnother`; `just test`); not yet seen on the simulator or the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Where a card comes from*

#### Use Case:
- **As someone** coming back to a board Larry has a question about
- **I want to** find the question on the board
- **so that** a decision about the drawing isn't only in the Inbox

#### Acceptance Criteria:
- **Scenario:** The board opens with an ask naming it
- **Given:** an open ask whose thread is the board's thread, or whose context names the thread or the board, and no card for it
- **When:** I open the board
- **Then:** its card lands at the top of what is on screen, by the left margin, and several land one under another

---

### User Story 882:

- **Summary:** Answer a question card from the board
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e), with Chat's decision card in the popup and an answer in my own words added to its verbs. Verified by host tests (`WhiteboardQuestionsTests`: `testAnAnswerLeavesTheQuestionOverTheAnswer`, `testOwnWordsAreTheInboxsFreeTextAnswer`; `ChatDecisionsTests` for the option's answer; `just test`); and on the simulator (`WhiteboardQuestionUITests.testLarrysQuestionLandsAnswersAndFolds`, 1/1); not yet seen on the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Answering*, *When it fails*

#### Use Case:
- **As someone** with Larry's question on my board
- **I want to** tap it and answer, with an option or in my own words
- **so that** Larry has my decision exactly as if I had answered in the Inbox

#### Acceptance Criteria:
- **Scenario:** I answer a card
- **Given:** an open card on the board
- **When:** I tap it and tap an option, or write my own answer and tap *Send*
- **Then:** the Cockpit takes *DECISION: \<label>* or *DECISION: \<my words>* as the Inbox's answer, the popup closes, and a refused answer instead leaves the popup with a copyable problem and its buttons live again

---

### User Story 883:

- **Summary:** An answered card keeps the question over the answer
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests`: `testWhatACardSays`, `testTheCardsKeepWithTheBoard`; `just test`); and on the simulator (`WhiteboardQuestionUITests` 1/1)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *An answered card*

#### Use Case:
- **As someone** who answered a question on a board
- **I want to** still see what was asked and what I said
- **so that** the drawing keeps the decision it led to

#### Acceptance Criteria:
- **Scenario:** The Cockpit takes my answer
- **Given:** a card I just answered
- **When:** the popup closes
- **Then:** the card is grey, *✓ \<question>* over the answer (and the note), and it is still there when the board opens again, with no network

---

### User Story 884:

- **Summary:** A card answered elsewhere shows that answer
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests.testClosedAsksFetchTheirAnswerAndAMissingOneIsAskedAgain`, `testTheWireAsksForSnoozedAsksAndEncodesTheIDs`; `just test`); not yet seen on the simulator or the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Answered elsewhere*

#### Use Case:
- **As someone** who answered a board's question in the Inbox or in Chat
- **I want to** see that answer on the board's card
- **so that** the board never shows a question as open that I have already decided

#### Acceptance Criteria:
- **Scenario:** The ask closed while the board was shut
- **Given:** a card whose ask is no longer open in the Cockpit
- **When:** I open the board
- **Then:** the card shows *✓ \<question>* over the answer the Cockpit gives, or *✓ answered* when it has none yet, asked again the next time the board opens

---

### User Story 885:

- **Summary:** An answered card opens read-only and collapses to a short line
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e), *Collapse* renamed *Shrink* in 'd3986c48', and back to *Collapse* on the card's strip in #1387 part 3 (on branch `native/question-looks-1387`). Verified by host tests (`WhiteboardQuestionsTests.testOnlyAnAnsweredCardFoldsToAChipAsWideAsItsWords`; `just test`); and on the simulator (`WhiteboardQuestionUITests` 1/1)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Reading* and *The card's looks*

#### Use Case:
- **As someone** with answered questions on a board
- **I want to** read one in full, or fold it out of the way
- **so that** old decisions stay on the board without crowding the drawing

#### Acceptance Criteria:
- **Scenario:** I collapse an answered card to its short line
- **Given:** an answered card on the board, shown full
- **When:** I tap it, close the popup, and tap *Collapse* on the card's strip
- **Then:** the popup showed the question and the answer in full, the card is now one line *✓ \<question>* as wide as its words, and a tap on it opens it out again

---

### User Story 886:

- **Summary:** The eraser takes an answered card
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests.testTheEraserTakesAnAnsweredCardAndLeavesAnOpenOne`; `just test`); the eraser's touches live in the board's view, with no host test, and take a card only from a touch that would erase ink — the Pencil, or a finger while fingers draw, never a finger panning the board (review fix); not yet seen on the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *The eraser*

#### Use Case:
- **As someone** done with an answered question on a board
- **I want to** erase it as I would ink
- **so that** clearing the board is one gesture whatever is on it

#### Acceptance Criteria:
- **Scenario:** I erase across cards
- **Given:** an answered card and an open card on the board, and the eraser in hand
- **When:** I stroke the eraser across both
- **Then:** the answered card goes, the open card stays, and the session log says a card was erased

- **Scenario:** I pan the board with the eraser in hand
- **Given:** an answered card on the board, the eraser in hand, and fingers set not to draw
- **When:** I drag a finger that starts on the card
- **Then:** the board scrolls and the card stays

---

### User Story 1119:

- **Summary:** An opened question folds back to its one line without answering
- **Status:** implemented in '22a78654', fixed after review in '2a4b6fca' (rebased from 'a4613ba7'), 'a022023c' and '08db3051', on branch `native/decision-fold-fjh0`; verified on the Mac build and on the iPad simulator (`just test-ladder`: `WhiteboardQuestionUITests.testLarrysQuestionLandsAnswersAndFolds` folds the opened question, sees the card's one open line, and opens it again before answering); after review round 1 ('a4613ba7') the simulator was re-run: `WhiteboardQuestionUITests` on the iPad simulator, and the smoke's *whiteboard: the question opened and folded back to its unanswered line* passed; not yet on the iPad
- **Issues:** bead context-grabber-fjh0
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Folding an open card*

#### Use Case:
- **As someone** who opened one of Larry's questions on a board and isn't ready to answer
- **I want to** fold it back to its line on the board from the card itself
- **so that** the drawing is back in view and the question still waits there

#### Acceptance Criteria:
- **Scenario:** I fold an opened question
- **Given:** an open question card's popup over the board
- **When:** I tap the chevron beside the decision card's **⋯**, even while a request is on its way
- **Then:** the popup closes, the card is its one open line *? \<question\> ···* again, and a tap opens it whole. Folding sends nothing and the log records an unanswered collapse. A request already on its way can update the original card when it finishes, and another question's popup stays open.

---

### User Story 889:

- **Summary:** I speak my own answer to a question card, with the mic beside Send
- **Status:** implemented in [a113e38](https://github.com/idvorkin/context-grabber/commit/a113e38), Chat's mic beside the own answer's *Send*. Verified by host tests and lint (`just test`), the Mac build, and on the iPad simulator (`just test-ladder`: `WhiteboardQuestionUITests` measures the field, then the mic, then *Send*, a gap of at most 8 points and both buttons at least 44 points each way). Recording itself is dictation, so it is the phone's to show: not yet tried on a device
- **Issues:** [#625](https://github.com/idvorkin/context-grabber/issues/625) ("put the record button by the send button", then "that should go on all of my screens")
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Answering*

#### Use Case:
- **As someone** answering Larry's question on a board, often with the Pencil in hand
- **I want to** speak my own answer with the mic right beside *Send*, as in Chat
- **so that** every place I write to Larry has its two thumb actions together

#### Acceptance Criteria:
- **Scenario:** The mic sits by Send
- **Given:** an open question card's popup, on iPhone or iPad
- **When:** I look at *Your own answer*
- **Then:** the mic is immediately beside *Send*, after the field, each at least 44 points in both directions; the mic records into the field as Chat's does and *Send* answers as before

---

### User Story 1273:

- **Summary:** I hide a question card to a bare '?'
- **Status:** implemented in 'c8c3adc3', the drag's cancel reset and the eraser's hold in 'ab30e78b', *Hide* renamed *Collapse* in 'd3986c48'. Verified by host tests (`WhiteboardQuestionsTests`: `testAnyCardHidesToAQuestionMarkAtItsLeftEndAndComesBackAsItWas`, `testTheEraserTakesAnAnsweredQuestionMarkAndLeavesAnOpenOne`, `testABoardKeptBeforeHidingReadsAsShown`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionHidesToAMarkAndDrags`, 3/3 with the class, and the whiteboard smoke); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Hiding a card*

#### Use Case:
- **As someone** drawing on a board with one of Larry's questions on it
- **I want to** shrink the card to a bare '?' without answering or folding it
- **so that** the drawing is clear and the question is still there, a tap away

#### Acceptance Criteria:
- **Scenario:** I hide an open question
- **Given:** an open question card on the board
- **When:** I tap *Collapse* on the card's strip (first built as *Hide* in the popup)
- **Then:** the card is a small round '?' in Larry's purple where the card's left end was, with no strip, nothing is answered, and the log records the look

---

### User Story 1169:

- **Summary:** A tap on a hidden card's '?' brings the card back as it was
- **Status:** implemented in 'c8c3adc3', the drag's cancel reset and the eraser's hold in 'ab30e78b'. Verified by host tests (`WhiteboardQuestionsTests`: `testAnyCardHidesToAQuestionMarkAtItsLeftEndAndComesBackAsItWas`, `testTheEraserTakesAnAnsweredQuestionMarkAndLeavesAnOpenOne`, `testABoardKeptBeforeHidingReadsAsShown`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionHidesToAMarkAndDrags`, 3/3 with the class, and the whiteboard smoke); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Hiding a card*

#### Use Case:
- **As someone** with a question I hid to a '?'
- **I want to** bring the card back with one tap
- **so that** the question I set aside is there again without answering it or opening its popup

#### Acceptance Criteria:
- **Scenario:** I bring a hidden card back
- **Given:** a hidden card's '?' on the board, open or answered
- **When:** I tap the '?'
- **Then:** the card is back as it was (open, answered, or a folded chip) where the '?' was, and no popup opens

---

### User Story 1175:

- **Summary:** A hidden card stays a '?' when the board is opened again
- **Status:** implemented in 'c8c3adc3', the drag's cancel reset and the eraser's hold in 'ab30e78b'. Verified by host tests (`WhiteboardQuestionsTests`: `testAnyCardHidesToAQuestionMarkAtItsLeftEndAndComesBackAsItWas`, `testTheEraserTakesAnAnsweredQuestionMarkAndLeavesAnOpenOne`, `testABoardKeptBeforeHidingReadsAsShown`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionHidesToAMarkAndDrags`, 3/3 with the class, and the whiteboard smoke); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Hiding a card*

#### Use Case:
- **As someone** who hid a question card
- **I want to** have it stay hidden across closing and opening the board
- **so that** the board looks as I left it

#### Acceptance Criteria:
- **Scenario:** A hidden card stays hidden
- **Given:** a hidden card
- **When:** I close the board and open it again
- **Then:** it is still a '?' in the same place

---

### User Story 1274:

- **Summary:** I drag a question card, a chip or a '?' anywhere on the page
- **Status:** implemented in 'c8c3adc3', the drag's cancel reset and the eraser's hold in 'ab30e78b'. Verified by host tests (`WhiteboardQuestionsTests.testACardMovesWhereItIsLetGoInsideThePage`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionHidesToAMarkAndDrags` drags the '?' and the card, neither opening the popup); with the Pencil, only on the iPad: not yet tried
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Moving a card*

#### Use Case:
- **As someone** arranging a board around Larry's questions
- **I want to** move a card where it fits the drawing
- **so that** a question sits beside what it is about and out of the way of my writing

#### Acceptance Criteria:
- **Scenario:** I drag a card
- **Given:** a question card, a chip or a '?' on the board
- **When:** I drag it with a finger or the Pencil and let go
- **Then:** it followed the touch and stays where I let go, inside the page; no popup opened and nothing was drawn; the log records where it moved

---

### User Story 1234:

- **Summary:** A question card I moved stays where I put it when the board is opened again
- **Status:** implemented in 'c8c3adc3', the drag's cancel reset and the eraser's hold in 'ab30e78b'. Verified by host tests (`WhiteboardQuestionsTests.testACardMovesWhereItIsLetGoInsideThePage`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionHidesToAMarkAndDrags` drags the '?' and the card, neither opening the popup); with the Pencil, only on the iPad: not yet tried
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Moving a card*

#### Use Case:
- **As someone** who dragged a question card into place
- **I want to** find it where I left it after closing and opening the board
- **so that** my arrangement of the board lasts

#### Acceptance Criteria:
- **Scenario:** A moved card stays moved
- **Given:** a card I dragged
- **When:** I close the board and open it again
- **Then:** it is where I left it

---

### User Story 1235:

- **Summary:** A question card dragged off the page stops at the page's edge
- **Status:** implemented in 'c8c3adc3', the drag's cancel reset and the eraser's hold in 'ab30e78b'. Verified by host tests (`WhiteboardQuestionsTests.testACardMovesWhereItIsLetGoInsideThePage`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionHidesToAMarkAndDrags` drags the '?' and the card, neither opening the popup); with the Pencil, only on the iPad: not yet tried
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Moving a card*

#### Use Case:
- **As someone** dragging a question card near the page's edge
- **I want to** have the card stay on the page however far I drag
- **so that** a card is never lost off the page

#### Acceptance Criteria:
- **Scenario:** A drag off the page
- **Given:** a card on the board
- **When:** I drag it past the page's edge
- **Then:** it stops at the page's edge

---

### User Story 1314:

- **Summary:** I archive a question card off the board
- **Status:** implemented in 'd3986c48'. Verified by host tests (`WhiteboardQuestionsArchiveTests`: `testAnArchivedCardLeavesTheBoardAndAnsweresNothing`, `testAnArchivedCardNeverLandsAgainByItself`, `testTheEraserCantReachAnArchivedCard`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionArchivesAndReopens`, the class 5/5, against the fake Cockpit); not yet on the iPad or against the real Larry
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Archiving a card*

#### Use Case:
- **As someone** with a question card on a board I'm done looking at
- **I want to** archive it without answering or erasing it
- **so that** the board is clear and the question and its answer are still kept

#### Acceptance Criteria:
- **Scenario:** I archive a card
- **Given:** a question card on the board, open or answered
- **When:** I tap *Archive* on the card's strip
- **Then:** the card is gone from the board, nothing is answered, the board's menu now has *Archived questions*, and the log records an archive

---

### User Story 1315:

- **Summary:** I reopen an archived question from the board's menu
- **Status:** implemented in 'd3986c48'. Verified by host tests (`WhiteboardQuestionsArchiveTests.testArchivedNewestFirstAndReopenedAsItWas`, `testABoardKeptBeforeArchivingReadsAsOnTheBoard`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testAQuestionArchivesAndReopens`, the class 5/5, against the fake Cockpit); not yet on the iPad or against the real Larry
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Archiving a card*

#### Use Case:
- **As someone** who archived one of Larry's questions
- **I want to** find it behind the board's menu and put it back
- **so that** an archived question or answer is never lost

#### Acceptance Criteria:
- **Scenario:** I reopen an archived card
- **Given:** an archived card on the board
- **When:** I open the board's menu, tap *Archived questions*, and tap *Reopen* beside it
- **Then:** the list showed its question with its answer or *open*; the card is back on the board where it was, as it was, and off the list, and the log records a reopen

---

### User Story 1316:

- **Summary:** I think a question over with Larry from its card
- **Status:** implemented in 'd3986c48'. Verified by host tests (`WhiteboardQuestionsArchiveTests.testOnlyAnOpenCardIsThoughtOverAndItsLineSaysSo`, `WhiteboardRequestsTests.testThinkingWordsPostToTheAsksOwnThread`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testThinkingTalksItOverWithLarry`, the class 5/5, against the fake Cockpit); not yet on the iPad or against the real Larry
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Thinking it over*

#### Use Case:
- **As someone** whose answer to Larry's question is "good idea, let's go back and forth"
- **I want to** talk it over on the card without picking an option
- **so that** the question stays open while we think it through together

#### Acceptance Criteria:
- **Scenario:** I start thinking a question over
- **Given:** an open question card's popup over the board
- **When:** I tap *Thinking*, write a few words under *Talk it over* and tap *Send*
- **Then:** my words go to the ask's own conversation on the Cockpit and show under *Talk it over*, nothing is answered, and the card on the board reads *… \<question\> ···*

---

### User Story 1317:

- **Summary:** Larry's reply to a question I'm thinking over shows on its card
- **Status:** implemented in 'd3986c48'. Verified by host tests (`WhiteboardRequestsTests.testTheConversationIsReadFromTheAsksThread`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests.testThinkingTalksItOverWithLarry`, the class 5/5, against the fake Cockpit); not yet on the iPad or against the real Larry
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Thinking it over*

#### Use Case:
- **As someone** thinking one of Larry's questions over with him
- **I want to** see his replies in the card's conversation as they come
- **so that** the back-and-forth happens where the question is, on the board

#### Acceptance Criteria:
- **Scenario:** Larry replies while the card is open
- **Given:** a card being thought over, its popup open at *Talk it over*
- **When:** Larry replies on the ask's conversation
- **Then:** his reply appears under mine within a few seconds, newest last, and I can still pick an option to answer the ask

---

### User Story 1319:

- **Summary:** A double tap steps a question card to its next look
- **Status:** implemented in 'beda7f13' and '3df0c091', held for Igor's design call on the before and after pictures (the board's preview of every look, `just render-preview App/Whiteboard/WhiteboardQuestionLooks+Preview.swift`). Verified by host tests (`WhiteboardQuestionsLooksTests`: `testCollapseStepsAnAnsweredCardFullThenShortThenRound`, `testCollapseTakesAnOpenCardStraightToRound`, `testADoubleTapCyclesAndWrapsFromRoundToFull`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests` 5/5: the strip's Collapse, Open out and Archive, the double tap's cycle, the strip staying put between looks); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *A double tap cycles the card's looks*

#### Use Case:
- **As someone** arranging Larry's questions on a board with the Pencil in hand
- **I want to** shrink or grow a card with a double tap, without opening it
- **so that** making room on the board is one gesture

#### Acceptance Criteria:
- **Scenario:** I double tap an answered card
- **Given:** an answered card shown full on the board
- **When:** I double tap it three times, a pause between each
- **Then:** it went to its one-line chip, then to a '?', then back to full, and no popup opened

---

### User Story 1320:

- **Summary:** An answered question reads as plain text on the board
- **Status:** implemented in 'beda7f13' and '3df0c091', held for Igor's design call on the before and after pictures (the board's preview of every look, `just render-preview App/Whiteboard/WhiteboardQuestionLooks+Preview.swift`). Verified by host tests (`WhiteboardQuestionsLooksTests.testAnAnsweredRoundIsATickAndAnOpenOneAQuestionMark`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests` 5/5: the strip's Collapse, Open out and Archive, the double tap's cycle, the strip staying put between looks); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *An answered card reads as text*

#### Use Case:
- **As someone** whose board keeps old answers beside the drawing
- **I want to** see an answered question as text, not as a card
- **so that** a settled decision reads like part of the board rather than a pending ask

#### Acceptance Criteria:
- **Scenario:** A question is answered
- **Given:** an open question card on the board
- **When:** I answer it
- **Then:** it is drawn as the question small over the answer with no card fill or edge, and a tap still opens it read-only

---

### User Story 1321:

- **Summary:** A question card's controls are always in the same spot
- **Status:** implemented in 'beda7f13' and '3df0c091', held for Igor's design call on the before and after pictures (the board's preview of every look, `just render-preview App/Whiteboard/WhiteboardQuestionLooks+Preview.swift`). Verified by host tests (`WhiteboardQuestionsLooksTests.testEachLookOffersItsControlsInOneOrder`, `testTheStripSitsAtTheSamePlaceInEveryLook`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests` 5/5: the strip's Collapse, Open out and Archive, the double tap's cycle, the strip staying put between looks); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *The controls sit in one spot*

#### Use Case:
- **As someone** who uses question cards often
- **I want to** find Collapse, Open out, Archive and Thinking in one place on every card
- **so that** I reach for them without looking

#### Acceptance Criteria:
- **Scenario:** I look for a control on cards in different looks
- **Given:** an open card, an answered card shown full, and an answered card collapsed to its short line on the board
- **When:** I look for each card's controls
- **Then:** each card has a strip of icons at a full card's right end, inside it, Collapse, Open out, Archive and Thinking each in its own slot, showing only those that card's look allows, the others' slots empty, so no icon moves between looks

---

### User Story 1325:

- **Summary:** One set of words and marks for a question card's looks, as on the web board
- **Status:** implemented in 'beda7f13' and '3df0c091', held for Igor's design call on the before and after pictures (the board's preview of every look, `just render-preview App/Whiteboard/WhiteboardQuestionLooks+Preview.swift`). Verified by host tests (`WhiteboardQuestionsLooksTests.testOpenOutGoesBackToFullFromAnyLook`, `testAnAnsweredRoundIsATickAndAnOpenOneAQuestionMark`; `just test`), the Mac build, and on the iPad simulator (`WhiteboardQuestionUITests` 5/5: the strip's Collapse, Open out and Archive, the double tap's cycle, the strip staying put between looks); not yet on the iPad
- **Issues:** [#1387](https://github.com/idvorkin/context-grabber/issues/1387)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *The card's looks*

#### Use Case:
- **As someone** who uses question cards on the iPad and on Larry's web board
- **I want to** see the same looks and the same words on both
- **so that** a card I collapse means the same thing wherever I look at it

#### Acceptance Criteria:
- **Scenario:** I collapse an answered card all the way
- **Given:** an answered card on the board, shown full
- **When:** I tap *Collapse* on its strip twice
- **Then:** it went to its short line, then to a grey round *✓* (an open card's round is a purple *?*), *Open out* showed on the strip once it wasn't full, and a tap on the round opened it out to full

