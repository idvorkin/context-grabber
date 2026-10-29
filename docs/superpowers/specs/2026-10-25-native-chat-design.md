# Chat with Larry in Grabber Native — Design Spec

Igor, 2026-10-25: *"can we iterate on inbox feature so it's more like chat? … I want to be able to have chat threads
there and stop needing telegram if I don't want it."* On sharing: *"share to a new thread."* On hearing back: *"A and
B"* — the app refreshes while open and counts unread replies, and a background check notifies of Larry's replies.
This is the "later spec" the [Inbox spec](2026-10-17-native-share-inbox-design.md) left room for; it replaces the
Inbox's list. Part of the [Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The Inbox becomes **Chat**: a list of conversations with Larry, each a thread of Igor's messages and Larry's replies.
Every share from another app starts a new thread. The threads are the Cockpit's chat threads — the same ones the
Cockpit's Chat tab shows and Larry already answers — so a conversation started on the phone can be picked up on the
laptop and back. Writing still works with no network, as the Inbox does today. While the app is open the thread
updates by itself; while it is not, the phone checks now and then and notifies Igor of a reply.

## Goals

- Talk to Larry in threads from the phone, without Telegram.
- Every share starts its own thread, with the shared thing as its first message.
- Nothing written is lost: a message waits on the phone until the Cockpit has it, and reaches it once.
- Igor can tell, without opening each thread, which ones Larry has answered.

## Non-goals

- Instant alerts like Telegram's. That needs real push and a paid developer account; a later spec (option C) if
  wanted. Telegram stays available for anything that must arrive at once.
