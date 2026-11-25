# Plan: boards in the Cockpit (t12b)

Companion to `docs/superpowers/specs/2026-11-22-boards-in-the-cockpit-design.md`. The spec says what Igor sees; this
says what the Cockpit store holds and how the devices talk to it, at the level Larry needs to build the Cockpit side.
Decided by Igor on 2026-11-24 (section 10): **C**, any drawing device draws, and a change to something changed since
is refused out loud.

## 1. What exists today (2026-11-24)

| | iPad (and Mac, iPhone read-only) | Web board (*/ink*) |
|---|---|---|
| Ink | a PencilKit `PKDrawing` blob per board (`WhiteboardStore`), plus a 480 px picture | `{board, folds, saved_at}` JSON per board (`board/ink_store.py`), board shape from `assets/ink/board.mjs`: `strokes: [{id, pts: [[x, y, pressure]], w, c, hid?}]`, `objects: [group / text / question]` |
| Meaning | `BoardMeaning` JSON beside the drawing: `rev`, handled batches, `touches`/`since`, kept `texts` (glyph strokes), `strokeIDs`, `strokeMeta`, `headers` + folds, `declined`, `questions`, `labels`, `theirs`, `inkBytes`/`inkPrint` | inside the board JSON (`objects`), plus `folds` |
| Identity | board: UUID. Stroke: its creation moment in ms (`BoardMoment`, `PKStrokePath.creationDate`), named through `strokeIDs` once moved or noted | board: its **name** (rename moves the file). Stroke: an `id` string |
| History | `rev` counts every change of the ink; Larry's op batches name `base_rev` and are refused on a clash (`BoardOpApplier`) | none: the whole file is saved, last write wins; a session log (`ink-logs/*.jsonl`) and audio sit beside it |
| Sync | CloudKit private DB, own boards up, every board down; only the drawing device draws | none; one server copy |

The rules already run in BoardCore on both sides, compiled to WebAssembly for the web board (ABI versions up to 20 on
2026-11-24); what isn't shared is the board.

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
→ 200 { "rev": 95, "applied": [0, 1, 3], "refused": [ { "op": 2, "id": "s-1795...", "reason": "changed",
         "device": "web", "by": "igor", "rev": 94, "at": "..." } ], "missing_ids": [] }
