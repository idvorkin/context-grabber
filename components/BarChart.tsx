import React from "react";
import { View, Text, StyleSheet, TouchableOpacity } from "react-native";
import { type DailyValue, formatDateKey } from "../lib/weekly";
import type { SleepDaily } from "../lib/sleep";
import { SLEEP_STAGE_COLORS } from "../lib/sleep";

// ─── Constants ────────────────────────────────────────────────────────────────

const CHART_HEIGHT = 200;
const LABEL_HEIGHT = 30;
const BAR_RADIUS = 4;
const DASH_HEIGHT = 2;

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// ─── Props ────────────────────────────────────────────────────────────────────

type Props = {
  data: DailyValue[];
  color: string;
  unit: string;
  onDayPress?: (date: string) => void;
  selectedDay?: string | null;
  /** Sleep-specific stacked-stage rendering. When present, overrides `data`. */
  stackedSleep?: SleepDaily[];
  /** Horizontal goal line value in the same units as the bar data. */
  goalLine?: number | null;
};

// ─── BarChart ─────────────────────────────────────────────────────────────────

export default function BarChart({
  data,
  color,
  unit,
  onDayPress,
  selectedDay,
  stackedSleep,
  goalLine,
}: Props): React.JSX.Element {
  const today = formatDateKey(new Date());

  // Stacked sleep mode: render per-night bars split into Core/Deep/REM/Awake.
  if (stackedSleep && stackedSleep.length > 0) {
    return renderStackedSleep({
      nights: stackedSleep,
      today,
      onDayPress,
      selectedDay,
      goalLine: goalLine ?? null,
      unit,
    });
  }

  // Compute the max value across the week (non-null only).
  const maxValue = data.reduce<number>((acc, d) => {
    if (d.value !== null && d.value > acc) return d.value;
    return acc;
  }, 0);

  // Dim color for non-today bars: append "4D" (30% opacity) to the hex string.
  const dimColor = `${color}4D`;

  return (
    <View style={styles.container}>
      {/* Bar area */}
      <View style={[styles.chartArea, { height: CHART_HEIGHT }]}>
        {data.map((day) => {
          const isToday = day.date === today;
          const isSelected = day.date === selectedDay;
          const barColor = isSelected ? color : isToday ? color : dimColor;

          // Determine the day-of-week label by parsing date as UTC midnight.
          const parsed = new Date(`${day.date}T00:00:00Z`);
          const dayLabel = DAY_LABELS[parsed.getUTCDay()];

          const Wrapper = onDayPress ? TouchableOpacity : View;
          const wrapperProps = onDayPress ? { onPress: () => onDayPress(day.date), activeOpacity: 0.7 } : {};

          if (day.value === null) {
            return (
              <Wrapper key={day.date} style={styles.barColumn} {...wrapperProps}>
                <View style={styles.barWrapper}>
                  <View style={[styles.dash, { backgroundColor: barColor }]} />
                </View>
                <Text style={[styles.dayLabel, (isToday || isSelected) && { color }]}>
                  {dayLabel}
                </Text>
                {isSelected && <View style={[styles.selectedDot, { backgroundColor: color }]} />}
              </Wrapper>
            );
          }

          const heightFraction = maxValue > 0 ? day.value / maxValue : 0;
          const barHeight = Math.max(4, Math.round(heightFraction * CHART_HEIGHT));

          return (
            <Wrapper key={day.date} style={styles.barColumn} {...wrapperProps}>
              <View style={styles.barWrapper}>
                <View style={[styles.bar, { height: barHeight, backgroundColor: barColor, borderRadius: BAR_RADIUS }]} />
              </View>
              <Text style={[styles.dayLabel, (isToday || isSelected) && { color }]}>
                {dayLabel}
              </Text>
              {isSelected && <View style={[styles.selectedDot, { backgroundColor: color }]} />}
            </Wrapper>
          );
        })}
      </View>

      {/* Unit label */}
      <Text style={styles.unitLabel}>{unit}</Text>
    </View>
  );
}

// ─── Stacked sleep rendering ──────────────────────────────────────────────────

type StackedSleepArgs = {
  nights: SleepDaily[];
  today: string;
  onDayPress?: (date: string) => void;
  selectedDay?: string | null;
  goalLine: number | null;
  unit: string;
};

