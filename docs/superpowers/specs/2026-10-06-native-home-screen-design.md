# Native Home Screen: the launchers, and Settings for the rest — Design Spec

Issue [#166](https://github.com/idvorkin/context-grabber/issues/166). Igor, 2026-10-06: *"Add a settings cog on
the front page. There's just a lot of stuff here that I don't use."* Story
[147](../../stories/08-reporting-problems.md#user-story-147). Part of the
[Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The native app's home screen was a diagnostics list with the journeys on top: below the launchers sat the gist
token, the build, this launch's log and *Report a problem* — things Igor reads once a week, if that. The home
screen now holds only the launchers. A *Settings* tile, the last one, opens a **Home screen** sheet where each launcher can
be hidden or moved, and where the diagnostics now live.

## Goals

- The home screen is a list of things to open, nothing else.
- Igor chooses which launchers show and in what order, and the choice outlasts a relaunch and an update.
- A launcher added in a later build appears on its own, without Igor doing anything and without his earlier
  choices being lost.
- The build, the log and *Report a problem* are one tap away, not gone. (The gist token went with the gist,
  2026-10-11: a troubled call files an automatic report instead.)

## Non-goals

- Settings for the journeys themselves (the timer's voice, the call's backend): those stay on their own screens.
- Renaming launchers, icons, or grouping them into folders.
- Hiding a journey from anything but the home screen: links, Shortcuts, the widget and the launch hooks still
  open a hidden journey.

## What Igor sees

**The home screen.** No title (Igor, 2026-10-06: *"Get rid of grabber native title"* — the phone already says
which app this is, and the space goes to the rows), no bar across the top at all (*"Why dead space at the top of my screen"*), the
launchers and, after them, a *Settings* tile (a cog in the bottom right corner until #286), the launchers
in Igor's order: Call Larry, Today, Gym Timer, Box breathing, Places, Think of a card, Cockpit until he changes
it. No header or footer around them: the old *Ported so far* / *Everything else is still in Context Grabber*
lines are gone, since every row is ported by definition. Anything that sits above the launchers in a later build
(a strip, a summary) stays above them. When every launcher is hidden, the home screen says so in one quiet line
and points at Settings.

**Not just a list** (Igor, 2026-10-07, #189: *"rework the home screen so it's not just a list"*; he chose the
*Today first* layout). Under the usage strip and What's new:

- **The Today card.** The mirror on the home screen: last night's sleep, today's steps, HRV and exercise
  minutes, each a big number with its name, and when they were read (*as of 7:10*). It shows the last grab the app
  made, so opening the app never asks Health for anything; tapping the card opens Today, which grabs fresh. Before
  any grab the card says *Today — tap to look* and opens Today the same way. A number Health did not give is a dash,
  never 0.
- **Three to a row** (Igor, 2026-10-11, reports #284–#286; superseding the four big tiles and the pairs of #225
  and #235). Every launcher under the Today card and the strip is the same small tile, three to a line, in Igor's
  order: its icon above a one- or two-word name (*"put three under a row, use shorter words plus the icon"*): Call,
  Timer, Breathe, Places, Card, Analyzer, Supermix, Cockpit, Song, Eulogy, Recent, Random. So Recent and Random
  sit side by side (#285). A hidden launcher closes the gap; a last line with fewer than three keeps the tiles the
  same size. Call Larry's tile still shows a call left running, as a small green badge in its corner — *calling…*, then the running time such as *2:05* — so it stays the size of its neighbours (the full line, with the backend and the voice, is on the Call screen). **Settings is the last tile** (#286:
  *"settings can be a button now"*), always there and never hidden, since it is the way back to a hidden
  launcher; the floating cog is gone.
- **How a launcher looks** (Igor, 2026-10-08: *"Doesn't it look bad? … think about making it good via
  design"*): each launcher has its own colour, and only its icon carries it, as a white glyph on a small rounded
  square, the way Settings draws its rows. The names are in the ordinary text colour, one size for every row so
  nothing shrinks to fit. The same icons are on the Today card and in Settings' list of launchers.
- **Drawn art on the tiles** (Igor, 2026-10-13, #304: *"custom icons … bigger tiles"*; settled 2026-10-17: keep
  three to a row, custom art for every tile, judge the size after). Each home tile shows its own hand-drawn
  picture, in one family (gouache and crayon on the launcher's colour), larger than the old glyph square, above
  the same short name: Igor's own raccoon on the phone for Call, in the look of the eulogy post's raccoons (rainbow glasses, green shirt, mismatched crocs, soft felt; Igor, 2026-10-17: *"not Larry, should be Igor, like from the blog in eulogy, that look"*), a heart on a calendar
  for Today, a stopwatch for Timer, someone sitting in full lotus for Breathe, a map with a pin for Places, an ace of spades for Card, a kettlebell and chart for Analyzer,
  headphones for Supermix, a gauge for Cockpit, a gravestone wearing headphones for Song, a gravestone for Eulogy
  (Igor, 2026-10-17), a clock
  with an arrow for Recent, dice for Random and a gear for Settings. Settings' list of launchers keeps the small
  glyph squares. Igor picks among three drawings of each; until he does, the first is shown.

**The daily strip** (Igor, iPad, 2026-10-10, #236: *"a little strip for things I want to do every day, like gym,
and that can get a checkmark … an up/down counter somehow that's still small. I want this all in one strip"*;
#238: *"days since gym"*). One thin card, one line tall, between the Today card and the tiles: the few things Igor
means to do every day, each a glance and a tap.

- **Gym** — a check. Grey with *3d* beside it when the last gym day was three days ago; green ✓ once today counts.
  Today counts when Igor taps it, when the Gym Timer finishes a workout, or when Health has a strength workout
  today. Days since gym counts from the last day that counted, by any of the three; *never* before the first.
- **Meditation** (Igor, 2026-10-10, #257: *"need a meditation in my thing too"*) — a check that, like Gym, turns
  green on its own: when a Box breathing session reached Done today, or when Health had mindful minutes today at
  the last grab (any meditation app; the app's own breathing writes them too). A tap is the fallback, and a tap
  can be taken back; a check from breathing or Health stays. A session in another app shows once Today has grabbed,
  because opening the home screen asks Health nothing.
- **Journal** — a check, shown as a drawn quill pen (Igor, #287, #299): a tap marks today written; another tap
  takes it back.
- **Balloons** — a count of balloons made for others today, shown as a drawn balloon poodle of few segments, one
  per body part (Igor, #287, #299, 2026-10-17)
  and the number. A tap adds one; a long press takes
  one off (never below 0). A soft tick on each change.
- **Magic** — the same counter, for magic done for others: 🪄 and the number.

**Days since, on every item** (Igor, 2026-10-17: *"Everything on my daily habits lists, like balloons, should have
the same days, since I have for exercise"*). Each item says how long it has been, as Gym does: until today counts,
Meditation and Journal show grey *3d* beside the icon when the last day was three days ago, and *–* before the
first. Balloons and Magic show today's number once it is above 0; at 0 they show the days since the last day
with any, in the same grey (*2d*, or *–* before the first), in place of the 0. Meditation's last day counts a tap
or a Box breathing session that reached Done; Health's mindful minutes count only for today, as now. VoiceOver
reads the same: "3 days since", "never".

Every item starts the day fresh at local midnight; the days before are kept, so the week can be read later (by
Larry, in the export: a later change, not this one). A tapped gym check can be taken back the same way as the
journal's; a check that came from the timer or Health stays. Every change is in the session log (`ui`, action
daily_strip, with the item and its new value), and so is each item turning green by itself (`daily_strip_auto`,
with the item and where it came from). The strip can be hidden from Settings like a launcher.

**An earlier day** (Igor, 2026-10-11, #290: *"Press and hold on a day strip element gives a slider on days since
forward or backwards. Then confirm to say you did it yesterday. It's a one and done"*). Press and hold Gym,
Meditation or Journal and a small sheet asks which day: a slider from today back two weeks, starting on
*yesterday*, its label the day in words and its date (*yesterday · Sun, Oct 11*, *3 days ago · Fri, Oct 9*).
*Confirm* marks that day done and closes the sheet; *Cancel* closes it with nothing changed. Gym's days since
follows at once (a gym day yesterday reads *1d*). Marking is all it does: an earlier day is not taken back here.
The counters keep their long press for one fewer. The log has `ui`, action daily_strip, with the item, the day
and `backdated`.

Non-goals: choosing other items or adding new ones from the app, streaks, reminders, history charts.

Order, hiding and Reset in Settings work as before.

**The Settings tile** (once the cog) opens the **Home screen** sheet, with *Done* at the top right. It has three parts:

1. **Launchers** — its own page (#302: *"launchers on its own page under settings"*): the sheet's first row,
   *Launchers*, opens it, with *Done* still at the top right. It lists every launcher, shown or hidden, in the current order, each with its icon, its name and a
   switch. A switch off hides that row from the home screen at once; on brings it back in the same place.
   Rows are dragged by their handle to reorder; the home screen follows. A footer says hidden rows still open
   from links and Shortcuts. *Reset to default* puts every row back, in the default order.
2. **About and diagnostics** — what used to be the bottom of the home screen: *Build* (commit, branch, version), *This launch*
   (the log's name and when it started, and where to find logs in Files), and *Report a problem* with its
   reminder that a shake works on any screen.
3. **About** (#303, the same page in every one of Igor's apps): a row that opens the app's name, its version and
   build, the commit it was built from as a link to that commit on GitHub, and a link to the repository. A build
   from uncommitted changes says so and links the commit underneath. A value the build did not record reads
   *Unknown*, and its link is left out.

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

- The home screen shows only the launchers (and anything placed above them), with a Settings tile after them and nothing above the first card but the status bar.
- Hiding a row through Settings removes it from the home screen; after a relaunch it is still hidden.
- Moving a row through Settings moves it on the home screen; after a relaunch the order holds.
- Reset brings back every row in the default order.
- A launcher unknown to the remembered order shows at the end; a forgotten one does not break anything.
- The build, the log and *Report a problem* are reachable from the sheet, and a shake with the
  sheet up files a report.
- *About* in the sheet shows the name, version (build) and commit of the build that is running, and both of its
  links open the commit and the repository on GitHub (#303).
- A hidden journey still opens from its link, Shortcut or launch hook.
- Every launcher under the Today card and the strip is the same small tile, three to a line in the remembered
  order, its icon above a short name; a last line with fewer than three keeps the tiles the same size, and
  *Settings* is always the last tile (#284–#286).

- The daily strip shows Gym, Meditation, Journal, Balloons and Magic in one line under the Today card. A tap checks Gym or
  Journal (a second tap unchecks). A tap adds a balloon or a trick, a long press takes one off, never below 0.
  Gym shows days since the last gym day until today counts, and a finished Gym Timer workout counts today with
  no tap. Meditation and Journal show days since their last day the same way, and Balloons and Magic show it in
  place of a 0 (*–* when there has never been one). After midnight everything starts fresh and yesterday's values are kept (#236, #238).
- After a Box breathing session reaches Done, or a grab that finds mindful minutes today, Meditation is green
  with no tap, and the log has `daily_strip_auto` naming where it came from (#257).
