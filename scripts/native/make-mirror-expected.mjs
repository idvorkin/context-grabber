#!/usr/bin/env node
// The mirror's acceptance bar (spec step 4): the native export equals the React Native app's, byte for byte, for
// the same Health data. This script runs the React Native app's own lib/ code — and a transcript of App.tsx's
// grab (grabHealthData, fetchDayFromHealthKit, grabWeeklyRangeQuery, grabWeeklyData, shareSnapshot, shareRaw) —
// over a fixture, against a fake HealthKit with the Health library's rules (samples newest first by start, a
// range matches every sample overlapping it, a sum over nothing is absent). MirrorFixtureTests in
// native/ContextCore runs the native grab over the same fixture and compares bytes.
//
//   TZ=America/Los_Angeles node scripts/native/make-mirror-expected.mjs
//       builds the fixture (a real two-day heart-rate export plus a synthetic week around it) and writes
//       native/ContextCore/Tests/ContextCoreTests/Fixtures/mirror-{fixture.json,summary-expected.json,raw-expected.json}
//   node scripts/native/make-mirror-expected.mjs --fixture <fixture.json> --out <dir>
//       the expected exports for a fixture the simulator hook wrote (sim-smoke.sh), in the TZ given
//
// Needs typescript from node_modules (NODE_PATH works) and Node 22+ (node:sqlite, for the accessory log's own SQL).
import { createRequire } from "node:module";
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";

const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
};
const fixtureArg = opt("--fixture");
const outArg = opt("--out");
const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const fixturesDir = join(root, "native/ContextCore/Tests/ContextCoreTests/Fixtures");

if (!fixtureArg && process.env.TZ !== "America/Los_Angeles") {
  console.error("run with TZ=America/Los_Angeles (the Swift test pins the same zone)");
  process.exit(1);
}

// ── compile lib/ ────────────────────────────────────────────────────────────────────────────────────────────────
const require = createRequire(join(process.env.NODE_PATH || join(root, "node_modules"), "noop.js"));
const ts = require("typescript");
const out = mkdtempSync(join(tmpdir(), "mirror-expected-"));
mkdirSync(join(out, "lib/gym"), { recursive: true });
for (const f of ["health", "sleep", "weekly", "stats", "share", "summary", "healthCache", "gym/accessoryLog"]) {
  const src = readFileSync(join(root, "lib", `${f}.ts`), "utf8");
  const js = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } });
  writeFileSync(join(out, "lib", `${f}.js`), js.outputText);
}
const local = createRequire(join(out, "lib", "noop.js"));
const { buildHealthData, workoutActivityName } = local("./health.js");
const { buildSleepDetailedBundle } = local("./sleep.js");
const { aggregateHeartRate, aggregateSleep, aggregateMeditation, pickLatestPerDay, formatDateKey } = local("./weekly.js");
const { buildSummaryExport, buildAccessoryLogExport } = local("./share.js");
const cache = local("./healthCache.js");
const accessoryLog = local("./gym/accessoryLog.js");

// expo-sqlite's async API over node:sqlite, so lib/healthCache.ts and lib/gym/accessoryLog.ts run their own SQL.
function expoDb() {
  const db = new DatabaseSync(":memory:");
  return {
    async execAsync(sql) { db.exec(sql); },
    async runAsync(sql, params = []) { return db.prepare(sql).run(...params); },
    async getFirstAsync(sql, params = []) { return db.prepare(sql).get(...params) ?? null; },
    async getAllAsync(sql, params = []) { return db.prepare(sql).all(...params); },
  };
}

