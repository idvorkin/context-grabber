# Native What's New: the app's recent changes, by day — Design Spec

Issue [#165](https://github.com/idvorkin/context-grabber/issues/165). Igor, 2026-10-06: *"Add what's new. Maybe
have it by day. Keep it up to date so I can remember."* Story
[148](../../stories/08-reporting-problems.md#user-story-148). Part of the
[Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The native app changes several times a day while journeys move over, and Igor installs builds faster than he can
remember what each one brought. The home screen gets a **What's new** row naming the latest day and its first
change; it opens a list of the last thirty days of changes, grouped by day, newest first. Nobody writes it: every
build makes it from the project's own history, so it is never stale and never forgotten.

## Goals

- Igor can see at a glance what the build on his phone brought, and look back a month.
- Each change reads as a person would say it, not as a commit message.
- It costs nothing to keep up: a change that is recorded the usual way (a story, a commit naming it) appears on
  its own.

## Non-goals

- Release notes for anyone but Igor; marketing copy; a badge or a pop-up after an update.
- Anything older than about a month.
- Changes to the React Native app.

## What counts as a change

- A change is a commit to the native app whose title names a user story: either it starts with *Story NNN*
  (the convention from 2026-10-06 on), or it ends naming its stories in brackets — *(story 133)*,
  *(stories 160-165)* — as the earlier native commits do.
- Bookkeeping is left out: the follow-up commits that only record a story's status, merges, work-in-progress
  commits and review fix-ups.
- The words shown are the story's own one-line summary when the change starts with its story; otherwise the
  commit's title without the story prefix or the bracketed list. A change that names an issue (in its title, or
  on its story) shows the issue number.
- One line per story per day: several commits for the same story on the same day are one change.
- The day is the local day the change landed, on the Mac that built the app.

## What Igor sees

**On the home screen**, above the launchers, one compact row: *What's new · Oct 5 — Think of a card opens Igor's
Think a Card Trainer*, with an **✕** at its end — **until it is dismissed** (Igor, 2026-10-06: *"release notes
should disappear once clicked, and then be in the settings"*, then *"give what's new an x button so I explicitly
dismiss it after builds"*). Tapping the row opens the list and leaves the row where it is; tapping ✕ dismisses it,
and it comes back only when a later build brings a change newer than the one dismissed. With nothing to show (no recent
changes, or a build made without the project's history) there is no row on the home screen.

**In the cog's sheet**, under *About and diagnostics*, *What's new* is always there, seen or not, and opens the
same screen.

**The What's new screen** has one section per day, newest first, headed by the weekday and date (*Monday, Oct
5*). Each change is a line of text with, under it in small type, the story and the issue it belongs to
(*Story 133 · #142*). **Every change opens its story** (Igor, iPad, 2026-10-08, #232: *"The what's new should
always link to the story so I can click on that"*): a tap on the line opens that user story, its use case and
acceptance criteria, on GitHub in Safari, at the story itself rather than the top of its journey. A line shows it
is a link (an arrow at its end). An empty list says there is nothing new in the last thirty days. Back returns
home.

## Explaining itself

Opening the screen is logged (`ui`, action open_whats_new), with how many days and changes it held and the
newest day. A tap on a change is logged (`ui`, action open_story) with the story and the address.

## Acceptance criteria

- A build lists the last thirty days of story changes, by day, newest first, with no one editing a list.
- A commit starting *Story NNN* shows that story's summary; a commit naming its stories in brackets shows its
  own title without them; status and merge commits never show.
- A commit whose title names no story still shows, under its own title, when its message names the story or its
  title names an issue that a story lists (#246); a commit that reaches no story by any of these does not show.
- The same story twice on one day is one line; on two days it is a line on each.
- The issue number shows when the commit or its story names one.
- The home row names the newest day and its first change, with an ✕; opening it keeps it, ✕ removes it until a
  newer change arrives, and a relaunch does not bring it back. With no history there is no home row.
- The cog's sheet always offers *What's new*; neither a missing nor an empty history breaks it or the screen.
- Tapping any change opens its story on GitHub, scrolled to that story; the log has `ui` open_story (#232).
