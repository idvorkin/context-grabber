#!/usr/bin/env python3
"""A stand-in for the Cockpit's chat routes, for the simulator (chat spec 2026-10-25; Cockpit story 129).

  scripts/native/fake-cockpit.py PORT REPORT

GET /chat, GET /chat/<key>, POST /chat (a new thread; with subject_id, the ask's own thread, #1387), POST /chat/<key>, POST /chat-seen, POST /attachments,
POST /chat/<key>/archive and /unarchive (#589; a new message brings a thread back; 415 unless application/json, as on
the Cockpit's write boundary),
GET /attachments/<ref>, the board store's /boards routes (fake_cockpit_store.py, stories 1330-1334), POST /whiteboard/strokes (story 419: counted and answered, never kept), POST /whiteboard/suggest (a ghost circle at the picture's right edge, streamed as NDJSON when the request
accepts it, as one JSON when not). A chat URL ending /plain gets a Cockpit that doesn't stream whatever is asked; one ending /many gets six marks of every kind, 400 ms apart. GET /fake/strokes says the ids of each POST /whiteboard/strokes so far, and the folds beside each (story 857). GET /fake/turns lists the board of each POST /whiteboard/suggest so far (story 1171). GET and POST /whiteboard/responder keep each board's knob (story 659), Sonnet by default. A message resent with an id the thread has is a duplicate, as on the Cockpit. Larry
answers every message of Igor's a second later ("Larry heard: <text>"), and a message with a board's picture with marks (cockpit#85: an arrow and a
label as kind + points, with the picture's picture_id and frame echoed). POST /fake/larry-draws {"count": n, "separate": bool} is a test's way to have him draw
unprompted on the newest board thread (n circles, as /whiteboard/suggest strokes; with "on_last_stroke": one circle on the
middle of the last stroke the board posted, story 1180; with "diagram": two boxes, each a rectangle with a label inside,
and an arrow between them, stories 1349-1351).
POST /fake/larry-says {"count": n,
"from": k} adds n replies of Larry's words, "Reply k: …" onwards, on the newest board thread (bead context-grabber-97s). POST /fake/larry-ops {"stale": false, "dy": 120}
is a test's way to have his next board answer be a batch of changes instead of marks (stories 814-817): room opened
below the middle of the picture he was sent (its frame, in board points) by dy, and a line of plain text in the gap,
on the message's own rev (one behind it with "behind", which the board still applies, story 961; before anything the
board remembers with "stale", which it refuses); with "kind": "connector_marks", marks instead: a
connector by points from the end of the first stroke sent to the start of the second (story 917); with "kind": "link_reply",
the usual arrow and label with a reply that ends on a Lavish link on the Cockpit's host (story 1127); with "kind": "small_label",
one label of 12-point letters asking for a 1-point pen, below the picture (stories 772, 779); with "kind": "words_only",
his usual words and no marks at all (story 1155); with "kind": "hold" (and "label", else none, as the Cockpit may send),
no answer at all: the picture's receipt goes seen with "waiting" {label, ts}, Larry holding for more, which his next
row (any of his) clears (story 929); with "kind": "ink_and_button", instead a purple line of his
across the gap below the picture and a green button under it whose tap_event is {"type": "make_room"}; with "kind":
"text_and_button", his text "room here" there instead of the line, the same button under it (bead
context-grabber-9d1). POST
/whiteboard/events takes the events a tap on one of his controls sends at once (stories 845, 846). GET /fake/ops says
what each board message reported back (its rev and op_result) and every events post. Every request is a JSON line in
REPORT.
POST /attachments takes pictures, PDFs and plain text, and answers anything else as the Cockpit does (400, #633; Cockpit
story 167, whose Word, Excel and PowerPoint files this stand-in doesn't tell apart, so refuses).
FAKE_COCKPIT_NEW_DELAY=<seconds> holds each POST /chat that long first, so a new chat's waiting state can be seen.
POST /chat/move {"thread", "message_id"} moves one of Igor's messages to a new thread, leaving a system row with moved_to
where it was (404 for no such message, 409 for one of Larry's), and Larry answers it there.
FAKE_COCKPIT_LARRY_DELAY=<seconds> is how long Larry takes to answer a board's picture, 1 by default: past 20 the board
offers Interrupt (story 777). FAKE_COCKPIT_BOARD_HOLD=<seconds> makes this a Cockpit that marks: Larry's answer marks the
picture's message done, and a later picture on that thread is held that long, once, before the Cockpit takes it, so past
20 the board says it is stuck and a resend of it lands at once (stories 775, 776; under 30, the app's own limit on the
request). POST /fake/larry-ops {"kind": "slow", "seconds": n} has Larry take n seconds over the next board answer only, so
the board offers Interrupt past 20 (stories 777, 805). POST /fake/board-stuck {"seconds": n} does FAKE_COCKPIT_BOARD_HOLD's
work for one thread and one picture: the newest board thread becomes one that marks (Igor's messages on it marked done,
and Larry's answers there marking his picture done), and its next picture is held n seconds before the Cockpit takes
it, so a test can see *Larry hasn't got the picture* and Retry (stories 775, 802).
Thread igor2-88g.593 is one Larry marks as looking done (#599). Thread igor2-88g.1268 is the pinned one, listed with no messages and refusing an archive (#598). By default this is a Cockpit with no skill threads (story 516). POST /fake/file-thread adds igor2-88g.633, titled The lease, whose one message from Igor carries a one-page PDF (story 1125). POST /fake/skill-thread is a test's way to add one (#632, cockpit#90), igor2-88g.632: pinned under Larry's, listed with no messages, refusing an archive, its replies from "idvorkin"; a message saying "fail" gets a failure row instead, with Igor's messages marked done either way, as on the Cockpit. Thread igor2-88g.592 holds one picture from Larry, all white and twice as tall as wide: on an iPhone it fills the
full-size view, under its Done (story 306).
Threads igor2-88g.603 and .604 hold the same picture from a whiteboard: board-603 (the UI test makes it with GRABBER_BOARD_FIXTURE) and board-gone-603, which no device has (stories 317, 319, #603).
Thread igor2-88g.1454 is the web ink board's: its board is ink-board-1454, which only the Cockpit's /ink page draws (story 569, #1454).
Decision cards (#878): POST /fake/asks {"open": true} adds (and resets, with what was answered) three open asks for GET /asks, the shape of the
Cockpit's normalize_ask with its `thread` (cockpit-7fr): igor2-88g.881 filed from chat igor2-88g.878 (thread names its
parent's chat), igor2-88g.879 on no chat (thread null), and igor2-88g.880 on a chat of its own bead, whose answer is always
refused (502, as bd failing); with "other": true too, igor2-88g.879 also has Larry's own option keyed "other", labelled "Something else" (stories 1129, 1130);
with "long": true too, igor2-88g.881's context runs to 80 lines, longer than any screen (story 1603);
{"open": false} removes them and their chats, so no other test sees an extra row. POST /act
answers one (409 already closed, or changed with the fresh ask when base_updated_at is stale), POST /close closes or
abandons, POST /snooze snoozes; GET /fake/answers lists every one of those posted. With "post_to_chat": true, a decided
/act or /close appends Igor's row to the ask's thread ("Decided: <label>", "Closed: <reason>", "Abandoned[: <reason>]",
"Dismissed[: <reason>]") and the answer gains chat {posted, thread, message, duplicate}, or {posted: false, thread, error}
for an ask with no chat, as serve.py's post_decision_to_chat.
Searching the asks (story 1132): GET /asks/search?q=<words>[&all=1] answers as the Cockpit's does (cockpit story 206) over
the open asks /fake/asks made and one answered ask, igor2-88g.882 "Renew the passport?" (answered "Go to the downtown
agency"), found only with all=1 but always counted: a /threads row each with matches; an empty q is a 400, and a q with
the word "bdfail" the 502 of bd failing.
The delta wire (cockpit story 346, "Chats load slow"): GET /chat and GET /chat/<key> send a weak ETag and answer 304
with no body to a matching If-None-Match; GET /chat/<key>?after=<id it holds> answers full: false with every row (a
merge by id gives the thread exactly), an unknown after, or a thread a move rewrote, answers full: true; both carry
cursor, the newest id.

Searching the chat list (stories 1616-1618, #1443): GET /chat?q=<words> answers as the Cockpit's does (cockpit story
335): GET /chat's rows, kept when every lowercased word is in the title or any message's text; a blank q is the plain
list. Thread igor2-88g.1443 "Travel docs", added by POST /fake/search-thread {"on": true} (and taken away with false,
since an extra row moves the list under the archive tests), says "passport" only in its first message. POST
/fake/search-down {"status": 502} makes a GET /chat with a q answer that status (0 brings it back); the plain list stays
up.
Question cards on a board (stories 880-886): GET /asks?snoozed=1 is GET /asks; POST /fake/larry-asks {"ask": id} opens
the asks as /fake/asks does (with "other" as there) and has Larry put a question card for that ask on the newest board thread ({kind: question,
ask, x, y} in the picture's pixels, with its frame); GET /ink/answers?ids=a,b answers with the question and answer of the
asks decided here, as ink_store.decision_answer reads them, and lists the rest as unknown.
Answer cards (#1439, stories 1355-1357): POST /fake/larry-answers {"text": words, "title"?, "re"?: ask id, "y"?} has Larry
put an answer card on the newest board thread ({kind: answer, text, x, y, title?, re?} in the picture's pixels, with its
frame).
Thread igor2-88g.820 holds one message of Igor's and Larry's answer, for Send to new chat (story 820; ChatMoveUITests
moves Igor's out, so a retry against the same fake Cockpit checks only the moved line; a full second run needs a
fresh one, as the chat UI script starts).
Thread igor2-88g.629 holds one question from Larry, for the press-and-hold menu (stories 518-519, 540-541), apart from .900, where the simulator's outbox can hold leftover smoke items; the chat UI script and the ladder's chat step clear the outbox's own leftovers for .629 first (forget-chat-thread.sh, #801, #812).
POST /ink/to-text {name, png} reads handwriting as the Cockpit's ink_text.py answers (stories 920-922): a PNG in base64
or a 400 with its reason, then {ok, text, too_long, advice, model, via} with the text "hello"; POST /fake/to-text
{"text": ..., "status": ..., "error": ...} sets what every later one answers ({} back to "hello"). GET /fake/to-text
lists the pictures' sizes so far.
The Cockpit down (stories 1604-1606): POST /fake/down {"status": 502} makes GET /chat and /chat/<key> answer that
status until a POST /fake/down {} brings them back.
A slow thread (story 1608): POST /fake/slow {"seconds": 6} makes each GET /chat/<key> wait that long before it
answers, until a POST /fake/slow {} makes them prompt again.
Recorded board sessions (story 1174): POST /fake/session {"name": "ops-move"} (one of the Cockpit's recordings, scrubbed,
under native/ContextCore/Tests/ContextCoreTests/Fixtures/board-sessions; "thread": a key to play it on instead of its own,
which is made titled as the Cockpit's host titles it, or "first" for the thread of the first board message after it, as
a board the app makes has a key nobody knows beforehand: the Board Lab's GRABBER_LAB_SESSION, story 1501) plays that session back: each strokes post is answered with its
count, new and erased against the board's send before, and the n-th of Igor's messages on that thread gets, a moment
later, Larry's replies and the receipts recorded after the n-th turn (his rows on the message's own board and picture,
his batch's base revision as far behind the message's rev as it was behind the recorded one). GET /fake/session says the
hint the Cockpit would wake Larry with for each message, the strokes answers, and how many answers are still to come;
{"name": null} stops it.
"""

