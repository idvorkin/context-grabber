import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  Linking,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { WebView, type WebViewMessageEvent } from "react-native-webview";
import { activateKeepAwakeAsync, deactivateKeepAwake } from "expo-keep-awake";
import { CopyableError } from "../components/CopyableError";
import {
  bridgeEmitScript,
  bridgeInstallScript,
  callIntentEmitScript,
  type CallIntent,
  describeError,
  devicesPayload,
  errorPayload,
  parseBridgeRequest,
  readyPayload,
  routeChangedPayload,
  type BridgePayload,
  type BridgeRequest,
} from "../lib/audioBridge";
import AudioRoute, { type AudioRouteSnapshot } from "../modules/audio-route";

/**
 * Igor's decision Cockpit. Served only on the tailnet — there is no
 * public route to it, which is exactly why the app carries no auth for
 * it. Reaching the host at all is the authentication.
 */
export const COCKPIT_URL = "https://c-5004.squeaker-teeth.ts.net";

/** Host portion of COCKPIT_URL, used to decide what stays in the tab. */
const COCKPIT_HOST = "c-5004.squeaker-teeth.ts.net";

type Props = {
  /**
   * False while another tab is showing. The screen stays mounted and is
   * merely hidden, so the Cockpit keeps its scroll position, its expanded
   * rows, and any in-flight recording across tab switches.
   */
  visible?: boolean;
  /** Override the loaded URL. Tests only. */
  url?: string;
  /**
   * A deep link asked for a call (`grabber://call?via=…`). Delivered to the
   * page exactly once per nonce, as soon as the page is loaded and healthy.
   * Spec: docs/superpowers/specs/2026-08-28-cockpit-call-deep-link-design.md.
   */
  callIntent?: CallIntent | null;
};

/** Tagged so it can never collide with the Gym Timer's default keep-awake. */
const KEEP_AWAKE_TAG = "cockpit";

