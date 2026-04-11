import {
  buildPlacesDailySummary,
  splitUncovered,
  type PlaceDaySummary,
} from "../lib/places_summary";
import type { Stay, TransitSegment } from "../lib/clustering_v2";
import type { LocationPoint } from "../lib/clustering";

function makeStay(placeId: string, startTime: number, durationMinutes: number): Stay {
  return {
    placeId,
    centroid: { latitude: 47.6, longitude: -122.3 },
    startTime,
    endTime: startTime + durationMinutes * 60 * 1000,
    durationMinutes,
    pointCount: 10,
  };
}

function makeTransit(startTime: number, durationMinutes: number): TransitSegment {
  return {
    startTime,
    endTime: startTime + durationMinutes * 60 * 1000,
    durationMinutes,
    distanceKm: 1,
    fromPlaceId: "A",
    toPlaceId: "B",
  };
}

function makePoint(ts: number): LocationPoint {
  return { latitude: 47.6, longitude: -122.3, accuracy: 20, timestamp: ts };
}

// Local midnight of a given date; set time to 12pm so "now" arg is unambiguously later
function localMidnight(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 0, 0, 0, 0).getTime();
}

function localNoon(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 12, 0, 0, 0).getTime();
}

// End-of-day "now" for tests that want a full day elapsed
function localEndOfDay(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 23, 59, 59, 999).getTime();
}

const MIN = 60 * 1000;
const DAY_MS_TEST = 24 * 60 * 60 * 1000;

