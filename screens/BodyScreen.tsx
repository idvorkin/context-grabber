import React, { useMemo } from "react";
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from "react-native";
import { MetricCard, type MetricCardProps } from "../components/MetricCard";
import { WeekStrip, buildWeekStripDays } from "../components/WeekStrip";
import { formatDateKey } from "../lib/weekly";
import type { ContextSnapshot } from "../lib/appTypes";

type Props = {
  snapshot: ContextSnapshot | null;
  metrics: MetricCardProps[];
  onOpenLocationDetail: () => void;
  /** Optional: dates that should show a workout-day dot. Map of dateKey → true. */
  workoutDays?: Set<string>;
};

export function BodyScreen({
  snapshot,
  metrics,
  onOpenLocationDetail,
  workoutDays,
}: Props) {
  const days = useMemo(
    () =>
      buildWeekStripDays(new Date(), formatDateKey, (dateKey) =>
        workoutDays?.has(dateKey)
          ? { hasDot: true, color: "#4cc9f0" }
          : undefined,
      ),
    [workoutDays],
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Body</Text>
      </View>
      <WeekStrip days={days} />
      <ScrollView contentContainerStyle={styles.scroll}>
        {snapshot ? (
          <View style={styles.metricGrid}>
            {metrics.map((m) => (
              <MetricCard
                key={m.label}
                metricKey={m.metricKey}
                label={m.label}
                value={m.value}
                sublabel={m.sublabel}
                onPress={m.onPress}
                boxPlotStats={m.boxPlotStats}
                boxPlotStatsList={m.boxPlotStatsList}
                color={m.color}
              />
            ))}
            <TouchableOpacity
              style={styles.metricCard}
              onPress={onOpenLocationDetail}
              testID="location-card"
              activeOpacity={0.7}
            >
              <Text style={styles.metricLabel}>Location</Text>
              {snapshot.location ? (
                <Text style={styles.metricValue}>
                  {snapshot.location.latitude.toFixed(2)},{" "}
                  {snapshot.location.longitude.toFixed(2)}
                </Text>
              ) : (
                <Text style={[styles.metricValue, styles.metricValueNull]}>—</Text>
              )}
              <Text style={styles.metricSublabel}>
                {(() => {
                  const latestMs = snapshot.location?.timestamp
                    ?? (snapshot.locationHistory.length > 0
                      ? snapshot.locationHistory[snapshot.locationHistory.length - 1].timestamp
                      : null);
                  if (latestMs == null) return "Unavailable";
                  const ageMs = Date.now() - latestMs;
                  if (ageMs < 5 * 60 * 1000) return "now";
                  if (ageMs < 60 * 60 * 1000) return `${Math.round(ageMs / 60000)} min ago`;
                  if (ageMs < 24 * 60 * 60 * 1000) return `${Math.round(ageMs / 3600000)} hr ago`;
                  const days = Math.round(ageMs / (24 * 3600000));
                  return days === 1 ? "yesterday" : `${days} days ago`;
                })()}
              </Text>
            </TouchableOpacity>
          </View>
        ) : (
          <View style={styles.empty}>
            <Text style={styles.emptyText}>No data yet — pull to grab.</Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: { paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  scroll: { paddingHorizontal: 20, paddingBottom: 20 },
  metricGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-between",
    marginTop: 4,
  },
  metricCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    width: "48%",
    marginBottom: 10,
  },
  metricLabel: { fontSize: 13, fontWeight: "600", color: "#4cc9f0", marginBottom: 4 },
  metricValue: { fontSize: 22, fontWeight: "bold", color: "#e0e0e0" },
  metricValueNull: { color: "#555" },
  metricSublabel: { fontSize: 11, color: "#888", marginTop: 2 },
  empty: { flex: 1, justifyContent: "center", alignItems: "center", paddingTop: 80 },
  emptyText: { color: "#666", fontSize: 14 },
});
