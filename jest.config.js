/** @type {import('jest').Config} */
module.exports = {
  projects: [
    {
      displayName: "unit",
      preset: "ts-jest",
      testEnvironment: "node",
      roots: ["<rootDir>/__tests__"],
      testPathIgnorePatterns: ["\\.test\\.tsx$"],
      moduleFileExtensions: ["ts", "tsx", "js", "json"],
    },
    {
      displayName: "component",
      preset: "react-native",
      roots: ["<rootDir>/__tests__"],
      testMatch: ["**/*.test.tsx"],
      transformIgnorePatterns: [
        "node_modules/(?!(react-native|@react-native|expo|expo-location|expo-sqlite|expo-task-manager|expo-status-bar|expo-file-system|expo-sharing|@kingstinct|expo-modules-core)/)",
      ],
      setupFiles: [
        "./node_modules/react-native/jest/setup.js",
        "./jest.setup.js",
      ],
      moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"],
    },
  ],
};
