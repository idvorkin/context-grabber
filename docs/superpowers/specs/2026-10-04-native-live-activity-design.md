# Native Live Activity: the Gym Timer and Box breathing — Design Spec

**Status:** Drafted 2026-10-04 (Igor: the Gym Timer's countdown on the lock screen; then, the same day, "the Live
Activity must be reusable — Box breathing gets one too")
**Owner:** Igor
**Tracking:** bead `context-grabber-3ss` (the native port); stories [106](../../stories/06-gym-timer.md),
[125](../../stories/07-widgets-and-links.md), [166](../../stories/09-breathing.md)
**Part of:** [Swift-native app](2026-10-04-swift-native-app-design.md) — this brings the lock-screen countdown
forward from the widgets step; the home-screen widgets (Today tiles, the memdeck card) still wait for it. Box
breathing's side changes [Box breathing](2026-10-04-box-breathing-design.md): a session now keeps running with
the phone locked.

## Summary

While a Gym Timer workout or a Box breathing session runs, Grabber Native shows it on the lock screen and in the
Dynamic Island: what step it is in, how far along, and a countdown to the end of the step that runs by itself.
A locked phone on the bench is the gym clock; a locked phone on the cushion still says *Exhale*. A tap on it
lands on the screen it came from.

The card looks the same for both — a word, a line under it, a big countdown, a bar — and only what it says
differs. There is never more than one: starting one screen's card ends the other's.

## Goals

- Read the step, where you are in the whole, and the time left without unlocking (stories 106, 166).
- The countdown reaches zero at the step's true end, the same moment the next cue sounds.
- A tap on the lock-screen card or the island opens the app on the running screen (story 125).
- Never a stale card: what the lock screen shows is what is running, or nothing.

## Non-goals

- Home-screen widgets and one-tap starts from them (story 114) — the widgets step.
- Controls on the card (pause, reset, stop from the lock screen). A tap opens the screen; the controls are there.
- The stopwatch and the set counter. Only Rounds mode has a card.
- Push-driven updates from a server. The app on the phone keeps it current.

## What Igor sees

### The Gym Timer, while the rounds run

| Phase | Lock screen | Island, compact | Colour |
|---|---|---|---|
| Ready count | *GET READY*, *Round 1/4*, the countdown, a bar over the ready count | *READY 1/4* · countdown | amber |
| Work | *WORK*, *Round 2/4*, the countdown, a bar over the round | *WORK 2/4* · countdown | red |
| Rest | *REST*, *Round 2/4*, the countdown, a bar over the rest | *REST 2/4* · countdown | green |

The colours are the timer face's: red working, green resting, amber getting ready.

### Box breathing, while the session runs

| Step | Lock screen | Island, compact |
|---|---|---|
| Inhale | *Inhale*, *Cycle 3 of 9*, the countdown to the end of the inhale, a bar over the step | *IN 3/9* · countdown |
| First hold | *Hold*, *Cycle 3 of 9*, … | *HOLD 3/9* · countdown |
| Exhale | *Exhale*, *Cycle 3 of 9*, … | *OUT 3/9* · countdown |
| Second hold | *Hold*, *Cycle 3 of 9*, … | *HOLD 3/9* · countdown |

Breathing's card is white on black, as quiet as its screen. The card appears with the first inhale, not during
the moment of quiet before it.

### Both

The countdown is large and in fixed-width digits, so it does not jitter as it counts. When another app's
activity shares the island, the minimal view is the countdown alone. A long press on the island expands it to
the lock-screen content.

The countdown runs on the phone's own clock between steps: the app does not need to be awake every second for it
to be right. At each step the card changes to the next.

### Paused

The Gym Timer's STOP, or a tap on the breathing circle, freezes the card: *PAUSED* in amber (the timer) or white
(breathing), what it was paused on underneath (*WORK · Round 2/4*, *Inhale · Cycle 3 of 9*), and the time left
in the step as a still number. Resuming starts the countdown again from exactly where it stopped.

### Finished

- The Gym Timer: *DONE!* and *4 rounds completed*.
- Box breathing: *Done* and *4 min 48 s · 9 cycles*.

No countdown. The card stays on the lock screen for a few minutes so a glance afterwards still sees it, then
goes by itself.

### When it goes away

- **RESET** (the timer) or **Back** (breathing) removes the card at once.
- **Leaving the screen** (*Done* on the timer, the close button on breathing) removes it at once, finished or not.
- **Choosing a timer preset after the finish** is a RESET and removes it.
- **Starting the other screen** removes the first one's card; only one is ever shown.
- **The app killed** (swiped away, or iOS ends it) can leave a card behind that no longer counts true. The next
  launch of the app removes it.

### When Live Activities are off

With Live Activities switched off for Grabber Native in Settings, both screens run exactly as before and nothing
shows on the lock screen. The session log says so once.

### The tap

A tap on the lock-screen card or the island opens the app on the screen it came from, still running (or paused,
or finished) as it was. There is no link to follow: the card only exists while its screen is open, so opening
the app is opening that screen.

## Acceptance criteria

- A 2 MIN workout running with the phone locked shows *WORK*, *Round 2/4* and a countdown during the second
  round; the countdown reaches zero within a second of the *go* or *rest* cue.
- A 5-minute session at 8 s, locked during the third cycle, shows *Exhale*, *Cycle 3 of 9* and a countdown that
  reaches zero as *Hold* is said; the voice keeps going with the phone locked.
- The island shows *WORK 2/4* (or *OUT 3/9*) and the countdown while another app is in front.
- Pausing shows *PAUSED* and a still time; resuming counts down again from it.
- The finish shows *DONE!* / *4 rounds completed* or *Done* / *4 min 48 s · 9 cycles*; the card is gone a few
  minutes later by itself.
- RESET, Back, leaving the screen, or a preset chosen after the finish remove the card at once.
- A tap on the card while it runs opens the app on its screen.
- After the app is swiped away mid-session and opened again, no card from that session remains.
- With Live Activities off in Settings both screens run and nothing fails.
- The session log has one line when the card appears, one at each step, pause and resume, and one when it goes,
  each saying whether iOS accepted it.

## Known limits

- **Only the app moves the card from one step to the next.** Both screens keep the app running in the
  background for their cues, so it is awake at each step; if iOS stopped it anyway, the card would count to zero
  and stay on that step until the app ran again.
- **A paused card left behind by a killed app** stays until the next launch or until iOS removes it (hours).

## Rationale

- One card per session, changed at steps and pauses rather than every second: iOS rations Live Activity
  updates, and a countdown that runs on the phone's clock is both cheaper and exactly on time.
- One look for both screens: a third screen later (a call, a meditation) says what to show and gets the card.
- The tap needs no deep link because the card's life is its screen's life. The React Native app needed a link
  because its timer was one tab among several.
