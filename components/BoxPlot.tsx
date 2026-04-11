import React from "react";
import { View, StyleSheet } from "react-native";
import type { BoxPlotStats } from "../lib/stats";

// ─── Constants ────────────────────────────────────────────────────────────────

const PLOT_HEIGHT = 24;
const PLOT_HEIGHT_COMPACT = 12;
const DOT_SIZE = 4;
const DOT_ROW_HEIGHT = 10;
const WHISKER_WIDTH = 1;
const MEDIAN_WIDTH = 2;

// ─── Props ────────────────────────────────────────────────────────────────────

type Props = {
  stats: BoxPlotStats;
  color: string;
  /** Compact variant: no dot row, slim plot row. Used when stacking multiple. */
  compact?: boolean;
};

// ─── BoxPlot ──────────────────────────────────────────────────────────────────

/**
 * Horizontal box plot rendered with React Native Views.
 *
 * Layout (top to bottom):
 *   1. Dot row: individual data points as small circles
 *   2. Box plot: whiskers (p5–p25, p75–p95), box (p25–p75), median line (p50)
 *
 * All positions are computed as percentages of the full range (min–max).
 */
export default function BoxPlot({ stats, color, compact = false }: Props): React.JSX.Element {
  const { min, max, p5, p25, p50, p75, p95, values } = stats;
  const range = max - min;
  const plotHeight = compact ? PLOT_HEIGHT_COMPACT : PLOT_HEIGHT;

  // When all values are identical, show a single centered bar.
  if (range === 0) {
    return (
      <View style={compact ? styles.containerCompact : styles.container}>
        {!compact && (
          <View style={styles.dotRow}>
            <View
              style={[
                styles.dot,
                { backgroundColor: color, left: "50%" },
              ]}
            />
          </View>
        )}
        <View style={[styles.plotRow, { height: plotHeight }]}>
          <View
            style={[
              styles.medianLine,
              { backgroundColor: color, left: "50%" },
            ]}
          />
        </View>
      </View>
    );
  }

  // Convert a value to a percentage position within the range.
  const toPercent = (v: number): number => ((v - min) / range) * 100;

  const p5Pct = toPercent(p5);
  const p25Pct = toPercent(p25);
  const p50Pct = toPercent(p50);
  const p75Pct = toPercent(p75);
  const p95Pct = toPercent(p95);

  const boxLeft = p25Pct;
  const boxWidth = p75Pct - p25Pct;

  // Dimmed color for whiskers and dots (30% opacity).
  const dimColor = `${color}4D`;

  return (
    <View style={compact ? styles.containerCompact : styles.container}>
      {/* Dot row: individual data points (hidden in compact mode) */}
      {!compact && (
        <View style={styles.dotRow}>
          {values.map((v, i) => (
            <View
              key={i}
              style={[
                styles.dot,
                {
                  backgroundColor: dimColor,
                  left: `${toPercent(v)}%`,
                },
              ]}
            />
          ))}
        </View>
      )}

      {/* Box plot row */}
      <View style={[styles.plotRow, { height: plotHeight }]}>
        {/* Left whisker: p5 to p25 */}
        <View
          style={[
            styles.whisker,
            {
              backgroundColor: dimColor,
              left: `${p5Pct}%`,
              width: `${boxLeft - p5Pct}%`,
              top: (plotHeight - WHISKER_WIDTH) / 2,
            },
          ]}
        />

        {/* Box: p25 to p75 */}
        <View
          style={[
            styles.box,
            {
              backgroundColor: `${color}33`,
              borderColor: color,
              left: `${boxLeft}%`,
              width: `${Math.max(boxWidth, 0.5)}%`,
            },
          ]}
        />

        {/* Right whisker: p75 to p95 */}
        <View
          style={[
            styles.whisker,
            {
              backgroundColor: dimColor,
              left: `${p75Pct}%`,
              width: `${p95Pct - p75Pct}%`,
              top: (plotHeight - WHISKER_WIDTH) / 2,
            },
          ]}
        />

        {/* Median line */}
        <View
          style={[
            styles.medianLine,
            {
              backgroundColor: color,
              left: `${p50Pct}%`,
            },
          ]}
        />
      </View>
    </View>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    width: "100%",
    marginTop: 6,
  },
  containerCompact: {
    width: "100%",
    marginTop: 2,
  },
  dotRow: {
    height: DOT_ROW_HEIGHT,
    position: "relative",
  },
  dot: {
    position: "absolute",
    width: DOT_SIZE,
    height: DOT_SIZE,
    borderRadius: DOT_SIZE / 2,
    top: (DOT_ROW_HEIGHT - DOT_SIZE) / 2,
    marginLeft: -(DOT_SIZE / 2),
  },
  plotRow: {
    position: "relative",
  },
  whisker: {
    position: "absolute",
    height: WHISKER_WIDTH,
    top: (PLOT_HEIGHT - WHISKER_WIDTH) / 2,
  },
  box: {
    position: "absolute",
    top: 2,
    bottom: 2,
    borderWidth: 1,
    borderRadius: 4,
  },
  medianLine: {
    position: "absolute",
    width: MEDIAN_WIDTH,
    top: 0,
    bottom: 0,
    borderRadius: 1,
    marginLeft: -(MEDIAN_WIDTH / 2),
  },
});
