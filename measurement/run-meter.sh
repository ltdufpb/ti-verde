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
TARGET_MODE="${MODE:-local}"
CONTAINER_NAME=""
TARGET_PID=""
CUSTOM_OUTPUT_DIR="${OUTPUT_DIR:-}"
TARGET_DURATION="${DURATION_SECONDS:-60}"
TARGET_BASELINE="${BASELINE_SECONDS:-15}"
APPLICATION_PREFIX="${APPLICATION_PREFIX:-}"
PROJECT_ROOT="${PROJECT_ROOT:-}"
APP_CMD="${APP_CMD:-}"

usage() {
  cat <<EOF
Uso: $(basename "$0") -l <LINGUAGEM> -m <MODO> --application-prefix <PREFIXO> [OPÇÕES]

Medidor universal de consumo de energia e perfilamento de hardware (Scaphandre + Profilers).
Suporta arquitetura multi-linguagem: PHP (phpspy), Java (async-profiler/JFR) e Python (py-spy).

Opções Principais:
  -l, --language <php|java|python>  Linguagem da aplicação a ser medida (padrão: $TARGET_LANG)
  -m, --mode <local|container|process> Modo de execução do alvo (padrão: $TARGET_MODE)
                                    - local: Inicia o servidor local da aplicação
                                    - container: Conecta a um container Docker em execução
                                    - process: Conecta a um processo já existente via PID

Opções de Modo:
  -c, --container <NOME_OU_ID>      Nome ou ID do container Docker (obrigatório se --mode container)
  -p, --pid <PID>                   PID do processo no Host (obrigatório se --mode process)
  --app-cmd <COMANDO>               Comando customizado para inicialização no modo local

Opções de Medição e Escopo:
  -d, --duration <SEGUNDOS>         Duração da janela de medição em segundos (padrão: $TARGET_DURATION)
  -b, --baseline <SEGUNDOS>         Duração da coleta em repouso/baseline em segundos (padrão: $TARGET_BASELINE)
  -o, --output <DIRETÓRIO>          Diretório customizado de saída para os resultados
  --prefix, --application-prefix <PREFIXO>  OBRIGATÓRIO. Filtra funções pelo prefixo do pacote/módulo
                                             (ex: "com/minhaempresa/servico" para Java, "meuapp." para Python,
                                             "App\\" para PHP)
  --project-root <DIRETÓRIO>        Raiz do código-fonte para qualificação dos frames.
                                     OBRIGATÓRIO para --language php e --language python
                                     (Java já vem qualificado nativamente pela JVM)
  --k6 <ARQUIVO>                    Caminho do arquivo k6-summary.json gerado pelo teste de carga
  --config <ARQUIVO>                Arquivo de configuração .env (padrão: config/experiment.env)
  -h, --help                        Exibe esta ajuda

Exemplos:
  # 1. Medir aplicação local Java (inicia servidor, filtra por pacote):
  $(basename "$0") --language java --mode local --application-prefix "com/minhaempresa/servico"

  # 2. Medir aplicação em container Docker Python:
  $(basename "$0") --language python --mode container -c fastapi_app \\
    --project-root /caminho/do/projeto --application-prefix "meuapp."

  # 3. Medir processo PHP específico por PID existente:
  $(basename "$0") --language php --mode process -p 12345 \\
    --project-root /caminho/do/projeto --application-prefix "App\\\\"
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
    --prefix|--application-prefix)
      APPLICATION_PREFIX="$2"
      shift 2
      ;;
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    -u|--url|--base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --app-cmd|--start-cmd)
      APP_CMD="$2"
      shift 2
      ;;
    --k6|--k6-summary)
      K6_SUMMARY="$2"
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
      # Suporte a argumentos posicionais rápidos: php local / python container my_app / java process 1234
      if [[ -z "${TARGET_LANG_SET:-}" && ("$1" == "php" || "$1" == "java" || "$1" == "python") ]]; then
        TARGET_LANG="$1"
        TARGET_LANG_SET=1
        shift
      elif [[ "$1" == "local" || "$1" == "container" || "$1" == "process" || "$1" == "server" || "$1" == "docker" || "$1" == "pid" ]]; then
        if [[ "$1" == "server" ]]; then TARGET_MODE="local"; elif [[ "$1" == "docker" ]]; then TARGET_MODE="container"; elif [[ "$1" == "pid" ]]; then TARGET_MODE="process"; else TARGET_MODE="$1"; fi
        shift
      elif [[ -n "${TARGET_MODE:-}" && "$TARGET_MODE" == "container" && -z "$CONTAINER_NAME" ]]; then
        CONTAINER_NAME="$1"
        shift
      elif [[ -n "${TARGET_MODE:-}" && "$TARGET_MODE" == "process" && -z "$TARGET_PID" && "$1" =~ ^[0-9]+$ ]]; then
        TARGET_PID="$1"
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
  php|java|python)
    ;;
  *)
    echo "Erro: Linguagem não suportada: '$TARGET_LANG'. Escolha entre: php, java, python." >&2
    exit 1
    ;;
