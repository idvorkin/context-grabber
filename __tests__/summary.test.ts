import { buildSummary, formatTime, formatLocalTime, formatNumber } from "../lib/summary";
import type { HealthData } from "../lib/health";

function makeHealth(overrides: Partial<HealthData> = {}): HealthData {
  return {
    steps: 8241,
    heartRate: 73,
    sleepHours: 7.2,
    bedtime: null,
    wakeTime: null,
    sleepBySource: null,
    activeEnergy: 450,
    walkingDistance: 5.3,
    weight: null,
    weightDaysLast7: null,
    meditationMinutes: null,
    hrv: null,
    restingHeartRate: null,
    exerciseMinutes: null,
    workouts: [],
    ...overrides,
  };
}

describe("buildSummary", () => {
  it("includes all present fields", () => {
    const result = buildSummary(makeHealth(), 142);
    expect(result).toBe("8,241 steps | Slept 7.2hrs | 73 bpm | 450 kcal | 5.3 km | 142 locations");
  });

  it("includes sleep time range when bedtime and wakeTime are present", () => {
    const result = buildSummary(
      makeHealth({
        bedtime: "2026-03-15T23:00:00Z",
        wakeTime: "2026-03-15T06:15:00Z",
      }),
      142
    );
    expect(result).toContain("Slept 7.2hrs (11pm\u20136:15am)");
  });

  it("omits sleep range when bedtime/wakeTime are absent", () => {
    const result = buildSummary(makeHealth(), 0);
    expect(result).toContain("Slept 7.2hrs");
    expect(result).not.toContain("(");
  });

  it("omits steps when null", () => {
    const result = buildSummary(makeHealth({ steps: null }), 10);
    expect(result).not.toContain("steps");
    expect(result).toContain("Slept 7.2hrs");
  });

  it("omits sleep section entirely when sleepHours is null", () => {
    const result = buildSummary(makeHealth({ sleepHours: null }), 5);
    expect(result).not.toContain("Slept");
    expect(result).toContain("8,241 steps");
  });

  it("includes weight and meditation when present", () => {
    const result = buildSummary(makeHealth({ weight: 78.3, meditationMinutes: 15 }), 0);
    expect(result).toContain("173 lbs");
    expect(result).toContain("15 min meditation");
  });

  it("returns empty string when all health data is null and location count is 0", () => {
    const result = buildSummary(
      makeHealth({
        steps: null,
        heartRate: null,
        sleepHours: null,
        activeEnergy: null,
        walkingDistance: null,
      }),
      0
    );
    expect(result).toBe("");
  });

  it("returns only locations when all health data is null but count > 0", () => {
    const result = buildSummary(
      makeHealth({
        steps: null,
        heartRate: null,
        sleepHours: null,
        activeEnergy: null,
        walkingDistance: null,
        weight: null,
        meditationMinutes: null,
      }),
      42
    );
    expect(result).toBe("42 locations");
  });

  it("includes workout breakdown when present", () => {
    const result = buildSummary(makeHealth({
      workouts: [
        { activityType: "Running", durationMinutes: 30, energyBurned: 250, distanceKm: 4.5 },
        { activityType: "Yoga", durationMinutes: 20, energyBurned: null, distanceKm: null },
      ],
    }), 0);
    expect(result).toContain("Running 30min 250kcal 4.5km");
    expect(result).toContain("Yoga 20min");
    expect(result).not.toContain("exercise");
  });

  it("falls back to exercise minutes when no workouts", () => {
    const result = buildSummary(makeHealth({ exerciseMinutes: 45 }), 0);
    expect(result).toContain("45 min exercise");
  });

  it("omits locations when count is 0", () => {
    const result = buildSummary(makeHealth(), 0);
    expect(result).not.toContain("locations");
  });

  it("has no trailing pipe", () => {
    const result = buildSummary(makeHealth(), 142);
    expect(result).not.toMatch(/\|$/);
    expect(result).not.toMatch(/\|\s*$/);
  });
});

describe("formatTime", () => {
  it("formats 11pm", () => {
    expect(formatTime("2026-03-15T23:00:00Z")).toBe("11pm");
  });

  it("formats 6:15am", () => {
    expect(formatTime("2026-03-15T06:15:00Z")).toBe("6:15am");
  });

  it("formats 12pm (noon)", () => {
    expect(formatTime("2026-03-15T12:00:00Z")).toBe("12pm");
  });

  it("formats 12am (midnight)", () => {
    expect(formatTime("2026-03-15T00:00:00Z")).toBe("12am");
  });

  it("formats 1:30pm", () => {
    expect(formatTime("2026-03-15T13:30:00Z")).toBe("1:30pm");
  });
});

describe("formatNumber", () => {
  it("formats 8241 with comma", () => {
    expect(formatNumber(8241)).toBe("8,241");
  });

  it("leaves 100 as-is", () => {
    expect(formatNumber(100)).toBe("100");
  });

  it("formats 1000000 with commas", () => {
    expect(formatNumber(1000000)).toBe("1,000,000");
  });

  it("formats 0", () => {
    expect(formatNumber(0)).toBe("0");
  });
});

describe("formatLocalTime", () => {
  // Lock the test's timezone so local-hour assertions are deterministic across CI
  // environments. The project's users are in PDT / America/Los_Angeles.
  const originalTZ = process.env.TZ;
  beforeAll(() => { process.env.TZ = "America/Los_Angeles"; });
  afterAll(() => { process.env.TZ = originalTZ; });

  it("converts a Thursday-night-in-PDT ISO to the correct local time", () => {
    // 2026-04-24T05:30:00Z is Thu 2026-04-23 22:30 PDT.
    expect(formatLocalTime("2026-04-24T05:30:00.000Z")).toBe("10:30pm");
  });

  it("converts Friday-morning-in-PDT wake time to local time", () => {
    // 2026-04-24T12:19:19Z is Fri 2026-04-24 05:19 PDT.
    expect(formatLocalTime("2026-04-24T12:19:00.000Z")).toBe("5:19am");
  });

  it("renders whole hours without trailing :00", () => {
    // Midnight UTC = 5pm PDT previous day.
    expect(formatLocalTime("2026-04-24T00:00:00.000Z")).toBe("5pm");
  });

  it("differs from formatTime (which is UTC) for a non-midnight UTC ISO", () => {
    const local = formatLocalTime("2026-04-24T05:30:00.000Z"); // "10:30pm"
    const utc = formatTime("2026-04-24T05:30:00.000Z"); // "5:30am"
    expect(local).not.toBe(utc);
  });
});
