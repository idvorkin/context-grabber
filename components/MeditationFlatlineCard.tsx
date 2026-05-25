import React, { useMemo } from "react";
import { StyleSheet, Text, View } from "react-native";
import type { DailyValue } from "../lib/weekly";

type Props = {
  /** Today's meditation minutes (HealthKit mindful sessions). null if unavailable. */
  todayMinutes: number | null;
  /** Last 7 days, oldest first (matches aggregateMeditation output). */
  weekly: DailyValue[] | null;
};

/**
 * Early-warning card: time since last mindful session + 7-day intensity strip.
 * The spec says this is "the early-warning signal" — if meditation flatlines
 * for 3+ days, that's a thing to surface, not buried in a metric grid.
 */
export function MeditationFlatlineCard({ todayMinutes, weekly }: Props) {
  const { sinceText, status } = useMemo(() => {
    if (todayMinutes != null && todayMinutes > 0) {
      return {
        sinceText: `Today: ${todayMinutes} min`,
        status: "active" as const,
      };
    }
    if (!weekly || weekly.length === 0) {
      return { sinceText: "No data yet", status: "unknown" as const };
    }
    // Walk weekly newest-to-oldest; find the most recent day with value > 0.
    // `weekly` is oldest-first, so iterate in reverse.
    let daysSince: number | null = null;
    for (let i = weekly.length - 1; i >= 0; i--) {
      if ((weekly[i].value ?? 0) > 0) {
        daysSince = weekly.length - 1 - i;
        break;
      }
    }
    if (daysSince == null) {
      return { sinceText: "7+ days since last", status: "flatline" as const };
    }
    if (daysSince === 0) {
      // Already covered by todayMinutes branch above, but defensive.
      return { sinceText: `Today: 0 min`, status: "warning" as const };
    }
    if (daysSince === 1) {
      return { sinceText: "Last meditated yesterday", status: "warning" as const };
    }
    return {
      sinceText: `Last meditated ${daysSince} days ago`,
      status: daysSince >= 3 ? ("flatline" as const) : ("warning" as const),
    };
  }, [todayMinutes, weekly]);

  // 7-day mini-strip: bar height encodes minutes (capped at 20).
  const bars = useMemo(() => {
    if (!weekly) return [];
    return weekly.map((d) => {
      const v = d.value ?? 0;
      const pct = Math.min(1, v / 20);
      return { dateKey: d.date, hasValue: v > 0, height: 4 + pct * 28 };
    });
  }, [weekly]);

  return (
    <View style={[styles.card, status === "flatline" && styles.cardFlatline]} testID="meditation-flatline-card">
      <Text style={styles.heading}>Meditation</Text>
      <Text style={[styles.since, statusColor(status)]}>{sinceText}</Text>
      {bars.length > 0 && (
        <View style={styles.strip}>
          {bars.map((b) => (
            <View
              key={b.dateKey}
              style={[
                styles.bar,
                { height: b.height, backgroundColor: b.hasValue ? "#4cc9f0" : "#243046" },
              ]}
            />
          ))}
        </View>
      )}
    </View>
  );
}

function statusColor(status: "active" | "warning" | "flatline" | "unknown") {
  switch (status) {
    case "active":
      return { color: "#4cc9f0" };
    case "flatline":
      return { color: "#e8a87c" };
    case "warning":
      return { color: "#ccc" };
    default:
      return { color: "#888" };
  }
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  cardFlatline: {
    borderWidth: 1,
    borderColor: "rgba(232, 168, 124, 0.4)",
  },
  heading: {
    color: "#4cc9f0",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 8,
  },
  since: {
    fontSize: 16,
    fontWeight: "600",
    marginBottom: 12,
  },
  strip: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 4,
    height: 36,
  },
  bar: {
    flex: 1,
    borderRadius: 2,
    minHeight: 4,
  },
});
