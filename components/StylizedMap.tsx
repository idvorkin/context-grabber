import React, { useMemo, useRef, useState } from "react";
import { Modal, StyleSheet, Text, TouchableOpacity, View } from "react-native";
import * as Clipboard from "expo-clipboard";
import MapView, {
  Marker,
  Polyline,
  PROVIDER_DEFAULT,
  type Region,
} from "react-native-maps";
import type { KnownPlace } from "../lib/places";
import type { LocationData } from "../lib/appTypes";
import { CURRENT_LOCATION_COLOR, PLACE_COLORS } from "../lib/places_colors";
import { iconForPlace } from "../lib/place_icons";

export type PathPoint = {
  lat: number;
  lon: number;
  timestamp?: number;
};

type Props = {
  currentLocation: LocationData;
  knownPlaces: KnownPlace[];
  height?: number;
  path?: PathPoint[];
  /**
   * Color per known place, keyed by `KnownPlace.name`. When provided, each
   * pin uses the matching color so the map shares its palette with the
   * Places-daily-breakdown bars (same place = same color across surfaces).
   * Missing entries fall back to PLACE_COLORS by index.
   */
  placeColors?: Map<string, string>;
};

const FALLBACK_REGION: Region = {
  latitude: 37.7749,
  longitude: -122.4194,
  latitudeDelta: 0.4,
  longitudeDelta: 0.4,
};

// Street-level span the find-me control zooms to (≈ a neighborhood).
const FIND_ME_DELTA = 0.01;

function computeRegion(
  currentLocation: LocationData,
  knownPlaces: KnownPlace[],
  path: PathPoint[],
): Region | null {
  const lats: number[] = [];
  const lngs: number[] = [];
  for (const p of knownPlaces) {
    lats.push(p.latitude);
    lngs.push(p.longitude);
  }
  if (currentLocation) {
    lats.push(currentLocation.latitude);
    lngs.push(currentLocation.longitude);
  }
  for (const p of path) {
    if (Number.isFinite(p.lat) && Number.isFinite(p.lon)) {
      lats.push(p.lat);
      lngs.push(p.lon);
    }
  }
  if (lats.length === 0) return null;

  const minLat = Math.min(...lats);
  const maxLat = Math.max(...lats);
  const minLng = Math.min(...lngs);
  const maxLng = Math.max(...lngs);

  const latSpan = Math.max(maxLat - minLat, 0.005);
  const lngSpan = Math.max(maxLng - minLng, 0.005);

  return {
    latitude: (minLat + maxLat) / 2,
    longitude: (minLng + maxLng) / 2,
    latitudeDelta: latSpan * 1.4,
    longitudeDelta: lngSpan * 1.4,
  };
}

function PlacePin({ color, label }: { color: string; label: string }) {
  const icon = iconForPlace(label);
  if (icon) {
    return (
      <View style={pinStyles.iconBubble} pointerEvents="none">
        <View style={[pinStyles.iconRing, { borderColor: color }]}>
          <Text style={pinStyles.iconGlyph}>{icon}</Text>
        </View>
      </View>
    );
  }
  return (
    <View style={pinStyles.wrap} pointerEvents="none">
      <View style={[pinStyles.dot, { backgroundColor: color }]} />
      <View style={pinStyles.labelChip}>
        <Text style={pinStyles.labelText} numberOfLines={1}>
          {label}
        </Text>
      </View>
    </View>
  );
}

function CurrentPin() {
  return (
    <View style={pinStyles.wrap} pointerEvents="none">
      <View style={pinStyles.halo} />
      <View
        style={[
          pinStyles.diamond,
          { backgroundColor: CURRENT_LOCATION_COLOR },
        ]}
      />
      <View style={[pinStyles.labelChip, pinStyles.currentLabelChip]}>
        <Text style={pinStyles.labelText}>You</Text>
      </View>
    </View>
  );
}

type SurfaceProps = {
  region: Region;
  currentLocation: LocationData;
  knownPlaces: KnownPlace[];
  polylineCoords: { latitude: number; longitude: number }[];
  placeColors?: Map<string, string>;
  /** This surface fills its parent (fullscreen) vs. fixed embedded height. */
  fullscreen: boolean;
  height: number;
  /** Toggle handler: enter fullscreen (embedded) or exit it (fullscreen). */
  onToggleFullscreen: () => void;
  /** Frame testID — "stylized-map" (embedded) or "stylized-map-fullscreen". */
  frameTestID: string;
  /** Control testID prefix — "map-" (embedded) or "map-fs-" (fullscreen). */
  idPrefix: string;
};

/**
 * The map itself plus its overlay controls. Owns its own MapView ref so the
 * find-me control animates the right camera, and its own copy-confirmation
 * state. Rendered twice: once embedded, once inside the fullscreen modal.
 */
