# Gym Timer — Accessory Work Log

## Summary

Let the user log accessory / mobility work (Half Lotus, McGill Big 3, Pigeon
Stretch, Dead Hangs) from the Gym Timer screen after a workout, persist it
locally, and surface it in the Context Grab summary export so the AI life coach
sees which mobility work actually happened.

## Problem

The Gym Timer runs the main workout (rounds / stopwatch / sets), but the small
accessory and mobility pieces done alongside it — a minute of half lotus, the
McGill Big 3, a pigeon stretch, dead hangs — leave no trace anywhere. There is
no record that they happened, so the coaching layer can't tell a day that
finished with mobility work from one that skipped it, and the user has nothing
to look back on.

## Goals

- From the Gym Timer screen, the user can open a short checklist of accessory
  items and mark which ones they did.
- Saving records the checked items with a timestamp into the app's local store,
  so the record survives app restarts.
- The logged accessory work rides along in the "Grab Context" summary export,
  each entry carrying the item name, an ISO timestamp, and the session date.
- The item list is easy to edit later (add / rename items) in one place.

## Non-Goals

- Per-rep counts, durations, sets, or weights for accessory items — a plain
  "I did this" toggle is enough.
- Editing or deleting a past accessory-log entry from the UI.
- Any change to the main timer behavior (rounds / stopwatch / sets), the Live
  Activity / Dynamic Island lifecycle, keep-awake, deep links, or presets.
- Cross-device sync of the accessory log (local-only for now).
- The timer's paused indicator — that is the LED display spec's
  (`2026-09-07-gym-timer-led-display-design.md`, *Paused*).

## Behavior

On the Gym Timer screen there is a clearly-labeled, always-available "Log
Accessory Work" button, placed in the screen's footer area above the mode
switcher so it is reachable in every mode (rounds / stopwatch / sets) rather
than only on timer completion.

Tapping it opens a checklist of accessory items:

- Half Lotus
- McGill Big 3
- Pigeon Stretch
- Dead Hangs

Each item is tap-to-toggle between unchecked and "done". The list starts with
nothing checked each time the sheet opens. A **Save** action records only the
items currently checked, stamped with the moment of saving, and dismisses the
sheet. A **Cancel** action dismisses without recording anything. Saving with
nothing checked records nothing and simply closes.

The recorded entries persist locally and survive app restarts. Saving shows a
brief confirmation on the button.

**Seeing what was logged.** Under the checklist, the same sheet lists the
recent log — the same seven-day window the coaching export carries, so what
the user sees is what the coach sees. Entries are grouped by day, newest day
first, headed *Today*, *Yesterday*, or the weekday and date (*Tue Sep 8*);
under each day, one line per save, with the wall-clock time and the items
saved together on it (*3:12pm · Half Lotus, Dead Hangs*). Nothing logged in
the window reads *Nothing logged in the last 7 days*. The list is read-only —
there is no editing or deleting from it (a non-goal above). It is fresh on
every open, so a save shows up the next time the sheet opens. If the log
cannot be read, the sheet still offers the checklist and shows the failure
through the copyable error affordance.

When the user runs "Grab Context" and shares the summary, the summary payload
includes the accessory work logged in the recent (7-day) window. Each entry
carries the item's display name, an ISO-8601 UTC timestamp of when it was
logged, and the local session date (YYYY-MM-DD). When nothing has been logged
in the window, the summary carries an explicit empty/absent accessory section
rather than omitting the concept.

If saving the log fails, the failure is shown through the standard copyable
error affordance (never a bare red string), so the user can copy a debuggable
payload.

## Acceptance criteria

- The Gym Timer screen shows a "Log Accessory Work" button in all three modes.
- Tapping it opens a checklist with exactly Half Lotus, McGill Big 3, Pigeon
  Stretch, and Dead Hangs, all initially unchecked.
- Toggling an item flips its checked state; toggling again clears it.
- Save with two of four items checked records exactly those two, each with a
  timestamp; the other two are not recorded.
- Save with nothing checked records nothing and closes the sheet.
- After saving and relaunching, a subsequent Grab Context summary still lists
  the previously logged items (persistence survives restart).
- A Grab Context summary export contains an accessory section; for each logged
  item it lists name, ISO timestamp, and session date.
- Existing timer behavior (rounds / stopwatch / sets), Live Activity, keep-awake,
  deep links, and presets are unchanged.
- A save failure is rendered via the copyable-error affordance.
- With nothing logged in the last 7 days, the sheet says so under the
  checklist.
- After saving Half Lotus and Dead Hangs and reopening the sheet, a *Today*
  group lists one line with the save's wall-clock time and both names; an
  entry from eight days ago is not listed.
- Two saves on the same day are two lines under one day heading, newest
  first; yesterday's save is under *Yesterday*; older days carry their
  weekday and date.
- A read failure leaves the checklist usable and shows a copyable error.

## Rationale

The accessory items are mobility/recovery work the coaching layer cares about
but that the timer never captured. A minimal tap-to-toggle checklist keeps the
friction low enough that it actually gets used after a workout, while a stable,
single-source item list keeps the set easy to evolve. Persisting locally and
folding the log into the existing summary export means the data reaches the
coach through the channel that already exists, with no new plumbing on the
receiving side. The button is persistent rather than gated on timer completion
because gating would tie it to rounds-mode's internal completion state and make
it unavailable in stopwatch/sets mode; a persistent button is simpler, works
everywhere, and matches the "a persistent, clearly-placed button is fine" call.
