#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$PROJECT_DIR/measurement/test-fixtures"
OUTPUT="$(mktemp -d)"
trap 'rm -rf "$OUTPUT"' EXIT

python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  --scaphandre "$FIXTURES/scaphandre.json" \
  --phpspy "$FIXTURES/phpspy.txt" \
  --window "$FIXTURES/window.json" \
  --k6 "$FIXTURES/k6-summary.json" \
  --carbon-intensity 100 \
  --output-dir "$OUTPUT" >/dev/null

python3 - "$OUTPUT/summary.json" <<'PY'
import json
import math
import sys

summary = json.load(open(sys.argv[1], encoding="utf-8"))
assert math.isclose(summary["energy"]["host_total_j"], 22.0, rel_tol=1e-9)
assert math.isclose(summary["energy"]["php_process_total_j"], 6.0, rel_tol=1e-9)
assert summary["profiling"]["phpspy_samples_in_file"] == 4
assert len(summary["function_times"]) > 0
first_fn = summary["function_times"][0]
assert "function" in first_fn
assert "total_time_s" in first_fn
assert "avg_time_ms" in first_fn
print("Analyzer self-test passed.")
PY
