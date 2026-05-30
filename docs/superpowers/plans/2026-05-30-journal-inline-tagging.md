# Journal Inline Role Tagging + Group-by-Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user see/add/remove a Journal entry's role tags inline, and toggle the Journal's grouping between by-affirmation (current) and by-role.

**Architecture:** Keep all grouping/resolution logic as pure functions in `lib/` (tested with Jest, the codebase's pure-function-only test convention). DB writes reuse the existing sync-aware moment helpers (`insertMoment` + `syncMoments` for add; a new `removeRoleTagFromEntry` mirroring `deleteMomentsForEntry` for remove). `JournalScreen` gains a grouping toggle and per-entry role avatars that open a compact role-picker modal.

**Tech Stack:** React Native + TypeScript, expo-sqlite, Jest/ts-jest. Spec: `docs/superpowers/specs/2026-05-30-journal-tagging-polish-design.md`.

**Decisions locked (from spec):** D1 persist-on-each-toggle; D2 compact modal sheet for the picker; D3 "Untagged" group at end of day.

---

## File Structure

- `lib/roleMoments.ts` (modify) — add pure `rolesByEntry()` + DB `getRolesByEntry()`.
- `lib/journal.ts` (modify) — extract `groupByContextAffirmation()` helper; add `groupEntriesByRole()` + its types.
- `lib/cloudkit.ts` (modify) — add sync-aware `removeRoleTagFromEntry()`.
- `components/JournalEntryRoleEditor.tsx` (create) — compact modal role picker for one entry.
- `components/JournalScreen.tsx` (modify) — load entry→roles map, render avatars + editor, add grouping toggle, render by-role groups.
- `__tests__/roleMoments.test.ts` (modify) — tests for `rolesByEntry`.
- `__tests__/journal.test.ts` (modify) — tests for `groupEntriesByRole`.

---

## Task 1: Pure `rolesByEntry()` — map entries → role set

**Files:**
- Modify: `lib/roleMoments.ts` (add after `getEntryIdsForRole`, ~line 89)
- Test: `__tests__/roleMoments.test.ts`

- [ ] **Step 1: Write the failing tests**

Add to `__tests__/roleMoments.test.ts` (it already imports `journalEntryIdFromMoment`, `type RoleMoment` and has a `moment()` factory):

```typescript
import { rolesByEntry } from "../lib/roleMoments";

describe("rolesByEntry", () => {
  it("groups role ids under the entry id a moment resolves to", () => {
    const map = rolesByEntry([
      moment({ roleId: "amelia", source: "manual", sourceRef: "e1" }),
      moment({ roleId: "family", source: "manual", sourceRef: "e1" }),
      moment({ roleId: "tori", source: "manual", sourceRef: "e2" }),
    ]);
    expect(map.get("e1")).toEqual(new Set(["amelia", "family"]));
    expect(map.get("e2")).toEqual(new Set(["tori"]));
  });

  it("resolves the journal: prefix form (auto-emo) to the same entry id", () => {
    const map = rolesByEntry([
      moment({ roleId: "emo", source: "auto-journal", sourceRef: "journal:e1" }),
    ]);
    expect(map.get("e1")).toEqual(new Set(["emo"]));
  });

  it("ignores moments not backed by a journal entry", () => {
    const map = rolesByEntry([
      moment({ roleId: "fit", source: "auto-workout", sourceRef: "workout:123" }),
    ]);
    expect(map.size).toBe(0);
  });

  it("deduplicates a role linked to the same entry by two moments", () => {
    const map = rolesByEntry([
      moment({ roleId: "tori", source: "manual", sourceRef: "e1" }),
      moment({ roleId: "tori", source: "auto-journal", sourceRef: "journal:e1" }),
    ]);
    expect(map.get("e1")).toEqual(new Set(["tori"]));
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest roleMoments -t rolesByEntry`
Expected: FAIL — `rolesByEntry is not a function` / not exported.

- [ ] **Step 3: Implement `rolesByEntry`**

Add to `lib/roleMoments.ts` after `getEntryIdsForRole` (~line 89):

```typescript
/**
 * Map every journal-backed role moment to its entry id, grouping the role
 * ids that point at each entry. Pure — the DB read lives in
 * getRolesByEntry. Powers the Journal's per-row role avatars and the
 * group-by-role view. Moments not backed by a journal entry are skipped.
 */
export function rolesByEntry(
  moments: Pick<RoleMoment, "roleId" | "source" | "sourceRef">[],
): Map<string, Set<RoleId>> {
  const map = new Map<string, Set<RoleId>>();
  for (const m of moments) {
    const entryId = journalEntryIdFromMoment({
      id: "",
      roleId: m.roleId,
      timestamp: 0,
      what: "",
      tag: null,
      source: m.source,
      sourceRef: m.sourceRef,
    });
    if (!entryId) continue;
    let set = map.get(entryId);
    if (!set) {
      set = new Set<RoleId>();
      map.set(entryId, set);
    }
    set.add(m.roleId);
  }
  return map;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest roleMoments -t rolesByEntry`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/roleMoments.ts __tests__/roleMoments.test.ts
git commit -m "feat(journal): rolesByEntry — resolve entries to their role set"
```

---

## Task 2: DB `getRolesByEntry()` — load the map from SQLite

**Files:**
- Modify: `lib/roleMoments.ts` (add after `rolesByEntry`)

No unit test — this is a thin DB wrapper (codebase tests pure functions only; the pure core `rolesByEntry` is already covered).

- [ ] **Step 1: Implement `getRolesByEntry`**

Add to `lib/roleMoments.ts` right after `rolesByEntry`:

```typescript
/**
 * Load the entry-id → role-set map for every journal-backed moment.
 * Thin DB wrapper around rolesByEntry; tolerant callers should catch a
 * missing table the same way the rest of the journal reads do.
 */
export async function getRolesByEntry(
  db: SQLite.SQLiteDatabase,
): Promise<Map<string, Set<RoleId>>> {
  const rows = await db.getAllAsync<{
    role_id: RoleId;
    source: RoleMomentSource;
    source_ref: string | null;
  }>(`SELECT role_id, source, source_ref FROM role_moments`);
  return rolesByEntry(
    rows.map((r) => ({
      roleId: r.role_id,
      source: r.source,
      sourceRef: r.source_ref,
    })),
  );
}
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/roleMoments.ts
git commit -m "feat(journal): getRolesByEntry DB loader for inline role tags"
```

---

## Task 3: Extract `groupByContextAffirmation()` (refactor, no behavior change)

**Files:**
- Modify: `lib/journal.ts` (refactor `groupEntries`, ~lines 87-146)
- Test: `__tests__/journal.test.ts` (existing `groupEntries` tests must still pass)

- [ ] **Step 1: Confirm current tests pass first**

Run: `npx jest journal`
Expected: PASS (baseline before refactor).

- [ ] **Step 2: Extract the helper**

In `lib/journal.ts`, add this exported helper just above `groupEntries` (~line 86). It is the context→affirmation body lifted verbatim from the inner loop:

```typescript
/**
 * Group a single day's entries by context → affirmation, newest-first,
 * pruning empties. Shared by groupEntries (date → context → affirmation)
 * and groupEntriesByRole (date → role → context → affirmation).
 */
export function groupByContextAffirmation(
  entries: JournalEntry[],
): ContextGroup[] {
  const byContext = new Map<JournalContext, Map<string, JournalEntry[]>>();
  for (const entry of entries) {
    let contextMap = byContext.get(entry.context);
    if (!contextMap) {
      contextMap = new Map();
      byContext.set(entry.context, contextMap);
    }
    const affKey = entry.affirmationTitle;
    let bucket = contextMap.get(affKey);
    if (!bucket) {
      bucket = [];
      contextMap.set(affKey, bucket);
    }
    bucket.push(entry);
  }

  const contexts: ContextGroup[] = [];
  for (const ctx of JOURNAL_CONTEXTS) {
    const contextMap = byContext.get(ctx);
    if (!contextMap || contextMap.size === 0) continue;
    const affirmations: AffirmationGroup[] = [];
    const titles = [...contextMap.keys()].sort((a, b) => {
      const ai = ALL_AFFIRMATION_TITLES.indexOf(a);
      const bi = ALL_AFFIRMATION_TITLES.indexOf(b);
      if (ai === -1 && bi === -1) return a.localeCompare(b);
      if (ai === -1) return 1;
      if (bi === -1) return -1;
      return ai - bi;
    });
    for (const title of titles) {
      const bucket = contextMap.get(title)!;
      bucket.sort((a, b) => b.date - a.date);
      affirmations.push({ affirmationTitle: title, entries: bucket });
    }
    contexts.push({ context: ctx, affirmations });
  }
  return contexts;
}
```

- [ ] **Step 3: Rewrite `groupEntries` to use the helper**

Replace the body of `groupEntries` (keep its signature/return type) with:

```typescript
export function groupEntries(entries: JournalEntry[]): DayGroup[] {
  if (entries.length === 0) return [];

  const byDay = new Map<string, JournalEntry[]>();
  for (const entry of entries) {
    const day = dayKey(entry.date);
    let bucket = byDay.get(day);
    if (!bucket) {
      bucket = [];
      byDay.set(day, bucket);
    }
    bucket.push(entry);
  }

  const sortedDays = [...byDay.keys()].sort((a, b) => b.localeCompare(a));
  const days: DayGroup[] = [];
  for (const day of sortedDays) {
    const contexts = groupByContextAffirmation(byDay.get(day)!);
    days.push({ dayKey: day, contexts });
  }
  return days;
}
```

- [ ] **Step 4: Run tests to verify no regression**

Run: `npx jest journal`
Expected: PASS — all existing `groupEntries` tests still green.

- [ ] **Step 5: Commit**

```bash
git add lib/journal.ts
git commit -m "refactor(journal): extract groupByContextAffirmation from groupEntries"
```

---

## Task 4: Pure `groupEntriesByRole()` — date → role → context

**Files:**
- Modify: `lib/journal.ts` (add after `groupEntries`)
- Test: `__tests__/journal.test.ts`

- [ ] **Step 1: Write the failing tests**

Add to `__tests__/journal.test.ts`. (It already imports from `../lib/journal` and `createEntry`/`createGratitude` exist there; check the file's existing imports and extend them with `groupEntriesByRole`.)

```typescript
import { groupEntriesByRole } from "../lib/journal";
import type { RoleId } from "../lib/roles";

describe("groupEntriesByRole", () => {
  const ORDER: RoleId[] = ["amelia", "family", "tori"];

  function entry(id: string, date: number, ctx: "opportunity" | "didit" | "grateful" = "opportunity") {
    return createEntry({ id, date, context: ctx, affirmationTitle: "Do It Anyways", text: id });
  }

  it("puts an entry under each of its roles within the day", () => {
    const e = entry("e1", Date.UTC(2026, 4, 30, 12));
    const map = new Map<string, Set<RoleId>>([["e1", new Set(["amelia", "family"])]]);
    const days = groupEntriesByRole([e], map, ORDER);
    expect(days).toHaveLength(1);
    const roleIds = days[0].roles.map((r) => r.roleId);
    expect(roleIds).toEqual(["amelia", "family"]); // ORDER preserved, no untagged
  });

  it("collects untagged entries under a null-role group at the end of the day", () => {
    const e = entry("e1", Date.UTC(2026, 4, 30, 12));
    const map = new Map<string, Set<RoleId>>(); // no roles for e1
    const days = groupEntriesByRole([e], map, ORDER);
    expect(days[0].roles.map((r) => r.roleId)).toEqual([null]);
  });

  it("orders tagged roles by the supplied order, untagged last", () => {
    const tagged = entry("e1", Date.UTC(2026, 4, 30, 12));
    const untagged = entry("e2", Date.UTC(2026, 4, 30, 13));
    const map = new Map<string, Set<RoleId>>([["e1", new Set(["tori"])]]);
    const days = groupEntriesByRole([tagged, untagged], map, ORDER);
    expect(days[0].roles.map((r) => r.roleId)).toEqual(["tori", null]);
  });

  it("preserves date → newest-day-first across days", () => {
    const older = entry("e1", Date.UTC(2026, 4, 29, 12));
    const newer = entry("e2", Date.UTC(2026, 4, 30, 12));
    const map = new Map<string, Set<RoleId>>([
      ["e1", new Set(["amelia"])],
      ["e2", new Set(["amelia"])],
    ]);
    const days = groupEntriesByRole([older, newer], map, ORDER);
    expect(days.map((d) => d.dayKey)).toEqual(["2026-05-30", "2026-05-29"]);
  });

  it("keeps context → affirmation structure inside a role group", () => {
    const opp = entry("e1", Date.UTC(2026, 4, 30, 12), "opportunity");
    const grat = createGratitude({ id: "e2", date: Date.UTC(2026, 4, 30, 13), text: "thanks" });
    const map = new Map<string, Set<RoleId>>([
      ["e1", new Set(["amelia"])],
      ["e2", new Set(["amelia"])],
    ]);
    const days = groupEntriesByRole([opp, grat], map, ORDER);
    const amelia = days[0].roles.find((r) => r.roleId === "amelia")!;
    expect(amelia.contexts.map((c) => c.context)).toEqual(["opportunity", "grateful"]);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest journal -t groupEntriesByRole`
Expected: FAIL — `groupEntriesByRole is not a function`.

- [ ] **Step 3: Add the types and implementation**

In `lib/journal.ts`, add the types near the other group types (after `DayGroup`, ~line 81) — note `RoleId` import:

```typescript
import type { RoleId } from "./roles";
```

```typescript
/** A role bucket within a day. roleId === null is the "Untagged" group. */
export type RoleGroup = {
  roleId: RoleId | null;
  contexts: ContextGroup[];
};

export type RoleDayGroup = {
  dayKey: string;
  roles: RoleGroup[];
};
```

Then add after `groupEntries`:

```typescript
/**
 * Group entries by date → role → context → affirmation. An entry appears
 * under EACH role it's tied to (per entryRoles); entries with no role land
 * in a single null-role "Untagged" group at the end of each day. Roles are
 * ordered by roleOrder (the canonical ROLES order); untagged always last.
 * Newest day first, mirroring groupEntries.
 */
export function groupEntriesByRole(
  entries: JournalEntry[],
  entryRoles: Map<string, Set<RoleId>>,
  roleOrder: readonly RoleId[],
): RoleDayGroup[] {
  if (entries.length === 0) return [];

  // day -> roleKey -> entries.  roleKey is the RoleId, or "" for untagged.
  const byDay = new Map<string, Map<string, JournalEntry[]>>();
  for (const entry of entries) {
    const day = dayKey(entry.date);
    let dayMap = byDay.get(day);
    if (!dayMap) {
      dayMap = new Map();
      byDay.set(day, dayMap);
    }
    const roles = entryRoles.get(entry.id);
    const keys = roles && roles.size > 0 ? [...roles] : [""];
    for (const key of keys) {
      let bucket = dayMap.get(key);
      if (!bucket) {
        bucket = [];
        dayMap.set(key, bucket);
      }
      bucket.push(entry);
    }
  }

  const sortedDays = [...byDay.keys()].sort((a, b) => b.localeCompare(a));
  const days: RoleDayGroup[] = [];
  for (const day of sortedDays) {
    const dayMap = byDay.get(day)!;
    const roles: RoleGroup[] = [];
    for (const roleId of roleOrder) {
      const bucket = dayMap.get(roleId);
      if (!bucket || bucket.length === 0) continue;
      roles.push({ roleId, contexts: groupByContextAffirmation(bucket) });
    }
    const untagged = dayMap.get("");
    if (untagged && untagged.length > 0) {
      roles.push({ roleId: null, contexts: groupByContextAffirmation(untagged) });
    }
    days.push({ dayKey: day, roles });
  }
  return days;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest journal -t groupEntriesByRole`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/journal.ts __tests__/journal.test.ts
git commit -m "feat(journal): groupEntriesByRole — date -> role -> context grouping"
```

---

## Task 5: Sync-aware `removeRoleTagFromEntry()`

**Files:**
- Modify: `lib/cloudkit.ts` (add after `deleteMomentsForEntry`, ~line 648)

No unit test — the codebase does not test CloudKit/DB code (it mirrors the untested `deleteMomentsForEntry`). Verified manually in Task 7.

- [ ] **Step 1: Implement `removeRoleTagFromEntry`**

Add to `lib/cloudkit.ts` after `deleteMomentsForEntry`:

```typescript
/**
 * Remove a single role's link to a journal entry (both source_ref forms:
 * the raw entry id from card/inline tagging and `journal:<id>` from
 * auto-emo). Sync-aware via deleteMomentRecord so CloudKit tombstones too.
 * Used by the Journal's inline role editor when a role is toggled off.
 */
export async function removeRoleTagFromEntry(
  db: SQLite.SQLiteDatabase,
  entryId: string,
  roleId: RoleId,
): Promise<void> {
  const rows = await db.getAllAsync<{ id: string }>(
    `SELECT id FROM role_moments
      WHERE role_id = ? AND (source_ref = ? OR source_ref = ?)`,
    [roleId, entryId, `journal:${entryId}`],
  );
  for (const r of rows) {
    await deleteMomentRecord(db, r.id);
  }
}
```

- [ ] **Step 2: Ensure `RoleId` is imported in cloudkit.ts**

Check the top imports. `lib/cloudkit.ts` imports from `./roleMoments`; add `RoleId` to the `./roles` import (or the existing roleMoments import block). Confirm with:

Run: `grep -n "RoleId" lib/cloudkit.ts`
If absent, add `import type { RoleId } from "./roles";` near the other type imports.

- [ ] **Step 3: Type-check**

Run: `npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/cloudkit.ts
git commit -m "feat(journal): removeRoleTagFromEntry sync-aware single-role untag"
```

---

## Task 6: `JournalEntryRoleEditor` compact modal picker

**Files:**
- Create: `components/JournalEntryRoleEditor.tsx`

No unit test (RN component; codebase tests pure logic only). Verified in Task 7.

- [ ] **Step 1: Create the component**

`components/JournalEntryRoleEditor.tsx`:

```tsx
import React, { useEffect, useState } from "react";
import {
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import type { JournalEntry } from "../lib/journal";
import { momentMetaForEntry } from "../lib/journal";
import { ROLES, getRole, type RoleId } from "../lib/roles";
import { insertMoment } from "../lib/roleMoments";
import { removeRoleTagFromEntry, syncMoments } from "../lib/cloudkit";
import { RolePickerChips } from "./RolePickerChips";
import { CopyableError } from "./CopyableError";

type Props = {
  visible: boolean;
  entry: JournalEntry | null;
  /** Roles the entry is currently tied to. */
  currentRoles: ReadonlySet<RoleId>;
  db: SQLite.SQLiteDatabase | null;
  onClose: () => void;
  /** Called after any persisted change so the parent can refresh. */
  onChanged: () => void;
};

/**
 * Compact modal to add/remove an existing entry's role tags (D1: each
 * toggle persists immediately; D2: modal sheet). Direct-manipulation:
 * the picker reflects exactly the entry's current role links and toggles
 * that set — adding never strips the auto-emo link, removing all leaves
 * the entry untagged.
 */
export function JournalEntryRoleEditor({
  visible,
  entry,
  currentRoles,
  db,
  onClose,
  onChanged,
}: Props) {
  const [selected, setSelected] = useState<Set<RoleId>>(new Set(currentRoles));
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (visible) {
      setSelected(new Set(currentRoles));
      setError(null);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, entry?.id]);

  async function toggle(roleId: RoleId) {
    if (!db || !entry) return;
    const isOn = selected.has(roleId);
    // Optimistic UI; revert on failure.
    setSelected((prev) => {
      const next = new Set(prev);
      if (isOn) next.delete(roleId);
      else next.add(roleId);
      return next;
    });
    try {
      if (isOn) {
        await removeRoleTagFromEntry(db, entry.id, roleId);
      } else {
        const meta = momentMetaForEntry(entry);
        await insertMoment(db, {
          roleId,
          timestamp: entry.date,
          what: meta.what,
          tag: meta.tag,
          source: "manual",
          sourceRef: entry.id,
        });
      }
      void syncMoments(db);
      onChanged();
    } catch (e: any) {
      setError(e?.message ?? String(e));
      // Revert optimistic toggle.
      setSelected((prev) => {
        const next = new Set(prev);
        if (isOn) next.add(roleId);
        else next.delete(roleId);
        return next;
      });
    }
  }

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />
        <View style={styles.sheet}>
          <View style={styles.handle} />
          <View style={styles.header}>
            <Text style={styles.heading}>Tag roles</Text>
            <TouchableOpacity onPress={onClose} testID="entry-roles-done">
              <Text style={styles.done}>Done</Text>
            </TouchableOpacity>
          </View>
          {entry?.text ? (
            <Text style={styles.preview} numberOfLines={2}>
              {entry.text}
            </Text>
          ) : entry ? (
            <Text style={styles.preview}>{getRole(ROLES[0].id) ? "" : ""}voice entry</Text>
          ) : null}
          <RolePickerChips
            selected={selected}
            onToggle={toggle}
            heading={null}
            testIDPrefix="entry-role"
          />
          {error && (
            <CopyableError
              message={error}
              context="JournalEntryRoleEditor.toggle"
              extra={{ entryId: entry?.id ?? "none" }}
              style={{ marginTop: 10 }}
            />
          )}
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.6)",
    justifyContent: "flex-end",
  },
  sheet: {
    backgroundColor: "#111828",
    borderTopLeftRadius: 18,
    borderTopRightRadius: 18,
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 32,
  },
  handle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: "#444",
    alignSelf: "center",
    marginBottom: 8,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 4,
  },
  heading: { color: "#e0e0e0", fontSize: 18, fontWeight: "700" },
  done: { color: "#4a9eff", fontSize: 16, fontWeight: "600" },
  preview: { color: "#9aa3b2", fontSize: 13, marginBottom: 4 },
});
```

> Note: the voice-entry preview line above is awkward — simplify Step 1b.

- [ ] **Step 1b: Fix the voice-entry preview line**

Replace the `entry?.text ? ... : entry ? ... : null` block with a clean version:

```tsx
          {entry && (
            <Text style={styles.preview} numberOfLines={2}>
              {entry.text || "voice entry"}
            </Text>
          )}
```

And remove the now-unused `getRole`/`ROLES` from the import if not otherwise used (keep `RoleId`). Final import line:

```tsx
import { type RoleId } from "../lib/roles";
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add components/JournalEntryRoleEditor.tsx
git commit -m "feat(journal): JournalEntryRoleEditor compact inline role picker"
```

---

## Task 7: Wire avatars + editor + grouping toggle into `JournalScreen`

**Files:**
- Modify: `components/JournalScreen.tsx`

No unit test (RN screen). Manual verification steps at the end.

- [ ] **Step 1: Add imports**

At the top of `components/JournalScreen.tsx`, extend imports:

```tsx
import {
  type AudioRecording,
  type JournalContext,
  type JournalEntry,
  type RoleDayGroup,
  CONTEXT_LABEL,
  groupEntries,
  groupEntriesByRole,
} from "../lib/journal";
import { getEntryIdsForRole, getRolesByEntry } from "../lib/roleMoments";
import { ROLES, getRole, type RoleId } from "../lib/roles";
```

Add the editor import next to the other component imports:

```tsx
import { JournalEntryRoleEditor } from "./JournalEntryRoleEditor";
```

Add a module-level constant for the canonical role order (after imports):

```tsx
const ROLE_ORDER: RoleId[] = ROLES.map((r) => r.id);
```

- [ ] **Step 2: Add state for the entry→roles map, grouping mode, and the editor target**

Inside `JournalScreen`, after the existing `useState` declarations (~line 43):

```tsx
  const [rolesByEntryMap, setRolesByEntryMap] = useState<Map<string, Set<RoleId>>>(
    new Map(),
  );
  const [groupMode, setGroupMode] = useState<"affirmation" | "role">("affirmation");
  const [editing, setEditing] = useState<JournalEntry | null>(null);
```

- [ ] **Step 3: Load the entry→roles map in `load()`**

In `load()`, after `setAudioById(map);` and before the `catch`, add:

```tsx
      try {
        setRolesByEntryMap(await getRolesByEntry(db));
      } catch {
        setRolesByEntryMap(new Map()); // tolerate missing table
      }
```

- [ ] **Step 4: Build the role-grouped view and the filtered role groups**

After the existing `const groups = useMemo(...)` (~line 78), add:

```tsx
  const roleDays = useMemo(
    () => groupEntriesByRole(filteredEntries, rolesByEntryMap, ROLE_ORDER),
    [filteredEntries, rolesByEntryMap],
  );
  // In role mode, an active filter narrows to just that role's group
  // (drop untagged + other roles that multi-tagged entries also belong to).
  const visibleRoleDays = useMemo<RoleDayGroup[]>(() => {
    if (filterRole == null) return roleDays;
    return roleDays
      .map((d) => ({
        dayKey: d.dayKey,
        roles: d.roles.filter((r) => r.roleId === filterRole),
      }))
      .filter((d) => d.roles.length > 0);
  }, [roleDays, filterRole]);
```

- [ ] **Step 5: Add the grouping toggle UI above the filter strip**

Just above the `<ScrollView ... style={styles.filterStrip}>` block (~line 155), insert:

```tsx
        <View style={styles.groupToggleRow}>
          <GroupToggleButton
            label="By affirmation"
            active={groupMode === "affirmation"}
            onPress={() => setGroupMode("affirmation")}
          />
          <GroupToggleButton
            label="By role"
            active={groupMode === "role"}
            onPress={() => setGroupMode("role")}
          />
        </View>
```

- [ ] **Step 6: Render the chosen grouping**

Replace the body that renders `groups` (the `groups.length === 0 ? ... : groups.map(...)` block, ~lines 197-248) with a switch on `groupMode`. Keep the existing affirmation rendering as-is; add the role rendering. The simplest structure:

```tsx
          {groupMode === "affirmation" ? (
            groups.length === 0 ? (
              renderEmpty()
            ) : (
              groups.map((day) => renderAffirmationDay(day))
            )
          ) : visibleRoleDays.length === 0 ? (
            renderEmpty()
          ) : (
            visibleRoleDays.map((day) => (
              <View key={day.dayKey} style={styles.dayBlock}>
                <TouchableOpacity onPress={() => toggleDay(day.dayKey)}>
                  <Text style={styles.dayHeader}>
                    {collapsedDays[day.dayKey] ? "▸" : "▾"} {formatDayHeader(day.dayKey)}
                  </Text>
                </TouchableOpacity>
                {!collapsedDays[day.dayKey] &&
                  day.roles.map((roleGroup) => (
                    <View
                      key={roleGroup.roleId ?? "untagged"}
                      style={styles.contextBlock}
                    >
                      <View style={styles.roleGroupHeader}>
                        {roleGroup.roleId && (
                          <RoleAvatar
                            roleId={roleGroup.roleId}
                            size={18}
                            ringColor={getRole(roleGroup.roleId).color}
                          />
                        )}
                        <Text style={styles.roleGroupHeaderText}>
                          {roleGroup.roleId
                            ? getRole(roleGroup.roleId).name
                            : "Untagged"}
                        </Text>
                      </View>
                      {roleGroup.contexts.map((ctx) => (
                        <View key={ctx.context} style={styles.contextBlock}>
                          <Text style={styles.contextHeader}>
                            {CONTEXT_LABEL[ctx.context as JournalContext]}
                          </Text>
                          {ctx.affirmations.map((a) => (
                            <View key={a.affirmationTitle} style={styles.affirmationBlock}>
                              <Text style={styles.affirmationHeader}>
                                {a.affirmationTitle}
                              </Text>
                              {a.entries.map((entry) => (
                                <EntryRow
                                  key={entry.id}
                                  entry={entry}
                                  audio={
                                    entry.audioRecordingId
                                      ? audioById[entry.audioRecordingId]
                                      : undefined
                                  }
                                  db={db}
                                  roles={rolesByEntryMap.get(entry.id) ?? null}
                                  onEditRoles={() => setEditing(entry)}
                                  onDelete={() => handleDelete(entry)}
                                />
                              ))}
                            </View>
                          ))}
                        </View>
                      ))}
                    </View>
                  ))}
              </View>
            ))
          )}
```

To support this, extract the existing affirmation-day JSX and empty-state JSX into two local helpers **inside the component** so both modes share them. Define above the `return`:

```tsx
  function renderEmpty() {
    return (
      <View style={styles.emptyBlock}>
        <Text style={styles.emptyTitle}>
          {filterRole != null ? "No entries for this role yet" : "No entries yet"}
        </Text>
        <Text style={styles.emptyHint}>
          {filterRole != null
            ? "Tag an affirmation or gratitude with this role, or write one from the role's detail sheet."
            : "Use Affirmation or Grateful from the dashboard to log thoughts. Pull down here to sync from CloudKit."}
        </Text>
      </View>
    );
  }

  function renderAffirmationDay(day: (typeof groups)[number]) {
    return (
      <View key={day.dayKey} style={styles.dayBlock}>
        <TouchableOpacity onPress={() => toggleDay(day.dayKey)}>
          <Text style={styles.dayHeader}>
            {collapsedDays[day.dayKey] ? "▸" : "▾"} {formatDayHeader(day.dayKey)}
          </Text>
        </TouchableOpacity>
        {!collapsedDays[day.dayKey] &&
          day.contexts.map((ctx) => (
            <View key={ctx.context} style={styles.contextBlock}>
              <Text style={styles.contextHeader}>
                {CONTEXT_LABEL[ctx.context as JournalContext]}
              </Text>
              {ctx.affirmations.map((a) => (
                <View key={a.affirmationTitle} style={styles.affirmationBlock}>
                  <Text style={styles.affirmationHeader}>{a.affirmationTitle}</Text>
                  {a.entries.map((entry) => (
                    <EntryRow
                      key={entry.id}
                      entry={entry}
                      audio={
                        entry.audioRecordingId
                          ? audioById[entry.audioRecordingId]
                          : undefined
                      }
                      db={db}
                      roles={rolesByEntryMap.get(entry.id) ?? null}
                      onEditRoles={() => setEditing(entry)}
                      onDelete={() => handleDelete(entry)}
                    />
                  ))}
                </View>
              ))}
            </View>
          ))}
      </View>
    );
  }
```

- [ ] **Step 7: Extend `EntryRow` to render role avatars + an edit affordance**

Replace the `EntryRow` function signature and body to accept `roles` and `onEditRoles`, and render a small avatar row beneath the time:

```tsx
function EntryRow({
  entry,
  audio,
  db,
  roles,
  onEditRoles,
  onDelete,
}: {
  entry: JournalEntry;
  audio: AudioRecording | undefined;
  db: SQLite.SQLiteDatabase | null;
  roles: ReadonlySet<RoleId> | null;
  onEditRoles: () => void;
  onDelete: () => void;
}) {
  const time = new Date(entry.date).toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
  const roleIds = roles ? ROLE_ORDER.filter((id) => roles.has(id)) : [];
  return (
    <View style={styles.entryRow}>
      <View style={{ flex: 1 }}>
        {entry.text ? <Text style={styles.entryText}>{entry.text}</Text> : null}
        {entry.audioRecordingId && audio && (
          <View style={{ marginTop: entry.text ? 8 : 0 }}>
            <AudioPlayer
              recordingId={entry.audioRecordingId}
              durationMs={audio.durationMs}
              db={db}
            />
          </View>
        )}
        {entry.audioRecordingId && !audio && (
          <Text style={styles.entryMissing}>voice note (metadata pending sync)</Text>
        )}
        <View style={styles.entryFooter}>
          <Text style={styles.entryTime}>{time}</Text>
          <TouchableOpacity
            onPress={onEditRoles}
            style={styles.roleTagBtn}
            testID={`entry-roles-${entry.id}`}
            accessibilityLabel="Edit role tags"
          >
            {roleIds.map((id) => (
              <RoleAvatar key={id} roleId={id} size={16} ringColor={getRole(id).color} />
            ))}
            <Text style={styles.roleTagPlus}>{roleIds.length === 0 ? "+ tag" : "＋"}</Text>
          </TouchableOpacity>
        </View>
      </View>
      <TouchableOpacity onPress={onDelete} style={styles.deleteBtn}>
        <Text style={styles.deleteBtnText}>×</Text>
      </TouchableOpacity>
    </View>
  );
}
```

- [ ] **Step 8: Add the `GroupToggleButton` component and new styles**

Add `GroupToggleButton` near `FilterChip`:

```tsx
function GroupToggleButton({
  label,
  active,
  onPress,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity
      onPress={onPress}
      style={[styles.groupToggleBtn, active && styles.groupToggleBtnActive]}
      testID={`journal-group-${label.includes("role") ? "role" : "affirmation"}`}
      accessibilityState={{ selected: active }}
    >
      <Text style={[styles.groupToggleText, active && styles.groupToggleTextActive]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}
```

Add these keys to the `styles` object:

```tsx
  groupToggleRow: {
    flexDirection: "row" as const,
    gap: 8,
    paddingHorizontal: 16,
    paddingTop: 10,
  },
  groupToggleBtn: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#2a2a3a",
    backgroundColor: "#111",
  },
  groupToggleBtnActive: {
    borderColor: "#4a9eff",
    backgroundColor: "#13243a",
  },
  groupToggleText: { color: "#aaa", fontSize: 13 },
  groupToggleTextActive: { color: "#4a9eff", fontWeight: "700" as const },
  roleGroupHeader: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    gap: 6,
    marginTop: 8,
  },
  roleGroupHeaderText: {
    color: "#cdd3df",
    fontSize: 14,
    fontWeight: "700" as const,
  },
  entryFooter: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    justifyContent: "space-between" as const,
    marginTop: 4,
  },
  roleTagBtn: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    gap: 3,
    paddingVertical: 2,
    paddingHorizontal: 4,
  },
  roleTagPlus: { color: "#6f7891", fontSize: 12, marginLeft: 2 },
```

- [ ] **Step 9: Render the editor modal**

Just before the closing `</View>` that wraps the screen (after the `</ScrollView>`, before `</View></Modal>`), add:

```tsx
        <JournalEntryRoleEditor
          visible={editing != null}
          entry={editing}
          currentRoles={
            editing ? rolesByEntryMap.get(editing.id) ?? new Set() : new Set()
          }
          db={db}
          onClose={() => setEditing(null)}
          onChanged={() => void load()}
        />
```

- [ ] **Step 10: Type-check and run all tests**

Run: `npx tsc --noEmit && npx jest`
Expected: no TS errors; all tests pass.

- [ ] **Step 11: Commit**

```bash
git add components/JournalScreen.tsx
git commit -m "feat(journal): inline role avatars + editor + group-by-role toggle (#47)"
```

- [ ] **Step 12: Manual verification on device/simulator**

Walk the spec's acceptance criteria:
1. Affirmation tagged Amelia+Family → row shows both avatars.
2. Untagged gratitude → row shows the emo avatar.
3. Tap avatars/`+ tag` → editor opens → add Tori → Done → row shows Tori; Tori filter includes it; survives restart.
4. Remove Tori → gone from row + filter.
5. Remove all roles → no avatars; not under any filter incl. emo.
6. Toggle **By role** → date → role → context; Amelia+Family entry under both; stripped entry under **Untagged**.
7. Toggle back **By affirmation** → original view.
8. By-role + tap Amelia filter → only Amelia group; clear → all groups.

---

## Self-Review Notes

- **Spec coverage:** §1 see roles → Task 1/2 (resolution) + Task 7 Step 7 (avatars). §2 add/remove inline → Task 5/6 + Task 7 Step 9. §3 group toggle → Task 3/4 + Task 7 Steps 4-6, 8. Direct-manipulation nuance → encoded in Task 6 (add reuses insertMoment with sourceRef=entry.id, never strips emo; remove deletes only the toggled role). Untagged-at-end (D3) → Task 4. Persist-on-toggle (D1) → Task 6. Modal sheet (D2) → Task 6.
- **Filter + group compose:** Task 7 Step 4 `visibleRoleDays`.
- **Tolerant reads:** Task 2 note + Task 7 Step 3 catch.
- **Type consistency:** `RoleDayGroup`/`RoleGroup` defined in Task 4, consumed in Task 7. `rolesByEntry`/`getRolesByEntry` Tasks 1-2. `removeRoleTagFromEntry` Task 5 → used Task 6. `groupByContextAffirmation` Task 3 → used Task 4.
- **Deferred (not in plan):** smaller tags, better icons — per spec non-goals.
```
