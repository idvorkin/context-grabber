import {
  buildPlacesDailySummary,
  formatPlacesDailyText,
  splitNonStay,
  segmentNonStay,
} from "../lib/places_summary";
import type { PlaceDaySummary } from "../lib/places_summary";
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

function localMidnight(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 0, 0, 0, 0).getTime();
}

function localNoon(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 12, 0, 0, 0).getTime();
}

function localEndOfDay(dateStr: string): number {
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d, 23, 59, 59, 999).getTime();
}

const MIN = 60 * 1000;

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
    const today = result.find((d) => d.dateKey === "2026-03-15")!;
    expect(today).toBeDefined();
    expect(today.places[0].placeId).toBe("Cafe");
    expect(today.places[0].totalMinutes).toBe(180);
    expect(today.places[1].placeId).toBe("Home");
    expect(today.places[1].totalMinutes).toBe(120);
    expect(today.places[2].placeId).toBe("Office");
    expect(today.places[2].totalMinutes).toBe(60);
    expect(today.totalStayMinutes).toBe(360);
  });

  test("day header elapsedMinutes = 24h for past days", () => {
    const stays = [makeStay("Home", localMidnight("2026-03-14") + 60 * MIN, 60)];
    const result = buildPlacesDailySummary(stays, [], [], 7, localNoon("2026-03-15"));
    const past = result.find((d) => d.dateKey === "2026-03-14")!;
    expect(past.elapsedMinutes).toBe(1440);
  });

  test("day header elapsedMinutes = (now - dayStart) for today", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 6 * 60 * MIN; // 6am
    const stays = [makeStay("Home", dayStart, 60)];
    const result = buildPlacesDailySummary(stays, [], [], 1, now);
    expect(result[0].elapsedMinutes).toBe(360);
  });

  test("multiple days sorted by date descending", () => {
    const stays: Stay[] = [
      makeStay("Home", localMidnight("2026-03-13") + 60 * MIN, 60),
      makeStay("Home", localMidnight("2026-03-15") + 60 * MIN, 90),
      makeStay("Home", localMidnight("2026-03-14") + 60 * MIN, 120),
    ];

    const result = buildPlacesDailySummary(stays, [], [], 7, localNoon("2026-03-15"));
    const dateKeys = result.map((d) => d.dateKey);
    expect(dateKeys[0]).toBe("2026-03-15");
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
    expect(dateKeys).not.toContain("2026-03-10");
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
    expect(today.places[0].totalMinutes).toBe(150);
    expect(today.places[1].placeId).toBe("Office");
    expect(today.places[1].totalMinutes).toBe(30);
  });

  test("single stay, zero points → all non-stay is no-data", () => {
    const base = localMidnight("2026-03-15") + 10 * 60 * MIN;
    const now = localMidnight("2026-03-15") + 18 * 60 * MIN; // 18h elapsed
    const result = buildPlacesDailySummary([makeStay("Home", base, 120)], [], [], 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(120);
    expect(d.transitMinutes).toBe(0);
    expect(d.noDataMinutes).toBe(960); // 18*60 - 120
    expect(d.totalStayMinutes + d.transitMinutes + d.noDataMinutes).toBe(d.elapsedMinutes);
  });

  test("stay crossing midnight contributes to both days", () => {
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
    expect(mar14.totalStayMinutes).toBe(120);
    expect(mar15.totalStayMinutes).toBe(480);
  });

  // ─── Transit fix tests ────────────────────────────────────────────────────

  test("BUG FIX: overnight gap with no points → no-data, NOT transit", () => {
    // Home stay 0:00–1:00, Coffee stay 9:00–9:30. Gap of 8h with NO raw points.
    // Pre-fix: clustering's TransitSegment would label the 8h gap as transit.
    // Post-fix: should be no-data because there are no GPS points to evidence movement.
    const dayStart = localMidnight("2026-03-15");
    const now = localMidnight("2026-03-15") + 10 * 60 * MIN; // 10h elapsed
    const stays = [
      makeStay("Home", dayStart, 60),
      makeStay("Coffee", dayStart + 9 * 60 * MIN, 30),
    ];
    const transit = [
      // What clustering would produce — should be ignored by buildPlacesDailySummary
      makeTransit(dayStart + 60 * MIN, 8 * 60),
    ];
    const result = buildPlacesDailySummary(stays, transit, [], 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(90);
    expect(d.transitMinutes).toBe(0);
    expect(d.noDataMinutes).toBe(d.elapsedMinutes - 90);
  });

  test("BUG FIX: drive between stays with steady GPS → transit, NOT no-data", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 4 * 60 * MIN;
    const stays = [
      makeStay("Home", dayStart, 60), // 0:00–1:00
      makeStay("Work", dayStart + 2 * 60 * MIN, 60), // 2:00–3:00
    ];
    // 1h gap (1:00–2:00) with GPS pings every 5 min
    const points: LocationPoint[] = [];
    for (let t = 60 * MIN; t <= 120 * MIN; t += 5 * MIN) {
      points.push(makePoint(dayStart + t));
    }
    const result = buildPlacesDailySummary(stays, [], points, 1, now);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(120);
    // Whole 1h gap should be transit (covered by GPS pings)
    expect(d.transitMinutes).toBeGreaterThanOrEqual(58);
    expect(d.transitMinutes).toBeLessThanOrEqual(62);
  });

  test("BUG FIX: 2h gap with one stray point → ~10 min transit, rest no-data", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 5 * 60 * MIN;
    const stays = [
      makeStay("A", dayStart, 60),
      makeStay("B", dayStart + 3 * 60 * MIN, 60),
    ];
    // 2h gap (1:00–3:00); ONE stray point at 2:00
    const points = [makePoint(dayStart + 2 * 60 * MIN)];
    const result = buildPlacesDailySummary(stays, [], points, 1, now);
    const d = result[0];
    // Single point → 10 min transit window (±5 min)
    expect(d.transitMinutes).toBeGreaterThanOrEqual(8);
    expect(d.transitMinutes).toBeLessThanOrEqual(12);
    // Rest of the gap is no-data
    expect(d.noDataMinutes).toBeGreaterThanOrEqual(108);
  });

  test("today's day truncated at now", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 6 * 60 * MIN;
    const stays = [makeStay("Home", dayStart, 120)];
    const result = buildPlacesDailySummary(stays, [], [], 1, now);
    const d = result[0];
    expect(d.elapsedMinutes).toBe(360);
    expect(d.noDataMinutes).toBe(240); // 6h - 2h, not 22h
  });

  test("invariant holds for all days", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = localEndOfDay("2026-03-15");
    const stays = [
      makeStay("Home", dayStart + 17_000, 37),
      makeStay("Work", dayStart + 23_400_000, 143),
    ];
    const points: LocationPoint[] = [];
    for (let i = 0; i < 20; i++) {
      points.push(makePoint(dayStart + 90 * 60 * MIN + i * 7 * MIN));
    }
    const result = buildPlacesDailySummary(stays, [], points, 1, now);
    const d = result[0];
    const sum = d.totalStayMinutes + d.transitMinutes + d.noDataMinutes;
    expect(Math.abs(sum - d.elapsedMinutes)).toBeLessThanOrEqual(1);
  });

  test("day with only raw points (no stays) shows transit/no-data", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 4 * 60 * MIN;
    const points: LocationPoint[] = [];
    for (let i = 0; i < 5; i++) {
      points.push(makePoint(dayStart + 60 * MIN + i * 3 * MIN));
    }
    const result = buildPlacesDailySummary([], [], points, 1, now);
    expect(result).toHaveLength(1);
    const d = result[0];
    expect(d.totalStayMinutes).toBe(0);
    // Points span 0:60–0:72 = 12 min run, +5 each side = 22 min transit
    expect(d.transitMinutes).toBeGreaterThanOrEqual(20);
    expect(d.transitMinutes).toBeLessThanOrEqual(24);
  });
});

