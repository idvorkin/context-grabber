# Native Home Screen: the launchers, and a cog for the rest — Design Spec

Issue [#166](https://github.com/idvorkin/context-grabber/issues/166). Igor, 2026-10-06: *"Add a settings cog on
the front page. There's just a lot of stuff here that I don't use."* Story
[147](../../stories/08-reporting-problems.md#user-story-147). Part of the
[Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The native app's home screen was a diagnostics list with the journeys on top: below the launchers sat the gist
token, the build, this launch's log and *Report a problem* — things Igor reads once a week, if that. The home
screen now holds only the launchers. A cog in the bottom right corner opens a **Home screen** sheet where each launcher can
be hidden or moved, and where the diagnostics now live.

## Goals

- The home screen is a list of things to open, nothing else.
- Igor chooses which launchers show and in what order, and the choice outlasts a relaunch and an update.
- A launcher added in a later build appears on its own, without Igor doing anything and without his earlier
  choices being lost.
- The build, the log, the gist token and *Report a problem* are one tap away, not gone.

## Non-goals

- Settings for the journeys themselves (the timer's voice, the call's backend): those stay on their own screens.
- Renaming launchers, icons, or grouping them into folders.
- Hiding a journey from anything but the home screen: links, Shortcuts, the widget and the launch hooks still
  open a hidden journey.

## What Igor sees

**The home screen.** No title (Igor, 2026-10-06: *"Get rid of grabber native title"* — the phone already says
which app this is, and the space goes to the rows), no bar across the top at all (*"Why dead space at the top of my screen"*), a
cog button in the bottom right corner (*"cog in bottom corner if anywhere"*), and the launchers as large rows
in Igor's order: Call Larry, Today, Gym Timer, Box breathing, Places, Think of a card, Cockpit until he changes
it. No header or footer around them: the old *Ported so far* / *Everything else is still in Context Grabber*
lines are gone, since every row is ported by definition. Anything that sits above the launchers in a later build
(a strip, a summary) stays above them. When every launcher is hidden, the home screen says so in one quiet line
and points at the cog.

**Not just a list** (Igor, 2026-10-07, #189: *"rework the home screen so it's not just a list"*; he chose the
*Today first* layout). Under the usage strip and What's new:

- **The Today card.** The mirror on the home screen: last night's sleep, today's steps, HRV and exercise
  minutes, each a big number with its name, and when they were read (*as of 7:10*). It shows the last grab the app
  made, so opening the app never asks Health for anything; tapping the card opens Today, which grabs fresh. Before
  any grab the card says *Today — tap to look* and opens Today the same way. A number Health did not give is a dash,
  never 0.
- **The first four launchers as tiles**, two by two, big enough to hit without looking: the first four of Igor's
  order (Today itself is skipped, since the card is Today). Each tile is the launcher's icon and name; Call Larry's
  tile still shows a live call's state.
- **The rest as rows** under the tiles, smaller than before, in the same order.

Order, hiding and Reset in the cog work as before: moving a launcher into the first four makes it a tile.

**The cog** opens the **Home screen** sheet, with *Done* at the top right. It has two parts:

1. **Launchers** — every launcher, shown or hidden, in the current order, each with its icon, its name and a
   switch. A switch off hides that row from the home screen at once; on brings it back in the same place.
   Rows are dragged by their handle to reorder; the home screen follows. A footer says hidden rows still open
   from links and Shortcuts. *Reset to default* puts every row back, in the default order.
2. **About and diagnostics** — what used to be the bottom of the home screen, unchanged: *Diagnostics uploads*
   (the gist token, with its line saying whether one is saved), *Build* (commit, branch, version), *This launch*
   (the log's name and when it started, and where to find logs in Files), and *Report a problem* with its
   reminder that a shake works on any screen.

**Shake to report** still works everywhere, including with the sheet up; the report names the screen as
*home_settings*.

## Remembering

- The order and the hidden set are remembered on the phone, with the app's other settings, and survive a
  relaunch and an update.
- A launcher the remembered order does not know (one added by a later build) is shown, at the end.
- A remembered launcher the build no longer has is ignored, and forgotten at the next change.
- If nothing can be remembered (the settings could not be opened), the home screen shows the default order and
  changes last until the app closes.

## Explaining itself

- Opening the sheet is logged (`ui`, action home_settings).
- Every change — a switch, a move, a reset — is logged with the full order and the hidden list as they now
  are (`ui`, action home_rows), so a log says what the home screen looked like.

## Acceptance criteria

- The home screen shows only the launchers (and anything placed above them), with a cog in the bottom right corner and nothing above the first card but the status bar.
- Hiding a row through the cog removes it from the home screen; after a relaunch it is still hidden.
- Moving a row through the cog moves it on the home screen; after a relaunch the order holds.
- Reset brings back every row in the default order.
- A launcher unknown to the remembered order shows at the end; a forgotten one does not break anything.
- The build, the log, the gist token and *Report a problem* are reachable from the sheet, and a shake with the
  sheet up files a report.
- A hidden journey still opens from its link, Shortcut or launch hook.
