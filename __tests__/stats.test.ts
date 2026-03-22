import {
  percentile,
  computeBoxPlotStats,
  extractValues,
  type BoxPlotStats,
} from "../lib/stats";

// ─── percentile ────────────────────────────────────────────────────────────────

describe("percentile", () => {
  it("returns the single value for a 1-element array", () => {
    expect(percentile([42], 0.5)).toBe(42);
    expect(percentile([42], 0)).toBe(42);
    expect(percentile([42], 1)).toBe(42);
  });

  it("returns exact values at 0 and 1", () => {
    const sorted = [10, 20, 30, 40, 50];
    expect(percentile(sorted, 0)).toBe(10);
    expect(percentile(sorted, 1)).toBe(50);
  });

  it("returns median for even-length array", () => {
    // [1, 2, 3, 4] — median interpolates between 2 and 3
    expect(percentile([1, 2, 3, 4], 0.5)).toBe(2.5);
  });

  it("returns median for odd-length array", () => {
    expect(percentile([1, 2, 3, 4, 5], 0.5)).toBe(3);
  });

  it("interpolates correctly for p25", () => {
    // [0, 10, 20, 30, 40] — p25: index = 0.25 * 4 = 1.0 → exact 10
    expect(percentile([0, 10, 20, 30, 40], 0.25)).toBe(10);
  });

  it("interpolates between values", () => {
    // [0, 100] — p50: index = 0.5 * 1 = 0.5 → 0 + 0.5 * (100 - 0) = 50
    expect(percentile([0, 100], 0.5)).toBe(50);
    // p25: index = 0.25 * 1 = 0.25 → 0 + 0.25 * 100 = 25
    expect(percentile([0, 100], 0.25)).toBe(25);
  });

  it("throws on empty array", () => {
    expect(() => percentile([], 0.5)).toThrow("Cannot compute percentile of empty array");
  });
});

// ─── computeBoxPlotStats ──────────────────────────────────────────────────────

describe("computeBoxPlotStats", () => {
  it("returns null for empty array", () => {
    expect(computeBoxPlotStats([])).toBeNull();
  });

  it("returns null for array of non-finite values", () => {
    expect(computeBoxPlotStats([NaN, Infinity, -Infinity])).toBeNull();
  });

  it("handles single value", () => {
    const result = computeBoxPlotStats([42]);
    expect(result).not.toBeNull();
    expect(result!.min).toBe(42);
    expect(result!.p5).toBe(42);
    expect(result!.p25).toBe(42);
    expect(result!.p50).toBe(42);
    expect(result!.p75).toBe(42);
    expect(result!.p95).toBe(42);
    expect(result!.max).toBe(42);
    expect(result!.values).toEqual([42]);
  });

  it("computes correct stats for known dataset", () => {
    // 7 values (one per day of the week)
    const values = [5000, 8000, 12000, 7500, 9000, 6000, 11000];
    const result = computeBoxPlotStats(values)!;

    // Sorted: [5000, 6000, 7500, 8000, 9000, 11000, 12000]
    expect(result.min).toBe(5000);
    expect(result.max).toBe(12000);
    expect(result.p50).toBe(8000); // middle value of 7 elements

    // p25: index = 0.25 * 6 = 1.5 → 6000 + 0.5 * (7500 - 6000) = 6750
    expect(result.p25).toBe(6750);

    // p75: index = 0.75 * 6 = 4.5 → 9000 + 0.5 * (11000 - 9000) = 10000
    expect(result.p75).toBe(10000);

    // values should be sorted
    expect(result.values).toEqual([5000, 6000, 7500, 8000, 9000, 11000, 12000]);
  });

  it("filters out NaN and Infinity", () => {
    const result = computeBoxPlotStats([10, NaN, 20, Infinity, 30]);
    expect(result).not.toBeNull();
    expect(result!.values).toEqual([10, 20, 30]);
    expect(result!.p50).toBe(20);
  });

  it("rounds to 1 decimal place", () => {
    const result = computeBoxPlotStats([1.15, 2.25, 3.35]);
    expect(result).not.toBeNull();
    // 1.15 rounds to 1.2, 2.25 rounds to 2.3, 3.35 rounds to 3.4
    expect(result!.min).toBe(1.2);
    expect(result!.max).toBe(3.4);
  });

  it("has correct shape with all fields", () => {
    const result = computeBoxPlotStats([1, 2, 3, 4, 5]);
    expect(result).toHaveProperty("min");
    expect(result).toHaveProperty("p5");
    expect(result).toHaveProperty("p25");
    expect(result).toHaveProperty("p50");
    expect(result).toHaveProperty("p75");
    expect(result).toHaveProperty("p95");
    expect(result).toHaveProperty("max");
    expect(result).toHaveProperty("values");
    expect(Array.isArray(result!.values)).toBe(true);
  });

  it("handles two values", () => {
    const result = computeBoxPlotStats([10, 20])!;
    expect(result.min).toBe(10);
    expect(result.max).toBe(20);
    expect(result.p50).toBe(15);
  });

  it("handles large dataset", () => {
    // 100 values from 1 to 100
    const values = Array.from({ length: 100 }, (_, i) => i + 1);
    const result = computeBoxPlotStats(values)!;
    expect(result.min).toBe(1);
    expect(result.max).toBe(100);
    expect(result.p50).toBe(50.5);
    expect(result.p25).toBe(25.8); // 0.25 * 99 = 24.75 → 25 + 0.75*(26-25) = 25.75 → rounds to 25.8
  });
});

// ─── extractValues ────────────────────────────────────────────────────────────

describe("extractValues", () => {
  it("returns empty array for empty input", () => {
    expect(extractValues([])).toEqual([]);
  });

  it("filters out null values", () => {
    const data = [
      { value: 10 },
      { value: null },
      { value: 20 },
      { value: null },
      { value: 30 },
    ];
    expect(extractValues(data)).toEqual([10, 20, 30]);
  });

  it("returns all values when none are null", () => {
    const data = [{ value: 1 }, { value: 2 }, { value: 3 }];
    expect(extractValues(data)).toEqual([1, 2, 3]);
  });

  it("returns empty array when all values are null", () => {
    const data = [{ value: null }, { value: null }];
    expect(extractValues(data)).toEqual([]);
  });
});
