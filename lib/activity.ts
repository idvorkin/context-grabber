/**
 * Pure functions for building an hourly activity timeline from exercise,
 * heart rate, and workout data. No device or HealthKit access.
 */

import { type WorkoutEntry } from "./health";

export type ExerciseSample = {
  startDate: string; // ISO 8601
  endDate?: string; // ISO 8601
  quantity: number; // minutes
};

export type HeartRateSample = {
  startDate: string; // ISO 8601
  quantity: number; // bpm
};

export type HourBucket = {
  hour: number; // 0-23
  exerciseMinutes: number;
  avgHeartRate: number | null;
  workouts: {
    activityType: string;
    durationMinutes: number;
    distanceKm: number | null;
  }[];
};

export type ActivityTimeline = {
  buckets: HourBucket[]; // always 24 entries
  totalExerciseMinutes: number;
  peakHour: number | null;
};

function emptyBuckets(): HourBucket[] {
  return Array.from({ length: 24 }, (_, i) => ({
    hour: i,
    exerciseMinutes: 0,
    avgHeartRate: null,
    workouts: [],
  }));
}

export function buildActivityTimeline(
  exerciseSamples: ExerciseSample[],
  heartRateSamples: HeartRateSample[],
  workouts: WorkoutEntry[],
  _date: Date,
): ActivityTimeline {
  const buckets = emptyBuckets();

  // --- Exercise samples ---
  for (const s of exerciseSamples) {
    const start = new Date(s.startDate);
    if (s.endDate) {
      const end = new Date(s.endDate);
      const totalMs = end.getTime() - start.getTime();
      if (totalMs <= 0) {
        // Degenerate range — assign to start hour
        buckets[start.getHours()].exerciseMinutes += s.quantity;
        continue;
      }
      // Walk each hour the sample touches and prorate
      let cursor = new Date(start);
      while (cursor < end) {
        const hour = cursor.getHours();
        // End of this clock hour
        const hourEnd = new Date(cursor);
        hourEnd.setMinutes(0, 0, 0);
        hourEnd.setHours(hour + 1);
        const sliceEnd = hourEnd < end ? hourEnd : end;
        const sliceMs = sliceEnd.getTime() - cursor.getTime();
        buckets[hour].exerciseMinutes += s.quantity * (sliceMs / totalMs);
        cursor = sliceEnd;
      }
    } else {
      buckets[start.getHours()].exerciseMinutes += s.quantity;
    }
  }

  // Round exercise minutes to avoid floating-point noise
  for (const b of buckets) {
    b.exerciseMinutes = Math.round(b.exerciseMinutes * 100) / 100;
  }

  // --- Heart rate samples ---
  const hrAccum: { sum: number; count: number }[] = Array.from(
    { length: 24 },
    () => ({ sum: 0, count: 0 }),
  );
  for (const hr of heartRateSamples) {
    const hour = new Date(hr.startDate).getHours();
    hrAccum[hour].sum += hr.quantity;
    hrAccum[hour].count += 1;
  }
  for (let i = 0; i < 24; i++) {
    if (hrAccum[i].count > 0) {
      buckets[i].avgHeartRate =
        Math.round((hrAccum[i].sum / hrAccum[i].count) * 10) / 10;
    }
  }

  // --- Workouts ---
  for (const w of workouts) {
    if (!w.startTime) continue;
    const hour = new Date(w.startTime).getHours();
    buckets[hour].workouts.push({
      activityType: w.activityType,
      durationMinutes: w.durationMinutes,
      distanceKm: w.distanceKm,
    });
  }

  // --- Totals ---
  const totalExerciseMinutes =
    Math.round(buckets.reduce((sum, b) => sum + b.exerciseMinutes, 0) * 100) /
    100;

  let peakHour: number | null = null;
  let peakVal = 0;
  for (const b of buckets) {
    if (b.exerciseMinutes > peakVal) {
      peakVal = b.exerciseMinutes;
      peakHour = b.hour;
    }
  }

  return { buckets, totalExerciseMinutes, peakHour };
}
