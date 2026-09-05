import React, {
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import {
  AccessibilityInfo,
  Animated,
  Easing,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { activateKeepAwakeAsync, deactivateKeepAwake } from "expo-keep-awake";
import { CopyableError } from "../components/CopyableError";
import * as Clipboard from "expo-clipboard";
import { describeRoute, offeredOutputs, preferredInput } from "../lib/callDevices";
import type { CallLog } from "../lib/callLog";
import { DEFAULT_VOICE, VOICES, hasVoicePick, voiceLabel, type CallVoice } from "../lib/callVoices";
import { getBuildInfo } from "../lib/version";
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
  /** The call's log; shown under Diagnostics and copied from there. */
  log: CallLog;
  backend: CallBackend;
  onBackendChange: (backend: CallBackend) => void;
  /** The voice the call answers in — Tony or Igor (#98). */
  voice?: CallVoice;
  onVoiceChange?: (voice: CallVoice) => void;
  /** Upload the log as a private gist; resolves with the URL. Absent = no token saved, no button. */
  onUpload?: () => Promise<string>;
  /** The last upload's URL, shown under the buttons. */
  lastUploadUrl?: string | null;
  /** A call is live on the Cockpit *page*; two microphones on one phone is a no. */
  cockpitCallLive: boolean;
  /** The Cockpit web view exists in this app session (it may hold a mic). Logged per call for #88. */
  cockpitMounted?: boolean;
};

/** Tagged so it can never collide with the Gym Timer's or the Cockpit tab's hold. */
const KEEP_AWAKE_TAG = "call";

/** How long iOS gets to apply a route pick before the picker re-reads it. */
const ROUTE_REFRESH_MS = 400;

/** The level disc falls at this rate per frame so a word leaves a visible trace. */
const METER_DECAY = 0.85;

/** The voice control's circle, and the level disc inside it at silence and at full voice. */
const VOICE_SIZE = 34;
const VOICE_DISC_MIN = 14;
const VOICE_DISC_MAX = VOICE_SIZE;

/** The hang-up is the biggest thing on the screen: a thumb finds it without looking. */
const HANGUP_SIZE = 34;

/** One outward pulse of the calling ring; the second ring runs half a period behind. */
const PULSE_MS = 1600;

/** A telephone (U+260E) with the text-presentation selector — not the emoji, so it takes our colour. */
const HANDSET = "\u260E\uFE0E";

/** The voice is Tony; Larry is the reasoning half behind him (#94). */
const LABEL: Record<CaptionRow["who"], string> = {
  igor: "Igor",
  larry: "Tony",
  tool: "⟳",
  note: "Larry",
};

const LABEL_A11Y: Record<CaptionRow["who"], string> = {
  igor: "Igor",
  larry: "Tony",
  tool: "consult",
  note: "Larry (context)",
};

export function useCallSnapshot(session: CallSession): CallSnapshot {
  const subscribe = useCallback((cb: () => void) => session.subscribe(cb), [session]);
  return useSyncExternalStore(subscribe, () => session.snapshot, () => session.snapshot);
}

/** iOS's Reduce Motion, live: the calling ring holds still when it is on. */
function useReduceMotion(): boolean {
  const [reduce, setReduce] = useState(false);
  useEffect(() => {
    let cancelled = false;
    AccessibilityInfo.isReduceMotionEnabled()
      .then((v) => {
        if (!cancelled) setReduce(v);
      })
      .catch(() => {});
    const sub = AccessibilityInfo.addEventListener("reduceMotionChanged", setReduce);
    return () => {
      cancelled = true;
      sub.remove();
    };
  }, []);
  return reduce;
}

function formatElapsed(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const mm = h ? String(m).padStart(2, "0") : String(m);
  return `${h ? `${h}:` : ""}${mm}:${String(s).padStart(2, "0")}`;
}

export function CallScreen({
  session,
  log,
  backend,
  onBackendChange,
  voice = DEFAULT_VOICE,
  onVoiceChange,
  onUpload,
  lastUploadUrl = null,
  cockpitCallLive,
  cockpitMounted = false,
}: Props) {
  const snap = useCallSnapshot(session);
  const active = snap.state === "connecting" || snap.state === "live";
  const reduceMotion = useReduceMotion();

  /* ---------- the voice ----------
     Tony or Igor (#98). Only ElevenLabs (and the drill) have a voice to
     pick; the name rides the status line and the devices line so a call in
     the wrong voice is visible without opening anything. */
  const voicedBackend = hasVoicePick(active ? snap.backend : backend);
  const pickedVoice: CallVoice = active ? snap.voice : voice;
  const pickedVoiceName = voicedBackend ? voiceLabel(pickedVoice) : "";

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
      log.add(`route change (${change.reason}): ${describeRoster(change)}`);
      setRoute(change);
    });
    return () => {
      cancelled = true;
      sub.remove();
    };
  }, [log]);

  /* ---------- a USB microphone wins ----------
     Igor: "If a mic is over USB, let's take that as a default." Applied
     whenever the roster changes — at the start of a call, or when the mic is
     plugged in during one — unless Igor picked a mic by hand this call, in
     which case his choice stands until the next call. */
  const manualInputPick = useRef(false);
  useEffect(() => {
    if (!active) manualInputPick.current = false;
  }, [active]);
  useEffect(() => {
    // Only while a call is live or connecting: opening the tab idle must not
    // move the system's preferred input.
    if (!active || !route || !AudioRoute || manualInputPick.current) return;
    const wanted = preferredInput(route);
    if (!wanted) return;
    const module = AudioRoute;
    // Only the microphone. iOS sends playback to a USB device that was just
    // chosen as the input; a mic receiver has no speaker. Put the output
    // back where it was.
    const before = route.current.output;
    log.add(`USB mic ${wanted} present → making it the mic (output stays ${before?.name ?? "auto"})`);
    module
      .setInput(wanted)
      .then((after) => {
        const moved = after.current.output?.id !== before?.id;
        if (!moved || !before) return after;
        const restore = before.type === "Speaker" ? "speaker" : before.id;
        log.add(`output moved to ${after.current.output?.name ?? "?"} → restoring ${before.name}`);
        return module.setOutput(restore);
      })
      .then(setRoute)
      .catch((e) => log.add(`USB default failed: ${e instanceof Error ? e.message : String(e)}`));
  }, [active, route, log]);

  const [devicesOpen, setDevicesOpen] = useState(false);

  // iOS applies a route pick asynchronously; the snapshot the call returns
  // can still show the old route. Read it again once the change has landed
  // so the chip moves even when no route-change event reaches us.
  const refreshLater = useRef<ReturnType<typeof setTimeout> | null>(null);
  const refreshRoute = useCallback(() => {
    if (refreshLater.current) clearTimeout(refreshLater.current);
    refreshLater.current = setTimeout(() => {
      refreshLater.current = null;
      if (!AudioRoute) return;
      try {
        setRoute(AudioRoute.getDevices());
      } catch {
        // session not ready; the next route-change event will say
      }
    }, ROUTE_REFRESH_MS);
  }, []);
  useEffect(
    () => () => {
      if (refreshLater.current) clearTimeout(refreshLater.current);
    },
    [],
  );
  const pickInput = useCallback(
    (id: string) => {
      if (!AudioRoute) return;
      manualInputPick.current = true;
      log.add(`pick mic ${id}`);
      AudioRoute.setInput(id).then(setRoute).catch((e) => log.add(`pick mic failed: ${String(e)}`));
      refreshRoute();
    },
    [refreshRoute, log],
  );
  const pickOutput = useCallback(
    (id: string) => {
      if (!AudioRoute) return;
      log.add(`pick output ${id}`);
      AudioRoute.setOutput(id).then(setRoute).catch((e) => log.add(`pick output failed: ${String(e)}`));
      refreshRoute();
    },
    [refreshRoute, log],
  );

  /* ---------- diagnostics ---------- */
  const [diagOpen, setDiagOpen] = useState(false);
  const [logLines, setLogLines] = useState<readonly string[]>(() => log.all);
  useEffect(() => log.subscribe((lines) => setLogLines([...lines])), [log]);
  const [copied, setCopied] = useState(false);
  const copiedTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(
    () => () => {
      if (copiedTimer.current) clearTimeout(copiedTimer.current);
    },
    [],
  );
  const copyDiagnostics = useCallback(async () => {
    const build = getBuildInfo();
    const text = log.render({
      build: `${build.shortSha} (${build.branch})`,
      state: snap.state,
      backend: snap.backend,
      ended: snap.endedReason,
      problem: snap.problem,
      route: route ? describeRoster(route) : "unknown",
    });
    try {
      await Clipboard.setStringAsync(text);
      setCopied(true);
      if (copiedTimer.current) clearTimeout(copiedTimer.current);
      copiedTimer.current = setTimeout(() => setCopied(false), 1500);
    } catch {
      // clipboard unavailable — the lines are still on screen
    }
  }, [log, snap, route]);

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

  // The live line: Igor's words as the recognizer still hears them, out of
  // the transcript and into a big box under the call line. The session
  // already keeps them as the one pending Igor row; the screen just moves it.
  const liveRow = snap.captions.find((r) => r.who === "igor" && r.pending) ?? null;
  const transcript = snap.captions.filter((r) => r !== liveRow);

  const backendLabel = BACKENDS.find((b) => b.id === (snap.backend ?? backend))?.label ?? "";
  // The voice's name rides the status line so a call in the wrong voice is visible (#98).
  const callLabel = pickedVoiceName ? `${backendLabel} · ${pickedVoiceName}` : backendLabel;

  let status: string;
  if (snap.state === "connecting") status = `calling Larry… · ${callLabel}`;
  else if (snap.state === "live") status = `live · ${formatElapsed(now - (snap.startedAt ?? now))} · ${callLabel}`;
  else if (snap.state === "ended") status = `ended — ${endingText(snap.endedReason)}`;
  else status = "";

  const startBlocked = cockpitCallLive ? "a call is live in the Cockpit tab" : null;

  // The first line of every call's log: what else might hold the mic (#88).
  const startCall = useCallback(() => {
    void session.start(backend, voice).then(() => {
      session.note(`context: cockpit web view ${cockpitMounted ? "mounted" : "not mounted"}, page call ${cockpitCallLive ? "LIVE" : "none"}`);
    });
  }, [session, backend, voice, cockpitMounted, cockpitCallLive]);

  /* ---------- upload to a gist ---------- */
  const [uploadState, setUploadState] = useState<"idle" | "uploading" | "uploaded" | "failed">("idle");
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [uploadedUrl, setUploadedUrl] = useState<string | null>(null);
  const uploadTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(
    () => () => {
      if (uploadTimer.current) clearTimeout(uploadTimer.current);
    },
    [],
  );
  const upload = useCallback(async () => {
    if (!onUpload) return;
    setUploadState("uploading");
    setUploadError(null);
    try {
      const url = await onUpload();
      setUploadedUrl(url);
      setUploadState("uploaded");
    } catch (e) {
      setUploadError(e instanceof Error ? e.message : String(e));
      setUploadState("failed");
    }
    if (uploadTimer.current) clearTimeout(uploadTimer.current);
    uploadTimer.current = setTimeout(() => setUploadState("idle"), 2500);
  }, [onUpload]);
  const shownUrl = uploadedUrl ?? lastUploadUrl;

  const [priming, setPriming] = useState(false);
  const primeAudio = useCallback(async () => {
    setPriming(true);
    try {
      await session.prime();
    } finally {
      setPriming(false);
    }
  }, [session]);

  return (
    <View style={styles.container} testID="call-screen">
      {/* The call line (#96): status on the left, three small controls on the
          right while a call is up. Nothing under the captions. */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          {!active && <Text style={styles.title}>Call</Text>}
          <Text
            style={[styles.status, active && styles.statusActive, snap.state === "live" && styles.statusLive, snap.endedBadly && styles.statusBad]}
            testID="call-status"
            numberOfLines={1}
          >
            {status}
          </Text>
        </View>
        {active && (
          <View style={styles.callControls} testID="call-controls">
            <VoiceControl
              session={session}
              muted={snap.muted}
              live={snap.state === "live"}
              onPress={() => session.setMuted(!snap.muted)}
            />
            <Pressable
              onPress={() => session.restart()}
              style={styles.iconButton}
              testID="call-restart"
              accessibilityRole="button"
              accessibilityLabel="Restart call"
              hitSlop={6}
            >
              <View style={styles.restartCircle}>
                <Text style={styles.restartGlyph}>↻</Text>
              </View>
            </Pressable>
            <Pressable
              onPress={() => session.stop()}
              style={styles.iconButton}
              testID="call-hangup"
              accessibilityRole="button"
              accessibilityLabel="Hang up"
              hitSlop={6}
            >
              <View style={styles.hangupCircle}>
                <Text style={styles.hangupGlyph}>{HANDSET}</Text>
              </View>
            </Pressable>
          </View>
        )}
      </View>

      {snap.state === "live" && (
        <View style={styles.live} testID="call-live" accessibilityLabel="What you are saying">
          <Text style={styles.liveLabel}>you</Text>
          <Text
            style={[styles.liveText, !liveRow?.text && styles.liveHint]}
            numberOfLines={3}
            ellipsizeMode="head"
            testID="call-live-text"
          >
            {liveRow?.text || (snap.muted ? "muted" : "listening…")}
          </Text>
        </View>
      )}

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

      {route && (
        <View style={styles.devices} testID="call-devices">
          <Pressable
            onPress={() => setDevicesOpen((o) => !o)}
            style={styles.devicesLine}
            testID="call-devices-toggle"
            accessibilityRole="button"
            accessibilityState={{ expanded: devicesOpen }}
            accessibilityLabel="Microphone, output and voice"
          >
            <Text style={styles.devicesSummary} numberOfLines={1} testID="call-devices-summary">
              {pickedVoiceName ? `${describeRoute(route)} · ${pickedVoiceName}` : describeRoute(route)}
            </Text>
            <Text style={styles.devicesChevron}>{devicesOpen ? "▾" : "▸"}</Text>
          </Pressable>
          {devicesOpen && (
            <View style={styles.devicesRows}>
              <DeviceRow
                label="Mic"
                devices={route.inputs}
                currentId={route.current.input?.id ?? null}
                onPick={pickInput}
                testID="call-inputs"
              />
              <DeviceRow
                label="Out"
                devices={offeredOutputs(route)}
                currentId={route.current.output?.id ?? null}
                onPick={pickOutput}
                testID="call-outputs"
              />
              {voicedBackend && (
                <VoiceRow
                  picked={pickedVoice}
                  locked={active}
                  onPick={(v) => {
                    log.add(`pick voice ${v}`);
                    onVoiceChange?.(v);
                  }}
                />
              )}
            </View>
          )}
          <Pressable
            onPress={() => setDiagOpen((o) => !o)}
            style={styles.devicesLine}
            testID="call-diag-toggle"
            accessibilityRole="button"
            accessibilityState={{ expanded: diagOpen }}
          >
            <Text style={styles.devicesSummary}>Diagnostics · {logLines.length} lines</Text>
            <Text style={styles.devicesChevron}>{diagOpen ? "▾" : "▸"}</Text>
          </Pressable>
          {diagOpen && (
            <View style={styles.diag} testID="call-diag">
              <ScrollView style={styles.diagScroll} nestedScrollEnabled>
                {logLines.length === 0 ? (
                  <Text style={styles.diagLine}>No call yet.</Text>
                ) : (
                  logLines.map((l, i) => (
                    <Text key={i} style={styles.diagLine} selectable>
                      {l}
                    </Text>
                  ))
                )}
              </ScrollView>
              <View style={styles.diagButtons}>
                <Pressable
                  onPress={() => void copyDiagnostics()}
                  style={styles.diagCopy}
                  testID="call-diag-copy"
                  accessibilityRole="button"
                >
                  <Text style={styles.diagCopyText}>{copied ? "Copied" : "Copy diagnostics"}</Text>
                </Pressable>
                {onUpload && (
                  <Pressable
                    onPress={() => void upload()}
                    disabled={uploadState === "uploading"}
                    style={[styles.diagCopy, uploadState === "uploading" && styles.buttonDisabled]}
                    testID="call-diag-upload"
                    accessibilityRole="button"
                    accessibilityLabel="Upload diagnostics"
                  >
                    <Text style={styles.diagCopyText}>
                      {uploadState === "uploading"
                        ? "Uploading…"
                        : uploadState === "uploaded"
                          ? "Uploaded"
                          : uploadState === "failed"
                            ? "Upload failed"
                            : "Upload"}
                    </Text>
                  </Pressable>
                )}
                {!active && (
                  <Pressable
                    onPress={() => void primeAudio()}
                    disabled={priming}
                    style={[styles.diagCopy, priming && styles.buttonDisabled]}
                    testID="call-prime"
                    accessibilityRole="button"
                    accessibilityLabel="Prime audio"
                  >
                    <Text style={styles.diagCopyText}>{priming ? "Priming…" : "Prime audio"}</Text>
                  </Pressable>
                )}
              </View>
              {shownUrl && (
                <Text style={styles.uploadUrl} selectable numberOfLines={1} testID="call-diag-upload-url">
                  {shownUrl}
                </Text>
              )}
              {uploadError && (
                <CopyableError message={uploadError} context="CallScreen.upload" style={styles.uploadError} />
              )}
            </View>
          )}
        </View>
      )}

      <ScrollView
        ref={scrollRef}
        style={styles.captions}
        contentContainerStyle={styles.captionsContent}
        testID="call-captions"
      >
        {transcript.map((row) => {
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
        {transcript.every((r) => !r.text) &&
          (snap.state === "connecting" ? (
            <Calling backendLabel={backendLabel} reduceMotion={reduceMotion} />
          ) : (
            <Text style={styles.empty}>
              {snap.state === "live"
                ? "Say hello."
                : "Larry, over the tailnet. The call keeps going when the phone locks."}
            </Text>
          ))}
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

      {!active && (
        <View style={styles.controls}>
          <View style={styles.startWrap}>
            <Pressable
              onPress={startCall}
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
        </View>
      )}
    </View>
  );
}

/** Every mic and output by name and type, one line — what a route change actually changed. */
function describeRoster(s: AudioRouteSnapshot): string {
  const d = (x: { name: string; type: string } | null | undefined) => (x ? `${x.name}[${x.type}]` : "none");
  return `in=${d(s.current.input)} out=${d(s.current.output)} | mics: ${s.inputs.map(d).join(", ") || "none"} | outs: ${s.outputs.map(d).join(", ") || "none"}`;
}

/**
 * The calling treatment: a handset with a ring pulsing outward, the way the
 * Phone app calls. Two rings half a period apart; under Reduce Motion one
 * still ring. Shown in place of the captions until the bridge says `ready`.
 */
function Calling({ backendLabel, reduceMotion }: { backendLabel: string; reduceMotion: boolean }) {
  const first = useRef(new Animated.Value(0)).current;
  const second = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (reduceMotion) return;
    const pulse = (v: Animated.Value) =>
      Animated.loop(
        Animated.timing(v, {
          toValue: 1,
          duration: PULSE_MS,
          easing: Easing.out(Easing.quad),
          useNativeDriver: true,
        }),
      );
    const anim = Animated.parallel([
      pulse(first),
      Animated.sequence([Animated.delay(PULSE_MS / 2), pulse(second)]),
    ]);
    anim.start();
    return () => {
      anim.stop();
      first.setValue(0);
      second.setValue(0);
    };
  }, [first, second, reduceMotion]);
  const ringStyle = (v: Animated.Value) =>
    reduceMotion
      ? styles.callingRingStill
      : {
          transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [1, 1.9] }) }],
          opacity: v.interpolate({ inputRange: [0, 1], outputRange: [0.6, 0] }),
        };
  return (
    <View style={styles.calling} testID="call-calling" accessibilityLabel={`Calling Larry on ${backendLabel}`}>
      <View style={styles.callingRingWrap}>
        <Animated.View style={[styles.callingRing, ringStyle(first)]} />
        {!reduceMotion && <Animated.View style={[styles.callingRing, ringStyle(second)]} />}
        <View style={styles.callingDisc}>
          <Text style={styles.callingGlyph}>{HANDSET}</Text>
        </View>
      </View>
      <Text style={styles.callingText}>Calling Larry…</Text>
      <Text style={styles.callingBackend}>{backendLabel}</Text>
    </View>
  );
}

