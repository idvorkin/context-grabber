# Whiteboard: question cards

Larry's web board (/ink) shows his open asks as live cards on the board (the Cockpit's FEATURES.md, *Ink*, "Question
cards"). This brings them to the app's board, so a question Larry asks about a drawing waits on that drawing and is
answered there, with the same effect as answering it in the Cockpit's Inbox. Part of
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md); the answering itself is Chat's
[decision cards](2026-11-14-chat-decision-cards-design.md), reused.

## Summary

An *ask* is a decision Larry is waiting on Igor for. When Larry asks one about a board, it lands on that board as a
card: one line, *? \<question> ···*, in Larry's purple. A tap opens it to answer. Once answered, the card stays on the
board, small and grey, as *✓ \<question>* over the answer, because a question answered is still worth seeing on the
drawing it was about. An answered card can fold to a one-line chip, and the eraser takes it away.

## Goals

- A question about a board is seen on that board, where the drawing it is about is.
- Answer it from the board in a tap, exactly as on the Cockpit's Inbox or Chat's decision card.
- Keep the question and its answer on the board afterwards, without the network.

## Non-goals

- Making or editing asks (Larry files them).
- Deleting an archived card for good: the eraser is the way a card leaves for good, and only from the board.
- A card pushing ink out of its way: a card lies over the board where it landed or where Igor dragged it.
- Cards on another device's copy of the board, or on a board only looked at: the cards live with the board on the
  device that draws it, as its chat thread does.
- An option picked together with a note: an option answers in one tap, as in Chat; *your own answer* is the other way.

## What Igor sees

**Where a card comes from.** Either way, once per ask on a board:
- Larry's reply on the board's thread holds a question for an ask: the card lands where he put it, inside the page.
- An open ask names the board, by its thread or in its context: when the board opens, its card lands at the top of what
  is on screen, near the left margin; several land one under another.

**An open card.** One line: *? \<question> ···*, cut with *…* to the card's width, on a pale purple card edged in
Larry's purple. Until the Cockpit's asks have been read it says *? Question ···*. It sits on the paper and moves and
zooms with the board.

