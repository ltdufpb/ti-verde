#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

echo "== Green Energy Lab Environment Check =="

[[ "$(uname -s)" == "Linux" ]] || fail "This workflow requires Linux."

if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  fail "WSL detected. Use native Linux on the physical computer."
fi

for command in curl python3 scaphandre perl; do
  command -v "$command" >/dev/null 2>&1 ||
    fail "Missing command: $command. Run measurement/install-tools-ubuntu.sh."
done

if ! command -v k6 >/dev/null 2>&1; then
  echo "INFO: 'k6' não está instalado localmente. (Necessário apenas para executar testes de carga locais via run-load-test.sh)"
fi

[[ -f "$PROJECT_DIR/tools/FlameGraph/flamegraph.pl" ]] ||
  fail "FlameGraph is missing in tools/FlameGraph."

echo "== Verificando ecossistema PHP =="
if command -v php >/dev/null 2>&1; then
  THREAD_SAFETY="$(php -i 2>/dev/null | awk -F'=> ' '/Thread Safety/ {print tolower($2); exit}')"
  if [[ "$THREAD_SAFETY" == "enabled" ]]; then
    echo "AVISO: PHP Thread Safety está habilitado (phpspy requer PHP Non-ZTS)."
  fi
  if [[ -x "$PROJECT_DIR/tools/phpspy/phpspy" ]]; then
    echo "  [OK] PHP CLI + phpspy disponíveis"
  else
    echo "  [AVISO] phpspy não encontrado em tools/phpspy/phpspy. Execute measurement/install-tools-ubuntu.sh para compilar."
  fi
else
  echo "  [INFO] php CLI não instalado."
fi

echo "== Verificando ecossistema Python =="
if command -v py-spy >/dev/null 2>&1; then
  echo "  [OK] Python 3 + py-spy ($(py-spy --version 2>/dev/null || echo 'instalado'))"
else
  echo "  [AVISO] py-spy não encontrado. Instale com: pip install py-spy --break-system-packages"
fi

echo "== Verificando ecossistema Java =="
ASPROF="$PROJECT_DIR/tools/async-profiler/bin/asprof"
if [[ -x "$ASPROF" ]] || command -v asprof >/dev/null 2>&1; then
  echo "  [OK] async-profiler (asprof) disponível"
else
  echo "  [AVISO] async-profiler (asprof) não encontrado. Execute measurement/install-tools-ubuntu.sh."
fi

if command -v jfr >/dev/null 2>&1; then
  echo "  [OK] JDK JFR CLI disponível"
else
  echo "  [INFO] Comando 'jfr' não encontrado (necessário para profiling Java nativo)."
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
echo "Environment check completed successfully."
echo "PHP:            $(php -v 2>/dev/null | head -n 1 || echo 'não instalado')"
echo "Python:         $(python3 --version 2>/dev/null || echo 'não instalado')"
echo "py-spy:         $(py-spy --version 2>/dev/null || echo 'não instalado')"
echo "Java:           $(java -version 2>&1 | head -n 1 || echo 'não instalado')"
echo "async-profiler: $($PROJECT_DIR/tools/async-profiler/bin/asprof --version 2>/dev/null || asprof --version 2>/dev/null || echo 'não instalado')"
echo "k6:             $(k6 version 2>/dev/null | head -n 1 || echo 'não instalado (opcional no host de medição)')"
echo "Scaphandre:     $(scaphandre --version 2>/dev/null || echo installed)"

