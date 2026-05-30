# Journal: inline role tagging + group-by-role — design spec

> **Status:** Drafted 2026-05-30. Addresses [issue #47](https://github.com/idvorkin/context-grabber/issues/47). Extends the [Affirmations & Gratitude Journal](2026-05-10-affirmations-journal-design.md) and [Roles ↔ Journal linking](2026-05-30-roles-journal-linking-design.md) specs. The forward (card → role) and reverse (role → entries) tagging directions already shipped (`4afbfd5`, `be2359f`); this spec adds **editing tags from the Journal itself** and a **group-by-role view**.

---

## Summary

Two journal improvements:

1. **Inline role tagging.** Today an entry's role tags are fixed at creation time on the Affirmation/Grateful card. This adds the ability to see an existing entry's role tags directly in the Journal and add or remove them after the fact.
2. **Group toggle.** The Journal can group either **by affirmation** (today's date → context → affirmation) **or by role** (date → role → context).

## Problem

- **Tagging is write-once.** If you forget to tag a moment to a role when you log it — or realize later it also belonged to another role — there's no way to fix it short of delete-and-re-log. The role↔journal link is bidirectional in *display* but not in *editing*.
- **The Journal has one lens.** You can filter to a single role, but you can't see the whole journal reorganized *by* role — e.g. "show me everything, grouped by who it was about." Affirmation is the only grouping spine.

## Goals

- From a Journal entry, **see which roles it's tagged to** at a glance.
- From a Journal entry, **add or remove role tags** without deleting the entry.
- **Toggle the Journal's grouping** between by-affirmation (current) and by-role.
- Edits persist immediately and survive app restart, like every other journal write.

## Non-goals

- **Smaller tags / compactness pass** (issue #47 item 2) — deferred. The filter-strip chips, recent-moment cards, and eulogy/attention chips stay their current size for now.
- **Better role icons** (issue #47 item 3) — deferred. Direction TBD by Igor.
- **No editing of entry text, context, or affirmation.** Only role tags become editable. Delete-and-re-log remains the only path for the entry's content (matches the journal spec).
- **No new role-moment sources or auto-detection.** Inline tagging creates the same kind of manual role-moment a card tag does.
- **No change to the card-side role picker** or to how the role filter strip behaves.

---

## User-visible behavior

### 1. See an entry's roles in the Journal

Every Journal entry row shows the **roles that entry is currently tied to**, rendered as a small horizontal row of role avatars beneath the entry, alongside a way to edit them.

- "Tied to" means exactly what the role filter already means: any role whose moments resolve back to this entry. This includes the automatic `emo` link that every untagged entry gets at creation time — so an entry's displayed roles always match which role filters would surface it.
- An entry with no role links shows just the edit affordance (e.g. a `+` to add the first tag), no avatars.
- The avatars are small and unobtrusive; tapping them is how you edit (see below).

### 2. Add / remove role tags inline

Tapping an entry's role avatars (or its `+` when it has none) opens a **compact role picker** for that entry:

- The picker shows all roles, with the entry's current roles pre-selected.
- Tapping a role **toggles** it: selecting adds a role link to the entry; deselecting removes it.
- Changes **persist immediately** — there's no separate save step, or a single obvious confirm/done that writes. (Implementation may choose tap-to-toggle-persists or a small Done button; either way the result is durable on dismiss.)
- After editing, the entry's avatar row and any open role filters reflect the change on the next refresh.

**Direct-manipulation model (the one behavioral nuance):** the avatars shown on a row *are* the complete set of role links, and the picker toggles exactly that set. Specifically:

- Adding a tag to an entry that currently has only the automatic `emo` link does **not** silently remove the `emo` link — `emo` stays selected until you deselect it. (This differs from create-time, where choosing explicit roles suppresses the auto-`emo` default. Here, what you see is what you toggle.)
- Removing every tag leaves the entry with **no** role links. It is not auto-re-tagged to `emo`. It simply stops appearing under any role filter.
- Re-adding a role you previously removed creates a fresh manual link; it behaves identically to a card tag.

Edge cases:

- Toggling a role on an entry that's **already** linked to that role via multiple moments (e.g. duplicate) removes all of them on deselect; the entry ends up cleanly untagged for that role.
- If the underlying role-moment table is missing/not-yet-migrated, the avatars render empty and editing is a no-op rather than an error (consistent with the existing tolerant reads).

### 3. Group toggle: by affirmation ↔ by role

The Journal gains a **grouping toggle** at the top (a small segmented control):

- **By affirmation** (default, current behavior): date → context → affirmation → entries.
- **By role**: date → role → context → entries.

By-role behavior:

- Within each day, entries are grouped under each role they're tied to (using the same entry→roles resolution as the avatars and the filter).
- An entry tied to **multiple roles** appears under **each** of those roles within that day.
- Entries with **no role tag** collect under an **"Untagged"** group at the end of each day. (Grouping displays every entry — unlike the filter, which hides untagged entries. The toggle reorganizes; it never hides.)
- Within a role, the existing context ordering (Opportunities → Did-Its → Gratitudes) is preserved.
- The grouping toggle is independent of the role **filter strip**: filtering to one role still works in both grouping modes (in by-role mode it simply narrows to that one role's group).
- Every grouping level stays collapsible, as today.

---

## Acceptance criteria

A non-technical reader should be able to walk these on the device:

- **See roles on a row:** Log an affirmation tagged to *Amelia* and *Family*. Open the Journal. The entry's row shows the Amelia and Family avatars.
- **See the auto-emo link:** Log a gratitude with **no** role tag. Open the Journal. The entry's row shows the *emo* avatar (the automatic link), matching that it appears under the *emo* filter.
- **Add a tag inline:** On an existing entry, tap its avatars/`+`, select *Tori*, dismiss. The row now shows *Tori* among its avatars, and filtering the Journal to *Tori* now includes the entry. Restart the app — the tag is still there.
- **Remove a tag inline:** On that entry, open the picker, deselect *Tori*, dismiss. The *Tori* avatar is gone and the *Tori* filter no longer includes it.
- **Remove all tags:** Deselect every role on an entry. The row shows no avatars and the entry appears under no role filter (including *emo*). It is not auto-re-tagged.
- **Group by role:** Switch the toggle to **By role**. The Journal reorganizes to date → role → context. The Amelia+Family entry appears under both *Amelia* and *Family* for its day. A never-tagged-and-emo-stripped entry appears under **Untagged**.
- **Toggle is reversible:** Switch back to **By affirmation** — the original date → context → affirmation view returns, unchanged.
- **Filter + group compose:** In **By role** mode, tap the *Amelia* filter chip — only the *Amelia* group shows; clear it — all role groups return.

## Decisions to confirm

- **D1 — Persist-on-toggle vs. Done button.** The inline picker could write each toggle immediately, or batch and write on a "Done"/dismiss. **Proposed default: write on each toggle (immediate), with dismiss simply closing.** Fewer steps, matches the direct-manipulation framing; safe because each write is a single row insert/delete.
- **D2 — Where the inline picker lives.** Inline-expanding under the row vs. a small modal/sheet anchored to the entry. **Proposed default: a compact modal sheet** (reuses the existing role-chip idiom, avoids reflowing the list). Open to inline expansion if it feels better on device.
- **D3 — "Untagged" group placement.** End of each day (proposed) vs. start. **Proposed default: end of day**, so tagged roles lead.

## How this serves the JTBD

- **Evidence stays editable.** A role is "evidence of investment"; letting you correct what counts as evidence — after the moment, when you have perspective — makes the role lens truer without turning the journal into a document you fuss over.
- **A second lens, no new capture.** Group-by-role reveals patterns the affirmation spine hides ("most of what I logged this week was about Amelia") using only data already captured. No new nagging, no new entry type.

## Cross-references

- Entry rows, grouping, delete flow, voice playback: [Affirmations & Gratitude Journal spec](2026-05-10-affirmations-journal-design.md).
- Role filter strip, entry→role resolution, auto-`emo` fallback: [Roles ↔ Journal linking spec](2026-05-30-roles-journal-linking-design.md).
- Deferred from this spec (issue #47): smaller tags (compactness pass) and better role icons.