function MapSurface({
  region,
  currentLocation,
  knownPlaces,
  polylineCoords,
  placeColors,
  fullscreen,
  height,
  onToggleFullscreen,
  frameTestID,
  idPrefix,
}: SurfaceProps) {
  const mapRef = useRef<MapView>(null);
  const [copyState, setCopyState] = useState<"idle" | "copied">("idle");
  // Transient hint shown when a location-dependent control is tapped before
  // there's a live GPS fix (the controls stay visible so they don't vanish).
  const [hint, setHint] = useState<string | null>(null);

  const NO_LOCK = "Waiting for a live GPS lock…";

  function showHint(msg: string) {
    setHint(msg);
    setTimeout(() => setHint(null), 1800);
  }

  function handleFindMe() {
    if (!currentLocation) {
      showHint(NO_LOCK);
      return;
    }
    mapRef.current?.animateToRegion(
      {
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        latitudeDelta: FIND_ME_DELTA,
        longitudeDelta: FIND_ME_DELTA,
      },
      350,
    );
  }

  async function handleCopyCoords() {
    if (!currentLocation) {
      showHint(NO_LOCK);
      return;
    }
    const text = `${currentLocation.latitude.toFixed(6)}, ${currentLocation.longitude.toFixed(6)}`;
    await Clipboard.setStringAsync(text);
    setCopyState("copied");
    setTimeout(() => setCopyState("idle"), 1500);
  }

  const pos = fullscreen ? fsPositions : embeddedPositions;

  return (
    <View
      style={[styles.frame, fullscreen ? { flex: 1 } : { height }]}
      testID={frameTestID}
    >
      <MapView
        ref={mapRef}
        provider={PROVIDER_DEFAULT}
        style={StyleSheet.absoluteFill}
        initialRegion={region ?? FALLBACK_REGION}
        showsCompass={false}
        showsScale={false}
        toolbarEnabled={false}
        rotateEnabled={false}
        pitchEnabled={false}
      >
        {knownPlaces.map((p, idx) => {
          const color =
            placeColors?.get(p.name) ?? PLACE_COLORS[idx % PLACE_COLORS.length];
          return (
            <Marker
              key={`p-${p.id}`}
              identifier={`map-pin-p-${p.id}`}
              testID={`map-pin-p-${p.id}`}
              coordinate={{ latitude: p.latitude, longitude: p.longitude }}
              title={p.name}
              anchor={{ x: 0.5, y: 0.5 }}
              tracksViewChanges={false}
            >
              <PlacePin color={color} label={p.name} />
            </Marker>
          );
        })}
        {currentLocation && (
          <Marker
            identifier="map-pin-current"
            testID="map-pin-current"
            coordinate={{
              latitude: currentLocation.latitude,
              longitude: currentLocation.longitude,
            }}
            title="You"
            anchor={{ x: 0.5, y: 0.5 }}
            tracksViewChanges={false}
          >
            <CurrentPin />
          </Marker>
        )}
        {polylineCoords.length >= 2 && (
          <Polyline
            testID="map-path-polyline"
            coordinates={polylineCoords}
            strokeColor="rgba(76, 201, 240, 0.85)"
            strokeWidth={3}
          />
        )}
      </MapView>

      <TouchableOpacity
        onPress={onToggleFullscreen}
        style={[styles.control, pos.fullscreen]}
        testID={`${idPrefix}fullscreen`}
        accessibilityLabel={fullscreen ? "Exit fullscreen map" : "Expand map to fullscreen"}
        hitSlop={8}
      >
        <Text style={styles.controlGlyph}>{fullscreen ? "⤡" : "⤢"}</Text>
      </TouchableOpacity>

      <TouchableOpacity
        onPress={handleFindMe}
        style={[styles.control, pos.findMe, !currentLocation && styles.controlIdle]}
        testID={`${idPrefix}find-me`}
        accessibilityLabel="Recenter map on my location"
        hitSlop={8}
      >
        <Text style={styles.controlGlyph}>◎</Text>
      </TouchableOpacity>

      <TouchableOpacity
        onPress={handleCopyCoords}
        style={[styles.control, pos.copy, !currentLocation && styles.controlIdle]}
        testID={`${idPrefix}copy-coords`}
        accessibilityLabel="Copy current coordinates"
        hitSlop={8}
      >
        <Text style={styles.controlGlyph}>
          {copyState === "copied" ? "✓" : "⧉"}
        </Text>
      </TouchableOpacity>

      {hint && (
        <View style={styles.hintWrap} pointerEvents="none">
          <View style={styles.hintBubble} testID={`${idPrefix}hint`}>
            <Text style={styles.hintText}>{hint}</Text>
          </View>
        </View>
      )}
    </View>
  );
}

