# Swift-Native App — Design Spec

**Status:** Drafted 2026-10-04; direction agreed with Igor the same day
**Owner:** Igor
**Tracking:** bead `context-grabber-3ss` (one child per step)
**Supersedes:** [OTA-first architecture](2026-09-07-ota-first-architecture-design.md) once the cutover lands

## Summary

Igor, 2026-10-04: *"look at ../exercise-analyzer, and see how it does logging for bugs and test and user
stories. Then convert this project to be swift native."* And: *"feel free to re-write stuff as required."*

Context Grabber becomes a native iOS app. A second app, **Grabber Native**, is built beside the current one and
lives on the phone next to it. It gains one journey at a time; Igor uses each on the phone before the next
starts. When it does everything the current app does, it takes the current app's place and the old one is
removed.

From its first build the native app explains itself the way Exercise Analyzer does: one log per launch, a
shake to report a problem, crashes that come back with the logs, and a Mac that files the reports as issues.

## Decisions (Igor, 2026-10-04)

| Question | Answer |
|---|---|
| Over-the-air updates | Given up. Every change reaches the phone as an install from the Mac. |
| How to get there | A new app beside the old one, then a cutover. Not screen-by-screen inside the old app, not a big bang. |
| The Cockpit tab | Critical. It is ported, with real microphones and outputs. |
| Uploading a log as a private gist | Kept: calls happen away from the Mac. |
| Line-by-line port | No. Rewrite where a native design is better; the stories are what must stay true. |

Found while scoping: journal and role-moment sync through iCloud is in use, so it is ported. The old
grid-based place clustering is not used by the app and is not.

## Goals

- Everything in [the stories](../../stories/README.md) that is implemented today works in the native app, judged
  story by story.
- A problem on the phone reaches a GitHub issue with its evidence in two commands, without Igor copying text.
- The current app keeps working, unchanged, until the cutover.
- Nothing on the phone is lost at the cutover: location history, known places, the journal, role moments,
  settings, the gist token, the widgets' state.

## Non-goals

- New features during the port. A journey is ported as its stories describe it; requests that come up become
  stories and wait.
- Android, the web, Mac Catalyst.
- Keeping both apps in step. The old app gets no new work except a fix Igor asks for.

## What Igor sees, step by step

Each step ends with a build on the phone and Igor using it.

| Step | What the native app can do after it |
|---|---|
| 1 | Opens; shows which build it is; keeps a log of every launch; a shake (or a button) files a problem with a screenshot; a crash is reported at the next launch. Nothing else yet. |
| 2 | The Gym Timer: presets, cues in Igor's voice, music that keeps playing, the LED face and the turn, the accessory log. |
| 3 | Calling Larry: the call that survives the lock, voices, the call's diagnostics in the same log, the gist upload. |
| 4 | The mirror (Today, Body, Move, Mind and their detail sheets) and Grab Context. The export is the same JSON, byte for byte, as the current app's for the same data. |
| 5 | Places: background location, stays, known places, the map, the database export. |
| 6 | Roles and the journal, synced through iCloud, with voice entries. |
| 7 | Widgets, links and Shortcuts open the native app; the Cockpit tab. |
| 8 | Cutover: the native app becomes Context Grabber. The old app is replaced in place and its data is there on first open. |

Until step 8 the native app is a separate app with its own name, its own Health and location
permissions, and no access to the old app's data. Journeys that need history (places, the journal) can import
the old app's database export.

## Explaining itself (step 1)

**The session log.** Every launch starts a new log that the app writes as it goes: what started, what the user
did that matters, what failed, with the numbers that decide a question as numbers. It names the build it came
from. It is visible in the Files app and comes to the Mac with one command. Logs older than thirty days are
deleted at launch, except a log a problem report names.

