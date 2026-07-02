#!/bin/bash
set -euo pipefail

PORT="${1:-}"

[[ -n "${PORT}" ]] || {
  echo "Usage: setup_and_light.sh <port>" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

"${SCRIPT_DIR}/bootstrap_mac.sh"
"${SCRIPT_DIR}/flash_merged_firmware.sh" "${PORT}"

echo "Setup and first-boot flash completed. Confirm that the expected image is visible."
