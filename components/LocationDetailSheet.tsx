import React, { useState } from "react";
import {
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  Platform,
} from "react-native";
import * as Location from "expo-location";
import * as FileSystem from "expo-file-system/legacy";
import * as Sharing from "expo-sharing";
import type { SQLiteDatabase } from "expo-sqlite";
import { type KnownPlace } from "../lib/places";
import { DB_NAME, getKnownPlaces, addKnownPlace, deleteKnownPlace, type LocationHistoryItem } from "../lib/db";

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type LocationDetailSheetProps = {
  visible: boolean;
  onClose: () => void;
  db: SQLiteDatabase | null;
  location: LocationData;
  locationHistory: LocationHistoryItem[];
  knownPlaces: KnownPlace[];
  setKnownPlaces: (places: KnownPlace[]) => void;
  setError: (msg: string | null) => void;
  locationSummaryText: string | null;
};

// --- Component ---

export default function LocationDetailSheet({
  visible,
  onClose,
  db,
  location,
  locationHistory,
  knownPlaces,
  setKnownPlaces,
  setError,
  locationSummaryText,
}: LocationDetailSheetProps) {
  // Form state
  const [newPlaceName, setNewPlaceName] = useState("");
  const [newPlaceLat, setNewPlaceLat] = useState("");
  const [newPlaceLng, setNewPlaceLng] = useState("");
  const [newPlaceRadius, setNewPlaceRadius] = useState("100");
  const [importJson, setImportJson] = useState("");
  const [placesExpanded, setPlacesExpanded] = useState(false);
  const [gpsStatus, setGpsStatus] = useState<string | null>(null);
  const [dbExportStatus, setDbExportStatus] = useState<string | null>(null);

  // --- Handlers ---

  async function handleAddPlace() {
    if (!db) {
      setError("Database not available. Please restart the app.");
      return;
    }
    const name = newPlaceName.trim();
    const lat = parseFloat(newPlaceLat);
    const lng = parseFloat(newPlaceLng);
    const radius = parseFloat(newPlaceRadius) || 100;
    if (!name) {
      setError("Place name is required");
      return;
    }
    if (isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      setError("Valid latitude (-90 to 90) and longitude (-180 to 180) required");
      return;
    }
    try {
      await addKnownPlace(db, name, lat, lng, radius);
      const places = await getKnownPlaces(db);
      setKnownPlaces(places);
      setNewPlaceName("");
      setNewPlaceLat("");
      setNewPlaceLng("");
      setNewPlaceRadius("100");
    } catch (e: any) {
      setError(e.message ?? "Failed to add place");
    }
  }

  async function handleDeletePlace(id: number) {
    if (!db) return;
    try {
      await deleteKnownPlace(db, id);
      const places = await getKnownPlaces(db);
      setKnownPlaces(places);
    } catch (e: any) {
      setError(e.message ?? "Failed to delete place");
    }
  }

  async function handleUseCurrentLocation() {
    try {
      setGpsStatus("Getting fresh GPS fix...");
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== "granted") {
        setGpsStatus("Location permission denied");
        return;
      }
      const loc = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Highest,
      });
      const age = Date.now() - loc.timestamp;
      if (age > 30000) {
        setGpsStatus(`GPS reading is ${Math.round(age / 1000)}s old — try again outdoors`);
        return;
      }
      const accuracy = Math.round(loc.coords.accuracy ?? 0);
      setNewPlaceLat(loc.coords.latitude.toFixed(6));
      setNewPlaceLng(loc.coords.longitude.toFixed(6));
      setGpsStatus(`Got fix: ±${accuracy}m accuracy`);
    } catch (e: any) {
      setGpsStatus(`GPS error: ${e.message}`);
    }
  }

  async function handleImportPlacesJson(json: string) {
    if (!db) {
      setError("Database not available. Please restart the app.");
      return;
    }
    try {
      const parsed = JSON.parse(json);
      const items = Array.isArray(parsed) ? parsed : parsed.knownPlaces ?? parsed.places;
      if (!Array.isArray(items)) {
        setError("JSON must be an array or have a knownPlaces/places array");
        return;
      }
      let added = 0;
      for (const p of items) {
        const name = String(p.name ?? "").trim();
        const lat = Number(p.lat ?? p.latitude);
        const lng = Number(p.lon ?? p.lng ?? p.longitude);
        const radius = Number(p.radiusMeters ?? p.radius_meters ?? p.radius ?? 100);
        if (!name || isNaN(lat) || isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
        await addKnownPlace(db, name, lat, lng, radius);
        added++;
      }
      const places = await getKnownPlaces(db);
      setKnownPlaces(places);
      setImportJson("");
      if (added === 0) setError("No valid places found in JSON");
    } catch (e: any) {
      setError(e.message ?? "Invalid JSON");
    }
  }

  async function handleDownloadDatabase() {
    try {
      setDbExportStatus("Exporting...");
      const dbPath = `${FileSystem.documentDirectory}SQLite/${DB_NAME}`;
      const info = await FileSystem.getInfoAsync(dbPath);
      if (!info.exists) {
        setDbExportStatus("DB not found at path");
        return;
      }
      const sizeKB = info.size ? Math.round(info.size / 1024) : 0;
      setDbExportStatus(`Sharing ${sizeKB}KB...`);
      const exportPath = `${FileSystem.cacheDirectory}${DB_NAME}`;
      await FileSystem.copyAsync({ from: dbPath, to: exportPath });
      await Sharing.shareAsync(exportPath, {
        mimeType: "application/x-sqlite3",
        dialogTitle: "Export Database",
        UTI: "public.database",
      });
      setDbExportStatus("Exported!");
    } catch (e: any) {
      setDbExportStatus(e.message ?? "Export failed");
    }
  }

  // --- Render ---

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={styles.modalContainer}>
        <View style={styles.modalHeader}>
          <Text style={styles.modalTitle}>Location</Text>
          <TouchableOpacity onPress={onClose} style={styles.modalCloseButton}>
            <Text style={styles.modalCloseText}>Done</Text>
          </TouchableOpacity>
        </View>
        <ScrollView style={styles.modalContent} keyboardDismissMode="on-drag" keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingBottom: 300 }}>
          <View style={styles.aboutCard}>
            <Text style={styles.metricLabel}>Current Location</Text>
            {location ? (
              <Text style={styles.metricValue}>
                {location.latitude.toFixed(4)}, {location.longitude.toFixed(4)}
              </Text>
            ) : (
              <Text style={[styles.metricValue, styles.metricValueNull]}>Unavailable</Text>
            )}
            {locationHistory.length > 0 && (
              <Text style={styles.locationCountText}>
                {locationHistory.length} point{locationHistory.length !== 1 ? "s" : ""} in trail
              </Text>
            )}
            {locationSummaryText && (
              <Text style={{ color: "#ccc", fontSize: 12, fontFamily: "Courier", marginTop: 12 }}>
                {locationSummaryText}
              </Text>
            )}

            <TouchableOpacity
              style={[styles.addPlaceButton, { marginTop: 12 }]}
              onPress={handleDownloadDatabase}
              testID="export-db-button"
            >
              <Text style={styles.addPlaceButtonText} testID="export-db-status">
                {dbExportStatus ?? "Export Database"}
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.aboutCard}>
            <TouchableOpacity onPress={() => setPlacesExpanded(!placesExpanded)} style={styles.settingRow}>
              <Text style={styles.metricLabel}>Known Places ({knownPlaces.length})</Text>
              <Text style={{ color: "#888", fontSize: 16 }}>{placesExpanded ? "\u25B2" : "\u25BC"}</Text>
            </TouchableOpacity>
            {placesExpanded && (
              <>
                <Text style={styles.locationCountText}>
                  GPS points within radius will use these names instead of generic "Place N" labels
                </Text>

                {knownPlaces.map((place) => (
                  <View key={place.id} style={styles.knownPlaceRow}>
                    <View style={styles.knownPlaceInfo}>
                      <Text style={styles.knownPlaceName}>{place.name}</Text>
                      <Text style={styles.knownPlaceDetail}>
                        {place.latitude.toFixed(4)}, {place.longitude.toFixed(4)} ({place.radiusMeters}m)
                      </Text>
                    </View>
                    <TouchableOpacity
                      onPress={() => handleDeletePlace(place.id)}
                      style={styles.knownPlaceDelete}
                    >
                      <Text style={styles.knownPlaceDeleteText}>X</Text>
                    </TouchableOpacity>
                  </View>
                ))}

                <View style={styles.addPlaceForm}>
                  <TextInput
                    style={styles.addPlaceInput}
                    placeholder="Name"
                    placeholderTextColor="#666"
                    value={newPlaceName}
                    onChangeText={setNewPlaceName}
                  />
                  <View style={styles.addPlaceCoordRow}>
                    <TextInput
                      style={[styles.addPlaceInput, styles.addPlaceCoordInput]}
                      placeholder="Latitude"
                      placeholderTextColor="#666"
                      value={newPlaceLat}
                      onChangeText={setNewPlaceLat}
                      keyboardType="decimal-pad"
                    />
                    <TextInput
                      style={[styles.addPlaceInput, styles.addPlaceCoordInput]}
                      placeholder="Longitude"
                      placeholderTextColor="#666"
                      value={newPlaceLng}
                      onChangeText={setNewPlaceLng}
                      keyboardType="decimal-pad"
                    />
                  </View>
                  <View style={styles.addPlaceCoordRow}>
                    <TextInput
                      style={[styles.addPlaceInput, styles.addPlaceCoordInput]}
                      placeholder="Radius (m)"
                      placeholderTextColor="#666"
                      value={newPlaceRadius}
                      onChangeText={setNewPlaceRadius}
                      keyboardType="number-pad"
                    />
                    <TouchableOpacity
                      style={[styles.addPlaceButton, { backgroundColor: "#3d405b" }]}
                      onPress={handleUseCurrentLocation}
                    >
                      <Text style={styles.addPlaceButtonText}>Use Current</Text>
                    </TouchableOpacity>
                  </View>
                  {gpsStatus && (
                    <Text style={styles.locationCountText}>{gpsStatus}</Text>
                  )}
                  <TouchableOpacity
                    style={styles.addPlaceButton}
                    onPress={handleAddPlace}
                  >
                    <Text style={styles.addPlaceButtonText}>Add Place</Text>
                  </TouchableOpacity>
                </View>

                <Text style={[styles.knownPlaceName, { marginTop: 16 }]}>Import JSON</Text>
                <TextInput
                  style={[styles.addPlaceInput, { height: 80, textAlignVertical: "top" }]}
                  placeholder='[{"name":"Home","lat":47.64,"lon":-122.30,"radiusMeters":100}]'
                  placeholderTextColor="#555"
                  value={importJson}
                  onChangeText={setImportJson}
                  multiline
                />
                <TouchableOpacity
                  style={styles.addPlaceButton}
                  onPress={() => handleImportPlacesJson(importJson)}
                >
                  <Text style={styles.addPlaceButtonText}>Import Places</Text>
                </TouchableOpacity>
              </>
            )}
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

