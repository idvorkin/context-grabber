import React from "react";
import { fireEvent, render, waitFor } from "@testing-library/react-native";
import { Linking } from "react-native";
import { CockpitScreen, COCKPIT_URL } from "../screens/CockpitScreen";
import { BRIDGE_EVENT, BRIDGE_GLOBAL, CALL_INTENT_EVENT, CALL_INTENT_GLOBAL } from "../lib/audioBridge";
import AudioRoute from "../modules/audio-route";

// Both mocks live in jest.setup.js. The web view one exposes its imperative
// handle so we can read back what was injected into the page — that injected
// string is the audio bridge's wire format, and running it is the only way to
// test the app → page direction without a device.
const web = jest.requireMock("react-native-webview").__mock as {
  injectJavaScript: jest.Mock;
  reload: jest.Mock;
};
const audio = AudioRoute as unknown as {
  snapshot: Record<string, unknown>;
  listeners: ((payload: unknown) => void)[];
  activate: jest.Mock;
  getDevices: jest.Mock;
  setInput: jest.Mock;
  setOutput: jest.Mock;
  addListener: jest.Mock;
};

/** Run every injected script against a fake page and collect the payloads. */
function injectedPayloads(): any[] {
  const events: any[] = [];
  const win: Record<string, any> = { dispatchEvent: (e: any) => events.push(e) };
  class FakeCustomEvent {
    type: string;
    detail: unknown;
    constructor(type: string, init?: { detail?: unknown }) {
      this.type = type;
      this.detail = init?.detail;
    }
  }
  for (const call of web.injectJavaScript.mock.calls) {
    new Function("window", "CustomEvent", call[0])(win, FakeCustomEvent);
  }
  expect(events.every((e) => e.type === BRIDGE_EVENT)).toBe(true);
  return events.map((e) => e.detail);
}

function post(r: ReturnType<typeof render>, msg: unknown) {
  fireEvent(r.getByTestId("cockpit-webview"), "message", {
    nativeEvent: { data: JSON.stringify(msg) },
  });
}

// react-native-webview is mocked in jest.setup.js as a plain View that
// forwards its props, so we can assert on the configuration the real
// WKWebView would receive.
describe("CockpitScreen", () => {
  beforeEach(() => {
    web.injectJavaScript.mockClear();
    web.reload.mockClear();
    audio.listeners = [];
    for (const fn of [
      audio.activate,
      audio.getDevices,
      audio.setInput,
      audio.setOutput,
      audio.addListener,
    ]) {
      fn.mockClear();
    }
  });

  it("points the web view at the tailnet Cockpit", () => {
    const r = render(<CockpitScreen />);
    const web = r.getByTestId("cockpit-webview");
    expect(web.props.source).toEqual({ uri: COCKPIT_URL });
    expect(COCKPIT_URL.startsWith("https://")).toBe(true);
  });

  it("configures the media props the Cockpit's voice control needs", () => {
    const r = render(<CockpitScreen />);
    const web = r.getByTestId("cockpit-webview");
    // Same-host grant + system prompt for anything else: iOS's own
    // permission machinery, no in-app permission UI.
    expect(web.props.mediaCapturePermissionGrantType).toBe(
      "grantIfSameHostElsePrompt",
    );
    expect(web.props.allowsInlineMediaPlayback).toBe(true);
    expect(web.props.mediaPlaybackRequiresUserAction).toBe(false);
  });

  it("enables pull-to-refresh and exposes a reload control", () => {
    const r = render(<CockpitScreen />);
    expect(r.getByTestId("cockpit-webview").props.pullToRefreshEnabled).toBe(
      true,
    );
    expect(r.getByTestId("cockpit-reload")).toBeTruthy();
  });

  it("shows a loading state until the page finishes loading", () => {
    const r = render(<CockpitScreen />);
    expect(r.getByTestId("cockpit-loading")).toBeTruthy();
    fireEvent(r.getByTestId("cockpit-webview"), "loadEnd");
    expect(r.queryByTestId("cockpit-loading")).toBeNull();
  });

  it("shows a reconnect panel instead of a blank view on load failure", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "error", {
      nativeEvent: { description: "A server with the specified hostname could not be found.", code: -1003 },
    });
    expect(r.getByTestId("cockpit-error")).toBeTruthy();
    expect(r.getByText("Can't reach the Cockpit")).toBeTruthy();
    expect(r.getByText(/Tailscale/)).toBeTruthy();
    expect(r.queryByTestId("cockpit-webview")).toBeNull();
  });

  it("shows the reconnect panel on an HTTP error too", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "httpError", {
      nativeEvent: { statusCode: 502, description: "Bad Gateway" },
    });
    expect(r.getByTestId("cockpit-error")).toBeTruthy();
  });

  it("retries the load from the reconnect panel", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "error", {
      nativeEvent: { description: "offline", code: -1009 },
    });
    fireEvent.press(r.getByTestId("cockpit-retry"));
    expect(r.queryByTestId("cockpit-error")).toBeNull();
    expect(r.getByTestId("cockpit-webview")).toBeTruthy();
  });

  it("keeps Cockpit navigation in the tab and hands other hosts to the browser", () => {
    const openURL = jest
      .spyOn(Linking, "openURL")
      .mockResolvedValue(undefined as never);
    const r = render(<CockpitScreen />);
    const shouldLoad =
      r.getByTestId("cockpit-webview").props.onShouldStartLoadWithRequest;

    expect(shouldLoad({ url: `${COCKPIT_URL}/decisions` })).toBe(true);
    expect(openURL).not.toHaveBeenCalled();

    expect(shouldLoad({ url: "https://github.com/idvorkin/igor2/pull/1" })).toBe(
      false,
    );
    expect(openURL).toHaveBeenCalledWith(
      "https://github.com/idvorkin/igor2/pull/1",
    );
    openURL.mockRestore();
  });

  it("stays mounted but hidden when another tab is active", () => {
    const r = render(<CockpitScreen visible={false} />);
    // Hidden from the accessibility tree (that's the point), so queries
    // have to opt in to hidden elements to see it at all.
    const screen = r.getByTestId("cockpit-screen", {
      includeHiddenElements: true,
    });
    expect(
      r.getByTestId("cockpit-webview", { includeHiddenElements: true }),
    ).toBeTruthy();
    const style = Array.isArray(screen.props.style)
      ? Object.assign({}, ...screen.props.style.filter(Boolean))
      : screen.props.style;
    expect(style.display).toBe("none");
  });
});

