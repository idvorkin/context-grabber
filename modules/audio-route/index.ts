import {
  NativeModule,
  requireOptionalNativeModule,
  type EventSubscription,
} from "expo-modules-core";

/**
 * A microphone or an output destination, as iOS names it.
 *
 * `id` is an `AVAudioSession` port UID, stable for as long as the device is
 * connected — except for the two synthetic output ids, `"auto"` and
 * `"speaker"`, which name a routing *decision* rather than a piece of
 * hardware.
 */
export type AudioDevice = {
  id: string;
  name: string;
  type: string;
};

/** What is actually carrying audio right now — never what was requested. */
export type AudioRouteCurrent = {
  input: AudioDevice | null;
  output: AudioDevice | null;
};

export type AudioRouteCapabilities = {
  selectInput: boolean;
  selectOutput: boolean;
  forceSpeaker: boolean;
};

export type AudioRouteSnapshot = {
  inputs: AudioDevice[];
  outputs: AudioDevice[];
  current: AudioRouteCurrent;
  capabilities: AudioRouteCapabilities;
};

/**
 * The session as the recorder is about to see it (#95): whether another
 * app is playing, whether an input is available, what is on the route, and
 * how the session is set. Read at arm time into the call's diagnostics.
 */
export type AudioInputState = {
  otherAudioPlaying: boolean;
  secondaryAudioShouldBeSilenced: boolean;
  inputAvailable: boolean;
  inputs: AudioDevice[];
  outputs: AudioDevice[];
  preferredInput: string | null;
  /** `PlayAndRecord`, … — the AVAudioSession name without its prefix. */
  category: string;
  /** `VoiceChat`, `Default`, … */
  mode: string;
  inputGain: number;
  sampleRate: number;
  /** Seconds. */
  ioBufferDuration: number;
  inputChannels: number;
};

/** A snapshot plus iOS's own word for why the route moved. */
export type AudioRouteChange = AudioRouteSnapshot & {
  reason: string;
};

type AudioRouteEvents = {
  onRouteChange: (payload: AudioRouteChange) => void;
};

declare class AudioRouteNativeModule extends NativeModule<AudioRouteEvents> {
  /** False is impossible from the native side; `null` module is the real "no". */
  isAvailable(): boolean;
  /**
   * Put the session in `.playAndRecord` with Bluetooth allowed, which is what
   * makes the input roster non-trivial and an output override legal.
   */
  activate(): Promise<AudioRouteSnapshot>;
  getDevices(): AudioRouteSnapshot;
  /** Optional: a binary built before #95 does not have it. Guard before calling. */
  getInputState?(): AudioInputState;
  /** `null` or `""` clears the preference and hands the choice back to iOS. */
  setInput(uid: string | null): Promise<AudioRouteSnapshot>;
  setOutput(port: string): Promise<AudioRouteSnapshot>;
}

/**
 * `null` when the native module is not linked — a build made before this
 * module existed, a `pod install` that never ran, or a test process. Every
 * caller has to cope with that, and coping means "behave as if there were no
 * bridge", which is exactly the pre-bridge behavior.
 */
const AudioRoute = requireOptionalNativeModule<AudioRouteNativeModule>("AudioRoute");

export default AudioRoute;
export type { EventSubscription };
