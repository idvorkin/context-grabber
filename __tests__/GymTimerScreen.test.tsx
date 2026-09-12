import React from "react";
import { act, fireEvent, render, within } from "@testing-library/react-native";
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
    expect(copied).toMatch(/phase idle → prep/); // START ran the ready count
    expect(copied).not.toMatch(/cue go/); // and said nothing itself
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

describe("GymTimerScreen — paused, said big", () => {
  it("rounds: STOP puts an amber PAUSEd over the frozen time in place of the phase word; RESUME brings the word back; turned, the edge says tap to resume", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} />);
    await settle();
    expect(r.queryByTestId("timer-paused")).toBeNull(); // idle is idle, not paused

    fireEvent.press(r.getByText("START"));
    await settle();
    expect(r.getByTestId("timer-word").props.accessibilityLabel).toBe("rEAdY");
    expect(r.queryByTestId("timer-paused")).toBeNull();

    fireEvent.press(r.getByText("STOP"));
    await settle();
    expect(r.getByTestId("timer-paused").props.accessibilityLabel).toBe("PAUSEd");
    expect(r.queryByTestId("timer-word")).toBeNull();
    expect(r.getByText("RESUME")).toBeTruthy();

    await hold(-1, 0); // turned while paused
    expect(r.getByText("tap to resume")).toBeTruthy();
    expect(r.getByTestId("timer-paused")).toBeTruthy();
    fireEvent.press(r.getByTestId("timer-turned")); // resume
    await settle();
    expect(r.getByText("tap to stop")).toBeTruthy();
    expect(r.queryByTestId("timer-paused")).toBeNull();
    expect(r.getByTestId("timer-word").props.accessibilityLabel).toBe("rEAdY");
    await hold(0, -1);
  });

  it("stopwatch: stopped with time on it is paused; reset clears it", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} initialMode="stopwatch" />);
    await settle();
    fireEvent.press(r.getByText("START"));
    await act(async () => { await new Promise((res) => setTimeout(res, 30)); });
    expect(r.queryByTestId("timer-paused")).toBeNull();
    fireEvent.press(r.getByText("STOP"));
    await settle();
    expect(r.getByTestId("timer-paused").props.accessibilityLabel).toBe("PAUSEd");
    fireEvent.press(r.getByText("RESET"));
    await settle();
    expect(r.queryByTestId("timer-paused")).toBeNull();
  });
});

describe("GymTimerScreen — the accessory log, read back", () => {
  type Row = { id: number; item_id: string; item_name: string; logged_at: number; date_key: string };
  /** The same in-memory store the lib tests use: inserts land, reads honour the since-filter. */
  function makeDb(seed: Row[] = []) {
    const rows: Row[] = [...seed];
    let nextId = rows.length + 1;
    return {
      execAsync: jest.fn(async () => undefined),
      runAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
        if (/INSERT\s+INTO\s+accessory_log/i.test(sql)) {
          const [item_id, item_name, logged_at, date_key] = params as [string, string, number, string];
          rows.push({ id: nextId++, item_id, item_name, logged_at, date_key });
        }
        return { changes: 1, lastInsertRowId: nextId - 1 };
      }),
      getAllAsync: jest.fn(async (sql: string, params: unknown[] = []) => {
        let out = [...rows];
        if (/WHERE\s+logged_at\s*>=\s*\?/i.test(sql)) out = out.filter((r) => r.logged_at >= (params[0] as number));
        return out.sort((a, b) => b.logged_at - a.logged_at);
      }),
      getFirstAsync: jest.fn(),
    };
  }
  const dateKey = (ms: number) => {
    const d = new Date(ms);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  };

  it("empty: the sheet says nothing was logged in the last 7 days", async () => {
    const r = render(<GymTimerScreen onExit={jest.fn()} db={makeDb() as any} />);
    await settle();
    fireEvent.press(r.getByTestId("open-accessory-log"));
    await settle();
    expect(r.getByText("Nothing logged in the last 7 days")).toBeTruthy();
  });

  it("a save shows up under Today on the next open, with its time and both names; an eight-day-old entry does not", async () => {
    const stale = Date.now() - 8 * 24 * 3600 * 1000;
    const db = makeDb([{ id: 1, item_id: "pigeon_stretch", item_name: "Pigeon Stretch", logged_at: stale, date_key: dateKey(stale) }]);
    const r = render(<GymTimerScreen onExit={jest.fn()} db={db as any} />);
    await settle();

    fireEvent.press(r.getByTestId("open-accessory-log"));
    await settle();
    expect(r.getByText("Nothing logged in the last 7 days")).toBeTruthy(); // the stale row is outside the window
    fireEvent.press(r.getByTestId("accessory-item-half_lotus"));
    fireEvent.press(r.getByTestId("accessory-item-dead_hangs"));
    fireEvent.press(r.getByTestId("accessory-save"));
    await settle();
    expect(r.queryByTestId("accessory-history")).toBeNull(); // the sheet closed

    fireEvent.press(r.getByTestId("open-accessory-log"));
    await settle();
    const history = within(r.getByTestId("accessory-history"));
    expect(history.getByText("Today")).toBeTruthy();
    expect(history.getByText(/^\d{1,2}(:\d\d)?(am|pm) · Half Lotus, Dead Hangs$/)).toBeTruthy();
    expect(history.queryByText(/Pigeon Stretch/)).toBeNull();
    expect(history.queryByText(/Nothing logged/)).toBeNull();
  });

  it("a read failure keeps the checklist and shows a copyable error", async () => {
    const db = makeDb();
    db.getAllAsync.mockRejectedValueOnce(new Error("disk says no"));
    const r = render(<GymTimerScreen onExit={jest.fn()} db={db as any} />);
    await settle();
    fireEvent.press(r.getByTestId("open-accessory-log"));
    await settle();
    expect(r.getByText("disk says no")).toBeTruthy();
    expect(r.getByTestId("accessory-item-half_lotus")).toBeTruthy();
    expect(r.queryByText(/Nothing logged/)).toBeNull();
  });
});
