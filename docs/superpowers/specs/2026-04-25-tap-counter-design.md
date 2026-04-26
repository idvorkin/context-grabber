# Tap Counter — Design Spec

## Summary

Add a single, label-free, daily-resetting "+1" counter that's tappable from both the main app screen and the iOS Home Screen widget. Each tap increments the count by one. The counter renders as classic tally marks in a handwritten font — the visual cue that this is a quick-and-disposable tally, not a precision tracker. Resolves the counter half of GitHub issue #29.

## Problem

Igor wants a one-tap way to log "I did a thing" — squats, gratitudes, magic-trick attempts, balloons, whatever pattern emerges. Every existing logging path requires a context switch: open a note app, type, save. The dashboard has the right surface (always-on, glance-friendly) but no incrementing affordance. And once you have a counter, the most painful friction is *opening the app* every time you want to bump it — so the iOS Home Screen widget needs to do +1 directly when iOS supports interactive widgets.

The 5-min meditation timer (the other half of issue #29) is a separate, independent feature and not in scope here.

## Goals

- One-tap +1 from the main dashboard.
- One-tap +1 from the Home Screen Today widget (iOS 17+) without launching the app.
- Tally-mark visual rendering (4 strokes + diagonal slash for groups of 5) in a casual handwritten font.
- Daily reset at local midnight — the count is "what I did today."
- Manual reset button on the main view for "I'm starting over" / "I miscounted."
- Counter value flows into the daily JSON export so the AI coach can see the day's tally.
- Reuses the existing App Group bridge that powers the widget's other live data.

## Non-Goals

- No counter label / settings (the user said "no label"; pattern hasn't emerged yet, defer configurability).
- No multiple counters with a picker (one is the v1; multi-counter is its own design).
- No historical record (yesterday's count, weekly totals, charts) — daily reset overwrites; future feature can add an event log if needed.
- No reset on the widget (would be too tap-prone; daily auto-reset covers most of the need).
- No HealthKit integration (a counter isn't a HealthKit type).
- No Android — iOS-only widget.

## User-Visible Behavior

### Main dashboard

Add a new compact "counter card" or header chip showing:

```
║║║║̸ ║║║║̸ ║║║   24
                ↺
```

- Tally marks: classic 5-mark groupings (4 vertical strokes + diagonal strike for the 5th). Wraps to a second line if it gets too wide.
- The number is shown alongside in a casual handwritten font (e.g. iOS-bundled "Marker Felt" or "Bradley Hand"). Display the digit even when the tally pattern reads it perfectly — it's faster to glance.
- Tapping the card increments the count by one with a brief haptic; tally and number redraw immediately.
- A small `↺` reset glyph next to the count: single tap presents a confirmation ("Reset to 0?") then resets. No accidental destructive action.
- When the count is `0`, the card still shows the affordance (same chip, just `0` and no marks) so the tap target remains discoverable.

### Daily reset (local midnight)

When the app foregrounds, if today's local date differs from the date the counter was last reset, set value to 0 and update the reset date. This catches reset on app open after midnight regardless of how the user got there (cold launch, deep link, widget tap).

### Manual reset

Tap the `↺` button → small inline confirm prompt or system Alert ("Reset count to 0?" / Cancel · Reset). On confirm: value = 0, redraw, push to widget.

### Home Screen Today widget

Add a counter row to the existing Today widget. Layout (medium widget, integrated):

```
┌────────────────────────────────────────┐
│  Today · Sat                       →   │
│  8,241 steps · 7.4h sleep · 35m ex     │
│  ──────────────────────────────────    │
│  ║║║║̸ ║║║║̸ ║║║   24              [+1] │   ← new counter row
│  ──────────────────────────────────    │
│  ⏱  Timer       1 MIN     5-1          │
└────────────────────────────────────────┘
```

- Tally marks + number render the same way as on the main view.
- **iOS 17+:** the `[+1]` zone is a Button bound to an App Intent. Tapping increments the counter in shared App Group storage and reloads the widget timeline. The app does *not* launch.
- **iOS 16 and older:** the `[+1]` zone is a Link to a `grabber://counter/inc` URL — tapping launches the app, which performs the increment and stays open. (Functional fallback; less elegant, but still one tap.)
- **Tapping the number** (the `24` text) is a Link to `grabber://main` — opens the app to the dashboard so the user can review or reset.
- The widget never displays a "reset" affordance.

### JSON export

Each `DailyExportEntry` gains:

```ts
counter: number | null;  // today's count, null if counter has never been incremented
```

Only the value is exported — no label, no reset history. The AI coach gets a single `counter: 24` field per day.

## Acceptance Criteria

- Tapping the counter card on the main view increments the displayed value by one within 100ms.
- Tally rendering shows 5-stroke groups (4 vertical + 1 diagonal slash) and matches the displayed number.
- The number uses a clearly handwritten-style font, distinct from the rest of the UI (which is sans-serif).
- Tapping `↺` and confirming sets the value to 0; the tally clears.
- Closing the app at 11:30 PM with count = 24, opening at 12:30 AM the next day shows count = 0 — without any user action between.
- On iOS 17+, tapping the `+1` zone of the Today widget increments the count visible on the widget within 1 second, and the app is *not* foregrounded.
- On iOS 16, tapping the `+1` zone launches the app, the count is incremented, and the user lands on the main dashboard.
- Tapping the number on the widget always launches the app to the main dashboard.
- The JSON export's "today" entry includes a `counter` field whose value matches whatever the dashboard shows at export time.
- Resetting on the main view (or daily auto-reset) reflects in the widget within ~5 seconds.

## Rationale

**Why App Group UserDefaults instead of SQLite?** The widget can't reach SQLite, and dual storage requires sync logic. UserDefaults is the natural shared-storage primitive for widgets, and the counter is fundamentally ephemeral (resets daily). A future "history of counts over time" feature can layer SQLite on top without breaking this.

**Why no label in v1?** Issue #29 mentions multiple possible uses ("squats, gratitudes, magic tricks") but Igor said the pattern hasn't emerged. Locking in a label now would either be wrong or quickly need migration. Shipping unlabeled is faster and more honest about the current state.

**Why a reset button if there's already a daily auto-reset?** Daily reset doesn't help when the user miscounts mid-day or wants to restart for a different purpose ("I was counting squats this morning, now I want to count gratitudes tonight"). The reset button is a release valve, not a primary affordance — hence the small `↺` and the confirm prompt.

**Why interactive widget on iOS 17+ but Link fallback on 16?** App Intents require iOS 17. We don't want to drop support for older iOS just for this feature. The fallback is functional (launch + increment), just less elegant.
