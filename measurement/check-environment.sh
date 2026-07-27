#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "== Green PHP Lab environment check =="

[[ "$(uname -s)" == "Linux" ]] || fail "This workflow requires Linux."

if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  fail "WSL detected. Use native Linux on the physical computer."
fi

for command in php curl python3 k6 scaphandre perl; do
  command -v "$command" >/dev/null 2>&1 ||
    fail "Missing command: $command. Run measurement/install-tools-ubuntu.sh."
done

[[ -x "$PROJECT_DIR/tools/phpspy/phpspy" ]] ||
  fail "phpspy is not built."

[[ -f "$PROJECT_DIR/tools/FlameGraph/flamegraph.pl" ]] ||
  fail "FlameGraph is missing."

THREAD_SAFETY="$(php -i 2>/dev/null | awk -F'=> ' '/Thread Safety/ {print tolower($2); exit}')"
if [[ "$THREAD_SAFETY" == "enabled" ]]; then
  fail "phpspy requires non-ZTS PHP, but Thread Safety is enabled."
fi

sudo -v
sudo modprobe intel_rapl_common 2>/dev/null || true
sudo modprobe intel_rapl_msr 2>/dev/null || true

POWER_FILES="$(
  find -L /sys/class/powercap -name energy_uj -type f 2>/dev/null |
  wc -l
)"
if [[ "$POWER_FILES" -eq 0 ]]; then
  fail "No RAPL energy_uj counters found under /sys/class/powercap."
fi

echo "Found $POWER_FILES RAPL energy counter(s)."

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

echo "Running Scaphandre smoke test..."
sudo scaphandre json -t 4 -s 1 --max-top-consumers 5 -f "$TMP_FILE" >/dev/null
[[ -s "$TMP_FILE" ]] || fail "Scaphandre produced no JSON."

python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  --validate-scaphandre "$TMP_FILE"

"$PROJECT_DIR/measurement/test-analyzer.sh"

echo
echo "Environment is ready."
echo "PHP:        $(php -v | head -n 1)"
echo "k6:         $(k6 version | head -n 1)"
echo "Scaphandre: $(scaphandre --version 2>/dev/null || echo installed)"
echo "phpspy:     $("$PROJECT_DIR/tools/phpspy/phpspy" -v 2>/dev/null || echo built)"
