import { buildHealthData, type HealthQueryResults } from "../lib/health";

/**
 * Tests for the context snapshot shape.
 * Validates that assembled snapshots have the correct structure
 * regardless of which health metrics succeed or fail.
 */

type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

type LocationHistoryItem = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  timestamp: number;
};

type ContextSnapshot = {
  timestamp: string;
  health: ReturnType<typeof buildHealthData>;
  location: LocationData;
  locationHistory: LocationHistoryItem[];
};

function buildSnapshot(
  healthResults: HealthQueryResults,
  location: LocationData,
  locationHistory: LocationHistoryItem[] = [],
): ContextSnapshot {
  return {
    timestamp: new Date().toISOString(),
    health: buildHealthData(healthResults),
    location,
    locationHistory,
  };
}

function fulfilled<T>(value: T): PromiseFulfilledResult<T> {
  return { status: "fulfilled", value };
}

function rejected(reason = "error"): PromiseRejectedResult {
  return { status: "rejected", reason };
}

function allRejected(): HealthQueryResults {
  return [rejected(), rejected(), rejected(), rejected(), rejected(), rejected(), rejected(), rejected(), rejected(), rejected(), rejected()];
}

describe("ContextSnapshot shape", () => {
  it("has all required top-level keys", () => {
    const snapshot = buildSnapshot(allRejected(), null);
    expect(snapshot).toHaveProperty("timestamp");
    expect(snapshot).toHaveProperty("health");
    expect(snapshot).toHaveProperty("location");
    expect(snapshot).toHaveProperty("locationHistory");
  });

  it("timestamp is a valid ISO 8601 string", () => {
    const snapshot = buildSnapshot(allRejected(), null);
    const parsed = new Date(snapshot.timestamp);
    expect(parsed.toISOString()).toBe(snapshot.timestamp);
  });

  it("health object has all metric keys", () => {
    const snapshot = buildSnapshot(allRejected(), null);
    const keys = Object.keys(snapshot.health).sort();
    expect(keys).toEqual([
      "activeEnergy",
      "bedtime",
      "exerciseMinutes",
      "heartRate",
      "hrv",
      "meditationMinutes",
      "restingHeartRate",
      "sleepBySource",
      "sleepHours",
      "steps",
      "wakeTime",
      "walkingDistance",
      "weight",
      "weightDaysLast7",
    ]);
  });

  it("location is null when unavailable", () => {
    const snapshot = buildSnapshot(allRejected(), null);
    expect(snapshot.location).toBeNull();
  });

  it("location has lat/lng/timestamp when available", () => {
    const location = {
      latitude: 47.6062,
      longitude: -122.3321,
      timestamp: Date.now(),
    };
    const snapshot = buildSnapshot(allRejected(), location);
    expect(snapshot.location).toEqual(location);
    expect(typeof snapshot.location!.latitude).toBe("number");
    expect(typeof snapshot.location!.longitude).toBe("number");
    expect(typeof snapshot.location!.timestamp).toBe("number");
  });

  it("full snapshot with all data populated has correct shape", () => {
    const healthResults: HealthQueryResults = [
      fulfilled({ sumQuantity: { quantity: 10000 } }),
      fulfilled({ quantity: 65 }),
      fulfilled({ sumQuantity: { quantity: 450 } }),
      fulfilled({ sumQuantity: { quantity: 8.25 } }),
      fulfilled([
        {
          startDate: "2026-03-14T23:00:00.000Z",
          endDate: "2026-03-15T07:00:00.000Z",
        },
      ]),
      fulfilled({ quantity: 72.5 }),
      fulfilled([
        {
          startDate: "2026-03-15T08:00:00.000Z",
          endDate: "2026-03-15T08:20:00.000Z",
        },
      ]),
      fulfilled([
        { startDate: "2026-03-14T08:00:00.000Z", quantity: 72.5 },
        { startDate: "2026-03-12T08:00:00.000Z", quantity: 72.3 },
      ]),
      fulfilled({ quantity: 38.2 }),
      fulfilled({ quantity: 55 }),
      fulfilled({ sumQuantity: { quantity: 25 } }),
    ];
    const location = {
      latitude: 47.6062,
      longitude: -122.3321,
      timestamp: 1710460800000,
    };
    const snapshot = buildSnapshot(healthResults, location);

    expect(snapshot.health.steps).toBe(10000);
    expect(snapshot.health.heartRate).toBe(65);
    expect(snapshot.health.activeEnergy).toBe(450);
    expect(snapshot.health.walkingDistance).toBe(8.25);
    expect(snapshot.health.sleepHours).toBe(8);
    expect(snapshot.health.bedtime).toBe("2026-03-14T23:00:00.000Z");
    expect(snapshot.health.wakeTime).toBe("2026-03-15T07:00:00.000Z");
    expect(snapshot.health.sleepBySource).toEqual({
      Unknown: {
        bedtime: "2026-03-14T23:00:00.000Z",
        wakeTime: "2026-03-15T07:00:00.000Z",
        coreHours: 0, deepHours: 0, remHours: 0, awakeHours: 0,
      },
    });
    expect(snapshot.health.weight).toBe(72.5);
    expect(snapshot.health.weightDaysLast7).toBe(2);
    expect(snapshot.health.meditationMinutes).toBe(20);
    expect(snapshot.health.hrv).toBe(38.2);
    expect(snapshot.health.restingHeartRate).toBe(55);
    expect(snapshot.health.exerciseMinutes).toBe(25);
    expect(snapshot.location).toEqual(location);
    expect(typeof snapshot.timestamp).toBe("string");
  });

  it("snapshot with all-null health still serializes to valid JSON", () => {
    const snapshot = buildSnapshot(allRejected(), null);
    const json = JSON.stringify(snapshot);
    const parsed = JSON.parse(json);
    expect(parsed.health.steps).toBeNull();
    expect(parsed.health.heartRate).toBeNull();
    expect(parsed.health.sleepHours).toBeNull();
    expect(parsed.health.bedtime).toBeNull();
    expect(parsed.health.wakeTime).toBeNull();
    expect(parsed.health.sleepBySource).toBeNull();
    expect(parsed.health.activeEnergy).toBeNull();
    expect(parsed.health.walkingDistance).toBeNull();
    expect(parsed.health.weight).toBeNull();
    expect(parsed.health.weightDaysLast7).toBeNull();
    expect(parsed.health.meditationMinutes).toBeNull();
    expect(parsed.health.hrv).toBeNull();
    expect(parsed.health.restingHeartRate).toBeNull();
    expect(parsed.health.exerciseMinutes).toBeNull();
    expect(parsed.location).toBeNull();
  });
});
