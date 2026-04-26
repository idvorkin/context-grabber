# Location Sheet Cleanup

## Summary

Remove the raw monospace summary text block from the Location detail sheet. The structured per-day Places breakdown below it already conveys the same information visibly, so the paragraph reads as noise.

## Goals

- Remove visual noise from the Location detail sheet.

## Non-Goals

- Changing what data is collected.
- Changing what gets shared via Summary / Raw export.
- Modifying the per-day Places breakdown card (kept).

## Behavior

Acceptance criteria:
- Opening the Location sheet shows: header, coordinates card (current location, point count, Copy Coordinates / Copy Daily Summary / Copy Location Details buttons), Places breakdown card, Known Places editor, Export Database. No Courier-font paragraph.
- Sharing the Summary export still includes the `places` field (recent + weekly) — only the visible UI text is removed.

## Rationale

The raw text dump was a debug artifact that survived into the shipping UI. It only rendered after the user tapped the Location card, so it was easy to miss; once seen, it was unhelpful.
