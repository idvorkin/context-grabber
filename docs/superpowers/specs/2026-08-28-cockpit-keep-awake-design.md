# Cockpit Tab Keeps the Screen Awake — Design Spec

**Status:** Proposed
**Date:** 2026-08-28
**Owner:** Igor
**Issue:** [#72](https://github.com/idvorkin/context-grabber/issues/72) · bead `context-grabber` (keep-awake) · igor2 `igor2-88g.188.1`
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md)

## Summary

Igor, on a call, 2026-08-28 08:01: *"check if Context Grabber can prevent the
screen from locking. When I'm on the Cockpit screen, I want to make sure it
doesn't lock."*

Today the phone's auto-lock runs while the Cockpit tab is showing. On a call,
the screen dims and locks mid-sentence; the web view's audio capture is then
suspended by iOS, and the call dies. Reading a long decision has the same
problem at a slower pace.

While the Cockpit tab is the one on screen, the phone does not auto-lock. On
every other tab, and whenever the app is not in front, the phone's own lock
settings apply exactly as before.

## Goals

- On the Cockpit tab, the screen stays on for as long as Igor leaves it there —
  through a whole call, through reading a whole decision.
- Leaving the Cockpit tab hands control back to iOS immediately: the usual
  auto-lock timer applies on Today, Body, Move, Mind, Places, Roles.
- Nothing to set up, nothing to remember. It is a property of the tab.

## Non-goals

- **Keeping a call alive through a lock.** If Igor locks the phone himself with
  the side button, the call ends the way it does today. Surviving a lock is
  [#73](https://github.com/idvorkin/context-grabber/issues/73) / [#74](https://github.com/idvorkin/context-grabber/issues/74).
- **A toggle.** No setting, no switch on the tab. If it ever needs to be
  optional, that is a spec change.
- **Letting the page decide.** The Cockpit web page is not told about this and
  cannot turn it on or off. The tab being frontmost is the whole rule.
- **Other tabs.** The Gym Timer already keeps the screen awake while it runs;
  nothing else changes.

## User-visible behavior

- Open the Cockpit tab and put the phone down: the screen stays lit — no dim,
  no lock — for as long as the tab is showing. Ten minutes, an hour.
- Switch to any other tab: within the phone's normal auto-lock interval the
  screen dims and locks as it always has.
- Press the side button on the Cockpit tab: the phone locks. This never fights
  a deliberate lock.
- Background the app from the Cockpit tab (home gesture, app switcher): the
  phone's own rules apply while the app is away. Return to the app on the
  Cockpit tab: the screen stays awake again, without a tap.
- The Cockpit's "Can't reach the Cockpit" error pane counts as the Cockpit tab:
  the screen stays awake there too, so a reconnect can be watched.
- No indicator. The screen simply does not go dark.

## Acceptance criteria

1. With auto-lock set to 30 seconds, the Cockpit tab left untouched for 5
   minutes shows no dimming and no lock.
2. Switching from the Cockpit tab to Today and waiting: the phone locks within
   the configured interval.
3. On the Cockpit tab, the side button locks the phone immediately.
4. Background the app from the Cockpit tab, wait past the auto-lock interval on
   the home screen: the phone locks. Reopen the app: it lands on the Cockpit
   tab and the screen stays awake again for 5 minutes untouched.
5. The Gym Timer's existing behaviour is unchanged.
6. Fresh install, no settings touched: 1–4 hold. There is nothing to enable.

## Rationale and risks

**Why the tab, not the call.** The issue offered the page a hook to hold the
screen only during a call. The tab is the simpler rule, and it is also the
right one: Igor reads decisions on this tab, not only calls. A rule that needs
the page's cooperation has two things that can be wrong; a rule about the tab
has one.

**Risk: battery.** A tab left open on a desk drains the battery. That is the
behaviour Igor asked for, and it is bounded by the tab: the moment he moves
on, iOS is back in charge.

**Ships as an over-the-air update.** The capability is already in the shipped
binary; no App Store or device build is needed.
