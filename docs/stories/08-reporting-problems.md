# Reporting problems

Getting something that went wrong in front of the developer with the evidence attached. These stories are about
the native app ([design spec](../superpowers/specs/2026-10-04-swift-native-app-design.md)); the current app's
logs are described in [DEBUGGING.md](../DEBUGGING.md).

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 140:

- **Summary:** The native app lives beside the current one
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified on the simulator (`just native-test-sim`: installs, launches, logs `session_start`) and on the phone (2026-10-04, installed beside Context Grabber and opened)

#### Use Case:
- **As someone** who depends on the current app every day
- **I want to** have the native app installed next to it under its own name
- **so that** I can try each ported journey without losing the app that works

#### Acceptance Criteria:
- **Scenario:** Installing the native build
- **Given:** Context Grabber is on the phone with its data
- **When:** the native build is installed and opened
- **Then:** a second app named "Grabber Native" opens on its Diagnostics screen showing the commit and branch it was built from, and Context Grabber still opens with its data untouched

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
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified on the simulator (`GRABBER_BUG` hook: the report, its screenshot and the log's name are written) and on the phone (2026-10-04: a shake, a note, the report and its screenshot pulled back)

#### Use Case:
- **As someone** who just saw the app do something wrong
- **I want to** shake the phone, type one line, and move on
- **so that** the developer gets the screen, the build and the session log without me explaining

#### Acceptance Criteria:
- **Scenario:** A shake
- **Given:** the native app is open on any screen
- **When:** I shake the phone, type "timer skipped the rest" and tap Log it
- **Then:** the report is stored with my note, a picture of the screen as it was at the shake, the screen's name, the build, and the name of this launch's log with the moment in it, and the screen says "Problem logged"

---

### User Story 143:

- **Summary:** A report becomes a GitHub issue once (technical)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); `just bugs-check` verified against the phone (2026-10-04, it found the one unfiled report); `just file-bugs` has not filed a real report yet; the issue names the screenshot's path on the Mac and uploads no picture: [509da33](https://github.com/idvorkin/context-grabber/commit/509da33), verified by running the script's body against a sample report; a failed look at the existing issues stops the filing instead of filing everything again: [6fed157](https://github.com/idvorkin/context-grabber/commit/6fed157), verified by running the script against a `gh` that fails (it exits before filing); a note that starts with a blank line is titled by its first line with words and no longer stops the filing: [002e088](https://github.com/idvorkin/context-grabber/commit/002e088), verified by running the script against a stand-in `gh`

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

### User Story 148:

- **Summary:** What's new, by day, written by the build itself
- **Issues:** [#165](https://github.com/idvorkin/context-grabber/issues/165)
- **Status:** native app: implemented in [f3d2758](https://github.com/idvorkin/context-grabber/commit/f3d2758) ([spec](../superpowers/specs/2026-10-06-native-whats-new-design.md)); verified by host tests (`WhatsNewTests`, including every real story file) and on the simulator (screenshots of the row and the screen listing Oct 5 and Oct 4 from this checkout's history; the log's `ui` open_whats_new with 2 days and 8 changes); the phone still to be checked by Igor

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
- **Then:** I see one section per day, newest first, each change once per story per day with its story and issue under it, no status or merge lines, and the log has `ui` open_whats_new

- **Scenario:** Nothing to show
- **Given:** a build made without the project's history, or with no story change in thirty days
- **When:** I open the app and tap the row
- **Then:** the row reads *What's new · nothing new* and the screen says there is nothing new, with no error
