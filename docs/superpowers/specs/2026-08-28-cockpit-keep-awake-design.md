# The Screen Stays Awake While a Call Is Live — Design Spec

**Status:** Proposed (revised: a function of the call, not the tab — Igor, PR #76 review)
**Date:** 2026-08-28
**Owner:** Igor
**Issue:** [#72](https://github.com/idvorkin/context-grabber/issues/72) · bead `context-grabber-d9d` · igor2 `igor2-88g.188.1`
**Depends on:** [Cockpit Tab](2026-08-27-cockpit-tab-design.md), [Cockpit Audio Bridge](2026-08-28-cockpit-audio-bridge-design.md)

## Summary

Igor, on a call, 2026-08-28 08:01: *"check if Context Grabber can prevent the
screen from locking. When I'm on the Cockpit screen, I want to make sure it
doesn't lock."* And on the first cut of this, which held the screen for the
whole tab: *"Actually, make it a function of the call, not the tab."*

Today the phone's auto-lock runs during a call. The screen dims and locks
mid-sentence; iOS then suspends the web view's audio capture, and the call
dies.

While a Larry call is live in the Cockpit — from the moment it starts
connecting until it ends — the phone does not auto-lock. The rest of the
time, the Cockpit tab included, the phone's own lock settings apply exactly
as before.

## Goals

- A call never dies because the phone auto-locked while Igor was listening
  or thinking.
- The hold is exactly as long as the call. Reading a decision, browsing PRs,
  or leaving the Cockpit tab open on a desk does not keep the screen on.
- Nothing to set up, nothing to remember. It is a property of the call.

## Non-goals

- **Keeping a call alive through a lock.** If Igor locks the phone himself
  with the side button, the call ends the way it does today. Surviving a lock
  is [#73](https://github.com/idvorkin/context-grabber/issues/73) /
  [#74](https://github.com/idvorkin/context-grabber/issues/74).
- **A toggle.** No setting, no switch.
- **Holding the screen for the tab.** Deliberately reversed from the first
  cut: the Cockpit tab with no call running behaves like every other tab.
- **Other tabs.** The Gym Timer already keeps the screen awake while it runs;
  nothing else changes.

## User-visible behavior

- Start a call (the page's handset, or a `grabber://call` link). From the
  moment the Call tab says *connecting…* the screen stays lit — no dim, no
  lock — for as long as the call lasts. Ten minutes, an hour.
- End the call (hang up, Larry hangs up, the bridge drops): within the
  phone's normal auto-lock interval the screen dims and locks as it always
  has.
- Switch to another tab mid-call: the call keeps running in the Cockpit and
  the screen stays awake. The call is the reason, not the tab.
- Press the side button mid-call: the phone locks. This never fights a
  deliberate lock.
- Background the app mid-call (home gesture, app switcher): the phone's own
  rules apply while the app is away. Come back with the call still live: the
  screen stays awake again, without a tap.
- Reload the Cockpit page, or lose it (the "Can't reach the Cockpit" pane):
  the call is gone, and so is the hold.
- On the Cockpit tab with no call — reading, browsing, the reconnect pane —
  the phone locks on its usual schedule.
- No indicator. During a call the screen simply does not go dark.

## Acceptance criteria

1. Auto-lock set to 30 seconds. Start a call and leave the phone untouched for
   5 minutes: no dimming, no lock, call still live.
2. Hang up and wait: the phone locks within the configured interval.
3. Mid-call, switch to the Today tab and wait 5 minutes: still lit, call
   still live.
4. Mid-call, the side button locks the phone immediately.
5. Mid-call, background the app and wait past the interval on the home
   screen: the phone locks. Reopen with the call still live: 5 minutes
   untouched, still lit.
6. Cockpit tab open, no call, 5 minutes untouched: the phone locks.
7. Mid-call, pull-to-refresh the Cockpit page: the call ends and the phone
   locks on schedule afterwards.
8. The Gym Timer's existing behaviour is unchanged.
9. Fresh install, no settings touched: 1–7 hold. There is nothing to enable.

## Rationale and risks

**Why the call, not the tab.** The first cut held the screen for the whole
tab on the reasoning that Igor reads decisions there too. He disagreed: the
thing that must not die is the call, and a tab left open on a desk should
lock like any other screen. A rule about the call is also the rule that
survives the native call screen (#74), where there is no tab at all.

**Why the page says when.** Only the Cockpit page knows when a call is
connecting, live, or over — it owns the socket. It tells the app, over the
same channel it uses for the audio bridge, and the app holds or releases
the screen accordingly. A page that goes away (reload, load failure, a
content-process kill) is a call that has ended, whether or not it managed to
say so.

**Risk: a hold that outlives the call.** If the page died without saying
"ended", the screen would stay lit until the next launch. The rule that any
page load, error, or teardown releases the hold is what prevents that.

**Ships as an over-the-air update** plus a Cockpit page change. The
capability is already in the shipped binary.
