# Everything off the phone: the stats archive — Design Spec

Bead context-grabber-3il. Igor, Cockpit chat 2026-10-19: *"let's archive all the stats we can do it every four hours.
Be sure to Delta stamp them somehow so we don't get duplicates. Should work for history as a one off, and then as
habits happen. Then maybe final daily batch. Since all guid marked no duplicates."* Part of the
[Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The phone keeps its location trail thirty days and reads Health only when Today looks. Everything Grabber Native
collects now goes, on its own, to a permanent archive on the Cockpit (its story 124): the trail's points, every
Health sample type the mirror reads and the daily strip's days, a few hours' worth at a time, the whole history the first time. Nothing is
ever there twice.

## Goals

- Every record the app collects is in the archive within a few hours of being collected, without Igor doing
  anything, and losing or replacing the phone loses none of it.
- The first run sends the whole history Health and the trail hold, in pages, over as many runs as it takes.
- A record is archived once: a lost answer, an overlapping page, a re-imported trail or a reinstall never doubles
  it.
- Deletions reach the archive too (a sample Health removed is marked, not silently absent).
- The daily strip's days are archived too (story 271; Igor, 2026-10-19: *"Did it include when I did balloons and
  magic, not just health?"*): gym, meditation, journal, balloons and magic, each day's value as the strip shows it,
  every device's taps included.

## Non-goals

- A screen: the archive is silent. What it did is in the session log; a later story may add a line to Settings.
- The activity log and the accessory log (a follow-up stream each). So the gym and meditation days the strip turns
  green from a finished Gym Timer workout or a Box breathing session are not in the strip's streams; a day Health
  counts is already in Health's own streams.
- Health's free-form metadata, workout routes, or samples of types the mirror does not read.
- Reading the archive back on the phone.

## What Igor sees

Nothing, by design. With the Cockpit reachable, the app sends what is new every four hours or so, once more when
it comes to the front after that long, and once at the end of the day; a first run after install sends history in
pages, carrying on across runs until it is caught up. Off the tailnet, nothing is sent and nothing is lost: the
next run picks up exactly where the last successful page ended. Health is never asked for access by the archive;
Today asks, and until it has, only the trail and the strip are archived. While the phone is locked Health cannot be
read, so a run then sends only the trail and the strip, says so once, and the next time the app comes to the front Health's share goes. On the simulator nothing is sent unless a launch hook
names where.

**The trail is never pruned ahead of the archive.** The phone's retention (thirty days unless Igor lowers it) deletes
an old point only once the archive has taken it. If the Cockpit is out of reach for longer than the retention, or it
refuses a page, the points it has not taken stay on the phone, however old, until it has; the prune's log line says
how many it kept. On a simulator with no archive to send to, retention prunes by age alone.

## The daily strip

Each strip item is its own stream. A day's value can change long after the day itself: a tap just before midnight,
an earlier day marked by press and hold, a counter's week edited, or another device's taps arriving over iCloud
days later. The archive keeps the first copy of anything it is sent, so a strip record is never "the day" but one
observation of it: the day, the item, its value as the strip showed it then (counts added up across devices, a
check's latest change), and when the phone saw it. **The newest observation of a day is that day's value.**

- The first run sends every day the strip has ever counted; later runs send only the days whose value changed
  since the archive last heard about them, whenever that day was.
- A day taken back to nothing (a check un-ticked, a count stepped down to 0) is sent as 0, so the archive does not
  keep the old value as the newest.
- A value that goes 3 → 2 → 3 is three observations, and the last one wins.
- A lost answer can leave two observations with the same value; that changes nothing about which value wins.
- Each device sends its own view of the strip. Until a device has heard the others over iCloud, its view can be
  short of their taps, and its newer observation wins until the synced one follows.

## Explaining itself

- Each page sent is logged (`archive`, action page, with the stream, how many records, how many the Cockpit
  inserted and how many it already had — never a record).
- A page the Cockpit refuses (4xx) stops that stream with the reason in the log (`archive` refused); an unreachable
  Cockpit stops the run (`archive` failed) and the same page goes next time.
- Each run ends with one line (`archive_run`: the streams, pages, records, counts and why any stream stopped).

## Acceptance criteria

- With the Cockpit reachable and Today having asked for Health, a fresh install's first runs send every point in
  the trail and every Health sample of the mirror's types, in pages, and the Cockpit's counts show each record
  inserted exactly once; a second pass over the same history inserts nothing.
- Four hours after a run, with the app in the background, a refresh run sends what came since; the log shows it.
- A run while the phone is locked sends the trail and the strip, logs one line saying Health was skipped, and does not count as
  a run: the app's next time in front runs again and sends Health's share.
- A daily batch delayed past midnight keeps its pending slot across refreshes and launches until it runs.
- An import that rolls back cannot contribute archived points or advance the archive past those points.
- Launching the app remains safe before the first archive run, including when an existing database is upgraded.
- A simulator sends archive data only to an explicitly supplied test destination; without one it sends nothing.
- With the Cockpit unreachable, a run stops at its first page with the reason, and the next reachable run sends
  that page again, which the Cockpit counts as new (not duplicate) the first time and duplicate thereafter.
- A trail imported from a Context Grabber export sends its points, and the Cockpit counts the ones it already had
  as duplicates.
- After the first run, the archive holds every day of balloons and magic (and every gym, meditation and journal
  check) with the value the strip shows; a run with no strip change sends nothing for the strip.
- Two balloons added to yesterday from the counter's week, or a day's taps arriving from the iPad, reach the
  archive on the next run as a newer observation of that day, and the newest observation per day matches the
  strip.
- A check un-ticked after it was archived reaches the archive as 0.