export function CockpitScreen({
  visible = true,
  url = COCKPIT_URL,
  callIntent = null,
}: Props) {
  const webRef = useRef<WebView>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  /* ---------- keep the screen awake ----------
     Igor: "when I'm on the Cockpit screen, I want to make sure it doesn't
     lock." A property of the tab, not of a call: he reads decisions here
     too. The screen stays mounted while hidden, so this keys on `visible`
     rather than on mount — every other tab hands the idle timer straight
     back to iOS. The error pane counts as the tab (a reconnect is watched).
     Spec: docs/superpowers/specs/2026-08-28-cockpit-keep-awake-design.md. */
  useEffect(() => {
    if (!visible) return;
    void Promise.resolve(activateKeepAwakeAsync(KEEP_AWAKE_TAG)).catch(() => {});
    return () => {
      void Promise.resolve(deactivateKeepAwake(KEEP_AWAKE_TAG)).catch(() => {});
    };
  }, [visible]);
  // Bumped on every manual retry to force a fresh WebView mount — reload()
  // on a WebView that failed its very first load is unreliable.
  const [reloadKey, setReloadKey] = useState(0);

  const handleRetry = useCallback(() => {
    setError(null);
    setLoading(true);
    setReloadKey((k) => k + 1);
  }, []);

  const handleReload = useCallback(() => {
    if (error) {
      handleRetry();
      return;
    }
    setLoading(true);
    webRef.current?.reload();
  }, [error, handleRetry]);

  /* ---------- audio bridge ----------
     WebKit shows the page one nameless microphone and no outputs at all, so
     the Cockpit's device pickers have nothing to build a control out of and
     hide themselves. The real roster is in AVAudioSession. This is the pipe:
     the page asks, the app answers, the app applies the page's choice.
     Protocol: docs/cockpit-audio-bridge.md. */

  const emit = useCallback((payload: BridgePayload) => {
    webRef.current?.injectJavaScript(bridgeEmitScript(payload));
  }, []);

  const handleBridgeRequest = useCallback(
    async (request: BridgeRequest) => {
      if (!AudioRoute) {
        // An OTA update can put a newer page in front of an older binary.
        // Saying so beats a request that never gets an answer.
        emit(
          errorPayload(
            request.type,
            "This build has no native audio bridge",
            request.requestId,
          ),
        );
        return;
      }
      try {
        let snapshot: AudioRouteSnapshot;
        switch (request.type) {
          case "audio.setInput":
            snapshot = await AudioRoute.setInput(request.id);
            break;
          case "audio.setOutput":
            snapshot = await AudioRoute.setOutput(request.port);
            break;
          default:
            // listDevices and getRoute differ only in what the page reads
            // out of the answer, so they share one.
            snapshot = AudioRoute.getDevices();
        }
        emit(devicesPayload(snapshot, request.requestId));
      } catch (e) {
        // Audio failures belong to the page, next to the control that caused
        // them — never to the app's own "can't reach the Cockpit" panel.
        emit(errorPayload(request.type, describeError(e), request.requestId));
      }
    },
    [emit],
  );

  const handleMessage = useCallback(
    (event: WebViewMessageEvent) => {
      const request = parseBridgeRequest(event.nativeEvent.data);
      // Not ours. The page owns postMessage and may be using it for something
      // else; swallowing that traffic would be a bug.
      if (!request) return;
      void handleBridgeRequest(request);
    },
    [handleBridgeRequest],
  );

  // The session has to be recording-capable before availableInputs lists
  // anything but the built-in mic and before an output override is legal.
  // Done on first visibility rather than on mount so a user who never opens
  // the tab never has their audio session touched.
  const activated = useRef(false);
  useEffect(() => {
    if (!visible || activated.current || !AudioRoute) return;
    activated.current = true;
    AudioRoute.activate().catch(() => {
      // Nothing to show: the page has not asked for anything yet, and the
      // next request re-reports the failure with its own requestId.
    });
  }, [visible]);

  // AirPods connecting, a cable pulled, a battery dying — or the web view's
  // own getUserMedia reconfiguring the session out from under us.
  useEffect(() => {
    if (!AudioRoute) return;
    const sub = AudioRoute.addListener("onRouteChange", (change) => {
      emit(routeChangedPayload(change));
    });
    return () => sub.remove();
  }, [emit]);

  const handleLoadEnd = useCallback(() => {
    setLoading(false);
    emit(readyPayload(!!AudioRoute));
  }, [emit]);

  /* ---------- call intent ----------
     The app never starts the call; it asks the page to press its own
     handset, so every rule the handset enforces holds for a link. One
     delivery per nonce. A page still loading gets it on load end — the same
     effect re-runs when `loading` flips. A failed load CONSUMES it: a call
     Igor asked for must not start an hour later when the page finally comes
     up after "Try again". A reload after a content-process kill does not
     re-deliver, because the nonce is already spent. */
  const intentDelivered = useRef<number | null>(null);
  useEffect(() => {
    if (!callIntent || intentDelivered.current === callIntent.nonce) return;
    if (error) {
      intentDelivered.current = callIntent.nonce;
      return;
    }
    if (loading) return;
    intentDelivered.current = callIntent.nonce;
    webRef.current?.injectJavaScript(callIntentEmitScript(callIntent));
  }, [callIntent, loading, error]);

  /**
   * Keep the tab pinned to the Cockpit. Anything on another host (a
   * GitHub PR link, an external article) is handed to the system
   * browser instead of turning this tab into a browsing session — which
   * also keeps the media-capture grant scoped to the one origin.
   */
  const handleShouldStartLoad = useCallback(
    (request: { url: string; navigationType?: string }) => {
      let host = "";
      try {
        host = new URL(request.url).host;
      } catch {
        return true;
      }
      if (host === COCKPIT_HOST) return true;
      if (request.url.startsWith("about:")) return true;
      Linking.openURL(request.url).catch(() => {});
      return false;
    },
    [],
  );

  return (
    <View
      style={[styles.container, !visible && styles.hidden]}
      testID="cockpit-screen"
      // Hidden tabs shouldn't be reachable by VoiceOver or Maestro.
      pointerEvents={visible ? "auto" : "none"}
    >
      <View style={styles.header}>
        <Text style={styles.title}>Cockpit</Text>
        <TouchableOpacity
          onPress={handleReload}
          style={styles.reloadBtn}
          testID="cockpit-reload"
          accessibilityRole="button"
          accessibilityLabel="Reload Cockpit"
        >
          <Text style={styles.reloadBtnText}>↻</Text>
        </TouchableOpacity>
      </View>

      {error ? (
        <View style={styles.errorPane} testID="cockpit-error">
          <Text style={styles.errorTitle}>Can&apos;t reach the Cockpit</Text>
          <Text style={styles.errorHint}>
            Check that Tailscale is connected and the machine serving the
            Cockpit is awake.
          </Text>
          <Text style={styles.errorUrl} selectable>
            {url}
          </Text>
          <TouchableOpacity
            onPress={handleRetry}
            style={styles.retryBtn}
            testID="cockpit-retry"
            accessibilityRole="button"
          >
            <Text style={styles.retryBtnText}>Try again</Text>
          </TouchableOpacity>
          <CopyableError
            message={error}
            context="CockpitScreen.load"
            extra={{ url }}
          />
        </View>
      ) : (
        <View style={styles.webWrap}>
          <WebView
            key={reloadKey}
            ref={webRef}
            testID="cockpit-webview"
            source={{ uri: url }}
            // --- media: let the Cockpit's voice controls work ---
            // iOS grants getUserMedia to same-host content and defers to
            // the system prompt for anything else. The app-level mic
            // alert is iOS's own (NSMicrophoneUsageDescription is
            // already declared for voice notes) — no custom UI.
            mediaCapturePermissionGrantType="grantIfSameHostElsePrompt"
            allowsInlineMediaPlayback
            mediaPlaybackRequiresUserAction={false}
            allowsAirPlayForMediaPlayback
            // --- audio bridge ---
            // onMessage is not optional: setting it is what makes
            // window.ReactNativeWebView.postMessage exist on the page at all.
            onMessage={handleMessage}
            // Before content, so the page can feature-detect the bridge on its
            // first line of script instead of racing a load event.
            injectedJavaScriptBeforeContentLoaded={bridgeInstallScript()}
            // --- navigation ---
            onShouldStartLoadWithRequest={handleShouldStartLoad}
            setSupportMultipleWindows={false}
            allowsBackForwardNavigationGestures
            // --- refresh ---
            pullToRefreshEnabled
            // --- lifecycle ---
            onLoadStart={() => setLoading(true)}
            onLoadEnd={handleLoadEnd}
            onError={(e) => {
              const { description, code } = e.nativeEvent;
              setLoading(false);
              setError(`${description ?? "Load failed"} (code ${code})`);
            }}
            onHttpError={(e) => {
              const { statusCode, description } = e.nativeEvent;
              setLoading(false);
              setError(
                `HTTP ${statusCode}${description ? ` — ${description}` : ""}`,
              );
            }}
            // iOS reclaims the web content process on memory pressure while
            // backgrounded; without this the tab comes back as a white void.
            onContentProcessDidTerminate={() => webRef.current?.reload()}
            style={styles.web}
            // Match the app chrome so the load flash isn't a white slab.
            containerStyle={styles.webContainer}
          />
          {loading && (
            <View style={styles.loadingOverlay} testID="cockpit-loading">
              <ActivityIndicator size="large" color="#4cc9f0" />
              <Text style={styles.loadingText}>Cockpit</Text>
            </View>
          )}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#1a1a2e" },
  hidden: { display: "none" },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingTop: 60,
    paddingBottom: 10,
    backgroundColor: "#0c121f",
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#222",
  },
  title: { color: "#eee", fontSize: 20, fontWeight: "700" },
  reloadBtn: { paddingHorizontal: 12, paddingVertical: 6 },
  reloadBtnText: { color: "#4cc9f0", fontSize: 22, lineHeight: 26 },
  webWrap: { flex: 1 },
  web: { flex: 1, backgroundColor: "#1a1a2e" },
  webContainer: { backgroundColor: "#1a1a2e" },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#1a1a2e",
    gap: 10,
  },
  loadingText: { color: "#888", fontSize: 13, letterSpacing: 1 },
  errorPane: { flex: 1, padding: 24, gap: 12 },
  errorTitle: { color: "#eee", fontSize: 18, fontWeight: "700" },
  errorHint: { color: "#aaa", fontSize: 14, lineHeight: 20 },
  errorUrl: { color: "#4cc9f0", fontSize: 13, fontFamily: "Menlo" },
  retryBtn: {
    alignSelf: "flex-start",
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 8,
    backgroundColor: "#243447",
  },
  retryBtnText: { color: "#4cc9f0", fontSize: 15, fontWeight: "600" },
});