import base64
import binascii
import hashlib
import json
import os
import re
import secrets
import sys
import threading
import time
import urllib.parse
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import fake_cockpit_store  # the board store's routes (stories 1330-1334), beside this file

PORT, REPORT = int(sys.argv[1]), sys.argv[2]
NEW_DELAY = float(os.environ.get("FAKE_COCKPIT_NEW_DELAY") or 0)
LARRY_DELAY = float(os.environ.get("FAKE_COCKPIT_LARRY_DELAY") or 1)
BOARD_HOLD = float(os.environ.get("FAKE_COCKPIT_BOARD_HOLD") or 0)
HELD = set()  # the ids of the board pictures FAKE_COCKPIT_BOARD_HOLD has held: each once, so a resend lands
STUCK = None  # POST /fake/board-stuck: {"key": the board thread, "seconds": its next picture's hold}, once (story 802)
MARKING = set()  # the board threads POST /fake/board-stuck made ones that mark: Larry's answer marks the picture done
LOCK = threading.Lock()
THREADS = {
    "igor2-88g.900": {"title": "Should the phone chat poll?", "messages": [], "seen": ""},
}
CREATED = {}
BOARD_MESSAGES = {}  # thread -> the newest message of Igor's carrying a board's picture
STROKE_SENDS = []  # the ids in each POST /whiteboard/strokes
FOLD_SENDS = []  # the folds beside each (story 857)
RESPONDERS = {}  # board -> haiku | sonnet | larry, as POST /whiteboard/responder set it (story 659)
SUGGESTS = []  # each POST /whiteboard/suggest's board, oldest first: a pause's turn, whoever answers (story 1171)
LARRY_OPS = None  # the next board answer's batch, as POST /fake/larry-ops armed it: once
LAST_STROKES = []  # the newest POST /whiteboard/strokes, for a connector mark between its first two (story 917)
TO_TEXT = {}  # what POST /ink/to-text answers, as POST /fake/to-text set it (stories 920-922)
TO_TEXT_SENDS = []  # each picture's name and bytes
TEXT_FIELDS = {"kind", "id", "text", "font", "x", "y", "w", "h", "color", "t"}  # a kept text in POST /whiteboard/strokes
EVENT_POSTS = []  # each POST /whiteboard/events body, with whether it woke Larry (story 846)
EVENT_TYPE = re.compile(r"[a-z][a-z0-9_]{0,31}")
WAKING = ("overlay_tap", "ghost_tap")  # a tap on his ghosts or controls wakes him; a plain tap never does


def take_events(data, size):
    """POST /whiteboard/events as the Cockpit takes it: its caps, its event types, and whether it wakes Larry."""
    events = data.get("events")
    if not data.get("board") or not isinstance(events, list):
        return 400, {"ok": False, "error": "board and events required"}
    if size > 256 * 1024 or len(events) > 200:
        return 413, {"ok": False, "error": "over the caps: 200 events, 256 KB"}
    for event in events:
        if not isinstance(event, dict) or not EVENT_TYPE.fullmatch(str(event.get("type", ""))):
            return 400, {"ok": False, "error": "every event needs a type like [a-z][a-z0-9_]{0,31}: %r" % event}
        if len(json.dumps(event)) > 8 * 1024:
            return 413, {"ok": False, "error": "an event over 8 KB"}
    woke = any(e["type"] in WAKING and e.get("target_id") for e in events)
    now = time.time()
    with LOCK:
        EVENT_POSTS.append(dict(data, woke=woke))
    return 200, {"ok": True, "board": data["board"], "rev": data.get("rev"), "events": len(events),
                 "ts": now, "ts_ms": int(now * 1000), "woke": woke}
