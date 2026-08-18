#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config/experiment.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# Configurações padrão
TARGET_LANG="${TARGET_LANGUAGE:-${METER_LANGUAGE:-php}}"
if [[ "$TARGET_LANG" != "php" && "$TARGET_LANG" != "java" && "$TARGET_LANG" != "python" ]]; then
  TARGET_LANG="php"
fi
TARGET_MODE="${MODE:-local}"
CONTAINER_NAME=""
TARGET_PID=""
CUSTOM_OUTPUT_DIR="${OUTPUT_DIR:-}"
TARGET_DURATION="${DURATION_SECONDS:-60}"
TARGET_BASELINE="${BASELINE_SECONDS:-15}"

usage() {
  cat <<EOF
Uso: $(basename "$0") -l <LINGUAGEM> -m <MODO> [OPÇÕES]

Medidor universal de consumo de energia e perfilamento de hardware (Scaphandre + Profilers).
Projetado para arquitetura multi-linguagem (PHP, e futuramente Java e Python).

Opções Obrigatórias/Principais:
  -l, --language <php|java|python>  Linguagem da aplicação a ser medida (padrão: $TARGET_LANG)
  -m, --mode <local|container|process> Modo de execução do alvo (padrão: $TARGET_MODE)
                                    - local: Inicia o servidor local da aplicação
                                    - container: Conecta a um container Docker em execução
                                    - process: Conecta a um processo já existente via PID

Opções de Modo:
  -c, --container <NOME_OU_ID>      Nome ou ID do container Docker (obrigatório se --mode container)
  -p, --pid <PID>                   PID do processo no Host (obrigatório se --mode process)

Opções de Medição:
  -d, --duration <SEGUNDOS>         Duração da janela de medição em segundos (padrão: $TARGET_DURATION)
  -b, --baseline <SEGUNDOS>         Duração da coleta em repouso/baseline em segundos (padrão: $TARGET_BASELINE)
  -o, --output <DIRETÓRIO>          Diretório customizado de saída para os resultados
  --config <ARQUIVO>                Arquivo de configuração .env (padrão: config/experiment.env)
  -h, --help                        Exibe esta ajuda

Exemplos:
  # 1. Medir aplicação PHP rodando localmente (inicia servidor embutido):
  $(basename "$0") -l php -m local

  # 2. Medir aplicação PHP em container Docker (ex: WordPress):
  $(basename "$0") -l php -m container -c wp_php

  # 3. Medir processo específico por PID:
  $(basename "$0") -l php -m process -p 12345
EOF
  exit 0
}

# Parse de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--language|--lang)
      TARGET_LANG="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
      shift 2
      ;;
    -m|--mode)
      TARGET_MODE="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
      shift 2
      ;;
    -c|--container)
      CONTAINER_NAME="$2"
      TARGET_MODE="container"
      shift 2
      ;;
    -p|--pid)
      TARGET_PID="$2"
      TARGET_MODE="process"
      shift 2
      ;;
    -d|--duration)
      TARGET_DURATION="$2"
      shift 2
      ;;
    -b|--baseline)
      TARGET_BASELINE="$2"
      shift 2
      ;;
    -o|--output|--output-dir)
      CUSTOM_OUTPUT_DIR="$2"
      shift 2
      ;;
    --config)
      CONFIG_FILE="$2"
      if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
      fi
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      # Suporte a argumentos posicionais rápidos: php local / php container wp_php
      if [[ -z "${TARGET_LANG_SET:-}" && ("$1" == "php" || "$1" == "java" || "$1" == "python") ]]; then
        TARGET_LANG="$1"
        TARGET_LANG_SET=1
        shift
      elif [[ "$1" == "local" || "$1" == "container" || "$1" == "process" || "$1" == "server" || "$1" == "docker" ]]; then
        if [[ "$1" == "server" ]]; then TARGET_MODE="local"; elif [[ "$1" == "docker" ]]; then TARGET_MODE="container"; else TARGET_MODE="$1"; fi
        shift
      elif [[ -n "${TARGET_MODE:-}" && "$TARGET_MODE" == "container" && -z "$CONTAINER_NAME" ]]; then
        CONTAINER_NAME="$1"
        shift
      else
        echo "Opção desconhecida: $1" >&2
        echo "Use $0 --help para ver as opções." >&2
        exit 1
      fi
      ;;
  esac