export function StylizedMap({
  currentLocation,
  knownPlaces,
  height = 180,
  path,
  placeColors,
}: Props) {
  const [fullscreen, setFullscreen] = useState(false);

  const cleanPath = useMemo(
    () =>
      (path ?? []).filter(
        (p) => Number.isFinite(p.lat) && Number.isFinite(p.lon),
      ),
    [path],
  );

  const region = useMemo(
    () => computeRegion(currentLocation, knownPlaces, cleanPath),
    [currentLocation, knownPlaces, cleanPath],
  );

  if (!region) {
    return (
      <View style={[styles.frame, styles.emptyFrame, { height }]} testID="stylized-map">
        <Text style={styles.emptyText}>
          No location yet — grab context or add a known place.
        </Text>
      </View>
    );
  }

  const polylineCoords = cleanPath.map((p) => ({
    latitude: p.lat,
    longitude: p.lon,
  }));

  const surfaceData = {
    region,
    currentLocation,
    knownPlaces,
    polylineCoords,
    placeColors,
  };

  return (
    <>
      <MapSurface
        {...surfaceData}
        fullscreen={false}
        height={height}
        onToggleFullscreen={() => setFullscreen(true)}
        frameTestID="stylized-map"
        idPrefix="map-"
      />
      {fullscreen && (
        <Modal
          visible
          animationType="slide"
          presentationStyle="fullScreen"
          onRequestClose={() => setFullscreen(false)}
          testID="map-fullscreen-modal"
        >
          <View style={styles.fullscreenBackdrop}>
            <MapSurface
              {...surfaceData}
              fullscreen
              height={height}
              onToggleFullscreen={() => setFullscreen(false)}
              frameTestID="stylized-map-fullscreen"
              idPrefix="map-fs-"
            />
          </View>
        </Modal>
      )}
    </>
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
  fullscreenBackdrop: {
    flex: 1,
    backgroundColor: "#0e1a2b",
  },
  emptyFrame: {
    justifyContent: "center",
    alignItems: "center",
    padding: 16,
  },
  emptyText: { color: "#666", fontSize: 12, textAlign: "center" },
  control: {
    position: "absolute",
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(20, 20, 30, 0.65)",
  },
  controlGlyph: {
    fontSize: 16,
    color: "#fff",
    textAlign: "center",
  },
  // Dimmed slightly when there's no live fix yet — still tappable (taps show
  // the "waiting for a lock" hint) but visually signals it's not ready.
  controlIdle: { opacity: 0.55 },
  hintWrap: {
    position: "absolute",
    bottom: 10,
    left: 0,
    right: 0,
    alignItems: "center",
  },
  hintBubble: {
    maxWidth: 240,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 14,
    backgroundColor: "rgba(20, 20, 30, 0.88)",
  },
  hintText: { color: "#fff", fontSize: 12, textAlign: "center" },
});

// All three controls stack at the top-right, out of the way of the map
// content. Fullscreen on top, then find-me, then copy. The fullscreen
// variant starts lower to clear the notch.
const embeddedPositions = StyleSheet.create({
  fullscreen: { top: 8, right: 8 },
  findMe: { top: 48, right: 8 },
  copy: { top: 88, right: 8 },
});

const fsPositions = StyleSheet.create({
  fullscreen: { top: 54, right: 16 },
  findMe: { top: 94, right: 16 },
  copy: { top: 134, right: 16 },
});

const pinStyles = StyleSheet.create({
  wrap: { alignItems: "center" },
  dot: {
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 2,
    borderColor: "#fff",
  },
  diamond: {
    width: 14,
    height: 14,
    borderWidth: 2,
    borderColor: "#fff",
    transform: [{ rotate: "45deg" }],
  },
  halo: {
    position: "absolute",
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "rgba(76, 201, 240, 0.22)",
    top: -9,
  },
  labelChip: {
    flexDirection: "row",
    alignItems: "center",
    marginTop: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    backgroundColor: "rgba(20, 20, 30, 0.85)",
    maxWidth: 140,
  },
  currentLabelChip: {
    marginTop: 7,
    backgroundColor: "rgba(76, 201, 240, 0.9)",
  },
  labelText: {
    color: "#fff",
    fontSize: 11,
    fontWeight: "600",
  },
  iconText: {
    fontSize: 11,
  },
  iconBubble: { alignItems: "center" },
  iconRing: {
    width: 34,
    height: 34,
    borderRadius: 17,
    borderWidth: 2.5,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center",
  },
  iconGlyph: {
    fontSize: 19,
    lineHeight: 22,
  },
});
