#!/usr/bin/env python3
"""Stories 1330-1334: the fake Cockpit's board store routes, which the device's cache and queue are built against,
checked without a simulator: a batch lands once per batch_id (a replay, or a 409 for a different body), an iphone is
refused at the door, ahead lands nothing, an armed refusal is applied per id (a group whose id exists inserts no body),
ops?since carries every landed id's body after (restore's kept body, erase's null), another device's batch lands, and
a malformed op or an odd body is a 400 or stored as is, never a crash."""

import json
import os
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
failed = False


def check(ok, what):
    global failed
    print(("ok   " if ok else "FAIL ") + "fake store: " + what)
    failed |= not ok


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


port = free_port()
base = "http://127.0.0.1:%d" % port
report = tempfile.NamedTemporaryFile(delete=False).name
fake = subprocess.Popen([os.path.join(ROOT, "scripts/native/fake-cockpit.py"), str(port), report],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def call(path, body=None):
    """(status, answer)."""
    request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=5) as answer:
            return answer.status, json.loads(answer.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())


def batch(batch_id, base_rev, ops, device="ipad-7c2e"):
    return {"batch_id": batch_id, "device": device, "by": "igor", "base_rev": base_rev, "device_at": "t", "ops": ops}


def stroke(id_, x=0):
    return {"id": id_, "pts": [[x, 0, 1]]}


