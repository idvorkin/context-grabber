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
  Alert,
  Modal,
  Linking,

} from "react-native";
import * as Location from "expo-location";
import * as TaskManager from "expo-task-manager";
import * as SQLite from "expo-sqlite";
import * as Updates from "expo-updates";
import * as Clipboard from "expo-clipboard";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import { buildHealthData, workoutActivityName, type HealthData, type HealthQueryResults, type SleepSample, type WorkoutEntry } from "./lib/health";
import {
  DB_NAME, openDB, initDB, getSetting, setSetting,
  insertLocation, pruneLocations, getLocationCount, getLocationStorageBytes,
  getKnownPlaces, addKnownPlace, deleteKnownPlace, getLocationHistory,
  getSleepTarget, setSleepTarget,
  type LocationHistoryItem,
} from "./lib/db";
import {
  buildSleepDetailedBundle,
  type SleepDetailedBundle,
} from "./lib/sleep";
import { buildActivityTimeline, type ActivityTimeline } from "./lib/activity";
import { buildSummary, formatNumber, formatLocalTime } from "./lib/summary";
import { getBuildInfo, formatBuildTimestamp } from "./lib/version";
import {
  type MetricKey,
  type DailyValue,
  type HeartRateDaily,
  METRIC_CONFIG,
  buildMovementOverlay,
  type MovementOverlayData,
  aggregateHeartRate,
  aggregateSleep,
  aggregateMeditation,
  pickLatestPerDay,
  formatDateKey,
} from "./lib/weekly";
import { buildSummaryExport, type WeeklyDataMap, type LocationSummary, type PlacesSummary } from "./lib/share";
import { parseDeepLink } from "./lib/deepLink";
import { writeWidgetSnapshot } from "./lib/widgetSnapshot";
import { getCounter, incrementCounter, resetCounter } from "./lib/counter";
import TallyCounter from "./components/TallyCounter";
import { clusterLocations, clusterLocationsV2 } from "./lib/clustering_v2";
import { type KnownPlace } from "./lib/places";
import { computeBoxPlotStats, extractValues, type BoxPlotStats } from "./lib/stats";
import {
  getComputedCachedBatch,
  getRawCachedBatch,
  putComputedCached,
  putRawCached,
  buildDateKeys,
  partitionDays,
} from "./lib/healthCache";
import MetricDetailSheet from "./components/MetricDetailSheet";
import BoxPlot from "./components/BoxPlot";
import SettingsModal from "./components/SettingsModal";
import LocationDetailSheet from "./components/LocationDetailSheet";
import GymTimerScreen from "./components/GymTimerScreen";

// --- Constants ---

const LOCATION_TASK_NAME = "background-location-task";

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
  /** Multi-box-plot mode: used by composite metrics (Movement) to stack mini
   *  box plots for each underlying series. When present, overrides
   *  boxPlotStats and renders the sublabel above the stack. */
  boxPlotStatsList?: Array<{ stats: BoxPlotStats; color: string }>;
};

