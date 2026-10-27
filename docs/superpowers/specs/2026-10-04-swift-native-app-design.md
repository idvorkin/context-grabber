# Swift-Native App — Design Spec

**Status:** Drafted 2026-10-04; direction agreed with Igor the same day
**Owner:** Igor
**Tracking:** bead `context-grabber-3ss` (one child per step)
**Supersedes:** [OTA-first architecture](2026-09-07-ota-first-architecture-design.md) once the cutover lands

## Summary

Igor, 2026-10-04: *"look at ../exercise-analyzer, and see how it does logging for bugs and test and user
stories. Then convert this project to be swift native."* And: *"feel free to re-write stuff as required."*

Context Grabber becomes a native iOS app. A second app, **Grabber Native**, is built beside the current one and
lives on the phone next to it. It gains one journey at a time; Igor uses each on the phone before the next
starts. When it does everything the current app does, it takes the current app's place and the old one is
removed.

From its first build the native app explains itself the way Exercise Analyzer does: one log per launch, a
shake to report a problem, crashes that come back with the logs, and a Mac that files the reports as issues.

## Decisions (Igor, 2026-10-04)

| Question | Answer |
|---|---|
| Over-the-air updates | Given up. Every change reaches the phone as an install from the Mac. |
| How to get there | A new app beside the old one, then a cutover. Not screen-by-screen inside the old app, not a big bang. |
| The Cockpit tab | Critical. It is ported, with real microphones and outputs. |
| Uploading a log as a private gist | Replaced 2026-10-11 (Igor): a troubled call files an automatic report on the phone, which the Mac's listener files as an issue once it can reach the phone. No token on the phone, nothing on GitHub until the Mac files it, nothing to clean up. |
| Line-by-line port | No. Rewrite where a native design is better; the stories are what must stay true. |
| The React Native code | Removed from the repository, 2026-10-17 (Igor: *"we can erase the React Native code from this repo, we don't really need it"*). The old app on the phone keeps running its last build and its data stays where it is until the cutover, but it can no longer be fixed or rebuilt. Where the native app was checked against the TypeScript, the expected results committed with the native tests are now the record. |

Found while scoping: journal and role-moment sync through iCloud is in use, so it is ported. The old
grid-based place clustering is not used by the app and is not.

## Goals

- Everything in [the stories](../../stories/README.md) that is implemented today works in the native app, judged
  story by story.
- A problem on the phone reaches a GitHub issue with its evidence in two commands, without Igor copying text.
- The current app keeps working, unchanged, until the cutover (since 2026-10-17 it has no source in the repository: it is never changed again).
- Nothing on the phone is lost at the cutover: location history, known places, the journal, role moments,
  settings, the widgets' state.

## Non-goals

- New features during the port. A journey is ported as its stories describe it; requests that come up become
  stories and wait.
- Android, the web, Mac Catalyst.
- Keeping both apps in step. The old app gets no new work except a fix Igor asks for.

## What Igor sees, step by step

Each step ends with a build on the phone and Igor using it.

| Step | What the native app can do after it |
|---|---|
| 1 | Opens; shows which build it is; keeps a log of every launch; a shake (or a button) files a problem with a screenshot; a crash is reported at the next launch. Nothing else yet. |
| 2 | The Gym Timer: presets, cues in Igor's voice, music that keeps playing, the LED face and the turn, the accessory log. |
| 3 | Calling Larry: the call that survives the lock, voices, the call's diagnostics in the same log, an automatic report when a call goes wrong. |
| 4 | The mirror (Today, Body, Move, Mind and their detail sheets) and Grab Context. The export is the same JSON, byte for byte, as the current app's for the same data. |
| 5 | Places: background location, stays, known places, the map, the database export. |
| 6 | Roles and the journal, synced through iCloud, with voice entries. |
| 7 | Widgets, links and Shortcuts open the native app; the Cockpit tab. |
| 8 | Cutover: the native app becomes Context Grabber. The old app is replaced in place and its data is there on first open. |

Until step 8 the native app is a separate app with its own name, its own Health and location
permissions, and no access to the old app's data. Journeys that need history (places, the journal) can import
the old app's database export.

## Explaining itself (step 1)

