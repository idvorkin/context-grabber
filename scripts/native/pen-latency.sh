#!/usr/bin/env bash
# Story 1311 (context-grabber-7xv6): print the board's Pencil-to-frame latency lines (`board_pen_latency`) from the session
# logs pulled off the devices, oldest first: device and session, surface, count, p50, p90, slowest (ms) and the refresh
# rate. Surfaces (story 1324): board (the board's own, one Pencil moment in four), native and web (Ink side by side's
# two halves, per stroke, the web board's own definition, so those two compare with each other).
# Usage: scripts/native/pen-latency.sh [logs-dir]   (default ~/tmp/agent/grabber-logs; run `just pull-logs` first)
set -euo pipefail
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi
dir="${1:-$HOME/tmp/agent/grabber-logs}"
[ -d "$dir" ] || { echo "pen-latency: no logs at $dir (just pull-logs)" >&2; exit 1; }
python3 - "$dir" <<'PY'
import glob, json, os, sys
root = sys.argv[1]
rows = 0
for path in sorted(glob.glob(os.path.join(root, "*", "logs", "*.jsonl")), key=os.path.basename):
    device = os.path.basename(os.path.dirname(os.path.dirname(path)))
    with open(path, errors="replace") as f:
        for line in f:
            if "board_pen_latency" not in line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("action") != "board_pen_latency":
                continue
            rows += 1
            surface = e.get("surface", "board")
            where = "{} {}: {}:".format(device, os.path.basename(path), surface)
            if surface == "board":
                print("{} {} moments, p50 {} ms, p90 {} ms, slowest {} ms, {} Hz".format(
                    where, e.get("count"), e.get("p50_ms"), e.get("p90_ms"), e.get("slowest_ms"), e.get("hz")))
            else:
                print("{} {} strokes ({} frames), p50 {} ms, p90 {} ms, slowest {} ms".format(
                    where, e.get("count"), e.get("frames"), e.get("p50_ms"), e.get("p90_ms"), e.get("slowest_ms")))
if rows == 0:
    print("pen-latency: no board_pen_latency lines yet (write a few lines with the Pencil on a build with story 1311)")
PY