done

# Validação da linguagem
case "$TARGET_LANG" in
  php)
    ;;
  java|python)
    echo "=========================================================================="
    echo " [AVISO DE ARQUITETURA MULTI-LINGUAGEM]"
    echo " A linguagem selecionada foi: $TARGET_LANG"
    echo " O módulo e profiler para '$TARGET_LANG' serão integrados no futuro merge."
    echo " No momento, o medidor está ativo para: php."
    echo "=========================================================================="
    exit 1
    ;;
  *)
    echo "Erro: Linguagem não suportada: '$TARGET_LANG'. Escolha entre: php, java, python." >&2
    exit 1
    ;;
esac

# Diretório de resultados
if [[ -n "$CUSTOM_OUTPUT_DIR" ]]; then
  RUN_DIR="$CUSTOM_OUTPUT_DIR"
else
  RUN_DIR="$PROJECT_DIR/results/${TARGET_LANG}-${TARGET_MODE}-$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$RUN_DIR"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"

# Arquivos de saída
SCAPH_FILE="$RUN_DIR/scaphandre.json"
BASELINE_FILE="$RUN_DIR/scaphandre-baseline.json"
PROFILER_FILE="$RUN_DIR/phpspy.txt"
PROFILER_ERR="$RUN_DIR/phpspy.stderr.log"
WINDOW_FILE="$RUN_DIR/window.json"
SERVER_LOG="$RUN_DIR/server.log"
K6_SUMMARY="${K6_SUMMARY:-$RUN_DIR/k6-summary.json}"
FLAMEGRAPH="$PROJECT_DIR/tools/FlameGraph/flamegraph.pl"
PHPSPY="$PROJECT_DIR/tools/phpspy/phpspy"

