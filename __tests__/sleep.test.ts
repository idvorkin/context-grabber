import {
  extractSleepDetails,
  aggregateSleepDetailed,
  computeSleepDebt,
  computeConsistencyStats,
  type SleepDaily,
} from "../lib/sleep";
import type { SleepSample } from "../lib/health";

describe("extractSleepDetails", () => {
  it("extracts bedtime and wakeTime from a single sample", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
    ];
    const result = extractSleepDetails(samples);
    expect(result.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(result.wakeTime).toBe("2026-03-15T07:00:00.000Z");
  });

  it("extracts bedtime and wakeTime from multiple samples", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T02:00:00.000Z",
      },
      {
        startDate: "2026-03-15T03:00:00.000Z",
        endDate: "2026-03-15T07:30:00.000Z",
      },
    ];
    const result = extractSleepDetails(samples);
    expect(result.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(result.wakeTime).toBe("2026-03-15T07:30:00.000Z");
  });

  it("returns null/null for empty array", () => {
    const result = extractSleepDetails([]);
    expect(result.bedtime).toBeNull();
    expect(result.wakeTime).toBeNull();
  });

  it("returns null/null for undefined input", () => {
    const result = extractSleepDetails(undefined);
    expect(result.bedtime).toBeNull();
    expect(result.wakeTime).toBeNull();
  });

  it("handles unsorted input and still returns correct values", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-15T03:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
      {
        startDate: "2026-03-14T22:00:00.000Z",
        endDate: "2026-03-15T01:00:00.000Z",
      },
      {
        startDate: "2026-03-15T01:30:00.000Z",
        endDate: "2026-03-15T02:30:00.000Z",
      },
    ];
    const result = extractSleepDetails(samples);
    // After sorting: 22:00, 01:30, 03:00
    expect(result.bedtime).toBe("2026-03-14T22:00:00.000Z");
    // Last sample after sorting ends at 07:00
    expect(result.wakeTime).toBe("2026-03-15T07:00:00.000Z");
  });

  it("returns ISO 8601 UTC strings", () => {
    const samples: SleepSample[] = [
      {
        startDate: new Date("2026-03-14T23:15:00.000Z"),
        endDate: new Date("2026-03-15T06:45:00.000Z"),
      },
    ];
    const result = extractSleepDetails(samples);
    expect(result.bedtime).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z$/);
    expect(result.wakeTime).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}.\d{3}Z$/);
  });
});

// ─── aggregateSleepDetailed ───────────────────────────────────────────────────

describe("aggregateSleepDetailed", () => {
  // Reference endDate in local time — 2026-03-15 12:00 local
  const endDate = new Date(2026, 2, 15, 12, 0, 0);

  it("returns `days` buckets when samples is undefined", () => {
    const result = aggregateSleepDetailed(undefined, endDate, 7);
    expect(result).toHaveLength(7);
    expect(result.every((b) => b.totalHours === null)).toBe(true);
    expect(result.every((b) => b.samples.length === 0)).toBe(true);
  });

  it("bucket is identified by local date of sample startDate", () => {
    const samples: SleepSample[] = [
      // 11pm local on 2026-03-14 → bucket 2026-03-14
      { startDate: new Date(2026, 2, 14, 23, 0, 0), endDate: new Date(2026, 2, 15, 7, 0, 0), value: 3 },
    ];
    const result = aggregateSleepDetailed(samples, endDate, 7);
    const night14 = result.find((b) => b.date === "2026-03-14")!;
    expect(night14).toBeDefined();
    expect(night14.samples.length).toBe(1);
    expect(night14.coreHours).toBe(8);
    expect(night14.totalHours).toBe(8);
  });

  it("computes per-stage hours from typed samples", () => {
    // One night, four sample types; sums should match
    const night = new Date(2026, 2, 14);
    const samples: SleepSample[] = [
      { startDate: new Date(2026, 2, 14, 23, 0, 0), endDate: new Date(2026, 2, 15, 0, 0, 0), value: 3 }, // 1h Core
      { startDate: new Date(2026, 2, 15, 0, 0, 0), endDate: new Date(2026, 2, 15, 1, 30, 0), value: 4 }, // 1.5h Deep
      { startDate: new Date(2026, 2, 15, 1, 30, 0), endDate: new Date(2026, 2, 15, 3, 0, 0), value: 5 }, // 1.5h REM
      { startDate: new Date(2026, 2, 15, 3, 0, 0), endDate: new Date(2026, 2, 15, 3, 15, 0), value: 2 }, // 0.25h Awake
      { startDate: new Date(2026, 2, 15, 3, 15, 0), endDate: new Date(2026, 2, 15, 6, 0, 0), value: 3 }, // 2.75h Core
    ];
    const result = aggregateSleepDetailed(samples, endDate, 7);
    const n = result.find((b) => b.date === "2026-03-14")!;
    expect(n.coreHours).toBeCloseTo(3.75, 1);
    expect(n.deepHours).toBeCloseTo(1.5, 1);
    expect(n.remHours).toBeCloseTo(1.5, 1);
    expect(n.awakeHours).toBeCloseTo(0.3, 1); // 0.25 rounded to 1dp = 0.3 (Math.round(2.5)/10 = 0.3)
    expect(n.totalHours).toBeCloseTo(6.75, 1); // core+deep+rem excludes Awake
  });

  it("bedtime = earliest asleep start, wakeTime = latest asleep end", () => {
    const samples: SleepSample[] = [
      { startDate: new Date(2026, 2, 14, 23, 5, 0), endDate: new Date(2026, 2, 15, 0, 0, 0), value: 3 },
      { startDate: new Date(2026, 2, 15, 0, 0, 0), endDate: new Date(2026, 2, 15, 6, 30, 0), value: 4 },
    ];
    const result = aggregateSleepDetailed(samples, endDate, 7);
    const n = result.find((b) => b.date === "2026-03-14")!;
    expect(n.bedtime).not.toBeNull();
    expect(n.wakeTime).not.toBeNull();
    expect(new Date(n.bedtime!).getHours()).toBe(23);
    expect(new Date(n.wakeTime!).getHours()).toBe(6);
  });

  it("merges overlapping same-stage intervals across sources", () => {
    // Watch + iPhone both report Core from 11pm–7am with 30min overlap in middle
    const samples: SleepSample[] = [
      { startDate: new Date(2026, 2, 14, 23, 0, 0), endDate: new Date(2026, 2, 15, 3, 30, 0), value: 3, source: "Watch" },
      { startDate: new Date(2026, 2, 15, 3, 0, 0), endDate: new Date(2026, 2, 15, 7, 0, 0), value: 3, source: "iPhone" },
    ];
    const result = aggregateSleepDetailed(samples, endDate, 7);
    const n = result.find((b) => b.date === "2026-03-14")!;
    // Merged duration = 8h, NOT 8.5h (the 30-min overlap is not double-counted)
    expect(n.coreHours).toBeCloseTo(8, 1);
  });
});