OP_REPORTS = []  # each board message's rev and op_result, oldest first (story 818)


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


def document(raw):
    """The Cockpit's document sniff, cut down (Cockpit story 167): a PDF by its header, plain text by being UTF-8 with no
    control bytes that doesn't open with markup."""
    if raw.startswith(b"%PDF-"):
        return "pdf"
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        return None
    if not text or re.search(r"[\x00-\x08\x0b\x0e-\x1f\x7f]", text) or text.lstrip().startswith("<"):
        return None
    return "txt"


# One blank page, for the delivered file row's preview (story 1125).
MINIMAL_PDF = (b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
               b"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n")
LEASE_PDF = "2026-11-21/0000000000000633.pdf"

ATTACHMENT_TYPES = {"png": "image/png", "pdf": "application/pdf", "txt": "text/plain; charset=utf-8"}


def now():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def row(key, who, text, mid=None, attachments=None, board=None):
    r = {"id": mid or secrets.token_hex(6), "ts": now(), "thread": key, "who": who, "text": text,
         "source": "app" if who == "igor" else "cli"}
    if attachments:
        r["attachments"] = attachments
    if board:
        r["board"] = board
    if who == "larry":
        # Story 929: his next message clears his hold, as the Cockpit's does.
        for m in THREADS.get(key, {}).get("messages", []):
            m.get("receipt", {}).pop("waiting", None)
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
THREADS["igor2-88g.820"] = {"title": "A chat to leave", "seen": "", "messages": [  # story 820: Send to new chat
    row("igor2-88g.820", "igor", "Start a fresh plan for the garden"),
    row("igor2-88g.820", "larry", "Happy to, in its own chat."),
]}
THREADS["igor2-88g.817"] = {"title": "Laptops", "seen": "", "messages": [  # story 747: a table in a bubble
    row("igor2-88g.817", "larry", "Here's how they compare:\n| | Weight | Battery | Price |\n|---|:---:|---:|---|\n"
        "| Air | 1.2 kg | 18 h | $1,099 |\n| Pro 14 | 1.6 kg | 22 h | $1,999 |\n| XPS | 1.4 kg | 12 h | $1,299 |\n"
        "Want the cheapest?"),
]}
SEARCH_THREAD = {"title": "Travel docs", "seen": "", "messages": [  # story 1617: a word only in an older message
    row("igor2-88g.1443", "igor", "Renew the passport before the trip"),
    row("igor2-88g.1443", "larry", "Booked; see you there."),
]}


SLOW = 0.0  # story 1608: seconds each GET /chat/<key> waits before it answers; 0 answers at once
# #1454, story 569: a thread of the web ink board's turns, its board a web board (`ink-<name>`) no device draws. Last
# of the threads and dated long ago, so it moves no other test's row down the list.
THREADS["igor2-88g.1454"] = {"title": "A web board", "seen": "", "messages": [
    dict(row("igor2-88g.1454", "larry", "Your turn on the ink board (board-1454)", attachments=[WHITE_PICTURE],
             board="ink-board-1454"), ts="2026-01-01T00:00:00+00:00"),
]}

DOWN = 0  # stories 1604-1606: the status GET /chat and /chat/<key> answer while a test has the Cockpit down; 0 is up
ASKS = {}  # #878: id -> the open ask, as GET /asks lists it
ANSWERS = []  # every POST /act, /close and /snooze, as posted
DECIDED = {}  # id -> {title, label, note, action}: what GET /ink/answers gives for an ask decided here
ASK_CHATS = ("igor2-88g.878", "igor2-88g.880")


def ask(aid, title, options, default="", expires_in=None, thread=None):
    at = "2026-11-14T10:00:00Z"
    expires = (datetime.now().astimezone() + timedelta(seconds=expires_in)).isoformat(timespec="seconds") \
        if expires_in is not None else ""
    return {"id": aid, "title": title, "context": "Larry asks, for the simulator.",
            "options": [{"key": k, "label": label, "detail": detail} for k, label, detail in options],
            "recommendation_key": default, "recommendation_text": "", "priority": 2, "issue_type": "decision",
            "status": "open", "created_at": at, "updated_at": at, "default": default,
            "default_label": next((label for k, label, _ in options if k == default), ""), "expires_at": expires,
            "seconds_left": expires_in, "expired": bool(expires_in is not None and expires_in < 0), "thread": thread}


def open_asks(on, other=False, board=None, long=False):
    ASKS.clear()
    ANSWERED.clear()
    del ANSWERS[:]
    DECIDED.clear()
    for key in ASK_CHATS:
        THREADS.pop(key, None)
    if not on:
        return
    ASKS["igor2-88g.881"] = ask("igor2-88g.881", "Lunch on Friday: where?",
                                [("tacos", "Tacos", "the place by the office"), ("ramen", "Ramen", "a short walk")],
                                default="tacos", expires_in=5 * 3600, thread="igor2-88g.878")
    ASKS["igor2-88g.881"]["context"] = (
        "Larry asks about lunch.\nTacos are near the office.\nRamen is a short walk.\n"
        "Friday works for both.\nWe can meet at noon.\nEither place takes reservations."
    )
    if long:
        ASKS["igor2-88g.881"]["context"] = "\n".join(f"Line {n} of what Larry found about lunch." for n in range(1, 81))
    ASKS["igor2-88g.879"] = ask("igor2-88g.879", "Renew the gym for a year?",
                                [("yes", "Renew", ""), ("no", "Let it lapse", "")]
                                + ([("other", "Something else", "Type your own answer")] if other else []))
    if board:
        ASKS["igor2-88g.879"]["context"] = f"Larry asks about board {board}."
    ASKS["igor2-88g.880"] = ask("igor2-88g.880", "Move the review to Monday?",
                                [("move", "Move it", ""), ("keep", "Keep Friday", "")], expires_in=-3600,
                                thread="igor2-88g.880")
    at = "2026-10-20T10:00:00Z"
    ANSWERED["igor2-88g.882"] = {"id": "igor2-88g.882", "title": "Renew the passport?", "thread": None,
                                 "context": "Expires in March; the photo booth is downtown.", "options": [],
                                 "answer": "Go to the downtown agency", "created_at": at, "updated_at": at}
    THREADS["igor2-88g.878"] = {"title": "Lunch on Friday", "seen": "", "messages": [
        row("igor2-88g.878", "larry", "Where should we eat on Friday?")]}
    THREADS["igor2-88g.880"] = {"title": "The review", "seen": "", "messages": [
        row("igor2-88g.880", "larry", "Can the review move?")]}


ANSWERED = {}  # story 1132: id -> an answered ask, which GET /asks/search finds with all=1 and GET /asks never lists


def search_matches(a, terms):
    """threads.thread_matches as the fake reads it: each field past the title holding a term, at most three."""
    title = a["title"].lower()
    fields = [("context", a.get("context") or "")]
    fields += [("option", o["label"] + (" — " + o["detail"] if o.get("detail") else "")) for o in a.get("options", [])]
    fields += [("answer", a.get("answer") or "")]
    chat = THREADS.get(a.get("thread") or a["id"])
    fields += [("thread", m["text"]) for m in (chat["messages"] if chat else [])]
    out = []
    for field, text in fields:
        text = " ".join(text.split())
        low = text.lower()
        hit = next((t for t in terms if t in low and t not in title), None)
        if hit is None:
            continue
        at = max(0, low.index(hit) - 40)
        snippet = text[at:at + 140]
        out.append({"field": field, "snippet": ("…" if at else "") + snippet + ("…" if at + 140 < len(text) else "")})
    return out[:3]


