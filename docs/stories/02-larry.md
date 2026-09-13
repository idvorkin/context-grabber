# Feeding Larry: the context export

Getting the week in front of the coach in one tap, shaped so a thoughtful human could give advice on it cold.

Part of the [user stories](README.md); persona and format are described there. The export is a contract: field names, units and structure stay stable across versions and across the Swift port.

---

### User Story 020:

- **Summary:** One tap sends Larry today's headline and the last seven days
- **Status:** implemented in [7b52df6](https://github.com/idvorkin/context-grabber/commit/7b52df6), [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `share.test.ts`, `snapshot.test.ts` and on the phone (every coaching call). Supersedes CC-1 in `docs/user-needs.md`.

#### Use Case:
- **As** Larry's client five minutes before the call
- **I want to** tap ↗ Summary and hand over a `today` object and a seven-entry `days` array
- **so that** Larry can reference specific days and numbers without me narrating the week

#### Acceptance Criteria:
- **Scenario:** Sharing before a call
- **Given:** a grab has completed
- **When:** I tap ↗ Summary on Today and pick a destination in the share sheet
- **Then:** the payload has `today` (date, day of week, steps, heart rate, resting HR, HRV, sleep hours with human bedtime and wake, meditation, exercise, weight in lbs, energy, distance, today's workouts) and `days` with seven entries newest first, each carrying the same daily fields with nulls where nothing was recorded

---

### User Story 021:

- **Summary:** The summary reads as a briefing, not a data dump
- **Status:** implemented in [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `share.test.ts` and on the phone (payload fits in an iMessage)

#### Use Case:
- **As** someone pasting the export into a chat
- **I want to** send a compact payload with no coordinates, no unix timestamps, no percentile tables
- **so that** the coach reads health narrative, and the message is not 90 % location noise

#### Acceptance Criteria:
- **Scenario:** Checking what went out
- **Given:** thirty days of location history on the phone
- **When:** I open the shared summary
- **Then:** it is single-line JSON with no `latitude`, `longitude`, `center`, `radiusMeters`, `pointCount`, `firstVisit`, `lastVisit` or `weeklyStats` keys, and it is at least 60 % smaller than the pre-trim export was

---

### User Story 022:

- **Summary:** Where the week went, as text a coach can read
- **Status:** implemented in [06a20b0](https://github.com/idvorkin/context-grabber/commit/06a20b0), [ff18ef3](https://github.com/idvorkin/context-grabber/commit/ff18ef3), [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `clustering_v2.test.ts` (real fixture) and on the phone. Supersedes CC-5.

#### Use Case:
- **As** someone whose "home by 6pm" goal Larry checks
- **I want to** include a weekly per-place rollup and the last three days as named stays with local times
- **so that** Larry sees "Office Tue 9am–5pm (8h)" rather than a list of points

#### Acceptance Criteria:
- **Scenario:** A normal week
- **Given:** Home, Office and Gym are known places
- **When:** I share the summary
- **Then:** `places.weekly` reads like "This week: Home 92h, Office 28h, Gym 4h" with places in descending hours, `places.recent` has at most the last three days in 12-hour local time, and with no location history the section is absent rather than the share failing

---

### User Story 023:

- **Summary:** Roles lead the export — who I have been being, before the numbers
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `roles.test.ts`, `share.test.ts` and on the phone

#### Use Case:
- **As** the eulogy version of me
- **I want to** open the export with each of the eleven roles, its week score, activity line, days since last shown, the roles needing attention with a reason, and this week's intentions
- **so that** Larry starts from "Husband to Tori, quiet, last shown May 14" and treats HealthKit as supporting evidence

#### Acceptance Criteria:
- **Scenario:** A week with one quiet role
- **Given:** no tagged moments for Husband to Tori in eight days
- **and Given:** an intention was set for Father to Amelia this week
- **When:** I share the summary
- **Then:** `roles` is the first key, its `roles` list has eleven entries with `qualifier` strong or quiet, `attention` names Husband to Tori with its reason, `intentions` carries the saved text, and an empty database yields `roles: null` without blocking the share

---

### User Story 024:

- **Summary:** The mobility work I logged after training rides along
- **Status:** implemented in [dc6546e](https://github.com/idvorkin/context-grabber/commit/dc6546e); verified by `accessoryLog.test.ts`, `share.test.ts` and on the phone

#### Use Case:
- **As** someone who does the McGill Big 3 but never mentions it
- **I want to** have the accessory items I ticked in the Gym Timer appear in the summary with when I did them
- **so that** a day that ended with mobility work looks different to Larry from one that skipped it

#### Acceptance Criteria:
- **Scenario:** After a week with two mobility sessions
- **Given:** Half Lotus and Dead Hangs were logged on Tuesday and Pigeon Stretch on Friday
- **When:** I share the summary
- **Then:** `accessory` lists three entries, each with the item name, an ISO-8601 UTC timestamp and the local `date`, and a week with nothing logged carries an empty section rather than omitting the concept

---

### User Story 025:

- **Summary:** Sleep hours in the export are real sleep, noon to noon
- **Status:** implemented in [14e81d0](https://github.com/idvorkin/context-grabber/commit/14e81d0), [7d2c9c9](https://github.com/idvorkin/context-grabber/commit/7d2c9c9); verified by `health.test.ts`, `sleep.test.ts` and on the phone. Supersedes CC-7.
- **Issues:** [#11](https://github.com/idvorkin/context-grabber/issues/11)

#### Use Case:
- **As** someone who was told "you slept 13 hours" by an app once
- **I want to** export the merged asleep hours, attributed to the night I went to bed
- **so that** Larry's sleep feedback is about sleep, not about two devices both watching me

#### Acceptance Criteria:
- **Scenario:** A night the Watch and phone both saw
- **Given:** overlapping samples from two sources for one night
- **When:** I share the summary
- **Then:** that day's `sleepHours` is the merged asleep total (Core + Deep + REM, not In Bed), a nap after noon counts toward the following night, and `bedtime` / `wakeTime` are human short times

---

### User Story 026:

- **Summary:** Meditation and exercise per day, with the zeros visible
- **Status:** implemented in [8361ad4](https://github.com/idvorkin/context-grabber/commit/8361ad4), [7b52df6](https://github.com/idvorkin/context-grabber/commit/7b52df6), [238cd20](https://github.com/idvorkin/context-grabber/commit/238cd20); verified by `health.test.ts`, `weekly.test.ts` and on the phone. Supersedes CC-2 and CC-3.

#### Use Case:
- **As** someone whose practice stopping is the earliest stress signal
- **I want to** export meditation and exercise minutes for each of the seven days, including days that were zero
- **so that** Larry can spot the flatline and confirm gym days without asking

#### Acceptance Criteria:
- **Scenario:** A week that fell off
- **Given:** meditation Monday to Wednesday and nothing after
- **When:** I share the summary
- **Then:** Thursday to Sunday carry `meditationMinutes: 0`, not null, and each day's `exerciseMinutes` is the sum of that day's workout samples

---

### User Story 027:

- **Summary:** Weight in pounds, HRV and resting heart rate every day
- **Status:** implemented in [7b52df6](https://github.com/idvorkin/context-grabber/commit/7b52df6), [b3f5146](https://github.com/idvorkin/context-grabber/commit/b3f5146); verified by `share.test.ts` and on the phone. Supersedes CC-4 and closes Larry's "HRV always null" gap from `docs/user-needs.md`.

#### Use Case:
- **As** someone tracking toward 180 lb with a coach who reads pounds
- **I want to** export daily weight in lbs, HRV in ms and resting heart rate
- **so that** the weight trend needs no conversion and recovery has a signal

#### Acceptance Criteria:
- **Scenario:** A day with a morning weigh-in
- **Given:** the scale wrote 82.1 kg to HealthKit
- **When:** I share the summary
- **Then:** that day's `weightLbs` is 181, `hrvMs` and `restingHeartRate` carry the day's values or null, and no day carries a kilogram figure

---

### User Story 028:

- **Summary:** Today's workouts in the headline, not just minutes
- **Status:** implemented in [b3f5146](https://github.com/idvorkin/context-grabber/commit/b3f5146), [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `share.test.ts` and on the phone. The per-set breakdown from the workout-analysis spec is not in the summary export (the analysis screen's own Share JSON carries it).
- **Issues:** [#34](https://github.com/idvorkin/context-grabber/issues/34)

#### Use Case:
- **As** someone who did kettlebells and a walk today
- **I want to** have each of today's workouts in the export with its type, minutes, energy and distance
- **so that** "35 exercise minutes" arrives as what it was

#### Acceptance Criteria:
- **Scenario:** A two-workout day
- **Given:** a Kettlebell workout and a Walk ended today
- **When:** I share the summary
- **Then:** `today.workouts` lists both with activity type, duration, kcal and km where present, and a workout that started yesterday but ended today is included

---

### User Story 029:

- **Summary:** The raw share, for a machine
- **Status:** implemented in [381d143](https://github.com/idvorkin/context-grabber/commit/381d143), [c6c0106](https://github.com/idvorkin/context-grabber/commit/c6c0106), [7d2c9c9](https://github.com/idvorkin/context-grabber/commit/7d2c9c9); verified by `snapshot.test.ts` and on the phone

#### Use Case:
- **As** an engineer debugging a number Larry questioned
- **I want to** share the full snapshot — every health field, the single coordinate, clustered places with their timeline — pretty-printed
- **so that** I can see exactly what the app saw without exposing the raw breadcrumb trail

#### Acceptance Criteria:
- **Scenario:** Checking a suspicious value
- **Given:** a grab has completed
- **When:** I tap ↗ Raw
- **Then:** the payload has `timestamp`, `health`, `location` and `locationClusters` (clusters, timeline, summary), is indented for reading, and contains no `locationHistory` point list

---

### User Story 030:

- **Summary:** Copy my current coordinates, fresh, in one tap
- **Status:** implemented in [7d1b64d](https://github.com/idvorkin/context-grabber/commit/7d1b64d), [0e85a51](https://github.com/idvorkin/context-grabber/commit/0e85a51), [863631b](https://github.com/idvorkin/context-grabber/commit/863631b), [ae0c1d0](https://github.com/idvorkin/context-grabber/commit/ae0c1d0); verified on the phone (issues closed after use)
- **Issues:** [#26](https://github.com/idvorkin/context-grabber/issues/26), [#14](https://github.com/idvorkin/context-grabber/issues/14)

#### Use Case:
- **As** someone about to text "here's where I am"
- **I want to** tap Copy and get a fix a few seconds old, or the cached one clearly marked when GPS will not answer
- **so that** I never paste an hour-old location, and never get nothing

#### Acceptance Criteria:
- **Scenario:** Copying after moving across town
- **Given:** the last grab was an hour ago at the office
- **When:** I tap Copy Coordinates in the Location sheet
- **Then:** the button reads "Refreshing…", the clipboard gets six-decimal coordinates from a fix under thirty seconds old and the button reads "Copied"; with permission denied or airplane mode it reads "Copied (cached)" and the clipboard still has the last fix; a double tap copies once

---

### User Story 031:

- **Summary:** Copy the daily places breakdown as plain text
- **Status:** implemented in [5f00862](https://github.com/idvorkin/context-grabber/commit/5f00862); verified by `places_summary.test.ts` and on the phone

#### Use Case:
- **As** someone answering "where did the week go?" in a chat
- **I want to** copy one line per day of named places and hours, newest first
- **so that** it pastes as something a person reads, not a table to decode

#### Acceptance Criteria:
- **Scenario:** Copying the week
- **Given:** three days of stays at known places
- **When:** I tap Copy Daily Summary
- **Then:** the clipboard reads like "Tue Apr 22: Home 10h, Office 7h, Gym 1h" per day with places by descending time, sub-hour stays as minutes, days without known places saying so, and the button shows "Copied" for a moment

---

### User Story 032:

- **Summary:** Copy the full location detail as JSON when I want the machine shape
- **Status:** implemented in [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59), [5f00862](https://github.com/idvorkin/context-grabber/commit/5f00862); verified on the phone

#### Use Case:
- **As** someone running my own analysis
- **I want to** copy clusters, the per-stay timeline and my fresh coordinates as JSON from the Location sheet
- **so that** the detail the coach briefing dropped is still one tap away

#### Acceptance Criteria:
- **Scenario:** Pulling the detail
- **Given:** location history exists
- **When:** I tap Copy Location Details
- **Then:** the clipboard holds JSON with `clusters`, `timeline`, the summary string and a `location` refreshed like the coordinate copy (falling back to cached), with the same Refreshing / Copied / Copied (cached) feedback

---

### User Story 033:

- **Summary:** This week against last week
- **Status:** not implemented (CC-6 in `docs/user-needs.md`, carried forward). No issue yet.

#### Use Case:
- **As** Larry's client asked "is that better or worse than usual?"
- **I want to** have the previous week's daily entries or per-metric medians beside this week's
- **so that** a trend is visible from the export alone

#### Acceptance Criteria:
- **Scenario:** Sharing with a comparison
- **Given:** fourteen days of cached health data
- **When:** I share the summary
- **Then:** the payload carries last week alongside this week for the same metrics, with the field names unchanged for this week

---

### User Story 034:

- **Summary:** The tally in the export
- **Status:** not implemented (promised in the tap-counter spec; `counter` is not in the summary today). No issue yet.

#### Use Case:
- **As** someone who counted 24 squats with the tally
- **I want to** have today's count in the summary
- **so that** the thing I tapped all day reaches the coach

#### Acceptance Criteria:
- **Scenario:** A counted day
- **Given:** the tally reads 24
- **When:** I share the summary
- **Then:** `today.counter` is 24, and a day with no taps carries null

---

### User Story 035:

- **Summary:** Reflections and mood in the export
- **Status:** not implemented (journal, gratitude and mood are logged but the summary carries none of them). No issue yet.

#### Use Case:
- **As** someone whose week's texture is in the gratitudes
- **I want to** have today's affirmations, gratitudes and mood / energy scores in the summary, voice notes as short transcripts or "voice note, 12s"
- **so that** Larry sees intention and feeling beside body and place

#### Acceptance Criteria:
- **Scenario:** A logged day
- **Given:** two gratitudes and a mood of 2 today
- **When:** I share the summary
- **Then:** the payload carries a journal section with both entries and a mood section with the scores, under stable field names

---

### User Story 036:

- **Summary:** Context reaches Larry without me tapping
- **Status:** not implemented; asks: [#84](https://github.com/idvorkin/context-grabber/issues/84). The Call tab already sends a location fix to the bridge at call start and on significant moves ([b88f34e](https://github.com/idvorkin/context-grabber/commit/b88f34e), [#107](https://github.com/idvorkin/context-grabber/issues/107)); the full summary does not travel that way yet.

#### Use Case:
- **As** someone who forgets to share before the call
- **I want to** have the summary pushed to Larry at call start, or on arrival at a known place
- **so that** the coach never starts cold because I did not tap

#### Acceptance Criteria:
- **Scenario:** Starting a call unprepared
- **Given:** I have not shared today
- **When:** the call connects
- **Then:** Larry has this week's summary before the first exchange
