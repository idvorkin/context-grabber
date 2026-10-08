# Breathing

A few minutes of box breathing: in, hold, out, hold, each the same length. These stories are about the native
app ([design spec](../superpowers/specs/2026-10-04-box-breathing-design.md)); the React Native app has no
breathing screen.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 160:

- **Summary:** Follow a circle through a box-breathing session
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); verified by host tests (`BreathPlanTests`, `BreathRunTests`) and on the simulator (`just native-test-sim`: every step on its second); redesigned circle in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97), seen in simulator screenshots (inhale, hold); not yet on the phone

#### Use Case:
- **As someone** who wants to settle before a hard conversation
- **I want to** follow one shape that tells me when to breathe in, hold and breathe out
- **so that** I can breathe evenly without counting

#### Acceptance Criteria:
- **Scenario:** A session
- **Given:** I am on the breathing screen with the breath length at 8 seconds
- **When:** I tap Begin
- **Then:** a white ring draws up both sides of a dark circle for 8 seconds while the circle grows and the word reads "Inhale", stays closed for 8 seconds while a bar fills under "Hold", un-draws for 8 seconds while the circle shrinks under "Exhale", is gone for 8 seconds while the bar fills under "Hold", and then starts again; the screen does not dim or lock

---

### User Story 161:

- **Summary:** Choose the breath and the session, and see where it will end
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); verified by host tests (`BreathPlanTests`); the redesigned sliders in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97), seen in a simulator screenshot of Setup; not yet on the phone

#### Use Case:
- **As someone** with five minutes, or two
- **I want to** set how long a breath is and about how long to sit
- **so that** the session fits the time and the lungs I have today

#### Acceptance Criteria:
- **Scenario:** The sliders
- **Given:** the breathing screen, never used before, open at 8 seconds and 5 minutes with "9 cycles · ends at 4 min 48 s"
- **When:** I drag Breath length from 8 to 15 seconds
- **Then:** it reads "5 cycles · ends at 5 min 0 s"; a session is always whole cycles, never fewer than one, and the sliders are where I left them the next time I open the app

---

### User Story 162:

- **Summary:** Know how long is left, and pause without losing my place
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); verified by host tests (`BreathRunTests`: pause freezes, resume continues mid-step, the session's length is unchanged); pause moved into the circle in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97), verified on the simulator (`just native-test-sim`: paused mid-inhale, nothing moved on) and a screenshot of the paused circle; the tap itself not yet on the phone

#### Use Case:
- **As someone** interrupted mid-breath
- **I want to** pause and pick up exactly where I stopped
- **so that** an interruption does not cost me the session

#### Acceptance Criteria:
- **Scenario:** Pause and resume
- **Given:** a session halfway through an inhale, showing "4:44 left", with a faint pause mark low in the circle and no pause button anywhere else
- **When:** I tap the circle
- **Then:** the circle shows a play mark, "Paused" and "tap to resume", and the ring, the circle and "4:44 left" do not move for as long as it stays paused; VoiceOver reads the circle as a "Pause" button while running and "Resume" while paused

---

### User Story 163:

- **Summary:** See the session finished
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); verified by host tests (`BreathRunTests`: finishes once, on time, 30 cycles without drift) and on the simulator (`just native-test-sim`: `breath_finished` on its second); redesigned Done in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97), seen in a simulator screenshot; not yet on the phone

#### Use Case:
- **As someone** breathing with my attention elsewhere
- **I want to** be told plainly that it is over
- **so that** I do not sit wondering whether there is another cycle

#### Acceptance Criteria:
- **Scenario:** The last hold ends
- **Given:** a 5-minute session at 8 seconds
- **When:** the ninth cycle's last hold ends
- **Then:** the screen reads "Done" and "4 min 48 s · 9 cycles", a closing sound plays unless the cue is Off, and "Back to start" returns to the sliders

---

### User Story 164:

- **Summary:** Breathe with my eyes closed, by tone
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); verified by host tests (`BreathToneTests`) and on the simulator (`just native-test-sim`: a `breath_cue` per step, each played); not yet heard on the phone

#### Use Case:
- **As someone** who settles faster with eyes shut
- **I want to** hear a different sound for each step
- **so that** I do not have to look at the screen

#### Acceptance Criteria:
- **Scenario:** Tone
- **Given:** the cue is set to Tone and music is playing
- **When:** I begin a session
- **Then:** a rising tone starts each inhale, a falling tone each exhale, a soft tick each hold and a closing tone the end, all over the music, which keeps playing; choosing Tone on the setup screen plays the rising tone as a sample; the choice is remembered

