#!/usr/bin/env python3
"""Story 1628: the Mac's store walk (the walk-the-store skill's `just walk` contract for this repo).

Runs every rung this Mac climbs once, never story by story: ContextCore's host tests, the lint, each script check the
stories name, the Mac build, and the simulator rung with every UI test class (the ladder's --all, kept going past a red
class). Then writes OUT/checks.json and asks the skill's walk.py to judge every story against it.

What only another machine can run is written `skip` with its reason, never left for judge to call missing: the wasm,
the Linux rung and the board-ops replay belong to the Linux VM; installs, uploads and bug filing are not checks.
A ref naming a class, test, recipe or script that is nowhere in the tree is written `missing`: its proof is gone.

  scripts/native/walk.py [OUT] [--skip-sim] [--skip-host] [--judge-only]
Exit 0 no new red, 1 new red, 2 the walk could not run. WALK_PY is the skill's walk.py.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WALK_PY = Path(os.environ.get("WALK_PY", Path.home() / ".claude/skills/walk-the-store/walk.py"))
WALKS = Path.home() / "tmp/agent/walks/context-grabber"
STORIES = ROOT / "docs/stories"
MANIFEST = STORIES / "walk.toml"
LOGS = ROOT / "native/Build/logs"
# macOS XCTest: Test Case '-[ContextCoreTests.FooTests testBar]' passed (0.001 seconds).
CASE = re.compile(r"^Test Case '-\[(?:\w+\.)?(\w+) (\w+)\]' (passed|failed|skipped)")
CLASS_DEF = re.compile(r"^\s*(?:final\s+|@MainActor\s+|public\s+|private\s+)*(?:class|struct)\s+(\w+Tests)\b", re.M)
FUNC_DEF = re.compile(r"func\s+(test\w+)\s*\(")
TEST_DIRS = ["native/ContextCore/Tests", "native/UITests", "native/ContractTests", "native/BoardLab"]

# Recipes the stories name that this Mac doesn't run as a check, and why.
ELSEWHERE = {
    "wasm-test": "the Linux VM builds and tests all wasm (AGENTS.md)",
    "test-linux": "the Linux rung runs on the Linux VM",
    "board-ops": "a replay tool, run on the Linux VM's walk",
    "touch-fixture": "a tool that writes a fixture from a pulled log, not a check",
    "ota": "an upload to the Cockpit's builds page, not a check",
    "deploy": "an install on Igor's devices: needs his own go-ahead, never part of a walk",
    "testflight": "an upload to TestFlight, not a check",
    "bugs-check": "reads the plugged-in devices' reports, not a check",
    "file-bugs": "files reports as issues, not a check",
    "bugs-monitor": "a listener, not a check",
    "check-deal": "a tool run by hand",
    "--list": "just's own listing, not a check",
}
OUTCOME = {"passed": "pass", "failed": "fail", "skipped": "skip"}
# Script checks that are simulator suites: their classes run once in the simulator rung, and the script reads as that
# step's result rather than a second run of every class.
SIM_SUITES = {"test-whiteboard-ui.sh": "whiteboard classes", "test-chat-ui.sh": "chat classes"}


def sh(argv, log: Path, timeout: int, cwd=ROOT, env=None) -> int:
    """One capped stage; past its cap the whole process group is killed and it reads as 124."""
    print("+", " ".join(map(str, argv)), flush=True)
    with log.open("w") as fh:
        p = subprocess.Popen(list(map(str, argv)), cwd=cwd, stdout=fh, stderr=subprocess.STDOUT,
                             env={**os.environ, **(env or {})}, start_new_session=True)
        try:
            rc = p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, 9)
            p.wait()
            fh.write(f"\nWALK: stage killed after {timeout}s\n")
            rc = 124
    print(f"  exit {rc} -> {log}", flush=True)
    return rc


def refs(kind: str) -> list[str]:
    argv = [sys.executable, str(WALK_PY), "refs", str(STORIES), "--kind", kind]
    if MANIFEST.exists():
        argv += ["--manifest", str(MANIFEST)]
    return subprocess.run(argv, capture_output=True, text=True, check=True).stdout.split()


def cases(log: Path) -> dict[str, dict]:
    """`Class.test` -> {outcome, detail}. A case that failed and then passed (the wrapper's one retry) is flaky."""
    seen: dict[str, list[str]] = {}
    details: dict[str, str] = {}
    if not log.exists():
        return {}
    lines = log.read_text(errors="replace").splitlines()
    for i, line in enumerate(lines):
        m = CASE.match(line)
        if not m:
            continue
        cls, test, verdict = m.groups()
        key = f"{cls}.{test}"
        seen.setdefault(key, []).append(OUTCOME[verdict])
        if verdict == "failed":
            details[key] = " | ".join(l.strip() for l in lines[max(0, i - 4):i] if "error" in l.lower())[:300]
    out = {}
    for key, runs in seen.items():
        if "fail" in runs and runs[-1] == "pass":
            out[key] = {"outcome": "flaky", "detail": "failed, then passed its retry"}
        elif "fail" in runs:
            out[key] = {"outcome": "fail", "detail": details.get(key, "")}
        else:
            out[key] = {"outcome": runs[-1], "detail": ""}
    return out


def source_index() -> dict[str, dict]:
    """Class name (or test target) -> {methods, files}."""
    idx: dict[str, dict] = {}
    for d in TEST_DIRS:
        for f in (ROOT / d).rglob("*.swift"):
            src = f.read_text(errors="replace")
            classes = CLASS_DEF.findall(src)
            if f.stem.endswith("Tests") and f.stem not in classes:
                classes.append(f.stem)
            target = next((p for p in f.relative_to(ROOT / d).parts[:-1] if p.endswith("Tests")), None)
            for c in classes + ([target] if target and target not in classes else []):
                e = idx.setdefault(c, {"methods": set(), "files": [], "members": set()})
                e["methods"] |= set(FUNC_DEF.findall(src))
                e["files"].append(str(f.relative_to(ROOT)))
                e["members"] |= set(classes)
    return idx


def xctest_checks(xrefs, results, idx, rung_rc, sha):
    """rung_rc: "host"/"sim" -> None (not run), 0 (ran), or the exit of a rung that failed before its cases ran."""
    checks = {f"xctest:{k}": v for k, v in results.items()}
    order = ["fail", "missing", "skip", "flaky", "pass"]
    for ref in xrefs:
        target = ref.split(":", 1)[1]
        cls, _, test = target.partition(".")
        if ref in checks:
            continue
        e = idx.get(cls)
        if e is None:
            checks[ref] = {"outcome": "missing", "detail": f"no class {cls} in the tree at {sha}"}
            continue
        if test:
            if test not in e["methods"]:
                checks[ref] = {"outcome": "missing", "detail": f"{cls} has no {test} at {sha}"}
            else:
                checks[ref] = {"outcome": "skip", "detail": f"{cls}.{test} is in the tree but did not run this walk"}
            continue
        rows = [v for k, v in results.items() if k.split(".", 1)[0] in (e["members"] | {cls})]
        if rows:
            # A class ref is the worst of its own cases, written out so judge's prefix match never folds in a stale
            # `Class.testGone` row another story cites.
            w = min(rows, key=lambda r: order.index(r["outcome"]))
            bad = sum(1 for r in rows if r["outcome"] == "fail")
            checks[ref] = {"outcome": w["outcome"],
                           "detail": f"{len(rows)} cases" + (f", {bad} failing: {w['detail']}" if bad else "")}
            continue
        sim_class = any(f.startswith(("native/UITests", "native/ContractTests", "native/BoardLab")) for f in e["files"])
        rung = "simulator" if sim_class else "host"
        code = rung_rc["sim" if sim_class else "host"]
        if code:
            checks[ref] = {"outcome": "fail", "detail": f"the {rung} rung failed (exit {code}) before {cls} ran"}
            continue
        why = ("did not run this walk (a mic test on a locked Mac is skipped by the wrapper)" if code == 0
               else f"the {rung} rung was not run this walk")
        checks[ref] = {"outcome": "skip", "detail": f"{cls}: {why}"}
    return checks


def script_checks() -> set[str]:
    """The script checks `just test` runs (native-test-host's scripts/native lines): the only scripts a walk runs."""
    names, inside = set(), False
    for line in (ROOT / "justfile").read_text().splitlines():
        if re.match(r"^[\w-]+\b[^#]*?:(?!=)", line):
            inside = line.startswith("native-test-host:")
        elif inside and (m := re.match(r"^\s+scripts/native/([\w.-]+)\s*$", line)):
            names.add(m.group(1))
    return names


def just_recipes() -> set[str]:
    names = set()
    for line in (ROOT / "justfile").read_text().splitlines():
        if not re.match(r"^[\w-]+\s*:=", line) and (m := re.match(r"^([\w-]+)\b[^#]*?:(?!=)", line)):
            names.add(m.group(1))
        if m := re.match(r"^alias\s+([\w-]+)\s*:=", line):
            names.add(m.group(1))
    return names | {"--list"}


def worst(*outcomes: dict) -> dict:
    order = ["fail", "missing", "skip", "flaky", "pass"]
    given = [o for o in outcomes if o]
    if not given:
        return {"outcome": "skip", "detail": "not run this walk"}
    return min(given, key=lambda o: order.index(o["outcome"]))


def rc_row(rc: int | None, what: str, log: Path | None = None) -> dict | None:
    if rc is None:
        return None
    if rc == 0:
        return {"outcome": "pass", "detail": what}
    return {"outcome": "fail", "detail": f"{what}: exit {rc}" + (f", see {log}" if log else "")}


def git_state() -> tuple[str, bool]:
    sha = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=no"],
                                capture_output=True, text=True).stdout.strip())
    return sha, dirty


