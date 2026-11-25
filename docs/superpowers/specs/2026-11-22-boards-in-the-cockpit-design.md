# Boards live in the Cockpit, not iCloud

Status: **decided, ready to build** (bead context-grabber-t12b). Igor made every pick on 2026-11-24 (see "Decided"
below); Larry: "Go ahead and start the build per your v2 plan." Design only so far, no code. Refreshed 2026-11-24
against that day's board work and Larry's answer on the Cockpit side (below). Larry brings the Cockpit side; the plan
beside this spec holds the store's shape for him.
Nothing here is built.

Igor, 2026-11-22, in the whiteboard vision review (via Larry): drop iCloud for boards. Every board lives in the
Cockpit. Every device (the iPad, the iPhone, the Mac and the web board) reads and writes that one copy, and each
device keeps an offline cache that catches up when it's back online.

Igor, 2026-11-24 (terminal): "I thought we were sharing whiteboards with the web so either could write/read... Like
expand and stuff should work. Do we not have a shared format?" Not yet: the rules are shared, the boards are not.

## Why

- **One copy, one truth.** Today a board lives on the iPad that drew it and travels through iCloud to the others. Its
  meaning (Larry's kept texts, groups, headers and folds, question cards, which ink is whose) stays on that device.
  Larry's web board (*/ink*) keeps its own boards and can't open an iPad board, and the iPad can't open a web board:
  a web board's link only opens its page in the browser (#1354).
- **The rules are already one.** Folding and expanding, scratch-out, making room, keeping and dismissing Larry's marks,
  groups, headers and question cards run the same code on the iPad and on the web board. What isn't shared is the
  board those rules act on.
- **Neither store today can be the one copy.** The web board keeps each board as one whole copy: the last save wins
  and there is no history, so two devices saving one board would lose ink silently. iCloud keeps the iPad's drawing
  and its meaning as two files with no revisions the Cockpit can see. Only the iPad's own record of changes, each
  numbered and each answering the number it was made against, has what a shared board needs; the Cockpit's store is
  built from that, not from either copy (Larry, 2026-11-24).
- **iCloud has cost more than it gave**: atomic-batch failures on a launch's first sync (context-grabber-jbot), a
  schema that has to be deployed by hand before every TestFlight build that adds a field, and a container borrowed
  from BugKit. None of that can be debugged from the Cockpit's own debug page.

## Goals

- Every board and everything it means is stored once, in the Cockpit, with its history.
- The web board and the iPad open, draw on and fold the same boards, with the same rules.
- Every device shows every board, offline too, from its own cache.
- Ink drawn offline is never lost silently. It goes up when the device is back online, or is refused out loud.
- A change to something another hand changed since is refused and says so; the board does no other merging.
- Existing iCloud boards and existing web boards move over with nothing lost and nothing for Igor to do.

## Non-goals

- Real-time co-drawing (two devices on one board, seeing each other's pen live). Changes arrive on the next sync,
  in seconds while online.
- Sharing boards with anyone but Igor and Larry.
- Search, folders, tags: still not a notes app.
- Undo across devices. Undo stays on the device that made the change.

## What a board holds

Everything below travels together as one version of the board, on every device:

- **The ink**: every stroke, with its pen, colour, width and the pressure of each point, so a stroke drawn with the
  Pencil looks the same on the web and back on the iPad.
- **Larry's marks and replies**: ghosts still waiting for Keep or Dismiss, a reply of two or more marks as one ghost
  group with *Keep group* (#1383), what each mark answers and where it sits beside that ink, and whether it has faded
  because Igor wrote over it.
- **Whose ink is whose**: Igor's writing, Larry's kept ink, and groups. A group Igor made of his own ink stays his
  writing; only Larry's groups are not (2026-11-24).
- **Kept texts and pasted text**, with the glyphs they were drawn as.
- **Headers and folds**: which lines are headers, which are folded, and the lines Igor said are not headers.
- **Question cards**: each card's ask, its answer, where it sits, and how it shows: full, shrunk to its one-line
  answer, collapsed to a round *?*, or archived off the board (#1387).
- **The board itself**: its name, its paper and lines, and when and where it was last drawn.

What stays on each device and does not travel: undo, the lettering style a device writes in, the Pencil's tool, the
review a device records of a session (#1379; a review's findings still go to Larry with the turn, as today), and the
session log.

## What Igor sees

### The boards list

- The same list as today, newest change first, on every device, with the web board's boards in it too. A board from
  another device says where it was last drawn (*Drawn on iPad*, *Drawn on the web*).
- A new board appears on the other devices within seconds while they are online, and when the list next opens or the
  app comes forward otherwise. A pull on the list fetches at once, as today.
- **Offline**, the list shows every board this device has seen, each openable, with a quiet line in the list:
  *Offline · 3 changes waiting to go up*. Nothing else changes. With nothing waiting, it says *Offline*.
- When the Cockpit is unreachable while the network is fine (the Mac asleep, the Cockpit down), the line says
  *Cockpit not answering* and is a copyable problem: when the device last reached it, what is waiting, and the
  address it tried.

### Drawing

- **Anyone can draw on any board from the iPad, the web board or the Mac** (Igor, whiteboard vision review: "Anyone
  can draw on it. Doesn't matter the device"; option C, 2026-11-24).
- **The iPhone only views boards** (Igor, 2026-11-24). It shows every board, current to the Cockpit's copy, and still
  offers *Send to Larry*; it never draws, so it never sends a change that can clash.
- A board drawn on offline keeps everything drawn. It goes up the moment the device is back, oldest change first.
- A board's meaning travels with its ink as one version. A device never shows one version's ink with another
  version's meaning.
- A fold made on the web is folded on the iPad when it next opens the board, and the other way round. Expanding a
  header on one device expands it everywhere.
- Larry's changes to a board (his marks, his tidy-ups, his replies) are changes like any device's: each names the
  version it was made against and is refused out loud when it clashes, as his replies already are on the iPad.

### Two devices, one board, apart (the conflict rule)

**A change to something another hand changed since is refused, and says so; the board does no other merging**
(option C, decided by Igor on 2026-11-24).

- New strokes touch nothing already there, so new strokes from either device both land.
- A change to an existing stroke, mark, group, header, card or text (moved, erased, recoloured, written over, kept,
  folded, shrunk) lands only if nobody else changed that thing since this device last saw it. Otherwise it is refused.
  For example, the same stroke moved on the iPad and moved differently on the web: the first to reach the Cockpit
  stands, and the second device's change to that stroke is refused. That device shows a copyable note, *Not moved:
  the web moved this since*, and the stroke where the Cockpit has it. Everything else that device drew in the same
  stretch still goes up.
- Keep and Dismiss on Larry's reply count as changes to that reply: *Keep group* on the iPad after the web dismissed
  the same reply is refused, *Not kept: the web dismissed this reply since*.
- A rename made after another device renamed the board is refused the same way: *Not renamed: the web renamed it
  "Plan" since*.
- Larry is told of a refused change as he is told of any of Igor's changes: one event naming what was refused and why.
- The Cockpit never asks Igor to pick between two versions of a board; a refused change is one thing's, named.

### Deleting

- Any device can delete any board. Delete still asks first and has no undo. The board goes everywhere: from the other
  devices' lists the next time they sync, and from their caches with it.
- **New ink does not override a delete** (the final vision draft; today's rule is the opposite). Ink drawn on a board
  that another device has deleted is refused when it reaches the Cockpit, and the device says so as a copyable
  problem: *Not saved: this board was deleted on the web at 21:14*. The refused ink is not thrown away silently:
  the problem offers **Keep my ink as a new board** (Igor, 2026-11-24), which saves the refused ink as a new board
  with the old board's name and *(kept ink)* after it.
- **A deleted board is kept forever** (Igor, 2026-11-24): delete is a soft delete with no purge. The board leaves
  every list but stays in the Cockpit and in its nightly backup, so a mistaken delete can always be brought back by
  asking Larry.

### Offline: each device's copy and its unsent changes

Igor, 2026-11-25, accepting Larry's store spec (its section 11): a refused change is undone on the device with a
copyable note, an undo that's blocked is refused and offers *Add it back as new ink*, and Larry's batches are applied
once, by the Cockpit. The wire is in the Cockpit store's own spec (cockpit, `docs/specs/2026-11-25-board-store.md`,
sections 3 and 6). This section is what Igor sees of it on a drawing device.

- **A board opens from the device's own copy**, with every unsent change of this device on top, online or not.
  Nothing drawn waits for the Cockpit before it shows.
- **Unsent changes go up oldest first, one save at a time.** If a save's answer never came back, it goes up again
  exactly as it was, so it lands once however many times it is sent. Any change made after it waits its turn.
- **Catching up before sending.** When another device or Larry changed the board meanwhile, the device's copy is behind
  the Cockpit's. The device takes those changes first, then checks its unsent changes against them, on the device, by
  the rule the Cockpit uses. A change to something another hand changed meanwhile is refused right there. It shows the
  copyable note the Cockpit's refusal would (*Not moved: the web moved this since*), and the thing shows the way the
  other hand left it. Everything else still goes up. The device never sends a change made against a version of a
  thing it hadn't seen, so no clash slips past. That holds when Larry restored a deleted board in the same stretch too: the
  restore decides only whether the board is deleted, never whether a clash counts.
- **Knowing it's caught up.** After an answer, the device takes its own change in without asking again only when
  nothing else landed in between: one new version if its change landed, none if nothing did. Otherwise it first
  fetches what it missed. A late answer to a save the device has meanwhile fetched, with whatever landed over it, changes
  nothing: the device never puts its older ink back over a newer change.
- **A refused change is undone on the device**, and its copyable note names the thing, who changed it and when. New
  ink that collides with a name already on the board is never dropped. It is added back under a new name, and the note
  says so.
- **Larry's replies reach a device only from the Cockpit.** The Cockpit applies his changes itself (Igor, 2026-11-25);
  a device takes them in when it catches up and never sends a reply of his, or re-sends one under a new name, so a
  reply can't hold up the saves behind it.
- **Ink refused because the board was deleted is kept aside**, off the queue, until Igor answers the note. *Keep my ink
  as a new board* makes a board with the old name and *(kept ink)* after it, holding that ink; dismissing the note lets
  it go. A delete that Larry has already undone by the time the device catches up sets nothing aside: the ink goes up
  to the board as usual.
- **A copy that's ahead of the Cockpit** (a broken cache) is thrown away and the board downloaded again. Unsent changes
  are kept and checked against the fresh copy.
- **A save the Cockpit couldn't look at** stays queued and is tried again. A save the Cockpit says was already used for
  a different change is a copyable problem; it is never quietly sent again under a new name.
- All of this sits behind a rollout setting, off by default. With it off, boards save and sync as today.

### Pictures and Larry

- Larry reads boards from the Cockpit's copy, not only from the pictures sent to him. *Send to Larry* still sends a
  picture and the turn's note. The picture is how Igor points, and the board is what Larry reads.
- Each version carries its picture for the list. A version that arrives without one is drawn on the device, as today.
- A question card's thinking goes on in the ask's own chat thread, as today; the card on the board holds the ask, the
  answer and how the card shows.

## Moving off iCloud and the web's old boards (migration)

- On the first launch of a build with this, each device puts up every board **it drew** from its own disk (its own
  copy is the truth for those, as today) with the board's id, name, ink, meaning and times. Ink the Cockpit
  already holds is never put up twice: not when a move that stopped partway runs again, and not when the board's
  ink already went up during rollout step 2.
- The iPad also puts up each board's drawing exactly as it was saved, kept beside the board in the Cockpit and never
  shown, so anything the shared format can't yet hold is not lost.
- Boards from other devices aren't put up by this device: the device that drew them does it. A board whose drawing
  device is gone (an old phone) is put up from the newest copy any device holds, once a week has passed with no
  upload from its owner. Until then the iCloud copy stays readable.
- **The web board's existing boards** move into the same store once, by the Cockpit, with their names and ink; a web
  board's link keeps working.
- **iCloud stays only for the migration.** iCloud sync of boards stops on each device once that device's boards are
  all in the Cockpit, and iCloud's copies are deleted once every board is confirmed in the Cockpit, on Igor's yes.
- The list says *Moving boards to the Cockpit · 4 of 12* while it runs, and a copyable problem names any board that
  couldn't move and why. Such a board stays on the device and in iCloud and tries again next launch.
- Board links and chat pictures' *Jump to board* keep working: board ids don't change.

## Rollout

1. **The Cockpit store, with history.** The Cockpit gets a board store that keeps every version and checks every
   change against the version it was made on. Nothing on the devices changes yet; the store is tried against
   recorded board sessions and the web board.
2. **The Cockpit holds a copy, iCloud stays the truth.** Each device writes every change to both. Larry and the web
   board read the Cockpit's copy. This is the check that the store keeps up, with no risk to Igor's boards.
3. **iPad and web board switch.** The Cockpit becomes the truth for the iPad and */ink*. The migration above runs.
   The iPhone and the Mac still read iCloud's copy, which the iPad keeps writing.
4. **Every device switches.** iCloud board sync stops; the migration ends.
5. **iCloud's copies deleted** on Igor's yes, once every board is confirmed in the Cockpit.

Each step is a setting on the device that Igor never has to touch, and it can be turned back. Step 3 waits for a
week of step 2 with no missing changes on the Cockpit's debug page.

### Trying it before the rollout: *Boards from the Cockpit (beta)*

Before step 2, the iPad gets one switch in the whiteboard's settings, **Boards from the Cockpit (beta)**, off by
default. It is for trying the store while Larry and the app build it, not for Igor's real boards.

- **Off** (the default): nothing changes. The boards list, drawing and iCloud sync are exactly as they are today, and
  the iPad never asks the Cockpit for boards.
- **On**: the boards list gets a section, *From the Cockpit*, above the iPad's own boards (first, so a long list of the iPad's boards never hides it). It lists the
  Cockpit's boards (name, and how many versions each has), fetched when the list opens and on a pull. The iPad's own
  boards below it are untouched and still sync over iCloud.
  - With no Cockpit boards yet, the section says *No boards in the Cockpit yet*.
  - When the Cockpit can't be reached, the section shows the copyable *Cockpit not answering* problem (the address it
    tried and what failed), and the iPad's own boards still open.
- **Each Cockpit board's copy and its waiting saves live on the iPad** and survive a relaunch: the copy the iPad last
  saw, the saves not yet sent, and the notes about saves that were refused. A save in flight when the app is killed
  goes again as it was (the same body, the same name), so the Cockpit never takes it twice.
- **The iPad talks to the Cockpit one save at a time**: it fetches what it missed before it sends, sends its oldest
  waiting save, waits for that answer, and only then sends the next. Refused changes become the copyable notes the
  *Offline* section describes; ink refused because the board was deleted waits for *Keep my ink as a new board*.
- Drawing on a Cockpit board from the iPad comes in the next step of this switch; until then a Cockpit board is
  listed, not opened.

## Decided (Igor, 2026-11-24, in his Inbox)

- **Who may draw: C.** Any drawing device (the iPad, the web board, the Mac) draws on any board. New strokes from
  every side always land; a change to something another hand changed since is refused and named. The other options
  were A (only the device that drew the board) and B (whole-board last write wins, keeping a copy).
- **The iPhone only views boards.** Drawing is the iPad and the web (and the Mac).
- **Ink refused because its board was deleted:** offer *Keep my ink as a new board*.
- **Deleted boards are kept forever:** a soft delete, never purged, and in the nightly backup.

Who builds what (Larry, 2026-11-24): the clash check on the devices and every device's side (the cache, the queue of
changes, the refused-change notes, the migration of iCloud boards) is this repo's. The Cockpit's store (its history,
the batch of changes, the nightly backup, */ink* moving from names to ids) is Larry's, once the shapes in the plan
are confirmed.

## Larry's answers (the Cockpit side, 2026-11-24)

The store's shape and his full answers are in the plan.

- **Reach:** the boards are reachable wherever the chat is, away from home too, with the chat's sign-in.
- **Backups:** every change is backed up nightly, and a board can be restored to any version it ever had. This must
  be in place before the Cockpit becomes the only server copy (rollout step 3).
- **Size:** the biggest board today is about 1.5 MB with 1,288 strokes, so every device caches every board whole.
- **Names to ids:** */ink* moves to ids, and each board's old name link keeps working.
- **Changes that skip the version check:** only the web board's whole-board save; it is replaced by checked changes
  when */ink* moves onto the store, and until then it must not write to a board the store holds.

Still open:

- Where the web board's pasted images live today; settled before the web boards move.
- How the Cockpit rebuilds a board's latest version from its changes (it leans toward running the shared board
  rules itself; the fallback is each device sending its own copy with each change).

## Acceptance criteria (for when it's built)

- A board drawn on the iPad appears on the web board, the Mac and the iPhone within ten seconds while all are online.
- A board drawn on the web opens on the iPad with the same ink, groups, headers, folds and cards.
- A header folded on the web is folded on the iPad when the board next opens there, and expanding it on the iPad
  expands it on the web.
- A board drawn on with the iPad in flight mode keeps all of it, and every stroke is in the Cockpit within ten
  seconds of the network coming back.
- The iPad and the web board each add ink to one board while the iPad is offline. Afterwards both see both sets of
  strokes, and nothing was asked of Igor.
- The iPad (offline) and the web board each move the same stroke differently. The first to reach the Cockpit stands;
  the other device says, copyably, that its move was refused and why, and keeps the rest of its ink.
- Keep group on Larry's reply on the iPad (offline) after the web dismissed it is refused, copyably, and the reply
  stays dismissed.
- The iPhone shows every board and its latest ink, and offers no way to draw on one.
- A board deleted on the web while the iPad, offline, draws on it stays deleted. The iPad says, copyably, that its
  ink wasn't saved and why.
- After the migration every board in the old lists, the iPad's and the web's, is in the new one with the same name,
  ink, meaning and link, and a Pencil stroke looks the same as before.
- The Cockpit unreachable shows *Cockpit not answering* as a copyable problem, and every board still opens.
