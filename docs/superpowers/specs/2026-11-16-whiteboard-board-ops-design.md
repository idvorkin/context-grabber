# Larry edits the board: making room and plain text (step 1)

Status: draft for Igor, 2026-11-16. Step 1 built (stories 814–819); steps 2 and 3 below (Igor via Larry, 2026-11-16: build them all in one round, one simulator pass at the end).

## The idea in one line

Larry can change the board itself, not only draw ghosts on it. In this first step he can open space between lines
and put down real, readable text. Each change he makes is one undo for Igor.

## Why

- Igor asked Larry on the board, 2026-11-16, to "stick 20 lines between here and here", and Larry had no way to do it.
  He can only draw into empty space.
- A kept label sits on top of Igor's ink instead of pushing it down (#894).
- Larry's labels are drawn in a traced hand font that is hard to read small (#895).
- Igor, 2026-11-16: more of the board's behaviour should live on Larry's side, so it can change without an iPad
  build. The app applies what Larry asks for, and Larry decides what to ask. This is the first step of that split
  (Larry's plan, thread igor2-88g.1499: step 1 here, objects and editing next, server-drawn controls last).

## What Igor sees

### Larry makes room

- Larry answers a turn with "make room here". Everything on the board below that line, including Igor's ink, pictures,
  pasted text and kept marks, slides straight down. Nothing is scaled, split or redrawn; whole strokes move.
- **Every cut lands between lines, and the room is whole lines** (Igor, 2026-11-22, design board: "every cut lands
  between lines"; bead context-grabber-2gu, story 1195). Larry's line snaps as every other push does (a paste, a drop,
  room by hand): a height on clear paper stays where it is; a height inside a line of writing moves to its top when
  that is nearer and within two lines, else to its bottom, so a line of handwriting, a kept text or a group of his
  moves whole or stays whole, never split. The distance rounds up to whole ruled lines: asked for 50 points, the board
  opens 80. Asked to close room (a negative distance), it closes blank paper only, in whole lines, as room by hand
  does, and nothing closes onto ink.
- **Larry hears what was used.** His next turn says, for each make-room in the change, the height and distance he
  asked for and the clear line and distance the board used, so he knows where the room really is.
- A change from an older look that applies to the board as it is now (below) snaps on the board as it is now, at the
  height Larry saw. If Igor opened room by hand in between, the push still lands at that height on the moved board;
  whether it should follow Igor's room is an open question, not decided (bead context-grabber-2gu).
- The board grows a page at the bottom when the push needs one. It never loses ink off the end.
- One tap on Undo puts everything back where it was, page count included. Redo pushes it down again.
- If Igor is drawing when the answer arrives (the Pencil is down, or was lifted less than a moment ago), the push
  waits until he lifts it. A push never moves ink under a live pen.
- **If Igor wrote on after Larry looked, the change still applies when nothing it names has moved or gone** (Larry,
  2026-11-17: his make-room kept coming back stale at rev 257 and rev 111, because Igor writes a stroke or two before
  it arrives). The board remembers, for each change since, which strokes moved or were erased. A batch from an older
  look applies to the board as it is now when none of the strokes, groups or texts it names is among those: a make
  room pushes down what is below its line now, Igor's newest strokes included, and his new strokes alone never
  stop it. Larry is told it applied on a newer board than the one he saw, and which one he saw.
- **It is refused as stale only on a real conflict**: it names a stroke Igor has since moved or erased, or it is older
  than the board remembers (the memory holds the last 200 changes). The memory is kept with the board, so a relaunch
  forgets nothing: a change Larry made from a look before the app restarted still applies when Igor only wrote new
  strokes since (bead context-grabber-fuw0). A board saved by a build from before this remembers nothing older than
  the revision it was saved at, so a look from before that is still refused as stale. A fold, an unfold, or connectors
  following their ends count as moving everything, so a look from before one is stale. The memory is saved with
  a fingerprint of the drawing it goes with, so a save cut off part-way (the drawing written, its memory not) is
  always noticed when the board opens, a moved stroke that left the drawing's size the same included: the board then
  forgets its memory of the changes, and every older look is stale. A change
  held for the Pencil is checked again when the Pencil lifts, so Igor moving or erasing what it names while it waits
  still refuses it. Nothing moves then, Larry
  is told why and which of his names conflicted, and he looks again and sends a fresh one. Igor never sees a
  half-applied change.

### When Larry's edit is blocked (stories 970–972, 976–978; Igor, 2026-11-17, via Larry: "show a chip so I'm not guessing")

- When a change of Larry's can't be applied (the board moved on since he looked, or anything else refuses it), a small
  chip shows over the board's top corner, under its ? and Feedback buttons, so the paper never moves, in Larry's
  purple: *Larry's edit blocked · Retry*, with a × beside it. Retry and × each take a finger's width; a tap on either
  never reaches the paper. Nothing on the board has moved; the chip only says so.
- **Retry hands Larry the board again**: it is *Larry's turn* at once, the picture of the board as it is now with what
  happened to his last change, so he looks again and sends a fresh one. It is never a replay of the refused change.
  Retry sends even when Larry already has this picture: only *Send to Larry* dims for that (beads context-grabber-ts8a,
  context-grabber-kxzk). The chip goes once a picture has gone; while one is still on its way, Retry sends nothing
  more and the chip stays, so Retry can be tapped again.
- **×** puts the chip away and asks nothing.
- The chip goes by itself when a later change of Larry's applies, and a newer refusal replaces it (one chip, never a
  pile). Leaving the board forgets it. A change dropped because the board closed shows nothing, as nobody is there.
