#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-perf-compare.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

printf '%s\n' \
    '{"scenario":"idle","rss_kb":100000,"pss_kb":80000,"uss_kb":60000,"cpu_pct":1.0}' \
    '{"scenario":"launcher","rss_kb":110000,"pss_kb":88000,"uss_kb":65000,"cpu_pct":2.0,"mean_ms":45}' \
    > "$TMP/baseline.jsonl"
printf '%s\n' \
    '{"scenario":"idle","rss_kb":102000,"pss_kb":81000,"uss_kb":61000,"cpu_pct":1.1}' \
    '{"scenario":"launcher","rss_kb":112000,"pss_kb":90000,"uss_kb":66000,"cpu_pct":2.2,"mean_ms":47}' \
    > "$TMP/candidate.jsonl"

"$REPO/tests/compare-bench.py" "$TMP/baseline.jsonl" "$TMP/candidate.jsonl"
printf 'OK: benchmark comparator rejects regressions using deterministic fixtures\n'
