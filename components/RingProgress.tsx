import React from "react";
import { StyleSheet, Text, View } from "react-native";

type Props = {
  /** Current value (e.g. minutes done this week). */
  value: number;
  /** Goal value (e.g. 150 min/week). When undefined or 0, ring shows 0% filled. */
  target?: number;
  /** Big text shown in the center. Defaults to `value`. */
  centerText?: string;
  /** Small text shown below the center value. */
  unit?: string;
  /** Overall diameter in pt. Default 84. */
  size?: number;
  /** Filled-dot color. Default cyan. */
  color?: string;
  /** Empty-dot color. Default dim navy. */
  trackColor?: string;
};

/**
 * Pure-View "ring" — 12 dots arranged on a circle, N of them filled to
 * encode `value / target` progress. No SVG, no rotation math, no
 * react-native-svg dependency. Cleaner alternative to a clipped-arc
 * semicircle trick when continuous arcs aren't strictly required.
 */
export function RingProgress({
  value,
  target,
  centerText,
  unit,
  size = 84,
  color = "#4cc9f0",
  trackColor = "#243046",
}: Props) {
  const pct =
    target && target > 0 ? Math.max(0, Math.min(1, value / target)) : 0;
  const filled = Math.round(pct * 12);
  const radius = size / 2 - 8;
  const dotSize = 8;
  const cx = size / 2 - dotSize / 2;
  const cy = size / 2 - dotSize / 2;

  return (
    <View style={[styles.ring, { width: size, height: size }]} testID="ring-progress">
      {Array.from({ length: 12 }).map((_, i) => {
        const angle = (i / 12) * 2 * Math.PI - Math.PI / 2;
        const left = cx + radius * Math.cos(angle);
        const top = cy + radius * Math.sin(angle);
        const isFilled = i < filled;
        return (
          <View
            key={i}
            style={[
              styles.dot,
              {
                left,
                top,
                width: dotSize,
                height: dotSize,
                borderRadius: dotSize / 2,
                backgroundColor: isFilled ? color : trackColor,
              },
            ]}
          />
        );
      })}
      <View style={styles.center}>
        <Text style={[styles.value, { color }]}>{centerText ?? String(value)}</Text>
        {unit ? <Text style={styles.unit}>{unit}</Text> : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  ring: {
    position: "relative",
    alignItems: "center",
    justifyContent: "center",
  },
  dot: {
    position: "absolute",
  },
  center: {
    alignItems: "center",
    justifyContent: "center",
  },
  value: {
    fontSize: 22,
    fontWeight: "700",
    fontVariant: ["tabular-nums"],
  },
  unit: {
    fontSize: 10,
    color: "#888",
    marginTop: -2,
  },
});
