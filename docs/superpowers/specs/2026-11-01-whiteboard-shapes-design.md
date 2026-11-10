# Whiteboard: Claude and Larry draw back (ghosts and shapes)

Igor, 2026-11-01: "what about the ghosting idea, does that work? How does Larry write back? I don't grok that yet",
then "make an issue for cockpit, build your side". Builds on [the whiteboard](2026-11-01-whiteboard-design.md)
(stories 344, 345, 349–377 and 380–389). Larry's half on the Cockpit is [cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85).

## The idea in one line

Claude and Larry don't paint pixels. They answer with **shapes**: a short list of lines, arrows, boxes, circles,
freehand curves and labels, placed on the board. The app draws those shapes faint, as **ghosts**, in Claude's or
Larry's colour. A ghost looks like ink, only fainter: a solid line with round ends, as wide as a kept stroke (Igor,
2026-11-02: "via ink strokes"), and a label is the outlines of its letters. A tap keeps one as real ink. Nothing they
suggest changes the board until Igor keeps it.

## What Igor sees

### Ghosts from Claude (stories 344, 350–352, 354, 357–359, 370–377)

- He draws, then lifts the Pencil. After **half a second** with nothing new Claude is asked (1 s until 2026-11-10, story 660), and within a few seconds faint
  shapes draw themselves in, one after another, in Claude's colour (orange): the box his arrow points at, a label, the
  third circle. Only one turn is asked at a time; strokes made meanwhile get their own turn after the next
  pause, which waits for the tool to lift.
- **Claude's marks arrive one at a time** (cockpit#85), each as the model makes it, not all together at the end. Where
  a Cockpit answers all at once, they all arrive then and draw in one after another as before; the app asks in a way
  that gets either.
- While ghosts show, the bar says how many and *tap one to keep it*.
- **A tap on a ghost keeps it** (a finger tap; the Pencil draws). It becomes real ink in Claude's colour (or the one it asked for, below), and his eraser and undo treat it like his own
  strokes.
- **Ghosts stay while he draws** (Igor, 2026-11-02: drawing together, not taking turns). The Pencil touching down
  leaves them, and an answer that lands while he draws still shows. Each new answer from Claude replaces his unkept
  ghosts and leaves Larry's: the old set stays until the first new mark lands, so the board is never blank between
  them, and an answer with nothing to add clears them when it ends. Claude's fade by themselves **30 s** after the last
  of them appears; Larry's stay until kept or dismissed.
