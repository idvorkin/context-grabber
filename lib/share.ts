/**
 * Build the 7-day daily export format for sharing.
 * Pure function — takes pre-fetched weekly data and returns structured daily entries.
 */

import type { DailyValue, HeartRateDaily } from "./weekly";
import type { PlaceCluster } from "./clustering";

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
  summary: string;
};

export type SummaryExport = {
  days: DailyExportEntry[];
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
 * Build an array of 7 daily export entries from weekly metric data.
 * Each entry combines all metrics for that day.
 */
/**
 * Build a summary export: 7-day daily health data + location clusters.
 */
export function buildSummaryExport(
  data: WeeklyDataMap,
  locationSummary: LocationSummary | null,
): SummaryExport {
  return {
    days: buildDailyExport(data),
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
