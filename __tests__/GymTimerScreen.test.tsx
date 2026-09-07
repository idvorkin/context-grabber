import React from "react";
import { act, fireEvent, render } from "@testing-library/react-native";
import { Accelerometer } from "expo-sensors";
import * as Clipboard from "expo-clipboard";
import GymTimerScreen from "../components/GymTimerScreen";

// The jest.setup mock of expo-sensors lets a test hold the phone.
const phone = Accelerometer as unknown as {
  __emit(reading: { x: number; y: number; z: number }): void;
  __listenerCount(): number;
};
const hold = (x: number, y: number) => act(async () => phone.__emit({ x, y, z: 0 }));
const settle = () => act(async () => {});

describe("GymTimerScreen — the LED look and the turn", () => {
  it("draws the time as seven-segment LEDs with ghost bars, white before the first start", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} />);
    await settle();
    const label = r.getByTestId("timer-time").props.accessibilityLabel as string;
    expect(label).toMatch(/^\d{1,2}:\d\d$/); // the 30-second preset reads 0:30, as it always has
    // Every digit has all seven bars drawn (lit or ghost) and a colon of two dots.
    expect(r.getAllByTestId(/^led-glyph-/).length).toBe(label.replace(":", "").length);
    expect(r.getByTestId("led-colon")).toBeTruthy();
    const zero = r.getAllByTestId("led-glyph-0")[0];
    expect(zero.props.children.filter(Boolean).length).toBe(7); // every bar drawn, lit or ghost
    expect(r.queryByTestId("timer-turned")).toBeNull();
    expect(r.getByTestId("timer-screen-upright")).toBeTruthy();
  });

  it("turned on its side, the face fills the screen sideways, a tap starts and stops, and back upright the timer is still going", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} />);
    await settle();
    expect(phone.__listenerCount()).toBe(1);

    await hold(-1, 0); // top of the phone to the left
    expect(r.getByTestId("timer-screen-turned")).toBeTruthy();
    expect(r.queryByText("Gym Timer")).toBeNull(); // no chrome
    expect(r.getByText("tap to start")).toBeTruthy();

    fireEvent.press(r.getByTestId("timer-turned"));
    await settle();
    expect(r.getByText("tap to stop")).toBeTruthy();

    await hold(0, -1); // upright again
    expect(r.queryByTestId("timer-turned")).toBeNull();
    expect(r.getByText("Gym Timer")).toBeTruthy();
    expect(r.getByText("STOP")).toBeTruthy(); // still running: the turn did not reset it

    await hold(1, 0); // top to the right: turned again (which way is the pure test's business)
    expect(r.getByTestId("timer-screen-turned")).toBeTruthy();

    r.unmount();
    expect(phone.__listenerCount()).toBe(0);
  });

  it("Custom: a fifth chip with sliders in tens starting at 1:00; the face follows; locked while running", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} />);
    await settle();
    expect(r.queryByTestId("custom-controls")).toBeNull();
    fireEvent.press(r.getByTestId("preset-custom"));
    await settle();
    expect(r.getByTestId("custom-controls")).toBeTruthy();
    expect(r.getByTestId("custom-work-value").props.children).toBe("1:00");
    expect(r.getByTestId("timer-time").props.accessibilityLabel).toBe("1:00");

    fireEvent.press(r.getByTestId("custom-work-plus"));
    await settle();
    expect(r.getByTestId("custom-work-value").props.children).toBe("1:10");
    expect(r.getByTestId("timer-time").props.accessibilityLabel).toBe("1:10"); // the face follows while idle

    fireEvent.press(r.getByText("START"));
    await settle();
    fireEvent.press(r.getByTestId("custom-work-plus")); // locked: nothing changes
    await settle();
    expect(r.getByTestId("custom-work-value").props.children).toBe("1:10");

    fireEvent.press(r.getByText("RESET"));
    await settle();
    fireEvent.press(r.getByTestId("custom-work-minus"));
    await settle();
    expect(r.getByTestId("custom-work-value").props.children).toBe("1:00"); // live again, and remembered through RESET
  });

  it("Log copies the timer log with a build header to the clipboard", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} />);
    await settle();
    fireEvent.press(r.getByText("START"));
    await settle();
    await act(async () => {
      fireEvent.press(r.getByTestId("timer-copy-log"));
    });
    const copied = (Clipboard.setStringAsync as jest.Mock).mock.calls.at(-1)?.[0] as string;
    expect(copied).toMatch(/^build: /);
    expect(copied).toContain("mode: rounds");
    expect(copied).toMatch(/duck window open/); // START's GO opened one
    expect(r.getByText("Copied")).toBeTruthy();
  });

  it("stopwatch: LED minutes and seconds with smaller hundredths; sets: a green LED count that a turned tap raises", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} initialMode="stopwatch" />);
    await settle();
    expect(r.getByTestId("timer-time").props.accessibilityLabel).toBe("00:00");
    expect(r.getByTestId("timer-fraction").props.accessibilityLabel).toBe(".00");

    fireEvent.press(r.getByText("SETS"));
    await settle();
    expect(r.getByTestId("timer-time").props.accessibilityLabel).toBe("0");
    await hold(1, 0);
    expect(r.getByText("tap to count")).toBeTruthy();
    fireEvent.press(r.getByTestId("timer-turned"));
    await settle();
    expect(r.getByTestId("timer-time").props.accessibilityLabel).toBe("1");
  });
});
