import { describeLocation, locationFields, significantMove, toCallLocation, SIGNIFICANT_MOVE_M } from "../lib/callLocation";
import type { KnownPlace } from "../lib/places";

const HOME: KnownPlace = { id: 1, name: "Home", latitude: 47.6, longitude: -122.3, radiusMeters: 100 };

describe("toCallLocation (#107)", () => {
  it("rounds, names the known place it falls in, and stamps the fix time", () => {
    const l = toCallLocation({ latitude: 47.60001234, longitude: -122.30002345, accuracy: 12.6 }, 1_700_000_000_000, [HOME]);
    expect(l).toEqual({ lat: 47.600012, lon: -122.300023, accuracyM: 13, at: "2023-11-14T22:13:20.000Z", place: "Home" });
    expect(locationFields(l)).toEqual({ lat: 47.600012, lon: -122.300023, accuracy_m: 13, at: "2023-11-14T22:13:20.000Z", place: "Home" });
  });

  it("outside every place the name is null; a missing accuracy is null", () => {
    const l = toCallLocation({ latitude: 47.7, longitude: -122.3 }, 0, [HOME]);
    expect(l.place).toBeNull();
    expect(l.accuracyM).toBeNull();
    expect(toCallLocation({ latitude: 47.7, longitude: -122.3, accuracy: -1 }, 0, []).accuracyM).toBeNull();
  });
});

describe("significantMove", () => {
  const at = (lat: number, lon: number, place: string | null = null) => ({ lat, lon, accuracyM: 10, at: "", place });

  it("the first fix always counts; a place change always counts", () => {
    expect(significantMove(null, at(47.6, -122.3))).toBe(true);
    expect(significantMove(at(47.6, -122.3, "Home"), at(47.6, -122.3, null))).toBe(true);
  });

  it("otherwise only a move of SIGNIFICANT_MOVE_M or more", () => {
    const dLat = SIGNIFICANT_MOVE_M / 111_000; // ~1 degree = 111 km
    expect(significantMove(at(47.6, -122.3), at(47.6 + dLat * 0.5, -122.3))).toBe(false);
    expect(significantMove(at(47.6, -122.3), at(47.6 + dLat * 1.1, -122.3))).toBe(true);
  });
});

describe("describeLocation", () => {
  it("names the place when there is one, coordinates otherwise, accuracy when known", () => {
    expect(describeLocation({ lat: 47.6, lon: -122.3, accuracyM: 12, at: "", place: "Home" })).toBe("Home (±12 m)");
    expect(describeLocation({ lat: 47.6, lon: -122.3, accuracyM: null, at: "", place: null })).toBe("47.6, -122.3");
  });
});
