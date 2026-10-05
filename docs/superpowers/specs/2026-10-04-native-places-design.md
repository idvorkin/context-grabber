# Native Places: the trail, the stays, the map — Design Spec

**Status:** Drafted 2026-10-04 (Igor: "how about location?" — Places is the next journey to move)
**Owner:** Igor
**Tracking:** bead `context-grabber-3ss` (the native port, step 5); stories [040–055](../../stories/03-places.md)
**Part of:** [Swift-native app](2026-10-04-swift-native-app-design.md). The rules the stays follow are unchanged
from [location clustering v2](2026-03-26-location-clustering-v2.md), the day accounting and naming from
[places breakdown](2026-04-11-places-breakdown-gaps-and-naming-design.md), the map from
[map controls](2026-05-31-map-controls-design.md) and [real route](2026-05-31-map-real-route-design.md).

## Summary

Grabber Native gets a **Places** screen that does what the Places tab and the Location sheet do in Context
Grabber: an opt-in trail recorded in the background, read back as stays at named places, a 24-hour strip and
bars per day that add up, a real map with the places and today's path, and the database export. The rules that
turn breadcrumbs into stays are the same, so the same trail gives the same stays, place names and hours in both
apps.

Until the cutover each app keeps its own trail. The native app therefore starts empty, and can **import** a
database exported from Context Grabber to bring the history and the known places across.

## Goals

- Every Places story that Context Grabber implements (040–053) holds in the native app.
- For the same trail and known places, the native app's stays, place names and per-day hours equal the current
  app's — checked against the real 36 000-point fixture, not only invented cases.
- History and known places come across from Context Grabber in one step, and doing it twice changes nothing.
- A problem with tracking can be answered from the session log: whether permission was given, whether tracking
  was on, when points arrived, what was pruned, what an import or export did.

## Non-goals

- Today's path on the home screen (story 054): a widget, so it waits for the widgets step.
- The Today tab's small map and Grab Context's location sections: the mirror and the export (step 4).
- Changing the clustering rules. Requests that come up become stories and wait.
- Syncing the two apps' trails. Import is a one-way copy, on demand.

## What Igor sees

### Home

The home screen lists **Places** under "Ported so far". It opens full screen; *Done* returns home.

### The Places screen, top to bottom

1. **The map** (stories 048–051): Apple Maps streets, a pin per known place ringed in the place's colour, a house,
   briefcase, barbell, cup or mortarboard where the name gives it away and a coloured dot with a name chip
   otherwise; **You** as a cyan diamond with a halo; today's recorded path as a line. It is framed to include
   every pin and the path, and free to pan and zoom. Three small controls sit in its corners: **locate** (centre
   on You at neighbourhood zoom; hidden with no fix), **copy** (puts "lat, lng" to six decimals on the clipboard
   and shows "✓ Copied" briefly), **expand** (the same map full screen, with the same controls; collapse or a
   swipe down returns).
2. **The last seven days**, newest first (stories 043, 044, 046, 047). Each day is a card: the date and the
   elapsed hours (24h for a past day, hours so far for today); a strip of the day in time order — stays in their
   place's colour, transit faded, no data grey, the rest of today dimmest; then a bar per place (longest first,
   at most ten), a *—transit—* row and a *—no data—* row, which together add up to the header within a minute.
   A tap on the card shows each visit with its times. A day with neither a stay nor a point is left out.
   An unnamed place reads "Place N" in amber with a **＋** that names it (below).
3. **Known places** (story 045): each with its colour, coordinates and radius; swipe to delete. **Add place**
   takes a name, a radius (100 m by default) and the position: *Use current* asks for a precise fix and refuses
   one older than thirty seconds with a line saying how old it was. **Import places** accepts the same JSON as
   today (an array, or an object with `knownPlaces` / `places`; `lat`/`latitude`, `lon`/`lng`/`longitude`,
   `radiusMeters`/`radius_meters`/`radius`).
4. **Tracking** (stories 040, 041): the Background Tracking switch, retention in days, the number of points
   stored and the permission as iOS reports it.
