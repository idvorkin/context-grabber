# Breathing

A few minutes of box breathing: in, hold, out, hold, each the same length. These stories are about the native
app ([design spec](../superpowers/specs/2026-10-04-box-breathing-design.md)); the React Native app has no
breathing screen.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 160:

- **Summary:** Follow a circle through a box-breathing session
- **Status:** implemented in [a197e0c](https://github.com/idvorkin/context-grabber/commit/a197e0c); verified by host tests (`BreathPlanTests`, `BreathRunTests`) and on the simulator (`just native-test-sim`: every step on its second); not yet on the phone

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
- **Status:** implemented in [a197e0c](https://github.com/idvorkin/context-grabber/commit/a197e0c); verified by host tests (`BreathPlanTests`); not yet on the phone

#### Use Case:
- **As someone** with five minutes, or two
- **I want to** set how long a breath is and about how long to sit
- **so that** the session fits the time and the lungs I have today

#### Acceptance Criteria:
- **Scenario:** The sliders
- **Given:** the breathing screen, never used before
- **When:** I look at it, then drag Breath length from 8 to 15 seconds
- **Then:** it opens at 8 seconds and 5 minutes with "9 cycles · ends at 4 min 48 s", and after the drag reads "5 cycles · ends at 5 min 0 s"; a session is always whole cycles, never fewer than one, and the sliders are where I left them the next time I open the app
- **Scenario:** A long sit
- **Given:** the breathing screen at 8 seconds
- **When:** I drag Session length all the way to the right
- **Then:** it stops at 15 minutes and reads "28 cycles · ends at 14 min 56 s"

---

### User Story 162:

- **Summary:** Know how long is left, and pause without losing my place
- **Status:** implemented in [a197e0c](https://github.com/idvorkin/context-grabber/commit/a197e0c); verified by host tests (`BreathRunTests`: pause freezes, resume continues mid-step, the session's length is unchanged); not yet on the phone

#### Use Case:
- **As someone** interrupted mid-breath
- **I want to** pause and pick up exactly where I stopped
- **so that** an interruption does not cost me the session

#### Acceptance Criteria:
- **Scenario:** Pause and resume
- **Given:** a session halfway through an inhale, showing "4:44 left", with a faint pause mark low in the circle and no pause button anywhere else
- **When:** I tap the circle, wait a minute, and tap the circle again
- **Then:** while paused the circle shows a play mark, "Paused" and "tap to resume", and the ring, the circle and "4:44 left" do not move; on the second tap the ring continues from halfway with no jump and the inhale is not announced again; VoiceOver reads the circle as a "Pause" button while running and "Resume" while paused
- **Scenario:** Leaving
- **Given:** a session in progress
- **When:** I tap the back chevron, or leave the app
- **Then:** back returns to the sliders at once with no question asked; leaving the app pauses the session until I return and tap the circle

---

### User Story 163:

- **Summary:** See the session finished
- **Status:** implemented in [a197e0c](https://github.com/idvorkin/context-grabber/commit/a197e0c); verified by host tests (`BreathRunTests`: finishes once, on time, 30 cycles without drift) and on the simulator (`just native-test-sim`: `breath_finished` on its second); not yet on the phone

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
- **Status:** implemented in [a197e0c](https://github.com/idvorkin/context-grabber/commit/a197e0c); verified by host tests (`BreathToneTests`) and on the simulator (`just native-test-sim`: a `breath_cue` per step, each played); not yet heard on the phone

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
- **Status:** implemented in [a197e0c](https://github.com/idvorkin/context-grabber/commit/a197e0c) with the Mac's Australian voice (Karen); the bundled clips since re-rendered with an ElevenLabs calm, gently spoken Australian woman's voice (eleven_v3, best of four takes); verified on the simulator (`just native-test-sim`: clips found and played); not yet heard on the phone

#### Use Case:
- **As someone** who finds tones clinical
- **I want to** hear a soothing woman's voice with an Australian accent say each step
- **so that** the session feels like being guided, not timed

#### Acceptance Criteria:
- **Scenario:** Voice
- **Given:** the cue is set to Voice and the phone is in aeroplane mode
- **When:** I begin a session
- **Then:** the voice says "Let's begin", then "Breathe in", "Hold", "Breathe out", "Hold" as each step starts, the second "Hold" lower and slower than the first, and "Well done" at the end; choosing Voice on the setup screen says "Breathe in" as a sample
- **Scenario:** A phrase's file is missing
- **Given:** the app was built without one of the voice files
- **When:** that step starts
- **Then:** the phone's own Australian voice says the phrase, and the log names the missing file
