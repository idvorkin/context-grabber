# Box breathing

**Status:** native app only (Grabber Native). Source: Igor's "Box Breathing App — Prototype Brief"
(2026-10-04); the brief suggested a web page first, Igor asked for it in the native app instead.
**Stories:** [160–165](../../stories/09-breathing.md).

## Summary

A guided box-breathing session: breathe in, hold, breathe out, hold, each for the same number of seconds, for a
few minutes. You choose how long a breath is and roughly how long to sit; the app shows a circle that fills and
empties with you and, if you want, tells you each step by voice or by tone so you can close your eyes.

## Goals

- From the home screen to breathing in two taps, with last time's choices already set.
- The picture alone is enough to follow; the sound alone is enough to follow.
- Timing that can be trusted: a ten-minute session ends within half a second of ten minutes.

## Non-goals

- No history, streaks, reminders or HealthKit mindful minutes. (The mirror already reads meditation from Health;
  writing to it is a separate decision.)
- No other patterns (4-7-8, unequal sides). Every side of the box is the same length.
- No running with the screen locked or the app in the background. The screen stays on instead.
- No widget or Shortcut.

## What you see

### Setup

- **Breath length**: a slider from 5 to 15 seconds, in whole seconds, starting at 8.
- **Session length**: a slider from 2 to 10 minutes, in whole minutes, starting at 5.
- A summary line under them that changes as either slider moves: **"9 cycles · ends at 4 min 48 s"**. A session
  is always a whole number of cycles — the number closest to the session length chosen, never fewer than one —
  so it ends at the end of a hold, not mid-breath.
- **Cue**: Voice, Tone or Off. Choosing Voice or Tone plays a sample of it at once ("Breathe in", or the rising
  tone).
- **Begin**.
- All three choices are remembered for next time.

### Session

A near-black screen with one dark circle in the middle and a white ring that draws around its edge.

| Step | The ring | The circle | Tone |
|---|---|---|---|
| Inhale | draws from the bottom up both sides and closes at the top | grows from 90% to full size | rising |
| Hold | stays closed; a bar under the word fills left to right | full size | soft tick |
| Exhale | un-draws from the top back down to the bottom | shrinks to 90% | falling |
| Hold | gone; the bar fills left to right | 90% | soft tick |

- The step's word — **Inhale**, **Hold**, **Exhale**, **Hold** — is in the circle. Under the circle, small and
  dim: **"4:31 left"**.
- The circle's size eases in and out, as a breath does. The ring and the bar move at a constant rate, so they
  read as time.
- With **Voice**, a calm woman's voice with an Australian accent says "Let's begin", then "Breathe in", "Hold",
  "Breathe out", "Hold" as each step starts (the second hold is said a little lower and slower, so the two are
  told apart by ear), and "Well done" at the end. The first inhale waits two seconds for "Let's begin"; the
  circle reads **Ready** while it does.
- With **Tone**, each step starts with its tone and the session ends with a closing tone. With **Off**, silence.
- Music or a podcast already playing keeps playing; the cues sound over it.
- The screen stays on for the whole session and goes back to the phone's own setting afterwards.
- **Pause** (top right) freezes the ring, the circle, the bar and the time left exactly where they are. Resume
  continues from that point in the step: nothing jumps and the step is not announced again.
- Leaving the app (a notification pulled down, the home gesture) pauses the session the same way.
- **Back** (top left) leaves at once for Setup, with no confirmation.

### Done

**"Done"**, the session as it was — **"4 min 48 s · 9 cycles"** — and **Back to start**, which returns to Setup.
The closing tone (or "Well done") plays as this appears.

## Accessibility

- **Reduce Motion**: the ring and bar still move; the circle stays one size.
- **VoiceOver**: each step is announced as it starts, whatever the cue choice.

## The voice

The six phrases are sound files that ship in the app, so the voice works with no network. They are rendered
ahead of time: by an ElevenLabs voice when one is chosen, otherwise by the Mac's Australian voice (Karen). If a
file is ever missing, the phone's own Australian voice says the phrase instead.

*Open, for Igor:* his ElevenLabs account has no female Australian voice today, so the first build ships Karen.
Picking a voice from the ElevenLabs library and re-running the render replaces the six files; nothing else changes.

## Edge cases

- The longest breath with the shortest session (15 s, 2 min) is two cycles; no setting gives less than one.
- A cue that is noticed late (the phone was busy) is played once, for the step the session is in now; steps
  that passed unheard are not replayed.
- Pause during the two-second lead-in holds the lead-in.

## Acceptance

- At 8 s and 5 min the summary reads "9 cycles · ends at 4 min 48 s"; moving either slider changes it.
- Each of the four steps lasts the breath length, in the order above, with the ring, circle, bar and word as in
  the table.
- A 10-minute session at 5 s (30 cycles) reaches Done within 0.5 s of 10:00, and no step starts more than
  0.1 s late.
- Pause for a minute mid-inhale, resume: the ring continues from where it stopped and the session's own length
  is unchanged.
- With Voice, each phrase is heard at the start of its step, in aeroplane mode, and over playing music.
- The cue choice and both sliders are as left after quitting and reopening the app.
- Every start, step, cue, pause, resume, finish and exit is in the session log, with how late each step was
  noticed.