esac

# Validação do modo
case "$TARGET_MODE" in
  local|server|container|docker|process|pid)
    ;;
  *)
    echo "Erro: Modo desconhecido: '$TARGET_MODE'. Escolha entre: local, container, process." >&2
    exit 1
    ;;
esac

# Validação do filtro de escopo — sempre obrigatório, em qualquer linguagem/modo
if [[ -z "$APPLICATION_PREFIX" ]]; then
  echo "Erro: --application-prefix é obrigatório. Use --help para ver exemplos." >&2
  exit 1
fi

# --project-root só é usado por phpspy/py-spy para qualificar nomes de frame;
# JFR (Java) já entrega nomes de classe totalmente qualificados pela JVM.
if [[ "$TARGET_LANG" != "java" && -z "$PROJECT_ROOT" ]]; then
  echo "Erro: --project-root é obrigatório para --language php ou --language python." >&2
  exit 1
fi

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
WINDOW_FILE="$RUN_DIR/window.json"
SERVER_LOG="$RUN_DIR/server.log"
K6_SUMMARY="${K6_SUMMARY:-$RUN_DIR/k6-summary.json}"
FLAMEGRAPH="$PROJECT_DIR/tools/FlameGraph/flamegraph.pl"

case "$TARGET_LANG" in
  php)
    PROFILER_FILE="$RUN_DIR/phpspy.txt"
    PROFILER_ERR="$RUN_DIR/phpspy.stderr.log"
    PHPSPY="${PHPSPY:-$PROJECT_DIR/tools/phpspy/phpspy}"
    ;;
  python)
    PROFILER_FILE="$RUN_DIR/profile.chrometrace.json"
    PROFILER_ERR="$RUN_DIR/pyspy.stderr.log"
    PYSPY="$(command -v py-spy || true)"
    ;;
  java)
    PROFILER_FILE="$RUN_DIR/profile.jfr"
    PROFILER_ERR="$RUN_DIR/asprof.stderr.log"
    ASPROF="${ASPROF:-$PROJECT_DIR/tools/async-profiler/bin/asprof}"
    if [[ ! -x "$ASPROF" ]] && command -v asprof >/dev/null 2>&1; then
      ASPROF="$(command -v asprof)"
    fi
    ;;
esac

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

# Verificação de ferramentas específicas da linguagem selecionada
case "$TARGET_LANG" in
  php)
    [[ -x "$PHPSPY" ]] || {
      echo "phpspy não encontrado em $PHPSPY. Execute measurement/install-tools-ubuntu.sh." >&2
      exit 1
    }
    ;;
  python)
    [[ -n "$PYSPY" ]] || {
      echo "py-spy não encontrado. Instale com: pip install py-spy --break-system-packages (ou execute measurement/install-tools-ubuntu.sh)" >&2
      exit 1
    }
    ;;
  java)
    [[ -x "$ASPROF" ]] || {
      echo "async-profiler (asprof) não encontrado em $ASPROF. Execute measurement/install-tools-ubuntu.sh." >&2
      exit 1
    }
    command -v jfr >/dev/null 2>&1 || {
      echo "Comando 'jfr' não encontrado no PATH. Instale o OpenJDK (ex: default-jdk ou openjdk-21-jdk)." >&2
      exit 1
    }
    ;;
esac

