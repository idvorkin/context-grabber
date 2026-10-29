# Feeding Larry: the context export

Getting the week in front of the coach in one tap, shaped so a thoughtful human could give advice on it cold.

Part of the [user stories](README.md); persona and format are described there. The export is a contract: field names, units and structure stay stable across versions and across the Swift port.

---

### User Story 020:

- **Summary:** One tap sends Larry today's headline and the last seven days
- **Status:** implemented in [7b52df6](https://github.com/idvorkin/context-grabber/commit/7b52df6), [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `share.test.ts`, `snapshot.test.ts` and on the phone (every coaching call). Supersedes CC-1 in `docs/user-needs.md`; native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); the phone still to be checked by Igor.

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
- **Status:** implemented in [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `share.test.ts` and on the phone (payload fits in an iMessage); native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); the phone still to be checked by Igor.

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
- **Status:** implemented in [06a20b0](https://github.com/idvorkin/context-grabber/commit/06a20b0), [ff18ef3](https://github.com/idvorkin/context-grabber/commit/ff18ef3), [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `clustering_v2.test.ts` (real fixture) and on the phone. Supersedes CC-5; native app: [622b3e5](https://github.com/idvorkin/context-grabber/commit/622b3e5), [6c23307](https://github.com/idvorkin/context-grabber/commit/6c23307), this week and last from the trail at share time, a week labelled by how far back it is; [ae8db8d](https://github.com/idvorkin/context-grabber/commit/ae8db8d): a stay counts whole in the week it began in, the weeks matching the whole real trail on each of its last 14 days; host-verified by `just native-test` (`PlacesSummaryTextTests`, `PlacesFixtureTests`); the phone still to be checked by Igor.
- **Issues:** [#543](https://github.com/idvorkin/context-grabber/issues/543)

#### Use Case:
- **As** someone whose "home by 6pm" goal Larry checks
- **I want to** include a weekly per-place rollup and the last three days as named stays with local times
- **so that** Larry sees "Office Tue 9am–5pm (8h)" rather than a list of points

#### Acceptance Criteria:
- **Scenario:** A normal week
- **Given:** Home, Office and Gym are known places
- **When:** I share the summary
- **Then:** `places.weekly` reads like "This week: Home 92h, Office 28h, Gym 4h" with places in descending hours, `places.recent` has at most the last three days in 12-hour local time with transits of an hour or more, and with no location history `places` is null rather than the share failing

---

### User Story 023:

- **Summary:** Roles lead the export — who I have been being, before the numbers
- **Status:** implemented in [54861c5](https://github.com/idvorkin/context-grabber/commit/54861c5); verified by `roles.test.ts`, `share.test.ts` and on the phone; native app: not yet — the `roles` key is left out until roles move rather than sent as null ([622b3e5](https://github.com/idvorkin/context-grabber/commit/622b3e5), [#543](https://github.com/idvorkin/context-grabber/issues/543)) (context-grabber-3ss.18).

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
- **Status:** implemented in [dc6546e](https://github.com/idvorkin/context-grabber/commit/dc6546e); verified by `accessoryLog.test.ts`, `share.test.ts` and on the phone; native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store), from the native accessory log; the phone still to be checked by Igor.

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
- **Status:** implemented in [14e81d0](https://github.com/idvorkin/context-grabber/commit/14e81d0), [7d2c9c9](https://github.com/idvorkin/context-grabber/commit/7d2c9c9); verified by `health.test.ts`, `sleep.test.ts` and on the phone. Supersedes CC-7; native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); the phone still to be checked by Igor.; native: a night counted once on the bed day (bead byo): [1f90c41](https://github.com/idvorkin/context-grabber/commit/1f90c41), verified by `testHoursByNightCountANightOnceOnTheBedDay` and the regenerated fixture parity tests (host)
- **Issues:** [#11](https://github.com/idvorkin/context-grabber/issues/11)

#### Use Case:
- **As** someone who was told "you slept 13 hours" by an app once
- **I want to** export the merged asleep hours, attributed to the night I went to bed
- **so that** Larry's sleep feedback is about sleep, not about two devices both watching me

#### Acceptance Criteria:
- **Scenario:** A night the Watch and phone both saw
- **Given:** overlapping samples from two sources for one night
- **When:** I share the summary
- **Then:** that day's `sleepHours` is the merged asleep total (Core + Deep + REM, not In Bed), a nap after noon counts toward the following night, and `bedtime` / `wakeTime` are human short times; in the native app a night that crosses midnight is one value, on the day I went to bed, never split across two days

---

### User Story 026:

- **Summary:** Meditation and exercise per day, with the zeros visible
- **Status:** implemented in [8361ad4](https://github.com/idvorkin/context-grabber/commit/8361ad4), [7b52df6](https://github.com/idvorkin/context-grabber/commit/7b52df6), [238cd20](https://github.com/idvorkin/context-grabber/commit/238cd20); verified by `health.test.ts`, `weekly.test.ts` and on the phone. Supersedes CC-2 and CC-3; native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); the phone still to be checked by Igor.

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
- **Status:** implemented in [7b52df6](https://github.com/idvorkin/context-grabber/commit/7b52df6), [b3f5146](https://github.com/idvorkin/context-grabber/commit/b3f5146); verified by `share.test.ts` and on the phone. Supersedes CC-4 and closes Larry's "HRV always null" gap from `docs/user-needs.md`; native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); the phone still to be checked by Igor.

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
- **Status:** implemented in [b3f5146](https://github.com/idvorkin/context-grabber/commit/b3f5146), [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59); verified by `share.test.ts` and on the phone. The per-set breakdown from the workout-analysis spec is not in the summary export (the analysis screen's own Share JSON carries it); native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); the phone still to be checked by Igor.
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
- **Status:** implemented in [381d143](https://github.com/idvorkin/context-grabber/commit/381d143), [c6c0106](https://github.com/idvorkin/context-grabber/commit/c6c0106), [7d2c9c9](https://github.com/idvorkin/context-grabber/commit/7d2c9c9); verified by `snapshot.test.ts` and on the phone; native app: [258a66b](https://github.com/idvorkin/context-grabber/commit/258a66b), [cb8e213](https://github.com/idvorkin/context-grabber/commit/cb8e213), byte-identical to the TypeScript export: verified by `just native-test` (`MirrorFixtureTests`) and `just native-test-sim` (fixture and the simulator's Health store); `location` and `locationClusters` are null until Places moves (step 5); the phone still to be checked by Igor.

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
- **Status:** implemented in [7d1b64d](https://github.com/idvorkin/context-grabber/commit/7d1b64d), [0e85a51](https://github.com/idvorkin/context-grabber/commit/0e85a51), [863631b](https://github.com/idvorkin/context-grabber/commit/863631b), [ae0c1d0](https://github.com/idvorkin/context-grabber/commit/ae0c1d0); verified on the phone (issues closed after use); native app: with Places (step 5).
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
- **Status:** implemented in [5f00862](https://github.com/idvorkin/context-grabber/commit/5f00862); verified by `places_summary.test.ts` and on the phone; native app: with Places (step 5).

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
- **Status:** implemented in [22bbf59](https://github.com/idvorkin/context-grabber/commit/22bbf59), [5f00862](https://github.com/idvorkin/context-grabber/commit/5f00862); verified on the phone; native app: with Places (step 5).

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

---

### User Story 037:

- **Summary:** What I finished — workouts and breathing sessions — rides along to Larry
- **Status:** native app only: implemented in [0ddda7b](https://github.com/idvorkin/context-grabber/commit/0ddda7b); verified by `ActivityLogTests` and `MirrorFixtureTests` (the fixture week's summary plus the trailing section, and the old export unchanged without it), and on the simulator (a 2 s × 2 breathing session and a one-round custom workout each wrote an `activity_logged` line and a row); a shared summary from the phone still to be checked by Igor
- **Issues:** [#139](https://github.com/idvorkin/context-grabber/issues/139)
- **Spec:** [Swift-native app — step 4](../superpowers/specs/2026-10-04-swift-native-app-design.md#the-mirror-and-grab-context-in-the-native-app-step-4)

#### Use Case:
- **As** Larry's client who trains with the Gym Timer and breathes with the circle
- **I want to** have every workout and breathing session I finish recorded and sent in the summary
- **so that** Larry knows what I actually did, not just what Health guessed

#### Acceptance Criteria:
- **Scenario:** A workout and a breathing session
- **Given:** this morning I ran the 30 SEC preset to *done* and a 5-minute box-breathing session to *Done*, and yesterday I reset a workout half way
- **When:** I share the summary from Today in Grabber Native
- **Then:** `activities` lists two entries, newest first, each with kind (`gym_timer` / `breathing`), a name such as *30 SEC · 6 rounds* or *Box breathing · 8 s · 9 cycles*, minutes, an ISO-8601 UTC timestamp and the local `date`; the reset workout is not there; and the session log has an `activity_logged` line for each


---

### User Story 038:

- **Summary:** Share anything to Grabber Native and it waits in my Inbox
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); verified by `InboxTests` (host: newest first, the count, sent and refused leaving it, delete taking the image, an empty note, an unreadable file named not fatal; previews are bounded thumbnails since [8589513](https://github.com/idvorkin/context-grabber/commit/8589513)); the simulator build, the `GRABBER_INBOX_FIXTURE` Inbox and a swipe in the next build turn; sharing from Safari, Notes and Photos in aeroplane mode on the phone still for Igor; any text the share sheet offers (RTF and HTML turned plain) and a copyable reason when a share cannot be read, in [d5095e8](https://github.com/idvorkin/context-grabber/commit/d5095e8); the tile's picture, the raccoon posting a letter (#395): [3efd0b8](https://github.com/idvorkin/context-grabber/commit/3efd0b8), verified by `scripts/native/test-tile-art.sh` (host: transparent, square, filling the tile) and by eye on light and dark; the phone in the next build turn
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305), [#395](https://github.com/idvorkin/context-grabber/issues/395) (the tile's picture)
- **Spec:** [Share into Grabber Native, and Larry's inbox](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client who comes across things worth talking about all day
- **I want to** share a link, some text or a photo from any app to Grabber Native, with a note
- **so that** it is kept for Larry the moment I see it, even with no signal

#### Acceptance Criteria:
- **Scenario:** Sharing from three apps in aeroplane mode
- **Given:** the phone is in aeroplane mode
- **When:** I share a Safari link, a Notes text and a Photos image to *Grabber Native*, adding a note to one and tapping *Add to Inbox* (*Start a chat* since #438, story 275) each time
- **Then:** each card closes at once, the Inbox lists the three newest first with what each is, the note, the link's site and when, the Inbox tile (the raccoon posting a letter) counts three not yet sent, a swipe deletes one and the count follows, and when I next open the app the log has an `inbox` added line for each with its kind and size but never its content

---

### User Story 039:

- **Summary:** What is in my Inbox reaches Larry, once each
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); verified by `InboxTests` (host: the request per cockpit#63 with the Cockpit's Origin and no token, every answer class, a HEIC as JPEG, an image over the cap made smaller, oldest first and stopping at the first unreachable, an unreadable image refused without asking, a fixture never sent; an item deleted while the send is out is not sent, in [8589513](https://github.com/idvorkin/context-grabber/commit/8589513)); a share made while a send is out goes in one more pass when it ends, in [3bf50ec](https://github.com/idvorkin/context-grabber/commit/3bf50ec); a send over the tailnet from the phone still for Igor; since #438 an item goes to the Cockpit's chat, not its inbox (stories 274, 275)
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305)
- **Spec:** [Share into Grabber Native, and Larry's inbox — phase 2](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client with things waiting in the Inbox
- **I want to** have them reach Larry's inbox on their own when the phone can reach the Cockpit
- **so that** Larry sees what I shared, the note and when, without me sending anything

#### Acceptance Criteria:
- **Scenario:** Back on the tailnet
- **Given:** three items wait in the Inbox, one of them a HEIC photo
- **When:** I open Grabber Native with the Cockpit reachable
- **Then:** each goes to Larry once, oldest first, and reads *sent to Larry* with the time, the photo arrives as a JPEG, and the log has an `inbox` sent line for each with the Cockpit's answer

---

### User Story 260:

- **Summary:** An item Larry's inbox refuses says why and is never resent
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); verified by `InboxTests` (host: a 4xx answer recorded as refused with the Cockpit's reason and not sent again, an unreadable image refused without asking); the copyable reason on the phone still for Igor
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305)
- **Spec:** [Share into Grabber Native, and Larry's inbox — phase 2](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client with something in the Inbox the Cockpit cannot take
- **I want to** see the Cockpit's reason, copyable, instead of it trying forever
- **so that** I can fix it or delete it, and nothing else waits behind it

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses an item
- **Given:** an item waits in the Inbox that the Cockpit will answer with a 4xx (too big, an unreadable image)
- **When:** I open Grabber Native with the Cockpit reachable
- **Then:** the item reads *Larry's inbox refused it* with the Cockpit's reason, copyable, it is not sent again on later opens, the items after it still go, and the log has an `inbox` refused line with the status and the reason

---

### User Story 261:

- **Summary:** With the Cockpit out of reach, the Inbox waits for the next open
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); #406's wording and the failed-send regression in [7efc955](https://github.com/idvorkin/context-grabber/commit/7efc955); verified by `InboxTests` (host: no answer or a 5xx leaves the item waiting and stops the send, oldest first; a transport failure retains the item and a later success sends it once); off the tailnet on the phone still for Igor
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305), [#406](https://github.com/idvorkin/context-grabber/issues/406)
- **Spec:** [Share into Grabber Native, and Larry's inbox — phase 2](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client away from the tailnet
- **I want to** have what I shared wait, not fail
- **so that** it reaches Larry by itself once the phone can reach the Cockpit again

#### Acceptance Criteria:
- **Scenario:** Off the tailnet
- **Given:** three items wait in the Inbox
- **When:** I open Grabber Native with the Cockpit unreachable or answering 5xx
- **Then:** all three stay *Not sent yet*, the log has one `inbox` failed line with the reason and the rest of that send waits, and on the next open with the Cockpit reachable they go, oldest first

---

### User Story 262:

- **Summary:** Start a new chat with the keyboard or dictation
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); verified by `InboxDraftTests` and the full `just test` (host); the sheet, dictation and pasting on the phone not yet; #424: the + is a floating button in the lower right in [066dae4](https://github.com/idvorkin/context-grabber/commit/066dae4); verified by `just test` (host) and the simulator build; on the phone not yet. #536: the + opens a new thread with the ordinary bar instead of a sheet in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d); verified by `ChatNewThreadUITests` (simulator: the + opens an empty *New chat* thread with the bar, its mic and Paste image, and no sheet); sending from it on the phone not yet.
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405), [#424](https://github.com/idvorkin/context-grabber/issues/424), [#536](https://github.com/idvorkin/context-grabber/issues/536)
- **Spec:** [Chat with Larry in Grabber Native — A new chat](../superpowers/specs/2026-10-25-native-chat-design.md); [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** tap Chat's + and type, or use the keyboard's dictation or the chat mic, in a new thread
- **so that** I can start a conversation with Larry without leaving the app or learning a second screen

#### Acceptance Criteria:
- **Scenario:** Starting a new chat
- **Given:** Chat is open, empty or populated, with one large round + fixed at the lower right above the safe area, no toolbar +, and room to scroll the last row fully above the button
- **When:** I tap the fixed +, enter text by typing or dictation, and tap Send
- **Then:** an empty thread titled *New chat* opened with the ordinary bar and the keyboard up; my message shows at once as *Not sent yet*, is kept on the phone and sent to Larry, the thread takes that message's first line as its title, and once the Cockpit has it this screen is the live thread

- **Scenario:** Leaving without sending
- **Given:** I tapped + and wrote nothing, or wrote and did not send
- **When:** I go back to the list
- **Then:** no thread was started
---

### User Story 263:

- **Summary:** Keep writing in the chat I just started
- **Status:** native app only: Add another implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); #536: replaced by the new thread's own bar in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d) (simulator: the bar is there; the hold-back until the first message lands on the phone not yet)
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405), [#536](https://github.com/idvorkin/context-grabber/issues/536)
- **Spec:** [Chat with Larry in Grabber Native — A new chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** stay in the new chat after its first message and add the next thought
- **so that** I can capture several thoughts in a row

#### Acceptance Criteria:
- **Scenario:** The next message in a new chat
- **Given:** I sent the first message of a new chat
- **When:** I write the next one
- **Then:** the bar has emptied and stays up; once the first message has reached Larry the next one sends into the same thread; until then the bar says the next goes once the first reaches Larry, and nothing I wrote is lost
---

### User Story 264:

- **Summary:** Paste a picture into a new chat
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025), the picture kept as copied (its format and orientation) in the #405 review fix; verified by `InboxDraftTests` and the full `just test` (host). #422: the note and its pasted picture share one box in [bfcd805](https://github.com/idvorkin/context-grabber/commit/bfcd805). #536: the new thread's bar pastes it, as every thread's does, in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d); verified by `ChatNewThreadUITests` (simulator: Paste image is on the new thread's bar); pasting on the phone not yet.
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405), [#422](https://github.com/idvorkin/context-grabber/issues/422), [#536](https://github.com/idvorkin/context-grabber/issues/536)
- **Spec:** [Chat with Larry in Grabber Native — A new chat](../superpowers/specs/2026-10-25-native-chat-design.md); [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** paste a clipboard image and see a small preview
- **so that** I can send Larry a picture directly from the app

#### Acceptance Criteria:
- **Scenario:** Starting a chat with a clipboard image
- **Given:** the clipboard holds an image and a new chat is open
- **When:** I tap Paste image, optionally enter text, and tap Send
- **Then:** the picture's preview and Remove image appear above the bar before sending, and the picture is sent as copied and the right way up, with the text as its note, as the new thread's first message
---

### User Story 265:

- **Summary:** An empty draft cannot be added
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); verified by `InboxDraftTests` (host); on the phone not yet
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405)
- **Spec:** [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** be stopped from adding a blank item
- **so that** nothing empty reaches Larry

#### Acceptance Criteria:
- **Scenario:** Adding only whitespace
- **Given:** a new chat is open (#536: the + opens a thread, not a sheet)
- **When:** I enter only spaces or new lines
- **Then:** Send stays disabled and nothing is saved

---

### User Story 266:

- **Summary:** Leaving a new chat unsent saves nothing
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); on the phone not yet
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405)
- **Spec:** [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** back out of a new chat
- **so that** a half-formed thought does not reach Larry

#### Acceptance Criteria:
- **Scenario:** Cancelling a draft
- **Given:** a new chat (#536) holds text or a pasted image, not sent
- **When:** I go back to the list
- **Then:** no thread is started and nothing is sent

---

### User Story 267:

- **Summary:** A failed save keeps the draft
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); verified by `InboxDraftTests` (host); on the phone not yet
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405)
- **Spec:** [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** keep what I wrote when the save fails
- **so that** I can try again without retyping

#### Acceptance Criteria:
- **Scenario:** Saving fails
- **Given:** a new chat's bar (#536) holds text or a pasted image
- **When:** I tap Send and the message cannot be written
- **Then:** the bar keeps the draft intact and a copyable error explains why

---

### User Story 268:

- **Summary:** Remove a pasted picture before adding
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); on the phone not yet
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405)
- **Spec:** [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** take back a picture I pasted by mistake
- **so that** only what I meant reaches Larry

#### Acceptance Criteria:
- **Scenario:** Removing the pasted image
- **Given:** a new chat's bar (#536) shows a pasted image's preview
- **When:** I tap Remove image
- **Then:** the preview goes and the text I wrote stays

---

### User Story 269:

- **Summary:** My Inbox waits offline and sends itself when the network returns
- **Status:** native app only: implemented in [7efc955](https://github.com/idvorkin/context-grabber/commit/7efc955); the retry on a path change after a failed send (Codex on #409) in [22c36ef](https://github.com/idvorkin/context-grabber/commit/22c36ef), and for a change that came while the failing send was out in [77d67d6](https://github.com/idvorkin/context-grabber/commit/77d67d6); a network that comes up on demand (an on-demand VPN) counts as available in [4be2267](https://github.com/idvorkin/context-grabber/commit/4be2267); verified by `InboxSendPolicyTests` and `InboxTests` with the full `just test` (host); the offline line and the send on the network's return on the phone not yet; #565, a failed send tried again on its own while the app is open (30 s doubling to 5 min) in [5a76646](https://github.com/idvorkin/context-grabber/commit/5a76646), verified by `InboxSendPolicyTests` (host) and a simulator build; the `inbox` backoff line on the phone not yet
- **Issues:** [#406](https://github.com/idvorkin/context-grabber/issues/406), [#565](https://github.com/idvorkin/context-grabber/issues/565)
- **Spec:** [Share into Grabber Native, and Larry's inbox — phase 2](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client sharing things away from a network
- **I want to** see that my items have not been sent and have them send when I am back online
- **so that** I trust they are kept without remembering to reopen the app

#### Acceptance Criteria:
- **Scenario:** The network returns with the app running
- **Given:** items wait in the Inbox after losing the network or failing to reach the Cockpit, each reads *Not sent yet* and the tile counts them; while the phone is offline the screen quietly says “No network — these go to Larry when you're back online” without attempting a send
- **When:** the network returns while the app is running, including a tailnet reconnect after a failed send while Wi-Fi or cellular stayed available
- **Then:** the offline line disappears if shown and waiting items send automatically without overlapping sends; a network that comes up on demand (an on-demand VPN) counts as available, so the send is tried and no offline line shows; after a failure (or during the send that then fails), a changed interface or metered/constrained access retries once after a burst settles for half a second, identical updates and an empty Inbox never retry; a failed send leaves its item waiting and counted, and the log records `inbox` offline_skipped, network_back and network_changed events as applicable

- **Scenario:** The Cockpit is away while the app stays open (#565)
- **Given:** the phone is online but the Cockpit is not answering, and a message waits after a send that did not get through
- **When:** the app stays open
- **Then:** the message is tried again on its own after 30 seconds, then a minute, two, four, and every five minutes after that, each wait logged as an `inbox` backoff line; the wait starts over after a send gets through, and the tries stop once nothing waits or the phone goes offline; a refused message is never tried again

---

### User Story 270:

- **Summary:** Everything the app collects is archived off the phone on its own, once each
- **Status:** implemented in [f4080b8](https://github.com/idvorkin/context-grabber/commit/f4080b8), [78961b4](https://github.com/idvorkin/context-grabber/commit/78961b4) and [85e5b66](https://github.com/idvorkin/context-grabber/commit/85e5b66) (the phone half; the Cockpit's `POST /archive` is its story 124), plus the review round (the next slots asked for before a background run, Health skipped while the phone is locked); verified on the host (`just test`: `ArchiveTests`, swift-format, SwiftLint) and the simulator (`just native-test-sim` 45/45, the archive hook included). Not yet verified: the phone, and the Cockpit's `/archive` endpoint (cockpit's archive-endpoint branch); until it is live a run stops on the error and retries later.
- **Why:** Igor, Cockpit chat 2026-10-19: "let's archive all the stats we can do it every four hours. Be sure to Delta stamp them somehow so we don't get duplicates. Should work for history as a one off, and then as habits happen. Then maybe final daily batch. Since all guid marked no duplicates"
- **Issues:** context-grabber-3il
- **Spec:** [Everything off the phone: the stats archive](../superpowers/specs/2026-10-19-native-stats-archive-design.md)

#### Use Case:
- **As** Larry's client whose phone keeps its trail thirty days and its Health history only on the phone
- **I want to** have everything the app collects copied to the Cockpit's archive on its own, a delta every few hours and the whole history the first time
- **so that** Larry has the whole record, and losing or replacing the phone loses none of it

#### Acceptance Criteria:
- **Scenario:** A delta every few hours, history the first time
- **Given:** Today has asked for Health, the Cockpit is reachable, and the trail and Health hold records the archive has not seen
- **When:** four hours pass since the last run (a background refresh, or the app comes to the front), or the end-of-day batch runs
- **Then:** every new point and sample goes to the Cockpit in pages, once each (a lost answer sends the same page again and the Cockpit counts it as already there), the cursor of each stream moves only after the Cockpit took the page, an unreachable Cockpit stops the run at its first page and the next run sends it again, and the log has one `archive` line per page with counts and never a record; launch remains safe with an existing database, and a simulator sends only to an explicitly supplied test destination; a run while the phone is locked sends the trail, says once that Health was skipped, and is not counted, so the app's next time in front sends Health's share; a delayed daily batch keeps its pending slot across midnight, and a rolled-back import cannot enter the archive or advance its cursor

---

### User Story 271:

- **Summary:** The daily strip's days are archived too, each day as the strip shows it
- **Status:** implemented in [d06ac21](https://github.com/idvorkin/context-grabber/commit/d06ac21); verified on the host (`just test`: `ArchiveTests`, swift-format, SwiftLint) and the simulator (`just native-test-sim`, the archive hook included). Not yet verified: the phone.
- **Why:** Igor, 2026-10-19, about story 270's archive: "Did it include when I did balloons and magic, not just health?"
- **Issues:** [#415](https://github.com/idvorkin/context-grabber/issues/415)
- **Spec:** [Everything off the phone: the stats archive](../superpowers/specs/2026-10-19-native-stats-archive-design.md), "The daily strip"

#### Use Case:
- **As** Larry's client who taps balloons, magic, gym, meditation and journal on the home screen's strip
- **I want to** have those days in the Cockpit's archive beside Health and the trail, with the values the strip shows
- **so that** Larry can read the whole history of what I did, not just what Health saw, and a changed day is never stuck at its first value

#### Acceptance Criteria:
- **Scenario:** The strip's history once, then each changed day
- **Given:** the strip holds days on this phone and days restored over iCloud from the iPad, and the Cockpit is reachable
- **When:** an archive run goes (the first one after this build, then every few hours and at the end of the day)
- **Then:** the first run sends every day each item has counted, one stream per item, with the value the strip shows (counts added up across devices, a check's latest change); later runs send only the days whose value has changed since the archive last took them, whatever their age (a backdated check, an edited week, the iPad's taps arriving late), each as a newer observation of that day, so the newest observation per day matches the strip; a day taken back to nothing goes as 0, a run with no strip change sends nothing for the strip, and the strip goes while the phone is locked

---

### User Story 272:

- **Summary:** My conversations with Larry are a list of threads, the ones he answered marked
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: the list as the Cockpit serves it, newest first, a failed answer read as no list), `sim-smoke.sh` against `scripts/native/fake-cockpit.py` and simulator screenshots (the list, the unread dot); against the real Cockpit once cockpit#64 is merged
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who talks to him about several things at once
- **I want to** open *Chat* and see each conversation, the ones with a reply I have not read marked
- **so that** I can pick up any of them without Telegram

#### Acceptance Criteria:
- **Scenario:** Opening Chat
- **Given:** the Cockpit has chat threads, one with a reply from Larry I have not read
- **When:** I tap the *Chat* tile
- **Then:** every thread is listed newest activity first with its title, who said the last thing and what, and when; the unread one is marked; finished ones fold under *Done (n)* by the Cockpit's own rule; and the tile counts unread threads plus my messages not yet sent

---

### User Story 273:

- **Summary:** A thread reads like a chat and keeps up by itself
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: messages with 👀/🏆 receipts and images, the seen request, an attachment address only for a ref the Cockpit mints), `sim-smoke.sh` (a link opens the thread, it is read and marked seen) and simulator screenshots (bubbles, links); on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client in the middle of a conversation
- **I want to** see my messages and his as bubbles that update while I watch
- **so that** it feels like talking, not refreshing a page

#### Acceptance Criteria:
- **Scenario:** Reading a thread
- **Given:** a thread with my messages, Larry's replies and an image
- **When:** I open it
- **Then:** mine are on the right and his on the left, oldest at the top, opening at the newest; links are tappable and the image shows inline and full screen on a tap; under each of mine is *sent*, 👀 once Larry has seen it, or 🏆 with his note once it is done; and the thread reads as read here and on the laptop

---

### User Story 274:

- **Summary:** What I write in a thread waits on the phone and reaches Larry once
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: the message to its thread's path with its id and the app as source, an image uploaded first and named by its ref), `InboxTests` (oldest first), `sim-smoke.sh` (one `POST /chat/<key>`, the text never in the log); the phone's copy dropped once the thread shows it in the review round, not yet verified on any rung; a send over the tailnet from the phone once cockpit#64 is merged; the bar emptied after a send with the keyboard up for the next ([46ca1f7](https://github.com/idvorkin/context-grabber/commit/46ca1f7), #449) verified by `ChatComposeClearsUITests` (simulator: typed, sent, the field empty, focused and Send disabled, the next message typed straight on); simulator typing does not reproduce the phone's leftover text, so on the phone not yet, where its `bar_after_send` line will say
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#449](https://github.com/idvorkin/context-grabber/issues/449)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client typing or dictating on a bad connection
- **I want to** send a message, with a pasted picture if I like, and trust it arrives exactly once
- **so that** nothing I say is lost or doubled

#### Acceptance Criteria:
- **Scenario:** Sending
- **Given:** a thread is open
- **When:** I type or dictate a message, optionally paste an image, and tap send
- **Then:** it appears at once marked *Not sent yet* and the field is empty with the keyboard still up for my next message, so the text is never left behind to be sent twice; it goes to the Cockpit, and then reads *sent* with Larry woken once; once the thread shows it from the Cockpit, the phone keeps no copy of it or its picture

---

### User Story 275:

- **Summary:** Each share starts its own thread with Larry
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: a new thread's title from the note, the text, the link's site or *Photo, <date>*; one `POST /chat` with the item's id), a share itself not yet made on any rung; sharing from Safari on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who shares things worth talking about all day
- **I want to** have each share become its own conversation
- **so that** Larry and I can talk about it on its own thread

#### Acceptance Criteria:
- **Scenario:** Sharing a link
- **Given:** I share a Safari link to *Grabber Native* with the note "worth a read"
- **When:** I tap *Start a chat*
- **Then:** the card closes at once, Chat lists a thread titled "worth a read" under *Not sent yet* until it reaches the Cockpit, and then as a thread whose first message is the link and the note

---

### User Story 276:

- **Summary:** A reply from Larry notifies me while the app is closed
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: only a new unread reply from Larry is due, once); the background check, the notification and its tap only on the phone, not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native — Hearing back](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who leaves the app after writing to him
- **I want to** be told when he answers
- **so that** I do not need Telegram to know there is a reply

#### Acceptance Criteria:
- **Scenario:** Larry answers while the app is away
- **Given:** I allowed notifications when I first sent a message, and the app is in the background
- **When:** Larry replies and iOS next runs the app's background check (it decides when; minutes to hours)
- **Then:** one notification per thread, *Larry*, the thread's title and the reply's first line; tapping it opens that thread

---

### User Story 277:

- **Summary:** What I shared before Chat is still there, under Earlier shares
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: an item sent before Chat, and a file from before Chat with no thread fields, read as an earlier share); on the phone with its real Inbox not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native — What was in the Inbox](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with things already in the Inbox when Chat arrives
- **I want to** find them, and have the unsent ones go on as chats
- **so that** nothing shared before the change is lost

#### Acceptance Criteria:
- **Scenario:** The first launch with Chat
- **Given:** the Inbox held two items already sent to Larry's inbox and one not yet sent
- **When:** I open Chat
- **Then:** the unsent one goes out as a new thread, and the two sent ones are under *Earlier shares (2)* at the bottom, read-only, each removable with a swipe

---

### User Story 278:

- **Summary:** With the Cockpit out of reach, Chat says why and keeps what I wrote
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by simulator screenshots (*Not sent yet*, the copyable error with the Cockpit down); on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client whose laptop is asleep or off the tailnet
- **I want to** see that Chat could not reach the Cockpit, and why
- **so that** I know my messages are safe and the problem is not on the phone

#### Acceptance Criteria:
- **Scenario:** The Cockpit out of reach
- **Given:** the phone is online but the Cockpit does not answer
- **When:** I open Chat
- **Then:** a copyable line says the chats could not be read and why, and what I wrote that has not gone yet is still listed under *Not sent yet*; with no network at all the quiet offline line shows instead

---

### User Story 279:

- **Summary:** Larry's reply appears in the open thread while I watch
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by a simulator screenshot (Larry's reply appearing without a refresh); a thread that cannot be read logs once per spell in the review round, not yet verified on any rung; on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client waiting on his answer
- **I want to** see it arrive in the thread I have open
- **so that** it feels like talking, not refreshing a page

#### Acceptance Criteria:
- **Scenario:** Larry answers while I watch
- **Given:** the thread is open
- **When:** Larry replies
- **Then:** his reply appears within a few seconds with no pull or tap, and the thread stays read; if the thread cannot be read, a copyable line says why

---

### User Story 300:

- **Summary:** A message sent offline goes once when the network returns; a refused one says why
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: a refused upload refusing the message, an unreachable Cockpit stopping the run) and `InboxTests` (a failure kept for later, a deleted one never sent); never sent twice across a lost answer rests on the Cockpit's dedupe by id (cockpit#64, not merged) and is not verified on any rung; on the phone not yet; #565, *The Cockpit isn't answering* on the list, the thread and a waiting message in [5a76646](https://github.com/idvorkin/context-grabber/commit/5a76646), verified by `ChatTests` (host: a timeout is the Cockpit away, a 503 is not) and a simulator build; on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#565](https://github.com/idvorkin/context-grabber/issues/565)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client typing on a bad connection
- **I want to** have what I wrote go by itself once the network is back, and hear why if Larry refuses it
- **so that** nothing I say is lost, doubled or silently dropped

#### Acceptance Criteria:
- **Scenario:** Offline or refused
- **Given:** no network, or the Cockpit refuses the message (too big, an unreadable image)
- **When:** I send
- **Then:** offline it stays *Not sent yet* and goes by itself when the network returns, never twice even if an answer was lost; refused it says *Larry refused it* with the reason, copyable, and is never sent again; a long press deletes it

- **Scenario:** The Cockpit isn't answering (#565)
- **Given:** the phone is online but the Cockpit times out or cannot be reached
- **When:** I open Chat or a thread, or a message I wrote tries to go
- **Then:** the list and the thread say *The Cockpit isn't answering — your messages are kept and go when it does*, copyable, with the underlying reason; a waiting message reads *Not sent yet · the Cockpit isn't answering*; the *No network* line is only for the phone being offline, and a Cockpit that answers with an error keeps its plain reason

---

### User Story 301:

- **Summary:** The + starts a new thread with Larry
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `sim-smoke.sh` (a message written for a new thread, through the `GRABBER_CHAT_SEND` hook, goes up as one `POST /chat` with the app as source and its first line as the title, the text never in the log) and a simulator screenshot (a new thread written while the Cockpit was down went up when it came back); on the phone not yet. #536: the + opens a new thread with the ordinary bar instead of a sheet in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d), each first-message attempt its own message in [8202fec](https://github.com/idvorkin/context-grabber/commit/8202fec); verified by `ChatNewThreadTests` (host) and `ChatNewThreadUITests` (simulator, against the fake Cockpit); on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#536](https://github.com/idvorkin/context-grabber/issues/536)
- **Spec:** [Chat with Larry in Grabber Native — A new chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with something new to talk about
- **I want to** start a conversation from Chat itself
- **so that** a new subject does not get buried in an old thread

#### Acceptance Criteria:
- **Scenario:** Starting one from the +
- **Given:** Chat is open
- **When:** I tap + and send a message from the new thread's bar
- **Then:** a new thread is started, titled with the message's first line, and the same screen becomes that thread once the Cockpit has it; the next message goes into it, and another new thread is another tap of +

---

### User Story 302:

- **Summary:** A reply I have already read, a Done thread, or what was waiting at install never notifies
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8), the Done thread and the first check in the review round; verified by `ChatTests` (host: one already read elsewhere is not due, a Done thread is not, the first check with nothing recorded raises none); the background check on the phone not yet
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438)
- **Spec:** [Chat with Larry in Grabber Native — Hearing back](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who reads Larry on the laptop too
- **I want to** be notified only of replies I have not seen
- **so that** a notification always means something new

#### Acceptance Criteria:
- **Scenario:** Already read
- **Given:** I read the reply on the laptop, the app showed it, the thread is Done, or it was waiting before the app's first background check
- **When:** the background check runs
- **Then:** nothing is notified for it

---

### User Story 303:

- **Summary:** I speak a message in a thread and read the words before I send them
- **Status:** native app only: implemented with Deepgram in [2015662](https://github.com/idvorkin/context-grabber/commit/2015662), moved to the problem report's Apple dictation with the five-minute cap in [f040853](https://github.com/idvorkin/context-grabber/commit/f040853), with the microphone picker; verified by `ChatVoiceTests`, `ChatVoiceClockTests` and `ChatVoiceWordsTests` (host: the five-minute limit and its line, the recording clock, a timer that dies with its recording, a thread's words taken by that thread only) and `ChatVoiceUITests` (simulator: no Deepgram key in Settings any more; the thread's mic and its microphone picker are there and ready); speaking on the phone not yet; #544: the microphone picker is a full-width row a finger tall, as the problem report's is, in [442e0a5](https://github.com/idvorkin/context-grabber/commit/442e0a5); host `just native-test`; the simulator's ChatVoiceUITests and the phone not yet; #546: a Send mid-recording stops it, so no words come back into the emptied bar, in [84e4f70](https://github.com/idvorkin/context-grabber/commit/84e4f70); no automated test (the decision lives in the app target); on the phone not yet; #531, BugKit's live input level under the microphone row, in [5e0cbda](https://github.com/idvorkin/context-grabber/commit/5e0cbda) on BugKit 0.3.11; verified by a simulator build; the meter moving with my voice on the phone not yet
- **Issues:** [#531](https://github.com/idvorkin/context-grabber/issues/531), [#448](https://github.com/idvorkin/context-grabber/issues/448), [#544](https://github.com/idvorkin/context-grabber/issues/544), [#546](https://github.com/idvorkin/context-grabber/issues/546)
- **Spec:** [Chat with Larry in Grabber Native — Speaking a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with my hands busy or more to say than I want to type
- **I want to** tap a mic in the thread, talk, and get my words in the message
- **so that** I can say it as fast as I think and still fix it before Larry reads it

#### Acceptance Criteria:
- **Scenario:** Speaking a message
- **Given:** no call is live
- **When:** I tap the mic in a thread, speak, and tap it again
- **Then:** it shows red with the seconds while it records, my words appear in the field as I speak, after anything I typed, transcribed by the same Apple dictation the problem report uses; nothing is sent until I tap Send

- **Scenario:** Choosing the microphone
- **Given:** a thread is open and nothing is recording
- **When:** I tap the *Microphone* row above the field (the whole row, a full finger tall, #544) and choose *Find microphones*, then a microphone
- **Then:** the row names it and my next recording uses it; *Automatic* follows the phone's route; the pick stays after a relaunch; during a recording or a live call the picker cannot be changed

- **Scenario:** Seeing how loud I am (#531)
- **Given:** I am recording a message in a thread
- **When:** I speak, softly and then loudly
- **Then:** the thin bar under the microphone row fills with my voice, green, orange near the top where it would clip, the same meter the problem report shows; it is empty when I am not recording

- **Scenario:** Nothing to transcribe, or no way to
- **Given:** a recording where nothing was heard, speech recognition or the microphone declined, or a call with Larry live
- **When:** I tap the mic
- **Then:** the field stays as it was, and a line says why: which permission is off, or that the call has the mic; a call that starts mid-recording stops it, keeps the words already in the field, and its sound is never changed

- **Scenario:** Interrupted mid-recording
- **Given:** I am recording a message
- **When:** a phone call, Siri or a microphone change interrupts
- **Then:** the clock stops, what I said so far stays in the field for me to read (never sent), and a copyable line says the microphone was interrupted

- **Scenario:** Sending while it records (#546)
- **Given:** I am recording a message and its words are in the field
- **When:** I tap Send
- **Then:** what the field held is sent, the recording stops, the bar empties and stays empty — no words come back into it — and the session log has a `chat_voice` line with action `dropped`, why `sent`

- **Scenario:** Five minutes at most
- **Given:** I am recording a message
- **When:** the clock reaches 5:00
- **Then:** the recording stops on its own and my words settle into the field exactly as if I had tapped stop (never sent), a quiet line under the bar says *Stopped at 5 minutes.*, and the session log has a `chat_voice` line with action `capped`

- **Scenario:** The log
- **Given:** I record a message
- **When:** I read the session log
- **Then:** `chat_voice` lines say when it started and stopped (and why it stopped early), never my words

---

### User Story 304:

- **Summary:** Settings tells me whether everything reached the archive, and which stream did not
- **Status:** native app only: implemented in [5f8260c](https://github.com/idvorkin/context-grabber/commit/5f8260c), [c9b87d3](https://github.com/idvorkin/context-grabber/commit/c9b87d3) (a locked run leaves the line alone), [208c2a2](https://github.com/idvorkin/context-grabber/commit/208c2a2) (red only after a day without progress, so a backfill is never red; the section follows a run that ends while it is open); host-verified by `just native-test` (`ArchiveStatusTests`, `ArchiveTests` refusal status); the simulator and the phone not yet
- **Issues:** [#547](https://github.com/idvorkin/context-grabber/issues/547)
- **Spec:** [Everything off the phone — In Settings](../superpowers/specs/2026-10-19-native-stats-archive-design.md#in-settings)

#### Use Case:
- **As** Larry's client whose week the Cockpit reads from the archive
- **I want to** see in Settings whether the archive is caught up, and why a stream is not
- **so that** a Cockpit out of reach or a refused page is fixed before it becomes a gap in what Larry sees

#### Acceptance Criteria:
- **Scenario:** The Cockpit has been out of reach
- **Given:** the archive last caught up two days ago and the last run could not reach the Cockpit
- **When:** I open Settings
- **Then:** the Archive section says *Cockpit out of reach · tried … · last caught up 2 days ago* in red, with a line for each stream that did not catch up and why; a refused stream shows the Cockpit's status in red, and a run that caught everything up says *Caught up* with when

- **Scenario:** The first backfill is still going
- **Given:** a fresh install whose archive runs are still sending years of history, a few pages a run, or were cut short by iOS
- **When:** I open Settings, or a run ends while it is open
- **Then:** the Archive section says *Behind* and *still sending its history* for those streams, in the ordinary colour, never red, and it changes when the run ends

---
