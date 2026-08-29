import { describeRoute, preferredInput, usbInput } from "../lib/callDevices";
import type { AudioRouteSnapshot } from "../modules/audio-route";

const builtIn = { id: "BuiltInMicrophoneBottom", name: "iPhone Microphone", type: "MicrophoneBuiltIn" };
const airpods = { id: "AC:12-tacl", name: "AirPods Pro", type: "BluetoothHFP" };
const usb = { id: "USB-1234", name: "Scarlett Solo", type: "USBAudio" };
const speaker = { id: "speaker", name: "Speaker", type: "Speaker" };

function snap(inputs: typeof builtIn[], current = inputs[0]): AudioRouteSnapshot {
  return {
    inputs,
    outputs: [speaker],
    current: { input: current, output: speaker },
    capabilities: { selectInput: true, selectOutput: true, forceSpeaker: true },
  };
}

describe("usbInput / preferredInput", () => {
  it("no USB mic → nothing to do", () => {
    expect(usbInput(snap([builtIn, airpods]))).toBeNull();
    expect(preferredInput(snap([builtIn, airpods]))).toBeNull();
  });

  it("a USB mic that is not current wins", () => {
    expect(preferredInput(snap([builtIn, usb], builtIn))).toBe("USB-1234");
    expect(preferredInput(snap([builtIn, airpods, usb], airpods))).toBe("USB-1234");
  });

  it("already on the USB mic → stay", () => {
    expect(preferredInput(snap([builtIn, usb], usb))).toBeNull();
  });
});

describe("describeRoute", () => {
  it("names the current mic and output", () => {
    expect(describeRoute(snap([builtIn]))).toBe("iPhone Microphone · Speaker");
    expect(describeRoute(null)).toBe("");
  });

  it("copes with a route that has no input yet", () => {
    const s = snap([builtIn]);
    s.current.input = null;
    expect(describeRoute(s)).toBe("no mic · Speaker");
  });
});
