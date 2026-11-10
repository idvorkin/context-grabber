#!/usr/bin/env python3
"""A stand-in for the Cockpit's chat routes, for the simulator (chat spec 2026-10-25; Cockpit story 129).

  scripts/native/fake-cockpit.py PORT REPORT

GET /chat, GET /chat/<key>, POST /chat (a new thread), POST /chat/<key>, POST /chat-seen, POST /attachments,
POST /chat/<key>/archive and /unarchive (#589; a new message brings a thread back; 415 unless application/json, as on
the Cockpit's write boundary),
GET /attachments/<ref>, POST /whiteboard/strokes (story 419: counted and answered, never kept), POST /whiteboard/suggest (a ghost circle at the picture's right edge, streamed as NDJSON when the request
accepts it, as one JSON when not). A chat URL ending /plain gets a Cockpit that doesn't stream whatever is asked; one ending /many gets six marks of every kind, 400 ms apart; one ending /far gets a circle far below the picture, past a board on paper's last page. GET /fake/strokes says the ids of each POST /whiteboard/strokes so far. GET and POST /whiteboard/responder keep each board's knob (story 659), Sonnet by default. A message resent with an id the thread has is a duplicate, as on the Cockpit. Larry
answers every message of Igor's a second later ("Larry heard: <text>"), and a message with a board's picture with marks (cockpit#85: an arrow and a
label as kind + points, with the picture's picture_id and frame echoed). POST /fake/larry-draws {"count": n} is a test's way to have him draw
unprompted on the newest board thread (n circles, as /whiteboard/suggest strokes). Every request is a JSON line in REPORT.
POST /attachments takes pictures only and answers anything else as the Cockpit does (400, #633).
FAKE_COCKPIT_NEW_DELAY=<seconds> holds each POST /chat that long first, so a new chat's waiting state can be seen.
Thread igor2-88g.593 is one Larry marks as looking done (#599). Thread igor2-88g.1268 is the pinned one, listed with no messages and refusing an archive (#598). By default this is a Cockpit with no skill threads (story 516). POST /fake/skill-thread is a test's way to add one (#632, cockpit#90), igor2-88g.632: pinned under Larry's, listed with no messages, refusing an archive, its replies from "idvorkin"; a message saying "fail" gets a failure row instead, with Igor's messages marked done either way, as on the Cockpit. Thread igor2-88g.592 holds one picture from Larry, all white and twice as tall as wide: on an iPhone it fills the
full-size view, under its Done (story 306).
Threads igor2-88g.603 and .604 hold the same picture from a whiteboard: board-603 (the UI test makes it with GRABBER_BOARD_FIXTURE) and board-gone-603, which no device has (stories 317, 319, #603).
Thread igor2-88g.629 holds one question from Larry, for the press-and-hold menu (stories 518-519, 540-541), apart from .900, where the simulator's outbox can hold leftover smoke items; the smoke and the chat UI script clear the outbox's own leftovers for .629 first (forget-chat-thread.sh, #801).
"""

import base64
import json
import os
import secrets
import sys
import threading
import time
import urllib.parse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT, REPORT = int(sys.argv[1]), sys.argv[2]
NEW_DELAY = float(os.environ.get("FAKE_COCKPIT_NEW_DELAY") or 0)
LOCK = threading.Lock()
THREADS = {
    "igor2-88g.900": {"title": "Should the phone chat poll?", "messages": [], "seen": ""},
}
CREATED = {}
BOARD_MESSAGES = {}  # thread -> the newest message of Igor's carrying a board's picture
STROKE_SENDS = []  # the ids in each POST /whiteboard/strokes
RESPONDERS = {}  # board -> haiku | sonnet | larry, as POST /whiteboard/responder set it (story 659)


def responder_answer(board):
    """GET /whiteboard/responder?board=<id> as the Cockpit answers it (whiteboard.py, cockpit-m28)."""
    return {"ok": True, "board": board, "responder": RESPONDERS.get(board, "sonnet"), "set": board in RESPONDERS,
            "at": None, "default": "sonnet", "choices": ["haiku", "sonnet", "larry"]}