5. **History and export** (stories 052, 053, 055): *Copy daily summary* (one line per day: "Mon Apr 20: Home 9h,
   Office 8h, Gym 1h"), *Export database*, *Import from Context Grabber*.

### Naming a place (story 047)

The **＋** on a "Place N" row looks for known places within 500 m of that stay's centre. With none, a card asks
for a name and a radius (100 m) and shows the coordinates. With one or more, a card says how far the nearest is
and what growing it would do — "Place 3 is 168 m from Milstead & Co. Expanding would grow radius 50 m → 159 m and
shift the centre 57 m." — with **Expand**, **Create new** and **Cancel**, and "(+N more within 500 m)" when there
are others. Either way every stay at that place, on every day, is relabelled at once.

### Background tracking (story 040)

Off on a fresh install. Switching it on asks for location While Using, then Always. With Always granted the app
records points while it is in the background and after it has been closed, and the switch stays on across
launches. Without Always — denied, or only While Using — the switch goes back off and a line under it says what
iOS allowed and that Settings is where to change it; nothing is recorded. Switching it off stops recording at
once; the points already stored stay.

While tracking is on iOS shows the blue location indicator when the app is in the background, as Context Grabber
does: a trail being recorded is never invisible.

### Retention (story 041)

Thirty days by default, from 1 to 365. Points older than the retention are deleted when the app comes to the
front and immediately when the number is lowered; the breakdown and the point count follow.

### The precise fix (story 042)

Each time the app comes to the front it asks for one precise fix; the map's You moves to it when it arrives. The
fix is only for You and for *Use current*; it is not added to the trail.

### Export (story 052)

*Export database* offers the app's whole database file in the share sheet — locations, known places, settings,
and whatever other journeys have stored — named `context-grabber.db`, the same name and format Context Grabber
exports. The button says what it is doing while it prepares the file. The copy is a consistent snapshot even if a
point arrives while it is made.

### Import from Context Grabber (story 055)

The way in is the file Context Grabber's *Export Database* produces. Igor can either

- share it from Context Grabber (or from Files) and choose Grabber Native, or
- tap *Import from Context Grabber* and pick the file in Files.

The app copies in that file's locations and known places and says what it did: "Imported 36 601 points (0
already here) and 4 places (0 already here)." Doing it again adds nothing — a point already present (same time,
same coordinates) is skipped, and so is a known place whose name is already taken here (the native one is kept:
it may have been grown since). Settings, the tracking switch and other journeys' data are not imported. A file
that is not a Context Grabber database is refused with a line saying why, and nothing changes. Imported points
older than the retention are pruned like any others, so an old export brings back only what retention allows.

## Differences from Context Grabber while both live side by side

- **Two trails.** Each app records its own; with both switched on the phone records twice (the battery risk in
  the parent spec). Import is the bridge until the cutover, when the native app opens Context Grabber's database
  in place and there is one trail again.
- **Tracking survives the app being closed.** Context Grabber's trail stops when iOS terminates the app and
  resumes only when Igor opens it. The native app also asks iOS to wake it on a significant move, and resumes
  the trail from there.
- **Day boundaries follow the calendar.** On the two days a year the clocks change, a day is 23 or 25 hours long
  and its strip and header say so; Context Grabber cuts every day at exactly 24 hours, so on those days its
  breakdown is off by an hour.
- **One screen.** The Places tab and the Location sheet are one screen; the three "copy" actions become the map's
  copy control and *Copy daily summary*. *Copy Location Details* (the export's location section as JSON) waits for
  Grab Context in step 4.
- **Errors** are on screen in plain words and in the session log with the state around them; a shake attaches
  the log.

## Rationale: how the trail is recorded

| Option | What it gives | Why not alone |
|---|---|---|
| Standard updates, ~100 m accuracy, no distance filter, never auto-paused (what Context Grabber does) | a dense trail while moving: the stays' hundred-metre radius and the transit / no-data split (a run of points less than ten minutes apart) are tuned on exactly this | stops for good when iOS terminates the app |
| Significant-change monitoring | wakes a terminated app after a move of roughly 500 m; cheap | one point per few minutes and hundreds of metres: too coarse to make stays or a route on its own |
| Visits | arrival and departure at a place, cheap | delivered minutes to hours late, as summaries, not points; the stays are already derived from points |
| Fine accuracy with a distance filter | a crisper route | more battery for nothing the stays need; a different input than the rules were tuned on |

**Chosen:** standard updates exactly as Context Grabber records them — so the same rules see the same kind of
trail — plus significant-change monitoring, so that a terminated app is woken and the standard updates resume.
Visits are not used.

**When the phone sits still, iOS sends nothing** (motion coprocessor), so a night at home is a few points in the
evening and a few in the morning. This is expected, and the clustering already joins consecutive stays at the
same place across such a gap (story 044). More frequent collection would not help and is not attempted.

## Acceptance criteria

- With tracking off on a fresh install, no points are stored and no location permission is asked for until the
  switch is touched.
- Switching tracking on and allowing Always records points with the app in the background; denying leaves the
  switch off with a line under it; the switch's state survives a relaunch.
- Lowering retention from 30 to 7 deletes the older points at once; the point count and the breakdown follow.
- For the fixture trail and its four known places, the native stays (place, start, end, points) equal Context
  Grabber's, and so do the seven-day breakdowns.
- Every day card's place, transit and no-data rows add up to its header within a minute.
- Naming "Place N" relabels every stay at that place; expanding a known place shows the new radius and centre
  shift before it is applied.
- Importing the fixture export brings in all its points and its four places; importing it again adds none.
- A file that is not a Context Grabber database is refused and nothing changes.
- The exported file opens as SQLite on the Mac with the same tables Context Grabber's export has for locations,
  known places and settings.
- The map shows the known places in the same colours as their bars, You, and today's path; locate, copy and
  expand work as described.
- Each of these leaves its event in the session log: permission, tracking on and off, points arriving (sampled),
  pruning, import, export, opening the screen.
