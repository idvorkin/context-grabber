# Calling Larry: the Call and Cockpit tabs

Talking to Larry from the phone — a call that survives the lock, the dashboard in a tab, and the evidence when a call goes wrong.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 080:

- **Summary:** A Larry call keeps going when the phone locks or goes in a pocket
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [c1600f0](https://github.com/idvorkin/context-grabber/commit/c1600f0); verified by `callSession.test.ts` and on the phone (daily calls)

#### Use Case:
- **As a** Larry's client walking to school with the phone in a pocket
- **I want to** keep talking after the screen locks, the app goes to the background, or I switch tabs
- **so that** a call is a conversation, not a screen I have to keep lit

#### Acceptance Criteria:
- **Scenario:** The phone locks mid-call
- **Given:** a call is live on the Call tab and Tony is talking
- **and Given:** the phone's auto-lock is set to 30 seconds
- **When:** I press the side button and keep talking to Larry for two minutes with the screen dark
- **Then:** Larry answers every time, and on unlock the captions include everything said while locked and the timer is continuous

- **Issues:** [#74](https://github.com/idvorkin/context-grabber/issues/74) the ask; [#73](https://github.com/idvorkin/context-grabber/issues/73) subsumed

---

### User Story 081:

- **Summary:** Call Larry with one tap, and see the phone calling the way the Phone app does
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [fac48db](https://github.com/idvorkin/context-grabber/commit/fac48db), [b15175c](https://github.com/idvorkin/context-grabber/commit/b15175c); verified by `CallScreen.test.tsx` and on the phone

#### Use Case:
- **As a** Larry's client opening the Call tab
- **I want to** tap Call Larry and watch the phone place the call
- **so that** the first five seconds of every call feel like a call, not a debug screen

#### Acceptance Criteria:
- **Scenario:** Placing a call on a fresh install
- **Given:** the Call tab is open and nothing has been remembered yet
- **When:** I tap Call Larry
- **Then:** a ring pulses around a handset under *Calling Larry…* and *ElevenLabs*, the words "connecting" and "bridge" appear nowhere, and within about five seconds the line reads *live* with the timer running and Tony greeting me

---

### User Story 082:

- **Summary:** One compact call line, with mute, restart and hang-up as small icons
- **Status:** implemented in [fac48db](https://github.com/idvorkin/context-grabber/commit/fac48db), [e858a9d](https://github.com/idvorkin/context-grabber/commit/e858a9d); verified by `CallScreen.test.tsx` and on the phone

#### Use Case:
- **As a** Larry's client reading captions on a live call
- **I want to** have the controls out of the way on the status line
- **so that** the transcript gets the screen instead of three big buttons

#### Acceptance Criteria:
- **Scenario:** Controls on a live call
- **Given:** a call is live
- **When:** I look at the top of the screen
- **Then:** one line reads *live · 1:17 · ElevenLabs · Igor* on the left with three small icons on the right — mute, restart (↻), a red handset — each answering a tap in a 44 pt square, and the captions run down to the tab bar with nothing under them

- **Issues:** [#90](https://github.com/idvorkin/context-grabber/issues/90) the calling state and round buttons; [#96](https://github.com/idvorkin/context-grabber/issues/96) folding them into the line

---

### User Story 083:

- **Summary:** The voice level is the mute
- **Status:** implemented in [fac48db](https://github.com/idvorkin/context-grabber/commit/fac48db), [8a0a09e](https://github.com/idvorkin/context-grabber/commit/8a0a09e); verified by `CallScreen.test.tsx` and on the phone

#### Use Case:
- **As a** Larry's client wondering whether my microphone is working
- **I want to** glance at one control that moves with my voice and mutes when tapped
- **so that** "is my mic live" and "shut it off" are the same glance and the same thumb

#### Acceptance Criteria:
- **Scenario:** Muting mid-call
- **Given:** a call is live and the disc in the voice control swells as I speak
- **When:** I tap the control
- **Then:** it dims, a red slash crosses the microphone, the disc freezes, the live line reads *muted*, nothing I say produces an Igor caption, and Larry does not hang up on the silence

---

### User Story 084:

- **Summary:** See what the recognizer is hearing me say, big, before it is sent
- **Status:** implemented in [4715141](https://github.com/idvorkin/context-grabber/commit/4715141); verified by `CallScreen.test.tsx` and on the phone

#### Use Case:
- **As a** Larry's client talking on a noisy street
- **I want to** watch my words appear large as they are recognised
- **so that** a misheard word shows up while there is still time to say it again

#### Acceptance Criteria:
- **Scenario:** A sentence is recognised
- **Given:** a call is live and the box under the call line reads *listening…*
- **When:** I say a sentence slowly
- **Then:** the words appear in the box in large type as they are recognised, and when Tony answers the box returns to *listening…* and the sentence is one *Igor* row in the transcript below

---

### User Story 085:

- **Summary:** Pick the voice that answers — Tony or my own clone
- **Status:** implemented in [3d0c38d](https://github.com/idvorkin/context-grabber/commit/3d0c38d); verified by `callVoices.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client who has heard his own cloned voice perform
- **I want to** choose Igor instead of Tony before a call
- **so that** the next call answers in my voice on the model that makes it worth hearing

#### Acceptance Criteria:
- **Scenario:** A call as Igor
- **Given:** ElevenLabs is the backend and the devices fold shows a *Voice* row with Tony highlighted
- **When:** I pick Igor, fold the pickers, and tap Call Larry
- **Then:** the devices line ends *· Igor*, the call line reads *live · 0:03 · ElevenLabs · Igor*, the voice that answers is my own with v3's expressiveness, and the pick survives a force-quit

- **Issues:** [#98](https://github.com/idvorkin/context-grabber/issues/98)

---

### User Story 086:

- **Summary:** Choose the microphone and speaker by name, folded away until needed
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [c1600f0](https://github.com/idvorkin/context-grabber/commit/c1600f0), [0a3812b](https://github.com/idvorkin/context-grabber/commit/0a3812b); verified by `callDevices.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client who just put AirPods in
- **I want to** move the call's microphone and output mid-call, or let a plugged-in USB mic take over
- **so that** the call follows the hardware I am actually wearing

#### Acceptance Criteria:
- **Scenario:** Pickers mid-call
- **Given:** a call is live on the built-in microphone and speaker
- **and Given:** AirPods Pro are paired
- **When:** I open the devices line and pick *AirPods Pro* as the microphone
- **Then:** within two seconds the devices line names AirPods Pro, the call continues, and my next sentence is captioned

---

### User Story 087:

- **Summary:** The first call after launch works like every other call
- **Status:** implemented in [62953e1](https://github.com/idvorkin/context-grabber/commit/62953e1), [ae01372](https://github.com/idvorkin/context-grabber/commit/ae01372), [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d); verified by `callSession.test.ts`, `callWatchdog.test.ts` and on the phone — the silent first call still recurs

#### Use Case:
- **As a** Larry's client placing the day's first call
- **I want to** be heard on the first try
- **so that** I never need a second tap to start talking

#### Acceptance Criteria:
- **Scenario:** A microphone that never delivers
- **Given:** the app was force-quit and relaunched
- **and Given:** the recorder starts but produces no buffer for a second and a half
- **When:** I tap Call Larry and say a sentence as soon as Tony greets me
- **Then:** the call's audio is torn down and brought back up on its own, and if it is still silent the call redials itself once on the same backend — *Calling Larry…* briefly, then *live* — without a tap, and my sentence is captioned

- **Issues:** [#88](https://github.com/idvorkin/context-grabber/issues/88) fixed; [#95](https://github.com/idvorkin/context-grabber/issues/95) open — the bridge still receives zero mic frames on some first calls

---

### User Story 088:

- **Summary:** Audio that stops mid-call heals itself, in either direction
- **Status:** implemented in [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d), [9c50345](https://github.com/idvorkin/context-grabber/commit/9c50345); verified by `callSession.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client whose microphone went quiet after the route settled
- **I want to** have the call notice and fix it
- **so that** a dead direction costs a short gap, not a hang-up and a redial

#### Acceptance Criteria:
- **Scenario:** The microphone stalls mid-call
- **Given:** a call is live and captions are flowing
- **When:** a route change kills the microphone tap (plugging and unplugging a USB mic)
- **Then:** within about two seconds Diagnostics shows *mic stalled … → re-arming (1/3)*, my next sentence is captioned, and no error is on screen

---

### User Story 089:

- **Summary:** Tony's greeting is heard in full, every call
- **Status:** implemented in [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d), [9c50345](https://github.com/idvorkin/context-grabber/commit/9c50345); verified by `callSession.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client answering on speaker
- **I want to** hear Tony's first sentence, not the second half of it
- **so that** the call does not open with "sorry, what?"

#### Acceptance Criteria:
- **Scenario:** The speaker is still waking up
- **Given:** a call has just gone *live* on the phone's speaker
- **When:** Larry's first frames arrive before the output clock is running
- **Then:** they are held until the clock runs, Diagnostics shows *output clock running after N ms* before the first frame is scheduled, and the whole greeting plays

---

### User Story 090:

- **Summary:** When Tony's audio is not arriving, read him instead
- **Status:** implemented in [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d); verified by `callSession.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client on a call where the words come and the sound does not
- **I want to** be told the bridge is not sending audio and read Tony's transcript meanwhile
- **so that** a starved socket is named, not blamed on my speaker, and the conversation can limp on

#### Acceptance Criteria:
- **Scenario:** A starved socket
- **Given:** a call is live and Tony's captions keep arriving
- **When:** no audio has come down the socket for five seconds
- **Then:** the screen says *Tony's audio is not arriving from the bridge*, the captions keep updating, and the banner clears the moment audio resumes

- **Issues:** [#105](https://github.com/idvorkin/context-grabber/issues/105)

---

### User Story 091:

- **Summary:** Restart a bad call with one tap
- **Status:** implemented in [e858a9d](https://github.com/idvorkin/context-grabber/commit/e858a9d); verified by `callSession.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client on a call with echo or a stuck consult
- **I want to** end it and dial again without visiting the picker
- **so that** the fix for a call that went bad is one thumb, and the evidence of the bad call is kept

#### Acceptance Criteria:
- **Scenario:** Restarting a live call
- **Given:** a call is live on ElevenLabs
- **When:** I tap ↻ on the call line
- **Then:** the call ends with *stopped*, *Calling Larry…* shows at once on the same backend, then *live*, and Diagnostics afterwards holds both calls separated by a rule

---

### User Story 092:

- **Summary:** The call tells Larry where I am
- **Status:** implemented in [b88f34e](https://github.com/idvorkin/context-grabber/commit/b88f34e); verified by `callLocation.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client calling from the walk to school
- **I want to** have my position — a known place's name when there is one — go up with the call and again when I move
- **so that** Larry knows where I am without me saying so

#### Acceptance Criteria:
- **Scenario:** A call placed at home
- **Given:** location permission is granted and Home is a known place
- **When:** I tap Call Larry and then walk out of the Home radius
- **Then:** Diagnostics shows *location: Home (±… m)* before or shortly after *live*, one more location line reaches the log within a minute of leaving, and standing still sends none

- **Issues:** [#107](https://github.com/idvorkin/context-grabber/issues/107) the ask (still open: what Larry does with it is the bridge's)

---

### User Story 093:

- **Summary:** Read the call's log on the phone, with both directions counted
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [6df0f65](https://github.com/idvorkin/context-grabber/commit/6df0f65), [ae01372](https://github.com/idvorkin/context-grabber/commit/ae01372), [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d); verified by `callLog.test.ts` and on the phone (every bug from #88 on was read from it)

#### Use Case:
- **As a** Larry's client whose call just went silent
- **I want to** open Diagnostics and see what the audio session, the microphone and the speaker were doing, for this call and the ones before it
- **so that** a bad call can be explained from the phone without a cable

#### Acceptance Criteria:
- **Scenario:** Reading a silent call afterwards
- **Given:** a call ended badly, its retry worked, and three more calls followed
- **When:** I open the Diagnostics fold
- **Then:** every call is there, oldest first and separated by rules, each with its start, the *at arm:* line, `mic_ack`, an `rx … KB / … frames · played … of …` line every five seconds and the ending with the final pair — and *Copy diagnostics* copies all of it with the build and roster

- **Issues:** [#106](https://github.com/idvorkin/context-grabber/issues/106); [#92](https://github.com/idvorkin/context-grabber/issues/92) evidence must survive a retry

---

### User Story 094:

- **Summary:** A troubled call uploads its log as a private gist on its own
- **Status:** implemented in [7504fa6](https://github.com/idvorkin/context-grabber/commit/7504fa6), [8a0a09e](https://github.com/idvorkin/context-grabber/commit/8a0a09e), [670084c](https://github.com/idvorkin/context-grabber/commit/670084c); verified by `gistUpload.test.ts` and on the phone (a device build: the Keychain is native)

#### Use Case:
- **As a** Larry's client who just hung up on a call that went wrong
- **I want to** have the log already at a URL on my clipboard
- **so that** the next paste into Telegram is the evidence, and I never copy a dump by hand

#### Acceptance Criteria:
- **Scenario:** A connection is lost mid-call
- **Given:** a GitHub token with the `gist` scope is saved in Settings and *Upload after a troubled call* is on
- **When:** the bridge dies mid-call and the call ends with *connection lost*
- **Then:** a secret gist named for the date and *troubled call* is created with the delete-me note at the top and the same text *Copy diagnostics* gives, its URL is on the clipboard and shown under the Diagnostics buttons, and a clean call afterwards creates nothing

- **Issues:** [#92](https://github.com/idvorkin/context-grabber/issues/92)

---

### User Story 095:

- **Summary:** Delete what the phone uploaded, and never pile up gists
- **Status:** implemented in [7504fa6](https://github.com/idvorkin/context-grabber/commit/7504fa6), [8a0a09e](https://github.com/idvorkin/context-grabber/commit/8a0a09e), [670084c](https://github.com/idvorkin/context-grabber/commit/670084c); verified by `gistUpload.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client whose call transcripts are sitting in secret gists
- **I want to** clear them from Settings once they have been read
- **so that** the evidence is short-lived and nothing accumulates on my account

#### Acceptance Criteria:
- **Scenario:** Deleting after three uploads
- **Given:** the app has uploaded three gists and one was already deleted on the laptop
- **When:** I tap *Delete uploaded diagnostics (3)* in Settings
- **Then:** it reports *deleted 2 of 3 — 1 already gone*, the count reads 0, the two are gone from GitHub, and only gists this app created were ever touched

---

### User Story 096:

- **Summary:** The Cockpit dashboard lives in a tab and keeps its place
- **Status:** implemented in [a11f583](https://github.com/idvorkin/context-grabber/commit/a11f583), [4e12d89](https://github.com/idvorkin/context-grabber/commit/4e12d89); verified by `CockpitScreen.test.tsx` and on the phone

#### Use Case:
- **As a** Larry's client answering a decision on the phone between errands
- **I want to** open the tailnet-only Cockpit as a tab and come back to it exactly as I left it
- **so that** the dashboard is part of the app, not a Safari tab to hunt for

#### Acceptance Criteria:
- **Scenario:** Leaving and returning
- **Given:** the Cockpit tab has loaded, I have scrolled down and expanded a row
- **When:** I switch to the Today tab and back
- **Then:** the dashboard is at the same scroll position with the same row expanded, with no reload flash and no header above it

---

### User Story 097:

- **Summary:** The Cockpit page gets real microphones and outputs, and knows it is inside the app
- **Status:** implemented in [19533fc](https://github.com/idvorkin/context-grabber/commit/19533fc), [f8d2f3a](https://github.com/idvorkin/context-grabber/commit/f8d2f3a); verified by `audioBridge.test.ts`, `cockpitClient.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client using the Cockpit's own call from the tab
- **I want to** see the same microphone and output pickers I have on the laptop, and have Larry's records say the call came from the app
- **so that** the web view is not a second-class place to call from

#### Acceptance Criteria:
- **Scenario:** Pickers in the web view
- **Given:** the Cockpit tab is open on its Call tab with AirPods paired
- **When:** I open the microphone dropdown
- **Then:** it lists *iPhone Microphone* and *AirPods Pro* by the names iOS gives them, the output dropdown offers Automatic, Speaker and the headset, and the page's address carries `client=context-grabber` with the build

- **Issues:** [#78](https://github.com/idvorkin/context-grabber/issues/78)

---

### User Story 098:

- **Summary:** A call from a link, a Shortcut, the widget, or the Cockpit page's own ☎ lands on the native Call tab
- **Status:** implemented in [cef19fc](https://github.com/idvorkin/context-grabber/commit/cef19fc), [8d35bb6](https://github.com/idvorkin/context-grabber/commit/8d35bb6), [a902080](https://github.com/idvorkin/context-grabber/commit/a902080), [b10e8d5](https://github.com/idvorkin/context-grabber/commit/b10e8d5); verified by `deepLink.test.ts`, `audioBridge.test.ts` and on the phone

#### Use Case:
- **As a** Larry's client on the home screen
- **I want to** reach a live call in one tap from wherever I am, including the Cockpit page's call button
- **so that** there is one call — the one that survives the lock — however I start it

#### Acceptance Criteria:
- **Scenario:** The page's call button inside the app
- **Given:** the Cockpit tab is open and no call is live
- **When:** I tap the page's ☎
- **Then:** the app switches to the Call tab and the call goes *live* on the remembered backend with no "open in Context Grabber?" prompt and no second microphone; with a call already live the tab is brought forward and the timer did not reset

- **Issues:** [#85](https://github.com/idvorkin/context-grabber/issues/85); [#99](https://github.com/idvorkin/context-grabber/issues/99)

---

### User Story 099:

- **Summary:** Larry hears about arrivals and workouts as they happen, and can nudge the phone back
- **Status:** not implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84)

#### Use Case:
- **As a** Larry's client arriving at the gym
- **I want to** have the arrival reach Larry without a call, and let Larry send a line to the phone
- **so that** the coaching is live context, not only what I bring to a call

#### Acceptance Criteria:
- **Scenario:** Arriving at a known place
- **Given:** Kettlebility is a known place and background tracking is on
- **When:** the phone settles inside its radius
- **Then:** Larry's record shows the arrival within a few minutes, and a note Larry sends back appears on the phone

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84) — shape to be discussed first
