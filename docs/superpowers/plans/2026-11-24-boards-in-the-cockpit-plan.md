# Plan: boards in the Cockpit (t12b)

Companion to `docs/superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md`. The spec says what Igor sees; this
says what the Cockpit store holds and how the devices talk to it, at the level Larry needs to build the Cockpit side.
Proposed, not approved: it waits on Igor's A/B/C. Everything assumes **C** (any device draws; a change to something
changed since is refused out loud). B is noted where it differs.

## 1. What exists today (2026-11-24)

| | iPad (and Mac, iPhone read-only) | Web board (*/ink*) |
|---|---|---|
| Ink | a PencilKit `PKDrawing` blob per board (`WhiteboardStore`), plus a 480 px picture | `{board, folds, saved_at}` JSON per board (`board/ink_store.py`), board shape from `assets/ink/board.mjs`: `strokes: [{id, pts: [[x, y, pressure]], w, c, hid?}]`, `objects: [group / text / question]` |
| Meaning | `BoardMeaning` JSON beside the drawing: `rev`, handled batches, `touches`/`since`, kept `texts` (glyph strokes), `strokeIDs`, `strokeMeta`, `headers` + folds, `declined`, `questions`, `labels`, `theirs`, `inkBytes`/`inkPrint` | inside the board JSON (`objects`), plus `folds` |
| Identity | board: UUID. Stroke: its creation moment in ms (`BoardMoment`, `PKStrokePath.creationDate`), named through `strokeIDs` once moved or noted | board: its **name** (rename moves the file). Stroke: an `id` string |
| History | `rev` counts every change of the ink; Larry's op batches name `base_rev` and are refused on a clash (`BoardOpApplier`) | none: the whole file is saved, last write wins; a session log (`ink-logs/*.jsonl`) and audio sit beside it |
| Sync | CloudKit private DB, own boards up, every board down; only the drawing device draws | none; one server copy |

Larry (2026-11-24): build the store from the events/ops log, not from the ink JSON.

## 2. The store

