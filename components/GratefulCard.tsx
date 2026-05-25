import React, { useEffect, useState } from "react";
import {
  Modal,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
} from "react-native";
import * as SQLite from "expo-sqlite";
import { createGratitude } from "../lib/journal";
import { insertEntry, insertAudio, tallyByContextFromDb } from "../lib/journalDb";
import { recordJournalMoment } from "../lib/autoDetect";
import { syncJournal } from "../lib/cloudkit";
import { uuidV4 } from "../lib/uuid";
import { VoiceRecorder, type RecordedVoice } from "./VoiceRecorder";
import { CopyableError } from "./CopyableError";

type Props = {
  visible: boolean;
  onClose: () => void;
  db: SQLite.SQLiteDatabase | null;
};

export function GratefulCard({ visible, onClose, db }: Props) {
  const [text, setText] = useState("");
  const [pendingVoice, setPendingVoice] = useState<RecordedVoice | null>(null);
  const [saving, setSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [todayCount, setTodayCount] = useState(0);
  const [savedHint, setSavedHint] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;
    setText("");
    setPendingVoice(null);
    setErrorMsg(null);
    setSavedHint(null);
    refreshTally();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  async function refreshTally() {
    if (!db) return;
    const t = await tallyByContextFromDb(db);
    setTodayCount(t.grateful);
  }

  async function handleSave(stayOpen: boolean) {
    if (!db) {
      setErrorMsg("DB not ready");
      return;
    }
    if (!text.trim() && !pendingVoice) {
      setErrorMsg("Add a note or record voice first");
      return;
    }
    setSaving(true);
    setErrorMsg(null);
    try {
      const now = Date.now();
      let audioRecordingId: string | null = null;
      if (pendingVoice) {
        await insertAudio(db, {
          id: pendingVoice.recordingId,
          filePath: pendingVoice.filePath,
          durationMs: pendingVoice.durationMs,
          createdAt: now,
        });
        audioRecordingId = pendingVoice.recordingId;
      }
      const entry = createGratitude({
        id: uuidV4(),
        date: now,
        text: text.trim(),
        audioRecordingId,
        createdAt: now,
      });
      await insertEntry(db, entry);
      void syncJournal(db);
      void recordJournalMoment(db, entry);

      setText("");
      setPendingVoice(null);
      await refreshTally();

      if (stayOpen) {
        setSavedHint("Saved · add another");
        setTimeout(() => setSavedHint(null), 1500);
      } else {
        onClose();
      }
    } catch (e: any) {
      setErrorMsg(e?.message ?? String(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        style={{ flex: 1, backgroundColor: "#000" }}
      >
        <View style={styles.header}>
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.cancel}>Cancel</Text>
          </TouchableOpacity>
          <Text style={styles.tally}>🙏 {todayCount} today</Text>
          <View style={{ width: 50 }} />
        </View>

        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 20, paddingBottom: 40 }}
          keyboardShouldPersistTaps="handled"
        >
          <Text style={styles.heading}>Grateful</Text>
          <Text style={styles.prompt}>I'm grateful for…</Text>

          <TextInput
            style={styles.textInput}
            placeholder="I'm grateful for…"
            placeholderTextColor="#666"
            multiline
            value={text}
            onChangeText={setText}
          />

          <View style={{ marginTop: 16, alignItems: "center" }}>
            <VoiceRecorder
              onRecorded={(v) => setPendingVoice(v)}
              onError={(m) => setErrorMsg(m)}
              disabled={saving}
            />
            {pendingVoice && (
              <View style={styles.voiceReady}>
                <Text style={styles.voiceReadyText}>
                  ✓ voice ready · {Math.round(pendingVoice.durationMs / 1000)}s
                </Text>
                <TouchableOpacity onPress={() => setPendingVoice(null)}>
                  <Text style={styles.voiceClear}>discard</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>

          {errorMsg && (
            <CopyableError
              message={errorMsg}
              context="GratefulCard"
              extra={{
                hasVoice: pendingVoice ? "yes" : "no",
              }}
              style={{ marginTop: 12 }}
            />
          )}
          {savedHint && <Text style={styles.savedHint}>{savedHint}</Text>}

          <View style={styles.saveRow}>
            <TouchableOpacity
              onPress={() => handleSave(true)}
              disabled={saving}
              style={[styles.saveBtn, styles.saveBtnSecondary]}
            >
              <Text style={styles.saveBtnText}>Save & add another</Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => handleSave(false)}
              disabled={saving}
              style={styles.saveBtn}
            >
              <Text style={styles.saveBtnText}>{saving ? "Saving…" : "Save"}</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = {
  header: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    justifyContent: "space-between" as const,
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderBottomColor: "#222",
    borderBottomWidth: 1,
  },
  cancel: { color: "#4a9eff", fontSize: 16 },
  tally: { color: "#bbb", fontSize: 13 },
  heading: {
    color: "#fff",
    fontSize: 28,
    fontWeight: "700" as const,
    textAlign: "center" as const,
    marginTop: 8,
  },
  prompt: {
    color: "#888",
    fontSize: 16,
    marginTop: 8,
    fontStyle: "italic" as const,
    textAlign: "center" as const,
  },
  textInput: {
    backgroundColor: "#1a1a1a",
    color: "#fff",
    borderRadius: 12,
    padding: 14,
    minHeight: 100,
    fontSize: 16,
    marginTop: 12,
    textAlignVertical: "top" as const,
  },
  voiceReady: {
    flexDirection: "row" as const,
    alignItems: "center" as const,
    justifyContent: "space-between" as const,
    marginTop: 14,
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: "#1a2a1a",
    borderRadius: 10,
  },
  voiceReadyText: { color: "#7fdf7f", fontSize: 14 },
  voiceClear: { color: "#ff8a8a", fontSize: 13 },
  errorText: {
    color: "#ff8a8a",
    fontSize: 13,
    marginTop: 12,
  },
  savedHint: {
    color: "#7fdf7f",
    fontSize: 13,
    marginTop: 12,
    textAlign: "center" as const,
  },
  saveRow: {
    flexDirection: "row" as const,
    gap: 8,
    marginTop: 24,
  },
  saveBtn: {
    flex: 1,
    paddingVertical: 14,
    backgroundColor: "#0a4a8a",
    borderRadius: 10,
    alignItems: "center" as const,
  },
  saveBtnSecondary: { backgroundColor: "#222" },
  saveBtnText: { color: "#fff", fontSize: 15, fontWeight: "600" as const },
};
