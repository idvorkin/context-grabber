import React from "react";
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { StylizedMap } from "../components/StylizedMap";
import type { ContextSnapshot } from "../lib/appTypes";
import type { KnownPlace } from "../lib/places";

type Props = {
  snapshot: ContextSnapshot | null;
  knownPlaces: KnownPlace[];
  onOpenLocationDetail: () => void;
  onOpenSettings: () => void;
};

export function PlacesScreen({
  snapshot,
  knownPlaces,
  onOpenLocationDetail,
  onOpenSettings,
}: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Places</Text>
      </View>
      <ScrollView contentContainerStyle={styles.scroll}>
        <StylizedMap
          currentLocation={snapshot?.location ?? null}
          knownPlaces={knownPlaces}
        />

        <View style={styles.summaryCard}>
          <Text style={styles.summaryLabel}>Current</Text>
          {snapshot?.location ? (
            <Text style={styles.summaryValue}>
              {snapshot.location.latitude.toFixed(4)},{" "}
              {snapshot.location.longitude.toFixed(4)}
            </Text>
          ) : (
            <Text style={[styles.summaryValue, styles.faint]}>Unavailable</Text>
          )}
          <Text style={styles.summarySub}>
            {(() => {
              const latestMs = snapshot?.location?.timestamp
                ?? (snapshot?.locationHistory && snapshot.locationHistory.length > 0
                  ? snapshot.locationHistory[snapshot.locationHistory.length - 1].timestamp
                  : null);
              if (latestMs == null) return "—";
              const ageMs = Date.now() - latestMs;
              if (ageMs < 5 * 60 * 1000) return "now";
              if (ageMs < 60 * 60 * 1000) return `${Math.round(ageMs / 60000)} min ago`;
              if (ageMs < 24 * 60 * 60 * 1000) return `${Math.round(ageMs / 3600000)} hr ago`;
              const days = Math.round(ageMs / (24 * 3600000));
              return days === 1 ? "yesterday" : `${days} days ago`;
            })()}
          </Text>
        </View>

        <Text style={styles.sectionHeading}>
          Known places ({knownPlaces.length})
        </Text>
        {knownPlaces.length === 0 ? (
          <View style={styles.emptyCard}>
            <Text style={styles.emptyText}>
              No known places yet. Open the detail sheet below to add one.
            </Text>
          </View>
        ) : (
          knownPlaces.slice(0, 5).map((p) => (
            <View key={p.id} style={styles.placeRow} testID={`place-row-${p.id}`}>
              <View style={styles.placeDot} />
              <View style={{ flex: 1 }}>
                <Text style={styles.placeName}>{p.name}</Text>
                <Text style={styles.placeMeta}>
                  {p.latitude.toFixed(3)}, {p.longitude.toFixed(3)} · r {Math.round(p.radiusMeters)}m
                </Text>
              </View>
            </View>
          ))
        )}

        <TouchableOpacity
          style={styles.actionBtn}
          onPress={onOpenLocationDetail}
          testID="places-open-detail"
        >
          <Text style={styles.actionBtnText}>Manage places · history · export</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.actionBtn, styles.actionBtnSecondary]}
          onPress={onOpenSettings}
          testID="places-open-settings"
        >
          <Text style={styles.actionBtnText}>Tracking · retention</Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: { paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  scroll: { paddingHorizontal: 20, paddingBottom: 20 },
  summaryCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 12,
    marginBottom: 12,
  },
  summaryLabel: {
    color: "#4cc9f0",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 4,
  },
  summaryValue: { color: "#e0e0e0", fontSize: 18, fontWeight: "700" },
  summarySub: { color: "#888", fontSize: 11, marginTop: 2 },
  faint: { color: "#555" },
  sectionHeading: {
    color: "#4cc9f0",
    fontSize: 13,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 8,
    marginBottom: 8,
  },
  emptyCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  emptyText: { color: "#888", fontSize: 13, textAlign: "center" },
  placeRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#16213e",
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 6,
  },
  placeDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: "#e8a87c",
    marginRight: 12,
  },
  placeName: { color: "#e0e0e0", fontSize: 15, fontWeight: "600" },
  placeMeta: { color: "#888", fontSize: 11, marginTop: 2 },
  actionBtn: {
    backgroundColor: "#2d6a4f",
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 12,
  },
  actionBtnSecondary: {
    backgroundColor: "#3d405b",
  },
  actionBtnText: { color: "#fff", fontSize: 14, fontWeight: "600" },
});
