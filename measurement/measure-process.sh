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

TARGET_PID="${1:-}"
LANGUAGE="${2:-}"

if [[ -z "$TARGET_PID" || -z "$LANGUAGE" ]]; then
  echo "Usage: $0 <pid> <php|python|java>" >&2
  exit 1
fi

case "$LANGUAGE" in
  php|python|java) ;;
  *)
    echo "Unsupported language: $LANGUAGE (expected php, python, or java)" >&2
    exit 1
    ;;
esac

kill -0 "$TARGET_PID" 2>/dev/null || {
  echo "Process $TARGET_PID not found or not running." >&2
  exit 1
}

if [[ -n "${OUTPUT_DIR:-}" ]]; then
  RUN_DIR="$OUTPUT_DIR"
else
  RUN_DIR="$PROJECT_DIR/results/${LANGUAGE}-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$RUN_DIR"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"

FLAMEGRAPH="$PROJECT_DIR/tools/FlameGraph/flamegraph.pl"
SCAPH_FILE="$RUN_DIR/scaphandre.json"
WINDOW_FILE="$RUN_DIR/window.json"

cp "$CONFIG_FILE" "$RUN_DIR/experiment.env"

REQUIRED_COMMANDS=(curl python3 scaphandre)
case "$LANGUAGE" in
  php)    REQUIRED_COMMANDS+=(php) ;;
  python) REQUIRED_COMMANDS+=(py-spy) ;;
  java)   REQUIRED_COMMANDS+=(jfr) ;;
esac

for command in "${REQUIRED_COMMANDS[@]}"; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing command: $command" >&2
    exit 1
  }
done

if [[ "$LANGUAGE" == "php" ]]; then
  PHPSPY="$PROJECT_DIR/tools/phpspy/phpspy"
  [[ -x "$PHPSPY" ]] || {
    echo "phpspy not found. Run measurement/install-tools-ubuntu.sh." >&2
    exit 1
  }
fi

if [[ "$LANGUAGE" == "python" ]]; then
  PYSPY="$(command -v py-spy || true)"
  [[ -n "$PYSPY" ]] || {
    echo "py-spy not found. Install with: pip install py-spy --break-system-packages" >&2
    exit 1
  }
fi

if [[ "$LANGUAGE" == "java" ]]; then
  ASPROF="$PROJECT_DIR/tools/async-profiler/bin/asprof"
  [[ -x "$ASPROF" ]] || {
    echo "asprof not found." >&2
    exit 1
  }
fi

[[ -f "$FLAMEGRAPH" ]] || {
  echo "FlameGraph not found. Run measurement/install-tools-ubuntu.sh." >&2
  exit 1
}

sudo -v

SCAPH_PID=""
PROFILER_PID=""

cleanup() {
  set +e
  [[ -n "$SCAPH_PID" ]] && sudo kill -INT "$SCAPH_PID" 2>/dev/null
  [[ -n "$PROFILER_PID" ]] && sudo kill -INT "$PROFILER_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

echo "Target PID: $TARGET_PID"
echo "Language: $LANGUAGE"
echo "Run directory: $RUN_DIR"

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
  --resources \
  -f "$SCAPH_FILE" &
SCAPH_PID=$!

case "$LANGUAGE" in
  php)
    PHPSPY_FILE="$RUN_DIR/phpspy.txt"
    PHPSPY_ERR="$RUN_DIR/phpspy.stderr.log"
    echo "Starting phpspy..."
    sudo "$PHPSPY" \
      -H "$PHPSPY_RATE_HZ" \
      -i "$COLLECTOR_TIMEOUT_MS" \
      -p "$TARGET_PID" \
      -d pt \
      -o "$PHPSPY_FILE" \
      2>"$PHPSPY_ERR" &
    PROFILER_PID=$!
    ;;
  python)
    PYSPY_FILE="$RUN_DIR/profile.speedscope.json"
    PYSPY_ERR="$RUN_DIR/pyspy.stderr.log"
    echo "Starting py-spy..."
    PYSPY_START_TIME="$(python3 -c 'import time; print(time.time())')"
    sudo "$PYSPY" record \
      --pid "$TARGET_PID" \
      --duration "$COLLECTOR_TIMEOUT" \
      --format speedscope \
      --output "$PYSPY_FILE" \
      2>"$PYSPY_ERR" &
    PROFILER_PID=$!
    ;;
  java)
    JFR_FILE="$RUN_DIR/profile.jfr"
    JFR_ERR="$RUN_DIR/asprof.stderr.log"
    echo "Starting async-profiler..."
    sudo "$ASPROF" \
      -d "$COLLECTOR_TIMEOUT" \
      -f "$JFR_FILE" \
      "$TARGET_PID" \
      2>"$JFR_ERR" &
    PROFILER_PID=$!
    ;;
esac

sleep "$COLLECTOR_LEAD_SECONDS"

START_TS="$(python3 -c 'import time; print(time.time())')"

echo "Measuring for ${DURATION_SECONDS}s..."
sleep "$DURATION_SECONDS"

END_TS="$(python3 -c 'import time; print(time.time())')"

python3 - "$WINDOW_FILE" "$START_TS" "$END_TS" "$TARGET_PID" "$LANGUAGE" <<'PY'
import json
import sys

path, start, end, pid, language = sys.argv[1:]
json.dump(
    {
        "start_timestamp": float(start),
        "end_timestamp": float(end),
        "target_pid": int(pid),
        "language": language,
    },
    open(path, "w", encoding="utf-8"),
    indent=2,
)
PY

echo "Waiting for collectors..."
wait "$SCAPH_PID"
SCAPH_PID=""
wait "$PROFILER_PID" || true
PROFILER_PID=""

echo "Analyzing..."
ANALYZE_ARGS=(
  --scaphandre "$SCAPH_FILE"
  --window "$WINDOW_FILE"
  --carbon-intensity "$CARBON_INTENSITY_G_PER_KWH"
  --flamegraph-script "$FLAMEGRAPH"
  --output-dir "$RUN_DIR"
)

case "$LANGUAGE" in
  php)    ANALYZE_ARGS+=(--phpspy "$PHPSPY_FILE") ;;
  python) ANALYZE_ARGS+=(--pyspy "$PYSPY_FILE" --start-time "$PYSPY_START_TIME") ;;
  java)   ANALYZE_ARGS+=(--jfr "$JFR_FILE") ;;
esac

python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  "${ANALYZE_ARGS[@]}" \
  >"$RUN_DIR/analysis-console.json"

echo
echo "Measurement completed."
echo "Summary:           $RUN_DIR/SUMMARY.md"
echo "Energy flamegraph: $RUN_DIR/energy-flamegraph.svg"
echo "CPU flamegraph:    $RUN_DIR/cpu-flamegraph.svg"
echo "Raw summary:       $RUN_DIR/summary.json"
echo "Top functions:     $RUN_DIR/top-functions.csv"
echo "RESULT_DIR=$RUN_DIR"