SERVER_PID=""
SCAPH_PID=""
PROFILER_PID=""
PYSPY_START_TIME=""

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
    HOST="${HOST:-127.0.0.1}"
    PORT="${PORT:-8080}"
    BASE_URL="${BASE_URL:-http://${HOST}:${PORT}}"

    case "$TARGET_LANG" in
      php)
        command -v php >/dev/null 2>&1 || { echo "Erro: 'php' CLI não encontrado no sistema." >&2; exit 1; }
        if [[ -n "$APP_CMD" ]]; then
          echo "==> Iniciando comando PHP customizado: $APP_CMD..."
          eval "$APP_CMD" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        else
          echo "==> Iniciando servidor PHP local em ${HOST}:${PORT}..."
          php -S "${HOST}:${PORT}" -t "$PROJECT_DIR/public" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        fi
        TARGET_PID="$SERVER_PID"
        ;;

      python)
        command -v python3 >/dev/null 2>&1 || { echo "Erro: 'python3' não encontrado no sistema." >&2; exit 1; }
        if [[ -n "$APP_CMD" ]]; then
          echo "==> Iniciando comando Python customizado: $APP_CMD..."
          eval "$APP_CMD" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        elif [[ -f "$PROJECT_DIR/scripts/python-server.py" ]]; then
          echo "==> Iniciando servidor Python local em ${HOST}:${PORT}..."
          python3 "$PROJECT_DIR/scripts/python-server.py" --host "${HOST}" --port "${PORT}" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        elif [[ -f "$PROJECT_DIR/public/app.py" ]]; then
          echo "==> Iniciando servidor Python local em ${HOST}:${PORT}..."
          python3 "$PROJECT_DIR/public/app.py" --host "${HOST}" --port "${PORT}" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        else
          echo "==> Iniciando servidor Python HTTP em ${HOST}:${PORT}..."
          python3 -m http.server "${PORT}" --bind "${HOST}" --directory "$PROJECT_DIR/public" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        fi
        TARGET_PID="$SERVER_PID"
        ;;

      java)
        command -v java >/dev/null 2>&1 || { echo "Erro: 'java' não encontrado no sistema." >&2; exit 1; }
        if [[ -n "$APP_CMD" ]]; then
          echo "==> Iniciando comando Java customizado: $APP_CMD..."
          eval "$APP_CMD" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        elif [[ -n "${JAVA_JAR:-}" && -f "$JAVA_JAR" ]]; then
          echo "==> Iniciando JAR Java local: $JAVA_JAR..."
          java -jar "$JAVA_JAR" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        elif [[ -f "$PROJECT_DIR/scripts/JavaServer.java" ]]; then
          echo "==> Iniciando servidor Java local em ${HOST}:${PORT}..."
          java "$PROJECT_DIR/scripts/JavaServer.java" "${PORT}" "${HOST}" >"$SERVER_LOG" 2>&1 &
          SERVER_PID=$!
        else
          echo "Erro: Nenhum comando ou aplicação Java especificada para modo local." >&2
          echo "Use --app-cmd 'java -jar app.jar' ou configure JAVA_JAR no .env" >&2
          echo "Ou execute sua aplicação e use: $0 --language java --mode process -p <PID>" >&2
          exit 1
        fi
        TARGET_PID="$SERVER_PID"
        ;;
    esac

    # Healthcheck / Aguardar inicialização do servidor
    echo "==> Aguardando servidor ficar online em ${BASE_URL}..."
    SERVER_ONLINE=0
    for _ in $(seq 1 50); do
      if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "Erro: O processo do servidor local (PID $SERVER_PID) encerrou prematuramente." >&2
        if [[ -s "$SERVER_LOG" ]]; then
          echo "--- Detalhes do erro em $SERVER_LOG ---" >&2
          cat "$SERVER_LOG" >&2
          echo "----------------------------------------" >&2
        fi
        exit 1
      fi
      if curl -fsS "${BASE_URL}/health" >/dev/null 2>&1 || curl -fsS "${BASE_URL}/" >/dev/null 2>&1; then
        SERVER_ONLINE=1
        break
      fi
      sleep 0.2
    done

    if [[ "$SERVER_ONLINE" -ne 1 ]]; then
      echo "Erro: Servidor falhou ao responder em ${BASE_URL}. Verifique $SERVER_LOG" >&2
      exit 1
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

    case "$TARGET_LANG" in
      php)
        CHILD_PID=$(pgrep -P "$TARGET_PID" -n 2>/dev/null || true)
        if [[ -n "$CHILD_PID" ]]; then
          echo "PID master: $TARGET_PID. Anexando ao worker PHP: $CHILD_PID"
          TARGET_PID="$CHILD_PID"
        else
          echo "Anexando ao PID do container: $TARGET_PID"
        fi
        ;;
      python)
        CHILD_PID=$(pgrep -P "$TARGET_PID" -n 2>/dev/null || true)
        if [[ -n "$CHILD_PID" ]]; then
          echo "PID master: $TARGET_PID. Anexando ao worker Python: $CHILD_PID"
          TARGET_PID="$CHILD_PID"
        else
          echo "Anexando ao PID do container: $TARGET_PID"
        fi
        ;;
      java)
        JAVA_CHILD=$(pgrep -P "$TARGET_PID" -x java -n 2>/dev/null || true)
        if [[ -n "$JAVA_CHILD" ]]; then
          echo "PID master: $TARGET_PID. Anexando ao processo Java: $JAVA_CHILD"
          TARGET_PID="$JAVA_CHILD"
        else
          echo "Anexando ao PID do container: $TARGET_PID"
        fi
        ;;
    esac
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

