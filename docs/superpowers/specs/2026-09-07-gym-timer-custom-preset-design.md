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

**Upright in Grabber Native: drums, not sliders** (story 184, Igor 2026-10-06: *"on vertical screen maybe dials
to turn up time and rest — show me designs"*). The native app's upright timer sets Work, Rest and Rounds with three
**drums** side by side instead of the three sliders: tall black panels, each with its label above (WORK, REST,
ROUNDS) and its value in big LED digits in the middle — red for work, green for rest, white for rounds, the colours
the face uses for them — with the value one step smaller faint above it and one step larger faint below, the way
a picker wheel shows its neighbours. Turning a drum:

- **Drag** up or down anywhere on it: each finger's-width of drag is one step, up for more; a fast flick moves
  two or four steps per finger's-width, so 1:00 to 10:00 is one or two flicks rather than a long drag.
- **Tap** its lower third for one step more, its upper third for one step less — the number that was there slides
  into the middle.
- Every step gives a light haptic tick; reaching the end of the range a firmer bump, and the drum stops.

The values, steps, ranges and defaults are exactly the ones above (Work 0:10–10:00 and Rest 0:00–5:00 in ten
seconds, Rounds 1–20, a fresh Custom at 1:00 / 0:10 / 5); only the control changed. Changing a drum changes the
face at once and is remembered at once, as the sliders were. They lock while running like the sliders, and are
hidden on its side the same way.

*Why drums.* Three designs were built and looked at on the simulator — two rotary knobs with detents, the drums,
and one arc around the values with a handle each for work and rest. The drums won as the gym-first one: three
large targets the size of a thumb, a gesture that works with a sweaty finger (a straight swipe, or a tap — no
circle to trace, no small handle to catch), digits readable at arm's length because the number fills the panel,
and they look like the LED face above them. The knobs read well but need a circular drag and offered nothing for
Rounds; the arc's handles are small and close together, the worst for wet fingers.

The other two stay in the app for Igor to try, chosen only by a launch setting for the simulator and Xcode, never
from the screen; the sliders are kept the same way. Each design has the same values, steps, ranges, haptics, lock
and log.

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
6a. **Drums, upright (Grabber Native).** CUSTOM shows three drums, WORK 1:00 / REST 0:10 / ROUNDS 5 on a fresh
   install, with the neighbouring values faint above and below. Drag Work up a finger's width: 1:10, with a tick.
   Tap the bottom of Rest: 0:20; the top: back to 0:10. A fast flick on Work moves several steps at once. At
   10:00 a further drag gives a bump and stays at 10:00. The face follows each change, and a relaunch keeps it.
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
