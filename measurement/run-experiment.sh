#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config/experiment.env}"
[[ -f "$CONFIG_FILE" ]] || {
  echo "Configuration file not found: $CONFIG_FILE" >&2
  exit 1
}

# shellcheck disable=SC1090
source "$CONFIG_FILE"

IMPLEMENTATION="${1:-slow}"
case "$IMPLEMENTATION" in
  slow|fast) ;;
  *)
    echo "Usage: $0 slow|fast" >&2
    exit 1
    ;;
esac

if [[ -n "${OUTPUT_DIR:-}" ]]; then
  RUN_DIR="$OUTPUT_DIR"
else
  RUN_DIR="$PROJECT_DIR/results/${IMPLEMENTATION}-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$RUN_DIR"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"

PHPSPY="$PROJECT_DIR/tools/phpspy/phpspy"
FLAMEGRAPH="$PROJECT_DIR/tools/FlameGraph/flamegraph.pl"
SCAPH_FILE="$RUN_DIR/scaphandre.json"
BASELINE_FILE="$RUN_DIR/scaphandre-baseline.json"
PHPSPY_FILE="$RUN_DIR/phpspy.txt"
PHPSPY_ERR="$RUN_DIR/phpspy.stderr.log"
K6_SUMMARY="$RUN_DIR/k6-summary.json"
WINDOW_FILE="$RUN_DIR/window.json"
SERVER_LOG="$RUN_DIR/php-server.log"

cp "$CONFIG_FILE" "$RUN_DIR/experiment.env"

for command in php curl python3 k6 scaphandre; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing command: $command" >&2
    exit 1
  }
done

[[ -x "$PHPSPY" ]] || {
  echo "phpspy not found. Run measurement/install-tools-ubuntu.sh." >&2
  exit 1
}

[[ -f "$FLAMEGRAPH" ]] || {
  echo "FlameGraph not found. Run measurement/install-tools-ubuntu.sh." >&2
  exit 1
}

sudo -v

SERVER_PID=""
SCAPH_PID=""
PHPSPY_PID=""

cleanup() {
  set +e
  [[ -n "$SCAPH_PID" ]] && sudo kill -INT "$SCAPH_PID" 2>/dev/null
  [[ -n "$PHPSPY_PID" ]] && sudo kill -INT "$PHPSPY_PID" 2>/dev/null
  [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

echo "Starting PHP application..."
php -S "${HOST}:${PORT}" -t "$PROJECT_DIR/public" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 50); do
  curl -fsS "${BASE_URL}/health" >/dev/null && break
  sleep 0.2
done

curl -fsS "${BASE_URL}/health" >/dev/null || {
  echo "PHP server failed. Check $SERVER_LOG" >&2
  exit 1
}

echo "PHP PID: $SERVER_PID"
echo "Run directory: $RUN_DIR"

# BASE_URL="$BASE_URL" "$PROJECT_DIR/scripts/verify-equivalence.sh"

echo "Warm-up: ${WARMUP_SECONDS}s..."
SUMMARY_PATH="$RUN_DIR/k6-warmup-summary.json" \
BASE_URL="$BASE_URL" \
WORKLOAD="$WORKLOAD" \
IMPLEMENTATION="$IMPLEMENTATION" \
SCALE="$SCALE" \
RATE="$RATE" \
DURATION_SECONDS="$WARMUP_SECONDS" \
k6 run --quiet "$PROJECT_DIR/k6.js"

sleep 3

echo "Idle baseline: ${BASELINE_SECONDS}s..."
sudo scaphandre json \
  -t "$BASELINE_SECONDS" \
  -s "$SCAPHANDRE_STEP_SECONDS" \
  --max-top-consumers "$SCAPHANDRE_MAX_PROCESSES" \
  --process-regex "$SCAPHANDRE_PROCESS_REGEX" \
  --resources \
  -f "$BASELINE_FILE"

COLLECTOR_TIMEOUT=$(
  python3 - <<PY
print(int(${COLLECTOR_LEAD_SECONDS}) + int(${DURATION_SECONDS}) + int(${COLLECTOR_TAIL_SECONDS}) + 8)
PY
)
COLLECTOR_TIMEOUT_MS=$((COLLECTOR_TIMEOUT * 1000))

echo "Starting Scaphandre..."
sudo scaphandre json \
  -t "$COLLECTOR_TIMEOUT" \
  -s "$SCAPHANDRE_STEP_SECONDS" \
  --max-top-consumers "$SCAPHANDRE_MAX_PROCESSES" \
  --process-regex "$SCAPHANDRE_PROCESS_REGEX" \
  --resources \
  -f "$SCAPH_FILE" &
SCAPH_PID=$!

echo "Starting phpspy..."
sudo "$PHPSPY" \
  -H "$PHPSPY_RATE_HZ" \
  -i "$COLLECTOR_TIMEOUT_MS" \
  -p "$SERVER_PID" \
  -d pt \
  -o "$PHPSPY_FILE" \
  2>"$PHPSPY_ERR" &
PHPSPY_PID=$!

sleep "$COLLECTOR_LEAD_SECONDS"

START_TS="$(python3 -c 'import time; print(time.time())')"

echo "Measured workload: implementation=$IMPLEMENTATION, duration=${DURATION_SECONDS}s, rate=${RATE}/s"
SUMMARY_PATH="$K6_SUMMARY" \
BASE_URL="$BASE_URL" \
WORKLOAD="$WORKLOAD" \
IMPLEMENTATION="$IMPLEMENTATION" \
SCALE="$SCALE" \
RATE="$RATE" \
DURATION_SECONDS="$DURATION_SECONDS" \
k6 run "$PROJECT_DIR/k6.js"

END_TS="$(python3 -c 'import time; print(time.time())')"

python3 - "$WINDOW_FILE" "$START_TS" "$END_TS" "$SERVER_PID" "$IMPLEMENTATION" <<'PY'
import json
import sys

path, start, end, pid, implementation = sys.argv[1:]
json.dump(
    {
        "start_timestamp": float(start),
        "end_timestamp": float(end),
        "target_pid": int(pid),
        "implementation": implementation,
    },
    open(path, "w", encoding="utf-8"),
    indent=2,
)
PY

echo "Waiting for collectors..."
wait "$SCAPH_PID"
SCAPH_PID=""
wait "$PHPSPY_PID" || true
PHPSPY_PID=""

echo "Analyzing..."
python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  --scaphandre "$SCAPH_FILE" \
  --baseline "$BASELINE_FILE" \
  --phpspy "$PHPSPY_FILE" \
  --window "$WINDOW_FILE" \
  --k6 "$K6_SUMMARY" \
  --carbon-intensity "$CARBON_INTENSITY_G_PER_KWH" \
  --flamegraph-script "$FLAMEGRAPH" \
  --output-dir "$RUN_DIR" \
  >"$RUN_DIR/analysis-console.json"

echo
echo "Measurement completed."
echo "Summary:           $RUN_DIR/SUMMARY.md"
echo "Energy flamegraph: $RUN_DIR/energy-flamegraph.svg"
echo "CPU flamegraph:    $RUN_DIR/cpu-flamegraph.svg"
echo "Raw summary:       $RUN_DIR/summary.json"
echo "Top functions:     $RUN_DIR/top-functions.csv"
echo "RESULT_DIR=$RUN_DIR"
