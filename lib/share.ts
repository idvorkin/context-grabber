/**
 * Build the 7-day daily export format for sharing.
 * Pure function — takes pre-fetched weekly data and returns structured daily entries.
 */

import type { DailyValue, HeartRateDaily } from "./weekly";
import type { PlaceCluster, PlaceVisit } from "./clustering";
import { computeBoxPlotStats, extractValues, type BoxPlotStats } from "./stats";

export type DailyExportEntry = {
  date: string; // "YYYY-MM-DD"
  dayOfWeek: string;
  steps: number | null;
  heartRate: { avg: number | null; min: number | null; max: number | null } | null;
  sleepHours: number | null;
  activeEnergy: number | null;
  walkingDistanceKm: number | null;
  weightKg: number | null;
  meditationMinutes: number | null;
  hrvMs: number | null;
  restingHeartRate: number | null;
  exerciseMinutes: number | null;
};

export type LocationSummary = {
  clusters: PlaceCluster[];
  timeline: PlaceVisit[];
  summary: string;
};

/** Statistical summary for a single metric (omits the raw values array for brevity). */
export type MetricStatsExport = {
  min: number;
  p5: number;
  p25: number;
  p50: number;
  p75: number;
  p95: number;
  max: number;
};

export type WeeklyStatsExport = {
  steps: MetricStatsExport | null;
  heartRate: MetricStatsExport | null;
  sleepHours: MetricStatsExport | null;
  activeEnergy: MetricStatsExport | null;
  walkingDistanceKm: MetricStatsExport | null;
  weightKg: MetricStatsExport | null;
  meditationMinutes: MetricStatsExport | null;
  hrvMs: MetricStatsExport | null;
  restingHeartRate: MetricStatsExport | null;
  exerciseMinutes: MetricStatsExport | null;
};

export type SummaryExport = {
  days: DailyExportEntry[];
  weeklyStats: WeeklyStatsExport;
  locationSummary: LocationSummary | null;
};

export type RawExport = {
  timestamp: string;
  health: Record<string, unknown>;
  location: { latitude: number; longitude: number; timestamp: number } | null;
  locationClusters: LocationSummary | null;
};

const DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

/**
 * Get the day-of-week name for a "YYYY-MM-DD" date string,
 * interpreted in local time.
 */
export function dayOfWeek(dateStr: string): string {
  // Parse as local date by using year/month/day components
  const [y, m, d] = dateStr.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  return DAY_NAMES[date.getDay()];
}

export type WeeklyDataMap = {
  steps: DailyValue[];
  heartRate: HeartRateDaily[];
  sleep: DailyValue[];
  activeEnergy: DailyValue[];
  walkingDistance: DailyValue[];
  weight: DailyValue[];
  meditation: DailyValue[];
  hrv: DailyValue[];
  restingHeartRate: DailyValue[];
  exerciseMinutes: DailyValue[];
};

/**
 * Convert BoxPlotStats to the leaner export format (drops raw values array).
 */
function toStatsExport(stats: BoxPlotStats | null): MetricStatsExport | null {
  if (!stats) return null;
  return {
    min: stats.min,
    p5: stats.p5,
    p25: stats.p25,
    p50: stats.p50,
    p75: stats.p75,
    p95: stats.p95,
    max: stats.max,
  };
}

/**
 * Compute 7-day statistical summaries for all metrics.
 */
export function buildWeeklyStats(data: WeeklyDataMap): WeeklyStatsExport {
  const hrValues = (data.heartRate as HeartRateDaily[])
    .filter((d) => d.avg !== null)
    .map((d) => d.avg as number);

  return {
    steps: toStatsExport(computeBoxPlotStats(extractValues(data.steps))),
    heartRate: toStatsExport(computeBoxPlotStats(hrValues)),
    sleepHours: toStatsExport(computeBoxPlotStats(extractValues(data.sleep))),
    activeEnergy: toStatsExport(computeBoxPlotStats(extractValues(data.activeEnergy))),
    walkingDistanceKm: toStatsExport(computeBoxPlotStats(extractValues(data.walkingDistance))),
    weightKg: toStatsExport(computeBoxPlotStats(extractValues(data.weight))),
    meditationMinutes: toStatsExport(computeBoxPlotStats(extractValues(data.meditation))),
    hrvMs: toStatsExport(computeBoxPlotStats(extractValues(data.hrv))),
    restingHeartRate: toStatsExport(computeBoxPlotStats(extractValues(data.restingHeartRate))),
    exerciseMinutes: toStatsExport(computeBoxPlotStats(extractValues(data.exerciseMinutes))),
  };
}

/**
 * Build a summary export: 7-day daily health data + stats + location clusters.
 */
export function buildSummaryExport(
  data: WeeklyDataMap,
  locationSummary: LocationSummary | null,
): SummaryExport {
  return {
    days: buildDailyExport(data),
    weeklyStats: buildWeeklyStats(data),
    locationSummary,
  };
}

export function buildDailyExport(data: WeeklyDataMap): DailyExportEntry[] {
  // Use steps dates as the canonical date list (all metrics should have same dates)
  return data.steps.map((stepDay, i) => {
    const hr = data.heartRate[i];
    return {
      date: stepDay.date,
      dayOfWeek: dayOfWeek(stepDay.date),
      steps: stepDay.value,
      heartRate:
        hr && (hr.avg !== null || hr.min !== null || hr.max !== null)
          ? { avg: hr.avg, min: hr.min, max: hr.max }
          : null,
      sleepHours: data.sleep[i]?.value ?? null,
      activeEnergy: data.activeEnergy[i]?.value ?? null,
      walkingDistanceKm: data.walkingDistance[i]?.value ?? null,
      weightKg: data.weight[i]?.value ?? null,
      meditationMinutes: data.meditation[i]?.value ?? null,
      hrvMs: data.hrv[i]?.value ?? null,
      restingHeartRate: data.restingHeartRate[i]?.value ?? null,
      exerciseMinutes: data.exerciseMinutes[i]?.value ?? null,
    };
  });
}
