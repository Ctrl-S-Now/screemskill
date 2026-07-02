#!/bin/bash
set -euo pipefail

PORT="${1:-}"
BAUD="${2:-921600}"

[[ -n "${PORT}" ]] || {
  echo "Usage: flash_merged_firmware.sh <port> [baud]" >&2
  exit 1
}

resolve_repo_root() {
  local current
  local script_dir

  if [[ -n "${ESP32_S3_TOUCH_LCD_REPO:-}" ]]; then
    current="${ESP32_S3_TOUCH_LCD_REPO}"
    if [[ -f "${current}/Firmware/ESP32-S3-2.8-Image-Test.bin" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  current="${script_dir}"
  while [[ "${current}" != "/" ]]; do
    if [[ -f "${current}/Firmware/ESP32-S3-2.8-Image-Test.bin" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi
    current="$(dirname "${current}")"
  done

  current="$(pwd)"
  while [[ "${current}" != "/" ]]; do
    if [[ -f "${current}/Firmware/ESP32-S3-2.8-Image-Test.bin" ]]; then
      printf '%s\n' "${current}"
      return 0
    fi
    current="$(dirname "${current}")"
  done

  return 1
}

REPO_ROOT="$(resolve_repo_root)" || {
  echo "Unable to locate the repository root. Set ESP32_S3_TOUCH_LCD_REPO or run from inside the repo." >&2
  exit 1
}

FIRMWARE="${REPO_ROOT}/Firmware/ESP32-S3-2.8-Image-Test.bin"

if ! command -v esptool.py >/dev/null 2>&1 &&
   ! python3 -c 'import esptool' >/dev/null 2>&1; then
  IDF_EXPORT="$(find "${HOME}/esp" "${HOME}/espidf" -maxdepth 6 -path '*/esp-idf/export.sh' -type f 2>/dev/null | sort | head -n 1 || true)"
  if [[ -n "${IDF_EXPORT}" ]]; then
    # shellcheck disable=SC1090
    source "${IDF_EXPORT}" >/dev/null
  fi
fi

if command -v esptool.py >/dev/null 2>&1; then
  esptool.py --chip esp32s3 --port "${PORT}" --baud "${BAUD}" write_flash 0x0 "${FIRMWARE}"
elif command -v python3 >/dev/null 2>&1 && python3 -c 'import esptool' >/dev/null 2>&1; then
  python3 -m esptool --chip esp32s3 --port "${PORT}" --baud "${BAUD}" write_flash 0x0 "${FIRMWARE}"
elif command -v python >/dev/null 2>&1 && python -c 'import esptool' >/dev/null 2>&1; then
  python -m esptool --chip esp32s3 --port "${PORT}" --baud "${BAUD}" write_flash 0x0 "${FIRMWARE}"
else
  echo "esptool.py or python is required to flash the first-boot image firmware." >&2
  exit 1
fi