function MetricCard({
  metricKey,
  label,
  value,
  sublabel,
  fullWidth,
  onPress,
  boxPlotStats,
  color,
  boxPlotStatsList,
}: MetricCardProps) {
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
      {boxPlotStatsList && boxPlotStatsList.length > 0 ? (
        <>
          <Text style={styles.metricSublabel}>{sublabel}</Text>
          <View style={{ marginTop: 4 }}>
            {boxPlotStatsList.map((item, i) => (
              <BoxPlot key={i} stats={item.stats} color={item.color} compact />
            ))}
          </View>
        </>
      ) : boxPlotStats && color ? (
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
  const updateCreatedAt = Updates.createdAt;
  const commitMessage = buildInfo.commitMessage;
  const [updateStatus, setUpdateStatus] = useState<string | null>(null);

  async function handleCheckForUpdate() {
    try {
      setUpdateStatus("Checking...");
      const check = await Updates.checkForUpdateAsync();
      if (!check.isAvailable) {
        setUpdateStatus(`Up to date (${updateId.slice(-4)})`);
        return;
      }
      setUpdateStatus("Downloading update...");
      const result = await Updates.fetchUpdateAsync();
      if (result.isNew) {
        setUpdateStatus("Reloading with new update...");
        await Updates.reloadAsync();
      } else {
        setUpdateStatus(`No new update (${updateId.slice(-4)})`);
      }
    } catch (e: any) {
      setUpdateStatus(`Error: ${e.message ?? "Update failed"}`);
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
              <Text style={styles.aboutRowValue}>
                {updateId === "embedded" ? "embedded" : `...${updateId.slice(-8)}`}
                {updateCreatedAt ? ` · ${updateCreatedAt.toLocaleDateString()}` : ""}
              </Text>
            </View>
            {commitMessage && (
              <Text style={{ color: "#ccc", fontSize: 12, marginTop: 4 }}>
                {commitMessage}
              </Text>
            )}

            <TouchableOpacity
              style={[styles.addPlaceButton, { marginTop: 8 }]}
              onPress={handleCheckForUpdate}
            >
              <Text style={styles.addPlaceButtonText}>
                {updateStatus ?? "Check for Updates"}
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
  const [sleepDetailedCache, setSleepDetailedCache] = useState<SleepDetailedBundle | null>(null);
  const [sleepTargetHours, setSleepTargetHoursState] = useState<number>(8);
  const [weeklyLoading, setWeeklyLoading] = useState(false);
  const [weeklyError, setWeeklyError] = useState<string | null>(null);
  const [statsCache, setStatsCache] = useState<Partial<Record<MetricKey, BoxPlotStats | null>>>({});
  const [workoutsByDay, setWorkoutsByDay] = useState<Record<string, WorkoutEntry[]>>({});
  const [activityTimelineByDay, setActivityTimelineByDay] = useState<Record<string, ActivityTimeline>>({});
  const [locationStorageBytes, setLocationStorageBytes] = useState(0);
  const [dbReady, setDbReady] = useState(false);
  const [sharing, setSharing] = useState(false);
  const [shareStatus, setShareStatus] = useState("");
  const [settingsVisible, setSettingsVisible] = useState(false);
  const [knownPlaces, setKnownPlaces] = useState<KnownPlace[]>([]);
  const [locationExpanded, setLocationExpanded] = useState(false);
  const [locationSummaryText, setLocationSummaryText] = useState<string | null>(null);
  const [locationCopied, setLocationCopied] = useState(false);
  const [gymTimerVisible, setGymTimerVisible] = useState(false);
  const [timerIntent, setTimerIntent] = useState<{
    mode: "rounds" | "stopwatch" | "sets";
    preset: string | null;
    autostart: boolean;
  } | null>(null);
  const [otaUpdateReady, setOtaUpdateReady] = useState(false);
  const [counterValue, setCounterValue] = useState(0);

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

        const target = await getSleepTarget(database);
        setSleepTargetHoursState(target);

        const count = await getLocationCount(database);
        setLocationCount(count);

        const places = await getKnownPlaces(database);
        setKnownPlaces(places);

        // Load counter (auto-resets if a new local day has begun).
        const counter = await getCounter(database);
        setCounterValue(counter.value);

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

  // Deep link routing. Keep a ref to grabContext so the handler always uses
  // the latest closure (grabContext reads live component state).
  const grabContextRef = useRef<(() => void) | null>(null);
  grabContextRef.current = () => { void grabContext(); };
  useEffect(() => {
    const handle = (url: string | null) => {
      const route = parseDeepLink(url);
      if (route.kind === "main") {
        setGymTimerVisible(false);
        if (route.autoGrab) grabContextRef.current?.();
      } else if (route.kind === "timer") {
        setTimerIntent({ mode: route.mode, preset: route.preset, autostart: route.autostart });
        setGymTimerVisible(true);
      }
      // kind === "unknown" → no-op (already on whatever screen)
    };
    void Linking.getInitialURL().then(handle);
    const sub = Linking.addEventListener("url", (ev) => handle(ev.url));
    return () => sub.remove();
  }, []);

  // Prune on app foreground + sync counter (daily reset + pull any +1's that
  // came from the widget while the app was backgrounded).
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
        try {
          const counter = await getCounter(db);
          setCounterValue(counter.value);
          void writeWidgetSnapshot({
            steps: snapshot?.health.steps ?? null,
            sleepHours: snapshot?.health.sleepHours ?? null,
            exerciseMinutes: snapshot?.health.exerciseMinutes ?? null,
            counter: counter.value,
          });
        } catch (e) {
          console.error("Counter sync on foreground error:", e);
        }
      }
    });
    return () => subscription.remove();
  }, [db, snapshot]);

  // Counter handlers — increment on tap, reset on the ↺ button.
  const handleCounterIncrement = useCallback(async () => {
    if (!db) return;
    try {
      const next = await incrementCounter(db);
      setCounterValue(next.value);
      void writeWidgetSnapshot({
        steps: snapshot?.health.steps ?? null,
        sleepHours: snapshot?.health.sleepHours ?? null,
        exerciseMinutes: snapshot?.health.exerciseMinutes ?? null,
        counter: next.value,
      });
    } catch (e) {
      console.error("Counter increment error:", e);
    }
  }, [db, snapshot]);

  const handleCounterReset = useCallback(() => {
    if (!db) return;
    Alert.alert(
      "Reset count to 0?",
      undefined,
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Reset",
          style: "destructive",
          onPress: async () => {
            try {
              const next = await resetCounter(db);
              setCounterValue(next.value);
              void writeWidgetSnapshot({
                steps: snapshot?.health.steps ?? null,
                sleepHours: snapshot?.health.sleepHours ?? null,
                exerciseMinutes: snapshot?.health.exerciseMinutes ?? null,
                counter: next.value,
              });
            } catch (e) {
              console.error("Counter reset error:", e);
            }
          },
        },
      ],
    );
  }, [db, snapshot]);

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

    const health = buildHealthData(healthResults);

    // Query today's workouts for rich activity data
    try {
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const workoutSamples = await HealthKit.queryWorkoutSamples({
        limit: 0,
        filter: { date: { startDate: startOfDay, endDate: now } },
      });
      health.workouts = workoutSamples.map((w: any) => {
        const json = w.toJSON ? w.toJSON() : w;
        return {
          activityType: workoutActivityName(json.workoutActivityType),
          durationMinutes: Math.round((json.duration?.quantity ?? 0) / 60),
          energyBurned: json.totalEnergyBurned?.quantity
            ? Math.round(json.totalEnergyBurned.quantity)
            : null,
          distanceKm: json.totalDistance?.quantity
            ? Math.round(json.totalDistance.quantity / 10) / 100
            : null,
          startTime: new Date(json.startDate).toISOString(),
          endTime: new Date(new Date(json.startDate).getTime() + (json.duration?.quantity ?? 0) * 1000).toISOString(),
        } as WorkoutEntry;
      });
    } catch {
      // Workout query failed — keep empty array
    }

    return health;
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
      case "walkingDistance": {
        const identifier =
          metric === "steps" ? QTI.stepCount
          : metric === "activeEnergy" ? QTI.activeEnergy
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
      case "exerciseMinutes": {
        const samples = await HealthKit.queryQuantitySamples(QTI.exerciseTime, {
          limit: 0,
          filter: dayFilter,
        });
        const mapped = samples.map((s: any) => ({
          startDate: new Date(s.startDate).toISOString(),
          endDate: s.endDate ? new Date(s.endDate).toISOString() : undefined,
          quantity: s.quantity,
          source: s.sourceRevision?.source?.name ?? "unknown",
        }));
        const totalMinutes = mapped.reduce((sum: number, s: any) => sum + (s.quantity ?? 0), 0);
        const value = totalMinutes > 0 ? Math.round(totalMinutes) : null;
        return {
          computed: { date: dateKey, value },
          raw: mapped,
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
      case "movement":
        // Composite metric — handled by fetching its three underlying series
        // (steps, walkingDistance, activeEnergy) in handleMetricPress.
        throw new Error("movement is a composite metric and cannot be fetched directly");
    }
  }

  // Metrics that are infrequent or span overnight — query full 7-day range, not per-day
  const RANGE_QUERY_METRICS: MetricKey[] = ["weight", "sleep"];

  function kgToLbs(data: DailyValue[]): DailyValue[] {
    return data.map(d => ({ ...d, value: d.value != null ? Math.round(d.value * 2.20462) : null }));
  }

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
        source: s.sourceName,
      }));
      results = aggregateSleep(rawSamples as any, now);
      // Also build the per-source detailed bundle (stages, bedtime, wake, samples)
      // for the sleep detail sheet. Tabs in the sheet select a source or "All".
      const bundle = buildSleepDetailedBundle(rawSamples as any, now);
      setSleepDetailedCache(bundle);
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
    if (metric === "weight") return kgToLbs(results);
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
    const result = dateKeys.map((key) => merged.get(key) ?? { date: key, value: null });
    if (metric === "weight") return kgToLbs(result as DailyValue[]);
    return result;
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

  async function fetchWorkoutsByDay(): Promise<Record<string, WorkoutEntry[]>> {
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    try {
      const samples = await HealthKit.queryWorkoutSamples({
        limit: 0,
        filter: { date: { startDate: sevenDaysAgo, endDate: now } },
      });
      const byDay: Record<string, WorkoutEntry[]> = {};
      for (const w of samples) {
        const json = (w as any).toJSON ? (w as any).toJSON() : w;
        const dayKey = formatDateKey(new Date(json.startDate));
        if (!byDay[dayKey]) byDay[dayKey] = [];
        byDay[dayKey].push({
          activityType: workoutActivityName(json.workoutActivityType),
          durationMinutes: Math.round((json.duration?.quantity ?? 0) / 60),
          energyBurned: json.totalEnergyBurned?.quantity ? Math.round(json.totalEnergyBurned.quantity) : null,
          distanceKm: json.totalDistance?.quantity ? Math.round(json.totalDistance.quantity / 10) / 100 : null,
          startTime: new Date(json.startDate).toISOString(),
          endTime: new Date(new Date(json.startDate).getTime() + (json.duration?.quantity ?? 0) * 1000).toISOString(),
        });
      }
      return byDay;
    } catch {
      return {};
    }
  }

  async function fetchActivityTimelines(): Promise<Record<string, ActivityTimeline>> {
    try {
      const now = new Date();
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const weekFilter = { date: { startDate: sevenDaysAgo, endDate: now } };
      const [exerciseSamples, hrSamples, workoutSamples] = await Promise.all([
        HealthKit.queryQuantitySamples(QTI.exerciseTime, { limit: 0, filter: weekFilter }),
        HealthKit.queryQuantitySamples(QTI.heartRate, { limit: 0, filter: weekFilter }),
        HealthKit.queryWorkoutSamples({ limit: 0, filter: weekFilter }),
      ]);
      // Bucket samples by day
      const exerciseByDay = new Map<string, any[]>();
      const hrByDay = new Map<string, any[]>();
      const workoutsByDayMap = new Map<string, WorkoutEntry[]>();

      for (const s of exerciseSamples as any[]) {
        const key = formatDateKey(new Date(s.startDate));
        if (!exerciseByDay.has(key)) exerciseByDay.set(key, []);
        exerciseByDay.get(key)!.push({
          startDate: new Date(s.startDate).toISOString(),
          endDate: s.endDate ? new Date(s.endDate).toISOString() : undefined,
          quantity: s.quantity ?? 0,
        });
      }
      for (const s of hrSamples as any[]) {
        const key = formatDateKey(new Date(s.startDate));
        if (!hrByDay.has(key)) hrByDay.set(key, []);
        hrByDay.get(key)!.push({
          startDate: new Date(s.startDate).toISOString(),
          quantity: s.quantity ?? 0,
        });
      }
      for (const w of workoutSamples as any[]) {
        const json = w.toJSON ? w.toJSON() : w;
        const key = formatDateKey(new Date(json.startDate));
        if (!workoutsByDayMap.has(key)) workoutsByDayMap.set(key, []);
        workoutsByDayMap.get(key)!.push({
          activityType: workoutActivityName(json.workoutActivityType),
          durationMinutes: Math.round((json.duration?.quantity ?? 0) / 60),
          energyBurned: json.totalEnergyBurned?.quantity ? Math.round(json.totalEnergyBurned.quantity) : null,
          distanceKm: json.totalDistance?.quantity ? Math.round(json.totalDistance.quantity / 10) / 100 : null,
          startTime: new Date(json.startDate).toISOString(),
          endTime: new Date(new Date(json.startDate).getTime() + (json.duration?.quantity ?? 0) * 1000).toISOString(),
        });
      }

      // Build timeline for each day that has data
      const result: Record<string, ActivityTimeline> = {};
      const allKeys = new Set([...exerciseByDay.keys(), ...hrByDay.keys(), ...workoutsByDayMap.keys()]);
      for (const key of allKeys) {
        const dayDate = new Date(key + "T12:00:00");
        result[key] = buildActivityTimeline(
          exerciseByDay.get(key) ?? [],
          hrByDay.get(key) ?? [],
          workoutsByDayMap.get(key) ?? [],
          dayDate,
        );
      }
      return result;
    } catch {
      return {};
    }
  }

  /**
   * Background prefetch of 7-day weekly data for every card. Runs after the
   * main grab so the UI renders immediately, then populates both weeklyCache
   * and statsCache so box plots appear on all cards without the user having
   * to tap each one. Past days hit the SQLite cache (lib/healthCache.ts)
   * so the cost after the first populate is just today's HealthKit queries.
   *
   * Non-fatal on error: cards just keep showing em-dashes until the user
   * taps them, which matches the pre-prefetch behavior.
   */
  async function prefetchAllWeeklyStats() {
    const keys: MetricKey[] = [
      "steps", "heartRate", "sleep", "activeEnergy", "walkingDistance",
      "weight", "meditation", "hrv", "restingHeartRate", "exerciseMinutes",
    ];
    try {
      const all = await Promise.all(keys.map((k) => grabWeeklyData(k)));
      const nextWeekly: Partial<Record<MetricKey, DailyValue[] | HeartRateDaily[]>> = {};
      const nextStats: Partial<Record<MetricKey, BoxPlotStats | null>> = {};
      keys.forEach((k, i) => {
        nextWeekly[k] = all[i];
        nextStats[k] = computeStatsForMetric(k, all[i]);
      });
      setWeeklyCache((prev) => ({ ...prev, ...nextWeekly }));
      setStatsCache((prev) => ({ ...prev, ...nextStats }));
    } catch (e) {
      console.warn("Background weekly prefetch failed:", e);
    }
  }

  async function handleMetricPress(key: MetricKey) {
    setSelectedMetric(key);
    setWeeklyError(null);

    // Movement is a composite of steps + walkingDistance + activeEnergy.
    // Fetch all three underlying series in parallel (using the shared
    // weeklyCache) and let the useMemo below assemble the overlay.
    if (key === "movement") {
      const keys: MetricKey[] = ["steps", "walkingDistance", "activeEnergy"];
      const missing = keys.filter((k) => !weeklyCache[k]);
      if (missing.length === 0) return;
      setWeeklyLoading(true);
      try {
        const fetched = await Promise.all(missing.map((k) => grabWeeklyData(k)));
        setWeeklyCache((prev) => {
          const next = { ...prev };
          missing.forEach((k, i) => { next[k] = fetched[i]; });
          return next;
        });
      } catch (e: any) {
        setWeeklyError(e.message ?? "Failed to load movement data");
      } finally {
        setWeeklyLoading(false);
      }
      return;
    }

    if (weeklyCache[key]) {
      if (key === "exerciseMinutes") {
        if (Object.keys(workoutsByDay).length === 0) fetchWorkoutsByDay().then(setWorkoutsByDay);
        if (Object.keys(activityTimelineByDay).length === 0) fetchActivityTimelines().then(setActivityTimelineByDay);
      }
      return;
    }
    setWeeklyLoading(true);
    try {
      const data = await grabWeeklyData(key);
      setWeeklyCache((prev) => ({ ...prev, [key]: data }));
      setStatsCache((prev) => ({ ...prev, [key]: computeStatsForMetric(key, data) }));
      if (key === "exerciseMinutes") {
        fetchWorkoutsByDay().then(setWorkoutsByDay);
        fetchActivityTimelines().then(setActivityTimelineByDay);
      }
    } catch (e: any) {
      setWeeklyError(e.message ?? "Failed to load weekly data");
    } finally {
      setWeeklyLoading(false);
    }
  }

  async function checkForOtaInBackground() {
    // Fire-and-forget. Never throws, never blocks grabContext. Silent on failure.
    try {
      if (!Updates.isEnabled) return;
      const check = await Updates.checkForUpdateAsync();
      if (!check.isAvailable) return;
      const result = await Updates.fetchUpdateAsync();
      if (result.isNew) setOtaUpdateReady(true);
    } catch {
      // Swallow — an update-check failure must not pollute the grab UX.
    }
  }

  async function grabContext() {
    setLoading(true);
    setError(null);
    setWeeklyCache({});
    setStatsCache({});
    setWeeklyError(null);
    // Kick off an OTA check in parallel. Never awaited.
    void checkForOtaInBackground();
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
          "HKWorkoutTypeIdentifier" as any,
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
      // Fire-and-forget: push today's headline to the home-screen widget's
      // shared suite. Never awaited — widget refresh is best-effort.
      void writeWidgetSnapshot({
        steps: health.steps,
        sleepHours: health.sleepHours,
        exerciseMinutes: health.exerciseMinutes,
        counter: counterValue,
      });
      // Kick off 7-day prefetch in the background so box plots appear on
      // every card without the user having to tap each one. Not awaited —
      // the UI renders immediately with today's values.
      void prefetchAllWeeklyStats();
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
      let places: PlacesSummary | null = null;
      if (snapshot.locationHistory.length > 0) {
        setShareStatus(`Clustering ${snapshot.locationHistory.length} locations...`);
        // Yield to UI before heavy computation
        await new Promise((r) => setTimeout(r, 0));
        const v2 = clusterLocationsV2(snapshot.locationHistory, knownPlaces);
        if (v2.summaryRecent || v2.summaryWeekly) {
          places = { weekly: v2.summaryWeekly, recent: v2.summaryRecent };
        }
      }
      setShareStatus("Sharing...");
      const summaryExport = buildSummaryExport(weeklyData, snapshot.health, places);
      // Compact JSON — pretty-print is a debugger affordance, not a delivery format.
      const json = JSON.stringify(summaryExport);
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

  // Build the Movement card sublabel: "<distance> km · <energy> kcal"
  const movementSublabel = (() => {
    const distPart = h?.walkingDistance != null ? `${h.walkingDistance} km` : "\u2014 km";
    const enPart = h?.activeEnergy != null ? `${formatNumber(h.activeEnergy)} kcal` : "\u2014 kcal";
    return `${distPart} \u00b7 ${enPart}`;
  })();

  // Movement card: three mini box plots stacked (steps / distance / energy),
  // each in its own color so they're readable without labels.
  const movementBoxPlotList = [
    statsCache.steps ? { stats: statsCache.steps, color: METRIC_CONFIG.steps.color } : null,
    statsCache.walkingDistance ? { stats: statsCache.walkingDistance, color: METRIC_CONFIG.walkingDistance.color } : null,
    statsCache.activeEnergy ? { stats: statsCache.activeEnergy, color: METRIC_CONFIG.activeEnergy.color } : null,
  ].filter((x): x is { stats: BoxPlotStats; color: string } => x !== null);

  const metrics: MetricCardProps[] = snapshot
    ? [
        // Movement: steps as the big headline, distance + energy as sublabel,
        // plus three stacked mini box plots (one per underlying series).
        {
          metricKey: "movement" as MetricKey,
          label: "Movement",
          value: h?.steps != null ? formatNumber(h.steps) : "\u2014",
          sublabel: movementSublabel,
          onPress: handleMetricPress,
          boxPlotStatsList: movementBoxPlotList.length > 0 ? movementBoxPlotList : undefined,
          color: METRIC_CONFIG.movement.color,
        },
        {
          metricKey: "exerciseMinutes" as MetricKey,
          label: "Exercise",
          value: h?.exerciseMinutes != null ? `${h.exerciseMinutes} min` : "\u2014",
          sublabel: h?.workouts && h.workouts.length > 0
            ? h.workouts.map(w => `${w.activityType} ${w.durationMinutes}m`).join(", ")
            : "today",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.exerciseMinutes,
          color: METRIC_CONFIG.exerciseMinutes.color,
        },
        // Cardio: live vs baseline
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
          metricKey: "restingHeartRate" as MetricKey,
          label: "Resting HR",
          value: h?.restingHeartRate != null ? `${h.restingHeartRate} bpm` : "\u2014",
          sublabel: "latest",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.restingHeartRate,
          color: METRIC_CONFIG.restingHeartRate.color,
        },
        // Recovery
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
          metricKey: "sleep" as MetricKey,
          label: "Sleep",
          value: h?.sleepHours != null ? `${h.sleepHours} hrs` : "\u2014",
          sublabel:
            h?.bedtime && h?.wakeTime
              ? `${formatLocalTime(h.bedtime)} \u2013 ${formatLocalTime(h.wakeTime)}`
              : h?.bedtime
                ? `${formatLocalTime(h.bedtime)} \u2013`
                : h?.wakeTime
                  ? `\u2013 ${formatLocalTime(h.wakeTime)}`
                  : "last night",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.sleep,
          color: METRIC_CONFIG.sleep.color,
        },
        // Wellness / body
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
          metricKey: "weight" as MetricKey,
          label: "Weight",
          value: h?.weight != null ? `${Math.round(h.weight * 2.20462)} lbs` : "\u2014",
          sublabel:
            h?.weightDaysLast7 != null
              ? `${h.weightDaysLast7}/7 days weighed`
              : "latest",
          onPress: handleMetricPress,
          boxPlotStats: statsCache.weight,
          color: METRIC_CONFIG.weight.color,
        },
      ]
    : [];

  if (gymTimerVisible) {
    return (
      <GymTimerScreen
        onExit={() => {
          setGymTimerVisible(false);
          setTimerIntent(null);
        }}
        initialMode={timerIntent?.mode}
        initialPreset={timerIntent?.preset ?? undefined}
        autostart={timerIntent?.autostart}
        onIntentConsumed={() => setTimerIntent(null)}
      />
    );
  }

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
              onPress={() => setGymTimerVisible(true)}
              accessibilityLabel="Gym Timer"
            >
              <Text style={styles.headerIconText}>{"🏋️"}</Text>
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

      {otaUpdateReady && (
        <TouchableOpacity
          style={styles.updateReadyBanner}
          onPress={async () => {
            try {
              await Updates.reloadAsync();
            } catch {
              setOtaUpdateReady(false);
            }
          }}
          accessibilityLabel="Reload with new update"
        >
          <Text style={styles.updateReadyText}>
            {"\u2193"} Update ready — tap to reload
          </Text>
        </TouchableOpacity>
      )}

      <AboutModal
        visible={aboutVisible}
        onClose={() => setAboutVisible(false)}
      />

      <SettingsModal
        visible={settingsVisible}
        onClose={() => setSettingsVisible(false)}
        db={db}
        trackingEnabled={trackingEnabled}
        setTrackingEnabled={setTrackingEnabled}
        retentionDays={retentionDays}
        setRetentionDays={setRetentionDays}
        locationCount={locationCount}
        setLocationCount={setLocationCount}
        locationStorageBytes={locationStorageBytes}
        setError={setError}
        startTracking={startTracking}
        stopTracking={stopTracking}
        sleepTargetHours={sleepTargetHours}
        setSleepTargetHours={setSleepTargetHoursState}
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

        {snapshot && (
          <>
            {summaryText.length > 0 && (
              <View style={styles.summaryBanner}>
                <Text style={styles.summaryText}>{summaryText}</Text>
              </View>
            )}

            <View style={styles.counterCard}>
              <TallyCounter
                value={counterValue}
                onPress={handleCounterIncrement}
                testID="counter-tally"
              />
              <TouchableOpacity
                onPress={handleCounterReset}
                style={styles.counterReset}
                testID="counter-reset"
                accessibilityLabel="Reset counter"
              >
                <Text style={styles.counterResetText}>↺</Text>
              </TouchableOpacity>
            </View>

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
                  boxPlotStatsList={m.boxPlotStatsList}
                  color={m.color}
                />
              ))}
            </View>

            <TouchableOpacity
              style={styles.locationCard}
              onPress={() => {
                setLocationExpanded(true);
                if (snapshot.locationHistory.length > 0 && !locationSummaryText) {
                  const v2 = clusterLocationsV2(snapshot.locationHistory, knownPlaces);
                  setLocationSummaryText(v2.summaryRecent + "\n\n" + v2.summaryWeekly);
                }
              }}
              testID="location-card"
            >
              <Text style={styles.metricLabel}>Location</Text>
              {snapshot.location ? (
                <View style={styles.locationRow}>
                  <Text style={styles.metricValue}>
                    {snapshot.location.latitude.toFixed(4)}, {snapshot.location.longitude.toFixed(4)}
                  </Text>
                  <TouchableOpacity
                    onPress={async () => {
                      if (!snapshot.location) return;
                      const text = `${snapshot.location.latitude.toFixed(6)}, ${snapshot.location.longitude.toFixed(6)}`;
                      await Clipboard.setStringAsync(text);
                      setLocationCopied(true);
                      setTimeout(() => setLocationCopied(false), 1500);
                    }}
                    style={styles.copyButton}
                    testID="location-copy"
                    accessibilityLabel="Copy coordinates"
                  >
                    <Text style={styles.copyButtonText}>
                      {locationCopied ? "Copied" : "Copy"}
                    </Text>
                  </TouchableOpacity>
                </View>
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
            </TouchableOpacity>

            <LocationDetailSheet
              visible={locationExpanded}
              onClose={() => setLocationExpanded(false)}
              db={db}
              location={snapshot.location}
              locationHistory={snapshot.locationHistory}
              knownPlaces={knownPlaces}
              setKnownPlaces={setKnownPlaces}
              setError={setError}
              locationSummaryText={locationSummaryText}
            />

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
      {selectedMetric && (() => {
        // Movement overlay data derived from the three underlying cached series.
        let movementData: MovementOverlayData | null = null;
        if (selectedMetric === "movement") {
          const steps = weeklyCache.steps as DailyValue[] | undefined;
          const dist = weeklyCache.walkingDistance as DailyValue[] | undefined;
          const energy = weeklyCache.activeEnergy as DailyValue[] | undefined;
          if (steps && dist && energy) {
            movementData = buildMovementOverlay(steps, dist, energy);
          }
        }
        return (
          <MetricDetailSheet
            metricKey={selectedMetric}
            currentValue={
              metrics.find((m) => m.metricKey === selectedMetric)?.value ?? "\u2014"
            }
            currentSublabel={
              metrics.find((m) => m.metricKey === selectedMetric)?.sublabel ?? ""
            }
            data={selectedMetric === "movement" ? null : (weeklyCache[selectedMetric] ?? null)}
            error={weeklyError}
            onClose={() => {
              setSelectedMetric(null);
              setWeeklyError(null);
            }}
            workouts={selectedMetric === "exerciseMinutes" ? snapshot?.health.workouts : undefined}
            workoutsByDay={selectedMetric === "exerciseMinutes" ? workoutsByDay : undefined}
            activityTimelineByDay={selectedMetric === "exerciseMinutes" ? activityTimelineByDay : undefined}
            movementData={movementData}
            sleepBundle={selectedMetric === "sleep" ? sleepDetailedCache : null}
            sleepTargetHours={selectedMetric === "sleep" ? sleepTargetHours : null}
            fetchRawCache={db && selectedMetric !== "movement" ? async () => {
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
        );
      })()}
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
  counterCard: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: "#1a1a2e",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginBottom: 12,
  },
  counterReset: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#2a2a40",
  },
  counterResetText: {
    color: "#888",
    fontSize: 18,
    fontWeight: "600",
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
  locationRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  copyButton: {
    backgroundColor: "#1f3a6b",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  copyButtonText: {
    color: "#e0e0e0",
    fontSize: 13,
    fontWeight: "600",
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
  updateReadyBanner: {
    marginHorizontal: 20,
    marginTop: 8,
    paddingVertical: 8,
    paddingHorizontal: 14,
    backgroundColor: "#1d4e4a",
    borderRadius: 10,
    borderWidth: 1,
    borderColor: "#4cc9f0",
    alignItems: "center",
  },
  updateReadyText: {
    color: "#4cc9f0",
    fontSize: 13,
    fontWeight: "600",
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