```

- **Idempotent by `batch_id`**: a resend returns the first answer.
- **Adds always land** (`add_strokes`, `add_text`, `add_card`, `overlay`, `connector`, a new group or reply of new
  ids), **once per id**: an add whose id the board already has (live or erased) is refused as `exists`, out loud, not
  reported as applied. Stroke ids are stable creation moments, so a stroke sent twice by any path is one stroke and a
  real collision stays visible. Re-added ink takes new ids: the pieces a partial erase leaves are `s-<ms>-n`.
- **Undo and redo restore** erased ink under its own ids with `restore`: it lands when the id is erased and nobody
  changed it after the erase the device saw (`changed_at_rev <= base_rev`), else `changed`. A `restore` of a live id
  is `unknown`, and any other change to an erased id is `changed`, in the same batch too. Erase, delete, `replace`
  (its `ids`) and `remove_overlay` leave a tombstone (the id stays taken), which the store must keep. Keep reusing a group id after an erase is a `restore` (or a new id).
- **A change to an existing thing lands only if `changed_at_rev(id) <= base_rev`**. Otherwise that one op is refused
  with who changed it and when; the rest of the batch still applies (the spec's "everything else still goes up").
- **Ops on a deleted board are refused** (`reason: "deleted"`, with `deleted_at` and device): new ink does not
  override a delete.
- **Rename**, **paper** and **delete_board** are changes to the board itself (`@board`) under the same rule; today
  they are Cockpit routes, and the store makes them ops.
- **What each op names** (Larry's question 4): `select` is the device's own and neither lands nor is refused; a
  connector's `from`/`to` are only referred to; `replace` changes its `ids` and adds its strokes; `remove_overlay`
  changes its id; every other op changes its `ids` (or `id`).
- **An op that names nothing** (`translate` by `below_y` alone) can't be checked and is refused as `unknown`: the sender
  resolves `below_y` to the ids it moves, against its base (Larry's question 2).
- **A change to a missing id** is refused per op as `unknown`, and the answer also lists those ids as `missing_ids`, as
  the Cockpit's batch contract does today (question 3).
- **A base ahead of the board** (`base_rev > rev`: another board's batch, or a broken cache) lands nothing: every op
  is refused as `ahead`, with the board's `rev` (question 5).
- One op over several ids lands for all of them or none. A whole-body write is `set {ids, bodies}`, never one `set`
  per id, so a move of three strokes is one op (interface 23, from the review of Larry's store spec, point 2).
- An op that both adds and changes (`group`, `header`, `replace`) lands per id: the answer's `landed: [{op, ids}]`
  names exactly the ids that landed, and the store applies from it, never from `applied` alone (point 3).
- A board is deleted by `board.deleted` or by `@board` erased. The store keeps `deleted` as the truth and never erases
  `@board`; `delete_board` sets `deleted` only. An undelete is a Cockpit admin action outside the rule (points 1, 7).
- A thing row without `rev` or `device` is an error, not dropped, so its id can't be added twice.
- Each accepted batch is one new `rev`. The answer always carries the new `rev` so the device rebases its cache.
- *B, rejected*: no per-thing check; a batch with `base_rev < rev` would replace the board wholesale and save the
  loser as a copy board. Simpler server, but it loses the named refusal, and Igor picked C.

The rule is built: `BoardStoreClash` in BoardCore and `bw_store_clash` (interface 22, stories 1293, 1322, 1323; the store's first slice in interface 23, stories 1326–1329). Today's
*/ink* can't adopt it as is (Larry, 2026-11-24): it saves whole boards, last write wins, with no per-thing revision,
device or tombstone, and its batch contract is all-or-nothing `stale`, so a per-op `refused[]` is a contract version
bump. It is the contract for the new store, a separate project Larry puts to Igor.

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
| `header` / `not_header` | header id + stroke ids | a header is a new thing with its own id that changes the strokes it heads, like a group (interface 23); `not_header` changes the strokes |
| `fold` / `unfold` | header id | the folded ids and shift are derived (abi 20 `bw_fold_picture`) |
| `add_card` / `card` | card id + `{ask, answer?, x, y, show: full|short|collapsed|archived}` | question cards (#1387: `?` and collapsed are one state; double tap cycles) |
| `rename`, `paper` | board | |
| `delete_board` | board | sets `deleted`; `@board` stays live, so the list keeps its name and paper |
| `set` | `ids` + `bodies` | a whole-body write of several things in one op (the store's v1 storage op) |

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
- A refused op is shown as the spec's copyable note and dropped from the queue; the rest stays. Ops refused as
  `deleted` are kept on disk, out of the queue, until Igor answers the problem: *Keep my ink as a new board* sends a
  `POST /boards` with a new id, the old name plus " (kept ink)" and the old paper, then one batch at `base_rev: 0` of
  the refused `add_strokes` and the meaning ops on those strokes; dismissing the problem discards them.
- Undo works on the local history only; an undo after sync is a new change and can itself be refused.

### 7a. The cache and queue as built (lane 70, 2026-11-25, to Larry's store spec 2bf00b04 sections 3 and 6)

`BoardStoreCache` in BoardCore, a value type the app persists (Codable) and drives; no network, no UI. Stories
1330-1334 and 1301.

- **State**: `rev` (the base: the last revision whose ops the cache has all seen), `things` (id → body, kind, rev,
  author, erased; an erased thing keeps its body so a local `restore` can bring it back), `deleted`, `queue` (batches,
  oldest first; only `queue[0]` may be frozen), `setAside` (ops refused `deleted`), `notes` (refusals to show),
  `needsPull`, `needsReload`.
- **Kinds** are the store's (cockpit `board-store-s1` a925f69): `stroke`, `object` (text, card, overlay, group),
  `header`, `connector`, `board`, so a copy built from ops matches one downloaded. The fake Cockpit's store routes
  follow that branch too (Larry's diff, msg d4af53f5b79d): `landed` in the answer, the door's checks and words,
  `ahead` per id, batch ids per board, a delete as `{rev, device, by, at}`, a worker failure as a 503.
- **Per id**: one function turns a storage op into the ids it lands with their bodies after (`add_strokes`' strokes,
  an add's or group's or header's own id with the op as its body, `set`'s `bodies`, `erase`/`remove_overlay`/`replace`'s
  ids to an erased tombstone, `restore` to the kept body, `rename`/`paper` to `@board`, `delete_board` to deleted).
  The same function shows the queue on top of the snapshot (`view`), folds in the device's own answered batch per id
  minus what `refused` names (spec 3: never per applied index), and the pulled `ops?since` batches use their own
  `{ids, bodies}` directly.
- **Freeze**: `freeze(batchID:)` gives `queue[0]` its id and `base_rev = rev` once; the app writes the cache to disk
  before the request leaves, so a kill mid-send retries the same body and id. A later batch's base is set only when it
  is frozen, after the earlier answer.
- **Answer**: `ok: false` keeps the batch frozen and queued. A 409 `batch_id_reused` is a copyable error, the batch
  stays. `ahead` sets `needsReload`. Otherwise the batch leaves the queue; refusals become notes; `deleted` ones go to
  `setAside`; `exists` on an add is re-added under `<id>-<slug>` as a new queued add (for a partly refused reply, only
  the refused parts, never an own id that already landed; its landed marks stay in the folded op). Caught up (applied
  non-empty and rev == base+1, or applied empty and rev == base): the batch folds in and `rev` moves; otherwise
  `needsPull`, and the batch's own landed ids come back in the pull, recognised by `batch_id`.
  A late answer (the copy's `rev` moved since the freeze, and the answer's rev is at or below it) folds nothing: the
  pull already brought that batch and anything over it (bead context-grabber-2m5r).
- **Pull**: `pull(rev:batches:)` applies each batch's bodies (an id new to the copy takes its kind from the op); an
  `admin` batch sets `needsReload`, and the check below then leaves the board's deleted state to the reload, so a
  delete Larry undid in the same pull refuses nothing; the pull's other changes still refuse what was queued over them
  (bead context-grabber-4v8k). The unsent queue runs through `BoardStoreClash.apply` as one batch at the **old** base,
  against things whose rev is the pulled rev when a foreign batch changed them and the old base otherwise (the
  device's own batches, the frozen one in flight included, don't clash with its own queue). The batch in flight goes
  first so later saves build on it, but its refusals are ignored and it is never rebuilt. Each refused op leaves the
  queue with a note, so the view shows the pulled body; then `rev` moves (never backwards).
- **Reload**: `reload(snapshot)` replaces things and rev, keeps the queue and set-aside ink, and runs the same rebase
  check at the reloaded rev against nothing changed, so only `deleted` and `exists` can refuse.
- **Keep my ink as a new board**: `keptInk(newID:)` gives the create body (old name + " (kept ink)", old paper) and the
  set-aside adds as one batch at base 0.

## 8. Migration

- **iPad (and any device with boards it drew)**: per board, decode the drawing, write the board as one `POST /boards`
  plus one batch of `add_strokes` and meaning ops at `base_rev: 0`, the picture and the **original drawing blob** as
  assets. `POST /boards` with an id the Cockpit already has is a no-op, and adds are once per id (section 3), so a
  rerun (next launch, after a partial run or a lost answer, or over strokes rollout step 2 already wrote) never adds a
  stroke twice. A board is done, and skipped from then on, once its migration batch has an answer. The iPad's local
  `rev` is never compared with the Cockpit's: one counts ink changes, the other accepted batches.
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
