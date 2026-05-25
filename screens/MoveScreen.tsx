import React, { useMemo } from "react";
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { RingProgress } from "../components/RingProgress";
import type { DailyValue } from "../lib/weekly";
import type { WorkoutEntry } from "../lib/health";

/** Default weekly exercise-minutes target (WHO: 150 min/week moderate activity). */
const WEEKLY_EXERCISE_TARGET_MIN = 150;

type Preset = {
  id: "30sec" | "1min" | "2min" | "5-1";
  label: string;
  detail: string;
};

const PRESETS: ReadonlyArray<Preset> = [
  { id: "30sec", label: "30 SEC", detail: "6 × 30s · 5s rest" },
  { id: "1min", label: "1 MIN", detail: "5 × 60s · 10s rest" },
  { id: "2min", label: "2 MIN", detail: "4 × 120s · 15s rest" },
  { id: "5-1", label: "5–1", detail: "3 × 5min · 60s rest" },
];

type Props = {
  /** Current week's exercise minutes per day (`weeklyCache.exerciseMinutes`). */
  exerciseMinutesWeekly: DailyValue[] | null;
  /** Today's workouts from snapshot. */
  workoutsToday: WorkoutEntry[];
  /** Past-week workouts grouped by date key. */
  workoutsByDay: Record<string, WorkoutEntry[]>;
  /** Tap a preset → launch GymTimer with that preset. */
  onLaunchPreset: (presetId: Preset["id"]) => void;
  /** Tap a workout row → open WorkoutAnalysisScreen. */
  onSelectWorkout: (workout: WorkoutEntry) => void;
};

export function MoveScreen({
  exerciseMinutesWeekly,
  workoutsToday,
  workoutsByDay,
  onLaunchPreset,
  onSelectWorkout,
}: Props) {
  const weeklyTotalMin = useMemo(() => {
    if (!exerciseMinutesWeekly) return 0;
    return exerciseMinutesWeekly.reduce(
      (sum, d) => sum + (d.value ?? 0),
      0,
    );
  }, [exerciseMinutesWeekly]);

  const recentWorkouts = useMemo(() => {
    // Flatten all 7-day workouts; sort by startTime descending; cap at 10.
    const all: WorkoutEntry[] = [];
    for (const day of Object.values(workoutsByDay)) {
      all.push(...day);
    }
    // Today's workouts may not yet be in workoutsByDay (lazy-loaded); add any missing.
    for (const w of workoutsToday) {
      if (!all.find((x) => x.startTime && x.startTime === w.startTime)) {
        all.push(w);
      }
    }
    all.sort((a, b) => {
      const ta = a.startTime ? new Date(a.startTime).getTime() : 0;
      const tb = b.startTime ? new Date(b.startTime).getTime() : 0;
      return tb - ta;
    });
    return all.slice(0, 10);
  }, [workoutsToday, workoutsByDay]);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Move</Text>
      </View>
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.ringRow}>
          <RingProgress
            value={Math.round(weeklyTotalMin)}
            target={WEEKLY_EXERCISE_TARGET_MIN}
            unit="min"
            size={100}
          />
          <View style={styles.ringLabel}>
            <Text style={styles.ringHeading}>This week</Text>
            <Text style={styles.ringSub}>
              {Math.round(weeklyTotalMin)} / {WEEKLY_EXERCISE_TARGET_MIN} min
            </Text>
            <Text style={styles.ringSubFaint}>
              Goal: {WEEKLY_EXERCISE_TARGET_MIN} min/week
            </Text>
          </View>
        </View>

        <Text style={styles.sectionHeading}>Gym Timer</Text>
        <View style={styles.presetGrid}>
          {PRESETS.map((p) => (
            <Pressable
              key={p.id}
              onPress={() => onLaunchPreset(p.id)}
              testID={`gym-preset-${p.id}`}
              style={styles.presetTile}
              accessibilityLabel={`Start ${p.label} timer`}
            >
              <Text style={styles.presetLabel}>{p.label}</Text>
              <Text style={styles.presetDetail}>{p.detail}</Text>
            </Pressable>
          ))}
        </View>

        <Text style={styles.sectionHeading}>Recent workouts</Text>
        {recentWorkouts.length === 0 ? (
          <View style={styles.emptyCard}>
            <Text style={styles.emptyText}>
              No workouts yet — tap a preset above to start one.
            </Text>
          </View>
        ) : (
          <View>
            {recentWorkouts.map((w, i) => (
              <TouchableOpacity
                key={`${w.startTime ?? "u"}-${i}`}
                onPress={() => onSelectWorkout(w)}
                style={styles.workoutRow}
                testID={`workout-row-${i}`}
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.workoutTitle}>{w.activityType}</Text>
                  <Text style={styles.workoutMeta}>
                    {w.durationMinutes} min
                    {w.energyBurned != null ? ` · ${Math.round(w.energyBurned)} kcal` : ""}
                    {w.distanceKm != null ? ` · ${w.distanceKm.toFixed(2)} km` : ""}
                  </Text>
                </View>
                {w.startTime && (
                  <Text style={styles.workoutWhen}>
                    {formatRelativeWorkoutTime(w.startTime)}
                  </Text>
                )}
              </TouchableOpacity>
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function formatRelativeWorkoutTime(iso: string): string {
  const then = new Date(iso).getTime();
  const ageMs = Date.now() - then;
  if (ageMs < 60 * 60 * 1000) return `${Math.round(ageMs / 60000)}m ago`;
  if (ageMs < 24 * 3600 * 1000) return `${Math.round(ageMs / 3600000)}h ago`;
  const days = Math.round(ageMs / (24 * 3600 * 1000));
  return days === 1 ? "yesterday" : `${days}d ago`;
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: { paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  scroll: { paddingHorizontal: 20, paddingBottom: 20 },
  ringRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 4,
    marginBottom: 16,
    gap: 16,
  },
  ringLabel: {
    flex: 1,
  },
  ringHeading: {
    fontSize: 14,
    fontWeight: "600",
    color: "#4cc9f0",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  ringSub: { fontSize: 18, fontWeight: "700", color: "#e0e0e0", marginTop: 4 },
  ringSubFaint: { fontSize: 12, color: "#888", marginTop: 2 },
  sectionHeading: {
    fontSize: 14,
    fontWeight: "600",
    color: "#4cc9f0",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 8,
    marginBottom: 8,
  },
  presetGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-between",
    gap: 10,
    marginBottom: 16,
  },
  presetTile: {
    width: "48%",
    backgroundColor: "#16213e",
    borderRadius: 12,
    paddingVertical: 18,
    paddingHorizontal: 14,
    alignItems: "center",
  },
  presetLabel: { fontSize: 20, fontWeight: "700", color: "#4cc9f0" },
  presetDetail: { fontSize: 11, color: "#888", marginTop: 4 },
  emptyCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  emptyText: { color: "#888", fontSize: 13, textAlign: "center" },
  workoutRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#16213e",
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 8,
  },
  workoutTitle: { color: "#e0e0e0", fontSize: 15, fontWeight: "600" },
  workoutMeta: { color: "#888", fontSize: 12, marginTop: 2 },
  workoutWhen: { color: "#666", fontSize: 12 },
});