// ── the fixture ─────────────────────────────────────────────────────────────────────────────────────────────────
const H = 3600_000, M = 60_000, D = 24 * H;
function buildFixture() {
  const hr = JSON.parse(readFileSync(join(root, "__tests__/fixtures/heart-rate-2d.json"), "utf8"));
  const ms = (iso) => new Date(iso).getTime();
  const at = (y, mo, d, h = 0, mi = 0, s = 0) => new Date(y, mo - 1, d, h, mi, s).getTime();
  let seed = 7;
  const rand = () => ((seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648);
  const now = ms("2026-05-03T19:45:00.000Z"); // 12:45pm PDT, Sunday
  const realStart = ms(hr.windowStart);
  const watch = hr.heartRate[0].source;
  const q = { steps: [], heartRate: [], activeEnergy: [], distance: [], bodyMass: [], hrv: [], restingHeartRate: [], exerciseTime: [] };

  // Heart rate, HRV, resting rate: the real export for its two days, a synthetic week before it.
  for (const s of hr.heartRate) q.heartRate.push({ start: ms(s.startDate), end: ms(s.endDate), value: s.bpm, source: s.source });
  for (let t = at(2026, 4, 25, 0, 3, 17); t < realStart; t += 10 * M + Math.floor(rand() * 4) * M) {
    const hour = new Date(t).getHours();
    const base = hour < 7 ? 56 : hour > 21 ? 62 : 74;
    const v = Math.round(base + rand() * 25);
    q.heartRate.push({ start: t, end: t, value: v, source: watch });
  }
  for (const s of hr.hrv) q.hrv.push({ start: ms(s.startDate), end: ms(s.endDate), value: s.bpm, source: s.source });
  for (const s of hr.restingHeartRate) q.restingHeartRate.push({ start: ms(s.startDate), end: ms(s.endDate), value: s.bpm, source: s.source });
  for (let d = 25; d <= 30; d++) {
    for (const h of [2, 5, 9, 15]) {
      const t = at(2026, 4, d, h, 11, 3);
      q.hrv.push({ start: t, end: t + 59_000, value: 20 + rand() * 40, source: watch });
    }
    q.restingHeartRate.push({ start: at(2026, 4, d, 0, 4, 9), end: at(2026, 4, d, 23, 55, 1), value: 58 + Math.floor(rand() * 8), source: watch });
  }
  // Active energy: the Watch's real buckets (the iPad's overlap them and Health would de-duplicate); synthetic before.
  for (const s of hr.activeEnergySamples) {
    if (s.source !== watch) continue;
    q.activeEnergy.push({ start: ms(s.startDate), end: ms(s.endDate), value: s.kcal, source: s.source });
  }
  for (let t = at(2026, 4, 25, 0, 2, 0); t < realStart; t += 15 * M) {
    const hour = new Date(t).getHours();
    q.activeEnergy.push({ start: t, end: t + 14 * M, value: Math.round((hour < 7 ? 1 : 6 + rand() * 30) * 1000) / 1000, source: watch });
  }
  // Steps and distance from the phone, hourly 7am–10pm; nothing on Wednesday Apr 29 (the phone stayed home).
  for (let d = 25; d <= 34; d++) {
    const day = new Date(2026, 3, d);
    if (day.getDate() === 29 && day.getMonth() === 3) continue;
    for (let h = 7; h <= 22; h++) {
      const t = at(day.getFullYear(), day.getMonth() + 1, day.getDate(), h, 5, 0);
      if (t + 50 * M > now) break;
      const steps = Math.floor(rand() * 900) + (h === 18 ? 2400 : 40);
      q.steps.push({ start: t, end: t + 50 * M, value: steps, source: "iPhone" });
      q.distance.push({ start: t, end: t + 50 * M, value: Math.round(steps * 0.000762 * 10000) / 10000, source: "iPhone" });
    }
  }
  // Weigh-ins (kg): two on Friday (the later one counts), none Thursday.
  for (const [d, h, mi, kg] of [[27, 7, 10, 82.1], [29, 7, 5, 81.85], [26, 6, 50, 82.4], [31, 7, 20, 81.6], [31, 21, 0, 82.3], [33, 7, 2, 81.45]]) {
    const t = new Date(2026, 3, d, h, mi).getTime();
    q.bodyMass.push({ start: t, end: t, value: kg, source: "Withings" });
  }

  // Workouts, with their exercise minutes: one began Saturday 11:40pm and ended after midnight.
  const workouts = [
    { activityType: 20, start: at(2026, 4, 28, 18, 30), minutes: 45, energyKcal: 380, distanceMeters: null },
    { activityType: 52, start: at(2026, 5, 1, 19, 0, 12), minutes: 40, energyKcal: 210.4, distanceMeters: 3215 },
    { activityType: 57, start: at(2026, 5, 2, 23, 40), minutes: 45, energyKcal: 95, distanceMeters: null },
    { activityType: 63, start: at(2026, 5, 3, 10, 0, 30), minutes: 25, energyKcal: 290, distanceMeters: 0 },
  ];
  // The real class (Strength Training, Saturday morning) from the export.
  for (const w of hr.workouts) {
    workouts.push({ activityType: w.workoutType, start: ms(w.startDate), seconds: w.durationSec, end: ms(w.endDate), energyKcal: w.totalEnergyKcal, distanceMeters: w.totalDistanceMeters });
  }
  const fxWorkouts = workouts.map((w) => {
    const seconds = w.seconds ?? w.minutes * 60;
    return { activityType: w.activityType, start: w.start, end: w.end ?? w.start + seconds * 1000, durationSeconds: seconds, energyKcal: w.energyKcal, distanceMeters: w.distanceMeters };
  });
  for (const w of fxWorkouts) {
    // Exercise minutes in 5-minute pieces, never across midnight (Health's sums would split them).
    for (let t = w.start; t + 5 * M <= w.end; t += 5 * M) {
      if (new Date(t).getDate() !== new Date(t + 5 * M - 1).getDate()) continue;
      q.exerciseTime.push({ start: t, end: t + 5 * M, value: 5, source: watch });
    }
  }

  // Sleep from two sources: the Watch's stages, and an app's in-bed and asleep spans over the same nights.
  const sleep = [];
  const autosleep = "AutoSleep";
  for (let d = 25; d <= 32; d++) {
    const bed = new Date(2026, 3, d, 22, 30 + Math.floor(rand() * 60), 7).getTime();
    let t = bed;
    const watchTonight = d !== 29; // Wednesday night the Watch was charging
    if (watchTonight) {
      if (d % 2 === 0) { sleep.push({ start: t, end: t + 18 * M, value: 2, source: watch }); t += 18 * M; } // onset
      const pattern = [[3, 50], [4, 40], [3, 35], [5, 20], [2, 4], [3, 60], [4, 25], [5, 30], [3, 45], [5, 35], [2, 6], [3, 40]];
      for (const [value, minutes] of pattern) {
        if (d === 30 && value === 5 && minutes === 30) { t += 95 * M; continue; } // a tracker gap
        sleep.push({ start: t, end: t + minutes * M, value, source: watch });
        t += minutes * M;
      }
    } else {
      t += 7 * H + 20 * M;
    }
    sleep.push({ start: bed - 7 * M, end: t + 9 * M, value: 0, source: autosleep });
    sleep.push({ start: bed + 3 * M, end: t - 11 * M, value: 1, source: autosleep });
  }
  // A bed-like blip one afternoon, and a late-morning nap that belongs to the night before.
  sleep.push({ start: at(2026, 4, 28, 15, 2, 11), end: at(2026, 4, 28, 15, 14, 40), value: 3, source: watch });
  sleep.push({ start: at(2026, 5, 2, 10, 15, 3), end: at(2026, 5, 2, 10, 55, 9), value: 1, source: autosleep });

  // Mindful minutes early in the week, then nothing.
  const mindful = [
    { start: at(2026, 4, 27, 7, 30, 1), end: at(2026, 4, 27, 7, 40, 31) },
    { start: at(2026, 4, 28, 7, 15, 2), end: at(2026, 4, 28, 7, 30, 2) },
    { start: at(2026, 4, 28, 21, 50, 5), end: at(2026, 4, 28, 22, 0, 5) },
    { start: at(2026, 4, 29, 6, 58, 0), end: at(2026, 4, 29, 7, 9, 45) },
  ];

  // The accessory log: two items saved together Tuesday, one Friday, and one too old for the week.
  const accessory = [];
  const save = (t, ids) => {
    for (const id of ids) {
      const item = accessoryLog.ACCESSORY_ITEMS.find((i) => i.id === id);
      accessory.push({ itemId: id, itemName: item.label, loggedAt: t, dateKey: formatDateKey(new Date(t)) });
    }
  };
  save(at(2026, 4, 20, 19, 0), ["mcgill_big_3"]);
  save(at(2026, 4, 28, 19, 20, 4), ["half_lotus", "dead_hangs"]);
  save(at(2026, 5, 1, 20, 5, 9), ["pigeon_stretch"]);

  // Health would split a sum across a boundary; keep cumulative samples inside one local day and before now.
  const sameDay = (s) => formatDateKey(new Date(s.start)) === formatDateKey(new Date(s.end - 1));
  for (const k of ["steps", "activeEnergy", "distance", "exerciseTime"]) q[k] = q[k].filter((s) => sameDay(s) && s.end <= now);
  for (const k of Object.keys(q)) q[k] = q[k].filter((s) => s.start <= now);
  return { timeZone: process.env.TZ, now, quantity: q, sleep, mindful, workouts: fxWorkouts, accessory };
}

// ── a fake HealthKit with the library's rules ───────────────────────────────────────────────────────────────────
function fakeHealthKit(fx) {
  const overlaps = (s, f) => s.start <= f.endDate.getTime() && s.end >= f.startDate.getTime();
  const newestFirst = (xs) => xs.map((x, i) => [x, i]).sort((a, b) => b[0].start - a[0].start || a[1] - b[1]).map((p) => p[0]);
  const src = (name) => ({ source: { name } });
  const qty = (s) => ({ startDate: new Date(s.start), endDate: new Date(s.end), quantity: s.value, sourceRevision: src(s.source) });
  return {
    async queryStatisticsForQuantity(kind, _stats, { filter }) {
      const hits = (fx.quantity[kind] ?? []).filter((s) => overlaps(s, filter.date));
      return hits.length === 0 ? {} : { sumQuantity: { quantity: newestFirst(hits).reduce((a, s) => a + s.value, 0) } };
    },
    async getMostRecentQuantitySample(kind) {
      const s = newestFirst(fx.quantity[kind] ?? [])[0];
      return s ? qty(s) : undefined;
    },
    async queryQuantitySamples(kind, { filter }) {
      return newestFirst((fx.quantity[kind] ?? []).filter((s) => overlaps(s, filter.date))).map(qty);
    },
    async queryCategorySamples(kind, { filter }) {
      const xs = kind === "sleep" ? fx.sleep : fx.mindful;
      return newestFirst(xs.filter((s) => overlaps(s, filter.date))).map((s) => ({
        startDate: new Date(s.start), endDate: new Date(s.end), value: s.value, sourceRevision: src(s.source),
      }));
    },
    async queryWorkoutSamples({ filter }) {
      return newestFirst(fx.workouts.filter((w) => overlaps(w, filter.date))).map((w) => ({
        toJSON: () => ({
          workoutActivityType: w.activityType,
          startDate: new Date(w.start),
          endDate: new Date(w.end),
          duration: { quantity: w.durationSeconds, unit: "s" },
          totalEnergyBurned: w.energyKcal == null ? undefined : { quantity: w.energyKcal, unit: "kcal" },
          totalDistance: w.distanceMeters == null ? undefined : { quantity: w.distanceMeters, unit: "m" },
        }),
      }));
    },
  };
}
const QTI = {
  stepCount: "steps", heartRate: "heartRate", activeEnergy: "activeEnergy", distance: "distance", bodyMass: "bodyMass",
  hrv: "hrv", restingHeartRate: "restingHeartRate", exerciseTime: "exerciseTime",
};
const CTI = { sleep: "sleep", mindfulSession: "mindful" };

// ── App.tsx, transcribed (the one change: `now` is passed in instead of `new Date()`) ─────────────────────────────
async function grabHealthData(HealthKit, nowMs) {
  const now = new Date(nowMs);
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);
  const dateFilter = { date: { startDate: startOfDay, endDate: now } };
  const todayNoon = new Date(now);
  todayNoon.setHours(12, 0, 0, 0);
  const yesterdayNoon = new Date(todayNoon.getTime() - 24 * 60 * 60 * 1000);
  const sleepDateFilter = { date: { startDate: yesterdayNoon, endDate: todayNoon } };
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const weightWeekFilter = { date: { startDate: sevenDaysAgo, endDate: now } };
  const results = await Promise.allSettled([
    HealthKit.queryStatisticsForQuantity(QTI.stepCount, ["cumulativeSum"], { filter: dateFilter }),
    HealthKit.getMostRecentQuantitySample(QTI.heartRate),
    HealthKit.queryStatisticsForQuantity(QTI.activeEnergy, ["cumulativeSum"], { filter: dateFilter }),
    HealthKit.queryStatisticsForQuantity(QTI.distance, ["cumulativeSum"], { filter: dateFilter }),
    HealthKit.queryCategorySamples(CTI.sleep, { limit: 0, filter: sleepDateFilter }),
    HealthKit.getMostRecentQuantitySample(QTI.bodyMass, "kg"),
    HealthKit.queryCategorySamples(CTI.mindfulSession, { limit: 0, filter: dateFilter }),
    HealthKit.queryQuantitySamples(QTI.bodyMass, { limit: 0, filter: weightWeekFilter, unit: "kg" }),
    HealthKit.getMostRecentQuantitySample(QTI.hrv),
    HealthKit.getMostRecentQuantitySample(QTI.restingHeartRate),
    HealthKit.queryStatisticsForQuantity(QTI.exerciseTime, ["cumulativeSum"], { filter: dateFilter }),
  ]);
  const sleepResult = results[4];
  let mappedSleep;
  if (sleepResult.status === "fulfilled" && sleepResult.value) {
    mappedSleep = {
      status: "fulfilled",
      value: sleepResult.value.map((s) => ({
        startDate: s.startDate, endDate: s.endDate, value: s.value,
        source: s.sourceRevision?.source?.toJSON?.()?.name ?? s.sourceRevision?.source?.name ?? "Unknown",
      })),
    };
  } else {
    mappedSleep = sleepResult.status === "fulfilled" ? { status: "fulfilled", value: [] } : { status: "rejected", reason: sleepResult.reason };
  }
  const health = buildHealthData([results[0], results[1], results[2], results[3], mappedSleep, results[5], results[6], results[7], results[8], results[9], results[10]]);
  try {
    const startOfDay2 = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const workoutSamples = await HealthKit.queryWorkoutSamples({ limit: 0, filter: { date: { startDate: startOfDay2, endDate: now } } });
    health.workouts = workoutSamples.map((w) => {
      const json = w.toJSON ? w.toJSON() : w;
      return {
        activityType: workoutActivityName(json.workoutActivityType),
        durationMinutes: Math.round((json.duration?.quantity ?? 0) / 60),
        energyBurned: json.totalEnergyBurned?.quantity ? Math.round(json.totalEnergyBurned.quantity) : null,
        distanceKm: json.totalDistance?.quantity ? Math.round(json.totalDistance.quantity / 10) / 100 : null,
        startTime: new Date(json.startDate).toISOString(),
        endTime: new Date(new Date(json.startDate).getTime() + (json.duration?.quantity ?? 0) * 1000).toISOString(),
      };
    });
  } catch {}
  return health;
}

