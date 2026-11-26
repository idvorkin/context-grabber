"""The fake Cockpit's board store routes (Larry's store spec, cockpit 2bf00b04, section 3; kept to the real store on
cockpit branch board-store-s1 a925f69, board/store.py, by Larry's diff, msg d4af53f5b79d; plan
2026-11-24-boards-in-the-cockpit-plan.md section 7a; stories 1330-1334): what a device's cache and queue talk to.

GET /boards[?deleted=1], GET /boards/<id>, GET /boards/<id>/ops?since=<rev>, POST /boards, POST /boards/<id>/ops.

It keeps the wire as the store has it, not the clash rule: the door's checks and their words (400 naming the field or
the op, 403 look_only for an iphone, 404 no such board), batch_id idempotent per board (the same body replays its
answer, a different one is a 409 batch_id_reused), a base ahead of the board refused per id, `landed` naming each op's
landed ids, the store's kinds, and ops?since with every landed id's body after. Otherwise every op lands: the rule is
BoardStoreClash's, which the device runs itself and the real store runs through the wasm. A test arms the rest:

  POST /fake/store-next {"refused": [{op, id, reason, rev?, device?, by?, at?}]} or {"status": 503} (the rule's worker
       down, which lands nothing): the next batch only
  POST /fake/store-remote {"board", "device", "by", "kind"?, "ops": [{op, ids, bodies}]}: another device's batch lands
  GET  /fake/store: every batch posted, in order, and each board's rev
"""

import hashlib
import json
import re
import threading
from datetime import datetime, timezone

LOCK = threading.Lock()
BOARDS = {}  # id -> {"name", "rev", "things": {id: thing}, "order": [id], "deleted", "log": [batch], "changed_at"}
ANSWERS = {}  # (board, batch_id) -> (sha of the body, answer)
POSTS = []  # every POST /boards/<id>/ops body, in order
ASSETS = {}  # sha -> bytes, from PUT /boards/assets/<sha> (story 1361: the original drawing)
NEXT = None  # what /fake/store-next armed: once

BOARD = "@board"
BOARD_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,200}$")
BATCH_ID_RE = re.compile(r"^[A-Za-z0-9_.:-]{1,200}$")
DEVICE_RE = re.compile(r"^(web|ipad|mac|iphone|cockpit)-[a-z0-9-]{1,40}$")
BY = ("igor", "larry", "claude")
MAX_OPS = 2000
# The store's storage ops and the kind each add makes (store.py ADDS_OWN_ID, GROUPING); a `reply` waits for slice 17.
OWN_ID = {"add_text": "object", "add_card": "object", "overlay": "object", "connector": "connector"}
GROUPING = {"group": "object", "header": "header"}
ERASING = ("erase", "remove_overlay", "replace")
OPS = {"add_strokes", "set", "erase", "remove_overlay", "replace", "restore", "select", "rename", "paper",
       "delete_board"} | set(OWN_ID) | set(GROUPING)


def now():
    return datetime.now(timezone.utc).isoformat()


def bad_id(x):
    if not isinstance(x, str) or not x:
        return "an id must be a non-empty string"
    if len(x) > 200:
        return "an id is at most 200 characters"
    if x == BOARD:
        return "%s is changed by rename, paper and delete_board only" % BOARD
    if any(ch < " " or ch == "\x7f" for ch in x):
        return "an id has no control characters"
    return None


def bad_ids(xs, empty_ok=False):
    if not isinstance(xs, list) or (not xs and not empty_ok):
        return "ids must be a non-empty list"
    why = next((w for w in map(bad_id, xs) if w), None)
    return why or ("ids repeat" if len(set(xs)) != len(xs) else None)


def bad_strokes(strokes, empty_ok=False):
    if not isinstance(strokes, list) or (not strokes and not empty_ok):
        return "strokes must be a non-empty list"
    if not all(isinstance(s, dict) for s in strokes):
        return "each stroke must be an object"
    return bad_ids([s.get("id") for s in strokes], empty_ok=True)


