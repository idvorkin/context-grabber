import React, {
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { activateKeepAwakeAsync, deactivateKeepAwake } from "expo-keep-awake";
import { CopyableError } from "../components/CopyableError";
import {
  BACKENDS,
  endingText,
  type CallBackend,
} from "../lib/callProtocol";
import type { CallSession, CallSnapshot, CaptionRow } from "../lib/callSession";
import AudioRoute, { type AudioRouteSnapshot } from "../modules/audio-route";

/**
 * The Call tab: a Larry call with no web page in it, so it keeps going when
 * the screen locks. The screen is the conversation and nothing else — the
 * Cockpit's own rules for a live call (DESIGN P23/P24): captions, short
 * speaker labels, no turn numbers, consults clamped.
 *
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md
 */

type Props = {
  session: CallSession;
  backend: CallBackend;
  onBackendChange: (backend: CallBackend) => void;
  /** A call is live on the Cockpit *page*; two microphones on one phone is a no. */
  cockpitCallLive: boolean;
};

/** Tagged so it can never collide with the Gym Timer's or the Cockpit tab's hold. */
const KEEP_AWAKE_TAG = "call";

const LABEL: Record<CaptionRow["who"], string> = {
  igor: "Igor",
  larry: "Larry",
  tool: "⟳",
  note: "·",
};

const LABEL_A11Y: Record<CaptionRow["who"], string> = {
  igor: "Igor",
  larry: "Larry",
  tool: "consult",
  note: "note",
};

export function useCallSnapshot(session: CallSession): CallSnapshot {
  const subscribe = useCallback((cb: () => void) => session.subscribe(cb), [session]);
  return useSyncExternalStore(subscribe, () => session.snapshot, () => session.snapshot);
}

function formatElapsed(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const mm = h ? String(m).padStart(2, "0") : String(m);
  return `${h ? `${h}:` : ""}${mm}:${String(s).padStart(2, "0")}`;
}

export function CallScreen({ session, backend, onBackendChange, cockpitCallLive }: Props) {
  const snap = useCallSnapshot(session);
  const active = snap.state === "connecting" || snap.state === "live";

  /* ---------- keep the screen awake while the call is live ----------
     The call no longer depends on this — that is the point of the tab — but
     reading captions with the screen going dark is still a bad call. Held
     only while this tab is showing: the screen unmounts when another tab is
     chosen, and the effect's cleanup releases it. */
  useEffect(() => {
    if (!active) return;
    void Promise.resolve(activateKeepAwakeAsync(KEEP_AWAKE_TAG)).catch(() => {});
    return () => {
      void Promise.resolve(deactivateKeepAwake(KEEP_AWAKE_TAG)).catch(() => {});
    };
  }, [active]);

  /* ---------- timer ---------- */
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (snap.state !== "live") return;
    setNow(Date.now());
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [snap.state]);

  /* ---------- devices ----------
     The real roster, straight from the audio session — the thing the Cockpit
     needed a whole bridge to see. Read when the tab opens and again whenever
     iOS moves the route (AirPods on, a cable out, the web view elsewhere). */
  const [route, setRoute] = useState<AudioRouteSnapshot | null>(null);
  useEffect(() => {
    if (!AudioRoute) return;
    let cancelled = false;
    AudioRoute.activate()
      .then((s) => {
        if (!cancelled) setRoute(s);
      })
      .catch(() => {});
    const sub = AudioRoute.addListener("onRouteChange", (change) => {
      setRoute(change);
    });
    return () => {
      cancelled = true;
      sub.remove();
    };
  }, []);

  const pickInput = useCallback((id: string) => {
    if (!AudioRoute) return;
    AudioRoute.setInput(id).then(setRoute).catch(() => {});
  }, []);
  const pickOutput = useCallback((id: string) => {
    if (!AudioRoute) return;
    AudioRoute.setOutput(id).then(setRoute).catch(() => {});
  }, []);

  /* ---------- captions scroll ---------- */
  const scrollRef = useRef<ScrollView>(null);
  useEffect(() => {
    scrollRef.current?.scrollToEnd({ animated: true });
  }, [snap.captions]);

  const [expanded, setExpanded] = useState<Set<number>>(() => new Set());
  const toggleExpanded = useCallback((id: number) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const backendLabel = BACKENDS.find((b) => b.id === (snap.backend ?? backend))?.label ?? "";

  let status: string;
  if (snap.state === "connecting") status = `connecting… ${backendLabel}`;
  else if (snap.state === "live") status = `live · ${formatElapsed(now - (snap.startedAt ?? now))} · ${backendLabel}`;
  else if (snap.state === "ended") status = `ended — ${endingText(snap.endedReason)}`;
  else status = "";

  const startBlocked = cockpitCallLive ? "a call is live in the Cockpit tab" : null;

  return (
    <View style={styles.container} testID="call-screen">
      <View style={styles.header}>
        <Text style={styles.title}>Call</Text>
        <Text
          style={[styles.status, snap.state === "live" && styles.statusLive, snap.endedBadly && styles.statusBad]}
          testID="call-status"
          numberOfLines={1}
        >
          {status}
        </Text>
      </View>

      {/* backend — pickable only between calls */}
      <View style={styles.chipRow} testID="call-backends">
        {BACKENDS.map((b) => {
          const selected = (active ? snap.backend : backend) === b.id;
          return (
            <Pressable
              key={b.id}
              onPress={() => !active && onBackendChange(b.id)}
              disabled={active}
              style={[styles.chip, selected && styles.chipSelected, active && !selected && styles.chipDisabled]}
              testID={`call-backend-${b.id}`}
              accessibilityRole="radio"
              accessibilityState={{ selected, disabled: active }}
            >
              <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{b.label}</Text>
            </Pressable>
          );
        })}
      </View>

      {route && (route.inputs.length > 1 || route.outputs.length > 1) && (
        <View style={styles.devices} testID="call-devices">
          {route.inputs.length > 1 && (
            <DeviceRow
              label="Mic"
              devices={route.inputs}
              currentId={route.current.input?.id ?? null}
              onPick={pickInput}
              testID="call-inputs"
            />
          )}
          {route.outputs.length > 1 && (
            <DeviceRow
              label="Out"
              devices={route.outputs}
              currentId={route.current.output?.id ?? null}
              onPick={pickOutput}
              testID="call-outputs"
            />
          )}
        </View>
      )}

      <ScrollView
        ref={scrollRef}
        style={styles.captions}
        contentContainerStyle={styles.captionsContent}
        testID="call-captions"
      >
        {snap.captions.map((row) => {
          if (!row.text) return null;
          const clamped = row.who === "tool" && !expanded.has(row.id);
          return (
            <Pressable
              key={row.id}
              onPress={row.who === "tool" ? () => toggleExpanded(row.id) : undefined}
              disabled={row.who !== "tool"}
              style={styles.row}
              testID={`call-row-${row.who}-${row.id}`}
            >
              <Text
                style={[styles.who, styles[`who_${row.who}`]]}
                accessibilityLabel={LABEL_A11Y[row.who]}
              >
                {LABEL[row.who]}
              </Text>
              <Text
                style={[styles.words, row.pending && styles.wordsPending, row.who !== "igor" && row.who !== "larry" && styles.wordsMuted]}
                numberOfLines={clamped ? 3 : undefined}
              >
                {row.text}
              </Text>
            </Pressable>
          );
        })}
        {snap.captions.every((r) => !r.text) && (
          <Text style={styles.empty}>
            {snap.state === "live"
              ? "Say hello."
              : snap.state === "connecting"
                ? "Reaching the bridge…"
                : "Larry, over the tailnet. The call keeps going when the phone locks."}
          </Text>
        )}
      </ScrollView>

      {snap.problem && (
        <CopyableError
          message={snap.problem}
          context="CallScreen.call"
          extra={{ state: snap.state, backend: snap.backend }}
          style={styles.problem}
        />
      )}
      {snap.state === "ended" && snap.endedBadly && snap.endedReason && (
        <CopyableError
          message={snap.endedReason}
          context="CallScreen.ended"
          extra={{ backend: snap.backend }}
          style={styles.problem}
        />
      )}

      <View style={styles.controls}>
        {active ? (
          <>
            <Pressable
              onPress={() => session.setMuted(!snap.muted)}
              style={[styles.button, styles.buttonSecondary, snap.muted && styles.buttonMuted]}
              testID="call-mute"
              accessibilityRole="button"
              accessibilityState={{ selected: snap.muted }}
              accessibilityLabel={snap.muted ? "Unmute" : "Mute"}
            >
              <Text style={styles.buttonText}>{snap.muted ? "Unmute" : "Mute"}</Text>
            </Pressable>
            <Pressable
              onPress={() => session.stop()}
              style={[styles.button, styles.buttonHangup]}
              testID="call-hangup"
              accessibilityRole="button"
              accessibilityLabel="Hang up"
            >
              <Text style={styles.buttonText}>Hang up</Text>
            </Pressable>
          </>
        ) : (
          <View style={styles.startWrap}>
            <Pressable
              onPress={() => void session.start(backend)}
              disabled={!!startBlocked}
              style={[styles.button, styles.buttonStart, startBlocked && styles.buttonDisabled]}
              testID="call-start"
              accessibilityRole="button"
              accessibilityState={{ disabled: !!startBlocked }}
              accessibilityLabel="Call Larry"
            >
              <Text style={styles.buttonText}>Call Larry</Text>
            </Pressable>
            {startBlocked && (
              <Text style={styles.blocked} testID="call-blocked">
                {startBlocked}
              </Text>
            )}
          </View>
        )}
      </View>
    </View>
  );
}

function DeviceRow({
  label,
  devices,
  currentId,
  onPick,
  testID,
}: {
  label: string;
  devices: AudioRouteSnapshot["inputs"];
  currentId: string | null;
  onPick: (id: string) => void;
  testID: string;
}) {
  return (
    <View style={styles.deviceRow} testID={testID}>
      <Text style={styles.deviceLabel}>{label}</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.deviceChips}>
        {devices.map((d) => {
          const selected = d.id === currentId;
          return (
            <Pressable
              key={d.id}
              onPress={() => onPick(d.id)}
              style={[styles.chip, styles.chipSmall, selected && styles.chipSelected]}
              accessibilityRole="radio"
              accessibilityState={{ selected }}
              testID={`${testID}-${d.id}`}
            >
              <Text style={[styles.chipText, selected && styles.chipTextSelected]} numberOfLines={1}>
                {d.name}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: {
    paddingHorizontal: 16,
    paddingTop: 60,
    paddingBottom: 10,
    backgroundColor: "#0c121f",
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#222",
    gap: 2,
  },
  title: { color: "#eee", fontSize: 20, fontWeight: "700" },
  status: { color: "#888", fontSize: 13, fontVariant: ["tabular-nums"] },
  statusLive: { color: "#4ade80" },
  statusBad: { color: "#f87171" },
  chipRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  chip: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    backgroundColor: "#243447",
  },
  chipSmall: { paddingHorizontal: 10, paddingVertical: 4 },
  chipSelected: { backgroundColor: "#4cc9f0" },
  chipDisabled: { opacity: 0.4 },
  chipText: { color: "#cbd5e1", fontSize: 13, fontWeight: "600" },
  chipTextSelected: { color: "#0c121f" },
  devices: { paddingHorizontal: 16, gap: 6, paddingBottom: 6 },
  deviceRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  deviceLabel: { color: "#888", fontSize: 12, width: 28 },
  deviceChips: { gap: 6 },
  captions: { flex: 1 },
  captionsContent: { paddingHorizontal: 16, paddingVertical: 12, gap: 10 },
  row: { flexDirection: "row", gap: 10, alignItems: "flex-start" },
  who: { width: 44, fontSize: 13, fontWeight: "700", textAlign: "right", lineHeight: 20 },
  who_igor: { color: "#4cc9f0" },
  who_larry: { color: "#fbbf24" },
  who_tool: { color: "#a78bfa" },
  who_note: { color: "#64748b" },
  words: { flex: 1, color: "#eee", fontSize: 16, lineHeight: 22 },
  wordsPending: { color: "#94a3b8", fontStyle: "italic" },
  wordsMuted: { color: "#94a3b8", fontSize: 14, lineHeight: 20 },
  empty: { color: "#666", fontSize: 14, lineHeight: 20, paddingTop: 20 },
  problem: { marginHorizontal: 16 },
  controls: {
    flexDirection: "row",
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "#222",
    backgroundColor: "#0c121f",
  },
  startWrap: { flex: 1, gap: 6 },
  button: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 16,
    borderRadius: 12,
  },
  buttonStart: { backgroundColor: "#16a34a" },
  buttonSecondary: { backgroundColor: "#243447" },
  buttonMuted: { backgroundColor: "#b45309" },
  buttonHangup: { backgroundColor: "#dc2626" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontSize: 17, fontWeight: "700" },
  blocked: { color: "#f87171", fontSize: 13, textAlign: "center" },
});