SQLite in cockpit-data, WAL mode. Each batch's op rows and the board's rev bump commit in one transaction (the
memdeck ledger's pattern). A nightly JSONL dump of the op log is committed to igor2 (section 10).

- **Board**: `id` (UUID; web boards get one at migration, their name becomes a field), `name`, `paper`, `ruled`,
  `created_at`, `last_drawn_on` (`ipad` / `web` / `mac`; the iPhone only views), `rev` (integer, +1 per accepted
  batch), `deleted_at` (soft delete: never purged, kept in the nightly backup; Igor, 2026-11-24).
- **Op log** (the truth): append-only, one row per accepted op: `{rev, batch_id, device, by (igor|larry|claude), at,
  op}`. Refused ops are logged too, with the reason, for the debug page and for Larry.
- **Snapshot**: the board's state at a `rev`, rebuilt from the log and cached every N revs (say 50) and on demand.
  This is what a device downloads on first open.
- **Per-thing version**: for every stroke, object, header, card and reply id, the `rev` that last changed it
  (`changed_at_rev`). This is all the clash check needs.
- **Assets**: content-addressed by SHA-256 (`PUT /boards/assets/<sha>`): the version picture, pasted images, and the
  original PencilKit blob kept at migration (never shown, for lossless rollback).

## 3. Batches and the clash rule

A device sends a **batch**: the ops of one save, against the last `rev` it saw.

```
POST /boards/<id>/ops
{ "batch_id": "<uuid>", "device": "ipad-air-11", "by": "igor", "base_rev": 92,
  "ops": [ ... ], "picture": "<sha>"? }
→ 200 { "rev": 95, "applied": [0, 1, 3], "refused": [ { "op": 2, "id": "s-1795...", "reason": "moved",
         "by": "web", "rev": 94, "at": "..." } ] }
```

- **Idempotent by `batch_id`**: a resend returns the first answer.
- **Adds always land** (`add_strokes`, `add_text`, `add_card`, new group of new ids).
- **A change to an existing thing lands only if `changed_at_rev(id) <= base_rev`**. Otherwise that one op is refused
  with who changed it and when; the rest of the batch still applies (the spec's "everything else still goes up").
- **Ops on a deleted board are refused** (`reason: "deleted"`, with `deleted_at` and device): new ink does not
  override a delete.
- **Rename** is a change to the board's name field and follows the same rule.
- Each accepted batch is one new `rev`. The answer always carries the new `rev` so the device rebases its cache.
- *Under B instead*: no per-thing check; a batch with `base_rev < rev` replaces the board wholesale and the loser is
  saved as a copy board. Simpler server, but it loses the "named refusal" and the vision draft rejects it.

The device checks the same rule before sending (BoardCore already does this for Larry's batches), so a refusal is
rare and explained; the Cockpit's check is the authority. The Cockpit's check is a per-id integer comparison, so it
can live in Python without the wasm; the op *meaning* (what a move does to a stroke) only needs to be applied on
snapshot rebuild, which can reuse BoardCore through the wasm the web board already loads.

## 4. Ops

Start from Larry's existing op batch format (fixtures in `native/ContextCore/Tests/ContextCoreTests/Fixtures/board-ops/`:
`add_strokes`, `add_text`, `delete`, `replace`, `set_hidden`, `set_meta`, `asked_below_y`, `asked_dy`) and add what
Igor's own hand does, which today exists only as a whole-drawing save on the iPad and a whole-board save on the web:

| Op | Targets | Notes |
|---|---|---|
| `add_strokes` | new stroke ids | full stroke records (section 5) |
| `move` | ids + `dx, dy` (or a transform) | strokes, objects, cards; Larry's room-making is a `move` too (abi 20 `bw_room_by_hand`) |
| `erase` | ids | whole strokes; a partial erase is `erase` + `add_strokes` of the surviving pieces |
| `restyle` | ids + `color` / `width` / `ink` | |
| `group` / `ungroup` | group id + ids, `owner: igor | larry` | `owner` drives abi 18's `mine` rule (Igor's groups stay his writing) |
| `reply` | reply id + its marks (ghosts) | one reply of 2+ marks is one ghost group (#1383/#1395); each mark carries its anchor (abi 19 mark holds: what it answers, its place) |
| `keep` / `dismiss` | reply id, optional mark index | Keep group keeps the whole reply; a kept reply becomes Larry's kept ink with `theirs` set |
| `mark_wrote` | mark id | Igor wrote over it, so it fades (abi 19 `bw_mark_wrote`) |
| `header` / `not_header` | stroke ids | headers and Igor's "not a header" |
| `fold` / `unfold` | header id | the folded ids and shift are derived (abi 20 `bw_fold_picture`) |
| `add_card` / `card` | card id + `{ask, answer?, x, y, show: full|short|collapsed|archived}` | question cards (#1387: `?` and collapsed are one state; double tap cycles) |
| `rename`, `paper` | board | |
| `delete_board` | board | tombstone |

What does **not** go to the store: undo steps (local), the lettering style, the Pencil tool, the device's board-review
recording (#1379, local; its findings already go to Larry with the turn), and the session log.

## 5. The stroke record, and what PencilKit can round-trip

One stroke record both sides read; the web's current fields are a subset, so */ink* keeps working by ignoring the
rest:

```
{ "id": "s-<ms>[-n]", "pts": [[x, y, pressure, t_ms, azimuth?, altitude?, size?]], "w": 2.5, "c": "#1a1a1a",
  "ink": "pen|pencil|marker|monoline|fountainPen|watercolor|crayon", "seed"?: 123, "xf"?: [a,b,c,d,tx,ty],
  "hid"?: true, "made_at": "<iso>" }
```

| PencilKit data | Round-trips? | How |
|---|---|---|
| Point x, y, force, timeOffset, azimuth, altitude, size | **yes** | per point in `pts` |
| Ink type, colour, base width | **yes**, for known types | `ink`, `c`, `w`. An ink type this build doesn't know must be kept as a string and drawn as `pen`, never force-unwrapped: `PKInk.inkType` traps on an unknown kind (#1083). |
| Pencil texture (`randomSeed`) | **yes** | `seed`, so a pencil stroke looks identical after a reload |
| Transform | **yes** | `xf`, or baked into points on upload (simpler; loses nothing visible) |
| Mask (pixel-eraser holes) | **no**, not faithfully | the device bakes a masked stroke into its visible pieces (`erase` + `add_strokes`) before upload; the original blob asset keeps the exact masked version |
| Stroke identity | **yes** | the creation moment the iPad already keys by (`BoardMoment`), as the stroke id |
| PaperKit shapes, text boxes, images (non-stroke markup) | **not today** | the iPad saves only the PencilKit drawing and the meaning; PaperKit's own markup elements are flattened or not kept. Store images as assets via an image object when that lands; to check before migration: does any board hold PaperKit markup that isn't in the drawing? |
| Kept text | **yes, in two forms** | a text object (`{id, kind: text, text, x, y, w, font}`, what the web draws) linked to its glyph stroke ids (what the iPad draws). Today the iPad keeps glyphs, the web keeps the text: the store keeps both and each side draws the one it can. |

The web's `pressure`-only points widen to the full tuple; a web stroke uploaded with only `[x, y, p]` is drawn on the
iPad with default azimuth and altitude and `t` spaced by the stroke's duration.

## 6. Reading

```
GET  /boards?since=<cursor>        → { boards: [{id, name, rev, last_drawn_on, picture, deleted_at?}], cursor }
GET  /boards/<id>                  → snapshot at the latest rev: { rev, board, strokes, objects, headers, cards, replies, ... }
GET  /boards/<id>/ops?since=<rev>  → the accepted ops after <rev>, for a cache that's close
GET  /boards/assets/<sha>
POST /boards                       → create { id, name, paper } (id made on the device, so offline creates work)
DELETE /boards/<id>                → tombstone
```

The listing is small enough to call on every list open. Sign-in is the chat's; reachable wherever the chat is.

## 7. The device cache

- A snapshot per board at its last-seen `rev`, plus a queue of unsent batches (oldest first), on disk.
- Opening a board shows the snapshot with the queue applied. Online, the device pulls `ops?since=rev`, rebases its
  queue on them, then sends.
- A refused op is shown as the spec's copyable note and dropped from the queue; the rest stays.
- Undo works on the local history only; an undo after sync is a new change and can itself be refused.

## 8. Migration

- **iPad (and any device with boards it drew)**: per board, decode the drawing, write the board as one `POST /boards`
  plus one batch of `add_strokes` and meaning ops at `base_rev: 0`, the picture and the **original drawing blob** as
  assets. Skip a board the Cockpit already has at the same or newer rev.
- **Web boards**: a one-off Cockpit job turns each `{board, folds}` JSON into a board with a new id and one batch; its
  name stays and the old `/ink` link redirects by name.
- Boards whose device is gone: after a week with no upload from the owner, the newest copy any device holds goes up.
- Check at the end: per board, the stroke count and the picture match the source; the debug page lists any that
  don't.

## 9. Work split

**Cockpit (Larry):** the store (section 2), the batch endpoint and clash check (3), reads (6), assets, the debug page
(per board: revs, refused ops, migration status), web board on the store (ids, the new ops instead of whole-board
saves, the wider stroke record), the web-board migration job, backups.

**App:** the stroke record and op encoders in BoardCore (host-tested, shared as wasm so */ink* encodes the same way),
the cache and queue, the list from the Cockpit, the copyable refusal notes, the iCloud-to-Cockpit migration, the
rollout setting, then removing iCloud board sync.

## 10. The Cockpit side's answers (Larry, 2026-11-24, msg 9fadc8d25f07)

1. **Store medium:** SQLite in cockpit-data, WAL mode. The op append and the rev bump happen in one transaction, the
   way the memdeck ledger already works.
2. **Backups:** none today; the web's ink JSONs in cockpit-data are untracked. Plan a nightly JSONL dump of the op
   log committed to igor2, like memdeck-ledger-backup. Restore replays the log to any rev. This is a precondition of
   rollout step 3: the Cockpit is about to become the only server copy.
3. **Names to ids:** yes. */ink* moves to ids, with each old name redirecting to its board.
4. **Writes that skip `base_rev`:** one. The web's whole-board save has no `base_rev`, so the last write wins.
   Larry's ops path (strokes, turns, marks) already checks it. That save is replaced by batches (section 3) when
   */ink* moves onto the store; until then it must not write to a board the store holds.
5. **Sizes:** the biggest web board is 1.5 MB with 1,288 strokes, the biggest iPad stroke export is 1.36 MB, and the
   biggest events log is 150 KB. Whole-board snapshots stay small enough to cache every board on every device and to
   send on first open. A snapshot every 50 revs is plenty.
6. **Assets:** chat attachments live at cockpit-data/attachments/<date>/<hash>.ext, capped at 100 MB as of today.
   Board assets (pictures, pasted images, the migration's original drawing blob) use the same content-addressed scheme
   and cap. **Still open:** where the web board's pasted images live today. Check that before migrating web boards.
7. **Snapshot rebuild:** a lean, not settled. The Cockpit rebuilds snapshots by running BoardCore's wasm under node,
   so the devices stay thin and send only batches. The fallback, if node and the wasm prove awkward server-side, is
   the device uploading its snapshot with each batch for the Cockpit to keep.

**Igor's picks, all made 2026-11-24:** C (any drawing device; clashes refused and named); the iPhone only views;
ink refused for a deleted board offers *Keep my ink as a new board*; deleted boards are kept forever. The Cockpit
refuses a change batch from an iPhone. Larry: "Go ahead and start the build per your v2 plan"; he builds the store
once the endpoint shapes here are confirmed.
