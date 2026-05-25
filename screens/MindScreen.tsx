import React from "react";
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import type * as SQLite from "expo-sqlite";
import TallyCounter from "../components/TallyCounter";
import { MeditationFlatlineCard } from "../components/MeditationFlatlineCard";
import { MoodReportCard } from "../components/MoodReportCard";
import type { DailyValue } from "../lib/weekly";

type Props = {
  db: SQLite.SQLiteDatabase | null;
  counterValue: number;
  todayMeditationMinutes: number | null;
  weeklyMeditation: DailyValue[] | null;
  onOpenAffirmation: () => void;
  onOpenGrateful: () => void;
  onOpenJournal: () => void;
  onCounterIncrement: () => void;
  onCounterReset: () => void;
  onMoodSaved?: () => void;
};

export function MindScreen({
  db,
  counterValue,
  todayMeditationMinutes,
  weeklyMeditation,
  onOpenAffirmation,
  onOpenGrateful,
  onOpenJournal,
  onCounterIncrement,
  onCounterReset,
  onMoodSaved,
}: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Mind</Text>
      </View>
      <ScrollView contentContainerStyle={styles.scroll}>
        <MoodReportCard db={db} onSaved={onMoodSaved} />

        <MeditationFlatlineCard
          todayMinutes={todayMeditationMinutes}
          weekly={weeklyMeditation}
        />

        <Text style={styles.sectionHeading}>Reflect</Text>
        <View style={styles.reflectGrid}>
          <TouchableOpacity
            style={[styles.reflectBtn, styles.btnAffirm]}
            onPress={onOpenAffirmation}
            testID="mind-affirm"
          >
            <Text style={styles.reflectBtnText}>🎯 Affirm</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.reflectBtn, styles.btnGrateful]}
            onPress={onOpenGrateful}
            testID="mind-grateful"
          >
            <Text style={styles.reflectBtnText}>🙏 Grateful</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.reflectBtn, styles.btnJournal]}
            onPress={onOpenJournal}
            testID="mind-journal"
          >
            <Text style={styles.reflectBtnText}>📖 Journal</Text>
          </TouchableOpacity>
        </View>

        <Text style={styles.sectionHeading}>Tally</Text>
        <View style={styles.counterCard}>
          <TallyCounter
            value={counterValue}
            onPress={onCounterIncrement}
            testID="mind-counter-tally"
          />
          <TouchableOpacity
            onPress={onCounterIncrement}
            style={styles.counterPlusOne}
            testID="mind-counter-plus-one"
            accessibilityLabel="Add one to counter"
          >
            <Text style={styles.counterPlusOneText}>+1</Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={onCounterReset}
            style={styles.counterReset}
            testID="mind-counter-reset"
            accessibilityLabel="Reset counter"
          >
            <Text style={styles.counterResetText}>↺</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: { paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  title: { fontSize: 28, fontWeight: "bold", color: "#e0e0e0" },
  scroll: { paddingHorizontal: 20, paddingBottom: 20 },
  sectionHeading: {
    color: "#4cc9f0",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 8,
    marginBottom: 8,
  },
  reflectGrid: {
    flexDirection: "row",
    gap: 8,
    marginBottom: 16,
  },
  reflectBtn: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: "center",
  },
  btnAffirm: { backgroundColor: "#1a2a3a" },
  btnGrateful: { backgroundColor: "#2a1f1a" },
  btnJournal: { backgroundColor: "#1a1a1a" },
  reflectBtnText: { color: "#fff", fontSize: 14, fontWeight: "600" },
  counterCard: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: "#16213e",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
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
});