**The session log.** Every launch starts a new log that the app writes as it goes: what started, what the user
did that matters, what failed, with the numbers that decide a question as numbers. It names the build it came
from. It is visible in the Files app and comes to the Mac with one command. Logs older than thirty days are
deleted at launch, except a log a problem report names.

**Reporting a problem.** A shake anywhere, or *Report a problem* behind the home screen's cog, opens a sheet with
one text field — **over whatever is in front**, a settings sheet, a picker or any other of the app's own dialogs
included (Igor, 2026-10-06, #182: *"I can't rage shake when a dialog is up"*); the dialog is still there after
the report is logged or cancelled, and the picture shows it. Only iOS's own alerts (a permission prompt) are out
of reach. The sheet has a list of what will be attached. *Log it* stores the note, a picture of the screen as it was
at the shake, the screen Igor was on, the build, and the name and moment of the session log. On the Mac the
report becomes one GitHub issue with the note and the context; filing twice never makes two issues.
*Log it and another*, right under the note where the keyboard cannot hide it, stores the report exactly the same way and opens a fresh, empty
report straight away, with a new picture of the screen underneath, so several problems can be filed in a row
without shaking again (Igor, 2026-10-07). **Speak the note** (Igor, 2026-10-08, #239: *"Add mic input to logging
dialog"*): a microphone button beside the note. One tap and what Igor says appears in the note as he says it, the
way dictation does, recognised on the phone; a second tap, *Log it*, or closing the sheet stops it. It adds to what
is already typed rather than replacing it, and a pause in speaking never replaces what was said before it (Igor,
2026-10-10, #249: *"When I stop talking the input gets replaced"*). The first use asks iOS for speech recognition (and the microphone, if not
yet granted); a refusal, or a phone that cannot recognise speech, leaves the button showing why when tapped, and
typing still works. During a Larry call the button is off, since the call holds the microphone. Dictating never
stops music or a podcast that was playing, and the Gym Timer's sound carries on afterwards as it was. Each start
and stop, each pause the recogniser started over after, and any failure, goes into the session log. The
picture stays on the Mac and the issue says where: the issues are public, and a screen can show health, places
or the journal.

**A report reaches the Mac away from it** (Igor, 2026-10-11, the BugKit 0.3.0 train). Every report saved from now
on, shaken or automatic, also goes up to Igor's own private iCloud, and the Mac's listener takes it from there on its
next poll and files it as it would one pulled off the phone. So a problem logged at the gym on cellular becomes an
issue without the phone ever coming near the Mac. It is on by default, with no switch. Saving is instant and never
waits for the network; when there is no signal, or iCloud is signed out, the report waits on the phone and goes up
the next time the app runs with a connection. Reports saved before this build stay on the phone for the Mac to pull
as before, and are never uploaded. A report too big for iCloud (over 20 MB of attachments) also stays on the phone
for the pull. Each upload, wait and failure is in the session log. Filing twice still never makes two issues,
whichever way a report arrives.

**A gentle shake is enough** (Igor, 2026-10-06, #164: *"let it work with less aggressive shakes"*). iOS's own shake
gesture wants a hard shake. The app also listens to the motion itself: a quick back-and-forth — three changes of
direction within a second, each flick at least about 1.5 g (Apple does not publish its own threshold; this one
is tuned from the log) — opens the report. Walking, a
jog, setting the phone down or a bump on the gym bench is not a shake. A hard shake still works as before, and
one shake opens one sheet. Each shake the app catches is in the session log with how hard it was, so the
threshold can be tuned from real shakes.

**Reset audio** (Igor, 2026-10-06: *"give me a reset audio under settings as it gets into a bad state phone
wide"*). The home screen's cog has a **Reset audio** button. It lets go of everything Grabber Native holds on the
phone's audio — its session, any ducking of other apps, a forced speaker, a chosen microphone — and tells other
apps they may resume, so music left ducked or paused after a call, a workout or a breathing session comes back.
Under the button it shows what the phone's audio was and is now (the route, whether other audio is playing). It
is not offered while a call is live: ending the call is the reset then. It cannot reset another app's audio or the
phone's audio service itself; if the phone is still wrong after it, restarting the phone is the remaining fix, and
the line under the button says so.

**Crashes.** When the app crashed or hung, the next launch's log says so and names a file with the stack; the
file comes to the Mac with the logs.

**Every error on screen** still carries a way to hand it over: the error is in the log with the state around
it, and the shake attaches that log. The copy-to-clipboard button stays where Igor is likely to be away from
the Mac (the call).

**Which build.** The home screen's cog shows the commit and branch the build was made from. The log's first
line carries the same.

## On the iPad

Igor, 2026-10-07: *"Will this work on iPad as well? Enable iPad version."* Grabber Native installs on the iPad
as an iPad app, not a magnified phone app: the screens fill the iPad's width and turn with it, every way; the
phone stays upright. Every journey opens and works. Some are the phone's by nature and say less on the iPad:

- **Today** reads the iPad's own Health, which holds little unless the iPad shares in iCloud Health.
- **Places** records where the iPad goes, which is usually nowhere; the phone's history is not on the iPad.
- **The live tile and Shortcuts** work as on the phone. The Gym Timer's Live Activity has no Lock Screen on the
  iPad to show on, so the timer simply runs in the app.
- **Calls, the Cockpit, breathing, the timer, the blog's launchers and the report shake** work as on the phone
  (a shake of an iPad is unlikely; *Report a problem* behind the cog is the way).

The iPad keeps its own settings, log and reports; they are not shared with the phone.

## Think of a card: the trainer's screen, in the app

Igor, 2026-10-08 (#219): *"Think of a card. Let's do it inline. I don't think it's worthy of its own app."* Then,
the same day: *"I want ThinkCard from the ThinkCard native app. I think that was better, maybe with a shared
library."* So the card screen in Grabber Native is Think a Card Trainer's own phone screen, shared between the two
apps rather than copied, and it behaves as the trainer's phone stories say (its journeys 01 to 04):

- **Black, one card large**, red suits red, dealt from Igor's memorized stack: every card once per pass, never the
  same card twice running.
- **A tap on the middle of the screen** switches the card at once, silently.
- **A tap on the right third is the ask**: the card stays up with a small count at the side, three, two, one, then
  a new card face up, a light tap of the phone, and the card said aloud (in Igor's voice clips when the build has
  them, otherwise the phone's voice). A tap during the count cancels it and the card stays.
- **A tap on the left third** is the same ask, drawn only from the hard cards (clear of the breathers).
- **Skip easy cards**, a switch under the card, leaves the breathers and two either side of each out of every deal.
  Grabber Native keeps its own setting; the trainer app keeps its.

What Grabber Native adds around it: **Done** at the top goes home, a shake reports a problem as on every other
screen, and the home screen's **Think of a card** (and `grabbernative://card?think=1`) opens it with the ask
already started. **During a live call** the card is never spoken: it is dealt and shown, silently, so the call keeps
the audio. If the build has no stack, the screen says so with a copyable error instead of a card.

The stack order is never in this repository: the build copies it in from the same private file the trainer uses.

**Drill the stack** (Igor, 2026-10-18: the trainer's drill, graded, with its stats, in this app too; the trainer's
stories 064–069). Under the card, beside *Skip easy cards*, *Drill the stack* stops an ask that is counting and
covers the screen with the trainer's own drill, the same one as in the trainer app:

- **Card → position, Position → card, or Mixed**: the question fills the top; a tap shows the answer under it (with
  the breather it counts from), the next tap counts it **right** and deals the next, and **Wrong** under the answer
  counts a miss instead. Every card once per pass, never the same twice running.
- It follows *Skip easy cards* as it was when the drill opened: on, only the hard positions are drilled.
- **Every graded answer goes to Igor's practice ledger**, the same one the trainer and Card Picker write to. Offline,
  answers wait on the phone and go when the ledger can be reached; nothing is lost by closing the app.
- **Stats**, at the top of the drill, shows what the ledger knows over 30 days from every source, the most missed
  positions first, and holds the ledger's URL and write key. They are pasted once in Grabber Native; the build never
  carries them, and the trainer app keeps its own copy.
- The log says what was pressed and what each send did, never a card beside its position, and never the key.
- **Done** returns to the card.

## Exercise Analyzer, one tap away

Igor, 2026-10-05 (#142): *"You should also be able to launch Exercise Analyzer."* The home screen lists **Exercise
Analyzer** under *Think of a card*; it opens Igor's Exercise Analyzer app where it was (that app's story 069). If it
is not installed, the row says so instead of doing nothing.

## Workout Supermix, one tap away

Igor, 2026-10-08 (#220): *"I want to open my YouTube Music Workout Super Mix as well."* The home screen lists
**Workout Supermix**, after *Exercise Analyzer*. It used to run Igor's own *Play Workout Supermix* shortcut from
the Shortcuts app, so YouTube Music played the mix (now replaced by the direct link below).

**Straight to the mix** ([#372](https://github.com/idvorkin/context-grabber/issues/372)), Igor, 2026-10-17:
*"I meant for the YouTube workout super short link. Super mix link."* Going through Shortcuts flashed the Shortcuts
app in front first. The tile now opens Igor's Workout Supermix link directly: a track in YouTube Music that runs
his mix from there, in the YouTube Music app, or in the browser if the app is not installed. The shortcut is no
longer used. The log says which opened (the app or the browser).

**Press and hold for another mix** ([#383](https://github.com/idvorkin/context-grabber/issues/383)), Igor,
2026-10-18: *"I should also be able to press and hold on music and then when I lift my finger select one and I
should have likes and Feel Good Supermix."* A tap still opens the Workout Supermix. A press and hold on the tile
offers three choices: **Workout Supermix**, **Liked music** (his YouTube Music likes) and **Feel Good
Supermix** (his link,
`https://music.youtube.com/playlist?list=RDTMAK5uy_nuKPeaybq-IRcrMnaR-5TIfvKxB7fVJu0`). Since #391 the hold opens a
popover of drawn choices instead of a list (the Workout Supermix's own kettlebell in headphones, a heart for Liked
music, a sun for Feel Good; Apple's headphones, heart and sun stood in on the list before it), and a tap on one opens
it (spec 2026-10-18-press-and-hold-popovers-design.md); a tap outside opens nothing. Each opens in YouTube Music, or the browser
without it, and the log names the mix and which opened. A mix that opens in neither (a tap or the popover) shows a
copyable problem under the tiles, naming the mix and its link, until the next try or a newer message.

## The Gym Timer in the native app (step 2)

The timer does what stories 100–116 say, with these differences while the two apps live side by side:

- **It opens from the native app's home screen**, full screen, and *Done* returns there.
- **The timer's log is the session log.** What the audio session, the duck window, the cues and the phases did is
  written there as events, so a shake attaches it. The *Log* button stays for the gym, where the Mac is not: it
  copies this launch's timer events behind a build line.
- **The preset chips are inert from START until RESET or the finish**, like the Custom sliders. In the current
  app a chip tapped mid-run silently changes the workout under the running clock.
- **A boundary is called within a tenth of a second of its true time.** The current app looks once a second, so
  a cue can be most of a second late.
- **A phone call mid-workout**: when the call ends the timer takes its audio back and keeps speaking.
- **With no rest, every round is still called.** A Custom preset with Rest 0:00 says *go* at the start of each
  round. The current app counts three, two, one and then says nothing.
- **Choosing a preset after the finish goes back to ready.** With *donE* on the face, a tap on a chip or a
  move of a Custom slider clears it and shows the new preset's time and *Round 1 of N*, as RESET would. The
  current app keeps the finished face until RESET.
- **Turned on its side, RESET is still there** (#132). While the rounds timer is paused or finished, or the
  stopwatch is stopped with time on it, a RESET button sits under the hint, turned with the face; a tap
  anywhere else still starts and stops. While running there is no RESET, so a tap across the room cannot clear a
  workout. The current app has no RESET in its turned view.
- **The count can be Adam, Igor or an Australian woman; Adam by default for now.** A gear on the timer's top
  bar (upright) opens *Timer settings*, where *Count voice* lists the three with a checkmark on the chosen one.
  Choosing one plays its *go* as a sample, is remembered across launches, and takes effect on the next cue — a
  running workout switches voice mid-count. Only the spoken words change: the fanfare after *done*, the timing
  and the music's ducking are the same for all three. The current app keeps Igor's voice.
- **Coming back to the app never costs a cue.** What fell while the app was away is not replayed, and what
  falls in the second Igor comes back is still said.
- **The lock-screen countdown and the Dynamic Island (106) came forward** and are their own spec:
  [Native Live Activity](2026-10-04-native-live-activity-design.md). One-tap starts from widgets
  and links (114) still wait for step 7, when the widgets move.
- **Sets, the Custom preset and the accessory log are the native app's own** until the cutover: what is logged
  in one app is not in the other, and the native app's accessory work is not in Grab Context until step 4.

Acceptance for step 2: each of stories 100–105, 107–113, 115 and 116 holds in the native app on the phone; a
whole workout with music playing, the phone locked for a round, leaves a session log with every phase and cue
at its true second and no `error`.

## Places in the native app (step 5)

What the native Places screen shows and does, how the trail is recorded, the import of Context Grabber's
exported database while the two apps keep separate trails, and the other differences:
[Native Places](2026-10-04-native-places-design.md).

## The Cockpit in the native app (step 7)

The Cockpit is ported ahead of the rest of step 7, as Igor called it critical: the page with real microphones and
outputs, the same bridge and client tag so the page needs no change, opened from the home screen and kept for the
launch when closed. What it does and how it differs: [the native Cockpit spec](2026-10-05-native-cockpit-design.md).

## Links and Shortcuts in the native app (step 7)

Every screen has a link, the timer and breathing links can start a run, the same things are Shortcuts actions and
Siri phrases, and a Links screen copies each link. Until the cutover the native app answers to its own scheme,
`grabbernative://`, because Context Grabber owns `grabber://` on the phone: [Native links and
Shortcuts](2026-10-06-native-links-design.md).

## Calling Larry in the native app (step 3)

The call does what stories 080–095 say, against the same bridge and the same wire format, with these
differences while the two apps live side by side:

- **It opens from the native app's home screen**, full screen, and *Done* returns there. The call belongs to
  the app, not the screen: leaving the call screen with a call live keeps the call, the home screen's Call row
  then reads *live · 1:17*, and a tap on it returns to the same captions and the same timer.
- **The call's log is the session log.** What the socket, the bridge, the microphone, the speaker, the audio
  session and the self-heals did is written there as events, so a shake attaches it. The Diagnostics fold on
  the call screen shows this launch's call events, oldest first, a rule before each call; *Copy diagnostics*
  and *Upload* carry the same text behind a header (build, state, ending, problem, route). A call that froze
  the app is in that launch's log file, which `pull-logs` brings to the Mac; the fold and the upload carry
  this launch only.
- **Echo cancellation is on from the first buffer.** The call's audio runs through iOS's voice-processing unit
  from before the engine first starts, every call, so the first call after launch is built exactly like the
  tenth. Larry's voice comes out of the speaker unless a headset is on.
- **The microphone that never delivers, the mic that goes quiet, the speaker that stalls, audio that is not
  arriving** are watched and healed by the same rules as stories 087–090, with the same thresholds.
- **The voice and the backend** are chosen on the call screen and remembered (stories 085, 091). The
  devices line names the current microphone and output. **During a call it is a menu** (Igor, 2026-10-13, #293:
  *"Can't switch microphones"*): *Microphone* lists *Automatic* (iOS's choice, named after the microphone it
  picked, so a plugged-in USB microphone taking over shows here) and then every microphone by the name iOS gives
  it; *Output* lists Automatic, Speaker and any headset. The one in use is checked. A pick moves the call within
  two seconds without dropping it, holds if the route moves under it later in the call, and is handed back to
  iOS when the call ends. Before a call the line only names the route; the menu belongs to a live call.
- **Where Igor is (story 092, #107)**, now that Places has shipped: a call asks for a fresh fix as it starts, and
  the fix, named for the known place it falls inside when there is one, goes up with the call. Each significant move
  during the call sends one more: a different known place, or 200 m from the last one sent. Standing still sends
  none. Diagnostics shows each one (*location: Home (±12 m)*), and off a known place only to about a kilometre (*47.62, -122.33 (±65 m)*), since the call's log can leave the phone in a report; the bridge still gets the precise fix. Without location permission the call simply carries
  none.
- **Prime audio is not ported.** It was an experiment for the silent first call in the React Native audio
  engine (#88); the native call builds its audio the same way every time.
- **No gist.** A call that went wrong files an automatic report on the phone: the call's log, why, and the session
  log's name, with no screenshot and no note (story 248). It waits there until the Mac's listener reaches the phone, which
  files it as an issue titled *Automatic report: call_trouble*. At most one per ten minutes, so a call that keeps
  failing does not pile them up; a long log keeps its newest lines within 5 MB. There is no token, no *Diagnostics
  uploads* screen and nothing to delete afterwards. *Copy diagnostics* still puts the call's log on the clipboard.
  Stories 094 and 095 describe the React Native app only.
- **"Call Larry" is a Shortcuts action of the native app too**: it opens Grabber Native on the call screen
  and starts the call on the remembered backend, or brings a live call forward. Links and the widget's ☎ wait
  for step 7.
- **One call at a time** is the native app's own: there is no Cockpit tab in it yet to police.

Acceptance for step 3: stories 080–085 and 087–095 hold in the native app on the phone (086 and 092 as above);
a call placed with the phone then locked for two minutes leaves a session log with the start, `ready`, the
microphone and speaker counts every five seconds while locked, and the ending, and no `error`.


**The call is let in as the Cockpit's own.** The bridge refuses a connection that does not come from the Cockpit's page or carry a client credential (#136). The native call presents itself as the Cockpit page does, so a call connects with nothing to set up on the phone.

## The mirror and Grab Context in the native app (step 4)

The mirror does what stories 002–009, 013 and 019 say, and Grab Context what stories 020, 021 and 024–029 say,
with these differences while the two apps live side by side:

- **Today opens from the native app's home screen**, as the Gym Timer does, and the home screen stays the
  list of launchers, with the diagnostics behind its cog ([home screen spec](2026-10-06-native-home-screen-design.md)).
- **Today is one screen**: a header with when the last grab finished and a phase while one runs, a summary line,
  the body cards (Movement, Exercise, Heart Rate, HRV, Sleep, Meditation, Weight) with the same values, sublabels
  and box plots as the current Body tab, and *Share summary* / *Share raw*. The current app's tabs (Today, Body,
  Move, Mind) are not rebuilt yet; what lives on them besides the cards waits for its own step (below).
- **A grab** asks for Health access the first time (the same read types as the current app), reads today live and
  the past six days from its own cache, and never fails as a whole: a metric Health will not give reads "—". A
  past day is kept in the cache only once it has settled: a day cached within 36 hours of its end (the first grab
  after midnight, before the Watch has synced its last hours) is asked again on every grab until one caches it
  later than that, and a day Health cannot answer keeps what was cached and is never cached as empty. It
  runs when Today opens, when the app comes back to the front, every thirty minutes while Today is open, and on a
  pull. The last grab's cards show at once on the next open.
- **The detail sheets** are drawn with the system's charts: bars for counts, a line with each day's range for
  heart rate, HRV, resting heart rate and weight, the normalized three-line Movement chart, and for Sleep the
  stacked stages, the per-source tabs with *All*, the sleep debt against the target, the bedtime-and-wake chart
  with its ± (time runs down the chart, so bedtime is the top line and wake the bottom one, and the gap
  between them is the time in bed: a wider gap is a longer night; the time labels are whole hours, evenly
  spaced; #307, #306; a tap on a night's dots names that night, its bedtime and its wake, under the chart, and
  marks it; a second tap clears it; #308), the onset and gap tags, and a tapped night's zoom card. Heart Rate carries resting heart rate under
  its chart.
- **The exports are the current app's, byte for byte**, for the same Health data and the same accessory log:
  the summary is the same single line of JSON, the raw share the same indented JSON. The share sheet receives the
  text, as in the current app.
- **What the native export carries that the current app's does not: the activities I finished** (Igor, 2026-10-05,
  #139: *"Make sure to log every time we complete an activity so we can give it to Larry"*). Every Gym Timer workout
  that runs to *done* and every breathing session that reaches *Done* is recorded with when it finished, what it
  was (the preset and its rounds, or the breath length and cycles) and how long it took. The summary gains an
  `activities` section after `accessory`: the last seven days, newest first, each with a kind (`gym_timer` or
  `breathing`), a readable name, minutes, an ISO-8601 UTC timestamp and the local date; a week with nothing finished
  carries an empty list. A workout reset or abandoned part way, and a breathing session left before *Done*, are not
  activities. This is the one deliberate difference from the current app's export, so the byte-for-byte check runs
  on everything else.
- **What the native export does not carry yet**: `roles` is left out until roles move (step 6), rather than shipped
  as null forever (the 2026-10-26 review, picked by Igor); once roles are native the key comes back first. In the
  raw share `location` and `locationClusters` are null until step 5; every other key is present with the same shape.
- **Places in the summary** (story 022): `places` carries the trail as the current app wrote it, text only and no
  coordinates: `weekly`, hours per place for this week and last ("This week: Home 92h, Office 28h"), places by
  hours, and `recent`, the stays that ended in the last three days, a line per day with each stay's local times and
  any transit of an hour or more. A week is labelled by how far back it is, so a week with no stays never shifts the
  labels (the current app labelled by rank). A stay counts whole in the week it began in, as in the current app: a
  Saturday night that runs into Sunday belongs to the week before, not to the Sunday. "Now" is the moment of the
  share; the current app measured the weeks and the last three days from the trail's newest point instead, so with
  a trail that has been silent for a while the native summary's "This week" and "recent" are the calendar's, not the
  last point's. With no stays, `places` is null.
- **Carried over unchanged, on purpose**, because the export must match the current app's byte for byte; each is
  filed to decide with Igor rather than fixed silently: `bedtime` and `wakeTime` in the
  headline are clock times in UTC; `walkingDistanceKm` is in the phone's preferred distance unit (miles on a phone
  set to US units); and a day's steps, energy and distance in `days` keep two decimals.
- **One deliberate difference from the current app** (Igor, 2026-10-17, from the old app's PR #154): each day's
  `sleepHours` in `days`, and the week's sleep stats, count a night once, noon to noon with the sources merged, on
  the day Igor went to bed, the same number the Sleep sheet shows for that night. The current app split a night
  across two days at midnight (an 11pm–7am night read about 1 h on one day and 7 h on the next). So in the morning
  today's row has no sleep yet; last night is yesterday's.
- **Settings for the mirror** is the sleep target, kept where the current app keeps it. It starts at **7 hours** (Igor, 2026-10-13, #301) and can also be changed on the Sleep sheet itself, right under the sleep-debt line, in half-hour steps from 4 to 12; the debt line follows at once. A target already chosen is kept. The current app's About and
  update check have no place here: the native app has no over-the-air updates, and Diagnostics names the build.
- **Not in this step**, each with its own issue: the map, tally and Reflect row on Today (001, with Places, the
  tally and the journal), the Exercise sheet's activity timeline and workout analysis (010's timeline, 011), the
  hourly heart-rate box plots and the raw heart-rate export (012), the meditation flatline card (014), mood and
  energy (015), the tally (016), the Move tab (017), recent reflections (018), and the week strip's gym-day dots
  (002).

Acceptance for step 4: for the fixture data — a real week of heart rate, HRV, resting heart rate and energy, plus
steps, distance, sleep from two sources, mindful minutes, weigh-ins, workouts (one crossing midnight) and accessory
entries — the native summary and raw exports equal the current app's, byte for byte, on the Mac and from the
simulator's Health store; on the phone the cards show the same numbers as the current app's Body tab after a grab
in both.

## Verifying

The ladder keeps its shape and gets cheaper at the bottom: the platform-free logic is tested on the Mac in
seconds; the simulator runs the app from launch hooks and is judged from the session log, not from taps; the
phone is for what only the phone can show. Details live in [TESTING.md](../../TESTING.md) and
[DEBUGGING.md](../../DEBUGGING.md).

## Acceptance criteria

Step 1:

- Installing the native app leaves the current app and its data untouched; both open.
- Each launch produces one new log whose first entry names the device, the system and the build.
- A shake opens the report sheet; an empty note cannot be sent; a sent report is stored with a screenshot and
  names the session log.
- From the Mac, new reports are detected without pulling everything, and filing them creates each issue once.
- A launch after a crash announces the crash in the log exactly once.
- A log older than thirty days is gone after the next launch unless a report names it.

The whole port:

- Every story marked implemented has the native build on its `Status:` line with where it was verified, or a
  line saying why it was dropped.
- For the fixture data, the native export equals the current export.
- After the cutover, the first open shows the same location history, places, journal and settings as the last
  open of the old app, and the widgets keep their state.

## Risks

- **The call.** Its fixes were found on the phone (echo cancellation, the silent first call, the mic after a
  route change). Each has a story or an issue; step 3 is checked against all of them on the phone before it
  counts.
- **No update without the Mac.** A bad build stays until the phone is back near the Mac. The old app stays
  installed until step 8 as the fallback.
- **Two apps tracking location** during steps 5–7 cost battery; background tracking in the native app stays
  off until Igor turns it on.
