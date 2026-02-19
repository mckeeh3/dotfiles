#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SCRIPT_DIR}/neofetch.conf"
TARGET_DIR="${HOME}/.config/neofetch"
TARGET_FILE="${TARGET_DIR}/config.conf"

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "Source file not found: ${SOURCE_FILE}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"

if [[ -e "${TARGET_FILE}" && ! -L "${TARGET_FILE}" ]]; then
  BACKUP_FILE="${TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  mv "${TARGET_FILE}" "${BACKUP_FILE}"
  echo "Backed up existing file to ${BACKUP_FILE}"
fi

ln -sfn "${SOURCE_FILE}" "${TARGET_FILE}"
echo "Linked ${TARGET_FILE} -> ${SOURCE_FILE}"
