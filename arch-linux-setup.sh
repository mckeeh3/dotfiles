#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/arch-linux"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

mapfile -t scripts < <(find "${TARGET_DIR}" -maxdepth 1 -type f -name "*.sh" | sort)

if [[ "${#scripts[@]}" -eq 0 ]]; then
  echo "No scripts found in ${TARGET_DIR}"
  exit 0
fi

for script in "${scripts[@]}"; do
  echo "Running ${script}"
  bash "${script}"
done

echo "Completed ${#scripts[@]} scripts."
