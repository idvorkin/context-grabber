import React, { useState } from "react";
import { View, Text, StyleSheet, type LayoutChangeEvent } from "react-native";

type HourlyBoxPlotProps = {
  raw: { value: number; time: string }[];
  color: string;
  label?: string;
};

const CHART_HEIGHT = 320;
const START_HOUR = 6;
const END_HOUR = 22;
const VISIBLE_HOURS = END_HOUR - START_HOUR + 1;

const HOUR_LABELS: Record<number, string> = {
  6: "6a", 9: "9a", 12: "12p", 15: "3p", 18: "6p", 21: "9p",
};

type HourStats = {
  hour: number;
  min: number;
  q1: number;
  median: number;
  q3: number;
  max: number;
  count: number;
};

function computeHourlyStats(raw: { value: number; time: string }[]): { stats: HourStats[]; globalMin: number; globalMax: number } {
  const byHour = new Map<number, number[]>();
  for (const r of raw) {
    const h = new Date(r.time).getHours();
    if (!byHour.has(h)) byHour.set(h, []);
    byHour.get(h)!.push(r.value);
  }

  const stats: HourStats[] = [];
  let globalMin = Infinity;
  let globalMax = -Infinity;

  for (let h = START_HOUR; h <= END_HOUR; h++) {
    const vals = byHour.get(h);
    if (!vals || vals.length === 0) continue;
    const sorted = [...vals].sort((a, b) => a - b);
    const n = sorted.length;
    const min = sorted[0];
    const max = sorted[n - 1];
    const q1 = sorted[Math.floor(n * 0.25)];
    const median = sorted[Math.floor(n * 0.5)];
    const q3 = sorted[Math.floor(n * 0.75)];
    stats.push({ hour: h, min, q1, median, q3, max, count: n });
    if (min < globalMin) globalMin = min;
    if (max > globalMax) globalMax = max;
  }

  return { stats, globalMin: globalMin === Infinity ? 0 : globalMin, globalMax: globalMax === -Infinity ? 0 : globalMax };
}

export default function HourlyBoxPlot({ raw, color, label }: HourlyBoxPlotProps): React.JSX.Element | null {
  const [chartWidth, setChartWidth] = useState(0);
  const { stats, globalMin, globalMax } = computeHourlyStats(raw);

  if (stats.length === 0) return null;

  const range = globalMax - globalMin || 1;
  const barWidth = chartWidth > 0 ? chartWidth / VISIBLE_HOURS : 0;

  const PAD_TOP = 18;  // room for median labels above whiskers
  const PAD_BOTTOM = 4;
  const plotHeight = CHART_HEIGHT - PAD_TOP - PAD_BOTTOM;

  function yPos(val: number): number {
    return PAD_TOP + plotHeight - ((val - globalMin) / range) * plotHeight;
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerText}>{label ?? "Hourly Detail"}</Text>
        <Text style={[styles.headerText, { color: "#666" }]}>
          {Math.round(globalMin)}–{Math.round(globalMax)}
        </Text>
      </View>

      <View style={{ flexDirection: "row", height: CHART_HEIGHT }}>
        {/* Y-axis scale */}
        <View style={styles.yAxis}>
          {(() => {
            const step = Math.ceil(range / 4 / 5) * 5; // round to nearest 5
            const ticks: number[] = [];
            for (let v = Math.ceil(globalMin / step) * step; v <= globalMax; v += step) ticks.push(v);
            if (ticks.length === 0) ticks.push(Math.round(globalMin), Math.round(globalMax));
            return ticks.map(v => (
              <Text key={v} style={[styles.yTickLabel, { top: yPos(v) - 6 }]}>{Math.round(v)}</Text>
            ));
          })()}
        </View>

        {/* Chart */}
        <View style={[styles.chartArea, { flex: 1, height: CHART_HEIGHT }]} onLayout={(e: LayoutChangeEvent) => setChartWidth(e.nativeEvent.layout.width)}>
          {/* Grid lines */}
          {chartWidth > 0 && (() => {
            const step = Math.ceil(range / 4 / 5) * 5;
            const ticks: number[] = [];
            for (let v = Math.ceil(globalMin / step) * step; v <= globalMax; v += step) ticks.push(v);
            return ticks.map(v => (
              <View key={`grid-${v}`} style={{ position: "absolute", left: 0, right: 0, top: yPos(v), height: 1, backgroundColor: "#ffffff0d" }} />
            ));
          })()}

          {chartWidth > 0 && stats.map(s => {
          const x = (s.hour - START_HOUR + 0.5) * barWidth;
          const whiskerWidth = 1;
          const boxWidth = barWidth * 0.5;

          const topWhisker = yPos(s.max);
          const bottomWhisker = yPos(s.min);
          const boxTop = yPos(s.q3);
          const boxBottom = yPos(s.q1);
          const medianY = yPos(s.median);

          return (
            <View key={s.hour}>
              {/* Whisker line (min to max) */}
              <View style={{
                position: "absolute",
                left: x - whiskerWidth / 2,
                top: topWhisker,
                width: whiskerWidth,
                height: bottomWhisker - topWhisker,
                backgroundColor: `${color}66`,
              }} />
              {/* Box (Q1 to Q3) */}
              <View style={{
                position: "absolute",
                left: x - boxWidth / 2,
                top: boxTop,
                width: boxWidth,
                height: Math.max(2, boxBottom - boxTop),
                backgroundColor: `${color}44`,
                borderWidth: 1,
                borderColor: `${color}88`,
                borderRadius: 2,
              }} />
              {/* Median line */}
              <View style={{
                position: "absolute",
                left: x - boxWidth / 2,
                top: medianY,
                width: boxWidth,
                height: 2,
                backgroundColor: color,
                borderRadius: 1,
              }} />
              {/* Count label */}
              {s.count >= 3 && (
                <Text style={{
                  position: "absolute",
                  left: x - 12,
                  top: topWhisker - 12,
                  fontSize: 8,
                  color: "#666",
                  textAlign: "center",
                  width: 24,
                }}>
                  {Math.round(s.median)}
                </Text>
              )}
            </View>
          );
        })}
        </View>
      </View>

      {/* Hour labels */}
      {chartWidth > 0 && (
        <View style={[styles.labelsRow, { marginLeft: 28 }]}>
          {Object.entries(HOUR_LABELS).map(([h, lbl]) => {
            const left = (Number(h) - START_HOUR + 0.5) * barWidth - 10;
            return <Text key={h} style={[styles.hourLabel, { left }]}>{lbl}</Text>;
          })}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { width: "100%" },
  header: { flexDirection: "row", justifyContent: "space-between", marginBottom: 6 },
  headerText: { fontSize: 13, color: "#e0e0e0", fontWeight: "600" },
  yAxis: { width: 28, position: "relative" },
  yTickLabel: { position: "absolute", right: 4, fontSize: 9, color: "#666", width: 24, textAlign: "right" },
  chartArea: { position: "relative", backgroundColor: "#111828", borderRadius: 8 },
  labelsRow: { position: "relative", height: 16, marginTop: 2 },
  hourLabel: { position: "absolute", fontSize: 10, color: "#666", width: 20, textAlign: "center" },
});
