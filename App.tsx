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
  Pressable,
} from "react-native";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as SQLite from "expo-sqlite";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import { buildHealthData, type HealthData, type HealthQueryResults } from "./lib/health";
import { pruneThreshold } from "./lib/location";
import { buildSummary, formatNumber } from "./lib/summary";
import { getBuildInfo, formatBuildTimestamp } from "./lib/version";

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
    INSERT OR IGNORE INTO settings (key, value) VALUES ('schema_version', '1');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('tracking_enabled', 'false');
    INSERT OR IGNORE INTO settings (key, value) VALUES ('retention_days', '30');
  `);
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
  label: string;
  value: string;
  sublabel: string;
  fullWidth?: boolean;
};

function MetricCard({ label, value, sublabel, fullWidth }: MetricCardProps) {
  const isNull = value === "\u2014";
  return (
    <View style={[styles.metricCard, fullWidth && styles.metricCardFull]}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={[styles.metricValue, isNull && styles.metricValueNull]}>
        {value}
      </Text>
      <Text style={styles.metricSublabel}>{sublabel}</Text>
    </View>
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

        // Prune on startup
        await pruneLocations(database, parseInt(days, 10) || 30);
        const countAfterPrune = await getLocationCount(database);
        setLocationCount(countAfterPrune);
      } catch (e: any) {
        console.error("DB init error:", e);
        setError("Database unavailable. Location tracking and history won't work.");
      }
    })();
  }, []);

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

  async function grabHealthData(): Promise<HealthData> {
    const now = new Date();
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const dateFilter = {
      date: { startDate: startOfDay, endDate: now },
    };
    const sleepDateFilter = {
      date: { startDate: yesterday, endDate: now },
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
      HealthKit.getMostRecentQuantitySample(QTI.bodyMass),
      HealthKit.queryCategorySamples(CTI.mindfulSession, {
        limit: 0,
        filter: dateFilter,
      }),
      HealthKit.queryQuantitySamples(QTI.bodyMass, {
        limit: 0,
        filter: weightWeekFilter,
      }),
    ]);

    return buildHealthData(results as HealthQueryResults);
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

  async function grabContext() {
    setLoading(true);
    setError(null);
    try {
      await HealthKit.requestAuthorization({
        toRead: [
          QTI.stepCount,
          QTI.heartRate,
          QTI.activeEnergy,
          QTI.distance,
          QTI.bodyMass,
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
    const json = JSON.stringify(snapshot, null, 2);
    await Share.share({
      message: json,
      title: "Context Grabber Snapshot",
    });
  }

  const summaryText = snapshot
    ? buildSummary(snapshot.health, locationCount)
    : "";

  const h = snapshot?.health;

  const metrics: MetricCardProps[] = snapshot
    ? [
        {
          label: "Steps",
          value: h?.steps != null ? formatNumber(h.steps) : "\u2014",
          sublabel: "today",
        },
        {
          label: "Heart Rate",
          value: h?.heartRate != null ? `${h.heartRate} bpm` : "\u2014",
          sublabel: "latest",
        },
        {
          label: "Sleep",
          value: h?.sleepHours != null ? `${h.sleepHours} hrs` : "\u2014",
          sublabel:
            h?.bedtime && h?.wakeTime
              ? `${h.bedtime} \u2013 ${h.wakeTime}`
              : "last night",
        },
        {
          label: "Active Energy",
          value: h?.activeEnergy != null ? `${formatNumber(h.activeEnergy)} kcal` : "\u2014",
          sublabel: "today",
        },
        {
          label: "Walking Distance",
          value: h?.walkingDistance != null ? `${h.walkingDistance} km` : "\u2014",
          sublabel: "today",
        },
        {
          label: "Weight",
          value: h?.weight != null ? `${h.weight} kg` : "\u2014",
          sublabel:
            h?.weightDaysLast7 != null
              ? `${h.weightDaysLast7}/7 days weighed`
              : "latest",
        },
        {
          label: "Meditation",
          value: h?.meditationMinutes != null ? `${h.meditationMinutes} min` : "\u2014",
          sublabel: "today",
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
          <TouchableOpacity
            style={styles.aboutButton}
            onPress={() => setAboutVisible(true)}
            accessibilityLabel="About"
          >
            <Text style={styles.aboutButtonText}>i</Text>
          </TouchableOpacity>
        </View>
      </View>

      <AboutModal
        visible={aboutVisible}
        onClose={() => setAboutVisible(false)}
      />

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
      >
        {error && (
          <View style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {/* Tracking Settings */}
        <View style={styles.settingsCard}>
          <Text style={styles.metricLabel}>Location Tracking</Text>
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
          </Text>
        </View>

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
                  label={m.label}
                  value={m.value}
                  sublabel={m.sublabel}
                  fullWidth={
                    metrics.length % 2 === 1 && i === metrics.length - 1
                  }
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

      <View style={styles.buttons}>
        <TouchableOpacity
          style={[styles.button, styles.grabButton]}
          onPress={grabContext}
          disabled={loading}
        >
          <Text style={styles.buttonText}>
            {loading ? "Grabbing..." : "Grab Context"}
          </Text>
        </TouchableOpacity>

        {snapshot && (
          <TouchableOpacity
            style={[styles.button, styles.shareButton]}
            onPress={shareSnapshot}
          >
            <Text style={styles.buttonText}>Share JSON</Text>
          </TouchableOpacity>
        )}
      </View>
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
  grabButton: {
    backgroundColor: "#4361ee",
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
  aboutButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "#16213e",
    justifyContent: "center",
    alignItems: "center",
    marginTop: 4,
  },
  aboutButtonText: {
    color: "#4cc9f0",
    fontSize: 16,
    fontWeight: "700",
    fontStyle: "italic",
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
});
