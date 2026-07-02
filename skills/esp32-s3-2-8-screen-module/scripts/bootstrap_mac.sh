#!/bin/bash
set -euo pipefail

IDF_VERSION="${1:-v5.4.2}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

find_existing_idf() {
  local candidate
  local candidates=(
    "${IDF_PATH:-}/export.sh"
    "${HOME}/esp/v5.4.1/esp-idf/export.sh"
    "${HOME}/esp/v5.4.2/esp-idf/export.sh"
    "${HOME}/esp/esp-idf/export.sh"
    "${HOME}/espidf/esp-idf/export.sh"
  )

  for candidate in "${candidates[@]}"; do
    if [[ "${candidate}" != "/export.sh" && -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  while IFS= read -r candidate; do
    printf '%s\n' "${candidate}"
    return 0
  done < <(find "${HOME}/esp" "${HOME}/espidf" -maxdepth 6 -path '*/esp-idf/export.sh' -type f 2>/dev/null | sort)

  return 1
}

ensure_python_helpers() {
  local python_bin
  local missing=()
  python_bin="$(command -v python3)"

  "${python_bin}" -c 'import yaml' >/dev/null 2>&1 || missing+=("pyyaml")
  "${python_bin}" -c 'import serial' >/dev/null 2>&1 || missing+=("pyserial")
  "${python_bin}" -c 'import esptool' >/dev/null 2>&1 || missing+=("esptool")

  if (( ${#missing[@]} > 0 )); then
    echo "Installing missing Python helpers: ${missing[*]}"
    "${python_bin}" -m pip install --user "${missing[@]}"
  else
    echo "Python helpers already available; skipping installation."
  fi
}

if EXISTING_IDF_EXPORT="$(find_existing_idf)"; then
  echo "Reusing existing ESP-IDF: ${EXISTING_IDF_EXPORT}"
  # shellcheck disable=SC1090
  source "${EXISTING_IDF_EXPORT}" >/dev/null
  idf.py --version
  ensure_python_helpers
  echo "Environment bootstrap complete; no ESP-IDF installation was performed."
  exit 0
fi

if ! need_cmd brew; then
  echo "Homebrew is required but not installed." >&2
  echo "Install Homebrew first, then rerun this script." >&2
  exit 1
fi

echo "[1/3] No compatible ESP-IDF found; installing prerequisites"
brew install libgcrypt glib pixman sdl2 libslirp dfu-util cmake python

echo "[2/3] Installing Espressif Installation Manager"
if ! need_cmd eim; then
  if ! brew tap | grep -q '^espressif/eim$'; then
    brew tap espressif/eim
  fi
  brew install eim
fi

ensure_python_helpers

echo "[3/3] Installing ESP-IDF ${IDF_VERSION}"
eim install -i "${IDF_VERSION}"

echo "Environment bootstrap complete."
