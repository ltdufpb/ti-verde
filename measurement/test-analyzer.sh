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
assert math.isclose(summary["energy"]["process_total_j"], 6.0, rel_tol=1e-9)
assert summary["profiling"]["samples_in_file"] == 4
assert len(summary["function_times"]) > 0
first_fn = summary["function_times"][0]
assert "function" in first_fn
assert "total_time_s" in first_fn
assert "avg_time_ms" in first_fn
print("Analyzer with k6 summary (phpspy) test passed.")
PY

# Test without --k6 summary
OUTPUT_NO_K6="$(mktemp -d)"
trap 'rm -rf "$OUTPUT" "$OUTPUT_NO_K6"' EXIT

python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  --scaphandre "$FIXTURES/scaphandre.json" \
  --phpspy "$FIXTURES/phpspy.txt" \
  --window "$FIXTURES/window.json" \
  --carbon-intensity 100 \
  --output-dir "$OUTPUT_NO_K6" >/dev/null

python3 - "$OUTPUT_NO_K6/summary.json" <<'PY'
import json
import math
import sys

summary = json.load(open(sys.argv[1], encoding="utf-8"))
assert math.isclose(summary["energy"]["host_total_j"], 22.0, rel_tol=1e-9)
assert math.isclose(summary["energy"]["process_total_j"], 6.0, rel_tol=1e-9)
assert summary["profiling"]["samples_in_file"] == 4
print("Analyzer without k6 summary (phpspy) test passed.")
PY

# Test with pyspy
OUTPUT_PYSPY="$(mktemp -d)"
trap 'rm -rf "$OUTPUT" "$OUTPUT_NO_K6" "$OUTPUT_PYSPY"' EXIT

python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  --scaphandre "$FIXTURES/scaphandre.json" \
  --pyspy "$FIXTURES/pyspy.chrometrace.json" \
  --start-time 1000.0 \
  --pyspy-rate 100.0 \
  --window "$FIXTURES/window.json" \
  --k6 "$FIXTURES/k6-summary.json" \
  --carbon-intensity 100 \
  --output-dir "$OUTPUT_PYSPY" >/dev/null

python3 - "$OUTPUT_PYSPY/summary.json" <<'PY'
import json
import math
import sys

summary = json.load(open(sys.argv[1], encoding="utf-8"))
assert math.isclose(summary["energy"]["host_total_j"], 22.0, rel_tol=1e-9)
assert math.isclose(summary["energy"]["process_total_j"], 6.0, rel_tol=1e-9)
assert summary["profiling"]["samples_in_file"] == 180
assert len(summary["function_times"]) > 0
print("Analyzer with k6 summary (pyspy) test passed.")
PY

