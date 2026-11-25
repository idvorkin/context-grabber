#!/usr/bin/env bash
# Story 1311 (context-grabber-7xv6): pen-latency.sh prints each board_pen_latency line from fake pulled logs, oldest
# session first, and says so when there are none. Story 1324: each line names its surface (board, native, web).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d "${TMPDIR:-/tmp}/cg-pen-latency.XXXXXX")
trap 'rm -rf "$dir"' EXIT
fail=0
out=$dir/out
ok() { echo "ok   pen latency: $1"; }
bad() { echo "FAIL pen latency: $1"; sed 's/^/     /' "$out"; fail=1; }
has() { if grep -qF -- "$2" "$out"; then ok "$1"; else echo "     wanted: $2"; bad "$1"; fi; }

mkdir -p "$dir/logs/ipad/logs"
"$here/pen-latency.sh" "$dir/logs" >"$out" 2>&1
has "no lines yet is said" "no board_pen_latency lines yet"

printf '%s\n' '{"t":10,"type":"whiteboard","action":"paper_touch"}' \
  '{"t":20,"type":"whiteboard","action":"board_pen_latency","count":200,"p50_ms":14.2,"p90_ms":19.8,"slowest_ms":31,"hz":120}' \
  >"$dir/logs/ipad/logs/grabber-20261124-101500.jsonl"
printf '%s\n' '{"t":5,"type":"whiteboard","action":"board_pen_latency","count":24,"p50_ms":12,"p90_ms":16.6,"slowest_ms":18,"hz":120}' \
  >"$dir/logs/ipad/logs/grabber-20261124-090000.jsonl"
"$here/pen-latency.sh" "$dir/logs" >"$out" 2>&1
has "a board line names its surface" "ipad grabber-20261124-101500.jsonl: board: 200 moments, p50 14.2 ms, p90 19.8 ms, slowest 31 ms, 120 Hz"
printf '%s\n' '{"t":30,"type":"ink_side_by_side","action":"board_pen_latency","surface":"native","measures":"oldest_undrawn_touch_to_frame","count":9,"frames":120,"p50_ms":8.3,"p90_ms":9,"slowest_ms":17}' \
  '{"t":31,"type":"ink_side_by_side","action":"board_pen_latency","surface":"web","measures":"oldest_undrawn_touch_to_frame","count":8,"frames":96,"p50_ms":16.7,"p90_ms":18,"slowest_ms":33.4}' \
  >"$dir/logs/ipad/logs/grabber-20261124-213000.jsonl"
"$here/pen-latency.sh" "$dir/logs" >"$out" 2>&1
has "the side-by-side native line" "ipad grabber-20261124-213000.jsonl: native: 9 strokes (120 frames), p50 8.3 ms, p90 9 ms, slowest 17 ms"
has "the side-by-side web line" "ipad grabber-20261124-213000.jsonl: web: 8 strokes (96 frames), p50 16.7 ms, p90 18 ms, slowest 33.4 ms"
if [ "$(grep -c -E 'moments|strokes' "$out")" -eq 4 ] && head -1 "$out" | grep -q 090000; then ok "oldest session first, other events skipped"; else bad "oldest session first, other events skipped"; fi

"$here/pen-latency.sh" "$dir/none" >"$out" 2>&1 && bad "a missing folder fails" || ok "a missing folder fails"
exit $fail
