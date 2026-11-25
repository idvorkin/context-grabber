# Ink side by side: the iPad's own ink beside the web board's

Status: built for bead context-grabber-vabk (stories 1209, 1213–1216). Asked for by Igor on 2026-11-22 at 21:38, via Larry.

## Summary

A debug screen on the iPad that splits down the middle. The left half is the app's own ink, a plain PencilKit canvas.
The right half is Larry's web board, the Cockpit's */ink* page, open on its *scratch* board. Igor draws on both,
one after the other or with a hand on each, and feels which ink keeps up with the Pencil. Each half shows a small
number in its corner: how long its last stroke took from touching down to the next frame, and the median so far.

It is an A/B tool and nothing else. The board itself is untouched: it keeps drawing with PencilKit exactly as it
does today, and nothing about the web board changes either.

## Goals

- Feel the two inks next to each other on the same iPad, at the same moment, under the same Pencil.
- Put a number beside the feel, the same kind of number on both sides, so a difference that is felt can be checked.
- Leave each sample in the session log, so a pulled log can be compared after the fact.

## Non-goals

- No change to how the board draws. Moving the board to the web's ink, or the web's to PencilKit, is a later
  decision this tool informs.
- Not a benchmark. The number is a guide (see *What the number means*), not a measurement of light leaving the glass.
- Not on the iPhone, which only looks at boards.
- No saving: the left half's ink is gone when the screen closes. The right half is the web board's own *scratch*
  board, which keeps what is drawn on it as the web board always does.

## What Igor sees

- **Where:** the home screen's Settings → *About and diagnostics* → **Ink side by side**. The row is on the iPad and
  the Mac, never on the iPhone.
- **The screen:** two halves of equal width with a thin line between them. The left is headed *iPad ink
  (PencilKit)*, the right *Web board (/ink)*. Each half fills the height under the bar.
- **The left half** draws with a black pen under the Pencil or a finger. A **Clear** button in the bar empties it.
- **The right half** is the Cockpit's */ink* page on its *scratch* board, the same page as in Safari, with its own
  tools. If the Cockpit can't be reached, the half shows the app's copyable error, *The web board didn't load* with
  the reason, and the left half still works.
- **The readout:** each half's top corner shows its numbers as `last 18 ms · median 21 ms · 12 strokes`, and
  *Draw to measure* before the first stroke. The numbers update with each stroke. Leaving the screen and coming back
  starts both counts again.
- **The log:** each stroke on either side adds an `ink_side_by_side` event: which side, that stroke's median and
  worst lag, how many frames it drew in, the running median and the count. Pressing **Clear** or leaving the screen
  adds one `board_pen_latency` line per half that drew, with `surface` *native* or *web*: how many frames were
  measured, the 50th and 90th percentile and the slowest, in milliseconds. `just pen-latency` prints those lines next
  to the board's own, so one pull of the iPad's logs gives both numbers.
- **What Igor does to measure (2026-11-24, his pick on bead 2vv):** open the screen on the iPad, write a few lines
  on each half with the Pencil, press **Clear**, then `just pull-logs` and `just pen-latency` on the Mac. If the web
  half's p50 is within a frame of the native half's, the board moves to the web's ink behind a switch.

## What the number means (and doesn't)

Both sides measure the same thing, the definition the web board itself already uses (its live-ink code, 2026-11-24):
**for every frame while the pen is down, the time from the oldest touch not yet drawn to the start of the frame
that draws it**. A stroke's number is the median of its frames, and its worst frame is kept too. The first frame of
a stroke counts from the pen-down; each later frame counts from the first pen movement since the last frame drawn.

- **Left (PencilKit):** the touch's own timestamp (the earliest coalesced touch since the last frame), to the
  display link's timestamp for the first frame that starts after it. A frame already under way when the touch
  arrives can't draw it, so it doesn't count. Both are seconds of system uptime.
- **Right (web):** the web board's own numbers, read as it logs them: the pointer event's timestamp, to the
  animation-frame time of the frame its live ink paints the new segment in. The app adds no measuring of its own to
  the page; it passes along the median, worst and frame count the page logs for each stroke. A tap on the page's own
  buttons, menus and fields is not a stroke and has no number.

Each side compares two times on one clock, so each number is sound on its own terms. They differ in what they
can't see:

- Neither number sees the pixels. A side that misses the next frame and draws the stroke one or two frames later
  shows the same number as one that doesn't. The feel is the real test; the number checks the gross difference
  (a touch that waits for the system, a page that is busy).
- The web side's touch timestamp is taken after the touch has crossed into the web page's process, so whatever
  WebKit adds getting it there is counted. The PencilKit side's isn't, so the web side's number includes a cost the
  native side's doesn't have to pay. That is part of the difference being measured.
- PencilKit predicts the Pencil's path ahead of the touches, and the web page can't. That shows in the feel, never
  in the number.
- A frame that takes longer than a second, or a number below zero, is a fault in the measuring, not a stroke: it is
  dropped and counted in the log as dropped.
- The board itself (not this screen) logs its own `board_pen_latency` lines with `surface` *board*, sampled from
  one Pencil moment in four to the frame's presentation time (story 1311). Those are a different span, so compare
  this screen's two surfaces with each other, not with the board's line.

## Acceptance criteria

- On the iPad, Settings → *Ink side by side* opens the two halves side by side. The left draws, and the right shows
  the web board's *scratch* board, which draws too.
- Each stroke on either half updates that half's readout, `last … ms · median … ms · n strokes`, and adds one
  `ink_side_by_side` event to the log, naming the side, the stroke's median and worst lag and its frame count.
- Pressing **Clear**, or leaving the screen, after strokes on a half adds one `board_pen_latency` line for that half,
  `surface` *native* or *web*, and `just pen-latency` prints it.
- With the Cockpit unreachable, the right half shows the app's copyable *The web board didn't load* error, and the
  left still draws and measures.
- A tap on the web board's own buttons, menus or fields leaves the web readout unchanged.
- Closing the screen and opening it again starts both readouts at *Draw to measure*.
- The iPhone's Settings has no *Ink side by side* row.
- The board's own drawing behaves exactly as before.