**Answering.** A tap on an open card opens it over the board: the ask's question, Larry's context, and its options as
Chat's decision card shows them (the default marked, the expiry, the ⋯ menu with Snooze, Close… and Abandon). A tap on
an option answers at once. Under the card, *Your own answer* and *Send* answer in Igor's words instead (needed for an ask
with no options). The card in the popup has no *Other…* of its own, as it has in Chat: this field is the
board's way to answer in Igor's words, already open. Larry's own-answer option (keyed *other*, or labelled *Other*,
*Something else*, *Type your own answer* and the like, as Chat's decision cards define it) is drawn, and a tap on it
answers nothing: it puts the cursor in *Your own answer* with the keyboard up, ready to type or dictate, and *Send*
stays off until there are words. The answer can be spoken: a mic sits immediately beside *Send*, after the field, both at least a
finger tall and wide (Igor, 2026-11-03, #625: the record button goes by Send on every input). It is Chat's mic: a tap
records, it turns red with the seconds, the words fill the field after what was typed, and a tap stops it; nothing is
sent until *Send*. *Send* or closing the popup stops a recording. A call, or another recording, holding the microphone
says so under the field, as in Chat. The Cockpit takes the answer exactly as the Inbox's (*DECISION: \<label>*, or *DECISION: \<words>*);
the popup closes and the card is answered. A snooze leaves the card open. A close or an abandon answers the card with
*Closed* or *Abandoned* and the reason under it.

**Folding an open card** (Igor, 2026-11-22, bead context-grabber-fjh0: *"I should also be able to re-collapse decision
cards"*). The opened question's decision card carries Chat's fold control beside its **⋯**. On the board a tap on it
folds the card back to its one line on the paper: the popup closes, nothing is answered, and the card is open as
before, a tap away. The control still works while an answer or menu action is on its way. If Igor opens another
question before that request finishes, the other popup stays open. The popup always opens with the decision card
whole, whatever its fold in Chat.

**When it fails.** As Chat's card: a refused answer leaves the popup open with a copyable problem, and its buttons live
again; one changed since it loaded says so and shows the ask as it now is. One already answered elsewhere, or no longer
open, closes the popup's question: the card fetches its answer (below), and the popup says *This question is no longer
open in the Cockpit (answered or closed).* when there is none to show.

**An answered card.** Grey, two small lines: *✓ \<question>* over the answer (the option's label, or the words, then
the note). It stays on the board, saved with it, and shows with no network.

**Answered elsewhere.** When the board opens and a card's ask is no longer open (answered in the Inbox, in Chat, or
closed by Larry), the card asks the Cockpit for that ask's question and answer and shows them. If the Cockpit has none
yet, the card says *✓ answered* and asks again the next time the board opens.

**Reading and folding.** A tap on an answered card opens it read-only: *✓ \<question>*, the answer in full, the note,
with *Shrink* and *Close*. *Shrink* folds the card to a one-line chip, *✓ \<question>*, only as wide as its words.
A tap on a chip opens it out again. (It was called *Collapse* until 2026-11-24, when Collapse became the round *?*
below; not *Fold*, which on the board means ink folded away.)

**Collapsing a card** (Igor, 2026-11-24, #1387: *"as well as collapse there should be just sort of Hide, and if I press
hide there should be a '?', that's just a '?'"*, then 07:51: *"Collapse question: this makes a little round"*). Every
card's popup, open or answered, has *Collapse* (first built as *Hide*). It closes the popup
and shrinks the card to a bare *?* on the board: a small round mark, Larry's purple for an open question, grey for an
answered one, a finger's size at the board's normal zoom. The *?* sits where the card's left end was, at the place
Larry put it beside the ink it is about (Larry agreed 2026-11-24; Igor is unsure, and drags it where he wants; the
margin was the other choice). A tap on the *?* brings the card back as it was, open or answered, folded or not; it opens no popup.
A hidden card stays hidden when the board is closed and opened again. The eraser takes an answered card's *?* as it
takes the card; an open question's *?* stays.

**Archiving a card** (Igor, 2026-11-24 07:51, #1387: *"Archive: it goes away, and maybe I have archived answers
somewhere that I can open behind some menu"*). Every card's popup, open or answered, has *Archive*. It closes the popup
and the card leaves the board; nothing is answered, and an open ask stays open in the Cockpit (answered there, the
archived card shows that answer when the board next reads the answers). The board's menu then has *Archived questions*,
only while the board has some: it lists each archived question, newest archived first, with its answer under it or
*open*, and *Reopen* beside it. *Reopen* puts the card back on the board where it was, as it was (open or answered, a
chip, a *?*), and takes it off the list. An archived card never lands on the board again by itself, neither from
Larry's reply nor from an open ask, and the eraser can't reach it. It stays archived across a reopen of the board.

**Thinking it over** (Igor, 2026-11-24 07:51, #1387: *"Thinking: that's a great idea that should go back-and-forth"*).
An open card's popup has *Thinking*. It answers nothing: it opens *Talk it over* in the popup, under Larry's question,
with the ask's own conversation (every ask has its own chat thread on the Cockpit), Igor's messages and Larry's
replies in order, the newest last, and a field with Chat's mic and *Send*. *Send* posts Igor's words to that
conversation; the ask stays open, and Larry replies there. While the popup is open, Larry's replies appear in it as
they come (read every few seconds). From then on the card is a card being thought over: on the board its line reads
*… \<question\> ···* in place of *? \<question\> ···*, and a tap opens the popup at *Talk it over*. Igor can still
pick an option or answer in his own words at any time; that answers the ask as before, and the card turns answered,
its conversation kept on the Cockpit. A failed read of the conversation says so in the popup, copyably; a refused or
lost send keeps the words in the field, with a copyable problem, for another try. Offline, *Thinking* is off.

**A double tap cycles the card's looks** (Igor, 2026-11-24, #1387, settled with Larry). A double tap on a card on the
board steps it to its next look, without opening the popup: an answered card goes full → short (its one-line chip,
*Shrink*) → *?* (*Collapse*) → full; an open card, already one line, goes full → *?* → full. A single tap still does
what it did.

**An answered card reads as text** (Igor, 2026-11-24, #1387; Larry: still a question card). Once answered, the card is
drawn as plain text on the board, the question small over the answer, with no card's fill or edge; it still opens,
shrinks, collapses, archives, moves and erases as an answered card does.

**The controls sit in one spot** (Igor, 2026-11-24, #1387: *"use icons all in same spot"*). A card's controls
(*Shrink*, *Collapse*, *Archive*, *Thinking*, as the card allows) are icons in one fixed place, the same on every card
in every look, so Igor learns one spot. Where that spot is, and how the looks above are drawn, comes from a design pass
on the card's states (before and after pictures to Larry) before it is built; until then the controls are the popup's.

**Moving a card** (#1387: *"I should be able to move it around, and move questions"*). A card, a chip or a *?* can be
dragged anywhere on the board, with a finger or the Pencil: it follows the touch and stays where it is let go, kept
inside the page, and it stays there when the board is opened again. A drag never opens the popup and never draws; a
tap without moving still opens it. With the eraser in hand nothing moves: a stroke that starts on a card erases or
leaves it, as below.

**The eraser.** With the eraser in hand, a stroke across an answered card or chip takes it off the board, as it would
ink. Only a touch that would erase ink takes it: the Pencil, or a finger while fingers draw; a finger that pans the
board takes nothing. An open card is still live: the eraser leaves it.

**When the asks are read.** When the board opens or comes back on screen, when a question of Larry's lands, and when a
card is opened. Offline, or with no Cockpit address, nothing is read: the cards on the board stay as they are, and an
open card's popup says the Cockpit's asks didn't load.

## Explaining itself

The session log says when cards landed (how many, from Larry's reply or from the open asks), when a card's answer came
from the Cockpit, each card opened (open or answered), each answer and its outcome (Chat's own decision events, from
the board), a fold (an open card's or an answered one's) and an opening-out, a card hidden and shown again, a card
moved (where to), a card archived and reopened, a card turned to thinking, each message sent to an ask's
conversation and how many replies a read found (never the words), a card erased, and a failed read of the asks or the answers, once until one
works. Never the answer's words.

## Acceptance criteria

- Larry's reply holding a question for an ask puts one card for it on the board, at his place, once.
- An open ask that names the board's thread or the board shows as a card when the board opens.
- A tap on an open card opens it; an option or Igor's own words answer it as the Inbox would, and the card turns into
  *✓ \<question>* over the answer.
- Larry's own-answer option (keyed *other*, or labelled *Something else*, *Other* and the like) shows in the popup's
  card; a tap on it sends nothing and puts the cursor in *Your own answer*; only Igor's words are ever sent from it.
- A card whose ask was answered elsewhere shows that answer once the Cockpit gives it.
- An answered card opens read-only, folds to a one-line chip, and a tap opens the chip out.
- An opened card not yet answered folds back to its one line from the fold control, answering nothing.
- An answered card's popup says *Shrink* (to its chip); every card's popup says *Collapse* (to its *?*).
- Any card archives off the board; *Archived questions* in the board's menu lists it with its answer or *open*, and
  *Reopen* puts it back where it was, as it was. An archived card never lands again by itself.
- *Thinking* on an open card opens its conversation with Larry in the popup; Igor's words go there and Larry's replies
  show, the ask stays open, and the card reads *… \<question\> ···* until an option or his words answer it.
- Any card collapses to a bare *?* where its left end was; a tap on the *?* brings it back as it was, and it stays hidden
  across a reopen.
- A card, a chip or a *?* drags to anywhere on the page and stays there, across a reopen; a drag opens nothing.
- The eraser takes an answered card and leaves an open one.
- Offline or with no address nothing is read, and the board's cards stay as they were.

## Depends on the Cockpit

`GET /asks?snoozed=1` (the open asks, the snoozed ones too, so a snoozed ask's card stays open), `POST /act` (the
answer), and `GET /ink/answers?ids=` (the question and answer of closed asks, the decisions log first). Larry places a
card with a `question` shape in a reply on the board's thread: the ask's id and where, in the picture's pixels.
*Thinking* uses the ask's own chat thread, keyed by the ask's id: `POST /chat` with `subject_id` set to the ask's id
and Igor's words (as a board's chat post, no picture), and `GET /chat/<ask id>` for the conversation (Larry,
2026-11-24: no new route or verb; the ask closes only when an option or Igor's words answer it).
