import {
  createEntry,
  createGratitude,
  dayKey,
  groupEntries,
  groupEntriesByRole,
  isJournalContext,
  isKnownAffirmationTitle,
  momentMetaForEntry,
  tallyByContext,
  type JournalEntry,
} from "../lib/journal";
import type { RoleId } from "../lib/roles";
import {
  AFFIRMATIONS,
  GRATEFUL_BUCKET,
  getRandomAffirmationIndex,
} from "../lib/affirmations";
import {
  buildJournalExport,
  parseJournalExport,
  JOURNAL_EXPORT_VERSION,
} from "../lib/journalExport";

// Fixed clock — every test that builds an entry passes its own date so
// snapshots stay deterministic.
const D1 = Date.UTC(2026, 4, 10, 12, 0, 0); // 2026-05-10 noon UTC
const D2 = Date.UTC(2026, 4, 9, 18, 0, 0);  // 2026-05-09 evening UTC

describe("affirmations module", () => {
  it("ships exactly the four canonical Humane Tracker affirmations", () => {
    expect(AFFIRMATIONS.map((a) => a.title)).toEqual([
      "Do It Anyways",
      "An Essentialist",
      "A Class Act",
      "Calm Like Water",
    ]);
  });

  it("Grateful is the dedicated bucket name, not an affirmation", () => {
    expect(GRATEFUL_BUCKET).toBe("Grateful");
    expect(AFFIRMATIONS.find((a) => a.title === "Grateful")).toBeUndefined();
  });

  it("getRandomAffirmationIndex never repeats currentIndex", () => {
    for (let i = 0; i < 50; i++) {
      const next = getRandomAffirmationIndex(2);
      expect(next).not.toBe(2);
      expect(next).toBeGreaterThanOrEqual(0);
      expect(next).toBeLessThan(AFFIRMATIONS.length);
    }
  });

  it("getRandomAffirmationIndex with no current can pick any index", () => {
    const seen = new Set<number>();
    for (let i = 0; i < 200; i++) seen.add(getRandomAffirmationIndex());
    // With 4 options and 200 trials, we should see all of them.
    expect(seen.size).toBe(AFFIRMATIONS.length);
  });
});

describe("journal types + guards", () => {
  it("isJournalContext narrows correctly", () => {
    expect(isJournalContext("opportunity")).toBe(true);
    expect(isJournalContext("didit")).toBe(true);
    expect(isJournalContext("grateful")).toBe(true);
    expect(isJournalContext("opportunities")).toBe(false);
    expect(isJournalContext(null)).toBe(false);
    expect(isJournalContext(undefined)).toBe(false);
  });

  it("isKnownAffirmationTitle accepts canonical four + Grateful", () => {
    expect(isKnownAffirmationTitle("Do It Anyways")).toBe(true);
    expect(isKnownAffirmationTitle("Grateful")).toBe(true);
    expect(isKnownAffirmationTitle("My Custom One")).toBe(false);
  });
});

describe("dayKey", () => {
  it("returns local-time YYYY-MM-DD for a known timestamp", () => {
    // Use a Date relative to local TZ to avoid TZ flakiness.
    const local = new Date(2026, 4, 10, 9, 30, 0); // local
    expect(dayKey(local.getTime())).toBe("2026-05-10");
  });

  it("buckets pre-midnight and post-midnight to different days", () => {
    const beforeMidnight = new Date(2026, 4, 10, 23, 59, 0).getTime();
    const afterMidnight = new Date(2026, 4, 11, 0, 1, 0).getTime();
    expect(dayKey(beforeMidnight)).toBe("2026-05-10");
    expect(dayKey(afterMidnight)).toBe("2026-05-11");
  });
});

describe("createEntry / createGratitude", () => {
  it("createEntry fills sensible defaults", () => {
    const e = createEntry({
      id: "e1",
      date: D1,
      context: "opportunity",
      affirmationTitle: "Do It Anyways",
    });
    expect(e.text).toBe("");
    expect(e.audioRecordingId).toBeNull();
    expect(e.createdAt).toBe(D1);
  });

  it("createGratitude always uses Grateful bucket + grateful context", () => {
    const e = createGratitude({ id: "g1", date: D1, text: "morning sun" });
    expect(e.context).toBe("grateful");
    expect(e.affirmationTitle).toBe(GRATEFUL_BUCKET);
    expect(e.text).toBe("morning sun");
  });
});

