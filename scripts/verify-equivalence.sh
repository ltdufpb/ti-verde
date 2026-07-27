#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

slow_cpu="$(curl -fsS "${BASE_URL}/work?workload=cpu&implementation=slow&scale=1")"
fast_cpu="$(curl -fsS "${BASE_URL}/work?workload=cpu&implementation=fast&scale=1")"

slow_text="$(curl -fsS "${BASE_URL}/work?workload=text&implementation=slow&scale=1")"
fast_text="$(curl -fsS "${BASE_URL}/work?workload=text&implementation=fast&scale=1")"

python3 - "$slow_cpu" "$fast_cpu" "$slow_text" "$fast_text" <<'PY'
import json
import sys

slow_cpu, fast_cpu, slow_text, fast_text = map(json.loads, sys.argv[1:])

assert slow_cpu["result"]["checksum"] == fast_cpu["result"]["checksum"]
assert slow_cpu["result"]["prime_count"] == fast_cpu["result"]["prime_count"]
assert slow_text["result"]["checksum"] == fast_text["result"]["checksum"]

print("Verification passed: slow and fast versions return equivalent results.")
print(f'CPU slow: {slow_cpu["duration_ms"]} ms')
print(f'CPU fast: {fast_cpu["duration_ms"]} ms')
print(f'Text slow: {slow_text["duration_ms"]} ms')
print(f'Text fast: {fast_text["duration_ms"]} ms')
PY