- Larry starting a conversation that only Telegram carries. Threads Larry starts on the Cockpit do appear here.
- Searching, renaming, closing or deleting threads from the phone. Closing is done on the Cockpit, as now.
- A voice conversation inside a thread (the Call screen is that). Speaking a message is in (#448): it becomes text
  Igor reads before he sends.

## What Igor sees

**The tile.** The home-screen *Inbox* tile becomes *Chat*, with the same raccoon-and-mailbox picture. Its number is
the conversations with a reply Igor has not read, plus any of his messages not yet sent.

**The list.** Newest activity first. Each row: the thread's title, the last message's first line and who wrote it,
when, and an unread mark when Larry has replied since Igor last looked. Finished threads fold under *Done*, by the
same rule the Cockpit uses, so the phone and the laptop agree. The round **+** stays at the lower right; it starts a
new thread. Pull to refresh. With no network, the quiet offline line from the Inbox stays.

**A thread.** Bubbles: Igor's on the right, Larry's on the left, oldest at the top, opening at the newest. Images
show inline, tap to see full size. Links are tappable. Under each of Igor's messages, its state: **Not sent yet**,
sent, 👀 when Larry has seen it, 🏆 when the thing is done (with Larry's note). Opening a thread marks it read here
and on the laptop. The thread updates by itself every few seconds while it is open, and the list on each return to
it.

**Writing.** One bar at the bottom: a growing text field with the keyboard's dictation mic, a *Paste image* control
when the clipboard holds an image (preview, remove), and *Send*. Send needs text or an image. A sent message appears
at once with **Not sent yet** until the Cockpit has it, and the bar empties at once, text and image, with the keyboard
still up for the next message — typed or dictated alike (#449).

**A new chat** (#536). Igor, 2026-10-26: *"for the Plus, why don't we just make that a new chat versus having its own
input dialog? That's probably a better UI."* The **+** opens an empty thread titled *New chat*, with the same bar every
thread has — text, *Paste image*, the mic — and the keyboard up. There is no separate sheet. Back with nothing sent
leaves no thread behind. The first Send starts the thread: the message shows at once as **Not sent yet**, kept on the
phone and sent by the same rules as any message (so it waits out no network), and the thread's title becomes that
message's first line. Once the Cockpit has it, the same screen is that thread, live like any other, and the bar takes
the next message. Until then the bar holds the next message back and says it goes once the first reaches Larry; a
not-yet-sent new thread also shows in the list under *Not sent yet*, as now. If Larry refuses that first message, it
says why, copyably, as any refused message does, and the bar takes a new first message at once — a line under the bar
says the first was refused — which starts the chat afresh; deleting the waiting first message does the same. Each
attempt is its own message, so a new try is never mistaken for the refused or deleted one, and the screen follows
the newest.

**Speaking a message** (#448). Igor, 2026-10-26, first: *"transcription based, use a good model like we do in
cockpit"*; then, on learning the problem reports' dictation is Apple's own recognizer: *"All right, use that."* So the
chat mic is the same dictation the problem report's note uses — Apple's speech recognizer, on the phone when it can
be, no key and no service of ours. The bar has a mic button beside the field. Tap it to start; it turns red and shows
the seconds counting; tap it again to stop. The words appear **in the field as Igor speaks**, after what was in it
when he tapped — never sent. When he stops, the last words settle (a spinner while they do), and he reads them, fixes
what he likes, and taps Send. A recording where nothing was heard leaves the field as it was. Nothing is kept of the
sound.

- **Which microphone.** Igor, 2026-10-26: *"make sure to be able to have a mic selector and then see the audio input
  levels."* A row across the bar, above the field, names the microphone the next recording will use —
  *Microphone · Automatic* (whatever the phone routes) or one of the phone's inputs (the built-in mic, a headset,
  AirPods) — laid out as the problem report's microphone row is. The whole row is the target, a full finger tall
  (Igor, 2026-10-26, #544: *"the selector button for the microphone is too small"*); a tap opens the list, with *Find
  microphones* to list them. The pick is kept across launches and is the same one the problem report's dictation uses. It cannot be
  changed while recording or during a live call. Under the row a thin live input-level bar shows how loud the
  microphone hears Igor while he records — green, orange near the top where the voice would clip, empty when not
  recording — the same meter the problem report shows (#531, Igor 2026-10-26: *"Don't forget to give me a
  Microphone box on this input as well … I really like the way it's done for Bug kit"*).
- **Permissions.** The first tap asks for speech recognition and the microphone (the same ones the problem report's
  dictation uses). Declined, a copyable line above the bar says which is off and that the phone's Settings turns it
  back on.
- **A live call.** While a call with Larry is live, the mic is the call's: the button is dimmed and a tap says so,
  starting nothing. A call that starts mid-recording stops it at once; the words already in the field stay, and a
  line says the call took the microphone.
- **An interruption.** A phone call, Siri or the microphone changing mid-recording stops it; the words heard so far
  stay in the field (still never sent), and a copyable line says the microphone was interrupted.
- **Five minutes at most.** Igor, 2026-10-26: a recording is capped at 5 minutes. At 5:00 it stops on its own and
  the words settle into the field exactly as if Igor had tapped stop — still never sent — and a quiet line under that
  thread's bar says *Stopped at 5 minutes.*
- **Music.** Recording mixes with whatever is playing, as the problem report's dictation does; it is not paused.
- **Failures** (the recognizer stopping, a microphone that will not start) are copyable errors above the bar; the
  words already in the field stay. A Gym Timer cue during a recording takes the audio session and stops it the same
  way: the words so far stay in the field.
- **Leaving the thread** mid-recording stops it.
- **Sending mid-recording** (#546, Igor 2026-10-26: *"Even after the send we still have the element in the sandbox"*):
  Send sends what is in the field — the words heard so far — and stops the recording there. Nothing comes back into
  the emptied bar afterwards; the bar is ready for the next message, and the mic for the next recording.

**Sharing in.** The share card is unchanged — preview, optional note, *Add to Inbox* becomes *Start a chat*. Each
share becomes a new thread whose first message is the shared thing with the note. The title is the note's first
line, else the text's, else the link's site, else *Photo, <date>*. It works in aeroplane mode and while the app is
not running, as now.

**Sending.** The same rules the Inbox has: tried when the app opens or comes to the front, when the network returns
and after a failed send's network change, oldest first, never while offline. A message resent after a lost answer
appears once on the thread, and a share resent after a lost answer makes one thread, not two. A message the Cockpit
refuses (too big, an unreadable image) reads *Larry refused it* with the reason, copyable, and is not resent; a swipe
deletes it. Unreachable keeps it **Not sent yet**.

**When the Cockpit isn't answering** (#565, 2026-10-27: the Cockpit's host was off the tailnet and Igor read the
timeout as *"Context grabber inbox broke"*). A request that times out or cannot connect while the phone itself is
online means the Cockpit is away, not the phone or the app. The list and an open thread then say *The Cockpit isn't
answering — your messages are kept and go when it does*, still copyable, with the underlying reason alongside; a
waiting message reads *Not sent yet · the Cockpit isn't answering*. This is distinct from the *No network* line, which
is the phone being offline. Other failures (the Cockpit answering with an error) keep their plain reason.

While the app is open and a message waits after a send that did not get through (the Cockpit away, or answering
with a server error), it is tried again on its own: after 30 seconds,
then a minute, two, four, and every five minutes after that. The wait starts over after a send that gets through, and
the retries stop once nothing waits or the phone goes offline (the network's return sends it, as above). A refused
message is never retried.

**Hearing back.** iOS runs a background check now and then — it decides when, so a reply may wait minutes or hours.
When the check finds a reply Igor has not seen, one notification per thread: *Larry* and the thread's title, with the
reply's first line. Tapping it opens that thread. A reply already read on the laptop raises nothing, nor does a
thread marked Done. The very first check after install only takes note of what is already there, so weeks of
unread laptop threads do not arrive as a burst; only replies after it notify. Notifications
need Igor's permission, asked once, the first time he sends a message; declining leaves everything else working.

**What was in the Inbox.** Items still waiting when this ships each become a new thread, as a share would. Items
already sent to Larry's inbox stay readable under one *Earlier shares* row at the bottom of the list, read-only, and
can be swiped away.

**What the phone keeps.** A message stays on the phone until the Cockpit's thread shows it; once Igor sees it there,
in an open thread, the phone's copy (and its picture) is dropped, so the phone does not fill up with old chat.

## Explaining itself

- `chat` events in the session log: sent / refused / failed (thread, message id, the Cockpit's answer; never the
  text; a new thread's sent line names where it landed), offline_skipped and network_back as the Inbox logs them,
  refreshed (count of unread), and background_check (when iOS ran it, what it found, notifications raised).
- `chat_voice` events: record_start (thread), record_stop (thread, seconds), capped (at the five-minute limit),
  dropped (left the thread, a call started), refused (a live call). The dictation's own `dictation_start`,
  `dictation_stop` and `dictation_error` lines (the problem report's) carry the recognizer's side. Never the words.
- A thread that cannot be read logs one error when the problem starts or changes, not one per poll.
- Every error on screen is copyable, with the thread and the Cockpit's answer.

## Acceptance criteria

- The tile reads *Chat* and counts unread conversations plus unsent messages.
- The list shows every Cockpit chat thread, Done folded the same as the Cockpit; opening one marks it read on both.
- A message typed or dictated in a thread appears at once, reads **Not sent yet** offline, and reaches the Cockpit
  once when the network returns; Larry's reply appears in the open thread within seconds without a manual refresh.
- Sharing a Safari link, a Notes text and a Photos image makes three new threads with sensible titles, in aeroplane
  mode too, each delivered once.
- 👀 and 🏆 appear under Igor's messages as Larry marks them.
- With the app closed, a reply from Larry eventually raises one notification for its thread; tapping it opens the
  thread; a reply already read elsewhere, or in a Done thread, raises none; the first check after install raises
  none.
- A refused message says why, copyably, and is never resent.
- The picker lists the phone's microphones and the next recording uses the one picked; *Automatic* follows the
  phone's route.
- Tap the mic, speak, tap again: the words appear in the field as they are spoken, after what was typed, and nothing
  is sent until Send; nothing heard leaves the field unchanged. During a live call the mic is dimmed and says why; a
  failure is a copyable error and the words already in the field stay. At 5:00 a recording stops on its own, its
  words in the field, with *Stopped at 5 minutes.* under the bar.
- The + opens an empty *New chat* thread with the ordinary bar (text, Paste image, mic); its first Send starts the
  thread, which becomes the live thread once the Cockpit has it; leaving before sending leaves nothing. A refused or
  deleted first message lets the next Send start the chat afresh, as a new message that reaches Larry.
- Waiting Inbox items become threads on first launch; sent ones stay under *Earlier shares*.

## Depends on the Cockpit

Two small changes there (a PR to idvorkin-ai-tools/cockpit), before the phone half:

- Messages from the phone are recognised as the phone's, alongside the page, the command line and Telegram.
- A message or new thread resent with the same id is recognised as one already taken, as Larry's inbox does today.
