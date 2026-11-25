# The whiteboard: Larry's turn and the conversation

Larry and Claude seeing the board: asking with the Pencil's pause or the voice, the picture and strokes he gets, who answers, the clock and the wait, the note and the conversation panel, Retry and Interrupt. One of the whiteboard journey's files; the
[journey table](README.md) lists them all.
Design specs: [whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md),
[shapes](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[paste](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[to text and snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[reword and live snap](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

---

### User Story 343:

- **Summary:** Show Larry the board
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), one send per stroke in [abe5876](https://github.com/idvorkin/context-grabber/commit/abe5876), the thread titled with the board's name in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023), the board's one thread instead of a new one each time in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardFrameTests`: the picture's margin and size) and the simulator build; a thread in Chat not yet seen from the iPad; a picture of the page or pages on screen since story 433 ([a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315)); *Larry's turn* and *Send to Larry* made one button (story 1176) in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552), verified by host tests and the whiteboard UI tests on the iPad simulator

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
- **Given:** I have just sent the board to Larry and he is looking at it
- **When:** I tap Send to Larry again before drawing anything more
- **Then:** the button is dimmed and nothing can be sent until I draw, speak or bring other pages on screen (story 765); on a board I only look at, the button is disabled until other pages are on screen. Since story 1176 Send on a board I draw on is Larry's turn

---

### User Story 344:

- **Summary:** Claude suggests the next strokes as I draw
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), the Cockpit's `POST /whiteboard/suggest` in [7974077](https://github.com/idvorkin/context-grabber/commit/7974077); verified by host tests (`WhiteboardTurnTests`: the request, the answer, each kind of stroke, a label on its baseline, a 429 skipped, shapes onto the board, a tap's hit, kept ink through PencilKit's own spline; `WhiteboardGhostTurnsTests`: a failing Cockpit noted once, a stale answer shown nowhere) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a pause brings a ghost; the keep verified on the simulator by `WhiteboardTurnUITests`); a real Claude answer and undo not yet tried on the iPad; #624's label converts to one unbroken row of every letter, pinned in [0215bb6](https://github.com/idvorkin/context-grabber/commit/0215bb6) (`BoardLabelOneLineTests`, host; the break seen on the iPad came after the keep, not from the conversion, and waits on the iPad's `ink_moved` evidence)
- **Issues:** [#624](https://github.com/idvorkin/context-grabber/issues/624)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing alone
- **I want to** see faint suggested strokes when I pause
- **so that** it feels like drawing with someone

#### Acceptance Criteria:
- **Scenario:** A ghost, kept
- **Given:** I drew two circles and lifted the Pencil with *Ask at my pauses* on, and a faint orange shape appeared within about five seconds
- **When:** I tap it
- **Then:** it becomes a real stroke in Claude's orange that my eraser and undo treat like mine

- **Scenario:** Every kind of stroke
- **Given:** *Ask at my pauses* is on and I paused
- **When:** the Cockpit answers with a line, an arrow, a polyline, a circle, an arc, a label and a kind the app doesn't know
- **Then:** the six I know appear as faint orange ghosts, the label's letters standing on the spot the Cockpit gave as its baseline, and the unknown one isn't shown

- **Scenario:** The model takes too long
- **Given:** *Ask at my pauses* is on and I paused
- **When:** the Cockpit has not answered after 10 s
- **Then:** no ghost appears and the bar says *Ghosts: the Cockpit isn't answering* until a turn gets through

- **Scenario:** Asked too soon
- **Given:** ghosts are showing
- **When:** a new turn comes within the Cockpit's 2 s and it answers 429
- **Then:** the turn is skipped with no error, the bar doesn't change and the ghosts stay

---

### User Story 345:

- **Summary:** Talk while I draw
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76), waiting for the next picture since [77f56103](https://github.com/idvorkin/context-grabber/commit/77f56103) (story 1281, verified on the host by `WhiteboardGhostTurnsTests`); the words to the turn verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and the new words by `WhiteboardSpeechTests`; real dictation over the Pencil and a real model answer to try on the iPad
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
- **Then:** once the next picture goes (the Pencil's pause, *Send to Larry*, closing the mic, or 5 s of silence; stories 1281, 1305), faint orange ghosts answer what I said, such as a label "dip" with an arrow at the curve's low point

---

### User Story 1281:

- **Summary:** The board's mic listens continuously, and a pause to think under 5 s sends nothing
- **Status:** implemented in [77f56103](https://github.com/idvorkin/context-grabber/commit/77f56103), a pause of 5 s or more sending since [162a6cf5](https://github.com/idvorkin/context-grabber/commit/162a6cf5) (story 1305); the waiting words verified on the host by `WhiteboardGhostTurnsTests`; real dictation on the iPad not yet
- **Issues:** Igor's whiteboard picks, 2026-11-24 (pick 5, via Larry); a pause of 5 s or more sends since Igor's answer the same day (story 1305)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md) (*Talking while drawing*)

#### Use Case:
- **As someone** who talks, stops to think, and draws on the board
- **I want to** keep the mic open with my words showing as I say them, and have them go only with the next picture (the Pencil's pause, story 345)
- **so that** a pause to think never sends half a thought to Larry

#### Acceptance Criteria:
- **Scenario:** Thinking out loud
- **Given:** the mic is open on the board
- **When:** I say "I see a chip that says", stop for four seconds, and go on
- **Then:** nothing is sent, and the note's line shows my words as I say them

---

### User Story 1287:

- **Summary:** *Send to Larry* takes my waiting words even when the drawing hasn't changed
- **Status:** implemented in [77f56103](https://github.com/idvorkin/context-grabber/commit/77f56103); verified on the host by `WhiteboardLarryTurnTests` and `WhiteboardGhostTurnsTests`; on the iPad not yet
- **Issues:** Igor's whiteboard picks, 2026-11-24 (pick 5, via Larry)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md) (*Talking while drawing*)

#### Use Case:
- **As someone** who talks to Larry over the board
- **I want to** send what I said with the board even when he already has the drawing
- **so that** a spoken question never waits for me to draw something new

#### Acceptance Criteria:
- **Scenario:** Send takes my words
- **Given:** Larry already has the board as it is, and the mic heard "what about Tuesday"
- **When:** I tap *Send to Larry*, which is not dimmed
- **Then:** the board goes to him with "what about Tuesday"

---

### User Story 1288:

- **Summary:** Closing the mic sends the words waiting
- **Status:** implemented in [77f56103](https://github.com/idvorkin/context-grabber/commit/77f56103), words waiting from before a switch since [c8d428f7](https://github.com/idvorkin/context-grabber/commit/c8d428f7); verified on the host by `WhiteboardGhostTurnsTests`; on the iPad not yet
- **Issues:** Igor's whiteboard picks, 2026-11-24 (pick 5, via Larry)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md) (*Talking while drawing*)

#### Use Case:
- **As someone** who finishes a thought by closing the mic
- **I want to** have what the mic heard go at once
- **so that** closing the mic is how I say "that's it"

#### Acceptance Criteria:
- **Scenario:** Closing the mic
- **Given:** the mic heard words no picture took, some of them before I switched microphones
- **When:** I tap the mic to close it
- **Then:** all of those words go at once, as before

---

### User Story 1289:

- **Summary:** Switching microphones keeps my words waiting
- **Status:** implemented in [77f56103](https://github.com/idvorkin/context-grabber/commit/77f56103); on the iPad not yet
- **Issues:** Igor's whiteboard picks, 2026-11-24 (pick 5, via Larry)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md) (*Talking while drawing*)

#### Use Case:
- **As someone** who changes microphones mid-thought
- **I want to** keep what I already said
- **so that** a new microphone never sends or loses half a thought

#### Acceptance Criteria:
- **Scenario:** Switching microphones
- **Given:** the mic is open and heard "so the plan is"
- **When:** I pick another microphone
- **Then:** nothing is sent, the mic listens on the new one, and "so the plan is" goes with the next picture

---

### User Story 1305:

- **Summary:** Five seconds of silence sends what I said
- **Status:** implemented in [162a6cf5](https://github.com/idvorkin/context-grabber/commit/162a6cf5); the 5 s rule verified on the host by `WhiteboardSpeechTests`, and the board's UI tests pass on the iPad Pro 11-inch (M5) simulator; real dictation's silence to try on the iPad
- **Issues:** Igor, 2026-11-24, answering Larry's board card igor2-88g.1724.4: "Keep a silence send, only after 5 s or more"
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md) (*Talking while drawing*)

#### Use Case:
- **As someone** who talks to the board without drawing or tapping anything
- **I want to** have my words go once I've been quiet for 5 s
- **so that** a spoken question reaches Larry without a tap, and a shorter pause to think still sends nothing

#### Acceptance Criteria:
- **Scenario:** Quiet for five seconds
- **Given:** the mic is open on the board and heard "what about Tuesday", which no picture has taken
- **When:** I say nothing more for 5 s
- **Then:** the board goes with "what about Tuesday", the mic stays open, and the session log says the silence sent it

---

### User Story 1118:

- **Summary:** A spoken turn waits until I have finished my sentence
- **Status:** superseded by stories 1281 and 1305 (Igor, 2026-11-24: the words go with the next picture, and only 5 s or more of silence sends, whatever the words end with); was implemented in [ea86e616](https://github.com/idvorkin/context-grabber/commit/ea86e616)
- **Issues:** bead `context-grabber-u1yy`
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who pauses to think mid-sentence while drawing
- **I want to** have the board wait for the end of what I'm saying
- **so that** Larry gets my whole thought, not "I see a chip that says"

#### Acceptance Criteria:
- **Scenario:** A pause mid-sentence
- **Given:** the mic is open on the board
- **When:** I say "I see a chip that says", stop for about 4 s, and go on "your board, what does that mean"
- **Then:** one turn goes, with the whole sentence, about 5 s after I finish

- **Scenario:** A short pause after a plain phrase
- **Given:** the mic is open on the board
- **When:** I say "OK when I drop text", stop for about 2.4 s, and go on
- **Then:** the two parts go as one turn

- **Scenario:** A finished sentence
- **Given:** the mic is open and the dictation ended my words with a full stop or question mark
- **When:** I stop talking
- **Then:** the turn goes after about 1.5 s of silence

- **Scenario:** The recognizer repeats itself
- **Given:** I stopped talking
- **When:** the recognizer sends my words again with nothing new
- **Then:** the silence is not restarted, and the turn goes on time

- **Scenario:** The Pencil pauses while I'm still talking
- **Given:** I'm mid-sentence and lift the Pencil
- **When:** the board's pause passes
- **Then:** the drawing's turn goes as before, and my sentence goes with the next turn once I finish

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

### User Story 349:

- **Summary:** Larry takes a turn on the board
- **Status:** first implemented as a call that waited for him in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to the chat path, no waiting, in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b) (Igor, 2026-11-02); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: Larry's turn brings his marks with no further tap) against the fake Cockpit; the real Larry's answer on the iPad not yet tried; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`); *Larry's turn* and *Send to Larry* made one button (story 1176) in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552), verified by host tests and the whiteboard UI tests on the iPad simulator
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** working an idea out on the board
- **I want to** hand Larry the Pencil for a turn
- **so that** he answers in marks on my drawing, not only in words somewhere else

#### Acceptance Criteria:
- **Scenario:** Larry answers on the board
- **Given:** the board has a drawing
- **When:** I tap *Send to Larry* (*Larry's turn* until story 1176 made them one button) and carry on
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) until he answers (story 662), with no spinner, and the Pencil keeps drawing. When he answers, faint purple shapes and a line from him appear with no tap, nothing on the board changes until I keep one, Chat has a thread named after the board with the picture and his words, and the board's next turn goes to it

---

### User Story 665:

- **Summary:** Turning *Ask at my pauses* off closes the board's mic
- **Status:** implemented in [9a83d67](https://github.com/idvorkin/context-grabber/commit/9a83d67); verified on the host (`WhiteboardGhostTurnsTests`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad. The bar's line worded for *Ask at my pauses* in [767aabac](https://github.com/idvorkin/context-grabber/commit/767aabac) (story 1171), verified on the host and the Mac build
- **Issues:** [#824](https://github.com/idvorkin/context-grabber/issues/824) (the mic heard words with Ghosts off and dropped them silently)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking to the board who turns *Ask at my pauses* off mid-sentence
- **I want to** have the mic close and say why
- **so that** I don't keep talking to a mic that reaches no one (story 367)

#### Acceptance Criteria:
- **Scenario:** Ask at my pauses goes off while I talk
- **Given:** the board's mic is open
- **When:** I turn *Ask at my pauses* off
- **Then:** the mic closes, the bar shows the [same notice as when Talk is refused](#user-story-367), and the words aren't asked about, now or when it comes back on

---

### User Story 359:

- **Summary:** Strokes made during a ghost turn get their own turn
- **Status:** superseded by story 894 (the Pencil going down drops a turn that hasn't landed; decided 2026-11-22) and story 892 (the next turn waits for my next pause, by my rhythm); was implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3); its rules verified by host tests (`WhiteboardPacerTests`); not on the simulator, whose fake Cockpit answers with no delay, and the Pencil lift still to try on the iPad
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
- **Then:** those words go with a new turn after the first lands, once I've paused by my own rhythm (story 892; first built as a second after it lands)

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

- **Summary:** *Ask at my pauses* off holds for speech too
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and since bead `context-grabber-y8r` by the host alone (`WhiteboardGhostTurnsTests`); real dictation to try on the iPad. Since [9a83d67](https://github.com/idvorkin/context-grabber/commit/9a83d67) (#824) the mic doesn't open with Ghosts off, so the say hook no longer stands in for it here: verified on the host (`WhiteboardGhostTurnsTests`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad. The bar's line worded for *Ask at my pauses* in [767aabac](https://github.com/idvorkin/context-grabber/commit/767aabac) (story 1171), verified on the host and the Mac build
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605), [#824](https://github.com/idvorkin/context-grabber/issues/824) (the mic heard words with Ghosts off and dropped them silently)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who switched *Ask at my pauses* off
- **I want to** have talking ask nothing either
- **so that** the switch means what it says (story 351)

#### Acceptance Criteria:
- **Scenario:** Speaking with Ask at my pauses off
- **Given:** *Ask at my pauses* is off
- **When:** I tap the board's mic
- **Then:** it doesn't open, and the bar says *Ask at my pauses is off, so the mic would reach no one: turn it on to talk*; nothing is asked, no ghost appears, and nothing is sent when it comes back on

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
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20). The switch dropping a pending answer is covered by the host test `WhiteboardGhostTurnsTests.testGhostsOffMidTurnMakesItsAnswerStaleAndForgetsTheOwedAsk`. See [story 825](10-whiteboard-marks.md#user-story-825) for the later change to taps outside marks. To see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** stop the marks still on their way when I turn off *Ask at my pauses*
- **so that** what I sent away doesn't come back

#### Acceptance Criteria:
- **Scenario:** Sent away part way
- **Given:** Claude's marks are arriving
- **When:** I turn *Ask at my pauses* off
- **Then:** they go and no more of that turn's marks appear

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
- **When:** I tap *Send to Larry*
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
- **When:** I tap *Send to Larry*
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
- **Then:** within a few seconds, with no tap, they show as purple ghosts on what the picture showed, not where I am now, and his text shows in the bar as his line

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
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b) on the device that started the thread, and on every device (a Send goes to the thread the board carries through iCloud) in [c1b960b5](https://github.com/idvorkin/context-grabber/commit/c1b960b5) (story 1158, bead context-grabber-da1), and a Send recording the thread as it lands, closed board or not, in the review fixes on this branch; verified by host tests (`WhiteboardMarksTests`: pictures queued with no thread share the one the first starts, a lost thread frees the board); the buttons holding each other back, and a Send's thread on the iPad, not yet tried
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

### User Story 1158:

- **Summary:** A Send from any device goes to the board's one conversation
- **Status:** implemented in [c1b960b5](https://github.com/idvorkin/context-grabber/commit/c1b960b5) (bead context-grabber-da1); verified by host tests (`WhiteboardMarksTests`: `testASendWithNoThreadOfItsOwnUsesTheOneTheBoardCarries`, `testASendWithNeitherStartsOneAndRecordsIt`, `testTheBoardsThreadIsTheCarriedOneExceptOnTheDrawingDevice`, `testACarriedThreadTheCockpitLostIsNeverUsed`, `testACarriedThreadLostBesideAnOlderOwnOneIsNeverUsed`; `just native-test`) and the Mac build (`just native-build-mac`); the phone's Send on an iPad-drawn board is owed on the devices (iCloud carries the thread only between real devices, and no iPhone runs while the whiteboard work is in progress); a board with no thread sent from the iPhone first is bead context-grabber-2ezr
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *The board's chat from the iPhone*
- **Issues:** bead context-grabber-da1 (Igor's pick on the design board, 2026-11-22: "a Send from any device goes to the board's one conversation"; read from the code: a Send used the thread this device started, so an iPhone's Send on an iPad's board started a second one)

#### Use Case:
- **As someone** looking at an iPad's board on my iPhone
- **I want to** send it to Larry from the phone and land in the conversation the board already has
- **so that** one board, one thread (story 385) is true on every device

#### Acceptance Criteria:
- **Scenario:** A phone's Send on an iPad's board
- **Given:** a board drawn on the iPad that already has a conversation with Larry, synced since, open on my iPhone
- **When:** I tap *Send to Larry* on the phone
- **Then:** the picture lands in that same conversation, the one the phone's note opens (story 1110), and no second thread is started, even when the phone started an older thread of its own for the board before; the phone's note and bubble open it after. The same holds on an iPad reinstalled since it drew the board, and a thread the Cockpit has lost is never used again on that device: the next picture starts a new one

---

### User Story 386:

- **Summary:** Larry draws unprompted
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by the simulator (`WhiteboardTurnUITests`) against the fake Cockpit, read from the board's note. Since story 770 the simulator keeps the unprompted marks and the reopen after a dismissal; the newest set on opening and a seen set never coming back are `WhiteboardMarksTests` on the host. Changed in [10727b6c](https://github.com/idvorkin/context-grabber/commit/10727b6c) (bead `context-grabber-n8ab`, story 1155): his next marks join his unkept ones instead of replacing them; verified by host tests (`WhiteboardMarksTests`, `WhiteboardGhostTurnsTests`), the Mac build and the simulator (`WhiteboardTurnUITests`: *5 to keep* after two replies)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with Larry's marks on the board
- **I want to** see his next marks join the ones I haven't dealt with
- **so that** nothing he drew leaves the board until I keep or dismiss it

#### Acceptance Criteria:
- **Scenario:** He draws unprompted
- **Given:** his marks are showing and I asked for nothing
- **When:** he posts another row of marks
- **Then:** the new ones show beside his unkept ones, which stay; Claude's stay

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
- **When:** I tap *Send to Larry*
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
- **When:** I tap *Send to Larry*
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

### User Story 1115:

- **Summary:** A Send's message and its picture share one id
- **Status:** implemented in [ee309dda](https://github.com/idvorkin/context-grabber/commit/ee309dda); verified by the Mac build. A Send from the iPad against the Cockpit not yet seen
- **Issues:** bead `context-grabber-bozm` (iPad, 2026-11-22 13:47: a Send's strokes were stored under its picture's id while its message had another, so a look-up by the message found no strokes, and Larry's reply to it was to a picture the board didn't know: `picture_known: false`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who sends a board to Larry with *Send to Larry*
- **I want to** have the message and its picture known by one id, as with *Larry's turn*
- **so that** Larry, and anyone reading the Cockpit, finds the strokes of the message he is answering, and his marks land where the picture was

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** a board with ink on it
- **When:** I tap *Send to Larry*
- **Then:** the chat message's id is the picture's id, the strokes are stored under that id, and Larry's reply to that message places its marks by the picture's frame and time

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

- **Scenario:** The outbox cannot read the wrapped strokes file
- **Given:** a queued Send whose wrapped strokes file is missing a readable strokes or folds list
- **When:** *Send to Larry* goes
- **Then:** the picture still goes, the strokes are skipped, and only the session log reports the unreadable file

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

- **Summary:** With no network Larry's turn says so and nothing waits (superseded by story 1176: Send waits in the outbox; this holds only for a picture a pause hands him)
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); the simulator compile only: no test runs a turn with no network, so this is owed on the iPad; *Larry's turn* and *Send to Larry* made one button (story 1176) in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552), verified by host tests and the whiteboard UI tests on the iPad simulator
- **Why:** split from story 421, whose old wording promised this case a send or a wait; a turn has no outbox
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry with no signal
- **I want to** be told the turn didn't go
- **so that** I don't wait for marks that aren't coming

#### Acceptance Criteria:
- **Scenario:** No network on Larry's turn
- **Given:** no network
- **When:** a pause hands him the picture on a Larry board
- **Then:** a copyable error says Larry couldn't be reached, and nothing is queued

---

### User Story 1176:

- **Summary:** One Send button that waits when offline
- **Status:** implemented in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552); verified by host tests (`just native-test`), the Mac build (`just native-build-mac`) and the whiteboard UI suite on the iPad simulator (rung 2, 78 tests green: `WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole` finds no *Larry's turn* and the three evenly spaced); iPhone tests were skipped by Igor's standing instruction of 2026-11-22. What Send does, offline, when it can't go and when the board reopens are stories 1189–1192. A wrapped strokes file requires both lists since [a91f59f9](https://github.com/idvorkin/context-grabber/commit/a91f59f9) (bead context-grabber-fffb), verified by host tests against hand-written fixtures (`WhiteboardStrokesFileTests`) and the Mac build.
- **Issues:** bead context-grabber-rtl (Igor, design board, 2026-11-22: "one Send button that waits when offline"); bead context-grabber-fffb (review of #1236: a waiting strokes file in the wrapped form names both its strokes and its folds; one without its folds is unreadable, never read as nothing folded)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *One Send*

#### Use Case:
- **As someone** handing the board to Larry, sometimes with no signal
- **I want to** have one Send button that hands him the board and waits when it can't go yet
- **so that** I never pick between two buttons that do nearly the same thing, and a turn taken offline isn't lost

#### Acceptance Criteria:
- **Scenario:** One button
- **Given:** a board I draw on, on the iPad
- **When:** I look at the bar's right group
- **Then:** it holds Talk, *Ask at my pauses* and Send to Larry, evenly spaced, and no *Larry's turn*

---

### User Story 1189:

- **Summary:** Send to Larry is Larry's turn
- **Status:** implemented in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552) (split from story 1176); verified by the whiteboard UI suite on the iPad simulator (rung 2: every test that handed Larry the board now taps Send and gets his marks with no further tap). On the iPad simulator's session log a first Send logged `send` (new_thread), `send_went` with clock true 39 ms later, and `larry_turn_over` why reply. A Send through the outbox carries no post timing for the Cockpit's debug page (story 1112): bead context-grabber-tadl.
- **Issues:** bead context-grabber-rtl (Igor, design board, 2026-11-22: "one Send button that waits when offline")
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *One Send*

#### Use Case:
- **As someone** handing the board to Larry with the network there
- **I want to** tap Send and have it be his turn
- **so that** his clock and marks come back as they did for *Larry's turn*

#### Acceptance Criteria:
- **Scenario:** Send is Larry's turn
- **Given:** a drawing on the board and the network there
- **When:** I tap *Send to Larry*
- **Then:** the note begins with Larry's clock, and his marks arrive on the board with no further tap

---

### User Story 1190:

- **Summary:** A Send with no network waits in the outbox and goes once
- **Status:** implemented in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552) (split from story 1176); verified by host tests (`WhiteboardOneSendTests`: *Waiting to send* in place of the clock and in VoiceOver, nothing else going while it waits, no timeout and never stuck, his clock and the three minutes starting when it goes, once; `WhiteboardStrokesTests.testABoardsSendWaitsOfflineAndGoesOnceWithItsFolds`: offline twice then back, one message under the picture's id with its folds beside its strokes). The network dropping and coming back is owed on the iPad (the simulator keeps its network).
- **Issues:** bead context-grabber-rtl (Igor, design board, 2026-11-22: "one Send button that waits when offline")
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *One Send*

#### Use Case:
- **As someone** handing the board to Larry with no signal
- **I want to** have the Send wait and go when the network is back
- **so that** a turn taken offline isn't lost or sent twice

#### Acceptance Criteria:
- **Scenario:** No network
- **Given:** no network
- **When:** I tap *Send to Larry*, then pause and tap it again
- **Then:** the note reads *Waiting to send · 0:00* and counts, the button is dimmed, nothing fails and nothing more goes to the outbox; when the network is back the picture goes once, the note reads *Larry · 0:00*, and his marks arrive with no further tap

---

### User Story 1202:

- **Summary:** Words spoken while the first Send waits are kept for the next picture
- **Status:** implemented in [2b950639](https://github.com/idvorkin/context-grabber/commit/2b950639); verified by host tests (`WhiteboardResponderTests`: a pause on a board whose own first Send waits goes to the turn; `WhiteboardOneSendTests`: the words held through the Send going and carried by the picture after his answer, or kept when it can't go) and the Mac build; owed on the iPad simulator, as the fake Cockpit can't hold a Send in the outbox.
- **Issues:** bead context-grabber-8lsj (review of PR #1236: words spoken at a pause while the board's first Send waited were dropped)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *One Send*

#### Use Case:
- **As someone** talking through a picture whose first Send waits for the network
- **I want to** have what I say at a pause kept
- **so that** Larry hears it with the next picture instead of losing it

#### Acceptance Criteria:
- **Scenario:** Words spoken while the first Send waits
- **Given:** a Larry board with no thread yet, its first Send waiting in the outbox
- **When:** I speak at a pause
- **Then:** nothing more goes while it waits, and once the Send has gone and Larry answers, the next picture carries my words; if the Send can't go, they wait for the next one

---

### User Story 1191:

- **Summary:** A Send that can't go frees the turn and keeps my words
- **Status:** implemented in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552) (split from story 1176); verified by host tests (`WhiteboardOneSendTests`: a refusal or a delete freeing the turn with its words kept; `ChatTests.testAnItemDeletedDuringItsUploadIsNeverPosted`: a Send deleted from the Inbox while its picture uploads is never posted). Not yet seen on the iPad.
- **Issues:** bead context-grabber-rtl (Igor, design board, 2026-11-22: "one Send button that waits when offline")
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *One Send*

#### Use Case:
- **As someone** whose waiting Send is deleted from the Inbox or refused
- **I want to** have the turn freed with what I said kept
- **so that** I can send again without losing my words

#### Acceptance Criteria:
- **Scenario:** It can't go after all
- **Given:** a Send waiting in the outbox
- **When:** I delete it from the Inbox, or the Cockpit refuses it
- **Then:** the turn is free and the button lights again, and what I said with it waits for the next picture; a refusal shows as a copyable problem naming the board

---

### User Story 1192:

- **Summary:** A board reopened while its Send waits says so
- **Status:** implemented in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552) (split from story 1176); verified by host tests (`WhiteboardOneSendTests`: a board reopened while it waits). Not yet seen on the iPad. A Send refused or deleted while its board is closed frees nothing to keep: its words are lost, bead context-grabber-tetc. The reopened board remembering what the waiting picture showed (no second copy on a repeat tap, ink drawn after it still new) in [027882ca](https://github.com/idvorkin/context-grabber/commit/027882ca), verified by host tests (`WhiteboardOneSendTests`: the picture's revision and part of the board, with folds open, restored from the outbox) and the Mac build; owed on the iPad simulator, as the fake Cockpit can't hold a Send in the outbox.
- **Issues:** bead context-grabber-rtl (Igor, design board, 2026-11-22: "one Send button that waits when offline"); bead context-grabber-kocz (review of PR #1236: a reopened board's repeat tap could send the identical picture, and ink drawn after the Send counted as sent)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *One Send*

#### Use Case:
- **As someone** closing a board while its Send waits
- **I want to** see it still waiting when I open the board again
- **so that** I know the turn is still on its way

#### Acceptance Criteria:
- **Scenario:** Reopened while it waits
- **Given:** a Send waiting in the outbox and the board closed
- **When:** I open the board again
- **Then:** the note reads *Waiting to send* again; when it goes Larry's clock starts and *Interrupt* is offered, and if it can't go what I said with it waits for the next picture

- **Scenario:** Send after the reopened Send goes
- **Given:** a board reopened while its Send waited, and the Send has now gone
- **When:** I look at *Send to Larry* with nothing drawn since the Send and the same pages on screen
- **Then:** it is dimmed and no second copy can go (story 765); had I drawn after the Send, before closing the board or since opening it, or moved to other pages, it is lit and a tap sends a fresh picture

---

### User Story 908:

- **Summary:** A connection dropped under Larry's turn is tried once more, quietly
- **Status:** implemented in [11e9176a](https://github.com/idvorkin/context-grabber/commit/11e9176a); verified by host tests (`WhiteboardLostConnectionTests`: lost once, lost twice, no network, one per hand-off, a turn taken over), the Mac build and the whiteboard UI tests on the iPad simulator (none drops a connection); the drop itself is owed on the iPad
- **Why:** the system tears the connection down when the app leaves the screen for a moment; that is not an outage, and story 428's error was the wrong answer to it
- **Issues:** [#1136](https://github.com/idvorkin/context-grabber/issues/1136) (*The network connection was lost* on the iPad when the app left the screen for a moment during a turn)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry who glances away from the app while it goes
- **I want to** have the turn go anyway
- **so that** a moment off screen doesn't cost me the turn or an error to dismiss

#### Acceptance Criteria:
- **Scenario:** A connection dropped under the turn is tried once more
- **Given:** Larry's turn is on its way and the iPad loses the connection under it, as when I leave the app for a moment
- **When:** the app is back on screen
- **Then:** the picture goes again by itself, once, and I see no error; Larry gets it once

---

### User Story 909:

- **Summary:** A connection lost again on the second try says Larry couldn't be reached
- **Status:** implemented in [11e9176a](https://github.com/idvorkin/context-grabber/commit/11e9176a); verified by host tests (`WhiteboardLostConnectionTests`: lost once, lost twice, no network, one per hand-off, a turn taken over), the Mac build and the whiteboard UI tests on the iPad simulator (none drops a connection); the drop itself is owed on the iPad
- **Why:** the quiet second try of story 908 is one try, not a loop; past it the turn says so, as story 428 does with no network
- **Issues:** [#1136](https://github.com/idvorkin/context-grabber/issues/1136) (*The network connection was lost* on the iPad when the app left the screen for a moment during a turn)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry on a connection that keeps dropping
- **I want to** be told the turn didn't go
- **so that** I don't wait for marks that aren't coming

#### Acceptance Criteria:
- **Scenario:** The second try fails too
- **Given:** the connection was lost under the turn and lost again on the second try
- **When:** the second try ends
- **Then:** a copyable error says Larry couldn't be reached, as with no network

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

### User Story 771:

- **Summary:** Larry can read the board's log without my exporting it
- **Status:** implemented in [dfc284d](https://github.com/idvorkin/context-grabber/commit/dfc284d), the header record naming the build in [973d927](https://github.com/idvorkin/context-grabber/commit/973d927); verified on the host (`just native-test`: `WhiteboardLogArchiveTests`, which lines are the board's, batches oldest first, the newest kept when the ring is full, a header and one record a line the archive keeps once, within 8 KB) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad: no turn has yet landed rows in the Cockpit's archive
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Larry can read what the board did*

#### Use Case:
- **As someone** telling Larry that something on the board went wrong
- **I want to** have him already hold what the board did
- **so that** he can find the cause without my pulling logs off the iPad

#### Acceptance Criteria:
- **Scenario:** A turn carries the log
- **Given:** a board on the iPad, and I tapped a ghost to keep it
- **When:** I give Larry his turn
- **Then:** the board's log lines since the last turn, the keep among them, are in the Cockpit's archive, and the board behaves as before

---

### User Story 800:

- **Summary:** Log lines the Cockpit missed go with the next picture
- **Status:** implemented in [dfc284d](https://github.com/idvorkin/context-grabber/commit/dfc284d); split from story 771. Verified on the host (`just native-test`: `WhiteboardLogArchiveTests`, batches oldest first, the newest kept when the ring is full, one record a line the archive keeps once) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Larry can read what the board did*

#### Use Case:
- **As someone** telling Larry that something on the board went wrong, on a patchy connection
- **I want to** have the board's log reach him whole even when one sending fails
- **so that** he never reads a log with a hole in it, or the same lines twice

#### Acceptance Criteria:
- **Scenario:** The Cockpit misses one
- **Given:** a turn whose log didn't reach the Cockpit
- **When:** the next picture goes to Larry
- **Then:** the lines that missed go with it, none lost and none twice

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
- **Then:** its Responder row says Larry (story 960) and opens on Haiku, Sonnet and Larry with Larry ticked, and when I pick Haiku the tick moves at once and the board has Haiku when I reopen it, here and on my other devices

- **Scenario:** A Larry board
- **Given:** a board whose responder is Larry, with *Ask at my pauses* on
- **When:** I draw and pause
- **Then:** no orange ghosts come; the bar's note begins with Larry's clock (*Larry · 0:00*, story 667), the picture is in the board's chat thread, and his purple marks show when he answers

- **Scenario:** The Cockpit can't take the choice
- **Given:** the Cockpit can't be reached
- **When:** I pick another responder
- **Then:** the tick goes back to the one the Cockpit last said and a copyable problem says why

---

### User Story 960:

- **Summary:** Larry answers every board I haven't set otherwise
- **Issues:** Igor on his board, 2026-11-17: "Let's make Larry default responder"
- **Status:** implemented in [436837c](https://github.com/idvorkin/context-grabber/commit/436837c); verified on the host (`WhiteboardResponderTests`: Larry ticked until the Cockpit says) and the Mac build. A new board's Responder on the live Cockpit not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing to talk with Larry
- **I want to** have Larry answer my boards without picking him on each one
- **so that** the board is a conversation with him from the first stroke, and Sonnet answers only where I chose it

#### Acceptance Criteria:
- **Scenario:** A new board
- **Given:** a board I just made
- **When:** it opens
- **Then:** its Responder is Larry, here and on my other devices

---

### User Story 962:

- **Summary:** An old board nobody set is given to Larry when I open it
- **Issues:** Igor on his board, 2026-11-17: "Let's make Larry default responder"
- **Status:** implemented in [436837c](https://github.com/idvorkin/context-grabber/commit/436837c); verified on the host (`WhiteboardResponderTests`: a never-set board given to Larry) and the Mac build. The write on open not yet seen against the live Cockpit or on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing to talk with Larry
- **I want to** have Larry answer my boards without picking him on each one
- **so that** the board is a conversation with him from the first stroke, and Sonnet answers only where I chose it

#### Acceptance Criteria:
- **Scenario:** An old board nobody set
- **Given:** a board from before, whose responder was never set
- **When:** I open it
- **Then:** its Responder becomes Larry, and the session log says it was the default

---

### User Story 963:

- **Summary:** A board I set keeps the responder I chose
- **Issues:** Igor on his board, 2026-11-17: "Let's make Larry default responder"
- **Status:** implemented in [436837c](https://github.com/idvorkin/context-grabber/commit/436837c); verified on the host (`WhiteboardResponderTests`: a set board kept, a Cockpit that doesn't say `set` counts as set) and the Mac build
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing to talk with Larry
- **I want to** have Larry answer my boards without picking him on each one
- **so that** the board is a conversation with him from the first stroke, and Sonnet answers only where I chose it

#### Acceptance Criteria:
- **Scenario:** A board I set
- **Given:** a board I set to Sonnet
- **When:** I open it
- **Then:** it stays Sonnet

---

### User Story 660:

- **Summary:** Claude is asked half a second after I lift the Pencil, not a second
- **Status:** superseded by story 892 (the wait follows my rhythm, 1.5 to 5 s); was implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (WhiteboardResponderTests.testThePauseIsHalfASecond (gone: replaced by story 892's rhythm wait in c9219b98); the pause's own rules unchanged in `WhiteboardPacerTests`). The feel on the iPad not yet tried
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Ghosts from Claude*

#### Use Case:
- **As someone** drawing with Claude
- **I want to** see ghosts sooner after I stop
- **so that** it feels like drawing together, not waiting for a turn

#### Acceptance Criteria:
- **Scenario:** A shorter pause
- **Given:** *Ask at my pauses* is on
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
- **Given:** *Ask at my pauses* is on
- **When:** I draw, pause, and a ghost turn goes
- **Then:** its session-log line has `pause_ms`, `render_ms`, `encode_ms` and `upload_ms` beside who answered, and the Cockpit's log of that turn has the pause, render and encode times

---

### User Story 662:

- **Summary:** A Larry board sends him one picture at a time, the newest
- **Issues:** the stale-push UI test, 2026-11-17: on a board's first turn, which opens its thread, an answer that landed before the board first looked was taken as already there, so the note kept *Larry has been looking* and never said it. Every row on a thread the turn opened is his answer; fixed in [3d91a5d](https://github.com/idvorkin/context-grabber/commit/3d91a5d), verified by host tests (`WhiteboardMarksTests`) and on the simulator (`testAStalePushMovesNothingAndLarryIsTold` (since bead context-grabber-3rk folded into `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`), rung 2)
- **Status:** implemented in [41b83fb](https://github.com/idvorkin/context-grabber/commit/41b83fb); verified on the host (`WhiteboardLarryTurnTests`: a pause while idle sends, a pause while he is looking doesn't, his answer with the board moved on sends once and with nothing new sends nothing, the 3-minute timeout, a tap taking over what was waiting, words carried, a failed picture freeing the turn). Not yet seen on the iPad or against the real Larry; a tap while he is looking with nothing new sending nothing (story 765) in [61761b8](https://github.com/idvorkin/context-grabber/commit/61761b8), verified by host tests (`WhiteboardLarryTurnTests`); the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`); Larry closing a turn with nothing to say (#913) is stories 811–813
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
- **When:** I tap *Send to Larry*
- **Then:** a picture of the board goes at once with any words that waited, and his answer to the earlier one sends nothing more; with nothing new since his picture went, the tap sends nothing (story 765)

---

### User Story 811:

- **Summary:** Larry closing the turn with nothing to add ends it
- **Status:** implemented in [462676e](https://github.com/idvorkin/context-grabber/commit/462676e); verified by host tests (`WhiteboardLarryTurnTests`, `WhiteboardLarryWaitTests`, `WhiteboardLarryClockTests`: done with nothing new sends nothing and says *Larry: nothing to add yet*, done with the board moved on sends one picture); not yet seen on the simulator or the iPad
- **Issues:** [#913](https://github.com/idvorkin/context-grabber/issues/913) (Larry marked the picture done with no reply, and the bar sat at *Larry · 0:54*)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see his turn end when he marks my picture done and has nothing to say
- **so that** the board never sits on his clock waiting for an answer that isn't coming

#### Acceptance Criteria:
- **Scenario:** He closes the turn with nothing to add
- **Given:** a Larry board, a picture sent and the bar showing Larry's clock
- **When:** Larry marks the picture done on the thread and writes no reply after it
- **Then:** the clock stops and the bar's note says *Larry: nothing to add yet* until the next turn starts; if I drew or spoke since the picture went, exactly one fresh picture goes, else nothing; the session log says the turn ended as done with no reply

---

### User Story 812:

- **Summary:** A reply after Larry closed the turn sends nothing more
- **Status:** implemented in [462676e](https://github.com/idvorkin/context-grabber/commit/462676e); verified by host tests (`WhiteboardLarryTurnTests`: a late reply sends nothing more); not yet seen on the simulator or the iPad
- **Issues:** [#913](https://github.com/idvorkin/context-grabber/issues/913) (Larry marked the picture done with no reply, and the bar sat at *Larry · 0:54*)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** have a reply he writes after closing the turn not send the board again
- **so that** his thread never gets the same board twice

#### Acceptance Criteria:
- **Scenario:** His reply comes after he closed the turn
- **Given:** Larry marked the picture done with no reply, and the turn ended
- **When:** a reply of his lands on the thread afterwards
- **Then:** no further picture goes for a board that hasn't moved on since

---

### User Story 813:

- **Summary:** Larry having the picture keeps his turn out
- **Status:** implemented in [462676e](https://github.com/idvorkin/context-grabber/commit/462676e); verified by host tests (`WhiteboardLarryWaitTests`: received and seen keep the turn out); not yet seen on the simulator or the iPad
- **Issues:** [#913](https://github.com/idvorkin/context-grabber/issues/913) (Larry marked the picture done with no reply, and the bar sat at *Larry · 0:54*)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** have his turn stay out while he has the picture but hasn't finished
- **so that** a picture he is still working on isn't treated as answered

#### Acceptance Criteria:
- **Scenario:** He has the picture but hasn't finished
- **Given:** a Larry board and a picture sent
- **When:** the thread says the Cockpit received it, or Larry has picked it up, and nothing more
- **Then:** the clock keeps running and no picture goes

---

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
- **When:** I tap *Send to Larry* with new ink
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
- **When:** I tap *Send to Larry*
- **Then:** the bar's note begins *Larry · 0:00* and counts until he answers

---

### User Story 765:

- **Summary:** Send to Larry is dimmed once Larry has this picture, until the next stroke
- **Status:** implemented in [61761b8](https://github.com/idvorkin/context-grabber/commit/61761b8); verified by host tests (`WhiteboardLarryTurnTests`: a repeat tap with nothing new sends nothing, a pause that sent counts too, a stroke, waiting words or another part of the board on screen send, a failed picture lets the same board go again; `WhiteboardLarryClockTests.testARepeatTapIsAnsweredForTwoSeconds`; `just native-test`) and the Mac build (`just native-build-mac`). The whiteboard's UI classes passed on the iPad simulator with it in (`just test-ladder`, at 98878ae), though none of them makes a repeat tap. Another part of the board on screen sending was added after that run and is verified on the host only. Not yet seen on the iPad; *Larry's turn* and *Send to Larry* made one button (story 1176) in [90663552](https://github.com/idvorkin/context-grabber/commit/90663552), verified by host tests and the whiteboard UI tests on the iPad simulator. Dimmed until the next stroke once Larry has this picture, reverting story 1176's *with no turn out a tap always sends* (bead context-grabber-x3tm): [eeb806e4](https://github.com/idvorkin/context-grabber/commit/eeb806e4), its `larry_has` log in [3cd2e198](https://github.com/idvorkin/context-grabber/commit/3cd2e198); verified by host tests (`just native-test`, `WhiteboardLarryTurnTests`) and the iPad simulator (rung 2, 2026-11-22, the Mac locked with the lock probe overridden on Igor's word: `WhiteboardLarryWaitUITests` 3 of 3 and `WhiteboardTurnUITests` 8 of 8), `testSendIsDimmedOnceLarryHasTheBoardUntilTheNextStroke` among them; not yet seen on the iPad.
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) (seven identical pictures in twelve seconds); bead context-grabber-x3tm (Igor, 2026-11-22: dimmed until the next stroke once Larry has this picture, reverting story 1176's *with no turn out a tap always sends*)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *A repeat tap sends nothing*

#### Use Case:
- **As someone** waiting on Larry and not sure my tap took
- **I want to** see that he already has the picture
- **so that** his thread isn't filled with copies and I know there is nothing to send

#### Acceptance Criteria:
- **Scenario:** Nothing new since the picture
- **Given:** Larry is looking at a picture, I have drawn and said nothing since, and the same part of the board is on screen
- **When:** I look at *Send to Larry* (one button since story 1176)
- **Then:** it is dimmed, and VoiceOver's hint says Larry already has this board; had I drawn a stroke, said something or scrolled to another page, it would light and a tap would send a fresh picture at once and restart the clock

- **Scenario:** He has answered
- **Given:** Larry has answered the picture, and I have drawn and said nothing since, with the same part of the board on screen
- **When:** I look at *Send to Larry*
- **Then:** it is still dimmed, until my next stroke, words or other pages on screen

- **Scenario:** A picture that didn't reach him, or Interrupt
- **Given:** a Send refused or deleted from the Inbox, or a turn I interrupted (story 805)
- **When:** I look at *Send to Larry* with nothing new drawn
- **Then:** it is lit, and a tap sends the picture

---

### User Story 766:

- **Summary:** The board's note is one line that opens into the conversation
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea), its line kept while empty in [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6) (the iPad simulator: `WhiteboardPaperGhostsUITests`' push and stale-push tests measured the ink 24 points lower once his state showed, and pass with it); verified by host tests (`WhiteboardNoteTests`: the line's state with *next:*, the middle and which end it keeps, a message giving the middle back after five seconds and one about the Cockpit not answering keeping it, *3 to keep*; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder` at 98878ae: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply` with the whiteboard's other UI classes). The Cockpit-not-answering messages keeping the middle was added after that run and is verified on the host only. Not yet seen on the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation"); [#882](https://github.com/idvorkin/context-grabber/issues/882) (the panel's live rows were drawn over each other)
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

- **Scenario:** The note first speaks
- **Given:** a board just opened, its note saying nothing yet, with ink on it
- **When:** I ask Larry and his state shows in the note
- **Then:** the ink stays exactly where it was on screen

---

### User Story 767:

- **Summary:** The note says what goes to Larry next
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea); verified by host tests (`WhiteboardNoteTests`: *next: ink*, *next: words* and *next: ink + words*, and the panel's chip with the waiting words, which took the *Next* row's place in #1003; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** drawing and talking while Larry is still looking
- **I want to** see what is waiting to go to him when he answers
- **so that** I know my new ink and words weren't lost and needn't tap to send them

#### Acceptance Criteria:
- **Scenario:** What is waiting
- **Given:** Larry is looking
- **When:** I draw and speak
- **Then:** the note's state says *next: ink + words*

---

### User Story 768:

- **Summary:** A tap on the note opens the conversation above the board
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea), [128a18c](https://github.com/idvorkin/context-grabber/commit/128a18c); the live rows one under another (#882) in [98878ae](https://github.com/idvorkin/context-grabber/commit/98878ae); verified by host tests (`WhiteboardNoteTests`: the tap on an iPad, the last ten messages with their marks, what is live, a board with no thread; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder` at 98878ae: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply` with the whiteboard's other UI classes). Not yet seen on the iPad: the Pencil on and below the panel is the iPad's check. Above the board, pushing the page down: [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129) (#1003, story 1048); #1039 moved the note's strip, the problem row with Retry and Dismiss, the panel and its scrolling text to their own file with no change in behaviour, verified by the host tests, the Mac build and the simulator smoke's whiteboard section (the iPhone's look-only boards; 2026-11-21); the iPad simulator's whiteboard classes wait on the Mac's screen unlocking; on the iPad simulator (2026-11-21, main 0228020e) the moved strip no longer followed the model: its count of marks to keep and Keep all stayed as first drawn (six of `WhiteboardPaperGhostsUITests` and `WhiteboardTurnUITests` failed); the drawing screen now hands the strip and the panel what they show as values (context-grabber-c59d, context-grabber-zem0) in [d35562c3](https://github.com/idvorkin/context-grabber/commit/d35562c3), verified by the host tests (`just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder --rung 2` on main c572c2a8 with the fix: all of `WhiteboardPaperGhostsUITests` and `WhiteboardTurnUITests` that failed now pass; 2026-11-21)
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation"); [#882](https://github.com/idvorkin/context-grabber/issues/882) (the panel's live rows were drawn over each other); [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the panel covered ink); [#1039](https://github.com/idvorkin/context-grabber/issues/1039) (bead context-grabber-gsfm: the strip, the panel and its text moved out of the drawing screen's file, so changes to one stop overlapping the other); bead context-grabber-c59d (after that move the strip's "N to keep" and Keep all went stale: the toolbar said 3 marks showing, the strip still 2 to keep); bead context-grabber-zem0 (the same six UI tests red on main, 2026-11-21)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** drawing and talking with Larry on a board
- **I want to** open the note and read what was said in full
- **so that** his reply and my own words aren't cut off, and reading them doesn't take me off the board

#### Acceptance Criteria:
- **Scenario:** Open it
- **Given:** a board with a thread, on an iPad
- **When:** I tap the line with a finger
- **Then:** a panel above the board shows the last messages of the thread in full and, under them, the status chip (story 1047); the page moves down to make room so no ink is under it (story 1048, #1003; until then it lay over the board), and the Pencil still draws below it

---

### User Story 1048:

- **Summary:** The open conversation pushes the page down and never covers ink
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by host tests (`WhiteboardNoteTests`; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder`: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply`: the paper's ? button below the open panel and moving back up when it closes, with the whiteboard's other UI classes). Not yet seen on the iPad
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** drawing with Larry on an iPad, with ink at the top of the page
- **I want to** open the conversation and still see every line I wrote
- **so that** reading Larry never hides what I am talking about

#### Acceptance Criteria:
- **Scenario:** Open it over ink
- **Given:** a board with ink on its top line and a thread, on an iPad
- **When:** I tap the note's line
- **Then:** the panel opens above the paper and the page moves down by its height, the top line of ink just under the panel and none of it under it; I tap again and the page moves back up

---

### User Story 1047:

- **Summary:** Igor's turns are one status chip, in one vocabulary
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by host tests (`WhiteboardNoteTests`; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder`: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply`: no row for a wordless picture and the chip *Your board · Sent*). Not yet seen on the iPad. That UI test's chip now reads *Your board · Answered* (story 1161)
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading Larry's replies in the open conversation
- **I want to** see his sentences one after another and one place that says where my picture is
- **so that** the panel is the conversation, not a log of *Your turn on the board · done* rows in four different words

#### Acceptance Criteria:
- **Scenario:** Three wordless turns
- **Given:** a thread of three pictures I sent without words, each answered by Larry
- **When:** I open the conversation
- **Then:** it shows Larry's three replies one after another with no *You: Your turn on the board* row, and under them one chip, *Your board · Answered*; while a turn is out the chip says what the closed line says, *Your board · Larry · 0:12 · next: ink*; a picture that went with my spoken words shows as a row of those words

---

### User Story 1161:

- **Summary:** Larry's reply after my picture reads Answered, marked or not
- **Status:** implemented in [77b25596](https://github.com/idvorkin/context-grabber/commit/77b25596) (bead `context-grabber-l9u`; Larry's recommendation, Igor has not ruled); split from story 1047. Verified by host tests (`WhiteboardNoteTests.testAReplyIsAnsweredAndACockpitThatMarksNothingNeverSaysSent`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply` against the fake Cockpit, which marks nothing: the chip *Your board · Answered*). Not yet seen on the iPad
- **Issues:** bead `context-grabber-l9u` (the chip read *Your board · Sent* after Larry's reply, on a Cockpit that marks nothing)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading Larry's reply to my picture in the open conversation
- **I want to** see the chip say he answered once his reply is there
- **so that** a Cockpit that marks nothing never leaves my answered picture reading *Sent*

#### Acceptance Criteria:
- **Scenario:** His reply is the answer, marked or not
- **Given:** a Cockpit that puts no marks on messages, and a picture I sent without words
- **When:** Larry's reply, words or only marks, comes after it on the thread and I open the conversation
- **Then:** the chip reads *Your board · Answered*, never *Sent*; before his reply it reads *Your board · Larry has it*; on a Cockpit that marks, a reply after the picture is *Answered* too, whatever its mark

---

### User Story 1053:

- **Summary:** Larry's words lead, and every line can be read
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by host tests (`WhiteboardNoteTests`: Larry's line marked for emphasis; `just test`) and a screenshot on the iPad simulator (`WhiteboardTurnUITests`, Larry's words in the main colour). The contrast figures are from the colour values, not measured on the iPad
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** glancing at the note and the open conversation while I draw
- **I want to** have Larry's words stand out and the quieter text still be readable
- **so that** the grey status text at about 2:1 no longer strains my eyes and his reply is what I see first

#### Acceptance Criteria:
- **Scenario:** Read the note
- **Given:** Larry has replied and the conversation is open
- **When:** I look at the note and the panel
- **Then:** Larry's words are in the main text colour, in the closed line and in the panel; my lines, his state and the chip are quieter but at least 4.5:1 against what is behind them

---

### User Story 1045:

- **Summary:** The conversation's lines are about seventy characters
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by the Mac build and the iPad simulator run (`WhiteboardTurnUITests`); a reply long enough to wrap at seventy characters is for the iPad's eye
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading a long reply of Larry's on an iPad
- **I want to** have it wrap like a paragraph, not run across the whole board
- **so that** I can read it at a glance

#### Acceptance Criteria:
- **Scenario:** A long reply on a wide iPad
- **Given:** Larry's reply of several sentences and the iPad in landscape
- **When:** I open the conversation
- **Then:** his reply wraps at about seventy characters, the panel's background still spanning the width

---

### User Story 837:

- **Summary:** The conversation panel keeps its size and scrolls, newest in view
- **Status:** implemented in [e403844](https://github.com/idvorkin/context-grabber/commit/e403844); verified by host tests (`WhiteboardNoteTests.testThePanelIsAFifthOfTheBoardAtMost`; `just test`), the Mac build (`just native-build-mac`) and an iPad simulator (`WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply`: the panel's height, with the class's other tests); scrolling to the newest line with a long thread is for the iPad's eye
- **Issues:** [#917](https://github.com/idvorkin/context-grabber/issues/917) ("when chat expands it needs to scroll not grow"), seen in [#913](https://github.com/idvorkin/context-grabber/issues/913)'s screenshot, the panel over nearly half the page
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** talking with Larry on a board while I draw
- **I want to** keep the conversation panel small however long the conversation gets, with the newest words showing
- **so that** reading what he said never covers the page I'm drawing on

#### Acceptance Criteria:
- **Scenario:** A long conversation
- **Given:** a board whose thread has more messages than the panel holds, on an iPad
- **When:** I tap the note's line to open the panel
- **Then:** the panel is no taller than a fifth of the board, its newest line is in view at the bottom, and a finger scrolls up to the older ones

---

### User Story 1277:

- **Summary:** The open conversation reads as chat bubbles, like Chat and the web chat
- **Status:** implemented in [cd47c873](https://github.com/idvorkin/context-grabber/commit/cd47c873); verified by host tests (`WhiteboardPanelLookTests`; `just native-test`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`just test-ladder --rung 2` at cd47c873: `WhiteboardBubblesUITests` with `WhiteboardPanelScrollUITests`, `WhiteboardLinkChipUITests` and `WhiteboardTurnUITests`, 12/12, one of Turn's on its retry, bead context-grabber-3zil); the Pencil on the bubbles and their look beside the web chat are the real iPad's, not yet seen; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("Give me an alternate chat view so I can move chat to be like bubbles"; "I like the web view of chat")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *The conversation as chat*

#### Use Case:
- **As someone** talking with Larry on a board while I draw
- **I want to** read the board's conversation as chat bubbles, as in Chat and the Cockpit's web chat
- **so that** who said what is clear at a glance, without leaving the board

#### Acceptance Criteria:
- **Scenario:** Switch to bubbles
- **Given:** a board with a thread and its conversation open, on an iPad
- **When:** I tap **Bubbles** at the panel's foot
- **Then:** the same messages show as bubbles, mine on the right in the accent colour and Larry's on the left, links as chips; the panel keeps its size, opens at the newest bubble and scrolls with a finger, never the Pencil

- **Scenario:** The choice is kept
- **Given:** I picked **Bubbles** on one board
- **When:** I open another board's conversation
- **Then:** it opens in Bubbles; **Lines** brings back the panel as it was

---

### User Story 1278:

- **Summary:** A grip resizes the docked conversation, as on the web
- **Status:** implemented in [b2da55db](https://github.com/idvorkin/context-grabber/commit/b2da55db); verified by host tests (`WhiteboardPanelPlaceTests`; `just native-test`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`just test-ladder --rung 2` at b2da55db: `WhiteboardConversationPlaceUITests`, and `WhiteboardBubblesUITests`, `WhiteboardPanelScrollUITests`, `WhiteboardLinkChipUITests` beside it); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("chat resizable like it is on the web"; "like a popover that I can move over the page, or can be docked like it is right now")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** reading a long exchange with Larry on a board
- **I want to** drag the conversation taller or shorter
- **so that** I see as much of it as I want, and no more, while I draw

#### Acceptance Criteria:
- **Scenario:** Drag it taller
- **Given:** a board's conversation open above the board, on an iPad
- **When:** I drag the grip under it down with a finger
- **Then:** the panel grows with my finger, the page moves down with it so no ink is under it, it stops short of the whole board, and the next board's panel opens at that height

---

### User Story 1272:

- **Summary:** Dragged up, the docked conversation stops at about four lines
- **Status:** implemented in [b2da55db](https://github.com/idvorkin/context-grabber/commit/b2da55db); verified by host tests (`WhiteboardPanelPlaceTests`: the dragged height's bounds; `just native-test`) and the Mac build (`just native-build-mac`); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("chat resizable like it is on the web"; "like a popover that I can move over the page, or can be docked like it is right now")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** reading a long exchange with Larry on a board
- **I want to** drag the conversation as short as I like
- **so that** the board gets the room, and a few lines of Larry still show

#### Acceptance Criteria:
- **Scenario:** Drag it shorter
- **Given:** a board's conversation open above the board, on an iPad
- **When:** I drag the grip up as far as it goes
- **Then:** it stops at about four lines

---

### User Story 1275:

- **Summary:** A double tap on the grip gives the docked conversation its own size back
- **Status:** implemented in [b2da55db](https://github.com/idvorkin/context-grabber/commit/b2da55db); verified by the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`just test-ladder --rung 2` at b2da55db: `WhiteboardConversationPlaceUITests`: the double tap after a drag); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("chat resizable like it is on the web"; "like a popover that I can move over the page, or can be docked like it is right now")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** who dragged the conversation taller
- **I want to** put it back to its own size in one gesture
- **so that** I don't have to drag it back by hand

#### Acceptance Criteria:
- **Scenario:** Back to its own size
- **Given:** a panel I dragged taller
- **When:** I double-tap the grip
- **Then:** it is its own size again, a fifth of the board at most

---

### User Story 1279:

- **Summary:** The conversation floats over the board as a card I move and size, or docks above it
- **Status:** implemented in [b2da55db](https://github.com/idvorkin/context-grabber/commit/b2da55db); verified by host tests (`WhiteboardPanelPlaceTests`; `just native-test`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`just test-ladder --rung 2` at b2da55db: `WhiteboardConversationPlaceUITests`, and `WhiteboardBubblesUITests`, `WhiteboardPanelScrollUITests`, `WhiteboardLinkChipUITests` beside it); the Pencil on the card is the iPad's check; the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22); the top-left grip (#1491) in [b0e55746](https://github.com/idvorkin/context-grabber/commit/b0e55746), verified by host tests (`WhiteboardPanelPlaceTests`; `just test`) and the iPad Pro 11-inch (M5) simulator (`test-ladder --rung 2`: `WhiteboardConversationPlaceUITests` drags the top-left grip, the bottom right stays put); the real iPad not yet
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("chat resizable like it is on the web"; "like a popover that I can move over the page, or can be docked like it is right now"); [#1491](https://github.com/idvorkin/context-grabber/issues/1491) (Igor, 2026-11-25, board ink: "resize in top left corner"; Inbox 07:22: put the grip at the top left)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** drawing with Larry's conversation open
- **I want to** float it as a card over the board, where I choose, and dock it back
- **so that** it stays in view without pushing the page down, or out of the way when I need the whole board

#### Acceptance Criteria:
- **Scenario:** Float it
- **Given:** a board's conversation open above the board, on an iPad
- **When:** I tap **Float**
- **Then:** the page moves back up and the conversation is a card at the board's top left; dragging its top edge moves it, never off the board, and the grip at its top-left corner sizes it, growing up and left with its bottom right staying put, never smaller than a few lines and never past the board's top or left edge

---

### User Story 1313:

- **Summary:** Everything at the floating card's foot fits, at any size the card can be
- **Status:** implemented in [88aa3c94](https://github.com/idvorkin/context-grabber/commit/88aa3c94) (the foot) and [b972209c](https://github.com/idvorkin/context-grabber/commit/b972209c) (the fresh-panel hook); verified by host tests (`just test`, incl. `LaunchHooksTests` for `GRABBER_WHITEBOARD_PANEL=fresh`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`test-ladder --rung 2` on the pre-rebase build 98c77151: `WhiteboardConversationPlaceUITests`, the foot's controls inside the card on one line, and the smoke); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work)
- **Issues:** [#1416](https://github.com/idvorkin/context-grabber/issues/1416) (Igor, 2026-11-24, iPad: "This dialogue is a little wonky": at the card's first size *Open in Chat* and **Dock** wrapped and the foot was cut off)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** drawing with Larry's conversation floating as a card
- **I want to** see the card's whole foot, on one line, however small I make the card
- **so that** *Open in Chat*, Lines / Bubbles and **Dock** are always there to tap and nothing looks broken

#### Acceptance Criteria:
- **Scenario:** A narrow card
- **Given:** the conversation floating as a card, at its first size or the smallest its top-left grip allows
- **When:** I look at its foot
- **Then:** *Open in Chat*, Lines / Bubbles and **Dock** sit on one line, *Open in Chat* and **Dock** as icons when their words don't fit, nothing at the card's bottom is cut off, and each still works

---

### User Story 1307:

- **Summary:** The floating card stays where I left it, at its size
- **Status:** implemented in [b2da55db](https://github.com/idvorkin/context-grabber/commit/b2da55db); verified by host tests (`WhiteboardPanelPlaceTests`: the card kept as text; `just native-test`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`just test-ladder --rung 2` at b2da55db: `WhiteboardConversationPlaceUITests`: a relaunch finds the card where it was left); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("chat resizable like it is on the web"; "like a popover that I can move over the page, or can be docked like it is right now")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** who floated and placed Larry's conversation
- **I want to** find it where I put it on the next board
- **so that** I place it once, not every time

#### Acceptance Criteria:
- **Scenario:** It stays where I left it
- **Given:** I floated and moved the card
- **When:** I open another board's conversation
- **Then:** it floats where I left the card, at the card's size

---

### User Story 1308:

- **Summary:** Dock puts the floating conversation back above the board
- **Status:** implemented in [b2da55db](https://github.com/idvorkin/context-grabber/commit/b2da55db); verified by the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`just test-ladder --rung 2` at b2da55db: `WhiteboardConversationPlaceUITests`: Dock brings back the grip at its dragged height); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#1384](https://github.com/idvorkin/context-grabber/issues/1384) ("chat resizable like it is on the web"; "like a popover that I can move over the page, or can be docked like it is right now")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Resize, and float or dock*

#### Use Case:
- **As someone** with Larry's conversation floating
- **I want to** dock it above the board again
- **so that** it stops covering the page when I need the whole board

#### Acceptance Criteria:
- **Scenario:** Dock it
- **Given:** the conversation floating
- **When:** I tap **Dock**
- **Then:** it is above the board again, at its docked height, and pushes the page down

---

### User Story 887:

- **Summary:** Another reply scrolls the full panel, not grows it
- **Status:** implemented in [e403844](https://github.com/idvorkin/context-grabber/commit/e403844) (story 837, #917); verified by host tests (`WhiteboardNoteTests.testThePanelIsAFifthOfTheBoardAtMost`; `just test`); a reply landing in a full panel is for the iPad's eye; a reply while Igor reads an older message leaves the panel where he scrolled it, in [cd815f7d](https://github.com/idvorkin/context-grabber/commit/cd815f7d), verified by host tests (`WhiteboardNoteTests.testThePanelFollowsTheNewestOnlyFromTheBottom`; `just native-test`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`WhiteboardPanelScrollUITests`: fifteen long replies, the panel and the paper under it never moving, a reply after a finger scrolled up leaving it on the older messages, and following again from the bottom; with `WhiteboardTurnUITests`, `WhiteboardListeningUITests` and `WhiteboardLinkChipUITests`, 10/10); the real iPad not yet; no iPhone run (Igor's no-iPhone rule during the whiteboard work, 2026-11-22)
- **Issues:** [#917](https://github.com/idvorkin/context-grabber/issues/917); bead context-grabber-97s (a reply pulled the panel back down while Igor read an older message)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** with the conversation panel open while Larry talks (story 837)
- **I want to** see each new answer without the panel growing
- **so that** the page I'm drawing on stays where it was

#### Acceptance Criteria:
- **Scenario:** Another reply
- **Given:** the panel is open and full
- **When:** Larry answers again
- **Then:** the panel stays the same height and scrolls to show his answer

- **Scenario:** Another reply while I read an older one (bead context-grabber-97s)
- **Given:** the panel is open and full, and I have scrolled up to an older message
- **When:** Larry answers again
- **Then:** the panel stays the same height and where I scrolled it; once I scroll back to the bottom, his next answer
  scrolls into view again

---

### User Story 1184:

- **Summary:** What the mic hears never grows the conversation panel
- **Status:** implemented in [cd815f7d](https://github.com/idvorkin/context-grabber/commit/cd815f7d); verified by the Mac build (`just native-build-mac`) and the iPad simulator only as far as the status chip still drawing (`WhiteboardTurnUITests`, `WhiteboardListeningUITests`); the *Hearing* row itself isn't reached on any rung, as no simulator hook keeps the board's mic on, so a long sentence on the iPad is still to see
- **Issues:** bead context-grabber-97s (Larry, 2026-11-22: *"an expanded chat message/card grows to its full height instead of scrolling within a bounded height"*; Igor on the board, 2026-11-16 05:38, *"when chat expands it needs to scroll not grow"*, first fixed for the messages by story 837)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** talking to Larry with the board's mic on and the conversation panel open
- **I want to** see the newest of what the mic hears without the panel growing
- **so that** a long sentence never pushes the page I'm drawing on down the screen

#### Acceptance Criteria:
- **Scenario:** A long sentence
- **Given:** the panel is open on an iPad and the mic is on
- **When:** I say something that runs past two lines of the panel
- **Then:** its *Hearing* row is at most two lines, ending on my newest words, older ones dropped at an *…*; the
  status chip is at most two lines; the panel keeps its height and the paper under it doesn't move

---

### User Story 1001:

- **Summary:** Larry's words with no marks stay in the note and the panel, off the board
- **Status:** already true on main (only a reply's marks become ghosts, only its board changes are applied); pinned in [c8cc50d](https://github.com/idvorkin/context-grabber/commit/c8cc50d), verified by host tests (`WhiteboardWordsOnlyTests`: `testWordsAfterMarksAreSaidAndTheMarksStay`, `testOpeningOnWordsAfterSettledMarksShowsNothing`, `testTheReplayLeavesTheBoardAsItWas`; `just test`); not yet seen on the iPad
- **Issues:** [#898](https://github.com/idvorkin/context-grabber/issues/898) (asked 2026-11-12 on [#879](https://github.com/idvorkin/context-grabber/issues/879); Larry's bead `context-grabber-0q7`)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Closed: one line*

#### Use Case:
- **As someone** drawing with Larry on a board
- **I want to** have his words-only replies read as words, in the note and the panel
- **so that** the board holds only what was drawn on it, mine or the marks he means to draw

#### Acceptance Criteria:
- **Scenario:** Words after marks
- **Given:** Larry's marks from his last reply showing on the board
- **When:** he replies in words only
- **Then:** his words are the note's line and the newest message in the panel, nothing new is on the board or offered to keep, and his earlier marks are where they were

---

### User Story 1002:

- **Summary:** A board whose thread holds only Larry's words draws nothing of his
- **Status:** already true on main; split from story 1001, pinned in [c8cc50d](https://github.com/idvorkin/context-grabber/commit/c8cc50d), verified by host tests (`WhiteboardWordsOnlyTests.testAThreadOfOnlyWordsDrawsNothing`, which also opens the board on that thread and finds nothing drawn; `just test`); not yet seen on the iPad
- **Issues:** [#898](https://github.com/idvorkin/context-grabber/issues/898)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Closed: one line*

#### Use Case:
- **As someone** drawing with Larry on a board
- **I want to** have his answer in words read as words, even when he has never drawn on the board
- **so that** the board holds only what was drawn on it

#### Acceptance Criteria:
- **Scenario:** Only words
- **Given:** a board whose thread holds only Larry's words
- **When:** he answers my picture in words
- **Then:** nothing of his is on the board, and the panel shows what he said

---

### User Story 769:

- **Summary:** On an iPhone a tap on the note opens the board's thread in Chat
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea); a tap that finds no thread says where the conversation is, and `conversation_chat` logs found, in [f5453423](https://github.com/idvorkin/context-grabber/commit/f5453423) (#1161), and it finds an iPad's board's thread among Larry's chats in [a43e6bf](https://github.com/idvorkin/context-grabber/commit/a43e6bfd) (#1163, story 1110); the board carries its thread through iCloud and the tap opens it first in [2f80d144](https://github.com/idvorkin/context-grabber/commit/2f80d144) (#1161, option B), verified by host tests (`BoardIndexTests`: a thread iCloud lacks sends the board up without new ink, one sent up without ink reaches the phone with no download; `WhiteboardNoteTests.testATapOnAPhoneOpensTheThreadTheBoardCarriesThroughICloud`; `just native-test`) and the Mac build (`just native-build-mac`); the CloudKit round trip (iPad up, iPhone down) is owed on the devices, and rung 2 is owed (the simulator has no iCloud account and was wedged on 2026-11-22); TestFlight needs the production schema deployed first; earlier, verified by host tests (`WhiteboardNoteTests`, `BoardThreadFindTests`: the tap on an iPhone with a thread and with none, `testATapWithNoThreadOnThisPhoneSaysWhereTheConversationIs`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPhone; a thread the Cockpit lost comes off the board's iCloud record, and one started from the outbox goes up at once, in [740ec791](https://github.com/idvorkin/context-grabber/commit/740ec791) (bead context-grabber-e3vb), verified by host tests (`BoardIndexTests.testAThreadTheCockpitLostComesOffTheRecord`, `testAThreadSentUpWithoutInkReachesThePhoneWithNoDownload`, `WhiteboardMarksTests.testAForgottenThreadStaysGoneAfterANewOneStarts`; `just native-test`) and the Mac build (`just native-build-mac`); rung 2 and the devices' CloudKit round trip are owed
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation"); [#1161](https://github.com/idvorkin/context-grabber/issues/1161) ("on the iPhone I should be able to interact with the chat": a tap on an iPad's board did nothing); [#1163](https://github.com/idvorkin/context-grabber/issues/1163), a board drawn on the iPad (story 1110); bead context-grabber-e3vb, a thread the Cockpit lost stayed on the board's iCloud copy
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** looking at a board on the iPhone
- **I want to** get from the note to the board's conversation
- **so that** I can read what Larry said where there is room for it

#### Acceptance Criteria:
- **Scenario:** On a phone
- **Given:** a board with a thread, on an iPhone
- **When:** I tap the note's line
- **Then:** Chat opens on the board's thread

- **Scenario:** The board carries its thread through iCloud
- **Given:** a board drawn on the iPad and sent to Larry, synced since, open on an iPhone that never sent it
- **When:** I tap the note's line
- **Then:** Chat opens on the board's thread at once, and the session log's `conversation_chat` says it was found in iCloud

- **Scenario:** A thread the Cockpit no longer has
- **Given:** a board drawn on the iPad whose thread the Cockpit has lost, so the iPad's next picture to it was refused
- **When:** the iPad's sync that follows at once has run, and I tap the note's line on the iPhone
- **Then:** Chat doesn't open the dead thread; the note looks among the chats or says where the conversation is, as for a board with no thread, and the iPad's `whiteboard_sync` counts the board in `threads_cleared`

- **Scenario:** No thread on this phone
- **Given:** a board drawn on the iPad, on an iPhone that never sent it to Larry, carrying no thread through iCloud, and no chat among Larry's that came from it (story 1110)
- **When:** I tap the note's line
- **Then:** Chat doesn't open, and the note says *Larry's conversation is on the iPad* for a few seconds

- **Scenario:** A board that never went to Larry
- **Given:** a board drawn on this iPhone that has no thread
- **When:** I tap the note's line
- **Then:** the note says *No conversation with Larry yet*

---

### User Story 1097:

- **Summary:** On an iPhone every board in the list has a chat bubble that opens its thread
- **Status:** implemented in [a43e6bf](https://github.com/idvorkin/context-grabber/commit/a43e6bfd); verified by host tests (`BoardThreadFindTests`; `just native-test`) and the Mac build (`just native-build-mac`); the simulator (rung 2) and the iPhone are owed. The thread from the board's iCloud record first, the chat search kept as a stopgap for boards not sent up since, in [2f80d144](https://github.com/idvorkin/context-grabber/commit/2f80d144) (#1161), verified by host tests (`BoardIndexTests`: a thread iCloud lacks sends the board up without new ink, one sent up without ink reaches the phone with no download; `WhiteboardNoteTests.testATapOnAPhoneOpensTheThreadTheBoardCarriesThroughICloud`; `just native-test`) and the Mac build (`just native-build-mac`); the CloudKit round trip (iPad up, iPhone down) is owed on the devices, and rung 2 is owed (the simulator has no iCloud account and was wedged on 2026-11-22); TestFlight needs the production schema deployed first; a thread the Cockpit lost comes off the board's iCloud record, and one started from the outbox goes up at once, in [740ec791](https://github.com/idvorkin/context-grabber/commit/740ec791) (bead context-grabber-e3vb), verified by host tests (`BoardIndexTests.testAThreadTheCockpitLostComesOffTheRecord`, `testAThreadSentUpWithoutInkReachesThePhoneWithNoDownload`, `WhiteboardMarksTests.testAForgottenThreadStaysGoneAfterANewOneStarts`; `just native-test`) and the Mac build (`just native-build-mac`); rung 2 and the devices' CloudKit round trip are owed
- **Issues:** [#1163](https://github.com/idvorkin/context-grabber/issues/1163), [#1161](https://github.com/idvorkin/context-grabber/issues/1161) ("Maybe I should have a chat button on every board when I'm in this view on the iPhone … maybe something subtle"); bead context-grabber-e3vb, a thread started from the outbox waited for an unrelated sync, and a lost one stayed on the board
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *The board's chat from the iPhone*

#### Use Case:
- **As someone** looking through boards on the iPhone
- **I want to** get from a board in the list straight to what Larry and I said about it
- **so that** I can read the conversation without opening the board first

#### Acceptance Criteria:
- **Scenario:** A board drawn on the iPad
- **Given:** the boards list on an iPhone, with a board drawn on the iPad that has a thread with Larry
- **When:** I tap the quiet chat bubble at the end of its row
- **Then:** that board's thread slides in over the list, and *Back* comes back to the list (bead context-grabber-dbku); a tap elsewhere on the row still opens the board, and a board with no thread says *No chat with Larry for this board yet*, copyably, filing no report

- **Scenario:** The thread comes with the board
- **Given:** a board the iPad sent to Larry and has synced since
- **When:** I tap its bubble on the iPhone
- **Then:** Chat opens on its thread at once, with no looking among the chats, and the session log's `chat_lookup` says the thread came from iCloud

- **Scenario:** A thread started from the outbox
- **Given:** a new board's first picture that waited in the iPad's outbox while the Cockpit was away
- **When:** the outbox sends it and its thread starts
- **Then:** the iPad syncs at once (`whiteboard_sync` why `outbox_thread`), so the iPhone's bubble opens the new thread without waiting for the board to close

- **Scenario:** A reinstall never clears a thread
- **Given:** a board drawn on the iPad that carries its thread through iCloud
- **When:** the app is reinstalled on the iPad and its boards come back from iCloud
- **Then:** the board still carries its thread, since only a thread the Cockpit said is gone is cleared

---

### User Story 1110:

- **Summary:** On an iPhone the note finds the thread of a board drawn on another device
- **Status:** implemented in [a43e6bf](https://github.com/idvorkin/context-grabber/commit/a43e6bfd); verified by host tests (`BoardThreadFindTests`; `just native-test`) and the Mac build (`just native-build-mac`); the simulator (rung 2) and the iPhone are owed. Numbered 1101 until 2026-11-22, when #1170's story had the same number (bead context-grabber-jt6n). The thread from the board's iCloud record first in [2f80d144](https://github.com/idvorkin/context-grabber/commit/2f80d144) (#1161), verified by host tests (`BoardIndexTests`: a thread iCloud lacks sends the board up without new ink, one sent up without ink reaches the phone with no download; `WhiteboardNoteTests.testATapOnAPhoneOpensTheThreadTheBoardCarriesThroughICloud`; `just native-test`) and the Mac build (`just native-build-mac`); the CloudKit round trip (iPad up, iPhone down) is owed on the devices, and rung 2 is owed (the simulator has no iCloud account and was wedged on 2026-11-22); TestFlight needs the production schema deployed first
- **Issues:** [#1163](https://github.com/idvorkin/context-grabber/issues/1163), [#1161](https://github.com/idvorkin/context-grabber/issues/1161) (the session log: a tap on the note of a board drawn on the iPad logged no thread and did nothing)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *The board's chat from the iPhone*

#### Use Case:
- **As someone** looking at a board on the iPhone that I drew on the iPad
- **I want to** have the note's tap open the board's conversation, as it does for a board this phone sent
- **so that** a tap is never silently ignored

#### Acceptance Criteria:
- **Scenario:** A board the iPhone never sent
- **Given:** a board drawn on the iPad, with a thread with Larry, open on an iPhone that never sent it
- **When:** I tap the note's line
- **Then:** Chat opens on the board's thread: the one the board carries through iCloud (#1161), else one found among Larry's chats by a message that came from this board, a stopgap for boards the iPad hasn't synced since; with none, the note says *Larry's conversation is on the iPad* for a few seconds (story 769)

- **Scenario:** A board from before the thread rode with it
- **Given:** a board that talked with Larry before boards carried their thread, and an iPad that has synced with this build since
- **When:** I tap the note's line on the iPhone
- **Then:** Chat opens on the board's thread from iCloud; the iPad sent it up on that sync without any new ink

---

### User Story 773:

- **Summary:** The board says whether Larry has picked the picture up
- **Status:** implemented in [d055f34](https://github.com/idvorkin/context-grabber/commit/d055f34), reconciled with stories 775–777 (one reading of the mark, 20 s) in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryClockTests`: `testUntilHePicksItUpTheStateSaysSent`, `testARepeatTapStillSaysLarryAlreadyHasThis`, `testVoiceOverSaysSentInWords`, `testHisSilenceSaysWhereThePictureWas`; `WhiteboardLarryWaitTests`: `testThePicturesOwnMarkSaysWhereItIs`, `testASendToLarryIsReadByTheNewestMessageSinceThePicture`, `testNoTurnOutIsUnknown`; `WhiteboardNoteTests.testTheLineAndThePanelSayWhetherHeHasThePicture`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Where the picture is*

#### Use Case:
- **As someone** waiting on Larry at the board
- **I want to** see whether he has picked my picture up yet
- **so that** I can tell "Larry is thinking" from "Larry never got it" without guessing from the clock

#### Acceptance Criteria:
- **Scenario:** Sent, then with Larry
- **Given:** a picture has just gone to Larry and the Cockpit has marked it *received*
- **When:** he picks it up four seconds later
- **Then:** the note's state reads *Sent · 0:03* and then *Larry · 0:04*, the clock never restarting; had he not picked it up in twenty seconds it would read *Sent · 0:21 · not picked up yet*, VoiceOver saying *Sent 21 seconds ago, not picked up yet*, with *Interrupt* beside it (story 777)

---

### User Story 801:

- **Summary:** On a Cockpit that marks nothing the board never says Sent
- **Status:** implemented in [d055f34](https://github.com/idvorkin/context-grabber/commit/d055f34), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 773. Verified by host tests (`WhiteboardLarryWaitTests.testAnOlderCockpitIsNeverStuck`, `WhiteboardLarryClockTests.testTheClockCountsFromThePicture`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad. The panel's chip is story 1162
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Where the picture is*

#### Use Case:
- **As someone** waiting on Larry at the board, against a Cockpit from before it marked messages
- **I want to** see the state read as it always did
- **so that** a missing mark is never read as news about my picture

#### Acceptance Criteria:
- **Scenario:** An older Cockpit
- **Given:** a Cockpit that puts no marks on messages
- **When:** a picture goes and he is slow
- **Then:** the state reads *Larry · 0:42* throughout, never *Sent*

---

### User Story 1162:

- **Summary:** On a Cockpit that marks nothing the panel's chip never says Sent
- **Status:** implemented in [77b25596](https://github.com/idvorkin/context-grabber/commit/77b25596) (bead `context-grabber-l9u`; Larry's recommendation, Igor has not ruled); split from story 801. Verified by host tests (`WhiteboardNoteTests.testAReplyIsAnsweredAndACockpitThatMarksNothingNeverSaysSent`; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply` against the fake Cockpit: the chip *Your board · Answered*). Not yet seen on the iPad
- **Issues:** bead `context-grabber-l9u` (the panel's chip read *Sent*)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Where the picture is*

#### Use Case:
- **As someone** opening the conversation against a Cockpit from before it marked messages
- **I want to** see the chip say where my picture is without a mark to go on
- **so that** a missing mark is never read as *Sent*

#### Acceptance Criteria:
- **Scenario:** The chip after the turn
- **Given:** a Cockpit that puts no marks on messages
- **When:** no turn is out and I open the conversation
- **Then:** the chip reads *Your board · Larry has it* for a picture with no reply yet and *Your board · Answered* once his reply follows it, never *Sent*

---

### User Story 775:

- **Summary:** A picture that hasn't reached the Cockpit in 20 seconds offers Retry
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), reconciled with story 773 in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryWaitTests`: `testNoMarkAtTwentySecondsIsStuckWithRetryAndDismiss`, `testNoMarkIsStuckOnlyOnACockpitThatMarks`, `testTheMarkIsFoundByTheMessagesId`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad, nor against a hung Cockpit. Retry itself, a Cockpit that marks nothing and a picture that lands after all are stories 802–804; seen on the iPad simulator in [#1242](https://github.com/idvorkin/context-grabber/pull/1242) (a UI test of a stuck picture, against the fake Cockpit: *Retry* and *Dismiss* showing, no *Interrupt*); since story 1176 that test's picture is a *Send*, so it is now `WhiteboardLarryWaitUITests.testASlowSendOffersNoRetry` (bead context-grabber-x3tm): no *Retry* or *Dismiss* while the Cockpit holds it, and his answer lands once it is taken. A pause's own stuck picture is held on the host only. A Send offers no Retry, only Interrupt; Retry stays for a pause's own picture (bead context-grabber-x3tm, Igor's card 4): [7f187416](https://github.com/idvorkin/context-grabber/commit/7f187416); verified by host tests (`just native-test`, `WhiteboardLarryTurnTests`) and the iPad simulator (rung 2, 2026-11-22, the Mac locked with the lock probe overridden on Igor's word: `WhiteboardLarryWaitUITests` 3 of 3 and `WhiteboardTurnUITests` 8 of 8), `testASlowSendOffersNoRetry` among them.
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing on a board the real Larry answers ("I think Larry got stuck. I need interrupt/retry button after 20s!")
- **I want to** be told when a picture I sent hasn't reached the Cockpit, and send it again with one tap
- **so that** I'm never left guessing whether Larry is slow or never got it

#### Acceptance Criteria:
- **Scenario:** The picture never lands
- **Given:** a picture sent to Larry, with no mark from the Cockpit on its message
- **When:** twenty seconds pass
- **Then:** the bar shows *Larry hasn't got the picture* as a problem I can copy, with *Retry* and *Dismiss* beside it, and the canvas is not covered

- **Scenario:** A Send the Cockpit is slow to take (story 1176; Igor, 2026-11-22: Interrupt only, no Retry beside it)
- **Given:** I tapped *Send to Larry* and the Cockpit hasn't taken the picture after twenty seconds
- **When:** I look at the bar
- **Then:** there is no *Retry* and no *Dismiss*: the Send is the outbox's to retry, and it goes by itself once the Cockpit takes it; *Retry* is only for a picture the board handed him itself after a pause

---

### User Story 802:

- **Summary:** Retry sends the stuck picture again, once
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 775. Verified by host tests (`WhiteboardLarryWaitTests`: `testRetryStartsTheTwentySecondsAgainOnTheSamePicture`, `testAFailureOfThePictureBeforeRetryNeverFreesTheRetriedTurn`, `testAHandOffReplacedByRetryOrDismissSpeaksNoMore`; `LaunchHooksTests`: the hook that taps it, `GRABBER_WHITEBOARD_LARRY_WAIT=retry`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad, nor against a hung Cockpit; seen on the iPad simulator in [#1242](https://github.com/idvorkin/context-grabber/pull/1242) (then a UI test of a stuck picture: a tap on *Retry* lands the same picture and the problem and the clock go with his answer); since bead context-grabber-x3tm a Send offers no Retry, and `WhiteboardLarryWaitUITests.testASlowSendOffersNoRetry` checks there is no *Retry* or *Dismiss* while the Cockpit holds it and that his answer lands once it is taken; Retry on a pause's own picture is the host's only
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** told that my picture hasn't reached Larry
- **I want to** send it again with one tap
- **so that** he gets it, and gets it once even if the first one did land

#### Acceptance Criteria:
- **Scenario:** I retry
- **Given:** the bar shows *Larry hasn't got the picture*
- **When:** I tap *Retry*
- **Then:** the same picture goes again under the same message, the clock goes back to 0:00, the problem goes, and the session log says I retried; if the first one did land, the thread still holds it once

---

### User Story 803:

- **Summary:** A Cockpit that marks nothing never looks stuck
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 775. Verified by host tests (`WhiteboardLarryWaitTests`: `testNoMarkIsStuckOnlyOnACockpitThatMarks`, `testAnOlderCockpitIsNeverStuck`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing with Larry against a Cockpit from before it marked messages
- **I want to** never be told a picture is stuck when the board can't know
- **so that** I don't resend pictures he already has

#### Acceptance Criteria:
- **Scenario:** A Cockpit that marks nothing
- **Given:** an older Cockpit, whose messages carry no marks
- **When:** twenty seconds pass on any picture
- **Then:** the board never says *Larry hasn't got the picture* and never offers *Retry*; it offers *Interrupt* (story 777)

---

### User Story 804:

- **Summary:** A stuck picture that lands after all stops looking stuck
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 775. Verified by host tests (`WhiteboardLarryWaitTests`: `testAPictureTheCockpitAnsweredForIsNeverStuck`, `testRetryStartsTheTwentySecondsAgainOnTheSamePicture`: a mark that arrives reads as working; `just native-test`) and the Mac build (`just native-build-mac`); that only its own problem goes lives in the board's view, with no host test. Not yet seen on the iPad; seen on the iPad simulator in [#1242](https://github.com/idvorkin/context-grabber/pull/1242) (then a UI test of a stuck picture: once the retried picture lands and he answers, *Larry hasn't got the picture* goes; now `WhiteboardLarryWaitUITests.testASlowSendOffersNoRetry`: no *Retry* past twenty seconds on a slow Send, and the clock goes once he answers); a slow picture landing without a Retry not yet seen on the simulator
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** told that my picture hasn't reached Larry when it was only slow
- **I want to** see that go by itself once it lands
- **so that** I'm not left with a warning that is no longer true

#### Acceptance Criteria:
- **Scenario:** He was slow, not stuck
- **Given:** *Larry hasn't got the picture* is showing
- **When:** the Cockpit's mark on the picture arrives, or his answer does
- **Then:** the problem goes on its own, and any other problem showing stays

---

### User Story 776:

- **Summary:** Dismiss a stuck picture and the board stops waiting
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), reconciled in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryWaitTests`: `testDismissFreesTheTurnAndKeepsItsWords`, `testAfterInterruptOrDismissTheNextTapSends`, `testAHandOffANewerPictureReplacedStillSpeaks`; `LaunchHooksTests`: the hook that taps it, `GRABBER_WHITEBOARD_LARRY_WAIT=dismiss`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** stop waiting on a picture that hasn't reached him
- **so that** my next pause or tap is a fresh ask instead of being held for an answer that won't come

#### Acceptance Criteria:
- **Scenario:** I dismiss it
- **Given:** the bar shows *Larry hasn't got the picture*
- **When:** I tap *Dismiss*
- **Then:** the problem and Larry's clock go, words that went with the picture wait for the next one, nothing more is said about that picture, my next tap sends (never *Larry already has this*), and the session log says it was dismissed

---

### User Story 777:

- **Summary:** Interrupt Larry when he has the picture and is taking long
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), reconciled in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryWaitTests`: `testReceivedSeenOrUnknownAtTwentySecondsIsWorkingWithOnlyInterrupt`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad, nor against the real Larry. The tap and his finishing are stories 805 and 806; seen on the iPad simulator in [#1242](https://github.com/idvorkin/context-grabber/pull/1242) (`WhiteboardLarryWaitUITests.testInterruptShowsPastTwentySecondsAndFreesTheBoard`, against a fake Cockpit that marks nothing and a 45 s Larry: nothing before twenty seconds, then *Interrupt* and no *Retry*)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** free the board from waiting on him once the Cockpit has my picture
- **so that** I can ask afresh without sending the same picture again, which wouldn't wake him

#### Acceptance Criteria:
- **Scenario:** He has it and hasn't finished
- **Given:** a picture the Cockpit marked received or seen, not done, or one on a Cockpit that marks nothing
- **When:** twenty seconds pass
- **Then:** the note's line offers a small *Interrupt* after the clock (*Sent · 0:21 · not picked up yet* or *Larry · 0:21*), and nothing else appears

---

### User Story 805:

- **Summary:** A tap on Interrupt frees the board, even with the picture still going up
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 777. A picture whose sending hasn't been answered is let go of too, so the next tap sends at once and, unless the Cockpit's mark says it has the picture, its words wait for the next one (this PR's review). Verified by host tests (`WhiteboardLarryWaitTests`: `testInterruptFreesTheTurnAndALateAnswerFindsNone`, `testAfterInterruptOrDismissTheNextTapSends`, `testDismissFreesTheTurnAndKeepsItsWords` for the words; `LaunchHooksTests`: the hook that taps it, `GRABBER_WHITEBOARD_LARRY_WAIT=interrupt`; `just native-test`) and the Mac build (`just native-build-mac`); letting go of the sending lives in the board's view, with no host test. Not yet seen on the iPad, nor against the real Larry; seen on the iPad simulator in [#1242](https://github.com/idvorkin/context-grabber/pull/1242) (`WhiteboardLarryWaitUITests.testInterruptShowsPastTwentySecondsAndFreesTheBoard`: the tap takes the clock away and the next tap starts a fresh one)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** waiting on Larry with *Interrupt* showing
- **I want to** stop waiting with one tap
- **so that** my next pause or tap is a fresh ask, at once, whatever became of the last picture

#### Acceptance Criteria:
- **Scenario:** I interrupt
- **Given:** *Interrupt* is showing, on a picture Larry has or on one still going up
- **When:** I tap *Interrupt*
- **Then:** the clock goes, the next pause or tap sends a fresh picture at once (never *Larry already has this*, never held for the last one's sending), words that went with a picture the Cockpit hasn't taken wait for the next one and nothing more is said about it, what Larry draws or says later still lands, and the session log says I interrupted

---

### User Story 806:

- **Summary:** Interrupt goes when Larry finishes
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 777. Verified by host tests (`WhiteboardLarryWaitTests`: `testDoneOffersNothingEvenWithTheTurnStillOut`, `testNoTurnOutOffersNothing`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** about to interrupt Larry just as he answers
- **I want to** see the control go with the wait
- **so that** I'm never offered a way to stop a wait that is already over

#### Acceptance Criteria:
- **Scenario:** He finishes
- **Given:** *Interrupt* is showing
- **When:** his answer arrives or the Cockpit marks the picture done
- **Then:** *Interrupt* goes

---

### User Story 807:

- **Summary:** The Cockpit's own line stays out of the board's conversation
- **Status:** implemented in this PR's review, with story 820; verified by host tests (`WhiteboardNoteTests.testTheCockpitsOwnLineIsLeftOut`; `just native-test`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading the board's conversation after sending one of my messages on to a new chat
- **I want to** see only what Larry and I said
- **so that** the Cockpit's *Moved to a new chat* never reads as Larry's words

#### Acceptance Criteria:
- **Scenario:** A message moved out of the board's thread
- **Given:** a board whose thread holds *Moved to a new chat* where a message of mine was
- **When:** I open the note's panel
- **Then:** it shows my messages and Larry's, and the moved line is not among them

---

### User Story 892:

- **Summary:** Claude and Larry wait until I've stopped writing, by my own rhythm
- **Status:** implemented in [c9219b9](https://github.com/idvorkin/context-grabber/commit/c9219b9) (the web board's `WritingVad`, ported; replaces story 660's fixed half second); verified on the host (`WhiteboardWritingVadTests`; `just native-test`). How it feels is the iPad's to show
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *When he has stopped writing*

#### Use Case:
- **As someone** writing a sentence on the board
- **I want to** be answered when I've finished a thought, not between two words
- **so that** ghosts and Larry's turns follow what I mean, not a timer

#### Acceptance Criteria:
- **Scenario:** A pause mid-sentence and one at the end of a line
- **Given:** *Ask at my pauses* is on and I write a few words at my usual pace
- **When:** I pause for a second in the middle of the line, then later stop at the end of the line
- **Then:** the mid-line pause asks nothing, and the pause at the end asks after about four times my usual gap between strokes, never less than 1.5 s nor more than 5 s; the session log's `vad` line says the wait, its cue and my usual gap

---

### User Story 893:

- **Summary:** An end-of-thought cue asks sooner
- **Status:** implemented in [c9219b9](https://github.com/idvorkin/context-grabber/commit/c9219b9); verified on the host (`WhiteboardWritingVadTests.testAQuestionMarkEndsTheThoughtAtOnce`, `testThePencilHoveringAtANewLineCutsThePauseToTheFloor`, `testTheHandLeavingIsSeenOnlyWhereTheHoverIs`). The Pencil's hover exists only on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *When he has stopped writing*

#### Use Case:
- **As someone** asking the board a question in ink
- **I want to** be answered as soon as the question is finished
- **so that** a longer wait for my rhythm doesn't hold up a thought that is plainly over

#### Acceptance Criteria:
- **Scenario:** A question mark, a new line, the hand gone
- **Given:** *Ask at my pauses* is on and I have written a line
- **When:** I end it with a question mark, or move the hovering Pencil to the start of the next line, or lift my hand away from the screen
- **Then:** the turn is asked 1.5 s after my last lift (at once if that has passed), and the session log's `vad` line names the cue

---

### User Story 894:

- **Summary:** Putting the Pencil down cancels a turn that hasn't landed
- **Status:** implemented in [c9219b9](https://github.com/idvorkin/context-grabber/commit/c9219b9); verified on the host (`WhiteboardGhostTurnsTests.testThePencilGoingDownCancelsATurnNotYetLanded` and its neighbours). The request being dropped on the wire is the iPad's to show
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *When he has stopped writing*

#### Use Case:
- **As someone** who starts writing again just after a pause
- **I want to** have the stale turn dropped
- **so that** Claude answers the board as it is when I next stop, not a picture I've already moved past

#### Acceptance Criteria:
- **Scenario:** Writing again while Claude is being asked
- **Given:** a pause has asked Claude and no answer has landed yet, and I spoke some words with it
- **When:** I put the Pencil down to write again
- **Then:** that request is dropped, any of its marks already shown go, the bar says nothing went wrong, and my words go with the next turn after my next pause

---

### User Story 1103:

- **Summary:** Pick the board's microphone and see the sound coming in
- **Status:** implemented in [f6fd7a73](https://github.com/idvorkin/context-grabber/commit/f6fd7a73); verified by the lint and host rungs, the Mac build, and every whiteboard UI test on the iPad simulator (the bar's buttons and the mic's turns unchanged). The simulator has no real microphone to pick or level to show: the pocket mic, the reopening and the moving bar are the iPad's to show
- **Issues:** [#1139](https://github.com/idvorkin/context-grabber/issues/1139) (the replay half is `context-grabber-3tdv`)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Which microphone, and what it hears*

#### Use Case:
- **As someone** talking to the board through a pocket mic rather than the iPad's own
- **I want to** see which microphone the open mic hears, pick another, and watch the sound coming in
- **so that** I know my words are reaching it before I say something that matters

#### Acceptance Criteria:
- **Scenario:** Switching to the pocket mic with the mic open
- **Given:** the board's mic is open on the iPad's own microphone, its name and moving level bar at the end of the note's line, and a pocket mic is connected
- **When:** I tap the name and pick the pocket mic
- **Then:** the mic closes, its words so far still go, and opens again on the pocket mic: the line names it, the bar moves with it as I talk, and the next opening, on any board, uses it too

---

### User Story 926:

- **Summary:** Hold the mic to pick the microphone, even with the mic closed
- **Status:** implemented in [b7a1cb54](https://github.com/idvorkin/context-grabber/commit/b7a1cb54) and [f0b27eb8](https://github.com/idvorkin/context-grabber/commit/f0b27eb8) (the dictation made at the board's opening, the *Find microphones* row matched by its label); verified by the lint and host rungs (`BoardMicMenuTests`: the rows, the tick, a pick kept from before a relaunch, when *Find microphones* shows), the Mac build, and the iPad simulator (`WhiteboardTurnUITests.testHoldingTheMicPicksTheMicrophone`: holding the closed mic shows *Talk to Claude*, *Automatic* and *Find microphones*, and the row still talks; the rest of WhiteboardTurnUITests green, and the whole whiteboard suite green apart from this test before its fix). The simulator has no microphone to pick: the pocket mic in the list, *Find microphones* on a paired one, and what reading them does to music playing are the iPad's to show
- **Issues:** bead `context-grabber-h5c0`
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Which microphone, and what it hears*

#### Use Case:
- **As someone** about to talk to the board through a pocket mic
- **I want to** hold the mic button and pick the microphone before I open it
- **so that** my first words already go through the pocket mic, without opening the mic on the wrong one first

#### Acceptance Criteria:
- **Scenario:** Picking the pocket mic with the mic closed
- **Given:** a board open with its mic closed, and a pocket mic connected
- **When:** I press and hold the mic button
- **Then:** the menu shows *Talk to Claude* under *Talk*, and under *Microphone* *Automatic* and the microphones the board knows, the picked one ticked, and *Find microphones*

---

### User Story 927:

- **Summary:** A microphone picked with the mic closed waits for the next opening
- **Status:** implemented in [b7a1cb54](https://github.com/idvorkin/context-grabber/commit/b7a1cb54); verified by the lint and host rungs (`BoardMicMenuTests`: a pick kept from before a relaunch, when *Find microphones* shows) and the Mac build. The simulator has no microphone to find or pick: *Find microphones* on a paired pocket mic and the opening on it are the iPad's to show
- **Issues:** bead `context-grabber-h5c0`
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Which microphone, and what it hears*

#### Use Case:
- **As someone** who just paired a pocket mic and hasn't opened the board's mic yet
- **I want to** find it and pick it from the mic button's long press without opening the mic
- **so that** the mic opens on the pocket mic the first time I tap it

#### Acceptance Criteria:
- **Scenario:** Finding and picking the pocket mic with the mic closed
- **Given:** a board open with its mic closed, and a pocket mic paired since the board last read its microphones
- **When:** I hold the mic button, tap *Find microphones*, hold it again and pick the pocket mic
- **Then:** nothing opens; the next tap on the mic opens it on the pocket mic, on this board or any other

---

### User Story 928:

- **Summary:** Hold the open mic to switch microphones
- **Status:** implemented in [b7a1cb54](https://github.com/idvorkin/context-grabber/commit/b7a1cb54); verified by the lint and host rungs (`BoardMicMenuTests`: the rows and the tick with the mic open) and the Mac build. The simulator has no second microphone: the switch itself is the iPad's to show
- **Issues:** bead `context-grabber-h5c0`
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Which microphone, and what it hears*

#### Use Case:
- **As someone** talking to the board whose words aren't reaching it
- **I want to** hold the mic button and pick another microphone while the mic is open
- **so that** I can switch without reaching for the note's line

#### Acceptance Criteria:
- **Scenario:** Switching to the pocket mic from the long press
- **Given:** the board's mic is open on the iPad's own microphone, and a pocket mic is connected
- **When:** I hold the mic button and pick the pocket mic
- **Then:** the mic closes, its words so far still go, and it opens again on the pocket mic, as a pick from the note's line does

---

### User Story 929:

- **Summary:** An ear on the board while Larry is waiting for more
- **Status:** implemented in [23b3e2ff](https://github.com/idvorkin/context-grabber/commit/23b3e2ff) and [421a15f0](https://github.com/idvorkin/context-grabber/commit/421a15f0); verified by host tests (`WhiteboardLarryListeningTests`: the Cockpit's `receipt.waiting` decoded from sample JSON, a malformed one never costing the receipt's state, only Igor's newest message holding, a hold on the turn's picture being his answer, the ear on the line and the chip only with no turn out; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`WhiteboardListeningUITests` against the fake Cockpit's hold: the ear with Larry's words, the clock gone, no Interrupt, the chip *Your board · Larry: hmm, go on*, gone on his next row; `WhiteboardTurnUITests` still green). The pulse and the real Cockpit's hold are for the iPad's eye
- **Issues:** bead `context-grabber-4fww` (Igor, 2026-11-22, on board ead78e80 via Larry: "when Larry has seen a post but is waiting for more, no text reply; show a tiny indicator")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Larry is listening*

#### Use Case:
- **As someone** thinking out loud on the board, mid-thought
- **I want to** see that Larry has my last post and is holding for more, without him writing a reply
- **so that** I keep going instead of wondering whether he is stuck or waiting for me

#### Acceptance Criteria:
- **Scenario:** Larry holds on my picture
- **Given:** I tapped *Send to Larry* and the clock is counting
- **When:** the Cockpit marks my picture *waiting*, with Larry's words *Larry: waiting for more*
- **Then:** the clock stops, a gently moving ear and *Larry: waiting for more* start the note's line, the open panel's chip reads *Your board · Larry: waiting for more*, and no *Interrupt* or *Larry didn't answer* comes however long it lasts

- **Scenario:** My waiting ink goes when Larry holds
- **Given:** I drew while his turn was out, so *next: ink* was waiting
- **When:** he holds on the picture
- **Then:** the waiting ink goes at once as a new picture, his clock starts again, and the ear goes with my new picture

- **Scenario:** The ear has words even when Larry gives none
- **Given:** a hold with no words of Larry's for it
- **When:** the board reads the thread
- **Then:** the ear reads *Larry: waiting for more*

---

### User Story 934:

- **Summary:** The ear goes when Larry answers
- **Status:** implemented in [23b3e2ff](https://github.com/idvorkin/context-grabber/commit/23b3e2ff); verified by host tests (`WhiteboardLarryListeningTests`: only Igor's newest message holding) and on the iPad simulator (`WhiteboardListeningUITests`: the ear gone on Larry's next row)
- **Issues:** bead `context-grabber-4fww`
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Larry is listening*

#### Use Case:
- **As someone** thinking out loud on the board, mid-thought
- **I want to** see the ear go as soon as Larry has his say
- **so that** the ear never claims he is holding when he has already answered

#### Acceptance Criteria:
- **Scenario:** The ear goes when Larry answers
- **Given:** the ear is showing
- **When:** Larry's next message lands, or the Cockpit stops marking the hold
- **Then:** the ear goes, and the line shows his words as usual

---

### User Story 1302:

- **Summary:** A board's turn that blinks files no report
- **Status:** implemented in [c857b02d](https://github.com/idvorkin/context-grabber/commit/c857b02d); verified by the outage rule's own host tests (`CockpitOutageTests`), the Mac build, and `WhiteboardTurnUITests` with `WhiteboardLarryWaitUITests` on the iPad Pro 11-inch (M5) simulator (11 passed); a real 502 on the iPad not yet
- **Issues:** [#1450](https://github.com/idvorkin/context-grabber/issues/1450)
- **Spec:** [An error on screen files a report by itself](../superpowers/specs/2026-11-19-errors-file-themselves-design.md); the chat's rule is story 1136

#### Use Case:
- **As** the developer reading the automatic reports
- **I want to** get no report when one turn to Larry gets a 502 from the Cockpit's proxy and the next one reaches him
- **so that** a board that heals in twelve seconds does not become an issue

#### Acceptance Criteria:
- **Scenario:** A board's turn that blinks files no report
- **Given:** a board is open, the device is online, and a turn to Larry just got HTTP 502 (or any 5xx, or it timed out,
  could not connect or lost its connection)
- **When:** the next turn, within a minute, reaches him
- **Then:** the board showed *Larry couldn't be reached* with Copy error for the failed turn, no automatic report was
  saved, and the log has `whiteboard` `cockpit_outage` `ended` with `filed: false`