describe("stripSegments", () => {
  const DAY_MS = 24 * 60 * 60 * 1000;

  test("past day with one stay covers full 24h, no future segment", () => {
    const dayStart = localMidnight("2026-03-14");
    const stays = [makeStay("Home", dayStart + 8 * 60 * MIN, 60)]; // 8am-9am
    const result = buildPlacesDailySummary(stays, [], [], 2, localNoon("2026-03-15"));
    const d = result.find((x) => x.dateKey === "2026-03-14")!;
    expect(d.stripSegments.length).toBeGreaterThan(0);
    // First segment starts at offset 0
    expect(d.stripSegments[0].startOffsetMs).toBe(0);
    // Last segment ends at DAY_MS (full 24h)
    expect(d.stripSegments[d.stripSegments.length - 1].endOffsetMs).toBe(DAY_MS);
    // No future segment for past days
    expect(d.stripSegments.every((s) => s.kind !== "future")).toBe(true);
    // Contiguous tiling: each segment starts where the previous ends
    for (let i = 1; i < d.stripSegments.length; i++) {
      expect(d.stripSegments[i].startOffsetMs).toBe(d.stripSegments[i - 1].endOffsetMs);
    }
    // Stay segment carries the placeId
    const stayseg = d.stripSegments.find((s) => s.kind === "stay")!;
    expect(stayseg.placeId).toBe("Home");
  });

  test("today has trailing future segment covering [now, DAY_MS]", () => {
    const dayStart = localMidnight("2026-03-15");
    const now = dayStart + 6 * 60 * MIN; // 6am
    const stays = [makeStay("Home", dayStart, 60)];
    const result = buildPlacesDailySummary(stays, [], [], 1, now);
    const d = result[0];
    // Full 24h coverage
    expect(d.stripSegments[0].startOffsetMs).toBe(0);
    expect(d.stripSegments[d.stripSegments.length - 1].endOffsetMs).toBe(DAY_MS);
    // Last segment is a "future" block starting at now offset
    const last = d.stripSegments[d.stripSegments.length - 1];
    expect(last.kind).toBe("future");
    expect(last.startOffsetMs).toBe(6 * 60 * MIN);
    expect(last.endOffsetMs).toBe(DAY_MS);
  });

  test("stay with scattered points produces stay + transit + noData segments", () => {
    const dayStart = localMidnight("2026-03-15");
    // Stay 0:00-1:00, scattered points 2:00-2:20, silence after
    const stays = [makeStay("Home", dayStart, 60)];
    const points: LocationPoint[] = [];
    for (let i = 0; i <= 4; i++) {
      points.push(makePoint(dayStart + 120 * MIN + i * 5 * MIN));
    }
    const result = buildPlacesDailySummary(stays, [], points, 1, localEndOfDay("2026-03-15"));
    const d = result[0];
    const kinds = d.stripSegments.map((s) => s.kind);
    expect(kinds).toContain("stay");
    expect(kinds).toContain("transit");
    expect(kinds).toContain("noData");
    // Time-ordered
    for (let i = 1; i < d.stripSegments.length; i++) {
      expect(d.stripSegments[i].startOffsetMs).toBeGreaterThanOrEqual(
        d.stripSegments[i - 1].startOffsetMs,
      );
    }
  });

  test("full day with no stays and no points → single noData segment (future if today, not if past)", () => {
    const dayStart = localMidnight("2026-03-15");
    // Past day with no data is skipped, so test today which has at least elapsed time
    const now = dayStart + 4 * 60 * MIN;
    // Need raw points to avoid the "skip empty days" filter
    const points = [makePoint(dayStart + 60 * MIN)];
    const result = buildPlacesDailySummary([], [], points, 1, now);
    const d = result[0];
    // Today: should end with future
    expect(d.stripSegments[d.stripSegments.length - 1].kind).toBe("future");
    // Full 24h coverage
    expect(d.stripSegments[0].startOffsetMs).toBe(0);
    expect(d.stripSegments[d.stripSegments.length - 1].endOffsetMs).toBe(DAY_MS);
  });
});

