#!/usr/bin/env python3
"""Compare two Hyprveil JSONL benchmark captures with explicit budgets."""

import json
import pathlib
import sys


def load(path):
    rows = {}
    for line in pathlib.Path(path).read_text().splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if "scenario" in row and "status" not in row:
            rows[row["scenario"]] = row
    return rows


if len(sys.argv) != 3:
    raise SystemExit("usage: compare-bench.py BASELINE.jsonl CANDIDATE.jsonl")

baseline, candidate = map(load, sys.argv[1:])
if not baseline or not candidate:
    raise SystemExit("both captures need numeric scenario rows from the same environment")

missing = sorted(set(baseline) - set(candidate))
if missing:
    raise SystemExit("candidate is missing scenarios: " + ", ".join(missing))

failures = []
for scenario, before in baseline.items():
    after = candidate[scenario]
    for metric in ("pss_kb", "uss_kb", "rss_kb"):
        if metric in before and metric in after:
            limit = before[metric] * 1.15
            if after[metric] > limit:
                failures.append(f"{scenario} {metric}: {after[metric]} > {limit:.0f}")
    if "cpu_pct" in before and "cpu_pct" in after:
        limit = max(before["cpu_pct"] * 1.20, before["cpu_pct"] + 0.5)
        if after["cpu_pct"] > limit:
            failures.append(f"{scenario} cpu_pct: {after['cpu_pct']} > {limit:.1f}")
    if "mean_ms" in before and "mean_ms" in after:
        limit = max(before["mean_ms"] * 1.15, before["mean_ms"] + 5)
        if after["mean_ms"] > limit:
            failures.append(f"{scenario} mean_ms: {after['mean_ms']} > {limit:.0f}")

if failures:
    raise SystemExit("performance regression:\n" + "\n".join(failures))
print(f"OK: {len(baseline)} benchmark scenarios remain within CPU, memory, and latency budgets")
