#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/arch-linux"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

count=0
found=0

while IFS= read -r script; do
  found=1
  count=$((count + 1))
  echo "Running ${script}"
  bash "${script}"
done < <(find "${TARGET_DIR}" -maxdepth 1 -type f -name "*.sh" | sort)

if [[ "${found}" -eq 0 ]]; then
  echo "No scripts found in ${TARGET_DIR}"
  exit 0
fi

echo "Completed ${count} scripts."
