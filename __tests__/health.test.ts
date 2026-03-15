import {
  calculateSleepHours,
  calculateMeditationMinutes,
  extractWeight,
  buildHealthData,
  type SleepSample,
  type MindfulSession,
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

  it("returns 0 when start equals end", () => {
    const samples: SleepSample[] = [
      {
        startDate: "2026-03-15T00:00:00.000Z",
        endDate: "2026-03-15T00:00:00.000Z",
      },
    ];
    expect(calculateSleepHours(samples)).toBe(0);
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
    ];
    expect(buildHealthData(results)).toEqual({
      steps: null,
      heartRate: null,
      sleepHours: null,
      bedtime: null,
      wakeTime: null,
      activeEnergy: null,
      walkingDistance: null,
      weight: null,
      meditationMinutes: null,
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
    ];
    const data = buildHealthData(results);
    expect(data.steps).toBe(8433);
    expect(data.heartRate).toBe(72);
    expect(data.activeEnergy).toBe(313);
    expect(data.walkingDistance).toBe(5.68);
    expect(data.sleepHours).toBe(8);
    expect(data.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(data.wakeTime).toBe("2026-03-15T07:00:00.000Z");
    expect(data.weight).toBe(75.5);
    expect(data.meditationMinutes).toBe(15);
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
    ];
    const data = buildHealthData(results);
    expect(data.heartRate).toBeNull();
    expect(data.sleepHours).toBeNull();
    expect(data.weight).toBeNull();
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
    ];
    const data = buildHealthData(results);
    expect(data.steps).toBe(5000);
    expect(data.heartRate).toBeNull();
    expect(data.activeEnergy).toBe(200);
    expect(data.walkingDistance).toBeNull();
    expect(data.sleepHours).toBe(3.5);
    expect(data.weight).toBe(80.12);
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
