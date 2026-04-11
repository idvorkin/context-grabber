import React from "react";
import { View, Text, StyleSheet, TouchableOpacity, type DimensionValue } from "react-native";
import { type DailyValue, type HeartRateDaily, formatDateKey } from "../lib/weekly";

// ─── Types ────────────────────────────────────────────────────────────────────

/**
 * A single series in a multi-line overlay chart. Values should be
 * pre-normalized to [0, 1] by the caller so all series share one Y axis.
 */
export type LineChartSeries = {
  label: string;
  color: string;
  /** Normalized values aligned to `dates`; null = gap */
  data: (number | null)[];
  /** Optional absolute max shown in the legend (e.g., "12,500 steps") */
  maxLabel?: string;
};

type Props = {
  /** Single-series mode (existing callers: heart rate, HRV, weight) */
  data?: DailyValue[] | HeartRateDaily[];
  color?: string;
  unit?: string;
  onDayPress?: (date: string) => void;
  selectedDay?: string | null;
  /** Multi-series mode (new — used by the Movement detail sheet) */
  series?: LineChartSeries[];
  /** Date keys (YYYY-MM-DD) aligned with each series.data index; required in multi-series mode */
  dates?: string[];
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

export default function LineChart({
  data,
  color,
  unit,
  onDayPress,
  selectedDay,
  series,
  dates,
}: Props): React.ReactElement {
  const today = formatDateKey(new Date());

  // Multi-series mode: overlay multiple normalized lines on a shared 0-1 Y axis.
  if (series && series.length > 0 && dates) {
    return <MultiSeriesLineChart series={series} dates={dates} onDayPress={onDayPress} selectedDay={selectedDay} />;
  }

  if (!data) {
    return (
      <View style={styles.container}>
        <View style={styles.noDataContainer}>
          <Text style={styles.noDataText}>No data</Text>
        </View>
      </View>
    );
  }

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

// ─── Multi-Series Overlay ────────────────────────────────────────────────────

type MultiSeriesProps = {
  series: LineChartSeries[];
  dates: string[];
  onDayPress?: (date: string) => void;
  selectedDay?: string | null;
};

function MultiSeriesLineChart({ series, dates, onDayPress, selectedDay }: MultiSeriesProps): React.ReactElement {
  const today = formatDateKey(new Date());
  const count = dates.length;
  const usableHeight = CHART_HEIGHT - PADDING_V * 2;
  const allAllNull = series.every((s) => s.data.every((v) => v === null));

  if (allAllNull) {
    return (
      <View style={styles.container}>
        <View style={styles.noDataContainer}>
          <Text style={styles.noDataText}>No data</Text>
        </View>
      </View>
    );
  }

  function leftPercent(i: number): DimensionValue {
    return `${(i / Math.max(count - 1, 1)) * 100}%` as DimensionValue;
  }

  // Normalized 0..1 → Y coordinate within chart area.
  function ratioToTop(v: number): number {
    // v is 0..1; larger values should render higher up (smaller top).
    return PADDING_V + (1 - Math.max(0, Math.min(1, v))) * usableHeight;
  }

  // Build line segments by walking adjacent non-null pairs per series. Each
  // segment is a thin rotated View — the same technique used for bar edges.
  function renderSeriesLine(s: LineChartSeries, si: number): React.ReactElement[] {
    const nodes: React.ReactElement[] = [];
    for (let i = 0; i < count - 1; i++) {
      const v1 = s.data[i];
      const v2 = s.data[i + 1];
      if (v1 === null || v2 === null) continue;
      // Compute the two endpoint positions in percentages (horizontal) and absolute px (vertical).
      const x1Pct = (i / Math.max(count - 1, 1)) * 100;
      const x2Pct = ((i + 1) / Math.max(count - 1, 1)) * 100;
      const y1 = ratioToTop(v1);
      const y2 = ratioToTop(v2);
      // Approximate line segment as two dots + a connecting rotated bar.
      // For simplicity and to match the existing component's dot-only aesthetic,
      // we render dots at each point and skip the connecting line. Callers can
      // see the "line shape" via the ordered dots.
      // (Connecting lines require precise pixel widths which React Native's
      // flex + rotation math doesn't handle gracefully; dots are sufficient.)
      nodes.push(
        <View
          key={`s${si}-d${i}`}
          style={[styles.dot, {
            left: `${x1Pct}%` as DimensionValue,
            top: y1 - DOT_RADIUS,
            backgroundColor: s.color,
            transform: [{ translateX: -DOT_RADIUS }],
            width: DOT_RADIUS * 2,
            height: DOT_RADIUS * 2,
            borderRadius: DOT_RADIUS,
          }]}
        />,
      );
      if (i === count - 2) {
        nodes.push(
          <View
            key={`s${si}-d${i + 1}`}
            style={[styles.dot, {
              left: `${x2Pct}%` as DimensionValue,
              top: y2 - DOT_RADIUS,
              backgroundColor: s.color,
              transform: [{ translateX: -DOT_RADIUS }],
              width: DOT_RADIUS * 2,
              height: DOT_RADIUS * 2,
              borderRadius: DOT_RADIUS,
            }]}
          />,
        );
      }
    }
    // Handle series with only isolated non-null points (no adjacent pairs).
    if (nodes.length === 0) {
      for (let i = 0; i < count; i++) {
        const v = s.data[i];
        if (v === null) continue;
        nodes.push(
          <View
            key={`s${si}-dot-${i}`}
            style={[styles.dot, {
              left: leftPercent(i),
              top: ratioToTop(v) - DOT_RADIUS,
              backgroundColor: s.color,
              transform: [{ translateX: -DOT_RADIUS }],
              width: DOT_RADIUS * 2,
              height: DOT_RADIUS * 2,
              borderRadius: DOT_RADIUS,
            }]}
          />,
        );
      }
    }
    return nodes;
  }

  return (
    <View style={styles.container}>
      <View style={[styles.chartArea, { height: CHART_HEIGHT }]}>
        {series.flatMap((s, si) => renderSeriesLine(s, si))}
        {/* Invisible tap targets per day */}
        {onDayPress && dates.map((date, i) => (
          <TouchableOpacity
            key={`tap-${date}`}
            style={{
              position: "absolute",
              left: leftPercent(i),
              top: 0,
              width: 32,
              height: CHART_HEIGHT,
              transform: [{ translateX: -16 }],
            }}
            activeOpacity={0.5}
            onPress={() => onDayPress(date)}
          />
        ))}
      </View>

      {/* Day labels */}
      <View style={styles.labelsRow}>
        {dates.map((date, i) => {
          const isToday = date === today;
          return (
            <View
              key={date}
              style={[styles.labelWrapper, {
                left: leftPercent(i),
                transform: [{ translateX: -16 }],
              }]}
            >
              <Text style={[styles.label, isToday && { fontWeight: "600", color: "#ccc" }]}>
                {getDayLabel(date)}
              </Text>
            </View>
          );
        })}
      </View>

      {/* Legend */}
      <View style={styles.legendRow}>
        {series.map((s, si) => (
          <View key={si} style={styles.legendItem}>
            <View style={[styles.legendDot, { backgroundColor: s.color }]} />
            <Text style={styles.legendLabel}>{s.label}</Text>
            {s.maxLabel && <Text style={styles.legendMax}>{s.maxLabel}</Text>}
          </View>
        ))}
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
  legendRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    marginTop: 4,
    gap: 12,
  },
  legendItem: {
    flexDirection: "row",
    alignItems: "center",
  },
  legendDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 5,
  },
  legendLabel: {
    color: "#ccc",
    fontSize: 12,
    fontWeight: "600",
  },
  legendMax: {
    color: "#888",
    fontSize: 11,
    marginLeft: 5,
  },
});