- The session log says when the chip showed (with the refused change's label and reason) and how it went: retry,
  dismissed, or replaced by a change that applied.

### Larry writes plain text

- Larry can put a line of text on the board in a plain, readable typeface, at a size and colour he picks, instead of
  a traced hand font. It reads cleanly at small sizes.
- The text is a mark like his others: it arrives as a ghost. Keeping it makes it part of the board, Dismiss throws it
  away, and Undo takes it back.
- Kept text is part of the page. It shows in the board's picture and in what Larry gets back. It moves with a push
  like any ink.
- **His text makes room, as a paste does** (#938; Igor, 2026-11-17, after Larry's list landed on his writing twice:
  "why didn't purple text push down?"). When a text of his would land on ink, the ink makes way: from the clear line
  nearest the text's top, everything below moves down, whole things whole, by as many whole lines as it takes to sit
  half a line under the text. Ink above that line stays. If the text's top falls in a line of writing nearer its
  bottom, that line stays and the text lands just under it instead, with the room opening below. A text on clear
  paper, or only beside ink on its line without touching it, moves nothing. Ink the same change draws, and a frame
  the text sits wholly inside, are never in its way: a label in his box, or in Igor's, stays where he put it.
- The room is part of his change: one Undo puts the ink back up (the ghost itself is still his, to keep or dismiss),
  and a page is added when the push needs one. Several lines of his in one change each make their own room, top to
  bottom, so a list of his never lands on Igor's writing. His other ghosts below the line move down with the ink, as
  do his texts already on the board.
- **A ghost of his text answers to his name for it** (#939; Larry, 2026-11-17: he deleted his list while its lines
  were still ghosts, every name came back missing, the ghosts stayed, and Igor later kept three of them, which Larry
  then had to delete again). While a text of his shows as a ghost, his changes reach it by the same name as once it is
  kept: a delete (or a replace) takes the ghost away, so Igor can never keep it afterwards; a move by its name moves
  the ghost; notes on it make it ink (above); a push moves it with the ink below. None of those is a missing name.
  Kept, it keeps his name, so the same change works on it either way. A name he never used, or a ghost Igor already
  dismissed, is still missing.
- **Keeping a ghost that ink has come under makes room too.** When Igor keeps one of Larry's text ghosts and his
  writing has since reached under it, the keep opens room the same way, and one Undo takes back both the kept text and
  the room. Keep all keeps his marks where they showed and makes room for what Igor wrote after the picture, as for his other marks (story 895).

### Larry hears the pen and taps

- Larry learns when the Pencil goes down and comes up. He can wait for Igor to finish before answering, and never
  pushes ink mid-stroke.
- Larry learns when Igor taps the board, and whether the tap landed on one of his marks. That is enough for him to
  offer tap-to-keep, or a tappable band where room will open.
- **A long stretch of drawing never costs Larry what changed** (bead context-grabber-27sv, 2026-11-22: a two-minute
  stretch of drawing and a kept reply between turns showed *5 events dropped* on the debug page). A turn carries up to
  as many events as the Cockpit takes (200), leaving room for the picture's own sending event. Past that the board
  lets go first of a view that a later view replaced, then of the Pencil's oldest downs and ups, and only then of the
  oldest of anything else, so Igor's ink changes, selections, taps and undos, the outcome of Larry's change and the
  debug timings are the last to go. Every event let go is still counted as dropped, and the board's session log says
  how many of each kind went with each turn.

### What the board says about its own sending, for the debug page (Igor, 2026-11-22, bead context-grabber-7zmj)

Igor: "prioritize any missing logging for the debug page on the whiteboard." The Cockpit's board debug page shows
each picture's way from the iPad to Larry's reply, and lists what nothing records. The parts only the iPad knows go
with each picture:

- **Which build sent it.** Every picture the board hands to Larry (the board's own hand-off and *Send to Larry*), and
  every batch of events sent between turns, names the app's build: its commit and branch, as a shake report names
  them.
- **The picture's own half of its way.** With each picture the board hands to Larry, one more event among its
  events says when the message left the iPad (to the millisecond), how long the picture took to draw and to encode,
  how long its strokes and its image took to go up, its size, the build, and whether it was a first send or a
  *Retry*. A *Retry* says its own times; it never repeats the first send's.
- **The board's name.** Every picture the board sends Larry (the hand-off, *Send to Larry*, a *Retry*, and a picture
  that waited to go) carries the board's name as it was when the picture was taken, not only the first one that starts
  the chat. So a board renamed on the iPad renames its chat with the next picture (the Cockpit retitles a chat it named
  itself to *Board: <name>* and keeps one Igor typed), and the debug page shows the board's name on each post. A
  Cockpit that doesn't read the name ignores it. (Igor via Larry, 2026-11-22, bead context-grabber-8rei.)
- **Mic off to text.** Each time words Igor spoke are taken for a turn, an event says when the mic opened, when the
  first words were heard, when the mic closed (none if it was still open), when the words were ready, and when they
  went with a picture, with the gaps between them in milliseconds and how many characters there were (never the
  words). Words said while the mic stays open are timed from the words before them. They ride with the next picture
  that goes to Larry, or the next batch of events sent between turns. Words dropped when *Ask at my pauses* is off
  are excluded from the timing.
- None of this changes what Igor sees on the board. A Cockpit that doesn't yet read these fields keeps them as they
  came, and the debug page shows them once it reads them.

### Driven from the web or from the app (Igor, 2026-11-16)

- The board takes changes from one place, whoever sends them. Today that is Larry over the network. Later, Larry's
  own board rules can run inside the app, so some features work offline and without a round trip.
- Igor sees the same behaviour from either: the same push, the same text, the same single undo.
- Which features run locally is a subset still to be decided. Anything not decided runs from the web.
- Turning a source on or off never needs Igor to do anything, and a board never takes the same change twice.

## Edge cases

- Several changes in one answer, such as making room and then placing text in the gap, are applied together as one
  undo, or not at all.
- A push asked for at a line below the last ink just adds blank paper; nothing moves.
- A push asked for inside a tall drawing whose top and bottom are both more than two lines away lands under the
  drawing, so the drawing stays whole.
- An answer with changes for a different board, or for a board that was deleted, is ignored and logged.
- An answer whose change names a board revision no board can have (a fraction, or a number too large to be one) is
  refused whole like any other change the board can't take: nothing moves, Larry is told why, the rest of his answer
  shows, and the board keeps running.
- With no network, Igor's ink works as it does today. Larry's changes simply don't arrive until he can answer.
- **A change of Larry's is never lost to the app quitting** (bead context-grabber-cc75). What the board knows about
  his changes (the revision, the changes already taken, his kept texts and names, the headers and folds, the question
  cards) is saved with the ink, in the same save, never before it. If the app is killed in the moment after a change
  landed and before the board saved, or while it waited for the Pencil to lift, the change is offered again on the
  next open: it lands, or, if the board has moved on since he looked, it is refused and Larry is told, as any stale
  change is. It is never remembered as done with its ink gone. At worst, a quit cut off in the middle of a save shows his change twice,
  which one Undo takes back, and the session log says it happened.
- **Which ink is Larry's goes with the board, not the device** (bead context-grabber-p1pl). The board remembers
  which of its ink Larry or Claude made (kept marks, his ink and texts) and which strokes are kept labels, in the same
  save as the ink. *Tidy overlaps* still finds every kept label, and kept marks still never make room as if they were
  Igor's, after the app is reinstalled or the board comes back from iCloud (once the board's meaning syncs). What a
  board learned before this lived on the device and moves into the board once, at launch, with nothing lost: what
  the board already knew stays, and what the device knew is added. If the move fails it is tried again next launch,
  and until then the board still knows its labels and Larry's ink.
