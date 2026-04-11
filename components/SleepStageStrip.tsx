import React from "react";
import { View, Text, StyleSheet } from "react-native";
import type { SleepSample } from "../lib/health";
import { SLEEP_STAGE_COLORS } from "../lib/sleep";

type Props = {
  samples: SleepSample[];
  bedtime: string | null;
  wakeTime: string | null;
};

/**
 * Thin horizontal strip showing stage composition across a single sleep window.
 * Spans [bedtime, wakeTime]. Each segment is colored by stage (Core, Deep, REM,
 * Awake, InBed). Renders bedtime/wake labels on each end.
 *
 * Not interactive — purely decorative, shown beneath each daily row in the
 * sleep detail sheet.
 */
export default function SleepStageStrip({ samples, bedtime, wakeTime }: Props): React.JSX.Element | null {
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

  return (
    <View style={styles.container}>
      <View style={styles.strip}>
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
      <View style={styles.timeRow}>
        <Text style={styles.timeLabel}>{formatTime(bedtime)}</Text>
        <Text style={styles.timeLabel}>{formatTime(wakeTime)}</Text>
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

const styles = StyleSheet.create({
  container: {
    marginTop: 4,
    marginBottom: 4,
  },
  strip: {
    width: "100%",
    height: 10,
    borderRadius: 4,
    overflow: "hidden",
    backgroundColor: "#1a1a2e",
    position: "relative",
  },
  timeRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    marginTop: 2,
  },
  timeLabel: {
    fontSize: 10,
    color: "#666",
  },
});
