# The Gym Timer

Running a workout from the phone propped on a water bottle — rounds, a stopwatch, a set counter, spoken cues in Igor's own voice, and the mobility work logged afterwards.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 100:

- **Summary:** Run a preset of timed rounds with a ready count, work, rest, and a finish
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [83e2bdc](https://github.com/idvorkin/context-grabber/commit/83e2bdc); verified by `timer.test.ts`, `GymTimerScreen.test.tsx` and on the phone (daily use); native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter between sets with the phone propped on a water bottle
- **I want to** pick 30 SEC, 1 MIN, 2 MIN or 5-1 and press START once
- **so that** the phone counts the rounds and I count the reps

#### Acceptance Criteria:
- **Scenario:** A 1 MIN workout runs to the end
- **Given:** the Gym Timer is open in Rounds mode with 1 MIN chosen
- **When:** I tap START
- **Then:** a five-second ready count runs, then five rounds of one minute of work and ten seconds of rest, the face shows the phase and *Round n of 5* throughout, and it ends on *donE*

---

### User Story 101:

- **Summary:** Shape a Custom preset with sliders, and have it remembered
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `customPreset.test.ts`, `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter whose programme wants 1:30 on, 0:20 off, eight rounds
- **I want to** set work, rest and rounds with sliders in ten-second steps and find them still set next time
- **so that** a preset that is not on the chip row costs me one setup, not one per workout

#### Acceptance Criteria:
- **Scenario:** A Custom preset survives a restart
- **Given:** the CUSTOM chip is chosen and the Work slider reads 1:00
- **When:** I tap + on Work three times, RESET, force-quit the app, and reopen the timer
- **Then:** CUSTOM is still the chosen chip, Work reads 1:30, and the face shows 1:30 before START

---

### User Story 102:

- **Summary:** Stop, resume, and reset a run without losing my place
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4); verified by `timer.test.ts`, `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor; RESUME after a STOP that landed on a boundary no tick had called now calls it: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by `just native-test` (`TimerEngineTests`)

#### Use Case:
- **As a** lifter interrupted mid-round by someone asking about the rack
- **I want to** stop the clock and pick it up where it was
- **so that** an interruption does not cost me the round

#### Acceptance Criteria:
- **Scenario:** A round is paused and resumed
- **Given:** a round is running with 0:42 left
- **When:** I tap STOP, wait, and tap RESUME
- **Then:** the clock held at 0:42 while stopped and counts on from there, still in the same round

---

### User Story 103:

- **Summary:** A stopped timer says PAUSEd, big enough to read across the room
- **Status:** implemented in [340e572](https://github.com/idvorkin/context-grabber/commit/340e572); verified by `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter glancing back at the phone after stepping away
- **I want to** see at once that the timer is stopped, not running
- **so that** I do not wait on a clock that is not moving

#### Acceptance Criteria:
- **Scenario:** STOP mid-round
- **Given:** a round is running and the green phase word *GO* stands over the red time
- **When:** I tap STOP
- **Then:** *PAUSEd* in amber LED letters, taller than *GO* was, stands over the frozen time, and RESUME brings *GO* back; turned on its side the edge line reads *tap to resume*

---

### User Story 104:

- **Summary:** Hear the cues in my own voice: three, two, one, go — rest — done
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `timer.test.ts` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor; each boundary is called in the second it falls by whichever look sees it first, and one found later is not replayed: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by `just native-test` (`TimerEngineTests`); the clock keeps ticking while a finger drags the lap list or the accessory sheet, so no cue is lost to a scroll: [6fed157](https://github.com/idvorkin/context-grabber/commit/6fed157), verified by build only (the simulator smoke does not scroll), the phone still to be checked by Igor

#### Use Case:
- **As a** lifter mid-set with my eyes on the bell, not the phone
- **I want to** hear the last three seconds counted and the boundary called
- **so that** I never look at the screen to know when to stop or go

#### Acceptance Criteria:
- **Scenario:** The boundary into rest
- **Given:** a round is in its last four seconds
- **When:** the clock reaches three
- **Then:** *three, two, one, rest* play in my own cloned voice on the seconds, START itself said nothing — the ready count's *three, two, one* led to the first *go!* — and the finish ends on *done*

---

### User Story 105:

- **Summary:** Music keeps playing through a workout and dips for the cues; a podcast pauses and resumes
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `duck.test.ts` and on the phone — the locked-phone boundary and podcast resume still to be re-checked by Igor; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim` as far as they can see, the phone (music, the lock, the turn, the lit screen) still to be checked by Igor; RESET or *Done* with the window open lets go of the session once, not twice: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by build only, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter training to music
- **I want to** hear the cues clearly over it without the music stopping
- **so that** the timer is a voice in the gym, not a mute button on my playlist

#### Acceptance Criteria:
- **Scenario:** The dip around a boundary
- **Given:** music is playing at full volume and a 30-second round is running
- **When:** the round reaches four seconds left
- **Then:** the music fades down, *three, two, one, rest* are each audible over it, and about a second after the last word it is back at full volume; a podcast in its place pauses at the three-second mark and resumes where it stopped

---

### User Story 106:

- **Summary:** The countdown lives in the Dynamic Island and on the lock screen
- **Status:** implemented in [4d1f7aa](https://github.com/idvorkin/context-grabber/commit/4d1f7aa), [7d921fb](https://github.com/idvorkin/context-grabber/commit/7d921fb), [83e2bdc](https://github.com/idvorkin/context-grabber/commit/83e2bdc), [2ef4a17](https://github.com/idvorkin/context-grabber/commit/2ef4a17); verified on the phone; native app: [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689), verified by `just native-test` (`GymTimerActivityContentTests`, `PhaseEndsAtTests`), `just native-test-sim` (the card started, pushed at each phase, ended on DONE!) and a simulator screenshot of the compact island (*WORK 1/5*, *0:52*); a refused card is logged once and not asked for again until the next workout: [5d2978b](https://github.com/idvorkin/context-grabber/commit/5d2978b), not yet produced on the simulator or the phone; the lock-screen card, the expanded island and DONE! not yet seen, not yet on the phone

#### Use Case:
- **As a** lifter with the phone locked on the bench
- **I want to** read the phase, the round and the time left without unlocking
- **so that** the lock screen is the gym clock

#### Acceptance Criteria:
- **Scenario:** A round runs with the phone locked
- **Given:** a 2 MIN workout is running
- **When:** I lock the phone and look at it during the second round
- **Then:** the Live Activity shows *WORK*, *Round 2/4* and a countdown that reaches zero at the round's true end, and on the phone's DONE it reads *DONE!* with the rounds completed

- **Issues:** the Live Activity used to freeze at the last phase once iOS suspended the app — fixed by the keepalive (story 107)

---

### User Story 107:

- **Summary:** The timer keeps time and keeps speaking with the screen off
- **Status:** implemented in [08c9bda](https://github.com/idvorkin/context-grabber/commit/08c9bda), [243ffa0](https://github.com/idvorkin/context-grabber/commit/243ffa0); verified by `timer.test.ts` (wall-clock derivation) and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim` as far as they can see, the phone (music, the lock, the turn, the lit screen) still to be checked by Igor; a cue due in the second the app comes back is still said, what fell while it was away is not replayed: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by `just native-test` (`TimerEngineTests`); the clock keeps ticking while a finger drags the lap list or the accessory sheet, so no cue is lost to a scroll: [6fed157](https://github.com/idvorkin/context-grabber/commit/6fed157), verified by build only (the simulator smoke does not scroll), the phone still to be checked by Igor

#### Use Case:
- **As a** lifter who puts the phone face down for a whole workout
- **I want to** hear every boundary called and find the app on the right round when I pick it up
- **so that** backgrounding the app is not the same as stopping the timer

#### Acceptance Criteria:
- **Scenario:** Several minutes in the background
- **Given:** a 5-1 workout is running
- **When:** I lock the phone for the whole of round two and unlock during round three
- **Then:** the rest and go cues played at their true times while locked, and on unlock the face shows round three with the correct time left within one frame, with no cue replayed

---

### User Story 108:

- **Summary:** The time is a seven-segment LED display on black, in the colours of a gym clock
- **Status:** implemented in [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `ledTimer.test.ts`, `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter three metres from the phone
- **I want to** read the minutes and seconds and know the phase from the colour alone
- **so that** the timer reads like the wall clock at Kettlebility

#### Acceptance Criteria:
- **Scenario:** A round in portrait
- **Given:** the Gym Timer is open with the 30 SEC preset, the time in white LED digits with ghost segments behind them
- **When:** I tap START
- **Then:** the digits turn amber under a green *rEAdY*, red under *GO*, green under *rESt*, and steady red on *donE*, with every digit's seven bars drawn lit or ghosted and a two-dot colon between minutes and seconds

---

### User Story 109:

- **Summary:** Turn the phone on its side and the display fills the long edge; a tap anywhere starts or stops
- **Status:** implemented in [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `GymTimerScreen.test.tsx` (the accelerometer mock), `ledTimer.test.ts` (the turn math) and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim` as far as they can see, the phone (music, the lock, the turn, the lit screen) still to be checked by Igor

#### Use Case:
- **As a** lifter who has propped the phone sideways against a water bottle
- **I want to** see only the time, huge and upright, with nothing else on screen
- **so that** the phone is the gym clock from across the floor

#### Acceptance Criteria:
- **Scenario:** Turned mid-round
- **Given:** a round is running in portrait
- **When:** I turn the phone on its side, top to the left, and then top to the right
- **Then:** within about half a second the phase word, time and round line read upright across the long edge both ways with no header, presets or mode bar, a tap anywhere stops and starts the timer, and turning back upright returns the full screen with the timer still running

---

### User Story 110:

- **Summary:** A stopwatch with laps, in LED digits with hundredths
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter timing a carry or a hold
- **I want to** run a stopwatch and mark laps
- **so that** an untimed piece still gets a number

#### Acceptance Criteria:
- **Scenario:** Two laps and a stop
- **Given:** the timer is in Stopwatch mode reading 00:00.00
- **When:** I tap START, LAP twice, and STOP
- **Then:** the digits ran red with smaller hundredths after the seconds, two lap rows sit under the controls newest first, and stopped with time on it the digits are white under *PAUSEd*; RESET clears both

---

### User Story 111:

- **Summary:** Count sets by tapping, with tally marks
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter doing ladders who loses count by the fourth rung
- **I want to** tap once per set and see the tally
- **so that** the count is on the phone, not in my head

#### Acceptance Criteria:
- **Scenario:** Counting to seven
- **Given:** the timer is in Sets mode reading *TAP TO COUNT*
- **When:** I tap the display seven times
- **Then:** the tally shows one struck group of five and two marks, the green LED count reads 7, UNDO takes one back, and the count is still 7 when I reopen the timer

---

### User Story 112:

- **Summary:** Log the accessory work after a workout with four taps
- **Status:** implemented in [dc6546e](https://github.com/idvorkin/context-grabber/commit/dc6546e); verified by `accessoryLog.test.ts`, `share.test.ts` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter finishing with half lotus and dead hangs
- **I want to** tick what I did on a short checklist and save
- **so that** the mobility work leaves a trace the coach can see, at a cost low enough that I actually do it

#### Acceptance Criteria:
- **Scenario:** Two items saved
- **Given:** the Gym Timer is open in any mode and I tap *Log Accessory Work*
- **When:** I check Half Lotus and Dead Hangs and tap Save
- **Then:** exactly those two are recorded with the moment of saving, the button reads *Logged ✓* briefly, and the next Grab Context summary lists both with an ISO timestamp and the session date

---

### User Story 113:

- **Summary:** See the last seven days of accessory work in the same sheet
- **Status:** implemented in [340e572](https://github.com/idvorkin/context-grabber/commit/340e572); verified by `accessoryLog.test.ts`, `GymTimerScreen.test.tsx` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim`, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter unsure whether yesterday's pigeon stretch got logged
- **I want to** see what was saved, by day, under the checklist
- **so that** what I see is what the coach sees

#### Acceptance Criteria:
- **Scenario:** Reopening after a save
- **Given:** Half Lotus and Dead Hangs were saved this afternoon and Pigeon Stretch eight days ago
- **When:** I open *Log Accessory Work* again
- **Then:** a *Today* group lists one line with the save's wall-clock time and *Half Lotus, Dead Hangs*, the eight-day-old entry is not listed, and with nothing in the window the sheet says *Nothing logged in the last 7 days*

---

### User Story 114:

- **Summary:** Start a timer from the home screen, a link, or the Live Activity in one tap
- **Status:** implemented in [a5ff68d](https://github.com/idvorkin/context-grabber/commit/a5ff68d), [b789147](https://github.com/idvorkin/context-grabber/commit/b789147), [2ef4a17](https://github.com/idvorkin/context-grabber/commit/2ef4a17); verified by `deepLink.test.ts` and on the phone; native app: not yet, it waits for the widgets step (bead context-grabber-3ss.7)

#### Use Case:
- **As a** lifter on the home screen with chalk on my hands
- **I want to** tap a 1 MIN tile and have the timer already running
- **so that** starting a workout is one tap, not four

#### Acceptance Criteria:
- **Scenario:** The widget's 1 MIN tile
- **Given:** the Today widget is on the home screen and the app is closed
- **When:** I tap its 1 MIN tile
- **Then:** the app opens on the Gym Timer with 1 MIN chosen and the countdown already running from 1:00 within a second, and a tap on the Live Activity later lands on the timer, not the dashboard

---

### User Story 115:

- **Summary:** The screen stays awake while the timer is open
- **Status:** implemented in [58001e1](https://github.com/idvorkin/context-grabber/commit/58001e1); verified on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), verified by `just native-test` and `just native-test-sim` as far as they can see, the phone (music, the lock, the turn, the lit screen) still to be checked by Igor

#### Use Case:
- **As a** lifter who set the phone down for a five-minute round
- **I want to** find the screen still lit at the end of it
- **so that** the clock is readable without a tap

#### Acceptance Criteria:
- **Scenario:** A long round
- **Given:** the phone's auto-lock is 30 seconds and the 5-1 preset is running
- **When:** I leave the phone untouched for the whole five-minute round
- **Then:** the screen never dims, and *Done* leaving the timer hands the lock back to the phone's own setting

---

### User Story 116:

- **Summary:** Copy the timer's log when the music did something odd
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `duck.test.ts` and on the phone; native app: [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5), where the timer writes to the session log and *Log* copies this launch's `timer_*` events behind a build line (nothing with `ok: false` instead of nothing marked FAILED), verified on the simulator, the phone still to be checked by Igor

#### Use Case:
- **As a** lifter whose podcast never came back after a cue
- **I want to** copy what the audio session did, from the phone, and paste it into a chat
- **so that** "the music stopped" is answered from evidence, the way a bad call is

#### Acceptance Criteria:
- **Scenario:** After a round with music
- **Given:** a round ran with music playing
- **When:** I tap *Log* at the top right of the timer and paste somewhere
- **Then:** the paste opens with a build line, then the session going active with `[mixWithOthers]`, the duck window opening at four seconds, holding through the ticks and the cue, closing, the session letting go and coming back, the keepalive loop restarting — and nothing marked FAILED; the button read *Copied* for a moment

---

### User Story 117:

- **Summary:** The preset cannot change under a running clock
- **Status:** native app only: implemented in [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5); verified by `just native-test` (`TimerEngineTests`), the phone still to be checked by Igor

#### Use Case:
- **As a** lifter whose thumb brushes the chip row mid-round
- **I want to** have the preset chips and the Custom sliders do nothing from START until RESET or the finish
- **so that** the workout I started is the workout that runs

#### Acceptance Criteria:
- **Scenario:** A chip tapped mid-round
- **Given:** CUSTOM is the chosen chip with Work 1:00 and 5 rounds, and it is running in round 2 with 0:42 left
- **When:** I tap the 2 MIN chip, try to drag the Work slider, then tap STOP and try the slider and the chip again
- **Then:** CUSTOM stays the chosen chip, Work still reads 1:00, the clock and *Round 2 of 5* are unchanged by the taps, and after RESET the chips and sliders answer again

---

### User Story 118:

- **Summary:** A phone call does not end the workout's cues
- **Status:** native app only: implemented in [5a284c5](https://github.com/idvorkin/context-grabber/commit/5a284c5); a phone call exists only on the phone, which is still to be checked by Igor

#### Use Case:
- **As a** lifter who takes a short call between rounds
- **I want to** have the timer take its audio back when the call ends
- **so that** the next count is spoken and the timer keeps running with the screen locked

#### Acceptance Criteria:
- **Scenario:** A call during a workout
- **Given:** the 5-1 preset is running and a phone call comes in
- **When:** I take the call, hang up, and lock the phone
- **Then:** the clock kept time through the call, the next three, two, one and cue are spoken at their true times with the phone still locked, and the session log has `timer_interruption` began and ended with the session going active again after it

---

### User Story 119:

- **Summary:** With no rest, every round is still called
- **Status:** native app only: implemented in [509da33](https://github.com/idvorkin/context-grabber/commit/509da33); verified by `just native-test` (`TimerEngineTests`), the phone still to be checked by Igor

#### Use Case:
- **As a** lifter running rounds back to back with the Custom preset's Rest at 0:00
- **I want to** hear *go* at the start of every round
- **so that** I know a new round began without looking at the phone

#### Acceptance Criteria:
- **Scenario:** Three rounds with no rest
- **Given:** CUSTOM is chosen with Work 0:10, Rest 0:00 and 3 rounds
- **When:** I tap START and let it run to the end
- **Then:** I hear the ready count and *go*, then *three, two, one, go* into round 2 and again into round 3, then *three, two, one, done*, the face reads *Round n of 3* for each, and the session log has a `timer_phase` line for each new round

---

### User Story 181:

- **Summary:** Reset the timer without turning the phone back upright
- **Status:** native app only: implemented in [bfc46ae](https://github.com/idvorkin/context-grabber/commit/bfc46ae), [6784c5d](https://github.com/idvorkin/context-grabber/commit/6784c5d) (the paused face shrinks further so RESET fits); verified by `just native-test-sim` and a simulator screenshot of the turned, finished face; the phone still to be checked by Igor
- **Issues:** [#132](https://github.com/idvorkin/context-grabber/issues/132)

#### Use Case:
- **As a** lifter with the phone propped sideways on a water bottle
- **I want to** reset a paused or finished workout where the phone stands
- **so that** starting the next one does not mean picking the phone up and turning it

#### Acceptance Criteria:
- **Scenario:** Paused on its side
- **Given:** the phone is on its side and a workout is paused mid-round
- **When:** I tap RESET under the hint
- **Then:** the face shows the preset ready from its first round, the session log has a `timer_reset` line, a tap anywhere else would have resumed instead, and while the workout runs no RESET is shown

---

### User Story 180:

- **Summary:** Choosing a preset after the finish goes back to ready
- **Status:** native app only: implemented in [7ba6357](https://github.com/idvorkin/context-grabber/commit/7ba6357); verified by `just native-test` (`TimerEngineTests`), the phone still to be checked by Igor

#### Use Case:
- **As a** lifter who finished one workout and wants a different one next
- **I want to** tap a chip or move a Custom slider and see that preset ready on the face
- **so that** the face never shows *donE* for a workout I am no longer looking at, and I do not have to tap RESET first

#### Acceptance Criteria:
- **Scenario:** A chip after the finish
- **Given:** 30 SEC ran to the end and the face reads *donE*, 0:00 and *Round 6 of 6*
- **When:** I tap the 1 MIN chip
- **Then:** the face clears *donE* and shows 1:00 and *Round 1 of 5*, exactly as RESET followed by the tap would, the session log has a `timer_reset` line, and choosing CUSTOM and moving its Work slider after another finish does the same with the slider's time

---

### User Story 182:

- **Summary:** Choose the voice that counts the workout
- **Status:** native app only: implemented in [d6ce5b6](https://github.com/idvorkin/context-grabber/commit/d6ce5b6); verified by `just native-test` (`CountVoiceTests`), a simulator screenshot of the sheet, and `just native-test-sim`'s `voice: adam` check on its one run with working simulator audio (the `aussie` hook check is written but the Mac's audio was down for every later run, main's build included); hearing each voice and the sample on the phone still to be checked by Igor

#### Use Case:
- **As a** lifter who hears the count from across the gym
- **I want to** pick who calls *three, two, one, go* — Adam, my own voice, or an excited Australian woman
- **so that** the count sounds the way I want to hear it today, without anything else about the timer changing

#### Acceptance Criteria:
- **Scenario:** Adam by default
- **Given:** I have never chosen a count voice
- **When:** I start a workout
- **Then:** Adam says *three, two, one, go*, *rest* and *done*, and each `timer_cue` line in the session log has `voice: adam`

- **Scenario:** Choosing another voice
- **Given:** the Gym Timer is upright
- **When:** I tap the gear, then *Australian woman* under *Count voice*
- **Then:** the checkmark moves to her row, she says *go* once as a sample, the session log has a `ui` line with `action: count_voice` and `voice: aussie`, the next cue is in her voice, and after quitting and reopening the app she is still the one counting

---

### User Story 183:

- **Summary:** Tap the time to pause, upright as on its side
- **Status:** native app only: implemented in [aaa1227](https://github.com/idvorkin/context-grabber/commit/aaa1227); verified by `GymTimerUITests` on the simulator (tap the time: RESUME appears, tap again: STOP); the phone still to be checked by Igor
- **Issues:** [#148](https://github.com/idvorkin/context-grabber/issues/148)
- **Spec:** [LED display — upright, the face is a button too](../superpowers/specs/2026-09-07-gym-timer-led-display-design.md)

#### Use Case:
- **As a** lifter who pauses by tapping the timer when the phone is on its side
- **I want to** pause the same way when I am holding the phone upright
- **so that** I do not hunt for the STOP button between sets

#### Acceptance Criteria:
- **Scenario:** Upright, mid-round
- **Given:** the phone is upright and a Rounds workout is running
- **When:** I tap the time
- **Then:** the workout pauses as STOP would (the face says *PAUSEd*, the log has `timer_pause`), and another tap on the time resumes it; the Stopwatch stops and resumes the same way

---

### User Story 184:

- **Summary:** Turn Work, Rest and Rounds on big drums, upright
- **Status:** native app only: implemented
- **Issues:** [#163](https://github.com/idvorkin/context-grabber/issues/163)
- **Spec:** [Custom preset — upright in Grabber Native: drums, not sliders](../superpowers/specs/2026-09-07-gym-timer-custom-preset-design.md)

#### Use Case:
- **As a** lifter setting a Custom workout between sets, with chalky or sweaty fingers and the phone at arm's length
- **I want to** turn Work, Rest and Rounds on three big drums with a swipe or a tap, reading the values in the same LED digits as the face
- **so that** I can set 1:30 on, 0:20 off, eight rounds in a few strokes without hunting for a slider's thumb

#### Acceptance Criteria:
- **Scenario:** Setting a Custom workout on the drums
- **Given:** the Gym Timer is upright with CUSTOM chosen, fresh at 1:00 / 0:10 / 5
- **When:** I drag the Work drum up a finger's width, tap the bottom of Rest, and flick Work up fast
- **Then:** Work reads 1:10 with a haptic tick, then several steps more after the flick, always on the ten-second grid and never past 10:00 (a bump there, and it stays); Rest reads 0:20; each drum shows the value one step less faint above and one more faint below; the face shows the new work time before START; the values are remembered as the sliders' were; while running the drums are dim and do nothing; and the session log has one `ui` custom_dial line per gesture
