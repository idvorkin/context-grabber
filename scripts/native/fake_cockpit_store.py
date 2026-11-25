"""The fake Cockpit's board store routes (Larry's store spec, cockpit 2bf00b04, section 3; plan
2026-11-24-boards-in-the-cockpit-plan.md section 7a; stories 1330-1334): what a device's cache and queue talk to.

GET /boards, GET /boards/<id>, GET /boards/<id>/ops?since=<rev>, POST /boards, POST /boards/<id>/ops.

It keeps the wire honest, not the clash rule: a batch is idempotent by batch_id (the same body replays its answer
with replay: true, a different body is a 409 batch_id_reused), an iphone device is refused at the door (403
look_only), an unknown board is a 404, a base ahead of the board refuses every op as ahead, and a landed batch is one
new rev whose landed ids, with their bodies after, come back from ops?since. Otherwise every op lands: the clash rule is
BoardStoreClash's, which the device runs itself and the real Cockpit runs through the wasm; a second copy here would be
a third. A test arms what the next batch's answer refuses instead:

  POST /fake/store-next {"refused": [{op, id, reason, rev?, device?, by?, at?}], "ok": false?, "status": n?}
  POST /fake/store-remote {"board", "device", "by", "ops": [{op, ids, bodies}]}: another device's batch lands
  GET  /fake/store: every batch posted, in order, and each board's rev
"""

import hashlib
import json
import threading
from datetime import datetime, timezone

LOCK = threading.Lock()
BOARDS = {}  # id -> {"name", "paper", "rev", "things": {id: thing}, "order": [id], "deleted", "log": [batch]}
ANSWERS = {}  # batch_id -> (sha of the body, answer)
POSTS = []  # every POST /boards/<id>/ops body, in order
NEXT = None  # what /fake/store-next armed: once

ADDING = {"add_strokes", "add_text", "add_card", "overlay", "connector", "reply"}
ERASING = {"erase", "delete", "remove_overlay"}
KEEP, RESTORE, DELETE = object(), object(), object()  # what an id's body becomes when it isn't a new body or erased


def now():
    return datetime.now(timezone.utc).isoformat()


def thing(body, kind, rev, who, erased=False):
    return {"body": body, "kind": kind, "rev": rev, "device": who["device"], "by": who["by"], "at": who["at"],
            "erased": erased}


def landings(op, board):
    """Each id a storage op names, with its body after (None: erased; KEEP: the body stays), and whether it adds."""
    kind = op.get("op", "")
    body = {k: v for k, v in op.items() if k != "op"}
    ids = [i for i in op.get("ids") or [] if isinstance(i, str)]
    named = [(s["id"], s, True) for key in ("strokes", "marks") for s in op.get(key) or [] if isinstance(s, dict)
             and isinstance(s.get("id"), str)]
    own = [(op["id"], body, True)] if isinstance(op.get("id"), str) else []
    if kind == "add_strokes":
        return named
    if kind in ("add_text", "add_card", "overlay", "connector"):
        return own
    if kind == "reply":
        return own + named
    if kind in ("group", "header"):
        return own + [(i, KEEP, False) for i in ids]
    if kind == "set":
        bodies = op.get("bodies") if isinstance(op.get("bodies"), dict) else {}
        return [(i, bodies.get(i, KEEP), False) for i in ids]
    if kind == "replace":
        return [(i, None, False) for i in ids] + named
    if kind == "restore":
        return [(i, RESTORE, False) for i in ids]
    if kind in ("rename", "paper"):
        old = (board["things"].get("@board") or {}).get("body")
        return [("@board", {**(old if isinstance(old, dict) else {}), **body}, False)]
    if kind == "delete_board":
        return [("@board", DELETE, False)]
    if kind == "select":
        return []
    changed = ids or ([op["id"]] if isinstance(op.get("id"), str) else [])
    return [(i, None if kind in ERASING else KEEP, False) for i in changed]