def wait_for_other_full_runs(cap_s: int = 3 * 3600) -> None:
    """A walk is batch work: it waits for another full simulator run (a ladder --all) to finish before its own."""
    start = datetime.datetime.now().timestamp()
    while datetime.datetime.now().timestamp() - start < cap_s:
        ps = subprocess.run(["/bin/ps", "-Ao", "pid=,command="], capture_output=True, text=True).stdout.splitlines()
        others = [l for l in ps if "test-ladder.sh" in l and "--all" in l and str(os.getpid()) not in l.split()[0]]
        if not others:
            return
        print(f"walk: waiting for another full simulator run ({others[0].split()[0]})", flush=True)
        subprocess.run(["sleep", "60"])


def ladder_steps(log: Path) -> dict[str, bool]:
    """The simulator rung's step labels -> passed, from the ladder's own lines."""
    out: dict[str, bool] = {}
    for line in log.read_text(errors="replace").splitlines() if log.exists() else []:
        if m := re.match(r"^\s+rung 2 (.+?): failed \(exit \d+\)", line):
            out[m.group(1)] = False
        elif m := re.match(r"^\s+rung 2 (.+?): \d+ s$", line):
            out.setdefault(m.group(1), True)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out", nargs="?")
    ap.add_argument("--skip-sim", action="store_true")
    ap.add_argument("--skip-host", action="store_true")
    ap.add_argument("--judge-only", action="store_true", help="judge an OUT whose checks.json is already written")
    a = ap.parse_args()
    if not WALK_PY.exists():
        print(f"walk: no walk.py at {WALK_PY} (set WALK_PY to the walk-the-store skill's walk.py)", file=sys.stderr)
        return 2
    out = Path(a.out or WALKS / datetime.datetime.now().strftime("%Y-%m-%d-%H%M")).expanduser()
    (out / "logs").mkdir(parents=True, exist_ok=True)
    previous = WALKS / "latest" / "walk.json"
    if not a.judge_only:
        sha, dirty = git_state()
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        x, j, s = refs("xctest"), refs("just"), refs("script")
        others = refs("node") + refs("pytest") + refs("landmark")
        rc: dict[str, int | None] = {k: None for k in ("lint", "host", "mac", "sim")}
        host: dict[str, dict] = {}
        scripts: dict[str, dict] = {}
        if not a.skip_host:
            rc["lint"] = sh(["just", "native-lint-format", "native-lint"], out / "logs/lint.log", 900)
            rc["host"] = sh(["scripts/native/host-lane.sh", "run", "bash", "-c", "cd native/ContextCore && swift test"],
                            out / "logs/host.log", 3600)
            host = cases(out / "logs/host.log")
            for key in [k for k, v in host.items() if v["outcome"] == "fail"]:  # one serial retry of each red case
                cls, test = key.split(".")
                r = sh(["scripts/native/host-lane.sh", "run", "bash", "-c",
                        f"cd native/ContextCore && swift test --filter '{cls}/{test}'"],
                       out / f"logs/host-retry-{cls}.{test}.log", 900)
                if r == 0:
                    host[key] = {"outcome": "flaky", "detail": "failed in the full run, passed alone"}
            runnable = script_checks()
            for ref in s:
                base = ref.split(":", 1)[1]
                found = sorted(ROOT.joinpath("scripts").rglob(base))
                if not found:
                    scripts[ref] = {"outcome": "missing", "detail": f"no script {base} at {sha}"}
                    continue
                if base in SIM_SUITES:
                    continue  # a simulator suite: judged from the simulator rung's step below, not run twice
                if found[0].name not in runnable:
                    scripts[ref] = {"outcome": "skip", "detail": f"{base} is not a script check `just test` runs"}
                    continue
                f = found[0]
                runner = ["python3", str(f)] if f.suffix == ".py" else ["bash", str(f)]
                log = out / f"logs/script-{base}.log"
                r = sh(runner, log, 900)
                if r != 0 and sh(runner, out / f"logs/script-{base}.retry.log", 900) == 0:
                    scripts[ref] = {"outcome": "flaky", "detail": "failed, then passed a serial retry"}
                else:
                    scripts[ref] = rc_row(r, f"{f.relative_to(ROOT)}", log)
            rc["mac"] = sh(["just", "native-build-mac"], out / "logs/mac.log", 1800)
        else:
            scripts = {ref: {"outcome": "skip", "detail": "the host rung was not run this walk"} for ref in s
                       if ref.split(":", 1)[1] not in SIM_SUITES}
        sim: dict[str, dict] = {}
        steps: dict[str, bool] = {}
        if not a.skip_sim:
            wait_for_other_full_runs()
            rc["sim"] = sh(["scripts/native/test-ladder.sh", "--all", "--rung", "2"], out / "logs/sim.log", 4 * 3600,
                           env={"LADDER_KEEP_GOING": "1", "SIM": os.environ.get("SIM", "iPad Pro 11-inch (M5)")})
            steps = ladder_steps(out / "logs/sim.log")
            for log in sorted(LOGS.glob("ladder-*.log")):
                if log.stat().st_mtime >= datetime.datetime.fromisoformat(started).timestamp():
                    sim.update(cases(log))
        for ref in s:
            base = ref.split(":", 1)[1]
            if base in SIM_SUITES and ref not in scripts:
                label = SIM_SUITES[base]
                scripts[ref] = ({"outcome": "skip", "detail": "the simulator rung was not run this walk"} if not steps
                                else {"outcome": "pass" if steps.get(label, False) else "fail",
                                      "detail": f"the simulator rung's {label} step (the same classes)"})
        results = {**host, **sim}
        sim_rc = rc["sim"] if rc["sim"] and (not steps.get("compile", True) or not sim) else (rc["sim"] and 0)
        checks = xctest_checks(x, results, source_index(), {"host": rc["host"], "sim": sim_rc}, sha)
        checks.update(scripts)
        recipes = just_recipes()
        host_row = rc_row(rc["host"], "ContextCore's swift test")
        lint_row = rc_row(rc["lint"], "swift-format and SwiftLint")
        script_rows = [row for ref, row in scripts.items() if ref.split(":", 1)[1] not in SIM_SUITES]
        step_row = lambda label: (None if not steps or label not in steps else
                                  {"outcome": "pass" if steps[label] else "fail", "detail": f"the ladder's {label} step"})
        mapped = {
            "test": worst(lint_row, host_row, *script_rows),
            "native-test": worst(lint_row, host_row, *script_rows),
            "native-lint": lint_row,
            "native-build-mac": rc_row(rc["mac"], "the Mac build"),
            "native-build-sim": step_row("compile"),
            "native-test-sim": step_row("smoke"),
            "native-test-contracts": step_row("contract tests"),
            "test-ladder": rc_row(rc["sim"], "the simulator rung with every UI class"),
        }
        for ref in j:
            r = ref.split(":", 1)[1]
            if r not in recipes:
                checks[ref] = {"outcome": "missing", "detail": f"no just recipe {r} at {sha}"}
            elif r in ELSEWHERE:
                checks[ref] = {"outcome": "skip", "detail": ELSEWHERE[r]}
            else:
                checks[ref] = mapped.get(r) or {"outcome": "skip", "detail": f"just {r} is not run by the Mac walk"}
        for ref in others:
            checks[ref] = {"outcome": "skip", "detail": "a node, pytest or web check: the Linux VM's walk runs it"}
        run = {"repo": "context-grabber", "sha": sha, "dirty": dirty, "started": started,
               "finished": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "kinds": ["xctest", "just", "script", "node", "pytest", "landmark"], "checks": checks,
               "stages": {k: v for k, v in rc.items() if v is not None}}
        (out / "checks.json").write_text(json.dumps(run, indent=1))
        if rc["sim"] is not None and not steps.get("compile", True):
            print("walk: the simulator build failed, so every UI class it cites reads red", file=sys.stderr)
    argv = [sys.executable, str(WALK_PY), "judge", "--stories", str(STORIES), "--checks", str(out / "checks.json"),
            "--out", str(out)]
    if MANIFEST.exists():
        argv += ["--manifest", str(MANIFEST)]
    if previous.exists():
        argv += ["--previous", str(previous)]
    verdict = subprocess.run(argv).returncode
    if verdict in (0, 1):
        latest = WALKS / "latest"
        WALKS.mkdir(parents=True, exist_ok=True)
        if latest.is_symlink() or latest.exists():
            latest.unlink()
        latest.symlink_to(out)
    print(f"walk: {out}/report.md (exit {verdict})")
    return verdict


if __name__ == "__main__":
    sys.exit(main())
