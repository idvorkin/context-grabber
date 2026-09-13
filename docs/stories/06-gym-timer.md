# The Gym Timer

Running a workout from the phone propped on a water bottle — rounds, a stopwatch, a set counter, spoken cues in Igor's own voice, and the mobility work logged afterwards.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 100:

- **Summary:** Run a preset of timed rounds with a ready count, work, rest, and a finish
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [83e2bdc](https://github.com/idvorkin/context-grabber/commit/83e2bdc); verified by `timer.test.ts`, `GymTimerScreen.test.tsx` and on the phone (daily use)

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
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `customPreset.test.ts`, `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4); verified by `timer.test.ts`, `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [340e572](https://github.com/idvorkin/context-grabber/commit/340e572); verified by `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `timer.test.ts` and on the phone

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
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `duck.test.ts` and on the phone — the locked-phone boundary and podcast resume still to be re-checked by Igor

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
- **Status:** implemented in [4d1f7aa](https://github.com/idvorkin/context-grabber/commit/4d1f7aa), [7d921fb](https://github.com/idvorkin/context-grabber/commit/7d921fb), [83e2bdc](https://github.com/idvorkin/context-grabber/commit/83e2bdc), [2ef4a17](https://github.com/idvorkin/context-grabber/commit/2ef4a17); verified on the phone

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
- **Status:** implemented in [08c9bda](https://github.com/idvorkin/context-grabber/commit/08c9bda), [243ffa0](https://github.com/idvorkin/context-grabber/commit/243ffa0); verified by `timer.test.ts` (wall-clock derivation) and on the phone

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
- **Status:** implemented in [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `ledTimer.test.ts`, `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `GymTimerScreen.test.tsx` (the accelerometer mock), `ledTimer.test.ts` (the turn math) and on the phone

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
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [be5828e](https://github.com/idvorkin/context-grabber/commit/be5828e); verified by `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [dc6546e](https://github.com/idvorkin/context-grabber/commit/dc6546e); verified by `accessoryLog.test.ts`, `share.test.ts` and on the phone

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
- **Status:** implemented in [340e572](https://github.com/idvorkin/context-grabber/commit/340e572); verified by `accessoryLog.test.ts`, `GymTimerScreen.test.tsx` and on the phone

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
- **Status:** implemented in [a5ff68d](https://github.com/idvorkin/context-grabber/commit/a5ff68d), [b789147](https://github.com/idvorkin/context-grabber/commit/b789147), [2ef4a17](https://github.com/idvorkin/context-grabber/commit/2ef4a17); verified by `deepLink.test.ts` and on the phone

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
- **Status:** implemented in [58001e1](https://github.com/idvorkin/context-grabber/commit/58001e1); verified on the phone

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
- **Status:** implemented in [4609169](https://github.com/idvorkin/context-grabber/commit/4609169); verified by `duck.test.ts` and on the phone

#### Use Case:
- **As a** lifter whose podcast never came back after a cue
- **I want to** copy what the audio session did, from the phone, and paste it into a chat
- **so that** "the music stopped" is answered from evidence, the way a bad call is

#### Acceptance Criteria:
- **Scenario:** After a round with music
- **Given:** a round ran with music playing
- **When:** I tap *Log* at the top right of the timer and paste somewhere
- **Then:** the paste opens with a build line, then the session going active with `[mixWithOthers]`, the duck window opening at four seconds, holding through the ticks and the cue, closing, the session letting go and coming back, the keepalive loop restarting — and nothing marked FAILED; the button read *Copied* for a moment
