#!/bin/bash
set -euo pipefail

ACTION="${1:-build}"
PORT="${2:-}"

resolve_repo_root() {
  local current
  local script_dir

  if [[ -n "${ESP32_S3_TOUCH_LCD_REPO:-}" ]]; then
    current="${ESP32_S3_TOUCH_LCD_REPO}"
    if [[ -f "${current}/ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/main.c" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  current="${script_dir}"
  while [[ "${current}" != "/" ]]; do
    if [[ -f "${current}/ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/main.c" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi
    current="$(dirname "${current}")"
  done

  current="$(pwd)"
  while [[ "${current}" != "/" ]]; do
    if [[ -f "${current}/ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test/main/main.c" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi
    current="$(dirname "${current}")"
  done

  return 1
}

ensure_idf() {
  if command -v idf.py >/dev/null 2>&1; then
    return 0
  fi

  if [[ -f "${HOME}/esp/esp-idf/export.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/esp/esp-idf/export.sh" >/dev/null
  fi

  command -v idf.py >/dev/null 2>&1
}

REPO_ROOT="$(resolve_repo_root)" || {
  echo "Unable to locate the repository root. Set ESP32_S3_TOUCH_LCD_REPO or run from inside the repo." >&2
  exit 1
}

PROJECT_DIR="${REPO_ROOT}/ESP-IDF/ESP32-S3-Touch-LCD-2.8B-Test"

ensure_idf || {
  echo "idf.py is not available. Open an ESP-IDF-enabled terminal or install ESP-IDF first." >&2
  exit 1
}

cd "${PROJECT_DIR}"

case "${ACTION}" in
  build)
    idf.py -DIDF_TARGET=esp32s3 build
    ;;
  flash)
    [[ -n "${PORT}" ]] || {
      echo "Port is required for flash." >&2
      exit 1
    }
    idf.py -DIDF_TARGET=esp32s3 -p "${PORT}" build flash
    ;;
  monitor)
    [[ -n "${PORT}" ]] || {
      echo "Port is required for monitor." >&2
      exit 1
    }
    idf.py -DIDF_TARGET=esp32s3 -p "${PORT}" monitor
    ;;
  full)
    [[ -n "${PORT}" ]] || {
      echo "Port is required for full." >&2
      exit 1
    }
    idf.py -DIDF_TARGET=esp32s3 -p "${PORT}" build flash monitor
    ;;
  *)
    echo "Unknown action: ${ACTION}. Use build, flash, monitor, or full." >&2
    exit 1
    ;;
esac