---

### User Story 165:

- **Summary:** Be talked through it by a calm voice
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37) with the Mac's Australian voice (Karen); the bundled clips since re-rendered with an ElevenLabs calm, gently spoken Australian woman's voice (eleven_v3, best of four takes) in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97); verified on the simulator (`just native-test-sim`: clips found and played); not yet heard on the phone

#### Use Case:
- **As someone** who finds tones clinical
- **I want to** hear a soothing woman's voice with an Australian accent say each step
- **so that** the session feels like being guided, not timed

#### Acceptance Criteria:
- **Scenario:** Voice
- **Given:** the cue is set to Voice and the phone is in aeroplane mode
- **When:** I begin a session
- **Then:** the voice says "Let's begin", then "Breathe in", "Hold", "Breathe out", "Hold" as each step starts, the second "Hold" lower and slower than the first, and "Well done" at the end; choosing Voice on the setup screen says "Breathe in" as a sample

---

### User Story 166:

- **Summary:** Breathe with the phone locked, and see the step on the lock screen
- **Status:** native app only: implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); verified by `just native-test` (`BreatheActivityContentTests`), `just native-test-sim` (the keepalive for the session; the card pushed at each step) and a simulator screenshot of the compact island running (*OUT 1/3*, *0:06*); the card starts at Begin and says *Ready* through the lead-in: [5d2978b](https://github.com/idvorkin/context-grabber/commit/5d2978b), verified by `just native-test` (`testTheQuietBeforeTheFirstInhaleSaysReadyAndTheTimeToIt`); the lock-screen card and the voice with the phone locked not yet on the phone

#### Use Case:
- **As someone** who wants the screen dark while breathing
- **I want to** lock the phone and still hear each step, and glance at the lock screen or the Dynamic Island to see where I am
- **so that** a session does not need a lit screen, and a glance is enough

#### Acceptance Criteria:
- **Scenario:** A locked session
- **Given:** I have just tapped Begin on a 5-minute session at 8 s with the voice
- **When:** I lock the phone at once
- **Then:** while "Let's begin" is said the lock screen shows *Ready*, *Cycle 1 of 9* and the seconds to the first inhale; the voice then keeps saying each step on time, and in the third cycle the lock screen shows *Exhale*, *Cycle 3 of 9* and a countdown that reaches zero as *Hold* is said; the Dynamic Island shows *OUT 3/9* and the countdown while another app is in front

---

### User Story 167:

- **Summary:** Sit for as long as fifteen minutes
- **Status:** implemented in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97); verified by host tests (`testTheLongestSessionIsFifteenMinutes`) and a simulator screenshot of Setup; not yet on the phone

#### Use Case:
- **As someone** with a long gap before a hard day
- **I want to** choose a session of up to fifteen minutes
- **so that** one sitting is enough to settle

#### Acceptance Criteria:
- **Scenario:** A long sit
- **Given:** the breathing screen at 8 seconds
- **When:** I drag Session length all the way to the right
- **Then:** it stops at 15 minutes and reads "28 cycles · ends at 14 min 56 s"

---

### User Story 168:

- **Summary:** Leave a session at once
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); not yet verified on the simulator or the phone

#### Use Case:
- **As someone** who has to stop breathing exercises now
- **I want to** get out of a session with one tap
- **so that** an interruption is not made worse by a question

#### Acceptance Criteria:
- **Scenario:** Back
- **Given:** a session in progress
- **When:** I tap the back chevron
- **Then:** the sliders return at once with no question asked, and the session's sound stops

---

### User Story 169:

- **Summary:** Keep breathing when I leave the app or lock the phone
- **Status:** implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); verified on the simulator (`just native-test-sim`: the keepalive runs for the session and stops at its end); the locked phone not yet checked

#### Use Case:
- **As someone** who does not want a lit screen while breathing
- **I want to** leave the app or lock the phone without stopping the session
- **so that** only a deliberate tap pauses it

#### Acceptance Criteria:
- **Scenario:** Leaving the app
- **Given:** a session in progress
- **When:** I leave the app
- **Then:** the session and its cues carry on without pausing, and coming back finds the circle where the session is (story 166)

---

### User Story 170:

- **Summary:** Still hear each step when a voice file is missing
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); not yet verified (every build so far carries all six files)

