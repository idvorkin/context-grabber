import { dayOfWeek, buildDailyExport, buildSummaryExport, buildTodayHeadline, buildWeeklyStats, type WeeklyDataMap } from "../lib/share";
import type { HealthData } from "../lib/health";
import type { HeartRateDaily } from "../lib/weekly";

const EMPTY_HEALTH: HealthData = {
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
  workouts: [],
};

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
      hrv: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
      restingHeartRate: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
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
      expect(entry.weightLbs).toBeNull();
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

  it("maps HRV and resting heart rate using avg from HeartRateDaily", () => {
    const dates = [
      "2026-03-09", "2026-03-10", "2026-03-11", "2026-03-12",
      "2026-03-13", "2026-03-14", "2026-03-15",
    ];
    const hrv: HeartRateDaily[] = dates.map((d, i) =>
      i === 6
        ? { date: d, avg: 42, min: 30, max: 65, q1: 35, median: 42, q3: 50, count: 5, raw: [] }
        : { date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] }
    );
    const restingHeartRate: HeartRateDaily[] = dates.map((d, i) =>
      i === 6
        ? { date: d, avg: 58, min: 55, max: 62, q1: 56, median: 58, q3: 60, count: 5, raw: [] }
        : { date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] }
    );
    const result = buildDailyExport(makeData({ hrv, restingHeartRate }));
    expect(result[6].hrvMs).toBe(42);
    expect(result[6].restingHeartRate).toBe(58);
    expect(result[0].hrvMs).toBeNull();
    expect(result[0].restingHeartRate).toBeNull();
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
      weight: dates.map((d, i) => ({ date: d, value: i === 6 ? 166 : null })),
      meditation: dates.map((d, i) => ({ date: d, value: i === 6 ? 15 : null })),
    });
    const result = buildDailyExport(data);
    const today = result[6];
    expect(today.steps).toBe(10000);
    expect(today.sleepHours).toBe(7.5);
    expect(today.activeEnergy).toBe(350);
    expect(today.walkingDistanceKm).toBe(5.2);
    expect(today.weightLbs).toBe(166);
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
    hrv: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
    restingHeartRate: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
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
    expect(stats.weightLbs).toBeNull();
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

  it("computes stats for HRV and resting heart rate using avg values", () => {
    const hrv: HeartRateDaily[] = dates.map((d, i) => ({
      date: d,
      avg: [35, 40, 42, 38, 45, 41, 39][i],
      min: 20, max: 60, q1: 30, median: [35, 40, 42, 38, 45, 41, 39][i], q3: 50, count: 5, raw: [],
    }));
    const restingHeartRate: HeartRateDaily[] = dates.map((d, i) => ({
      date: d,
      avg: [55, 58, 60, 57, 62, 59, 56][i],
      min: 50, max: 70, q1: 53, median: [55, 58, 60, 57, 62, 59, 56][i], q3: 65, count: 5, raw: [],
    }));
    const stats = buildWeeklyStats(makeData({ hrv, restingHeartRate }));
    expect(stats.hrvMs).not.toBeNull();
    expect(stats.hrvMs!.p50).toBe(40);
    expect(stats.restingHeartRate).not.toBeNull();
    expect(stats.restingHeartRate!.p50).toBe(58);
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
    hrv: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
    restingHeartRate: dates.map((d) => ({ date: d, avg: null, min: null, max: null, q1: null, median: null, q3: null, count: 0, raw: [] })),
    exerciseMinutes: dates.map((d) => ({ date: d, value: null })),
  });

  it("returns today + days + places, no weeklyStats, no locationSummary", () => {
    const result = buildSummaryExport(makeData(), EMPTY_HEALTH, null);
    expect(result).toHaveProperty("today");
    expect(result).toHaveProperty("days");
    expect(result).toHaveProperty("places");
    expect(result).not.toHaveProperty("weeklyStats");
    expect(result).not.toHaveProperty("locationSummary");
    expect(result).not.toHaveProperty("todayWorkouts");
    expect(result.days).toHaveLength(7);
  });

  it("today headline uses the last date in the 7-day window", () => {
    const result = buildSummaryExport(makeData(), EMPTY_HEALTH, null);
    expect(result.today.date).toBe("2026-03-15");
    expect(result.today.dayOfWeek).toBe("Sunday");
  });

  it("places summary is null when caller passes null (empty location history)", () => {
    const result = buildSummaryExport(makeData(), EMPTY_HEALTH, null);
    expect(result.places).toBeNull();
  });

  it("surfaces PlacesSummary text blocks when caller provides them", () => {
    const result = buildSummaryExport(makeData(), EMPTY_HEALTH, {
      weekly: "This week: Home 92h, Office 28h",
      recent: "Mon Mar 15: Home 10pm–7am (9h)",
    });
    expect(result.places?.weekly).toContain("Home 92h");
    expect(result.places?.recent).toContain("10pm–7am");
  });

  it("exported JSON contains no lat/lng, coordinates, or unix timestamps", () => {
    // The whole point of the trim — verify by stringifying and grepping for
    // forbidden key names.
    const health: HealthData = {
      ...EMPTY_HEALTH,
      steps: 8241,
      heartRate: 72,
      sleepHours: 7.5,
      bedtime: "2026-03-14T06:00:00Z", // 11pm local in Pacific
      wakeTime: "2026-03-15T14:30:00Z",
      weight: 75, // kg
    };
    const result = buildSummaryExport(makeData(), health, {
      weekly: "This week: Home 92h",
      recent: "Sun Mar 15: Home all day",
    });
    const json = JSON.stringify(result);
    expect(json).not.toContain("latitude");
    expect(json).not.toContain("longitude");
    expect(json).not.toContain("radiusMeters");
    expect(json).not.toContain("firstVisit");
    expect(json).not.toContain("lastVisit");
    expect(json).not.toContain("pointCount");
    expect(json).not.toContain("weeklyStats");
  });

  it("today headline converts weight kg → lbs and formats bedtime/wake times", () => {
    const health: HealthData = {
      ...EMPTY_HEALTH,
      weight: 75, // 75 kg → 165 lbs
      bedtime: "2026-03-15T06:00:00Z", // 6:00 UTC
      wakeTime: "2026-03-15T14:30:00Z", // 14:30 UTC
    };
    const today = buildTodayHeadline(health, "2026-03-15");
    expect(today.weightLbs).toBe(165);
    // formatTime uses UTC — 06:00 → "6am", 14:30 → "2:30pm"
    expect(today.bedtime).toBe("6am");
    expect(today.wakeTime).toBe("2:30pm");
  });
});