describe("buildPlacesDailySummary", () => {
  test("empty stays returns empty result (no raw points either)", () => {
    expect(buildPlacesDailySummary([], [], [], 7, localNoon("2026-03-15"))).toEqual([]);
  });

  test("single day with multiple places sorted by duration", () => {
    const base = localMidnight("2026-03-15") + 8 * 60 * MIN; // 8am
    const stays: Stay[] = [
      makeStay("Home", base, 120),
      makeStay("Office", base + 3 * 60 * MIN, 60),
      makeStay("Cafe", base + 5 * 60 * MIN, 180),
    ];

    const result = buildPlacesDailySummary(stays, [], [], 7, localEndOfDay("2026-03-15"));
    expect(result.length).toBeGreaterThanOrEqual(1);
    const today = result.find((d) => d.dateKey === "2026-03-15")!;
    expect(today).toBeDefined();
    // Sorted by duration desc: Cafe (180), Home (120), Office (60)
    expect(today.places[0].placeId).toBe("Cafe");
    expect(today.places[0].totalMinutes).toBe(180);
    expect(today.places[1].placeId).toBe("Home");
    expect(today.places[1].totalMinutes).toBe(120);
    expect(today.places[2].placeId).toBe("Office");
    expect(today.places[2].totalMinutes).toBe(60);
    expect(today.totalStayMinutes).toBe(360);
  });

  test("multiple days sorted by date descending", () => {
    const stays: Stay[] = [
      makeStay("Home", localMidnight("2026-03-13") + 60 * MIN, 60),
      makeStay("Home", localMidnight("2026-03-15") + 60 * MIN, 90),
      makeStay("Home", localMidnight("2026-03-14") + 60 * MIN, 120),
    ];

    const result = buildPlacesDailySummary(stays, [], [], 7, localNoon("2026-03-15"));
    // Dates present (skip pure-empty-no-data days)
    const dateKeys = result.map((d) => d.dateKey);
    expect(dateKeys[0]).toBe("2026-03-15"); // most recent first
    expect(dateKeys).toContain("2026-03-14");
    expect(dateKeys).toContain("2026-03-13");
  });

  test("respects days limit", () => {
    const stays: Stay[] = [];
    for (let i = 10; i <= 14; i++) {
      stays.push(makeStay("Home", localMidnight(`2026-03-${i}`) + 60 * MIN, 60));
    }

    const result = buildPlacesDailySummary(stays, [], [], 3, localNoon("2026-03-14"));
    const dateKeys = result.map((d) => d.dateKey);
    expect(dateKeys[0]).toBe("2026-03-14");
    expect(dateKeys.length).toBeLessThanOrEqual(3);
    // 2026-03-10 and -11 should not appear since they're outside the 3-day window
    expect(dateKeys).not.toContain("2026-03-10");
    expect(dateKeys).not.toContain("2026-03-11");
  });

  test("top 10 places limit enforced", () => {
    const base = localMidnight("2026-03-15") + 60 * MIN;
    const stays: Stay[] = [];
    for (let i = 0; i < 15; i++) {
      stays.push(makeStay(`Place ${i}`, base + i * 10 * MIN, (15 - i) * 10));
    }

    const result = buildPlacesDailySummary(stays, [], [], 7, localNoon("2026-03-15"));
    const today = result.find((d) => d.dateKey === "2026-03-15")!;
    expect(today.places.length).toBe(10);
    expect(today.places[0].totalMinutes).toBeGreaterThanOrEqual(today.places[9].totalMinutes);
  });

  test("same place across multiple stays on same day gets summed", () => {
    const base = localMidnight("2026-03-15") + 60 * MIN;
    const stays: Stay[] = [
      makeStay("Home", base, 60),
      makeStay("Office", base + 2 * 60 * MIN, 30),
      makeStay("Home", base + 3 * 60 * MIN, 90),
    ];

    const result = buildPlacesDailySummary(stays, [], [], 7, localNoon("2026-03-15"));
    const today = result.find((d) => d.dateKey === "2026-03-15")!;
    expect(today.places[0].placeId).toBe("Home");
    expect(today.places[0].totalMinutes).toBe(150); // 60 + 90
    expect(today.places[1].placeId).toBe("Office");
    expect(today.places[1].totalMinutes).toBe(30);
  });

  test("single stay, zero transit, zero points → full remainder is no-data", () => {
    // 2h stay mid-day, nothing else. "Now" = 6pm same day → elapsed = 18h.
    const base = localMidnight("2026-03-15") + 10 * 60 * MIN; // 10am
    const now = localMidnight("2026-03-15") + 18 * 60 * MIN; // 6pm
    const result = buildPlacesDailySummary([makeStay("Home", base, 120)], [], [], 1, now);
    expect(result).toHaveLength(1);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(120);
    expect(d.transitMinutes).toBe(0);
    expect(d.looseMinutes).toBe(0);
    // elapsed = 18h = 1080 min; stay = 120 min; rest = 960 min no-data
    expect(d.noDataMinutes).toBe(960);
    expect(d.totalStayMinutes + d.transitMinutes + d.looseMinutes + d.noDataMinutes).toBe(
      18 * 60,
    );
  });

  test("stay crossing midnight contributes to both days", () => {
    // Stay from 10pm Mar 14 to 8am Mar 15 = 10h, split 2h into Mar 14 + 8h into Mar 15
    const start = localMidnight("2026-03-14") + 22 * 60 * MIN;
    const end = localMidnight("2026-03-15") + 8 * 60 * MIN;
    const stay: Stay = {
      placeId: "Home",
      centroid: { latitude: 47.6, longitude: -122.3 },
      startTime: start,
      endTime: end,
      durationMinutes: 600,
      pointCount: 20,
    };

    const result = buildPlacesDailySummary([stay], [], [], 2, localNoon("2026-03-15"));
    const mar14 = result.find((d) => d.dateKey === "2026-03-14")!;
    const mar15 = result.find((d) => d.dateKey === "2026-03-15")!;
    expect(mar14).toBeDefined();
    expect(mar15).toBeDefined();
    expect(mar14.totalStayMinutes).toBe(120); // 10pm→midnight = 2h
    expect(mar15.totalStayMinutes).toBe(480); // midnight→8am = 8h
  });

  test("transit segment contributes to transitMinutes", () => {
    const base = localMidnight("2026-03-15") + 9 * 60 * MIN;
    const now = localMidnight("2026-03-15") + 11 * 60 * MIN; // 11am = 11h elapsed
    const stays = [makeStay("Home", base, 30)]; // 9:00–9:30
    const transit = [makeTransit(base + 30 * MIN, 30)]; // 9:30–10:00
    const result = buildPlacesDailySummary(stays, transit, [], 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(30);
    expect(d.transitMinutes).toBe(30);
    expect(d.totalStayMinutes + d.transitMinutes + d.looseMinutes + d.noDataMinutes).toBe(
      11 * 60,
    );
  });

  test("loose classification: scattered points in uncovered window → looseMinutes", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 6 * 60 * MIN; // 6h elapsed
    // One 1h stay from 00:00–01:00. Then 8 points from 02:00–02:40 at 5-min intervals.
    const stays = [makeStay("Home", dayStart, 60)];
    const points: LocationPoint[] = [];
    for (let i = 0; i < 9; i++) {
      points.push(makePoint(dayStart + 120 * MIN + i * 5 * MIN));
    }

    const result = buildPlacesDailySummary(stays, [], points, 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(60);
    expect(d.transitMinutes).toBe(0);
    // Points span 02:00–02:40 = 40 min of loose run, + 5min half-window on each side = 50 min
    expect(d.looseMinutes).toBeGreaterThanOrEqual(45);
    expect(d.looseMinutes).toBeLessThanOrEqual(55);
    // Total invariant holds
    expect(d.totalStayMinutes + d.transitMinutes + d.looseMinutes + d.noDataMinutes).toBe(
      6 * 60,
    );
  });

  test("no-data classification: stay + silence → noDataMinutes fills gap", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 4 * 60 * MIN; // 4h elapsed
    const stays = [makeStay("Home", dayStart, 60)]; // 00:00–01:00
    const result = buildPlacesDailySummary(stays, [], [], 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(60);
    expect(d.looseMinutes).toBe(0);
    expect(d.noDataMinutes).toBe(180); // 4h - 1h
  });

  test("mixed: stay + loose cluster + silence → split correctly", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 10 * 60 * MIN; // 10h elapsed
    // Stay: 00:00–02:00 (2h)
    // Loose cluster of points: 04:00–04:20 (8 points, 3 min apart)
    // Silence: rest
    const stays = [makeStay("Home", dayStart, 120)];
    const points: LocationPoint[] = [];
    for (let i = 0; i <= 6; i++) {
      points.push(makePoint(dayStart + 240 * MIN + i * 3 * MIN));
    }

    const result = buildPlacesDailySummary(stays, [], points, 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(120);
    // 18 min of points + 5 min on each side = ~28 min loose
    expect(d.looseMinutes).toBeGreaterThanOrEqual(25);
    expect(d.looseMinutes).toBeLessThanOrEqual(32);
    expect(d.totalStayMinutes + d.transitMinutes + d.looseMinutes + d.noDataMinutes).toBe(
      10 * 60,
    );
  });

  test("single orphan point in long silence → ~10m loose, rest no-data", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 6 * 60 * MIN;
    const points = [makePoint(dayStart + 180 * MIN)]; // single point at 03:00
    const result = buildPlacesDailySummary([], [], points, 1, now);
    const d = result[0];
    expect(d.looseMinutes).toBeGreaterThanOrEqual(9);
    expect(d.looseMinutes).toBeLessThanOrEqual(11);
    expect(d.noDataMinutes).toBe(6 * 60 - d.looseMinutes);
  });

  test("today's day is truncated at now, not full 24h", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 6 * 60 * MIN; // 6h elapsed
    const stays = [makeStay("Home", dayStart, 120)]; // 2h stay
    const result = buildPlacesDailySummary(stays, [], [], 1, now);
    const d = result[0];
    expect(d.noDataMinutes).toBe(240); // 6h - 2h = 4h, not 22h
  });

  test("invariant holds under rounding drift", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = localEndOfDay("2026-03-15");
    // Weird offsets to trigger rounding
    const stays = [
      makeStay("Home", dayStart + 17_000, 37),
      makeStay("Work", dayStart + 23_400_000, 143),
    ];
    const transit = [makeTransit(dayStart + 37 * MIN + 17_000, 29)];
    const points: LocationPoint[] = [];
    for (let i = 0; i < 20; i++) {
      points.push(makePoint(dayStart + 90 * 60 * MIN + i * 7 * MIN));
    }

    const result = buildPlacesDailySummary(stays, transit, points, 1, now);
    const d = result[0];
    const sum = d.totalStayMinutes + d.transitMinutes + d.looseMinutes + d.noDataMinutes;
    expect(Math.abs(sum - 1440)).toBeLessThanOrEqual(1);
  });
});

