#!/usr/bin/env bash
# Host test for wasm-essentials-check.sh: passes on the real wasm sources, fails naming the file and line on an
# NSNumber, and ignores one in a comment.
set -uo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-wasm-ess.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }
scripts/native/wasm-essentials-check.sh >"$tmp/out" 2>&1
check $? "the board wasm's sources have no Foundation-only types"
printf 'let n = (x as? NSNumber)?.intValue\n' >"$tmp/Bad.swift"
out=$(scripts/native/wasm-essentials-check.sh "$tmp" 2>&1); st=$?
[ $st -ne 0 ] && grep -q "Bad.swift:1:" <<<"$out"; check $? "an NSNumber fails, naming the file and line"
printf '// NSNumber is not here\nlet n = JSONNumber(x)?.intValue\n' >"$tmp/Bad.swift"
scripts/native/wasm-essentials-check.sh "$tmp" >/dev/null 2>&1
check $? "a mention in a comment passes"
exit $fail