// --- Styles ---

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    backgroundColor: "#1a1a2e",
  },
  modalHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingTop: Platform.OS === "ios" ? 16 : 20,
    paddingHorizontal: 20,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: "#16213e",
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: "bold",
    color: "#e0e0e0",
  },
  modalCloseButton: {
    padding: 4,
  },
  modalCloseText: {
    color: "#4361ee",
    fontSize: 16,
    fontWeight: "600",
  },
  modalContent: {
    flex: 1,
    paddingHorizontal: 20,
  },
  aboutCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 16,
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
  locationCountText: {
    fontSize: 13,
    color: "#888",
    marginTop: 4,
  },
  settingRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 8,
  },
  knownPlaceRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: "#1a1a2e",
    marginTop: 4,
  },
  knownPlaceInfo: {
    flex: 1,
  },
  knownPlaceName: {
    fontSize: 15,
    fontWeight: "600",
    color: "#e0e0e0",
  },
  knownPlaceDetail: {
    fontSize: 12,
    color: "#888",
    marginTop: 2,
  },
  knownPlaceDelete: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: "#3d1f1f",
    justifyContent: "center",
    alignItems: "center",
    marginLeft: 8,
  },
  knownPlaceDeleteText: {
    color: "#ff6b6b",
    fontSize: 13,
    fontWeight: "700",
  },
  addPlaceForm: {
    marginTop: 12,
    gap: 8,
  },
  addPlaceInput: {
    backgroundColor: "#1a1a2e",
    color: "#fff",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 14,
    borderWidth: 1,
    borderColor: "#333",
  },
  addPlaceCoordRow: {
    flexDirection: "row",
    gap: 8,
  },
  addPlaceCoordInput: {
    flex: 1,
  },
  addPlaceButton: {
    backgroundColor: "#2d6a4f",
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: "center",
  },
  addPlaceButtonText: {
    color: "#fff",
    fontSize: 14,
    fontWeight: "600",
  },
});