- **A tap off the ghosts dismisses them all.**
- **Where a finger draws** (an iPhone, an iPad with no Pencil, or with the system's Pencil-only setting off), it stops
  drawing while ghosts show: it taps and pans, so keeping a ghost leaves no dot. With no ghost left it draws again.
- A ghost turn gives up **10 s** after it was asked, however much has arrived by then (the Cockpit's model takes about
  3 s, and an answer to an older drawing still lands where that drawing was). If no mark has arrived, none is shown and
  the bar says *Ghosts: the Cockpit isn't answering*. **An answer cut off after a mark has arrived is no failure**: the
  marks already drawn stay, and the bar says nothing. A turn sent away (a dismissal, Ghosts off) stops showing marks at
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

### How a mark looks: pen, colour, lettering (#698)

Igor, 2026-11-05, picked from Larry's note: *choosing the pen width, the font and the color … it fixes the bold text at
the same time.* Any mark from Claude or Larry can say how it looks; one that says nothing looks as it does today, except
that labels are no longer bold.

- **Pen.** A mark can name its pen width, in the same units as its position on the board. A line, arrow, curve, circle,
  arc or box drawn without one keeps today's width.
- **Labels are no longer bold.** A label with no pen of its own is drawn at a pen about a ninth of its letter height,
  so its letters read as handwriting, not a marker. A label kept as ink is kept at that pen too. Ink kept before this
  change stays as it was saved.
- **Colour.** A mark can name its colour. One without a colour is in its author's: Claude's orange, Larry's blue.
  A ghost in a named colour is as faint as any other ghost, and a kept mark is ink in that colour.
- **Lettering.** A label can ask for *print* (the default) or *hand*, a handwriting face. The hand face is the app's
  own, not Igor's writing.
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

- **The Board menu has a Responder section: Haiku, Sonnet and Larry**, one of them ticked. It is the board's own
  setting, kept on the Cockpit, so every device drawing that board answers the same way. A board nobody has set
  answers with Sonnet.
- **Opening a board asks the Cockpit which one it has.** Until it answers, or when it can't be reached, Sonnet is
  ticked, and the board draws as before. A choice Igor makes before the answer comes wins over it.
- **Choosing one tells the Cockpit at once**, and the next pause is answered by it. If the Cockpit refuses or can't be
  reached, the tick goes back to what the Cockpit last said and a copyable problem says what happened.
- **Haiku and Sonnet** answer with orange ghosts, exactly as above: Haiku is the faster model, Sonnet the sharper one.
  Spoken words are answered by the board's responder too.
- **Larry**: a pause brings no orange ghosts. The Cockpit says the board is Larry's, and the board goes to its chat
  thread just as *Larry's turn* sends it, and his blue marks come when he has drawn them. Words spoken to the board go
  with that picture as its message.
- **One Larry turn at a time, the latest wins** (story 662; Igor, 2026-11-10: "can we avoid this, think about best
  design"). Real Larry takes a minute or more, so his thread never fills with pictures:
  - While a turn is out (a picture sent, no answer from him yet on the thread) the bar says *Larry is looking…*, and
    further pauses send nothing. They only note that the board moved on; words spoken meanwhile wait.
  - When he answers, or after **3 minutes** with no answer, **one** fresh picture of the board as it is then goes, with
    the words that waited, if the board moved on or words waited. Otherwise nothing goes and the bar stops saying he
    is looking.
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
  board*, and the bar says *Larry is looking…* as soon as the picture is taken, until he answers (story 662). No spinner: Igor keeps drawing, and can
  hand him a newer picture once that one has gone. If it can't be delivered, the line goes and the problem below shows.
- **Each board has one thread**, named after the board. The board's first *Larry's turn* or *Send to Larry* starts it,
  and later ones of either kind go to it, on this device, even when the first *Send* lands with the board closed. The
  two don't race to start it: *Larry's turn* is off while the board's first *Send* waits in the outbox, and *Send* is
  off while a turn is on its way. If the Cockpit says it no longer has the thread, the next picture starts a new one.
  Claude's ghost turns have no thread.
- **Larry's marks arrive on their own.** While a board that has a thread is open, the app looks at the thread about
  every 3 s. A new row of Larry's with marks shows them as ghosts in Larry's colour (blue), kept by a tap like Claude's.
  It makes no difference whether he is answering a turn, answering *Send to Larry*, or drawing unprompted.
- **Marks land where the picture was.** Every picture goes with its place on the board, and his row brings it back, so
  his marks sit on what he saw even after Igor has drawn elsewhere, panned or zoomed. A row of marks that doesn't say
  where its picture was is not shown (the session log says so).
- **His words show in the bar**: the text of each new row of his, as his line; *Larry is looking…* goes.
  A row of marks with no words clears it. The talk carries on in Chat.
- **What shows when a board opens:** only his newest row of marks, and its line, unless Igor already kept or dismissed
  something from that row on this device. Older rows never come back: they are in Chat. After that, every new row shows.
- **Each new row of marks replaces his unkept ones** and leaves Claude's alone; Claude's ghosts never replace his. His
  marks stay until kept or dismissed: no timer, and the Ghosts switch doesn't touch them.
- **A dismissed set doesn't come back**, on the next look or the next time the board opens. Keeping one mark settles
  that row the same way the next time the board opens: the ones he left show until the board closes.
- The looking stops when the board closes or the app goes to the background, and starts again when it comes back.
  While it can't reach the Cockpit the bar says so quietly after 10 to 15 s (*Larry's marks: the Cockpit isn't
  answering*), the log says so once, and the bar clears itself when the Cockpit answers. Never an error box, never a
  repeating one.
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
- The strokes are the whole board each time, never a difference: a stroke missing from a send was erased.
- **Rubbed-out ink doesn't go** (story 423). What the pixel eraser removed is missing from the strokes as it is from
  the picture; what is left of a stroke it cut goes as new strokes, one per stretch still visible.

### Not yet

- Larry drawing during a call (story 346).

## Talking while drawing (Igor, 2026-11-02: "an interactive session so I can tell him to do stuff and he can add stuff"; stories 345, 360–368, #604, #605)

- A **microphone** in the board's bar stays open while he draws, until he taps it again or leaves the board.
- About a second after he stops talking, what he said goes with a picture of the board, without waiting for a stroke:
  "draw a box around this" brings faint orange ghosts about 4 s later, kept or dismissed like any others. They are
  still suggestions: nothing becomes ink without a tap.
- It works on an empty board: "draw a circle" shows ghosts in the part of the board on screen.
- If he speaks while Claude is answering, those words go with the next turn. Words whose turn didn't get through
  (skipped, refused or the Cockpit away) go with the next one.
- With Ghosts off nothing is asked: the mic still hears him, the words go nowhere and aren't kept for later.
- Words that only revise what was already sent don't start a turn.
- The bar shows the last words heard. The answerer is Claude's fast model; Larry is too slow for back-and-forth, so
  he stays on his own button.
- When the mic can't start, the bar shows a copyable problem, including during a call with Larry, which has the
  microphone. The board's mic stops when a call starts, and when a shake report opens, so words meant for the report
  don't go to the Cockpit; he taps it again to go on. A stopped mic takes a moment to finish its last words, and
  its button waits for that.
- Words are heard by Apple's dictation, on the device when it can, and the words go to the Cockpit with the picture.

## Where it runs

On the Cockpit (Igor's pick: no model key on the device, and Larry is there). Claude's ghosts come from its ghost
endpoint, which takes the board's picture and answers with strokes: lines, arrows, polylines, circles, arcs, boxes
and labels. Larry's marks come over chat ([cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85)): a picture
sent to him carries which board it is, a new id, and its place on the board, and the Cockpit keeps those on the row and
hands them back; his rows carry shapes in the picture's pixels, in the ghost endpoint's format or the older one.

## Acceptance

- Draw a circle and lift the Pencil: the turn goes half a second later (the session log's pause), not a second.
- Open the Board menu: Responder shows Haiku, Sonnet and Larry with the board's own ticked. Pick Haiku, close and reopen
  the board, and on another device: Haiku is ticked on both, and the next ghost turn's log says Haiku answered.
- Pick Larry and draw: no orange ghosts come; the bar says *Larry is looking…*, the picture is in the board's chat
  thread, and his blue marks arrive when he answers.
- On a Larry board, draw and pause five times while he is looking: his thread gets no new picture until he answers,
  then exactly one, of the board as it is then. Pause again with nothing drawn since his answer: nothing more goes.
  Speak while he is looking: the words arrive with that next picture. Tap *Larry's turn* while he is looking: a picture
  goes at once. Leave him unanswering for 3 minutes: the bar stops saying he is looking.
- With the Cockpit unreachable, pick another responder: the tick goes back and a copyable problem says why.
- Every ghost turn's log line has the pause, render, encode and upload times in milliseconds, and the Cockpit's own log
  of that turn has the first three.
- Write a column of notes down a tall board and tap Larry's turn: the Cockpit's render of the board (any page of it)
  shows the handwriting as sharp as the iPad does, and its reply names the lines added since his last turn.
- Cut the Cockpit's strokes route (a 404 or no network): the picture still arrives, and the session log says the
  strokes did not.
- Draw two circles on the iPad and lift the Pencil: within about 5 s faint orange shapes appear, solid like ink. Tap
  one: it becomes orange ink, the same line only stronger, that the eraser removes and undo takes back.
- With the Cockpit streaming, marks appear one at a time, and the session log says how long the first one took. With a
  Cockpit answering all at once, they appear together and everything else above holds.
- Cut the connection after the first mark: it stays and the bar says nothing. Cut it before any: the bar says ghosts
  aren't answering.
- Draw again before the ghosts come, or while they show: they stay, and the next pause brings a new set that replaces
  Claude's. Leave them alone: they fade after 30 s. Larry's blue marks stay through all of it.
- On a device where a finger draws: a tap on a ghost keeps it with no dot drawn, and a tap off the ghosts dismisses
  them; then the finger draws again.
- Turn Ghosts off: lifting the Pencil asks nothing (the session log shows no turn). Larry's blue ghosts stay showing.
- Tap Larry's turn: the bar says *Larry is looking…* straight away and the Pencil keeps drawing. Chat has a thread
  named after the board holding the picture. Minutes later, with no tap, blue ghosts and his line appear on what he saw,
  even if the view has moved since.
- He draws unprompted on the thread: the same, with no tap by Igor. His next marks replace the unkept ones.
- Dismiss his marks: they don't return, not on the next look and not after closing and reopening the board. Leave them
  and reopen: only his newest set shows.
- Cockpit unreachable: drawing works as before and the bar says ghosts aren't answering, and that his marks aren't;
  Larry's turn shows a copyable problem; when the Cockpit is back the bar clears by itself.
