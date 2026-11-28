# Whiteboard: Claude and Larry draw back (ghosts and shapes)

Igor, 2026-11-01: "what about the ghosting idea, does that work? How does Larry write back? I don't grok that yet",
then "make an issue for cockpit, build your side". Builds on [the whiteboard](2026-11-01-whiteboard-design.md)
(stories 344, 345, 349–377 and 380–389). Larry's half on the Cockpit is [cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85).

## The idea in one line

Claude and Larry don't paint pixels. They answer with **shapes**: a short list of lines, arrows, boxes, circles,
freehand curves and labels, placed on the board. The app draws those shapes faint, as **ghosts**, in Claude's or
Larry's colour. A ghost looks like ink, only fainter: a solid line with round ends, as wide as a kept stroke (Igor,
2026-11-02: "via ink strokes"), and a label is its letters written in single pen strokes, as a hand would (#895). A tap keeps one as real ink. Nothing they
suggest changes the board until Igor keeps it.

## What Igor sees

### Ghosts from Claude (stories 344, 350–352, 354, 357–359, 370–377)

- He draws, then lifts the Pencil. **Once he has stopped writing** (see *When he has stopped writing*, below: 1.5 to 5 s by his rhythm from 2026-11-16, story 892; half a second before that, story 660, and 1 s before 2026-11-10) Claude is asked, and within a few seconds faint
  shapes draw themselves in, one after another, in Claude's colour (orange): the box his arrow points at, a label, the
  third circle. Only one turn is asked at a time; strokes made meanwhile get their own turn after the next
  pause, which waits for the tool to lift.
- **Claude's marks arrive one at a time** (cockpit#85), each as the model makes it, not all together at the end. Where
  a Cockpit answers all at once, they all arrive then and draw in one after another as before; the app asks in a way
  that gets either.
- While ghosts show, the bar says how many and *tap one to keep it*.
- **A tap on a mark offers Keep and Dismiss** (#883; Igor, 2026-11-14). A finger tap on one of Claude's or Larry's
  marks (the Pencil draws) changes nothing on the board yet: two small buttons, **Keep** and **Dismiss**, appear beside
  that mark, always wholly on screen, moved inward when the mark is at an edge of the view. They follow the mark when
  the board moves. A tap on another mark moves them to that one.
  - **The tap goes to the mark nearest the finger** (#941; Larry, 2026-11-17: his four named boxes, and every label
    inside a box was half out of reach: the box, drawn first, took any tap within 22 points of its sides, which on his
    60-point boxes was 38 to 57 percent of each name). A tap anywhere on a label's letters, or in the box the
    letters fill, is on the label. When the finger is within reach of several marks, the nearest takes it; between
    two as near, the one drawn later, on top. So a label inside a box is tapped on its words and the box on its sides,
    whichever came first in his reply, and a line crossing another is chosen where the finger is closer to it.
  - The session log says, for each mark chosen, how many marks were within the finger's reach, and, for each set of
    marks shown, how many of each kind, so a mark that can't be tapped shows up in a phone's log.
  - **Keep all keeps every mark of Larry's showing, each reply as one thing** (#942; Igor, 2026-11-17, via Larry:
    "accept the group", after keeping his four named boxes one mark at a time; Igor, 2026-11-22, bead
    context-grabber-yqau: "Keep group and Keep all become one button, Keep all"). There is one such button, **Keep all**,
    in the note's line beside the count of marks to keep (below); beside a chosen mark there are only Keep and Dismiss, which read *Keep group* and *Dismiss group* when the mark's reply shows two or more (below).
    One tap keeps every mark of Larry's still showing, from every reply of his that shows, where each showed, as ink in
    his colours: nothing of Igor's moves, as with one Keep, unless the marks would land on what he wrote after Larry
    looked (below). It is **one keep**: one room made for all of them and **one undo takes them all back**, named
    *Keep all*.
  - **What was kept together moves together.** The marks of each reply of his kept this way are **one group**, as
    Larry's own groups are: a push or a paste's room never splits it, the Pencil held on any of it picks up all of it,
    and Larry hears it as one group (its strokes carry the same group note, named for his reply) that he can move or
    erase by that one name. Tidy overlaps leaves it as it is. Two replies showing are two groups, each named for its own
    reply. A reply with only one mark left showing, and Larry's text from a change of his (which belongs to no reply),
    are each kept as one thing on their own, as Keep keeps them. A mark of the reply Igor already kept or dismissed is
    not in its group; Claude's marks never are, and Keep all leaves them showing.
    - **A drag that picks up part of a group brings the rest along** (bead context-grabber-1xdh; Igor, 2026-11-22: "when
      I select and want to move something, it's borked"). On the iPad a finger drag on Larry's kept text, with nothing
      selected, is taken by the system's handwriting view, which picks up only the paragraph under the finger: it moved
      102 of a kept reply's 120 strokes and left the rest of the reply where it was. When a drag by hand, with nothing
      selected, moves part of a group and all of what it moved went the same way the same distance, the rest of the
      group moves that same way too, so the whole group lands where he let go. If the drop opens room, the whole
      group is what makes it, nothing of the group is pushed, and the drag, the rest of the group and the push are one
      Undo named *Move*. It doesn't apply to a lasso of part of a group (he chose that part), to handwriting the system
      rewrapped (its strokes moved by different amounts), to a move the owners-apart rule puts right, or to Undo and
      Redo. The session log says, for each drop, how many strokes it brought along and from which groups.
  - **Keep beside any mark of a reply keeps the whole reply** (bead context-grabber-it0e; Igor, 2026-11-22, 21:34,
    option A, after keeping one eye, both labels and the arrow of Larry's smiley face one at a time and finding the
    face, the smile and the other eye left behind as marks to keep). Keep beside a chosen mark of one of Larry's
    replies keeps every mark of that reply still showing, where each showed, as one group named for the reply, exactly
    as *Keep all* keeps that reply; his other replies' marks stay showing. It is one keep: one room made, one undo
    named *Keep* takes the whole reply back. A reply with only that mark left showing, his text from a change (which
    belongs to no reply) and any mark of Claude's are kept alone, as before.
  - **A reply of several marks shows, is chosen and is turned down as one group** (#1383; Igor, 2026-11-24, 05:10,
    after dismissing three of Larry's four list lines one at a time and keeping the fourth: "it should've come in as
    keep group"). While two or more marks of one of Larry's replies show, a faint dashed outline in his colour sits
    round all of them, so the reply reads as one thing before anything is tapped. A tap on any of its marks chooses
    the whole reply: the buttons sit beside the outline, not beside the one mark, and read **Keep group** and
    **Dismiss group**. A tap on another mark of the same reply changes nothing; a tap on another reply's mark, or off
    the marks, moves or puts the buttons away as before. **Keep group** is Keep above (the whole reply, one group, one
    undo). **Dismiss group** takes every mark of that reply still showing, and none of them comes back when the board
    opens again; his other replies' marks stay. To drop one piece of a reply, keep the group and erase that piece. A
    reply with one mark showing, his text from a change and Claude's marks show no outline and keep Keep and Dismiss
    for that one mark. Kept, the group is picked up and dragged whole, as any group (below). No new Cockpit op is
    needed: the marks of one reply of Larry's are its group.
  - **A finger tap on any stroke of a group selects the whole group, ready to drag** (#947; Igor, 2026-11-18: "when I
    click select-all, I want some notion of fixed object on finger-click to move"). A group is a reply kept with
    *Keep all*, or one of Larry's own groups. The tap must land on one of the group's strokes, within a finger's
    reach of its line (a fingertip, about 22 screen points, whatever the zoom), not merely inside the group's box. All
    of the group is then selected, as a lasso round it would select it, and a finger drags it as one; one Undo puts it
    back where it was. The Pencil keeps drawing over it as before, and drawing fingers leave no dot for the tap.
    - For up to three seconds after the tap or until the next touch, a dot from that tap is taken back and the whole
      group stays selected, even when the iPad is slow to answer. A second tap gets its own window. New ink and ink
      restored by Undo or Redo are kept.
    - Only on a board he can draw on, with no marks of Claude's or Larry's showing (with them showing a tap chooses a
      mark, as above), and never in the margin (the outline's). One of Larry's controls showing (a button, chip, band
      or hint) changes nothing: a tap on the control is the control's and reaches Larry (it selects nothing and opens
      no words), and a tap anywhere else picks up as here, the first tap selecting and the second rewording (bead
      context-grabber-9d1; decided 2026-11-22, Igor away, reversible).
    - A tap off every group, on his own writing or blank paper, does what it did.
    - **A word of his own that a connector joins is one thing** (Igor, 2026-11-22, decision card igor2-88g.1620.5:
      "a connected word is one thing; a tap takes it whole"). An arrow end on his word makes the word a group, as the
      outline already labels it *Group* (story 1094), so a finger tap on any stroke of it selects the whole word,
      ready to drag, as for Larry's groups. His writing that no arrow joins stays plain ink.
    - **A kept text inside a group** (decided 2026-11-22, Igor away, reversible): the first tap selects the group; a
      second tap on the text while its group is selected opens its words for rewording, as a tap on a text outside
      any group does at once.
    - The session log says, for each such tap, the group's name, how many strokes it selected, how a finger touches
      the paper then, whether fingers draw, and whether the group was still selected a beat later.
  - **A finger tap on anything of Larry's he kept, outside a group, picks up that one thing alone** (#1171; Igor,
    2026-11-22, on the iPad, with Larry's steps written inside a box of his: "I want to be able to click what Larry
    wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"). A
    text of Larry's (kept with Keep, kept alone by Keep all, or written by a change of his), a mark of his or Claude's
    kept with Keep (or alone by Keep all), and a stroke Larry drew on the board: the tap on it, within a fingertip of its line as for a
    group, selects all of that one thing and nothing else, not his own ink under or beside it, nor Larry's other
    marks; a finger drags it alone, and one Undo puts it back. A lasso still takes whatever it rings, his ink
    included, and can split a text of Larry's.
    - Under the same conditions as a group's tap (a board he can draw on, no marks showing, never in the margin; his
      controls showing change nothing, except that a tap on one is the control's); a thing of Larry's in a group is
      the group's, as above.
    - **A text of Larry's**: the first tap selects it (its label reads *Text · tap to reword*); a second tap on it
      while it is selected opens its words for rewording. A text of Igor's own (one he typed, or a To text result)
      still opens at the first tap.
    - Where his own ink is nearer the tap than Larry's, the tap is his ink's and does what it did.
    - Not yet (non-goal): a mark still showing, not kept, is never dragged; it is kept first, then picked up.
    - The session log says, for each such tap, that it was one thing of Larry's rather than a group, how many strokes
      it selected, and whether it was still selected a beat later.
  - **The board never offers to convert handwriting to text** (bead context-grabber-4nnh; Igor, 2026-11-22: "Also never
    prompt me to convert"). On the iPad, a selection of handwriting (a finger tap on a group or on a text of Larry's,
    or a lasso) brought up the system's own handwriting popover over it about a second later, and with it the
    selection silently went: the tapped group showed selected, then nothing was, and the finger drag that followed
    moved nothing. iPadOS has no setting to switch that offer off, so the board puts it away as soon as it shows, on
    a selection, on a tap or anywhere else over the paper. The board's own *To text* (story 1095) is untouched and
    is the one way to turn ink into text.
    - **A tapped group stays selected and draggable.** If the selection a group's tap (or a tap on one thing of
      Larry's) made goes while the tap's window is open (three seconds, or until the next touch), with no touch of
      Igor's since, the board puts the whole selection back; a finger drag then moves it as one. A selection Igor
      changes himself, by a touch, a lasso or a tap elsewhere, is never put back. The board tries at most three times
      per tap, then leaves it and says so in the log.
    - The session log says each time the system offers its popover (what it is, what it points at, what holds the
      keyboard focus, how much is selected), whether the board put it away and how much was selected after; and, for
      a tapped group whose selection went, when it went, whether the offer was showing, and whether the put-back held.
  - **PaperKit's handwriting reflow never carries Igor's ink and Larry's together** (bead context-grabber-eg7v; Igor,
    2026-11-22: keep the reflow, but it must never group his ink with Larry's or Claude's). On the iPad a finger tap on
    a text of Larry's can open the system's handwriting reflow over it, which takes Larry's text and Igor's strokes
    written beside it for one line of handwriting; a drag there moved all of them together. The reflow stays, and
    whenever it (or any move of the system's own that Igor didn't select) moves both his ink and Larry's or Claude's at
    once, only one owner's ink stays moved:
    - **The owner with more of the moved strokes keeps the move**; the other owner's strokes go back exactly where they
      were. On a tie Igor's ink keeps it. So the iPad's case (Larry's 52-stroke text and two strokes of Igor's) moves
      Larry's text and leaves Igor's two strokes in place; Igor reflowing his own line with a few of Larry's strokes
      caught in it moves his line and leaves Larry's strokes in place.
    - The move and the put-back are **one Undo**, which puts everything where it was before the reflow.
    - A move of only Igor's ink or only Larry's is left as the reflow made it. A drag of what Igor selected (a lasso, a
      group's tap, a tap on one thing of Larry's) is never split: a lasso round both owners' ink still moves both.
    - Undo and Redo are never split either.
    - The session log says, for every move the rule looked at, whether it split it and why not when it didn't (one
      owner, all selected, Larry's strokes unknown), how many strokes went back and whose, and whether the system's
      own step was taken back cleanly or the strokes were moved back by hand.
  - The buttons stay together, beside the mark and wholly on screen as before, and never under the board's top-right
    corner (? and Feedback, and *Larry's edit blocked* when it shows): placed there, they move below that corner. Each
    takes at least 36 points each way, and a tap on either, or between them, never reaches the paper.
  - The session log says how many marks a Keep all took, its strokes, and the groups it made, by name.
  - **Keep** does what a tap used to: the mark becomes real ink in Claude's colour (or the one it asked for, below),
    and his eraser and undo treat it like his own strokes. One undo takes it back.
  - **A reply of Larry's makes room for what Igor wrote after Larry looked** (#894, stories 1004–1006, 1037; Igor, 2026-11-14: push what he
    wrote since the picture down the page to make room for Larry's reply, rather than put the reply below his ink;
    2026-11-19, on a board where a kept group of Larry's landed on his writing: "group pushes purple text out of the
    way"). Larry places a reply on the picture he was sent, often minutes old, and Igor keeps writing meanwhile. This
    is the *A late reply* rule of the object-layer design (PR #912), which needs nothing from that design's objects.
    - When **Keep** or **Keep all** would put marks of Larry's on ink drawn or pasted *after* the picture that reply
      answers was taken (ink he could not have seen), that ink makes way in the same step: from the clear line at or
      above the top of the newer ink the marks land on, everything below moves straight down by whole lines until the first
      of it sits half a line under the lowest of the kept marks. Whole things move whole (a line of writing, a kept
      text, a group, a folded section); nothing is scaled or split. Ink above that line stays.
    - **His marks stay exactly where he put them**, beside what they name. Only the ink moves.
    - **Ink that was in his picture never makes room this way.** If he drew over it (a circle round a word, an arrow
      onto it) he meant to. A mark that lands on blank paper, beside ink without touching it, or only on ink he saw,
      moves nothing, as before.
    - **Only Igor's own ink makes room.** Marks of Larry's or Claude's kept or drawn after the picture (a box of his
      kept a moment before the arrow that ends on it, a text of his, ink his changes drew) never do. The board knows
      them on the device that kept them; a mark kept on another device is taken as Igor's.
    - The keep and the room are **one step**: one Undo puts Igor's ink back up and takes the marks back, and Redo does
      both. A page is added at the bottom when the push needs one.
    - **A reply that arrives with the board closed** follows the same rule. The board remembers on this device when
      each picture it sent Larry was taken, so a reply shown when the board next opens still knows what Igor wrote
      after it. A reply to a picture this device doesn't remember (sent from another device, or more than 200 pictures
      ago on this board) keeps as before, with nothing moved.
    - It is Larry's marks, drawn marks kept with Keep and everything Keep all keeps, his text included. His text
      kept with Keep, or from a change of his, already makes room as it lands ([Larry edits the
      board](2026-11-16-whiteboard-board-ops-design.md), *His text makes room*); Claude's marks, which answer in
      seconds, are unchanged.
    - **Keep all makes room once, for all of it**: one room, under the lowest of the marks it keeps, for every thing
      of Igor's that any kept mark lands on and that he made after the picture *that mark's* reply answers. When
      replies to different pictures show together, ink in a reply's own picture never makes room for that reply's
      marks, even if an earlier reply's picture didn't have it. A mark whose picture's time this device doesn't know
      makes no room of its own, but the room made for the others goes under it too. His text from a change kept with
      them makes room in that same one room, as it does with Keep: whatever it lands on goes down under it, a frame
      it sits wholly inside aside, and the text stays where it showed.
    - His other unkept marks move with the ink they hold to (*His marks hold to the ink they answer*, below). Not yet
      (#912's *Reflow rules*): blank paper further down doesn't take up the push: the push moves everything below the line, as a paste's room does, marks of Larry's
      kept earlier from the same reply included (Keep all keeps each reply whole, so this only bites when Igor keeps a
      reply mark by mark).
    - The session log's keep line says whether it made room, where and how far, how many things it landed on that Igor
      wrote after the picture, and when that picture was taken, or that its time isn't known.
  - **Dismiss** removes that mark and only that mark (beside a reply of several marks it is *Dismiss group* and takes
    the whole reply: *A reply of several marks shows, is chosen and is turned down as one group*, above). It isn't kept, and it doesn't come back, on the next look or the
    next time the board opens. The other marks stay, and the rest of an answer still on its way still lands.
  - **A tap anywhere else puts the buttons away and changes nothing**: no mark is kept or dismissed by a stray tap.
    Starting to draw puts them away too, and the Pencil keeps drawing while they show. If their mark goes (Claude's
    fade, a new set of Claude's replaces it, or *Ask at my pauses* goes off) they go with it.
- **Ghosts stay while he draws** (Igor, 2026-11-02: drawing together, not taking turns). The Pencil touching down
  leaves them, and an answer that lands while he draws still shows. Each new answer from Claude replaces his unkept
  ghosts and leaves Larry's: the old set stays until the first new mark lands, so the board is never blank between
  them, and an answer with nothing to add clears them when it ends. Claude's fade by themselves **30 s** after the last
  of them appears; Larry's stay until kept or dismissed, or until Igor writes over one and posts (*His marks hold to
  the ink they answer, and fade when written over*, below).
- **A tap off the marks dismisses nothing** (#823, then #883): one stray tap must never lose a mark, least of all
  Larry's, which don't come back. Clearing a mark takes its own Dismiss.
- **A tap on his own selection is still his, marks showing or not** (#1170; Igor, 2026-11-22: "Click, select, then
  delete did nothing"). With ink selected, a finger tap inside the selection that reaches no mark keeps the selection
  and brings up its menu (Cut, Copy, Delete and the rest), exactly as it does with no marks on the board. Only a tap
  that reaches a mark chooses that mark (and lets the selection go), and a tap off both the marks and the selection
  lets the selection go and puts Keep and Dismiss away, as before. The session log's tap line says whether the tap was
  inside the selection and whether the selection was kept.
  - **What the tap lands on inside it doesn't matter** (context-grabber-nkh; Igor, 2026-11-22: "Igor's own selection
    always wins a tap"). A lasso round several things (a group of Larry's, one of his things, a kept text, his own
    ink) is one selection: a finger tap inside it on any of them keeps the whole selection and brings up its menu. It
    does not select that group or thing alone, and it does not open the text's words. Only when the selection is
    exactly the one thing tapped (a group or thing of Larry's picked up by an earlier tap, or one text) does the tap go
    on to it: a second tap on a selected text opens its words, as before. A tap outside the selection does what it did
    before. The session log says when a tap was kept by the selection and what it landed on.
- **A tap on the selection's menu is the menu's, marks showing or not** (context-grabber-tcy0; Igor, 2026-11-22: "I'm
  gonna select this text, then hit delete... when I delete nothing happens"). With something selected (his ink, a text,
  a shape) and Larry's marks on the board, the small menu that floats beside the selection (Delete among it) does what
  its button says: Delete removes what was selected. A tap on that menu is never a tap on the board: it does not let
  the selection go, does not choose a mark beneath it, does not open a text's words or select a group under it. The
  session log says when a tap landed on the menu and what was selected as it did.
- **Where a finger draws** (an iPhone, an iPad with no Pencil, or with the system's Pencil-only setting off), it stops
  drawing while ghosts show: it taps and pans, so a tap on a mark leaves no dot. With no ghost left (kept, dismissed or faded) it draws again.
  - **A tap off the marks gives the finger its pen back** (context-grabber-2eml; Igor, 2026-11-22: "the iPad looks like
    it's stuck", then, via Larry, that a tap off should exit selection). A finger tap on empty board, reaching no mark and
    not inside his own selection, puts Keep and Dismiss away as before and also lets the finger draw again, with the
    marks still showing. A finger writer is never stuck panning: one tap and he writes. A tap on a mark still chooses
    it, with no dot left where he tapped, and its Keep and Dismiss work as before. The finger stays drawing until no
    mark is left; the next marks to arrive after that put it back to tapping and panning.
  - **Once the Pencil has touched a board, a finger never draws** (Igor, 2026-11-22: "I should never have finger drawn
    if I'm using the pencil"). From the Pencil's first touch on any board until the app is next launched, and always
    where the system's "Only Draw with Apple Pencil" setting is on, a finger pans, selects and taps, marks showing or
    not, and a tap off the marks never turns finger drawing on. The tap-off rule above is only for someone writing
    with a finger and no Pencil.
  - The session log says each time the finger starts or stops drawing, and which rule decided it: marks arriving, a tap
    off, no marks left, or the Pencil.
- A ghost turn gives up **10 s** after it was asked, however much has arrived by then (the Cockpit's model takes about
  3 s, and an answer to an older drawing still lands where that drawing was). If no mark has arrived, none is shown and
  the bar says *Ghosts: the Cockpit isn't answering*. **An answer cut off after a mark has arrived is no failure**: the
  marks already drawn stay, and the bar says nothing. A turn the Cockpit says came too soon (it takes one every 2 s)
  is quietly skipped: the bar says nothing and the ghosts on the board stay.
- **Ask at my pauses** is a switch in the board's bar, on by default and remembered. Until 2026-11-22 it was called
  *Ghosts* and read as Claude's alone (bead context-grabber-4ic; Igor, design board: "the switch becomes 'Ask at my
  pauses' for whoever answers"). It is about whoever answers the board, Larry or Claude. Off, nothing is asked after a
  pause, whoever the responder is. Claude's ghosts go at once and any more from that turn are dropped. Larry's
  marks already showing stay. *Send to Larry* still goes when tapped.
  - VoiceOver reads *Ask at my pauses: on* or *Ask at my pauses: off*, followed by the number of marks showing if any.
    The icon is sparkles when on and a crossed-out eye when off. See [the whiteboard design](2026-11-01-whiteboard-design.md)
    for the long-press menu and help sheet.
  - **The mic still needs it on** (confirmed 2026-11-22). See *Talking while drawing* below for what happens when
    it goes off.
- Ghosts need the Cockpit. When it can't be reached the board draws as before; the bar says *Ghosts: the Cockpit
  isn't answering* until a turn gets through.
- Only on the device that draws the board. A board that is look-only gets no ghosts.
- A point in an answer that lies past anywhere the board could reach is ignored, and a shape left with too few points
  isn't shown: a model's bad number never breaks the board. A label with nothing to draw (an emoji has no outline)
  isn't shown or counted either.
- **A long label wraps to the picture's width** (#1526; Igor on the iPad, 2026-11-26: "Larry ink should be wrapped as
  required"). Larry sends a label as one line at whatever length he wrote it, so a long one ran past the right edge of
  the board he was looking at. A label that would cross the right edge of the picture he was sent (less a small
  margin) goes on to further lines, breaking between words and at any newline he wrote; a single word too long for the room breaks where it must.
  Each further line starts at the label's left edge, one line pitch lower, the pitch in proportion to the letters' size
  (a fifth more than their height, the Cockpit's own line height, so its placer and the board agree). A label that fits draws as before, on one line, and a label placed so near the
  edge that hardly any room is left still gets a few words to a line, never one letter. Keeping it keeps the lines as
  shown, and a tap anywhere in the box its lines fill reaches it. Texts with no picture behind them (a reworded text,
  a word turned to text) don't wrap: they have no edge to wrap to.

### When he has stopped writing (stories 892–894; Igor, 2026-11-16: "match Larry's web board")

A pause after the last stroke asks Claude for ghosts, or hands Larry the picture on a Larry board. A fixed half second
asked in the middle of a sentence; the Cockpit's web board (*/ink*) waits the way voice detection waits for a speaker,
and the iPad now waits the same way.

- **The wait follows his rhythm.** The board learns the gaps between his strokes (the median of the last forty, a gap
  over 3 s being a pause, not his rhythm) and waits about **four times** his usual gap, never less than **1.5 s** and
  never more than **5 s**. Until it has seen three gaps it takes a usual gap of 0.35 s, so the first wait is 1.5 s.
- **Mid-line waits longer.** A last stroke in the middle of the page, away from the start and the end of a line, makes
  the wait half as long again, within the same 1.5 to 5 s; strokes still coming faster than his usual make it a quarter
  longer again.
- **End-of-thought cues cut it to 1.5 s**, counted from the lift: a question mark (a small dot just under the stroke
  before it); the hovering Pencil going back to the start of a line below the last stroke; and the hand leaving the
  paper (no Pencil hover for a second, on an iPad whose Pencil hovers). A cue after 1.5 s has passed asks at once. A
  pause is cut short once.
- **The Pencil going down cancels a turn that hasn't landed.** Writing again means the picture Claude is looking at is
  already stale: the request is dropped, any of its marks that had arrived go, and words spoken with it wait for the
  next turn. The bar says nothing about it, as nothing failed. The next pause asks about the board as it is then. A
  Larry turn already handed to him stays out, as before.
- **Larry's turns wait the same way.** On a Larry board the picture goes after the same learned pause; one Larry turn at
  a time, as below.
- The session log says, for each pause, how long it waited, why (*rhythm*, *mid-line*, *+quick*, *question*, *new line*,
  *hand away*) and his usual gap, so the iPad can show whether it feels right.

### Keep all and Tidy overlaps (stories 895, 896, 897; Igor, 2026-11-16: "match Larry's web board"; 2026-11-22: "Keep all behaves like Keep group")

Larry often answers with several labels down the page. Kept one by one they land exactly where he drew them, and on a
board that moved on since his picture a label can land on Igor's writing. The Cockpit's web board (*/ink*) keeps them
in order and can tidy overlaps. On the iPad, since 2026-11-22, **his marks stay where he drew them and Igor's newer
writing makes room**, the one rule every keep follows (bead context-grabber-yqau; it replaces moving a label down to
the first clear space, which the first Keep all did).

- **Keep all**, in the note's line beside the count of marks to keep (as on the web board's ghost bar), keeps every mark
  of Larry's showing at once, as one keep: **one undo takes them all back**. It is there only while his marks show. It
  keeps every reply showing; Keep beside a mark keeps only that mark's reply (bead context-grabber-it0e), and there is
  no separate Keep group. Each mark becomes ink where it
  showed; each reply's marks are one group (*What was kept together moves together*, above); and what Igor wrote after
  a reply's picture, where that reply's marks land, moves down in whole lines under the lowest kept mark, in the same
  step (*A reply of Larry's makes room*, above). Ink that was in the picture never moves for it. Nothing of his comes
  back on the next look or open, as for a mark kept on its own.
- **Board menu → Tidy overlaps** (one row: the menu has no room for more and still closes after a pick, #848) lays out again, top to bottom, every kept label (and pasted text) that sits on other
  ink, his or another label above it: each moves down under what it sits on, as above. Ink that only touches a label's
  edge isn't under it. His own strokes and kept shapes stay where they are. **One undo takes the tidy back.** With
  nothing to move the bar says *Nothing overlaps* until the board next changes, and tidying a tidy board changes nothing.
  A label Larry grouped with his box (or any group of his) stays where it is with its group: Tidy never pulls a
  group apart, so a grouped label on ink is left on it, and the labels around it still clear it.
- Labels are known by how they were made: the strokes of one kept label or one paste are made in the same moment, and the
  board remembers those moments, on this device. A label kept on another device, or before this build, is ink like
  any other and is never moved.
- Folded ink (hidden under a folded header) is neither moved nor in the way: a kept label never moves for ink you can't
  see, and a folded label stays where it is until it is unfolded.
- A tidy or a keep that moves ink past the last page brings the pages it needs, as any keep does.
- The session log says what each did: how many marks were kept and how many moved, how many labels the tidy found and
  moved.

### Larry chooses the buttons beside his reply (stories 1352–1353, #1525)

Beside a mark of Larry's the buttons have always been Keep and Dismiss (*Keep group* and *Dismiss group* for a reply of
several marks). Now **the reply says which buttons it offers**, so a new choice reaches the board without a new build.

- A reply can name its choices, in order, each with an optional label. The same choices apply to marks drawn on the
  picture and to pending text added by board edits. Moving pending text keeps its original choices.
- The board shows a button for each choice it knows, in the reply's order. Blank labels use the board's own names
  (*Keep* or *Keep group*, *Dismiss* or *Dismiss group*). If the labels are too wide for the window, the chooser uses
  those standard names in the same order.
- A reply that names no choices offers Keep and Dismiss as before. A choice the board doesn't know yet is left out, and
  the session log names it (a few, cut short), so Larry can offer a choice before the build that does it reaches Igor.
  A reply whose choices are all unknown still offers Keep and Dismiss, so a mark can always be kept or dismissed.

### His marks hold to the ink they answer, and fade when written over (stories 1180, 1181, 1269–1271; bead context-grabber-p2an; Igor, 2026-11-23, 16:55: "Anchor, and fade when written over")

A mark of Larry's that Igor hasn't kept or dismissed answers something on the board: a check on a word, a label beside
a line, an arrow to a box. Until now it sat at the place it landed while the board moved under it: a fold, a drag or
room for a reply slid his ink away and left the mark on blank paper or on someone else's ink, and Igor's new lines
could run straight over it (board 5c232430, 2026-11-23: his new lines landed on Larry's *got all 33 strokes* label).
Unkept marks still take no room. Instead each holds to what it answers, and when Igor writes over one it fades and
goes with his next post.

The rule is the same for every unkept mark, Larry's and Claude's (Claude's fade by themselves in 30 s anyway), and for
his text from a change shown as a mark. A kept mark is ink and follows the board's rules for ink. A connector mark
already follows what its ends join (story 917) and holds to nothing more, though writing over it fades it the same.

- **What a mark holds to (its anchor)** is chosen once, when the mark lands on the board, against the board as it
  shows then (folds closed, and a mark drawn on a picture with folds open first brought to the folded board, as
  story 1046 does). The board's units are what moves whole: a stroke, a kept text, a group, a header's row. Of the
  units that show:
  - the one the mark overlaps most, if it overlaps any;
  - else the nearest unit above it or beside it (one whose top is above the mark's middle), by the gap between their
    boxes; between two as near, the one made later;
  - else nothing: on blank paper with nothing above or beside it, the mark stays where it landed.

  Within that unit the mark holds to the strokes nearest it, then to the rest of the unit's line (a word of Igor's
  writing is several units, a stroke each), so an erased stroke or a reworded word hands it on to the next. A mark shown again when the board opens holds to the anchor it had, not one chosen again; a reply that
  lands with the board closed chooses its anchor when it is first shown.
- **Where the anchor goes, the mark goes, by the same amount.** Through every change of the board:
  - **A move** (a drag, a lasso's move, Larry's own move, a group carried along): the mark moves with its unit.
  - **Room** (the margin's room handle, *Insert space*, a paste's or a drop's room, a late reply pushing his newer
    writing down, Larry's room): the mark moves exactly when its unit moves. Room opened between a mark and the unit
    it holds to leaves the mark beside its unit; room through the mark itself does too. A mark never splits.
  - **Fold**: a mark whose unit folds away folds with it and doesn't show; a mark that holds to the header's own row
    stays with the row. **Unfold** brings it back beside its unit, wherever the unit now is.
  - **Erase**: a mark whose unit is all erased doesn't show (it answered ink that is gone).
  - **Undo and Redo** put the unit back, and the mark with it: undoing an erase shows the mark again, beside it.
  - Hidden marks (folded away, or their ink erased) can't be tapped and aren't kept by *Keep all*; they show again
    when their unit does.
- **Written over.** A stroke Igor draws, with the Pencil or with a finger that draws, writes over a mark when at least
  a third of its path lies on the mark: inside the box a label's letters fill, or, for a drawn mark (a line, an arrow,
  a box, a circle, a check), within reach of its line (half the two pens' widths and 2 points). So writing a word on
  a label, striking it through, or scribbling over a check writes over it; an underline below a label, a circle round
  it, a line crossing an arrow, or a word written beside it does not. A scratch-out erases only ink and leaves an
  unkept mark it runs over as it was: its zigzag goes, so nothing is left writing over the mark; Dismiss takes the
  mark. Nothing else writes over a mark: a finger that pans, taps or
  lassoes, the eraser, a paste, a drop, a keep, and Larry's own changes don't. Ink that was under the mark when it
  landed (Larry drew over it on purpose) never does either.
- **A written-over mark fades**: it shows at a third of its strength, so his writing reads on top, and stays where it
  was. It can still be tapped, kept and dismissed until it goes. Undo of the stroke that wrote over it (or erasing
  that stroke) brings it back to full strength.
- **It goes on his next post.** The next picture of the board that reaches Larry (a pause's turn, *Send to Larry*, or
  the outbox sending one that waited) takes away every faded mark, and every mark whose ink was erased, and tells
  Larry which, in the same send: the turn's report names each mark by its id with *written over* or *ink erased*. A
  send that fails, or waits in the outbox, takes nothing away. A mark taken away this way is settled as a dismissed
  one is: it doesn't come back on the next look or the next open.
- **Unkept marks take no room**, as before: a paste, a drop, room and new writing land on them as on blank paper. Only
  ink lands under ink. (The board's interaction review checks writing that lands under ink; a stroke on an unkept mark
  is not that, it is this rule's *written over*.)
- **The web board follows the same rule** (a follow-up, with its own story): the anchor, where each mark shows, whether it is folded away
  or its ink erased, and whether new strokes wrote over it come from the board's own rules, so a mark on the Cockpit's
  web board holds to the same ink and fades for the same stroke as on the iPad.
- The session log says, for each mark that lands, what it holds to (or nothing) and how far away; for each stroke that
  writes over a mark, which mark and how much of the stroke lay on it; for each post, which marks went and why.

### How a mark looks: pen, colour, lettering (#698)

Igor, 2026-11-05, picked from Larry's note: *choosing the pen width, the font and the color … it fixes the bold text at
the same time.* Any mark from Claude or Larry can say how it looks; one that says nothing looks as it does today, except
that labels are no longer bold.

- **Pen.** A mark can name its pen width, in the same units as its position on the board. A line, arrow, curve, circle,
  arc or box drawn without one keeps today's width.
- **Labels are no longer bold.** A label with no pen of its own is drawn at a pen about a ninth of its letter height
  (never under the thinnest pen, below), so its letters read as handwriting, not a marker. A label kept as ink is
  kept at that pen too. Ink kept before this change stays as it was saved.
- **A label takes the pen in Igor's hand (#949).** Igor, 2026-11-18: *ink thicker should probably match my pen
  width.* A label with no pen of its own, from Claude or Larry, is drawn at the width of the pen Igor last held on that
  board, whatever its letters' size, so his text and Larry's read at one weight. It is held between the thinnest and
  the widest pen as any mark is. With the eraser or the lasso in hand, it is the last pen he held; before he has held
  one on the board, it is the ninth of its letters, as above. The width is taken when the ghost shows, so a kept label
  is ink at the width its ghost showed even if he changes pen in between; changing pen doesn't redraw ghosts already
  showing. A text of Larry's lettered straight onto the board by a batch of his takes the same width. A label that
  names a pen keeps its own, and every other mark keeps the width above. Ink kept before this stays as it was saved.
- **Never too thin to see (#883).** No mark, asked-for pen or label's own, is drawn thinner than the thinnest pen the
  iPad shows as ink, 2.5 points on the board. A kept label of small letters came out as ink too thin to draw: saved,
  counted and sent, but invisible on the board and in the picture. Below that pen the ghost would look fine and the
  kept ink would not, so the ghost is held to the same pen and a kept mark still looks as its ghost did. Labels under
  about 23-point letters read bolder than a ninth would make them (2.5 points on 13-point letters): seen and kept
  beats thin and gone. Ink kept too thin before this stays as it was saved.
- **Colour.** A mark can name its colour. One without a colour is in its author's: Claude's orange, Larry's purple.
  A ghost in a named colour is as faint as any other ghost, and a kept mark is ink in that colour.
- **Larry's own colour (context-grabber-a3w).** Larry's purple is a colour the tool picker's swatches don't offer
  (black, blue, green, yellow, red) and far from Claude's orange, so his kept marks never look like Igor's ink, to Igor
  or to Larry reading the strokes. It was a blue, and Igor writes in the picker's blue: the two could not be told
  apart. Marks kept before this stay blue.
- **A keep never touches the pen in hand.** Keeping a mark leaves the tool Igor is holding as it was: its kind,
  colour and width.
- **Lettering.** A label can ask for *print* (the default) or *hand*, a handwriting face. The hand face is the app's
  own, not Igor's writing.
- **Letters are written, not traced (#895).** Igor, 2026-11-14, on his board: "Why weird outline font, do you get to
  pick?" and "don't use that outline view, just use like normal arial". A label's letters are single pen strokes, one
  line down the middle of each stem and bowl, the way a pen writes them, not the outline around each letter. So a label
  reads as plain, solid print at any size: at the thinnest pen (2.5 points) small letters stay open instead of filling
  in, and a kept label is the same strokes as ink. *Print* is a plain upright sans letter; *hand* is a joined, slanted
  script, still the app's own and not Igor's writing. Both are written the same way.
  - Letters, digits and the punctuation on a keyboard are written. Curly quotes, dashes and the ellipsis a model
    writes are written as their plain keyboard forms (' " - ...). A character neither covers (an accented letter, an
    arrow, a symbol) keeps its traced outline, so nothing in a label goes missing; an emoji still draws nothing.
  - Text Igor pastes onto the board is written in the same letters (#996, [the paste spec](2026-11-02-whiteboard-paste-design.md)),
    so a board never mixes written and traced lettering.
  - A label is as tall and as wide as before, near enough, and stands on the same baseline: where it lands, how it is
    tapped and how kept labels make room are unchanged. Re-flowing or rewording a label measures it in the written
    letters.
  - Kept, it is ink like any other: it erases stroke by stroke (a letter is a few strokes now, not one outline), undoes,
    saves and syncs, and the strokes Larry is sent are the letters as written. Labels kept before this stay as they
    were saved.
  - Why this and not real text (#950): written letters are still ink, so the kept-ink path, the eraser, the 2.5-point
    pen and the strokes Larry reads all keep working with nothing new on the board. A typeset font is an option
    beside them (#950, next), never instead of them. The letter shapes are the public-domain Hershey single-stroke fonts (Roman Simplex for print, Script Simplex for
    hand), carried by the app with their acknowledgement, so no new dependency or licence is added.
- **A real font, still drawn as ink (#950).** Igor, 2026-11-18, on his board: "Why not have the app render a real
  font?"; and 2026-11-20 (W3 on his decision page for #912): "a real font as a per-board or per-text option, still
  drawn as ink (keeps its id, moves, folds and erases like ink)". Single-stroke letters stay the default.
  - **Two letterings: *Single strokes* (the default) and *Real font*.** In the real font a label's letters are the
    outlines of a typeface that ships with the iPad, traced as thin ink: *print* is Helvetica, *hand* is Noteworthy.
    No font is downloaded or carried, so no licence is added. The outline is not filled, as no ink on the board is.
  - **Per board.** The Board menu has a *Real font* switch, off until he turns it on; the Board button's spoken
    label says *real font* while it is on. It is one row, not a submenu or a section: the Board menu has room for no
    more rows and still closes on a pick (#848), and a submenu's rows closed under the iPad simulator's tap. The choice is remembered by that board on this device, as its lines are; a board with nothing chosen,
    every board from before included, uses single strokes. Changing it costs no stroke, adds no undo step and
    redraws nothing already on the board: it decides how text made from then on is lettered.
  - **What the board's lettering letters:** a paste, Claude's labels, Larry's labels and texts that name no lettering
    of their own, and *To text*. A ghost takes the lettering when it shows, so a kept label is the ink its ghost
    showed even if the board's lettering changed in between.
  - **Per text: Larry or Claude can ask.** A label or a text of Larry's can name its own lettering, *single* or
    *font*, which wins over the board's for that text alone. One that names an unknown lettering is lettered as if it
    had named none. The strokes the board sends Larry name a text as before; how it is lettered is in its ink.
  - **It is the same text object.** A text in the real font keeps its id, words, colour, size and lettering: it
    moves, is lassoed, folds with its section, erases (a partial erase dissolves it to plain ink, as for any text),
    undoes in one step, and rewording it redraws it in the lettering it was made in. Its box (where it is tapped, how
    much room it takes, how a reword wraps) is measured in the font's own letters.
  - **Where it can look worse, and why it is opt-in.** Outlines at the thinnest pen fill in on small letters (the
    #895 complaint), and each letter is more ink than its single strokes. A character Helvetica or Noteworthy lacks
    falls back to whatever face the iPad has for it; an emoji still draws nothing.
- **Boxes.** Besides the shapes above, a mark can be a box given by its top-left corner, width and height. It's an
  outline; there's no fill.
- **Nothing a mark asks for breaks the board.** A colour that isn't a colour, an unknown lettering or a pen of zero or
  less is ignored and the mark is drawn as if it hadn't asked. A pen wider than any kept stroke could be is held to
  that width. A kind of mark the app doesn't know is dropped, as today.
- **A kept mark keeps its look.** Kept, it is ink at the width and colour it showed as a ghost, and it saves, syncs,
  undoes and erases like any other ink.

### Who answers the pause: Haiku, Sonnet or Larry (stories 659, 661; Igor, 2026-11-10)

Igor, 2026-11-10: "settings or a knob to go between haiku, sonnet, and the real Larry … everything measured". The
first piece of the live-whiteboard plan: a knob to compare who answers, and the iPad's own timings to compare them by.

- **The Board menu has a Responder submenu: Haiku, Sonnet and Larry**, one of them ticked, and the submenu's row
  shows which. It is a submenu so the Board menu stays short enough to close when a colour or lines are picked (#848).
  It is the board's own setting, kept on the Cockpit, so every device drawing that board answers the same way.
- **Larry is the default** (Igor, 2026-11-17: "Let's make Larry default responder"). Every board, new or old, that
  nobody has set answers with Larry; a board Igor set to Haiku or Sonnet keeps his choice. The Cockpit tells the two
  apart: it says whether a board's responder was ever set. Its own default for a board never set is still Sonnet, so
  the board makes the choice itself: opening a board nobody has set gives it to Larry, once, as if Igor had picked
  him, and the session log says it was the default and not him. (Were the Cockpit's own default to become Larry, that
  first write would simply find nothing to change.)
- **Opening a board asks the Cockpit which one it has.** Until it answers, or when it can't be reached, Larry is
  ticked. A choice Igor makes before the answer comes wins over it, and a board Igor has set is never changed back.
- **Choosing one tells the Cockpit at once**, and the next pause is answered by it. If the Cockpit refuses or can't be
  reached, the tick goes back to what the Cockpit last said and a copyable problem says what happened.
- **Haiku and Sonnet** answer with orange ghosts, exactly as above: Haiku is the faster model, Sonnet the sharper one.
  Spoken words are answered by the board's responder too.
- **Larry**: a pause brings no orange ghosts. The Cockpit says the board is Larry's, and the board goes to its chat
  thread just as *Send to Larry* sends it, and his purple marks come when he has drawn them. Words spoken to the board go
  with that picture as its message.
- **One Larry turn at a time, the latest wins** (story 662; Igor, 2026-11-10: "can we avoid this, think about best
  design"). Real Larry takes a minute or more, so his thread never fills with pictures:
  - While a turn is out (a picture sent, no answer from him yet on the thread) the bar's note begins with Larry's clock (*Larry · 0:00*, story 667), and
    further pauses send nothing. They only note that the board moved on; words spoken meanwhile wait.
  - When he answers, or after **3 minutes** with no answer, **one** fresh picture of the board as it is then goes, with
    the words that waited, if the board moved on or words waited. Otherwise nothing goes and the bar stops saying he
    is looking.
  - **Larry closing the turn with nothing to say counts as his answer** (stories 811–813, #913; Igor, 2026-11-16, Larry's option (a)).
    Larry sometimes marks the picture done on the thread and writes nothing back. Done with no reply after it ends the
    turn exactly as an answer with no shapes would: the clock stops, and one fresh picture goes if the board moved on
    or words waited, else nothing. In place of the clock the bar's note says *Larry: nothing to add yet* until the
    next turn starts. A reply of his that lands after that sends nothing more of its own for the same board, and the
    session log says the turn ended this way. A mark that only says he has the picture, or has picked it up, keeps the
    turn out.
  - *Send to Larry* always goes at once, on any board, and takes over whatever was waiting: its words go with it, and
    the turn it starts is the one he is looking at. With no network it waits in the outbox and goes when it can (*One
    Send*, story 1176).
  - A picture that can't reach him frees the turn, and its words wait for the next one. *Ask at my pauses* off forgets
    what the pauses kept; a turn already out stays out.
  - While the board's *Send* waits in the outbox, a pause, his answer to an earlier picture and the three-minute wait
    send nothing, so it can't start a second thread or go twice (story 1176). What a pause hears meanwhile is kept, as
    for any turn out, even while that Send is the one that will start the board's thread: the words go with the next
    picture once he has answered it, or with the next Send if it can't go (story 1202).
- The first stroke with the switch off puts *Ask at my pauses is off, so no one is watching: turn it on for a look*
  in the bar's note. It stays there, past the note's usual few seconds, until the switch comes back on. The session
  log notes that first unwatched stroke. (Bead context-grabber-bozm: a tap meant for the mic landed on Ghosts beside
  it, and Igor wrote for 16 minutes to a board nobody was watching, with nothing on screen saying so.)
- **Every ghost turn is measured** (story 661). The session log says, for each one, how long the pause waited, how long
  the picture took to draw and to encode, and how long it took to upload, beside who answered. The Cockpit is told the
  first three with the turn itself, so its own log puts the iPad's half beside the model's; the upload is known only
  once the request has gone, so it is in the session log alone.

### One Send (story 1176; Igor, design board, 2026-11-22: "one Send button that waits when offline")

*Larry's turn* and *Send to Larry* did nearly the same thing, two buttons side by side: with no network a Send waited
in the outbox and a turn failed with nothing queued. They are one button now.

- **One button, *Send to Larry*,** at the end of the bar's right group (Talk, *Ask at my pauses*, Send). There is no *Larry's turn*
  button. A long press names it *Send* with one row, *Send the board to Larry*.
- **On a board drawn here it is Larry's turn.** The picture of the pages on screen goes to the board's thread with its
  strokes, as a turn's did, saying *your turn on the board* (the conversation panel shows no row for it, as for a turn)
  or carrying the words that waited. The bar's note begins with Larry's clock, his marks arrive with no further tap,
  and *Interrupt* is offered on it once he has it, as for a turn.
- **It always goes through the outbox.** With the network there it leaves at once; with none, or with the Cockpit not
  answering, it waits there and goes when it can, by itself, once. Nothing fails and nothing is lost.
- **While it waits, the board says so.** The note's state reads *Waiting to send · 0:12* in place of Larry's clock
  (VoiceOver: *Waiting to send for 12 seconds*), with what is waiting to go next after it as usual. The three-minute
  wait does not run, *Larry hasn't got the picture* is never said of it, and nothing else goes: a pause, his answer to an
  earlier picture and the button itself send nothing more until it has gone. The button is dimmed while it waits.
- **When it goes, his clock starts.** The note reads *Larry · 0:00* (or *Sent* until he picks it up, story 773) from the
  moment it left the outbox, and the three minutes count from there.
- **Closing the board while it waits loses nothing.** It goes from the outbox as any message does; a board opened again
  while it still waits says *Waiting to send* again, and starts Larry's clock when it goes. Once it has gone, the board
  knows what that picture showed, as it would had it never closed: with nothing drawn since the Send and the same pages
  on screen, Send stays dimmed and no second copy goes, while ink drawn after the Send (before the board closed, or
  since it opened) or other pages on screen light it for a fresh picture.
- **A Send the Cockpit refuses, or one deleted from the Inbox while it waits,** frees the turn and its words wait for the
  next picture. A refusal shows as a copyable problem naming the board and the reason.
  A Send refused or deleted while its board is closed does not yet keep its words for the next picture (bead
  context-grabber-tetc).
- **Once Larry has this picture, Send is dimmed until the next stroke** (Igor, 2026-11-22, bead context-grabber-x3tm;
  until then a tap with no turn out always sent). While he looks and after he answers, with nothing drawn or said
  since and the same pages on screen, the button is dimmed; new ink, words waiting or other pages on screen light it.
  A picture that didn't reach him, or *Interrupt*, lights it too (story 805).
- **Confirmed by Igor, 2026-11-22:** the message is the turn's note (*your turn on the board*) or the words that waited;
  a waiting Send just waits, dimmed; once he has it the note offers *Interrupt* only, with no Retry beside it.
- **A board only looked at** (the iPhone's, another device's) keeps its own *Send to Larry*: it takes no turn and doesn't
  look, the bar says *Sent to Larry: his reply shows in Chat*, and the button is dimmed until other pages are on screen.
- Retry and Dismiss (stories 775, 776) stay for the pictures the board hands him itself after a pause on a Larry board;
  a Send is the outbox's to retry, as it always was.

### Larry's turn (stories 349, 353, 355–357, 380–389)

Larry draws through his chat thread, in his own time: the real Larry answers in minutes, so nothing waits for him
(Igor, 2026-11-02).

- **Larry's turn** is *Send to Larry* on a board drawn here (*One Send* above): a picture of the board goes to the board's chat thread, saying *your turn on the
  board*, and the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) as soon as the picture is taken, until he answers (story 662). No spinner: Igor keeps drawing, and can
  hand him a newer picture once that one has gone. If it can't be delivered yet, it waits in the outbox (*One Send*).
- **Each board has one thread**, named after the board. The board's first *Send to Larry*, or the first picture a pause hands
  him, starts it, and later ones go to it, on every device (a Send from the iPhone goes to the thread the board carries through iCloud: [the conversation design](2026-11-12-whiteboard-conversation-design.md), story 1158), even when the first *Send* lands with the board closed. The
  two don't race to start it: a pause sends nothing while the board's *Send* waits in the outbox, and *Send* is off
  while a picture a pause handed him is on its way. If the Cockpit says it no longer has the thread, the next picture starts a new one.
  Claude's ghost turns have no thread.
- **Larry's marks arrive on their own.** While a board that has a thread is open, the app looks at the thread about
  every 3 s. A new row of Larry's with marks shows them as ghosts in Larry's colour (purple), kept or dismissed like Claude's.
  It makes no difference whether he is answering a turn, answering *Send to Larry*, or drawing unprompted.
- **Marks land where the picture was.** Every picture goes with its place on the board, and his row brings it back, so
  his marks sit on what he saw even after Igor has drawn elsewhere, panned or zoomed. A row of marks that doesn't say
  where its picture was is not shown (the session log says so).
- **His words show in the bar**: the text of each new row of his, as his line; his clock goes (story 667).
  A row of marks with no words clears it. The talk carries on in Chat.
- **What shows when a board opens:** his newest row of marks, and its line, and every earlier row of his that was still
  showing on this device when the board closed; each without the marks Igor already kept or dismissed from it on this
  device. A row whose every mark he kept or dismissed shows nothing. Rows this device never showed don't come back:
  they are in Chat. The device remembers up to 20 rows with marks still showing per board. It can reopen those marks
  even if the Cockpit loses their thread and the board starts a new one. A reply with no visible marks takes no place in
  that limit. Once the board is open, every new drawable row shows.
- **A new reply adds his marks, never clears them** (Igor, 2026-11-22, bead `context-grabber-n8ab`: a 12-mark
  sequence diagram of Larry's vanished when his next reply, a label and then a question card, came in). Each new row's
  marks join the unkept ones from his earlier replies; those stay until Igor keeps or dismisses them (Keep, Keep
  all, Dismiss). Several rows that land between two looks all show. The count of marks to keep is all of
  them, and Keep all keeps all of them. When he draws the same thing again, the copies show together: Igor clears the
  one he doesn't want with Dismiss, and Larry has no need to send a diagram again to keep it on the
  board. Claude's ghosts never replace his, nor his Claude's. His
  marks stay until kept or dismissed: no timer, and the *Ask at my pauses* switch doesn't touch them.
- **A kept or dismissed mark doesn't come back**, on the next look or the next time the board opens. Only that mark:
  the ones of his row Igor left alone show again when the board opens, until each is kept or dismissed (#883).
  Once his newest drawable row is settled, dealing with older rows still showing leaves it settled.
- When a reply's marks show, the session log records how many earlier marks stayed and how many replies they came from.
- The looking stops when the board closes or the app goes to the background, and starts again when it comes back.
  While it can't reach the Cockpit the bar says so quietly after 10 to 15 s (*Larry's marks: the Cockpit isn't
  answering*; while a turn of his is out, his clock says it instead, *Cockpit not answering*, story 760), the log
  says so once, and the bar clears itself when the Cockpit answers. Never an error box, never a repeating one.
- When a picture a pause hands him can't be delivered, or the Cockpit refuses it, the bar shows a copyable problem
  with what was asked; a *Send* waits in the outbox instead (*One Send*). A look-only board takes no turn and doesn't look: its *Send to Larry* still sends, and his reply shows only in
  Chat.

### The strokes go with the picture (stories 419, 424; Igor, 2026-11-03: "Can we send strokes instead?")

A picture of a tall board shrinks the handwriting to a few pixels; the strokes do not.

- **Every picture for Larry is preceded by the board's strokes.** *Send to Larry* and the pictures a pause hands him first hand
  the Cockpit every stroke on the board, in board points, each with when it was drawn, its colour as it looks in
  light mode, its width, its tool and a stable id, under the picture's own id. The picture then goes as before: it is
  what Chat shows, and what Larry reads when the strokes did not get through.
- **A picture and its message are one id** (bead context-grabber-bozm). A *Send to Larry* gives its chat message the
  picture's own id, so whatever names the message (Larry's reply, the Cockpit's debug page)
  finds the strokes stored under it, and his marks on it land where the picture was.
- **Larry reads any part sharp and knows what is new.** The Cockpit keeps the strokes per picture, renders any region
  at any size for him, and tells him which strokes were added or erased since the picture before his last reply.
  His marks come back as before, placed by the frame of whatever he drew on, so a page he rendered himself lands as
  exactly as the app's own picture.
- **A mark of his that Igor kept comes back to him as ink in his colour**, so he can tell a kept mark from a
  dismissed one; a mark that was never kept is in no picture and no stroke, by design.
- **Nothing waits on the strokes** (stories 421, 426). If the Cockpit answers the strokes with an error, the picture
  still goes, the session log says what became of the strokes, and the bar says nothing about them. A queued strokes
  file in the wrapped form must contain both a strokes list and a folds list. If either list is missing or unreadable,
  the picture still goes, the strokes are skipped, and only the session log reports the unreadable file.
- **With no network** a *Send* waits in the outbox with its strokes beside its picture, and both go when the network
  is back (story 427), the folded sections with them. Since *Larry's turn* became *Send* (story 1176) nothing fails
  for want of a network; only a picture a pause hands him on a Larry board still says Larry couldn't be reached (story
  428).
- **A dropped connection is tried once more before anything is said** (#1136, stories 908, 909). When the iPad loses the
  connection under the picture on its way to Larry (most often because the app left the screen for a moment while it
  was going), the board sends it again by itself once the app is back on screen, and Igor sees nothing. Only a second
  failure, or any other network error, says Larry couldn't be reached. The second try is the same message, so Larry
  gets the picture once; a turn Igor has retried, dismissed or interrupted in the meantime is not sent again.
- The strokes are the whole board each time, never a difference: a stroke missing from a send was erased.
- **Rubbed-out ink doesn't go** (story 423). What the pixel eraser removed is missing from the strokes as it is from
  the picture; what is left of a stroke it cut goes as new strokes, one per stretch still visible.

### Not yet

- Larry drawing during a call (story 346).

## Talking while drawing (Igor, 2026-11-02: "an interactive session so I can tell him to do stuff and he can add stuff"; stories 345, 360–368, #604, #605)

- A **microphone** in the board's bar stays open while he draws, until he taps it again or leaves the board.
- **The mic listens continuously; only a long silence sends** (Igor, 2026-11-24, his whiteboard picks: "continuous
  listening with the words showing live, replacing the 1.5 s pause-to-send"; then, the same day: "Keep a silence
  send, only after 5 s or more"; stories 1281, 1305). It stays open while he talks, thinks and draws. A pause in his
  speech under **5 s** sends nothing; **5 s or more** of silence after words he hasn't sent yet sends them with the
  board as it is then, and the mic stays open. This replaces the end-of-phrase wait (1.5 s after a sentence, 3 s
  after a plain phrase, 5 s after a hanging word; story 1118, bead `context-grabber-u1yy`), which still cut him off
  when he stopped to think: the silence is now 5 s whatever the words end with.
  - **The words show live** in the note's line as he speaks, newest kept in view.
  - **His words go with the next picture**, whatever sends it: the Pencil's pause (*When he has stopped writing*),
    *Send to Larry*, closing the mic, or 5 s of silence after them. Each takes every word heard so far; words still
    coming go with the one after. Nothing is dropped and nothing goes twice.
  - **The silence counts from the last change in what the mic heard.** The recognizer handing over the same words
    again doesn't restart it; a new or revised word does. Silence after words already sent sends nothing, so a quiet
    board stays quiet.
  - **Words waiting count as new**: while words wait, *Send to Larry* is not dimmed as *Larry already has this*, and
    a tap sends the board with them even when the drawing hasn't changed.
  - **Talking with no drawing** sends after 5 s of silence, or sooner when he taps *Send to Larry* or closes the
    mic.
  - **Switching microphones keeps listening**: the words heard so far wait for the next picture instead of going at
    once. Closing the mic or leaving the board sends what was heard at once, as before.
  - While Larry holds for more (*Larry: waiting*, the ear), nothing changes: his words still wait for the next pause,
    tap, close or 5 s of silence, and that picture ends the hold as any turn does.
  - The session log says what sent the words (the silence among them) and how many characters went
    ([debugging](../../debugging/whiteboard.md)).
  "draw a box around this" brings faint orange ghosts once the next picture goes, kept or dismissed like any others.
  They are still suggestions: nothing becomes ink without a Keep.
- It works on an empty board: "draw a circle" shows ghosts in the part of the board on screen.
- If he speaks while Claude is answering, those words go with the next turn. Words whose turn didn't get through
  (skipped, refused or the Cockpit away) go with the next one.
- With *Ask at my pauses* off nothing is asked, and the mic never takes words it would drop (#824): it doesn't open,
  and the bar says *Ask at my pauses is off, so the mic would reach no one: turn it on to talk*. Turning the switch off
  with the mic open closes it with the same line. Words aren't kept for later. Turning it on clears the line.
- Words that only revise what was already sent don't start a turn.
- The bar shows the last words heard. See *Who answers the pause* above for how spoken words reach the board's responder.
- When the mic can't start, the bar shows a copyable problem, including during a call with Larry, which has the
  microphone. The board's mic stops when a call starts, and when a shake report opens, so words meant for the report
  don't go to the Cockpit; he taps it again to go on. A stopped mic takes a moment to finish its last words, and
  its button waits for that.
- Words are heard by Apple's dictation, on the device when it can, and the words go to the Cockpit with the picture.

### Which microphone, and what it hears (#1139, story 1103; Igor, 2026-11-22: "I need to have a mic selector and see the audio of it coming in because I want to be able to use my pocket mic")

- **While the mic is open, the end of the note's line names the microphone it is hearing** (*Built-In Microphone*,
  a pocket mic's receiver, AirPods) **and a small level bar that moves with the sound coming in.** A bar that stays
  flat while he talks says his words aren't reaching that microphone. With *Automatic* picked, the name is the
  microphone the system chose. Closed, both are gone.
- **Tapping the name lists *Automatic* and every microphone connected now**, the picked one ticked. Picking another
  while the mic is open closes it, its words so far still going as at any close, and opens it again on the new
  microphone; the name and the bar follow.
- **The list is read each time the mic opens**, so a pocket mic plugged in or paired since the last time shows up.
  One connected while the mic is already open shows up at the next opening.
- **A long press on Talk picks the microphone too, open or closed** (Igor, 2026-11-22: "Hold mic should let me do mic
  selection as well!"; story 926). Under the menu's *Talk* row, a *Microphone* section lists *Automatic* and the
  microphones the board knows (read at the last opening, or by *Find microphones*), the picked one ticked; a pick
  kept from before a relaunch and not read since shows ticked by its name. Picking one with the mic closed keeps it
  for the next opening, on any board, and opens nothing; with the mic open it does what a pick from the note's line
  does. With the mic closed, a last row, *Find microphones*, reads the ones connected now (asking for the microphone
  the first time, as the first opening does), and the next long press lists them. A plain tap on Talk still opens
  and closes the mic; a tap in the moment the list is being read does nothing, and the session log says why.
- **The pick is kept** for the next opening, on any board, and after a relaunch. It is the same pick as Chat's and the
  problem report's microphone. A picked microphone that is no longer connected falls back to *Automatic* when the
  list is next read.
- **Nothing moves for it**: the name and the bar sit in the note's line, which keeps its height.
- **The session log says** how many microphones each opening and each *Find microphones* listed and which one the mic
  hears, and each pick: whether it was *Automatic* and whether the mic was open.
- **Not here: replaying a board with its sound**, as Notability plays a recording back with the ink (#1139's second
  ask, `context-grabber-3tdv`). The board's mic is dictation; it hears the words, not the sound. Playback is proposed
  in [Whiteboard with Claude](2026-11-01-whiteboard-design.md), *Playing a board back, as Notability does*.

## Where it runs

On the Cockpit (Igor's pick: no model key on the device, and Larry is there). Claude's ghosts come from its ghost
endpoint, which takes the board's picture and answers with strokes: lines, arrows, polylines, circles, arcs, boxes
and labels. Larry's marks come over chat ([cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85)): a picture
sent to him carries which board it is, a new id, and its place on the board, and the Cockpit keeps those on the row and
hands them back; his rows carry shapes in the picture's pixels, in the ghost endpoint's format or the older one.

## Acceptance

- Have Larry answer with a label in print and one in hand, at small and large sizes: each reads as plain written
  letters, one stroke wide, open at the thinnest pen; kept, the ink is the same letters. A label with a curly quote
  or a dash shows it; one with an accented letter still shows that letter.
- Turn on *Real font* in the Board menu: the switch is on, the menu closes, nothing on the board changes
  and the next stroke draws. Paste, and have Larry add a text: both are Helvetica's outlines as thin ink. Keep Larry's
  text, move it, fold its section, reword it: it stays one text in the real font. Erase one letter: what is left is
  plain ink. Leave and reopen the board: *Real font* is still on. A new board, and every older board, letter in
  single strokes.
- On a single-stroke board, a text of Larry's that asks for the real font is in the real font, and the board's next
  paste is still single strokes; on a real-font board, one that asks for single strokes is single strokes.
- Draw a circle and lift the Pencil: the turn goes once he has stopped writing, 1.5 to 5 s later by his rhythm (the session log's pause and its cue); the Pencil going down first cancels a turn not yet landed.
- Open the Board menu: the Responder row names the board's own; open it and it shows Haiku, Sonnet and Larry with that one ticked. Pick Haiku, close and reopen
  the board, and on another device: Haiku is ticked on both, and the next ghost turn's log says Haiku answered.
- Pick Larry and draw: no orange ghosts come; the bar's note begins with Larry's clock (*Larry · 0:00*, story 667), the picture is in the board's chat
  thread, and his purple marks arrive when he answers.
- On a Larry board, draw and pause five times while he is looking: his thread gets no new picture until he answers,
  then exactly one, of the board as it is then. Pause again with nothing drawn since his answer: nothing more goes.
  Speak while he is looking: the words arrive with that next picture. Tap *Send to Larry* while he is looking, after a stroke: a picture
  goes at once (with nothing drawn or said since the last one, nothing goes: [story 765](2026-11-12-whiteboard-conversation-design.md)). Leave him unanswering for 3 minutes: the bar stops saying he is looking.
- With the Cockpit unreachable, pick another responder: the tick goes back and a copyable problem says why.
- With a pocket mic connected, open the board's mic: the note's line names a microphone and its bar moves as Igor
  talks. Tap the name and pick the pocket mic: the mic closes and opens again, the line names the pocket mic, and the
  bar moves with it, not with the iPad's own. Close the mic and open it again: the pocket mic again, and the session
  log names it.
- Every ghost turn's log line has the pause, render, encode and upload times in milliseconds, and the Cockpit's own log
  of that turn has the first three.
- Write a column of notes down a tall board and tap Send to Larry: the Cockpit's render of the board (any page of it)
  shows the handwriting as sharp as the iPad does, and its reply names the lines added since his last turn.
- Cut the Cockpit's strokes route (a 404 or no network): the picture still arrives, and the session log says the
  strokes did not.
- Draw two circles on the iPad and lift the Pencil: within about 5 s faint orange shapes appear, solid like ink. Tap
  one: Keep and Dismiss appear beside it and nothing else changes. Keep: it becomes orange ink, the same line only
  stronger, that the eraser removes and undo takes back. Dismiss on another: it goes, and the rest stay.
- Tap Send to Larry, then write two lines below the last of the board's ink while he looks. When his reply lands where
  those lines are, Keep all: his marks stay where they showed, the two lines and everything under them move down in
  whole lines until they sit under his lowest mark, the ink above doesn't move, and one Undo puts the lines back and
  takes his marks away. A reply that lands only on ink that was in his picture keeps with nothing moved.
- Tap a mark at the very edge of the view: both buttons are wholly on screen. Tap off the marks, or start drawing:
  the buttons go and every mark is still there.
- With the Cockpit streaming, marks appear one at a time, and the session log says how long the first one took. With a
  Cockpit answering all at once, they appear together and everything else above holds.
- Cut the connection after the first mark: it stays and the bar says nothing. Cut it before any: the bar says ghosts
  aren't answering.
- Draw again before the ghosts come, or while they show: they stay, and the next pause brings a new set that replaces
  Claude's. Leave them alone: they fade after 30 s. Larry's purple marks stay through all of it.
- On a device where a finger draws: a tap on a ghost offers Keep and Dismiss with no dot drawn, a tap off the ghosts
  dismisses nothing, and once none is left the finger draws again.
- With no Pencil used: marks showing, a finger drag pans; tap empty paper, and the next finger drag draws ink while the
  marks still show; a tap on a mark still brings its Keep and Dismiss and leaves no dot.
- With the Pencil used once: a finger drag never draws, with marks or without, and a tap off the marks doesn't change that.
- Turn *Ask at my pauses* off, on a Larry board and on a Haiku board: lifting the Pencil asks nothing (the session log
  shows no turn, and nothing reaches the Cockpit). Larry's purple ghosts stay showing.
- Tap Send to Larry: the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) straight away and the Pencil keeps drawing. Chat has a thread
  named after the board holding the picture. Minutes later, with no tap, purple ghosts and his line appear on what he saw,
  even if the view has moved since.
- He draws unprompted on the thread: the same, with no tap by Igor. His next marks join the unkept ones, which stay.
- He answers twice, the second a label or a question card: the first reply's marks are still there beside the label,
  and the count of marks to keep is both replies'.
- Dismiss one of his marks: it doesn't return, not on the next look and not after closing and reopening the board. Leave them
  and reopen: his newest set shows, and any earlier set of his still showing when the board closed.
- Cockpit unreachable: drawing works as before and the bar says ghosts aren't answering, and that his marks aren't;
  *Send to Larry* waits in the outbox; when the Cockpit is back the bar clears by itself and the Send goes once.
- One Send (story 1176): the bar's right group is Talk, *Ask at my pauses* and Send, with no *Larry's turn*. With no network, tap
  Send to Larry: the note reads *Waiting to send · 0:00* and counts, the button is dimmed, and a pause or a second tap
  sends nothing. The network back: the picture goes once, the note reads *Larry · 0:00*, and his marks arrive with no
  further tap. Close the board while it waits and open it again: it still says *Waiting to send*; when it goes, Send stays dimmed
  unless something was drawn after the Send. Once he answers, Send stays dimmed until the next stroke. Delete it from the
  Inbox: the turn is free and the button lights.