def ask_search(query):
    """GET /asks/search?q=<words>[&all=1] as serve.py's handle_ask_search answers it (cockpit story 206): every word
    somewhere in the ask, case ignored; open asks first, answered behind all=1 but always counted; a /threads row each,
    plus matches. A q holding "bdfail" is the 502 of bd failing."""
    q = (query.get("q") or [""])[0]
    terms = q.lower().split()
    if not terms:
        return 400, {"ok": False, "error": "q is required"}
    if "bdfail" in terms:
        return 502, {"ok": False, "error": "bd: database is locked"}
    include = (query.get("all") or [""])[0] in ("1", "true")

    def text(a):
        chat = THREADS.get(a.get("thread") or a["id"])
        parts = [a["title"], a.get("context") or "", a.get("answer") or ""]
        parts += [o["label"] + " " + o["detail"] for o in a.get("options", [])]
        parts += [m["text"] for m in (chat["messages"] if chat else [])]
        return "\n".join(parts).lower()

    def found(asks, open_):
        return [{"key": a["id"], "needs_igor": open_, "open": open_, "last_ts": a["updated_at"], "topic": "",
                 "root": {"kind": "ask", "id": a["id"], "title": a["title"], "ts": a["created_at"], "priority": 2},
                 "items": [], "matches": search_matches(a, terms)}
                for a in asks if all(t in text(a) for t in terms)]

    waiting = found(ASKS.values(), True)
    answered = found(ANSWERED.values(), False)
    rows = waiting + (answered if include else [])
    return 200, {"ok": True, "fetched_at": now(), "q": q, "terms": terms, "inbox": len(ASKS), "open": len(waiting),
                 "answered": len(answered), "all": include, "count": len(rows), "threads": rows}


def decide(path, data):
    """POST /act, /close and /snooze as serve.py answers them; the ask leaves GET /asks once decided."""
    ANSWERS.append({"path": path, **data})
    a = ASKS.get(data.get("id"))
    if not a:
        return 409, {"ok": False, "error": "already closed", "id": data.get("id")}
    if path == "/act" and data.get("id") == "igor2-88g.880":
        return 502, {"ok": False, "error": "bd: database is locked"}
    if path != "/snooze" and data.get("base_updated_at") and data["base_updated_at"] != a["updated_at"]:
        return 409, {"ok": False, "error": "changed since you loaded it (server at %s)" % a["updated_at"], "ask": a}
    if path == "/snooze":
        del ASKS[data["id"]]
        return 200, {"ok": True, "id": data["id"], "snoozed_until": "2026-11-16T16:00:00Z"}
    if path == "/close" and data.get("action") == "close" and not (data.get("reason") or "").strip():
        return 400, {"ok": False, "error": "closing a bead needs a one-line reason"}
    del ASKS[data["id"]]
    DECIDED[data["id"]] = decision_answer(a["title"], data)
    answer = {"ok": True, "id": data["id"], "action": data.get("action"), "title": a["title"]}
    if data.get("post_to_chat") is True:
        answer["chat"] = post_to_chat(a, data)
    return 200, answer


def decision_answer(title, data):
    """ink_store.decision_answer: DECISION: <label>[\\nNote: <text>], or a close word and its reason as the note."""
    action = data.get("action")
    if action in ("dismiss", "close", "abandon"):
        label = {"dismiss": "Dismissed", "close": "Closed", "abandon": "Abandoned"}[action]
        note = (data.get("reason") or "").strip()
    else:
        text = (data.get("response") or "").strip().removeprefix("DECISION:").strip()
        label, _, note = text.partition("\nNote:")
        label, note = label.strip(), note.strip()
    return {"title": title, "label": label, "note": note, "action": action}


def post_to_chat(a, data):
    """serve.py's post_decision_to_chat: Igor's row in the ask's thread, once per ask."""
    thread = a.get("thread")
    if not thread or thread not in THREADS:
        return {"posted": False, "thread": None, "error": "the ask has no chat thread"}
    action = data.get("action")
    if action == "respond":
        text = "Decided: " + (data.get("response") or "").removeprefix("DECISION:").strip()
    else:
        word = {"dismiss": "Dismissed", "close": "Closed", "abandon": "Abandoned"}[action]
        reason = (data.get("reason") or "").strip()
        text = "%s: %s" % (word, reason) if reason else word
    mid = "act-" + a["id"]
    messages = THREADS[thread]["messages"]
    old = next((m for m in messages if m["id"] == mid), None)
    if old:
        return {"posted": True, "thread": thread, "message": old, "duplicate": True}
    m = row(thread, "igor", text, mid)
    m["source"] = data.get("source") or "cockpit"
    messages.append(m)
    return {"posted": True, "thread": thread, "message": m, "duplicate": False}


def summary(key, t):
    last = t["messages"][-1] if t["messages"] else {"ts": "", "who": "", "text": ""}
    larry = [m["ts"] for m in t["messages"] if m["who"] == "larry"]
    unread = len([ts for ts in larry if ts > t["seen"]])
    return {"key": key, "title": t["title"], "count": len(t["messages"]), "last_ts": last["ts"],
            "last_who": last["who"], "last_text": last["text"] or ("[image]" if t["messages"] else ""), "larry_ts": larry,
            "unread": unread, "done": t.get("archived", False), "archived": t.get("archived", False),
            "looks_done": t.get("looks_done", False), "pinned": t.get("pinned", False), "skill": t.get("skill"),
            "last_author": last.get("author", "")}


SEARCH_DOWN = 0  # story 1618: the status a GET /chat with a q answers while a test has the search down; 0 is up


def chat_search(query):
    """GET /chat?q=<words> as the Cockpit's answers it (cockpit story 335): GET /chat's rows, in its order, kept when
    every lowercased word is a substring of the title or of any message's text; a blank q is the plain list."""
    terms = ((query.get("q") or [""])[0]).lower().split()
    rows = []
    for k, t in THREADS.items():
        if not (t["messages"] or t.get("pinned")):
            continue
        hay = "\n".join([t["title"]] + [m.get("text") or "" for m in t["messages"]]).lower()
        if all(w in hay for w in terms):
            rows.append(summary(k, t))
    return 200, {"ok": True, "threads": rows}


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


def ops_batch(source, armed):
    """Larry's changes to the board he was sent (stories 814-817): room below the picture's middle, text in the gap."""
    frame, rev = source["frame"], source.get("rev", 0)
    if armed.get("kind") == "ink_and_button":
        bottom = frame["y"] + frame["h"]
        return {"board": source["board"], "base_rev": rev, "label": "ink and a button",
                "list": [{"op": "add_strokes", "strokes": [
                            {"id": "fake-line-1", "points": [[frame["x"] + 40, bottom + 30], [frame["x"] + 240, bottom + 30]],
                             "width": 6, "meta": {"group": "g1", "kind": "underline"}}]},
                         {"op": "overlay", "id": "fake-button-1", "kind": "button", "label": "Make room",
                          "rect": {"x": frame["x"] + 40, "y": bottom + 70, "w": 200, "h": 60},
                          "style": {"fill": "#00aa00", "color": "#ffffff"}, "tap_event": {"type": "make_room"}}]}
    if armed.get("kind") == "text_and_button":
        # Bead context-grabber-9d1: a text of his to keep while one of his controls shows.
        bottom = frame["y"] + frame["h"]
        return {"board": source["board"], "base_rev": rev, "label": "text and a button",
                "list": [{"op": "add_text", "id": "fake-text-1", "x": frame["x"] + 40, "y": bottom + 30,
                          "text": "room here", "font": "plain", "size": 28},
                         {"op": "overlay", "id": "fake-button-1", "kind": "button", "label": "Make room",
                          "rect": {"x": frame["x"] + 40, "y": bottom + 110, "w": 200, "h": 60},
                          "style": {"fill": "#00aa00", "color": "#ffffff"}, "tap_event": {"type": "make_room"}}]}
    below = frame["y"] + frame["h"] / 2
    dy = armed.get("dy", 120)
    # Story 961: "behind" is one revision before the picture, which the board still applies (it names nothing Igor
    # moved); "stale" is before anything the board remembers, which it refuses.
    base = -1 if armed.get("stale") else rev - 1 if armed.get("behind") else rev
    return {"board": source["board"], "base_rev": base, "label": "make room",
            "list": [{"op": "translate", "below_y": below, "dy": dy},
                     {"op": "add_text", "id": "fake-text-1", "x": frame["x"] + 40, "y": below + dy / 4,
                      "text": "room here", "font": "plain", "size": 28}]}


