/** @type {import('jest').Config} */
module.exports = {
  // A cold transform cache (every fresh worktree) babel-compiles react-native in every
  // worker at once; the contention pushes CallScreen render tests past the 5 s default.
  // Global only: jest-circus ignores a per-project testTimeout.
  testTimeout: 30000,
  projects: [
    {
      displayName: "unit",
      preset: "ts-jest",
      testEnvironment: "node",
      roots: ["<rootDir>/__tests__"],
      testPathIgnorePatterns: ["\\.test\\.tsx$", "/__tests__/fixtures/"],
      moduleFileExtensions: ["ts", "tsx", "js", "json"],
    },
    {
      displayName: "component",
      preset: "react-native",
      roots: ["<rootDir>/__tests__"],
      testMatch: ["**/*.test.tsx"],
      testPathIgnorePatterns: ["/__tests__/fixtures/"],
      transformIgnorePatterns: [
        "node_modules/(?!(react-native|@react-native|expo|react-native-audio-api|react-native-webview|expo-location|expo-sqlite|expo-task-manager|expo-status-bar|expo-file-system|expo-sharing|expo-clipboard|@kingstinct|expo-modules-core)/)",
      ],
      moduleNameMapper: {
        "\\.(mp3|wav|m4a|aac|aif|aiff)$": "<rootDir>/__tests__/fixtures/audioStub.js",
      },
      setupFiles: [
        "./node_modules/react-native/jest/setup.js",
        "./jest.setup.js",
      ],
      moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"],
    },
  ],
};