def bad_op(op):
    """Why `op` isn't a storage op the store takes (store.py _bad_op), or None."""
    if not isinstance(op, dict):
        return "an op must be an object"
    kind = op.get("op")
    if kind not in OPS:
        return "unknown op %r: the store takes %s" % (kind, ", ".join(sorted(OPS)))
    if kind == "add_strokes":
        return bad_strokes(op.get("strokes"))
    if kind in OWN_ID or kind == "remove_overlay":
        return bad_id(op.get("id"))
    if kind in GROUPING:
        return bad_id(op.get("id")) or bad_ids(op.get("ids"), empty_ok=True)
    if kind == "set":
        ids, bodies = op.get("ids"), op.get("bodies")
        why = bad_ids(ids)
        if why:
            return why
        if not isinstance(bodies, dict) or set(bodies) != set(ids):
            return "bodies must give a body for every id in ids, and no other"
        for i in ids:
            if bodies[i] is None:
                return "the body of %s is null: erase it instead" % i
            if isinstance(bodies[i], dict) and bodies[i].get("id", i) != i:
                return "the body of %s carries another id" % i
        return None
    if kind in ("erase", "restore"):
        return bad_ids(op.get("ids"))
    if kind == "replace":
        why = bad_ids(op.get("ids")) or bad_strokes(op.get("strokes"), empty_ok=True)
        if why:
            return why
        if set(op["ids"]) & {s["id"] for s in op["strokes"]}:
            return "replace adds new ids, never the ones it takes away"
        return None
    if kind == "rename":
        return None if isinstance(op.get("name"), str) and op["name"].strip() else "name must be a non-empty string"
    if kind == "paper":
        return None if "paper" in op else "paper needs `paper` (and `lines`, `ruled` if any)"
    return None  # delete_board, select


def check_batch(body):
    """(status, answer) for a batch refused at the door (store.py _check_batch), or None."""
    if not isinstance(body, dict):
        return 400, {"ok": False, "error": "body must be an object"}
    if not isinstance(body.get("batch_id"), str) or not BATCH_ID_RE.fullmatch(body["batch_id"]):
        return 400, {"ok": False, "error": "batch_id must match [A-Za-z0-9_.:-]{1,200}"}
    device = body.get("device")
    if not isinstance(device, str) or not DEVICE_RE.fullmatch(device):
        return 400, {"ok": False, "error": "device must be <class>-<slug>"}
    if device.startswith("iphone-"):
        return 403, {"ok": False, "error": "look_only"}
    if body.get("by") not in BY:
        return 400, {"ok": False, "error": "by must be one of igor, larry, claude"}
    base = body.get("base_rev")
    if not isinstance(base, int) or isinstance(base, bool) or base < 0:
        return 400, {"ok": False, "error": "base_rev must be an integer >= 0"}
    at = body.get("device_at")
    if at is not None and (not isinstance(at, str) or len(at) > 64):
        return 400, {"ok": False, "error": "device_at must be a timestamp string"}
    ops = body.get("ops")
    if not isinstance(ops, list):
        return 400, {"ok": False, "error": "ops must be a list"}
    if len(ops) > MAX_OPS:
        return 413, {"ok": False, "error": "at most %d ops a batch" % MAX_OPS}
    for i, op in enumerate(ops):
        why = bad_op(op)
        if why:
            return 400, {"ok": False, "error": "op %d: %s" % (i, why), "op": i}
    return None


def named(op):
    """(adds, changes) as the rule reads them (BoardStoreClash.Op)."""
    kind, id_, ids = op.get("op"), op.get("id"), op.get("ids") or []
    strokes = [s["id"] for s in op.get("strokes") or []]
    own = [id_] if isinstance(id_, str) else []
    if kind == "add_strokes":
        return strokes, []
    if kind in OWN_ID:
        return own, []
    if kind == "replace":
        return strokes, ids
    if kind in GROUPING:
        return own, ids
    if kind in ("rename", "paper", "delete_board"):
        return [], [BOARD]
    if kind == "select":
        return [], []
    return [], ids or own


