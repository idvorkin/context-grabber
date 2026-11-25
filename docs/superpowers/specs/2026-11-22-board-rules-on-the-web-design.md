# The board's rules on the web: BoardCore as WebAssembly

Story 1503. Plan: [2026-11-22-board-rules-wasm-plan.md](../plans/2026-11-22-board-rules-wasm-plan.md). Igor,
2026-11-22: the Cockpit's web ink board runs the app's own Swift board rules, compiled to WebAssembly, so a board
answers the same on the web as on the iPad.

## Summary

The board's rules (where a clear line is, what a recorded session replays to) build as one WebAssembly module. The
Cockpit's web board loads it once, hands it the board, tells it about new ink as it is drawn, and asks it where a cut
lands. The answers are the iPad's, computed by the same code, not a JavaScript copy of it.

## Goals

- The rules the board uses on the iPad build for WebAssembly (WASI), with nothing else of the app: no networking, no
  disk, no drawing.
- A small interface the Cockpit codes against, with a version number, that stays the same while the rules behind it
  change.
- The board stays loaded: the Cockpit sends it once, then only new ink, and asks with plain numbers.
- One command builds the module, stripped; one replays the Cockpit's recorded board sessions through it and checks them
  against the same goldens the app's own replay test uses.

## Non-goals

- Not the Cockpit's side: the page that loads the module, the browser's WASI stand-in and the board's adapter are the
  Cockpit's work.
- Not text measuring: placing a text needs a font, and the module has none, so nothing that lays out letters is offered.
- Not a smaller module yet. It is about 56 MB stripped (about 20 MB gzipped, 13 MB with brotli), nearly all Foundation
  and its Unicode data. Moving the rules to a lighter Foundation is later work.
- Not the iPad's own precision (below).

## What the Cockpit sees

- It loads the module and starts it once.
- It hands over the board exactly as the iPad posts it to the Cockpit: the board's id and its strokes, each with its
  points and width, kept texts included. The module answers with how many boxes its rules see, or says why it could
  not read the board.
- New ink goes in as strokes in the same form. Anything else that changes the board (an erase, a move, an undo) means
  loading it again.
- Asked where a cut at a height lands, it answers with the clear line the iPad would choose: the height itself when it
  is clear, else the nearer edge of the row of ink it falls in, the top only when it is within two lines.
- With nothing loaded, it says so rather than answering.
- Every failure can be read back as words.

## The interface, version 1

The module is a WASI reactor (`wasm32-unknown-wasip1`): the host calls `_initialize` once, then the exports below.
It imports 34 `wasi_snapshot_preview1` functions and nothing else: `args_get`, `args_sizes_get`,
`clock_res_get`, `clock_time_get`, `environ_get`, `environ_sizes_get`, `fd_close`, `fd_fdstat_get`,
`fd_fdstat_set_flags`, `fd_filestat_get`, `fd_filestat_set_size`, `fd_filestat_set_times`, `fd_pread`,
`fd_prestat_dir_name`, `fd_prestat_get`, `fd_read`, `fd_readdir`, `fd_seek`, `fd_sync`, `fd_tell`,
`fd_write`, `path_create_directory`, `path_filestat_get`, `path_filestat_set_times`, `path_link`,
`path_open`, `path_readlink`, `path_remove_directory`, `path_rename`, `path_symlink`, `path_unlink_file`,
`poll_oneoff`, `proc_exit` and `random_get`. Measured under node over the whole test (the four replays,
loads, new ink, cuts and refusals), only six are called: `random_get`, `args_sizes_get`, `args_get` and
`environ_sizes_get` while `_initialize` runs, then `clock_time_get`, and `fd_prestat_get` once, answered "bad
descriptor" (8): there is no directory to open. A browser's stand-in answers those six and can answer every other
import with an error. All numbers are wasm
`i32` unless marked `f64`.

**Memory.** The host writes input into the module's `memory` through a buffer it asks for with `bw_alloc`, and
frees it with `bw_free` once the call returns: the module never keeps an input buffer. Every pointer an export
returns is a new *reply*: four bytes of length (unsigned, little-endian) and then that many bytes of UTF-8. The host
reads it and frees the pointer with `bw_free`. Text is UTF-8 JSON unless said otherwise. Any call may grow the
memory, which replaces `memory.buffer`: the host takes a fresh view of it after every call, never one kept from
before.

| Export | Arguments | Returns |
|---|---|---|
| `bw_alloc` | `n`: bytes | a pointer to `n` bytes for the host to fill |
| `bw_free` | a pointer from `bw_alloc` or a reply | nothing |
| `bw_info` | none | a reply: `{"abi": 1, "cgfloat_bits": 32, "contract": 1, "line": 40, "near": 80}` |
| `bw_load` | pointer, length of a board | the number of boxes, or `-1` |
| `bw_add_strokes` | pointer, length of `{"strokes": [...]}` | the number of boxes now, or `-1` |
| `bw_cut_y` | `y` (`f64`, board points) | the clear line (`f64`), or NaN |
| `bw_error` | none | a reply holding why the last `bw_load`, `bw_add_strokes` or `bw_cut_y` failed (plain text), or `0` when it did not |
| `bw_replay` | pointer, length of a recorded session (JSONL) | a reply: the replay (below). For tests |

- `bw_info`: `abi` is this interface's version; it goes up when an export's arguments, results or JSON shapes
  change, and a host that sees a version it doesn't know stops. `cgfloat_bits` is the width of the rules'
  arithmetic, `contract` the board contract the replay reads, `line` and `near` the ruled line and how far a cut
  looks for a clear one, in board points.
- A board is the body of the iPad's `POST /whiteboard/strokes`: `{"board": id, "strokes": [...]}`. A stroke is
  `{"id", "points": [[x, y], ...], "width"}` with optional `"hidden"`, `"t"`, `"color"`, `"tool"` and
  `"meta"` (a `group` in it makes strokes one box); a kept text is `{"id", "kind": "text", "x", "y", "w", "h", "t"}`. A kept text is told from another by its