# Determina regex de processo para o Scaphandre
if [[ -z "${SCAPHANDRE_PROCESS_REGEX:-}" || "$SCAPHANDRE_PROCESS_REGEX" == "php" || "$SCAPHANDRE_PROCESS_REGEX" == "(php|mysqld|mariadbd|apache2)" ]]; then
  case "$TARGET_LANG" in
    php)    SCAPH_REGEX="(php|php-fpm|apache2|httpd|mysqld|mariadbd)" ;;
    python) SCAPH_REGEX="(python|python3|pypy|gunicorn|uvicorn|uwsgi)" ;;
    java)   SCAPH_REGEX="(java|jvm)" ;;
    *)      SCAPH_REGEX="$TARGET_LANG" ;;
  esac
else
  SCAPH_REGEX="$SCAPHANDRE_PROCESS_REGEX"
fi

sudo -v 2>/dev/null || true

# 1. Medição de Baseline em Repouso (Scaphandre)
if [[ "${TARGET_BASELINE}" -gt 0 ]]; then
  echo "==> Medindo consumo em repouso (baseline) por ${TARGET_BASELINE}s..."
  sudo scaphandre json \
    -t "$TARGET_BASELINE" \
    -s "${SCAPHANDRE_STEP_SECONDS:-1}" \
    --max-top-consumers "${SCAPHANDRE_MAX_PROCESSES:-100}" \
    --process-regex "$SCAPH_REGEX" \
    --resources \
    -f "$BASELINE_FILE"
else
  echo "==> Baseline ignorado (0s)."
fi

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
  --process-regex "$SCAPH_REGEX" \
  --resources \
  -f "$SCAPH_FILE" &
SCAPH_PID=$!

# 3. Inicia Profiler específico da linguagem
case "$TARGET_LANG" in
  php)
    echo "==> Iniciando phpspy no PID $TARGET_PID..."
    sudo "$PHPSPY" \
      -H "${PHPSPY_RATE_HZ:-99}" \
      -i "$COLLECTOR_TIMEOUT_MS" \
      -p "$TARGET_PID" \
      -d pt \
      -o "$PROFILER_FILE" \
      2>"$PROFILER_ERR" &
    PROFILER_PID=$!
    ;;
  python)
    echo "==> Iniciando py-spy no PID $TARGET_PID..."
    PYSPY_START_TIME="$(python3 -c 'import time; print(time.time())')"
    PYSPY_EXTRA_ARGS=()
    if [[ "${PYSPY_INCLUDE_IDLE:-false}" == "true" ]]; then
      PYSPY_EXTRA_ARGS+=(--idle)
    fi
    sudo "$PYSPY" record \
      --pid "$TARGET_PID" \
      --duration "$COLLECTOR_TIMEOUT" \
      --format chrometrace \
      "${PYSPY_EXTRA_ARGS[@]}" \
      --rate "${PYSPY_RATE_HZ:-100}" \
      --output "$PROFILER_FILE" \
      2>"$PROFILER_ERR" &
    PROFILER_PID=$!
    ;;
  java)
    echo "==> Iniciando async-profiler (asprof) no PID $TARGET_PID..."
    sudo "$ASPROF" \
      -d "$COLLECTOR_TIMEOUT" \
      -f "$PROFILER_FILE" \
      "$TARGET_PID" \
      2>"$PROFILER_ERR" &
    PROFILER_PID=$!
    ;;
esac

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
  --window "$WINDOW_FILE"
  --carbon-intensity "${CARBON_INTENSITY_G_PER_KWH:-100}"
  --flamegraph-script "$FLAMEGRAPH"
  --output-dir "$RUN_DIR"
  --application-prefix "$APPLICATION_PREFIX"
)

if [[ -f "$BASELINE_FILE" ]]; then
  ANALYZE_ARGS+=(--baseline "$BASELINE_FILE")
fi

case "$TARGET_LANG" in
  php)
    ANALYZE_ARGS+=(--phpspy "$PROFILER_FILE")
    ;;
  python)
    ANALYZE_ARGS+=(--pyspy "$PROFILER_FILE" --start-time "$PYSPY_START_TIME" --pyspy-rate "${PYSPY_RATE_HZ:-100}")
    ;;
  java)
    ANALYZE_ARGS+=(--jfr "$PROFILER_FILE")
    ;;
esac

if [[ -f "$K6_SUMMARY" ]]; then
  ANALYZE_ARGS+=(--k6 "$K6_SUMMARY")
fi

if [[ -n "$PROJECT_ROOT" ]]; then
  ANALYZE_ARGS+=(--project-root "$PROJECT_ROOT")
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