**Reporting a problem.** A shake anywhere, or *Report a problem* on the Diagnostics screen, opens a sheet with
one text field and a list of what will be attached. *Log it* stores the note, a picture of the screen as it was
at the shake, the screen Igor was on, the build, and the name and moment of the session log. On the Mac the
report becomes one GitHub issue with the note and the context; filing twice never makes two issues. The
picture stays on the Mac and the issue says where: the issues are public, and a screen can show health, places
or the journal.

**Crashes.** When the app crashed or hung, the next launch's log says so and names a file with the stack; the
file comes to the Mac with the logs.

**Every error on screen** still carries a way to hand it over: the error is in the log with the state around
it, and the shake attaches that log. The copy-to-clipboard button stays where Igor is likely to be away from
the Mac (the call).

**Which build.** The Diagnostics screen shows the commit and branch the build was made from. The log's first
line carries the same.

## The Gym Timer in the native app (step 2)

The timer does what stories 100–116 say, with these differences while the two apps live side by side:

- **It opens from the native app's home screen**, full screen, and *Done* returns there.
- **The timer's log is the session log.** What the audio session, the duck window, the cues and the phases did is
  written there as events, so a shake attaches it. The *Log* button stays for the gym, where the Mac is not: it
  copies this launch's timer events behind a build line.
- **The preset chips are inert from START until RESET or the finish**, like the Custom sliders. In the current
  app a chip tapped mid-run silently changes the workout under the running clock.
- **A boundary is called within a tenth of a second of its true time.** The current app looks once a second, so
  a cue can be most of a second late.
- **A phone call mid-workout**: when the call ends the timer takes its audio back and keeps speaking.
- **With no rest, every round is still called.** A Custom preset with Rest 0:00 says *go* at the start of each
  round. The current app counts three, two, one and then says nothing.
- **Choosing a preset after the finish goes back to ready.** With *donE* on the face, a tap on a chip or a
  move of a Custom slider clears it and shows the new preset's time and *Round 1 of N*, as RESET would. The
  current app keeps the finished face until RESET.
- **Turned on its side, RESET is still there** (#132). While the rounds timer is paused or finished, or the
  stopwatch is stopped with time on it, a RESET button sits under the hint, turned with the face; a tap
  anywhere else still starts and stops. While running there is no RESET, so a tap across the room cannot clear a
  workout. The current app has no RESET in its turned view.
- **Coming back to the app never costs a cue.** What fell while the app was away is not replayed, and what
  falls in the second Igor comes back is still said.
- **The lock-screen countdown (106) and one-tap starts from widgets and links (114) wait for step 7**, when the
  widgets move. Until then the native timer keeps time and speaks with the screen locked, but shows nothing on
  the lock screen.
- **Sets, the Custom preset and the accessory log are the native app's own** until the cutover: what is logged
  in one app is not in the other, and the native app's accessory work is not in Grab Context until step 4.

Acceptance for step 2: each of stories 100–105, 107–113, 115 and 116 holds in the native app on the phone; a
whole workout with music playing, the phone locked for a round, leaves a session log with every phase and cue
at its true second and no `error`.

## The mirror and Grab Context in the native app (step 4)

The mirror does what stories 002–009, 013 and 019 say, and Grab Context what stories 020, 021 and 024–029 say,
with these differences while the two apps live side by side:

- **Today opens from the native app's home screen**, as the Gym Timer does, and the home screen stays the
  Diagnostics list. Whether Today becomes the home screen (with Diagnostics behind a button) is Igor's call and
  waits for it.
- **Today is one screen**: a header with when the last grab finished and a phase while one runs, a summary line,
  the body cards (Movement, Exercise, Heart Rate, HRV, Sleep, Meditation, Weight) with the same values, sublabels
  and box plots as the current Body tab, and *Share summary* / *Share raw*. The current app's tabs (Today, Body,
  Move, Mind) are not rebuilt yet; what lives on them besides the cards waits for its own step (below).
- **A grab** asks for Health access the first time (the same read types as the current app), reads today live and
  the past six days from its own cache, and never fails as a whole: a metric Health will not give reads "—". It
  runs when Today opens, when the app comes back to the front, every thirty minutes while Today is open, and on a
  pull. The last grab's cards show at once on the next open.