- **A deleted board leaves nothing behind on the device**: its ink, its picture, what it knows of Larry's changes and
  everything the device remembered about it (its thread, where the paper was scrolled, its lines and lettering).
- Older builds that don't understand a change ignore it and show Larry's answer as they do today. Nothing breaks.

## Step 2: Larry edits the ink itself

The web board (the Cockpit's `/ink`) is where these behaviours are worked out first; the iPad board follows it.

### Larry draws, erases and replaces ink

- Larry can put ink straight onto the board: real strokes, not ghosts, at the width and colour he chooses. They are
  part of the page from that moment, show in the next picture, and come back to him under the names he gave them.
- He can erase strokes by name, and replace some strokes with others (tidying a scrawl into a clean line, say) in a
  single step.
- Each answer of his is still one undo: Undo takes back everything that answer did, the strokes he drew, the ones he
  erased and the ones he moved, page count included.

### Larry groups ink

- Larry can tag strokes with notes of his own. The board never reads them, except one: a group. Strokes in one
  group move as one when he pushes or moves them, so a label and its underline never split.
- His notes go back to him exactly as he wrote them, with the strokes they belong to.
- **A text he puts notes on is ink, not a ghost** (#937; Larry, 2026-11-17, rev 180: his Judge box drew and its label
  didn't, and grouping the two came back with the label missing). A text of his that the same change adds and then
  groups, or gives any notes, lands on the board at once as kept text in his colour and lettering, under his name for
  it, never as a ghost to keep: a box and its label arrive together. It is part of the change's one Undo, it is in the
  group, it moves with the group as one, and it goes back to him as a kept text under his name, so grouping it is
  never a missing name. A text he only adds, with no notes, is still a ghost for Igor to keep or dismiss.
- A kept text he groups joins the group: it moves with it, whichever of the group's names he moves it by. Erasing or
  moving the text by its own name takes the text alone out or along with its group, as for any stroke of a group.

### Larry hears my ink change and my selection

- After each change Igor makes, Larry learns which strokes were added, which were erased and which Igor moved, by
  name, and the board's revision after it. A stroke Igor moves keeps its name, as one Larry moves does.
- When Igor circles ink with the lasso, Larry learns which strokes are selected.

## Step 3: Larry's controls on the board

### Bands, chips, buttons and hints

- Larry can lay a few controls on the board: a band (a strip across the page, such as "room opens here"), a chip, a
  button, or a hint. Each sits at a place on the board, scrolls with it, and carries a short label. They are not ink:
  they are never in the picture, never in the strokes, and never undone. He takes them away when he is done with them.
- A tap on one reaches Larry at once, without waiting for Igor's next turn, and wakes him: it is a tap on his control,
  naming which, with the event he asked to hear carried as he wrote it. (A plain tap on the board never wakes him.)
  If the Cockpit can't take it straight away, it goes with the next turn instead, and the session log says so.
- What the board sends Larry keeps to the Cockpit's limits: at most 200 events at once, none bigger than 8 KB, and the
  whole under 256 KB. An event too big is left out, and when there are too many the oldest go; either way he is told
  how many he missed.

### Larry folds and selects

- Larry can hide strokes and show them again, as a folded section would. Hidden ink is still on the board: it keeps
  its place, moves with a push, and comes back when he shows it. Hiding is part of his answer's one undo.
- Larry can select strokes for Igor, as if Igor had circled them with the lasso, ready for Igor to move or delete.

### Larry hears the margin, the view and Undo

- A finger in the board's left margin tells Larry what it did there: a tap, a hold, or a drag and how far, with where
  on the board it was. That is how Igor will ask for room by hand.
- When Igor stops scrolling or zooming, Larry learns what part of the board is on screen and at what zoom.
- When Igor undoes one of Larry's changes, Larry learns which one, by its name.

## Step 4: the board behaves like Larry's web board

Igor, 2026-11-16: the web board at /ink is the behaviour to match, its model and its gestures alike; where the iPad
board differs, this says why.

### Paste makes room

- A paste never lands on ink. It goes to the clear patch of the screen nearest its middle that holds it whole with
  half a line of air round it, right of the margin and on the page.
- When no clear patch holds it, room opens at the clear line nearest the middle of the screen: the ink below moves
  down, whole things whole, by as many whole lines as the paste needs beyond the blank paper already there, and the
  paste lands at the top of that room against the margin. It is the same push as Larry's *make room*.
- The push and the paste are one Undo, named *Paste*. A push that needs another page adds it, and Undo takes it away.
- The paste lands selected, with **Delete** beside it. Delete takes the paste away (one Undo); the room it opened
  stays, as on the web board. Selecting anything else, or any change to the ink, puts Delete away.
- Ink folded away (below) is no obstacle: a paste may land where a folded section's hidden lines are.

### Dropping ink onto writing makes room

Igor, 2026-11-17: "same as reflowing stuff below, as opposed to drop on top"; 2026-11-22: "when I drop text onto
existing text, I want it to move just like if I was to select text" (stories 969, 973–975, 979).

- When Igor drops text or ink onto other writing, the dropped ink stays where he let go. From the clear line nearest
  its top, everything below slides down by whole lines, keeping groups intact and leaving half a line of space under
  the drop. Ink above that line stays in place (stories 973 and 1172).
- Igor can start the drag with a lasso selection, by tapping a group or a kept reply, or by dragging handwriting
  directly with nothing selected. The last case makes room when the strokes move together during the gesture.
  Handwriting reflow that moves words by different amounts or moves ink on its own opens no room (story 1177).
- If ink is written, erased or moved before the drop settles, the drop stays where it landed and opens no room.
  If the drag moves Igor's and Larry's ink together, one owner's ink goes back (story 1145) and no room opens.
- Dropped on clear paper, or only touching other ink at an edge, nothing else moves: the drop is an ordinary move.
- Ink on the line the drop was lifted from is never pushed by it: a word slid along its own line, even over the
  word beside it, moves nothing else.
- The drag and the room it opened are **one Undo**, named *Move*: one tap puts the dragged ink back where it came from
  and the ink below back up. A push that needs another page adds it, and Undo takes it away.
- An Undo or Redo of a move never opens room again; only a drag by hand does. Folded ink is no obstacle, as for a
  paste.
- The session log describes the pickup, landing and outcome. See `paper_drop` and `paper_drop_after` in the
  [whiteboard event reference](../../debugging/whiteboard.md) (story 1178).

### Erasing part of a group dissolves it

- When Igor's eraser takes some, not all, of the strokes of a group (one of Larry's groups, or the letters of a
  text of his that Igor kept), what is left is plain ink: it no longer moves as one thing, and Larry's next turn no
  longer calls it his group or his text. The strokes that are left keep their names.
- Larry is told, with the strokes that went, which groups dissolved.
- Erasing a whole group, or a stroke in no group, is an ordinary erase.

### Headers fold their sections

- **A finger tap in the left margin beside a line makes that line a header.** A small ▾ shows in the margin beside it.
  A tap beside a header folds it (the mark turns ▸ with the number of lines folded) and a tap again unfolds it.
  A tap beside blank paper adds no Undo step.
- **A section ends where the ink comes back to the header's indent.** It runs from the line below the header to the
  first line that starts at or left of the header's own left edge (within half a line), or to the next header at the
  same indent or shallower. Blank paper never ends a section. When the line under a header isn't indented at all, the
  section runs to the next header at its indent or shallower. A deeper header inside a section is its own header, and
  folds on its own: folds nest.
- **Ink written under a folded header stays outside its fold** (Igor, 2026-11-23, bead context-grabber-eysh).
  Unfolding lands what he wrote under the folded header after the section's lines, and the section now ends where
  that ink begins, as a rule ends it: the next fold hides only what the fold hid before, whatever the indents say.
  Only ink the section would otherwise have taken counts; an unfold with nothing written under the fold changes no
  section. Erasing that ink lets the section run on again. The web board follows the same rule.
- **Folded lines hide and the board closes up.** What is below the section slides up to sit a line or two under the
  header, in whole lines. Unfolding puts it back; anything written under the folded header meanwhile moves down below
  the section rather than being drawn over.
- A fold is one Undo, named *Fold* or *Unfold*. (The web board's folds are not undo steps; on paper every change is,
  and an Undo of an earlier step would otherwise spring a fold open.)
- **Making or unmaking an open header is one Undo.** Undo is named *Make header* for a margin tap or that menu
  choice, and *Not a header* for the opposite choice. Undo restores whether the line was a header and whether it
  was declined as one, with every stroke left where it was. Redo reapplies the change.
- ***Not a header* on a folded header opens its lines.** One Undo restores the header and folds the lines back
  under it, with one Undo event for Larry. Redo removes the header and opens its lines again.
- Drawing an underline or # gives the header the [same Undo as the stroke](2026-11-19-whiteboard-ink-headers-design.md#undoing-a-wrong-guess).
- Folded ink is still on the board: it moves with its header, and a push never splits it from its header. Larry is
  told which strokes are folded under which header and how many lines, so folded ink is never taken for erased, nor
  for new when it unfolds.
- Headers are kept with the board on this device, by the names of their strokes.
- **A folded header says what it holds on the board.** Beside the folded header's row, a little right of its last
  stroke, a small grey "▸ N lines folded" ("▸ 1 line folded" for one) shows on the board, in the same words and the
  same place as the web board's.
- **Larry's picture shows a folded section whole, flagged folded** (Igor, 2026-11-20, W4 on PR #912: "the picture
  shows the whole section, flagged as folded"; #1013). Every picture of the board (Larry's turn, Send, Claude's
  turn) draws each folded section in full, in place, as the board would look with it open: its lines sit under the
  header and what is below comes after them, so the picture is taller than the screen by what is folded. The section
  is shaded light grey across the page, with a grey "folded" in the margin at its top and a grey ▸ beside the header
  (an open header in a picture is labelled "▾ header" past its line: the ink headers spec); a fold folded inside it is drawn whole too, inside the shading. Larry never loses what Igor
  set aside, and still sees that Igor set it aside. Igor's own board is unchanged: the section stays folded there, and
  the picture has no "▸ N lines folded".
