#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${HOME}/.local/bin"
mkdir -p "${TARGET_DIR}"

link_file() {
  local source_file="$1"
  local target_file="$2"

  if [[ ! -f "${source_file}" ]]; then
    echo "Source file not found: ${source_file}" >&2
    exit 1
  fi

  if [[ -e "${target_file}" && ! -L "${target_file}" ]]; then
    local backup_file="${target_file}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${target_file}" "${backup_file}"
    echo "Backed up existing file to ${backup_file}"
  fi

  ln -sfn "${source_file}" "${target_file}"
  echo "Linked ${target_file} -> ${source_file}"
}

link_file "${SCRIPT_DIR}/ssh2" "${TARGET_DIR}/ssh2"
link_file "${SCRIPT_DIR}/ssh2.config" "${TARGET_DIR}/ssh2.config"
