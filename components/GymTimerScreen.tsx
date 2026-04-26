import React, { useState, useCallback, useEffect, useRef } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
} from "react-native";
import { useKeepAwake } from "expo-keep-awake";
import { useTimer, type TimerProfile, type Phase } from "../lib/gym/useTimer";
import { useStopwatch, formatStopwatchTime } from "../lib/gym/useStopwatch";
import { useSets } from "../lib/gym/useSets";
import { useLiveActivity } from "../lib/gym/useLiveActivity";

// --- Types ---

type Mode = "rounds" | "stopwatch" | "sets";

type GymTimerScreenProps = {
  onExit: () => void;
  initialMode?: Mode;
  initialPreset?: string;
  autostart?: boolean;
  onIntentConsumed?: () => void;
};

// --- Presets ---

const PRESETS: { id: string; name: string; profile: TimerProfile }[] = [
  { id: "30sec", name: "30 SEC", profile: { name: "30sec", workTime: 30, restTime: 5, rounds: 6, cycles: 1, prepTime: 5 } },
  { id: "1min", name: "1 MIN", profile: { name: "1min", workTime: 60, restTime: 10, rounds: 5, cycles: 1, prepTime: 5 } },
  { id: "5-1", name: "5-1", profile: { name: "5-1", workTime: 300, restTime: 60, rounds: 3, cycles: 1, prepTime: 10 } },
];

// --- Helpers ---

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
}

function phaseColor(phase: Phase): string {
  switch (phase) {
    case "work": return "#4361ee";
    case "rest": return "#06d6a0";
    case "prep": return "#f77f00";
    case "done": return "#f72585";
    default: return "#e0e0e0";
  }
}

function phaseLabel(phase: Phase): string {
  switch (phase) {
    case "prep": return "GET READY";
    case "work": return "WORK";
    case "rest": return "REST";
    case "done": return "DONE!";
    default: return "";
  }
}

// --- Sub-components ---

function RoundsMode({ profile, onReset, autostart }: { profile: TimerProfile; onReset: () => void; autostart?: boolean }) {
  const { state, toggle, reset } = useTimer(profile);
  const autostartFiredRef = useRef(false);
  useEffect(() => {
    if (!autostart || autostartFiredRef.current) return;
    autostartFiredRef.current = true;
    toggle();
  }, [autostart, toggle]);
  const { start: laStart, update: laUpdate, stop: laStop } = useLiveActivity();
  const prevPhaseRef = useRef<Phase>("idle");
  const prevRoundRef = useRef(state.currentRound);
  const prevRunningRef = useRef(false);
  const prevPausedRef = useRef(false);
  // Snapshot timeLeft at boundaries so we don't need it in deps
  const timeLeftRef = useRef(state.timeLeft);
  timeLeftRef.current = state.timeLeft;

  // Manage Live Activity lifecycle. Fires on phase / round / running / paused
  // changes. Round changes are tracked separately so AppState foreground
  // catch-up across a full rest period (same phase, different round) still
  // reissues the LA update.
  useEffect(() => {
    const wasRunning = prevRunningRef.current;
    const wasPaused = prevPausedRef.current;
    const prevPhase = prevPhaseRef.current;
    const prevRound = prevRoundRef.current;
    prevPhaseRef.current = state.phase;
    prevRoundRef.current = state.currentRound;
    prevRunningRef.current = state.isRunning;
    prevPausedRef.current = state.isPaused;

    const endTimeMs = Date.now() + timeLeftRef.current * 1000;
    const roundLabel = `Round ${state.currentRound}/${state.totalRounds}`;

    if (state.phase === "done") {
      laStop("DONE!", `${state.totalRounds} rounds completed`);
    } else if (state.phase === "idle" && prevPhase !== "idle") {
      laStop();
    } else if (state.isPaused && !wasPaused && wasRunning) {
      laStop("PAUSED", roundLabel);
    } else if (state.isRunning && !wasRunning) {
      laStart(phaseLabel(state.phase) || "TIMER", roundLabel, endTimeMs);
    } else if (
      state.isRunning &&
      (state.phase !== prevPhase || state.currentRound !== prevRound)
    ) {
      laUpdate(phaseLabel(state.phase), roundLabel, endTimeMs);
    }
  }, [state.phase, state.isRunning, state.isPaused, state.currentRound, state.totalRounds, laStart, laUpdate, laStop]);

  // Cleanup on unmount
  useEffect(() => () => { laStop(); }, [laStop]);

  return (
    <View style={styles.modeContainer}>
      {state.phase !== "idle" && (
        <Text style={[styles.phaseText, { color: phaseColor(state.phase) }]}>
          {phaseLabel(state.phase)}
        </Text>
      )}
      <Text style={[styles.mainTime, { color: phaseColor(state.phase) }]}>
        {state.phase === "idle" ? formatTime(profile.workTime) : formatTime(state.timeLeft)}
      </Text>
      <Text style={styles.roundText}>
        Round {state.currentRound} of {state.totalRounds}
      </Text>
      <View style={styles.controlsRow}>
        <TouchableOpacity style={styles.resetBtn} onPress={() => { reset(); onReset(); }}>
          <Text style={styles.resetBtnText}>RESET</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.playBtn, state.isRunning && styles.stopBtn]}
          onPress={toggle}
        >
          <Text style={styles.playBtnText}>
            {state.isRunning ? "STOP" : state.isPaused ? "RESUME" : "START"}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function StopwatchMode() {
  const { state, toggle, reset, lap } = useStopwatch();
  const time = formatStopwatchTime(state.elapsedMs);

  return (
    <View style={styles.modeContainer}>
      <Text style={styles.mainTime}>
        {time.main}<Text style={styles.fractionText}>{time.fraction}</Text>
      </Text>
      <View style={styles.controlsRow}>
        <TouchableOpacity
          style={[styles.resetBtn, !state.isRunning && styles.disabledBtn]}
          onPress={lap}
          disabled={!state.isRunning}
        >
          <Text style={styles.resetBtnText}>LAP</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.playBtn, state.isRunning && styles.stopBtn]}
          onPress={toggle}
        >
          <Text style={styles.playBtnText}>{state.isRunning ? "STOP" : "START"}</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.resetBtn} onPress={reset}>
          <Text style={styles.resetBtnText}>RESET</Text>
        </TouchableOpacity>
      </View>
      {state.laps.length > 0 && (
        <View style={styles.lapList}>
          {state.laps.map((lapTime, i) => {
            const f = formatStopwatchTime(lapTime);
            return (
              <View key={i} style={styles.lapRow}>
                <Text style={styles.lapLabel}>Lap {state.laps.length - i}</Text>
                <Text style={styles.lapTime}>{f.main}{f.fraction}</Text>
              </View>
            );
          })}
        </View>
      )}
    </View>
  );
}

