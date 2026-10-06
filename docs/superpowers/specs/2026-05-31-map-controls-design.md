# Map controls: find-me + fullscreen — design spec

> **Status:** Drafted 2026-05-31. Adds two on-map controls to the `StylizedMap` widget shipped in #44 (today's-path overlay). Addresses [#50](https://github.com/idvorkin/context-grabber/issues/50) (find-me) and [#51](https://github.com/idvorkin/context-grabber/issues/51) (fullscreen toggle). The two pair naturally and ship together.

---

## Summary

The embedded map is small and, once you pan/zoom around, there's no quick way back to your own position. Two controls fix that:

1. **Find me** — a locate button that snaps the map back to your current location at a readable zoom.
2. **Fullscreen** — an expand button that blows the map up to fill the screen, with a way back to the embedded size.

## Problem

`StylizedMap` is embedded at a fixed ~180px height on the Today and Places screens. It shows known places, today's path polyline, and a "You" pin. Two friction points:

- After dragging/zooming to inspect the path, there's no one-tap way to re-center on "You" — you have to manually pan back.
- At 180px the path and surrounding streets are cramped; reading the day's movement means squinting.

## Goals

- A **find-me** control that recenters the map on the current location at a useful zoom, without disturbing the path/pins.
- A **fullscreen** control that expands the map to fill the screen and a clear way to collapse it back.
- Both controls read as standard map affordances (locate icon, expand/contract icon) and don't fight the existing copy-coordinates button.
- Everything the embedded map shows — path overlay, known-place pins, the "You" pin — is present in fullscreen too.

## Non-goals

- **No live GPS re-fetch on tap.** Find-me recenters on the location the map already displays (the "You" pin / most-recent fix). It is "snap back to where I am," not "acquire a fresh fix." (Matches the issue's stated need: snapping back after panning.)
- **No new map gestures, layers, or tile styles.** Rotation/pitch stay disabled as today.
- **No persistence of map camera between sessions.** Opening the screen still fits-to-content as it does now.
- **No change to the copy-coordinates control** beyond making room for the new buttons.

---

## User-visible behavior

### Find me

- A **locate control** (standard locate/target icon) sits as an overlay on the map.
- Tapping it **animates** the camera to center on the current location at a **street-level zoom** (closer than the default fit-to-content view), so "You" is centered and the immediate surroundings are legible.
- The known-place pins, the "You" pin, and the today's-path polyline are unaffected — the control only moves the camera.
- The control is **always visible** (so it never vanishes between fixes). If there's no current location yet, tapping it shows a brief **"Waiting for a live GPS lock…"** hint instead of moving the camera, and the control dims slightly to signal it's not ready. *(Amended 2026-05-31: previously hidden without a location; hiding made the buttons disappear whenever a grab missed a fix. We don't fall back to last-known — stale coordinates would mislead.)*
- The **copy-coordinates** control behaves the same: always visible, and tapping it without a fix shows the same hint (there's nothing to copy until there's a location).

### Fullscreen

- An **expand control** (standard expand icon) sits as an overlay on the embedded map.
- Tapping it presents the map **filling the screen**. The fullscreen map shows the same pins, "You" pin, and path overlay.
- In fullscreen, the expand control becomes a **collapse/close affordance**; tapping it (or the system dismiss gesture) returns to the embedded map at its original size.
- The **find-me** and **copy-coordinates** controls are available in fullscreen too.
- Entering fullscreen frames the map to its content (fit-to-content), the same way the embedded map frames on open. (The embedded map's exact pan/zoom at the moment of expansion is **not** carried across — fullscreen opens at the fitted view. See D2.)

### Layout / interaction

- The new controls and the existing copy button coexist without overlapping and remain comfortably tappable.
- Controls use the same translucent dark pill treatment as the existing copy button, for visual consistency.

---

## Acceptance criteria

A non-technical reader should be able to walk these on the device:

- **Find me recenters:** On the Today screen, drag the map far away from your position and zoom out. Tap the locate button. The map animates back so the "You" pin is centered and zoomed to street level. The path and place pins are still drawn.
- **No-lock hint:** With no current location (no fix yet), the locate and copy buttons are still visible (slightly dimmed). Tapping either shows a brief "Waiting for a live GPS lock…" hint and does nothing else. Once a fix arrives, both work normally.
- **Fullscreen expands:** Tap the expand button. The map fills the screen, showing the same path and pins.
- **Fullscreen find-me works:** While fullscreen, pan away, tap locate — it recenters within the fullscreen map.
- **Collapse returns:** Tap the collapse/close control (or swipe down) — the map returns to its embedded size on the underlying screen, unchanged.
- **Copy still works:** In both embedded and fullscreen, the copy-coordinates button copies the current coordinates (shows its ✓ confirmation).
- **No regression:** Pins, the "You" pin, and the polyline render exactly as before when neither control is used.

## Decisions to confirm

- **D1 — Find-me zoom level.** Recenter to a street-level view (proposed: ~0.01° span, roughly a neighborhood) vs. preserving the current zoom and only re-centering. **Proposed default: street-level zoom** — the issue says "resets zoom to a useful default," implying a zoom change, and it's more useful after zooming out.
- **D2 — Fullscreen camera carry-over.** Preserve the embedded map's exact pan/zoom when expanding vs. open fullscreen at the fitted-to-content view. **Proposed default: fitted-to-content** — simpler, predictable, and the user can find-me or pan immediately. (Strict carry-over would need to read the live camera; not worth the complexity for v1.)
- **D3 — Fullscreen presentation.** A full-screen modal vs. a page-sheet (card that doesn't quite reach the top). **Proposed default: full-screen modal** — the whole point is maximum map area.

## Rationale

- **Why recenter on the shown location, not a fresh fix?** The map already plots the most-recent location as "You." The pain is navigational (I panned away), not staleness. Re-acquiring GPS would add permission prompts and latency for no benefit to the stated need. If "live locate" is ever wanted, it's a clean follow-on.
- **Why fit-to-content on fullscreen instead of carrying the camera?** It's the behavior the embedded map already uses on open, so it's consistent and needs no new camera-reading plumbing. Find-me covers the "take me to my exact spot" case in one tap.

## Cross-references

- The map widget, path overlay, pins, copy-coordinates control: `components/StylizedMap.tsx` (shipped in #44).
- Embedding screens: Today and Places screens.
