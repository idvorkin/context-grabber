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
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); verified by `InboxTests` (host: newest first, the count, sent and refused leaving it, delete taking the image, an empty note, an unreadable file named not fatal; previews are bounded thumbnails since [8589513](https://github.com/idvorkin/context-grabber/commit/8589513)); the simulator build, the `GRABBER_INBOX_FIXTURE` Inbox and a swipe in the next build turn; sharing from Safari, Notes and Photos in aeroplane mode on the phone still for Igor; any text the share sheet offers (RTF and HTML turned plain) and a copyable reason when a share cannot be read, in [d5095e8](https://github.com/idvorkin/context-grabber/commit/d5095e8); the tile's picture, the raccoon posting a letter (#395): [3efd0b8](https://github.com/idvorkin/context-grabber/commit/3efd0b8), verified by `scripts/native/test-tile-art.sh` (host: transparent, square, filling the tile) and by eye on light and dark; the phone in the next build turn; #673: the card's field is headed *Message*, in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3)
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305), [#395](https://github.com/idvorkin/context-grabber/issues/395) (the tile's picture), [#673](https://github.com/idvorkin/context-grabber/issues/673) (the card's *Message*)
- **Spec:** [Share into Grabber Native, and Larry's inbox](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client who comes across things worth talking about all day
- **I want to** share a link, some text or a photo from any app to Grabber Native, with a message
- **so that** it is kept for Larry the moment I see it, even with no signal

#### Acceptance Criteria:
- **Scenario:** Sharing from three apps in aeroplane mode
- **Given:** the phone is in aeroplane mode
- **When:** I share a Safari link, a Notes text and a Photos image to *Grabber Native*, adding a message to one and tapping *Add to Inbox* (*Start a chat* since #438, story 275) each time
- **Then:** each card closes at once, the Inbox lists the three newest first with what each is, the message, the link's site and when, the Inbox tile (the raccoon posting a letter) counts three not yet sent, a swipe deletes one and the count follows, and when I next open the app the log has an `inbox` added line for each with its kind and size but never its content

---

### User Story 039:

- **Summary:** What is in my Inbox reaches Larry, once each
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); verified by `InboxTests` (host: the request per cockpit#63 with the Cockpit's Origin and no token, every answer class, a HEIC as JPEG, an image over the cap made smaller, oldest first and stopping at the first unreachable, an unreadable image refused without asking, a fixture never sent; an item deleted while the send is out is not sent, in [8589513](https://github.com/idvorkin/context-grabber/commit/8589513)); a share made while a send is out goes in one more pass when it ends, in [3bf50ec](https://github.com/idvorkin/context-grabber/commit/3bf50ec); a send over the tailnet from the phone still for Igor; since #438 an item goes to the Cockpit's chat, not its inbox (stories 274, 275); since context-grabber-gp7, one send at a time and the extra pass for a share made meanwhile are `InboxOutboxTests` (host, a held transport)
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305)
- **Spec:** [Share into Grabber Native, and Larry's inbox — phase 2](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client with things waiting in the Inbox
- **I want to** have them reach Larry's inbox on their own when the phone can reach the Cockpit
- **so that** Larry sees what I shared, the message and when, without me sending anything

#### Acceptance Criteria:
- **Scenario:** Back on the tailnet
- **Given:** three items wait in the Inbox, one of them a HEIC photo
- **When:** I open Grabber Native with the Cockpit reachable
- **Then:** each goes to Larry once, oldest first, and reads *sent to Larry* with the time, the photo arrives as a JPEG, and the log has an `inbox` sent line for each with the Cockpit's answer

---

### User Story 260:

- **Summary:** An item Larry's inbox refuses says why and is never resent
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); verified by `InboxTests` (host: a 4xx answer recorded as refused with the Cockpit's reason and not sent again, an unreadable image refused without asking); the copyable reason on the phone still for Igor; a 408 or 429 no longer counts as refused in [8bdd0381](https://github.com/idvorkin/context-grabber/commit/8bdd0381) (#1452, story 261): host `ChatTests`
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305)
- **Spec:** [Share into Grabber Native, and Larry's inbox — phase 2](../superpowers/specs/2026-10-17-native-share-inbox-design.md)

#### Use Case:
- **As** Larry's client with something in the Inbox the Cockpit cannot take
- **I want to** see the Cockpit's reason, copyable, instead of it trying forever
- **so that** I can fix it or delete it, and nothing else waits behind it

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses an item
- **Given:** an item waits in the Inbox that the Cockpit will answer with a 4xx that says the item is wrong (too big,
  an unreadable image), not one that says to try later (a timeout reading the upload, or too many at once)
- **When:** I open Grabber Native with the Cockpit reachable
- **Then:** the item reads *Larry's inbox refused it* with the Cockpit's reason, copyable, it is not sent again on later opens, the items after it still go, and the log has an `inbox` refused line with the status and the reason

---

### User Story 261:

- **Summary:** With the Cockpit out of reach, the Inbox waits for the next open
- **Status:** native app only: implemented in [99b308e](https://github.com/idvorkin/context-grabber/commit/99b308e); #406's wording and the failed-send regression in [7efc955](https://github.com/idvorkin/context-grabber/commit/7efc955); verified by `InboxTests` (host: no answer or a 5xx leaves the item waiting and stops the send, oldest first; a transport failure retains the item and a later success sends it once); off the tailnet on the phone still for Igor; a 408 or 429 on a send waits rather than reads refused (#1452) in [8bdd0381](https://github.com/idvorkin/context-grabber/commit/8bdd0381): host `ChatTests` testATimeoutOrBusyAnswerWaitsRatherThanRefuses and testATimedOutUploadWaitsWithoutHoldingUpTheRestButTooManyStopsThem (rung 1); a slow upload on the phone not yet
- **Issues:** [#305](https://github.com/idvorkin/context-grabber/issues/305), [#406](https://github.com/idvorkin/context-grabber/issues/406), [#1452](https://github.com/idvorkin/context-grabber/issues/1452) and [#1453](https://github.com/idvorkin/context-grabber/issues/1453) (a 408 on a photo's upload read as refused, and the photo was lost)
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

- **Scenario:** The Cockpit timed out reading a photo (#1452)
- **Given:** a photo waits in the Inbox, and the Cockpit answers its upload with 408 (it gave up waiting for the
  body, as a 2.2 MB photo on a slow link did on 2026-11-25) or 429 (too many at once)
- **When:** it is sent
- **Then:** it stays *Not sent yet*, never *Larry refused it*, and goes again with the next send; no automatic report
  is filed for it, and the log has the `chat` failed line with the status and the reason
- **And:** after a 408 the items behind it still go in that send, so one photo that keeps timing out never holds up
  the rest; after a 429 the rest of that send waits, like an unreachable Cockpit

---

### User Story 262:

- **Summary:** Start a new chat with the keyboard or dictation
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); verified by `InboxDraftTests` and the full `just test` (host); the sheet, dictation and pasting on the phone not yet; #424: the + is a floating button in the lower right in [066dae4](https://github.com/idvorkin/context-grabber/commit/066dae4); verified by `just test` (host) and the simulator build; on the phone not yet. #536: the + opens a new thread with the ordinary bar instead of a sheet in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d); verified by `ChatNewThreadUITests` (simulator: the + opens an empty *New chat* thread with the bar, its mic and Paste image, and no sheet); sending from it on the phone not yet. #637: the + no longer floats, it sits in a bar below the list beside the voice button, in [dd6c94d](https://github.com/idvorkin/context-grabber/commit/dd6c94d); verified by `ChatArchiveUITests` (simulator); on the phone not yet. #685: the + floats over the list again, beside the voice button, in [dd5d9ef8](https://github.com/idvorkin/context-grabber/commit/dd5d9ef8); verified by `ChatArchiveUITests` (simulator: chat suite 34 passed; one swipe test failed on the suite's slow first launch, then passed 3 of 3 alone); on the phone not yet.; the + opening the ordinary bar with the keyboard up is now checked at the end of `ChatNewThreadUITests`' voice-button test, the focus rule in `ChatNewThreadScreenTests` (host), bead `context-grabber-t8i`; #1365: the + opening a new chat again is story 1607
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405), [#424](https://github.com/idvorkin/context-grabber/issues/424), [#536](https://github.com/idvorkin/context-grabber/issues/536), [#637](https://github.com/idvorkin/context-grabber/issues/637), [#685](https://github.com/idvorkin/context-grabber/issues/685), [#1365](https://github.com/idvorkin/context-grabber/issues/1365)
- **Spec:** [Chat with Larry in Grabber Native — A new chat](../superpowers/specs/2026-10-25-native-chat-design.md); [Adding from inside the app](../superpowers/specs/2026-10-17-native-share-inbox-design.md#adding-from-inside-the-app)

#### Use Case:
- **As** Larry's client capturing something worth discussing
- **I want to** tap Chat's + and type, or use the keyboard's dictation or the chat mic, in a new thread
- **so that** I can start a conversation with Larry without leaving the app or learning a second screen

#### Acceptance Criteria:
- **Scenario:** Starting a new chat
- **Given:** Chat is open, empty or populated, with one large round + fixed at the lower right, and no toolbar +
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
- **Status:** native app only: implemented in [7efc955](https://github.com/idvorkin/context-grabber/commit/7efc955); the retry on a path change after a failed send (Codex on #409) in [22c36ef](https://github.com/idvorkin/context-grabber/commit/22c36ef), and for a change that came while the failing send was out in [77d67d6](https://github.com/idvorkin/context-grabber/commit/77d67d6); a network that comes up on demand (an on-demand VPN) counts as available in [4be2267](https://github.com/idvorkin/context-grabber/commit/4be2267); verified by `InboxSendPolicyTests` and `InboxTests` with the full `just test` (host); the offline line and the send on the network's return on the phone not yet; #565, a failed send tried again on its own while the app is open (30 s doubling to 5 min) in [5a76646](https://github.com/idvorkin/context-grabber/commit/5a76646), verified by `InboxSendPolicyTests` (host) and a simulator build; the `inbox` backoff line on the phone not yet; #633, a refused file goes again on *Send again* in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294), verified by `ChatFileTests` (host); since context-grabber-gp7, the send's timing (waiting for the first path reading, offline skipped, the network's return, a new route's half-second retry, the backoff's 30 s then 60 s and what stops it) is `InboxOutboxTests` (host, an injected clock, timers and transport)
- **Issues:** [#406](https://github.com/idvorkin/context-grabber/issues/406), [#565](https://github.com/idvorkin/context-grabber/issues/565), [#633](https://github.com/idvorkin/context-grabber/issues/633)
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
- **Then:** the message is tried again on its own after 30 seconds, then a minute, two, four, and every five minutes after that, each wait logged as an `inbox` backoff line; the wait starts over after a send gets through, and the tries stop once nothing waits or the phone goes offline; a refused message is never tried again on its own (a file goes again on *Send again*, story 488)

---

### User Story 270:

- **Summary:** Everything the app collects is archived off the phone on its own, once each
- **Status:** implemented in [5ffefb3a](https://github.com/idvorkin/context-grabber/commit/5ffefb3a), [b239e434](https://github.com/idvorkin/context-grabber/commit/b239e434) and [d9cee15d](https://github.com/idvorkin/context-grabber/commit/d9cee15d) (the phone half; the Cockpit's `POST /archive` is its story 124), plus the review round (the next slots asked for before a background run, Health skipped while the phone is locked); verified on the host (`just test`: `ArchiveTests`, swift-format, SwiftLint) and the simulator (`just native-test-sim` 45/45, the archive hook included). Not yet verified: the phone, and the Cockpit's `/archive` endpoint (cockpit's archive-endpoint branch); until it is live a run stops on the error and retries later. When a run is due, by how the last one ended (a run that never reached the Cockpit is due again at the next foreground; the run itself host-tested in `ArchiveTests`, smoke's archive relaunch dropped): [76152e1](https://github.com/idvorkin/context-grabber/commit/76152e1); verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending. Every heart-rate reading of a workout, the last 400 days newest-first, big pages in several batches (context-grabber-kseb): [5c34f9db](https://github.com/idvorkin/context-grabber/commit/5c34f9db); verified on the host (`just test`: `HealthSeriesTests`, `ArchiveTests`) and the Mac build; the Health queries themselves (series readings, the dated walk) only on the phone, pending. The review round (only separate readings expanded, a day of overlap on each walk forward, a stop between batches, the newest-first walk named in Settings): [db3fda46](https://github.com/idvorkin/context-grabber/commit/db3fda46); verified on the host (`HealthSeriesTests`, `ArchiveStatusTests`); the phone pending.
- **Why:** Igor, Cockpit chat 2026-10-19: "let's archive all the stats we can do it every four hours. Be sure to Delta stamp them somehow so we don't get duplicates. Should work for history as a one off, and then as habits happen. Then maybe final daily batch. Since all guid marked no duplicates"
- **Issues:** context-grabber-3il, context-grabber-kseb (Larry 82296d49b1fd, 2026-11-25: heart rate stopped at 2025-11-13, a 41-min HIIT held 4 readings)
- **Spec:** [Everything off the phone: the stats archive](../superpowers/specs/2026-10-19-native-stats-archive-design.md)

#### Use Case:
- **As** Larry's client whose phone keeps its trail thirty days and its Health history only on the phone
- **I want to** have everything the app collects copied to the Cockpit's archive on its own, a delta every few hours and the whole history the first time
- **so that** Larry has the whole record, and losing or replacing the phone loses none of it

#### Acceptance Criteria:
- **Scenario:** A delta every few hours, history the first time
- **Given:** Today has asked for Health, the Cockpit is reachable, and the trail and Health hold records the archive has not seen
- **When:** four hours pass since the last run (a background refresh, or the app comes to the front), or the end-of-day batch runs
- **Then:** every new point and sample goes to the Cockpit in pages, once each (a lost answer sends the same page again and the Cockpit counts it as already there), the cursor of each stream moves only after the Cockpit took the page, an unreachable Cockpit stops the run at its first page and the next run sends it again, and the log has one `archive` line per page with counts and never a record; launch remains safe with an existing database, and a simulator sends only to an explicitly supplied test destination; a run while the phone is locked sends the trail, says once that Health was skipped, and is not counted, so the app's next time in front sends Health's share; a run that could not reach the Cockpit holds nothing off, so the next time the app comes to the front runs again, while one that caught up or was refused holds the next foreground off four hours; a run iOS cuts short keeps every cursor a taken page moved; a delayed daily batch keeps its pending slot across midnight, and a rolled-back import cannot enter the archive or advance its cursor; a workout's heart rate arrives as every reading the Watch took, about one every 5 s, each once, not one value per stored sample; the last 400 days of heart rate, steps, active energy and walking distance arrive newest-first within a few runs even while the oldest-first history is still going over, and new readings keep coming after that; a page that grows past one batch goes as several, and the stream's place moves on only once all of them are taken; a workout's steps, active energy and distance stay one record each, not one more per reading; each walk forward goes back over the last day it sent, so heart rate the Watch syncs late still arrives; Settings names the newest-first walk apart from its stream ("Heart Rate, last 400 days"); a run iOS cuts short between the batches of a page stops there without moving the page's place

---

### User Story 271:

- **Summary:** The daily strip's days are archived too, each day as the strip shows it
- **Status:** implemented in [d06ac21](https://github.com/idvorkin/context-grabber/commit/d06ac21); verified on the host (`just test`: `ArchiveTests`, swift-format, SwiftLint) and the simulator (`just native-test-sim`, the archive hook included). Not yet verified: the phone. The run that carries the strip moved into the core in [76152e1](https://github.com/idvorkin/context-grabber/commit/76152e1) (the strip still goes while locked, `ArchiveTests`); verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending.
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
- **Then:** every thread is listed newest activity first, after the pinned one (story 316), with its title, who said the last thing and what, and when; the unread one is marked; finished ones fold under *Done (n)* by the Cockpit's own rule; and the tile counts unread threads plus my messages not yet sent

---

### User Story 273:

- **Summary:** A thread reads like a chat and keeps up by itself
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: messages with receipts and images, the seen request, an attachment address only for a ref the Cockpit mints), `sim-smoke.sh` (a link opens the thread, it is read and marked seen) and simulator screenshots (bubbles, links); on the phone not yet; the Cockpit's receipt ladder in [be0c46c](https://github.com/idvorkin/context-grabber/commit/be0c46c) (#630), verified by `ChatTests` (host: decoding and glyphs) and a simulator build; the glyphs not yet seen on a screen
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#630](https://github.com/idvorkin/context-grabber/issues/630)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client in the middle of a conversation
- **I want to** see my messages and his as bubbles that update while I watch
- **so that** it feels like talking, not refreshing a page

#### Acceptance Criteria:
- **Scenario:** Reading a thread
- **Given:** a thread with my messages, Larry's replies and an image
- **When:** I open it
- **Then:** mine are on the right and his on the left, oldest at the top, opening at the newest; links are tappable and the image shows inline and full screen on a tap; under each of mine is *sent*, 👀 once the Cockpit has it, 🫡 once it is with Larry, or 🏆 with his note once it is done (a state this build doesn't know reads as 👀); and the thread reads as read here and on the laptop

---

### User Story 274:

- **Summary:** What I write in a thread waits on the phone and reaches Larry once
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: the message to its thread's path with its id and the app as source, an image uploaded first and named by its ref), `InboxTests` (oldest first), `sim-smoke.sh` (one `POST /chat/<key>`, the text never in the log); the phone's copy dropped once the thread shows it in the review round, not yet verified on any rung; a send over the tailnet from the phone once cockpit#64 is merged; the bar emptied after a send with the keyboard up for the next ([46ca1f7](https://github.com/idvorkin/context-grabber/commit/46ca1f7), #449) verified by a simulator UI test since gone (typed, sent, the field empty, focused and Send disabled, the next message typed straight on); simulator typing does not reproduce the phone's leftover text, so on the phone not yet, where its `bar_after_send` line will say; bead `context-grabber-t8i` folds that check into `ChatNewThreadUITests`' first-message test (the field empty, the keyboard up, the next words in with no tap), and Send disabled on an empty bar into `ChatNewThreadScreenTests` (host)
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

- **Summary:** A share with *New chat* ticked starts its own thread with Larry
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: a new thread's title from the note, the text, the link's site or *Photo, <date>*; one `POST /chat` with the item's id), a share itself not yet made on any rung; sharing from Safari on the phone not yet. #587: a new thread is now the card's ticked *New chat* row rather than every share, in [c362df7](https://github.com/idvorkin/context-grabber/commit/c362df7); the tick is the card's own state, not yet seen on any rung, on the phone still for Igor; #673: the card's field is headed *Message*, in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3)
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#673](https://github.com/idvorkin/context-grabber/issues/673) (the card's *Message*)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who shares things worth talking about all day
- **I want to** have a share with *New chat* ticked become its own conversation
- **so that** Larry and I can talk about it on its own thread

#### Acceptance Criteria:
- **Scenario:** Sharing a link
- **Given:** I share a Safari link to *Grabber Native* with the message "worth a read"
- **When:** I tap *Start a chat*
- **Then:** the card closes at once, Chat lists a thread titled "worth a read" under *Not sent yet* until it reaches the Cockpit, and then as a thread whose first message is the link and the message

---

### User Story 276:

- **Summary:** A reply from Larry notifies me while the app is closed
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: only a new unread reply from Larry is due, once); the background check, the notification and its tap only on the phone, not yet; a tapped notification no longer crashes the app ([aede196](https://github.com/idvorkin/context-grabber/commit/aede196), #610, the delegate's completion on the main thread): simulator build only, a notification tap to try on the phone
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#609](https://github.com/idvorkin/context-grabber/issues/609), [#610](https://github.com/idvorkin/context-grabber/issues/610)
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

### User Story 839:

- **Summary:** A Chat read I stopped or that was overtaken shows nothing
- **Status:** native app only: implemented in [f3190178](https://github.com/idvorkin/context-grabber/commit/f3190178); verified by `ChatReadOrderTests` (host) and the Mac build; on the phone not yet
- **Issues:** bead `context-grabber-exg6`
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client moving in and out of Chat while it reads
- **I want to** see only the newest answer, and no problem for a read I walked away from
- **so that** a red line means the Cockpit really failed, and the list and the thread never step back in time

#### Acceptance Criteria:
- **Scenario:** A read stopped or overtaken
- **Given:** the chat list or an open thread is being read, and the app coming to the front, a closed thread, a send, the poll or an answered card reads it again
- **When:** I leave the list or the thread before its read is answered, or an older read finishes after a newer one
- **Then:** no problem appears for the read that was stopped, and the list or the thread shows the newest read that finished; an older answer or problem never replaces it

---

### User Story 300:

- **Summary:** A message sent offline goes once when the network returns; a refused one says why
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: a refused upload refusing the message, an unreachable Cockpit stopping the run) and `InboxTests` (a failure kept for later, a deleted one never sent); never sent twice across a lost answer rests on the Cockpit's dedupe by id (cockpit#64, not merged) and is not verified on any rung; on the phone not yet; #565, *The Cockpit isn't answering* on the list, the thread and a waiting message in [5a76646](https://github.com/idvorkin/context-grabber/commit/5a76646), verified by `ChatTests` (host: a timeout is the Cockpit away, a 503 is not) and a simulator build; on the phone not yet; #633, a refused file kept to go again in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294), verified by `ChatFileTests` (host); #632, a refusal names the skill it came from in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2), see story 517.
- **Issues:** [#438](https://github.com/idvorkin/context-grabber/issues/438), [#565](https://github.com/idvorkin/context-grabber/issues/565), [#633](https://github.com/idvorkin/context-grabber/issues/633), [#632](https://github.com/idvorkin/context-grabber/issues/632)
- **Spec:** [Chat with Larry in Grabber Native](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client typing on a bad connection
- **I want to** have what I wrote go by itself once the network is back, and hear why if Larry refuses it
- **so that** nothing I say is lost, doubled or silently dropped

#### Acceptance Criteria:
- **Scenario:** Offline or refused
- **Given:** no network, or the Cockpit refuses the message (too big, an unreadable image)
- **When:** I send
- **Then:** offline it stays *Not sent yet* and goes by itself when the network returns, never twice even if an answer was lost; refused it says *Larry refused it* (on a skill's thread, the skill's name, story 517) with the reason, copyable, and is never sent again on its own (a file says it is kept and offers *Send again*, stories 487, 488); a long press deletes it

- **Scenario:** The Cockpit isn't answering (#565)
- **Given:** the phone is online but the Cockpit times out or cannot be reached
- **When:** I open Chat or a thread, or a message I wrote tries to go
- **Then:** the list and the thread say *The Cockpit isn't answering — your messages are kept and go when it does*, copyable, with the underlying reason; a waiting message reads *Not sent yet · the Cockpit isn't answering*; the *No network* line is only for the phone being offline, and a Cockpit that answers with an error keeps its plain reason

---

### User Story 301:

- **Summary:** The + starts a new thread with Larry
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `sim-smoke.sh` (a message written for a new thread, through the `GRABBER_CHAT_SEND` hook, goes up as one `POST /chat` with the app as source and its first line as the title, the text never in the log) and a simulator screenshot (a new thread written while the Cockpit was down went up when it came back); on the phone not yet. #536: the + opens a new thread with the ordinary bar instead of a sheet in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d), each first-message attempt its own message in [8202fec](https://github.com/idvorkin/context-grabber/commit/8202fec); verified by `ChatNewThreadTests` (host) and `ChatNewThreadUITests` (simulator, against the fake Cockpit); on the phone not yet; bead `context-grabber-t8i`: where a Send goes, the hold-back line and the title are `ChatNewThreadScreenTests` (host); the typed first Send stays in `ChatNewThreadUITests`
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
- **Status:** native app only: implemented with Deepgram in [2015662](https://github.com/idvorkin/context-grabber/commit/2015662), moved to the problem report's Apple dictation with the five-minute cap in [f040853](https://github.com/idvorkin/context-grabber/commit/f040853), with the microphone picker; verified by `ChatVoiceTests`, `ChatVoiceClockTests` and `ChatVoiceWordsTests` (host: the five-minute limit and its line, the recording clock, a timer that dies with its recording, a thread's words taken by that thread only) and ChatVoiceUITests, a simulator test since gone (Settings asks for no Deepgram key because that section is gone from the code; on the simulator: the thread's mic and its microphone picker are there and ready); speaking on the phone not yet; #544: the microphone picker is a full-width row a finger tall, as the problem report's is, in [442e0a5](https://github.com/idvorkin/context-grabber/commit/442e0a5); host `just native-test`; the simulator's ChatVoiceUITests and the phone not yet; #546: a Send mid-recording stops it, so no words come back into the emptied bar, in [84e4f70](https://github.com/idvorkin/context-grabber/commit/84e4f70); no automated test (the decision lives in the app target); on the phone not yet; #625: the mic moved beside Send in [f52d9dd](https://github.com/idvorkin/context-grabber/commit/f52d9dd); verified by ChatVoiceUITests on the iPhone 17 simulator, where it measures the order, the gap and the 44-point targets; the iPad and a finger on it are still to try; #559: a chat recording holds the microphone against the problem report, in [080fbf7](https://github.com/idvorkin/context-grabber/commit/080fbf7); host `just native-test` and a simulator compile; dictating on the phone not yet.; since [1101e05d](https://github.com/idvorkin/context-grabber/commit/1101e05d) who has the microphone is one floor ([spec](../superpowers/specs/2026-11-10-microphone-floor-design.md)): a tap asks it, a call takes it from the recording, the report's dictation waits for it, verified on the Linux rung (host tests, `AudioFloorTests`); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending; #822: words handed over twice are kept once, BugKit 0.3.13 in [a3b49f6](https://github.com/idvorkin/context-grabber/commit/a3b49f6); verified by BugKit's tests (bug-kit #113/#114) and the host rung here; the simulator and dictating on the phone not yet; since story 770 the thread bar's mic, its place beside Send, the 44-point targets and the picker opening are checked in `ChatNewThreadUITests.testTheVoiceButtonOpensANewChatWithItsMicTapped`, on the new chat's bar, which is the thread's, and ChatVoiceUITests is gone; #1165: each microphone change while it records is logged with why and what changed, and the stop line with the state it stopped in, in [3a9762d4](https://github.com/idvorkin/context-grabber/commit/3a9762d4); verified by the lint and host rungs (`just native-test`) and the Mac build; the route itself is the phone's to show (a recording on a headset, then the phone locked); #1165: the screen kept awake while it records (Igor's decision, 2026-11-22; a mitigation, the stop's cause still waits on the route_change line) in [8d683c38](https://github.com/idvorkin/context-grabber/commit/8d683c38); verified by `ChatVoiceAwakeTests` (host: on at the start, off at the stop, never on without a start, someone else's hold left alone) and the Mac build; the simulator rung owed (the simulator stack was wedged on 2026-11-22; the hold is not visible to a UI test); the screen staying lit and the recording outliving the auto-lock time are the phone's to show; #1398: a route change mid-recording no longer stops it (BugKit 0.3.18, idvorkin/bug-kit#143) in [cad21e04](https://github.com/idvorkin/context-grabber/commit/cad21e04); verified by BugKit's dictation tests (33 host tests, the new rule tests included), the host rung here (`just test`), the Mac build and the iPad Pro 11-inch (M5) simulator's chat UI tests (36 tests and the smoke, the voice button and call-holds-the-mic tests among them); a real route change on the phone or iPad is still to try
- **Issues:** [#559](https://github.com/idvorkin/context-grabber/issues/559), [#448](https://github.com/idvorkin/context-grabber/issues/448), [#544](https://github.com/idvorkin/context-grabber/issues/544), [#546](https://github.com/idvorkin/context-grabber/issues/546), [#625](https://github.com/idvorkin/context-grabber/issues/625), [#822](https://github.com/idvorkin/context-grabber/issues/822) (on-device dictation handed over the words twice with no space; BugKit 0.3.13 keeps them once), [#1165](https://github.com/idvorkin/context-grabber/issues/1165) (a recording on a Bluetooth headset stopped with *The microphone changed* 85 s in, about 50 s after the phone locked; the log could not say what changed, so the route is now logged; the cause waits for the next one; idvorkin/bug-kit#133; then, by Igor's decision, the screen is kept awake while it records), [#1398](https://github.com/idvorkin/context-grabber/issues/1398), [#1411](https://github.com/idvorkin/context-grabber/issues/1411), [#1412](https://github.com/idvorkin/context-grabber/issues/1412) (dictation died about a second in when the route moved from AirPods to USB audio: BugKit rebuilt the engine only in the first second; idvorkin/bug-kit#142, fixed in BugKit 0.3.18)
- **Spec:** [Chat with Larry in Grabber Native — Speaking a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with my hands busy or more to say than I want to type
- **I want to** tap a mic in the thread, talk, and get my words in the message
- **so that** I can say it as fast as I think and still fix it before Larry reads it

#### Acceptance Criteria:
- **Scenario:** Speaking a message
- **Given:** no call is live
- **When:** I tap the mic in a thread, speak, and tap it again
- **Then:** it shows red with the seconds while it records, my words appear in the field as I speak, once each, after anything I typed, transcribed by the same Apple dictation the problem report uses; nothing is sent until I tap Send

- **Scenario:** A problem report during a recording (#559)
- **Given:** I'm recording a message in a thread
- **When:** I shake to report a problem
- **Then:** the recording keeps going with its words intact, and the report's mic is off, as it is during a call, until I stop recording; if the recording ends with the report still open, the mic comes back at my next keystroke

- **Scenario:** The audio route changes mid-recording (#1398)
- **Given:** I'm recording a message in a thread, or talking on the board's mic
- **When:** the audio route changes at any point (AirPods connect or drop, a USB microphone is plugged in, the input changes format)
- **Then:** the recording keeps going on the new input with the words so far kept; it stops, with a copyable line saying why, only if the microphone can't be restarted or the route keeps flapping (3 restarts within 10 s)

- **Scenario:** One microphone, one holder
- **Given:** I'm recording a message in a thread
- **When:** a call with Larry starts, or (on an iPad, once the board asks too, #821) I tap the board's mic beside the thread
- **Then:** the call takes the microphone: the recording stops with its words kept and a line saying the call took it; the board's mic does not start while the recording goes on, and says another recording has it

- **Scenario:** The mic sits by Send (#625)
- **Given:** a thread or a new chat is open, on iPhone or iPad
- **When:** I look at the bar
- **Then:** the mic is immediately beside Send, at the trailing edge after the field, each at least 44 points in both directions, and each tap does what it did

- **Scenario:** Choosing the microphone
- **Given:** a thread is open and nothing is recording
- **When:** I tap the *Microphone* row above the field (the whole row, a full finger tall, #544) and choose *Find microphones*, then a microphone
- **Then:** the row names it and my next recording uses it; *Automatic* follows the phone's route; the pick stays after a relaunch; during a recording or a live call the picker cannot be changed

- **Scenario:** Nothing to transcribe, or no way to
- **Given:** a recording where nothing was heard, speech recognition or the microphone declined, or a call with Larry live
- **When:** I tap the mic
- **Then:** the field stays as it was, and a line says why: which permission is off, or that the call has the mic; a call that starts mid-recording stops it, keeps the words already in the field, and its sound is never changed

- **Scenario:** Interrupted mid-recording
- **Given:** I am recording a message
- **When:** a phone call or Siri taking the audio interrupts
- **Then:** the clock stops, what I said so far stays in the field for me to read (never sent), and a copyable line says the microphone was interrupted

- **Scenario:** The screen stays awake while I speak (#1165)
- **Given:** I am recording a message and I put the phone down
- **When:** the auto-lock time passes, and later the recording ends (I tap stop, send, leave the thread, a call takes the mic, it is interrupted, or it reaches 5:00)
- **Then:** the screen does not auto-lock while it records, and auto-lock is back as soon as it ends; if the Gym Timer or breathing was already keeping the screen awake, it still is; the side button still locks the phone

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
- **Then:** `chat_voice` lines say when it started and stopped (and why it stopped early), never my words; each microphone change while it records is a line saying why iOS changed it, the microphone before and after, and whether the phone was locked, and the stop line says the same of the moment it stopped (#1165); a `keep_awake` line says when auto-lock was held off at the start and given back at the stop

---

### User Story 304:

- **Summary:** Settings tells me whether everything reached the archive, and which stream did not
- **Status:** native app only: implemented in [5f8260c](https://github.com/idvorkin/context-grabber/commit/5f8260c), [c9b87d3](https://github.com/idvorkin/context-grabber/commit/c9b87d3) (a locked run leaves the line alone), [208c2a2](https://github.com/idvorkin/context-grabber/commit/208c2a2) (red only after a day without progress, so a backfill is never red; the section follows a run that ends while it is open); host-verified by `just native-test` (`ArchiveStatusTests`, `ArchiveTests` refusal status); the simulator and the phone not yet. The headline and "is a run due" read one state, and the stored stop reasons read back unchanged: [76152e1](https://github.com/idvorkin/context-grabber/commit/76152e1); verified on the Linux rung (host tests); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending
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

### User Story 305:

- **Summary:** While I speak a message in a thread, a meter shows how loud I am
- **Status:** native app only: BugKit's live input level under the microphone row, in [5e0cbda](https://github.com/idvorkin/context-grabber/commit/5e0cbda) on BugKit 0.3.11; verified by a simulator build; the meter moving with my voice on the phone not yet
- **Issues:** [#531](https://github.com/idvorkin/context-grabber/issues/531)
- **Spec:** [Chat with Larry in Grabber Native — Speaking a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client speaking a message instead of typing it
- **I want to** see my voice move a level meter while I record, as the problem report shows it
- **so that** I know the microphone hears me, and not too loudly, before I find out from the words

#### Acceptance Criteria:
- **Scenario:** Seeing how loud I am
- **Given:** I am recording a message in a thread
- **When:** I speak, softly and then loudly
- **Then:** the thin bar under the microphone row fills with my voice, green, orange near the top where it would clip, the same meter the problem report shows; it is empty when I am not recording

---

### User Story 306:

- **Summary:** A picture opened full size in a thread always has a way back
- **Status:** native app only: implemented in [8625876](https://github.com/idvorkin/context-grabber/commit/8625876); verified by the simulator build, `ChatImageCloseTests` (host: only a swipe down past 80 points closes) and `ChatImageUITests` (simulator: Done and a swipe down close it); tapping Done and swiping down over a white picture on the iPad not yet; since story 770 one launch does both (`testDoneShowsOverAWhitePictureAndASwipeOrDoneCloses`: a swipe down closes it, a tap on the picture opens it again, Done closes it); the iPad (`context-grabber-ootp`): [ffd468b4](https://github.com/idvorkin/context-grabber/commit/ffd468b4), the test zooms the tall picture until the white lies under *Done* where fitted leaves it on the margin, verified on the simulator on the iPad Pro 11-inch (M5), where the zoom ran and the white showed under the dark badge, and on the iPhone 17, plus `just native-test` and the Mac build; a real iPad not yet
- **Issues:** [#592](https://github.com/idvorkin/context-grabber/issues/592); bead `context-grabber-ootp` (the simulator check failed on the iPad, where the fitted picture left *Done* over the black margin, not over the picture)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client reading a picture he sent back, such as my whiteboard with his marks on it
- **I want to** see it full size and get back to the thread
- **so that** a white picture never leaves me stuck on a screen with no visible way out

#### Acceptance Criteria:
- **Scenario:** Back from a white picture
- **Given:** a thread holds a picture that is mostly white, like a whiteboard
- **When:** I tap it, then tap *Done* or swipe down
- **Then:** the picture fills the screen as far as its shape allows (a tall picture on the iPad leaves dark margins at its sides), *Done* is on a dark badge I can see over the picture wherever the picture lies under it, fitted or zoomed, and either one brings me back to the thread

---

### User Story 821:

- **Summary:** Zoom into a picture in a thread
- **Status:** native app only: implemented in [01dc660](https://github.com/idvorkin/context-grabber/commit/01dc660) and [6d1003e](https://github.com/idvorkin/context-grabber/commit/6d1003e); verified by the host tests (`ChatImageZoomTests`: the scale clamp and settle, the double-tap toggle, a drag's travel since its last change, the pan step and its clamp, the fitted size, and the swipe closing only a fitted picture that was not pinched) and the Mac build; `ChatImageUITests.testShareShowsAndADoubleTapZoomsSoASwipePans` (simulator: a double tap zooms so a swipe pans, a second one lets the swipe close) compiles but has not run; the simulator and the phone (the pinch's feel, a pinch that drifts down not closing, a pan after a pinch not jumping, and a drag at fitted joined by a second finger's pinch leaving the next plain swipe down still closing) not yet
- **Issues:** [#907](https://github.com/idvorkin/context-grabber/issues/907)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client reading a picture in a thread, such as a whiteboard he marked up or a screenshot
- **I want to** zoom into it and move around it
- **so that** I can read the small writing he marked rather than squint at it

#### Acceptance Criteria:
- **Scenario:** Zoom in and move around
- **Given:** a picture is open full size, at its fitted size
- **When:** I pinch it open or double tap it, then drag it with one finger
- **Then:** it zooms around my fingers, up to five times for a pinch and to two and a half times for a double tap, and pans without its edge coming inside the screen's; while it is zoomed a swipe down pans rather than closes, a pinch never closes it, a second double tap or a pinch let go smaller than fitted brings it back to fitted, where a swipe down closes it again, and the next time I open it, it is fitted

---

### User Story 822:

- **Summary:** Share or save a picture from a thread
- **Status:** native app only: implemented in [01dc660](https://github.com/idvorkin/context-grabber/commit/01dc660) and [6d1003e](https://github.com/idvorkin/context-grabber/commit/6d1003e); verified by the Mac build; `ChatImageUITests.testShareShowsAndADoubleTapZoomsSoASwipePans` (simulator: Share shows, and is live once the picture has loaded) compiles but has not run; the simulator and the phone (the share sheet holding the picture, Save Image asking for Photos access once, a picture that can't be fetched showing its problem with Share dimmed) not yet
- **Issues:** [#907](https://github.com/idvorkin/context-grabber/issues/907)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client reading a picture in a thread, such as a whiteboard he marked up
- **I want to** share or save the picture itself
- **so that** I keep it, or hand it to someone, rather than lose it in the thread

#### Acceptance Criteria:
- **Scenario:** Share the picture
- **Given:** a picture is open full size
- **When:** I tap *Share*, at the top leading corner on the same dark badge as *Done*
- **Then:** the share sheet offers the picture itself, so *Save Image* puts it in Photos and AirDrop sends the picture, not a link only my tailnet can open; a picture that could not be fetched shows a copyable problem in its place, with *Share* dimmed

---

### User Story 307:

- **Summary:** Archive a chat with a swipe, and undo it
- **Status:** native app only: implemented in [61e7f30](https://github.com/idvorkin/context-grabber/commit/61e7f30), a list read racing an archive in [88a194c](https://github.com/idvorkin/context-grabber/commit/88a194c), reading a thread no longer un-archiving it in [efd55da](https://github.com/idvorkin/context-grabber/commit/efd55da); verified by host tests (`ChatTests`: the archived field, the request, the answers) and the simulator (`ChatArchiveUITests` against the fake Cockpit); the simulator not re-run since the request gained its `Content-Type` in [9ff3ded](https://github.com/idvorkin/context-grabber/commit/9ff3ded); against the real Cockpit on the iPad not yet; bead `context-grabber-t8i`: the row moving at once, a refusal putting it back, Undo and the five seconds, and a list read racing a change are `ChatArchiverTests` (host, run on Linux), with the real swipe and Undo kept in `ChatArchiveUITests`
- **Issues:** [#589](https://github.com/idvorkin/context-grabber/issues/589), [#591](https://github.com/idvorkin/context-grabber/issues/591)
- **Spec:** [Chat with Larry in Grabber Native — Archiving](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a long list of chats
- **I want to** archive a finished one with a swipe, and take it back if I slipped
- **so that** the list holds only what is still open, the same on the phone and the Cockpit

#### Acceptance Criteria:
- **Scenario:** Swipe to archive, and undo
- **Given:** an open thread in the list
- **When:** I swipe it left, tap *Archive*, then tap *Undo* within five seconds
- **Then:** it folds under *Done* with *Archived "title"* and *Undo* showing, and *Undo* puts it back in the live list

---

### User Story 308:

- **Summary:** Archive a chat from inside it
- **Status:** native app only: implemented in [61e7f30](https://github.com/idvorkin/context-grabber/commit/61e7f30); verified by the simulator (`ChatArchiveUITests` against the fake Cockpit); not re-run since the request gained its `Content-Type` in [9ff3ded](https://github.com/idvorkin/context-grabber/commit/9ff3ded); against the real Cockpit on the iPad not yet; bead `context-grabber-t8i`: the menu's rules are `ChatArchiverTests` (host), and the menu archiving and going back stays in `ChatArchiveUITests`; since the Inbox's All / New row put *Done* below the screen, the test scrolls down to it (bead context-grabber-zlfl), passing on the simulator 2026-11-21
- **Issues:** [#589](https://github.com/idvorkin/context-grabber/issues/589), [#591](https://github.com/idvorkin/context-grabber/issues/591), bead context-grabber-zlfl, bead context-grabber-eu7u (the menu-row tap racing the menu animation)
- **Spec:** [Chat with Larry in Grabber Native — Archiving](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a long list of chats
- **I want to** archive a thread from its ⋯ menu when I've finished reading it
- **so that** I am done with it without going back to find its row

#### Acceptance Criteria:
- **Scenario:** From inside the thread
- **Given:** I am reading a thread
- **When:** I open ⋯ and tap *Archive chat*
- **Then:** I am back on the list with the thread under *Done*

---

### User Story 309:

- **Summary:** Bring an archived chat back
- **Status:** native app only: implemented in [61e7f30](https://github.com/idvorkin/context-grabber/commit/61e7f30), and a thread the Cockpit still calls done going back under *Done* in the PR's review fix; verified by the simulator (`ChatArchiveUITests` against the fake Cockpit: the swipe and the menu); not re-run since the request gained its `Content-Type` in [9ff3ded](https://github.com/idvorkin/context-grabber/commit/9ff3ded); against the real Cockpit on the iPad not yet; bead `context-grabber-t8i`: the unarchive and its list read are `ChatArchiverTests` (host); the swipe under Done stays in `ChatArchiveUITests`, and Unarchive from the menu is no longer tapped on the simulator (the same call, host-tested)
- **Issues:** [#589](https://github.com/idvorkin/context-grabber/issues/589), [#591](https://github.com/idvorkin/context-grabber/issues/591)
- **Spec:** [Chat with Larry in Grabber Native — Archiving](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a long list of chats
- **I want to** unarchive a thread I archived
- **so that** a chat I still need returns to the live list

#### Acceptance Criteria:
- **Scenario:** Unarchive from the list or the thread
- **Given:** an archived thread under *Done*
- **When:** I swipe it left and tap *Unarchive*, or tap *Unarchive chat* in its ⋯ menu
- **Then:** it is back in the live list, unless the Cockpit still calls it done by its own rule, when it stays under *Done* and offers *Archive chat*

---

### User Story 310:

- **Summary:** A refused archive says why
- **Status:** native app only: implemented in [61e7f30](https://github.com/idvorkin/context-grabber/commit/61e7f30), and one change at a time per thread in the PR's review fix; the answers verified by host tests (`ChatTests`); the refusal on screen not yet verified: the fake Cockpit never refuses a thread it has
- **Issues:** [#589](https://github.com/idvorkin/context-grabber/issues/589), [#591](https://github.com/idvorkin/context-grabber/issues/591)
- **Spec:** [Chat with Larry in Grabber Native — Archiving](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a long list of chats
- **I want to** know when an archive or unarchive did not take
- **so that** the list never lies about where a thread is

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses
- **Given:** the Cockpit refuses or cannot be reached
- **When:** I archive or unarchive a thread, from the list or from inside it
- **Then:** it goes back where it was and a copyable problem says why, on the screen I am on, until my next archive or a pull to refresh


---

### User Story 311:

- **Summary:** Archive several chats at once
- **Status:** native app only: implemented in [9027855](https://github.com/idvorkin/context-grabber/commit/9027855); verified on the simulator by `ChatArchiveUITests` against the fake Cockpit; the real Cockpit not yet; #685: *Archive (N)* sits below the floating buttons, clear of them, on the #685 branch after review, with an assertion added to `ChatArchiveUITests` that has not run yet (the pipeline is host-only); bead `context-grabber-t8i`: the ticks, *Archive (N)*, Cancel and one Undo for the batch are `ChatArchiverTests` (host); real ticks, *Archive (2)* clear of the buttons and its Undo stay in `ChatArchiveUITests`
- **Issues:** [#599](https://github.com/idvorkin/context-grabber/issues/599), [#685](https://github.com/idvorkin/context-grabber/issues/685)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man with a list full of finished chats
- **I want to** tick several and archive them with one tap
- **so that** I can clear the list without swiping each one

#### Acceptance Criteria:
- **Scenario:** Several together
- **Given:** the chat list shows live threads
- **When:** I tap *Select*, tick two, and tap *Archive (2)*, below the floating buttons and clear of them
- **Then:** both fold under *Done*, the list says *Archived 2 chats* with *Undo* for five seconds, and *Undo* brings both back

---

### User Story 312:

- **Summary:** Larry proposes that a chat looks done
- **Status:** native app only: implemented in [9027855](https://github.com/idvorkin/context-grabber/commit/9027855); verified on the simulator by `ChatArchiveUITests` against the fake Cockpit; Larry's mark on the real Cockpit not yet (he agreed `looks_done` and is building it); bead `context-grabber-t8i`: what Review ticks and its line are `ChatArchiverTests` (host); the tap path is `sim-smoke.sh`'s `GRABBER_CHAT_SELECT` check
- **Issues:** [#599](https://github.com/idvorkin/context-grabber/issues/599)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who forgets to close chats
- **I want to** see which ones Larry thinks are finished and approve them together
- **so that** the list stays clear, and nothing is closed behind my back

#### Acceptance Criteria:
- **Scenario:** Reviewing the proposals
- **Given:** Larry has marked a thread as looking done
- **When:** I open the chat list
- **Then:** the row says *Looks done*, the thread stays where it is, and a line at the top says *1 chat looks done* with *Review*

---

### User Story 313:

- **Summary:** Cancel leaves Select with nothing archived
- **Status:** native app only: implemented in [9027855](https://github.com/idvorkin/context-grabber/commit/9027855); verified on the simulator by `ChatArchiveUITests` against the fake Cockpit; the real Cockpit not yet; bead `context-grabber-t8i`: `ChatArchiverTests` (host)
- **Issues:** [#599](https://github.com/idvorkin/context-grabber/issues/599)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who ticked more than he meant to
- **I want to** back out of Select
- **so that** nothing is archived until I say so

#### Acceptance Criteria:
- **Scenario:** Changing my mind
- **Given:** I have ticked threads
- **When:** I tap *Cancel*
- **Then:** nothing is archived, and the rows open their threads again

---

### User Story 314:

- **Summary:** Approve what Larry proposed, keeping any I choose
- **Status:** native app only: implemented in [9027855](https://github.com/idvorkin/context-grabber/commit/9027855); verified on the simulator by `ChatArchiveUITests` against the fake Cockpit; Larry's mark on the real Cockpit not yet (he agreed `looks_done` and is building it); bead `context-grabber-t8i`: what Review ticks and the one-tap archive are `ChatArchiverTests` (host); the taps are `sim-smoke.sh`'s `GRABBER_CHAT_SELECT` check; #1098: the unticked proposals are turned down on *Archive (N)*, implemented in [2abe843c](https://github.com/idvorkin/context-grabber/commit/2abe843c), verified on the host by `ChatLooksDoneDeclinedTests` and the Mac build, the phone not yet
- **Issues:** [#599](https://github.com/idvorkin/context-grabber/issues/599), [#1098](https://github.com/idvorkin/context-grabber/issues/1098)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who forgets to close chats
- **I want to** untick any proposal I disagree with and archive the rest
- **so that** Larry's judgement stays a proposal I approve

#### Acceptance Criteria:
- **Scenario:** Approving
- **Given:** I tapped *Review*
- **When:** I untick any I want to keep and tap *Archive (N)*
- **Then:** the ticked ones fold under *Done* with *Undo*, and the rest stay live without *Looks done*, so the next *Review* doesn't offer them again (#1098); *Cancel* turns nothing down

---

### User Story 823:

- **Summary:** Review shows only the chats that look done
- **Status:** native app only: implemented in [b2867e90](https://github.com/idvorkin/context-grabber/commit/b2867e90) (bead context-grabber-szom); verified on the host by `ChatArchiverTests` (Review opens on Recommendations, only what looks done shows, *Nothing looks done* when none is left), the Mac build, and the simulator by `ChatArchiveUITests.testReviewShowsOnlyRecommendationsAndTicksSurviveTheSwitch` against the fake Cockpit; the phone and the real Cockpit not yet
- **Issues:** bead context-grabber-szom
- **Spec:** [Native chat — Reviewing only what looks done](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man approving Larry's proposals to close chats
- **I want to** see only the chats he thinks are finished while I review them
- **so that** the proposals aren't lost among every other live chat

#### Acceptance Criteria:
- **Scenario:** Reviewing the recommendations
- **Given:** two live chats look done and others don't
- **When:** I tap *Review*
- **Then:** the switch at the top reads *Recommendations*, only those two show, both ticked, and *Archive (2)* archives them

---

### User Story 1138:

- **Summary:** Open a chat while ticking, and come back to the same ticks
- **Status:** native app only: implemented in [4e573f98](https://github.com/idvorkin/context-grabber/commit/4e573f98); verified on the host (`just native-test`), the Mac build (`just native-build-mac`) and the iPad simulator (iPad Pro 11-inch (M5)) by `ChatArchiveUITests.testAChatOpenedWhileTickingComesBackToTheSameTicks` against the fake Cockpit, the class green; the iPhone simulator and the phone not yet (no iPhone runs during the whiteboard work)
- **Issues:** [#1258](https://github.com/idvorkin/context-grabber/issues/1258)
- **Spec:** [Native chat — Reading a chat before archiving it](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man reviewing which chats to archive
- **I want to** open one to see what it says, then come back to my ticks
- **so that** I archive only what I've checked, without starting the review again

#### Acceptance Criteria:
- **Scenario:** Peeking at a chat while ticking
- **Given:** I tapped *Review* or *Select* and ticked a chat
- **When:** I press and hold a row and tap *Open chat*, or tap the arrow at its end, then tap *Back*
- **Then:** the chat opened as it would from the list, and back on the list I am still ticking, on the same side of the switch, with the same ticks and the same *Archive (N)*; opening it ticked or unticked nothing

---

### User Story 824:

- **Summary:** Switch between the recommendations and every chat without losing a tick
- **Status:** native app only: implemented in [b2867e90](https://github.com/idvorkin/context-grabber/commit/b2867e90) (bead context-grabber-szom); verified on the host by `ChatArchiverTests` (Select opens on All, ticks survive the switch, *Archive (N)* takes the hidden tick), the Mac build, and the simulator by `ChatArchiveUITests.testReviewShowsOnlyRecommendationsAndTicksSurviveTheSwitch` against the fake Cockpit; the phone not yet
- **Issues:** bead context-grabber-szom
- **Spec:** [Native chat — Reviewing only what looks done](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man reviewing Larry's proposals who spots another chat to close
- **I want to** switch to every live chat, tick it too, and archive them all in one tap
- **so that** one review clears everything I'm done with

#### Acceptance Criteria:
- **Scenario:** Ticks survive the switch
- **Given:** I tapped *Review*, or *Select*, which opens on *All*
- **When:** I switch to *All*, tick another chat, and switch back to *Recommendations*
- **Then:** every tick I made is still there, *Archive (N)* counts the chat ticked under *All* though it isn't shown, and archiving takes all of them

---

### User Story 1120:

- **Summary:** Turn down a chat Larry thinks looks done
- **Status:** native app only: implemented in [2abe843c](https://github.com/idvorkin/context-grabber/commit/2abe843c) (#1098); verified on the host by `ChatLooksDoneDeclinedTests` and the Mac build; the simulator and the phone not yet
- **Issues:** [#1098](https://github.com/idvorkin/context-grabber/issues/1098)
- **Spec:** [Native chat — Turning a proposal down](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who disagrees with Larry that a chat is finished
- **I want to** take his *Looks done* off it with a swipe
- **so that** the proposals I've already said no to stop asking for my attention

#### Acceptance Criteria:
- **Scenario:** Saying not done
- **Given:** a live chat says *Looks done* and the line at the top says *1 chat looks done*
- **When:** I swipe its row from the leading edge and tap *Not done*
- **Then:** the row loses *Looks done*, the line at the top goes, the chat stays live where it was, and the next *Review* doesn't offer it

---

### User Story 1121:

- **Summary:** A turned-down chat looks done again only when Larry proposes it again
- **Status:** native app only: implemented in [2abe843c](https://github.com/idvorkin/context-grabber/commit/2abe843c) (#1098); verified on the host by `ChatLooksDoneDeclinedTests` and the Mac build; the simulator and the phone not yet
- **Issues:** [#1098](https://github.com/idvorkin/context-grabber/issues/1098)
- **Spec:** [Native chat — Turning a proposal down](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who turned down one of Larry's proposals
- **I want to** see it again only if Larry proposes it again later
- **so that** my no sticks, and his next judgement still reaches me

#### Acceptance Criteria:
- **Scenario:** A new proposal after the old one was cleared
- **Given:** I turned down a chat's *Looks done*, and it stays turned down across launches while the Cockpit still carries that proposal
- **When:** I write in it, which clears Larry's proposal, and Larry later marks it as looking done again
- **Then:** the row says *Looks done* again and the line at the top counts it

---

### User Story 1122:

- **Summary:** A board's thread has *Board* in its top bar, back to the board
- **Status:** native app only: implemented in [2833e9b0](https://github.com/idvorkin/context-grabber/commit/2833e9b0) (#1091); verified on the host by `ChatThreadBoardTests` (the newest board message names it, else this device's record; none for a thread with no board), the Mac build, and the simulator (rung 2, iPhone 17, 2026-11-21) by `ChatImageUITests.testABoardsThreadHasBoardInItsBarBackToTheBoard` against the fake Cockpit; the iPad and the phone not yet; a board drawn here opening at once in [4933b0ba](https://github.com/idvorkin/context-grabber/commit/4933b0ba) (#1137)
- **Issues:** [#1091](https://github.com/idvorkin/context-grabber/issues/1091), [#1137](https://github.com/idvorkin/context-grabber/issues/1137), bead context-grabber-dbku
- **Spec:** [Native chat — A board's thread opens its board](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who left his board for its thread with *Open in Chat*
- **I want to** tap *Board* in the thread's top bar
- **so that** I am back on the board as it is now, and from its *Back* on every board, without hunting for a picture to zoom

#### Acceptance Criteria:
- **Scenario:** Back to the board from its thread
- **Given:** a thread holds a message sent from a board that iCloud or this device holds, or this device started the thread from one of its boards
- **When:** I open the thread and tap *Board*
- **Then:** a board drawn on this device opens at once, another device's after iCloud is asked, with what is on it now, sliding in over the thread with no home or boards list on the way, and its *Back* comes back to the thread (bead context-grabber-dbku)

---

### User Story 1124:

- **Summary:** A thread with no board has no *Board* in its top bar
- **Status:** native app only: implemented in [2833e9b0](https://github.com/idvorkin/context-grabber/commit/2833e9b0) (#1091); verified on the host by `ChatThreadBoardTests` (none for a thread with no board) and on the simulator (rung 2, iPhone 17, 2026-11-21) by `ChatImageUITests.testAThreadWithNoBoardHasNoBoardInItsBar` against the fake Cockpit; the iPad and the phone not yet
- **Issues:** [#1091](https://github.com/idvorkin/context-grabber/issues/1091)
- **Spec:** [Native chat — A board's thread opens its board](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man reading a thread that never came from a board
- **I want to** see no *Board* in its top bar
- **so that** the bar never offers a way to a board that isn't there

#### Acceptance Criteria:
- **Scenario:** A thread with no board
- **Given:** a thread with no message from a board, which no board of this device started
- **When:** I open it
- **Then:** its top bar has no *Board*

---

### User Story 1123:

- **Summary:** *Board* on a thread whose board can't be opened says why and keeps the thread
- **Status:** native app only: implemented in [2833e9b0](https://github.com/idvorkin/context-grabber/commit/2833e9b0) (#1091); verified on the simulator (rung 2, iPhone 17, 2026-11-21) by `ChatImageUITests.testBoardOnAThreadWhoseBoardIsMissingSaysSoAndTheThreadStays` against the fake Cockpit (a board no device has); a board deleted on another device, or a drawing that fails to come down, not yet; a missing board's problem within about five seconds however slowly iCloud answers in [ce9c111a](https://github.com/idvorkin/context-grabber/commit/ce9c111a) (context-grabber-4qel), verified on the host by `BoardFindTests` (the wait cut short while the sync runs on) and the Mac build; the simulator (rung 2: `ChatImageUITests` on the iPhone and iPad, `WhiteboardRowDeleteUITests`, and a session log with a forced `icloud: no_answer`) owed once the simulators work
- **Issues:** [#1091](https://github.com/idvorkin/context-grabber/issues/1091), bead context-grabber-4qel
- **Spec:** [Native chat — A board's thread opens its board](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man tapping *Board* on an old board's thread
- **I want to** be told when the board can't be opened
- **so that** I stay in the thread and never land on a blank or old board by mistake

#### Acceptance Criteria:
- **Scenario:** A board that can't be opened
- **Given:** the thread's board was deleted, isn't on this device even after asking iCloud, or its latest drawing didn't come down
- **When:** I tap *Board*
- **Then:** the button reads *Looking for the board…* while it asks, for no more than about five seconds however slowly iCloud answers, then a copyable problem at the top of the thread says so (and that iCloud hadn't answered, when it hadn't), and the thread stays open

---

### User Story 1125:

- **Summary:** A file delivered to a chat shows as a row that opens it
- **Status:** native app only: implemented in [28ae5154](https://github.com/idvorkin/context-grabber/commit/28ae5154) (#633); the row's kind and name verified on the host by `ChatTests`; `ChatFileUITests` (rung 2, iPhone 17 against the fake Cockpit, 2026-11-21) sees the row read *Lease.pdf, PDF* and the tap open the system preview; against the real Cockpit on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — A delivered file in the thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who sent him a PDF
- **I want to** see it in the thread and open it again from there
- **so that** the conversation shows what Larry was given, and I can read it beside his answer

#### Acceptance Criteria:
- **Scenario:** Opening a delivered PDF
- **Given:** a thread holding a message that carries a PDF the Cockpit took, its words starting with *Lease.pdf*
- **When:** I tap the row reading *Lease.pdf* and *PDF* above the message's words
- **Then:** the PDF opens in the system's preview, where I can read, share or save it

---

### User Story 1126:

- **Summary:** A delivered file that can't be fetched says why
- **Status:** native app only: implemented in [28ae5154](https://github.com/idvorkin/context-grabber/commit/28ae5154) (#633); the problem's words verified on the host by `ChatTests`; on screen, on the simulator or the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — A delivered file in the thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client opening a file while the Cockpit is away or no longer has it
- **I want to** be told what went wrong, and try again
- **so that** a tap that opens nothing never leaves me guessing

#### Acceptance Criteria:
- **Scenario:** The file can't be fetched
- **Given:** a thread's file row, and the Cockpit away or without that file
- **When:** I tap the row
- **Then:** a copyable problem under the row gives the reason and the file's address, and tapping the row again tries once more

---

### User Story 834:

- **Summary:** Show only the chats with a reply I haven't read
- **Status:** native app only: implemented in [f4889234](https://github.com/idvorkin/context-grabber/commit/f4889234), [81c5d6d4](https://github.com/idvorkin/context-grabber/commit/81c5d6d4) and [d7c83910](https://github.com/idvorkin/context-grabber/commit/d7c83910) (bead context-grabber-qp3m); verified on the host by `ChatArchiverTests` (an open chat stays in New while read, New shows only live chats with an unread reply, the pinned one only when unread, no *Done* fold, *No new messages*, Review's switch while ticking) and the Mac build; `ChatArchiveUITests.testNewHidesWhatIsReadAndIsRememberedAcrossALaunch` and `testAChatOpenedFromNewStaysOpenAndHasLeftNewOnceBack` (a chat opened from New stays open while read) pass on the simulator (rung 2, iPhone 17, 2026-11-21, main 0228020e); the phone not yet
- **Issues:** bead context-grabber-qp3m
- **Spec:** [Native chat — Only the new messages](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man with a long chat list and a few new replies in it
- **I want to** switch the list to only the chats with something new
- **so that** I read what's waiting without scanning every row for the unread mark

#### Acceptance Criteria:
- **Scenario:** Switching to New
- **Given:** two live chats have a reply I haven't read and others don't
- **When:** I switch the list to *New*
- **Then:** only those two show, in the list's order, with no *Done* fold; after I open one and come back only the other is left; with none left the list says *No new messages*, and *All* shows every chat again

---

### User Story 835:

- **Summary:** The list remembers New or All on each device
- **Status:** native app only: implemented in [f4889234](https://github.com/idvorkin/context-grabber/commit/f4889234) and [81c5d6d4](https://github.com/idvorkin/context-grabber/commit/81c5d6d4) (bead context-grabber-qp3m); what is remembered and that anything else restores as *All* verified on the host by `ChatArchiverTests`, and the Mac build; the relaunch is `ChatArchiveUITests.testNewHidesWhatIsReadAndIsRememberedAcrossALaunch`, passing on the simulator (rung 2, iPhone 17, 2026-11-21); the phone not yet
- **Issues:** bead context-grabber-qp3m
- **Spec:** [Native chat — Only the new messages](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who prefers to see only what's new on his phone
- **I want to** find the list as I left it the next time I open the app
- **so that** I don't switch it back every time

#### Acceptance Criteria:
- **Scenario:** Coming back to the app
- **Given:** I switched the list to *New* on this device
- **When:** I quit the app and open Chat again
- **Then:** the list is still on *New*; another device keeps its own choice

---

### User Story 838:

- **Summary:** A chip names the machine that started a chat
- **Status:** not built: spec written for bead context-grabber-p5s4; waits on the Cockpit naming the machine that started a thread (bead context-grabber-l0g1), which no Cockpit does today
- **Issues:** bead context-grabber-p5s4, bead context-grabber-l0g1
- **Spec:** [Native chat — Which machine started a chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man whose computers start chats with Larry on their own
- **I want to** see which machine started a chat, on its row and inside it
- **so that** I can tell a machine's chat from one I started without opening it

#### Acceptance Criteria:
- **Scenario:** A chat a machine started
- **Given:** the Cockpit says a chat was started by the machine *ig-mba*, and another was started by me on the phone
- **When:** I open the chat list, and then the first chat
- **Then:** its row and its header show a chip reading *ig-mba*; the chat I started has no chip; a Cockpit that names no machine shows no chip on any chat

---

### User Story 315:

- **Summary:** A batch that partly fails says which and why
- **Status:** native app only: implemented for #599; the problem's text verified on the host by `ChatTests`; a refusal in a batch not yet driven on the simulator or the phone
- **Issues:** [#599](https://github.com/idvorkin/context-grabber/issues/599)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man archiving several chats at once
- **I want to** see every chat that didn't archive and why
- **so that** no refusal is hidden behind a later one

#### Acceptance Criteria:
- **Scenario:** Some refused
- **Given:** I tapped *Archive (N)* or *Undo* for several chats
- **When:** the Cockpit refuses or doesn't answer for two of them
- **Then:** those two go back where they were and one copyable problem names both with their reasons

---

### User Story 316:

- **Summary:** One always-on chat with Larry pinned at the top
- **Status:** native app only: implemented in [542ad39](https://github.com/idvorkin/context-grabber/commit/542ad39), on the Cockpit's pinned thread (cockpit `ace4083`); verified on the simulator by `ChatArchiveUITests` against the fake Cockpit; on the devices not yet; bead `context-grabber-t8i`: no swipe, no tick and no menu for the pinned thread are `ChatArchiverTests` (host); its place on top and its VoiceOver label stay in `ChatArchiveUITests`
- **Issues:** [#598](https://github.com/idvorkin/context-grabber/issues/598)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man with something to tell Larry and no thread to put it in
- **I want to** find one chat always at the top of the list
- **so that** I can drop anything into it without starting a new thread

#### Acceptance Criteria:
- **Scenario:** The pinned thread
- **Given:** the Cockpit has a pinned thread, even one with no messages
- **When:** I open the chat list
- **Then:** it is first, with a pin and *Drop anything here* until it has a message; it opens and takes messages like any thread, has no swipe to archive and no tick in *Select*, never says *Looks done*, and its screen has no ⋯ menu; with only this thread live, *Select* is off

---

### User Story 317:

- **Summary:** A board picture in a thread jumps to that board as it is now
- **Status:** native app only: implemented in [f37d267](https://github.com/idvorkin/context-grabber/commit/f37d267), a board drawn here opening at once in [4933b0ba](https://github.com/idvorkin/context-grabber/commit/4933b0ba) (#1137, story 1137); verified on the simulator against the fake Cockpit (the jump); a board that comes down from iCloud on the jump, and sending `board` from the app (another branch), not yet
- **Issues:** [#603](https://github.com/idvorkin/context-grabber/issues/603), [#1137](https://github.com/idvorkin/context-grabber/issues/1137), bead context-grabber-dbku
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client looking at an old picture of a whiteboard in a thread
- **I want to** zoom in on it and tap *Jump to board*
- **so that** I am on the board as it is now, not looking at a stale screenshot

#### Acceptance Criteria:
- **Scenario:** A picture from a board
- **Given:** a thread holds a picture sent from a whiteboard that iCloud or this device holds
- **When:** I tap the picture, then *Jump to board*
- **Then:** the full-size view goes down and the board slides in over the thread with what is on it now (at once for a board drawn on this device, after asking iCloud for another device's), with no home or boards list on the way; *Back* on the board comes back to the thread, and no full-size view is left in the way (bead context-grabber-dbku)

---

### User Story 318:

- **Summary:** A picture that didn't come from a board has no jump
- **Status:** native app only: implemented in [f37d267](https://github.com/idvorkin/context-grabber/commit/f37d267); verified on the simulator against the fake Cockpit
- **Issues:** [#603](https://github.com/idvorkin/context-grabber/issues/603)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client zooming in on any other picture in a thread
- **I want to** see only *Done*
- **so that** no button offers a board that doesn't exist

#### Acceptance Criteria:
- **Scenario:** A picture with no board
- **Given:** a thread holds a picture that didn't come from a board
- **When:** I tap it
- **Then:** it opens full size as ever, with *Done* and no *Jump to board*

---

### User Story 319:

- **Summary:** A jump to a board that can't be opened says why and keeps the picture
- **Status:** native app only: implemented in [f37d267](https://github.com/idvorkin/context-grabber/commit/f37d267); verified on the simulator against the fake Cockpit (a board no device has); a board deleted on another device, or a drawing that fails to come down, not yet; since story 770 why a board can't open is `BoardIndexTests.testABoardThatCantOpenSaysWhy` on the host, and a link to a board no device has is checked on the simulator by `WhiteboardRowDeleteUITests` (the chat suite's own copy of that check was removed); a missing board's problem within about five seconds however slowly iCloud answers in [ce9c111a](https://github.com/idvorkin/context-grabber/commit/ce9c111a) (context-grabber-4qel), verified on the host by `BoardFindTests` (the wait cut short while the sync runs on) and the Mac build; the simulator (rung 2: `ChatImageUITests` on the iPhone and iPad, `WhiteboardRowDeleteUITests`, and a session log with a forced `icloud: no_answer`) owed once the simulators work
- **Issues:** [#603](https://github.com/idvorkin/context-grabber/issues/603), bead context-grabber-4qel
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client jumping to a board from an old picture
- **I want to** be told when the board can't be opened as it is now
- **so that** I keep the picture and never land on a blank or old board by mistake

#### Acceptance Criteria:
- **Scenario:** A board that can't be opened
- **Given:** the picture's board was deleted, isn't on this device even after asking iCloud, or its latest drawing didn't come down
- **When:** I tap *Jump to board*
- **Then:** within about five seconds however slowly iCloud answers, a copyable problem says so over the picture (and that iCloud hadn't answered, when it hadn't), which stays open until I close it

---

### User Story 1137:

- **Summary:** A jump to a board drawn on this device is quick
- **Status:** native app only: implemented in [4933b0ba](https://github.com/idvorkin/context-grabber/commit/4933b0ba) (#1137); verified on the host by `BoardFindTests` (this device's board here opens without asking, another device's or one not here asks, a jump asks once), the Mac build, and the simulator (rung 2, iPhone 17 and iPad Pro 11-inch (M5), 2026-11-22) by `ChatImageUITests.testAPictureFromABoardJumpsToIt`, whose session log shows `find` icloud: own_here in 1 ms, then just_asked as the boards came up, and the picture's cover down in 29 ms (577 ms on the iPad before); another device's board through a real iCloud, and the iPad, not yet; the board coming up as soon as the thread has gone, not after a fixed 0.7 s, in [336b13c4](https://github.com/idvorkin/context-grabber/commit/336b13c4) (bead context-grabber-mzdf): the jump's `open_url` to `open_whiteboard` was 703–722 ms, now 104–228 ms with `links` settled via gone in every run (host `HomeStackTests`, the Mac build, the simulator rung 2 on iPhone 17 and iPad Pro 11-inch (M5), 2026-11-22, three runs each of the jump and *Board* tests and the chat suite); the phone not yet
- **Issues:** [#1137](https://github.com/idvorkin/context-grabber/issues/1137), bead context-grabber-mzdf (the fixed 0.7 s pause after the thread closed was most of what was left)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** a man on the iPad who left his board for its thread and wants to get back to it
- **I want to** tap *Jump to board* on a picture, or *Board* in the thread's bar, and be on the board straight away
- **so that** going back to the board feels like a link, not a wait on iCloud (it took nearly three seconds, half of it asking iCloud twice)

#### Acceptance Criteria:
- **Scenario:** Jumping to a board
- **Given:** a thread holds a picture of a board, drawn on this device with its drawing here, or drawn on another device
- **When:** I tap the picture, then *Jump to board* (or *Board* in the thread's bar)
- **Then:** a board drawn here opens at once from what is here, with no *Looking for the board…* wait and no slide as the picture goes down, and iCloud isn't asked on the way (a delete made elsewhere that hasn't reached this device lands once the board is closed, unless I drew on it); another device's board opens after iCloud is asked once, so its newest ink is there, and never a second time as the board comes up; either way the board comes up as soon as the thread has finished going, not after a fixed pause

---

### User Story 480:

- **Summary:** A paperclip attaches a PDF or any document to a message
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); reading and classifying a pick verified on the host by `ChatFileTests`; the paperclip seen on the simulator; the document picker and the file on the bar only on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a PDF on my phone
- **I want to** pick it from the chat bar and send it with or without words
- **so that** Larry can read it without my leaving the conversation

#### Acceptance Criteria:
- **Scenario:** Picking a file
- **Given:** I am in a thread or a new chat
- **When:** I tap the paperclip and choose a PDF
- **Then:** it sits above the field by name and size with *Remove file*, and Send is on with no words typed

---

### User Story 481:

- **Summary:** A picked file comes off the bar before it is sent
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); needs the document picker, on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who picked the wrong file
- **I want to** take it off the bar
- **so that** the wrong file never reaches Larry

#### Acceptance Criteria:
- **Scenario:** Removing it
- **Given:** a file is on the bar
- **When:** I tap *Remove file*
- **Then:** the bar holds only what I typed, and nothing is sent

---

### User Story 482:

- **Summary:** A message carries one attachment, the newer
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); needs the document picker, on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client changing my mind about what to attach
- **I want to** have the newer attachment replace the older
- **so that** I always know what the message carries

#### Acceptance Criteria:
- **Scenario:** One attachment to a message
- **Given:** a pasted image or a picked file is on the bar
- **When:** I add the other
- **Then:** the newer one replaces it

---

### User Story 483:

- **Summary:** A picture from the file picker goes as a picture
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); telling a picture from a document verified on the host by `ChatFileTests`; the preview needs the document picker, on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a photo in Files
- **I want to** have it treated as the picture it is
- **so that** Larry sees it as he sees any picture

#### Acceptance Criteria:
- **Scenario:** A picture from the picker
- **Given:** I am on the bar
- **When:** I pick a photo from Files
- **Then:** it previews and goes as a pasted picture would

---

### User Story 484:

- **Summary:** A file sent with no network waits on the phone
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); staying in the waiting state verified on the host by `ChatFileTests`; waiting out no network on the phone not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client on a patchy connection
- **I want to** send a file as I would any message
- **so that** it is never lost and never lands twice

#### Acceptance Criteria:
- **Scenario:** Sending with no network
- **Given:** I have no connection
- **When:** I send a file
- **Then:** the message shows *Not sent yet* with the file's name, and goes when the network returns

---

### User Story 485:

- **Summary:** A new chat from a file alone is titled with its name
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); verified on the host by `ChatFileTests`
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client starting a chat with only a file
- **I want to** see the chat named after it
- **so that** I can find it in the list

#### Acceptance Criteria:
- **Scenario:** A new chat from a file
- **Given:** a new chat with only a file on the bar
- **When:** I tap Send
- **Then:** the chat is titled with the file's name

---

### User Story 486:

- **Summary:** A file's name reaches Larry in the message's words
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); verified on the host by `ChatFileTests`, against a stand-in for a Cockpit that takes files; the real Cockpit takes pictures only today, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sending a named document
- **I want to** have Larry told what it is called
- **so that** he knows which document we are talking about

#### Acceptance Criteria:
- **Scenario:** Its name reaches Larry
- **Given:** the Cockpit takes the file
- **When:** the message lands
- **Then:** its words start with the file's name, then what I typed

---

### User Story 487:

- **Summary:** A file the Cockpit won't take says why and stays on the phone
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the refusal and the kept file verified on the host by `ChatFileTests`; the problem seen on the simulator against the fake Cockpit, and the refusal checked by the smoke until context-grabber-gp7; since then the refusal with no message after it is `InboxOutboxTests` (host) and the smoke no longer relaunches for it; #633, the refusal now for a kind of file the Cockpit doesn't take (since Cockpit story 167 it takes PDFs, plain text and Office files) in [28ae5154](https://github.com/idvorkin/context-grabber/commit/28ae5154)
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a kind of file the Cockpit doesn't take
- **I want to** be told the file did not go, and keep it
- **so that** I never believe Larry has a file he doesn't

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses a file
- **Given:** a kind of file the Cockpit doesn't take (since Cockpit story 167 it takes pictures, PDFs, plain text, Word, Excel and PowerPoint; a zip, say, it refuses)
- **When:** I send it
- **Then:** a copyable problem names the file and gives the Cockpit's reason, the file stays on the phone, and no message goes without it

---

### User Story 488:

- **Summary:** A refused file goes with one tap once the Cockpit takes files
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); a resend under the same id, landing once in its thread, verified on the host by `ChatFileTests`, against a stand-in for a Cockpit that takes files; the real Cockpit taking a file not yet; since context-grabber-gp7, *Send again* through the outbox, refused then taken, is `InboxOutboxTests` (host)
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with a file the Cockpit refused
- **I want to** send it again without picking it again
- **so that** the day the Cockpit takes files, nothing needs redoing

#### Acceptance Criteria:
- **Scenario:** Sending it again
- **Given:** a refused file
- **When:** I tap *Send again* once the Cockpit takes files
- **Then:** the same message goes, once, and lands in its thread

---

### User Story 489:

- **Summary:** Sending a file again too soon changes nothing
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the store and the second refusal verified on the host by `ChatFileTests`; `GRABBER_CHAT_SEND_AGAIN` and its smoke check written, not yet run on the simulator; the tap itself on the phone, not yet; since context-grabber-gp7 the kept file uploading again, refused again with no message, is `InboxOutboxTests` (host) and the smoke check is gone; #633, the criteria now for a kind of file the Cockpit still doesn't take in [28ae5154](https://github.com/idvorkin/context-grabber/commit/28ae5154)
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client trying again while the Cockpit still doesn't take the file
- **I want to** hear the same answer and keep the file
- **so that** trying costs me nothing

#### Acceptance Criteria:
- **Scenario:** Sending again too soon
- **Given:** a refused file, and the Cockpit still doesn't take its kind
- **When:** I tap *Send again*
- **Then:** it is refused again with the same problem, and still kept

---

### User Story 490:

- **Summary:** Deleting a refused file takes it off the phone
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the store verified on the host by `ChatFileTests`; the swipe and the menu on a refused file on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who no longer needs a refused file
- **I want to** let it go
- **so that** it doesn't sit on my phone for good

#### Acceptance Criteria:
- **Scenario:** Letting it go
- **Given:** a refused file
- **When:** I delete it
- **Then:** it is gone from the phone

---

### User Story 491:

- **Summary:** A new chat says where its refused file stays and what the next message does
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the line's words verified on the host by `ChatFileTests`; on screen, on the simulator or the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client whose new chat began with a refused file
- **I want to** know what happens if I keep typing
- **so that** I don't think the file went with my next message, or lost it

#### Acceptance Criteria:
- **Scenario:** Writing on after a refused file
- **Given:** a new chat whose first message is a refused file
- **When:** I look at the bar
- **Then:** a line says the file stays under *Not sent yet* and that a new message starts a separate chat without it

---

### User Story 492:

- **Summary:** A file the phone can no longer read says so and offers no Send again
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); verified on the host by `ChatFileTests`; on screen on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client whose kept file went missing from the phone
- **I want to** be told plainly
- **so that** I don't blame the Cockpit, or tap a button that can only fail

#### Acceptance Criteria:
- **Scenario:** The file is gone
- **Given:** a waiting file whose bytes are no longer on the phone
- **When:** it comes up to send
- **Then:** a copyable problem says the phone could not read it and to pick it again, with no *Send again*

---

### User Story 493:

- **Summary:** A file over 100 MB says so when it is picked
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the limit raised from 10 MB to 100 MB to match the Cockpit (2026-11-24) in [f94efbcc](https://github.com/idvorkin/context-grabber/commit/f94efbcc); verified on the host by `ChatFileTests`; the problem on screen needs the document picker, on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633), [#1426](https://github.com/idvorkin/context-grabber/issues/1426)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client picking a large file
- **I want to** hear about it at once
- **so that** I don't wait on a send that can never work

#### Acceptance Criteria:
- **Scenario:** Too big
- **Given:** a file over 100 MB
- **When:** I pick it
- **Then:** a copyable problem gives its name and size and the limit, and the draft stays as it was

---

### User Story 494:

- **Summary:** An empty or unreadable file says so when it is picked
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); verified on the host by `ChatFileTests`; the problem on screen needs the document picker, on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client picking a broken file
- **I want to** hear about it at once
- **so that** I don't wait on a send that can never work

#### Acceptance Criteria:
- **Scenario:** Empty or unreadable
- **Given:** a file with nothing in it or that the phone can't read
- **When:** I pick it
- **Then:** a copyable problem says which, and the draft stays as it was

---

### User Story 495:

- **Summary:** The share card offers my recent chats beside New chat
- **Status:** native app only: implemented in [c362df7](https://github.com/idvorkin/context-grabber/commit/c362df7); verified by `ShareThreadsTests` (host: five live chats, the pinned one first, Done and archived left out, read from the chat route); the app and the extension build for the simulator; simctl cannot drive a share sheet, so the card itself is not yet seen on any rung, a share from Safari on the phone still for Igor
- **Issues:** [#587](https://github.com/idvorkin/context-grabber/issues/587)
- **Spec:** [Chat with Larry in Grabber Native — Sharing into a chat that is already going](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing something that belongs to a conversation already going
- **I want to** see my recent chats on the share card
- **so that** I can pick the one it belongs to instead of opening another thread

#### Acceptance Criteria:
- **Scenario:** The card with the Cockpit in reach
- **Given:** I have eight live chats, the always-on one among them, plus a Done chat and an archived one
- **When:** I share a Safari link to *Grabber Native*
- **Then:** the card shows *New chat* ticked and five chats below it, the always-on one first and then newest activity, each with its title and age, and neither the Done nor the archived chat

---

### User Story 496:

- **Summary:** A share goes into the chat I pick, once
- **Status:** native app only: implemented in [c362df7](https://github.com/idvorkin/context-grabber/commit/c362df7); verified by `ShareThreadsTests` (host: a link and a picture go to that thread's path with the note and the item's id, and no title); the app and the extension build for the simulator; simctl cannot drive a share sheet, so picking a chat on the card and the message landing in the real Cockpit are still for Igor on the phone; #673: the card's field is headed *Message*, in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3)
- **Issues:** [#587](https://github.com/idvorkin/context-grabber/issues/587), [#673](https://github.com/idvorkin/context-grabber/issues/673) (the card's *Message*)
- **Spec:** [Chat with Larry in Grabber Native — Sharing into a chat that is already going](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who picked a recent chat on the share card
- **I want to** have the shared thing land as that chat's next message
- **so that** Larry reads it in context and no extra thread appears

#### Acceptance Criteria:
- **Scenario:** Sending a link into a chat
- **Given:** the card lists my chat "Should the phone chat poll?" and I wrote the message "worth a read"
- **When:** I tap that chat, then *Send*
- **Then:** the card closes at once, and the app sends one message into that chat holding the link and the message, with no new thread; while it waits it reads *Not sent yet* in the thread, and resending after a lost answer still makes one message

---

### User Story 497:

- **Summary:** With the Cockpit out of reach, the card offers New chat alone and says why
- **Status:** native app only: implemented in [c362df7](https://github.com/idvorkin/context-grabber/commit/c362df7); verified by `ShareThreadsTests` (host: an error answer, an answer that is not a list, a timeout and another failure each read as New chat only, with the reason); the app and the extension build for the simulator; simctl cannot drive a share sheet, so the line and its *Copy* on the card, in aeroplane mode, are still for Igor on the phone; the `inbox` added line's `offered` says what the list held
- **Issues:** [#587](https://github.com/idvorkin/context-grabber/issues/587)
- **Spec:** [Chat with Larry in Grabber Native — Sharing into a chat that is already going](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing in aeroplane mode or off the tailnet
- **I want to** still share at once and know why my chats are not listed
- **so that** nothing I share waits on the network and a missing list is not a mystery

#### Acceptance Criteria:
- **Scenario:** The list cannot be read
- **Given:** the Cockpit does not answer, or answers with an error
- **When:** I share something to *Grabber Native* and wait a few seconds
- **Then:** the card offers *New chat* alone with one quiet line saying why, selectable and with *Copy*, and *Start a chat* closes the card at once with the share kept on the phone

---

### User Story 498:

- **Summary:** A share into a chat the Cockpit no longer has stays visible and says why
- **Status:** native app only: implemented in [c362df7](https://github.com/idvorkin/context-grabber/commit/c362df7); verified by `ShareThreadsTests` (host: a 404 is refused once and never resent, and the list keeps what no thread could show); `ChatNewThreadUITests` still pass on the simulator against the fake Cockpit with the list's wider rule; the row for a gone chat is not yet seen on any rung, on the phone still for Igor
- **Issues:** [#587](https://github.com/idvorkin/context-grabber/issues/587)
- **Spec:** [Chat with Larry in Grabber Native — Sharing into a chat that is already going](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who shared into a chat that has since gone
- **I want to** see that the share was refused and why
- **so that** it does not disappear into a thread I can never open

#### Acceptance Criteria:
- **Scenario:** The chat has gone
- **Given:** a share waits on the phone for a chat the Cockpit no longer lists
- **When:** the app sends it and the Cockpit answers that it has no such chat
- **Then:** Chat's list shows it under *Not sent yet* with *Larry refused it* and the reason, copyable, it is not sent again, and a swipe deletes it

---

### User Story 499:

- **Summary:** The card never waits for the list, and the list never moves my choice
- **Status:** native app only: implemented in [c362df7](https://github.com/idvorkin/context-grabber/commit/c362df7); the tick is the card's own state and only a tap changes it; no host test can see that, and the app and the extension build for the simulator; simctl cannot drive a share sheet, so a slow list on the card is still for Igor on the phone; #673: the card's field is headed *Message*, in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3)
- **Issues:** [#587](https://github.com/idvorkin/context-grabber/issues/587), [#673](https://github.com/idvorkin/context-grabber/issues/673) (the card's *Message*)
- **Spec:** [Chat with Larry in Grabber Native — Sharing into a chat that is already going](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing in a hurry
- **I want to** send as soon as I have the thing on the card, whatever the list is doing
- **so that** a slow Cockpit neither holds me up nor sends my share somewhere I did not choose

#### Acceptance Criteria:
- **Scenario:** The list arrives late
- **Given:** the card is open with *New chat* ticked and the Cockpit has not answered yet
- **When:** the recent chats arrive while I write my message
- **Then:** *New chat* stays ticked until I tap something else, and tapping *Start a chat* before they arrive starts a new chat as usual

---

### User Story 500:

- **Summary:** A voice button beside the + opens a new chat already recording
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewChatVoiceTests` (host: recording once per tap) and `ChatNewThreadUITests` (simulator: the button sits beside the +, opens *New chat* with no sheet, its mic tapped as it opens); the red seconds and the keyboard staying down on the phone not yet; [4fac40c](https://github.com/idvorkin/context-grabber/commit/4fac40c) (#961): the test takes the recognizer stopping as it starts, the simulator's answer with both permissions granted, as the mic's copyable line; read from the failing runs' session logs, rerun on the simulator not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637), [#961](https://github.com/idvorkin/context-grabber/issues/961)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client with something to say and my hands busy
- **I want to** tap one button in Chat and start talking
- **so that** a new conversation starts with my voice, without a tap on + and another on the mic

#### Acceptance Criteria:
- **Scenario:** Starting a new chat by voice
- **Given:** Chat is open and no call is live
- **When:** I tap the voice button immediately left of the +
- **Then:** an empty thread titled *New chat* opens with the ordinary bar and no sheet or dialog, the bar's mic is already red with the seconds counting, the keyboard stays down, and the session log has a `ui` line with action `open_new_chat` and voice true, then `chat_voice` lines, never my words

---

### User Story 501:

- **Summary:** A spoken first message waits for my Send
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by the first-Send path in `ChatNewThreadUITests` (simulator: nothing sent on opening); speaking, stopping and sending on the phone not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who just spoke a first message
- **I want to** read my words before they go
- **so that** a misheard sentence never reaches Larry or starts a thread by itself

#### Acceptance Criteria:
- **Scenario:** Stopping and sending
- **Given:** a new chat opened by the voice button is recording
- **When:** I speak, tap the mic to stop, read the words in the field and tap Send
- **Then:** nothing left the phone until that Send, which starts the thread as any first Send does: the message shows as *Not sent yet*, and the thread takes its first line as the title

---

### User Story 502:

- **Summary:** Backing out of a voice chat leaves nothing
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewThreadUITests` (simulator: back leaves no thread waiting); the recording stopping mid-sentence on the phone not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who changed my mind mid-sentence
- **I want to** go back to the list
- **so that** no recording keeps going and no thread appears

#### Acceptance Criteria:
- **Scenario:** Going back while it records
- **Given:** a new chat opened by the voice button is recording
- **When:** I go back to the list
- **Then:** the recording stops, no thread was started, and the session log has a `chat_voice` line with action `dropped`, why `left_thread`

---

### User Story 503:

- **Summary:** A live call keeps the microphone from the voice button
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewThreadUITests` against the fake bridge (simulator: a live call, the new chat opens with its mic idle, the line, the keyboard up); the line beside an older mic problem not run yet, and a real call's sound on the phone not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client on a call with Larry
- **I want to** see that the voice button can't take the microphone
- **so that** the call's sound is never disturbed and I'm told why nothing is recording

#### Acceptance Criteria:
- **Scenario:** Tapping it during a call
- **Given:** a call with Larry is live and the voice button beside the + is dimmed
- **When:** I tap it
- **Then:** the new chat opens with the keyboard up and nothing recording, the bar says *A call with Larry is using the microphone. End it to speak a message.*, even if an older mic problem shows beside it, the session log has a `chat_voice` line with action `refused`, why `call_live`, and the call carries on

---

### User Story 504:

- **Summary:** A voice chat that can't record still opens
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewThreadUITests` (simulator: the mic's copyable line or a recording, whichever the simulator's permissions give, with nothing sent); declining on the phone not yet; [4fac40c](https://github.com/idvorkin/context-grabber/commit/4fac40c) (#961): the test takes the recognizer stopping as it starts, the simulator's answer with both permissions granted, as the mic's copyable line; read from the failing runs' session logs, rerun on the simulator not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637), [#961](https://github.com/idvorkin/context-grabber/issues/961)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client whose microphone or speech recognition is off
- **I want to** be told what is off and keep the new chat
- **so that** I can type instead, or fix it and try the mic again

#### Acceptance Criteria:
- **Scenario:** Recording can't start
- **Given:** speech recognition or the microphone is declined, or the recognizer won't start or stops as soon as it starts
- **When:** I tap the voice button
- **Then:** the new chat stays open with a copyable line in its bar saying what is off, the field is empty, and nothing was sent

---

### User Story 505:

- **Summary:** The + stays as it was beside the voice button
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewChatVoiceTests` (host: the + never records) and `ChatNewThreadUITests` (simulator: the + after the voice button leaves the mic idle); the phone not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who wants to type
- **I want to** have the + behave as it always did
- **so that** a new button beside it never turns on the microphone when I meant to write

#### Acceptance Criteria:
- **Scenario:** Tapping the +
- **Given:** Chat is open
- **When:** I tap the +
- **Then:** the same empty thread opens with the keyboard up and nothing recording

---

### User Story 506:

- **Summary:** The + and the voice button float over the list, which uses the whole screen
- **Status:** native app only: implemented in [dd6c94d](https://github.com/idvorkin/context-grabber/commit/dd6c94d); verified by `ChatArchiveUITests` (simulator: both buttons sit in a bar across the list's foot, a swipe on a row at the foot opens Unarchive, and the bar test fails on the list as it was); the bar's solid fill not yet seen on the simulator, and how the bar looks and a thumb's swipe on the phone not yet; #685 floats the buttons in [dd5d9ef8](https://github.com/idvorkin/context-grabber/commit/dd5d9ef8), verified by `ChatArchiveUITests` (simulator: chat suite 34 passed; one swipe test failed on the suite's slow first launch, then passed 3 of 3 alone)
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637), [#685](https://github.com/idvorkin/context-grabber/issues/685)
- **Spec:** [Chat with Larry in Grabber Native — The list](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client tidying my chats
- **I want** the list to run to the bottom of the screen with the buttons floating over it
- **so that** I see as many chats as fit

#### Acceptance Criteria:
- **Scenario:** A long list
- **Given:** Chat lists more rows than fit
- **When:** I look at the bottom of the screen
- **Then:** rows run to the bottom, with the + and the voice button floating over them at the lower right, and no bar behind them

---

### User Story 507:

- **Summary:** A simulator with no address leaves the real Cockpit alone
- **Status:** native app only: implemented in [87bb116](https://github.com/idvorkin/context-grabber/commit/87bb116); the decision and the share card asking nothing are `ChatCockpitTests` on the host; the simulator smoke's log shows no send tried; a board's turn failing on the address that cannot resolve was not run
- **Issues:** [#525](https://github.com/idvorkin/context-grabber/issues/525)
- **Spec:** [Chat with Larry in Grabber Native — On a simulator](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the person running test builds on the Mac
- **I want to** launch a simulator build without naming a Cockpit
- **so that** a test run never lands in Larry's chats or marks them read

#### Acceptance Criteria:
- **Scenario:** A plain launch on the simulator
- **Given:** a simulator build launched with no chat address, on a Mac that can reach the tailnet
- **When:** chat, the Inbox, a board's turn or the share card would ask the Cockpit for anything
- **Then:** no request goes to the real Cockpit

---

### User Story 508:

- **Summary:** The simulator's outbox stays put with no address
- **Status:** native app only: implemented in [87bb116](https://github.com/idvorkin/context-grabber/commit/87bb116); `ChatCockpitTests` on the host (real store, counted requests); the simulator smoke's chat section held a message back until context-grabber-gp7; since then the held message, with no retry, is `InboxOutboxTests` (host) instead
- **Issues:** [#525](https://github.com/idvorkin/context-grabber/issues/525)
- **Spec:** [Chat with Larry in Grabber Native — On a simulator](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the person running test builds on the Mac
- **I want to** leave messages behind from an earlier test run
- **so that** the next launch without an address cannot deliver them to Larry

#### Acceptance Criteria:
- **Scenario:** Leftover test messages
- **Given:** a simulator whose outbox holds waiting messages from an earlier run
- **When:** the app launches with no chat address, as a test that has nothing to do with chat does
- **Then:** every message is still waiting afterwards, unsent and not refused, and nothing is retried on a timer

---

### User Story 509:

- **Summary:** A simulator sends only where it is pointed
- **Status:** native app only: implemented in [87bb116](https://github.com/idvorkin/context-grabber/commit/87bb116); `ChatCockpitTests` on the host; the simulator smoke's chat section saw the held message reach the fake Cockpit once until context-grabber-gp7; since then a relaunch over the same outbox delivering it once is `InboxOutboxTests` (host) instead
- **Issues:** [#525](https://github.com/idvorkin/context-grabber/issues/525)
- **Spec:** [Chat with Larry in Grabber Native — On a simulator](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the person testing chat
- **I want to** name an address when I launch
- **so that** what the simulator holds goes to that stand-in, or to the real Cockpit only because I asked

#### Acceptance Criteria:
- **Scenario:** An address named at launch
- **Given:** a simulator with a message waiting from a launch that had no address
- **When:** a later launch names an address
- **Then:** the message goes to that address, once

---

### User Story 510:

- **Summary:** A simulator with no address says why
- **Status:** native app only: implemented in [87bb116](https://github.com/idvorkin/context-grabber/commit/87bb116); the launch line, the held count and the refresh's reason are read from the log in the simulator smoke's chat section; the problem as drawn on the list and in a thread was not looked at; since context-grabber-gp7 the held count is host-only (`ChatCockpitTests`, `InboxOutboxTests`) and the smoke reads the launch line and the list's reason in one launch with nothing waiting
- **Issues:** [#525](https://github.com/idvorkin/context-grabber/issues/525)
- **Spec:** [Chat with Larry in Grabber Native — On a simulator](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the person reading a test run's log
- **I want to** see at once why chat is doing nothing
- **so that** I don't mistake a missing address for a hang or a Cockpit that is away

#### Acceptance Criteria:
- **Scenario:** No address, chat opened
- **Given:** a simulator launched with no chat address
- **When:** chat opens, or a message is written
- **Then:** the log says there is no address and how many messages it held back, and the list and an open thread show a copyable problem saying so

---

### User Story 511:

- **Summary:** A phone or an iPad is unchanged
- **Status:** native app only: implemented in [87bb116](https://github.com/idvorkin/context-grabber/commit/87bb116); the decision for a device is `ChatCockpitTests` on the host; no device was built or run, so the phone itself is for Igor
- **Issues:** [#525](https://github.com/idvorkin/context-grabber/issues/525)
- **Spec:** [Chat with Larry in Grabber Native — On a simulator](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client on the phone
- **I want to** have nothing change about how chat reaches the Cockpit
- **so that** a rule for test builds never holds up a real message

#### Acceptance Criteria:
- **Scenario:** A device with no address
- **Given:** a build on a phone or an iPad, launched as always
- **When:** a message is written
- **Then:** it goes to the Cockpit as it did before this rule

---

### User Story 512:

- **Summary:** A skill's thread is pinned under Larry's, there before its first message
- **Status:** native app only: implemented in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2); verified on the host by `ChatTests` and `ChatArchiverTests` (a pinned row has no swipe, tick or menu) and on the simulator by `ChatSkillThreadUITests` against the fake Cockpit (pinned under Larry's); the real Cockpit (cockpit#90, unmerged) and the phone not yet
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632); bead `context-grabber-rg6x` (the UI test asked for one named other row on screen, which on the iPad sat below the fold after the other chat classes had added threads: it now reads the order off every row showing)
- **Spec:** [Chat with Larry in Grabber Native — A skill's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor with a skill answering its own thread
- **I want to** find it right under Larry's pinned thread, always on
- **so that** I can ask the skill anything without hunting for the thread or closing it by accident

#### Acceptance Criteria:
- **Scenario:** Two pinned threads
- **Given:** the Cockpit pins Larry's thread and an idvorkin skill thread with no messages, and other threads are newer
- **When:** I open Chat
- **Then:** Larry's comes first, then idvorkin reading *Ask idvorkin*, then the rest, and idvorkin has no *Archive* swipe, no tick in *Select* and no **⋯** menu, and its bar says *Message idvorkin*

---

### User Story 513:

- **Summary:** A skill's reply carries its name and a lettered avatar
- **Status:** native app only: implemented in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2); verified on the simulator by `ChatSkillThreadUITests` against the fake Cockpit; the real Cockpit and the phone not yet
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632)
- **Spec:** [Chat with Larry in Grabber Native — A skill's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor reading a thread
- **I want to** see who is speaking when it isn't Larry
- **so that** I never mistake the skill's words for Larry's

#### Acceptance Criteria:
- **Scenario:** The skill answers
- **Given:** I sent a message on the idvorkin thread
- **When:** the reply lands
- **Then:** it appears by itself with *idvorkin* and a lettered avatar above the bubble, and Larry's replies elsewhere stay as they were

---

### User Story 514:

- **Summary:** A skill's failure is a copyable error, not an answer
- **Status:** native app only: implemented in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2); verified on the host by `ChatTests` and on the simulator by `ChatSkillThreadUITests` against the fake Cockpit; the real Cockpit and the phone not yet
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632)
- **Spec:** [Chat with Larry in Grabber Native — A skill's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor whose question the skill could not answer
- **I want to** see the failure as a failure, and copy it
- **so that** I know to send again and never read 🏆 on something unanswered

#### Acceptance Criteria:
- **Scenario:** The skill fails, then answers
- **Given:** the Cockpit wrote a failure row after my message and marked my message done
- **When:** I look at the thread
- **Then:** the failure is a copyable problem under the skill's name, my message shows 👀 and not 🏆, and once a real reply follows my messages before it show 🏆

---

### User Story 515:

- **Summary:** The list row and the notification name the skill when it spoke last
- **Status:** native app only: implemented in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2); the row verified on the simulator by `ChatSkillThreadUITests` against the fake Cockpit; the speaker's name on the host by `ChatTests`; the notification itself only the phone can show, not yet
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632)
- **Spec:** [Chat with Larry in Grabber Native — A skill's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor scanning the list or a notification
- **I want to** see *idvorkin*, not *Larry*, on what the skill said
- **so that** I know who has answered without opening the thread

#### Acceptance Criteria:
- **Scenario:** The skill spoke last
- **Given:** the last message on a thread is from the skill
- **When:** I read its row, or a notification comes for it
- **Then:** the row reads *idvorkin: …* and the notification's title is *idvorkin*; where I spoke last it still reads *You: …*

---

### User Story 516:

- **Summary:** A Cockpit without skill threads changes nothing
- **Status:** native app only: implemented in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2); verified on the host by `ChatTests` and on the simulator by `ChatArchiveUITests`, whose fake Cockpit has no skill thread
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632)
- **Spec:** [Chat with Larry in Grabber Native — A skill's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor on a build newer than the Cockpit
- **I want to** see Chat as it was
- **so that** the app can ship before the Cockpit's half does

#### Acceptance Criteria:
- **Scenario:** The fields aren't there
- **Given:** the Cockpit's answers have no skill, author or error fields
- **When:** I open Chat and a thread
- **Then:** the list, the replies, the bar and the notifications read Larry as before, with one pinned thread

---

### User Story 517:

- **Summary:** A message refused on a skill's thread names the skill
- **Status:** native app only: implemented in [50b4df2](https://github.com/idvorkin/context-grabber/commit/50b4df2) and [1286e05](https://github.com/idvorkin/context-grabber/commit/1286e05); the words verified on the host by `ChatFileTests`; on screen, on the simulator or the phone, not yet
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632)
- **Spec:** [Chat with Larry in Grabber Native — A skill's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor writing on a skill's thread
- **I want to** see the skill named when my message is refused
- **so that** I never think Larry was the one I wrote to

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses a text
- **Given:** I am on the idvorkin thread
- **When:** the Cockpit refuses a text I send there
- **Then:** it reads *idvorkin refused it* with the reason, as a copyable problem

---

### User Story 518:

- **Summary:** Holding a message offers what I can do with it
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host, `ChatHold.choices`: all four on Larry's words, only Quote and Copy on mine, only Yes and No on a picture alone; mine gained *Send to new chat* with story 820) and `ChatReactionUITests` (simulator, fake Cockpit: all four on Larry's message, Quote on mine); the feel of the hold on the phone and iPad, and links staying tappable, not yet
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629)
- **Spec:** [Chat with Larry in Grabber Native — Press and hold a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client reading a thread on the phone or the iPad
- **I want to** press and hold a message and see *Yes*, *No*, *Quote in reply* and *Copy*
- **so that** answering takes one gesture, and I am only offered what makes sense for that message

#### Acceptance Criteria:
- **Scenario:** Holding each kind of message
- **Given:** a thread with a message from Larry and one of mine
- **When:** I press and hold each
- **Then:** Larry's offers *Yes*, *No*, *Quote in reply* and *Copy*; mine offers *Quote in reply*, *Copy* and *Send to new chat* (story 820) but no *Yes* or *No*; a message that is only a picture offers neither *Quote in reply* nor *Copy*

---

### User Story 519:

- **Summary:** Yes or No to Larry's newest message sends that one word
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host) and `ChatReactionUITests` (simulator: the fake's Larry repeats *Yes*); `sim-smoke.sh` no longer relaunches the app to tap *Yes* through the hook, a copy of those two (test-ladder audit, 2026-11-10; [bbbeafd](https://github.com/idvorkin/context-grabber/commit/bbbeafd)); half-typed words staying in the bar and a *Yes* with no network follow from the code, not exercised on any rung; a real Larry waking on the phone not yet
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629), [#809](https://github.com/idvorkin/context-grabber/issues/809) (a sent message its thread never returns made *Yes* go out quoted for good; since [1586a17](https://github.com/idvorkin/context-grabber/commit/1586a17) it stops counting as waiting five minutes after the send and leaves the phone after seven days, verified on the Linux rung (host tests: `ChatOutboxLookTests`, `InboxOutboxTests`, `InboxTests`); the train's simulator pass on native/larry-train-1110 (iPhone 17, 2026-11-10: the Mac build and the UI tests green); the phone pending)
- **Spec:** [Chat with Larry in Grabber Native — Press and hold a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client asked a yes-or-no question
- **I want to** hold his message and tap *Yes* or *No*
- **so that** he has my answer without my typing it, even with no network

#### Acceptance Criteria:
- **Scenario:** Answering the newest message
- **Given:** Larry's message is the newest in the thread and I have words half typed in the bar
- **When:** I hold it and tap *Yes*
- **Then:** a message reading *Yes* appears at once as **Not sent yet**, reaches the Cockpit once and wakes Larry like any message, my half-typed words stay in the bar, and the log's `chat` reaction line names the reaction and the message but never the text

- **Scenario:** A sent message the thread never shows (#809)
- **Given:** a message I sent on this thread more than five minutes ago, which the Cockpit took but its thread does not list
- **When:** I hold Larry's newest message and tap *Yes*
- **Then:** my old message shows no pending bubble, *Yes* goes as the bare word, not quoted, and the old message is gone from the phone seven days after I sent it, whether or not I open the thread again

---

### User Story 540:

- **Summary:** Yes or No to an older message says which message it answers
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host: the quote, its lines, the 280-character cut, a picture alone) and `ChatReactionUITests` (simulator: *No* on an older message reaches the fake under its quote); older because something newer still waits on the phone not exercised on any rung
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629), [#809](https://github.com/idvorkin/context-grabber/issues/809) (a sent message could count as still waiting for good, so every answer was older than it; since [1586a17](https://github.com/idvorkin/context-grabber/commit/1586a17) a sent message stops counting five minutes after the send, see story 519)
- **Spec:** [Chat with Larry in Grabber Native — Press and hold a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client answering something further up the thread
- **I want to** have my *Yes* or *No* carry a quote of what it answers
- **so that** Larry never takes it as an answer to whatever was said last

#### Acceptance Criteria:
- **Scenario:** Answering further up
- **Given:** a message of Larry's with newer messages after it, sent or still waiting on the phone
- **When:** I hold it and tap *No*
- **Then:** the message sent is that message's words, each line marked `> ` and at most 280 characters, then a blank line, then *No*; a message that was only a picture is quoted as *A picture*

---

### User Story 541:

- **Summary:** Quote in reply puts the message in the bar for me to answer
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host: after what the bar held, two quotes kept) and `ChatReactionUITests` (simulator: the bar filled, the keyboard up; nothing sent was a 3 s look for an answer, dropped, as a quote only fills the bar and never reaches the outbox); a quote during a recording needs the phone's microphone, not yet
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629)
- **Spec:** [Chat with Larry in Grabber Native — Press and hold a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client replying to one point in a long thread
- **I want to** quote a message into the bar and write under it
- **so that** my reply is plainly about that message, on the phone and on the laptop alike

#### Acceptance Criteria:
- **Scenario:** Quoting into the bar
- **Given:** a message in the thread, and maybe words already in the bar or a recording going on
- **When:** I hold it and tap *Quote in reply*
- **Then:** nothing is sent; the bar holds what it held, then the message's words with each line marked `> ` and at most 280 characters, then a blank line, with the keyboard up; a recording stops with its words so far kept

---

### User Story 542:

- **Summary:** A Yes or No that can't be kept says why
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); not verified on any rung: no hook makes the phone's store fail
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629)
- **Spec:** [Chat with Larry in Grabber Native — Press and hold a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who tapped *Yes* and looked away
- **I want to** be told if the phone could not keep it
- **so that** I never believe I answered when nothing was sent

#### Acceptance Criteria:
- **Scenario:** The phone can't keep the message
- **Given:** the phone cannot store a message
- **When:** I hold a message of Larry's and tap *Yes*
- **Then:** a copyable problem at the top of the thread says so, naming the thread and the message it answered, no message appears, and the log's `error` line with where: chat_react names them but never the text

---

### User Story 543:

- **Summary:** The share card's field says Message
- **Status:** native app only: implemented in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3); verified by the iPhone 17 simulator build of the app and the extension (it compiles; nothing was run); simctl cannot drive a share sheet, so the card itself is not yet seen on any rung, a share from Safari on the phone still for Igor
- **Issues:** [#673](https://github.com/idvorkin/context-grabber/issues/673)
- **Spec:** [Chat with Larry in Grabber Native — Sharing in](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing a page to a chat
- **I want to** see the card's field called *Message*
- **so that** I know what I write lands as a chat message, not a note kept somewhere

#### Acceptance Criteria:
- **Scenario:** Opening the card
- **Given:** I am reading a page in Safari
- **When:** I share it to *Grabber Native*
- **Then:** the card's field is headed *Message* with *Optional* inside it, VoiceOver reads it as *Message*, and the word *note* is nowhere on the card

---

### User Story 544:

- **Summary:** A shared link reaches the message whole, down every path of the card
- **Status:** native app only: implemented before this issue, checked and instrumented in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3); verified by `ShareLinkTests` (host: new chat and a picked chat, with and without words, the whole request body, query and fragment kept, a long message cut only in the title, the log line holding neither link nor words); a share from Safari reaching Larry on the phone still for Igor, the `chat` line's link_in_message settling it
- **Issues:** [#673](https://github.com/idvorkin/context-grabber/issues/673)
- **Spec:** [Chat with Larry in Grabber Native — The shared link on the message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sending a page to Larry
- **I want to** have the link to the page on the message every time
- **so that** Larry can go back to the page I meant, whatever else I wrote

#### Acceptance Criteria:
- **Scenario:** One link, each way out of the card
- **Given:** a page shared from Safari at an address with a query and a fragment
- **When:** I send it to *New chat* and then to a picked chat, each with and without a message
- **Then:** all four messages start with the whole address exactly as shared, my words after it when there are any, and the log's `chat` line says link_in_message: true and holds neither the address nor my words

---

### User Story 545:

- **Summary:** The card finds the link however the other app hands it over
- **Status:** native app only: implemented in [48534a3](https://github.com/idvorkin/context-grabber/commit/48534a3); verified by `ShareLinkTests` (host, with real item providers; three of its tests failed against the card's old logic: a file before the link, a link as words or bytes, and a provider made from a URL answering with bytes on the Mac; also a link as plain words behind a picture or a text, and behind an email address; a link as marked-up text behind a picture, a text or an email address, also driven through the real card source on the Mac); what apps really hand over on the phone not yet seen, the `inbox` added line's share_types will show it
- **Issues:** [#673](https://github.com/idvorkin/context-grabber/issues/673)
- **Spec:** [Chat with Larry in Grabber Native — The shared link on the message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing from an app that hands links over its own way
- **I want to** get the link all the same
- **so that** the card never says it can't read a share that had a link in it

#### Acceptance Criteria:
- **Scenario:** A file attachment ahead of the link
- **Given:** an app shares a file first and a web link after it
- **When:** the card opens
- **Then:** the card previews the web link, the message carries it, and the `inbox` added line's share_types names what the app offered

- **Scenario:** A link as words, behind something else
- **Given:** an app shares a picture or a line of text first, and after it a web link as plain words or as marked-up text whose words are the link
- **When:** the card opens
- **Then:** the card previews the web link and the message carries it

- **Scenario:** An address that is not a web link
- **Given:** an app shares an email address first and a web link after it
- **When:** the card opens
- **Then:** the card previews the web link and the message carries it; shared with no web link, the email address is the link as before

---

### User Story 546:

- **Summary:** Speaking a message on the share card
- **Status:** changed 2026-11-22 (#1135): the card's own mic button is gone, since iOS refused the share extension the microphone on every tap (the iPad, 2026-11-11 and twice on 2026-11-22, both permissions allowed), and the keyboard's dictation key speaks the message, in [a56ca99e](https://github.com/idvorkin/context-grabber/commit/a56ca99e); verified by the host rung (`just native-test`: format and lint, the card is not compiled there) and the simulator rung's Xcode build of the share extension; speaking with the keyboard's key on the phone not yet. Before: native app only: a mic button on the card's *Message* field, the problem report's dictation, implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet: Apple's guidance is that an app extension cannot use the microphone (an iMessage app excepted), so the first tap on the phone settles whether it can. Stopping, sending, cancelling and a refusal are stories 555–558
- **Issues:** [#673](https://github.com/idvorkin/context-grabber/issues/673), [#793](https://github.com/idvorkin/context-grabber/issues/793), [#1135](https://github.com/idvorkin/context-grabber/issues/1135) (the card's mic: *Voice input could not start*, avfaudio error 2003329396, on every tap)
- **Spec:** [Chat with Larry in Grabber Native — Speaking on the card](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing a page with my hands full
- **I want to** say my message on the card instead of typing it
- **so that** what I think about the page goes with it without typing

#### Acceptance Criteria:
- **Scenario:** Saying the message
- **Given:** the share card is open on a page from Safari
- **When:** I tap the keyboard's dictation key in the *Message* field and speak
- **Then:** my words appear in the *Message* field after anything I typed, and nothing is sent until I tap *Start a chat* or *Send*; the field has no mic button of its own, and the card never asks for the microphone or speech recognition

---

### User Story 547:

- **Summary:** The last chat scrolls clear of the floating buttons
- **Status:** native app only: implemented in [dd5d9ef8](https://github.com/idvorkin/context-grabber/commit/dd5d9ef8); `ChatArchiveUITests` scrolls a row clear of the buttons before tapping and swiping it (simulator: chat suite 34 passed; one swipe test failed on the suite's slow first launch, then passed 3 of 3 alone); the very last row of a list longer than the screen not measured, and on the phone not yet
- **Issues:** [#685](https://github.com/idvorkin/context-grabber/issues/685)
- **Spec:** [Chat with Larry in Grabber Native — The list](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client tidying my chats
- **I want** the end of the list to scroll up clear of the buttons
- **so that** no row is stuck beneath them

#### Acceptance Criteria:
- **Scenario:** The last row
- **Given:** Chat lists more rows than fit
- **When:** I scroll to the end of the list
- **Then:** the last row sits clear above the buttons, where I can tap it and swipe it from anywhere along it

---

### User Story 548:

- **Summary:** Paste a copied photo into a Mac chat with Command+V
- **Status:** native app only: implemented in [3fdb7c3](https://github.com/idvorkin/context-grabber/commit/3fdb7c3); the Mac build compiles and `just test` passes (host). Not yet verified on a Mac by pressing the key (the unsigned test runner refuses Mac UI tests; Igor checks by hand). A phone and an iPad are unchanged
- **Issues:** [#730](https://github.com/idvorkin/context-grabber/issues/730)
- **Spec:** [Chat with Larry in Grabber Native — Pasting a picture on a Mac](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, writing to Larry on the Mac
- **I want to** paste a photo I copied in another app straight into the chat bar
- **so that** I can show Larry a picture without saving it to a file and picking it

#### Acceptance Criteria:
- **Scenario:** A photo copied elsewhere
- **Given:** the Mac build, a thread open, and a photo copied in Photos, Preview or a browser
- **When:** I come back to the window, click in the bar and press Command+V (or choose Edit > Paste)
- **Then:** the photo sits above the field with its preview and *Remove image*, the words I typed stay, and *Paste image* is live; words on the clipboard still paste as words

---

### User Story 549:

- **Summary:** A thread's links wait as chips under its title
- **Status:** native app only: implemented in [771196ab](https://github.com/idvorkin/context-grabber/commit/771196ab); `ChatLinksTests` (host, real PR, gist and blog links) pass and the Mac build compiles; not yet seen on the simulator or the phone
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, back in a chat where Larry opened a PR an hour ago
- **I want to** see that thread's PRs, gists and blog links as chips at the top
- **so that** I open the one I want in one tap instead of scrolling back for it

#### Acceptance Criteria:
- **Scenario:** A thread with a PR, a gist and a blog post
- **Given:** a thread whose messages hold https://github.com/idvorkin/context-grabber/pull/734 (twice, once to its files), a gist and https://idvork.in/ai-journal.
- **When:** I open the thread
- **Then:** under its title I see *PR #734*, *gist* and *idvork.in/ai-journal*, newest first, each once, without the full stop after the link; tapping one opens it, and the links in the bubbles stay tappable

---

### User Story 550:

- **Summary:** Fold a thread's links away, and it stays folded
- **Status:** native app only: implemented in [771196ab](https://github.com/idvorkin/context-grabber/commit/771196ab); `ChatLinksTests` (host, real PR, gist and blog links) pass and the Mac build compiles; not yet seen on the simulator or the phone
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, in a long-running thread whose links I no longer need
- **I want to** fold its chips away
- **so that** the thread has its room back, and only that thread loses its chips

#### Acceptance Criteria:
- **Scenario:** Folding, leaving and coming back
- **Given:** an open thread with its links showing
- **When:** I tap *Links*, leave the thread, quit the app and open the thread again
- **Then:** it shows *Links (N)* alone, folded, and another thread's chips still show; tapping *Links (N)* unfolds them

---

### User Story 551:

- **Summary:** Past ten links, *All links* lists the rest
- **Status:** native app only: implemented in [771196ab](https://github.com/idvorkin/context-grabber/commit/771196ab); `ChatLinksTests` (host, real PR, gist and blog links) pass and the Mac build compiles; not yet seen on the simulator or the phone
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, in a thread with a day's worth of PRs
- **I want** the strip to stay short and still reach every link
- **so that** the chips don't become a wall and nothing is lost

#### Acceptance Criteria:
- **Scenario:** Thirteen links
- **Given:** a thread whose messages hold thirteen different links
- **When:** I tap *All links (13)* at the end of the strip
- **Then:** a list shows all thirteen, newest first, each with its chip's words and the link in full, and a tap opens one

---

### User Story 552:

- **Summary:** A thread without links has no strip
- **Status:** native app only: implemented in [771196ab](https://github.com/idvorkin/context-grabber/commit/771196ab); `ChatLinksTests` (host, real PR, gist and blog links) pass and the Mac build compiles; not yet seen on the simulator or the phone
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, chatting about the day with no links in it
- **I want** the thread to look as it always has
- **so that** the strip is there only when it has something to offer

#### Acceptance Criteria:
- **Scenario:** Words only, then a link
- **Given:** a thread whose messages mention *AGENTS.md* and *idvork.in/foo* but no link written with https://
- **When:** I open it, and Larry then replies with https://idvork.in/eulogy
- **Then:** at first there is no strip, and with Larry's reply the strip appears with *idvork.in/eulogy* alone

---

### User Story 553:

- **Summary:** On the Mac and a full-width iPad, the thread list shows each thread's newest links
- **Status:** native app only: implemented in [771196ab](https://github.com/idvorkin/context-grabber/commit/771196ab), a row's read cut short by scrolling tried again in [69f16f74](https://github.com/idvorkin/context-grabber/commit/69f16f74); `ChatLinksTests` (host, real PR, gist and blog links) pass and the Mac build compiles; not yet seen on the simulator or the phone. Whether a chip in a row takes its own tap, rather than opening the thread, is for the simulator (an iPad) or the Mac by hand
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — Links in the thread list on an iPad or a Mac](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor at the Mac with several chats going
- **I want** each row of the list to show its thread's newest links
- **so that** I can open the PR from a chat without opening the chat

#### Acceptance Criteria:
- **Scenario:** The list on the Mac
- **Given:** the Mac build, and live threads, one with four links and one with none
- **When:** I open Chat
- **Then:** the first row shows its three newest link chips under its last line, a chip opens its link and the rest of the row opens the thread; the other row looks as it does today, and on an iPhone no row shows chips

---

### User Story 554:

- **Summary:** A PR chip says whether the pull request is merged
- **Status:** native app only: implemented in [f406191c](https://github.com/idvorkin/context-grabber/commit/f406191c), from the Cockpit's PR states; `ChatPRStatesTests` (host, the answer as Larry's contract gives it) pass and the Mac build compiles; not yet seen on the simulator or the phone
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — A pull request's state](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, looking over a thread's PRs
- **I want** each PR chip to say open, draft, merged or closed
- **so that** I know which ones still need me without opening them

#### Acceptance Criteria:
- **Scenario:** One merged, one open
- **Given:** a thread with PR #734 (merged) and PR #736 (open), and a Cockpit that reports their state
- **When:** I open the thread
- **Then:** *PR #734* reads merged in purple and *PR #736* reads open in green (a draft reads draft in grey, a closed one closed in red); a PR whose state the Cockpit does not know yet reads as today

- **Scenario:** The Cockpit can't be reached
- **Given:** a thread with PR chips, offline or with the Cockpit down
- **When:** I open the thread
- **Then:** the chips show their numbers alone (or the words they last had) and no problem is shown; the session log has one `pr_states_failed` with the reason

---

### User Story 555:

- **Summary:** Stopping the share card's dictation
- **Status:** removed 2026-11-22 with the card's mic button (#1135: iOS refused the share extension the microphone on every tap, so it never listened), in [a56ca99e](https://github.com/idvorkin/context-grabber/commit/a56ca99e); the keyboard's dictation key speaks the message (story 546). Before: native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793), [#1135](https://github.com/idvorkin/context-grabber/issues/1135)
- **Spec:** [Chat with Larry in Grabber Native — Speaking on the card](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client speaking a message on the share card
- **I want** a tap on the stop button to end the recording
- **so that** I can read and fix the message before it goes

#### Acceptance Criteria:
- **Scenario:** Stopping
- **Given:** the card is listening
- **When:** I tap the stop button
- **Then:** the last words settle in the field, the mic button comes back, and the field takes typing again

---

### User Story 556:

- **Summary:** Sending from the share card while it listens
- **Status:** removed 2026-11-22 with the card's mic button (#1135: iOS refused the share extension the microphone on every tap, so it never listened), in [a56ca99e](https://github.com/idvorkin/context-grabber/commit/a56ca99e); the keyboard's dictation key speaks the message (story 546). Before: native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793), [#1135](https://github.com/idvorkin/context-grabber/issues/1135)
- **Spec:** [Chat with Larry in Grabber Native — Speaking on the card](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client speaking a message on the share card
- **I want** *Start a chat* or *Send* to work while the card is still listening
- **so that** I do not have to stop the recording first

#### Acceptance Criteria:
- **Scenario:** Sending while it listens
- **Given:** the card is listening and some words are in the field
- **When:** I tap *Start a chat* or *Send*
- **Then:** the share goes with the words heard so far, the recording stops, and the card closes

---

### User Story 557:

- **Summary:** Closing the share card while it listens
- **Status:** removed 2026-11-22 with the card's mic button (#1135: iOS refused the share extension the microphone on every tap, so it never listened), in [a56ca99e](https://github.com/idvorkin/context-grabber/commit/a56ca99e); the keyboard's dictation key speaks the message (story 546). Before: native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793), [#1135](https://github.com/idvorkin/context-grabber/issues/1135)
- **Spec:** [Chat with Larry in Grabber Native — Speaking on the card](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client speaking a message on the share card
- **I want** *Cancel*, or a swipe down, to stop the recording
- **so that** nothing keeps listening after the card has gone

#### Acceptance Criteria:
- **Scenario:** Cancelling while it listens
- **Given:** the card is listening
- **When:** I tap *Cancel* or swipe the card away
- **Then:** the recording stops, the card closes and nothing is kept

---

### User Story 558:

- **Summary:** The share card says why it cannot listen
- **Status:** removed 2026-11-22 with the card's mic button (#1135: iOS refused the share extension the microphone on every tap, so it never listened), in [a56ca99e](https://github.com/idvorkin/context-grabber/commit/a56ca99e); the keyboard's dictation key speaks the message (story 546). Before: native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793), [#1135](https://github.com/idvorkin/context-grabber/issues/1135)
- **Spec:** [Chat with Larry in Grabber Native — Speaking on the card](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client speaking a message on the share card
- **I want** a copyable line when the card cannot listen
- **so that** one paste shows what stopped it, and I can still type the message

#### Acceptance Criteria:
- **Scenario:** The phone will not let the card listen
- **Given:** a permission is off, or iOS refuses the card the microphone
- **When:** I tap the mic button
- **Then:** a line under the field says what stopped it, with a *Copy error* button whose copy names where it stopped, the build and both permissions' state, and I can still type the message and send it

---

### User Story 559:

- **Summary:** The share card recommends the chat this link started
- **Status:** native app only: implemented in [4de55fa](https://github.com/idvorkin/context-grabber/commit/4de55fa); verified by `ShareSameLinkTests` (host: a link sent as a new chat is remembered with the chat it started, that chat is recommended for the same link and listed first within the five, even from past the fifth place, and the `offered` log field names it); the card is not compiled on the host, and simctl cannot drive a share sheet, so the row on the card is not yet seen on the simulator or the phone
- **Issues:** [#794](https://github.com/idvorkin/context-grabber/issues/794)
- **Spec:** [Chat with Larry in Grabber Native — The chat this link already started](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing a page again with a second thought
- **I want to** have the chat my first share of that link started recommended on the card
- **so that** the follow-up lands where Larry already has the page instead of in a twin chat

#### Acceptance Criteria:
- **Scenario:** Sharing the same link again an hour later
- **Given:** an hour ago I shared a Safari link as a new chat, the app sent it, and that chat is still live
- **When:** I share the same link to *Grabber Native* again
- **Then:** that chat is the first row under *New chat*, above the always-on chat, with *Same link* under its title, *New chat* is still ticked, and one tap on the row then *Send* puts the share in that chat

---

### User Story 728:

- **Summary:** A PR chip flips to its new state while I'm looking, in the thread and the wide list
- **Status:** native app only: implemented in [f406191c](https://github.com/idvorkin/context-grabber/commit/f406191c), the Cockpit asked again every half minute while chips are on screen (sooner while a PR is still being looked up); `ChatPRStatesTests` (host) pass and the Mac build compiles; the flip itself is not yet seen on the simulator, the Mac or the phone
- **Issues:** [#736](https://github.com/idvorkin/context-grabber/issues/736)
- **Spec:** [Chat with Larry in Grabber Native — A pull request's state](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, with a chat open while Larry's PR goes through on the laptop
- **I want** its chip to change from open to merged by itself, and the Mac's thread list to show each row's PR states too
- **so that** I know it landed without opening GitHub, leaving the thread or pulling to refresh

#### Acceptance Criteria:
- **Scenario:** Merged while the thread is open
- **Given:** an open thread whose *PR #736* chip reads open
- **When:** the pull request is merged on GitHub and I stay on the thread
- **Then:** within about half a minute the chip reads merged in purple, with nothing tapped

- **Scenario:** The wide list
- **Given:** the Mac build, the thread list showing a row with *PR #734* and *PR #736* chips
- **When:** I look at the list
- **Then:** each PR chip carries its state's word and colour as in the thread, and changes there too while the list is on screen; an iPhone's list is unchanged

- **Scenario:** A PR named for the first time
- **Given:** Larry has just written a link to a PR the Cockpit was not tracking
- **When:** the chip appears
- **Then:** it shows its number alone, then its state within seconds

---

### User Story 729:

- **Summary:** Bigger and smaller chat text on the Mac
- **Status:** implemented in [97914da4](https://github.com/idvorkin/context-grabber/commit/97914da4); `ChatTextSizeTests` (host) pass and the Mac build compiles; not yet pressed on the Mac
- **Issues:** [#781](https://github.com/idvorkin/context-grabber/issues/781)
- **Spec:** [Chat with Larry in Grabber Native — Bigger and smaller text on a Mac](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, reading Larry's replies in the Mac's chat window from across the desk
- **I want** Command+= and Command+Minus to make chat's text bigger and smaller, and Command+0 to put it back
- **so that** a long reply is comfortable to read at whatever distance I'm sitting, and stays that way next time

#### Acceptance Criteria:
- **Scenario:** Bigger, then remembered
- **Given:** the Mac build with a chat thread open
- **When:** I press Command+= twice, quit and reopen the app, and open the thread again
- **Then:** its messages, the bar and the thread list are two sizes bigger, the rest of the app is unchanged, and View >
  Actual Size (Command+0) puts chat back to the system's size; at the largest size Bigger Text is dimmed

---

### User Story 740:

- **Summary:** The same page is recognised however the other app dressed its address
- **Status:** native app only: implemented in [4de55fa](https://github.com/idvorkin/context-grabber/commit/4de55fa); verified by `ShareSameLinkTests` (host: `http` and `https`, capitals in the site, `www.`, a trailing slash, a `#` part, the order after the `?` and tracking tags all give one page; another path, port, site, `?v=` or `#/` route gives another, and `si` is a tag only on YouTube and Spotify); not yet seen on the simulator or the phone
- **Issues:** [#794](https://github.com/idvorkin/context-grabber/issues/794)
- **Spec:** [Chat with Larry in Grabber Native — The chat this link already started](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing a page from an app that tags its links
- **I want to** have the card recognise the page I already shared whatever was added to its address
- **so that** a tracking tag or a trailing slash does not hide the chat it belongs to

#### Acceptance Criteria:
- **Scenario:** The second share carries tracking tags
- **Given:** a live chat I started an hour ago from `https://idvork.in/eulogy`
- **When:** I share `http://www.idvork.in/eulogy/?utm_source=share#roles`
- **Then:** the card recommends that chat, where sharing `https://idvork.in/eulogy/roles` would recommend none

---

### User Story 741:

- **Summary:** A link's chat is recommended for eight hours, and only while it is live
- **Status:** native app only: implemented in [4de55fa](https://github.com/idvorkin/context-grabber/commit/4de55fa); verified by `ShareSameLinkTests` (host: a chat started eight hours ago is recommended and one a little older is not; a Done or gone chat is not; the phone's note of a start is not read past eight hours and is dropped the next time the app comes to the front; text, a picture and an unread list recommend nothing); not yet seen on the simulator or the phone
- **Issues:** [#794](https://github.com/idvorkin/context-grabber/issues/794)
- **Spec:** [Chat with Larry in Grabber Native — The chat this link already started](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing a link I shared yesterday
- **I want to** be offered a fresh chat once the old one has gone cold or been closed
- **so that** a new look at a page is not steered into yesterday's conversation

#### Acceptance Criteria:
- **Scenario:** The chat is older than eight hours
- **Given:** a chat I started from a link nine hours ago, still live
- **When:** I share the same link again
- **Then:** the card shows *New chat* and my recent chats as usual, no row is marked *Same link*, and no line says why

---

### User Story 742:

- **Summary:** Of several chats one link started, the newest live one is recommended
- **Status:** native app only: implemented in [4de55fa](https://github.com/idvorkin/context-grabber/commit/4de55fa); verified by `ShareSameLinkTests` (host: of three chats from one link the most recently started live one is chosen, a newer Done one passed over); not yet seen on the simulator or the phone
- **Issues:** [#794](https://github.com/idvorkin/context-grabber/issues/794)
- **Spec:** [Chat with Larry in Grabber Native — The chat this link already started](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client who started more than one chat from the same link today
- **I want to** have only the latest of them recommended
- **so that** the card points at the conversation I am most likely still in

#### Acceptance Criteria:
- **Scenario:** Two chats from one link
- **Given:** I started a chat from a link five hours ago and another from the same link two hours ago, both live
- **When:** I share that link again
- **Then:** the chat from two hours ago is the first row and the only one marked *Same link*

---

### User Story 743:

- **Summary:** A message's links are chips in its bubble: a PR reads *PR*, the blog *Preview*
- **Status:** native app only: implemented on branch `chat-short-link-labels` (first as short underlined words, then as chips after Igor's review); `ChatBubbleLinksTests` (host) written but not run (no Swift toolchain on the Linux box that built it, no Mac); not yet seen on the simulator or the phone
- **Spec:** [Chat with Larry in Grabber Native — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, reading Larry's reply that links the PR he opened and a blog preview
- **I want to** see a *PR* chip and a *Preview* chip where the long addresses were, like the chips above the thread
- **so that** the message reads as words, and the links are still one tap away

#### Acceptance Criteria:
- **Scenario:** One PR and one preview, then two PRs
- **Given:** a message "Opened https://github.com/idvorkin/context-grabber/pull/734, preview at http://c-5004.squeaker-teeth.ts.net:8445/ai-journal." and another linking PRs #734 and #736
- **When:** I open the thread
- **Then:** the first bubble reads "Opened [PR], preview at [Preview]." with the two as chips, the comma and full stop beside them, each opening its full address; the second has two *PR* chips, each with its state once known; the chips under the title are unchanged, and *Copy* on either bubble copies the full addresses

---

### User Story 744:

- **Summary:** An Inbox chip in Larry's reply, and on the strip above, opens that thread in the app
- **Status:** native app only: implemented on branch `chat-cockpit-thread-links`; `ChatCockpitLinkTests`, `ChatBubbleLinksTests` and `AppLinkTests` (host) written but not run (no Swift toolchain on the Linux box that built it, no Mac); the `larry` URL scheme is registered but not opened on a device; not yet seen on the simulator or the phone
- **Spec:** [Chat with Larry in Grabber Native — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, reading Larry's reply that says a decision is waiting in the Inbox
- **I want to** tap its *Inbox* chip, there or on the strip above the thread, and land on that question's thread in the app
- **so that** I answer it without Safari, the web Cockpit or the long tailnet address

#### Acceptance Criteria:
- **Scenario:** Both spellings, a known thread, then an unknown one
- **Given:** Larry's reply "It's in the Inbox: https://c-5004.squeaker-teeth.ts.net/#thread/igor2-88g.1411.2, same as larry://inbox/igor2-88g.1411.2", a thread the chat list shows
- **When:** I open the thread and tap either *Inbox* chip in the bubble, or the one *Inbox* chip on the strip
- **Then:** the bubble shows two *Inbox* chips and no address, the strip one; that thread opens in the app over this one and Back returns here; a thread the list does not show opens on the Cockpit page; *All links* lists it as larry://inbox/igor2-88g.1411.2; and larry://inbox/igor2-88g.1411.2 tapped in Notes opens the app on that thread

---

### User Story 1127:

- **Summary:** A link in the board's conversation is a chip a finger opens, and Lavish reads *Larry: Lavish*
- **Status:** native app only: implemented in [01698b61](https://github.com/idvorkin/context-grabber/commit/01698b61), with an Inbox chip opening its thread in the app and a selection in the panel kept across a redraw in [c1d2de98](https://github.com/idvorkin/context-grabber/commit/c1d2de98); `ChatBubbleLinksTests` and `WhiteboardNoteTests` (host) pass, the Mac build compiles, and on the simulator (iPad Pro 11-inch (M5), 2026-11-22) `WhiteboardLinkChipUITests` shows the *Larry: Lavish* chip in the open conversation with no tailnet address and a tap on it opens the page; not yet seen on the iPad by Igor, and the Pencil doing nothing on a chip is the iPad's check
- **Issues:** [#1138](https://github.com/idvorkin/context-grabber/issues/1138)
- **Spec:** [Whiteboard conversation — Links are chips](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), [Chat with Larry in Grabber Native — Lavish is Larry's](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, at the whiteboard on the iPad with the conversation open
- **I want to** tap the link Larry wrote in his reply, shown as a short chip
- **so that** I open the page he made without leaving for Chat or copying a long tailnet address

#### Acceptance Criteria:
- **Scenario:** Larry's reply with a Lavish page and a PR, on the board
- **Given:** an open board conversation whose newest reply is "All three trees are there, plus AI multiplier: https://c-5004.squeaker-teeth.ts.net:8444/session/7d7f837c3898ed37 and https://github.com/idvorkin/context-grabber/pull/734."
- **When:** I read it and tap a chip with a finger
- **Then:** the reply reads "… plus AI multiplier: [Larry: Lavish] and [PR]." with no address showing, and the closed line above reads "Larry: … plus AI multiplier: Larry: Lavish and PR."; the tapped chip opens its page; a Pencil touch on a chip does nothing; copying the reply copies both full addresses; and in Chat the same message shows the same two chips, the Lavish one reading *Larry: Lavish* (not *Preview*) on the strip too, while a blog preview on port 8445 still reads *Preview*

---

### User Story 1133:

- **Summary:** An install link from the Cockpit is an *Install* chip that offers the build
- **Status:** native app only: implemented on branch `native/install-chip-xwns`; `ChatLinksTests` (host: the Cockpit's link, an encoded manifest, another host, an `http` manifest, no or another `action`, and that no install link is tappable in a message's words) pass and the Mac build compiles; not yet seen on the simulator (no simulator run while the whiteboard work holds the iPhone simulators) or the phone, where iOS's install prompt is the check
- **Issues:** bead context-grabber-xwns
- **Spec:** [Chat with Larry in Grabber Native — An install link is an Install chip](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, reading Larry's message that a new build is ready to install over the air
- **I want to** tap an *Install* chip where the long `itms-services` link was
- **so that** iOS offers the build without my copying the link into Safari

#### Acceptance Criteria:
- **Scenario:** The Cockpit's install link, then ones from elsewhere
- **Given:** Larry's message "Build 412 is up: itms-services://?action=download-manifest&url=https://c-5004.squeaker-teeth.ts.net/builds/412/manifest.plist" and another holding the same link with an `http://` manifest, one with a manifest on another host, and one with no `action`
- **When:** I open the thread and tap the chip
- **Then:** the first bubble reads "Build 412 is up: [Install]", the strip has one *Install* chip, *All links* spells it with *Larry* and no tailnet address, and the tap hands the link to iOS, which asks to install the build; the other three links read as plain words with nothing to tap and no chip on the strip

---

### User Story 747:

- **Summary:** A table in Larry's message reads as a table
- **Status:** native app: implemented in [fdb12f0](https://github.com/idvorkin/context-grabber/commit/fdb12f0), [56a557c](https://github.com/idvorkin/context-grabber/commit/56a557c) (VoiceOver reads it row by row) and [161e3ef](https://github.com/idvorkin/context-grabber/commit/161e3ef) (a table with only a heading still speaks), issue [#817](https://github.com/idvorkin/context-grabber/issues/817); verified by `ChatTablesTests` (host, 10 cases), the Mac build, and on the simulator (iPhone 17, 2026-11-10: ChatTableUITests, since gone, reads the grid row by row in the bubble's label, the screenshot shows the bold heading, row lines and right-aligned Battery; the other 16 chat UI tests pass with the new fake thread); on the phone since f668bc4 (2026-11-10), not yet seen there by Igor; since story 770 what VoiceOver reads is `ChatTablesTests.testTheTableReadsRowByRow` on the host (seen to fail with the headings dropped), and ChatTableUITests is gone: the table's label being part of the bubble's one label and the screenshot of the grid are no longer taken by a test
- **Spec:** [Chat with Larry in Grabber Native — A table in a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, reading Larry's comparison of three laptops on the phone
- **I want to** see his Markdown table as a grid of rows and columns
- **so that** I can compare the options at a glance instead of decoding pipes and dashes

#### Acceptance Criteria:
- **Scenario:** A three-row, four-column comparison
- **Given:** Larry's message "Here's how they compare:", then a table with the heading `| | Weight | Battery | Price |`, its dashes row, and three rows, then "Want the cheapest?"
- **When:** I open the thread on the iPhone
- **Then:** the bubble reads the first line, then a grid with the heading in bold and one row per laptop, then the last line; the grid scrolls sideways inside the bubble if it is wider than it, and *Copy* copies the message with its pipes

---

### User Story 749:

- **Summary:** Two quick Returns at the end of a message send it, the blank lines taken off
- **Status:** native app only: implemented in [e4f9de0d](https://github.com/idvorkin/context-grabber/commit/e4f9de0d) (PR [#885](https://github.com/idvorkin/context-grabber/pull/885), bead context-grabber-94m); a deletion never counting as a Return in [9b744756](https://github.com/idvorkin/context-grabber/commit/9b744756); verified on the Mac 2026-11-14: `just native-test` (SwiftLint, swift-format, `ChatDoubleEnterTests` 14 cases among 1,484 host tests) and the Mac build (`just native-build-mac`); one simulator ladder passed with it in (the seven chat UI classes and the chat smoke), none of which presses a Return, so the send itself is not yet seen on the simulator or the phone: the on-screen keyboard's, a hardware keyboard's and Wispr Flow's Returns are not yet seen sending; `GRABBER_CHAT_ENTER` drives it on the simulator, not yet run
- **Spec:** [Chat with Larry in Grabber Native — Two quick Returns send](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, dictating into a chat thread by voice with the phone out of reach
- **I want to** end what I said with two quick Returns and have it sent
- **so that** I send hands-free, without a blank line at the end of the message, and still get a blank line when I pause between Returns

#### Acceptance Criteria:
- **Scenario:** Dictated, then two quick Returns
- **Given:** an open thread whose bar reads "see you at noon"
- **When:** I press Return twice within 400 milliseconds, on the keyboard or by the dictation tool's two new lines at once
- **Then:** "see you at noon" is sent as Send would send it, with nothing after "noon", and the bar is empty; two Returns further apart leave a blank line and send nothing, two quick Returns between two lines or in an empty bar send nothing, deleting the last paragraph so a blank line ends the bar sends nothing, and *Quote in reply* still sends nothing

---

### User Story 748:

- **Summary:** A pasted blog-review batch reads as one card of chips
- **Status:** native app: implemented in [e305103e](https://github.com/idvorkin/context-grabber/commit/e305103e), PR [#886](https://github.com/idvorkin/context-grabber/pull/886) (bead context-grabber-d23), numbered 765 there and renumbered 748 in [64c6708b](https://github.com/idvorkin/context-grabber/commit/64c6708b) (765 is the whiteboard's); verified on the Mac 2026-11-14: `just native-test` (`ChatReviewBatchTests` 7 cases among 1,484 host tests) and the Mac build (`just native-build-mac`); one simulator ladder passed with it in (the seven chat UI classes and the chat smoke), none of which shows a batch, so the card itself is not yet seen on the simulator or the phone; `GRABBER_CHAT_REVIEW` opens a note on the simulator, not yet run
- **Spec:** [Chat with Larry in Grabber Native — A blog-review batch in a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, pasting the notes the blog's annotate tool exported for a post into a chat
- **I want to** see them as the page's title and one chip per note that I can open
- **so that** I can read what I flagged at a glance instead of a wall of JSON

#### Acceptance Criteria:
- **Scenario:** A batch of two notes
- **Given:** a message that is exactly the annotate tool's export for "An example post", with a *fix* note "Say it once." and a *question* note "Does this belong here?"
- **When:** I open the thread on the iPhone
- **Then:** the bubble shows a chip "An example post" that opens the post, beside "2 notes"; then the chips "fix · Say it once." and "question · Does this belong here?"; tapping the first shows the quoted passage with the words around it dimmed and the whole comment, and tapping it again folds it; *Copy* copies the message as pasted; a note with the quote "passion or addiction:" and an empty comment reads "note · “passion or addiction:”"; and the same JSON after the words "Here are my notes:", inside a code fence, broken, or other JSON reads exactly as written, with no card

---

### User Story 820:

- **Summary:** Send one of my messages to a new chat
- **Status:** native app: implemented in [248fb1ce](https://github.com/idvorkin/context-grabber/commit/248fb1ce) and [5f97b1cd](https://github.com/idvorkin/context-grabber/commit/5f97b1cd), PR [#890](https://github.com/idvorkin/context-grabber/pull/890) (bead context-grabber-9yo), the moved row read as the Cockpit ships it in [e7dcb40](https://github.com/idvorkin/context-grabber/commit/e7dcb40); verified on the host (`just native-test`: `ChatMoveTests`, `ChatReactionTests.testOnlyMyMessagesSendToANewChatAndTheMovedLineHasNoMenu` and the rest of `ChatReactionTests`) and the Mac build (`just native-build-mac`). The Cockpit's `POST /chat/move` is on its main (cockpit-x3s, 5af4fc8); the app has not yet been tried against it. `GRABBER_CHAT_HOLD=new-chat` taps it on the simulator against the fake Cockpit, which now moves messages (docs/TESTING.md). Seen on the iPad simulator (rung 2, iPad Pro 11-inch (M5)) by `ChatMoveUITests` in [b7b3b978](https://github.com/idvorkin/context-grabber/commit/b7b3b978) (bead context-grabber-9yo, 2026-11-22): not offered on Larry's message, mine moved to a new chat that opens and Larry answers, the old chat keeping Larry's reply and a *Moved to a new chat* line that opens the new one, against the fake Cockpit; the iPhone simulator not run (Igor's standing no-iPhone rule during the whiteboard work), and the real Cockpit's move and a device not yet
- **Spec:** [Chat with Larry in Grabber Native — Press and hold a message](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor, who started something new in the middle of an unrelated chat
- **I want to** send that message to a chat of its own and carry on there
- **so that** each chat stays about one thing and Larry answers the new topic in its own place

#### Acceptance Criteria:
- **Scenario:** Moving my message out
- **Given:** an open chat holding one of my messages that the Cockpit already has
- **When:** I hold it (or right-click it on the Mac) and tap *Send to new chat*
- **Then:** a new chat titled by the message's first line opens, holding that message with its pictures, and Larry answers there; going back, the old chat shows *Moved to a new chat* where the message was, which opens the new chat when tapped; Larry's messages and messages still on their way offer no such choice; the moved line arriving doesn't by itself mark the old chat read; a Cockpit that refuses or can't move it leaves the message where it was, with a copyable problem saying why

---

### User Story 830:

- **Summary:** Answer Larry's decision from its chat
- **Status:** native app: implemented on branch `native/878-decision-cards` (6b5534a2: the answer is Igor's message in the chat the ask continues); verified on the host (`just native-test`: `ChatDecisionsTests`), the Mac build (`just native-build-mac`) and the simulator: `ChatDecisionUITests` passed three runs of three on the iPhone 17 simulator against the fake Cockpit (8f5d70ca: the thread screen's identifier had hidden the card's; 6b5534a2: the ask's `thread` and `post_to_chat`), the answer arriving as Igor's *Decided: Ramen* in the thread the ask was filed from; the real Cockpit's `post_to_chat` and the phone not yet; 41071987: a read that began before an answer is dropped, so the card can't come back, and offline a thread shows no card, verified on the host and the Mac build, the simulator not yet
- **Issues:** [#878](https://github.com/idvorkin/context-grabber/issues/878)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md)

#### Use Case:
- **As** Igor, reading a chat where Larry put a question to me
- **I want to** see the question's card at the top and answer it with one tap
- **so that** I decide where I'm already talking with Larry, without opening the Cockpit

#### Acceptance Criteria:
- **Scenario:** Tapping an option on the card in its thread
- **Given:** an open chat that an open ask continues (Larry filed it from that chat, or it is the chat's own bead), its card pinned at the top with the question, Larry's context, one button per option, the default (or else the recommended) option marked and, when it has one, its expiry
- **When:** I tap an option
- **Then:** the Cockpit records it exactly as an answer on its own card, and the card gives way to my answer as my own message in the thread, *Decided: \<label>*, there on the laptop too; when the Cockpit couldn't write that message (or is one from before it could), the card gives way to *You decided: \<label>* instead; a refused or failed answer leaves the card with its buttons live and a copyable problem; an ask answered elsewhere says *Already answered elsewhere* and leaves; one changed since it loaded says so and shows the new version; an expired ask is still answerable

---

### User Story 831:

- **Summary:** See on the list which chats have a decision waiting
- **Status:** native app: implemented on branch `native/878-decision-cards` (6b5534a2: marked by the ask's `thread`); verified on the host (`just native-test`: `ChatDecisionsTests`, which threads are marked, with the fallback for a Cockpit that sends none), the Mac build (`just native-build-mac`) and the simulator: `ChatDecisionUITests` passed three runs of three on the iPhone 17 simulator against the fake Cockpit (8f5d70ca: the thread screen's identifier had hidden the card's; 6b5534a2: the ask's `thread` and `post_to_chat`); the phone not yet; 41071987: offline the marks and the row go even after an earlier read, and a read from before an answer can't bring a mark back, verified on the host and the Mac build, the simulator not yet
- **Issues:** [#878](https://github.com/idvorkin/context-grabber/issues/878)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md)

#### Use Case:
- **As** Igor, looking down the Chat list
- **I want to** see which chats hold a decision Larry is waiting on
- **so that** I open those first instead of opening each chat to find out

#### Acceptance Criteria:
- **Scenario:** The list with an ask that continues one chat
- **Given:** a chat that an open ask continues, and others that none does
- **When:** the Chat list opens or I pull it
- **Then:** only that chat's row says *Decision waiting*; once the ask is answered, snoozed, closed or abandoned the mark goes, at once when I did it on this phone and on the next read of the list when it was done elsewhere; offline, no row is marked; a read that fails leaves the marks as they were and says nothing on the list, which is otherwise unchanged

---

### User Story 832:

- **Summary:** Open every waiting decision from one row
- **Status:** native app: implemented on branch `native/878-decision-cards` (6b5534a2: *Open chat* by the ask's `thread`); verified on the host (`just native-test`: `ChatDecisionsTests`, the order and the count), the Mac build (`just native-build-mac`) and the simulator: `ChatDecisionUITests` passed three runs of three on the iPhone 17 simulator against the fake Cockpit (8f5d70ca: the thread screen's identifier had hidden the card's; 6b5534a2: the ask's `thread` and `post_to_chat`); *Open chat* itself is not driven by a UI test; the phone not yet; 41071987: offline *Decisions* lists no asks, verified on the host and the Mac build, the simulator not yet; #1072: a card answered, closed or abandoned on *Decisions* gave way at once only in the model, its finished row taking over the card's view, in [5e547564](https://github.com/idvorkin/context-grabber/commit/5e547564); verified by `ChatDecisionUITests.testTheLastDecisionFinishedOnDecisionsLeavesItsLine` on the iPhone 17 simulator (red before, green after, the class green), the host and the Mac build; the Mac app itself not yet
- **Issues:** [#878](https://github.com/idvorkin/context-grabber/issues/878), [#1072](https://github.com/idvorkin/context-grabber/issues/1072)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md)

#### Use Case:
- **As** Igor, with a few minutes to clear what Larry is waiting on
- **I want to** open all the open decisions at once as cards
- **so that** I can answer them one after another, including the ones that have no chat

#### Acceptance Criteria:
- **Scenario:** Opening *Decisions*
- **Given:** open asks on the Cockpit, some continuing a chat and some on no chat
- **When:** I tap *Decisions (N)*, the row under Larry's pinned thread
- **Then:** every open ask shows as a card, soonest to expire first and those with no expiry after, each answerable as in its chat and each with *Open chat*, which opens the chat the ask continues (or else its own, empty) to talk it over; an answer given here leaves the line *You decided: \<label>*; an answered card leaves the list and the count drops; a card answered, closed or abandoned there gives way to its line at once, the last one too, never staying on screen answered and still tappable (#1072); with no open ask there is no row; a list that can't be read shows a copyable problem

---

### User Story 833:

- **Summary:** Snooze, close or abandon a decision from its card
- **Status:** native app: implemented on branch `native/878-decision-cards` (6b5534a2: a close or an abandon writes Igor's message into the ask's chat); verified on the host (`just native-test`: `ChatDecisionsTests`, the requests, `post_to_chat` and what each answer means) and the Mac build (`just native-build-mac`); the menu is not driven on the simulator, against the real Cockpit or on the phone; #1072: a card answered, closed or abandoned on *Decisions* gave way at once only in the model, its finished row taking over the card's view, in [5e547564](https://github.com/idvorkin/context-grabber/commit/5e547564); verified by `ChatDecisionUITests.testTheLastDecisionFinishedOnDecisionsLeavesItsLine` on the iPhone 17 simulator (red before, green after, the class green), the host and the Mac build; the Mac app itself not yet
- **Issues:** [#878](https://github.com/idvorkin/context-grabber/issues/878), [#1072](https://github.com/idvorkin/context-grabber/issues/1072)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md)

#### Use Case:
- **As** Igor, facing a decision I can't or won't make now
- **I want to** snooze it, close it with a reason, or abandon it from the card's menu
- **so that** it stops waiting on me in the right way, as on the Cockpit's own card

#### Acceptance Criteria:
- **Scenario:** The card's ⋯ menu
- **Given:** a decision card, in its chat or under *Decisions*
- **When:** I pick *Snooze* (*Later today*, *Tomorrow morning*, *Next week*), *Close…* with a one-line reason, or *Abandon* with one of the Cockpit's reasons or none
- **Then:** the Cockpit does what its own card does, leaving *Decisions* and its row's mark; in the ask's chat a close or an abandon becomes my message, *Closed: \<reason>* or *Abandoned[: \<reason>]*, and the card gives way to it; a snooze, a card on *Decisions*, or a message the Cockpit couldn't write gives way to *Snoozed until \<when>*, *Closed* or *Abandoned*; *Close* can't be sent without a reason; a refusal leaves the card with a copyable problem, and an ask already finished elsewhere says *Already answered elsewhere*

---

### User Story 1128:

- **Summary:** Answer a decision in my own words with *Other*
- **Status:** native app: implemented in [f779b0fb](https://github.com/idvorkin/context-grabber/commit/f779b0fb); verified on the host (`just native-test`: `ChatDecisionsTests`, which labels are Larry's *Other*, when the card adds its own, a tap on his opening the field and never answering, the words sent as *DECISION: \<words\>*), the Mac build (`just native-build-mac`) and the simulator (`just test-ladder --rung 2`, 2026-11-22): `ChatDecisionUITests.testOtherAnswersInIgorsOwnWords` and `testLarrysOwnOtherOpensTheFieldAndNeverSendsTheBareWord` on the iPhone 17 simulator against the fake Cockpit, the class green, and `WhiteboardQuestionUITests` on the iPad simulator (no *Other* in the popup); dictating into the field and the real Cockpit are the phone's to show
- **Issues:** bead context-grabber-sm4l (Igor, 2026-11-22, Cockpit thread igor2-88g.1620: *"When we have a decision card it always needs to have an other so I can add another option. In this case I didn't understand what finger draw was about."*); bead context-grabber-1zyc (the same request, closed as its duplicate)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md), *Other*, *Answering in his own words*

#### Use Case:
- **As** Igor, looking at a decision card whose options don't fit, or that I don't understand
- **I want to** pick *Other* and type or dictate my own answer
- **so that** Larry gets what I actually think, not the nearest option, without leaving the card for the chat

#### Acceptance Criteria:
- **Scenario:** Answering with my own words
- **Given:** a decision card, in its chat or under *Decisions*, whose options include none labelled *Other*
- **When:** I tap *Other…* under the options, type or dictate my words in the field it opens, and tap *Send*
- **Then:** the Cockpit takes *DECISION: \<my words\>* as the Inbox's free-text answer, and the card gives way to *Decided: \<my words\>* as my message in the ask's chat (or *You decided: \<my words\>* where no message could be written); *Send* is off until there are words; a refusal leaves the card, my words still in the field, with a copyable problem

---

### User Story 1129:

- **Summary:** Larry's own *Other*, *Something else* or *Type your own answer* opens the field instead of answering
- **Status:** native app: implemented in [f779b0fb](https://github.com/idvorkin/context-grabber/commit/f779b0fb); verified on the host (`just native-test`: `ChatDecisionsTests`, which labels are Larry's *Other*, when the card adds its own, a tap on his opening the field and never answering, the words sent as *DECISION: \<words\>*), the Mac build (`just native-build-mac`) and the simulator (`just test-ladder --rung 2`, 2026-11-22): `ChatDecisionUITests.testOtherAnswersInIgorsOwnWords` and `testLarrysOwnOtherOpensTheFieldAndNeverSendsTheBareWord` on the iPhone 17 simulator against the fake Cockpit, the class green, and `WhiteboardQuestionUITests` on the iPad simulator (no *Other* in the popup); dictating into the field and the real Cockpit are the phone's to show; extended in [1948b3af](https://github.com/idvorkin/context-grabber/commit/1948b3af) (bead context-grabber-sm4l reopened: keyed *other* or labelled *Something else* and the like, the board's popup drawing Larry's option and putting the cursor in *Your own answer*, the wire refusing a bare label or no words); verified on the host (`just native-test`: `ChatDecisionsTests.testAnOwnAnswerOptionIsOtherByKeyOrByWhatItSays`, `testAnEmptyOrBareOwnAnswerIsNeverSent`, `testAnEmptyOwnAnswerNeverReachesTheCockpit`), the Mac build (`just native-build-mac`) and the simulator (2026-11-22, through the build lane and the wrapper against the fake Cockpit, its ask keyed *other* labelled *Something else*): `ChatDecisionUITests` 5/5 on the iPhone 17, `WhiteboardQuestionUITests` 2/2 on the iPad Pro 11-inch (M5), `testLarrysSomethingElseTakesTheCursorToTheOwnAnswer` new
- **Issues:** bead context-grabber-sm4l (Igor, 2026-11-22, Cockpit thread igor2-88g.1620: *"When we have a decision card it always needs to have an other so I can add another option. In this case I didn't understand what finger draw was about."*); bead context-grabber-1zyc (the same request, closed as its duplicate); bead context-grabber-sm4l reopened (Igor, 2026-11-22 14:14, Cockpit thread igor2-88g.1620: he picked Larry's *Something else / Type your own answer* (key *other*), the phone sent *DECISION: Something else* with no words, and no text box opened — *"when I type my own answer I [should get] a text box"*)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md), *Other*, *Answering in his own words*

#### Use Case:
- **As** Igor, on a card where Larry already offered his own way to answer in my words
- **I want to** have his option open the field for my own words
- **so that** there is one *Other*, and Larry never gets the option's bare label, or an empty answer, as my answer

#### Acceptance Criteria:
- **Scenario:** Larry already offered *Other*
- **Given:** a card in Chat whose own options include an own-answer option: keyed *other*, or labelled *Other*, *Something else*, *Type your own answer*, *Your own answer*, *None of these* or *None of the above* (any case, any punctuation around it, alone or as half of a label like *Something else / Type your own answer*)
- **When:** I look at it and tap Larry's option
- **Then:** there is no second *Other…*; his option opens the same field instead of answering, *Send* is off until I have typed or dictated words, and the Cockpit never receives its bare label (*DECISION: Something else*) or an empty answer, only my words

---

### User Story 1130:

- **Summary:** On the board's question card, Larry's *Other* puts me in *Your own answer*
- **Status:** native app: implemented in [f779b0fb](https://github.com/idvorkin/context-grabber/commit/f779b0fb); verified on the host (`just native-test`: `ChatDecisionsTests`, which labels are Larry's *Other*, when the card adds its own, a tap on his opening the field and never answering, the words sent as *DECISION: \<words\>*), the Mac build (`just native-build-mac`) and the simulator (`just test-ladder --rung 2`, 2026-11-22): `ChatDecisionUITests.testOtherAnswersInIgorsOwnWords` and `testLarrysOwnOtherOpensTheFieldAndNeverSendsTheBareWord` on the iPhone 17 simulator against the fake Cockpit, the class green, and `WhiteboardQuestionUITests` on the iPad simulator (no *Other* in the popup); dictating into the field and the real Cockpit are the phone's to show; extended in [1948b3af](https://github.com/idvorkin/context-grabber/commit/1948b3af) (bead context-grabber-sm4l reopened: keyed *other* or labelled *Something else* and the like, the board's popup drawing Larry's option and putting the cursor in *Your own answer*, the wire refusing a bare label or no words); verified on the host (`just native-test`: `ChatDecisionsTests.testAnOwnAnswerOptionIsOtherByKeyOrByWhatItSays`, `testAnEmptyOrBareOwnAnswerIsNeverSent`, `testAnEmptyOwnAnswerNeverReachesTheCockpit`), the Mac build (`just native-build-mac`) and the simulator (2026-11-22, through the build lane and the wrapper against the fake Cockpit, its ask keyed *other* labelled *Something else*): `ChatDecisionUITests` 5/5 on the iPhone 17, `WhiteboardQuestionUITests` 2/2 on the iPad Pro 11-inch (M5), `testLarrysSomethingElseTakesTheCursorToTheOwnAnswer` new
- **Issues:** bead context-grabber-sm4l (Igor, 2026-11-22, Cockpit thread igor2-88g.1620: *"When we have a decision card it always needs to have an other so I can add another option. In this case I didn't understand what finger draw was about."*); bead context-grabber-1zyc (the same request, closed as its duplicate); bead context-grabber-sm4l reopened (Igor, 2026-11-22 14:14, Cockpit thread igor2-88g.1620: he picked Larry's *Something else / Type your own answer* (key *other*), the phone sent *DECISION: Something else* with no words, and no text box opened — *"when I type my own answer I [should get] a text box"*)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md), *Other*, *Answering in his own words*, [Question cards on the board](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md)

#### Use Case:
- **As** Igor, answering a question card on a board
- **I want to** have Larry's *Other* (or *Something else*) take me to the popup's own *Your own answer* field
- **so that** picking it lets me type or dictate my answer, and the popup never offers two fields for the same thing

#### Acceptance Criteria:
- **Scenario:** The board's question card
- **Given:** a question card's popup on a board, which already has *Your own answer* under the card (story 882), for an ask whose options include Larry's own-answer option (keyed *other*, or labelled as in story 1129)
- **When:** I tap Larry's option
- **Then:** nothing is sent; the cursor is in *Your own answer* with the keyboard up, *Send* stays off until there are words, and *Send* answers with my words; the card in the popup has no *Other…* of its own

---

### User Story 1131:

- **Summary:** Fold a decision card to one line, and open it again
- **Status:** native app: implemented in '22a78654', fixed after review in '2a4b6fca' (rebased from 'a4613ba7'), 'a022023c' and '08db3051', on branch `native/decision-fold-fjh0`; verified on the host (`just native-test`: `ChatDecisionFoldsTests`, the fold per ask, its saved list, the cap), the Mac build (`just native-build-mac`), and on the iPhone 17 simulator (`just test-ladder`: `ChatDecisionUITests.testACardFoldsToItsLineStaysFoldedAndOpensAgain` folds a card on *Decisions*, finds it folded in its thread with the row's mark and the count unchanged, still folded after a relaunch, and opens it again; nothing posted to the Cockpit); after review round 1 ('a4613ba7') the simulator was re-run: `ChatDecisionUITests` 4/4 on the iPhone 17 simulator, and the smoke's *chat: the decision card folded and reopened from its line* passed; not yet on the phone or the iPad
- **Issues:** bead context-grabber-fjh0
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md), *Folding a card*

#### Use Case:
- **As** Igor, with a decision I'm not ready to make sitting at the top of a thread or on *Decisions*
- **I want to** fold its card to one line and open it again when I'm ready
- **so that** it stops filling the screen without my answering, closing or snoozing it

#### Acceptance Criteria:
- **Scenario:** I put a decision card aside and return to it
- **Given:** a decision card, in its chat or under *Decisions*
- **When:** I tap the chevron beside its **⋯**, even while a request is on its way
- **Then:** it becomes one line with the question and a downward chevron. Folding sends nothing, and the row's *Decision waiting* and *Decisions (N)* stay the same. The fold survives leaving the screen, opening the ask in its other place, and restarting the app on this device. Tapping the line brings back the whole card, including any context I expanded and any own answer I had begun under *Other…* on that screen, and keeps it open next time.

### User Story 1132:

- **Summary:** Search the asks on *Decisions* by title and content, the answered ones too
- **Status:** native app: implemented in '2158881f' and '6a963e19', with its docs and screenshot in '446b4547', on branch `native/inbox-search-4dme`; verified on the host (`just native-test`: `ChatAskSearchTests`, the answer with empty and missing matches, the counts and the count line, the 400 and the 502, the request's escaping, the highlights, a row's tap; `test-fake-cockpit-ops.py`, the fake's `/asks/search`), the Mac build (`just native-build-mac`), and on the iPad Pro 11-inch (M5) simulator (`ChatAskSearchUITests`: an option's word finds the ask with its *option* line and *1 open · 0 answered*, an answered-only match says *No asks match.* and *0 open · 1 answered (tick to show)* and shows once *Answered too* is ticked, a 502 is a copyable problem, a tap opens the chat with the ask's card, and its kept screenshot shows the words marked in the option and context lines; `ChatDecisionUITests` 6/6 there too); the box moved above the rows on the iPhone in [43929f0b](https://github.com/idvorkin/context-grabber/commit/43929f0b) (it was in iOS's bottom toolbar there); `ChatAskSearchUITests` not yet run on the iPhone simulator, nor on a device; Escape from a hardware keyboard is the system's search Cancel, not tested
- **Issues:** bead context-grabber-4dme
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md), *Searching the asks*

#### Use Case:
- **As** Igor looking for a decision I remember a few words of
- **I want to** type them into the search box on *Decisions* and see the asks that say them, wherever they say them
- **so that** I can find an ask, open or long answered, on the phone as on the Cockpit's Inbox

#### Acceptance Criteria:
- **Scenario:** A word only in the ask's body
- **Given:** an open ask whose context, an option or its conversation says "ramen", and whose question does not
- **When:** I type "ramen" in the box on *Decisions*
- **Then:** once I pause, the list is that ask, with a line under its question saying where it matched (*option*) and
  the word marked, and the count line reads *1 open · 0 answered*

- **Scenario:** Several words, any order
- **Given:** an ask titled "Reconnect the Kindle Scribe Drive token?"
- **When:** I type "kindle reconnect"
- **Then:** it is found: every word must appear somewhere, case ignored, and characters like `.` and `<` are just characters

- **Scenario:** Only an answered ask matches
- **Given:** the only ask that matches was answered last month
- **When:** I search
- **Then:** the list says *No asks match.* and the count reads *0 open · 1 answered (tick to show)*; ticking *Answered
  too* shows it, after any open ones

- **Scenario:** Opening a found ask
- **Given:** a found row for an open ask Larry filed from a chat
- **When:** I tap it
- **Then:** that chat opens with the ask's card at the top; an answered ask opens its own chat, or its page on the Cockpit
  when Chat doesn't have it

- **Scenario:** The search fails
- **Given:** the Cockpit can't read its beads (a 502), or can't be reached
- **When:** I search
- **Then:** a copyable problem shows in place of the rows, carrying the words and the status; emptying the box brings the
  cards back as they were

---

### User Story 1603:

- **Summary:** A long decision card at the top of its thread scrolls inside itself instead of covering the chat
- **Status:** native app: implemented in [b4c4ed4f](https://github.com/idvorkin/context-grabber/commit/b4c4ed4f) and [1a248af4](https://github.com/idvorkin/context-grabber/commit/1a248af4); verified by host tests (`just native-test`, `ChatDecisionCapTests`), the Mac build, and the iPad simulator (rung 2: `ChatDecisionUITests` 7/7, `testALongCardInItsThreadScrollsInsideAndLeavesTheChatOnScreen`: the card stays at its cap, about 60% of the thread, the context opens inside it and scrolls to the last option, the message bar stays on screen); not yet seen on a device. No iPhone runs (whiteboard work, Igor 2026-11-22)
- **Issues:** bead context-grabber-o2i2, formerly 97s (Larry, 2026-11-22, Cockpit thread igor2-88g.1620: *"an expanded chat message/card grows to its full height instead of scrolling within a bounded height"*)
- **Spec:** [Decision cards in Chat](../superpowers/specs/2026-11-14-chat-decision-cards-design.md), *A long card at the top of its thread*

#### Use Case:
- **As** Igor, in a chat whose decision card has a long context from Larry
- **I want to** open the whole context and still see the chat, the message bar and the card's own controls
- **so that** reading the whole question never pushes the conversation, the options or the fold off the screen

#### Acceptance Criteria:
- **Scenario:** Opening a context longer than the screen
- **Given:** a decision card at the top of its chat whose context runs past the screen
- **When:** I tap the context to see all of it
- **Then:** the card stops at about 60% of the chat's height; the question, the fold chevron and the **⋯** stay at its
  top; I scroll inside the card to read the rest and reach the last option; the conversation and the message bar stay
  on screen under it; tapping the context again closes it to its first lines and the card shrinks back; a card whose
  whole context and options fit is drawn at its own height, as before, with nothing to scroll

---

### User Story 1134:

- **Summary:** Every message I send Larry says which build of the app sent it
- **Status:** native app: implemented in e4cf17ab; verified on the host (`just native-test`: `AppBuildTests`, the stamp read from a stamped Info.plist and not from the test runner's, a new chat and a reply, a board picture beside its own build line, every decision verb, a board's events, and an unstamped build sending neither) and the Mac build (`just native-build-mac`); a wire change with nothing on screen, so no simulator run; the real build number and sha on a live post are the phone's and the iPad's to show once deployed, and Larry seeing them waits on the Cockpit keeping them with the message
- **Issues:** bead context-grabber-esw3 (Larry, 2026-11-22, Cockpit thread igor2-88g.1620: Igor asked *"confirm I'm running it"* and Larry couldn't tell; only board posts carried a build)
- **Spec:** [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md), *Every post says which build sent it*

#### Use Case:
- **As** Igor, checking that a new build reached my phone or iPad
- **I want to** have every message I send Larry say which build sent it
- **so that** I can ask him *"am I running it?"* and he answers from the message, without my opening Settings

#### Acceptance Criteria:
- **Scenario:** A message goes to Larry
- **Given:** a build stamped with its build number and short commit
- **When:** I send a chat message (a new chat or a reply), reply from the Inbox, share something from another app, send a board's picture, or answer, close, abandon or snooze a decision
- **Then:** what reaches the Cockpit carries the build number and the short commit, under the same two names on every kind of message; a board picture also keeps the build line it already sent; and a build that knows neither fact sends the message as before, with neither name rather than an empty one

---

### User Story 1135:

- **Summary:** A link's chip reads the site's short name the Cockpit gives, so a new name needs no app release
- **Status:** native app: implemented in 5b7af00c; verified by ContextCore's host tests and the chat UI test classes on the iPad simulator
- **Issues:** Larry, 2026-11-24, Cockpit thread igor2-88g.1620 (msg 1edde2605703): Igor said yes to server-sent link labels; background in thread igor2-88g.1571
- **Spec:** [Chat with Larry — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md), *Site names come from the Cockpit*

#### Use Case:
- **As** Igor, reading a Larry thread full of links to his explainer pages
- **I want to** see *ai-tools/p04.html* instead of *idvorkin-ai-tools.github.io/p04.html*, and have the next short name appear without an app update
- **so that** chips stay short and Larry can rename a site from the Cockpit alone

#### Acceptance Criteria:
- **Scenario:** The Cockpit names a site
- **Given:** the Cockpit's site names include *idvorkin-ai-tools.github.io* as *ai-tools* and *example.org* as *ex*
- **When:** I open a thread linking https://idvorkin-ai-tools.github.io/p04.html, https://example.org/a/b and https://example.org/
- **Then:** the chips read *ai-tools/p04.html*, *ex/b* and *ex*, on the strip, on the list's rows and in the bubbles, each opening its full address

---

### User Story 1609:

- **Summary:** Before the Cockpit has answered, a link's chip reads the site names the app ships with
- **Status:** native app: implemented in 5b7af00c; verified by ContextCore's host tests
- **Issues:** Larry, 2026-11-24, Cockpit thread igor2-88g.1620 (msg 1edde2605703)
- **Spec:** [Chat with Larry — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md), *Site names come from the Cockpit*

#### Use Case:
- **As** Igor, opening chat on a fresh install with the Cockpit out of reach
- **I want to** still see the short names I am used to
- **so that** a chip never reads the long host just because the list hasn't arrived

#### Acceptance Criteria:
- **Scenario:** No list from the Cockpit yet
- **Given:** a first launch with the Cockpit unreachable
- **When:** I open a thread linking https://idvorkin-ai-tools.github.io/p04.html
- **Then:** the chip reads *ai-tools/p04.html*, from the names the app ships with

---

### User Story 1610:

- **Summary:** A site name from the Cockpit never renames a PR, gist, Inbox, Install or Larry chip
- **Status:** native app: implemented in 5b7af00c; verified by ContextCore's host tests
- **Issues:** Larry, 2026-11-24, Cockpit thread igor2-88g.1620 (msg 1edde2605703)
- **Spec:** [Chat with Larry — Links in a thread](../superpowers/specs/2026-10-25-native-chat-design.md), *Site names come from the Cockpit*

#### Use Case:
- **As** Igor, reading a thread of PRs, gists and Cockpit links
- **I want to** have those chips keep their own words whatever the Cockpit's list says
- **so that** *PR #n* and *Inbox* always mean what they did

#### Acceptance Criteria:
- **Scenario:** A name never changes a special chip
- **Given:** a list that also names *github.com*, *gist.github.com* and the Cockpit's own host
- **When:** a thread links a PR, a gist, a Cockpit thread and a Lavish page
- **Then:** they still read *PR #n*, *gist*, *Inbox* and *Larry: Lavish*

---

### User Story 1136:

- **Summary:** A Cockpit that blinks files no report
- **Issues:** [#1245](https://github.com/idvorkin/context-grabber/issues/1245), [#1246](https://github.com/idvorkin/context-grabber/issues/1246), [#1247](https://github.com/idvorkin/context-grabber/issues/1247), [#1248](https://github.com/idvorkin/context-grabber/issues/1248), [#1249](https://github.com/idvorkin/context-grabber/issues/1249), [#1250](https://github.com/idvorkin/context-grabber/issues/1250), [#1251](https://github.com/idvorkin/context-grabber/issues/1251), [#1252](https://github.com/idvorkin/context-grabber/issues/1252), [#1253](https://github.com/idvorkin/context-grabber/issues/1253), [#1259](https://github.com/idvorkin/context-grabber/issues/1259), [#1268](https://github.com/idvorkin/context-grabber/issues/1268), [#1269](https://github.com/idvorkin/context-grabber/issues/1269)
- **Status:** implemented in [1a685bc5](https://github.com/idvorkin/context-grabber/commit/1a685bc5); verified by the host rung (`just native-test`, `CockpitOutageTests`: a blip that heals files nothing) and the Mac build (`just native-build-mac`); the simulator and the devices are not yet verified (no iPhone runs while the whiteboard work is in progress)
- **Spec:** [An error on screen files a report by itself](../superpowers/specs/2026-11-19-errors-file-themselves-design.md), [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the developer reading the automatic reports
- **I want to** get no report when the Cockpit's proxy answers 502 to one poll and the next one reads fine
- **so that** a chat that heals in four seconds does not become ten issues

#### Acceptance Criteria:
- **Scenario:** A Cockpit that blinks files no report
- **Given:** a chat thread is open, the device is online, and the Cockpit just answered HTTP 502 (or any 5xx, or the read timed
  out, could not connect or lost its connection)
- **When:** the next poll reads the thread
- **Then:** no automatic report was saved (a thread that had loaded shows no banner for one blip, story 1606), and the log
  has `chat` `cockpit_outage` `ended` with `filed: false`

---

### User Story 1139:

- **Summary:** A Cockpit that stays away files one report
- **Issues:** [#1245](https://github.com/idvorkin/context-grabber/issues/1245), [#1246](https://github.com/idvorkin/context-grabber/issues/1246), [#1247](https://github.com/idvorkin/context-grabber/issues/1247), [#1248](https://github.com/idvorkin/context-grabber/issues/1248), [#1249](https://github.com/idvorkin/context-grabber/issues/1249), [#1250](https://github.com/idvorkin/context-grabber/issues/1250), [#1251](https://github.com/idvorkin/context-grabber/issues/1251), [#1252](https://github.com/idvorkin/context-grabber/issues/1252), [#1253](https://github.com/idvorkin/context-grabber/issues/1253), [#1259](https://github.com/idvorkin/context-grabber/issues/1259), [#1268](https://github.com/idvorkin/context-grabber/issues/1268), [#1269](https://github.com/idvorkin/context-grabber/issues/1269)
- **Status:** implemented in [1a685bc5](https://github.com/idvorkin/context-grabber/commit/1a685bc5); verified by the host rung (`just native-test`, `CockpitOutageTests`: two minutes of failures file once, a pause starts the count again) and the Mac build (`just native-build-mac`); the simulator and the devices are not yet verified (no iPhone runs while the whiteboard work is in progress)
- **Spec:** [An error on screen files a report by itself](../superpowers/specs/2026-11-19-errors-file-themselves-design.md), [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the developer reading the automatic reports
- **I want to** get one report when the Cockpit stays away, and no more while it lasts
- **so that** a real outage is still seen, once

#### Acceptance Criteria:
- **Scenario:** A Cockpit that stays away files one report
- **Given:** a chat thread is open, the device is online, and every read has failed the way story 1136 names for 2 minutes
- **When:** the next read fails that way
- **Then:** one automatic report is saved for the outage, saying how long it has lasted and how many reads failed; no other is
  saved while it lasts; the log has `cockpit_outage` `filed`, and `ended` with `filed: true` once a read gets through

---

### User Story 1600:

- **Summary:** A device that is offline files no report
- **Issues:** [#1245](https://github.com/idvorkin/context-grabber/issues/1245), [#1246](https://github.com/idvorkin/context-grabber/issues/1246), [#1247](https://github.com/idvorkin/context-grabber/issues/1247), [#1248](https://github.com/idvorkin/context-grabber/issues/1248), [#1249](https://github.com/idvorkin/context-grabber/issues/1249), [#1250](https://github.com/idvorkin/context-grabber/issues/1250), [#1251](https://github.com/idvorkin/context-grabber/issues/1251), [#1252](https://github.com/idvorkin/context-grabber/issues/1252), [#1253](https://github.com/idvorkin/context-grabber/issues/1253), [#1259](https://github.com/idvorkin/context-grabber/issues/1259), [#1268](https://github.com/idvorkin/context-grabber/issues/1268), [#1269](https://github.com/idvorkin/context-grabber/issues/1269)
- **Status:** implemented in [1a685bc5](https://github.com/idvorkin/context-grabber/commit/1a685bc5); verified by the host rung (`just native-test`, `CockpitOutageTests`: the device offline never files) and the Mac build (`just native-build-mac`); the simulator and the devices are not yet verified (no iPhone runs while the whiteboard work is in progress)
- **Spec:** [An error on screen files a report by itself](../superpowers/specs/2026-11-19-errors-file-themselves-design.md), [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the developer reading the automatic reports
- **I want to** get no report when a chat read fails because the device's own connection is down
- **so that** the iPad waking before the app notices it is offline (#1268) is not an issue

#### Acceptance Criteria:
- **Scenario:** A device that is offline files no report
- **Given:** the app has not yet noticed the device is offline
- **When:** a chat read fails with *The Internet connection appears to be offline*
- **Then:** it shows *The Cockpit isn't answering* with Copy error and saves no report, however long it lasts

---

### User Story 1601:

- **Summary:** Any other failed chat read files at once
- **Issues:** [#1245](https://github.com/idvorkin/context-grabber/issues/1245), [#1246](https://github.com/idvorkin/context-grabber/issues/1246), [#1247](https://github.com/idvorkin/context-grabber/issues/1247), [#1248](https://github.com/idvorkin/context-grabber/issues/1248), [#1249](https://github.com/idvorkin/context-grabber/issues/1249), [#1250](https://github.com/idvorkin/context-grabber/issues/1250), [#1251](https://github.com/idvorkin/context-grabber/issues/1251), [#1252](https://github.com/idvorkin/context-grabber/issues/1252), [#1253](https://github.com/idvorkin/context-grabber/issues/1253), [#1259](https://github.com/idvorkin/context-grabber/issues/1259), [#1268](https://github.com/idvorkin/context-grabber/issues/1268), [#1269](https://github.com/idvorkin/context-grabber/issues/1269)
- **Status:** implemented in [1a685bc5](https://github.com/idvorkin/context-grabber/commit/1a685bc5); verified by the host rung (`just native-test`, `CockpitOutageTests`: other failures file at once) and the Mac build (`just native-build-mac`); the simulator and the devices are not yet verified (no iPhone runs while the whiteboard work is in progress)
- **Spec:** [An error on screen files a report by itself](../superpowers/specs/2026-11-19-errors-file-themselves-design.md), [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the developer reading the automatic reports
- **I want to** keep a report for a chat read that fails in a way an outage does not explain
- **so that** a real bug is not hidden by the outage rule

#### Acceptance Criteria:
- **Scenario:** Any other failed chat read files at once
- **Given:** a chat thread is open
- **When:** the Cockpit answers HTTP 404, or an answer the app cannot read
- **Then:** it files at once, as story 155 says

---

### User Story 1602:

- **Summary:** The chat list keeps trying while the Cockpit is away
- **Issues:** [#1245](https://github.com/idvorkin/context-grabber/issues/1245), [#1246](https://github.com/idvorkin/context-grabber/issues/1246), [#1247](https://github.com/idvorkin/context-grabber/issues/1247), [#1248](https://github.com/idvorkin/context-grabber/issues/1248), [#1249](https://github.com/idvorkin/context-grabber/issues/1249), [#1250](https://github.com/idvorkin/context-grabber/issues/1250), [#1251](https://github.com/idvorkin/context-grabber/issues/1251), [#1252](https://github.com/idvorkin/context-grabber/issues/1252), [#1253](https://github.com/idvorkin/context-grabber/issues/1253), [#1259](https://github.com/idvorkin/context-grabber/issues/1259), [#1268](https://github.com/idvorkin/context-grabber/issues/1268), [#1269](https://github.com/idvorkin/context-grabber/issues/1269)
- **Status:** implemented in [1a685bc5](https://github.com/idvorkin/context-grabber/commit/1a685bc5); verified by the Mac build (`just native-build-mac`) only, the retry being app code no host test reaches; the simulator and the devices are not yet verified (no iPhone runs while the whiteboard work is in progress)
- **Spec:** [An error on screen files a report by itself](../superpowers/specs/2026-11-19-errors-file-themselves-design.md), [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** the developer reading the automatic reports
- **I want to** see the chat list read again by itself while it shows that the Cockpit is away
- **so that** the list heals without my pulling it, and the outage ends as soon as the Cockpit answers

#### Acceptance Criteria:
- **Scenario:** The chat list keeps trying while the Cockpit is away
- **Given:** the chat list is on screen and its last read failed the way story 1136 names, whether or not the banner of story 1604 shows yet
- **When:** 15 seconds pass
- **Then:** the list is read again, and again every 15 seconds until it reads or leaves the screen

---

### User Story 1604:

- **Summary:** The chat list says plainly when the Cockpit is down
- **Issues:** bead `context-grabber-3kgu`, [#1352](https://github.com/idvorkin/context-grabber/issues/1352), [#1353](https://github.com/idvorkin/context-grabber/issues/1353), [#1361](https://github.com/idvorkin/context-grabber/issues/1361)
- **Status:** implemented in [51a53eab](https://github.com/idvorkin/context-grabber/commit/51a53eab); verified by the host rung (`just native-test`, `CockpitDownTests`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatCockpitDownUITests` against the fake Cockpit answering 502, with the other chat classes); the devices are not yet verified
- **Spec:** [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor reading his chats
- **I want to** see *Cockpit not answering* at the top of the chat list when the Cockpit can't be reached or answers 5xx, with the chats it last read still under it
- **so that** an empty or stale list never passes for *no chats* or *nothing new*

#### Acceptance Criteria:
- **Scenario:** The chat list says plainly when the Cockpit is down
- **Given:** the device is online and the Cockpit answers the list's reads with HTTP 502 (or any 5xx, a timeout, or a refused connection)
- **When:** the list's reads fail enough to count as down: the first failure while it holds no rows, the second in a row once it has read
- **Then:** a banner beginning *Cockpit not answering* shows at the top with Copy error, with the rows it last read still under it

---

### User Story 1605:

- **Summary:** The down banner says what failed, since when, and the last good read
- **Issues:** bead `context-grabber-3kgu`, [#1352](https://github.com/idvorkin/context-grabber/issues/1352), [#1353](https://github.com/idvorkin/context-grabber/issues/1353), [#1361](https://github.com/idvorkin/context-grabber/issues/1361)
- **Status:** implemented in [51a53eab](https://github.com/idvorkin/context-grabber/commit/51a53eab); verified by the host rung (`just native-test`, `CockpitDownTests`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatCockpitDownUITests` against the fake Cockpit answering 502, with the other chat classes); the devices are not yet verified
- **Spec:** [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor reading his chats
- **I want to** copy the banner and get what failed, its HTTP status or reason, when it started failing and when the last good read was
- **so that** a report or a message to Larry carries the evidence (#1361 was a 502 on one thread at 12:39)

#### Acceptance Criteria:
- **Scenario:** The down banner says what failed, since when, and the last good read
- **Given:** a thread read at 12:31 and its reads have answered HTTP 502 since 12:39
- **When:** Igor copies the banner
- **Then:** the copy reads *Cockpit not answering — reading this chat answered HTTP 502 since 12:39; last good read 12:31*, a screen with no read since launch says *no good read since the app opened*, and the words stay the same while the outage lasts

---

### User Story 1606:

- **Summary:** The down banner waits for a second failure and clears itself
- **Issues:** bead `context-grabber-3kgu`, [#1352](https://github.com/idvorkin/context-grabber/issues/1352), [#1353](https://github.com/idvorkin/context-grabber/issues/1353), [#1361](https://github.com/idvorkin/context-grabber/issues/1361)
- **Status:** implemented in [51a53eab](https://github.com/idvorkin/context-grabber/commit/51a53eab); verified by the host rung (`just native-test`, `CockpitDownTests`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatCockpitDownUITests` against the fake Cockpit answering 502, with the other chat classes); the devices are not yet verified
- **Spec:** [Chat with Larry](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor reading his chats
- **I want to** see no banner for one blip the next poll heals, and see the banner go by itself when the Cockpit answers
- **so that** the banner means the Cockpit is really down, and I never have to pull to get rid of it

#### Acceptance Criteria:
- **Scenario:** The down banner waits for a second failure and clears itself
- **Given:** a thread is open with its messages loaded, and its reads have failed with HTTP 502, once (no banner) or long enough for the banner to show
- **When:** the next read gets through
- **Then:** no banner is on screen and the fresh messages are in place, and a later failure counts from one again, as does one more than five minutes after the thread's last failed read
---

### User Story 1608:

- **Summary:** A thread says it is loading while its first read is on its way
- **Issues:** [#1362](https://github.com/idvorkin/context-grabber/issues/1362)
- **Status:** implemented in [13706a3b](https://github.com/idvorkin/context-grabber/commit/13706a3b); verified by the host rung (`ChatThreadLoadingTests`), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatCockpitDownUITests.testASlowFirstReadSaysItIsLoading` against the fake Cockpit's `/fake/slow`, with the other chat classes); the devices are not yet verified
- **Spec:** [Chat with Larry — Saying plainly when the Cockpit is down](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor opening a chat while the Cockpit is slow to answer
- **I want to** see that the chat is loading rather than a blank page
- **so that** I know it is on its way and do not take an empty screen for a lost chat

#### Acceptance Criteria:
- **Scenario:** A slow first read says it is loading
- **Given:** a thread that has not been read since the app opened, and a Cockpit that takes several seconds to answer it
- **When:** Igor opens the thread
- **Then:** the thread says *Loading this chat…* with a spinner at once, and when the read lands the messages replace it; a new chat from the +, a thread whose messages are already on screen, or the device offline never shows the line
---

### User Story 1614:

- **Summary:** In a group chat every reply says who wrote it; Larry's own replies are never a skill
- **Status:** native app only: implemented in [ec2bb8e3](https://github.com/idvorkin/context-grabber/commit/ec2bb8e3) and [05c75dca](https://github.com/idvorkin/context-grabber/commit/05c75dca) (Tony always wears his byline, the whiteboard panel names speakers); verified by `just test` (host: `ChatSpeakerTests`: Larry's own name is Larry, *tony* is Tony, openers never make a group) and the iPad Pro 11-inch (M5) simulator (the chat UI classes, `ChatSkillThreadUITests` included); a group thread on the real Cockpit not yet
- **Spec:** [Chat with Larry in Grabber Native — Three voices, and a group chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor reading a thread that Larry, Tony or a skill all write in
- **I want to** see each reply's speaker by name and avatar, and Larry's own replies as Larry's
- **so that** I never mistake Tony's or a skill's words for Larry's, nor see Larry labelled as a skill

#### Acceptance Criteria:
- **Scenario:** Two speakers besides me make a group
- **Given:** a thread with a reply written under Larry's own name and another under *tony*, and a page or call opener at the top
- **When:** I open it
- **Then:** every reply carries its speaker's name and lettered avatar, Larry's in purple and Tony's as *Tony*; the opener alone never makes a thread a group, so a thread with Larry and the opener reads as before, and a reply under Larry's name there has no skill byline; a reply under *tony* always wears *Tony*, even when Tony is the only one answering

---

### User Story 1615:

- **Summary:** A call's thread rows are news, never an answer to me
- **Status:** native app only: implemented in [ec2bb8e3](https://github.com/idvorkin/context-grabber/commit/ec2bb8e3); verified by `just test` (host: `ChatSpeakerTests.testAFailureThenOnlyCallRowsStillFails`); a call's thread on the real Cockpit not yet
- **Spec:** [Chat with Larry in Grabber Native — A call's thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor writing on a voice call's own thread
- **I want to** have the call's own rows (a consult's answer, a note, the summary) not count as Larry answering me
- **so that** a message of mine that only a failure followed still shows it was not answered

#### Acceptance Criteria:
- **Scenario:** A failure, then only the call's rows
- **Given:** my message on a call's thread, a failure after it, and then rows the call's bridge wrote
- **When:** I read the thread
- **Then:** my message still shows 👀, not 🏆, until a real reply of Larry's follows

---

### User Story 1607:

- **Summary:** The + opens a new chat again after the last one landed
- **Issues:** [#1365](https://github.com/idvorkin/context-grabber/issues/1365); bead context-grabber-6d1b (on the iPhone, two quick Backs to Home left the list's bottom search toolbar over the Chat tile)
- **Status:** the + logs what it found, and new_chat_shown, new_chat_gone or new_chat_not_shown, in [3b090f81](https://github.com/idvorkin/context-grabber/commit/3b090f81); verified by `ChatNewChatAgainUITests` on the iPad simulator against the fake Cockpit (the + opened a new chat again after each of four ways out) and that run's session log (new_chat_shown after every +, no new_chat_not_shown); the Mac's dead + is not reproduced yet; step E's dead Chat tile on the iPhone (bead context-grabber-6d1b: the chat list's bottom search toolbar left over Home) fixed in [43929f0b](https://github.com/idvorkin/context-grabber/commit/43929f0b), the search box above the rows, and verified by `ChatNewChatAgainUITests` 3/3 on the iPhone 17 simulator (3/3 failed at step E before)
- **Spec:** [Chat with Larry in Grabber Native — A new chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client starting one chat after another
- **I want to** have the + open a new chat every time I tap it
- **so that** I never sit in front of a dead + wondering whether my next thought went anywhere

#### Acceptance Criteria:
- **Scenario:** The + opens a new chat again
- **Given:** the Cockpit is up, my last new chat landed in its thread, and I left it by Back, by going Home and coming back to Chat, or by opening another thread from the list
- **When:** I tap the + again
- **Then:** an empty *New chat* opens each time

---

### User Story 1611:

- **Summary:** Each day of the week goes to Larry as one record: sleep, movement, workouts, places by name, habits
- **Status:** native app: implemented in 5f3f4fe4; verified by ContextCore's host tests (DailyPushTests), the Mac build and the iPad simulator smoke; the iPhone (Health, the trail, the Cockpit's /daily) still to check
- **Issues:** Igor, 2026-11-24 09:07, via Larry (Cockpit thread igor2-88g.1620, msg faf3017bc6cd); shape agreed in msg 567ab576db57; Cockpit side cockpit-61m
- **Spec:** [The day, summed up, to Larry](../superpowers/specs/2026-11-24-daily-summary-to-larry-design.md)

#### Use Case:
- **As** Igor, writing my weekly report with Larry
- **I want to** have every day of the week already with him, summed up as the app reads it
- **so that** the report starts from real numbers without either of us working them out again

#### Acceptance Criteria:
- **Scenario:** The week goes, once
- **Given:** the switch *Send the day to Larry* is on and the Cockpit takes the records
- **When:** I open Today, and then open it again with nothing changed
- **Then:** each of the last seven days was sent once, oldest first, with sleep asleep and in bed kept apart, where the sleep was measured, steps, exercise minutes, heart rate, weight, workouts, the minutes per named place and every strip habit by its own name; the second opening sent nothing

---

### User Story 1612:

- **Summary:** A day that changes later is sent again, and only that day
- **Status:** native app: implemented in 5f3f4fe4; verified by ContextCore's host tests (DailyPushTests), the Mac build and the iPad simulator smoke; the iPhone (Health, the trail, the Cockpit's /daily) still to check
- **Issues:** Igor, 2026-11-24 09:07, via Larry (Cockpit thread igor2-88g.1620, msg faf3017bc6cd)
- **Spec:** [The day, summed up, to Larry](../superpowers/specs/2026-11-24-daily-summary-to-larry-design.md), *When it goes*

#### Use Case:
- **As** Igor, ticking yesterday's journal this morning, or with last night's sleep syncing from the Watch late
- **I want to** have Larry see the corrected day
- **so that** the weekly report reads the week as it really was, not as it first looked

#### Acceptance Criteria:
- **Scenario:** A habit ticked for yesterday
- **Given:** yesterday's record already went with the journal not done
- **When:** I tick the journal for yesterday and Today grabs again
- **Then:** yesterday goes again with the journal done by a tap, and no other day goes

---

### User Story 1613:

- **Summary:** No coordinates, nothing from the iPad, and a reading Health refused leaves only that reading empty
- **Status:** native app: implemented in 5f3f4fe4; a refused steps reading no longer empties the habits in a9f7b40e (host test DailyPushTests testAFailedStepsReadingKeepsTheHabits); verified by ContextCore's host tests (DailyPushTests), the Mac build and the iPad simulator smoke; the iPhone (Health, the trail, the Cockpit's /daily) still to check
- **Issues:** Igor, 2026-11-24 09:07, via Larry (Cockpit thread igor2-88g.1620, msg faf3017bc6cd); review finding habits-dates-diverge (a failed steps reading sent every day with no habits)
- **Spec:** [The day, summed up, to Larry](../superpowers/specs/2026-11-24-daily-summary-to-larry-design.md), *Goals*

#### Use Case:
- **As** Igor, whose day says where I live and work
- **I want to** send only place names and only from the phone, and never lose a whole day to one failed reading
- **so that** what Larry keeps is private, counted once, and as complete as Health allows

#### Acceptance Criteria:
- **Scenario:** A day with an unnamed stay and a refused reading
- **Given:** a day with a stay at a place I never named, and Health refusing that day's weight
- **When:** the day's record goes
- **Then:** the unnamed stay counts only as minutes, no latitude, longitude or circle is in the record, the weight is empty and every other reading is there; on the iPad nothing is sent at all

---

### User Story 1619:

- **Summary:** Meditation in the day's record counts as the strip counts it: Health's mindful minutes only for today
- **Status:** native app: implemented in a9f7b40e; verified by ContextCore's host test DailyPushTests testMindfulMinutesCountMeditationForTodayOnly; the iPhone (Health's mindful minutes) still to check
- **Issues:** review finding meditation-health-past-days (a past day's mindful minutes marked meditation done while the strip showed it not done)
- **Spec:** [The day, summed up, to Larry](../superpowers/specs/2026-11-24-daily-summary-to-larry-design.md), *What a day's record says*

#### Use Case:
- **As** Igor, reading the week's habits with Larry
- **I want to** have the record say meditation was done exactly when my strip says so
- **so that** the weekly report and the strip I see never disagree

#### Acceptance Criteria:
- **Scenario:** Mindful minutes on a past day and today
- **Given:** Health has mindful minutes for Monday and for today, and I neither tapped meditation nor ran Box breathing on either day
- **When:** the week is sent on Tuesday
- **Then:** today's meditation is done by Health, Monday's is not done, and both days still carry their mindful minutes
---

### User Story 1616:

- **Summary:** Search the chat list for a thread by its words
- **Issues:** [#1443](https://github.com/idvorkin/context-grabber/issues/1443)
- **Status:** implemented in [01c9badc](https://github.com/idvorkin/context-grabber/commit/01c9badc); verified by the host rung (`ChatThreadSearchTests`, `test-fake-cockpit-ops.py`'s `/chat?q` checks), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatThreadSearchUITests` against the fake Cockpit's `GET /chat?q`, with the other chat classes, 37/37); the box sits above the rows on the iPhone too in [43929f0b](https://github.com/idvorkin/context-grabber/commit/43929f0b), verified by `ChatThreadSearchUITests` 3/3 on the iPhone 17 simulator; not yet on a device
- **Spec:** [Chat with Larry — Searching the threads](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor looking for a chat I remember a few words of
- **I want to** type them into a search box on the chat list and see only the threads that say them
- **so that** I can find a thread on the phone as I do on the Cockpit's Stream, without scrolling the whole list

#### Acceptance Criteria:
- **Scenario:** Words in a thread's title or newest message
- **Given:** a chat titled "Ramen in Ashland" and others that never say ramen
- **When:** I type "ashland ramen" in the list's search box and pause
- **Then:** the list is that chat's row with the words marked, and a tap opens the thread

### User Story 1617:

- **Summary:** A chat list search reaches words deep in a thread's older messages
- **Issues:** [#1443](https://github.com/idvorkin/context-grabber/issues/1443)
- **Status:** implemented in [01c9badc](https://github.com/idvorkin/context-grabber/commit/01c9badc); verified by the host rung (`ChatThreadSearchTests`, `test-fake-cockpit-ops.py`'s `/chat?q` checks), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatThreadSearchUITests` against the fake Cockpit's `GET /chat?q`, with the other chat classes, 37/37); the box sits above the rows on the iPhone too in [43929f0b](https://github.com/idvorkin/context-grabber/commit/43929f0b), verified by `ChatThreadSearchUITests` 3/3 on the iPhone 17 simulator; not yet on a device
- **Spec:** [Chat with Larry — Searching the threads](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor who remembers words from somewhere in a conversation, not from its title or newest message
- **I want to** the search to find that chat anyway, as the Cockpit's own chat search does
- **so that** the phone and the laptop find the same threads

#### Acceptance Criteria:
- **Scenario:** A word only in an older message
- **Given:** a chat whose first message says "passport" and whose title and newest message do not
- **When:** I search "passport"
- **Then:** once the Cockpit answers, that chat's row shows; a done or archived chat that matches shows after the live ones

### User Story 1618:

- **Summary:** The chat list search survives the Cockpit being down and leaves the list as it was
- **Issues:** [#1443](https://github.com/idvorkin/context-grabber/issues/1443)
- **Status:** implemented in [01c9badc](https://github.com/idvorkin/context-grabber/commit/01c9badc); verified by the host rung (`ChatThreadSearchTests`, `test-fake-cockpit-ops.py`'s `/chat?q` checks), the Mac build (`just native-build-mac`) and the iPad Pro 11-inch (M5) simulator (`ChatThreadSearchUITests` against the fake Cockpit's `GET /chat?q`, with the other chat classes, 37/37); the box sits above the rows on the iPhone too in [43929f0b](https://github.com/idvorkin/context-grabber/commit/43929f0b), verified by `ChatThreadSearchUITests` 3/3 on the iPhone 17 simulator; not yet on a device
- **Spec:** [Chat with Larry — Searching the threads](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Igor searching while the Cockpit is unreachable
- **I want to** still see the chats the phone itself can match, with a plain note of what is missing
- **so that** a down Cockpit never leaves me with nothing, and clearing the box puts my list back

#### Acceptance Criteria:
- **Scenario:** The Cockpit's search fails
- **Given:** the Cockpit answers the search with a 502
- **When:** I search words a chat's title says
- **Then:** that chat's row shows under a copyable problem naming the search and the 502; with no match at all the list says *No chats match.*; emptying the box brings back the list, its *All*/*New* choice and *Decisions* as they were
