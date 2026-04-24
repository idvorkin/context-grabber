import { parseDeepLink } from "../lib/deepLink";

describe("parseDeepLink — scheme handling", () => {
  it("parses both schemes identically for the same path", () => {
    const short = parseDeepLink("grabber://timer?preset=1min&autostart=1");
    const long = parseDeepLink("com.idvorkin.contextgrabber://timer?preset=1min&autostart=1");
    expect(short).toEqual(long);
  });

  it("returns unknown for null / undefined / empty", () => {
    expect(parseDeepLink(null)).toEqual({ kind: "unknown" });
    expect(parseDeepLink(undefined)).toEqual({ kind: "unknown" });
    expect(parseDeepLink("")).toEqual({ kind: "unknown" });
  });

  it("returns unknown for an unrelated scheme", () => {
    expect(parseDeepLink("https://example.com/timer")).toEqual({ kind: "unknown" });
    expect(parseDeepLink("someotherapp://timer")).toEqual({ kind: "unknown" });
  });
});

describe("parseDeepLink — main route", () => {
  it("opens main for an empty path", () => {
    expect(parseDeepLink("grabber://")).toEqual({ kind: "main", autoGrab: false });
  });

  it("opens main for explicit /main", () => {
    expect(parseDeepLink("grabber://main")).toEqual({ kind: "main", autoGrab: false });
  });

  it("opens main + auto-grabs for /grab", () => {
    expect(parseDeepLink("grabber://grab")).toEqual({ kind: "main", autoGrab: true });
  });

  it("ignores query params on main routes", () => {
    expect(parseDeepLink("grabber://main?ignored=1")).toEqual({ kind: "main", autoGrab: false });
    expect(parseDeepLink("grabber://grab?also=ignored")).toEqual({ kind: "main", autoGrab: true });
  });
});

describe("parseDeepLink — timer route", () => {
  it("opens rounds mode with no preset and no autostart when bare", () => {
    expect(parseDeepLink("grabber://timer")).toEqual({
      kind: "timer",
      mode: "rounds",
      preset: null,
      autostart: false,
    });
  });

  it("accepts all three known presets", () => {
    expect(parseDeepLink("grabber://timer?preset=30sec")).toEqual({
      kind: "timer",
      mode: "rounds",
      preset: "30sec",
      autostart: false,
    });
    expect(parseDeepLink("grabber://timer?preset=1min")).toEqual({
      kind: "timer",
      mode: "rounds",
      preset: "1min",
      autostart: false,
    });
    expect(parseDeepLink("grabber://timer?preset=5-1")).toEqual({
      kind: "timer",
      mode: "rounds",
      preset: "5-1",
      autostart: false,
    });
  });

  it("drops unknown preset values to null (fallback to last selection in UI)", () => {
    const route = parseDeepLink("grabber://timer?preset=nonsense");
    expect(route).toEqual({ kind: "timer", mode: "rounds", preset: null, autostart: false });
  });

  it("honors autostart=1", () => {
    expect(parseDeepLink("grabber://timer?preset=1min&autostart=1")).toEqual({
      kind: "timer",
      mode: "rounds",
      preset: "1min",
      autostart: true,
    });
  });

  it("treats autostart other than '1' as false", () => {
    const r1 = parseDeepLink("grabber://timer?preset=1min&autostart=true");
    const r2 = parseDeepLink("grabber://timer?preset=1min&autostart=0");
    expect(r1.kind).toBe("timer");
    expect(r2.kind).toBe("timer");
    if (r1.kind === "timer") expect(r1.autostart).toBe(false);
    if (r2.kind === "timer") expect(r2.autostart).toBe(false);
  });

  it("opens stopwatch mode via /timer/stopwatch", () => {
    expect(parseDeepLink("grabber://timer/stopwatch")).toEqual({
      kind: "timer",
      mode: "stopwatch",
      preset: null,
      autostart: false,
    });
  });

  it("opens sets mode via /timer/sets", () => {
    expect(parseDeepLink("grabber://timer/sets")).toEqual({
      kind: "timer",
      mode: "sets",
      preset: null,
      autostart: false,
    });
  });

  it("ignores unrecognized timer sub-paths (falls back to rounds)", () => {
    const route = parseDeepLink("grabber://timer/bogus");
    expect(route).toEqual({ kind: "timer", mode: "rounds", preset: null, autostart: false });
  });
});

describe("parseDeepLink — unknown routes", () => {
  it("returns unknown for an unknown top-level path", () => {
    expect(parseDeepLink("grabber://whatever")).toEqual({ kind: "unknown" });
  });
});
