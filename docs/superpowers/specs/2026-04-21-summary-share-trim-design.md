# Summary Share Trim — Design Spec

## Summary

The "Summary" share (what the user sends to their life coach) currently produces a pretty-printed JSON blob dominated by location data that a human coach can't use: lat/lng pairs, unix-ms timestamps, per-stay entries for trips as short as 1 minute, and full percentile tables duplicating the 7-day data. Trim the Summary share to high-signal content only, move the detailed location export to the Location sheet, and stop pretty-printing the JSON so it transmits cleanly in SMS / iMessage.

## Problem

"Summary" is meant to be a compact, coach-readable snapshot of the last 7 days. Today the output has four sections:

1. Seven days of daily health values (high signal — keep).
2. Weekly percentile stats for every metric (redundant — the LLM on the coach's side can derive percentiles from the daily data).
3. Today's workouts (small, high signal — keep).
4. Location summary: includes a flat stays-only sentence string **plus** an array of every unique place with its coordinates/radius/unix-ms visit times, **plus** a per-stay timeline entry for every stay in the retention window including ones shorter than 30 minutes.

On real data (~30-day retention, ~5 stays/day), section 4 is ~70–90% of the blob, and none of the lat/lng numbers, unix timestamps, or short-stay entries are useful to a human reader. The share is too large for SMS and noisy to skim.

There is no separate path for users who *do* want the detailed location data (coords + full timeline) — today they either get it inside the Summary share or not at all.

## Goals

- Summary share is dominated by health narrative and reads cleanly as a coach briefing.
- Place activity is present in Summary as **human-readable text only** (named places + hours), no coordinates, no unix timestamps, no radius, no point counts.
- Summary share size drops by roughly 70% on a typical 30-day location history.
- Users who want full location detail (coords, per-stay timeline) can copy it from the Location sheet with a single tap.
- No loss of information for the user — the data they can access today is still accessible, just routed to the right surface.

## Non-Goals

- No changes to the "Raw" share button (it keeps its current behavior).
- No changes to what data is *collected* — HealthKit queries, GPS tracking, retention settings are all unchanged.
- No changes to the Metric cards, Metric Detail Sheet, or Location Detail Sheet layout beyond adding the new copy button.
- No change to markdown vs JSON format for Summary — stays JSON, just compact and trimmed.

## User-Visible Behavior

### Summary share button

Tapping **↗ Summary** produces a compact JSON payload with:

- **Today's headline** — a single object with today's values for all the metrics the dashboard shows (steps, sleep hours + bedtime + wake time, heart rate, resting HR, HRV, meditation minutes, exercise minutes, weight in lbs, today's workouts).
- **Last 7 days** — an array of 7 daily entries with the same fields already exported today.
- **Place activity** — two human-readable text blocks:
  - *Weekly breakdown*: `"This week: Home 92h, Office 28h, Gym 4h"` (one line per week, up to the weeks present in the retention window).
  - *Recent days timeline*: last 3 days of named-place stays with local times and durations, e.g. `"Mon Mar 15: Home 10pm–7am (9h), Office 9am–5pm (8h)"`.

The JSON is serialized **without** pretty-printing (no 2-space indent, no newlines in the JSON itself — the two place-activity text blocks keep their own internal newlines as string content).

The Summary share no longer includes: weekly percentile stats, cluster objects with coordinates/radius/unix timestamps, per-stay timeline objects, or any lat/lng number.

### Location Detail Sheet — two new copy actions

In the Location sheet (opened by tapping the Location card on the main screen), add two buttons placed near the existing Export Database button. Both show "Copied" feedback for ~1.5s, mirroring the existing coordinate-copy pattern.

1. **Copy Daily Summary** — copies a human-readable, one-line-per-day breakdown of time spent per known place, newest day first. Example:

   ```
   Tue Apr 22: Home 10h, Office 7h, Gym 1h
   Mon Apr 21: Home 9h, Office 8h
   Sun Apr 20: Home 22h
   ```

   Places are sorted within each day by total time descending. Stays ≥ 1 hour render as `Nh` (with a decimal when not whole, e.g. `1.5h`); stays under an hour render as `Xm`. Days with no recognized stays render as `"<header>: no known places"`. The text contains no coordinates, ISO timestamps, or unix milliseconds — the intent is a format a life coach can read as-is.

2. **Copy Location Details** — copies a JSON blob with today's current-location coordinates, the full clusters array, the per-stay timeline (including short stays), and the summary string. This is the shape that used to be bundled into Summary before the trim. Kept as a single-tap power-user export.

The main-screen Location card keeps its existing lat/lng-only "Copy" button unchanged. Together the three actions split cleanly by audience: main-screen Copy for quick coordinate sharing, Copy Daily Summary for a coach briefing, Copy Location Details for machine-readable power use.

### Raw share button

Unchanged. Still emits the full detailed export (health + single coordinate + full clusters + full timeline).

## Acceptance Criteria

- On a device with ≥ 7 days of location history, the Summary share JSON is at least 60% smaller (byte count) than before.
- The Summary JSON contains no key named `latitude`, `longitude`, `center`, `radiusMeters`, `pointCount`, `firstVisit`, `lastVisit`, or `weeklyStats`.
- The Summary JSON contains a non-empty `today` object and a 7-entry `days` array when health data is available.
- The Summary JSON's place activity section contains only string values (no arrays of objects, no nested lat/lng).
- Weekly place breakdown text lists named places in descending order by hours (e.g. Home before Office before Gym when those are the true hours).
- Recent days timeline text contains at most the last 3 days and uses 12-hour local time (`10pm–7am`), not unix milliseconds or ISO strings.
- Tapping **Copy Location Details** in the Location sheet copies a JSON string containing `clusters`, `timeline`, and current coordinates, and shows "Copied" feedback for ~1.5 seconds.
- Tapping **Copy Daily Summary** copies plain text with one line per day (day header + comma-separated places with durations), no coordinates or unix timestamps, and shows "Copied" feedback for ~1.5 seconds.
- When location history is empty, the Summary share still succeeds (no location section, or an empty one) and the copy buttons are either hidden or copy an empty-state string (implementer's choice — both are acceptable).
- The Raw share button's output is unchanged byte-for-byte vs. before this change.

## Rationale

The "life coach" use case is human-in-the-loop: the coach either reads the summary themselves or feeds it to an LLM with a prompt. In both cases, coordinates and unix timestamps are dead weight. Percentile tables are already derivable from the 7-day data. The detailed location blob exists for a different user goal (machine-readable export, personal tooling) and belongs behind its own explicit action, not bundled into the coach briefing.

Compact JSON (no pretty-print) is the right default for share payloads — the content will either be read as text (where the indentation is clutter) or parsed by an LLM (which doesn't need the whitespace). Pretty-printed JSON is a debugger affordance, not a delivery format.
