# The Board Lab: the board alone, for its UI tests

Bead context-grabber-09tx (whiteboard refactor D3 slice 4). Story 1501. Plan:
[2026-11-22-board-lab-plan.md](../plans/2026-11-22-board-lab-plan.md).

## Summary

A second, small app for the simulator that opens straight onto the whiteboard's boards list. It is the same board with
the same rules and launch hooks, and nothing else of the app. A whiteboard UI test launches it instead of the whole
app, and so waits less for the parts of a launch it doesn't need.

## Goals

- A whiteboard UI test can launch the Board Lab and find the boards list as the app's open-the-boards launch hook
  leaves it, the same buttons under the same names, so a test class moves to the lab with no change to its code.
- It opens on a chosen state: a new board, or a board from the app's board fixtures (a board drawn on another
  device).
- It opens on a chosen recorded Cockpit session: Larry answers its board as he did in that recording, through the
  simulator's stand-in Cockpit.
- It never shares the app's data on the simulator: its own boards, settings and logs.

## Non-goals

- Not on the iPhone or the iPad: it is never installed on a device and has no widgets, share extension, Health or
  iCloud.
- Not every class moves at once: two in the first change, as proof, with the time measured. The rest follow only if the
  numbers say the lab pays for its build.
- Not the board's ink from a recorded session (Larry's side only for now).

## Acceptance criteria

- On the iPad simulator, the lab launches to the boards list with *New* ready, and the two moved classes pass there,
  run by the whiteboard UI test script with the app's own classes.
- The plan's table holds the measured before and after: class seconds, launch seconds per case, and the lab's added
  build time.
- The lab answers none of the app's links. A `grabbernative://` link opens Grabber Native even on a simulator or device
  where the lab is installed beside it: two apps claiming one link scheme let the system hand it to either (the store
  walk of 2026-11-24 found every warm link landing in the lab, bead context-grabber-3hj9.1).