`t` (milliseconds), as on the iPad, which posts it: texts with no `t`, or within a millisecond of each other, count
as one box.
  A width left out is 3, as on the iPad; the web board's own format (`pts`, `w`, a default of 4) is the Cockpit's to
  convert. Other fields are ignored.
- The boxes are what the iPad's rules cut around: each shown stroke's, each kept text's, a group's as one; hidden ones
  left out.
- `bw_load` replaces the loaded board. When it fails nothing is loaded. `bw_add_strokes` adds to the loaded board;
  when it fails (nothing loaded, or a stroke it can't read) the loaded board is as it was.
- `bw_cut_y` answers NaN when nothing is loaded.
- `bw_replay` runs a recorded session (the Cockpit's `fixtures/board/sessions`) through the board's own replay and
  answers `{"name", "contract", "mismatches": [..], "turns": [{"id", "onBoard", "hint"}], "batches": [{"reply",
  "arrivedAt", "matches", "replayedOk", "recordedOk"}]}`, or `{"error": why}`.

## The interface, version 2: rows and folds

Story 1508. Igor, 2026-11-22: "build all of the web features for the Swift core and drag them back and forth". Version 2 adds the
next two answers the web board takes from the app: which row of writing a tap is on, and what folding a header tucks
away. Everything in version 1 is unchanged; `bw_info` says `"abi": 2`.

These answers need the board's writing itself, not only its boxes, so the Cockpit sends a second copy, the *outline*,
held apart from the board `bw_load` keeps:

- Each stroke with its real points and pen width (a width left out is 3), and whether it is hidden.
- Each kept text and each card as the box the Cockpit measured, since the module cannot measure text. Each moves whole
  and is nobody's handwriting.
- Which strokes belong to one group (a text or a card is its own group).
- The headers as the iPad keeps them: each header's strokes, its `#` mark and deeper marks, and, when it is folded,
  what its fold holds, what it hid itself, how far the rest slid, how many lines it hides and where its section ended.
- With each header, the strokes written under it while it was folded, once it has been opened (story 1231): its
  section ends where the first of them begins. The page records them when it unfolds a header, as the iPad does: the
  strokes the opened section would take that the fold did not hold. Without them, ink written under a folded header
  joins the section on the next fold.

| Export | Arguments | Returns |
|---|---|---|
| `bw_outline_load` | pointer, length of an outline | the number of strokes and boxes read, or `-1` with nothing loaded |
| `bw_outline_add` | pointer, length of `{"strokes": [...]}` | the number of strokes and boxes now, or `-1` with the outline as it was |
| `bw_row_at` | `y` (`f64`) | a reply: `{"row": null}` on blank paper, `{"row": {"header", "top", "bottom"}}` on a header's row, else `{"row": {"names", "top", "bottom"}}` with the row's strokes in board order |
| `bw_fold` | pointer, length of `{"id"}` | a reply: `{"fold": null}` when there is nothing to fold, else `{"fold": {"ids", "own", "shift", "lines", "bottom"}}` |

- The row at a height is the row of writing within half a line of it, as a margin tap or the hold menu on the iPad
  finds it. A row holding a header is that header.
- Folding asks what the fold would do and leaves the loaded outline as it was: the Cockpit applies the answer to its
  own board, then sends the outline again.
- New writing at the end goes in with `bw_outline_add`; anything else that changes the board loads the outline again.
- With no outline loaded, both questions answer `{"error"}` saying so, and every failure can be read back as words.

The web board's "Swift N/M" level moves each answer over one step at a time: below the step the web board answers
itself, at or above it the module does, so the two can be compared on the same board.

## The interface, version 3: where a paste lands, and the room a drop opens

Story 1513. The next two steps of the web board's Swift level: a paste (text pasted as a kept text) lands where the
iPad's would, and a selection dropped on writing pushes it down by the iPad's rule. Both are asked of the board
`bw_load` keeps, with plain numbers; `bw_info` says `"abi": 3`, and versions 1 and 2 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_place` | `w`, `h`, then the view's `left`, `top`, `right`, `bottom` (all `f64`, board points) | a reply: `{"x", "y", "push": null}` where a clear patch holds it, else `{"x", "y", "push": {"cut", "dy"}}`; `{"error"}` with nothing loaded |
| `bw_drop` | the dropped block's `left`, `top`, `right`, `bottom`, then the box it was lifted from (all `f64`) | a reply: `{"push": null}` when it opens no room, else `{"push": {"cut", "dy"}}`; `{"error"}` with nothing loaded |

- The Cockpit measures the pasted text and sends its size: the module has no font.
- A paste lands on the clear patch of the view nearest its middle that holds it with half a line of air all round, right
  of the margin and inside the page. When none does, it goes under the writing above the clear line nearest the view's
  middle, and room opens there: as much as it needs beyond the blank paper already there, in whole lines.
- A drop opens room only when the block sits on writing other than the line it was lifted from (touching an edge is
  not sitting on it). Then everything below the clear line nearest its top goes down by whole lines until the first of
  it is half a line under the block.
- For a drop the loaded board is everything but what was dropped: the Cockpit loads that board before asking.
- The Cockpit moves the writing; the module only answers where and how far.

## The interface, version 4: headers written in ink, Fold all and Collapse

Story 1512. The next step: an underline or a # the principal writes makes a header by the iPad's rule for headers
written in ink, and Fold all and Collapse to a level fold the headers the iPad's Fold all and Collapse fold. Both are
asked of the outline `bw_outline_load` keeps, each on a copy: the loaded outline stays as it was, and the Cockpit
makes the board change. `bw_info` says `"abi": 4`; versions 1 to 3 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_ink_header` | `{"name", "id"}`: the stroke just drawn (already in the outline) and the name a new header takes | a reply: `{"ink": null}` when the stroke does nothing for headers, else `{"ink": {"kind", "header", ...}, "after": the header as it now is}`; `{"error"}` with no outline or no name and id |
| `bw_fold_plan` | `{}` for Fold all, `{"to": n}` for Collapse to level n | a reply: `{"open", "levels", "folds": [{"id", "ids", "own", "shift", "lines", "bottom"}]}`; `{"error"}` with no outline, a request that is not a JSON object, or a `to` that is not a whole number |

- `kind` is `underline` or `hash` (the line became header `id`; with `y`, the line's middle, and `mark`, the strokes
  that made it), `grew` (the stroke was written on a header's line and joined it; with `names`) or `deeper` (a #
  finished beside a # header's #s took it a level deeper; with `level`, `y` and `mark`). `after` is the header as
  the iPad keeps it.
- `folds` are in the order the iPad makes them, the lowest header first, each as `bw_fold` describes one, and only
  the headers that fold now (one already folded, or one that does not fold, is not listed). `open` says every fold
  was opened first (Collapse does that; Fold all does not). `levels` is each header's level with everything open.
- The Cockpit makes the folds one after another by its own fold, given each fold's strokes and shift.

## The interface, version 5: what a hold is on

Story 1620. A Pencil held still picks up the same word the iPad's Pencil hold picks up, and a finger held still brings
up the same menu a finger hold brings up on the iPad: *Select* and *Delete* the thing under it (no *Delete* on a header's row), then the rows
for its line. Both over the loaded outline; `bw_info` says `"abi": 5`; versions 1 to 4 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_word_at` | `x`, `y`, `slop` (`f64`, board points) | a reply: `{"names": [...]}`, or `{"names": null}` off ink; `{"error"}` with no outline |
| `bw_hold_menu` | `x`, `y`, `inMargin` (`i32`, nonzero left of the margin), `slop` | a reply: `{"choices": [id], "names", "on", "header"?}`; `{"error"}` with no outline |

- A choice is named by its id (`select`, `delete`, `make-room`, `paste`, `make-header`, `not-header`, `fold-all`,
  `level-1` to `level-3`, `unfold-all`); `header` is the header *Not a header* takes. `on` is `header-mark`,
  `header`, `group`, `ink` or `paper`; `names` are what *Select* and *Delete* take.
- A hold anywhere inside a box the Cockpit sends (a kept text or a card) is on that box, as on the iPad.

## The interface, version 6: a connector's route

Story 1621. A connector's shaft runs where the iPad's connectors route it: straight from one end's side to the other's,
unless that crosses a box in the way; then one orthogonal elbow that crosses nothing (across then down, else down
then across); else straight anyway. `bw_info` says `"abi": 6`; versions 1 to 5 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_route_connector` | `{"from", "to": [left, top, right, bottom], "fromSide", "toSide": "top" \| "bottom" \| "left" \| "right" \| "center", "obstacles": [box]}` | a reply: `{"points": [[x, y], ...]}`, two or three; `{"error"}` without both boxes |

- No board is loaded: the Cockpit sends the two ends' boxes and the boxes of the other things that could be in the
  way, and draws the head itself.

## The interface, version 7: Larry's ops

Story 1622. The web board reads Larry's batch using the app's rules for accepting it and planning its changes, then
puts the plan on its own board. `bw_info` says `"abi": 7`; versions 1 to 6 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_ops_plan` | `{"batch": the message's ops, "board"?: {"strokes", "boxes", "metas": {name: notes}, "folds": {name: "h:<header>"}, "ghosts": [text], "measured": {op index: [width, height]}, "pages"}}` | a reply: `{"batch": {"refusal", "label", "board", "base_rev", "ops", "names_used"}, "plan"?}`; `{"error"}` when it can't be read |

- Without a board it only reads the batch: its refusal as the iPad names it, and the names it uses (what a batch from
  an older look conflicts on).
- The board is sent with each ask, with strokes and boxes in the same form as `bw_outline_load`. Each kept text or
  card answers to its own name and can anchor a connector or be in the way of its route. Nothing is kept between asks.
- The plan names what it touches, never a canvas place: `moves` {name: [dx, dy]}, `erase`, `hidden` {name: bool},
  `added` (his strokes where the batch leaves them), `metas`, `forget`, `select`, `texts` and `dismissed` (his ghosts),
  `inked`, `missing_ids`, `rooms`, `moved`, `pages_after`, `connected`, `rerouted`, `loosened` and `overlays`.
- `overlays` gives the controls to set or remove in batch order, in the same form as the `overlay` and `remove_overlay`
  ops. The Cockpit applies them in that order.
- Each showing ghost can carry its own `"measured": [width, height]`. For new text, the board's `measured` map uses
  the zero-based position of each `add_text` in the batch's `list`. Two texts with the same name can take different
  space. The planner uses the Cockpit's measurements for placement and room, and estimates a text's size when none
  is supplied.

## The interface, version 8: the room a late reply opens

Story 1623. A text of Larry's set on ink lands as a paste or a drop does: on its own lines, with the writing below
making room, as the app lands it. A reply of Larry's kept over ink Igor wrote after its picture opens room by the app's late-reply rule: the marks
stay where he drew them, and from the top of the line of writing the newer ink starts in, everything below goes down
whole lines until it is half a line under the lowest mark. `bw_info` says `"abi": 8`; versions 1 to 7 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_late` | `{"marks": [[left, top, right, bottom]], "seen"}`: the marks' boxes, and when the picture was taken, unix ms | a reply: `{"push": {"cut", "dy"} \| null, "covered"}`; `{"error"}` with no outline or no `seen` |
| `bw_text_room` | `{"box": [left, top, right, bottom]}`: where a text of Larry's, or anything landing, is set | a reply: `{"sits", "y", "cut", "dy"}`: whether it overlaps what shows, where its top lands, the clear line nearest its top and how far everything from there goes down (0 for none); `{"error"}` with no outline or no box |

- A stroke's `t` in the outline (`bw_outline_load`, `bw_outline_add`) is when it was made, unix ms: what tells ink
  newer than the picture. A stroke without one is taken as seen.

## The interface, version 9: lines that look like headers

Story 1267. The faint H the web board offers beside a line written big or underlined is the iPad's offer: the same
lines, for the same reasons, over the loaded outline. `bw_info` says `"abi": 9`; versions 1 to 8 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_candidates` | `{"declined"?: [name]}`: strokes of lines Igor said were not headers | a reply: `{"candidates": [{"y", "top", "bottom", "left", "right", "why"}]}`, top down; `{"error"}` with no outline or a request that is not a JSON object |

- A line is offered when it is written well bigger than his usual lines (once there are four lines of his to judge
  by) or underlined across most of its width; `why` is `big` or `underline`, and `y` is the line's middle, where a
  margin tap makes it a header.
- A line already a header, or on a row holding one, is never offered; nor is one with a declined stroke on its row,
  nor writing that is not his (a kept text, a card, a group of Larry's).
- Asking changes nothing: the loaded outline stays as it was.

## The interface, version 10: what moves whole, and its rows

Story 1263. The boxes the web board cuts, pushes and folds around are the app's: what moves whole on the loaded
outline, by the app's rule for it, and the rows they make. `bw_info` says `"abi": 10`; versions 1 to 9 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_rows` | none | a reply: `{"units": [{"names", "tag", "header", "box"}], "rows": [{"top", "bottom"}]}`; `{"error"}` with no outline |

- A unit is what moves whole: a lone stroke, a kept text or card, a group of Larry's, or a header's row with
  everything folded under it. `names` are its strokes' and boxes' names in board order (a folded header's include what
  it hides); `tag` is its text, card, group or `h:<header>`, null for a lone stroke; `header` is its header's id, or
  null; `box` is `[left, top, right, bottom]`, what shows of it (a folded header's is its own row).
- Units come in board order; a hidden thing is only in the unit of the header that folded it, and one with nothing
  showing is not listed.
- Rows are the heights units take, top down, units that overlap merged: every height between two rows is a clear
  line, the boxes `bw_load` can be given.
- Asking changes nothing.

## The interface, version 11: opening a fold

Story 1264. Opening a folded header on the web board does what opening it does on the iPad: what was below slides
back down, by more whole lines if something was written under the folded header, the folded lines show again, and
the ink written under the header while it was folded ends its section from then on (story 1231), so the next fold
leaves it out. `bw_info` says `"abi": 11`; versions 1 to 10 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_opening` | `{"id"}`: a folded header | a reply: `{"opening": null}` when it is not folded, else `{"opening": {"top", "slide", "moves": {name: dy}, "shown": [name], "ends": [name] \| null}}`; `{"error"}` with no outline or no id |

- `top` is the bottom of the header's row and `slide` how far everything from there down went: the fold's shift, plus
  whole lines when the ink written under it would otherwise sit on the opened lines.
- `moves` names each stroke and box that slid and how far; `shown` the ones the fold hid that show again.
- `ends` is the header's list as it now is: what it had, and the ink written under it while folded that the opened
  section would otherwise take. Null when there is none.
- Asking changes nothing: the Cockpit opens the fold on its own board with the answer and loads the outline again.

## The interface, version 12: erasing a fold whole

Story 1265. An eraser across a folded header's "▸ N lines folded", or across the header's own words with a scratch-out,
takes the whole fold on the web board as it does on the iPad: the header, everything it hides and every fold folded
inside it go, and what was below closes up to where the header was, in whole lines. `bw_info` says `"abi": 12`;
versions 1 to 11 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_fold_erase` | `{"path": [[x, y]], "reach"?, "onHeader"?}`, or `{"headers": [id]}` | a reply: `{"hits": [{"header", "byMarker", "headers", "names", "top"}], "erased": null \| {"names", "headers", "moves": {name: dy}}}`; `{"error"}` with no outline, or with neither a path nor headers |

- With a path (board points), the folds it takes are the shown folds whose marker it passes within `reach` of (8 when
  left out), and with `onHeader` those whose header's words it passes over too (never by its underline or #). With
  `headers`, each named fold that is folded and shows is taken as if by its marker.
- Each hit names its header, whether it was by the marker, every header that goes with it (folds inside it), every
  stroke and box that goes, by name, and the top of its header's row.
- `erased` is what erasing all of them at once does: the names and headers gone, and how far each thing below moved
  up. Null when the path takes no fold.
- Asking changes nothing: the Cockpit erases on its own board with the answer and loads the outline again.

## The interface, version 13: units the web board can use as its own

Story 1263. Larry, 2026-11-23: the web board's own units have about fifteen callers, each needing a unit's key, its
strokes and its objects apart, and its edges exactly as the page worked them out, since a cut compares them exactly.
`bw_rows` now gives each unit those, so the page's own rule for units can go. `bw_info` says `"abi": 13`; versions 1
to 12 are unchanged but for `bw_rows`.

| Export | Arguments | Returns |
|---|---|---|
| `bw_rows` | none | a reply: `{"units": [{"key", "names", "strokeIds", "objectIds", "object", "tag", "header", "box"}], "rows": [{"top", "bottom"}]}`; `{"error"}` with no outline |

- `key` is `h:<header>` for a header's row, `o:<object>` for a kept text, a card or a group, and `s:<stroke>` for a
  lone stroke; it stays the same while the unit does.
- `strokeIds` are its ink, `objectIds` its kept texts and cards (a folded header's include the ones it hides) and the
  group that makes it one; `object` is the text, card or group, null for a header or a lone stroke.
- `box` and the rows are the page's own numbers: a stroke's edges are its points' extremes widened by half its pen
  and a box's are the numbers sent, worked out in 64 bits from what the page sent. Which units there are and what
  shows of each is still the rules' answer; on the web the rules' own geometry is 32-bit (Precision, below), so their
  boxes would come back a hair off the page's.

## The interface, version 14: keeping Larry's marks, and Tidy overlaps

Story 1163. Keep all and Tidy overlaps on the web board decide as the app does. Keep all keeps each reply of two or more
marks as one group, named as the app names it, and a lone mark on its own. It opens one room for everything kept: what
Igor wrote after a mark's own picture under that mark, and whatever a text of Larry's being kept sits on, goes down
whole lines until it is half a line under the lowest mark. The marks stay where they showed. Tidy overlaps moves each
kept label that sits on ink down under it, top to bottom, with half a line of air. The writing never moves. `bw_info`
says `"abi": 14`; versions 1 to 13 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_keep_all` | `{"marks": [{"id", "box": [left, top, right, bottom], "seen"?}], "landing"?: [box], "theirs"?: [ms]}`: each mark by its name (`<reply>#<n>`), its box with half its pen round it, and when its reply's picture was taken, unix ms; the boxes of Larry's texts kept with them; the times of ink Larry or Claude made | a reply: `{"groups": {mark: group}, "push": {"cut", "dy"} \| null, "covered"}`; `{"error"}` with no outline or a mark it can't read |
| `bw_tidy` | `{"labels": [name]}`: the kept labels, by their names in the outline | a reply: `{"moves": {name: dy}}`, only the labels that move; `{"error"}` with no outline or no labels |

- Both work over the outline `bw_outline_load` keeps, its strokes' `t` telling ink newer than a picture.
- A mark whose picture time is unknown makes no room of its own, but the room still reaches half a line under it.
- Ink made a millisecond either side of a time in `theirs` never makes room. A kept text or card never does either.
- A known difference: a kept text or card on the web board is a box with no time, so it never makes room as newer
  writing. On the iPad a text Igor pasted after a reply's picture is his and does make room under that reply's marks.
- Where the rules came from: the app keeps a mark by its keep-all grouping, the late-reply room for several replies and
  Tidy overlaps. The board's storage on disk and the check that a kept mark drew whole are not placement rules and have
  no export.
- Tidy takes everything that shows and is not a label as ink, a kept text or card over its whole box. What is hidden is
  neither. A label in one of Larry's groups stays with its group, as ink.
- Moving the web board onto these changes what it does: its Keep all no longer moves later marks down when an earlier
  one moved, and its Tidy no longer pushes the writing down. Both now do what the iPad does.

## The interface, version 15: a session's review

Story 1261. A writing session's record, in the form both surfaces write
([reviewing each writing session](2026-11-23-board-interaction-review-design.md)), reviewed by the same checks the iPad
runs, so the web board's findings are the iPad's verdict for verdict. Stateless: the loaded board and outline are
untouched. `bw_info` says `"abi": 15`; versions 1 to 14 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_review` | pointer, length of a record (JSONL: a header `{"record": 1, "board", "session", "surface", "build"?, "observes"?: {"selection", "pen", "kept"}, "ink": [{"id", "owner", "box": [x, y, w, h], "n"?, "header"?}], "folds"?: [{"header", "held", "folded"?}]}`, then one step per line `{"t", "kind", "by", "name"?, "aim"?: {"ids"?, "start"?}, "changes"?: [{"id", "owner"?, "before"?, "after"?, "n"?, "header"?, "hidden"?}], "room"?: {"cut", "dy"}, "fold"?, "seen"?: {"held_after"?, "pen_before"?, "pen_after"?, "kept"?: [{"shown", "expected", "ink_px"?, "dark_px"?}], "drawn_whole"?}}`) | a reply: `{"record", "board", "session", "surface", "build"?, "steps", "checks": [{"check", "name", "sight", "bug", "as_designed", "unclear"}], "findings": [{"check", "name", "verdict", "step", "t", "kind", "by", "story"?, "ids", "summary", "evidence": [[key, value]]}], "to_look_at"}`; `{"error"}` when the record can't be read |

- `observes` says what the surface saw for the three checks that need its eyes: `"yes"`, `"approx"` (the web board's
  pen in hand, *Larry's answer* in the review's spec), or absent; a check reads `checked`, `approximate` or
  `not_checked` as its `sight`.
- A change with neither `after` nor `hidden` removes the unit; one with `hidden` alone hides or shows it where it
  stands.
- Evidence numbers are printed to one decimal, so the 32-bit arithmetic below never changes a report's text.

## The interface, version 16: the board's revision and Larry's batches

Story 1164. The web board decides each batch of Larry's as the app decides it: applied now, held until the Pencil
lifts, refused, or ignored. It keeps the board's revision the same way. A batch made on an older look of the board still
applies, unless something Igor moved or erased since is named in it, or a batch of Larry's changed the board since.
A batch seen before is ignored, and so is one for another board. A second batch held for the Pencil replaces the first,
which is refused as superseded. Only the batch let through is reported once the board answers. A report for any other
batch, or a second report, counts for nothing. The module keeps the board's applier as it keeps the loaded board, and
the host steps it. `bw_info` says `"abi": 16`; versions 1 to 15 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_applier` | one step, `{"step", ...}`: `load` `{"rev", "since", "handled", "touches": [{"rev", "ids", "all"}], "last_result"}`; `changed` `{"ids", "all"}`; `receive` `{"key", "batch", "board", "editable", "ready"}`; `release` `{"ready"}`; `report` `{"key", "outcome": "applied" \| "unavailable" \| "failed", "reason", "changes_board", "missing_ids", "rooms"}`; `drop_held` `{"reason"}`; `closed` | a reply: what came of the step, and `"state"`: `{"rev", "since", "handled", "touches", "held", "applying", "last_result"}`; `{"error"}` for a step it can't read |

- `load` sets the applier as the board last kept it; with nothing given it is a fresh board's.
- `changed`: the ink changed. `ids` names what Igor moved, erased or broke a group of (none for new ink alone), with
  the groups and texts those belong to, as the app records a change; `all` marks a change made by a batch of Larry's.
- `receive` and `release` answer `"decision"`: `"apply"` (with the batch's `key`, `label` and `rebased_from`), `"held"`
  (with the `replaced` label), `"refused"` (with the `result` Larry hears, its `conflict_ids` when he named something
  moved since) or `"ignored"` (with `why`); null when nothing is held or the Pencil is still down.
- `report` answers `"applied"` or `"refused"` with the `result`, or `"late"`. A refused one also gives `canvas`:
  `unavailable` or `failed:<reason>`. A batch that changed the board counts as touching everything, so no batch from
  an earlier look applies over it. The host sends `changed` first, as the board's own change.
- What changed between two looks of the board is the host's to say. The app learns it from its own canvas, not by
  comparing pictures, so the web board's comparison of two looks stays its own.

## The interface, version 17: scratch-out and hold-to-shape

Story 1165. A fast zigzag over writing scratches it out on the web board as it does on the iPad. The strokes it touches
go, provided most of their ink lies under it. A zigzag that is slow, too small, or marches along as *mmm* does stays
ink. One over clear paper, or only beside ink, finds nothing. A stroke held still at its end snaps to the clean line,
rectangle or ellipse it nearly is, by the app's thresholds. `bw_info` says `"abi": 17`; versions 1 to 16 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_scratch_out` | `{"points": [[x, y]], "ms"?}`: the zigzag, not on the board, and how long it took | a reply: `{"ok", "gone": [name], "reversals", "speed", "why", "finds_nothing", "zigzag"}`; `{"error"}` with no outline or no points |
| `bw_shape_snap` | `{"points": [[x, y]], "times"?: [seconds], "lifted"?}`: a stroke, when each point came and when the Pencil lifted | a reply: `{"shape": {"kind": "line" \| "rect" \| "ellipse", "name", "points", "error"} \| null, "held"}`; `{"error"}` with no points |

- The scratch-out works over the outline `bw_outline_load` keeps: the ink that shows. Kept texts and cards are boxes
  and never go with it. `why` says why it stays ink (`short`, `small`, `few turns`, `short sweeps`, `marches along`,
  `slow`, `no ink`, `beside ink`, and for a scribble that wanders, `wanders, no ink` or `wanders, beside ink`).
  `finds_nothing` is true for a scratch-out in shape and speed that found nothing to take. The app removes that one
  with a word.
- `zigzag` is true for a zigzag in shape and fast enough whatever is under it: over a fold's marker, where there is
  no ink, the fold goes all the same, as on the iPad.
- On the web board a scratch-out used to take kept texts and cards too; with the app's rule it takes only ink.
- `speed` is board points per millisecond to two places, null without `ms`. Without `ms` it is not held to a speed.
- `held` is whether the Pencil last moved five points or more at least half a second before it lifted. It is null
  without times. The shape comes whether or not it was held; the host snaps only a held stroke.
- The web board's strike-through (a saw across a line of writing) and a scratch-out's tail (its last sweeps lifted as
  a stroke of their own) have no counterpart in the app's rules, so they stay the web board's own.

## The interface, version 18: groups Igor made

Story 1280. Igor, 2026-11-24 (bead context-grabber-xzmc): "only Larry's groups count as not your writing; my own grouped
strokes stay my writing." Until now the module read every group in the outline as Larry's, while the web board let Igor
group his own ink and read those groups as his writing: the one rule the two boards still differed on (story 1512).

- The outline may name the groups Igor made himself: `"mine": [group]`. Left out, every group is Larry's, as on the
  iPad, where only Larry groups.
- A group of Igor's still moves whole, everywhere a group does: its box, its row, its unit, a cut never splitting it.
- It is his writing: its strokes make lines of writing, a row's names include them (so a margin tap or *Make header*
  can make it a header), an underline under it or a # at its start makes it a header, ink written on its line joins
  that header's row, a long flat line in it can be a rule, and it can be offered as a line that looks like a header.
- Larry's groups, kept texts and cards are nobody's writing, as before.
- `bw_info` says `"abi": 18`. Every other export's arguments and answers are as in version 17.

## The interface, version 19: Larry's marks hold to the ink they answer

Story 1294 (Larry for the web board, 2026-11-24, cockpit-kp5). On the iPad an unkept mark of Larry's holds to the ink
it answers: it moves when that ink moves, hides while that ink is folded away or erased, and fades when Igor writes
over it; the next post takes the faded and orphaned ones away (stories 1180, 1181, 1269–1271). The web board asks the
app's own rule for each of those answers, so a mark behaves the same on both boards.

The web board keeps each mark's anchor, chosen once when the mark lands, and sends it back with every question. The
module remembers nothing of the marks. All answers are over the outline `bw_outline_load` keeps, as it is now.

| Export | Arguments | Returns |
|---|---|---|
| `bw_mark_anchor` | `{"mark": {"id", "lines": [[[x, y]]], "pen"?, "label"?}}`: a mark where it landed | a reply: `{"anchor": {"strokes": [{"name", "x", "y"}], "gap", "written_by": [name]}}` |
| `bw_mark_place` | `{"marks": [{"id", "anchor"?}]}` | a reply: `{"places": {id: {"dx", "dy", "hidden": null \| "folded" \| "erased", "faded", "drops": null \| "written_over" \| "ink_erased"}}}` |
| `bw_mark_wrote` | `{"stroke": {"id", "points", "width"}, "marks": [{"mark", "anchor"?}]}`: a stroke Igor just wrote | a reply: `{"anchors": {id: anchor}, "wrote": [{"id", "share"}]}` |
| `bw_mark_drops` | `{"marks": [{"id", "anchor"?}]}` | a reply: `{"drops": [{"id", "why": "written_over" \| "ink_erased"}]}` |

- The anchor is the unit the mark overlaps most, else the nearest unit above or beside it. It names up to eight of that
  unit's strokes, nearest first, then the rest of its line, each with where its box began; an empty list when the mark
  landed with nothing near. A label is written over inside its letters' box, a drawn mark along its line.
- A mark moves by as much as its first anchor stroke that still shows moved. It is hidden, `folded`, while all of its
  anchor's strokes are folded away, and `erased` once none is left on the board. A mark with no anchor stays where it
  landed.
- A stroke writes over a mark when at least a third of its path lies on it. `bw_mark_wrote` answers only the anchors it
  changed, each with the stroke's name added to `written_by`, and each mark written over with the share of the stroke
  on it, to two places. A hidden mark is never written over.
- A mark is faded while a stroke that wrote over it still shows, so undoing that stroke brings the mark back.
- `drops`: what a post now takes away and why, in the order the marks were sent: a faded mark that shows, and a mark
  whose ink is all erased.
- A mark, anchor or stroke the module can't read is a reply `{"error"}`, as is a question with no outline loaded.
- `bw_info` says `"abi": 19`. Every other export's arguments and answers are as in version 18.

## The interface, version 20: room by hand, and Larry's picture of a folded board

Stories 1295 and 1298 (Larry for the web board, 2026-11-24, cockpit-kp5). Two answers the web board still worked out in its own
JavaScript now come from the app's rules.

**Room by hand.** Dragging the left-margin handle opens room in whole lines at the clear line nearest where the drag
began. Dragging up closes room, but only blank paper, in whole lines: the push is rigid, so ink never closes onto ink
(Igor, 2026-11-22). The web board's own copy let blank paper absorb a push; with the app's rule it no longer does.

| Export | Arguments | Returns |
|---|---|---|
| `bw_room_by_hand` | `y`, `dy`: where the drag began, and how far, board points | a reply: `{"push": null \| {"cut", "dy"}, "cut", "closable"}`; `{"error"}` with no board loaded |

- `push` is what moves: everything below `cut` moves `dy`, a whole number of lines. It is null when nothing would move
  (a drag of under half a line, or closing where there is no blank paper).
- `cut` is the clear line the drag snaps to, whether or not anything moves, so the handle can show where it is.
- `closable` is how much blank paper can close at that line, in whole lines, so the handle can show the paper that
  will close before the drag ends (as the iPad does).
- It works over the board `bw_load` keeps, as `bw_cut_y` does.

**Larry's picture of a folded board.** The picture Larry sees draws every folded section in full, in place, as the
board would look with it open, shaded, with its header marked as folded; his marks on that picture map back onto the
folded board (stories 900, 1046).

| Export | Arguments | Returns |
|---|---|---|
| `bw_fold_picture` | none | a reply: `{"picture": null}` when no fold shows; else `{"picture": {"offsets": {name: [dx, dy]}, "shown": [name], "bands": [{"header", "top", "bottom"}], "map": [{"header", "y", "h"}], "folded_marks": [{"header", "y"}], "open_labels": [{"header", "text", "box": [left, top, right, bottom]}]}}`; `{"error"}` with no outline loaded |

- `offsets`: each stroke or box that moves in the opened picture, by name, and how far; `shown`: the ones a fold hid
  that the picture shows.
- `bands`: each opened section's stretch of the page in the picture, for its shading.
- `map`: the folds opened, in order, each as the place `y` from which the picture slid `h` further down. It is what goes
  with the picture as `picture_folds`, and the way a mark on the picture maps back to the folded board.
- `folded_marks`: where each folded header's marker goes; `open_labels`: the label each open header gets.
- It works over the outline `bw_outline_load` keeps, as it is now; it changes nothing.

`bw_info` says `"abi": 20`. Every other export's arguments and answers are as in version 19.

### Interface 21: To text in the hold menu, and a hold on the selection (stories 1309, 1310; #1386)

Igor, 2026-11-24: To text appears only in the long-press menu, never beside a selection. The hold menu's rules are
the shared core's, so the web board's long-press menu gets the row the same way.

- `bw_hold_menu` and `bw_hold_menu_on` offer `to-text` right after `select`: on a word of his, a group and a header's
  row. Not on a kept text, which is text already.
- New, `bw_hold_menu_on`, input `{"x", "y", "in_margin", "slop", "selected": [name]}`, the strokes selected now
  (`in_margin` a JSON bool or a number, nonzero true, as `bw_hold_menu`'s 0/1):
  held on a thing any of whose strokes are selected, the menu is about the whole selection, `on: "selection"`, with
  `to-text` (unless it is all one kept text) and `delete` and then the line's rows, and no `select`. Held anywhere
  else, or with nothing selected, it answers as `bw_hold_menu`. No `x` or `y` is a reply `{"error": "no x and y"}`.

`bw_info` says `"abi": 21`. Every other export's arguments and answers are as in version 20.

### Interface 22: the shared-board store's clash rule (stories 1293, 1322, 1323; t12b)

Igor, 2026-11-24: boards live in the Cockpit, and any of the iPad, the web board and the Mac draws on them (option C,
spec *Boards live in the Cockpit*). A device sends a batch of changes against the last revision it saw; the Cockpit
decides, per change, what lands. The rule is the shared core's, so the Cockpit's store and every device decide alike.

- New, `bw_store_clash`, input `{"board": {"rev", "things": {name: thing}, "deleted"?: thing}, "base_rev", "device",
  "by", "at", "ops": [op]}`, a thing being `{"rev", "device", "by", "at", "erased"?}`: who last changed it and when.
- The answer is `{"rev", "applied": [op index], "refused": [{"op", "id", "reason", "rev"?, "device"?, "by"?, "at"?}],
  "missing_ids": [name], "board"}`, the board after the batch in the same shape as the input's.
- New ink always lands, once per name: an add of a name the board already has, live or erased, is refused as `exists`,
  out loud. The pieces a partial erase leaves take new names.
- Undo and redo bring erased ink back under its own names with `restore`: it lands when nobody changed those names
  after the erase the device saw, and is refused as `changed` otherwise. A `restore` of something not erased is
  refused as `unknown`, and any other change to an erased thing as `changed`, even one erased earlier in the same
  batch. `replace` and removing an overlay take what they name off the board the way an erase does, so it comes back
  only by `restore` and its name stays taken.
- A change lands only when every name it touches was last changed at or before `base_rev`, or earlier in the same
  batch. Otherwise that change is refused as `changed`, naming the thing and who changed it and when; the rest of the
  batch still lands. One change over several things lands for all of them or none. A change to a name the board
  doesn't have is refused as `unknown`.
- Renaming the board and its paper are changes to the board itself, under the same rule.
- What each change names: new ink, text, cards, overlays and connectors are new things (a connector's two ends are only
  referred to, not changed); `replace` changes what it names and adds its new strokes; a selection is the device's own
  and neither lands nor is refused. A change that names nothing, such as moving everything below a line, can't be
  checked and is refused as `unknown`: the device sends the names it moves.
- A batch based on a revision the board hasn't reached (another board's, or a broken cache) lands nothing: every
  change is refused as `ahead`, with the board's revision, one that names nothing included.
- The answer also lists the `unknown` names as `missing_ids`, the way the Cockpit's batches name them today.
- Once the board is deleted, nothing lands on it, new ink included: every change is refused as `deleted`, with when and
  where it was deleted. That holds within a batch too: the changes after its `delete_board` are refused the same way.
- An accepted batch is one new revision; a batch where nothing landed leaves the revision as it was.
- Missing input says so: `{"error": "no board" | "no base_rev" | "no device" | "no ops"}`.

`bw_info` says `"abi": 22`. Every other export's arguments and answers are as in version 21.

### Interface 23: the store's first slice (stories 1326–1329; cockpit-8kh)

Igor, 2026-11-25: build the Cockpit's board store. Larry's spec for it (cockpit `board-store-spec`) was reviewed against
version 22 and every point accepted; this version settles the rule's side of those points before any store code.

- A **header** is a new thing with its own name that changes the strokes it heads, the way a group does: if its name
  is already on the board it is refused as `exists`, and its strokes are checked like any change.
- **A board is deleted however the store records it**: by the board's `deleted` field, or by the board's own entry
  (`@board`) being erased; either one refuses every later change as `deleted`, with when and where. The store keeps
  `deleted` as the truth and never erases `@board` (agreed with Larry, 2026-11-25), and `delete_board` still only
  marks the board deleted, so its name and paper stay for the list. Bringing a deleted board back is not a change any
  device makes: every change to a deleted board, `restore` included, is refused as `deleted`; undeleting is the
  Cockpit's own admin action.
- **A change over several things** names them all in one change (`set` with its names and their new contents, like a
  move), so it lands for all of them or none; a change naming one thing names it alone.
- **A change that also adds** (a group, a header, `replace`) lands what it can, and the answer now says, per change,
  exactly which names landed: `"landed": [{"op", "ids"}]`. The store applies name by name from that list, never from
  `applied` alone, so a group whose own name is refused as `exists` adds nothing new.
- **A malformed record is refused out loud**: a thing (or the board's `deleted`) without its revision or the device
  that changed it, or whose `erased` is neither true/false nor 1/0, answers `{"error": "malformed thing <name>"}`
  instead of being dropped, so an add of that name can't land a second time. A `deleted` of `null` is no delete.

- **One encoder for every device** (stories 1299, 1300): new, `bw_store_encode`, input `{"before": board, "after":
  board, "erased"?: {name: thing}}`, a board in the web board's own shape (`strokes`, `objects`, `headers`,
  `connectors`, and the board's `name`, `paper`, `lines`, `ruled`), `erased` the erased things the device still holds
  for undo. The answer is `{"ops": [op]}`, the storage ops that take the store from before to after, in an order the
  rule accepts within one batch:
  - brought back: `restore` of every erased name the after has again, then `set` for any of them that differs from
    what was erased;
  - taken off: one `erase` of every name the after lacks;
  - changed: one `set {ids, bodies}` of every name whose record differs, so a change of several things lands for all
    or none;
  - new: one `add_strokes` of the new strokes in draw order, then each new text (`add_text`), question card
    (`add_card`), other object (`overlay`), group (`group`), header (`header`) and connector (`connector`), its record
    as the op's fields;
  - the board: `rename` when the name changed, `paper` (with `lines` and `ruled`) when any of those did.
  A record goes up as the device holds it, every field included, the ones this build doesn't know too: a stroke the
  web drew keeps its pen data after an iPad move, and an iPad stroke keeps its texture seed after a web move. Fields
  of the board that the store doesn't keep (the pen, Larry's bookkeeping) are listed as `"ignored": [field]` rather
  than dropped silently. Missing input says so: `{"error": "no before" | "no after"}`.
- **One stroke record** both sides read: the shared fixture holds strokes with every field the web and the iPad
  write, and one this build doesn't know, and the encoder carries each through a move unchanged.

`bw_info` says `"abi": 23`. Every other export's arguments and answers are as in version 22.

## Precision: a known difference from the iPad

In WebAssembly the rules' arithmetic is 32-bit (the SDK has no 64-bit target), where the iPad's is 64-bit. Boxes
agree to about 1e-4 points. A decision differs only when a height sits
within about 1e-4 points of the exact middle of a row, where the rule breaks a tie between the row's top and bottom:
in the spike, 9 of about 4,600 queries on the recorded boards, 8 of them heights placed there on purpose and one from a
plain 1.5-point sweep (the title-build board at 100). The module answers as the 32-bit rules do; the replay test pins
that one case so a change shows. If it matters, the rules get their own 64-bit geometry, a change on the app's side.

### Boxes that only touch

On Apple's platforms two boxes that only share an edge or a corner do not meet; in the Foundation that Linux and
WebAssembly use, they do. The board's rules therefore decide whether boxes meet themselves, the way Apple does: an edge
or a corner shared is no overlap, any area is. Without that, a paste whose half line of air exactly touched a line of
writing landed elsewhere on the web than on the iPad (found by the Cockpit's comparison on its seeded random boards,
2026-11-22, and checked against Apple on the Mac).

## Acceptance criteria

- The board's rules build for WebAssembly, and the app, its tests and its Linux build are as before (the board's HTTP
  requests moved out of the board's module, the same calls from the same places).
- One command builds the module stripped and prints its size and checksum.
- Every recorded session replays through the module as the app's replay test expects: contract 1, no mismatch but
  ops-move's known one, each turn's hint the end of the recorded hint, the same turns.
- A board loaded whole, and the same board loaded in two halves (the second added as new ink), give the same clear
  line at every height tried; asked before any board is loaded, the answer is NaN with a reason.
