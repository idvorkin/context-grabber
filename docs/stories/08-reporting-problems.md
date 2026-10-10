# Reporting problems

Getting something that went wrong in front of the developer with the evidence attached. These stories are about
the native app ([design spec](../superpowers/specs/2026-10-04-swift-native-app-design.md)); the current app's
logs are described in [DEBUGGING.md](../DEBUGGING.md).

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 140:

- **Summary:** The native app lives beside the current one
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified on the simulator (`just native-test-sim`: installs, launches, logs `session_start`) and on the phone (2026-10-04, installed beside Context Grabber and opened); the commit and branch moved behind the home screen's cog: [80b7186](https://github.com/idvorkin/context-grabber/commit/80b7186), verified on the simulator (screenshot of the sheet)

#### Use Case:
- **As someone** who depends on the current app every day
- **I want to** have the native app installed next to it under its own name
- **so that** I can try each ported journey without losing the app that works

#### Acceptance Criteria:
- **Scenario:** Installing the native build
- **Given:** Context Grabber is on the phone with its data
- **When:** the native build is installed and opened
- **Then:** a second app named "Grabber Native" opens on its home screen, whose cog shows the commit and branch it was built from, and Context Grabber still opens with its data untouched

---

### User Story 141:

- **Summary:** Every launch keeps a log (technical)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified by host tests (`SessionLogLineTests`) and on the simulator (`just native-test-sim` reads `session_start`)

#### Use Case:
- **As a** developer asked "why did it do that"
- **I want to** read what the app did in that launch, with numbers
- **so that** a symptom is explained from evidence instead of a theory

#### Acceptance Criteria:
- **Scenario:** A launch
- **Given:** the native app is installed
- **When:** I open it
- **Then:** a new log file for this launch exists in the app's Documents folder (visible in Files), its first line names the device, the system, the commit and the branch, every later line carries its type and the milliseconds since launch, and `just pull-logs` brings it to the Mac

---

### User Story 142:

