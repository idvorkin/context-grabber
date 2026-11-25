# From the home screen: widgets, the card, and links

Getting to the thing without opening the app: the Today widget, the memdeck card on the home and lock screens, links that land where I mean, and the Shortcuts app. On the iPad, a tile's screen in a window of its own.

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
- **Status:** implemented in [a5ff68d](https://github.com/idvorkin/context-grabber/commit/a5ff68d); verified on the phone; native app: [ea8c689](https://github.com/idvorkin/context-grabber/commit/ea8c689), by construction rather than a link — the card lives only while the timer's full screen is up (RESET and leaving end it, a killed launch's card is ended at the next launch), so opening the app is opening the timer; verified by reading the code only, the tap not yet on the phone; since #791 the card can outlive the timer's screen (a workout running while Igor is elsewhere in the app), so its tap carries the timer's link: [e5d4897](https://github.com/idvorkin/context-grabber/commit/e5d4897) (stories 732, 733)
- **Issues:** #791

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
- **Status:** implemented in [c81b9b1](https://github.com/idvorkin/context-grabber/commit/c81b9b1); verified by the check-deal recipe (the deal's promises under plain `swiftc`) and on the phone; that recipe went with the React Native app in [4f13fdde](https://github.com/idvorkin/context-grabber/commit/4f13fdde), and the deal's promises are verified now by `CardDealTests` on the host rung

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
- **Issues:** [#219](https://github.com/idvorkin/context-grabber/issues/219)
- **Status:** implemented in [c81b9b1](https://github.com/idvorkin/context-grabber/commit/c81b9b1); verified by `CardScreen.test.tsx` and on the phone; native app (#219, Igor 2026-10-08: *"let's do it inline"*): implemented in [fdec37f](https://github.com/idvorkin/context-grabber/commit/fdec37f); verified by `CardDealTests` (host: the deal's promises, and the same card as the old app for the same moment) and `CardUITests` on the simulator (the home row opens face down counting, a card face up at zero, a tap deals another, *Never mind* keeps the card); replaced the same day by the trainer's own screen, story 245

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

### User Story 133:

- **Summary:** Think of a card in Grabber Native opens Igor's trainer
- **Status:** replaced by story 129 in the app (#219, Igor 2026-10-08: *"I don't think it's worthy of its own app"*); was [0152b68](https://github.com/idvorkin/context-grabber/commit/0152b68)

#### Use Case:
- **As a** man about to do the trick, with Grabber Native open
- **I want to** tap *Think of a card* and be in Think a Card Trainer with the beat already started
- **so that** I practise with the trainer I built for it, not a second card app

#### Acceptance Criteria:
- **Scenario:** The row
- **Given:** Think a Card Trainer is installed on the phone
- **When:** I tap *Think of a card* on Grabber Native's home screen
- **Then:** the trainer comes to the front and starts "think of a card" as its watch complication's tap does, and if the trainer is not installed the home screen says so instead

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
- **Given:** the Shortcuts app lists *Call Larry* (Backend: Gemini, ElevenLabs, OpenAI, Drill, Direct Larry, or blank) and *Open Cockpit* under Context Grabber
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

---

### User Story 134:

- **Summary:** Open Exercise Analyzer from the native home screen
- **Status:** native app only: implemented in [225d739](https://github.com/idvorkin/context-grabber/commit/225d739); verified by `ExerciseAnalyzerLinkUITests` on the simulator with Exercise Analyzer's url-scheme build installed (tap the row, Exercise Analyzer runs in front); the phone still to be checked by Igor
- **Issues:** [#142](https://github.com/idvorkin/context-grabber/issues/142)
- **Spec:** [Swift-native app — Exercise Analyzer, one tap away](../superpowers/specs/2026-10-04-swift-native-app-design.md#exercise-analyzer-one-tap-away)

#### Use Case:
- **As a** lifter whose home screen is Grabber Native
- **I want to** open Exercise Analyzer from it
- **so that** recording a set is one tap from where I already am

#### Acceptance Criteria:
- **Scenario:** The row
- **Given:** Exercise Analyzer is installed
- **When:** I tap *Exercise Analyzer* on Grabber Native's home screen
- **Then:** Exercise Analyzer comes to the front, the session log has `open_exercise_analyzer` with ok true, and without it installed the home screen says it is not installed

---

### User Story 243:

- **Summary:** Workout Supermix from the native home screen
- **Status:** native app only: implemented in [fae3e8c](https://github.com/idvorkin/context-grabber/commit/fae3e8c); verified by `WorkoutSupermixUITests` on the simulator (tap the row, Shortcuts runs in front; the simulator has no such shortcut); YouTube Music playing the mix on the phone not yet; superseded by story 139 (#372): the tile opens the mix's link directly, not the shortcut
- **Issues:** [#220](https://github.com/idvorkin/context-grabber/issues/220)
- **Spec:** [Swift-native app — Workout Supermix, one tap away](../superpowers/specs/2026-10-04-swift-native-app-design.md#workout-supermix-one-tap-away)

#### Use Case:
- **As a** lifter about to start a workout from Grabber Native
- **I want to** tap one row and have my YouTube Music Workout Supermix playing
- **so that** the music starts without hunting through YouTube Music

#### Acceptance Criteria:
- **Scenario:** The row
- **Given:** my *Play Workout Supermix* shortcut is in the Shortcuts app
- **When:** I tap *Workout Supermix* on Grabber Native's home screen
- **Then:** Shortcuts runs the shortcut and YouTube Music plays the mix, the session log has `open_workout_supermix` with ok true, and without Shortcuts on the phone the home screen says so

---

### User Story 139:

- **Summary:** Workout Supermix opens straight in YouTube Music
- **Issues:** [#372](https://github.com/idvorkin/context-grabber/issues/372)
- **Status:** implemented in [fe5b5d4](https://github.com/idvorkin/context-grabber/commit/fe5b5d4) (the tile opens Igor's link as a universal link, the browser without YouTube Music, and the log says which); verified by `just test` (host) and a parse; `WorkoutSupermixUITests` (Safari in front on the simulator) and the build in the next build turn; YouTube Music opening on the phone still for Igor; a failure to open is a copyable problem under the tiles since [d507d3c](https://github.com/idvorkin/context-grabber/commit/d507d3c) (#383)
- **Spec:** [Swift-native app — Workout Supermix, one tap away](../superpowers/specs/2026-10-04-swift-native-app-design.md#workout-supermix-one-tap-away)

#### Use Case:
- **As a** lifter about to start a workout from Grabber Native
- **I want to** tap the Workout Supermix tile and land in my mix in YouTube Music
- **so that** the music starts without the Shortcuts app flashing in front first

#### Acceptance Criteria:
- **Scenario:** The tile
- **Given:** YouTube Music is installed
- **When:** I tap *Workout Supermix*
- **Then:** YouTube Music opens on my Workout Supermix with no Shortcuts hop, the browser opens it instead if YouTube Music is missing, and the log says which opened

---

### User Story 221:

- **Summary:** Press and hold the music tile to pick Workout, Liked music or Feel Good Supermix
- **Issues:** [#383](https://github.com/idvorkin/context-grabber/issues/383), [#391](https://github.com/idvorkin/context-grabber/issues/391)
- **Status:** native app only: the menu became the tile's popover of drawn icons in #391 (story 222; commit in that story's Status); icons on each mix [fa6be05](https://github.com/idvorkin/context-grabber/commit/fa6be05), verified by `WorkoutSupermixTests` (host), the hold menu's icons in `WorkoutSupermixUITests` (simulator, not yet run); implemented in [ee9d77c](https://github.com/idvorkin/context-grabber/commit/ee9d77c), a failure to open copyable since [d507d3c](https://github.com/idvorkin/context-grabber/commit/d507d3c); verified by `WorkoutSupermixTests` (host: the three mixes in order, each a YouTube Music universal link, Feel Good without feature=share); the simulator build in the next build turn; the press and hold, and Liked music opening his likes, on the phone still for Igor
- **Spec:** [Swift-native app — Workout Supermix, one tap away](../superpowers/specs/2026-10-04-swift-native-app-design.md#workout-supermix-one-tap-away)

#### Use Case:
- **As a** man about to train, or just wanting music, from Grabber Native
- **I want to** press and hold the music tile and tap the mix I want
- **so that** my likes or the Feel Good mix are as close as the workout one, without opening YouTube Music to look

#### Acceptance Criteria:
- **Scenario:** Picking a mix
- **Given:** YouTube Music is installed
- **When:** I press and hold the Workout Supermix tile, then tap *Liked music* or *Feel Good Supermix* in the popover
- **Then:** a popover of Workout Supermix (the kettlebell in headphones), Liked music (a heart) and Feel Good Supermix (a sun) opens beside the tile, each drawn, the one I tap opens in YouTube Music (the browser without it), a tap outside the popover opens nothing, a plain tap still opens the Workout Supermix, a mix that will not open shows a copyable problem under the tiles until the next try or a newer message, and the log names the mix and which opened

---

### User Story 226:

- **Summary:** Today's numbers on the usage tile, and daily strip under the usage left
- **Issues:** [#396](https://github.com/idvorkin/context-grabber/issues/396), [#404](https://github.com/idvorkin/context-grabber/issues/404), [#427](https://github.com/idvorkin/context-grabber/issues/427)
- **Status:** native app only: implemented in [dac9d82](https://github.com/idvorkin/context-grabber/commit/dac9d82), the entry at local midnight in [341e29e](https://github.com/idvorkin/context-grabber/commit/341e29e); verified by `TodayGlanceTests` (host: the card's order, the short forms, the dash, today only) and a simulator build of the app and widget; the drawn tile on the phone not yet; the daily strip in place of sleep (#404) in [f02df8c](https://github.com/idvorkin/context-grabber/commit/f02df8c), verified by `TodayGlanceTests` (host) and a simulator build of the app and widget; the drawn strip on the phone not yet; the strip coloured as home (#427) in [14c7e45](https://github.com/idvorkin/context-grabber/commit/14c7e45), verified by `TodayGlanceTests` (host); the drawn tile on a simulator and the phone not yet
- **Spec:** [native live tile, "Today's numbers"](../superpowers/specs/2026-10-06-native-live-tile-design.md)

#### Use Case:
- **As a** man glancing at his phone's home screen
- **I want to** see my Meditation and Journal marks, Balloons and Magic counts, steps, HRV and exercise on the usage tile
- **so that** the day's state is one glance away without opening the app

#### Acceptance Criteria:
- **Scenario:** The tile follows today's strip
- **Given:** the app has written today's strip and Health reading, and I change the strip with a tap, hold, week edit or peer sync
- **When:** I look at the usage tile on my home screen, then again after local midnight
- **Then:** both sizes show the app's Meditation and Journal done/not-done marks, Balloons and Magic counts, and steps, HRV and exercise with small symbols fitting the small tile, with no sleep; each part is absent before its first write and after midnight until written for the new day, and a strip change does not revive yesterday's Health numbers

- **Scenario:** The tile's strip is coloured as the home page's (#427)
- **Given:** today I have meditated and blown one balloon, but not journalled or done magic
- **When:** I look at the usage tile
- **Then:** the meditation symbol is green and the balloon pink, as on the home page, and the journal and magic symbols stay grey

---

### User Story 222:

- **Summary:** Holding the music tile opens a popover of drawn mixes, not a list
- **Issues:** [#391](https://github.com/idvorkin/context-grabber/issues/391)
- **Status:** native app only: implemented in [61fba62](https://github.com/idvorkin/context-grabber/commit/61fba62); verified by `HoldChoicesTests` (host: the three mixes in order, each with its art) and `WorkoutSupermixUITests.testTheHoldPopoverShowsEachMix` (simulator: the popover lists all three, Liked opens in the browser); the drawn art and the light tick on the phone not yet
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As a** man at the home screen with a tile in mind
- **I want to** press and hold the Workout Supermix tile and see the mixes as drawn tiles
- **so that** picking music looks like the home screen and reads at a glance

#### Acceptance Criteria:
- **Scenario:** The music popover
- **Given:** YouTube Music is installed
- **When:** I press and hold the Workout Supermix tile and tap the heart
- **Then:** a popover pointing at the tile shows Workout Supermix, Liked music and Feel Good Supermix as drawn tiles with their names, Workout first; my likes open in YouTube Music; a tap outside instead closes it with nothing opened; and the log has the popover opening and `from: home_popover` with the mix

---

### User Story 223:

- **Summary:** Hold the Gym Timer tile to start a preset
- **Issues:** [#391](https://github.com/idvorkin/context-grabber/issues/391)
- **Status:** native app only: implemented in [61fba62](https://github.com/idvorkin/context-grabber/commit/61fba62); verified by `HoldChoicesTests` (host: the four presets and Custom, each starting) and HoldPopoverUITests' timer test (simulator: 1 MIN opens the timer running); since [35457eed](https://github.com/idvorkin/context-grabber/commit/35457eed) that UI test is a host test, `HomeStackTests.testEveryHeldChoiceOpensItsScreenFromHome` (each preset brings the timer up at once, started), verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending; on the phone not yet
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As a** man at the home screen with a tile in mind
- **I want to** press and hold the Gym Timer tile and pick 30 SEC, 1 MIN, 2 MIN, 5-1 or Custom
- **so that** a workout starts from the home screen with the phone going straight down

#### Acceptance Criteria:
- **Scenario:** Straight into 2 MIN
- **Given:** the home screen
- **When:** I press and hold the Gym Timer tile and tap *2 MIN*
- **Then:** the timer opens on 2 MIN and its get-ready countdown starts, 2 MIN is its chosen preset afterwards, and a plain tap on the tile still opens it ready on the remembered preset

---

### User Story 224:

- **Summary:** Hold the Box breathing tile to begin at a breath length
- **Issues:** [#391](https://github.com/idvorkin/context-grabber/issues/391)
- **Status:** native app only: implemented in [61fba62](https://github.com/idvorkin/context-grabber/commit/61fba62); verified by `HoldChoicesTests` (host: 8, 10, 12 and 15 s, each beginning) and `HoldPopoverUITests.testATapOutsideOpensNothing` (simulator: the popover lists 10 s, a tap outside closes it on the home screen); remembered as breathing's choice afterwards since [2069559](https://github.com/idvorkin/context-grabber/commit/2069559) (simulator build); a length beginning a session on the phone not yet
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As a** man at the home screen with a tile in mind
- **I want to** press and hold Box breathing and pick 8, 10, 12 or 15 seconds a side
- **so that** a session starts at the length I want without touching the sliders

#### Acceptance Criteria:
- **Scenario:** Ten-second sides
- **Given:** my remembered session is 5 minutes
- **When:** I press and hold the Box breathing tile and tap *10 s*
- **Then:** breathing opens and begins at 10 seconds a side for 5 minutes

---

### User Story 225:

- **Summary:** Hold the card tile to think, see a card or drill
- **Issues:** [#391](https://github.com/idvorkin/context-grabber/issues/391), [#400](https://github.com/idvorkin/context-grabber/issues/400) (the drill's prompt is a button, so the UI test looks for one)
- **Status:** native app only: implemented in [61fba62](https://github.com/idvorkin/context-grabber/commit/61fba62); verified by `HoldChoicesTests` (host: think, face up, drill in order) and HoldPopoverUITests' card test (simulator: Drill the stack opens the drill; since [35457eed](https://github.com/idvorkin/context-grabber/commit/35457eed) a host test, `HomeStackTests.testEveryHeldChoiceOpensItsScreenFromHome`, the drill over the card, verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending), which looks for the prompt as a button since #400; a hand simulator run at [ea7e334](https://github.com/idvorkin/context-grabber/commit/ea7e334) passed 4 tests with 0 failures, but its record does not name them, so whether it re-ran this test is unconfirmed; on the phone not yet
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As a** man at the home screen with a tile in mind
- **I want to** press and hold Think of a card and pick think of a card, a card face up, or drill the stack
- **so that** the card practice I want is one gesture away

#### Acceptance Criteria:
- **Scenario:** Into the drill
- **Given:** the home screen
- **When:** I press and hold the Think of a card tile and tap *Drill the stack*
- **Then:** the stack drill opens, and a plain tap on the tile still counts down to a card as before

---

### User Story 244:

- **Summary:** Today's hand: a card, the role of the day, and three quick starts on the big widget
- **Status:** native app only: implemented in [2a1e6e8](https://github.com/idvorkin/context-grabber/commit/2a1e6e8); verified by `CardDealTests`, `EulogyRolesTests` and `AppLinkTests` (host) and `TodaysHandUITests` on the simulator (added through SpringBoard's gallery: the card and *Today, be Father to Zach* drew, a tap turned 10♥ into Q♥ with the app in the background, *Think of a card* opened the card screen counting); the phone not yet. From the stack, in the trainer's face (#219): [cecb31f](https://github.com/idvorkin/context-grabber/commit/cecb31f); verified by `CardDealSubsetTests` (host: the deal's promises over a smaller deck) and `TodaysHandUITests` on the simulator against the pinned trainer commit (the trainer's 2♠ dealt in place); against the tag its tap check failed once (#230, open); the Supermix button opens the mix in YouTube Music since #372 ([dfc0d06](https://github.com/idvorkin/context-grabber/commit/dfc0d06)), not the shortcut
- **Issues:** [#221](https://github.com/idvorkin/context-grabber/issues/221), [#230](https://github.com/idvorkin/context-grabber/issues/230)
- **Spec:** [Today's hand](../superpowers/specs/2026-10-08-native-large-widget-design.md)

#### Use Case:
- **As a** memdeck student who wants the eulogy in sight
- **I want to** see a card I can deal again, one of my eulogy's roles for the day, and the card trick, my workout music and Larry one tap away on the big widget
- **so that** every glance at the home screen is a prompt, a reminder of who I mean to be, and a start

#### Acceptance Criteria:
- **Scenario:** The widget
- **Given:** *Today's hand* is on the home screen
- **When:** I tap the card, and later *Think of a card*, *Supermix* and *Call Larry*
- **Then:** the card, from my stack and drawn as the trainer draws it, changes within a second without the app opening, it changes by itself every five minutes, with *Skip easy cards* on no breather or card within two of one shows, *Today, be* names a role from the eulogy that changes after midnight (each once in eleven days), *Think of a card* opens the card screen asking, *Supermix* opens my mix in YouTube Music (#372), and *Call Larry* opens the call screen calling

---

### User Story 250:

- **Summary:** Today's hand: a tap after a skipped redraw still deals a card that is not on screen
- **Status:** native app only: implemented in [45c8e32](https://github.com/idvorkin/context-grabber/commit/45c8e32); verified by `CardDealTests` (host: a tap avoids both the card showing and the last tap's card; 1,639 asserts fail without the change) and `TodaysHandUITests` on the simulator (iPhone 17, two iterations, both passed: a tap changed the card with the app in the background); the skipped-redraw case itself cannot be forced on the simulator; the phone not yet; the tapped card's own count carried by its button instead of recorded at timeline build (Codex on #334): [acf722d](https://github.com/idvorkin/context-grabber/commit/acf722d), host-checked only (lint); the widget build and `TodaysHandUITests` in the next build turn; the drawn entry's slot carried too, so a tap after a five-minute boundary avoids the card still on screen (Codex on #334): [a3aef08](https://github.com/idvorkin/context-grabber/commit/a3aef08), verified by `CardDealTests` (host; 1,638 asserts fail without it); the button carries the card itself, so a changed *Skip easy cards* can't hide it either (Codex on #334): [f01506f](https://github.com/idvorkin/context-grabber/commit/f01506f), `CardDealTests` (host); the widget on the phone in the next build turn
- **Issues:** [#230](https://github.com/idvorkin/context-grabber/issues/230)
- **Spec:** [Today's hand](../superpowers/specs/2026-10-08-native-large-widget-design.md)

#### Use Case:
- **As a** memdeck student tapping the big widget for another card
- **I want to** get a different card every tap, even when iOS was slow to redraw after the last one
- **so that** a tap never looks like it did nothing

#### Acceptance Criteria:
- **Scenario:** A tap after iOS skipped the widget's redraw
- **Given:** *Today's hand* still shows a card from before my last tap, because iOS did not redraw it
- **When:** I tap the card again
- **Then:** the widget deals a card that is not the one on screen, and the app does not open

---

### User Story 245:

- **Summary:** Think of a card in Grabber Native is the trainer's own screen
- **Status:** native app only: implemented in [cecb31f](https://github.com/idvorkin/context-grabber/commit/cecb31f), with think-a-card-trainer v0.1.0 (its PR #6, D15); verified by a simulator build and the screen read by eye (black, the card large, *Skip easy cards*); `CardUITests` runs again on the simulator (#229: the trainer speaks the card in lower case, and the count is told from a two's or three's rank by its size): the row opens the screen counting, the ask deals a new card, a tap switches it, Done goes home; the ask, the voice and silence during a call not yet checked on the phone; on ThinkACardUI 0.2.0 (no visible change): [6c71dc0](https://github.com/idvorkin/context-grabber/commit/6c71dc0); verified by the simulator build (think-a-card-trainer 0.2.0 resolved) and `CardUITests` testTheTrainersScreenAsksThenDeals on iPhone 17; the phone and iPad after the merge
- **Issues:** [#219](https://github.com/idvorkin/context-grabber/issues/219), [#229](https://github.com/idvorkin/context-grabber/issues/229), [#694](https://github.com/idvorkin/context-grabber/issues/694) (the UI test timed out on a loaded Mac with the card already dealt)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

#### Use Case:
- **As a** man practising his stack, with Grabber Native as his home screen
- **I want to** tap *Think of a card* and get Think a Card Trainer's screen, the same one, not a copy
- **so that** the prompt I practise with is the one I built, and it improves in both apps at once

#### Acceptance Criteria:
- **Scenario:** The ask from the home screen
- **Given:** the build has my stack
- **When:** I tap *Think of a card* on the home screen
- **Then:** the trainer's screen opens with the ask started (a card up, a small three-two-one at the side, then a new card, a tap of the phone, the card said aloud), a tap on the middle switches the card, the right third asks again, the left third asks from the hard cards, and *Done* goes home

- **Scenario:** During a call
- **Given:** a call with Larry is live
- **When:** I ask for a card
- **Then:** the new card shows and nothing is said, and the call's audio is untouched

---

### User Story 220:

- **Summary:** Drill the stack from the card screen, graded, and it reaches my practice ledger
- **Status:** native app only: implemented in [07433d7](https://github.com/idvorkin/context-grabber/commit/07433d7) (the `GRABBER_DRILL` hook in [244fa20](https://github.com/idvorkin/context-grabber/commit/244fa20); a shake reports from inside the drill since [5f7df26](https://github.com/idvorkin/context-grabber/commit/5f7df26), naming the drill as its screen since [631daff](https://github.com/idvorkin/context-grabber/commit/631daff), when the hook opens it too since [240a405](https://github.com/idvorkin/context-grabber/commit/240a405)), on think-a-card-trainer v0.3.0 (the drill, its grading, Mixed, the ledger and Stats are the library's, verified by its host tests); verified by host `just native-test`; the simulator build, `CardUITests` testDrillTheStackOpensTheTrainersDrill and the `GRABBER_DRILL=mixed` smoke check not yet; grading and the ledger on the phone not yet; on think-a-card-trainer v0.3.5 in [8876808](https://github.com/idvorkin/context-grabber/commit/8876808): the drill's *Wrong* is a large target at the right edge (think-a-card-trainer issue 33) and *Mixed* no longer runs too many numbers in a row (think-a-card-trainer issue 34), both the library's and verified by its tests; host `just native-test`; the app build and the drill on the phone not yet; on think-a-card-trainer v0.3.6 in [8d5ae94](https://github.com/idvorkin/context-grabber/commit/8d5ae94) (#569, #570): the answer centred under the question and *Wrong* a small half-clear button in its own row at the bottom right, replacing the large strip above; verified by the library's tests and a simulator build here; the drill on the phone not yet; a failed Stats load is a copyable error (story 227) in [f0f149e](https://github.com/idvorkin/context-grabber/commit/f0f149e) (#563): simulator build only, the failure itself not yet seen on a simulator or the phone; `CardUITests` testDrillTheStackOpensTheTrainersDrill passes on the simulator with its fix in [29f4561](https://github.com/idvorkin/context-grabber/commit/29f4561) (#400: it taps the drill's own Done and finds the prompt as a button; no app change); a hand simulator run at [ea7e334](https://github.com/idvorkin/context-grabber/commit/ea7e334) passed 4 tests with 0 failures, but its record does not name them, so whether it ran the later closing check that the drill has gone is unconfirmed; *Stats* covers the picked stretch instead of a fixed 30 days (story 239) on think-a-card-trainer v0.3.10 in [20e762c5](https://github.com/idvorkin/context-grabber/commit/20e762c5): host `just native-test` and the Mac build; *Stats* on the phone not yet
- **Issues:** [#400](https://github.com/idvorkin/context-grabber/issues/400) (the UI test tapped the wrong Done), [#569](https://github.com/idvorkin/context-grabber/issues/569), [#570](https://github.com/idvorkin/context-grabber/issues/570) (the answer centred, Wrong smaller and half-clear at the bottom: ThinkACardUI 0.3.6, think-a-card-trainer#38), [#563](https://github.com/idvorkin/context-grabber/issues/563) (a failed Stats load is a copyable error, story 227: the library lets the host present it since think-a-card-trainer#22, v0.3.1), [think-a-card-trainer#33](https://github.com/idvorkin/think-a-card-trainer/issues/33) (the Wrong button), [think-a-card-trainer#34](https://github.com/idvorkin/think-a-card-trainer/issues/34) (Mixed)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

#### Use Case:
- **As a** man practising his stack, with Grabber Native as his home screen
- **I want to** open the trainer's drill from the card screen, grade each answer with a tap or *Wrong*, and see which positions I miss
- **so that** the practice I do in this app counts in the same ledger as the trainer's and Card Picker's

#### Acceptance Criteria:
- **Scenario:** A graded drill that lands in the ledger
- **Given:** the build has my stack, and the ledger's URL and write key are pasted in the drill's *Stats*
- **When:** I tap *Drill the stack* under the card, pick *Mixed*, tap to see an answer, tap again for one I knew and press *Wrong* for one I missed, then open *Stats*
- **Then:** the drill asks both ways round from my stack (only the hard positions with *Skip easy cards* on), a tap shows the answer as the position alone, centred under the question, and *Wrong* is a small half-clear button at the bottom right, each answer is sent to the ledger (kept and sent later when offline), *Stats* shows the picked stretch (story 239) from every source as a difficulty grid, one cell per position in stack order with its card face, with a *Taps / Voice* picker, the log never pairs a card with its position or shows the key, and *Done* returns to the card


---

### User Story 229:

- **Summary:** The stack drill never asks two lookalike cards back to back
- **Status:** native app only: on think-a-card-trainer v0.3.8 (the rule is the library's, think-a-card-trainer#46, merged there as 7b86605 and verified by its host `think-a-card-trainer:LookalikeTests`: over seeded passes only a pass's last card may follow its lookalike, every card still once per pass, no card twice running over 3,000 pass boundaries); the pin bump here in [581f6e6](https://github.com/idvorkin/context-grabber/commit/581f6e6); verified by host `just test`, the Mac build (resolves ThinkACard 0.3.8) and the simulator smoke's drill check (`GRABBER_DRILL=mixed` opens the drill over the card, 52 positions); `CardUITests` testDrillTheStackOpensTheTrainersDrill not yet (the Mac was locked); the order itself is the library's tests' to see, and the drill on the phone not yet
- **Issues:** [#778](https://github.com/idvorkin/context-grabber/issues/778) (Igor's shake from the drill, 2026-11-07), [think-a-card-trainer#46](https://github.com/idvorkin/think-a-card-trainer/issues/46)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

Igor, 2026-11-07: *"Never do certain things back to back like Sequence of King and Queen in the same suit and color
But the same thing on black and red is often good"*; 2026-11-10: *"heart and club of jack is good. Since they are far
apart."*

#### Use Case:
- **As a** man drilling his stack
- **I want to** never be asked a card right after one that looks almost the same
- **so that** each answer is a fresh recall, not a nudge from the card before

#### Acceptance Criteria:
- **Scenario:** Lookalikes are kept apart, red and black of one rank are not
- **Given:** the drill is open from the card screen, in any mode
- **When:** I answer card after card through several passes
- **Then:** two cards of the same suit and neighbouring ranks (K♠ then Q♠, 2♥ then 3♥; an ace and a king do not neighbour) never come one right after the
  other, except that a pass's last card is still asked when nothing else is left; the same rank in a red and a black
  suit (J♥ then J♣) may come back to back; every card still comes once per pass and never twice running; the card
  screen's own deal is unchanged

---

### User Story 230:

- **Summary:** Drill the positions I miss first
- **Status:** native app only: comes with think-a-card-trainer v0.3.8 (the *Order* choice is the library's, trainer #32 and its story 073, shipped there in v0.3.7 and verified by its host tests), pinned here in [581f6e6](https://github.com/idvorkin/context-grabber/commit/581f6e6); not yet verified in this app (neither on the simulator nor on the phone)
- **Issues:** [think-a-card-trainer#32](https://github.com/idvorkin/think-a-card-trainer/issues/32)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

#### Use Case:
- **As a** man drilling his stack
- **I want to** have the drill ask first the positions I have been missing
- **so that** my practice goes where I am weakest, not spread evenly over cards I already know

#### Acceptance Criteria:
- **Scenario:** Misses first
- **Given:** the drill is open from the card screen and the practice ledger has seen some positions missed
- **When:** I set *Order* to *Misses first* and answer through a pass
- **Then:** the pass asks the missed positions first, worst first, then the never-graded ones, then the rest; *Shuffled*
  stays the default

---

### User Story 231:

- **Summary:** Misses first falls back to shuffled when the ledger cannot be read, and says so
- **Status:** native app only: comes with think-a-card-trainer v0.3.8 (the *Order* choice is the library's, trainer #32 and its story 073, shipped there in v0.3.7 and verified by its host tests), pinned here in [581f6e6](https://github.com/idvorkin/context-grabber/commit/581f6e6); not yet verified in this app (neither on the simulator nor on the phone)
- **Issues:** [think-a-card-trainer#32](https://github.com/idvorkin/think-a-card-trainer/issues/32)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

#### Use Case:
- **As a** man drilling his stack
- **I want to** still be drilled when the ledger cannot tell which positions I miss, and be told so
- **so that** a ledger outage never blocks practice or passes off a shuffled order as my misses

#### Acceptance Criteria:
- **Scenario:** The ledger cannot be read
- **Given:** the drill is open and the practice ledger cannot be reached
- **When:** I set *Order* to *Misses first*
- **Then:** the drill stays shuffled and says so

---

### User Story 239:

- **Summary:** The drill's Stats cover today, the last 7 days or the last 30, my pick
- **Status:** native app only: comes with think-a-card-trainer v0.3.10 (the picker is the library's, trainer story 075, PR #51, verified there by its host tests and its signed device build), pinned here in [20e762c5](https://github.com/idvorkin/context-grabber/commit/20e762c5); verified by host `just native-test` and the Mac build (resolves ThinkACard 0.3.10); *Stats* on the phone not yet (it has no simulator hook)
- **Issues:** [think-a-card-trainer#35](https://github.com/idvorkin/think-a-card-trainer/issues/35) (Igor: *"Add last 1 3 and 7 days. See change over time"*), [think-a-card-trainer#43](https://github.com/idvorkin/think-a-card-trainer/issues/43) (the ledger's ranges)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

#### Use Case:
- **As a** man drilling his stack
- **I want to** switch the drill's *Stats* between today, the last 7 days and the last 30
- **so that** I can see how I am doing now and how it changes, not only over the month

#### Acceptance Criteria:
- **Scenario:** Pick a stretch
- **Given:** the drill's *Stats* can read the practice ledger
- **When:** I pick *Day*, *Week* or *30 days* at its top
- **Then:** the attempts and the whole difficulty grid reload for that stretch alone, in whole Pacific days ending
  today, and the heading says *Today*, *Last 7 days* or *Last 30 days* as the ledger names it; *Stats* opens on
  *Week* the first time and on my last pick after, across relaunches, and the trainer app keeps its own pick

---

### User Story 568:

- **Summary:** The drill's Stats show the last 30 days as a calendar heat map
- **Status:** native app only: comes with think-a-card-trainer v0.3.10 (the calendar is the library's, trainer story 076, PR #51, verified there by its host tests: sources summed per Pacific day, empty days blank, the clock change, the colour steps), pinned here in [20e762c5](https://github.com/idvorkin/context-grabber/commit/20e762c5); verified by host `just native-test` and the Mac build (resolves ThinkACard 0.3.10); *Stats* on the phone not yet
- **Issues:** [think-a-card-trainer#35](https://github.com/idvorkin/think-a-card-trainer/issues/35)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

Igor, 2026-11-23: *"a calendar view with a heat map of the days of the month: the last trailing 30 days by day, and
a color heat map by how many practiced. Maybe I can flip to right and wrong."*

#### Use Case:
- **As a** man drilling his stack
- **I want to** see the last 30 days as a calendar coloured by how much I practised, and flip it to right or wrong
- **so that** I can see which days I drilled and how they went at a glance

#### Acceptance Criteria:
- **Scenario:** The calendar
- **Given:** the drill's *Stats* can read the practice ledger
- **When:** I open *Stats*, whatever stretch is picked (story 239)
- **Then:** under the grid the 30 Pacific days ending today sit in week rows, each day coloured in one of four steps
  of the busiest day's answers from every source; a day without answers is blank; tapping a day says its answers,
  right and wrong; a *Practiced / Right / Wrong* switch above the calendar colours the days by all answers, the
  right ones or the misses, each on its own scale

---

### User Story 238:

- **Summary:** The drill's Stats pairs with Larry's box, from a pasted link or a code
- **Status:** native app only: implemented in [9535b2f0](https://github.com/idvorkin/context-grabber/commit/9535b2f0) on think-a-card-trainer v0.3.9 (the field, the code parsing and the copyable failure are the library's, verified by its host tests); verified by host `just native-test`, the Mac build, and the iPad Pro 11-inch (M5) simulator smoke (the drill hook opened the drill; its two failures, the whiteboard's Larry turn offline and the call skipped with the lid closed, are not this change); the shared Keychain group is proven only by the signed phone build, and the first real pairing is Igor's
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

Igor, 2026-11-23: the drill's *Stats* asked for pairing and there was nowhere to put a code; the ledger now checks
keys against the keyring on Larry's box. The trainer's v0.3.9 has the field (its story 074); this app supplies the
redeem and reads the phone's shared pairing.

#### Use Case:
- **As a** man practising his stack in Grabber Native
- **I want to** paste Larry's pairing link, or type its code, into the drill's *Stats*
- **so that** my answers reach the ledger with the phone's own key, shared with Think a Card, and I never paste a
  URL or key

#### Acceptance Criteria:
- **Scenario:** Pair with code
- **Given:** the phone is unpaired, its key expired or the ledger refused it, and Larry sent a fresh pairing link
- **When:** I paste the link (or its 26-character code) into *Pair with code* in the drill's *Stats* and press *Pair*
- **Then:** the phone redeems it with the keyring on Larry's box; *Stats* says *Paired as … until* the day and
  loads the stats; the answers that waited go with the new key; Think a Card reads the same pairing; a failure
  shows in place as a copyable error without the code; the 4-letter Cockpit approval code is turned away with a
  message; the session log says paired or failed, never the code or the key

---

### User Story 571:

- **Summary:** The drill's Stats says where a pair link comes from
- **Status:** native app only: implemented in [4e31ea21](https://github.com/idvorkin/context-grabber/commit/4e31ea21), verified by host tests (`DrillPairingHintTests`), the Mac build and the iPad Pro 11-inch (M5) simulator (`CardUITests` and the smoke); the words on an unpaired phone not yet seen
- **Issues:** [#1356](https://github.com/idvorkin/context-grabber/issues/1356)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

Igor, 2026-11-23 (#1356): "I need a pair code. I don't know how to get one." Nothing beside the field said where a
code comes from: Larry makes one on the box and sends it as a link.

#### Use Case:
- **As a** man practising his stack in Grabber Native whose phone needs pairing
- **I want to** be told, beside *Pair with code*, how to get a pair link
- **so that** I can pair (story 238) without guessing where a code comes from

#### Acceptance Criteria:
- **Scenario:** Where a code comes from
- **Given:** the phone is unpaired, its key expired or the ledger refused it
- **When:** I open the drill's *Stats*
- **Then:** beside *Pair with code* it says to ask Larry in chat for a pair link, and that the link lasts 10 minutes

---

### User Story 227:

- **Summary:** A Stats load that fails in the drill is a copyable error
- **Status:** native app only: implemented in [f0f149e](https://github.com/idvorkin/context-grabber/commit/f0f149e) (#563), on the drill of story 220; verified by a simulator build only, the failure itself not yet seen on a simulator or the phone; a refused key (401, 403) says to ask Larry in chat for a pair link in [3231680d](https://github.com/idvorkin/context-grabber/commit/3231680d) (#1371), verified by host tests (`DrillPairingHintTests`), the Mac build, and the iPad Pro 11-inch (M5) simulator (`CardUITests`; the refusal itself not yet seen on a device)
- **Issues:** [#563](https://github.com/idvorkin/context-grabber/issues/563), [#1371](https://github.com/idvorkin/context-grabber/issues/1371)
- **Spec:** [Swift-native app — Think of a card: the trainer's screen, in the app](../superpowers/specs/2026-10-04-swift-native-app-design.md#think-of-a-card-the-trainers-screen-in-the-app)

On 2026-11-23 the iPhone's Stats said only *Could not load the stats: the ledger answered 401*: the phone's key had
lapsed, and nothing said so or what to do (#1371).

#### Use Case:
- **As a** man practising his stack, who reports what goes wrong by pasting it
- **I want to** copy a failed Stats load with the state behind it
- **so that** the report says what the drill asked for and held, not just that it failed

#### Acceptance Criteria:
- **Scenario:** A Stats load that fails
- **Given:** the ledger can't be reached or refuses the key
- **When:** I open *Stats* in the drill
- **Then:** the sheet shows the failure as a copyable error carrying the days asked for and the answers waiting, never the key

- **Scenario:** The ledger refuses the phone's key
- **Given:** the phone's pairing has lapsed or the ledger refuses its key
- **When:** I open *Stats* and the ledger answers 401 or 403
- **Then:** the copyable error says the pairing has lapsed or was refused and to ask Larry in chat for a pair link to
  paste into *Pair with code*; any other failure reads as before

---

### User Story 135:

- **Summary:** A link and a Shortcuts action for every screen of Grabber Native
- **Status:** implemented in [5c1f4ad](https://github.com/idvorkin/context-grabber/commit/5c1f4ad), *Open Grabber Native* in [68229b3](https://github.com/idvorkin/context-grabber/commit/68229b3) (simulator build; Shortcuts on the phone not yet); verified by `AppLinkTests` (host) and `LinksUITests` on the simulator (real links through iOS, cold and warm: `timer?preset=10,10,2` counting down, `breathe?breath=5&minutes=2` begun over the running timer, `nowhere` on home, `timer?preset=9min` ready; Copy on the Links screen; since [35457eed](https://github.com/idvorkin/context-grabber/commit/35457eed) the warm half is `HomeStackTests`, with the screen stack one reducer: a second link inside the wait replaces the first (#818), a link home leaves home in front and named, verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending), with `just native-test-sim` passing; the Shortcuts actions, Siri and the Action Button on the phone not yet; a link's screen coming up once what it closed has gone, the 0.7 s now only the most it waits, in [336b13c4](https://github.com/idvorkin/context-grabber/commit/336b13c4) (bead context-grabber-mzdf), verified on the host by `HomeStackTests` (every closed screen gone, a view leaving while its screen stays, a second link inside the wait) and on the simulator (rung 2, iPhone 17 and iPad Pro 11-inch (M5), 2026-11-22) by `LinksUITests.testWarmLinksOverEachKindOfScreenBringTheirScreenUp`, warm links through the system over the timer, breathing, the card and Today, each `links` settled via gone (10–32 ms on the iPhone, ~520 ms on the iPad); the phone not yet
- **Issues:** [#167](https://github.com/idvorkin/context-grabber/issues/167), [#808](https://github.com/idvorkin/context-grabber/issues/808) (which screen is up as one tested model; no visible change), [#818](https://github.com/idvorkin/context-grabber/issues/818) (two links inside the wait each presented), bead context-grabber-mzdf (the wait is for what closed to go, not a fixed 0.7 s)

#### Use Case:
- **As a** man wiring the Action Button and a few Shortcuts to the native app
- **I want to** pick *Start Gym Timer* (1 MIN) or *Start Box Breathing* (5 minutes) from Grabber Native's actions, or paste `grabbernative://timer?preset=1min` copied from the app's Links screen
- **so that** the workout or the breathing is running before I have opened, navigated or pressed anything, and every screen is one tap from wherever I put it

#### Acceptance Criteria:
- **Scenario:** Links, cold and warm
- **Given:** Grabber Native is closed (and again with it open on another screen)
- **When:** I open `grabbernative://timer?preset=10,10,2`, `grabbernative://breathe?breath=5&minutes=2`, `grabbernative://today`, `grabbernative://places`, `grabbernative://cockpit`, `grabbernative://call` or `grabbernative://card`
- **Then:** each lands on its screen, the timer counting down and the breathing begun within about a second; `grabbernative://nowhere` opens the home screen, a preset it does not know opens the timer ready, and none of them shows an error

- **Scenario:** Two links close together, and a link home
- **Given:** the timer is up, or Chat is open
- **When:** two links arrive a tenth of a second apart (`places`, then `cockpit`), or `grabbernative://home` arrives from Chat, and then I shake to report
- **Then:** only the Cockpit comes up, once, and Places never shows; from Chat the home screen is in front, and the report names *home*

- **Scenario:** A link over another screen comes up as soon as that screen has gone
- **Given:** the timer, or Chat, is on screen
- **When:** a link to another screen arrives
- **Then:** the timer or Chat goes, and the link's screen comes up as soon as it has finished going, not after a fixed pause; if a closing screen never says it has gone, the link's screen still comes up within about 0.7 s

- **Scenario:** Shortcuts and the Links screen
- **Given:** the Shortcuts app lists *Open Grabber Native*, *Open Today*, *Start Gym Timer*, *Start Box Breathing*, *Open Places*, *Open Cockpit* and *Call Larry* under Grabber Native
- **When:** I run *Start Gym Timer* with 1 MIN while the app is closed, and later tap Copy beside a link on *Links for Shortcuts* at the bottom of the home screen
- **Then:** the app opens on the timer with 1 MIN counting down, and the clipboard holds exactly that link; Context Grabber's own `grabber://` links still open Context Grabber

- **Scenario:** A shortcut to the app itself
- **Given:** the app is closed or showing another screen
- **When:** I run *Open Grabber Native* (or say "Open Grabber Native")
- **Then:** the app opens on its home screen with nothing started

---

### User Story 136:

- **Summary:** The usage left on a home-screen tile, with one-tap starts beside it
- **Status:** implemented in [7b70242](https://github.com/idvorkin/context-grabber/commit/7b70242); verified by `UsageSnapshotTests` (host: the round trip, the countdown and *to spend* at drawing time, the age, the placeholder) and `UsageTileUITests` on the simulator (the medium tile added through SpringBoard's gallery draws the real Cockpit reading, *just now*; its Gym Timer starts the last preset); the orange age over hours, low and critical bars, the placeholder on screen, Breathe and Call Larry from the tile, and the App Group on a device-signed build not yet on the phone
- **Issues:** [#168](https://github.com/idvorkin/context-grabber/issues/168)

#### Use Case:
- **As a** man deciding whether to start another long session with Claude, or whether this week's allowance is about to go unspent
- **I want to** see Week, the model and Voice left on a Grabber Native tile on the home screen, and start the Gym Timer, Box breathing or a call to Larry from the same tile
- **so that** the budget is a glance and the things I do daily are one tap, without opening the app first

#### Acceptance Criteria:
- **Scenario:** The tile after a reading
- **Given:** the small or medium live tile is on the home screen and Grabber Native has loaded a reading on the tailnet
- **When:** I look at the home screen, and again two hours later without opening the app
- **Then:** the tile shows the strip's bars and numbers with the strip's orange and red, then *12m ago* in grey, later *2h ago* in orange, and *31% to spend* in green once the week resets within a day with more than 20% left

- **Scenario:** One tap, and before any reading
- **Given:** the medium tile, on a phone where Grabber Native has never loaded a reading
- **When:** I look at it, then tap Gym Timer
- **Then:** it reads *Open Grabber Native* with no numbers, and the tap opens the app with the last preset counting down; Breathe begins a session and Call Larry starts the call the same way

---

### User Story 137:

- **Summary:** My eulogy, its song and the blog's recent changes, one tap each
- **Issues:** [#177](https://github.com/idvorkin/context-grabber/issues/177), [#195](https://github.com/idvorkin/context-grabber/issues/195), [#197](https://github.com/idvorkin/context-grabber/issues/197), [#201](https://github.com/idvorkin/context-grabber/issues/201), [#205](https://github.com/idvorkin/context-grabber/issues/205), [#692](https://github.com/idvorkin/context-grabber/issues/692)
- **Status:** implemented in [0a3f541](https://github.com/idvorkin/context-grabber/commit/0a3f541), [2b75d3a](https://github.com/idvorkin/context-grabber/commit/2b75d3a), [6dc7848](https://github.com/idvorkin/context-grabber/commit/6dc7848); verified by `BlogLinksTests` (host, the post as served 2026-10-07) and `EulogyUITests` on the simulator (Eulogy and Recent bring Safari forward; the song plays in the app, pauses, resumes from where it was after the sheet closes, and Open on Suno opens the song the post embeds; the scrubber moves it, restart plays from the start, and with the sheet closed the small player pauses in place, opens the sheet as it is, and its ✕ takes it away); the lock screen, playing on with the phone locked, and the phone not yet; the player's rules (play and resume where it was, the scrub, restart, the ✕, the finish, a call pausing it and holding it off, a song that cannot load or start saying so and letting the audio go) moved from `EulogyUITests` to host tests (`SongPlaybackTests`); the simulator keeps one play with restart and the small player, the blog launchers and Open on Suno: [00b1c66](https://github.com/idvorkin/context-grabber/commit/00b1c66), verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending; #692 (the song refused on the simulator, 2026-11-05) was the simulator's audio, not the app: `EulogyUITests` green again and a song that does not play now names the problem on the sheet: [06b1d58](https://github.com/idvorkin/context-grabber/commit/06b1d58), verified on the simulator (iPhone 17, 2026-11-19: `EulogyUITests` 3/3 twice, the log's load in 0.16 s and play ok; the failure message checked with the song missing)
- **Spec:** [native Eulogy](../superpowers/specs/2026-10-07-native-eulogy-design.md)

#### Use Case:
- **As someone** who rereads his eulogy, plays its song and checks what changed on his blog most days
- **I want to** reach each from the home screen in one tap
- **so that** the daily practice costs no typing and no hunting

#### Acceptance Criteria:
- **Scenario:** The song in the app
- **Given:** I am on the home screen, online or not
- **When:** I tap *Eulogy song*
- **Then:** a sheet titled *How Igor wants to live* opens and the song starts playing inside the app, with a pause button and how far through it is; it pauses whatever else was playing

- **Scenario:** Keep listening
- **Given:** the song is playing
- **When:** I close the sheet, lock the phone, or go to another app
- **Then:** the song keeps playing, and the lock screen shows it with play and pause

- **Scenario:** Pick up where I left off
- **Given:** I paused the song partway and closed the sheet
- **When:** I tap *Eulogy song* again
- **Then:** the sheet shows the same place and the song resumes from it, not from the start

- **Scenario:** A call comes first
- **Given:** the song is playing, or a Larry call is live
- **When:** I start a call, or tap play on the song
- **Then:** starting the call pauses the song where it is; with the call live the song does not play and its sheet says it waits for the call to end

- **Scenario:** Scrub and restart
- **Given:** the song's sheet is open
- **When:** I drag the scrubber to the last chorus, or tap restart
- **Then:** the song carries on from where I let go (still playing, or still paused), or plays from the start

- **Scenario:** The small player
- **Given:** the song is playing or paused partway and I closed its sheet
- **When:** I look at the home screen
- **Then:** a small player sits in the bottom-left corner with the song's place and play/pause; tapping it opens the sheet, its ✕ stops the song and it goes away, and it goes away by itself when the song ends

- **Scenario:** The song on Suno
- **Given:** the eulogy post embeds a Suno song
- **When:** I tap *Open on Suno* in the song's sheet
- **Then:** that song opens on Suno (the app if installed, else the browser), and the log names the song and that it came from the post

- **Scenario:** Offline
- **Given:** the phone cannot reach the blog
- **When:** I tap *Open on Suno*
- **Then:** the song found last time opens; if none was ever found, the eulogy post opens and the screen says the song could not be found

- **Scenario:** The post and recent changes
- **Given:** the home screen
- **When:** I tap *Eulogy*, and later *Recent*
- **Then:** idvork.in/eulogy and idvork.in/recent open in the browser

---

### User Story 138:

- **Summary:** The eulogy song plays at its own speed, in the car too
- **Issues:** [#370](https://github.com/idvorkin/context-grabber/issues/370)
- **Status:** implemented in [d0a1353](https://github.com/idvorkin/context-grabber/commit/d0a1353) (the session set before the player is prepared, a player prepared at another sample rate replaced at the same place, and the rate, route and any clock drift in the log) and [4ff9f1b](https://github.com/idvorkin/context-grabber/commit/4ff9f1b) with the review fix after it (a song that will not load, or will not start, lets the session go so other audio comes back); verified by `just native-lint`, and the app compiled in the simulator build at 3106eb2 (2026-10-18 build turn); the car on the phone is still for Igor to check; the reload at a new sample rate and the drift line are now host tests (`SongPlaybackTests`): [00b1c66](https://github.com/idvorkin/context-grabber/commit/00b1c66), verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending
- **Spec:** [native Eulogy](../superpowers/specs/2026-10-07-native-eulogy-design.md)

#### Use Case:
- **As someone** who plays his eulogy song while driving, often right after a Larry call or the Cockpit
- **I want to** hear it at its own speed, whatever audio route was there before
- **so that** the song is the song, not a chipmunk that ends in 45 seconds

#### Acceptance Criteria:
- **Scenario:** Right after the hands-free line
- **Given:** the phone is on the car's hands-free line and the Cockpit was just open
- **When:** I tap *Eulogy song* and listen for a minute
- **Then:** the song sounds as recorded and its clock reads about 1:00, not three times that

---

### User Story 247:

- **Summary:** A random page of my blog, one tap away
- **Issues:** [#259](https://github.com/idvorkin/context-grabber/issues/259)
- **Status:** implemented in [456463e](https://github.com/idvorkin/context-grabber/commit/456463e); verified on the simulator by `EulogyUITests` (Random brings Safari forward, 2026-10-11); the phone not yet
- **Spec:** [native Eulogy](../superpowers/specs/2026-10-07-native-eulogy-design.md)

#### Use Case:
- **As someone** whose blog has years of posts he no longer remembers writing
- **I want to** open a random page of it from the home screen
- **so that** I reread something I'd forgotten without choosing it

#### Acceptance Criteria:
- **Scenario:** A random page
- **Given:** the home screen, online
- **When:** I tap *Random*
- **Then:** idvork.in/random opens in the browser and shows a page of the blog the blog picked; tapping again later usually lands somewhere else

- **Scenario:** Like any launcher
- **Given:** a phone that already has its own order of launchers
- **When:** this build arrives
- **Then:** *Random* shows at the end until I move or hide it from Settings

---

### User Story 465:

- **Summary:** Holding Random offers the blog's topics
- **Issues:** [#392](https://github.com/idvorkin/context-grabber/issues/392)
- **Status:** native app only: implemented in [765ffa1](https://github.com/idvorkin/context-grabber/commit/765ffa1); verified by `HoldChoicesTests` (host: the eight choices in order) and HoldPopoverUITests' Random test (simulator; dropped in [35457eed](https://github.com/idvorkin/context-grabber/commit/35457eed), the choices' order being `HoldChoicesTests`' and the popover itself still shown by `testATapOutsideOpensNothing`); the tick and the look on the phone not yet
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As someone** whose blog has years of posts on many subjects
- **I want to** press and hold the Random tile and see the topics as small tiles
- **so that** I can ask for one subject without leaving the home screen

#### Acceptance Criteria:
- **Scenario:** The topics popover
- **Given:** the home screen
- **When:** I press and hold *Random*
- **Then:** a popover pointing at the tile offers Anything, AI, Tech, Family, Health, Mind, Work and Books, each with a picture and its name, Anything first, and the log has the popover opening

---

### User Story 466:

- **Summary:** A topic opens the blog's random link for that topic
- **Issues:** [#392](https://github.com/idvorkin/context-grabber/issues/392)
- **Status:** native app only: implemented in [765ffa1](https://github.com/idvorkin/context-grabber/commit/765ffa1); verified by `BlogLinksTests` (host: each topic's link) and HoldPopoverUITests' Random test (simulator: AI brings the browser forward; since [35457eed](https://github.com/idvorkin/context-grabber/commit/35457eed) the host's `HomeStackTests.testEveryHeldChoiceOpensItsScreenFromHome` checks AI asks for its topic, and the browser coming forward is the phone's to see); the post being on that topic needs the blog's change (story 468)
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As someone** whose blog has years of posts on many subjects
- **I want to** choose a topic from the Random popover
- **so that** the blog picks a post on that subject

#### Acceptance Criteria:
- **Scenario:** Choosing AI
- **Given:** the Random popover is open
- **When:** I tap *AI*
- **Then:** idvork.in/random?topic=ai opens in the browser, the popover closes, and the log has `open_random` with `from: home_popover` and `topic: ai`

---

### User Story 467:

- **Summary:** A plain tap on Random stays random from everything
- **Issues:** [#392](https://github.com/idvorkin/context-grabber/issues/392)
- **Status:** native app only: implemented in [765ffa1](https://github.com/idvorkin/context-grabber/commit/765ffa1); verified by `BlogLinksTests` (host: Anything is the tile's own link) and `EulogyUITests.testBlogLaunchersLeaveTheApp` (simulator: the tap still opens the browser)
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As someone** whose blog has years of posts on many subjects
- **I want to** tap Random, or choose Anything from its popover
- **so that** the quick way still surprises me with any post

#### Acceptance Criteria:
- **Scenario:** Tap or Anything
- **Given:** the home screen
- **When:** I tap *Random*, or hold it and tap *Anything*
- **Then:** idvork.in/random opens in the browser with no topic in the link

---

### User Story 468:

- **Summary:** A topic the blog does not know still lands on a post
- **Issues:** [#392](https://github.com/idvorkin/context-grabber/issues/392)
- **Status:** native app only: the app's half implemented in [765ffa1](https://github.com/idvorkin/context-grabber/commit/765ffa1), which needs no change when the blog ships; the blog's half is not implemented (a PR to idvorkin/idvorkin.github.io). Checked 2026-11-03 by reading the live page and its script: idvork.in/random?topic=ai answers 200, reads no topic and picks from every post
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As someone** whose blog has years of posts on many subjects
- **I want to** choose a topic before the blog has learned topics
- **so that** nothing breaks while the two halves ship apart, and the choices start working by themselves

#### Acceptance Criteria:
- **Scenario:** The blog ignores the topic
- **Given:** the blog does not read the topic in the link
- **When:** I choose *AI* from the Random popover
- **Then:** the browser lands on a random post drawn from everything, the app shows no error, and it cannot tell the topic was ignored

---

### User Story 469:

- **Summary:** VoiceOver reaches every topic
- **Issues:** [#392](https://github.com/idvorkin/context-grabber/issues/392)
- **Status:** native app only: implemented in [765ffa1](https://github.com/idvorkin/context-grabber/commit/765ffa1), by the same tile actions as stories 222-225; only the phone can show VoiceOver, not yet checked
- **Spec:** [Press and hold a tile: a popover of drawn icons](../superpowers/specs/2026-10-18-press-and-hold-popovers-design.md)

#### Use Case:
- **As someone** whose blog has years of posts on many subjects
- **I want to** reach each topic from the Random tile's actions with VoiceOver on
- **so that** a topic never depends on a press and hold

#### Acceptance Criteria:
- **Scenario:** VoiceOver
- **Given:** VoiceOver is on and *Random* is focused
- **When:** I choose the *Family* action
- **Then:** idvork.in/random?topic=family opens in the browser

---

### User Story 228:

- **Summary:** A link opens a board, or the boards
- **Status:** native app only: implemented in [f37d267](https://github.com/idvorkin/context-grabber/commit/f37d267); verified on the simulator (a board no device has, against the fake Cockpit, stays on the boards with the problem) and by host tests (the link's parsing); a board drawn here opening at once in [4933b0ba](https://github.com/idvorkin/context-grabber/commit/4933b0ba) (#1137, `BoardFindTests` on the host); a board that comes down from iCloud through the link, not yet; a missing board's problem within about five seconds however slowly iCloud answers in [ce9c111a](https://github.com/idvorkin/context-grabber/commit/ce9c111a) (context-grabber-4qel), verified on the host by `BoardFindTests` (the wait cut short while the sync runs on) and the Mac build; the simulator (rung 2: `ChatImageUITests` on the iPhone and iPad, `WhiteboardRowDeleteUITests`, and a session log with a forced `icloud: no_answer`) owed once the simulators work
- **Issues:** [#603](https://github.com/idvorkin/context-grabber/issues/603), [#1137](https://github.com/idvorkin/context-grabber/issues/1137), bead context-grabber-4qel
- **Spec:** [Native links](../superpowers/specs/2026-10-06-native-links-design.md)

#### Use Case:
- **As** someone holding a link to one of my whiteboards
- **I want to** open it and be on that board as it is now
- **so that** I never read an old drawing as the current one

#### Acceptance Criteria:
- **Scenario:** A link to a board
- **Given:** I have a `grabbernative://whiteboard?board=<id>` link
- **When:** I open it
- **Then:** that board opens as it is now, at once when it is drawn on this device and after asking iCloud when it is another device's (#1137), which gets about five seconds to answer before the link goes by what is here; a board that can't be opened leaves me on the boards with a copyable problem saying why

---

### User Story 569:

- **Summary:** A link to a web ink board opens its page in the browser
- **Status:** native app only: implemented in [e146d45c](https://github.com/idvorkin/context-grabber/commit/e146d45c); verified by host tests (`WebInkBoardTests`: which ids are web boards, the page's address) and on the iPad Pro 11-inch (M5) simulator (`WebInkBoardLinkUITests`: the link opens Safari, no board-missing problem; the session log's `open_web_board` then `opened_web_board ok`); the board debug page's chip on the real iPad not yet
- **Issues:** [#1354](https://github.com/idvorkin/context-grabber/issues/1354)
- **Spec:** [Native links](../superpowers/specs/2026-10-06-native-links-design.md)

On 2026-11-23 the board debug page's chip opened `grabbernative://whiteboard?board=ink-wasn-t` on the iPad, a board
drawn on the Cockpit's web ink page, and the app looked for it among its own boards and said it wasn't on the device.

#### Use Case:
- **As** Igor following a board chip from the Cockpit
- **I want** a web ink board's link to open that board where it lives
- **so that** I land on the board, not on a problem saying it isn't here

#### Acceptance Criteria:
- **Scenario:** A link to a web ink board
- **Given:** a `grabbernative://whiteboard?board=ink-<name>` link, a board of the Cockpit's web ink page
- **When:** I open it
- **Then:** the browser opens that board's page on the Cockpit (`/ink?b=<name>`); the app doesn't look for it among
  its boards or show a problem; the session log says the web board was opened and from where

---

### User Story 460:

- **Summary:** Hold a tile and open its screen in a new window on the iPad
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the iPad simulator (a window opened and closed by `GRABBER_WINDOW`: `window` open, appear, close, gone); the ledger and what a hold offers by `WindowLedgerTests`, on the host. The hold itself and the windows side by side are for the iPad, and so is opening a window after another has closed.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor on the iPad
- **I want to** open Chat, Today, the Cockpit, Places, the boards or the card in a window of its own
- **so that** I can see two of them side by side

#### Acceptance Criteria:
- **Scenario:** A hold offers a window
- **Given:** I am on the iPad's home screen
- **When:** I press and hold one of those tiles, or the Today card, and choose *New window*
- **Then:** that screen opens in a new window, with the home window as it was, and its Done closes the window

---

### User Story 470:

- **Summary:** A phone is as it was without windows
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the host (what a hold offers, `WindowLedgerTests`) and the phone's links by `LinksUITests`.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor on the iPhone
- **I want to** have every hold and screen as it was
- **so that** the iPad's windows cost the phone nothing

#### Acceptance Criteria:
- **Scenario:** A phone is as it was
- **Given:** I am on the iPhone
- **When:** I hold any tile
- **Then:** nothing offers a window, and a tile that had no popover still has none

---

### User Story 461:

- **Summary:** A screen is in one window at a time
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the iPad simulator (asked again, it came forward with two scenes still connected). The hold itself is for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with a screen in its own window
- **I want to** have every way of opening it bring that window forward
- **so that** a page or a board never ends up in two places, where one would overwrite the other

#### Acceptance Criteria:
- **Scenario:** The tile again
- **Given:** Chat is in a window of its own
- **When:** I tap its tile, hold it and choose *New window*, or open a link to it
- **Then:** that window comes forward, no second one opens, and a link's thread or board opens inside it

---

### User Story 471:

- **Summary:** A screen leaves the home window when it gets a window of its own
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the iPad simulator (the boards up at home left before their window opened). The Cockpit's page moving is for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with the Cockpit up at home
- **I want to** give it a window without reloading it
- **so that** its page and what's on it come along

#### Acceptance Criteria:
- **Scenario:** It was showing at home
- **Given:** the home window shows the Cockpit
- **When:** another window asks for the Cockpit in a window
- **Then:** it leaves the home window first and the page comes along as it was

---

### User Story 472:

- **Summary:** A card already in a window comes forward without starting a drill or a count
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; not verified by a run: only a hold with the card in a window reaches it, which is for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with the card in its own window
- **I want to** hold the card tile or tap it without anything starting behind my back
- **so that** a drill never starts later when I didn't ask for it then

#### Acceptance Criteria:
- **Scenario:** Drill the stack, with the card in a window
- **Given:** the card is in a window of its own
- **When:** I hold its tile and choose *Drill the stack*
- **Then:** that window comes forward as it was, no drill starts in it, and none starts the next time the card opens

---

### User Story 462:

- **Summary:** A window iPadOS makes itself says home is elsewhere rather than repeating it
- **Status:** replaced by story 731 (#782). Was native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; not verified by a run: only the iPad's own New Window reaches it, which is for the iPad. The ledger's rule is `WindowLedgerTests`.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor using iPadOS's own New Window
- **I want to** be told what that window can't do and where to go
- **so that** it doesn't show every screen the home window opens a second time

#### Acceptance Criteria:
- **Scenario:** A home window is up
- **Given:** the home window is open
- **When:** I make a new window of the app from iPadOS's menus
- **Then:** it says home is open in another window and to hold a tile there (replaced by story 731, #782: it now offers
  the screens that can have a window)

---

### User Story 473:

- **Summary:** A new window with no home window is the home window
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; the ledger's rule by `WindowLedgerTests`, on the host; iPadOS's own New Window is for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor having closed the home window
- **I want to** get it back from iPadOS's menus
- **so that** I always have a way to the home screen

#### Acceptance Criteria:
- **Scenario:** No home window
- **Given:** I closed the home window
- **When:** I make a new window of the app
- **Then:** it is the home window

---

### User Story 463:

- **Summary:** A second window leaves a call alone
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the iPad simulator (a call on the fake bridge, synthetic audio, with a board's window opened and closed: it ran to its hang-up, ended `stopped`, not `badly`, and the bridge saw `stt_stop` and `stop`).
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor on a call
- **I want to** open and close other windows without the call noticing
- **so that** having windows costs me nothing

#### Acceptance Criteria:
- **Scenario:** A call and a window
- **Given:** a call with Larry is up
- **When:** I open a board in a window and close it again
- **Then:** the call carries on as it was

---

### User Story 474:

- **Summary:** A call stops a board's microphone in its window too
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); not verified by a run with a board listening in a window: for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with a board listening in its own window
- **I want to** have a call take the microphone as it does at home
- **so that** the two never fight over it

#### Acceptance Criteria:
- **Scenario:** A call starts with a board's microphone on
- **Given:** a board in its own window is listening
- **When:** a call starts
- **Then:** the board's microphone stops, as it does in the home window

---

### User Story 475:

- **Summary:** A board's window saves what was drawn as it closes
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); not verified by a run with drawing: for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor drawing on a board in a window
- **I want to** close the window any way I like
- **so that** nothing I drew is lost

#### Acceptance Criteria:
- **Scenario:** A board's window closes
- **Given:** I am drawing on a board in a window
- **When:** that window closes, by Done or the system's way
- **Then:** what I drew is saved

---

### User Story 476:

- **Summary:** The screens that hold the audio stay in the home window
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the host (what a hold offers, `WindowLedgerTests`).
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor on the iPad's home screen
- **I want to** not be offered a window for the screens that hold the audio
- **so that** they never talk over each other

#### Acceptance Criteria:
- **Scenario:** What has no window
- **Given:** I am on the iPad's home screen
- **When:** I hold the Gym Timer or Box breathing tile, or look for the call
- **Then:** none offers *New window*, since each holds the audio and shows in the home window only

---

### User Story 464:

- **Summary:** With windows the app comes back once
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the host (`AppPhaseLatch`, one change counted once).
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with several windows open
- **I want to** have a return to the front counted once
- **so that** nothing runs twice

#### Acceptance Criteria:
- **Scenario:** Coming back
- **Given:** two windows are open
- **When:** the app comes back to the front
- **Then:** its refresh and syncs run once

---

### User Story 477:

- **Summary:** A link with the home window closed brings it back
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); not verified by a run: for the iPad, including whether iOS opens a window for the link itself, which `window` home, extra_home and reopen_home in the log would show.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with only a Chat window open
- **I want to** have a link or Shortcut land somewhere
- **so that** nothing goes missing

#### Acceptance Criteria:
- **Scenario:** A link with the home window closed
- **Given:** only a Chat window is open
- **When:** a link or Shortcut asks for a screen with no window
- **Then:** the home window comes back and shows it

---

### User Story 478:

- **Summary:** A report names the window it was shaken in
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; not verified by a run: for the iPad, and side by side it can name either window's screen (the spec's limit).
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with a screen in a window in front
- **I want to** have a report say which screen I was on
- **so that** the issue it becomes points at the right place

#### Acceptance Criteria:
- **Scenario:** A report
- **Given:** Chat is in a window of its own and in front
- **When:** I shake or press ⌘I
- **Then:** one report opens over that window, with its picture, naming chat

---

### User Story 479:

- **Summary:** A link that lands in the home window brings it forward
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; not verified by a run: `window` bring_home in the log, for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor working in Chat's window with home behind it
- **I want to** see what a link does to the home window
- **so that** nothing changes out of sight, above all a running timer

#### Acceptance Criteria:
- **Scenario:** Jump to board from a Chat window
- **Given:** Chat is in a window of its own in front, home is behind it and the boards have no window
- **When:** I tap *Jump to board*
- **Then:** the home window comes forward showing the boards

---

### User Story 565:

- **Summary:** Closing the card's window brings its widgets up to date
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; not verified by a run: widgets exist only on a device, for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor dealing cards in a window
- **I want to** see the deal on the widgets when I'm done
- **so that** they match the card as they do when it closes at home

#### Acceptance Criteria:
- **Scenario:** The card's window closes
- **Given:** I dealt cards in the card's own window
- **When:** that window closes, by Done or the system's way
- **Then:** the home and lock screen card widgets catch up

---

### User Story 566:

- **Summary:** A Places window closed on its map opens on the list next time
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df) and its review fix; not verified by a run: for the iPad.
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor who closed Places with the map up
- **I want to** open Places on its list as usual
- **so that** a closed window leaves no trace

#### Acceptance Criteria:
- **Scenario:** Closed with the map up
- **Given:** Places is in a window with its full-screen map up
- **When:** I close that window the system's way and open Places again
- **Then:** it opens on the list, with the map down

---

### User Story 567:

- **Summary:** A relaunch always has a home window
- **Status:** native app only: implemented in [cc011df](https://github.com/idvorkin/context-grabber/commit/cc011df); verified on the iPad simulator (a relaunch brings the home window).
- **Issues:** [#634](https://github.com/idvorkin/context-grabber/issues/634)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor relaunching the app with a screen's window open
- **I want to** always have a way to the home screen
- **so that** no launch leaves me stuck on one screen

#### Acceptance Criteria:
- **Scenario:** A relaunch
- **Given:** iPadOS brings back only a screen's window
- **When:** the app starts
- **Then:** the home window opens too, a moment later

### User Story 560:

- **Summary:** A screen's window is called by that screen's name
- **Status:** native app only: implemented in [df9b8ac](https://github.com/idvorkin/context-grabber/commit/df9b8ac); verified on the iPad simulator (the log's `title` line, read back from the scene, for a Chat and a Today window); the role by `WindowLedgerTests`, on the host. Where iPadOS shows the name is for the iPad: the simulator's log shows the scene holds it, not how the system draws it.
- **Issues:** [#661](https://github.com/idvorkin/context-grabber/issues/661)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with several windows of the app open on the iPad
- **I want to** have each window named for the screen in it
- **so that** I can pick the one I want from the system's list of windows

#### Acceptance Criteria:
- **Scenario:** Chat in a window of its own
- **Given:** Chat is in a window of its own
- **When:** iPadOS shows the app's windows by name
- **Then:** that window reads Chat, the name on its home tile

### User Story 561:

- **Summary:** The home window's name follows what it is showing
- **Status:** native app only: implemented in [df9b8ac](https://github.com/idvorkin/context-grabber/commit/df9b8ac); verified on the iPad simulator by the log's `title` lines: there and back for Places, Cockpit, Whiteboard, Box breathing, Gym Timer, Think of a card and Today; going up only for Chat, Settings and What's new. Call Larry and the eulogy song's sheet were not run. Where iPadOS shows the name is for the iPad.
- **Issues:** [#661](https://github.com/idvorkin/context-grabber/issues/661)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor moving around in the home window
- **I want to** have its name say what is in it now
- **so that** it never reads as a screen I have left

#### Acceptance Criteria:
- **Scenario:** Places over home, then closed
- **Given:** the home window is on the home grid and reads Home
- **When:** I open Places there and later close it
- **Then:** it reads Places while Places is up, then Home again

### User Story 562:

- **Summary:** Another window's screen leaves the home window's name alone
- **Status:** native app only: implemented in [df9b8ac](https://github.com/idvorkin/context-grabber/commit/df9b8ac); verified on the iPad simulator (a Today window opened and closed, with no `title` line for the home window) and by `WindowLedgerTests`, on the host.
- **Issues:** [#661](https://github.com/idvorkin/context-grabber/issues/661)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor with Today in a window of its own
- **I want to** have the home window keep its own name
- **so that** two windows never claim one screen

#### Acceptance Criteria:
- **Scenario:** Today opens in its own window
- **Given:** the home window is on the home grid
- **When:** Today opens in a window of its own
- **Then:** the home window still reads Home and the new window reads Today

### User Story 563:

- **Summary:** A window saying home is elsewhere has no name
- **Status:** native app only: implemented in [df9b8ac](https://github.com/idvorkin/context-grabber/commit/df9b8ac); the rule by `WindowLedgerTests`, on the host; not verified by a run: only iPadOS's own New Window reaches it, which is for the iPad.
- **Issues:** [#661](https://github.com/idvorkin/context-grabber/issues/661)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor using iPadOS's own New Window
- **I want to** not see a name for a screen that window doesn't have
- **so that** the window list doesn't offer a second Home

#### Acceptance Criteria:
- **Scenario:** A new window with home up
- **Given:** the home window is open
- **When:** I make a new window of the app from iPadOS's menus
- **Then:** it says home is open in another window and the app gives it no name

### User Story 564:

- **Summary:** A phone names no window
- **Status:** native app only: implemented in [df9b8ac](https://github.com/idvorkin/context-grabber/commit/df9b8ac); verified on an iPhone simulator (the home window and Places, no `title` line in the log).
- **Issues:** [#661](https://github.com/idvorkin/context-grabber/issues/661)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor on the iPhone
- **I want to** have the phone stay as it was
- **so that** the iPad's window names cost the phone nothing

#### Acceptance Criteria:
- **Scenario:** Moving between screens on a phone
- **Given:** the app is on an iPhone, which has one window
- **When:** I open and close any screen
- **Then:** the app sets no name on the window

---

### User Story 233:

- **Summary:** A window's name says what's open in it, as the Cockpit's tab does
- **Status:** native app only: implemented in [0d9609c9](https://github.com/idvorkin/context-grabber/commit/0d9609c9); verified by host tests and lint (`just native-test`, `WindowTitleTests`: the Cockpit's `pageTitle` and `titleDetail` cases) and the Mac build (`just native-build-mac`); not yet seen in a window on the iPad or the Mac. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-ds8r (Igor, 2026-11-22, feedback via Larry: window titles follow the view, as the
  Cockpit now does, its story 211)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md), *Its name says what's open in it*

#### Use Case:
- **As** Igor with the app in several windows on the iPad or the Mac
- **I want to** see in each window's name what it shows, in the same words the Cockpit's browser tab uses
- **so that** I can pick the right window from the Mac's window list or the iPad's switcher without opening each one

#### Acceptance Criteria:
- **Scenario:** The Cockpit in a window
- **Given:** the Cockpit is open in a window of its own (or in the home window)
- **When:** I move to its Machines view
- **Then:** the window is named *Cockpit · Machines*, the Cockpit's own name for the view

### User Story 234:

- **Summary:** The Cockpit's window is plain Cockpit until its page names itself
- **Status:** native app only: implemented in [0d9609c9](https://github.com/idvorkin/context-grabber/commit/0d9609c9); verified by host tests and lint (`just native-test`, `WindowTitleTests`: the Cockpit's `pageTitle` and `titleDetail` cases) and the Mac build (`just native-build-mac`); not yet seen in a window on the iPad or the Mac. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-ds8r (Igor, 2026-11-22, feedback via Larry: window titles follow the view, as the
  Cockpit now does, its story 211)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md), *Its name says what's open in it*

#### Use Case:
- **As** Igor with the app in several windows on the iPad or the Mac
- **I want to** see a plain name while the Cockpit's page hasn't said what it shows
- **so that** the window never carries a stale or a stranger page's name

#### Acceptance Criteria:
- **Scenario:** The Cockpit before it names itself
- **Given:** the Cockpit's page hasn't loaded, can't load, or a link took it to a page that isn't the Cockpit's
- **When:** I look at the window's name
- **Then:** it is plain *Cockpit*

### User Story 235:

- **Summary:** A Chat window's name carries the open thread's title
- **Status:** native app only: implemented in [0d9609c9](https://github.com/idvorkin/context-grabber/commit/0d9609c9); verified by host tests and lint (`just native-test`, `WindowTitleTests`: the Cockpit's `pageTitle` and `titleDetail` cases) and the Mac build (`just native-build-mac`); not yet seen in a window on the iPad or the Mac. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-ds8r (Igor, 2026-11-22, feedback via Larry: window titles follow the view, as the
  Cockpit now does, its story 211)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md), *Its name says what's open in it*

#### Use Case:
- **As** Igor with the app in several windows on the iPad or the Mac
- **I want to** see which thread a Chat window has open
- **so that** I can find the conversation I want among my windows

#### Acceptance Criteria:
- **Scenario:** A thread open in Chat
- **Given:** Chat is open in a window on its list of threads
- **When:** I open a thread
- **Then:** the window is *Chat · <the thread's title>*

### User Story 236:

- **Summary:** A Whiteboard window's name follows the open board's name
- **Status:** native app only: implemented in [0d9609c9](https://github.com/idvorkin/context-grabber/commit/0d9609c9); verified by host tests and lint (`just native-test`, `WindowTitleTests`: the Cockpit's `pageTitle` and `titleDetail` cases) and the Mac build (`just native-build-mac`); not yet seen in a window on the iPad or the Mac. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-ds8r (Igor, 2026-11-22, feedback via Larry: window titles follow the view, as the
  Cockpit now does, its story 211)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md), *Its name says what's open in it*

#### Use Case:
- **As** Igor with the app in several windows on the iPad or the Mac
- **I want to** see which board a Whiteboard window has open, under its current name
- **so that** the window list matches what I called the board

#### Acceptance Criteria:
- **Scenario:** Renaming the open board
- **Given:** a board is open in the Whiteboard window, which is named *Whiteboard · <its name>*
- **When:** I rename the open board
- **Then:** the window carries the new name

### User Story 237:

- **Summary:** A long or markdown title is cut to plain words in a window's name
- **Status:** native app only: implemented in [0d9609c9](https://github.com/idvorkin/context-grabber/commit/0d9609c9); verified by host tests and lint (`just native-test`, `WindowTitleTests`: the Cockpit's `pageTitle` and `titleDetail` cases) and the Mac build (`just native-build-mac`); not yet seen in a window on the iPad or the Mac. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-ds8r (Igor, 2026-11-22, feedback via Larry: window titles follow the view, as the
  Cockpit now does, its story 211)
- **Spec:** [Windows on the iPad](../superpowers/specs/2026-11-03-ipad-windows-design.md), *Its name says what's open in it*

#### Use Case:
- **As** Igor with the app in several windows on the iPad or the Mac
- **I want to** see a short, plain name even when a thread's title is long or has markdown in it
- **so that** the window list stays readable

#### Acceptance Criteria:
- **Scenario:** A long title
- **Given:** a thread whose title is long or has markdown in it
- **When:** it is open in the Chat window
- **Then:** the name shows its plain words, cut to 40 characters with *…*

---

### User Story 580:

- **Summary:** One command opens the app on the Mac
- **Status:** native app only: implemented in [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a); verified on Igor's Mac, ad hoc: the app opens in a window with the iPad's layout and no crash report through every launch; the recipe built and opened it, with no Cockpit address.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor at his Mac
- **I want to** run the same app there as a real Mac app
- **so that** chat and the whiteboard are in a window beside my other work

#### Acceptance Criteria:
- **Scenario:** Starting it
- **Given:** a checkout of the repo on a Mac
- **When:** I run the Mac recipe
- **Then:** the app builds with no signing identity and opens in a window of its own

---

### User Story 581:

- **Summary:** Each screen a Mac can run comes up on the Mac
- **Status:** native app only: implemented in [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a); verified on Igor's Mac, ad hoc, by launch link and session log, with a picture of each screen: home, Today, the timer (cues played, muted), breathing (cues played, muted), Places, the Cockpit, the card, Chat, the whiteboard and a call. Drawing with a mouse is not verified: it needs a person.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor at his Mac
- **I want to** open any home tile
- **so that** a tile either does its work or tells me why it can't

#### Acceptance Criteria:
- **Scenario:** Opening a tile
- **Given:** the app is open on the Mac
- **When:** I open any main screen
- **Then:** it comes up, and the app keeps running

---

### User Story 582:

- **Summary:** A Mac build reaches my Cockpit by itself
- **Status:** native app only: [#680](https://github.com/idvorkin/context-grabber/issues/680), connecting by default, reversing the rule [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a) built here: [dd827e96](https://github.com/idvorkin/context-grabber/commit/dd827e96); host tests (`ChatCockpitTests`), and verified on Igor's Mac, ad hoc, with no address named: chat read his 125 threads from his Cockpit and logged no `no_address`.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638), [#680](https://github.com/idvorkin/context-grabber/issues/680)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, whose Mac is on the tailnet
- **I want** the Mac build to reach my Cockpit with nothing to set, as my phone does
- **so that** chat works as soon as it opens

#### Acceptance Criteria:
- **Scenario:** No address named
- **Given:** a Mac build launched with no Cockpit address
- **When:** I open chat
- **Then:** my threads load from my Cockpit, with no error about an address

---

### User Story 583:

- **Summary:** Named, a Mac build's chat goes to that Cockpit
- **Status:** native app only: implemented in [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a); verified on Igor's Mac against the stand-in: a message written in a thread reached it, its reply showed, and the outbox emptied.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor at his Mac
- **I want to** name a Cockpit when I start the app
- **so that** chat works there, against the stand-in or the real one

#### Acceptance Criteria:
- **Scenario:** A message from the Mac
- **Given:** a Mac build launched with a Cockpit address
- **When:** I send a message in a thread
- **Then:** it reaches that Cockpit and the reply shows in the thread

---

### User Story 584:

- **Summary:** Places says a Mac doesn't track in the background
- **Status:** native app only: implemented in [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a); built for the Mac and the screen opened on Igor's Mac, its log clean. macOS's location prompt was left unanswered, so a location fix is not verified.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor looking at Places on the Mac
- **I want** no switch that promises a trail a Mac can't record
- **so that** the screen is honest about what it does here

#### Acceptance Criteria:
- **Scenario:** The tracking section on a Mac
- **Given:** Places is open on the Mac
- **When:** I look at the tracking section
- **Then:** a line says a Mac doesn't record in the background, where a phone has the switch

---

### User Story 585:

- **Summary:** The timer and breathing run on a Mac with no Live Activity
- **Status:** native app only: implemented in [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a); verified on Igor's Mac by launch hook and session log: a timer ran through its count-in and into its first round, its cues playing muted, and a breathing session ran to its finish, with no error. The Mac build has no Live Activity code to call.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor timing a set at my desk
- **I want** the timer to run in its window
- **so that** the card a Mac doesn't have is no failure

#### Acceptance Criteria:
- **Scenario:** A session on the Mac
- **Given:** the Gym Timer or Box breathing is open on the Mac
- **When:** I start a session
- **Then:** it runs to its end in the window, and nothing reports a missing card

---

### User Story 586:

- **Summary:** With no iCloud a Mac build's boards stay on the Mac
- **Status:** native app only: implemented in [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a); verified on Igor's Mac, ad hoc: the boards list says iCloud is out of reach, a board opens, a problem report saves on the Mac, and nothing crashes. A signed Mac build, which would have iCloud, has not been built.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor running the build with no signing identity
- **I want** iCloud's absence to be a line and not a crash
- **so that** the rest of the app is still there

#### Acceptance Criteria:
- **Scenario:** Opening the boards
- **Given:** a Mac build with no iCloud
- **When:** I open the whiteboard
- **Then:** the list says boards stay on this device, and a board opens

---

### User Story 232:

- **Summary:** With no iCloud a link to another device's board says why and files nothing
- **Status:** native app only: implemented in [8c764c11](https://github.com/idvorkin/context-grabber/commit/8c764c11); verified on the host (`BoardIndexTests`, `just native-test`) and the Mac build (`just native-build-mac`); the Mac app itself not yet.
- **Issues:** [#1254](https://github.com/idvorkin/context-grabber/issues/1254)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor running the Mac build with no iCloud
- **I want** a chat link to a board drawn on the iPad to say why it can't open here
- **so that** I open it on the iPad instead of chasing a report that is no bug

#### Acceptance Criteria:
- **Scenario:** A link to a board drawn on another device
- **Given:** a Mac build with no iCloud, and a board drawn on the iPad
- **When:** I tap the board's link in a chat
- **Then:** a copyable problem says the board isn't on this device and this build can't reach iCloud to bring it, so open it on the device that drew it; it files no automatic report

---

### User Story 587:

- **Summary:** A test launch named nowhere reaches no Cockpit
- **Status:** native app only: [#680](https://github.com/idvorkin/context-grabber/issues/680), [dd827e96](https://github.com/idvorkin/context-grabber/commit/dd827e96); host tests (`ChatCockpitTests`). Verified on Igor's Mac under [e171012a](https://github.com/idvorkin/context-grabber/commit/e171012a), when a launch with no address went nowhere: no connection to the real Cockpit's address in any launch, watched every half second; the chat list, the Cockpit page and a call each said why. Naming nowhere since [#680](https://github.com/idvorkin/context-grabber/issues/680): host tests only.
- **Issues:** [#638](https://github.com/idvorkin/context-grabber/issues/638), [#680](https://github.com/idvorkin/context-grabber/issues/680)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor testing a Mac build
- **I want to** name nowhere as the Cockpit
- **so that** a test launch never lands in my threads

#### Acceptance Criteria:
- **Scenario:** A test launch named nowhere
- **Given:** a Mac build launched with chat, the page and the usage strip all named nowhere
- **When:** chat, the Cockpit page, the usage strip and a call all try to run
- **Then:** nothing reaches the real Cockpit, and chat, the page and the call each say copyably why

---

### User Story 588:

- **Summary:** A test launch's outbox and my real one stay apart on a Mac
- **Status:** native app only: [#680](https://github.com/idvorkin/context-grabber/issues/680), implemented in the review round after [dd827e96](https://github.com/idvorkin/context-grabber/commit/dd827e96); host tests (`ChatCockpitTests`). Not yet built or seen on a Mac.
- **Issues:** [#680](https://github.com/idvorkin/context-grabber/issues/680)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, who runs test launches and real ones on the same Mac
- **I want** what each leaves waiting to stay with its own kind of launch
- **so that** a test message never reaches Larry and a real one never vanishes into a stand-in

#### Acceptance Criteria:
- **Scenario:** A message left waiting
- **Given:** one message left waiting by a test launch and one by a launch with no address named
- **When:** a later launch of either kind sends what waits
- **Then:** it sends only the message its own kind of launch left

### User Story 700:

- **Summary:** Today on the Mac says quietly that Health lives on the phone
- **Status:** implemented in [eeb68d1](https://github.com/idvorkin/context-grabber/commit/eeb68d1); verified by the Mac build only
- **Issues:** [#700](https://github.com/idvorkin/context-grabber/issues/700)
- **Spec:** [The Mac app](../superpowers/specs/2026-11-03-native-mac-app-design.md), *Health*

#### Use Case:
- **As someone** using Grabber on the Mac
- **I want to** see a plain line that Health lives on my phone
- **so that** an every-grab red error doesn't make me think the app broke

#### Acceptance Criteria:
- **Scenario:** Today on a Mac
- **Given:** the Mac app, which has no Health store
- **When:** Today opens or I pull to grab
- **Then:** where the cards would be it says *Health lives on your phone. This Mac has none.*, with no copyable error; a phone or iPad that can't reach Health still shows the error

---

### User Story 677:

- **Summary:** Send a chat message from the Mac's keyboard
- **Status:** implemented on branch native/mac-send-keys (#683); the Mac build compiles. Not yet verified by pressing the keys on a Mac (the unsigned test runner refuses the UI test; Igor checks by hand)
- **Issues:** [#683](https://github.com/idvorkin/context-grabber/issues/683)
- **Spec:** [Chat](../superpowers/specs/2026-10-25-native-chat-design.md), [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, typing to Larry on the Mac
- **I want** Enter or Command+Enter to send
- **so that** my hands stay on the keyboard instead of reaching for the Send button

#### Acceptance Criteria:
- **Scenario:** Sending with a key
- **Given:** the Mac build, a thread open, and words in the bar
- **When:** I press Enter or Command+Enter
- **Then:** the message sends and the bar empties, as a click on Send does

---

### User Story 679:

- **Summary:** Start a new line in a Mac chat message with Shift+Enter
- **Status:** implemented on branch native/mac-send-keys (#683); the Mac build compiles. Not yet verified by pressing the keys on a Mac (the unsigned test runner refuses the UI test; Igor checks by hand)
- **Issues:** [#683](https://github.com/idvorkin/context-grabber/issues/683)
- **Spec:** [Chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, writing Larry a longer message on the Mac
- **I want** Shift+Enter to start a new line
- **so that** I can break a message into lines without sending it half written

#### Acceptance Criteria:
- **Scenario:** A longer message
- **Given:** the Mac build and words in the bar
- **When:** I press Shift+Enter
- **Then:** the bar starts a new line and nothing sends

---

### User Story 680:

- **Summary:** Enter on an empty Mac chat bar sends nothing
- **Status:** implemented on branch native/mac-send-keys (#683); the Mac build compiles. Not yet verified by pressing the keys on a Mac (the unsigned test runner refuses the UI test; Igor checks by hand)
- **Issues:** [#683](https://github.com/idvorkin/context-grabber/issues/683)
- **Spec:** [Chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, pressing Enter out of habit on the Mac
- **I want** an empty bar to ignore it
- **so that** no blank message lands in the thread

#### Acceptance Criteria:
- **Scenario:** Nothing to send
- **Given:** the Mac build and an empty bar
- **When:** I press Enter
- **Then:** nothing sends and no blank message appears

---

### User Story 678:

- **Summary:** Confirm a short form on the Mac with Enter
- **Status:** implemented on branch native/mac-send-keys (#683); the Mac build compiles. Not yet verified by pressing the keys on a Mac (the unsigned test runner refuses the UI test; Igor checks by hand)
- **Issues:** [#683](https://github.com/idvorkin/context-grabber/issues/683)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, typing a name on the Mac
- **I want** Enter to confirm it
- **so that** every place I type on the Mac finishes the same way

#### Acceptance Criteria:
- **Scenario:** Confirming a form
- **Given:** the Mac build, and renaming a board, adding a place or naming one, with what it needs filled in
- **When:** I press Enter
- **Then:** it does what its button does

---

### User Story 681:

- **Summary:** Enter on a Mac form missing what it needs does nothing
- **Status:** implemented on branch native/mac-send-keys (#683); the Mac build compiles. Not yet verified by pressing the keys on a Mac (the unsigned test runner refuses the UI test; Igor checks by hand)
- **Issues:** [#683](https://github.com/idvorkin/context-grabber/issues/683)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, pressing Enter on a half-filled form on the Mac
- **I want** the form to wait for what it needs
- **so that** nothing half made is added and I don't lose what I typed

#### Acceptance Criteria:
- **Scenario:** A form missing what it needs
- **Given:** the Mac build and adding a place with no name
- **When:** I press Enter
- **Then:** nothing is added and what I typed stays

---

### User Story 682:

- **Summary:** Send a problem report's note from the Mac with Command+Enter
- **Status:** the report dialog's own behaviour, unchanged by #683. Not yet verified by pressing the keys on a Mac (Igor checks by hand)
- **Issues:** [#683](https://github.com/idvorkin/context-grabber/issues/683)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, writing a long problem report on the Mac
- **I want** Command+Enter to send it while Enter starts a new line
- **so that** a long note keeps its lines and still sends from the keyboard

#### Acceptance Criteria:
- **Scenario:** A problem report's note
- **Given:** the Mac build, the report dialog open and a note typed
- **When:** I press Command+Enter
- **Then:** the report sends

### User Story 684:

- **Summary:** Report a problem from the Mac's menu bar
- **Status:** implemented on branch native/mac-menu (#681); the Mac build compiles. Not yet verified by choosing the item from a Mac's menu bar
- **Issues:** [#681](https://github.com/idvorkin/context-grabber/issues/681)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac, which can't be shaken
- **I want** a problem report in the menu bar
- **so that** I can report what I see without a shake

#### Acceptance Criteria:
- **Scenario:** Reporting a problem
- **Given:** the Mac build is open on any screen
- **When:** I choose Report a Problem… from the Help menu
- **Then:** the report dialog opens, as a shake opens it on a phone

### User Story 685:

- **Summary:** Open Settings from the Mac's menu bar
- **Status:** implemented on branch native/mac-menu (#681); the Mac build compiles. Not yet verified by choosing the item from a Mac's menu bar
- **Issues:** [#681](https://github.com/idvorkin/context-grabber/issues/681)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac
- **I want** Settings… in the app's menu, with Command+Comma
- **so that** I change a setting the way every Mac app lets me, without hunting for a tile

#### Acceptance Criteria:
- **Scenario:** Opening Settings
- **Given:** the Mac build is open on home, with no other screen covering it (Settings… is dimmed while one does)
- **When:** I choose Settings… from the app's menu, or press Command+Comma
- **Then:** the app's settings open over home

### User Story 722:

- **Summary:** Keyboard shortcuts on the Mac: the Go menu
- **Status:** implemented in [c6977e4](https://github.com/idvorkin/context-grabber/commit/c6977e4); verified by the Mac build (it compiles), not yet by pressing the keys on a Mac
- **Issues:** [#722](https://github.com/idvorkin/context-grabber/issues/722)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac with a keyboard under my hands
- **I want** keys for the places I go, listed in a Go menu in the menu bar
- **so that** I get there without reaching for the trackpad, and can look up a key I forgot

#### Acceptance Criteria:
- **Scenario:** Going to a home destination
- **Given:** the Mac build is open on home, with no other screen, sheet or report dialog covering it
- **When:** I press Command+1 through Command+9, or choose a destination from the Go menu
- **Then:** that destination opens, as a tap on its tile would, and the Go menu lists them in the order home shows them,
  the Today card first when it is shown

### User Story 723:

- **Summary:** The Go menu follows home
- **Status:** implemented in [c6977e4](https://github.com/idvorkin/context-grabber/commit/c6977e4); verified by the Mac build (it compiles), not yet by pressing the keys on a Mac
- **Issues:** [#722](https://github.com/idvorkin/context-grabber/issues/722)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac with a keyboard under my hands
- **I want** the Go menu to match home as I have arranged it
- **so that** its numbers mean the same tiles I see on home

#### Acceptance Criteria:
- **Scenario:** The Go menu follows home
- **Given:** I have hidden or moved a tile in Settings
- **When:** I open the Go menu
- **Then:** the hidden tile is gone from it, the moved one is in its new place, and the numbers follow

### User Story 724:

- **Summary:** New Board by key on the Mac
- **Status:** implemented in [c6977e4](https://github.com/idvorkin/context-grabber/commit/c6977e4), changed in [66bdf33](https://github.com/idvorkin/context-grabber/commit/66bdf33) (Command+N no longer New Window); verified on the Mac (rung 1.5): File > New Board reads Shift+Command+N in the app's menu; not yet pressed by a person
- **Issues:** [#722](https://github.com/idvorkin/context-grabber/issues/722), [#745](https://github.com/idvorkin/context-grabber/issues/745)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac with a keyboard under my hands
- **I want** a key and a File menu item that start a new whiteboard board
- **so that** I can sketch something the moment I think of it

#### Acceptance Criteria:
- **Scenario:** A new board
- **Given:** the Mac build is open on home, or on the whiteboard
- **When:** I press Command+Shift+N, or choose New Board from the File menu
- **Then:** the whiteboard opens on a new empty board

### User Story 725:

- **Summary:** Report a Problem by key on the Mac
- **Status:** implemented in [c6977e4](https://github.com/idvorkin/context-grabber/commit/c6977e4), changed in [ae8c438](https://github.com/idvorkin/context-grabber/commit/ae8c438) and [5a6bff7](https://github.com/idvorkin/context-grabber/commit/5a6bff7); verified by the Mac build (it compiles), not yet by pressing the keys on a Mac
- **Issues:** [#722](https://github.com/idvorkin/context-grabber/issues/722), [#745](https://github.com/idvorkin/context-grabber/issues/745), [#741](https://github.com/idvorkin/context-grabber/issues/741)
- **Spec:** [Grabber Native on the Mac — Control+R and Command+N](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac with a keyboard under my hands
- **I want** a key for Report a Problem…
- **so that** I can report what just went wrong without leaving the keyboard

#### Acceptance Criteria:
- **Scenario:** Reporting a problem by key
- **Given:** the Mac build is open on any screen
- **When:** I press Command+Shift+R, or Control+R
- **Then:** the report dialog opens over that screen, as Report a Problem… in the app menu (and the Help menu) opens it

### User Story 726:

- **Summary:** The Go keys never close a live screen
- **Status:** implemented in [c6977e4](https://github.com/idvorkin/context-grabber/commit/c6977e4), changed in [ae8c438](https://github.com/idvorkin/context-grabber/commit/ae8c438), [5a6bff7](https://github.com/idvorkin/context-grabber/commit/5a6bff7) and [66bdf33](https://github.com/idvorkin/context-grabber/commit/66bdf33) (New Chat on Command+N); verified by the Mac build (it compiles), not yet by pressing the keys on a Mac
- **Issues:** [#722](https://github.com/idvorkin/context-grabber/issues/722), [#745](https://github.com/idvorkin/context-grabber/issues/745)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac with a keyboard under my hands
- **I want** the Go keys to do nothing while another screen is in front
- **so that** a timer or a call I have running is never closed by a stray key

#### Acceptance Criteria:
- **Scenario:** Another screen is in front
- **Given:** a timer, a call, the settings, What's new, the report dialog or any other screen covers home
- **When:** I open the Go menu, or press one of its keys
- **Then:** its items are dimmed and nothing happens, so nothing live is closed; New Board is dimmed too, unless home or
  the whiteboard is the screen in front, and New Chat (Command+N), unless home or chat is in
  front, or chat has a window of its own; *Report a problem* stays live (story 730)

### User Story 727:

- **Summary:** No Mac menus on a phone or an iPad
- **Status:** implemented in [c6977e4](https://github.com/idvorkin/context-grabber/commit/c6977e4); verified by the Mac build (it compiles), not yet by pressing the keys on a Mac
- **Issues:** [#722](https://github.com/idvorkin/context-grabber/issues/722)
- **Spec:** [Grabber Native on the Mac](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, using the app on a Mac with a keyboard under my hands
- **I want** the phone and the iPad to stay as they are
- **so that** the Mac's menus and keys add nothing I have to learn there

#### Acceptance Criteria:
- **Scenario:** A phone and an iPad
- **Given:** the app on an iPhone, or on an iPad with a hardware keyboard
- **When:** I look for these menus or press these keys
- **Then:** nothing new is there: the menu and its keys are the Mac's alone

### User Story 730:

- **Summary:** Report a problem from the menu on any screen, on the Mac
- **Status:** implemented in [ae8c438](https://github.com/idvorkin/context-grabber/commit/ae8c438); `MacGoMenuTests` (host) pass and the Mac build compiles; not yet chosen from the menu on the Mac
- **Issues:** [#783](https://github.com/idvorkin/context-grabber/issues/783)
- **Spec:** [Grabber Native on the Mac — Reporting from any screen](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, in chat or any other screen of the app on the Mac, having just seen something wrong
- **I want** to open the problem report from the menu bar where I look for it
- **so that** I report it from where it happened, with that screen in the report, instead of going back home to the tile

#### Acceptance Criteria:
- **Scenario:** Reporting from chat by the menu
- **Given:** the Mac build with chat (or a timer, Places, the whiteboard) in front of home
- **When:** I choose *Report a problem* in the Go menu, or *Report a Problem…* in the app menu, or press Command+Shift+R
- **Then:** the report dialog opens over that screen with its screenshot, and nothing in front is closed; the other Go
  items stay dimmed

### User Story 734:

- **Summary:** A new chat by key from anywhere on the Mac
- **Status:** implemented in [5a6bff7](https://github.com/idvorkin/context-grabber/commit/5a6bff7), changed in [66bdf33](https://github.com/idvorkin/context-grabber/commit/66bdf33); `MacGoMenuTests` (host) pass and the Mac build compiles; on the Mac (rung 1.5) the File menu reads New Chat Command+N, New Window Option+Command+N, New Board Shift+Command+N, and choosing New Chat by accessibility logged `open_new_chat` from mac_menu and opened chat; the key not yet pressed by a person
- **Issues:** [#745](https://github.com/idvorkin/context-grabber/issues/745)
- **Spec:** [Grabber Native on the Mac — Control+R and Command+N](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, on the Mac with a thought for Larry
- **I want** Command+N to open a new chat wherever I am
- **so that** I start the conversation from the keyboard without finding chat's tile and its +

#### Acceptance Criteria:
- **Scenario:** A new chat from home
- **Given:** the Mac build is open on home
- **When:** I press Command+N, or choose New Chat from the File menu
- **Then:** chat opens on a new empty chat, as its + would, ready to type

### User Story 735:

- **Summary:** A new chat by key from chat on the Mac
- **Status:** implemented in [5a6bff7](https://github.com/idvorkin/context-grabber/commit/5a6bff7), changed in [66bdf33](https://github.com/idvorkin/context-grabber/commit/66bdf33); `MacGoMenuTests` (host) pass and the Mac build compiles; on the Mac (rung 1.5) the File menu reads New Chat Command+N, New Window Option+Command+N, New Board Shift+Command+N, and choosing New Chat by accessibility logged `open_new_chat` from mac_menu and opened chat; the key not yet pressed by a person
- **Issues:** [#745](https://github.com/idvorkin/context-grabber/issues/745)
- **Spec:** [Grabber Native on the Mac — Control+R and Command+N](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, reading a thread in chat on the Mac
- **I want** Command+N to start another chat right there
- **so that** a new subject gets its own thread without reaching for the mouse

#### Acceptance Criteria:
- **Scenario:** A new chat from chat
- **Given:** chat is in front, in the home window or in a window of its own
- **When:** I press Command+N
- **Then:** a new empty chat opens there

### User Story 736:

- **Summary:** Command+T opens a new chat on the Mac too
- **Status:** implemented in [7395b8e](https://github.com/idvorkin/context-grabber/commit/7395b8e); on the Mac (rung 1.5) the File menu reads New Chat Command+N, New Thread Command+T, New Window Option+Command+N, and Command+T pressed through System Events logged `open_new_chat` from `mac_menu_new_thread` from home and again from chat, with Command+N still logging `open_new_chat`; not yet pressed by a person
- **Issues:** [#1046](https://github.com/idvorkin/context-grabber/issues/1046), bead context-grabber-kupi
- **Spec:** [Grabber Native on the Mac — Command+T is New Chat too](../superpowers/specs/2026-11-03-native-mac-app-design.md)

#### Use Case:
- **As** Igor, on the Mac, whose fingers reach for Command+T for a new thread as often as Command+N
- **I want** Command+T to open a new chat just as Command+N does
- **so that** either "new" key starts the thread, and neither has to be remembered over the other

#### Acceptance Criteria:
- **Scenario:** Command+T opens a new chat
- **Given:** home or chat is in front, or chat has a window of its own
- **When:** I press Command+T, or choose New Thread from the File menu
- **Then:** a new empty chat opens, as Command+N would, and Command+N still opens one too

### User Story 731:

- **Summary:** A new window lets me choose what it shows
- **Status:** implemented in [c02ddeb](https://github.com/idvorkin/context-grabber/commit/c02ddeb), moved to Option+Command+N in [66bdf33](https://github.com/idvorkin/context-grabber/commit/66bdf33); `WindowOfferTests` (host) pass and the Mac build compiles; on the Mac (rung 1.5) File > New Window reads Option+Command+N and, chosen by accessibility with home up, logged `new_window` then `extra_home` with two scenes (the chooser); not yet pressed by a person, nor the iPad's New Window
- **Issues:** [#782](https://github.com/idvorkin/context-grabber/issues/782), [#745](https://github.com/idvorkin/context-grabber/issues/745)
- **Spec:** [Windows on the iPad — Another window of the app](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor, on the Mac with the app's home window open
- **I want** File > New Window (Option+Command+N) to start on a short home where I pick what the window shows
- **so that** I can put Chat, Today, a board or the Cockpit beside home without hunting for a tile to hold

#### Acceptance Criteria:
- **Scenario:** Choosing Chat in a new window
- **Given:** the home window is open and no Chat window is
- **When:** I press Option+Command+N and choose Chat
- **Then:** the window becomes the Chat window, named Chat; it offered only the screens home shows that can have a window,
  in home's order; had Chat already been in a window, that window would have come forward and this one closed

---

### User Story 826:

- **Summary:** A new window's menu offers only what can have a window
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WindowOfferTests`) and the Mac build; the simulator and the iPad still to do
- **Issues:** [#870](https://github.com/idvorkin/context-grabber/issues/870) (Igor asked why the new-window menu didn't list everything; Igor, 2026-11-14: only the six that can have their own window)
- **Spec:** [Windows on the iPad — Another window of the app](../superpowers/specs/2026-11-03-ipad-windows-design.md)

#### Use Case:
- **As** Igor, opening another window of the app on the iPad
- **I want** its menu to list only the screens that can have a window of their own, and to say where the others are
- **so that** nothing in it would fight the home window for the audio, and I know why the timer isn't there

#### Acceptance Criteria:
- **Scenario:** The menu of a new window
- **Given:** home is open in one window and shows every tile
- **When:** I open a new window of the app
- **Then:** its menu lists Today, Chat, the Cockpit, Places, the Whiteboard and the card, in home's order, and not the Gym Timer, Box breathing, the call or the Workout Supermix; its footnote says those stay in the home window

---

### User Story 732:

- **Summary:** Tap the Live Activity to get back to a workout I left
- **Status:** native app only: implemented in [e5d4897](https://github.com/idvorkin/context-grabber/commit/e5d4897); verified by `just test` (lint + host) and the simulator's `GymTimerUITests` and `LinksUITests`; the card on the lock screen and its tap still to be checked by Igor on the phone
- **Issues:** #791
- **Spec:** [Native Live Activity — When it goes away, The tap](../superpowers/specs/2026-10-04-native-live-activity-design.md)

#### Use Case:
- **As a** lifter who pressed *Done* on a running workout to look at something else in the app
- **I want to** tap the Live Activity and land on that same workout
- **so that** the card is always the way back to the clock that is counting

#### Acceptance Criteria:
- **Scenario:** From the island back to a workout I left
- **Given:** a rounds timer is running, I pressed *Done* and am on another screen, and the Live Activity still counts down
- **When:** I tap the Live Activity
- **Then:** whatever is in front gives way and the Gym Timer comes up with the same workout still running at the right time, in the mode I left it in — not restarted and not another preset

---

### User Story 733:

- **Summary:** The Live Activity stays while a workout runs off the timer's screen
- **Status:** native app only: implemented in [e5d4897](https://github.com/idvorkin/context-grabber/commit/e5d4897); verified by `just test` (lint + host) and the simulator's `GymTimerUITests` and `LinksUITests`; the card on the lock screen and its tap still to be checked by Igor on the phone
- **Issues:** #791
- **Spec:** [Native Live Activity — When it goes away, The tap](../superpowers/specs/2026-10-04-native-live-activity-design.md)

#### Use Case:
- **As a** lifter with a workout running while I look elsewhere in the app
- **I want** the lock-screen card and the island to keep counting
- **so that** I can read the round and the time left without going back to the timer

#### Acceptance Criteria:
- **Scenario:** The card while I look elsewhere
- **Given:** a rounds timer is running
- **When:** I press *Done* and stay in the app
- **Then:** the card stays on the lock screen and the island and keeps moving from phase to phase, until that workout is paused (story 191), reset, or finished and shown its few minutes
