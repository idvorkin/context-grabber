import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  TouchableOpacity,
  Share,
  Platform,
} from "react-native";
import * as Location from "expo-location";
import HealthKit from "@kingstinct/react-native-healthkit";
import type {
  QuantityTypeIdentifier,
  CategoryTypeIdentifier,
} from "@kingstinct/react-native-healthkit";
import { buildHealthData, type HealthData } from "./lib/health";

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type ContextSnapshot = {
  timestamp: string;
  health: HealthData;
  location: LocationData;
};

const QTI = {
  stepCount: "HKQuantityTypeIdentifierStepCount" as QuantityTypeIdentifier,
  heartRate: "HKQuantityTypeIdentifierHeartRate" as QuantityTypeIdentifier,
  activeEnergy:
    "HKQuantityTypeIdentifierActiveEnergyBurned" as QuantityTypeIdentifier,
  distance:
    "HKQuantityTypeIdentifierDistanceWalkingRunning" as QuantityTypeIdentifier,
};

const CTI = {
  sleep: "HKCategoryTypeIdentifierSleepAnalysis" as CategoryTypeIdentifier,
};

export default function App() {
  const [snapshot, setSnapshot] = useState<ContextSnapshot | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

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

    const results = await Promise.allSettled([
      HealthKit.queryStatisticsForQuantity(QTI.stepCount, ["cumulativeSum"], {
        filter: dateFilter,
      }),
      HealthKit.getMostRecentQuantitySample(QTI.heartRate),
      HealthKit.queryStatisticsForQuantity(
        QTI.activeEnergy,
        ["cumulativeSum"],
        { filter: dateFilter }
      ),
      HealthKit.queryStatisticsForQuantity(QTI.distance, ["cumulativeSum"], {
        filter: dateFilter,
      }),
      HealthKit.queryCategorySamples(CTI.sleep, {
        limit: 0,
        filter: sleepDateFilter,
      }),
    ]);

    return buildHealthData(results as any);
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
        toRead: [QTI.stepCount, QTI.heartRate, QTI.activeEnergy, QTI.distance, CTI.sleep],
      });

      const [health, location] = await Promise.all([
        grabHealthData(),
        grabLocation(),
      ]);

      const result: ContextSnapshot = {
        timestamp: new Date().toISOString(),
        health,
        location,
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

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      <View style={styles.header}>
        <Text style={styles.title}>Context Grabber</Text>
        <Text style={styles.subtitle}>
          Grab your iPhone context for your AI life coach
        </Text>
      </View>

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
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Health</Text>
            <Text style={styles.dataRow}>
              Steps: {snapshot.health.steps ?? "—"}
            </Text>
            <Text style={styles.dataRow}>
              Heart Rate: {snapshot.health.heartRate ?? "—"} bpm
            </Text>
            <Text style={styles.dataRow}>
              Sleep: {snapshot.health.sleepHours ?? "—"} hrs
            </Text>
            <Text style={styles.dataRow}>
              Active Energy: {snapshot.health.activeEnergy ?? "—"} kcal
            </Text>
            <Text style={styles.dataRow}>
              Distance: {snapshot.health.walkingDistance ?? "—"} km
            </Text>

            <Text style={[styles.cardTitle, { marginTop: 16 }]}>Location</Text>
            {snapshot.location ? (
              <Text style={styles.dataRow}>
                {snapshot.location.latitude.toFixed(4)},{" "}
                {snapshot.location.longitude.toFixed(4)}
              </Text>
            ) : (
              <Text style={styles.dataRow}>Unavailable</Text>
            )}

            <Text style={styles.timestamp}>{snapshot.timestamp}</Text>
          </View>
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
  card: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginTop: 12,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#4cc9f0",
    marginBottom: 8,
  },
  dataRow: {
    fontSize: 16,
    color: "#ccc",
    marginBottom: 4,
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
});
