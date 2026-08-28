// Mock expo-location
jest.mock('expo-location', () => ({
  requestForegroundPermissionsAsync: jest.fn().mockResolvedValue({ status: 'granted' }),
  requestBackgroundPermissionsAsync: jest.fn().mockResolvedValue({ status: 'granted' }),
  getCurrentPositionAsync: jest.fn().mockResolvedValue({
    coords: { latitude: 47.6062, longitude: -122.3321, accuracy: 10 },
    timestamp: 1710460800000,
  }),
  startLocationUpdatesAsync: jest.fn().mockResolvedValue(undefined),
  stopLocationUpdatesAsync: jest.fn().mockResolvedValue(undefined),
  hasStartedLocationUpdatesAsync: jest.fn().mockResolvedValue(false),
  Accuracy: { Balanced: 3 },
  ActivityType: { Other: 4 },
}));

// Mock expo-task-manager
jest.mock('expo-task-manager', () => ({
  defineTask: jest.fn(),
}));

// Mock expo-sqlite
jest.mock('expo-sqlite', () => ({
  openDatabaseAsync: jest.fn().mockResolvedValue({
    execAsync: jest.fn().mockResolvedValue(undefined),
    getFirstAsync: jest.fn().mockResolvedValue(null),
    getAllAsync: jest.fn().mockResolvedValue([]),
    runAsync: jest.fn().mockResolvedValue(undefined),
  }),
}));

// Mock @kingstinct/react-native-healthkit
jest.mock('@kingstinct/react-native-healthkit', () => ({
  __esModule: true,
  default: {
    requestAuthorization: jest.fn().mockResolvedValue(undefined),
    queryStatisticsForQuantity: jest.fn().mockResolvedValue({ sumQuantity: { quantity: 0 } }),
    getMostRecentQuantitySample: jest.fn().mockResolvedValue(null),
    queryCategorySamples: jest.fn().mockResolvedValue([]),
    queryQuantitySamples: jest.fn().mockResolvedValue([]),
  },
}));

// Mock expo-updates
jest.mock('expo-updates', () => ({
  channel: 'development',
  runtimeVersion: '1.0.0',
  updateId: null,
}));

// Mock expo-status-bar
jest.mock('expo-status-bar', () => ({
  StatusBar: 'StatusBar',
}));

// Mock expo-file-system/legacy
jest.mock('expo-file-system/legacy', () => ({
  documentDirectory: 'file:///mock/',
  cacheDirectory: 'file:///mock-cache/',
  getInfoAsync: jest.fn().mockResolvedValue({ exists: false }),
  copyAsync: jest.fn().mockResolvedValue(undefined),
}));

// Mock expo-sharing
jest.mock('expo-sharing', () => ({
  shareAsync: jest.fn().mockResolvedValue(undefined),
}));

// Mock expo-clipboard
jest.mock('expo-clipboard', () => ({
  setStringAsync: jest.fn().mockResolvedValue(undefined),
  getStringAsync: jest.fn().mockResolvedValue(''),
}));

// Mock expo-live-activity
jest.mock('expo-live-activity', () => ({
  startActivity: jest.fn().mockReturnValue('mock-activity-id'),
  updateActivity: jest.fn(),
  stopActivity: jest.fn(),
}));

// Mock expo-keep-awake
jest.mock('expo-keep-awake', () => ({
  useKeepAwake: jest.fn(),
}));

// Mock expo-audio (no native recorder/player in tests)
jest.mock('expo-audio', () => {
  const recorder = {
    id: 'mock',
    currentTime: 0,
    isRecording: false,
    uri: 'file:///mock/recording.m4a',
    record: jest.fn(),
    stop: jest.fn().mockResolvedValue(undefined),
    pause: jest.fn(),
    prepareToRecordAsync: jest.fn().mockResolvedValue(undefined),
  };
  const player = {
    play: jest.fn(),
    pause: jest.fn(),
    seekTo: jest.fn().mockResolvedValue(undefined),
    replace: jest.fn(),
  };
  return {
    RecordingPresets: { HIGH_QUALITY: {}, LOW_QUALITY: {} },
    useAudioRecorder: jest.fn(() => recorder),
    useAudioRecorderState: jest.fn(() => ({ isRecording: false, durationMillis: 0 })),
    useAudioPlayer: jest.fn(() => player),
    useAudioPlayerStatus: jest.fn(() => ({ playing: false, currentTime: 0, duration: 0 })),
    requestRecordingPermissionsAsync: jest.fn().mockResolvedValue({ granted: true }),
    setAudioModeAsync: jest.fn().mockResolvedValue(undefined),
  };
});

