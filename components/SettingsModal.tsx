import { useState, useRef } from "react";
import {
  Text,
  View,
  ScrollView,
  TouchableOpacity,
  Share,
  Switch,
  TextInput,
  Modal,
  StyleSheet,
} from "react-native";
import HealthKit from "@kingstinct/react-native-healthkit";
import type { CategoryTypeIdentifier } from "@kingstinct/react-native-healthkit";
import type * as SQLite from "expo-sqlite";
import { setSetting, pruneLocations, getLocationCount } from "../lib/db";

const CTI_SLEEP =
  "HKCategoryTypeIdentifierSleepAnalysis" as CategoryTypeIdentifier;

type SettingsModalProps = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
  trackingEnabled: boolean;
  setTrackingEnabled: (enabled: boolean) => void;
  retentionDays: string;
  setRetentionDays: (days: string) => void;
  locationCount: number;
  setLocationCount: (count: number) => void;
  locationStorageBytes: number;
  setError: (error: string) => void;
  startTracking: () => Promise<boolean>;
  stopTracking: () => Promise<boolean>;
};

export default function SettingsModal({
  visible,
  onClose,
  db,
  trackingEnabled,
  setTrackingEnabled,
  retentionDays,
  setRetentionDays,
  locationCount,
  setLocationCount,
  locationStorageBytes,
  setError,
  startTracking,
  stopTracking,
}: SettingsModalProps) {
  const [trackingExpanded, setTrackingExpanded] = useState(false);
  const [debugExpanded, setDebugExpanded] = useState(false);
  const [debugSleepData, setDebugSleepData] = useState<string | null>(null);
  const retentionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  async function handleTrackingToggle(enabled: boolean) {
    if (!db) { setError("Database not available. Please restart the app."); return; }
    try {
      if (enabled) { const started = await startTracking(); if (!started) return; }
      else { const stopped = await stopTracking(); if (!stopped) return; }
      setTrackingEnabled(enabled);
      await setSetting(db, "tracking_enabled", enabled ? "true" : "false");
    } catch (e: any) { setError(e.message ?? "Failed to update tracking setting"); }
  }

  function handleRetentionChange(text: string) {
    setRetentionDays(text);
    if (retentionTimerRef.current) clearTimeout(retentionTimerRef.current);
    retentionTimerRef.current = setTimeout(async () => {
      if (!db) { setError("Database not available. Please restart the app."); return; }
      const days = parseInt(text, 10);
      if (!isNaN(days) && days >= 0) {
        try {
          await setSetting(db, "retention_days", String(days));
          await pruneLocations(db, days);
          const count = await getLocationCount(db);
          setLocationCount(count);
        } catch (e: any) { setError(e.message ?? "Failed to update retention setting"); }
      }
    }, 1000);
  }

  async function handleFetchDebugSleep() {
    try {
      setDebugSleepData("Loading...");
      const now = new Date();
      const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
      const samples = await HealthKit.queryCategorySamples(CTI_SLEEP, {
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
    } catch (e: any) { setDebugSleepData(`Error: ${e.message}`); }
  }

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <View style={styles.modalContainer}>
        <View style={styles.modalHeader}>
          <Text style={styles.modalTitle}>Settings</Text>
          <TouchableOpacity onPress={onClose} style={styles.modalCloseButton}>
            <Text style={styles.modalCloseText}>Done</Text>
          </TouchableOpacity>
        </View>
        <ScrollView style={styles.modalContent} keyboardDismissMode="on-drag" keyboardShouldPersistTaps="handled" contentContainerStyle={{ paddingBottom: 300 }}>
          <View style={styles.card}>
            <TouchableOpacity onPress={() => setTrackingExpanded(!trackingExpanded)} style={styles.settingRow}>
              <Text style={styles.sectionTitle}>Location Tracking</Text>
              <Text style={{ color: "#888", fontSize: 16 }}>{trackingExpanded ? "\u25B2" : "\u25BC"}</Text>
            </TouchableOpacity>
            {trackingExpanded && (
              <>
                <View style={styles.settingRow}>
                  <Text style={styles.settingText}>Background Tracking</Text>
                  <Switch value={trackingEnabled} onValueChange={handleTrackingToggle} trackColor={{ false: "#555", true: "#4361ee" }} thumbColor="#fff" />
                </View>
                <View style={styles.settingRow}>
                  <Text style={styles.settingText}>Retention (days)</Text>
                  <TextInput style={styles.retentionInput} value={retentionDays} onChangeText={handleRetentionChange} keyboardType="number-pad" maxLength={4} selectTextOnFocus />
                </View>
                <Text style={styles.countText}>
                  {locationCount} location{locationCount !== 1 ? "s" : ""} tracked
                  {locationStorageBytes > 0 ? ` (${locationStorageBytes > 1024 * 1024 ? `${(locationStorageBytes / (1024 * 1024)).toFixed(1)} MB` : locationStorageBytes > 1024 ? `${(locationStorageBytes / 1024).toFixed(1)} KB` : `${locationStorageBytes} B`})` : ""}
                </Text>
              </>
            )}
          </View>

          <View style={styles.card}>
            <TouchableOpacity onPress={() => setDebugExpanded(!debugExpanded)} style={styles.settingRow}>
              <Text style={styles.sectionTitle}>Debug: Raw Sleep Data</Text>
              <Text style={{ color: "#888", fontSize: 16 }}>{debugExpanded ? "\u25B2" : "\u25BC"}</Text>
            </TouchableOpacity>
            {debugExpanded && (
              <>
                <Text style={styles.countText}>Last 2 days of raw HealthKit sleep samples with source info</Text>
                <TouchableOpacity style={[styles.actionButton, { marginTop: 8 }]} onPress={handleFetchDebugSleep}>
                  <Text style={styles.actionButtonText}>Fetch Raw Sleep</Text>
                </TouchableOpacity>
                {debugSleepData && debugSleepData !== "Loading..." && (
                  <TouchableOpacity style={[styles.actionButton, { marginTop: 8, backgroundColor: "#3d405b" }]} onPress={() => Share.share({ message: debugSleepData })}>
                    <Text style={styles.actionButtonText}>Copy / Share</Text>
                  </TouchableOpacity>
                )}
                {debugSleepData && (
                  <ScrollView style={{ maxHeight: 400, marginTop: 8 }} nestedScrollEnabled>
                    <Text style={{ color: "#ccc", fontSize: 11, fontFamily: "Courier" }}>{debugSleepData}</Text>
                  </ScrollView>
                )}
              </>
            )}
          </View>
        </ScrollView>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalContainer: { flex: 1, backgroundColor: "#1a1a2e" },
  modalHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: 20, paddingTop: 16, paddingBottom: 12 },
  modalTitle: { fontSize: 20, fontWeight: "bold", color: "#e0e0e0" },
  modalCloseButton: { padding: 8 },
  modalCloseText: { color: "#4895ef", fontSize: 16, fontWeight: "600" },
  modalContent: { flex: 1, paddingHorizontal: 16 },
  card: { backgroundColor: "#16213e", borderRadius: 12, padding: 16, marginBottom: 12 },
  sectionTitle: { fontSize: 16, fontWeight: "bold", color: "#e0e0e0" },
  settingRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingVertical: 8 },
  settingText: { color: "#e0e0e0", fontSize: 14 },
  retentionInput: { color: "#fff", fontSize: 14, backgroundColor: "#0f3460", borderRadius: 8, paddingHorizontal: 12, paddingVertical: 4, width: 60, textAlign: "center" },
  countText: { color: "#888", fontSize: 12, marginTop: 4 },
  actionButton: { backgroundColor: "#2d6a4f", borderRadius: 8, paddingVertical: 10, paddingHorizontal: 16, alignItems: "center" },
  actionButtonText: { color: "#fff", fontSize: 14, fontWeight: "600" },
});