def added(op, tid):
    """(kind, body) when `tid` is a thing `op` adds (store.py _added), else None."""
    kind = op["op"]
    if kind in ("add_strokes", "replace"):
        return next((("stroke", s) for s in op.get("strokes") or () if s.get("id") == tid), None)
    if (kind in OWN_ID or kind in GROUPING) and op.get("id") == tid:
        return OWN_ID.get(kind) or GROUPING[kind], {k: v for k, v in op.items() if k != "op"}
    return None


def already(board, ops, refused):
    """Adds of ids the board already holds, refused `exists` as the real store does (cockpit 12e08d4): the clash rule
    is the device's, but an id is added once, so a second add lands nothing and the rev stays. Skips what `refused`
    already names."""
    named_already = {(r.get("op"), r.get("id")) for r in refused}
    out = []
    for index, op in enumerate(ops):
        for tid in named(op)[0]:
            if tid in board["things"] and (index, tid) not in named_already:
                thing = board["things"][tid]
                out.append({"op": index, "id": tid, "reason": "exists", **stamp(thing["rev"], thing)})
    return out


def stamp(rev, who):
    return {"rev": rev, "device": who["device"], "by": who["by"], "at": who["at"]}


def land(board, op, ids, rev, who):
    """The op's landed ids applied to the board; gives ops?since's {op, ids, bodies}."""
    things, bodies = board["things"], {}
    for tid in ids:
        new = added(op, tid)
        old = things.get(tid)
        if new:
            if old is None:
                board["order"].append(tid)
            things[tid] = {"kind": (old or {}).get("kind") or new[0], "body": new[1], "erased": False,
                           **stamp(rev, who)}
        elif old is None:
            continue
        elif op["op"] in ERASING:
            things[tid] = {**old, "erased": True, **stamp(rev, who)}
        elif op["op"] == "restore":
            things[tid] = {**old, "erased": False, **stamp(rev, who)}
        elif op["op"] == "set":
            things[tid] = {**old, "body": op["bodies"][tid], **stamp(rev, who)}
        elif tid == BOARD and op["op"] in ("rename", "paper"):
            body = dict(old["body"]) if isinstance(old["body"], dict) else {}
            body.update({k: v for k, v in op.items() if k != "op"})
            things[tid] = {**old, "body": body, **stamp(rev, who)}
            board["name"] = body.get("name", board["name"])
        else:
            things[tid] = {**old, **stamp(rev, who)}
            if op["op"] == "delete_board":
                board["deleted"] = stamp(rev, who)
        bodies[tid] = None if things[tid]["erased"] else things[tid]["body"]
    return {"op": op["op"], "ids": list(bodies), "bodies": bodies}


def commit(board, ops, refused, who, batch_id, kind="ops"):
    """One batch at the board's next rev, per id from `refused`: an op with a refusal that isn't `exists` lands
    nothing; otherwise its adds land minus those refused `exists`, and its changes land. Gives (rev, applied, landed);
    nothing changes when nothing landed."""
    rev = board["rev"] + 1
    applied, landed, log = [], [], []
    for index, op in enumerate(ops):
        mine = [r for r in refused if r.get("op") == index]
        if op.get("op") == "select" or any(r.get("reason") != "exists" for r in mine):
            continue
        exists = {r.get("id") for r in mine}
        adds, changes = named(op)
        ids = [i for i in adds if i not in exists] + [i for i in changes if i in board["things"]]
        if not ids:
            continue
        applied.append(index)
        landed.append({"op": index, "ids": ids})
        log.append(land(board, op, ids, rev, who))
    if not applied:
        return board["rev"], [], []
    board["rev"], board["changed_at"] = rev, who["at"]
    board["log"].append({"rev": rev, "batch_id": batch_id, "kind": kind, **who, "ops": log})
    return rev, applied, landed


