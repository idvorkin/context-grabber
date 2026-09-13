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
verified (host tests, the simulator, or the phone), or **not implemented** with the issue that asks for it. The
stories are the only record of status; there is no separate table to keep in step. A bug against a story goes on
its `Issues:` line.

| Journey | What it covers | IDs |
|---|---|---|
| [The mirror](01-mirror.md) | Today and the week at a glance: the metric cards, the detail sheets, sleep, movement, mind; Settings and About. | 001–019 |
| [Feeding Larry](02-larry.md) | Grab Context: the summary and raw exports, the 7-day window, what the coach sees. | 020–039 |
| [Places](03-places.md) | Background location, stays and known places, the per-day breakdown, the map, the database export. | 040–059 |
| [Roles and the journal](04-roles-and-journal.md) | Who I have been: the identity threads, time-since, the journal and its tags, gratitude, affirmations, mood. | 060–079 |
| [Calling Larry](05-call.md) | The native Call tab that survives the lock, the Cockpit page, voices, diagnostics that reach Larry. | 080–099 |
| [The Gym Timer](06-gym-timer.md) | Presets, cues in Igor's voice, the LED face and the turn, music that keeps playing, the accessory-work log. | 100–119 |
| [From the home screen](07-widgets-and-links.md) | Widgets, the memdeck card, deep links and Shortcuts. | 120–139 |

New stories take the next free ID in their journey's range; a journey that outgrows its range takes the next
unused block of twenty.