async function fetchDayFromHealthKit(HealthKit, metric, dateKey) {
  const dayStart = new Date(dateKey + "T00:00:00");
  const dayEnd = new Date(dateKey + "T23:59:59.999");
  const dayFilter = { date: { startDate: dayStart, endDate: dayEnd } };
  switch (metric) {
    case "steps": case "activeEnergy": case "walkingDistance": {
      const identifier = metric === "steps" ? QTI.stepCount : metric === "activeEnergy" ? QTI.activeEnergy : QTI.distance;
      const result = await HealthKit.queryStatisticsForQuantity(identifier, ["cumulativeSum"], { filter: dayFilter }).catch(() => null);
      const value = result?.sumQuantity?.quantity != null ? Math.round(result.sumQuantity.quantity * 100) / 100 : null;
      return { computed: { date: dateKey, value }, raw: [{ date: dateKey, value, source: "statistics" }] };
    }
    case "exerciseMinutes": {
      const samples = await HealthKit.queryQuantitySamples(QTI.exerciseTime, { limit: 0, filter: dayFilter });
      const mapped = samples.map((s) => ({
        startDate: new Date(s.startDate).toISOString(), endDate: s.endDate ? new Date(s.endDate).toISOString() : undefined,
        quantity: s.quantity, source: s.sourceRevision?.source?.name ?? "unknown",
      }));
      const totalMinutes = mapped.reduce((sum, s) => sum + (s.quantity ?? 0), 0);
      const value = totalMinutes > 0 ? Math.round(totalMinutes) : null;
      return { computed: { date: dateKey, value }, raw: mapped };
    }
    case "heartRate": case "hrv": case "restingHeartRate": {
      const identifier = metric === "heartRate" ? QTI.heartRate : metric === "hrv" ? QTI.hrv : QTI.restingHeartRate;
      const samples = await HealthKit.queryQuantitySamples(identifier, { limit: 0, filter: dayFilter });
      const mapped = samples.map((s) => ({ startDate: new Date(s.startDate).toISOString(), quantity: s.quantity }));
      const buckets = aggregateHeartRate(mapped.map((m) => ({ startDate: m.startDate, quantity: m.quantity })), dayEnd, 1);
      return { computed: buckets[0], raw: mapped };
    }
    case "meditation": {
      const sessions = await HealthKit.queryCategorySamples(CTI.mindfulSession, { limit: 0, filter: dayFilter });
      const mapped = [...sessions].map((s) => ({ startDate: new Date(s.startDate).toISOString(), endDate: new Date(s.endDate).toISOString() }));
      const buckets = aggregateMeditation(mapped, dayEnd, 1);
      return { computed: buckets[0], raw: mapped };
    }
  }
  throw new Error(`no per-day query for ${metric}`);
}

