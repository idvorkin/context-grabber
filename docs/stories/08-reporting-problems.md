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
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); `just bugs-check` verified against the phone (2026-10-04, it found the one unfiled report); `just file-bugs` has not filed a real report yet

#### Use Case:
- **As a** developer with the phone near the Mac
- **I want to** have every new report filed as an issue with its note, context and screenshot
- **so that** nothing Igor reported is lost and nothing is filed twice

#### Acceptance Criteria:
- **Scenario:** Filing after a session at the gym
- **Given:** two reports are on the phone and one of them is already an issue
- **When:** I run `just pull-logs` and `just file-bugs`
- **Then:** exactly one new issue is created, carrying the note, the screen, the build, the log's name and the screenshot, and running `just file-bugs` again creates none

---

### User Story 144:

- **Summary:** A crash comes back with the logs (technical)
- **Status:** implemented in [89da016](https://github.com/idvorkin/context-grabber/commit/89da016); verified by build only — the first real crash will verify it

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
