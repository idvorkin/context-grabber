import { StatusBar } from "expo-status-bar";
import { useState, useEffect, useCallback, useRef } from "react";
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  TouchableOpacity,
  Share,
  Platform,
  Switch,
  TextInput,
  AppState,
  Modal,
  Linking,

} from "react-native";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as SQLite from "expo-sqlite";
import * as Updates from "expo-updates";
import * as FileSystem from "expo-file-system/legacy";
import * as Sharing from "expo-sharing";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import { buildHealthData, type HealthData, type HealthQueryResults, type SleepSample } from "./lib/health";
import { pruneThreshold } from "./lib/location";
import { buildSummary, formatNumber } from "./lib/summary";
import { getBuildInfo, formatBuildTimestamp } from "./lib/version";
import {
  type MetricKey,
  type DailyValue,
  type HeartRateDaily,
  METRIC_CONFIG,
  aggregateHeartRate,
  aggregateSleep,
  aggregateMeditation,
  pickLatestPerDay,
  formatDateKey,
} from "./lib/weekly";
import { buildSummaryExport, type WeeklyDataMap, type LocationSummary } from "./lib/share";
import { clusterLocations } from "./lib/clustering";
import { type KnownPlace } from "./lib/places";
import { computeBoxPlotStats, extractValues, type BoxPlotStats } from "./lib/stats";
import {
  initCacheTables,
  getComputedCachedBatch,
  getRawCachedBatch,
  putComputedCached,
  putRawCached,
  buildDateKeys,
  partitionDays,
} from "./lib/healthCache";
import MetricDetailSheet from "./components/MetricDetailSheet";
import BoxPlot from "./components/BoxPlot";

// --- Constants ---

const LOCATION_TASK_NAME = "background-location-task";

const DB_NAME = "context-grabber.db";

type LocationHistoryItem = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  timestamp: number;
};

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type ContextSnapshot = {
  timestamp: string;
  health: HealthData;
  location: LocationData;
  locationHistory: LocationHistoryItem[];
};

const QTI = {
  stepCount: "HKQuantityTypeIdentifierStepCount" as QuantityTypeIdentifier,
  heartRate: "HKQuantityTypeIdentifierHeartRate" as QuantityTypeIdentifier,
  activeEnergy:
    "HKQuantityTypeIdentifierActiveEnergyBurned" as QuantityTypeIdentifier,
  distance:
    "HKQuantityTypeIdentifierDistanceWalkingRunning" as QuantityTypeIdentifier,
  bodyMass: "HKQuantityTypeIdentifierBodyMass" as QuantityTypeIdentifier,
  hrv: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN" as QuantityTypeIdentifier,
  restingHeartRate: "HKQuantityTypeIdentifierRestingHeartRate" as QuantityTypeIdentifier,
  exerciseTime: "HKQuantityTypeIdentifierAppleExerciseTime" as QuantityTypeIdentifier,
};

const CTI = {
  sleep: "HKCategoryTypeIdentifierSleepAnalysis" as CategoryTypeIdentifier,
  mindfulSession:
    "HKCategoryTypeIdentifierMindfulSession" as CategoryTypeIdentifier,
};

// --- SQLite helpers (module-level for use by background task) ---

async function openDB(): Promise<SQLite.SQLiteDatabase> {
  return SQLite.openDatabaseAsync(DB_NAME);
}

