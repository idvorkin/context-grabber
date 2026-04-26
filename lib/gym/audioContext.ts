import { AudioContext } from "react-native-audio-api";

let _ctx: InstanceType<typeof AudioContext> | null = null;

export function getAudioContext(): InstanceType<typeof AudioContext> {
  if (!_ctx) _ctx = new AudioContext();
  return _ctx;
}
