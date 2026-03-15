import React from "react";
import { View, Text, StyleSheet, type DimensionValue } from "react-native";
import { type DailyValue, type HeartRateDaily, formatDateKey } from "../lib/weekly";

// ─── Types ────────────────────────────────────────────────────────────────────

type Props = {
  data: DailyValue[] | HeartRateDaily[];
  color: string;
  unit: string;
};

// ─── Constants ────────────────────────────────────────────────────────────────

const CHART_HEIGHT = 200;
const LABEL_HEIGHT = 30;
const DOT_RADIUS = 5;
const PADDING_V = 10; // vertical padding inside chart area

const DAY_LABELS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function isHeartRateData(data: DailyValue[] | HeartRateDaily[]): data is HeartRateDaily[] {
  return data.length > 0 && "avg" in data[0];
}

function getDayLabel(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  return DAY_LABELS[d.getUTCDay()];
}

// Returns the primary value for a data point (avg for HR, value otherwise).
function getPrimaryValue(item: DailyValue | HeartRateDaily): number | null {
  if ("avg" in item) return item.avg;
  return item.value;
}

// Compute vertical position (0 = top, 1 = bottom) for a given value.
function valueToRatio(value: number, min: number, max: number): number {
  if (max === min) return 0.5;
  return (max - value) / (max - min);
}

// ─── Component ────────────────────────────────────────────────────────────────

export default function LineChart({ data, color, unit }: Props): React.ReactElement {
  const today = formatDateKey(new Date());
  const isHR = isHeartRateData(data);

  // Gather all non-null primary values to compute scale.
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

  // Also include HR min/max in scale so range bands fit.
  const scaleValues = [...allValues];
  if (isHR) {
    for (const item of data as HeartRateDaily[]) {
      if (item.min !== null) scaleValues.push(item.min);
      if (item.max !== null) scaleValues.push(item.max);
    }
  }

  const scaleMin = Math.min(...scaleValues);
  const scaleMax = Math.max(...scaleValues);

  // Usable vertical range inside chart (excluding top/bottom padding).
  const usableHeight = CHART_HEIGHT - PADDING_V * 2;

  function ratioToTop(value: number): number {
    return PADDING_V + valueToRatio(value, scaleMin, scaleMax) * usableHeight;
  }

  const count = data.length;
  // Horizontal position: percentage-based for each index.
  function leftPercent(i: number): DimensionValue {
    return `${(i / Math.max(count - 1, 1)) * 100}%` as DimensionValue;
  }

  return (
    <View style={styles.container}>
      {/* Chart area */}
      <View style={[styles.chartArea, { height: CHART_HEIGHT }]}>
        {data.map((item, i) => {
          const primaryVal = getPrimaryValue(item);
          const isToday = item.date === today;
          const dotColor = isToday ? color : `${color}99`;

          // Horizontal label below
          const left = leftPercent(i);

          // Range band for heart rate
          let rangeBand: React.ReactElement | null = null;
          if (isHR) {
            const hrItem = item as HeartRateDaily;
            if (hrItem.min !== null && hrItem.max !== null) {
              const topPos = ratioToTop(hrItem.max);
              const bottomPos = ratioToTop(hrItem.min);
              const bandHeight = bottomPos - topPos;
              rangeBand = (
                <View
                  key={`band-${i}`}
                  style={[
                    styles.rangeBand,
                    {
                      left,
                      top: topPos,
                      height: Math.max(bandHeight, 2),
                      backgroundColor: `${color}26`,
                      transform: [{ translateX: -6 }],
                      width: 12,
                    },
                  ]}
                />
              );
            }
          }

          // Dot
          let dot: React.ReactElement | null = null;
          if (primaryVal !== null) {
            const topPos = ratioToTop(primaryVal) - DOT_RADIUS;
            dot = (
              <View
                key={`dot-${i}`}
                style={[
                  styles.dot,
                  {
                    left,
                    top: topPos,
                    backgroundColor: dotColor,
                    transform: [{ translateX: -DOT_RADIUS }],
                    width: DOT_RADIUS * 2,
                    height: DOT_RADIUS * 2,
                    borderRadius: DOT_RADIUS,
                    borderWidth: isToday ? 2 : 0,
                    borderColor: isToday ? "white" : "transparent",
                  },
                ]}
              />
            );
          }

          return (
            <React.Fragment key={item.date}>
              {rangeBand}
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
              style={[
                styles.labelWrapper,
                {
                  left: leftPercent(i),
                  transform: [{ translateX: -16 }],
                },
              ]}
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
  rangeBand: {
    position: "absolute",
    borderRadius: 3,
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
    color: "#888",
  },
});
