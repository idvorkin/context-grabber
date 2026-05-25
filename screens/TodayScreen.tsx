import React from "react";
import {
  Platform,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import * as Updates from "expo-updates";
import TallyCounter from "../components/TallyCounter";
import type { ContextSnapshot } from "../lib/appTypes";

type Props = {
  snapshot: ContextSnapshot | null;
  loading: boolean;
  loadingStartedAt: number | null;
  loadingPhase: string | null;
  error: string | null;
  otaUpdateReady: boolean;
  setOtaUpdateReady: (v: boolean) => void;
  counterValue: number;
  reflectTally: { opportunity: number; didit: number; grateful: number };
  sharing: boolean;
  shareStatus: string;
  onOpenSettings: () => void;
  onOpenAffirmation: () => void;
  onOpenGrateful: () => void;
  onOpenJournal: () => void;
  onCounterIncrement: () => void;
  onCounterReset: () => void;
  onRefresh: () => void;
  onShareSnapshot: () => void;
  onShareRaw: () => void;
};

export function TodayScreen({
  snapshot,
  loading,
  loadingStartedAt,
  loadingPhase,
  error,
  otaUpdateReady,
  setOtaUpdateReady,
  counterValue,
  reflectTally,
  sharing,
  shareStatus,
  onOpenSettings,
  onOpenAffirmation,
  onOpenGrateful,
  onOpenJournal,
  onCounterIncrement,
  onCounterReset,
  onRefresh,
  onShareSnapshot,
  onShareRaw,
}: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerRow}>
          <View style={styles.headerText}>
            <Text style={styles.title}>Context Grabber</Text>
          </View>
          <View style={styles.headerButtons}>
            {loading && loadingStartedAt != null && (
              <View style={styles.loadingPill}>
                <Text style={styles.loadingPillText}>
                  {Math.max(0, Math.floor((Date.now() - loadingStartedAt) / 1000))}s
                  {loadingPhase ? ` · ${loadingPhase}` : ""}
                </Text>
              </View>
            )}
            <TouchableOpacity
              style={styles.headerIconButton}
              onPress={onOpenSettings}
              accessibilityLabel="Settings"
            >
              <Text style={styles.headerIconText}>{"⚙"}</Text>
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
            {"↓"} Update ready — tap to reload
          </Text>
        </TouchableOpacity>
      )}

      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={onRefresh}
            tintColor="#4cc9f0"
          />
        }
      >
        {error && (
          <View style={styles.errorBox}>
            <Text style={styles.errorText}>{error}</Text>
          </View>
        )}

        {snapshot && (
          <>
            <View style={styles.counterCard}>
              <TallyCounter
                value={counterValue}
                onPress={onCounterIncrement}
                testID="counter-tally"
              />
              <TouchableOpacity
                onPress={onCounterIncrement}
                style={styles.counterPlusOne}
                testID="counter-plus-one"
                accessibilityLabel="Add one to counter"
              >
                <Text style={styles.counterPlusOneText}>+1</Text>
              </TouchableOpacity>
              <TouchableOpacity
                onPress={onCounterReset}
                style={styles.counterReset}
                testID="counter-reset"
                accessibilityLabel="Reset counter"
              >
                <Text style={styles.counterResetText}>↺</Text>
              </TouchableOpacity>
            </View>

            <View style={reflectStyles.zone}>
              <View style={reflectStyles.headerRow}>
                <Text style={reflectStyles.heading}>Reflect</Text>
                <Text style={reflectStyles.tally}>
                  ☀️ {reflectTally.opportunity}  ✓ {reflectTally.didit}  🙏 {reflectTally.grateful}
                </Text>
              </View>
              <View style={reflectStyles.btnRow}>
                <TouchableOpacity
                  style={[reflectStyles.btn, reflectStyles.btnAffirm]}
                  onPress={onOpenAffirmation}
                  testID="reflect-affirm"
                >
                  <Text style={reflectStyles.btnText}>🎯 Affirm</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[reflectStyles.btn, reflectStyles.btnGrateful]}
                  onPress={onOpenGrateful}
                  testID="reflect-grateful"
                >
                  <Text style={reflectStyles.btnText}>🙏 Grateful</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[reflectStyles.btn, reflectStyles.btnJournal]}
                  onPress={onOpenJournal}
                  testID="reflect-journal"
                >
                  <Text style={reflectStyles.btnText}>📖 Journal</Text>
                </TouchableOpacity>
              </View>
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
              onPress={onShareSnapshot}
              disabled={sharing}
            >
              <Text style={styles.buttonText}>
                {sharing ? (shareStatus || "Preparing...") : "↗ Summary"}
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.button, styles.rawButton, styles.shareButtonHalf]}
              onPress={onShareRaw}
            >
              <Text style={styles.buttonText}>{"↗"} Raw</Text>
            </TouchableOpacity>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: { paddingTop: 60, paddingHorizontal: 20, paddingBottom: 16 },
  headerRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  headerText: { flex: 1 },
  headerButtons: {
    flexDirection: "row",
    gap: 8,
    alignItems: "center",
    marginTop: 4,
  },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  headerIconButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "#16213e",
    justifyContent: "center",
    alignItems: "center",
  },
  headerIconText: { color: "#4cc9f0", fontSize: 16, fontWeight: "700" },
  loadingPill: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 10,
    backgroundColor: "rgba(76,201,240,0.15)",
  },
  loadingPillText: {
    color: "#4cc9f0",
    fontSize: 11,
    fontWeight: "600",
    fontVariant: ["tabular-nums"],
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
  updateReadyText: { color: "#4cc9f0", fontSize: 13, fontWeight: "600" },
  content: { flex: 1, paddingHorizontal: 20 },
  contentInner: { paddingBottom: 20 },
  errorBox: {
    backgroundColor: "#3d1f1f",
    borderRadius: 8,
    padding: 12,
    marginTop: 12,
  },
  errorText: { color: "#ff6b6b", fontSize: 14 },
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
  counterPlusOne: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: "rgba(76, 201, 240, 0.18)",
    marginLeft: "auto",
    marginRight: 8,
  },
  counterPlusOneText: { color: "#4cc9f0", fontSize: 15, fontWeight: "700" },
  counterReset: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#2a2a40",
  },
  counterResetText: { color: "#888", fontSize: 18, fontWeight: "600" },
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
  metricLabel: {
    fontSize: 13,
    fontWeight: "600",
    color: "#4cc9f0",
    marginBottom: 4,
  },
  metricValue: { fontSize: 22, fontWeight: "bold", color: "#e0e0e0" },
  metricValueNull: { color: "#555" },
  metricSublabel: { fontSize: 11, color: "#888", marginTop: 2 },
  timestamp: {
    fontSize: 12,
    color: "#666",
    marginTop: 12,
    textAlign: "right",
  },
  buttons: {
    paddingHorizontal: 20,
    paddingBottom: Platform.OS === "ios" ? 16 : 12,
    paddingTop: 8,
    gap: 10,
  },
  shareRow: { flexDirection: "row", gap: 10 },
  button: { borderRadius: 12, padding: 16, alignItems: "center" },
  shareButton: { backgroundColor: "#2d6a4f" },
  shareButtonHalf: { flex: 1 },
  rawButton: { backgroundColor: "#3d405b" },
  buttonText: { color: "#fff", fontSize: 16, fontWeight: "600" },
});

const reflectStyles = StyleSheet.create({
  zone: {
    backgroundColor: "#0e0e0e",
    borderRadius: 14,
    padding: 14,
    borderWidth: 1,
    borderColor: "#1a1a1a",
    marginBottom: 4,
  },
  headerRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 10,
  },
  heading: {
    color: "#fff",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  tally: { color: "#bbb", fontSize: 13, fontVariant: ["tabular-nums"] },
  btnRow: { flexDirection: "row", gap: 8 },
  btn: {
    flex: 1,
    paddingVertical: 14,
    backgroundColor: "#1a1a1a",
    borderRadius: 10,
    alignItems: "center",
  },
  btnAffirm: { backgroundColor: "#1a2a3a" },
  btnGrateful: { backgroundColor: "#2a1f1a" },
  btnJournal: { backgroundColor: "#1a1a1a" },
  btnText: { color: "#fff", fontSize: 14, fontWeight: "600" },
});
