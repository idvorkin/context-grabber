import React from "react";
import { act, fireEvent, render, within } from "@testing-library/react-native";
import { activateKeepAwakeAsync, deactivateKeepAwake } from "expo-keep-awake";
import { CallScreen } from "../screens/CallScreen";
import { CallSession, type BridgeSocket, type CallAudio } from "../lib/callSession";
import { CallLog } from "../lib/callLog";
import * as Clipboard from "expo-clipboard";
import AudioRoute from "../modules/audio-route";

class FakeSocket implements BridgeSocket {
  binaryType = "blob";
  onopen: ((ev: unknown) => void) | null = null;
  onmessage: ((ev: { data: unknown }) => void) | null = null;
  onerror: ((ev: unknown) => void) | null = null;
  onclose: ((ev: unknown) => void) | null = null;
  sent: unknown[] = [];
  send(data: unknown) {
    this.sent.push(data);
  }
  close() {}
  say(m: Record<string, unknown>) {
    act(() => {
      this.onmessage?.({ data: JSON.stringify(m) });
    });
  }
}

const audio: CallAudio = {
  prepare: jest.fn(async () => {}),
  startMic: jest.fn(async () => {}),
  restartMic: jest.fn(async () => {}),
  openPlayback: jest.fn(),
  play: jest.fn(),
  flush: jest.fn(),
  stop: jest.fn(async () => {}),
};

const route = AudioRoute as unknown as { listeners: ((p: unknown) => void)[]; setOutput: jest.Mock; setInput: jest.Mock; getDevices: jest.Mock };

function setup(props: { cockpitCallLive?: boolean } = {}) {
  const socket = new FakeSocket();
  const log = new CallLog();
  const session = new CallSession({ connect: () => socket, audio, log }, "wss://h/bridge");
  const onBackendChange = jest.fn();
  const r = render(
    <CallScreen
      session={session}
      log={log}
      backend="gemini"
      onBackendChange={onBackendChange}
      cockpitCallLive={props.cockpitCallLive ?? false}
    />,
  );
  return { r, socket, session, onBackendChange, log };
}

const settle = () => act(async () => {});

async function goLive(t: ReturnType<typeof setup>) {
  fireEvent.press(t.r.getByTestId("call-start"));
  await settle();
  act(() => t.socket.onopen?.({}));
  t.socket.say({ type: "ready", out_rate: 24000, backend: "gemini", session: "s" });
  await settle();
}

