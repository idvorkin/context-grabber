# Deep Links + Home-Screen Widget — Design Spec

## Summary

Add a URL-scheme-based deep-link system so the app can be launched directly into the Gym Timer (optionally with a preset selected and the timer auto-started) or into the main dashboard (optionally auto-triggering a Grab Context). Then ship an iOS Home Screen widget ("Design B") that renders today's health snapshot alongside tap zones that use those deep links — one main tile, and two timer tiles (1 MIN, 5-1) that open the app and start the timer on tap.

## Problem

Today, the app has a gym timer with Live Activity / Dynamic Island support, but:

1. **Tapping the Live Activity wakes the app without routing anywhere** — the Swift side already passes a `deepLinkUrl` through `widgetURL()`, but the JavaScript side has no inbound handler, so the user lands wherever the app happened to be.
2. **No home-screen shortcut for "start a 1-minute timer right now."** The user has to open the app, navigate to the gym timer screen, pick the preset, and press START. That's four taps for a recurring micro-workflow.
3. **No at-a-glance health widget.** Checking today's step count or sleep hours requires launching the full app.

## Goals

- One tap on a home-screen icon opens the gym timer with a preset pre-selected AND the timer running. ("Start a 1-minute timer" = one tap.)
- One tap on a home-screen icon triggers Grab Context without further input.
- Tapping the existing Live Activity / Dynamic Island routes to the correct screen (not just "wakes app and stops").
- A home-screen widget shows today's steps / sleep hours / exercise minutes, refreshed whenever the app does a Grab Context.
- Widget also exposes three deep-link tap zones: top card → main, 1 MIN tile → timer + auto-start, 5-1 tile → timer + auto-start.
- URL scheme works identically whether the app is cold-launched from the URL, resumed from background, or already foregrounded.

## Non-Goals

- No Siri-intent, App Shortcuts, or voice triggers beyond what's needed for the URL scheme to be valid.
- No widget background refresh beyond "whatever snapshot the app last wrote." iOS throttles widget reloads aggressively and the user's mental model ("what I last saw when I grabbed") is simpler.
- No per-screen staleness indicators on the widget — em-dash for missing data is enough.
- No new timer presets or timer behavior changes.
- No Android widget (this is an iOS-only app).
- No universal links (HTTPS-based app links) — the custom scheme is sufficient since the widget and Shortcuts can both use it.

## User-Visible Behavior

### URL scheme

Two schemes both work — pick whichever is more convenient for the context:

- **`com.idvorkin.contextgrabber://…`** — the existing bundle-ID-format scheme, kept for Live Activity compatibility and for anything already using it.
- **`grabber://…`** — new short alias, preferred for anything the user types or configures manually (Shortcuts app, Safari, test URLs).

### Routes

| URL path + query | Effect |
|---|---|
| `grabber://` or `grabber://main` | Open main dashboard. |
| `grabber://grab` | Open main dashboard + automatically trigger a Grab Context. |
| `grabber://timer` | Open Gym Timer, rounds mode, keeping whatever preset was last selected. |
| `grabber://timer?preset=<id>` | Open Gym Timer, rounds mode, with the given preset selected (`30sec`, `1min`, `5-1`). Unknown preset IDs are ignored (falls back to last selection). |
| `grabber://timer?preset=<id>&autostart=1` | Same as above, plus the timer's START button is pressed automatically on arrival. |
| `grabber://timer/stopwatch` | Open Gym Timer in stopwatch mode. |
| `grabber://timer/sets` | Open Gym Timer in sets mode. |
| Any other / malformed URL | Open main dashboard (silent fallback, no error toast). |

Cold launch and warm launch are identical in behavior. If the app is launched via URL when it was already grabbing context, the grab completes normally and the URL action applies to the post-grab state.

### Home Screen widget (Design B, medium / 2×4)