const RANGE_QUERY_METRICS = ["weight", "sleep"];
const kgToLbs = (data) => data.map((d) => ({ ...d, value: d.value != null ? Math.round(d.value * 2.20462) : null }));

async function grabWeeklyRangeQuery(HealthKit, db, metric, nowMs) {
  const now = new Date(nowMs);
  const todayKey = formatDateKey(now);
  const sevenDaysAgo = new Date(now.getTime() - (metric === "sleep" ? 8 : 7) * 24 * 60 * 60 * 1000);
  const dateFilter = { date: { startDate: sevenDaysAgo, endDate: now } };
  let results, rawSamples;
  if (metric === "weight") {
    const samples = await HealthKit.queryQuantitySamples(QTI.bodyMass, { limit: 0, filter: dateFilter, unit: "kg" });
    rawSamples = samples.map((s) => ({ startDate: new Date(s.startDate).toISOString(), quantity: s.quantity }));
    results = pickLatestPerDay(rawSamples.map((m) => ({ startDate: m.startDate, quantity: m.quantity })), now);
  } else {
    const samples = await HealthKit.queryCategorySamples(CTI.sleep, { limit: 0, filter: dateFilter });
    rawSamples = [...samples].map((s) => ({
      startDate: new Date(s.startDate).toISOString(), endDate: new Date(s.endDate).toISOString(), value: s.value, source: s.sourceName,
    }));
    results = aggregateSleep(rawSamples, now);
    buildSleepDetailedBundle(rawSamples, now);
  }
  for (const bucket of results) {
    if (bucket.date !== todayKey) {
      await cache.putComputedCached(db, metric, bucket.date, bucket);
      const dayRaw = rawSamples.filter((s) => formatDateKey(new Date(s.startDate)) === bucket.date);
      if (dayRaw.length > 0) await cache.putRawCached(db, metric, bucket.date, dayRaw);
    }
  }
  if (metric === "weight") return kgToLbs(results);
  return results;
}

