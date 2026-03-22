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
import * as Updates from "expo-updates";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import { buildHealthData, type HealthData, type HealthQueryResults } from "./lib/health";
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
} from "./lib/weekly";
import { buildSummaryExport, type WeeklyDataMap, type LocationSummary } from "./lib/share";
import { clusterLocations } from "./lib/clustering";
import { computeBoxPlotStats, extractValues, type BoxPlotStats } from "./lib/stats";
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

async function getLocationStorageBytes(db: SQLite.SQLiteDatabase): Promise<number> {
  const row = await db.getFirstAsync<{ size: number }>(
    "SELECT SUM(LENGTH(latitude) + LENGTH(longitude) + LENGTH(accuracy) + LENGTH(timestamp) + 20) as size FROM locations",
  );
  return row?.size ?? 0;
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

  async function grabWeeklyData(metric: MetricKey): Promise<DailyValue[] | HeartRateDaily[]> {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const dateFilter = { date: { startDate: sevenDaysAgo, endDate: now } };

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
        const dayPromises = Array.from({ length: 7 }, (_, idx) => {
          const i = 6 - idx;
          const dayStart = new Date(now);
          dayStart.setDate(dayStart.getDate() - i);
          dayStart.setHours(0, 0, 0, 0);
          const dayEnd = new Date(dayStart);
          dayEnd.setHours(23, 59, 59, 999);
          const dateKey = `${dayStart.getFullYear()}-${String(dayStart.getMonth() + 1).padStart(2, "0")}-${String(dayStart.getDate()).padStart(2, "0")}`;
          return HealthKit.queryStatisticsForQuantity(
            identifier,
            ["cumulativeSum"],
            { filter: { date: { startDate: dayStart, endDate: dayEnd } } },
          )
            .then((result) => ({
              date: dateKey,
              value: result?.sumQuantity?.quantity != null
                ? Math.round(result.sumQuantity.quantity * 100) / 100
                : null,
            }))
            .catch(() => ({ date: dateKey, value: null }));
        });
        return Promise.all(dayPromises);
      }
      case "heartRate": {
        const samples = await HealthKit.queryQuantitySamples(QTI.heartRate, {
          limit: 0,
          filter: dateFilter,
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate),
          quantity: s.quantity,
        }));
        return aggregateHeartRate(mapped, now);
      }
      case "sleep": {
        // Query 8 days back to capture overnight sessions starting before the 7-day window
        const eightDaysAgo = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000);
        const samples = await HealthKit.queryCategorySamples(CTI.sleep, {
          limit: 0,
          filter: { date: { startDate: eightDaysAgo, endDate: now } },
        });
        return aggregateSleep([...samples], now);
      }
      case "weight": {
        const samples = await HealthKit.queryQuantitySamples(QTI.bodyMass, {
          limit: 0,
          filter: dateFilter,
          unit: "kg",
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate),
          quantity: s.quantity,
        }));
        return pickLatestPerDay(mapped, now);
      }
      case "meditation": {
        const sessions = await HealthKit.queryCategorySamples(CTI.mindfulSession, {
          limit: 0,
          filter: dateFilter,
        });
        return aggregateMeditation([...sessions], now);
      }
      case "hrv": {
        const samples = await HealthKit.queryQuantitySamples(QTI.hrv, {
          limit: 0,
          filter: dateFilter,
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate),
          quantity: s.quantity,
        }));
        return pickLatestPerDay(mapped, now);
      }
      case "restingHeartRate": {
        const samples = await HealthKit.queryQuantitySamples(QTI.restingHeartRate, {
          limit: 0,
          filter: dateFilter,
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate),
          quantity: s.quantity,
        }));
        return pickLatestPerDay(mapped, now);
      }
    }
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
        hrv: allMetrics[7] as DailyValue[],
        restingHeartRate: allMetrics[8] as DailyValue[],
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
        const { clusters, timeline, summary } = clusterLocations(snapshot.locationHistory);
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
      const { clusters, timeline, summary } = clusterLocations(snapshot.locationHistory);
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
          value: h?.weight != null ? `${h.weight} kg` : "\u2014",
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
          <ScrollView style={styles.modalContent}>
            <View style={styles.aboutCard}>
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
                {locationStorageBytes > 0
                  ? ` (${locationStorageBytes > 1024 * 1024
                      ? `${(locationStorageBytes / (1024 * 1024)).toFixed(1)} MB`
                      : locationStorageBytes > 1024
                        ? `${(locationStorageBytes / 1024).toFixed(1)} KB`
                        : `${locationStorageBytes} B`})`
                  : ""}
              </Text>
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
});
