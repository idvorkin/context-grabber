import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  Animated,
  Dimensions,
  Easing,
  Modal,
  PanResponder,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  TouchableWithoutFeedback,
  View,
  ActivityIndicator,
} from "react-native";
import type { SourceSleepSummary, WorkoutEntry } from "../lib/health";
import {
  METRIC_CONFIG,
  computeAverage,
  type MetricKey,
  type DailyValue,
  type HeartRateDaily,
} from "../lib/weekly";
import { formatNumber } from "../lib/summary";
import BarChart from "./BarChart";
import LineChart from "./LineChart";

// ─── Types ────────────────────────────────────────────────────────────────────

type MetricDetailSheetProps = {
  metricKey: MetricKey;
  currentValue: string;
  currentSublabel: string;
  data: DailyValue[] | HeartRateDaily[] | null; // null = loading
  error: string | null;
  onClose: () => void;
  sleepBySource?: Record<string, SourceSleepSummary> | null;
  workouts?: WorkoutEntry[];
  workoutsByDay?: Record<string, WorkoutEntry[]>;
  /** Callback to fetch raw cached samples for debug view */
  fetchRawCache?: () => Promise<string>;
};

// ─── Constants ────────────────────────────────────────────────────────────────

const DISMISS_THRESHOLD = 100;
const SWIPE_START_THRESHOLD = 10;
const ANIMATION_DURATION = 300;
const OVERLAY_MAX_OPACITY = 0.6;

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDayRow(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${days[d.getUTCDay()]}, ${months[d.getUTCMonth()]} ${d.getUTCDate()}`;
}

function isHeartRateData(
  data: DailyValue[] | HeartRateDaily[],
): data is HeartRateDaily[] {
  return data.length > 0 && "avg" in data[0];
}

function formatHeartRateRow(item: HeartRateDaily): string {
  if (item.avg === null) return "—";
  const avg = Math.round(item.avg);
  if (item.min !== null && item.max !== null) {
    return `${avg} avg (${Math.round(item.min)}–${Math.round(item.max)})`;
  }
  return `${avg}`;
}

function formatDailyValue(item: DailyValue, unit: string): string {
  if (item.value === null) return "—";
  const formatted = Number.isInteger(item.value)
    ? formatNumber(item.value)
    : item.value.toLocaleString("en-US", { maximumFractionDigits: 2 });
  return `${formatted} ${unit}`;
}

// ─── Component ────────────────────────────────────────────────────────────────

/** Format UTC ISO timestamp as local 12-hour time (intentional: users see sleep times in their timezone). */
function formatSleepTime(iso: string): string {
  const d = new Date(iso);
  const h = d.getHours();
  const m = d.getMinutes();
  const ampm = h >= 12 ? "PM" : "AM";
  const h12 = h % 12 || 12;
  return `${h12}:${m.toString().padStart(2, "0")} ${ampm}`;
}

export default function MetricDetailSheet({
  metricKey,
  currentValue,
  currentSublabel,
  data,
  error,
  onClose,
  sleepBySource,
  workouts,
  workoutsByDay,
  fetchRawCache,
}: MetricDetailSheetProps): React.ReactElement {
  const screenHeight = Dimensions.get("window").height;
  const config = METRIC_CONFIG[metricKey];
  const sourceNames = useMemo(
    () => (sleepBySource ? Object.keys(sleepBySource) : []),
    [sleepBySource],
  );
  const [selectedSource, setSelectedSource] = useState<string | null>(null);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);
  const [debugVisible, setDebugVisible] = useState(false);
  const [rawCacheJson, setRawCacheJson] = useState<string | null>(null);

  const isWhiskerChart = data && data.length > 0 && "avg" in data[0];

  // Get raw values for the selected day
  const selectedDayData = useMemo(() => {
    if (!selectedDay || !isWhiskerChart) return null;
    const dayItem = (data as HeartRateDaily[]).find((d) => d.date === selectedDay);
    return dayItem ?? null;
  }, [selectedDay, data, isWhiskerChart]);

  // Build debug JSON for all metric types
  const debugJson = useMemo(() => {
    if (!data || data.length === 0) return "";
    if (isWhiskerChart) {
      return JSON.stringify(
        (data as HeartRateDaily[]).map((d) => ({
          date: d.date, count: d.count,
          min: d.min, q1: d.q1, median: d.median, q3: d.q3, max: d.max, avg: d.avg,
          raw: d.raw,
        })),
        null, 2,
      );
    }
    return JSON.stringify(
      (data as DailyValue[]).map((d) => ({ date: d.date, value: d.value })),
      null, 2,
    );
  }, [data, isWhiskerChart]);

  // Update selected source when sleepBySource data arrives
  useEffect(() => {
    if (sourceNames.length > 0 && selectedSource === null) {
      setSelectedSource(sourceNames[0]);
    }
  }, [sourceNames, selectedSource]);

  // Single animated value drives translateY (0 = visible) and overlay opacity.
  const animValue = useRef(new Animated.Value(0)).current;

  // Secondary animated value for snap-back during pan gesture.
  const panOffset = useRef(new Animated.Value(0)).current;

  // Entry animation on mount.
  useEffect(() => {
    Animated.timing(animValue, {
      toValue: 1,
      duration: ANIMATION_DURATION,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start();
  }, [animValue]);

  function dismiss() {
    Animated.timing(animValue, {
      toValue: 0,
      duration: ANIMATION_DURATION,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start(() => onClose());
  }

  // Derived animated styles from animValue (0 = offscreen, 1 = visible).
  const sheetTranslateY = animValue.interpolate({
    inputRange: [0, 1],
    outputRange: [screenHeight, 0],
  });

  const overlayOpacity = animValue.interpolate({
    inputRange: [0, 1],
    outputRange: [0, OVERLAY_MAX_OPACITY],
  });

  // Combined translateY: entry animation + pan offset.
  const combinedTranslateY = Animated.add(sheetTranslateY, panOffset);

  // PanResponder for swipe-to-dismiss on header+chart zone only.
  const panResponder = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_evt, gestureState) =>
        gestureState.dy > SWIPE_START_THRESHOLD,
      onPanResponderMove: (_evt, gestureState) => {
        // Clamp to >= 0 (no upward drag past 0).
        const clamped = Math.max(0, gestureState.dy);
        panOffset.setValue(clamped);
      },
      onPanResponderRelease: (_evt, gestureState) => {
        if (gestureState.dy > DISMISS_THRESHOLD) {
          dismiss();
        } else {
          // Snap back.
          Animated.timing(panOffset, {
            toValue: 0,
            duration: 200,
            easing: Easing.out(Easing.cubic),
            useNativeDriver: true,
          }).start();
        }
      },
      onPanResponderTerminate: () => {
        Animated.timing(panOffset, {
          toValue: 0,
          duration: 200,
          easing: Easing.out(Easing.cubic),
          useNativeDriver: true,
        }).start();
      },
    }),
  ).current;

  // ─── Average ────────────────────────────────────────────────────────────────

  let averageText: string | null = null;
  if (data !== null && !error) {
    if (isHeartRateData(data)) {
      // Build DailyValue array from avg values for computeAverage.
      const asDaily: DailyValue[] = data.map((d) => ({
        date: d.date,
        value: d.avg,
      }));
      const avg = computeAverage(asDaily);
      if (avg !== null) {
        averageText = `Avg: ${formatNumber(Math.round(avg))} ${config.unit}/day`;
      }
    } else {
      const avg = computeAverage(data);
      if (avg !== null) {
        const formatted = Number.isInteger(avg)
          ? formatNumber(avg)
          : avg.toLocaleString("en-US", { maximumFractionDigits: 2 });
        averageText = `Avg: ${formatted} ${config.unit}/day`;
      }
    }
  }

  // ─── Daily rows (most recent first) ─────────────────────────────────────────

  let dailyRows: React.ReactElement[] | null = null;
  if (data !== null && !error) {
    const reversed = [...data].reverse();
    const isHR = isHeartRateData(reversed as DailyValue[] | HeartRateDaily[]);

    dailyRows = reversed.map((item, index) => {
      const dayLabel = formatDayRow(item.date);
      const valueLabel = isHR
        ? formatHeartRateRow(item as HeartRateDaily)
        : formatDailyValue(item as DailyValue, config.unit);
      const dayWorkouts = metricKey === "exerciseMinutes" ? workoutsByDay?.[item.date] : undefined;

      return (
        <View key={item.date}>
          <View
            style={[styles.dayRow, index > 0 && styles.dayRowDivider]}
          >
            <Text style={styles.dayRowLabel}>{dayLabel}</Text>
            <Text style={styles.dayRowValue}>{valueLabel}</Text>
          </View>
          {dayWorkouts && dayWorkouts.length > 0 && (
            <View style={styles.dayWorkouts}>
              {dayWorkouts.map((w, wi) => (
                <View key={wi} style={styles.dayWorkoutRow}>
                  <Text style={styles.dayWorkoutName}>{w.activityType}</Text>
                  <View style={styles.workoutDetails}>
                    <Text style={styles.workoutPill}>{w.durationMinutes}m</Text>
                    {w.energyBurned != null && <Text style={styles.workoutPill}>{w.energyBurned} kcal</Text>}
                    {w.distanceKm != null && <Text style={styles.workoutPill}>{w.distanceKm} km</Text>}
                  </View>
                </View>
              ))}
            </View>
          )}
        </View>
      );
    });
  }

  // ─── Chart ──────────────────────────────────────────────────────────────────

  let chartContent: React.ReactElement;
  if (data === null) {
    chartContent = (
      <View style={styles.chartPlaceholder}>
        <ActivityIndicator color={config.color} size="large" />
      </View>
    );
  } else if (error) {
    chartContent = (
      <View style={styles.chartPlaceholder}>
        <Text style={styles.errorText}>{error}</Text>
      </View>
    );
  } else if (config.chartType === "bar") {
    chartContent = (
      <BarChart data={data as DailyValue[]} color={config.color} unit={config.unit} />
    );
  } else {
    chartContent = (
      <LineChart
        data={data}
        color={config.color}
        unit={config.unit}
        onDayPress={(date) => setSelectedDay(selectedDay === date ? null : date)}
        selectedDay={selectedDay}
      />
    );
  }

  // ─── Render ─────────────────────────────────────────────────────────────────

  return (
    <View style={StyleSheet.absoluteFill}>
      {/* Overlay — taps dismiss */}
      <TouchableWithoutFeedback onPress={dismiss}>
        <Animated.View style={[styles.overlay, { opacity: overlayOpacity }]} />
      </TouchableWithoutFeedback>

      {/* Sheet */}
      <Animated.View
        style={[
          styles.sheet,
          { transform: [{ translateY: combinedTranslateY }] },
        ]}
      >
        {/* PanResponder zone: drag handle + header + current value + chart */}
        <View {...panResponder.panHandlers}>
          {/* Drag handle */}
          <View style={styles.dragHandleRow}>
            <View style={styles.dragHandle} />
          </View>

          {/* Header */}
          <View style={styles.header}>
            <Text style={[styles.headerTitle, { color: config.color }]}>
              {config.label}
            </Text>
            <Text style={styles.closeButton} onPress={dismiss}>
              ✕
            </Text>
          </View>

          {/* Current value */}
          <View style={styles.currentValueContainer}>
            <Text style={styles.currentValue}>{currentValue}</Text>
            <Text style={styles.currentSublabel}>{currentSublabel}</Text>
          </View>

          {/* Sleep source tabs */}
          {metricKey === "sleep" && sourceNames.length > 0 && (
            <View style={styles.sourceSection}>
              <View style={styles.sourceTabs}>
                {sourceNames.map((name) => (
                  <TouchableOpacity
                    key={name}
                    style={[
                      styles.sourceTab,
                      selectedSource === name && { backgroundColor: config.color + "33", borderColor: config.color },
                    ]}
                    onPress={() => setSelectedSource(name)}
                  >
                    <Text style={[styles.sourceTabText, selectedSource === name && { color: config.color }]}>
                      {name}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
              {selectedSource && sleepBySource?.[selectedSource] && (() => {
                const s = sleepBySource[selectedSource];
                return (
                  <View style={styles.sourceDetail}>
                    <Text style={styles.sourceDetailRow}>
                      {formatSleepTime(s.bedtime)} → {formatSleepTime(s.wakeTime)}
                    </Text>
                    <View style={styles.stageRow}>
                      {s.deepHours > 0 && <Text style={styles.stagePill}>Deep {s.deepHours}h</Text>}
                      {s.coreHours > 0 && <Text style={styles.stagePill}>Core {s.coreHours}h</Text>}
                      {s.remHours > 0 && <Text style={styles.stagePill}>REM {s.remHours}h</Text>}
                      {s.awakeHours > 0 && <Text style={[styles.stagePill, { color: "#f4845f" }]}>Awake {s.awakeHours}h</Text>}
                    </View>
                  </View>
                );
              })()}
            </View>
          )}

          {/* Chart */}
          <View style={styles.chartContainer}>{chartContent}</View>

          {/* Average line */}
          {averageText !== null && (
            <Text style={[styles.averageText, { color: config.color }]}>
              {averageText}
            </Text>
          )}
        </View>

        {/* Workout breakdown for exercise metric */}
        {metricKey === "exerciseMinutes" && workouts && workouts.length > 0 && (
          <View style={styles.workoutSection}>
            <Text style={[styles.workoutTitle, { color: config.color }]}>Today's Workouts</Text>
            {workouts.map((w, i) => (
              <View key={i} style={styles.workoutRow}>
                <Text style={styles.workoutName}>{w.activityType}</Text>
                <View style={styles.workoutDetails}>
                  <Text style={styles.workoutPill}>{w.durationMinutes} min</Text>
                  {w.energyBurned != null && <Text style={styles.workoutPill}>{w.energyBurned} kcal</Text>}
                  {w.distanceKm != null && <Text style={styles.workoutPill}>{w.distanceKm} km</Text>}
                </View>
              </View>
            ))}
          </View>
        )}

        {/* Daily breakdown — separate from PanResponder */}
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Selected day raw values */}
          {selectedDayData && selectedDayData.raw.length > 0 && (
            <View style={styles.rawSection}>
              <Text style={[styles.rawTitle, { color: config.color }]}>
                {formatDayRow(selectedDayData.date)} — {selectedDayData.count} readings
              </Text>
              <Text style={styles.rawValues}>
                {selectedDayData.raw.map((r) => `${r.value} (${new Date(r.time).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })})`).join(", ")}
              </Text>
              <View style={styles.rawStats}>
                <Text style={styles.rawStatPill}>Min {selectedDayData.min}</Text>
                <Text style={styles.rawStatPill}>Q1 {selectedDayData.q1}</Text>
                <Text style={styles.rawStatPill}>Med {selectedDayData.median}</Text>
                <Text style={styles.rawStatPill}>Q3 {selectedDayData.q3}</Text>
                <Text style={styles.rawStatPill}>Max {selectedDayData.max}</Text>
              </View>
            </View>
          )}

          {dailyRows}

          {/* Debug button — available for all metrics */}
          {data && data.length > 0 && (
            <View style={styles.debugSection}>
              <TouchableOpacity
                onPress={() => {
                  setDebugVisible(true);
                  if (fetchRawCache) {
                    setRawCacheJson("Loading...");
                    fetchRawCache().then(setRawCacheJson).catch((e) => setRawCacheJson(`Error: ${e.message}`));
                  }
                }}
                style={styles.debugToggle}
              >
                <Text style={styles.debugToggleText}>Debug</Text>
              </TouchableOpacity>
            </View>
          )}
        </ScrollView>

        {/* Debug full-screen modal */}
        <Modal
          visible={debugVisible}
          animationType="slide"
          presentationStyle="pageSheet"
          onRequestClose={() => setDebugVisible(false)}
        >
          <View style={styles.debugModal}>
            <View style={styles.debugModalHeader}>
              <Text style={[styles.debugModalTitle, { color: config.color }]}>
                {config.label} — Raw Data
              </Text>
              <TouchableOpacity onPress={() => setDebugVisible(false)}>
                <Text style={styles.debugModalClose}>Done</Text>
              </TouchableOpacity>
            </View>
            <View style={styles.debugModalActions}>
              <TouchableOpacity
                style={styles.debugShareButton}
                onPress={() => {
                  const full = rawCacheJson
                    ? `=== COMPUTED ===\n${debugJson}\n\n=== RAW CACHE ===\n${rawCacheJson}`
                    : debugJson;
                  Share.share({ message: full });
                }}
              >
                <Text style={styles.debugShareText}>Copy / Share</Text>
              </TouchableOpacity>
            </View>
            <ScrollView style={styles.debugModalScroll}>
              <Text style={[styles.debugModalTitle, { marginBottom: 8 }]}>Computed</Text>
              <Text style={styles.debugJson} selectable>
                {debugJson}
              </Text>
              {rawCacheJson && (
                <>
                  <Text style={[styles.debugModalTitle, { marginTop: 16, marginBottom: 8 }]}>Raw Cache</Text>
                  <Text style={styles.debugJson} selectable>
                    {rawCacheJson}
                  </Text>
                </>
              )}
            </ScrollView>
          </View>
        </Modal>
      </Animated.View>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  overlay: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "black",
  },
  sheet: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: "#111828",
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    maxHeight: "90%",
  },
  dragHandleRow: {
    alignItems: "center",
    paddingTop: 12,
    paddingBottom: 8,
  },
  dragHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: "#444",
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingBottom: 8,
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: "600",
  },
  closeButton: {
    fontSize: 18,
    color: "#888",
    paddingLeft: 16,
    paddingVertical: 4,
  },
  currentValueContainer: {
    paddingHorizontal: 20,
    paddingBottom: 12,
  },
  currentValue: {
    fontSize: 36,
    fontWeight: "700",
    color: "#e0e0e0",
  },
  currentSublabel: {
    fontSize: 13,
    color: "#888",
    marginTop: 2,
  },
  chartContainer: {
    paddingHorizontal: 20,
    paddingBottom: 8,
  },
  chartPlaceholder: {
    height: 230,
    justifyContent: "center",
    alignItems: "center",
  },
  errorText: {
    color: "#888",
    fontSize: 14,
    textAlign: "center",
  },
  averageText: {
    fontSize: 14,
    fontWeight: "600",
    textAlign: "center",
    paddingBottom: 12,
  },
  scrollView: {
    flexShrink: 1,
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingBottom: 32,
  },
  dayRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 12,
  },
  dayRowDivider: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "#222",
  },
  dayRowLabel: {
    fontSize: 15,
    fontWeight: "600",
    color: "#e0e0e0",
  },
  dayRowValue: {
    fontSize: 15,
    color: "#aaa",
  },
  sourceSection: {
    paddingHorizontal: 20,
    paddingBottom: 12,
  },
  sourceTabs: {
    flexDirection: "row",
    gap: 8,
    marginBottom: 10,
  },
  sourceTab: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: "#333",
  },
  sourceTabText: {
    fontSize: 13,
    fontWeight: "600",
    color: "#888",
  },
  sourceDetail: {
    paddingVertical: 4,
  },
  sourceDetailRow: {
    fontSize: 15,
    color: "#e0e0e0",
    marginBottom: 8,
  },
  stageRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  stagePill: {
    fontSize: 13,
    color: "#aaa",
    backgroundColor: "#222",
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    overflow: "hidden",
  },
  rawSection: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#222",
    backgroundColor: "#1a1f2e",
  },
  rawTitle: {
    fontSize: 14,
    fontWeight: "600",
    marginBottom: 6,
  },
  rawValues: {
    fontSize: 12,
    color: "#aaa",
    fontFamily: "Courier",
    lineHeight: 18,
    marginBottom: 8,
  },
  rawStats: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 6,
  },
  rawStatPill: {
    fontSize: 11,
    color: "#ccc",
    backgroundColor: "#2a2f3e",
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    overflow: "hidden",
  },
  workoutSection: {
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 8,
  },
  workoutTitle: {
    fontSize: 14,
    fontWeight: "600",
    marginBottom: 8,
  },
  workoutRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#333",
  },
  workoutName: {
    color: "#fff",
    fontSize: 15,
    fontWeight: "500",
  },
  workoutDetails: {
    flexDirection: "row",
    gap: 6,
  },
  workoutPill: {
    color: "#aaa",
    fontSize: 13,
    backgroundColor: "#2a2f3e",
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    overflow: "hidden",
  },
  dayWorkouts: {
    paddingHorizontal: 20,
    paddingBottom: 8,
  },
  dayWorkoutRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 3,
  },
  dayWorkoutName: {
    color: "#aaa",
    fontSize: 13,
  },
  debugSection: {
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 20,
    alignItems: "center",
  },
  debugToggle: {
    paddingVertical: 6,
    paddingHorizontal: 16,
  },
  debugToggleText: {
    fontSize: 12,
    color: "#666",
  },
  debugModal: {
    flex: 1,
    backgroundColor: "#111828",
  },
  debugModalHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#333",
  },
  debugModalTitle: {
    fontSize: 16,
    fontWeight: "600",
  },
  debugModalClose: {
    fontSize: 16,
    color: "#4cc9f0",
    fontWeight: "600",
  },
  debugModalActions: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    alignItems: "center",
  },
  debugModalScroll: {
    flex: 1,
    paddingHorizontal: 16,
  },
  debugShareButton: {
    backgroundColor: "#2a2f3e",
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 8,
  },
  debugShareText: {
    fontSize: 13,
    color: "#aaa",
  },
  debugJson: {
    fontSize: 11,
    color: "#aaa",
    fontFamily: "Courier",
    lineHeight: 16,
  },
});
