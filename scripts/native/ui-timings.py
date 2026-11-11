#!/usr/bin/env python3
"""Where a UI test run's time went, from its xcodebuild log (Igor, 2026-11-10: "detailed logging so we can speed
them up").

Usage: ui-timings.py <xcodebuild log> [--run <name>] [--jsonl <file>] [--top N]

For every test case: its total, the launch (from the start until the app is up and idle, the first step that is not
setting the app up), the steps XCUITest retried, the attachments taken, and the slow gaps (a second or more between
two activity lines, named by the line that ended them). Prints the slowest cases, the per-class totals and the
largest gap kinds; with --jsonl appends one line per case so runs can be compared over time.
"""

import argparse
import json
import re
import sys
import time
from collections import defaultdict

CASE = re.compile(r"Test Case '-\[(\w+)\.(\w+) (\w+)\]' (started|passed|failed|skipped)(?: \(([\d.]+) seconds\))?")
STEP = re.compile(r"^\s+t =\s+([\d.]+)s\s+(.*)$")
# The activity lines that bring the app up, before the test's own first step.
LAUNCH = re.compile(
    r"(?:Start Test|Set Up|Launch |Setting up automation|Wait for .* to idle|Terminate |Open |Find the Target Application)"
)
GAP_S = 1.0


def kind(line):
    """A gap's name: the activity with its quoted element and numbers taken out, so like gaps add up."""
    line = re.sub(r"`[^`]*`|\"[^\"]*\"|'[^']*'", "…", line.strip())
    line = re.sub(r"\(attempt #\d+\)|\d+(\.\d+)?", "", line)
    return re.sub(r"\s+", " ", line).strip()[:70]


def parse(lines):
    cases, current, seen = [], None, set()
    for line in lines:
        m = CASE.search(line)
        if m:
            _, cls, test, state, secs = m.groups()
            if state == "started":
                current = {"class": cls, "test": test, "steps": [], "secs": None, "state": None}
            elif current and current["test"] == test:
                current["state"], current["secs"] = state, float(secs or 0)
                current["retry"] = (cls, test) in seen
                seen.add((cls, test))
                cases.append(current)
                current = None
            continue
        s = STEP.match(line)
        if s and current is not None:
            current["steps"].append((float(s.group(1)), s.group(2)))
    return [summarise(c) for c in cases]


def summarise(case):
    steps = case.pop("steps")
    launch = 0.0
    for t, text in steps:
        if not LAUNCH.match(text):
            launch = t
            break
    gaps = defaultdict(float)
    for (t0, _), (t1, text) in zip(steps, steps[1:]):
        if t1 - t0 >= GAP_S:
            gaps[kind(text)] += t1 - t0
    case.update(
        launch_s=round(launch, 2),
        retries=sum("Retrying" in text for _, text in steps),
        attachments=sum("Added attachment" in text for _, text in steps),
        slow_gaps_s=round(sum(gaps.values()), 2),
        gaps={k: round(v, 2) for k, v in sorted(gaps.items(), key=lambda kv: -kv[1])},
    )
    return case


def report(cases, top):
    if not cases:
        return "ui timings: no test cases in the log"
    total = sum(c["secs"] for c in cases)
    launch = sum(c["launch_s"] for c in cases)
    distinct = {(c["class"], c["test"]) for c in cases}
    out = [
        f"ui timings: {len(distinct)} cases, {total:.0f} s in tests; launching the app {launch:.0f} s"
        f" ({100 * launch / total if total else 0:.0f}%), {sum(c['retries'] for c in cases)} retried steps,"
        f" {sum(c['attachments'] for c in cases)} attachments"
    ]
    # A case that failed and then passed on xcodebuild's retry: named, so a flake is never hidden by the retry.
    failed = {(c["class"], c["test"]) for c in cases if c["state"] == "failed"}
    passed = {(c["class"], c["test"]) for c in cases if c["state"] == "passed"}
    flaky = sorted(failed & passed)
    if flaky:
        out.append(f"  passed only on retry ({len(flaky)}): " + ", ".join(f"{k}.{t}" for k, t in flaky))
    per_class = defaultdict(lambda: [0, 0.0, 0.0])
    for c in cases:
        p = per_class[c["class"]]
        p[0] += not c["retry"]
        p[1] += c["secs"]
        p[2] += c["launch_s"]
    out.append("  by class (cases, seconds, of which launch):")
    for cls, (n, secs, lch) in sorted(per_class.items(), key=lambda kv: -kv[1][1]):
        out.append(f"    {secs:6.1f} s  {n:2d}  launch {lch:5.1f} s  {cls}")
    out.append(f"  slowest {min(top, len(cases))}:")
    for c in sorted(cases, key=lambda c: -c["secs"])[:top]:
        out.append(
            f"    {c['secs']:6.1f} s  launch {c['launch_s']:4.1f}  retries {c['retries']}  {c['class']}.{c['test']}"
            + ("" if c["state"] == "passed" else f"  [{c['state']}]")
        )
    gaps = defaultdict(float)
    for c in cases:
        for k, v in c["gaps"].items():
            gaps[k] += v
    out.append("  where the gaps of a second or more went:")
    for k, v in sorted(gaps.items(), key=lambda kv: -kv[1])[:8]:
        out.append(f"    {v:6.1f} s  {k}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("log")
    ap.add_argument("--run", default="", help="the run's name, kept on each JSON line")
    ap.add_argument("--jsonl", help="append one JSON line per case to this file")
    ap.add_argument("--top", type=int, default=8)
    args = ap.parse_args(argv)
    with open(args.log, errors="replace") as f:
        cases = parse(f)
    print(report(cases, args.top))
    if args.jsonl and cases:
        stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        with open(args.jsonl, "a") as f:
            for c in cases:
                f.write(json.dumps({"t": stamp, "run": args.run, **c}) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