- With the picture goes where its folded sections are, so a reader can tell the picture's places from the board's.
  Larry's marks drawn on that picture land on Igor's board where he drew them: a mark below a folded section lands
  below it on the folded board, and a mark on the folded lines lands just under their header. A mark on a picture
  sent from another device lands as the picture's frame says, unmoved by folds.
- **Erasing a fold takes the whole section.** The eraser across a folded header's "▸ N lines folded", or across the
  folded header's own ink, erases the header and everything folded under it (folds folded inside it included), and
  what was below closes up to where the header was, in whole lines. One Undo brings the section back, still folded,
  and what was below back where it was. (Across the header's ink the eraser takes those strokes itself first, so
  there it is two Undos.) A scratch-out over the marker or the folded header line does the same, with one Undo, and what it took stays gone, on the sheet and to Larry, as he writes on (#1015). An eraser stroke the iPad calls off before it lifts (a palm, a system gesture taking the
  touch) takes no fold by its marker; across the header's own ink it takes the fold only if that ink is gone from the
  board, so folded lines are never left hidden under no header.
- **A header's own ink is its words, not its underline or #** (context-grabber-bov; Igor: "a fold is erased only by
  its words or its marker"). The eraser or a scratch-out across a folded header's underline, or across a stroke of
  its # (## and ### included), takes that stroke as any ink and leaves the header's words, the fold, its "▸ N lines
  folded" and every folded line as they were (the ink headers spec, *Undoing a wrong guess*). Across the words or the
  marker it takes the section as above. By the words, the section goes when the eraser or the scratch-out takes some of
  them, not when it only passes near them, as along an underline drawn just under the words.
