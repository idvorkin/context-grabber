import React, { useState, useCallback, useEffect, useRef } from "react";
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
} from "react-native";
import { useKeepAwake } from "expo-keep-awake";
import * as Clipboard from "expo-clipboard";
import { buildLabel } from "../lib/version";
import { timerLog } from "../lib/gym/timerLog";
import { TimerFace, TurnedTimer, LED, ledColorFor } from "./TimerFace";
import { ledPhaseWord } from "../lib/gym/sevenSegment";
import { useDeviceTurn } from "../lib/gym/useDeviceTurn";
import {
  CUSTOM_PRESET_ID,
  REST_RANGE,
  ROUNDS_RANGE,
  STEP_SECONDS,
  WORK_RANGE,
  customProfile,
  formatSeconds,
  type CustomPreset,
} from "../lib/gym/customPreset";
import { loadChosenPreset, loadCustomPreset, saveChosenPreset, saveCustomPreset } from "../lib/gym/customPresetStorage";
import { StepSlider } from "./StepSlider";
import type { Turn } from "../lib/gym/deviceTurn";
import { useTimer, type TimerProfile, type Phase } from "../lib/gym/useTimer";
import { useStopwatch, formatStopwatchTime } from "../lib/gym/useStopwatch";
import { useSets } from "../lib/gym/useSets";
import { useLiveActivity } from "../lib/gym/useLiveActivity";
import { configureAudioSessionForBackground } from "../lib/gym/keepalive";

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
  { id: "2min", name: "2 MIN", profile: { name: "2min", workTime: 120, restTime: 15, rounds: 4, cycles: 1, prepTime: 10 } },
  { id: "5-1", name: "5-1", profile: { name: "5-1", workTime: 300, restTime: 60, rounds: 3, cycles: 1, prepTime: 10 } },
];
/** The fifth chip: its profile comes from the remembered sliders (lib/gym/customPreset.ts). */
const CUSTOM_CHIP = { id: CUSTOM_PRESET_ID, name: "CUSTOM" };
const PRESET_IDS = [...PRESETS.map((p) => p.id), CUSTOM_CHIP.id];

// --- Helpers ---

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
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

type CustomControls = { value: CustomPreset; onChange: (next: CustomPreset) => void };

