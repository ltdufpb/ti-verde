#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR/tools"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer is for Linux." >&2
  exit 1
fi

if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  cat >&2 <<'EOF'
WSL was detected.

You may run the PHP application in WSL, but RAPL power counters are generally
not exposed there. Boot native Linux on the physical computer for the actual
Scaphandre experiment.
EOF
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  jq \
  perl \
  php-cli \
  python3 \
  wget

echo "Installing k6..."
curl -fsSL https://dl.k6.io/key.gpg |
  sudo gpg --dearmor --yes -o /usr/share/keyrings/k6-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" |
  sudo tee /etc/apt/sources.list.d/k6.list >/dev/null

sudo apt-get update
sudo apt-get install -y k6

install_scaphandre_from_release() {
  local architecture="$1"
  local release_json asset_url temporary_deb

  case "$architecture" in
    x86_64|amd64) architecture="amd64" ;;
    aarch64|arm64) architecture="arm64" ;;
    *)
      echo "No automatic package selection for architecture: $architecture" >&2
      return 1
      ;;
  esac

  release_json="$(mktemp)"
  temporary_deb="$(mktemp --suffix=.deb)"

  curl -fsSL \
    https://api.github.com/repos/hubblo-org/scaphandre/releases/latest \
    -o "$release_json"

  asset_url="$(
    python3 - "$release_json" "$architecture" <<'PY'
import json
import sys

path, arch = sys.argv[1], sys.argv[2]
release = json.load(open(path, encoding="utf-8"))
candidates = []

for asset in release.get("assets", []):
    name = asset.get("name", "").lower()
    url = asset.get("browser_download_url", "")
    if name.endswith(".deb") and arch in name:
        score = 10 if ("deb12" in name or "bookworm" in name) else 0
        candidates.append((score, url))

if not candidates:
    raise SystemExit(1)

print(sorted(candidates, reverse=True)[0][1])
PY
  )" || {
    rm -f "$release_json" "$temporary_deb"
    return 1
  }

  curl -fL "$asset_url" -o "$temporary_deb"
  sudo apt-get install -y "$temporary_deb"
  rm -f "$release_json" "$temporary_deb"
}

if ! command -v scaphandre >/dev/null 2>&1; then
  echo "Installing Scaphandre..."
  if apt-cache show scaphandre >/dev/null 2>&1; then
    sudo apt-get install -y scaphandre
  else
    install_scaphandre_from_release "$(uname -m)" || {
      cat >&2 <<'EOF'
Automatic Scaphandre installation failed.
Install the appropriate official Scaphandre .deb package and rerun this script.
EOF
      exit 1
    }
  fi
fi

mkdir -p "$TOOLS_DIR"

if [[ ! -d "$TOOLS_DIR/phpspy/.git" ]]; then
  rm -rf "$TOOLS_DIR/phpspy"
  git clone --recursive https://github.com/adsr/phpspy.git "$TOOLS_DIR/phpspy"
fi

echo "Building phpspy..."
make -C "$TOOLS_DIR/phpspy"

if [[ ! -d "$TOOLS_DIR/FlameGraph/.git" ]]; then
  rm -rf "$TOOLS_DIR/FlameGraph"
  git clone https://github.com/brendangregg/FlameGraph.git "$TOOLS_DIR/FlameGraph"
fi

chmod +x "$PROJECT_DIR"/*.sh 2>/dev/null || true
chmod +x "$PROJECT_DIR"/measurement/*.sh
chmod +x "$PROJECT_DIR"/scripts/*.sh 2>/dev/null || true
chmod +x "$PROJECT_DIR"/carbon.py

echo
echo "Installation completed."
echo "Next: ./measurement/check-environment.sh"