function renderStackedSleep({ nights, today, onDayPress, selectedDay, goalLine, unit }: StackedSleepArgs): React.JSX.Element {
  // Max hours for vertical scale — include the goal line so it's never off-chart.
  const maxHours = nights.reduce<number>((acc, n) => {
    const total = (n.coreHours || 0) + (n.deepHours || 0) + (n.remHours || 0) + (n.awakeHours || 0);
    return total > acc ? total : acc;
  }, goalLine ?? 0);
  const safeMax = maxHours > 0 ? maxHours : 1;

  return (
    <View style={styles.container}>
      <View style={[styles.chartArea, { height: CHART_HEIGHT }]}>
        {/* Goal line */}
        {goalLine !== null && goalLine > 0 && goalLine <= maxHours && (
          <View
            pointerEvents="none"
            style={[
              styles.goalLine,
              { bottom: LABEL_HEIGHT + (goalLine / safeMax) * (CHART_HEIGHT - LABEL_HEIGHT) },
            ]}
          />
        )}

        {nights.map((night) => {
          const isToday = night.date === today;
          const isSelected = night.date === selectedDay;
          const parsed = new Date(`${night.date}T00:00:00Z`);
          const dayLabel = DAY_LABELS[parsed.getUTCDay()];

          const Wrapper = onDayPress ? TouchableOpacity : View;
          const wrapperProps = onDayPress ? { onPress: () => onDayPress(night.date), activeOpacity: 0.7 } : {};

          const total = (night.coreHours || 0) + (night.deepHours || 0) + (night.remHours || 0) + (night.awakeHours || 0);
          if (total <= 0) {
            return (
              <Wrapper key={night.date} style={styles.barColumn} {...wrapperProps}>
                <View style={styles.barWrapper}>
                  <View style={[styles.dash, { backgroundColor: "#555" }]} />
                </View>
                <Text style={[styles.dayLabel, (isToday || isSelected) && { color: "#e0e0e0" }]}>
                  {dayLabel}
                </Text>
                {isSelected && <View style={[styles.selectedDot, { backgroundColor: "#e0e0e0" }]} />}
              </Wrapper>
            );
          }

          const usableHeight = CHART_HEIGHT - LABEL_HEIGHT;
          const totalBarHeight = Math.max(4, Math.round((total / safeMax) * usableHeight));

          // Segment heights, proportional to each stage within the day's bar
          const coreH = Math.round((night.coreHours / total) * totalBarHeight);
          const deepH = Math.round((night.deepHours / total) * totalBarHeight);
          const remH = Math.round((night.remHours / total) * totalBarHeight);
          const awakeH = Math.max(0, totalBarHeight - coreH - deepH - remH);

          const dim = isSelected || isToday ? 1 : 0.75;

          return (
            <Wrapper key={night.date} style={styles.barColumn} {...wrapperProps}>
              <View style={styles.barWrapper}>
                <View style={{ width: "60%", height: totalBarHeight, borderRadius: BAR_RADIUS, overflow: "hidden", opacity: dim }}>
                  {/* Awake on top, then REM, Deep, Core on bottom */}
                  {awakeH > 0 && <View style={{ height: awakeH, backgroundColor: SLEEP_STAGE_COLORS.Awake }} />}
                  {remH > 0 && <View style={{ height: remH, backgroundColor: SLEEP_STAGE_COLORS.REM }} />}
                  {deepH > 0 && <View style={{ height: deepH, backgroundColor: SLEEP_STAGE_COLORS.Deep }} />}
                  {coreH > 0 && <View style={{ height: coreH, backgroundColor: SLEEP_STAGE_COLORS.Core }} />}
                </View>
                <Text style={styles.barTotalLabel}>
                  {night.totalHours != null ? night.totalHours.toFixed(1) : ""}
                </Text>
              </View>
              <Text style={[styles.dayLabel, (isToday || isSelected) && { color: "#e0e0e0" }]}>
                {dayLabel}
              </Text>
              {isSelected && <View style={[styles.selectedDot, { backgroundColor: "#e0e0e0" }]} />}
            </Wrapper>
          );
        })}
      </View>

      <Text style={styles.unitLabel}>{unit}</Text>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    width: "100%",
  },
  chartArea: {
    flexDirection: "row",
    alignItems: "flex-end",
    paddingBottom: LABEL_HEIGHT,
  },
  barColumn: {
    flex: 1,
    alignItems: "center",
  },
  barWrapper: {
    flex: 1,
    justifyContent: "flex-end",
    alignItems: "center",
    width: "100%",
  },
  bar: {
    width: "60%",
  },
  dash: {
    width: "40%",
    height: DASH_HEIGHT,
    borderRadius: 1,
  },
  dayLabel: {
    position: "absolute",
    bottom: 0,
    fontSize: 11,
    color: "#666",
    textAlign: "center",
    height: LABEL_HEIGHT,
    lineHeight: LABEL_HEIGHT,
  },
  selectedDot: {
    position: "absolute",
    bottom: 22,
    width: 4,
    height: 4,
    borderRadius: 2,
  },
  unitLabel: {
    fontSize: 11,
    color: "#888",
    textAlign: "center",
    marginTop: 4,
  },
  barTotalLabel: {
    fontSize: 10,
    color: "#aaa",
    marginTop: 2,
    textAlign: "center",
  },
  goalLine: {
    position: "absolute",
    left: 0,
    right: 0,
    height: 1,
    borderStyle: "dashed",
    borderWidth: 0.5,
    borderColor: "#8d99ae",
    opacity: 0.5,
  },
});
