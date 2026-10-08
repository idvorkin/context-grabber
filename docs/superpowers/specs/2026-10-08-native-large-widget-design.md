# Today's hand: Grabber Native's large widget — design spec

> **Status:** Igor, 2026-10-08 (#221), asked what goes on the big widget: *"Something new to surprise me."* This is
> the answer; he has not seen it before it ships.

## Summary

A large home-screen widget for Grabber Native, *Today's hand*: the memdeck card, big, that a tap deals in place;
one of the eulogy's roles for the day; and three one-tap starts for the things Igor reaches for: *Think of a card*,
the *Workout Supermix*, and *Call Larry*.

## Goals

- Every glance at the home screen is a memdeck prompt (the old app's large widget did this; the native app had no
  widget that could).
- Every day the widget names one role from the eulogy, so the eulogy is in front of Igor without opening anything.
- The card trick, the workout music and Larry are one tap from the home screen.

## Non-goals

- Today's health numbers. The medium usage tile and the Today screen already carry what the native app grabs.
- Scoring a role, or saying whether it was lived. The role is a nudge, never a grade (the Roles tab's rule).
- Quotes from the eulogy. Only the role names are Igor's words in the app; the passages in the old app are partly
  placeholders, so none are shown.
- A lock-screen card. Lock-screen widgets cannot deal in place; that can come later.

## What Igor sees

**The card** fills the left of the widget, drawn as the card screen draws it: dealt from Igor's memorized stack,
one card per five minutes, changing on its own, and a tap on it deals a different card at once, without opening
the app. With *Skip easy cards* on in Grabber Native, the widget leaves the same cards out. The widget and the card
screen deal separately (Igor, 2026-10-08: the widget deals from the stack, as the trainer screen does).

**The role of the day** is on the right: *Today, be* and one of the eulogy's eleven roles, in the eulogy's order, a
new one each local day, every role once in eleven days. Tapping it opens the app.

**Three buttons** under the role:

- **Think of a card** opens the card screen with the count already running, as the home screen's row does.
- **Workout Supermix** opens the app, which runs Igor's *Play Workout Supermix* shortcut, as the home screen's row
  does.
- **Call Larry** opens the call screen and calls, as a link to the call does.

The widget is listed as *Today's hand*, large size only.

## Acceptance criteria

- With *Today's hand* on the home screen, a card and a role show; the card changes on its own within ten minutes
  and the role changes after midnight.
- Tapping the card shows a different card within a second and the app does not open.
- With *Skip easy cards* on, no breather and no card within two of one shows on the widget.
- Each button lands where it says: the card counting, Shortcuts playing the mix, the call screen calling.
- Over any eleven days in a row, each role is shown once.
