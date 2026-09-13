# Places: where the week went

Turning a quiet trail of breadcrumbs into named places and hours — for the map, the breakdown, and the coach.

Part of the [user stories](README.md); persona and format are described there.

---

### User Story 040:

- **Summary:** Opt in to background tracking once, then forget it
- **Status:** implemented in [8361ad4](https://github.com/idvorkin/context-grabber/commit/8361ad4), [97b33b0](https://github.com/idvorkin/context-grabber/commit/97b33b0); verified by `location.test.ts`, `db.test.ts` and on the phone (months of trail)

#### Use Case:
- **As** someone who wants the location story captured implicitly
- **I want to** flip one switch, grant Always permission, and have breadcrumbs stored locally from then on
- **so that** I never log where I was, and nothing leaves the phone

#### Acceptance Criteria:
- **Scenario:** Turning tracking on
- **Given:** tracking is off (the default on a fresh install)
- **When:** I switch on Background Tracking in Settings and allow Always
- **Then:** points land in the local database with latitude, longitude, accuracy and a UTC timestamp while the app is closed, the switch stays on across relaunches, and denying the permission leaves the switch off with a message rather than a crash

---

### User Story 041:

- **Summary:** Keep only the last N days of trail
- **Status:** implemented in [8361ad4](https://github.com/idvorkin/context-grabber/commit/8361ad4); verified by `location.test.ts` and on the phone

#### Use Case:
- **As** someone who does not want a permanent location log on the phone
- **I want to** set retention in days, with older points pruned on foreground and immediately when I lower the number
- **so that** the history is bounded and the bound is mine

#### Acceptance Criteria:
- **Scenario:** Shortening retention
- **Given:** retention is 30 days and forty days of points exist
- **When:** I set retention to 7
- **Then:** points older than seven days are gone at once, the Places breakdown shrinks to match, and reopening the app tomorrow prunes again without me touching anything

---

### User Story 042:

- **Summary:** A precise fix on every foreground
- **Status:** implemented in [ae0c1d0](https://github.com/idvorkin/context-grabber/commit/ae0c1d0); verified on the phone (issue closed after use)
- **Issues:** [#32](https://github.com/idvorkin/context-grabber/issues/32)

#### Use Case:
- **As** someone whose phone stops reporting when it sits still
- **I want to** get a high-accuracy fix each time the app comes to the front
- **so that** "You" on the map is where I am, not where I parked two hours ago

#### Acceptance Criteria:
- **Scenario:** Coming back to the app
- **Given:** the phone was stationary for hours
- **When:** I foreground the app
- **Then:** a fresh precise fix is requested and the Today map's "You" pin moves to it before the grab completes

---

### User Story 043:

- **Summary:** Breadcrumbs become stays: where I was, from when to when
- **Status:** implemented in [88c1bbd](https://github.com/idvorkin/context-grabber/commit/88c1bbd), [ff18ef3](https://github.com/idvorkin/context-grabber/commit/ff18ef3); verified by `clustering_v2.test.ts` against the 36 000-point real fixture and on the phone (daily use). The v1 grid clustering ([08be4fd](https://github.com/idvorkin/context-grabber/commit/08be4fd)) is kept only for the Raw share.
- **Issues:** [#9](https://github.com/idvorkin/context-grabber/issues/9)

#### Use Case:
- **As** someone with a noisy indoor GPS
- **I want to** have the trail read as stays of at least five minutes within about a hundred metres, with the same coffee shop on two days as two stays
- **so that** the timeline is "Office 9am–5pm", not a spatial blob with a meaningless total

#### Acceptance Criteria:
- **Scenario:** An ordinary weekday
- **Given:** points at Home, a drive, Office, a drive, Gym, Home
- **When:** the Places tab opens
- **Then:** the day reads as four stays in time order with start, end and duration, a stop under five minutes is not a stay, a wild 200 m GPS jump that snaps back within thirty minutes does not split a stay, and a place with no name is "Place N", numbered by first visit and stable across days

---

### User Story 044:

- **Summary:** A silent night at home is one stay, not two with a hole
- **Status:** implemented in [ebbd97c](https://github.com/idvorkin/context-grabber/commit/ebbd97c); verified by `clustering_v2.test.ts` (Thursday in the real fixture: one Home stay across a 5 h 23 m gap) and on the phone

#### Use Case:
- **As** someone whose phone stops reporting while it charges on the nightstand
- **I want to** have consecutive stays at the same place merged regardless of the gap between them
- **so that** the night reads "Home 9pm–7am", not two fragments and nine hours of "no data"

#### Acceptance Criteria:
- **Scenario:** Overnight silence
- **Given:** a Home point at 11 pm and the next at 5 am with nothing between
- **When:** the day is clustered
- **Then:** Home is a single stay from the evening to the morning; Home → Bar → Home stays three stays; a three-night stretch at one place collapses into one stay

---

### User Story 045:

- **Summary:** My places by name: Home, Office, Gym
- **Status:** implemented in [2f8aaa2](https://github.com/idvorkin/context-grabber/commit/2f8aaa2), [363c94f](https://github.com/idvorkin/context-grabber/commit/363c94f); verified by `places.test.ts` and on the phone. Supersedes DB-5 in `docs/user-needs.md`.
- **Issues:** [#12](https://github.com/idvorkin/context-grabber/issues/12), [#14](https://github.com/idvorkin/context-grabber/issues/14)

#### Use Case:
- **As** someone who wants the timeline in my own words
- **I want to** add, delete and import known places with a name, coordinates and radius, using my current position when I am standing there
- **so that** stays are labelled Home and Gym, and a coach can read them

#### Acceptance Criteria:
- **Scenario:** Naming the gym from the gym
- **Given:** I am inside the gym
- **When:** I open the Location sheet, type "Gym", tap Use Current, and Add Place
- **Then:** the place is stored with a fix under thirty seconds old (a stale fix is refused with a status line), today's stay there is labelled Gym on the next render, the list shows it under Known Places with its count, and Import Places accepts a JSON array of places

---

### User Story 046:

- **Summary:** Every day's hours add up: stays, transit, no data, on a 24-hour strip
- **Status:** implemented in [16388d2](https://github.com/idvorkin/context-grabber/commit/16388d2), [75ec6f5](https://github.com/idvorkin/context-grabber/commit/75ec6f5), [16f1be3](https://github.com/idvorkin/context-grabber/commit/16f1be3), [e2e6a88](https://github.com/idvorkin/context-grabber/commit/e2e6a88), [46d38e5](https://github.com/idvorkin/context-grabber/commit/46d38e5); verified by `places_summary.test.ts` and on the phone (issue closed after use)
- **Issues:** [#40](https://github.com/idvorkin/context-grabber/issues/40)

#### Use Case:
- **As** someone who saw "8h" on a sixteen-hour day
- **I want to** see each day as bars for its places plus a transit row and a no-data row that sum to the elapsed day, with a colour strip of the day in time order
- **so that** I can tell "I was moving" from "my phone wasn't tracking"

#### Acceptance Criteria:
- **Scenario:** A day with a dead-phone gap
- **Given:** Home till 8 am, a drive with GPS, Office, then nothing from 6 pm
- **When:** I open the Places tab
- **Then:** the day card's header reads the elapsed hours (24h for past days, hours-so-far for today), the rows are Home, Office, "—transit—" and "—no data—" summing to the header within a minute, the strip above them shows the same segments in order with the unlived part of today dimmest, a stay across midnight is split between the two days, and tapping the card expands the visit detail

---

### User Story 047:

- **Summary:** Name an unknown place from the breakdown, or grow the known place it belongs to
- **Status:** implemented in [5d920bc](https://github.com/idvorkin/context-grabber/commit/5d920bc), [75ec6f5](https://github.com/idvorkin/context-grabber/commit/75ec6f5), [34f7e70](https://github.com/idvorkin/context-grabber/commit/34f7e70); verified by `places.test.ts` (the merge circle) and `places_summary.test.ts`, checked against the real fixture (the 500 m gate catches "Place 2", 160 m from Milstead), and on the phone

#### Use Case:
- **As** someone looking at "Place 3" in amber for the third day running
- **I want to** tap it and either name it or be offered the known place it is near, with the exact new radius and centre shift shown
- **so that** repeat visits stop being anonymous without me copying coordinates into a form

#### Acceptance Criteria:
- **Scenario:** A stay 168 m from a known café
- **Given:** "Milstead & Co" is known with a 50 m radius
- **When:** I tap Name on that day's Place 3 row
- **Then:** a card says the stay is 168 m from Milstead & Co and that expanding would grow its radius 50 m → 159 m and shift its centre 57 m, with Expand / Create new place / Cancel; Expand relabels every Place 3 stay on every day, Create new asks for a name and radius (default 100 m), and a stay farther than 500 m from everything goes straight to the name card

---

### User Story 048:

- **Summary:** A real map with my places on it, each in its own colour
- **Status:** implemented in [4cb8641](https://github.com/idvorkin/context-grabber/commit/4cb8641), [ac11088](https://github.com/idvorkin/context-grabber/commit/ac11088), [dc781bb](https://github.com/idvorkin/context-grabber/commit/dc781bb), [48c9372](https://github.com/idvorkin/context-grabber/commit/48c9372); verified by `StylizedMap.test.tsx` and on the phone (daily use)

#### Use Case:
- **As** someone who recognises streets faster than coordinates
- **I want to** see Apple Maps tiles with a pin per known place, the same colour as its bar in the breakdown, a house / briefcase / barbell icon where the name gives it away, and me as a cyan diamond
- **so that** the day's geography is readable at a glance and the map and the breakdown speak the same colour language

#### Acceptance Criteria:
- **Scenario:** Opening Places
- **Given:** Home, Office and Gym are known and I am at the gym
- **When:** I open the Places tab
- **Then:** the map shows streets and water with a 🏠, 💼 and 🏋️ pin each ringed in its place colour, unnamed places as a coloured dot with a name chip, a "You" diamond with a halo, the map framed to include every pin and the path, free to pan and zoom; the Today tab's map shows only the places visited today

---

### User Story 049:

- **Summary:** Today's path follows where I actually went
- **Status:** implemented in [067a04e](https://github.com/idvorkin/context-grabber/commit/067a04e), [c7b768c](https://github.com/idvorkin/context-grabber/commit/c7b768c); verified by `location.test.ts` (route thinning) and on the phone
- **Issues:** [#42](https://github.com/idvorkin/context-grabber/issues/42)

#### Use Case:
- **As** someone who walked the long way round the lake
- **I want to** see the day's line trace the recorded GPS trail rather than straight hops between place pins
- **so that** the line means "the route", and three places no longer draw a triangle across the city

#### Acceptance Criteria:
- **Scenario:** A day with a walk between two places
- **Given:** a dense trail of points along the lake path
- **When:** I look at the Today or Places map
- **Then:** the polyline follows the curve of the path, thinned so panning stays smooth, a gap where GPS went quiet is one straight segment between the last and next real points, and a day with one point draws no line

---

### User Story 050:

- **Summary:** Find me, and go fullscreen
- **Status:** implemented in [b11dafc](https://github.com/idvorkin/context-grabber/commit/b11dafc), [d190517](https://github.com/idvorkin/context-grabber/commit/d190517); verified by `StylizedMap.test.tsx` and on the phone (issues closed after use)
- **Issues:** [#50](https://github.com/idvorkin/context-grabber/issues/50), [#51](https://github.com/idvorkin/context-grabber/issues/51)

#### Use Case:
- **As** someone who panned off to look at the route
- **I want to** snap back to my position at street zoom with one tap, and blow the map up to the whole screen
- **so that** the small embedded map is enough most of the time and never a trap

#### Acceptance Criteria:
- **Scenario:** Lost on the map
- **Given:** I dragged far away and zoomed out
- **When:** I tap the locate control
- **Then:** the camera animates to centre "You" at neighbourhood zoom with pins and path untouched; the expand control opens a fullscreen map framed to its content with the same pins, path, locate and copy controls, and the collapse control or a swipe down returns to the embedded map; with no current location the locate control is hidden

---

### User Story 051:

- **Summary:** Copy my coordinates from the map itself
- **Status:** implemented in [fb33625](https://github.com/idvorkin/context-grabber/commit/fb33625), [c95247c](https://github.com/idvorkin/context-grabber/commit/c95247c), [d190517](https://github.com/idvorkin/context-grabber/commit/d190517); verified on the phone

#### Use Case:
- **As** someone sending "meet me here"
- **I want to** tap a small copy glyph on the map and get full-precision coordinates
- **so that** the standalone coordinates card is unnecessary and the map stays the whole story

#### Acceptance Criteria:
- **Scenario:** Sharing my spot
- **Given:** the map shows a "You" pin
- **When:** I tap the copy control in the map's corner
- **Then:** the clipboard holds "lat, lng" to six decimals, a "✓ Copied" confirmation shows briefly, and the control never blocks tapping a pin

---

### User Story 052:

- **Summary:** Export the whole database for my own tools
- **Status:** implemented in [98c26d2](https://github.com/idvorkin/context-grabber/commit/98c26d2), [95521bf](https://github.com/idvorkin/context-grabber/commit/95521bf), [363c94f](https://github.com/idvorkin/context-grabber/commit/363c94f); verified by the Maestro flow `export-db.yaml` and on the phone (the test fixture came out of it). Supersedes DB-4.
- **Issues:** [#18](https://github.com/idvorkin/context-grabber/issues/18)

#### Use Case:
- **As** an engineer who wants to run SQL on my own trail
- **I want to** share the SQLite file from the Location sheet
- **so that** clustering rules can be checked against real data on a Mac

#### Acceptance Criteria:
- **Scenario:** Pulling the database
- **Given:** the Location sheet is open
- **When:** I tap Export Database
- **Then:** the iOS share sheet offers the `.db` file with locations, settings, known places and the health caches, and the button shows a status while it prepares

---

### User Story 053:

- **Summary:** The Location sheet shows structure, not a debug dump
- **Status:** implemented in [432ef9c](https://github.com/idvorkin/context-grabber/commit/432ef9c), [46d38e5](https://github.com/idvorkin/context-grabber/commit/46d38e5); verified on the phone

#### Use Case:
- **As** someone opening the sheet for the copy buttons
- **I want to** see the coordinates card with its three copy actions, the known places editor and Export Database, and nothing in Courier
- **so that** the sheet reads as controls, while the day-by-day story lives on the Places tab

#### Acceptance Criteria:
- **Scenario:** Opening the sheet
- **Given:** location history exists
- **When:** I tap "Manage places · history · export" on Places
- **Then:** the sheet shows the current location with point count and Copy Coordinates / Copy Daily Summary / Copy Location Details, the Known Places editor, and Export Database, with no raw summary paragraph; the per-day breakdown is on the Places tab, not here

---

### User Story 054:

- **Summary:** Today's path on the home screen
- **Status:** not implemented; asks: [#45](https://github.com/idvorkin/context-grabber/issues/45), [#42](https://github.com/idvorkin/context-grabber/issues/42). Needs a native build (a MapKit widget).

#### Use Case:
- **As** someone glancing at the lock screen
- **I want to** see today's route and places on a widget without opening the app
- **so that** "where did today go" is ambient

#### Acceptance Criteria:
- **Scenario:** Glancing mid-afternoon
- **Given:** the widget is on the home screen and today has three stays
- **When:** I look at it
- **Then:** it shows today's path with the visited places pinned, refreshed within a few minutes of a new stay