describe("CockpitScreen audio bridge", () => {
  beforeEach(() => {
    web.injectJavaScript.mockClear();
    audio.listeners = [];
    for (const fn of [
      audio.activate,
      audio.getDevices,
      audio.setInput,
      audio.setOutput,
      audio.addListener,
    ]) {
      fn.mockClear();
    }
  });

  it("installs the bridge before any page script runs", () => {
    const r = render(<CockpitScreen />);
    const script = r.getByTestId("cockpit-webview").props
      .injectedJavaScriptBeforeContentLoaded;
    expect(typeof script).toBe("string");
    expect(script).toContain(BRIDGE_GLOBAL);
    // Setting onMessage is what makes window.ReactNativeWebView.postMessage
    // exist on the page at all — without it the bridge is one-way.
    expect(typeof r.getByTestId("cockpit-webview").props.onMessage).toBe("function");
  });

  it("puts the audio session in recording shape once the tab is visible", () => {
    render(<CockpitScreen />);
    expect(audio.activate).toHaveBeenCalledTimes(1);
  });

  it("leaves the audio session alone for a tab that was never opened", () => {
    render(<CockpitScreen visible={false} />);
    expect(audio.activate).not.toHaveBeenCalled();
  });

  it("tells the page the bridge is live once the page has loaded", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "loadEnd");
    expect(injectedPayloads()).toContainEqual(
      expect.objectContaining({ type: "audio.ready", available: true, platform: "ios" }),
    );
  });

  it("answers listDevices with the real roster", async () => {
    const r = render(<CockpitScreen />);
    post(r, { type: "audio.listDevices", requestId: "r1" });
    await waitFor(() => expect(web.injectJavaScript).toHaveBeenCalled());

    const payload = injectedPayloads().find((p) => p.type === "audio.devices");
    expect(payload.requestId).toBe("r1");
    expect(payload.inputs.map((d: any) => d.name)).toEqual([
      "iPhone Microphone",
      "AirPods Pro",
    ]);
    // The output list WebKit cannot produce at all is the whole point.
    expect(payload.outputs.map((d: any) => d.id)).toContain("speaker");
    expect(payload.current.output.id).toBe("speaker");
  });

  it("applies a microphone choice and answers with what actually resulted", async () => {
    const r = render(<CockpitScreen />);
    post(r, { type: "audio.setInput", id: "AC:12:34:56:78:9A-tacl", requestId: "r2" });
    await waitFor(() => expect(audio.setInput).toHaveBeenCalledWith("AC:12:34:56:78:9A-tacl"));

    const payload = injectedPayloads().find((p) => p.type === "audio.devices");
    expect(payload.requestId).toBe("r2");
    expect(payload.current).toBeDefined();
  });

  it("hands 'system default' to iOS as a cleared preference", async () => {
    const r = render(<CockpitScreen />);
    post(r, { type: "audio.setInput", id: "" });
    await waitFor(() => expect(audio.setInput).toHaveBeenCalledWith(null));
  });

  it("applies an output choice", async () => {
    const r = render(<CockpitScreen />);
    post(r, { type: "audio.setOutput", port: "speaker", requestId: "r3" });
    await waitFor(() => expect(audio.setOutput).toHaveBeenCalledWith("speaker"));
    expect(injectedPayloads().find((p) => p.type === "audio.devices").requestId).toBe("r3");
  });

  it("reports a refused route to the page instead of swallowing it", async () => {
    audio.setInput.mockRejectedValueOnce(new Error("Input not available: ghost"));
    const r = render(<CockpitScreen />);
    post(r, { type: "audio.setInput", id: "ghost", requestId: "r4" });

    await waitFor(() =>
      expect(injectedPayloads().some((p) => p.type === "audio.error")).toBe(true),
    );
    const payload = injectedPayloads().find((p) => p.type === "audio.error");
    expect(payload).toEqual({
      type: "audio.error",
      op: "audio.setInput",
      message: "Input not available: ghost",
      requestId: "r4",
    });
    // An audio failure is the page's to show; the app's error panel is for
    // "can't reach the Cockpit" and nothing else.
    expect(r.queryByTestId("cockpit-error")).toBeNull();
  });

  it("pushes a route change without being asked", () => {
    render(<CockpitScreen />);
    expect(audio.addListener).toHaveBeenCalledWith("onRouteChange", expect.any(Function));

    audio.listeners.forEach((fn) =>
      fn({ ...audio.snapshot, reason: "oldDeviceUnavailable" }),
    );
    const payload = injectedPayloads().find((p) => p.type === "audio.routeChanged");
    expect(payload.reason).toBe("oldDeviceUnavailable");
    expect(payload.inputs).toBeDefined();
  });

  it("stops listening for route changes when the screen goes away", () => {
    const r = render(<CockpitScreen />);
    expect(audio.listeners).toHaveLength(1);
    r.unmount();
    expect(audio.listeners).toHaveLength(0);
  });

  it("leaves messages that are not ours alone", () => {
    const r = render(<CockpitScreen />);
    post(r, { type: "cockpit.decision", id: 3 });
    fireEvent(r.getByTestId("cockpit-webview"), "message", {
      nativeEvent: { data: "not json" },
    });
    expect(web.injectJavaScript).not.toHaveBeenCalled();
    expect(audio.getDevices).not.toHaveBeenCalled();
  });
});

