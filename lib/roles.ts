/**
 * The 11 roles from Igor's eulogy. This module owns role definitions,
 * activity-score aggregation, and the rule for "needs attention".
 *
 * Eulogy passages here are short placeholders; Igor can replace them with
 * the verbatim idvork.in/eulogy text in a follow-up — the role IDs and
 * order are what other modules depend on.
 */

import type { DailyValue, HeartRateDaily, MetricKey } from "./weekly";
import type { RoleMoment } from "./roleMoments";

/** Loose shape accepted by computeWeekActivity — matches App.tsx's weeklyCache. */
export type WeeklyCacheLike = Partial<
  Record<MetricKey, DailyValue[] | HeartRateDaily[]>
>;

export type RoleId =
  | "smiles"
  | "carfree"
  | "habits"
  | "fit"
  | "emo"
  | "tech"
  | "pro"
  | "family"
  | "tori"
  | "amelia"
  | "zach";

export type RoleDef = {
  id: RoleId;
  /** Display name as used in headlines. */
  name: string;
  /** Compact one-line label for narrow contexts. */
  short: string;
  /** Hex accent color used on cards, dots, sparklines. */
  color: string;
  /** Verbatim or placeholder eulogy passage. */
  eulogyPassage: string;
  /** 3–5 identity-marker phrases shown as chips on the role detail. */
  eulogyMarkers: string[];
  /**
   * Days-since-last-shown threshold above which the role is flagged
   * "needs attention". 0 disables the rule.
   */
  attentionThresholdDays: number;
};

/** Eulogy order — DO NOT reorder. UI depends on this for constellation layout. */
export const ROLES: ReadonlyArray<RoleDef> = [
  {
    id: "smiles",
    name: "Dealer of smiles & wonder",
    short: "Smiles & wonder",
    color: "#f6c177",
    eulogyPassage:
      "Igor was a dealer of smiles and wonder — the man who made strangers laugh at coffee shops.",
    eulogyMarkers: ["small kindnesses", "wonder-as-default", "laughter as a gift"],
    attentionThresholdDays: 7,
  },
  {
    id: "carfree",
    name: "Mostly car-free spirit",
    short: "Car-free",
    color: "#9ccfd8",
    eulogyPassage:
      "He walked, biked, and took the bus on purpose — moving slowly through his city.",
    eulogyMarkers: ["legs first", "city at human pace", "fewer keys"],
    attentionThresholdDays: 5,
  },
  {
    id: "habits",
    name: "Disciple of 7 habits",
    short: "7 habits",
    color: "#c4a7e7",
    eulogyPassage:
      "He kept showing up to the same small practices — 5am wake, gratitude, planning the week.",
    eulogyMarkers: ["small daily reps", "first-things-first", "weekly review"],
    attentionThresholdDays: 4,
  },
  {
    id: "fit",
    name: "Fit fellow",
    short: "Fit",
    color: "#ebbcba",
    eulogyPassage:
      "He moved his body almost every day — gym, weight on the scale, sleep that wasn't optional.",
    eulogyMarkers: ["$1000 weight pledge", "daily strength", "boring consistency"],
    attentionThresholdDays: 5,
  },
  {
    id: "emo",
    name: "Emotionally healthy human",
    short: "Emo",
    color: "#a3be8c",
    eulogyPassage:
      "He noticed his feelings — meditation, journaling, gratitude — instead of letting them run him.",
    eulogyMarkers: ["grandmother mind", "feelings as data", "morning sit"],
    attentionThresholdDays: 3,
  },
  {
    id: "tech",
    name: "Technologist",
    short: "Tech",
    color: "#88c0d0",
    eulogyPassage:
      "He built things for the joy of building — terminals, weekend projects, half-finished tools left for someone else to finish.",
    eulogyMarkers: ["weekend hacks", "tools-for-self", "leave it better"],
    attentionThresholdDays: 5,
  },
  {
    id: "pro",
    name: "Professional",
    short: "Pro",
    color: "#81a1c1",
    eulogyPassage:
      "At work he was the calm one — the person who unblocked teams and let other people take the credit.",
    eulogyMarkers: ["unblock teams", "calm-under-fire", "credit to others"],
    attentionThresholdDays: 5,
  },
  {
    id: "family",
    name: "Family man",
    short: "Family",
    color: "#bf616a",
    eulogyPassage:
      "Sundays at his house meant dinner, board games, and the kids' friends parked in the kitchen.",
    eulogyMarkers: ["Sunday dinner", "open kitchen", "kids' friends welcome"],
    attentionThresholdDays: 7,
  },
  {
    id: "tori",
    name: "Husband to Tori",
    short: "Husband · Tori",
    color: "#d08770",
    eulogyPassage:
      "He chose Tori, on purpose, every day — Tori-light, Igor-heavy.",
    eulogyMarkers: ["when Igor met Tori", "lifelong partner", "Tori-light, Igor-heavy"],
    attentionThresholdDays: 7,
  },
  {
    id: "amelia",
    name: "Father to Amelia",
    short: "Father · Amelia",
    color: "#ebcb8b",
    eulogyPassage:
      "He showed up for Amelia — arboretum walks, listening more than talking, the long view.",
    eulogyMarkers: ["arboretum walks", "listen more than talk", "the long view"],
    attentionThresholdDays: 5,
  },
  {
    id: "zach",
    name: "Father to Zach",
    short: "Father · Zach",
    color: "#a3be8c",
    eulogyPassage:
      "He showed up for Zach — pickup-game energy, dad jokes, a deliberate hand on the shoulder.",
    eulogyMarkers: ["pickup-game energy", "dad jokes", "deliberate presence"],
    attentionThresholdDays: 5,
  },
];

