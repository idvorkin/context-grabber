#!/usr/bin/env bash
# The Linux rung (context-grabber-bf1): what a Linux box can say about ContextCore without a Mac.
#   1. ContextCore's XCTests, built and run on Linux. Units that need an Apple framework (ImageIO, NSItemProvider,
#      CoreText, JavaScriptCore, PencilKit) are left out by `#if canImport`, and so are their tests; link finding, upload
#      types and the affine transform have Linux stand-ins, so theirs run here too (docs/TESTING.md, Off the Mac).
#   2. ContextCore and its tests cross-built with a Darwin Swift SDK (xtool's) for macOS, iOS and the iOS simulator:
#      Mach-O compiled, never executed. Skipped, and said so, when no `darwin` SDK is installed.
#   3. The app's own sources compiled for iOS with the same SDK: App and Shared, the widgets, the share extension and
#      the UI tests, against the BugKit and ThinkACard pins in native/project.yml (a generated SwiftPM package in the
#      build directory; resolving it needs the network). Compiled, never linked into a bundle or run. Skipped, and said
#      so, without the SDK or when the packages can't be fetched.
#   4. The host rung's script checks that need no Mac (the list in step 4 below; docs/TESTING.md names each).
# None of it covers Xcode itself (the project, asset catalogs, signing), Catalyst-only code or anything at runtime on
# Apple: the Mac's `just native-test` and the simulator do.
#
# Environment (all optional):
#   LINUX_SWIFT_BIN  the Swift toolchain's bin directory, when `swift` on PATH is not the one to use
#   LINUX_LIB_DIR    extra libraries for the toolchain and the link (LD_LIBRARY_PATH and -L), e.g. an ICU it needs
#   SQLITE_INCLUDE   a directory holding sqlite3.h, when libsqlite3-dev is not installed
#   CG_LINUX_BUILD   a build directory to keep between runs (default: a temporary one, removed afterwards)
#   JOBS             build jobs (default 3)
set -uo pipefail
# A kept build directory is the caller's: created if missing, and a relative one is taken from where they ran it (#904).
if [ -n "${CG_LINUX_BUILD:-}" ]; then
  mkdir -p "$CG_LINUX_BUILD" && CG_LINUX_BUILD=$(cd "$CG_LINUX_BUILD" && pwd) ||
    { echo "CG_LINUX_BUILD=$CG_LINUX_BUILD: cannot create that build directory" >&2; exit 2; }
fi
cd "$(dirname "$0")/../../native/ContextCore"
[ "$(uname -s)" = Linux ] || { echo "test-linux is the Linux rung; on a Mac run just native-test" >&2; exit 2; }
[ -n "${LINUX_SWIFT_BIN:-}" ] && export PATH="$LINUX_SWIFT_BIN:$PATH"
command -v swift >/dev/null || { echo "no swift on PATH (set LINUX_SWIFT_BIN)" >&2; exit 2; }
flags=()
if [ -n "${LINUX_LIB_DIR:-}" ]; then
  export LD_LIBRARY_PATH="$LINUX_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  flags+=(-Xlinker "-L$LINUX_LIB_DIR")
fi
[ -n "${SQLITE_INCLUDE:-}" ] && flags+=(-Xcc "-I$SQLITE_INCLUDE")
# CSQLite finds SQLite through pkg-config (#943); SQLITE_INCLUDE stays for a box without its .pc file.
if [ -z "${SQLITE_INCLUDE:-}" ] && ! pkg-config --exists sqlite3 2>/dev/null && [ ! -e /usr/include/sqlite3.h ]; then
  echo "no sqlite3: apt install libsqlite3-dev pkg-config, or set SQLITE_INCLUDE" >&2
  exit 2
fi
build=${CG_LINUX_BUILD:-}
if [ -z "$build" ]; then
  build=$(mktemp -d "${TMPDIR:-/tmp}/cg-test-linux.XXXXXX")
  trap 'rm -rf "$build"' EXIT
fi
jobs=${JOBS:-3}
low() { nice -n 19 ionice -c 3 "$@"; }
fail=0

echo "== $(swift --version 2>&1 | head -1)"
echo "== Linux: swift test ($(uname -m))"
log=$build/linux-test.log
low swift test -j "$jobs" --scratch-path "$build/linux" ${flags[@]+"${flags[@]}"} >"$log" 2>&1
status=$?
grep -E "error:|Fatal error" "$log" | head -20
summary=$(grep -E "Executed [0-9]+ tests" "$log" | tail -1 | sed 's/^[[:space:]]*//')
if [ $status -ne 0 ] || [ -z "$summary" ]; then
  echo "FAIL Linux swift test (exit $status; log: $log)"
  fail=1
else
  echo "ok   $summary"
fi

# The board-ops harness (#943): Larry runs it on this kind of box, where it writes SVGs. Built and run on a fixture.
echo "== Linux: board-ops harness"
log=$build/board-ops.log
fixtures=Tests/ContextCoreTests/Fixtures/board-ops
if low swift run -j "$jobs" --scratch-path "$build/linux" ${flags[@]+"${flags[@]}"} board-ops-harness \
  --board "$fixtures/judge-board.json" --ops "$fixtures/judge-ops.json" --out "$build/board-ops/judge" >"$log" 2>&1 \
  && grep -q '<svg' "$build/board-ops/judge.svg" && grep -Eq '"action" ?: ?"applied"' "$build/board-ops/judge.result.json"; then
  echo "ok   board-ops harness: the Judge batch replayed, $build/board-ops/judge.svg written"
else
  grep -E "error:" "$log" | head -20
  echo "FAIL board-ops harness (log: $log)"
  fail=1
fi

