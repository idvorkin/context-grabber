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
