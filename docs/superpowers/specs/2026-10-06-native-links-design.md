# Native links and Shortcuts — Design Spec

**Status:** Drafted 2026-10-06 (Igor, from the phone: *"a link so i can create shortcuts"*; then *"go propose
something and build it, and I can figure out stuff"*)
**Owner:** Igor
**Tracking:** [#167](https://github.com/idvorkin/context-grabber/issues/167); story
[135](../../stories/07-widgets-and-links.md)
**Part of:** [Swift-native app](2026-10-04-swift-native-app-design.md), step 7 (widgets, links and Shortcuts)

## Summary

Every screen of Grabber Native has a link that opens the app on it, and the ones that run something — the Gym
Timer, Box breathing, a call — can start it from the link. The same things are actions in the Shortcuts app and
phrases for Siri, so a shortcut is built by picking from a menu, not by typing a URL. A *Links* screen inside
the app lists every link with a Copy button, for the times a URL is what a surface wants (the Action Button, a
home-screen bookmark, another app).

## Goals

- A shortcut, the Action Button or a widget opens the native app exactly where Igor meant, cold or warm.
- Starting a workout or a breathing session is one action, with the preset or the length chosen in the shortcut.
- No link ever crashes the app or leaves it on a half-open screen: a link it does not understand lands on the
  home screen, and the log says what came in.
- The links read the same as Context Grabber's, so a shortcut moves over at the cutover by changing the scheme
  only.

## Non-goals

- Routes for screens the native app does not have yet (the journal, reflections, the tally, *Grab*'s auto-share).
- Controls from a link on a screen already running (pause, stop, next round).
- Parameters beyond what the screen's own controls offer (no 3-second breaths from a link, no 30 rounds).

## The scheme, while the two apps live side by side

Context Grabber already owns `grabber://` on the phone, and its widgets, its Live Activity and the Cockpit
page's ☎ fall back to it. iOS does not say which app opens a scheme two apps claim, so until the cutover the
native app answers to its own scheme, **`grabbernative://`**, with exactly the grammar below. It also understands
a `grabber://` link handed to it directly (pasted into the Links screen's examples, or after the cutover), so
the cutover registers `grabber` and every saved link keeps working.

## The links

| Link | Lands on |
|---|---|
| `grabbernative://` or `grabbernative://home` | the home screen |
| `grabbernative://today` (also `…://grab`) | Today, which grabs as it opens |
| `grabbernative://timer` | the Gym Timer on its remembered preset, ready, not started |
| `grabbernative://timer?preset=1min` | the Gym Timer on that chip (`30sec`, `1min`, `2min`, `5-1`, `custom`), started |
| `grabbernative://timer?preset=60,10,5` | a Custom workout of work seconds, rest seconds and rounds, started, not remembered |
| `grabbernative://timer?autostart=1` | the remembered preset, started |
| `grabbernative://breathe` | Box breathing's sliders |
| `grabbernative://breathe?minutes=5` | a session of that length on the remembered breath, begun |
| `grabbernative://breathe?breath=8&minutes=5` | a session of that breath (seconds a side) and length, begun |
| `grabbernative://breathe?autostart=1` | a session from the remembered sliders, begun |
| `grabbernative://places` | Places |
| `grabbernative://cockpit` | the Cockpit |
| `grabbernative://call` | the call screen, calling Larry on the remembered backend; a live call is brought forward, not restarted |
| `grabbernative://call?via=eleven` | …on that backend (`eleven`, `gemini`, `openai`, `drill`) |
| `grabbernative://card` | Think a Card Trainer on "think of a card", as the home screen's row does |

- **The timer's grammar is the simulator hook's**: a preset is a chip's name or *work,rest,rounds*. Context
  Grabber's `timer?preset=1min&autostart=1` works too. `autostart=0` with a preset only selects it.
- **Values outside the controls' ranges are brought into them**: a Custom workout snaps to the sliders' steps
  (work 10 s – 10 min, rest 0 – 5 min, 1 – 20 rounds), breath to 5 – 15 seconds, length to 2 – 15 minutes. A link's
  Custom workout or breathing session is for that run only and moves no slider; a chip a link names becomes the
  chosen chip, as a tap on it would.
- **A link while something is on screen** closes what is in front and opens what the link names, so a timer
  link during a breathing session ends the session and starts the workout. A call carries on behind any screen,
  as it does when its own screen is closed. A link to the screen already in front with nothing to start leaves
  it as it is.
- **What is not understood is never an error on screen.** An unknown route opens the home screen. An unknown
  preset opens the timer ready on the remembered preset; a breath or length that is not a number is ignored;
  an unknown backend calls on the remembered one. Each is logged as a link that was not fully understood.
- **A file opened in the app** (Context Grabber's database export) still imports into Places, as before.

## Shortcuts and Siri

Grabber Native's actions in the Shortcuts app, each opening the app:

| Action | Parameter | Does what the link does |
|---|---|---|
| *Open Today* | — | `today` |
| *Start Gym Timer* | Preset: 30 SEC, 1 MIN, 2 MIN, 5-1, Custom; blank for the remembered one | `timer?preset=…`, started |
| *Start Box Breathing* | Minutes, 2 – 15; blank for the remembered length | `breathe?minutes=…`, begun |
| *Open Places* | — | `places` |
| *Open Cockpit* | — | `cockpit` |
| *Call Larry* (already there) | Backend; blank for the remembered one | `call?via=…` |

Each is also a Siri phrase and a ready-made shortcut under the app in the Shortcuts app: "Start Gym Timer in
Grabber Native", "Start 1 MIN in Grabber Native", "Start Box Breathing in Grabber Native", "Open Today in Grabber
Native", "Open Places in Grabber Native", "Open Cockpit in Grabber Native", "Call Larry in Grabber Native".

## The Links screen

A row near the bottom of the home screen, *Links for Shortcuts*, opens a list of every link above with a line
saying what it does and a **Copy** button. Copying puts the link on the clipboard and the row says *Copied* for a
moment. A footer says the actions are also in the Shortcuts app under Grabber Native, and that the scheme becomes
`grabber://` at the cutover.

## What the log says

Every link, shortcut and opened file is one line: the link (a shortcut as the link it equals; a file by its
name), which screen it routed to, whether it was fully understood, and where it came from (a link, a shortcut,
a file).

## Acceptance criteria

- Each link in the table, opened with the app closed and again with it open on another screen, lands where the
  table says; the timer and breathing links that start something are running within about a second.
- `grabbernative://timer?preset=10,10,2` runs a whole 35-second workout; `grabbernative://breathe?breath=5&minutes=2`
  begins a 2-minute session of 5-second breaths.
- `grabbernative://nowhere`, `grabbernative://timer?preset=9min` and `grabbernative://breathe?minutes=lots` open
  the home screen, the timer ready, and the sliders respectively, with no error on screen, and the log says each
  was not fully understood.
- The six actions are in the Shortcuts app under Grabber Native; a shortcut of *Start Gym Timer* (1 MIN) run with
  the app closed opens the timer counting down.
- The Links screen lists every link above; Copy puts exactly that link on the clipboard.
- Context Grabber's own links (`grabber://…` from its widgets and the Cockpit page) still open Context Grabber.