def land(board, op, index, refused, rev, who):
    """The op's landed ids, per id from `refused` (store spec section 3): an op refused for anything but exists landed
    nothing; otherwise each add lands unless refused exists, each change lands. Gives ops?since's {op, ids, bodies}."""
    mine = [r for r in refused if r.get("op") == index]
    if any(r.get("reason") != "exists" for r in mine):
        return None
    exists = {r.get("id") for r in mine}
    ids, bodies = [], {}
    for id_, body, adds in landings(op, board):
        if adds and id_ in exists:
            continue
        old = board["things"].get(id_)
        if body is DELETE:
            board["deleted"] = {"rev": rev, **who}
            after = (old or {}).get("body")
        elif body is KEEP:
            if not old:
                continue
            after = old["body"]
            board["things"][id_] = {**old, "rev": rev, **who}
        elif body is RESTORE:
            if not old:
                continue
            after = old["body"]
            board["things"][id_] = {**old, "rev": rev, "erased": False, **who}
        elif body is None:
            after = None
            board["things"][id_] = thing((old or {}).get("body"), (old or {}).get("kind"), rev, who, erased=True)
        else:
            after = body
            if id_ not in board["things"]:
                board["order"].append(id_)
            kind = "stroke" if op.get("op") in ("add_strokes", "replace") else op.get("op", "").replace("add_", "")
            board["things"][id_] = thing(body, (old or {}).get("kind") or kind, rev, who)
            if id_ == "@board" and isinstance(body, dict):
                board["name"] = body.get("name", board["name"])
        ids.append(id_)
        bodies[id_] = after
    return {"op": op.get("op"), "ids": ids, "bodies": bodies}


def commit(board, ops, refused, who, batch_id, kind="ops"):
    """One batch at the board's next rev; nothing changes when nothing landed. Gives (rev, applied)."""
    rev = board["rev"] + 1
    landed, applied = [], []
    for index, op in enumerate(ops):
        if op.get("op") == "select":
            continue
        result = land(board, op, index, refused, rev, who)
        if result is not None and (result["ids"] or op.get("op") == "delete_board"):
            landed.append(result)
            applied.append(index)
    if not applied:
        return board["rev"], []
    board["rev"] = rev
    board["log"].append({"rev": rev, "batch_id": batch_id, "kind": kind, **who, "ops": landed})
    return rev, applied


def snapshot(id_, board):
    live = [i for i in board["order"] if not board["things"][i]["erased"]]
    out = {"id": id_, "name": board["name"], "rev": board["rev"], "contract": 2,
           "things": [{"id": i, "ord": n, **{k: v for k, v in board["things"][i].items() if k != "erased"}}
                      for n, i in enumerate(live)],
           "erased": [i for i in board["order"] if board["things"][i]["erased"]]}
    if board["deleted"]:
        out["deleted"] = board["deleted"]
    return out


def get(path, query):
    """GET's (status, answer), or None when the path isn't the store's."""
    with LOCK:
        if path == "/fake/store":
            return 200, {"ok": True, "posts": POSTS, "revs": {i: b["rev"] for i, b in BOARDS.items()}}
        if path == "/boards":
            show_deleted = (query.get("deleted") or [""])[0] == "1"
            rows = [{"id": i, "name": b["name"], "rev": b["rev"], "last_drawn_on": b.get("last_drawn_on"),
                     "picture": None, **({"deleted": True} if b["deleted"] else {})}
                    for i, b in BOARDS.items() if show_deleted or not b["deleted"]]
            return 200, {"boards": rows, "contract": 2}
        if not path.startswith("/boards/"):
            return None
        parts = path[len("/boards/"):].split("/")
        board = BOARDS.get(parts[0])
        if board is None:
            return 404, {"ok": False, "error": "unknown board"}
        if len(parts) == 1:
            return 200, snapshot(parts[0], board)
        if parts[1:] == ["ops"]:
            since = int((query.get("since") or ["0"])[0] or 0)
            return 200, {"rev": board["rev"], "batches": [b for b in board["log"] if b["rev"] > since]}
    return None


