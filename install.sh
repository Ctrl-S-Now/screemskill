#!/bin/bash
set -euo pipefail

SKILL_NAME="esp32-s3-2-8-screen-module"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
INSTALL_ROOT="${CODEX_HOME}/esp32-s3-screen-skill"
SKILL_TARGET="${CODEX_HOME}/skills/${SKILL_NAME}"
REPO_URL="${1:-${ESP32_SCREEN_SKILL_REPO_URL:-}}"

if [[ -n "${REPO_URL}" ]]; then
  if [[ -d "${INSTALL_ROOT}/.git" ]]; then
    git -C "${INSTALL_ROOT}" pull --ff-only
  else
    mkdir -p "$(dirname "${INSTALL_ROOT}")"
    git clone "${REPO_URL}" "${INSTALL_ROOT}"
  fi
  REPO_ROOT="${INSTALL_ROOT}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="${SCRIPT_DIR}"
fi

SOURCE="${REPO_ROOT}/skills/${SKILL_NAME}"
[[ -f "${SOURCE}/SKILL.md" ]] || {
  echo "Skill source not found: ${SOURCE}" >&2
  exit 1
}

mkdir -p "${CODEX_HOME}/skills"
if [[ -e "${SKILL_TARGET}" || -L "${SKILL_TARGET}" ]]; then
  if [[ "$(readlink "${SKILL_TARGET}" 2>/dev/null || true)" == "${SOURCE}" ]]; then
    echo "Skill is already installed: ${SKILL_TARGET}"
    exit 0
  fi
  echo "Install target already exists: ${SKILL_TARGET}" >&2
  echo "Remove or rename it before installing this skill." >&2
  exit 1
fi

ln -s "${SOURCE}" "${SKILL_TARGET}"
echo "Installed ${SKILL_NAME} at ${SKILL_TARGET}"
echo "Restart Codex to load the skill."

