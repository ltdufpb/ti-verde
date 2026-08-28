#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config/experiment.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

TARGET_URL="${BASE_URL:-http://127.0.0.1:8080}"
TARGET_WORKLOAD="${WORKLOAD:-wordpress}"
TARGET_SCALE="${SCALE:-1}"
TARGET_RATE="${RATE:-2}"
TARGET_DURATION="${DURATION_SECONDS:-60}"
TARGET_WARMUP=0
WP_USER="${WP_USER:-marcos}"
WP_PASS="${WP_PASS:-Teste1234}"
OUTPUT_SUMMARY="${K6_SUMMARY:-$PROJECT_DIR/results/k6-summary.json}"

usage() {
  cat <<EOF
Uso: $(basename "$0") [WORKLOAD] [OPÇÕES]

Script dedicado para execução separada do teste de carga com k6.
Pode ser executado localmente em outro terminal ou em uma máquina remota de teste.

Argumentos posicionais (opcional):
  wordpress | cpu | text | mixed | login    Define o tipo de workload rapidamente

Opções:
  -u, --url <URL>           URL base da aplicação (padrão: $TARGET_URL)
  -w, --workload <TIPO>     Tipo de workload: wordpress, cpu, text, mixed, login (padrão: $TARGET_WORKLOAD)
  -r, --rate <REQ/S>        Taxa constante de requisições por segundo (padrão: $TARGET_RATE)
  -d, --duration <SEGUNDOS> Duração da carga em segundos (padrão: $TARGET_DURATION)
  -s, --scale <VALOR>       Fator de escala de processamento (padrão: $TARGET_SCALE)
  --user <USUÁRIO>          Usuário para login WordPress (padrão: $WP_USER)
  --pass <SENHA>            Senha para login WordPress (padrão: $WP_PASS)
  --warmup <SEGUNDOS>       Executa um aquecimento prévio antes da carga principal (padrão: 0)
  -o, --output <ARQUIVO>    Caminho do arquivo de resumo k6 (padrão: $OUTPUT_SUMMARY)
  -h, --help                Exibe esta ajuda

Exemplos:
  $(basename "$0") wordpress
  $(basename "$0") cpu
  $(basename "$0") --url http://192.168.1.50:8080 --rate 5 --duration 60
EOF
  exit 0
}

# Processamento de primeiro argumento posicional se fornecido
if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
  case "$1" in
    wordpress|wp)
      TARGET_WORKLOAD="wordpress"
      shift
      ;;
    cpu|text|mixed|login)
      TARGET_WORKLOAD="$1"
      shift
      ;;
    *)
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      TARGET_URL="$2"
      shift 2
      ;;
    -w|--workload)
      TARGET_WORKLOAD="$2"
      shift 2
      ;;
    -r|--rate)
      TARGET_RATE="$2"
      shift 2
      ;;
    -d|--duration)
      TARGET_DURATION="$2"
      shift 2
      ;;
    -s|--scale)
      TARGET_SCALE="$2"
      shift 2
      ;;
    --user)
      WP_USER="$2"
      shift 2
      ;;
    --pass)
      WP_PASS="$2"
      shift 2
      ;;
    --warmup)
      TARGET_WARMUP="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_FILE="$2"
      if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
        TARGET_URL="${BASE_URL:-$TARGET_URL}"
        TARGET_WORKLOAD="${WORKLOAD:-$TARGET_WORKLOAD}"
        TARGET_SCALE="${SCALE:-$TARGET_SCALE}"
        TARGET_RATE="${RATE:-$TARGET_RATE}"
        TARGET_DURATION="${DURATION_SECONDS:-$TARGET_DURATION}"
        WP_USER="${WP_USER:-${LIBREPHOTOS_USER:-$WP_USER}}"
        WP_PASS="${WP_PASS:-${LIBREPHOTOS_PASS:-$WP_PASS}}"
      fi
      shift 2
      ;;
    --script)
      K6_SCRIPT="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_SUMMARY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Opção desconhecida: $1" >&2
      echo "Use $0 --help para ver as opções disponíveis." >&2
      exit 1
      ;;
  esac
done

if ! command -v k6 >/dev/null 2>&1; then
  echo "Erro: 'k6' não foi encontrado." >&2
  echo "Instale o k6 executando: ./measurement/install-tools-ubuntu.sh (ou via https://k6.io)" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_SUMMARY")"

echo "=========================================================================="
echo " [GERADOR DE CARGA K6]"
echo " URL:            $TARGET_URL"
echo " Workload:       $TARGET_WORKLOAD"
echo " Taxa:           $TARGET_RATE req/s"
echo " Duração:        ${TARGET_DURATION}s"
echo " Escala:         $TARGET_SCALE"
echo " Resumo em:      $OUTPUT_SUMMARY"
echo "=========================================================================="

K6_SCRIPT="${K6_SCRIPT:-}"
if [[ -z "$K6_SCRIPT" ]]; then
  if [[ "$TARGET_WORKLOAD" == "librephotos" && -f "$PROJECT_DIR/librephotos-load-test.js" ]]; then
    K6_SCRIPT="$PROJECT_DIR/librephotos-load-test.js"
  elif [[ "$TARGET_WORKLOAD" == "bookstack" && -f "$PROJECT_DIR/load-test.js" ]]; then
    K6_SCRIPT="$PROJECT_DIR/load-test.js"
  else
    K6_SCRIPT="$PROJECT_DIR/k6.js"
  fi
fi

if [[ "$TARGET_WARMUP" -gt 0 ]]; then
  echo "==> Executando Warm-up de ${TARGET_WARMUP}s..."
  SUMMARY_PATH="/dev/null" \
  BASE_URL="$TARGET_URL" \
  WORKLOAD="$TARGET_WORKLOAD" \
  WP_USER="$WP_USER" \
  WP_PASS="$WP_PASS" \
  SCALE="$TARGET_SCALE" \
  RATE="$TARGET_RATE" \
  DURATION_SECONDS="$TARGET_WARMUP" \
  k6 run --quiet "$K6_SCRIPT"
  echo "==> Warm-up concluído. Aguardando 2s antes da carga principal..."
  sleep 2
fi

echo "==> Iniciando teste de carga medido usando $K6_SCRIPT..."
SUMMARY_PATH="$OUTPUT_SUMMARY" \
BASE_URL="$TARGET_URL" \
WORKLOAD="$TARGET_WORKLOAD" \
WP_USER="$WP_USER" \
WP_PASS="$WP_PASS" \
LIBREPHOTOS_USER="$WP_USER" \
LIBREPHOTOS_PASS="$WP_PASS" \
SCALE="$TARGET_SCALE" \
RATE="$TARGET_RATE" \
DURATION_SECONDS="$TARGET_DURATION" \
k6 run "$K6_SCRIPT"

echo
echo "Teste de carga concluído com sucesso!"
echo "Resumo do k6 salvo em: $OUTPUT_SUMMARY"