async function grabWeeklyData(HealthKit, db, metric, nowMs) {
  if (RANGE_QUERY_METRICS.includes(metric)) return grabWeeklyRangeQuery(HealthKit, db, metric, nowMs);
  const now = new Date(nowMs);
  const todayKey = formatDateKey(now);
  const dateKeys = cache.buildDateKeys(now, 7);
  const cached = await cache.getComputedCachedBatch(db, metric, dateKeys);
  const { cachedDays, fetchDays } = cache.partitionDays(todayKey, dateKeys, cached);
  const freshResults = await Promise.all(
    fetchDays.map(async (dateKey) => {
      const result = await fetchDayFromHealthKit(HealthKit, metric, dateKey);
      if (dateKey !== todayKey) {
        await cache.putComputedCached(db, metric, dateKey, result.computed);
        await cache.putRawCached(db, metric, dateKey, result.raw);
      }
      return { dateKey, computed: result.computed };
    }),
  );
  const merged = new Map(cachedDays);
  for (const { dateKey, computed } of freshResults) merged.set(dateKey, computed);
  const result = dateKeys.map((key) => merged.get(key) ?? { date: key, value: null });
  if (metric === "weight") return kgToLbs(result);
  return result;
}

async function expectedExports(fx) {
  const HealthKit = fakeHealthKit(fx);
  const db = expoDb();
  await cache.initCacheTables(db);
  await accessoryLog.initAccessoryLogTable(db);
  for (const a of fx.accessory) {
    await db.runAsync("INSERT INTO accessory_log (item_id, item_name, logged_at, date_key) VALUES (?, ?, ?, ?)", [a.itemId, a.itemName, a.loggedAt, a.dateKey]);
  }
  // grabContext: the snapshot is stamped after the reads; here "now" is the stamp.
  const health = await grabHealthData(HealthKit, fx.now);
  const snapshot = { timestamp: new Date(fx.now).toISOString(), health, location: null, locationHistory: [] };
  // shareSnapshot (no location history: places null; no roles yet in the native app: roles null).
  const keys = ["steps", "heartRate", "sleep", "activeEnergy", "walkingDistance", "weight", "meditation", "hrv", "restingHeartRate", "exerciseMinutes"];
  const all = await Promise.all(keys.map((k) => grabWeeklyData(HealthKit, db, k, fx.now)));
  const weeklyData = {
    steps: all[0], heartRate: all[1], sleep: all[2], activeEnergy: all[3], walkingDistance: all[4],
    weight: all[5], meditation: all[6], hrv: all[7], restingHeartRate: all[8], exerciseMinutes: all[9],
  };
  const sevenDaysAgo = fx.now - accessoryLog.ACCESSORY_LOG_WINDOW_DAYS * 24 * 3600 * 1000;
  const accessoryBlock = buildAccessoryLogExport(await accessoryLog.getAccessoryLog(db, sevenDaysAgo));
  const summary = JSON.stringify(buildSummaryExport(weeklyData, snapshot.health, null, null, accessoryBlock));
  // shareRaw
  const raw = JSON.stringify({ timestamp: snapshot.timestamp, health: snapshot.health, location: snapshot.location, locationClusters: null }, null, 2);
  return { summary, raw };
}

// ── main ────────────────────────────────────────────────────────────────────────────────────────────────────────
let fx, dest;
if (fixtureArg) {
  fx = JSON.parse(readFileSync(fixtureArg, "utf8"));
  dest = outArg ?? dirname(fixtureArg);
} else {
  fx = buildFixture();
  dest = fixturesDir;
  mkdirSync(dest, { recursive: true });
  writeFileSync(join(dest, "mirror-fixture.json"), JSON.stringify(fx) + "\n");
}
const { summary, raw } = await expectedExports(fx);
writeFileSync(join(dest, "mirror-summary-expected.json"), summary);
writeFileSync(join(dest, "mirror-raw-expected.json"), raw);
const counts = Object.entries(fx.quantity).map(([k, v]) => `${k} ${v.length}`).join(", ");
console.log(`${counts}, sleep ${fx.sleep.length}, workouts ${fx.workouts.length} -> ${dest} (summary ${summary.length} B, raw ${raw.length} B)`);
