import {
  buildActivityTimeline,
  type ExerciseSample,
  type HeartRateSample,
} from "../lib/activity";
import type { WorkoutEntry } from "../lib/health";

const TODAY = new Date("2026-04-04T00:00:00");

describe("buildActivityTimeline", () => {
  it("returns 24 zero buckets for empty inputs", () => {
    const result = buildActivityTimeline([], [], [], TODAY);
    expect(result.buckets).toHaveLength(24);
    expect(result.totalExerciseMinutes).toBe(0);
    expect(result.peakHour).toBeNull();
    for (const b of result.buckets) {
      expect(b.exerciseMinutes).toBe(0);
      expect(b.avgHeartRate).toBeNull();
      expect(b.workouts).toEqual([]);
    }
  });

  it("places a single exercise sample at the correct hour", () => {
    const samples: ExerciseSample[] = [
      { startDate: "2026-04-04T10:15:00", quantity: 12 },
    ];
    const result = buildActivityTimeline(samples, [], [], TODAY);
    expect(result.buckets[10].exerciseMinutes).toBe(12);
    expect(result.totalExerciseMinutes).toBe(12);
    expect(result.peakHour).toBe(10);
  });

  it("prorates exercise across hours when endDate spans two hours", () => {
    // 10:50 to 11:10 = 20 min total, 10 min in hour 10, 10 min in hour 11
    const samples: ExerciseSample[] = [
      {
        startDate: "2026-04-04T10:50:00",
        endDate: "2026-04-04T11:10:00",
        quantity: 20,
      },
    ];
    const result = buildActivityTimeline(samples, [], [], TODAY);
    expect(result.buckets[10].exerciseMinutes).toBe(10);
    expect(result.buckets[11].exerciseMinutes).toBe(10);
    expect(result.totalExerciseMinutes).toBe(20);
  });

  it("buckets heart rate samples by hour", () => {
    const hrSamples: HeartRateSample[] = [
      { startDate: "2026-04-04T08:05:00", quantity: 72 },
      { startDate: "2026-04-04T14:30:00", quantity: 95 },
    ];
    const result = buildActivityTimeline([], hrSamples, [], TODAY);
    expect(result.buckets[8].avgHeartRate).toBe(72);
    expect(result.buckets[14].avgHeartRate).toBe(95);
    expect(result.buckets[0].avgHeartRate).toBeNull();
  });

  it("averages multiple HR samples in the same hour", () => {
    const hrSamples: HeartRateSample[] = [
      { startDate: "2026-04-04T09:00:00", quantity: 60 },
      { startDate: "2026-04-04T09:30:00", quantity: 80 },
      { startDate: "2026-04-04T09:45:00", quantity: 100 },
    ];
    const result = buildActivityTimeline([], hrSamples, [], TODAY);
    expect(result.buckets[9].avgHeartRate).toBe(80);
  });

  it("places a workout in the correct hour bucket", () => {
    const workouts: WorkoutEntry[] = [
      {
        activityType: "Running",
        durationMinutes: 30,
        energyBurned: 250,
        distanceKm: 5.0,
        startTime: "2026-04-04T07:00:00.000Z",
        endTime: "2026-04-04T07:30:00.000Z",
      },
    ];
    const result = buildActivityTimeline([], [], workouts, TODAY);
    const hour = new Date("2026-04-04T07:00:00.000Z").getHours();
    expect(result.buckets[hour].workouts).toHaveLength(1);
    expect(result.buckets[hour].workouts[0]).toEqual({
      activityType: "Running",
      durationMinutes: 30,
      distanceKm: 5.0,
    });
  });

  it("excludes workouts without startTime", () => {
    const workouts: WorkoutEntry[] = [
      {
        activityType: "Yoga",
        durationMinutes: 60,
        energyBurned: 100,
        distanceKm: null,
        // no startTime
      },
    ];
    const result = buildActivityTimeline([], [], workouts, TODAY);
    for (const b of result.buckets) {
      expect(b.workouts).toHaveLength(0);
    }
  });

  it("identifies the peak hour correctly", () => {
    const samples: ExerciseSample[] = [
      { startDate: "2026-04-04T06:00:00", quantity: 5 },
      { startDate: "2026-04-04T17:00:00", quantity: 30 },
      { startDate: "2026-04-04T20:00:00", quantity: 15 },
    ];
    const result = buildActivityTimeline(samples, [], [], TODAY);
    expect(result.peakHour).toBe(17);
  });
});
