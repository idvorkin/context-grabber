import { dayOfWeek, buildDailyExport, buildSummaryExport, buildWeeklyStats, type WeeklyDataMap } from "../lib/share";
import type { HeartRateDaily } from "../lib/weekly";

describe("dayOfWeek", () => {
  it("returns correct day names", () => {
    expect(dayOfWeek("2026-03-15")).toBe("Sunday");
    expect(dayOfWeek("2026-03-16")).toBe("Monday");
    expect(dayOfWeek("2026-03-09")).toBe("Monday");
    expect(dayOfWeek("2026-03-14")).toBe("Saturday");
  });
});

describe("buildDailyExport", () => {
  const makeData = (overrides?: Partial<WeeklyDataMap>): WeeklyDataMap => {
    const dates = [
      "2026-03-09",
      "2026-03-10",
      "2026-03-11",
      "2026-03-12",
      "2026-03-13",
      "2026-03-14",
      "2026-03-15",
    ];
    return {
      steps: dates.map((d) => ({ date: d, value: null })),
      heartRate: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
      sleep: dates.map((d) => ({ date: d, value: null })),
      activeEnergy: dates.map((d) => ({ date: d, value: null })),
      walkingDistance: dates.map((d) => ({ date: d, value: null })),
      weight: dates.map((d) => ({ date: d, value: null })),
      meditation: dates.map((d) => ({ date: d, value: null })),
      hrv: dates.map((d) => ({ date: d, value: null })),
      restingHeartRate: dates.map((d) => ({ date: d, value: null })),
      exerciseMinutes: dates.map((d) => ({ date: d, value: null })),
      ...overrides,
    };
  };

  it("returns 7 entries with correct dates and day names", () => {
    const result = buildDailyExport(makeData());
    expect(result).toHaveLength(7);
    expect(result[0].date).toBe("2026-03-09");
    expect(result[0].dayOfWeek).toBe("Monday");
    expect(result[6].date).toBe("2026-03-15");
    expect(result[6].dayOfWeek).toBe("Sunday");
  });

  it("returns null for all metrics when data is empty", () => {
    const result = buildDailyExport(makeData());
    for (const entry of result) {
      expect(entry.steps).toBeNull();
      expect(entry.heartRate).toBeNull();
      expect(entry.sleepHours).toBeNull();
      expect(entry.activeEnergy).toBeNull();
      expect(entry.walkingDistanceKm).toBeNull();
      expect(entry.weightKg).toBeNull();
      expect(entry.meditationMinutes).toBeNull();
      expect(entry.hrvMs).toBeNull();
      expect(entry.restingHeartRate).toBeNull();
      expect(entry.exerciseMinutes).toBeNull();
    }
  });

  it("maps step values correctly", () => {
    const dates = [
      "2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12",
      "2026-03-13", "2026-03-14", "2026-03-15",
    ];
    const steps = dates.map((d, i) => ({ date: d, value: i === 6 ? 8432 : null }));
    const result = buildDailyExport(makeData({ steps }));
    expect(result[6].steps).toBe(8432);
    expect(result[0].steps).toBeNull();
  });

  it("maps heart rate data correctly", () => {
    const dates = [
      "2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12",
      "2026-03-13", "2026-03-14", "2026-03-15",
    ];
    const heartRate: HeartRateDaily[] = dates.map((d, i) =>
      i === 6
        ? { date: d, avg: 72, min: 55, max: 120, q1: 60, median: 70, q3: 85, count: 10, raw: [{value:55,time:"T"},{value:60,time:"T"},{value:70,time:"T"},{value:85,time:"T"},{value:120,time:"T"}] }
        : { date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] }
    );
    const result = buildDailyExport(makeData({ heartRate }));
    expect(result[6].heartRate).toEqual({ avg: 72, min: 55, max: 120 });
    expect(result[0].heartRate).toBeNull();
  });

  it("maps all metric types into a single entry", () => {
    const dates = [
      "2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12",
      "2026-03-13", "2026-03-14", "2026-03-15",
    ];
    const data = makeData({
      steps: dates.map((d, i) => ({ date: d, value: i === 6 ? 10000 : null })),
      sleep: dates.map((d, i) => ({ date: d, value: i === 6 ? 7.5 : null })),
      activeEnergy: dates.map((d, i) => ({ date: d, value: i === 6 ? 350 : null })),
      walkingDistance: dates.map((d, i) => ({ date: d, value: i === 6 ? 5.2 : null })),
      weight: dates.map((d, i) => ({ date: d, value: i === 6 ? 75.5 : null })),
      meditation: dates.map((d, i) => ({ date: d, value: i === 6 ? 15 : null })),
    });
    const result = buildDailyExport(data);
    const today = result[6];
    expect(today.steps).toBe(10000);
    expect(today.sleepHours).toBe(7.5);
    expect(today.activeEnergy).toBe(350);
    expect(today.walkingDistanceKm).toBe(5.2);
    expect(today.weightKg).toBe(75.5);
    expect(today.meditationMinutes).toBe(15);
  });

  it("does not include location data", () => {
    const result = buildDailyExport(makeData());
    for (const entry of result) {
      expect(entry).not.toHaveProperty("location");
      expect(entry).not.toHaveProperty("locationHistory");
    }
  });
});