describe("momentMetaForEntry", () => {
  it("uses the affirmation title + context for an affirmation entry", () => {
    const e = createEntry({
      id: "e1",
      date: D1,
      context: "opportunity",
      affirmationTitle: "Do It Anyways",
      text: "plan a date night",
    });
    expect(momentMetaForEntry(e)).toEqual({
      what: "Do It Anyways",
      tag: "opportunity",
    });
  });

  it("uses the affirmation title even when the entry is voice-only", () => {
    const e = createEntry({
      id: "e2",
      date: D1,
      context: "didit",
      affirmationTitle: "An Essentialist",
      text: "",
      audioRecordingId: "a1",
    });
    expect(momentMetaForEntry(e)).toEqual({
      what: "An Essentialist",
      tag: "didit",
    });
  });

  it("uses the gratitude text for a grateful entry", () => {
    const e = createGratitude({ id: "g1", date: D1, text: "morning sun" });
    expect(momentMetaForEntry(e)).toEqual({
      what: "morning sun",
      tag: "grateful",
    });
  });

  it("falls back to 'Grateful' for a voice-only gratitude", () => {
    const e = createGratitude({ id: "g2", date: D1, audioRecordingId: "a2" });
    expect(momentMetaForEntry(e)).toEqual({
      what: "Grateful",
      tag: "grateful",
    });
  });
});

describe("groupEntries", () => {
  function entry(over: Partial<JournalEntry>): JournalEntry {
    return createEntry({
      id: over.id ?? "x",
      date: over.date ?? D1,
      context: over.context ?? "opportunity",
      affirmationTitle: over.affirmationTitle ?? "Do It Anyways",
      text: over.text ?? "",
      audioRecordingId: over.audioRecordingId ?? null,
    });
  }

  it("returns empty array for no entries", () => {
    expect(groupEntries([])).toEqual([]);
  });

  it("groups by date desc, then context order, then affirmation", () => {
    const groups = groupEntries([
      entry({ id: "a", date: D2, context: "didit", affirmationTitle: "A Class Act" }),
      entry({ id: "b", date: D1, context: "opportunity", affirmationTitle: "Do It Anyways" }),
      entry({ id: "c", date: D1, context: "grateful", affirmationTitle: "Grateful" }),
      entry({ id: "d", date: D1, context: "opportunity", affirmationTitle: "An Essentialist" }),
    ]);
    expect(groups.map((g) => g.dayKey)).toEqual(["2026-05-10", "2026-05-09"]);
    const today = groups[0];
    // Opportunities come before Gratitudes; Did Its absent on this day.
    expect(today.contexts.map((c) => c.context)).toEqual(["opportunity", "grateful"]);
    // Within Opportunities: Do It Anyways before An Essentialist (canonical
    // list order, not alphabetical).
    expect(today.contexts[0].affirmations.map((a) => a.affirmationTitle)).toEqual([
      "Do It Anyways",
      "An Essentialist",
    ]);
  });

  it("orders entries within an affirmation newest-first", () => {
    const groups = groupEntries([
      entry({ id: "older", date: D1, text: "first" }),
      entry({ id: "newer", date: D1 + 60_000, text: "second" }),
    ]);
    const leaf = groups[0].contexts[0].affirmations[0].entries;
    expect(leaf.map((e) => e.id)).toEqual(["newer", "older"]);
  });

  it("sorts unknown affirmation titles alphabetically after known ones", () => {
    const groups = groupEntries([
      entry({ id: "x", affirmationTitle: "Zebra Affirmation" }),
      entry({ id: "y", affirmationTitle: "Aardvark Affirmation" }),
      entry({ id: "z", affirmationTitle: "Do It Anyways" }),
    ]);
    expect(
      groups[0].contexts[0].affirmations.map((a) => a.affirmationTitle),
    ).toEqual(["Do It Anyways", "Aardvark Affirmation", "Zebra Affirmation"]);
  });
});

