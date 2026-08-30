import type { AudioDevice, AudioInputState, AudioRouteSnapshot } from "../modules/audio-route";

/**
 * Which microphone a call should be on, given what is attached.
 *
 * Igor, 2026-08-29: "If a mic is over USB, let's take that as a default."
 * A USB audio interface is the deliberate choice — nobody plugs one in by
 * accident — so it wins over whatever iOS picked, unless Igor picked
 * something himself (the caller tracks that; this is just the rule).
 *
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md,
 * "The devices line".
 */

/** `AVAudioSession.Port.usbAudio.rawValue` */
export const USB_PORT_TYPE = "USBAudio";

export function usbInput(snapshot: AudioRouteSnapshot): AudioDevice | null {
  return snapshot.inputs.find((d) => d.type === USB_PORT_TYPE) ?? null;
}

/** The input id to switch to, or `null` when the current one should stay. */
export function preferredInput(snapshot: AudioRouteSnapshot): string | null {
  const usb = usbInput(snapshot);
  if (!usb) return null;
  if (snapshot.current.input?.id === usb.id) return null;
  return usb.id;
}

/**
 * What the output picker offers. A USB device is listed only while iOS is
 * actually playing through it: the native module lists every USB *input*
 * as a steerable output (right for a USB headset), but a wireless-mic
 * receiver has no speaker, and offering it is offering silence.
 */
export function offeredOutputs(snapshot: AudioRouteSnapshot): AudioDevice[] {
  const currentId = snapshot.current.output?.id;
  return snapshot.outputs.filter((d) => d.type !== USB_PORT_TYPE || d.id === currentId);
}

/** "iPhone Microphone · Speaker" — the folded devices line. */
export function describeRoute(snapshot: AudioRouteSnapshot | null): string {
  if (!snapshot) return "";
  const input = snapshot.current.input?.name ?? "no mic";
  const output = snapshot.current.output?.name ?? "no output";
  return `${input} · ${output}`;
}

/**
 * One log line for what the mic is up against as it is armed (#95): the
 * thing to read first on a silent call. "OTHER AUDIO PLAYING" is shouted
 * because it is the answer to "could it be somebody else has the audio?".
 */
export function describeInputState(s: AudioInputState): string {
  const d = (x: { name: string; type: string } | null | undefined) => (x ? `${x.name}[${x.type}]` : "none");
  const list = (xs: readonly AudioDevice[]) => xs.map(d).join(", ") || "none";
  const parts = [
    s.otherAudioPlaying ? "OTHER AUDIO PLAYING" : "no other audio",
    s.secondaryAudioShouldBeSilenced ? "silence hint ON" : null,
    s.inputAvailable ? "input available" : "NO INPUT AVAILABLE",
    `in: ${list(s.inputs)}`,
    `out: ${list(s.outputs)}`,
    s.preferredInput ? `preferred ${s.preferredInput}` : null,
    `${s.category}/${s.mode}`,
    `gain ${s.inputGain.toFixed(2)}`,
    `${Math.round(s.sampleRate)} Hz`,
    `buffer ${Math.round(s.ioBufferDuration * 1000)} ms`,
    `${s.inputChannels} ch`,
  ];
  return parts.filter((x): x is string => !!x).join(" | ");
}
