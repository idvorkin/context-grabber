import {
  extractSleepDetails,
  aggregateSleepDetailed,
  buildSleepDetailedBundle,
  pickDefaultSleepSource,
  SLEEP_ALL_SOURCES,
  computeSleepDebt,
  computeConsistencyStats,
  computeTrackingGap,
  computeOnsetMinutes,
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
      bedtime: null, wakeTime: null, onsetMinutes: null, samples: [],
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
      bedtime, wakeTime, onsetMinutes: null, samples: [],
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

describe("computeTrackingGap", () => {
  function night(overrides: Partial<SleepDaily> = {}): SleepDaily {
    return {
      date: "2026-04-23",
      totalHours: 7,
      coreHours: 0,
      deepHours: 0,
      remHours: 0,
      awakeHours: 0,
      onsetMinutes: null,
      // Bedtime 10:30pm, wakeTime 5:30am = 7h in bed.
      bedtime: "2026-04-24T05:30:00Z", // Thu 22:30 local if PDT
      wakeTime: "2026-04-24T12:30:00Z", // Fri 05:30 local if PDT
      samples: [],
      ...overrides,
    };
  }

  it("returns null when totalHours roughly matches in-bed range", () => {
    // 7h in bed, 7h tracked → gap 0 → null.
    expect(computeTrackingGap(night({ totalHours: 7 }))).toBeNull();
  });

  it("returns null for nights with no bedtime or wakeTime", () => {
    expect(computeTrackingGap(night({ bedtime: null, totalHours: 5 }))).toBeNull();
    expect(computeTrackingGap(night({ wakeTime: null, totalHours: 5 }))).toBeNull();
  });

  it("returns null for nights with no tracked hours (already visibly blank)", () => {
    expect(computeTrackingGap(night({ totalHours: null }))).toBeNull();
    expect(computeTrackingGap(night({ totalHours: 0 }))).toBeNull();
  });

  it("returns null when gap is below the 30-minute floor", () => {
    // 7h in bed, 6h42m tracked → gap 18m → below 30m floor, null.
    expect(computeTrackingGap(night({ totalHours: 6.7 }))).toBeNull();
  });

  it("flags when tracker dropped ~45 min on a 7-hour night", () => {
    // 7h in bed, 6.25h tracked → gap 45m → above 30m floor AND 10% of 420=42, yes.
    const gap = computeTrackingGap(night({ totalHours: 6.25 }));
    expect(gap).not.toBeNull();
    expect(gap!).toBeGreaterThanOrEqual(44);
    expect(gap!).toBeLessThanOrEqual(46);
  });

  it("respects the 10% threshold on longer nights", () => {
    // 10h in bed (bed 10pm, wake 8am), 9h tracked → gap 60m, 10% = 60m → boundary; null or just under.
    const gapNight: SleepDaily = {
      date: "2026-04-23",
      totalHours: 9,
      coreHours: 0,
      deepHours: 0,
      remHours: 0,
      awakeHours: 0,
      bedtime: "2026-04-24T05:00:00Z",
      wakeTime: "2026-04-24T15:00:00Z", // 10h later
      onsetMinutes: null,
      samples: [],
    };
    // Exactly 60m gap, 10% of 600m = 60m. gap (60) is NOT > threshold (60) → null.
    expect(computeTrackingGap(gapNight)).toBeNull();
    // Now drop tracked to 8.5h → gap 90m, threshold max(30, 60) = 60 → 90 > 60 → flagged.
    expect(computeTrackingGap({ ...gapNight, totalHours: 8.5 })).toBeGreaterThanOrEqual(89);
  });

  it("returns null on a degenerate in-bed range (wakeTime at or before bedtime)", () => {
    expect(
      computeTrackingGap(
        night({
          bedtime: "2026-04-24T12:30:00Z",
          wakeTime: "2026-04-24T12:30:00Z",
          totalHours: 1,
        }),
      ),
    ).toBeNull();
  });
});

describe("computeOnsetMinutes", () => {
  // Small helper: build an Awake sample from start/end ms.
  const awake = (startMs: number, endMs: number): SleepSample => ({
    startDate: new Date(startMs).toISOString(),
    endDate: new Date(endMs).toISOString(),
    value: 2,
  });
  const sleep = (startMs: number, endMs: number): SleepSample => ({
    startDate: new Date(startMs).toISOString(),
    endDate: new Date(endMs).toISOString(),
    value: 3,
  });
  const minutes = 60 * 1000;
  const hours = 60 * minutes;

  it("returns null when there's no pre-sleep Awake", () => {
    const first = Date.UTC(2026, 3, 24, 5, 0); // 5:00 UTC
    const samples = [sleep(first, first + 8 * hours)];
    expect(computeOnsetMinutes(samples, first)).toBeNull();
  });

  it("returns the duration of a single contiguous pre-sleep Awake segment", () => {
    const first = Date.UTC(2026, 3, 24, 5, 0);
    const samples = [
      awake(first - 30 * minutes, first), // 30m Awake ending exactly at first sleep
      sleep(first, first + 8 * hours),
    ];
    expect(computeOnsetMinutes(samples, first)).toBe(30);
  });

  it("sums multiple close-together pre-sleep Awake segments", () => {
    const first = Date.UTC(2026, 3, 24, 5, 0);
    const samples = [
      awake(first - 50 * minutes, first - 40 * minutes), // 10m
      awake(first - 20 * minutes, first), // 20m, 20m gap to prior — still < 1h
      sleep(first, first + 8 * hours),
    ];
    // Walking backwards: pick up 20m (directly adjacent), then 20m gap is fine
    // (< 1h), pick up 10m. Total 30m.
    expect(computeOnsetMinutes(samples, first)).toBe(30);
  });

  it("discards Awake separated from sleep by more than 1h gap (the 'noise' case)", () => {
    const first = Date.UTC(2026, 3, 24, 5, 0);
    const samples = [
      awake(first - 4 * hours, first - 3.5 * hours), // 30m, far from sleep → noise
      awake(first - 15 * minutes, first), // 15m, directly adjacent → counted
      sleep(first, first + 8 * hours),
    ];
    // Walking backwards: 15m (adjacent). Then gap from first-15m back to
    // first-3.5h = 3h 15m > 1h → stop. Noise segment discarded.
    expect(computeOnsetMinutes(samples, first)).toBe(15);
  });

  it("stops at the first >1h gap even mid-run", () => {
    const first = Date.UTC(2026, 3, 24, 5, 0);
    const samples = [
      awake(first - 6 * hours, first - 5.5 * hours), // 30m, noise
      awake(first - 90 * minutes, first - 80 * minutes), // 10m, bridges >1h to prior
      awake(first - 45 * minutes, first - 30 * minutes), // 15m, bridges 35m to prior
      awake(first - 20 * minutes, first), // 20m, 10m gap to prior
      sleep(first, first + 8 * hours),
    ];
    // Walking backwards: 20m (adj), 10m gap, 15m (45m→30m), 35m gap, 10m
    // (90m→80m), 3h 50m gap → stop. Noise (30m earlier) discarded.
    // Total = 20 + 15 + 10 = 45m.
    expect(computeOnsetMinutes(samples, first)).toBe(45);
  });

  it("ignores Awake samples whose end is after the first sleep start", () => {
    // A mid-night Awake (say 3am wake) is not an onset segment.
    const first = Date.UTC(2026, 3, 24, 5, 0);
    const samples = [
      sleep(first, first + 2 * hours),
      awake(first + 2 * hours, first + 2.25 * hours), // mid-night Awake
      sleep(first + 2.25 * hours, first + 8 * hours),
    ];
    expect(computeOnsetMinutes(samples, first)).toBeNull();
  });

  it("merges overlapping pre-sleep Awake samples from two sources", () => {
    const first = Date.UTC(2026, 3, 24, 5, 0);
    const samples: SleepSample[] = [
      {
        startDate: new Date(first - 30 * minutes).toISOString(),
        endDate: new Date(first - 10 * minutes).toISOString(),
        value: 2,
        source: "Watch",
      },
      {
        startDate: new Date(first - 20 * minutes).toISOString(),
        endDate: new Date(first).toISOString(),
        value: 2,
        source: "iPhone",
      },
      sleep(first, first + 7 * hours),
    ];
    // Watch covers [-30, -10], iPhone covers [-20, 0]. Merged: [-30, 0] = 30m.
    expect(computeOnsetMinutes(samples, first)).toBe(30);
  });
});

describe("computeTrackingGap — Awake-in-session is covered, not a gap", () => {
  const minutes = 60 * 1000;
  const hours = 60 * minutes;

  it("does not flag a night whose only 'gap' is mid-night Awake time", () => {
    // 8h in bed, 6.5h Core+Deep+REM, 1.5h Awake (bathroom breaks + early stir).
    // Old behavior: gap = 8 - 6.5 = 1.5h → flagged.
    // New behavior: covered = 6.5 + 1.5 = 8h → gap = 0 → null.
    const bedMs = Date.UTC(2026, 3, 24, 5, 0);
    const wakeMs = bedMs + 8 * hours;
    const samples: SleepSample[] = [
      {
        startDate: new Date(bedMs).toISOString(),
        endDate: new Date(bedMs + 2 * hours).toISOString(),
        value: 3,
      },
      {
        startDate: new Date(bedMs + 2 * hours).toISOString(),
        endDate: new Date(bedMs + 2.5 * hours).toISOString(),
        value: 2, // 30m Awake mid-session
      },
      {
        startDate: new Date(bedMs + 2.5 * hours).toISOString(),
        endDate: new Date(bedMs + 7 * hours).toISOString(),
        value: 3,
      },
      {
        startDate: new Date(bedMs + 7 * hours).toISOString(),
        endDate: new Date(bedMs + 8 * hours).toISOString(),
        value: 2, // 1h Awake at end
      },
    ];
    const night: SleepDaily = {
      date: "2026-04-23",
      totalHours: 6.5, // core+deep+rem, Awake excluded
      coreHours: 6.5,
      deepHours: 0,
      remHours: 0,
      awakeHours: 1.5,
      bedtime: new Date(bedMs).toISOString(),
      wakeTime: new Date(wakeMs).toISOString(),
      onsetMinutes: null,
      samples,
    };
    expect(computeTrackingGap(night)).toBeNull();
  });

  it("flags when truly untracked time is beyond the threshold even if some Awake exists", () => {
    // 8h in bed, 5.5h core+deep+rem, 15m Awake, 2h 15m truly untracked.
    const bedMs = Date.UTC(2026, 3, 24, 5, 0);
    const wakeMs = bedMs + 8 * hours;
    const samples: SleepSample[] = [
      {
        startDate: new Date(bedMs).toISOString(),
        endDate: new Date(bedMs + 5.5 * hours).toISOString(),
        value: 3, // 5.5h sleep
      },
      {
        startDate: new Date(bedMs + 5.5 * hours).toISOString(),
        endDate: new Date(bedMs + 5.75 * hours).toISOString(),
        value: 2, // 15m Awake (then 2h 15m of nothing)
      },
    ];
    const night: SleepDaily = {
      date: "2026-04-23",
      totalHours: 5.5,
      coreHours: 5.5,
      deepHours: 0,
      remHours: 0,
      awakeHours: 0.25,
      bedtime: new Date(bedMs).toISOString(),
      wakeTime: new Date(wakeMs).toISOString(),
      onsetMinutes: null,
      samples,
    };
    // Covered = 5.5 + 0.25 = 5.75h. In-bed 8h. Gap = 2.25h = 135m.
    // Threshold = max(30, 48) = 48. 135 > 48 → flagged.
    const gap = computeTrackingGap(night);
    expect(gap).not.toBeNull();
    expect(gap!).toBeGreaterThanOrEqual(134);
    expect(gap!).toBeLessThanOrEqual(136);
  });
});
