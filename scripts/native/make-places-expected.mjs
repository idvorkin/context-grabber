#!/usr/bin/env node
// Runs the React Native app's TypeScript clustering on the real fixture and writes what it produced, so the
// native port is checked against the TypeScript on real data (PlacesFixtureTests in native/ContextCore).
//
//   TZ=America/Los_Angeles node scripts/native/make-places-expected.mjs
//
// Needs `npm ci` (it compiles lib/ with the project's own TypeScript). The time zone is pinned because days are
// local; the Swift test pins the same one. Points go to the per-day breakdown in timestamp order (stable), as
// the app reads them from SQLite; clustering sorts for itself.
import { createRequire } from "node:module";
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

if (process.env.TZ !== "America/Los_Angeles") {
  console.error("run with TZ=America/Los_Angeles (the Swift test pins the same zone)");
  process.exit(1);
}
const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const require = createRequire(join(process.env.NODE_PATH || join(root, "node_modules"), "noop.js"));
const ts = require("typescript");

// Compile the handful of lib/ files the clustering and the breakdown need to CommonJS in a scratch directory.
const out = mkdtempSync(join(tmpdir(), "places-expected-"));
mkdirSync(join(out, "lib"));
for (const f of ["clustering_v2", "clustering", "places", "geo", "places_summary", "weekly", "health", "sleep", "stats"]) {
  const src = readFileSync(join(root, "lib", `${f}.ts`), "utf8");
  const js = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } });
  writeFileSync(join(out, "lib", `${f}.js`), js.outputText);
}
const local = createRequire(join(out, "lib", "noop.js"));
const { clusterLocationsV2 } = local("./clustering_v2.js");
const { buildPlacesDailySummary, formatPlacesDailyText } = local("./places_summary.js");

const raw = JSON.parse(readFileSync(join(root, "__tests__/fixtures/locations.json"), "utf8"));
const points = raw.map((r) => ({ latitude: r.latitude, longitude: r.longitude, accuracy: r.accuracy, timestamp: r.timestamp }));
// The fixture's four real known places (the same rows as context-grabber.db).
const knownPlaces = [
  { id: 13, name: "Kettlebility", latitude: 47.6762, longitude: -122.3187, radiusMeters: 100 },
  { id: 15, name: "Milstead & Co", latitude: 47.6508, longitude: -122.3503, radiusMeters: 50 },
  { id: 17, name: "Home", latitude: 47.641901, longitude: -122.304481, radiusMeters: 100 },
  { id: 18, name: "Work", latitude: 47.628937, longitude: -122.343437, radiusMeters: 200 },
];
const { stays, transit } = clusterLocationsV2(points, knownPlaces);
const sorted = points.map((p, i) => [p, i]).sort((a, b) => a[0].timestamp - b[0].timestamp || a[1] - b[1]).map((x) => x[0]);
// "Now" is half an hour after the last point, so the newest day is a partial today.
const now = Math.ceil(sorted[sorted.length - 1].timestamp / 60000) * 60000 + 30 * 60000;
const days = buildPlacesDailySummary(stays, transit, sorted, 14, now);
const text = formatPlacesDailyText(days);

const dest = join(root, "native/ContextCore/Tests/ContextCoreTests/Fixtures/places-expected.json");
mkdirSync(dirname(dest), { recursive: true });
writeFileSync(dest, JSON.stringify({ timeZone: process.env.TZ, now, knownPlaces, stays, transit, days, text }, null, 1) + "\n");
console.log(`${stays.length} stays, ${transit.length} transit, ${days.length} days -> ${dest}`);