if swift sdk list 2>/dev/null | grep -qx darwin; then
  for triple in arm64-apple-macosx arm64-apple-ios arm64-apple-ios-simulator; do
    sdk=$(swift sdk configure --show-configuration darwin "$triple" 2>/dev/null | sed -n 's/^sdkRootPath: //p')
    log=$build/$triple.log
    if low swift build --build-tests --build-system native --swift-sdk darwin --triple "$triple" -j "$jobs" \
      --scratch-path "$build/$triple" >"$log" 2>&1; then
      echo "ok   cross-build $triple: ContextCore + tests compiled, not run (SDK $(basename "${sdk:-?}"))"
    else
      grep -E "error:" "$log" | head -20
      echo "FAIL cross-build $triple (log: $log)"
      fail=1
    fi
  done
else
  echo "SKIP cross-build: no darwin Swift SDK (xtool sdk install)"
fi
# 3. The app's sources for iOS. Each Xcode target becomes a SwiftPM target over symlinks to its folders, with the
# project's package pins; a failure here is a compile error the Mac's build would also hit.
pin() {  # <package name in project.yml> <url|exactVersion>
  awk -v p="  $1:" -v k="$2" '$0 == p {f = 1; next} f && /^  [^ ]/ {f = 0} f && $1 == k":" {print $2; exit}' \
    ../project.yml
}
if swift sdk list 2>/dev/null | grep -qx darwin; then
  app=$build/app
  mkdir -p "$app/App" "$app/Widgets" "$app/Share" "$app/UITests"
  native=$(cd .. && pwd)
  ln -sfn "$native/App" "$app/App/App"
  ln -sfn "$native/Shared" "$app/App/Shared"
  ln -sfn "$native/Widgets" "$app/Widgets/Widgets"
  ln -sfn "$native/Shared" "$app/Widgets/Shared"
  ln -sfn "$native/Share" "$app/Share/Share"
  ln -sfn "$native/UITests" "$app/UITests/UITests"
  cat >"$app/Package.swift" <<PKG
// swift-tools-version: 6.0
// Generated by scripts/native/test-linux.sh: the app's targets, compiled for iOS off the Mac.
import PackageDescription
let package = Package(
  name: "GrabberNativeLinuxCompile",
  platforms: [.iOS("$(sed -n 's/^    iOS: "\(.*\)"/\1/p' ../project.yml)")],
  dependencies: [
    .package(path: "$native/ContextCore"),
    .package(url: "$(pin BugKit url)", exact: "$(pin BugKit exactVersion)"),
    .package(url: "$(pin ThinkACard url)", exact: "$(pin ThinkACard exactVersion)"),
  ],
  targets: [
    .target(
      name: "GrabberNative",
      dependencies: [
        "ContextCore", .product(name: "BugKit", package: "bug-kit"),
        .product(name: "ThinkACardCore", package: "think-a-card-trainer"),
        .product(name: "ThinkACardUI", package: "think-a-card-trainer"),
      ], path: "App", exclude: ["App/Assets.xcassets"]),
    .target(
      name: "GrabberWidgets",
      dependencies: [
        "ContextCore", .product(name: "ThinkACardCore", package: "think-a-card-trainer"),
        .product(name: "ThinkACardUI", package: "think-a-card-trainer"),
      ], path: "Widgets", exclude: ["Widgets/Info.plist"]),
    .target(
      name: "GrabberShare", dependencies: ["ContextCore", .product(name: "BugKit", package: "bug-kit")],
      path: "Share", exclude: ["Share/Info.plist"]),
    .testTarget(name: "GrabberNativeUITests", path: "UITests"),
  ],
  swiftLanguageModes: [.v5]
)
PKG
  log=$build/app.log
  if ! (cd "$app" && low swift package resolve >"$log" 2>&1); then
    tail -3 "$log"
    echo "SKIP app compile for iOS: its packages could not be fetched (log: $log)"
  elif (cd "$app" && low swift build --build-tests --build-system native --swift-sdk darwin --triple arm64-apple-ios \
    -j "$jobs" >>"$log" 2>&1); then
    echo "ok   app compile arm64-apple-ios: App, widgets, share extension and UI tests compiled, not linked or run"
  else
    grep -E "error:" "$log" | sort -u | head -20
    echo "FAIL app compile arm64-apple-ios (log: $log)"
    fail=1
  fi
else
  echo "SKIP app compile for iOS: no darwin Swift SDK (xtool sdk install)"
fi

# 4. The host rung's script checks that run anywhere (the rest need the Mac: actool, BugKit's signing guard).
cd ../..
for check in scripts/native/test-ladder-map.sh scripts/native/test-breath-clips.py scripts/native/test-ui-timings.sh scripts/native/test-ladder-report.sh \
  scripts/native/test-smoke-lock.sh scripts/native/test-linux-imports.sh scripts/native/test-build-lane.sh \
  scripts/native/test-lease-slot.sh scripts/native/test-story-ids.sh scripts/native/test-story-commits.sh scripts/native/test-story-tests.sh scripts/native/test-board-sessions.py scripts/native/test-testing-lists.sh \
  scripts/native/test-mic-tests.sh; do
  log=$build/$(basename "$check").log
  if "$check" >"$log" 2>&1; then
    echo "ok   $check"
  else
    grep -E "^FAIL|not ok|Error" "$log" | head -10
    echo "FAIL $check (log: $log)"
    fail=1
  fi
done

# A failure keeps its logs, even in the temporary directory.
if [ $fail -ne 0 ] && [ -z "${CG_LINUX_BUILD:-}" ]; then
  trap - EXIT
  echo "logs kept in $build"
fi
exit $fail