describe("splitUncovered", () => {
  test("no points → all no-data", () => {
    const r = splitUncovered([{ start: 0, end: 60 * MIN }], []);
    expect(r.looseMs).toBe(0);
    expect(r.noDataMs).toBe(60 * MIN);
  });

  test("single point → 10 minute loose window", () => {
    const r = splitUncovered([{ start: 0, end: 60 * MIN }], [makePoint(30 * MIN)]);
    expect(r.looseMs).toBe(10 * MIN); // ±5 min
    expect(r.noDataMs).toBe(50 * MIN);
  });

  test("points <10min apart merge into single run", () => {
    const pts = [makePoint(20 * MIN), makePoint(28 * MIN), makePoint(35 * MIN)];
    const r = splitUncovered([{ start: 0, end: 60 * MIN }], pts);
    // Run spans 20→35 = 15 min; +5 each side = 25 min
    expect(r.looseMs).toBe(25 * MIN);
  });

  test("points >10min apart are separate runs", () => {
    const pts = [makePoint(10 * MIN), makePoint(30 * MIN)]; // 20 min gap
    const r = splitUncovered([{ start: 0, end: 60 * MIN }], pts);
    // Two runs, each 10 min wide
    expect(r.looseMs).toBe(20 * MIN);
  });

  test("loose segment clipped at interval boundary", () => {
    // Point at time 2 with ±5min window → [−3, 7]; interval starts at 0 → loose = 7
    const r = splitUncovered([{ start: 0, end: 60 * MIN }], [makePoint(2 * MIN)]);
    expect(r.looseMs).toBe(7 * MIN);
  });
});
