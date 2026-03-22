import {
  calculateSleepHours,
  filterActualSleep,
  sleepCategoryName,
  buildSleepBySource,
  calculateMeditationMinutes,
  extractWeight,
  countWeightDays,
  buildHealthData,
  type SleepSample,
  type SourceSleepSummary,
  type MindfulSession,
  type WeightSample,
  type HealthQueryResults,
} from "../lib/health";

describe("calculateSleepHours", () => {
  it("returns null for undefined input", () => {
    expect(calculateSleepHours(undefined)).toBeNull();
  });

  it("returns null for empty array", () => {
    expect(calculateSleepHours([])).toBeNull();
  });

  it("calculates hours from a single sleep sample", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(8);
  });

  it("sums multiple sleep samples", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T02:00:00.000Z", // 3 hours
      },
      {
        startDate: "2026-03-15T03:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z", // 4 hours
      },
    ];
    expect(calculateSleepHours(samples)).toBe(7);
  });

  it("rounds to one decimal place", () => {
    // 7 hours 30 minutes = 7.5 hours
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T06:30:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(7.5);
  });

  it("handles Date objects as well as strings", () => {
    const samples: SleepSample[] = [
      {
        startDate: new Date("2026-03-14T22:00:00.000Z"),
        endDate: new Date("2026-03-15T06:00:00.000Z"),
      },
    ];
    expect(calculateSleepHours(samples)).toBe(8);
  });

  it("merges overlapping samples from multiple sources", () => {
    // Watch: 23:00-07:00, Phone: 23:30-06:30 (fully overlapping)
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
      {
        startDate: "2026-03-14T23:30:00.000Z",
        endDate: "2026-03-15T06:30:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(8); // not 15
  });

  it("merges partially overlapping samples", () => {
    // 23:00-03:00 and 02:00-07:00 overlap by 1 hour
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T03:00:00.000Z",
      },
      {
        startDate: "2026-03-15T02:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(8); // not 9
  });

  it("handles multiple overlapping sources correctly", () => {
    // Three sources all reporting the same ~8h sleep
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
      {
        startDate: "2026-03-14T23:15:00.000Z",
        endDate: "2026-03-15T06:45:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(8); // not 24
  });

  it("returns 0 when start equals end", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-15T00:00:00.000Z",
        endDate: "2026-03-15T00:00:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(0);
  });

  it("filters out InBed and Awake samples when value field present", () => {
    const samples: SleepSample[] = [
      // InBed: 10pm-7am (9hrs) — should be excluded
      { startDate: "2026-03-14T22:00:00.000Z", endDate: "2026-03-15T07:00:00.000Z", value: 0 },
      // Awake: 3am-3:15am — should be excluded
      { startDate: "2026-03-15T03:00:00.000Z", endDate: "2026-03-15T03:15:00.000Z", value: 2 },
      // Core: 10:30pm-1am (2.5hrs)
      { startDate: "2026-03-14T22:30:00.000Z", endDate: "2026-03-15T01:00:00.000Z", value: 3 },
      // Deep: 1am-3am (2hrs)
      { startDate: "2026-03-15T01:00:00.000Z", endDate: "2026-03-15T03:00:00.000Z", value: 4 },
      // REM: 3:15am-5am (1.75hrs)
      { startDate: "2026-03-15T03:15:00.000Z", endDate: "2026-03-15T05:00:00.000Z", value: 5 },
      // Core: 5am-6:30am (1.5hrs)
      { startDate: "2026-03-15T05:00:00.000Z", endDate: "2026-03-15T06:30:00.000Z", value: 3 },
    ];
    // Without filtering: would be ~9hrs (InBed covers everything)
    // With filtering: Core+Deep+REM+Core = 10:30pm-6:30am with 15min gap at 3am = ~7.75hrs
    const hours = calculateSleepHours(samples);
    expect(hours).toBeLessThan(9);
    expect(hours).toBeGreaterThan(7);
  });

  it("keeps all samples when no value field present (legacy data)", () => {
    const samples: SleepSample[] = [
      { startDate: "2026-03-14T22:00:00.000Z", endDate: "2026-03-15T06:00:00.000Z" },
    ];
    expect(calculateSleepHours(samples)).toBe(8);
  });
});

