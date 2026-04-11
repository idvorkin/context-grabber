import React, { useMemo, useState } from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import type { PlaceDaySummary } from "../lib/places_summary";

const COLORS = [
  "#4361ee", "#f72585", "#4cc9f0", "#7209b7", "#3a86a7",
  "#f77f00", "#06d6a0", "#e63946", "#a8dadc", "#fca311",
];

// Color used for unnamed "Place N" rows AND loose-data rows — both signal
// "tap-to-fix / unresolved data."
const UNKNOWN_COLOR = "#fca311";
const TRANSIT_COLOR = "#4cc9f0";
const NO_DATA_COLOR = "#555";

const PLACE_N_PATTERN = /^Place \d+$/;

export type NamePlaceTarget = {
  placeId: string;
  visitIndex: number; // index into day.visits — use the most recent visit for centroid
  dateKey: string;
};

type Props = {
  days: PlaceDaySummary[];
  onNamePlace?: (target: NamePlaceTarget) => void;
};

function formatHours(minutes: number): string {
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const h = Math.round(minutes / 6) / 10;
  return `${h}h`;
}

function formatDateLabel(dateKey: string): string {
  const [y, m, d] = dateKey.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${days[date.getDay()]} ${months[date.getMonth()]} ${date.getDate()}`;
}

function formatTime(ts: number): string {
  const d = new Date(ts);
  let h = d.getHours();
  const m = d.getMinutes();
  const period = h >= 12 ? "pm" : "am";
  h = h % 12 || 12;
  return m === 0 ? `${h}${period}` : `${h}:${String(m).padStart(2, "0")}${period}`;
}

export default function PlacesDailyBreakdown({ days, onNamePlace }: Props) {
  const [expandedDay, setExpandedDay] = useState<string | null>(null);

  // Assign colors per known place. Unknown "Place N" rows always use UNKNOWN_COLOR
  // regardless of their slot in the rotating palette.
  const colorMap = useMemo(() => {
    const map = new Map<string, string>();
    const knownPlaces = new Set<string>();
    for (const day of days) {
      for (const p of day.places) {
        if (!PLACE_N_PATTERN.test(p.placeId)) knownPlaces.add(p.placeId);
      }
    }
    let i = 0;
    for (const id of knownPlaces) {
      map.set(id, COLORS[i % COLORS.length]);
      i++;
    }
    return map;
  }, [days]);

  if (days.length === 0) return null;

  return (
    <View style={styles.container}>
      {days.map((day) => {
        // Bar scale: max across stays + transit + no-data so all rows share
        // a comparable visual scale.
        const maxStay = day.places.length > 0 ? day.places[0].totalMinutes : 0;
        const maxMinutes = Math.max(
          maxStay,
          day.transitMinutes,
          day.noDataMinutes,
          1,
        );
        const isExpanded = expandedDay === day.dateKey;
        return (
          <TouchableOpacity
            key={day.dateKey}
            style={styles.card}
            activeOpacity={0.7}
            onPress={() => setExpandedDay(isExpanded ? null : day.dateKey)}
          >
            <View style={styles.dateRow}>
              <Text style={styles.dateHeader}>{formatDateLabel(day.dateKey)}</Text>
              <Text style={styles.totalText}>{formatHours(day.elapsedMinutes)}</Text>
            </View>
            {day.places.map((place) => {
              const isUnknown = PLACE_N_PATTERN.test(place.placeId);
              const fraction = maxMinutes > 0 ? place.totalMinutes / maxMinutes : 0;
              const color = isUnknown
                ? UNKNOWN_COLOR
                : colorMap.get(place.placeId) ?? COLORS[0];
              // Find the longest visit for this placeId on this day so the
              // naming flow can use its centroid as a representative location.
              const visitIndex = isUnknown
                ? findLongestVisitIndex(day.visits, place.placeId)
                : -1;
              return (
                <View key={place.placeId} style={styles.row}>
                  <View style={styles.barContainer}>
                    <View style={[styles.bar, { width: `${Math.max(fraction * 100, 2)}%`, backgroundColor: color }]} />
                  </View>
                  <Text style={styles.placeName} numberOfLines={1}>{place.placeId}</Text>
                  <Text style={styles.hours}>{formatHours(place.totalMinutes)}</Text>
                  {isUnknown && onNamePlace && visitIndex >= 0 && (
                    <TouchableOpacity
                      style={styles.nameButton}
                      onPress={(e) => {
                        e.stopPropagation();
                        onNamePlace({
                          placeId: place.placeId,
                          visitIndex,
                          dateKey: day.dateKey,
                        });
                      }}
                      hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                      testID={`name-place-${day.dateKey}-${place.placeId}`}
                    >
                      <Text style={styles.nameButtonText}>＋</Text>
                    </TouchableOpacity>
                  )}
                </View>
              );
            })}

            {/* Supplemental accounting rows: transit, no-data */}
            {day.transitMinutes > 0 && (
              <View style={styles.row}>
                <View style={styles.barContainer}>
                  <View
                    style={[
                      styles.bar,
                      {
                        width: `${Math.max((day.transitMinutes / maxMinutes) * 100, 2)}%`,
                        backgroundColor: TRANSIT_COLOR,
                        opacity: 0.55,
                      },
                    ]}
                  />
                </View>
                <Text style={[styles.placeName, styles.dimText]} numberOfLines={1}>—transit—</Text>
                <Text style={[styles.hours, styles.dimText]}>{formatHours(day.transitMinutes)}</Text>
              </View>
            )}
            {day.noDataMinutes > 0 && (
              <View style={styles.row}>
                <View style={styles.barContainer}>
                  <View
                    style={[
                      styles.bar,
                      {
                        width: `${Math.max((day.noDataMinutes / maxMinutes) * 100, 2)}%`,
                        backgroundColor: NO_DATA_COLOR,
                      },
                    ]}
                  />
                </View>
                <Text style={[styles.placeName, styles.dimText]} numberOfLines={1}>—no data—</Text>
                <Text style={[styles.hours, styles.dimText]}>{formatHours(day.noDataMinutes)}</Text>
              </View>
            )}

            {/* Expanded: individual visits */}
            {isExpanded && day.visits.length > 0 && (
              <View style={styles.visitsSection}>
                {day.visits.map((v, i) => {
                  const isUnknown = PLACE_N_PATTERN.test(v.placeId);
                  const color = isUnknown
                    ? UNKNOWN_COLOR
                    : colorMap.get(v.placeId) ?? COLORS[0];
                  return (
                    <View key={i} style={styles.visitRow}>
                      <View style={[styles.visitDot, { backgroundColor: color }]} />
                      <Text style={styles.visitTime}>
                        {formatTime(v.startTime)}–{formatTime(v.endTime)}
                      </Text>
                      <Text style={styles.visitPlace} numberOfLines={1}>{v.placeId}</Text>
                      <Text style={styles.visitDuration}>{formatHours(v.durationMinutes)}</Text>
                    </View>
                  );
                })}
              </View>
            )}
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

function findLongestVisitIndex(
  visits: PlaceDaySummary["visits"],
  placeId: string,
): number {
  let bestIdx = -1;
  let bestDuration = -1;
  for (let i = 0; i < visits.length; i++) {
    if (visits[i].placeId === placeId && visits[i].durationMinutes > bestDuration) {
      bestIdx = i;
      bestDuration = visits[i].durationMinutes;
    }
  }
  return bestIdx;
}

const styles = StyleSheet.create({
  container: { marginTop: 12, gap: 8 },
  card: {
    backgroundColor: "#16213e",
    borderRadius: 10,
    padding: 12,
  },
  dateRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 8,
  },
  dateHeader: {
    fontSize: 14,
    fontWeight: "700",
    color: "#4cc9f0",
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 5,
  },
  barContainer: {
    flex: 1,
    height: 14,
    backgroundColor: "#1a1a2e",
    borderRadius: 4,
    overflow: "hidden",
  },
  bar: {
    height: "100%",
    borderRadius: 4,
  },
  placeName: {
    color: "#e0e0e0",
    fontSize: 12,
    fontWeight: "500",
    width: 80,
    marginLeft: 8,
    textAlign: "left",
  },
  hours: {
    color: "#aaa",
    fontSize: 12,
    width: 36,
    textAlign: "right",
  },
  dimText: {
    opacity: 0.7,
    color: "#888",
  },
  nameButton: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: "#2d6a4f",
    marginLeft: 6,
    justifyContent: "center",
    alignItems: "center",
  },
  nameButtonText: {
    color: "#fff",
    fontSize: 14,
    fontWeight: "700",
    lineHeight: 16,
  },
  totalText: {
    color: "#888",
    fontSize: 12,
  },
  visitsSection: {
    marginTop: 8,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: "#1a1a2e",
  },
  visitRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingVertical: 3,
  },
  visitDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: 6,
  },
  visitTime: {
    color: "#888",
    fontSize: 11,
    width: 90,
  },
  visitPlace: {
    color: "#e0e0e0",
    fontSize: 12,
    flex: 1,
  },
  visitDuration: {
    color: "#666",
    fontSize: 11,
    width: 32,
    textAlign: "right",
  },
});