/**
 * The voice control — "the little voice dial-y thing" — and the mute, one
 * control. A disc inside the circle swells with the mic and falls with
 * decay so a word leaves a trace. Subscribes to the session's level channel
 * directly so ten updates a second re-render this one view and not the
 * captions. Muted, the disc freezes where it was, the circle dims, and a
 * slash crosses the microphone.
 */
function VoiceControl({
  session,
  muted,
  live,
  onPress,
}: {
  session: CallSession;
  muted: boolean;
  live: boolean;
  onPress: () => void;
}) {
  const [level, setLevel] = useState(0);
  const mutedRef = useRef(muted);
  mutedRef.current = muted;
  useEffect(() => {
    if (!live) {
      setLevel(0);
      return;
    }
    let shown = 0;
    return session.subscribeLevel((raw) => {
      // Frozen while muted: the level is the mute's own state, not a meter.
      if (mutedRef.current) return;
      shown = Math.max(raw, shown * METER_DECAY);
      setLevel(shown);
    });
  }, [session, live]);
  const disc = Math.round(VOICE_DISC_MIN + level * (VOICE_DISC_MAX - VOICE_DISC_MIN));
  return (
    <Pressable
      onPress={onPress}
      style={styles.iconButton}
      testID="call-mute"
      accessibilityRole="button"
      accessibilityState={{ selected: muted }}
      accessibilityLabel={muted ? "Unmute" : "Mute"}
      accessibilityValue={{ text: `microphone level ${Math.round(level * 100)}%` }}
      hitSlop={8}
    >
      <View style={[styles.voiceCircle, muted && styles.voiceCircleMuted]}>
        <View
          testID="call-mic-meter"
          style={[
            styles.voiceDisc,
            muted && styles.voiceDiscMuted,
            { width: disc, height: disc, borderRadius: disc / 2 },
          ]}
        />
        <MicGlyph muted={muted} />
        {muted && <View style={styles.voiceSlash} />}
      </View>
    </Pressable>
  );
}