- **The detail sheets** are drawn with the system's charts: bars for counts, a line with each day's range for
  heart rate, HRV, resting heart rate and weight, the normalized three-line Movement chart, and for Sleep the
  stacked stages, the per-source tabs with *All*, the sleep debt against the target, the bedtime-and-wake chart
  with its ±, the onset and gap tags, and a tapped night's zoom card. Heart Rate carries resting heart rate under
  its chart.
- **The exports are the current app's, byte for byte**, for the same Health data and the same accessory log:
  the summary is the same single line of JSON, the raw share the same indented JSON. The share sheet receives the
  text, as in the current app.
- **What the native export does not carry yet**: `roles` is null until roles move (step 6) — the current app sends
  them; `places` is null until the native Places has its weekly and recent summaries (after step 5); in the raw
  share `location` and `locationClusters` are null until step 5. Every key is still present with the same shape.
- **Carried over unchanged, on purpose**, because the export must match the current app's byte for byte; each is
  filed to decide with Igor rather than fixed silently: each day's `sleepHours` in `days` is counted midnight to
  midnight (the headline's last night is noon to noon, as story 025 asks); `bedtime` and `wakeTime` in the
  headline are clock times in UTC; `walkingDistanceKm` is in the phone's preferred distance unit (miles on a phone
  set to US units); and a day's steps, energy and distance in `days` keep two decimals.
- **Settings for the mirror** is the sleep target, kept where the current app keeps it. The current app's About and
  update check have no place here: the native app has no over-the-air updates, and Diagnostics names the build.
- **Not in this step**, each with its own issue: the map, tally and Reflect row on Today (001, with Places, the
  tally and the journal), the Exercise sheet's activity timeline and workout analysis (010's timeline, 011), the
  hourly heart-rate box plots and the raw heart-rate export (012), the meditation flatline card (014), mood and
  energy (015), the tally (016), the Move tab (017), recent reflections (018), and the week strip's gym-day dots
  (002).

Acceptance for step 4: for the fixture data — a real week of heart rate, HRV, resting heart rate and energy, plus
steps, distance, sleep from two sources, mindful minutes, weigh-ins, workouts (one crossing midnight) and accessory
entries — the native summary and raw exports equal the current app's, byte for byte, on the Mac and from the
simulator's Health store; on the phone the cards show the same numbers as the current app's Body tab after a grab
in both.

## Verifying

The ladder keeps its shape and gets cheaper at the bottom: the platform-free logic is tested on the Mac in
seconds; the simulator runs the app from launch hooks and is judged from the session log, not from taps; the
phone is for what only the phone can show. Details live in [TESTING.md](../../TESTING.md) and
[DEBUGGING.md](../../DEBUGGING.md).

## Acceptance criteria

Step 1:

- Installing the native app leaves the current app and its data untouched; both open.
- Each launch produces one new log whose first entry names the device, the system and the build.
- A shake opens the report sheet; an empty note cannot be sent; a sent report is stored with a screenshot and
  names the session log.
- From the Mac, new reports are detected without pulling everything, and filing them creates each issue once.
- A launch after a crash announces the crash in the log exactly once.
- A log older than thirty days is gone after the next launch unless a report names it.

The whole port:

- Every story marked implemented has the native build on its `Status:` line with where it was verified, or a
  line saying why it was dropped.
- For the fixture data, the native export equals the current export.
- After the cutover, the first open shows the same location history, places, journal and settings as the last
  open of the old app, and the widgets keep their state.

## Risks

- **The call.** Its fixes were found on the phone (echo cancellation, the silent first call, the mic after a
  route change). Each has a story or an issue; step 3 is checked against all of them on the phone before it
  counts.
- **No update without the Mac.** A bad build stays until the phone is back near the Mac. The old app stays
  installed until step 8 as the fallback.
- **Two apps tracking location** during steps 5–7 cost battery; background tracking in the native app stays
  off until Igor turns it on.