describe("filterActualSleep", () => {
  it("filters out InBed (0) and Awake (2)", () => {
    const samples: SleepSample[] = [
      { startDate: "2026-03-15T00:00:00.000Z", endDate: "2026-03-15T08:00:00.000Z", value: 0 },
      { startDate: "2026-03-15T01:00:00.000Z", endDate: "2026-03-15T03:00:00.000Z", value: 3 },
      { startDate: "2026-03-15T03:00:00.000Z", endDate: "2026-03-15T03:15:00.000Z", value: 2 },
      { startDate: "2026-03-15T04:00:00.000Z", endDate: "2026-03-15T06:00:00.000Z", value: 5 },
    ];
    const filtered = filterActualSleep(samples);
    expect(filtered).toHaveLength(2);
    expect(filtered[0].value).toBe(3);
    expect(filtered[1].value).toBe(5);
  });

  it("keeps Asleep (1), Core (3), Deep (4), REM (5)", () => {
    const samples: SleepSample[] = [
      { startDate: "a", endDate: "b", value: 1 },
      { startDate: "a", endDate: "b", value: 3 },
      { startDate: "a", endDate: "b", value: 4 },
      { startDate: "a", endDate: "b", value: 5 },
    ];
    expect(filterActualSleep(samples)).toHaveLength(4);
  });

  it("returns all samples when no value field present", () => {
    const samples: SleepSample[] = [
      { startDate: "a", endDate: "b" },
      { startDate: "c", endDate: "d" },
    ];
    expect(filterActualSleep(samples)).toHaveLength(2);
  });
});

describe("sleepCategoryName", () => {
  it("maps known sleep values to category names", () => {
    expect(sleepCategoryName(0)).toBe("InBed");
    expect(sleepCategoryName(1)).toBe("Asleep");
    expect(sleepCategoryName(2)).toBe("Awake");
    expect(sleepCategoryName(3)).toBe("Core");
    expect(sleepCategoryName(4)).toBe("Deep");
    expect(sleepCategoryName(5)).toBe("REM");
  });

  it("returns 'Asleep' for undefined (legacy data)", () => {
    expect(sleepCategoryName(undefined)).toBe("Asleep");
  });

  it("returns 'Unknown' for unrecognized values", () => {
    expect(sleepCategoryName(99)).toBe("Unknown");
  });
});

