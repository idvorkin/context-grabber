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
import type { WorkoutEntry } from "../lib/health";
import {
  METRIC_CONFIG,
  computeAverage,
  type MetricKey,
  type DailyValue,
  type HeartRateDaily,
  type MovementOverlayData,
} from "../lib/weekly";
import {
  computeSleepDebt,
  computeConsistencyStats,
  computeTrackingGap,
  pickDefaultSleepSource,
  SLEEP_ALL_SOURCES,
  SLEEP_STAGE_COLORS,
  type SleepDaily,
  type SleepDetailedBundle,
} from "../lib/sleep";
import { formatNumber } from "../lib/summary";
import BarChart from "./BarChart";
import LineChart from "./LineChart";
import ActivityTimelineChart from "./ActivityTimeline";
import HourlyBoxPlot from "./HourlyBoxPlot";
import SleepStageStrip from "./SleepStageStrip";
import SleepConsistencyChart from "./SleepConsistencyChart";
import ZoomedSleepDayCard from "./ZoomedSleepDayCard";
import type { ActivityTimeline } from "../lib/activity";

// ─── Types ────────────────────────────────────────────────────────────────────

type MetricDetailSheetProps = {
  metricKey: MetricKey;
  currentValue: string;
  currentSublabel: string;
  data: DailyValue[] | HeartRateDaily[] | null; // null = loading
  error: string | null;
  onClose: () => void;
  workouts?: WorkoutEntry[];
  workoutsByDay?: Record<string, WorkoutEntry[]>;
  activityTimelineByDay?: Record<string, ActivityTimeline>;
  /** Callback to fetch raw cached samples for debug view */
  fetchRawCache?: () => Promise<string>;
  /** Movement composite overlay (only used when metricKey === "movement") */
  movementData?: MovementOverlayData | null;
  /** Detailed per-source sleep bundle (only used when metricKey === "sleep") */
  sleepBundle?: SleepDetailedBundle | null;
  /** Sleep target in hours (for the debt line) */
  sleepTargetHours?: number | null;
  /** Resting heart rate weekly data + today's value, surfaced at the bottom
   *  of the Heart Rate detail sheet (since the metric grid no longer has a
   *  dedicated Resting HR card). Only consumed when metricKey === "heartRate". */
  restingHeartRateWeekly?: HeartRateDaily[] | null;
  restingHeartRateToday?: number | null;
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

function formatSleepDebt(debtHours: number, targetHours: number): string {
  if (debtHours <= 0) return "Sleep debt: 0m (caught up!)";
  const h = Math.floor(debtHours);
  const m = Math.round((debtHours - h) * 60);
  const debtStr = h > 0 && m > 0 ? `${h}h ${m}m` : h > 0 ? `${h}h` : `${m}m`;
  return `Sleep debt: \u2212${debtStr} over 7 days (target ${targetHours}h)`;
}

function sleepDebtColor(debtHours: number): string {
  if (debtHours <= 0) return "#8d99ae";
  if (debtHours > 4) return "#e63946";
  if (debtHours > 2) return "#f4845f";
  return "#8d99ae";
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function MetricDetailSheet({
  metricKey,
  currentValue,
  currentSublabel,
  data,
  error,
  onClose,
  workouts,
  workoutsByDay,
  activityTimelineByDay,
  fetchRawCache,
  movementData,
  sleepBundle,
  sleepTargetHours,
  restingHeartRateWeekly,
  restingHeartRateToday,
}: MetricDetailSheetProps): React.ReactElement {
  const isMovement = metricKey === "movement";
  const isSleep = metricKey === "sleep";
  const screenHeight = Dimensions.get("window").height;
  const config = METRIC_CONFIG[metricKey];

  // Sleep source tabs: "All" plus one per source in the bundle.
  const sleepSourceTabs = useMemo(() => {
    if (!sleepBundle) return [];
    const sorted = Object.keys(sleepBundle.bySource).sort();
    return [SLEEP_ALL_SOURCES, ...sorted];
  }, [sleepBundle]);

  const [selectedSource, setSelectedSource] = useState<string | null>(null);
  const [selectedDay, setSelectedDay] = useState<string | null>(null);
  const [debugVisible, setDebugVisible] = useState(false);
  const [rawCacheJson, setRawCacheJson] = useState<string | null>(null);

  // Default source: pick the one with the most stage detail the first time a
  // bundle arrives. "All" fallback handled by pickDefaultSleepSource.
  useEffect(() => {
    if (!isSleep || !sleepBundle) return;
    if (selectedSource !== null) return;
    setSelectedSource(pickDefaultSleepSource(sleepBundle));
  }, [isSleep, sleepBundle, selectedSource]);

  // Resolved SleepDaily[] for the currently selected source (or merged).
  const sleepDetailed: SleepDaily[] | null = useMemo(() => {
    if (!isSleep || !sleepBundle) return null;
    if (selectedSource === null || selectedSource === SLEEP_ALL_SOURCES) {
      return sleepBundle.merged;
    }
    return sleepBundle.bySource[selectedSource] ?? sleepBundle.merged;
  }, [isSleep, sleepBundle, selectedSource]);

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

  // ─── Sleep derived values ───────────────────────────────────────────────────

  const sleepDebt = useMemo(() => {
    if (!isSleep || !sleepDetailed || !sleepTargetHours) return null;
    return computeSleepDebt(sleepDetailed, sleepTargetHours);
  }, [isSleep, sleepDetailed, sleepTargetHours]);

  const sleepConsistency = useMemo(() => {
    if (!isSleep || !sleepDetailed) return null;
    return computeConsistencyStats(sleepDetailed);
  }, [isSleep, sleepDetailed]);

  // Selected night (for the zoom card). Null when no day is selected.
  const selectedSleepNight = useMemo(() => {
    if (!isSleep || !sleepDetailed || !selectedDay) return null;
    return sleepDetailed.find((n) => n.date === selectedDay) ?? null;
  }, [isSleep, sleepDetailed, selectedDay]);

  // Last-night stage percentages (from the most recent non-zero night)
  const lastNightStages = useMemo(() => {
    if (!isSleep || !sleepDetailed) return null;
    // Find the most recent night with any stage data
    for (let i = sleepDetailed.length - 1; i >= 0; i--) {
      const n = sleepDetailed[i];
      const total = n.coreHours + n.deepHours + n.remHours + n.awakeHours;
      if (total > 0) {
        return {
          corePct: Math.round((n.coreHours / total) * 100),
          deepPct: Math.round((n.deepHours / total) * 100),
          remPct: Math.round((n.remHours / total) * 100),
          awakePct: Math.round((n.awakeHours / total) * 100),
          coreHours: n.coreHours,
          deepHours: n.deepHours,
          remHours: n.remHours,
          awakeHours: n.awakeHours,
        };
      }
    }
    return null;
  }, [isSleep, sleepDetailed]);

  // ─── Average ────────────────────────────────────────────────────────────────

  let averageText: string | null = null;
  // Movement: compute 7-day avg/max for each of the three series
  type MovementStats = { avg: number | null; max: number | null };
  let movementStats: { steps: MovementStats; distance: MovementStats; energy: MovementStats } | null = null;
  if (isMovement && movementData && !error) {
    const statsFor = (values: (number | null)[]): MovementStats => {
      const nonNull = values.filter((v): v is number => v !== null);
      if (nonNull.length === 0) return { avg: null, max: null };
      const sum = nonNull.reduce((s, v) => s + v, 0);
      return { avg: sum / nonNull.length, max: Math.max(...nonNull) };
    };
    movementStats = {
      steps: statsFor(movementData.days.map((d) => d.steps)),
      distance: statsFor(movementData.days.map((d) => d.distanceKm)),
      energy: statsFor(movementData.days.map((d) => d.energyKcal)),
    };
  } else if (isSleep && !error) {
    // Sleep Avg must match the bars the user is seeing. The bars come from
    // sleepDetailed (noon-to-noon, filtered by selected source tab). Historical
    // bug: averaging `data` (aggregateSleep output, midnight-attribution,
    // all-sources merged) produced numbers 30%+ off from the bars — see
    // GitHub issue #28 / context-grabber-80y. Skip the legacy path entirely
    // for sleep even when sleepDetailed is still loading (leave Avg blank).
    if (sleepDetailed) {
      const hoursValues = sleepDetailed
        .map((n) => n.totalHours)
        .filter((v): v is number => v !== null);
      if (hoursValues.length > 0) {
        const avg = Math.round((hoursValues.reduce((s, v) => s + v, 0) / hoursValues.length) * 10) / 10;
        averageText = `Avg: ${avg} ${config.unit}/day`;
      }
    }
  } else if (data !== null && !error) {
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
  if (isSleep && sleepDetailed && !error) {
    // Sleep: show row with total + per-night stage strip below
    const reversedNights = [...sleepDetailed].reverse();
    dailyRows = reversedNights.map((night, index) => {
      const isSelected = selectedDay === night.date;
      const gapMinutes = computeTrackingGap(night);
      const gapLabel = gapMinutes != null
        ? gapMinutes >= 60
          ? `gap ${Math.floor(gapMinutes / 60)}h${gapMinutes % 60 ? ` ${gapMinutes % 60}m` : ""}`
          : `gap ${gapMinutes}m`
        : null;
      // Only surface onset when it's material (≥ 10 min) — short
      // pre-sleep windows aren't interesting and add visual clutter.
      const onsetLabel = night.onsetMinutes != null && night.onsetMinutes >= 10
        ? night.onsetMinutes >= 60
          ? `onset ${Math.floor(night.onsetMinutes / 60)}h${night.onsetMinutes % 60 ? ` ${night.onsetMinutes % 60}m` : ""}`
          : `onset ${night.onsetMinutes}m`
        : null;
      return (
        <TouchableOpacity
          key={night.date}
          activeOpacity={0.7}
          onPress={() => setSelectedDay(isSelected ? null : night.date)}
        >
          <View
            style={[
              styles.dayRow,
              index > 0 && styles.dayRowDivider,
              isSelected && { backgroundColor: config.color + "11" },
            ]}
          >
            <Text style={styles.dayRowLabel}>{formatDayRow(night.date)}</Text>
            <View style={{ flexDirection: "row", alignItems: "center", gap: 6 }}>
              {onsetLabel && (
                <Text
                  style={styles.sleepRowOnset}
                  accessibilityLabel={`Sleep onset: ${onsetLabel}`}
                  testID={`sleep-row-onset-${night.date}`}
                >
                  {onsetLabel}
                </Text>
              )}
              {gapLabel && (
                <Text
                  style={styles.sleepRowGap}
                  accessibilityLabel={`Tracker gap: ${gapLabel}`}
                  testID={`sleep-row-gap-${night.date}`}
                >
                  {"⚠"} {gapLabel}
                </Text>
              )}
              <Text style={styles.dayRowValue}>
                {night.totalHours != null ? `${night.totalHours}h` : "\u2014"}
              </Text>
            </View>
          </View>
          <SleepStageStrip
            samples={night.samples}
            bedtime={night.bedtime}
            wakeTime={night.wakeTime}
            height={18}
            labelSize={12}
            radius={6}
          />
        </TouchableOpacity>
      );
    });
  } else if (isMovement && movementData && !error) {
    // Movement: three values per day (steps, distance, energy)
    const reversedDays = [...movementData.days].reverse();
    dailyRows = reversedDays.map((d, index) => (
      <View key={d.dateKey} style={[styles.dayRow, index > 0 && styles.dayRowDivider, { flexDirection: "column", alignItems: "flex-start" }]}>
        <Text style={styles.dayRowLabel}>{formatDayRow(d.dateKey)}</Text>
        <View style={styles.movementRowValues}>
          <Text style={styles.movementValueText}>
            Steps: <Text style={styles.movementValueNum}>{d.steps != null ? formatNumber(d.steps) : "\u2014"}</Text>
          </Text>
          <Text style={styles.movementValueText}>
            Distance: <Text style={styles.movementValueNum}>{d.distanceKm != null ? `${d.distanceKm} km` : "\u2014"}</Text>
          </Text>
          <Text style={styles.movementValueText}>
            Energy: <Text style={styles.movementValueNum}>{d.energyKcal != null ? `${formatNumber(d.energyKcal)} kcal` : "\u2014"}</Text>
          </Text>
        </View>
      </View>
    ));
  } else if (data !== null && !error) {
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
  if (isMovement) {
    if (!movementData) {
      chartContent = (
        <View style={styles.chartPlaceholder}>
          <ActivityIndicator color={config.color} size="large" />
        </View>
      );
    } else {
      chartContent = (
        <LineChart
          dates={movementData.days.map((d) => d.dateKey)}
          series={[
            {
              label: "Steps",
              color: METRIC_CONFIG.steps.color,
              data: movementData.stepsNormalized,
              maxLabel: movementData.stepsMax > 0 ? `max ${formatNumber(movementData.stepsMax)}` : undefined,
            },
            {
              label: "Distance",
              color: METRIC_CONFIG.walkingDistance.color,
              data: movementData.distanceNormalized,
              maxLabel: movementData.distanceMax > 0 ? `max ${movementData.distanceMax} km` : undefined,
            },
            {
              label: "Energy",
              color: METRIC_CONFIG.activeEnergy.color,
              data: movementData.energyNormalized,
              maxLabel: movementData.energyMax > 0 ? `max ${formatNumber(movementData.energyMax)} kcal` : undefined,
            },
          ]}
          onDayPress={(date) => setSelectedDay(selectedDay === date ? null : date)}
          selectedDay={selectedDay}
        />
      );
    }
  } else if (data === null) {
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
  } else if (isSleep && sleepDetailed && sleepDetailed.length > 0) {
    chartContent = (
      <BarChart
        data={[]}
        color={config.color}
        unit={config.unit}
        onDayPress={(date) => setSelectedDay(selectedDay === date ? null : date)}
        selectedDay={selectedDay}
        stackedSleep={sleepDetailed}
        goalLine={sleepTargetHours ?? null}
      />
    );
  } else if (config.chartType === "bar") {
    chartContent = (
      <BarChart
        data={data as DailyValue[]}
        color={config.color}
        unit={config.unit}
        onDayPress={(date) => setSelectedDay(selectedDay === date ? null : date)}
        selectedDay={selectedDay}
      />
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
        {/* PanResponder zone: drag handle + header + current value only.
            Everything else lives in the ScrollView below for more scroll room. */}
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
        </View>

        {/* Everything below current value lives in the ScrollView */}
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Sleep source tabs */}
          {isSleep && sleepSourceTabs.length > 1 && (
            <View style={styles.sourceTabsRow}>
              {sleepSourceTabs.map((name) => (
                <TouchableOpacity
                  key={name}
                  style={[
                    styles.sourceTab,
                    selectedSource === name && {
                      backgroundColor: config.color + "33",
                      borderColor: config.color,
                    },
                  ]}
                  onPress={() => setSelectedSource(name)}
                >
                  <Text
                    style={[
                      styles.sourceTabText,
                      selectedSource === name && { color: config.color },
                    ]}
                  >
                    {name}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          )}

          {/* Activity timeline for exercise — shows selected day or today */}
          {metricKey === "exerciseMinutes" && activityTimelineByDay && Object.keys(activityTimelineByDay).length > 0 && (() => {
            const todayKey = data ? data[data.length - 1]?.date : null;
            const dayKey = selectedDay ?? todayKey;
            const timeline = dayKey ? activityTimelineByDay[dayKey] : null;
            return timeline ? (
              <View style={styles.chartContainer}>
                <ActivityTimelineChart timeline={timeline} color={config.color} />
              </View>
            ) : null;
          })()}

          {/* Hourly box plot for whisker-chart metrics when a day is selected */}
          {isWhiskerChart && selectedDayData && selectedDayData.raw.length > 0 && (
            <View style={styles.chartContainer}>
              <HourlyBoxPlot
                raw={selectedDayData.raw}
                color={config.color}
                label={`${formatDayRow(selectedDayData.date)} by Hour`}
              />
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

          {/* Movement: 7-day stats for each of the three series */}
          {isMovement && movementStats && (
            <View style={styles.movementStatsBlock}>
              <Text style={[styles.movementStatsRow, { color: METRIC_CONFIG.steps.color }]}>
                Steps: avg {movementStats.steps.avg != null ? formatNumber(Math.round(movementStats.steps.avg)) : "\u2014"}
                {movementStats.steps.max != null ? ` · max ${formatNumber(movementStats.steps.max)}` : ""}
              </Text>
              <Text style={[styles.movementStatsRow, { color: METRIC_CONFIG.walkingDistance.color }]}>
                Distance: avg {movementStats.distance.avg != null ? `${(Math.round(movementStats.distance.avg * 10) / 10)} km` : "\u2014"}
                {movementStats.distance.max != null ? ` · max ${movementStats.distance.max} km` : ""}
              </Text>
              <Text style={[styles.movementStatsRow, { color: METRIC_CONFIG.activeEnergy.color }]}>
                Energy: avg {movementStats.energy.avg != null ? `${formatNumber(Math.round(movementStats.energy.avg))} kcal` : "\u2014"}
                {movementStats.energy.max != null ? ` · max ${formatNumber(movementStats.energy.max)} kcal` : ""}
              </Text>
            </View>
          )}

          {/* Sleep: zoom card when a day is selected (supersedes the last-night stage row) */}
          {isSleep && selectedSleepNight && (
            <ZoomedSleepDayCard night={selectedSleepNight} color={config.color} />
          )}

          {/* Sleep: debt + stage percentages + consistency */}
          {isSleep && sleepDetailed && sleepDetailed.length > 0 && (
            <View style={styles.sleepStatsBlock}>
              {sleepDebt !== null && sleepTargetHours != null && (
                <Text style={[styles.sleepDebtLine, { color: sleepDebtColor(sleepDebt) }]}>
                  {formatSleepDebt(sleepDebt, sleepTargetHours)}
                </Text>
              )}
              {/* Hide last-night stage row while a day is zoomed — zoom card shows the same info */}
              {lastNightStages && !selectedSleepNight && (
                <View style={styles.stagePercentRow}>
                  {lastNightStages.coreHours > 0 && (
                    <Text style={[styles.stagePercentItem, { color: SLEEP_STAGE_COLORS.Core }]}>
                      Core {lastNightStages.corePct}%
                    </Text>
                  )}
                  {lastNightStages.deepHours > 0 && (
                    <Text style={[styles.stagePercentItem, { color: SLEEP_STAGE_COLORS.Deep }]}>
                      Deep {lastNightStages.deepPct}%
                    </Text>
                  )}
                  {lastNightStages.remHours > 0 && (
                    <Text style={[styles.stagePercentItem, { color: SLEEP_STAGE_COLORS.REM }]}>
                      REM {lastNightStages.remPct}%
                    </Text>
                  )}
                  {lastNightStages.awakeHours > 0 && (
                    <Text style={[styles.stagePercentItem, { color: SLEEP_STAGE_COLORS.Awake }]}>
                      Awake {lastNightStages.awakePct}%
                    </Text>
                  )}
                </View>
              )}
              {sleepConsistency && (
                <SleepConsistencyChart
                  nights={sleepDetailed}
                  bedtimeStdevMin={sleepConsistency.bedtimeStdevMinutes}
                  wakeStdevMin={sleepConsistency.wakeStdevMinutes}
                />
              )}
            </View>
          )}

          {/* Workout breakdown for exercise metric — selected day or today */}
          {metricKey === "exerciseMinutes" && (() => {
            const todayKey = data ? data[data.length - 1]?.date : null;
            const dayKey = selectedDay ?? todayKey;
            if (!dayKey) return null;
            const isToday = dayKey === todayKey;
            const dayWorkouts = isToday
              ? (workouts ?? [])
              : (workoutsByDay?.[dayKey] ?? []);
            const dayValue = (data as DailyValue[] | null)?.find((d) => d.date === dayKey);
            const totalMin = dayValue?.value ?? null;
            const headerLabel = isToday ? "Today" : formatDayRow(dayKey);
            const totalText = totalMin != null ? ` — ${totalMin} min total` : "";
            if (dayWorkouts.length === 0 && totalMin == null) return null;
            return (
              <View style={styles.workoutSection}>
                <Text style={[styles.workoutTitle, { color: config.color }]}>
                  {headerLabel}{totalText}
                </Text>
                {dayWorkouts.map((w, i) => (
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
            );
          })()}

          {/* Selected day raw values */}
          {selectedDayData && selectedDayData.raw.length > 0 && (
            <View style={styles.rawSection}>
              <Text style={[styles.rawTitle, { color: config.color }]}>
                {formatDayRow(selectedDayData.date)} — {selectedDayData.count} readings
              </Text>
              <Text style={styles.rawValues}>
                {[...selectedDayData.raw].sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime()).map((r) => `${Math.round(r.value)} (${new Date(r.time).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })})`).join(", ")}
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

          {/* Resting Heart Rate section — appears at the bottom of the Heart
              Rate sheet now that Resting HR no longer has its own card. */}
          {metricKey === "heartRate" && (restingHeartRateToday != null || (restingHeartRateWeekly && restingHeartRateWeekly.some((d) => d.avg !== null))) && (
            <View style={styles.restingHrSection} testID="resting-hr-section">
              <Text style={styles.restingHrTitle}>Resting Heart Rate</Text>
              <Text style={styles.restingHrLatest} testID="resting-hr-latest">
                {restingHeartRateToday != null
                  ? `${restingHeartRateToday} bpm latest`
                  : "— bpm latest"}
              </Text>
              {restingHeartRateWeekly && restingHeartRateWeekly.length > 0 && (
                <View style={styles.restingHrRows}>
                  {[...restingHeartRateWeekly].reverse().map((d, i) => (
                    <View
                      key={d.date}
                      style={[
                        styles.restingHrRow,
                        i > 0 && styles.dayRowDivider,
                      ]}
                    >
                      <Text style={styles.dayRowLabel}>{formatDayRow(d.date)}</Text>
                      <Text style={styles.dayRowValue}>
                        {d.avg != null ? `${Math.round(d.avg)} bpm` : "—"}
                      </Text>
                    </View>
                  ))}
                </View>
              )}
            </View>
          )}

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
    paddingVertical: 16,
    paddingHorizontal: 4,
  },
  dayRowDivider: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "#222",
  },
  dayRowLabel: {
    fontSize: 17,
    fontWeight: "600",
    color: "#e0e0e0",
  },
  dayRowValue: {
    fontSize: 17,
    color: "#aaa",
  },
  sleepRowGap: {
    fontSize: 11,
    color: "#b88a2a",
  },
  sleepRowOnset: {
    fontSize: 11,
    color: "#8d99ae",
  },
  sleepStatsBlock: {
    marginTop: 12,
    paddingHorizontal: 20,
    gap: 6,
  },
  restingHrSection: {
    marginTop: 24,
    paddingHorizontal: 20,
  },
  restingHrTitle: {
    color: "#888",
    fontSize: 13,
    fontWeight: "600",
    textTransform: "uppercase",
    letterSpacing: 1,
    marginBottom: 6,
  },
  restingHrLatest: {
    color: "#e0e0e0",
    fontSize: 18,
    fontWeight: "600",
    marginBottom: 8,
  },
  restingHrRows: {
    backgroundColor: "rgba(255,255,255,0.03)",
    borderRadius: 8,
  },
  restingHrRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  sleepDebtLine: {
    fontSize: 13,
    fontWeight: "600",
  },
  stagePercentRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
    marginTop: 2,
  },
  stagePercentItem: {
    fontSize: 12,
    fontWeight: "600",
  },
  movementStatsBlock: {
    marginTop: 12,
    paddingHorizontal: 20,
    gap: 4,
  },
  movementStatsRow: {
    fontSize: 13,
    fontWeight: "600",
  },
  movementRowValues: {
    marginTop: 6,
    gap: 2,
  },
  movementValueText: {
    fontSize: 13,
    color: "#888",
  },
  movementValueNum: {
    color: "#e0e0e0",
    fontWeight: "600",
  },
  sourceTabsRow: {
    flexDirection: "row",
    flexWrap: "wrap",
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