def snapshot(id_, board):
    live = [i for i in board["order"] if not board["things"][i]["erased"]]
    out = {"id": id_, "name": board["name"], "rev": board["rev"], "contract": 2,
           "things": [{"id": i, "kind": board["things"][i]["kind"], "ord": n, "body": board["things"][i]["body"],
                       **stamp(board["things"][i]["rev"], board["things"][i])} for n, i in enumerate(live)],
           "erased": [i for i in board["order"] if board["things"][i]["erased"]]}
    if board["deleted"]:
        out["deleted"] = board["deleted"]
    return out


def get(path, query):
    """GET's (status, answer), or None when the path isn't the store's."""
    with LOCK:
        if path == "/fake/store":
            return 200, {"ok": True, "posts": POSTS, "revs": {i: b["rev"] for i, b in BOARDS.items()},
                         "assets": {k: len(v) for k, v in ASSETS.items()}}
        if path == "/boards":
            show_deleted = (query.get("deleted") or [""])[0] == "1"
            rows = sorted(BOARDS.items(), key=lambda item: item[1]["changed_at"], reverse=True)
            return 200, {"boards": [{"id": i, "name": b["name"], "rev": b["rev"], "last_drawn_on": None,
                                     "picture": None, **({"deleted": b["deleted"]} if b["deleted"] else {})}
                                    for i, b in rows if show_deleted or not b["deleted"]], "contract": 2}
        if not path.startswith("/boards/"):
            return None
        parts = path[len("/boards/"):].split("/")
        if parts[1:] not in ([], ["ops"]) or not parts[0] or parts[0] == "assets":
            return None
        board = BOARDS.get(parts[0])
        if parts[1:] == ["ops"]:
            since = (query.get("since") or [""])[0]
            if not since.isdigit():
                return 400, {"ok": False, "error": "since must be a revision, an integer >= 0"}
            if board is None:
                return 404, {"ok": False, "error": "no such board"}
            return 200, {"rev": board["rev"], "batches": [b for b in board["log"] if b["rev"] > int(since)]}
        if board is None:
            return 404, {"ok": False, "error": "no such board"}
        return 200, snapshot(parts[0], board)


def create(data):
    id_, name = data.get("id"), data.get("name")
    if not isinstance(id_, str) or not BOARD_ID_RE.fullmatch(id_):
        return 400, {"ok": False, "error": "id must match [A-Za-z0-9_-]{1,200}"}
    if id_ == "assets":
        return 400, {"ok": False, "error": "id 'assets' is reserved"}
    if not isinstance(name, str) or not name.strip():
        return 400, {"ok": False, "error": "name must be a non-empty string"}
    device = data.get("device", "cockpit-create")
    if not isinstance(device, str) or not DEVICE_RE.fullmatch(device):
        return 400, {"ok": False, "error": "device must be <class>-<slug>"}
    if device.startswith("iphone-"):
        return 403, {"ok": False, "error": "look_only"}
    by = data.get("by", "igor")
    if by not in BY:
        return 400, {"ok": False, "error": "by must be one of igor, larry, claude"}
    created = id_ not in BOARDS
    if created:
        who = {"device": device, "by": by, "at": now()}
        body = {"name": name.strip(), **{k: data[k] for k in ("paper", "lines", "ruled", "original_asset") if k in data},
                "v": 1}
        BOARDS[id_] = {"name": name.strip(), "rev": 0, "order": [BOARD], "deleted": None, "log": [],
                       "changed_at": who["at"], "things": {BOARD: {"kind": "board", "body": body, "erased": False,
                                                                   **stamp(0, who)}}}
    board = BOARDS[id_]
    return 200, {"ok": True, "id": id_, "name": board["name"], "rev": board["rev"], "created": created, "contract": 2}


