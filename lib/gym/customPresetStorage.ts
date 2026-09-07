/**
 * The Custom preset, remembered: the sliders' values and which chip was
 * chosen last, in the app's settings table.
 * Spec: docs/superpowers/specs/2026-09-07-gym-timer-custom-preset-design.md
 */
import { getSetting, setSetting } from "../db";
import { getGymDb } from "./gymDb";
import { DEFAULT_CUSTOM, normalizeCustom, type CustomPreset } from "./customPreset";

const PRESET_KEY = "gym_custom_preset";
const CHOSEN_KEY = "gym_active_preset";

export async function loadCustomPreset(): Promise<CustomPreset> {
  const db = getGymDb();
  if (!db) return DEFAULT_CUSTOM;
  try {
    return normalizeCustom(JSON.parse(await getSetting(db, PRESET_KEY, "null")));
  } catch {
    return DEFAULT_CUSTOM;
  }
}

export async function saveCustomPreset(p: CustomPreset): Promise<void> {
  const db = getGymDb();
  if (!db) return;
  await setSetting(db, PRESET_KEY, JSON.stringify(normalizeCustom(p)));
}

/** Which chip was chosen last; null when never. */
export async function loadChosenPreset(): Promise<string | null> {
  const db = getGymDb();
  if (!db) return null;
  const v = await getSetting(db, CHOSEN_KEY, "");
  return v || null;
}

export async function saveChosenPreset(id: string): Promise<void> {
  const db = getGymDb();
  if (!db) return;
  await setSetting(db, CHOSEN_KEY, id);
}