function SetsMode() {
  const { state, increment, undo, reset } = useSets(15);
  const { count, maxCount } = state;
  const isMaxed = count >= maxCount;

  // Build tally groups (5 per group)
  const fullGroups = Math.floor(count / 5);
  const remainder = count % 5;

  return (
    <View style={styles.modeContainer}>
      <TouchableOpacity
        style={styles.setsDisplay}
        onPress={!isMaxed ? increment : undefined}
        activeOpacity={0.7}
      >
        {count === 0 ? (
          <Text style={styles.setsPlaceholder}>TAP TO COUNT</Text>
        ) : (
          <View style={styles.tallyContainer}>
            {Array.from({ length: fullGroups }).map((_, gi) => (
              <View key={gi} style={styles.tallyGroup}>
                {Array.from({ length: 4 }).map((_, mi) => (
                  <View key={mi} style={styles.tallyMark} />
                ))}
                <View style={styles.tallyStrike} />
              </View>
            ))}
            {remainder > 0 && (
              <View style={styles.tallyGroup}>
                {Array.from({ length: remainder }).map((_, mi) => (
                  <View key={mi} style={styles.tallyMark} />
                ))}
              </View>
            )}
          </View>
        )}
        {isMaxed && <Text style={styles.maxText}>MAX REACHED!</Text>}
      </TouchableOpacity>
      <Text style={styles.setsCount}>{count}</Text>
      <View style={styles.controlsRow}>
        <TouchableOpacity
          style={[styles.resetBtn, count === 0 && styles.disabledBtn]}
          onPress={undo}
          disabled={count === 0}
        >
          <Text style={styles.resetBtnText}>UNDO</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.playBtn, isMaxed && styles.disabledBtn]}
          onPress={increment}
          disabled={isMaxed}
        >
          <Text style={styles.playBtnText}>+1</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.resetBtn, count === 0 && styles.disabledBtn]}
          onPress={reset}
          disabled={count === 0}
        >
          <Text style={styles.resetBtnText}>RESET</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

// --- Main Screen ---