describe("tallyByContext", () => {
  it("counts only entries on the target day", () => {
    const today = dayKey(D1);
    const tally = tallyByContext(
      [
        createEntry({ id: "1", date: D1, context: "opportunity", affirmationTitle: "Do It Anyways" }),
        createEntry({ id: "2", date: D1, context: "opportunity", affirmationTitle: "An Essentialist" }),
        createEntry({ id: "3", date: D1, context: "didit", affirmationTitle: "A Class Act" }),
        createEntry({ id: "4", date: D2, context: "grateful", affirmationTitle: "Grateful" }),
      ],
      today,
    );
    expect(tally).toEqual({ opportunity: 2, didit: 1, grateful: 0 });
  });
});

describe("journalExport round-trip", () => {
  it("buildJournalExport then parseJournalExport recovers all entries", () => {
    const entries: JournalEntry[] = [
      createEntry({
        id: "e1",
        date: D1,
        context: "opportunity",
        affirmationTitle: "Do It Anyways",
        text: "stay calm in the meeting",
      }),
      createGratitude({ id: "g1", date: D2, text: "sunny morning" }),
    ];
    const audio = [
      { id: "a1", filePath: "voice/a1.m4a", durationMs: 12345, createdAt: D1 },
    ];
    const exported = buildJournalExport(entries, audio, new Date(D1));
    expect(exported.version).toBe(JOURNAL_EXPORT_VERSION);
    expect(exported.app).toBe("context-grabber");
    expect(exported.entries).toHaveLength(2);
    expect(exported.audioRecordings).toHaveLength(1);

    const json = JSON.stringify(exported);
    const parsed = parseJournalExport(JSON.parse(json));
    expect(parsed.entries).toHaveLength(2);
    expect(parsed.entries[0].id).toBe("e1");
    expect(parsed.entries[0].text).toBe("stay calm in the meeting");
    expect(parsed.entries[1].context).toBe("grateful");
    expect(parsed.entries[1].affirmationTitle).toBe("Grateful");
    expect(parsed.audioRecordings[0].durationMs).toBe(12345);
  });

  it("parseJournalExport rejects malformed entries with a clear error", () => {
    expect(() => parseJournalExport(null)).toThrow(/object/);
    expect(() => parseJournalExport({ entries: "no" })).toThrow(/array/);
    expect(() =>
      parseJournalExport({
        entries: [{ id: "x", date: "bad", context: "opportunity", affirmationTitle: "x" }],
      }),
    ).toThrow(/date/);
    expect(() =>
      parseJournalExport({
        entries: [{ id: "x", date: D1, context: "weird", affirmationTitle: "x" }],
      }),
    ).toThrow(/unknown/);
  });

  it("parseJournalExport tolerates missing audioRecordings array", () => {
    const result = parseJournalExport({ entries: [] });
    expect(result.audioRecordings).toEqual([]);
  });
});

describe("groupEntriesByRole", () => {
  const ORDER: RoleId[] = ["amelia", "family", "tori"];

  function entry(
    id: string,
    date: number,
    ctx: "opportunity" | "didit" | "grateful" = "opportunity",
  ) {
    return createEntry({
      id,
      date,
      context: ctx,
      affirmationTitle: "Do It Anyways",
      text: id,
    });
  }

  it("puts an entry under each of its roles within the day", () => {
    const e = entry("e1", Date.UTC(2026, 4, 30, 12));
    const map = new Map<string, Set<RoleId>>([
      ["e1", new Set(["amelia", "family"])],
    ]);
    const days = groupEntriesByRole([e], map, ORDER);
    expect(days).toHaveLength(1);
    expect(days[0].roles.map((r) => r.roleId)).toEqual(["amelia", "family"]);
  });

  it("collects untagged entries under a null-role group at the end of the day", () => {
    const e = entry("e1", Date.UTC(2026, 4, 30, 12));
    const map = new Map<string, Set<RoleId>>();
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
    const grat = createGratitude({
      id: "e2",
      date: Date.UTC(2026, 4, 30, 13),
      text: "thanks",
    });
    const map = new Map<string, Set<RoleId>>([
      ["e1", new Set(["amelia"])],
      ["e2", new Set(["amelia"])],
    ]);
    const days = groupEntriesByRole([opp, grat], map, ORDER);
    const amelia = days[0].roles.find((r) => r.roleId === "amelia")!;
    expect(amelia.contexts.map((c) => c.context)).toEqual([
      "opportunity",
      "grateful",
    ]);
  });
});
