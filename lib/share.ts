/**
 * Build the 7-day daily export format for sharing.
 * Pure function — takes pre-fetched weekly data and returns structured daily entries.
 */

import type { DailyValue, HeartRateDaily } from "./weekly";
import type { PlaceCluster, PlaceVisit } from "./clustering";
import type { HealthData, WorkoutEntry } from "./health";
import { computeBoxPlotStats, extractValues, type BoxPlotStats } from "./stats";
import { formatTime } from "./summary";

export type DailyExportEntry = {
  date: string; // "YYYY-MM-DD"
  dayOfWeek: string;
  steps: number | null;
  heartRate: { avg: number | null; min: number | null; max: number | null } | null;
  sleepHours: number | null;
  activeEnergy: number | null;
  walkingDistanceKm: number | null;
  weightLbs: number | null;
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
  weightLbs: MetricStatsExport | null;
  meditationMinutes: MetricStatsExport | null;
  hrvMs: MetricStatsExport | null;
  restingHeartRate: MetricStatsExport | null;
  exerciseMinutes: MetricStatsExport | null;
};

/** Today's headline — the first thing a life coach reads. Coach-friendly shape:
 *  no ISO timestamps, no coordinates, no raw sample arrays. */
export type TodayHeadline = {
  date: string; // "YYYY-MM-DD" (local)
  dayOfWeek: string;
  steps: number | null;
  heartRate: number | null;
  restingHeartRate: number | null;
  hrv: number | null;
  sleepHours: number | null;
  bedtime: string | null; // "11pm" / "12:15am" — formatted for humans
  wakeTime: string | null;
  meditationMinutes: number | null;
  exerciseMinutes: number | null;
  weightLbs: number | null;
  activeEnergy: number | null;
  walkingDistanceKm: number | null;
  workouts: WorkoutEntry[];
};

/** Text-only place activity: human-readable, no coords, no unix timestamps. */
export type PlacesSummary = {
  weekly: string; // "This week: Home 92h, Office 28h\nLast week: ..."
  recent: string; // "Mon Mar 15: Home 10pm–7am (9h), Office 9am–5pm (8h)"
};

export type SummaryExport = {
  today: TodayHeadline;
  days: DailyExportEntry[];
  places: PlacesSummary | null;
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
  hrv: HeartRateDaily[];
  restingHeartRate: HeartRateDaily[];
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
    weightLbs: toStatsExport(computeBoxPlotStats(extractValues(data.weight))),
    meditationMinutes: toStatsExport(computeBoxPlotStats(extractValues(data.meditation))),
    hrvMs: toStatsExport(computeBoxPlotStats(
      (data.hrv as HeartRateDaily[]).filter((d) => d.avg !== null).map((d) => d.avg as number)
    )),
    restingHeartRate: toStatsExport(computeBoxPlotStats(
      (data.restingHeartRate as HeartRateDaily[]).filter((d) => d.avg !== null).map((d) => d.avg as number)
    )),
    exerciseMinutes: toStatsExport(computeBoxPlotStats(extractValues(data.exerciseMinutes))),
  };
}

/**
 * Build the "today" headline from live HealthData.
 * Bedtime/wakeTime get formatted to coach-readable "11pm" form
 * (the raw ISO value in HealthData is useful only to the chart layer).
 */
export function buildTodayHeadline(health: HealthData, dateKey: string): TodayHeadline {
  return {
    date: dateKey,
    dayOfWeek: dateKey ? dayOfWeek(dateKey) : "",
    steps: health.steps,
    heartRate: health.heartRate,
    restingHeartRate: health.restingHeartRate,
    hrv: health.hrv,
    sleepHours: health.sleepHours,
    bedtime: health.bedtime ? formatTime(health.bedtime) : null,
    wakeTime: health.wakeTime ? formatTime(health.wakeTime) : null,
    meditationMinutes: health.meditationMinutes,
    exerciseMinutes: health.exerciseMinutes,
    weightLbs: health.weight != null ? Math.round(health.weight * 2.20462) : null,
    activeEnergy: health.activeEnergy,
    walkingDistanceKm: health.walkingDistance,
    workouts: health.workouts ?? [],
  };
}

/**
 * Build a summary export: today's headline + last 7 daily health values + text-only place activity.
 * No coordinates, no unix timestamps, no percentile tables — those belong in Raw / Copy Location Data.
 */
export function buildSummaryExport(
  data: WeeklyDataMap,
  health: HealthData,
  places: PlacesSummary | null,
): SummaryExport {
  // Canonical "today" is the last date in the 7-day window (data is sorted ascending).
  const todayDate = data.steps[data.steps.length - 1]?.date ?? "";
  return {
    today: buildTodayHeadline(health, todayDate),
    days: buildDailyExport(data),
    places,
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
      weightLbs: data.weight[i]?.value ?? null,
      meditationMinutes: data.meditation[i]?.value ?? null,
      hrvMs: data.hrv[i]?.avg ?? null,
      restingHeartRate: data.restingHeartRate[i]?.avg ?? null,
      exerciseMinutes: data.exerciseMinutes[i]?.value ?? null,
    };
  });
}
