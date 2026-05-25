import type { HealthData } from "./health";
import type { LocationHistoryItem } from "./db";

export type LocationData = {
  latitude: number;
  longitude: number;
  timestamp: number;
} | null;

export type ContextSnapshot = {
  timestamp: string;
  health: HealthData;
  location: LocationData;
  locationHistory: LocationHistoryItem[];
};