describe("buildWeeklyStats", () => {
  const dates = [
    "2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12",
    "2026-03-13", "2026-03-14", "2026-03-15",
  ];

  const makeData = (overrides?: Partial<WeeklyDataMap>): WeeklyDataMap => ({
    steps: dates.map((d) => ({ date: d, value: null })),
    heartRate: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
    sleep: dates.map((d) => ({ date: d, value: null })),
    activeEnergy: dates.map((d) => ({ date: d, value: null })),
    walkingDistance: dates.map((d) => ({ date: d, value: null })),
    weight: dates.map((d) => ({ date: d, value: null })),
    meditation: dates.map((d) => ({ date: d, value: null })),
    hrv: dates.map((d) => ({ date: d, value: null })),
    restingHeartRate: dates.map((d) => ({ date: d, value: null })),
    exerciseMinutes: dates.map((d) => ({ date: d, value: null })),
    ...overrides,
  });

  it("returns null stats when all values are null", () => {
    const stats = buildWeeklyStats(makeData());
    expect(stats.steps).toBeNull();
    expect(stats.heartRate).toBeNull();
    expect(stats.sleepHours).toBeNull();
    expect(stats.activeEnergy).toBeNull();
    expect(stats.walkingDistanceKm).toBeNull();
    expect(stats.weightKg).toBeNull();
    expect(stats.meditationMinutes).toBeNull();
    expect(stats.hrvMs).toBeNull();
    expect(stats.restingHeartRate).toBeNull();
    expect(stats.exerciseMinutes).toBeNull();
  });

  it("computes stats for steps with data", () => {
    const steps = dates.map((d, i) => ({
      date: d,
      value: [5000, 8000, 12000, 7500, 9000, 6000, 11000][i],
    }));
    const stats = buildWeeklyStats(makeData({ steps }));
    expect(stats.steps).not.toBeNull();
    expect(stats.steps!.min).toBe(5000);
    expect(stats.steps!.max).toBe(12000);
    expect(stats.steps!.p50).toBe(8000);
    // Stats export should not have a values array
    expect(stats.steps).not.toHaveProperty("values");
  });

  it("computes stats for heart rate using avg values", () => {
    const heartRate: HeartRateDaily[] = dates.map((d, i) => ({
      date: d,
      avg: [65, 70, 72, 68, 75, 71, 69][i],
      min: 50,
      max: 120,
      q1: 60,
      median: [65, 70, 72, 68, 75, 71, 69][i],
      q3: 85,
      count: 10,
      raw: [],
    }));
    const stats = buildWeeklyStats(makeData({ heartRate }));
    expect(stats.heartRate).not.toBeNull();
    expect(stats.heartRate!.p50).toBe(70);
  });
});

describe("buildSummaryExport", () => {
  const dates = [
    "2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12",
    "2026-03-13", "2026-03-14", "2026-03-15",
  ];

  const makeData = (): WeeklyDataMap => ({
    steps: dates.map((d) => ({ date: d, value: null })),
    heartRate: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
    sleep: dates.map((d) => ({ date: d, value: null })),
    activeEnergy: dates.map((d) => ({ date: d, value: null })),
    walkingDistance: dates.map((d) => ({ date: d, value: null })),
    weight: dates.map((d) => ({ date: d, value: null })),
    meditation: dates.map((d) => ({ date: d, value: null })),
    hrv: dates.map((d) => ({ date: d, value: null })),
    restingHeartRate: dates.map((d) => ({ date: d, value: null })),
    exerciseMinutes: dates.map((d) => ({ date: d, value: null })),
  });

  it("includes weeklyStats in export", () => {
    const result = buildSummaryExport(makeData(), null);
    expect(result).toHaveProperty("days");
    expect(result).toHaveProperty("weeklyStats");
    expect(result).toHaveProperty("locationSummary");
  });
});
