# Share into Grabber Native, and Larry's inbox — Design Spec

Issue [#305](https://github.com/idvorkin/context-grabber/issues/305). Igor, 2026-10-13: *"enable us to be able to
share arbitrary content in … and we should be able to send it to Larry. We need to figure out how to give Larry an
inbox, because eventually we'll add chatting capability to this app."* He chose the phased plan, 2026-10-17. Part of
the [Swift-native app](2026-10-04-swift-native-app-design.md).

> **Since 2026-10-25 the Inbox is Chat** ([Chat with Larry in Grabber Native](2026-10-25-native-chat-design.md), #438): each share starts a thread, sends go to the Cockpit's chat instead of Larry's inbox, and items sent before then sit under *Earlier shares*. Sharing, offline waiting and once-each sending below still hold.

## Summary

Anything Igor can share on the phone — a link, some text, a photo, a screenshot — can be shared to Grabber Native.
It lands in an **Inbox** in the app at once, works with no network, and later goes on to Larry. The Inbox is the
first piece of a conversation with Larry inside the app.

## Goals

- One tap from any app's share sheet puts the thing in the Inbox, with an optional note.
- Nothing shared is lost: the Inbox keeps it on the phone until it has reached Larry.
- Phase 2: what is in the Inbox reaches Larry through the Cockpit, and the Inbox says which items have.

## Non-goals

- Chat with Larry (a later spec; the Inbox is shaped so a reply can sit beside what Igor sent).
- Sharing out of the app, or editing what was shared.
- Files other than text, links and images (PDFs, audio) in phase 1.

## What Igor sees

**Sharing.** In any app's share sheet, *Grabber Native* is a target. Tapping it shows a small card: a preview of
what is being shared (the link's title and address, the first lines of the text, or the image), an optional note,
and *Add to Inbox*. *Add to Inbox* closes the card at once; *Cancel* closes it with nothing kept. Sharing works in
aeroplane mode and while Grabber Native is not running. Any text the sheet offers is taken, marked-up text (RTF,
HTML) kept as plain text; a share the card cannot read says why, selectable and with *Copy*.

**The Inbox.** A launcher on the home screen, *Inbox*, with the number of items not yet sent to Larry on its tile. Its
picture is the felt raccoon of the other tiles sliding an envelope and a photo into a blue mailbox with its flag
up (Igor, 2026-10-18, #395: *"Inbox icon looks terrible. Should be racoon putting something into a mailbox"*).
It lists what was shared, newest first: what it is, the note, where it came from (a link's site; iOS does not tell
the app which app shared it), and when. A swipe deletes one. In
phase 1 every item reads *on the phone*; in phase 2, *sent to Larry* with the time, or **Not sent yet**.
While the phone has no network, one quiet line says “No network — these go to Larry when you're back online”.

**Phase 2: to Larry.** When the phone can reach the Cockpit, each item waiting goes to Larry's inbox there, oldest
first, once each. A failure leaves it waiting, never marked sent or removed, and is retried the next time the app
is opened, the network returns while the app is running, or, while the app stays open, on its own after a wait
(#565, see *When the Cockpit isn't answering* in the [chat spec](2026-10-25-native-chat-design.md)). Larry sees the item, the note and when it was shared.

How it goes (the Cockpit's side shipped 2026-10-18, cockpit#63):

- **Only over the tailnet**, to the same Cockpit the app's Cockpit screen opens; reaching it is the permission, so
  nothing secret is set up on the phone.
- **When**: each time the app opens or comes to the front, and once more when a send ends if something was shared
  while it was out. No send starts until network availability is known, and none starts while offline. When the
  network returns while the app is running, the offline line disappears and waiting items send automatically.
  After a failed send, a meaningful network change (including the VPN tunnel returning while Wi-Fi stays up,
  or a change in metered or constrained access) retries waiting items too, also when the change came while that
  send was still out. A burst of such changes settles for
  half a second before one retry. Identical network updates do not start extra sends; a return or retry during
  a send requests at most one more pass after that send ends. Sharing from another app never waits on the network.
- **Once each**: an item resent after a lost answer is recognised by the Cockpit as one it already has, and reads
  *sent to Larry* like any other.
- **HEIC photos go as JPEG**; PNG, JPEG, GIF and WebP go as they are. Any photo is made smaller (as a JPEG) if
  needed so each fits the Cockpit's 10 MB.
- **Refused**: when the Cockpit says an item itself is wrong (too big, an unreadable image), it is not retried. It
  reads *Larry's inbox refused it* with the Cockpit's reason, which can be copied. A swipe deletes it as usual.
- **Unreachable or failing** (no tailnet, the Cockpit down): it stays **Not sent yet**, and the log says why.

## Adding from inside the app

Issues [#405](https://github.com/idvorkin/context-grabber/issues/405), [#424](https://github.com/idvorkin/context-grabber/issues/424),
[#422](https://github.com/idvorkin/context-grabber/issues/422); replaced by Chat's **+** in
[#536](https://github.com/idvorkin/context-grabber/issues/536).

The Inbox became Chat (spec 2026-10-25-native-chat-design.md). Its one large, round **+**, fixed at the lower right
above the bottom safe area (#424), now opens a new chat thread with the ordinary thread bar — see *A new chat* in the
chat spec — not a sheet of its own. What the sheet promised still holds there: typing, pasting text and the
keyboard's dictation mic (and the chat mic, #448); **Paste image** when the clipboard holds one, with a preview that
can be removed before sending, the picture kept as copied, in its own format and the right way up; an image needs no
text, and text alongside it is its note; whitespace alone cannot be sent; one Send makes one message. Sending never
waits for the network: a failed save keeps the draft with a copyable error, and a message without a connection stays
*Not sent yet* until the next chance. *Add another* is gone: the thread stays open after its first Send, and its bar
takes the next message once the first has reached Larry.

Every Send produces a `ui` event with the kind and byte size, never the content.

Acceptance criteria:

- One round + stays fixed at the lower right above the safe area, with a generous tap target, in an empty and a
  populated list; there is no top-right +, and the last row can scroll fully clear of the button.
- The + opens an empty new thread with the ordinary bar; typed or dictated text can be sent from it.
- Paste image previews the clipboard image and sends it with any accompanying text as its note; a portrait photo
  stays upright.
- Empty drafts cannot be sent; failed saves preserve the draft with a copyable explanation.
- Each Send is one waiting message kept on the phone, sent through the existing path.

## Explaining itself

- Each share is logged (`inbox`, action added, with the kind and size, never the content) when the app next opens
  and finds it.
- Each send in phase 2 is logged (`inbox`, action sent / refused / failed, with the item and the Cockpit's answer).
- Skipping a send while offline and sending when the network returns are logged (`inbox`, action offline_skipped /
  network_back, with the waiting count, never the content).

## Acceptance criteria

- Sharing a Safari link, a Notes text and a Photos image each puts one item in the Inbox, with the note, within a
  second, in aeroplane mode too.
- The Inbox tile shows the raccoon posting a letter and counts the items not yet sent; deleting one updates it.
- Phase 2: with the Cockpit reachable, every waiting item reaches Larry once and then reads *sent to Larry*;
  with it unreachable or failing, items remain **Not sent yet** and stay counted on the tile.
- With no network, the Inbox shows the quiet offline line and attempts no send; a network that comes up on demand
  (an on-demand VPN) counts as available, so the send is tried and no offline line shows. On network return while the app
  is running, the line disappears and waiting items send without reopening the app; repeated available-network
  updates with identical network details do not cause extra sends, and a send already in progress is never overlapped.
- After a failed send, reconnecting the tailnet while Wi-Fi or cellular stays available retries waiting items,
  even when the tailnet returned before that send failed; meaningful network changes in a burst cause one retry after settling, and an empty Inbox never retries.
- Phase 2: an item the Cockpit refuses reads *Larry's inbox refused it* with the reason, copyable, and is not sent
  again; a HEIC photo arrives at Larry as a JPEG.
