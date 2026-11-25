#!/usr/bin/env python3
"""Stories 814-818: the fake Cockpit's board ops, which WhiteboardPaperGhostsUITests relies on, checked without a
simulator. Armed with POST /fake/larry-ops, Larry's next board answer is a batch of changes on the message's own rev
(one behind it when stale), with room below the picture's middle and a line of text in the gap, and only once; GET
/fake/ops says the rev and op_result each board message carried."""

import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
failed = False


def check(ok, what):
    global failed
    print(("ok   " if ok else "FAIL ") + "fake ops: " + what)
    failed |= not ok


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


port = free_port()
base = "http://127.0.0.1:%d" % port
report = tempfile.NamedTemporaryFile(delete=False).name
fake = subprocess.Popen(
    [os.path.join(ROOT, "scripts/native/fake-cockpit.py"), str(port), report],
    env={**os.environ, "FAKE_COCKPIT_LARRY_DELAY": "0.1"}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def call(path, body=None):
    request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=5) as answer:
        return json.loads(answer.read())


def larry_rows(key):
    time.sleep(0.5)
    return [m for m in call("/chat/" + key)["messages"] if m["who"] == "larry"]


try:
    for _ in range(50):
        try:
            call("/fake/ops")
            break
        except OSError:
            time.sleep(0.1)
    frame = {"x": 100, "y": 200, "w": 400, "h": 600, "scale": 2}
    turn = {"id": "p1", "text": "turn", "board": "b1", "picture_id": "p1", "frame": frame, "title": "Plan", "rev": 7,
            "op_result": None, "events": [{"type": "pen", "state": "down", "idle_ms": 0, "t": 1}]}
    call("/fake/larry-ops", {})
    key = call("/chat", turn)["thread"]
    rows = larry_rows(key)
    ops = rows[-1].get("ops") if rows else None
    check(ops is not None and rows[-1]["text"] == "made room", "an armed answer is a batch: %s" % rows)
    if ops:
        check(ops["board"] == "b1" and ops["base_rev"] == 7 and ops["label"] == "make room", "on the message's rev")
        push, text = ops["list"]
        check(push == {"op": "translate", "below_y": 500, "dy": 120}, "room below the picture's middle: %s" % push)
        check(text["op"] == "add_text" and text["id"] == "fake-text-1" and text["font"] == "plain"
              and text["y"] == 530 and text["x"] == 140, "text in the gap: %s" % text)
    check(not call("/fake/ops")["armed"], "once")

    call("/fake/larry-ops", {"stale": True, "dy": 50})
    second = dict(turn, id="p2", picture_id="p2", rev=8,
                  op_result={"label": "make room", "ok": True, "rev": 8}, events=[])
    call("/chat/" + key, second)
    stale = larry_rows(key)[-1].get("ops") or {}
    check(stale.get("base_rev") == -1 and stale.get("list", [{}])[0].get("dy") == 50,
          "stale is before anything the board remembers: %s" % stale)
    call("/fake/larry-ops", {"behind": True})
    call("/chat/" + key, dict(turn, id="p2b", picture_id="p2b", rev=8, op_result=None, events=[]))
    behind = larry_rows(key)[-1].get("ops") or {}
    check(behind.get("base_rev") == 7, "behind is one behind, story 961: %s" % behind)

    call("/chat/" + key, dict(turn, id="p3", picture_id="p3", rev=8, op_result=None, events=[]))
    last = larry_rows(key)[-1]
    check("ops" not in last and last.get("shapes"), "unarmed, he draws marks as before")
    reports = call("/fake/ops")["reports"]
    check([r["rev"] for r in reports] == [7, 8, 8, 8], "each board message's rev: %s" % reports)
    check(reports[0]["events"] == 1 and reports[1]["op_result"] == {"label": "make room", "ok": True, "rev": 8},
          "and its events and op_result: %s" % reports)
    call("/fake/larry-ops", {"kind": "ink_and_button"})
    call("/chat/" + key, dict(turn, id="p4", picture_id="p4", rev=9, op_result=None, events=[]))
    ink = larry_rows(key)[-1].get("ops") or {}
    kinds = [op["op"] for op in ink.get("list", [])]
    check(ink.get("base_rev") == 9 and kinds == ["add_strokes", "overlay"], "his ink and a button: %s" % ink)
    check(ink["list"][1]["tap_event"] == {"type": "make_room"} and ink["list"][0]["strokes"][0]["points"][0] == [140, 830],
          "the line and the button sit below the picture")
    # Story 929: a hold is no row, the picture's receipt seen and waiting; his next row clears it.
    before = len(larry_rows(key))
    call("/fake/larry-ops", {"kind": "hold", "label": "Larry: go on"})
    call("/chat/" + key, dict(turn, id="p5", picture_id="p5", rev=10, op_result=None, events=[]))
    rows = larry_rows(key)
    held = [m for m in call("/chat/" + key)["messages"] if m["id"] == "p5"][0].get("receipt") or {}
    check(len(rows) == before and held.get("state") == "seen" and held.get("waiting", {}).get("label") == "Larry: go on"
          and held["waiting"].get("ts"), "a hold is seen and waiting, with no answer: %s" % held)
    call("/fake/larry-draws", {"count": 1})
    held = [m for m in call("/chat/" + key)["messages"] if m["id"] == "p5"][0].get("receipt") or {}
    check(held.get("state") == "seen" and "waiting" not in held, "his next row clears the hold: %s" % held)
    # Story 1180: a circle on the middle of the last stroke posted, in the picture's pixels.
    call("/whiteboard/strokes", {"board": "b1", "picture_id": "p5", "frame": frame,
                                 "strokes": [{"id": "s1", "points": [[150, 300], [250, 320], [350, 340]]}]})
    call("/fake/larry-draws", {"count": 1, "on_last_stroke": True})
    circle = larry_rows(key)[-1]["shapes"][0]
    check(circle["cx"] == 300 and circle["cy"] == 240 and circle["r"] == 24, "a circle on the last stroke: %s" % circle)
    answer = call("/whiteboard/events", {"board": "b1", "rev": 9, "events": [{"type": "tap", "target_id": "x"}]})
    check(answer["ok"] and answer["woke"] is False and answer["rev"] == 9 and "ts_ms" in answer,
          "a plain tap is taken but wakes nobody: %s" % answer)
    tap = {"type": "overlay_tap", "target_id": "x", "event": {"type": "make_room"}}
    answer = call("/whiteboard/events", {"board": "b1", "rev": 9, "events": [tap]})
    posts = call("/fake/ops")["event_posts"]
    check(answer["woke"] and posts[-1]["woke"] and posts[-1]["events"][0]["target_id"] == "x",
          "a tap on his control wakes him: %s" % posts)
    for bad, why in (({"type": "Make-Room"}, "a type out of pattern"), ({"type": "x", "pad": "y" * 9000}, "over 8 KB")):
        try:
            call("/whiteboard/events", {"board": "b1", "rev": 9, "events": [bad]})
            check(False, "%s is refused" % why)
        except urllib.error.HTTPError as error:
            check(error.code in (400, 413), "%s is refused: %s" % (why, error.code))
    picture = {"board": "b1", "picture_id": "p9", "frame": frame}
    text = {"kind": "text", "id": "t1", "text": "hi", "font": "print", "x": 1, "y": 2, "w": 3, "h": 4, "color": "#000000",
            "t": 5}
    ink = {"id": "s1", "color": "#000000", "width": 3, "tool": "pen", "points": [[0, 0], [1, 1]]}
    check(call("/whiteboard/strokes", dict(picture, strokes=[ink, text]))["count"] == 2, "a text the Cockpit takes")
    for bad, why in ((dict(text, points=[[0, 0]]), "a text with more"), (dict(text, font="plain"), "a font it doesn't know"), ({"id": "s2", "points": []}, "a stroke with none"),
                     (dict(ink, kind="label"), "another kind")):
        try:
            call("/whiteboard/strokes", dict(picture, strokes=[bad]))
            check(False, why + " is refused")
        except urllib.error.HTTPError as e:
            check(e.code == 400, why + " is refused")
    fold = {"header": "h-1", "header_strokes": ["s1"], "lines": 3, "strokes": ["s2", "s3"]}
    call("/whiteboard/strokes", dict(picture, strokes=[ink], folds=[fold]))
    check(call("/fake/strokes")["folds"][-1] == [fold], "folds beside the strokes are taken and kept")
    try:
        call("/whiteboard/strokes", dict(picture, strokes=[ink], folds=[{"header": "h-1"}]))
        check(False, "a fold without its lines and strokes is refused")
    except urllib.error.HTTPError as e:
        check(e.code == 400, "a fold without its lines and strokes is refused")
    # Stories 1604-1606: POST /fake/down, which ChatCockpitDownUITests relies on.
    call("/fake/down", {"status": 502})
    try:
        call("/chat")
        check(False, "a down Cockpit's list is a 502")
    except urllib.error.HTTPError as e:
        check(e.code == 502, "a down Cockpit's list is a 502")
    call("/fake/down", {})
    check("threads" in call("/chat"), "the list reads again once it is up")
    # Story 1132: GET /asks/search, which ChatAskSearchUITests relies on.
    call("/fake/asks", {"open": True})
    found = call("/asks/search?q=RAMEN")
    check([t["key"] for t in found["threads"]] == ["igor2-88g.881"] and found["terms"] == ["ramen"],
          "a search finds an open ask by an option")
    check("option" in [m["field"] for m in found["threads"][0]["matches"]], "the option is a matched field")
    hidden = call("/asks/search?q=passport")
    check(hidden["threads"] == [] and (hidden["open"], hidden["answered"]) == (0, 1), "answered ones are counted, not shown")
    check([t["key"] for t in call("/asks/search?q=passport&all=1")["threads"]] == ["igor2-88g.882"],
          "all=1 shows the answered ask")
    for q, code in (("%20", 400), ("bdfail", 502)):
        try:
            call("/asks/search?q=" + q)
            check(False, "q=%s is a %d" % (q, code))
        except urllib.error.HTTPError as e:
            check(e.code == code, "q=%s is a %d" % (q, code))
    call("/fake/asks", {"open": False})
    # Stories 1616-1618: GET /chat?q, which ChatThreadSearchUITests relies on.
    check(call("/chat?q=passport")["threads"] == [], "no search thread until a test asks for it")
    call("/fake/search-thread", {"on": True})
    check([t["key"] for t in call("/chat?q=PASSPORT")["threads"]] == ["igor2-88g.1443"],
          "the chat search finds a word in an older message")
    check([t["key"] for t in call("/chat?q=travel%20booked")["threads"]] == ["igor2-88g.1443"],
          "every word, title or message")
    check(len(call("/chat?q=%20")["threads"]) == len(call("/chat")["threads"]), "a blank q is the plain list")
    call("/fake/search-down", {"status": 502})
    try:
        call("/chat?q=laptops")
        check(False, "a down search is a 502")
    except urllib.error.HTTPError as e:
        check(e.code == 502, "a down search is a 502")
    check("threads" in call("/chat"), "the list stays up while the search is down")
    call("/fake/search-down", {})
    call("/fake/search-thread", {"on": False})
    check("igor2-88g.1443" not in [t["key"] for t in call("/chat")["threads"]], "the search thread goes away again")
    # Stories 777, 805: a slow answer is armed for one picture only.
    call("/fake/larry-ops", {"kind": "slow", "seconds": 1.5})
    before = len(larry_rows(key))
    call("/chat/" + key, dict(turn, id="p6", picture_id="p6", rev=11, op_result=None, events=[]))
    check(len(larry_rows(key)) == before, "a slow answer hasn't come in half a second")
    time.sleep(1.5)
    check(len(larry_rows(key)) == before + 1, "and comes after its seconds")
    # Stories 775, 802: board-stuck makes the newest board thread mark, and holds its next picture once.
    stuck = call("/fake/board-stuck", {"seconds": 1.5})
    check(stuck["thread"] == key and all((m.get("receipt") or {}).get("state") == "done"
                                         for m in call("/chat/" + key)["messages"] if m["who"] == "igor"),
          "board-stuck marks the thread's pictures done: %s" % stuck)
    started = time.time()
    call("/chat/" + key, dict(turn, id="p7", picture_id="p7", rev=12, op_result=None, events=[]))
    check(time.time() - started >= 1.4, "its next picture is held")
    started = time.time()
    again = call("/chat/" + key, dict(turn, id="p7", picture_id="p7", rev=12, op_result=None, events=[]))
    check(time.time() - started < 1 and again.get("duplicate"), "a resend lands at once, kept once: %s" % again)
    time.sleep(1.5)
    p7 = [m for m in call("/chat/" + key)["messages"] if m["id"] == "p7"]
    check(len(p7) == 1 and (p7[0].get("receipt") or {}).get("state") == "done", "his answer marks it done: %s" % p7)
    started = time.time()
    call("/chat/" + key, dict(turn, id="p8", picture_id="p8", rev=13, op_result=None, events=[]))
    check(time.time() - started < 1, "only once")
finally:
    fake.kill()
    os.unlink(report)

sys.exit(1 if failed else 0)