export function getRole(id: RoleId): RoleDef {
  const r = ROLES.find((x) => x.id === id);
  if (!r) throw new Error(`Unknown role id: ${id}`);
  return r;
}

// ─── Week activity ───────────────────────────────────────────────────────────

export type RoleSignal = {
  label: string;
  /** Numeric magnitude for ranking. */
  value: number;
  /** Display string for the signal value. */
  display: string;
};

export type RoleWeekActivity = {
  roleId: RoleId;
  /** 0–100 weighted blend of contributing signals. */
  score: number;
  /** 7 daily intensity values (oldest → newest) for the bar strip. */
  bars: number[];
  /** Single-sentence summary like "3 gym · 6 days weighed · 7.1h avg". */
  activityLine: string;
  /** Most recent contributing event in ISO 8601, or null. */
  lastShownIso: string | null;
  daysSinceLastShown: number | null;
  attention: { flagged: boolean; reason: string | null };
};

export type WeekActivityContext = {
  health: WeeklyCacheLike;
  moments: RoleMoment[];
  now: Date;
};

/**
 * Aggregate a role's this-week activity from existing data + tagged moments.
 *
 * Each role pulls from a different mix of signals — `fit` is workouts +
 * weight + sleep, `tech` has no auto-signal in v1 and relies on manual
 * moments. The score is a heuristic ramp; the *direction* matters more
 * than the absolute number.
 */