#### Use Case:
- **As someone** breathing with my eyes closed
- **I want to** hear every step even when the app was built without one of its phrases
- **so that** a broken build does not leave a silent step

#### Acceptance Criteria:
- **Scenario:** A phrase's file is missing
- **Given:** the app was built without one of the voice files
- **When:** that step starts
- **Then:** the phone's own Australian voice says the phrase, and the log names the missing file

---

### User Story 171:

- **Summary:** See a paused session on the lock screen
- **Status:** native app only: implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); verified by `just native-test` (`BreatheActivityContentTests`) and a simulator screenshot of the compact island paused (*PAUSED 1/1*, *0:03*); not yet on the phone

#### Use Case:
- **As someone** who paused a session and locked the phone
- **I want to** see on the lock screen that it is paused and where
- **so that** I know where I will pick up

#### Acceptance Criteria:
- **Scenario:** Paused
- **Given:** a session showing *Inhale*, *Cycle 3 of 9* on the lock screen
- **When:** I tap the circle to pause
- **Then:** the card reads *PAUSED*, *Inhale · Cycle 3 of 9* and a still time left in the step

---

### User Story 172:

- **Summary:** See a finished session on the lock screen
- **Status:** native app only: implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); verified by `just native-test` (`BreatheActivityContentTests`) and `just native-test-sim` (the card ended on Done); not yet on the phone

#### Use Case:
- **As someone** who finished a session with the phone locked
- **I want to** see that it is done when I glance at the lock screen
- **so that** I do not wonder whether there is another cycle

#### Acceptance Criteria:
- **Scenario:** Finished
- **Given:** a 5-minute session at 8 s showing on the lock screen
- **When:** its last hold ends
- **Then:** the card reads *Done* and *4 min 48 s · 9 cycles* with no countdown, and goes by itself a few minutes later

---

### User Story 173:

- **Summary:** The card goes when I leave the session
- **Status:** native app only: implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); not yet verified on the simulator or the phone

#### Use Case:
- **As someone** who is done with breathing
- **I want to** have the lock screen card go when I leave
- **so that** a stale card does not linger

#### Acceptance Criteria:
- **Scenario:** Back
- **Given:** a session running with its card on the lock screen
- **When:** I tap the back chevron
- **Then:** the card is removed at once

---

### User Story 174:

- **Summary:** Open the session from its card
- **Status:** native app only: implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); not yet on the phone

#### Use Case:
- **As someone** glancing at the lock screen mid-session
- **I want to** tap the card to get back to the circle
- **so that** I can pause or leave without hunting for the screen

#### Acceptance Criteria:
- **Scenario:** The tap
- **Given:** a session running with its card on the lock screen
- **When:** I tap the card
- **Then:** the app opens on the breathing screen with the session where it is

---

### User Story 175:

