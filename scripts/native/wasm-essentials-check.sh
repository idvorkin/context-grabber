#!/usr/bin/env bash
# The board wasm builds on FoundationEssentials alone (bead context-grabber-pt1e), which has none of Foundation's
# Objective-C bridge types. A type like NSNumber compiles on the Mac and breaks only the wasm build on Larry's VM
# (2026-11-24, bw_store_clash). This fails on any such type in the wasm's own sources, so the Mac catches it first.
# Usage: wasm-essentials-check.sh [dir ...]   (default: native/ContextCore/Sources/BoardWasm)
set -uo pipefail
cd "$(dirname "$0")/../.."
dirs=("$@")
[ ${#dirs[@]} -gt 0 ] || dirs=(native/ContextCore/Sources/BoardWasm)
pattern='\b(NSNumber|NSString|NSDictionary|NSArray|NSMutable[A-Za-z]+|NSRegularExpression|NumberFormatter|DateFormatter|NSCharacterSet)\b'
hits=$(grep -rnE "$pattern" "${dirs[@]}" --include='*.swift' | grep -vE '^[^:]+:[0-9]+:\s*//')
if [ -n "$hits" ]; then
  echo "FAIL wasm-essentials: Foundation-only types the wasm can't build (FoundationEssentials has none of them;"
  echo "     read JSON numbers with BoardCore's JSONNumber):"
  echo "$hits" | sed 's/^/     /'
  exit 1
fi
echo "ok   wasm-essentials: no Foundation-only types in ${dirs[*]}"