```
┌────────────────────────────────────┐
│  Today · Mon                   →   │
│                                    │
│  8,241 steps   ·   7.4h sleep      │
│  35 min exercise                   │
│  ────────────────────────────────  │
│  ⏱          ┌─────┐   ┌─────┐      │
│  Timer      │1 MIN│   │ 5-1 │      │
│             └─────┘   └─────┘      │
└────────────────────────────────────┘
```

- **Top card** — single tap zone spanning the day label, the three metric lines, and the arrow. Tapping opens the app at the main dashboard.
- **Timer label ("⏱ Timer")** — part of the top card visually but sits on the bottom strip; treat it as the same tap zone as the top card (opens main). Tapping the *label area*, the arrow, or the metric text all go to main.
- **1 MIN tile** — tap → opens the Gym Timer with the `1min` preset selected and the timer running.
- **5-1 tile** — tap → opens the Gym Timer with the `5-1` preset selected and the timer running.

All three metrics display the value from the last Grab Context. If no Grab has ever happened (fresh install, permissions not granted), each metric renders as `—`. The date label ("Today · Mon") reflects the day-of-week of the last Grab, not the wall-clock day; the word "Today" stays literal even if the last Grab was yesterday. (Simpler than "Yesterday" states; user is expected to Grab regularly.)

Freshness is the user's responsibility — the widget does not independently pull HealthKit data, and tapping it does not force a refresh. Grabbing from the app refreshes the widget.

### Live Activity — behavior fix, not a new feature

The existing Live Activity / Dynamic Island tap must now actually route:
- Tap during an active timer → open Gym Timer screen in rounds mode (so the user can see phase / pause / reset).
- Tap after "DONE!" → open Gym Timer (idle state is fine).

This is not a scope addition, it's a bug fix: the Swift side passes `deepLinkUrl` today, but the app ignores it, so the user sees the dashboard instead of the timer.

## Acceptance Criteria

### Deep links

- Running `xcrun simctl openurl booted "grabber://timer?preset=1min&autostart=1"` from a booted simulator launches the app, switches to Gym Timer, selects the 1 MIN preset, and the timer begins counting down from `1:00` within 1 second of launch.
- Running the same URL while the app is already foregrounded on the main dashboard also routes to timer + starts within 1 second.
- Running `grabber://grab` from either state triggers a Grab Context (same code path as tapping the button).
- Malformed URL (e.g. `grabber://timer?preset=nonsense`) falls back to opening the Gym Timer with the previously selected preset, no crash, no toast.
- Tapping the Live Activity during an active timer opens the Gym Timer screen (not the main dashboard).
- Both `grabber://` and `com.idvorkin.contextgrabber://` work for every route listed above.

### Widget

- After a fresh install, tapping Grab Context once causes the widget to show non-dash values for steps, sleep, and exercise within two minutes.
- Without ever having done a Grab Context, the widget renders all three metric values as `—` and still functions (tap zones work).
- The widget's 1 MIN tile, tapped on the home screen, opens the app and the timer is running within 1 second.
- The widget's top card tapped opens the main dashboard.
- The widget does not crash or show "Unable to Load" in any state (empty data, stale data, fresh install).
- Widget fits iOS medium size class (no clipped text, no overflowing tiles).

## Rationale

**Why add `grabber://` as a second scheme rather than renaming?** Renaming the existing scheme breaks any in-flight Live Activity URLs and requires a deploy-coordinated migration. Aliasing costs three lines in `Info.plist` and lets both schemes work forever.

**Why `autostart=1` as a query param rather than a separate route?** The set of presets is finite and dashboard-style routes with query params are easier to construct from a Shortcut or widget tap than path-based variants (`/timer/1min/start` vs `/timer?preset=1min&autostart=1`). The query-param approach also survives adding new presets without route-shape churn.

**Why write the widget snapshot on Grab Context rather than on any HealthKit update?** Grabs are user-initiated, infrequent, and already do the HealthKit work. Background widget refresh would add cost (HealthKit query in a background task) for a feature the user mostly sees right after grabbing anyway.

**Why em-dash over "No data" on the widget?** The main-screen metric cards already use em-dash for this state — consistency with an established pattern beats inventing a new one.
