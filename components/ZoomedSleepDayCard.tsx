import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { SLEEP_STAGE_COLORS, type SleepDaily } from "../lib/sleep";
import SleepStageStrip from "./SleepStageStrip";

type Props = {
  night: SleepDaily;
  color: string;
};

function formatDateLabel(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00Z");
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  ];
  return `${days[d.getUTCDay()]}, ${months[d.getUTCMonth()]} ${d.getUTCDate()}`;
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  let h = d.getHours();
  const m = d.getMinutes();
  const ampm = h >= 12 ? "pm" : "am";
  h = h % 12 || 12;
  return m === 0 ? `${h}${ampm}` : `${h}:${String(m).padStart(2, "0")}${ampm}`;
}

export default function ZoomedSleepDayCard({
  night,
  color,
}: Props): React.JSX.Element {
  const hasData =
    night.bedtime && night.wakeTime && night.totalHours != null && night.samples.length > 0;

  if (!hasData) {
    return (
      <View style={styles.card}>
        <Text style={[styles.dateLabel, { color }]}>
          {formatDateLabel(night.date)}
        </Text>
        <Text style={styles.emptyText}>No sleep data for this night</Text>
      </View>
    );
  }

  const stageTotal =
    night.coreHours + night.deepHours + night.remHours + night.awakeHours;
  const pct = (h: number) =>
    stageTotal > 0 ? Math.round((h / stageTotal) * 100) : 0;

  return (
    <View style={styles.card}>
      <View style={styles.headerRow}>
        <Text style={[styles.dateLabel, { color }]}>
          {formatDateLabel(night.date)}
        </Text>
        <Text style={styles.totalLabel}>{night.totalHours}h</Text>
      </View>
      <Text style={styles.windowLabel}>
        {formatTime(night.bedtime!)} → {formatTime(night.wakeTime!)}
      </Text>
      <SleepStageStrip
        samples={night.samples}
        bedtime={night.bedtime}
        wakeTime={night.wakeTime}
        height={48}
        radius={8}
        labelSize={11}
        showHourTicks
      />
      {stageTotal > 0 && (
        <View style={styles.stageRow}>
          {night.coreHours > 0 && (
            <Text style={[styles.stageItem, { color: SLEEP_STAGE_COLORS.Core }]}>
              Core {pct(night.coreHours)}%
            </Text>
          )}
          {night.deepHours > 0 && (
            <Text style={[styles.stageItem, { color: SLEEP_STAGE_COLORS.Deep }]}>
              Deep {pct(night.deepHours)}%
            </Text>
          )}
          {night.remHours > 0 && (
            <Text style={[styles.stageItem, { color: SLEEP_STAGE_COLORS.REM }]}>
              REM {pct(night.remHours)}%
            </Text>
          )}
          {night.awakeHours > 0 && (
            <Text style={[styles.stageItem, { color: SLEEP_STAGE_COLORS.Awake }]}>
              Awake {pct(night.awakeHours)}%
            </Text>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    marginHorizontal: 20,
    marginBottom: 12,
    padding: 14,
    backgroundColor: "#1a1f2e",
    borderRadius: 12,
  },
  headerRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 2,
  },
  dateLabel: {
    fontSize: 15,
    fontWeight: "700",
  },
  totalLabel: {
    fontSize: 20,
    fontWeight: "700",
    color: "#e0e0e0",
  },
  windowLabel: {
    fontSize: 13,
    color: "#aaa",
    marginBottom: 8,
  },
  stageRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
    marginTop: 10,
  },
  stageItem: {
    fontSize: 13,
    fontWeight: "600",
  },
  emptyText: {
    color: "#888",
    fontSize: 13,
    marginTop: 8,
  },
});
