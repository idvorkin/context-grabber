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
- **Session length**: a slider from 2 to 15 minutes, in whole minutes, starting at 5.
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
- **Pause lives in the circle.** Tapping the circle pauses; tapping it again resumes. There is no separate pause
  button. While running, a small, faint pause mark sits low in the circle, so it reads as something to tap without
  competing with the word. While paused, the circle says so plainly: a play mark, **"Paused"** in place of the
  step's word, and **"tap to resume"** under it; the ring dims but stays where it stopped.
- Pausing freezes the ring, the circle, the bar and the time left exactly where they are. Resume continues from
  that point in the step: nothing jumps and the step is not announced again.
- For VoiceOver the circle is one button, labelled **Pause** while running and **Resume** while paused, with the
  step's word as its value.
- Leaving the app (a notification pulled down, the home gesture) pauses the session the same way; tapping the
  circle resumes it.
- **Back** (top left) leaves at once for Setup, with no confirmation.

### Done

**"Done"**, the session as it was — **"4 min 48 s · 9 cycles"** — and **Back to start**, which returns to Setup.
The closing tone (or "Well done") plays as this appears.

## The look

Calm and quiet, monochrome on near-black; nothing bright, nothing that counts a score.

- **Type**: the words that carry the moment — the title, the step's word in the circle, the slider values,
  "Done" — are set in a light serif, so the screen reads like a quiet page rather than a dashboard. Labels are
  small, spaced-out capitals; numbers that change keep their width so nothing jitters.
- **Setup**: each slider shows its value large beside its label, with a faint dot for every whole step it can
  stop on and the ends of its range under it. The summary sits on its own line between hairlines. The cue is three
  quiet choices, each with a small symbol; the chosen one is lit. Begin is a full-width white pill at the bottom.
- **Session**: the circle has a little depth — slightly lighter at its centre than its edge — and the ring glows
  softly, more as it closes. Time left sits small and dim under the circle.
- **Done**: the closed ring, small and still, over "Done", the session's length and cycles, and a quiet
  outlined "Back to start".

## Accessibility

- **Reduce Motion**: the ring and bar still move; the circle stays one size.
- **VoiceOver**: each step is announced as it starts, whatever the cue choice.

## The voice

The six phrases are sound files that ship in the app, so the voice works with no network. They are rendered
ahead of time by an ElevenLabs voice: a calm, gently spoken Australian woman, slow and unhurried, the best of a
few takes of each phrase. Rendered without an ElevenLabs key, the Mac's Australian voice (Karen) stands in. If a
file is ever missing, the phone's own Australian voice says the phrase instead. The longest phrase, "Let's
begin", fits inside the two-second lead-in.

## Edge cases

- The longest breath with the shortest session (15 s, 2 min) is two cycles; no setting gives less than one.
- The longest session (15 min) is 45 cycles at 5 s and 15 cycles at 15 s.
- A cue that is noticed late (the phone was busy) is played once, for the step the session is in now; steps
  that passed unheard are not replayed.
- Pause during the two-second lead-in holds the lead-in.

## Acceptance

- At 8 s and 5 min the summary reads "9 cycles · ends at 4 min 48 s"; moving either slider changes it. At 8 s and
  15 min it reads "28 cycles · ends at 14 min 56 s".
- Each of the four steps lasts the breath length, in the order above, with the ring, circle, bar and word as in
  the table.
- A 10-minute session at 5 s (30 cycles) reaches Done within 0.5 s of 10:00, and no step starts more than
  0.1 s late.
- Tap the circle mid-inhale: it reads "Paused · tap to resume" and nothing moves; a minute later tap it again:
  the ring continues from where it stopped, the inhale is not announced again, and the session's own length is
  unchanged. There is no pause button anywhere else on the screen.
- With Voice, each phrase is heard at the start of its step, in aeroplane mode, and over playing music.
- The cue choice and both sliders are as left after quitting and reopening the app.
- Every start, step, cue, pause, resume, finish and exit is in the session log, with how late each step was
  noticed.