try:
    for _ in range(50):
        try:
            call("/boards")
            break
        except OSError:
            time.sleep(0.1)

    # POST /boards: the store's create.
    status, made = call("/boards", {"id": "b-1", "name": "Plan", "paper": "dots", "device": "ipad-7c2e"})
    check(status == 200 and made["created"] is True and made["rev"] == 0, "a board is created")
    again = call("/boards", {"id": "b-1", "name": "Other"})[1]
    check(again["created"] is False and again["name"] == "Plan", "creating an id it has is a no-op")
    board = call("/boards/b-1")[1]["things"][0]
    check(board["id"] == "@board" and board["kind"] == "board" and board["body"]["name"] == "Plan"
          and board["device"] == "ipad-7c2e", "the board's own thing carries its name and who made it")
    for bad, why in [({"name": "x"}, "id"), ({"id": "a/b", "name": "x"}, "id"),
                     ({"id": "assets", "name": "x"}, "reserved"), ({"id": "b", "name": "  "}, "name"),
                     ({"id": "b", "name": "x", "device": "laptop"}, "device"),
                     ({"id": "b", "name": "x", "by": "mallory"}, "by")]:
        status, answer = call("/boards", bad)
        check(status == 400 and why in answer["error"], "a create without a good %s is a 400 naming it" % why)
    check(call("/boards", {"id": "b", "name": "x", "device": "iphone-1"}) == (403, {"ok": False, "error": "look_only"}),
          "an iphone's create is look_only")

    # POST /boards/<id>/ops.
    first = batch("b1", 0, [{"op": "add_strokes", "strokes": [stroke("s1"), stroke("s2")]}])
    status, answer = call("/boards/b-1/ops", first)
    check(status == 200 and answer["rev"] == 1 and answer["applied"] == [0] and answer["replay"] is False
          and answer["landed"] == [{"op": 0, "ids": ["s1", "s2"]}], "a batch lands as one new rev and says what landed")
    status, again = call("/boards/b-1/ops", first)
    check(again["replay"] is True and again["rev"] == 1, "the same batch again replays its answer")
    status, reused = call("/boards/b-1/ops", batch("b1", 0, [{"op": "erase", "ids": ["s1"]}]))
    check(status == 409 and reused["error"] == "batch_id_reused", "a batch_id with a different body is a 409")
    call("/boards", {"id": "b-2", "name": "Other board"})
    check(call("/boards/b-2/ops", first)[1].get("replay") is False, "a batch_id is the board's own: another board's is new")
    check(call("/boards/b-1/ops", batch("p1", 1, [{"op": "erase", "ids": ["s1"]}], device="iphone-1"))[0] == 403,
          "an iphone's batch is refused at the door")
    check(call("/boards/nope/ops", batch("x", 0, [])) == (404, {"ok": False, "error": "no such board"}),
          "an unknown board is a 404, no such board")
    for ops, what in [([{"op": "erase", "ids": ["s1"]}, "not an op"], "an op that isn't an object"),
                      ([{"op": "move", "ids": ["s1"], "dx": 3}], "a meaning op"),
                      ([{"op": "reply", "id": "r1", "marks": []}], "a reply, which devices never send"),
                      ([{"op": "set", "ids": ["@board"], "bodies": {"@board": {"name": "x"}}}], "a set on @board"),
                      ([{"op": "set", "ids": ["s1"], "bodies": {"s1": None}}], "a set to null"),
                      ([{"op": "set", "ids": ["s1"], "bodies": {}}], "a set without a body for each id"),
                      ([{"op": "replace", "ids": ["s1"], "strokes": [stroke("s1")]}], "a replace that re-adds its id"),
                      ([{"op": "rename", "name": " "}], "a rename to nothing")]:
        status, bad = call("/boards/b-1/ops", batch("m1", 1, ops))
        check(status == 400 and bad.get("op") == len(ops) - 1, "%s is a 400 naming its index" % what)
    for field, value in [("device", "laptop"), ("by", "mallory"), ("base_rev", -1), ("batch_id", "a b")]:
        body = {**batch("m2", 1, []), field: value}
        check(call("/boards/b-1/ops", body)[0] == 400, "a batch with a bad %s is a 400" % field)

    status, ahead = call("/boards/b-1/ops", batch("a1", 9, [{"op": "erase", "ids": ["s1", "s2"]}]))
    check(ahead["rev"] == 1 and ahead["applied"] == [] and ahead["landed"] == []
          and [(r["id"], r["reason"]) for r in ahead["refused"]] == [("s1", "ahead"), ("s2", "ahead")],
          "a base ahead of the board lands nothing, refused per id")

    # A group whose own id exists: armed, its members' change lands, its body doesn't.
    call("/fake/store-remote", {"board": "b-1", "device": "web-3f9a", "ops": [
        {"op": "group", "ids": ["g1"], "bodies": {"g1": {"owner": "larry"}}}]})
    call("/fake/store-next", {"refused": [{"op": 0, "id": "g1", "reason": "exists"}]})
    status, grouped = call("/boards/b-1/ops", batch("b2", 2, [{"op": "group", "id": "g1", "ids": ["s1"]}]))
    things = {t["id"]: t for t in call("/boards/b-1")[1]["things"]}
    check(grouped["applied"] == [0] and grouped["landed"] == [{"op": 0, "ids": ["s1"]}]
          and things["g1"]["body"] == {"owner": "larry"} and things["s1"]["rev"] == 3,
          "an answer lands per id from refused, never per applied index")
    call("/boards/b-1/ops", batch("k1", 3, [{"op": "add_text", "id": "t1", "text": "hi"},
                                            {"op": "header", "id": "h1", "ids": ["s2"]},
                                            {"op": "connector", "id": "c1", "from": "s1", "to": "s2"}]))
    kinds = {t["id"]: t["kind"] for t in call("/boards/b-1")[1]["things"]}
    check((kinds["s1"], kinds["t1"], kinds["h1"], kinds["c1"]) == ("stroke", "object", "header", "connector"),
          "things carry the store's kinds")

    call("/fake/store-next", {"status": 503})
    status, down = call("/boards/b-1/ops", batch("b3", 4, [{"op": "erase", "ids": ["s2"]}]))
    check(status == 503 and down["ok"] is False and call("/boards/b-1")[1]["rev"] == 4,
          "an armed worker failure is a 503 that lands nothing")
    status, erased = call("/boards/b-1/ops", batch("b4", 4, [{"op": "erase", "ids": ["s2"]}]))
    status, restored = call("/boards/b-1/ops", batch("b5", 5, [{"op": "restore", "ids": ["s2"]}]))
    since = call("/boards/b-1/ops?since=4")[1]
    check([b["rev"] for b in since["batches"]] == [5, 6], "ops?since gives the batches after it")
    check(since["batches"][0]["ops"][0]["bodies"] == {"s2": None}, "an erase's body after is null")
    check(since["batches"][1]["ops"][0]["bodies"] == {"s2": stroke("s2")}, "a restore carries the kept body")
    check(since["batches"][1]["batch_id"] == "b5" and since["batches"][1]["device"] == "ipad-7c2e",
          "each batch names its id and author")
    for query in ["", "since=", "since=-1", "since=two", "since=1.5"]:
        status, answer = call("/boards/b-1/ops?" + query)
        check(status == 400 and "since" in answer["error"], "ops?%s is a 400 naming since" % query)

    # Bodies are stored as they come: any JSON but null, a string included.
    status, odd = call("/boards/b-1/ops", batch("b6", 6, [{"op": "set", "ids": ["s1"], "bodies": {"s1": "a string"}}]))
    things = {t["id"]: t for t in call("/boards/b-1")[1]["things"]}
    check(status == 200 and things["s1"]["body"] == "a string", "a string body is stored as is and never crashes the fake")
    status, keepword = call("/boards/b-1/ops", batch("b7", 7, [{"op": "set", "ids": ["s1"], "bodies": {"s1": "keep"}}]))
    check({t["id"]: t for t in call("/boards/b-1")[1]["things"]}["s1"]["body"] == "keep",
          "a body that reads like an internal word is still a body")

    status, gone = call("/boards/b-1/ops", batch("b8", 8, [{"op": "rename", "name": "Plan 2"}, {"op": "delete_board"}]))
    snap = call("/boards/b-1")[1]
    deleted = snap.get("deleted") or {}
    check(snap["name"] == "Plan 2" and deleted.get("rev") == 9 and deleted.get("device") == "ipad-7c2e"
          and deleted.get("by") == "igor" and deleted.get("at"), "rename lands, and a delete is {rev, device, by, at}")
    listed = {b["id"]: b for b in call("/boards?deleted=1")[1]["boards"]}
    check("b-1" not in [b["id"] for b in call("/boards")[1]["boards"]] and listed["b-1"]["deleted"] == deleted
          and "deleted" not in listed["b-2"], "a deleted board leaves the list; ?deleted=1 shows it with its delete")
finally:
    fake.terminate()

raise SystemExit(1 if failed else 0)