/* ---------- keep the screen awake ----------
   Spec: docs/superpowers/specs/2026-08-28-cockpit-keep-awake-design.md. A
   property of the tab: held while it shows, released the moment it does not. */
describe("CockpitScreen keeps the screen awake", () => {
  const keep = jest.requireMock("expo-keep-awake") as {
    activateKeepAwakeAsync: jest.Mock;
    deactivateKeepAwake: jest.Mock;
  };
  beforeEach(() => {
    keep.activateKeepAwakeAsync.mockClear();
    keep.deactivateKeepAwake.mockClear();
  });

  it("holds the screen while the tab is showing", () => {
    render(<CockpitScreen />);
    expect(keep.activateKeepAwakeAsync).toHaveBeenCalledWith("cockpit");
    expect(keep.deactivateKeepAwake).not.toHaveBeenCalled();
  });

  it("never holds it for a tab that is mounted but hidden", () => {
    render(<CockpitScreen visible={false} />);
    expect(keep.activateKeepAwakeAsync).not.toHaveBeenCalled();
  });

  it("hands the idle timer back the moment another tab shows, and takes it again on return", () => {
    const r = render(<CockpitScreen />);
    r.rerender(<CockpitScreen visible={false} />);
    expect(keep.deactivateKeepAwake).toHaveBeenCalledWith("cockpit");
    r.rerender(<CockpitScreen visible />);
    expect(keep.activateKeepAwakeAsync).toHaveBeenCalledTimes(2);
  });

  it("releases it when the screen goes away entirely", () => {
    const r = render(<CockpitScreen />);
    r.unmount();
    expect(keep.deactivateKeepAwake).toHaveBeenCalledWith("cockpit");
  });

  it("still holds it on the reconnect pane — a reconnect is watched", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "error", {
      nativeEvent: { description: "offline", code: -1009 },
    });
    expect(r.getByTestId("cockpit-error")).toBeTruthy();
    expect(keep.deactivateKeepAwake).not.toHaveBeenCalled();
  });

  it("uses its own tag so the Gym Timer's default keep-awake is never released by it", () => {
    const r = render(<CockpitScreen />);
    r.unmount();
    for (const call of keep.deactivateKeepAwake.mock.calls) expect(call[0]).toBe("cockpit");
  });
});

