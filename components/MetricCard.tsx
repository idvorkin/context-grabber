import React from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import type { MetricKey } from "../lib/weekly";
import type { BoxPlotStats } from "../lib/stats";
import BoxPlot from "./BoxPlot";

export type MetricCardProps = {
  metricKey: MetricKey;
  label: string;
  value: string;
  sublabel: string;
  onPress: (key: MetricKey) => void;
  boxPlotStats?: BoxPlotStats | null;
  color?: string;
  /** Multi-box-plot mode: used by composite metrics (Movement) to stack mini
   *  box plots for each underlying series. When present, overrides
   *  boxPlotStats and renders the sublabel above the stack. */
  boxPlotStatsList?: Array<{ stats: BoxPlotStats; color: string }>;
};

export function MetricCard({
  metricKey,
  label,
  value,
  sublabel,
  onPress,
  boxPlotStats,
  color,
  boxPlotStatsList,
}: MetricCardProps) {
  const isNull = value === "—";
  return (
    <TouchableOpacity
      style={styles.metricCard}
      onPress={() => onPress(metricKey)}
      activeOpacity={0.7}
    >
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={[styles.metricValue, isNull && styles.metricValueNull]}>
        {value}
      </Text>
      {boxPlotStatsList && boxPlotStatsList.length > 0 ? (
        <>
          <Text style={styles.metricSublabel}>{sublabel}</Text>
          <View style={{ marginTop: 4 }}>
            {boxPlotStatsList.map((item, i) => (
              <BoxPlot key={i} stats={item.stats} color={item.color} compact />
            ))}
          </View>
        </>
      ) : boxPlotStats && color ? (
        <BoxPlot stats={boxPlotStats} color={color} />
      ) : (
        <Text style={styles.metricSublabel}>{sublabel}</Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  metricCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    width: "48%",
    marginBottom: 10,
  },
  metricLabel: {
    fontSize: 13,
    fontWeight: "600",
    color: "#4cc9f0",
    marginBottom: 4,
  },
  metricValue: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#e0e0e0",
  },
  metricValueNull: {
    color: "#555",
  },
  metricSublabel: {
    fontSize: 11,
    color: "#888",
    marginTop: 2,
  },
});
