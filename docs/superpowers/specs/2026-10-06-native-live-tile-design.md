# The live tile: usage left on the home screen — Design Spec

**Status:** Drafted 2026-10-06 (Igor, from the phone: *"add a live tile"*; then *"go propose something and build it,
and I can figure out stuff"*)
**Owner:** Igor
**Tracking:** [#168](https://github.com/idvorkin/context-grabber/issues/168); story
[136](../../stories/07-widgets-and-links.md)
**Part of:** [Swift-native app](2026-10-04-swift-native-app-design.md), step 7 (widgets). Builds on the usage strip
of the [native Cockpit](2026-10-05-native-cockpit-design.md) and the links of
[Native links and Shortcuts](2026-10-06-native-links-design.md).

## Summary

Grabber Native gets its first home-screen widget, the *live tile*. It shows the usage strip — what is left of
Claude's week, the current model's allowance and the voice budget — so "how much do I have left" is a glance at
the home screen, not a launch. The medium size adds three one-tap starts: the Gym Timer, Box breathing and a call
to Larry.

## Goals

- The strip's numbers, colours and *to spend* nudge on the home screen, the same as the strip in the app.
- Honest about age: the tile says how old its reading is, and an old one says so in orange.
- Never a made-up number: before the app has ever loaded a reading, the tile says to open the app, not 0%.
- One tap from the home screen to a running workout, a breathing session or a call.

## Non-goals

- The widget fetching from the Cockpit itself. The Cockpit is on the tailnet and the app already loads it; the
  tile shows what the app last loaded.
- A lock-screen version, a large size, today's activities on the tile (later, when the activities have a home in
  the native app).
- Refreshing from the tile. A tap opens the app, whose strip loads a new reading as it comes to the front.

## What Igor sees

**Small:** the three bars — *Week*, the model (named as the Cockpit names it), *Voice* — each a fill of what is
left with its number, then one line: the reading's age (*12m ago*), and when it matters *31% to spend* in green.
A tap opens the app on the home screen.

**Medium:** the same bars and line on the left half, and on the right three buttons stacked: **Gym Timer**
(starts the last preset used), **Breathe** (begins a session from the sliders), **Call Larry** (calls on the
remembered backend, or brings a live call forward). Each is the link of the same name, so it does exactly what that
link does. A tap anywhere else opens the home screen.

The rules are the strip's:

- **Low is loud.** A bar under 20% left is orange, under 10% red.
- **Unspent is loud too.** With the week resetting in under a day and more than 20% left, the line leads with
  *N% to spend* in green. The tile works this out at the moment it is drawn, not when the reading was taken, so the
  nudge appears and goes on time even when the app has not been opened.
- **Old is loud.** The age is grey while the reading is under an hour old and orange after that. A half of the
  reading the Cockpit itself called stale is drawn as the strip draws it. A bar the Cockpit did not report is not
  drawn.
- **Before any reading:** a quiet *Open Grabber Native* with the app's name, never zeros. The medium tile still
  has its three buttons.

## How fresh it is

Whenever the app loads a reading (at launch, on coming to the front, every five minutes while open, after a tap to
refresh), the tile is told to redraw with it. A failed load changes nothing on the tile: it keeps the last reading
and its age keeps growing. Between loads the tile redraws by itself about every quarter hour, so the age and the
*to spend* nudge move on their own.

## Acceptance criteria

- After the app has loaded a reading, the small and medium tiles show the same bars and numbers as the strip, with
  the same orange and red, and *Nm ago*.
- An hour after the last load, the age is orange; a week due to reset in 13 hours with 31% left reads *31% to
  spend* in green, even if the reading was taken two days earlier.
- With the app never opened since install, the tile reads *Open Grabber Native* and shows no numbers.
- On the medium tile, Gym Timer, Breathe and Call Larry each open the app with the workout running, the session
  begun, or the call connecting; elsewhere on the tile opens the home screen.
