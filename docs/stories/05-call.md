# Calling Larry: the Call and Cockpit tabs

Talking to Larry from the phone — a call that survives the lock, the dashboard in a tab, and the evidence when a call goes wrong.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 080:

- **Summary:** A Larry call keeps going when the phone locks or goes in a pocket
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [c1600f0](https://github.com/idvorkin/context-grabber/commit/c1600f0); verified by `callSession.test.ts` and on the phone (daily calls); native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by `just native-test` (`CallSession*Tests`) and `just native-test-sim` (a call to the fake bridge, [9939b6a](https://github.com/idvorkin/context-grabber/commit/9939b6a)); the lock is the phone still to be checked by Igor; native no-sound fix [d9c1fd1](https://github.com/idvorkin/context-grabber/commit/d9c1fd1) (#146: the player reconnected when the mic finds the engine stopped) verified on the phone by Igor, 2026-10-05; #186 [326396a](https://github.com/idvorkin/context-grabber/commit/326396a) (the silent-mixer check waits for audio in hand 1.5 s; a failed reopen retries at 0.5, 1 and 2 s, then says the audio stopped) verified by `CallSilentMixerTests` (host, the phone's own timings) and the simulator build; on the phone not yet; #576 [8979f02](https://github.com/idvorkin/context-grabber/commit/8979f02) (a barge-in forgets the loud-audio mark), verified by host tests and a simulator compile; on the phone not yet

- **Issues:** [#576](https://github.com/idvorkin/context-grabber/issues/576) (a barge-in read as a silent mixer), [#136](https://github.com/idvorkin/context-grabber/issues/136) (native: the bridge refused the native socket, which sent no Origin), #146, [#186](https://github.com/idvorkin/context-grabber/issues/186) (a needless reopen that failed left the call silent both ways), [#199](https://github.com/idvorkin/context-grabber/issues/199), [#198](https://github.com/idvorkin/context-grabber/issues/198)

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

- **Scenario:** Interrupting Larry doesn't cost me the mic (#576)
- **Given:** a call is live and Larry is talking
- **When:** I talk over Larry and the rest of Larry's audio is dropped
- **Then:** the call keeps listening without a gap, and the audio isn't rebuilt or reported as trouble just because the dropped audio never played

- **Issues:** [#74](https://github.com/idvorkin/context-grabber/issues/74) the ask; [#73](https://github.com/idvorkin/context-grabber/issues/73) subsumed

---

### User Story 081:

- **Summary:** Call Larry with one tap, and see the phone calling the way the Phone app does
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [fac48db](https://github.com/idvorkin/context-grabber/commit/fac48db), [b15175c](https://github.com/idvorkin/context-grabber/commit/b15175c); verified by `CallScreen.test.tsx` and on the phone; native app: [d782599](https://github.com/idvorkin/context-grabber/commit/d782599), the ring still under Reduce Motion; verified by `just native-test-sim` and a simulator screenshot; the phone still to be checked by Igor

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
- **Status:** implemented in [fac48db](https://github.com/idvorkin/context-grabber/commit/fac48db), [e858a9d](https://github.com/idvorkin/context-grabber/commit/e858a9d); verified by `CallScreen.test.tsx` and on the phone; native app: [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by a simulator screenshot of the live call line; the phone still to be checked by Igor

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
- **Status:** implemented in [fac48db](https://github.com/idvorkin/context-grabber/commit/fac48db), [8a0a09e](https://github.com/idvorkin/context-grabber/commit/8a0a09e); verified by `CallScreen.test.tsx` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by `just native-test` (mute and level tests); the phone still to be checked by Igor

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
- **Status:** implemented in [4715141](https://github.com/idvorkin/context-grabber/commit/4715141); verified by `CallScreen.test.tsx` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by `just native-test` (caption tests) and `just native-test-sim` (the fake bridge's partial and final become one Igor row); the phone still to be checked by Igor; #467: the sentence leaves the box the moment it is sent, not when Tony answers, in [085663f](https://github.com/idvorkin/context-grabber/commit/085663f) ([story 216](#user-story-216)); #532: a half-said sentence stays in the box when something else arrives ([story 325](#user-story-325))

#### Use Case:
- **As a** Larry's client talking on a noisy street
- **I want to** watch my words appear large as they are recognised
- **so that** a misheard word shows up while there is still time to say it again

#### Acceptance Criteria:
- **Scenario:** A sentence is recognised
- **Given:** a call is live and the box under the call line reads *listening…*
- **When:** I say a sentence slowly
- **Then:** the words appear in the box in large type as they are recognised, and when the agent has the sentence the box returns to *listening…* and the sentence is one *Igor* row in the transcript below ([story 216](#user-story-216))

---

### User Story 216:

- **Summary:** See the moment the agent has my sentence (*heard*), without waiting for Larry's reply
- **Status:** implemented in [085663f](https://github.com/idvorkin/context-grabber/commit/085663f) and [33a965b](https://github.com/idvorkin/context-grabber/commit/33a965b) (a real repeat is not taken for the recognizer's late final) and [8f94f16](https://github.com/idvorkin/context-grabber/commit/8f94f16) (every final after a send, before the next partial, is the recognizer's late account, whatever its words); verified by `just native-test` (host: `CallSessionTests` — a heard sentence leaves the live line marked heard, two sentences heard before Larry answers are two rows, a late final spelled differently, a prefix final and two split finals are not shown, a real repeat is, the mark survives an interruption and a consult, hanging up clears it) and `just native-test-sim` (the fake bridge sends two sentences before Larry answers: both are logged as heard Igor captions and the late final as restated); the phone, on a Direct call, still to be checked by Igor; #897: the mark renamed from *sent* to *heard*, in [a2430ed](https://github.com/idvorkin/context-grabber/commit/a2430ed3) (verified by `just test` on the host — `CallSessionTests` — and `SMOKE_ONLY=call just native-test-sim` on the simulator — both of the fake bridge's rows logged heard); *sent* in the live line before it is [story 332](#user-story-332); #532: what happens to the next sentence's words when one is heard is [story 325](#user-story-325)
- **Issues:** [#467](https://github.com/idvorkin/context-grabber/issues/467), [#897](https://github.com/idvorkin/context-grabber/issues/897)
- **Spec:** [Native call — the live line](../superpowers/specs/2026-08-28-native-call-screen-design.md)

#### Use Case:
- **As a** Larry's client on a Direct call, where Larry can think for seconds before he speaks
- **I want to** see each sentence leave the live line and sit in the transcript marked *heard* the moment the agent has it
- **so that** I know what he has, and what I say next is plainly a new sentence rather than more of the last one

#### Acceptance Criteria:
- **Scenario:** Two sentences heard before Larry answers
- **Given:** a live call, on Direct or ElevenLabs, with the live line reading *listening…*
- **When:** I say a sentence, the agent has it, and I say a second one before Larry answers
- **Then:** the first sentence is an *Igor* row marked *heard* as soon as the agent has it, the second builds in a fresh live line and becomes a second *Igor* row marked *heard* — two rows, neither shown twice — and when Larry answers both *heard* marks go

---

### User Story 332:

- **Summary:** See that my sentence has left the phone (*sent*) before the agent has it
- **Status:** implemented in [a2430ed](https://github.com/idvorkin/context-grabber/commit/a2430ed3); verified by `just test` on the host (`CallSessionTests` — sent then heard, speaking again clears the mark, no mark without words or for a late final after a heard sentence; `CallWireTests` — `speech_final` and `stt_utterance_end` are read) and `SMOKE_ONLY=call just native-test-sim` on the simulator (the fake bridge's second sentence is logged sent once, then heard); the phone still to check how far apart *sent* and *heard* show
- **Issues:** [#897](https://github.com/idvorkin/context-grabber/issues/897)
- **Spec:** [Native call — the live line](../superpowers/specs/2026-08-28-native-call-screen-design.md)

#### Use Case:
- **As a** Larry's client on a call, with no other sign that what I just said got out
- **I want to** see *sent* in the live line once my sentence has left the phone, before the agent has it
- **so that** I know my words got out, and a long wait for *heard* points at the agent, not my phone

#### Acceptance Criteria:
- **Scenario:** A sentence is sent, then heard
- **Given:** a live call, on Direct or ElevenLabs, with the live line reading *listening…*
- **When:** I say a sentence and stop talking
- **Then:** a small *sent* mark appears in the live line beside my words once the recognizer has the whole sentence; if I start talking again the mark goes until I stop; when the agent has the sentence the live line empties and the sentence is an *Igor* row marked *heard* ([story 216](#user-story-216))

---

### User Story 325:

- **Summary:** Keep what I'm saying in one live line when something else arrives
- **Status:** implemented in [abc8cb2](https://github.com/idvorkin/context-grabber/commit/abc8cb2), and for a consult starting and a first word that only sits inside a sent word in the review commit after it; verified by `just native-test` (host: `CallSessionTests` — Larry's words and a consult leave a half-said sentence building in one row, a finished sentence still settles, a late transcript leaves the next sentence's words live and its final counts as new speech, a transcript that holds the live words leaves nothing behind); no device call yet
- **Issues:** [#532](https://github.com/idvorkin/context-grabber/issues/532)
- **Spec:** [Native call — the live line](../superpowers/specs/2026-08-28-native-call-screen-design.md)

#### Use Case:
- **As a** Larry's client mid-sentence on a call, with Larry and the bridge reporting things as I talk
- **I want to** see my half-said words carry on building where they are
- **so that** one sentence is one row, and nothing I'm saying blinks away

#### Acceptance Criteria:
- **Scenario:** Something arrives while I'm mid-sentence
- **Given:** a live call with half a sentence building in the live line
- **When:** words of Larry's arrive, a consult starts, or the bridge reports my previous sentence as sent
- **Then:** the words I'm saying stay in the live line and carry on building there until the turn ends or they are sent, and my sentence isn't split into two rows

---

### User Story 326:

- **Summary:** Open the Cockpit page I'm on in the browser
- **Status:** implemented in [275fcfd](https://github.com/idvorkin/context-grabber/commit/275fcfd); issue [#871](https://github.com/idvorkin/context-grabber/issues/871); verified by host tests (`LaunchHooksTests`) and the Mac build; the phone with the next deploy (`GRABBER_COCKPIT=browser` drives it on a simulator)
- **Spec:** [Cockpit tab — Open in browser](../superpowers/specs/2026-08-27-cockpit-tab-design.md)

#### Use Case:
- **As** Igor, on a Cockpit page in the app on the iPad
- **I want to** open that same page in Safari with one tap
- **so that** I get the browser's tabs, sharing and room while the app keeps its place

#### Acceptance Criteria:
- **Scenario:** A thread's page, then the browser
- **Given:** the Cockpit is showing a decision's thread
- **When:** I tap the browser button in the footer
- **Then:** Safari opens that thread's address, the app's Cockpit still shows the thread, and the session log has the address it opened

---

### User Story 085:

- **Summary:** Pick the voice that answers — Tony or my own clone
- **Status:** implemented in [3d0c38d](https://github.com/idvorkin/context-grabber/commit/3d0c38d); verified by `callVoices.test.ts` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599), the pick remembered in the settings table under the old app's key; verified by `just native-test` (voice tests); the phone still to be checked by Igor. #417: each voice's model from the Cockpit's recommendation in [1c65923](https://github.com/idvorkin/context-grabber/commit/1c65923); verified by the call host tests (the recommendation cache and the start frame) and the full `just test`, and the app compiles on the simulator; a call on the phone not yet. #428: the recommendation request gets an eight-second budget in [67247cc](https://github.com/idvorkin/context-grabber/commit/67247cc); verified by `just test` (host) and the simulator build; on the phone not yet.

#### Use Case:
- **As a** Larry's client who has heard his own cloned voice perform
- **I want to** choose Igor instead of Tony before a call
- **so that** the next call answers in my voice on the model that makes it worth hearing

#### Acceptance Criteria:
- **Scenario:** A call as Igor
- **Given:** ElevenLabs is the backend and the devices fold shows a *Voice* row with Tony highlighted
- **When:** I pick Igor, fold the pickers, and tap Call Larry
- **Then:** the devices line ends *· Igor*, the call line reads *live · 0:03 · ElevenLabs · Igor*, the voice that answers is my own on the Cockpit’s recommended model (or the bridge’s choice until recommendations arrive), the last good recommendation works offline and survives relaunch, fresh recommendations avoid a refetch, expired recommendations revalidate without delaying the call, a slow cellular recommendation has eight seconds to arrive and is saved for subsequent calls even after this call starts, and the pick survives a force-quit

- **Issues:** [#98](https://github.com/idvorkin/context-grabber/issues/98), [#417](https://github.com/idvorkin/context-grabber/issues/417), [#428](https://github.com/idvorkin/context-grabber/issues/428)

---

### User Story 086:

- **Summary:** Choose the microphone and speaker by name, folded away until needed
- **Issues:** [#293](https://github.com/idvorkin/context-grabber/issues/293)
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [c1600f0](https://github.com/idvorkin/context-grabber/commit/c1600f0), [4e12d896](https://github.com/idvorkin/context-grabber/commit/4e12d896); verified by `callDevices.test.ts` and on the phone; native app: the devices line is a menu during a call (#293): [3bd0779](https://github.com/idvorkin/context-grabber/commit/3bd0779), verified by `CallDevicesTests` (host: Automatic named after the live microphone, the one in use checked, outputs in the audio bridge's order); picking on the phone not yet

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
- **Status:** implemented in [62953e1](https://github.com/idvorkin/context-grabber/commit/62953e1), [ae01372](https://github.com/idvorkin/context-grabber/commit/ae01372), [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d); verified by `callSession.test.ts`, `callWatchdog.test.ts` and on the phone — the silent first call still recurs; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599), voice processing on from prepare every call; verified by `just native-test` (no-first-frame and zeros tests); the phone still to be checked by Igor; the zero-run rearm's evidence and its edges (#364): [6cd1ff0](https://github.com/idvorkin/context-grabber/commit/6cd1ff0), [2bba05e](https://github.com/idvorkin/context-grabber/commit/2bba05e), [387088f](https://github.com/idvorkin/context-grabber/commit/387088f), [b02aeca](https://github.com/idvorkin/context-grabber/commit/b02aeca), [00153f0](https://github.com/idvorkin/context-grabber/commit/00153f0) (the heal says what the mic and the playback held, *audio back* is logged once the restart has finished, and a recovery finishing after the hang-up logs and reports nothing for the ended call), verified by `just native-test` (`CallSessionZerosTests`, `testAProbeRearmThatFailsAfterTheHangUpIsIgnored`); on the simulator with the Mac unlocked (`SMOKE_ONLY=call just native-test-sim` at eeb1945c, 2026-11-19, and 380788c7: the real-audio call passed with 75 mic frames up, 1 s of Larry played, no zero-run re-arm and no automatic report); the 1.5-second watch narrowed to a built-in recorder with a valid sample rate, Bluetooth and a zero rate waiting 10 s (#423, story 204): [c841779](https://github.com/idvorkin/context-grabber/commit/c841779), [538d3f1](https://github.com/idvorkin/context-grabber/commit/538d3f1), verified by `just test` (host, the no-first-frame tests) and the simulator build

#### Use Case:
- **As a** Larry's client placing the day's first call
- **I want to** be heard on the first try
- **so that** I never need a second tap to start talking

#### Acceptance Criteria:
- **Scenario:** A microphone that never delivers
- **Given:** the app was force-quit and relaunched
- **and Given:** the built-in recorder has a valid sample rate but produces no buffer for a second and a half
- **When:** I tap Call Larry and say a sentence as soon as Tony greets me
- **Then:** the call's audio is torn down and brought back up on its own, and if it is still silent the call redials itself once on the same backend — *Calling Larry…* briefly, then *live* — without a tap, and my sentence is captioned; if I hang up while a recovery is still finishing, the ended call shows no new problem

- **Issues:** [#88](https://github.com/idvorkin/context-grabber/issues/88) fixed; [#95](https://github.com/idvorkin/context-grabber/issues/95) open — the bridge still receives zero mic frames on some first calls; [#364](https://github.com/idvorkin/context-grabber/issues/364) fixed — the heal's restart dropping queued playback was [#578](https://github.com/idvorkin/context-grabber/issues/578) (story 320), and the simulator's silent mic, with the automatic report it filed, came from a locked Mac ([#419](https://github.com/idvorkin/context-grabber/issues/419), story 827); the heal logs the evidence

---

### User Story 088:

- **Summary:** Audio that stops mid-call heals itself, in either direction
- **Status:** implemented in [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d), [9c50345](https://github.com/idvorkin/context-grabber/commit/9c50345); verified by `callSession.test.ts` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599) (tap re-armed up to three times, the graph rebuilt on an interruption or a configuration change); verified by `just native-test` (`CallWatchdogTests`); the phone still to be checked by Igor

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
- **Status:** implemented in [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d), [9c50345](https://github.com/idvorkin/context-grabber/commit/9c50345); verified by `callSession.test.ts` and on the phone; native app: [d782599](https://github.com/idvorkin/context-grabber/commit/d782599) (`clock_running` with after_ms before the first frame; reopened once after 2 s); verified by `just native-test-sim` (real audio: the clock ran and the bridge's second of PCM was scheduled); the phone still to be checked by Igor; a reopen that keeps the greeting is story 320

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

### User Story 320:

- **Summary:** A speaker that never started is reopened without losing Tony's greeting
- **Status:** native app only: [dc197a1](https://github.com/idvorkin/context-grabber/commit/dc197a1); verified by `just test` (host: `PlaybackTailTests`); the phone in the next build turn
- **Issues:** [#578](https://github.com/idvorkin/context-grabber/issues/578) (2026-10-30: the clock reopen threw Tony's greeting away)
- **Spec:** [Native call — Audio that stops](../superpowers/specs/2026-08-28-native-call-screen-design.md#audio-that-stops--either-direction)

#### Use Case:
- **As a** Larry's client answering on AirPods
- **I want to** hear Tony's whole greeting even when the speaker has to be reopened
- **so that** a heal fixes the speaker without costing me Larry's words

#### Acceptance Criteria:
- **Scenario:** The speaker has not started after two seconds
- **Given:** a call has just gone *live* on AirPods and Tony's greeting has arrived
- **When:** the output clock has not started after two seconds, so playback is reopened
- **Then:** the whole greeting plays on the reopened speaker, and Diagnostics shows a `call_audio` requeue line with the seconds it kept

---

### User Story 321:

- **Summary:** A car mic that gives zeros while Larry speaks does not cut his reply
- **Status:** native app only: [30c692a](https://github.com/idvorkin/context-grabber/commit/30c692a); verified by `just test` (host: `CallSessionZerosTests`); the phone in the next build turn
- **Issues:** [#577](https://github.com/idvorkin/context-grabber/issues/577) (2026-10-29, the car: the zero-run reset fired mid-reply and cut 13.7 s of Larry)
- **Spec:** [Native call — Audio that stops](../superpowers/specs/2026-08-28-native-call-screen-design.md#audio-that-stops--either-direction)

#### Use Case:
- **As a** Larry's client on a call in the car over Bluetooth
- **I want to** hear Larry's whole reply even when the car's mic goes to zeros while he speaks
- **so that** a mic quirk the reset cannot fix never costs me his words or raises a false alarm

#### Acceptance Criteria:
- **Scenario:** The car's mic gives zeros while Larry speaks
- **Given:** a live call on the car's Bluetooth whose mic has already carried my voice
- **When:** the mic gives a second of exact zeros while Larry's reply is still playing
- **Then:** his reply plays to the end without a gap or a silence warning, and only if the zeros are still there once it has finished is the call's audio reset, or if it already was, the silence said

---

### User Story 322:

- **Summary:** A call that loses its connection in a network handoff redials on its own
- **Status:** native app only: [8984bad](https://github.com/idvorkin/context-grabber/commit/8984bad), verified by `just test` (host: `CallSessionHandoffTests`); the phone in the next build turn
- **Issues:** [#440](https://github.com/idvorkin/context-grabber/issues/440), [#575](https://github.com/idvorkin/context-grabber/issues/575) (2026-10-29, the car: the socket died 0.2 s after the phone moved the call from cellular onto Wi-Fi)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client who walks into Wi-Fi, or drives out of it, mid-call
- **I want to** have the call reconnect by itself when the phone switches networks
- **so that** arriving home or the car finding Wi-Fi doesn't end my conversation

#### Acceptance Criteria:
- **Scenario:** The phone hands the call from cellular to Wi-Fi
- **Given:** a live call
- **When:** the phone's network changes and the connection to the bridge is lost within ten seconds
- **Then:** the call redials once on the same backend in the same voice — *Calling Larry…* briefly, then *live* with Larry greeting me — without a tap, and Diagnostics say it redialed after a network change

---

### User Story 323:

- **Summary:** A connection lost with no network change still ends the call
- **Status:** native app only: [8984bad](https://github.com/idvorkin/context-grabber/commit/8984bad), verified by `just test` (host: `CallSessionHandoffTests`); the phone in the next build turn
- **Issues:** [#440](https://github.com/idvorkin/context-grabber/issues/440)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client on a live call
- **I want to** see the call end *connection lost* when the bridge goes away and my network has not changed
- **so that** the app only redials for a handoff and never hides a real outage behind a retry

#### Acceptance Criteria:
- **Scenario:** The connection drops with no handoff
- **Given:** a live call whose network has not changed in the last ten seconds
- **When:** the connection to the bridge is lost
- **Then:** the call ends *connection lost*, as before

---

### User Story 752:

- **Summary:** A call that can't reach the Cockpit says so, and names Tailscale
- **Status:** implemented in [075a476](https://github.com/idvorkin/context-grabber/commit/075a476); verified on the host (`just test`: `CallSessionTests`), the Mac build (`just native-build-mac`) and the simulator call smoke (`just native-test-sim`: calls clean, a dropped call files one report)
- **Issues:** [#784](https://github.com/idvorkin/context-grabber/issues/784)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client starting a call on a device whose Tailscale is off
- **I want to** see that the call never reached the Cockpit, and why it might not have
- **so that** I turn Tailscale on instead of thinking the call dropped

#### Acceptance Criteria:
- **Scenario:** The Cockpit's address can't be found
- **Given:** the device can't find or reach the Cockpit
- **When:** I start a call
- **Then:** the call ends *can't reach the Cockpit: is Tailscale on?*, and the automatic trouble report is still filed

---

### User Story 324:

- **Summary:** A handoff redial that cannot get through ends the call instead of looping
- **Status:** native app only: [8984bad](https://github.com/idvorkin/context-grabber/commit/8984bad), verified by `just test` (host: `CallSessionHandoffTests`); the phone in the next build turn. Narrowed by story 1075 (#1417) in [0c95985a](https://github.com/idvorkin/context-grabber/commit/0c95985a): only a loss with no fresh network change ends the call
- **Issues:** [#440](https://github.com/idvorkin/context-grabber/issues/440), [#1417](https://github.com/idvorkin/context-grabber/issues/1417)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client whose phone has moved onto a network that cannot carry a call
- **I want to** have the call end after its one redial fails
- **so that** the app does not dial Larry over and over on a network that will not hold

#### Acceptance Criteria:
- **Scenario:** The redial cannot get through either
- **Given:** a call that just redialed after a handoff, and the phone's network has not changed since
- **When:** its connection is lost before any of Larry's audio arrives
- **Then:** the call ends *connection lost* and does not redial again

---

### User Story 1075:

- **Summary:** A second handoff during a redial redials again
- **Status:** native app only: [0c95985a](https://github.com/idvorkin/context-grabber/commit/0c95985a), verified by `just test` (host: `CallSessionHandoffTests`) and the Mac build (`just native-build-mac`); a real call on the road still to be checked
- **Issues:** [#1417](https://github.com/idvorkin/context-grabber/issues/1417)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client on a call in a moving car
- **I want to** have the call redial again when the network changes a second time while it is redialing
- **so that** cellular and Wi-Fi trading places twice in a few seconds does not end my call

#### Acceptance Criteria:
- **Scenario:** The network changes again during the redial
- **Given:** a call that just redialed after a handoff
- **When:** the phone's network changes again and the redial's connection is lost before any of Larry's audio arrives
- **Then:** the call redials again on the same backend and voice, and the log names it as redial 2 in the minute

---

### User Story 1076:

- **Summary:** Handoff redials stop after three in a minute
- **Status:** native app only: [0c95985a](https://github.com/idvorkin/context-grabber/commit/0c95985a), verified by `just test` (host: `CallSessionHandoffTests`) and the Mac build (`just native-build-mac`); a real call on the road still to be checked
- **Issues:** [#1417](https://github.com/idvorkin/context-grabber/issues/1417)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client on a call whose network keeps flapping
- **I want to** have the call end once it has redialed three times in a minute
- **so that** the app does not dial Larry over and over on a network that will not settle

#### Acceptance Criteria:
- **Scenario:** Too many handoffs in a minute
- **Given:** a call that has redialed after a handoff three times in the last sixty seconds
- **When:** the network changes and the connection is lost a fourth time within that minute
- **Then:** the call ends *connection lost* and does not redial

---

### User Story 1077:

- **Summary:** Larry's own caption lines are in his purple
- **Status:** native app only: implemented in [ec2bb8e3](https://github.com/idvorkin/context-grabber/commit/ec2bb8e3); verified by `just test` (host: `ChatSpeakerTests.testLarrysOwnCaptionLines`), the Mac build and the iPad Pro 11-inch (M5) simulator smoke (synthetic and real-audio calls); the purple on a real call not yet
- **Spec:** [Native call — Direct Larry](../superpowers/specs/2026-08-28-native-call-screen-design.md#direct-larry)

#### Use Case:
- **As a** Larry's client reading a call's captions
- **I want to** see what is Larry's own in Larry's purple, and Tony's and my lines as they were
- **so that** the three voices on a call, Igor, Tony and Larry, read apart at a glance, as on the Cockpit

#### Acceptance Criteria:
- **Scenario:** A call's captions name their voice by colour
- **Given:** a call with lines from me, from the voice, and tool lines or notes Larry put in himself
- **When:** I look at the captions
- **Then:** the tool lines, the notes and, on a Direct call, Larry's spoken lines carry Larry's purple label; on ElevenLabs or Drill the voice's lines are labelled *Tony* as before, and my lines are unchanged

---

### User Story 090:

- **Summary:** When Tony's audio is not arriving, read him instead
- **Status:** implemented in [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d); verified by `callSession.test.ts` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3); verified by `just native-test` (audio not arriving test); the phone still to be checked by Igor

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
- **Status:** implemented in [e858a9d](https://github.com/idvorkin/context-grabber/commit/e858a9d); verified by `callSession.test.ts` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by `just native-test` (restart test); the phone still to be checked by Igor

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
- **Status:** implemented in [b88f34e](https://github.com/idvorkin/context-grabber/commit/b88f34e); verified by `callLocation.test.ts` and on the phone; native app: wired once Places shipped (#107): [23ff3f2](https://github.com/idvorkin/context-grabber/commit/23ff3f2), verified by `CallLocationTests` (host); the Diagnostics line on a real call in the next build turn; the start and location frames are ported and tested in `CallSessionLocationTests`; the log rounds an off-place fix (bead byo): [1f90c41](https://github.com/idvorkin/context-grabber/commit/1f90c41), verified by `CallLocationTests` (host)

#### Use Case:
- **As a** Larry's client calling from the walk to school
- **I want to** have my position — a known place's name when there is one — go up with the call and again when I move
- **so that** Larry knows where I am without me saying so

#### Acceptance Criteria:
- **Scenario:** A call placed at home
- **Given:** location permission is granted and Home is a known place
- **When:** I tap Call Larry and then walk out of the Home radius
- **Then:** Diagnostics shows *location: Home (±… m)* before or shortly after *live*, one more location line reaches the log within a minute of leaving, and standing still sends none; off a known place the log line shows the position to two decimals only

- **Issues:** [#107](https://github.com/idvorkin/context-grabber/issues/107) the ask (still open: what Larry does with it is the bridge's)

---

### User Story 093:

- **Summary:** Read the call's log on the phone, with both directions counted
- **Status:** implemented in [b8d45ca](https://github.com/idvorkin/context-grabber/commit/b8d45ca), [6df0f65](https://github.com/idvorkin/context-grabber/commit/6df0f65), [ae01372](https://github.com/idvorkin/context-grabber/commit/ae01372), [7db050d](https://github.com/idvorkin/context-grabber/commit/7db050d); verified by `callLog.test.ts` and on the phone (every bug from #88 on was read from it); native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599) — the call's log is the session log, the fold shows this launch's `call_*` events with a rule between calls; verified by `just native-test` (`CallEventLogTests`) and `just native-test-sim` (the bridge received the dump at the hang-up); the phone still to be checked by Igor

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
- **Status:** implemented in [7504fa6](https://github.com/idvorkin/context-grabber/commit/7504fa6), [8a0a09e](https://github.com/idvorkin/context-grabber/commit/8a0a09e), [670084c](https://github.com/idvorkin/context-grabber/commit/670084c); verified by `gistUpload.test.ts` and on the phone (a device build: the Keychain is native); native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599), the token entered under Diagnostics uploads on the native home screen; verified by `just native-test` (GistTests (gone: the gist upload went in 0a56f3a6), the trouble rule in `CallEventLogTests`); a real gist is the phone still to be checked by Igor; the Swift-native app no longer uploads gists (2026-10-11): it files an automatic report instead, [story 248](#user-story-248)

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
- **Status:** implemented in [7504fa6](https://github.com/idvorkin/context-grabber/commit/7504fa6), [8a0a09e](https://github.com/idvorkin/context-grabber/commit/8a0a09e), [670084c](https://github.com/idvorkin/context-grabber/commit/670084c); verified by `gistUpload.test.ts` and on the phone; native app: [f6092a3](https://github.com/idvorkin/context-grabber/commit/f6092a3), [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by `just native-test` (GistTests (gone: the gist upload went in 0a56f3a6): prune, retire, already gone); the phone still to be checked by Igor; the Swift-native app no longer uploads gists (2026-10-11): it files an automatic report instead, [story 248](#user-story-248)

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

### User Story 248:

- **Summary:** A call that went wrong files a report on its own, and the Mac files the issue
- **Status:** implemented in [0a56f3a](https://github.com/idvorkin/context-grabber/commit/0a56f3a) (the report, the gist gone) and [9fd7f3b](https://github.com/idvorkin/context-grabber/commit/9fd7f3b) (the smoke check: a dropped call reports once, a second is skipped); verified on the simulator by `just native-test-sim` (2026-10-11: a clean call files none, a dropped call files one with call-log.txt, a second after a relaunch is skipped, now BugKit's host tests `bug-kit:AutoReportTests.oneReportPerReasonPerWindow` and `theWindowHoldsAcrossARelaunch` rather than a smoke relaunch; smoke-check fix [7c4ed4b](https://github.com/idvorkin/context-grabber/commit/7c4ed4b)); the listener filing one and a real troubled call on the phone not yet; a mic re-arm that brought the mic back files none: [59c5805](https://github.com/idvorkin/context-grabber/commit/59c5805), [ebd1f73](https://github.com/idvorkin/context-grabber/commit/ebd1f73), verified on the host by `CallDiagnosticsTests` and `CallSessionTests`; the smoke judges each clean call on its own log and counts a report the window held back as filed, so a rerun inside ten minutes can't hide a failure: 4ee1f8a0 (story 1026, bead `context-grabber-qj5y`), verified on the simulator
- **Issues:** [#450](https://github.com/idvorkin/context-grabber/issues/450), [#348](https://github.com/idvorkin/context-grabber/issues/348): a mic re-arm that brought the mic back is not trouble; verified by `CallDiagnosticsTests` and `CallSessionTests` (host). [#545](https://github.com/idvorkin/context-grabber/issues/545): a failed Larry tool answer is not the call's trouble, in the #545 fix; verified by `CallDiagnosticsTests` (host)
- **Spec:** [Swift-native app](../superpowers/specs/2026-10-04-swift-native-app-design.md)

#### Use Case:
- **As a** Larry's client who just hung up on a call that went wrong
- **I want to** have its log reach a GitHub issue without copying, uploading or a token on the phone
- **so that** the evidence of every troubled call is there when I sit down at the Mac, and nothing private is posted before then

#### Acceptance Criteria:
- **Scenario:** A connection is lost mid-call
- **Given:** the native app on the phone
- **When:** the bridge dies mid-call and the call ends with *connection lost*
- **Then:** the phone saves a report on its own, with the call's log, the reason and this launch's log named, and no screenshot or note; nothing is uploaded from the phone

- **Scenario:** The Mac picks it up
- **Given:** a report saved after a troubled call
- **When:** the Mac's listener next reaches the phone
- **Then:** it files one GitHub issue titled *Automatic report: call_trouble* with the call's log, once

- **Scenario:** A call that keeps failing
- **Given:** a report was saved for a troubled call less than ten minutes ago, even across a relaunch
- **When:** another call ends in trouble
- **Then:** no second report is saved, and the log says it was skipped; a clean call saves nothing

- **Scenario:** Larry's side fails, the call does not (#545)
- **Given:** a call whose audio, connection and ending were all fine
- **When:** the bridge says a question it put to Larry got no usable answer (a failed tool answer)
- **Then:** no report is saved, since that is Larry's side and not the call's, and the call's log still has the line

- **Scenario:** The mic repairs itself (#450, #348)
- **Given:** a call whose mic went quiet during a pause
- **When:** the app re-arms the mic, it comes back, and the call carries on and ends well
- **Then:** no report is saved, and the call's log still has the lines

- **Scenario:** The mic repair does not work (#450, #348)
- **Given:** a call whose mic went quiet during a pause
- **When:** the app re-arms the mic, and the re-arm fails, never reports back, or the call ends with no sign the mic returned
- **Then:** the phone saves a report, as for any other troubled call

- **Scenario:** A very long call
- **Given:** the call's log is longer than the report's 5 MB
- **When:** the report is saved
- **Then:** it keeps the newest lines, from a line boundary, and the log says it was cut

- **Scenario:** No gist left behind
- **Given:** the home screen's Settings tile
- **When:** I look for *Diagnostics uploads*
- **Then:** it is gone: no token to enter and nothing to delete; *Copy diagnostics* on the call still copies the log

---

### User Story 096:

- **Summary:** The Cockpit dashboard lives in a tab and keeps its place
- **Status:** implemented in [a11f583](https://github.com/idvorkin/context-grabber/commit/a11f583), [4e12d89](https://github.com/idvorkin/context-grabber/commit/4e12d89); verified by `CockpitScreen.test.tsx` and on the phone. Native: [63a012a](https://github.com/idvorkin/context-grabber/commit/63a012a) (a screen kept for the launch, story 200); verified by `CockpitBridgeTests` (host) and the `cockpit:` checks in `sim-smoke.sh` (simulator) and a simulator screenshot of the tailnet page; on the phone: not yet. The unreachable panel, and that it comes down when a page then loads, moved from the smoke to `CockpitPageStateTests`: [a3436a9](https://github.com/idvorkin/context-grabber/commit/a3436a9); verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending

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
- **Status:** implemented in [19533fc](https://github.com/idvorkin/context-grabber/commit/19533fc), [f8d2f3a](https://github.com/idvorkin/context-grabber/commit/f8d2f3a); verified by `audioBridge.test.ts`, `cockpitClient.test.ts` and on the phone. Native: [63a012a](https://github.com/idvorkin/context-grabber/commit/63a012a); verified by `CockpitBridgeTests` (host) and the `cockpit:` checks in `sim-smoke.sh` (simulator) (a device list delivered and acknowledged, the tag on the address) and the real tailnet page asking the native bridge for its roster on the simulator; real headsets on the phone: not yet

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
- **Status:** implemented in [cef19fc](https://github.com/idvorkin/context-grabber/commit/cef19fc), [8d35bb6](https://github.com/idvorkin/context-grabber/commit/8d35bb6), [a902080](https://github.com/idvorkin/context-grabber/commit/a902080), [b10e8d5](https://github.com/idvorkin/context-grabber/commit/b10e8d5); verified by `deepLink.test.ts`, `audioBridge.test.ts` and on the phone. Native: [63a012a](https://github.com/idvorkin/context-grabber/commit/63a012a) parses `call.start` / `call.focus` and hands the page's `grabber://call` to iOS, which opens Context Grabber's Call tab until the native call lands; verified by `BridgeParseTests`, `CockpitPageTests` (host); on the phone: not yet
- **Status:** implemented in [cef19fc](https://github.com/idvorkin/context-grabber/commit/cef19fc), [8d35bb6](https://github.com/idvorkin/context-grabber/commit/8d35bb6), [a902080](https://github.com/idvorkin/context-grabber/commit/a902080), [b10e8d5](https://github.com/idvorkin/context-grabber/commit/b10e8d5); verified by `deepLink.test.ts`, `audioBridge.test.ts` and on the phone; native app: the Call Larry Shortcut only (story 202); links and the widget wait for step 7

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

- **Summary:** Larry hears that I arrived at a known place, within a few minutes, without a call
- **Status:** implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84). Verified on the phone on 2026-11-21 (main [a666883](https://github.com/idvorkin/context-grabber/commit/a666883), the Cockpit taking `POST /context` since idvorkin-ai-tools/cockpit 2b2bb45): the pulled session log has eight `live_context` events, each `detected` and then `sent`, 0 to 6 s after it settled (arrived at Flow fitness at 11:34 and 13:57, at home at 11:57 and 15:55). The detection (five minutes inside, silence counting as staying, a fix less precise than 100 m ignored) is built in [27eff19](https://github.com/idvorkin/context-grabber/commit/27eff19) and verified by host tests (`LiveContextDetectorTests`, on the real fixture trail too). Holding and sending to the Cockpit's `POST /context` (the shape proposed to Larry on 2026-11-20) is built in [4f278d6](https://github.com/idvorkin/context-grabber/commit/4f278d6) and verified by host tests against a fake Cockpit (`LiveContextSendTests`). Spec: [live context](../superpowers/specs/2026-10-17-native-live-context-design.md)

#### Use Case:
- **As a** Larry's client arriving at the gym
- **I want to** have the arrival reach Larry without a call
- **so that** the coaching is live context, not only what I bring to a call

#### Acceptance Criteria:
- **Scenario:** Arriving at a known place
- **Given:** Kettlebility is a known place, location recording is on and the app is in the background
- **When:** the phone has been inside its circle for five minutes
- **Then:** Larry's record shows *arrived at Kettlebility* with the time I walked in, and the session log has a `live_context` line for it

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84)

---

### User Story 1070:

- **Summary:** Turning Background tracking off stops Larry hearing about an arrival or departure not yet noticed
- **Status:** implemented in [1e6fe81](https://github.com/idvorkin/context-grabber/commit/1e6fe81); verified by host tests (`LiveContextSendTests.testWithRecordingOffTheQuietSettlesNothing`, which did not build before the fix) and the Mac build; the phone not yet. Spec: [live context](../superpowers/specs/2026-10-17-native-live-context-design.md)

#### Use Case:
- **As a** Larry's client who turns Background tracking off
- **I want to** have nothing about where I am reach Larry once recording is off
- **so that** switching tracking off means the phone stops telling Larry where I go

#### Acceptance Criteria:
- **Scenario:** Background tracking turned off before the five minutes are up
- **Given:** I walked into Kettlebility two minutes ago, *Tell Larry when I arrive and leave* is on, and I have just turned Background tracking off
- **When:** I open the app an hour later
- **Then:** nothing is sent about Kettlebility, while an arrival or departure noticed before tracking went off still goes

- **Issues:** context-grabber-1zrt (a foreground after tracking went off let a pending arrival or departure settle and be sent)

---

### User Story 335:

- **Summary:** Larry hears that I left a known place, timed when I walked out
- **Status:** implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84). Verified on the phone on 2026-11-21 (main [a666883](https://github.com/idvorkin/context-grabber/commit/a666883), the Cockpit taking `POST /context` since idvorkin-ai-tools/cockpit 2b2bb45): the pulled session log has eight `live_context` events, each `detected` and then `sent`, 0 to 6 s after it settled (left Flow fitness after 6 and 106 minutes, home after 78 and 26, each with its minutes stayed). The detection (five minutes outside, the time of the first position outside, how long I stayed) is built in [27eff19](https://github.com/idvorkin/context-grabber/commit/27eff19) and verified by host tests (`LiveContextDetectorTests`); sending it, with the minutes stayed, in [4f278d6](https://github.com/idvorkin/context-grabber/commit/4f278d6), verified by `LiveContextSendTests` against a fake Cockpit

#### Use Case:
- **As a** Larry's client leaving the gym
- **I want to** have the departure reach Larry with when I left
- **so that** he knows the session is over and how long it was

#### Acceptance Criteria:
- **Scenario:** Leaving a known place
- **Given:** the phone has told Larry I arrived at Kettlebility
- **When:** it has been outside the circle for five minutes
- **Then:** Larry's record shows *left Kettlebility* with the time of the first position outside, and a `live_context` line names it

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84)

---

### User Story 336:

- **Summary:** Passing a known place, or a position the phone itself reports as imprecise, tells Larry nothing
- **Status:** implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84). Built in [27eff19](https://github.com/idvorkin/context-grabber/commit/27eff19); verified by host tests (`LiveContextDetectorTests`: driving past, stepping out and back, a 1.4 km fix at home on the real trail sending no departure)

#### Use Case:
- **As a** Larry's client who drives past the gym on the way to work
- **I want to** have only real arrivals and departures reach Larry
- **so that** he never congratulates me on a workout I drove past

#### Acceptance Criteria:
- **Scenario:** Driving past a known place
- **Given:** Kettlebility is a known place and location recording is on
- **When:** the phone passes through its circle in under five minutes
- **Then:** nothing is sent to Larry

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84)

---

### User Story 337:

- **Summary:** An arrival made off the tailnet waits, and reaches Larry with the time it happened
- **Status:** implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84). Held, retried oldest first with the same id, refused ones not retried, dropped after a day: built in [4f278d6](https://github.com/idvorkin/context-grabber/commit/4f278d6), verified by host tests against a fake Cockpit (`LiveContextSendTests`). The Cockpit takes them since 2026-11-20 (idvorkin-ai-tools/cockpit 2b2bb45); on the phone every event so far went at once (2026-11-21), so a wait off the tailnet is not yet seen there

#### Use Case:
- **As a** Larry's client whose phone is sometimes off the tailnet
- **I want to** have an arrival the Cockpit could not take sent later, once
- **so that** Larry hears it with the time I walked in, not the time it got through

#### Acceptance Criteria:
- **Scenario:** The Cockpit unreachable at the gym
- **Given:** the phone cannot reach the Cockpit when it settles at Kettlebility
- **When:** the Cockpit is next reachable, within a day
- **Then:** Larry's record shows *arrived at Kettlebility* once, with the time I walked in, and the session log shows the `live_context` line waiting and then sent

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84)

---

### User Story 338:

- **Summary:** One switch in Places stops Larry hearing where I go, and says what it last sent
- **Status:** implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84). Built in [a795fca](https://github.com/idvorkin/context-grabber/commit/a795fca), [dc4fcfe](https://github.com/idvorkin/context-grabber/commit/dc4fcfe), [acf9c86](https://github.com/idvorkin/context-grabber/commit/acf9c86), [aa6e613](https://github.com/idvorkin/context-grabber/commit/aa6e613) (the switch and its line; the send's background time ended when iOS says it is up; the UI test; switching off cancels the send under way, and the line's wording with tracking off), [0839f56](https://github.com/idvorkin/context-grabber/commit/0839f56) (a send cancelled by switching off sends nothing more and logs `cancelled`, not a stale `waiting`: `LiveContextSendTests`, host). The line's wording is verified by host tests (`LiveContextStatusTests`); the switch turning off and saying so on the simulator (`LiveContextSwitchUITests`, iPhone 17, 2026-11-20); the phone not yet seen

#### Use Case:
- **As a** Larry's client who wants a day to himself
- **I want to** turn off *Tell Larry when I arrive and leave* in Places
- **so that** nothing about where I go leaves the phone until I turn it back on

#### Acceptance Criteria:
- **Scenario:** The switch off
- **Given:** *Tell Larry when I arrive and leave* is off and background tracking is on
- **When:** I arrive at and leave Kettlebility
- **Then:** nothing is sent, the line under the switch says it is off, and turning it back on sends nothing about where I already am; turned off while a send is under way, nothing more goes and the session log says the send was cancelled

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84), context-grabber-x9ko

---

### User Story 339:

- **Summary:** Larry can nudge the phone back with a line
- **Status:** not implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84), the second half, after arrivals and departures

#### Use Case:
- **As a** Larry's client
- **I want to** have a note Larry sends appear on the phone
- **so that** he can nudge me where I am, without Telegram

#### Acceptance Criteria:
- **Scenario:** A nudge from Larry
- **Given:** Larry has heard I arrived at Kettlebility
- **When:** he sends a line to the phone
- **Then:** it appears on the phone as a notification

- **Issues:** [#84](https://github.com/idvorkin/context-grabber/issues/84)

---

### User Story 200:

- **Summary:** In Grabber Native the Cockpit is a full-screen page from the home screen, and Done keeps it
- **Status:** implemented in [63a012a](https://github.com/idvorkin/context-grabber/commit/63a012a) (native), the ☎ staying in the app in [d061129](https://github.com/idvorkin/context-grabber/commit/d061129) (CockpitCallUITests on the simulator, its check since folded into `CockpitBackUITests`: one call on the page's backend, the fallback link caught as a duplicate); verified by `CockpitBridgeTests` (host), the `cockpit:` checks in `sim-smoke.sh` and a simulator screenshot of the tailnet page, the bridge test page and the unreachable panel; on the phone: not yet. Back and Cockpit in the footer (#234): [c1c6e53](https://github.com/idvorkin/context-grabber/commit/c1c6e53); verified by `CockpitBackUITests` on the simulator (a page the stand-in Cockpit opened in place shows Back, Back returns and the button goes, Cockpit returns from two pages deep, Done leaves) and CockpitCallUITests still passing; since [105485e7](https://github.com/idvorkin/context-grabber/commit/105485e7) (#905) the ☎ check is the last step of `CockpitBackUITests`' launch, passing on the simulator. The panel no longer outlives a failed page (Back or Cockpit after a 404 loads, then shows the page with no panel), and which buttons show is `CockpitPageStateTests`: [a3436a9](https://github.com/idvorkin/context-grabber/commit/a3436a9); verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending. A first open's link tap that went nowhere (`CockpitBackUITests`' first try): the session log has each navigation as WebKit asks for it and starts it, and the bridge test page shows what it saw of the tap (context-grabber-ybo3); verified on the Mac build and the host rung. A UI test's ☎ dials no real bridge: story 1072.
- **Issues:** [#234](https://github.com/idvorkin/context-grabber/issues/234), context-grabber-ybo3 (open: the cause waits on an instrumented miss)
- **Spec:** [native Cockpit](../superpowers/specs/2026-10-05-native-cockpit-design.md)

#### Use Case:
- **As a** Larry's client trying the native app beside Context Grabber
- **I want to** open the Cockpit from the native app's home screen, step back to it, and find the dashboard as I left it
- **so that** the native app carries the decision queue — with the real microphone and output pickers — before it replaces the old one

#### Acceptance Criteria:
- **Scenario:** Done and back
- **Given:** I opened *Cockpit* on Grabber Native's home screen, scrolled down and expanded a row
- **When:** I tap *Done* in the footer and then *Cockpit* again
- **Then:** the dashboard is at the same place with the row expanded and no loading flash; the page's address carries `client=context-grabber` with the native build, its pickers list the phone's microphones and outputs

- **Scenario:** Back from a page the Cockpit opened
- **Given:** I opened Lavish (or a blog proposal) from the dashboard, and it opened in place
- **When:** I tap *Back* in the footer, or *Cockpit* from a page or two deeper
- **Then:** Back goes one page back and disappears on the dashboard, Cockpit goes straight to the dashboard, *Done* still leaves the Cockpit, and the session log has `cockpit_nav` as the tap's page starts, then `cockpit_page`, `cockpit_back` and `cockpit_home` with the addresses

- **Scenario:** Back from a page that failed
- **Given:** a page the dashboard opened answered 404 (or could not load), and the *Can't reach the Cockpit* panel covers it
- **When:** I tap *Back* or *Cockpit* in the footer
- **Then:** the panel comes down and the spinner shows while the page loads, then the page before it shows with no panel over it; a page that fails again brings the panel back with its own address and reason

- **Scenario:** The page's ☎ stays in the app
- **Given:** Grabber Native's Cockpit is open and no call is up
- **When:** I tap the page's ☎
- **Then:** the Cockpit steps back and Grabber Native's Call screen comes up with one call starting, on the backend the page asked for; Context Grabber does not open. Tapping ☎ again from the Cockpit during that call brings the same call forward

---

### User Story 201:

- **Summary:** Leave the call screen and come back to the same call
- **Status:** native app only: implemented in [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by build and the simulator smoke (the call is owned by the app model, the screen only shows it), leaving and returning not exercised by a script; the phone still to be checked by Igor

#### Use Case:
- **As a** Larry's client who wants to check the timer or report a problem mid-call
- **I want to** close the call screen without ending the call and find it again from the home screen
- **so that** the call is the app's, not a screen I must keep open

#### Acceptance Criteria:
- **Scenario:** Done mid-call
- **Given:** a call is live in Grabber Native and Tony is talking
- **When:** I tap *Done* and look at the home screen
- **Then:** Tony keeps talking, the Call row reads *live · 0:42 · ElevenLabs · Tony* and counts on, and a tap on it shows the same captions and the same timer, with the session log showing `close_call` and `open_call` and no `call_ended` between them

---

### User Story 202:

- **Summary:** Call Larry from a Shortcut in the native app
- **Status:** native app only: implemented in [d782599](https://github.com/idvorkin/context-grabber/commit/d782599); verified by build only (Shortcuts cannot run on the simulator from a script); the phone still to be checked by Igor

#### Use Case:
- **As a** Larry's client with the Action Button set to a Shortcut
- **I want to** run *Call Larry* from Grabber Native's actions
- **so that** the call that survives the lock is one press away while the native app replaces the old one

#### Acceptance Criteria:
- **Scenario:** The Shortcut with no call up
- **Given:** Grabber Native is closed and ElevenLabs is the remembered backend
- **When:** I run Grabber Native's *Call Larry* action from the Shortcuts app
- **Then:** the app opens on the call screen and the call goes *live* on ElevenLabs without a tap, the session log shows `open_call` from shortcut and `call_start`, and running it again mid-call brings the call forward without a second `call_start`

---

### User Story 203:

- **Summary:** What is left of Claude's week and of the voice budget, as a strip on the native home screen
- **Status:** implemented in [3da9e54](https://github.com/idvorkin/context-grabber/commit/3da9e54) (native); verified by `CockpitUsageTests` (host) and the simulator against the live Cockpit (strip drawn: Week 31%, Fable 13% orange, Voice 3.8h; unreachable Cockpit: no strip, `usage` load ok:false in the log); the refresh ask's Origin checked with curl (403 without, 202 with); on the phone: not yet; the *to spend* nudge [aa054d2](https://github.com/idvorkin/context-grabber/commit/aa054d2) verified by `CockpitUsageTests` and a simulator screenshot against the live Cockpit (*28% to spend · resets in 6H*); the thinner card, verified by a simulator screenshot against the live Cockpit: [adfed5a](https://github.com/idvorkin/context-grabber/commit/adfed5a)
- **Spec:** [native Cockpit — the usage strip](../superpowers/specs/2026-10-05-native-cockpit-design.md#the-usage-strip-on-the-home-screen)

#### Use Case:
- **As a** Larry's client who spends Claude and ElevenLabs all week
- **I want to** see how much of the weekly allowance, the current model's allowance and the voice budget is left the moment I open the native app
- **so that** I pace the week without opening the Cockpit, and a call to Larry never dies on an empty voice budget

#### Acceptance Criteria:
- **Scenario:** A glance at what is left
- **Given:** the phone is on the tailnet and the Cockpit has a usage reading
- **When:** I open Grabber Native
- **Then:** above the rows a thin card, about two lines tall with hairline bars, shows Week, the model and Voice left as bars with their numbers, when the week resets and the pacing verdict; a bar under 20% is orange, under 10% red; a stale reading says its age

- **Scenario:** Quota about to go to waste
- **Given:** the week resets in 13 hours and 31% of it is left
- **When:** I open Grabber Native
- **Then:** the line under the bars starts with *31% to spend* in green; a day earlier, or with under 20% left, it does not

- **Scenario:** Refresh and off the tailnet
- **Given:** the strip is showing
- **When:** I tap it
- **Then:** it says *refreshing…* until Larry has taken a new reading (about a minute) and then shows it; and with Tailscale off the home screen shows no strip and no error

---

### User Story 204:

- **Summary:** A slow Bluetooth microphone gets time to settle before the call heals
- **Status:** implemented in [c841779](https://github.com/idvorkin/context-grabber/commit/c841779), [538d3f1](https://github.com/idvorkin/context-grabber/commit/538d3f1); verified by `just test` (host, `MicStartupDeadlineTests` and the no-first-frame tests) and the simulator build; a call in the car not yet.
- **Issues:** [#423](https://github.com/idvorkin/context-grabber/issues/423)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client calling from the car
- **I want to** let its Bluetooth microphone finish connecting
- **so that** the call's recovery does not keep restarting a microphone that is still waking up

#### Acceptance Criteria:
- **Scenario:** The car microphone starts slowly
- **Given:** the current route is Bluetooth or the microphone reports a zero sample rate, and no microphone buffer has arrived
- **When:** I call Larry and the microphone takes almost ten seconds after opening to deliver its first buffer
- **Then:** neither a no-buffer audio reset nor a redial interrupts those ten seconds, the first buffer cancels that heal, and Diagnostics record the deadline and reason; if no buffer arrives by ten seconds, the existing reset and one-time redial apply, while a valid built-in or wired microphone keeps its 1.5-second watch

---

### User Story 334:

- **Summary:** A car microphone that the audio reopens while it is still starting gets its full window again
- **Status:** implemented in [e2e4d7a](https://github.com/idvorkin/context-grabber/commit/e2e4d7a3); verified by `just test` (host, `MicStartupDeadlineTests`: a reopen 2 s into a Bluetooth window gives ten more seconds, an ordinary-looking reopen never shortens it, a Bluetooth reopen grows an ordinary one, a reopen after the first buffer changes nothing, a fourth reopen keeps the window running) and `SMOKE_ONLY=call just native-test-sim` (the synthetic fake-bridge call; the real-audio call was skipped with the Mac locked, so the engine side is built, not run); a call in the car not yet
- **Issues:** [#433](https://github.com/idvorkin/context-grabber/issues/433)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client calling from the car
- **I want to** have the Bluetooth microphone's settling window start again when the audio rebuilds itself before the microphone has delivered anything
- **so that** a rebuild early in startup does not cut the microphone's time short and set off a reset while it is still waking up

#### Acceptance Criteria:
- **Scenario:** The audio reopens the microphone during its startup window
- **Given:** a call whose Bluetooth microphone has a ten-second window and has delivered no buffer
- **When:** two seconds in, the audio rebuilds itself and opens the microphone again
- **Then:** no reset comes until ten seconds after that reopen, the window is never shortened by it, Diagnostics record the restart and what reopened the microphone, a reopen after the first buffer changes nothing, and after three reopens in one window a fourth leaves the window running so a flapping route cannot hold off the reset

---

### User Story 205:

- **Summary:** Call Direct Larry from the app — my words straight to Larry, his answer in his own voice
- **Status:** implemented in [cfa3db4](https://github.com/idvorkin/context-grabber/commit/cfa3db4); verified by `just test` (host: `CallWireTests`, `CallSessionTests.testADirectCallNamesTheBackendAndSendsNoVoiceOrModel`, `AppLinkTests`, `CockpitBridgeTests`, `CallSettingsTests`) and on the simulator against the fake bridge (*live · Direct*, Larry's line captioned *Larry*, five backends fitting the row); a real Direct call on the phone not yet.
- **Issues:** [#436](https://github.com/idvorkin/context-grabber/issues/436)
- **Spec:** [Native call — Direct Larry](../superpowers/specs/2026-08-28-native-call-screen-design.md#direct-larry)

#### Use Case:
- **As a** Larry's client who wants to talk to Larry himself, not a voice model that phones him
- **I want to** pick *Direct* on the Call screen
- **so that** the call reaches the Cockpit's Direct Larry and the conversation is with him

#### Acceptance Criteria:
- **Scenario:** Placing a Direct call
- **Given:** the Call screen is idle
- **When:** I pick *Direct* and tap Call Larry
- **Then:** the call goes live on the bridge's Direct Larry with its own model and voice, the status line reads *live · … · Direct*, Larry's lines are captioned *Larry*, there is no Voice row, and the next call starts on Direct too

---

### User Story 206:

- **Summary:** Ask for Direct Larry from outside the Call screen
- **Status:** implemented in [cfa3db4](https://github.com/idvorkin/context-grabber/commit/cfa3db4); verified by `just test` (host: `CallWireTests`, `CallSessionTests.testADirectCallNamesTheBackendAndSendsNoVoiceOrModel`, `AppLinkTests`, `CockpitBridgeTests`, `CallSettingsTests`) and on the simulator against the fake bridge (*live · Direct*, Larry's line captioned *Larry*, five backends fitting the row); a real Direct call on the phone not yet.
- **Issues:** [#436](https://github.com/idvorkin/context-grabber/issues/436)
- **Spec:** [Native call — Direct Larry](../superpowers/specs/2026-08-28-native-call-screen-design.md#direct-larry)

#### Use Case:
- **As a** Larry's client starting a call from a link, a shortcut or a Cockpit page
- **I want to** name Direct Larry there
- **so that** the call starts on Direct without my opening the backend row first

#### Acceptance Criteria:
- **Scenario:** Every way in
- **Given:** an entry point set to Direct: the link `grabbernative://call?via=direct`, the Call Larry shortcut with backend *Direct Larry*, or ☎ on a Cockpit page set to Direct Larry inside the app
- **When:** I use it
- **Then:** the call starts on Direct

---

### User Story 207:

- **Summary:** The other backends keep Tony and the Voice row when Direct joins them
- **Status:** implemented in [cfa3db4](https://github.com/idvorkin/context-grabber/commit/cfa3db4); verified by `just test` (host: `CallWireTests`, `CallSessionTests.testADirectCallNamesTheBackendAndSendsNoVoiceOrModel`, `AppLinkTests`, `CockpitBridgeTests`, `CallSettingsTests`) and on the simulator against the fake bridge (*live · Direct*, Larry's line captioned *Larry*, five backends fitting the row); a real Direct call on the phone not yet.
- **Issues:** [#436](https://github.com/idvorkin/context-grabber/issues/436)
- **Spec:** [Native call — Direct Larry](../superpowers/specs/2026-08-28-native-call-screen-design.md#direct-larry)

#### Use Case:
- **As a** Larry's client who calls through a voice model
- **I want to** keep the call I had before Direct arrived
- **so that** Direct changes nothing about ElevenLabs, Gemini, OpenAI or Drill

#### Acceptance Criteria:
- **Scenario:** The other backends are unchanged
- **Given:** I picked ElevenLabs (shown as *Eleven* in the row), Gemini, OpenAI or Drill
- **When:** I call
- **Then:** Larry's lines are captioned *Tony* as before and the Voice row is where it was

---

### User Story 208:

- **Summary:** A microphone that fails to open still gets the call's reset and redial
- **Status:** implemented in [40f5d77](https://github.com/idvorkin/context-grabber/commit/40f5d77), the foreground state on a successful start too in [746a960](https://github.com/idvorkin/context-grabber/commit/746a960) (instrumentation only, #582's cause is not yet known); verified by `just test` (host: `CallSessionMicTests` — a failed open resets then redials, a failed reset still redials, a buffer clears the line — and `ErrorDetailTests`) and the simulator build; whether the reset or the redial recovers from the phone's *unspecified* audio error, and what a successful start logs, are not yet seen on the phone
- **Issues:** [#582](https://github.com/idvorkin/context-grabber/issues/582) (the engine is refused when the phone locks just after the tap: every refusal logged the app in the background, so that case no longer resets or redials, it holds — story 829), [#441](https://github.com/idvorkin/context-grabber/issues/441) (the phone's audio refused to start, *avfaudio error 2003329396*, and the call sat silent until the bridge hung up)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client whose phone refuses to start its audio
- **I want to** have the call try its reset and its one redial on its own
- **so that** a call that failed to open the microphone recovers, or says so, instead of sitting silent until the bridge hangs up

#### Acceptance Criteria:
- **Scenario:** The microphone fails to open
- **Given:** a live call whose microphone failed to open, so the screen says *microphone failed*
- **When:** no microphone buffer arrives within the startup deadline
- **Then:** the call resets its audio once; if the reset fails or still brings no buffer, it redials once; a buffer after the reset clears *microphone failed*; and Diagnostics record the session, route, formats and the error's own code for every failed audio start, and the foreground state as the start was tried for every audio start, failed or not

---

### User Story 829:

- **Summary:** A call started just before the phone locks waits for me to open Grabber
- **Status:** implemented in [3f45a4b](https://github.com/idvorkin/context-grabber/commit/3f45a4b) and [6dc765b](https://github.com/idvorkin/context-grabber/commit/6dc765b); verified by `just native-test` (host: `CallHoldTests` and `CallSessionHoldTests`) and the Mac build (`just native-build-mac`); the phone still to do — only a phone can lock between the tap and the mic opening
- **Issues:** [#582](https://github.com/idvorkin/context-grabber/issues/582)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client who taps Call and pockets the phone, or switches to another app, in the same breath
- **I want to** have the call wait for me and tell me to open Grabber
- **so that** the call is not torn down and redialled in the background where iOS refuses the mic every time

#### Acceptance Criteria:
- **Scenario:** The phone locks before the mic opens
- **Given:** I tapped Call and the phone locked before the microphone started
- **When:** iOS refuses to start the microphone because the app is not in front
- **Then:** the call stays connected and holds: no reset, no redial, no trouble report; the screen says *Open Grabber to start the mic*; and one notification says *Larry's call is waiting — Open Grabber to start the mic.*

---

### User Story 327:

- **Summary:** Opening Grabber starts a held call's mic
- **Status:** implemented in [3f45a4b](https://github.com/idvorkin/context-grabber/commit/3f45a4b) and [6dc765b](https://github.com/idvorkin/context-grabber/commit/6dc765b); verified by `just native-test` (host: `CallHoldTests` and `CallSessionHoldTests`) and the Mac build (`just native-build-mac`); the phone still to do
- **Issues:** [#582](https://github.com/idvorkin/context-grabber/issues/582)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client who taps Call and pockets the phone, or switches to another app, in the same breath
- **I want to** have my mic start the moment I open Grabber
- **so that** the call I started goes on without my tapping Call again

#### Acceptance Criteria:
- **Scenario:** I open Grabber
- **Given:** a held call (story 829)
- **When:** I unlock and open Grabber, or tap the notification (which opens the call screen)
- **Then:** the microphone starts at once, with echo cancellation as on any call; Larry's voice, if it was playing, keeps playing; the call goes on; and the notification is gone

---

### User Story 328:

- **Summary:** A held call I never come back to ends after five minutes
- **Status:** implemented in [3f45a4b](https://github.com/idvorkin/context-grabber/commit/3f45a4b) and [6dc765b](https://github.com/idvorkin/context-grabber/commit/6dc765b); verified by `just native-test` (host: `CallHoldTests` and `CallSessionHoldTests`) and the Mac build (`just native-build-mac`); the phone still to do
- **Issues:** [#582](https://github.com/idvorkin/context-grabber/issues/582)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client who taps Call and pockets the phone, or switches to another app, in the same breath
- **I want to** have a call I forgot about end on its own
- **so that** nothing sits connected or redials while the phone is in my pocket

#### Acceptance Criteria:
- **Scenario:** I never come back
- **Given:** a held call (story 829)
- **When:** five minutes pass without the app coming forward
- **Then:** the call ends as a hang-up does, saying *the mic never started: Grabber was not opened within 5 minutes* with *Copy error*, and nothing redials

---

### User Story 329:

- **Summary:** A call still holds when notifications are off
- **Status:** implemented in [3f45a4b](https://github.com/idvorkin/context-grabber/commit/3f45a4b) and [6dc765b](https://github.com/idvorkin/context-grabber/commit/6dc765b); verified by `just native-test` (host: `CallHoldTests` and `CallSessionHoldTests`) and the Mac build (`just native-build-mac`); the phone still to do
- **Issues:** [#582](https://github.com/idvorkin/context-grabber/issues/582)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client who has not allowed Grabber's notifications
- **I want to** have the call hold anyway and say the notification could not be sent
- **so that** I know why nothing told me the call was waiting

#### Acceptance Criteria:
- **Scenario:** Notifications are off
- **Given:** notifications are not allowed for Grabber
- **When:** a call holds
- **Then:** the call still holds, and the screen says the notification could not be sent

---

### User Story 330:

- **Summary:** A held call whose mic starts on its own goes on
- **Status:** implemented in the review fix on #582's branch (after [3f45a4b](https://github.com/idvorkin/context-grabber/commit/3f45a4b) and [6dc765b](https://github.com/idvorkin/context-grabber/commit/6dc765b)); verified by `just native-test` (host: `CallSessionHoldTests` — a late buffer ends the hold, the ceiling no longer applies, coming forward keeps open playback); the phone still to do
- **Issues:** [#582](https://github.com/idvorkin/context-grabber/issues/582)
- **Spec:** [Native call — a microphone that never delivers](../superpowers/specs/2026-08-28-native-call-screen-design.md#a-microphone-that-never-delivers)

#### Use Case:
- **As a** Larry's client in a car whose Bluetooth settles slowly
- **I want to** have the call go on as soon as my mic delivers, even with the phone locked
- **so that** a working call is not ended five minutes later for a mic that did start

#### Acceptance Criteria:
- **Scenario:** Sound arrives while held
- **Given:** a call that held because the opened microphone sent nothing in time with the app not in front
- **When:** the microphone delivers sound
- **Then:** the hold ends: the call goes on, the notification is gone, and the five-minute ceiling no longer applies

---

### User Story 209:

- **Summary:** A call that ends *connection lost* leaves the evidence of which network went
- **Status:** implemented in [03563d6](https://github.com/idvorkin/context-grabber/commit/03563d6), interfaces in use apart from those available in [d6ba8c4](https://github.com/idvorkin/context-grabber/commit/d6ba8c4) (instrumentation only: the cause of the drops is not yet known); verified by `just test` (host: `CallNetworkTests`, `CallSessionConnectingTests.testALostSocketSaysHowLongSinceTheLastFrameInAndOut`) and the simulator build; a dropped call's log on the phone not yet
- **Issues:** [#440](https://github.com/idvorkin/context-grabber/issues/440), [#439](https://github.com/idvorkin/context-grabber/issues/439) (two calls from home lost their connection seconds in; the log could not say why)
- **Spec:** [Native call — interruptions](../superpowers/specs/2026-08-28-native-call-screen-design.md#interruptions)

#### Use Case:
- **As a** Larry's client whose call dropped
- **I want to** have the call's log say what the network did
- **so that** the drop can be fixed from evidence instead of a guess

#### Acceptance Criteria:
- **Scenario:** The connection drops mid-call
- **Given:** a live call
- **When:** the phone's network changes, or the connection to the bridge is lost
- **Then:** Diagnostics hold the network at the call's start and at every change (connected or not, which interfaces the call is using and which are available, metered, Low Data Mode), and the lost line names the error's code, the error underneath it, and the seconds since the last frame in and out; the screen still says *connection lost*

---

### User Story 210:

- **Summary:** Larry's reply plays clean when the bridge cuts his frames mid-sample
- **Status:** implemented in [8385814](https://github.com/idvorkin/context-grabber/commit/8385814); verified by `just test` (host: `PCM16StreamTests`); a Direct call on the phone not yet.
- **Issues:** [#442](https://github.com/idvorkin/context-grabber/issues/442), [#447](https://github.com/idvorkin/context-grabber/issues/447)
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics)

#### Use Case:
- **As a** Larry's client who heard noise and static on a call whose server-side recording was clean
- **I want to** the phone to read Larry's audio as the stream it is
- **so that** a frame cut mid-sample no longer plays as static

#### Acceptance Criteria:
- **Scenario:** Larry's reply arrives in frames cut mid-sample
- **Given:** a live call whose bridge sends Larry's audio in frames, some with an odd byte count
- **When:** the reply plays
- **Then:** the reply is heard clean: an odd frame's last byte joins the next frame

---

### User Story 211:

- **Summary:** A call that sounds wrong says why in Diagnostics
- **Status:** implemented in [8385814](https://github.com/idvorkin/context-grabber/commit/8385814); verified by `just test` (host: `PlaybackWindowTests`, the counters in `CallSessionCountersTests`); a Direct call on the phone not yet.
- **Issues:** [#442](https://github.com/idvorkin/context-grabber/issues/442); [#584](https://github.com/idvorkin/context-grabber/issues/584) the simulator smoke counted the simulator's expected no-archive-URL ending as a failed call
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics)

#### Use Case:
- **As a** Larry's client whose call sounded wrong
- **I want to** the call's log to say how Larry's frames arrived and played
- **so that** the next bad call carries its own evidence

#### Acceptance Criteria:
- **Scenario:** Larry speaks on a live call
- **Given:** a live call
- **When:** Larry's frames arrive
- **Then:** Diagnostics show a playback line every five seconds he spoke with frame count and sizes, odd and dropped frames, underruns and dry time, longest gap and queue depth; the level line names the player, session and hardware rates and the buffer; and the ending line carries the odd-frame and underrun totals

---

### User Story 212:

- **Summary:** A call's log reaches Larry without the phone
- **Status:** implemented in [8385814](https://github.com/idvorkin/context-grabber/commit/8385814); verified by `just test` (host: `CallLogArchiveTests`, the trouble rule in `CallEventLogTests`); its log in the Cockpit's archive after a call on the phone not yet.
- **Issues:** [#442](https://github.com/idvorkin/context-grabber/issues/442); [#584](https://github.com/idvorkin/context-grabber/issues/584) the simulator smoke counted the simulator's expected no-archive-URL ending as a failed call
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics)

#### Use Case:
- **As a** Larry's client whose call merely sounded wrong
- **I want to** the call's log sent to the Cockpit's archive when the call ends
- **so that** Larry can read the evidence on his box without the phone

#### Acceptance Criteria:
- **Scenario:** A call ends
- **Given:** a call that reached the bridge's ready
- **When:** the call ends
- **Then:** the call's log is in the Cockpit's archive under the call's bridge session, with a line in Diagnostics saying it was taken

---

### User Story 213:

- **Summary:** Larry's reply stays clean when the phone's own audio hiccups mid-reply
- **Status:** implemented in [c9ff20c](https://github.com/idvorkin/context-grabber/commit/c9ff20c), [3d81338](https://github.com/idvorkin/context-grabber/commit/3d81338) (a barge-in starts the stream anew even with no player); verified by `just test` (host: `PCM16StreamTests.testASkippedFrameKeepsTheStreamAligned`, `testTheCarryWaitsForTheNextFrameAndNotPastAReset`); a Direct call on the phone not yet.
- **Issues:** [#442](https://github.com/idvorkin/context-grabber/issues/442) (Codex on #443)
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics)

#### Use Case:
- **As a** Larry's client whose phone rebuilds its audio during a call
- **I want to** the samples after the hiccup to stay aligned
- **so that** a rebuild or a dropped frame never turns the rest of the reply into static

#### Acceptance Criteria:
- **Scenario:** The phone's own audio hiccups mid-reply
- **Given:** a reply whose frames are cut mid-sample
- **When:** the phone rebuilds its audio, or a frame arrives with nowhere to play
- **Then:** the samples after it are heard clean, never static: only Larry's next reply starts the stream anew

---

### User Story 214:

- **Summary:** A call that never heard ready still keeps its own log in the archive
- **Status:** implemented in [c9ff20c](https://github.com/idvorkin/context-grabber/commit/c9ff20c); verified by `just test` (host: `CallLogArchiveTests.testACallThatNeverHeardReadyTakesAFreshLocalKey`); on the phone not yet.
- **Issues:** [#442](https://github.com/idvorkin/context-grabber/issues/442) (Codex on #443)
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics)

#### Use Case:
- **As a** Larry's client whose call failed before the bridge was ready
- **I want to** that call's log archived under a key of its own
- **so that** the archive never drops it as another call's copy

#### Acceptance Criteria:
- **Scenario:** A call that never reached the bridge's ready
- **Given:** a call that never reached the bridge's ready
- **When:** the call ends
- **Then:** its log goes under a key no other call shares

---

### User Story 215:

- **Summary:** A line too long for an archive record does not cost the rest of the log
- **Status:** implemented in [c9ff20c](https://github.com/idvorkin/context-grabber/commit/c9ff20c), [054fbc8](https://github.com/idvorkin/context-grabber/commit/054fbc8) and [135439f](https://github.com/idvorkin/context-grabber/commit/135439f) (a long field in the header is cut too, Codex on #523); verified by `just test` (host: `CallLogArchiveTests.testALongLineIsCutUntilItsRecordFitsTheArchivesBytes`, `testALongProblemInTheHeaderIsCutUntilTheHeaderFits`); on the phone not yet.
- **Issues:** [#442](https://github.com/idvorkin/context-grabber/issues/442) (Codex on #443)
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics)

#### Use Case:
- **As a** Larry's client whose call carried a long caption or tool answer
- **I want to** that line cut to fit an archive record
- **so that** the archive keeps the rest of the call's log

#### Acceptance Criteria:
- **Scenario:** A line longer than an archive record holds
- **Given:** a call whose log has a line, or whose ending or problem in the header, longer than an archive record holds
- **When:** the call ends
- **Then:** the long text is cut to fit, and the rest of the log and the header's other fields are kept

---

### User Story 217:

- **Summary:** A Direct call starts knowing what my day has held so far
- **Status:** implemented in [4f9ec6c](https://github.com/idvorkin/context-grabber/commit/4f9ec6c); host-verified by `just native-test` (`CallTodayTests`); on the phone not yet. The Cockpit's voice bridge already reads `today` into Direct Larry's prompt (`direct_today_block` in `voice_bridge.py`, on the Cockpit's main).
- **Issues:** [#548](https://github.com/idvorkin/context-grabber/issues/548)
- **Spec:** [Native call — What the day has held](../superpowers/specs/2026-08-28-native-call-screen-design.md#what-the-day-has-held)

#### Use Case:
- **As** Igor calling Direct Larry, who starts fresh
- **I want to** the call to bring what the phone already knows about today: steps, last night's sleep, exercise, mindful minutes, workouts and the daily strip
- **so that** Larry knows it is a gym day or a short night without my telling him

#### Acceptance Criteria:
- **Scenario:** Calling Direct after a grab this morning
- **Given:** Today grabbed twelve minutes ago and the strip shows gym and three balloons
- **When:** I start a call on Direct
- **Then:** the bridge's start carries today's numbers, that the grab is twelve minutes old and the strip as the home screen shows it, a grab from an earlier day sends the strip only, the voice-model backends carry no day, and Diagnostics says *today: grab 12 min old* without the numbers

---

### User Story 218:

- **Summary:** A Direct call lets me pick its speech-to-text: Default, Nova-3 or Flux
- **Status:** implemented in [15d59d1](https://github.com/idvorkin/context-grabber/commit/15d59d1), fixed in [563c481](https://github.com/idvorkin/context-grabber/commit/563c481); host-verified by `just native-test` (`CallSTTTests`); in the simulator and on the phone not yet. The Cockpit's voice bridge already reads `stt` from a Direct call's start (`DIRECT_STT_CHOICES` in `voice_bridge.py`, Cockpit #80).
- **Issues:** [#556](https://github.com/idvorkin/context-grabber/issues/556)
- **Spec:** [Native call — Speech to text on Direct](../superpowers/specs/2026-08-28-native-call-screen-design.md#speech-to-text-on-direct)

#### Use Case:
- **As** Igor calling Direct Larry from the phone
- **I want to** choose Flux or Nova-3 for the speech-to-text
- **so that** I can compare the two on real calls and keep whichever ends my turns sooner without mangling words

#### Acceptance Criteria:
- **Scenario:** Picking Flux for a Direct call
- **Given:** Direct is chosen and the Speech to text row shows Default
- **When:** I pick Flux and start a call
- **Then:** the bridge is told Flux at the start, the status line ends *Direct · Flux*, the call's log names it, the pick survives a relaunch, Restart and the redial keep it, Default tells the bridge nothing so it decides, and the voice-model backends show no row and send nothing

---

### User Story 219:

- **Summary:** Cutting Tony off raises no "audio not arriving" banner
- **Status:** implemented in [ee1a185](https://github.com/idvorkin/context-grabber/commit/ee1a185) and [f4a6e62](https://github.com/idvorkin/context-grabber/commit/f4a6e62); host-verified by `just native-test` (`CallSessionTests`, `CallDiagnosticsTests`); on the phone not yet
- **Issues:** [#567](https://github.com/idvorkin/context-grabber/issues/567)
- **Spec:** [Native call — Audio that stops](../superpowers/specs/2026-08-28-native-call-screen-design.md#audio-that-stops--either-direction)

#### Use Case:
- **As a** Larry's client who talks over Tony
- **I want to** cut him off without the call crying wolf
- **so that** the *audio not arriving* banner, and a trouble report, mean the sound really stopped

#### Acceptance Criteria:
- **Scenario:** I cut in while Tony is answering
- **Given:** a call is live and Tony is answering
- **When:** I talk over him, and the bridge sends the words of the reply I cut off again as text, with no audio
- **Then:** no banner shows, the call does not count as trouble, and the log has a `call_bridge` cut_off_resend line

---

### User Story 331:

- **Summary:** Larry's loudest words play without a clipped edge
- **Status:** implemented in [b3c7cdd](https://github.com/idvorkin/context-grabber/commit/b3c7cdd); verified by `just test` (host: `PlaybackLimiterTests`) and the Mac build (rung 1.5); a Direct call on the phone not yet
- **Issues:** [#903](https://github.com/idvorkin/context-grabber/issues/903) playback rendered a mixer peak of 1.08 (2026-10-25)
- **Spec:** [Native call — Larry's voice never goes over full scale](../superpowers/specs/2026-08-28-native-call-screen-design.md#the-voice)

#### Use Case:
- **As a** Larry's client listening to his answer
- **I want to** his stressed words to sound as clean as the rest
- **so that** the voice I hear is the one he sent, not a harsh, flattened version of it

#### Acceptance Criteria:
- **Scenario:** A loud reply
- **Given:** a live call
- **When:** Larry's voice arrives at full scale
- **Then:** the loudest peaks are rounded smoothly to leave headroom, the level line's mixer peak stays under 1.0, and it counts the rounded samples

- **Scenario:** A quiet reply
- **Given:** a live call
- **When:** Larry's voice stays under about 70% of full scale
- **Then:** it plays exactly as sent, and the level line counts no rounded samples

---

### User Story 333:

- **Summary:** Hanging up lets the last frames reach the bridge
- **Status:** implemented in [4c736d2](https://github.com/idvorkin/context-grabber/commit/4c736d2) (the hang-up's close waits for the dump, `stt_stop` and `stop` to leave, at most two seconds); verified by `just test` (host: `SocketCloseDrainTests`), the Mac build and `SMOKE_ONLY=call just native-test-sim` (both calls logged `call_socket` close with drained: true after the hang-up, and the bridge received the dump and `stop`); the real socket on the phone not yet
- **Issues:** [#902](https://github.com/idvorkin/context-grabber/issues/902) the hang-up closed the socket before the stop frames left
- **Spec:** [Native call — Diagnostics](../superpowers/specs/2026-08-28-native-call-screen-design.md#diagnostics) (*The last frames leave before the line closes*)

#### Use Case:
- **As a** Larry's client ending a call
- **I want to** my hang-up to reach the bridge as a hang-up, with the call's dump and the end of what I said
- **so that** Larry hears a clean goodbye, not a dropped line, and the call's record is complete

#### Acceptance Criteria:
- **Scenario:** Hanging up lets the last frames reach the bridge
- **Given:** a live call
- **When:** I tap the red handset
- **Then:** the screen says the call ended at once, the bridge receives the dump, *stop listening* and *stop* before the line closes, and the log's close line says the frames left (or, if they had not after two seconds, that the line closed anyway)

---

### User Story 751:

- **Summary:** The call's problem line shows the worst thing still wrong, and the mic is restarted once
- **Status:** implemented in [56c468f](https://github.com/idvorkin/context-grabber/commit/56c468f); verified on the Linux rung (host tests: `CallSessionProblemLineTests`, the rest of `CallSession*Tests` green); simulator/phone pending, needs the Mac
- **Issues:** state-machine audit of 2026-11-10, finding 1
- **Spec:** [Native call — The problem line](../superpowers/specs/2026-08-28-native-call-screen-design.md#the-problem-line)

#### Use Case:
- **As a** Larry's client on a call that has more than one thing wrong
- **I want to** see the worst problem still standing, and the next one when it lifts
- **so that** an empty line means the call is fine, not that one fix wiped the others

#### Acceptance Criteria:
- **Scenario:** A bridge error outlives a second of silence
- **Given:** a live call where the bridge reported an error
- **When:** the mic delivers exact zeros past its one restart, then makes a sound
- **Then:** the line says *the microphone is delivering silence* while the zeros last, then the bridge's error again, not nothing

- **Scenario:** *Not reaching Larry* outlives an audio warning
- **Given:** the line says *the microphone is not reaching Larry*
- **When:** the phone's audio reports *the microphone stopped delivering*, then recovers
- **Then:** the line shows the audio warning while it stands, then *not reaching Larry* again until the bridge acknowledges the mic

- **Scenario:** One restart per call
- **Given:** a call whose first second is exact zeros, so the mic is restarted
- **When:** the bridge does not acknowledge the mic within five seconds
- **Then:** the mic is not restarted a second time; the bridge is asked about the rebuilt mic, and if it stays silent the line says *the microphone is not reaching Larry*

---

### User Story 1071:

- **Summary:** The call keeps the microphone when I breathe or start the timer during it
- **Status:** implemented in [7405d2fd](https://github.com/idvorkin/context-grabber/commit/7405d2fd); verified on the host rung (`AudioFloorTests.testTimerAndBreathingAreSilentDuringACall` and `testTheGateFollowsTheCall`, which failed against the old table) and the Mac build; the simulator rung not run (the Mac's screen was locked) and audio sessions exist only on the phone: the phone not yet. Spec: [native call screen](../superpowers/specs/2026-08-28-native-call-screen-design.md), Breathing and the Gym Timer during a call
- **Issues:** context-grabber-2r55 (a breathing session started during a call set the audio to playback, the route went to "no microphone · Speaker" and the call's mic re-armed against a 0 Hz input; #739's log)

#### Use Case:
- **As a** Larry's client on a call who wants to breathe or time a set while we talk
- **I want to** have the call keep its microphone and its audio whatever I open beside it
- **so that** Larry never loses me because I started a breathing session or a workout

#### Acceptance Criteria:
- **Scenario:** Breathing started by hand on a live call
- **Given:** a call with Larry is live and he can hear me
- **When:** I open Box breathing with Voice and Begin
- **Then:** the session runs on screen in silence with *Sounds are off during the call*, the devices line does not change, and Larry still hears me and I still hear him

---

### User Story 1072:

- **Summary:** A UI test's call never reaches Larry's real voice bridge
- **Status:** implemented in [40183c4c](https://github.com/idvorkin/context-grabber/commit/40183c4c), the hang-up in the Cockpit's ☎ check in [6bd23ac8](https://github.com/idvorkin/context-grabber/commit/6bd23ac8); which bridge a launch gets is `CallProtocolTests` (host); `CockpitBackUITests` on the iPad simulator (2026-11-22): the ☎'s drill call dialled `ws://192.0.2.1:8780`, was hung up while it rang and ended `stopped`, and no automatic report was filed; the Mac build green. Spec: [native Cockpit](../superpowers/specs/2026-10-05-native-cockpit-design.md)
- **Issues:** context-grabber-0mn (the ☎ check placed a real drill call on Igor's bridge on every run: no UI test named a bridge, so a call dialled the Cockpit's own; the app was ended a moment after the call started, and the bridge logged a drill session that ended at once)

#### Use Case:
- **As a** Larry's client whose drills, recordings and transcripts are Larry's picture of me
- **I want to** have the app's automated UI checks never place a call on my real voice bridge
- **so that** my drill and call records hold only the calls I made

#### Acceptance Criteria:
- **Scenario:** The Cockpit's ☎ in a UI test
- **Given:** a UI test launched the app the usual way for tests and named no bridge of its own
- **When:** it taps the stand-in Cockpit page's ☎, which asks for a drill call, and hangs the call up while it still rings
- **Then:** the call dialled an address that never answers, nothing reached Igor's voice bridge or his drill and call records, and the call ended cleanly with no automatic report

---

### User Story 1073:

- **Summary:** The Cockpit knows what a call was on: the device, the microphone and output, the audio and the network, and each change
- **Status:** implemented in [9bf83750](https://github.com/idvorkin/context-grabber/commit/9bf83750); host-verified by `just test` (`CallMetaTests`, `CallSessionMetaTests`); the Mac build (rung 1.5); the iPad simulator's call smoke (rung 2, 2026-11-24): the start frame went with the meta, its route logged as *no microphone · Speaker* on synthetic audio. A real call on the phone, with the Cockpit's /debug/call (cockpit-71g) reading it, not yet
- **Issues:** context-grabber-2k58 (Igor, 2026-11-24 06:13 via Larry: send call metadata whenever we have it; Cockpit cockpit-71g, /debug/call)
- **Spec:** [Native call — What the call says about itself](../superpowers/specs/2026-08-28-native-call-screen-design.md#what-the-call-says-about-itself)

#### Use Case:
- **As** Igor, who reads a bad call afterwards on the Cockpit's call debug page
- **I want to** have every call tell the Cockpit which device, microphone, output, audio settings and network it was on, and each time those changed
- **so that** "Larry couldn't hear me" can be traced to the AirPods dropping or Wi-Fi giving way without the phone in hand

#### Acceptance Criteria:
- **Scenario:** Putting AirPods in during a call on Wi-Fi
- **Given:** a call started on the iPhone's microphone and speaker, on Wi-Fi
- **When:** I put my AirPods in mid-call, then walk out of Wi-Fi range
- **Then:** the call's start told the bridge the device, *iPhone Microphone* and *Speaker*, the audio session and Wi-Fi; one route message followed naming *AirPods Pro* as microphone and output and why iOS changed it; one network message followed naming cellular; a route change that left the same devices sent nothing; and no permission was asked for

### User Story 1074:

- **Summary:** A crash after hanging up leaves, as the session log's last lines, which of the call's teardown steps was still in flight
- **Status:** implemented in [0f2859c8](https://github.com/idvorkin/context-grabber/commit/0f2859c8) (instrumentation); the call's network watch moved off the global queue onto its own serial one in [2e76c8bd](https://github.com/idvorkin/context-grabber/commit/2e76c8bd) as a guard, not a proven fix; host-verified by `just test` and the Mac build (rung 1.5). The iPhone, where the crash happened, gets it with its next build (the no-iPhone rule holds it for now)
- **Issues:** #1414, #1413 (iPhone, build 5271406b, 2026-11-24 14:52:36Z: SIGSEGV in objc_release from a block on a global queue, 1.4 s after a 23-minute call was hung up)
- **Spec:** [Native call — What the call says about itself](../superpowers/specs/2026-08-28-native-call-screen-design.md#what-the-call-says-about-itself)

#### Use Case:
- **As** the agent reading a crash that came moments after a call ended
- **I want to** see in the session log when the call's network watch was stopped and when the call's log left for the Cockpit's archive
- **so that** the next such crash names its cause from evidence instead of a guess

#### Acceptance Criteria:
- **Scenario:** Hanging up a call
- **Given:** a live call
- **When:** I hang up
- **Then:** the session log shows the network watch stopping and the call's log being sent to the archive before the line that says how that send went; a call that never started watching the network logs no stop