WHITE_PICTURE = "2026-11-01/0000000000000592.png"
IMAGES = {WHITE_PICTURE: base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAACCAAAAAC86un7AAAADElEQVR4nGP4z/AfAAQAAf8iCjrwAAAAAElFTkSuQmCC")}


def is_picture(raw):
    return (raw.startswith(b"\x89PNG\r\n\x1a\n") or raw.startswith(b"\xff\xd8\xff") or raw[:6] in (b"GIF87a", b"GIF89a")
            or (raw[:4] == b"RIFF" and raw[8:12] == b"WEBP"))


def now():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def row(key, who, text, mid=None, attachments=None, board=None):
    r = {"id": mid or secrets.token_hex(6), "ts": now(), "thread": key, "who": who, "text": text,
         "source": "app" if who == "igor" else "cli"}
    if attachments:
        r["attachments"] = attachments
    if board:
        r["board"] = board
    return r


THREADS["igor2-88g.900"]["messages"] += [
    row("igor2-88g.900", "igor", "Does the phone poll while a thread is open?"),
    row("igor2-88g.900", "larry", "Every four seconds, and the list on each return."),
]
THREADS["igor2-88g.593"] = {"title": "Finished plan", "seen": "", "looks_done": True, "messages": [
    row("igor2-88g.593", "larry", "That's settled then."),
]}
THREADS["igor2-88g.1268"] = {"title": "Larry", "seen": "", "pinned": True, "messages": []}
THREADS["igor2-88g.592"] = {"title": "Your whiteboard", "seen": "", "messages": [
    row("igor2-88g.592", "larry", "", attachments=[WHITE_PICTURE]),
]}
THREADS["igor2-88g.603"] = {"title": "A board picture", "seen": "", "messages": [
    row("igor2-88g.603", "igor", "", attachments=[WHITE_PICTURE], board="board-603"),
]}
THREADS["igor2-88g.604"] = {"title": "A board since deleted", "seen": "", "messages": [
    row("igor2-88g.604", "igor", "", attachments=[WHITE_PICTURE], board="board-gone-603"),
]}
THREADS["igor2-88g.629"] = {"title": "Larry asks", "seen": "", "messages": [
    row("igor2-88g.629", "larry", "Shall we ship it?"),
]}


def summary(key, t):
    last = t["messages"][-1] if t["messages"] else {"ts": "", "who": "", "text": ""}
    larry = [m["ts"] for m in t["messages"] if m["who"] == "larry"]
    unread = len([ts for ts in larry if ts > t["seen"]])
    return {"key": key, "title": t["title"], "count": len(t["messages"]), "last_ts": last["ts"],
            "last_who": last["who"], "last_text": last["text"] or ("[image]" if t["messages"] else ""), "larry_ts": larry,
            "unread": unread, "done": t.get("archived", False), "archived": t.get("archived", False),
            "looks_done": t.get("looks_done", False), "pinned": t.get("pinned", False), "skill": t.get("skill"),
            "last_author": last.get("author", "")}


def skill_reply_later(key, text):
    def go():
        time.sleep(1)
        with LOCK:
            t = THREADS[key]
            fail = "fail" in (text or "")
            r = row(key, "larry", ("The %s skill could not answer: a fake failure. Send again to retry." % t["skill"])
                    if fail else "idvorkin heard: " + (text or "a picture"))
            r["author"] = t["skill"]
            if fail:
                r["error"] = True
            t["messages"].append(r)
            for m in t["messages"]:
                if m["who"] == "igor":
                    m["receipt"] = {"state": "done"}
    threading.Thread(target=go, daemon=True).start()


def reply_later(key, text):
    def go():
        time.sleep(1)
        with LOCK:
            THREADS[key]["messages"].append(row(key, "larry", "Larry heard: " + (text or "a picture")))
    threading.Thread(target=go, daemon=True).start()


def marks(key, text, shapes):
    source = BOARD_MESSAGES[key]
    r = row(key, "larry", text)
    r.update(shapes=shapes, picture_id=source["picture_id"], frame=source["frame"], board=source["board"])
    THREADS[key]["messages"].append(r)


def answer_board_later(key):
    def go():
        time.sleep(1)
        with LOCK:
            frame = BOARD_MESSAGES[key]["frame"]
            w, h = frame["w"] * frame["scale"], frame["h"] * frame["scale"]
            marks(key, "this is where it goes", [
                {"kind": "arrow", "points": [[0, h + 40], [w / 2, h + 40]]},
                {"kind": "text", "points": [[w / 2 + 20, h + 20]], "text": "here", "size": 36}])
    threading.Thread(target=go, daemon=True).start()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _stream(self, strokes, gap):
        """NDJSON as the Cockpit streams it (cockpit#85), each line flushed: HTTP/1.0, so the body ends when this closes."""
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        for i, stroke in enumerate(strokes):
            if i:
                time.sleep(gap)
            self.wfile.write(json.dumps(stroke).encode() + b"\n")
            self.wfile.flush()
        self.wfile.write(json.dumps({"done": True, "ms": 1}).encode() + b"\n")
        self.wfile.flush()

    def _report(self, extra):
        with open(REPORT, "a") as f:
            f.write(json.dumps({"method": self.command, "path": self.path, **extra}) + "\n")

    def do_GET(self):
        path = urllib.parse.unquote(self.path.split("?")[0])
        self._report({})
        with LOCK:
            if path == "/fake/strokes":
                return self._json(200, {"ok": True, "sends": STROKE_SENDS})
            if path.endswith("/whiteboard/responder"):
                query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                return self._json(200, responder_answer((query.get("board") or [""])[0]))
            if path == "/chat":
                rows = [summary(k, t) for k, t in THREADS.items() if t["messages"] or t.get("pinned")]
                return self._json(200, {"ok": True, "threads": rows})
            if path.startswith("/chat/"):
                t = THREADS.get(path[len("/chat/"):])
                return self._json(200, {"ok": True, "messages": t["messages"] if t else []})
            if path.startswith("/attachments/") and path[len("/attachments/"):] in IMAGES:
                data = IMAGES[path[len("/attachments/"):]]
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                return self.wfile.write(data)
        self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        path = urllib.parse.unquote(self.path.split("?")[0])
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        if path == "/attachments":
            self._report({"bytes": len(raw), "origin": self.headers.get("Origin")})
            if not is_picture(raw):
                return self._json(400, {"ok": False, "error": "not an image Cockpit accepts (png, jpeg, gif or webp)"})
            ref = "%s/%s.png" % (datetime.now().strftime("%Y-%m-%d"), secrets.token_hex(8))
            with LOCK:
                IMAGES[ref] = raw
            return self._json(200, {"ok": True, "ref": ref, "url": "/attachments/" + ref})
        data = json.loads(raw or b"{}")
        if path in ("/whiteboard/suggest", "/plain/whiteboard/suggest", "/many/whiteboard/suggest", "/far/whiteboard/suggest"):
            return self._suggest(data, path.split("/")[1])
        if path == "/whiteboard/strokes":
            # Story 419: the board's strokes before its picture; answered as the Cockpit does, never kept.
            strokes = data.get("strokes") or []
            with LOCK:
                STROKE_SENDS.append([s.get("id") for s in strokes])
            self._report({"strokes": len(strokes), "board": data.get("board"), "picture_id": data.get("picture_id"),
                          "frame": data.get("frame"), "origin": self.headers.get("Origin")})
            return self._json(200, {"ok": True, "board": data["board"], "picture_id": data["picture_id"],
                                    "count": len(strokes), "new": len(strokes), "erased": 0})
        if path.endswith("/whiteboard/responder"):
            # Story 659: the board's knob. A Larry board's suggest still draws here: the fake has one answerer.
            self._report({"body": data})
            if data.get("responder") not in ("haiku", "sonnet", "larry", None) or not data.get("board"):
                return self._json(400, {"ok": False, "error": "responder must be one of haiku, sonnet, larry, or null"})
            with LOCK:
                if data.get("responder") is None:
                    RESPONDERS.pop(data["board"], None)
                else:
                    RESPONDERS[data["board"]] = data["responder"]
                return self._json(200, responder_answer(data["board"]))
        if path == "/fake/larry-draws":
            return self._draws(data)
        if path == "/fake/skill-thread":
            with LOCK:
                THREADS.setdefault("igor2-88g.632", {"title": "idvorkin", "seen": "", "pinned": True,
                                                     "skill": "idvorkin", "messages": []})
            return self._json(200, {"ok": True})
        if path == "/chat" and NEW_DELAY:
            time.sleep(NEW_DELAY)
        self._report({"body": {k: v for k, v in data.items() if k != "text"}, "chars": len(data.get("text") or ""),
                      "origin": self.headers.get("Origin")})
        with LOCK:
            way = path.rsplit("/", 1)[-1]
            if path.startswith("/chat/") and way in ("archive", "unarchive"):
                if self.headers.get("Content-Type", "").split(";")[0].strip().lower() != "application/json":
                    return self._json(415, {"ok": False, "error": "application/json required"})
                t = THREADS.get(path[len("/chat/"):-len(way) - 1])
                if t and t.get("pinned"):
                    return self._json(409, {"ok": False, "error": "the pinned thread can't be archived"})
                if not t or (way == "archive" and not t["messages"]):
                    return self._json(404, {"ok": False, "error": "no such thread"})
                t["archived"] = way == "archive"
                return self._json(200, {"ok": True, "archived": t["archived"]})
            if path == "/chat-seen":
                t = THREADS.get(data.get("thread"))
                if t and t["messages"]:
                    t["seen"] = max(m["ts"] for m in t["messages"])
                return self._json(200, {"ok": True, "marked": 1})
            if path == "/chat":
                key = CREATED.get(data.get("id"))
                if not key:
                    key = "igor2-88g.%d" % (901 + len(CREATED))
                    CREATED[data.get("id")] = key
                    THREADS[key] = {"title": data.get("title") or "untitled", "messages": [], "seen": ""}
            elif path.startswith("/chat/"):
                key = path[len("/chat/"):]
                if key not in THREADS:
                    return self._json(404, {"ok": False, "error": "no such thread"})
            else:
                return self._json(404, {"ok": False, "error": "unknown endpoint"})
            t = THREADS[key]
            mine = [m for m in t["messages"] if m["id"] == data.get("id")]
            if mine:
                return self._json(200, {"ok": True, "thread": key, "message": mine[0], "duplicate": True})
            frame = data.get("frame")
            if frame is not None and not all(isinstance(frame.get(k), (int, float)) for k in ("x", "y", "w", "h")):
                return self._json(400, {"ok": False, "error": "frame needs x, y, w, h"})
            m = row(key, "igor", data.get("text") or "", data.get("id"), data.get("attachments"))
            for name in ("board", "picture_id", "frame"):
                if name in data:
                    m[name] = data[name]
            t["messages"].append(m)
            t["archived"] = False
            if data.get("board"):
                BOARD_MESSAGES[key] = m
        if t.get("skill"):
            skill_reply_later(key, data.get("text"))
            return self._json(200, {"ok": True, "thread": key, "message": m, "marker": None, "skill": t["skill"]})
        if data.get("board"):
            answer_board_later(key)
        else:
            reply_later(key, data.get("text"))
        self._json(200, {"ok": True, "thread": key, "message": m, "title": t["title"]})

    def _suggest(self, data, cockpit):
        w, h = data.get("width"), data.get("height")
        accepts = "application/x-ndjson" in self.headers.get("Accept", "")
        self._report({"turn": "claude", "width": w, "height": h, "text": data.get("text"),
                      "origin": self.headers.get("Origin")})
        if not data.get("image") or not w or not h:
            return self._json(400, {"ok": False, "error": "no picture"})
        circle = {"kind": "circle", "cx": w - 20, "cy": h / 2, "r": 40}
        if cockpit == "far":
            # At most 2 px a point: well below any first page and the blank one after it.
            return self._stream([{"kind": "circle", "cx": w / 2, "cy": h + 8000, "r": 40}], 0)
        if cockpit == "plain" or not accepts:
            return self._json(200, {"ok": True, "strokes": [circle]})
        if cockpit != "many":
            return self._stream([circle], 0)
        self._stream([circle,
                      {"kind": "line", "x1": 0, "y1": h + 40, "x2": w, "y2": h + 40},
                      {"kind": "arrow", "x1": 0, "y1": h + 90, "x2": w, "y2": h + 90},
                      {"kind": "polyline", "points": [[0, h + 140], [w / 3, h + 180], [w, h + 140]]},
                      {"kind": "arc", "cx": w / 2, "cy": h + 260, "r": 50, "start": 0, "end": 270},
                      {"kind": "label", "x": 0, "y": h + 380, "text": "here", "size": 48}], 0.4)

    def _draws(self, data):
        self._report({"unprompted": data.get("count")})
        with LOCK:
            if not BOARD_MESSAGES:
                return self._json(404, {"ok": False, "error": "no board thread"})
            key = list(BOARD_MESSAGES)[-1]
            marks(key, "", [{"kind": "circle", "cx": 40 * i, "cy": 40, "r": 20} for i in range(1, data["count"] + 1)])
        return self._json(200, {"ok": True})


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