/* ---------- call intent ----------
   Spec: docs/superpowers/specs/2026-08-28-cockpit-call-deep-link-design.md.
   The app asks the page to press its own handset — once per link, only once
   the page is up, and never after a failed load. */
describe("CockpitScreen call intent", () => {
  beforeEach(() => {
    web.injectJavaScript.mockClear();
  });

  /** Every injected script, run against a fake page; returns the cockpit-call events + the parked global. */
  function delivered() {
    const events: any[] = [];
    const win: Record<string, any> = { dispatchEvent: (e: any) => events.push(e) };
    class FakeCustomEvent {
      type: string;
      detail: unknown;
      constructor(type: string, init?: { detail?: unknown }) {
        this.type = type;
        this.detail = init?.detail;
      }
    }
    for (const call of web.injectJavaScript.mock.calls) {
      new Function("window", "CustomEvent", call[0])(win, FakeCustomEvent);
    }
    return {
      calls: events.filter((e) => e.type === CALL_INTENT_EVENT).map((e) => e.detail),
      parked: win[CALL_INTENT_GLOBAL],
      order: events.map((e) => e.type),
    };
  }
  const load = (r: ReturnType<typeof render>) => fireEvent(r.getByTestId("cockpit-webview"), "loadEnd");

  it("asks the page to start the call once the page is up, not before", () => {
    const r = render(<CockpitScreen callIntent={{ via: "eleven", nonce: 1 }} />);
    expect(delivered().calls).toHaveLength(0);
    load(r);
    const d = delivered();
    expect(d.calls).toEqual([{ type: "call.start", via: "eleven", nonce: 1 }]);
    expect(d.parked).toEqual({ type: "call.start", via: "eleven", nonce: 1 });
  });

  it("tells the page the bridge is ready before asking it to call", () => {
    const r = render(<CockpitScreen callIntent={{ via: null, nonce: 1 }} />);
    load(r);
    const order = delivered().order;
    expect(order.indexOf(BRIDGE_EVENT)).toBeLessThan(order.indexOf(CALL_INTENT_EVENT));
  });

  it("delivers straight away to a page that is already loaded", () => {
    const r = render(<CockpitScreen />);
    load(r);
    r.rerender(<CockpitScreen callIntent={{ via: "gemini", nonce: 2 }} />);
    expect(delivered().calls).toEqual([{ type: "call.start", via: "gemini", nonce: 2 }]);
  });

  it("delivers a link once — not again on re-render, not again after a reload", () => {
    const r = render(<CockpitScreen />);
    load(r);
    const intent = { via: null, nonce: 3 };
    r.rerender(<CockpitScreen callIntent={intent} />);
    r.rerender(<CockpitScreen callIntent={{ ...intent }} />);
    // iOS killed the content process; the screen reloads the page.
    fireEvent(r.getByTestId("cockpit-webview"), "loadStart");
    load(r);
    expect(delivered().calls).toHaveLength(1);
  });

  it("a second link is a second call request", () => {
    const r = render(<CockpitScreen />);
    load(r);
    r.rerender(<CockpitScreen callIntent={{ via: null, nonce: 4 }} />);
    r.rerender(<CockpitScreen callIntent={{ via: "drill", nonce: 5 }} />);
    expect(delivered().calls.map((c) => c.nonce)).toEqual([4, 5]);
  });

  it("a failed load consumes the link: Try again loads the page and starts no call", () => {
    const r = render(<CockpitScreen callIntent={{ via: "eleven", nonce: 6 }} />);
    fireEvent(r.getByTestId("cockpit-webview"), "error", {
      nativeEvent: { description: "offline", code: -1009 },
    });
    fireEvent.press(r.getByTestId("cockpit-retry"));
    load(r);
    expect(delivered().calls).toHaveLength(0);
  });

  it("a link that arrives on the reconnect pane is consumed too", () => {
    const r = render(<CockpitScreen />);
    fireEvent(r.getByTestId("cockpit-webview"), "httpError", {
      nativeEvent: { statusCode: 502, description: "Bad Gateway" },
    });
    r.rerender(<CockpitScreen callIntent={{ via: null, nonce: 7 }} />);
    fireEvent.press(r.getByTestId("cockpit-retry"));
    load(r);
    expect(delivered().calls).toHaveLength(0);
  });

  it("waits for the page even when the tab is hidden, then delivers on load", () => {
    const r = render(<CockpitScreen visible={false} callIntent={{ via: null, nonce: 8 }} />);
    fireEvent(r.getByTestId("cockpit-webview", { includeHiddenElements: true }), "loadEnd");
    expect(delivered().calls).toHaveLength(1);
  });
});
