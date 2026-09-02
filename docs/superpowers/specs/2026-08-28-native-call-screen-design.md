# A Call That Survives the Lock — Native Call Screen Design Spec

**Status:** Implemented (phase 1) — on-device acceptance pending
**Date:** 2026-08-28
**Owner:** Igor
**Issue:** [#74](https://github.com/idvorkin/context-grabber/issues/74) (this) · subsumes [#73](https://github.com/idvorkin/context-grabber/issues/73) · bead `context-grabber-e19`
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md), [Cockpit Audio Bridge](2026-08-28-cockpit-audio-bridge-design.md)
**Changes:** [Call deep link](2026-08-28-cockpit-call-deep-link-design.md) — `grabber://call` now lands here, not on the Cockpit page
**Amended:** 2026-08-29, [#90](https://github.com/idvorkin/context-grabber/issues/90) — a calling treatment while the bridge answers; mute folds into the voice indicator; a round red hang-up
**Amended:** 2026-08-29, [#98](https://github.com/idvorkin/context-grabber/issues/98) — a voice picker beside the microphone picker
**Amended:** 2026-09-02, [#95](https://github.com/idvorkin/context-grabber/issues/95) / [#105](https://github.com/idvorkin/context-grabber/issues/105) / [#106](https://github.com/idvorkin/context-grabber/issues/106) — audio that stops mid-call heals itself; the greeting waits for the speaker; the log counts both directions and survives a freeze

## Summary

Igor, on a call, 2026-08-28 09:40: *"I want to be able to do in Context
Grabber a native UI for calling, so it doesn't have to be in a web view.
Basically, instead of Cockpit, I just have the calling tab, and I want it to
be native so that when my phone locks, the call can keep going."* And later,
on how: *"I'm assuming you just use the backend services, or expose backend
services, and make another UI on top of Cockpit."*

That assumption is right, and it is the whole design. A Larry call is one
socket to the voice bridge: microphone audio goes up, Larry's voice comes
down, and a handful of small messages describe what is happening — captions,
"Larry interrupted", "the call ended because…". Everything that makes it a
*conversation* — who is speaking, when a turn ends, "hang up" meaning hang
up, the two-minute idle rule, Larry's memory and tools — lives on the
server. The Cockpit page contributes exactly three things: it opens the
microphone, it plays the audio without gaps, and it draws the captions.

Today those three things run inside a web view, and iOS suspends a web
view's microphone the moment the screen locks. The call dies mid-sentence.
Keeping the screen awake ([#72](https://github.com/idvorkin/context-grabber/issues/72))
papers over it; a deliberate lock, a pocket, a Siri interruption still kill
the call.

This spec moves those three things into the app itself. A new **Call** tab
does what the Cockpit's Call tab does, against the same bridge, with no web
page in the loop — and because the app owns the audio, iOS treats it like a
phone call: the screen can lock, the phone can go in a pocket, and Larry
keeps talking.

## Goals

- A call keeps going through a screen lock, the app going to the
  background, and the phone being put down — for as long as Igor and Larry
  are still talking.
- Same call as today: same backends, same Larry, same captions, same spoken
  controls, same endings. Nothing about the *conversation* changes.
- The microphone and output pickers that the audio bridge fought for are
  simply there — the native screen has the real roster without a bridge.
- One tap (or one `grabber://call` link) from anywhere to a live call.
- No new backend. The bridge that serves the page serves the app.

## Non-goals

- **Replacing the Cockpit page's Call tab.** The page keeps its call for
  laptops and for anyone not in the app. The two are peers on the same
  bridge.
- **The Cockpit page's other surfaces.** Decisions, PRs, history, the call
  detail pages (`#call/<id>`) stay in the web view. The Call tab is the
  call, live, and nothing else.
- **Lock-screen call controls / CallKit.** Hang-up from the lock screen, the
  green "call in progress" pill, surviving an *incoming phone call* — phase
  2, its own spec. Phase 1 is "the call does not die when the screen goes
  dark".
- **A model picker.** The call runs on each backend's default model. (The
  *voice* picker was a phase-2 item; it is in — see *The voice* below.)
- **Voices for the other backends.** Igor: *"I don't care so much about the
  other ones."* OpenAI's ten built-in voices and Gemini's pinned one are not
  offered; those backends call on their defaults.
- **Typed turns.** The page offers a text box when there is no microphone.
  The app always has a microphone.
- **Android.**

## User-visible behavior

### The Call tab

A new tab, **Call**, beside Cockpit. Idle, it shows: a large **Call Larry**
button, a row of backends to choose from — *ElevenLabs*, *Gemini*, *OpenAI*,
*Drill* — with the last choice remembered (ElevenLabs, Tony's voice, until
Igor picks otherwise — "Let's default to the 11 labs Tony call", 2026-08-29),
and one **devices line**.

### The devices line

Igor, 2026-08-29: *"Instead of wasting all of that mic output/input, I want
to be able to collapse that down, maybe under a folder, so I have more
space."* And: *"I want to see mic input volume, that little strip that goes
up and down."*

One line, always visible: the current microphone and output by name —
*iPhone Microphone · Speaker* — and a disclosure chevron. Tap the line and
the two pickers unfold beneath it (the same roster and names the audio
bridge gives the page: *iPhone Microphone*, *AirPods Pro*, *Speaker*); tap
again and they fold away. Folded is the default; the captions get the space.

The "little strip that goes up and down" started life on this line. Since
[#90](https://github.com/idvorkin/context-grabber/issues/90) it is the
**voice control** at the bottom of the screen — the thing you look at while
talking, and the mute — described under *During a call*. It is live
whenever the microphone is open, and gone with the call.

### The voice

Igor, on a call 2026-08-29 10:47, trying to reach his own cloned voice from
the app: *"When we collapse microphones, can we also pick the voice to
select as well? I want to be able to select the different ElevenLabs
voices."* ([#98](https://github.com/idvorkin/context-grabber/issues/98)).
Scoped down the same afternoon (16:14): *the full ElevenLabs voice list is
not needed for v1 — a two-way selector is enough: Tony or Igor.*

Inside the same fold as the microphone and output pickers, a third row,
**Voice**, with two choices:

- **Tony** — the stock voice (ElevenLabs's *Charlie*), the one every call
  has used until now, on the bridge's default model.
- **Igor** — his own cloned voice. The clone is only worth hearing on
  ElevenLabs's *v3 conversational* model, where it performs `[laughs]`,
  `[sighs]` and accent tags (Igor: *"Holy shit, that's good"*), so picking
  Igor also puts the call on that model. Nothing else about the call
  changes: same Tony persona, same Larry behind him.

Tony is the pick on a fresh install. Tap the other: it is remembered like
the backend is, across restarts, and the next call is placed in that voice.
The pick is locked while a call is connecting or live — a voice cannot
change mid-session — and Restart and the automatic redial keep it. **The
voice's name is on the status line** whenever a call is up (*live · 1:17 ·
ElevenLabs · Igor*) and on the folded devices line (*iPhone Microphone ·
Speaker · Igor*), so a call in the wrong voice is visible without opening
anything.

The voice belongs to ElevenLabs (and to Drill, whose clips are ElevenLabs
too). On Gemini and OpenAI the row is folded away and the call is on the
vendor's default, whatever was picked for ElevenLabs; switch back and the
pick is still there.

Not in this change: the full account roster with favourites (the page has
it; add it here if two is ever not enough), a model picker (Igor implies
v3; Tony implies the default; nothing else is chosen), and voices for the
other backends.

**A USB microphone wins — for the microphone only.** *"If a mic is over
USB, let's take that as a default."* When a USB audio device with a
microphone is attached — at the start of a call, or plugged in during one —
the call uses it without a tap, and the devices line says so. Igor's own
pick still wins: once he has chosen a microphone by hand during a call, the
app stops second-guessing him until the next call. **The output does not
move.** iOS likes to send playback to a USB device that was just chosen as
the microphone; a wireless-mic receiver has no speaker, and the first time
this rule ran Larry's voice went into the dongle and Igor heard nothing
(2026-08-29). The output stays where it was, and a USB device is offered in
the output picker only while iOS is actually playing through it.

### Diagnostics

*"Do you have logging output on this?"* Under the devices line, a
**Diagnostics** fold. Open, it shows the call's log — a timestamped line
for everything that matters and nothing that does not: the call starting
and on which backend and bridge, the audio session configured, the
recorder opening and at what hardware rate — and, at the moment it is
armed, whether another app is playing audio, whether an input is
available at all, the inputs and outputs actually on the route, and how
the session is set (category, mode, gain, rate, buffer), because Igor's
question on a silent call was *"could it be somebody else has the
audio?"* ([#95](https://github.com/idvorkin/context-grabber/issues/95)) —
the first mic frame and every
few seconds of frames after, the probe and its ack, mute, interruptions,
route changes with the full roster (every mic and output by name and
type), the bridge's `ready`, warnings, errors, and the ending. A **Copy
diagnostics** button puts the whole log plus the build, the state, and the
current roster on the clipboard, so a bad call can be pasted into a chat
without a cable. Folded by default; the log is kept whether or not it is
open, across the call and until the next one starts.

Beside *Copy diagnostics*, while no call is live, a **Prime audio**
control (Igor, 2026-08-29 09:16, still chasing the silent first call: *"Do
we need to do something like a dummy call that opens, closes, reopens?
Maybe give me a button to do that so I can test."*). It brings the call's
audio up and down once without dialling — session on, microphone open for
half a second to nowhere, everything off — and logs each step. It exists
for the experiment: prime, then call; if the first call then carries
audio, the cause is the first activation of the input unit and priming
becomes automatic; if not, something else owns the microphone. The log's
first line of every call also says whether the Cockpit tab is loaded and
whether its page reports a call of its own.

**The log keeps the calls before.** A retry must never erase the evidence
of the call it is retrying ([#92](https://github.com/idvorkin/context-grabber/issues/92)),
and on 2026-08-29 a silent call's evidence was gone after two more calls
— a retry and one after it — before anyone could read it. So the log
holds every call it has room for (several hundred lines, six to ten
calls), each separated by a rule, oldest first; *Copy diagnostics* copies
all of it, and so does the dump the bridge gets.

**The log counts both directions** ([#106](https://github.com/idvorkin/context-grabber/issues/106)).
Every five seconds of a live call, one line: what came down the socket
(kilobytes and frames), how much of it the speaker has rendered against
how much was scheduled, whether the output clock is running, and how many
microphone frames went up — so a call where the bridge sent a megabyte and
the phone played fifteen frames is visible on the phone without the
server's log. The ending line carries the final pair. *Played* means
rendered by the speaker; *received* means delivered by the socket; the log
never confuses the two.

**The log survives a freeze.** Igor, 2026-08-30: *"I had a freeze when I
switched microphones in the last call — hopefully the app was actually
storing everything."* The log is mirrored to disk as it grows, not
assembled at hang-up, so a call that freezes or kills the app still leaves
its lines. On the next launch those lines come back at the top of the log
under a *previous run, recovered from disk* rule, and go out with the next
dump like any other call's.

**The dump reaches the bridge on its own.** At every hang-up, at every
automatic redial, and when the bridge fails to acknowledge the microphone,
the app sends the dump to the bridge over the call's own socket before
anything closes, so Larry can read it from the call's record without Igor
pasting anything. (Bridge half: the Cockpit repo.)

### Audio that stops — either direction

Igor's dumps of 2026-08-30 ([#95](https://github.com/idvorkin/context-grabber/issues/95)):
*"this time I'm getting microphone but not audio"*; on another call the
microphone delivered one buffer and then nothing for the rest of the
call, right after the phone's own route settled; on a third, *"I didn't
hear you on the first round, but I did hear you on the second"* — the
greeting played into a speaker that had not started. The audio session
comes up with one direction dead, either way round, and a route change
mid-call can kill a direction that was working.

So the call **watches both directions the whole time, and heals what it
can**:

- **A microphone that goes quiet** — armed, not interrupted, and no
  buffer for a second and a half — is closed and reopened, up to three
  times. A line in Diagnostics says so each time (*mic stalled: no buffer
  for 1600 ms → re-arming (1/3)*). If it stays quiet after that, the
  screen says *the microphone stopped delivering* until buffers return.
- **A speaker whose clock stops** — Larry's audio is queued and due, and
  the output clock has not moved for a second — is reopened, and the
  screen says *Tony's audio is arriving but not playing* until it moves
  again. What was queued is lost (a short gap); the next frames play.
- **The greeting waits for the speaker.** Larry's first frames are held
  until the output clock is actually running — the first frame kicks it,
  and the wait is logged (*output clock running after 120 ms*). If the
  clock has not started after two seconds, playback is reopened once and
  the held audio plays from there. Nothing Tony says in his first two
  seconds is lost to a speaker that was still waking up.
- **Audio that is not arriving at all** — Tony's words keep arriving as
  text, but no audio has come down the socket for five seconds — is not
  the phone's to heal. The screen says *Tony's audio is not arriving from
  the bridge*, the captions carry his words meanwhile
  ([#105](https://github.com/idvorkin/context-grabber/issues/105): *"I
  don't hear you. Can I read what you're saying at least?"* — yes: the
  captions have always shown Tony's transcript as he speaks), and the
  banner clears the moment audio resumes.

### A microphone that never delivers

Larry's finding on [#88](https://github.com/idvorkin/context-grabber/issues/88),
2026-08-29 09:26: on every silent first call the bridge received *no*
microphone frames at all — not zeros, nothing. The recorder was started and
never produced a buffer. So the app watches for exactly that: if a second
and a half passes after the recorder starts with no buffer, the call's audio is
torn down and brought back up (a short gap in Larry's voice, a line in
Diagnostics); if there is still nothing after that, the call **redials
itself** — once — on the same backend, because the retry has always
worked. The watch is short — a second and a half, where a working mic's
first buffer comes within a tenth — because on 2026-08-29 17:33 Igor hung
up a silent call at 3.1 s, before a three-second watch could act (the
bridge's record shows zero frames). From the chair: the first call after
launch may take a few seconds longer to become a working call, and never
needs a second tap — give it five seconds before reaching for Restart.

### Starting a call

Igor, 2026-08-29, on a call from this tab: *"Can you make the UI just a
little bit nicer too? While it's calling, instead of saying 'Connecting the
bridge', have like a calling thing; and mute and hang up are pretty ugly
buttons. Maybe the mute button merges with the little voice dial-y thing.
Make it prettier."*

Tap **Call Larry**. The screen *calls*, the way the Phone app does: in the
middle of the screen a ring pulses slowly outward around a handset, under it
*Calling Larry…* and the backend's name, and the status line at the top
says *calling Larry…* and the backend. Nothing about bridges or connecting
is on screen. The round red hang-up is already at the bottom, so a call that
is taking too long can be abandoned with the same tap that ends a live one.
With the phone's Reduce Motion on, the ring is still; the words are the
same. The five or six seconds this takes are the first impression of every
call.

When the bridge answers, the calling treatment gives way to the captions,
the status says *live*, a timer starts, and the microphone opens — not
before. (Opening the microphone before the far end is ready is the page's
rule too; it stops Igor talking into nothing.)

**The first call after launch works like every other call.** Igor,
2026-08-29 08:40: *"I think there's something wrong when it's a first
call."* The bridge's recordings agreed ([#88](https://github.com/idvorkin/context-grabber/issues/88)):
the first call of a burst sent exact silence for its whole length and the
retry carried audio. The first attempt at this (waiting for the input
route) did not fix it: the route was up. What differed was order — on a
first call, echo cancellation was switched on *after* playback had already
started the audio engine; on every later call it was already on before.
Now it is switched on the moment the call's audio session is configured,
before anything starts. And if the mic nonetheless delivers a second of
exact zeros, the call's audio is torn down and brought back up the way a
second call would (a short gap in Larry's voice), with a line in
Diagnostics saying so. Only if it is still silent after that does the
screen say *the microphone is delivering silence*.

**The bridge knows it is the app.** The call introduces itself —
`client: context-grabber` and the build — so the bridge's records can tell
an app call from a browser call ([#78](https://github.com/idvorkin/context-grabber/issues/78),
the call half).

If the bridge cannot be reached — not on the tailnet, the server is down —
the screen says so within a few seconds, with a copyable error, and returns
to idle. Nothing hangs.

### During a call

The screen is the conversation and nothing else (Cockpit DESIGN P23/P24):

- **Captions.** Each thing Igor says and each thing the voice says is a
  row: a short speaker label — *Igor*, *Tony*, never wider than five
  characters — and the words. The voice is **Tony** (Igor, 2026-08-29:
  *"In the call log, it should say Igor and Tony, not Igor and Larry"*);
  Larry is the reasoning half behind him. A line Larry put into the call
  himself (injected context) carries the label *Larry*. Larry's spoken text appears as he says it;
  Igor's appears when the recognizer settles on it. No turn numbers, no
  links, no per-turn readouts. Larry's *consults* (asking the other Larry
  something mid-call) show as a short clamped row that expands on tap and
  never touches the call.
- **The voice control — which is the mute.** At the bottom, left of the
  hang-up, one round control that *is* the microphone: a disc inside it
  swells with Igor's voice and shrinks in silence, so "is my mic working"
  is answered by glancing at it. Tapping it mutes. Muted, the control dims,
  a red slash crosses the microphone, the disc stops moving — frozen where
  it was — and the word under it reads *Muted*; nothing Igor says leaves
  the phone, and the bridge is told so it does not hang up on the silence.
  Tap again: the slash goes, the disc moves again. There is no separate
  mute button; the level and the mute are one thing, with a label under it
  so the first tap is not a guess.
- **Hang up.** A round red button with a handset on it, bottom-centre, big
  enough for a thumb without looking — not a text button. Tapping it ends
  the call with reason *stopped*. It is there from the moment the call
  starts calling until the call ends, and then **Call Larry** takes its
  place.
- **Mic / output pickers.** Change the microphone or the speaker mid-call;
  it takes effect immediately, and if iOS reroutes on its own (AirPods
  connect, headphones unplugged) the pickers follow and the call carries
  on wherever iOS put it.
- **Timer, backend name and voice**, small, at the top.

When Larry is cut off — Igor talks over him — the audio stops within a
beat, exactly as on the page. That decision is the vendor's; the screen
just stops playing.

**Spoken control works unchanged** (DESIGN P25): "Larry, hang up", "end
the call", "bye Larry" end the call; the two-minute idle hang-up and its
thirty-second warning still apply. These are the bridge's, not the
screen's, and they do not care which client is connected.

### The lock — the point of all this

- **Lock the phone mid-call** (side button, or auto-lock): the call
  continues. Larry keeps talking through whatever the output is; Igor
  keeps being heard. The lock screen shows iOS's own "app is using the
  microphone" indicator and nothing else.
- **Background the app mid-call** (home gesture, switch to another app):
  same — the call continues.
- **Switch to another tab mid-call:** same. The Call tab is one tap away
  and the timer is still running when he gets back.
- **Come back** — unlock, reopen: the captions are where he left them, the
  timer is right, nothing reconnects because nothing disconnected.
- **While the Call tab is frontmost during a live call the screen stays
  awake**, as it does on the Cockpit tab today — but the call no longer
  *depends* on it. A deliberate lock is honoured and does not end the
  call.

### Interruptions

- **An incoming phone call, Siri, or another app taking over audio** pauses
  the call's audio. When the interruption ends, the call's audio resumes on
  its own. If the interruption outlasts the bridge's patience (two minutes
  of silence), the bridge hangs up and the screen shows *idle 2 min* when
  Igor returns. Phase 2 (CallKit) makes the phone-call case graceful; phase
  1 only promises "resume if the bridge is still there".
- **Losing the network** (walking out of Wi-Fi with no cell coverage, the
  tailnet dropping): the call ends with a *connection lost* reason. Phase 1
  does not reconnect; a fresh tap starts a fresh call.

### Endings

The call ends and the screen says why, in the same words the page uses:
*stopped*, *idle 2 min*, *hang-up intent*, *Larry hung up*, *vendor ended
the call*, *vendor max duration*, *connection lost*. The captions stay on
screen until the next call starts; the **Call Larry** button is back.

Gemini Live caps a call at roughly fifteen minutes and the bridge warns
before it does; the warning shows as a row.

### The deep link

`grabber://call` and `grabber://call?via=…` now open the **Call** tab and
start the call there — the web view is not loaded for it. `via` names the
backend exactly as before (`gemini`, `eleven`, `openai`, `drill`); an
unknown `via` is ignored and the remembered backend is used. If a call is
already live, the link brings Igor to it and does not start a second one.
The rest of the deep-link spec is unchanged.

### The widget

Igor, 2026-08-29: *"Make sure to add a call button there as well, somewhere."*

The home-screen widget (medium and large) gets a **☎ Call** pill in its
header, beside the date. Tapping it is `grabber://call`: the app opens on
the Call tab and the call starts on the remembered backend — from the home
screen to Larry in one tap, no unlock-and-hunt. The rest of the widget is
unchanged; the pill is the only new tap zone.

### One call at a time

If a call is live on the Cockpit *page* (its own Call tab, in the web
view) and Igor taps **Call Larry**, the tap is refused with a one-line
reason — *a call is live in the Cockpit tab* — rather than opening a
second microphone on the same phone. The reverse is not policed; the page
does not know about the native call.

### Restart

Igor, 2026-08-29 09:39: *"Including End Call, we should have Restart
Call."* Beside the hang-up, a **Restart** control: one tap ends the current
session and dials a new one on the same backend, without a trip through the
picker. It is the user's own self-heal for a call that went bad — a silent
first call, echo, a stuck consult, a dropped socket. The ended call's
diagnostics are sent to the bridge and kept in the log (behind the
separator) exactly as a hang-up's are; Restart never erases evidence.

### The call line

Igor, 2026-08-29 09:44, on seeing the round controls from #90 on the
phone: *"these mute and end buttons are ridiculously too big — it's awful,
super distracting … maybe end and mute go up into the call line with the
length. Look how much of the screen you're taking up."* Reversed
([#96](https://github.com/idvorkin/context-grabber/issues/96)).

During a call there is **one compact line** at the top: on the left,
*live · 1:17 · ElevenLabs · Igor* (or *calling Larry… · ElevenLabs ·
Igor*; no voice segment on a backend without a voice pick); on the right,
three small icon controls — **mute** (the voice indicator: it
swells as Igor speaks; tap to mute, and it dims, freezes and takes a red
slash), **restart** (↻), **end** (a red handset). Visually small, but each
is comfortably tappable (44 pt hit area). Nothing else sits between the
captions and the tab bar: the transcript gets the bottom of the screen
back. The calling treatment in the middle of the screen stays; the big
**Call Larry** button is only there when there is no call.

## Acceptance criteria

1. **Call Larry** on a fresh install (nothing remembered): the call is on
   ElevenLabs — within 5 s the screen says *live*, the timer runs, and
   saying "hello Larry" produces a reply in Tony's voice, with both
   captions on screen.
2. Repeat for Gemini, OpenAI, and Drill. The remembered backend survives
   an app restart.
3. Mid-call, press the side button. Wait 2 minutes with the screen dark,
   talking to Larry at intervals: Larry answers every time. Unlock: the
   captions include everything said while locked, the timer is continuous.
4. Mid-call, auto-lock fires (auto-lock set to 30 s, phone untouched while
   Larry talks): same as 3.
5. Mid-call, home gesture to another app for 2 minutes, talking: same.
   Return: same.
6. Mid-call, switch to the Today tab for 2 minutes: same.
7. Talk over Larry: his audio stops within ~250 ms.
8. Mute: say something; no Igor caption appears and Larry does not react.
   Unmute: normal. A 3-minute mute does not end the call.
9. Say "Larry, hang up": the call ends with *hang-up intent*. Say nothing
   for 2 minutes: *idle 2 min*, with the warning row at 90 s.
10. Connect AirPods mid-call: audio moves to them, the output picker says
    so, the call continues. Switch the output picker back to Speaker:
    Larry's voice moves to the speaker.
11. Kill the bridge process mid-call: within 30 s the screen shows
    *connection lost* with a copyable error, and **Call Larry** is
    tappable again.
12. Turn Wi-Fi off with no tailnet reachability: tapping **Call Larry**
    fails within 10 s with a copyable error naming the host.
13. `grabber://call?via=eleven` from a Shortcut with the app closed: the
    app opens on the Call tab and the call is *live* on ElevenLabs without
    a tap. With a call already live: the app comes to the Call tab; the
    timer did not reset.
14. Start a call on the Cockpit page's Call tab, then tap **Call Larry**:
    refused with the reason; the page's call is unaffected.
15. Trigger a Siri interruption mid-call: after Siri dismisses, the call's
    audio is back within 2 s without a tap.
16. The live screen contains no turn numbers and no speaker label wider
    than five characters; a consult row is clamped and expandable, and
    expanding it does not touch the call.
17. The bridge's call record for a native call (`data/voice-live/<session>.jsonl`,
    the feedback marker on teardown) matches a page call's in every way
    except the client tag on the start frame, which names the app and
    build.
18. Tap **☎ Call** on the home-screen widget (medium, then large): the app
    opens on the Call tab and the call is *live* on the remembered backend
    without another tap. With a call already live: the app comes to the
    Call tab; the timer did not reset.
19. **Echo.** Gemini backend, phone on speaker, no headphones, held at
    arm's length: let Larry say two full sentences. No *Igor* caption
    appears containing Larry's words, and Larry does not interrupt or
    restart himself. Then switch to the Today tab and back mid-call and
    repeat: still clean (re-activating the session must not drop it).

20. **Pickers mid-call.** With AirPods paired, on a live call: pick
    *AirPods Pro* as the microphone — within 2 s the chip moves, the call
    continues, and the next sentence Igor says is captioned (the mic
    survived the change of hardware rate). Pick *Speaker* as the output:
    Larry moves to the speaker; pick *AirPods Pro*: he moves back. Repeat
    the mic pick with the phone locked mid-way: still captioned after
    unlock.
21. **Level.** On a live call, speak: the disc in the voice control swells
    with the voice and shrinks in silence. Mute: it freezes and dims. Hang
    up: the control is gone with the call.
22. **Folded pickers.** Open the Call tab: one devices line (*iPhone
    Microphone · Speaker*, chevron); no level strip on it, no chips. Tap
    it: the mic and output pickers appear; tap again: gone. Picking a
    device updates the line's names whether folded or not.
23. **USB default.** Plug a USB-C microphone in, then start a call: the
    devices line names the USB mic and Larry hears it. Start a call on the
    built-in mic, then plug the USB mic in: the call moves to it within
    2 s. Pick *iPhone Microphone* by hand, then re-plug the USB mic: the
    call stays on the built-in mic for the rest of that call.
24. **USB does not steal the output.** With a wireless-mic USB receiver
    plugged in, start a call on speaker: the mic is the receiver, the
    output is still *Speaker*, Larry is audible, and the receiver is not
    listed under *Out*.
25. **Diagnostics.** After any call, open *Diagnostics*: the log shows the
    start, `ready` with the output rate, the recorder's rate, an `at arm:`
    line just before `recorder started` saying whether other audio was
    playing and which inputs were on the route, the first mic
    frame, `mic_ack`, `output clock running after N ms`, every route change
    with the roster, an `rx … KB / … frames · played … of …` line every five
    seconds, and the ending with the final received/played pair.
    *Copy diagnostics* → paste: the same, plus build sha, state, and the
    current roster.
26. **Calling.** Tap **Call Larry**: until the bridge answers, the middle of
    the screen shows a ring pulsing outward around a handset, *Calling
    Larry…*, and the backend's name; the status line reads *calling Larry…*
    with the backend; the words "connecting" and "bridge" appear nowhere.
    The round red hang-up is already tappable and ends it with *stopped*.
    When the bridge answers, the treatment is gone and the captions area
    says *Say hello.* Turn on Reduce Motion (Settings → Accessibility →
    Motion) and call again: the ring does not pulse; everything else is the
    same.
27. **The voice control is the mute.** On a live call, the small round
    voice icon on the call line swells as Igor speaks. Tap it: it dims, a red slash
    crosses the microphone, the disc stops moving, the word under it says
    *Muted*; say something — no *Igor* caption, Larry does not react. Tap
    again: the slash goes, the disc moves, and the next sentence is
    captioned. There is no other mute control on the screen.
28. **Hang-up.** While calling and while live, a small red handset icon
    sits at the right end of the call line, with a 44 pt hit area; tapping it ends the call with
    *stopped*. Idle and ended, it is gone and **Call Larry** is back. The
    *Diagnostics* fold opens in every state, calling and live included.
29. **First call after launch.** Force-quit the app. Launch, Call tab,
    **Call Larry**, say a sentence as soon as Tony has greeted: the voice
    control swells as you speak and your sentence is captioned. Diagnostics
    shows `input route ready: iPhone Microphone` before `recorder
    started`, and no `zeros` line. Repeat five times (force-quit between):
    five for five. If a `mic delivering zeros → re-arming` line appears,
    the call still works (the watchdog caught it) — report it.
30. **No-frames self-heal.** Diagnostics on any call where the mic never
    delivered shows `no mic buffer within 1.5s … → resetting audio`, then
    either `first mic frame` (healed) or `still no mic buffer → redialing`
    followed by a fresh `start` on the same backend; the screen shows
    *Calling Larry…* again briefly and then *live*, without a tap. The
    bridge's record of the dead session ends with the app's diagnostics.
31. **Evidence survives a retry.** After a silent call, its retry, and
    three more calls, open Diagnostics: all of them are there, separated by
    rules, the earliest first; *Copy diagnostics* copies all of them.
32. **Restart.** On a live call, tap **Restart**: the call ends with
    *stopped* and immediately shows *Calling Larry…* on the same backend,
    then *live*; no picker, no second tap. Diagnostics afterwards holds
    both calls, and the bridge's record of the first ends with the app's
    diagnostics.
33. **The call line.** On a live call, the only controls are three small
    icons on the status line's right — mute, restart, end — and the
    captions run down to the tab bar with nothing under them. Each icon
    answers a tap anywhere in a 44 pt square. Muting via the icon dims and
    slashes it; the timer keeps counting.
34. **The voice row.** ElevenLabs selected, open the devices fold: under
    *Mic* and *Out* a *Voice* row offers **Tony** and **Igor**, Tony
    highlighted on a fresh install. Switch the backend to Gemini: the row is
    gone; back to ElevenLabs: it is back with the same pick.
35. **A call as Igor.** Pick *Igor*, fold the pickers: the devices line ends
    *· Igor*. **Call Larry**: the status line reads *calling Larry… ·
    ElevenLabs · Igor*, then *live · 0:03 · ElevenLabs · Igor*, and the
    voice that answers is Igor's own, with v3's expressiveness; the bridge's
    session row names the clone and `eleven_v3_conversational`. Force-quit
    and relaunch: *Igor* is still picked. Tap **Restart**: the new call is
    as Igor too, and the row stayed locked throughout.
36. **Back to Tony.** Pick *Tony*: the next call answers in Charlie's voice
    on the default model, and the bridge's session row shows no voice or
    model override — exactly a call placed before this change.

37. **The greeting is heard.** Ten calls in a row, ElevenLabs, phone on
    speaker: Tony's first sentence is heard in full every time; Diagnostics
    shows `output clock running after N ms` before the first frame is
    scheduled, and no call shows *I didn't hear you on the first round*.
38. **A microphone that stops mid-call heals.** Mid-call, force a route
    change that kills the tap (pick *Speaker* while already on the speaker,
    or plug and unplug a USB mic): within ~2 s Diagnostics shows `mic
    stalled … → re-arming (1/3)` and the next sentence is captioned; the
    screen shows no error. If the re-arms fail, the screen says *the
    microphone stopped delivering* and clears when buffers return.
39. **Audio not arriving is named, not blamed on the speaker.** On a call
    where Tony's captions keep coming but no audio does (a starved socket),
    within 5 s the screen says *Tony's audio is not arriving from the
    bridge*, the captions keep updating, and the banner clears when audio
    resumes. The five-second `rx` lines show the byte count standing still.
40. **The log outlives the app.** Force-quit the app mid-call. Relaunch,
    open Diagnostics: the frozen call's lines are there at the top under
    *previous run, recovered from disk*, followed by `app launched, build
    …`. Place a call and hang up: the dump the bridge receives contains
    those lines.
