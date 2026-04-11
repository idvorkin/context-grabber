import React from "react";
import { render, act } from "@testing-library/react-native";
import * as SQLite from "expo-sqlite";
import HealthKit from "@kingstinct/react-native-healthkit";
import * as Location from "expo-location";

import App from "../App";

// Helper to flush all pending promises
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

// Render app and let initial effects settle (auto-grab fires on mount)
async function renderApp() {
  const result = render(<App />);
  await act(async () => {
    await flushPromises();
  });
  return result;
}

// --- Rendering Tests ---

describe("App rendering", () => {
  it("renders without crashing", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Context Grabber")).toBeTruthy();
  });

  it("shows title and subtitle", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Context Grabber")).toBeTruthy();
    expect(
      getByText("Grab your iPhone context for your AI life coach"),
    ).toBeTruthy();
  });

  it("shows refresh button in header", async () => {
    const { getByLabelText } = await renderApp();
    expect(getByLabelText("Refresh")).toBeTruthy();
  });

  it("shows settings button in header", async () => {
    const { getByLabelText } = await renderApp();
    expect(getByLabelText("Settings")).toBeTruthy();
  });

  it("shows about button in header", async () => {
    const { getByLabelText } = await renderApp();
    expect(getByLabelText("About")).toBeTruthy();
  });

  it("shows share buttons after auto-grab on startup", async () => {
    const { getByText } = await renderApp();
    expect(getByText(/Summary/)).toBeTruthy();
    expect(getByText(/Raw/)).toBeTruthy();
  });
});

// --- Interaction Tests ---

describe("App interactions", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    (SQLite.openDatabaseAsync as jest.Mock).mockResolvedValue({
      execAsync: jest.fn().mockResolvedValue(undefined),
      getFirstAsync: jest.fn().mockResolvedValue(null),
      getAllAsync: jest.fn().mockResolvedValue([]),
      runAsync: jest.fn().mockResolvedValue(undefined),
    });

    (HealthKit.requestAuthorization as jest.Mock).mockResolvedValue(undefined);
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: "granted",
    });
    (Location.getCurrentPositionAsync as jest.Mock).mockResolvedValue({
      coords: { latitude: 47.6062, longitude: -122.3321, accuracy: 10 },
      timestamp: 1710460800000,
    });
  });

  it("shows metric cards after auto-grab", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Movement")).toBeTruthy();
    expect(getByText("Heart Rate")).toBeTruthy();
    expect(getByText("Sleep")).toBeTruthy();
    expect(getByText("Weight")).toBeTruthy();
    expect(getByText("Meditation")).toBeTruthy();
    expect(getByText("HRV")).toBeTruthy();
    expect(getByText("Resting HR")).toBeTruthy();
    expect(getByText("Exercise")).toBeTruthy();
  });

  it("shows share buttons after auto-grab", async () => {
    const { getByText } = await renderApp();
    expect(getByText(/Summary/)).toBeTruthy();
    expect(getByText(/Raw/)).toBeTruthy();
  });

  it("shows location coordinates after auto-grab", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Location")).toBeTruthy();
    expect(getByText(/47\.6062/)).toBeTruthy();
    expect(getByText(/-122\.3321/)).toBeTruthy();
  });
});

// --- MetricCard rendering ---

describe("MetricCard rendering after grab", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    (SQLite.openDatabaseAsync as jest.Mock).mockResolvedValue({
      execAsync: jest.fn().mockResolvedValue(undefined),
      getFirstAsync: jest.fn().mockResolvedValue(null),
      getAllAsync: jest.fn().mockResolvedValue([]),
      runAsync: jest.fn().mockResolvedValue(undefined),
    });

    (HealthKit.requestAuthorization as jest.Mock).mockResolvedValue(undefined);
    (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: "granted",
    });
    (Location.getCurrentPositionAsync as jest.Mock).mockResolvedValue({
      coords: { latitude: 47.6062, longitude: -122.3321, accuracy: 10 },
      timestamp: 1710460800000,
    });
  });

  it("shows em dash for null health values", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const { getAllByText } = await renderApp();
    const dashes = getAllByText("\u2014");
    expect(dashes.length).toBeGreaterThanOrEqual(3);
  });

  it("renders metric card labels and sublabels", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const { getByText, getAllByText } = await renderApp();

    expect(getByText("Movement")).toBeTruthy();
    expect(getByText("Heart Rate")).toBeTruthy();
    expect(getByText("Sleep")).toBeTruthy();
    expect(getByText("Weight")).toBeTruthy();
    expect(getByText("Meditation")).toBeTruthy();
    expect(getByText("HRV")).toBeTruthy();
    expect(getByText("Resting HR")).toBeTruthy();
    expect(getByText("Exercise")).toBeTruthy();

    const todaySublabels = getAllByText("today");
    expect(todaySublabels.length).toBe(2); // meditation, exercise (movement uses custom sublabel)
    const latestSublabels = getAllByText("latest");
    expect(latestSublabels.length).toBe(4); // heart rate, weight, hrv, resting hr
  });

  it("shows all metric cards after grab", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 1000 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue({
      quantity: 72,
    });
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([
      {
        startDate: "2026-03-14T23:00:00.000Z",
        endDate: "2026-03-15T07:00:00.000Z",
      },
    ]);

    const { getByText } = await renderApp();

    const metricLabels = [
      "Movement", "Heart Rate", "Sleep", "Weight", "Meditation",
      "HRV", "Resting HR", "Exercise",
    ];

    for (const label of metricLabels) {
      expect(getByText(label)).toBeTruthy();
    }
  });
});

// --- Summary banner ---

describe("Dashboard display after grab", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    (SQLite.openDatabaseAsync as jest.Mock).mockResolvedValue({
      execAsync: jest.fn().mockResolvedValue(undefined),
      getFirstAsync: jest.fn().mockResolvedValue(null),
      getAllAsync: jest.fn().mockResolvedValue([]),
      runAsync: jest.fn().mockResolvedValue(undefined),
    });

    (HealthKit.requestAuthorization as jest.Mock).mockResolvedValue(undefined);
    (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: "granted",
    });
    (Location.getCurrentPositionAsync as jest.Mock).mockResolvedValue({
      coords: { latitude: 47.6062, longitude: -122.3321, accuracy: 10 },
      timestamp: 1710460800000,
    });
  });

  it("shows summary banner with step count", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock)
      .mockResolvedValueOnce({ sumQuantity: { quantity: 8432 } }) // steps
      .mockResolvedValueOnce({ sumQuantity: { quantity: 312 } }) // active energy
      .mockResolvedValueOnce({ sumQuantity: { quantity: 5.67 } }); // distance
    (HealthKit.getMostRecentQuantitySample as jest.Mock)
      .mockResolvedValueOnce({ quantity: 72 }) // heart rate
      .mockResolvedValueOnce({ quantity: 75.5 }); // weight
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const { getByText } = await renderApp();
    expect(getByText(/8,432 steps/)).toBeTruthy();
  });

  it("shows location as unavailable when permission denied", async () => {
    (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: "denied",
    });
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const { getByText } = await renderApp();
    expect(getByText("Unavailable")).toBeTruthy();
  });
});