// Mock expo-cloudkit (no native module in tests)
jest.mock('expo-cloudkit', () => ({
  configure: jest.fn(),
  getAccountStatus: jest.fn().mockResolvedValue('available'),
  saveRecords: jest.fn().mockResolvedValue([{ recordName: 'test-record' }]),
  fetchRecord: jest.fn().mockResolvedValue({ fields: { now: { value: 0 } } }),
  createZone: jest.fn().mockResolvedValue(undefined),
  fetchRecordZoneChanges: jest.fn().mockResolvedValue({
    changedRecords: [],
    deletedRecordNames: [],
    syncToken: 'tok',
    moreComing: false,
  }),
  deleteRecords: jest.fn().mockResolvedValue(undefined),
}));

// Mock react-native-maps (no native MapKit in tests)
jest.mock('react-native-maps', () => {
  const React = require('react');
  const { View } = require('react-native');
  // forwardRef so components can hold a MapView ref and call imperative
  // camera methods (animateToRegion) — used by the find-me control.
  const MapView = React.forwardRef((props, ref) => {
    React.useImperativeHandle(ref, () => ({
      animateToRegion: () => {},
      animateCamera: () => {},
      fitToCoordinates: () => {},
    }));
    return React.createElement(View, props, props.children);
  });
  const Marker = (props) => React.createElement(View, props, props.children);
  const Polyline = (props) => React.createElement(View, props);
  return {
    __esModule: true,
    default: MapView,
    Marker,
    Polyline,
    PROVIDER_DEFAULT: 'default',
    PROVIDER_GOOGLE: 'google',
  };
});

// Mock react-native-webview (no WKWebView in tests). Rendered as a plain
// View that still forwards testID/props so assertions can inspect the
// media-capture and refresh props we depend on.
//
// The imperative handle's methods are jest.fn()s exposed as `__mock` so the
// audio-bridge tests can read what was injected into the page — that string
// IS the protocol's wire format, and asserting on it is the only way to test
// the app→page direction without a device.
jest.mock('react-native-webview', () => {
  const React = require('react');
  const { View } = require('react-native');
  const handle = {
    reload: jest.fn(),
    goBack: jest.fn(),
    injectJavaScript: jest.fn(),
  };
  const WebView = React.forwardRef((props, ref) => {
    React.useImperativeHandle(ref, () => handle);
    return React.createElement(View, props);
  });
  return { __esModule: true, WebView, default: WebView, __mock: handle };
});

// Mock the local audio-route Expo module (no AVAudioSession in tests). The
// default snapshot is a phone with AirPods paired — the shape that matters,
// since a phone with nothing attached is the case where the pickers have
// nothing to show anyway.
const mockAudioRouteSnapshot = {
  inputs: [
    { id: 'BuiltInMicrophoneBottom', name: 'iPhone Microphone', type: 'MicrophoneBuiltIn' },
    { id: 'AC:12:34:56:78:9A-tacl', name: 'AirPods Pro', type: 'BluetoothHFP' },
  ],
  outputs: [
    { id: 'auto', name: 'Automatic', type: 'auto' },
    { id: 'speaker', name: 'Speaker', type: 'Speaker' },
    { id: 'AC:12:34:56:78:9A-tacl', name: 'AirPods Pro', type: 'BluetoothHFP' },
  ],
  current: {
    input: { id: 'BuiltInMicrophoneBottom', name: 'iPhone Microphone', type: 'MicrophoneBuiltIn' },
    output: { id: 'speaker', name: 'Speaker', type: 'Speaker' },
  },
  capabilities: { selectInput: true, selectOutput: true, forceSpeaker: true },
};
const mockAudioRoute = {
  snapshot: mockAudioRouteSnapshot,
  listeners: [],
  isAvailable: jest.fn(() => true),
  activate: jest.fn(async () => mockAudioRoute.snapshot),
  getDevices: jest.fn(() => mockAudioRoute.snapshot),
  setInput: jest.fn(async () => mockAudioRoute.snapshot),
  setOutput: jest.fn(async () => mockAudioRoute.snapshot),
  addListener: jest.fn((_name, listener) => {
    mockAudioRoute.listeners.push(listener);
    return {
      remove: jest.fn(() => {
        mockAudioRoute.listeners = mockAudioRoute.listeners.filter((l) => l !== listener);
      }),
    };
  }),
};
jest.mock('./modules/audio-route', () => ({
  __esModule: true,
  default: mockAudioRoute,
  __mock: mockAudioRoute,
}));

// Mock react-native-audio-api
jest.mock('react-native-audio-api', () => ({
  AudioContext: jest.fn().mockImplementation(() => ({
    currentTime: 0,
    destination: {},
    createOscillator: jest.fn().mockReturnValue({
      frequency: { value: 0 },
      type: 'sine',
      connect: jest.fn(),
      start: jest.fn(),
      stop: jest.fn(),
    }),
    createGain: jest.fn().mockReturnValue({
      gain: { value: 0 },
      connect: jest.fn(),
    }),
  })),
}));
