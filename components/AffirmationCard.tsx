import React, { useEffect, useMemo, useRef, useState } from "react";
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
import {
  AFFIRMATIONS,
  getRandomAffirmationIndex,
  type Affirmation,
} from "../lib/affirmations";
import { createEntry, type JournalContext } from "../lib/journal";
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

const PROMPTS: Record<JournalContext, string> = {
  opportunity: "How will you apply this today?",
  didit: "How did you apply this?",
  grateful: "I'm grateful for…",
};

export function AffirmationCard({ visible, onClose, db }: Props) {
  const [index, setIndex] = useState(() => getRandomAffirmationIndex());
  const [picker, setPicker] = useState(false);
  const [context, setContext] = useState<JournalContext>("opportunity");
  const [text, setText] = useState("");
  const [pendingVoice, setPendingVoice] = useState<RecordedVoice | null>(null);
  const [saving, setSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [tally, setTally] = useState({ opportunity: 0, didit: 0, grateful: 0 });
  const [savedHint, setSavedHint] = useState<string | null>(null);
  const lastIndexRef = useRef(index);

  const affirmation: Affirmation = AFFIRMATIONS[index];

  // Re-randomize on each open.
  useEffect(() => {
    if (!visible) return;
    const next = getRandomAffirmationIndex(lastIndexRef.current);
    setIndex(next);
    lastIndexRef.current = next;
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
    setTally(t);
  }

  function selectAffirmation(i: number) {
    setIndex(i);
    lastIndexRef.current = i;
    setPicker(false);
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
      const entry = createEntry({
        id: uuidV4(),
        date: now,
        context,
        affirmationTitle: affirmation.title,
        text: text.trim(),
        audioRecordingId,
        createdAt: now,
      });
      await insertEntry(db, entry);
      // Best-effort background sync; UI doesn't wait.
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
          <Text style={styles.tally}>
            ☀️ {tally.opportunity}  ✓ {tally.didit}  🙏 {tally.grateful}
          </Text>
          <View style={{ width: 50 }} />
        </View>

        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ padding: 20, paddingBottom: 40 }}
          keyboardShouldPersistTaps="handled"
        >
          <TouchableOpacity
            onPress={() => setPicker(!picker)}
            style={styles.affirmationBlock}
          >
            <Text style={styles.affirmationTitle}>{affirmation.title}</Text>
            <Text style={styles.affirmationSubtitle}>{affirmation.subtitle}</Text>
            <Text style={styles.swapHint}>tap to choose a different one</Text>
          </TouchableOpacity>

          {picker && (
            <View style={styles.pickerBox}>
              {AFFIRMATIONS.map((a, i) => (
                <TouchableOpacity
                  key={a.title}
                  onPress={() => selectAffirmation(i)}
                  style={[
                    styles.pickerRow,
                    i === index && styles.pickerRowActive,
                  ]}
                >
                  <Text style={styles.pickerTitle}>{a.title}</Text>
                  <Text style={styles.pickerSubtitle}>{a.subtitle}</Text>
                </TouchableOpacity>
              ))}
            </View>
          )}

          <View style={styles.contextRow}>
            <ContextButton
              active={context === "opportunity"}
              label="🎯 Opportunity"
              onPress={() => setContext("opportunity")}
            />
            <ContextButton
              active={context === "didit"}
              label="✓ Did It"
              onPress={() => setContext("didit")}
            />
          </View>

          <Text style={styles.prompt}>{PROMPTS[context]}</Text>

          <TextInput
            style={styles.textInput}
            placeholder={PROMPTS[context]}
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
              context="AffirmationCard"
              extra={{
                affirmation: affirmation.title,
                ctx: context,
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

function ContextButton({
  active,
  label,
  onPress,
}: {
  active: boolean;
  label: string;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity
      onPress={onPress}
      style={[styles.contextBtn, active && styles.contextBtnActive]}
    >
      <Text
        style={[
          styles.contextBtnText,
          active && styles.contextBtnTextActive,
        ]}
      >
        {label}
      </Text>
    </TouchableOpacity>
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
  tally: { color: "#bbb", fontSize: 13, fontVariant: ["tabular-nums" as const] },
  affirmationBlock: {
    paddingVertical: 18,
    borderBottomColor: "#222",
    borderBottomWidth: 1,
  },
  affirmationTitle: {
    color: "#fff",
    fontSize: 24,
    fontWeight: "700" as const,
    textAlign: "center" as const,
  },
  affirmationSubtitle: {
    color: "#bbb",
    fontSize: 14,
    textAlign: "center" as const,
    marginTop: 6,
    fontStyle: "italic" as const,
  },
  swapHint: {
    color: "#666",
    fontSize: 11,
    textAlign: "center" as const,
    marginTop: 8,
  },
  pickerBox: {
    marginTop: 12,
    backgroundColor: "#111",
    borderRadius: 12,
    padding: 8,
  },
  pickerRow: { padding: 12, borderRadius: 8 },
  pickerRowActive: { backgroundColor: "#1f2a3a" },
  pickerTitle: { color: "#fff", fontSize: 16, fontWeight: "600" as const },
  pickerSubtitle: { color: "#999", fontSize: 12, marginTop: 2 },
  contextRow: {
    flexDirection: "row" as const,
    gap: 8,
    marginTop: 18,
  },
  contextBtn: {
    flex: 1,
    paddingVertical: 14,
    backgroundColor: "#1a1a1a",
    borderRadius: 10,
    alignItems: "center" as const,
  },
  contextBtnActive: { backgroundColor: "#0a4a8a" },
  contextBtnText: { color: "#aaa", fontSize: 15, fontWeight: "600" as const },
  contextBtnTextActive: { color: "#fff" },
  prompt: {
    color: "#888",
    fontSize: 14,
    marginTop: 16,
    fontStyle: "italic" as const,
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
