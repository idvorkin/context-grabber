import React, { useMemo, useState } from "react";
import { LayoutChangeEvent, StyleSheet, Text, View } from "react-native";
import type { KnownPlace } from "../lib/places";
import type { LocationData } from "../lib/appTypes";

/** A point on the day's path overlay. `timestamp` is optional and unused for
 * rendering today — it exists so callers can pass `Stay`-shaped data without
 * stripping fields. */
export type PathPoint = {
  lat: number;
  lon: number;
  timestamp?: number;
};

type Props = {
  /** Current GPS location, if available. */
  currentLocation: LocationData;
  /** Known places to anchor as pins. */
  knownPlaces: KnownPlace[];
  /** Map height in pt. Default 180. */
  height?: number;
  /**
   * Optional ordered breadcrumbs for today's path. Rendered as a polyline
   * overlay connecting the points in array order (so callers should sort
   * by time first). When 2+ points are present, also extends the projection
   * bounding box so the path stays inside the frame. Empty / single-point
   * arrays render nothing extra.
   */
  path?: PathPoint[];
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
export function StylizedMap({
  currentLocation,
  knownPlaces,
  height = 180,
  path,
}: Props) {
  // Frame size — needed to compute segment lengths in pt for the path
  // polyline overlay (we can't rotate a percentage-width line accurately
  // because rotation needs a known length). Default to a sensible value;
  // onLayout updates it once the frame measures.
  const [frameSize, setFrameSize] = useState<{ width: number; height: number } | null>(null);

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

    // Path points participate in the bounding box so the polyline can't
    // wander off-frame, but they're not rendered as labelled pins.
    const pathPts = (path ?? []).filter(
      (p) => Number.isFinite(p.lat) && Number.isFinite(p.lon),
    );

    if (pts.length === 0 && pathPts.length === 0) return null;

    if (pts.length + pathPts.length === 1) {
      // Only one point of any kind — center it.
      const onlyPath = pts.length === 0;
      return {
        points: pts.map((p) => ({ ...p, x: 0.5, y: 0.5 })),
        path: onlyPath ? [{ x: 0.5, y: 0.5 }] : [],
      };
    }

    const lats = [
      ...pts.map((p) => p.lat),
      ...pathPts.map((p) => p.lat),
    ];
    const lngs = [
      ...pts.map((p) => p.lng),
      ...pathPts.map((p) => p.lon),
    ];
    const minLat = Math.min(...lats);
    const maxLat = Math.max(...lats);
    const minLng = Math.min(...lngs);
    const maxLng = Math.max(...lngs);

    // Avoid divide-by-zero when all points are co-located.
    const latRange = maxLat - minLat || 1e-9;
    const lngRange = maxLng - minLng || 1e-9;

    // 10% padding so pins aren't flush against the edges.
    const pad = 0.1;
    const project = (lat: number, lng: number) => ({
      x: pad + ((lng - minLng) / lngRange) * (1 - 2 * pad),
      // y is inverted: higher lat = top of screen.
      y: pad + (1 - (lat - minLat) / latRange) * (1 - 2 * pad),
    });

    return {
      points: pts.map((p) => ({ ...p, ...project(p.lat, p.lng) })),
      path: pathPts.map((p) => project(p.lat, p.lon)),
    };
  }, [currentLocation, knownPlaces, path]);

  // Polyline segments between consecutive path points. Computed in pt
  // (not %) because rotation requires a real length.
  const pathSegments = useMemo(() => {
    if (!projected || !frameSize) return [];
    if (projected.path.length < 2) return [];
    const w = frameSize.width;
    const h = frameSize.height;
    const segs: Array<{
      key: string;
      left: number;
      top: number;
      width: number;
      angle: number;
    }> = [];
    for (let i = 1; i < projected.path.length; i++) {
      const a = projected.path[i - 1];
      const b = projected.path[i];
      const ax = a.x * w;
      const ay = a.y * h;
      const bx = b.x * w;
      const by = b.y * h;
      const dx = bx - ax;
      const dy = by - ay;
      const len = Math.sqrt(dx * dx + dy * dy);
      if (len < 0.5) continue;
      const angle = (Math.atan2(dy, dx) * 180) / Math.PI;
      // Offset top by half the segment height so the line is vertically
      // centered on (ax, ay) — the transformOrigin pivot ("left center")
      // expects the rotation point to be at the vertical middle.
      segs.push({
        key: `seg-${i}`,
        left: ax,
        top: ay - 1,
        width: len,
        angle,
      });
    }
    return segs;
  }, [projected, frameSize]);

  function handleLayout(e: LayoutChangeEvent) {
    const { width, height: h } = e.nativeEvent.layout;
    if (
      !frameSize ||
      Math.abs(frameSize.width - width) > 0.5 ||
      Math.abs(frameSize.height - h) > 0.5
    ) {
      setFrameSize({ width, height: h });
    }
  }

  return (
    <View
      style={[styles.frame, { height }]}
      testID="stylized-map"
      onLayout={handleLayout}
    >
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
      {/* Path polyline — render BEFORE pins so pins sit on top. Each segment
          is a 1px-tall view rotated to align with its endpoints. */}
      {pathSegments.map((s) => (
        <View
          key={s.key}
          testID={s.key}
          pointerEvents="none"
          style={[
            styles.pathSegment,
            {
              left: s.left,
              top: s.top,
              width: s.width,
              transform: [{ rotate: `${s.angle}deg` }],
            },
          ]}
        />
      ))}
      {/* Small dots at each path breadcrumb. Skipped when there's only one
          point or when the frame hasn't measured yet. */}
      {frameSize && projected && projected.path.length >= 2
        ? projected.path.map((p, idx) => (
            <View
              key={`path-dot-${idx}`}
              testID={`map-path-dot-${idx}`}
              pointerEvents="none"
              style={[
                styles.pathDot,
                {
                  left: `${p.x * 100}%`,
                  top: `${p.y * 100}%`,
                },
              ]}
            />
          ))
        : null}
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
  pathSegment: {
    position: "absolute",
    height: 2,
    backgroundColor: "rgba(76, 201, 240, 0.55)",
    // Default RN rotation pivots around the view's center; we want the
    // rotation to pivot around the start point (left edge, vertical center)
    // so the segment extends toward the next breadcrumb.
    transformOrigin: "left center",
    borderRadius: 1,
  },
  pathDot: {
    position: "absolute",
    width: 5,
    height: 5,
    borderRadius: 2.5,
    marginLeft: -2.5,
    marginTop: -2.5,
    backgroundColor: "#4cc9f0",
    opacity: 0.85,
  },
});