export default function GymTimerScreen({
  onExit,
  initialMode,
  initialPreset,
  autostart,
  onIntentConsumed,
}: GymTimerScreenProps) {
  useKeepAwake();
  const [mode, setMode] = useState<Mode>(initialMode ?? "rounds");
  const initialPresetIsValid = initialPreset != null && PRESETS.some(p => p.id === initialPreset);
  const [activePreset, setActivePreset] = useState(
    initialPresetIsValid ? initialPreset! : "30sec",
  );

  // Consume the intent once so re-opens from deep links don't replay stale state.
  const intentConsumedRef = useRef(false);
  useEffect(() => {
    if (intentConsumedRef.current) return;
    intentConsumedRef.current = true;
    onIntentConsumed?.();
  }, [onIntentConsumed]);

  const currentProfile = PRESETS.find(p => p.id === activePreset)?.profile ?? PRESETS[0].profile;

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={onExit} style={styles.exitBtn}>
          <Text style={styles.exitText}>Done</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Gym Timer</Text>
        <View style={{ width: 50 }} />
      </View>

      {/* Presets (only in rounds mode) */}
      {mode === "rounds" && (
        <View style={styles.presetRow}>
          {PRESETS.map(p => (
            <TouchableOpacity
              key={p.id}
              style={[styles.presetBtn, activePreset === p.id && styles.presetActive]}
              onPress={() => setActivePreset(p.id)}
            >
              <Text style={[styles.presetText, activePreset === p.id && styles.presetTextActive]}>
                {p.name}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

      {/* Mode content */}
      <View style={styles.content}>
        {mode === "rounds" && <RoundsMode profile={currentProfile} onReset={() => {}} autostart={autostart} />}
        {mode === "stopwatch" && <StopwatchMode />}
        {mode === "sets" && <SetsMode />}
      </View>

      {/* Bottom nav */}
      <View style={styles.bottomNav}>
        {(["rounds", "stopwatch", "sets"] as Mode[]).map(m => (
          <TouchableOpacity
            key={m}
            style={[styles.navItem, mode === m && styles.navItemActive]}
            onPress={() => setMode(m)}
          >
            <Text style={[styles.navText, mode === m && styles.navTextActive]}>
              {m.toUpperCase()}
            </Text>
          </TouchableOpacity>
        ))}
      </View>
    </SafeAreaView>
  );
}

// --- Styles ---

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: "#16213e",
  },
  exitBtn: { padding: 4 },
  exitText: { color: "#4361ee", fontSize: 16, fontWeight: "600" },
  headerTitle: { color: "#e0e0e0", fontSize: 18, fontWeight: "700" },
  presetRow: {
    flexDirection: "row",
    justifyContent: "center",
    gap: 8,
    paddingVertical: 12,
  },
  presetBtn: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: "#16213e",
  },
  presetActive: { backgroundColor: "#4361ee" },
  presetText: { color: "#888", fontSize: 13, fontWeight: "600" },
  presetTextActive: { color: "#fff" },
  content: { flex: 1, justifyContent: "center", alignItems: "center" },
  modeContainer: { alignItems: "center", width: "100%", paddingHorizontal: 24 },
  phaseText: { fontSize: 18, fontWeight: "700", marginBottom: 8 },
  mainTime: { fontSize: 72, fontWeight: "200", color: "#e0e0e0", fontVariant: ["tabular-nums"] },
  fractionText: { fontSize: 36, color: "#888" },
  roundText: { color: "#888", fontSize: 16, marginTop: 8 },
  controlsRow: {
    flexDirection: "row",
    gap: 16,
    marginTop: 32,
    alignItems: "center",
  },
  playBtn: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: "#4361ee",
    justifyContent: "center",
    alignItems: "center",
  },
  stopBtn: { backgroundColor: "#e63946" },
  playBtnText: { color: "#fff", fontSize: 16, fontWeight: "700" },
  resetBtn: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: "#16213e",
  },
  resetBtnText: { color: "#888", fontSize: 14, fontWeight: "600" },
  disabledBtn: { opacity: 0.3 },
  lapList: { marginTop: 24, width: "100%" },
  lapRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: "#16213e",
  },
  lapLabel: { color: "#888", fontSize: 14 },
  lapTime: { color: "#e0e0e0", fontSize: 14, fontVariant: ["tabular-nums"] },
  setsDisplay: {
    minHeight: 200,
    justifyContent: "center",
    alignItems: "center",
    width: "100%",
  },
  setsPlaceholder: { color: "#555", fontSize: 24, fontWeight: "600" },
  setsCount: { color: "#e0e0e0", fontSize: 48, fontWeight: "700", marginTop: 12 },
  maxText: { color: "#f72585", fontSize: 16, fontWeight: "700", marginTop: 8 },
  tallyContainer: { flexDirection: "row", flexWrap: "wrap", gap: 16, justifyContent: "center" },
  tallyGroup: {
    flexDirection: "row",
    gap: 4,
    alignItems: "center",
    position: "relative",
  },
  tallyMark: {
    width: 4,
    height: 40,
    backgroundColor: "#4cc9f0",
    borderRadius: 2,
  },
  tallyStrike: {
    position: "absolute",
    width: "120%",
    height: 3,
    backgroundColor: "#4cc9f0",
    top: "45%",
    left: "-10%",
    transform: [{ rotate: "-30deg" }],
  },
  bottomNav: {
    flexDirection: "row",
    borderTopWidth: 1,
    borderTopColor: "#16213e",
    paddingBottom: 8,
  },
  navItem: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 12,
  },
  navItemActive: { borderTopWidth: 2, borderTopColor: "#4361ee" },
  navText: { color: "#555", fontSize: 12, fontWeight: "600" },
  navTextActive: { color: "#4361ee" },
});
