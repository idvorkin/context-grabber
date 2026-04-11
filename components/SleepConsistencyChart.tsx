import React from "react";
import { View, Text, StyleSheet, type DimensionValue } from "react-native";
import type { SleepDaily } from "../lib/sleep";
import { SLEEP_STAGE_COLORS } from "../lib/sleep";

type Props = {
  nights: SleepDaily[]; // ordered ascending by date (oldest first)
  bedtimeStdevMin: number;
  wakeStdevMin: number;
};

/**
 * Two-line chart showing bedtime and wake time across a 7-night window.
 * Y axis covers 6pm → noon next day so overnight sleep lays out sensibly
 * (bedtime at the bottom = later, wake at the top = earlier).
 */
export default function SleepConsistencyChart({ nights, bedtimeStdevMin, wakeStdevMin }: Props): React.JSX.Element {
  // Y axis mapping: 0 = 6pm (18*60=1080 min from midnight), 1 = noon next day (36*60=2160 min)
  // So a bedtime of 11pm (23*60=1380) maps to (1380 - 1080) / (2160 - 1080) = 300/1080 = 0.278
  // A wake time of 6am (6*60=360) — shift into next-day frame by adding 1440 → 1800 → (1800-1080)/1080 = 0.667
  const Y_MIN = 18 * 60; // 6pm
  const Y_MAX = 36 * 60; // noon next day
  const Y_RANGE = Y_MAX - Y_MIN;

  function toMinutesFromMidnight(iso: string): number {
    const d = new Date(iso);
    return d.getHours() * 60 + d.getMinutes();
  }

  function bedtimeToY(iso: string | null): number | null {
    if (!iso) return null;
    let m = toMinutesFromMidnight(iso);
    // Bedtimes late in the evening OR early after-midnight: shift after-midnight
    // into the next-day frame so they sit at the top visually.
    if (m <= 12 * 60) m += 24 * 60; // e.g. 1am → 25h
    return (m - Y_MIN) / Y_RANGE;
  }

  function wakeToY(iso: string | null): number | null {
    if (!iso) return null;
    let m = toMinutesFromMidnight(iso);
    // Wake times are morning; shift into the next-day frame for the y axis.
    m += 24 * 60;
    return (m - Y_MIN) / Y_RANGE;
  }

  const count = nights.length;
  const H = 90; // chart height

  function leftPercent(i: number): DimensionValue {
    return `${(i / Math.max(count - 1, 1)) * 100}%` as DimensionValue;
  }

  // Y axis labels — show 6pm / midnight / 6am / noon
  const yTicks: Array<{ label: string; yPct: number }> = [
    { label: "6p", yPct: (18 * 60 - Y_MIN) / Y_RANGE },
    { label: "12a", yPct: (24 * 60 - Y_MIN) / Y_RANGE },
    { label: "6a", yPct: (30 * 60 - Y_MIN) / Y_RANGE },
    { label: "12p", yPct: (36 * 60 - Y_MIN) / Y_RANGE },
  ];

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Bedtime consistency</Text>
      <View style={{ flexDirection: "row" }}>
        {/* Y-axis labels */}
        <View style={{ width: 30, height: H, position: "relative" }}>
          {yTicks.map((tick) => (
            <Text
              key={tick.label}
              style={[
                styles.yLabel,
                {
                  position: "absolute",
                  top: `${tick.yPct * 100}%`,
                  transform: [{ translateY: -6 }],
                },
              ]}
            >
              {tick.label}
            </Text>
          ))}
        </View>
        {/* Chart area */}
        <View style={{ flex: 1, height: H, position: "relative" }}>
          {/* Tick lines */}
          {yTicks.map((tick) => (
            <View
              key={tick.label}
              style={{
                position: "absolute",
                left: 0,
                right: 0,
                top: `${tick.yPct * 100}%`,
                height: 1,
                backgroundColor: "#222",
              }}
            />
          ))}
          {/* Bedtime dots */}
          {nights.map((night, i) => {
            const y = bedtimeToY(night.bedtime);
            if (y === null) return null;
            return (
              <View
                key={`b-${night.date}`}
                style={{
                  position: "absolute",
                  left: leftPercent(i),
                  top: `${Math.max(0, Math.min(1, y)) * 100}%`,
                  width: 6,
                  height: 6,
                  borderRadius: 3,
                  backgroundColor: SLEEP_STAGE_COLORS.Deep,
                  transform: [{ translateX: -3 }, { translateY: -3 }],
                }}
              />
            );
          })}
          {/* Wake dots */}
          {nights.map((night, i) => {
            const y = wakeToY(night.wakeTime);
            if (y === null) return null;
            return (
              <View
                key={`w-${night.date}`}
                style={{
                  position: "absolute",
                  left: leftPercent(i),
                  top: `${Math.max(0, Math.min(1, y)) * 100}%`,
                  width: 6,
                  height: 6,
                  borderRadius: 3,
                  backgroundColor: SLEEP_STAGE_COLORS.REM,
                  transform: [{ translateX: -3 }, { translateY: -3 }],
                }}
              />
            );
          })}
        </View>
      </View>
      <Text style={styles.stdev}>
        Bedtime ±{bedtimeStdevMin} min · Wake ±{wakeStdevMin} min
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 12,
    marginBottom: 4,
  },
  title: {
    color: "#ccc",
    fontSize: 13,
    fontWeight: "600",
    marginBottom: 6,
  },
  yLabel: {
    color: "#666",
    fontSize: 10,
    textAlign: "right",
    paddingRight: 4,
  },
  stdev: {
    color: "#888",
    fontSize: 12,
    marginTop: 6,
  },
});