SESSIONS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                            "native/ContextCore/Tests/ContextCoreTests/Fixtures/board-sessions")
SESSION = None  # story 1174: the recorded board session being played back, as POST /fake/session chose it
RECEIPT_RANK = {"sent": 0, "received": 1, "seen": 2, "done": 3}


def load_session(name, thread=None):
    """A recorded session (the Cockpit's, scrubbed: scripts/native/board-sessions.py) ready to play on `thread` (its
    own recorded thread by default, made here as the Cockpit's host titles it): after the n-th of Igor's messages there,
    Larry's replies and the receipts recorded after the n-th turn, in order."""
    with open(os.path.join(SESSIONS_DIR, os.path.basename(name) + ".jsonl"), encoding="utf-8") as f:
        steps = [json.loads(line) for line in f if line.strip()]
    header, groups, turns = steps[0], [], []
    for step in steps[1:]:
        if step["step"] == "post" and step["route"].startswith("/chat/"):
            turns.append({"id": step["body"]["id"], "rev": step["body"].get("rev")})
            groups.append([])
        elif step["step"] in ("reply", "receipt") and groups:
            groups[-1].append(step)
    key = None if thread == "first" else thread or header["thread"]
    if key:
        THREADS.setdefault(key, {"title": "Board, " + key, "messages": [], "seen": ""})
    return {"name": header["name"], "thread": key, "groups": groups, "turns": turns, "next": 0, "ids": {},
            "strokes": {}, "answers": {}, "hints": {}, "pending": 0}


def strokes_answer(data):
    """Story 1174: count, new and erased against the board's send before, as the Cockpit answers."""
    ids = {s.get("id") for s in data.get("strokes") or []}
    before = SESSION["strokes"].get(data.get("board"))
    SESSION["strokes"][data.get("board")] = ids
    answer = {"count": len(ids), "new": len(ids - before) if before is not None else len(ids),
              "erased": len(before - ids) if before is not None else 0}
    SESSION["answers"][data.get("picture_id")] = answer
    return answer


def session_hint(key, data):
    """The hint the Cockpit wakes Larry with for this message (board contract, *What wakes the agent*)."""
    hint = "cockpit · chat · %s · #thread/%s" % (THREADS[key]["title"], key)
    board = data.get("board")
    if not board:
        return hint
    hint += " · board %s · draw back: chat.py reply --shapes" % board
    rev = data.get("rev")
    if isinstance(rev, int):
        hint += " · rev %d (move it: chat.py reply --ops, base_rev %d)" % (rev, rev)
    result = data.get("op_result")
    if isinstance(result, dict):
        state = "ok" if result.get("ok") else "refused (%s)" % result.get("reason")
        hint += " · op_result %s for %r at rev %s" % (state, result.get("label"), result.get("rev"))
        if result.get("missing_ids"):
            hint += ", %d ids missing" % len(result["missing_ids"])
    if data.get("events"):
        hint += " · %d events: whiteboard_events.py show %s --thread %s" % (len(data["events"]), board, key)
    answer = SESSION["answers"].get(data.get("picture_id"))
    if answer:
        hint += " · strokes %d (%d new): whiteboard_strokes.py render %s %s --thread %s --out <png>" % (
            answer["count"], answer["new"], board, data["picture_id"], key)
    return hint


def play_session_later(key, m, data):
    """Larry's recorded answer to this turn, a moment later: his rows (on this message's board and picture, his batch's
    base revision as far behind this message's as it was behind the recorded one) and the recorded receipts."""
    session = SESSION  # a session chosen again meanwhile doesn't take this answer's place
    n = session["next"]
    session["next"] += 1
    if n >= len(session["turns"]):
        return
    turn, group = session["turns"][n], session["groups"][n]
    session["ids"][turn["id"]] = m["id"]
    session["pending"] += 1

    def go():
        time.sleep(LARRY_DELAY)
        with LOCK:
            for step in group:
                if step["step"] == "reply":
                    r = row(key, "larry", step["text"])
                    recorded = step["expect"]["row"]
                    for name in ("frame", "shapes", "ops", "board", "picture_id"):
                        if name in recorded:
                            r[name] = json.loads(json.dumps(recorded[name]))
                    if "board" in r and data.get("board"):
                        r["board"] = data["board"]
                    if "picture_id" in r and data.get("picture_id"):
                        r["picture_id"] = data["picture_id"]
                    if "ops" in r:
                        r["ops"]["board"] = data.get("board") or r["ops"]["board"]
                        if isinstance(data.get("rev"), int) and isinstance(turn["rev"], int):
                            r["ops"]["base_rev"] += data["rev"] - turn["rev"]
                    THREADS[key]["messages"].append(r)
                    continue
                for target in step["targets"]:
                    mine = next((x for x in THREADS[key]["messages"] if x["id"] == session["ids"].get(target)), None)
                    if mine is None:
                        continue
                    receipt = mine.setdefault("receipt", {"state": "received"})
                    if step["state"] == "waiting":
                        receipt["waiting"] = {"ts": now(), **({"label": step["label"]} if "label" in step else {})}
                    elif RECEIPT_RANK.get(step["state"], -1) > RECEIPT_RANK.get(receipt.get("state"), 0):
                        receipt["state"] = step["state"]
                        receipt[step["state"] + "_ts"] = now()
            session["pending"] -= 1
    threading.Thread(target=go, daemon=True).start()