/** A microphone drawn from views — capsule, cradle, stem, foot — so it needs no icon font or SVG. */
function MicGlyph({ muted }: { muted: boolean }) {
  const tint = muted ? styles.micMuted : null;
  return (
    <View style={styles.mic} pointerEvents="none">
      <View style={[styles.micCapsule, tint]} />
      <View style={[styles.micCradle, muted && styles.micCradleMuted]} />
      <View style={[styles.micStem, tint]} />
      <View style={[styles.micFoot, tint]} />
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

/**
 * The voice row (#98): Tony or Igor. Locked while a call is up — a voice
 * cannot change mid-session.
 */
function VoiceRow({
  picked,
  locked,
  onPick,
}: {
  picked: CallVoice;
  locked: boolean;
  onPick: (voice: CallVoice) => void;
}) {
  return (
    <View style={styles.deviceRow} testID="call-voices">
      <Text style={styles.deviceLabel}>Voice</Text>
      <View style={styles.deviceChips}>
        {VOICES.map((v) => {
          const selected = v.id === picked;
          return (
            <Pressable
              key={v.id}
              onPress={() => !locked && onPick(v.id)}
              disabled={locked}
              style={[styles.chip, styles.chipSmall, selected && styles.chipSelected, locked && !selected && styles.chipDisabled]}
              accessibilityRole="radio"
              accessibilityState={{ selected, disabled: locked }}
              testID={`call-voices-${v.id}`}
            >
              <Text style={[styles.chipText, selected && styles.chipTextSelected]}>{v.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  header: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 16,
    paddingTop: 56,
    paddingBottom: 8,
    backgroundColor: "#0c121f",
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#222",
    gap: 12,
    minHeight: 100,
  },
  headerLeft: { flex: 1, gap: 2 },
  title: { color: "#eee", fontSize: 20, fontWeight: "700" },
  status: { color: "#888", fontSize: 13, fontVariant: ["tabular-nums"] },
  statusActive: { fontSize: 15, fontWeight: "600" },
  callControls: { flexDirection: "row", alignItems: "center", gap: 6 },
  iconButton: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  statusLive: { color: "#4ade80" },
  statusBad: { color: "#f87171" },
  /* the live line (#igor 2026-09-02): twice a caption row, big type */
  live: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 10,
    marginHorizontal: 16,
    marginTop: 10,
    paddingVertical: 8,
    paddingHorizontal: 12,
    minHeight: 64,
    borderRadius: 10,
    backgroundColor: "#0f1b2d",
    borderLeftWidth: 3,
    borderLeftColor: "#4cc9f0",
  },
  liveLabel: { color: "#4cc9f0", fontSize: 12, fontWeight: "700", lineHeight: 28, width: 28 },
  liveText: { flex: 1, color: "#f8fafc", fontSize: 22, lineHeight: 28, fontWeight: "500" },
  liveHint: { color: "#475569", fontStyle: "italic", fontWeight: "400" },
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
  devices: { paddingHorizontal: 16, paddingBottom: 6 },
  devicesLine: { flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 6 },
  devicesSummary: { flex: 1, color: "#aaa", fontSize: 13 },
  devicesChevron: { color: "#666", fontSize: 13 },
  devicesRows: { gap: 6, paddingTop: 4 },
  diag: { gap: 6, paddingBottom: 6 },
  diagScroll: { maxHeight: 180, backgroundColor: "#0c121f", borderRadius: 8, padding: 8 },
  diagLine: { color: "#9fb3c8", fontSize: 11, fontFamily: "Menlo", lineHeight: 15 },
  diagButtons: { flexDirection: "row", gap: 8, flexWrap: "wrap" },
  uploadUrl: { color: "#9fb3c8", fontSize: 12, fontFamily: "Menlo" },
  uploadError: { marginTop: 4 },
  diagCopy: { alignSelf: "flex-start", paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, backgroundColor: "#243447" },
  diagCopyText: { color: "#4cc9f0", fontSize: 13, fontWeight: "600" },
  deviceRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  deviceLabel: { color: "#888", fontSize: 12, width: 36 },
  deviceChips: { flexDirection: "row", gap: 6 },
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

  /* ---------- calling ---------- */
  calling: { alignItems: "center", gap: 6, paddingTop: 48, paddingBottom: 24 },
  callingRingWrap: { width: 96, height: 96, alignItems: "center", justifyContent: "center", marginBottom: 18 },
  callingRing: {
    position: "absolute",
    width: 96,
    height: 96,
    borderRadius: 48,
    borderWidth: 2,
    borderColor: "#4cc9f0",
  },
  callingRingStill: { opacity: 0.35 },
  callingDisc: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: "#243447",
    borderWidth: 2,
    borderColor: "#4cc9f0",
    alignItems: "center",
    justifyContent: "center",
  },
  callingGlyph: { color: "#4cc9f0", fontSize: 34, lineHeight: 40 },
  callingText: { color: "#eee", fontSize: 20, fontWeight: "600" },
  callingBackend: { color: "#888", fontSize: 14 },

  /* ---------- controls ---------- */
  controls: {
    flexDirection: "row",
    alignItems: "flex-start",
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 18,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: "#222",
    backgroundColor: "#0c121f",
  },
  controlSlot: { flex: 1, alignItems: "center" },
  restartCircle: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: "#243447",
    alignItems: "center",
    justifyContent: "center",
  },
  restartGlyph: { color: "#4cc9f0", fontSize: 18, lineHeight: 22, fontWeight: "700" },
  control: { alignItems: "center", gap: 8 },
  controlLabel: { color: "#9fb3c8", fontSize: 12, fontWeight: "600" },
  controlLabelMuted: { color: "#f87171" },
  startWrap: { flex: 1, gap: 6 },
  button: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 16,
    borderRadius: 12,
  },
  buttonStart: { backgroundColor: "#16a34a" },
  buttonDisabled: { opacity: 0.4 },
  buttonText: { color: "#fff", fontSize: 17, fontWeight: "700" },
  blocked: { color: "#f87171", fontSize: 13, textAlign: "center" },

  /* the voice control: circle, level disc, mic, slash */
  voiceCircle: {
    width: VOICE_SIZE,
    height: VOICE_SIZE,
    borderRadius: VOICE_SIZE / 2,
    backgroundColor: "#243447",
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
  },
  voiceCircleMuted: { opacity: 0.55 },
  voiceDisc: { position: "absolute", backgroundColor: "#4ade80", opacity: 0.45 },
  voiceDiscMuted: { backgroundColor: "#64748b" },
  voiceSlash: {
    position: "absolute",
    width: 3,
    height: VOICE_SIZE,
    borderRadius: 2,
    backgroundColor: "#f87171",
    transform: [{ rotate: "45deg" }],
  },
  mic: { alignItems: "center" },
  micCapsule: { width: 6, height: 10, borderRadius: 3, backgroundColor: "#eee" },
  micCradle: {
    width: 12,
    height: 7,
    marginTop: -5,
    borderWidth: 1.5,
    borderTopWidth: 0,
    borderBottomLeftRadius: 6,
    borderBottomRightRadius: 6,
    borderColor: "#eee",
  },
  micCradleMuted: { borderColor: "#cbd5e1" },
  micStem: { width: 1.5, height: 2, backgroundColor: "#eee" },
  micFoot: { width: 7, height: 1.5, borderRadius: 1, backgroundColor: "#eee" },
  micMuted: { backgroundColor: "#cbd5e1" },

  /* the hang-up: round, red, the handset in white */
  hangupCircle: {
    width: HANGUP_SIZE,
    height: HANGUP_SIZE,
    borderRadius: HANGUP_SIZE / 2,
    backgroundColor: "#dc2626",
    alignItems: "center",
    justifyContent: "center",
  },
  hangupGlyph: { color: "#fff", fontSize: 17, lineHeight: 21 },
});
