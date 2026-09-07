# Gym Timer: a Custom preset with a slider — design spec

> **Status:** Drafted 2026-09-07 from Igor, in the terminal: *"Let's add a
> custom timer where we do a slider, moving every 10, starting on 60s,
> remember where it was last, or having the resets…"* Decisions D1–D4 below
> are proposed defaults.

## Summary

Beside the four fixed presets (30 SEC, 1 MIN, 2 MIN, 5-1) the Gym Timer's
Rounds mode gets a fifth, **Custom**: a slider for the work time in
ten-second steps, starting at one minute, with a rest slider and a rounds
count beside it. Whatever you set is what the timer runs, it is remembered
across launches, and RESET never touches it. It ships over the air: no
native code.

## Goals

- Pick any work time in ten-second steps without leaving the timer.
- The last setting is there next time — after RESET, after *Done*, after a
  relaunch.
- It works exactly like the other presets once set: the same LED face,
  cues, dip, Live Activity, background keep-alive, and turned-phone view.

## Non-goals

- **Not a preset editor.** The four fixed presets stay fixed; Custom is one
  extra slot, not a way to edit or add more.
- **Not a saved list.** One remembered setting, not a library of them.
- **Not seconds.** Ten-second steps only; the count and the cues are built
  for round numbers.
- **Not a native slider control.** The slider is drawn by the app, so this
  and any tweak to it ship over the air.

## User-visible behavior

**The chip.** A fifth chip, **CUSTOM**, after 5-1 in the preset row.
Choosing it works like choosing any preset: the LED face shows the work
time, START runs it.

**The controls.** With CUSTOM chosen, three controls sit under the preset
row, above the face:

- **Work** — a slider from 0:10 to 10:00 in ten-second steps. The value
  reads in `m:ss` beside it. Drag the thumb, tap anywhere on the track, or
  use the − and + at its ends for one step. It starts at **1:00**.
- **Rest** — the same slider from 0:00 to 5:00; 0:00 means no rest between
  rounds. Starts at 0:10.
- **Rounds** — − and + around a number, 1 to 20. Starts at 5.

So a fresh Custom is the 1 MIN preset, and you shape it from there. The
ready count before the first round is 5 seconds for work up to a minute
and a half, 10 seconds beyond, as the fixed presets do.

**Locked while running.** Once the timer is running or paused the three
controls stay visible but go dim and do nothing; RESET brings them back to
life. Changing a control while idle updates the face at once.

**Remembered.** The three values, and which chip is chosen, are saved the
moment they change and are back next time the timer opens — after RESET,
after *Done*, after force-quitting the app. Only changing them changes
them.

**Turned.** With the phone on its side the controls are hidden with the
rest of the chrome, as the preset row is; the face fills the screen.

**By link.** `grabber://timer?preset=custom` opens the timer on Custom with
the remembered values, and `&autostart=1` starts it, like the other
presets.

## Acceptance criteria

1. **The chip.** Rounds mode shows five chips; CUSTOM is last. Tap it: the
   face reads 1:00 (first time), three controls appear under the chips.
2. **Ten-second steps.** Drag Work to about the middle: it reads a multiple
   of ten seconds. Tap + once: ten seconds more. Tap − once: back. The
   track's ends are 0:10 and 10:00. Rest runs 0:00 to 5:00; Rounds 1 to 20.
3. **It runs what it says.** Set Work 0:40, Rest 0:20, Rounds 2, START: a
   ready count, 40 seconds of work (the count and *go!* / *rest* cues as
   ever), 20 of rest, 40 more, *done*. The Live Activity and the turned
   face show the same numbers.
4. **Locked while running.** With the timer running, the controls are dim
   and a drag changes nothing; pause: still locked; RESET: live again.
5. **Remembered.** Set Work 1:30, RESET: still 1:30. Choose 1 MIN, then
   CUSTOM again: still 1:30. Force-quit and reopen the app, open the
   timer: CUSTOM is chosen and Work reads 1:30.
6. **Turned.** On its side, no controls; back upright, they are there.
7. **By link.** `grabber://timer?preset=custom&autostart=1` starts the
   remembered custom timer.
8. **Over the air.** This ships with `just ota`; no native build.

## Decisions

- **D1 — Work, rest, and rounds, not work alone.** *Proposed.* A rounds
  timer with only a work time would run one round with a stranger's rest;
  the two extra controls are what make Custom a real preset. The default
  is the 1 MIN preset's shape, so "starting on 60s" is exactly what a
  fresh Custom is.
- **D2 — Remember the chip too.** *Proposed.* "Remember where it was last"
  reads as the slider; remembering that Custom was the chosen chip costs
  nothing and is what a user who set it up expects on return.
- **D3 — Locked, not hidden, while running.** *Proposed.* Hiding would
  reflow the screen at START; dimming keeps the layout and reads as "not
  now".
- **D4 — Drawn slider.** *Proposed.* The community slider is a native
  package; a track and thumb drawn by the app do the job and keep the
  feature and its tweaks over the air (the OTA-first review of the same
  day).

## Rationale

**Why ten seconds.** The cues count the last three seconds and speak the
boundaries; a work time that is a round number of tens keeps the count
landing where it belongs and the face readable. Finer than that is what
the stopwatch is for.

**Why the preset row and not a settings screen.** The presets are chosen
at the moment of use, standing at the rack; Custom's controls belong in
the same place, one tap away, and hidden the moment the timer runs.