if [[ -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_FILE" "$RUN_DIR/experiment.env"
fi

# Verificação de ferramentas comuns de medição
for command in curl python3 scaphandre; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Comando de medição não encontrado: $command. Execute measurement/install-tools-ubuntu.sh" >&2
    exit 1
  }
done

[[ -f "$FLAMEGRAPH" ]] || {
  echo "FlameGraph não encontrado em $FLAMEGRAPH. Execute measurement/install-tools-ubuntu.sh." >&2
  exit 1
}

# Verificação de ferramentas específicas da linguagem PHP
if [[ "$TARGET_LANG" == "php" ]]; then
  [[ -x "$PHPSPY" ]] || {
    echo "phpspy não encontrado em $PHPSPY. Execute measurement/install-tools-ubuntu.sh." >&2
    exit 1
  }
fi

sudo -v

SERVER_PID=""
SCAPH_PID=""
PROFILER_PID=""

cleanup() {
  set +e
  [[ -n "$SCAPH_PID" ]] && sudo kill -INT "$SCAPH_PID" 2>/dev/null
  [[ -n "$PROFILER_PID" ]] && sudo kill -INT "$PROFILER_PID" 2>/dev/null
  [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

# Resolução do Target PID conforme o Modo de Execução
case "$TARGET_MODE" in
  local|server)
    if [[ "$TARGET_LANG" == "php" ]]; then
      command -v php >/dev/null 2>&1 || { echo "Erro: 'php' CLI não encontrado no sistema." >&2; exit 1; }
      HOST="${HOST:-127.0.0.1}"
      PORT="${PORT:-8080}"
      BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
      echo "==> Iniciando servidor PHP local em ${HOST}:${PORT}..."
      php -S "${HOST}:${PORT}" -t "$PROJECT_DIR/public" >"$SERVER_LOG" 2>&1 &
      SERVER_PID=$!
      TARGET_PID="$SERVER_PID"

      for _ in $(seq 1 50); do
        curl -fsS "${BASE_URL}/health" >/dev/null 2>&1 && break
        sleep 0.2
      done

      curl -fsS "${BASE_URL}/health" >/dev/null 2>&1 || {
        echo "Erro: Servidor PHP falhou ao iniciar. Verifique $SERVER_LOG" >&2
        exit 1
      }
    fi
    ;;

  container|docker)
    if [[ -z "$CONTAINER_NAME" ]]; then
      echo "Erro: Nome ou ID do container não fornecido. Use -c <NOME_CONTAINER>." >&2
      exit 1
    fi
    if ! command -v docker >/dev/null 2>&1; then
      echo "Erro: 'docker' não foi encontrado." >&2
      exit 1
    fi

    echo "==> Identificando PID do container Docker '$CONTAINER_NAME'..."
    TARGET_PID=$(sudo docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || docker inspect -f '{{.State.Pid}}' "$CONTAINER_NAME" 2>/dev/null || true)
    if [[ -z "$TARGET_PID" || "$TARGET_PID" -eq 0 ]]; then
      echo "Erro: Não foi possível obter o PID do container '$CONTAINER_NAME'. O container está rodando?" >&2
      exit 1
    fi

    # Se for PHP-FPM, tenta capturar worker ativo do container
    if [[ "$TARGET_LANG" == "php" ]]; then
      CHILD_PID=$(pgrep -P "$TARGET_PID" -n 2>/dev/null || true)
      if [[ -n "$CHILD_PID" ]]; then
        echo "PID master: $TARGET_PID. Anexando ao worker PHP: $CHILD_PID"
        TARGET_PID="$CHILD_PID"
      else
        echo "Anexando ao PID do container: $TARGET_PID"
      fi
    fi
    ;;

  process|pid)
    if [[ -z "$TARGET_PID" ]]; then
      echo "Erro: PID não fornecido. Use -p <PID>." >&2
      exit 1
    fi
    if ! kill -0 "$TARGET_PID" 2>/dev/null; then
      echo "Erro: Processo com PID $TARGET_PID não está em execução ou sem permissão de acesso." >&2
      exit 1
    fi
    echo "==> Anexando ao processo PID existente: $TARGET_PID"
    ;;

  *)
    echo "Erro: Modo desconhecido '$TARGET_MODE'. Use local, container ou process." >&2
    exit 1
    ;;
esac

echo "Linguagem:              $TARGET_LANG"
echo "Modo de Execução:       $TARGET_MODE"
echo "PID Alvo no Host:       $TARGET_PID"
echo "Diretório de saída:     $RUN_DIR"

# 1. Medição de Baseline em Repouso (Scaphandre)
echo "==> Medindo consumo em repouso (baseline) por ${TARGET_BASELINE}s..."
sudo scaphandre json \
  -t "$TARGET_BASELINE" \
  -s "${SCAPHANDRE_STEP_SECONDS:-1}" \
  --max-top-consumers "${SCAPHANDRE_MAX_PROCESSES:-100}" \
  --process-regex "${SCAPHANDRE_PROCESS_REGEX:-php}" \
  --resources \
  -f "$BASELINE_FILE"

COLLECTOR_TIMEOUT=$(
  python3 - <<PY
print(int(${COLLECTOR_LEAD_SECONDS:-3}) + int(${TARGET_DURATION}) + int(${COLLECTOR_TAIL_SECONDS:-5}) + 8)
PY
)
COLLECTOR_TIMEOUT_MS=$((COLLECTOR_TIMEOUT * 1000))

# 2. Inicia Scaphandre em background
echo "==> Iniciando coletor Scaphandre em background..."
sudo scaphandre json \
  -t "$COLLECTOR_TIMEOUT" \
  -s "${SCAPHANDRE_STEP_SECONDS:-1}" \
  --max-top-consumers "${SCAPHANDRE_MAX_PROCESSES:-100}" \
  --process-regex "${SCAPHANDRE_PROCESS_REGEX:-php}" \
  --resources \
  -f "$SCAPH_FILE" &
