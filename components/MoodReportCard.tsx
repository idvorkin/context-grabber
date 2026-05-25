import React, { useCallback, useEffect, useState } from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import type * as SQLite from "expo-sqlite";
import {
  getMoodForDate,
  logMood,
  todayDateKey,
  type MoodScore,
} from "../lib/moodLog";

type Props = {
  db: SQLite.SQLiteDatabase | null;
  /** Called after a save so a parent can re-fetch + sync. */
  onSaved?: () => void;
};

const SCORES: MoodScore[] = [1, 2, 3, 4, 5];

/**
 * Compact mood + energy self-report. Two rows of 5 number buttons; tapping
 * a number records that dimension immediately. Spec: ≤ 3 taps for a full
 * mood + energy entry; with auto-save on tap this card needs 2.
 */
export function MoodReportCard({ db, onSaved }: Props) {
  const [mood, setMood] = useState<MoodScore | null>(null);
  const [energy, setEnergy] = useState<MoodScore | null>(null);
  const [note, setNote] = useState("");
  const [today, setToday] = useState(todayDateKey());

  // Load today's existing entry (if any) on mount + when db becomes ready.
  useEffect(() => {
    if (!db) return;
    const key = todayDateKey();
    setToday(key);
    void (async () => {
      try {
        const existing = await getMoodForDate(db, key);
        if (existing) {
          setMood(existing.mood);
          setEnergy(existing.energy);
          setNote(existing.note ?? "");
        }
      } catch {
        // Soft-fail on load — the card stays at defaults
      }
    })();
  }, [db]);

  const persist = useCallback(
    async (next: { mood: MoodScore | null; energy: MoodScore | null; note: string }) => {
      if (!db) return;
      if (next.mood == null || next.energy == null) return;
      try {
        await logMood(db, {
          date: today,
          mood: next.mood,
          energy: next.energy,
          note: next.note.trim() === "" ? null : next.note.trim(),
        });
        onSaved?.();
      } catch {
        // Soft-fail; UI keeps the selection so a re-tap retries
      }
    },
    [db, today, onSaved],
  );

  const onMoodPress = (score: MoodScore) => {
    setMood(score);
    void persist({ mood: score, energy, note });
  };
  const onEnergyPress = (score: MoodScore) => {
    setEnergy(score);
    void persist({ mood, energy: score, note });
  };

  return (
    <View style={styles.card} testID="mood-report-card">
      <Text style={styles.heading}>How was today?</Text>
      <ScoreRow
        label="Mood"
        selected={mood}
        onPress={onMoodPress}
        testIdPrefix="mood"
      />
      <ScoreRow
        label="Energy"
        selected={energy}
        onPress={onEnergyPress}
        testIdPrefix="energy"
      />
      <TextInput
        style={styles.note}
        placeholder="Note (optional)"
        placeholderTextColor="#666"
        value={note}
        onChangeText={setNote}
        onEndEditing={() => void persist({ mood, energy, note })}
        multiline
      />
    </View>
  );
}

function ScoreRow({
  label,
  selected,
  onPress,
  testIdPrefix,
}: {
  label: string;
  selected: MoodScore | null;
  onPress: (s: MoodScore) => void;
  testIdPrefix: string;
}) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <View style={styles.buttons}>
        {SCORES.map((s) => {
          const isOn = selected === s;
          return (
            <Pressable
              key={s}
              onPress={() => onPress(s)}
              style={[styles.btn, isOn && styles.btnOn]}
              testID={`${testIdPrefix}-${s}`}
              accessibilityLabel={`${label} ${s} of 5`}
              accessibilityState={{ selected: isOn }}
            >
              <Text style={[styles.btnText, isOn && styles.btnTextOn]}>{s}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
  },
  heading: {
    color: "#4cc9f0",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginBottom: 12,
  },
  row: { marginBottom: 12 },
  rowLabel: { color: "#ccc", fontSize: 13, marginBottom: 6 },
  buttons: { flexDirection: "row", gap: 6 },
  btn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: "#1a1a2e",
    alignItems: "center",
  },
  btnOn: { backgroundColor: "#4cc9f0" },
  btnText: { color: "#888", fontSize: 16, fontWeight: "600" },
  btnTextOn: { color: "#0c121f" },
  note: {
    color: "#e0e0e0",
    backgroundColor: "#1a1a2e",
    borderRadius: 8,
    padding: 10,
    fontSize: 13,
    minHeight: 40,
    textAlignVertical: "top",
  },
});
