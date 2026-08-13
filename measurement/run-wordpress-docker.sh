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

CONTAINER_NAME="${1:-}"

if [[ -z "$CONTAINER_NAME" ]]; then
  echo "Uso: $0 <NOME_OU_ID_DO_CONTAINER_DOCKER>" >&2
  echo "Exemplo: $0 wordpress-container" >&2
  exit 1
fi

echo "==> Verificando container Docker '$CONTAINER_NAME'..."
if ! command -v docker >/dev/null 2>&1; then
  echo "Erro: 'docker' não encontrado." >&2
  exit 1
fi

TARGET_PID=$(sudo docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null)

if [[ -z "$TARGET_PID" || "$TARGET_PID" -eq 0 ]]; then
  echo "Erro: Não foi possível obter o PID do container '$CONTAINER_NAME'. O container está rodando?" >&2
  exit 1
fi

# Se o container for master process, tenta identificar workers PHP-FPM se existirem
CHILD_PID=$(pgrep -P "$TARGET_PID" -n 2>/dev/null || true)
if [[ -n "$CHILD_PID" ]]; then
  echo "PID do master process Docker: $TARGET_PID. Anexando ao worker PID: $CHILD_PID"
  TARGET_PID="$CHILD_PID"
else
  echo "Anexando ao PID do container: $TARGET_PID"
fi

RUN_DIR="$PROJECT_DIR/results/wordpress-docker-$(date +%Y%m%d-%H%M%S)"
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

cp "$CONFIG_FILE" "$RUN_DIR/experiment.env"

for command in curl python3 k6 scaphandre; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Comando não encontrado: $command" >&2
    exit 1
  }
done

[[ -x "$PHPSPY" ]] || {
  echo "phpspy não encontrado. Execute measurement/install-tools-ubuntu.sh." >&2
  exit 1
}

[[ -f "$FLAMEGRAPH" ]] || {
  echo "FlameGraph não encontrado. Execute measurement/install-tools-ubuntu.sh." >&2
  exit 1
}

sudo -v

SCAPH_PID=""
PHPSPY_PID=""

cleanup() {
  set +e
  [[ -n "$SCAPH_PID" ]] && sudo kill -INT "$SCAPH_PID" 2>/dev/null
  [[ -n "$PHPSPY_PID" ]] && sudo kill -INT "$PHPSPY_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

echo "Verificando se o WordPress está acessível em $BASE_URL..."
for _ in $(seq 1 30); do
  curl -fsS "$BASE_URL" >/dev/null 2>&1 && break
  sleep 0.5
done

curl -fsS "$BASE_URL" >/dev/null 2>&1 || {
  echo "Erro: Não foi possível conectar ao WordPress em $BASE_URL. Verifique o BASE_URL em config/experiment.env." >&2
  exit 1
}

echo "Target PID (Host): $TARGET_PID"
echo "Diretório de resultados: $RUN_DIR"

echo "Warm-up: ${WARMUP_SECONDS}s..."
SUMMARY_PATH="$RUN_DIR/k6-warmup-summary.json" \
BASE_URL="$BASE_URL" \
WORKLOAD="$WORKLOAD" \
WP_USER="${WP_USER:-marcos}" \
WP_PASS="${WP_PASS:-Teste1234}" \
IMPLEMENTATION="wordpress" \
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

echo "Iniciando Scaphandre..."
sudo scaphandre json \
  -t "$COLLECTOR_TIMEOUT" \
  -s "$SCAPHANDRE_STEP_SECONDS" \
  --max-top-consumers "$SCAPHANDRE_MAX_PROCESSES" \
  --process-regex "$SCAPHANDRE_PROCESS_REGEX" \
  --resources \
  -f "$SCAPH_FILE" &
SCAPH_PID=$!

echo "Iniciando phpspy no PID $TARGET_PID..."
sudo "$PHPSPY" \
  -H "$PHPSPY_RATE_HZ" \
  -i "$COLLECTOR_TIMEOUT_MS" \
  -p "$TARGET_PID" \
  -d pt \
  -o "$PHPSPY_FILE" \
  2>"$PHPSPY_ERR" &
PHPSPY_PID=$!

sleep "$COLLECTOR_LEAD_SECONDS"

START_TS="$(python3 -c 'import time; print(time.time())')"

echo "Executando carga de trabalho no WordPress em $BASE_URL (duração=${DURATION_SECONDS}s, rate=${RATE}/s)..."
SUMMARY_PATH="$K6_SUMMARY" \
BASE_URL="$BASE_URL" \
WORKLOAD="$WORKLOAD" \
WP_USER="${WP_USER:-marcos}" \
WP_PASS="${WP_PASS:-Teste1234}" \
IMPLEMENTATION="wordpress" \
SCALE="$SCALE" \
RATE="$RATE" \
DURATION_SECONDS="$DURATION_SECONDS" \
k6 run "$PROJECT_DIR/k6.js"

END_TS="$(python3 -c 'import time; print(time.time())')"

python3 - "$WINDOW_FILE" "$START_TS" "$END_TS" "$TARGET_PID" "wordpress" <<'PY'
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

echo "Aguardando coletores..."
wait "$SCAPH_PID"
SCAPH_PID=""
wait "$PHPSPY_PID" || true
PHPSPY_PID=""

echo "Analisando resultados..."
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
echo "Medição do WordPress (Docker) concluída!"
echo "Relatório:          $RUN_DIR/SUMMARY.md"
echo "Energy flamegraph: $RUN_DIR/energy-flamegraph.svg"
echo "CPU flamegraph:    $RUN_DIR/cpu-flamegraph.svg"
echo "Funções principais: $RUN_DIR/top-functions.csv"
