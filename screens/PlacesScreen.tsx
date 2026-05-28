import React, { useMemo, useState } from "react";
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from "react-native";
import type { SQLiteDatabase } from "expo-sqlite";
import { StylizedMap } from "../components/StylizedMap";
import PlacesDailyBreakdown, {
  type NamePlaceTarget,
} from "../components/PlacesDailyBreakdown";
import type { ContextSnapshot } from "../lib/appTypes";
import {
  type KnownPlace,
  mergePlaceCircle,
} from "../lib/places";
import {
  addKnownPlace,
  getKnownPlaces,
  updateKnownPlace,
  type LocationHistoryItem,
} from "../lib/db";
import { clusterLocationsV2 } from "../lib/clustering_v2";
import { buildPlacesDailySummary } from "../lib/places_summary";
import { haversineDistance } from "../lib/geo";

const MERGE_SUGGEST_DISTANCE = 500; // meters — see places-breakdown spec section 4

type Props = {
  snapshot: ContextSnapshot | null;
  knownPlaces: KnownPlace[];
  db: SQLiteDatabase | null;
  locationHistory: LocationHistoryItem[];
  setKnownPlaces: (places: KnownPlace[]) => void;
  setError: (msg: string | null) => void;
  onOpenLocationDetail: () => void;
  onOpenSettings: () => void;
};

// "Name this place" modal state (lifted from LocationDetailSheet)
type NameModalState =
  | { kind: "closed" }
  | {
      kind: "name";
      centroid: { latitude: number; longitude: number };
      defaultName: string;
      sourcePlaceId: string;
    }
  | {
      kind: "merge";
      centroid: { latitude: number; longitude: number };
      sourcePlaceId: string;
      nearest: KnownPlace;
      otherCount: number;
      distance: number;
      preview: { latitude: number; longitude: number; radiusMeters: number };
      shift: number;
    };

