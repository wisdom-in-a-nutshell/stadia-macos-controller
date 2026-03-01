#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mapfile -t tracked_files < <(git ls-files)

if [ "${#tracked_files[@]}" -eq 0 ]; then
  echo "[check-fast] no tracked files found"
  exit 0
fi

echo "[check-fast] checking for merge conflict markers"
if command -v rg >/dev/null 2>&1; then
  if rg -n --no-messages "^(<<<<<<< |=======|>>>>>>> )" -- "${tracked_files[@]}"; then
    echo "[check-fast] merge conflict markers detected"
    exit 1
  fi
else
  if grep -nE "^(<<<<<<< |=======|>>>>>>> )" "${tracked_files[@]}"; then
    echo "[check-fast] merge conflict markers detected"
    exit 1
  fi
fi

echo "[check-fast] validating Swift package manifest"
swift package dump-package >/dev/null

echo "[check-fast] checks passed"
