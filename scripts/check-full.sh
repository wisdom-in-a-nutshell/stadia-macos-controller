#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mapfile -t tracked_files < <(git ls-files)

if [ "${#tracked_files[@]}" -eq 0 ]; then
  echo "[check-full] no tracked files found"
  exit 0
fi

echo "[check-full] checking for merge conflict markers"
if command -v rg >/dev/null 2>&1; then
  if rg -n --no-messages "^(<<<<<<< |=======|>>>>>>> )" -- "${tracked_files[@]}"; then
    echo "[check-full] merge conflict markers detected"
    exit 1
  fi
else
  if grep -nE "^(<<<<<<< |=======|>>>>>>> )" "${tracked_files[@]}"; then
    echo "[check-full] merge conflict markers detected"
    exit 1
  fi
fi

while IFS= read -r file; do
  [ -f "$file" ] || continue
  bash -n "$file"
done < <(git ls-files '*.sh')

echo "[check-full] validating Swift package manifest"
swift package dump-package >/dev/null

echo "[check-full] building Swift package"
swift build

echo "[check-full] checks passed"
