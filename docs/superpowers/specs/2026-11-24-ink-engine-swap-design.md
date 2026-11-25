# Swap the iPad board's ink engine for the web board's (behind a setting)

Status: proposal, 2026-11-24. Nothing is built. It waits on Igor's pick of A or B below, made after the latency measurement in step 0.

## Summary

Igor decided on 11/24 at 18:16 that the iPad board should draw with the web board's ink engine, so the two boards behave and look the same. The rest of the app stays as it is, and a Settings switch chooses the engine. This spec answers his first question honestly: is it just PencilKit? It then compares two ways to do the swap and recommends one.

## Is it "just PencilKit"? No

The iPad board is built on PaperKit, Apple's markup board, which has PencilKit inside it. Together they give the board all of the following. The web engine must provide each one, or the swap must rebuild it.

| What the board gets today | Where it comes from | Does the web engine have it? |
|---|---|---|
| Pencil-to-pixel latency, with predicted touches and Apple's low-latency drawing path | PencilKit | Partly. Safari delivers pen events about a frame later. The web measured 16 ms median input-to-frame at 60 Hz; the iPad's number comes from the pen-latency log after the next install. |
| Pressure | PencilKit | Partly. Safari on this iPad has reported a constant pressure, so the page falls back to simulated pressure. |
| Tilt and azimuth (shading with a tilted Pencil) | PencilKit | No. |
| Ink types: pen, marker, pencil, fountain pen, watercolor | PencilKit | No. There is one pen, drawn as a smooth outline. |
| Eraser: whole-stroke and pixel (part of a stroke) | PencilKit | Whole-stroke only. |
| Lasso select, move, and copy and paste of strokes | PencilKit and PaperKit | Yes: lasso, move and paste in the board rules. |
| The tool picker (tools, colours, widths) | PencilKit | Its own small toolbar. |
| Undo and redo | PaperKit, through the system undo | Yes, its own: a 200-step snapshot stack. |
| Scrolling, pinch zoom, and "the Pencil never zooms" | PaperKit's scroll view, with the app's own guard | Scrolling only, with no zoom (the page is locked to its width). |
| Shapes, text boxes and arrows | PaperKit markup | Yes: texts, kept labels and connectors in the board rules. |
| Scratch-out and hold-to-shape | the app's own rules (shared with the web) on PencilKit strokes | Yes: the same shared rules. |
| Scribble (handwriting into a text field) and the system edit menu | UIKit and PaperKit | No. Scribble isn't needed on the board, and the edit menu was removed on purpose by #1385. |
| VoiceOver and other accessibility | PaperKit | Little. |
| The saved board format | an Apple drawing plus the app's own meaning, in iCloud | Different: the web's JSON strokes. The Cockpit store (t12b) makes that the one format. |

The app also hooks into PaperKit's drawing in dozens of places: ghost replies, the kept-ink look, the hold menu, room-making, folds, review, playback and the pen-latency probe. A swap touches most of the board's code, not one file. A Settings switch means both engines live side by side until one is retired.

## The two ways

**A. A web view.** The iPad board shows the web board's ink page, bundled in the app so it works offline. A bridge carries what the app's shell owns: the board list, the chat panel, the mic, Larry's turns, Send to Larry, and the session log.

**B. A native port.** The web engine's drawing (its smooth outline and the board model) is rebuilt in Swift, drawn natively, with the board rules shared as today. PencilKit and PaperKit leave the board.

| | A: web view | B: native port |
|---|---|---|
| Same engine as the web | Yes, the same code | Same rules; a second drawing renderer that must look identical (checked against reference pictures) |
| Pencil latency | WebKit's: about one frame behind native, to be measured | Can match native: predicted and coalesced touches |
| Pressure and tilt | Whatever Safari reports (pressure unreliable, no tilt) | Full |
| Zoom | None unless the web adds it | Native pinch, with the Pencil-never-zooms rule |
| The app's native features (ghosts, Keep, mic, panels) | Bridged; much already exists in the web board (keep, turns, panel, voice) | Rewired from PaperKit onto the new canvas |
| Offline | The page is bundled; it must not be fetched from the Cockpit | Native |
| Work | Medium: the bridge plus bundling, then retiring the native board's PaperKit-specific code | Large: renderer, eraser, lasso, undo, zoom, toolbar, then rewiring dozens of hooks |
| Fits t12b (one board format in the Cockpit) | Exactly: it is the web format | Yes, after the port |
| Risk | Pen feel on the iPad | Time; two renderers drifting apart |

## Recommendation

Measure first, then pick A unless the measurement rules it out.

0. **Measure (no new code).** The debug screen *Ink side by side* already puts PencilKit on the left and the Cockpit's ink page on the right, with a live latency readout on each. The board's new pen-latency log line records the native side during real use. Igor writes a few lines on each half on the iPad, and both numbers land in the session log.
1. **If the web side is within one frame of native and feels fine to Igor, build A** behind the Settings switch, with the bundled page and the bridge. It is the shortest path to one engine everywhere, and it matches the Cockpit store the boards are moving to.
2. **If the web side is clearly worse** (more than a frame behind, or pressure unusable), build B: port the outline renderer first, then the eraser, lasso, undo and zoom, retiring PaperKit last.

Either way the switch defaults to today's engine until Igor says the new one is good.

## What Igor sees

- Settings gains **Ink engine: iPad / Web**, and the board reopens with the chosen engine.
- On the web engine the board looks and behaves as the web board does: the same pen, eraser, lasso, folds and Keep. The board list, chat, mic and Larry stay where they are.
- Tilt shading and the other ink types are gone on the web engine; fountain pen and pencil are iPad-engine only.

## Acceptance (for whichever is built)

- The switch changes the engine without losing the open board.
- A stroke drawn on the iPad's web engine appears the same on the web board, and the other way round, once boards share the Cockpit store.
- The session log records pen latency on both engines, so the pick can be re-checked.
- Everything the board does today (Keep, ghosts, mic, Send to Larry, review, playback) still works on the new engine, or is listed as not yet ported.

## Open questions

- Igor: A or B after the measurement? Is losing tilt and the extra ink types acceptable?
- Larry: can the ink page run fully from a bundled copy (no Cockpit fetch for its scripts)? Does the web board want zoom?