describe("segmentNonStay", () => {
  test("no points → single noData segment", () => {
    const segs = segmentNonStay(0, 60 * MIN, []);
    expect(segs).toEqual([{ start: 0, end: 60 * MIN, kind: "noData" }]);
  });

  test("single point → transit sandwiched by noData", () => {
    const segs = segmentNonStay(0, 60 * MIN, [makePoint(30 * MIN)]);
    expect(segs).toHaveLength(3);
    expect(segs[0].kind).toBe("noData");
    expect(segs[1].kind).toBe("transit");
    expect(segs[2].kind).toBe("noData");
    // Tiling
    expect(segs[0].end).toBe(segs[1].start);
    expect(segs[1].end).toBe(segs[2].start);
    expect(segs[0].start).toBe(0);
    expect(segs[2].end).toBe(60 * MIN);
  });

  test("point at very start → leading transit, trailing noData", () => {
    const segs = segmentNonStay(0, 60 * MIN, [makePoint(2 * MIN)]);
    // Point window [−3, 7] clamped to [0, 7]
    expect(segs[0]).toEqual({ start: 0, end: 7 * MIN, kind: "transit" });
    expect(segs[1]).toEqual({ start: 7 * MIN, end: 60 * MIN, kind: "noData" });
  });
});

describe("splitNonStay", () => {
  test("no points → all no-data", () => {
    const r = splitNonStay([{ start: 0, end: 60 * MIN }], []);
    expect(r.transitMs).toBe(0);
    expect(r.noDataMs).toBe(60 * MIN);
  });

  test("single point → 10 minute transit window", () => {
    const r = splitNonStay([{ start: 0, end: 60 * MIN }], [makePoint(30 * MIN)]);
    expect(r.transitMs).toBe(10 * MIN);
    expect(r.noDataMs).toBe(50 * MIN);
  });

  test("points <10min apart merge into single run", () => {
    const pts = [makePoint(20 * MIN), makePoint(28 * MIN), makePoint(35 * MIN)];
    const r = splitNonStay([{ start: 0, end: 60 * MIN }], pts);
    expect(r.transitMs).toBe(25 * MIN); // 20→35 = 15min run, +5 each side
  });

  test("points >10min apart are separate runs", () => {
    const pts = [makePoint(10 * MIN), makePoint(30 * MIN)]; // 20 min gap
    const r = splitNonStay([{ start: 0, end: 60 * MIN }], pts);
    expect(r.transitMs).toBe(20 * MIN); // 2 × 10-min runs
  });

  test("transit segment clipped at interval boundary", () => {
    // Point at time 2 with ±5min window → [−3, 7]; interval starts at 0 → transit = 7
    const r = splitNonStay([{ start: 0, end: 60 * MIN }], [makePoint(2 * MIN)]);
    expect(r.transitMs).toBe(7 * MIN);
  });
});

