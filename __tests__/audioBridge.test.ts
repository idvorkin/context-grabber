import {
  BRIDGE_EVENT,
  BRIDGE_GLOBAL,
  BRIDGE_VERSION,
  bridgeEmitScript,
  bridgeInstallScript,
  describeError,
  devicesPayload,
  errorPayload,
  parseBridgeRequest,
  readyPayload,
  routeChangedPayload,
} from "../lib/audioBridge";
import type { AudioRouteSnapshot } from "../modules/audio-route";

const SNAPSHOT: AudioRouteSnapshot = {
  inputs: [
    { id: "BuiltInMicrophoneBottom", name: "iPhone Microphone", type: "MicrophoneBuiltIn" },
    { id: "AC:12:34:56:78:9A-tacl", name: "AirPods Pro", type: "BluetoothHFP" },
  ],
  outputs: [
    { id: "auto", name: "Automatic", type: "auto" },
    { id: "speaker", name: "Speaker", type: "Speaker" },
    { id: "AC:12:34:56:78:9A-tacl", name: "AirPods Pro", type: "BluetoothHFP" },
  ],
  current: {
    input: { id: "BuiltInMicrophoneBottom", name: "iPhone Microphone", type: "MicrophoneBuiltIn" },
    output: { id: "speaker", name: "Speaker", type: "Speaker" },
  },
  capabilities: { selectInput: true, selectOutput: true, forceSpeaker: true },
};

/**
 * Evaluate an injected script the way the page would, against a minimal
 * window stand-in. The injected string IS the wire format, so running it is
 * the only honest way to test it without a phone.
 */
function runInFakePage(script: string, win: Record<string, unknown>) {
  const fn = new Function("window", "CustomEvent", `${script}`);
  class FakeCustomEvent {
    type: string;
    detail: unknown;
    constructor(type: string, init?: { detail?: unknown }) {
      this.type = type;
      this.detail = init?.detail;
    }
  }
  return fn(win, FakeCustomEvent);
}

describe("parseBridgeRequest", () => {
  it("reads a bare listDevices", () => {
    expect(parseBridgeRequest(JSON.stringify({ type: "audio.listDevices" }))).toEqual({
      type: "audio.listDevices",
    });
  });

  it("echoes a requestId when one is supplied", () => {
    expect(
      parseBridgeRequest(JSON.stringify({ type: "audio.getRoute", requestId: "r1" })),
    ).toEqual({ type: "audio.getRoute", requestId: "r1" });
  });

  it("drops a non-string requestId rather than passing it through", () => {
    expect(
      parseBridgeRequest(JSON.stringify({ type: "audio.listDevices", requestId: 7 })),
    ).toEqual({ type: "audio.listDevices" });
  });

  it("normalizes every spelling of 'system default' on setInput", () => {
    for (const raw of [
      { type: "audio.setInput" },
      { type: "audio.setInput", id: null },
      { type: "audio.setInput", id: "" },
    ]) {
      expect(parseBridgeRequest(JSON.stringify(raw))).toEqual({
        type: "audio.setInput",
        id: null,
      });
    }
  });

  it("keeps a real input id", () => {
    expect(
      parseBridgeRequest(JSON.stringify({ type: "audio.setInput", id: "mic-bt" })),
    ).toEqual({ type: "audio.setInput", id: "mic-bt" });
  });

  it("accepts `id` as an alias of `port` on setOutput", () => {
    expect(
      parseBridgeRequest(JSON.stringify({ type: "audio.setOutput", id: "speaker" })),
    ).toEqual({ type: "audio.setOutput", port: "speaker" });
    expect(
      parseBridgeRequest(JSON.stringify({ type: "audio.setOutput", port: "auto" })),
    ).toEqual({ type: "audio.setOutput", port: "auto" });
  });

  it("rejects a setOutput with no destination at all", () => {
    expect(parseBridgeRequest(JSON.stringify({ type: "audio.setOutput" }))).toBeNull();
  });

  it("ignores traffic that is not ours", () => {
    // The page owns postMessage and may be using it for something else.
    expect(parseBridgeRequest(JSON.stringify({ type: "cockpit.decision" }))).toBeNull();
    expect(parseBridgeRequest("not json at all")).toBeNull();
    expect(parseBridgeRequest(JSON.stringify(["audio.listDevices"]))).toBeNull();
    expect(parseBridgeRequest(JSON.stringify(null))).toBeNull();
    expect(parseBridgeRequest("")).toBeNull();
    expect(parseBridgeRequest(undefined)).toBeNull();
    expect(parseBridgeRequest(42)).toBeNull();
  });
});

describe("payload builders", () => {
  it("stamps a type onto a snapshot without disturbing it", () => {
    const payload = devicesPayload(SNAPSHOT, "r9");
    expect(payload.type).toBe("audio.devices");
    expect(payload.requestId).toBe("r9");
    expect(payload.inputs).toEqual(SNAPSHOT.inputs);
    expect(payload.current).toEqual(SNAPSHOT.current);
  });

  it("omits requestId entirely for a fire-and-forget answer", () => {
    expect("requestId" in devicesPayload(SNAPSHOT)).toBe(false);
  });

  it("carries the route-change reason through", () => {
    const payload = routeChangedPayload({ ...SNAPSHOT, reason: "oldDeviceUnavailable" });
    expect(payload.type).toBe("audio.routeChanged");
    expect(payload.reason).toBe("oldDeviceUnavailable");
  });

  it("reports whether the native module is there at all", () => {
    expect(readyPayload(true)).toEqual({
      type: "audio.ready",
      version: BRIDGE_VERSION,
      platform: "ios",
      available: true,
    });
    expect(readyPayload(false).available).toBe(false);
  });

  it("names the operation that failed", () => {
    expect(errorPayload("audio.setInput", "Input not available: x", "r3")).toEqual({
      type: "audio.error",
      op: "audio.setInput",
      message: "Input not available: x",
      requestId: "r3",
    });
  });
});

