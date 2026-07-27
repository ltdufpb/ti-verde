#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config/experiment.env}"

# shellcheck disable=SC1090
source "$CONFIG_FILE"

SESSION_DIR="$PROJECT_DIR/results/comparison-$(date +%Y%m%d-%H%M%S)"
SLOW_DIR="$SESSION_DIR/slow"
FAST_DIR="$SESSION_DIR/fast"
mkdir -p "$SLOW_DIR" "$FAST_DIR"

echo "=== Slow implementation ==="
OUTPUT_DIR="$SLOW_DIR" CONFIG_FILE="$CONFIG_FILE" \
  "$PROJECT_DIR/measurement/run-experiment.sh" slow

echo
echo "Cooling down for ${COOLDOWN_SECONDS}s..."
sleep "$COOLDOWN_SECONDS"

echo
echo "=== Fast implementation ==="
OUTPUT_DIR="$FAST_DIR" CONFIG_FILE="$CONFIG_FILE" \
  "$PROJECT_DIR/measurement/run-experiment.sh" fast

python3 "$PROJECT_DIR/measurement/compare_runs.py" \
  "$SLOW_DIR" \
  "$FAST_DIR" \
  --output "$SESSION_DIR/COMPARISON.md"

echo
echo "Comparison completed: $SESSION_DIR"
