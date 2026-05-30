/**
 * Tests for lib/roleMoments.ts pure helpers — specifically the source_ref
 * normalizer that maps a moment back to its journal entry id (or null).
 */

import {
  journalEntryIdFromMoment,
  rolesByEntry,
  type RoleMoment,
} from "../lib/roleMoments";

function moment(partial: Partial<RoleMoment>): RoleMoment {
  return {
    id: "m1",
    roleId: "tori",
    timestamp: 0,
    what: "",
    tag: null,
    source: "manual",
    sourceRef: null,
    ...partial,
  };
}

describe("journalEntryIdFromMoment", () => {
  it("returns the raw entry id for a card-tagged manual moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "manual", sourceRef: "entry-abc" }),
      ),
    ).toBe("entry-abc");
  });

  it("strips the journal: prefix from an auto-journal moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-journal", sourceRef: "journal:entry-xyz" }),
      ),
    ).toBe("entry-xyz");
  });

  it("strips the journal: prefix from an auto-grateful moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-grateful", sourceRef: "journal:g-1" }),
      ),
    ).toBe("g-1");
  });

  it("returns null for a workout moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-workout", sourceRef: "workout:12345" }),
      ),
    ).toBeNull();
  });

  it("returns null for a mindful moment", () => {
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-mindful", sourceRef: "mindful:2026-05-30T10:00:00Z" }),
      ),
    ).toBeNull();
  });

  it("returns null for a free-form manual tag with no source_ref", () => {
    expect(
      journalEntryIdFromMoment(moment({ source: "manual", sourceRef: null })),
    ).toBeNull();
  });

  it("returns null when an auto-detected source carries a bare ref", () => {
    // Defensive: auto sources should never resolve to a journal entry even
    // if their ref lacks a recognizable prefix.
    expect(
      journalEntryIdFromMoment(
        moment({ source: "auto-workout", sourceRef: "somethingweird" }),
      ),
    ).toBeNull();
  });
});

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