def post(path, data):
    """POST's (status, answer), or None when the path isn't the store's."""
    global NEXT
    with LOCK:
        if path == "/fake/store-next":
            NEXT = data
            return 200, {"ok": True}
        if path == "/fake/store-remote":
            board = BOARDS.get(data.get("board"))
            if board is None:
                return 404, {"ok": False, "error": "unknown board"}
            who = {"device": data.get("device", "web-3f9a"), "by": data.get("by", "igor"), "at": now()}
            rev = board["rev"] + 1
            landed = []
            for o in data.get("ops") or []:
                if not isinstance(o, dict):
                    return 400, {"ok": False, "error": "malformed op"}
                bodies = o.get("bodies") if isinstance(o.get("bodies"), dict) else {}
                if o.get("op") == "delete_board":
                    board["deleted"] = {"rev": rev, **who}
                for id_ in [i for i in o.get("ids") or [] if isinstance(i, str)]:
                    old = board["things"].get(id_) or {}
                    body = bodies.get(id_)
                    if id_ not in board["things"]:
                        board["order"].append(id_)
                    board["things"][id_] = thing(old.get("body") if body is None else body,
                                                 old.get("kind") or o.get("kind"), rev, who, erased=body is None)
                landed.append({"op": o.get("op"), "ids": o.get("ids") or [], "bodies": bodies})
            board["rev"] = rev
            board["log"].append({"rev": rev, "batch_id": data.get("batch_id") or "remote-%d" % rev,
                                 "kind": data.get("kind") or "ops", **who, "ops": landed})
            applied = list(range(len(landed)))
            return 200, {"ok": True, "rev": rev, "applied": applied}
        if path == "/boards":
            id_ = data.get("id")
            if not isinstance(id_, str) or not id_:
                return 400, {"ok": False, "error": "no id"}
            if id_ not in BOARDS:
                who = {"device": data.get("device", ""), "by": data.get("by", "igor"), "at": now()}
                BOARDS[id_] = {"name": data.get("name", ""), "rev": 0, "order": ["@board"], "deleted": None, "log": [],
                               "things": {"@board": thing({"name": data.get("name", ""), "paper": data.get("paper")},
                                                          "board", 0, who)}}
            return 200, {"ok": True, "id": id_, "rev": BOARDS[id_]["rev"], "contract": 2}
        if not (path.startswith("/boards/") and path.endswith("/ops")):
            return None
        POSTS.append(data)
        board = BOARDS.get(path[len("/boards/"):-len("/ops")])
        if board is None:
            return 404, {"ok": False, "error": "unknown board"}
        device = data.get("device") or ""
        if device.startswith("iphone"):
            return 403, {"ok": False, "error": "look_only"}
        batch_id, ops, base = data.get("batch_id"), data.get("ops"), data.get("base_rev")
        if not isinstance(batch_id, str) or not isinstance(ops, list) or not isinstance(base, int):
            return 400, {"ok": False, "error": "a batch needs batch_id, base_rev and ops"}
        for index, op in enumerate(ops):
            if not isinstance(op, dict) or not isinstance(op.get("op"), str):
                return 400, {"ok": False, "error": "malformed op", "op": index}
        sha = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        if batch_id in ANSWERS:
            seen, answer = ANSWERS[batch_id]
            if seen != sha:
                return 409, {"ok": False, "error": "batch_id_reused"}
            return 200, {**answer, "replay": True}
        armed, NEXT = NEXT, None
        if armed and (armed.get("ok") is False or armed.get("status", 200) != 200):
            return armed.get("status", 200), {"ok": False, "error": armed.get("error", "not looked at")}
        if base > board["rev"]:
            refused = [{"op": i, "id": "", "reason": "ahead", "rev": board["rev"]} for i in range(len(ops))]
        else:
            refused = (armed or {}).get("refused") or []
        who = {"device": device, "by": data.get("by", "igor"), "at": now()}
        rev, applied = commit(board, ops, refused, who, batch_id) if base <= board["rev"] else (board["rev"], [])
        answer = {"ok": True, "contract": 2, "batch_id": batch_id, "rev": rev, "applied": applied,
                  "refused": refused, "replay": False,
                  "missing_ids": [r["id"] for r in refused if r.get("reason") == "unknown" and r.get("id")]}
        ANSWERS[batch_id] = (sha, answer)
        return 200, answer