describe("buildSleepBySource", () => {
  it("returns null for undefined input", () => {
    expect(buildSleepBySource(undefined)).toBeNull();
  });

  it("returns null for empty array", () => {
    expect(buildSleepBySource([])).toBeNull();
  });

  it("groups samples by source with stage breakdown", () => {
    const samples: SleepSample[] = [
      { startDate: "2026-03-14T22:30:00.000Z", endDate: "2026-03-15T01:00:00.000Z", value: 3, source: "Apple Watch" },
      { startDate: "2026-03-15T01:00:00.000Z", endDate: "2026-03-15T03:00:00.000Z", value: 4, source: "Apple Watch" },
      { startDate: "2026-03-15T03:15:00.000Z", endDate: "2026-03-15T05:00:00.000Z", value: 5, source: "Apple Watch" },
      { startDate: "2026-03-15T03:00:00.000Z", endDate: "2026-03-15T03:15:00.000Z", value: 2, source: "Apple Watch" },
    ];
    const result = buildSleepBySource(samples)!;
    expect(result["Apple Watch"]).toBeDefined();
    expect(result["Apple Watch"].bedtime).toBe("2026-03-14T22:30:00.000Z");
    expect(result["Apple Watch"].wakeTime).toBe("2026-03-15T05:00:00.000Z");
    expect(result["Apple Watch"].coreHours).toBe(2.5);
    expect(result["Apple Watch"].deepHours).toBe(2);
    expect(result["Apple Watch"].remHours).toBe(1.8);
    expect(result["Apple Watch"].awakeHours).toBe(0.3);
  });

  it("separates multiple sources", () => {
    const samples: SleepSample[] = [
      { startDate: "2026-03-14T23:00:00.000Z", endDate: "2026-03-15T07:00:00.000Z", value: 3, source: "Apple Watch" },
      { startDate: "2026-03-14T22:45:00.000Z", endDate: "2026-03-15T06:50:00.000Z", value: 4, source: "AutoSleep" },
    ];
    const result = buildSleepBySource(samples)!;
    expect(Object.keys(result)).toHaveLength(2);
    expect(result["Apple Watch"]).toBeDefined();
    expect(result["AutoSleep"]).toBeDefined();
    expect(result["Apple Watch"].bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(result["AutoSleep"].bedtime).toBe("2026-03-14T22:45:00.000Z");
  });

  it("defaults to 'Unknown' source when not provided", () => {
    const samples: SleepSample[] = [
      { startDate: "2026-03-14T23:00:00.000Z", endDate: "2026-03-15T07:00:00.000Z", value: 3 },
    ];
    const result = buildSleepBySource(samples)!;
    expect(result["Unknown"]).toBeDefined();
    expect(result["Unknown"].coreHours).toBe(8);
  });

  it("handles Date objects", () => {
    const samples: SleepSample[] = [
      {
        startDate: new Date("2026-03-14T23:00:00.000Z"),
        endDate: new Date("2026-03-15T07:00:00.000Z"),
        value: 4,
        source: "Apple Watch",
      },
    ];
    const result = buildSleepBySource(samples)!;
    expect(result["Apple Watch"].bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(result["Apple Watch"].wakeTime).toBe("2026-03-15T07:00:00.000Z");
    expect(result["Apple Watch"].deepHours).toBe(8);
  });

  it("rounds hours to 1 decimal", () => {
    // 7h 20m = 7.333... → 7.3
    const samples: SleepSample[] = [
      { startDate: "2026-03-14T23:00:00.000Z", endDate: "2026-03-15T06:20:00.000Z", value: 5, source: "Watch" },
    ];
    const result = buildSleepBySource(samples)!;
    expect(result["Watch"].remHours).toBe(7.3);
  });
});

describe("buildHealthData", () => {
  function fulfilled<T>(value: T): PromiseFulfilledResult<T> {
    return { status: "fulfilled", value };
  }

  function rejected(reason = "error"): PromiseRejectedResult {
    return { status: "rejected", reason };
  }

  it("returns all null when every query is rejected", () => {
    const results: HealthQueryResults = [
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
    ];
    expect(buildHealthData(results)).toEqual({
      steps: null,
      heartRate: null,
      sleepHours: null,
      bedtime: null,
      wakeTime: null,
      sleepBySource: null,
      activeEnergy: null,
      walkingDistance: null,
      weight: null,
      weightDaysLast7: null,
      meditationMinutes: null,
      hrv: null,
      restingHeartRate: null,
      exerciseMinutes: null,
    });
  });

  it("extracts values from fulfilled results", () => {
    const results: HealthQueryResults = [
      fulfilled({ sumQuantity: { quantity: 8432.7 } }),
      fulfilled({ quantity: 72.4 }),
      fulfilled({ sumQuantity: { quantity: 312.9 } }),
      fulfilled({ sumQuantity: { quantity: 5.678 } }),
      fulfilled([
        {
          startDate: "2026-03-14T23:00:00.000Z",
          endDate: "2026-03-15T07:00:00.000Z",
        },
      ]),
      fulfilled({ quantity: 75.5 }),
      fulfilled([
        {
          startDate: "2026-03-15T08:00:00.000Z",
          endDate: "2026-03-15T08:15:00.000Z",
        },
      ]),
      fulfilled([
        { startDate: "2026-03-14T08:00:00.000Z", quantity: 75.5 },
        { startDate: "2026-03-13T08:00:00.000Z", quantity: 75.4 },
        { startDate: "2026-03-11T08:00:00.000Z", quantity: 75.3 },
      ]),
      fulfilled({ quantity: 42.5 }),
      fulfilled({ quantity: 58 }),
      fulfilled({ sumQuantity: { quantity: 32 } }),
    ];
    const data = buildHealthData(results);
    expect(data.steps).toBe(8433);
    expect(data.heartRate).toBe(72);
    expect(data.activeEnergy).toBe(313);
    expect(data.walkingDistance).toBe(5.68);
    expect(data.sleepHours).toBe(8);
    expect(data.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(data.wakeTime).toBe("2026-03-15T07:00:00.000Z");
    // No source on test samples, so groups under "Unknown"
    expect(data.sleepBySource).toEqual({
      Unknown: {
        bedtime: "2026-03-14T23:00:00.000Z",
        wakeTime: "2026-03-15T07:00:00.000Z",
        coreHours: 0, deepHours: 0, remHours: 0, awakeHours: 0,
      },
    });
    expect(data.weight).toBe(75.5);
    expect(data.weightDaysLast7).toBe(3);
    expect(data.meditationMinutes).toBe(15);
    expect(data.hrv).toBe(42.5);
    expect(data.restingHeartRate).toBe(58);
    expect(data.exerciseMinutes).toBe(32);
  });

  it("returns null heartRate when value is null (no recent sample)", () => {
    const results: HealthQueryResults = [
      fulfilled({ sumQuantity: { quantity: 100 } }),
      fulfilled(null),
      fulfilled({ sumQuantity: { quantity: 50 } }),
      fulfilled({ sumQuantity: { quantity: 1.0 } }),
      fulfilled([]),
      fulfilled(null),
      fulfilled([]),
      fulfilled([]),
      fulfilled(null),
      fulfilled(null),
      fulfilled({ sumQuantity: { quantity: 0 } }),
    ];
    const data = buildHealthData(results);
    expect(data.heartRate).toBeNull();
    expect(data.sleepHours).toBeNull();
    expect(data.sleepBySource).toBeNull();
    expect(data.weight).toBeNull();
    expect(data.weightDaysLast7).toBeNull();
    expect(data.meditationMinutes).toBeNull();
  });

  it("returns null when sumQuantity is missing (no data, not zero)", () => {
    const results: HealthQueryResults = [
      fulfilled({ sumQuantity: null }),
      rejected(),
      fulfilled({}),
      fulfilled({ sumQuantity: undefined }),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
      rejected(),
    ];
    const data = buildHealthData(results);
    expect(data.steps).toBeNull();
    expect(data.activeEnergy).toBeNull();
    expect(data.walkingDistance).toBeNull();
  });

  it("mixes fulfilled and rejected results correctly", () => {
    const results: HealthQueryResults = [
      fulfilled({ sumQuantity: { quantity: 5000 } }),
      rejected("HealthKit unavailable"),
      fulfilled({ sumQuantity: { quantity: 200 } }),
      rejected("permission denied"),
      fulfilled([
        {
          startDate: "2026-03-15T01:00:00.000Z",
          endDate: "2026-03-15T04:30:00.000Z",
        },
      ]),
      fulfilled({ quantity: 80.123 }),
      rejected("no mindful data"),
      fulfilled([
        { startDate: "2026-03-15T08:00:00.000Z", quantity: 80.123 },
      ]),
      rejected(),
      rejected(),
      rejected(),
    ];
    const data = buildHealthData(results);
    expect(data.steps).toBe(5000);
    expect(data.heartRate).toBeNull();
    expect(data.activeEnergy).toBe(200);
    expect(data.walkingDistance).toBeNull();
    expect(data.sleepHours).toBe(3.5);
    expect(data.sleepBySource).toEqual({
      Unknown: {
        bedtime: "2026-03-15T01:00:00.000Z",
        wakeTime: "2026-03-15T04:30:00.000Z",
        coreHours: 0, deepHours: 0, remHours: 0, awakeHours: 0,
      },
    });
    expect(data.weight).toBe(80.12);
    expect(data.weightDaysLast7).toBe(1);
    expect(data.meditationMinutes).toBeNull();
  });
});

describe("extractWeight", () => {
  it("returns null when no sample", () => {
    expect(extractWeight(null)).toBeNull();
    expect(extractWeight(undefined)).toBeNull();
  });

  it("returns kg when present", () => {
    expect(extractWeight({ quantity: 75.5 })).toBe(75.5);
    expect(extractWeight({ quantity: 80.123 })).toBe(80.12);
  });
});

describe("countWeightDays", () => {
  it("returns null for undefined or empty input", () => {
    expect(countWeightDays(undefined)).toBeNull();
    expect(countWeightDays([])).toBeNull();
  });

  it("counts distinct days from weight samples", () => {
    const samples: WeightSample[] = [
      { startDate: "2026-03-14T08:00:00.000Z", quantity: 75.5 },
      { startDate: "2026-03-14T20:00:00.000Z", quantity: 75.6 }, // same day
      { startDate: "2026-03-13T08:00:00.000Z", quantity: 75.4 },
      { startDate: "2026-03-11T08:00:00.000Z", quantity: 75.3 },
    ];
    expect(countWeightDays(samples)).toBe(3);
  });

  it("returns 1 for a single sample", () => {
    const samples: WeightSample[] = [
      { startDate: "2026-03-14T08:00:00.000Z", quantity: 75.5 },
    ];
    expect(countWeightDays(samples)).toBe(1);
  });
});

describe("calculateMeditationMinutes", () => {
  it("returns null when no sessions", () => {
    expect(calculateMeditationMinutes(undefined)).toBeNull();
    expect(calculateMeditationMinutes([])).toBeNull();
  });

  it("sums multiple sessions to minutes", () => {
    const sessions: MindfulSession[] = [
      {
        startDate: "2026-03-15T08:00:00.000Z",
        endDate: "2026-03-15T08:10:00.000Z", // 10 min
      },
      {
        startDate: "2026-03-15T12:00:00.000Z",
        endDate: "2026-03-15T12:20:00.000Z", // 20 min
      },
    ];
    expect(calculateMeditationMinutes(sessions)).toBe(30);
  });
});
