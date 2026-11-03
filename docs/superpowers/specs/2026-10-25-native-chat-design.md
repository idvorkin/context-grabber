# Chat with Larry in Grabber Native — Design Spec

Igor, 2026-10-25: *"can we iterate on inbox feature so it's more like chat? … I want to be able to have chat threads
there and stop needing telegram if I don't want it."* On sharing: *"share to a new thread."* On hearing back: *"A and
B"* — the app refreshes while open and counts unread replies, and a background check notifies of Larry's replies.
This is the "later spec" the [Inbox spec](2026-10-17-native-share-inbox-design.md) left room for; it replaces the
Inbox's list. Part of the [Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The Inbox becomes **Chat**: a list of conversations with Larry, each a thread of Igor's messages and Larry's replies.
A share from another app starts a new thread unless Igor picks a recent one on its card (#587). The threads are the Cockpit's chat threads — the same ones the
Cockpit's Chat tab shows and Larry already answers — so a conversation started on the phone can be picked up on the
laptop and back. Writing still works with no network, as the Inbox does today. While the app is open the thread
updates by itself; while it is not, the phone checks now and then and notifies Igor of a reply.

## Goals

- Talk to Larry in threads from the phone, without Telegram.
- A share starts its own thread, with the shared thing as its first message, or goes into a recent thread Igor picks
  on its card (#587).
- Nothing written is lost: a message waits on the phone until the Cockpit has it, and reaches it once.
- Igor can tell, without opening each thread, which ones Larry has answered.

## Non-goals

- Instant alerts like Telegram's. That needs real push and a paid developer account; a later spec (option C) if
  wanted. Telegram stays available for anything that must arrive at once.
- Larry starting a conversation that only Telegram carries. Threads Larry starts on the Cockpit do appear here.
- Searching, renaming or deleting threads from the phone. Archiving is the phone's way to close one (#589).
- A voice conversation inside a thread (the Call screen is that). Speaking a message is in (#448): it becomes text
  Igor reads before he sends.
- Sharing a file in from another app (#633). A file reaches a thread through the paperclip; the share card takes no files.

## What Igor sees

**The tile.** The home-screen *Inbox* tile becomes *Chat*, with the same raccoon-and-mailbox picture. Its number is
the conversations with a reply Igor has not read, plus any of his messages not yet sent.

**The list.** The pinned thread, then newest activity first. Each row: the thread's title, the last message's first
line and who wrote it, when, and an unread mark when Larry has replied since Igor last looked. Finished threads fold
under *Done*, by the same rule the Cockpit uses, so the phone and the laptop agree. The round **+** stays at the lower right, in an opaque bar
across the bottom of the list (#637), so the buttons never cover a row he can see and every row on screen can be swiped from
anywhere along it; a row scrolled beneath the bar is hidden until he scrolls it up. The **+** starts a new thread. Pull to refresh. With no network, the quiet offline line from the Inbox stays.

**Archiving** (Igor, 2026-11-01: "Let me archive threads both via swipe and via buttons in chat overflow"; #589, the
Cockpit's archive shipped first). Swiping a thread left in the list offers *Archive*; it folds under *Done* at once,
and the list shows *Archived "title"* with *Undo* for five seconds. An archived thread under *Done* swipes to
*Unarchive*. Inside a thread, the **⋯** menu at the top has *Archive chat*, or *Unarchive chat* when it is archived;
archiving from there goes back to the list. A new message from either side brings an archived thread back by itself,
as on the Cockpit. When the Cockpit refuses or can't be reached, the thread goes back where it was and a copyable
problem says why, in the list and on the open thread, until the next archive or a pull to refresh. Changes to one thread
happen in order: an *Undo* tapped before the Cockpit has answered the archive waits for that answer. A thread the
Cockpit still calls finished by its own rule stays under *Done* after *Unarchive*.

**The pinned thread** (Igor, 2026-11-02: "pinned thread on top"; #598). One always-on thread with Larry sits at the top of
the list with a pin, for dropping anything into, even before it has a message. It can't be archived, swiped away or
ticked in *Select*, its screen has no **⋯** menu, it never folds under *Done* and it never says *Looks done*. With only
the pinned thread live there is nothing to tick, so *Select* is off.

**A skill's thread** (#632; the Cockpit's half is cockpit#90). The Cockpit can pin a second kind of thread that a skill
answers instead of Larry; the first is *idvorkin*. It sits right under Larry's pinned thread, above everything else,
however recent the others are, and is there before its first message, reading *Ask idvorkin*. Everything the pinned
thread can't do, it can't do either: no archive, no ticking, no **⋯**, no *Done*, no *Looks done*. The bar says *Message
idvorkin* and a message there is not sent to Larry. The reply comes in by itself like any other, usually within half a
minute, with the skill's name and a lettered avatar above the bubble; Larry's own replies look as they always did. The
list row and the notification name the skill when it spoke last (*idvorkin: …*), not Larry. A refused message on this
thread reads *idvorkin refused it*.

When the skill can't answer, the Cockpit says why in the thread, and the app draws that as a copyable error under the
skill's name, not as a bubble. It is not an answer: a message of Igor's with only a failure after it does not show 🏆,
whatever the Cockpit's receipt says, and shows 👀 until a real reply follows. A notification or list row can't tell a
failure from a reply, since the list doesn't say, so it shows the failure's own words under the skill's name.

A Cockpit that doesn't have skill threads yet changes nothing: no second pinned thread, and Larry's threads read as
before.

**Archiving several, and threads that look done** (Igor, 2026-11-02; #599). *Select* at the top of the list turns the
live threads into checkboxes, and *Archive (N)* at the bottom archives them together, with *Undo* for five seconds for
all of them (*Archived 3 chats*). *Cancel* leaves the list as it was. Larry marks a thread he judges finished, and a new
message clears the mark. A marked thread says *Looks done* on its row and is never moved or archived by itself: a line
at the top of the list says *2 chats look done* with *Review*, which opens *Select* with those already ticked, so one
tap archives them, and unticking keeps any of them. A thread that finishes or is archived elsewhere while ticked leaves
the count and is not archived. When some can't be archived those threads go back and one copyable problem names each of
them and why; a single thread reads as it always did. A failed *Undo* of several says the same.

**A thread.** Bubbles: Igor's on the right, Larry's on the left, oldest at the top, opening at the newest. Images
show inline, tap to see full size; the full-size view always has a Done that shows on any picture, white or
dark, and a swipe down closes it too. A picture sent from a whiteboard also shows **Jump to board** in the full-size
view (#603, Igor, 2026-11-02: *"we opened a Zoom in and we get a button that says jump to the thing"*): it opens that
board as it is now, not the old picture, leaving the thread behind as any link does, with no full-size view left over
it. iCloud is asked first on every jump, so newer ink from another device is there when the board opens; out of
iCloud's reach, it opens the last drawing this device knew of. A board that was deleted, that isn't on this device even
after asking iCloud, or whose latest drawing didn't come down, says so in a copyable problem and the picture stays open. A picture from anywhere else has no button. Links are tappable. Under each of Igor's messages, its state: **Not sent yet**,
sent, 👀 when the Cockpit has received it, 🫡 when it is with Larry, 🏆 when the thing is done (with Larry's note),
the same ladder as the Cockpit's web page (Igor, 2026-11-03, #630: *"Look at how we do Telegram. Copy that for
everyone."*). A state this build doesn't know reads as 👀. Opening a thread marks it read here and on the laptop. The thread updates by itself every few seconds while it is open, and the list on each return to
it.

**Press and hold a message** (Igor, 2026-11-03, #629: *"Maybe let me do press-and-hold reactions for yes, no, quote in
reply"*). Holding one of Larry's messages opens a menu: *Yes*, *No*, *Quote in reply*, *Copy*. Holding one of Igor's own
offers *Quote in reply* and *Copy*, since answering himself means nothing. A message that is only a picture has nothing
to quote or copy, so Larry's offers *Yes* and *No* and Igor's opens no menu. Tapping a link or a picture works as ever. The menu's *Copy* takes the
whole message and replaces selecting its text by a long press, which the same gesture can't also do.

- **Yes and No** send at once, with no second tap: an ordinary message reading *Yes* or *No*, in the thread, under every
  rule a typed message has. It shows **Not sent yet** until the Cockpit has it, waits out no network, lands once and wakes
  Larry. The Cockpit has no reactions of its own, so there is no mark on the message Igor held. Whatever is in the bar
  stays there.
- **An older message.** A bare *Yes* answers whatever was said last, so when the held message isn't the thread's newest,
  the *Yes* or *No* goes under a quote of what it answers (*A picture* for a picture alone). Larry never reads it as an
  answer to something else.
- **Quote in reply** sends nothing. The message's words go into the bar, each line marked `> ` and at most 280 characters
  (cut with …), with a blank line after for the reply and the keyboard up. They follow anything already written, so
  quoting two messages keeps both. Igor edits and sends it as any message. A recording going on stops first, its words so
  far staying in the bar, as a Send mid-recording does. The quote is plain text in the message: the laptop's page and
  Larry read the same words.
- **A failure.** A *Yes* or *No* that can't be kept on the phone says so in a copyable problem at the top of the thread,
  with the thread and the message it answered, and nothing is sent.

**Writing.** One bar at the bottom: a growing text field with the keyboard's dictation mic, a paperclip for a file, a
*Paste image* control when the clipboard holds an image (preview, remove), and *Send*. Send needs text, an image or a
file. A sent message appears
at once with **Not sent yet** until the Cockpit has it, and the bar empties at once, text and attachment, with the keyboard
still up for the next message — typed or dictated alike (#449).

**Attaching a file** (Igor, 2026-11-03, #633: *"Support file and PDF upload"*). A paperclip on the bar opens the phone's
file picker, for a PDF or any other document. The file sits above the field by name and size, with *Remove file*, and goes
with whatever is typed as one message, which reads as the file's name and then the words; a new chat's title is the
words' first line, else the file's name. One attachment to a message: picking a file replaces a pasted image, and
pasting an image replaces a picked file. A picture chosen in the picker is treated as a pasted one: it previews and
sends as a picture, except that one over 10 MB is refused at the pick where a pasted one is made to fit. Send works
with a file alone. It waits on the phone and lands once like any message.

Limits are said when the file is picked, in a copyable problem, and the draft stays as it was: over 10 MB (the Cockpit's
limit), empty, or unreadable. Nothing is sent and the original file is untouched.

**A file the Cockpit won't take.** The Cockpit can hold only pictures so far. A file it refuses stays on the phone in
the thread (or under *Not sent yet* for a new chat), and a copyable problem names the file and gives the Cockpit's own
reason, with *Send again* beside it. *Send again* tries the same message once more, so once the Cockpit takes files
nothing needs picking again. A file stays until it is delivered or Igor deletes it. In a new chat whose first message
is a refused file, the bar says the file stays under *Not sent yet* and that a new message starts a separate chat
without it. If the phone can no longer read the kept file, the problem says that instead and offers no *Send again*:
no request went, and picking it again is the only way on.

**A new chat** (#536). Igor, 2026-10-26: *"for the Plus, why don't we just make that a new chat versus having its own
input dialog? That's probably a better UI."* The **+** opens an empty thread titled *New chat*, with the same bar every
thread has — text, the paperclip, *Paste image*, the mic — and the keyboard up. There is no separate sheet. Back with nothing sent
leaves no thread behind. The first Send starts the thread: the message shows at once as **Not sent yet**, kept on the
phone and sent by the same rules as any message (so it waits out no network), and the thread's title becomes that
message's first line. Once the Cockpit has it, the same screen is that thread, live like any other, and the bar takes
the next message. Until then the bar holds the next message back and says it goes once the first reaches Larry; a
not-yet-sent new thread also shows in the list under *Not sent yet*, as now. If Larry refuses that first message, it
says why, copyably, as any refused message does, and the bar takes a new first message at once — a line under the bar
says the first was refused — which starts the chat afresh (a refused file stays, and the line says so: *A file the
Cockpit won't take*); deleting the waiting first message does the same. Each
attempt is its own message, so a new try is never mistaken for the refused or deleted one, and the screen follows
the newest.

**A new chat by voice** (#637). Igor, 2026-11-03: a voice button beside the **+**, for a first message that is spoken.
It sits immediately to the left of the **+**, the same size, so the **+** stays where the thumb knows it. A tap opens a
new chat just as the **+** does — an empty thread titled *New chat*, the same bar, no sheet or dialog — and starts
recording straight away with the chat mic described below, as if he had tapped that mic himself. Everything about the
recording is the chat mic's: the red button and the seconds, the words in the field as he speaks, a tap to stop, the
five-minute stop. Nothing is sent until he taps Send, and that Send starts the thread as any first Send does. Going back
stops the recording and leaves no thread behind. The keyboard stays down while it records, since he is talking and the
words fill the field by themselves; a tap on the field brings it up. The **+** itself is unchanged: keyboard up,
nothing recording.

A live call still holds the microphone. During a call the voice button is dimmed, and a tap opens the new chat with the
keyboard up, records nothing, and the bar says the call has the mic, as the thread's own mic does. A permission that is
off, or a recognizer that will not start, shows its copyable line in the new chat's bar, and the new chat stays open to
type in or to try the mic again. An older copyable line from the mic never hides these quieter lines: both show.

**Speaking a message** (#448). Igor, 2026-10-26, first: *"transcription based, use a good model like we do in
cockpit"*; then, on learning the problem reports' dictation is Apple's own recognizer: *"All right, use that."* So the
chat mic is the same dictation the problem report's note uses — Apple's speech recognizer, on the phone when it can
be, no key and no service of ours. The bar has a mic button right beside *Send*, at the bar's trailing edge after the
field, each at least a finger tall and wide (Igor, 2026-11-03, #625: *"put the record button by the send button"*).
Tap it to start; it turns red and shows the seconds counting; tap it again to stop. The words appear **in the field as Igor speaks**, after what was in it
when he tapped — never sent. When he stops, the last words settle (a spinner while they do), and he reads them, fixes
what he likes, and taps Send. A recording where nothing was heard leaves the field as it was. Nothing is kept of the
sound.

A problem report opened during a recording (#559) leaves the recording running: the phone can't run two recognizers at
once, and the first one would die with an error and lose its place. The report's own mic is off while the chat holds
the microphone, as it is during a call; Igor can type the report, or stop the recording and then speak it. If the
recording ends with the report still open, the report's mic comes back at his next keystroke.

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

**Sharing in.** The share card keeps its preview and optional note, and *Add to Inbox* becomes *Start a chat*. A
share with *New chat* ticked becomes a new thread whose first message is the shared thing with the note. The title
is the note's first line, else the text's, else the link's site, else *Photo, <date>*. It works in aeroplane mode and
while the app is not running, as now.

**Sharing into a chat that is already going** (#587, Igor 2026-11-01: *"let's allow me to select some of the previous
chats as well"*). Under the note the card lists *New chat*, ticked, and the five most recent chats that are still
live, each with its title and how long ago it last moved: the always-on chat first, then newest activity. Done and
archived chats are not offered. Tapping a row ticks it, and the card's button reads *Start a chat* for *New chat* and
*Send* for a chat. The shared thing, with the note, becomes the next message in that chat, under the same rules as any
message from the thread's bar: it waits on the phone, goes once, and shows in the thread as *Not sent yet* until it has
gone. Sharing still never waits on the network:

- The card opens at once with *New chat* ticked and can be sent straight away; the recent chats are asked of the
  Cockpit as it opens, and appear when they come. Their arrival never moves the tick. This one question is the only
  thing the card asks the network; the shared thing itself is written to the phone and sent by the app, as before.
- With the Cockpit out of reach, or answering with something else, within a few seconds the card offers *New chat*
  alone and one quiet line says why, selectable and with *Copy*. In aeroplane mode this is how a share looks.
- A chat with nothing to offer (a new install, every chat Done) is *New chat* alone, with no line.
- A share into a chat the Cockpit no longer has is refused like any other: it is not resent, and it reads *Larry refused
  it* with the Cockpit's reason. A message into a chat the list does not hold stays visible in the list under *Not sent
  yet*, refused or waiting, with a swipe to delete, since no thread on screen could show it.

**Sending.** The same rules the Inbox has: tried when the app opens or comes to the front, when the network returns
and after a failed send's network change, oldest first, never while offline. A message resent after a lost answer
appears once on the thread, and a share resent after a lost answer makes one thread, not two. A message the Cockpit
refuses (too big, an unreadable image) reads *Larry refused it* with the reason, copyable, and is not resent on its own
(only a file offers *Send again*, above); a swipe deletes it. Unreachable keeps it **Not sent yet**.

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
message is never retried on its own.

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

**On a simulator (#525).** A simulator reaches the tailnet too, so like the stats archive it talks to the real Cockpit
only when a launch hook names an address, and a hook can name a stand-in or the real one. Without one, chat, the Inbox, the
whiteboard's turns and the share card reach no Cockpit at all: nothing is sent, read or marked read. What waits in the outbox stays
waiting, however it got there, and goes when a later launch names an address. The chat list and an open thread say
copyably that this simulator has no address and how to give it one, rather than reading as a Cockpit that is away, and
nothing is tried again on a timer. A phone or an iPad behaves as it always has.

## Explaining itself

- `inbox` added says whether a share starts a chat or names its thread, and what the card's list held when Igor sent
  it (how many chats, still reading, or why it failed): the card itself cannot write to the session log.
- `chat` events in the session log: sent / refused / failed (thread, message id, the Cockpit's answer; never the
  text; a new thread's sent line names where it landed), offline_skipped and network_back as the Inbox logs them,
  refreshed (count of unread), and background_check (when iOS ran it, what it found, notifications raised).
- `chat` reply_failed (thread, message id, the skill; once per failure on screen, never the text); opening a thread
  names its skill.
- `chat_voice` events: record_start (thread), record_stop (thread, seconds), capped (at the five-minute limit),
  dropped (left the thread, a call started), refused (a live call). The dictation's own `dictation_start`,
  `dictation_stop` and `dictation_error` lines (the problem report's) carry the recognizer's side. Never the words.
- `chat` no_address, once at each launch of a simulator with no address, says why chat reaches nothing; `inbox` no_address
  (how many wait, what asked) at each send it held back; a refresh that could not run says the same in its reason.
- `chat` events for the press-and-hold menu: reaction (yes or no, thread, message id, whether it was the newest), quote
  and copy (thread, message id). Never the text.
- A thread that cannot be read logs one error when the problem starts or changes, not one per poll.
- Every error on screen is copyable, with the thread and the Cockpit's answer.

## Acceptance criteria

- The tile reads *Chat* and counts unread conversations plus unsent messages.
- The list shows every Cockpit chat thread, Done folded the same as the Cockpit; opening one marks it read on both.
- A message typed or dictated in a thread appears at once, reads **Not sent yet** offline, and reaches the Cockpit
  once when the network returns; Larry's reply appears in the open thread within seconds without a manual refresh.
- Sharing a Safari link, a Notes text and a Photos image makes three new threads with sensible titles, in aeroplane
  mode too, each delivered once.
- 👀 appears under Igor's message once the Cockpit has it, 🫡 once it is with Larry, 🏆 once Larry marks it done.
- With the app closed, a reply from Larry eventually raises one notification for its thread; tapping it opens the
  thread; a reply already read elsewhere, or in a Done thread, raises none; the first check after install raises
  none.
- A refused message says why, copyably, and is never resent on its own; only a file offers *Send again*.
- Holding Larry's newest message and tapping *Yes* sends *Yes*; on an older one it sends a quote of that message, then
  *Yes*; *No* the same. *Quote in reply* fills the bar, sends nothing and leaves what was typed in place. Igor's own
  messages offer no *Yes* or *No*.
- The picker lists the phone's microphones and the next recording uses the one picked; *Automatic* follows the
  phone's route.
- Tap the mic, speak, tap again: the words appear in the field as they are spoken, after what was typed, and nothing
  is sent until Send; nothing heard leaves the field unchanged. During a live call the mic is dimmed and says why; a
  failure is a copyable error and the words already in the field stay. At 5:00 a recording stops on its own, its
  words in the field, with *Stopped at 5 minutes.* under the bar.
- The + opens an empty *New chat* thread with the ordinary bar (text, paperclip, Paste image, mic); its first Send starts
  the thread, which becomes the live thread once the Cockpit has it; leaving before sending leaves nothing. A refused or
  deleted first message lets the next Send start the chat afresh, as a new message that reaches Larry.
- The voice button beside the + opens the same empty *New chat* thread already recording, the keyboard down; the words
  land in the field, nothing is sent until Send, and that Send starts the thread; back leaves nothing. During a live
  call it is dimmed, and a tap opens the new chat recording nothing, with the keyboard up and a line saying the call has
  the mic. The + still opens with the keyboard up and records nothing.
- Waiting Inbox items become threads on first launch; sent ones stay under *Earlier shares*.
- The paperclip picks a PDF or any document; it shows by name and size, *Remove file* takes it off, and Send sends it with
  or without words. A picture picked there goes as a picture. Over 10 MB, empty or unreadable says so copyably at the
  pick and leaves the draft alone.
- A file the Cockpit refuses is still on the phone, with a copyable problem naming it and the Cockpit's reason; *Send
  again* retries the same message, and delivers it once the Cockpit takes files. A kept file the phone can't read says
  so and has no *Send again*.
- A new chat that began with a refused file says where the file stays and that a new message starts a separate chat.
- The share card lists *New chat* (ticked) and up to five recent live chats, with title and age, as soon as the Cockpit
  answers; a share into one lands as that chat's next message, once, with no new thread and no new title; with the
  Cockpit out of reach the card offers *New chat* alone, says why, and still closes at once on sending.
- A simulator launched with no address sends nothing to the Cockpit, whatever its outbox holds, reads nothing from it,
  and says why in the log and on the list; the same outbox goes once, to the address a later launch names. A phone or an
  iPad with no address talks to the Cockpit as before.
- A skill's thread sits under Larry's pinned thread whichever is newer, can't be archived, and its replies carry the
  skill's name and avatar. A failure is a copyable error and leaves Igor's message without 🏆. An older Cockpit shows
  none of this.

## Depends on the Cockpit

Two small changes there (a PR to idvorkin-ai-tools/cockpit), before the phone half:

- Messages from the phone are recognised as the phone's, alongside the page, the command line and Telegram.
- A message or new thread resent with the same id is recognised as one already taken, as Larry's inbox does today.

Files (#633) need one more, not built yet; until then a file is refused and kept, as above:

- The Cockpit's attachments accept PDFs and other documents, not only pictures, under the same 10 MB limit and the same
  rule that it names what it stores; a message can name one, Larry is told where it is, and asking for it returns it.
  The file's own name reaches Larry in the message's words. The Cockpit's web page shows such an attachment as something
  to open, not as a broken picture.

Showing a delivered file in the phone's thread, as a row that opens it, is built with that change; no Cockpit sends one
back today.
