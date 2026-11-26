# Context Grabber — User Stories

Mike Cohn use case plus Gherkin acceptance criteria, one scenario per story, one When and one Then
(deanpeters/Product-Manager-Skills `user-story`). Persona throughout: **Igor, an engineer between jobs who feeds a
weekly coaching call with Larry, his AI coach, and wants a humane mirror of the week** — iPhone in the pocket,
Apple Watch on the wrist, music playing at the gym, the phone propped on a water bottle between sets. The mirror
shows, it never judges: time-since over streaks, no red badges, capture implicit ([jtbd.md](../jtbd.md)).

These files are the spec of what the app does. The design specs in [superpowers/specs/](../superpowers/specs/) are
the deep dives behind them — a story links to its spec where one exists, and a behaviour change updates the spec
first and the story in the same PR ([AGENTS.md](../../AGENTS.md)).

Every story carries its own `Status:` line: **implemented** with the commits that built it and where it was
verified (host tests, the simulator, or the phone), or **not implemented** with the issue or bead that asks for it.
Link to commits as they appear in the branch's history after a rebase. See the
[host rung's script checks](../TESTING.md#the-host-rungs-script-checks) for link failures.
The stories are the only record of status; there is no separate table to keep in step. A bug against a story goes
on its `Issues:` line.

| Journey | What it covers | IDs |
|---|---|---|
| [The mirror](01-mirror.md) | Today and the week at a glance: the metric cards, the detail sheets, sleep, movement, mind; Settings and About. | 001–019, 440–459 |
| [Feeding Larry](02-larry.md) | Grab Context: the summary and raw exports, the 7-day window, what the coach sees. | 020–039, 260–279, 300–319, 480–499, 500–519, 540–559, 728–729, 740–744, 747–749, 820–824, 830–835, 838–839, 1120–1139, 1600–1619, 1700–1799 |
| [Places](03-places.md) | Background location, stays and known places, the per-day breakdown, the map, the database export. | 040–059 |
| [Roles and the journal](04-roles-and-journal.md) | Who I have been: the identity threads, time-since, the journal and its tags, gratitude, affirmations, mood. | 060–079 |
| [Calling Larry](05-call.md) | The native Call tab that survives the lock, the Cockpit page, voices, diagnostics that reach Larry. | 080–099, 200–219, 248, 320–339, 751–752, 829, 1070–1089, 1800–1899 |
| [The Gym Timer](06-gym-timer.md) | Presets, cues in Igor's voice, the LED face and the turn, music that keeps playing, the accessory-work log. | 100–119, 180–199 |
| [From the home screen](07-widgets-and-links.md) | Widgets, the memdeck card, deep links and Shortcuts; windows on the iPad; the Mac app. | 120–139, 220–239, 243–245, 247, 250, 460–479, 560–579, 580–589, 677–682, 684–685, 700, 720–727, 730–739, 826 |
| [Reporting problems](08-reporting-problems.md) | The native app beside this one: the session log, the shake, crashes, reports that become issues. | 140–159, 246, 251–255 |
| [Breathing](09-breathing.md) | The native app's box-breathing screen: the circle, the sliders, pause, tones and the voice. | 160–179, 240–242, 249, 256–259, 280–299 |
| The whiteboard: [the board and the list](10-whiteboard-boards.md), [boards on paper](10-whiteboard-paper.md), [Larry's turn and the conversation](10-whiteboard-turn.md), [ghosts and Larry's marks](10-whiteboard-marks.md), [Larry changes the board](10-whiteboard-edits.md), [question cards](10-whiteboard-cards.md), [gestures](10-whiteboard-gestures.md), [headers, folds and the outline](10-whiteboard-outline.md), [storage, sync and the log](10-whiteboard-storage-and-log.md) | Drawing with the Pencil on a board bigger than the screen, Larry seeing it, and Claude drawing along. | 340–439, 520–539, 590–609, 610–629, 630–649, 650–669, 698, 746, 760–769, 771–779, 800–819, 825, 836–837, 840–859, 860–879, 880–889, 890–899, 900–909, 910–919, 920–929, 930–934, 940–949, 950–959, 960–969, 970–979, 990–1009, 1030–1049, 1050–1069, 1090–1119, 1140–1159, 1160–1499 |
| [Building and testing](11-building-and-testing.md) | How a change reaches the phone quickly: testing on the Mac, the simulator kept for what needs it, practices shared with the other apps. | 670–676, 683, 686–689, 745, 750, 753–759, 770, 780–799, 827–828, 980–989, 1010–1029, 1500–1519, 1620–1639, 1900–1999 |

New stories take their IDs from `scripts/native/story-ids.py reserve <journey> [n]` (story 791), never "the next
free ID" read from one branch: it skips the IDs on main, in every open PR and reserved by any agent on any machine,
and `just pre-merge` checks them again against main right before merging (story 793). A journey that outgrows its
range takes the next unused block above every journey's IDs and adds it to the end of its row; reserve's failure names
the block and every journey's free IDs. That block is added on purpose, never by an agent or the pipeline mid-PR to
make room for its own story: they stop and report the full journey (bead context-grabber-1vvb). A quiet journey takes
twenty; one that adds stories daily, like the whiteboard,
takes hundreds (1160–1499, bead context-grabber-0e04). The IDs column is the allocation: no two journeys hold the same ID,
and `just test` fails on an ID used twice or outside its own journey's IDs (`scripts/native/test-story-ids.sh`,
story 789). A journey can span several files (the whiteboard's, by feature area, story 796): its row links each
of them, they share its IDs column, and a new story goes in the file of its feature area with any free ID of the
journey's. The scattered single IDs are stories that took another journey's number before this was checked; they
keep their numbers, as commits and issues name them.