SCAPH_PID=$!

# 3. Inicia Profiler específico da linguagem
if [[ "$TARGET_LANG" == "php" ]]; then
  echo "==> Iniciando phpspy no PID $TARGET_PID..."
  sudo "$PHPSPY" \
    -H "${PHPSPY_RATE_HZ:-99}" \
    -i "$COLLECTOR_TIMEOUT_MS" \
    -p "$TARGET_PID" \
    -d pt \
    -o "$PROFILER_FILE" \
    2>"$PROFILER_ERR" &
  PROFILER_PID=$!
fi

sleep "${COLLECTOR_LEAD_SECONDS:-3}"

START_TS="$(python3 -c 'import time; print(time.time())')"

echo ""
echo "=========================================================================="
echo " [MEDIDOR DE ENERGIA E PERFORMANCE INICIADO]"
echo " Linguagem:        $(echo "$TARGET_LANG" | tr '[:lower:]' '[:upper:]')"
echo " Modo:             $TARGET_MODE"
echo " PID Alvo (Host):  $TARGET_PID"
echo " Duração Janela:   ${TARGET_DURATION}s"
echo " Resultados em:    $RUN_DIR"
echo ""
echo " Execute o teste de carga AGORA (em outro terminal ou máquina remota):"
echo "   ./run-load-test.sh"
echo "=========================================================================="
echo ""

echo "Aguardando janela de medição (${TARGET_DURATION}s)..."
sleep "$TARGET_DURATION"

END_TS="$(python3 -c 'import time; print(time.time())')"

# Grava janela de medição
python3 - "$WINDOW_FILE" "$START_TS" "$END_TS" "$TARGET_PID" "$TARGET_LANG" "$TARGET_MODE" <<'PY'
import json
import sys

path, start, end, pid, lang, mode = sys.argv[1:]
json.dump(
    {
        "start_timestamp": float(start),
        "end_timestamp": float(end),
        "duration_seconds": float(end) - float(start),
        "target_pid": int(pid),
        "language": lang,
        "mode": mode,
    },
    open(path, "w", encoding="utf-8"),
    indent=2,
)
PY

echo "Aguardando término dos coletores..."
wait "$SCAPH_PID"
SCAPH_PID=""

if [[ -n "$PROFILER_PID" ]]; then
  wait "$PROFILER_PID" || true
  PROFILER_PID=""
fi

echo "Analisando resultados..."
ANALYZE_ARGS=(
  --scaphandre "$SCAPH_FILE"
  --baseline "$BASELINE_FILE"
  --phpspy "$PROFILER_FILE"
  --window "$WINDOW_FILE"
  --carbon-intensity "${CARBON_INTENSITY_G_PER_KWH:-100}"
  --flamegraph-script "$FLAMEGRAPH"
  --output-dir "$RUN_DIR"
)

if [[ -f "$K6_SUMMARY" ]]; then
  ANALYZE_ARGS+=(--k6 "$K6_SUMMARY")
fi

python3 "$PROJECT_DIR/measurement/analyze_measurement.py" \
  "${ANALYZE_ARGS[@]}" \
  >"$RUN_DIR/analysis-console.json"

echo
echo "=========================================================================="
echo " [MEDIÇÃO CONCLUÍDA]"
echo " Relatório:          $RUN_DIR/SUMMARY.md"
echo " Energy flamegraph:  $RUN_DIR/energy-flamegraph.svg"
echo " CPU flamegraph:     $RUN_DIR/cpu-flamegraph.svg"
echo " Top funções:        $RUN_DIR/top-functions.csv"
echo " Resumo JSON:        $RUN_DIR/summary.json"
echo " RESULT_DIR=$RUN_DIR"
echo "=========================================================================="