describe("formatPlacesDailyText", () => {
  function makeDay(dateKey: string, placeTotals: Array<[string, number]>): PlaceDaySummary {
    return {
      dateKey,
      places: placeTotals.map(([placeId, totalMinutes]) => ({ placeId, totalMinutes })),
      visits: [],
      elapsedMinutes: 24 * 60,
      totalStayMinutes: placeTotals.reduce((s, [, m]) => s + m, 0),
      transitMinutes: 0,
      noDataMinutes: 0,
      stripSegments: [],
    };
  }

  it("formats a day as 'Day Mon D: Place Nh, …' with whole-hour places in descending order", () => {
    // 2026-04-20 is a Monday (local).
    const text = formatPlacesDailyText([
      makeDay("2026-04-20", [["Home", 540], ["Office", 480], ["Gym", 60]]),
    ]);
    expect(text).toBe("Mon Apr 20: Home 9h, Office 8h, Gym 1h");
  });

  it("renders one line per day separated by newlines, most recent first as caller supplies", () => {
    const text = formatPlacesDailyText([
      makeDay("2026-04-21", [["Home", 600]]),
      makeDay("2026-04-20", [["Office", 480]]),
    ]);
    expect(text).toBe("Tue Apr 21: Home 10h\nMon Apr 20: Office 8h");
  });

  it("uses minutes for sub-hour stays and tenths-of-hour otherwise", () => {
    const text = formatPlacesDailyText([
      makeDay("2026-04-20", [["Home", 90], ["Cafe", 45]]),
    ]);
    expect(text).toBe("Mon Apr 20: Home 1.5h, Cafe 45m");
  });

  it("handles days with no known places gracefully", () => {
    const text = formatPlacesDailyText([makeDay("2026-04-20", [])]);
    expect(text).toBe("Mon Apr 20: no known places");
  });

  it("contains no lat/lng or ISO/unix timestamps — human text only", () => {
    const text = formatPlacesDailyText([
      makeDay("2026-04-20", [["Home", 540]]),
    ]);
    expect(text).not.toMatch(/\d{4}-\d{2}-\d{2}T/);
    expect(text).not.toMatch(/latitude|longitude/);
    expect(text).not.toMatch(/\d{13}/); // no unix ms
  });
});