export function computeWeekActivity(
  roleId: RoleId,
  ctx: WeekActivityContext,
): RoleWeekActivity {
  const def = getRole(roleId);
  const moments = ctx.moments.filter((m) => m.roleId === roleId);

  const bars = new Array(7).fill(0) as number[];
  const signals: RoleSignal[] = [];
  let lastShownIso: string | null = null;

  // Walk last 7 days; figure out where today sits.
  const todayMidnight = new Date(ctx.now);
  todayMidnight.setHours(0, 0, 0, 0);

  // Manual + auto moments contribute 1 unit each to the day they fall in.
  for (const m of moments) {
    const day = new Date(m.timestamp);
    day.setHours(0, 0, 0, 0);
    const daysAgo = Math.round(
      (todayMidnight.getTime() - day.getTime()) / (1000 * 3600 * 24),
    );
    if (daysAgo >= 0 && daysAgo < 7) {
      // bars[0] = 6 days ago, bars[6] = today
      bars[6 - daysAgo] += 1;
    }
    if (!lastShownIso || new Date(m.timestamp).toISOString() > lastShownIso) {
      lastShownIso = new Date(m.timestamp).toISOString();
    }
  }

  // Per-role health signals.
  switch (roleId) {
    case "fit": {
      const exer = (ctx.health.exerciseMinutes ?? []) as DailyValue[];
      let workoutDays = 0;
      for (let i = 0; i < exer.length && i < 7; i++) {
        const v = exer[exer.length - 1 - i]?.value ?? 0;
        const bucket = 6 - i;
        if (bucket >= 0) bars[bucket] += v > 0 ? 1 : 0;
        if (v > 0) {
          workoutDays += 1;
          const candidate = new Date(exer[exer.length - 1 - i].date).toISOString();
          if (!lastShownIso || candidate > lastShownIso) lastShownIso = candidate;
        }
      }
      const weight = (ctx.health.weight ?? []) as DailyValue[];
      const weighedDays = weight.filter((d) => d.value != null).length;
      const sleep = (ctx.health.sleep ?? []) as DailyValue[];
      const sleepValues = sleep
        .map((s) => s.value)
        .filter((v): v is number => v != null);
      const avgSleep =
        sleepValues.length > 0
          ? sleepValues.reduce((a, b) => a + b, 0) / sleepValues.length
          : null;
      signals.push({
        label: "Workouts",
        value: workoutDays,
        display: `${workoutDays} gym`,
      });
      signals.push({
        label: "Weighed",
        value: weighedDays,
        display: `${weighedDays} weighed`,
      });
      if (avgSleep != null) {
        signals.push({
          label: "Sleep avg",
          value: avgSleep,
          display: `${avgSleep.toFixed(1)}h avg`,
        });
      }
      break;
    }
    case "emo": {
      const med = (ctx.health.meditation ?? []) as DailyValue[];
      let medDays = 0;
      for (let i = 0; i < med.length && i < 7; i++) {
        const v = med[med.length - 1 - i]?.value ?? 0;
        const bucket = 6 - i;
        if (bucket >= 0) bars[bucket] += v > 0 ? 1 : 0;
        if (v > 0) {
          medDays += 1;
          const candidate = new Date(med[med.length - 1 - i].date).toISOString();
          if (!lastShownIso || candidate > lastShownIso) lastShownIso = candidate;
        }
      }
      signals.push({
        label: "Meditation",
        value: medDays,
        display: `${medDays} meditated`,
      });
      break;
    }
    case "carfree": {
      const dist = (ctx.health.walkingDistance ?? []) as DailyValue[];
      let activeDays = 0;
      let totalKm = 0;
      for (let i = 0; i < dist.length && i < 7; i++) {
        const v = dist[dist.length - 1 - i]?.value ?? 0;
        const bucket = 6 - i;
        if (bucket >= 0) bars[bucket] += v > 2 ? 1 : 0;
        if (v > 2) {
          activeDays += 1;
          totalKm += v;
        }
      }
      signals.push({
        label: "Walk-heavy days",
        value: activeDays,
        display: `${activeDays} days >2km`,
      });
      if (totalKm > 0) {
        signals.push({
          label: "Distance",
          value: totalKm,
          display: `${totalKm.toFixed(1)} km`,
        });
      }
      break;
    }
    default: {
      // smiles, habits, tech, pro, family, tori, amelia, zach — manual-tag-only in v1.
      signals.push({
        label: "Tagged moments",
        value: moments.length,
        display:
          moments.length === 0
            ? "no tags yet"
            : `${moments.length} tagged`,
      });
    }
  }

  // Score: a rough blend. Cap at 100. Each bar unit ≈ ~10 pts (with cap).
  const barSum = bars.reduce((a, b) => a + b, 0);
  const score = Math.min(100, Math.round(barSum * 10 + moments.length * 5));

  const daysSinceLastShown = lastShownIso
    ? Math.floor(
        (todayMidnight.getTime() - startOfDay(new Date(lastShownIso)).getTime()) /
          (1000 * 3600 * 24),
      )
    : null;

  const attention = computeAttention(def, score, daysSinceLastShown);

  const activityLine = signals.map((s) => s.display).join(" · ");

  return {
    roleId,
    score,
    bars,
    activityLine: activityLine || "no signal this week",
    lastShownIso,
    daysSinceLastShown,
    attention,
  };
}

function startOfDay(d: Date): Date {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function computeAttention(
  def: RoleDef,
  _score: number,
  daysSinceLastShown: number | null,
): { flagged: boolean; reason: string | null } {
  // v1: threshold-only. The spec's score-based rule requires last-week
  // comparison too, which we don't compute yet — adding it without
  // last-week data would over-flag.
  if (def.attentionThresholdDays <= 0) {
    return { flagged: false, reason: null };
  }
  if (daysSinceLastShown == null) {
    return { flagged: true, reason: "Not shown this week" };
  }
  if (daysSinceLastShown >= def.attentionThresholdDays) {
    return {
      flagged: true,
      reason: `Last shown ${daysSinceLastShown} days ago`,
    };
  }
  return { flagged: false, reason: null };
}