def remote(data):
    """Another device's batch, given as ops?since gives it: each id with its body after (null: erased)."""
    board = BOARDS.get(data.get("board"))
    if board is None:
        return 404, {"ok": False, "error": "no such board"}
    who = {"device": data.get("device", "web-3f9a"), "by": data.get("by", "igor"), "at": now()}
    rev, landed = board["rev"] + 1, []
    for o in data.get("ops") or []:
        if not isinstance(o, dict):
            return 400, {"ok": False, "error": "malformed op"}
        bodies = o.get("bodies") if isinstance(o.get("bodies"), dict) else {}
        if o.get("op") == "delete_board":
            board["deleted"] = stamp(rev, who)
        for tid in [i for i in o.get("ids") or [] if isinstance(i, str)]:
            old, body = board["things"].get(tid) or {}, bodies.get(tid)
            if tid not in board["things"]:
                board["order"].append(tid)
            board["things"][tid] = {"kind": old.get("kind") or o.get("kind") or "stroke", "erased": body is None,
                                    "body": old.get("body") if body is None else body, **stamp(rev, who)}
        landed.append({"op": o.get("op"), "ids": o.get("ids") or [], "bodies": bodies})
    board["rev"], board["changed_at"] = rev, who["at"]
    board["log"].append({"rev": rev, "batch_id": data.get("batch_id") or "remote-%d" % rev,
                         "kind": data.get("kind") or "ops", **who, "ops": landed if data.get("kind") != "admin" else []})
    return 200, {"ok": True, "rev": rev}


def post(path, data):
    """POST's (status, answer), or None when the path isn't the store's."""
    global NEXT
    with LOCK:
        if path == "/fake/store-next":
            NEXT = data
            return 200, {"ok": True}
        if path == "/fake/store-remote":
            return remote(data)
        if path == "/boards":
            return create(data)
        if not (path.startswith("/boards/") and path.endswith("/ops")):
            return None
        POSTS.append(data)
        door = check_batch(data)
        if door:
            return door
        board_id = path[len("/boards/"):-len("/ops")]
        board = BOARDS.get(board_id)
        if board is None:
            return 404, {"ok": False, "error": "no such board"}
        sha = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        key = (board_id, data["batch_id"])
        if key in ANSWERS:
            seen, answer = ANSWERS[key]
            if seen != sha:
                return 409, {"ok": False, "error": "batch_id_reused",
                             "detail": "this batch_id was sent before with a different body; a batch, once sent, "
                                       "is frozen"}
            return 200, {**answer, "replay": True}
        armed, NEXT = NEXT, None
        if armed and armed.get("status", 200) != 200:
            return armed["status"], {"ok": False, "error": "the board rules are not running: the worker did not answer"}
        ops, base = data["ops"], data["base_rev"]
        who = {"device": data["device"], "by": data["by"], "at": now()}
        if base > board["rev"]:
            refused = [{"op": i, "id": id_, "reason": "ahead", "rev": board["rev"]}
                       for i, op in enumerate(ops) if op.get("op") != "select"
                       for id_ in (sum(named(op), []) or [""])]
            rev, applied, landed = board["rev"], [], []
        else:
            refused = (armed or {}).get("refused") or []
            refused = refused + already(board, ops, refused)
            rev, applied, landed = commit(board, ops, refused, who, data["batch_id"])
        answer = {"ok": True, "contract": 2, "batch_id": data["batch_id"], "rev": rev, "applied": applied,
                  "refused": refused, "landed": landed, "replay": False,
                  "missing_ids": [r["id"] for r in refused if r.get("reason") == "unknown" and r.get("id")]}
        ANSWERS[key] = (sha, answer)
        return 200, answer


def put_asset(path, raw):
    """PUT /boards/assets/<sha>: the bytes kept by their sha (story 1361); a wrong sha is a 400."""
    sha = path[len("/boards/assets/"):]
    if hashlib.sha256(raw).hexdigest() != sha:
        return 400, {"ok": False, "error": "sha doesn't match the body"}
    with LOCK:
        ASSETS[sha] = raw
    return 200, {"ok": True, "sha": sha, "bytes": len(raw)}
