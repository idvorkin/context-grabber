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
- **Status:** native app only: implemented in [c5a4025](https://github.com/idvorkin/context-grabber/commit/c5a4025); verified by `InboxDraftTests` and the full `just test` (host); the sheet, dictation and pasting on the phone not yet; #424: the + is a floating button in the lower right in [066dae4](https://github.com/idvorkin/context-grabber/commit/066dae4); verified by `just test` (host) and the simulator build; on the phone not yet. #536: the + opens a new thread with the ordinary bar instead of a sheet in [ca6fe3d](https://github.com/idvorkin/context-grabber/commit/ca6fe3d); verified by `ChatNewThreadUITests` (simulator: the + opens an empty *New chat* thread with the bar, its mic and Paste image, and no sheet); sending from it on the phone not yet. #637: the + no longer floats, it sits in a bar below the list beside the voice button, in [dd6c94d](https://github.com/idvorkin/context-grabber/commit/dd6c94d); verified by `ChatArchiveUITests` (simulator); on the phone not yet. #685: the + floats over the list again, beside the voice button, in [dd5d9ef8](https://github.com/idvorkin/context-grabber/commit/dd5d9ef8); verified by `ChatArchiveUITests` (simulator: chat suite 34 passed; one swipe test failed on the suite's slow first launch, then passed 3 of 3 alone); on the phone not yet.; the + opening the ordinary bar with the keyboard up is now checked at the end of `ChatNewThreadUITests`' voice-button test, the focus rule in `ChatNewThreadScreenTests` (host), bead `context-grabber-t8i`
- **Issues:** [#405](https://github.com/idvorkin/context-grabber/issues/405), [#424](https://github.com/idvorkin/context-grabber/issues/424), [#536](https://github.com/idvorkin/context-grabber/issues/536), [#637](https://github.com/idvorkin/context-grabber/issues/637), [#685](https://github.com/idvorkin/context-grabber/issues/685)
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
- **Status:** native app only: implemented in [ff6e3b8](https://github.com/idvorkin/context-grabber/commit/ff6e3b8); verified by `ChatTests` (host: the message to its thread's path with its id and the app as source, an image uploaded first and named by its ref), `InboxTests` (oldest first), `sim-smoke.sh` (one `POST /chat/<key>`, the text never in the log); the phone's copy dropped once the thread shows it in the review round, not yet verified on any rung; a send over the tailnet from the phone once cockpit#64 is merged; the bar emptied after a send with the keyboard up for the next ([46ca1f7](https://github.com/idvorkin/context-grabber/commit/46ca1f7), #449) verified by `ChatComposeClearsUITests` (simulator: typed, sent, the field empty, focused and Send disabled, the next message typed straight on); simulator typing does not reproduce the phone's leftover text, so on the phone not yet, where its `bar_after_send` line will say; bead `context-grabber-t8i` folds that check into `ChatNewThreadUITests`' first-message test (the field empty, the keyboard up, the next words in with no tap), and Send disabled on an empty bar into `ChatNewThreadScreenTests` (host)
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
- **Status:** native app only: implemented with Deepgram in [2015662](https://github.com/idvorkin/context-grabber/commit/2015662), moved to the problem report's Apple dictation with the five-minute cap in [f040853](https://github.com/idvorkin/context-grabber/commit/f040853), with the microphone picker; verified by `ChatVoiceTests`, `ChatVoiceClockTests` and `ChatVoiceWordsTests` (host: the five-minute limit and its line, the recording clock, a timer that dies with its recording, a thread's words taken by that thread only) and `ChatVoiceUITests` (Settings asks for no Deepgram key because that section is gone from the code; on the simulator: the thread's mic and its microphone picker are there and ready); speaking on the phone not yet; #544: the microphone picker is a full-width row a finger tall, as the problem report's is, in [442e0a5](https://github.com/idvorkin/context-grabber/commit/442e0a5); host `just native-test`; the simulator's ChatVoiceUITests and the phone not yet; #546: a Send mid-recording stops it, so no words come back into the emptied bar, in [84e4f70](https://github.com/idvorkin/context-grabber/commit/84e4f70); no automated test (the decision lives in the app target); on the phone not yet; #625: the mic moved beside Send in [f52d9dd](https://github.com/idvorkin/context-grabber/commit/f52d9dd); verified by ChatVoiceUITests on the iPhone 17 simulator, where it measures the order, the gap and the 44-point targets; the iPad and a finger on it are still to try; #559: a chat recording holds the microphone against the problem report, in [080fbf7](https://github.com/idvorkin/context-grabber/commit/080fbf7); host `just native-test` and a simulator compile; dictating on the phone not yet.
- **Issues:** [#559](https://github.com/idvorkin/context-grabber/issues/559), [#448](https://github.com/idvorkin/context-grabber/issues/448), [#544](https://github.com/idvorkin/context-grabber/issues/544), [#546](https://github.com/idvorkin/context-grabber/issues/546), [#625](https://github.com/idvorkin/context-grabber/issues/625)
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

- **Scenario:** A problem report during a recording (#559)
- **Given:** I'm recording a message in a thread
- **When:** I shake to report a problem
- **Then:** the recording keeps going with its words intact, and the report's mic is off, as it is during a call, until I stop recording; if the recording ends with the report still open, the mic comes back at my next keystroke

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
- **Status:** native app only: implemented in [8625876](https://github.com/idvorkin/context-grabber/commit/8625876); verified by the simulator build, `ChatImageCloseTests` (host: only a swipe down past 80 points closes) and `ChatImageUITests` (simulator: Done and a swipe down close it); tapping Done and swiping down over a white picture on the iPad not yet
- **Issues:** [#592](https://github.com/idvorkin/context-grabber/issues/592)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client reading a picture he sent back, such as my whiteboard with his marks on it
- **I want to** see it full size and get back to the thread
- **so that** a white picture never leaves me stuck on a screen with no visible way out

#### Acceptance Criteria:
- **Scenario:** Back from a white picture
- **Given:** a thread holds a picture that is mostly white, like a whiteboard
- **When:** I tap it, then tap *Done* or swipe down
- **Then:** the picture fills the screen with *Done* on a dark badge I can see over it, and either one brings me back to the thread

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
- **Status:** native app only: implemented in [61e7f30](https://github.com/idvorkin/context-grabber/commit/61e7f30); verified by the simulator (`ChatArchiveUITests` against the fake Cockpit); not re-run since the request gained its `Content-Type` in [9ff3ded](https://github.com/idvorkin/context-grabber/commit/9ff3ded); against the real Cockpit on the iPad not yet; bead `context-grabber-t8i`: the menu's rules are `ChatArchiverTests` (host), and the menu archiving and going back stays in `ChatArchiveUITests`
- **Issues:** [#589](https://github.com/idvorkin/context-grabber/issues/589), [#591](https://github.com/idvorkin/context-grabber/issues/591)
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
- **Status:** native app only: implemented in [9027855](https://github.com/idvorkin/context-grabber/commit/9027855); verified on the simulator by `ChatArchiveUITests` against the fake Cockpit; Larry's mark on the real Cockpit not yet (he agreed `looks_done` and is building it); bead `context-grabber-t8i`: what Review ticks and the one-tap archive are `ChatArchiverTests` (host); the taps are `sim-smoke.sh`'s `GRABBER_CHAT_SELECT` check
- **Issues:** [#599](https://github.com/idvorkin/context-grabber/issues/599)
- **Spec:** [Native chat](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As a** man who forgets to close chats
- **I want to** untick any proposal I disagree with and archive the rest
- **so that** Larry's judgement stays a proposal I approve

#### Acceptance Criteria:
- **Scenario:** Approving
- **Given:** I tapped *Review*
- **When:** I untick any I want to keep and tap *Archive (N)*
- **Then:** the ticked ones fold under *Done* with *Undo*, and the rest stay live

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
- **Status:** native app only: implemented in [f37d267](https://github.com/idvorkin/context-grabber/commit/f37d267); verified on the simulator against the fake Cockpit (the jump); a board that comes down from iCloud on the jump, and sending `board` from the app (another branch), not yet
- **Issues:** [#603](https://github.com/idvorkin/context-grabber/issues/603)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client looking at an old picture of a whiteboard in a thread
- **I want to** zoom in on it and tap *Jump to board*
- **so that** I am on the board as it is now, not looking at a stale screenshot

#### Acceptance Criteria:
- **Scenario:** A picture from a board
- **Given:** a thread holds a picture sent from a whiteboard that iCloud or this device holds
- **When:** I tap the picture, then *Jump to board*
- **Then:** iCloud is asked first, the full-size view goes down and the board opens with what is on it now; *Done* on the boards takes me home, and no full-size view is left in the way

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
- **Status:** native app only: implemented in [f37d267](https://github.com/idvorkin/context-grabber/commit/f37d267); verified on the simulator against the fake Cockpit (a board no device has); a board deleted on another device, or a drawing that fails to come down, not yet
- **Issues:** [#603](https://github.com/idvorkin/context-grabber/issues/603)
- **Spec:** [Chat with Larry in Grabber Native — A thread](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client jumping to a board from an old picture
- **I want to** be told when the board can't be opened as it is now
- **so that** I keep the picture and never land on a blank or old board by mistake

#### Acceptance Criteria:
- **Scenario:** A board that can't be opened
- **Given:** the picture's board was deleted, isn't on this device even after asking iCloud, or its latest drawing didn't come down
- **When:** I tap *Jump to board*
- **Then:** a copyable problem says so over the picture, which stays open until I close it

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
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the refusal and the kept file verified on the host by `ChatFileTests`; the problem seen on the simulator against the fake Cockpit, and the refusal checked by the smoke until context-grabber-gp7; since then the refusal with no message after it is `InboxOutboxTests` (host) and the smoke no longer relaunches for it
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client while the Cockpit holds only pictures
- **I want to** be told the file did not go, and keep it
- **so that** I never believe Larry has a file he doesn't

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses a file
- **Given:** the Cockpit takes only pictures
- **When:** I send a PDF
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
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); the store and the second refusal verified on the host by `ChatFileTests`; `GRABBER_CHAT_SEND_AGAIN` and its smoke check written, not yet run on the simulator; the tap itself on the phone, not yet; since context-grabber-gp7 the kept file uploading again, refused again with no message, is `InboxOutboxTests` (host) and the smoke check is gone
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client trying again while the Cockpit holds only pictures
- **I want to** hear the same answer and keep the file
- **so that** trying costs me nothing

#### Acceptance Criteria:
- **Scenario:** Sending again too soon
- **Given:** a refused file, and the Cockpit still takes only pictures
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

- **Summary:** A file over 10 MB says so when it is picked
- **Status:** native app only: implemented in [e149294](https://github.com/idvorkin/context-grabber/commit/e149294); verified on the host by `ChatFileTests`; the problem on screen needs the document picker, on the phone, not yet
- **Issues:** [#633](https://github.com/idvorkin/context-grabber/issues/633)
- **Spec:** [Chat with Larry in Grabber Native — Attaching a file](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client picking a large file
- **I want to** hear about it at once
- **so that** I don't wait on a send that can never work

#### Acceptance Criteria:
- **Scenario:** Too big
- **Given:** a file over 10 MB
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
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewChatVoiceTests` (host: recording once per tap) and `ChatNewThreadUITests` (simulator: the button sits beside the +, opens *New chat* with no sheet, its mic tapped as it opens); the red seconds and the keyboard staying down on the phone not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637)
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
- **Status:** native app only: implemented in [08e89d1](https://github.com/idvorkin/context-grabber/commit/08e89d1); verified by `ChatNewThreadUITests` (simulator: the mic's copyable line or a recording, whichever the simulator's permissions give, with nothing sent); declining on the phone not yet
- **Issues:** [#637](https://github.com/idvorkin/context-grabber/issues/637)
- **Spec:** [Chat with Larry in Grabber Native — A new chat by voice](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client whose microphone or speech recognition is off
- **I want to** be told what is off and keep the new chat
- **so that** I can type instead, or fix it and try the mic again

#### Acceptance Criteria:
- **Scenario:** Recording can't start
- **Given:** speech recognition or the microphone is declined, or the recognizer won't start
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
- **Issues:** [#632](https://github.com/idvorkin/context-grabber/issues/632)
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
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host, `ChatHold.choices`: all four on Larry's words, only Quote and Copy on mine, only Yes and No on a picture alone) and `ChatReactionUITests` (simulator, fake Cockpit: all four on Larry's message, Quote on mine); the feel of the hold on the phone and iPad, and links staying tappable, not yet
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
- **Then:** Larry's offers *Yes*, *No*, *Quote in reply* and *Copy*; mine offers only *Quote in reply* and *Copy*; a message that is only a picture offers neither *Quote in reply* nor *Copy*

---

### User Story 519:

- **Summary:** Yes or No to Larry's newest message sends that one word
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host) and `ChatReactionUITests` (simulator: the fake's Larry repeats *Yes*); half-typed words staying in the bar and a *Yes* with no network follow from the code, not exercised on any rung; a real Larry waking on the phone not yet
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629), [#809](https://github.com/idvorkin/context-grabber/issues/809) (a sent message its thread never returns would make *Yes* go out quoted; the log's `chat` outbox_thread line is there to settle whether it happens)
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

---

### User Story 540:

- **Summary:** Yes or No to an older message says which message it answers
- **Status:** native app only: implemented in [1d5008e](https://github.com/idvorkin/context-grabber/commit/1d5008e); verified by `ChatReactionTests` (host: the quote, its lines, the 280-character cut, a picture alone) and `ChatReactionUITests` (simulator: *No* on an older message reaches the fake under its quote); older because something newer still waits on the phone not exercised on any rung
- **Issues:** [#629](https://github.com/idvorkin/context-grabber/issues/629), [#809](https://github.com/idvorkin/context-grabber/issues/809) (whether a sent message can count as still waiting for good; see story 519)
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
- **Status:** native app only: a mic button on the card's *Message* field, the problem report's dictation, implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet: Apple's guidance is that an app extension cannot use the microphone (an iMessage app excepted), so the first tap on the phone settles whether it can. Stopping, sending, cancelling and a refusal are stories 555–558
- **Issues:** [#673](https://github.com/idvorkin/context-grabber/issues/673), [#793](https://github.com/idvorkin/context-grabber/issues/793)
- **Spec:** [Chat with Larry in Grabber Native — Speaking on the card](../superpowers/specs/2026-10-25-native-chat-design.md)

#### Use Case:
- **As** Larry's client sharing a page with my hands full
- **I want to** say my message on the card with a mic button, as I do in a problem report
- **so that** what I think about the page goes with it without typing

#### Acceptance Criteria:
- **Scenario:** Saying the message
- **Given:** the share card is open on a page from Safari
- **When:** I tap the mic button on the *Message* field and speak
- **Then:** the button becomes a red stop button, my words appear in the *Message* field after anything I typed, the field takes no typing while it listens, and nothing is sent until I tap *Start a chat* or *Send*

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
- **Status:** native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793)
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
- **Status:** native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793)
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
- **Status:** native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793)
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
- **Status:** native app only: implemented in [92850cd9](https://github.com/idvorkin/context-grabber/commit/92850cd9) and [9b5a4d07](https://github.com/idvorkin/context-grabber/commit/9b5a4d07); host `just native-test` (format and lint only: the card is not compiled there) and the simulator rung's Xcode build of the branch, the share extension included, against BugKit 0.3.12; speaking on the phone not yet
- **Issues:** [#793](https://github.com/idvorkin/context-grabber/issues/793)
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