- **The pixel eraser takes a fold by its words only once they are rubbed through.** Across the marker it takes the
  section as the eraser does. Across a folded header's words it takes the section only when every stroke of the words
  has been rubbed, as a called-off stroke does; a rub on the corner of one letter takes that corner and leaves the
  section folded under what is left of its header.
- **Fold all and Unfold all**, and **collapse to a level**: from the hold menu on a header's mark, Fold all, 1, 2, 3
  and Unfold all. A header's level is how deep it nests with everything open. A ## or ### written at a header's start nests it under the # above it (the ink headers spec, *Header levels*). Collapsing to level *n* shows the
  headers down to level *n* and nothing deeper: every header at level *n* folds, and so does a shallower one with no
  headers under it; a shallower one with headers under it stays open.
- **A line that looks like a header shows a faint H in the margin**: one written well bigger than his usual lines
  (1.5 times his usual line height and 1.6 times his usual letters, once the board has four lines of his to judge by,
  three strokes or more, wider than tall), or one underlined across most of its width. It is only a suggestion: it
  doesn't fold and isn't kept until his margin tap there makes it a header.
- **Headers drawn in ink** (#967): an underline drawn under a line, or a # written at its start, makes it a header as
  he draws it, and a rule drawn across the page ends the sections above it. See
  [Headers drawn in ink](2026-11-19-whiteboard-ink-headers-design.md). The faint H stays for ink drawn before.

### Press and hold (#918)

- **A finger or the Pencil held still in the margin, then dragged**, opens room at the clear line nearest where it
  went down, by the drag in whole lines when he lifts; dragged up it closes blank paper only, never past the ink
  above. One Undo. (Igor, 2026-11-16, on the iPad: "push down doesn't seem to fire at all" — he reached for the
  margin with the Pencil, and the Pencil only drew.)
- **The Pencil in the margin is the handle only once it has held still**: it went down in the margin and stayed
  within about 12 points of there for half a second (a hand on a Pencil drifts; Igor's two long holds drifted past
  10). Once it has held, any drift is part of the drag. A Pencil that moves further sooner, or lifts sooner, draws as
  ever, so quick bullets and dashes in the margin stay ink. A hold leaves no ink behind: the stroke the Pencil drew
  while holding and dragging is taken away. Held on a header's mark, the Pencil brings up the outline menu whatever
  the drag, as a finger does.
- **A finger or the Pencil held still in the margin, not dragged**, or **a finger held still anywhere on the page**,
  brings up a small menu:
  *Make room here* (three lines, at the clear line nearest the finger), *Paste*, and *Make header* beside a line of
  ink (*Not a header* beside a header). Held on a header's mark, the menu is the outline: *Fold all*, *1*, *2*, *3*,
  *Unfold all*.
- **The menu is about what the finger is on** (Larry, 2026-11-22, bead context-grabber-y4y: "press-and-hold on the
  board should open a useful menu"). Igor's iPad logs from 11-16 to 11-22 show the menu came up 26 times and a row
  was chosen 3 times: held on his own writing, it offered nothing about that writing. So a finger held still **on ink**
  on the page (within a fingertip of it: the word under it, a group of Larry's, a kept text or a header's row whole,
  as the Pencil's pick-up finds it) puts the rows for that thing first:
  - *Select*: that thing is selected, as if lassoed, with its label above it, ready to drag or for the
    selection's own menu (Copy, Delete and the rest).
  - *To text* (stories 1309, 1310; #1386): that thing read and typed in its place, as To text does (*Handwriting to
    text*). It is the only place To text is offered: nothing shows beside a selection. The web board's hold menu has
    the same row, as the rule is the shared core's.
  - *Delete*: it goes, one Undo named *Delete*, and Larry hears it erased. Not offered on a header's row: rubbing a
    header out has its own rules, above.
  - then *Make room here*, *Paste* and *Make header* (or *Not a header*), as before.
  Held **off ink** on the page, or in the margin, the menu is as before. The rows stand in a column, each with its
  icon, beside the finger and kept on screen; a tap anywhere else closes it. A finger that draws leaves no dot where
  it held for the menu. Each menu shown and each row chosen is in
  the session log with what the finger was on.
- **The Pencil held still on ink for 400 ms picks up the word under it**: the strokes on that line chained while the
  gap between them is under 16 points (a group of Larry's, a kept text or a header row whole). The same stroke drags
  it, and where the Pencil lifts it lands; the Pencil's own stroke is not kept. One Undo, named *Move*. Held still
  and lifted without moving, the word is left selected. Off ink, a held Pencil draws as ever. In the margin a
  held Pencil is the hold above, never the pick-up, as a finger's is.
- On paper the word lands, and the room opens, when the Pencil lifts rather than following it live; PaperKit owns
  the stroke while it is drawn. While the handle is held, a see-through band shows where the room will open or close
  (*Every pen gesture shows what it did (#1000)* in [Whiteboard with Claude](2026-11-01-whiteboard-design.md)).
- Every hold tried in the margin is in the session log: when it began, with the finger or the Pencil and where, and
  whether it became a hold or why not (it moved first, it lifted too soon, or the board never saw it held), so a
  phone's log says what happened to a hold that didn't fire.

## Step 5: connectors (smart arrows)

Igor, 2026-11-16: the board's arrows should be smart, as on the web board (/ink): an arrow that joins two things and
stays joined when they move.

### What a connector is

- A connector is an arrow from one thing on the board to another: a kept text, a group of Larry's, or a word of Igor's.
  Its tail leaves the first thing's side that faces the second, and its head lands on the second's side that faces
  the first.
- It runs straight, unless a straight line would cross another thing (a kept text or a group). Then it bends once, an
  L made of a level and an upright leg, if either L crosses nothing. If neither does, it runs straight anyway.
- It follows its ends. When either one moves, whoever moved it (Igor's lasso, a word picked up with the Pencil, a
  push, a paste making room, a fold closing up, or Larry), the arrow is drawn again from where they are now. The
  redraw is part of that move's own Undo. When an end is folded away, the arrow points at the header that hides it.
- The eraser takes a connector whole, as any stroke, and nothing else of it is left.
- When one of its ends goes (erased, or a group or a kept text that came apart), the arrow stays where it was, as plain
  ink, as on the web board.

### Igor makes one

- Igor draws an arrow, by hand, from one thing to another, and circles it with the lasso. When both of its ends land on
  something (within 16 points), a **Connect** button shows beside the selection.
- On the iPad the lasso often takes more than the arrow: the boxes at both ends come with it, the whole diagram in one
  rectangle (#1440). Connect still shows then: it finds the arrow inside the selection (a long open stroke, with the
  marks touching one of its ends, none bigger than half the arrow, as its arrowhead, and the head at that end) and
  joins the two things at its ends. The boxes and their labels stay as they are, and a box drawn as separate lines is
  still a box: a line whose ends both meet other lines' ends, as a box's corners do (a hand-drawn corner may
  overshoot or fall short by up to 20 pt), is never taken for the arrow. A selection of things with no arrow between
  them offers no Connect.
- Connect takes his drawn arrow away and puts a clean connector in its place, joining the two things. One Undo,
  named *Connect*, gives his own arrow back.
- The head is the end nearest the rest of the strokes he circled (the arrowhead). With only one stroke circled, the
  head is where the stroke ended.
- An end on a word of his makes that word one thing: from then on it moves whole, as one of Larry's groups does, and
  rubbing out part of it makes it plain ink again (and the connector plain ink with it).

### Larry makes one

- Larry can draw a connector as one of his changes: its name and its two ends, each the name of a stroke, group or
  kept text on the board, or a point on the board. A point takes the smallest thing under it (within 16 points), or
  else the word there.
- An end that names nothing on the board draws nothing, and Larry is told which name was missing. With an end at a
  point on bare paper, the arrow is drawn as plain ink between the two points, as the web board keeps such an arrow.
- It is part of his answer's one Undo, like his ink. He can erase it by its name.

### Larry's connector marks (in his reply)

Larry, 2026-11-17: "On /ink my arrows are live connectors that follow moves and folds; on the iPad they're dead strokes
that drift when he makes room."

- Larry's reply can carry a connector among its marks, as the web board takes it: its two ends either name two things
  on the board, or are two points on his picture, each landing on the thing under it (within 16 points, else the word
  there).
- It shows as a ghost like his other marks, drawn as the arrow it would be: from one thing's facing side to the
  other's, around anything in its way, as a connector routes.
- If several replies arrive between looks, a connector sees the ready changes from earlier replies, including a named
  stroke one of those replies added.
- Keep, or Keep all, makes it a real connector, joined to its two things and following them from then on. When Keep
  all groups it with other marks from the reply, the connector still follows its ends and goes back to Larry with its
  route. It is part of the one Undo.
- An end on bare paper keeps as a plain arrow where he drew it, as the web board keeps it. A mark naming something the
  board doesn't have shows nothing, and is set aside as if dismissed.
- Dismiss throws it away, like any mark.

### What Larry gets back

- A connector goes back to Larry with the board's strokes, as a stroke under its name, so it shows in every picture he
  renders. Its notes say what it is: a connector, what it joins (by name), the sides its ends leave and land on, and
  the points of its route.
- Larry hears Igor make one as he hears any ink change: his arrow's strokes erased and the connector added.

### Known limits

- Undoing a Connect gives Igor's own arrow back, but a word that Connect made one thing stays one thing.
- Connectors in Larry's chat-reply shapes are not handled yet: only his board changes draw them.
- Larry's connectors are drawn after the rest of his changes in the same answer, on the board those changes leave.

## Larry checks a change before he sends it (#936)

Igor, 2026-11-17, after Larry's changes made a mess of his board 13f700bf: "how can you test?" Larry had no way to see
what a change would do except to send it to Igor's real board, and paused his changes until there was one.

- Larry (or an agent chasing a bug) takes a copy of a board, as the board sends him its strokes, and one or more of his
  changes, and gets back, on the Mac in seconds with no iPad and no simulator: what the board would answer him (the
  same `op_result`: applied or refused, the revision, any missing names), which of his and Igor's things moved, were
  erased, were drawn or stayed his ghosts, a picture of the board before and after with all of that marked on it, and
  the board after, to try his next change on.
- The board's own rules decide it, not a copy of them: what the iPad would do with the change is what the check shows.
- The copy can say what only the iPad knows: the board's revision, his texts still showing as ghosts, and what Igor
  moved since an older look. Igor keeping one of his ghosts can be part of the check.
- It shows neither the Pencil's wait nor folds; those are checked on the iPad.
- **His marks check too** (#941): a reply of his with marks (boxes, lines, labels: the ghosts a chat reply carries,
  placed by the picture he answered) shows them where the iPad would, and says, for each, whether a finger tapping on
  it reaches it or which other mark of his takes the tap instead. A tap at a point can be part of the check, and says
  which mark it would choose.
- **Keeping a reply as a group checks too** (#942): Igor's *Keep all* of the reply's marks (once *Keep group*) can be part of
  the check. The marks become his ink under one group named for the reply, and a later change of Larry's that moves or
  erases that group by its name shows it moving or going as one.

### A recorded board session replays too (contract v1, bead context-grabber-09tx, stories 1173, 1174, 1182, 1183)

The Cockpit keeps recorded real board conversations (its board contract, *Recorded sessions*): what the iPad posted,
in its order, what Larry replied, and the receipts. The same sessions are replayed on the Cockpit, by the agent's
whiteboard skill and here, so a change to the wire on one side shows as a failure on the others.

- **Only a scrubbed copy comes here.** This repository is public and the sessions are Igor's own writing. The copy
  keeps every id, count, revision, frame, event, change and receipt, and nothing anyone wrote: every word becomes x's
  of the same shape (any script; digits become 0), and every stroke is a straight line across its own box, snapped out to a 40-point grid. It names the Cockpit commit it came from.
  Making the copy refuses a field it doesn't know, and refuses a copy in which any word of four letters or more from
  the session's own writing is still readable.
- **On the Mac, the whole session replays** with the board's own rules, in seconds and with no iPad: each of Larry's
  batches is tried on the board as it stood when the batch arrived (Igor's strokes since his look included), and the
  answer the board gives is set beside the answer the iPad really sent on its next turn. His marks show and are tapped
  as for one reply. Any difference is listed, not hidden.
- **What Larry was told matches.** For each of Igor's turns, the revision, the last batch's answer, the number of
  events and the strokes count (and how many are new) that the turn carried are what the Cockpit's recorded hint to
  Larry says.
- **The simulator's stand-in Cockpit plays a session back**: once a session is chosen, the board's strokes post is
  answered with the counts the Cockpit gave, and each of Igor's turns on that board gets Larry's next recorded reply
  (his words, marks or batch of changes) and its receipts, in the order they happened.
- Not replayed: the pictures themselves (neither the iPad's nor the Cockpit's render of the board), and what only the
  iPad's canvas does.

## Non-goals

- Editing a kept label's words (#912).
- Scratch-out to delete (another build).
- A connector made by dragging from one thing to another (the web board's way is the lasso and Connect), and a
  connector between two plain strokes that aren't a word.
- Question cards, the writing pause learned from his rhythm, tidying overlaps (other builds).
- Running Larry's board logic inside the app for offline use.
- Controls that survive the board closing: they are Larry's live conversation, and he lays them again.

## Acceptance

- Larry asks for room below a line on a board with ink above and below it. The ink below moves down that far, rounded
  up to whole lines, the ink above doesn't move, and one Undo restores the board exactly.
- Larry asks for room at a height inside a line of writing: the cut lands at the clear line next to it (its top when
  nearer and within two lines, else its bottom), no line, text or group is split, and his next turn names the clear
  line and distance used beside the ones he asked for.
- A push that needs another page adds one. Undo removes it again.
- With the Pencil down, a push waits, then applies within a second of the Pencil lifting.
- When Igor drew new strokes after Larry looked, the push still applies to the board as it is now, and Larry's next
  turn says it applied on a newer board. When Igor moved or erased a stroke the batch names, it is refused, nothing
  moves, Larry is told why and which names, and his next answer
  applies.
- Larry's plain text arrives as a ghost, keeps on a tap, reads in a plain typeface, shows in the next picture Larry
  gets, and moves with a later push.
- The session log has one line per applied or refused change, with what moved and why, for a phone check.
- A refused change of Larry's shows *Larry's edit blocked · Retry*; Retry sends his turn, even when he already has this picture, and the chip goes once it has gone; × only
  puts it away; a change that applies afterwards clears it.
- Check the [drop and Undo cases](#dropping-ink-onto-writing-makes-room) for each pickup method.
- Larry draws two strokes, erases one of Igor's and replaces another: all of it shows at once, one Undo takes all of
  it back, and his strokes come back to him under his names.
- A push moves a group whole, even when only some of it is below the line. His notes come back with the strokes.
- Igor draws, erases and lasso-moves: Larry's next turn names what was added, erased and moved, and the moved
  strokes keep their names. A lasso selection is named too.
- A band Larry lays shows at its place and scrolls with the board; a tap on it reaches him within a second.
- Hidden ink vanishes and returns on his word, and moves with a push while hidden.
- A margin tap, hold and drag, the end of a scroll, and an undo of his change each reach him on the next turn.
- A paste over a full screen opens room at the middle: the ink below moves down whole lines, the paste sits in the
  room, selected with Delete beside it, and one Undo takes both the paste and the room away. On a screen with a clear
  patch the paste lands there and nothing moves.
- Rubbing out one stroke of Larry's group leaves the rest as plain ink; his next turn says the group dissolved.
- A margin tap beside a line makes it a header; a tap beside it folds its indented lines and the ink below closes up;
  another tap brings them back where they were. The header is only the line tapped beside: a descender on it that
  touches the next line doesn't pull that line in, and the touched line is the first line of its section, and a tap beside the touched line is that line's (it can be made a header of its own) rather than the header's above it. Folding a section holding a folded header and unfolding it leaves the
  inner one folded. Larry's next turn lists the folded strokes under their header, and none of them as erased.
- Fold all, 1, 2 and Unfold all on a two-level outline show what the outline would.
- A folded header shows "▸ N lines folded" beside it. Larry's next picture shows the folded lines under the header,
  shaded, with "folded" in the margin and ▸ beside the header, and the ink below the section after them; the board on
  the iPad stays folded.
- A mark of Larry's drawn on that picture under the folded section lands under the same ink on the folded board.
- The eraser drawn across that marker erases the header and its folded lines, the ink below closes up to where the
  header was, and one Undo brings the section back folded with the ink below where it was.
- An eraser stroke across that marker that the iPad calls off (a palm landing, a system gesture) leaves the fold, its
  header and the ink below as they were.
- The eraser across a folded header's underline (or a stroke of its #) takes only that stroke: the header's words,
  "▸ N lines folded" and the folded lines stay, and the ink below stays where it was. Across its words it takes the
  section.
- The pixel eraser rubbed on a corner of one letter of a folded header leaves the section folded; rubbed through every
  stroke of the words, it takes the section.
- A line written big or underlined shows a faint H; a margin tap there makes it a header.
- A finger held in the margin and dragged down two lines opens two lines; held and lifted, or held on the page, it
  shows the menu. The Pencil held on a word for under half a second and dragged moves that word, and nothing else.
- A connector from one group to another is drawn straight; a group put between them makes it bend once around it;
  moving that group away straightens it again. Lasso-moving an end redraws the arrow to it, and one Undo puts both
  back.
- Igor lassos an arrow he drew from a word to a kept text: Connect shows, and a tap leaves a clean arrow between them
  that follows either one when it moves. One Undo gives his arrow back.
- Larry's connector by names and by points both land; one naming nothing draws nothing and is reported missing; one
  with an end on bare paper is plain ink.
- Erasing one end leaves the arrow as plain ink; his next strokes carry it without its connector notes.
- Larry's reply with a connector mark between two of his groups shows a ghost arrow between them; Keep makes it a
  connector, and a push between the groups then redraws it to where they are.
