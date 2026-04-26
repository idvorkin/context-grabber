# Copy Buttons Refresh GPS — Design Spec

## Summary

Both Copy buttons that share location coordinates — the main-view Location card's "Copy" and the Location Detail Sheet's "Copy Location Details" — currently emit whatever GPS fix was captured at the last `grabContext()`. If the user opened the app an hour ago and didn't tap Grab Context again, they paste an hour-old fix into a message. The whole point of those buttons is "I'm about to send this to someone now," so each Copy should refresh GPS first, with a graceful fallback to the cached fix when GPS is unavailable.

## Problem

Location coordinates copied from the app are silently stale. There is no indication to the user that the fix is old, and no opportunity for the OS to deliver a fresh reading even though the user has clearly signaled intent to share their current location. In practice this means coordinates pasted into iMessage / Slack can be off by miles if the user has moved since opening the app.

The "Use Current" button in the Known Places form already does the right thing: requests foreground permission, calls `getCurrentPositionAsync` at highest accuracy, rejects readings older than 30s, and surfaces status text. The two Copy paths should mirror that behavior.

## Goals

- Tapping Copy on either surface yields a coordinate fix that is at most a few seconds old in the common case.
- The button gives clear in-flight feedback so the user knows GPS is being refreshed and doesn't tap again.
- When GPS refresh fails (permissions denied, hardware unavailable, timeout), the user still gets a copy of the cached fix — better something than nothing — with explicit cached-vs-fresh feedback.
- No regression to the existing 1.5s "Copied" confirmation pattern.

## Non-Goals

- No change to the Grab Context button or to `snapshot.location` — that still represents the captured-at-grab fix.
- No change to the Known Places "Use Current" button.
- No change to the third Copy button in the Location sheet ("Copy Daily Summary") — it copies derived per-day text, not coordinates, so freshness doesn't apply.
- No persistent UI for fix age — the staleness is addressed at copy-time, not by surfacing age elsewhere.
- No change to background location tracking, retention, or the location history table.

## User-Visible Behavior

### Main-view Location card — "Copy" button

1. Default state shows label "Copy".
2. User taps the button.
3. Label changes to "Refreshing..." while the app requests a fresh GPS fix at highest accuracy. The button remains visible and tappable; subsequent taps during this phase are no-ops.
4. On success (fresh fix obtained within a reasonable timeout and not older than 30 seconds): the fresh latitude/longitude are written to the clipboard at 6-decimal precision, and the label changes to "Copied" for ~1.5 seconds, then back to "Copy".
5. On failure (foreground permission not granted, hardware error, fix returns older than 30 seconds, or any thrown error): the cached coordinates from the last grabbed snapshot are written to the clipboard at 6-decimal precision, and the label changes to "Copied (cached)" for ~1.5 seconds, then back to "Copy".
6. If there is no cached fix at all (snapshot has no location), the button does nothing — same as today.

### Location Detail Sheet — "Copy Location Details" button

1. Default state shows label "Copy Location Details".
2. User taps the button.
3. Label changes to "Refreshing..." while the app requests a fresh GPS fix at highest accuracy.
4. On success: the JSON payload is built using the fresh fix in place of the cached `location` field, written to the clipboard, and the label changes to "Copied" for ~1.5 seconds, then back to "Copy Location Details". The rest of the payload (clusters, timeline, summary) is unchanged.
5. On failure: the JSON payload is built using the cached `snapshot.location` exactly as it does today, written to the clipboard, and the label changes to "Copied (cached)" for ~1.5 seconds.
6. If there is no cached fix and no fresh fix can be obtained, the JSON's `location` field is `null` (today's behavior on no-snapshot-location), the payload is still copied, and the label shows "Copied (cached)".

### Behavior shared by both buttons

- "Refreshing..." transient label appears immediately on tap, before any async work.
- The clipboard is always written at the end — successful refresh path or fallback path — so the user never gets nothing.
- Existing "Copied" / new "Copied (cached)" both clear after ~1.5s.
- No alert dialogs, no error modals — failures are communicated only via the cached label.

## Acceptance Criteria

- Tapping "Copy" on the main Location card with permissions granted causes the clipboard to receive a fix whose timestamp is within ~30 seconds of the tap (verifiable by inspecting clipboard contents and comparing to wall-clock time of the tap).
- Tapping "Copy" with foreground location permission denied still writes the snapshot's cached coordinates to the clipboard, and the button visibly transitions through "Refreshing..." → "Copied (cached)" → "Copy".
- Tapping "Copy" while airplane mode is on (or otherwise unable to obtain a fresh fix) falls back to cached and shows "Copied (cached)".
- Tapping "Copy Location Details" in the Location sheet behaves identically: shows "Refreshing..." then "Copied" or "Copied (cached)", and the JSON's `location` reflects the fresh fix on the success path.
- Rapid double-tap on either button does not produce two clipboard writes or two refreshes — the in-flight state is idempotent.
- The cached-fallback label "Copied (cached)" is reachable from a manual test that revokes Location permission for the app between launches.
- Existing "Copy" pattern (1.5s confirmation) is preserved on the fresh-success path — total dwell on "Copied" stays ~1.5s, not extended by GPS time.
- The "Use Current" button in the Known Places form continues to work as today (no shared mutation regression).

## Rationale

The user signals "send my location now" by tapping Copy. Any time we have a chance to give them a fresh fix, we should — but we should never refuse to copy at all. iOS may suppress GPS updates while stationary (documented elsewhere in this codebase) so a 30-second-old fresh fix is still acceptable; that's the same threshold the Known Places form uses, and reusing it keeps the two paths consistent. Falling back silently to cached coordinates instead of an error dialog matches the "always succeed at copying" mental model: the user wanted text in their clipboard, the app delivers text, and the label tells them whether it's authoritative.
