import {
  extractSleepDetails,
  aggregateSleepDetailed,
  buildSleepDetailedBundle,
  pickDefaultSleepSource,
  SLEEP_ALL_SOURCES,
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

describe("buildSleepDetailedBundle", () => {
  // Use 2026-03-15 at noon local as "end of window" anchor for deterministic bucketing.
  const endDate = new Date(2026, 2, 15, 12, 0, 0);

  it("returns empty bundle for no samples", () => {
    const bundle = buildSleepDetailedBundle([], endDate, 7);
    expect(bundle.merged).toHaveLength(7);
    expect(bundle.merged.every((n) => n.totalHours === null)).toBe(true);
    expect(Object.keys(bundle.bySource)).toEqual([]);
  });

  it("groups samples by source and produces independent SleepDaily arrays", () => {
    // Watch reports stages; AutoSleep reports only generic "Asleep" (value 1).
    const samples: SleepSample[] = [
      {
        startDate: new Date(2026, 2, 14, 23, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 1, 0, 0).toISOString(),
        value: 3, // Core
        source: "Apple Watch",
      },
      {
        startDate: new Date(2026, 2, 15, 1, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 2, 0, 0).toISOString(),
        value: 4, // Deep
        source: "Apple Watch",
      },
      {
        startDate: new Date(2026, 2, 15, 2, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 6, 30, 0).toISOString(),
        value: 1, // Asleep
        source: "AutoSleep",
      },
    ];
    const bundle = buildSleepDetailedBundle(samples, endDate, 7);

    expect(Object.keys(bundle.bySource).sort()).toEqual([
      "Apple Watch",
      "AutoSleep",
    ]);

    const watchNight = bundle.bySource["Apple Watch"].find(
      (n) => n.date === "2026-03-14",
    );
    expect(watchNight).toBeDefined();
    expect(watchNight!.coreHours).toBe(2); // 23→01
    expect(watchNight!.deepHours).toBe(1); // 01→02
    expect(watchNight!.remHours).toBe(0);

    const autoNight = bundle.bySource["AutoSleep"].find(
      (n) => n.date === "2026-03-14",
    );
    expect(autoNight).toBeDefined();
    expect(autoNight!.coreHours).toBe(0);
    expect(autoNight!.deepHours).toBe(0);
    // AutoSleep's sample is a generic "Asleep" (value 1), so stage hours stay
    // at zero but totalHours is non-null (matches calculateSleepHours).
    expect(autoNight!.totalHours).not.toBeNull();

    // Merged view has all three samples collapsed.
    const mergedNight = bundle.merged.find((n) => n.date === "2026-03-14");
    expect(mergedNight).toBeDefined();
    expect(mergedNight!.totalHours).not.toBeNull();
  });

  it("omits sources with no samples in the window", () => {
    const samples: SleepSample[] = [
      {
        startDate: new Date(2026, 2, 14, 23, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 6, 0, 0).toISOString(),
        value: 1,
        source: "Apple Watch",
      },
    ];
    const bundle = buildSleepDetailedBundle(samples, endDate, 7);
    expect(Object.keys(bundle.bySource)).toEqual(["Apple Watch"]);
    expect(bundle.bySource["AutoSleep"]).toBeUndefined();
  });
});

describe("pickDefaultSleepSource", () => {
  const endDate = new Date(2026, 2, 15, 12, 0, 0);

  it("picks the source with the most stage-detailed hours", () => {
    const samples: SleepSample[] = [
      // Watch: 2h Core + 1h Deep + 0.5h REM = 3.5 stage hours
      {
        startDate: new Date(2026, 2, 14, 23, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 1, 0, 0).toISOString(),
        value: 3, // Core
        source: "Apple Watch",
      },
      {
        startDate: new Date(2026, 2, 15, 1, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 2, 0, 0).toISOString(),
        value: 4, // Deep
        source: "Apple Watch",
      },
      {
        startDate: new Date(2026, 2, 15, 2, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 2, 30, 0).toISOString(),
        value: 5, // REM
        source: "Apple Watch",
      },
      // AutoSleep: generic Asleep only, zero stage detail
      {
        startDate: new Date(2026, 2, 15, 2, 30, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 6, 30, 0).toISOString(),
        value: 1,
        source: "AutoSleep",
      },
    ];
    const bundle = buildSleepDetailedBundle(samples, endDate, 7);
    expect(pickDefaultSleepSource(bundle)).toBe("Apple Watch");
  });

  it("falls back to 'All' when no source reports stages", () => {
    const samples: SleepSample[] = [
      {
        startDate: new Date(2026, 2, 14, 23, 0, 0).toISOString(),
        endDate: new Date(2026, 2, 15, 7, 0, 0).toISOString(),
        value: 1, // generic Asleep only
        source: "AutoSleep",
      },
    ];
    const bundle = buildSleepDetailedBundle(samples, endDate, 7);
    expect(pickDefaultSleepSource(bundle)).toBe(SLEEP_ALL_SOURCES);
  });

  it("returns 'All' for empty bundle", () => {
    const bundle = buildSleepDetailedBundle([], endDate, 7);
    expect(pickDefaultSleepSource(bundle)).toBe(SLEEP_ALL_SOURCES);
  });
});
