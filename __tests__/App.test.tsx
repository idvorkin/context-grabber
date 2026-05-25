import React from "react";
import { render, act, fireEvent } from "@testing-library/react-native";
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

// Switch to a tab and settle effects.
async function gotoTab(result: ReturnType<typeof render>, tab: string) {
  await act(async () => {
    fireEvent.press(result.getByTestId(`tab-${tab}`));
    await flushPromises();
  });
}

// --- Rendering Tests ---

describe("App rendering", () => {
  it("renders without crashing", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Context Grabber")).toBeTruthy();
  });

  it("shows title", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Context Grabber")).toBeTruthy();
  });

  it("shows settings button in header", async () => {
    const { getByLabelText } = await renderApp();
    expect(getByLabelText("Settings")).toBeTruthy();
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

  it("shows metric cards on Body tab after auto-grab", async () => {
    const result = await renderApp();
    await gotoTab(result, "body");
    const { getByText } = result;
    expect(getByText("Movement")).toBeTruthy();
    expect(getByText("Heart Rate")).toBeTruthy();
    expect(getByText("Sleep")).toBeTruthy();
    expect(getByText("Weight")).toBeTruthy();
    expect(getByText("Meditation")).toBeTruthy();
    expect(getByText("HRV")).toBeTruthy();
    expect(getByText("Exercise")).toBeTruthy();
  });

  it("shows share buttons after auto-grab", async () => {
    const { getByText } = await renderApp();
    expect(getByText(/Summary/)).toBeTruthy();
    expect(getByText(/Raw/)).toBeTruthy();
  });

  it("shows location coordinates on Places tab after auto-grab", async () => {
    const result = await renderApp();
    await gotoTab(result, "places");
    const { getByText } = result;
    // PlacesScreen uses toFixed(4), so we match the first 4 digits.
    expect(getByText(/47\.60/)).toBeTruthy();
    expect(getByText(/-122\.33/)).toBeTruthy();
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

  it("shows em dash for null health values on Body tab", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const result = await renderApp();
    await gotoTab(result, "body");
    const dashes = result.getAllByText("\u2014");
    expect(dashes.length).toBeGreaterThanOrEqual(3);
  });

  it("renders metric card labels and sublabels on Body tab", async () => {
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const result = await renderApp();
    await gotoTab(result, "body");
    const { getByText, getAllByText } = result;

    expect(getByText("Movement")).toBeTruthy();
    expect(getByText("Heart Rate")).toBeTruthy();
    expect(getByText("Sleep")).toBeTruthy();
    expect(getByText("Weight")).toBeTruthy();
    expect(getByText("Meditation")).toBeTruthy();
    expect(getByText("HRV")).toBeTruthy();
    expect(getByText("Exercise")).toBeTruthy();

    // meditation always says "today"; exercise + weight sublabels are
    // staleness-driven ("7+ days ago" when weeklyCache hasn't loaded).
    const todaySublabels = getAllByText("today");
    expect(todaySublabels.length).toBe(1);
    const latestSublabels = getAllByText("latest");
    expect(latestSublabels.length).toBe(2); // heart rate, hrv
  });

  it("shows all metric cards on Body tab after grab", async () => {
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

    const result = await renderApp();
    await gotoTab(result, "body");
    const { getByText } = result;

    const metricLabels = [
      "Movement", "Heart Rate", "Sleep", "Weight", "Meditation",
      "HRV", "Exercise",
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

  it("shows location as unavailable when permission denied", async () => {
    (Location.requestForegroundPermissionsAsync as jest.Mock).mockResolvedValue({
      status: "denied",
    });
    (HealthKit.queryStatisticsForQuantity as jest.Mock).mockResolvedValue({
      sumQuantity: { quantity: 0 },
    });
    (HealthKit.getMostRecentQuantitySample as jest.Mock).mockResolvedValue(null);
    (HealthKit.queryCategorySamples as jest.Mock).mockResolvedValue([]);

    const result = await renderApp();
    await gotoTab(result, "places");
    expect(result.getByText("Unavailable")).toBeTruthy();
  });
});

describe("Tab navigation", () => {
  it("renders the tab bar", async () => {
    const { getByTestId } = await renderApp();
    expect(getByTestId("tab-bar")).toBeTruthy();
  });

  it("renders all six tabs in spec order", async () => {
    const { getByTestId } = await renderApp();
    expect(getByTestId("tab-today")).toBeTruthy();
    expect(getByTestId("tab-body")).toBeTruthy();
    expect(getByTestId("tab-move")).toBeTruthy();
    expect(getByTestId("tab-mind")).toBeTruthy();
    expect(getByTestId("tab-places")).toBeTruthy();
    expect(getByTestId("tab-roles")).toBeTruthy();
  });

  it("starts on Today tab", async () => {
    const { getByText } = await renderApp();
    expect(getByText("Context Grabber")).toBeTruthy();
  });

  it("switches to Body tab when its tab is pressed", async () => {
    const result = await renderApp();
    await gotoTab(result, "body");
    // Body tab renders WeekStrip (unique to Body in PR-2)
    expect(result.getByTestId("week-strip")).toBeTruthy();
  });

  it("switches to Mind tab and shows mood report + meditation flatline", async () => {
    const result = await renderApp();
    await gotoTab(result, "mind");
    expect(result.getByTestId("mood-report-card")).toBeTruthy();
    expect(result.getByTestId("meditation-flatline-card")).toBeTruthy();
    expect(result.getByTestId("mind-affirm")).toBeTruthy();
    expect(result.getByTestId("mind-grateful")).toBeTruthy();
    expect(result.getByTestId("mind-journal")).toBeTruthy();
  });

  it("switches to Places tab and shows the stylized map", async () => {
    const result = await renderApp();
    await gotoTab(result, "places");
    expect(result.getByTestId("stylized-map")).toBeTruthy();
    expect(result.getByTestId("places-open-detail")).toBeTruthy();
  });

  it("switches to Roles tab and shows Coming soon stub", async () => {
    const result = await renderApp();
    await gotoTab(result, "roles");
    expect(result.getByText("Coming soon")).toBeTruthy();
  });

  it("Move tab shows the 4 gym timer presets and weekly ring", async () => {
    const result = await renderApp();
    await gotoTab(result, "move");
    expect(result.getByTestId("ring-progress")).toBeTruthy();
    expect(result.getByTestId("gym-preset-30sec")).toBeTruthy();
    expect(result.getByTestId("gym-preset-1min")).toBeTruthy();
    expect(result.getByTestId("gym-preset-2min")).toBeTruthy();
    expect(result.getByTestId("gym-preset-5-1")).toBeTruthy();
  });
});
