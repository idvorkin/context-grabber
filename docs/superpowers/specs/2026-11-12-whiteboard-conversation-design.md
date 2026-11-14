# Whiteboard: Larry's clock and the conversation strip

Issue [#879](https://github.com/idvorkin/context-grabber/issues/879) (Igor, from the iPad, 2026-11-12): "know how long
Larry has been thinking and if my requests are going simultaneously", "some kind of collapse expand conversation", and,
written on the board itself, "This seems very slow, are we crashing/hung?" Extends
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md) (*Who answers the pause*, *Larry's turn*).
Stories: [10-whiteboard.md](../../stories/10-whiteboard.md).

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
- A cancel button. A picture that has gone can't be called back.
- A clock for the fast responders (Haiku, Sonnet). They answer in about two seconds. Larry's clock shows whenever a
  turn of his is out, which on a Haiku or Sonnet board means after *Larry's turn* or *Send to Larry*.

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

## A repeat tap sends nothing (Igor, 2026-11-12; changes story 662)

Six taps on *Larry's turn* and one on *Send to Larry* in twelve seconds each sent Larry the same picture. He had to
say so himself.

- **While Larry is looking at a picture and nothing has changed since it went** (no new ink, no words waiting, the
  same part of the board on screen), *Larry's turn* and *Send to Larry* send nothing.
- **The tap is answered.** For two seconds the note's state reads **Larry already has this · 0:12**, then goes back to
  the clock.
- **Anything new and the tap sends as before**: new ink, waiting words or another part of the board on screen go at
  once as a fresh picture and the clock restarts.
- **With no turn out, *Larry's turn* always sends**, new ink or not: asking him to look again is a real request.
  *Send to Larry* keeps its own rule (off until the next stroke).
- **Every tap changes something on screen within a quarter of a second**: the clock appears or restarts, or the note
  says why nothing went.

## One line that opens (Igor, 2026-11-12: "some kind of collapse expand conversation")

### Closed: one line

The note is one line and never two. It doesn't change height, so it never moves the paper.

- **First: Larry's state**, when a turn is out: the clock, then what is waiting to go when he answers, as
  **next: ink**, **next: words** or **next: ink + words**.
- **Then the newest thing said, by whoever said it last**: Larry's line, or what the mic last heard (*You: …*), or
  *Listening…* with the mic open and nothing heard. When Igor's words don't fit, the end is kept and the start is
  cut, because the newest words are the ones he is checking. Larry's line keeps its start.
- **Last: how many suggestions are showing** (*3 to keep*) and a chevron.
- The note's other messages (a paste cut short, *Sent to Larry*, a look-only reason, Ghosts being off when the mic is
  tapped) take the middle for a few seconds and give it back.
- **A message about something still wrong stays**: *Ghosts: the Cockpit isn't answering* and *Larry's marks: the
  Cockpit isn't answering* hold the middle until the Cockpit answers again, however long that is.
- With nothing to say, there is no line, as today.

### Open: the conversation

A finger tap on the line opens a panel under it, over the top of the board.

- **It lies over the board and doesn't move it.** At most a third of the screen tall; more scrolls inside it.
- **It shows the recent end of the board's thread as it stands**: Larry's words in full, and for each picture of
  Igor's the words that went with it and its mark from the Cockpit (received, seen, done). Newest at the bottom, where
  it opens. Up to the last ten messages. *Open in Chat* opens the whole thread.
- **Under them, what is live**: the turn that's out with its clock, what is waiting to go next with the waiting words
  in full, and what the mic is hearing.
- **A board with no thread yet** shows only what is live.
- **Text can be selected and copied.**
- **The Pencil never acts on the panel**: it neither draws through it nor scrolls it. A stroke that starts on the
  board below draws as usual and the panel stays open. Fingers scroll and tap it.
- **It closes on a tap on the line.** It doesn't close when Larry answers or when Igor draws. Open or closed is
  remembered for the next board.
- **Suggestions under the panel can't be tapped** while it is open; the line's *3 to keep* is the hint to close it.
- **On an iPhone** there is no panel: a tap on the line opens the board's thread in Chat, when it has one.
- **Not here:** how each picture was sent, how much ink was new, how long each answer took. That is for a page on
  the Cockpit.

## Under discussion (not built; on #879)

- **Where the picture is.** The state could say *Sent* until Larry has picked the picture up and *Larry has it*
  after, with *Larry hasn't picked this up* as the honest slow signal. Waiting on Larry's answer about when the
  Cockpit's marks are made.
- **Larry's side:** a progress note while he works, words before marks, and timings on the Cockpit's thread page.
  Asked of Larry.

## Acceptance

- Send Larry a picture: within a second the note begins *Larry · 0:00* and counts up each second.
- He answers: the state goes and his line shows.
- Draw, pause, and tap *Larry's turn* while he is looking: the clock goes back to 0:00.
- He never answers: at three minutes the note shows *Larry didn't answer*; copying it gives the board, the time the
  picture went, the wait, what was waiting and whether the Cockpit was answering.
- Ink was waiting at the three-minute mark: a fresh picture goes and a new clock starts; the problem is still there.
- The Cockpit stops answering mid-wait: the state adds *Cockpit not answering* and keeps counting; it goes when the
  Cockpit is back.
- Leave the app for twenty seconds mid-wait and come back: the clock is twenty seconds further on.
- A long reply of Larry's and a long *Heard:* line are both showing: the state is still fully visible at the start.
- A pause on a Haiku or Sonnet board starts no clock; *Larry's turn* on one does.
- The board shows one problem at a time: a later failure takes the place of *Larry didn't answer*.
- *Dismiss* beside *Larry didn't answer* removes it.
- Tap *Larry's turn* twice with nothing drawn between: one picture is on his thread, and the second tap's answer is
  *Larry already has this*.
- Tap *Larry's turn* while he is looking, after drawing a stroke: a second picture goes and the clock restarts.
- Tap *Larry's turn* while he is looking, after scrolling to another page: a picture of that page goes.
- The Cockpit stops answering after Larry has spoken: the note says so for as long as it lasts, not for five seconds.
- Larry's long reply and a long *Heard:* are showing: the note is one line, the clock whole at its start.
- Draw while he is looking: the state gains *next: ink*.
- Tap the line: the panel opens over the board, the ink below hasn't moved, and Larry's whole reply can be read.
- Draw with the Pencil below the open panel: the stroke lands and the panel stays open.
- Close the board with the panel open and open another: the panel is open there.
- On an iPhone, tap the line on a board with a thread: Chat opens on that thread.
