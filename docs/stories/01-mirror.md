# The mirror: today and the week

Seeing who I have actually been being — today at a glance, the week on a tap — without flinching and without judging.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 001:

- **Summary:** Open the app and see where I am, my tally, and a way to reflect — before any tab tap
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5), [ac11088](https://github.com/idvorkin/context-grabber/commit/ac11088), [fb33625](https://github.com/idvorkin/context-grabber/commit/fb33625); verified by `App.test.tsx`, `StylizedMap.test.tsx` and on the phone (daily use). The "day in a sentence" headline and the Fresh / Stale chip from the tabbed-app spec are not built.

#### Use Case:
- **As** someone opening the phone at the end of the day
- **I want to** land on a Today screen with today's map, my tally and the Reflect buttons
- **so that** the answer to "where am I, what did I do" is on the first screen, not behind a tab

#### Acceptance Criteria:
- **Scenario:** Opening the app after a day out
- **Given:** the app has grabbed at least once
- **When:** I open it
- **Then:** the Today tab shows a map of today's places and path with a "You" pin, the tally with +1 and reset, the Reflect row with today's counts, and the grab timestamp; the gear opens Settings

---

### User Story 002:

- **Summary:** Glance the body in one scroll, grouped the way Larry reads it
- **Status:** implemented in [cb58e1e](https://github.com/idvorkin/context-grabber/commit/cb58e1e), [11a9c11](https://github.com/idvorkin/context-grabber/commit/11a9c11), [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `App.test.tsx` and on the phone (daily use). Supersedes DB-1 in `docs/user-needs.md`.

#### Use Case:
- **As** someone checking in before bed
- **I want to** see Movement, Exercise, Heart Rate, HRV, Sleep, Meditation and Weight as cards with today's value and a range under each
- **so that** I know where I stand in two seconds without doing arithmetic

#### Acceptance Criteria:
- **Scenario:** Reading the Body tab
- **Given:** a grab has completed
- **When:** I open the Body tab
- **Then:** a week strip runs across the top with a dot on gym days, and the cards show each metric's value with its sublabel ("today", "latest", "last night"); a metric with no data reads "—" dimmed, never an error

---

### User Story 003:

- **Summary:** Tap any metric for its last seven days
- **Status:** implemented in [ad6c48c](https://github.com/idvorkin/context-grabber/commit/ad6c48c), [7363b9e](https://github.com/idvorkin/context-grabber/commit/7363b9e); verified by `weekly.test.ts` and on the phone (daily use). Supersedes DB-2.

#### Use Case:
- **As** someone who noticed a low number
- **I want to** tap the card and see the week as a chart with a daily breakdown
- **so that** I can tell a one-off from a pattern

#### Acceptance Criteria:
- **Scenario:** Drilling into a metric
- **Given:** the Body tab is showing cards
- **When:** I tap Meditation
- **Then:** a sheet slides up with the metric's name, today's value, a seven-bar chart with today highlighted, an "Avg … /day" line, and seven daily rows newest first; the whole sheet scrolls as one and the handle or ✕ dismisses it

---

### User Story 004:

- **Summary:** See a metric's range, not just its average
- **Status:** implemented in [2f8aaa2](https://github.com/idvorkin/context-grabber/commit/2f8aaa2), [ae0c1d0](https://github.com/idvorkin/context-grabber/commit/ae0c1d0), [6d9b60b](https://github.com/idvorkin/context-grabber/commit/6d9b60b); verified by `stats.test.ts` and on the phone
- **Issues:** [#10](https://github.com/idvorkin/context-grabber/issues/10), [#30](https://github.com/idvorkin/context-grabber/issues/30)

#### Use Case:
- **As** an engineer who distrusts averages
- **I want to** see each card's week as a box plot with the endpoints written on the tile
- **so that** a wide week and a narrow week look different at a glance

#### Acceptance Criteria:
- **Scenario:** Reading a card's range
- **Given:** seven days of data for a metric
- **When:** I look at its card
- **Then:** a horizontal box plot shows p5 / p25 / p50 / p75 / p95 with the min and max as small numbers in the corners, and the Movement card stacks three mini plots (steps, distance, energy)

---

### User Story 005:

- **Summary:** Movement is one card, not three
- **Status:** implemented in [955611a](https://github.com/idvorkin/context-grabber/commit/955611a), [6d9b60b](https://github.com/idvorkin/context-grabber/commit/6d9b60b); verified by `weekly.test.ts` and on the phone

#### Use Case:
- **As** someone asking "did I move today?"
- **I want to** see steps big with distance and energy underneath, and one chart with all three
- **so that** I answer one question instead of three, and can see the day I ran rather than walked

#### Acceptance Criteria:
- **Scenario:** Opening Movement
- **Given:** steps, walking distance and active energy for the week
- **When:** I tap the Movement card
- **Then:** the sheet shows three normalized lines on one chart with a legend giving each series' weekly max, and daily rows carrying all three absolute values; the export still carries the three fields separately

---

### User Story 006:

- **Summary:** Sleep is counted noon to noon and per source, so a Watch and a phone don't double the night
- **Status:** implemented in [14e81d0](https://github.com/idvorkin/context-grabber/commit/14e81d0), [7d2c9c9](https://github.com/idvorkin/context-grabber/commit/7d2c9c9), [2f8aaa2](https://github.com/idvorkin/context-grabber/commit/2f8aaa2), [7363b9e](https://github.com/idvorkin/context-grabber/commit/7363b9e); verified by `sleep.test.ts`, `health.test.ts`, `weekly.test.ts` and on the phone (issue reports from real nights)
- **Issues:** [#11](https://github.com/idvorkin/context-grabber/issues/11), [#6](https://github.com/idvorkin/context-grabber/issues/6)

#### Use Case:
- **As** someone whose Watch and phone both log sleep
- **I want to** see last night attributed to the day I went to bed, with a tab per source and an All view that merges overlaps
- **so that** a 7-hour night never reads as 14, and I can compare what each device saw

#### Acceptance Criteria:
- **Scenario:** Two sources logged the same night
- **Given:** Apple Watch and a second source both reported 11pm–6am
- **When:** I open the Sleep sheet
- **Then:** the source with the richest stage data is selected by default, "All" shows the merged night once (about 7 h), switching tabs re-renders the chart, average, stages and daily rows, and a sample before noon counts toward the previous night

---

### User Story 007:

- **Summary:** See how I slept, not only how long: stages, debt against a target, and bedtime consistency
- **Status:** implemented in [18ed07b](https://github.com/idvorkin/context-grabber/commit/18ed07b); verified by `sleep.test.ts` and on the phone

#### Use Case:
- **As** someone trying to keep a steady bedtime
- **I want to** see each night's Core / Deep / REM / Awake stack, a running sleep debt against my target, and a bedtime-and-wake line over the week
- **so that** a drifting schedule is visible before it becomes a bad week

#### Acceptance Criteria:
- **Scenario:** Reading the week's sleep
- **Given:** the sleep target in Settings is 8 h
- **and Given:** four nights were short
- **When:** I open the Sleep sheet
- **Then:** the bars are stacked by stage with totals under them, a "Sleep debt" line sums the shortfalls (oversleeping earns nothing back), a two-line chart shows bedtime and wake with "±" minutes under it, and each daily row carries a thin stage strip from bedtime to wake

---

### User Story 008:

- **Summary:** Zoom into one night
- **Status:** implemented in [7363b9e](https://github.com/idvorkin/context-grabber/commit/7363b9e); verified on the phone

#### Use Case:
- **As** someone who woke up rough
- **I want to** tap that night's bar and see its stages laid out large with the hours underneath
- **so that** I can see when the night broke, not just that it was short

#### Acceptance Criteria:
- **Scenario:** Inspecting a night
- **Given:** the Sleep sheet is open
- **When:** I tap Tuesday's bar
- **Then:** a card appears under the chart with the date, total and bedtime → wake, a large stage strip with hour labels, and that night's stage percentages; tapping the bar again closes it, tapping another night switches it, and a night with no data says so inside the card

---

### User Story 009:

- **Summary:** The sleep view never contradicts itself
- **Status:** implemented in [20245f9](https://github.com/idvorkin/context-grabber/commit/20245f9), [2897738](https://github.com/idvorkin/context-grabber/commit/2897738), [4c4ae84](https://github.com/idvorkin/context-grabber/commit/4c4ae84); verified by `sleep.test.ts` and on the phone (Igor's own nights, issue closed)
- **Issues:** [#28](https://github.com/idvorkin/context-grabber/issues/28)

#### Use Case:
- **As** someone who caught the app claiming a 10.4 h average over 7 h bars
- **I want to** see a header in local short times, an average that equals the bars I am looking at, and the difference between time the tracker missed and time I lay awake
- **so that** I can trust the panel enough to act on it

#### Acceptance Criteria:
- **Scenario:** A noisy night with a stray afternoon sample
- **Given:** the Watch logged a bed-like blip at 3 pm and the real night 10:30 pm–5:19 am
- **When:** I open the Sleep sheet on that source
- **Then:** the header reads "10:30pm – 5:19am", the Avg equals the mean of the visible bars, the blip is excluded from bedtime and totals, an "onset Xm" tag shows pre-sleep awake time of ten minutes or more, and a "⚠ gap" tag appears only for truly untracked time

---

### User Story 010:

- **Summary:** Exercise shows the workouts themselves, by type, with the day's timeline
- **Status:** implemented in [238cd20](https://github.com/idvorkin/context-grabber/commit/238cd20), [b3f5146](https://github.com/idvorkin/context-grabber/commit/b3f5146), [a459445](https://github.com/idvorkin/context-grabber/commit/a459445), [03348f8](https://github.com/idvorkin/context-grabber/commit/03348f8); verified by `activity.test.ts`, `health.test.ts` and on the phone
- **Issues:** [#7](https://github.com/idvorkin/context-grabber/issues/7)

#### Use Case:
- **As** someone who did kettlebells in the morning and walked in the evening
- **I want to** see the day's workouts listed by type with duration, energy and distance, and a timeline of when the day was active
- **so that** "35 exercise minutes" turns back into what actually happened

#### Acceptance Criteria:
- **Scenario:** Reviewing a training day
- **Given:** HealthKit holds a Kettlebell workout and a Walk for today
- **When:** I tap the Exercise card
- **Then:** the sheet lists both workouts with their type, minutes, kcal and km, the selected day's total minutes is shown, and the activity timeline's bars are tappable by day

---

### User Story 011:

- **Summary:** Tap a workout and see the sets it contained, inferred from the heart rate alone
- **Status:** implemented in [a85c07e](https://github.com/idvorkin/context-grabber/commit/a85c07e), [f3d3ee9](https://github.com/idvorkin/context-grabber/commit/f3d3ee9), [bf819a0](https://github.com/idvorkin/context-grabber/commit/bf819a0), [dfb8217](https://github.com/idvorkin/context-grabber/commit/dfb8217), [c7fc808](https://github.com/idvorkin/context-grabber/commit/c7fc808); verified by `workoutAnalysis.test.ts` against the real two-day HR fixture (Igor's 10× swings recovered exactly) and on the phone. Phase 3 of the parent issue — handing the sets to Larry automatically — is not built.
- **Issues:** [#34](https://github.com/idvorkin/context-grabber/issues/34), [#35](https://github.com/idvorkin/context-grabber/issues/35)

#### Use Case:
- **As** someone who never logs sets by hand
- **I want to** tap a workout and see the working sets, rests, rep estimates and a plain-language narrative
- **so that** a Kettlebility class is inspectable in two taps and obviously-wrong inferences are obvious before Larry sees them

#### Acceptance Criteria:
- **Scenario:** Opening yesterday's class
- **Given:** the workout has heart-rate samples
- **When:** I tap it in the Exercise sheet
- **Then:** within about a second the analysis screen shows the HR trace with set bands, one row per set with its time since start, rest before it, duration, peak and average HR, recovery floor, a rep estimate and a confidence dot, an inline sparkline per set, a narrative paragraph, and a Share JSON action; a workout with no HR says set inference is unavailable instead of erroring

---

### User Story 012:

- **Summary:** Heart rate by the hour, resting rate alongside, and the raw samples when I want them
- **Status:** implemented in [ffa18a7](https://github.com/idvorkin/context-grabber/commit/ffa18a7), [03e40a5](https://github.com/idvorkin/context-grabber/commit/03e40a5), [66c3a0f](https://github.com/idvorkin/context-grabber/commit/66c3a0f); verified by `stats.test.ts` and on the phone

#### Use Case:
- **As** someone wondering whether the afternoon spike was the gym or the meeting
- **I want to** see heart rate as hourly box plots with resting HR in the same sheet, and export the raw samples for a day or a week
- **so that** the day's shape is readable and the raw data is one tap away for a deeper look

#### Acceptance Criteria:
- **Scenario:** Reading a day's heart rate
- **Given:** a day of samples
- **When:** I open the Heart Rate sheet
- **Then:** hourly ranges render as box plots, resting heart rate is shown in the sheet rather than as its own card, and a 1d / 2d / 7d export shares the raw HR and workout samples as JSON

---

### User Story 013:

- **Summary:** Tiles never go blank, and they refresh themselves
- **Status:** implemented in [f318e94](https://github.com/idvorkin/context-grabber/commit/f318e94), [ae0c1d0](https://github.com/idvorkin/context-grabber/commit/ae0c1d0), [81434c4](https://github.com/idvorkin/context-grabber/commit/81434c4), [ec1acfc](https://github.com/idvorkin/context-grabber/commit/ec1acfc); verified by `snapshot.test.ts` and on the phone (issues closed after use)
- **Issues:** [#33](https://github.com/idvorkin/context-grabber/issues/33), [#31](https://github.com/idvorkin/context-grabber/issues/31), [#32](https://github.com/idvorkin/context-grabber/issues/32)

#### Use Case:
- **As** someone glancing at the phone between meetings
- **I want to** always see the last grab's numbers, with a fresh grab happening on foreground, every thirty minutes, or on pull
- **so that** the mirror is never empty and never stale enough to lie

#### Acceptance Criteria:
- **Scenario:** Cold start after a night
- **Given:** the app was killed overnight
- **When:** I open it in the morning
- **Then:** yesterday's snapshot renders at once, a re-grab starts on foreground with an elapsed-seconds pill and phase label in the header, past days come from the local cache while today is live, and pulling down on Today grabs again

---

### User Story 014:

- **Summary:** Meditation flatline is a card, not a buried number
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified on the phone. Supersedes the in-app half of CC-3.

#### Use Case:
- **As** someone whose practice quietly stops when stress rises
- **I want to** see time since the last sit and a seven-day intensity strip at the top of Mind
- **so that** three days of nothing is noticed as a signal, in time-since language, not a broken streak

#### Acceptance Criteria:
- **Scenario:** A lapsed week
- **Given:** no mindful session for three days
- **When:** I open the Mind tab
- **Then:** the card reads the days since the last session with the week's strip mostly empty; no red, no "missed" wording anywhere on the tab

---

### User Story 015:

- **Summary:** Log mood and energy in two taps
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `moodLog.test.ts` and on the phone

#### Use Case:
- **As** someone noticing my energy dip at 3 pm
- **I want to** tap a number for mood and a number for energy and be done
- **so that** the self-report exists at all — anything longer would not get logged

#### Acceptance Criteria:
- **Scenario:** A quick check-in
- **Given:** the Mind tab is open
- **When:** I tap 2 on the mood row and 3 on the energy row
- **Then:** each tap saves immediately with no Save button, and the entries are still there after a relaunch

---

### User Story 016:

- **Summary:** A label-free daily tally, on Move and Today, that resets at midnight
- **Status:** implemented in [d00e45b](https://github.com/idvorkin/context-grabber/commit/d00e45b), [c6fc609](https://github.com/idvorkin/context-grabber/commit/c6fc609), [c48d01b](https://github.com/idvorkin/context-grabber/commit/c48d01b); verified by `counter.test.ts` and on the phone (widget +1 in daily use). The five-minute timer preset half of the issue is a Gym Timer story.
- **Issues:** [#29](https://github.com/idvorkin/context-grabber/issues/29)

#### Use Case:
- **As** someone counting squats, or balloons, or gratitudes — whatever the day is
- **I want to** tap +1 and see tally marks grow, reset with a confirm, and start at zero each morning
- **so that** "I did a thing" costs one tap and never needs a label

#### Acceptance Criteria:
- **Scenario:** Counting through a day
- **Given:** the count read 24 at 11:30 pm
- **When:** I open the app at 12:30 am and tap +1
- **Then:** the tally shows 1 (the day reset without me), the marks render in groups of five with a diagonal strike, the same count shows on the Today tab and the home-screen widget, and ↺ asks before zeroing

---

### User Story 017:

- **Summary:** Move is where training starts: presets one tap away and the week's minutes as a ring
- **Status:** implemented in [55032c4](https://github.com/idvorkin/context-grabber/commit/55032c4), [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `App.test.tsx` and on the phone (daily use). The timer's own behaviour is the Gym Timer journey.

#### Use Case:
- **As** someone walking into the gym
- **I want to** open Move, tap a preset, and be in the timer, with the week's exercise ring and recent workouts on the same screen
- **so that** starting a set is one tap and the week's effort is visible where I train

#### Acceptance Criteria:
- **Scenario:** Starting a session
- **Given:** the Move tab is open
- **When:** I tap the 1 MIN preset tile
- **Then:** the Gym Timer opens on that preset, and behind it Move shows the ring of this week's minutes against the weekly goal and the ten most recent workouts, each tappable for its analysis

---

### User Story 018:

- **Summary:** See what I reflected on in the last day, right where I log it
- **Status:** implemented in [c48d01b](https://github.com/idvorkin/context-grabber/commit/c48d01b); verified by `JournalRecentList.test.tsx` and on the phone

#### Use Case:
- **As** someone who just logged a gratitude
- **I want to** see the last 24 hours of entries under the Reflect buttons, playable, deletable, and taggable in place
- **so that** reflecting is a loop, not a one-way capture into an archive I never open

#### Acceptance Criteria:
- **Scenario:** After logging a gratitude
- **Given:** I saved "Sunny walk" a minute ago and a voice affirmation yesterday morning
- **When:** I look at the Mind tab
- **Then:** "Recent (24h)" lists the gratitude at the top with its time, the voice entry with a play control and its duration if it is within 24 hours, delete asks first, tapping the role avatars edits the roles in place, and an empty window shows a prompt pointing at Reflect

---

### User Story 019:

- **Summary:** Settings and About: tracking, retention, the sleep target, and what build is running
- **Status:** implemented in [7d2c9c9](https://github.com/idvorkin/context-grabber/commit/7d2c9c9), [18ed07b](https://github.com/idvorkin/context-grabber/commit/18ed07b), [2bb7f2b](https://github.com/idvorkin/context-grabber/commit/2bb7f2b), [bafc357](https://github.com/idvorkin/context-grabber/commit/bafc357), [d87ad0b](https://github.com/idvorkin/context-grabber/commit/d87ad0b), [0bb87bf](https://github.com/idvorkin/context-grabber/commit/0bb87bf); verified by `version.test.ts` and on the phone (every OTA)

#### Use Case:
- **As** someone who just got told "it's fixed, reload"
- **I want to** open Settings → About and see the commit message, build time, channel and runtime, and pull the update from there
- **so that** "what is my phone running?" has an answer without a Mac

#### Acceptance Criteria:
- **Scenario:** Confirming an update landed
- **Given:** a new OTA update was published
- **When:** I open Settings and tap About
- **Then:** Settings shows the sleep target, the background-tracking switch with retention days, and the diagnostics-upload section; About shows version, built time, the commit as a link, channel and runtime, "Check for Updates" fetches and reloads, and a downloaded update also shows a tap-to-reload banner on Today