function RoundsMode({ profile, onReset, autostart, turn, custom }: { profile: TimerProfile; onReset: () => void; autostart?: boolean; turn: Turn; custom?: CustomControls }) {
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

  const face = {
    word: ledPhaseWord(state.phase),
    time: state.phase === "idle" ? formatTime(profile.workTime) : formatTime(state.timeLeft),
    color: ledColorFor(state.phase),
    sub: `Round ${state.currentRound} of ${state.totalRounds}`,
  };
  if (turn !== "upright") {
    return <TurnedTimer {...face} turn={turn} onTap={toggle} hint={state.isRunning ? "tap to stop" : "tap to start"} />;
  }
  // The Custom preset's controls: live while idle, dim and inert once running or paused.
  const locked = state.isRunning || state.isPaused;
  return (
    <View style={styles.modeContainer}>
      {custom && (
        <View style={styles.customControls} testID="custom-controls">
          <StepSlider label="Work" value={custom.value.work} min={WORK_RANGE.min} max={WORK_RANGE.max} step={STEP_SECONDS} format={formatSeconds} disabled={locked} onChange={(work) => custom.onChange({ ...custom.value, work })} testID="custom-work" />
          <StepSlider label="Rest" value={custom.value.rest} min={REST_RANGE.min} max={REST_RANGE.max} step={STEP_SECONDS} format={formatSeconds} disabled={locked} onChange={(rest) => custom.onChange({ ...custom.value, rest })} testID="custom-rest" />
          <StepSlider label="Rounds" value={custom.value.rounds} min={ROUNDS_RANGE.min} max={ROUNDS_RANGE.max} step={1} disabled={locked} onChange={(rounds) => custom.onChange({ ...custom.value, rounds })} testID="custom-rounds" />
        </View>
      )}
      <TimerFace {...face} maxHeight={150} testID="timer-face" />
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

function StopwatchMode({ turn }: { turn: Turn }) {
  const { state, toggle, reset, lap } = useStopwatch();
  const time = formatStopwatchTime(state.elapsedMs);
  const face = { time: time.main, fraction: time.fraction, color: state.isRunning ? LED.red : LED.white };
  if (turn !== "upright") {
    return <TurnedTimer {...face} turn={turn} onTap={toggle} hint={state.isRunning ? "tap to stop" : "tap to start"} />;
  }

  return (
    <View style={styles.modeContainer}>
      <TimerFace {...face} maxHeight={130} testID="timer-face" />
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

function SetsMode({ turn }: { turn: Turn }) {
  const { state, increment, undo, reset } = useSets(15);
  const { count, maxCount } = state;
  const isMaxed = count >= maxCount;
  const face = { time: String(count), color: LED.green };
  const maxed = isMaxed ? "max reached" : undefined;
  if (turn !== "upright") {
    return <TurnedTimer {...face} sub={maxed} turn={turn} onTap={() => { if (!isMaxed) increment(); }} hint={maxed ?? "tap to count"} />;
  }

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
      <TimerFace {...face} maxHeight={90} testID="timer-face" />
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
  // Configure the iOS audio session for `playback` BEFORE any audio plays so
  // the first beep / silent loop runs in the correct background-eligible
  // category. Idempotent — safe to call on every mount.
  useEffect(() => {
    configureAudioSessionForBackground();
  }, []);
  const [mode, setMode] = useState<Mode>(initialMode ?? "rounds");
  const initialPresetIsValid = initialPreset != null && PRESET_IDS.includes(initialPreset);
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

  // Custom: the sliders' values, remembered — and which chip was chosen, unless a link chose one.
  const [custom, setCustom] = useState<CustomPreset | null>(null);
  useEffect(() => {
    void loadCustomPreset().then(setCustom);
    if (initialPreset == null) {
      void loadChosenPreset().then((id) => {
        if (id && PRESET_IDS.includes(id)) setActivePreset(id);
      });
    }
  }, [initialPreset]);
  const choosePreset = useCallback((id: string) => {
    setActivePreset(id);
    void saveChosenPreset(id);
  }, []);
  const changeCustom = useCallback((next: CustomPreset) => {
    setCustom(next);
    void saveCustomPreset(next);
  }, []);
  const customControls: CustomControls | undefined =
    activePreset === CUSTOM_PRESET_ID && custom ? { value: custom, onChange: changeCustom } : undefined;
  const currentProfile =
    activePreset === CUSTOM_PRESET_ID
      ? customProfile(custom ?? { work: 60, rest: 10, rounds: 5 })
      : (PRESETS.find(p => p.id === activePreset)?.profile ?? PRESETS[0].profile);
  // Which way the phone is held. Turned, the mode fills the screen sideways and
  // the chrome goes; the mode components stay where they are in the tree so
  // their timers survive the turn.
  const turn = useDeviceTurn();
  const turned = turn !== "upright";
  // Copy log: the audio session's and the duck window's doings, behind a build header.
  const [logCopied, setLogCopied] = useState(false);
  const copyLog = useCallback(async () => {
    await Clipboard.setStringAsync(timerLog.render({ build: buildLabel(), mode, preset: mode === "rounds" ? activePreset : undefined }));
    setLogCopied(true);
    setTimeout(() => setLogCopied(false), 1500);
  }, [mode, activePreset]);

  return (
    <SafeAreaView style={styles.container} testID={turned ? "timer-screen-turned" : "timer-screen-upright"}>
      {/* Header */}
      {!turned && <View style={styles.header}>
        <TouchableOpacity onPress={onExit} style={styles.exitBtn}>
          <Text style={styles.exitText}>Done</Text>
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Gym Timer</Text>
        <TouchableOpacity onPress={() => void copyLog()} style={styles.exitBtn} testID="timer-copy-log" accessibilityLabel="Copy timer log">
          <Text style={styles.logText}>{logCopied ? "Copied" : "Log"}</Text>
        </TouchableOpacity>
      </View>}

      {/* Presets (only in rounds mode) */}
      {!turned && mode === "rounds" && (
        <View style={styles.presetRow}>
          {[...PRESETS, CUSTOM_CHIP].map(p => (
            <TouchableOpacity
              key={p.id}
              style={[styles.presetBtn, activePreset === p.id && styles.presetActive]}
              onPress={() => choosePreset(p.id)}
              testID={`preset-${p.id}`}
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
        {mode === "rounds" && <RoundsMode profile={currentProfile} onReset={() => {}} autostart={autostart} turn={turn} custom={customControls} />}
        {mode === "stopwatch" && <StopwatchMode turn={turn} />}
        {mode === "sets" && <SetsMode turn={turn} />}
      </View>

      {/* Bottom nav */}
      {!turned && <View style={styles.bottomNav}>
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
      </View>}
    </SafeAreaView>
  );
}

// --- Styles ---

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#000" },
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
  logText: { color: "#555", fontSize: 14, fontWeight: "600", minWidth: 50, textAlign: "right" },
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
  customControls: { width: "100%", marginBottom: 8 },
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
