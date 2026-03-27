import React from "react";
import { View, Text, StyleSheet, TouchableOpacity, type DimensionValue } from "react-native";
import { type DailyValue, type HeartRateDaily, formatDateKey } from "../lib/weekly";

// ─── Types ────────────────────────────────────────────────────────────────────

type Props = {
  data: DailyValue[] | HeartRateDaily[];
  color: string;
  unit: string;
  onDayPress?: (date: string) => void;
  selectedDay?: string | null;
};

// ─── Constants ────────────────────────────────────────────────────────────────

const CHART_HEIGHT = 200;
const LABEL_HEIGHT = 30;
const DOT_RADIUS = 5;
const PADDING_V = 10; // vertical padding inside chart area
const BOX_WIDTH = 20;
const WHISKER_WIDTH = 10;

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function isHeartRateData(data: DailyValue[] | HeartRateDaily[]): data is HeartRateDaily[] {
  return data.length > 0 && "avg" in data[0];
}

function getDayLabel(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  return DAY_LABELS[d.getUTCDay()];
}

function getPrimaryValue(item: DailyValue | HeartRateDaily): number | null {
  if ("avg" in item) return item.avg;
  return item.value;
}

function valueToRatio(value: number, min: number, max: number): number {
  if (max === min) return 0.5;
  return (max - value) / (max - min);
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function LineChart({ data, color, unit, onDayPress, selectedDay }: Props): React.ReactElement {
  const today = formatDateKey(new Date());
  const isHR = isHeartRateData(data);

  const allValues: number[] = data
    .map((item) => getPrimaryValue(item))
    .filter((v): v is number => v !== null);

  const allNull = allValues.length === 0;

  if (allNull) {
    return (
      <View style={styles.container}>
        <View style={styles.noDataContainer}>
          <Text style={styles.noDataText}>No data</Text>
        </View>
      </View>
    );
  }

  // Include whisker extremes in scale.
  const scaleValues = [...allValues];
  if (isHR) {
    for (const item of data as HeartRateDaily[]) {
      if (item.min !== null) scaleValues.push(item.min);
      if (item.max !== null) scaleValues.push(item.max);
    }
  }

  const scaleMin = Math.min(...scaleValues);
  const scaleMax = Math.max(...scaleValues);
  const usableHeight = CHART_HEIGHT - PADDING_V * 2;

  function ratioToTop(value: number): number {
    return PADDING_V + valueToRatio(value, scaleMin, scaleMax) * usableHeight;
  }

  const count = data.length;
  function leftPercent(i: number): DimensionValue {
    return `${(i / Math.max(count - 1, 1)) * 100}%` as DimensionValue;
  }

  return (
    <View style={styles.container}>
      <View style={[styles.chartArea, { height: CHART_HEIGHT }]}>
        {data.map((item, i) => {
          const primaryVal = getPrimaryValue(item);
          const isToday = item.date === today;
          const dotColor = isToday ? color : `${color}99`;
          const left = leftPercent(i);

          if (isHR) {
            const hr = item as HeartRateDaily;
            if (hr.q1 === null || hr.q3 === null || hr.median === null || hr.min === null || hr.max === null) {
              return null;
            }

            const whiskerTop = ratioToTop(hr.max);
            const whiskerBottom = ratioToTop(hr.min);
            const boxTop = ratioToTop(hr.q3);
            const boxBottom = ratioToTop(hr.q1);
            const medianTop = ratioToTop(hr.median);
            const isSelected = selectedDay === item.date;
            const opacity = isSelected ? 1 : (isToday ? 0.9 : 0.6);

            const whiskerContent = (
              <>
                {/* Whisker line (min to max) */}
                <View
                  style={[styles.whiskerLine, {
                    left: "50%",
                    top: whiskerTop,
                    height: Math.max(whiskerBottom - whiskerTop, 1),
                    transform: [{ translateX: -1 }],
                    backgroundColor: `${color}66`,
                  }]}
                />
                {/* Top whisker cap */}
                <View
                  style={[styles.whiskerCap, {
                    left: "50%",
                    top: whiskerTop,
                    transform: [{ translateX: -WHISKER_WIDTH / 2 }],
                    backgroundColor: `${color}66`,
                  }]}
                />
                {/* Bottom whisker cap */}
                <View
                  style={[styles.whiskerCap, {
                    left: "50%",
                    top: whiskerBottom,
                    transform: [{ translateX: -WHISKER_WIDTH / 2 }],
                    backgroundColor: `${color}66`,
                  }]}
                />
                {/* Box (Q1 to Q3) */}
                <View
                  style={[styles.box, {
                    left: "50%",
                    top: boxTop,
                    height: Math.max(boxBottom - boxTop, 2),
                    transform: [{ translateX: -BOX_WIDTH / 2 }],
                    backgroundColor: isSelected ? `${color}55` : `${color}33`,
                    borderColor: isSelected || isToday ? color : `${color}88`,
                    borderWidth: isSelected ? 2 : 1,
                  }]}
                />
                {/* Median line */}
                <View
                  style={[styles.medianLine, {
                    left: "50%",
                    top: medianTop,
                    transform: [{ translateX: -BOX_WIDTH / 2 }],
                    backgroundColor: isToday || isSelected ? color : `${color}cc`,
                  }]}
                />
                {/* Count label */}
                <View
                  style={[styles.countWrapper, {
                    left: "50%",
                    top: whiskerTop - 16,
                    transform: [{ translateX: -12 }],
                  }]}
                >
                  <Text style={[styles.countText, { color: `${color}99` }]}>
                    n={hr.count}
                  </Text>
                </View>
              </>
            );

            return (
              <TouchableOpacity
                key={item.date}
                style={[styles.whiskerTouchArea, { left, opacity }]}
                activeOpacity={0.7}
                onPress={() => onDayPress?.(item.date)}
              >
                <View style={{ height: CHART_HEIGHT, width: BOX_WIDTH + 10 }}>
                  {whiskerContent}
                </View>
              </TouchableOpacity>
            );
          }

          // Simple line chart dot for non-HR data
          let dot: React.ReactElement | null = null;
          if (primaryVal !== null) {
            const topPos = ratioToTop(primaryVal) - DOT_RADIUS;
            dot = (
              <View
                key={`dot-${i}`}
                style={[styles.dot, {
                  left,
                  top: topPos,
                  backgroundColor: dotColor,
                  transform: [{ translateX: -DOT_RADIUS }],
                  width: DOT_RADIUS * 2,
                  height: DOT_RADIUS * 2,
                  borderRadius: DOT_RADIUS,
                  borderWidth: isToday ? 2 : 0,
                  borderColor: isToday ? "white" : "transparent",
                }]}
              />
            );
          }

          return (
            <React.Fragment key={item.date}>
              {dot}
            </React.Fragment>
          );
        })}
      </View>

      {/* Day labels */}
      <View style={styles.labelsRow}>
        {data.map((item, i) => {
          const isToday = item.date === today;
          return (
            <View
              key={item.date}
              style={[styles.labelWrapper, {
                left: leftPercent(i),
                transform: [{ translateX: -16 }],
              }]}
            >
              <Text style={[styles.label, isToday && { color, fontWeight: "600" }]}>
                {getDayLabel(item.date)}
              </Text>
            </View>
          );
        })}
      </View>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    width: "100%",
  },
  chartArea: {
    position: "relative",
    width: "100%",
  },
  noDataContainer: {
    height: CHART_HEIGHT + LABEL_HEIGHT,
    justifyContent: "center",
    alignItems: "center",
  },
  noDataText: {
    color: "#888",
    fontSize: 14,
  },
  whiskerLine: {
    position: "absolute",
    width: 2,
    borderRadius: 1,
  },
  whiskerCap: {
    position: "absolute",
    width: WHISKER_WIDTH,
    height: 2,
    borderRadius: 1,
  },
  box: {
    position: "absolute",
    width: BOX_WIDTH,
    borderWidth: 1,
    borderRadius: 3,
  },
  medianLine: {
    position: "absolute",
    width: BOX_WIDTH,
    height: 2,
    borderRadius: 1,
  },
  countWrapper: {
    position: "absolute",
    width: 24,
    alignItems: "center",
  },
  countText: {
    fontSize: 9,
    fontWeight: "500",
  },
  whiskerTouchArea: {
    position: "absolute",
    transform: [{ translateX: -15 }],
  },
  dot: {
    position: "absolute",
  },
  labelsRow: {
    position: "relative",
    height: LABEL_HEIGHT,
    width: "100%",
  },
  labelWrapper: {
    position: "absolute",
    width: 32,
    alignItems: "center",
  },
  label: {
    fontSize: 11,
    color: "#666",
  },
});
