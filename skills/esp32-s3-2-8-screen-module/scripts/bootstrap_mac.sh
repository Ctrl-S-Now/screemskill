#!/bin/bash
set -euo pipefail

IDF_VERSION="${1:-v5.4.2}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

if ! need_cmd brew; then
  echo "Homebrew is required but not installed." >&2
  echo "Install Homebrew first, then rerun this script." >&2
  exit 1
fi

echo "[1/4] Installing macOS prerequisites via Homebrew"
brew install libgcrypt glib pixman sdl2 libslirp dfu-util cmake python

echo "[2/4] Installing Espressif Installation Manager"
if ! brew tap | grep -q '^espressif/eim$'; then
  brew tap espressif/eim
fi
brew install eim

PYTHON_BIN="$(command -v python3)"

echo "[3/4] Installing Python-side helper packages"
"${PYTHON_BIN}" -m pip install --user --upgrade pip pyyaml pyserial esptool

if ! need_cmd eim; then
  echo "eim was installed but is not yet on PATH. Open a new terminal and rerun this script." >&2
  exit 1
fi

echo "[4/4] Installing ESP-IDF ${IDF_VERSION}"
eim install -i "${IDF_VERSION}"

echo "Environment bootstrap complete."
