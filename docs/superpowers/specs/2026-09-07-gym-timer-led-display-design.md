# Gym Timer: the LED look, and turning the phone — design spec

> **Status:** Drafted 2026-09-07 from Igor, in the terminal: *"Look at Box
> Timer on the App Store, see how it has that LED countdown look. That's how
> I want my count up / count down timer to look, especially when I do a
> phone rotate."* Decisions D1–D4 below are proposed defaults; not built yet.

## Summary

The Gym Timer's time — the countdown in Rounds, the count-up in Stopwatch,
the count in Sets — is drawn as a seven-segment LED display: glowing
segments on black, with the unlit segments faintly there, the way a gym's
wall clock and the Box Timer app look. Turn the phone on its side and the
display turns with it and grows to fill the long edge of the screen, with
nothing else on it; a tap anywhere starts or stops. Turn it back and the
timer is as it was. The rest of the app never turns.

## Goals

- The time reads from across a room: big LED digits, high contrast, a glow.
- Turned sideways, the digits use the whole screen — the phone propped
  against a water bottle is the wall clock.
- Nothing about how the timer *works* changes: presets, phases, rounds,
  laps, sets, the Live Activity, the beeps, the background keep-alive are
  all exactly as they are.
- The rest of the app is untouched: it stays portrait, and no other screen
  changes.

## Non-goals

- **Not the whole app in landscape.** Only the timer's display turns, and
  only while the timer screen is open. (D1.)
- **Not a new timer.** No new modes, presets, or sounds.
- **Not the widget.** The Today widget's timer tiles and the Live Activity
  keep their current look.
- **Not a font.** The digits are drawn, not typed, so they scale to any size
  with no font to bundle.

## User-visible behavior

**The display.** Where the time used to be thin white type, there is now a
seven-segment display: each digit is the classic seven bars, the lit bars
bright with a soft glow, the unlit bars just visible as dark ghosts, so an
`8` is always faintly present behind every digit and the display reads as
one panel rather than as text. The colon between minutes and seconds is two
LED dots. The display sits on black; the whole timer screen is black behind
it. Digits are as wide as the screen allows in portrait.

**Colours.** The time is red while working, green while resting, amber
while getting ready, red again — and steady — on *DONE*; idle, before the
first start, it is white. Above the time in Rounds mode a short LED word in
green says the phase — *GO*, *rESt*, *rEAdY*, *donE* — the way a
seven-segment display spells them; the round, *Round 2 of 5*, stays in
ordinary small type under the time. The stopwatch is red while running and
white when stopped, its hundredths in smaller LED digits after the seconds.
The set count is green LED digits; the tally marks stay as they are.

**Turning the phone.** Turn the phone on its side, either way, and within
about half a second the timer's display turns to read upright and grows to
fill the long edge of the screen — the phase word, the time, the round, and
nothing else: no header, no presets, no mode bar. Tap anywhere: the timer
starts or stops (Rounds and Stopwatch) or counts one more (Sets). A small
line in ordinary type at the edge says *tap to start* / *tap to stop* /
*tap to count*. Turn the phone back upright and the full timer screen
returns, with its buttons, exactly where it was — the timer never noticed.
Laying the phone flat leaves the display as it was last turned.

**What does not turn.** The phone's own window stays portrait the whole
time: the status bar, the notch, and every other screen of the app are
exactly as before. Only the timer's display turns, drawn sideways inside
the portrait window.

**Everything else** on the timer screen — presets, START / STOP / RESET,
LAP, +1 / UNDO, the mode bar, *Done* — is unchanged.

## Acceptance criteria

1. **Rounds, portrait.** Open the Gym Timer: the preset's time shows as
   white LED digits filling the width, ghost segments visible behind them,
   on black. START: the time turns amber for *rEAdY*, red for *GO*, green
   for *rESt*, with the green phase word above it; the round line is under
   it. The beeps, the Live Activity and the phases are exactly as before.
2. **Stopwatch.** Red LED `MM:SS` with smaller LED hundredths while running,
   white when stopped; LAP rows unchanged.
3. **Sets.** The count is green LED digits; the tally marks and buttons are
   unchanged.
4. **Turn.** With the timer running, turn the phone to either side: within
   about half a second the display is sideways, upright to the eye, the
   digits spanning the long edge; header, presets and mode bar are gone.
   Tap anywhere: the timer stops; tap again: it resumes. Turn the phone
   back: the normal screen is back, the timer still running and correct.
5. **Turn, both ways.** Top of the phone to the left and top to the right
   both read upright.
6. **Flat.** Lay the phone face-up on a table while turned: the display
   stays as it was; pick it up: it follows.
7. **The rest of the app.** With the timer turned, press *Done* (turn back
   first): the Today screen is portrait as always. No other screen in the
   app turns when the phone does.
8. **Legible across the room.** From three metres, the turned display's
   minutes and seconds are readable and the phase colour is obvious.
9. **Nothing regresses.** Presets, autostart from the widget tiles and deep
   links, background timing, beeps, laps, sets, *Done*.

## Decisions

- **D1 — The display turns, not the window.** Box Timer's screenshots show
  it: the phone's window stays portrait and the display is drawn sideways
  inside it. Letting the OS rotate the window would mean every screen of
  the app has to survive landscape, and the timer chrome too; turning only
  the display gives the wall-clock without any of that. *Proposed.*
- **D2 — Colours by phase, in LED colours.** Red / green / amber for work /
  rest / ready, white idle — the LED palette rather than today's blue /
  teal / orange, because it is what a gym clock is and what the glow looks
  right in. The green phase word is Box Timer's green label. *Proposed.*
- **D3 — Tap anywhere when turned.** The buttons are not drawn sideways; a
  tap on the display is the one control, as in Box Timer's *TAP TO PAUSE*.
  RESET, LAP and UNDO wait for the phone to come back upright. *Proposed.*
- **D4 — Black.** The timer screen goes from navy to black; LEDs want black
  behind them. The chrome (header, mode bar, buttons) keeps its colours.
  *Proposed.*

## Rationale and risks

**Why draw the digits rather than use a seven-segment font.** A font is a
file to bundle and a text layout to fight (tabular widths, glow via shadow
on text is poor); seven bars per digit is a few dozen lines, scales to any
size exactly, and the ghost segments come for free.

**Why the accelerometer and not the OS's rotation.** The app is locked to
portrait and stays so (D1). The phone's tilt is read from its accelerometer
a few times a second — gravity tells which edge is down — with a margin so
the display does not flicker between orientations near 45°. No permission
prompt: reading the accelerometer needs none.

**Risk: the mirror.** Which way "top to the left" turns the display is a
sign convention that is easy to get backwards — and the first build had it
backwards, reading upside down both ways (Igor: *"rotation math seems
off"*). The phone turned counter-clockwise needs the display turned
clockwise relative to it. Criterion 5 is the check.
