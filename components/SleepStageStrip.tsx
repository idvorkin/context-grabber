import React from "react";
import { View, Text, StyleSheet } from "react-native";
import type { SleepSample } from "../lib/health";
import { SLEEP_STAGE_COLORS } from "../lib/sleep";

type Props = {
  samples: SleepSample[];
  bedtime: string | null;
  wakeTime: string | null;
  /** Strip height in px. Default 10 (daily rows). Daily rows use 18, zoom card 48. */
  height?: number;
  /** Font size of the bedtime/wake labels under the strip. Default 10. */
  labelSize?: number;
  /** Border radius of the strip. Default 4. */
  radius?: number;
  /** Render hour tick labels under the strip (every hour between bedtime and wake). */
  showHourTicks?: boolean;
};

/**
 * Horizontal strip showing stage composition across a single sleep window.
 * Spans [bedtime, wakeTime]. Each segment is colored by stage (Core, Deep, REM,
 * Awake, InBed). Renders bedtime/wake labels on each end.
 */
export default function SleepStageStrip({
  samples,
  bedtime,
  wakeTime,
  height = 10,
  labelSize = 10,
  radius = 4,
  showHourTicks = false,
}: Props): React.JSX.Element | null {
  if (!bedtime || !wakeTime || samples.length === 0) return null;

  const windowStart = new Date(bedtime).getTime();
  const windowEnd = new Date(wakeTime).getTime();
  const windowMs = windowEnd - windowStart;
  if (windowMs <= 0) return null;

  // Sort, clamp, and coalesce overlapping same-stage intervals.
  const intervals = samples
    .map((s) => ({
      start: Math.max(windowStart, new Date(s.startDate).getTime()),
      end: Math.min(windowEnd, new Date(s.endDate).getTime()),
      value: s.value,
    }))
    .filter((i) => i.end > i.start)
    .sort((a, b) => a.start - b.start);

  // Hour ticks: one label per whole hour between bedtime and wake time. Fall
  // back to every 2 hours if the window is > 10h.
  let tickPositions: { left: number; label: string }[] = [];
  if (showHourTicks) {
    const windowHours = windowMs / (1000 * 60 * 60);
    const stepHours = windowHours > 10 ? 2 : 1;
    const firstTick = new Date(windowStart);
    firstTick.setMinutes(0, 0, 0);
    firstTick.setHours(firstTick.getHours() + 1);
    for (
      let t = firstTick.getTime();
      t < windowEnd;
      t += stepHours * 60 * 60 * 1000
    ) {
      const left = ((t - windowStart) / windowMs) * 100;
      tickPositions.push({ left, label: formatHourShort(new Date(t)) });
    }
  }

  return (
    <View style={styles.container}>
      <View
        style={[
          styles.strip,
          { height, borderRadius: radius },
        ]}
      >
        {intervals.map((iv, i) => {
          const left = ((iv.start - windowStart) / windowMs) * 100;
          const width = ((iv.end - iv.start) / windowMs) * 100;
          return (
            <View
              key={i}
              style={{
                position: "absolute",
                left: `${left}%`,
                width: `${Math.max(width, 0.5)}%`,
                top: 0,
                bottom: 0,
                backgroundColor: colorForStage(iv.value),
              }}
            />
          );
        })}
      </View>
      {showHourTicks && tickPositions.length > 0 && (
        <View style={styles.tickRow}>
          {tickPositions.map((tp, i) => (
            <Text
              key={i}
              style={[
                styles.tickLabel,
                { left: `${tp.left}%`, fontSize: Math.max(9, labelSize - 1) },
              ]}
            >
              {tp.label}
            </Text>
          ))}
        </View>
      )}
      <View style={styles.timeRow}>
        <Text style={[styles.timeLabel, { fontSize: labelSize }]}>
          {formatTime(bedtime)}
        </Text>
        <Text style={[styles.timeLabel, { fontSize: labelSize }]}>
          {formatTime(wakeTime)}
        </Text>
      </View>
    </View>
  );
}

function colorForStage(value: number | undefined): string {
  switch (value) {
    case 0: return SLEEP_STAGE_COLORS.InBed;
    case 2: return SLEEP_STAGE_COLORS.Awake;
    case 3: return SLEEP_STAGE_COLORS.Core;
    case 4: return SLEEP_STAGE_COLORS.Deep;
    case 5: return SLEEP_STAGE_COLORS.REM;
    case 1: // generic Asleep with no stage
    default: return SLEEP_STAGE_COLORS.Core;
  }
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  let h = d.getHours();
  const m = d.getMinutes();
  const ampm = h >= 12 ? "pm" : "am";
  h = h % 12 || 12;
  return m === 0 ? `${h}${ampm}` : `${h}:${String(m).padStart(2, "0")}${ampm}`;
}

function formatHourShort(d: Date): string {
  let h = d.getHours();
  const ampm = h >= 12 ? "p" : "a";
  h = h % 12 || 12;
  return `${h}${ampm}`;
}

const styles = StyleSheet.create({
  container: {
    marginTop: 4,
    marginBottom: 4,
  },
  strip: {
    width: "100%",
    overflow: "hidden",
    backgroundColor: "#1a1a2e",
    position: "relative",
  },
  tickRow: {
    position: "relative",
    height: 14,
    marginTop: 2,
  },
  tickLabel: {
    position: "absolute",
    top: 0,
    color: "#666",
    transform: [{ translateX: -8 }],
  },
  timeRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginTop: 2,
  },
  timeLabel: {
    color: "#666",
  },
});
