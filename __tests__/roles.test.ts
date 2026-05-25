/**
 * Tests for lib/roles.ts: role definitions + computeWeekActivity.
 */

import {
  ROLES,
  getRole,
  computeWeekActivity,
  type WeeklyCacheLike,
} from "../lib/roles";
import type { RoleMoment } from "../lib/roleMoments";

describe("ROLES constant", () => {
  it("declares all 11 eulogy roles in order", () => {
    const ids = ROLES.map((r) => r.id);
    expect(ids).toEqual([
      "smiles",
      "carfree",
      "habits",
      "fit",
      "emo",
      "tech",
      "pro",
      "family",
      "tori",
      "amelia",
      "zach",
    ]);
  });

  it("each role has a non-empty name + color + passage + markers", () => {
    for (const r of ROLES) {
      expect(r.name.length).toBeGreaterThan(0);
      expect(r.color).toMatch(/^#[0-9a-f]{6}$/i);
      expect(r.eulogyPassage.length).toBeGreaterThan(0);
      expect(r.eulogyMarkers.length).toBeGreaterThanOrEqual(1);
      expect(r.attentionThresholdDays).toBeGreaterThanOrEqual(0);
    }
  });
});

describe("getRole", () => {
  it("returns the role def for a known id", () => {
    expect(getRole("fit").name).toBe("Fit fellow");
  });

  it("throws on an unknown id", () => {
    expect(() => getRole("unknown" as any)).toThrow(/Unknown role id/);
  });
});

const NOW = new Date(2026, 4, 25); // May 25, 2026

function emptyCtx(): WeeklyCacheLike {
  return {};
}

describe("computeWeekActivity", () => {
  it("returns empty signal when nothing contributes", () => {
    const out = computeWeekActivity("fit", {
      health: emptyCtx(),
      moments: [],
      now: NOW,
    });
    expect(out.roleId).toBe("fit");
    expect(out.score).toBe(0);
    expect(out.bars).toEqual([0, 0, 0, 0, 0, 0, 0]);
    expect(out.lastShownIso).toBeNull();
    expect(out.daysSinceLastShown).toBeNull();
  });

  it("flags attention when nothing happened this week for a role with a threshold", () => {
    const out = computeWeekActivity("tori", {
      health: emptyCtx(),
      moments: [],
      now: NOW,
    });
    expect(out.attention.flagged).toBe(true);
  });

  it("does not flag attention when a recent moment exists", () => {
    const yesterday = new Date(NOW);
    yesterday.setDate(yesterday.getDate() - 1);
    const moments: RoleMoment[] = [
      {
        id: "m1",
        roleId: "tori",
        timestamp: yesterday.getTime(),
        what: "date night",
        tag: null,
        source: "manual",
        sourceRef: null,
      },
    ];
    const out = computeWeekActivity("tori", {
      health: emptyCtx(),
      moments,
      now: NOW,
    });
    expect(out.attention.flagged).toBe(false);
    expect(out.daysSinceLastShown).toBe(1);
  });

  it("fit role scores up with weekly workout days", () => {
    const exer = Array.from({ length: 7 }).map((_, i) => {
      const d = new Date(NOW);
      d.setDate(d.getDate() - (6 - i));
      const dateKey = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
      // workouts on days 2, 4, 6 (3 workouts in the last 7)
      return { date: dateKey, value: [2, 4, 6].includes(i) ? 30 : 0 };
    });
    const out = computeWeekActivity("fit", {
      health: { exerciseMinutes: exer as any },
      moments: [],
      now: NOW,
    });
    expect(out.score).toBeGreaterThan(0);
    expect(out.activityLine).toMatch(/3 gym/);
  });

  it("counts manual moments toward the bars and score", () => {
    const moments: RoleMoment[] = [
      {
        id: "m1",
        roleId: "tori",
        timestamp: NOW.getTime(),
        what: "date night",
        tag: null,
        source: "manual",
        sourceRef: null,
      },
      {
        id: "m2",
        roleId: "tori",
        timestamp: NOW.getTime() - 2 * 24 * 3600 * 1000,
        what: "called Tori",
        tag: null,
        source: "manual",
        sourceRef: null,
      },
    ];
    const out = computeWeekActivity("tori", {
      health: emptyCtx(),
      moments,
      now: NOW,
    });
    expect(out.score).toBeGreaterThan(0);
    expect(out.bars[6]).toBeGreaterThanOrEqual(1); // today
    expect(out.bars[4]).toBeGreaterThanOrEqual(1); // two days ago
  });
});
