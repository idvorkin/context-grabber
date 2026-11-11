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
  minutes, each a big number with its name, and nothing above them: no heading, drawing, time or arrow (Igor,
  2026-10-17, #355: *"Today header adds nothing, just the content"*). When they were read (*as of 7:10*) is still
  read out by VoiceOver with the numbers. It shows the last grab, and
  each time the app comes to the front it grabs again in the background, so the numbers are current without a tap
  and nothing waits on it: the old numbers stay until the new ones land (Igor, 2026-10-17, #355: *"make sure it runs
  async in the background so I never block the user"*). That refresh runs only once Health has been asked for
  everything the grab reads, so opening a fresh install (or a build that reads something new) never asks Health
  for anything; tapping the card opens Today, which grabs fresh. Before
  any grab the card says *Today — tap to look* and opens Today the same way. A number Health did not give is a dash,
  never 0.
- **Three to a row** (Igor, 2026-10-11, reports #284–#286; superseding the four big tiles and the pairs of #225
  and #235). Every launcher under the Today card and the strip is the same small tile, three to a line, in Igor's
  order: Call, Timer, Breathe, Places, Card, Analyzer, Supermix, Cockpit, Song, Eulogy, Recent, Random, Report a
  problem. *Report a problem* opens the same report sheet a shake or Settings opens, so a report is one tap from home
  (Igor, 2026-10-17, #340: *"log a bug as an option or as a button on the main menu"*, #353: *"add an icon for
  bug"*); like any launcher, Settings can move or hide it. (Each first
  showed its icon above a one- or two-word name, *"put three under a row, use shorter words plus the icon"*; since
  the drawn art, the picture alone, below.) So Recent and Random
  sit side by side (#285). A hidden launcher closes the gap; a last line with fewer than three keeps the tiles the
  same size. Call Larry's tile still shows a call left running, as a small green badge in its corner — *calling…*, then the running time such as *2:05* — so it stays the size of its neighbours (the full line, with the backend and the voice, is on the Call screen). **Settings is the last tile** (#286:
  *"settings can be a button now"*), always there and never hidden, since it is the way back to a hidden
  launcher; the floating cog is gone.
- **How a launcher looks** (Igor, 2026-10-08: *"Doesn't it look bad? … think about making it good via
  design"*): each launcher has its own colour, and only its icon carries it, as a white glyph on a small rounded
  square, the way Settings draws its rows. The names are in the ordinary text colour, one size for every row so
  nothing shrinks to fit. Settings' list of launchers draws them this way; the tiles and the Today card show the drawn
  art below.
- **Drawn art on the tiles** (Igor, 2026-10-13, #304: *"custom icons … bigger tiles"*; settled 2026-10-17: keep
  three to a row, custom art for every tile, judge the size after). Each home tile shows its own picture and
  no name: the picture says what it is, so it fills the tile in the space a name took: each picture is cut close to its object, and the object takes up
  most of its tile, which stays the size it was (Igor, 2026-10-17, #354: *"tiles same size but icons take up more of
  it"*); the three metal objects (the Gym Timer's stopwatch, the Cockpit's gauge and Settings' gear) sit a little
  smaller than the rest, at about 85%, so they stop crowding their tiles (Igor, 2026-10-17, #362: *"Metal tiles,
  just a little bit smaller"*) (Igor, 2026-10-17: *"words
  are dups now"*, then *"no words"*). VoiceOver still reads each launcher's full name. Objects are painted as refined still-lifes, not cartoons
  (Igor, 2026-10-17: *"less cartoony on everything"*), with no background of their own: each object sits straight
  on its tile, so the art blends into the tile in light mode and in dark (Igor, 2026-10-17: *"more blended into the
  background, some kind of transparent, but still works when dark"*, replacing *"give all of them backgrounds the
  same color"*). No faces on things. The launcher's own colour stays on Settings' list. Every
  person is Igor, as the raccoon of his blog's eulogy post (rainbow glasses, green shirt, mismatched crocs, soft
  felt; *"people are always Igor from the blog"*). Call: Igor's raccoon on the phone. Today: a heart on a paper
  calendar. Timer: a steel stopwatch. Breathe: Igor's raccoon meditating in full lotus. Places: a folded map with a
  pin. Card: an ace of spades. Analyzer: the Exercise Analyzer app's own icon, the raccoon swinging a kettlebell on teal, with iOS's rounded corners, so the tile reads as "this opens that app" (Igor, 2026-10-17, #366: *"Make exercise analyzer the icon for launching it"*); the one tile that keeps a background, because it is that app's icon. Supermix: a kettlebell wearing big leather headphones, a smaller one behind it (Igor, 2026-10-18, #382: *"super mix should probably have kettle bells with headphones"*). Cockpit: a dashboard
  gauge. Song: a gravestone carved IGOR, wearing big, bold headphones. Eulogy: a gravestone carved IGOR above a small heart
  (Igor, 2026-10-17: *"make headphones more pronounced, write Igor on both stones"*). On both stones IGOR is the
  first thing the eye finds: large letters across most of the stone, cut deep and dark against the pale stone, readable
  at tile size (Igor, 2026-10-17, #363: *"Make the Igor on the eulogy ones more pronounced so it's very obvious"*). Recent: a fan of freshly printed
  pages with a red ribbon, so it is not a third round dial beside Timer's stopwatch and Cockpit's gauge. Random: dice. Report a problem: a beetle, drawn like a museum specimen. Settings: a brass gear. Settings'
  list of launchers keeps the small glyph squares. Which of the drawings each tile shows is Igor's call and can
  change at any time.

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
- **Balloons** — a count of balloons made for others today, shown as a balloon poodle drawn in outline, one balloon
  segment per body part, with a domed head, a pom-pom and a forward snout (Igor, #287, #299, 2026-10-17)
  and the number. A tap adds one; a press and hold opens its week
  (below), where a − takes one off. A soft tick on each change.
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

**An earlier day** (Igor, #290; two-week grid approved 2026-10-20, #414). Press and hold Gym,
Meditation or Journal to open a two-week editor. Its header has Cancel, the item's name and an accent-filled
Done button. Fourteen tiles fill seven columns and two rows, oldest at top left and today at bottom right.
Each tile shows the weekday letter and date number; today and yesterday add “today” and “yest.” tags.
Done days have an accent fill, other days a dark fill, today a subtle outline, and days changed since opening
an orange ring. Tiles are at least 44 points tall (normally 64), with full-date accessibility labels saying
whether the day is done, and a selected trait for done days.

The headline says “N of the last 14 days”. Under it, “Last done today”, “Last done yesterday”,
“Last done K days ago”, or “Last done not in two weeks” reflects the edited days. Unsaved edits append
“ · K change(s) to save”, with singular wording for one. A legend shows done and changed swatches and
“Tap a day to mark or unmark it”. Tapping toggles a day locally, including taking a tapped day back;
a check supplied by the timer, breathing or Health stays, just as on today's strip. Health's strength workouts
supply Gym's days across all fourteen tiles, not only the last week's (#435). Done saves every changed
day and closes; Cancel or dismissing saves nothing. Taking a tapped day back syncs with the same latest-change-wins
rule as today's un-tap. The strip and Gym's days since update immediately after Done.
Balloons and Magic still open their week (below). Each changed day saved produces one `ui` event, action
daily_strip, with the item, the day, `backdated` and `done` true or false.

**The same strip on the phone and the iPad** (Igor, iPad, 2026-10-17, #376: *"Do stats sync over Cloud kit like the
did I do magic if not implement"*). What Igor marks on one device shows on the others signed into his iCloud,
usually within a minute, and offline changes catch up when the device is back online:

- A check (Gym, Meditation, Journal) done on any device is done everywhere, today or an earlier day, and taking a
  tapped check back on any device takes it back everywhere: the latest change wins.
- Counts add up across devices: a balloon on the iPad and two on the phone make 3 on both. A − in a counter's week
  takes one off the device's own count, so a day never goes below what the other devices counted.
- Days since follows the shared days, so a journal day written on the phone ends the iPad's *3d* too.
- Gym and Meditation turning green by themselves (the Gym Timer, Box breathing, Health) work on each device as
  before and stay on the device where they happened: a timer workout on the phone does not turn the iPad's Gym
  green.
- The first time a device syncs, its last twelve months go up too, so the iPad learns the past year of the phone's
  history. Older days stay on the device that has them (iCloud's store for this is small).
- After the app is reinstalled, its own days come back from iCloud instead of being overwritten, and a count
  tapped before iCloud has caught up, however long that takes offline and even across a restart of the app, adds
  to the count that comes back: three balloons in iCloud and one tap make four, and a − at 0 takes
  nothing off (#380). When iCloud has nothing to send back (no device has synced the strip yet), five minutes in a
  row online with the app open count as caught up and the device starts syncing; time offline or in the background
  never counts.
- If the phone cannot take back what iCloud holds (its database refuses the write), it sends nothing and tries
  again later, so iCloud's days are never replaced by a partial copy.
- The strip's days sit in iCloud unencrypted beyond what iOS and iCloud already do on disk and in transit (Igor,
  2026-10-18: small app state, a personal build). Anything more sensitive, or an App Store build, encrypts first.
- Without iCloud (signed out, or iCloud Drive off for the app) the strip works as before on that device alone, and
  nothing says otherwise beyond the log.

The log says what the sync did: a device publishing its days (how many months), and another device's change
arriving (which device, which months), and why a sync could not run.

**A counter's week** (Igor, 2026-10-17, #342: *"If I press and hold on my daily habit strip What's up Yesterday or
today Like a count"*; 2026-10-18: press and hold, and make it the whole week, with check marks on the days before).
Press and hold Balloons or Magic and a sheet opens on that counter's last seven days, all at once: today at the top,
then yesterday, then the five before, each labelled in words and with its date (*today · Sun, Oct 18*, *yesterday ·
Sat, Oct 17*, *3 days ago · Thu, Oct 15*). Each day shows its count with − and + beside it (never below 0) and a check mark when
the count is above 0, so the days with a balloon read at a glance and a forgotten one can be added to the day it was
made. The changes stay in the sheet until *Confirm*, which saves every day changed and closes it; *Cancel*, or
swiping the sheet away, changes nothing. Today's number on the strip and the days since follow at once. Days older
than the week are not shown here. This replaces the counters' long press for one fewer: one fewer is today's − in
the sheet. The log has one `ui` event per day changed, action daily_strip, with the item, the day, the new value and
`backdated` when the day is not today.

Non-goals: choosing other items or adding new ones from the app, streaks, reminders, history charts.

Order, hiding and Reset in Settings work as before.

**The Settings tile** (once the cog) opens the **Home screen** sheet, with *Done* at the top right. It has three parts:

1. **Launchers** — its own page (#302: *"launchers on its own page under settings"*): the sheet's first row,
   *Launchers*, opens it, with *Done* still at the top right. It lists every launcher, shown or hidden, in the current order, each with its icon, its name and a
   switch. A switch off hides that row from the home screen at once; on brings it back in the same place.
   Rows are dragged to reorder; the home screen follows. On the Mac a row is dragged with the pointer: pressing
   anywhere on the row but its switch and dropping it on another row puts it in that row's place (#742: *"get rid
   of up down and just support dragging"*). The Move up / Move down arrows that #714 added while the pointer drag
   did nothing are gone, and the footer says to drag on every device. A footer says hidden rows still open
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
- On the Mac, dragging a launcher with the pointer and dropping it on another row moves it to that place in the list
  and on the home screen; the drag never flips a switch, and the list shows no arrows (#742, replacing #714's).
- Reset brings back every row in the default order.
- A launcher unknown to the remembered order shows at the end; a forgotten one does not break anything.
- The build, the log and *Report a problem* are reachable from the sheet, and a shake with the
  sheet up files a report.
- *About* in the sheet shows the name, version (build) and commit of the build that is running, and both of its
  links open the commit and the repository on GitHub (#303).
- A hidden journey still opens from its link, Shortcut or launch hook.
- Every launcher under the Today card and the strip is the same small tile, three to a line in the remembered
  order, its drawn picture with no name under it (VoiceOver reads the name); a last line with fewer than three keeps the tiles the same size, and
  *Settings* is always the last tile (#284–#286).

- The daily strip shows Gym, Meditation, Journal, Balloons and Magic in one line under the Today card. A tap checks Gym or
  Journal (a second tap unchecks). A tap adds a balloon or a trick; a press and hold opens that counter's week.
  Gym shows days since the last gym day until today counts, and a finished Gym Timer workout counts today with
  no tap. Meditation and Journal show days since their last day the same way, and Balloons and Magic show it in
  place of a 0 (*–* when there has never been one). After midnight everything starts fresh and yesterday's values are kept (#236, #238).
- After a Box breathing session reaches Done, or a grab that finds mindful minutes today, Meditation is green
  with no tap, and the log has `daily_strip_auto` naming where it came from (#257).
- A check or a count made on the phone shows on the iPad within about a minute, and the other way round; counts
  add up across the devices, and days since follows the shared days (#376).