describe("CallScreen", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    route.listeners = [];
  });

  it("idle: Call Larry, the backends, and no hang-up", () => {
    const { r } = setup();
    expect(r.getByTestId("call-start")).toBeTruthy();
    expect(r.queryByTestId("call-hangup")).toBeNull();
    expect(r.getByTestId("call-backend-gemini").props.accessibilityState.selected).toBe(true);
    expect(r.getByTestId("call-status").props.children).toBe("");
  });

  it("picking a backend is reported up, and locked once the call starts", async () => {
    const t = setup();
    fireEvent.press(t.r.getByTestId("call-backend-eleven"));
    expect(t.onBackendChange).toHaveBeenCalledWith("eleven");
    await goLive(t);
    fireEvent.press(t.r.getByTestId("call-backend-openai"));
    expect(t.onBackendChange).toHaveBeenCalledTimes(1);
  });

  it("Call Larry → connecting → live with a timer, mute and hang up", async () => {
    const t = setup();
    fireEvent.press(t.r.getByTestId("call-start"));
    await settle();
    expect(t.r.getByTestId("call-status").props.children).toBe("connecting… Gemini");
    expect(t.r.getByTestId("call-hangup")).toBeTruthy();
    act(() => t.socket.onopen?.({}));
    t.socket.say({ type: "ready", out_rate: 24000, backend: "gemini", session: "s" });
    await settle();
    expect(t.r.getByTestId("call-status").props.children).toMatch(/^live · \d+:\d\d · Gemini$/);
    expect(t.r.getByTestId("call-mute")).toBeTruthy();
  });

  it("captions: Igor pending in italics, Larry settled, a consult clamped and expandable", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "stt_partial", text: "hello" });
    expect(t.r.getByTestId(/^call-row-igor-/)).toBeTruthy();
    expect(t.r.getByText("hello")).toBeTruthy();
    t.socket.say({ type: "transcript", who: "larry", text: "Hi Igor." });
    expect(t.r.getByText("Hi Igor.")).toBeTruthy();
    t.socket.say({ type: "tool_call", question: "what next?" });
    const tool = t.r.getByTestId(/^call-row-tool-/);
    const words = t.r.getByText("asking Larry: what next? …");
    expect(words.props.numberOfLines).toBe(3);
    fireEvent.press(tool);
    expect(t.r.getByText("asking Larry: what next? …").props.numberOfLines).toBeUndefined();
    // Labels never wider than five characters (Cockpit DESIGN P24).
    for (const [who, a11y] of [["igor", "Igor"], ["larry", "Larry"], ["tool", "consult"]]) {
      const row = t.r.getByTestId(new RegExp(`^call-row-${who}-`));
      const label = within(row).getByLabelText(a11y).props.children as string;
      expect(label.length).toBeLessThanOrEqual(5);
    }
  });

  it("mute toggles and hang up ends the call with 'stopped'", async () => {
    const t = setup();
    await goLive(t);
    fireEvent.press(t.r.getByTestId("call-mute"));
    expect(t.session.snapshot.muted).toBe(true);
    expect(t.r.getByText("Unmute")).toBeTruthy();
    fireEvent.press(t.r.getByTestId("call-hangup"));
    await settle();
    expect(t.r.getByTestId("call-status").props.children).toBe("ended — stopped");
    expect(t.r.getByTestId("call-start")).toBeTruthy();
  });

  it("the bridge's ending is shown in the page's words", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "closed", reason: "idle timeout" });
    expect(t.r.getByTestId("call-status").props.children).toBe("ended — idle 2 min");
    expect(t.r.queryByText("Copy error")).toBeNull();
  });

  it("a lost connection is a copyable error", async () => {
    const t = setup();
    await goLive(t);
    act(() => t.socket.onclose?.({}));
    expect(t.r.getByTestId("call-status").props.children).toBe("ended — connection lost");
    expect(t.r.getByText("Copy error")).toBeTruthy();
  });

  it("a problem mid-call is copyable and the call stays live", async () => {
    const t = setup();
    await goLive(t);
    t.socket.say({ type: "error", message: "vendor 500" });
    expect(t.r.getByText("vendor 500")).toBeTruthy();
    expect(t.r.getByText("Copy error")).toBeTruthy();
    expect(t.r.getByTestId("call-hangup")).toBeTruthy();
  });

  it("refuses to start while the Cockpit page has a call live", () => {
    const { r, session } = setup({ cockpitCallLive: true });
    expect(r.getByTestId("call-blocked").props.children).toBe("a call is live in the Cockpit tab");
    fireEvent.press(r.getByTestId("call-start"));
    expect(session.snapshot.state).toBe("idle");
  });

  it("holds the screen awake for exactly the call", async () => {
    const t = setup();
    expect(activateKeepAwakeAsync).not.toHaveBeenCalled();
    await goLive(t);
    expect(activateKeepAwakeAsync).toHaveBeenCalledWith("call");
    fireEvent.press(t.r.getByTestId("call-hangup"));
    await settle();
    expect(deactivateKeepAwake).toHaveBeenCalledWith("call");
  });

  it("folds the pickers under one line that names the route; unfolds on tap", async () => {
    const t = setup();
    await settle();
    expect(t.r.getByTestId("call-devices-summary").props.children).toBe("iPhone Microphone · Speaker");
    expect(t.r.queryByTestId("call-inputs")).toBeNull();
    fireEvent.press(t.r.getByTestId("call-devices-toggle"));
    expect(t.r.getByTestId("call-inputs")).toBeTruthy();
    expect(t.r.getByTestId("call-outputs")).toBeTruthy();
    fireEvent.press(t.r.getByTestId("call-devices-toggle"));
    expect(t.r.queryByTestId("call-inputs")).toBeNull();
  });

  it("the level strip follows the mic, dimmed while muted, flat after the call", async () => {
    const t = setup();
    await goLive(t);
    const width = () => t.r.getByTestId("call-mic-meter").props.children.props.style.at(-1).width;
    expect(width()).toBe("0%");
    const loud = new Float32Array(480).fill(0.5);
    const feed = (audio.startMic as jest.Mock).mock.calls[0][0] as (s: Float32Array, r: number) => void;
    act(() => feed(loud, 48000));
    expect(parseInt(width(), 10)).toBeGreaterThan(80);
    fireEvent.press(t.r.getByTestId("call-mute"));
    act(() => feed(loud, 48000));
    expect(parseInt(width(), 10)).toBeGreaterThan(80);
    fireEvent.press(t.r.getByTestId("call-hangup"));
    await settle();
    expect(width()).toBe("0%");
  });

  it("a USB microphone becomes the mic on its own, unless Igor picked one by hand", async () => {
    const usb = { id: "USB-1", name: "Scarlett Solo", type: "USBAudio" };
    const base = (AudioRoute as unknown as { snapshot: { inputs: unknown[] } }).snapshot;
    const withUsb = { ...base, inputs: [...base.inputs, usb] };
    const t = setup();
    await settle();
    expect(route.setInput).not.toHaveBeenCalled();
    // idle: a USB mic in the roster changes nothing
    act(() => {
      for (const l of route.listeners) l({ ...withUsb, reason: "NewDeviceAvailable" });
    });
    expect(route.setInput).not.toHaveBeenCalled();
    await goLive(t);
    // plugged in mid-call: the roster changes
    act(() => {
      for (const l of route.listeners) l({ ...withUsb, reason: "NewDeviceAvailable" });
    });
    expect(route.setInput).toHaveBeenLastCalledWith("USB-1");
    // iOS moved the output to the USB device along with the input — put it back
    await settle();
    expect(route.setOutput).not.toHaveBeenCalled();
    route.setInput.mockImplementationOnce(async () => ({
      ...withUsb,
      current: { input: usb, output: usb },
    }));
    act(() => {
      for (const l of route.listeners) l({ ...withUsb, current: { input: base.inputs[0], output: { id: "speaker", name: "Speaker", type: "Speaker" } }, reason: "NewDeviceAvailable" });
    });
    await settle();
    expect(route.setOutput).toHaveBeenLastCalledWith("speaker");
    // Igor picks the built-in mic by hand; a re-plug no longer overrides him
    fireEvent.press(t.r.getByTestId("call-devices-toggle"));
    route.setInput.mockClear();
    fireEvent.press(t.r.getByTestId("call-inputs-BuiltInMicrophoneBottom"));
    expect(route.setInput).toHaveBeenLastCalledWith("BuiltInMicrophoneBottom");
    route.setInput.mockClear();
    act(() => {
      for (const l of route.listeners) l({ ...withUsb, reason: "NewDeviceAvailable" });
    });
    expect(route.setInput).not.toHaveBeenCalled();
  });

  it("does not offer a USB mic receiver as an output", async () => {
    const usb = { id: "USB-1", name: "Wireless Mic RX", type: "USBAudio" };
    const base = (AudioRoute as unknown as { snapshot: { inputs: unknown[]; outputs: unknown[] } }).snapshot;
    const t = setup();
    await settle();
    act(() => {
      for (const l of route.listeners) l({ ...base, outputs: [...base.outputs, usb], reason: "NewDeviceAvailable" });
    });
    fireEvent.press(t.r.getByTestId("call-devices-toggle"));
    expect(t.r.queryByTestId("call-outputs-USB-1")).toBeNull();
    expect(t.r.getByTestId("call-outputs-speaker")).toBeTruthy();
  });

  it("diagnostics: the log unfolds and copies with build, state and roster", async () => {
    const t = setup();
    await goLive(t);
    expect(t.r.queryByTestId("call-diag")).toBeNull();
    fireEvent.press(t.r.getByTestId("call-diag-toggle"));
    expect(t.r.getByText(/start backend=gemini bridge=wss:\/\/h\/bridge/)).toBeTruthy();
    expect(t.r.getByText(/ready: out_rate=24000/)).toBeTruthy();
    await act(async () => {
      fireEvent.press(t.r.getByTestId("call-diag-copy"));
    });
    const copied = (Clipboard.setStringAsync as jest.Mock).mock.calls.at(-1)[0] as string;
    expect(copied).toMatch(/^build: /m);
    expect(copied).toMatch(/^state: live/m);
    expect(copied).toMatch(/^route: in=iPhone Microphone\[MicrophoneBuiltIn\]/m);
    expect(copied).toMatch(/ready: out_rate=24000/);
  });

  it("shows the real device roster and applies a pick", async () => {
    const t = setup();
    await settle();
    fireEvent.press(t.r.getByTestId("call-devices-toggle"));
    expect(t.r.getByTestId("call-inputs")).toBeTruthy();
    fireEvent.press(t.r.getByTestId("call-outputs-speaker"));
    expect(route.setOutput).toHaveBeenCalledWith("speaker");
    fireEvent.press(t.r.getByTestId("call-inputs-AC:12:34:56:78:9A-tacl"));
    expect(route.setInput).toHaveBeenCalledWith("AC:12:34:56:78:9A-tacl");
  });

  it("re-reads the route shortly after a pick, in case iOS applied it late", async () => {
    jest.useFakeTimers();
    try {
      const t = setup();
      await settle();
      fireEvent.press(t.r.getByTestId("call-devices-toggle"));
      route.getDevices.mockClear();
      fireEvent.press(t.r.getByTestId("call-outputs-speaker"));
      expect(route.getDevices).not.toHaveBeenCalled();
      await act(async () => {
        jest.advanceTimersByTime(500);
      });
      expect(route.getDevices).toHaveBeenCalledTimes(1);
    } finally {
      jest.useRealTimers();
    }
  });
});
