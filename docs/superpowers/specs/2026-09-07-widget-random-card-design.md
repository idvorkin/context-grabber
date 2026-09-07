# A random playing card on the big widget — design spec

> **Status:** Drafted 2026-09-07 from Igor, in the terminal: *"I have 2 screens
> like the big widget, I want to always have a card on it so I can remember to
> try to find a random card."* — *"card means like a playing card, I need to
> always have a random card."* Decided the same day (D1–D3 below): just the
> card, on the big widget **and** the lock screen. Amended the same evening —
> *"Can it flip faster. If I click it can it switch to a new random one?"* —
> every five minutes, and a tap on the card deals a new one.

## Summary

The large Today widget — the one Igor keeps on two home-screen pages — always
shows one playing card, chosen at random, and the card changes on its own
through the day. The same card sits on the lock screen in a small widget of
its own. It is a standing memdeck prompt: glance at the phone, see the seven
of clubs, find it in the stack. Nothing to open, nothing to tap.

## Goals

- Every time Igor looks at the big widget, or at the lock screen, there is a
  playing card on it.
- The card is random and keeps changing, so the prompt never goes stale.
- Every surface shows the same card at the same moment — one card, seen from
  the lock screen and both home-screen pages.
- It reads as a playing card at a glance: rank and suit, red suits red, big
  enough to see without picking the phone up.
- The rest of the widget — steps, sleep, tally, Reflect, timers, the ☎ pill —
  stays where it is and works as before.

## Non-goals

- **Not a weighted deck.** The Drill on the Cockpit quietly deals more of the
  cards Igor is slow on; the widget deals a fair 52. Weighting would need the
  Cockpit's data on the phone, and the widget is meant to be a prompt, not a
  drill.
- **Not the answer.** The widget does not show the card's stack position,
  and there is nothing to flip. The Drill is where he is scored.
- **Not the medium widget.** The smaller layout stays exactly as it is.
- **Not the app's business.** A Grab, a call, a journal entry — nothing the
  app does deals a card. The clock deals, and a tap on the card deals; that
  is all.

## User-visible behavior

**The card.** In the big widget's top block, beside today's steps and sleep,
one playing card: a small white card with rounded corners, the rank in the
corner and the suit under it, hearts and diamonds in red, spades and clubs in
black. Face cards show their letter (J, Q, K), the ace an A, the ten a 10.
It is the same size as the two lines of metrics beside it, so the widget is
no taller than today.

**A new card, regularly.** The card changes every five minutes, on the
clock, whether or not the app is opened, and never repeats the card it just
showed. Both of Igor's home-screen pages and the lock screen show the same
card at the same time — it is one card, seen from three places.

**A new card on demand.** Tap the card — on the big widget, or on the
rectangular or round lock-screen widget — and within a second it is a
different card, on every surface at once, without the app opening. The
clock keeps dealing from there. (The one-line lock-screen widget cannot be
tapped in place; a tap on it opens the app.)

**Fair.** Every card comes up as often as every other: left to the clock,
over any 52 cards each of the 52 appears once. No card is held back and
none is favoured, and a tap does not change that — it only reshuffles.

**On the lock screen.** A small widget in the row under the clock shows the
same card — rank and suit, as big as the row allows, the word *memdeck*
beside it so a stranger's glance reads it as a prompt and not a game. The
lock screen draws widgets in one tint, so the suits there are shapes, not
colours; the round variant shows just the rank and suit, the one-line
variant (above the clock) reads e.g. *7♣ memdeck*.

**Tapping anything else** on the widget does what it did before: the
block around the card opens the app, the tiles and the ☎ pill are
unchanged. Nothing on a widget starts a call.

## Acceptance criteria

1. **Always a card.** Fresh install, no Grab ever: the big widget shows a
   playing card in the top block. Every card that appears is one of the 52.
2. **It changes on its own.** Leave the phone alone for a quarter hour; the
   card is different from the one before and has changed more than once in
   between. Two glances a few seconds apart show the same card.
3. **No stutter.** The card never shows the same card twice in a row — not
   on the clock, and not on a tap.
3a. **A tap deals.** Tap the card on the big widget: within a second it is a
   different card, and the lock screen and the other home page show that
   same new card. Tap again: different again. The round and rectangular
   lock-screen widgets deal on a tap the same way; the one-line one opens
   the app.
4. **Every surface agrees.** The widget on home-screen page 1, the one on
   page 2, and the lock-screen widget show the same card at the same time.
5. **Legible.** From arm's length, red suits are visibly red on the big
   widget and the rank is readable; nothing else in the widget moved or
   shrank to make room. Dark and light appearance both look like a playing
   card.
6. **Lock screen.** Add the widget to the lock screen (Customize → the row
   under the clock): the rectangular one shows the card and *memdeck*, the
   round one the card alone, the inline one a single line above the clock.
   A tap on the rectangular or round one deals; on the inline one, opens the
   app.
7. **The medium widget is untouched.**
8. **Nothing else regresses.** Steps, sleep, exercise, the +1 tally, Reflect,
   the timer tiles and the ☎ pill all still work exactly as before.
9. **A native build.** This is widget code; it ships with `just deploy`, not
   over the air.

## Decisions (Igor, 2026-09-07)

- **D1 — Just the card.** No flip, no stack position. The ask was a reminder,
  not a scorer; the Drill is a tap away.
- **D2 — Lock screen too.** The first ask was the lock screen and the
  correction was the big widget; the answer is both, showing the same card.
- **D3 — A tap deals a new card.** Amended the same day: the first answer
  was "opens the app", then *"if I click it can it switch to a new random
  one?"* Not the Drill call: the ☎ pill already calls, and a card that
  dials Larry on a mis-tap is a card that gets removed.
- **D4 — Every five minutes.** *"Can it flip faster"* — five minutes is as
  fast as iOS reliably turns a widget's page on its own; faster than that
  is what the tap is for.

## Rationale

**Why beside the metrics and not a new row.** The large widget is full — four
rows and three dividers. A card is naturally the height of two lines of
text, and the metrics block has empty space to its right. Adding a row
would push the timers off the bottom on smaller phones.

**Why every five minutes, and why the clock deals.** A memdeck prompt earns
its place by being different each time he looks, and he looks at the home
screen dozens of times a day. The card is a function of the clock and of
how many times the card has been tapped — nothing else — so three widgets
on three surfaces agree without talking to each other, and "never twice in
a row" and "each card once per 52" are facts rather than likelihoods. A
tap is one shared number going up by one; every surface reads it and deals
the same new card. Five minutes is the practical floor for a widget that
turns its own page; the tap covers anything faster.

**Why not the Drill's weighting.** The Drill never tells Igor which cards he
is weak on — his rule, in his words — and a weighted widget is a list of his
weak cards in slow motion. A fair deck keeps that promise trivially.
