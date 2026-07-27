#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"

echo "Starting Green PHP Lab at http://${HOST}:${PORT}"
echo "Press Ctrl+C to stop."
exec php -S "${HOST}:${PORT}" -t "${PROJECT_DIR}/public"