- **Summary:** Report a problem in five seconds with the evidence attached
- **Issues:** [#182](https://github.com/idvorkin/context-grabber/issues/182) (a shake did nothing while a sheet was up), [#239](https://github.com/idvorkin/context-grabber/issues/239) (speak the note)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified on the simulator (`GRABBER_BUG` hook: the report, its screenshot and the log's name are written) and on the phone (2026-10-04: a shake, a note, the report and its screenshot pulled back); over a sheet (#182): [19f4b7c](https://github.com/idvorkin/context-grabber/commit/19f4b7c), verified by `ShakeOverSheetUITests` on the simulator (the report twice over the cog's sheet, the sheet still there after Cancel; the log's `over`); a real shake over a dialog on the phone not yet; *Log it and another* [a85e228](https://github.com/idvorkin/context-grabber/commit/a85e228), verified by `LogItAndAnotherUITests` on the simulator (two reports stored, each with its own note and picture, the second opened empty with no shake). Speak the note (#239): [3c4f13d](https://github.com/idvorkin/context-grabber/commit/3c4f13d); verified by `ReportDictationUITests` on the simulator (the mic button sits beside the note, on with no call) and its screenshot read by eye; the permission prompts, the spoken words, the music carrying on and the button off during a call are the phone's to check, not yet

#### Use Case:
- **As someone** who just saw the app do something wrong
- **I want to** shake the phone, type one line, and move on
- **so that** the developer gets the screen, the build and the session log without me explaining

#### Acceptance Criteria:
- **Scenario:** A shake
- **Given:** the native app is open on any screen
- **When:** I shake the phone, type "timer skipped the rest" and tap Log it
- **Then:** the report is stored with my note, a picture of the screen as it was at the shake, the screen's name, the build, and the name of this launch's log with the moment in it, and the screen says "Problem logged"

- **Scenario:** Several in a row
- **Given:** a report is open with a note typed
- **When:** I tap *Log it and another*, type a second note and tap *Log it*
- **Then:** two reports are stored, each with its own note and picture, and the second report opened empty without another shake

- **Scenario:** Speaking the note
- **Given:** the report is open, with or without words typed, and no call is up
- **When:** I tap the microphone and say "the timer skipped the rest", then tap it again
- **Then:** the words appear in the note as I say them, after anything I had typed; music that was playing keeps playing; the log has `dictation_start` and `dictation_stop`; and during a call the microphone button is off

- **Scenario:** A shake over a dialog
- **Given:** a sheet is up — the home screen's cog, Today's settings, the timer's settings, a Places naming sheet
- **When:** I shake the phone, then cancel; and shake again
- **Then:** the report opens over the sheet each time, its picture shows the sheet, and after Cancel or Log it the sheet is still there; the log's `ui` report_problem says what it opened over

---

### User Story 143:

- **Summary:** A report becomes a GitHub issue once (technical)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); `just bugs-check` verified against the phone (2026-10-04, it found the one unfiled report); `just file-bugs` has not filed a real report yet; the issue names the screenshot's path on the Mac and uploads no picture: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by running the script's body against a sample report; a failed look at the existing issues stops the filing instead of filing everything again: [6fed157](https://github.com/idvorkin/context-grabber/commit/6fed157), verified by running the script against a `gh` that fails (it exits before filing); a note that starts with a blank line is titled by its first line with words and no longer stops the filing: [002e088](https://github.com/idvorkin/context-grabber/commit/002e088), verified by running the script against a stand-in `gh`; the iPad as well as the phone (`pull-logs`, `bugs-check`, `file-bugs`, each device in its own folder, the issue saying which): [72d9fe7](https://github.com/idvorkin/context-grabber/commit/72d9fe7), verified against both devices on 2026-10-10 (it found and filed the iPad's five reports and the phone's three, then reported none left)

#### Use Case:
- **As a** developer with the phone near the Mac
- **I want to** have every new report filed as an issue with its note and context, and told where its screenshot is on the Mac
- **so that** nothing Igor reported is lost, nothing is filed twice, and no picture of his health, places or journal lands in a public issue

#### Acceptance Criteria:
- **Scenario:** Filing after a session at the gym
- **Given:** two reports are on the phone and one of them is already an issue
- **When:** I run `just pull-logs` and `just file-bugs`
- **Then:** exactly one new issue is created, carrying the note, the screen, the build, the log's name and the screenshot's path under `~/tmp/agent/grabber-logs/` on the Mac, no picture is uploaded anywhere, and running `just file-bugs` again creates none

---

### User Story 144:

- **Summary:** A crash comes back with the logs (technical)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified by build only — the first real crash will verify it; one file per crash (the abort after an exception writes no second file) and a crash the app could not record still reaches the system's own report: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by build only

#### Use Case:
- **As a** developer reading a session log that stops mid-work
- **I want to** get the crash's reason and stack from the phone with the same pull as the logs
- **so that** a crash is diagnosed from evidence like any other report

#### Acceptance Criteria:
- **Scenario:** The launch after a crash
- **Given:** the native app crashed
- **When:** it is opened again and I run `just pull-logs`
- **Then:** the new launch's log has one `crash_report` line naming a file under `crashes/` with the signal or exception and its stack, the file is pulled with the logs, and a later launch does not announce it again

---

### User Story 145:

- **Summary:** Old logs do not pile up, reported ones stay (technical)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified by host tests (`LogRetentionTests`)

#### Use Case:
- **As someone** whose phone storage is not for log files
- **I want to** have logs older than thirty days deleted
- **so that** the app's footprint stays small while the evidence for an open report survives

#### Acceptance Criteria:
- **Scenario:** A launch with old logs
- **Given:** the Documents folder holds a 40-day-old log no report names and a 40-day-old log a report names
- **When:** I open the app
- **Then:** the first is deleted, the second is kept, and the new log has one `logs_pruned` line with the count, the bytes freed and how many were kept for reports
---

### User Story 146:

- **Summary:** A gentle shake opens the report, not only a hard one
- **Status:** native app only: implemented in [29347c8](https://github.com/idvorkin/context-grabber/commit/29347c8); verified by `ShakeGestureTests` (host: a light 1.8 g shake counts; one push, a 0.5 Hz sway and a 1 g jiggle do not; one sheet per shake); the threshold on the phone still to be checked by Igor (the simulator has no accelerometer)
- **Issues:** [#164](https://github.com/idvorkin/context-grabber/issues/164)
- **Spec:** [Swift-native app — a gentle shake is enough](../superpowers/specs/2026-10-04-swift-native-app-design.md)

#### Use Case:
- **As** the person reporting problems from the phone many times a day
- **I want to** open the report with a quick, gentle shake
- **so that** reporting stays a reflex and not a workout

#### Acceptance Criteria:
- **Scenario:** A quick back-and-forth
- **Given:** Grabber Native is open on any screen
- **When:** I give the phone a quick, light shake — three flicks — that iOS's own shake would ignore
- **Then:** the report sheet opens once, and the session log has `shake` with source motion and the peak force; walking with the phone in my hand or setting it on the bench opens nothing

---

### User Story 147:

- **Summary:** The home screen holds only what I open, and a cog holds the rest
- **Issues:** [#166](https://github.com/idvorkin/context-grabber/issues/166)
- **Status:** native app: implemented in [80b7186](https://github.com/idvorkin/context-grabber/commit/80b7186) ([spec](../superpowers/specs/2026-10-06-native-home-screen-design.md)); verified by host tests (`HomeLayoutTests`) and on the simulator (`HomeSettingsUITests`: Cockpit hidden and Gym Timer moved to the top through the cog, both still so after a relaunch, Reset puts them back; the log's `ui` home_settings / home_rows lines; screenshots of the home screen and the sheet); the phone still to be checked by Igor; no title, verified by a simulator screenshot: [adfed5a](https://github.com/idvorkin/context-grabber/commit/adfed5a); no bar and the cog in the bottom corner [aa18183](https://github.com/idvorkin/context-grabber/commit/aa18183), verified by `HomeSettingsUITests` and a simulator screenshot

#### Use Case:
- **As someone** who opens the native app to start a workout, a call or a breath, not to read its build number
- **I want to** see only the launchers I use, in my order, with the diagnostics one tap away behind a cog
- **so that** the thing I came for is the first thing under my thumb

#### Acceptance Criteria:
- **Scenario:** Hiding a launcher
- **Given:** the home screen shows Call Larry, Today, Gym Timer, Box breathing, Places, Think of a card and Cockpit, with a cog in the bottom right corner and nothing below them
- **When:** I tap the cog, turn off Cockpit's switch, tap Done and later relaunch the app
- **Then:** Cockpit is gone from the home screen and stays gone after the relaunch, and the log has `ui` home_settings and a `ui` home_rows line naming the order and `cockpit` as hidden

- **Scenario:** Moving a launcher
- **Given:** the Home screen sheet is open
- **When:** I drag Gym Timer to the top and relaunch the app
- **Then:** Gym Timer is the first row on the home screen, before and after the relaunch

- **Scenario:** A launcher added by a later build
- **Given:** I have reordered and hidden rows in an earlier build
- **When:** a build with a new launcher is installed
- **Then:** my order and hidden rows are kept and the new launcher shows at the end

- **Scenario:** The diagnostics, out of the way
- **Given:** I need the build, this launch's log, the gist token or *Report a problem*
- **When:** I tap the cog
- **Then:** they are under *About and diagnostics* in the sheet, as they were on the home screen, and a shake with the sheet up still opens a report naming the screen *home_settings*


- **Scenario:** No title
- **Given:** the app is open on its home screen
- **When:** I look at the top
- **Then:** there is no *Grabber Native* title and no empty bar: the usage card starts just under the status bar, and the cog is in the bottom right corner

---

### User Story 148:

- **Summary:** What's new, by day, written by the build itself
- **Issues:** [#165](https://github.com/idvorkin/context-grabber/issues/165), [#232](https://github.com/idvorkin/context-grabber/issues/232), [#246](https://github.com/idvorkin/context-grabber/issues/246)
- **Status:** native app: implemented in [f3d2758](https://github.com/idvorkin/context-grabber/commit/f3d2758) ([spec](../superpowers/specs/2026-10-06-native-whats-new-design.md)); verified by host tests (`WhatsNewTests`, including every real story file) and on the simulator (screenshots of the row and the screen listing Oct 5 and Oct 4 from this checkout's history; the log's `ui` open_whats_new with 2 days and 8 changes); the phone still to be checked by Igor; the ✕ and the cog's row verified by `WhatsNewSeenUITests` and `WhatsNewTests` on the simulator: [adfed5a](https://github.com/idvorkin/context-grabber/commit/adfed5a). Each change opens its story (#232): [5227ba9](https://github.com/idvorkin/context-grabber/commit/5227ba9); verified by `WhatsNewTests` (host: the link to the story's own heading, every real story file, an older feed without links) and `WhatsNewStoryLinkUITests` on the simulator (a tap opens Safari). A commit naming its story only in its message or through its issue still shows (#246): [6b1d0aa](https://github.com/idvorkin/context-grabber/commit/6b1d0aa); verified by `WhatsNewTests` (host) and the build script run on this repository's history (newest day Oct 10 rather than Oct 7: 6 days, 41 changes)

#### Use Case:
- **As someone** who installs a new build of the native app most days
- **I want to** see what each recent day's builds changed, in plain words, newest first
- **so that** I remember what to try, and nobody has to keep a list up to date

#### Acceptance Criteria:
- **Scenario:** The latest change on the home screen
- **Given:** the build was made from history whose newest story change, on Oct 5, is *Think of a card opens Igor's Think a Card Trainer*
- **When:** I open the app
- **Then:** the home screen shows *What's new · Oct 5 — Think of a card opens Igor's Think a Card Trainer* above the launchers

- **Scenario:** The list by day
- **Given:** the last thirty days hold story changes on several days, some with status follow-ups and merges
- **When:** I tap *What's new*
- **Then:** I see one section per day, newest first, each change once per story per day with its story and issue under it, no status or merge lines, and the log has `ui` open_whats_new; a change whose title names no story is still there when its message names the story or its issue belongs to one

- **Scenario:** A change opens its story
- **Given:** What's new is open
- **When:** I tap a change
- **Then:** its user story opens on GitHub in Safari, at that story, and the log has `ui` open_story with the story and the address

- **Scenario:** Nothing to show
- **Given:** a build made without the project's history, or with no story change in thirty days
- **When:** I open the app and the cog's *What's new*
- **Then:** the home screen has no What's new row, and *What's new* in the cog's sheet says there is nothing new, with no error

- **Scenario:** Dismissed with its ✕, kept in the cog
- **Given:** the home screen shows *What's new* after a new build
- **When:** I open it and come back, then tap its ✕, then relaunch the app
- **Then:** opening leaves the row on the home screen; the ✕ removes it and the relaunch does not bring it back until a build with a newer change; *What's new* in the cog's sheet still opens the list, and the log has `ui` dismiss_whats_new

---

### User Story 149:

- **Summary:** Reset audio from the cog when the phone's sound gets stuck
- **Status:** native app only: implemented in [d2f5fe6](https://github.com/idvorkin/context-grabber/commit/d2f5fe6); verified by `ResetAudioUITests` on the simulator (the cog's Reset audio shows the route before and after; the log's `audio_reset` went SoloAmbient → Ambient with nothing refused); stuck music on the phone still to be checked by Igor
- **Spec:** [Swift-native app — reset audio](../superpowers/specs/2026-10-04-swift-native-app-design.md)

#### Use Case:
- **As** someone whose music stays ducked or whose sound goes to the wrong place after a call or a workout
- **I want to** tap Reset audio in the home screen's cog
- **so that** the phone's sound is back without hunting through apps or restarting the phone

#### Acceptance Criteria:
- **Scenario:** Music left ducked
- **Given:** no call is live and another app's music is playing quieter than it should after a workout
- **When:** I tap *Reset audio*
- **Then:** Grabber Native lets go of the audio and tells other apps to resume, the line under the button shows the route before and after, the session log has `audio_reset` with both, and while a call is live the button is not offered

---

### User Story 150:

- **Summary:** Grabber Native on the iPad
- **Issues:** [#202](https://github.com/idvorkin/context-grabber/issues/202), [#203](https://github.com/idvorkin/context-grabber/issues/203)
- **Status:** implemented in [2c2a6ee](https://github.com/idvorkin/context-grabber/commit/2c2a6ee); verified by `IPadUITests` on an iPad Air 11-inch simulator (home spans the width in landscape; Call, Today, Gym Timer, Box breathing, Places and Cockpit open in landscape, screenshots checked) and a portrait screenshot; on Igor's iPad not yet (its id is not in the provisioning profile until Xcode is signed in)
- **Spec:** [Swift-native app, "On the iPad"](../superpowers/specs/2026-10-04-swift-native-app-design.md)

#### Use Case:
- **As someone** with an iPad on the desk beside the phone
- **I want to** run Grabber Native there as a real iPad app
- **so that** calls, the timer, breathing and the Cockpit are on the bigger screen when it is the one in reach

#### Acceptance Criteria:
- **Scenario:** An iPad app, any way up
- **Given:** Grabber Native installed on the iPad
- **When:** I open it, turn the iPad to landscape and back, and open each launcher
- **Then:** the home screen fills the iPad's screen in both orientations (not a phone-sized window), and every launcher opens its screen without an error

---

### User Story 151:

- **Summary:** The home screen opens on today, not on a list
- **Issues:** [#189](https://github.com/idvorkin/context-grabber/issues/189), [#225](https://github.com/idvorkin/context-grabber/issues/225), [#227](https://github.com/idvorkin/context-grabber/issues/227), [#235](https://github.com/idvorkin/context-grabber/issues/235)
- **Status:** implemented in [5046a38](https://github.com/idvorkin/context-grabber/commit/5046a38); verified by `HomeLayoutTests` (host) and `HomeTodayCardUITests`, `HomeSettingsUITests`, `WhatsNewSeenUITests` on the simulator (the card from the fixture week: 6.8h, 2,631 steps, 22.4 ms, 55 min, as of its time; Call, Gym Timer, Box breathing and Places two by two; moving Gym Timer first puts its tile first); on the phone not yet. One-line tiles and the two shared lines (#225): [b90f918](https://github.com/idvorkin/context-grabber/commit/b90f918); verified by `HomeLayoutTests` (host) and `HomePairsUITests` on the simulator (tiles under 80 points tall; Exercise Analyzer beside Workout Supermix, Eulogy beside Eulogy song; the song's half opens the song). Each launcher's colour on its icon square, names in the text colour at one size, *Analyzer* and *Supermix* in half a line (#227): [43cdc3f](https://github.com/idvorkin/context-grabber/commit/43cdc3f); verified by `HomePairsUITests` on the simulator and its screenshot read by eye. Every launcher a tile, the pairs the size of the four's and a lone launcher the width of two (#235): [26a92ba](https://github.com/idvorkin/context-grabber/commit/26a92ba); verified by `HomePairsUITests` on the simulator (widths, heights and left edges against the four's) and its screenshot read by eye
- **Spec:** [native home screen, "Not just a list"](../superpowers/specs/2026-10-06-native-home-screen-design.md)

#### Use Case:
- **As someone** who opens the app many times a day
- **I want to** see how I am doing at a glance, with the things I do daily as big targets
- **so that** the home screen is the mirror, not a menu

#### Acceptance Criteria:
- **Scenario:** The Today card and the tiles
- **Given:** the app has grabbed at least once
- **When:** I open the app
- **Then:** a Today card shows sleep, steps, HRV and exercise from the last grab with when it was read, the first four launchers (Today aside) are one-line tiles two by two, and the rest are tiles of the same look below them: Exercise Analyzer and Workout Supermix two tiles on one line, Eulogy and Eulogy song two on another, each the size of the four's, and every other launcher one tile the width of two, and no Health prompt appears

- **Scenario:** Before any grab
- **Given:** a fresh install
- **When:** I open the app and tap the card
- **Then:** the card says *Today — tap to look*, and Today opens and grabs


---

### User Story 246:

- **Summary:** A daily strip: gym, journal, balloons and magic, at a glance
- **Issues:** [#236](https://github.com/idvorkin/context-grabber/issues/236), [#238](https://github.com/idvorkin/context-grabber/issues/238)
- **Status:** implemented in COMMIT; verified by `DailyStripTests` and `HomeLayoutTests` (host: values by day, never below 0, gym days from a tap, the timer or a strength workout, days since gym across the clock change) and `DailyStripUITests` on the simulator (above the tiles, one line, a tap adds a balloon, a long press takes one off, the journal check flips and back); a Gym Timer workout or a Health strength workout checking gym on the phone not yet
- **Spec:** [native home screen, "The daily strip"](../superpowers/specs/2026-10-06-native-home-screen-design.md)

#### Use Case:
- **As someone** with a few things I mean to do every day: the gym, my journal, balloons and magic for others
- **I want to** see at a glance which are done today, and mark them with one tap
- **so that** the home screen holds the days up to me, including how long since the gym

#### Acceptance Criteria:
- **Scenario:** Checks and counts
- **Given:** the home screen, with the strip under the Today card
- **When:** I tap Journal, tap Balloons twice and long-press it once, and tap Magic
- **Then:** Journal shows a green check, Balloons shows 1, Magic shows 1, all on one tight line, and the log has `ui` daily_strip for each change

- **Scenario:** Days since gym
- **Given:** my last gym day was three days ago
- **When:** I open the app
- **Then:** the kettlebell is grey with *3d*; after I finish a Gym Timer workout (or Health records a strength workout, or I tap it) it turns green with a check

- **Scenario:** A new day
- **Given:** yesterday's strip had a check and counts
- **When:** midnight passes
- **Then:** the strip starts fresh, and yesterday's values are kept
