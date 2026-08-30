/**
 * The voice a Larry call answers in — Tony or Igor (#98).
 *
 * Igor, 2026-08-29: the full ElevenLabs roster is not needed; a two-way
 * selector is enough. Tony is the stock voice (ElevenLabs's *Charlie*, the
 * bridge's default) on the bridge's default model. Igor is his own clone,
 * and the clone is only worth hearing on `eleven_v3_conversational`, which
 * performs `[laughs]` / `[sighs]` / accent tags — so picking Igor implies
 * that model. Nothing else about the call changes.
 *
 * The ids come off the account roster (`GET <cockpit>/voices`, read
 * 2026-08-29): "Charlie" IKne3meq5aSn9XLyUdCD is `ELEVEN_VOICE_ID` in the
 * bridge; "Igor" Nvd5I2HGnOWHNU0ijNEy is the clone named exactly Igor
 * (the account also has "Igor 1" and "Igor - Sept 1 2026"). A re-clone
 * changes the id and this constant with it.
 *
 * Spec: docs/superpowers/specs/2026-08-28-native-call-screen-design.md,
 * "The voice".
 */

import type { CallBackend } from "./deepLink";

export type CallVoice = "tony" | "igor";

export const VOICES: ReadonlyArray<{
  id: CallVoice;
  label: string;
  /** What rides the start frame. "" = the bridge's default. */
  voiceId: string;
  model: string;
}> = [
  { id: "tony", label: "Tony", voiceId: "", model: "" },
  { id: "igor", label: "Igor", voiceId: "Nvd5I2HGnOWHNU0ijNEy", model: "eleven_v3_conversational" },
];

export const DEFAULT_VOICE: CallVoice = "tony";

export function isCallVoice(value: unknown): value is CallVoice {
  return VOICES.some((v) => v.id === value);
}

/**
 * The backends whose voice is an ElevenLabs voice. Mirrors
 * `ELEVEN_VOICED_BACKENDS` in the bridge — the drill is in it because its
 * clips are ElevenLabs too. On the others the pick is not sent.
 */
export const VOICED_BACKENDS: ReadonlySet<CallBackend> = new Set<CallBackend>(["eleven", "drill"]);

export function hasVoicePick(backend: CallBackend | null | undefined): boolean {
  return !!backend && VOICED_BACKENDS.has(backend);
}

export function voiceLabel(voice: CallVoice): string {
  return VOICES.find((v) => v.id === voice)?.label ?? "";
}

/** The `voice` / `model` fields of the start frame for this backend and pick. */
export function voiceFrameFields(backend: CallBackend, voice: CallVoice): { voice: string; model: string } {
  if (!hasVoicePick(backend)) return { voice: "", model: "" };
  const v = VOICES.find((x) => x.id === voice);
  return { voice: v?.voiceId ?? "", model: v?.model ?? "" };
}
