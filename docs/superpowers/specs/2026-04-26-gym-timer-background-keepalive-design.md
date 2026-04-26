# Gym Timer — Background Keepalive

## Summary

Keep the gym timer's Dynamic Island / Lock Screen Live Activity in sync with the actual workout state when the app is backgrounded.

## Problem

The gym timer drives phase transitions (prep → work → rest → work…) from a JS `setInterval` and updates the Live Activity only at phase boundaries. When iOS suspends the JS thread (within seconds of backgrounding), the interval stops firing; the Live Activity therefore freezes at the last phase, with the native countdown expiring at the original phase's end and never moving on.

## Goals

- Live Activity reflects the true current phase, round, and time-remaining at any moment, even after several minutes in the background.
- Returning to the foreground after a long absence shows the correct in-app state instantly (no "snap-back" lag).
- No regression for users who don't background the app.

## Non-Goals

- Server-side push to update the Live Activity (no backend exists for this app).
- Re-playing audio cues that were missed during background suspension.
- Battery-perfect operation in cases where iOS truly kills the app (out of available memory pressure).

## Behavior

The timer state is derived from a wall-clock anchor (`startedAtMs` minus accumulated paused time). At any moment the displayed phase / round / time-remaining reflects the workout's true position, regardless of how long ago the last JS tick fired.

When the user returns the app to the foreground:
- The dashboard timer numbers update to the correct values within one frame.
- The Live Activity is reissued so its `endTimeMs` matches the current phase's end.
- No audible cues are replayed for boundaries crossed while backgrounded.

While the app is backgrounded:
- A silent audio loop runs through the existing audio session (now configured for `playback` category). This keeps the JS thread alive so phase transitions and Live Activity updates fire on schedule.
- Audible cues (start beep, end beep, finish fanfare) continue to play for boundaries crossed while backgrounded, since the audio session is active.

When the timer ends or the user exits the gym timer screen:
- The audio session is deactivated and the silent loop stops, freeing the keepalive resources.

## Acceptance criteria

- Background the app during work phase 1 of a 3-round profile; wait through rest into work round 2; foreground. Dashboard and Live Activity show "WORK · Round 2/3" with the correct remaining time.
- Background during prep; foreground 30s later (well after work has begun). State shows the appropriate work-round time-left.
- Pause then background then foreground 5 minutes later: state still shows "PAUSED · Round X/Y", no time has been consumed.
- Reset returns the audio session to inactive.
- Locking the phone (without backgrounding) is equivalent to backgrounding for these purposes.

## Rationale

iOS does not provide a way for a foreground-only app to schedule Live Activity updates while suspended without a backend push. The standard "running tracker" technique — declaring `audio` in `UIBackgroundModes` and keeping a silent audio source playing — keeps the app's JS thread alive long enough for tick-driven Live Activity updates to fire normally. The wall-clock-anchored derivation is a separate safety net: even if iOS kills the app under memory pressure, the next foreground re-derives the correct state from the elapsed wall time without needing to replay any intermediate ticks.