async function initDB(db: SQLite.SQLiteDatabase): Promise<void> {
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      accuracy REAL,
      timestamp INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp);
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS known_places (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      radius_meters REAL NOT NULL DEFAULT 100
    );
    INSERT OR IGNORE INTO settings (key, value) VALUES ('schema_version', '1');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('tracking_enabled', 'false');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('retention_days', '30');
  `);
  await initCacheTables(db);
}

async function getSetting(
  db: SQLite.SQLiteDatabase,
  key: string,
  defaultValue: string,
): Promise<string> {
  const row = await db.getFirstAsync<{ value: string }>(
    "SELECT value FROM settings WHERE key = ?",
    [key],
  );
  return row?.value ?? defaultValue;
}

async function setSetting(
  db: SQLite.SQLiteDatabase,
  key: string,
  value: string,
): Promise<void> {
  await db.runAsync(
    "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
    [key, value],
  );
}

async function insertLocation(
  db: SQLite.SQLiteDatabase,
  latitude: number,
  longitude: number,
  accuracy: number | null,
  timestamp: number,
): Promise<void> {
  await db.runAsync(
    "INSERT INTO locations (latitude, longitude, accuracy, timestamp) VALUES (?, ?, ?, ?)",
    [latitude, longitude, accuracy, timestamp],
  );
}

async function pruneLocations(
  db: SQLite.SQLiteDatabase,
  retentionDays: number,
): Promise<void> {
  const threshold = pruneThreshold(retentionDays, Date.now());
  await db.runAsync("DELETE FROM locations WHERE timestamp < ?", [threshold]);
}

async function getLocationCount(db: SQLite.SQLiteDatabase): Promise<number> {
  const row = await db.getFirstAsync<{ count: number }>(
    "SELECT COUNT(*) as count FROM locations",
  );
  return row?.count ?? 0;
}

async function getLocationStorageBytes(db: SQLite.SQLiteDatabase): Promise<number> {
  const row = await db.getFirstAsync<{ size: number }>(
    "SELECT SUM(LENGTH(latitude) + LENGTH(longitude) + LENGTH(accuracy) + LENGTH(timestamp) + 20) as size FROM locations",
  );
  return row?.size ?? 0;
}

async function getKnownPlaces(
  db: SQLite.SQLiteDatabase,
): Promise<KnownPlace[]> {
  const rows = await db.getAllAsync<{
    id: number;
    name: string;
    latitude: number;
    longitude: number;
    radius_meters: number;
  }>("SELECT id, name, latitude, longitude, radius_meters FROM known_places ORDER BY name ASC");
  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    radiusMeters: r.radius_meters,
  }));
}

async function addKnownPlace(
  db: SQLite.SQLiteDatabase,
  name: string,
  latitude: number,
  longitude: number,
  radiusMeters: number,
): Promise<void> {
  await db.runAsync(
    "INSERT INTO known_places (name, latitude, longitude, radius_meters) VALUES (?, ?, ?, ?)",
    [name, latitude, longitude, radiusMeters],
  );
}

async function deleteKnownPlace(
  db: SQLite.SQLiteDatabase,
  id: number,
): Promise<void> {
  await db.runAsync("DELETE FROM known_places WHERE id = ?", [id]);
}

async function getLocationHistory(
  db: SQLite.SQLiteDatabase,
): Promise<LocationHistoryItem[]> {
  const rows = await db.getAllAsync<LocationHistoryItem>(
    "SELECT latitude, longitude, accuracy, timestamp FROM locations ORDER BY timestamp ASC",
  );
  return rows;
}

// --- Background Location Task (MUST be at module scope) ---

TaskManager.defineTask(LOCATION_TASK_NAME, async ({ data, error }) => {
  if (error) {
    console.error("Background location task error:", error.message);
    return;
  }
  if (!data) return;
  const locationData = data as { locations?: Location.LocationObject[] };
  const locations = locationData.locations;
  if (!Array.isArray(locations)) return;
  try {
    const db = await openDB();
    await initDB(db);
    for (const loc of locations) {
      await insertLocation(
        db,
        loc.coords.latitude,
        loc.coords.longitude,
        loc.coords.accuracy,
        loc.timestamp,
      );
    }
  } catch (e) {
    console.error("Failed to store background location:", e);
  }
});

// --- MetricCard Component ---

type MetricCardProps = {
  metricKey: MetricKey;
  label: string;
  value: string;
  sublabel: string;
  fullWidth?: boolean;
  onPress: (key: MetricKey) => void;
  boxPlotStats?: BoxPlotStats | null;
  color?: string;
};

function MetricCard({ metricKey, label, value, sublabel, fullWidth, onPress, boxPlotStats, color }: MetricCardProps) {
  const isNull = value === "\u2014";
  return (
    <TouchableOpacity
      style={[styles.metricCard, fullWidth && styles.metricCardFull]}
      onPress={() => onPress(metricKey)}
      activeOpacity={0.7}
    >
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={[styles.metricValue, isNull && styles.metricValueNull]}>
        {value}
      </Text>
      {boxPlotStats && color ? (
        <BoxPlot stats={boxPlotStats} color={color} />
      ) : (
        <Text style={styles.metricSublabel}>{sublabel}</Text>
      )}
    </TouchableOpacity>
  );
}

// --- About Modal ---

function AboutModal({
  visible,
  onClose,
}: {
  visible: boolean;
  onClose: () => void;
}) {
  const buildInfo = getBuildInfo();
  const updateChannel = Updates.channel ?? "N/A";
  const runtimeVersion = Updates.runtimeVersion ?? "N/A";
  const updateId = Updates.updateId ?? "embedded";
  const [updateStatus, setUpdateStatus] = useState<string | null>(null);
  const [dbExportStatus, setDbExportStatus] = useState<string | null>(null);

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
      // Copy to a temp location so share sheet can access it
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

  async function handleCheckForUpdate() {
    try {
      setUpdateStatus("Checking...");
      const result = await Updates.fetchUpdateAsync();
      if (result.isNew) {
        setUpdateStatus("Reloading...");
        await Updates.reloadAsync();
      } else {
        setUpdateStatus("Already up to date");
      }
    } catch (e: any) {
      setUpdateStatus(e.message ?? "Update failed");
    }
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <View style={styles.modalContainer}>
        <View style={styles.modalHeader}>
          <Text style={styles.modalTitle}>About</Text>
          <TouchableOpacity onPress={onClose} style={styles.modalCloseButton}>
            <Text style={styles.modalCloseText}>Done</Text>
          </TouchableOpacity>
        </View>

        <ScrollView style={styles.modalContent}>
          <View style={styles.aboutCard}>
            <Text style={styles.aboutAppName}>Context Grabber</Text>
            <Text style={styles.aboutTagline}>
              Export HealthKit, GPS & location data for AI life coaching
            </Text>
          </View>

          <View style={styles.aboutCard}>
            <Text style={styles.metricLabel}>Build Info</Text>

            <View style={styles.aboutRow}>
              <Text style={styles.aboutRowLabel}>Version</Text>
              <Text style={styles.aboutRowValue}>
                {buildInfo.shortSha} ({buildInfo.branch})
              </Text>
            </View>

            {buildInfo.timestamp ? (
              <View style={styles.aboutRow}>
                <Text style={styles.aboutRowLabel}>Built</Text>
                <Text style={styles.aboutRowValue}>
                  {formatBuildTimestamp(buildInfo.timestamp)}
                </Text>
              </View>
            ) : null}

            {buildInfo.commitUrl ? (
              <TouchableOpacity
                style={styles.aboutRow}
                onPress={() => Linking.openURL(buildInfo.commitUrl)}
              >
                <Text style={styles.aboutRowLabel}>Commit</Text>
                <Text style={[styles.aboutRowValue, styles.aboutLink]}>
                  View on GitHub
                </Text>
              </TouchableOpacity>
            ) : null}

            <View style={styles.aboutRow}>
              <Text style={styles.aboutRowLabel}>Channel</Text>
              <Text style={styles.aboutRowValue}>{updateChannel}</Text>
            </View>

            <View style={styles.aboutRow}>
              <Text style={styles.aboutRowLabel}>Runtime</Text>
              <Text style={styles.aboutRowValue}>{runtimeVersion}</Text>
            </View>

            <View style={styles.aboutRow}>
              <Text style={styles.aboutRowLabel}>Update</Text>
              <Text style={styles.aboutRowValue}>{updateId}</Text>
            </View>

            <TouchableOpacity
              style={[styles.addPlaceButton, { marginTop: 8 }]}
              onPress={handleCheckForUpdate}
            >
              <Text style={styles.addPlaceButtonText}>
                {updateStatus ?? "Check for Updates"}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.addPlaceButton, { marginTop: 8 }]}
              onPress={handleDownloadDatabase}
              testID="export-db-button"
            >
              <Text style={styles.addPlaceButtonText} testID="export-db-status">
                {dbExportStatus ?? "Export Database"}
              </Text>
            </TouchableOpacity>

            {buildInfo.repoUrl ? (
              <TouchableOpacity
                style={styles.aboutRow}
                onPress={() => Linking.openURL(buildInfo.repoUrl)}
              >
                <Text style={styles.aboutRowLabel}>Repository</Text>
                <Text style={[styles.aboutRowValue, styles.aboutLink]}>
                  View on GitHub
                </Text>
              </TouchableOpacity>
            ) : null}
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

// --- App Component ---

export default function App() {
  const [snapshot, setSnapshot] = useState<ContextSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [trackingEnabled, setTrackingEnabled] = useState(false);
  const [retentionDays, setRetentionDays] = useState("30");
  const [locationCount, setLocationCount] = useState(0);
  const [db, setDb] = useState<SQLite.SQLiteDatabase | null>(null);
  const [aboutVisible, setAboutVisible] = useState(false);
  const [selectedMetric, setSelectedMetric] = useState<MetricKey | null>(null);
  const [weeklyCache, setWeeklyCache] = useState<Partial<Record<MetricKey, DailyValue[] | HeartRateDaily[]>>>({});
  const [weeklyLoading, setWeeklyLoading] = useState(false);
  const [weeklyError, setWeeklyError] = useState<string | null>(null);
  const [statsCache, setStatsCache] = useState<Partial<Record<MetricKey, BoxPlotStats | null>>>({});
  const [locationStorageBytes, setLocationStorageBytes] = useState(0);
  const [dbReady, setDbReady] = useState(false);
  const [sharing, setSharing] = useState(false);
  const [shareStatus, setShareStatus] = useState("");
  const [settingsVisible, setSettingsVisible] = useState(false);
  const [knownPlaces, setKnownPlaces] = useState<KnownPlace[]>([]);
  const [newPlaceName, setNewPlaceName] = useState("");
  const [newPlaceLat, setNewPlaceLat] = useState("");
  const [newPlaceLng, setNewPlaceLng] = useState("");
  const [newPlaceRadius, setNewPlaceRadius] = useState("100");
  const [importJson, setImportJson] = useState("");
  const [debugSleepData, setDebugSleepData] = useState<string | null>(null);
  const [trackingExpanded, setTrackingExpanded] = useState(false);
  const [placesExpanded, setPlacesExpanded] = useState(false);
  const [debugExpanded, setDebugExpanded] = useState(false);

  // Initialize database on mount
  useEffect(() => {
    (async () => {
      try {
        const database = await openDB();
        await initDB(database);
        setDb(database);

        const enabled = await getSetting(database, "tracking_enabled", "false");
        setTrackingEnabled(enabled === "true");

        const days = await getSetting(database, "retention_days", "30");
        setRetentionDays(days);

        const count = await getLocationCount(database);
        setLocationCount(count);

        const places = await getKnownPlaces(database);
        setKnownPlaces(places);

        // Prune on startup
        await pruneLocations(database, parseInt(days, 10) || 30);
        const countAfterPrune = await getLocationCount(database);
        setLocationCount(countAfterPrune);
        const storageBytes = await getLocationStorageBytes(database);
        setLocationStorageBytes(storageBytes);
        setDbReady(true);
      } catch (e: any) {
        console.error("DB init error:", e);
        setError("Database unavailable. Location tracking and history won't work.");
      }
    })();
  }, []);

  // Auto-grab context on startup once DB is ready
  const hasAutoGrabbed = useRef(false);
  useEffect(() => {
    if (dbReady && !hasAutoGrabbed.current) {
      hasAutoGrabbed.current = true;
      grabContext();
    }
  }, [dbReady]);

  // Prune on app foreground
  useEffect(() => {
    const subscription = AppState.addEventListener("change", async (state) => {
      if (state === "active" && db) {
        try {
          const days = parseInt(
            await getSetting(db, "retention_days", "30"),
            10,
          ) || 30;
          await pruneLocations(db, days);
          const count = await getLocationCount(db);
          setLocationCount(count);
        } catch (e) {
          console.error("Prune on foreground error:", e);
        }
      }
    });
    return () => subscription.remove();
  }, [db]);

  const startTracking = useCallback(async () => {
    try {
      const { status: fgStatus } =
        await Location.requestForegroundPermissionsAsync();
      if (fgStatus !== "granted") {
        setError("Foreground location permission denied");
        return false;
      }

      const { status: bgStatus } =
        await Location.requestBackgroundPermissionsAsync();
      if (bgStatus !== "granted") {
        setError("Background location permission denied");
        return false;
      }

      await Location.startLocationUpdatesAsync(LOCATION_TASK_NAME, {
        accuracy: Location.Accuracy.Balanced,
        activityType: Location.ActivityType.Other,
        deferredUpdatesInterval: 0,
        deferredUpdatesDistance: 0,
        showsBackgroundLocationIndicator: true,
      });

      return true;
    } catch (e: any) {
      setError(e.message ?? "Failed to start tracking");
      return false;
    }
  }, []);

  const stopTracking = useCallback(async (): Promise<boolean> => {
    try {
      const hasStarted =
        await Location.hasStartedLocationUpdatesAsync(LOCATION_TASK_NAME);
      if (hasStarted) {
        await Location.stopLocationUpdatesAsync(LOCATION_TASK_NAME);
      }
      return true;
    } catch (e: any) {
      setError(e.message ?? "Failed to stop tracking");
      return false;
    }
  }, []);

  async function handleTrackingToggle(enabled: boolean) {
    if (!db) {
      setError("Database not available. Please restart the app.");
      return;
    }

    try {
      if (enabled) {
        const started = await startTracking();
        if (!started) return;
      } else {
        const stopped = await stopTracking();
        if (!stopped) return;
      }

      setTrackingEnabled(enabled);
      await setSetting(db, "tracking_enabled", enabled ? "true" : "false");
    } catch (e: any) {
      setError(e.message ?? "Failed to update tracking setting");
    }
  }

  // Track pending retention value for debounced save
  const retentionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleRetentionChange(text: string) {
    setRetentionDays(text);

    if (retentionTimerRef.current) {
      clearTimeout(retentionTimerRef.current);
    }

    retentionTimerRef.current = setTimeout(async () => {
      if (!db) {
        setError("Database not available. Please restart the app.");
        return;
      }
      const days = parseInt(text, 10);
      if (!isNaN(days) && days >= 0) {
        try {
          await setSetting(db, "retention_days", String(days));
          await pruneLocations(db, days);
          const count = await getLocationCount(db);
          setLocationCount(count);
        } catch (e: any) {
          setError(e.message ?? "Failed to update retention setting");
        }
      }
    }, 1000);
  }

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

  const [gpsStatus, setGpsStatus] = useState<string | null>(null);

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

  async function handleFetchDebugSleep() {
    try {
      setDebugSleepData("Loading...");
      const now = new Date();
      const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
      const CTI = { sleep: "HKCategoryTypeIdentifierSleepAnalysis" as any };
      const samples = await HealthKit.queryCategorySamples(CTI.sleep, {
        limit: 0,
        filter: { date: { startDate: twoDaysAgo, endDate: now } },
      });
      const raw = (samples as any[]).map((s: any) => {
        const src = s.sourceRevision?.source;
        const srcName = src?.toJSON?.()?.name ?? src?.name ?? "Unknown";
        const srcBundle = src?.toJSON?.()?.bundleIdentifier ?? src?.bundleIdentifier ?? "?";
        return {
          start: new Date(s.startDate).toISOString(),
          end: new Date(s.endDate).toISOString(),
          value: s.value,
          source: srcName,
          bundle: srcBundle,
          device: s.device?.name ?? null,
          sourceRaw: String(src),
        };
      });
      setDebugSleepData(JSON.stringify(raw, null, 2));
    } catch (e: any) {
      setDebugSleepData(`Error: ${e.message}`);
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

  async function grabHealthData(): Promise<HealthData> {
    const now = new Date();
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const dateFilter = {
      date: { startDate: startOfDay, endDate: now },
    };
    // Noon-to-noon window captures exactly one night of sleep
    const todayNoon = new Date(now);
    todayNoon.setHours(12, 0, 0, 0);
    const yesterdayNoon = new Date(todayNoon.getTime() - 24 * 60 * 60 * 1000);
    const sleepDateFilter = {
      date: { startDate: yesterdayNoon, endDate: todayNoon },
    };

    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const weightWeekFilter = {
      date: { startDate: sevenDaysAgo, endDate: now },
    };

    const results = await Promise.allSettled([
      HealthKit.queryStatisticsForQuantity(QTI.stepCount, ["cumulativeSum"], {
        filter: dateFilter,
      }),
      HealthKit.getMostRecentQuantitySample(QTI.heartRate),
      HealthKit.queryStatisticsForQuantity(
        QTI.activeEnergy,
        ["cumulativeSum"],
        { filter: dateFilter },
      ),
      HealthKit.queryStatisticsForQuantity(QTI.distance, ["cumulativeSum"], {
        filter: dateFilter,
      }),
      HealthKit.queryCategorySamples(CTI.sleep, {
        limit: 0,
        filter: sleepDateFilter,
      }),
      HealthKit.getMostRecentQuantitySample(QTI.bodyMass, "kg"),
      HealthKit.queryCategorySamples(CTI.mindfulSession, {
        limit: 0,
        filter: dateFilter,
      }),
      HealthKit.queryQuantitySamples(QTI.bodyMass, {
        limit: 0,
        filter: weightWeekFilter,
        unit: "kg",
      }),
      HealthKit.getMostRecentQuantitySample(QTI.hrv),
      HealthKit.getMostRecentQuantitySample(QTI.restingHeartRate),
      HealthKit.queryStatisticsForQuantity(
        QTI.exerciseTime,
        ["cumulativeSum"],
        { filter: dateFilter },
      ),
    ]);

    // Map source names onto sleep samples for per-source summary (new array, no mutation)
    const sleepResult = results[4];
    let mappedSleep: PromiseSettledResult<SleepSample[]>;
    if (sleepResult.status === "fulfilled" && sleepResult.value) {
      mappedSleep = {
        status: "fulfilled" as const,
        value: (sleepResult.value as any[]).map((s: any) => ({
          startDate: s.startDate,
          endDate: s.endDate,
          value: s.value,
          source: s.sourceRevision?.source?.toJSON?.()?.name ?? s.sourceRevision?.source?.name ?? "Unknown",
        })),
      };
    } else {
      mappedSleep = sleepResult.status === "fulfilled"
        ? { status: "fulfilled" as const, value: [] }
        : { status: "rejected" as const, reason: (sleepResult as PromiseRejectedResult).reason };
    }
    const healthResults: HealthQueryResults = [
      results[0], results[1], results[2], results[3],
      mappedSleep,
      results[5], results[6], results[7], results[8], results[9], results[10],
    ] as HealthQueryResults;

    return buildHealthData(healthResults);
  }

  async function grabLocation(): Promise<LocationData> {
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== "granted") {
      return null;
    }
    const loc = await Location.getCurrentPositionAsync({});
    return {
      latitude: loc.coords.latitude,
      longitude: loc.coords.longitude,
      timestamp: loc.timestamp,
    };
  }

  /** Fetch a single day's data from HealthKit (no cache). */
  async function fetchDayFromHealthKit(
    metric: MetricKey,
    dateKey: string,
  ): Promise<{ computed: DailyValue | HeartRateDaily; raw: any[] }> {
    const dayStart = new Date(dateKey + "T00:00:00");
    const dayEnd = new Date(dateKey + "T23:59:59.999");
    const dayFilter = { date: { startDate: dayStart, endDate: dayEnd } };

    switch (metric) {
      case "steps":
      case "activeEnergy":
      case "walkingDistance":
      case "exerciseMinutes": {
        const identifier =
          metric === "steps" ? QTI.stepCount
          : metric === "activeEnergy" ? QTI.activeEnergy
          : metric === "exerciseMinutes" ? QTI.exerciseTime
          : QTI.distance;
        const result = await HealthKit.queryStatisticsForQuantity(
          identifier,
          ["cumulativeSum"],
          { filter: dayFilter },
        ).catch(() => null);
        const value = result?.sumQuantity?.quantity != null
          ? Math.round(result.sumQuantity.quantity * 100) / 100
          : null;
        return {
          computed: { date: dateKey, value },
          raw: [{ date: dateKey, value, source: "statistics" }],
        };
      }
      case "heartRate":
      case "hrv":
      case "restingHeartRate": {
        const identifier =
          metric === "heartRate" ? QTI.heartRate
          : metric === "hrv" ? QTI.hrv
          : QTI.restingHeartRate;
        const samples = await HealthKit.queryQuantitySamples(identifier, {
          limit: 0,
          filter: dayFilter,
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate).toISOString(),
          quantity: s.quantity,
        }));
        // Aggregate just this one day
        const buckets = aggregateHeartRate(
          mapped.map((m) => ({ startDate: m.startDate, quantity: m.quantity })),
          dayEnd, 1,
        );
        return { computed: buckets[0], raw: mapped };
      }
      case "sleep": {
        // Sleep needs wider window for overnight sessions
        const prevDay = new Date(dayStart.getTime() - 12 * 60 * 60 * 1000);
        const samples = await HealthKit.queryCategorySamples(CTI.sleep, {
          limit: 0,
          filter: { date: { startDate: prevDay, endDate: dayEnd } },
        });
        const mapped = [...samples].map((s: any) => ({
          startDate: new Date(s.startDate).toISOString(),
          endDate: new Date(s.endDate).toISOString(),
          value: s.value,
        }));
        const buckets = aggregateSleep(mapped as any, dayEnd, 1);
        return { computed: buckets[0], raw: mapped };
      }
      case "weight": {
        const samples = await HealthKit.queryQuantitySamples(QTI.bodyMass, {
          limit: 0,
          filter: dayFilter,
          unit: "kg",
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate).toISOString(),
          quantity: s.quantity,
        }));
        const buckets = pickLatestPerDay(
          mapped.map((m) => ({ startDate: m.startDate, quantity: m.quantity })),
          dayEnd, 1,
        );
        return { computed: buckets[0], raw: mapped };
      }
      case "meditation": {
        const sessions = await HealthKit.queryCategorySamples(CTI.mindfulSession, {
          limit: 0,
          filter: dayFilter,
        });
        const mapped = [...sessions].map((s: any) => ({
          startDate: new Date(s.startDate).toISOString(),
          endDate: new Date(s.endDate).toISOString(),
        }));
        const buckets = aggregateMeditation(mapped as any, dayEnd, 1);
        return { computed: buckets[0], raw: mapped };
      }
    }
  }

  // Metrics that are infrequent or span overnight — query full 7-day range, not per-day
  const RANGE_QUERY_METRICS: MetricKey[] = ["weight", "sleep"];

  async function grabWeeklyRangeQuery(metric: MetricKey): Promise<DailyValue[] | HeartRateDaily[]> {
    const now = new Date();
    const todayKey = formatDateKey(now);
    const sevenDaysAgo = new Date(now.getTime() - (metric === "sleep" ? 8 : 7) * 24 * 60 * 60 * 1000);
    const dateFilter = { date: { startDate: sevenDaysAgo, endDate: now } };

    let results: DailyValue[];
    let rawSamples: any[];

    if (metric === "weight") {
      const samples = await HealthKit.queryQuantitySamples(QTI.bodyMass, {
        limit: 0,
        filter: dateFilter,
        unit: "kg",
      });
      rawSamples = samples.map((s: any) => ({
        startDate: new Date(s.startDate).toISOString(),
        quantity: s.quantity,
      }));
      results = pickLatestPerDay(
        rawSamples.map((m: any) => ({ startDate: m.startDate, quantity: m.quantity })),
        now,
      );
    } else {
      // sleep
      const samples = await HealthKit.queryCategorySamples(CTI.sleep, {
        limit: 0,
        filter: dateFilter,
      });
      rawSamples = [...samples].map((s: any) => ({
        startDate: new Date(s.startDate).toISOString(),
        endDate: new Date(s.endDate).toISOString(),
        value: s.value,
      }));
      results = aggregateSleep(rawSamples as any, now);
    }

    // Cache past days
    if (db) {
      for (const bucket of results) {
        if (bucket.date !== todayKey) {
          await putComputedCached(db, metric, bucket.date, bucket);
          // Store raw samples that fall on this day
          const dayRaw = rawSamples.filter((s: any) => {
            const sDate = formatDateKey(new Date(s.startDate));
            return sDate === bucket.date;
          });
          if (dayRaw.length > 0) {
            await putRawCached(db, metric, bucket.date, dayRaw);
          }
        }
      }
    }
    return results;
  }

  async function grabWeeklyData(metric: MetricKey): Promise<DailyValue[] | HeartRateDaily[]> {
    // Range-query metrics: use full 7-day query (weight is infrequent, sleep spans overnight)
    if (RANGE_QUERY_METRICS.includes(metric)) {
      return grabWeeklyRangeQuery(metric);
    }

    const now = new Date();
    const todayKey = formatDateKey(now);
    const dateKeys = buildDateKeys(now, 7);

    // Check computed cache
    const cached = db
      ? await getComputedCachedBatch(db, metric, dateKeys)
      : new Map<string, any>();
    const { cachedDays, fetchDays } = partitionDays(todayKey, dateKeys, cached);

    // Fetch uncached days from HealthKit
    const freshResults = await Promise.all(
      fetchDays.map(async (dateKey) => {
        const result = await fetchDayFromHealthKit(metric, dateKey);
        // Cache past days (not today) — both raw and computed
        if (db && dateKey !== todayKey) {
          await putComputedCached(db, metric, dateKey, result.computed);
          await putRawCached(db, metric, dateKey, result.raw);
        }
        return { dateKey, computed: result.computed };
      }),
    );

    // Merge cached + fresh, ordered by dateKeys
    const merged = new Map<string, any>(cachedDays);
    for (const { dateKey, computed } of freshResults) {
      merged.set(dateKey, computed);
    }
    return dateKeys.map((key) => merged.get(key) ?? { date: key, value: null });
  }

  function computeStatsForMetric(key: MetricKey, data: DailyValue[] | HeartRateDaily[]): BoxPlotStats | null {
    if ("avg" in (data[0] ?? {})) {
      // HeartRateDaily: use avg values
      const vals = (data as HeartRateDaily[])
        .filter((d) => d.avg !== null)
        .map((d) => d.avg as number);
      return computeBoxPlotStats(vals);
    }
    return computeBoxPlotStats(extractValues(data as DailyValue[]));
  }

  async function handleMetricPress(key: MetricKey) {
    setSelectedMetric(key);
    setWeeklyError(null);
    if (weeklyCache[key]) return;
    setWeeklyLoading(true);
    try {
      const data = await grabWeeklyData(key);
      setWeeklyCache((prev) => ({ ...prev, [key]: data }));
      setStatsCache((prev) => ({ ...prev, [key]: computeStatsForMetric(key, data) }));
    } catch (e: any) {
      setWeeklyError(e.message ?? "Failed to load weekly data");
    } finally {
      setWeeklyLoading(false);
    }
  }

  async function grabContext() {
    setLoading(true);
    setError(null);
    setWeeklyCache({});
    setStatsCache({});
    setWeeklyError(null);
    try {
      await HealthKit.requestAuthorization({
        toRead: [
          QTI.stepCount,
          QTI.heartRate,
          QTI.activeEnergy,
          QTI.distance,
          QTI.bodyMass,
          QTI.hrv,
          QTI.restingHeartRate,
          QTI.exerciseTime,
          CTI.sleep,
          CTI.mindfulSession,
        ],
      });

      const [health, location] = await Promise.all([
        grabHealthData(),
        grabLocation(),
      ]);

      // Fetch location history from SQLite
      let locationHistory: LocationHistoryItem[] = [];
      if (db) {
        try {
          locationHistory = await getLocationHistory(db);
          setLocationCount(locationHistory.length);
          const storageBytes = await getLocationStorageBytes(db);
          setLocationStorageBytes(storageBytes);
        } catch (e) {
          console.error("Failed to fetch location history:", e);
        }
      }

      const result: ContextSnapshot = {
        timestamp: new Date().toISOString(),
        health,
        location,
        locationHistory,
      };
      setSnapshot(result);
    } catch (e: any) {
      setError(e.message ?? "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  async function shareSnapshot() {
    if (!snapshot) return;
    setSharing(true);
    try {
      setShareStatus("Fetching health data...");
      const metricKeys: MetricKey[] = [
        "steps", "heartRate", "sleep", "activeEnergy", "walkingDistance",
        "weight", "meditation", "hrv", "restingHeartRate", "exerciseMinutes",
      ];
      const allMetrics = await Promise.all(
        metricKeys.map((key) => weeklyCache[key] ? Promise.resolve(weeklyCache[key]!) : grabWeeklyData(key)),
      );
      const weeklyData: WeeklyDataMap = {
        steps: allMetrics[0] as DailyValue[],
        heartRate: allMetrics[1] as HeartRateDaily[],
        sleep: allMetrics[2] as DailyValue[],
        activeEnergy: allMetrics[3] as DailyValue[],
        walkingDistance: allMetrics[4] as DailyValue[],
        weight: allMetrics[5] as DailyValue[],
        meditation: allMetrics[6] as DailyValue[],
        hrv: allMetrics[7] as HeartRateDaily[],
        restingHeartRate: allMetrics[8] as HeartRateDaily[],
        exerciseMinutes: allMetrics[9] as DailyValue[],
      };
      // Compute and cache stats for all metrics during share
      const newStats: Partial<Record<MetricKey, BoxPlotStats | null>> = {};
      metricKeys.forEach((key, i) => {
        newStats[key] = computeStatsForMetric(key, allMetrics[i]);
      });
      setStatsCache((prev) => ({ ...prev, ...newStats }));
      let locationSummary: LocationSummary | null = null;
      if (snapshot.locationHistory.length > 0) {
        setShareStatus(`Clustering ${snapshot.locationHistory.length} locations...`);
        // Yield to UI before heavy computation
        await new Promise((r) => setTimeout(r, 0));
        const { clusters, timeline, summary } = clusterLocations(snapshot.locationHistory, 50, 3, knownPlaces);
        locationSummary = { clusters, timeline, summary };
      }
      setShareStatus("Sharing...");
      const summaryExport = buildSummaryExport(weeklyData, locationSummary);
      const json = JSON.stringify(summaryExport, null, 2);
      await Share.share({
        message: json,
        title: "Context Grabber - 7 Day Summary",
      });
    } catch (e: any) {
      setError(e.message ?? "Failed to build share data");
    } finally {
      setSharing(false);
      setShareStatus("");
    }
  }

  async function shareRaw() {
    if (!snapshot) return;
    // Cluster location history instead of sharing raw points
    let locationClusters: LocationSummary | null = null;
    if (snapshot.locationHistory.length > 0) {
      const { clusters, timeline, summary } = clusterLocations(snapshot.locationHistory, 50, 3, knownPlaces);
      locationClusters = { clusters, timeline, summary };
    }
    const rawExport = {
      timestamp: snapshot.timestamp,
      health: snapshot.health,
      location: snapshot.location,
      locationClusters,
    };
    const json = JSON.stringify(rawExport, null, 2);
    await Share.share({
      message: json,
      title: "Context Grabber - Raw Data",
    });
  }

  const summaryText = snapshot
    ? buildSummary(snapshot.health, locationCount)
    : "";

  const h = snapshot?.health;

  const metrics: MetricCardProps[] = snapshot
    ? [
        {
          metricKey: "steps" as MetricKey,
          label: "Steps",
          value: h?.steps != null ? formatNumber(h.steps) : "\u2014",
          sublabel: "today",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.steps,
          color: METRIC_CONFIG.steps.color,
        },
        {
          metricKey: "heartRate" as MetricKey,
          label: "Heart Rate",
          value: h?.heartRate != null ? `${h.heartRate} bpm` : "\u2014",
          sublabel: "latest",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.heartRate,
          color: METRIC_CONFIG.heartRate.color,
        },
        {
          metricKey: "sleep" as MetricKey,
          label: "Sleep",
          value: h?.sleepHours != null ? `${h.sleepHours} hrs` : "\u2014",
          sublabel:
            h?.bedtime && h?.wakeTime
              ? `${h.bedtime} \u2013 ${h.wakeTime}`
              : "last night",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.sleep,
          color: METRIC_CONFIG.sleep.color,
        },
        {
          metricKey: "activeEnergy" as MetricKey,
          label: "Active Energy",
          value: h?.activeEnergy != null ? `${formatNumber(h.activeEnergy)} kcal` : "\u2014",
          sublabel: "today",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.activeEnergy,
          color: METRIC_CONFIG.activeEnergy.color,
        },
        {
          metricKey: "walkingDistance" as MetricKey,
          label: "Walking Distance",
          value: h?.walkingDistance != null ? `${h.walkingDistance} km` : "\u2014",
          sublabel: "today",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.walkingDistance,
          color: METRIC_CONFIG.walkingDistance.color,
        },
        {
          metricKey: "weight" as MetricKey,
          label: "Weight",
          value: h?.weight != null ? `${h.weight} kg (${Math.round(h.weight * 2.20462)} lbs)` : "\u2014",
          sublabel:
            h?.weightDaysLast7 != null
              ? `${h.weightDaysLast7}/7 days weighed`
              : "latest",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.weight,
          color: METRIC_CONFIG.weight.color,
        },
        {
          metricKey: "meditation" as MetricKey,
          label: "Meditation",
          value: h?.meditationMinutes != null ? `${h.meditationMinutes} min` : "\u2014",
          sublabel: "today",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.meditation,
          color: METRIC_CONFIG.meditation.color,
        },
        {
          metricKey: "hrv" as MetricKey,
          label: "HRV",
          value: h?.hrv != null ? `${h.hrv} ms` : "\u2014",
          sublabel: "latest",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.hrv,
          color: METRIC_CONFIG.hrv.color,
        },
        {
          metricKey: "restingHeartRate" as MetricKey,
          label: "Resting HR",
          value: h?.restingHeartRate != null ? `${h.restingHeartRate} bpm` : "\u2014",
          sublabel: "latest",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.restingHeartRate,
          color: METRIC_CONFIG.restingHeartRate.color,
        },
        {
          metricKey: "exerciseMinutes" as MetricKey,
          label: "Exercise",
          value: h?.exerciseMinutes != null ? `${h.exerciseMinutes} min` : "\u2014",
          sublabel: "today",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.exerciseMinutes,
          color: METRIC_CONFIG.exerciseMinutes.color,
        },
      ]
    : [];

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <View style={styles.headerText}>
            <Text style={styles.title}>Context Grabber</Text>
            <Text style={styles.subtitle}>
              Grab your iPhone context for your AI life coach
            </Text>
          </View>
          <View style={styles.headerButtons}>
            <TouchableOpacity
              style={[styles.headerIconButton, loading && { opacity: 0.5 }]}
              onPress={grabContext}
              disabled={loading}
              accessibilityLabel="Refresh"
            >
              <Text style={styles.headerIconText}>{"\u21BB"}</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.headerIconButton}
              onPress={() => setSettingsVisible(true)}
              accessibilityLabel="Settings"
            >
              <Text style={styles.headerIconText}>{"\u2699"}</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={styles.headerIconButton}
              onPress={() => setAboutVisible(true)}
              accessibilityLabel="About"
              testID="about-button"
            >
              <Text style={[styles.headerIconText, { fontStyle: "italic" }]}>i</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>

      <AboutModal
        visible={aboutVisible}
        onClose={() => setAboutVisible(false)}
      />

      <Modal
        visible={settingsVisible}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setSettingsVisible(false)}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Settings</Text>
            <TouchableOpacity onPress={() => setSettingsVisible(false)} style={styles.modalCloseButton}>
              <Text style={styles.modalCloseText}>Done</Text>
            </TouchableOpacity>
          </View>
          <ScrollView style={styles.modalContent} keyboardDismissMode="on-drag" keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingBottom: 300 }}>
            <View style={styles.aboutCard}>
              <TouchableOpacity onPress={() => setTrackingExpanded(!trackingExpanded)} style={styles.settingRow}>
                <Text style={styles.metricLabel}>Location Tracking</Text>
                <Text style={{ color: "#888", fontSize: 16 }}>{trackingExpanded ? "\u25B2" : "\u25BC"}</Text>
              </TouchableOpacity>
              {trackingExpanded && (
                <>
                  <View style={styles.settingRow}>
                    <Text style={styles.settingText}>Background Tracking</Text>
                    <Switch
                      value={trackingEnabled}
                      onValueChange={handleTrackingToggle}
                      trackColor={{ false: "#555", true: "#4361ee" }}
                      thumbColor="#fff"
                    />
                  </View>
                  <View style={styles.settingRow}>
                    <Text style={styles.settingText}>Retention (days)</Text>
                    <TextInput
                      style={styles.retentionInput}
                      value={retentionDays}
                      onChangeText={handleRetentionChange}
                      keyboardType="number-pad"
                      maxLength={4}
                      selectTextOnFocus
                    />
                  </View>
                  <Text style={styles.locationCountText}>
                    {locationCount} location{locationCount !== 1 ? "s" : ""} tracked
                    {locationStorageBytes > 0
                      ? ` (${locationStorageBytes > 1024 * 1024
                          ? `${(locationStorageBytes / (1024 * 1024)).toFixed(1)} MB`
                          : locationStorageBytes > 1024
                            ? `${(locationStorageBytes / 1024).toFixed(1)} KB`
                            : `${locationStorageBytes} B`})`
                      : ""}
                  </Text>
                </>
              )}
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

            <View style={styles.aboutCard}>
              <TouchableOpacity onPress={() => setDebugExpanded(!debugExpanded)} style={styles.settingRow}>
                <Text style={styles.metricLabel}>Debug: Raw Sleep Data</Text>
                <Text style={{ color: "#888", fontSize: 16 }}>{debugExpanded ? "\u25B2" : "\u25BC"}</Text>
              </TouchableOpacity>
              {debugExpanded && (
                <>
                  <Text style={styles.locationCountText}>
                    Last 2 days of raw HealthKit sleep samples with source info
                  </Text>
                  <TouchableOpacity
                    style={[styles.addPlaceButton, { marginTop: 8 }]}
                    onPress={handleFetchDebugSleep}
                  >
                    <Text style={styles.addPlaceButtonText}>Fetch Raw Sleep</Text>
                  </TouchableOpacity>
                  {debugSleepData && debugSleepData !== "Loading..." && (
                    <TouchableOpacity
                      style={[styles.addPlaceButton, { marginTop: 8, backgroundColor: "#3d405b" }]}
                      onPress={() => Share.share({ message: debugSleepData })}
                    >
                      <Text style={styles.addPlaceButtonText}>Copy / Share</Text>
                    </TouchableOpacity>
                  )}
                  {debugSleepData && (
                    <ScrollView style={{ maxHeight: 400, marginTop: 8 }} nestedScrollEnabled>
                      <Text style={{ color: "#ccc", fontSize: 11, fontFamily: "Courier" }}>
                        {debugSleepData}
                      </Text>
                    </ScrollView>
                  )}
                </>
              )}
            </View>
          </ScrollView>
        </View>
      </Modal>

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
      >
        {error && (
          <View style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {snapshot && (
          <>
            {summaryText.length > 0 && (
              <View style={styles.summaryBanner}>
                <Text style={styles.summaryText}>{summaryText}</Text>
              </View>
            )}

            <View style={styles.metricGrid}>
              {metrics.map((m, i) => (
                <MetricCard
                  key={m.label}
                  metricKey={m.metricKey}
                  label={m.label}
                  value={m.value}
                  sublabel={m.sublabel}
                  fullWidth={metrics.length % 2 === 1 && i === metrics.length - 1}
                  onPress={handleMetricPress}
                  boxPlotStats={m.boxPlotStats}
                  color={m.color}
                />
              ))}
            </View>

            <View style={styles.locationCard}>
              <Text style={styles.metricLabel}>Location</Text>
              {snapshot.location ? (
                <Text style={styles.metricValue}>
                  {snapshot.location.latitude.toFixed(4)},{" "}
                  {snapshot.location.longitude.toFixed(4)}
                </Text>
              ) : (
                <Text style={[styles.metricValue, styles.metricValueNull]}>
                  Unavailable
                </Text>
              )}
              {snapshot.locationHistory.length > 0 && (
                <Text style={styles.locationCountText}>
                  {snapshot.locationHistory.length} point
                  {snapshot.locationHistory.length !== 1 ? "s" : ""} in trail
                </Text>
              )}
            </View>

            <Text style={styles.timestamp}>{snapshot.timestamp}</Text>
          </>
        )}
      </ScrollView>

      {snapshot && (
        <View style={styles.buttons}>
          <View style={styles.shareRow}>
            <TouchableOpacity
              style={[styles.button, styles.shareButton, styles.shareButtonHalf]}
              onPress={shareSnapshot}
              disabled={sharing}
            >
              <Text style={styles.buttonText}>
                {sharing ? (shareStatus || "Preparing...") : "\u2197 Summary"}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.button, styles.rawButton, styles.shareButtonHalf]}
              onPress={shareRaw}
            >
              <Text style={styles.buttonText}>{"\u2197"} Raw</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
      {selectedMetric && (
        <MetricDetailSheet
          metricKey={selectedMetric}
          currentValue={
            metrics.find((m) => m.metricKey === selectedMetric)?.value ?? "\u2014"
          }
          currentSublabel={
            metrics.find((m) => m.metricKey === selectedMetric)?.sublabel ?? ""
          }
          data={weeklyCache[selectedMetric] ?? null}
          error={weeklyError}
          onClose={() => {
            setSelectedMetric(null);
            setWeeklyError(null);
          }}
          sleepBySource={selectedMetric === "sleep" ? snapshot?.health.sleepBySource : undefined}
          fetchRawCache={db ? async () => {
            const dateKeys = buildDateKeys(new Date(), 7);
            const raw = await getRawCachedBatch(db, selectedMetric, dateKeys);
            if (raw.size === 0) return "No raw cache entries found";
            const result: Record<string, any> = {};
            for (const key of dateKeys) {
              result[key] = raw.get(key) ?? null;
            }
            return JSON.stringify(result, null, 2);
          } : undefined}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#1a1a2e",
  },
  header: {
    paddingTop: 60,
    paddingHorizontal: 20,
    paddingBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: "bold",
    color: "#e0e0e0",
  },
  subtitle: {
    fontSize: 14,
    color: "#888",
    marginTop: 4,
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
  },
  contentInner: {
    paddingBottom: 20,
  },
  summaryBanner: {
    backgroundColor: "#0f3460",
    borderRadius: 10,
    padding: 12,
    marginTop: 12,
  },
  summaryText: {
    color: "#ccc",
    fontSize: 13,
    textAlign: "center",
  },
  metricGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-between",
    marginTop: 12,
  },
  metricCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    width: "48%",
    marginBottom: 10,
  },
  metricCardFull: {
    width: "100%",
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
  locationCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 2,
  },
  settingsCard: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 12,
  },
  settingRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 8,
  },
  settingText: {
    fontSize: 16,
    color: "#ccc",
  },
  retentionInput: {
    backgroundColor: "#1a1a2e",
    color: "#fff",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    fontSize: 16,
    width: 60,
    textAlign: "center",
    borderWidth: 1,
    borderColor: "#333",
  },
  locationCountText: {
    fontSize: 13,
    color: "#888",
    marginTop: 4,
  },
  timestamp: {
    fontSize: 12,
    color: "#666",
    marginTop: 12,
    textAlign: "right",
  },
  errorBox: {
    backgroundColor: "#3d1f1f",
    borderRadius: 8,
    padding: 12,
    marginTop: 12,
  },
  errorText: {
    color: "#ff6b6b",
    fontSize: 14,
  },
  buttons: {
    paddingHorizontal: 20,
    paddingBottom: Platform.OS === "ios" ? 40 : 20,
    gap: 10,
  },
  button: {
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  shareButton: {
    backgroundColor: "#2d6a4f",
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  headerRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  headerText: {
    flex: 1,
  },
  headerButtons: {
    flexDirection: "row",
    gap: 8,
    alignItems: "center",
    marginTop: 4,
  },
  headerIconButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "#16213e",
    justifyContent: "center",
    alignItems: "center",
  },
  headerIconText: {
    color: "#4cc9f0",
    fontSize: 16,
    fontWeight: "700",
  },
  shareRow: {
    flexDirection: "row",
    gap: 10,
  },
  shareButtonHalf: {
    flex: 1,
  },
  rawButton: {
    backgroundColor: "#3d405b",
  },
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
  aboutAppName: {
    fontSize: 22,
    fontWeight: "bold",
    color: "#e0e0e0",
    marginBottom: 4,
  },
  aboutTagline: {
    fontSize: 14,
    color: "#888",
  },
  aboutRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: "#1a1a2e",
  },
  aboutRowLabel: {
    fontSize: 14,
    color: "#888",
  },
  aboutRowValue: {
    fontSize: 14,
    color: "#e0e0e0",
  },
  aboutLink: {
    color: "#4361ee",
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
