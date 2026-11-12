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

## Under discussion (not built; on #879)

- **Where the picture is.** The Cockpit already marks each message received, seen and done. The state could say
  *Sent* until Larry has picked the picture up and *Larry has it* after, with *Larry hasn't picked this up* as the
  honest slow signal. Waiting on Larry's answer about when those marks are made.
- **A repeat tap with nothing new sends nothing** and says *Larry already has this*. Changes story 662; waiting on
  Igor.
- **One line that opens.** The note becomes a single line (state, newest words, what is waiting to go next) and a tap
  opens the recent end of the board's thread over the top of the board. Waiting on Igor.
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
