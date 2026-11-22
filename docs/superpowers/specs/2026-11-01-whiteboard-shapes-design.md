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
  - **Keep group keeps a whole reply as one thing** (#942; Igor, 2026-11-17, via Larry: "accept the group", after
    keeping his four named boxes one mark at a time). When the chosen mark is one of Larry's and more of the marks from
    the same reply of his still show, a third button, **Keep group** with how many (*Keep group · 11*), sits between
    Keep and Dismiss. One tap keeps every mark of that reply still showing, where each showed, as ink in his colours:
    nothing of Igor's moves, as with one Keep, unless the reply would land on what he wrote after Larry looked (below).
    **One undo takes them all back.**
  - What it keeps is **one group**, as Larry's own groups are: a push or a paste's room never splits it, the Pencil
    held on any of it picks up all of it, and Larry hears it as one group (its strokes carry the same group note, named
    for his reply) that he can move or erase by that one name. Tidy overlaps leaves it as it is. A mark of the reply
    Igor already kept or dismissed is not in it; Claude's marks, and Larry's text from a change of his, never are.
  - **A finger tap on any stroke of a group selects the whole group, ready to drag** (#947; Igor, 2026-11-18: "when I
    click select-all, I want some notion of fixed object on finger-click to move"). A group is a reply kept with
    *Keep group*, or one of Larry's own groups. The tap must land on one of the group's strokes, within a finger's
    reach of its line (a fingertip, about 22 screen points, whatever the zoom), not merely inside the group's box. All
    of the group is then selected, as a lasso round it would select it, and a finger drags it as one; one Undo puts it
    back where it was. The Pencil keeps drawing over it as before, and drawing fingers leave no dot for the tap.
    - Only on a board he can draw on, with no marks of Claude's or Larry's showing and none of Larry's controls (with
      them showing a tap chooses a mark, as above), and never in the margin (the outline's).
    - A tap off every group, on his own writing or blank paper, does what it did.
    - **A kept text inside a group** (decided 2026-11-22, Igor away, reversible): the first tap selects the group; a
      second tap on the text while its group is selected opens its words for rewording, as a tap on a text outside
      any group does at once.
    - The session log says, for each such tap, the group's name, how many strokes it selected, how a finger touches
      the paper then, whether fingers draw, and whether the group was still selected a beat later.
  - **A finger tap on anything of Larry's he kept, outside a group, picks up that one thing alone** (#1171; Igor,
    2026-11-22, on the iPad, with Larry's steps written inside a box of his: "I want to be able to click what Larry
    wrote. I want to be able to keep that separate somehow and just pick that up and move it around by itself"). A
    text of Larry's (kept with Keep or Keep all, or written by a change of his), a mark of his or Claude's kept with
    Keep or Keep all, and a stroke Larry drew on the board: the tap on it, within a fingertip of its line as for a
    group, selects all of that one thing and nothing else, not his own ink under or beside it, nor Larry's other
    marks; a finger drags it alone, and one Undo puts it back. A lasso still takes whatever it rings, his ink
    included, and can split a text of Larry's.
    - Under the same conditions as a group's tap (a board he can draw on, no marks or Larry's controls showing,
      never in the margin); a thing of Larry's in a group is the group's, as above.
    - **A text of Larry's**: the first tap selects it (its label reads *Text · tap to reword*); a second tap on it
      while it is selected opens its words for rewording. A text of Igor's own (one he typed, or a To text result)
      still opens at the first tap.
    - Where his own ink is nearer the tap than Larry's, the tap is his ink's and does what it did.
    - **One reply of Larry's, kept piece by piece, is picked up whole** (bead context-grabber-hm7n; Igor, 2026-11-22,
      on the iPad: "Should move as group when clicked"). Every mark of one reply of Larry's that he kept with plain
      Keep, one at a time, is one thing to a finger: a tap on any of them selects all the pieces of that reply still
      on the board, and nothing else (not his own ink, not Larry's marks from another reply, not a mark of Claude's).
      The label beside it reads as for what it holds: two texts read *2 things · move together*, marks alone *Ink ·
      To text*. A drag moves them together, and one Undo puts them back. A text in such a reply opens its words at a
      second tap while the reply is selected, as a text alone does.
      - A reply kept with Keep group was already one group and stays so.
      - Marks kept with Keep all stay one thing each, as above (decided 2026-11-22, Igor away, reversible: Keep all
        always keeps one whole reply, and story 1140 picks one of those up alone). A mark of the same reply kept with
        plain Keep before Keep all joins only the other plainly kept ones.
      - A reply he kept before this change is still picked up one piece at a time: the board never learned which
        reply those came from.
      - A group Larry makes himself with a change (a group note on strokes) is a group, as above, and a tap on any of
        its strokes takes the whole group.
      - The session log names such a tap for the reply, apart from a tap on one thing alone.
    - Not yet (non-goal): a mark still showing, not kept, is never dragged; it is kept first, then picked up.
    - The session log says, for each such tap, that it was one thing of Larry's rather than a group, how many strokes
      it selected, and whether it was still selected a beat later.
  - The buttons stay together, beside the mark and wholly on screen as before, and never under the board's top-right
    corner (? and Feedback, and *Larry's edit blocked* when it shows): placed there, they move below that corner. Each
    of the three takes at least 36 points each way, and a tap on any of them, or between them, never reaches the paper.
  - The note line's *Keep all* stays as it was (story 895): every mark of his, each laid clear of Igor's writing, not
    grouped.
  - The session log says how many marks a group keep took, its strokes and its group's name.
  - **Keep** does what a tap used to: the mark becomes real ink in Claude's colour (or the one it asked for, below),
    and his eraser and undo treat it like his own strokes. One undo takes it back.
  - **A reply of Larry's makes room for what Igor wrote after Larry looked** (#894, stories 1004–1006, 1037; Igor, 2026-11-14: push what he
    wrote since the picture down the page to make room for Larry's reply, rather than put the reply below his ink;
    2026-11-19, on a board where a kept group of Larry's landed on his writing: "group pushes purple text out of the
    way"). Larry places a reply on the picture he was sent, often minutes old, and Igor keeps writing meanwhile. This
    is the *A late reply* rule of the object-layer design (PR #912), which needs nothing from that design's objects.
    - When **Keep** or **Keep group** would put marks of Larry's on ink drawn or pasted *after* the picture that reply
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
    - It is Larry's drawn marks (Keep and Keep group). His text already makes room as it lands ([Larry edits the
      board](2026-11-16-whiteboard-board-ops-design.md), *His text makes room*); *Keep all* lays his labels clear of
      the writing (story 895); Claude's marks, which answer in seconds, are unchanged.
    - Not yet (#912's *Reflow rules*): his other unkept marks don't slide with the ink, and blank paper further down
      doesn't take up the push: the push moves everything below the line, as a paste's room does, marks of Larry's
      kept earlier from the same reply included (Keep group keeps a reply whole, so this only bites when Igor keeps a
      reply mark by mark).
    - The session log's keep line says whether it made room, where and how far, how many things it landed on that Igor
      wrote after the picture, and when that picture was taken, or that its time isn't known.
  - **Dismiss** removes that mark and only that mark. It isn't kept, and it doesn't come back, on the next look or the
    next time the board opens. The other marks stay, and the rest of an answer still on its way still lands.
  - **A tap anywhere else puts the buttons away and changes nothing**: no mark is kept or dismissed by a stray tap.
    Starting to draw puts them away too, and the Pencil keeps drawing while they show. If their mark goes (Claude's
    fade, a new set replaces it, Ghosts off) they go with it.
- **Ghosts stay while he draws** (Igor, 2026-11-02: drawing together, not taking turns). The Pencil touching down
  leaves them, and an answer that lands while he draws still shows. Each new answer from Claude replaces his unkept
  ghosts and leaves Larry's: the old set stays until the first new mark lands, so the board is never blank between
  them, and an answer with nothing to add clears them when it ends. Claude's fade by themselves **30 s** after the last
  of them appears; Larry's stay until kept or dismissed.
- **A tap off the marks dismisses nothing** (#823, then #883): one stray tap must never lose a mark, least of all
  Larry's, which don't come back. Clearing a mark takes its own Dismiss.
- **A tap on his own selection is still his, marks showing or not** (#1170; Igor, 2026-11-22: "Click, select, then
  delete did nothing"). With ink selected, a finger tap inside the selection that reaches no mark keeps the selection
  and brings up its menu (Cut, Copy, Delete and the rest), exactly as it does with no marks on the board. Only a tap
  that reaches a mark chooses that mark (and lets the selection go), and a tap off both the marks and the selection
  lets the selection go and puts Keep and Dismiss away, as before. The session log's tap line says whether the tap was
  inside the selection and whether the selection was kept.
- **Where a finger draws** (an iPhone, an iPad with no Pencil, or with the system's Pencil-only setting off), it stops
  drawing while ghosts show: it taps and pans, so a tap on a mark leaves no dot. With no ghost left (kept, dismissed or faded) it draws again.
- A ghost turn gives up **10 s** after it was asked, however much has arrived by then (the Cockpit's model takes about
  3 s, and an answer to an older drawing still lands where that drawing was). If no mark has arrived, none is shown and
  the bar says *Ghosts: the Cockpit isn't answering*. **An answer cut off after a mark has arrived is no failure**: the
  marks already drawn stay, and the bar says nothing. A turn sent away (Ghosts off) stops showing marks at
  once, even with more on the way. A turn the Cockpit says came too soon (it
  takes one every 2 s) is quietly skipped: the bar says nothing and the ghosts on the board stay.
- **Ghosts** is a switch in the board's bar, on by default and remembered. Off, nothing is asked after a pause: Claude's
  ghosts go and a turn of his on its way is dropped. Larry's marks stay, because a tap asked for them.
- Ghosts need the Cockpit. When it can't be reached the board draws as before; the bar says *Ghosts: the Cockpit
  isn't answering* until a turn gets through.
- Only on the device that draws the board. A board that is look-only gets no ghosts.
- A point in an answer that lies past anywhere the board could reach is ignored, and a shape left with too few points
  isn't shown: a model's bad number never breaks the board. A label with nothing to draw (an emoji has no outline)
  isn't shown or counted either.

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

### Keep all and Tidy overlaps (stories 895, 896, 897; Igor, 2026-11-16: "match Larry's web board")

Larry often answers with several labels down the page. Kept one by one they land exactly where he drew them, and on a
board that moved on since his picture a label can land on Igor's writing. The Cockpit's web board (*/ink*) keeps them
in order and can tidy overlaps; the iPad does the same, except that **his own ink never moves**: where the web board
pushes the writing below down to make room, the iPad moves the label down to the first clear space instead.

- **Keep all**, in the note's line beside the count of marks to keep (as on the web board's ghost bar), keeps every mark
  of Larry's showing at once, as one keep: **one undo takes them all back**. It is there only while his marks show. They are kept top to bottom: a label (words) that would sit on ink
  moves down under that ink, half a line clear of it, and every mark after it moves down with it, so they stay in the
  order he drew them. A line, arrow, box or circle is meant to sit on what it points at, so it never moves for ink of its
  own; it moves only with a label above it that moved. Each mark kept is ink for the next. Nothing of his comes back on
  the next look or open, as for a mark kept on its own.
- **Board menu → Tidy overlaps** (one row: the menu has no room for more and still closes after a pick, #848) lays out again, top to bottom, every kept label (and pasted text) that sits on other
  ink, his or another label above it: each moves down under what it sits on, as above. Ink that only touches a label's
  edge isn't under it. His own strokes and kept shapes stay where they are. **One undo takes the tidy back.** With
  nothing to move the bar says *Nothing overlaps* until the board next changes, and tidying a tidy board changes nothing.
- Labels are known by how they were made: the strokes of one kept label or one paste are made in the same moment, and the
  board remembers those moments, on this device. A label kept on another device, or before this build, is ink like
  any other and is never moved.
- Folded ink (hidden under a folded header) is neither moved nor in the way: a kept label never moves for ink you can't
  see, and a folded label stays where it is until it is unfolded.
- A tidy or a keep that moves ink past the last page brings the pages it needs, as any keep does.
- The session log says what each did: how many marks were kept and how many moved, how many labels the tidy found and
  moved.

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
  thread just as *Larry's turn* sends it, and his purple marks come when he has drawn them. Words spoken to the board go
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
  - *Larry's turn* and *Send to Larry* always go at once, on any board, and take over whatever was waiting: its words
    go with them, and the turn they start is the one he is looking at.
  - A picture that can't reach him frees the turn, and its words wait for the next one. Ghosts off forgets what the
    pauses kept; a turn already out stays out.
  - A pause while the board's first *Send* waits in the outbox sends nothing, so it can't start a second thread.
- With Ghosts off nothing is asked after a pause, whoever the responder is.
- **Every ghost turn is measured** (story 661). The session log says, for each one, how long the pause waited, how long
  the picture took to draw and to encode, and how long it took to upload, beside who answered. The Cockpit is told the
  first three with the turn itself, so its own log puts the iPad's half beside the model's; the upload is known only
  once the request has gone, so it is in the session log alone.

### Larry's turn (stories 349, 353, 355–357, 380–389)

Larry draws through his chat thread, in his own time: the real Larry answers in minutes, so nothing waits for him
(Igor, 2026-11-02).

- **Larry's turn** in the board's bar sends a picture of the board to the board's chat thread, saying *your turn on the
  board*, and the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) as soon as the picture is taken, until he answers (story 662). No spinner: Igor keeps drawing, and can
  hand him a newer picture once that one has gone. If it can't be delivered, the line goes and the problem below shows.
- **Each board has one thread**, named after the board. The board's first *Larry's turn* or *Send to Larry* starts it,
  and later ones of either kind go to it, on this device, even when the first *Send* lands with the board closed. The
  two don't race to start it: *Larry's turn* is off while the board's first *Send* waits in the outbox, and *Send* is
  off while a turn is on its way. If the Cockpit says it no longer has the thread, the next picture starts a new one.
  Claude's ghost turns have no thread.
- **Larry's marks arrive on their own.** While a board that has a thread is open, the app looks at the thread about
  every 3 s. A new row of Larry's with marks shows them as ghosts in Larry's colour (purple), kept or dismissed like Claude's.
  It makes no difference whether he is answering a turn, answering *Send to Larry*, or drawing unprompted.
- **Marks land where the picture was.** Every picture goes with its place on the board, and his row brings it back, so
  his marks sit on what he saw even after Igor has drawn elsewhere, panned or zoomed. A row of marks that doesn't say
  where its picture was is not shown (the session log says so).
- **His words show in the bar**: the text of each new row of his, as his line; his clock goes (story 667).
  A row of marks with no words clears it. The talk carries on in Chat.
- **What shows when a board opens:** only his newest row of marks, and its line, without the marks Igor already kept or
  dismissed from it on this device; nothing, once he has kept or dismissed every mark in it. Older rows never come back:
  they are in Chat. After that, every new row shows.
- **Each new row of marks replaces his unkept ones** and leaves Claude's alone; Claude's ghosts never replace his. His
  marks stay until kept or dismissed: no timer, and the Ghosts switch doesn't touch them.
- **A kept or dismissed mark doesn't come back**, on the next look or the next time the board opens. Only that mark:
  the ones of his row Igor left alone show again when the board opens, until each is kept or dismissed (#883).
- The looking stops when the board closes or the app goes to the background, and starts again when it comes back.
  While it can't reach the Cockpit the bar says so quietly after 10 to 15 s (*Larry's marks: the Cockpit isn't
  answering*; while a turn of his is out, his clock says it instead, *Cockpit not answering*, story 760), the log
  says so once, and the bar clears itself when the Cockpit answers. Never an error box, never a repeating one.
- When the picture can't be handed to him, or the Cockpit refuses it, the bar shows a copyable problem with what was
  asked. A look-only board takes no turn and doesn't look: its *Send to Larry* still sends, and his reply shows only in
  Chat.

### The strokes go with the picture (stories 419, 424; Igor, 2026-11-03: "Can we send strokes instead?")

A picture of a tall board shrinks the handwriting to a few pixels; the strokes do not.

- **Every picture for Larry is preceded by the board's strokes.** *Larry's turn* and *Send to Larry* both first hand
  the Cockpit every stroke on the board, in board points, each with when it was drawn, its colour as it looks in
  light mode, its width, its tool and a stable id, under the picture's own id. The picture then goes as before: it is
  what Chat shows, and what Larry reads when the strokes did not get through.
- **Larry reads any part sharp and knows what is new.** The Cockpit keeps the strokes per picture, renders any region
  at any size for him, and tells him which strokes were added or erased since the picture before his last reply.
  His marks come back as before, placed by the frame of whatever he drew on, so a page he rendered himself lands as
  exactly as the app's own picture.
- **A mark of his that Igor kept comes back to him as ink in his colour**, so he can tell a kept mark from a
  dismissed one; a mark that was never kept is in no picture and no stroke, by design.
- **Nothing waits on the strokes** (stories 421, 426). If the Cockpit answers the strokes with an error, the picture
  still goes, the session log says what became of the strokes, and the bar says nothing about them.
- **With no network** a *Send* waits in the outbox with its strokes beside its picture, and both go when the network
  is back (story 427). *Larry's turn* doesn't wait: a copyable error says Larry couldn't be reached, and nothing is
  queued (story 428).
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
- About a second after he stops talking, what he said goes with a picture of the board, without waiting for a stroke:
  "draw a box around this" brings faint orange ghosts about 4 s later, kept or dismissed like any others. They are
  still suggestions: nothing becomes ink without a Keep.
- It works on an empty board: "draw a circle" shows ghosts in the part of the board on screen.
- If he speaks while Claude is answering, those words go with the next turn. Words whose turn didn't get through
  (skipped, refused or the Cockpit away) go with the next one.
- With Ghosts off nothing is asked, and the mic never takes words it would drop (#824): it doesn't open, and the bar
  says Ghosts are off so the mic would reach no one. Turning Ghosts off with the mic open closes it with the same line.
  Words aren't kept for later. Turning Ghosts on clears the line.
- Words that only revise what was already sent don't start a turn.
- The bar shows the last words heard. The answerer is Claude's fast model; Larry is too slow for back-and-forth, so
  he stays on his own button.
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
- **The pick is kept** for the next opening, on any board, and after a relaunch. It is the same pick as Chat's and the
  problem report's microphone. A picked microphone that is no longer connected falls back to *Automatic* when the
  list is next read.
- **Nothing moves for it**: the name and the bar sit in the note's line, which keeps its height.
- **The session log says** how many microphones each opening listed and which one the mic hears, and each pick:
  whether it was *Automatic* and whether the mic was open.
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
  Speak while he is looking: the words arrive with that next picture. Tap *Larry's turn* while he is looking, after a stroke: a picture
  goes at once (with nothing drawn or said since the last one, nothing goes: [story 765](2026-11-12-whiteboard-conversation-design.md)). Leave him unanswering for 3 minutes: the bar stops saying he is looking.
- With the Cockpit unreachable, pick another responder: the tick goes back and a copyable problem says why.
- With a pocket mic connected, open the board's mic: the note's line names a microphone and its bar moves as Igor
  talks. Tap the name and pick the pocket mic: the mic closes and opens again, the line names the pocket mic, and the
  bar moves with it, not with the iPad's own. Close the mic and open it again: the pocket mic again, and the session
  log names it.
- Every ghost turn's log line has the pause, render, encode and upload times in milliseconds, and the Cockpit's own log
  of that turn has the first three.
- Write a column of notes down a tall board and tap Larry's turn: the Cockpit's render of the board (any page of it)
  shows the handwriting as sharp as the iPad does, and its reply names the lines added since his last turn.
- Cut the Cockpit's strokes route (a 404 or no network): the picture still arrives, and the session log says the
  strokes did not.
- Draw two circles on the iPad and lift the Pencil: within about 5 s faint orange shapes appear, solid like ink. Tap
  one: Keep and Dismiss appear beside it and nothing else changes. Keep: it becomes orange ink, the same line only
  stronger, that the eraser removes and undo takes back. Dismiss on another: it goes, and the rest stay.
- Tap Larry's turn, then write two lines below the last of the board's ink while he looks. When his reply lands where
  those lines are, Keep group: his marks stay where they showed, the two lines and everything under them move down in
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
  changes nothing, and once none is left the finger draws again.
- Turn Ghosts off: lifting the Pencil asks nothing (the session log shows no turn). Larry's purple ghosts stay showing.
- Tap Larry's turn: the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) straight away and the Pencil keeps drawing. Chat has a thread
  named after the board holding the picture. Minutes later, with no tap, purple ghosts and his line appear on what he saw,
  even if the view has moved since.
- He draws unprompted on the thread: the same, with no tap by Igor. His next marks replace the unkept ones.
- Dismiss one of his marks: it doesn't return, not on the next look and not after closing and reopening the board. Leave them
  and reopen: only his newest set shows.
- Cockpit unreachable: drawing works as before and the bar says ghosts aren't answering, and that his marks aren't;
  Larry's turn shows a copyable problem; when the Cockpit is back the bar clears by itself.