- **Summary:** Keep breathing through a phone call or Siri
- **Status:** native app only: implemented in [5d2978b](https://github.com/idvorkin/context-grabber/commit/5d2978b) (the keepalive restarts when an interruption ends during a session, `breath_interruption` in the log, mirroring the Gym Timer, story 118); verified by `just native-build-sim` (it builds); not yet on the phone

#### Use Case:
- **As someone** breathing with the phone locked
- **I want to** have the session carry on after a call or Siri interrupts it
- **so that** an interruption does not silently end the rest of the session

#### Acceptance Criteria:
- **Scenario:** A call mid-session
- **Given:** a session running with the phone locked
- **When:** a phone call comes in and ends
- **Then:** the voice says the next step at its true time with the phone still locked, and the session log has `breath_interruption` began and ended with the session going active again after it

---

### User Story 176:

- **Summary:** The finished card goes when I go back to start
- **Status:** native app only: implemented in [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689); not yet verified on the simulator or the phone

#### Use Case:
- **As someone** who has finished a session
- **I want to** have the *Done* card go as soon as I start over
- **so that** the lock screen never shows a session that is behind me

#### Acceptance Criteria:
- **Scenario:** Back to start
- **Given:** a finished session with its *Done* card on the lock screen
- **When:** I tap Back to start
- **Then:** the card is removed at once rather than a few minutes later

---

### User Story 177:

- **Retired:** covered by 173 and 176

---

### User Story 178:

- **Summary:** Breathe on when the lock-screen card is refused
- **Status:** native app only: implemented in [5d2978b](https://github.com/idvorkin/context-grabber/commit/5d2978b); verified by `just native-build-sim` (it builds); a refusal not yet produced on the simulator or the phone

#### Use Case:
- **As someone** whose phone will not show the card (Live Activities off, or iOS refusing it)
- **I want to** have the session run as normal without it, and the log say why once
- **so that** a missing card neither breaks the session nor floods the log

#### Acceptance Criteria:
- **Scenario:** A refused card
- **Given:** iOS refuses the breathing card when I tap Begin
- **When:** the session runs through its steps
- **Then:** the session speaks and moves as normal with no card; the log has one line saying why (an `error` with where: live_activity, or `unavailable` when Live Activities are off), and the card is asked for again only when I next tap Begin, never from the locked phone

---

### User Story 179:

- **Summary:** Resume exactly where I paused
- **Status:** implemented in [7c4fb37](https://github.com/idvorkin/context-grabber/commit/7c4fb37); verified by host tests (`BreathRunTests`: resume continues mid-step, the session's length is unchanged); resume by a tap on the circle in [2e68c97](https://github.com/idvorkin/context-grabber/commit/2e68c97); the tap not yet on the phone

#### Use Case:
- **As someone** coming back from an interruption
- **I want to** pick the breath up from the exact point I stopped
- **so that** the pause costs me nothing

#### Acceptance Criteria:
- **Scenario:** Resume
- **Given:** a session paused for a minute halfway through an inhale, showing "4:44 left"
- **When:** I tap the circle
- **Then:** the ring continues from halfway with no jump, "4:44 left" counts down again, and the inhale is not announced again

---

### User Story 240:

- **Summary:** A thicker ring, and a cog to pick its style
- **Status:** native app only: implemented in [685be3e](https://github.com/idvorkin/context-grabber/commit/685be3e); verified by `BreathStyleTests` (host), `BreatheStyleUITests` (pick Tide through the cog, relaunch, still Tide) and simulator screenshots of all four styles mid-inhale and the picker; the phone still to be checked by Igor
- **Issues:** [#147](https://github.com/idvorkin/context-grabber/issues/147)
- **Spec:** [Box breathing — ring styles](../superpowers/specs/2026-10-04-box-breathing-design.md#ring-styles)

#### Use Case:
- **As a** person breathing with the circle every day
- **I want to** see a ring that is easier to follow, and choose among a few calm ways of drawing it
- **so that** the practice stays quiet without getting stale

#### Acceptance Criteria:
- **Scenario:** Choosing a style
- **Given:** the breathing setup screen
- **When:** I tap the cog, choose *Tide* and begin
- **Then:** the circle fills from the bottom as I breathe in, stays full on the hold, drains as I breathe out; the session log has `breathe_style` with *tide*; the next launch still uses *Tide*; and with nothing chosen the ring is *Line*, twice as thick as before

---

### User Story 241:

- **Summary:** Breath presets, and a custom box with its own in and out
- **Issues:** [#155](https://github.com/idvorkin/context-grabber/issues/155), [#204](https://github.com/idvorkin/context-grabber/issues/204)
- **Status:** implemented in [cb75f1b](https://github.com/idvorkin/context-grabber/commit/cb75f1b); verified by `BreathTests` (host: an uneven 4/8 box's steps, cycles and timing; clamping; even presets) and `BreathePresetsUITests`, `BreatheStyleUITests` on the simulator (12 s gives 6 cycles; Custom's In and Out remembered across a relaunch; the setup scrolls so the cog stays reachable) plus a screenshot; on the phone not yet
- **Spec:** [box breathing, "Breath length"](../superpowers/specs/2026-10-04-box-breathing-design.md)

#### Use Case:
- **As someone** who breathes at a few set paces and sometimes wants a longer out-breath
- **I want to** pick 8, 10, 12 or 15 seconds with one tap, or set in and out separately
- **so that** the pace I want is one tap, not a slider hunt

#### Acceptance Criteria:
- **Scenario:** A preset
- **Given:** the breathing screen
- **When:** I tap *12 s* and Begin
- **Then:** each of the four steps lasts 12 seconds, and *12 s* is still chosen the next time I open the screen

- **Scenario:** Custom
- **Given:** the breathing screen
- **When:** I tap *Custom*, set In to 4 and Out to 8, and Begin
- **Then:** in and its hold last 4 seconds, out and its hold 8, the summary counts cycles of 24 seconds, and both lengths are remembered

