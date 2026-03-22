/**
 * Pure statistical functions for computing percentiles and box plot summaries.
 * No device or HealthKit access — fully testable.
 */

export type BoxPlotStats = {
  min: number;
  p5: number;
  p25: number;
  p50: number;
  p75: number;
  p95: number;
  max: number;
  values: number[];
};

/**
 * Compute a percentile value from a sorted array using linear interpolation.
 * @param sorted  Pre-sorted array of numbers (ascending).
 * @param p       Percentile as a fraction (0–1), e.g. 0.5 for p50.
 */
export function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) throw new Error("Cannot compute percentile of empty array");
  if (sorted.length === 1) return sorted[0];

  // Use the "exclusive" (R-7) interpolation method, matching NumPy/Excel default.
  const index = p * (sorted.length - 1);
  const lower = Math.floor(index);
  const upper = Math.ceil(index);

  if (lower === upper) return sorted[lower];

  const fraction = index - lower;
  return sorted[lower] + fraction * (sorted[upper] - sorted[lower]);
}

/**
 * Compute box plot statistics from an array of numbers.
 * Returns null if the input array is empty or contains no finite values.
 * Values are rounded to 1 decimal place for display.
 */
export function computeBoxPlotStats(values: number[]): BoxPlotStats | null {
  // Filter to finite numbers only.
  const finite = values.filter((v) => Number.isFinite(v));
  if (finite.length === 0) return null;

  const sorted = [...finite].sort((a, b) => a - b);

  return {
    min: round1(sorted[0]),
    p5: round1(percentile(sorted, 0.05)),
    p25: round1(percentile(sorted, 0.25)),
    p50: round1(percentile(sorted, 0.5)),
    p75: round1(percentile(sorted, 0.75)),
    p95: round1(percentile(sorted, 0.95)),
    max: round1(sorted[sorted.length - 1]),
    values: sorted.map(round1),
  };
}

/**
 * Round to 1 decimal place.
 */
function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

/**
 * Extract non-null values from a DailyValue array for stats computation.
 */
export function extractValues(data: Array<{ value: number | null }>): number[] {
  return data.filter((d) => d.value !== null).map((d) => d.value as number);
}
