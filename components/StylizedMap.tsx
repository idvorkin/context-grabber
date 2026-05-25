import React, { useMemo } from "react";
import { StyleSheet, Text, View } from "react-native";
import type { KnownPlace } from "../lib/places";
import type { LocationData } from "../lib/appTypes";

type Props = {
  /** Current GPS location, if available. */
  currentLocation: LocationData;
  /** Known places to anchor as pins. */
  knownPlaces: KnownPlace[];
  /** Map height in pt. Default 180. */
  height?: number;
};

/**
 * View-only "map" — a stylized backdrop with colored circles where pins
 * would be. The whole point of this is to *not* require an Apple Maps
 * key or a `react-native-maps` install. v1 just shows "things exist
 * spatially" with the right relative positioning between known places
 * and the user; a real map is a v2 conversation.
 *
 * Projection: linear lat/lng scaling to the bounding box of all points,
 * with 10% padding. Pins inside the same square render at consistent
 * relative positions across grabs.
 */
export function StylizedMap({ currentLocation, knownPlaces, height = 180 }: Props) {
  const projected = useMemo(() => {
    const pts: Array<{ lat: number; lng: number; kind: "current" | "place"; label: string; id: string }> = [];
    for (const p of knownPlaces) {
      pts.push({
        lat: p.latitude,
        lng: p.longitude,
        kind: "place",
        label: p.name,
        id: `p-${p.id}`,
      });
    }
    if (currentLocation) {
      pts.push({
        lat: currentLocation.latitude,
        lng: currentLocation.longitude,
        kind: "current",
        label: "You",
        id: "current",
      });
    }
    if (pts.length === 0) return null;

    if (pts.length === 1) {
      return {
        points: pts.map((p) => ({ ...p, x: 0.5, y: 0.5 })),
      };
    }

    const lats = pts.map((p) => p.lat);
    const lngs = pts.map((p) => p.lng);
    const minLat = Math.min(...lats);
    const maxLat = Math.max(...lats);
    const minLng = Math.min(...lngs);
    const maxLng = Math.max(...lngs);

    // Avoid divide-by-zero when all points are co-located.
    const latRange = maxLat - minLat || 1e-9;
    const lngRange = maxLng - minLng || 1e-9;

    // 10% padding so pins aren't flush against the edges.
    const pad = 0.1;
    return {
      points: pts.map((p) => ({
        ...p,
        x: pad + ((p.lng - minLng) / lngRange) * (1 - 2 * pad),
        // y is inverted: higher lat = top of screen.
        y: pad + (1 - (p.lat - minLat) / latRange) * (1 - 2 * pad),
      })),
    };
  }, [currentLocation, knownPlaces]);

  return (
    <View style={[styles.frame, { height }]} testID="stylized-map">
      <View style={styles.backdrop} />
      <View style={styles.gridH1} />
      <View style={styles.gridH2} />
      <View style={styles.gridV1} />
      <View style={styles.gridV2} />
      {!projected && (
        <View style={styles.empty}>
          <Text style={styles.emptyText}>
            No location yet — grab context or add a known place.
          </Text>
        </View>
      )}
      {projected?.points.map((p) => (
        <View
          key={p.id}
          style={[
            styles.pin,
            p.kind === "current" ? styles.pinCurrent : styles.pinPlace,
            {
              left: `${p.x * 100}%`,
              top: `${p.y * 100}%`,
            },
          ]}
          testID={`map-pin-${p.id}`}
        >
          {p.kind === "current" && <View style={styles.pinHalo} />}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    position: "relative",
    borderRadius: 14,
    overflow: "hidden",
    backgroundColor: "#0e1a2b",
    borderWidth: 1,
    borderColor: "#1a2a3a",
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "#0e1a2b",
  },
  gridH1: { position: "absolute", left: 0, right: 0, top: "33%", height: 1, backgroundColor: "rgba(76,201,240,0.06)" },
  gridH2: { position: "absolute", left: 0, right: 0, top: "67%", height: 1, backgroundColor: "rgba(76,201,240,0.06)" },
  gridV1: { position: "absolute", top: 0, bottom: 0, left: "33%", width: 1, backgroundColor: "rgba(76,201,240,0.06)" },
  gridV2: { position: "absolute", top: 0, bottom: 0, left: "67%", width: 1, backgroundColor: "rgba(76,201,240,0.06)" },
  empty: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "center",
    alignItems: "center",
    padding: 16,
  },
  emptyText: { color: "#666", fontSize: 12, textAlign: "center" },
  pin: {
    position: "absolute",
    width: 12,
    height: 12,
    borderRadius: 6,
    marginLeft: -6,
    marginTop: -6,
  },
  pinPlace: { backgroundColor: "#e8a87c", borderWidth: 1, borderColor: "rgba(232, 168, 124, 0.4)" },
  pinCurrent: { backgroundColor: "#4cc9f0", borderWidth: 2, borderColor: "#fff" },
  pinHalo: {
    position: "absolute",
    width: 28,
    height: 28,
    borderRadius: 14,
    left: -10,
    top: -10,
    backgroundColor: "rgba(76, 201, 240, 0.18)",
  },
});
