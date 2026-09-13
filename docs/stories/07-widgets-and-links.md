# From the home screen: widgets, the card, and links

Getting to the thing without opening the app: the Today widget, the memdeck card on the home and lock screens, links that land where I mean, and the Shortcuts app.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 120:

- **Summary:** Today's numbers on the home screen without opening the app
- **Status:** implemented in [b789147](https://github.com/idvorkin/context-grabber/commit/b789147), [dd1a899](https://github.com/idvorkin/context-grabber/commit/dd1a899); verified on the phone (daily)

#### Use Case:
- **As someone** at the kitchen counter glancing at the phone
- **I want to** see today's steps, sleep and exercise minutes on a home-screen widget
- **so that** "am I on track" costs a glance, not a launch

#### Acceptance Criteria:
- **Scenario:** After a grab
- **Given:** the medium Today widget is on the home screen
- **When:** I press Grab Context in the app and return to the home screen
- **Then:** within two minutes the widget shows "Today · <weekday>" with steps, sleep hours and exercise minutes from that grab (an em-dash for anything never grabbed), and tapping the top block opens the app on the dashboard

---

### User Story 121:

- **Summary:** Start a timer from the home screen in one tap
- **Status:** implemented in [a5ff68d](https://github.com/idvorkin/context-grabber/commit/a5ff68d), [b789147](https://github.com/idvorkin/context-grabber/commit/b789147), [83e2bdc](https://github.com/idvorkin/context-grabber/commit/83e2bdc), [2ef4a17](https://github.com/idvorkin/context-grabber/commit/2ef4a17); verified by `deepLink.test.ts` and on the phone

#### Use Case:
- **As a** lifter with the bell already in hand
- **I want to** tap 1 MIN, 2 MIN or 5-1 on the widget
- **so that** the timer is counting down before I have opened, navigated or pressed START

#### Acceptance Criteria:
- **Scenario:** The 1 MIN tile
- **Given:** the Today widget is on the home screen and the app is closed
- **When:** I tap the 1 MIN tile
- **Then:** the app opens on the Gym Timer with the 1 MIN preset selected and the countdown running within about a second — the same when the app was already open on another tab

---

### User Story 122:

- **Summary:** Bump the day's tally from the widget without launching the app
- **Status:** implemented in [d00e45b](https://github.com/idvorkin/context-grabber/commit/d00e45b), [c6fc609](https://github.com/idvorkin/context-grabber/commit/c6fc609); verified by `counter.test.ts` and on the phone
- **Issues:** [#29](https://github.com/idvorkin/context-grabber/issues/29) — the counter half shipped; the quick 5-minute meditation preset asked for there is still open

#### Use Case:
- **As a** man doing a set of squats between meetings
- **I want to** tap +1 on the widget after each one
- **so that** "I did a thing" is one tap and today's count is on the Move tab when I look

#### Acceptance Criteria:
- **Scenario:** +1 in place
- **Given:** the Today widget shows the tally row with its count
- **When:** I tap +1 on the widget
- **Then:** the count on the widget rises by one without the app opening, the Move tab's tally marks show the same number, and at local midnight the count starts again from zero

---

### User Story 123:

- **Summary:** Reflect from the widget: affirm, be grateful, or open the journal
- **Status:** implemented in [d61f15a](https://github.com/idvorkin/context-grabber/commit/d61f15a), [2e4fd9f](https://github.com/idvorkin/context-grabber/commit/2e4fd9f); verified by `deepLink.test.ts` and on the phone

#### Use Case:
- **As a** man who just noticed something worth writing down
- **I want to** tap 🎯 Affirm or 🙏 Grateful on the widget and land straight on that card
- **so that** the noticing is not lost to the four taps it would take to get there

#### Acceptance Criteria:
- **Scenario:** Straight to the card
- **Given:** the widget's Reflect strip shows today's counts ("☀️2  ✓1  🙏4") and the three tiles
- **When:** I tap 🙏 Grateful
- **Then:** the app opens with the Grateful card already up, and after I save, the widget's gratitude count reads one more on its next refresh

---

### User Story 124:

- **Summary:** Call Larry from the widget's ☎ pill
- **Status:** implemented in [8d35bb6](https://github.com/idvorkin/context-grabber/commit/8d35bb6); verified on the phone

#### Use Case:
- **As a** man with a thought for Larry and the phone on the counter
- **I want to** tap the ☎ Call pill on the widget
- **so that** the call is connecting before the thought is gone

#### Acceptance Criteria:
- **Scenario:** One tap to a call
- **Given:** the Today widget is on the home screen
- **When:** I tap ☎ Call
- **Then:** the app opens on the Call tab already *connecting…* on the remembered backend, and if a call is already live it simply shows that call

---

### User Story 125:

- **Summary:** Tap the Live Activity and land on the timer
- **Status:** implemented in [a5ff68d](https://github.com/idvorkin/context-grabber/commit/a5ff68d); verified on the phone

#### Use Case:
- **As a** lifter watching the countdown in the Dynamic Island
- **I want to** tap it and be on the Gym Timer screen
- **so that** pause, reset and the phase are one tap away, not the dashboard

#### Acceptance Criteria:
- **Scenario:** From the island to the timer
- **Given:** a rounds timer is running and the Live Activity shows the countdown
- **When:** I tap the Live Activity
- **Then:** the app opens on the Gym Timer in rounds mode with the timer still running, not on the dashboard

---

### User Story 126:

- **Summary:** A link opens the app exactly where I meant, from anywhere
- **Status:** implemented in [a5ff68d](https://github.com/idvorkin/context-grabber/commit/a5ff68d), [b789147](https://github.com/idvorkin/context-grabber/commit/b789147), [cef19fc](https://github.com/idvorkin/context-grabber/commit/cef19fc), [a902080](https://github.com/idvorkin/context-grabber/commit/a902080), [c81b9b1](https://github.com/idvorkin/context-grabber/commit/c81b9b1); verified by `deepLink.test.ts` and on the phone

#### Use Case:
- **As a** man wiring the Action Button and a few Shortcuts
- **I want to** open `grabber://timer?preset=1min&autostart=1`, `grabber://grab`, `grabber://reflect/grateful`, `grabber://call?via=eleven`, `grabber://cockpit` or `grabber://card` and have each do the obvious thing
- **so that** every surface that can open a URL can drive the app, and a typo never crashes it

#### Acceptance Criteria:
- **Scenario:** Routes, cold and warm
- **Given:** the app is closed (and again with it open on the Today tab)
- **When:** I open `grabber://timer?preset=1min&autostart=1`
- **Then:** the timer starts within a second either way; `com.idvorkin.contextgrabber://` behaves identically; an unknown preset falls back to the last one; and a malformed link opens the dashboard with no error

---

### User Story 127:

- **Summary:** Always a playing card on the big widget, and a fresh one when I want it
- **Status:** implemented in [c81b9b1](https://github.com/idvorkin/context-grabber/commit/c81b9b1); verified by `just check-deal` (the deal's promises under plain `swiftc`) and on the phone

#### Use Case:
- **As a** memdeck student who keeps the large widget on two home-screen pages
- **I want to** see a random card beside today's numbers, changing every five minutes, and a different one the instant I tap it
- **so that** every glance is a prompt to find the card in the stack

#### Acceptance Criteria:
- **Scenario:** The card deals
- **Given:** the large Today widget is on both home-screen pages
- **When:** I tap the card on one of them
- **Then:** within a second it is a different card on both pages and the lock screen, the app does not open, it is never the same card twice in a row, and left alone for a quarter hour it has changed more than once on its own

---

### User Story 128:

- **Summary:** The same card on the lock screen, and a tap that takes me to it
- **Status:** implemented in [c81b9b1](https://github.com/idvorkin/context-grabber/commit/c81b9b1); verified on the phone

#### Use Case:
- **As someone** glancing at the locked phone
- **I want to** see "7♣ memdeck" under the clock, and land on a big card if I tap it
- **so that** the prompt is there before I unlock, and the practice is one tap further

#### Acceptance Criteria:
- **Scenario:** The lock-screen widget
- **Given:** the rectangular, round or inline memdeck widget is on the lock screen
- **When:** I tap it
- **Then:** it showed the same card as the big widget, was never blank, and the app opens on the Card tab with a big card that differs from the one the lock screen showed

---

### User Story 129:

- **Summary:** The Card tab: tap for another, or "think of a card" and wait five seconds
- **Status:** implemented in [c81b9b1](https://github.com/idvorkin/context-grabber/commit/c81b9b1); verified by `CardScreen.test.tsx` and on the phone

#### Use Case:
- **As a** man about to do the trick for someone
- **I want to** press *Think of a card*, see the card turn face down with a count from five, and get a new card face up when it hits zero
- **so that** the pause is me saying "think of a card" and shuffling, and the reveal is theirs

#### Acceptance Criteria:
- **Scenario:** Think of a card
- **Given:** the Card tab is open on a fresh card (every open deals one; a tap deals another)
- **When:** I press *Think of a card*
- **Then:** the card goes face down counting five, four, three…, a new card is face up at zero, pressing *Never mind* mid-count stops it with the previous card face up, and on leaving the tab or locking the phone the widgets show the last card the tab dealt

---

### User Story 130:

- **Summary:** "Call Larry" and "Open Cockpit" by name in the Shortcuts app and to Siri
- **Status:** implemented in [8d35bb6](https://github.com/idvorkin/context-grabber/commit/8d35bb6), [a902080](https://github.com/idvorkin/context-grabber/commit/a902080); verified on the phone
- **Issues:** [#75](https://github.com/idvorkin/context-grabber/issues/75), [#85](https://github.com/idvorkin/context-grabber/issues/85) (closed)

#### Use Case:
- **As a** man building an automation without wanting to remember a URL
- **I want to** pick *Call Larry* (with an optional backend) or *Open Cockpit* from Context Grabber's actions, or say "Call Larry in Context Grabber"
- **so that** the call and the dashboard are things I choose from a menu or speak, next to *Increment Counter*

#### Acceptance Criteria:
- **Scenario:** A shortcut of one action
- **Given:** the Shortcuts app lists *Call Larry* (Backend: Gemini, ElevenLabs, OpenAI, Drill, or blank) and *Open Cockpit* under Context Grabber
- **When:** I run a shortcut of just *Call Larry* with ElevenLabs while the app is closed
- **Then:** the app opens on the Call tab and goes *connecting… ElevenLabs* → *live* with no tap; run while a call is live it shows that call without restarting it; and *Open Cockpit* opens the Cockpit tab the same way

---

### User Story 131:

- **Summary:** Know which build is actually running on the phone
- **Status:** implemented in [bafc357](https://github.com/idvorkin/context-grabber/commit/bafc357), [8b28d51](https://github.com/idvorkin/context-grabber/commit/8b28d51), [0bb87bf](https://github.com/idvorkin/context-grabber/commit/0bb87bf); verified on the phone (every OTA)

#### Use Case:
- **As a** man who just got told "an update is live" in a session
- **I want to** open About and read the commit message, short sha, branch and update id that are running
- **so that** "did the OTA land" is answered without a Mac

#### Acceptance Criteria:
- **Scenario:** After an OTA
- **Given:** an update was published and the app has been opened twice since
- **When:** I open About
- **Then:** the Build Info shows the new commit's message and sha, the update channel, runtime version and update id, and *Check for update* reports what it did

---

### User Story 132:

- **Summary:** Today's path on a home-screen map widget
- **Status:** not implemented; asks: [#45](https://github.com/idvorkin/context-grabber/issues/45), [#42](https://github.com/idvorkin/context-grabber/issues/42) (which interpretation is still open)

#### Use Case:
- **As someone** wondering where the day went before opening anything
- **I want to** see today's GPS trail drawn on a small map on the home screen
- **so that** the day's shape is a glance, like the steps are

#### Acceptance Criteria:
- **Scenario:** The map widget
- **Given:** background tracking has recorded today's trail
- **When:** I look at the home screen
- **Then:** a map widget shows today's route over the map with the current position marked, refreshed with the last grab