def answer_board_later(key):
    def go():
        global LARRY_OPS
        delay = LARRY_DELAY
        with LOCK:
            if LARRY_OPS is not None and LARRY_OPS.get("kind") == "slow":
                # Stories 777, 805: this one answer takes that long, past the board's twenty seconds.
                delay, LARRY_OPS = float(LARRY_OPS.get("seconds", 40)), None
        time.sleep(delay)
        with LOCK:
            if BOARD_HOLD or key in MARKING:
                BOARD_MESSAGES[key]["receipt"] = {"state": "done"}
            if LARRY_OPS is not None and LARRY_OPS.get("kind") == "connector_marks":
                # Story 917: a connector mark from the end of the first stroke to the start of the second, by points.
                LARRY_OPS = None
                frame = BOARD_MESSAGES[key]["frame"]
                ink = [s["points"] for s in LAST_STROKES if s.get("points")]
                if len(ink) >= 2:
                    px = lambda p: [(p[0] - frame["x"]) * frame["scale"], (p[1] - frame["y"]) * frame["scale"]]
                    (x1, y1), (x2, y2) = px(ink[0][-1]), px(ink[1][0])
                    marks(key, "these two go together", [{"kind": "connector", "x1": x1, "y1": y1, "x2": x2, "y2": y2}])
                    return
            said = "this is where it goes"
            if LARRY_OPS is not None and LARRY_OPS.get("kind") == "link_reply":
                # Story 1127 (#1138): his reply links a Lavish page, which the board's conversation shows as a chip.
                LARRY_OPS = None
                said += ", the map: https://c-5004.squeaker-teeth.ts.net:8444/session/7d7f837c3898ed37."
            if LARRY_OPS is not None and LARRY_OPS.get("kind") == "hold":
                # Story 929: he has seen the picture and holds for more: its receipt seen and waiting, and no row.
                label, LARRY_OPS = LARRY_OPS.get("label"), None
                stamp = now()
                waiting = {"ts": stamp}
                if label:
                    waiting["label"] = label
                BOARD_MESSAGES[key]["receipt"] = {"state": "seen", "received_ts": stamp, "seen_ts": stamp,
                                                  "waiting": waiting}
                return
            if LARRY_OPS is not None and LARRY_OPS.get("kind") == "small_label":
                # Stories 772, 779 (bead context-grabber-z8o): letters as small as Larry's that vanished once kept on the
                # iPad, 12 points on the board (12 x the frame's scale in picture pixels), asking for a 1-point pen: under
                # what PencilKit draws, as a ninth of their height was before Igor's pen reached his labels (#949). 80
                # points below the picture, clear of a paste's selection menu. "pen": <points> asks for that pen instead, as
                # Igor's own 2.68 (bead context-grabber-qko5: a whole small label at a normal pen read as cut).
                pen, LARRY_OPS = LARRY_OPS.get("pen", 1), None
                frame = BOARD_MESSAGES[key]["frame"]
                w, h = frame["w"] * frame["scale"], frame["h"] * frame["scale"]
                marks(key, "small words", [
                    {"kind": "text", "points": [[w / 4, h + 80 * frame["scale"]]], "text": "small",
                     "size": 12 * frame["scale"], "pen": pen * frame["scale"]}])
                return
            if LARRY_OPS is not None and LARRY_OPS.get("kind") == "words_only":
                # Story 1155: his answer is words alone, so a test's unprompted marks after it are the only ones to keep.
                LARRY_OPS = None
                marks(key, said, [])
                return
            if LARRY_OPS is not None:
                source, armed, LARRY_OPS = BOARD_MESSAGES[key], LARRY_OPS, None
                r = row(key, "larry", "made room")
                r.update(ops=ops_batch(source, armed), picture_id=source["picture_id"], board=source["board"])
                THREADS[key]["messages"].append(r)
                return
            frame = BOARD_MESSAGES[key]["frame"]
            w, h = frame["w"] * frame["scale"], frame["h"] * frame["scale"]
            marks(key, said, [
                {"kind": "arrow", "points": [[0, h + 40], [w / 2, h + 40]]},
                {"kind": "text", "points": [[w / 2 + 20, h + 20]], "text": "here", "size": 36}])
    threading.Thread(target=go, daemon=True).start()