export function PlacesScreen({
  snapshot,
  knownPlaces,
  db,
  locationHistory,
  setKnownPlaces,
  setError,
  onOpenLocationDetail,
  onOpenSettings,
}: Props) {
  // Name/merge modal state — hoisted from LocationDetailSheet so the [+ name
  // this place] button on the tab-level timeline works without opening the
  // sheet.
  const [nameModal, setNameModal] = useState<NameModalState>({ kind: "closed" });
  const [nameInput, setNameInput] = useState("");
  const [nameRadiusInput, setNameRadiusInput] = useState("100");

  // Raw points for clustering (used by both the daily breakdown and the
  // naming flow's centroid lookup).
  const rawPoints = useMemo(
    () =>
      locationHistory.map((h) => ({
        latitude: h.latitude,
        longitude: h.longitude,
        timestamp: h.timestamp,
        accuracy: h.accuracy ?? 0,
      })),
    [locationHistory],
  );

  // Cluster output reused twice — once for the daily breakdown table, once
  // for today's path overlay on the map. Memoize to avoid recomputing.
  const clusterResult = useMemo(() => {
    if (rawPoints.length === 0) return null;
    return clusterLocationsV2(rawPoints, knownPlaces);
  }, [rawPoints, knownPlaces]);

  // Per-day places breakdown — the timeline the Places tab is supposed to
  // surface per spec (2026-05-25-tabbed-app-design.md acceptance criterion
  // "Today + Yesterday timeline shows all clusters with start/end times").
  const placesDailySummary = useMemo(() => {
    if (!clusterResult) return [];
    return buildPlacesDailySummary(
      clusterResult.stays,
      clusterResult.transit,
      rawPoints,
      7,
    );
  }, [clusterResult, rawPoints]);

  // Today's path overlay — stay centroids in chronological order, filtered
  // to stays that overlap today's local-time window. Used by StylizedMap to
  // draw a polyline between the day's visited known places. Per issue #42
  // Option A: "Overlay today's location path (breadcrumbs / route)".
  const todaysPath = useMemo(() => {
    if (!clusterResult) return [];
    const now = Date.now();
    const dayStart = new Date(now);
    dayStart.setHours(0, 0, 0, 0);
    const startMs = dayStart.getTime();
    return clusterResult.stays
      .filter((s) => s.endTime >= startMs && s.startTime <= now)
      .sort((a, b) => a.startTime - b.startTime)
      .map((s) => ({
        lat: s.centroid.latitude,
        lon: s.centroid.longitude,
        timestamp: s.startTime,
      }));
  }, [clusterResult]);

  // Tap on the [+] button next to a "Place N" row in PlacesDailyBreakdown.
  // Inspect proximity to known places and open either the merge-preview or
  // name-input modal.
  function handleNamePlaceTap(target: NamePlaceTarget) {
    const day = placesDailySummary.find((d) => d.dateKey === target.dateKey);
    if (!day) return;
    const visit = day.visits[target.visitIndex];
    if (!visit) return;

    // PlaceDaySummary doesn't carry the centroid (only stay times). Re-derive
    // by re-running clustering on rawPoints — cheap, deterministic, and avoids
    // leaking centroid through the summary type.
    const cluster = clusterLocationsV2(rawPoints, knownPlaces);
    const stay = cluster.stays.find(
      (s) =>
        s.placeId === visit.placeId &&
        s.startTime <= visit.startTime &&
        s.endTime >= visit.endTime,
    );
    if (!stay) return;
    const centroid = stay.centroid;

    // Find known places within MERGE_SUGGEST_DISTANCE.
    const candidates = knownPlaces
      .map((kp) => ({
        place: kp,
        distance: haversineDistance(
          centroid.latitude,
          centroid.longitude,
          kp.latitude,
          kp.longitude,
        ),
      }))
      .filter((c) => c.distance <= MERGE_SUGGEST_DISTANCE)
      .sort((a, b) => a.distance - b.distance);

    if (candidates.length === 0) {
      setNameInput("");
      setNameRadiusInput("100");
      setNameModal({
        kind: "name",
        centroid,
        defaultName: "",
        sourcePlaceId: target.placeId,
      });
      return;
    }

    const nearest = candidates[0];
    const preview = mergePlaceCircle(
      {
        latitude: nearest.place.latitude,
        longitude: nearest.place.longitude,
        radiusMeters: nearest.place.radiusMeters,
      },
      centroid,
    );
    const shift = haversineDistance(
      nearest.place.latitude,
      nearest.place.longitude,
      preview.latitude,
      preview.longitude,
    );
    setNameModal({
      kind: "merge",
      centroid,
      sourcePlaceId: target.placeId,
      nearest: nearest.place,
      otherCount: candidates.length - 1,
      distance: nearest.distance,
      preview,
      shift,
    });
  }

  async function handleConfirmName() {
    if (nameModal.kind !== "name") return;
    if (!db) {
      setError("Database not available. Please restart the app.");
      return;
    }
    const name = nameInput.trim();
    const radius = parseFloat(nameRadiusInput) || 100;
    if (!name) {
      setError("Place name is required");
      return;
    }
    try {
      await addKnownPlace(
        db,
        name,
        nameModal.centroid.latitude,
        nameModal.centroid.longitude,
        radius,
      );
      const places = await getKnownPlaces(db);
      setKnownPlaces(places);
      setNameModal({ kind: "closed" });
    } catch (e: any) {
      setError(e.message ?? "Failed to add place");
    }
  }

  async function handleConfirmMerge() {
    if (nameModal.kind !== "merge") return;
    if (!db) {
      setError("Database not available. Please restart the app.");
      return;
    }
    try {
      await updateKnownPlace(db, nameModal.nearest.id, {
        latitude: nameModal.preview.latitude,
        longitude: nameModal.preview.longitude,
        radiusMeters: nameModal.preview.radiusMeters,
      });
      const places = await getKnownPlaces(db);
      setKnownPlaces(places);
      setNameModal({ kind: "closed" });
    } catch (e: any) {
      setError(e.message ?? "Failed to expand place");
    }
  }

  // From the merge modal, switch to the "create new place" path.
  function handleSwitchToCreateNew() {
    if (nameModal.kind !== "merge") return;
    setNameInput("");
    setNameRadiusInput("100");
    setNameModal({
      kind: "name",
      centroid: nameModal.centroid,
      defaultName: "",
      sourcePlaceId: nameModal.sourcePlaceId,
    });
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Places</Text>
      </View>
      <ScrollView contentContainerStyle={styles.scroll}>
        <StylizedMap
          currentLocation={snapshot?.location ?? null}
          knownPlaces={knownPlaces}
          path={todaysPath}
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

        {placesDailySummary.length > 0 && (
          <PlacesDailyBreakdown
            days={placesDailySummary}
            onNamePlace={handleNamePlaceTap}
          />
        )}

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

      {/* Name / Merge place modal — lifted from LocationDetailSheet so the
          [+ name this place] button on the tab-level timeline works. */}
      <Modal
        visible={nameModal.kind !== "closed"}
        animationType="fade"
        transparent
        onRequestClose={() => setNameModal({ kind: "closed" })}
      >
        <View style={styles.namePlaceBackdrop}>
          <View style={styles.namePlaceCard}>
            {nameModal.kind === "name" && (
              <>
                <Text style={styles.namePlaceTitle}>Name this place</Text>
                <Text style={styles.namePlaceCoords}>
                  {nameModal.centroid.latitude.toFixed(5)}, {nameModal.centroid.longitude.toFixed(5)}
                </Text>
                <TextInput
                  style={styles.namePlaceInput}
                  placeholder="Place name"
                  placeholderTextColor="#666"
                  value={nameInput}
                  onChangeText={setNameInput}
                  autoFocus
                  testID="name-place-input"
                />
                <TextInput
                  style={[styles.namePlaceInput, { marginTop: 8 }]}
                  placeholder="Radius (m)"
                  placeholderTextColor="#666"
                  value={nameRadiusInput}
                  onChangeText={setNameRadiusInput}
                  keyboardType="number-pad"
                />
                <View style={styles.namePlaceButtonRow}>
                  <TouchableOpacity
                    style={[styles.namePlaceButton, styles.namePlaceCancelButton]}
                    onPress={() => setNameModal({ kind: "closed" })}
                  >
                    <Text style={styles.namePlaceButtonText}>Cancel</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.namePlaceButton, { flex: 1 }]}
                    onPress={handleConfirmName}
                    testID="name-place-save"
                  >
                    <Text style={styles.namePlaceButtonText}>Save</Text>
                  </TouchableOpacity>
                </View>
              </>
            )}

            {nameModal.kind === "merge" && (
              <>
                <Text style={styles.namePlaceTitle}>Nearby known place</Text>
                <Text style={styles.namePlaceBody}>
                  <Text style={{ fontWeight: "700" }}>{nameModal.sourcePlaceId}</Text> is{" "}
                  {Math.round(nameModal.distance)}m from{" "}
                  <Text style={{ fontWeight: "700" }}>{nameModal.nearest.name}</Text>.
                </Text>
                <Text style={styles.namePlaceBody}>
                  Expanding would grow radius {Math.round(nameModal.nearest.radiusMeters)}m →{" "}
                  {Math.round(nameModal.preview.radiusMeters)}m and shift the center by{" "}
                  {Math.round(nameModal.shift)}m.
                </Text>
                {nameModal.otherCount > 0 && (
                  <Text style={styles.namePlaceHint}>(+{nameModal.otherCount} more within 500m)</Text>
                )}
                <View style={styles.namePlaceButtonRow}>
                  <TouchableOpacity
                    style={[styles.namePlaceButton, styles.namePlaceCancelButton]}
                    onPress={() => setNameModal({ kind: "closed" })}
                  >
                    <Text style={styles.namePlaceButtonText}>Cancel</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.namePlaceButton, { backgroundColor: "#3d405b", flex: 1 }]}
                    onPress={handleSwitchToCreateNew}
                  >
                    <Text style={styles.namePlaceButtonText}>Create new</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.namePlaceButton, { flex: 1 }]}
                    onPress={handleConfirmMerge}
                    testID="merge-place-confirm"
                  >
                    <Text style={styles.namePlaceButtonText}>Expand {nameModal.nearest.name}</Text>
                  </TouchableOpacity>
                </View>
              </>
            )}
          </View>
        </View>
      </Modal>
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
  namePlaceBackdrop: {
    flex: 1,
    backgroundColor: "rgba(0,0,0,0.6)",
    justifyContent: "center",
    paddingHorizontal: 24,
  },
  namePlaceCard: {
    backgroundColor: "#16213e",
    borderRadius: 14,
    padding: 20,
  },
  namePlaceTitle: {
    color: "#e0e0e0",
    fontSize: 18,
    fontWeight: "700",
    marginBottom: 8,
  },
  namePlaceCoords: {
    color: "#888",
    fontSize: 12,
    fontFamily: "Courier",
    marginBottom: 12,
  },
  namePlaceBody: {
    color: "#ccc",
    fontSize: 14,
    marginBottom: 8,
    lineHeight: 20,
  },
  namePlaceHint: {
    color: "#888",
    fontSize: 12,
    marginBottom: 4,
  },
  namePlaceInput: {
    backgroundColor: "#1a1a2e",
    color: "#fff",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 14,
    borderWidth: 1,
    borderColor: "#333",
  },
  namePlaceButtonRow: {
    flexDirection: "row",
    gap: 8,
    marginTop: 12,
  },
  namePlaceButton: {
    backgroundColor: "#2d6a4f",
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: "center",
  },
  namePlaceButtonText: {
    color: "#fff",
    fontSize: 14,
    fontWeight: "600",
  },
  namePlaceCancelButton: {
    backgroundColor: "#3d1f1f",
    flex: 0.7,
  },
});
