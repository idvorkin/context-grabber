# Whiteboard: Larry's clock and the conversation strip

Issue [#879](https://github.com/idvorkin/context-grabber/issues/879) (Igor, from the iPad, 2026-11-12): "know how long
Larry has been thinking and if my requests are going simultaneously", "some kind of collapse expand conversation", and,
written on the board itself, "This seems very slow, are we crashing/hung?" Extends
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md) (*Who answers the pause*, *Larry's turn*).
Stories: [Larry's turn and the conversation](../../stories/10-whiteboard-turn.md).

## What happened

The session log of that report: 14 pictures went to Larry in four minutes, every one was delivered and answered, and
his answers took 5 to 63 seconds. The bar said *Larry is looking…* the whole time, in grey, in the middle of two lines
of other text. Second 5 and second 60 looked the same, and so did slow and broken. Igor shook the iPad 57 seconds into
the longest wait.

## Goals

- From the corner of his eye, while drawing, Igor can tell that Larry is working and for how long.
- A wait that ended without an answer says so, and what it says can be copied.
- Slow and unreachable never look the same.

## Non-goals (for this step)

- Changing what gets sent or when. The one-picture-at-a-time rule (story 662) stays as it is.
- Calling a picture back. One that has gone can't be. The 20-second controls below (Igor, 2026-11-14) free the board's
  turn or send the same picture again; none of them unsends anything.
- A clock for the fast responders (Haiku, Sonnet). They answer in about two seconds. Larry's clock shows whenever a
  turn of his is out, which on a Haiku or Sonnet board means after *Send to Larry*.

## Larry's clock (built first)

- **Where.** The bar's note under the top bar. While Larry is looking, the note **begins** with his state, so it is
  never the part that gets cut off: **Larry · 0:42**. Everything else the note carries follows it.
- **It starts when the picture is taken**, the moment the bar used to start saying *Larry is looking…*, and counts up
  once a second: *0:07*, *1:12*.
- **It stops when his answer is seen.** The state goes and his line shows as today.
- **A newer picture restarts it at 0:00.** The clock always times the picture Larry is now looking at.
- **At three minutes the board stops waiting**, as it does today. New: it says so. The bar shows **Larry didn't
  answer** as a problem that can be copied. The copied text names the screen and the operation and carries the state
  that explains it: when the picture went, how long the board waited, whether ink or words were waiting behind it,
  and whether the Cockpit was answering. If ink or words were waiting they go as a fresh picture, as today, and the
  clock starts again for that one. The problem stays until Igor dismisses it or Larry next answers.
- **The Cockpit not answering is the one "hung" signal.** When the board's looks at the thread have been failing, the
  state reads **Larry · 0:48 · Cockpit not answering** and the clock keeps counting. It clears itself when the
  Cockpit answers again.
- **Away and back.** If the app goes to the background while Larry is looking, the clock shows the true time since
  the picture went when it returns.
- **VoiceOver** reads the state as *Larry has been looking for 42 seconds*, when asked, not on every tick.
- **The Pencil keeps drawing** throughout; the clock never takes a touch.

## A repeat tap sends nothing (Igor, 2026-11-12; changes story 662; dimmed until the next stroke, Igor 2026-11-22)

Six taps on *Larry's turn* and one on *Send to Larry* in twelve seconds each sent Larry the same picture. He had to
say so himself.

- **Once Larry has a picture and nothing has changed since it went** (no new ink, no words waiting, the same part of
  the board on screen), *Send to Larry* is dimmed, until the next stroke (Igor, 2026-11-22, bead context-grabber-x3tm,
  reverting story 1176's *with no turn out a tap always sends*). That holds while he looks and after he has answered:
  he already has this picture, so there is nothing to send. VoiceOver's hint says *Larry already has this board*.
- **Anything new lights it again**: new ink, waiting words or another part of the board on screen, and a tap sends a
  fresh picture at once and the clock restarts.
- **What lights it without anything new**: a picture that didn't reach him (refused, deleted from the Inbox, or never
  taken), and *Interrupt*, which makes the next tap a fresh ask (story 805).
- **A tap that somehow arrives anyway sends nothing** and is answered: for two seconds the note's state reads **Larry
  already has this · 0:12**, then goes back to the clock.
- **Every tap changes something on screen within a quarter of a second**: the clock appears or restarts, or the note
  says why nothing went.

## Where the picture is: sent, or with Larry (Larry, 2026-11-12; story 773)

The Cockpit marks each of Igor's messages *received* when it lands, *seen* when Larry picks it up and *done* when he
has answered. Chat shows those marks; the board now reads them for the picture it is waiting on, the message that
carries that picture. Larry marks board pictures *seen* and *done* from 2026-11-14. One reading of the mark names the
state here and decides the controls in *After 20 seconds*, below.

- **While the Cockpit has the picture and Larry hasn't picked it up** (*received*), the state reads **Sent · 0:03**.
  The clock is the same clock, counted from when the picture went.
- **Once he has it** (*seen*), the state reads **Larry · 0:42**, as before.
- **A picture that sits unpicked for 20 seconds** reads **Sent · 0:21 · not picked up yet**. That is the honest slow
  signal: Larry is busy with something else, or isn't running. Twenty seconds is the same threshold as the controls'.
- **A picture the Cockpit hasn't taken yet** (no mark on its message) reads **Larry · 0:07**, as before; from twenty
  seconds it is stuck (below).
- **His answer ends the wait** whatever the mark said: an answer with no *seen* before it is still an answer.
- **The other states are unchanged and say more than the mark**: *Cockpit not answering* shows as before (the mark
  can't be read then, so the state keeps what it last knew), *Send to Larry* is still dimmed while he has the board as it is, and
  *Larry didn't answer* still comes at three minutes. Its copied state now also says where the picture was.
- **VoiceOver** says *Sent 3 seconds ago, not picked up yet* or *Larry has been looking for 42 seconds*.
- **The panel's live row** says the same as the line.
- **A Cockpit that sends no marks** (an older one): the state reads *Larry · 0:42* throughout, as before.

## After 20 seconds: Retry, Dismiss or Interrupt (Igor, 2026-11-14; stories 775–777)

Written on the board: "I think Larry got stuck. I need interrupt/retry button after 20s!" The clock says how long; it
doesn't say whether the picture ever reached him, or offer anything to do about it.

- **Twenty seconds after a picture goes** with no answer, the board looks at where the picture is (above: the same
  reading that names the state) and offers one small control. Before twenty seconds, nothing is offered.

| Where the picture is | Before 20 s | From 20 s |
|---|---|---|
| The Cockpit never took it: no mark on its message, or no such message, on a thread whose other pictures do carry marks | *Larry · 0:07* | *Larry hasn't got the picture*, with **Retry** and **Dismiss** |
| *Received*: the Cockpit has it, Larry hasn't picked it up | *Sent · 0:03* | *Sent · 0:21 · not picked up yet*, and **Interrupt** |
| *Seen*: Larry has it | *Larry · 0:12* | *Larry · 0:42*, and **Interrupt** |
| Not known: the Cockpit marks nothing, or the board hasn't read the thread yet | *Larry · 0:07* | *Larry · 0:42*, and **Interrupt**; never *Retry* |
| *Done*, or his answer | the state goes | nothing |

- **No mark at all: stuck.** The Cockpit hasn't taken the picture: it is still on its way or its answer was lost. The
  bar shows **Larry hasn't got the picture** as a problem that can be copied (when the picture went, how long it has
  waited, whether it is still going up, whether the Cockpit is answering, and where the picture is), with **Retry**
  and **Dismiss** beside it, where *Larry didn't answer* sits. A picture whose sending the Cockpit answered is never
  stuck: the Cockpit has it.
  - **Retry** sends the very same picture again: the same picture and the same message, so if the first did land the
    Cockpit keeps one and Larry is asked once. The clock goes back to 0:00 and the twenty seconds start again.
  - **Dismiss** stops waiting: the turn is free, words that went with the picture wait for the next one, and nothing
    more is said about that picture.
- **Only a Cockpit that marks messages can say a picture is stuck.** An older one marks nothing, so there a missing
  mark says nothing: its pictures are offered *Interrupt*, never *Retry*, and no turn on it looks stuck.
- **Received or seen, not done: the Cockpit has it.** It is Larry's to pick up or to answer. The note's line, after the
  clock, carries a quiet **Interrupt**. It frees the turn, so the next pause or tap is a fresh ask instead of being
  held for his answer. What Larry draws or says later still lands. Words waiting for the next picture still go with it.
  Sending it again would not wake him, so there is no *Retry* here.
- **Interrupt on a picture still going up** (a board's first picture, or one on a Cockpit that marks nothing, whose
  sending hasn't been answered) lets go of that sending too: the next tap sends at once and nothing more is said about
  that picture, as with *Dismiss*. The words that went with it wait for the next one, unless the Cockpit's mark says
  it already has the picture.
- **After Interrupt or Dismiss the next tap always sends**: no turn is out, so *Larry already has this* can't answer
  it.
- **Done, or his answer: nothing is offered**, and the control goes with the clock.
- **Small and out of the way.** Retry and Dismiss sit in the bar's problem row, Interrupt in the note's line. Neither
  covers the board, and the Pencil keeps drawing.
- **Retry and Dismiss only for the pictures the board hands him itself.** A *Send to Larry* goes through the outbox,
  which already keeps trying, and while it waits there the note says *Waiting to send* (story 1176), so its turn is
  never *stuck* and is offered neither. Once the outbox has sent it, *Interrupt* is offered on it as on any picture
  he has. Its state reads *Sent* or *Larry* from its mark.
- **One problem at a time, the newest wins.** The 3-minute wait is unchanged: if it runs out with the picture still
  stuck, *Larry didn't answer* takes the problem row's place. A picture stuck later takes the place of *Larry didn't
  answer*. *Larry hasn't got the picture* goes on its own when the mark comes, when he answers, and on *Retry* or
  *Dismiss*; it never takes another problem away.
- **A sending that Retry, Dismiss or Interrupt replaced** no longer speaks for the board: when it ends, it frees
  nothing and shows nothing. One that a newer picture replaced still says it failed, and its words still wait.
- **The session log says each change** (stuck, working, back to waiting or nothing) and each press, with the picture
  and where it was.

## One line that opens (Igor, 2026-11-12: "some kind of collapse expand conversation")

### Closed: one line

The note is one line and never two. It doesn't change height, so it never moves the paper: with nothing to say yet,
on a board just opened, its line is kept empty, so the paper doesn't jump when Larry's state or a message first shows.

- **First: Larry's state**, when a turn is out: the clock, then what is waiting to go when he answers, as
  **next: ink**, **next: words** or **next: ink + words**. With no turn out and Larry holding for more, an ear in
  its place (*Larry is listening*, below).
- **Then the newest thing said, by whoever said it last**: Larry's line, or what the mic last heard (*You: …*), or
  *Listening…* with the mic open and nothing heard. When Igor's words don't fit, the end is kept and the start is
  cut, because the newest words are the ones he is checking. Larry's line keeps its start.
- **Last: how many suggestions are showing** (*3 to keep*) and a chevron.
- The note's other messages (a paste cut short, *Sent to Larry*, a look-only reason, *Ask at my pauses* being off when the mic is
  tapped) take the middle for a few seconds and give it back.
- **A message about something still wrong stays**: *Ghosts: the Cockpit isn't answering* and *Larry's marks: the
  Cockpit isn't answering* hold the middle until the Cockpit answers again, however long that is.
- With nothing to say, there is no line, as today.
- **Words alone are said, never drawn** (Igor, 2026-11-12, #898). A reply of Larry's that is words with no marks
  and no changes to the board is his line in the note and a message in the panel, and nothing else: nothing lands on
  the board, nothing is offered to keep, and his marks already showing stay as they were. Only marks he sends as marks,
  or text he places with a change to the board, appear on it.

### Open: the conversation

A finger tap on the line opens a panel under it, **above the board: it pushes the page down and never covers ink**
(Igor, 2026-11-20, #1003: the panel lay over his top line of ink and took about a quarter of the screen; "a narrow
strip showing Larry's latest line that never covers ink. Opened, it pushes the page down"). Until 2026-11-20 the panel
lay over the board so the paper never moved; covering ink is the worse of the two, so now the paper moves down by the
panel's height while it is open and back up when it closes. The ink keeps its place on the page: what was at the top
of the screen is just under the panel.

- **It is small and keeps its size.** At most a fifth of the board tall, and never less room than about four lines;
  past that it doesn't grow, its messages scroll inside it (Igor, 2026-11-16, #917: "when chat expands it needs to
  scroll not grow"; at a third it covered nearly half the page). The status chip and *Open in Chat* stay at its foot,
  under the messages, while the messages scroll. What sits under the messages is bounded too, so nothing in the panel
  can grow it past that size (Larry, 2026-11-22, bead context-grabber-97s): what the mic hears shows at most two
  lines, ending on its newest words, with older words dropped at an *…*, and the status chip at most two lines.
- **It shows the newest.** It opens scrolled to the bottom, the newest line in view, and while it is there a new
  line keeps it there. A finger can scroll up to read older messages, and then a new line leaves it where Igor is
  reading (bead context-grabber-97s): it doesn't jump back down under his finger. Scrolled back to the bottom, it
  follows the newest again; closed and opened again, it opens at the newest.
- **It is the conversation, not a log of turns.** Larry's words in full, newest at the bottom, up to the last ten
  messages; *Open in Chat* slides the whole thread in over the board, and *Back* brings back the board as he left it
  (bead context-grabber-dbku). The thread's top bar has *Board*, which comes back to
  this board ([native chat, A board's thread opens its board](2026-10-25-native-chat-design.md); #1091). Igor's pictures that carried no words of his (the *Your turn on
  the board* the board sends on its own) are not rows: they were most of the panel, between Larry's sentences. A
  picture that went with Igor's own spoken words shows as a row of those words.
- **Larry's words get the emphasis.** His lines are in the main text colour; Igor's lines and the status are quieter
  but still at least 4.5:1 against the panel (the grey marks were about 2:1). The same holds for the closed line:
  Larry's words in the main colour, his state in the quieter one.
- **Docked, the conversation is about half the board wide** (#1438, Igor 2026-11-24: "Make docked chat be wider, like
  only halfway"). On a wide iPad the docked text column runs to about half the board's width, never narrower than about
  seventy characters, so a long reply reads as a paragraph and not one line across the whole board; the panel's
  background still spans the width. Floating, the text fills the card, whatever width it was given.
- **One status chip, one vocabulary.** Under the messages, one chip says where Igor's newest board picture is. While
  a turn is out it says exactly what the closed line's state says, the clock and what waits to go next: *Your board ·
  Sent · 0:02* or *Your board · Larry · 0:36 · next: ink*. With no turn out it says where the last picture got to:
  *Sent* (on its way, or the Cockpit has it and Larry hasn't picked it up), *Larry has it*, or *Answered*; while Larry
  is holding for more, the ear and his words for it instead (*Your board · Larry: waiting for more*). A reply of
  Larry's after the picture is *Answered* whatever its mark says, and a Cockpit that marks nothing never shows *Sent*:
  there the picture on the thread with no reply yet reads *Larry has it* (bead context-grabber-l9u; Larry's
  recommendation, Igor has not ruled on it). The chip
  replaces the *Now* and *Next* rows and each picture's *received*, *seen* and *done* marks, so the panel never shows
  two words for one state. With no picture on the thread and no turn out there is no chip.
- **The Cockpit's own lines are left out** (*Moved to a new chat*, where a message was sent on to a chat of its own):
  they are neither Igor's nor Larry's, and Chat shows them.
- **What the mic is hearing** shows under the chip while the mic is open.
- **A board with no thread yet** shows only the chip and what the mic hears.
- **Text can be selected and copied.**
- **Links are chips** (Igor, 2026-11-22, #1138: *"If Larry sends a chip in the chat for URL ideally it's a chip and it
  needs to be clickable"*). A link in the conversation stands as a chip where it was written, with the same words as
  in Chat's bubbles (*PR*, *Preview*, *Inbox*, *Larry: Lavish*, a site and its page), never the long tailnet address.
  A finger tap on it opens the link as Chat does, an *Inbox* chip on its thread in the app; the Pencil still does
  nothing on the panel. Copying text that holds a chip copies the link's full address in its place. The closed line, too short for chips,
  reads a link in Larry's newest words as the chip's words (*Larry: … the map: Larry: Lavish.*).
- **The Pencil never acts on the panel**: it neither draws through it nor scrolls it. A stroke that starts on the
  board below draws as usual and the panel stays open. Fingers scroll and tap it.
- **It closes on a tap on the line.** It doesn't close when Larry answers or when Igor draws. Open or closed is
  remembered for the next board.
- **Nothing on the board is under the panel**, so every suggestion stays tappable while it is open.
- **On an iPhone** there is no panel: a tap on the line slides the board's thread in over the board, when it has one,
  and *Back* brings back the board (bead context-grabber-dbku).
- **A tap that finds no thread says so** (Igor, 2026-11-22, #1161: "I should be able to interact with the chat"; the
  tap did nothing, silently). A board's thread is known only to the device that sent its pictures to Larry, so the
  iPhone looking at an iPad's board finds none. The note's middle then says, for its few seconds, where the
  conversation is: *Larry's conversation is on the iPad* (the name of the device that drew the board). On a board
  drawn on this device that has never gone to Larry, it says *No conversation with Larry yet*. The iPhone first
  opens the thread the board carries through iCloud, then looks among Larry's chats (*The board's chat from the
  iPhone*, below, #1161, #1163); these words are for when neither finds one.
- **Not here:** how each picture was sent, how much ink was new, how long each answer took. That is for a page on
  the Cockpit.

## The conversation as chat (Igor, 2026-11-24, #1384)

Igor, from the board: "Give me an alternate chat view so I can move chat to be like bubbles", and a minute later: "And
chat resizable like it is on the web. Actually I like the web view of chat, and I think I should also be able to
migrate chat so it's like a popover that I can move over the page, or can be docked like it is right now."

### Bubbles (built first)

- **A switch at the panel's foot**, beside *Open in Chat*: **Lines** (the panel as it is above) or **Bubbles**. Lines
  is the default. The choice is remembered for the next board, as open or closed is.
- **Bubbles look like Chat and the Cockpit's web chat.** Each message the panel shows is a bubble: Igor's on the right,
  in the accent colour with white words; Larry's on the left, in a quiet grey with the main text colour. No names over
  them: the side says who. Links are chips, and tables are grids, as in Chat's bubbles; a tap on a chip opens it as
  in Chat, and the log says so as it does for a chip in Lines.
- **The same messages as Lines.** The last ten; the Cockpit's own lines and Igor's word-less pictures left out; a
  reply of Larry's with marks and no words reads *drew on the board*.
- **The same size and scrolling as Lines.** At most a fifth of the board tall, never less than about four lines; it
  opens at the newest bubble, follows new ones while at the bottom, and stays where Igor is reading once a finger has
  scrolled up. The status chip, what the mic hears and *Open in Chat* stay under the bubbles.
- **The Pencil never acts on it**: it neither draws through nor scrolls the bubbles. Fingers scroll and tap them.
- **A long press on a bubble copies its words.** There is no reacting, quoting or sending on from here: that is
  Chat's, one tap away through *Open in Chat*.

### Resize, and float or dock

- **Resize, as on the web.** A grip on the panel's lower edge drags it taller or shorter, between about four lines and
  most of the board. The height is remembered for the next board. A double tap on the grip gives the panel back its
  own size, a fifth at most, as before any drag. Docked, the page moves with it, so ink is still
  never under the panel.
- **Float or dock.** **Float** at the panel's foot undocks it into a card floating over the board, which a finger
  drags by its top edge anywhere on the board and resizes by its top-left corner (#1491, Igor 2026-11-25: "resize in
  top left corner"), never past the board's edges and never smaller than a few lines and its controls. The grip at the
  top left grows the card up and to the left and shrinks it back; its bottom right stays where it is. It first floats at the board's top left, a third of it wide, clear of *?* and
  *Feedback* at its top right. The card holds the whole panel: the thread, the chip, what the mic hears, *Open in
  Chat*, the Lines / Bubbles switch and **Dock**. Floating, the page moves back up and the card lies
  over the ink, so it is Igor's choice to cover ink, never the board's. Dock puts it back above the board. Floating or
  docked, and where the card was, are remembered.
- **Everything at the card's foot fits, at any size it can be** (#1416, Igor 2026-11-24: "this dialogue is a little
  wonky"). The foot's controls stay on one line: when the card is too narrow for *Open in Chat* and **Dock** as words,
  they show as their icons, with the same names for VoiceOver. The thread takes what is left of the card after the
  chip, what the mic hears and the foot, so nothing at the bottom is cut off, docked or floating.
- **The Pencil never acts on the card either**: a stroke that starts on the card does nothing; one that starts on the
  board and runs under the card draws.

### Acceptance

- Open the conversation, tap **Bubbles**: the same messages show as bubbles, Igor's on the right in the accent colour,
  Larry's on the left. Close the board and open another: the conversation there opens in Bubbles.
- In Bubbles, Larry replies: a new bubble shows at the bottom and the panel stays the same height.
- In Bubbles, scroll up to an older bubble and Larry replies: the panel stays where it was.
- In Bubbles, a reply with a link: the link is a chip, and a finger tap opens it.
- In Bubbles, a Pencil stroke on the panel neither scrolls it nor draws.
- Tap **Lines**: the panel is as it was before this change.
- Drag the grip under the docked panel down: the panel grows with the finger and the page moves down with it; let go,
  close the board and open another: the panel is that tall there. Drag it up past about four lines: it stops there.
  Double-tap the grip: it is its own size again.
- Tap **Float**: the page moves back up and the conversation is a card at the board's top left. Drag its top edge:
  it follows the finger and stops at the board's edges. Drag the grip at its top-left corner up and left: it
  grows up and left while its bottom right stays put; down and right, it shrinks, never smaller than a few lines, and
  at the board's top or left edge it stops growing. Close the board and open another: the card is where it was left. Tap **Dock**: it is above the board
  again, at its docked height.
- Float the card at its first size, and at the smallest its top-left grip allows: the foot is one line, nothing at its bottom is
  cut off, and *Open in Chat* and **Dock** still work (as icons when the words don't fit).
- With the card floating, a Pencil stroke that starts on the card draws nothing; one that starts beside it draws.

## Larry is listening (Igor, 2026-11-22, context-grabber-4fww)

Igor, on his board: when Larry has seen a post but is waiting for more, because Igor is mid-thought, Larry says
nothing, and the board shows a tiny indicator instead. The Cockpit marks Igor's newest message as *seen* and *waiting*,
with Larry's words for it, until Larry's next message or a done clears it.

- **An ear, gently animated, with Larry's words**: *Larry: waiting for more* when he gives none. It shows at the start
  of the note's line, where his state would be, and as the panel's chip, *Your board · Larry: waiting for more*, in
  place of *Larry has it*: one chip, one vocabulary. With Reduce Motion on, the ear holds still.
- **Only on Igor's newest message.** A hold on an older message, or one Larry has since answered, shows nothing. It
  shows whether that message carried a picture or only words.
- **It is an answer, not a silence.** A hold on the picture of a turn that is out ends that turn as his answer would:
  the clock stops, no *Interrupt* is offered, *Larry didn't answer* never comes, and the line never says *nothing to add*.
  Ink or words that waited for him go at once as the next picture, since more is what he is waiting for.
- **It clears** when Larry's next message lands, when the Cockpit stops marking the hold, or when a new picture or
  message of Igor's goes. While a turn is out, the turn's own clock speaks, not the ear.
- **No reply is expected** while the ear shows: nothing on the board waits for one or says he is late.
- **A Cockpit that never holds** shows no ear, and everything else reads as before.
- **The session log says when it starts and stops**, with Larry's words and what ended it.

## The board's chat from the iPhone (Igor, 2026-11-22, #1163)

Igor, on the iPhone, in the boards list: "Maybe I should have a chat button on every board when I'm in this view on
the iPhone. Not sure, maybe something subtle." Just before, a tap on the note of a board drawn on the iPad did
nothing: that board had a thread with Larry, but only the iPad knew which one.

- **Every row of the boards list on an iPhone ends in a small chat bubble**, quiet, in the secondary colour, at least
  44 points to tap. A tap on it slides that board's thread in over the list, and *Back* comes back to the list (bead
  context-grabber-dbku). A tap anywhere else on the row opens the board, as
  before. The iPad and the Mac have no bubble: there the board's panel holds its conversation.
- **The board's thread is found wherever it was started.** The one this device started is used at once. Otherwise
  **the board carries its thread through iCloud** (Igor, 2026-11-22, #1161, option B): the device that sends a
  board's pictures to Larry puts the board's thread on the board's iCloud copy, so every other device that has the
  board knows its thread, and the bubble and the note open it with no looking and no wait. The drawing device sends
  the thread up on its next sync after the thread starts or changes, even with no new ink, and a board that already
  had a thread before this goes up on the drawing device's next sync too. Only when the board carries no thread
  (its drawing device hasn't synced since this came, or it never went to Larry) does the iPhone look among Larry's
  chats for one titled with the board's name, and open it only if one of its messages came from this very board, so a
  chat that only shares a name is never opened. That look is a stopgap for boards from before, to be dropped once
  they all carry their thread. A thread found once is remembered until the app closes.
- **A thread started from the outbox goes up at once too** (bead context-grabber-e3vb). A board's first picture that
  waited in the outbox (the Cockpit couldn't be reached when it was sent) starts the board's thread when the outbox
  finally sends it; the board goes up to iCloud with that thread right then, not at the next return to the app or
  close of the board.
- **A thread the Cockpit no longer has comes off the board** (bead context-grabber-e3vb). When the Cockpit answers
  that a board's thread is gone, the drawing device forgets it and the board's iCloud copy stops carrying it, on a
  sync that runs at once, so the iPhone never opens a dead thread. Until the next picture starts a new thread (which
  goes up as before), the iPhone treats the board as one carrying no thread and looks among the chats. Only a thread
  the Cockpit said is gone is cleared: a reinstalled iPad, which starts out knowing no threads, never clears the one
  a board carries. The session log says when a forgotten thread was cleared from the board's iCloud copy.
- **A Send from any device goes to the board's one conversation** (Igor, 2026-11-22, on the design board; bead
  context-grabber-da1, story 1158). A *Send to Larry* on a device that didn't draw the board (an iPhone looking at an
  iPad's board) goes to the thread the board carries through iCloud, and that device keeps it as the board's thread
  from then on, so its note and bubble open the same conversation. Only a board that carries no thread starts one
  from such a device. On the drawing device its own thread is the board's, the one it sends up; a reinstalled one that
  knows none of its own yet uses the thread its board carries, so its next picture doesn't start a second
  conversation either. A thread the Cockpit said is gone is never used again, on any device.
- **The board's thread wins over an older one of this device's.** A board an iPhone sent to Larry before this, from
  the phone, opens and sends to the thread the board carries when it carries one, not the second one the phone
  started then; with none carried, the phone's own is used, as before.
- **While it looks** the bubble turns into a small spinner, and a second tap does nothing.
- **A board with no chat says so.** The list shows *No chat with Larry for this board yet*, which can be copied with
  the board, its name and how many chats were checked. It is not a bug, so it files no report.
- **A Cockpit that can't be reached says so**, copyably, with the reason, as Chat itself does.
- **The note's line on an iPhone** looks the same way: a tap on it, on a board this device never sent, opens the
  thread the board carries, else looks among the chats, or the note says where the conversation is, as above, for a
  few seconds. The session log says where each thread was found: this device, the board's iCloud copy, earlier this
  launch, or the chats.
- **TestFlight builds need one step from Igor first.** The board's thread is a new piece of the board's iCloud copy.
  Builds from the cable save to iCloud's development side, which takes it on its own; TestFlight builds save to the
  production side, which refuses a board that carries a piece it hasn't been given, ink and all. So before the first
  TestFlight build with this: a cable build sends a board with a thread up, then the development schema is deployed
  to production in the CloudKit Console (the same step as the whiteboard spec's, *TestFlight builds need one step
  from Igor first*). Until then a TestFlight build still syncs every board's ink (Igor, 2026-11-22, bead
  context-grabber-irm0): when iCloud refuses a board for the thread it carries, the board goes up once more without
  its thread, so its ink and every board after it still sync, and the session log says the thread was left off and
  what iCloud said. For the rest of that launch boards go up without their threads, so a refused thread doesn't
  send its board up again and again; the next launch offers the threads again, and once production has the piece
  they go up on their own. Until then the other devices find the board's conversation among Larry's chats, as for a
  board from before.
- **A board with no thread, sent from the iPhone first.** The phone's Send starts the conversation and the phone keeps
  it. The board's iCloud copy is written only by the device that drew it, so until that device learns the thread the
  board carries none, and the iPad's next picture would start its own: a rare order (the iPad draws, so it sends
  first), left for later (bead context-grabber-2ezr).

## Under discussion (not built; on #879)

- **Larry's side:** a progress note while he works (it would follow the clock: *Larry · 0:42 · reading the board*),
  words before marks, and timings on the Cockpit's thread page. Larry has taken these as `cockpit-dj8`.

## Acceptance

- Send Larry a picture: within a second the note begins *Larry · 0:00* and counts up each second.
- He answers: the state goes and his line shows.
- He answers in words only, with his marks from before still showing: his words are the note's line and in the
  panel, nothing new is on the board or offered to keep, and his earlier marks are where they were.
- Draw, pause, and tap *Send to Larry* while he is looking: the clock goes back to 0:00.
- He never answers: at three minutes the note shows *Larry didn't answer*; copying it gives the board, the time the
  picture went, the wait, what was waiting and whether the Cockpit was answering.
- Ink was waiting at the three-minute mark: a fresh picture goes and a new clock starts; the problem is still there.
- A picture a pause on a Larry board handed him doesn't reach the Cockpit: at twenty seconds *Larry hasn't got the picture* shows with *Retry* and
  *Dismiss*. *Retry* sends the same picture and the clock starts again; *Dismiss* frees the turn.
- The Cockpit has the picture and Larry hasn't finished: at twenty seconds the note's line offers *Interrupt*; a tap
  frees the turn, and the next pause or tap sends a fresh picture (never *Larry already has this*).
- A Cockpit that marks nothing: no turn ever shows *Larry hasn't got the picture* or *Retry*; from twenty seconds the
  note's line offers *Interrupt*.
- *Retry* on a picture that did land the first time: the thread holds it once.
- The Cockpit stops answering mid-wait: the state adds *Cockpit not answering* and keeps counting; it goes when the
  Cockpit is back.
- Leave the app for twenty seconds mid-wait and come back: the clock is twenty seconds further on.
- A long reply of Larry's and a long *Heard:* line are both showing: the state is still fully visible at the start.
- A pause on a Haiku or Sonnet board starts no clock; *Send to Larry* on one does.
- The board shows one problem at a time: a later failure takes the place of *Larry didn't answer*.
- *Dismiss* beside *Larry didn't answer* removes it.
- Tap *Send to Larry* twice with nothing drawn between: one picture is on his thread, and the second tap's answer is
  *Larry already has this*.
- Tap *Send to Larry* while he is looking, after drawing a stroke: a second picture goes and the clock restarts.
- Tap *Send to Larry* while he is looking, after scrolling to another page: a picture of that page goes.
- The Cockpit stops answering after Larry has spoken: the note says so for as long as it lasts, not for five seconds.
- Larry's long reply and a long *Heard:* are showing: the note is one line, the clock whole at its start.
- Draw while he is looking: the state gains *next: ink*.
- Tap the line: the panel opens above the board and the page moves down by its height, so the top line of ink is
  just under the panel, not under it; Larry's whole reply can be read. Tap again: the page moves back up.
- A thread of three pictures with no words and three replies: the panel shows Larry's three replies one after
  another, no *You: Your turn on the board* rows, and one chip *Your board · Answered*. The same on a Cockpit that
  marks nothing; there a picture with no reply yet reads *Your board · Larry has it*, never *Sent*.
- Larry is looking at a picture with ink waiting: the chip reads *Your board · Larry · 0:12 · next: ink*, the same
  words as the closed line.
- Larry's lines read in the main text colour; every other line in the panel and the note is at least 4.5:1.
- Larry holds on the picture he is looking at with *waiting for more*: the clock stops, an ear and *Larry: waiting
  for more* start the note's line, the chip reads *Your board · Larry: waiting for more*, and no *Interrupt* or *Larry
  didn't answer* ever comes. His next reply takes the ear away.
- On an iPad in landscape with the conversation docked, Larry's long reply wraps at about half the board's width, and
  never narrower than about seventy characters. Floated into a wide card, it fills the card.
- With more messages than fit, the panel is a fifth of the board tall, shows the newest message at its bottom, and
  scrolls with a finger to the older ones; another reply arrives and the panel stays the same height, the reply in view.
- Scroll the panel up to an older message, and another reply arrives: the panel stays where it was; scroll back down to
  the newest and the next reply is in view again.
- Speak a long sentence with the mic on and the panel open: what it hears is at most two lines, its newest words, and
  the panel and the paper under it don't move.
- Draw with the Pencil below the open panel: the stroke lands and the panel stays open.
- Close the board with the panel open and open another: the panel is open there.
- On an iPhone, tap the line on a board with a thread: Chat opens on that thread.
- On an iPhone, tap the line on an iPad's board with no chat with Larry: Chat doesn't open, and the note says *Larry's conversation is on the
  iPad*.
- On an iPhone, in the boards list, tap the bubble on a board drawn on the iPad that has talked with Larry: Chat
  opens on that board's thread. Tap the row beside it: the board opens.
- On an iPhone, tap the bubble on a board that never went to Larry: *No chat with Larry for this board yet* shows in
  the list and can be copied; no report is filed.
- On an iPhone, open a board drawn on the iPad and tap its note: Chat opens on the board's thread.
- Send a board to Larry from the iPad, close it, and on the iPhone (after its boards sync) tap the board's bubble or
  its note: Chat opens on that thread at once, and the session log says it came from iCloud.
- A board that talked with Larry before this change: once the iPad has synced with this build, the iPhone opens its
  thread from iCloud too.
- With the Cockpit unreachable, send a new board's first picture from the iPad; bring the Cockpit back: once the
  outbox sends it, the board goes up to iCloud with its new thread without being closed, and the iPhone's bubble opens
  it.
- Delete a board's thread on the Cockpit and send the board's next picture from the iPad: the Cockpit refuses it, the
  board's iCloud copy stops carrying the thread at once, and the iPhone's bubble no longer opens the dead thread.
- Reinstall the app on the iPad: the boards that come back keep the threads they carry on iCloud.
- Send Larry a picture, the Cockpit takes it and he hasn't picked it up: the note begins *Sent · 0:00* and counts.
- He picks it up: the state changes to *Larry ·* and the clock doesn't restart.
- Twenty seconds pass with the picture not picked up: the state adds *not picked up yet* and *Interrupt* shows.
- He answers without ever marking it: the state goes and his line shows.
- Three minutes pass and it was never picked up: the copied problem says where the picture was.
