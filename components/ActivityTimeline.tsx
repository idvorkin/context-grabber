import React, { useState } from "react";
import { View, Text, StyleSheet, type LayoutChangeEvent } from "react-native";
import type { ActivityTimeline } from "../lib/activity";

type ActivityTimelineProps = {
  timeline: ActivityTimeline;
  color: string;
};

const CHART_HEIGHT = 120;
const START_HOUR = 6;
const END_HOUR = 22;
const VISIBLE_HOURS = END_HOUR - START_HOUR + 1;
const HR_COLOR = "#f72585";
const HR_DOT_SIZE = 5;
const HR_MIN = 50;
const HR_MAX = 180;

const HOUR_LABELS: Record<number, string> = {
  6: "6a", 9: "9a", 12: "12p", 15: "3p", 18: "6p", 21: "9p",
};

export default function ActivityTimelineChart({ timeline, color }: ActivityTimelineProps): React.JSX.Element {
  const [chartWidth, setChartWidth] = useState(0);
  const visibleBuckets = timeline.buckets.filter(b => b.hour >= START_HOUR && b.hour <= END_HOUR);
  const maxExercise = visibleBuckets.reduce((acc, b) => Math.max(acc, b.exerciseMinutes), 0);
  const barWidth = chartWidth > 0 ? chartWidth / VISIBLE_HOURS : 0;

  function onLayout(e: LayoutChangeEvent) {
    setChartWidth(e.nativeEvent.layout.width);
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>Activity</Text>
        <Text style={styles.headerText}>{timeline.totalExerciseMinutes} min</Text>
      </View>

      <View style={[styles.chartArea, { height: CHART_HEIGHT }]} onLayout={onLayout}>
        {chartWidth > 0 && (
          <>
            {/* Exercise bars */}
            <View style={styles.barsRow}>
              {visibleBuckets.map(bucket => {
                const barHeight = maxExercise > 0
                  ? Math.max(2, Math.round((bucket.exerciseMinutes / maxExercise) * (CHART_HEIGHT - 4)))
                  : 0;
                return (
                  <View key={bucket.hour} style={{ width: barWidth, height: CHART_HEIGHT, justifyContent: "flex-end", alignItems: "center" }}>
                    {bucket.exerciseMinutes > 0 && (
                      <View style={{ width: barWidth * 0.6, height: barHeight, backgroundColor: `${color}cc`, borderRadius: 2 }} />
                    )}
                  </View>
                );
              })}
            </View>

            {/* Heart rate dots */}
            {visibleBuckets.map(bucket => {
              if (bucket.avgHeartRate === null) return null;
              const clamped = Math.min(HR_MAX, Math.max(HR_MIN, bucket.avgHeartRate));
              const ratio = (clamped - HR_MIN) / (HR_MAX - HR_MIN);
              const top = CHART_HEIGHT - ratio * CHART_HEIGHT - HR_DOT_SIZE / 2;
              const left = (bucket.hour - START_HOUR + 0.5) * barWidth - HR_DOT_SIZE / 2;
              return (
                <View key={`hr-${bucket.hour}`} style={[styles.hrDot, { top, left }]} />
              );
            })}

            {/* Workout blocks */}
            {visibleBuckets.map(bucket =>
              bucket.workouts.map((w, wi) => {
                const spanHours = Math.max(w.durationMinutes / 60, 0.5);
                const left = (bucket.hour - START_HOUR) * barWidth;
                const width = Math.min(spanHours * barWidth, chartWidth - left);
                return (
                  <View key={`wo-${bucket.hour}-${wi}`} style={[styles.workoutBlock, { left, width }]}>
                    <Text style={styles.workoutLabel} numberOfLines={1}>{w.activityType}</Text>
                  </View>
                );
              })
            )}
          </>
        )}
      </View>

      {/* Hour labels */}
      {chartWidth > 0 && (
        <View style={styles.labelsRow}>
          {Object.entries(HOUR_LABELS).map(([h, label]) => {
            const hour = Number(h);
            const left = (hour - START_HOUR + 0.5) * barWidth;
            return (
              <Text key={h} style={[styles.hourLabel, { left: left - 10 }]}>{label}</Text>
            );
          })}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { width: "100%" },
  header: { flexDirection: "row", justifyContent: "space-between", marginBottom: 6 },
  headerText: { fontSize: 13, color: "#e0e0e0", fontWeight: "600" },
  chartArea: { position: "relative", width: "100%", backgroundColor: "#111828", borderRadius: 8, overflow: "hidden" },
  barsRow: { flexDirection: "row", position: "absolute", bottom: 0, left: 0, right: 0, height: "100%" },
  hrDot: { position: "absolute", width: HR_DOT_SIZE, height: HR_DOT_SIZE, borderRadius: HR_DOT_SIZE / 2, backgroundColor: HR_COLOR },
  workoutBlock: { position: "absolute", bottom: 0, height: 20, backgroundColor: "rgba(255,255,255,0.15)", borderRadius: 4, justifyContent: "center", alignItems: "center", paddingHorizontal: 4 },
  workoutLabel: { fontSize: 9, color: "#e0e0e0", fontWeight: "500" },
  labelsRow: { position: "relative", height: 16, marginTop: 2 },
  hourLabel: { position: "absolute", fontSize: 10, color: "#666", width: 20, textAlign: "center" },
});