// ─── computeSleepDebt ─────────────────────────────────────────────────────────

describe("computeSleepDebt", () => {
  function makeNight(total: number | null): SleepDaily {
    return {
      date: "2026-03-15", totalHours: total,
      coreHours: 0, deepHours: 0, remHours: 0, awakeHours: 0,
      bedtime: null, wakeTime: null, samples: [],
    };
  }

  it("zero debt when all nights meet target", () => {
    const nights = [8, 8, 8, 8, 8, 8, 8].map(makeNight);
    expect(computeSleepDebt(nights, 8)).toBe(0);
  });

  it("sums per-night deficits", () => {
    const nights = [7, 7, 7, 7, 7, 7, 7].map(makeNight);
    expect(computeSleepDebt(nights, 8)).toBe(7); // 1h × 7 nights
  });

  it("oversleep does not repay debt", () => {
    const nights = [6, 10, 6, 10, 6, 10, 6].map(makeNight); // 4 × 2h deficits
    expect(computeSleepDebt(nights, 8)).toBe(8);
  });

  it("missing nights (null) count as zero sleep, full-target deficit", () => {
    const nights = [makeNight(null), makeNight(8)];
    expect(computeSleepDebt(nights, 8)).toBe(8);
  });

  it("returns 0 when target is 0", () => {
    const nights = [makeNight(5)];
    expect(computeSleepDebt(nights, 0)).toBe(0);
  });
});

// ─── computeConsistencyStats ──────────────────────────────────────────────────

describe("computeConsistencyStats", () => {
  function makeNight(bedtime: string | null, wakeTime: string | null): SleepDaily {
    return {
      date: "2026-03-15", totalHours: 8,
      coreHours: 0, deepHours: 0, remHours: 0, awakeHours: 0,
      bedtime, wakeTime, samples: [],
    };
  }

  it("returns 0 stdev for identical bedtimes", () => {
    const t = new Date(2026, 2, 14, 23, 0, 0).toISOString();
    const w = new Date(2026, 2, 15, 7, 0, 0).toISOString();
    const nights = [makeNight(t, w), makeNight(t, w), makeNight(t, w)];
    const stats = computeConsistencyStats(nights);
    expect(stats.bedtimeStdevMinutes).toBe(0);
    expect(stats.wakeStdevMinutes).toBe(0);
  });

  it("treats bedtimes across midnight consistently", () => {
    // 11pm and 1am should be "2 hours apart", not 22
    const n1 = makeNight(new Date(2026, 2, 14, 23, 0, 0).toISOString(), null);
    const n2 = makeNight(new Date(2026, 2, 15, 1, 0, 0).toISOString(), null);
    const stats = computeConsistencyStats([n1, n2]);
    // Stdev of [1380 (11pm +24h), 1500 (1am +24h)] → mean 1440, stdev 60
    expect(stats.bedtimeStdevMinutes).toBe(60);
  });

  it("handles missing bedtime/wake fields", () => {
    const n1 = makeNight(null, null);
    const n2 = makeNight(new Date(2026, 2, 15, 7, 0, 0).toISOString(), new Date(2026, 2, 15, 7, 0, 0).toISOString());
    const stats = computeConsistencyStats([n1, n2]);
    expect(stats.bedtimeStdevMinutes).toBe(0); // only 1 valid → stdev 0
  });
});