describe("describeError", () => {
  it("prefers a real message", () => {
    expect(describeError(new Error("Input not available: x"))).toBe(
      "Input not available: x",
    );
    expect(describeError("plain string")).toBe("plain string");
  });

  it("never hands the page an empty string", () => {
    expect(describeError(new Error(""))).toBe("Unknown audio error");
    expect(describeError(undefined)).toBe("Unknown audio error");
    expect(describeError({})).toBe("Unknown audio error");
  });
});

describe("bridgeInstallScript", () => {
  it("installs a feature-detectable global", () => {
    const win: Record<string, any> = {};
    runInFakePage(bridgeInstallScript(), win);
    const bridge = win[BRIDGE_GLOBAL];
    expect(bridge.version).toBe(BRIDGE_VERSION);
    expect(bridge.platform).toBe("ios");
    expect(bridge.last).toBeNull();
  });

  it("posts well-formed requests the parser accepts", () => {
    const sent: string[] = [];
    const win: Record<string, any> = {
      ReactNativeWebView: { postMessage: (m: string) => sent.push(m) },
    };
    runInFakePage(bridgeInstallScript(), win);
    const bridge = win[BRIDGE_GLOBAL];

    bridge.listDevices("a");
    bridge.setInput("mic-bt", "b");
    bridge.setOutput("speaker", "c");
    bridge.getRoute();

    // Round-trip: what the injected helper emits is exactly what the native
    // side parses. Drift between the two ends is the whole risk here.
    expect(sent.map(parseBridgeRequest)).toEqual([
      { type: "audio.listDevices", requestId: "a" },
      { type: "audio.setInput", id: "mic-bt", requestId: "b" },
      { type: "audio.setOutput", port: "speaker", requestId: "c" },
      { type: "audio.getRoute" },
    ]);
  });

  it("does not throw when ReactNativeWebView is missing", () => {
    const win: Record<string, any> = {};
    runInFakePage(bridgeInstallScript(), win);
    expect(() => win[BRIDGE_GLOBAL].listDevices()).not.toThrow();
  });

  it("is idempotent — a re-injection keeps the existing bridge", () => {
    const win: Record<string, any> = {};
    runInFakePage(bridgeInstallScript(), win);
    const first = win[BRIDGE_GLOBAL];
    first.last = { marker: true };
    runInFakePage(bridgeInstallScript(), win);
    expect(win[BRIDGE_GLOBAL]).toBe(first);
    expect(win[BRIDGE_GLOBAL].last).toEqual({ marker: true });
  });

  it("ends in a primitive, which iOS requires of an injected script", () => {
    expect(bridgeInstallScript().trimEnd().endsWith("true;")).toBe(true);
  });
});

describe("bridgeEmitScript", () => {
  function emitInto(payload: Parameters<typeof bridgeEmitScript>[0]) {
    const events: { type: string; detail: any }[] = [];
    const win: Record<string, any> = {
      dispatchEvent: (e: any) => events.push(e),
    };
    runInFakePage(bridgeInstallScript(), win);
    runInFakePage(bridgeEmitScript(payload), win);
    return { win, events };
  }

  it("dispatches the payload on its own event type", () => {
    const { events } = emitInto(devicesPayload(SNAPSHOT, "r1"));
    expect(events).toHaveLength(1);
    expect(events[0].type).toBe(BRIDGE_EVENT);
    expect(events[0].detail).toEqual({
      type: "audio.devices",
      requestId: "r1",
      ...SNAPSHOT,
    });
  });

  it("records the payload on `last` for a listener that attached late", () => {
    const { win } = emitInto(routeChangedPayload({ ...SNAPSHOT, reason: "override" }));
    expect(win[BRIDGE_GLOBAL].last.reason).toBe("override");
  });

  it("survives a device name full of quotes, newlines and script tags", () => {
    // A Bluetooth device is named by whoever paired it, and that name lands
    // inside a script we evaluate.
    const nasty = `He said "hi"\n</script>\\ '     ${"`"}${"${x}"}`;
    const payload = devicesPayload({
      ...SNAPSHOT,
      inputs: [{ id: "x", name: nasty, type: "BluetoothHFP" }],
    });
    const { events } = emitInto(payload);
    expect(events[0].detail.inputs[0].name).toBe(nasty);
  });

  it("does not blow up when no bridge global was installed", () => {
    const events: any[] = [];
    const win: Record<string, any> = { dispatchEvent: (e: any) => events.push(e) };
    expect(() => runInFakePage(bridgeEmitScript(readyPayload(true)), win)).not.toThrow();
    expect(events[0].detail.type).toBe("audio.ready");
  });

  it("swallows a page that has no dispatchEvent rather than throwing into iOS", () => {
    const win: Record<string, any> = {};
    expect(() => runInFakePage(bridgeEmitScript(readyPayload(true)), win)).not.toThrow();
  });

  it("ends in a primitive, which iOS requires of an injected script", () => {
    expect(bridgeEmitScript(readyPayload(true)).trimEnd().endsWith("true;")).toBe(true);
  });
});