def thread_answer(t, query):
    """GET /chat/<key> on the delta wire (cockpit story 346, docs/chat-parity.md). The ETag names the thread's state,
    whatever the cursor. With `after` a message it holds, the answer is `full: false` with every row from the start: a
    client merging by id ends with exactly the thread, which is all the contract promises, and an older row whose
    receipt moved on is always among them. An unknown `after`, or none, is the whole thread, `full: true`."""
    messages = t["messages"] if t else []
    tag = "W/\"" + hashlib.sha1(json.dumps(messages, sort_keys=True).encode()).hexdigest()[:16] + "\""
    after = (query.get("after") or [""])[0]
    full = not after or after not in {m.get("id") for m in messages} or bool(t and t.get("rewritten"))
    cursor = messages[-1]["id"] if messages else ""
    return tag, {"ok": True, "full": full, "cursor": cursor, "messages": messages}


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

    def _tagged(self, etag, obj):
        """A 200 carrying a weak ETag, or a 304 with no body when the client already holds it (cockpit story 346)."""
        if self.headers.get("If-None-Match") == etag:
            self.send_response(304)
            self.send_header("ETag", etag)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("ETag", etag)
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
        store = fake_cockpit_store.get(path, urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query))
        if store is not None:
            return self._json(*store)
        with LOCK:
            if path == "/asks":
                return self._json(200, {"ok": True, "fetched_at": now(), "asks": list(ASKS.values())})
            if path == "/asks/search":
                return self._json(*ask_search(urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)))
            if path == "/ink/answers":
                query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                ids = [i for i in (query.get("ids") or [""])[0].split(",") if i]
                return self._json(200, {"ok": True, "answers": {i: DECIDED[i] for i in ids if i in DECIDED},
                                        "unknown": [i for i in ids if i not in DECIDED]})
            if path == "/fake/answers":
                return self._json(200, {"ok": True, "answers": ANSWERS})
            if path == "/fake/turns":
                return self._json(200, {"ok": True, "turns": SUGGESTS})
            if path == "/fake/session":
                return self._json(200, {"ok": True, "session": SESSION and {
                    k: SESSION[k] for k in ("name", "thread", "next", "pending", "hints", "answers")}})
            if path == "/fake/strokes":
                return self._json(200, {"ok": True, "sends": STROKE_SENDS, "folds": FOLD_SENDS})
            if path == "/fake/to-text":
                return self._json(200, {"ok": True, "sends": TO_TEXT_SENDS})
            if path == "/fake/ops":
                return self._json(200, {"ok": True, "armed": LARRY_OPS is not None, "reports": OP_REPORTS,
                                        "event_posts": EVENT_POSTS})
            if path.endswith("/whiteboard/responder"):
                query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                return self._json(200, responder_answer((query.get("board") or [""])[0]))
            if SLOW and path.startswith("/chat/"):
                time.sleep(SLOW)
            if DOWN and (path == "/chat" or path.startswith("/chat/")):
                return self._json(DOWN, {"ok": False, "error": "Bad Gateway"})
            if path == "/chat":
                query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                if (query.get("q") or [""])[0].strip():
                    if SEARCH_DOWN:
                        return self._json(SEARCH_DOWN, {"ok": False, "error": "bd: database is locked"})
                    return self._json(*chat_search(query))
                rows = [summary(k, t) for k, t in THREADS.items() if t["messages"] or t.get("pinned")]
                answer = {"ok": True, "threads": rows}
                # The list's ETag hashes the answer, one per query (`?fields=summary` answers the same rows here).
                tag = "W/\"" + hashlib.sha1(json.dumps([sorted(query.items()), answer]).encode()).hexdigest()[:16] + "\""
                return self._tagged(tag, answer)
            if path.startswith("/chat/"):
                return self._tagged(*thread_answer(THREADS.get(path[len("/chat/"):]),
                                                   urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)))
            if path.startswith("/attachments/") and path[len("/attachments/"):] in IMAGES:
                data = IMAGES[path[len("/attachments/"):]]
                self.send_response(200)
                self.send_header("Content-Type", ATTACHMENT_TYPES[path.rsplit(".", 1)[1]])
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                return self.wfile.write(data)
        self._json(404, {"ok": False, "error": "not found"})

    def do_PUT(self):
        path = urllib.parse.unquote(self.path.split("?")[0])
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        if path.startswith("/boards/assets/"):
            self._report({"bytes": len(raw)})
            return self._json(*fake_cockpit_store.put_asset(path, raw))
        self._json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        global SESSION
        path = urllib.parse.unquote(self.path.split("?")[0])
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0))
        if path == "/boards" or path.startswith("/boards/") or path.startswith("/fake/store"):
            self._report({})
            try:
                data = json.loads(raw or b"{}")
            except ValueError:
                return self._json(400, {"ok": False, "error": "not JSON"})
            store = fake_cockpit_store.post(path, data if isinstance(data, dict) else {})
            if store is not None:
                return self._json(*store)
        if path == "/attachments":
            self._report({"bytes": len(raw), "origin": self.headers.get("Origin")})
            ext = "png" if is_picture(raw) else document(raw)
            if ext is None:
                return self._json(400, {"ok": False, "error": "not an image or document Cockpit accepts (png, jpeg, gif, "
                                        "webp, pdf, plain text, docx, xlsx or pptx)"})
            ref = "%s/%s.%s" % (datetime.now().strftime("%Y-%m-%d"), secrets.token_hex(8), ext)
            with LOCK:
                IMAGES[ref] = raw
            return self._json(200, {"ok": True, "ref": ref, "url": "/attachments/" + ref})
        data = json.loads(raw or b"{}")
        if path == "/ink/to-text":
            return self._to_text(data)
        if path == "/fake/search-thread":
            with LOCK:
                if data.get("on"):
                    THREADS["igor2-88g.1443"] = SEARCH_THREAD
                else:
                    THREADS.pop("igor2-88g.1443", None)
            return self._json(200, {"ok": True, "on": "igor2-88g.1443" in THREADS})
        if path == "/fake/search-down":
            global SEARCH_DOWN
            with LOCK:
                SEARCH_DOWN = int(data.get("status") or 0)
            return self._json(200, {"ok": True, "status": SEARCH_DOWN})
        if path == "/fake/slow":
            global SLOW
            with LOCK:
                SLOW = float(data.get("seconds") or 0)
            return self._json(200, {"ok": True, "slow": SLOW})
        if path == "/fake/down":
            global DOWN
            with LOCK:
                DOWN = int(data.get("status") or 0)
            return self._json(200, {"ok": True, "down": DOWN})
        if path == "/fake/to-text":
            global TO_TEXT
            with LOCK:
                TO_TEXT = data
            return self._json(200, {"ok": True})
        if path in ("/whiteboard/suggest", "/plain/whiteboard/suggest", "/many/whiteboard/suggest"):
            return self._suggest(data, path.split("/")[1])
        if path == "/whiteboard/strokes":
            # Story 419: the board's strokes before its picture; answered as the Cockpit does, never kept.
            strokes = data.get("strokes") or []
            # As whiteboard_strokes.py: a text is exactly these fields; any other entry needs its points.
            for s in strokes:
                if s.get("kind") == "text":
                    if not {"kind", "id", "text", "x", "y", "w", "h"} <= set(s) <= TEXT_FIELDS:
                        return self._json(400, {"ok": False, "error": "a text entry has %s" % sorted(s)})
                    if s.get("font", "print") not in ("print", "hand"):
                        return self._json(400, {"ok": False, "error": "text font must be print or hand"})
                elif s.get("kind") is not None or not s.get("points"):
                    return self._json(400, {"ok": False, "error": "a stroke needs points"})
            # Story 857: folded sections beside the strokes, as whiteboard_strokes.py's _folds takes them.
            folds = data.get("folds")
            global LAST_STROKES
            with LOCK:
                LAST_STROKES = strokes
            if folds is not None:
                ok = isinstance(folds, list) and all(
                    isinstance(f, dict) and isinstance(f.get("header"), str) and isinstance(f.get("lines"), int)
                    and isinstance(f.get("strokes"), list) and isinstance(f.get("header_strokes", []), list)
                    for f in folds)
                if not ok:
                    return self._json(400, {"ok": False, "error": "folds must be [{header, header_strokes, lines, strokes}]"})
            with LOCK:
                STROKE_SENDS.append([s.get("id") for s in strokes])
                FOLD_SENDS.append(folds or [])
            self._report({"strokes": len(strokes), "board": data.get("board"), "picture_id": data.get("picture_id"),
                          "frame": data.get("frame"), "origin": self.headers.get("Origin")})
            with LOCK:
                answer = strokes_answer(data) if SESSION else {"count": len(strokes), "new": len(strokes), "erased": 0}
            return self._json(200, {"ok": True, "board": data["board"], "picture_id": data["picture_id"], **answer})
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
        if path == "/fake/asks":
            with LOCK:
                open_asks(bool(data.get("open")), other=bool(data.get("other")), board=data.get("board"),
                          long=bool(data.get("long")))
            return self._json(200, {"ok": True, "asks": len(ASKS)})
        if path in ("/act", "/close", "/snooze"):
            self._report({"body": data, "origin": self.headers.get("Origin")})
            with LOCK:
                return self._json(*decide(path, data))
        if path == "/fake/session":
            name = data.get("name")
            if name and not os.path.exists(os.path.join(SESSIONS_DIR, os.path.basename(name) + ".jsonl")):
                return self._json(404, {"ok": False, "error": "no recorded session %s" % name})
            with LOCK:
                SESSION = load_session(name, data.get("thread")) if name else None
            return self._json(200, {"ok": True, "thread": SESSION and SESSION["thread"]})
        if path == "/fake/larry-draws":
            return self._draws(data)
        if path == "/fake/larry-says":
            # Bead context-grabber-97s: more of Larry's words on the newest board thread than the panel holds.
            with LOCK:
                if not BOARD_MESSAGES:
                    return self._json(404, {"ok": False, "error": "no board thread"})
                key = list(BOARD_MESSAGES)[-1]
                start = int(data.get("from", 1))
                for n in range(start, start + int(data.get("count", 1))):
                    THREADS[key]["messages"].append(row(key, "larry", f"Reply {n}: " + "a long line of Larry's, " * 6))
            return self._json(200, {"ok": True})
        if path == "/fake/larry-asks":
            with LOCK:
                if not BOARD_MESSAGES:
                    return self._json(404, {"ok": False, "error": "no board thread"})
                open_asks(True, other=bool(data.get("other")))
                key = list(BOARD_MESSAGES)[-1]
                marks(key, "a question for you", [{"kind": "question", "ask": data.get("ask"), "x": 40, "y": 40}])
            return self._json(200, {"ok": True})
        if path == "/fake/larry-answers":
            # Answer cards (#1439, stories 1355-1357): Larry's answer on the newest board thread, {kind: answer, text,
            # x, y, title?, re?} in the picture's pixels, with its frame.
            with LOCK:
                if not BOARD_MESSAGES:
                    return self._json(404, {"ok": False, "error": "no board thread"})
                key = list(BOARD_MESSAGES)[-1]
                shape = {"kind": "answer", "text": data.get("text", ""), "x": 40, "y": data.get("y", 120)}
                for field in ("title", "re"):
                    if data.get(field):
                        shape[field] = data[field]
                marks(key, "an answer for you", [shape])
            return self._json(200, {"ok": True})
        if path == "/whiteboard/events":
            self._report({"body": data})
            status, answer = take_events(data, len(raw))
            return self._json(status, answer)
        if path == "/fake/larry-ops":
            global LARRY_OPS
            with LOCK:
                LARRY_OPS = data
            return self._json(200, {"ok": True})
        if path == "/fake/board-stuck":
            # Stories 775, 802: the newest board thread marks Igor's messages (those there are marked done), and its next
            # picture is held that long, once, before the Cockpit takes it: past 20 the board says it is stuck, and a
            # resend of it lands at once. {"seconds": 0} disarms it.
            global STUCK
            with LOCK:
                key = next(reversed(BOARD_MESSAGES), None)
                if key is None or not data.get("seconds"):
                    STUCK = None
                    return self._json(200 if not data.get("seconds") else 409, {"ok": key is not None})
                MARKING.add(key)
                for m in THREADS[key]["messages"]:
                    if m["who"] == "igor":
                        m["receipt"] = {"state": "done"}
                STUCK = {"key": key, "seconds": float(data["seconds"])}
            return self._json(200, {"ok": True, "thread": key})
        if path == "/fake/file-thread":
            # Story 1125 (#633): a PDF Igor sent, delivered, on a thread of its own so no other test sees it.
            with LOCK:
                IMAGES[LEASE_PDF] = MINIMAL_PDF
                THREADS["igor2-88g.633"] = {"title": "The lease", "seen": "", "messages": [
                    row("igor2-88g.633", "igor", "Lease.pdf\n\nread page 3", attachments=[LEASE_PDF])]}
            return self._json(200, {"ok": True})
        if path == "/fake/skill-thread":
            with LOCK:
                THREADS.setdefault("igor2-88g.632", {"title": "idvorkin", "seen": "", "pinned": True,
                                                     "skill": "idvorkin", "messages": []})
            return self._json(200, {"ok": True})
        if path == "/chat" and NEW_DELAY:
            time.sleep(NEW_DELAY)
        if BOARD_HOLD and data.get("board") and path[len("/chat/"):] in BOARD_MESSAGES and data.get("id") not in HELD:
            HELD.add(data.get("id"))
            time.sleep(BOARD_HOLD)
        stuck = STUCK
        if stuck and data.get("board") and path == "/chat/" + stuck["key"] and data.get("id") not in HELD:
            HELD.add(data.get("id"))
            STUCK = None
            time.sleep(stuck["seconds"])
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
            if path == "/chat/move":
                t = THREADS.get(data.get("thread"))
                m = next((m for m in t["messages"] if m["id"] == data.get("message_id")), None) if t else None
                if not m:
                    return self._json(404, {"ok": False, "error": "no such message"})
                if m["who"] != "igor":
                    return self._json(409, {"ok": False, "error": "only your own messages can be moved"})
                key = "igor2-88g.%d" % (901 + len(CREATED))
                CREATED["moved:" + m["id"]] = key
                title = (m["text"] or "untitled").splitlines()[0]
                line = row(data["thread"], "system", "Moved to a new chat")
                line.update(kind="moved", moved_to=key)
                t["messages"][t["messages"].index(m)] = line
                # A message a client holds is gone: its next delta read is the whole thread (cockpit story 346).
                t["rewritten"] = True
                m["thread"] = key
                THREADS[key] = {"title": title, "messages": [m], "seen": ""}
                reply_later(key, m["text"])
                return self._json(200, {"ok": True, "thread": key, "title": title})
            if path == "/chat-seen":
                t = THREADS.get(data.get("thread"))
                if t and t["messages"]:
                    t["seen"] = max(m["ts"] for m in t["messages"])
                return self._json(200, {"ok": True, "marked": 1})
            if path == "/chat" and data.get("subject_id"):
                # Stories 1316, 1317 (#1387): every ask has its own thread, keyed by the ask's id.
                key = data["subject_id"]
                THREADS.setdefault(key, {"title": "ask " + key, "messages": [], "seen": ""})
            elif path == "/chat":
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
            for name in ("board", "picture_id", "frame", "rev", "picture_folds"):
                if name in data:
                    m[name] = data[name]
            t["messages"].append(m)
            t["archived"] = False
            if data.get("board"):
                BOARD_MESSAGES[key] = m
                OP_REPORTS.append({"rev": data.get("rev"), "op_result": data.get("op_result"),
                                   "events": len(data.get("events") or []),
                                   "event_types": [e.get("type") for e in data.get("events") or []]})
        if SESSION and (key == SESSION["thread"] or (SESSION["thread"] is None and data.get("board"))):
            with LOCK:
                SESSION["thread"] = key  # "first": the thread of the first board message after it was chosen
                SESSION["hints"][m["id"]] = session_hint(key, data)
                play_session_later(key, m, data)
            return self._json(200, {"ok": True, "thread": key, "message": m, "title": t["title"]})
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
        with LOCK:
            SUGGESTS.append(data.get("board"))
        if not data.get("image") or not w or not h:
            return self._json(400, {"ok": False, "error": "no picture"})
        circle = {"kind": "circle", "cx": w - 20, "cy": h / 2, "r": 40}
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

    def _to_text(self, data):
        # As ink_text.parse and post: the same checks and reasons, then the armed answer.
        self._report({"to_text": data.get("name"), "png_chars": len(data.get("png") or ""),
                      "origin": self.headers.get("Origin")})
        if not isinstance(data.get("png"), str):
            return self._json(400, {"ok": False, "error": "send {png: <base64>}"})
        try:
            png = base64.b64decode(data["png"], validate=True)
        except (binascii.Error, ValueError):
            return self._json(400, {"ok": False, "error": "png is not base64"})
        if not png.startswith(b"\x89PNG"):
            return self._json(400, {"ok": False, "error": "png is not a PNG"})
        with LOCK:
            TO_TEXT_SENDS.append({"name": data.get("name"), "bytes": len(png)})
            armed = dict(TO_TEXT)
        if armed.get("status", 200) != 200:
            return self._json(armed["status"], {"ok": False, "error": armed.get("error") or "the model failed"})
        text = armed.get("text", "hello")
        return self._json(200, {"ok": True, "text": text[:500], "too_long": len(text) > 500, "advice": [],
                                "model": "fake", "via": "fake"})

    def _draws(self, data):
        self._report({"unprompted": data.get("count")})
        with LOCK:
            if not BOARD_MESSAGES:
                return self._json(404, {"ok": False, "error": "no board thread"})
            key = list(BOARD_MESSAGES)[-1]
            gap = data.get("gap", 40)
            if data.get("shape") == "square":
                circles = [{"kind": "rect", "x": gap * i - 20, "y": 20, "w": 40, "h": 40} for i in range(1, data.get("count", 0) + 1)]
            else:
                circles = [{"kind": "circle", "cx": gap * i, "cy": 40, "r": 20} for i in range(1, data.get("count", 0) + 1)]
            if data.get("diagram"):
                # Stories 1349-1351 (#1528): two boxes, each a rectangle with a label inside, and an arrow between them.
                circles = [
                    {"kind": "rect", "x": 20, "y": 80, "w": 120, "h": 60},
                    {"kind": "label", "x": 40, "y": 120, "text": "Box A", "size": 20},
                    {"kind": "rect", "x": 260, "y": 80, "w": 120, "h": 60},
                    {"kind": "label", "x": 280, "y": 120, "text": "Box B", "size": 20},
                    {"kind": "arrow", "x1": 145, "y1": 110, "x2": 255, "y2": 110},
                ]
            ink = [st["points"] for st in LAST_STROKES if st.get("points")]
            if data.get("on_last_stroke") and ink:
                # Story 1180: a circle on the last stroke, which it then holds to.
                frame = BOARD_MESSAGES[key]["frame"]
                x, y = ink[-1][len(ink[-1]) // 2][:2]
                scale = frame.get("scale", 1)
                circles = [{"kind": "circle", "cx": (x - frame["x"]) * scale, "cy": (y - frame["y"]) * scale,
                            "r": 12 * scale}]
            if data.get("separate"):
                # Story 1154: one reply per circle, so Keep beside each keeps it alone.
                for circle in circles:
                    marks(key, "", [circle])
            else:
                marks(key, "", circles)
        return self._json(200, {"ok": True})


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
