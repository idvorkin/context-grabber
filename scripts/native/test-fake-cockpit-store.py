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

    check(call("/boards", {"id": "b-1", "name": "Plan", "paper": "dots"})[0] == 200, "a board is created")
    check(call("/boards", {"id": "b-1", "name": "Other"})[1]["rev"] == 0, "creating an id it has is a no-op")
    check(call("/boards/b-1")[1]["name"] == "Plan", "the snapshot keeps the first name")

    first = batch("b1", 0, [{"op": "add_strokes", "strokes": [stroke("s1"), stroke("s2")]}])
    status, answer = call("/boards/b-1/ops", first)
    check(status == 200 and answer["rev"] == 1 and answer["applied"] == [0] and answer["replay"] is False,
          "a batch lands as one new rev")
    status, again = call("/boards/b-1/ops", first)
    check(again["replay"] is True and again["rev"] == 1, "the same batch again replays its answer")
    status, reused = call("/boards/b-1/ops", batch("b1", 0, [{"op": "erase", "ids": ["s1"]}]))
    check(status == 409 and reused["error"] == "batch_id_reused", "a batch_id with a different body is a 409")
    check(call("/boards/b-1/ops", batch("p1", 1, [{"op": "erase", "ids": ["s1"]}], device="iphone-1"))[0] == 403,
          "an iphone's batch is refused at the door")
    check(call("/boards/nope/ops", batch("x", 0, []))[0] == 404, "an unknown board is a 404")
    status, bad = call("/boards/b-1/ops", batch("m1", 1, [{"op": "erase", "ids": ["s1"]}, "not an op"]))
    check(status == 400 and bad.get("op") == 1, "a malformed op is a 400 naming its index")

    status, ahead = call("/boards/b-1/ops", batch("a1", 9, [{"op": "erase", "ids": ["s1"]}]))
    check(ahead["rev"] == 1 and ahead["applied"] == [] and ahead["refused"][0]["reason"] == "ahead",
          "a base ahead of the board lands nothing")

    # A group whose own id exists: armed, its members' change lands, its body doesn't.
    call("/fake/store-remote", {"board": "b-1", "device": "web-3f9a", "ops": [
        {"op": "group", "ids": ["g1"], "bodies": {"g1": {"owner": "larry"}}}]})
    call("/fake/store-next", {"refused": [{"op": 0, "id": "g1", "reason": "exists"}]})
    status, grouped = call("/boards/b-1/ops", batch("b2", 2, [{"op": "group", "id": "g1", "ids": ["s1"]}]))
    things = {t["id"]: t for t in call("/boards/b-1")[1]["things"]}
    check(grouped["applied"] == [0] and things["g1"]["body"] == {"owner": "larry"} and things["s1"]["rev"] == 3,
          "an answer lands per id from refused, never per applied index")

    call("/fake/store-next", {"ok": False})
    status, down = call("/boards/b-1/ops", batch("b3", 3, [{"op": "erase", "ids": ["s2"]}]))
    check(down["ok"] is False and call("/boards/b-1")[1]["rev"] == 3, "an armed ok:false lands nothing")
    status, erased = call("/boards/b-1/ops", batch("b4", 3, [{"op": "erase", "ids": ["s2"]}]))
    status, restored = call("/boards/b-1/ops", batch("b5", 4, [{"op": "restore", "ids": ["s2"]}]))
    since = call("/boards/b-1/ops?since=3")[1]
    check([b["rev"] for b in since["batches"]] == [4, 5], "ops?since gives the batches after it")
    check(since["batches"][0]["ops"][0]["bodies"] == {"s2": None}, "an erase's body after is null")
    check(since["batches"][1]["ops"][0]["bodies"] == {"s2": stroke("s2")}, "a restore carries the kept body")
    check(since["batches"][1]["batch_id"] == "b5" and since["batches"][1]["device"] == "ipad-7c2e",
          "each batch names its id and author")

    # Bodies are stored as they come: a string body (on @board too) is kept, not read as a name.
    status, odd = call("/boards/b-1/ops", batch("b6", 5, [{"op": "set", "ids": ["s1", "@board"],
                                                          "bodies": {"s1": "a string", "@board": "also"}}]))
    snap = call("/boards/b-1")[1]
    things = {t["id"]: t for t in snap["things"]}
    check(status == 200 and things["s1"]["body"] == "a string" and snap["name"] == "Plan",
          "a string body is stored as is and never crashes the fake")
    status, keepword = call("/boards/b-1/ops", batch("b7", 6, [{"op": "set", "ids": ["s1"], "bodies": {"s1": "keep"}}]))
    check({t["id"]: t for t in call("/boards/b-1")[1]["things"]}["s1"]["body"] == "keep",
          "a body that reads like an internal word is still a body")

    call("/boards/b-1/ops", batch("b8", 7, [{"op": "rename", "name": "Plan 2"}, {"op": "delete_board"}]))
    snap = call("/boards/b-1")[1]
    check(snap["name"] == "Plan 2" and snap.get("deleted"), "rename and delete_board land on @board")
    check(call("/boards")[1]["boards"] == [] and len(call("/boards?deleted=1")[1]["boards"]) == 1,
          "a deleted board leaves the list, and ?deleted=1 shows it")
finally:
    fake.terminate()

raise SystemExit(1 if failed else 0)
