import React from "react";
import { render, fireEvent, act } from "@testing-library/react-native";
import * as SQLite from "expo-sqlite";
import HealthKit from "@kingstinct/react-native-healthkit";
import * as Location from "expo-location";

import App from "../App";

// Helper to flush all pending promises
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

// Render app and let initial effects settle
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

  it("shows Grab Context button", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Grab Context")).toBeTruthy();
  });

  it("shows Share JSON button after auto-grab on startup", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Share JSON")).toBeTruthy();
  });

  it("shows tracking settings card with toggle and retention input", async () => {
    const { getByText, getByDisplayValue } = await renderApp();
    expect(getByText("Location Tracking")).toBeTruthy();
    expect(getByText("Background Tracking")).toBeTruthy();
    expect(getByText("Retention (days)")).toBeTruthy();
    expect(getByDisplayValue("30")).toBeTruthy();
  });

  it("shows location count text", async () => {
    const { getByText } = await renderApp();
    expect(getByText("0 locations tracked")).toBeTruthy();
  });
});

// --- Interaction Tests ---

describe("App interactions", () => {
  beforeEach(() => {
    jest.clearAllMocks();

    // Reset mock implementations to defaults
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

  it("shows Grabbing... while loading", async () => {
    // Make health request hang so we can see the loading state (auto-grab triggers on mount)
    let resolveAuth: () => void;
    const authPromise = new Promise<void>((resolve) => {
      resolveAuth = resolve;
    });
    (HealthKit.requestAuthorization as jest.Mock).mockReturnValue(authPromise);

    const result = render(<App />);

    // Auto-grab fires on mount, so we should see Grabbing...
    await act(async () => {
      await flushPromises();
    });

    expect(result.getByText("Grabbing...")).toBeTruthy();

    // Resolve to clean up
    await act(async () => {
      resolveAuth!();
      await flushPromises();
    });
  });

  it("shows snapshot data after grabbing", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock)
      .mockResolvedValueOnce({ sumQuantity: { quantity: 8432 } }) // steps
      .mockResolvedValueOnce({ sumQuantity: { quantity: 312 } }) // active energy
      .mockResolvedValueOnce({ sumQuantity: { quantity: 5.67 } }); // distance
    (HealthKit.getMostRecentQuantitySample as jest.Mock)
      .mockResolvedValueOnce({ quantity: 72 }) // heart rate
      .mockResolvedValueOnce({ quantity: 75.5 }); // weight

    const { getByText } = await renderApp();

    await act(async () => {
      fireEvent.press(getByText("Grab Context"));
      await flushPromises();
    });

    // After grabbing, metric cards should appear
    expect(getByText("Steps")).toBeTruthy();
    expect(getByText("Heart Rate")).toBeTruthy();
    expect(getByText("Sleep")).toBeTruthy();
    expect(getByText("Active Energy")).toBeTruthy();
    expect(getByText("Walking Distance")).toBeTruthy();
    expect(getByText("Weight")).toBeTruthy();
    expect(getByText("Meditation")).toBeTruthy();
  });

  it("shows Share JSON button after auto-grab", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Share JSON")).toBeTruthy();
  });

  it("shows location coordinates after grabbing", async () => {
    const { getByText } = await renderApp();

    await act(async () => {
      fireEvent.press(getByText("Grab Context"));
      await flushPromises();
    });

    expect(getByText("Location")).toBeTruthy();
    // Coordinates formatted to 4 decimal places
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
    // All health queries return empty/null results
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const { getByText, getAllByText } = await renderApp();

    await act(async () => {
      fireEvent.press(getByText("Grab Context"));
      await flushPromises();
    });

    // Heart rate, sleep, weight, meditation should show em dash
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

    await act(async () => {
      fireEvent.press(getByText("Grab Context"));
      await flushPromises();
    });

    // Check labels
    expect(getByText("Steps")).toBeTruthy();
    expect(getByText("Heart Rate")).toBeTruthy();
    expect(getByText("Sleep")).toBeTruthy();
    expect(getByText("Active Energy")).toBeTruthy();
    expect(getByText("Walking Distance")).toBeTruthy();
    expect(getByText("Weight")).toBeTruthy();
    expect(getByText("Meditation")).toBeTruthy();

    // Check sublabels
    const todaySublabels = getAllByText("today");
    expect(todaySublabels.length).toBe(5); // steps, active energy, walking distance, meditation, exercise
    const latestSublabels = getAllByText("latest");
    expect(latestSublabels.length).toBe(4); // heart rate, weight, hrv, resting hr
  });

  it("shows all 7 metric cards after grab", async () => {
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

    await act(async () => {
      fireEvent.press(getByText("Grab Context"));
      await flushPromises();
    });

    const metricLabels = [
      "Steps",
      "Heart Rate",
      "Sleep",
      "Active Energy",
      "Walking Distance",
      "Weight",
      "Meditation",
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
    // Set up mocks before render so auto-grab picks them up
    (HealthKit.queryStatisticsForQuantity as jest.Mock)
      .mockResolvedValueOnce({ sumQuantity: { quantity: 8432 } }) // steps
      .mockResolvedValueOnce({ sumQuantity: { quantity: 312 } }) // active energy
      .mockResolvedValueOnce({ sumQuantity: { quantity: 5.67 } }); // distance
    (HealthKit.getMostRecentQuantitySample as jest.Mock)
      .mockResolvedValueOnce({ quantity: 72 }) // heart rate
      .mockResolvedValueOnce({ quantity: 75.5 }); // weight
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const { getByText } = await renderApp();

    // Auto-grab should have completed with the mocked data
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

    await act(async () => {
      fireEvent.press(getByText("Grab Context"));
      await flushPromises();
    });

    expect(getByText("Unavailable")).toBeTruthy();
  });
});
